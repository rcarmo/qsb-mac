//
//  HGSSQLiteBackedCache.m
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

#import "HGSSQLiteBackedCache.h"
#import "HGSLog.h"

#import "GTMSQLite.h"

static NSTimeInterval const kCacheDefaultFlushInterval = 60.0; // once a minute
static NSTimeInterval const kCacheDefaultMaximumAge = 3600 * 24 * 7 * 2; // 2 weeks
static NSUInteger const kCacheDefaultMaxEntries = 10000;
static float const kCacheDefaultSoftMaxEntries = 8000;
static NSString* const kCachePendingTouchKey = @"key";
static NSString* const kCachePendingTouchTimestamp = @"timestamp";

static NSString* const kCacheSchema = @"CREATE TABLE IF NOT EXISTS cache ("
  @"  key TEXT PRIMARY KEY,"
  @"  value BLOB,"
  @"  accessed INT64,"
  @"  modified INT64)";

static NSString* const kMetaDataVersionKey = @"version";
static NSString* const kMetaDataSchema = @"CREATE TABLE IF NOT EXISTS metadata ("
  @"  key TEXT PRIMARY KEY,"
  @"  value TEXT)";

@interface HGSSQLiteBackedCache ()
- (BOOL)initDatabaseWithVersion:(NSString *)version;
- (void)addPendingTouch:(NSString *)key;
- (void)commitPendingTouches:(NSMutableArray *)touches;

- (void)invalidateEntriesNotAccessedAfter:(NSDate *)date;
- (void)invalidateLeastRecentlyUsedFrom:(NSUInteger)currentRows
                                     to:(NSUInteger)decreasedRows;
- (void)flushTimer:(NSTimer *)ignored;
@end

@implementation HGSSQLiteBackedCache
@synthesize hardMaximumEntries = hardMaximumEntries_;
@synthesize softMaximumEntries = softMaximumEntries_;
@synthesize maximumAge = maximumAge_;

- (id)initWithPath:(NSString *)path version:(NSString *)version {
  return [self initWithPath:path version:(NSString *)version useArchiver:NO];
}

- (id)initWithPath:(NSString *)path
           version:(NSString *)version
       useArchiver:(BOOL)flag {
  self = [super init];
  if (self) {
    dbPath_ = [path retain];
    pendingTouches_ = [[NSMutableArray alloc] init];
    flushTimer_
      = [NSTimer scheduledTimerWithTimeInterval:kCacheDefaultFlushInterval
                                         target:self
                                       selector:@selector(flushTimer:)
                                       userInfo:nil
                                        repeats:YES];
    maximumAge_ = kCacheDefaultMaximumAge;
    hardMaximumEntries_ = kCacheDefaultMaxEntries;
    softMaximumEntries_ = kCacheDefaultSoftMaxEntries;
    useNSArchiver_ = flag;
    BOOL goodInit = [self initDatabaseWithVersion:version];
    if (!goodInit) {
      HGSLogDebug(@"Unable to init shortcuts DB");
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [self flush];
  [flushTimer_ invalidate];
  [dbPath_ release];
  [db_ release];
  [pendingTouches_ release];
  [super dealloc];
}

- (BOOL)initDatabaseWithVersion:(NSString *)version {
  int errorCode;
  if (!db_) {
    NSString *directory = [dbPath_ stringByDeletingLastPathComponent];
    NSError *error;
    BOOL isDirectory = NO;
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL directoryExists = [fm fileExistsAtPath:directory
                                    isDirectory:&isDirectory];
    if (directoryExists && !isDirectory) {
      [fm removeItemAtPath:directory error:&error];
      directoryExists = NO;
    }
    if (!directoryExists) {
      if (![fm createDirectoryAtPath:directory
         withIntermediateDirectories:YES
                          attributes:nil
                               error:&error]) {
        HGSLog(@"Unable to create directory: %@", error);
        return NO;
      }
    }

    db_ = [[GTMSQLiteDatabase alloc] initWithPath:dbPath_
                                  withCFAdditions:NO
                                             utf8:YES
                                        errorCode:&errorCode];
    if (errorCode != SQLITE_OK && errorCode != SQLITE_DONE) {
      HGSLog(@"Unable to initialise database: %d", errorCode);
      return NO;
    }
  }

  // Create the table if it does not exist.
  errorCode = [db_ executeSQL:kCacheSchema];
  if (errorCode != SQLITE_OK) {
    HGSLog(@"Unable to create cache table: %@", [db_ lastErrorString]);
    return NO;
  }
  errorCode = [db_ executeSQL:kMetaDataSchema];
  if (errorCode != SQLITE_OK) {
    HGSLog(@"Unable to create metadata table: %@", [db_ lastErrorString]);
    return NO;
  }
  NSString *getVersionStatement = @"SELECT value FROM metadata WHERE key = ?";
  GTMSQLiteStatement *statement
    = [GTMSQLiteStatement statementWithSQL:getVersionStatement
                                inDatabase:db_
                                 errorCode:&errorCode];
  if ([statement bindStringAtPosition:1 string:kMetaDataVersionKey] != SQLITE_OK) {
    HGSLog(@"Unable to bind key: %@", [db_ lastErrorString]);
    return NO;
  }
  errorCode = [statement stepRow];
  NSString *dbVersion = @"0";
  if (errorCode == SQLITE_ROW) {
    dbVersion = [statement resultStringAtPosition:0];
  }
  [statement finalizeStatement];

  if (![dbVersion isEqualToString:version]) {
    // We're out of date. May want to handle this more gracefully in
    // the future, but for right now, just wipe out all of their
    // shortcuts.
    [self removeAllObjects];
    NSString *setVersionStatement
      = @"INSERT OR REPLACE INTO metadata VALUES(?, ?)";
    statement
      = [GTMSQLiteStatement statementWithSQL:setVersionStatement
                                  inDatabase:db_
                                   errorCode:&errorCode];
    if ([statement bindStringAtPosition:1
                                 string:kMetaDataVersionKey] != SQLITE_OK) {
      HGSLog(@"Unable to bind key: %@", [db_ lastErrorString]);
      return NO;
    }
    if ([statement bindStringAtPosition:2
                                 string:version] != SQLITE_OK) {
      HGSLog(@"Unable to bind value: %@", [db_ lastErrorString]);
      return NO;
    }
    errorCode = [statement stepRow];
    if (errorCode == SQLITE_ERROR) {
      HGSLog(@"Unable to add row: %@", [db_ lastErrorString]);
      return NO;
    }
    // finalize
    [statement finalizeStatement];
  }
  [self flush];
  return YES;
}

- (NSUInteger)count {
  int errorCode;
  NSString *countStatement = @"SELECT COUNT(*) FROM cache";
  GTMSQLiteStatement *statement
    = [GTMSQLiteStatement statementWithSQL:countStatement
                                inDatabase:db_
                                 errorCode:&errorCode];
  int result = [statement stepRow];
  NSUInteger count = 0;
  if (result == SQLITE_ROW) {
    count = [[statement resultNumberAtPosition:0] unsignedIntValue];
  } else {
    HGSLog(@"Unable to get count of cache: %@", [db_ lastErrorString]);
  }
  [statement finalizeStatement];
  return count;
}

#pragma mark Maintenance

// Adds a value to |pendingTouches_| to mark certain entries as accesses.
// The pendingTouches_ are regularly flushed to the database. This avoids
// a write penalty for each read.
- (void)addPendingTouch:(NSString *)key {
  NSTimeInterval touch = [[NSDate date] timeIntervalSince1970];
  [pendingTouches_ addObject:[NSDictionary dictionaryWithObjectsAndKeys:
    key,
    kCachePendingTouchKey,
    [NSNumber numberWithLongLong:(long long)touch],
    kCachePendingTouchTimestamp,
    nil]];
}

- (void)commitPendingTouches:(NSMutableArray *)touches {
  int errorCode;
  NSString* touchStatement = @"UPDATE cache SET accessed = ? WHERE key = ?";
  GTMSQLiteStatement *statement
    = [GTMSQLiteStatement statementWithSQL:touchStatement
                                inDatabase:db_
                                 errorCode:&errorCode];
  if (errorCode != SQLITE_OK) {
    HGSLog(@"Error create statement: %@", [db_ lastErrorString]);
    return;
  }

  [db_ beginDeferredTransaction];
  {
    // TODO(altse): Needs testing.
    for (NSDictionary *touch in touches) {
      NSString *pendingTouch = [touch objectForKey:kCachePendingTouchKey];
      NSNumber *timeStamp = [touch objectForKey:kCachePendingTouchTimestamp];
      [statement bindStringAtPosition:1 string:pendingTouch];
      [statement bindLongLongAtPosition:2 value:[timeStamp longLongValue]];
      [statement stepRow];
    }
    [statement finalizeStatement];
  }
  [db_ commit];
  [touches removeAllObjects];
}

#pragma mark Compressing

- (void)removeAllObjects {
  static NSString* const kDeleteStatement = @"DELETE FROM cache";
  int errorCode;
  GTMSQLiteStatement *statement
    = [GTMSQLiteStatement statementWithSQL:kDeleteStatement
                                inDatabase:db_
                                 errorCode:&errorCode];
  [statement stepRow];
  [statement finalizeStatement];
}

- (void)invalidateEntriesNotAccessedAfter:(NSDate *)date {
  NSTimeInterval unixTimestamp = [date timeIntervalSince1970];
  static NSString* const kDeleteByDateStatement =
  @"DELETE FROM cache WHERE accessed < ?";
  int errorCode;
  GTMSQLiteStatement *statement
    = [GTMSQLiteStatement statementWithSQL:kDeleteByDateStatement
                                inDatabase:db_
                                 errorCode:&errorCode];
  if (errorCode != SQLITE_OK) {
    HGSLog(@"Unable to create SQLite statement: %@", [db_ lastErrorString]);
    return;
  }

  [statement bindLongLongAtPosition:1 value:(long long)unixTimestamp];
  if ([statement stepRow] == SQLITE_ERROR) {
    HGSLog(@"Unable to delete by date: %@", [db_ lastErrorString]);
  }
  [statement finalizeStatement];
}

- (void)invalidateLeastRecentlyUsedFrom:(NSUInteger)currentRows
                                     to:(NSUInteger)decreasedRows {
  int errorCode;
  NSUInteger toRemove = currentRows - decreasedRows;
  NSString *sql = [NSString stringWithFormat:@"DELETE FROM cache WHERE key IN "
                   @" (SELECT key FROM cache ORDER BY accessed LIMIT %d)",
                   toRemove];
  GTMSQLiteStatement *statement
    = [GTMSQLiteStatement statementWithSQL:sql
                                inDatabase:db_
                                 errorCode:&errorCode];
  if (errorCode != SQLITE_OK) {
    HGSLog(@"Unable to create SQLite statement: %@", [db_ lastErrorString]);
    return;
  }

  [statement stepRow];
  [statement finalizeStatement];
}

#pragma mark Flushing

- (void)flushTimer:(NSTimer *)ignored {
  [self flush];
}

// A regular method that's called to clean up cache entries. Expected to be
// called on the main thread.
- (void)flush {
  // Do nothing, including removing the old and/or excess entries, unless
  // the cache has some new entries to process.  Otherwise, we'll prevent
  // the machine from going to sleep.
  if ([pendingTouches_ count]) {
    [self commitPendingTouches:pendingTouches_];

    NSDate *oldestEntryDate
      = [NSDate dateWithTimeIntervalSinceNow:(-1 * maximumAge_)];
    [self invalidateEntriesNotAccessedAfter:oldestEntryDate];

    // If our size still exceeds our maximum entries, get rid of least recently
    // accessed entries.
    NSUInteger count = [self count];
    if (count > hardMaximumEntries_) {
      [self invalidateLeastRecentlyUsedFrom:count to:softMaximumEntries_];
    }
  }
}

#pragma mark NSKeyValueCoding

// Read value from an SQL backend.
- (id)valueForKey:(NSString *)key {
  NSString* selectStatement = @"SELECT value FROM cache WHERE key = ?";
  int errorCode;
  GTMSQLiteStatement *statement =
    [GTMSQLiteStatement statementWithSQL:selectStatement
                              inDatabase:db_
                               errorCode:&errorCode];
  if (errorCode != SQLITE_OK) {
    HGSLog(@"Unable to create SQLite statement: %@", [db_ lastErrorString]);
    return nil;
  }

  if ([statement bindStringAtPosition:1 string:key] != SQLITE_OK) {
    HGSLog(@"Unable to bind key: %@", [db_ lastErrorString]);
    return nil;
  }
  // Execute
  int result = [statement stepRow];
  if (result == SQLITE_ERROR) {
    [statement finalizeStatement];
    HGSLog(@"Error occurred executing statement: %@", [db_ lastErrorString]);
    return nil;
  }
  if (result != SQLITE_ROW) {
    // Not found.
    [statement finalizeStatement];
    return nil;
  }

  NSData *valueData = [statement resultBlobDataAtPosition:0];
  [statement finalizeStatement];
  if (!valueData) {
    HGSLog(@"Unable to retrieve value: nil returned.");
    return nil;
  }

  id theValue;
  if (useNSArchiver_) {
    @try {
      theValue = [NSKeyedUnarchiver unarchiveObjectWithData:valueData];
    }
    @catch (NSException * e) {
      HGSLog(@"Exception unarchiving object: %@", e);
      return nil;
    }
  } else {
    NSString *errorString = nil;
    theValue
      = [NSPropertyListSerialization propertyListFromData:valueData
                                         mutabilityOption:NSPropertyListImmutable
                                                   format:nil
                                         errorDescription:&errorString];
    if (errorString) {
      HGSLog(@"Unable to parse as plist: %@", errorString);
      return nil;
    }
  }

  [self addPendingTouch:key];
  return theValue;
}

- (void)setValue:(id)value forKey:(NSString *)key {
  NSString* errorString = nil;
  NSData* valueData = nil;

  if (useNSArchiver_) {
    valueData = [NSKeyedArchiver archivedDataWithRootObject:value];
  } else {
    valueData
      = [NSPropertyListSerialization dataFromPropertyList:value
                                                   format:NSPropertyListBinaryFormat_v1_0
                                         errorDescription:&errorString];
    if (errorString) {
      HGSLog(@"Unable to serialize value for cache: %@", errorString);
      return;
    }
  }

  NSTimeInterval unixTimestamp = [[NSDate date] timeIntervalSince1970];

  NSString* insertStatement = @"INSERT OR REPLACE INTO cache VALUES (?, ?, ?, ?)";
  int errorCode;
  GTMSQLiteStatement *statement
    = [GTMSQLiteStatement statementWithSQL:insertStatement
                                inDatabase:db_
                                 errorCode:&errorCode];
  [statement bindStringAtPosition:1 string:key];
  [statement bindBlobAtPosition:2 data:valueData];
  [statement bindLongLongAtPosition:3 value:(long long)unixTimestamp];
  [statement bindLongLongAtPosition:4 value:(long long)unixTimestamp];
  // execute
  int insertResult = [statement stepRow];
  if (insertResult == SQLITE_ERROR) {
    HGSLog(@"Unable to add row: %@", [db_ lastErrorString]);
  }
  // finalize
  [statement finalizeStatement];
}

- (void)setNilValueForKey:(NSString *)key {
  NSString* deleteStatement = @"DELETE FROM cache WHERE key = ?";
  int errorCode;
  GTMSQLiteStatement *statement
    = [GTMSQLiteStatement statementWithSQL:deleteStatement
                                inDatabase:db_
                                 errorCode:&errorCode];
  [statement bindStringAtPosition:1 string:key];
  [statement stepRow];
  [statement finalizeStatement];
}
@end
