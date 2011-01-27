//
//  QSBActionModel.h
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

/*!
 @header
 @discussion QSBActionModel
*/

#import <Foundation/Foundation.h>

@class QSBSearchController;
@class HGSMutableActionOperation;
@class QSBTableResult;
@class HGSResultArray;

/*!
 A model class in the Model-View-Presenter meaning of the term for an action
 being created by QSB.
*/
@interface QSBActionModel : NSObject {
 @private
  NSMutableArray *searchControllers_;
  HGSMutableActionOperation *actionOperation_;
  QSBTableResult *selectedTableResult_;
}

/*! The current search being performed. */
@property (readonly, nonatomic, assign) QSBSearchController *activeSearchController;

/*! The HGSActionOperation that we are filling in. */
@property (readonly, nonatomic, retain) HGSMutableActionOperation *actionOperation;

/*! The currently selected table result. */
@property (readwrite, nonatomic, retain) QSBTableResult *selectedTableResult;

/*! Add a search controller to the stack of search controllers. */
- (void)pushSearchController:(QSBSearchController *)controller;

/*! Pop the top search controller from the stack of search controllers. */
- (void)popSearchController;

/*! Access the search controller at idx in the stack of search controllers. */
- (QSBSearchController *)searchControllerAtIndex:(NSUInteger)idx;

/*! 
 Return the number of search controllers in the stack of search controllers. 
*/
- (NSUInteger)searchControllerCount;

/*! 
 Reset our model by clearing the search controller stack, and resetting
 the action operation.
*/
- (void)reset;

/*! Return YES if we can pivot on the current table selection. */
- (BOOL)canPivot;

/*! Return YES if we can pivot on the current table selection. */
- (BOOL)canUnpivot;

@end
