// DP mac port: the disc image picker for macOS (the Win32 and GTK ones are in
// deadlyprem_iso_installer.cpp).

#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <filesystem>

namespace deadlyprem {

std::filesystem::path PickIsoFileMac() {
  __block std::filesystem::path result;
  void (^pick)(void) = ^{
    @autoreleasepool {
      NSOpenPanel* panel = [NSOpenPanel openPanel];
      panel.title = @"Select your Deadly Premonition Xbox 360 disc image";
      panel.message = @"Select the disc image (.iso) dumped from your own copy of the game.";
      panel.prompt = @"Install";
      panel.canChooseFiles = YES;
      panel.canChooseDirectories = NO;
      panel.allowsMultipleSelection = NO;
      NSMutableArray<UTType*>* types = [NSMutableArray array];
      for (NSString* extension in @[ @"iso", @"xiso" ]) {
        UTType* type = [UTType typeWithFilenameExtension:extension];
        if (type) {
          [types addObject:type];
        }
      }
      if (types.count) {
        panel.allowedContentTypes = types;
      }
      [NSApp activateIgnoringOtherApps:YES];
      if ([panel runModal] == NSModalResponseOK) {
        NSURL* url = panel.URLs.firstObject;
        if (url.fileURL) {
          result = std::filesystem::path(url.fileSystemRepresentation);
        }
      }
    }
  };
  // AppKit panels belong to the main thread, which runs the wizard's UI.
  if ([NSThread isMainThread]) {
    pick();
  } else {
    dispatch_sync(dispatch_get_main_queue(), pick);
  }
  return result;
}

}  // namespace deadlyprem
