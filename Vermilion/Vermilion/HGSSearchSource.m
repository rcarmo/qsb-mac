//
//  HGSSearchSource.mm
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

#import "HGSSearchSource.h"
#import "HGSResult.h"
#import "HGSQuery.h"
#import "HGSLog.h"
#import "HGSBundle.h"
#import "HGSIconProvider.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSTokenizer.h"
#import "HGSTypeFilter.h"
#import "HGSType.h"
#import "HGSActionArgument.h"

NSString *const kHGSSearchSourceUTIsToExcludeFromDiskSourcesKey
  = @"HGSSearchSourceUTIsToExcludeFromDiskSources";
NSString *const kHGSSearchSourceSupportedTypesKey
  = @"HGSSearchSourceSupportedTypes";
NSString *const kHGSSearchSourceUnsupportedTypesKey
  = @"HGSSearchSourceUnsupportedTypes";
NSString *const kHGSSearchSourcePivotableTypesKey
  = @"HGSSearchSourcePivotableTypes";
NSString *const kHGSSearchSourceCannotArchiveKey
= @"HGSSearchSourceCannotArchive";

@implementation HGSSearchSource
@synthesize pivotableTypes = pivotableTypes_;
@synthesize cannotArchive = cannotArchive_;
@synthesize resultTypeFilter = resultTypeFilter_;
@synthesize utisToExcludeFromDiskSources = utisToExcludeFromDiskSources_;

+ (void)initialize {
  if (self == [HGSSearchSource class]) {
#if DEBUG
    NSNumber *validateBehaviors = [NSNumber numberWithBool:YES];
#else
    NSNumber *validateBehaviors = [NSNumber numberWithBool:NO];
#endif
    NSDictionary *dict
      = [NSDictionary dictionaryWithObject:validateBehaviors
                                    forKey:kHGSValidateSearchSourceBehaviorsPrefKey];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:dict]; 
  }
}

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {

    id value = [configuration objectForKey:kHGSSearchSourcePivotableTypesKey];
    pivotableTypes_ = [[NSSet qsb_setFromId:value] retain];

    value
      = [configuration objectForKey:kHGSSearchSourceUTIsToExcludeFromDiskSourcesKey];
    utisToExcludeFromDiskSources_ = [[NSSet qsb_setFromId:value] retain];
    
    value = [configuration objectForKey:kHGSSearchSourceCannotArchiveKey];
    cannotArchive_ = [value boolValue];
    
    value = [configuration objectForKey:kHGSSearchSourceSupportedTypesKey];
    NSSet *supportedTypes = [NSSet qsb_setFromId:value];
    if (!supportedTypes) {
      HGSLogDebug(@"Source: %@ does not have a HGSSearchSourceSupportedTypes key", 
                  self);
      supportedTypes = [HGSTypeFilter allTypesSet];
    }
    value = [configuration objectForKey:kHGSSearchSourceUnsupportedTypesKey];
    NSSet *unsupportedTypes = [NSSet qsb_setFromId:value];
    resultTypeFilter_ 
      = [[HGSTypeFilter alloc] initWithConformTypes:supportedTypes
                                doesNotConformTypes:unsupportedTypes];
  }
  return self;
}

- (void)dealloc {
  [pivotableTypes_ release];
  [utisToExcludeFromDiskSources_ release];
  [resultTypeFilter_ release];
  [super dealloc];
}

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = NO;
  
  // If we have a current action argument we are trying to fulfill,
  // does the type desired by the action intersect with the types we can
  // return?
  HGSActionArgument *currentArg = [query actionArgument];
  HGSTypeFilter *typeFilter = [currentArg typeFilter];
  if (typeFilter) {
    isValid = [typeFilter intersectsWithFilter:[self resultTypeFilter]];
  } else {
    isValid = YES;
  }
  if (isValid) {
    HGSResultArray *pivotObjects = [query pivotObjects];
    NSSet *pivotTypes = [self pivotableTypes];
    if (pivotObjects && pivotTypes) {
      NSSet *allPivots = [NSSet setWithObject:@"*"];
      if (![pivotTypes isEqual:allPivots]) {
        for (HGSResult *pivotObject in pivotObjects) {
          BOOL goodObject = NO;
          for (NSString *pivotType in pivotTypes) {
            if ([pivotObject conformsToType:kHGSTypeAction]) {
              goodObject = YES;
            } else {
              goodObject = [pivotObject conformsToType:pivotType];
            }
            if (goodObject) {
              break;
            }
          }
          isValid = isValid & goodObject;
          if (!isValid) {
            break;
          }
        }
      }
    } else {
      for (HGSResult *pivotObject in pivotObjects) {
        if (![pivotObject conformsToType:kHGSTypeAction]) {
          isValid = NO;
          break;
        } 
      } 
      isValid &= [[[query tokenizedQueryString] tokenizedString] length] > 0;
    }
  }
  return isValid;
}

- (HGSSearchOperation *)searchOperationForQuery:(HGSQuery *)query {  
  // subclasses must provide a search op
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:kHGSValidateSearchSourceBehaviorsPrefKey]) {
    HGSLog(@"ERROR: Source %@ forgot to override searchOperationForQuery:.",
           [self class]);
  }
  [self doesNotRecognizeSelector:_cmd];
  return nil;  // COV_NF_LINE
}

- (id)provideValueForKey:(NSString *)key result:(HGSResult *)result {
  return nil;
}

- (NSMutableDictionary *)archiveRepresentationForResult:(HGSResult *)result {
  // Do we allow archiving?
  if (cannotArchive_) return nil;
  
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  NSSet *requiredKeys = [NSSet setWithObjects:
                         kHGSObjectAttributeNameKey,
                         kHGSObjectAttributeURIKey,
                         kHGSObjectAttributeTypeKey,
                         nil];
  NSArray *otherKeys = [NSArray arrayWithObjects:
                        kHGSObjectAttributeSnippetKey,
                        kHGSObjectAttributeSourceURLKey,
                        nil];
  
  NSMutableSet *defaultArchiveKeys = [NSMutableSet setWithSet:requiredKeys];
  [defaultArchiveKeys addObjectsFromArray:otherKeys];
  NSArray *sourceArchiveKeys = [self archiveKeys];
  if ([sourceArchiveKeys count]) {
    [defaultArchiveKeys addObjectsFromArray:sourceArchiveKeys];
  }
  for (NSString *archiveKey in defaultArchiveKeys) {
    id value = [result valueForKey:archiveKey];
    if (value) {
      if ([value isKindOfClass:[NSURL class]]) {
        value = [value absoluteString];
      }
      [dict setObject:value forKey:archiveKey];
    } else {
      if ([requiredKeys containsObject:archiveKey]) {
        HGSLogDebug(@"Attempting to archive %@. Missing required key %@",
                    result, archiveKey);
        dict = nil;
        break;
      }
    }
  }
  if (![NSPropertyListSerialization propertyList:dict 
                                isValidForFormat:NSPropertyListBinaryFormat_v1_0]) {
    HGSLog(@"Archive cannot be serialized: %@", dict);
    dict = nil;
  }
  return dict;
}

- (NSArray *)archiveKeys {
  return nil;
}

- (HGSResult *)resultWithArchivedRepresentation:(NSDictionary *)representation {
  // Do we allow archiving?
  HGSResult *result = nil;
  if (!cannotArchive_) {
    result = [[self resultClass] resultWithDictionary:representation source:self];
  }
  return result;
}

- (void)promoteResult:(HGSResult *)result {
  // Base implementation does nothing.
}

- (BOOL)providesIconsForResults {
  return NO;
}

- (Class)resultClass {
  return [HGSUnscoredResult class];
}

@end

@implementation HGSSimpleNamedSearchSource

+ (id)sourceWithName:(NSString *)displayName 
          identifier:(NSString *)identifier 
              bundle:(NSBundle *)bundle {
  return [[[self alloc] initWithName:displayName
                          identifier:identifier 
                              bundle:bundle] autorelease];
}

- (id)initWithName:(NSString *)displayName 
        identifier:(NSString *)identifier 
            bundle:(NSBundle *)bundle {
  HGSExtensionPoint *sp = [HGSExtensionPoint sourcesPoint];
  HGSExtension *ext = [sp extensionWithIdentifier:identifier];
  if (ext) {
    [self release];
    self = [ext retain];
  } else {
    if (displayName) {
      NSDictionary *config = 
        [NSDictionary dictionaryWithObjectsAndKeys:
         bundle, kHGSExtensionBundleKey,
         identifier, kHGSExtensionIdentifierKey,
         displayName, kHGSExtensionUserVisibleNameKey,
         [NSNumber numberWithBool:YES], @"HGSSearchSourceCannotArchive",
         nil];
    
      self = [super initWithConfiguration:config];
      if (self) {
        [sp extendWithObject:self];
      }
    } else {
      [self release];
      self = nil;
    }
  }
  return self;
}

@end
