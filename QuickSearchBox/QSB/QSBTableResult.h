//
//  QSBTableResult.h
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

#import <Foundation/Foundation.h>

/*!
 @header
 @discussion QSBTableResult
 */

@class HGSScoredResult;
@class QSBCategory;
@class QSBSearchController;

/*!
  Abstract base class for showing results in our tables
*/
@interface QSBTableResult : NSObject <NSCopying>

/*!
 The secondary title color used for many text elements in QSB.
*/
+ (NSColor *)secondaryTitleColor;

/*!
  Determine if the result can be pivoted on.
*/
- (BOOL)isPivotable;

/*!
 Tell the result we are pivoting on it.
*/
- (void)willPivot;

/*!
  Return a string that has the title of the result.
*/
- (NSAttributedString *)titleString;

/*!
  Return a string that has the title of the result on the first line, the
  snippet (if any) on the next line, and the SourceURL on the following line.
*/
- (NSAttributedString *)titleSnippetSourceURLString;

/*!
  Return a string that has the title of the result on the first line with the
  snippet (if any) on the second line.
*/
- (NSAttributedString *)titleSnippetString;

/*!
  Return a string that has the title of the result on the first line with the
  SourceURL (if any) on the second line.
*/
- (NSAttributedString *)titleSourceURLString;

/*!
  Returns the display name for the result.
*/
- (NSString *)displayName;

/*!
  Return the path as an array of dictionaries for display in the UI.
*/
- (NSArray *)displayPath;

/*!
  Return an icon.
*/
- (NSImage *)displayIcon;

/*!
 Return a tooltip.
*/
- (NSString*)displayToolTip;

/*!
  Return a thumbnail.
*/
- (NSImage *)displayThumbnail;

/*!
  Return the score of the result.
*/
- (CGFloat)score;

/*!
  Return the class of the view controller used to display the result at the top
  level.
*/
- (Class)topResultsRowViewControllerClass;

/*!
  Attempt to perform the default action on the item.
*/
- (void)performAction:(id)sender;

/*!
  Copies the contents of the result to the pasteboard.
*/
- (BOOL)copyToPasteboard:(NSPasteboard *)pb;
@end

/*!
  A result that comes from one of our sources.
*/
@interface QSBSourceTableResult : QSBTableResult {
 @private
  HGSScoredResult *representedResult_;
  NSImage *thumbnailImage_;
  NSImage *icon_;
  NSString *categoryName_;
}

@property (nonatomic, readonly) HGSScoredResult *representedResult;
@property (nonatomic, readwrite, copy) NSString *categoryName;

+ (id)tableResultWithResult:(HGSScoredResult *)result;
- (id)initWithResult:(HGSScoredResult *)result;

@end

/*!
  A "search google" result.
*/
@interface QSBGoogleTableResult : QSBSourceTableResult
@end

/*!
  A separator (horizontal rule).
*/
@interface QSBSeparatorTableResult : QSBTableResult

+ (id)tableResult;

@end

/*!
  A fold (eg Show more results or Show Top Results).
*/
@interface QSBFoldTableResult : QSBTableResult {
 @private
  QSBSearchController *controller_;
}

+ (id)tableResultWithSearchController:(QSBSearchController *)controller;
- (id)initWithSearchController:(QSBSearchController *)controller;
@end

/*!
  A message from the UI.
*/
@interface QSBMessageTableResult : QSBTableResult {
 @private
  NSString *message_;
}

+ (id)tableResultWithString:(NSString *)message;

@end

/*!
  Show a line in the 'More' results presenting the total number of possible
  results for a category and allowing the user to cause those results to be
  listed in the table.
*/
@interface QSBShowAllTableResult : QSBTableResult {
 @private
  QSBCategory *category_;
  NSUInteger categoryCount_;
}

+ (id)tableResultWithCategory:(QSBCategory *)category
                        count:(NSUInteger)categoryCount;
- (id)initWithCategory:(QSBCategory *)category
                 count:(NSUInteger)categoryCount;
- (NSString *)categoryName;

@end
