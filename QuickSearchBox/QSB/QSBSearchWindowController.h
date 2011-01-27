//
//  QSBSearchWindowController.h
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

#import <Cocoa/Cocoa.h>
#import "GTMDefines.h"

@class QSBTextField;
@class QSBMenuButton;
@class QSBCustomPanel;
@class QSBWelcomeController;
@class QSBResultsWindowController;
@class QSBActionPresenter;
@class HGSResultArray;

extern const NSTimeInterval kQSBAppearDelay;
extern const NSTimeInterval kQSBShowDuration;
extern const NSTimeInterval kQSBHideDuration;

@interface QSBSearchWindowController : NSWindowController {
 @private
  IBOutlet QSBTextField *searchTextField_;
  IBOutlet NSImageView *logoView_;
  IBOutlet QSBMenuButton *windowMenuButton_;
  IBOutlet NSWindow *shieldWindow_;
  IBOutlet NSView *resultsOffsetterView_;
  IBOutlet NSImageView *thumbnailView_;
  IBOutlet QSBResultsWindowController *resultsWindowController_;
  IBOutlet QSBActionPresenter *actionPresenter_;
  
  BOOL needToUpdatePositionOnActivation_;  // Do we need to reposition
  // Resets our query to "" after kQSBResetQueryTimeoutPrefKey seconds
  __weak NSTimer *queryResetTimer_;
  // Shows our results window after a delay
  __weak NSTimer *displayResultsTimer_;
  // controls whether we put the pasteboard data in the qsb
  __weak NSTimer *findPasteBoardChangedTimer_;
  NSInteger findPasteBoardChangeCount_;  // used to detect if the pasteboard has changed
  BOOL insertFindPasteBoardString_;  // should we use the find pasteboard string
  // The welcome window controller.
  __weak QSBWelcomeController *welcomeController_;
}

// Designated initializer
- (id)init;

// Change search window visibility
- (IBAction)showSearchWindow:(id)sender;
- (IBAction)hideSearchWindow:(id)sender;

// Take a corpus from a menu item
- (IBAction)selectCorpus:(id)sender;

// Attempt to set the height of the results window while insuring that
// the results window fits comfortably on the screen along with the
// search box window.
- (NSRect)setResultsWindowFrameWithHeight:(CGFloat)height;

// Grab the selection from the Finder
- (IBAction)grabSelection:(id)sender;

// Drop the selection from the Finder on the current selection
- (IBAction)dropSelection:(id)sender;

// Reset the current query by unrolling all pivots, if any, and hiding the
// results window.  If no results are showing then hide the query window.
- (IBAction)qsb_clearSearchString:(id)sender;

// Just clears the search string.
- (IBAction)resetSearchString:(id)sender;

// Search for a string in the UI
- (void)searchForString:(NSString *)string;

// Select an object in the UI.
// SaveText - do we maintain the users current typing?
- (void)selectResults:(HGSResultArray *)results saveText:(BOOL)saveText;

// The hot key was hit.
- (void)hitHotKey:(id)sender;

@end
