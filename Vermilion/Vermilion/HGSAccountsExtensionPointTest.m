//
//  HGSAccountsExtensionPointTest.m
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
#import "HGSAccount.h"
#import "HGSAccountType.h"
#import "HGSAccountsExtensionPoint.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSExtensionPoint.h"
#import "HGSPlugin.h"
#import "HGSProtoExtension.h"
#import <OCMock/OCMock.h>

#pragma mark Supporting Classes

static NSString *const kAccountTypeAID = @"com.google.qsb.testA.account";
static NSString *const kAccountTypeAClass = @"AccountTypeA";
static NSString *const kAccountTypeA = @"AccountA";
static NSString *const kAccountAClass = @"AccountA";
static NSString *const kAccountTypeAName = @"Account Type A";

@interface AccountTypeA : HGSAccountType
@end


@implementation AccountTypeA

- (NSString *)type {
  return kAccountTypeAID;
}

@end


@interface AccountA : HGSAccount
@end


@implementation AccountA

- (NSString *)type {
  return kAccountTypeAID;
}

@end

#pragma mark Test Class

@interface HGSAccountsExtensionPointTest : GTMTestCase {
 @private
  BOOL receivedAddAccountExtensionNotification_;
  BOOL receivedWillRemoveAccountExtensionNotification_;
  BOOL receivedWillRemoveAccountNotification_;
  BOOL receivedDidRemoveAccountExtensionNotification_;
  HGSAccount *expectedAccount_;
}

@property BOOL receivedAddAccountExtensionNotification;
@property BOOL receivedWillRemoveAccountNotification;
@property BOOL receivedWillRemoveAccountExtensionNotification;
@property BOOL receivedDidRemoveAccountExtensionNotification;
@property (retain) HGSAccount *expectedAccount;

- (void)removeAllAccountsAndTypes;
- (void)didAddAccountExtensionNotification:(NSNotification *)notification;
- (void)willRemoveAccountExtensionNotification:(NSNotification *)notification;
- (void)willRemoveAccountNotification:(NSNotification *)notification;
- (void)didRemoveAccountExtensionNotification:(NSNotification *)notification;

@end


@implementation HGSAccountsExtensionPointTest

@synthesize receivedAddAccountExtensionNotification
  = receivedAddAccountExtensionNotification_;
@synthesize receivedWillRemoveAccountNotification
  = receivedWillRemoveAccountNotification_;
@synthesize receivedWillRemoveAccountExtensionNotification
  = receivedWillRemoveAccountExtensionNotification_;
@synthesize receivedDidRemoveAccountExtensionNotification
  = receivedDidRemoveAccountExtensionNotification_;
@synthesize expectedAccount = expectedAccount_;

- (void)dealloc {
  [self setExpectedAccount:nil];
  [super dealloc];
}

- (void)removeAllAccountsAndTypes {
  HGSExtensionPoint *point = [HGSExtensionPoint accountTypesPoint];
  NSArray *extensions = [point extensions];
  for (HGSExtension *extension in extensions) {
    [point removeExtension:extension];
  }
  point = [HGSExtensionPoint accountsPoint];
  extensions = [point extensions];
  for (HGSExtension *extension in extensions) {
    [point removeExtension:extension];
  }
}

- (void)setExpectedAccount:(HGSAccount *)expectedAccount {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  if (expectedAccount_) {
    [expectedAccount_ release];
    [nc removeObserver:self];
  }
  if (expectedAccount) {
    expectedAccount_ = [expectedAccount retain];
    [nc addObserver:self
           selector:@selector(didAddAccountExtensionNotification:)
               name:kHGSExtensionPointDidAddExtensionNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(willRemoveAccountExtensionNotification:)
               name:kHGSExtensionPointWillRemoveExtensionNotification
             object:nil];
    // TODO(mrossetti): Clearly, we don't need the following so remove it and
    // change over all such in QSB to use above notification instead.
    [nc addObserver:self
           selector:@selector(willRemoveAccountNotification:)
               name:kHGSAccountWillBeRemovedNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(didRemoveAccountExtensionNotification:)
               name:kHGSExtensionPointDidRemoveExtensionNotification
             object:nil];
    
  }
}

- (BOOL)receivedAddAccountExtensionNotification {
  BOOL result = receivedAddAccountExtensionNotification_;
  receivedAddAccountExtensionNotification_ = NO;
  return result;
}

- (BOOL)receivedWillRemoveAccountExtensionNotification {
  BOOL result = receivedWillRemoveAccountExtensionNotification_;
  receivedWillRemoveAccountExtensionNotification_ = NO;
  return result;
}

- (BOOL)receivedWillRemoveAccountNotification {
  BOOL result = receivedWillRemoveAccountNotification_;
  receivedWillRemoveAccountNotification_ = NO;
  return result;
}

- (BOOL)receivedDidRemoveAccountExtensionNotification {
  BOOL result = receivedDidRemoveAccountExtensionNotification_;
  receivedDidRemoveAccountExtensionNotification_ = NO;
  return result;
}

#pragma mark Notification Handlers

- (void)didAddAccountExtensionNotification:(NSNotification *)notification {
  STAssertEquals([[notification object] class],
                 [HGSAccountsExtensionPoint class], nil);
  NSDictionary *userInfo = [notification userInfo];
  id notificationObject = [userInfo objectForKey:kHGSExtensionKey];
  HGSAccount *expectedAccount = [self expectedAccount];
  BOOL gotExpectedObject = (notificationObject == expectedAccount);
  [self setReceivedAddAccountExtensionNotification:gotExpectedObject];
}

- (void)willRemoveAccountExtensionNotification:(NSNotification *)notification {
  STAssertEquals([[notification object] class],
                 [HGSAccountsExtensionPoint class], nil);
  NSDictionary *userInfo = [notification userInfo];
  id notificationObject = [userInfo objectForKey:kHGSExtensionKey];
  HGSAccount *expectedAccount = [self expectedAccount];
  BOOL gotExpectedObject = (notificationObject == expectedAccount);
  [self setReceivedWillRemoveAccountExtensionNotification:gotExpectedObject];
}

- (void)willRemoveAccountNotification:(NSNotification *)notification {
  id notificationObject = [notification object];
  HGSAccount *expectedAccount = [self expectedAccount];
  BOOL gotExpectedObject = (notificationObject == expectedAccount);
  [self setReceivedWillRemoveAccountNotification:gotExpectedObject];
}

- (void)didRemoveAccountExtensionNotification:(NSNotification *)notification {
  STAssertEquals([[notification object] class],
                 [HGSAccountsExtensionPoint class], nil);
  NSDictionary *userInfo = [notification userInfo];
  id notificationObject = [userInfo objectForKey:kHGSExtensionKey];
  HGSAccount *expectedAccount = [self expectedAccount];
  BOOL gotExpectedObject = (notificationObject == expectedAccount);
  [self setReceivedDidRemoveAccountExtensionNotification:gotExpectedObject];
}

#pragma mark Tests

- (void)testBasicAccountExtensions {
  HGSAccountsExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
  STAssertNotNil(accountsPoint, nil);
  
  // There should be no accounts registered yet.
  NSArray *accounts = [accountsPoint accountsForType:@"DUMMYTYPE"];
  STAssertEquals([accounts count], (NSUInteger)0, nil);
  accounts = [accountsPoint accountsForType:kAccountTypeA];
  STAssertEquals([accounts count], (NSUInteger)0, nil);

  // Attempt to add invalid accounts.
  STAssertFalse([accountsPoint extendWithObject:nil], nil);
  accounts = [accountsPoint extensions];
  STAssertEquals([accounts count], (NSUInteger)0, nil);
  accounts = [accountsPoint accountsAsArray];
  STAssertEquals([accounts count], (NSUInteger)0, nil);
  BOOL notified = [self receivedAddAccountExtensionNotification];
  STAssertFalse(notified, nil);
  
  // Add one valid account.
  AccountA *account1
    = [[[AccountA alloc] initWithName:@"account1"] autorelease];
  STAssertNotNil(account1, nil);
  [self setExpectedAccount:account1];
  STAssertTrue([accountsPoint extendWithObject:account1], nil);
  accounts = [accountsPoint accountsAsArray];
  STAssertEquals([accounts count], (NSUInteger)1, nil);
  notified = [self receivedAddAccountExtensionNotification];
  STAssertTrue(notified, nil);
  
  // Remove the account.
  [account1 remove];
  notified = [self receivedWillRemoveAccountNotification];
  STAssertTrue(notified, nil);
  notified = [self receivedWillRemoveAccountExtensionNotification];
  STAssertTrue(notified, nil);
  notified = [self receivedDidRemoveAccountExtensionNotification];
  STAssertTrue(notified, nil);
 
  [self setExpectedAccount:nil];

  // Remove everything.
  [self removeAllAccountsAndTypes];
}

- (void)testAddMultipleAccounts {
  // We need a bundle.
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock stub] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock stub] andReturn:@"bundle.executable"]
   objectForInfoDictionaryKey:@"CFBundleExecutable"];
  [[[bundleMock stub] andReturn:kAccountTypeAName] 
   qsb_localizedInfoPListStringForKey:kAccountTypeAName];
  BOOL yes = YES;
  [[[bundleMock stub] andReturnValue:OCMOCK_VALUE(yes)] isLoaded];

  // We need a plugin
  id pluginMock = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMock stub] andReturn:@"PLUGIN"] displayName];
  [[[pluginMock stub] andReturn:bundleMock] bundle];
  
  // We need an account type extension point.
  HGSExtensionPoint *accountTypesPoint = [HGSExtensionPoint accountTypesPoint];
  STAssertNotNil(accountTypesPoint, nil);
  
  // We need at least one account type.
  NSDictionary *configuration
    = [NSDictionary dictionaryWithObjectsAndKeys:
       bundleMock, kHGSExtensionBundleKey,
       kAccountTypeAClass, kHGSExtensionClassKey,
       kAccountTypeAID, kHGSExtensionIdentifierKey,
       kAccountTypeAName, kHGSExtensionUserVisibleNameKey,
       kHGSAccountTypesExtensionPoint, kHGSExtensionPointKey,
       kAccountTypeA, kHGSExtensionOfferedAccountTypeKey,
       kAccountAClass, kHGSExtensionOfferedAccountClassKey,
       nil];
  HGSProtoExtension *accountTypeProto
    = [[[HGSProtoExtension alloc] initWithConfiguration:configuration
                                                 plugin:pluginMock]
       autorelease];
  STAssertNotNil(accountTypeProto, nil);
  [accountTypeProto install];
  HGSAccountType *accountType
    = [accountTypesPoint extensionWithIdentifier:kAccountTypeAID];
  STAssertNotNil(accountType, nil);
  
  // Add several accounts.
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  NSString *accountName = [NSString stringWithFormat:@"%@ (%@)", @"account1",
                           kAccountTypeAName];
  [[[bundleMock stub] andReturn:accountName] 
   qsb_localizedInfoPListStringForKey:accountName];  
  NSDictionary *accountDict1 = [NSDictionary dictionaryWithObjectsAndKeys:
                                kAccountTypeAID, kHGSAccountTypeKey,
                                bundleMock, kHGSExtensionBundleKey,
                                @"account1", kHGSAccountUserNameKey,
                                versionNumber, kHGSAccountsPrefVersionKey,
                                nil];
  accountName = [NSString stringWithFormat:@"%@ (%@)", @"account2",
                 kAccountTypeAName];
  [[[bundleMock stub] andReturn:accountName] 
   qsb_localizedInfoPListStringForKey:accountName];
  NSDictionary *accountDict2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                kAccountTypeAID, kHGSAccountTypeKey,
                                bundleMock, kHGSExtensionBundleKey,
                                @"account2", kHGSAccountUserNameKey,
                                versionNumber, kHGSAccountsPrefVersionKey,
                                nil];
  accountName = [NSString stringWithFormat:@"%@ (%@)", @"account3",
                 kAccountTypeAName];
  [[[bundleMock stub] andReturn:accountName] 
   qsb_localizedInfoPListStringForKey:accountName];
  NSDictionary *accountDict3 = [NSDictionary dictionaryWithObjectsAndKeys:
                                kAccountTypeAID, kHGSAccountTypeKey,
                                bundleMock, kHGSExtensionBundleKey,
                                @"account3", kHGSAccountUserNameKey,
                                versionNumber, kHGSAccountsPrefVersionKey,
                                nil];
  accountName = [NSString stringWithFormat:@"%@ (%@)", @"account4",
                 kAccountTypeAName];
  [[[bundleMock stub] andReturn:accountName] 
   qsb_localizedInfoPListStringForKey:accountName];
  NSDictionary *accountDict4 = [NSDictionary dictionaryWithObjectsAndKeys:
                                kAccountTypeAID, kHGSAccountTypeKey,
                                bundleMock, kHGSExtensionBundleKey,
                                @"account4", kHGSAccountUserNameKey,
                                versionNumber, kHGSAccountsPrefVersionKey,
                                nil];
  accountName = [NSString stringWithFormat:@"%@ (%@)", @"account5",
                 kAccountTypeAName];
  [[[bundleMock stub] andReturn:accountName] 
   qsb_localizedInfoPListStringForKey:accountName];
  NSDictionary *accountDict5 = [NSDictionary dictionaryWithObjectsAndKeys:
                                kAccountTypeAID, kHGSAccountTypeKey,
                                bundleMock, kHGSExtensionBundleKey,
                                @"account5", kHGSAccountUserNameKey,
                                versionNumber, kHGSAccountsPrefVersionKey,
                                nil];
  NSArray *accountDicts = [NSArray arrayWithObjects:accountDict1, accountDict2,
                           accountDict3, accountDict4, accountDict5, nil];
  HGSAccountsExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
  [accountsPoint addAccountsFromArray:accountDicts];
  NSArray *accountExtensions = [accountsPoint extensions];
  NSUInteger extensionCount = [accountExtensions count];
  STAssertEquals(extensionCount, (NSUInteger)5, nil);
  NSArray *accounts = [accountsPoint accountsForType:kAccountTypeAID];
  NSUInteger accountCount = [accounts count];
  STAssertEquals(accountCount, (NSUInteger)5, nil);
  
  NSString *description = [accountsPoint description];
  STAssertNotEquals([description length], (NSUInteger)0, nil);
  [self removeAllAccountsAndTypes];
}

@end
