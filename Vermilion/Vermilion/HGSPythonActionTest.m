//
//  HGSPythonActionTest.m
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


#import "GTMSenTestCase.h"
#import "HGSPythonAction.h"
#import "HGSResult.h"
#import "HGSType.h"
#import "HGSUserMessage.h"

@interface HGSPythonActionTest : GTMTestCase {
 @private
  int notificationCount_;
}
- (void)displayUserMessage:(NSNotification *)notification;
@end

@implementation HGSPythonActionTest

- (void)testAction {
  HGSPython *sharedPython = [HGSPython sharedPython];
  STAssertNotNil(sharedPython, nil);
  
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  [sharedPython appendPythonPath:[bundle resourcePath]];
  
  NSDictionary *config = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"VermilionTest", kPythonModuleNameKey,
                          @"VermilionAction", kPythonClassNameKey,
                          @"python.test", kHGSExtensionIdentifierKey,
                          @"*", @"HGSActionDirectObjectTypes",
                          bundle, kHGSExtensionBundleKey,
                          nil];
  STAssertNotNil(config, nil);

  HGSPythonAction *action
    = [[[HGSPythonAction alloc] initWithConfiguration:config] autorelease];
  STAssertNotNil(action, nil);
  
  HGSScoredResult *result 
    = [HGSScoredResult resultWithURI:@"http://www.google.com/"
                                name:@"Google"
                                type:kHGSTypeWebBookmark
                              source:nil
                          attributes:nil
                               score:0
                               flags:0
                         matchedTerm:nil
                      matchedIndexes:nil];
  STAssertNotNil(result, nil);
  HGSResultArray *results = [HGSResultArray arrayWithResult:result];
  STAssertNotNil(results, nil);
  
  STAssertTrue([action appliesToResults:results], nil);
  
  NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                        results, kHGSActionDirectObjectsKey, nil];
  STAssertNotNil(info, nil);
  
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];  
  [nc addObserver:self 
         selector:@selector(displayUserMessage:) 
             name:kHGSUserMessageNotification 
           object:nil];
  notificationCount_ = 0;
  STAssertTrue([action performWithInfo:info], nil);
  
  // We have 6 here, because we increment notificationCount_ by one for each
  // argument passed to it. The first call we make only passes one arg, the
  // second call passes two. The third call passes 3.
  STAssertEquals(notificationCount_, 6, nil);
  [nc removeObserver:self name:kHGSUserMessageNotification object:nil];
  STAssertNotNil([action directObjectTypeFilter], nil);
}

- (void)displayUserMessage:(NSNotification *)notification {
  NSDictionary *userInfo = [notification userInfo];
  NSString *message = [userInfo objectForKey:kHGSSummaryMessageKey];
  STAssertNotNil(message, nil);
  NSString *description = [userInfo objectForKey:kHGSDescriptionMessageKey];
  if (description) {
    ++notificationCount_;
  }
  NSString *name = [userInfo objectForKey:kHGSNameMessageKey];
  if (name) {
    ++notificationCount_;
  }
  NSImage *image = [userInfo objectForKey:kHGSImageMessageKey];
  STAssertNotNil(image, nil);
  
  ++notificationCount_;
}

// TODO(dmaclach): Add test that returns results from python action.

@end
