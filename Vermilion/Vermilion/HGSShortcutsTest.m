//
//  HGSShortcutsTest.m
//  GoogleDesktop
//
//  Created by dmaclach on 6/5/07.
//  Copyright (c) 2007 Google Inc. All rights reserved.
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

#import "HGSShortcutsTest.h"
#import "HGSShortcuts.h"
#import <OCMock/OCMock.h>
#import "GDQueryClient.h"
#import "GDEventListenerProtocol.h"
#import "GDQueryResults.h"
#import "GDHyperApplication.h"
#import "GDEventListenerMock.h"

// These are copied from HGSShortcuts.m
static NSString *const kHGSShortcutsKey = @"kHGSShortcutsKey";
static NSString *const kHGSShortcutsVersionKey = @"kHGSShortcutsVersionKey";
static const int kHyperDBVersion = 2;

@implementation HGSShortcutsTest
- (void)setUp {
  // Preserve your prefs, but set them to a default state so we can test
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  savedShortcuts_ = [[defaults objectForKey:kHGSShortcutsKey] retain];
  [defaults removeObjectForKey:kHGSShortcutsKey];
  savedVersion_ = [[defaults objectForKey:kHGSShortcutsVersionKey] retain];
  [defaults removeObjectForKey:kHGSShortcutsVersionKey];
  STAssertNil([defaults objectForKey:kHGSShortcutsKey], nil);
  STAssertNil([defaults objectForKey:kHGSShortcutsVersionKey], nil);
  
  // Set up mocks
  mockEventListener_ = [[OCMockObject mockForClass:[GDEventListenerMock class]] retain];
  [[[mockEventListener_ expect] andReturn:@"1"] userPropertyForKey:kHGSShortcutsVersionKey 
                                                          authPort:OCMOCK_ANY];
  [[mockEventListener_ expect] setUserProperty:[NSString stringWithFormat:@"%d", kHyperDBVersion]
                                        forKey:kHGSShortcutsVersionKey
                                      authPort:OCMOCK_ANY];
  mockQueryClient_ = [[OCMockObject mockForClass:[GDQueryClient class]] retain];
  
  // Create db
  savedSource_ = [[NSApp distObjConnectionSource] retain];
  [NSApp setDistObjConnectionSource:self];
  db_ = [[HGSShortcuts alloc] init];
  STAssertNotNil(db_, nil);
  
  [mockEventListener_ verify];
  
  // Check to see if the version is correct
  STAssertEquals([[defaults objectForKey:kHGSShortcutsVersionKey] intValue], kHyperDBVersion, nil);
  
  // Check to see we have no defaults
  STAssertNil([defaults objectForKey:kHGSShortcutsKey], nil);
}

- (void)tearDown {
  // Restore your prefs. Even if we crash or cancel in the middle of the
  // unit test we should be ok. Worst thing I can see happening is "losing"
  // all you saved shortcuts.
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObjectForKey:kHGSShortcutsKey];
  if (savedShortcuts_) {
    [defaults setObject:savedShortcuts_ forKey:kHGSShortcutsKey];
    [savedShortcuts_ release];
  }
  [defaults removeObjectForKey:kHGSShortcutsVersionKey];
  if (savedVersion_) {
    [defaults setObject:savedVersion_ forKey:kHGSShortcutsVersionKey];
    [savedVersion_ release];
  }
  [defaults synchronize];
  
  // free up objects
  [db_ release];
  [mockQueryClient_ release];
  [mockEventListener_ release]; 
  [NSApp setDistObjConnectionSource:savedSource_];
  [savedSource_ release];

}

- (void)testResultForShortcutFailures {
  // Request a default for a shortcut
  GDQueryResult *result = [db_ resultForShortcut:@"GDHyperShortcutTest"];
  STAssertNil(result, nil);
  
  // Test bad args
  [db_ resultForShortcut:nil];
  STAssertNil(result, nil);
  [db_ resultForShortcut:@""];
  STAssertNil(result, nil);
}

- (void)testUpdateShortcutFailures {
  NSDictionary *mockQueryResult = [NSDictionary dictionary];
  
  // Test bad args
  STAssertFalse([db_ updateShortcut:nil withQueryResult:mockQueryResult], nil);
  STAssertFalse([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:nil], nil);
  STAssertFalse([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:mockQueryResult], nil);
  STAssertFalse([db_ updateShortcut:@"" withQueryResult:mockQueryResult], nil);
  
  // Test documentTokenForToken failure
  NSDictionary *mockQueryResult1 = [NSDictionary dictionaryWithObject:@"resultToken1" forKey:@"kGDQueryResultToken"];
  [[[mockQueryClient_ expect] andReturn:nil] documentTokenForToken:@"resultToken1"];
  STAssertFalse([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:mockQueryResult1], nil);
}

- (void)testSucesses {
  GDQueryResult *mockQueryResult1 = [NSDictionary dictionaryWithObjectsAndKeys:
    @"resultToken1", @"kGDQueryResultToken",
    @"http://www.google.com", @"kGDQueryResultLink",
    nil];
  GDQueryResult *mockQueryResult2 = [NSDictionary dictionaryWithObjectsAndKeys:
    @"resultToken2", @"kGDQueryResultToken",
    @"http://www.dave.com", @"kGDQueryResultLink",
    nil];
  GDQueryResult *mockQueryResult3 = [NSDictionary dictionaryWithObjectsAndKeys:
    @"resultToken3", @"kGDQueryResultToken",
    @"http://www.dumb.com", @"kGDQueryResultLink",
    nil];
  
  // 1 Test add and find
  [[[mockQueryClient_ expect] andReturn:@"documentToken1"] documentTokenForToken:@"resultToken1"];
  [[[mockQueryClient_ expect] andReturn:@"resultToken1"] tokenForDocumentToken:@"documentToken1"];
  [[[mockQueryClient_ expect] andReturn:mockQueryResult1] eventPropertiesForToken:@"resultToken1" 
                                                                            query:@"gdhypershortcuttest"];
  STAssertTrue([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:mockQueryResult1], nil);
  GDQueryResult *result = [db_ resultForShortcut:@"GDHyperShortcutTest"];
  STAssertEquals(result, mockQueryResult1, nil);
  
  // 2 Test add another and find
  [[[mockQueryClient_ expect] andReturn:@"documentToken2"] documentTokenForToken:@"resultToken2"];
  [[[mockQueryClient_ expect] andReturn:@"resultToken1"] tokenForDocumentToken:@"documentToken1"];
  [[[mockQueryClient_ expect] andReturn:mockQueryResult1] eventPropertiesForToken:@"resultToken1"
                                                                            query:@"gdhypershortcuttest"];

  STAssertTrue([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:mockQueryResult2], nil);
  result = [db_ resultForShortcut:@"GDHyperShortcutTest"];
  STAssertEquals(result, mockQueryResult1, nil);

  // 3 Test add another and find again
  [[[mockQueryClient_ expect] andReturn:@"documentToken2"] documentTokenForToken:@"resultToken2"];
  [[[mockQueryClient_ expect] andReturn:@"resultToken2"] tokenForDocumentToken:@"documentToken2"];
  [[[mockQueryClient_ expect] andReturn:mockQueryResult2] eventPropertiesForToken:@"resultToken2" 
                                                                            query:@"gdhypershortcuttest"];

  STAssertTrue([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:mockQueryResult2], nil);
  result = [db_ resultForShortcut:@"GDHyperShortcutTest"];
  STAssertEquals(result, mockQueryResult2, nil);
  
  // 4 Test add original and find
  [[[mockQueryClient_ expect] andReturn:@"documentToken1"] documentTokenForToken:@"resultToken1"];
  [[[mockQueryClient_ expect] andReturn:@"resultToken1"] tokenForDocumentToken:@"documentToken1"];
  [[[mockQueryClient_ expect] andReturn:mockQueryResult1] eventPropertiesForToken:@"resultToken1" 
                                                                            query:@"gdhypershortcuttest"];

  STAssertTrue([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:mockQueryResult1], nil);
  result = [db_ resultForShortcut:@"GDHyperShortcutTest"];
  STAssertEquals(result, mockQueryResult1, nil);

  // 5 Test add yet another twice and find it
  [[[mockQueryClient_ expect] andReturn:@"documentToken3"] documentTokenForToken:@"resultToken3"];
  [[[mockQueryClient_ expect] andReturn:@"documentToken3"] documentTokenForToken:@"resultToken3"];
  [[[mockQueryClient_ expect] andReturn:@"resultToken3"] tokenForDocumentToken:@"documentToken3"];
  [[[mockQueryClient_ expect] andReturn:mockQueryResult3] eventPropertiesForToken:@"resultToken3" 
                                                                            query:@"gdhypershortcuttest"];

  STAssertTrue([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:mockQueryResult3], nil);
  STAssertTrue([db_ updateShortcut:@"GDHyperShortcutTest" withQueryResult:mockQueryResult3], nil);
  result = [db_ resultForShortcut:@"GDHyperShortcutTest"];
  STAssertEquals(result, mockQueryResult3, nil);

  // 6 Test diacriticals and case
  [[[mockQueryClient_ expect] andReturn:@"resultToken3"] tokenForDocumentToken:@"documentToken3"];
  [[[mockQueryClient_ expect] andReturn:mockQueryResult3] eventPropertiesForToken:@"resultToken3" 
                                                                            query:@"gdhypershortcuttest"];

  NSString *shortcut = [NSString stringWithUTF8String:"GDhYpérShörtCûtTèsT"];
  result = [db_ resultForShortcut:shortcut];
  STAssertEquals(result, mockQueryResult3, nil);
  [mockQueryClient_ verify];
}

// Delegate methods required to support unittesting HGSShortcuts
- (GDQueryClient*)queryClient {
  return (GDQueryClient*)mockQueryClient_;
}

- (GMTransientRootProxy<GDEventListenerProtocol>*)eventListener {
  return (GMTransientRootProxy<GDEventListenerProtocol>*)mockEventListener_;
}
  
- (GDStatsClient*)statsClient {
  STFail(@"No statsClient should be requested from hyperdb tests");
  return nil;
}
@end
