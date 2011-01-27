//
//  HGSResult.h
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
  @discussion HGSResult
*/

#import <Foundation/Foundation.h>

@class HGSSearchSource;
@class HGSTokenizedString;
@class HGSIconProvider;

// Support the icon property: the phone needs to treat this as a different class
#if TARGET_OS_IPHONE
@class UIImage;
typedef UIImage NSImage;
#else
@class NSImage;
#endif

// public value keys
extern NSString* const kHGSObjectAttributeNameKey;  // NSString
extern NSString* const kHGSObjectAttributeURIKey;  // NSString
extern NSString* const kHGSObjectAttributeUniqueIdentifiersKey; // NSArray (of NSStrings)
extern NSString* const kHGSObjectAttributeTypeKey;  // NSString
extern NSString* const kHGSObjectAttributeStatusKey;  // NSString

// Last Used Date can be set using the key, but should be retrieved using
// the [HGSResult lastUsedDate] method. It will not be in the value dictionary.
extern NSString* const kHGSObjectAttributeLastUsedDateKey;  // NSDate
extern NSString* const kHGSObjectAttributeSnippetKey;  // NSString
extern NSString* const kHGSObjectAttributeSourceURLKey;  // NSString
// Icon Key returns the icon lazily (default for things in the table)
// Immediate Icon Key blocks the UI until we get an icon back
extern NSString* const kHGSObjectAttributeIconKey;  // NSImage
extern NSString* const kHGSObjectAttributeImmediateIconKey;  // NSImage
extern NSString* const kHGSObjectAttributeIconPreviewFileKey;  // NSString - either an URL or a filepath
extern NSString* const kHGSObjectAttributeFlagIconNameKey;  // NSString
extern NSString* const kHGSObjectAttributeAliasDataKey;  // NSData
extern NSString* const kHGSObjectAttributeIsSyntheticKey;  // NSNumber (BOOL)
extern NSString* const kHGSObjectAttributeIsContainerKey;  // NSNumber (BOOL)
extern NSString* const kHGSObjectAttributeDefaultActionKey;  // id<HGSAction>
extern NSString* const kHGSObjectAttributeActionDirectObjectsKey;  // HGSResultArray
extern NSString* const kHGSObjectAttributeContactEmailKey; // NSString - Primary email address
extern NSString* const kHGSObjectAttributeEmailAddressesKey; // NSArray of NSString - Related email addresses
extern NSString* const kHGSObjectAttributeContactsKey;  // NSArray of NSString - Names of related people
extern NSString* const kHGSObjectAttributeBundleIDKey;  // NSString - Bundle ID
extern NSString* const kHGSObjectAttributeAlternateActionURIKey; // NSURL - url to be opened for accessory cell in mobile
extern NSString* const kHGSObjectAttributeUTTypeKey;  // NSString - UTType

extern NSString* const kHGSObjectAttributeWebSearchDisplayStringKey; // Display string to replace "Search %@" when it doesn't make sense
extern NSString* const kHGSObjectAttributeWebSearchTemplateKey; // NSString
extern NSString* const kHGSObjectAttributeAllowSiteSearchKey; // NSNumber BOOL - Allow this item to be tabbed into
extern NSString* const kHGSObjectAttributeWebSuggestTemplateKey; // NSString - JSON suggest url (in google/opensearch format)
extern NSString* const kHGSObjectAttributeStringValueKey; // NSString
extern NSString* const kHGSObjectAttributePasteboardValueKey; // NSDictionary of types(NSString) to NSData

// Keys for attribute dictionaries. Use accesors to get values.
extern NSString* const kHGSObjectAttributeRankFlagsKey;  // NSNumber of HGSRankFlags
extern NSString* const kHGSObjectAttributeMatchedTermKey;  // NSString the term we matched

extern NSString* const kHGSObjectAttributeAddressBookRecordIdentifierKey;  // NSValue (NSInteger)

/*! 
 @const
 Prevent Google Web Source from searching this result using site search.
 BOOL value. Default NO.
 */
extern NSString *const kHGSObjectAttributeHideGoogleSiteSearchResultsKey;

enum {
  eHGSNameMatchRankFlag = 1 << 0,
  eHGSUserPersistentPathRankFlag = 1 << 1,
  eHGSLaunchableRankFlag = 1 << 2,
  eHGSSpecialUIRankFlag = 1 << 3,
  eHGSUnderHomeRankFlag = 1 << 4,
  eHGSHomeChildRankFlag = 1 << 8,
  eHGSBelowFoldRankFlag = 1 << 9,
  eHGSShortcutRankFlag = 1 << 10,
};
typedef NSUInteger HGSRankFlags;

// String constants indicating a result's status as stored in the result
// attribute with the kHGSObjectAttributeStatusKey key. The lack of this
// attribute indicates a status of 'valid'.
extern NSString* const kHGSObjectStatusStaleValue;

/*!
  Encapsulates a search result. May not directly contain all information about
  the result, but can use |source| to provide it lazily when needed for display
  or comparison purposes.
  
  The source may provide results lazily and will send notifications to anyone
  registered with KVO.  Consumers of the attributes shouldn't need to concern
  themselves with the details of pending loads or caching of results.
 
  This is an abstract class. The concrete subclasses are HGSScoredResult, and
  HGSUnscoredResult.
*/
@interface HGSResult : NSObject <NSCopying> {
 @public
  NSUInteger hash_;
  HGSIconProvider *iconProvider_;
}

/*!
 Get an attribute by name. |-valueForKey:| may return a placeholder value that
 is to be updated later via KVO.
 */
- (id)valueForKey:(NSString*)key;

/*!
 Is it a local file
 */
- (BOOL)isFileResult;

/*!
 Some helpers to check if this result is of a given type.  -[isOfType:] checks
 for an exact match of the type.
*/
- (BOOL)isOfType:(NSString *)typeStr;
- (BOOL)conformsToType:(NSString *)typeStr;

/*!
 Is this result a "duplicate" of |compareTo|? Not using |-isEqual:| because
 that impacts how the object gets put into collections.
 */
- (BOOL)isDuplicate:(HGSResult *)compareTo;

/*!
 Mark this result as having been of interest to the user.
 Base implementation sends a promoteResult message to the result's source,
 and sends out a "kHGSResultDidPromoteNotification".
 */
- (void)promote;

/*!
 Return a new result by adding attributes from result to self.
 If both self and result contain a value for an attribute, self is not changed
 for that attribute.
 */
- (id)resultByAddingAttributesFromResult:(HGSResult *)result;

/*!
 URL for the result.
 */
-(NSURL *)url;

/*!
 Filepath for the result.
 */
-(NSString *)filePath;

/*!
 The display name for the result. Must be implemented by subclass.
*/
- (NSString *)displayName;

/*!
 URI for the result. Must be implemented by subclass.
 */
- (NSString *)uri;

/*!
 Type of the result. See kHGSType constants. Must be implemented by subclass.
 */
- (NSString *)type;

/*!
 The source which supplied this result. Must be implemented by subclass.
 */
-(HGSSearchSource *)source;



/*!
 Return a new result by adding attributes to self. 
 If both self and attributes contain a value for an attribute, self is not
 changed for that attribute.
 Must be implemented by subclass.
 */
- (id)resultByAddingAttributes:(NSDictionary *)attributes;

@end

/*!
 A result that hasn't been scored against a query.
*/
@interface HGSUnscoredResult : HGSResult {
 @private
  NSString *uri_;
  NSString *displayName_;
  NSString *type_;
  HGSSearchSource *source_;
  NSDictionary *attributes_;  
}

/*!
 Designated initializer.
*/
- (id)initWithURI:(NSString *)uri
             name:(NSString *)name
             type:(NSString *)typeStr
           source:(HGSSearchSource *)source 
       attributes:(NSDictionary *)attributes;
/*!
 Convenience methods
*/
+ (id)resultWithURL:(NSURL *)url
               name:(NSString *)name
               type:(NSString *)typeStr
             source:(HGSSearchSource *)source
         attributes:(NSDictionary *)attributes;

+ (id)resultWithFilePath:(NSString *)path
                  source:(HGSSearchSource *)source 
              attributes:(NSDictionary *)attributes;

+ (id)resultWithURI:(NSString *)uri
               name:(NSString *)name
               type:(NSString *)type
             source:(HGSSearchSource *)source
         attributes:(NSDictionary *)attributes;

/*!
 Create an result based on a dictionary of keys. 
 */
+ (id)resultWithDictionary:(NSDictionary *)dictionary 
                    source:(HGSSearchSource *)source;

- (id)initWithDictionary:(NSDictionary*)dict
                  source:(HGSSearchSource *)source;

@end

/*!
 A result that has been scored against a query.
*/
@interface HGSScoredResult : HGSResult  {
@private
  HGSResult *result_;
  CGFloat score_;
  HGSRankFlags rankFlags_;
  HGSTokenizedString *matchedTerm_;
  NSIndexSet *matchedIndexes_;
}

/*!
 The relative score of an item (from 0.0 to 1.0)
 */
@property (readonly) CGFloat score;
/*!
 Information about the item that may change it's overall ranking
 */
@property (readonly) HGSRankFlags rankFlags;
/*!
  The term that |score| was matched against.
*/
@property (readonly, copy) HGSTokenizedString *matchedTerm;
/*!
 The indexes of charactes of term that |score| was matched against.
*/
@property (readonly, retain) NSIndexSet *matchedIndexes;

- (id)initWithResult:(HGSResult *)result 
               score:(CGFloat)score
          flagsToSet:(HGSRankFlags)setFlags
        flagsToClear:(HGSRankFlags)clearFlags
         matchedTerm:(HGSTokenizedString *)term
      matchedIndexes:(NSIndexSet *)ranges;

+ (id)resultWithResult:(HGSResult *)result 
                 score:(CGFloat)score
            flagsToSet:(HGSRankFlags)setFlags
          flagsToClear:(HGSRankFlags)clearFlags
           matchedTerm:(HGSTokenizedString *)term
        matchedIndexes:(NSIndexSet *)indexes;

+ (id)resultWithURI:(NSString *)uri
               name:(NSString *)name
               type:(NSString *)type
             source:(HGSSearchSource *)source
         attributes:(NSDictionary *)attributes
              score:(CGFloat)score
              flags:(HGSRankFlags)flags
        matchedTerm:(HGSTokenizedString *)term
     matchedIndexes:(NSIndexSet *)indexes;

+ (id)resultWithFilePath:(NSString *)path
                  source:(HGSSearchSource *)source 
              attributes:(NSDictionary *)attributes
                   score:(CGFloat)score
                   flags:(HGSRankFlags)flags
             matchedTerm:(HGSTokenizedString *)term
          matchedIndexes:(NSIndexSet *)indexes;

- (id)initWithURI:(NSString *)uri
             name:(NSString *)name
             type:(NSString *)type
           source:(HGSSearchSource *)source
       attributes:(NSDictionary *)attributes
            score:(CGFloat)score
            flags:(HGSRankFlags)flags
      matchedTerm:(HGSTokenizedString *)term
   matchedIndexes:(NSIndexSet *)indexes;

@end
  
/*!
 A collection of HGSResults that acts very similar to NSArray.
*/
@interface HGSResultArray : NSObject <NSFastEnumeration> {
  NSArray *results_;
}
/*!
 The display name for the results combined.
 */
@property (readonly) NSString *displayName;

+ (id)arrayWithResult:(HGSResult *)result;
+ (id)arrayWithResults:(NSArray *)results;
+ (id)arrayWithFilePaths:(NSArray *)filePaths;
- (id)initWithResults:(NSArray *)results;
- (id)initWithFilePaths:(NSArray *)filePaths;
- (NSArray *)urls;
- (NSUInteger)count;
- (id)objectAtIndex:(NSUInteger)ind;
- (id)lastObject;
/*!
  Will return nil if any of the results does not have a valid file path
*/
- (NSArray *)filePaths;
- (NSImage *)icon;
/*!
  Some helpers to check if this result is of a given type.  |isOfType| checks
  for an exact match of the type.
*/
- (BOOL)isOfType:(NSString *)typeStr;
- (BOOL)conformsToType:(NSString *)typeStr;

/*!
 Mark these results as having been of interest to the user.
 Base implementation sends a promoteResult message to the result's source.
*/
- (void)promote;

@end

/*!
 Notification sent when a result is promoted.
 Object is the HGSScoredResult.
*/
extern NSString *const kHGSResultDidPromoteNotification;
