//
//  HGSSearchTermScorer.m
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

#import "HGSSearchTermScorer.h"
#import "HGSTokenizer.h"
#import <AssertMacros.h>

// TODO(dmaclach): possibly make these variables we can adjust?
//                 If we do so, make sure that they don't affect performance
//                 too badly.

static const CGFloat kHGSIsPrefixMultiplier = 1.0;
static const CGFloat kHGSIsFrontOfWordMultiplier = 0.8;
static const CGFloat kHGSIsWeakHitMultipier = 0.6;
static const CGFloat kHGSNoMatchScore = 0.0;

// The amount by which an other item score is multiplied in order to determine
// its final score.
static CGFloat gHGSOtherItemMultiplier = 0.5;

CGFloat HGSScoreTermForItem(HGSTokenizedString *term, 
                            HGSTokenizedString *string, 
                            NSIndexSet **outHitIndexes) {
  // TODO(dmaclach) add support for higher plane UTF16
  CGFloat score = kHGSNoMatchScore;
  unichar termSeparator = [HGSTokenizer tokenizerSeparator];
  if (outHitIndexes) {
    *outHitIndexes = [NSMutableIndexSet indexSet];
  }
  require_quiet(term && string, BadParams);
  
  CFStringRef str = (CFStringRef)[string tokenizedString];
  CFStringRef abbr = (CFStringRef)[term tokenizedString];
  CFIndex strLength = CFStringGetLength(str);
  CFIndex abbrLength = CFStringGetLength(abbr);
  if (abbrLength > strLength) return score;
  
  Boolean ownStrChars = false;
  Boolean ownAbbrChars = false;
  
  const UniChar *strChars = CFStringGetCharactersPtr(str);
  if (!strChars) {
    strChars = malloc(sizeof(unichar) * strLength);
    require(strChars, CouldNotAllocateStrChars);
    ownStrChars = true;
    CFStringGetCharacters(str, CFRangeMake(0, strLength), (UniChar *)strChars);
  }
  const UniChar *abbrChars = CFStringGetCharactersPtr(abbr);
  if (!abbrChars) {
    abbrChars = malloc(sizeof(unichar) * abbrLength);
    require(abbrChars, CouldNotAllocateAbbrChars);
    ownAbbrChars = true;
    CFStringGetCharacters(abbr, 
                          CFRangeMake(0, abbrLength), 
                          (UniChar *)abbrChars);
  }
  
  CFIndex stringIndex = 0;
  CFIndex abbrIndex = 0;
  CFIndex separatorIndex = 0;
  for (; stringIndex < strLength && abbrIndex < abbrLength; ++stringIndex) {
    UniChar abbrChar = abbrChars[abbrIndex];
    UniChar strChar = strChars[stringIndex];
    if (abbrChar == strChar) {
      NSUInteger mappedIndex 
        = [string mapIndexFromTokenizedToOriginal:stringIndex];
      if (outHitIndexes) {
        if (mappedIndex != NSNotFound) {
          [(NSMutableIndexSet *)(*outHitIndexes) addIndex:mappedIndex];
        }
      }
      if (mappedIndex == abbrIndex) {
        score += kHGSIsPrefixMultiplier;
      } else {
        if (stringIndex - 1 == separatorIndex) {
          score += kHGSIsFrontOfWordMultiplier;
        } else {
          score += kHGSIsWeakHitMultipier;
        }
      }
      abbrIndex += 1;
    } else {
      // We missed a character
      // Scan forward to the next word
      if (abbrChar == termSeparator) {
        abbrIndex += 1;
      }
      for (; stringIndex < strLength; 
           ++stringIndex) {
        UniChar nextStrChar = strChars[stringIndex];
        if (nextStrChar == termSeparator) {
          separatorIndex = stringIndex;
          break;
        }
      }
    }
  }
  if (abbrIndex != abbrLength) {
    score = kHGSNoMatchScore;
  } else {
    score /= [[string originalString] length];
  }
  if (ownAbbrChars) {
    free((UniChar *)abbrChars);
  }
CouldNotAllocateAbbrChars:
  if (ownStrChars) {
    free((UniChar *)strChars);
  }
CouldNotAllocateStrChars:
BadParams:
  return score;
}

CGFloat HGSScoreTermForMainAndOtherItems(HGSTokenizedString *term,
                                         HGSTokenizedString *mainString,
                                         NSArray *otherStrings,
                                         HGSTokenizedString **outMatchedString,
                                         NSIndexSet **outHitIndexes) {
  // If the caller has not provided a wordRanges then we create and return
  // a new one.
  HGSTokenizedString *localMatchedString = mainString;
  NSIndexSet *localMatchedSet = nil;
  CGFloat score = HGSScoreTermForItem(term, mainString, &localMatchedSet);
  // Check |otherItems| only for better matches than the main
  // search item.
  NSIndexSet *tempSet = nil;
  for (HGSTokenizedString *otherString in otherStrings) {
    NSIndexSet *otherSet = nil;
    CGFloat newScore = (HGSScoreTermForItem(term, otherString, &otherSet)
                        * gHGSOtherItemMultiplier);
    if (newScore > score) {
      localMatchedString = otherString;
      localMatchedSet = otherSet;
      score = newScore;
      if (outHitIndexes) {
        *outHitIndexes = tempSet;
      }
    }
  }
  if (outMatchedString) {
    *outMatchedString = score > 0 ? localMatchedString : nil;
  }
  if (outHitIndexes) {
    *outHitIndexes = score > 0 ? localMatchedSet : nil;
  }
  return score;
}


CGFloat HGSCalibratedScore(HGSCalibratedScoreType scoreType) {
  CGFloat value = 0;
  switch (scoreType) {
    case kHGSCalibratedPerfectScore:
      value = 1.0;
      break;
    case kHGSCalibratedStrongScore:
      value = 0.75;
      break;
    case kHGSCalibratedModerateScore:
      value = 0.5;
      break;
    case kHGSCalibratedWeakScore:
      value = 0.25;
      break;
    case kHGSCalibratedInsignificantScore:
      value = 0.01;
      break;
    default:
      break;
  }
  return value;
}
