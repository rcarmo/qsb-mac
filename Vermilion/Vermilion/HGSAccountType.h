//
//  HGSAccountType.h
//
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
  @discussion HGSAccountType
*/

#import <Vermilion/HGSExtension.h>

/*!
 A class that specifies a type of account that can be instantiated into an
 instance of HGSAccount representing an actual account with a user name
 and authentication credentials.  Account Types are typically presented
 in the user interface, allowing the user to create a concrete account
 instance along with its credentials.
 
 An account type is an extension added to the account types extension point
 (HGSAccountTypesExtensionPoint).  One is specified in the plist of a
 plugin as an HGSExtension and provides the following:
 
 @textblock
   HGSExtensionClass: Always 'HGSAccountType'.
   HGSExtensionIdentifier: A reverse DNS identifier such as
     'com.google.qsb.google.account'.
   HGSExtensionUserVisibleName: The human readable name of the account
     type such as may be presented in a popup of available account
     types.  For instance, 'Google'.
   HGSExtensionPoint: Always 'HGSAccountTypesExtensionPoint'.
   HGSExtensionOfferedAccountType: A unique account type name which is also
     used by consumers (i.e. other extensions) wishing to be 'factored' by
     accounts of this type.  Quite often this will be the same as the
     human readable name specified for HGSExtensionUserVisibleName.  For
     example: 'Google'.
 @/textblock
 
 When used with the Quick Search Box, the following can also be provided:
 
 @textblock
   QSBSetUpAccountViewNibName: The name of the nib containing a view by
     which a new account of this type can be set up.  Optional, and, if
     not provided, no new accounts of this type can be set up.  The nib
     should be provided in the bundle for the associated plugin.
   QSBSetUpAccountViewControllerClassName: The name of the NSViewController
     class which must be the owner of the nib specified by
     QSBSetUpAccountViewNibName.  This view controller must derive from
     QSBSetUpAccountViewController.  QSBSetUpSimpleAccountViewController,
     which derives from QSBSetUpAccountViewController, provides the common
     elements for typical account types needing a user name and a password.
   QSBEditAccountWindowNibName: The name of the nib containing a window by
     which an existing account of this type can be edited.  Optional, and, if
     not provided, accounts of this type cannot be edited once set up.  The
     nib should be provided in the bundle for the associated plugin.
   QSBEditAccountWindowControllerClassName: The name of the NSWindowController
     class which must be the owner of the nib specified by
     QSBEditAccountWindowNibName.  This window controller must derive from
     QSBEditAccountWindowController.  QSBEditSimpleAccountViewController,
     which derives from QSBEditAccountWindowController, provides the common
     elements for typical account for which the password can be updated.
 @/textblock
*/
@interface HGSAccountType : HGSExtension
@end
