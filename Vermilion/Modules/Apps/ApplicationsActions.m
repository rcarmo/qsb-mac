//
//  ApplicationsActions.m
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
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
#import "GTMNSWorkspace+Running.h"
#import "GTMMethodCheck.h"
#import "GTMGarbageCollection.h"
#import "HGSLog.h"
#import <Carbon/Carbon.h>

@interface ApplicationsAction : HGSAction
@end

@interface ApplicationsQuitAction : ApplicationsAction
@end

@interface ApplicationsForceQuitAction : ApplicationsAction
@end

@interface ApplicationsQuitOthersAction : ApplicationsAction
@end

@interface ApplicationsHideAction : ApplicationsAction
@end

@interface ApplicationsHideOthersAction : ApplicationsAction
@end


@implementation ApplicationsAction
GTM_METHOD_CHECK(NSWorkspace, gtm_launchedApplications);

- (BOOL)appliesToResult:(HGSResult *)result {
  NSArray *apps = [[NSWorkspace sharedWorkspace] gtm_launchedApplications];
  NSString *resultPath = [result filePath];
  for (NSDictionary *app in apps) {
    NSString *path = [app objectForKey:@"NSApplicationPath"];
    if ([resultPath isEqual:path]) {
      return YES;
    }
  }
  return NO;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  return NO; 
}

- (NSArray *)appDictionariesForPaths:(NSArray *)paths {
  NSArray *apps = [[NSWorkspace sharedWorkspace] gtm_launchedApplications];
  NSArray *appsPaths = [apps valueForKey:@"NSApplicationPath"];
  NSDictionary *pathMap = [NSDictionary dictionaryWithObjects:apps 
                                                      forKeys:appsPaths];
  return [pathMap objectsForKeys:paths notFoundMarker:[NSNull null]];
}

- (BOOL)PSN:(ProcessSerialNumber *)psn forApplication:(NSDictionary *)theApp {
  if (!theApp) return NO;
  psn->highLongOfPSN
    = [[theApp objectForKey:@"NSApplicationProcessSerialNumberHigh"] intValue];
  psn->lowLongOfPSN
    = [[theApp objectForKey:@"NSApplicationProcessSerialNumberLow"] intValue];
  return (psn->lowLongOfPSN != 0 || psn->highLongOfPSN != 0);
}

- (BOOL)quitPSN:(ProcessSerialNumber)psn {
  AppleEvent event = {typeNull, 0};
  AEBuildError error;
  
  OSStatus err = AEBuildAppleEvent(kCoreEventClass, kAEQuitApplication, 
                                   typeProcessSerialNumber,
                                   &psn, sizeof(ProcessSerialNumber), 
                                   kAutoGenerateReturnID, 
                                   kAnyTransactionID,
                                   &event, &error, "");
  if (err == noErr) {
    err = AESend(&event, NULL,
                 kAENoReply, kAENormalPriority, kAEDefaultTimeout,
                 NULL, NULL);
  }

  if (err) {
    HGSLogDebug(@"Error quitting process %d", err);  
  }

  return err == noErr;
}

- (BOOL)hideApplications:(NSArray *)theApps {    
  for (NSDictionary *theApp in theApps) {
    ProcessSerialNumber psn;
    if ([self PSN:&psn forApplication:theApp])
      ShowHideProcess(&psn, FALSE);
  }
  return YES;
}

- (BOOL)hideOtherApplications:(NSArray *)theApps { 
  NSUInteger count = [theApps count];
  ProcessSerialNumber *psn = calloc(sizeof(ProcessSerialNumber), count);
  if (!psn) return NO;
  for (NSUInteger i = 0; i < count; i++) {
    [self PSN:psn+i forApplication:[theApps objectAtIndex:i]];
  }
  // TODO(alcor): first open the primary app (to avoid constant switching)
  //[self switchToApplication:theApp frontWindowOnly:YES];
  
  ProcessSerialNumber thisPSN;
  thisPSN.highLongOfPSN = kNoProcess;
  thisPSN.lowLongOfPSN = 0;
  Boolean show = NO;  // Initialize with default so CLANG is happy
  while(GetNextProcess(&thisPSN) == noErr) {
    for (NSUInteger i = 0; i < count; i++) {
      OSStatus err = SameProcess(&thisPSN, psn + i, &show);
      if (err != noErr) continue;
      if (show) break;
    }
    OSStatus err = ShowHideProcess(&thisPSN, show);
    if(err != noErr) {
      HGSLogDebug(@"Unable to hide process %d", err);
    }
  } 
  free(psn);
  return YES;
}

- (BOOL)quitApplication:(NSDictionary *)theApp {
  ProcessSerialNumber psn;
  if (![self PSN:&psn forApplication:theApp]) return NO;
  return [self quitPSN:psn];
}

- (BOOL)quitOtherApplications:(NSArray *)theApps { 
  NSUInteger count = [theApps count];
  ProcessSerialNumber *psn = calloc(sizeof(ProcessSerialNumber), count);
  if (!psn) return NO;
  for (NSUInteger i = 0; i < count; i++) {
    [self PSN:psn+i forApplication:[theApps objectAtIndex:i]];
  }
  // TODO(alcor): first open the primary app (to avoid constant switching)
  //[self reopenApplication:theApp];
  ProcessSerialNumber thisPSN;
  thisPSN.highLongOfPSN = kNoProcess;
  thisPSN.lowLongOfPSN = 0;
  Boolean show = NO;
  ProcessSerialNumber myPSN;
  MacGetCurrentProcess(&myPSN);
  
  while(GetNextProcess(&thisPSN) == noErr) {
    NSDictionary *dict
      = GTMCFAutorelease(ProcessInformationCopyDictionary(&thisPSN,
                           kProcessDictionaryIncludeAllInformationMask));
    BOOL background = [[dict objectForKey:@"LSUIElement"] boolValue]
      || [[dict objectForKey:@"LSBackgroundOnly"] boolValue];
    if (background) continue;
    NSString *name;
    OSStatus err = CopyProcessName(&thisPSN, (CFStringRef *)&name);
    
    if (err != noErr) HGSLogDebug(@"Unable to get process name %d", err);
    if ([[name autorelease] isEqualToString:@"Finder"]) continue;
    
    SameProcess(&thisPSN, &myPSN, &show);
    if (show) continue;
    
    for (NSUInteger i = 0; i < count; i++) {
      err = SameProcess(&thisPSN, psn+i, &show);
      if (err) continue;
      if (show) break;
    }
    if (!show) {
      [self quitPSN:thisPSN];
    }
  }
  free(psn);
  return YES;
}

- (BOOL)forceQuitApplications:(NSArray *)theApps {
  for (NSDictionary *theApp in theApps) {
    pid_t pid
      = [[theApp objectForKey:@"NSApplicationProcessIdentifier"] intValue];
    OSStatus err = kill(pid, SIGKILL);
    
    if (err != noErr) HGSLogDebug(@"Unable to kill app %d %d", pid, err);
  }
  return YES;
}

@end

@implementation ApplicationsQuitAction
- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL quit = NO;
  
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *result in directObjects) {
    NSString *path = [result filePath];
    NSString *bundleID = [[NSBundle bundleWithPath:path] bundleIdentifier];
    const char *bundleIDUTF8 = [bundleID UTF8String];
    if (bundleIDUTF8) {
      AppleEvent event;
      if (AEBuildAppleEvent(kCoreEventClass, kAEQuitApplication,
                            typeApplicationBundleID, bundleIDUTF8,
                            strlen(bundleIDUTF8), kAutoGenerateReturnID,
                            kAnyTransactionID, &event, NULL, "") == noErr) {
        AppleEvent reply;
        if (AESendMessage(&event, &reply, kAENoReply,
                          kAEDefaultTimeout) == noErr) {
          quit = YES;
        }
        AEDisposeDesc(&event);
      }
    }
  }
  
  return quit;
}
@end

@implementation ApplicationsForceQuitAction
- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];  
  NSArray *paths = [directObjects filePaths];  
  return [self forceQuitApplications:[self appDictionariesForPaths:paths]];  
}
@end

@implementation ApplicationsQuitOthersAction
- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];  
  NSArray *paths = [directObjects filePaths];  
  return [self quitOtherApplications:[self appDictionariesForPaths:paths]];  
}
@end

@implementation ApplicationsHideAction
- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];  
  NSArray *paths = [directObjects filePaths];  
  return [self hideApplications:[self appDictionariesForPaths:paths]];  
}
@end

@implementation ApplicationsHideOthersAction
- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];  
  NSArray *paths = [directObjects filePaths];  
  return [self hideOtherApplications:[self appDictionariesForPaths:paths]];  
}
@end


