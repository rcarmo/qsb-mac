//
//  QSBResultRowViewController.h
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

/*!
 @header
 @discussion QSBResultRowViewController
*/

#import <Cocoa/Cocoa.h>

/*!
 The abstract base view controller class for the various nibs used to present
 a row in a results table.  There are several child classes which support
 the presentation of results for the Top and the More windows as well as
 for showing dividers, category summaries, and the Top and More folds.

 Support is also provided for result sources that wish to present their own
 view for drawing in place of the right-hand side detail shown by default.
 A custom result view will be width constrained but may have a variable
 height.
*/
@interface QSBResultRowViewController : NSViewController {
 @private
  /*!
   The custom result view used to present an optional source-provided result
   view.  The source-provided view will be added as a child to this view and
   resized to match width while the view of this controller will be resized
   height-wise to accomodate the custom view.  If this view is not connected
   in the nib then no source-provided view will be allowed.
  */
  IBOutlet NSView* customResultView_;
  BOOL customResultViewInstalled_;
  NSNib *nib_;
  NSArray *topLevelObjects_;
}

/*!
 Returns YES if there is a connected |customResultView| and the result's
 source has provided a view for rendering the result.
*/
@property (readonly, nonatomic, getter=isCustomResultViewInstalled)
  BOOL customResultViewInstalled;

/*! Designated initializer. */
- (id)initWithNib:(NSNib *)nib;

@end

