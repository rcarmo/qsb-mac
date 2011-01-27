//
//  HGSSimpleAccount.h
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

/*!
 @header
 @discussion HGSSimpleAccount
*/

#import <Vermilion/HGSAccount.h>

@class HGSKeychainItem;

/*!
 An abstract base class which manages an account with an account name
 and password (stored in the user's keychain) and with which a search 
 source or action can be associated.

 Use this as your account's base class if your account has the common
 pattern of requiring an account name and password for setup.  Your
 specialization of HGSSimpleAccount should have:

  - Concrete account class (see GoogleAccount) providing:
    - a -[type] method returning a (constant) string giving the
      type of the account class which this account offers to sources
      and actions adhering to the HGSAccountClientProtocol.
    - an -[authenticateWithPassword:] method that performs a synchronous
      authentication of the account.  (Note: this method _should not_
      set |authenticated|.
    Optional:
    - an -[authenticate] method that performs an asynchronous authentication
      of the account and sets |authenticated|.

  - Optionally, when you desire a user interface to be used in
    conjunction with QSB, you should also provide:
    - a view controller class deriving from 
      QSBSetUpSimpleAccountViewController, and
    - a window controller class deriving from
      QSBEditSimpleAccountWindowController.
    See those class descriptions for the details.
  - Your account type extension's plist entry must include an entry
    for HGSExtensionOfferedAccountType giving the accountType and
    HGSExtensionOfferedAccountClass giving the name of the 
    HGSSimpleAccount descendant class.

 See Vermilion/Modules/GoogleAccount/ for an example.
*/
@interface HGSSimpleAccount : HGSAccount

/*!
 Adjust the account name, if desired.  The default implementation
 returns the original string.
*/
- (NSString *)adjustUserName:(NSString *)userName;

/*!
 Retrieve the keychain item for our keychain service name, if any.
*/
- (HGSKeychainItem *)keychainItem;

/*!
 Test the account and password to see if they authenticate.
 The default implementation assumes the account is valid.  You
 should provide your own implementation.  Do not set
 authenticated_ in this method.
*/
- (BOOL)authenticateWithPassword:(NSString *)password;

@end

