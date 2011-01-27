//
//  QSBResultsWindowController.h
//
//  Copyright (c) 2010 Google Inc. All rights reserved.
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

@class QSBSearchWindowController;
@class QSBActionPresenter;
@class QSBFlippedView;
@class QSBAnimatedScroll;
@class QSBResultsViewBaseController;
@class QSBTableResult;
@class QSBResultsViewControllerTrio;

@interface QSBResultsWindowController : NSWindowController <NSAnimationDelegate> {
 @private
  IBOutlet QSBSearchWindowController *searchWindowController_;
  IBOutlet QSBFlippedView *resultsView_;
  IBOutlet NSPathControl *statusBar_;
  IBOutlet QSBActionPresenter *actionPresenter_;
  QSBAnimatedScroll *pivotAnimation_;
  NSMutableArray *resultsViewControllerTrios_;
  QSBResultsViewControllerTrio *pivotTrio_;
  NSTimer *resetWindowSizeTimer_;
}

@property (readonly, assign) QSBActionPresenter *actionPresenter;

- (NSTableView *)activeTableView;
- (QSBTableResult *)selectedTableResult;

- (IBAction)hideResultsWindow:(id)sender;
- (IBAction)showResultsWindow:(id)sender;
- (IBAction)qsb_showTopResults:(id)sender;
- (IBAction)qsb_showMoreResults:(id)sender;
- (IBAction)pathControlClick:(id)sender;
@end

// Notification that the selected result did change.
// Object is the QSBResultsWindowController
// Userinfo keys:
//   QSBSelectedTableResultKey - the QSBTableResult if one is selected.
//
// If nothing is selected, there will be no QSBSelectedTableResultKey.
#define kQSBSelectedTableResultDidChangeNotification \
  @"QSBSelectedTableResultDidChangeNotification"
#define kQSBSelectedTableResultKey @"QSBSelectedTableResultKey"

