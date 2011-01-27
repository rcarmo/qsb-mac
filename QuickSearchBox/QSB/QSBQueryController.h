//
//  QSBQueryController.h
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
#import "GTMDefines.h"

@class QSBMoreResultsViewDelegate;
@class QSBQuery;
@class QSBResultsViewBaseController;
@class QSBSearchWindowController;
@class QSBTopResultsViewDelegate;
@class QSBTableResult;
@class HGSObject;
@protocol HGSAction;

// The controller associated with a particular query responsible for
// managing the relationship between this query and any previous query
// from which this was pivoted.  Manages the visual presentation of the
// results of the query.  Handles user interaction upon a result item
// for pivoting further or performing an action.
// TODO(mrossetti): Most of this was functionality was migrated from
// QSBSearchWindowController but there is still some more functionality
// to be moved.
//
@interface QSBQueryController : NSViewController {
 @private
  IBOutlet QSBQuery *query_;
  IBOutlet QSBTopResultsViewDelegate *topResultsController_;
  IBOutlet QSBMoreResultsViewDelegate *moreResultsController_;
  IBOutlet NSSplitView *splitView_;
  IBOutlet NSProgressIndicator *progressIndicator_;
  IBOutlet NSPathControl *statusBar_;
  QSBSearchWindowController *searchWindowController_;
  QSBResultsViewBaseController *activeResultsViewController_;  // Weak
  QSBQueryController *parentQueryController_;
  NSString *pivotQueryString_;  // What was typed when the user pivoted.
  NSRange pivotQueryRange_;  // What was selected when the user pivoted.
  NSRect topResultsFrame_;
  NSRect moreResultsFrame_;
}

@property(nonatomic, retain) QSBSearchWindowController *searchWindowController;
@property(nonatomic, copy) NSString *savedPivotQueryString;
@property(nonatomic, assign) NSRange savedPivotQueryRange;

// Initialize and install into the search results window.  Designated initializer.
- (id)initWithNibName:(NSString *)nibName
     windowController:(QSBSearchWindowController *)searchWindowController;

// Set/get this guy's parent QSBQueryController (i.e. the one from which
// this query was pivoted, if any.
- (void)setParentQueryController:(QSBQueryController *)parentQueryController;
- (QSBQueryController *)parentQueryController;

// Update active results views immediately.
- (void)updateResultsViewNow;

// Post a desire for the results views to be updated soon.
- (void)updateResultsView;

// Stop all source operations for this query.
- (void)stopQuery;

// Return the height of the results window necessary to accommodate
// the active view.
- (CGFloat)windowHeight;

// Show Top Results or More Results.
- (void)showTopResults:(id)sender;
- (void)showMoreResults:(id)sender;
- (void)toggleTopMoreViews;

// Reset our results views.
- (void)reset;

// query
- (QSBQuery *)query;

// Set/Get the search text string for our query.
- (void)setQueryString:(NSString *)queryString;
- (NSString *)queryString;

// Return the selected object from the active results controller.
- (QSBTableResult *)selectedObject;

// Set/get the pivot object for the query.
- (void)setPivotObject:(HGSObject *)pivotObject;
- (HGSObject *)pivotObject;

// Perform an action on an object.
- (void)performAction:(id<HGSAction>)action forObject:(HGSObject *)object;

// Perform the default action on the selected object in the active results controller.
- (BOOL)performDefaultActionOnSelectedRow;

// Change the selection, if acceptable, in the active results presentation.
- (BOOL)performSelectionMovementSelector:(SEL)selector;

// Return the active results view controller.
- (QSBResultsViewBaseController *)activeResultsViewController;

// Return the 'Top Results' view controller.
- (QSBTopResultsViewDelegate *)topResultsController;

// Return the 'More Results' view controller.
- (QSBMoreResultsViewDelegate *)moreResultsController;

@end

// Notifications for perform actions.
// Object is the action id<HGSAction>
// UserInfo keys
//   kQSBNotificationQueryKey - query that found the object that the action is 
//                             being performed on (QSBQuery)
//   kQSBNotificationDirectObjectKey - the direct object the action is being 
//                                     performed on(HGSObject)
//   kQSBNotificationIndirectObjectKey - the indirect object the action is 
//                                       being performed on(HGSObject)
//   kQSBNotificationSuccessKey - did the action complete successfully (NSNumber)
// object is the object the action is being performed on (HGSObject)
// WillPerform has QSBNotificationQueryKey and QSBNotificationActionKey
// DidPerform has QSBNotificationQueryKey, QSBNotificationActionKey, and 
// QSBNotificationSuccessKey
#define kQSBQueryControllerWillPerformActionNotification @"QSBQueryControllerWillPerformActionNotification"
#define kQSBQueryControllerDidPerformActionNotification @"QSBQueryControllerDidPerformActionNotification"
