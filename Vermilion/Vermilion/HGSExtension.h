//
//  HGSExtension.h
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
 @discussion HGSExtension
*/

#import <AppKit/AppKit.h>

@class HGSProtoExtension;

/*!
  Information about extensions that a UI can display.
*/
@interface HGSExtension : NSObject {
 @private
  NSString *displayName_;
  NSString *iconPath_;
  NSImage *icon_;
  NSString *identifier_;
  NSBundle *bundle_;
  BOOL userVisible_;
  __weak HGSProtoExtension *protoExtension_;
}

/*!
 Return the protoExtension associated with this extension.
 */
@property (readonly, assign) HGSProtoExtension *protoExtension;
/*!
 Return the bundle associated with this extension.
 */
@property (readonly, retain) NSBundle *bundle;
/*!
 Return an identifier for the extension (reverse DNS style).
 
 @result The default implementation returns the kHGSExtensionIdentifierKey value 
         from the configuration dictionary. Falls back on CFBundleIdentifier.
 */
@property (readonly, copy) NSString *identifier;
/*!
 Return an icon that can be displayed 128x128.
 
 @result The default implementation returns the image at the 
         kHGSExtensionIconImagePathKey value from the configuration dictionary. 
         Falls back on a default icon.
*/
@property (readonly, retain) NSImage *icon;
/*!
 Return a display name string for the extension.
 
 @result The default implementation returns the kHGSExtensionUserVisibleNameKey 
        value from the configuration dictionary. If that doesn't exist, it tries
        various fallbacks trying to get a decent name.
*/
@property (readonly, copy) NSString *displayName;
/*!
 Return a copyright string for the extension.
 
 @result The default implementation returns the NSHumanReadableCopyright value.
*/
@property (readonly, copy) NSString *copyright;
/*!
 Return a description for the extension.
 
 @result The default implementation looks for a file named "Description.html", 
         "Description.rtf", and "Description.rtfd", in that order, in the bundle 
         returned by bundle.
 */
@property (readonly, copy) NSAttributedString *extensionDescription;
/*!
 Return a version number for the extension.
 
 @result The default value is the "CFBundleVersion" value from the info.plist 
         of the bundle of the class that this object is an instance of.
*/
@property (readonly, copy) NSString *extensionVersion;
/*!
  Return a name for a default icon for this extension if another icon can't
  be found.
*/
@property (readonly, retain) NSString *defaultIconName;

/*!
 Return whether this extension would normally be presented to the user
 in the user interface.  For example, not all account types are shown
 to the user in the 'Account Type' popup of QSB.  User visibility is
 normally controlled by the kHGSExtensionIsUserVisible key in the
 extension's section of the plugin's plist and defaults to YES if
 not otherwise specified.
 
 @result YES if the extension should be presented to the user.
*/
@property (nonatomic, assign) BOOL userVisible;

/*!
 Default initializer.
*/
- (id)initWithConfiguration:(NSDictionary *)configuration;

/*!
 Primary initializer used when installing an extension as part of enabling a
 protoExtension.  Some extensions require knowledge of their protoExtension.
 This initializer calls [self initWithConfiguration:].
*/
- (id)initWithConfiguration:(NSDictionary *)configuration
                      owner:(HGSProtoExtension *)owner;

/*!
  Return an objectForInfoDictionaryKey for this extension
*/
- (id)objectForInfoDictionaryKey:(NSString *)key;

/*!
  Return a default object for the given key.  Overridding implementations
  should always call super if it cannot provide the default.
*/
- (id)defaultObjectForKey:(NSString *)key;

/*!
  Called when an extension is being uninstalled. Good place to handle
  cancelling operations and invalidating timers. All implementations should
  be sure to call [super uninstall].
*/
- (void)uninstall;

/*!
  Returns an autoreleased image.
  If nameOrPathOrExtension is absolute:
    - If the path is to an image file, returns that file
    - If the path is to a non-image file, returns its icon.
  If not absolute, looks for an image in the bundle.
    - If the path is to an image file, returns that file
    - If the path is to a non-image file, returns its icon.
  Calls standard imageNamed.
  Finally attempts to get an image treating nameOrPathOrExtension as a fileType.
*/
- (NSImage *)imageNamed:(NSString *)nameOrPathOrExtension;

@end

/*!
 Extensions to NSSet to make it easier to read values in from configuration
 dictionaries.
*/
@interface NSSet (HGSExtension)

/*!
 Given a string, array, or a set, will convert it into a set.
 Useful for reading configuration dictionaries.
*/
+ (NSSet *)qsb_setFromId:(id)value;

@end

/*!
 Extensions to NSBundle to make it easier to read values in from configuration
 dictionaries.
*/
@interface NSBundle (HGSExtension)

/*!
 Given a key, will look for it first in InfoPList.strings, and then
 in Localizable.strings attempting to localize it.
 Will return string, if no localized version is found.
*/
- (NSString *)qsb_localizedInfoPListStringForKey:(NSString *)key;

@end

#pragma mark Extension keys

/*!
  String which is the class of the extension. Required.
*/
extern NSString *const kHGSExtensionClassKey;

/*!
  String giving the points to which to attach the extension. Required.
*/
extern NSString *const kHGSExtensionPointKey;

/*!
  String which is the reverse DNS identifier of the extension. Required.
*/
extern NSString *const kHGSExtensionIdentifierKey;

/*!
  String which is the user-visible name of the extension. Optional.
  Will use plugin display name if not supplied.
*/
extern NSString *const kHGSExtensionUserVisibleNameKey;

/*!
  Extension's icon image. This can be requested through defaultObjectForKey but
  cannot be set in the initial configuration, because we want to discourage
  loading icons at startup if at all possible. When you fulfill the request we
  expect a 128x128 image.
*/
extern NSString *const kHGSExtensionIconImageKey;

/*!
  String which is the path to an icon image. The path can either just be a
  name, in which case it will be looked for in the extension bundle, or a full
  path.
*/
extern NSString *const kHGSExtensionIconImagePathKey;

/*!
  NSNumber (BOOL) indicating if extension is enabled. Optional. Defaults
  to YES.
*/
extern NSString *const kHGSExtensionEnabledKey;

/*!
  NSBundle bundle associated with the extension
*/
extern NSString *const kHGSExtensionBundleKey;

/*!
  Types of accounts in which the extension is interested.  This may be a
  single NSString specifying the account type, or an array of NSStrings.
  The account type is typically expressed in reverse-DNS format.
*/
extern NSString *const kHGSExtensionDesiredAccountTypesKey;

/*!
  Type of accounts in which the extension is offering.  Appropriate only
  for extensions of type HGSAccountType.
*/
extern NSString *const kHGSExtensionOfferedAccountTypeKey;

/*!
  Class name of the account class deriving from HGSAccount which the
  extension is offering.  Appropriate only for extensions of type
  HGSAccountType.
*/
extern NSString *const kHGSExtensionOfferedAccountClassKey;

/*!
  YES if the extension presented to the user in the preferences panel.  If this
  is not present then YES is assumed.
*/
extern NSString *const kHGSExtensionIsUserVisibleKey;

/*!
  YES if the extension is to be enabled by default.  If this key is _not_
  present, YES is assumed, except for account-dependent sources, in which case
  NO is assumed.
*/
extern NSString *const kHGSExtensionIsEnabledByDefaultKey;

/*!
  Account assigned to the extension. (id<HGSAccount>)
*/
extern NSString *const kHGSExtensionAccountKey;
