//
//  ___PROJECTNAMEASIDENTIFIER___Source.m
//  ___PROJECTNAME___
//
//  Created by ___FULLUSERNAME___ on ___DATE___.
//  Copyright ___ORGANIZATIONNAME___ ___YEAR___. All rights reserved.
//

#import <Vermilion/Vermilion.h>

@interface ___PROJECTNAMEASIDENTIFIER___Source : HGSCallbackSearchSource
@end

@implementation ___PROJECTNAMEASIDENTIFIER___Source

//- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
//  return YES;
//}

// Collect results for a search operation. You can use the pivot object
// and the query's tokenized string to perform your search
- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSQuery *query = [operation query];
  // The pivot object (if any)
  // HGSResult *pivotObject = [query pivotObject];
  HGSTokenizedString *term = [query tokenizedQueryString];
  if ([[term tokenizedString] isEqual:@"localhost"]) {
    CGFloat score = HGSCalibratedScore(kHGSCalibratedPerfectScore);
    HGSScoredResult *result
      = [HGSScoredResult resultWithURI:@"http://localhost"
                                  name:NSStringFromClass([self class])
                                  type:kHGSTypeWebpage
                                source:self
                            attributes:nil
                                 score:score
                                 flags:0
                           matchedTerm:term
                        matchedIndexes:nil];
    [operation setRankedResults:[NSArray arrayWithObject:result]];
  }
}

@end
