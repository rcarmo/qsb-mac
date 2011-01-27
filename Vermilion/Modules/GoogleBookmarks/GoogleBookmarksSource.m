//
//  GoogleBookmarksSource.m
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

#import <Vermilion/Vermilion.h>
#import <GData/GDataHTTPFetcher.h>
#import <QSBPluginUI/QSBHGSResultAttributeKeys.h>
#import "HGSKeychainItem.h"
#import "GTMGoogleSearch.h"


static const NSTimeInterval kRefreshSeconds = 3600.0;  // 60 minutes.

// Only report errors to user once an hour.
static const NSTimeInterval kErrorReportingInterval = 3600.0;  // 1 hour

@interface GoogleBookmarksSource : HGSMemorySearchSource <HGSAccountClientProtocol> {
 @private
  NSTimer *updateTimer_;
  HGSFetcherOperation *fetchOperation_;
  HGSSimpleAccount *account_;
  NSURL *baseURL_;
}

- (void)setUpPeriodicRefresh;
- (void)startAsynchronousBookmarkFetch;
- (void)indexBookmarksFromData:(NSData*)data operation:(NSOperation *)op;
- (void)indexBookmarkNode:(NSXMLNode*)bookmarkNode
                operation:(NSOperation *)op
                     into:(HGSMemorySearchSourceDB*)database;
- (void)loginCredentialsChanged:(NSNotification *)notification;
- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData
          operation:(NSOperation *)operation;
- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
            didFail:(NSError *)error
          operation:(NSOperation *)operation;
@end

@implementation GoogleBookmarksSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    account_ = [[configuration objectForKey:kHGSExtensionAccountKey] retain];
    if (account_) {
      // Fetch, and schedule a timer to update every hour.
      [self startAsynchronousBookmarkFetch];
      [self setUpPeriodicRefresh];
      // Watch for credential changes.
      NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
      [nc addObserver:self
             selector:@selector(loginCredentialsChanged:)
                 name:kHGSAccountDidChangeNotification
               object:account_];
    }
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [fetchOperation_ release];
  [updateTimer_ release];
  [account_ release];
  [baseURL_ release];
  [super dealloc];
}

- (void)uninstall {
  [fetchOperation_ cancel];
  [updateTimer_ invalidate];
  [super uninstall];
}

#pragma mark -
#pragma mark Bookmarks Fetching

- (void)startAsynchronousBookmarkFetch {
  if (!fetchOperation_ || [fetchOperation_ isFinished]) {
    GTMGoogleSearch *gsearch = [GTMGoogleSearch sharedInstance];
    NSDictionary *args = [NSDictionary dictionaryWithObjectsAndKeys:
                          @"rss", @"output", @"10000", @"num", nil];
    NSString *bookmarkRequestString
      = [gsearch searchURLFor:nil
                       ofType:@"bookmarks/find"
                    arguments:args];
    NSRange findRange = [bookmarkRequestString rangeOfString:@"/find?"];
    HGSAssert(findRange.location != NSNotFound, nil);
    NSString *baseURLString
      = [bookmarkRequestString substringToIndex:findRange.location];
    baseURL_ = [[NSURL URLWithString:baseURLString] retain];
    bookmarkRequestString
      = [bookmarkRequestString
         stringByReplacingOccurrencesOfString:@"http:"
                                   withString:@"https:"
                                      options:NSLiteralSearch | NSAnchoredSearch
                                        range:NSMakeRange(0, 5)];
    NSURL *bookmarkRequestURL = [NSURL URLWithString:bookmarkRequestString];
    NSMutableURLRequest *bookmarkRequest
      = [NSMutableURLRequest
         requestWithURL:bookmarkRequestURL
            cachePolicy:NSURLRequestReloadIgnoringCacheData
        timeoutInterval:15.0];
    GDataHTTPFetcher *fetcher
      = [GDataHTTPFetcher httpFetcherWithRequest:bookmarkRequest];

    if (!fetcher) {
      HGSLog(@"Failed to allocate GDataHTTPFetcher.");
    }
    HGSKeychainItem* keychainItem
      = [HGSKeychainItem keychainItemForService:[account_ identifier]
                                       username:nil];
    NSString *userName = [keychainItem username];
    NSString *password = [keychainItem password];
    [fetcher setCredential:
     [NSURLCredential credentialWithUser:userName
                                password:password
                             persistence:NSURLCredentialPersistenceNone]];
    [bookmarkRequest setHTTPMethod:@"POST"];
    [fetcher setRequest:bookmarkRequest];

    HGSOperationQueue *queue = [HGSOperationQueue sharedOperationQueue];
    [fetchOperation_ release];
    fetchOperation_
      = [[HGSFetcherOperation alloc] initWithTarget:self
                                         forFetcher:fetcher
                                  didFinishSelector:@selector(httpFetcher:finishedWithData:operation:)
                                    didFailSelector:@selector(httpFetcher:didFail:operation:)];
   [queue addOperation:fetchOperation_];
  }
}

- (void)refreshBookmarks:(NSTimer *)timer {
  [self startAsynchronousBookmarkFetch];
  [self setUpPeriodicRefresh];
}

- (void)indexBookmarksFromData:(NSData *)data operation:(NSOperation *)op {
  if ([op isCancelled]) return;
  NSXMLDocument* bookmarksXML
    = [[[NSXMLDocument alloc] initWithData:data
                                   options:0
                                     error:nil] autorelease];
  NSArray *bookmarkNodes = [bookmarksXML nodesForXPath:@"//item" error:NULL];
  HGSMemorySearchSourceDB *database = [HGSMemorySearchSourceDB database];
  NSEnumerator *nodeEnumerator = [bookmarkNodes objectEnumerator];
  NSXMLNode *bookmark;
  while ((bookmark = [nodeEnumerator nextObject])) {
    if ([op isCancelled]) break;
    [self indexBookmarkNode:bookmark operation:op into:database];
  }
  [self replaceCurrentDatabaseWith:database];
}

- (void)indexBookmarkNode:(NSXMLNode*)bookmarkNode
                operation:(NSOperation *)op
                     into:(HGSMemorySearchSourceDB*)database {
  NSString *title = nil;
  NSString *url = nil;
  NSMutableArray *otherTermStrings = [NSMutableArray array];
  NSArray *nodeChildren = [bookmarkNode children];
  for (NSXMLNode *infoNode in nodeChildren) {
    NSString *infoNodeName = [infoNode name];
    if ([infoNodeName isEqualToString:@"title"]) {
      title = [infoNode stringValue];
    } else if ([infoNodeName isEqualToString:@"link"]) {
      url = [infoNode stringValue];
      // TODO(stuartmorgan): break the URI, and make those into title terms as well
    } else if ([infoNodeName isEqualToString:@"smh:bkmk_label"] ||
               [infoNodeName isEqualToString:@"smh:bkmk_annotation"]) {
      NSString *infoNodeString = [infoNode stringValue];
      [otherTermStrings addObject:infoNodeString];
    }
  }


  if (!url || [op isCancelled]) {
    return;
  }

  NSImage *icon = [NSImage imageNamed:@"blue-nav"];
  NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSUnderHomeRankFlag];

  // Compose the contents of the path control:
  //  - account name
  //  - host
  //  - subdomain (if any)
  NSMutableArray *cellArray = [NSMutableArray array];
  NSString *userName = [account_ userName];
  NSDictionary *userCell = [NSDictionary dictionaryWithObjectsAndKeys:
                            userName, kQSBPathCellDisplayTitleKey,
                            baseURL_, kQSBPathCellURLKey,
                            nil];
  [cellArray addObject:userCell];

  NSRange range = [url rangeOfString:@"://"];
  if (range.location == NSNotFound) {
    HGSLog(@"Unable to index bookmark %@", url);
    return;
  }
  NSUInteger hostPos = NSMaxRange(range);
  NSString *host = [url substringFromIndex:hostPos];
  NSString *subdomain = nil;
  range = [host rangeOfString:@"/"];
  if (range.location != NSNotFound) {
    // No subdomain found.
    hostPos += NSMaxRange(range);
    subdomain = [host substringFromIndex:range.location];
    host = [host substringToIndex:range.location];
  }
  NSURL *hostURL = [NSURL URLWithString:[url substringToIndex:hostPos]];
  NSDictionary *hostCell = [NSDictionary dictionaryWithObjectsAndKeys:
                            host, kQSBPathCellDisplayTitleKey,
                            hostURL, kQSBPathCellURLKey,
                            nil];
  [cellArray addObject:hostCell];

  if ([subdomain length] > 1) {
    NSDictionary *subdomainCell = [NSDictionary dictionaryWithObjectsAndKeys:
                                   subdomain, kQSBPathCellDisplayTitleKey,
                                   [NSURL URLWithString:url], kQSBPathCellURLKey,
                                   nil];
    [cellArray addObject:subdomainCell];
  }

  NSDictionary *attributes
    = [NSDictionary dictionaryWithObjectsAndKeys:
       rankFlags, kHGSObjectAttributeRankFlagsKey,
       url, kHGSObjectAttributeSourceURLKey,
       icon, kHGSObjectAttributeIconKey,
       cellArray, kQSBObjectAttributePathCellsKey,
       @"star-flag", kHGSObjectAttributeFlagIconNameKey,
       nil];
  HGSUnscoredResult* result
    = [HGSUnscoredResult resultWithURI:url
                                  name:([title length] > 0 ? title : url)
                                  type:HGS_SUBTYPE(kHGSTypeWebBookmark,
                                                   @"googlebookmarks")
                                source:self
                            attributes:attributes];
  [database indexResult:result
                   name:title
             otherTerms:otherTermStrings];
}

#pragma mark -
#pragma mark GDataHTTPFetcher Helpers

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)retrievedData
          operation:(NSOperation *)operation {
  [self indexBookmarksFromData:retrievedData operation:operation];
}

- (void)httpFetcher:(GDataHTTPFetcher *)fetcher
            didFail:(NSError *)error
          operation:(NSOperation *)operation {
  HGSLog(@"httpFetcher failed: %@ %@", error, [[fetcher request] URL]);
}

#pragma mark -
#pragma mark Authentication & Refresh

- (void)loginCredentialsChanged:(NSNotification *)notification {
  HGSAssert([notification object] == account_,
            @"Notification from bad account!");
  // Make sure we aren't in the middle of waiting for results; if we are, try
  // again later instead of changing things in the middle of the fetch.
  if (![fetchOperation_ isFinished]) {
    [self performSelector:@selector(loginCredentialsChanged:)
               withObject:notification
               afterDelay:60.0];
    return;
  }

  // If the login changes, we should update immediately, and make sure the
  // periodic refresh is enabled (it would have been shut down if the previous
  // credentials were incorrect).
  [self startAsynchronousBookmarkFetch];
  [self setUpPeriodicRefresh];
}

- (void)setUpPeriodicRefresh {
  [updateTimer_ invalidate];
  [updateTimer_ release];
  // We add 5 minutes worth of random jitter.
  NSTimeInterval jitter = arc4random() / (LONG_MAX / (NSTimeInterval)300.0);
  updateTimer_
    = [[NSTimer scheduledTimerWithTimeInterval:kRefreshSeconds + jitter
                                        target:self
                                      selector:@selector(refreshBookmarks:)
                                      userInfo:nil
                                       repeats:NO] retain];
}

#pragma mark -
#pragma mark HGSAccountClientProtocol Methods

- (BOOL)accountWillBeRemoved:(HGSAccount *)account {
  HGSAssert(account == account_, @"Notification from bad account!");
  return YES;
}

@end
