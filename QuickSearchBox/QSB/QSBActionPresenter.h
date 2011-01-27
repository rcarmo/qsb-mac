//
//  QSBActionPresenter.h
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

#import <AppKit/AppKit.h>

/*!
 @header
 @discussion QSBActionPresenter
*/

@class QSBActionModel;
@class HGSResultArray;
@class QSBSearchController;
@class HGSActionOperation;
@class HGSActionArgument;
@class QSBTableResult;

/*!
 A presenter class in the Model-View-Presenter meaning of the term for an action
 being created by QSB. All interaction between the view and the model should
 go through this presenter.
*/
@interface QSBActionPresenter : NSResponder {
 @private
  QSBActionModel *actionModel_;
  HGSActionArgument *currentActionArgument_;
}

@property (readonly, nonatomic, assign) QSBSearchController *activeSearchController;
@property (readonly, nonatomic, retain) HGSActionOperation *actionOperation;
@property (readonly, nonatomic, assign) HGSActionArgument *currentActionArgument;
@property (readonly, nonatomic, retain) QSBTableResult *selectedTableResult;

/*! Designated initializer. */
- (id)initWithActionModel:(QSBActionModel *)model;

/*! 
 Reset our model by clearing the search controller stack, and resetting
 the action operation.
*/
- (void)reset;

/*! Return YES if we can pivot on the current table selection. */
- (BOOL)canPivot;

/*! Return YES if we can pivot on the current table selection. */
- (BOOL)canUnpivot;

/*! 
 Start a search with text getting pivotObjects from the current table selection.
*/
- (void)searchFor:(NSString *)text;

/*!
 Return an attributed string describing the current query for display to the 
 user.
*/
- (NSAttributedString *)pivotAttributedString;

/*!
 Force a pivot on the given objects.
*/
- (void)pivotOnObjects:(HGSResultArray *)pivotObjects;

/*!
 Request that the model attempt to perform its action based on the current
 table result (and whatever other arguments the user may have already selected.)
*/
- (IBAction)qsb_pickCurrentSourceTableResult:(id)sender;

/*!
 Request that the model attempt to pivot on the current selection.
*/
- (IBAction)qsb_pivotOnSelection:(id)sender;

/*!
 Request that the model attempt to unpivot on the current selection.
*/
- (IBAction)qsb_unpivotOnSelection:(id)sender;

/*!
 Request that the model stop with the current search, store it,
 and start a new search.
*/
- (IBAction)qsb_delimitResult:(id)sender;

@end

/*!
 Notifications for the action presenter resetting.
 Object is the action presenter that is resetting.
*/
#define kQSBActionPresenterWillResetNotification \
  @"QSBActionPresenterWillResetNotification"
#define kQSBActionPresenterDidResetNotification \
  @"QSBActionPresenterDidResetNotification"

/*!
 Notification that an action will be performed.
 If you want to know that an action did get performed, look for the
 HGSActionDidPerformNotification.
 Object is the actionPresenter
 UserInfo contains kQSBActioOperationnKey which is the action operation being 
 performed.
*/
#define kQSBActionPresenterWillPerformActionNotification \
  @"QSBActionPresenterWillPerformActionNotification"

/*!
 Key in the user info dictionary for 
 kQSBActionPresenterWillPerformActionNotification denoting the action being
 performed. HGSActionOperation.
*/
#define kQSBActionOperationKey @"QSBActionOperation"

/*!
 Notifications for pivoting
 Object is the QSBActionPresenter.
*/
#define kQSBActionPresenterWillPivotNotification @"QSBActionPresenterWillPivotNotification"
#define kQSBActionPresenterDidPivotNotification @"QSBActionPresenterDidPivotNotification"
#define kQSBActionPresenterWillUnpivotNotification @"QSBActionPresenterWillUnpivotNotification"
#define kQSBActionPresenterDidUnpivotNotification @"QSBActionPresenterDidUnpivotNotification"
#define kQSBOldSearchControllerKey @"QSBOldSearchControllerKey"
#define kQSBNewSearchControllerKey @"QSBNewSearchControllerKey"

