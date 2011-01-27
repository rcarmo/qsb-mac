//
//  Shortcuts.m
//
//  Copyright (c) 2007-2009 Google Inc. All rights reserved.
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

// Shortcuts stores things in our user defaults.
// The top level is a dictionary keyed by "shortcut" where a shortcut is the
// series of characters entered by the user for them to get a object (i.e.
// 'ipho' could correspond to iPhoto. The value associated with the key is
// an array of object identifiers. These identifiers match an entry in
// a sqlite cache that holds the data needed to rebuild the object.
// When a user associates a object (ex 'ipho') with a object (ex 'iphoto')
// and there is nothing else keyed to 'ipho' in the DB, the array for 'ipho'
// will have a single entry 'iphoto'. If the user then associates 'iphone' with
// 'ipho' the array for 'ipho' will have two objects (iphoto and iphone). If
// the user again associates ipho with iPhone then the array will change to
// (iPhone, iPhoto). If the user then associates ipho with iphonizer the array
// will change to (iphone, iponizer). Object for shortcut will always return the
// first element in the array for a given key.

#import <Vermilion/Vermilion.h>

#if TARGET_OS_IPHONE
#import "GMOSourceConfigProvider.h"
#else  // TARGET_OS_IPHONE
#import "QSBTableResult.h"
#import "QSBActionPresenter.h"
#import "Shortcuts.h"
#endif  // TARGET_OS_IPHONE

#import <GTM/GTMMethodCheck.h>
#import <GTM/GTMExceptionalInlines.h>
#import <GTM/GTMTypeCasting.h>

static NSString *const kHGSShortcutsDictionaryKey
  = @"kHGSShortcutsDictionaryKey";
static NSString *const kHGSShortcutsVersionStringKey
  = @"kHGSShortcutsVersionStringKey";
static NSString *const kHGSShortcutsSourceIdentifierKey
  = @"kHGSShortcutsSourceIdentifierKey";

// The current version of the shortcuts DB. If you change how things are stored
// in the shortcuts DB, you will have to change this.
static NSString* const kHGSShortcutsVersion = @"0.93";

// Maximum number of entries per shortcut.
static const unsigned int kMaxEntriesPerShortcut = 3;

@interface ShortcutsSource : HGSCallbackSearchSource {
@private
  // Shortcuts Data is keyed by shortcut (what the user typed) and
  // each object is an NSMutableArray with up to kMaxEntriesPerShortcut.
  // Each object in the array is an NSDictionary representing a single
  // HGSResult.
  NSMutableDictionary *shortcuts_;
  NSString *shortcutsFilePath_;
  BOOL dirty_;
  NSTimer *writeShortcutsTimer_;
}

// Tell the database that "object" was selected for shortcut, and let it do its
// magic internally to update itself.
- (BOOL)updateShortcutForTokenizedString:(HGSTokenizedString *)shortcut
                        withRankedResult:(HGSScoredResult *)result;

- (NSArray *)rankedObjectsForShortcut:(HGSTokenizedString *)shortcut;

// Remove the given identifier for the shortcut.
- (void)removeIdentifier:(NSString *)identifier
             forShortcut:(HGSTokenizedString *)shortcut;
- (void)writeShortcuts:(NSTimer *)timer;
- (NSDictionary *)readShortcuts:(NSString *)path;

// Notifications
- (void)qsbActionPresenterWillPivot:(NSNotification *)notification;
- (void)qsbActionPresenterWillPerformAction:(NSNotification *)notification;
- (void)updateShortcut:(NSNotification *)notification;

@end

static inline NSInteger KeyLength(NSString *a, NSString *b, void *c) {
  NSUInteger lengthA = [a length];
  NSUInteger lengthB = [b length];
  if (lengthA < lengthB) {
    return NSOrderedAscending;
  } else if (lengthA > lengthB) {
    return NSOrderedDescending;
  }
  return NSOrderedSame;
}

@implementation ShortcutsSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
#if TARGET_OS_IPHONE
    GMOSourceConfigProvider *provider = [GMOSourceConfigProvider defaultConfig];
    shortcutsFilePath_ = [[provider shortcutsCacheDbPath] copy]
#else
    id<HGSDelegate> delegate = [[HGSPluginLoader sharedPluginLoader] delegate];
    NSString *appSupportPath = [delegate userApplicationSupportFolderForApp];
    shortcutsFilePath_
      = [[appSupportPath stringByAppendingPathComponent:@"shortcuts.db"] retain];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(qsbActionPresenterWillPivot:)
               name:kQSBActionPresenterWillPivotNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(qsbActionPresenterWillPerformAction:)
               name:kQSBActionPresenterWillPerformActionNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(updateShortcut:)
               name:kShortcutsUpdateShortcutNotification
             object:nil];
#endif
    shortcuts_ = [[self readShortcuts:shortcutsFilePath_] retain];
    writeShortcutsTimer_
      = [[NSTimer scheduledTimerWithTimeInterval:300
                                          target:self
                                        selector:@selector(writeShortcuts:)
                                        userInfo:nil
                                         repeats:YES] retain];

  }
  return self;
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [writeShortcutsTimer_ release];
  [nc removeObserver:self];
  [shortcuts_ release];
  [shortcutsFilePath_ release];
  [super dealloc];
}

- (NSUInteger)indexOfResultWithIdentifier:(NSString *)identifier
                                fromArray:(NSArray *)array {
  NSUInteger idx = NSNotFound;
  NSUInteger count = [array count];
  for (NSUInteger i = 0; i < count; ++i) {
    NSDictionary *dict = [array objectAtIndex:i];
    if ([[dict objectForKey:kHGSObjectAttributeURIKey] isEqualTo:identifier]) {
      idx = i;
      break;
    }
  }
  return idx;
}

- (id)defaultObjectForKey:(NSString *)key {
  id defaultObject = nil;
  if ([key isEqualToString:kHGSExtensionUserVisibleNameKey]) {
    defaultObject = HGSLocalizedString(@"Shortcuts",
                                       @"A result label denoting a user "
                                       @"defined shortcut string for a result");
  }
  if (!defaultObject) {
    defaultObject = [super defaultObjectForKey:key];
  }
  return defaultObject;
}

- (HGSResult *)unarchiveResult:(NSDictionary *)resultEntry {
  HGSResult *result = nil;
  NSString *sourceIdentifier
    = [resultEntry objectForKey:kHGSShortcutsSourceIdentifierKey];
  if (sourceIdentifier) {
    HGSExtensionPoint *sourcesPoint = [HGSExtensionPoint sourcesPoint];
    HGSSearchSource *source
      = [sourcesPoint extensionWithIdentifier:sourceIdentifier];
    result = [source resultWithArchivedRepresentation:resultEntry];
  }
  return result;
}

- (NSDictionary *)archiveResult:(HGSScoredResult *)result {
  NSMutableDictionary *archive = nil;
  HGSSearchSource *source = [result source];
  if (source) {
    archive = [source archiveRepresentationForResult:result];
    if (archive) {
      NSString *identifier = [source identifier];
      [archive setObject:identifier forKey:kHGSShortcutsSourceIdentifierKey];
    }
  }
  return archive;
}

- (BOOL)updateShortcutForTokenizedString:(HGSTokenizedString *)shortcut
                        withRankedResult:(HGSScoredResult *)result {
  // Check to see if the args we got are reasonable
  if (!shortcut || !result) {
    HGSLogDebug(@"Bad Args");
    return NO;
  }

  if (![shortcut tokenizedLength]) {
    return NO;
  }

  NSString *identifier = [result uri];
  if (!identifier) {
    HGSLogDebug(@"HGSResult had no identifier (%@)", result);
    return NO;
  }

  NSDictionary *archiveDict = [self archiveResult:result];
  if (!archiveDict) {
    return NO;
  }

  @synchronized (shortcuts_) {
    NSMutableArray *valueArray = [shortcuts_ objectForKey:shortcut];
     // see if we have an array for the given shortcut
    NSUInteger currentIndex = [self indexOfResultWithIdentifier:identifier
                                                      fromArray:valueArray];

    // The only way to be inserted at 0 is if you are in 2nd place,
    // otherwise insert at 1
    NSUInteger newIndex = (currentIndex <= 1) ? 0 : 1;

    // Only perform the insertion/update if the current index changed
    // or if the array doesn't exist yet.
    if (!valueArray || newIndex != currentIndex) {
      if (!valueArray) {
        valueArray = [NSMutableArray arrayWithObject:archiveDict];
        [shortcuts_ setObject:valueArray forKey:shortcut];
      } else {
        if (currentIndex < [valueArray count]) {
          [valueArray removeObjectAtIndex:currentIndex];
        }
        if (newIndex < [valueArray count]) {
          [valueArray insertObject:archiveDict atIndex:newIndex];
        } else {
          [valueArray addObject:archiveDict];
        }
      }

      // Clamp the number of shortcuts to kMaxEntriesPerShortcut.
      if ([valueArray count] > kMaxEntriesPerShortcut) {
        NSRange toRemove
          = GTMNSMakeRange(kMaxEntriesPerShortcut,
                           [valueArray count] - kMaxEntriesPerShortcut);
        [valueArray removeObjectsInRange:toRemove];
      }
      dirty_ = YES;
      HGSLogDebug(@"Shortcut recorded: %@ = %@", shortcut, result);
    }

  }
  return YES;
}

- (void)removeIdentifier:(NSString *)identifier
             forShortcut:(HGSTokenizedString *)shortcut {
  NSString *tokenizedShortcut = [shortcut tokenizedString];
  @synchronized (shortcuts_) {
    NSMutableArray *shortcutArray = [shortcuts_ objectForKey:tokenizedShortcut];
    NSUInteger idx = [self indexOfResultWithIdentifier:identifier
                                             fromArray:shortcutArray];
    if (idx != NSNotFound) {
        [shortcutArray removeObjectAtIndex:idx];
        dirty_ = YES;
    }
  }
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSQuery *query = [operation query];
  HGSTokenizedString *tokenizedString = [query tokenizedQueryString];
  NSArray *rankedResults = [self rankedObjectsForShortcut:tokenizedString];
  [operation setRankedResults:rankedResults];
}

- (NSArray *)rankedObjectsForShortcut:(HGSTokenizedString *)shortcut {
  NSMutableArray *results = [NSMutableArray array];
  @synchronized(shortcuts_) {
    for (HGSTokenizedString *key in [shortcuts_ allKeys]) {
      NSIndexSet *matchedIndexes = nil;
      CGFloat score = HGSScoreTermForItem(shortcut, key, &matchedIndexes);
      if (score > 0.0) {
        NSArray *resultArray = [shortcuts_ objectForKey:key];
        CGFloat base = 1.0;
        for (NSDictionary *resultDict in resultArray) {
          HGSResult *result = [self unarchiveResult:resultDict];

          // If we have an action, check to see if it can be displayed right
          // now.
          if ([result conformsToType:kHGSTypeAction]) {
            HGSAction *action
              = [result valueForKey:kHGSObjectAttributeDefaultActionKey];
            if (![action showInGlobalSearchResults]) {
              // Can't be shown right now, so nil out result.
              result = nil;
            }
          }

          HGSScoredResult *scoredResult = nil;
          if (result) {
            score = score * base;
            scoredResult = [HGSScoredResult resultWithResult:result
                                                       score:score
                                                  flagsToSet:eHGSShortcutRankFlag
                                                flagsToClear:0
                                                 matchedTerm:shortcut
                                              matchedIndexes:matchedIndexes];
            base -= .01;
          }
          if (scoredResult) {
            // We are not interested in stale results, but we also do not
            // want to remove them from our shortcuts.
            NSString *status
              = [result valueForKey:kHGSObjectAttributeStatusKey];
            if (![status isEqualToString:kHGSObjectStatusStaleValue]
                && [results indexOfObject:scoredResult] == NSNotFound) {
              [results addObject:scoredResult];
            }
          } else {
            NSString *identifier
              = [resultDict objectForKey:kHGSObjectAttributeURIKey];
            if (identifier) {
              [self removeIdentifier:identifier forShortcut:shortcut];
            }
          }
        }
      }
    }
  }
  return results;
}

#if TARGET_OS_IPHONE
- (void)resetHistoryAndCache {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObjectForKey:kHGSShortcutsVersionKey];
  [defaults removeObjectForKey:kHGSShortcutsKey];
  [defaults synchronize];

  [shortcuts_ removeAllObjects];
}

#else

// Store off the shortcut on a pivot.
- (void)qsbActionPresenterWillPivot:(NSNotification *)notification {
  QSBActionPresenter *presenter = [notification object];
  if (![presenter canUnpivot]) {
    QSBSearchController *controller = [presenter activeSearchController];
    QSBSourceTableResult *tableResult
      = (QSBSourceTableResult*)[presenter selectedTableResult];
    if ([tableResult respondsToSelector:@selector(representedResult)]) {
      HGSScoredResult *result = [tableResult representedResult];
      HGSAssert([result isKindOfClass:[HGSScoredResult class]], nil);
      [self updateShortcutForTokenizedString:[controller tokenizedQueryString]
                                              withRankedResult:result];
    }
  }
}

// Store off the shortcut when an action is performed on it.
- (void)qsbActionPresenterWillPerformAction:(NSNotification *)notification {
  QSBActionPresenter *presenter = [notification object];
  QSBSearchController *searchController = [presenter activeSearchController];
  HGSActionOperation *operation = [presenter actionOperation];

  HGSResultArray *directObjects
    = [operation argumentForKey:kHGSActionDirectObjectsKey];
  NSUInteger count = [directObjects count];
  HGSScoredResult *result = nil;
  if (count == 0) {
    // If we have no direct objects, we are likely an action.
    QSBSourceTableResult *tableResult
      = (QSBSourceTableResult*)[presenter selectedTableResult];
    if ([tableResult respondsToSelector:@selector(representedResult)]) {
      result = [tableResult representedResult];
    }
  } else if (count == 1) {
    result = [directObjects objectAtIndex:0];
  }
  if (result) {
    HGSTokenizedString *shortcut = [searchController tokenizedQueryString];
    if ([shortcut originalLength] > 0) {
      [self updateShortcutForTokenizedString:[searchController tokenizedQueryString]
                            withRankedResult:result];
    }
  }
}

- (void)updateShortcut:(NSNotification *)notification {
  NSDictionary *userInfo = [notification userInfo];
  NSString *string
    = GTM_STATIC_CAST(NSString, [userInfo objectForKey:kShortcutsShortcutKey]);
  HGSScoredResult *result
    = GTM_STATIC_CAST(HGSScoredResult,
                      [userInfo objectForKey:kShortcutsResultKey]);
  if (!string) {
    HGSLog(@"Bad String at updateShortcut:");
  }
  if (!result) {
    HGSLog(@"Bad Result at updateShortcut:");
  }
  HGSTokenizedString *tokenizedString = [HGSTokenizer tokenizeString:string];
  [self updateShortcutForTokenizedString:tokenizedString
                        withRankedResult:result];
}

// When the plugin is being uninstalled, write out shortcuts, and invalidate
// the timer which is retaining us.
- (void)uninstall {
  [writeShortcutsTimer_ invalidate];
  [self writeShortcuts:nil];
  [super uninstall];
}

- (NSDictionary *)readShortcuts:(NSString *)path {
  NSMutableDictionary *fileContents
    = [NSMutableDictionary dictionaryWithContentsOfFile:shortcutsFilePath_];
  NSString *vers = [fileContents objectForKey:kHGSShortcutsVersionStringKey];
  NSDictionary *storedData = [fileContents objectForKey:kHGSShortcutsDictionaryKey];
  NSMutableDictionary *shortcuts = [NSMutableDictionary dictionary];
  if ([vers isEqualToString:kHGSShortcutsVersion] && storedData) {
    for (NSString *identifier in storedData) {
      HGSTokenizedString *tokenizedID = [HGSTokenizer tokenizeString:identifier];
      NSArray *values = [storedData objectForKey:identifier];
      [shortcuts setObject:values forKey:tokenizedID];
    }
  }
  return shortcuts;
}

- (void)writeShortcuts:(NSTimer *)timer {
  NSMutableDictionary *shortCutData = nil;
  @synchronized(shortcuts_) {
    if (dirty_) {
      shortCutData = [NSMutableDictionary dictionary];
      for (HGSTokenizedString *tokenizedString in shortcuts_) {
        NSString *string = [tokenizedString tokenizedString];
        NSArray *valueArray = [shortcuts_ objectForKey:tokenizedString];
        [shortCutData setObject:valueArray forKey:string];
      }
    }
    if (shortCutData) {
      NSDictionary *fileData = [NSDictionary dictionaryWithObjectsAndKeys:
        shortCutData, kHGSShortcutsDictionaryKey,
        kHGSShortcutsVersion, kHGSShortcutsVersionStringKey,
        nil];
      if (![fileData writeToFile:shortcutsFilePath_ atomically:YES]) {
        HGSLog(@"Unable to write shortcuts to %@", shortcutsFilePath_);
      } else {
        dirty_ = NO;
      }
    }
  }
}
#endif

@end
