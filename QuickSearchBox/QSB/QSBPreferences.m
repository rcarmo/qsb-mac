//
//  QSBPreferences.m
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

#import "QSBPreferences.h"

@implementation QSBPreferences

+ (BOOL)registerDefaults {

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *dictOfDefaults =
    [NSDictionary dictionaryWithObjectsAndKeys:
     // QSB result list length
     [NSNumber numberWithInteger:kQSBResultCountDefault],
     kQSBResultCountKey,
     // QSB more category result count
     [NSNumber numberWithInteger:kQSBMoreCategoryResultCountDefault],
     kQSBMoreCategoryResultCountKey,
     // QSB number of more "results" to show before breaking with "show all"s
     [NSNumber numberWithInteger:kQSBMaxMoreResultCountBeforeAbridgingDefault],
     kQSBMaxMoreResultCountBeforeAbridgingKey,
     // QSB hot key
     kQSBHotKeyKeyDefault,
     kQSBHotKeyKey,
     [NSNumber numberWithBool:kQSBHotKeyKeyEnabledDefault],
     kQSBHotKeyKeyEnabled,
     // QSB hot key 2
     kQSBHotKeyKey2Default,
     kQSBHotKeyKey2,
     [NSNumber numberWithBool:kQSBHotKeyKey2EnabledDefault],
     kQSBHotKeyKey2Enabled,
     // QSB Icon In Dock
     [NSNumber numberWithBool:kQSBIconInDockDefault],
     kQSBIconInDockKey,
     // QSB Icon In Menubar
     [NSNumber numberWithBool:kQSBIconInMenubarDefault],
     kQSBIconInMenubarKey,
     // Use Growl for user messages
     [NSNumber numberWithBool:kQSBUseGrowlDefault],
     kQSBUseGrowlKey,
     // Do we show suggestions
     [NSNumber numberWithInteger:kGoogleSuggestCountDefault],
     kGoogleSuggestCountKey,
     // Do we show nav suggestions
     [NSNumber numberWithInteger:kGoogleNavSuggestCountDefault],
     kGoogleNavSuggestCountKey,
     // done
     nil];

  if (!defaults || !dictOfDefaults) return NO;

  [defaults registerDefaults:dictOfDefaults];
  
  return YES;
}

@end
