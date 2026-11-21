/**
 * @file src/platform/macos/av_video.m
 * @brief Definitions for video capture on macOS.
 */
// local includes
#import "av_video.h"

@implementation AVVideo

- (id)initWithDisplay:(CGDirectDisplayID)displayID frameRate:(int)frameRate {
  self = [super init];

  CGDisplayModeRef mode = CGDisplayCopyDisplayMode(displayID);
  if (!mode) {
    [self release];
    return nil;
  }

  self.displayID = displayID;
  self.pixelFormat = kCVPixelFormatType_32BGRA;
  self.frameWidth = (int) CGDisplayModeGetPixelWidth(mode);
  self.frameHeight = (int) CGDisplayModeGetPixelHeight(mode);
  self.minFrameDuration = CMTimeMake(1, frameRate);
  self.session = [[AVCaptureSession alloc] init];
  self.videoOutputs = [[NSMapTable alloc] init];
  self.captureCallbacks = [[NSMapTable alloc] init];
  self.captureSignals = [[NSMapTable alloc] init];
  self.captureQueues = [[NSMapTable alloc] init];

  CFRelease(mode);

  AVCaptureScreenInput *screenInput = [[AVCaptureScreenInput alloc] initWithDisplayID:self.displayID];
  [screenInput setMinFrameDuration:self.minFrameDuration];
  [screenInput setCapturesCursor:NO];

  if ([self.session canAddInput:screenInput]) {
    [self.session addInput:screenInput];
  } else {
    [screenInput release];
    return nil;
  }

  [self.session startRunning];

  return self;
}

- (void)dealloc {
  [self.captureQueues release];
  [self.videoOutputs release];
  [self.captureCallbacks release];
  [self.captureSignals release];
  [self.session stopRunning];
  [super dealloc];
}

- (void)setFrameWidth:(int)frameWidth frameHeight:(int)frameHeight {
  self.frameWidth = frameWidth;
  self.frameHeight = frameHeight;
}

- (dispatch_semaphore_t)capture:(FrameCallbackBlock)frameCallback {
  @synchronized(self) {
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];

    [videoOutput setVideoSettings:@{
      (NSString *) kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithUnsignedInt:self.pixelFormat],
      (NSString *) kCVPixelBufferWidthKey: [NSNumber numberWithInt:self.frameWidth],
      (NSString *) kCVPixelBufferHeightKey: [NSNumber numberWithInt:self.frameHeight],
      (NSString *) AVVideoScalingModeKey: AVVideoScalingModeResizeAspect,
    }];

    dispatch_queue_attr_t qos = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, DISPATCH_QUEUE_PRIORITY_HIGH);
    dispatch_queue_t recordingQueue = dispatch_queue_create("videoCaptureQueue", qos);
    [videoOutput setSampleBufferDelegate:self queue:recordingQueue];

    // Mutate the graph in place. A stopRunning/startRunning pair renegotiates the whole
    // capture session, which is slow and is a deadlock hazard when called from the sample
    // buffer delegate below.
    [self.session beginConfiguration];

    if ([self.session canAddOutput:videoOutput]) {
      [self.session addOutput:videoOutput];
    } else {
      [self.session commitConfiguration];
      dispatch_release(recordingQueue);
      [videoOutput release];
      return nil;
    }

    AVCaptureConnection *videoConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    dispatch_semaphore_t signal = dispatch_semaphore_create(0);

    [self.videoOutputs setObject:videoOutput forKey:videoConnection];
    [self.captureCallbacks setObject:frameCallback forKey:videoConnection];
    [self.captureSignals setObject:signal forKey:videoConnection];
    [self.captureQueues setObject:[NSValue valueWithPointer:recordingQueue] forKey:videoConnection];

    [self.session commitConfiguration];

    // Keep the delegate queue alive until completion or cancellation drains it.
    [videoOutput release];

    return signal;
  }
}

- (void)cancelCapture:(dispatch_semaphore_t)signal {
  dispatch_queue_t queue = nil;
  AVCaptureVideoDataOutput *output = nil;
  @synchronized(self) {
    AVCaptureConnection *matchingConnection = nil;
    for (AVCaptureConnection *connection in self.captureSignals) {
      if ([self.captureSignals objectForKey:connection] == signal) {
        matchingConnection = connection;
        break;
      }
    }
    if (matchingConnection) {
      output = [[self.videoOutputs objectForKey:matchingConnection] retain];
      queue = (dispatch_queue_t) [[self.captureQueues objectForKey:matchingConnection] pointerValue];
      [self.captureCallbacks removeObjectForKey:matchingConnection];
      [self.videoOutputs removeObjectForKey:matchingConnection];
      [self.captureSignals removeObjectForKey:matchingConnection];
      [self.captureQueues removeObjectForKey:matchingConnection];
    }
  }
  if (queue) {
    [output setSampleBufferDelegate:nil queue:NULL];
    [self.session beginConfiguration];
    [self.session removeOutput:output];
    [self.session commitConfiguration];
    dispatch_sync(queue, ^{});
    dispatch_release(queue);
    [output release];
  }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
         fromConnection:(AVCaptureConnection *)connection {
  FrameCallbackBlock callback = [self.captureCallbacks objectForKey:connection];

  if (callback != nil) {
    if (!callback(sampleBuffer)) {
      @synchronized(self) {
        if ([self.captureCallbacks objectForKey:connection] != callback) {
          return;
        }
        [self.session beginConfiguration];
        [self.captureCallbacks removeObjectForKey:connection];
        [self.session removeOutput:[self.videoOutputs objectForKey:connection]];
        [self.videoOutputs removeObjectForKey:connection];
        dispatch_semaphore_signal([self.captureSignals objectForKey:connection]);
        [self.captureSignals removeObjectForKey:connection];
        dispatch_queue_t queue = (dispatch_queue_t) [[self.captureQueues objectForKey:connection] pointerValue];
        [self.captureQueues removeObjectForKey:connection];
        [self.session commitConfiguration];
        dispatch_release(queue);
      }
    }
  }
}

@end
