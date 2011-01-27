//
//  HGSPlugin.h
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
 @discussion HGSPlugin
*/

#import <Vermilion/HGSExtension.h>

@class HGSProtoExtension;

/*!
  A class that manages a collection of source, action and service extensions
  along with location, type, enablement, etc.
  
  When an instance of HGSPlugin is initially loaded, either from a bundle or
  from preferences, an inventory of all potential extensions is collected from
  the HGSPlugin specification.
  
  Each potential extensions falls into one of two categories: 'simple' and
  'factorable'.  'Simple' extensions are immediately added to a list of
  extensions that will be automatically installed during application startup.
  These are HGSProtoExtensions.  This list is contained in |protoExtensions_|.
  This list is what is presented to the user in the 'Searchable Items' table
  found in Preferences.  A HGSProtoExtension is an extension that can be
  installed and made active either automatically at QSB startup or manually
  through user interaction.
  
  'Factorable' extensions are those that require 'factors' before they can be
  considered for installation and activation.  During the inventory process, a
  list of these 'factorable' extensions is kept in |factorableExtensions_|.
  One such 'factor' (and the only one we currently implement) is 'account'
  (see HGSAccount).  During the inventory process, the factor desired by a
  factorable extensions is identified and, if available, a new copy of the
  factorable extension is created for that factor and added to
  |protoExtensions_|.  So, for example, a copy the Picasaweb search source
  extension will be created for each instance of GoogleAccount that can be
  found; it is then placed in the list of searchable items which the user can
  enable via Preferences.
  
  The |factorableExtensions_| list is kept so that new extensions can be
  created during runtime should a new 'factor' be recognized.  For example, if
  the user sets up a new Google acccount a new Picasaweb search source using
  that account will be added to |protoExtensions_| and the user will see that
  search source appear in Preferences.
  
  An extension (search source, aka HGSExtension) is not actually installed
  until the user enables one of the 'Searchable Items' in Preferences.  (See
  HGSProtoExtension for more on this topic.)
*/
@interface HGSPlugin : HGSExtension {
 @private
  NSArray *protoExtensions_;
  NSMutableArray *factorableProtoExtensions_;
  BOOL enabled_;
}

/*! 
  Instantiated protoExtensions of this plugin. 
*/
@property (nonatomic, retain, readonly) NSArray *protoExtensions;

/*! 
  Plugin master switch. 
*/
@property (nonatomic, getter=isEnabled) BOOL enabled;

/*!
  Checks to see that the plugin bundle has a valid API version.
  @param bundle to check
  @result YES if API is valid
*/
+ (BOOL)isPluginBundleValidAPI:(NSBundle *)pluginBundle;

/*!
  Reconstitue a plugin from a bundle.
 
  Designated initializer.
*/
- (id)initWithBundle:(NSBundle *)bundle;

/*! 
  Factor our protoextensions, if appropriate. 
*/
- (void)factorProtoExtensions;

/*! 
  Install all the enabled extensions belonging to this plugin. 
*/
- (void)install;

/*! 
  Uninstall all the enabled extensions belonging to this plugin. 
*/
- (void)uninstall;

/*!
 Returns the identifier for the bundle associated with this plugin.
*/
- (NSString *)bundleIdentifier;

/*! 
  Remove and discard a protoextension. 
*/
- (void)removeProtoExtension:(HGSProtoExtension *)protoExtension;

/*! 
  Install all of our account types, if any. 
*/
- (void)installAccountTypes;

/*! 
 Convenience function that returns only extensions of a specific type. 
*/
- (NSArray *)extensionsWithType:(NSString *)type;

/*! 
 Convenience function that returns only source extensions.  Used by
 Debug panel of Preferences nib.
*/
- (NSArray *)sourceExtensions;

/*! 
 Convenience function that returns only action extensions.  Used by
 Debug panel of Preferences nib.
*/
- (NSArray *)actionExtensions;

/*! 
 Convenience function that returns only service extensions.  Used by
 Debug panel of Preferences nib.
*/
- (NSArray *)serviceExtensions;

/*! 
 Convenience function that returns only account type extensions.  Used by
 Debug panel of Preferences nib.
*/
- (NSArray *)accountTypeExtensions;

@end

/*!
  Notification sent when plugin has been enabled/disabled.  The notification's
  |object| will contain the HGSPlugin reporting the change.  There will be no
  |userInfo|.
*/
extern NSString *const kHGSPluginDidChangeEnabledNotification;

/*! 
  Array of Cocoa extension descriptions. 
*/
extern NSString *const kHGSExtensionsKey;

/*! 
  NSNumber (BOOL) indicating if plugin is enabled (master switch). 
*/
extern NSString *const kHGSPluginEnabledKey;

/*! 
  Array containing dictionaries describing the extensions of this plugin. 
*/
extern NSString *const kHGSPluginExtensionsDicts;

extern NSString *const kHGSBundleIdentifierKey;

/*!
 kHGSPluginConfigurationVersionKey is a key into the archived dictionary
 describing a plugin giving the version of the dictionary when that plugin was
 most recently archived.
*/
#define kHGSPluginConfigurationVersionKey @"kHGSPluginConfigurationVersionKey"

/*!
 kHGSPluginConfigurationVersion gives the current version with which a plugin
 configuration dictionary will be archived.
*/
#define kHGSPluginConfigurationVersion 1
