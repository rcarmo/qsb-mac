//
//  TransferenceDemoController.m
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

#import "TransferenceDemoController.h"

@interface TransferenceDemoController ()
// Clears all of the NSTextFields and disables all of the appropriate buttons.
//
- (void)disableOptionsForDisconnect;

// Fetches the latest plugin data from the beacon and refreshes them in the UI.
//
- (void)reloadPlugins;
@end


@implementation TransferenceDemoController

#pragma mark -- Intialize and dealloc --

- (id)init {
  if ((self = [super init])) {
    pluginList_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  [client_ unsubscribeFromServer];
  [client_ release];
  [pluginList_ release];
  [super dealloc];
}

#pragma mark -- Private methods --

- (void)disableOptionsForDisconnect {
  [plugin_ removeAllItems];
  [plugin_ setEnabled:NO];
  [pluginState_ setState:NSOffState];
  [pluginState_ setEnabled:NO];
}

- (void)reloadPlugins {
  // Store the previous selection
  NSString *previous = [plugin_ titleOfSelectedItem];

  [pluginList_ removeAllObjects];
  if (client_) {
    [pluginList_ addObjectsFromArray:[client_ plugins]];

    // Counts of all plugins and which ones are enabled and disabled
    int all = 0;
    int on = 0;
    int off = 0;
    BOOL previousExists = NO;
    for (QSBPlugin *currentPlugin in pluginList_) {
      [plugin_ addItemWithTitle:[currentPlugin displayName]];
      if ([previous isEqualToString:[currentPlugin displayName]]) {
        previousExists = YES;
      }
      if ([currentPlugin enabled]) {
        on++;
      } else {
        off++;
      }
      all++;
    }

    [numberOfPlugins_ setStringValue:[NSString stringWithFormat:@"%d", all]];
    [enabledPlugins_ setStringValue:[NSString stringWithFormat:@"%d", on]];
    [disabledPlugins_ setStringValue:[NSString stringWithFormat:@"%d", off]];
    [plugin_ setEnabled:YES];
    [pluginState_ setEnabled:YES];
    if (previousExists) {
      [plugin_ selectItemWithTitle:previous];
    }
    [self selectedPlugin:plugin_];
  }
}

- (void)awakeFromNib {
  // Fill in default settings
  [hostname_ setStringValue:@"localhost"];
  [port_ setStringValue:[NSString stringWithFormat:@"%d", kTransferencePort]];

  [self disableOptionsForDisconnect];
}

#pragma mark -- TransferenceClient delegate methods --

- (void)searchDidComplete {
  NSTimeInterval lastSearch = [client_ lastSearchTime];
  NSInteger results = [client_ numberOfSearchResults];

  NSString *lastSearchString =
    [NSString stringWithFormat:@"%f seconds", lastSearch];
  NSString *numberOfResultsString =
    [NSString stringWithFormat:@"%d", results];

  [lastSearchTime_ setStringValue:lastSearchString];
  [numberOfResults_ setStringValue:numberOfResultsString];
}

#pragma mark -- Public methods --

- (IBAction)connect:(NSButton *)sender {
  if ([[sender title] isEqualToString:@"Connect"]) {
    unsigned short port = [[port_ stringValue] intValue];
    client_ =
      [[TransferenceClient alloc] initWithAddress:[hostname_ stringValue]
                                             port:port];
    if (client_) {
      [client_ subscribeToServer];
      [client_ setDelegate:self];
      [QSBVersion_ setStringValue:[client_ QSBVersion]];
      NSString *hostInfo = [NSString stringWithFormat:@"%@ %@",
                            [client_ hostMacOSXVersionString],
                            [client_ hostArchitecture]];
      [hostOSVersion_ setStringValue:hostInfo];
      [QSBStartupTime_ setStringValue:[[client_ startupTime] description]];
      [self reloadPlugins];
      [sender setTitle:@"Disconnect"];
    }
  } else {
    [client_ unsubscribeFromServer];
    [client_ release];
    client_ = nil;
    [sender setTitle:@"Connect"];
    [self disableOptionsForDisconnect];
  }
}

- (IBAction)selectedPlugin:(NSPopUpButton *)sender {
  NSString *plugin = [sender titleOfSelectedItem];
  for (QSBPlugin *currentPlugin in pluginList_) {
    if ([plugin isEqualToString:[currentPlugin displayName]]) {
      if ([currentPlugin enabled]) {
        [pluginState_ setState:NSOnState];
      } else {
        [pluginState_ setState:NSOffState];
      }
      break;
    }
  }
}

- (IBAction)updatePluginState:(NSButton *)sender {
  NSString *plugin = [plugin_ titleOfSelectedItem];
  for (QSBPlugin *currentPlugin in pluginList_) {
    if ([plugin isEqualToString:[currentPlugin displayName]]) {
      if ([sender state] == NSOnState) {
        [currentPlugin setEnabled:YES];
      } else {
        [currentPlugin setEnabled:NO];
      }
      break;
    }
  }
  [self reloadPlugins];
}
@end
