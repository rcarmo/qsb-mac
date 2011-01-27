//
//  HGSMemorySearchSourceTest.m
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
#import "HGSMemorySearchSource.h"
#import "HGSResult.h"
#import "HGSSearchOperation.h"
#import "HGSQuery.h"
#import "HGSTokenizer.h"
#import <OCMock/OCMock.h>

@interface HGSMemorySearchSourceTest : GTMTestCase 
@end

@implementation HGSMemorySearchSourceTest
- (void)testInit {
  HGSMemorySearchSource *memSource = nil;
  memSource = [[HGSMemorySearchSource alloc] init];
  STAssertNil(memSource, nil);
  NSDictionary *config = [NSDictionary dictionary];
  memSource = [[HGSMemorySearchSource alloc] initWithConfiguration:config];
  STAssertNil(memSource, nil);
  
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  struct {
    NSString *value;
    NSString *key;
  } stubValuesAndKeys[] = {
    // things called to get an identifier
    { @"test.identifier", @"CFBundleIdentifier" },
    // things called to get a name
    { nil, @"CFBundleDisplayName" },
    { nil, @"CFBundleName" },
    { nil, @"CFBundleExecutable" },
    { @"testCopyright", @"NSHumanReadableCopyright" },
    { @"testVersion", @"CFBundleVersion" }
  };    
  for (size_t i = 0; 
       i < sizeof(stubValuesAndKeys) / sizeof(stubValuesAndKeys[0]);
       ++i) {
    [[[bundleMock expect] andReturn:stubValuesAndKeys[i].value] 
     objectForInfoDictionaryKey:stubValuesAndKeys[i].key];
    if (!stubValuesAndKeys[i].value) {
      [[[bundleMock expect] andReturn:nil] 
       pathForResource:@"QSBInfo" ofType:@"plist"];
    }
  }
  config = [NSDictionary dictionaryWithObject:bundleMock 
                                       forKey:kHGSExtensionBundleKey];
  memSource 
    = [[[HGSMemorySearchSource alloc] initWithConfiguration:config] autorelease];
  STAssertNotNil(memSource, nil);
}

- (void)testSearch {
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  struct {
    NSString *value;
    NSString *key;
  } stubValuesAndKeys[] = {
    // things called to get an identifier
    { @"test.identifier", @"CFBundleIdentifier" },
    // things called to get a name
    { nil, @"CFBundleDisplayName" },
    { nil, @"CFBundleName" },
    { nil, @"CFBundleExecutable" },
    { @"testCopyright", @"NSHumanReadableCopyright" },
    { @"testVersion", @"CFBundleVersion" }
  };    
  for (size_t i = 0; 
       i < sizeof(stubValuesAndKeys) / sizeof(stubValuesAndKeys[0]);
       ++i) {
    [[[bundleMock expect] andReturn:stubValuesAndKeys[i].value] 
     objectForInfoDictionaryKey:stubValuesAndKeys[i].key];
    if (!stubValuesAndKeys[i].value) {
      [[[bundleMock expect] andReturn:nil] 
       pathForResource:@"QSBInfo" ofType:@"plist"];
    }
  }
  NSDictionary *config 
    = [NSDictionary dictionaryWithObject:bundleMock 
                                  forKey:kHGSExtensionBundleKey];
  HGSMemorySearchSource *memSource 
    = [[[HGSMemorySearchSource alloc] initWithConfiguration:config] autorelease];
  STAssertNotNil(memSource, nil);
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSString *path
    = [ws absolutePathForAppBundleWithIdentifier:@"com.apple.finder"];
  STAssertNotNil(path, nil);
  id searchSourceMock = [OCMockObject mockForClass:[HGSSearchSource class]];
  HGSUnscoredResult *result 
    = [HGSUnscoredResult resultWithFilePath:path
                                     source:searchSourceMock
                                 attributes:nil];
  STAssertNotNil(result, nil);
  [[[searchSourceMock expect] 
    andReturn:nil] 
   provideValueForKey:kHGSObjectAttributeRankFlagsKey result:result];
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];
  [database indexResult:result
                   name:@"testName"
             otherTerms:[NSArray arrayWithObjects:@"foo", @"bar", @"bam", nil]];
  
  id searchQueryMock = [OCMockObject mockForClass:[HGSQuery class]];
  HGSCallbackSearchOperation *op 
    = [[[HGSCallbackSearchOperation alloc] initWithQuery:searchQueryMock
                                                  source:memSource] autorelease];
  HGSTokenizedString *tokenString = [HGSTokenizer tokenizeString:@"foo"]; 
  [[[searchQueryMock expect] andReturn:tokenString] tokenizedQueryString];
  [[[searchQueryMock expect] andReturn:nil] pivotObjects];
  [[[searchQueryMock expect] andReturn:nil] actionArgument];
  [memSource replaceCurrentDatabaseWith:database];
  [memSource performSearchOperation:op];
}
@end
