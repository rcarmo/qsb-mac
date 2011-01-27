//
//  HGSUnitTestingUtilities.m
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

#import "HGSUnitTestingUtilities.h"
#import <GTM/GTMGarbageCollection.h>
#import <GTM/GTMDebugThreadValidation.h>
#import <objc/runtime.h>
#import <sys/param.h>

@interface HGSUnitTestingPluginLoader()
- (BOOL)loadPluginWithDelegate:(HGSUnitTestingDelegate *)delegate;
@end

@implementation HGSUnitTestingPluginLoader

+ (BOOL)loadPluginWithDelegate:(HGSUnitTestingDelegate *)delegate {
  HGSUnitTestingPluginLoader *loader 
    = [[[HGSUnitTestingPluginLoader alloc] init] autorelease];
  return [loader loadPluginWithDelegate:delegate];
}

- (BOOL)loadPluginWithDelegate:(HGSUnitTestingDelegate *)delegate {
  // This routine messes with the delegate for the plugin loader.
  // We don't want people changing the delegate out from underneath us.
  GTMAssertRunningOnMainThread();
  HGSPluginLoader *loader = [HGSPluginLoader sharedPluginLoader];
  id oldDelegate = [loader delegate];
  [loader setDelegate:delegate];
  NSArray *errors = nil;
  [loader loadPluginsWithErrors:&errors];
  BOOL wasGood = YES;
  if (errors) {
    wasGood = NO;
    HGSLog(@"Unable to load plugin %@: %@", [delegate path], errors);
  } else {
    [loader installAndEnablePluginsBasedOnPluginsState:nil];
  }
  [loader setDelegate:oldDelegate];
  return wasGood;
}

@end

@implementation HGSUnitTestingDelegate
@synthesize path = path_;

- (id)initWithPath:(NSString *)path {
  if ((self = [super init])) {
    HGSAssert([path length], @"Need a valid plugin");
    path_ = [path copy];
  }
  return self;
}

- (void)dealloc {
  [path_ release];
  [super dealloc];
}

- (NSString*)userFolderNamed:(NSString* )name {
  NSString *workingDir = NSTemporaryDirectory();
  NSString *result = nil;    
  NSString *finalPath
    = [[workingDir stringByAppendingPathComponent:@"Quick Search Box Unit Testing"]
       stringByAppendingPathComponent:name];
  
  // make sure it exists
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:finalPath] ||
      [fm createDirectoryAtPath:finalPath
    withIntermediateDirectories:YES
                     attributes:nil
                          error:NULL]) {
    result = finalPath;
  }
  return result;
}

- (NSString*)userApplicationSupportFolderForApp {
  return [self userFolderNamed:@"Application Support"];
}

- (NSString*)userCacheFolderForApp {
  return [self userFolderNamed:@"Cache"];
}

- (NSArray*)pluginFolders {
  return [NSArray arrayWithObject:path_];
}

- (NSString *)suggestLanguage {
  return @"en_US";
}

- (NSString *)clientID {
  return @"qsb_mac_unit_testing";
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

@implementation HGSExtensionAbstractTestCase 

@synthesize extension = extension_;
@synthesize extensionPointIdentifier = extensionPointIdentifier_;
@synthesize pluginName = pluginName_;
@synthesize identifier = identifier_;
@synthesize delegate = delegate_;

- (id)initWithInvocation:(NSInvocation *)invocation
             pluginNamed:(NSString *)pluginName 
     extensionIdentifier:(NSString *)identifier
extensionPointIdentifier:(NSString *)extensionPointIdentifier
                delegate:(HGSUnitTestingDelegate *)delegate {
  if ((self = [super initWithInvocation:invocation])) {
    pluginName_ = [pluginName copy];
    STAssertGreaterThan([pluginName_ length], (NSUInteger)0, nil);
    identifier_ = [identifier copy];
    STAssertGreaterThan([identifier_ length], (NSUInteger)0, nil);
    extensionPointIdentifier_ = [extensionPointIdentifier copy];
    STAssertGreaterThan([extensionPointIdentifier_ length], (NSUInteger)0, nil);
    loadedExtensions_ = [[NSMutableArray alloc] init];
    delegate_ = delegate;
  }
  return self;
}

- (id)initWithInvocation:(NSInvocation *)invocation
             pluginNamed:(NSString *)pluginName 
     extensionIdentifier:(NSString *)identifier
extensionPointIdentifier:(NSString *)extensionPointIdentifier {
  return [self initWithInvocation:invocation 
                      pluginNamed:pluginName 
              extensionIdentifier:identifier 
         extensionPointIdentifier:extensionPointIdentifier 
                         delegate:nil];
}

- (void)dealloc {
  [pluginName_ release];
  [identifier_ release];
  [extensionPointIdentifier_ release];
  [loadedExtensions_ release];
  [super dealloc];
}

- (void)setUp {
  [super setUp];
  STAssertNil(extension_, @"How is extension not nil?");
  extension_ = [self extensionWithIdentifier:identifier_
                             fromPluginNamed:pluginName_
                    extensionPointIdentifier:extensionPointIdentifier_
                                    delegate:delegate_];
  STAssertNotNil(extension_, nil);
}

- (void)tearDown {
  for (HGSExtension *extension in loadedExtensions_) {
    [[extension protoExtension] uninstall];
  }
  [loadedExtensions_ removeAllObjects];
  extension_ = nil;
  [super tearDown];
}

- (HGSExtension *)extensionWithIdentifier:(NSString *)identifier
                          fromPluginNamed:(NSString *)pluginName
                 extensionPointIdentifier:(NSString *)extensionPointID
                                 delegate:(HGSUnitTestingDelegate *)delegate {
  HGSExtension *extension = nil;
  HGSExtensionPoint *pluginsPoint = [HGSExtensionPoint pluginsPoint];
  HGSPlugin *plugin = [pluginsPoint extensionWithIdentifier:pluginName];
  if (plugin) {
    NSArray *extensions = [plugin extensionsWithType:extensionPointID];
    for (HGSProtoExtension *protoExtension in extensions) {
      if ([[protoExtension identifier] isEqual:identifier]) {
        [protoExtension install];
        extension = [protoExtension extension];
        break;
      }
    }
  } else {
    NSBundle *hgsBundle = HGSGetPluginBundle();
    NSString *bundlePath = [hgsBundle bundlePath];
    NSString *workingDir = [bundlePath stringByDeletingLastPathComponent];
    NSString *path = [workingDir stringByAppendingPathComponent:pluginName];
    path = [path stringByAppendingPathExtension:@"hgs"];
    if (!delegate) {
      delegate = [[[HGSUnitTestingDelegate alloc] initWithPath:path] autorelease];
    }
    BOOL didLoad = [HGSUnitTestingPluginLoader loadPluginWithDelegate:delegate];
    STAssertTrue(didLoad, @"Unable to load %@", path);
    HGSExtensionPoint *extensionPoint 
      = [HGSExtensionPoint pointWithIdentifier:extensionPointID];
    STAssertNotNil(extensionPoint, 
                   @"Unable to get extensionpoint %@", extensionPointID);
    extension = [extensionPoint extensionWithIdentifier:identifier];
  }
  STAssertNotNil(extension, @"Unable to get extension %@ from %@ on %@", 
                 identifier, pluginName, extensionPointID);
  [loadedExtensions_ addObject:extension];
  return extension;
}

- (void)testDisplayName {
  STAssertNotNil([[self extension] displayName], nil);
}

@end

@implementation HGSSearchSourceAbstractTestCase
@dynamic source;

- (id)initWithInvocation:(NSInvocation *)invocation
             pluginNamed:(NSString *)pluginName 
     extensionIdentifier:(NSString *)identifier {
  return [super initWithInvocation:invocation 
                       pluginNamed:pluginName 
               extensionIdentifier:identifier 
          extensionPointIdentifier:kHGSSourcesExtensionPoint];
}

- (HGSSearchSource *)source {
  return [self extension];
}

// Must be overridden by subclasses.
- (NSArray *)archivableResults {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)testArchiving {
  HGSSearchSource *source = [self source];
  if (![source cannotArchive]) {
    NSArray *results = [self archivableResults];
    for (HGSResult *result in results) {
      NSDictionary *archive = [source archiveRepresentationForResult:result];
      STAssertNotNil(archive, nil);
      HGSResult *thawedResult = [source resultWithArchivedRepresentation:archive];
      STAssertTrue([result isDuplicate:thawedResult], 
                   @"result: %@ thawedResult: %@", result, thawedResult);
    }
    
    // Expected failures
    HGSResult *tempResult = [source resultWithArchivedRepresentation:nil];
    STAssertNil(tempResult, nil);
    tempResult 
      = [source resultWithArchivedRepresentation:[NSDictionary dictionary]];
    STAssertNil(tempResult, nil);
    
    NSDictionary *archive = [source archiveRepresentationForResult:nil];
    STAssertNil(archive, nil);
  }
}

@end

@implementation HGSActionAbstractTestCase
@dynamic action;

- (id)initWithInvocation:(NSInvocation *)invocation
             pluginNamed:(NSString *)pluginName 
     extensionIdentifier:(NSString *)identifier {
  return [super initWithInvocation:invocation 
                       pluginNamed:pluginName 
               extensionIdentifier:identifier 
          extensionPointIdentifier:kHGSActionsExtensionPoint];
}

- (HGSAction *)action {
  return [self extension];
}

@end

@implementation HGSUnitTestingSource

+ (id)sourceWithBundle:(NSBundle *)bundle {
  return [[[self alloc] initWithBundle:bundle] autorelease];
}

- (id)initWithBundle:(NSBundle *)bundle {
  HGSExtensionPoint *sp = [HGSExtensionPoint sourcesPoint];
  NSString *identifier 
    = [[bundle bundlePath] stringByAppendingString:@".HGSUnitTestingSource"];
  HGSExtension *ext = [sp extensionWithIdentifier:identifier];
  if (ext) {
    [self release];
    self = [ext retain];
  } else {
    NSDictionary *config 
      = [NSDictionary dictionaryWithObjectsAndKeys:
         bundle, kHGSExtensionBundleKey,
         identifier, kHGSExtensionIdentifierKey,
         identifier, kHGSExtensionUserVisibleNameKey,
         nil];
    self = [super initWithConfiguration:config];
    if (self) {
      [sp extendWithObject:self];
    }
  }
  return self;
}

@end

