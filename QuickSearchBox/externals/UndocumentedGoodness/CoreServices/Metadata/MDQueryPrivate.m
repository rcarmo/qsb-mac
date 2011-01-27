//
// MDQueryPrivate.m
//

#include "MDQueryPrivate.h"

Boolean MDQueryPrivateIsSpotlightIndexing(void) {
  BOOL indexing = NO;
  NSArray *spotlightStatus = (NSArray *)_MDCopyIndexingStatus();
  for (NSDictionary *dict in spotlightStatus) {
    NSNumber *filesInFlight = [dict objectForKey:@"FilesInflightScan"];
    if ([filesInFlight integerValue] != 0) {
      indexing = YES;
      break;
    }
  }
  [spotlightStatus release];
  return indexing;
}
