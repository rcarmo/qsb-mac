//
//  HGSPathCellElement.m
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
 @discussion HGSPathCellElement
 */

#import <Foundation/Foundation.h>

/*!
 A helper class for constructing the elements comprising the path control
 presented by QSB at the bottom of the results window.
*/
@interface HGSPathCellElement : NSObject {
 @private
  NSString *title_;
  NSURL *url_;
  NSImage *image_;
}

@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, retain) NSURL *url;
@property (nonatomic, readonly, retain) NSImage *image;

/*!
 Create an HGSPathCellElement.
 @param title The string title to be presented in the path control cell.
  This string may be nil, in which case it is replaced by an empty string
  and no title will be shown in the path control.
 @param url The URL to be opened when the user clicks in the path cell.
  The URL may be nil, in which case the cell will not highlight when the
  mouse passes over.
*/
+ (id)elementWithTitle:(NSString *)title url:(NSURL *)url;

/*!
 Initialize an HGSPathCellElement with an image. Designated initializer.
 @param title The string title to be presented in the path control cell.
   This string may be nil, in which case it is replaced by an empty string
   and no title will be shown in the path control.
 @param url The URL to be opened when the user clicks in the path cell.
   The URL may be nil, in which case the cell will not highlight when the
   mouse passes over.
 @param image An image to be presented in the patch cell.
 */
- (id)initElementWithTitle:(NSString *)title
                       url:(NSURL *)url
                     image:(NSImage *)image;

/*!
 Construct an array containing one or more dictionaries with path control
 element specifications as defined in QSBPathCell.h.
*/
+ (NSArray *)pathCellArrayWithElements:(NSArray *)elements;

@end
