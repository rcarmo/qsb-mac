//
//  GoogleAccountRegisterAccountCommand.m
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

#import <Cocoa/Cocoa.h>
#import <Vermilion/Vermilion.h>
#import "GoogleAccount.h"
#import "HGSKeychainItem.h"

@interface GoogleAccountRegisterAccountCommand : NSScriptCommand
@end


@implementation GoogleAccountRegisterAccountCommand

- (id)performDefaultImplementation {
  NSDictionary *args = [self evaluatedArguments];
  NSString *accountName = [args objectForKey:@"Account"];
  NSString *password = [args objectForKey:@"Password"];
  NSNumber *accountTypeNum = [args objectForKey:@"AccountType"];
  UInt32 accountType = [accountTypeNum unsignedIntValue];
  Class accountTypeClass = (accountType == 'Hstd')
                           ? [GoogleAppsAccount class]
                           : [GoogleAccount class];
  GoogleAccount *newAccount
    = [[[accountTypeClass alloc] initWithName:accountName] autorelease];
  if (newAccount) {
    // Make sure this account is not already registered.
    NSString *accountIdentifier = [newAccount identifier];
    HGSAccountsExtensionPoint *accountsPoint
      = [HGSExtensionPoint accountsPoint];
    if (![accountsPoint extensionWithIdentifier:accountIdentifier]) {
      // Authenticate the account.
      BOOL isGood = [newAccount authenticateWithPassword:password];
      [newAccount setAuthenticated:isGood];
      if (isGood) {
        // If there is not already a keychain item create one.  If there is
        // then update the password.
        HGSKeychainItem *keychainItem = [newAccount keychainItem];
        if (keychainItem) {
          [keychainItem setUsername:accountName
                           password:password];
        } else {
          NSString *keychainServiceName = accountIdentifier;
          [HGSKeychainItem addKeychainItemForService:keychainServiceName
                                        withUsername:accountName
                                            password:password]; 
        }
        
        // Install the account.
        if (![accountsPoint extendWithObject:newAccount]) {
          // Set error that account failed to install -- very unusual
          // so also log an error to the console.
          HGSLog(@"Failed to install account extension for account '%@'.",
                 accountName);
          NSString *errorString
            = HGSLocalizedString(@"The account failed to install.",
                                 @"An error message saying that the account "
                                 @"could not be installed.");
          [self setScriptErrorString:errorString];
          [self setScriptErrorNumber:errOSAScriptError];
          newAccount = nil;
        }
      } else {
        NSString *errorString
          = HGSLocalizedString(@"The account failed to authenticate.",
                               @"An error message saying that the account "
                               @"could not be authenticated.");
        [self setScriptErrorString:errorString];
        [self setScriptErrorNumber:errOSAScriptError];
        newAccount = nil;
      }
    } else {
      NSString *errorString
        = HGSLocalizedString(@"Account already set up.",
                             @"An error message explaining that an "
                             @"account of that type with that "
                             @"login information has already "
                             @"been set up.");
      [self setScriptErrorString:errorString];
      [self setScriptErrorNumber:errOSAScriptError];
      newAccount = nil;
    }
  }

  return [newAccount objectSpecifier];
}

@end
