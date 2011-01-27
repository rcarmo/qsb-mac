//
//  HGSPluginLoaderTest.m
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
#import "HGSPluginLoader.h"
#import "HGSDelegate.h"
#import "HGSBundle.h"

@interface HGSTestLoaderPlugin : NSObject
@end

@interface HGSTestLoaderDelegate : NSObject <HGSDelegate> 
@end

@implementation HGSTestLoaderDelegate

- (NSArray *)pluginFolders {
  NSBundle *bundle = HGSGetPluginBundle();
  NSString *pluginsPath = [[bundle bundlePath] stringByDeletingLastPathComponent];
  NSArray *pluginsPaths = nil;
  if ([pluginsPath length]) {
    pluginsPaths = [NSArray arrayWithObject:pluginsPath];
  }
  return pluginsPaths;
}

// Unused delegate functions.
- (NSString *)userApplicationSupportFolderForApp {
  return nil;
}

- (NSString *)userCacheFolderForApp {
  return nil;
}

- (NSString *)suggestLanguage {
  return nil;
}

- (NSString *)clientID {
  return nil;
}

- (id)provideValueForKey:(NSString *)key result:(HGSResult *)result {
  return nil;
}

- (NSDictionary *)getActionSaveAsInfoFor:(NSDictionary *)request {
  return nil;
}

- (NSArray *)sourcesToRunOnMainThread {
  return nil;
}

@end


@interface HGSPluginLoaderTest : GTMTestCase
@end


@implementation HGSPluginLoaderTest

- (void)testBundlePathsForPluginPath {
  HGSPluginLoader *pluginLoader = [HGSPluginLoader sharedPluginLoader];
  [pluginLoader registerClass:[HGSTestLoaderPlugin class] 
                forExtensions:[NSArray arrayWithObject:@"octest"]];
  STAssertNotNil(pluginLoader, nil);
  HGSTestLoaderDelegate *loaderDelegate
    = [[[HGSTestLoaderDelegate alloc] init] autorelease];
  STAssertNotNil(loaderDelegate, nil);
  STAssertNotNil([loaderDelegate pluginFolders], nil);
  [pluginLoader setDelegate:loaderDelegate];
  NSArray *errors;
  NSMutableArray *unexpectedErrors = [NSMutableArray array];
  [pluginLoader loadPluginsWithErrors:&errors];
  for (NSDictionary *error in errors) {
    NSString *errorString 
      = [error objectForKey:kHGSPluginLoaderPluginFailureKey];
    if (![errorString isEqual:kHGSPluginLoaderPluginFailedUnknownPluginType]) {
      [unexpectedErrors addObject:error];
    }
  }
  STAssertEquals([unexpectedErrors count], (NSUInteger)0, 
                 @"Errors: %@", unexpectedErrors);
  NSArray *paths = [pluginLoader pluginsSDEFPaths];
  STAssertEquals([paths count], (NSUInteger)1, @"Paths: %@", paths);
  [pluginLoader setDelegate:nil];
}

@end

@implementation HGSTestLoaderPlugin
+ (BOOL)isPluginBundleValidAPI:(NSBundle *)pluginBundle {
  return YES;
}
- (id)initWithBundle:(NSBundle *)bundle {
  self = [super init];
  return self;
}
- (NSString *)identifier {
  return NSStringFromClass([self class]);
}
@end

