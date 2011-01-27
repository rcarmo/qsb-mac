//
//  QSBPreferenceWindowController.h
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
 @header Manage the QSB preferences window.
 @discussion Provide the primary interface for managing the top-level
 elements of the preferences window.
 */

#import <Cocoa/Cocoa.h>

@class QSBSetUpAccountWindowController;
@class HGSPlugin;

/*!
 Manage the Quick Search App preferences window.
*/
@interface QSBPreferenceWindowController : NSWindowController
    <NSMenuDelegate, NSToolbarDelegate> {
 @private
  IBOutlet NSPopUpButton *colorPopUp_;
  IBOutlet NSScrollView *advancedScrollView_;
  IBOutlet NSTabView *tabView_;
  IBOutlet NSToolbar *toolbar_;
  IBOutlet NSTableView *sourcesTable_;
  IBOutlet NSTableView *accountsTable_;

  BOOL prefsColorWellWasShowing_;  // YES if color well was showing.
  NSColorList *colors_;
  NSColor *selectedColor_;
  NSArray *sourceSortDescriptor_;

  IBOutlet NSArrayController *accountsListController_;
  LSSharedFileListRef openAtLoginItemsList_;
  UInt32 openAtLoginItemsSeedValue_;
}

@property (nonatomic, retain) NSColor *selectedColor;

/*! Designated initializer. */
- (id)init;

// Manage and report the visisbility of the preferences window.
- (IBAction)showPreferences:(id)sender;
- (void)hidePreferences;
- (BOOL)preferencesWindowIsShowing;

// Account management.
- (IBAction)setupAccount:(id)sender;
- (IBAction)editAccount:(id)sender;
- (IBAction)removeAccount:(id)sender;

// Tab Selection
- (IBAction)selectTabForSender:(id)sender;

// Choose a color from the drop down
- (IBAction)setColorFromMenu:(id)sender;

@end

/*!
 A string specifying the name of the nib to be loaded and used for
 editing an existing account.
 */
extern NSString *const kQSBEditAccountWindowNibName;

/*!
 A string specifying the name of the class of the window controller used in
 the account edit window specified by kQSBEditAccountWindowNibName.
 */
extern NSString *const kQSBEditAccountWindowControllerClassName;
