//
//  NSArray+CommonPrefixDetectionTest.m
//
//  Created by Alastair Tse on 2008/06/10.
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
#import "NSArray+CommonPrefixDetection.h"

@interface NSArray_HGSCommonPrefixDetectionTest : SenTestCase
@end

@implementation NSArray_HGSCommonPrefixDetectionTest

- (void)testCommonPrefixForStringsWithOptionsForwards {
  NSArray *strings 
    = [NSArray arrayWithObjects:@"abc", @"abcd", @"abd", @"ab", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:0],
              @"Got common prefix even though there are no breakers");

  strings = [NSArray arrayWithObjects:@"ab-c", @"ab-cd", @"ab-d", @"ab", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:0],
              @"Found common prefix even though it does not have a breaker");

  strings = [NSArray arrayWithObjects:@"ab-c", @"ab-cd", @"ab-d", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:0],
              @"Found prefix even though - does not have spaces around it");

  strings = [NSArray arrayWithObjects:@"", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:0], nil);

  strings = [NSArray arrayWithObjects:@"", @"", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:0], nil);

  strings = [NSArray arrayWithObjects:@"", @"", @"abc", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:0], nil);

  strings = [NSArray arrayWithObjects:
             @"Amazon - John Mayer", @"Amazon - Google", nil];
  STAssertEqualObjects([strings commonPrefixForStringsWithOptions:0],
                       @"Amazon - ",nil);
  
  strings = [NSArray arrayWithObjects:@"---", @"--", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:0],
              @"Shouldn't have found prefix");
}

- (void)testCommonPrefixForStringsWithOptionsBackwards {
  NSArray *strings = [NSArray arrayWithObjects:
                      @"xyz", @"wxyz", @"vwxyz", @"yz", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
              @"Got common prefix even though there are not breakers");

  strings = [NSArray arrayWithObjects:@"c-ab", @"cd-ab", @"d-ab", @"ab", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
              @"Found common prefix even though it does not have a breaker");

  strings = [NSArray arrayWithObjects:@"x - yz", @"w - yz", @"k - yz", nil];
  STAssertEqualObjects([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
                       @" - yz", nil);

  strings = [NSArray arrayWithObjects:
             @"amazon - a", @"amazon - a", @"amazon - a", nil];
  STAssertEqualObjects([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
                       @" - a", nil);

  strings = [NSArray arrayWithObjects:@"-a", @"-a", @"-a", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
              nil);

  strings = [NSArray arrayWithObjects:@"", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
              nil);

  strings = [NSArray arrayWithObjects:@"", @"", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
              nil);


  strings = [NSArray arrayWithObjects:@"", @"", @"abc", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
              nil);

  strings = [NSArray arrayWithObjects:
             @"blah blah | liquidx", @"ho | liquidx", nil];
  STAssertEqualObjects([strings commonPrefixForStringsWithOptions:NSBackwardsSearch],
                       @" | liquidx",
                       nil);

  strings = [NSArray arrayWithObjects:@"---", @"--", nil];
  STAssertNil([strings commonPrefixForStringsWithOptions:0],
              @"Shouldn't have found prefix");
}
@end
