//
//  QSBKeystoneRemover.m
//
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

#import <Foundation/Foundation.h>
#import <GTM/GTMScriptRunner.h>
#import <Vermilion/Vermilion.h>

// In charge of removing old keystone tickets. Does it on a timer so as to
// not get in the way of startup.

static NSString *const kKeystoneAdminPath
  = @"Google/GoogleSoftwareUpdate/GoogleSoftwareUpdate.bundle/Contents/MacOS/ksadmin";

@interface QSBKeystoneRemover : NSObject
- (void)removeKeystone:(NSTimer *)timer;
@end

@implementation QSBKeystoneRemover
+ (void)load {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  QSBKeystoneRemover *remover = [[[QSBKeystoneRemover alloc] init] autorelease];
  [NSTimer scheduledTimerWithTimeInterval:20
                                   target:remover
                                 selector:@selector(removeKeystone:)
                                 userInfo:nil
                                  repeats:NO];
  [pool release];
}

- (void)removeKeystone:(NSTimer *)timer {
  NSArray *systemLibs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                            NSAllDomainsMask,
                                                            YES);
  NSFileManager *fm = [NSFileManager defaultManager];

  for (NSString *path in systemLibs) {
    path = [path stringByAppendingPathComponent:kKeystoneAdminPath];
    if ([fm isExecutableFileAtPath:path]) {
      NSString *script = [path stringByAppendingString:@" -d -P com.google.qsb"];
      GTMScriptRunner *runner = [GTMScriptRunner runner];
      NSString *error = nil;
      NSString *output = [runner run:script standardError:&error];
      if (error && ![error isEqualToString:@"No ticket to delete"]) {
        HGSLog(@"Error running %@.\rStdout: %@\rStderr: %@",
               script, output, error);
      } else {
        break;
      }
    }
  }
}

@end
