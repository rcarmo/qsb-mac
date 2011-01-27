//
//  HGSSearchSourceRanker.h
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
//

#import <Foundation/Foundation.h>

/*!
 @header
 @discussion HGSSearchSourceRanker
*/

@class HGSSearchSource;
@class HGSExtensionPoint;

/*!
 Keeps track of the ranking of search sources. Currently this is only the
 order that they fire off in searches, but eventually will be responsible
 for influencing the ranking of results in HGSMixer.
*/
@interface HGSSearchSourceRanker : NSObject {
 @private
  NSMutableDictionary *rankDictionary_;
  HGSExtensionPoint *sourcesPoint_;
  UInt64 promotionCount_;
  BOOL dirty_;
}

/*!
 Has the ranking data been changed, since dirty was last set to NO.
*/
@property (getter=isDirty) BOOL dirty;

/*!
 Returns the shared ranker which will initialize itself with data stored
 in user preferences if available, or else a default initial set of data.
 It will update the user preference data on a regular basis automatically.
*/
+ (HGSSearchSourceRanker *)sharedSearchSourceRanker;

/*! 
 Designated initializer. Initialize with data previously obtained from
 rankerData. In general you should always use +sharedSearchSourceRanker.
 This exists mainly for unittesting.
 @param data Data to initialize the ranker with.
 @param point HGSExtensionPoint to get sources from.
 @result HGSSearchSourceRanker instance.
*/
- (id)initWithRankerData:(id)data sourcesPoint:(HGSExtensionPoint*)point;

/*!
 Archives the current ranker data in a form that can be stored in a plist.
*/
- (id)rankerData;

/*!
 Returns the list of source in order from fastest to slowest.
*/
- (NSArray *)orderedSourcesByPerformance;

/*!
 Returns the average amount of absolute time it takes for a source to run.
*/
- (UInt64)averageTimeForSource:(HGSSearchSource *)source;

/*!
 Total number of promotions.
*/
- (UInt64)promotionCount;

/*!
 Promotion count for a given source
*/
- (UInt64)promotionCountForSource:(HGSSearchSource *)source;

@end
