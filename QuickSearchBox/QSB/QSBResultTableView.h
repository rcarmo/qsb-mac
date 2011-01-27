//
//  QSBResultTableView.h
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

// The table view that displays our results.
@interface QSBResultTableView : NSTableView {
 @private
  NSRange visibleRowRange_;
  CGFloat maxTableHeight_;
  CGFloat minTableHeight_;
}

// Return the most recently calculated table height to properly show ourself.
@property (readonly, assign) CGFloat tableHeight;
@property (readwrite, assign) CGFloat maxTableHeight;
@property (readwrite, assign) CGFloat minTableHeight;

// Tries to select a row in a table. Checks the current selection
// and if it isn't good, increments or decrements (depending on |incrementing|)
// until we find one, or we're at the top or bottom of the table and have
// found no acceptable selection.
// Returns YES if we selected something.
// Note: We do not wrap around the table.
- (BOOL)selectFirstSelectableRowByIncrementing:(BOOL)incrementing
                                    startingAt:(NSInteger)firstRow;
@end

@interface NSObject (QSBResultTableViewDelegateMethods)
- (void)qsbTableView:(NSTableView*)view
  changedVisibleRowsFrom:(NSRange)oldVisible 
                  to:(NSRange)newVisible;
@end

// Notification that the table reloaded its data
// Object is the table.
#define kQSBResultTableViewDidReloadData @"QSBResultTableViewDidReloadData"

