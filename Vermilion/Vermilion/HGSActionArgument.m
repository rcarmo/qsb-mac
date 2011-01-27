//
//  HGSActionArgument.m
//
//  Copyright (c) 2010 Google Inc. All rights reserved.
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

#import "HGSActionArgument.h"
#import "HGSBundle.h"
#import "HGSCallbackSearchSource.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSExtension.h"
#import "HGSLog.h"
#import "HGSPluginLoader.h"
#import "HGSQuery.h"
#import "HGSResult.h"
#import "HGSType.h"
#import "HGSTypeFilter.h"

NSString* const kHGSActionArgumentBundleKey = @"HGSActionArgumentBundle";
NSString* const kHGSActionArgumentIdentifierKey = @"HGSActionArgumentIdentifier";
NSString* const kHGSActionArgumentSupportedTypesKey
  = @"HGSActionArgumentSupportedTypes";
NSString* const kHGSActionArgumentUnsupportedTypesKey
  = @"HGSActionArgumentUnsupportedTypes";
NSString* const kHGSActionArgumentOptionalKey = @"HGSActionArgumentOptional";
NSString* const kHGSActionArgumentUserVisibleOtherTermsKey
  = @"HGSActionArgumentUserVisibleOtherTerms";
NSString* const kHGSActionArgumentUserVisibleNameKey
  = @"HGSActionArgumentUserVisibleName";
NSString* const kHGSActionArgumentUserVisibleDescriptionKey
  = @"HGSActionArgumentUserVisibleDescription";
NSString* const kHGSActionArgumentClassKey = @"HGSActionArgumentClass";

static NSString* const kHGSActionArgumentSourceIdentifier
  = @"com.google.vermilion.actionargument.source";

// A simple source that returns custom values for action arguments if the
// action argument is configured to do so.
@interface HGSActionArgumentSource : HGSCallbackSearchSource
+ (void)pluginLoaderDidLoadPlugins:(NSNotification *)notification;
@end

@implementation HGSActionArgument

@synthesize optional = optional_;
@synthesize identifier = identifier_;
@synthesize displayName = displayName_;
@synthesize typeFilter = typeFilter_;
@synthesize displayDescription = displayDescription_;
@synthesize displayOtherTerms = displayOtherTerms_;

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super init])) {

    NSBundle *bundle = [configuration objectForKey:kHGSActionArgumentBundleKey];
    HGSCheckDebug(bundle, @"Action argument needs a bundle! %@", self);

    identifier_
      = [[configuration objectForKey:kHGSActionArgumentIdentifierKey] retain];
    HGSCheckDebug(identifier_, @"Action argument needs an identifier! %@", self);

    id value = [configuration objectForKey:kHGSActionArgumentSupportedTypesKey];
    NSSet *supportedTypes = [NSSet qsb_setFromId:value];

    value = [configuration objectForKey:kHGSActionArgumentUnsupportedTypesKey];
    NSSet *unsupportedTypes = [NSSet qsb_setFromId:value];

    typeFilter_ = [[HGSTypeFilter alloc] initWithConformTypes:supportedTypes
                                          doesNotConformTypes:unsupportedTypes];

    HGSCheckDebug(typeFilter_,
                  @"Action Argument %@ must have supported type", self);

    optional_
      = [[configuration objectForKey:kHGSActionArgumentOptionalKey] boolValue];

    displayName_
      = [configuration objectForKey:kHGSActionArgumentUserVisibleNameKey];
    displayName_
      = [[bundle qsb_localizedInfoPListStringForKey:displayName_] retain];
    HGSCheckDebug(!optional_ || displayName_,
                  @"Optional Action Argument %@ must have a display name", self);
    HGSCheckDebug(!displayName_ || [displayName_ characterAtIndex:0] != '^',
                  @"Display name not localized %@", self);
    displayDescription_
      = [configuration objectForKey:kHGSActionArgumentUserVisibleDescriptionKey];
    displayDescription_
      = [[bundle qsb_localizedInfoPListStringForKey:displayDescription_] retain];
    HGSCheckDebug((!displayDescription_
                   || [displayDescription_ characterAtIndex:0] != '^'),
                  @"Display name not localized %@", self);

    value = [configuration objectForKey:kHGSActionArgumentUserVisibleOtherTermsKey];
    NSSet *terms = [NSSet qsb_setFromId:value];
    if ([terms count]) {
      NSMutableSet *localizedTerms
        = [[NSMutableSet alloc] initWithCapacity:[terms count]];
      for (NSString *term in terms) {
        term = [bundle qsb_localizedInfoPListStringForKey:term];
        HGSCheckDebug(!term || [term characterAtIndex:0] != '^',
                    @"Other term %@ not localized for %@", term, self);
        [localizedTerms addObject:term];
      }
      displayOtherTerms_ = localizedTerms;
    }

    if (!bundle || !identifier_ || !typeFilter_ || (optional_ && !displayName_)) {
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [identifier_ release];
  [displayName_ release];
  [typeFilter_ release];
  [displayDescription_ release];
  [displayOtherTerms_ release];
  [super dealloc];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p identifier='%@' name='%@'>",
          [self class], self, [self identifier], [self displayName]];
}

- (HGSScoredResult *)scoreResult:(HGSScoredResult *)result
                        forQuery:(HGSQuery *)query {
  return result;
}

- (void)willScoreForQuery:(HGSQuery *)query {
}

- (void)didScoreForQuery:(HGSQuery *)query {
}

+ (HGSActionArgumentSource *)defaultActionArgumentSource {
  HGSExtensionPoint *sourcesPoint = [HGSExtensionPoint sourcesPoint];
  return [sourcesPoint
          extensionWithIdentifier:kHGSActionArgumentSourceIdentifier];
}

@end

@implementation HGSActionArgumentSource

// Hate to do this with load, but it's an effective way of getting us
// so that we can load with the rest of the extensions.
+ (void)load {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  if ([[self class] isEqual:[HGSActionArgumentSource class]]) {
    HGSPluginLoader *sharedLoader = [HGSPluginLoader sharedPluginLoader];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(pluginLoaderDidLoadPlugins:)
               name:kHGSPluginLoaderDidLoadPluginsNotification
             object:sharedLoader];
  }
  [pool release];
}

// We can now load ourself safely.
+ (void)pluginLoaderDidLoadPlugins:(NSNotification *)notification {
  HGSActionArgumentSource *source = [[[self alloc] init] autorelease];
  HGSAssert(source, nil);
  HGSExtensionPoint *sourcesPoint = [HGSExtensionPoint sourcesPoint];
  BOOL addedSource = [sourcesPoint extendWithObject:source];
  HGSAssert(addedSource, nil);
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self
                name:kHGSPluginLoaderDidLoadPluginsNotification
              object:[notification object]];
}

- (id)init {
  NSDictionary *configDictionary
    = [NSDictionary dictionaryWithObjectsAndKeys:
       HGSGetPluginBundle(), kHGSExtensionBundleKey,
       kHGSActionArgumentSourceIdentifier, kHGSExtensionIdentifierKey,
       @"Action Argument Source", kHGSExtensionUserVisibleNameKey,
       [NSNumber numberWithBool:NO], kHGSExtensionIsUserVisibleKey,
       [NSNumber numberWithBool:YES], kHGSSearchSourceCannotArchiveKey,
       [HGSTypeFilter allTypesSet], kHGSSearchSourceSupportedTypesKey,
       nil];
  self = [super initWithConfiguration:configDictionary];
  return self;
}

// Only valid if the pivot argument conforms to type action and the current
// action argument returns its own values.
- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = NO;
  HGSActionArgument *argument = [query actionArgument];
  if ([argument respondsToSelector:@selector(resultsForQuery:source:)]) {
    HGSResultArray *pivotObjects = [query pivotObjects];
    if ([pivotObjects count] == 1) {
      HGSResult *result = [pivotObjects objectAtIndex:0];
      if ([result conformsToType:kHGSTypeAction]) {
        isValid = YES;
      }
    }
  }
  return isValid;
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSQuery *query = [operation query];
  HGSActionArgument *argument = [query actionArgument];
  NSArray *results = [argument resultsForQuery:query source:self];
  [operation setRankedResults:results];
}

@end
