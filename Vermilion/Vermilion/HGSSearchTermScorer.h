//
//  HGSSearchTermScorer.h
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

/*!
 @header
 @discussion HGSSearchTermScorer
*/

#ifdef __cplusplus
extern "C" {
#endif

@class HGSTokenizedString;
  
/*!
 Scores how well a given term comprised of a singe word matches to a
 string.  (Release version.)
 @param term The search term against which the candidate item will be
 searched.  This should be a single word.
 @param string The string against which to match the search term.
 @param outHitIndexes If non-nil, contains the indexes of the characters
 that were matched against.
 @result an unbounded float representing the matching score of the best match.
 */
CGFloat HGSScoreTermForItem(HGSTokenizedString *term, 
                            HGSTokenizedString *string, 
                            NSIndexSet **outHitIndexes);
/*!
 Scores how well a one or more words match a string.  (Release version.)
 @param term A term to match against.
 @param mainString The string against which to score the search term.
 @param otherStrings An NSArray of HGSScoreStrings which are alternative items
 against which the searchTerms will be scored.  If the score for any of
 the other items is high enough then its score will be used instead of 
 the score for the main item.
 @param outMatchedString If non-nil, contains the string that was matched 
 against.
 @param outHitIndexes If non-nil, contains the indexes of the characters
 that were matched against.
 @result an NSArray of float NSNumbers representing the matching scores
 of the best match for each search term.
 */
CGFloat HGSScoreTermForMainAndOtherItems(HGSTokenizedString *term,
                                         HGSTokenizedString *mainString,
                                         NSArray *otherStrings,
                                         HGSTokenizedString **outMatchedString,
                                         NSIndexSet **outHitIndexes);

/*!
 @enum Calibrated Score Categories
 @abstract Used to specify the minimum score required to achieve the
 desired category.
 @constant kHGSCalibratedPerfectScore The score assigned for a perfect math.
 @constant kHGSCalibratedStrongScore A strong match score.
 @constant kHGSCalibratedModerateScore A moderately match score.
 @constant kHGSCalibratedWeakScore A moderate match score.
 @constant kHGSCalibratedInsignificantScore An insignificant match score.
 @constant kHGSCalibratedLastScore Can be used as a count of possible values.
 */  
typedef enum {
  kHGSCalibratedPerfectScore = 0,
  kHGSCalibratedStrongScore,
  kHGSCalibratedModerateScore,
  kHGSCalibratedWeakScore,
  kHGSCalibratedInsignificantScore,
  kHGSCalibratedLastScore
} HGSCalibratedScoreType;


/*!
 Returns a calibrated score based on the desired category strengh.
 @param scoreType The strength category for which the minimum match score
 is to be returned.
 @result A CGFloat containing the minimum match score for the given
 strength category.
 */
CGFloat HGSCalibratedScore(HGSCalibratedScoreType scoreType);

#ifdef __cplusplus
}
#endif

