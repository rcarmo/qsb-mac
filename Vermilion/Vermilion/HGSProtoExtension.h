//
//  HGSProtoExtension.h
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
 @discussion HGSProtoExtension
*/

#import <Foundation/Foundation.h>

@class HGSPlugin;
@class HGSExtension;
@class HGSAccount;

/*!
  An HGSProtoExtension manages an HGSExtension.  Typically, a list of these
  protoExtensions is presented to the user in a table allowing the user to
  choose which are to be enabled for actual use.  When a protoExtension is
  enabled, either automatically at application launch or manually by the user,
  an instance of HGSExtension is created and made available for subsequent
  searches and actions.  Correspondingly, when a protoExtension is disabled the
  associated HGSExtension is turned off and removed.
  
  An HGSProtoExtension can be 'factored'.  This means that the prototype
  extension can specify interest in certain external 'factors' such as an
  online account (which is the only type of factor currently supported).  Upon
  the availability of a 'factor' of the desired type, the protoExtension is
  replicated (by HGSPlugin calling the -[HGSProtoExtension factor] or
  -[HGSProtoExtension factorForAccount:] member function) and added to the list
  of available sources (usually presented to the user in a table).
  
  To specify an extension's interest in being factored by whatever
  HGSGoogleAccounts are available, provide the HGSExtensionDesiredAccountTypes
  key in your bundle's plist with a value of |Google|.
  
  It is likely that this implementation will change somewhat as new types of
  factors are introduced in the future.
*/
@interface HGSProtoExtension : NSObject {
 @private
  __weak HGSPlugin *plugin_;
  HGSExtension *extension_;
  NSMutableDictionary *configuration_;  
  BOOL enabled_;
}

/*!
   Returns the concrete extension, if any, associated with this
   proto-extension.
*/
@property (nonatomic, retain, readonly) HGSExtension *extension;

/*!
  Returns the display name for the protoextension. This is localized.
*/
@property (nonatomic, copy, readonly) NSString *displayName;

/*!
  Returns an icon for the protoextension.
*/
@property (nonatomic, retain, readonly) NSImage *icon;

/*!
  Returns the identifier of extension point that the extension represented 
  by this protoextension will extend when installed.
*/
@property (nonatomic, readonly) NSString *extensionPointKey;

/*!
  Returns the identifier for this extension.
*/
@property (nonatomic, copy, readonly) NSString *identifier;

/*! 
  YES if this extension has been turned on. 
*/
@property (nonatomic, getter=isEnabled) BOOL enabled;

/*!
 Return a version number for the extension.  By default returns the
 "CFBundleVersion" value from the info.plist of the bundle of the class that
 this object is an instance of.
 */
@property (nonatomic, assign, readonly) NSString *extensionVersion;

/*!
 Return a description for the extension.  By default looks for a file named
 "Description.html", "Description.rtf", and "Description.rtfd", in that order,
 in the bundle of the class that this object is an instance of.
 */
@property (nonatomic, assign, readonly) NSAttributedString *extensionDescription;

/*!
 Return YES if this protoExtension is factorable.  Sources are currently only
 factorable by instances of HGSAccount.
*/
@property (nonatomic, assign, readonly, getter=isFactorable) BOOL factorable;

/*!
 Returns if the extension has been installed.
*/
@property (nonatomic, assign, readonly, getter=isInstalled) BOOL installed;

/*!
 Returns YES if the extension can be enabled or disabled.  This is used to
 check account-dependent extensions to see if the account has been
 authenticated.
 */
@property (nonatomic, assign, readonly) BOOL canSetEnabled;

/*!
 Return the account used by the extension, if any.
 
 @result The default implementation looks for an account identifier
         as a part of the extension identifier and is the portion of
         the identifier following 'ACCOUNT='.
 */
@property (readonly, copy) NSString *associatedAccount;

/*! 
  Initialize a prototype extension given a dictionary. 
*/
- (id)initWithConfiguration:(NSDictionary *)bundleExtension
                     plugin:(HGSPlugin *)plugin;

/*!
  Return zero or more protoExtensions by factoring based on desired accounts.
  If this protoExtension is not factorable then return an empty array.
*/
- (NSArray *)factor;

/*!
  Return a new protoExtension by factoring on the account.  If this
  protoExtension is not factorable on account then return nil.
  TODO(mrossetti): Generalize this when additional factor types are introduced.
*/
- (HGSProtoExtension *)factorForAccount:(HGSAccount *)account;

/*!
  Install the extension represented by this protoextension. This will add
  the extension to it's extension point.
*/
- (void)install;
/*!
  Uninstall the extension represented by this protoextension. This will remove
  the extension from it's extension point.
*/
- (void)uninstall;

/*!
  Returns YES if the extension's extension point is of the type specified and
  for which the HGSIsUserVisible flas is not set to NO.
*/
- (BOOL)isUserVisibleAndExtendsExtensionPoint:(NSString *)extensionPoint;

/*!
  Returns a configuration value.
*/
- (id)objectForKey:(NSString *)configurationKey;

@end

/*!
  Notification sent when an extension has been enabled/disabled.  The
  notification's |object| will contain the HGSProtoExtension reporting the
  change.  There will be no |userInfo|.
*/
extern NSString *const kHGSExtensionDidChangeEnabledNotification;
