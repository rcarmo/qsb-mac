//
//  GoogleDocsSaveAsAccessoryController.m
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

#import "GoogleDocsSaveAsAccessoryController.h"
#import <Vermilion/Vermilion.h>
#import "GoogleDocsConstants.h"

@interface GoogleDocsSaveAsAccessoryController ()

@property (nonatomic, retain) NSDictionary *descriptionToExtensionMap;

@end


@implementation GoogleDocsSaveAsAccessoryController

@synthesize fileTypes = fileTypes_;
@synthesize fileTypeIndex = fileTypeIndex_;
@synthesize worksheetNames = worksheetNames_;
@synthesize worksheetIndex = worksheetIndex_;
@synthesize descriptionToExtensionMap = descriptionToExtensionMap_;

- (void)dealloc {
  [fileTypes_ release];
  [saveAsInfo_ release];
  [descriptionToExtensionMap_ release];
  [super dealloc];
}

- (void)setSaveAsInfo:(NSDictionary *)saveAsInfo {
  // We get a dictionary with the request in it.  Determine the types
  // to be presented based on the kind of Google Doc we've got.
  // Also set the proposed file name.
  [saveAsInfo_ release];
  saveAsInfo_ = [saveAsInfo retain];
  HGSResult *result = [saveAsInfo objectForKey:kHGSSaveAsHGSResultKey];
  HGSAssert(result, nil);
  NSString *category = [result valueForKey:kGoogleDocsDocCategoryKey];
  isSpreadsheet_ = [category isEqualToString:kDocCategorySpreadsheet];
  NSBundle *bundle = HGSGetPluginBundle();
  NSString *fileTypesPath
    = [bundle pathForResource:@"GoogleDocsSaveAsFileTypes" ofType:@"plist"];
  NSDictionary *fileTypesInfo 
    = [NSDictionary dictionaryWithContentsOfFile:fileTypesPath];
  
  // Load up localized descriptions and map them to extensions.
  NSDictionary *extensionMap = [fileTypesInfo objectForKey:@"extensionMap"];
  // Create a temporary localized version of the extension map to aid
  // in the creation of the localized category file type list.
  NSMutableDictionary *localizedExtensionMap
    = [NSMutableDictionary dictionaryWithCapacity:[extensionMap count]];
  for (NSString *key in extensionMap) {
    NSString *value = [extensionMap objectForKey:key];
    NSString *localizedValue = HGSLocalizedString(value, nil);
    [localizedExtensionMap setObject:localizedValue forKey:key];
  }
  // We invert the table so that we can later map from localized description
  // to file type extension.
  NSMutableDictionary *descriptionToExtensionMap
    = [NSMutableDictionary dictionaryWithCapacity:[extensionMap count]];
  for (NSString *extension in localizedExtensionMap) {
    NSString *localizedDescription
      = [localizedExtensionMap objectForKey:extension];
    [descriptionToExtensionMap setObject:extension forKey:localizedDescription];
  }
  [self setDescriptionToExtensionMap:descriptionToExtensionMap];
  
  // Compose the file type description list for the chosen document category.
  NSDictionary *categories = [fileTypesInfo objectForKey:@"categories"];
  NSArray *extensionList = [categories objectForKey:category];
  NSMutableArray *descriptionList
    = [NSMutableArray arrayWithCapacity:[extensionList count]];
  for (NSString *extension in extensionList) {
    // Convert extensions to localized descriptions.
    NSString *description = [localizedExtensionMap objectForKey:extension];
    [descriptionList addObject:description];
  }
  [self setFileTypes:descriptionList];
  
  // Populate the worksheet array.
  NSArray *worksheetNames = [result valueForKey:kGoogleDocsWorksheetNamesKey];
  [self setWorksheetNames:worksheetNames];
  
  // Initialize the file type.
  [self setFileTypeIndex:0];
}

- (NSDictionary *)saveAsInfo {
  // Return a dictionary with the selected file type.
  NSMutableDictionary *saveAsInfo
    = (saveAsInfo_) ? [[saveAsInfo_ mutableCopy] autorelease]
                    : [NSMutableDictionary dictionaryWithCapacity:1];
  NSArray *fileTypes = [self fileTypes];
  NSInteger fileTypeIndex = [self fileTypeIndex];
  if (fileTypeIndex < [fileTypes count]) {
    NSString *description = [fileTypes objectAtIndex:fileTypeIndex];
    NSString *extension
      = [[self descriptionToExtensionMap] objectForKey:description];
    [saveAsInfo setObject:extension forKey:kGoogleDocsDocSaveAsExtensionKey];
  } else {
    HGSLogDebug(@"Attempt to access item %d from fileTypes with %d elements.",
                fileTypeIndex, [fileTypes count]);
  }
  if (isSpreadsheet_) {
    NSNumber *worksheetIndex
      = [NSNumber numberWithInteger:fileTypeIndex];
    [saveAsInfo setObject:worksheetIndex
                   forKey:kGoogleDocsDocSaveAsWorksheetIndexKey];
  }
  return saveAsInfo;
}

- (void)setFileTypeIndex:(NSInteger)fileTypeIndex {
  fileTypeIndex_ = fileTypeIndex;
  BOOL shouldBeEnabled = NO;
  if (isSpreadsheet_) {
    // If they chose TSV, CSV or HTML and there is more then one worksheet
    // we want to show them the worksheet popup.
    // TODO(mrossetti): Also accommodate PDF which, being a bit different from
    // CSV/TSV/HTML, allows either all worksheets or a single worksheet.
    NSString *chosenFileType = [fileTypes_ objectAtIndex:[self fileTypeIndex]];
    NSString *extension
      = [[self descriptionToExtensionMap] objectForKey:chosenFileType];
    NSSet *singleWorksheetSet
      = [NSSet setWithObjects:@"csv", @"tsv", @"html", nil];
    if ([singleWorksheetSet containsObject:extension]
        && [[self worksheetNames] count] > 1) {
      shouldBeEnabled = YES;
    }
  }
  [worksheetPopup_ setEnabled:shouldBeEnabled];
  [worksheetPopup_ setHidden:!shouldBeEnabled];
  [worksheetLabel_ setHidden:!shouldBeEnabled];
}

@end
