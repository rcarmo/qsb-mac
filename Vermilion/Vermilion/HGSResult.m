//
//  HGSResult.m
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

#import "HGSResult.h"

#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMNSEnumerator+Filter.h>
#import <GTM/GTMNSString+URLArguments.h>
#import <GTM/GTMTypeCasting.h>

#import "HGSType.h"
#import "HGSTypeFilter.h"
#import "HGSExtensionPoint.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSLog.h"
#import "HGSIconProvider.h"
#import "HGSSearchSource.h"
#import "NSString+ReadableURL.h"
#import "HGSPluginLoader.h"
#import "HGSDelegate.h"
#import "HGSBundle.h"
#import "HGSSearchSourceRanker.h"

// Notifications
NSString *const kHGSResultDidPromoteNotification
  = @"HGSResultDidPromoteNotification";

// storage and initialization for value names
NSString* const kHGSObjectAttributeNameKey = @"HGSObjectAttributeName";
NSString* const kHGSObjectAttributeURIKey = @"HGSObjectAttributeURI";
NSString* const kHGSObjectAttributeUniqueIdentifiersKey = @"HGSObjectAttributeUniqueIdentifiers";  // NSString
NSString* const kHGSObjectAttributeTypeKey = @"HGSObjectAttributeType";
NSString* const kHGSObjectAttributeStatusKey = @"HGSObjectAttributeStatus";
NSString* const kHGSObjectAttributeLastUsedDateKey = @"HGSObjectAttributeLastUsedDate";
NSString* const kHGSObjectAttributeSnippetKey = @"HGSObjectAttributeSnippet";
NSString* const kHGSObjectAttributeSourceURLKey = @"HGSObjectAttributeSourceURL";
NSString* const kHGSObjectAttributeIconKey = @"HGSObjectAttributeIcon";
NSString* const kHGSObjectAttributeImmediateIconKey = @"HGSObjectAttributeImmediateIcon";
NSString* const kHGSObjectAttributeIconPreviewFileKey = @"HGSObjectAttributeIconPreviewFile";
NSString* const kHGSObjectAttributeFlagIconNameKey = @"HGSObjectAttributeFlagIconName";
NSString* const kHGSObjectAttributeAliasDataKey = @"HGSObjectAttributeAliasData";
NSString* const kHGSObjectAttributeIsSyntheticKey = @"HGSObjectAttributeIsSynthetic";
NSString* const kHGSObjectAttributeIsContainerKey = @"HGSObjectAttributeIsContainer";
NSString* const kHGSObjectAttributeRankFlagsKey = @"HGSObjectAttributeRankFlags";
NSString* const kHGSObjectAttributeMatchedTermKey = @"HGSObjectAttributeMatchedTerm";
NSString* const kHGSObjectAttributeDefaultActionKey = @"HGSObjectAttributeDefaultAction";
NSString* const kHGSObjectAttributeActionDirectObjectsKey = @"HGSObjectAttributeActionDirectObjects";
NSString* const kHGSObjectAttributeBundleIDKey = @"HGSObjectAttributeBundleID";
NSString* const kHGSObjectAttributeWebSearchDisplayStringKey = @"HGSObjectAttributeWebSearchDisplayString";
NSString* const kHGSObjectAttributeWebSearchTemplateKey = @"HGSObjectAttributeWebSearchTemplate";
NSString* const kHGSObjectAttributeAllowSiteSearchKey = @"HGSObjectAttributeAllowSiteSearch";
NSString* const kHGSObjectAttributeWebSuggestTemplateKey = @"HGSObjectAttributeWebSuggestTemplate";
NSString* const kHGSObjectAttributeStringValueKey = @"HGSObjectAttributeStringValue";
NSString* const kHGSObjectAttributePasteboardValueKey = @"HGSObjectAttributePasteboardValue";
NSString* const kHGSObjectAttributeUTTypeKey = @"HGSObjectAttributeUTType";
NSString *const kHGSObjectAttributeHideGoogleSiteSearchResultsKey
  = @"HGSObjectAttributeHideGoogleSiteSearchResults";

// Contact related keys
NSString* const kHGSObjectAttributeContactEmailKey = @"HGSObjectAttributeContactEmail";
NSString* const kHGSObjectAttributeEmailAddressesKey = @"HGSObjectAttributeEmailAddresses";
NSString* const kHGSObjectAttributeContactsKey = @"HGSObjectAttributeContacts";
NSString* const kHGSObjectAttributeAlternateActionURIKey = @"HGSObjectAttributeAlternateActionURI";
NSString* const kHGSObjectAttributeAddressBookRecordIdentifierKey = @"HGSObjectAttributeAddressBookRecordIdentifier";

static NSString* const kHGSResultFileSchemePrefix = @"file://localhost";

NSString* const kHGSObjectStatusStaleValue = @"HGSObjectStatusStaleValue";


@interface HGSResult ()
-(NSDictionary *)attributes;
@end

@interface HGSUnscoredContactResult : HGSUnscoredResult
@end

@interface HGSUnscoredWebpageResult : HGSUnscoredResult {
 @private
  NSString *normalizedIdentifier_;
}

@property (readonly, copy) NSString *normalizedIdentifier;

@end

@implementation HGSResult

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

- (void)dealloc {
  [iconProvider_ invalidate];
  [iconProvider_ release];
  [super dealloc];
}

// if the value isn't present, ask the result source to satisfy the
// request.
- (id)valueForKey:(NSString*)key {
  id value = [[self attributes] objectForKey:key];
  if (!value) {
    if ([key isEqualToString:kHGSObjectAttributeURIKey]) {
      value = [self uri];
    } else if ([key isEqualToString:kHGSObjectAttributeNameKey]) {
      value = [self displayName];
    } else if ([key isEqualToString:kHGSObjectAttributeTypeKey]) {
      value = [self type];
    } else if ([key isEqualToString:kHGSObjectAttributeIconKey]
               || [key isEqualToString:kHGSObjectAttributeImmediateIconKey]) {
      HGSSearchSource *source = [self source];
      if ([source providesIconsForResults]) {
        value = [source provideValueForKey:key result:self];
      } else {
        @synchronized(self) {
          if (!iconProvider_) {
            HGSIconCache *cache = [HGSIconCache sharedIconCache];
            BOOL skip = [key isEqualToString:kHGSObjectAttributeImmediateIconKey];
            iconProvider_ = [[cache iconProviderForResult:self
                                          skipPlaceholder:skip] retain];
          }
          value = [iconProvider_ icon];
        }
      }
    }
    if (!value) {
      // If we haven't provided a value, ask our source for a value.
      value = [[self source] provideValueForKey:key result:self];
    }
    if (!value) {
      // If neither self or source provides a value, ask our HGSDelegate.
      HGSPluginLoader *loader = [HGSPluginLoader sharedPluginLoader];
      id <HGSDelegate> delegate = [loader delegate];
      value = [delegate provideValueForKey:key result:self];
    }
  }
  if (!value) {
    value = [super valueForKey:key];
  }
  // Done for thread safety.
  return [[value retain] autorelease];
}

- (id)valueForUndefinedKey:(NSString *)key {
  return nil;
}

- (BOOL)isFileResult {
  return [[self uri] hasPrefix:kHGSResultFileSchemePrefix];
}

- (BOOL)isOfType:(NSString *)typeStr {
  // Exact match
  BOOL result = [[self type] isEqualToString:typeStr];
  return result;
}

- (BOOL)conformsToType:(NSString *)typeStr {
  NSString *myType = [self type];
  return HGSTypeConformsToType(myType, typeStr);
}

- (BOOL)isDuplicate:(HGSResult *)compareTo {
  BOOL isDupe = NO;
  if (self->hash_ == compareTo->hash_) {
    isDupe = [[self uri] isEqualTo:[compareTo uri]];
  }
  return isDupe;
}

- (void)promote {
  [[self source] promoteResult:self];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kHGSResultDidPromoteNotification object:self];
}


- (id)resultByAddingAttributesFromResult:(HGSResult *)result {
  return [self resultByAddingAttributes:[(HGSResult *)result attributes]];
}

- (NSString*)description {
  return [NSString stringWithFormat:
          @"<%@:%p> %@ - %@ (%@ from %@)",
          [self class], self,
          [self displayName], [self type], [self class], [self source]];
}

- (NSURL *)url {
  return [NSURL URLWithString:[self uri]];
}

- (NSString *)filePath {
  NSString *path = nil;
  if ([self isFileResult]) {
    path = [[self uri] substringFromIndex:[kHGSResultFileSchemePrefix length]];
    path = [path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
  }
  return path;
}

- (NSString *)stringValue {
  return [self displayName];
}

- (NSUInteger)hash {
  return hash_;
}

#pragma mark Methods that must be overridden.

- (NSString *)displayName {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}


- (NSString *)uri {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (NSString *)type {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

-(HGSSearchSource *)source {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (NSDictionary *)attributes {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id)resultByAddingAttributes:(NSDictionary *)attributes {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}


@end

@implementation HGSUnscoredResult

- (id)initWithURI:(NSString *)uri
             name:(NSString *)name
             type:(NSString *)typeStr
           source:(HGSSearchSource *)source
       attributes:(NSDictionary *)attributes {

  if (!uri || !name || !typeStr) {
    HGSLogDebug(@"Must have an uri, name and typestr for %@ of %@ (%@)",
                name, source, uri);
    [self release];
    return nil;
  }

  Class concreteClass = nil;
  if (HGSTypeConformsToType(typeStr, kHGSTypeContact)
      && ![self isKindOfClass:[HGSUnscoredContactResult class]]) {
    concreteClass = [HGSUnscoredContactResult class];
  } else if (HGSTypeConformsToType(typeStr, kHGSTypeWebpage)
             && ![self isKindOfClass:[HGSUnscoredWebpageResult class]]) {
    concreteClass = [HGSUnscoredWebpageResult class];
  }
  if (concreteClass) {
    [self release];
    self = [[concreteClass alloc] initWithURI:uri
                                         name:name
                                         type:typeStr
                                       source:source
                                   attributes:attributes];
  } else {
    if ((self = [super init])) {
#if DEBUG
      // This is a debug runtime check to make sure our URIs are valid URLs.
      // We do allow "some" invalid URLS. search urls with %s in them for example.
      BOOL validURL =  [NSURL URLWithString:uri] != nil;
      validURL |= [uri rangeOfString:@"%s"].location == NSNotFound;
      validURL |= [uri hasPrefix:@"javascript:"];
      if (!validURL) {
        HGSLog(@"Bad URI - %@ from Source %@", uri, source);
      }
#endif
      NSMutableDictionary *abridgedAttrs
        = [NSMutableDictionary dictionaryWithDictionary:attributes];
      [abridgedAttrs removeObjectsForKeys:[NSArray arrayWithObjects:
                                           kHGSObjectAttributeURIKey,
                                           kHGSObjectAttributeNameKey,
                                           kHGSObjectAttributeTypeKey,
                                           nil]];
      if (![abridgedAttrs objectForKey:kHGSObjectAttributeLastUsedDateKey]) {
        [abridgedAttrs setObject:[NSDate distantPast]
                          forKey:kHGSObjectAttributeLastUsedDateKey];
      }
      uri_ = [uri retain];
      hash_ = [uri_ hash];
      displayName_ = [name retain];
      type_ = [typeStr retain];
      source_ = [source retain];

      // If we are supplied with an icon, apply it to both immediate
      // and non-immediate icon attributes.
      NSImage *image = [abridgedAttrs objectForKey:kHGSObjectAttributeIconKey];
      if (image) {
        if (![abridgedAttrs objectForKey:kHGSObjectAttributeImmediateIconKey]) {
          [abridgedAttrs setObject:image forKey:kHGSObjectAttributeImmediateIconKey];
        }
      } else {
        image = [abridgedAttrs objectForKey:kHGSObjectAttributeImmediateIconKey];
        if (image) {
          if (![abridgedAttrs objectForKey:kHGSObjectAttributeIconKey]) {
            [abridgedAttrs setObject:image forKey:kHGSObjectAttributeIconKey];
          }
        }
      }

      attributes_ = [abridgedAttrs retain];
    }
  }
  return self;
}

- (NSString*)description {
  return [NSString stringWithFormat:
          @"<%@:%p> [%@ - %@ (%@ from %@)]",
          [self class], self,
          [self displayName], [self type], [self class], [self source]];
}


+ (id)resultWithURL:(NSURL*)url
               name:(NSString *)name
               type:(NSString *)typeStr
             source:(HGSSearchSource *)source
         attributes:(NSDictionary *)attributes {
  return [[[self alloc] initWithURI:[url absoluteString]
                               name:name
                               type:typeStr
                             source:source
                         attributes:attributes] autorelease];
}

+ (id)resultWithURI:(NSString*)uri
               name:(NSString *)name
               type:(NSString *)typeStr
             source:(HGSSearchSource *)source
         attributes:(NSDictionary *)attributes {
  return [[[self alloc] initWithURI:uri
                               name:name
                               type:typeStr
                             source:source
                         attributes:attributes] autorelease];
}

+ (id)resultWithFilePath:(NSString *)path
                  source:(HGSSearchSource *)source
              attributes:(NSDictionary *)attributes {
  id result = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:path]) {
    NSString *type = HGSTypeForPath(path);
    if (!type) {
      type = kHGSTypeFile;
    }

	// Properly URL escape the components of the file path.
    NSEnumerator *components
      = [[path componentsSeparatedByString:@"/"] objectEnumerator];
    SEL selector = @selector(gtm_stringByEscapingForURLArgument);
    NSEnumerator *newComponents
      = [components gtm_enumeratorByMakingEachObjectPerformSelector:selector
                                                         withObject:nil];
    NSString *uriPath
      = [[newComponents allObjects] componentsJoinedByString:@"/"];
    NSString *uri
      = [NSString stringWithFormat:@"%@%@", kHGSResultFileSchemePrefix, uriPath];
    result = [self resultWithURI:uri
                            name:[fm displayNameAtPath:path]
                            type:type
                          source:source
                      attributes:attributes];
  }
  return result;
}

+ (id)resultWithDictionary:(NSDictionary *)dictionary
                    source:(HGSSearchSource *)source {
  return [[[self alloc] initWithDictionary:dictionary
                                    source:source] autorelease];
}

- (id)initWithDictionary:(NSDictionary*)attributes
                  source:(HGSSearchSource *)source {
  NSString *uri = [attributes objectForKey:kHGSObjectAttributeURIKey];
  if ([uri isKindOfClass:[NSURL class]]) {
    uri = [((NSURL*)uri) absoluteString];
  }
  if ([uri hasPrefix:kHGSResultFileSchemePrefix]) {
    NSString *path = [uri substringFromIndex:[kHGSResultFileSchemePrefix length]];
    path = [path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:path]) {
      [self release];
      return nil;
    }
  }
  NSString *name = [attributes objectForKey:kHGSObjectAttributeNameKey];
  NSString *type = [attributes objectForKey:kHGSObjectAttributeTypeKey];
  self = [self initWithURI:uri
                      name:name
                      type:type
                    source:source
                attributes:attributes];
  return self;
}

- (void)dealloc {
  [source_ release];
  [attributes_ release];
  [uri_ release];
  [displayName_ release];
  [type_ release];
  [super dealloc];
}


GTM_METHOD_CHECK(NSString, readableURLString);

#pragma mark HGSResult Overrides

- (NSString *)displayName {
  return displayName_;
}

- (NSString *)uri {
  return uri_;
}

- (NSString *)type {
  return type_;
}

-(HGSSearchSource *)source {
  return source_;
}

- (NSDictionary *)attributes {
  return attributes_;
}

- (id)resultByAddingAttributes:(NSDictionary *)attributes {
  NSMutableDictionary *newAttributes
    = [NSMutableDictionary dictionaryWithDictionary:attributes];
  [newAttributes addEntriesFromDictionary:[self attributes]];
  HGSUnscoredResult *newResult
    = [HGSUnscoredResult resultWithURI:[self uri]
                                  name:[self displayName]
                                  type:[self type]
                                source:[self source]
                            attributes:newAttributes];
  return newResult;
}

@end


@implementation HGSUnscoredWebpageResult

@synthesize normalizedIdentifier = normalizedIdentifier_;

- (id)initWithURI:(NSString *)uri
             name:(NSString *)name
             type:(NSString *)typeStr
           source:(HGSSearchSource *)source
       attributes:(NSDictionary *)attributes {
  if ((self = [super initWithURI:uri
                            name:name
                            type:typeStr
                          source:source
                      attributes:attributes])) {
    normalizedIdentifier_ = [[uri readableURLString] retain];
  }
  return self;
}

- (void)dealloc {
  [normalizedIdentifier_ release];
  [super dealloc];
}

- (BOOL)isDuplicate:(HGSResult*)compareTo {
  BOOL isDupe = NO;
  HGSUnscoredWebpageResult *webpageResult
    = GTM_DYNAMIC_CAST([HGSUnscoredWebpageResult class], compareTo);
  if (webpageResult) {
    // URL get special checks to enable matches to reduce duplicates, we remove
    // some things that tend to be "optional" to get a "normalized" url, and
    // compare those.
    NSString *myNormURLString = [self normalizedIdentifier];
    NSString *compareNormURLString = [webpageResult normalizedIdentifier];
    isDupe = [myNormURLString isEqualToString:compareNormURLString];
  }
  if (!isDupe) {
    isDupe = [super isDuplicate:compareTo];
  }
  return isDupe;
}

@end

@implementation HGSUnscoredContactResult

- (BOOL)isDuplicate:(HGSResult*)compareTo {
  BOOL isDupe = NO;
  HGSUnscoredContactResult *contactResult
    = GTM_DYNAMIC_CAST([HGSUnscoredContactResult class], compareTo);
  if (contactResult) {
    // Running through the identifers ourself is faster than creating two
    // NSSets and calling intersectsSet on them.
    NSArray *identifiers
      = [self valueForKey:kHGSObjectAttributeUniqueIdentifiersKey];
    NSArray *identifiers2
      = [contactResult valueForKey:kHGSObjectAttributeUniqueIdentifiersKey];

    for (id a in identifiers) {
      for (id b in identifiers2) {
        if ([a isEqual:b]) {
          isDupe = YES;
          break;
        }
      }
      if (isDupe) {
        break;
      }
    }
  }
  if (!isDupe) {
    isDupe = [super isDuplicate:compareTo];
  }
  return isDupe;
}


@end

@implementation HGSScoredResult
@synthesize score = score_;
@synthesize rankFlags = rankFlags_;
@synthesize matchedTerm = matchedTerm_;
@synthesize matchedIndexes = matchedIndexes_;

+ (id)resultWithResult:(HGSResult *)result
                 score:(CGFloat)score
            flagsToSet:(HGSRankFlags)setFlags
          flagsToClear:(HGSRankFlags)clearFlags
           matchedTerm:(HGSTokenizedString *)term
        matchedIndexes:(NSIndexSet *)indexes {
  return [[[[self class] alloc] initWithResult:result
                                         score:score
                                    flagsToSet:setFlags
                                  flagsToClear:clearFlags
                                   matchedTerm:term
                                matchedIndexes:indexes] autorelease];
}


+ (id)resultWithURI:(NSString *)uri
               name:(NSString *)name
               type:(NSString *)type
             source:(HGSSearchSource *)source
         attributes:(NSDictionary *)attributes
              score:(CGFloat)score
              flags:(HGSRankFlags)flags
        matchedTerm:(HGSTokenizedString *)term
     matchedIndexes:(NSIndexSet *)indexes {
  return [[[[self class] alloc] initWithURI:uri
                                       name:name
                                       type:type
                                     source:source
                                 attributes:attributes
                                       score:score
                                      flags:flags
                                matchedTerm:term
                             matchedIndexes:indexes] autorelease];
}

+ (id)resultWithFilePath:(NSString *)path
                  source:(HGSSearchSource *)source
              attributes:(NSDictionary *)attributes
                   score:(CGFloat)score
                   flags:(HGSRankFlags)flags
            matchedTerm:(HGSTokenizedString *)term
          matchedIndexes:(NSIndexSet *)indexes {
  HGSUnscoredResult *result = [HGSUnscoredResult resultWithFilePath:path
                                                             source:source
                                                         attributes:attributes];
  return [self resultWithResult:result
                          score:score
                     flagsToSet:flags
                   flagsToClear:~flags
                    matchedTerm:term
                 matchedIndexes:indexes];
}

- (id)initWithResult:(HGSResult *)result
               score:(CGFloat)score
          flagsToSet:(HGSRankFlags)setFlags
        flagsToClear:(HGSRankFlags)clearFlags
         matchedTerm:(HGSTokenizedString *)term
      matchedIndexes:(NSIndexSet *)indexes {
  if ((self = [super init])) {
    result_ = [result retain];
    hash_ = [result hash];
    score_ = score;
    rankFlags_ = [[result valueForKey:kHGSObjectAttributeRankFlagsKey] unsignedIntegerValue];
    rankFlags_ |= setFlags;
    rankFlags_ &= ~clearFlags;
    matchedTerm_ = [term retain];
    matchedIndexes_ = [indexes retain];

    HGSAssert(result_, @"Must have a result argument");
    if (!result_) {
      [self release];
      self = nil;
    }
  }
  return self;
}

- (id)initWithURI:(NSString *)uri
             name:(NSString *)name
             type:(NSString *)type
           source:(HGSSearchSource *)source
       attributes:(NSDictionary *)attributes
             score:(CGFloat)score
            flags:(HGSRankFlags)flags
     matchedTerm:(HGSTokenizedString *)term
   matchedIndexes:(NSIndexSet *)indexes {
  HGSUnscoredResult *result = [HGSUnscoredResult resultWithURI:uri
                                                          name:name
                                                          type:type
                                                        source:source
                                                    attributes:attributes];
  return [self initWithResult:result
                         score:score
                   flagsToSet:flags
                 flagsToClear:~flags
                  matchedTerm:term
               matchedIndexes:indexes];
}

- (CGFloat)score {
  // Change the score based on the source's promotion count.
  // We can't calculate this in initially because some sources could create
  // HGSScoredResults that they keep around, and they wouldn't be updated
  // dynamically.
  CGFloat score = score_;
  if (!([self rankFlags] & eHGSShortcutRankFlag)) {
    HGSSearchSource *source = [self source];
    HGSSearchSourceRanker *ranker = [HGSSearchSourceRanker sharedSearchSourceRanker];
    UInt64 promotionCount = [ranker promotionCount];
    UInt64 promotionForSource = [ranker promotionCountForSource:source];
    CGFloat promotionMultiplier
      = ((CGFloat)promotionForSource / (CGFloat)promotionCount);
    score = score + 1.0 * promotionMultiplier;
  }
  return score;
}

- (NSString*)description {
  NSString *desc = [super description];
  return [NSString stringWithFormat:@"%@ score: %0.5f", desc, [self score]];
}

- (void)dealloc {
  [matchedTerm_ release];
  [matchedIndexes_ release];
  [result_ release];
  [super dealloc];
}

#pragma mark HGSResult Overrides

- (NSString *)displayName {
  return [result_ displayName];
}


- (NSString *)uri {
  return [result_ uri];
}

- (NSString *)type {
  return [result_ type];
}

- (HGSSearchSource *)source {
  return [result_ source];
}


- (NSDictionary *)attributes {
  return [result_ attributes];
}

- (id)resultByAddingAttributes:(NSDictionary *)attributes {
  NSMutableDictionary *newAttributes
    = [NSMutableDictionary dictionaryWithDictionary:attributes];
  [newAttributes addEntriesFromDictionary:[self attributes]];
  HGSScoredResult *newResult = [HGSScoredResult resultWithURI:[self uri]
                                                         name:[self displayName]
                                                         type:[self type]
                                                       source:[self source]
                                                   attributes:newAttributes
                                                        score:[self score]
                                                        flags:[self rankFlags]
                                                  matchedTerm:[self matchedTerm]
                                               matchedIndexes:[self matchedIndexes]];
  return newResult;
}

@end

@implementation HGSResultArray

+ (id)arrayWithResult:(HGSResult *)result {
  id resultsArray = nil;
  if (result) {
    NSArray *array = [NSArray arrayWithObject:result];
    resultsArray = [self arrayWithResults:array];
  }
  return resultsArray;
}

+ (id)arrayWithResults:(NSArray *)results {
  return [[[self alloc] initWithResults:results] autorelease];
}

+ (id)arrayWithFilePaths:(NSArray *)filePaths {
  return [[[self alloc] initWithFilePaths:filePaths] autorelease];
}

- (id)initWithResults:(NSArray *)results {
  if ((self = [super init])) {
    results_ = [results copy];
  }
  return self;
}

- (id)initWithFilePaths:(NSArray *)filePaths {
  NSMutableArray *results
    = [NSMutableArray arrayWithCapacity:[filePaths count]];
  for (NSString *path in filePaths) {
    HGSUnscoredResult *result = [HGSUnscoredResult resultWithFilePath:path
                                                               source:nil
                                                           attributes:nil];
    HGSAssert(result, @"Unable to create result from %@", path);
    if (result) {
      [results addObject:result];
    }
  }
  return [self initWithResults:results];
}


- (void)dealloc {
  [results_ release];
  [super dealloc];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id *)stackbuf
                                    count:(NSUInteger)len {
  return [results_ countByEnumeratingWithState:state
                                       objects:stackbuf
                                         count:len];
}

- (NSString*)displayName {
  NSString *displayName = nil;
  if ([results_ count] == 1) {
    HGSScoredResult *result = [results_ objectAtIndex:0];
    displayName = [result displayName];
  } else {
    // TODO(alcor): make this nicer
    displayName = HGSLocalizedString(@"Multiple Items",
                                     @"A label denoting that this result "
                                     @"represents multiple items");
  }
  return displayName;
}

- (BOOL)isOfType:(NSString *)typeStr {
  BOOL isOfType = YES;
  for (HGSScoredResult *result in self) {
    isOfType = [result isOfType:typeStr];
    if (!isOfType) break;
  }
  return isOfType;
}

- (BOOL)conformsToType:(NSString *)typeStr {
  BOOL isOfType = YES;
  for (HGSScoredResult *result in self) {
    isOfType = [result conformsToType:typeStr];
    if (!isOfType) break;
  }
  return isOfType;
}

- (void)promote {
  [results_ makeObjectsPerformSelector:@selector(promote)];
}

- (NSArray *)urls {
  return [results_ valueForKey:@"url"];
}

- (NSArray *)filePaths {
  NSMutableArray *paths = [NSMutableArray arrayWithCapacity:[results_ count]];
  for (HGSScoredResult *result in self) {
    NSURL *url = [result url];
    if ([url isFileURL]) {
      [paths addObject:[url path]];
    } else {
      paths = nil;
      break;
    }
  }
  return paths;
}

- (NSUInteger)count {
  return [results_ count];
}

- (id)objectAtIndex:(NSUInteger)ind {
  return [results_ objectAtIndex:ind];
}

- (id)lastObject {
  return [results_ lastObject];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ results:\r%@", [self class], results_];
}

- (NSImage*)icon {
  NSImage *displayImage = nil;
  if ([results_ count] == 1) {
    HGSScoredResult *result = [results_ objectAtIndex:0];
    displayImage = [result valueForKey:kHGSObjectAttributeIconKey];
  } else {
    HGSIconCache *cache = [HGSIconCache sharedIconCache];
    displayImage = [cache compoundPlaceHolderIcon];
  }
  return displayImage;
}

@end
