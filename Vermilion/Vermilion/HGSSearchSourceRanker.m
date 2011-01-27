//
//  HGSSearchSourceRanker.m
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

#import "HGSSearchSourceRanker.h"
#import "HGSMemorySearchSource.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSResult.h"
#import "HGSLog.h"
#import "HGSBundle.h"

static NSString *const kHGSSearchSourceRankerDataPointRunTimeKey
  = @"runtime";
static NSString *const kHGSSearchSourceRankerDataPointPromotionsKey
  = @"promotions";
static NSString *const kHGSSearchSourceRankerDataKey
  = @"HGSSearchSourceRankerData";
static NSString *const kHGSSearchSourceRankerSourceIDKey
  = @"HGSSearchSourceRankerSourceID";

// Ranks sources in the order that we should run them
@interface HGSSearchSourceRankerDataPoint : NSObject {
 @private
  UInt64 averageTime_;
  UInt64 promotions_;
  BOOL firstRunCompleted_;
}
- (id)initWithDictionary:(NSDictionary *)dict;
- (void)encodeToDictionary:(NSMutableDictionary *)dict;
- (void)addTimeDataPoint:(UInt64)machTime;
- (void)promote;
- (UInt64)averageTime;
- (UInt64)promotionCount;
@end

@interface HGSSearchSourceRanker ()

- (void)saveToPreferencesTimer:(NSTimer *)timer;
- (void)resultDidPromote:(NSNotification *)notification;
- (void)searchOperationDidFinish:(NSNotification *)notification;

@end

static NSInteger HGSSearchSourceRankerPerformanceSort(id src1,
                                                      id src2,
                                                      void *rankDict) {
  HGSSearchSource *source1 = (HGSSearchSource *)src1;
  HGSSearchSource *source2 = (HGSSearchSource *)src2;
  HGSAssert([source1 isKindOfClass:[HGSSearchSource class]], nil);
  HGSAssert([source2 isKindOfClass:[HGSSearchSource class]], nil);
  NSDictionary *rankDictionary = (NSDictionary *)rankDict;
  NSString *id1 = [source1 identifier];
  NSString *id2 = [source2 identifier];
  HGSAssert([id1 length], nil);
  HGSAssert([id2 length], nil);
  HGSSearchSourceRankerDataPoint *dp1 = [rankDictionary objectForKey:id1];
  HGSSearchSourceRankerDataPoint *dp2 = [rankDictionary objectForKey:id2];
  NSInteger order = NSOrderedSame;
  UInt64 time1 = [dp1 averageTime];
  UInt64 time2 = [dp2 averageTime];
  if (time1 > time2) {
    order = NSOrderedDescending;
  } else if (time1 < time2) {
    order = NSOrderedAscending;
  } else {
    UInt64 promoteCount1 = [dp1 promotionCount];
    UInt64 promoteCount2 = [dp2 promotionCount];
    if (promoteCount1 < promoteCount2) {
      order = NSOrderedDescending;
    } else if (promoteCount1 > promoteCount2) {
      order = NSOrderedAscending;
    } else {
      // If we have no data on either of them, run memory search sources first.
      // This will mainly apply for our first searches we run.
      Class memSourceClass = [HGSMemorySearchSource class];
      BOOL src1IsMemorySource = [source1 isKindOfClass:memSourceClass];
      BOOL src2IsMemorySource = [source2 isKindOfClass:memSourceClass];
      if (src1IsMemorySource && !src2IsMemorySource) {
        order = NSOrderedAscending;
      } else if (!src1IsMemorySource && src2IsMemorySource) {
        order = NSOrderedDescending;
      }
    }
  }
  return order;
}

static NSInteger HGSSourceRangePromotionSort(id a, id b, void *context) {
  NSNumber *numA
    = [a objectForKey:kHGSSearchSourceRankerDataPointPromotionsKey];
  NSNumber *numB
    = [b objectForKey:kHGSSearchSourceRankerDataPointPromotionsKey];
  unsigned long promoteA = [numA unsignedLongValue];
  unsigned long promoteB = [numB unsignedLongValue];
  NSInteger order = NSOrderedSame;
  if (promoteA < promoteB) {
    order = NSOrderedDescending;
  } else if (promoteA > promoteB) {
    order = NSOrderedAscending;
  }
  return order;
}


@implementation HGSSearchSourceRanker

@synthesize dirty = dirty_;


+ (HGSSearchSourceRanker *)sharedSearchSourceRanker {
  // Not using GTMObjectSingleton because we want to be able to
  // have both a shared version and be able to initialize these
  // ourselves for unit testing purposes.
  static HGSSearchSourceRanker *sharedRanker = nil;
  @synchronized (@"HGSSearchSourceSharedRankerSynchronization") {
    if (!sharedRanker) {
      sharedRanker = [[HGSSearchSourceRanker alloc] init];
    }
  }
  return sharedRanker;
}

- (id)init {
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSArray *array = [userDefaults arrayForKey:kHGSSearchSourceRankerDataKey];
  if (!array) {
    // Load defaults
    NSBundle *bundle = HGSGetPluginBundle();
    NSString *plistPath
      = [bundle pathForResource:@"HGSSearchSourceRankerCalibration"
                         ofType:@"plist"];
    array = [NSArray arrayWithContentsOfFile:plistPath];
  }
  HGSAssert(array, nil);
  self = [self initWithRankerData:array
                     sourcesPoint:[HGSExtensionPoint sourcesPoint]];
  if (self) {
    [NSTimer scheduledTimerWithTimeInterval:10
                                     target:self
                                   selector:@selector(saveToPreferencesTimer:)
                                   userInfo:@"saveToPreferencesTimer"
                                    repeats:YES];
  }
  return self;
}

- (id)initWithRankerData:(id)data sourcesPoint:(HGSExtensionPoint*)point {
  if ((self = [super init])) {
    HGSAssert(point, nil);
    HGSAssert([data isKindOfClass:[NSArray class]], nil);
    rankDictionary_ = [[NSMutableDictionary alloc] init];
    sourcesPoint_ = [point retain];
    if (data) {
      for (NSDictionary *entry in data) {
        NSString *key = [entry objectForKey:kHGSSearchSourceRankerSourceIDKey];
        HGSSearchSourceRankerDataPoint *dp
          = [[[HGSSearchSourceRankerDataPoint alloc] initWithDictionary:entry]
             autorelease];
        if (dp) {
          [rankDictionary_ setObject:dp forKey:key];
          promotionCount_ += [dp promotionCount];
        }
      }
    }
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(resultDidPromote:)
               name:kHGSResultDidPromoteNotification
             object:nil];
    [nc addObserver:self
           selector:@selector(searchOperationDidFinish:)
               name:kHGSSearchOperationDidFinishNotification
             object:nil];
  }
  return self;
}


- (void)dealloc {
  [rankDictionary_ release];
  [sourcesPoint_ release];
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [super dealloc];
}

- (id)rankerData {
  NSMutableArray *array = [NSMutableArray array];
  @synchronized (self) {
    for (NSString *sourceID in rankDictionary_) {
      HGSSearchSourceRankerDataPoint *dp
        = [rankDictionary_ objectForKey:sourceID];
      NSMutableDictionary *entry
        = [NSMutableDictionary dictionaryWithObject:sourceID
                                           forKey:kHGSSearchSourceRankerSourceIDKey];
      [dp encodeToDictionary:entry];
      [array addObject:entry];
    }
  }
  [array sortUsingFunction:HGSSourceRangePromotionSort context:NULL];
  return array;
}

- (void)addTimeDataPoint:(UInt64)machTime
               forSource:(HGSSearchSource *)source {
  NSString *sourceID = [source identifier];
  @synchronized (self) {
    HGSSearchSourceRankerDataPoint *dp
      = [rankDictionary_ objectForKey:sourceID];
    if (!dp) {
      dp = [[[HGSSearchSourceRankerDataPoint alloc] init] autorelease];
      [rankDictionary_ setObject:dp forKey:sourceID];
    }
    [dp addTimeDataPoint:machTime];
    [self setDirty:YES];
  }
}

- (UInt64)averageTimeForSource:(HGSSearchSource *)source {
  UInt64 avgTime = 0;
  NSString *sourceID = [source identifier];
  @synchronized (self) {
    HGSSearchSourceRankerDataPoint *dp
      = [rankDictionary_ objectForKey:sourceID];
    if (dp) {
      avgTime = [dp averageTime];
    }
  }
  return avgTime;
}

- (NSArray *)orderedSourcesByPerformance {
  NSMutableArray *sources
    = [NSMutableArray arrayWithArray:[sourcesPoint_ extensions]];
  @synchronized (self) {
    [sources sortUsingFunction:HGSSearchSourceRankerPerformanceSort
                       context:rankDictionary_];
  }
  return sources;
}

- (UInt64)promotionCount {
  return promotionCount_;
}

- (UInt64)promotionCountForSource:(HGSSearchSource *)source {
  NSString *identifier = [source identifier];
  HGSSearchSourceRankerDataPoint *dp
    = [rankDictionary_ objectForKey:identifier];
  return [dp promotionCount];
}

- (NSString *)description {
  NSArray *orderedSources = [self orderedSourcesByPerformance];
  NSMutableString *desc
    = [NSMutableString stringWithString:[super description]];
  for(HGSSearchSource *source in orderedSources) {
    NSString *identifier = [source identifier];
    HGSSearchSourceRankerDataPoint *dp
      = [rankDictionary_ objectForKey:identifier];
    [desc appendFormat:@" %15lld %@\n", [dp averageTime], [source displayName]];
  }
  return desc;
}

#pragma mark Timer and Notification callbacks
- (void)saveToPreferencesTimer:(NSTimer *)timer {
  if ([self isDirty]) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSArray *data = [self rankerData];
    [defaults setObject:data forKey:kHGSSearchSourceRankerDataKey];
    [self setDirty:NO];
  }
}

- (void)resultDidPromote:(NSNotification *)notification {
  HGSResult *result = [notification object];
  HGSSearchSource *source = [result source];
  NSString *sourceID = [source identifier];
  @synchronized (self) {
    HGSSearchSourceRankerDataPoint *dp
      = [rankDictionary_ objectForKey:sourceID];
    [dp promote];
    [self setDirty:YES];
    promotionCount_ += 1;
  }
}

- (void)searchOperationDidFinish:(NSNotification *)notification {
  HGSSearchOperation *operation = [notification object];
  if (![operation isCancelled]) {
    // only add a data point if the op wasn't cancelled.
    UInt64 runTime = [operation runTime];
    [self addTimeDataPoint:runTime
                 forSource:[operation source]];
  }
}

@end

@implementation HGSSearchSourceRankerDataPoint

- (id)initWithDictionary:(NSDictionary *)dict {
  if ((self = [super init])) {
    NSNumber *number
      = [dict objectForKey:kHGSSearchSourceRankerDataPointRunTimeKey];
    averageTime_ = [number unsignedLongLongValue];
    number = [dict objectForKey:kHGSSearchSourceRankerDataPointPromotionsKey];
    promotions_ = [number unsignedLongLongValue];
  }
  return self;
}

- (void)encodeToDictionary:(NSMutableDictionary *)dict {
  [dict setObject:[NSNumber numberWithUnsignedLongLong:[self averageTime]]
           forKey:kHGSSearchSourceRankerDataPointRunTimeKey];
  [dict setObject:[NSNumber numberWithUnsignedLongLong:promotions_]
           forKey:kHGSSearchSourceRankerDataPointPromotionsKey];
 }

- (void)addTimeDataPoint:(UInt64)machTime {
  if (firstRunCompleted_) {
    // Calculate a very simple moving average, but only if we already
    // have data to work with.
    if (averageTime_ > 0) {
      averageTime_ = ((machTime * 2) + averageTime_) / 3;
    } else {
      averageTime_ = machTime;
    }
  } else {
    firstRunCompleted_ = YES;
  }
}

- (UInt64)averageTime {
  return averageTime_;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"promotions %lu averageTime: %llu)",
          [self promotionCount], [self averageTime]];
}

- (void)promote {
  promotions_++;
}

- (UInt64)promotionCount {
  return promotions_;
}

@end
