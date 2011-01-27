//
//  HGSTokenizerTest.m
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

#import <Foundation/Foundation.h>
#import "GTMSenTestCase.h"

#import "HGSTokenizer.h"

#define kHGSTokenizerTestMapSize 5
@interface HGSTokenizerTest : GTMTestCase
@end

@implementation HGSTokenizerTest

- (void)testInit {
  STAssertNil([HGSTokenizer tokenizeString:nil], nil);
  STAssertNotNil([HGSTokenizer tokenizeString:@""], nil);
}

- (void)testTokenize {
  HGSTokenizedString *tokenizedString 
    = [HGSTokenizer tokenizeString:@"this, this is a test."];
  STAssertEqualObjects([tokenizedString tokenizedString], 
                       @"this˽this˽is˽a˽test", nil);

  // now bang through a few different cases
  struct {
    NSString *string;
    NSString *tokenized;
    struct {
      NSUInteger domain;
      NSUInteger codomain;
    } mapping[kHGSTokenizerTestMapSize];
  } testData[] = {
    {
      // camelcase
      @"MacPython2.4",
      @"mac˽python˽2.4",
      { {0, 0 }, { 1, 1 }, { 5, 4 }, { 11, 9 }, { 3, NSNotFound } }
    },
    {
      @"NSStringFormatter",
      @"ns˽string˽formatter",
      { {0, 0 }, { 1, 1 }, { 3 , 2 }, { 10, 8 }, { 9, NSNotFound } }
    },
    {
      // format: query, words, nil.  a final nil ends all tests.
      @"ABC 123 A1B2C3 ABC-123 ABC_123 A#B A1.2b",
      @"abc˽123˽a˽1˽b˽2˽c˽3˽abc˽123˽abc˽123˽a˽b˽a˽1.2˽b",
      { {4, 4 }, { 8, 8 }, { 10, 9 }, { 12, 10 }, { 46, 39 } }
    },
    {
      @"  abc123  ",
      @"abc˽123",
      { {0, 2 }, { 1, 3 }, { 3, NSNotFound }, { 4, 5 }, { 5, 6 } }
    },
    {
      @"_-+  abc123 &*#.",
      @"abc˽123",
      { {0, 5 }, { 1, 6 }, { 5, 9 }, { 11, NSNotFound }, { 3, NSNotFound } }
    },
    {
      @"- - a -a- - ",
      @"a˽a",
      { {0, 4 }, { 1, NSNotFound }, { 2, 7 }, { 3, NSNotFound }, { 4, NSNotFound } }
    },
    {
      // test what we do w/ hyphenated words and underscore connections, not so
      // much to force the behavior, but so we realize when it changes and think
      // through any downstream effects.
      @"abc-xyz abc--xyz abc_xyz",
      @"abc˽xyz˽abc˽xyz˽abc˽xyz",
      { {0, 0 }, { 4, 4 }, { 8, 8 }, { 12, 13 }, { 20, 21 } }
    },
    {
      // test what we do w/ contractions for the same reason.
      @"can't say i'd like that. i''d?",
      @"can't˽say˽i'd˽like˽that˽i˽d",
      { {0, 0 }, { 3, 3 }, { 24, 25 }, { 26, 28 }, { 5, NSNotFound } }
    },
    {
      // test what happens w/ colons also for the same reasons.
      @"abc:xyz abc::xyz",
      @"abc˽xyz˽abc˽xyz",
      { {0, 0 }, { 1, 1 }, { 5, 5 }, { 11, NSNotFound }, { 3, NSNotFound } }
    },
    {
      @"Photoshop",
      @"photo˽shop",
      { {0, 0 }, { 1, 1 }, { 5, NSNotFound }, { 6, 5 }, { 7, 6 } }
    },
    {
      @"I Love Firefox",
      @"i˽love˽fire˽fox",
      { {0, 0 }, { 1, NSNotFound }, { 2, 2 }, { 6, NSNotFound }, { 12, 11 } }
    },
    {
      @"Thunderbird",
      @"thunder˽bird",
      { {0, 0 }, { 1, 1 }, { 7, NSNotFound }, { 8, 7 }, { 9, 8 } }
    },
    {
      @"http://https://addons.mozilla.org/firefox/addon/1865",
      @"http˽https˽addons˽mozilla˽org˽fire˽fox˽addon˽1865",
      { {0, 0 }, { 1, 1 }, { 4, NSNotFound }, { 5, 7 }, { 31, 35 } }
    },
    {
      // This one isn't exactly what we want, but I wanted to keep a test in
      // here to make sure this stays consistent. In the FileDirectorySystem
      // source we preformat the string to strip out the '.'. See the next
      // test that verifies that case.
      @"NSArray.h",
      @"nsarray˽h",
      { {0, 0 }, { 1, 1 }, { 3, 3 }, { 7, NSNotFound }, { 8, 8 } }
    },
    {
      // Read the comment about this test in the test above.
      @"NSArray h",
      @"ns˽array˽h",
      { {0, 0 }, { 1, 1 }, { 2, NSNotFound }, { 3, 2 }, { 8, NSNotFound } }
    }
  };
  
  for (size_t i = 0; i < sizeof(testData) / sizeof(testData[0]); ++i) {
    // collect the query
    HGSTokenizedString *tokenTest 
      = [HGSTokenizer tokenizeString:testData[i].string];
    STAssertEqualObjects([tokenTest tokenizedString], 
                         testData[i].tokenized, nil);
    for (NSUInteger j = 0; j < kHGSTokenizerTestMapSize; j++) {
      NSUInteger domain = testData[i].mapping[j].domain;
      NSUInteger codomain = testData[i].mapping[j].codomain;
      NSUInteger map = [tokenTest mapIndexFromTokenizedToOriginal:domain];
      STAssertEquals(map, codomain, @"Iteration %d of %@", 
                     j, [tokenTest originalString]);
    }
  }
}

@end
