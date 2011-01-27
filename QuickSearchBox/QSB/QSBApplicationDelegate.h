//
//  QSBApplicationDelegate.h
//
//  Copyright (c) 2006-2008 Google Inc. All rights reserved.
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
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <Growl/Growl.h>
#import "GTMDefines.h"

@class QSBSearchWindowController;
@class QSBPreferenceWindowController;
@class QSBHGSDelegate;
@class QSBUserMessenger;
@class GTMCarbonHotKey;
@class GTMHotKey;

extern NSString *const kQSBBeenLaunchedPrefKey;

@interface QSBApplicationDelegate : NSObject <GrowlApplicationBridgeDelegate> {
 @private
  IBOutlet NSMenu *statusItemMenu_;
  IBOutlet NSMenu *dockMenu_;
  IBOutlet NSMenuItem *statusShowSearchBoxItem_;
  IBOutlet NSMenuItem *dockShowSearchBoxItem_;

  QSBSearchWindowController *searchWindowController_;
  GTMCarbonHotKey *carbonHotKey_;  // the hot key we're looking for.
  GTMHotKey *hotKey_;
  NSUInteger hotModifiers_;  // if we are getting double taps, the mods to look for.
  NSUInteger hotModifiersState_;
  NSUInteger oldHotModifiers_;  // Keep track of the last modifier state
  NSTimeInterval lastHotModifiersEventCheckedTime_;
  NSStatusItem *statusItem_;
  ProcessSerialNumber otherQSBPSN_;  // The psn of any other qsb that is running
  QSBPreferenceWindowController *prefsWindowController_;
  QSBHGSDelegate *hgsDelegate_;
  QSBUserMessenger *userMessenger_;
  NSAppleEventDescriptor *applicationASDictionary_;
  BOOL activateOnStartup_;
}

@property (readonly, retain, nonatomic) QSBSearchWindowController *searchWindowController;

@property (retain, nonatomic) GTMHotKey *hotKey;

// Manage our application preferences.
- (IBAction)showPreferences:(id)sender;

// Open a browser window with the Product homepage
- (IBAction)showProductHomepage:(id)sender;

// Handles selecting the "Send Feedback To Google" item in menu
- (IBAction)sendFeedbackToGoogle:(id)sender;

// Show the about box
- (IBAction)orderFrontStandardAboutPanel:(id)sender;

// Show the debug window
- (IBAction)showDebugWindow:(id)sender;

// method that is called when the modifier keys are hit and we are inactive
- (void)modifiersChangedWhileInactive:(NSEvent*)event;

// method that is called when the modifier keys are hit and we are active
- (void)modifiersChangedWhileActive:(NSEvent*)event;

// method that is called when a key changes state and we are active
- (void)keysChangedWhileActive:(NSEvent*)event;

- (NSMenu*)statusItemMenu;

// A list of all plugins which have been identified in the various
// plugin locations.
- (NSArray *)plugins;

// A list of all available source extensions (regardless of whether they
// are installed or not).
- (NSArray *)sourceExtensions;

// Returns the accounts.
- (NSArray *)accounts;

// Returns YES if the user wants us to report messages using Growl
// and Growl is active.
- (BOOL)useGrowl;
- (void)setUseGrowl:(BOOL)value;

// Returns YES if Growl is available.
- (BOOL)growlIsInstalledAndRunning;

@end

#pragma mark Notifications

// Notification sent when we are reopened (finder icon clicked while we
// are running, or the dock icon clicked).
#define kQSBApplicationDidReopenNotification @"QSBApplicationDidReopenNotification"
