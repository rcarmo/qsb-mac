//
//  HGSTypeFilter.m
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

#import "HGSTypeFilter.h"
#import "HGSType.h"
#import "HGSLog.h"

NSString *HGSTypeForPath(NSString *path) {
  FSRef ref;
  Boolean isDir = FALSE;
  OSStatus err = FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],
                               &ref,
                               &isDir);
  if (err != noErr) return nil;
  CFStringRef cfUTType = NULL;
  err = LSCopyItemAttribute(&ref, kLSRolesAll,
                            kLSItemContentType, (CFTypeRef*)&cfUTType);
  if (err != noErr || !cfUTType) return nil;
  NSString *outType = HGSTypeForUTType(cfUTType);
  if (outType == kHGSTypeFile) {
    NSString *extension = [path pathExtension];
    if ([extension caseInsensitiveCompare:@"webloc"] == NSOrderedSame) {
      outType = kHGSTypeWebBookmark;
    }
  }
  CFRelease(cfUTType);
  return outType;
}

NSString *HGSTypeForUTType(CFStringRef utType) {
  // TODO(dmaclach): probably need some way for third parties to muscle their
  // way in here and improve this map for their types.
  NSString *outType = nil;
  // Order of the map below is important as it's most specific first.
  // We don't want things matching to directories when they are packaged docs.
  struct {
    CFStringRef uttype;
    NSString *hgstype;
  } typeMap[] = {
    { kUTTypeContact, kHGSTypeContact },
    { kUTTypeMessage, kHGSTypeEmail },
    { CFSTR("com.apple.safari.history"), kHGSTypeWebHistory },
    { kUTTypeHTML, kHGSTypeWebpage },
    { kUTTypeApplication, kHGSTypeFileApplication },
    { kUTTypeAudio, kHGSTypeFileMusic },
    { kUTTypeImage, kHGSTypeFileImage },
    { kUTTypeMovie, kHGSTypeFileMovie },
    { kUTTypePDF, kHGSTypeFilePDF },
    { kUTTypePlainText, kHGSTypeTextFile },
    { kUTTypePackage, kHGSTypeFile },
    { kUTTypeDirectory, kHGSTypeDirectory },
    { kUTTypeItem, kHGSTypeFile },
  };
  for (size_t i = 0; i < sizeof(typeMap) / sizeof(typeMap[0]); ++i) {
    if (UTTypeConformsTo(utType, typeMap[i].uttype)) {
      outType = typeMap[i].hgstype;
      break;
    }
  }
  return outType;
}
BOOL HGSTypeConformsToType(NSString *type1, NSString *type2) {
  // Must have the exact prefix
  HGSCheckDebug([type1 length], @"");
  BOOL result = [type2 isEqual:kHGSTypeAllTypes];
  if (!result) {
    NSUInteger type2Len = [type2 length];
    result = type2Len > 0 && [type1 hasPrefix:type2];
    if (result &&
        ([type1 length] > type2Len)) {
      // If it's not an exact match, it has to have a '.' after the base type (we
      // don't count "foobar" as of type "foo", only "foo.bar" matches).
      unichar nextChar = [type1 characterAtIndex:type2Len];
      result = (nextChar == '.');
    }
  }
  return result;
}

static BOOL HGSTypeConformsToTypeSet(NSString *type1, NSSet *types) {
  HGSCheckDebug([type1 length], @"");
  BOOL conforms = NO;
  for (NSString *type in types) {
    if (HGSTypeConformsToType(type1, type)) {
      conforms = YES;
      break;
    }
  }
  return conforms;
}

static BOOL HGSTypeDoesNotConformToTypeSet(NSString *type1, NSSet *types) {
  BOOL doesNotConform = YES;
  HGSCheckDebug([type1 length], @"");
  if ([types count] != 0) {
    for (NSString *type in types) {
      if (HGSTypeConformsToType(type1, type)) {
        doesNotConform = NO;
        break;
      }
    }
  }
  return doesNotConform;
}

@implementation HGSTypeFilter

static NSSet *sHGSTypeFilterAllTypesSet = nil;
static HGSTypeFilter *sHGSTypeFilterAllTypes = nil;

+ (void)initialize {
  if (!sHGSTypeFilterAllTypesSet) {
    NSString *allTypes = @"*";
    sHGSTypeFilterAllTypesSet = [[NSSet alloc] initWithObjects:&allTypes
                                                         count:1];
    sHGSTypeFilterAllTypes
      = [[self filterWithConformTypes:sHGSTypeFilterAllTypesSet
                  doesNotConformTypes:nil] retain];
  }
}

+ (NSSet *)allTypesSet {
  return sHGSTypeFilterAllTypesSet;
}

+ (id)filterAllowingAllTypes {
  return sHGSTypeFilterAllTypes;
}

+ (id)filterWithConformTypes:(NSSet *)conformTypes {
  return [[[self alloc] initWithConformTypes:conformTypes
                         doesNotConformTypes:nil] autorelease];
}

+ (id)filterWithDoesNotConformTypes:(NSSet *)doesNotConformTypes {
  return [[[self alloc] initWithConformTypes:[self allTypesSet]
                         doesNotConformTypes:doesNotConformTypes] autorelease];
}

+ (id)filterWithConformTypes:(NSSet *)conformTypes
         doesNotConformTypes:(NSSet *)doesNotConformTypes {
  return [[[self alloc] initWithConformTypes:conformTypes
                         doesNotConformTypes:doesNotConformTypes] autorelease];
}

- (id)initWithConformTypes:(NSSet *)conformTypes
       doesNotConformTypes:(NSSet *)doesNotConformTypes {
  HGSCheckDebug(conformTypes, @"");
  if ((self = [super init])) {
    conformTypes_ = [conformTypes copy];
    doesNotConformTypes_ = [doesNotConformTypes copy];
    // NSSets use their count as their hash. We want a better hash, so we
    // iterate through the immutable elements.
    for (NSString *type in conformTypes_) {
      hash_ += [type hash];
    }
    for (NSString *type in doesNotConformTypes_) {
      hash_ += [type hash];
    }
#if DEBUG
    // Debug runtime check to make sure our types are sane.
    if ([doesNotConformTypes_ count]) {
      HGSCheckDebug(![conformTypes_ intersectsSet:doesNotConformTypes_], @"");
      if (![conformTypes isEqual:[[self class] allTypesSet]]) {
        for (NSString *type in doesNotConformTypes) {
          HGSCheckDebug(HGSTypeConformsToTypeSet(type, conformTypes),
                        @"Type: %@ does not conform to conformTypes %@",
                        type, conformTypes);
        }
      }
    }
#endif  // DEBUG
    if (!conformTypes_) {
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [conformTypes_ release];
  [doesNotConformTypes_ release];
  [super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
  return [self retain];
}

- (BOOL)isValidType:(NSString *)type {
  HGSCheckDebug(type, @"");

  return HGSTypeConformsToTypeSet(type, conformTypes_)
    && HGSTypeDoesNotConformToTypeSet(type, doesNotConformTypes_);
}

- (NSUInteger)hash {
  return hash_;
}

- (NSSet *)conformTypes {
  return conformTypes_;
}

- (NSSet *)doesNotConformTypes {
  return doesNotConformTypes_;
}

- (BOOL)allowsAllTypes {
  return ([doesNotConformTypes_ count] == 0
          && [conformTypes_ isEqual:sHGSTypeFilterAllTypesSet]);
}

- (BOOL)intersectsWithFilter:(HGSTypeFilter *)filter {
  BOOL intersects = NO;
  for (NSString *type in [filter conformTypes]) {
    if ([self isValidType:type]) {
      intersects = YES;
      break;
    }
  }
  if (!intersects) {
    for (NSString *type in [self conformTypes]) {
      if ([filter isValidType:type]) {
        intersects = YES;
        break;
      }
    }
  }
  return intersects;
}

- (BOOL)isEqual:(id)object {
  BOOL good = NO;
  if ([object isKindOfClass:[self class]]) {
    if ([[self conformTypes] isEqual:[object conformTypes]]) {
      if ([[self doesNotConformTypes] isEqual:[object doesNotConformTypes]]) {
        good = YES;
      }
    }
  }
  return good;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%p - %@>\n\tConforms:%@\n\tDoesNotConform:%@",
          self, [self class], conformTypes_, doesNotConformTypes_];
}

@end
