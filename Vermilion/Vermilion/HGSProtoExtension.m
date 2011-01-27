//
//  HGSProtoExtension.m
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

#import "HGSProtoExtension.h"
#import "HGSAccount.h"
#import "HGSAccountsExtensionPoint.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSExtension.h"
#import "HGSLog.h"
#import "HGSPlugin.h"
#import "HGSPythonAction.h"
#import "HGSPythonSource.h"

@interface HGSProtoExtension ()

// TODO(mrossetti): There will be other types of factors in the future so
// will need to introduce an HGSFactor protocol that supports -[identifier]
// at a minimum.
- (id)copyWithFactor:(HGSAccount *)factor
              forKey:(NSString *)key;

// Respond to the pending removal of an account by shutting down our
// extension, if any, and removing ourself from the list of sources.
- (void)willRemoveAccount:(NSNotification *)notification;

// Provide an array of the account types in which this extension is interested.
- (NSArray *)desiredAccountTypes;

@property (nonatomic, retain, readwrite) HGSExtension *extension;
@property (nonatomic, readonly) NSString *className;

// Prefs.xib KVOs plugin
@property (nonatomic, readonly) HGSPlugin *plugin;
@end


@implementation HGSProtoExtension

@synthesize extension = extension_;
@synthesize enabled = enabled_;
@synthesize plugin = plugin_;

+ (NSSet *)keyPathsForValuesAffectingKeyInstalled {
  NSSet *affectingKeys = [NSSet setWithObject:@"extension"];
  return affectingKeys;
}

+ (NSSet *)keyPathsForValuesAffectingCanSetEnabled {
  NSSet *affectingKeys = [NSSet setWithObject:@"plugin.enabled"];
  return affectingKeys;
}

- (id)init {
  self = [self initWithConfiguration:nil plugin:nil];
  return self;
}

- (id)initWithConfiguration:(NSDictionary *)configuration
                     plugin:(HGSPlugin *)plugin {
  if ((self = [super init])) {
    configuration_ 
      = [[NSMutableDictionary alloc] initWithDictionary:configuration];
    if (plugin) {
      NSBundle *pluginBundle = [plugin bundle];
      if (pluginBundle) {
        [configuration_ setObject:pluginBundle forKey:kHGSExtensionBundleKey];
        
        // TODO(mrossetti): Review this policy in light of accounts and net 
        // access.
        // Always enable new extensions.
        // Do not use mutator since we do not want the side-effects.
        enabled_ = YES;
        NSNumber *enabled 
          = [configuration objectForKey:kHGSExtensionEnabledKey];
        if (enabled) {
          enabled_ = [enabled boolValue]; 
        } else {
          enabled 
            = [configuration objectForKey:kHGSExtensionIsEnabledByDefaultKey];
          if (enabled) {
            enabled_ = [enabled boolValue];
          }
        }
        
        plugin_ = plugin;
        
        NSString *displayName 
          = [configuration_ objectForKey:kHGSExtensionUserVisibleNameKey];
        if (displayName) {
          displayName 
            = [pluginBundle qsb_localizedInfoPListStringForKey:displayName];
        }
        if (!displayName) {
          displayName = [plugin displayName];
        }
        [configuration_ setObject:displayName 
                           forKey:kHGSExtensionUserVisibleNameKey];
        
        NSString *className = [self className];
        NSString *identifier = [self identifier];
        NSString *extensionPointKey = [self extensionPointKey];
        
        if (!className || !identifier || !extensionPointKey) {
          HGSLog(@"Unable to create proto extension %@ (%@)", 
                 [self displayName], [self class]);
          [self release];
          self = nil;
        }        
      } else {
        HGSLogDebug(@"Plugin must have a bundle.");
        [self release];
        self = nil;
      }
    } else {
      HGSLogDebug(@"Plugin required.");
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [extension_ release];
  [configuration_ release];
  plugin_ = nil;
  [super dealloc];
}

- (BOOL)isFactorable {
  // We are factorable if we are looking for accounts.  
  // TODO(mrossetti): Additional types of factors may be added in the future.
  NSString *desiredAccountType
    = [configuration_ objectForKey:kHGSExtensionDesiredAccountTypesKey];
  BOOL factorsByAccount = (desiredAccountType != nil);
  return factorsByAccount;
}

- (NSArray *)factor {
  // Determine if this protoExtension should be factored and, if so,
  // create one or more factored protoextensions, otherwise return 
  // and empty array.
  // NOTE: This approach is linear, that is, it does not lend itself to
  //       an N x N expansion based on multiple factor types.
  NSMutableArray *factoredExtensions = [NSMutableArray array];
  // Create a copy of self for each account that's available.
  NSArray *desiredAccountTypes = [self desiredAccountTypes];
  for (NSString *desiredAccountType in desiredAccountTypes) {
    HGSAccountsExtensionPoint *aep = [HGSExtensionPoint accountsPoint];
    NSArray *accounts = [aep accountsForType:desiredAccountType];
    for (HGSAccount *account in accounts) {
      HGSProtoExtension *factoredExtension = [self factorForAccount:account];
      if (factoredExtension) {
        [factoredExtensions addObject:factoredExtension];
      }
    }
  }
  return factoredExtensions;
}

- (HGSProtoExtension *)factorForAccount:(HGSAccount *)account {
  HGSProtoExtension *factoredExtension = nil;
  NSString *accountType = [account type];
  NSArray *desiredAccountTypes = [self desiredAccountTypes];
  if ([desiredAccountTypes containsObject:accountType]) {
    factoredExtension = [[self copyWithFactor:account
                                       forKey:kHGSExtensionAccountKey]
                         autorelease];
    // By default we disable account-based source extensions and enable
    // account-based action extensions unless the enable state has been
    // specifically overridden in the extension's configuration.
    NSNumber *isEnabledByDefaultValue 
      = [configuration_ objectForKey:kHGSExtensionIsEnabledByDefaultKey];
    BOOL doEnable = [isEnabledByDefaultValue boolValue];
    NSString *extensionPoint = [self extensionPointKey];
    if (!isEnabledByDefaultValue
        && [extensionPoint isEqualToString:kHGSActionsExtensionPoint]) {
      doEnable = YES;
    }
    if (!doEnable || ![account isAuthenticated]) {
      // Set isEnabled_ directly--we don't want the setter side-effects.
      factoredExtension->enabled_ = NO;
    }
    
    // Register this protoExtension to receive notifications of pending
    // removal of the account so that the removal can be propogated to 
    // the extension.
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:factoredExtension
           selector:@selector(willRemoveAccount:)
               name:kHGSAccountWillBeRemovedNotification
             object:account];
  }
  return factoredExtension;
}

- (NSAttributedString *)extensionDescription {
  return [plugin_ extensionDescription];
}

- (NSString *)extensionVersion {
  return [plugin_ extensionVersion];
}

- (BOOL)canSetEnabled {
  BOOL canSet = [plugin_ isEnabled];
  if (canSet) {
    HGSAccount *account = [configuration_ objectForKey:kHGSExtensionAccountKey];
    if (account) {
      canSet = [account isAuthenticated];
    }
  }
  return canSet;
}

- (void)install {
  if ([self isInstalled]) {
    return;
  }
  
  NSDate *startDate = [NSDate date];
  NSBundle *bundle = [configuration_ objectForKey:kHGSExtensionBundleKey];
  HGSExtension *extension = nil;
  
  if ([bundle objectForInfoDictionaryKey:@"CFBundleExecutable"]) {
    // Ensure the bundle is loaded
    if (![bundle isLoaded]) {
      // TODO(dmaclach): if we move stats, python, etc. from the current
      // extension loading, we can make all plugin's not get loaded until here,
      // so we don't may costs during startup for loading and never load a code
      // bundle if it has no active sources/actions.
      if (![bundle load]) {
        HGSLog(@"Unable to load bundle %@", bundle);
        return;
      }
    }
  }
  
  // Create it now
  NSString *className = [self className];
  Class extensionPointClass = NSClassFromString(className);
  // Note that the extension class must descend from HGSExtension and should
  // provide its own implementation of initWithConfiguration: which will be
  // called by -[HGSExtension initWithConfiguration:owner:].
  if (extensionPointClass 
      && [extensionPointClass
          instancesRespondToSelector:@selector(initWithConfiguration:)]) {
    @try {
      // We have a try block here as this is a common fail place for extensions
      // and we don't want a failure to take out installing all the other
      // extensions. Since we are calling 3rd party code, we can't be sure
      // they will be kind to us.
      extension
        = [[[extensionPointClass alloc] initWithConfiguration:configuration_
                                                        owner:self] 
           autorelease];
    }
    @catch (NSException *e) {
      HGSLog(@"Unable to init extension %@ (%@)", extension, e);
    }
  } else {
    HGSLogDebug(@"No className (%@) or extensionPointClass does not respond "
                @"to -[initWithConfiguration:]", className);
  }
  if (extension) {
    NSString *extensionPointKey = [self extensionPointKey];
    if (extensionPointKey) {
      HGSExtensionPoint *point
        = [HGSExtensionPoint pointWithIdentifier:extensionPointKey];
      if ([point extendWithObject:extension]) {
        [self setExtension:extension];
      } else {
        HGSLog(@"Unable to extend %@ with %@ in %@",
               point, extension, bundle);
      }
    } else {
      HGSLogDebug(@"No extensionPointKey");
    }
  } else {
    HGSLog(@"Unable to instantiate extension %@ in %@",
           className, bundle);
  }
  NSTimeInterval loadTime = -[startDate timeIntervalSinceNow];
  if (loadTime > 0.1f) {
    HGSLogDebug(@"Loading %@ took %3.0fms", [self displayName], loadTime * 1000);
  }
}

- (void)uninstall {
  if ([self isInstalled]) {
    NSString *extensionPointKey = [self extensionPointKey];
    HGSExtensionPoint *point
      = [HGSExtensionPoint pointWithIdentifier:extensionPointKey];
    HGSExtension *extension = [self extension];
    [extension uninstall];
    [point removeExtension:extension];
    [self setExtension:nil];
  }
}

- (BOOL)isInstalled {
  return ([self extension] != nil);
}

- (void)setEnabled:(BOOL)isEnabled {
  if (enabled_ != isEnabled) {
    BOOL notify = YES;
    enabled_ = isEnabled;
    if (isEnabled) {
      [self install];
    } else if ([self isInstalled]) {
      [self uninstall];
    } else {
      // Don't signal if we aren't installed to prevent a flood of
      // notifications at startup.
      notify = NO;
    }
    if (notify) {
      // Signal that the plugin's enabling setting has changed.
      NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
      [center postNotificationName:kHGSExtensionDidChangeEnabledNotification
                            object:self];
    }
  }
}

- (NSString *)associatedAccount {
  NSString *account = nil;
  NSString *identifier = [self identifier];
  NSRange accountRange = [identifier rangeOfString:@"ACCOUNT="];
  if (accountRange.location != NSNotFound) {
    account = [identifier substringFromIndex:NSMaxRange(accountRange)];
  }
  return account;
}

- (BOOL)isUserVisibleAndExtendsExtensionPoint:(NSString *)extensionPoint {
  BOOL doesExtend = [[self extensionPointKey] isEqualToString:extensionPoint];
  if (doesExtend) {
    NSNumber *isUserVisibleValue 
      = [configuration_ objectForKey:kHGSExtensionIsUserVisibleKey];
    if (isUserVisibleValue) {
      doesExtend = [isUserVisibleValue boolValue];
    }
  }
  return doesExtend;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p isEnabled=%d, plugin=%p\n"
          @"extensionDict: %@>",
          [self class], self, [self isEnabled], plugin_, configuration_];
}

- (id)copyWithFactor:(HGSAccount *)factor
              forKey:(NSString *)key {
  NSMutableDictionary *newConfiguration 
    = [NSMutableDictionary dictionaryWithDictionary:configuration_];
  [newConfiguration setObject:factor forKey:key];
  
  NSString *factorIdentifier = [factor identifier];
  
  NSString *newIdentifier = [self identifier];
  // Recalculate the proto extension identifier.
  HGSAssert([newIdentifier rangeOfString:@"?"].length == 0, @"We shouldn't have"
            @"any other args in our identifier yet");
  newIdentifier = [newIdentifier stringByAppendingFormat:@"?ACCOUNT=%@",
                   factorIdentifier];
  [newConfiguration setObject:newIdentifier forKey:kHGSExtensionIdentifierKey];
  
  
  // Enhance the displayName.
  // TODO(mrossetti): This will get fancier and allow clicking on account
  // name in order to go to the account in the account list.
  NSString *newDisplayName = [[self displayName] stringByAppendingFormat:@" (%@)",
                              [factor displayName]];
  [newConfiguration setObject:newDisplayName 
                       forKey:kHGSExtensionUserVisibleNameKey];
  
  HGSProtoExtension *extension 
    = [[[self class] alloc] initWithConfiguration:newConfiguration
                                           plugin:plugin_];
  return extension;
}

- (NSString *)extensionPointKey {
  return [configuration_ objectForKey:kHGSExtensionPointKey];
}

- (NSString *)className {
  return [configuration_ objectForKey:kHGSExtensionClassKey];
}

- (NSString *)identifier {
  return [configuration_ objectForKey:kHGSExtensionIdentifierKey];
}

- (NSString *)displayName {
  return [configuration_ objectForKey:kHGSExtensionUserVisibleNameKey];
}

- (NSImage *)icon {
  NSImage *icon = nil;
  NSString *iconPath 
    = [configuration_ objectForKey:kHGSExtensionIconImagePathKey];
  if ([iconPath length]) {
    if (![iconPath isAbsolutePath]) {
      NSBundle *bundle = [configuration_ objectForKey:kHGSExtensionBundleKey];
      iconPath = [bundle pathForImageResource:iconPath];
    }
    icon = [[[NSImage alloc] initByReferencingFile:iconPath] autorelease];
    if (!icon) {
      HGSLogDebug(@"Unable to get image %@", iconPath);
    }
  }
  if (!icon) {
    icon = [NSImage imageNamed:@"QSBPlugin"];
  }
  return icon;
}

  
- (NSArray *)desiredAccountTypes {
  NSArray *desiredAccountTypes
    = [configuration_ objectForKey:kHGSExtensionDesiredAccountTypesKey];
  if ([desiredAccountTypes isKindOfClass:[NSString class]]) {
    desiredAccountTypes = [NSArray arrayWithObject:desiredAccountTypes];
  }
  return desiredAccountTypes;
}

- (id)objectForKey:(NSString *)configurationKey {
  return [configuration_ objectForKey:configurationKey];
}
  
#pragma mark Notification Handling

- (void)willRemoveAccount:(NSNotification *)notification {
  // Remove ourself unless our installed extension tells us otherwise.
  BOOL alsoRemoveClient = YES;
  if ([self isInstalled]) {
    // Inform our extension that the account is going away.
    HGSExtension *extension = [self extension];
    if ([extension conformsToProtocol:@protocol(HGSAccountClientProtocol)]) {
      id<HGSAccountClientProtocol> accountClient
        = (id<HGSAccountClientProtocol>)extension;
      HGSAccount *account = [notification object];
      alsoRemoveClient = [accountClient accountWillBeRemoved:account];
    } else {
      HGSLogDebug(@"Attempt to remove an account for an extension that "
                  @"does not support the HGSAccountClientProtocol. "
                  @"Extension identifier: '%@'", 
                  [self identifier]);
    }
  }
  if (alsoRemoveClient) {
    [plugin_ removeProtoExtension:self];
    // Make sure our preferences are updated.
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kHGSExtensionDidChangeEnabledNotification
                      object:self];
  }
}

@end

// Notification sent when extension has been enabled/disabled.
NSString *const kHGSExtensionDidChangeEnabledNotification
   = @"HGSExtensionDidChangeEnabledNotification";
