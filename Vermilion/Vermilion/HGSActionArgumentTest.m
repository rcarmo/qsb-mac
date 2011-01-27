//
//  HGSActionArgumentTest.m
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

#import "GTMSenTestCase.h"

#import <OCMock/OCMock.h>

#import "HGSActionArgument.h"
#import "HGSType.h"
#import "HGSTypeFilter.h"
#import "HGSBundle.h"
#import "HGSResult.h"
#import "HGSQuery.h"

static NSString *const kActionArgumentTestIdentifier = @"FooActionArgument";

@interface HGSActionArgumentTest : GTMTestCase
@end

@implementation HGSActionArgumentTest

- (void)testActionArgumentCreation {
  NSBundle *bundle = HGSGetPluginBundle();
  NSDictionary *config = [NSDictionary dictionary];
  STAssertNil([[[HGSActionArgument alloc] 
                initWithConfiguration:config] autorelease], nil);
  
  config = [NSDictionary dictionaryWithObjectsAndKeys:
            kActionArgumentTestIdentifier, kHGSActionArgumentIdentifierKey, nil];
  STAssertNil([[[HGSActionArgument alloc] 
                initWithConfiguration:config] autorelease], nil);
  
  config = [NSDictionary dictionaryWithObjectsAndKeys:
            kHGSTypeFile, kHGSActionArgumentSupportedTypesKey,
            nil];
  STAssertNil([[[HGSActionArgument alloc] 
                initWithConfiguration:config] autorelease], nil);

  config = [NSDictionary dictionaryWithObjectsAndKeys:
            kActionArgumentTestIdentifier, kHGSActionArgumentIdentifierKey, 
            kHGSTypeFile, kHGSActionArgumentSupportedTypesKey,
            nil];
  STAssertNil([[[HGSActionArgument alloc] 
                initWithConfiguration:config] autorelease], nil);
  
  config = [NSDictionary dictionaryWithObjectsAndKeys:
            kActionArgumentTestIdentifier, kHGSActionArgumentIdentifierKey, 
            kHGSTypeFile, kHGSActionArgumentSupportedTypesKey,
            bundle, kHGSActionArgumentBundleKey,
            nil];
  HGSActionArgument *arg = [[[HGSActionArgument alloc] 
                             initWithConfiguration:config] autorelease];
  STAssertNotNil(arg, nil);
  
  // Verify requireds
  STAssertEqualObjects([arg identifier], kActionArgumentTestIdentifier, nil);
  STAssertTrue([[arg typeFilter] isValidType:kHGSTypeTextFile], nil);
  STAssertFalse([[arg typeFilter] isValidType:kHGSTypeWebBookmark], nil);
  
  // Verify optionals
  STAssertFalse([arg isOptional], nil);
  STAssertNil([arg displayName], nil);
  STAssertNil([arg displayDescription], nil);
  STAssertNil([arg displayOtherTerms], nil);
  
  // Must have a display name for an optional
  config = [NSDictionary dictionaryWithObjectsAndKeys:
            kActionArgumentTestIdentifier, kHGSActionArgumentIdentifierKey, 
            kHGSTypeFile, kHGSActionArgumentSupportedTypesKey,
            bundle, kHGSActionArgumentBundleKey,
            [NSNumber numberWithBool:YES], kHGSActionArgumentOptionalKey,
            nil];
  arg = [[[HGSActionArgument alloc] 
          initWithConfiguration:config] autorelease];
  STAssertNil(arg, nil);
 
  config = [NSDictionary dictionaryWithObjectsAndKeys:
            kActionArgumentTestIdentifier, kHGSActionArgumentIdentifierKey, 
            kHGSTypeFile, kHGSActionArgumentSupportedTypesKey,
            bundle, kHGSActionArgumentBundleKey,
            [NSNumber numberWithBool:YES], kHGSActionArgumentOptionalKey,
            @"foo", kHGSActionArgumentUserVisibleNameKey,
            nil];
  arg = [[[HGSActionArgument alloc] 
          initWithConfiguration:config] autorelease];
  STAssertNotNil(arg, nil);
}

- (void)testLoadFromPlist {
  NSBundle *bundle = HGSGetPluginBundle();
  NSArray *tests = [bundle objectForInfoDictionaryKey:@"HGSActionArgumentTests"];
  STAssertNotNil(tests, nil);
  NSMutableDictionary *test1 = [[[tests objectAtIndex:0] mutableCopy] autorelease];
  [test1 setObject:bundle forKey:@"HGSActionArgumentBundle"];
  
  HGSActionArgument *arg = [[[HGSActionArgument alloc] 
                             initWithConfiguration:test1] autorelease];
  // Verify requireds
  STAssertEqualObjects([arg identifier], @"testActionArgument", nil);
  STAssertTrue([[arg typeFilter] isValidType:kHGSTypeFileApplication], nil);
  STAssertFalse([[arg typeFilter] isValidType:kHGSTypeTextFile], nil);
  
  // Verify optionals
  STAssertTrue([arg isOptional], nil);
  STAssertEqualObjects([arg displayName], @"File", nil);
  STAssertEqualObjects([arg displayDescription], 
                       @"The file you want to manipulate.", nil);
  NSSet *otherTerms = [NSSet setWithObjects:@"Document", @"Doohickey", nil];
  STAssertEqualObjects([arg displayOtherTerms], otherTerms, nil);

  id result = [OCMockObject mockForClass:[HGSScoredResult class]];
  id query = [OCMockObject mockForClass:[HGSQuery class]];
  [arg willScoreForQuery:query];
  HGSScoredResult *newResult = [arg scoreResult:result 
                                       forQuery:query];
  [arg didScoreForQuery:query];
  STAssertEquals(result, newResult, nil);
}

@end
