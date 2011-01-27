//
//  GoogleDocsSaveAsAccessoryController.h
//
//  Copyright (c) 2009 Google Inc. All rights reserved.
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
  @discussion This header provided only to satisfy Interface Builder.
*/

#import <Cocoa/Cocoa.h>
#import "QSBActionSaveAsControllerProtocol.h"

/*!
 A view controller conforming to QSBActionSaveAsControllerProtocol used to
 manage the accessory view for the Google Doc Save As action's save-as
 NSSavePanel which manages a popup presenting the types of documents to
 which a Google Doc can be exported.
*/
@interface GoogleDocsSaveAsAccessoryController : NSViewController <QSBActionSaveAsControllerProtocol> {
 @private
  IBOutlet NSTextField *worksheetLabel_;  // Label for worksheet popup.
  IBOutlet NSPopUpButton *worksheetPopup_;  // Worksheet popup.
  NSArray *fileTypes_;
  NSInteger fileTypeIndex_;
  NSArray *worksheetNames_;
  NSInteger worksheetIndex_;
  NSDictionary *saveAsInfo_;
  // Maps from the localized save-as document type description to the
  // extension to be assigned to the exported file.
  NSDictionary *descriptionToExtensionMap_;
  // YES if we're dealing with a spreadsheet.
  BOOL isSpreadsheet_;
}

/*!
 A list of user visible file types set based on the kind (category) of
 Google Doc being exported.  This is bound to the Possible File Types
 array controller in the nib.
*/
@property (nonatomic, retain) NSArray *fileTypes;

/*!
 The index of the file type chosen by the user.  This is bound to
 the Document Type Popup control in the nib.
*/
@property (nonatomic, assign) NSInteger fileTypeIndex;

/*!
 A list of worksheets contained in a spreadsheet.  These choices are
 presented to the user for CSV and TSV files when there is more than one
 worksheet.  This is bound to the Worksheets array controller in the nib.
 */
@property (nonatomic, retain) NSArray *worksheetNames;

/*!
 The index of the worksheet chosen by the user.  This is bound to
 the Worksheet Popup control in the nib.
 */
@property (nonatomic, assign) NSInteger worksheetIndex;

/*!
 Specifies controller-specific information to be shown in and/or
 provided by the accessory view of the save-as panel.  This is required
 by the QSBActionSaveAsControllerProtocol.
*/
@property (nonatomic, retain) NSDictionary *saveAsInfo;

@end
