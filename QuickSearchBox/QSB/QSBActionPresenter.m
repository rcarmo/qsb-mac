//
//  QSBActionPresenter.m
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

#import "QSBActionPresenter.h"

#import <Vermilion/Vermilion.h>
#import <GTM/GTMTypeCasting.h>

#import "QSBResultsWindowController.h"
#import "QSBActionModel.h"
#import "QSBPivotTextAttachment.h"
#import "QSBSearchController.h"
#import "QSBTableResult.h"

@interface QSBActionPresenter ()
- (void)selectedTableResultDidChange:(NSNotification *)notification;
@end

@implementation QSBActionPresenter

@synthesize currentActionArgument = currentActionArgument_;

- (id)initWithActionModel:(QSBActionModel *)model {
  if ((self = [super init])) {
    actionModel_ = [model retain];
    QSBSearchController *newController
      = [[[QSBSearchController alloc] initWithActionPresenter:self] autorelease];
    [actionModel_ pushSearchController:newController];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(selectedTableResultDidChange:)
               name:kQSBSelectedTableResultDidChangeNotification
             object:nil];
    if (!actionModel_) {
      [self release];
      self = nil;
      HGSLogDebug(@"Nil model passed into %@", NSStringFromSelector(_cmd));
    }
  }
  return self;
}

- (id)init {
  return [self initWithActionModel:[[[QSBActionModel alloc] init] autorelease]];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [actionModel_ release];
  [super dealloc];
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@: %p> Action: %@ "
          @"SearchControllerDepth: %d", [self class], self,
          [[[self actionOperation] action] displayName],
          [actionModel_ searchControllerCount]];
}

#pragma mark Private Methods

- (HGSAction *)actionFromPivotObjects:(HGSResultArray *)pivotObjects {
  HGSAction *action = nil;
  if ([pivotObjects count] == 1) {
    HGSResult *result = [pivotObjects lastObject];
    if ([result conformsToType:kHGSTypeAction]) {
      action = [result valueForKey:kHGSObjectAttributeDefaultActionKey];
    }
  }
  return action;
}

- (void)searchFor:(NSString *)text {
  HGSTokenizedString *tokenizedQueryString = [HGSTokenizer tokenizeString:text];
  QSBSearchController *activeController = [self activeSearchController];
  [activeController setTokenizedQueryString:tokenizedQueryString
                               pivotObjects:[activeController pivotObjects]];
}

- (void)pivotOnObjects:(HGSResultArray *)pivotObjects {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  QSBSearchController *oldSearchController = [self activeSearchController];
  QSBSearchController *newController
    = [[[QSBSearchController alloc] initWithActionPresenter:self] autorelease];
  NSDictionary *userInfo
    = [NSDictionary dictionaryWithObjectsAndKeys:
       oldSearchController, kQSBOldSearchControllerKey,
       newController, kQSBNewSearchControllerKey,
       nil];
  [nc postNotificationName:kQSBActionPresenterWillPivotNotification
                    object:self userInfo:userInfo];
  [actionModel_ pushSearchController:newController];

  NSUInteger pivotCount = [pivotObjects count];
  QSBSearchController *activeController = [self activeSearchController];

  if (pivotCount) {
    HGSAction *action = [self actionFromPivotObjects:pivotObjects];
    if (action) {
      HGSMutableActionOperation *operation = [actionModel_ actionOperation];
      [operation setAction:action];
      HGSResultArray *directObjects
        = [[pivotObjects lastObject]
           valueForKey:kHGSObjectAttributeActionDirectObjectsKey];
      [operation setArgument:directObjects forKey:kHGSActionDirectObjectsKey];
      currentActionArgument_ = [action nextArgumentToFillIn:operation];
    }
  }

  [activeController setTokenizedQueryString:nil
                               pivotObjects:pivotObjects];
  [nc postNotificationName:kQSBActionPresenterDidPivotNotification
                    object:self
                  userInfo:userInfo];
}

- (void)reset {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:kQSBActionPresenterWillResetNotification
                    object:self
                  userInfo:nil];
  [actionModel_ reset];
  QSBSearchController *newController
    = [[[QSBSearchController alloc] initWithActionPresenter:self] autorelease];
  [actionModel_ pushSearchController:newController];
  currentActionArgument_ = nil;
  [nc postNotificationName:kQSBActionPresenterDidResetNotification
                    object:self
                  userInfo:nil];
}

- (QSBTableResult *)selectedTableResult {
  return [actionModel_ selectedTableResult];
}

- (BOOL)canPivot {
  return [actionModel_ canPivot];
}

- (BOOL)canUnpivot {
  return [actionModel_ canUnpivot];
}

- (QSBSearchController *)activeSearchController {
  return [actionModel_ activeSearchController];
}

- (HGSActionOperation *)actionOperation {
  return [[[actionModel_ actionOperation] copy] autorelease];
}

- (NSAttributedString *)pivotAttributedString {
  NSMutableAttributedString *pivotString
    = [[[NSMutableAttributedString alloc] init] autorelease];
  NSUInteger controllerCount = [actionModel_ searchControllerCount];
  for (NSUInteger i = 1; i < controllerCount; ++i) {
    QSBSearchController *controller = [actionModel_ searchControllerAtIndex:i];
    QSBPivotTextAttachment *attachment
      = [[[QSBPivotTextAttachment alloc]
          initWithSearchController:controller] autorelease];
    NSAttributedString *attachmentString =
      [NSAttributedString attributedStringWithAttachment:attachment];
    [pivotString appendAttributedString:attachmentString];
  }
  QSBSearchController *controller
    = [actionModel_ searchControllerAtIndex:controllerCount - 1];
  HGSTokenizedString *query = [controller tokenizedQueryString];
  NSString *string = [query originalString];
  if (string) {
    NSAttributedString *attrString
      = [[[NSAttributedString alloc] initWithString:string] autorelease];
    [pivotString appendAttributedString:attrString];
  }
  return pivotString;
}

#pragma mark Notifications
- (void)selectedTableResultDidChange:(NSNotification *)notification {
  QSBTableResult *tableResult
    = [[notification userInfo] objectForKey:kQSBSelectedTableResultKey];
  [actionModel_ setSelectedTableResult:tableResult];
}

#pragma mark Actions

- (IBAction)qsb_pickCurrentSourceTableResult:(id)sender {
  QSBSourceTableResult *tableResult
    = GTM_STATIC_CAST(QSBSourceTableResult, [actionModel_ selectedTableResult]);
  HGSScoredResult *scoredResult = [tableResult representedResult];
  HGSMutableActionOperation *operation = [actionModel_ actionOperation];

  if (currentActionArgument_) {
    HGSTypeFilter *filter = [currentActionArgument_ typeFilter];
    if ([filter isValidType:[scoredResult type]]) {
      HGSResultArray *results = [HGSResultArray arrayWithResult:scoredResult];
      [operation setArgument:results forKey:[currentActionArgument_ identifier]];
    } else {
      NSBeep();
    }
  } else {
    HGSAction *action
      = [scoredResult valueForKey:kHGSObjectAttributeDefaultActionKey];
    if (action) {
      [operation setAction:action];
      HGSResultArray *directObjects = nil;
      if ([scoredResult conformsToType:kHGSTypeAction]) {
        directObjects
          = [scoredResult valueForKey:kHGSObjectAttributeActionDirectObjectsKey];
      } else {
        directObjects = [HGSResultArray arrayWithResult:scoredResult];
      }
      [operation setArgument:directObjects forKey:kHGSActionDirectObjectsKey];
    } else {
      HGSLog(@"Unable to get default action for %@", scoredResult);
    }
  }
  if ([operation isValid]) {
    // Create a non mutable copy of the operation and perform it,
    // in case someone attempts to change our current operation before
    // the operation gets a chance to be performed.
    HGSActionOperation *operationToPerform = [[operation copy] autorelease];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    NSDictionary *userInfo
      = [NSDictionary dictionaryWithObject:operationToPerform
                                    forKey:kQSBActionOperationKey];
    [nc postNotificationName:kQSBActionPresenterWillPerformActionNotification
                      object:self
                    userInfo:userInfo];
    [operationToPerform performAction];
  }
}

- (IBAction)qsb_pivotOnSelection:(id)sender {
  if (![self canPivot]) return;

  QSBTableResult *tableResult = [self selectedTableResult];
  QSBSourceTableResult *sourceTableResult = GTM_STATIC_CAST(QSBSourceTableResult,
                                                            tableResult);
  HGSResult *pivotObject = [sourceTableResult representedResult];
  HGSResultArray *pivotObjects = [HGSResultArray arrayWithResult:pivotObject];
  [self pivotOnObjects:pivotObjects];
}

- (IBAction)qsb_unpivotOnSelection:(id)sender {
  if (![self canUnpivot]) return;
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  QSBSearchController *oldSearchController = [self activeSearchController];
  NSUInteger count = [actionModel_ searchControllerCount];
  QSBSearchController *newController
    = [actionModel_ searchControllerAtIndex:count - 1];
  NSDictionary *userInfo
  = [NSDictionary dictionaryWithObjectsAndKeys:
     oldSearchController, kQSBOldSearchControllerKey,
     newController, kQSBNewSearchControllerKey,
     nil];
  [nc postNotificationName:kQSBActionPresenterWillUnpivotNotification
                    object:self userInfo:userInfo];
  HGSResultArray *pivotObjects = [oldSearchController pivotObjects];
  HGSAction *action = [self actionFromPivotObjects:pivotObjects];
  if (action) {
    [[actionModel_ actionOperation] reset];
    currentActionArgument_ = nil;
  }
  [actionModel_ popSearchController];
  [nc postNotificationName:kQSBActionPresenterDidUnpivotNotification
                    object:self
                  userInfo:userInfo];
}

- (IBAction)qsb_delimitResult:(id)sender {
  // TODO(dmaclach): Here's where we would support the comma operator.
}

@end
