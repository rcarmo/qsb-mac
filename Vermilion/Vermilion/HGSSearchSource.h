//
//  HGSSearchSource.h
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
  @discussion HGSSearchSource
*/

#import <Vermilion/HGSExtension.h>

@class HGSResult;
@class HGSQuery;
@class HGSSearchOperation;
@class HGSTypeFilter;

/*!
  An abstraction for searching a particular collection of data. There will be
  many search sources that provide results to a query and the results of a
  given search source may span many result types.
 
  Query Flow:
  
  If the query has a pivot object, the calling code will check if the
  source handles that type for pivots (|pivotableTypes|).  Then the calling
  code will call |isValidSourceForQuery:| to perform any other validation.  If
  all of those pass, then |searchOperationForQuery:| gets called.
*/
@interface HGSSearchSource : HGSExtension {
 @protected
  NSSet *pivotableTypes_;
  NSSet *utisToExcludeFromDiskSources_;
  HGSTypeFilter *resultTypeFilter_;
  BOOL cannotArchive_;
}

/*!
 The list of types this source can do a pivot search on. Defaults to the value 
 of "HGSSearchSourcePivotTypes" from config dict. Set
 "HGSSearchSourcePivotTypes" to \@"*" to pivot on any type
*/
@property (readonly) NSSet *pivotableTypes;

/*!
 Returns whether the results for the source should be added to the QSB shortcuts
 list. Default to the value of "HGSSearchSourceCannotArchive", or NO if that key
 is not defined.
 */
@property (readonly) BOOL cannotArchive;

/*!
  Allows a Search Sources to claim a set of file UTIs that should be ignored by
  any sources that walk file systems because this source is returning them
  through other means.  This allows a source to prevent something like a
  Spotlight based source from returning the MetaData files normally used by
  Spotlight.

  NOTES:
     1 this can not change over time as callers are allowed to cache the value
       for the lifetime of the app for performance reasons.
     2 this can be called on any thread, so keep that in mind for a sources
       implementation.
 
  Defaults to nil or the value of kHGSSearchSourceUTIsToExcludeFromDiskSources
  from the config dict.
*/
@property (readonly) NSSet *utisToExcludeFromDiskSources;

/*! 
  If YES this source returns icons for it's results so we will use it to get
  kHGSObjectAttributeImmediateIconKey and kHGSObjectAttributeIconKey instead
  of using HGSIconProvider. 
 
  Defaults to NO.
*/
@property (readonly) BOOL providesIconsForResults;

/*!
 A definition of the types that this source will provide. It is made up of
 the value of "HGSSearchSourceSupportedTypes" and 
 "HGSSearchSourceUnsupportedTypes" from the configuration dictionary.
*/
@property (readonly) HGSTypeFilter *resultTypeFilter;

/*!
  Returns whether this source is valid for the query string/terms.
  @result YES if there's a pivot or if -[HGSQuery uniqueWords] returns a set of 
          one or more items.
*/
- (BOOL)isValidSourceForQuery:(HGSQuery *)query;

/*!
  Returns an operation to search this source for |query| and posts notifs to
  |observer|. Sources can override this factory method to return something that
  holds state specific to the source.
*/
- (HGSSearchOperation *)searchOperationForQuery:(HGSQuery *)query;

/*!
  Fetch the actual value. This returns value. In some cases you will get a temp
  value that will be updated in the future via KVO.
  @result Base implementation returns nil.
*/
- (id)provideValueForKey:(NSString *)key result:(HGSResult *)result;

/*!
  Supports archiving something for the source to allow the result to be
  remembered in shortcuts.
  
  Simply store the key/value pars in the dict you need to recreate your object.
  
  If the config dict has the boolean "HGSSearchSourceCannotArchive" set to
  YES, this will return nil. (blocking archiving).
 
  If your source would like to store any source-specific key/value pair then
  override -[HGSSearchSource archiveKeys] to provide a set of the keys to
  add to the archive.  See -[HGSSearchSource archiveKeys] for more on this.
 
  @result Base implementation archives
          1 kHGSObjectAttributeNameKey,
          2 kHGSObjectAttributeURIKey,
          3 kHGSObjectAttributeTypeKey,
          4 kHGSObjectAttributeSnippetKey,
          5 kHGSObjectAttributeSourceURLKey
*/
- (NSMutableDictionary *)archiveRepresentationForResult:(HGSResult *)result;

/*!
  Provide an array of keys of result attributes to be archived.  The default
  implementation returns nil.
*/
- (NSArray *)archiveKeys;

/*! 
  Reanimate a result based on a dictionary created by
  archiveRepresentationForResult:.
*/
- (HGSResult *)resultWithArchivedRepresentation:(NSDictionary *)representation;

/*!
  Called when interest is expressed in "result".
  Allows the source to refine it's future searches.
  Base implementation does nothing.
*/ 
- (void)promoteResult:(HGSResult *)result;

/*!
  Returns the class that the source should use to instantiate results.
*/
- (Class)resultClass;

@end

/*!
  kHGSValidateSearchSourceBehaviorsPrefKey is a boolean preference that the
  engine can use to enable extra logging about Source behaviors to help
  developers make sure their Source is acting right.  The pref should be set
  before launch to ensure it is all possible checks are done.
*/
#define kHGSValidateSearchSourceBehaviorsPrefKey \
  @"HGSValidateSearchSourceBehaviors"

/*!
  kHGSSearchSourceUTIsToExcludeFromDiskSources allows sources to define UTIs
  that we will exclude from disk sources (specifically spotlight). See comment
  about utisToExcludeFromDiskSources above.
*/
extern NSString *const kHGSSearchSourceUTIsToExcludeFromDiskSourcesKey;

/*!
 Configuration dictionary key that along with 
 kHGSSearchSourceUnsupportedTypesKey controls resultTypeFilter.
*/
extern NSString *const kHGSSearchSourceSupportedTypesKey;

/*!
 Configuration dictionary key that along with 
 kHGSSearchSourceSupportedTypesKey controls resultTypeFilter.
*/
extern NSString *const kHGSSearchSourceUnsupportedTypesKey;

/*!
 Configuration dictionary key that controls pivotableTypes.
*/
extern NSString *const kHGSSearchSourcePivotableTypesKey;

/*!
 Configuration dictionary key that controls cannotArchive.
*/
extern NSString *const kHGSSearchSourceCannotArchiveKey;

/*!
 A simple way to register a source for things that we generate in non-standard
 ways, such as items that are dragged in, or otherwise.
*/
@interface HGSSimpleNamedSearchSource : HGSSearchSource
+ (id)sourceWithName:(NSString *)displayName 
          identifier:(NSString *)identifier 
              bundle:(NSBundle *)bundle;

- (id)initWithName:(NSString *)displayName 
        identifier:(NSString *)identifier 
            bundle:(NSBundle *)bundle;
@end
