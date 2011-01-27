//
//  HGSSQLiteBackedCacheTest.m
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

#import "GTMSenTestCase.h"
#import "HGSSQLiteBackedCache.h"

@class HGSSQLiteBackendCache;

@interface HGSSQLiteBackedCacheTest : GTMTestCase {
  HGSSQLiteBackendCache* cache_;
}

- (NSString*)tempDbPath;
@end

@interface HGSSQLiteBackedCache ()

- (void)invalidateEntriesNotAccessedAfter:(NSDate *)date;
@end

@implementation HGSSQLiteBackedCacheTest

- (NSString*)tempDbPath {
  NSString *tempDir = NSTemporaryDirectory();
  NSString *result = [tempDir stringByAppendingPathComponent:@"unittest.db"];
  return result;
}

- (void)setUp {
  NSError* error = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:[self tempDbPath]]) {
    [fm removeItemAtPath:[self tempDbPath] error:&error];
    STAssertNil(error,
                @"Unable to delete file: %@: %@",
                [self tempDbPath],
                [error localizedDescription]);
  }
  cache_ = [[HGSSQLiteBackedCache alloc] initWithPath:[self tempDbPath]
                                              version:@"1.0"];
  STAssertNotNil(cache_, @"Unable to create DB");
}

- (void)testSetValueForKey {
  NSString *key = @"xx";
  NSString *expectedValue = @"yy";
  NSString *actualValue = nil;

  [cache_ setValue:expectedValue forKey:key];
  actualValue = [cache_ valueForKey:key];
  STAssertEqualStrings(actualValue, expectedValue, @"Value mismatch");
}

- (void)testSetNilValueForKey {
  NSString *key = @"xx";
  NSString *expectedValue = @"yy";
  NSString *actualValue = nil;

  [cache_ setValue:expectedValue forKey:key];
  actualValue = [cache_ valueForKey:key];
  STAssertEqualStrings(actualValue, expectedValue, @"Value mismatch");

  [cache_ setNilValueForKey:key];
  actualValue = [cache_ valueForKey:key];
  STAssertNil(actualValue,
              @"Expected nil value for cache, but got: %@",
              actualValue);
}

- (void)testCount {
  for (NSUInteger count = 1; count < 10; count++) {
    [cache_ setValue:@"blah" forKey:[NSString stringWithFormat:@"%d", count]];
    STAssertEquals(count,
                   [cache_ count],
                   @"Size mismatch: expected: %d actual: %d",
                   count,
                   [cache_ count]);
  }
  for (NSUInteger count = 10; count > 0; count--) {
    [cache_ setNilValueForKey:[NSString stringWithFormat:@"%d", count]];
    STAssertEquals(count - 1,
                   [cache_ count],
                   @"Size mismatch: expected: %d actual: %d",
                   count - 1,
                   [cache_ count]);

  }
}

- (void)testInvalidateEntriesNotAccessedAfter {
  // Insert a batch of entries that will be deleted.
  [cache_ setValue:@"xx" forKey:@"1"];
  [cache_ setValue:@"xx" forKey:@"2"];
  [cache_ setValue:@"xx" forKey:@"3"];
  [cache_ setValue:@"xx" forKey:@"4"];
  STAssertEquals((NSUInteger)4, [cache_ count], @"Size mismatch");

  // Record a checkpoint timestamp.
  [NSThread sleepForTimeInterval:2.0];
  NSDate *checkPoint = [NSDate date];
  [NSThread sleepForTimeInterval:2.0];

  // Insert some more entries after the checkpoint.
  [cache_ setValue:@"xx" forKey:@"5"];
  [cache_ setValue:@"xx" forKey:@"6"];
  STAssertEquals((NSUInteger)6, [cache_ count], @"Size mismatch");

  // Remove the entries that were inserted before the check point.
  [cache_ invalidateEntriesNotAccessedAfter:checkPoint];
  STAssertEquals((NSUInteger)2, [cache_ count], @"Size mismatch after delete");
}

- (void)tearDown {
  [cache_ release];
  cache_ = nil;

  NSError* error = nil;
  NSString *path = [self tempDbPath];
  [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
  STAssertNil(error,
              @"Unable to clean up after test: %@: %@",
              [self tempDbPath],
              [error localizedDescription]);
}

@end
