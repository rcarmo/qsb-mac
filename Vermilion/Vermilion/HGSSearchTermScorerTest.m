//
//  HGSSearchTermScorerTest.m
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
#import "HGSSearchTermScorer.h"
#import "HGSTokenizer.h"
#import <Vermilion/HGSBundle.h>
#import <OCMock/OCMock.h>

// There is an accompanying test data file with the name 
// HGSSearchTermScorerTestData.plist which is used by the
// testRelativeTermScoring test case below.  The construct of the test data
// file is an array of test cases.  Each test case is a dictionary
// with two items.  One item has a key of 'search terms' and is a string
// containing one or more words which will be used to score 'search items'.
// The other item in the dictionary has a key of 'search items' and is
// an array of strings, each of which will be scored against the 'search
// terms'.  The array of 'search items' should be in the order in which
// you expect them to score from highest to lowest.

#define kHGSMaximumRelativeTermScoringTests 100

@interface HGSSearchTermScorerTest : GTMTestCase

@end

@implementation HGSSearchTermScorerTest

#pragma mark Tests

static CGFloat HGSScoreTermForString(NSString *stringA, NSString *stringB) {
  HGSTokenizedString *tokenA = [HGSTokenizer tokenizeString:stringA];
  HGSTokenizedString *tokenB = [HGSTokenizer tokenizeString:stringB];
  return HGSScoreTermForItem(tokenA, tokenB, nil);
}

- (void)testBasicRelativeTermScoring {
  CGFloat scoreA = HGSScoreTermForString(@"abc", @"abcd");
  CGFloat scoreB = HGSScoreTermForString(@"abc", @"abcde");
  STAssertTrue(scoreA > scoreB,  @"%f !> %f", scoreA, scoreB);
  scoreA = HGSScoreTermForString(@"abc", @"american bandstand of canada");
  scoreB 
    = HGSScoreTermForString(@"abc", @"american candy bandstand of canada");
  STAssertTrue(scoreA > scoreB, @"%f !> %f", scoreA, scoreB);
  scoreA = HGSScoreTermForString(@"canada", @"american bandstand of canada");
  scoreB 
    = HGSScoreTermForString(@"canada", @"american candy bandstand of canada");
  STAssertTrue(scoreA > scoreB, @"%f !> %f", scoreA, scoreB);
  scoreA = HGSScoreTermForString(@"ic", @"iChat");
  scoreB 
    = HGSScoreTermForString(@"ic", @"Icons");
  STAssertEquals(scoreA, scoreB, nil);
  
  scoreA = HGSScoreTermForString(@"dis u", @"Disk Utility");
  STAssertGreaterThan(scoreA, (CGFloat)0, nil);
}

- (void)testRelativeTermScoring {
  // Pull in the test data.
  NSBundle *bundle = HGSGetPluginBundle();
  STAssertNotNil(bundle, nil);
  NSString *plistPath = [bundle pathForResource:@"HGSSearchTermScorerTestData"
                                         ofType:@"plist"];
  STAssertNotNil(plistPath, nil);
  NSArray *testList = [NSArray arrayWithContentsOfFile:plistPath];
  STAssertNotNil(testList, nil);
  STAssertTrue([testList count] > 0, nil);
  STAssertTrue([testList count] <= kHGSMaximumRelativeTermScoringTests, nil);
  
  // Allow a maximum of kHGSMaximumRelativeTermScoringTests possible
  // search items.  The scores will be in one-to-one correspondence with the
  // input testItems and the resulting scores should following a descending
  // pattern even though the items will be scored randomly.
  CGFloat itemScores[kHGSMaximumRelativeTermScoringTests];
  NSUInteger itemIndex[kHGSMaximumRelativeTermScoringTests];  // Used to randomize the items.
  srandom((float)[NSDate timeIntervalSinceReferenceDate]);
  for (NSDictionary *test in testList) {
    for (NSUInteger i = 0; i < kHGSMaximumRelativeTermScoringTests; ++i) {
      itemScores[i] = 0.0;
      itemIndex[i] = i;
    }
    NSString *testTermsString = [test objectForKey:@"query"];
    NSArray *testItems = [test objectForKey:@"results"];
    NSUInteger itemsCount = [testItems count];
    for (NSUInteger j = itemsCount; j > 0; --j) {
      // Pick a random item index then compress the index choices.
      NSUInteger indexChoice = random() / (LONG_MAX / j);
      NSUInteger randomIndex = itemIndex[indexChoice];
      for (NSUInteger k = indexChoice + 1; k < 50; ++k) {
        itemIndex[k - 1] = itemIndex[k];
      }
      id testItem = [testItems objectAtIndex:randomIndex];
      NSString *primaryItem = nil;
      NSArray *secondaryItems = nil;
      if ([testItem isKindOfClass:[NSString class]]) {
        primaryItem = testItem;
      } else if ([testItem isKindOfClass:[NSArray class]]) {
        secondaryItems = testItem;
        NSUInteger itemCount = [secondaryItems count];
        if (itemCount > 0) {
          primaryItem = [secondaryItems objectAtIndex:0];
          secondaryItems = (itemCount > 1)
            ? [secondaryItems subarrayWithRange:NSMakeRange(1, itemCount - 1)]
            : nil;
        }
      }
      if (primaryItem) {
        // This replicates the score formula used in HGSMemorySearchSource
        // when secondaryItems are taken into consideration.
        CGFloat itemScore = 0.0;
        CGFloat termScore
          = HGSScoreTermForString(testTermsString, primaryItem);
        // Only consider secondaryItem that have better scores than the main
        // search item.
        for (NSString *secondaryItem in secondaryItems) {
          termScore = MAX(termScore,
                          HGSScoreTermForString(testTermsString, 
                                                    secondaryItem)
                          / 2.0);
        }
        itemScores[randomIndex] = itemScore;
      }
    }
    // Verify that we got ascending scores.
    for (NSUInteger l = 1; l < itemsCount; ++l) {
      STAssertTrue(itemScores[l - 1] >= itemScores[l], 
                   @"Score failure for '%@'[%d]: %0.2f !>= '%@'[%d]: %0.2f "
                   @"for term '%@'", 
                   [testItems objectAtIndex:l - 1], l - 1, itemScores[l - 1],
                   [testItems objectAtIndex:l], l, itemScores[l],
                   testTermsString);
    }
  }
}

@end
