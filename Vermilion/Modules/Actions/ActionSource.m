//
//  ActionSource.m
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

#import <Vermilion/Vermilion.h>

//
// ActionSource
//
// Implements a SearchSource for finding actions in both the global and
// pivoted context

static NSString * const kActionIdentifierArchiveKey = @"ActionIdentifier";

@interface ActionSource : HGSMemorySearchSource {
 @private
  BOOL rebuildCache_;
}
- (void)extensionPointActionsChanged:(NSNotification*)notification;
- (void)pluginLoaderDidInstallPlugins:(NSNotification *)notification;
- (void)collectActions;
@end

@implementation ActionSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    HGSPluginLoader *pluginLoader = [HGSPluginLoader sharedPluginLoader];
    [nc addObserver:self
           selector:@selector(pluginLoaderDidInstallPlugins:)
               name:kHGSPluginLoaderDidInstallPluginsNotification
             object:pluginLoader];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

#pragma mark -

- (void)pluginLoaderDidInstallPlugins:(NSNotification *)notification {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  HGSExtensionPoint *actionsPoint = [HGSExtensionPoint actionsPoint];

  [nc addObserver:self
         selector:@selector(extensionPointActionsChanged:)
             name:kHGSExtensionPointDidAddExtensionNotification
           object:actionsPoint];
  [nc addObserver:self
         selector:@selector(extensionPointActionsChanged:)
             name:kHGSExtensionPointDidRemoveExtensionNotification
           object:actionsPoint];
  [nc removeObserver:self
                name:kHGSPluginLoaderDidInstallPluginsNotification
              object:[notification object]];
  [self collectActions];
}

- (void)extensionPointActionsChanged:(NSNotification*)notification {
  // Since the notifications can come in baches as we load things (and if/when
  // we support enable/disable they too could come in batches), we set a flag
  // and rebuild it next time it's needed.
  rebuildCache_ = YES;
}

- (HGSResult *)objectFromAction:(HGSAction *)action
                    resultArray:(HGSResultArray *)array {
  // Set some of the flags to bump them up in the result's ranks
  NSNumber *rankFlags
    = [NSNumber numberWithUnsignedInt:eHGSLaunchableRankFlag
       | eHGSSpecialUIRankFlag
       | eHGSUnderHomeRankFlag
       | eHGSHomeChildRankFlag];
  NSMutableDictionary *attributes
    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
       rankFlags, kHGSObjectAttributeRankFlagsKey,
       action, kHGSObjectAttributeDefaultActionKey,
       array, kHGSObjectAttributeActionDirectObjectsKey,
       nil];
  NSImage *icon = [action displayIconForResults:array];
  if (icon) {
    [attributes setObject:icon forKey:kHGSObjectAttributeIconKey];
  }
  NSString *name = [action displayNameForResults:nil];
  NSString *extensionIdentifier = [action identifier];
  NSString *urlStr = [NSString stringWithFormat:@"action:%@", extensionIdentifier];

  HGSUnscoredResult *actionObject
    = [HGSUnscoredResult resultWithURI:urlStr
                                  name:name
                                  type:kHGSTypeAction
                                source:self
                            attributes:attributes];

  return actionObject;
}

- (void)collectActions {
  rebuildCache_ = NO;
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];

  HGSExtensionPoint* actionPoint = [HGSExtensionPoint actionsPoint];
  for (HGSAction *action in [actionPoint extensions]) {
    // Create a result object that wraps our action
    HGSResult *actionObject = [self objectFromAction:action
                                         resultArray:nil];
    // Index our result
    [database indexResult:actionObject
                     name:[actionObject displayName]
               otherTerms:[[action otherTerms] allObjects]];
  }
  [self replaceCurrentDatabaseWith:database];
}

#pragma mark -

- (NSMutableDictionary *)archiveRepresentationForResult:(HGSResult *)result {
  // For action results, we pull out the action, and save off it's extension
  // identifier.
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  HGSAction *action = [result valueForKey:kHGSObjectAttributeDefaultActionKey];
  NSString *extensionIdentifier = [action identifier];
  if (extensionIdentifier) {
    [dict setObject:extensionIdentifier forKey:kActionIdentifierArchiveKey];
  }
  return dict;
}

- (HGSResult *)resultWithArchivedRepresentation:(NSDictionary *)representation {
  HGSResult *result = nil;
  NSString *extensionIdentifier
    = [representation objectForKey:kActionIdentifierArchiveKey];
  if (extensionIdentifier) {
    HGSExtensionPoint* actionPoint = [HGSExtensionPoint actionsPoint];
    HGSAction *action
      = [actionPoint extensionWithIdentifier:extensionIdentifier];
    if (action) {
      // We create a new result, but it should fold based out the url
      result = [self objectFromAction:action
                          resultArray:nil];
    }
  }

  return result;
}

#pragma mark -

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  // Recollect things on demand
  if (rebuildCache_) {
    [self collectActions];
  }
  [super performSearchOperation:operation];
}

- (HGSScoredResult *)postFilterScoredResult:(HGSScoredResult *)scoredResult
                            matchesForQuery:(HGSQuery *)query
                               pivotObjects:(HGSResultArray *)pivotObjects {
  HGSResultArray *queryPivotObjects = [query pivotObjects];
  HGSScoredResult *rankedActionResult = nil;
  if (queryPivotObjects) {
    // Pivot: filter to actions that support this object as the target of the
    // action.
    HGSAction *action
      = [scoredResult valueForKey:kHGSObjectAttributeDefaultActionKey];
    if ([action appliesToResults:queryPivotObjects]) {
      HGSResult *actionResult = [self objectFromAction:action
                                           resultArray:queryPivotObjects];
      CGFloat score = [scoredResult score];
      HGSTokenizedString *matchedTerm = [scoredResult matchedTerm];
      HGSRankFlags flagsToSet = 0;

      if ([matchedTerm tokenizedLength] == 0) {
        // This gives some ordering to actions, putting more specific actions
        // first.
        HGSCalibratedScoreType scoreType;
        HGSTypeFilter *directObjectTypeFilter = [action directObjectTypeFilter];
        HGSTypeFilter *allTypeFilter = [HGSTypeFilter filterAllowingAllTypes];
        if ([directObjectTypeFilter isEqual:allTypeFilter]) {
          scoreType = kHGSCalibratedWeakScore;
        } else {
          scoreType = kHGSCalibratedModerateScore;
        }
        score = HGSCalibratedScore(scoreType);
      }
      NSIndexSet *matchedIndexes = [scoredResult matchedIndexes];
      rankedActionResult = [HGSScoredResult resultWithResult:actionResult
                                                       score:score
                                                  flagsToSet:flagsToSet
                                                flagsToClear:0
                                                 matchedTerm:matchedTerm
                                              matchedIndexes:matchedIndexes];
    }
  } else {

    // No pivot: so just include the actions that are valid for a top level
    // query.
    HGSAction *action
      = [scoredResult valueForKey:kHGSObjectAttributeDefaultActionKey];
    if ([action showInGlobalSearchResults]) {
      rankedActionResult = scoredResult;
    }
  }

  return rankedActionResult;
}

@end

