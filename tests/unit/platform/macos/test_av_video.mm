/**
 * @file tests/unit/platform/macos/test_av_video.mm
 * @brief Regression tests for cancellation of stalled macOS video capture.
 */
#ifdef __APPLE__

#include "../../../tests_common.h"
#import <AVFoundation/AVFoundation.h>
#import <src/platform/macos/av_video.h>

/** @brief Video capture cancellation tests that do not require a live display. */
class AVVideoCancellationTest: public PlatformTestSuite {};

/** @brief Cancellation waits for the callback queue before returning to its caller. */
TEST_F(AVVideoCancellationTest, DrainsDelegateQueueAfterTimeout) {
  AVVideo *video = [[AVVideo alloc] init];
  video.session = [[AVCaptureSession alloc] init];
  video.videoOutputs = [[NSMapTable alloc] init];
  video.captureCallbacks = [[NSMapTable alloc] init];
  video.captureSignals = [[NSMapTable alloc] init];
  video.captureQueues = [[NSMapTable alloc] init];

  AVCaptureConnection *connection = (AVCaptureConnection *) [[NSObject alloc] init];
  AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
  dispatch_semaphore_t signal = dispatch_semaphore_create(0);
  dispatch_queue_t queue = dispatch_queue_create("test.av-video-cancel", DISPATCH_QUEUE_SERIAL);
  dispatch_semaphore_t entered = dispatch_semaphore_create(0);
  dispatch_semaphore_t finish = dispatch_semaphore_create(0);
  __block BOOL drained = NO;
  dispatch_async(queue, ^{
    dispatch_semaphore_signal(entered);
    dispatch_semaphore_wait(finish, DISPATCH_TIME_FOREVER);
    drained = YES;
  });
  ASSERT_EQ(dispatch_semaphore_wait(entered, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC)), 0);

  [video.videoOutputs setObject:output forKey:connection];
  [video.captureSignals setObject:signal forKey:connection];
  [video.captureQueues setObject:[NSValue valueWithPointer:queue] forKey:connection];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    dispatch_semaphore_signal(finish);
  });
  [video cancelCapture:signal];

  EXPECT_TRUE(drained);
  EXPECT_EQ([video.videoOutputs count], 0u);
  EXPECT_EQ([video.captureSignals count], 0u);
  EXPECT_EQ([video.captureQueues count], 0u);

  dispatch_release(entered);
  dispatch_release(finish);
  dispatch_release(signal);
  [output release];
  [connection release];
  [video release];
}

#endif
