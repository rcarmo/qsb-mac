//
//  QSBMoreResultsViewController.m
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

#import "QSBMoreResultsViewController.h"

#import <Vermilion/Vermilion.h>
#import <GTM/GTMNSObject+KeyValueObserving.h>
#import <GTM/GTMMethodCheck.h>

#import "QSBSearchController.h"
#import "QSBPreferences.h"
#import "QSBTableResult.h"
#import "QSBResultsViewTableView.h"
#import "NSAttributedString+Attributes.h"
#import "QSBMoreResultsResultCell.h"
#import "QSBResultsWindowController.h"

// Extra space to allow for miscellaneous rows (such as fold) in the results table.
static const NSUInteger kCategoryRowOverhead = 3;
static const NSTimeInterval kFirstRowDownwardDelay = 0.6;
static const NSTimeInterval kFirstRowUpwardDelay = 0.4;

@interface QSBMoreResultsViewController ()

// Given a category, should we show a "Show all" result for it?
- (BOOL)shouldDisplayShowAllResultForCategory:(QSBCategory *)category;
- (QSBTableResult *)cachedTableResultForRow:(NSInteger)row;
- (void)cacheTableResult:(QSBTableResult *)result forRow:(NSInteger)row;
- (void)uncacheTableResultForRow:(NSInteger)row;
- (void)uncacheAllTableResults;
- (void)addShowAllCategory:(QSBCategory *)category;
- (void)moreCategoryResultCountChanged:(GTMKeyValueChangeNotification *)notification;
- (void)maxMoreResultCountBeforeAbridgingChanged:(GTMKeyValueChangeNotification *)notification;

@end

@implementation QSBMoreResultsViewController

GTM_METHOD_CHECK(NSMutableAttributedString, addAttributes:);
GTM_METHOD_CHECK(NSObject, gtm_addObserver:forKeyPath:selector:userInfo:options:);

- (id)initWithSearchController:(QSBSearchController *)controller {
  if ((self = [super initWithSearchController:controller
                                      nibName:@"QSBMoreResultsView"])) {
    showAllCategoriesSet_ = [[NSMutableSet alloc] init];
    cachedRows_ = [[NSMutableDictionary alloc] init];
    blockTime_ = -1;
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs gtm_addObserver:self
                forKeyPath:kQSBMoreCategoryResultCountKey
                  selector:@selector(moreCategoryResultCountChanged:)
                  userInfo:nil
                   options:NSKeyValueObservingOptionNew];
    [prefs gtm_addObserver:self
                forKeyPath:kQSBMaxMoreResultCountBeforeAbridgingKey
                  selector:@selector(maxMoreResultCountBeforeAbridgingChanged:)
                  userInfo:nil
                   options:NSKeyValueObservingOptionNew];

    moreCategoryResultCount_
      = [prefs integerForKey:kQSBMoreCategoryResultCountKey];
    maxMoreResultCountBeforeAbridging_
      = [prefs integerForKey:kQSBMaxMoreResultCountBeforeAbridgingKey];
  }
  return self;
}

- (void)awakeFromNib {
  QSBResultsViewTableView *resultsTableView = [self resultsTableView];
  [resultsTableView setIntercellSpacing:NSMakeSize(0.0, 3.0)];
  [resultsTableView setMaxTableHeight:550.0];
  [super awakeFromNib];
}

- (void)dealloc {
  [self uncacheAllTableResults];
  [showAllCategoriesSet_ release];
  [separatorRows_ release];
  [resultCountByCategory_ release];
  [sortedCategories_ release];
  [cachedRows_ release];
  [super dealloc];
}

- (NSUInteger)resultCountForCategory:(QSBCategory *)category {
  NSNumber *nsCount = [resultCountByCategory_ objectForKey:category];
  return [nsCount unsignedIntegerValue];
}

- (BOOL)shouldDisplayShowAllResultForCategory:(QSBCategory *)category {
  BOOL displayShowAll = resultCount_ > maxMoreResultCountBeforeAbridging_;
  if (displayShowAll) {
    displayShowAll = ![showAllCategoriesSet_ containsObject:category];
    if (displayShowAll) {
      NSUInteger count = [self resultCountForCategory:category];
      displayShowAll = count > moreCategoryResultCount_;
    }
  }
  return displayShowAll;
}

// Sort the categories alphabetically. QSBCategories sort by their
// localizedName.
- (NSArray *)sortedCategories {
  NSMutableArray *categories = [NSMutableArray array];
  for (QSBCategory *category in resultCountByCategory_) {
    NSUInteger count = [self resultCountForCategory:category];
    if (count > 0) {
      [categories addObject:category];
    }
  }
  return [categories sortedArrayUsingSelector:@selector(compare:)];
}

// Determine how many rows we actually have, and where our separators are.
- (void)updateTableData {
  [sortedCategories_ release];
  sortedCategories_ = [[self sortedCategories] retain];
  rowCount_ = 0;
  NSMutableIndexSet *mutableSeparators = [NSMutableIndexSet indexSet];
  for (QSBCategory *category in sortedCategories_) {
    NSUInteger count = [self resultCountForCategory:category];
    if (count) {
      if ([self shouldDisplayShowAllResultForCategory:category]) {
        rowCount_ += moreCategoryResultCount_ + 1;
      } else {
        // for show all views
        rowCount_ += count;
      }
      // Separator
      [mutableSeparators addIndex:rowCount_ - 1];
    }
  }
  [separatorRows_ release];
  separatorRows_ = [mutableSeparators retain];
  [self uncacheAllTableResults];
}

// Determine an actual result for a row index.
- (QSBTableResult *)tableResultForRow:(NSInteger)row {
  QSBTableResult *object = nil;
  if (row >= 0) {
    object = [self cachedTableResultForRow:row];
    if (!object) {
      // Determine what row our category is in by comparing to our
      // "separator" indexes.
      NSUInteger endRow = [separatorRows_ indexGreaterThanOrEqualToIndex:row];
      NSRange range = NSMakeRange(0, row);
      NSUInteger categoryIndex = [separatorRows_ countOfIndexesInRange:range];

      QSBCategory *category = [sortedCategories_ objectAtIndex:categoryIndex];

      // Determine if we should add a showall.
      if (endRow == row
          && [self shouldDisplayShowAllResultForCategory:category]) {
        NSUInteger count = [self resultCountForCategory:category];
        object = [QSBShowAllTableResult tableResultWithCategory:category
                                                          count:count];
      }
      if (!object) {
        QSBSearchController *searchController
          = [self searchController];
        NSUInteger startRow = [separatorRows_ indexLessThanIndex:endRow];
        if (startRow == NSNotFound) {
          startRow = 0;
        } else {
          startRow += 1;
        }
        object = [searchController rankedResultForCategory:category
                                                   atIndex:row - startRow];
        if (object) {
          if (row == startRow) {
            NSString *localizedName = [category localizedName];
            [(QSBSourceTableResult *)object setCategoryName:localizedName];
          }
        }
      }
    }
    [self cacheTableResult:object forRow:row];
    object = object;
  }
  return object;
}

- (IBAction)qsb_showAllForSelectedCategory:(id)sender {
  NSTableView *tableView = [self resultsTableView];
  NSInteger row = [tableView selectedRow];
  NSRange range = NSMakeRange(0, row);
  NSUInteger categoryIndex = [separatorRows_ countOfIndexesInRange:range];

  QSBCategory *category = [sortedCategories_ objectAtIndex:categoryIndex];
  [self addShowAllCategory:category];
}

- (void)addShowAllCategory:(QSBCategory *)category {
  [showAllCategoriesSet_ addObject:category];

  // Force our category lists and indexes to be regenerated.
  // The selection gets lost so save/restore the selection.
  [self updateTableData];

  QSBResultsViewTableView *resultsTableView = [self resultsTableView];
  NSUInteger selectedRow = [resultsTableView selectedRow];
  [resultsTableView reloadData];
  NSIndexSet *selRowSet = [NSIndexSet indexSetWithIndex:selectedRow];
  [resultsTableView selectRowIndexes:selRowSet byExtendingSelection:NO];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSDictionary *userInfo
    = [NSDictionary dictionaryWithObject:category
                                  forKey:kQSBMoreResultsCategoryKey];
  [nc postNotificationName:kQSBMoreResultsDidShowCategoryNotification
                    object:self
                  userInfo:userInfo];
}

- (void)displayIconUpdated:(GTMKeyValueChangeNotification *)notification {
  NSNumber *rowNumber = [notification userInfo];
  NSInteger row = [rowNumber integerValue];
  NSTableView *view = [self resultsTableView];
  NSRect rect = [view rectOfRow:row];
  [view setNeedsDisplayInRect:rect];
}

- (QSBTableResult *)cachedTableResultForRow:(NSInteger)row {
  NSNumber *key = [NSNumber numberWithInteger:row];
  return [cachedRows_ objectForKey:key];
}

- (void)removeCachedTableResultObserver:(NSNumber *)key {
  QSBTableResult *result = [cachedRows_ objectForKey:key];
  if (result) {
    if ([result isKindOfClass:[QSBSourceTableResult class]]) {
      [result gtm_removeObserver:self
                      forKeyPath:@"displayIcon"
                        selector:@selector(displayIconUpdated:)];
    }
  }
}

- (void)cacheTableResult:(QSBTableResult *)result forRow:(NSInteger)row {
  if (result) {
    NSNumber *key = [NSNumber numberWithInteger:row];
    [self removeCachedTableResultObserver:key];
    if ([result isKindOfClass:[QSBSourceTableResult class]]) {
      [result gtm_addObserver:self forKeyPath:@"displayIcon"
                     selector:@selector(displayIconUpdated:)
                     userInfo:key
                      options:0];
    }
    [cachedRows_ setObject:result forKey:key];
  }
}


- (void)uncacheTableResultForRow:(NSInteger)row {
  NSNumber *key = [NSNumber numberWithInteger:row];
  [self removeCachedTableResultObserver:key];
  [cachedRows_ removeObjectForKey:key];
}

- (void)uncacheAllTableResults {
  NSArray *keys = [cachedRows_ allKeys];
  for (NSNumber *key in keys) {
    [self removeCachedTableResultObserver:key];
    [cachedRows_ removeObjectForKey:key];
  }
}

#pragma mark NSResponder Overrides

- (void)moveUp:(id)sender {
  QSBResultsViewTableView *tableView = [self resultsTableView];
  NSInteger row = [tableView selectedRow];

  NSTimeInterval timeToBlock = 0.0;

  if (row == 0) {
    timeToBlock = kFirstRowUpwardDelay;
  }

  NSEvent *event = [NSApp currentEvent];
  if (timeToBlock > 0
      && [event type] == NSKeyDown
      && [event isARepeat]) {
    if (blockTime_ < 0) {
      blockTime_ = [NSDate timeIntervalSinceReferenceDate];
    }
    if ([NSDate timeIntervalSinceReferenceDate] - blockTime_ < timeToBlock) {
      return;
    }
  }

  if (row == 0) {
    // If we're on the first row then transition to the 'Top' results view.
    [NSApp sendAction:@selector(qsb_showTopResults:) to:nil from:self];
  } else {
    [tableView selectFirstSelectableRowByIncrementing:NO
                                           startingAt:row - 1];
  }
   blockTime_ = -1;
}

// Repeats can't move us past the first row until a delay passes. this prevents
// overshooting the top results
- (void)moveDown:(id)sender {
  QSBResultsViewTableView *tableView = [self resultsTableView];
  NSInteger row = [tableView selectedRow];

  NSTimeInterval timeToBlock = 0.0;

  if (row == 0) {
    timeToBlock = kFirstRowDownwardDelay;
  }
  // TODO(alcor): This is disabled until further experimentation can be done
  // else {
  //    NSObject *result = [self objectForRow:row - 1];
  //    if ([result isKindOfClass:[QSBSeparatorTableResult class]]) {
  //      timeToBlock = 0.2;
  //    }
  //  }

  NSEvent *event = [NSApp currentEvent];
  if (timeToBlock > 0
      && [event type] == NSKeyDown
      && [event isARepeat]) {
    if (blockTime_ < 0) {
      blockTime_ = [NSDate timeIntervalSinceReferenceDate];
    }
    if ([NSDate timeIntervalSinceReferenceDate] - blockTime_ < timeToBlock) {
      return;
    }
  }
  blockTime_ = -1;
  [tableView selectFirstSelectableRowByIncrementing:YES
                                         startingAt:row + 1];
}

#pragma mark NSTableViewDelegate Methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return rowCount_;
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex {
  // Need to return something here because NSTableView requires we override
  // this method as a datasource. We actually set our cell's data in
  // tableView:willDisplayCell:forTableColumn:row
  return @"";
}

- (void)qsbTableView:(NSTableView*)view
changedVisibleRowsFrom:(NSRange)oldVisible
                  to:(NSRange)newVisible {
  // Remove the rows that are no longer visible from our cache.
  NSRange indexesToRemove;
  if (oldVisible.location < newVisible.location) {
    indexesToRemove.location = oldVisible.location;
    indexesToRemove.length = newVisible.location - oldVisible.location;
  } else {
    indexesToRemove.location = NSMaxRange(newVisible);
    indexesToRemove.length = NSMaxRange(oldVisible) - NSMaxRange(newVisible);
  }
  for (NSUInteger i = indexesToRemove.location;
       i < NSMaxRange(indexesToRemove);
       ++i) {
    [self uncacheTableResultForRow:i];
  }
}

#pragma mark Notifications

- (void)searchControllerDidUpdateResults:(NSNotification *)notification {
  NSDictionary *userInfo = [notification userInfo];
  NSDictionary *resultCountByCategory
    = [userInfo objectForKey:kQSBSearchControllerResultCountByCategoryKey];
  [resultCountByCategory_ release];
  resultCountByCategory_ = [resultCountByCategory retain];
  NSNumber *resultCount
    = [userInfo objectForKey:kQSBSearchControllerResultCountKey];
  resultCount_ = [resultCount unsignedIntegerValue];
  [self updateTableData];
  [super searchControllerDidUpdateResults:notification];
}

- (void)moreCategoryResultCountChanged:(GTMKeyValueChangeNotification *)notification {
  NSDictionary *change = [notification change];
  NSNumber *valueOfChange = [change valueForKey:NSKeyValueChangeNewKey];
  moreCategoryResultCount_ = [valueOfChange unsignedIntegerValue];
  NSTableView *resultsTableView = [self resultsTableView];
  [resultsTableView reloadData];
}

- (void)maxMoreResultCountBeforeAbridgingChanged:(GTMKeyValueChangeNotification *)notification {
  NSDictionary *change = [notification change];
  NSNumber *valueOfChange = [change valueForKey:NSKeyValueChangeNewKey];
  maxMoreResultCountBeforeAbridging_ = [valueOfChange unsignedIntegerValue];
  NSTableView *resultsTableView = [self resultsTableView];
  [resultsTableView reloadData];
}

@end
