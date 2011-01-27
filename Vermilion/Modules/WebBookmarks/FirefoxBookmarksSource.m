//
//  FirefoxBookmarksSource.m
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
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

// Copyright (c) 2009 Aaron Ecay
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "FirefoxBookmarksSource.h"
#import <JSON/JSON.h>
#import "GTMFileSystemKQueue.h"

@interface NSFileManager (FirefoxBookmarksSource)
- (NSString *)mostRecentFileInDirectory:(NSString *)path;
@end

@interface FirefoxBookmarksSource ()
// -[NSString JSONValue] can result in NSNull objects in the returned
// dictionary for the FF JSON so we have to strip those out.
- (id)removeNullsFromJSONObject:(id)object;
@end

@interface NSString (FirefoxBookmarksSource)
// Firefox may have unnecessary, non-standard commas which causes
// -[NSString JSONValue] to fail.  Remove those commas.
- (NSString *)stringByStrippingUnnecessaryCommasFromFirefoxJSONString;
@end

@implementation FirefoxBookmarksSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  NSString *path = [self iniFilePath];
  return [super initWithConfiguration:configuration
                      browserTypeName:@"firefox"
                          fileToWatch:path];
}

// COV_NF_START
- (void)dealloc {
  // Plugins aren't unloaded
  [bookmarksDirectoryKQueue_ release];
  [searchPluginsDirectoryKQueue_ release];
  [super dealloc];
}
// COV_NF_END

- (void)updateDatabase:(HGSMemorySearchSourceDB *)database
               forPath:(NSString *)path 
             operation:(NSOperation *)operation {
  if ([operation isCancelled]) return;
  NSString *bookmarksPath = [bookmarksDirectoryKQueue_ path];
  NSString *pluginsPath = [searchPluginsDirectoryKQueue_ path];
  if (![path isEqual:bookmarksPath] && ![path isEqual:pluginsPath]) {
    NSString *iniPath = [self iniFilePath];
    NSString *profilePath = [self defaultProfilePathFromIniFilePath:iniPath];
    bookmarksPath = [self bookmarksBackupDirectoryFromProfilePath:profilePath];
    
    // we need to recreate the whole shooting match because our ini file has
    // changed
    GTMFileSystemKQueueEvents queueEvents = (kGTMFileSystemKQueueDeleteEvent 
                                             | kGTMFileSystemKQueueWriteEvent);
    
    [bookmarksDirectoryKQueue_ release];
    bookmarksDirectoryKQueue_ 
      = [[GTMFileSystemKQueue alloc] initWithPath:bookmarksPath
                                        forEvents:queueEvents
                                    acrossReplace:YES
                                           target:self
                                           action:@selector(fileChanged:event:)];
    
    pluginsPath = [self searchPluginsDirectoryFromProfilePath:profilePath];
    [searchPluginsDirectoryKQueue_ release];
    searchPluginsDirectoryKQueue_
      = [[GTMFileSystemKQueue alloc] initWithPath:pluginsPath
                                        forEvents:queueEvents
                                    acrossReplace:YES
                                           target:self
                                           action:@selector(fileChanged:event:)];
  }
    
  NSArray *plugins = [self inventorySearchPluginsAtPath:pluginsPath];
  for(NSDictionary *plugin in plugins) {
    NSString *name = [plugin objectForKey:kHGSObjectAttributeNameKey];
    NSString *urlString = [plugin objectForKey:kHGSObjectAttributeURIKey];
    [self indexResultNamed:name 
                       URL:urlString 
           otherAttributes:nil 
                      into:database];
  }
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *bookmarksFile = [fm mostRecentFileInDirectory:bookmarksPath];
  NSDictionary *bookmarksDict = [self bookmarksFromFile:bookmarksFile];
  NSArray *bookmarks = [self inventoryBookmarks:bookmarksDict];
  for (NSDictionary *bookmark in bookmarks) {
    NSString *name = [bookmark objectForKey:kHGSObjectAttributeNameKey];
    NSString *urlString = [bookmark objectForKey:kHGSObjectAttributeURIKey];
    NSDate *date = [bookmark objectForKey:kHGSObjectAttributeLastUsedDateKey];
    NSDictionary *otherAttributes
      = [NSDictionary dictionaryWithObject:date 
                                    forKey:kHGSObjectAttributeLastUsedDateKey];
    [self indexResultNamed:name 
                       URL:urlString 
           otherAttributes:otherAttributes
                      into:database];
  }
}

- (NSDictionary *)defaultProfileDictFromIniFileDict:(NSDictionary *)iniFileDict {
  NSDictionary *defaultDict = nil;
  NSDictionary *firstProfile = nil;
  for (NSString *key in iniFileDict) {
    if ([key hasPrefix:@"Profile"]) {
      NSDictionary *dataDict = [iniFileDict objectForKey:key];
      if (!firstProfile) firstProfile = dataDict;
      NSString *defaultValue = [dataDict objectForKey:@"Default"];
      if ([defaultValue boolValue]) {
        defaultDict = dataDict;
      }
    }
  }
  if (!defaultDict) {
    defaultDict = firstProfile;
  }
  return defaultDict;
}
  
- (NSDictionary *)parseIniFileAtPath:(NSString *)path {
  NSMutableDictionary *profileDict = nil;
  NSError *error = nil;
  NSString *profileIniString 
    = [NSString stringWithContentsOfFile:path 
                                encoding:NSUTF8StringEncoding 
                                   error:&error];
  if (error) {
    HGSLog(@"Unable to load %@ (%@)", path, error);
  } else {
    NSArray *profileIniLines 
      = [profileIniString componentsSeparatedByString:@"\n"];
    if (!profileIniLines) return nil;
    profileDict = [NSMutableDictionary dictionary];
    NSMutableDictionary *entryDict = nil;
    NSString *entryKey = nil;
    NSCharacterSet *wsSet = [NSCharacterSet whitespaceCharacterSet];
    for (NSString *line in profileIniLines) {
      line = [line stringByTrimmingCharactersInSet:wsSet];
      if ([line length]) {
        if ([line hasPrefix:@"["] && [line hasSuffix:@"]"]) {
          if (entryKey && entryDict) {
            [profileDict setObject:entryDict forKey:entryKey];
          }
          entryKey = [line substringWithRange:NSMakeRange(1, [line length] - 2)];
          entryDict = [NSMutableDictionary dictionary];
        } else {
          NSRange keyRange = [line rangeOfString:@"="];
          if (keyRange.length == 1) {
            NSString *key = [line substringToIndex:keyRange.location];
            NSString *entry = [line substringFromIndex:keyRange.location + 1];
            [entryDict setObject:entry forKey:key];
          }
        }
      }
    }
    if (entryKey && entryDict) {
      [profileDict setObject:entryDict forKey:entryKey];
    }
  }
  return profileDict;
}

- (NSString *)defaultProfilePathFromIniFilePath:(NSString *)iniFile {
  NSDictionary *profileDict = [self parseIniFileAtPath:iniFile];
  NSDictionary *defaultDict 
    = [self defaultProfileDictFromIniFileDict:profileDict];
  NSString *profilePath = [defaultDict objectForKey:@"Path"];
  NSNumber *value = [defaultDict objectForKey:@"IsRelative"];
  NSString *finalPath = nil;
  if ([value boolValue] && profilePath) {
    NSString *rootPath = [iniFile stringByDeletingLastPathComponent];
    finalPath = [rootPath stringByAppendingPathComponent:profilePath];
  } else {
    finalPath = profilePath;
  }
  return finalPath;
}

- (NSString *)iniFilePath {
  NSArray *appSupportDirArray
    = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, 
                                          NSUserDomainMask,
                                          YES);
  if (![appSupportDirArray count]) {
    // COV_NF_START
    // App support is always there
    HGSLog(@"Unable to find ~/Library/Application Support/");
    [self release];
    return nil;
    // COV_NF_END
  }
  NSString *appSupportDir = [appSupportDirArray objectAtIndex:0];
  NSString *iniFilePath 
    = [appSupportDir stringByAppendingPathComponent:@"Firefox"];
  return [iniFilePath stringByAppendingPathComponent:@"profiles.ini"];
}  

- (id)removeNullsFromJSONObject:(id)object {
  id newObject = nil;
  if ([object isKindOfClass:[NSArray class]]) {
    newObject = [NSMutableArray arrayWithCapacity:[object count]];
    for (id element in object) {
      id newElement = [self removeNullsFromJSONObject:element];
      if (newElement) {
        [newObject addObject:newElement];
      }
    }
  } else if ([object isKindOfClass:[NSDictionary class]]) {
    newObject = [NSMutableDictionary dictionaryWithCapacity:[object count]];
    for (id key in object) {
      id element = [object valueForKey:key];
      id newElement = [self removeNullsFromJSONObject:element];
      if (newElement) {
        [newObject setObject:newElement forKey:key];
      }
    }
  } else if (![object isEqual:[NSNull null]]) {
    newObject = object;
  }
  return newObject;
}     
      
- (NSDictionary *)bookmarksFromFile:(NSString *)path {
  NSError *error = nil;
  NSDictionary *dictWithoutNulls = nil;
  NSString *fileContents 
    = [NSString stringWithContentsOfFile:path 
                                encoding:NSUTF8StringEncoding 
                                   error:&error];
  if (error) {
    HGSLog(@"Unable to load %@ (%@)", path, error);
  } else {
    fileContents
      = [fileContents stringByStrippingUnnecessaryCommasFromFirefoxJSONString];
    NSDictionary *dict = [fileContents JSONValue];
    dictWithoutNulls = [self removeNullsFromJSONObject:dict];
  }
  return dictWithoutNulls;
}

- (void)addBookmarksInDictionary:(NSDictionary *)bookmarks
                         toArray:(NSMutableArray *)array {
  NSArray *children = [bookmarks objectForKey:@"children"];
  if (children) {
    for (NSDictionary *child in children) {
      [self addBookmarksInDictionary:child toArray:array];
    }
  } else {
    NSString *type = [bookmarks objectForKey:@"type"];
    if ([type isEqual:@"text/x-moz-place"]) {
      NSString *uri = [bookmarks objectForKey:@"uri"];
      if ([uri hasPrefix:@"http"]) {
        NSString *title = [bookmarks objectForKey:@"title"];
        if (title) {
          NSNumber *lastModified = [bookmarks objectForKey:@"lastModified"];
          // Firefox stores its dates as microseconds since the epoch.
          // We floor it because dates created without the floor don't compare
          // very well due to round off error. i.e. if you don't floor it,
          // our unittests will fail.
          NSTimeInterval firefoxDate = floor([lastModified doubleValue] / 1000000);
          NSDate *date = [NSDate dateWithTimeIntervalSince1970:firefoxDate];
          NSDictionary *bookmark = [NSDictionary dictionaryWithObjectsAndKeys:
                                    title, kHGSObjectAttributeNameKey,
                                    uri , kHGSObjectAttributeURIKey,
                                    date, kHGSObjectAttributeLastUsedDateKey,
                                    nil];
          [array addObject:bookmark];
        }
      }
    }
  }
}

- (NSArray *)inventoryBookmarks:(NSDictionary *)bookmarks {
  NSMutableArray *array = [NSMutableArray array];
  [self addBookmarksInDictionary:bookmarks toArray:array];
  return array;
}

- (NSString *)bookmarksBackupDirectoryFromProfilePath:(NSString *)profile {
  NSString *path = [profile stringByAppendingPathComponent:@"bookmarkbackups"];
  return path;
}

- (NSString *)searchPluginsDirectoryFromProfilePath:(NSString *)profile {
  NSString *path = [profile stringByAppendingPathComponent:@"searchplugins"];
  return path;
}

- (NSArray*)inventorySearchPluginsAtPath:(NSString *)path {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error = nil;
  NSArray *pluginFiles = [fm contentsOfDirectoryAtPath:path error:&error];
  if (error) {
    HGSLog(@"Unable to read contents of %@ (%@)", path, error);
  }
  NSMutableArray *pluginEntries 
    = [NSMutableArray arrayWithCapacity:[pluginFiles count]];
  for (NSString *pluginFile in pluginFiles) {
    NSString *pluginPath = [path stringByAppendingPathComponent:pluginFile];
    NSURL *pluginUrl 
      = [[[NSURL alloc] initFileURLWithPath:pluginPath] autorelease];
    error = nil;
    NSXMLDocument *pluginDoc 
      = [[[NSXMLDocument alloc] initWithContentsOfURL:pluginUrl
                                              options:0
                                                error:&error] autorelease];
    if (error) {
      HGSLog(@"Unable to parse search plugin file %@ (%@)", 
             pluginUrl, error);
      continue;
    }
    
    NSArray *names = [pluginDoc nodesForXPath:@"//os:ShortName"
                                        error:&error];
    if (error || [names count] == 0) {
      HGSLog(@"Unable to get //os:ShortName from %@ (%@)", pluginUrl, error);
      continue;
    }
    
    NSString *name = [[names objectAtIndex:0] stringValue];
    NSArray *urls = [pluginDoc nodesForXPath:@"//os:Url"
                                       error:&error];
    if (error || [urls count] == 0) {
      HGSLog(@"Unable to get //os:Url from %@ (%@)", pluginUrl, error);
      continue;
    } 
    NSXMLElement *urlNode = [urls objectAtIndex:0];
    NSXMLNode *templateNode = [urlNode attributeForName:@"template"];
    NSString *urlString = [templateNode stringValue];
    urlString = [urlString stringByReplacingOccurrencesOfString:@"{searchTerms}"
                           withString:@"%s"];
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                          name, kHGSObjectAttributeNameKey,
                          urlString, kHGSObjectAttributeURIKey,
                          nil];
    [pluginEntries addObject:dict];
  }
  return pluginEntries;
}

@end

@implementation NSFileManager (FirefoxBookmarksSource)

- (NSString *)mostRecentFileInDirectory:(NSString *)path {
  NSString *recentPath = nil;
  NSDate *oldDate = [NSDate distantPast];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator *fileEnum = [fm enumeratorAtPath:path];
  NSString *fullPath = nil;
  for (NSString *file in fileEnum) {
    fullPath = [path stringByAppendingPathComponent:file];
    NSError *error = nil;
    NSDictionary *attributes = nil;
    NSString *fileType = nil;
    do {
      attributes = [fm attributesOfItemAtPath:fullPath error:&error];
      if (!attributes || error) {
        HGSLogDebug(@"Error getting attributes for %@ (%@)", fullPath, error);
        break;
      }
      fileType = [attributes objectForKey:NSFileType];
    } while ([fileType isEqual:NSFileTypeSymbolicLink]);
    if ([fileType isEqual:NSFileTypeRegular]) {
      NSDate *modDate = [attributes objectForKey:NSFileModificationDate];
      if (!modDate) {
        HGSLogDebug(@"Unable to get moddate for %@", fullPath);
        continue;
      }
      if ([modDate compare:oldDate] == NSOrderedDescending) {
        oldDate = modDate;
        recentPath = fullPath;
      }
    }
  }
  return recentPath;
}

@end

@implementation NSString (FirefoxBookmarksSource)

- (NSString *)stringByStrippingUnnecessaryCommasFromFirefoxJSONString {
  // The only known case at the moment is an extra comma at the end of
  // the main 'children' section.  Fix: s/,\]/\]/.
  NSString *cleanString
    = [self stringByReplacingOccurrencesOfString:@",]" withString:@"]"];
  return cleanString;
}

@end
