//
//  QSBGeneralDataProvider.m
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

#import "GDGeneralDataProvider.h"
#import <Vermilion/Vermilion.h>

NSString* const GDGeneralDataProviderObjectKey = @"GDGeneralDataProviderObjectKey";
NSString* const GDGeneralDataProviderIconKey = @"GDGeneralDataProviderIconKey";

@interface GDGeneralDataProvider (GDGeneralDataProviderPrivateMethods)

// Immediately load icon for the given result object.
- (NSImage *)loadIconForObject:(HGSObject *)object;

// Determine if the result is a fileURL and compose a path cell array for it.
- (id)valueForFileURL:(HGSObject*)result;

// Determine if the results is a regular URL and compose a path cell array for it.
- (id)pathCellArrayForURL:(HGSObject*)result;

@end

@implementation GDGeneralDataProvider

- (id)provideValueForKey:(NSString*)key result:(HGSObject*)result {
  id value = nil;
  if ([key isEqualToString:kHGSObjectAttributeIconKey]
      || [key isEqualToString:kHGSObjectAttributeImmediateIconKey]) {  
    HGSIconProvider *provider = [HGSIconProvider sharedIconProvider];
    if ([key isEqualToString:kHGSObjectAttributeImmediateIconKey]) {
      value = [provider provideIconForResult:result
                                  loadLazily:NO
                                    useCache:YES];
      if (!value) {
        value = [self loadIconForObject:result];
      }
    } else {
      // Use the icon cache to retrive the icon
      value = [provider provideIconForResult:result
                                  loadLazily:YES
                                    useCache:YES];
    }
  } else if ([key isEqualToString:kHGSObjectAttributePathCellsKey]) {
    value = [self valueForFileURL:result];
    if (!value) value = [self pathCellArrayForURL:result];
  } else if ([key isEqualToString:kHGSObjectAttributeDefaultActionKey]) {
    HGSExtensionPoint *actionPoint = [HGSExtensionPoint actionsPoint];
    HGSModuleLoader *sharedLoader = [HGSModuleLoader sharedModuleLoader];
    id<HGSDelegate> delegate = [sharedLoader delegate];
    NSString *actionID = [delegate defaultActionID];
    value = [actionPoint extensionWithIdentifier:actionID];
  }
  return value;
}

@end

@implementation GDGeneralDataProvider (GDGeneralDataProviderPrivateMethods)

- (NSImage*)loadIconForObject:(HGSObject *)object {
  NSImage *value = nil;
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSURL *url = [object valueForKey:kHGSObjectAttributeIconPreviewFileKey];
  if (!url) {
    url = [object identifier];
  }
  if (url) {
    if ([url isFileURL]) {
      value = [ws iconForFile:[url path]];
    } else {
      NSString *scheme = [url scheme];
      typedef struct {
        NSString *scheme;
        OSType icon;
      } SchemeMap;
      SchemeMap map[] = {
        { @"http", 'tSts' },
        { @"https", 'tSts' },
        { @"ftp", kInternetLocationFTPIcon },
        { @"afp", kInternetLocationAppleShareIcon },
        { @"mailto", kInternetLocationMailIcon },
        { @"news", kInternetLocationNewsIcon }
      };
      OSType iconType = kInternetLocationGenericIcon;
      for (size_t i = 0; i < sizeof(map) / sizeof(SchemeMap); ++i) {
        if ([scheme caseInsensitiveCompare:map[i].scheme] == NSOrderedSame) {
          iconType = map[i].icon;
          break;
        }
      }
      return [ws iconForFileType:NSFileTypeForHFSTypeCode(iconType)];
    }
  }
  return value;
}

- (id)valueForFileURL:(HGSObject*)result {
  NSMutableArray *cellArray = nil;

  // Provide a cellArray for the path control assuming that we are
  // a file and our identifier is a file URL.
  NSURL *baseURL = [result identifier];
  if ([baseURL isFileURL]) {
    // Generate a list of display components and then walk backwards
    // through it generating URLs for each component.
    NSString *targetPath = [baseURL path];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *displayComponents = [fm componentsToDisplayForPath:targetPath];
    if (displayComponents) {
      cellArray = [NSMutableArray arrayWithCapacity:[displayComponents count]];
      NSEnumerator *reverseEnum = [displayComponents reverseObjectEnumerator];
      NSString *component;
      NSString *subPath = targetPath;
      while ((component = [reverseEnum nextObject])) {
        NSURL *url = [NSURL fileURLWithPath:subPath];
        NSDictionary *cellDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  component, kHGSPathCellDisplayTitleKey,
                                  url, kHGSPathCellURLKey,
                                  nil];
        [cellArray insertObject:cellDict atIndex:0];
        subPath = [subPath stringByDeletingLastPathComponent];
      }
      // Determine if we can abbreviate the path presentation.
      
      // First, see if this is in the user's home directory structure
      // and, if so, abbreviated it with 'Home'.  If not, then check
      // to see if we're on the root volume and if so, don't show
      // the volume name.
      NSString *homeDirectory = NSHomeDirectory();
      NSString *homeDisplay = [fm displayNameAtPath:homeDirectory];
      NSUInteger compCount = 0;
      NSDictionary *componentToAdd = nil;
      NSDictionary *firstCell = [cellArray objectAtIndex:0];
      NSString *firstCellTitle = [firstCell objectForKey:kHGSPathCellDisplayTitleKey];
      if ([firstCellTitle isEqualToString:homeDisplay]) {
        compCount = 1;
        componentToAdd = [NSDictionary dictionaryWithObjectsAndKeys:
                          HGSLocalizedString(@"Home", nil), kHGSPathCellDisplayTitleKey,
                          [NSURL fileURLWithPath:homeDirectory], kHGSPathCellURLKey,
                          nil];
      } else {
        NSString *rootDisplay = [fm displayNameAtPath:@"/"];
        if ([firstCellTitle isEqualToString:rootDisplay]) {
          compCount = 1;
        }
      }
      if (compCount) {
        [cellArray removeObjectsInRange:NSMakeRange(0, compCount)];
      }
      if (componentToAdd) {
        [cellArray insertObject:componentToAdd atIndex:0];
      }
    } else {
      HGSLogDebug(@"Unable to get path components for path '%@'.", targetPath);
    }
  }
  
  return cellArray;
}

- (id)pathCellArrayForURL:(HGSObject*)result {
  NSMutableArray *cellArray = nil;
  
  // See if we have a regular URL.
  NSURL *baseURL = [result identifier];
  NSString *absolutePath = [baseURL absoluteString];
  if (absolutePath) {
    // Build up two path cells, one with the domain, and the second
    // with the location within the domain.  Do this by finding the
    // first and second occurrence of the slash separator.
    NSString *hostString = [baseURL host];
    if ([hostString length]) {
      cellArray = [NSMutableArray arrayWithCapacity:2];
      NSURL *pathURL = [NSURL URLWithString:absolutePath];
      NSString *pathString = [baseURL path];
     
      if ([pathString length] == 0 || [pathString isEqualToString:@"/"]) {
        // We just have a host cell.
        NSDictionary *hostCell = [NSDictionary dictionaryWithObjectsAndKeys:
                                  hostString, kHGSPathCellDisplayTitleKey,
                                  pathURL, kHGSPathCellURLKey,
                                  nil];
        [cellArray addObject: hostCell];
      } else {          
        // NOTE: Attempts to use -[NSURL initWithScheme:host:path:] were unsuccessful
        //       using (nil|@""|@"/") for the path.  Each fails to produce an
        //       acceptable URL or throws an exception.
        // NSURL *hostURL = [[[NSURL alloc] initWithScheme:[baseURL scheme]
        //                                            host:hostString
        //                                            path:???] autorelease];
        NSURL *hostURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/",
                                               [baseURL scheme], hostString]];
        NSDictionary *hostCell = [NSDictionary dictionaryWithObjectsAndKeys:
                                  hostString, kHGSPathCellDisplayTitleKey,
                                  hostURL, kHGSPathCellURLKey,
                                  nil];
        [cellArray addObject: hostCell];
        NSDictionary *pathCell = [NSDictionary dictionaryWithObjectsAndKeys:
                                  pathString, kHGSPathCellDisplayTitleKey,
                                  pathURL, kHGSPathCellURLKey,
                                  nil];
        [cellArray addObject: pathCell];
      }
    }
  }
  return cellArray;
}

@end

