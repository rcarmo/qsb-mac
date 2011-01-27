//
//  HGSUnitTestingUtilities.m
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

/*!
 @header
 @discussion A set of utilities for unit testing Vermilion plugins.
 */

#import <Vermilion/Vermilion.h>
#import "GTMSenTestCase.h"

/*!
 A base class for a generic delegate to pass into HGSUnitTestingPluginLoader.
 */
@interface HGSUnitTestingDelegate : NSObject<HGSDelegate> {
@private
  NSString *path_;
}
@property (readonly, copy) NSString *path;

- (id)initWithPath:(NSString *)path;
@end


/*!
  Loads a single plugin if it hasn't already been loaded
*/
@interface HGSUnitTestingPluginLoader : NSObject

/*!
 Loads the plugin that the delegate supplies if it hasn't already been loaded.
 You can then access the plugin via the extension points.
 Uses delegate as the plugin loading delegate.
*/
+ (BOOL)loadPluginWithDelegate:(HGSUnitTestingDelegate *)delegate;
                                                  
@end

/*!
 A base class for testing various extensions. Takes care of loading and
 unloading the extension appropriately for you. If you override setup and/or
 teardown, make sure to call the super class versions from your override.
*/
@interface HGSExtensionAbstractTestCase : GTMTestCase {
 @private
  HGSExtension *extension_;
  HGSUnitTestingDelegate *delegate_;  // Weak.
  NSString *extensionPointIdentifier_;
  NSString *pluginName_;
  NSString *identifier_;
  NSMutableArray *loadedExtensions_;
}

@property (readonly, retain, nonatomic) id extension;
@property (readonly, assign, nonatomic) NSString *extensionPointIdentifier;
@property (readonly, retain, nonatomic) NSString *pluginName;
@property (readonly, retain, nonatomic) NSString *identifier;
@property (readonly, assign, nonatomic) HGSUnitTestingDelegate *delegate;

/*!
 Designated initializer for HGSExtensionTestCase.
 @param invocation. The test to be invoked.
 @param pluginName The name of the plugin that we want to access 
        (without the hgs extension). 
 @param identifier The identifier for the extension we want to load.
 @param extensionPointIdentifier The extension point that we expect the 
        extension to extend.
 @param delegate the HGSUnitTestingDelegate used to control plugin loading.
        delegate can be nil, in which case a HGSUnitTestingDelegate will be 
        used.
*/
- (id)initWithInvocation:(NSInvocation *)invocation
             pluginNamed:(NSString *)pluginName 
     extensionIdentifier:(NSString *)identifier
extensionPointIdentifier:(NSString *)extensionPointIdentifier
                delegate:(HGSUnitTestingDelegate *)delegate;
/*!
  Calls 
  initWithInvocation:pluginNamed:extensionIdentifier:extensionPointIdentifier:delegate:
  with a nil delegate.
*/
- (id)initWithInvocation:(NSInvocation *)invocation
             pluginNamed:(NSString *)pluginName 
     extensionIdentifier:(NSString *)identifier
extensionPointIdentifier:(NSString *)extensionPointIdentifier;

/*
  Returns and loads an HGSExtension.
  @param pluginName The name of the plugin that we want to access 
  (without the hgs extension). 
  @param identifier The identifier for the extension we want to load.
  @param extensionPointIdentifier The extension point that we expect the
  extension to extend.
  @param delegate the HGSUnitTestingDelegate used to control plugin loading.
*/

- (HGSExtension *)extensionWithIdentifier:(NSString *)identifier
                          fromPluginNamed:(NSString *)pluginName
                 extensionPointIdentifier:(NSString *)extensionPointID
                                 delegate:(HGSUnitTestingDelegate *)delegate;
@end

/*!
 A base class for testing source extensions.
*/
@interface HGSSearchSourceAbstractTestCase : HGSExtensionAbstractTestCase
@property (readonly, retain, nonatomic) HGSSearchSource *source;
/*!
 Designated initializer for HGSSearchSourceTestCase.
 @param invocation. The test to be invoked.
 @param pluginName The name of the plugin that we want to access 
 (without the hgs extension). 
 @param identifier The identifier for the extension we want to load
*/
- (id)initWithInvocation:(NSInvocation *)invocation
             pluginNamed:(NSString *)pluginName 
     extensionIdentifier:(NSString *)identifier;

/*!
 Returns a list of results that can be archived by this source. Needs
 to be overridden by any subclass that supports archiving of results.
*/
- (NSArray *)archivableResults;
@end

/*!
 A base class for testing action extensions.
 */
@interface HGSActionAbstractTestCase : HGSExtensionAbstractTestCase
@property (readonly, retain, nonatomic) HGSAction *action;
/*!
 Designated initializer for HGSActionTestCase.
 @param invocation. The test to be invoked.
 @param pluginName The name of the plugin that we want to access 
 (without the hgs extension). 
 @param identifier The identifier for the extension we want to load
 */
- (id)initWithInvocation:(NSInvocation *)invocation
             pluginNamed:(NSString *)pluginName 
     extensionIdentifier:(NSString *)identifier;
@end

/*!
 A simple source for using in tests.
*/
@interface HGSUnitTestingSource : HGSSearchSource
+ (id)sourceWithBundle:(NSBundle *)bundle;

- (id)initWithBundle:(NSBundle *)bundle;
@end

