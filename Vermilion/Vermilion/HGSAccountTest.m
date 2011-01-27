//
//  HGSAccountTest.m
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
#import "GoogleAccountsConstants.h" // Note dependency.
#import "HGSAccount.h"
#import "HGSAccountType.h"
#import "HGSGoogleAccountTypes.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSExtensionPoint.h"
#import "HGSPlugin.h"
#import "HGSProtoExtension.h"
#import <OCMock/OCMock.h>

#pragma mark Supporting Classes

static NSString *const kTestAccountTypeID = @"com.google.qsb.test.account";
static NSString *const kTestAccountTypeClass = @"TestAccountType";
static NSString *const kTestAccountType = @"BaseAccount";
static NSString *const kTestAccountClass = @"BaseAccount";
static NSString *const kTestAccountTypeName = @"Test Account Type";

@interface TestAccountType : HGSAccountType
@end


@implementation TestAccountType

- (NSString *)type {
  return kTestAccountTypeID;
}

@end


@interface NilTypeAccount : HGSAccount
@end


@implementation NilTypeAccount

- (NSString *)type {
  return nil;
}

@end


@interface BaseAccount : HGSAccount
@end


@implementation BaseAccount

- (NSString *)type {
  return kTestAccountTypeID;
}

@end

@interface MockGoogleAccount : HGSAccount
@end


@implementation MockGoogleAccount

- (NSString *)type {
  return kHGSGoogleAccountType;
}

@end

@interface MockGoogleAppsAccount : HGSAccount
@end


@implementation MockGoogleAppsAccount

- (NSString *)type {
  return kHGSGoogleAppsAccountType;
}

@end

#pragma mark Test Class

@interface HGSAccountTest : GTMTestCase {
 @private
  BOOL receivedPasswordNotification_;
  BOOL receivedWillBeRemovedNotification_;
  HGSAccount *account_;
}

@property BOOL receivedPasswordNotification;
@property BOOL receivedWillBeRemovedNotification;
@property (retain) HGSAccount *account;

- (void)passwordChanged:(NSNotification *)notification;
- (void)willBeRemoved:(NSNotification *)notification;

@end


@implementation HGSAccountTest

@synthesize receivedPasswordNotification = receivedPasswordNotification_;
@synthesize receivedWillBeRemovedNotification
  = receivedWillBeRemovedNotification_;
@synthesize account = account_;

- (void)setAccount:(HGSAccount *)account {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  if (account_) {
    [account_ release];
    [nc removeObserver:self];
  }
  if (account) {
    account_ = [account retain];
    [nc addObserver:self
           selector:@selector(passwordChanged:)
               name:kHGSAccountDidChangeNotification
             object:account];
    [nc addObserver:self
           selector:@selector(willBeRemoved:)
               name:kHGSAccountWillBeRemovedNotification
             object:account];
  }
}

- (void)dealloc {
  [self setAccount:nil];
  [super dealloc];
}

- (void)passwordChanged:(NSNotification *)notification {
  id notificationObject = [notification object];
  HGSAccount *expectedAccount = [self account];
  BOOL gotExpectedObject = (notificationObject == expectedAccount);
  [self setReceivedPasswordNotification:gotExpectedObject];
}

- (void)willBeRemoved:(NSNotification *)notification {
  id notificationObject = [notification object];
  HGSAccount *expectedAccount = [self account];
  BOOL gotExpectedObject = (notificationObject == expectedAccount);
  [self setReceivedWillBeRemovedNotification:gotExpectedObject];
}

#pragma mark Tests

- (void)testInit {
  // init
  HGSAccount *account = [[[HGSAccount alloc] init] autorelease];
  STAssertNil(account, @"|init| should not create new HSGAccount");
  // initWithName:
  account = [[[HGSAccount alloc] initWithName:nil] autorelease];
  STAssertNil(account, @"|initWithName:nil| should not create new HSGAccount");
  account = [[[HGSAccount alloc] initWithName:@""] autorelease];
  STAssertNil(account, @"|initWithName:@\"\"| should not create new HSGAccount");
  account = [[[NilTypeAccount alloc] initWithName:@"USERNAME"] autorelease];
  STAssertNil(account, nil);

  // initWithConfiguration:
  NSDictionary *configuration = [NSDictionary dictionary];
  account
    = [[[NilTypeAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"USERNAME A", kHGSAccountUserNameKey,
                   versionNumber, kHGSAccountsPrefVersionKey,
                   nil];
  account
    = [[[NilTypeAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);
  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"USERNAME B", kHGSAccountUserNameKey,
                   @"DUMMY TYPE B", kHGSAccountTypeKey,
                   versionNumber, kHGSAccountsPrefVersionKey,
                   nil];
  account
    = [[[NilTypeAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);
  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"USERNAME B", kHGSAccountUserNameKey,
                   @"DUMMY TYPE B", kHGSAccountTypeKey,
                   @"DUMMY NAME B", kHGSExtensionUserVisibleNameKey,
                   @"DUMMY IDENTIFIER B", kHGSExtensionIdentifierKey,
                   versionNumber, kHGSAccountsPrefVersionKey,
                   nil];
  account
    = [[[NilTypeAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);
  // Initializations with test account type.  This is the only one that
  // should actually succeed in creating an account.
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock stub] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock stub] andReturn:@"USERNAME C ((null))"] 
   qsb_localizedInfoPListStringForKey:@"USERNAME C ((null))"];
  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"USERNAME C", kHGSAccountUserNameKey,
                   @"DUMMY TYPE C", kHGSAccountTypeKey,
                   bundleMock, kHGSExtensionBundleKey,
                   versionNumber, kHGSAccountsPrefVersionKey,
                   nil];
  account
    = [[[BaseAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNotNil(account, nil);
}

- (void)testConfiguration {
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock stub] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock stub] andReturn:@"USERNAME D ((null))"] 
   qsb_localizedInfoPListStringForKey:@"USERNAME D ((null))"];
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  NSDictionary *configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"USERNAME D", kHGSAccountUserNameKey,
                                 @"DUMMY TYPE D", kHGSAccountTypeKey,
                                 bundleMock, kHGSExtensionBundleKey,
                                 versionNumber, kHGSAccountsPrefVersionKey,
                                 nil];
  HGSAccount *account
    = [[[BaseAccount alloc] initWithConfiguration:configuration] autorelease];
  NSDictionary *result = [account configuration];
  STAssertNotNil(result, nil);
  NSString * userName = [result objectForKey:kHGSAccountUserNameKey];
  STAssertEqualObjects(userName, @"USERNAME D", nil);
  NSString * accountType = [result objectForKey:kHGSAccountTypeKey];
  STAssertEqualObjects(accountType, kTestAccountTypeID, nil);
}

- (void)testTypesAndAccessors {
  // We need a bundle.
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock stub] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock stub] andReturn:@"bundle.executable"]
   objectForInfoDictionaryKey:@"CFBundleExecutable"];
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
       kTestAccountTypeClass, kHGSExtensionClassKey,
       kTestAccountTypeID, kHGSExtensionIdentifierKey,
       kTestAccountTypeName, kHGSExtensionUserVisibleNameKey,
       kHGSAccountTypesExtensionPoint, kHGSExtensionPointKey,
       kTestAccountType, kHGSExtensionOfferedAccountTypeKey,
       kTestAccountClass, kHGSExtensionOfferedAccountClassKey,
       nil];
  [[[bundleMock stub] andReturn:kTestAccountTypeName] 
   qsb_localizedInfoPListStringForKey:kTestAccountTypeName];
  HGSProtoExtension *accountTypeProto
    = [[[HGSProtoExtension alloc] initWithConfiguration:configuration
                                                 plugin:pluginMock]
     autorelease];
  STAssertNotNil(accountTypeProto, nil);
  [accountTypeProto install];
  HGSAccountType *accountType
    = [accountTypesPoint extensionWithIdentifier:kTestAccountTypeID];
  STAssertNotNil(accountType, nil);
  NSString *key = [NSString stringWithFormat:@"USERNAME E (%@)", 
                   kTestAccountTypeName];
  [[[bundleMock stub] andReturn:key] 
   qsb_localizedInfoPListStringForKey:key];
  // Let's add an account.
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  NSDictionary *accountConfig = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"USERNAME E", kHGSAccountUserNameKey,
                                 bundleMock, kHGSExtensionBundleKey,
                                 kTestAccountTypeID, kHGSAccountTypeKey,
                                 versionNumber, kHGSAccountsPrefVersionKey,
                                 nil];
  HGSAccount *account
    = [[[BaseAccount alloc] initWithConfiguration:accountConfig] autorelease];
  NSString * userName = [account userName];
  STAssertEqualObjects(userName, @"USERNAME E", nil);
  NSString *displayName = [account displayName];
  STAssertEqualObjects(displayName, @"USERNAME E (Test Account Type)", nil);
  NSString *accountTypeName = [account type];
  STAssertEqualObjects(accountTypeName, kTestAccountTypeID, nil);
  NSString *password = [account password];
  STAssertNil(password, nil);
  BOOL isEditable = [account isEditable];
  STAssertTrue(isEditable, nil);
  NSString *description = [account description];
  STAssertNotNil(description, nil);
  
  // Null operations.
  [account authenticate];
}

- (void)testSetPassword {
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock stub] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock stub] andReturn:@"USERNAME F ((null))"] 
   qsb_localizedInfoPListStringForKey:@"USERNAME F ((null))"];
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  NSDictionary *configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"USERNAME F", kHGSAccountUserNameKey,
                                 @"DUMMY TYPE F", kHGSAccountTypeKey,
                                 bundleMock, kHGSExtensionBundleKey,
                                 versionNumber, kHGSAccountsPrefVersionKey,
                                nil];
  HGSAccount *account
    = [[[BaseAccount alloc] initWithConfiguration:configuration] autorelease];
  [self setAccount:account];
  [account setPassword:@"PASSWORD F"];
  STAssertTrue([self receivedPasswordNotification], nil);
}

- (void)testRemove {
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock stub] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock stub] andReturn:@"USERNAME G ((null))"] 
   qsb_localizedInfoPListStringForKey:@"USERNAME G ((null))"];
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  NSDictionary *configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"USERNAME G", kHGSAccountUserNameKey,
                                 @"DUMMY TYPE G", kHGSAccountTypeKey,
                                 bundleMock, kHGSExtensionBundleKey,
                                 versionNumber, kHGSAccountsPrefVersionKey,
                                 nil];
  HGSAccount *account
    = [[[BaseAccount alloc] initWithConfiguration:configuration] autorelease];
  [self setAccount:account];
  [account remove];
  STAssertTrue([self receivedWillBeRemovedNotification], nil);
}

- (void)testUpgradeAccount {
  // We have to use a real bundle for this particular test.
  NSBundle *bundleMock = [NSBundle bundleForClass:[self class]];
  NSNumber *badVersionNumber = [NSNumber numberWithInt:666];
  NSDictionary *configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"USERNAME G", kHGSAccountUserNameKey,
                                 @"DUMMY TYPE G", kHGSAccountTypeKey,
                                 bundleMock, kHGSExtensionBundleKey,
                                 badVersionNumber, kHGSAccountsPrefVersionKey,
                                 nil];
  HGSAccount *account
    = [[[HGSAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);

  NSNumber *oldVersionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefVersion0];
  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"USERNAME G", kHGSAccountUserNameKey,
                   @"GoogleAccount", kHGSAccountTypeKey,
                   bundleMock, kHGSExtensionBundleKey,
                   oldVersionNumber, kHGSAccountsPrefVersionKey,
                   nil];
  account
    = [[[MockGoogleAccount alloc] initWithConfiguration:configuration]
       autorelease];
  STAssertNotNil(account, nil);
  // Testing for nil is adequate since the -[type] accesses the member function
  // which returns a constant.  But let's just make sure.
  NSString *accountType = [account type];
  STAssertEqualObjects(accountType, kHGSGoogleAccountType, nil);

  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"USERNAME G", kHGSAccountUserNameKey,
                   kGoogleAppsAccountClassName, kHGSAccountTypeKey,
                   bundleMock, kHGSExtensionBundleKey,
                   oldVersionNumber, kHGSAccountsPrefVersionKey,
                   nil];
  account
    = [[[MockGoogleAppsAccount alloc] initWithConfiguration:configuration]
       autorelease];
  STAssertNotNil(account, nil);
  accountType = [account type];
  STAssertEqualObjects(accountType, kHGSGoogleAppsAccountType, nil);
}

@end
