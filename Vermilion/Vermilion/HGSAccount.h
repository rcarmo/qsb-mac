//
//  HGSAccount.h
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
  @discussion HGSAccount
*/

#import <Vermilion/HGSExtension.h>

/*!
  Information about accounts that a UI can display and which source or actions
  can access.
*/
@interface HGSAccount : HGSExtension {
 @private
  NSString *userName_; // AKA the account name.
  BOOL authenticated_;
}

/*!
  The userName for the account
*/
@property (nonatomic, copy, readonly) NSString *userName;
/*!
  The type (google/facebook/etc.) of the account.
*/
@property (nonatomic, copy, readonly) NSString *type;
/*!
  Is the account valid? (i.e. has it been authenticated)
*/
@property (nonatomic, getter=isAuthenticated) BOOL authenticated;
/*!
  Determine if the account is editable.  The default returns YES.
*/
@property (nonatomic, readonly, getter=isEditable) BOOL editable;
/*!
  Account password
*/
@property (nonatomic, readwrite, retain) NSString *password;
/*!
  Initialize a new account entry
*/
- (id)initWithName:(NSString *)userName;

/*!
  Reconstitute an account entry from a dictionary.
*/
- (id)initWithConfiguration:(NSDictionary *)prefDict;

/*!
  Return a dictionary describing the account appropriate for archiving to
  preferences.
*/
- (NSDictionary *)configuration;

/*!
  Do what is appropriate in order to remove the account.  The default removes
  the account from the accounts extensions point.  If you derive a subclass
  then you should call super's (this) remove.
*/
- (void)remove;

/*!
  Perform an asynchronous authentication for the account using its existing
  credentials.  The default does nothing.
*/
- (void)authenticate;

/*!
 Given a dictionary describing an account, upgrade that dictionary to the
 latest version.
*/
+ (NSDictionary *)upgradeConfiguration:(NSDictionary *)configuration;

@end

/*!  
  A protocol to which extensions wanting access to an account must adhere.
*/
@protocol HGSAccountClientProtocol

/*!
  Inform an account clients that an account is going to be removed.  The client
  should return YES if it should be shut down and deleted.
*/
- (BOOL)accountWillBeRemoved:(HGSAccount *)account;

@end

/*! The version of the preferences data stored in the dictionary (NSNumber). */
extern NSString *const kHGSAccountsPrefVersionKey;

/*! Current version of an account description in preferences. */
extern NSInteger const kHGSAccountsPrefCurrentVersion;

/*!
  Original version of an account preferences.  There was no version
  specified prior to version 1.
*/
extern NSInteger const kHGSAccountsPrefVersion0;

/*!
  Notification sent whenever an account has been changed. The |object| sent
  with the notification is the HGSAccount instance that has been changed.
*/
extern NSString *const kHGSAccountDidChangeNotification;

/*!
  Notification sent when an account is going to be removed. The |object| sent
  with the notification is the HGSAccount instance that will be removed.
*/
extern NSString *const kHGSAccountWillBeRemovedNotification;

/*!
  String specifying the username of the account.
*/
extern NSString *const kHGSAccountUserNameKey;

/*!
  String specifying the type of the account.
*/
extern NSString *const kHGSAccountTypeKey;
