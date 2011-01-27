//
//  QSBTopResultsViewController.m
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

#import "QSBTopResultsViewController.h"
#import <Vermilion/Vermilion.h>
#import <objc/message.h>

#import "QSBSearchController.h"
#import "QSBResultsViewTableView.h"
#import "QSBTableResult.h"
#import "QSBTopResultsRowViewControllers.h"
#import "QSBResultsWindowController.h"

@implementation QSBTopResultsViewController

- (id)initWithSearchController:(QSBSearchController *)controller {
  return [super initWithSearchController:controller
                                 nibName:@"QSBTopResultsView"];
}

- (void)awakeFromNib {
  QSBResultsViewTableView *resultsTableView = [self resultsTableView];
  [resultsTableView setIntercellSpacing:NSMakeSize(0.0, 0.0)];
  rowViewControllers_ = [[NSMutableDictionary dictionary] retain];
  [super awakeFromNib];
}

- (void)dealloc {
  [rowViewControllers_ release];
  [super dealloc];
}

#pragma mark QSBResultsViewBaseController Overrides

- (QSBTableResult *)tableResultForRow:(NSInteger)row {
  return [[self searchController] topResultForIndex:row];
}

#pragma mark Actions

- (void)moveDown:(id)sender {
  QSBResultsViewTableView *tableView = [self resultsTableView];
  NSInteger newRow = [tableView selectedRow] + 1;
  if (newRow >= [self numberOfRowsInTableView:nil]) {
    QSBTableResult *result = [self selectedTableResult];
    if ([result isKindOfClass:[QSBFoldTableResult class]]) {
      BOOL handled = [NSApp sendAction:@selector(qsb_showMoreResults:)
                                  to:nil
                                from:self];
      HGSCheckDebug(handled, @"qsb_showMoreResults not handled");
    }
  } else {
    [tableView selectFirstSelectableRowByIncrementing:YES startingAt:newRow];
  }
}

#pragma mark NSTableView Delegate Methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [[self searchController] topResultCount];
}

- (CGFloat)tableView:(NSTableView *)tableView
         heightOfRow:(NSInteger)row {
  NSArray *columns = [tableView tableColumns];
  NSTableColumn *column = [columns objectAtIndex:0];
  NSView *colView = [self tableView:tableView viewForColumn:column row:row];
  CGFloat rowHeight = NSHeight([colView frame]);
  return rowHeight;
}

- (BOOL)tableView:(NSTableView *)aTableView
  shouldSelectRow:(NSInteger)rowIndex {
  QSBTableResult *object = [self tableResultForRow:rowIndex];
  BOOL isSeparator = [object isKindOfClass:[QSBSeparatorTableResult class]];
  BOOL isMessage = [object isKindOfClass:[QSBMessageTableResult class]];
  BOOL isSelectable = object && !(isSeparator || isMessage);
  return isSelectable;
}

- (id)tableView:(NSTableView *)tableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row {
  id value = nil;
  NSString *identifier = [tableColumn identifier];
  QSBTableResult *result = [self tableResultForRow:row];
  if ([identifier isEqual:@"PivotArrows"]) {
    value = [result isPivotable] ? [NSImage imageNamed:@"ChildArrow"] : nil;
  } else if ([identifier isEqual:@"Results"]) {
    value = result;
  } else {
    HGSLogDebug(@"Unknown table identifier %@ for %@", identifier, tableView);
  }
  return value;
}

- (NSView*)tableView:(NSTableView*)tableView
       viewForColumn:(NSTableColumn*)column
                 row:(NSInteger)row {
  // Creating our views lazily.
  QSBResultRowViewController *oldController
    = [rowViewControllers_ objectForKey:[NSNumber numberWithInteger:row]];
  QSBResultRowViewController *newController = nil;

  // Decide what kind of view we want to use based on the result.
  QSBTableResult *result = [self tableResultForRow:row];
  Class aRowViewControllerClass
    = [result topResultsRowViewControllerClass];
  if (aRowViewControllerClass) {
    if (!oldController
        || [oldController class] != aRowViewControllerClass) {
      newController
        = [[[aRowViewControllerClass alloc] init] autorelease];
      [rowViewControllers_ setObject:newController
                              forKey:[NSNumber numberWithInteger:row]];
      [newController loadView];
    } else {
      newController = oldController;
    }
    if ([newController representedObject] != result) {
      [newController setRepresentedObject:result];
    }
  }

  if (!newController) {
    HGSLogDebug(@"Unable to determine result row view for result %@ (row %d).",
                result, row);
  }

  NSView *newView = [newController view];
  return newView;
}

@end

