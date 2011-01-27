//
//  QSBResultsViewBaseController.m
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

#import "QSBResultsViewBaseController.h"
#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBPluginUI.h>

#import "QSBApplicationDelegate.h"
#import "QSBTableResult.h"
#import "QSBResultsViewTableView.h"
#import "QSBSearchWindowController.h"
#import "GTMGeometryUtils.h"
#import "QSBSearchController.h"

@implementation QSBResultsViewBaseController

@synthesize searchController = searchController_;

- (id)initWithSearchController:(QSBSearchController *)controller
                       nibName:(NSString *)nibName {
  if ((self = [super initWithNibName:nibName bundle:nil])) {
    searchController_ = [controller retain];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(searchControllerDidUpdateResults:)
               name:kQSBSearchControllerDidUpdateResultsNotification
             object:searchController_];
  }
  return self;
}

- (void)awakeFromNib {
  [resultsTableView_ setDoubleAction:@selector(qsb_pickCurrentTableResult:)];
  [resultsTableView_ setTarget:nil];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

- (QSBResultsViewTableView *)resultsTableView {
  return resultsTableView_;
}

- (QSBTableResult *)selectedTableResult {
  return [self tableResultForRow:[resultsTableView_ selectedRow]];
}

- (void)searchControllerDidUpdateResults:(NSNotification *)notification {
  NSTableView *resultsTableView = [self resultsTableView];
  [resultsTableView reloadData];
  if ([resultsTableView selectedRow] == -1) {
    [resultsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                  byExtendingSelection:NO];
  }
}

- (BOOL)tableView:(NSTableView *)tv
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard*)pb {
  NSUInteger row = [rowIndexes firstIndex];
  QSBTableResult *tableResult = [self tableResultForRow:row];
  return [tableResult copyToPasteboard:pb];
}

- (void)tableView:(NSTableView *)aTableView
  willDisplayCell:(id)aCell
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex {
  QSBTableResult *result = [self tableResultForRow:rowIndex];
  [aCell setRepresentedObject:result];
}

- (NSString *)tableView:(NSTableView *)tableView toolTipForCell:(NSCell *)cell
                   rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc
                    row:(NSInteger)row mouseLocation:(NSPoint)mouseLocation {
  QSBTableResult *result = [self tableResultForRow:row];
  NSString *tip = [result displayToolTip];
  return tip;
}

- (QSBTableResult *)tableResultForRow:(NSInteger)row {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (IBAction)pathControlClick:(id)sender {
  // If the cell has a URI then dispatch directly to that URI, otherwise
  // ask the object if it wants to handle the click and, if so, tell it
  // which cell was clicked.
  NSPathControl *pathControl = sender;
  NSPathComponentCell *clickedComponentCell
    = [pathControl clickedPathComponentCell];
  if (clickedComponentCell) {
    NSURL *pathURL = [clickedComponentCell URL];
    if (!pathURL || ![[NSWorkspace sharedWorkspace] openURL:pathURL]) {
      // No URI or the URI launch failed.  Fallback to let the result take a shot.
      QSBTableResult *selectedObject = [self selectedTableResult];
      SEL cellClickHandler
        = NSSelectorFromString([selectedObject
                                valueForKey:kQSBObjectAttributePathCellClickHandlerKey]);
      if (cellClickHandler) {
        NSArray *pathComponentCells = [pathControl pathComponentCells];
        NSUInteger clickedCell
          = [pathComponentCells indexOfObject:clickedComponentCell];
        NSNumber *cellNumber = [NSNumber numberWithUnsignedInteger:clickedCell];
        [selectedObject performSelector:cellClickHandler withObject:cellNumber];
      }
    }
  }
}

- (IBAction)qsb_pickCurrentTableResult:(id)sender {
  QSBTableResult *result = [self selectedTableResult];
  [result performAction:self];
}

#pragma mark Actions

- (IBAction)copy:(id)sender {
  QSBTableResult *qsbTableResult = [self selectedTableResult];
  NSPasteboard *pb = [NSPasteboard generalPasteboard];
  [qsbTableResult copyToPasteboard:pb];
}

#pragma mark UI Validation

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem {
  BOOL validated = YES;
  if ([anItem action] == @selector(copy:)) {
    QSBTableResult *qsbTableResult = [self selectedTableResult];
    validated = [qsbTableResult isKindOfClass:[QSBSourceTableResult class]];
  }
  return validated;
}

@end
