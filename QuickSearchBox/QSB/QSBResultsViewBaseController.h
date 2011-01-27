//
//  QSBResultsViewBaseController.h
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

#import <Cocoa/Cocoa.h>

@class QSBResultsViewTableView;
@class QSBTableResult;
@class QSBSearchController;

// Abstract base class for the result views which manages the presentation
// of results in the Top Results and the More Results views.
@interface QSBResultsViewBaseController : NSViewController {
 @private
  IBOutlet QSBResultsViewTableView *resultsTableView_;
  QSBSearchController *searchController_;
}

@property (readonly, retain) QSBSearchController *searchController;

- (id)initWithSearchController:(QSBSearchController *)controller
                       nibName:(NSString *)nibName;

// Return the various views associated with this controller.
- (QSBResultsViewTableView *)resultsTableView;

// Return the last selected table item.
- (QSBTableResult *)selectedTableResult;

// For a given row in the table, return the associated QSBTableResult
- (QSBTableResult *)tableResultForRow:(NSInteger)row;

// Respond to a click in the path control.
- (IBAction)pathControlClick:(id)sender;

// Pick the currently selected table result.
- (IBAction)qsb_pickCurrentTableResult:(id)sender;

// Called when the results have been updated.
- (void)searchControllerDidUpdateResults:(NSNotification *)notification;

@end
