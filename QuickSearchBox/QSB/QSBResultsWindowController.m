//
//  QSBResultsWindowController.m
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

#import "QSBResultsWindowController.h"

#import <Vermilion/Vermilion.h>
#import <GTM/GTMTypeCasting.h>
#import <GTM/GTMNSAnimation+Duration.h>
#import <GTM/GTMMethodCheck.h>

#import "QSBAnimatedScroll.h"
#import "QSBCustomPanel.h"
#import "QSBSearchWindowController.h"
#import "QSBSearchController.h"
#import "QSBFlippedView.h"
#import "QSBTopResultsViewController.h"
#import "QSBMoreResultsViewController.h"
#import "QSBResultsViewTableView.h"
#import "QSBTableResult.h"
#import "QSBHGSResultAttributeKeys.h"
#import "QSBActionPresenter.h"

@interface QSBResultsViewControllerTrio : NSObject {
 @private
  QSBTopResultsViewController *topResultsViewController_;
  QSBMoreResultsViewController *moreResultsViewController_;
  QSBResultsViewBaseController *activeResultsViewController_;
}

@property(nonatomic, readonly, retain) QSBTopResultsViewController *topResultsViewController;
@property(nonatomic, readonly, retain) QSBMoreResultsViewController *moreResultsViewController;
@property(nonatomic, readwrite, assign) QSBResultsViewBaseController *activeResultsViewController;

- (id)initWithSearchController:(QSBSearchController *)controller;

@end

@interface QSBResultsWindowController ()
- (void)animatedScrollToPoint:(NSPoint)point
                     userInfo:(id<NSObject>)userInfo;
- (QSBResultsViewBaseController *)activeResultsViewController;
- (void)setActiveResultsViewController:(QSBResultsViewBaseController *)controller;
- (QSBTopResultsViewController *)currentTopResultsViewController;
- (QSBMoreResultsViewController *)currentMoreResultsViewController;
- (QSBResultsViewControllerTrio *)currentResultsViewControllerTrio;
- (void)actionPresenterDidReset:(NSNotification *)notification;
- (void)actionPresenterWillPivot:(NSNotification *)notification;
- (void)actionPresenterDidPivot:(NSNotification *)notification;
- (void)actionPresenterWillUnpivot:(NSNotification *)notification;
- (void)actionPresenterDidUnpivot:(NSNotification *)notification;
- (void)updateWindowHeightBasedOnTable:(QSBResultTableView *)tableView;
- (void)tableViewDidReloadData:(NSNotification *)notification;
- (void)tableViewSelectionDidChange:(NSNotification *)notification;
- (void)updateTableHeight:(NSTimer *)timer;
@end

@implementation QSBResultsWindowController

GTM_METHOD_CHECK(NSAnimationContext, gtm_setDuration:eventMask:);
GTM_METHOD_CHECK(NSAnimation, gtm_setDuration:eventMask:);

@synthesize actionPresenter = actionPresenter_;

#pragma mark Instantiation

- (id)init {
  if ((self = [super initWithWindowNibName:@"QSBResultsWindow"])) {
    resultsViewControllerTrios_ = [[NSMutableArray alloc] init];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [resultsViewControllerTrios_ release];
  [pivotAnimation_ release];
  [resetWindowSizeTimer_ invalidate];
  resetWindowSizeTimer_ = nil;
  [super dealloc];
}


#pragma mark Overrides

- (void)windowDidLoad {
  HGSAssert(searchWindowController_ != nil,
            @"Did you forget to hook up searchWindowController_ in the nib?");
  QSBCustomPanel *window = (QSBCustomPanel*)[self window];
  [window setCanBecomeKeyWindow:NO];
  [window setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
  [window setAlphaValue:0];
  [window setLevel:kCGStatusWindowLevel + 1];
  [window orderFront:self];
  [window setIgnoresMouseEvents:YES];

  [resultsView_ setAutoresizesSubviews:NO];
  [resultsView_ setFrame:NSZeroRect];

  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(actionPresenterDidReset:)
             name:kQSBActionPresenterDidResetNotification
           object:actionPresenter_];
  [nc addObserver:self
         selector:@selector(actionPresenterWillPivot:)
             name:kQSBActionPresenterWillPivotNotification
           object:actionPresenter_];
  [nc addObserver:self
         selector:@selector(actionPresenterDidPivot:)
             name:kQSBActionPresenterDidPivotNotification
           object:actionPresenter_];
  [nc addObserver:self
         selector:@selector(actionPresenterWillUnpivot:)
             name:kQSBActionPresenterWillUnpivotNotification
           object:actionPresenter_];
  [nc addObserver:self
         selector:@selector(actionPresenterDidUnpivot:)
             name:kQSBActionPresenterDidUnpivotNotification
           object:actionPresenter_];

  QSBSearchController *controller = [actionPresenter_ activeSearchController];
  pivotTrio_
    = [[[QSBResultsViewControllerTrio alloc]
        initWithSearchController:controller] autorelease];
  [resultsViewControllerTrios_ addObject:pivotTrio_];
  [self actionPresenterDidPivot:nil];
}

#pragma mark Public Methods

- (QSBTableResult *)selectedTableResult {
  return [[self activeResultsViewController] selectedTableResult];
}

- (NSTableView *)activeTableView {
  return [[self activeResultsViewController] resultsTableView];
}

#pragma mark Private Methods

- (void)animatedScrollToPoint:(NSPoint)point
                     userInfo:(id<NSObject>)userInfo {
  [pivotAnimation_ stopAnimation];
  [pivotAnimation_ release];
  pivotAnimation_ = [[QSBAnimatedScroll alloc] initWithView:resultsView_
                                                   endPoint:point];
  [pivotAnimation_ setDelegate:self];
  [pivotAnimation_ setUserInfo:userInfo];
  [pivotAnimation_ gtm_setDuration:[pivotAnimation_ duration]
                         eventMask:kGTMLeftMouseUpAndKeyDownMask];
  [pivotAnimation_ startAnimation];
}

- (QSBResultsViewControllerTrio *)currentResultsViewControllerTrio {
  return [resultsViewControllerTrios_ lastObject];
}

- (QSBResultsViewBaseController *)activeResultsViewController {
  return [[self currentResultsViewControllerTrio] activeResultsViewController];
}

- (void)setActiveResultsViewController:(QSBResultsViewBaseController *)controller {
  // Remove any old observers.
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self
                name:NSTableViewSelectionDidChangeNotification
              object:nil];
  [nc removeObserver:self
                name:kQSBResultTableViewDidReloadData
              object:nil];
  NSResponder *nextResponder = [self nextResponder];
  if ([nextResponder isKindOfClass:[QSBResultsViewBaseController class]]) {
    QSBResultsViewBaseController *oldActiveResultsViewController
      = (QSBResultsViewBaseController *)nextResponder;
    nextResponder = [oldActiveResultsViewController nextResponder];
    [oldActiveResultsViewController setNextResponder:nil];
  }

  if (controller) {
    [controller setNextResponder:nextResponder];
    [self setNextResponder:controller];
    QSBResultTableView *tableView = [controller resultsTableView];
    [[self window] makeFirstResponder:tableView];
    [nc addObserver:self
           selector:@selector(tableViewSelectionDidChange:)
               name:NSTableViewSelectionDidChangeNotification
             object:tableView];
    [nc addObserver:self
           selector:@selector(tableViewDidReloadData:)
               name:kQSBResultTableViewDidReloadData
             object:tableView];
    [[self currentResultsViewControllerTrio] setActiveResultsViewController:controller];
    NSNotification *notification
      = [NSNotification notificationWithName:NSTableViewSelectionDidChangeNotification
                                      object:tableView];
    [self tableViewSelectionDidChange:notification];
    // If there are any views overlapping our controller view, move them out
    // of the way so that the controller view is unobscured.
    NSView *view = [controller view];
    if (view) {
      NSRect viewFrame = [view frame];
      NSArray *siblingViews = [[view superview] subviews];
      for (NSView *sibling in siblingViews) {
        if (view != sibling) {
          NSRect siblingFrame = [sibling frame];
          if (NSIntersectsRect(viewFrame, siblingFrame)) {
            siblingFrame = NSOffsetRect(siblingFrame, NSWidth(viewFrame), 0);
            [sibling setFrame:siblingFrame];
          }
        }
      }
    }
    [self updateWindowHeightBasedOnTable:tableView];
  } else {
    [self setNextResponder:nextResponder];
  }
}

- (QSBTopResultsViewController *)currentTopResultsViewController{
  return [[self currentResultsViewControllerTrio] topResultsViewController];
}

- (QSBMoreResultsViewController *)currentMoreResultsViewController{
  return [[self currentResultsViewControllerTrio] moreResultsViewController];
}

- (void)updateWindowHeightBasedOnTable:(QSBResultTableView *)tableView {
  [resetWindowSizeTimer_ invalidate];
  resetWindowSizeTimer_
    = [NSTimer scheduledTimerWithTimeInterval:0.3
                                       target:self
                                     selector:@selector(updateTableHeight:)
                                     userInfo:tableView
                                      repeats:NO];
}

#pragma mark Responder Chain Actions

- (void)qsb_showMoreResults:(id)sender {
  QSBMoreResultsViewController *moreResultsViewController
    = [self currentMoreResultsViewController];
  NSView *moreResultsView = [moreResultsViewController view];
  NSScrollView *scrollView = [resultsView_ enclosingScrollView];
  NSRect visibleRect = [scrollView documentVisibleRect];
  NSRect moreFrame = [moreResultsView frame];
  if (!(NSEqualPoints(moreFrame.origin, visibleRect.origin))) {
    QSBTopResultsViewController *topResultsViewController
      = [self currentTopResultsViewController];
    NSView *topResultsView = [topResultsViewController view];
    NSRect topFrame = [topResultsView frame];
    QSBResultTableView *moreTableView
      = [moreResultsViewController resultsTableView];
    CGFloat height = [moreTableView tableHeight];
    moreFrame = NSMakeRect(NSMinX(topFrame),
                           NSMinY(topFrame) + height,
                           NSWidth(visibleRect),
                           height);
    [moreResultsView setFrame:moreFrame];

    NSRect resultsFrame = [resultsView_ frame];
    BOOL updateFrame = NO;
    if (NSMaxX(resultsFrame) < NSMaxX(moreFrame)) {
      resultsFrame.size.width = NSMaxX(moreFrame);
      updateFrame = YES;
    }
    if (NSMaxY(resultsFrame) < NSMaxY(moreFrame)) {
      resultsFrame.size.height = NSMaxY(moreFrame);
      updateFrame = YES;
    }
    if (updateFrame) {
      [resultsView_ setFrame:resultsFrame];
    }

    [self setActiveResultsViewController:moreResultsViewController];
    [self animatedScrollToPoint:moreFrame.origin userInfo:nil];
  }
}

- (void)qsb_showTopResults:(id)sender {
  QSBTopResultsViewController *topResultsViewController
    = [self currentTopResultsViewController];
  NSView *topResultsView = [topResultsViewController view];
  NSScrollView *scrollView = [resultsView_ enclosingScrollView];
  NSRect visibleRect = [scrollView documentVisibleRect];
  NSRect topFrame = [topResultsView frame];
  if (!(NSEqualPoints(topFrame.origin, visibleRect.origin))) {
    QSBMoreResultsViewController *moreResultsViewController
      = [self currentMoreResultsViewController];
    NSView *moreResultsView = [moreResultsViewController view];
    NSRect moreFrame = [moreResultsView frame];
    QSBResultTableView *topTableView
      = [topResultsViewController resultsTableView];
    CGFloat height = [topTableView tableHeight];
    topFrame = NSMakeRect(NSMinX(moreFrame),
                          NSMinY(moreFrame) - height,
                          NSWidth(visibleRect),
                          height);
    [topResultsView setFrame:topFrame];
    [self setActiveResultsViewController:topResultsViewController];
    [self animatedScrollToPoint:topFrame.origin userInfo:nil];
  }
}

- (IBAction)hideResultsWindow:(id)sender {
  NSWindow *window = [self window];
  if ([window ignoresMouseEvents]) return;

  [window setIgnoresMouseEvents:YES];

  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] gtm_setDuration:kQSBHideDuration
                                             eventMask:kGTMLeftMouseUpAndKeyDownMask];
  [[window animator] setAlphaValue:0.0];
  [NSAnimationContext endGrouping];
}

- (IBAction)showResultsWindow:(id)sender {
  NSWindow *window = [self window];
  if (![window ignoresMouseEvents]) return;
  [window setIgnoresMouseEvents:NO];
  if (![window parentWindow]) {
    NSWindow *searchWindow = [searchWindowController_ window];
    [searchWindow addChildWindow:window ordered:NSWindowBelow];
  }
  NSRect frame = [window frame];
  [NSAnimationContext beginGrouping];
  [[NSAnimationContext currentContext] gtm_setDuration:kQSBShowDuration
                                             eventMask:kGTMLeftMouseUpAndKeyDownMask];
  [[window animator] setAlphaValue:1.0];
  NSRect newFrame
    = [searchWindowController_ setResultsWindowFrameWithHeight:NSHeight(frame)];
  QSBResultsViewBaseController *activeResultsViewController
    = [self activeResultsViewController];
  NSView *resultsView = [activeResultsViewController view];
  frame = [resultsView frame];
  frame.size.width = NSWidth(newFrame);
  [resultsView setFrame:frame];
  [NSAnimationContext endGrouping];
}

- (IBAction)pathControlClick:(id)sender {
  QSBResultsViewBaseController *controller
    = [[self currentResultsViewControllerTrio] activeResultsViewController];
  [controller pathControlClick:sender];
}

#pragma mark Notifications

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  NSTableView *tableView = GTM_STATIC_CAST(NSTableView, [notification object]);
  NSInteger row = [tableView selectedRow];
  if (row < 0) {
    if ([tableView numberOfRows]) {
      NSIndexSet *zeroSet = [NSIndexSet indexSetWithIndex:0];
      [tableView selectRowIndexes:zeroSet byExtendingSelection:NO];
      row = 0;
    }
  }
  NSCell *cell = [tableView preparedCellAtColumn:0 row:row];
  QSBTableResult *tableResult = GTM_STATIC_CAST(QSBTableResult,
                                                [cell representedObject]);
  NSArray *cellValues = nil;
  if ([tableResult respondsToSelector:@selector(representedResult)]) {
    HGSScoredResult *result
      = [(QSBSourceTableResult *)tableResult representedResult];
    cellValues = [result valueForKey:kQSBObjectAttributePathCellsKey];
  }
  [statusBar_ setObjectValue:cellValues];

  NSDictionary *userInfo = nil;
  if (tableResult) {
    userInfo = [NSDictionary dictionaryWithObject:tableResult
                                           forKey:kQSBSelectedTableResultKey];
  }
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kQSBSelectedTableResultDidChangeNotification
                    object:self
                  userInfo:userInfo];
}

- (void)tableViewDidReloadData:(NSNotification *)notification {
  [self tableViewSelectionDidChange:notification];
  QSBResultsViewTableView *tableView = GTM_STATIC_CAST(QSBResultsViewTableView,
                                                       [notification object]);
  [self updateWindowHeightBasedOnTable:tableView];
}

- (void)actionPresenterDidReset:(NSNotification *)notification {
  [self setActiveResultsViewController:nil];
  [resultsViewControllerTrios_ removeAllObjects];
  QSBActionPresenter *presenter = [notification object];
  QSBSearchController *controller = [presenter activeSearchController];
  pivotTrio_
    = [[[QSBResultsViewControllerTrio alloc]
        initWithSearchController:controller] autorelease];
  [resultsViewControllerTrios_ addObject:pivotTrio_];
  [self actionPresenterDidPivot:nil];
}

- (void)actionPresenterWillPivot:(NSNotification *)notification {
  HGSAssert(!pivotTrio_, nil);
  pivotTrio_ = [self currentResultsViewControllerTrio];
  NSDictionary *userInfo = [notification userInfo];
  QSBSearchController *controller
    = [userInfo objectForKey:kQSBNewSearchControllerKey];
  QSBResultsViewControllerTrio *newTrio
    = [[[QSBResultsViewControllerTrio alloc]
        initWithSearchController:controller] autorelease];
  [resultsViewControllerTrios_ addObject:newTrio];
}

- (void)actionPresenterDidPivot:(NSNotification *)notification {
  // Add topview
  QSBTopResultsViewController *topController
    = [self currentTopResultsViewController];
  NSView *topView = [topController view];
  [resultsView_ addSubview:topView positioned:NSWindowAbove relativeTo:nil];

  // Align our new view with the current view
  NSPoint origin = NSZeroPoint;
  NSScrollView *scrollView = [resultsView_ enclosingScrollView];
  NSRect visibleRect = [scrollView documentVisibleRect];
  QSBResultsViewBaseController *activeController
    = [pivotTrio_ activeResultsViewController];
  NSView *tableScrollView = [activeController view];
  QSBResultTableView *tableView = [activeController resultsTableView];
  if (tableScrollView) {
    NSRect scrollRect = [tableScrollView frame];
    origin = scrollRect.origin;
    origin.x += NSWidth(visibleRect);
  }
  CGFloat height = [tableView tableHeight];
  NSRect topFrame = NSMakeRect(origin.x, origin.y,
                               visibleRect.size.width, height);
  [topView setFrame:topFrame];

  NSRect resultsFrame = [resultsView_ frame];
  BOOL updateFrame = NO;
  if (NSMaxX(resultsFrame) < NSMaxX(topFrame)) {
    resultsFrame.size.width = NSMaxX(topFrame);
    updateFrame = YES;
  }
  if (NSMaxY(resultsFrame) < NSMaxY(topFrame)) {
    resultsFrame.size.height = NSMaxY(topFrame);
    updateFrame = YES;
  }
  if (updateFrame) {
    [resultsView_ setFrame:resultsFrame];
  }

  // Add moreview
  QSBMoreResultsViewController *moreController
    = [self currentMoreResultsViewController];
  NSView *moreView = [moreController view];
  [resultsView_ addSubview:moreView positioned:NSWindowBelow relativeTo:nil];
  [self setActiveResultsViewController:topController];
  [self animatedScrollToPoint:topFrame.origin userInfo:nil];
  pivotTrio_ = nil;
}

- (void)actionPresenterWillUnpivot:(NSNotification *)notification {
  HGSAssert(!pivotTrio_, nil);
  pivotTrio_ = [[self currentResultsViewControllerTrio] retain];
  [resultsViewControllerTrios_ removeLastObject];
}

- (void)actionPresenterDidUnpivot:(NSNotification *)notification {
  HGSAssert(pivotTrio_, nil);
  QSBResultsViewBaseController *newViewController
    = [self activeResultsViewController];
  NSView *newView = [newViewController view];
  NSScrollView *scrollView = [resultsView_ enclosingScrollView];
  NSRect visibleRect = [scrollView documentVisibleRect];

  // Align our new view with the current view
  NSPoint origin = NSZeroPoint;
  NSView *tableScrollView = [[pivotTrio_ activeResultsViewController] view];
  NSRect scrollRect = [tableScrollView frame];
  origin = scrollRect.origin;
  origin.x -= NSWidth(visibleRect);
  QSBResultTableView *newTableView = [newViewController resultsTableView];
  NSRect newFrame = NSMakeRect(origin.x,
                               origin.y,
                               visibleRect.size.width,
                               [newTableView tableHeight]);
  [newView setFrame:newFrame];

  [self setActiveResultsViewController:newViewController];

  // Reset the selection so that the tableview sends out a
  // NSTableViewSelectionDidChangeNotification notification.
  NSInteger selectedRow = [newTableView selectedRow];
  [newTableView deselectRow:selectedRow];
  [newTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow]
            byExtendingSelection:NO];
  [self animatedScrollToPoint:newFrame.origin
                     userInfo:pivotTrio_];
  [pivotTrio_ release];
  pivotTrio_ = nil;
}

#pragma mark Timer Callbacks

- (void)updateTableHeight:(NSTimer *)timer {
  HGSCheckDebug(timer == resetWindowSizeTimer_, @"");
  QSBResultTableView *tableView = GTM_STATIC_CAST(QSBResultTableView,
                                                  [timer userInfo]);

  // Extra Window Height
  NSWindow *window = [self window];
  NSRect windowFrame = [window frame];
  NSRect resultsScrollFrame = [[resultsView_ enclosingScrollView] frame];
  NSRect statusFrame = [statusBar_ frame];
  CGFloat resultsScrollMaxY = NSMaxY(resultsScrollFrame);
  CGFloat statusMaxY = NSMaxY(statusFrame);
  CGFloat windowHeight = NSHeight(windowFrame);
  CGFloat extraWindowHeight = windowHeight - resultsScrollMaxY + statusMaxY;

  // Get our new height
  CGFloat height = [tableView tableHeight];

  // Set our scroll frame (upper left)
  NSScrollView *scrollView = [tableView enclosingScrollView];
  NSRect scrollFrame = [scrollView frame];
  scrollFrame.size.height = height;

  // Set our results view frame (upper left)
  NSRect resultsFrame = [resultsView_ frame];
  if (NSHeight(resultsFrame) < height) {
    resultsFrame.size.height = height;
    [resultsView_ setFrame:resultsFrame];
  }

  // Window frame (lower left)
  NSRect contentRect = NSMakeRect(0,
                                  0,
                                  NSWidth(scrollFrame),
                                  height + extraWindowHeight);
  CGFloat top = NSMaxY(windowFrame);
  windowFrame.size = contentRect.size;
  windowFrame.origin.y = top - NSHeight(windowFrame);
  [NSAnimationContext beginGrouping];
  NSAnimationContext *current = [NSAnimationContext currentContext];
  [current gtm_setDuration:0.2 eventMask:NSAnyEventMask];
  [[scrollView animator] setFrame:scrollFrame];
  [[window animator] setFrame:windowFrame display:YES];
  [NSAnimationContext endGrouping];
  [resetWindowSizeTimer_ invalidate];
  resetWindowSizeTimer_ = nil;
}
@end

@implementation QSBResultsViewControllerTrio

@synthesize topResultsViewController = topResultsViewController_;
@synthesize moreResultsViewController = moreResultsViewController_;
@synthesize activeResultsViewController = activeResultsViewController_;

- (id)initWithSearchController:(QSBSearchController *)controller {
  if ((self = [super init])) {
    topResultsViewController_
      = [[QSBTopResultsViewController alloc] initWithSearchController:controller];
    moreResultsViewController_
      = [[QSBMoreResultsViewController alloc] initWithSearchController:controller];
    activeResultsViewController_ = topResultsViewController_;
  }
  return self;
}

- (void)dealloc {
  // We want the views that these controllers are controlling to be removed
  // from their view, since their controller is going away. Can't have
  // uncontrolled views running around haphazardly.
  [[topResultsViewController_ view] removeFromSuperview];
  [[moreResultsViewController_ view] removeFromSuperview];
  [topResultsViewController_ release];
  [moreResultsViewController_ release];
  [super dealloc];
}

@end
