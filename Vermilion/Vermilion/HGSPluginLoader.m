//
//  HGSPluginLoader.m
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

#import "HGSPluginLoader.h"
#import <GTM/GTMObjectSingleton.h>
#import <GTM/NSString+SymlinksAndAliases.h>
#import <GTM/GTMMethodCheck.h>
#import "HGSCoreExtensionPoints.h"
#import "HGSDelegate.h"
#import "HGSLog.h"
#import "HGSPlugin.h"

@interface HGSPluginLoader()
// Returns an array containing the full paths for all bundles
// found within the given plugin's path.
+ (NSArray *)bundlePathsForPluginPath:(NSString *)pluginPath;
- (void)loadPluginsAtPath:(NSString*)pluginsPath 
                sdefPaths:(NSMutableArray *)sdefPaths
                   errors:(NSArray **)errors;
@end

NSString *const kHGSPluginLoaderPluginPathKey
  = @"HGSPluginLoaderPluginPathKey";
NSString *const kHGSPluginLoaderPluginFailureKey
  = @"HGSPluginLoaderPluginFailureKey";
NSString *const kHGSPluginLoaderPluginFailedAPICheck
  = @"HGSPluginLoaderPluginFailedAPICheck";
NSString *const kHGSPluginLoaderPluginFailedInstantiation
  = @"HGSPluginLoaderPluginFailedInstantiation";
NSString *const kHGSPluginLoaderPluginFailedUnknownPluginType 
  = @"HGSPluginLoaderPluginFailedUnknownPluginType";
NSString *const kHGSPluginLoaderWillLoadPluginsNotification
  = @"HGSPluginLoaderWillLoadPluginsNotification";
NSString *const kHGSPluginLoaderDidLoadPluginsNotification
  = @"HGSPluginLoaderDidLoadPluginsNotification";
NSString *const kHGSPluginLoaderWillLoadPluginNotification
  = @"HGSPluginLoaderWillLoadPluginNotification";
NSString *const kHGSPluginLoaderDidLoadPluginNotification
  = @"HGSPluginLoaderDidLoadPluginNotification";
NSString *const kHGSPluginLoaderPluginKey
  = @"HGSPluginLoaderPluginKey";
NSString *const kHGSPluginLoaderPluginNameKey
  = @"HGSPluginLoaderPluginNameKey";
NSString *const kHGSPluginLoaderErrorKey
  = @"HGSPluginLoaderErrorKey";
NSString *const kHGSPluginLoaderDidInstallPluginsNotification
  = @"HGSPluginLoaderDidInstallPluginsNotification";
NSString *const kHGSPluginLoaderDidInstallPluginNotification
  = @"HGSPluginLoaderDidInstallPluginNotification";
NSString *const kHGSPluginLoaderWillInstallPluginNotification
  = @"HGSPluginLoaderWillInstallPluginNotification";

@implementation HGSPluginLoader

GTMOBJECT_SINGLETON_BOILERPLATE(HGSPluginLoader, sharedPluginLoader);
GTM_METHOD_CHECK(NSString, stringByResolvingSymlinksAndAliases);

@synthesize delegate = delegate_;
@synthesize plugins = plugins_;
@synthesize pluginsSDEFPaths = pluginsSDEFPaths_;

- (id)init {
  if ((self = [super init])) {
    extensionMap_ = [[NSMutableDictionary alloc] init];
  }
  return self;
}

// COV_NF_START
// Singleton, so never called.
- (void)dealloc {
  [extensionMap_ release];
  [plugins_ release];
  [super dealloc];
}
// COV_NF_END

+ (NSArray *)bundlePathsForPluginPath:(NSString *)pluginPath {
  NSMutableArray *bundlePaths = nil;
  BOOL isDirectory;
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:pluginPath isDirectory:&isDirectory]) {
    BOOL isPackage = NO;
    if (isDirectory) {
      isPackage
        = [[NSWorkspace sharedWorkspace] isFilePackageAtPath:pluginPath];
    }
    id fileEnum
      = (isDirectory && !isPackage)
        ? [[NSFileManager defaultManager] enumeratorAtPath:pluginPath]
        : [NSArray arrayWithObject:pluginPath];
    for (NSString *path in fileEnum) {
      NSString* fullPath = nil;
      if (isDirectory && !isPackage) {
        [fileEnum skipDescendents];
        fullPath = [pluginPath stringByAppendingPathComponent:path];
      } else {
        fullPath = path;
      }
      if (!bundlePaths) {
        bundlePaths = [NSMutableArray arrayWithObject:fullPath];
      } else {
        [bundlePaths addObject:fullPath];
      }
    }
  }
  return bundlePaths;
}

- (void)loadPluginsWithErrors:(NSArray **)errors {
  NSArray *pluginPaths = [[self delegate] pluginFolders];
  NSMutableArray *allErrors = nil;
  NSMutableArray *sdefPaths = [NSMutableArray array];
  
  for (NSString *pluginPath in pluginPaths) {
    NSArray *pluginErrors = nil;
    [self loadPluginsAtPath:pluginPath sdefPaths:sdefPaths errors:&pluginErrors];
    if (pluginErrors) {
      if (!allErrors) {
        allErrors = [NSMutableArray array];
      }
      [allErrors addObjectsFromArray:pluginErrors];
    }
  }
  if (errors) {
    *errors = allErrors;
  }
  HGSExtensionPoint *pluginsPoint = [HGSExtensionPoint pluginsPoint];
  NSArray *factorablePlugins = [pluginsPoint extensions];
  
  // Installing extensions is done in this order:
  //   1. Install account type extensions.
  //   2. Install previously setup accounts from our preferences.  This 
  //      step relies on the account types having been installed in Step 1.
  //      This needs to be done before you call.
  //      -installAndEnablePluginsBasedOnPluginsState
  //   3. Factor all factorable extensions.  This step relies on accounts
  //      having been reconstituted in Step 2.
  //   4. Install all non-account type extensions.
  
  // Step 1: Install the account type extensions.
  [factorablePlugins makeObjectsPerformSelector:@selector(installAccountTypes)];
  
  [self setPlugins:factorablePlugins];
  pluginsSDEFPaths_ = [sdefPaths retain];
}

- (void)installAndEnablePluginsBasedOnPluginsState:(NSArray *)state {
  NSArray *plugins = [self plugins];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  // Step 3: Factor the new extensions now that we know all available accounts.
  [plugins makeObjectsPerformSelector:@selector(factorProtoExtensions)];
  
  // Step 4: Go through our plugins and set enabled states based on what
  // the user has saved off in their prefs.
  for (HGSPlugin *plugin in plugins) {
    NSString *pluginIdentifier = [plugin identifier];
    NSDictionary *oldPluginDict = nil;
    for (oldPluginDict in state) {
      NSString *oldID = [oldPluginDict objectForKey:kHGSBundleIdentifierKey];
      if ([oldID isEqualToString:pluginIdentifier]) {
        break;
      }
    }
    // If a user has turned off a plugin, then all extensions associated
    // with that plugin are turned off. New plugins are on by default.
    BOOL pluginEnabled = YES;
    if (oldPluginDict) {
      pluginEnabled 
        = [[oldPluginDict objectForKey:kHGSPluginEnabledKey] boolValue];
    }
    [plugin setEnabled:pluginEnabled];
    
    // Now run through all the extensions in the plugin. Due to us moving
    // code around an extension may have moved from one plugin to another.
    // So even though we found a matching plugin above, we will search
    // through all the plugins looking for a match.
    NSArray *protoExtensions = [plugin protoExtensions];
    for (HGSProtoExtension *protoExtension in protoExtensions) {
      BOOL protoExtensionEnabled = YES;
      NSString *protoExtensionID = [protoExtension identifier];
      NSDictionary *oldExtensionDict = nil;
      for (oldPluginDict in state) {
        NSArray *oldExtensionDicts 
          = [oldPluginDict objectForKey:kHGSPluginExtensionsDicts];
        for (oldExtensionDict in oldExtensionDicts) {
          NSString *oldID 
            = [oldExtensionDict objectForKey:kHGSExtensionIdentifierKey];
          if ([oldID isEqualToString:protoExtensionID]) {
            protoExtensionEnabled 
               = [[oldExtensionDict objectForKey:kHGSExtensionEnabledKey] boolValue];
            break;
          }
        }
        if (oldExtensionDict) break;
      }
      // Due to us moving code around, an extension may have moved from one
      // plugin to another
      if ((!state || oldExtensionDict) && pluginEnabled) {
        [protoExtension setEnabled:protoExtensionEnabled];
      }
    }
    if ([plugin isEnabled]) {
      NSDictionary *userInfo 
        = [NSDictionary dictionaryWithObject:plugin 
                                      forKey:kHGSPluginLoaderPluginKey];
      [nc postNotificationName:kHGSPluginLoaderWillInstallPluginNotification
                        object:self
                      userInfo:userInfo];
      [plugin install];
      [nc postNotificationName:kHGSPluginLoaderDidInstallPluginNotification
                        object:self
                      userInfo:userInfo];
      
    }
  }
  [nc postNotificationName:kHGSPluginLoaderDidInstallPluginsNotification 
                    object:self];
}

- (NSArray *)pluginsState {
  // Save these plugins in preferences. All we care about at this point is
  // the enabled state of the plugin and it's extensions.
  NSArray *plugins = [self plugins];
  NSUInteger count = [plugins count];
  NSMutableArray *archivablePlugins = [NSMutableArray arrayWithCapacity:count];
  for (HGSPlugin *plugin in plugins) {
    NSArray *protoExtensions = [plugin protoExtensions];
    count = [protoExtensions count];
    NSMutableArray *archivableExtensions = [NSMutableArray arrayWithCapacity:count];
    for (HGSProtoExtension *protoExtension in protoExtensions) {
      NSNumber *isEnabled = [NSNumber numberWithBool:[protoExtension isEnabled]];
      NSString *identifier = [protoExtension identifier];
      NSDictionary *protoValues = [NSDictionary dictionaryWithObjectsAndKeys:
                                   identifier, kHGSExtensionIdentifierKey,
                                   isEnabled, kHGSExtensionEnabledKey,
                                   nil];
      [archivableExtensions addObject:protoValues];
    }
    NSNumber *isEnabled = [NSNumber numberWithBool:[plugin isEnabled]];
    NSString *identifier = [plugin identifier];
    NSDictionary *archiveValues
      = [NSDictionary dictionaryWithObjectsAndKeys:
         identifier, kHGSBundleIdentifierKey,
         isEnabled, kHGSPluginEnabledKey,
         archivableExtensions, kHGSPluginExtensionsDicts,
         nil];
    [archivablePlugins addObject:archiveValues];
  }
  return archivablePlugins;
}

- (void)loadPluginsAtPath:(NSString*)pluginPath 
                sdefPaths:(NSMutableArray *)sdefPaths
                   errors:(NSArray **)errors {
  NSArray *bundlePaths = [HGSPluginLoader bundlePathsForPluginPath:pluginPath];
  if ([bundlePaths count]) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kHGSPluginLoaderWillLoadPluginsNotification 
                      object:self 
                    userInfo:nil];
    NSMutableArray *ourErrors = [NSMutableArray array];
    for (NSString *fullPath in bundlePaths) {
      NSString *errorType = nil;
      NSString *extension = [fullPath pathExtension];
      Class pluginClass = [extensionMap_ objectForKey:extension];
      NSString *pluginName = [fullPath lastPathComponent];
      HGSPlugin *plugin = nil;
      if (pluginClass) {
        fullPath = [fullPath stringByResolvingSymlinksAndAliases];
        NSBundle *pluginBundle = [NSBundle bundleWithPath:fullPath];
        // Get the name.
        NSString *betterPluginName 
          = [pluginBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"];
        if (!betterPluginName) {
          betterPluginName 
            = [pluginBundle objectForInfoDictionaryKey:@"CFBundleName"];
        }
        if (betterPluginName) {
          pluginName = betterPluginName;
        }
        NSDictionary *willLoadUserInfo 
          = [NSDictionary dictionaryWithObject:pluginName 
                                        forKey:kHGSPluginLoaderPluginNameKey];
        [nc postNotificationName:kHGSPluginLoaderWillLoadPluginNotification
                          object:self 
                        userInfo:willLoadUserInfo];
        if ([pluginClass isPluginBundleValidAPI:pluginBundle]) {
          plugin 
            = [[[pluginClass alloc] initWithBundle:pluginBundle] autorelease];
          if (plugin) {
            HGSExtensionPoint *pluginsPoint = [HGSExtensionPoint pluginsPoint];
            [pluginsPoint extendWithObject:plugin];
            // Is it scriptable?
            BOOL pluginScriptable 
              = [[pluginBundle objectForInfoDictionaryKey:@"NSAppleScriptEnabled"]
                 boolValue];
            if (pluginScriptable) {
              // Does it have any sdefs?
              NSArray *sdefResourcePaths
                = [pluginBundle pathsForResourcesOfType:@"sdef" inDirectory:nil];
              if (sdefResourcePaths) {
                [sdefPaths addObjectsFromArray:sdefResourcePaths];
              }
            }
          } else {
            errorType = kHGSPluginLoaderPluginFailedInstantiation;
          }
        } else {
          errorType = kHGSPluginLoaderPluginFailedAPICheck;
        }
      } else {
        errorType = kHGSPluginLoaderPluginFailedUnknownPluginType;
      }
      NSDictionary *errorDictionary = nil;
      if (errorType) {
        errorDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                           errorType, kHGSPluginLoaderPluginFailureKey,
                           fullPath, kHGSPluginLoaderPluginPathKey,
                           nil];
        [ourErrors addObject:errorDictionary];
      }
      NSMutableDictionary *didLoadUserInfo 
        = [NSMutableDictionary dictionaryWithObject:pluginName
                                             forKey:kHGSPluginLoaderPluginNameKey];
      if (plugin) {
        [didLoadUserInfo setObject:plugin forKey:kHGSPluginLoaderPluginKey];
      }
      if (errorDictionary) {
        [didLoadUserInfo setObject:errorDictionary 
                            forKey:kHGSPluginLoaderErrorKey];
      }
      [nc postNotificationName:kHGSPluginLoaderDidLoadPluginNotification 
                        object:self 
                      userInfo:didLoadUserInfo];
    }
    NSDictionary *didLoadsUserInfo = nil;
    if ([ourErrors count]) {
      didLoadsUserInfo 
        = [NSDictionary dictionaryWithObject:ourErrors 
                                      forKey:kHGSPluginLoaderErrorKey];
    }
    [nc postNotificationName:kHGSPluginLoaderDidLoadPluginsNotification 
                      object:self 
                    userInfo:didLoadsUserInfo];
    
    if (errors) {
      *errors = [ourErrors count] ? ourErrors : nil;
    }  
  }
}

- (void)registerClass:(Class)cls forExtensions:(NSArray *)extensions {
  for (id extension in extensions) {
    #if DEBUG
    Class oldCls = [extensionMap_ objectForKey:extension];
    if (oldCls) {
      HGSLogDebug(@"Replacing %@ with %@ for extension %@", 
                  NSStringFromClass(oldCls), NSStringFromClass(cls), extension);
    }
    #endif
    [extensionMap_ setObject:cls forKey:extension];
  }
}

@end
