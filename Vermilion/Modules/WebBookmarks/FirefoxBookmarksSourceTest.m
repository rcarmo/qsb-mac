//
//  FirefoxBookmarksSourceTest.m
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

#import "GTMSenTestCase.h"
#import "HGSUnitTestingUtilities.h"
#import "FirefoxBookmarksSource.h"

@interface FirefoxBookmarksSourceTest : HGSSearchSourceAbstractTestCase {
 @private
  NSString *dirToRemovePath_;
}
@end

@implementation FirefoxBookmarksSourceTest
- (id)initWithInvocation:(NSInvocation *)invocation {
  NSBundle *hgsBundle = HGSGetPluginBundle();
  NSString *firefoxSupportDir
    = [@"~/Library/Application Support/Firefox" stringByExpandingTildeInPath];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:firefoxSupportDir]) {
    NSString *firefoxResourceDir
      = [[hgsBundle resourcePath] stringByAppendingPathComponent:@"Firefox"];
    NSError *error = nil;
    if ([fm copyItemAtPath:firefoxResourceDir
                    toPath:firefoxSupportDir
                     error:&error]) {
      dirToRemovePath_ = [firefoxSupportDir retain];
    } else {
      STFail(@"Could not copy Firefox app support (%@)", error);
    }
  }
  
  self = [super initWithInvocation:invocation 
                       pluginNamed:@"WebBookmarks" 
               extensionIdentifier:@"com.google.qsb.webbookmarks.firefox.source"];
  return self;
}

- (void)dealloc {
  if (dirToRemovePath_) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    if (![fm removeItemAtPath:dirToRemovePath_ error:&error]) {
      STFail(@"Unable to remove %@ (%@)", dirToRemovePath_, error);
    }
    [dirToRemovePath_ release];
  }
  [super dealloc];
}

- (void)testParseFirefoxIniFile {
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *iniPath = [pluginBundle pathForResource:@"profiles" 
                                             ofType:@"ini"
                                        inDirectory:@"Firefox"];
  FirefoxBookmarksSource *ffSource = (FirefoxBookmarksSource *)[self source];
  NSDictionary *dict = [ffSource parseIniFileAtPath:iniPath];
  STAssertNotNil(dict, @"Unable to parse %@", iniPath);

  NSString *masterPath = [pluginBundle pathForResource:@"profiles.ini"
                                                ofType:@"xml"
                                           inDirectory:@"Firefox"];
  NSDictionary *masterDict
    = [NSDictionary dictionaryWithContentsOfFile:masterPath];
  STAssertNotNil(masterDict, @"Unable to load master %@", masterPath);
  STAssertEqualObjects(masterDict, dict, nil);
}

- (void)testFirefoxIniPath {
  FirefoxBookmarksSource *ffSource = (FirefoxBookmarksSource *)[self source];
  NSString *path = [ffSource iniFilePath];
  NSString *expectedPath 
    = @"~/Library/Application Support/Firefox/profiles.ini";
  expectedPath = [expectedPath stringByStandardizingPath];
  STAssertEqualObjects(path, expectedPath, nil);
}

- (void)testDefaultProfileFromIniFileDict {
  FirefoxBookmarksSource *ffSource = (FirefoxBookmarksSource *)[self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *iniPath = [pluginBundle pathForResource:@"profiles" 
                                             ofType:@"ini"
                                        inDirectory:@"Firefox"];
  
  // Test with a solo entry
  NSDictionary *iniDict = [ffSource parseIniFileAtPath:iniPath];
  STAssertNotNil(iniDict, @"Unable to parse %@", iniPath);
  NSDictionary *defaultDict 
    = [ffSource defaultProfileDictFromIniFileDict:iniDict];
  NSString *path = [defaultDict objectForKey:@"Path"];
  STAssertEqualObjects(path, @"Profiles/mt3pkk17.default", nil);
  
  // Test with a default entry
  iniPath = [pluginBundle pathForResource:@"profilesWith2Profiles" 
                                   ofType:@"ini"
                              inDirectory:@"Firefox"];
  iniDict = [ffSource parseIniFileAtPath:iniPath];
  STAssertNotNil(iniDict, @"Unable to parse %@", iniPath);
  defaultDict = [ffSource defaultProfileDictFromIniFileDict:iniDict];
  path = [defaultDict objectForKey:@"Path"];
  STAssertEqualObjects(path, @"Profiles/308lm7ed.Foo", nil);
}

- (void)testParseBookmarksFile {
  FirefoxBookmarksSource *ffSource = (FirefoxBookmarksSource *)[self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *jsonPath = [pluginBundle pathForResource:@"bookmarks" 
                                              ofType:@"json"
                                         inDirectory:@"Firefox"];
  
  // Test with a solo entry
  NSDictionary *iniDict = [ffSource bookmarksFromFile:jsonPath];
  STAssertNotNil(iniDict, @"Unable to parse %@", jsonPath);
  NSString *masterPath = [pluginBundle pathForResource:@"bookmarks.json" 
                                                ofType:@"xml"
                                           inDirectory:@"Firefox"];
  NSDictionary *masterDict 
    = [NSDictionary dictionaryWithContentsOfFile:masterPath];
  STAssertNotNil(masterDict, nil);
  STAssertEqualObjects(iniDict, masterDict, nil);
}

- (void)testFirefoxDefaultProfilePath {
  FirefoxBookmarksSource *ffSource = (FirefoxBookmarksSource *)[self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *iniPath = [pluginBundle pathForResource:@"profiles" 
                                             ofType:@"ini"
                                        inDirectory:@"Firefox"];
  STAssertNotNil(iniPath, nil);
  NSString *ffPath = [ffSource defaultProfilePathFromIniFilePath:iniPath];
  NSString *expected = [iniPath stringByDeletingLastPathComponent];
  expected 
    = [expected stringByAppendingPathComponent:@"Profiles/mt3pkk17.default"];
  STAssertEqualObjects(ffPath, expected, nil);
}

- (void)testFirefoxBookmarksBackupDirectoryFromProfilePath {
  FirefoxBookmarksSource *ffSource = (FirefoxBookmarksSource *)[self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *iniPath = [pluginBundle pathForResource:@"profiles" 
                                             ofType:@"ini"
                                        inDirectory:@"Firefox"];
  STAssertNotNil(iniPath, nil);
  NSString *ffPath = [ffSource defaultProfilePathFromIniFilePath:iniPath];
  NSString *expected = [iniPath stringByDeletingLastPathComponent];
  expected 
    = [expected stringByAppendingPathComponent:@"Profiles/mt3pkk17.default"];
  STAssertEqualObjects(ffPath, expected, nil);
}

- (void)testInventorySearchPluginsAtPath {
  FirefoxBookmarksSource *ffSource = (FirefoxBookmarksSource *)[self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *pluginsPath = [pluginBundle pathForResource:@"searchplugins"
                                                 ofType:nil
                                            inDirectory:@"Firefox"];
  STAssertNotNil(pluginsPath, nil);
  NSArray *items = [ffSource inventorySearchPluginsAtPath:pluginsPath];
  NSString *masterPath = [pluginBundle pathForResource:@"searchPluginsMaster" 
                                                ofType:@"xml"
                                           inDirectory:@"Firefox"];
  STAssertNotNil(masterPath, nil);
  NSArray *masterItems = [NSArray arrayWithContentsOfFile:masterPath];
  STAssertEqualObjects(items, masterItems, nil);
}
 
- (void)testInventoryBookmarks {
  FirefoxBookmarksSource *ffSource = (FirefoxBookmarksSource *)[self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *jsonPath = [pluginBundle pathForResource:@"bookmarks" 
                                              ofType:@"json"
                                         inDirectory:@"Firefox"];
  NSDictionary *bookmarksDict = [ffSource bookmarksFromFile:jsonPath];
  STAssertNotNil(bookmarksDict, @"Unable to parse %@", jsonPath);
  NSArray *bookmarks = [ffSource inventoryBookmarks:bookmarksDict];
  NSString *masterPath = [pluginBundle pathForResource:@"bookmarksMaster" 
                                                ofType:@"xml"
                                           inDirectory:@"Firefox"];
  STAssertNotNil(masterPath, nil);
  NSArray *masterItems = [NSArray arrayWithContentsOfFile:masterPath];
  STAssertEqualObjects(bookmarks, masterItems, nil);
}

- (NSArray *)archivableResults {
  // TODO(dmaclach): add some results to test.
  return nil;
}
@end
