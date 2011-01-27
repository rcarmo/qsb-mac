//
//  HGSWebInfo.m
//  WebInfo
//
//  Created by Nicholas Jitkoff on 4/17/08.
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

#import "HGSWebInfo.h"
//#import "GDataHTTPFetcher.h"
#import "GMLog.h"

@implementation HGSWebInfo
+ (id)infoWithURL:(NSURL *)url {
  return [[[self alloc] initWithURL:url] autorelease];
}

- (id)initWithURL:(NSURL *)url {
  self = [super init];
  if (self != nil) {
    url_ = [url retain];
  }
  return self;
}
- (void)dealloc {
  [url_ release];
  [super dealloc];
}

- (void)loadInfo {
  [infoDict_ release];
  infoDict_ = [[NSMutableDictionary alloc] init];
  NSXMLParser *parser = [[NSXMLParser alloc] initWithContentsOfURL:url_];
  [parser setDelegate:self];
  [parser parse];
  
  // TODO(alcor): make this async?
  //  NSURLRequest *request = [NSURLRequest requestWithURL:url_];
  //  NSData *data = [NSURLConnection sendSynchronousRequest:request
  //                                       returningResponse:nil
  //                                                   error:nil];
  //  GDataHTTPFetcher* myFetcher = [GDataHTTPFetcher httpFetcherWithRequest:request];
  //  [myFetcher beginFetchWithDelegate:self
  //                  didFinishSelector:@selector(myFetcher:finishedWithData:)
  //          didFailWithStatusSelector:@selector(myFetcher:failedWithStatus:data:)
  //           didFailWithErrorSelector:@selector(myFetcher:failedWithError:)];
}

- (NSDictionary *)infoDict {
  if (!infoDict_) {
    [self loadInfo]; 
  }
  return infoDict_;
}

//- (void)myFetcher:(GDataHTTPFetcher *)fetcher finishedWithData:(NSData *)retrievedData {
//  NSXMLParser *parser = [[NSXMLParser alloc] initWithData:retrievedData];
//  [parser setDelegate:self];
//  [parser parse];
//  [parser release];
//}
//
//- (void)myFetcher:(GDataHTTPFetcher *)fetcher failedWithStatus:(int)status data:(NSData *)data {
//  //TODO(alcor)
//}
//
//- (void)myFetcher:(GDataHTTPFetcher *)fetcher failedWithNetworkError:(NSError *)error {
//  //TODO(alcor)
//}

- (void)parser:(NSXMLParser *)parser 
didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict {
  if ([elementName caseInsensitiveCompare:@"body"] == NSOrderedSame)
    [parser abortParsing];
  
  if ([elementName caseInsensitiveCompare:@"link"] == NSOrderedSame) {
    
    // TODO(alcor): make these case insensitive (how?)
    NSString *rel = [attributeDict objectForKey:@"rel"];   
    if ([rel isEqualToString:@"shortcut icon"] || [rel isEqualToString:@"apple-touch-icon"]
        || [rel isEqualToString:@"search"]) {
      [infoDict_ setObject:attributeDict forKey:rel];
    }
  }
}

- (void)parser:(NSXMLParser *)parser
 didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI
 qualifiedName:(NSString *)qName{
  if ([elementName caseInsensitiveCompare:@"head"] == NSOrderedSame) 
    [parser abortParsing];  
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
  if ([parseError code] == NSXMLParserDelegateAbortedParseError) {
    GMLogErr(@"aborted %@", infoDict_); 
  } else {
    GMLogErr(@"error %@", parseError); 
  }
}

- (NSURL *)faviconURL {
  
  // TODO(alcor): make these case insensitive
  NSString *urlString = [infoDict_ valueForKeyPath:@"favicon.href"];
  return urlString ? [NSURL URLWithString:urlString] : nil;
}

- (NSURL *)largeIconURL {
  // TODO(alcor): make these case insensitive
  NSString *urlString = [infoDict_ valueForKeyPath:@"apple-touch-icon.href"];
  return urlString ? [NSURL URLWithString:urlString] : nil;
}

- (NSData *)openSearchData {
  
  // TODO(alcor): make these case insensitive
  NSString *href = [[self infoDict] valueForKeyPath:@"search.href"];
  if (!href) return nil;
  NSURL *relURL = [NSURL URLWithString:href relativeToURL:url_];
  return [NSData dataWithContentsOfURL:relURL];
}

- (HGSOpenSearch *)openSearchInfo {
  NSData *data = [self openSearchData];
  return [[[HGSOpenSearch alloc] initWithData:data] autorelease];
}


@end
