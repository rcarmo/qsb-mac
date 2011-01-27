//
//  HGSPluginLoader.h
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

#import <Foundation/Foundation.h>

/*!
 @header HGSPluginLoader
 Takes care of loading and registering plugins that extend extensions points
 Fields requests for iterators and actions for a given type via the associated
 protocols.
 
 Extensions can be defined in two ways: the easy way is to add a
 'HGSExtensions' key to your plist which is an array of dictionaries.  Each
 dictionary contains two keys: 'HGSExtensionClass' which is the class to be
 instantiated 'HGSExtensionPoint' which is a string naming the point to be
 extended.
 
 Common points are: HGSActionsExtensionPoint HGSSourcesExtensionPoint;
 
 <array>
   <dict> 
     <key>HGSExtensionClass</key> 
       <string>HGSActionSource</string>
     <key>HGSExtensionPoint</key> 
       <string>HGSSourcesExtensionPoint</string>
   </dict> 
 </array>
*/

@protocol HGSDelegate;
@class HGSCodeSignature;

/*!
 HGSPluginLoader
 Responsible for loading plugins.
*/
@interface HGSPluginLoader : NSObject {
 @private
  __weak id<HGSDelegate> delegate_;
  NSArray *plugins_;
  
  /*!
   Extension map maps a particular extension (.hgs) to a type of plugin to
   instantiate. This allows us to extend Vermiliion to accept other types of
   plugins like (.py) or (.scpt) and have those act as real plugins.
  */
  NSMutableDictionary *extensionMap_;
  
  /*!
   An array of paths to SDEFs in plugins.
  */
  NSArray *pluginsSDEFPaths_;
}

@property (readwrite, assign, nonatomic) id<HGSDelegate> delegate;
@property (readwrite, retain) NSArray *plugins;
@property (readonly, retain) NSArray *pluginsSDEFPaths;

/*!
  Return the shared plugin Loader.
*/
+ (HGSPluginLoader*)sharedPluginLoader;

/*!
  Registers a plugin class for a given set of extensions.
*/
- (void)registerClass:(Class)cls forExtensions:(NSArray *)extensions;

/*!
 Identify and load all plugins and their sources and actions.
*/
- (void)loadPluginsWithErrors:(NSArray **)errors;

/*! 
 Install plugins and enable them based on a state stored previously with
 pluginsState.
*/
- (void)installAndEnablePluginsBasedOnPluginsState:(NSArray *)state;

/*! 
 Get a state for the plugins which can be stored away and used to restore
 the plugins at a later time using  installAndEnablePluginsBasedOnPluginsState:.
*/
- (NSArray*)pluginsState;
@end

/*!
  Keys for the error dictionaries for the loadPluginsAtPath:errors: method 
  Path of the failed plugin (NSString)
*/
extern NSString *const kHGSPluginLoaderPluginPathKey;

/*!
  Reason for failure (NSString)
*/
extern NSString *const kHGSPluginLoaderPluginFailureKey;

/*!
  Failed because it's API version was incorrect
*/
extern NSString *const kHGSPluginLoaderPluginFailedAPICheck;

/*!
  Failed because unable to instantiate
*/
extern NSString *const kHGSPluginLoaderPluginFailedInstantiation;

/*!
  Failed because we don't recognize the type of the plugin
*/
extern NSString *const kHGSPluginLoaderPluginFailedUnknownPluginType;

/*!
 Notification that the loader is starting to load plugins. 
 Object is the plugin loader.
*/
extern NSString *const kHGSPluginLoaderWillLoadPluginsNotification;

/*!
 Notification that the loader has finished loading plugins. 
 Object is the plugin loader.
 Userinfo may contain kHGSPluginLoaderErrorKey which is an array
 of dictionaries representing errors loading plugins.
*/
extern NSString *const kHGSPluginLoaderDidLoadPluginsNotification;

/*!
 Notification that the plugins are all initialized and ready.
 Object is the plugin loader.
*/
extern NSString *const kHGSPluginLoaderDidInstallPluginsNotification;

/*!
 Notification that the loader will load a plugin
 Object is the plugin loader.
 Userinfo may contain kHGSPluginLoaderPluginNameKey which is an NSString
 representing the name of the plugin being loaded.
*/
extern NSString *const kHGSPluginLoaderWillLoadPluginNotification;

/*!
 Notification that the loader will install a plugin
 Object is the plugin loader.
 Userinfo may contain kHGSPluginLoaderPluginKey which is the plugin being 
 installed.
*/
extern NSString *const kHGSPluginLoaderWillInstallPluginNotification;

/*!
 Notification that the loader did install a plugin
 Object is the plugin loader.
 Userinfo may contain kHGSPluginLoaderPluginKey which is the plugin that was 
 installed.
 */
extern NSString *const kHGSPluginLoaderDidInstallPluginNotification;


/*!
 Notification that the loader did load a plugin
 Object is the plugin loader.
 Userinfo may contain:
 - kHGSPluginLoaderPluginNameKey which is an NSString
   representing the name of the plugin being loaded.
 - kHGSPluginLoaderPluginKey which is an HGSPlugin
 - kHGSPluginLoaderErrorKey which is a error dictionary
*/
extern NSString *const kHGSPluginLoaderDidLoadPluginNotification;

/*!
  Key representing a plugin (HGSPlugin).
*/
extern NSString *const kHGSPluginLoaderPluginKey;
/*!
  Key representing a plugin name (NSString *).
*/
extern NSString *const kHGSPluginLoaderPluginNameKey;
/*!
  Key representing an error loading the plugin.
*/
extern NSString *const kHGSPluginLoaderErrorKey;
