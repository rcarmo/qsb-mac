//
//  HGSDelegate.h
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
 @discussion HGSDelegate
 */

@class HGSResult;


/*!
  This protocol is used for a delegate so the core HGS code can get information
  from the application it's running within without knowing about the packaging.
*/
@protocol HGSDelegate

/*!
  Returns the path to the user level app support folder for the running app.
*/
- (NSString *)userApplicationSupportFolderForApp;

/*! Returns the path to the user level cache folder for the running app. */
- (NSString *)userCacheFolderForApp;

/*! Returns an array of strings w/ the plugin folders. */
- (NSArray*)pluginFolders;

/*! Return a string with a language code specifying the preferred language. */
- (NSString *)suggestLanguage;

/*! Return a string uniquely identifying the client. */
- (NSString *)clientID;

/*!
  Given a result provide a value for the key. This is for keys that are
  specific to the UI.
*/
- (id)provideValueForKey:(NSString *)key result:(HGSResult *)result;

/*!
  Return a set of identifiers for highspeed sources that we want to run on the
  mainthread for queries.
*/
- (NSArray *)sourcesToRunOnMainThread;

/*!
 Provide client-specific action save-as information to HGS.
 
 Provide save-as information requested by an HGS action given a dictionary
 containing at least one key (kHGSSaveAsRequestTypeKey) identifying the
 purpose of the request. Other, optional, keys may be provided as appropriate
 for helping the HGSDelegate fulfill the request.  The primary requestor may
 identify itself by passing a pointer to itself as the value for the key
 kHGSSaveAsRequesterKey.
 
 The intention of this function is to give plug-ins the ability to request
 information for a save-as action to be performed; information that only the
 delegate can provide such as through a user interface (perhaps via preferences
 or a modal save-as dialog).
 
 The required key, for example, could be used to identify a nib file (for a
 Mac OS X-based client).  Additional key/values can be supplied in the
 dictionary giving default values to be shown in a modal dialog.
 
 @param request A dictionary containing keys and default values (possibly
 NSNULL) for which configuration information is requested.
 @result If successful, a dictionary containing the requested information,
 otherwise NULL.
*/
- (NSDictionary *)getActionSaveAsInfoFor:(NSDictionary *)request;

@end

/*!
  Specifies the purpose of the call to -[HGSDelegate getActionSaveAsInfoFor:].
 
  Dictionary key for specifying a string value giving the purpose of the
  call to -[HGSDelegate getActionSaveAsInfoFor:].
 
  When QSB is the client this will be the name of the nib file associated
  with a user interface presentation of a window with a window controller
  with a class name of this string with 'DialogController' appended.  
  However, if HGSConfigurationRequestSaveAsKey is provided in the request
  with a value of YES then QSB will present an NSSavePanel with an
  accessory view from the nib file with a view controller with a class
  name of this string with 'AccessoryController' appended.
*/
#define kHGSSaveAsRequestTypeKey @"HGSSaveAsRequestTypeKey"

/*!
  Dictionary key for specifying a pointer value to the requestor of the
  call to -[HGSDelegate getActionSaveAsInfoFor:].
*/
#define kHGSSaveAsRequesterKey @"HGSSaveAsRequesterKey"

/*!
 Dictionary key for specifying a pointer value to the requestor of the
 call to -[HGSDelegate getActionSaveAsInfoFor:].
 */
#define kHGSSaveAsHGSResultKey @"HGSSaveAsHGSResultKey"

/*!
   Dictionary key for specifying that a request to -[HGSDelegate
   getActionSaveAsInfoFor:] has succeeded or failed.
*/
#define kHGSSaveAsAcceptableKey @"HGSSaveAsAcceptableKey"

/*!
 Dictionary key for specifying the URL to which the save-as is to be
 performed.
*/
#define kHGSSaveAsURLKey @"HGSSaveAsURLKey"
