// Compile the helper into this test without invoking its display/app lifecycle.
#define main helperMain
#import "main.m"
#undef main

/** @brief Verify config replacement, preservation, and repeated startup behavior. */
int main(void) {
  @autoreleasepool {
    NSString *original = @"# keep this comment\nsystem_tray = disabled\noutput_name = 1\n output_name = 2\ndd_configuration_option = disabled\ncustom_setting = value=with=equals\n";
    NSString *updated = configuredText(original, 47);
    NSCAssert([updated containsString:@"# keep this comment\nsystem_tray = disabled\n"], @"Preserve unrelated text");
    NSCAssert([updated containsString:@"custom_setting = value=with=equals\n"], @"Preserve values with equals");
    NSCAssert([[updated componentsSeparatedByString:@"output_name"] count] == 2, @"Remove duplicate old selectors");
    NSCAssert([updated containsString:@"output_name = 47\n"], @"Use the runtime display ID");
    NSCAssert([updated containsString:@"dd_configuration_option = ensure_only_display\n"], @"Enable session switching");
    NSCAssert([updated containsString:@"dd_config_revert_on_disconnect = enabled\n"], @"Restore on disconnect");
    NSCAssert([configuredText(updated, 47) isEqualToString:updated], @"Repeated launches are idempotent");
    NSString *restarted = configuredText(updated, 99);
    NSCAssert([restarted containsString:@"output_name = 99\n"] && ![restarted containsString:@"output_name = 47\n"], @"Handle changed display IDs");
    NSCAssert([configuredText(@"", 1) containsString:@"output_name = 1\n"], @"Support a new config");
  }
  return 0;
}
