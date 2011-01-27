//
//  QSBQueryController.m
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

#import "QSBQueryController.h"
#import "QSBApplicationDelegate.h"
#import "QSBMoreResultsViewDelegate.h"
#import "QSBQuery.h"
#import "QSBTableResult.h"
#import "QSBResultsViewBaseController.h"
#import "QSBSearchWindowController.h"
#import "QSBTopResultsViewDelegate.h"
#import "HGSObject.h"

NSString *const kScrollViewHiddenKeyPath = @"hidden";

@interface QSBQueryController (QSBSearchWindowControllerPrivate)

// Return the currently selected results object.
- (QSBTableResult *)selection;

// Setter for specifying the active results view controller.
- (void)setActiveResultsViewController:(QSBResultsViewBaseController *)value
                               animate:(BOOL)animate;


- (void)updateViewsWithAnimation:(BOOL)animate;

@end


@implementation QSBQueryController
@synthesize searchWindowController = searchWindowController_;
@synthesize savedPivotQueryString = pivotQueryString_;
@synthesize savedPivotQueryRange = pivotQueryRange_;

- (id)initWithNibName:(NSString *)nibName
     windowController:(QSBSearchWindowController *)searchWindowController {
  if ((self = [super initWithNibName:nibName bundle:nil])) {
    [self setSearchWindowController:searchWindowController];
    // TODO(alcor): this should be removed, but much of the searchWindow code
    // assumes the nib connections are intact when this method returns
    [self loadView];
  }
  return self;
}

- (void)awakeFromNib {
    [self setActiveResultsViewController:topResultsController_ animate:NO];
}

- (void)dealloc {
  [parentQueryController_ release];
  [pivotQueryString_ release];
  [searchWindowController_ release];
  [super dealloc];
}

- (void)setParentQueryController:(QSBQueryController *)parentQueryController {
  [parentQueryController_ autorelease];
  parentQueryController_ = [parentQueryController retain];
  [query_ setParentQuery:[parentQueryController query]];
  QSBSourceTableResult *selectedObject 
    = (QSBSourceTableResult *)[parentQueryController selectedObject];
  HGSAssert(!selectedObject 
            || [selectedObject isKindOfClass:[QSBSourceTableResult class]],
            @"expected a QSBSourceTableResult and got %@", selectedObject);
  [self setPivotObject:[selectedObject representedObject]];
}

- (QSBQueryController *)parentQueryController {
  return parentQueryController_;
}

- (QSBResultsViewBaseController *)activeResultsViewController {
  return activeResultsViewController_;
}

- (QSBTopResultsViewDelegate *)topResultsController {
  return [[topResultsController_ retain] autorelease];
}

- (QSBMoreResultsViewDelegate *)moreResultsController {
  return [[moreResultsController_ retain] autorelease];
}
  
- (void)updateResultsViewNow {
  // Mark all results controllers as needing to be updated.
  [topResultsController_ setResultsNeedUpdating:YES];
  [moreResultsController_ setResultsNeedUpdating:YES];
  
  // Immediately update the active controller and determine window height.
  [[self activeResultsViewController] updateResultsView];
}

- (void)updateResultsView {
  [searchWindowController_ updateResultsView];
}

- (void)stopQuery {
  [query_ stopQuery];
}

- (CGFloat)windowHeight {
  return [[self activeResultsViewController] windowHeight]
    + NSHeight([statusBar_ bounds]);
}

- (QSBQuery *)query {
  return query_;
}

- (void)setQueryString:(NSString *)queryString {
  [query_ setQueryString:queryString];
  if ([self activeResultsViewController] != topResultsController_) {
    [self showTopResults:self];
  } else {
    // If we don't need to swap views, at least update the view locations
    // in case they have shifted
    // TODO(alcor): this causes the wrong size to be set. Fix
    //[self updateViewsWithAnimation:NO];
  }
}

- (NSString*)queryString {
  NSString *queryString = [query_ queryString];
  return queryString;
}

- (QSBTableResult *)selectedObject {
  QSBTableResult *result = [[self activeResultsViewController] selectedObject];
  return result;
}

- (void)setPivotObject:(HGSObject *)pivotObject {
  [query_ setPivotObject:pivotObject];
}

- (HGSObject *)pivotObject {
  return [query_ pivotObject];
}

- (void)performAction:(id<HGSAction>)action
            forObject:(HGSObject *)object {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSMutableDictionary *userInfo 
    = [NSMutableDictionary dictionaryWithObjectsAndKeys:
       object, kQSBNotificationDirectObjectKey,
       query_, kQSBNotificationQueryKey,
       nil];
  [nc postNotificationName:kQSBQueryControllerWillPerformActionNotification
                    object:action
                  userInfo:userInfo];
  HGSActionOperation *op = [[[HGSActionOperation alloc] initWithAction:action
                                                         primaryObject:object] 
                            autorelease];
  NSDictionary *result = [op performAction];
  NSNumber *success = [result objectForKey:kHGSActionCompletedSuccessfully];
  if (![success boolValue]) {
    NSBeep();
    HGSLog(@"Action failed %@", action);
  }
  [userInfo setObject:success forKey:kQSBNotificationSuccessKey];
  [nc postNotificationName:kQSBQueryControllerDidPerformActionNotification
                    object:action
                  userInfo:userInfo];  
}

- (BOOL)performDefaultActionOnSelectedRow {
  QSBTableResult *result = [self selectedObject];
  return [result performDefaultActionWithQueryController:self];
}

- (BOOL)performSelectionMovementSelector:(SEL)selector {
  BOOL acceptable = [[self activeResultsViewController]
                     performSelectionMovementSelector:selector];
  return acceptable;
}

#pragma mark Top/More Results View Control

- (void)showTopResults:(id)sender {
  [self setActiveResultsViewController:topResultsController_ animate:YES];
}

- (void)showMoreResults:(id)sender {
  [self setActiveResultsViewController:moreResultsController_ animate:YES];
}

- (void)toggleTopMoreViews {
  if (activeResultsViewController_ == topResultsController_) {
    [self showMoreResults:self];
  } else {
    [self showTopResults:self];
  }
}

- (void)reset {
  // Give our results view controllers a chance to reset.
  [topResultsController_ reset];
  [moreResultsController_ reset];
}

@end


@implementation QSBQueryController (QSBSearchWindowControllerPrivate)

- (QSBTableResult *)selection {
  QSBTableResult *result = [[self activeResultsViewController] selectedObject];
  return result;
}

- (void)updateViewsWithAnimation:(BOOL)animate {

  CGFloat newHeight = [[self activeResultsViewController] windowHeight];
  
  int resizingMask = NSViewWidthSizable | NSViewHeightSizable;
  int pinToTopMask = NSViewWidthSizable | NSViewMinYMargin;

  NSView *topView = [topResultsController_ view];
  NSView *moreView = [moreResultsController_ view];
  
  [topView setAutoresizingMask:pinToTopMask];
  [moreView setAutoresizingMask:pinToTopMask];
  [searchWindowController_ setResultsWindowHeight:newHeight
                                                 + NSHeight([statusBar_ bounds])
                                        animating:NO];
  [topView setAutoresizingMask:resizingMask];
  [moreView setAutoresizingMask:resizingMask];
  
  NSRect viewBounds = [[self view] bounds];
  viewBounds.origin.y += NSHeight([statusBar_ bounds]);
  viewBounds.size.height -= NSHeight([statusBar_ bounds]);
  
  NSRect topFrame = [topView frame];
  NSRect moreFrame = [moreView frame];
  
  if ([self activeResultsViewController] == moreResultsController_) { 
    [moreView setHidden:NO];
    moreFrame = viewBounds;
    
    if (![moreView superview]) {
      [[self view] addSubview:moreView 
                   positioned:NSWindowBelow
                   relativeTo:topView];
      NSRect moreStartFrame = moreFrame;
      moreStartFrame.origin.y = topFrame.origin.y - NSHeight(moreFrame);
      [moreView setFrame:moreStartFrame];
    }
    topFrame.origin.y = NSMaxY(viewBounds);   
    [topView setAutoresizingMask:pinToTopMask];
  } else {
    topFrame = viewBounds;
    moreFrame = viewBounds;
    moreFrame.origin.y = NSMinY(viewBounds) - NSHeight(moreFrame);
  }
  
  topResultsFrame_ = topFrame;
  moreResultsFrame_ = moreFrame;

  if (animate) {
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.2];
    [[topView animator] setFrame:topResultsFrame_];
    [[moreView animator] setFrame:moreResultsFrame_];
    [NSAnimationContext endGrouping];
  } else {
    [topView setFrame:topResultsFrame_];
    [moreView setFrame:moreResultsFrame_];
  }
}

- (void)setActiveResultsViewController:(QSBResultsViewBaseController *)newController
                               animate:(BOOL)animate{
  
  if (activeResultsViewController_ != newController) {
    [newController updateResultsView];
    
    // Swap out the old view while swapping in the top results view.
    [newController setSwapSelection];
  
    [searchWindowController_ completeQueryText];
    [self willChangeValueForKey:@"activeResultsViewController"];
    activeResultsViewController_ = newController;
    [self didChangeValueForKey:@"activeResultsViewController"];
    [self updateViewsWithAnimation:animate];
  }
}
@end
