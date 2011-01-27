//
//  QSBQuery.h
//
//  Copyright (c) 2006-2008 Google Inc. All rights reserved.
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

#import <Cocoa/Cocoa.h>
#import <Vermilion/Vermilion.h>

@class HGSObject;
@class HGSShortcuts;
@class QSBMoreResultsViewDelegate;

// Interface between QSB and the web suggestor and the desktop query
// takes a query string and is responsible for turning it into results.
@interface QSBQuery : NSObject {
 @private
  IBOutlet QSBMoreResultsViewDelegate *moreResultsViewDelegate_;
  
  NSMutableArray *cachedDesktopResults_; // This array persists results between
                                         // queries to remove perceived latency
  
  NSMutableArray *desktopResults_;
  NSMutableArray *lockedResults_;
  NSString *queryString_;  // Current query string entered by user.
  HGSObject *pivotObject_;
  NSUInteger currentResultDisplayCount_;
  HGSQueryController *queryController_;
  QSBQuery *parentQuery_;
  
  NSArray *oldSuggestions_; // The last suggestions seen
                                 
  NSDictionary *moreResults_;  // Contains one results array per category.
  NSMutableDictionary *typeCategoryDict_;  // type->category conversion.
  
  // used to update the UI at various times through the life of the query
  NSTimer *shortcutDisplayTimer_;
  NSTimer *firstTierDisplayTimer_;
  NSTimer *secondTierDisplayTimer_;
                                 
  NSTimeInterval lastMoreUpdateTime_;

  BOOL queryIsInProcess_;  // Yes while a query is under way.
  NSUInteger pushModifierFlags_; // NSEvent Modifiers at pivot time
}

@property(nonatomic, assign) NSUInteger pushModifierFlags;

// Returns the desktop results
- (NSArray *)desktopResults;

// Returns the more results
- (NSDictionary *)moreResults;

// Changes the query and restarts the query to desktop and web if the
// web tab is frontmost.
- (void)setQueryString:(NSString *)queryString;

// Sets/Gets the parent query from which we were spawned.
- (void)setParentQuery:(QSBQuery *)parentQueryClient;
- (QSBQuery *)parentQuery;

// Sets/Gets a context (pivot object) for the current query.
- (void)setPivotObject:(HGSObject *)value;
- (HGSObject *)pivotObject;

// Returns the current query
- (NSString*)queryString;

// Returns the maximum number of results to present.
- (NSUInteger)maximumResultsToCollect;

// Return YES if you don't want a 'More' results view available to be shown if
// everything can be shown in the 'Top' results.  Defaults to NO.
- (BOOL)suppressMoreIfTopShowsAll;

// Perform the actual query.  For use only be child classes.
- (void)doDesktopQuery:(id)ignoredValue;

// Stop all source operations for this query.
- (void)stopQuery;

// Set/get in-process indication for query.  Bound to the progress
// indicator.
- (void)setQueryIsInProcess:(BOOL)value;
- (BOOL)queryIsInProcess;

@end

// Sent when the query has completed and the results have been processed. 
// Object is the QSBQuery.
GTM_EXTERN NSString *kHGSQueryDidFinishNotification;
