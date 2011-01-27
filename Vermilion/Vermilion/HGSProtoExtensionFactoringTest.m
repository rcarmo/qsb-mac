//
//  HGSProtoExtensionFactoringTest.m
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

@interface HGSProtoExtensionFactoringTest : GTMTestCase {
 @private
  __weak HGSProtoExtension *expectedExtensionRemoved_;
}

@end


static NSString *const kAccountTypeID = @"com.google.qsb.factor.account";
static NSString *const kAccountTypeClass = @"FactorableAccountType";
static NSString *const kAccountTypeName = @"Factorable Account Type";
static NSString *const kAccountClass = @"FactorableAccount";
static NSString *const kAccountType = @"FactorableAccount";

@interface FactorableAccountType : HGSAccountType
@end


@implementation FactorableAccountType

- (NSString *)type {
  return kAccountTypeID;
}

@end


@interface FactorableAccount : HGSAccount
@end

// Account Extension Mock

@implementation FactorableAccount

- (NSString *)type {
  return kAccountType;
}

@end


@implementation HGSProtoExtensionFactoringTest

- (BOOL)expectedExtensionConstraint:(id)value {
  STAssertTrue([value isKindOfClass:[HGSProtoExtension class]], nil);
  BOOL isExpectedObject = (value == expectedExtensionRemoved_);
  return isExpectedObject;
}

- (void)testFactoring {
  // Debugging Note: If you plan to inspect the protoExtension (via an
  // NSLog, for instance) then you'll need a _real_ bundle.  Substituting
  // the following for the OCMockObject will suffice:
  //  NSBundle *bundleMock = [NSBundle bundleForClass:[self class]];

  // We need a bundle.
  id bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  [[[bundleMock expect] andReturn:@"bundle.identifier"] 
   objectForInfoDictionaryKey:@"CFBundleIdentifier"];
  [[[bundleMock expect] andReturn:kAccountTypeName] 
   qsb_localizedInfoPListStringForKey:kAccountTypeName];  
  [[[bundleMock expect] andReturn:kAccountTypeName] 
   qsb_localizedInfoPListStringForKey:kAccountTypeName];  
  [[[bundleMock expect] andReturn:@"bundle.executable"]
   objectForInfoDictionaryKey:@"CFBundleExecutable"];
  NSString *value 
    = [NSString stringWithFormat:@"testUserName (%@)", kAccountTypeName];
  [[[bundleMock expect] andReturn:value] 
   qsb_localizedInfoPListStringForKey:value];  
  BOOL yes = YES;
  [[[bundleMock expect] andReturnValue:OCMOCK_VALUE(yes)] isLoaded];

  // We need a plugin
  id pluginMock = [OCMockObject mockForClass:[HGSPlugin class]];
  [[[pluginMock stub] andReturn:bundleMock] bundle];
  [[[pluginMock expect] andReturnValue:OCMOCK_VALUE(yes)] isEnabled];
  
  // We need an account type extension point.
  HGSExtensionPoint *accountTypesPoint = [HGSExtensionPoint accountTypesPoint];
  STAssertNotNil(accountTypesPoint, nil);
  
  // We need at least one account type.
  NSDictionary *configuration
    = [NSDictionary dictionaryWithObjectsAndKeys:
       bundleMock, kHGSExtensionBundleKey,
       kAccountTypeClass, kHGSExtensionClassKey,
       kAccountTypeID, kHGSExtensionIdentifierKey,
       kAccountTypeName, kHGSExtensionUserVisibleNameKey,
       kHGSAccountTypesExtensionPoint, kHGSExtensionPointKey,
       kAccountType, kHGSExtensionOfferedAccountTypeKey,
       kAccountClass, kHGSExtensionOfferedAccountClassKey,
       nil];
  HGSProtoExtension *accountTypeProto
    = [[[HGSProtoExtension alloc] initWithConfiguration:configuration
                                                 plugin:pluginMock]
       autorelease];
  STAssertNotNil(accountTypeProto, nil);
  [accountTypeProto install];
  HGSAccountType *accountType
    = [accountTypesPoint extensionWithIdentifier:kAccountTypeID];
  STAssertNotNil(accountType, nil);

  // Add an account.
  NSNumber *versionNumber
    = [NSNumber numberWithInteger:kHGSAccountsPrefCurrentVersion];
  NSDictionary *accountDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               kAccountTypeID, kHGSAccountTypeKey,
                               bundleMock, kHGSExtensionBundleKey,
                               @"testUserName", kHGSAccountUserNameKey,
                               versionNumber, kHGSAccountsPrefVersionKey,
                               nil];
  NSArray *accountDicts = [NSArray arrayWithObject:accountDict];

  HGSAccountsExtensionPoint *aep = [HGSExtensionPoint accountsPoint];
  [aep addAccountsFromArray:accountDicts];
  
  NSArray *accounts = [aep accountsForType:kAccountType];
  STAssertEquals([accounts count], (NSUInteger)1, nil);
  HGSAccount *account = [accounts objectAtIndex:0];
  [account setAuthenticated:YES];
  [[[bundleMock expect] andReturn:@"DISPLAY NAME"] 
   qsb_localizedInfoPListStringForKey:@"DISPLAY NAME"];  

  // Create the factorable extension.
  NSDictionary *factorConfiguration
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"DISPLAY NAME", kHGSExtensionUserVisibleNameKey,
       @"IDENTIFIER", kHGSExtensionIdentifierKey,
       @"CLASS NAME", kHGSExtensionClassKey,
       kHGSAccountsExtensionPoint, kHGSExtensionPointKey,
       [NSNumber numberWithBool:YES], kHGSExtensionEnabledKey,
       kAccountType, kHGSExtensionDesiredAccountTypesKey,
       [NSNumber numberWithBool:YES], kHGSExtensionIsUserVisibleKey,
       nil];
  HGSProtoExtension *protoExtensionI
    = [[[HGSProtoExtension alloc] initWithConfiguration:factorConfiguration
                                                 plugin:pluginMock]
       autorelease];
  value = @"DISPLAY NAME (testUserName (Factorable Account Type))";
  [[[bundleMock expect] andReturn:value] 
   qsb_localizedInfoPListStringForKey:value];  

  NSArray *factored = [protoExtensionI factor];
  STAssertEquals([factored count], (NSUInteger)1, nil);

  // Take the extension for a test drive.
  HGSProtoExtension *factoredExtension = [factored objectAtIndex:0];
  BOOL userVisible
    = [factoredExtension
       isUserVisibleAndExtendsExtensionPoint:kHGSAccountsExtensionPoint];
  STAssertTrue(userVisible, nil);
  STAssertTrue([factoredExtension canSetEnabled], nil);
  
  // TODO(mrossetti):Test installing by calling setEnabled:(YES|NO).

  // Remove the account.
  expectedExtensionRemoved_ = factoredExtension;
  id constraint
    = [OCMConstraint constraintWithSelector:@selector(expectedExtensionConstraint:)
                                   onObject:self];
  [[pluginMock expect] removeProtoExtension:constraint];
  [account remove];
  expectedExtensionRemoved_ = nil;
  [pluginMock verify];
}

@end
