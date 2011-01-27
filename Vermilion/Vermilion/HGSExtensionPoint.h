//
//  HGSExtensionPoint.h
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
 @discussion HGSExtensionPoint
*/

#import <Foundation/Foundation.h>

/*!
  HGSExtensionPoint objects are a place that plugins can register new
  functionality. Each extension point contains a list of all registered
  extensions as well as a protocol to verify their interface.  Extensions can
  be registered at any time, and the way they are used depends only on the
  requestor.
  
  This class is threadsafe.
*/
@interface HGSExtensionPoint : NSObject {
 @private
  NSMutableDictionary* extensions_;
  Class class_;
}

/*!
  All extensions registered with this point.
*/
@property (readonly) NSArray *extensions;

/*!
  Returns the global extension point with a given identifier.
*/
+ (HGSExtensionPoint*)pointWithIdentifier:(NSString*)identifer;

/*!
    Sets a class that all extensions on this point must have a "kindOf"
    relationship. Extensions are verified on add. If extensions have already
    been registered with this point, they will be verified immediately. If they
    fail, an error will be logged to the console and they will be
    removed/ignored.
*/
- (void)setKindOfClass:(Class)kindOfClass;

/*!
  Add an extension to this point.  Returns NO if the extension could not be
  registered or if the object does not conform to the protocol.
*/
- (BOOL)extendWithObject:(id)extension;

#pragma mark Access

/*!
  Returns the extension with the given identifier.
*/
- (id)extensionWithIdentifier:(NSString *)identifier;

#pragma mark Removal

/*!
  Remove a given extension.
*/
- (void)removeExtension:(id)extension;

@end


/*!
  This notification is sent by an extension point when extensions are added.
  Object is the extension point being modified Dictionary contains
  kHGSExtensionKey.
*/
extern NSString* const kHGSExtensionPointDidAddExtensionNotification;

/*!
  Notifications sent by an extension point when an extension is about to be
  removed.
*/
extern NSString* const kHGSExtensionPointWillRemoveExtensionNotification;
/*!
  Notifications sent by an extension point when an extension is has been
  removed.
*/
extern NSString* const kHGSExtensionPointDidRemoveExtensionNotification;

/*!
  Key for the notification dictionary. Represents the extension being added or
  removed.
*/
extern NSString *const kHGSExtensionKey;
