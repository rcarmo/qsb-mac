//
//  HGSSimpleAccountTest.m
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
#import "HGSSimpleAccount.h"
#import "HGSKeychainItem.h"
#import <OCMock/OCMock.h>

static NSString *const kServiceName
  =  @"com.google.qsb.SimpleAccountType.HGSSimpleAccount E";

@interface HGSSimpleAccountTest : GTMTestCase {
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

@interface SimpleAccount : HGSSimpleAccount
@end

@implementation SimpleAccount

- (NSString *)type {
  return @"SimpleAccountType";
}

- (BOOL)authenticateWithPassword:(NSString *)password {
  return NO;
}

@end


@interface NilTypeSimpleAccount : HGSAccount
@end


@implementation NilTypeSimpleAccount

- (NSString *)type {
  return nil;
}

@end

@interface SimpleAccountWithFakeKeychain : SimpleAccount
@end

@implementation SimpleAccountWithFakeKeychain

// Fake having a keychainItem.
- (HGSKeychainItem *)keychainItem {
  HGSKeychainItem *item = [[[HGSKeychainItem alloc] init] autorelease];
  return item;
}

@end

@implementation HGSSimpleAccountTest

@synthesize receivedPasswordNotification = receivedPasswordNotification_;
@synthesize receivedWillBeRemovedNotification
  = receivedWillBeRemovedNotification_;
@synthesize account = account_;

- (void)dealloc {
  [self setAccount:nil];
  [super dealloc];
}

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

- (BOOL)receivedPasswordNotification {
  BOOL result = receivedPasswordNotification_;
  receivedPasswordNotification_ = NO;
  return result;
}

- (BOOL)receivedWillBeRemovedNotification {
  BOOL result = receivedWillBeRemovedNotification_;
  receivedWillBeRemovedNotification_ = NO;
  return result;
}

- (void)setUp {
  // Cleanse the keychain.
  NSArray *keychainItems
    = [HGSKeychainItem allKeychainItemsForService:kServiceName];
  for (HGSKeychainItem *keychainItem in keychainItems) {
    [keychainItem removeFromKeychain];
  }
}

#pragma mark Tests

- (void)testInit {
  // init: Should fail to init due to no username or type.
  HGSSimpleAccount *account = [[[HGSSimpleAccount alloc] init] autorelease];
  STAssertNil(account, nil);
  // initWithName: Should fail to init since there is no type.
  account = [[[HGSSimpleAccount alloc] initWithName:nil] autorelease];
  STAssertNil(account, nil);
  account = [[[HGSSimpleAccount alloc] initWithName:@""] autorelease];
  STAssertNil(account, nil);
  account = [[[NilTypeSimpleAccount alloc] initWithName:@"HGSSimpleAccount A"] autorelease];
  STAssertNil(account, nil);
  account = [[[SimpleAccount alloc] initWithName:@"SimpleAccount A"] autorelease];
  STAssertNotNil(account, nil);
  // initWithConfiguration:
  NSDictionary *configuration = [NSDictionary dictionary];
  account
    = [[[HGSSimpleAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);
  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"HGSSimpleAccount A", kHGSAccountUserNameKey,
                   nil];
  account
    = [[[HGSSimpleAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);
  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"HGSSimpleAccount B", kHGSAccountUserNameKey,
                   @"SIMPLE TYPE B", kHGSAccountTypeKey,
                   nil];
  account
    = [[[HGSSimpleAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);
  // HGSSimpleAccounts must have a keychain item so this will result in nil.
  configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                   @"HGSSimpleAccount C", kHGSAccountUserNameKey,
                   nil];
  account
    = [[[SimpleAccount alloc] initWithConfiguration:configuration] autorelease];
  STAssertNil(account, nil);
}

- (void)testConfiguration {
  // The SimpleAccountWithFakeKeychain class provides a fake keychain item
  // so should result in an account.
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock expect] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  NSDictionary *configuration = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @"HGSSimpleAccount D", kHGSAccountUserNameKey,
                                 bundleMock, kHGSExtensionBundleKey,
                                 versionNumber, kHGSAccountsPrefVersionKey,
                                 nil];
  NSString *value = @"HGSSimpleAccount D ((null))";
  [[[bundleMock expect] andReturn:value] 
   qsb_localizedInfoPListStringForKey:value];  
  
  HGSAccount *account
    = [[[SimpleAccountWithFakeKeychain alloc] initWithConfiguration:configuration]
       autorelease];
  NSDictionary *result = [account configuration];
  STAssertNotNil(result, nil);
  NSString * userName = [result objectForKey:kHGSAccountUserNameKey];
  STAssertEqualObjects(userName, @"HGSSimpleAccount D", nil);
  NSString * accountType = [result objectForKey:kHGSAccountTypeKey];
  STAssertEqualObjects(accountType, @"SimpleAccountType", nil);
}

- (void)testAccessors {
  SimpleAccount *account
    = [[[SimpleAccount alloc] initWithName:@"HGSSimpleAccount E"]
       autorelease];
  // Clean up any keychain item leftover from a previous run
  HGSKeychainItem *keychainItem = [account keychainItem];
  [keychainItem removeFromKeychain];
  NSString *identifier = [account identifier];
  STAssertEqualObjects(identifier, @"SimpleAccountType.HGSSimpleAccount E", nil);
  NSString *userName = [account userName];
  STAssertEqualObjects(userName, @"HGSSimpleAccount E", nil);
  // displayName tested in HGSAccountTest, not here.
  NSString *accountType = [account type];
  STAssertEqualObjects(accountType, @"SimpleAccountType", nil);
  BOOL isEditable = [account isEditable];
  STAssertTrue(isEditable, nil);
  NSString *description = [account description];
  STAssertNotNil(description, nil);
  
  // Password
  BOOL notified = [self receivedPasswordNotification];
  STAssertFalse(notified, nil);
  NSString *password = [account password];
  STAssertNil(password, nil);
  [self setAccount:account];
  [account setPassword:@"PASSWORD E"];
  notified = [self receivedPasswordNotification];
  STAssertTrue(notified, nil);
  // receivedPasswordNotification should have been reset -- be sure.
  notified = [self receivedPasswordNotification];
  STAssertFalse(notified, nil);
  // Reset the password -- takes a different path from first setting.
  [account setPassword:@"PASSWORD E1"];
  notified = [self receivedPasswordNotification];
  STAssertTrue(notified, nil);
  
  // Null operations.
  [account authenticate];
  
  // Other Accessors
  BOOL authenticated = [account authenticateWithPassword:nil];
  STAssertFalse(authenticated, nil);
  [account setAuthenticated:YES];
  authenticated = [account isAuthenticated];
  STAssertTrue(authenticated, nil);
  [account setAuthenticated:NO];
  authenticated = [account isAuthenticated];
  STAssertFalse(authenticated, nil);
  [account setAuthenticated:YES];
  authenticated = [account isAuthenticated];
  STAssertTrue(authenticated, nil);
  
  // Removal
  [account remove];
  STAssertTrue([self receivedWillBeRemovedNotification], nil);
}

@end
