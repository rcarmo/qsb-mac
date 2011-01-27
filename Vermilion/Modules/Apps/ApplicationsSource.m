//
//  ApplicationsSource.m
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

// Private LSInfo attribute. Returns a CFArray with valid architectures
// (i386, ppc, etc.).
extern const CFStringRef kLSItemArchitecturesValidOnCurrentSystem;

// Indexes Applications and Preference Panes. Allows pivoting on the
// System Preferences to find preference panes inside it.

@interface ApplicationsSource : HGSMemorySearchSource {
 @private
  NSMetadataQuery *query_;
}

- (void)startQuery;

// Do a fast index of the most likely app locations
// (/Applications and ~/Applications).
- (void)fastIndex;

- (void)queryNotification:(NSNotification *)notification;
@end

static NSString *const kApplicationSourcePredicateString
  = @"(kMDItemContentTypeTree == 'com.apple.application') "
    @"|| (kMDItemContentTypeTree == 'com.apple.systempreference.prefpane')";

@implementation ApplicationsSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    if (![self loadResultsCache]) {
      [self fastIndex];
    }
    [self performSelector:@selector(startQuery)
               withObject:nil
               afterDelay:10];
  }
  return self;
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [query_ release];
  [super dealloc];
}

- (void)startQuery {
  // kick off a spotlight query for applications. it'll be a standing
  // query that we keep around for the duration of this source.
  query_ = [[NSMetadataQuery alloc] init];
  NSPredicate *predicate
    = [NSPredicate predicateWithFormat:kApplicationSourcePredicateString];
  NSArray *scope = [NSArray arrayWithObject:NSMetadataQueryLocalComputerScope];
  [query_ setSearchScopes:scope];
  NSSortDescriptor *desc
    = [[[NSSortDescriptor alloc] initWithKey:(id)kMDItemLastUsedDate
                                   ascending:NO] autorelease];
  [query_ setSortDescriptors:[NSArray arrayWithObject:desc]];
  [query_ setPredicate:predicate];
  [query_ setNotificationBatchingInterval:10];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(queryNotification:)
             name:nil
           object:query_];

  [query_ startQuery];
}

- (BOOL)pathIsLaunchable:(NSString *)path {
  // Check to see if we can actually execute this file
  BOOL launchable = NO;
  NSURL *url = [NSURL fileURLWithPath:path];
  if (url) {
    FSRef fsRef;
    if (CFURLGetFSRef((CFURLRef)url, &fsRef)) {
      CFTypeRef archs;
      if (LSCopyItemAttribute(&fsRef,
                              kLSRolesAll,
                              kLSItemArchitecturesValidOnCurrentSystem,
                              &archs) == noErr) {
        if (archs) {
          launchable = CFArrayGetCount(archs) > 0;
          CFRelease(archs);
        }
      }
    }
  }
  return launchable;
}

- (BOOL)pathIsPrefPane:(NSString *)path {
  NSString *ext = [path pathExtension];
  return [ext caseInsensitiveCompare:@"prefPane"] == NSOrderedSame;
}

// Returns YES if the application is something a user would never realistically
// want to have show up as a match.
// TODO(stuartmorgan): make this more intelligent (e.g., suppressing pref
// panes and duplicate apps from the non-boot volume).
- (BOOL)pathShouldBeSuppressed:(NSString *)path {
  BOOL suppress = NO;
  if (!path) {
    suppress = YES;
  } else if ([self pathIsPrefPane:path]) {
    // Only match pref panes if they are installed.
    // TODO(stuartmorgan): This should actually be looking specifically in the
    // boot volume
    suppress = ([path rangeOfString:@"/PreferencePanes/"].location
                == NSNotFound);
  } else if ([path rangeOfString:@"/Library/"].location != NSNotFound) {
    // TODO(alcor): verify that these paths actually exist, or filter on bndleid
    NSArray *whitelist
      = [NSArray arrayWithObjects:
         @"/System/Library/CoreServices/Software Update.app",
         @"/System/Library/CoreServices/Finder.app",
         @"/System/Library/CoreServices/Archive Utility.app",
         @"/System/Library/CoreServices/Screen Sharing.app",
         @"/System/Library/CoreServices/Network Diagnostics.app",
         @"/System/Library/CoreServices/Network Setup Assistant.app",
         @"/System/Library/CoreServices/Installer.app",
         @"/System/Library/CoreServices/Kerberos.app",
         @"/System/Library/CoreServices/Dock.app",
         nil];
    if (![whitelist containsObject:path]) suppress = YES;
  } else if ([path rangeOfString:@"/Developer/Platforms/"].location != NSNotFound) {
    suppress = YES;
  }
  return suppress;
}

- (void)parseResultsOperation:(NSMetadataQuery *)query {
  NSArray *mdAttributeNames = [NSArray arrayWithObjects:
                               (NSString *)kMDItemDisplayName,
                               (NSString *)kMDItemPath,
                               (NSString *)kMDItemLastUsedDate,
                               (NSString *)kMDItemCFBundleIdentifier,
                               nil];
  NSUInteger resultCount = [query resultCount];
  NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSLaunchableRankFlag];
  NSMutableDictionary *regularAttributes
    = [NSMutableDictionary dictionaryWithObject:rankFlags
                                         forKey:kHGSObjectAttributeRankFlagsKey];
  rankFlags = [NSNumber numberWithUnsignedInt:(eHGSLaunchableRankFlag
                                               | eHGSBelowFoldRankFlag)];
  NSMutableDictionary *belowFoldAttributes
    = [NSMutableDictionary dictionaryWithObject:rankFlags
                                         forKey:kHGSObjectAttributeRankFlagsKey];
  NSString *prefPaneString = HGSLocalizedString(@"Preference Pane",
                                                @"A label denoting that this "
                                                @"result is a System "
                                                @"Preference Pane");
  NSFileManager *fileManager = [NSFileManager defaultManager];
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];
  for (NSUInteger i = 0; i < resultCount; ++i) {
    NSMetadataItem *result = [query resultAtIndex:i];
    NSDictionary *mdAttributes = [result valuesForAttributes:mdAttributeNames];
    NSString *path = [mdAttributes objectForKey:(NSString*)kMDItemPath];

    if ([self pathShouldBeSuppressed:path])
      continue;

    NSString *name = [mdAttributes objectForKey:(NSString*)kMDItemDisplayName];
    NSArray *components = [path pathComponents];

    NSString *fileSystemName = [components objectAtIndex:[components count] - 1];
    if (!name) {
      name = fileSystemName;
    }

    NSMutableDictionary *attributes = regularAttributes;

    // Check to see if this same path exists on our root drive without
    // "Volumes/DriveName" on the front. If so, we will push it beneath the
    // fold because it is probably a dual boot system.
    if ([components count] > 3
        && [[components objectAtIndex:1] isEqualToString:@"Volumes"]) {
      NSRange range = NSMakeRange(3, [components count] - 3);
      NSMutableArray *matchPathArray = [NSMutableArray arrayWithObject:@"/"];
      [matchPathArray addObjectsFromArray:[components subarrayWithRange:range]];
      NSString *matchPath = [NSString pathWithComponents:matchPathArray];
      NSDictionary *fileAttrs = [fileManager attributesOfItemAtPath:matchPath
                                                              error:nil];
      if (fileAttrs) {
        // We have the exact same file on our system drive. Most likely an
        // alternate drive, or backup drive.
        attributes = belowFoldAttributes;
      }
    }

    if (attributes != belowFoldAttributes) {
      if (![self pathIsLaunchable:path]) {
        attributes = belowFoldAttributes;
      }
    }

    if ([self pathIsPrefPane:path]) {
      // Some prefpanes forget to localize their names and end up with
      // foo.prefpane as their kMDItemTitle. foo.prefPane Preference Pane looks
      // ugly.
      if ([self pathIsPrefPane:name]) {
        name = [name stringByDeletingPathExtension];
      }
      name = [name stringByAppendingFormat:@" %@", prefPaneString];
    }

    if ([[path pathExtension] caseInsensitiveCompare:@"app"] == NSOrderedSame) {
      name = [name stringByDeletingPathExtension];
    }

    // set last used date
    NSDate *date = [mdAttributes objectForKey:(NSString*)kMDItemLastUsedDate];
    if (!date) {
      date = [NSDate distantPast];
    }

    [attributes setObject:date forKey:kHGSObjectAttributeLastUsedDateKey];

    // Grab a bundle ID
    NSString *bundleID
      = [mdAttributes objectForKey:(NSString *)kMDItemCFBundleIdentifier];
    if (bundleID) {
      [attributes setObject:bundleID forKey:kHGSObjectAttributeBundleIDKey];
    }

    // create a HGSResult to talk to the rest of the application
    HGSUnscoredResult *hgsResult
      = [HGSUnscoredResult resultWithFilePath:path
                                       source:self
                                   attributes:attributes];

    [database indexResult:hgsResult
                 name:name
            otherTerm:fileSystemName];

  }

  // Due to a bug in 10.5.6 we can't find the network prefpane
  // add it by hand
  // Radar 6495591 Can't find network prefpane using spotlight
  NSString *networkPath = @"/System/Library/PreferencePanes/Network.prefPane";
  NSBundle *networkBundle = [NSBundle bundleWithPath:networkPath];

  if (networkBundle) {
    NSString *name
      = [networkBundle objectForInfoDictionaryKey:@"NSPrefPaneIconLabel"];
    name = [name stringByAppendingFormat:@" %@", prefPaneString];
    // Unfortunately last used date is hidden from us.
    [regularAttributes removeObjectForKey:kHGSObjectAttributeLastUsedDateKey];
    [regularAttributes setObject:@"com.apple.preference.network"
                          forKey:kHGSObjectAttributeBundleIDKey];
    NSURL *url = [NSURL fileURLWithPath:networkPath];
    HGSUnscoredResult *hgsResult
      = [HGSUnscoredResult resultWithURI:[url absoluteString]
                                    name:name
                                    type:kHGSTypeFileApplication
                                  source:self
                              attributes:regularAttributes];

    [database indexResult:hgsResult];
  } else {
    HGSLog(@"Unable to find Network.prefpane");
  }
  [self replaceCurrentDatabaseWith:database];
  [self saveResultsCache];
  [query enableUpdates];
}

- (void)queryNotification:(NSNotification *)notification {
  NSString *name = [notification name];
  if ([name isEqualToString:NSMetadataQueryDidFinishGatheringNotification]
      || [name isEqualToString:NSMetadataQueryDidUpdateNotification] ) {
    NSMetadataQuery *query = [notification object];
    [query_ disableUpdates];
    NSOperation *op
      = [[[NSInvocationOperation alloc] initWithTarget:self
                                              selector:@selector(parseResultsOperation:)
                                                object:query]
         autorelease];
    [[HGSOperationQueue sharedOperationQueue] addOperation:op];
  }
}

#pragma mark -

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  if (isValid) {
    HGSResult *pivotObject = [query pivotObject];
    if ([pivotObject conformsToType:kHGSTypeFileApplication]) {
      NSString *appName = [[pivotObject filePath] lastPathComponent];
      isValid = [appName isEqualToString:@"System%20Preferences.app"];
    }
  }
  return isValid;
}

- (HGSResult *)preFilterResult:(HGSResult *)result
               matchesForQuery:(HGSQuery*)query
                  pivotObjects:(HGSResultArray *)pivotObjects {
  if ([pivotObjects conformsToType:kHGSTypeFileApplication]) {
    // Remove things that aren't preference panes
    NSString *absolutePath = [result filePath];
    if (![self pathIsPrefPane:absolutePath]) {
      result = nil;
    }
  }
  return result;
}

// A real quick and dirty fast pass on the expected locations.
- (void)fastIndex {
  NSArray *applicationFolders
    = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,
                                          NSUserDomainMask | NSLocalDomainMask,
                                          YES);
  NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSLaunchableRankFlag];
  NSMutableDictionary *regularAttributes
    = [NSMutableDictionary dictionaryWithObject:rankFlags
                                         forKey:kHGSObjectAttributeRankFlagsKey];
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];
  NSFileManager *fm = [NSFileManager defaultManager];
  for (NSString *appPath in applicationFolders) {
    NSDirectoryEnumerator *fileEnumerator = [fm enumeratorAtPath:appPath];
    for (NSString *path in fileEnumerator) {
      NSString *extension = [path pathExtension];
      if ([extension length]) {
        if ([extension isEqualToString:@"app"]) {
          NSString *fullPath = [appPath stringByAppendingPathComponent:path];
          NSString *uriPath
            = [fullPath stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
          NSString *url = [@"file://localhost" stringByAppendingString:uriPath];
          HGSUnscoredResult *hgsResult
            = [HGSUnscoredResult resultWithURI:url
                                          name:[fm displayNameAtPath:fullPath]
                                          type:kHGSTypeFileApplication
                                        source:self
                                    attributes:regularAttributes];

          [database indexResult:hgsResult];
        }
        [fileEnumerator skipDescendents];
      }
    }
  }
  [self replaceCurrentDatabaseWith:database];
}



@end

