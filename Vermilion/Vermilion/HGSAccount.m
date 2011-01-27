//
//  HGSAccount.m
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

#import "HGSAccount.h"
#import "HGSAccountType.h"
#import "HGSBundle.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSGoogleAccountTypes.h"
#import "HGSAccountsExtensionPoint.h"
#import "HGSLog.h"
#import "HGSKeychainItem.h"


// The version of the preferences data stored in the dictionary (NSNumber).
NSString *const kHGSAccountsPrefVersionKey 
  = @"HGSAccountsPrefVersionKey";

// Account versions
NSInteger const kHGSAccountsPrefVersion0 = 0;
NSInteger const kHGSAccountsPrefCurrentVersion = 1;

NSString *const kHGSAccountDisplayNameFormat = @"%@ (%@)";
NSString *const kHGSAccountIdentifierFormat = @"%@.%@";

@interface HGSAccount ()

@property (nonatomic, copy) NSString *userName;

@end


@implementation HGSAccount

@synthesize userName = userName_;
@synthesize authenticated = authenticated_;

- (id)initWithName:(NSString *)userName {
  if ([userName length]) {
    // NOTE: The following call to -[type] resolves to a constant string
    // defined per-class.
    NSString *accountTypeIdentifier = [self type];
    HGSExtensionPoint *accountTypesPoint = [HGSExtensionPoint accountTypesPoint];
    HGSAccountType *accountType
      = [accountTypesPoint extensionWithIdentifier:accountTypeIdentifier];
    HGSProtoExtension *protoAccountType = [accountType protoExtension];
    NSString *accountTypeName
      = [protoAccountType objectForKey:kHGSExtensionUserVisibleNameKey];
    NSString *name = [NSString stringWithFormat:kHGSAccountDisplayNameFormat,
                      userName, accountTypeName];
    NSString *identifier
      = [NSString stringWithFormat:kHGSAccountIdentifierFormat, 
         accountTypeIdentifier, userName];
    NSBundle *bundle = HGSGetPluginBundle();
    NSDictionary *configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                                   userName, kHGSAccountUserNameKey,
                                   name, kHGSExtensionUserVisibleNameKey,
                                   identifier, kHGSExtensionIdentifierKey,
                                   bundle, kHGSExtensionBundleKey,
                                   nil];
    if ((self = [super initWithConfiguration:configuration])) {
      userName_ = [userName copy];
      if (!userName_ || ![self type]) {
        HGSLog(@"HGSAccounts require a userName and type.");
        [self release];
        self = nil;
      }
    }
  } else {
    [self release];
    self = nil;
  }
  return self;
}

- (id)initWithConfiguration:(NSDictionary *)prefDict {
  // See if this configuration is up-to-date.
  if (prefDict) {
    prefDict = [HGSAccount upgradeConfiguration:prefDict];
  }
  if (prefDict) {
    NSString *userName = [prefDict objectForKey:kHGSAccountUserNameKey];
    if ([userName length]) {
      NSString *accountTypeIdentifier = [prefDict objectForKey:kHGSAccountTypeKey];
      NSString *name = [prefDict objectForKey:kHGSExtensionUserVisibleNameKey];
      NSString *identifier = [prefDict objectForKey:kHGSExtensionIdentifierKey];
      NSBundle *bundle = [prefDict objectForKey:kHGSExtensionBundleKey];
      if (!name || !identifier || !bundle) {
        NSMutableDictionary *configuration
          = [NSMutableDictionary dictionaryWithDictionary:prefDict];
        if (!name) {
          HGSExtensionPoint *accountTypesPoint
            = [HGSExtensionPoint accountTypesPoint];
          HGSAccountType *accountType
            = [accountTypesPoint extensionWithIdentifier:accountTypeIdentifier];
          HGSProtoExtension *protoAccountType = [accountType protoExtension];
          NSString *accountTypeName
            = [protoAccountType objectForKey:kHGSExtensionUserVisibleNameKey];
          name = [NSString stringWithFormat:kHGSAccountDisplayNameFormat,
                  userName, accountTypeName];
          [configuration setObject:name forKey:kHGSExtensionUserVisibleNameKey];
        }
        if (!identifier) {
          identifier = [NSString stringWithFormat:kHGSAccountIdentifierFormat, 
                        accountTypeIdentifier, userName];
          [configuration setObject:identifier forKey:kHGSExtensionIdentifierKey];
        }
        if (!bundle) {
          bundle = HGSGetPluginBundle();
          if (!bundle) {
            // COV_NF_START
            HGSLog(@"HGSAccounts require bundle.");
            [self release];
            return nil;
            // COV_NF_END
          }
          [configuration setObject:bundle forKey:kHGSExtensionBundleKey];
        }
        prefDict = configuration;
      }
      if ((self = [super initWithConfiguration:prefDict])) {
        userName_ = [userName copy];
        if (![self type]) {
          HGSLog(@"HGSAccounts require an account type.");
          [self release];
          self = nil;
        }
      }
    } else {
      HGSLog(@"HGSAccounts require a userName and type.");
      [self release];
      self = nil;
    }
  } else {
    HGSLog(@"Bad or missing account configuration.");
    [self release];
    self = nil;
  }
  return self;
}

- (id)init {
  self = [self initWithName:nil];
  return self;
}

- (NSDictionary *)configuration {
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  NSDictionary *accountDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               [self userName], kHGSAccountUserNameKey,
                               [self type], kHGSAccountTypeKey,
                               versionNumber, kHGSAccountsPrefVersionKey,
                               nil];
  return accountDict;
}

- (void) dealloc {
  [userName_ release];
  [super dealloc];
}

- (NSString *)type {
  HGSAssert(NO, @"Must be overridden by subclass");
  return nil;
}

- (NSString *)password {
  return nil;
}

- (void)setPassword:(NSString *)password {
  NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
  [defaultCenter postNotificationName:kHGSAccountDidChangeNotification 
                               object:self];
}

- (void)remove {
  // Remove the account extension.
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kHGSAccountWillBeRemovedNotification object:self];
  HGSExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
  [accountsPoint removeExtension:self];
}

- (BOOL)isEditable {
  return YES;
}

- (void)authenticate {
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@:%p account='%@', type='%@'>",
          [self class], self, [self userName], [self type]];
}

+ (NSDictionary *)upgradeConfiguration:(NSDictionary *)configuration {
  NSNumber *versionNumber
    = [configuration valueForKey:kHGSAccountsPrefVersionKey];
  NSInteger version = [versionNumber integerValue];
  if (!versionNumber || version != kHGSAccountsPrefCurrentVersion) {
    // The configuration is NOT of the latest version.
    NSMutableDictionary *upgradedAccount = nil;
    if (version == 0) {
      // For version 0: convert the account type and update the keychain.
      NSString *oldAccountType = [configuration objectForKey:kHGSAccountTypeKey];
      NSString *newAccountType = nil;
      NSString *oldKeychainPrefix = nil;
      if ([oldAccountType isEqualToString:@"GoogleAccount"]) {
        newAccountType = kHGSGoogleAccountType;
        oldKeychainPrefix = @"com.google.qsb.GoogleAccount";
      } else if ([oldAccountType isEqualToString:@"GoogleAppsAccount"]) {
        newAccountType = kHGSGoogleAppsAccountType;
        oldKeychainPrefix = @"com.google.qsb.GoogleAppsAccount";
      } else if ([oldAccountType isEqualToString:@"TwitterAccount"]) {
        newAccountType = @"com.google.qsb.twitter.account";
        oldKeychainPrefix = @"com.google.qsb.TwitterAccount";
      }
      if (newAccountType) {
        upgradedAccount
          = [NSMutableDictionary dictionaryWithDictionary:configuration];
        [upgradedAccount setObject:newAccountType forKey:kHGSAccountTypeKey];
        // Retrieve the old keychain entry.
        NSString *userName = [configuration objectForKey:kHGSAccountUserNameKey];
        NSString *keychainServiceName = [NSString stringWithFormat:@"%@.%@",
                                         oldKeychainPrefix, userName];
        HGSKeychainItem *keychainItem
          = [HGSKeychainItem keychainItemForService:keychainServiceName 
                                           username:userName];
        if (keychainItem) {
          NSString *password = [keychainItem password];
          [keychainItem removeFromKeychain];
          keychainServiceName = [NSString stringWithFormat:@"%@.%@",
                                 newAccountType, userName];
          [HGSKeychainItem addKeychainItemForService:keychainServiceName
                                        withUsername:userName
                                            password:password]; 
        }
      }
      NSNumber *updatedVersionNumber
        = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
      [upgradedAccount setObject:updatedVersionNumber
                          forKey:kHGSAccountsPrefVersionKey];

    } else {
      HGSLog(@"Failed to upgrade account from version %d, account description: %@",
             version, configuration);
    }
    configuration = upgradedAccount;
  }
  return configuration;
}

@end


NSString *const kHGSAccountDidChangeNotification
  = @"HGSAccountDidChangeNotification";
NSString *const kHGSAccountWillBeRemovedNotification
  = @"HGSAccountWillBeRemovedNotification";

NSString *const kHGSAccountUserNameKey = @"HGSAccountUserNameKey";
NSString *const kHGSAccountTypeKey = @"HGSAccountTypeKey";
