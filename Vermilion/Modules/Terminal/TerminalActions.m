//
//  TerminalActions.m
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
#import "GTMNSAppleScript+Handler.h"

static NSAppleScript *sTerminalAppleScript;

@interface TerminalAction : HGSAction

- (NSAppleScript *)appleScript;

@end

@interface TerminalShowDirectoryAction : TerminalAction
@end

@interface TerminalExecuteInShellAction : TerminalAction
@end

static NSString *const kTerminalBundleID = @"com.apple.Terminal";

@implementation TerminalAction

- (id)defaultObjectForKey:(NSString *)key {
  id defaultObject = nil;
  if ([key isEqualToString:kHGSExtensionIconImageKey]) {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSString *terminalPath
      = [ws absolutePathForAppBundleWithIdentifier:kTerminalBundleID];
    NSImage *icon = [ws iconForFile:terminalPath]; 
    defaultObject = icon;
  }
  if (!defaultObject) {
    defaultObject = [super defaultObjectForKey:key];
  }
  return defaultObject;
}

- (NSAppleScript *)appleScript {
  @synchronized(self) {
    if (!sTerminalAppleScript) {
      NSString *path = [[self bundle] pathForResource:@"Terminal"
                                               ofType:@"scpt"
                                          inDirectory:@"Scripts"];
      NSURL *url = [NSURL fileURLWithPath:path];
      sTerminalAppleScript = [[NSAppleScript alloc] initWithContentsOfURL:url
                                                                    error:nil];
    }
  }
  return sTerminalAppleScript;
}

@end

@implementation TerminalShowDirectoryAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  NSArray *paths = [directObjects filePaths];
  NSArray *parameters = [NSArray arrayWithObject:paths];
  NSDictionary *errorDictionary = nil;
  [[self appleScript] gtm_executePositionalHandler:@"openDirectory"
                                        parameters:parameters
                                             error:&errorDictionary];
  
  if (errorDictionary) {
    HGSLog(@"error: %@", errorDictionary);
    return NO;
  }  
  return YES;
}

@end

@implementation TerminalExecuteInShellAction

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  for (HGSResult *result in directObjects) {
    NSDictionary *value 
      = [result valueForKey:kHGSObjectAttributePasteboardValueKey];
    if (value) {
      NSString *script = [value objectForKey:NSStringPboardType];
      NSArray *parameters = [NSArray arrayWithObject:script];
      NSDictionary *errorDictionary = nil;
      [[self appleScript] gtm_executePositionalHandler:@"doScript"
                                            parameters:parameters
                                                 error:&errorDictionary];
      if (errorDictionary) {
        HGSLog(@"error: %@", errorDictionary);
        return NO;
      }
    }
  }
  return YES;
}

@end

