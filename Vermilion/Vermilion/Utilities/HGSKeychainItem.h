//
//  HGSKeychainItem.h
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
 @discussion HGSKeychainItem
*/

#import <Foundation/Foundation.h>
#import <Security/Security.h>

/*!
 Code for accessing the keychain.
*/
@interface HGSKeychainItem : NSObject {
 @private
  SecKeychainItemRef keychainItemRef_;
}

@property (readonly) NSString *username;
@property (readonly) NSString *password;
@property (readonly) NSString *label;

/*!
 Returns the first keychain item matching the service.
 If the username can be anything, pass nil for |username|.
*/
+ (HGSKeychainItem*)keychainItemForService:(NSString*)serviceName
                                  username:(NSString*)username;
/*!
 Returns the first keychain item for the given host.
 If the username can be anything, pass nil for |username|.
 */
+ (HGSKeychainItem*)keychainItemForHost:(NSString*)host
                               username:(NSString*)username;

/*! Returns all keychain items for the given service. */
+ (NSArray*)allKeychainItemsForService:(NSString*)serviceName;

/*! Adds a new keychain item for |service|. */
+ (HGSKeychainItem*)addKeychainItemForService:(NSString*)serviceName
                                 withUsername:(NSString*)username
                                     password:(NSString*)password;

/*! Designated initializer */
- (HGSKeychainItem*)initWithRef:(SecKeychainItemRef)ref;

/*! Updates the username and password associated with a keychain item. */
- (void)setUsername:(NSString*)username password:(NSString*)password;

/*! Delete the keychain item from its keychain. */
- (void)removeFromKeychain;

/*!
 Check |status| and if not noErr then always log wrPermErr's otherwise
 only log other errors for debug builds.  The wrPermErr could indicate
 a corrupted keychain.
*/
+ (BOOL)reportIfKeychainError:(OSStatus) status;
@end
