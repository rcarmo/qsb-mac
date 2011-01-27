//
//  HGSObject.h
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

#import <Foundation/Foundation.h>

@protocol HGSSearchSource;

// Support the icon property: the phone needs to treat this as a different class
#if TARGET_OS_IPHONE
@class UIImage;
typedef UIImage NSImage;
#else
@class NSImage;
#endif

// public value keys
extern NSString* const kHGSObjectAttributeNameKey;  // NSString
extern NSString* const kHGSObjectAttributeURIKey;  // NSURL
extern NSString* const kHGSObjectAttributeUniqueIdentifiersKey; // NSArray (of NSStrings)
extern NSString* const kHGSObjectAttributeTypeKey;  // NSString

// Last Used Date can be set using the key, but should be retrieved using
// the [HGSObject lastUsedDate] method. It will not be in the value dictionary.
extern NSString* const kHGSObjectAttributeLastUsedDateKey;  // NSDate
extern NSString* const kHGSObjectAttributeSnippetKey;  // NSString
extern NSString* const kHGSObjectAttributeSourceURLKey;  // NSString
// Icon Key returns the icon lazily (default for things in the table)
// Immediate Icon Key blocks the UI until we get an icon back
extern NSString* const kHGSObjectAttributeIconKey;  // NSImage
extern NSString* const kHGSObjectAttributeImmediateIconKey;  // NSImage
extern NSString* const kHGSObjectAttributeIconPreviewFileKey;  // NSURL
extern NSString* const kHGSObjectAttributeIsSyntheticKey;  // NSNumber (BOOL)
extern NSString* const kHGSObjectAttributeIsCorrectionKey;  // NSNumber (BOOL)
extern NSString* const kHGSObjectAttributeIsContainerKey;  // NSNumber (BOOL)
extern NSString* const kHGSObjectAttributeDefaultActionKey;  // id<HGSAction>
// Path cell-related keys
extern NSString* const kHGSObjectAttributePathCellClickHandlerKey;  // selector as string
extern NSString* const kHGSObjectAttributePathCellsKey;  // NSArray of NSDictionaries
extern NSString* const kHGSPathCellDisplayTitleKey;  // NSString
extern NSString* const kHGSPathCellImageKey;  // NSImage
extern NSString* const kHGSPathCellURLKey;  // NSURL
extern NSString* const kHGSPathCellHiddenKey;  // NSNumber (BOOL)

extern NSString* const kHGSObjectAttributeContactEmailKey; // NSString - Primary email address
extern NSString* const kHGSObjectAttributeEmailAddressesKey; // NSArray of NSString - Related email addresses
extern NSString* const kHGSObjectAttributeContactsKey; // NSArray of NSString - Names of related people

// Chat buddy-related keys
extern NSString* const kHGSObjectAttributeBuddyMatchingStringKey; // NSString
extern NSString* const kHGSIMBuddyInformationKey; // NSDictionary

extern NSString* const kHGSObjectAttributeAlternateActionURIKey; // NSURL - url to be opened for accessory cell in mobile

extern NSString* const kHGSObjectAttributeWebSearchDisplayStringKey; // Display string to replace "Search %@" when it doesn't make sense
extern NSString* const kHGSObjectAttributeWebSearchTemplateKey; // NSString
extern NSString* const kHGSObjectAttributeAllowSiteSearchKey; // NSNumber BOOL - Allow this item to be tabbed into
extern NSString* const kHGSObjectAttributeWebSuggestTemplateKey; // NSString - JSON suggest url (in google/opensearch format)
extern NSString* const kHGSObjectAttributeStringValueKey; // NSString

// Keys for attribute dictionaries. Use accesors to get values.
extern NSString* const kHGSObjectAttributeRankFlagsKey;  // NSNumber of HGSRankFlags
extern NSString* const kHGSObjectAttributeRankKey;  // NSNumber 0-10... (estimated number of uses in 7 days?)

extern NSString* const kHGSObjectAttributeAddressBookRecordIdentifierKey;  // NSValue (NSInteger)

// The "type" system used for results is based on string hierarchies (similar to
// reverse dns names).  The common bases are "contact", "file", "webpage", etc.
// A source can then refine them to be more specific: "contact.addressbook",
// "contact.google", "webpage.bookmark".  These strings are meant to be case
// sensitive (to allow for faster compares).  There are two helpers (isOfType:
// and conformsToType:) that allow the caller to check to see if a result is of
// a certain type or refinement of that type.  The HGS_SUBTYPE macro is to be
// used in the construction of string hierarchies with more than one segment.
// Types can be made up of multiple segments to refine them as specifically as
// needed.
#define HGS_SUBTYPE(x,y) x @"." y
// Here are the current bases/common types, that DOES NOT mean that is all the
// valid base types are.  New sources are free to add new types.
#define kHGSTypeContact @"contact"
#define kHGSTypeFile    @"file"
#define kHGSTypeEmail   @"email"
#define kHGSTypeWebpage @"webpage"
#define kHGSTypeOnebox  @"onebox"
#define kHGSTypeAction  @"action"
#define kHGSTypeSuggest @"suggestion"
#define kHGSTypeSearch  @"search"
#define kHGSTypeScript  @"script"
#define kHGSTypeText    @"text"
#define kHGSTypeDirectory        HGS_SUBTYPE(kHGSTypeFile, @"directory")
#define kHGSTypeTextFile         HGS_SUBTYPE(kHGSTypeFile, @"text")
#define kHGSTypeFileApplication  HGS_SUBTYPE(kHGSTypeFile, @"application")
#define kHGSTypeWebBookmark      HGS_SUBTYPE(kHGSTypeWebpage, @"bookmark")
#define kHGSTypeWebHistory       HGS_SUBTYPE(kHGSTypeWebpage, @"history")
#define kHGSTypeWebApplication   HGS_SUBTYPE(kHGSTypeWebpage, @"application")
#define kHGSTypeGoogleSuggest    HGS_SUBTYPE(kHGSTypeSuggest, @"googlesuggest")
#define kHGSTypeGoogleNavSuggest HGS_SUBTYPE(kHGSTypeWebpage, @"googlenavsuggest")
#define kHGSTypeGoogleSearch     HGS_SUBTYPE(kHGSTypeSearch,  @"googlesearch")
// Media splits into file. and webpage. because most actions will need to know
// how to act on them based on how they are fetched.
#define kHGSTypeFileMedia        HGS_SUBTYPE(kHGSTypeFile, @"media")
#define kHGSTypeFileMusic        HGS_SUBTYPE(kHGSTypeFileMedia, @"music")
#define kHGSTypeFileImage        HGS_SUBTYPE(kHGSTypeFileMedia, @"image")
#define kHGSTypeFileMovie        HGS_SUBTYPE(kHGSTypeFileMedia, @"movie")
#define kHGSTypeWebMedia         HGS_SUBTYPE(kHGSTypeWebpage, @"media")
#define kHGSTypeWebMusic         HGS_SUBTYPE(kHGSTypeWebMedia, @"music")
#define kHGSTypeWebImage         HGS_SUBTYPE(kHGSTypeWebMedia, @"image")
#define kHGSTypeWebMovie         HGS_SUBTYPE(kHGSTypeWebMedia, @"movie")
// TODO(dmaclach): should album inherit from image?
#define kHGSTypeFilePhotoAlbum   HGS_SUBTYPE(kHGSTypeFileImage,   @"album") 
#define kHGSTypeWebPhotoAlbum    HGS_SUBTYPE(kHGSTypeWebImage,   @"album") 
#define kHGSTypeTextUserInput    HGS_SUBTYPE(kHGSTypeText, @"userinput")
#define kHGSTypeTextPhoneNumber  HGS_SUBTYPE(kHGSTypeText, @"phonenumber")
#define kHGSTypeTextEmailAddress HGS_SUBTYPE(kHGSTypeText, @"emailaddress")
#define kHGSTypeTextInstantMessage HGS_SUBTYPE(kHGSTypeText, @"instantmessage")
//
// HGSObject
//
// Encapsulates a search result. May not directly contain all information about
// the result, but can use |source| to provide it lazily when needed for
// display or comparison purposes.
//
// The source may provide results lazily and will send notifications to anyone
// registered with KVO.  Consumers of the attributes shouldn't need to concern
// themselves with the details of pending loads or caching of results, but
// should call |-cancelAllPendingAttributeUpdates| when details of an object are
// no longer required (eg, the user has selected a different result or cleared
// the search).

enum {
  eHGSNameMatchRankFlag = 1 << 0,
  eHGSUserPersistentPathRankFlag = 1 << 1,
  eHGSLaunchableRankFlag = 1 << 2,
  eHGSSpecialUIRankFlag = 1 << 3,
  eHGSUnderHomeRankFlag = 1 << 4,
  eHGSUnderDownloadsRankFlag = 1 << 5,
  eHGSUnderDesktopRankFlag = 1 << 6,
  eHGSSpamRankFlag = 1 << 7,
  eHGSHomeChildRankFlag = 1 << 8,
  eHGSBelowFoldRankFlag = 1 << 9,
};

typedef NSUInteger HGSRankFlags;

@interface HGSObject : NSObject <NSCopying, NSMutableCopying> {
 @protected
  // Used for global ranking, set by the Search Source that creates it.
  HGSRankFlags rankFlags_;
  CGFloat rank_;
  NSString *identifier_;
  NSUInteger idHash_;
  NSString *name_;
  NSString *type_;
  id <HGSSearchSource> source_;
  // TODO(pink) - Cole had the idea that some of the values should be marked
  //    as purgable or cacheable (eg, preview) so that they can be tossed if we
  //    determine we're taking up too much memory, or if they're really expensive
  //    to generate, they can be cached. However, the cacheable nature doesn't
  //    seem like something anyone outside of the providing SearchSource should
  //    have to care about.
  NSMutableDictionary* values_;  // All accesses to values_ must be synchronized
  BOOL conformsToContact_;
  NSString *normalizedIdentifier_; // Only webpages have normalizedIdentifiers
  NSDate *lastUsedDate_;
};

// Convenience methods 
+ (id)objectWithIdentifier:(NSURL*)uri
                      name:(NSString *)name
                      type:(NSString *)typeStr
                    source:(id<HGSSearchSource>)source
                attributes:(NSDictionary *)attributes;

+ (id)objectWithFilePath:(NSString *)path 
                  source:(id<HGSSearchSource>)source 
              attributes:(NSDictionary *)attributes;

// Create an object based on a dictionary of keys. Note that even though
// kHGSObjectAttributeURIKey is documented as being a NSURL, it needs to be
// an NSString and will be converted internally.
+ (id)objectWithDictionary:(NSDictionary *)dictionary 
                    source:(id<HGSSearchSource>)source;
  
- (id)initWithIdentifier:(NSURL*)uri
                    name:(NSString *)name
                    type:(NSString *)typeStr
                  source:(id<HGSSearchSource>)source
              attributes:(NSDictionary *)attributes;

- (id)initWithDictionary:(NSDictionary*)dict
                  source:(id<HGSSearchSource>)source;

// get and set attributes. |-valueForKey:| may return a placeholder value
// that is to be updated later via KVO.
// TODO(dmaclach)get rid of setValue:forKey: support
- (void)setValue:(id)obj forKey:(NSString*)key;
- (id)valueForKey:(NSString*)key;

// URI for result
- (NSURL*)identifier;

// The name by which this result shall be known.
- (NSString*)displayName;

// The type, of this result.
- (NSString*)type;

// Some helpers to check if this result is of a given type.  |isOfType| checks
// for an exact match of the type.  |conformsToType{Set}| checks to see if this
// object is of the specific type{s} or a refinement of it/them.
- (BOOL)isOfType:(NSString *)typeStr;
- (BOOL)conformsToType:(NSString *)typeStr;
- (BOOL)conformsToTypeSet:(NSSet *)typeSet;

// The source which will handle this result.
- (id<HGSSearchSource>)source;

// Either an NSURL or slash-delimeted NSString giving a path to the 
// selected result.
// TODO(mrossetti): Implement at some point path cell click handling.
- (id)displayPath;

- (NSImage*)displayIconWithLazyLoad:(BOOL)lazyLoad;

- (CGFloat)rank;

- (HGSRankFlags)rankFlags;

- (NSDate *)lastUsedDate;

// merge the attributes of |result| into this one. Single values that overlap
// are lost, arrays and dictionaries are merged together to form the union.
// TODO(dmaclach): get rid of mergewith
- (void)mergeWith:(HGSObject*)result;

// this is result a "duplicate" of |compareTo|? Not using |-isEqual:| because 
// that impacts how the object gets put into collections.
- (BOOL)isDuplicate:(HGSObject*)compareTo;

@end

@interface HGSMutableObject : HGSObject
- (void)setRankFlags:(HGSRankFlags)flags;
- (void)addRankFlags:(HGSRankFlags)flags;
- (void)removeRankFlags:(HGSRankFlags)flags;
- (void)setRank:(CGFloat)rank;
@end

// Each subclass defines its own set of public value keys for both display
// and dupe-detection purposes.

extern NSString* const kHGSObjectAttributeVisitedCountKey;  // NSValue (NSInteger)


// Convenience methods for getting file paths out of HGSObjects
@interface HGSObject (HGSFileConvenienceMethods)
- (NSArray *)filePaths; // Array of strings
@end
