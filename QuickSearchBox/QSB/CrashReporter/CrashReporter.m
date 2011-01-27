//  Copyright (c) 2010 Google Inc. All rights reserved.
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
//  Portions Copyright (c) 2004 Claus Broch, Infinite Loop. All rights reserved.

#import "CrashReporter.h"

@interface CrashReporter ()
- (void)appWillTerminate:(NSNotification*)notification;
@end

@implementation CrashReporter

@synthesize companyName = companyName_;
@synthesize url = url_;
@synthesize userInfo = userInfo_;

- (void)dealloc {
  [reporterTask_ release];
  reporterTask_ = nil;

  [self setCompanyName:nil];
  [self setUserInfo:nil];
  [self setUrl:nil];

  [super dealloc];
}


- (NSTask*)reporterTask {
  NSTask* task = [[NSTask alloc] init];

  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  NSString* path = [bundle pathForResource:@"CrashReporter" ofType:@"app"];
  path = [path stringByResolvingSymlinksInPath];
  bundle = [NSBundle bundleWithPath:path];
  path = [bundle executablePath];
  [task setLaunchPath:path];

  NSProcessInfo* procInfo = [NSProcessInfo processInfo];
  const int pid = [procInfo processIdentifier];
  NSMutableArray* args = [NSMutableArray arrayWithObjects:
              @"-pidToWatch", [NSString stringWithFormat:@"%d", pid],
              @"-company", [self companyName] ? [self companyName] : @"",
              @"-url", [self url] ? [self url] : @"",
              nil];

  if ([[self userInfo] length] > 0) {
    [args addObject:@"-userInfo"];
    [args addObject:[self userInfo]];
  }

  [task setArguments:args];

  [task launch];

  return task;
}

- (BOOL)launchReporter {
  if (!reporterTask_) {
    reporterTask_ = [[self reporterTask] retain];

    [[NSNotificationCenter defaultCenter] addObserver:self
                         selector:@selector(appWillTerminate:)
                           name:NSApplicationWillTerminateNotification
                           object:NSApp];
  }
  return [reporterTask_ isRunning];
}


- (void)appWillTerminate:(NSNotification*)notification {
  if (reporterTask_) {
    [reporterTask_ terminate];
    [reporterTask_ release];
    reporterTask_ = nil;
  }

}

@end
