//
//  QSBQuery.m
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

#import "QSBQuery.h"
#import "QSBApplication.h"
#import "QSBApplicationDelegate.h"
#import "QSBMoreResultsViewDelegate.h"
#import "QSBPreferences.h"
#import "QSBTableResult.h"
#import "QSBResultsViewBaseController.h"
#import "GTMMethodCheck.h"
#import "GoogleCorporaSource.h"
#import "NSString+CaseInsensitive.h"
#import "NSString+ReadableURL.h"
#import "HGSOpenSearchSuggestSource.h"

// Notifications
NSString *kHGSQueryDidFinishNotification = @"HGSQueryDidFinishNotification";


// KVO Selector strings.
static NSString *const kDesktopResultsKVOKey = @"desktopResults";

static const NSUInteger kDefaultMaximumResultsToCollect = 500;

@interface QSBQuery (QSBQueryPrivateMethods)

- (void)displayTimerElapsed:(NSTimer*)timer;

- (void)startDisplayTimers;
- (void)cancelDisplayTimers;

- (void)cancelAndReleaseQueryController;

// Reset the 'More Results'
- (void)setMoreResults:(NSDictionary *)value;

// Queue an operation to update the 'More' results view if one has not
// previously been posted within |minimumInterval| (in seconds).  Specify 0.0
// for |minimumInterval| if the operation should be queued regardless of 
// time since previous queuing.  Return YES if an update operation was
// actually queued.
- (BOOL)updateMoreResultsWithInterval:(NSTimeInterval)minimumInterval;

// Iterates current query results and updates the 'More' results view.
- (void)updateMoreResultsOperation:(id)unused;

@end


@implementation QSBQuery

@synthesize pushModifierFlags = pushModifierFlags_;

GTM_METHOD_CHECK(NSString, hasCaseInsensitivePrefix:);

+ (void)initialize {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [self setKeys:[NSArray arrayWithObjects:@"showAllCategoriesSet", nil]
    triggerChangeNotificationsForDependentKey:@"moreResults"];
  [pool release];
}

- (id)init {
  self = [super init];
  if (self != nil) {
    desktopResults_ = [[NSMutableArray alloc] init];
    cachedDesktopResults_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  // Cancel outstanding query requests and all timers.
  [self stopQuery];
  [self cancelAndReleaseQueryController];
  [queryString_ release];
  [pivotObject_ release];
  [parentQuery_ release];
  [desktopResults_ release];
  [cachedDesktopResults_ release];
  [lockedResults_ release];
  [oldSuggestions_ release];
  [moreResults_ release];
  [typeCategoryDict_ release];
  [super dealloc];
}

- (void)updateDesktopResults {  
  HGSQueryController* controller = queryController_;
  if (!controller) return;
  HGSAssert(controller, @"No controller?");

  if (currentResultDisplayCount_ == 0) {
    HGSLog(@"updateDesktopResults called with display count still at 0!");
    return;
  }

  NSArray *rankedResults = [controller rankedResults];
  NSMutableArray *hgsResults = [NSMutableArray array];
  NSMutableArray *hgsMutableSuggestions = [NSMutableArray array];
  for (HGSObject *result in rankedResults) {
    if ([result conformsToType:kHGSTypeSuggest]) {
      [hgsMutableSuggestions addObject:result];
    } else {
      [hgsResults addObject:result];
    }
  }
  NSArray *hgsSuggestions = (NSArray*)hgsMutableSuggestions;
  
  // TODO(dmaclach): we need to revisit this.  as shortcuts, suggest, and
  // regular results go in, they need to be deduped.  the current dedupe is in
  // the mixer as it does the merge, but we don't seem to want to use that here.
  // so we need to factor that logic into some way it can be used here.  we had
  // been using uris here, but we don't want to require them, and that's not the
  // same deduping that happens w/in mixer.

  // Build the main results list.
  // First anything that was locked down, then shortcuts, then the main results.
  // We have to do simple de-duping across the three, since there may be
  // duplication between the three sets.
  NSMutableArray *mainResults = [NSMutableArray array];
  
  // Keep what was locked in
  [mainResults addObjectsFromArray:lockedResults_];
  
  // Standard results
  BOOL hasMoreStandardResults = NO;
  for (HGSObject *result in hgsResults) {
    if ([mainResults count] >= currentResultDisplayCount_) {
      hasMoreStandardResults = YES;
      break;
    }
    // See todo above, for now we "dedupe" simply by the fact that we're pulling
    // from a list that just keeps getting things merged in, so we only need ptr
    // compares.
    NSArray *mainHGSResults = [mainResults valueForKey:@"representedObject"];
    if ([mainHGSResults indexOfObjectIdenticalTo:result] == NSNotFound) {
      QSBSourceTableResult *sourceResult
        = [QSBSourceTableResult resultWithObject:result];
        
      if (([result rankFlags] & eHGSBelowFoldRankFlag) == 0) {
        [mainResults addObject:sourceResult];
      } else {
        hasMoreStandardResults = YES; 
      }
    }
  }

  // If there were more results than could be shown in TOP then we'll
  // need a 'More' fold.
  BOOL showMore = (hasMoreStandardResults
                   || ![self suppressMoreIfTopShowsAll])
                  && ![[NSUserDefaults standardUserDefaults]
                       boolForKey:@"disableMoreResults"];
  
  // Anything that ends up in the main results section should be locked down
  // to prevent any rearranging.
  [lockedResults_ release];
  lockedResults_ = [mainResults copy];
  
  // Is this search a generic, global search? (No pivot set)
  // If so, there may be special items above and/or below the search results
  NSMutableArray *prefixResults = [NSMutableArray array];
  NSMutableArray *suffixResults = [NSMutableArray array];
  HGSQuery *query = [controller query];
  HGSObject *pivotObject = [query pivotObject];

  if (!pivotObject) {
    
    // TODO(stuartmorgan): this is something of a hack to account for the fact
    // that suggest now comes in with the results but is handled like a suffix;
    // we need to rethink how it should work.
    
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSInteger suggestCount = [prefs integerForKey:kQSBSuggestCountKey];
    if (suggestCount) {
      if ([hgsSuggestions count] || [[self queryString] length] < 3) {
        [oldSuggestions_ autorelease];
        oldSuggestions_ = [hgsSuggestions retain]; 
      } else {
        hgsSuggestions = oldSuggestions_;
      }
      
      // a negative tag indicates a prefix
      BOOL prefixSuggestions = suggestCount < 0;         
      NSUInteger absSuggestCount = ABS(suggestCount);
      // enforce a minimum of three suggests for now
      if (absSuggestCount == 1) absSuggestCount = 3;
      
      if ([hgsSuggestions count] > absSuggestCount) {
        hgsSuggestions = [hgsSuggestions subarrayWithRange:NSMakeRange(0, absSuggestCount)];
      }
      
      if (absSuggestCount) {
        for (HGSObject *suggest in hgsSuggestions) {
          QSBTableResult *qsbSuggest = nil;
          // This switch controls icon versus text suggestions
#if 1          
          NSString *suggestString = [suggest displayName];
          qsbSuggest = [QSBGoogleTableResult resultForQuery:suggestString];
#else
          qsbSuggest = [QSBSourceTableResult resultWithObject:suggest];
#endif
          
          if (prefixSuggestions) {
            [prefixResults addObject:qsbSuggest];
          } else {
            [suffixResults addObject:qsbSuggest];
          }
        }
      }
    }
  } else {
    if ([pivotObject conformsToType:kHGSTypeWebpage]) {
      NSString *queryString = [query rawQueryString];
      if ([queryString length] == 0) {
        NSString *messageFormat 
          = NSLocalizedString(@"Search %@ by typing in the box above.",
                              @"Message: Search <website> by typing in the "
                              @"box above. (30 chars excluding <website>)");
        NSString *messageString = [NSString stringWithFormat:messageFormat, 
                                   [pivotObject displayName]];
        QSBMessageTableResult *message 
          = [QSBMessageTableResult resultWithString:messageString];
        [prefixResults addObject:message];
      }
    }
  }

  // Build the actual list
  [self willChangeValueForKey:kDesktopResultsKVOKey];
  [desktopResults_ removeAllObjects];
  
  if ([prefixResults count] > 0) {
    [desktopResults_ addObjectsFromArray:prefixResults];
  }
  
  if ([mainResults count] > 0) {
    if ([desktopResults_ count] > 0) {
      [desktopResults_ addObject:[QSBSeparatorTableResult result]];
    }
    [desktopResults_ addObjectsFromArray:mainResults];
  }
  
  if (![[controller query] pivotObject]) {
    // TODO(alcor): this is probably going to be done by the mixer eventually
    int idx = 0; 
    if ([desktopResults_ count]) {
      QSBTableResult *first = [desktopResults_ objectAtIndex:0];
      // List the google result lower if we have a strong confidence result.
      if ([first rank] > 0) {
        idx = 1;
      }
    }
    
    QSBGoogleTableResult *googleItem = [QSBGoogleTableResult resultForQuery:queryString_];
    [desktopResults_ insertObject:googleItem
                          atIndex:idx];
  }
  
  if ([desktopResults_ count] < [cachedDesktopResults_ count]) {
    [cachedDesktopResults_ replaceObjectsInRange:
                              NSMakeRange(0, [desktopResults_ count])
                            withObjectsFromArray:desktopResults_];
  } else {
    [cachedDesktopResults_ setArray:desktopResults_];
  }

  
  if (showMore && [controller hasAnyRealResults]) {
    if ([suffixResults count] > 0) {
      [desktopResults_ addObjectsFromArray:suffixResults];
    }
    if (![controller queriesFinished]) {
      [desktopResults_ addObject:[QSBSearchStatusTableResult result]];
    }    
    [desktopResults_ addObject:[QSBFoldTableResult result]];
  } else {
    if ([suffixResults count] > 0 && [mainResults count] > 0) {
      [desktopResults_ addObjectsFromArray:suffixResults];
    }
    if (![controller queriesFinished]) {
      [desktopResults_ addObject:[QSBSearchStatusTableResult result]];
    }    
  }
  
  if ([controller queriesFinished]) {
    [cachedDesktopResults_ setArray:desktopResults_];
  }
    
  [self didChangeValueForKey:kDesktopResultsKVOKey];
}

- (void)purgeInvalidResults {
  if (![cachedDesktopResults_ isEqualToArray:desktopResults_]) {
    [self willChangeValueForKey:kDesktopResultsKVOKey];
    [cachedDesktopResults_ setArray:desktopResults_];
    [self didChangeValueForKey:kDesktopResultsKVOKey];
  }
}

- (NSString *)searchStatus {
  return [queryController_ pendingQueryNames];
}

- (NSArray*)desktopResults {
  return [[cachedDesktopResults_ retain] autorelease];
}

- (NSDictionary *)moreResults {
  return [[moreResults_ retain] autorelease];
}

// Restart the query with the current queryString_ and context
// this cancels the old query.
- (void)restartQueryClearingResults:(BOOL)clearResults {
#if DEBUG
  BOOL reportQueryStatusOnRestart = [[NSUserDefaults standardUserDefaults]
                                     boolForKey:@"reportQueryStatusOnRestart"];
  if (reportQueryStatusOnRestart) {
    HGSLog(@"QSB: Query Controller status before restart.\n  %@.", queryController_);
  }
#endif
  [self cancelAndReleaseQueryController];
  
  // wait before sending off our query to coalesce any other restarts in flight.
  // Must cancel any old requests as we only want one in the queue at a time.
  [NSObject cancelPreviousPerformRequestsWithTarget:self 
                                           selector:@selector(doDesktopQuery:) 
                                             object:nil];
  [self performSelector:@selector(doDesktopQuery:)
             withObject:nil
             afterDelay:0.0];
  
  [NSObject cancelPreviousPerformRequestsWithTarget:self 
                                           selector:@selector(purgeInvalidResults) 
                                             object:nil];
  
  [self performSelector:@selector(purgeInvalidResults)
             withObject:nil
             afterDelay:0.5];
  
  if (clearResults) {
    [self willChangeValueForKey:kDesktopResultsKVOKey];
    [desktopResults_ removeAllObjects];
    [cachedDesktopResults_ removeAllObjects];
    [self didChangeValueForKey:kDesktopResultsKVOKey];
    [self setMoreResults:nil];
  }
}

- (void)setParentQuery:(QSBQuery *)parentQuery {
  [parentQuery_ autorelease];
  parentQuery_ = [parentQuery retain];
}

- (QSBQuery *)parentQuery {
  return [[parentQuery_ retain] autorelease];
}
 
- (void)setPivotObject:(HGSObject *)value {
  [pivotObject_ autorelease];
  pivotObject_ = [value retain];
}

- (HGSObject *)pivotObject {
  return [[pivotObject_ retain] autorelease];
}

- (void)setQueryString:(NSString*)queryString {
  BOOL isPrefix = NO;
  if (!queryString) {
    [queryString_ release];
    queryString_ = nil;
  } else if (![queryString_ isEqualToString:queryString]) {
    isPrefix = ([queryString_ length] > 0 && 
                [queryString length] > 0 && 
                ([queryString hasCaseInsensitivePrefix:queryString_] || 
                 [queryString_ hasCaseInsensitivePrefix:queryString]));
    [queryString_ autorelease];
    queryString_ = [queryString copy];
  }
  [self restartQueryClearingResults:(!isPrefix)];
}

- (NSString*)queryString {
  return queryString_;
}

- (NSUInteger)maximumResultsToCollect {
  return kDefaultMaximumResultsToCollect;
}

- (BOOL)suppressMoreIfTopShowsAll {
  return YES;
}

- (void)doDesktopQuery:(id)ignoredValue {  
  [lockedResults_ release];
  lockedResults_ = nil;
  currentResultDisplayCount_ = 0;
  [self setQueryIsInProcess:YES];
  [self cancelDisplayTimers];
  
  if (queryString_ || pivotObject_) {
  
    HGSQueryFlags flags = 0;
    if (pushModifierFlags_ & NSAlternateKeyMask) {
      flags |= eHGSQueryShowAlternatesFlag;
    }
    
    HGSQuery *query = [[[HGSQuery alloc] initWithString:queryString_
                                            pivotObject:pivotObject_
                                             queryFlags:flags]
                       autorelease];
    [query setMaxDesiredResults:[self maximumResultsToCollect]];
    
    [self cancelAndReleaseQueryController];
    HGSMixer* mixer = [[[HGSMixer alloc] init] autorelease];
    queryController_ = [[HGSQueryController alloc] initWithQuery:query
                                                           mixer:mixer];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self 
           selector:@selector(queryControllerDidFinish:) 
               name:kHGSQueryControllerDidFinishNotification 
             object:queryController_];
    [nc addObserver:self 
           selector:@selector(queryControllerDidAddResults:) 
               name:kHGSQueryControllerDidUpdateResultsNotification 
             object:queryController_];
    // This became a separate call because some sources come back before
    // this call returns and queryController_ must be set first
    [queryController_ startQuery];
    [self startDisplayTimers];
  }
}

- (void)setQueryIsInProcess:(BOOL)value {
  queryIsInProcess_ = value;
}

- (BOOL)queryIsInProcess {
  return queryIsInProcess_;
}

- (void)stopQuery {
  [self cancelDisplayTimers];
  [NSObject cancelPreviousPerformRequestsWithTarget:self 
                                           selector:@selector(doDesktopQuery:) 
                                             object:nil];
  [queryController_ cancel];
  [self setQueryIsInProcess:NO];
}

#pragma mark Notifications

// Called when the last active query operation, and thus the query, has
// completed.  May be called even when there are more results that are
// possible, but the query has been stopped by the user or by the query
// reaching a time threshhold. 
- (void)queryControllerDidFinish:(NSNotification *)notification {
  [self updateMoreResultsWithInterval:0.25];
  currentResultDisplayCount_ = [self maximumResultsToCollect];
  [self updateDesktopResults]; 
#if DEBUG
  BOOL dumpTopResults = [[NSUserDefaults standardUserDefaults]
                         boolForKey:@"dumpTopResults"];
  if (dumpTopResults) {
    HGSLog(@"QSB: Desktop Results:\n%@", [self desktopResults]);
    HGSLog(@"QSB: More Results:\n%@", [self moreResults]);
  }
#endif
  // Notify that the results are complete.
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kHGSQueryDidFinishNotification 
                    object:self];
  
  [self setQueryIsInProcess:NO];
  [self cancelDisplayTimers];
}

// Called when more results are added to the query.
- (void)queryControllerDidAddResults:(NSNotification *)notification {
  [self willChangeValueForKey:@"searchStatus"];
  [self didChangeValueForKey:@"searchStatus"];
  [self updateMoreResultsWithInterval:0.25];
}

@end


@implementation QSBQuery(QSBQueryPrivateMethods)

// called when enough time has elapsed that we want to display some results
// to the user.
- (void)displayTimerElapsed:(NSTimer*)timer {
  if (timer == shortcutDisplayTimer_) {
    currentResultDisplayCount_ = 1;
  } else if (timer == firstTierDisplayTimer_) {
    // Fill most of the rows, but leave a few for good but slow results.
    currentResultDisplayCount_ = (int)(0.8 * [self maximumResultsToCollect]);
  } else {
    // Leave one slot for the very best (queryDidFinish: sets
    // currentResultDisplayCount_ = [self maximumResultsToCollect]
    currentResultDisplayCount_ = [self maximumResultsToCollect] - 1;
  }
  [self updateDesktopResults];
  
  // If we've locked down all the rows, we can go ahead and cancel the query now
  if ([lockedResults_ count] == [self maximumResultsToCollect]) {
    [queryController_ cancel];
  }
}

// start three display timers for 100, 300 and 750ms. We retain them
// so we can cancel them if the query finishes early.
- (void)startDisplayTimers {
  // We need the first cutoff to be below the user's "instant" threshold
  // for autocomplete to feel right.
  const CGFloat kShortcutDisplayInterval = 0.100;
  const CGFloat kFirstTierDisplayInterval = 0.300;
  const CGFloat kSecondTierDisplayInterval = 0.750;
  
  shortcutDisplayTimer_ =
      [[NSTimer scheduledTimerWithTimeInterval:kShortcutDisplayInterval
                                        target:self
                                      selector:@selector(displayTimerElapsed:)
                                      userInfo:@"shortcutTimer"
                                       repeats:NO] retain];
  firstTierDisplayTimer_ =
      [[NSTimer scheduledTimerWithTimeInterval:kFirstTierDisplayInterval 
                                        target:self
                                      selector:@selector(displayTimerElapsed:)
                                      userInfo:@"firstTierTimer"
                                       repeats:NO] retain];
  secondTierDisplayTimer_ =
      [[NSTimer scheduledTimerWithTimeInterval:kSecondTierDisplayInterval 
                                        target:self
                                      selector:@selector(displayTimerElapsed:)
                                      userInfo:@"secondTierTimer"
                                       repeats:NO] retain];
}

// cancels all timers and clears the member variables.
- (void)cancelDisplayTimers {
  [shortcutDisplayTimer_ invalidate];
  [shortcutDisplayTimer_ release];
  shortcutDisplayTimer_ = nil;
  [firstTierDisplayTimer_ invalidate];
  [firstTierDisplayTimer_ release];
  firstTierDisplayTimer_ = nil;
  [secondTierDisplayTimer_ invalidate];
  [secondTierDisplayTimer_ release];
  secondTierDisplayTimer_ = nil;
}

- (void)cancelAndReleaseQueryController {
  if (queryController_) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:nil object:queryController_];
    [queryController_ cancel];
    [queryController_ release];
    queryController_ = nil;
  }
}

- (void)setMoreResults:(NSDictionary *)value {
  [moreResults_ autorelease];
  moreResults_ = [value retain];
  [moreResultsViewDelegate_ setMoreResultsWithDict:value];
}

- (BOOL)updateMoreResultsWithInterval:(NSTimeInterval)minimumInterval {
  NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
  if (fpclassify(minimumInterval) == FP_ZERO
      || (lastMoreUpdateTime_ + minimumInterval) < currentTime
      || [queryController_ queriesFinished]) {
    lastMoreUpdateTime_ = currentTime;
    // TODO(dmaclach): figure out why this is causing crashes running on a 
    // separate thread. For right now push it on main. Left code in here for
    // future fix
#if 0
    NSOperation *updateMoreOp
      = [[[NSInvocationOperation alloc]
          initWithTarget:self
                selector:@selector(updateMoreResultsOperation:)
                  object:nil]
         autorelease];
    NSOperationQueue *sharedQueue
      = [[[HGSModuleLoader sharedModuleLoader] delegate] sharedOperationQueue];
    [sharedQueue addOperation:updateMoreOp];
#else
    NSDictionary *resultsByCategory = [queryController_ rankedResultsByCategory];
    [self setMoreResults:resultsByCategory];
#endif
  }
  return NO;
}

- (void)updateMoreResultsOperation:(id)unused {
  NSDictionary *resultsByCategory = [queryController_ rankedResultsByCategory];
  [self performSelectorOnMainThread:@selector(setMoreResults:)
                         withObject:resultsByCategory
                      waitUntilDone:NO];
}

@end
