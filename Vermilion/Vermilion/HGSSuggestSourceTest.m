//
//  HGSSuggestSourceTest.m
//  GoogleMobile
//
//  Created by Alastair Tse on 2008/03/19.
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

#import "GTMSenTestCase.h"

#import <Foundation/Foundation.h>
#import <JSON/JSON.h>

#import "HGSSuggestSource.h"
#import "HGSBundle.h"

@interface HGSSuggestSourceTest : GTMTestCase {
 @private
  HGSSuggestSource *source_;
}

@end

@interface HGSSuggestSource (PrivateMethods)
- (NSArray *)responseWithJSONData:(NSData *)responseData;
- (NSMutableArray *)suggestionsWithResponse:(NSArray *)response
                                  withQuery:(HGSQuery *)query;
@end

@implementation HGSSuggestSourceTest

- (void)setUp {
  NSDictionary *configDict 
    = [NSDictionary dictionaryWithObjectsAndKeys:
       HGSGetPluginBundle(), kHGSExtensionBundleKey,
       @"com.google.qsb.core.suggest.source.test", kHGSExtensionIdentifierKey,
       @"Suggest Test", kHGSExtensionUserVisibleNameKey,
       @"text.suggestion", kHGSSearchSourceSupportedTypesKey,
       nil];
  source_ = [[HGSSuggestSource alloc] initWithConfiguration:configDict];
  STAssertNotNil(source_, nil);
}

- (void)tearDown {
  [source_ release];
  source_ = nil;
}

//
// Tests
//


- (void)testSuggestionsWithResponseWithQuery {
  NSMutableArray *results = nil;
  HGSSuggestSource *suggestSource = (HGSSuggestSource*)source_;
  results = [suggestSource suggestionsWithResponse:nil withQuery:nil];
  STAssertNotNil(results, nil);
  STAssertEquals([results count], (NSUInteger)0, nil);

  results = [suggestSource suggestionsWithResponse:[NSArray array]
                                         withQuery:nil];
  STAssertNotNil(results, nil);
  STAssertEquals([results count], (NSUInteger)0, nil);

  NSArray* noResultResponse = [NSArray arrayWithObject:[NSString string]];
  results = [suggestSource suggestionsWithResponse:noResultResponse
                                         withQuery:nil];
  STAssertNotNil(results, nil);
  STAssertEquals([results count], (NSUInteger)0, nil);

  NSArray* nonStringQueryResponse = [NSArray arrayWithObjects:
    [NSNumber numberWithInt:0],
    [NSArray array],
    nil];
  results = [suggestSource suggestionsWithResponse:nonStringQueryResponse
                                         withQuery:nil];
  STAssertNotNil(results, nil);
  STAssertEquals([results count], (NSUInteger)0, nil);
}

- (void)testResponseWithJSONData {
  HGSSuggestSource* source = (HGSSuggestSource*)source_;
  // Invalid JSON responses that should return an empty array.
  NSDictionary *emptyTestCases = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSArray array], @"",
    [NSArray array], @" ",
    [NSArray array], @" [",                // Malformed JSON
    [NSArray array], @" [] ",              // Whitespace and empty array.
    [NSArray array], @"[]",                // Empty array
    [NSArray array], @"[\"test\"]",        // Less than 2 elements in array.
    [NSArray array], @"<html></html>",     // Malformed request
    nil];

  NSArray *expectedResult = nil;
  NSArray *actualResult = nil;
  for (NSString *testString in [emptyTestCases allKeys]) {
    NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
    expectedResult = nil;
    if ([emptyTestCases objectForKey:testString] != [NSNull null]) {
      expectedResult = [emptyTestCases objectForKey:testString];
    }
    actualResult = [source responseWithJSONData:testData];
    STAssertEqualObjects(expectedResult, actualResult,
                         @"Expected: %@ Actual: %@",
                         expectedResult,
                         actualResult);
  }

  // Valid JSON response that should be parsed properly.
  NSString *noSuggest = @"[\"test\", []]";
  NSString *noResponse = [NSArray arrayWithObjects:@"test", [NSArray array], nil];
  NSString *oneSuggest = @"[\"q\",[[\"quote aapl\",\"3,040,000 results\",\"1\"]]]";
  NSArray *oneResponse = [NSArray arrayWithObjects:
    @"q",
    [NSArray arrayWithObjects:
      [NSArray arrayWithObjects:@"quote aapl", @"3,040,000 results", @"1", nil],
      nil],
    nil];

  NSString *twoSuggest = @"[\"q\",[[\"quote aapl\",\"3,040,000 results\",\"1\"],[\"quote goog\",\"495,000 results\",\"2\"]]]";
  NSArray *twoResponse = [NSArray arrayWithObjects:
    @"q",
    [NSArray arrayWithObjects:
     [NSArray arrayWithObjects:@"quote aapl", @"3,040,000 results", @"1", nil],
     [NSArray arrayWithObjects:@"quote goog", @"495,000 results", @"2", nil],
     nil],
    nil];

  NSDictionary *testCases = [NSDictionary dictionaryWithObjectsAndKeys:
    noResponse, noSuggest,
    oneResponse, oneSuggest,
    twoResponse, twoSuggest,
    nil];

  for (NSString *testString in [testCases allKeys]) {
    NSData *testData = [testString dataUsingEncoding:NSUTF8StringEncoding];
    expectedResult = nil;
    if ([testCases objectForKey:testString] != [NSNull null]) {
      expectedResult = [testCases objectForKey:testString];
    }
    actualResult = [source responseWithJSONData:testData];
    STAssertEqualObjects(expectedResult, actualResult,
                         @"Expected: %@ Actual: %@",
                         expectedResult,
                         actualResult);
  }

  // Non-ASCII responses
  NSString *nonAsciiResponse = @"[\"a\",[[\"av女郎\",\"473,500 results\",\"4\"],[\"av图片\",\"489,200 results\",\"5\"]]]";
  actualResult = [source responseWithJSONData:[nonAsciiResponse dataUsingEncoding:NSUTF8StringEncoding]];
  STAssertNotNil(actualResult, @"Failed to parse");
  STAssertEquals([actualResult count], (NSUInteger)2, @"Mismatched return size");
  NSArray *firstSuggest = [[actualResult objectAtIndex:1] objectAtIndex:0];
  STAssertEqualObjects([firstSuggest objectAtIndex:0],
                       @"av女郎",
                       @"Mismatched title: %@",
                       [firstSuggest objectAtIndex:0]);
}

@end
