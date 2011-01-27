//
//  CalculatorSource.m
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

#import <Vermilion/Vermilion.h>

#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMNSNumber+64Bit.h>

#import "CalculatePrivate.h"
#import "TextActions.h"

@interface CalculatorSource : HGSCallbackSearchSource {
 @private
  NSCharacterSet *mathSet_;
  NSCharacterSet *nonAlphanumericSet_;
  NSString *calculatorAppPath_;
}
@end

@implementation CalculatorSource

GTM_METHOD_CHECK(NSNumber, gtm_numberWithCGFloat:);

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    NSCharacterSet *mathSet
      = [NSCharacterSet characterSetWithCharactersInString:@"1234567890+-*/() "];
    mathSet_ = [mathSet retain];
    NSCharacterSet *nonAlphanumericSet =
      [[NSCharacterSet alphanumericCharacterSet] invertedSet];
    nonAlphanumericSet_ = [nonAlphanumericSet retain];

    NSString *calcPath
      = [[NSWorkspace sharedWorkspace]
         absolutePathForAppBundleWithIdentifier:@"com.apple.calculator"];
    if ([calcPath length]) {
      NSURL *fileURL = [NSURL fileURLWithPath:calcPath];
      calculatorAppPath_ = [[fileURL absoluteString] retain];
    }
    if (!mathSet_ || !nonAlphanumericSet_ || !calculatorAppPath_) {
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [mathSet_ release];
  [nonAlphanumericSet_ release];
  [calculatorAppPath_ release];
  [super dealloc];
}

#pragma mark Private Methods

- (HGSAction *)defaultAction {
  NSString *actionName = GTM_NSSTRINGIFY(kCoreTextActionLargeTypeID);
  HGSAction *action
    = [[HGSExtensionPoint actionsPoint] extensionWithIdentifier:actionName];
  if (!action) {
    HGSLog(@"Unable to get large type action (%@)", actionName);
  }
  return action;
}

#pragma mark -

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = NO;
  NSString *rawQuery = [[query tokenizedQueryString] originalString];

  // It takes atleast 3 chars to make an expression ie- 1+1
  if ([rawQuery length] > 2) {
    // As long as any of the math characters are in the string, let it through
    NSRange range = [rawQuery rangeOfCharacterFromSet:mathSet_];
    if (range.location != NSNotFound) {
      // Also require at least one math character that isn't alphanumeric
      range = [rawQuery rangeOfCharacterFromSet:nonAlphanumericSet_];
      if (range.location != NSNotFound) {
        isValid = [super isValidSourceForQuery:query];
      }
    }
  }
  return isValid;
}

- (BOOL)isSearchConcurrent {
  // Not sure if the framework we call is thread safe, so play it safe
  return YES;
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSTokenizedString *queryString = [[operation query] tokenizedQueryString];
  NSString *rawQuery = [queryString originalString];
  if ([rawQuery length]) {
    // Fix up separators and decimals. The Calculator framework wants
    // '.' for decimals, and no grouping separators.
    NSLocale *locale = [NSLocale autoupdatingCurrentLocale];
    NSString *decimalSeparator = [locale objectForKey:NSLocaleDecimalSeparator];
    NSString *groupingSeparator
      = [locale objectForKey:NSLocaleGroupingSeparator];
    NSMutableString *fixedQuery = [NSMutableString stringWithString:rawQuery];
    [fixedQuery replaceOccurrencesOfString:groupingSeparator
                                withString:@""
                                   options:0
                                     range:NSMakeRange(0, [fixedQuery length])];
    [fixedQuery replaceOccurrencesOfString:decimalSeparator
                                withString:@"."
                                   options:0
                                     range:NSMakeRange(0, [fixedQuery length])];
    char answer[1024];
    answer[0] = '\0';
    int success
      = CalculatePerformExpression((char *)[fixedQuery UTF8String],
                                   10, 1, answer);
    if (success) {
      NSString *answerString = [NSString stringWithUTF8String:answer];
      NSString *resultString
        = [NSString stringWithFormat:@"%@ = %@", rawQuery, answerString];
      // We don't want the answer truncated because we show the expression,
      // so if we have a lot of characters we will just shorten down to the
      // answer. 30 chosen by experimentation.
      if ([resultString length] > 30) {
        resultString = answerString;
      }
      // Cheat, force this result high in the list.
      // TODO(dmaclach): figure out a cleaner way to get results like this high
      // in the results.
      NSDictionary *pasteboardData
        = [NSDictionary dictionaryWithObject:answerString
                                      forKey:NSStringPboardType];
      NSMutableDictionary *attributes
           = [NSMutableDictionary dictionaryWithObject:pasteboardData
                                                forKey:kHGSObjectAttributePasteboardValueKey];
      
      HGSAction *largeTypeAction = [self defaultAction];
      if (largeTypeAction) {
        [attributes setObject:largeTypeAction
                       forKey:kHGSObjectAttributeDefaultActionKey];
      }
      
      HGSScoredResult *rankedHGSObject
        = [HGSScoredResult resultWithURI:calculatorAppPath_
                                    name:resultString
                                    type:HGS_SUBTYPE(kHGSTypeOnebox, @"calculator")
                                  source:self
                              attributes:attributes
                                   score:HGSCalibratedScore(kHGSCalibratedPerfectScore) 
                                   flags:eHGSSpecialUIRankFlag
                             matchedTerm:queryString
                          matchedIndexes:nil];
      NSArray *resultsArray = [NSArray arrayWithObject:rankedHGSObject];
      [operation setRankedResults:resultsArray];
    }
  }
  // Since we are concurent, finish the query ourselves.
  [operation finishQuery];
}

@end
