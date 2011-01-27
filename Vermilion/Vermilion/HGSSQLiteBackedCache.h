//
//  HGSSQLiteBackedCache.h
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

#import <Foundation/Foundation.h>

/*!
 @header
 @discussion HGSSQLiteBackedCache
*/

@class GTMSQLiteDatabase;

/*!
  A limited sized cache backed by SQLite.
*/
@interface HGSSQLiteBackedCache : NSObject {
 @private
  GTMSQLiteDatabase* db_;
  NSString* dbPath_;

  NSUInteger hardMaximumEntries_;  
  NSUInteger softMaximumEntries_;
  NSTimeInterval maximumAge_;
  __weak NSTimer *flushTimer_;
  
  /*!
    Stores a list of keys that were touched. Since writes are expensive,
    we batch all the accesses for a fixed time period and then write them all
    in one go.
  */
  NSMutableArray *pendingTouches_;
  BOOL useNSArchiver_;
}

/*!
  Exceeding this triggers a cleanup.
*/
@property (readwrite, assign, nonatomic) NSUInteger hardMaximumEntries;
/*!
  When deleting items, cache will be bought down to this size.
*/
@property (readwrite, assign, nonatomic) NSUInteger softMaximumEntries;
@property (readwrite, assign, nonatomic) NSTimeInterval maximumAge;
/*!
  Number of entries
*/
@property (readonly, nonatomic) NSUInteger count;

/*!
  Initialise the cache with the absolute path for storage.  If version !=
  version on disk, the cache will be emptied.
*/
- (id)initWithPath:(NSString *)path version:(NSString *)version;

/*!
  This class usually uses property list serialization for its blobs, this
  switches it to use NSKeyedArchiver
*/
- (id)initWithPath:(NSString *)path 
           version:(NSString *)version 
       useArchiver:(BOOL)flag;

/*!
  Writes any pending writes into the database, and performs cleanup of the
  database to ensure the size does not exceed the maximumEntries_ size.
*/
- (void)flush;

/*!
  Remove all the entries.
*/
- (void)removeAllObjects;
@end
