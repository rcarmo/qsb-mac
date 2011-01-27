//
//  TransferenceDemoController.h
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

#import <Cocoa/Cocoa.h>
#import "TransferenceClient.h"

// This class is the controller for the Tranference Demo application.  The
// implementation file gives examples of how to use the Transference client
// to get statistical information about the Quick Search Box.

@interface TransferenceDemoController : NSObject {
 @private
  IBOutlet NSTextField *QSBStartupTime_;
  IBOutlet NSTextField *QSBVersion_;
  IBOutlet NSButton *connect_;
  IBOutlet NSTextField *disabledPlugins_;
  IBOutlet NSTextField *enabledPlugins_;
  IBOutlet NSTextField *hostOSVersion_;
  IBOutlet NSTextField *hostname_;
  IBOutlet NSTextField *lastSearchTime_;
  IBOutlet NSTextField *numberOfPlugins_;
  IBOutlet NSTextField *numberOfResults_;
  IBOutlet NSButton *pluginState_;
  IBOutlet NSPopUpButton *plugin_;
  IBOutlet NSTextField *port_;

  TransferenceClient *client_;
  NSMutableArray *pluginList_;
}

- (IBAction)connect:(NSButton *)sender;
- (IBAction)selectedPlugin:(NSPopUpButton *)sender;
- (IBAction)updatePluginState:(NSButton *)sender;
@end
