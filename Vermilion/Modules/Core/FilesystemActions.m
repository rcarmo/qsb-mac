//
//  FileSystemActions.m
//
//  Copyright (c) 2008 Google Inc. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//    * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following disclaimer
//  in the documentation and/or other materials provided with the
//  distribution.
//    * Neither the name of Google Inc. nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import <Vermilion/Vermilion.h>
#import <Quartz/Quartz.h>
#import "FilesystemActions.h"
#import "GTMMethodCheck.h"
#import "GTMNSAppleScript+Handler.h"
#import "GTMGarbageCollection.h"
#import "GTMSystemVersion.h"
#import "GTMNSWorkspace+Running.h"
#import "GTMGeometryUtils.h"

// Adds a weak reference to QLPreviewPanel so that we work on Leopard.
__asm__(".weak_reference _OBJC_CLASS_$_QLPreviewPanel");

// Expose an SPI on Leopard that we need that has a different
// interface on 10.6.
@interface QLPreviewPanel (QLPrivates)
- (void)setURLs:(id)fp8
    currentIndex:(unsigned int)fp12
    preservingDisplayState:(BOOL)fp16;
@end

@interface FileSystemOpenAction : HGSAction
@end

@interface FileSystemOpenWithAction : FileSystemOpenAction
@end

@interface FileSystemOpenAgainAction : HGSAction
@end

@interface FileSystemOpenActionApplicationArgument : HGSActionArgument {
 @private
  NSArray *appURLs_;
  NSURL *defaultURL_;
}
@end

@interface FileSystemRenameAction : HGSAction
@end

@interface FileSystemSetCommentAction : HGSAction
@end

@interface FileSystemQuickLookAction : HGSAction
    <NSComboBoxDataSource, QLPreviewPanelDataSource> {
 @private
  NSArray *urls_;
}
@end

@interface FileSystemScriptAction : HGSAction
+ (NSAppleScript *)fileSystemActionScript;
- (NSString *)handlerName;
@end

@interface FileSystemMoveToAction : FileSystemScriptAction
@end

@interface FileSystemCopyToAction : FileSystemScriptAction
@end

@interface FileSystemShowInFinderAction : FileSystemScriptAction
@end

@interface FileSystemGetInfoAction : FileSystemScriptAction
@end


@interface FileSystemEjectAction : HGSAction
@end

@implementation FileSystemOpenWithAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  HGSResultArray *apps
    = [info objectForKey:@"com.google.core.filesystem.action.openwith.application"];
  NSArray *appURLs = [apps urls];
  NSArray *directURLs = [directObjects urls];
  BOOL wasGood = YES;
  for (NSString *appURL in appURLs) {
    LSLaunchURLSpec spec = {
      (CFURLRef)appURL,
      (CFArrayRef)directURLs,
      NULL,
      0,
      NULL
    };
    wasGood &= LSOpenFromURLSpec(&spec, NULL) == noErr;
  }
  return wasGood;
}

@end

@implementation FileSystemOpenActionApplicationArgument

- (void)willScoreForQuery:(HGSQuery *)query {
  HGSActionOperation *actionOperation = [query actionOperation];
  HGSResultArray *directTypes
    = [actionOperation argumentForKey:kHGSActionDirectObjectsKey];
  if ([directTypes count]) {
    HGSResult *theDirectType = [directTypes objectAtIndex:0];
    CFURLRef directTypeURL = NULL;
    if ([theDirectType isFileResult]) {
      NSString *filePath = [theDirectType filePath];
      directTypeURL = (CFURLRef)[NSURL fileURLWithPath:filePath];
    } else {
      directTypeURL = (CFURLRef)[theDirectType url];
    }
    appURLs_ = (NSArray *)LSCopyApplicationURLsForURL(directTypeURL,
                                                      kLSRolesAll);
    OSStatus err = LSGetApplicationForURL(directTypeURL,
                                          kLSRolesAll,
                                          NULL,
                                          (CFURLRef *)&defaultURL_);
    HGSCheckDebug(err == noErr, @"");
  } else {
    HGSLogDebug(@"No direct types for %@ for %@",
                actionOperation, [self class]);
  }
}

- (void)didScoreForQuery:(HGSQuery *)query {
  [appURLs_ release];
  appURLs_ = nil;
  [defaultURL_ release];
  defaultURL_ = nil;
}

- (HGSScoredResult *)scoreResult:(HGSScoredResult *)result
                        forQuery:(HGSQuery *)query {
  HGSScoredResult *outResult = nil;
  if ([result conformsToType:kHGSTypeFileApplication]) {
    NSString *appPath = [result filePath];
    NSURL *appURL = [NSURL fileURLWithPath:appPath];
    Boolean accepts = [appURLs_ containsObject:appURL];
    if (!accepts) {
      outResult = [HGSScoredResult resultWithResult:result
                                              score:[result score]
                                         flagsToSet:eHGSBelowFoldRankFlag
                                       flagsToClear:0
                                        matchedTerm:[result matchedTerm]
                                     matchedIndexes:[result matchedIndexes]];
    } else {
      CGFloat score = [result score];
      if ([appURL isEqual:defaultURL_]) {
        score = HGSCalibratedScore(kHGSCalibratedPerfectScore);
      }

      outResult = [HGSScoredResult resultWithResult:result
                                              score:score
                                         flagsToSet:0
                                       flagsToClear:0
                                        matchedTerm:[result matchedTerm]
                                     matchedIndexes:[result matchedIndexes]];
    }
  } else if ([result conformsToType:kHGSTypeDirectory]) {
    outResult = result;
  }
  return outResult;
}

@end

@implementation FileSystemOpenAction

- (id)defaultObjectForKey:(NSString *)key {
  id defaultObject = nil;
  if ([key isEqualToString:kHGSExtensionIconImageKey]) {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSImage *icon = [ws iconForFileType:@"rtf"];
    defaultObject = icon;
  }
  if (!defaultObject) {
    defaultObject = [super defaultObjectForKey:key];
  }
  return defaultObject;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
     = [info objectForKey:kHGSActionDirectObjectsKey];
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSArray *urls = [directObjects urls];
  BOOL wasGood = YES;
  for (NSURL *url in urls) {
    wasGood &= [ws openURL:url];
  }
  return wasGood;
}

- (NSImage *)displayIconForResults:(HGSResultArray*)results {
  NSImage *icon = nil;
  NSUInteger resultsCount = [results count];
  if (resultsCount) {
    if ([results count] > 1) {
      icon = [super displayIconForResults:results];
    } else {
      HGSResult *result = [results objectAtIndex:0];
      NSURL *url = [result url];

      BOOL isDirectory = NO;
      if ([url isFileURL]) {
        [[NSFileManager defaultManager] fileExistsAtPath:[url path]
                                             isDirectory:&isDirectory];
      }

      if (isDirectory) {
        NSWorkspace *ws = [NSWorkspace sharedWorkspace];
        NSString *finderPath
          = [ws absolutePathForAppBundleWithIdentifier:@"com.apple.finder"];
        icon = [ws iconForFile:finderPath];
      } else {
        CFURLRef appURL = NULL;
        if (url
            && noErr == LSGetApplicationForURL((CFURLRef)url,
                                               kLSRolesViewer | kLSRolesEditor,
                                               NULL, &appURL)) {
          GTMCFAutorelease(appURL);
          icon
            = [[NSWorkspace sharedWorkspace] iconForFile:[(NSURL *)appURL path]];
        }
      }
    }
  } else {
    icon = [super displayIconForResults:results];
  }
  return icon;
}

- (BOOL)appliesToResults:(HGSResultArray *)results {
  BOOL applies = NO;
  if ([super appliesToResults:results]) {
    // If we have an icon, then we probably apply.
    applies = [self displayIconForResults:results] != nil;
  }
  return applies;
}

@end


@implementation FileSystemOpenAgainAction

// Creates the open again icon which is just two copies of an icon offset
// from one another with the background icon faded out.
- (NSImage *)openAgainIconFromImage:(NSImage *)image {
  NSInteger sizes[] = {128, 32};
  NSImage *finalImage
    = [[[NSImage alloc] initWithSize:NSMakeSize(128, 128)] autorelease];
  for (size_t i = 0; i < sizeof(sizes) / sizeof(sizes[0]); ++i) {
    NSInteger size = sizes[i];
    NSInteger quarterSize = size / 4;
    NSBitmapImageRep *imageRep
      = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                 pixelsWide:size
                                                 pixelsHigh:size
                                              bitsPerSample:8
                                            samplesPerPixel:4
                                                   hasAlpha:YES
                                                   isPlanar:NO
                                             colorSpaceName:NSCalibratedRGBColorSpace
                                                bytesPerRow:32 * size
                                               bitsPerPixel:32] autorelease];
    NSGraphicsContext *context
      = [NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:context];
    NSInteger threeQuarterSize = size - quarterSize;
    NSRect rect1 = NSMakeRect(0, quarterSize,
                              threeQuarterSize, threeQuarterSize);
    NSRect rect2 = NSMakeRect(quarterSize, 0,
                              threeQuarterSize, threeQuarterSize);
    NSRect imageRect = GTMNSRectOfSize([image size]);
    [image drawInRect:rect1
             fromRect:imageRect
            operation:NSCompositeSourceOver
             fraction:0.5];
    [image drawInRect:rect2
             fromRect:imageRect
            operation:NSCompositeSourceOver
             fraction:1.0];
    [finalImage addRepresentation:imageRep];
    [NSGraphicsContext restoreGraphicsState];
  }
  return finalImage;
}

- (id)defaultObjectForKey:(NSString *)key {
  id defaultObject = nil;
  if ([key isEqualToString:kHGSExtensionIconImageKey]) {

    IconRef iconRef = NULL;
    GetIconRef(kOnSystemDisk,
               kSystemIconsCreator,
               kGenericApplicationIcon,
               &iconRef);

    NSImage *image = nil;
    if (iconRef) {
      image = [[[NSImage alloc] initWithIconRef:iconRef] autorelease];
      image = [self openAgainIconFromImage:image];
      ReleaseIconRef(iconRef);
    }

    defaultObject = image;
  }
  if (!defaultObject) {
    defaultObject = [super defaultObjectForKey:key];
  }
  return defaultObject;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];

  NSArray *filePaths = [directObjects filePaths];

  BOOL success = YES;
  NSMutableArray *urlsToOpen
    = [NSMutableArray arrayWithCapacity:[filePaths count]];
  for (NSString *path in filePaths) {
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    [urlsToOpen addObject:fileURL];
  }
  LSLaunchURLSpec spec = {
    NULL,
    (CFArrayRef)urlsToOpen,
    NULL, kLSLaunchAsync | kLSLaunchStartClassic | kLSLaunchNewInstance,
    NULL
  };
  OSStatus status = LSOpenFromURLSpec(&spec, NULL);
  if (status) {
    HGSLog(@"Unable to open %@ (%d)", directObjects, status);
    NSBeep();
  }
  return success;
}

- (NSImage *)displayIconForResults:(HGSResultArray*)results {
  NSImage *icon = nil;
  NSUInteger resultsCount = [results count];
  if (resultsCount) {
    if (resultsCount > 1) {
      icon = [super displayIconForResults:results];
    } else {
      HGSResult *result = [results objectAtIndex:0];
      NSString *path = [result filePath];
      NSWorkspace *ws = [NSWorkspace sharedWorkspace];
      icon = [ws iconForFile:path];
    }
    icon = [self openAgainIconFromImage:icon];
  } else {
    icon = [super displayIconForResults:results];
  }
  return icon;
}

@end

@implementation FileSystemScriptAction

+ (NSAppleScript *)fileSystemActionScript {
  static NSAppleScript *fileSystemActionScript = nil;
  if (!fileSystemActionScript) {
    NSBundle *bundle = HGSGetPluginBundle();
    NSString *path = [bundle pathForResource:@"FileSystemActions"
                                      ofType:@"scpt"
                                 inDirectory:@"Scripts"];
    if (path) {
      NSURL *url = [NSURL fileURLWithPath:path];
      NSDictionary *error = nil;
      fileSystemActionScript
        = [[NSAppleScript alloc] initWithContentsOfURL:url
                                                 error:&error];
      if (error) {
        HGSLog(@"Unable to load %@. Error: %@", url, error);
      }
    } else {
      HGSLog(@"Unable to find script FileSystemActions.scpt");
    }
  }
  return fileSystemActionScript;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
     = [info objectForKey:kHGSActionDirectObjectsKey];
  NSArray *args = [directObjects filePaths];
  NSDictionary *error = nil;
  NSAppleScript *script = [FileSystemScriptAction fileSystemActionScript];
  NSString *handlerName = [self handlerName];
  NSAppleEventDescriptor *answer
    = [script gtm_executePositionalHandler:handlerName
                                parameters:[NSArray arrayWithObject:args]
                                     error:&error];
  BOOL isGood = YES;
  if (!answer || error) {
    HGSLogDebug(@"Unable to execute handler '%@': %@", handlerName, error);
    isGood = NO;
  }
  return isGood;
}

- (NSString *)handlerName {
  HGSAssert(NO, @"handlerName must be overridden by subclasses");
  return nil;
}

@end

@implementation FileSystemShowInFinderAction

- (id)defaultObjectForKey:(NSString *)key {
  id defaultObject = nil;
  if ([key isEqualToString:kHGSExtensionIconImageKey]) {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *finderPath
      = [ws absolutePathForAppBundleWithIdentifier:@"com.apple.finder"];
    defaultObject = [ws iconForFile:finderPath];
  }
  if (!defaultObject) {
    defaultObject = [super defaultObjectForKey:key];
  }
  return defaultObject;
}

- (NSString *)handlerName {
  return @"showInFinder";
}

@end

@implementation FileSystemRenameAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL wasGood = NO;
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  HGSResultArray *names
    = [info objectForKey:@"com.google.core.filesystem.action.rename.name"];
  if ([directObjects count] && [names count]) {
    HGSResult *nameResult = [names objectAtIndex:0];
    NSDictionary *value
      = [nameResult valueForKey:kHGSObjectAttributePasteboardValueKey];
    if (value) {
      NSString *name = [value objectForKey:NSStringPboardType];
      NSUInteger location = [name rangeOfString:@"."].location;
      NSFileManager *fm = [NSFileManager defaultManager];
      wasGood = YES;
      for (HGSResult *result in directObjects) {
        NSString *filePath = [result filePath];
        NSString *extension = [filePath pathExtension];
        NSString *directory = [filePath stringByDeletingLastPathComponent];
        NSString *newPath = [directory stringByAppendingPathComponent:name];
        // If the user hasn't supplied us with an extension, use the one that
        // is already there.
        if ([extension length] && (location == 0 || location == NSNotFound)) {
          newPath = [newPath stringByAppendingPathExtension:extension];
        }
        NSError *error = nil;
        if (![fm moveItemAtPath:filePath toPath:newPath error:&error]) {
          wasGood = NO;
          [NSApp presentError:error];
          break;
        }
      }
    }
  }
  return wasGood;
}

@end

@implementation FileSystemSetCommentAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL wasGood = NO;
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  HGSResultArray *comments
    = [info objectForKey:@"com.google.core.filesystem.action.setcomments.comment"];
  if ([directObjects count] && [comments count]) {
    HGSResult *commentResult = [comments objectAtIndex:0];
    NSDictionary *value
      = [commentResult valueForKey:kHGSObjectAttributePasteboardValueKey];
    if (value) {
      NSString *comment = [value objectForKey:NSStringPboardType];
      wasGood = YES;
      for (HGSResult *result in directObjects) {
        NSString *filePath = [result filePath];
        NSString *source
          = [NSString stringWithFormat:
             @"tell app \"Finder\"\r"
             @"set comment of file (posix file(\"%@\")) to \"%@\"\r"
             @"end", filePath, comment];
        NSAppleScript *script = [[NSAppleScript alloc] initWithSource:source];
        NSDictionary *error = nil;
        NSAppleEventDescriptor *desc = [script executeAndReturnError:&error];
        [script release];
        if (!desc || error) {
          wasGood = NO;
          HGSLog(@"Error Setting Comment: %@", error);
          break;
        }
      }
    }
  }
  return wasGood;
}

@end

@implementation FileSystemMoveToAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  HGSResultArray *directories
    = [info objectForKey:@"com.google.core.filesystem.action.moveto.location"];
  NSArray *froms = [directObjects filePaths];
  NSArray *tos = [directories filePaths];
  NSArray *args = [NSArray arrayWithObjects:froms, [tos objectAtIndex:0], nil];
  NSDictionary *error = nil;
  NSAppleScript *script = [FileSystemScriptAction fileSystemActionScript];
  NSString *handlerName = [self handlerName];
  NSAppleEventDescriptor *answer
    = [script gtm_executePositionalHandler:handlerName
                                parameters:args
                                     error:&error];
  BOOL isGood = YES;
  if (!answer || error) {
    HGSLogDebug(@"Unable to execute handler '%@': %@", handlerName, error);
    isGood = NO;
  }
  return isGood;
}

- (NSString *)handlerName {
  return @"moveto";
}

@end

@implementation FileSystemCopyToAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  HGSResultArray *directories
    = [info objectForKey:@"com.google.core.filesystem.action.copyto.location"];
  NSArray *froms = [directObjects filePaths];
  NSArray *tos = [directories filePaths];
  NSArray *args = [NSArray arrayWithObjects:froms, [tos objectAtIndex:0], nil];
  NSDictionary *error = nil;
  NSAppleScript *script = [FileSystemScriptAction fileSystemActionScript];
  NSString *handlerName = [self handlerName];
  NSAppleEventDescriptor *answer
    = [script gtm_executePositionalHandler:handlerName
                                parameters:args
                                     error:&error];
  BOOL isGood = YES;
  if (!answer || error) {
    HGSLogDebug(@"Unable to execute handler '%@': %@", handlerName, error);
    isGood = NO;
  }
  return isGood;
}

- (NSString *)handlerName {
  return @"copyto";
}

@end

@implementation FileSystemQuickLookAction

- (void)dealloc {
  [urls_ release];
  [super dealloc];
}

- (BOOL)causesUIContextChange {
  return NO;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
  return [urls_ count];
}

- (id)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)idx {
  NSURL *url = nil;
  if (idx < [urls_ count]) {
    url = [urls_ objectAtIndex:idx];
  } else {
    HGSLogDebug(@"%d >= max index %d in -[%@ %@]",
                idx, [urls_ count], [self class], NSStringFromSelector(_cmd));
  }
  return url;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  [urls_ autorelease];
  urls_ = [[directObjects urls] copy];
  // Need to use NSClassFromString so that we work on Leopard.
#if MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_5
#error Clean up this mess now that we don't support Leopard
#endif //  MAC_OS_X_VERSION_MIN_REQUIRED > MAC_OS_X_VERSION_10_5
  QLPreviewPanel *panel
    = [NSClassFromString(@"QLPreviewPanel") sharedPreviewPanel];
  NSLog(@"%@", panel);
  [panel setHidesOnDeactivate:NO];
  if ([GTMSystemVersion isSnowLeopardOrGreater]) {
    [panel setDataSource:self];
    [panel reloadData];
  } else {
    // SnowLeopard revamped QuickLookUI. This is a bit of a hack to convince
    // the compiler to look the other way while we call methods it doesn't
    // know about, so we can run on Leopard.
    [panel setURLs:urls_ currentIndex:0 preservingDisplayState:YES];
  }
  if (![panel isVisible]) {
    [NSApp activateIgnoringOtherApps:YES];
    [[panel windowController] setDelegate:self];

    // This makes sure we are on top of our query window
    NSWindow *theKeyWindow = [NSApp keyWindow];
    NSInteger keyLevel = [theKeyWindow level];
    [panel setLevel:keyLevel + 1];

    [panel makeKeyAndOrderFront:self];
  }
  return YES;
}

@end

@implementation FileSystemGetInfoAction

GTM_METHOD_CHECK(NSAppleScript, gtm_executePositionalHandler:parameters:error:);

- (id)defaultObjectForKey:(NSString *)key {
  id defaultObject = nil;
  if ([key isEqualToString:kHGSExtensionIconImageKey]) {
    defaultObject = [NSImage imageNamed:NSImageNameInfo];
  }
  if (!defaultObject) {
    defaultObject = [super defaultObjectForKey:key];
  }
  return defaultObject;
}

- (NSString *)handlerName {
  return @"getInfo";
}

@end

@implementation FileSystemEjectAction

- (id)defaultObjectForKey:(NSString *)key {
  id defaultObject = nil;
  if ([key isEqualToString:kHGSExtensionIconImageKey]) {

    IconRef iconRef = NULL;
    GetIconRef(kOnSystemDisk,
               kSystemIconsCreator,
               kEjectMediaIcon,
               &iconRef);

    NSImage *image = nil;
    if (iconRef) {
      image = [[[NSImage alloc] initWithIconRef:iconRef] autorelease];
      ReleaseIconRef(iconRef);
    }

    defaultObject = image;
  }
  if (!defaultObject) {
    defaultObject = [super defaultObjectForKey:key];
  }
  return defaultObject;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
     = [info objectForKey:kHGSActionDirectObjectsKey];

  NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
  NSArray *filePaths = [directObjects filePaths];

  BOOL success = YES;
  for (NSString *path in filePaths) {
    // if workspace can't do it, try the finder.
    if (![workspace unmountAndEjectDeviceAtPath:path]){
      NSString *displayName
        = [[NSFileManager defaultManager] displayNameAtPath:path];
      NSString *source = [NSString stringWithFormat:
        @"tell application \"Finder\" to eject disk \"%@\"",displayName];
      NSAppleScript *ejectScript
        = [[[NSAppleScript alloc] initWithSource:source] autorelease];
      NSDictionary *errorDict = nil;
      [ejectScript executeAndReturnError:&errorDict];
      if (errorDict) {
        NSString *error
        = [errorDict objectForKey:NSAppleScriptErrorBriefMessage];
        HGSLog(@"Error ejecting disk %@: %@", path, error);
        NSBeep();
        success = NO;
      }
    }
  }
  return success;
}

- (BOOL)appliesToResults:(HGSResultArray *)results {
  BOOL doesApply = [super appliesToResults:results];
  if (doesApply) {
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSArray *filePaths = [results filePaths];
    if (filePaths) {
      NSArray *volumes = [workspace mountedLocalVolumePaths];
      NSSet *volumesSet = [NSSet setWithArray:volumes];
      NSSet *pathsSet = [NSSet setWithArray:filePaths];
      doesApply = [pathsSet intersectsSet:volumesSet];
    } else {
      doesApply = NO;
    }
  }
  return doesApply;
}

@end
