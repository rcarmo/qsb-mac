//
//  HGSPlugin.m
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

#import "HGSPlugin.h"
#import "HGSAccount.h"
#import "HGSAccountsExtensionPoint.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSLog.h"
#import "HGSPluginLoader.h"
#import "HGSProtoExtension.h"

// Array of Cocoa extension descriptions.
NSString *const kHGSExtensionsKey = @"HGSExtensions";
// NSNumber (BOOL) indicating if plugin is enabled (master switch).
NSString *const kHGSPluginEnabledKey = @"HGSPluginEnabled";
// Array containing dictionaries describing the extensions of this plugin.
NSString *const kHGSPluginExtensionsDicts = @"HGSPluginExtensionsDicts";

NSString *const kHGSBundleIdentifierKey = @"HGSBundleIdentifier";

static NSString *const kHGSPluginAPIVersionKey 
  = @"HGSPluginAPIVersion";

@interface HGSPlugin ()

// Respond to new accounts being added by factoring our extension.
- (void)addProtoExtensionForAccount:(NSNotification *)notification;

// Add extension(s) to our instantiated protoExtensions.
- (void)addProtoExtensions:(NSArray *)protoExtensions
                   install:(BOOL)install;

@property (nonatomic, retain, readwrite) NSArray *protoExtensions;

@end


@implementation HGSPlugin

@synthesize protoExtensions = protoExtensions_;
@synthesize enabled = enabled_;

// TODO(mrossetti): Move this and extensionsWithType: up into QSB.
+ (NSSet *)keyPathsForValuesAffectingSourceExtensions {
  return [NSSet setWithObject:@"protoExtensions"];
}

+ (NSSet *)keyPathsForValuesAffectingActionExtensions {
  return [NSSet setWithObject:@"protoExtensions"];
}

+ (NSSet *)keyPathsForValuesAffectingServiceExtensions {
  return [NSSet setWithObject:@"protoExtensions"];
}

+ (NSSet *)keyPathsForValuesAffectingAccountTypeExtensions {
  return [NSSet setWithObject:@"protoExtensions"];
}

+ (void)load {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  HGSPluginLoader *loader = [HGSPluginLoader sharedPluginLoader];
  [loader registerClass:self forExtensions:[NSArray arrayWithObject:@"hgs"]];
  [pool release];
}


+ (BOOL)isPluginBundleValidAPI:(NSBundle *)pluginBundle {
  NSNumber *pluginAPIVersion
    = [pluginBundle objectForInfoDictionaryKey:kHGSPluginAPIVersionKey];
  if (!pluginAPIVersion) {
    NSString *qsbPlistPath = [pluginBundle pathForResource:@"QSBInfo" 
                                                    ofType:@"plist"];
    if (qsbPlistPath) {
      NSDictionary *qsbPlist 
        = [NSDictionary dictionaryWithContentsOfFile:qsbPlistPath];
      pluginAPIVersion = [qsbPlist objectForKey:kHGSPluginAPIVersionKey];
    }
  }
  return [pluginAPIVersion intValue] == VERMILLION_PLUGIN_API_VERSION;
}

- (id)init {
  return [self initWithBundle:nil];
}

- (id)initWithBundle:(NSBundle *)bundle {
  if (!bundle) {
    [self release];
    return nil;
  }
  
  NSDictionary *configuration 
    = [NSDictionary dictionaryWithObject:bundle 
                                  forKey:kHGSExtensionBundleKey];
  if ((self = [super initWithConfiguration:configuration])) {
    NSMutableArray *protoExtensions = [NSMutableArray array];
    
    // Discover all plist based extensions
    NSArray *standardExtensions
      = [self objectForInfoDictionaryKey:kHGSExtensionsKey];
    factorableProtoExtensions_ = [[NSMutableArray array] retain];
    for (NSDictionary *extensionConfig in standardExtensions) {
      HGSProtoExtension *extension
        = [[[HGSProtoExtension alloc] initWithConfiguration:extensionConfig
                                                     plugin:self]
         autorelease];
      if (extension) {
        if ([extension isFactorable]) {
          // Factor this extension right now, if factors are available.
          NSArray *factoredExtensions = [extension factor];
          [protoExtensions addObjectsFromArray:factoredExtensions];
          
          // Then remember this factorable extension in case new factors
          // show up later.
          [factorableProtoExtensions_ addObject:extension];
        } else {
          // Not factorable so just add the extension.
          [protoExtensions addObject:extension];
        }
      } 
    } 
    
    BOOL hasExtensions = NO;
    if ([protoExtensions count]) {
      [self setProtoExtensions:protoExtensions];
      hasExtensions = YES;
    }
    if ([factorableProtoExtensions_ count]) {
      hasExtensions = YES;
    }
    if (!hasExtensions) {
      HGSLog(@"No standard extensions or factorable extensions found "
             @"in plugin at path %@.", [bundle bundlePath]);
      [self release];
      return nil;
    }
    // TODO(mrossetti): Reconsider this policy.
    // Automatically enable newly discovered plugins.
    enabled_ = YES;  // Do not use the setter.
  }
  return self;
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [protoExtensions_ release];
  [factorableProtoExtensions_ release];
  [super dealloc];
}

- (void)setEnabled:(BOOL)isEnabled {
  if ([self isEnabled] != isEnabled) {
    enabled_ = isEnabled;
    // Install/enable or disable the plugin.
    if (isEnabled) {
      [self install];
    } else {
      [self uninstall];
    }
    
    // Signal that the plugin's enabling setting has changed.
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center postNotificationName:kHGSPluginDidChangeEnabledNotification
                          object:self];
  }
}

- (void)factorProtoExtensions {
  NSMutableArray *factoredExtensions
    = [NSMutableArray arrayWithCapacity:[factorableProtoExtensions_ count]];
  for (HGSProtoExtension *factorableExtension in factorableProtoExtensions_) {
    if ([factorableExtension isFactorable]) {
      NSArray *factoredProtoExtensions = [factorableExtension factor];
      [factoredExtensions addObjectsFromArray:factoredProtoExtensions];
    } else {
      [factoredExtensions addObject:factorableExtension];
    }
  }
  [self addProtoExtensions:factoredExtensions install:NO];
}

- (void)install {
  // Lock and load all enable-able sources and actions.
  for (HGSProtoExtension *protoExtension in [self protoExtensions]) {
    if ([protoExtension isEnabled]) {
      [protoExtension install];
    }
  }
  if ([factorableProtoExtensions_ count]) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    HGSExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
    [nc addObserver:self
           selector:@selector(addProtoExtensionForAccount:)
               name:kHGSExtensionPointDidAddExtensionNotification
             object:accountsPoint];
  }
}

- (void)uninstall {
  [[self protoExtensions] makeObjectsPerformSelector:@selector(uninstall)];
  if ([factorableProtoExtensions_ count]) {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    HGSExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
    [nc removeObserver:self
                  name:kHGSExtensionPointDidAddExtensionNotification
                object:accountsPoint];
  }
  [super uninstall];
}

- (NSString *)bundleIdentifier {
  return [[self bundle] bundleIdentifier];
}

- (void)removeProtoExtension:(HGSProtoExtension *)protoExtension {
  [protoExtension uninstall];
  
  // The proto extension will be released when removed from the array so
  // hold on to it through this cycle.
  [[protoExtension retain] autorelease];
  
  NSArray *oldProtoExtensions = [self protoExtensions];
  NSMutableArray *newProtoExtensions 
    = [NSMutableArray arrayWithArray:oldProtoExtensions];
  [newProtoExtensions removeObject:protoExtension];
  [self setProtoExtensions:newProtoExtensions];
}

- (void)installAccountTypes {
  NSArray *accountTypeProtoExtensions = [self accountTypeExtensions];
  [accountTypeProtoExtensions makeObjectsPerformSelector:@selector(install)];
}

// TODO(mrossetti): Move this and convenience functions following up into QSB.
- (NSArray *)extensionsWithType:(NSString *)type {
  NSArray *filteredExtensions = [self protoExtensions];
  NSPredicate *pred
    = [NSPredicate predicateWithFormat:@"extensionPointKey == %@", type];
  filteredExtensions = [filteredExtensions filteredArrayUsingPredicate:pred];
  return filteredExtensions;
}

- (NSArray *)sourceExtensions {
  return [self extensionsWithType:kHGSSourcesExtensionPoint];
}

- (NSArray *)actionExtensions {
  return [self extensionsWithType:kHGSActionsExtensionPoint];
}

- (NSArray *)serviceExtensions {
  return [self extensionsWithType:kHGSServicesExtensionPoint];
}

- (NSArray *)accountTypeExtensions {
  return [self extensionsWithType:kHGSAccountTypesExtensionPoint];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p %@ enabled=%d>",
          [self class], self, [self displayName], [self isEnabled]];
}

- (void)addProtoExtensionForAccount:(NSNotification *)notification {
  // See if any of our factorable extensions are interested in a newly
  // added account and, if so, add them to our sources.
  NSDictionary *userInfo = [notification userInfo];
  HGSAccount *account = [userInfo objectForKey:kHGSExtensionKey];
  // Only factor for accounts with a userName.
  NSString *userName = [account userName];
  // TODO(mrossetti): The following will not be required once we refactor
  // accounts and account types.  This is a temporary work-around.
  if ([userName length]) {
    NSMutableArray *newExtensions = [NSMutableArray array];
    for (HGSProtoExtension *factorableExtension in factorableProtoExtensions_) {
      HGSProtoExtension *newProtoExtension
        = [factorableExtension factorForAccount:account];
      if (newProtoExtension) {
        [newExtensions addObject:newProtoExtension];
      }
    }
    [self addProtoExtensions:newExtensions install:YES];
  }
}

- (void)addProtoExtensions:(NSArray *)protoExtensions
                   install:(BOOL)install {
  NSArray *oldProtoExtensions = [self protoExtensions];
  NSArray *newProtoExtensions = nil;
  if (oldProtoExtensions) {
    newProtoExtensions
      = [oldProtoExtensions arrayByAddingObjectsFromArray:protoExtensions];
  } else {
    newProtoExtensions = [NSArray arrayWithArray:protoExtensions];
  }
  [self setProtoExtensions:newProtoExtensions];
  
  // Install all of the enabled new extensions.
  if (install) {
    for (HGSProtoExtension *newProtoExtension in protoExtensions) {
      if ([newProtoExtension isEnabled]) {
        [newProtoExtension install];
      }
    }
  }
}

@end

// Notification sent when extension has been enabled/disabled.
NSString *const kHGSPluginDidChangeEnabledNotification
  = @"HGSPluginDidChangeEnabledNotification";
