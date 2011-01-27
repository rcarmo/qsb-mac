//
//  QDBDebugWindowController.m
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
//

#import "QSBDebugWindowController.h"
#import <Vermilion/Vermilion.h>
#import "QSBSearchController.h"
#import "QSBTableResult.h"

static NSString *const kQSBDWTopResultsKey = @"Top Results";
static NSString *const kQSBDWMoreResultsKey =@"More Results";
static NSUInteger kQSBDWResultRowCount = 10;

static NSInteger QSBDWSortOperations(HGSSearchOperation *op1,
                                     HGSSearchOperation *op2,
                                     void* context) {
  NSInteger value = NSOrderedSame;
  HGSTypeFilter *filter = [HGSTypeFilter filterAllowingAllTypes];
  NSUInteger resultCount1 = [op1 resultCountForFilter:filter];
  NSUInteger resultCount2 = [op2 resultCountForFilter:filter];
  if (resultCount1 > resultCount2) {
    value = NSOrderedAscending;
  } else  if (resultCount1 < resultCount2) {
    value = NSOrderedDescending;
  }
  return value;
}

@interface QSBDebugWindowController ()

- (void)queryControllerWillStart:(NSNotification *)notification;
- (void)queryControllerDidFinish:(NSNotification *)notification;
- (void)searchControllerDidUpdateResults:(NSNotification *)notification;
- (void)searchOperationWillStart:(NSNotification *)notification;
- (void)searchOperationDidFinish:(NSNotification *)notification;
- (void)searchOperationWasCancelled:(NSNotification *)notification;
- (void)searchOperationDidUpdateResults:(NSNotification *)notification;

@end

@implementation QSBDebugWindowController

+ (id)sharedWindowController {
  static QSBDebugWindowController *sharedController = nil;
  if (!sharedController) {
    sharedController = [[self alloc] initWithWindowNibName:@"QSBDebugWindow"];
  }
  return sharedController;
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [searchOperations_ release];
  [updatedResults_ release];
  [queryControllerStartTime_ release];
  [super dealloc];
}

- (void)windowDidLoad {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc addObserver:self
         selector:@selector(queryControllerWillStart:)
             name:kHGSQueryControllerWillStartNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(queryControllerDidFinish:)
             name:kHGSQueryControllerDidFinishNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(searchControllerDidUpdateResults:)
             name:kQSBSearchControllerDidUpdateResultsNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(searchOperationWillStart:)
             name:kHGSSearchOperationWillStartNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(searchOperationDidFinish:)
             name:kHGSSearchOperationDidFinishNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(searchOperationWasCancelled:)
             name:kHGSSearchOperationWasCancelledNotification
           object:nil];
  [nc addObserver:self
         selector:@selector(searchOperationDidUpdateResults:)
             name:kHGSSearchOperationDidUpdateResultsNotification
           object:nil];

  NSFont *font = [NSFont systemFontOfSize:[NSFont smallSystemFontSize]];
  NSBrowserCell *browserCell
    = [[[NSBrowserCell alloc] initTextCell:@""] autorelease];
  [browserCell setFont:font];
  [mixedResults_ setCellPrototype:browserCell];
  [operations_ setCellPrototype:browserCell];
  searchOperations_ = [[NSMutableArray alloc] init];
  updatedResults_ = [[NSMutableArray alloc] init];
  [[self window] center];
}

#pragma mark Notifications
- (void)queryControllerWillStart:(NSNotification *)notification {
  HGSQueryController *controller = [notification object];
  HGSQuery *query = [controller query];
  HGSTokenizedString *tokenizedString = [query tokenizedQueryString];
  [normalizedQuery_ setStringValue:[tokenizedString tokenizedString]];
  [rawQuery_ setStringValue:[tokenizedString originalString]];
  [searchOperations_ removeAllObjects];
  [updatedResults_ removeAllObjects];
  [operations_ loadColumnZero];
  [mixedResults_ loadColumnZero];
  [queryControllerStartTime_ release];
  queryControllerStartTime_ = [[NSDate date] retain];
  [gatheringTime_ setStringValue:@"Gathering"];
  [gatheringProgress_ startAnimation:self];
}

- (void)queryControllerDidFinish:(NSNotification *)notification {
  NSTimeInterval elapsedTime = [queryControllerStartTime_ timeIntervalSinceNow];
  NSString *value = [NSString stringWithFormat:@"%0.3f ms", elapsedTime * -1000];
  [gatheringTime_ setStringValue:value];
  [gatheringProgress_ stopAnimation:self];
}

- (void)searchControllerDidUpdateResults:(NSNotification *)notification {
  QSBSearchController *controller = [notification object];
  NSRange range = NSMakeRange(0, [controller topResultCount]);
  NSArray *topResults = [controller topResultsInRange:range];
  NSDictionary *moreResults = nil;
  // TODO(dmaclach): fix this up somehow.
  // [controller rankedResultsByCategory];
  NSDictionary *dictionary
    = [NSDictionary dictionaryWithObjectsAndKeys:
       topResults, kQSBDWTopResultsKey,
       moreResults, kQSBDWMoreResultsKey,
       nil];
  [updatedResults_ addObject:dictionary];
  [mixedResults_ loadColumnZero];
}

- (void)searchOperationWillStart:(NSNotification *)notification {
  HGSSearchOperation *op = [notification object];
  [searchOperations_ addObject:op];
  [searchOperations_ sortUsingFunction:QSBDWSortOperations context:NULL];
  [operations_ loadColumnZero];
}

- (void)searchOperationDidFinish:(NSNotification *)notification {
  [operations_ loadColumnZero];
}

- (void)searchOperationWasCancelled:(NSNotification *)notification {
  [operations_ loadColumnZero];
}

- (void)searchOperationDidUpdateResults:(NSNotification *)notification {
  [searchOperations_ sortUsingFunction:QSBDWSortOperations context:NULL];
  [operations_ loadColumnZero];
}

#pragma mark Browser Delegate Methods
- (NSInteger)mixedResultsNumberOfRowsInColumn:(NSInteger)column {
  NSInteger rowCount = 0;
  if (column == 0) {
    rowCount = [updatedResults_ count];
  } else {
    NSInteger selectedMix = [mixedResults_ selectedRowInColumn:0];
    NSDictionary *dictionary = [updatedResults_ objectAtIndex:selectedMix];
    if (column == 1) {
      rowCount = [[dictionary allKeys] count];
    } else {
      NSCell *selectedCell = [mixedResults_ selectedCellInColumn:1];
      NSString *key = [selectedCell stringValue];
      if ([key isEqual:kQSBDWTopResultsKey]) {
        NSArray *results = [dictionary objectForKey:key];
        if (column == 2) {
          rowCount = [results count];
        } else {
          rowCount = kQSBDWResultRowCount;
        }
      } else if ([key isEqual:kQSBDWMoreResultsKey]) {
        NSDictionary *rankedResultsByCategory = [dictionary objectForKey:key];
        if (column == 2) {
          rowCount = [[rankedResultsByCategory allKeys] count];
        } else {
          selectedCell = [mixedResults_ selectedCellInColumn:2];
          key = [selectedCell stringValue];
          NSArray *results = [rankedResultsByCategory objectForKey:key];
          if (column == 3) {
            rowCount = [results count];
          } else {
            rowCount = kQSBDWResultRowCount;
          }
        }
      }
    }
  }
  return rowCount;
}

- (NSInteger)operationsNumberOfRowsInColumn:(NSInteger)column {
  NSInteger rowCount = 0;
  if (column == 0) {
    rowCount = [searchOperations_ count];
  } else if (column == 1) {
    NSInteger selectedOp = [operations_ selectedRowInColumn:0];
    HGSSearchOperation *operation = [searchOperations_ objectAtIndex:selectedOp];
    HGSTypeFilter *filter = [HGSTypeFilter filterAllowingAllTypes];
    rowCount = [operation resultCountForFilter:filter];
  } else if (column == 2) {
    rowCount = kQSBDWResultRowCount;
  }
  return rowCount;
}

- (NSInteger)browser:(NSBrowser *)sender numberOfRowsInColumn:(NSInteger)column {
  NSInteger rowCount = 0;
  if (sender == mixedResults_) {
    rowCount = [self mixedResultsNumberOfRowsInColumn:column];
  } else if (sender == operations_) {
    rowCount = [self operationsNumberOfRowsInColumn:column];
  } else {
    HGSAssert(NO, nil);
  }
  return rowCount;
}
- (void)willDisplayCell:(id)cell
                  atRow:(NSInteger)row
              forResult:(HGSScoredResult *)result {
  NSString *cellData = nil;
  switch (row) {
    case 0:
      cellData = [result displayName];
      break;

    case 1:
      cellData = [result type];
      break;

    case 2:
      cellData = [NSString stringWithFormat:@"Score: %0.3f", [result score]];
      break;

    case 3:
      cellData = [result uri];
      break;

    case 4:
      cellData = [[result url] absoluteString];
      break;

    case 5:
      cellData = [NSString stringWithFormat:@"Below Fold: %@",
                  [result rankFlags] & eHGSBelowFoldRankFlag ? @"Yes" : @"No"];
      break;

    case 6:
      cellData = [NSString stringWithFormat:@"Shortcut: %@",
                  [result rankFlags] & eHGSShortcutRankFlag ? @"Yes" : @"No"];
      break;

    case 7:
      cellData = [NSString stringWithFormat:@"Last Used: %@",
                  [result valueForKey:kHGSObjectAttributeLastUsedDateKey]];
      break;

    case 8:
      cellData = [NSString stringWithFormat:@"Matched Term: %@",
                  [[result matchedTerm] tokenizedString]];
      break;

    case 9:
      cellData = [NSString stringWithFormat:@"Source: %@",
                  [[result source] identifier]];
      break;
  }
  [cell setStringValue:cellData];
  [cell setLeaf:YES];
}

- (void)operationsWillDisplayCell:(id)cell
                            atRow:(NSInteger)row
                           column:(NSInteger)column {
  if (column == 0) {
    HGSSearchOperation *operation = [searchOperations_ objectAtIndex:row];
    NSString *name = [operation displayName];
    NSString *cellData = nil;
    HGSTypeFilter *filter = [HGSTypeFilter filterAllowingAllTypes];
    if ([operation isCancelled]) {
      cellData = [NSString stringWithFormat:@"%@ (Cancelled)", name];
    } else if ([operation isFinished]) {
      cellData = [NSString stringWithFormat:@"%@ (%d - %0.3fms)",
                  name, [operation resultCountForFilter:filter],
                  [operation runTime] / 10e5];
    } else {
      cellData = [NSString stringWithFormat:@"%@ (%d)",
                  name, [operation resultCountForFilter:filter]];
    }
    [cell setStringValue:cellData];
  } else {
    NSInteger selectedOp = [operations_ selectedRowInColumn:0];
    HGSSearchOperation *operation = [searchOperations_ objectAtIndex:selectedOp];
    HGSTypeFilter *allFilter = [HGSTypeFilter filterAllowingAllTypes];
    if (column == 1) {
      HGSScoredResult *scoredResult
        = [operation sortedRankedResultAtIndex:row
                                    typeFilter:allFilter];
      NSString *cellData = [NSString stringWithFormat:@"%@ (%0.3f)",
                            [scoredResult displayName], [scoredResult score]];
      [cell setStringValue:cellData];
    } else if (column == 2) {
      NSInteger selectedResult = [operations_ selectedRowInColumn:1];
      HGSScoredResult *result
        = [operation sortedRankedResultAtIndex:selectedResult
                                    typeFilter:allFilter];
      [self willDisplayCell:cell atRow:row forResult:result];
    }
  }
}

- (void)mixedResultsWillDisplayCell:(id)cell
                              atRow:(NSInteger)row
                             column:(NSInteger)column {
  if (column == 0) {
    [cell setStringValue:[NSString stringWithFormat:@"Mix %d", row]];
  } else {
    NSInteger selectedMix = [mixedResults_ selectedRowInColumn:0];
    NSDictionary *dictionary = [updatedResults_ objectAtIndex:selectedMix];
    if (column == 1) {
      [cell setStringValue:[[dictionary allKeys] objectAtIndex:row]];
    } else {
      NSCell *selectedCell = [mixedResults_ selectedCellInColumn:1];
      NSString *key = [selectedCell stringValue];
      if ([key isEqual:kQSBDWTopResultsKey]) {
        NSArray *results = [dictionary objectForKey:key];
        if (column == 2) {
          QSBTableResult *tableResult = [results objectAtIndex:row];
          NSString *name = [tableResult displayName];
          if (name) {
            [cell setStringValue:name];
          } else {
            [cell setStringValue:NSStringFromClass([tableResult class])];
            [cell setLeaf:YES];
          }
        } else {
          NSUInteger selectedRow = [mixedResults_ selectedRowInColumn:2];
          QSBTableResult *tableResult = [results objectAtIndex:selectedRow];
          if ([tableResult respondsToSelector:@selector(representedResult)]) {
            HGSScoredResult *result = [(id)tableResult representedResult];
            [self willDisplayCell:cell atRow:row forResult:result];
          } else {
            [cell setStringValue:NSStringFromClass([tableResult class])];
          }
        }
      } else {
        NSDictionary *rankedResultsByCategory = [dictionary objectForKey:key];
        NSArray *categories = [rankedResultsByCategory allKeys];
        if (column == 2) {
          [cell setStringValue:[categories objectAtIndex:row]];
        } else {
          NSCell *selectedCategory = [mixedResults_ selectedCellInColumn:2];
          NSString *categoryName = [selectedCategory stringValue];
          NSArray *results = [rankedResultsByCategory objectForKey:categoryName];
          if (column == 3) {
            HGSScoredResult *result = [results objectAtIndex:row];
            [cell setStringValue:[result displayName]];
          } else {
            NSUInteger selectedResult = [mixedResults_ selectedRowInColumn:3];
            HGSScoredResult *result = [results objectAtIndex:selectedResult];
            [self willDisplayCell:cell atRow:row forResult:result];
          }
        }
      }
    }
  }
}

- (void)browser:(NSBrowser *)sender
willDisplayCell:(id)cell
          atRow:(NSInteger)row
         column:(NSInteger)column {
  if (sender == mixedResults_) {
    [self mixedResultsWillDisplayCell:cell atRow:row column:column];
  } else if (sender == operations_) {
    [self operationsWillDisplayCell:cell atRow:row column:column];
  } else {
    HGSAssert(NO, nil);
  }
}
@end
