//
//  HGSPluginBlacklistTest.m
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
#import "HGSPluginBlacklist.h"

@interface HGSPluginBlacklistTest : GTMTestCase {
 @private
  NSString *savedBlacklistPath_;
  BOOL updated_;
}
@end

static NSString *kBlacklistItem1 = @"com.example.blacklist.super.malware.plus";
static NSString *kBlacklistItem2 = @"com.example.blacklist.sneaky.ads";
static NSString *kBlackListXml =
  @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
   "<blacklist version=\"1.0\">\n"
   "\n"
   "<plugin>\n"
   "<title>Super Malware Plus</title>\n"
   "<description>Steals your credit card numbers and passwords</description>\n"
   "<guid>com.example.blacklist.super.malware.plus</guid>\n"
   "</plugin>\n"
   "\n"
   "<plugin>\n"
   "<title>Sneaky Ads</title>\n"
   "<description>Slips pop-up ads onto your system</description>\n"
   "<guid>com.example.blacklist.sneaky.ads</guid>\n"
   "</plugin>\n"
   "\n"
   "</blacklist>";

@implementation HGSPluginBlacklistTest

- (void)setUp {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self selector:@selector(feedChanged:)
                           name:kHGSBlacklistUpdatedNotification
                         object:nil];
}

- (void)tearDown {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)testUpdateFeed {
  HGSPluginBlacklist *bl = [[[HGSPluginBlacklist alloc] init] autorelease];
  STAssertNotNil(bl, nil);
  
  STAssertFalse([bl bundleIDIsBlacklisted:kBlacklistItem1], nil);
  STAssertFalse([bl bundleIDIsBlacklisted:kBlacklistItem2], nil);

  [bl updateBlacklistWithData:[kBlackListXml
                               dataUsingEncoding:NSUTF8StringEncoding]];

  STAssertTrue(updated_, nil);
  
  STAssertTrue([bl bundleIDIsBlacklisted:kBlacklistItem1], nil);
  STAssertTrue([bl bundleIDIsBlacklisted:kBlacklistItem2], nil);
  STAssertFalse([bl bundleIDIsBlacklisted:@"com.google.qsb.plugin.Other"], nil);
}

- (void)feedChanged:(NSNotification*)note {
  updated_ = YES;
}

@end
