//
//  HGSObject.m
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

#import "HGSObject.h"
#import "HGSExtensionPoint.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSLog.h"
#import "HGSIconProvider.h"
#import "HGSSearchSource.h"
#import "NSString+ReadableURL.h"
#import "GTMMethodCheck.h"

// storage and initialization for value names
NSString* const kHGSObjectAttributeNameKey = @"kHGSObjectAttributeName";
NSString* const kHGSObjectAttributeURIKey = @"kHGSObjectAttributeURI";
NSString* const kHGSObjectAttributeUniqueIdentifiersKey = @"kHGSObjectAttributeUniqueIdentifiers";  // NSString
NSString* const kHGSObjectAttributeTypeKey = @"kHGSObjectAttributeType";
NSString* const kHGSObjectAttributeLastUsedDateKey = @"kHGSObjectAttributeLastUsedDate";
NSString* const kHGSObjectAttributeSnippetKey = @"kHGSObjectAttributeSnippet";
NSString* const kHGSObjectAttributeSourceURLKey = @"kHGSObjectAttributeSourceURL";
NSString* const kHGSObjectAttributeIconKey = @"kHGSObjectAttributeIcon";
NSString* const kHGSObjectAttributeImmediateIconKey = @"kHGSObjectAttributeImmediateIconKey";
NSString* const kHGSObjectAttributeIconPreviewFileKey = @"kHGSObjectAttributeIconPreviewFileKey";
NSString* const kHGSObjectAttributeIsSyntheticKey = @"kHGSObjectAttributeIsSynthetic";
NSString* const kHGSObjectAttributeIsCorrectionKey = @"kHGSObjectAttributeIsCorrection";
NSString* const kHGSObjectAttributeIsContainerKey = @"kHGSObjectAttributeIsContainer";
NSString* const kHGSObjectAttributeRankKey = @"kHGSObjectAttributeRank";  
NSString* const kHGSObjectAttributeDefaultActionKey = @"kHGSObjectAttributeDefaultActionKey";
// Path cell-related keys
NSString* const kHGSObjectAttributePathCellClickHandlerKey = @"kHGSObjectAttributePathCellClickHandler";
NSString* const kHGSObjectAttributePathCellsKey = @"kHGSObjectAttributePathCells";
NSString* const kHGSPathCellDisplayTitleKey = @"kHGSPathCellDisplayTitle";
NSString* const kHGSPathCellImageKey = @"kHGSPathCellImage";
NSString* const kHGSPathCellURLKey = @"kHGSPathCellURL";
NSString* const kHGSPathCellHiddenKey = @"kHGSPathCellHidden";

NSString* const kHGSObjectAttributeVisitedCountKey = @"kHGSObjectAttributeVisitedCount";

NSString* const kHGSObjectAttributeWebSearchDisplayStringKey = @"kHGSObjectAttributeWebSearchDisplayString";
NSString* const kHGSObjectAttributeWebSearchTemplateKey = @"kHGSObjectAttributeWebSearchTemplate";
NSString* const kHGSObjectAttributeAllowSiteSearchKey = @"kHGSObjectAttributeAllowSiteSearch";
NSString* const kHGSObjectAttributeWebSuggestTemplateKey = @"kHGSObjectAttributeWebSuggestTemplate";
NSString* const kHGSObjectAttributeStringValueKey = @"kHGSObjectAttributeStringValue";

NSString* const kHGSObjectAttributeRankFlagsKey = @"kHGSObjectAttributeRankFlags";

// Contact related keys
NSString* const kHGSObjectAttributeContactEmailKey = @"kHGSObjectAttributeContactEmail";  
NSString* const kHGSObjectAttributeEmailAddressesKey = @"kHGSObjectAttributeEmailAddressesKey";
NSString* const kHGSObjectAttributeContactsKey = @"kHGSObjectAttributeContactsKey";
NSString* const kHGSObjectAttributeAlternateActionURIKey = @"kHGSObjectAttributeAlternateActionURI";
NSString* const kHGSObjectAttributeAddressBookRecordIdentifierKey = @"kHGSObjectAttributeAddressBookRecordIdentifier";

// Chat Buddy-related keys
NSString* const kHGSObjectAttributeBuddyMatchingStringKey = @"kHGSObjectAttributeBuddyMatchingStringKey";
NSString* const kHGSIMBuddyInformationKey = @"kHGSIMBuddyInformationKey";

@interface HGSObject (HGSObjectPrivate)
- (NSDictionary *)values;
+ (NSString *)hgsTypeForPath:(NSString*)path;
@end

@implementation HGSObject

GTM_METHOD_CHECK(NSString, readableURLString);

+ (void)initialize {
  [self setKeys:[NSArray arrayWithObject:kHGSObjectAttributeIconKey]  
 triggerChangeNotificationsForDependentKey:kHGSObjectAttributeImmediateIconKey];
}

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
  return YES;  
}

+ (id)objectWithIdentifier:(NSURL*)uri
                      name:(NSString *)name
                      type:(NSString *)typeStr
                    source:(id<HGSSearchSource>)source 
                attributes:(NSDictionary *)attributes {
  return [[[self alloc] initWithIdentifier:uri
                                      name:name
                                      type:typeStr
                                    source:source
                                attributes:attributes] autorelease]; 
}

+ (id)objectWithFilePath:(NSString *)path 
                  source:(id<HGSSearchSource>)source 
              attributes:(NSDictionary *)attributes {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSURL *url = [NSURL fileURLWithPath:path];
  NSString *type = [self hgsTypeForPath:path];
  if (!type) {
    type = kHGSTypeFile;
  }
  
  return [self objectWithIdentifier:url
                               name:[fm displayNameAtPath:path]
                               type:type
                             source:source
                         attributes:attributes];
}

+ (id)objectWithDictionary:(NSDictionary *)dictionary 
                    source:(id<HGSSearchSource>)source {
  return [[[self alloc] initWithDictionary:dictionary 
                                    source:source] autorelease];
}

- (id)initWithIdentifier:(NSURL*)uri
                    name:(NSString *)name
                    type:(NSString *)typeStr
                  source:(id<HGSSearchSource>)source 
              attributes:(NSDictionary *)attributes {
  if ((self = [super init])) {
    if (!uri || !name || !typeStr) {
      HGSLogDebug(@"Must have an identifer, name and typestr for %@ of %@ (%@)", 
                  name, source, uri);
      [self release];
      return nil;
    }
    values_ = [[NSMutableDictionary alloc] initWithCapacity:4 ];

    identifier_ = [[uri absoluteString] retain];
    idHash_ = [identifier_ hash];
    name_ = [name retain];
    type_ = [typeStr retain];
    source_ = [source retain];
    conformsToContact_ = [self conformsToType:kHGSTypeContact];
    if ([self conformsToType:kHGSTypeWebpage]) {
      normalizedIdentifier_ = [[identifier_ readableURLString] retain];
    }
    if (attributes) {
      [values_ addEntriesFromDictionary:attributes];
    }
    NSNumber *rank = [values_ objectForKey:kHGSObjectAttributeRankKey];
    if (rank) {
      rank_ = [rank floatValue];
      [values_ removeObjectForKey:kHGSObjectAttributeRankKey];
    }
    NSNumber *rankFlags = [values_ objectForKey:kHGSObjectAttributeRankFlagsKey];
    if (rankFlags) {
      rankFlags_ = [rankFlags unsignedIntValue];
      [values_ removeObjectForKey:kHGSObjectAttributeRankFlagsKey];
    }
    lastUsedDate_ = [values_ objectForKey:kHGSObjectAttributeLastUsedDateKey];
    if (lastUsedDate_) {
      [values_ removeObjectForKey:kHGSObjectAttributeLastUsedDateKey];
    } else {
      lastUsedDate_ = [NSDate distantPast];
    }
    [lastUsedDate_ retain];
  }
  return self;
}

- (id)initWithDictionary:(NSDictionary*)dict 
                  source:(id<HGSSearchSource>)source {
  NSMutableDictionary *attributes = [[dict mutableCopy] autorelease];
  NSURL *url = [attributes objectForKey:kHGSObjectAttributeURIKey];
  if ([url isKindOfClass:[NSString class]]) {
    url = [NSURL URLWithString:(NSString*)url];
  }
  
  if ([url isFileURL]) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:[url path]]) {
      [self release];
      return nil;
    }  
  }
  
  NSString *name = [attributes objectForKey:kHGSObjectAttributeNameKey];
  NSString *type = [attributes objectForKey:kHGSObjectAttributeTypeKey];
  [attributes removeObjectsForKeys:[NSArray arrayWithObjects:
                                    kHGSObjectAttributeURIKey, 
                                    kHGSObjectAttributeNameKey, 
                                    kHGSObjectAttributeTypeKey,
                                    nil]];
  return [self initWithIdentifier:url 
                             name:name 
                             type:type 
                           source:source
                       attributes:attributes];
  return self;
}

- (void)dealloc {
  [[HGSIconProvider sharedIconProvider] cancelOperationsForResult:self];
  [source_ release];
  [values_ release];
  [identifier_ release];
  [normalizedIdentifier_ release];
  [name_ release];
  [type_ release];
  [lastUsedDate_ release];
  [super dealloc];
}

- (id)copyOfClass:(Class)cls {
  // Split the alloc and the init up to minimize time spent in
  // synchronized block.
  HGSObject *newObj = [cls alloc];
  @synchronized(values_) {
    newObj = [newObj initWithIdentifier:[self identifier]
                                   name:[self displayName]
                                   type:[self type]
                                 source:source_
                             attributes:values_];
  }
  // now pull over the fields
  newObj->rank_ = rank_;
  newObj->rankFlags_ = rankFlags_;
  return newObj;
}

- (id)copyWithZone:(NSZone *)zone {
  return [self copyOfClass:[HGSObject class]];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
  return [self copyOfClass:[HGSMutableObject class]];
}

- (NSUInteger)hash {
  return [[self identifier] hash];
}

- (BOOL)isEqual:(id)object {
  BOOL equal = NO;
  if ([object isKindOfClass:[HGSObject class]]) {
    HGSObject *hgsObject = (HGSObject*)object;
    equal = [object isOfType:[self type]]
      && [[hgsObject identifier] isEqual:[self identifier]];
  }
  return equal;
}

- (void)setValue:(id)obj forKey:(NSString*)key {
  if (key) { // This allows nil to remove value
    @synchronized(values_) {
      id oldValue = [values_ objectForKey:key];
      // TODO(dmaclach): handle this better, hopefully by getting rid of
      // setValue:forKey:
      HGSAssert(![key isEqualToString:kHGSObjectAttributeRankFlagsKey], nil);
      HGSAssert(![key isEqualToString:kHGSObjectAttributeURIKey], nil);
      HGSAssert(![key isEqualToString:kHGSObjectAttributeRankKey], nil);
      HGSAssert(![key isEqualToString:kHGSObjectAttributeNameKey], nil);
      HGSAssert(![key isEqualToString:kHGSObjectAttributeTypeKey], nil);
      if (oldValue != obj && ![oldValue isEqual:obj]) {
        [self willChangeValueForKey:key];
        if (!obj) {
          [values_ removeObjectForKey:key];
        } else {
          [values_ setObject:obj forKey:key];
        }
        [self didChangeValueForKey:key];
      }
    }
  }
}

- (id)valueForUndefinedKey:(NSString *)key {
  return nil;
}

// if the value isn't present, ask the result source to satisfy the
// request. Also registers for notifications so that we can update the
// value cache. 
- (id)valueForKey:(NSString*)key {
  id value = nil;
  if ([key isEqualToString:kHGSObjectAttributeURIKey]) {
    value = [self identifier];
  } else if ([key isEqualToString:kHGSObjectAttributeNameKey]) {
    value = [self displayName];
  } else if ([key isEqualToString:kHGSObjectAttributeTypeKey]) {
    value = [self type];
  }
  if (!value) {
    @synchronized (values_) {
      value = [values_ objectForKey:key];
      if (!value) {
        if ([key isEqualToString:kHGSObjectAttributeImmediateIconKey]) {
          value = [values_ objectForKey:kHGSObjectAttributeIconKey];
        }
      }
      if (!value) {
         // request from the source. This may kick off a pending load. 
        value = [[self source] provideValueForKey:key result:self];
        
        // request from the default source if none was provided
        // TODO(alcor): redo this to support type-based result handlers, right 
        // now we just load a class from string
        
        if (!value) {
          Class dataProviderClass = NSClassFromString(@"GDGeneralDataProvider");
          if (dataProviderClass) {
            value = [[[[dataProviderClass alloc] init] autorelease]
                     provideValueForKey:key result:self];
          }
        }
        if (value) {
          [self setValue:value forKey:key];
        }
      }
      if (!value) {
        value = [super valueForKey:key];
      }
    }
  }
  // Done for thread safety.
  return [[value retain] autorelease];
}

- (NSURL*)identifier {
  return [NSURL URLWithString:identifier_];
}

- (NSString*)stringValue {
  return [self displayName];
}

- (NSString*)displayName {
  return [[name_ retain] autorelease];
}
  
- (NSImage *)displayIconWithLazyLoad:(BOOL)lazyLoad {
  NSString *key = lazyLoad ? kHGSObjectAttributeIconKey 
                           : kHGSObjectAttributeImmediateIconKey;
  return [self valueForKey:key];
}

- (id)displayPath {
  // The path presentation shown in the search results window can be
  // built from one of the following (in order of preference):
  //   1. an array of cell descriptions
  //   2. a file path URL (from our |identifier|).
  //   3. a slash-delimeted string of cell titles
  // Only the first option guarantees that a cell is clickable, the
  // second option may but is not likely to support clicking, and the
  // third definitely not.  GDGeneralDataProvider will return a decent
  // cell array for regular URLs and file URLs and a mediocre one for
  // public.message results but you can compose and provide your own
  // in 1) your source's provideValueForKey: method or 2) an override
  // of displayPath in your custom HGSObect result class.
  return [self valueForKey:kHGSObjectAttributePathCellsKey];
}

- (NSString*)type {
  return type_;
}

- (BOOL)isOfType:(NSString *)typeStr {
  // Exact match
  BOOL result = [type_ isEqualToString:typeStr];
  return result;
}

static BOOL TypeConformsToType(NSString *type1, NSString *type2) {
  // Must have the exact prefix
  BOOL result = [type1 hasPrefix:type2];
  NSUInteger typeLen;
  if (result &&
      ([type1 length] > (typeLen = [type2 length]))) {
    // If it's not an exact match, it has to have a '.' after the base type (we
    // don't count "foobar" as of type "foo", only "foo.bar" matches).
    unichar nextChar = [type1 characterAtIndex:typeLen];
    result = (nextChar == '.');
  }
  return result;
}

- (BOOL)conformsToType:(NSString *)typeStr {
  NSString *myType = [self type];
  return TypeConformsToType(myType, typeStr);
}

- (BOOL)conformsToTypeSet:(NSSet *)typeSet {
  NSString *myType = [self type];
  for (NSString *aType in typeSet) {
    if (TypeConformsToType(myType, aType)) {
      return YES;
    }
  }
  return NO;
}

- (id<HGSSearchSource>)source {  
  return source_;
}

- (CGFloat)rank {
  return rank_;
}

- (HGSRankFlags)rankFlags {
  return rankFlags_;
}

- (NSString*)description {
  return [NSString stringWithFormat:@"[%@ - %@ (%@ from %@)]", 
          [self displayName], [self type], [self class], source_];
}

// merge the attributes of |result| into this one. Single values that overlap
// are lost, arrays and dictionaries are merged together to form the union.
// TODO(dmaclach): currently this description is a lie. Arrays and dictionaries
// aren't merged.
- (void)mergeWith:(HGSObject*)result {
  BOOL dumpQueryProgress = [[NSUserDefaults standardUserDefaults]
                            boolForKey:@"reportQueryOperationsProgress"];
  if (dumpQueryProgress) {
    HGSLogDebug(@"merging %@ into %@", [result description], [self description]);
  }
  NSDictionary *resultValues = [result values];
  @synchronized(values_) {
    for (NSString *key in [resultValues allKeys]) {
      if ([values_ objectForKey:key]) continue;
      [values_ setValue:[result valueForKey:key] forKey:key];
    }
  }
}

// this is result a "duplicate" of |compareTo|? The default implementation 
// checks |kHGSObjectAttributeURIKey| for equality, but subclasses may want
// something more sophisticated. Not using |-isEqual:| because that
// impacts how the object gets put into collections.
- (BOOL)isDuplicate:(HGSObject*)compareTo {
  // TODO: does [self class] come into play here?  can two different types ever
  // be equal at a base impl layer.
  BOOL intersects = NO;
  
  if (self->conformsToContact_ 
      && compareTo->conformsToContact_) {
    
    NSArray *identifiers = [self valueForKey:kHGSObjectAttributeUniqueIdentifiersKey];
    NSArray *identifiers2 = [compareTo valueForKey:kHGSObjectAttributeUniqueIdentifiersKey];
    
    for (id a in identifiers) {
      for (id b in identifiers2) {
        if ([a isEqual:b]) {
          intersects = YES;
          break;
        }
      }
      if (intersects) {
        break;
      }
    }
  } else {
    if (self->idHash_ == compareTo->idHash_) {
      intersects = [self->identifier_ isEqualToString:compareTo->identifier_];
    }
  }
  if (!intersects) {
    // URL get special checks to enable matches to reduce duplicates, we remove
    // some things that tend to be "optional" to get a "normalized" url, and
    // compare those.

    NSString *myNormURLString = self->normalizedIdentifier_;
    NSString *compareNormURLString = compareTo->normalizedIdentifier_;
    
    // if we got strings, compare
    if (myNormURLString && compareNormURLString) {
      intersects = [myNormURLString isEqualToString:compareNormURLString];
    }
  }
  return intersects;
}

- (NSDate *)lastUsedDate {
  return lastUsedDate_;
}
@end

@implementation HGSObject (HGSObjectPrivate)

- (NSDictionary *)values {
  NSDictionary *dict;
  @synchronized (values_) {
    // We make a copy and autorelease to keep safe across threads.
    dict = [values_ copy];
  }
  return [dict autorelease];
}

+ (NSString *)hgsTypeForPath:(NSString*)path {
  // TODO(dmaclach): probably need some way for third parties to muscle their
  // way in here and improve this map for their types.
  // TODO(dmaclach): combine this code with the SLFilesSource code so we
  // are only doing this in one place.
  FSRef ref;
  Boolean isDir = FALSE;
  OSStatus err = FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],
                               &ref, 
                               &isDir);
  if (err != noErr) return nil;
  CFStringRef cfUTType = NULL;
  err = LSCopyItemAttribute(&ref, kLSRolesAll, kLSItemContentType, (CFTypeRef*)&cfUTType);
  if (err != noErr || !cfUTType) return nil;
  NSString *outType = nil;
  // Order of the map below is important as it's most specific first.
  // We don't want things matching to directories when they are packaged docs.
  struct {
    CFStringRef uttype;
    NSString *hgstype;
  } typeMap[] = {
    { kUTTypeContact, kHGSTypeContact },
    { kUTTypeMessage, kHGSTypeEmail },
    { kUTTypeHTML, kHGSTypeWebpage },
    { kUTTypeApplication, kHGSTypeFileApplication },
    { kUTTypeAudio, kHGSTypeFileMusic },
    { kUTTypeImage, kHGSTypeFileImage },
    { kUTTypeMovie, kHGSTypeFileMovie },
    { kUTTypePlainText, kHGSTypeTextFile },
    { kUTTypeDirectory, kHGSTypeDirectory },
    { kUTTypeItem, kHGSTypeFile }
  };
  for (size_t i = 0; i < sizeof(typeMap) / sizeof(typeMap[0]); ++i) {
    if (UTTypeConformsTo(cfUTType, typeMap[i].uttype)) {
      outType = typeMap[i].hgstype;
      break;
    }
  }
  CFRelease(cfUTType);
  return outType;
}

@end

@implementation HGSMutableObject

- (void)setRankFlags:(HGSRankFlags)flags {
  rankFlags_ = flags;
}

- (void)addRankFlags:(HGSRankFlags)flags {
  rankFlags_ |= flags;
}

- (void)removeRankFlags:(HGSRankFlags)flags {
  rankFlags_ &= ~flags;
}

- (void)setRank:(CGFloat)rank {
  rank_ = rank;
}
@end

@implementation HGSObject (HGSFileConvenienceMethods)
- (NSArray *)filePaths {
  // TODO(alcor): Eventually these will need to return arrays, better to get
  // the actions in the habit of handling an array rather than a single item.
  NSURL *url = [self valueForKey:kHGSObjectAttributeURIKey];
  if (![url isFileURL]) return nil;
  NSString *path = [url path];
  return [NSArray arrayWithObject:path];
}

@end
