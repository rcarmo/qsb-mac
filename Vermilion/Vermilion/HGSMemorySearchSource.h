//
//  HGSMemorySearchSource.h
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

#import <Vermilion/HGSCallbackSearchSource.h>

/*!
 @header
 @discussion HGSMemorySearchSource
*/

@class HGSQuery;
@class HGSResultArray;
@class HGSMemorySearchSourceDB;

/*!
 Subclass of HGSCallbackSearchSource that handles the search logic for simple
 sources that precompute all possible results and keep them in memory.
 
 When a query comes in, all items will be passed through
 |preFilterResult:matchesForQuery:pivotObject:|, then they will be filtered
 by name  and then passed through
 |postFilterScoredResult:matchesForQuery:pivotObject:| and returned. The default
 implementations of the filters do nothing, so by default results will be
 returned unchanged.
 
 HGSMemorySearchSource gets the base behavior for |pivotableTypes| and
 |isValidSourceForQuery:|, meaning it will support a query without a context
 object, but not match if there is a context (pivot) object.  Subclasses can
 override this method to support pivots.  When a query with a pivot without a
 search term comes in, all objects are returned as matches, meaning they all
 get sent to the pre and post filter methods, the subclass then has the
 responsibility to filter based on the pivot object.
*/
@interface HGSMemorySearchSource : HGSCallbackSearchSource {
 @private
  HGSMemorySearchSourceDB* resultsDatabase_;
  NSUInteger cacheHash_;
  NSString *cachePath_;
}


/*!
 Swaps out the current database with the new database. It makes a copy
 of the database so you can mutate your instance.
*/
- (void)replaceCurrentDatabaseWith:(HGSMemorySearchSourceDB *)database;

/*!
 Save the contents of the memory index to disk. If the contents of the index
 haven't changed since the last call to saveResultsCache or loadResultsCache,
 the write is skipped (although there is still a small amount of overhead
 in determining whether or not the index has changed). The usage pattern is
 to call saveResultsCache after each periodic or event-triggered indexing
 pass, and call loadResultsCache once at startup so that the previous
 index is immediately available, though perhaps a little stale.
 @seealso //google_vermilion_ref/occ/instm/HGSMemorySearchSource/loadResultsCache loadResultsCache
*/
- (void)saveResultsCache;

/*!
 Load the results saved by a previous call to 
 saveResultsCache, populating
 the memory index (and overwriting any existing entries in the index).
 @result Returns yes if anything was loaded into the cache.
 @seealso //google_vermilion_ref/occ/instm/HGSMemorySearchSource/saveResultsCache saveResultsCache
*/
- (BOOL)loadResultsCache;

/*!
 Return an array of HGSRankedResults that match query.
 @param results initial array of results
 @param operation Operation to match
 @result array of HGSRankedResults
*/
- (NSArray *)rankedResultsFromArray:(NSArray *)results 
                       forOperation:(HGSCallbackSearchOperation *)operation;
@end

/*! These are methods subclasses can override to control behaviors. */
@interface HGSMemorySearchSource (ProtectedMethods)

/*!
 Called for each result before HGSMemorySearchSource does it's default
 name matching. Use it to filter our results that are easy to remove without
 going through our name ranking. The returned result is what is passed through
 the name matching and eventually added to results if applicable. Default
 version just returns result. Return nil if you want the result filtered out.
*/
- (HGSResult *)preFilterResult:(HGSResult *)result 
               matchesForQuery:(HGSQuery*)query
                  pivotObjects:(HGSResultArray *)pivotObjects;
/*!
 Called for each result after HGSMemorySearchSource does it's default
 name matching. Use it to filter our results that cost more than our name 
 ranking. (eg anything that hits the disk). Return nil to filter out the
 result. Default version just returns result.
*/
- (HGSScoredResult *)postFilterScoredResult:(HGSScoredResult *)result 
                            matchesForQuery:(HGSQuery *)query
                               pivotObjects:(HGSResultArray *)pivotObjects;
 
@end

/*! 
 A database that contains indexed HGSResults. Used by HGSMemorySearchSource
 for quickly finding and sorting results.
*/
@interface HGSMemorySearchSourceDB : NSObject <NSCopying> {
 @private
  NSMutableArray* storage_;
}

/*!
 Return an empty database.
 @result an empty autoreleased HGSMemorySearchSourceDB instance.
*/
+ (id)database;

/*!
 Add a result.
 
 The two strings (name and otherTerm) will be properly tokenized for the caller, 
 so pass them in as raw unnormalized, untokenized strings.
 @param hgsResult the result to index.
 @param name is the word that counts as a name match for hgsResult. 
 @param otherTerm is another term that can be used to match hgsResult but is
 of less importance than name. This argument is optional and can be nil.
 */
- (void)indexResult:(HGSResult *)hgsResult
               name:(NSString *)name
          otherTerm:(NSString *)otherTerm;

/*!
 Add a result.
 
 The strings (name and otherTerms) will be properly tokenized for the caller, 
 so pass them in as raw unnormalized, untokenized strings.
 @param hgsResult the result to index
 @param name is the word that counts as a name match for hgsResult. 
 @param otherTerms is an array of terms that can be used to match hgsResult but 
 are of less importance than name. This argument is optional and can be nil.
 */
- (void)indexResult:(HGSResult *)hgsResult
               name:(NSString *)name
         otherTerms:(NSArray *)otherTerms;

/*!
 Add a result.
 Equivalent to calling 
 @link indexResult:name:otherTerm: indexResult:name:otherTerm: @/link
 with name set to the displayName of the hgsResult, and nil for otherTerm. 
 @param hgsResult the result to index.
 */
- (void)indexResult:(HGSResult *)hgsResult;

@end

