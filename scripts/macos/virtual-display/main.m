// Interface declarations and display setup adapted from Chromium (BSD license).
// https://chromium.googlesource.com/chromium/src/+/HEAD/ui/display/mac/test/virtual_display_util_mac.mm
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

@interface CGVirtualDisplayDescriptor: NSObject
@property unsigned int vendorID, productID, serialNum, serialNumber;
@property (strong) NSString *name;
@property CGSize sizeInMillimeters;
@property unsigned int maxPixelsWide, maxPixelsHigh;
@property CGPoint redPrimary, greenPrimary, bluePrimary, whitePoint;
@property (strong) dispatch_queue_t queue;
@end
@interface CGVirtualDisplayMode: NSObject
- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)rate;
@end
@interface CGVirtualDisplaySettings: NSObject
@property (strong) NSArray *modes;
@property unsigned int hiDPI;
@end
@interface CGVirtualDisplay: NSObject
@property (readonly) unsigned int displayID;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end

static volatile sig_atomic_t stopped = 0;

static void stopDisplay(int signalNumber) {
  (void) signalNumber;
  stopped = 1;
}

/**
 * @brief Replace only the Sunshine settings owned by this helper.
 * @param original Existing configuration, including unrelated settings.
 * @param displayID Current CoreGraphics display identifier.
 * @return Updated configuration text.
 */
static NSString *configuredText(NSString *original, unsigned int displayID) {
  NSDictionary<NSString *, NSString *> *settings = @ {
    @"output_name": [NSString stringWithFormat:@"%u", displayID],
    @"dd_configuration_option": @"ensure_only_display",
    @"dd_resolution_option": @"disabled",
    @"dd_refresh_rate_option": @"disabled",
    @"dd_config_revert_on_disconnect": @"enabled",
    @"dd_config_revert_delay": @"0"
  };
  NSMutableArray<NSString *> *lines = [NSMutableArray new];
  for (NSString *line in [original componentsSeparatedByString:@"\n"]) {
    NSString *key = [[[line componentsSeparatedByString:@"="] firstObject]
      stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!settings[key]) {
      [lines addObject:line];
    }
  }
  while (lines.count && [lines.lastObject length] == 0) {
    [lines removeLastObject];
  }
  for (NSString *key in [[settings allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
    [lines addObject:[NSString stringWithFormat:@"%@ = %@", key, settings[key]]];
  }
  return [[lines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"];
}

/** @brief Pump the run loop briefly so native application state stays current. */
static void pump(void) {
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

/**
 * @brief Stop Sunshine before changing its capture display or removing that display.
 * @return True if all Sunshine instances stopped.
 */
static BOOL stopSunshine(void) {
  NSArray<NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:@"dev.lizardbyte.app.Sunshine"];
  for (NSRunningApplication *app in apps) {
    if (!app.terminated) {
      kill(app.processIdentifier, SIGTERM);
    }
  }
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
  for (NSRunningApplication *app in apps) {
    while (!app.terminated && deadline.timeIntervalSinceNow > 0) {
      pump();
    }
    if (!app.terminated) {
      fprintf(stderr, "Sunshine did not stop in 10 seconds; terminating the stalled process.\n");
      kill(app.processIdentifier, SIGKILL);
    }
  }
  deadline = [NSDate dateWithTimeIntervalSinceNow:3];
  for (NSRunningApplication *app in apps) {
    while (!app.terminated && deadline.timeIntervalSinceNow > 0) {
      pump();
    }
    if (!app.terminated) {
      return NO;
    }
  }
  return YES;
}

/**
 * @brief Save the current display ID and start the installed Sunshine app.
 * @param displayID CoreGraphics identifier of the ready virtual display.
 * @return True if configuration and application launch succeeded.
 */
static BOOL startSunshine(unsigned int displayID) {
  NSString *directory = [NSHomeDirectory() stringByAppendingPathComponent:@".config/sunshine"];
  NSString *path = [directory stringByAppendingPathComponent:@"sunshine.conf"];
  NSFileManager *files = NSFileManager.defaultManager;
  NSError *error = nil;
  if (![files createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
    NSLog(@"Cannot create Sunshine config directory: %@", error);
    return NO;
  }
  NSString *original = @"";
  if ([files fileExistsAtPath:path]) {
    original = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (!original) {
      NSLog(@"Cannot read Sunshine config: %@", error);
      return NO;
    }
    NSString *backup = [directory stringByAppendingPathComponent:@"sunshine.conf.before-virtualdisplay"];
    if (![files fileExistsAtPath:backup] && ![files copyItemAtPath:path toPath:backup error:&error]) {
      NSLog(@"Cannot back up Sunshine config: %@", error);
      return NO;
    }
  }
  if (![configuredText(original, displayID) writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
    NSLog(@"Cannot save Sunshine config: %@", error);
    return NO;
  }
  NSWorkspaceOpenConfiguration *configuration = NSWorkspaceOpenConfiguration.configuration;
  configuration.activates = NO;
  __block BOOL completed = NO;
  __block BOOL succeeded = NO;
  [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:@"/Applications/Sunshine.app"]
                                      configuration:configuration
                                  completionHandler:^(NSRunningApplication *app, NSError *launchError) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                      succeeded = app != nil;
                                      if (launchError) {
                                        NSLog(@"Cannot launch Sunshine: %@", launchError);
                                      }
                                      completed = YES;
                                    });
                                  }];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:15];
  while (!completed && !stopped && deadline.timeIntervalSinceNow > 0) {
    pump();
  }
  return completed && succeeded;
}

/** @brief Create the display and keep it alive for Sunshine until termination. */
int main(int argc, const char *argv[]) {
  @autoreleasepool {
    if (argc == 2 && strcmp(argv[1], "--stop-sunshine") == 0) {
      return stopSunshine() ? 0 : 1;
    }
    if (!NSClassFromString(@"CGVirtualDisplay")) {
      fprintf(stderr, "CGVirtualDisplay is unavailable on this macOS version.\n");
      return 1;
    }
    if (![[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Sunshine.app"]) {
      fprintf(stderr, "Install the patched Sunshine.app in /Applications first.\n");
      return 1;
    }
    if (!stopSunshine()) {
      return 1;
    }
    signal(SIGINT, stopDisplay);
    signal(SIGTERM, stopDisplay);
    CGVirtualDisplayDescriptor *descriptor = [CGVirtualDisplayDescriptor new];
    descriptor.name = @"Moonlight 1440p 180Hz";
    descriptor.vendorID = 505;
    descriptor.productID = 1440;
    descriptor.serialNum = 1440180;
    if ([descriptor respondsToSelector:@selector(setSerialNumber:)]) {
      descriptor.serialNumber = 1440180;
    }
    descriptor.maxPixelsWide = 2560;
    descriptor.maxPixelsHigh = 1440;
    descriptor.sizeInMillimeters = CGSizeMake(597, 336);
    descriptor.redPrimary = CGPointMake(0.64, 0.33);
    descriptor.greenPrimary = CGPointMake(0.30, 0.60);
    descriptor.bluePrimary = CGPointMake(0.15, 0.06);
    descriptor.whitePoint = CGPointMake(0.3127, 0.3290);
    descriptor.queue = dispatch_get_main_queue();
    CGVirtualDisplay *display = [[CGVirtualDisplay alloc] initWithDescriptor:descriptor];
    if (!display) {
      fprintf(stderr, "macOS refused virtual display creation.\n");
      return 1;
    }
    CGVirtualDisplaySettings *settings = [CGVirtualDisplaySettings new];
    settings.hiDPI = 0;
    CGVirtualDisplayMode *mode = [[CGVirtualDisplayMode alloc] initWithWidth:2560 height:1440 refreshRate:180];
    if (!mode) {
      fprintf(stderr, "macOS refused the 1440p/180 Hz mode.\n");
      return 1;
    }
    settings.modes = @[mode];
    if (![display applySettings:settings]) {
      fprintf(stderr, "macOS refused display settings.\n");
      return 1;
    }
    printf("Virtual display ID: %u. Requested 2560x1440 at 180 Hz.\nKeep this process running; Ctrl-C removes the display.\n", display.displayID);
    fflush(stdout);
    BOOL reported = NO;
    int status = 0;
    NSDate *readyDeadline = [NSDate dateWithTimeIntervalSinceNow:15];
    while (!stopped) {
      [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
      if (!reported) {
        CGDisplayModeRef actual = CGDisplayCopyDisplayMode(display.displayID);
        if (actual) {
          printf("macOS reports: %zux%zu at %.2f Hz\n", CGDisplayModeGetWidth(actual), CGDisplayModeGetHeight(actual), CGDisplayModeGetRefreshRate(actual));
          fflush(stdout);
          BOOL correctMode = CGDisplayModeGetWidth(actual) == 2560 && CGDisplayModeGetHeight(actual) == 1440 && fabs(CGDisplayModeGetRefreshRate(actual) - 180) < 0.1;
          CGDisplayModeRelease(actual);
          if (!correctMode || !startSunshine(display.displayID)) {
            fprintf(stderr, "Virtual display mode or Sunshine startup failed.\n");
            status = 1;
            break;
          }
          reported = YES;
        }
      }
      if (!reported && readyDeadline.timeIntervalSinceNow <= 0) {
        fprintf(stderr, "Timed out waiting for the virtual display.\n");
        status = 1;
        break;
      }
    }
    // Restore physical displays before the virtual display disappears.
    stopSunshine();
    display = nil;
    return status;
  }
  return 0;
}
