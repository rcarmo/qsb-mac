//
//  QSBPreferences.h
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

@interface QSBPreferences : NSObject
+ (BOOL)registerDefaults; // register the default w/ NSUserDefaults
@end

// Number of suggestions
// TODO(dmaclach): Move these out to the suggest source when we get
// persource preferences. That is why they are NOT prefixed with
// QSB as they are not QSB prefs.
#define kGoogleSuggestCountKey @"GoogleSuggestCount" // BOOL
#define kGoogleSuggestCountDefault 1
#define kGoogleNavSuggestCountKey @"GoogleNavSuggestCount" // BOOL
#define kGoogleNavSuggestCountDefault 1

// int - QSB number of results in the menu
#define kQSBResultCountKey                    @"QSBResultCount"
#define kQSBResultCountMin                    5
#define kQSBResultCountMax                    15
#define kQSBResultCountDefault                5

// int - QSB number of more results shown per category
#define kQSBMoreCategoryResultCountKey        @"QSBMoreCategoryResultCount"
#define kQSBMoreCategoryResultCountMin        1
#define kQSBMoreCategoryResultCountMax        5
#define kQSBMoreCategoryResultCountDefault    3

// int - QSB number of more results shown before we will "abridge" the results
//       by adding "show all <category>" results.
#define kQSBMaxMoreResultCountBeforeAbridgingKey @"kQSBMaxMoreResultCountBeforeAbridging"
#define kQSBMaxMoreResultCountBeforeAbridgingDefault    20

// Dictionary - Hot key information
#define kQSBHotKeyKey                         @"QSBHotKey"

// Dictionary key for hot key configuration information modifier flags.
// NSNumber of a unsigned int. Modifier flags are stored using Cocoa constants
// (same as NSEvent) you will need to translate them to Carbon modifier flags
// for use with RegisterEventHotKey()
#define kQSBHotKeyModifierFlagsKey @"Modifiers"

// Dictionary key for hot key configuration of virtual key code.  NSNumber of
// unsigned int. For double-modifier hotkeys (see below) this value is ignored.
#define kQSBHotKeyKeyCodeKey @"KeyCode"

// Dictionary key for hot key configuration of double-modifier tap. NSNumber
// BOOL value. Double-tap modifier keys cannot be used with
// RegisterEventHotKey(), you must implement your own Carbon event handler.
#define kQSBHotKeyDoubledModifierKey @"DoubleModifier"

// Default hotkey is ControlSpace
#define kQSBHotKeyKeyDefault                  [NSDictionary dictionaryWithObjectsAndKeys: \
                                                 [NSNumber numberWithUnsignedInt:NSControlKeyMask], \
                                                 kQSBHotKeyModifierFlagsKey, \
                                                 [NSNumber numberWithUnsignedInt:49], \
                                                 kQSBHotKeyKeyCodeKey, \
                                                 [NSNumber numberWithBool:NO], \
                                                 kQSBHotKeyDoubledModifierKey, \
                                                 nil]
#define kQSBHotKeyKeyEnabled                  @"QSBHotKeyKeyEnabled"
#define kQSBHotKeyKeyEnabledDefault           YES

#define kQSBHotKeyKey2                         @"QSBHotKey2"
#define kQSBHotKeyKey2Default                 [NSDictionary dictionaryWithObjectsAndKeys: \
                                                 [NSNumber numberWithUnsignedInt:NSCommandKeyMask], \
                                                 kQSBHotKeyModifierFlagsKey, \
                                                 [NSNumber numberWithUnsignedInt:0], \
                                                 kQSBHotKeyKeyCodeKey, \
                                                 [NSNumber numberWithBool:YES], \
                                                 kQSBHotKeyDoubledModifierKey, \
                                                 nil]
#define kQSBHotKeyKey2Enabled                  @"QSBHotKeyKey2Enabled"
#define kQSBHotKeyKey2EnabledDefault           YES

#define kQSBIconInMenubarKey                  @"QSBIconInMenubar"
#define kQSBIconInMenubarDefault              NO
#define kQSBIconInDockKey                     @"QSBIconInDock"
#define kQSBIconInDockDefault                 YES
#define kQSBUseGrowlKey                       @"QSBUseGrowl"
#define kQSBUseGrowlDefault                   YES
