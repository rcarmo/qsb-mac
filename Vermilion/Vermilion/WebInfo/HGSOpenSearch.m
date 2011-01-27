//
//  HGSOpenSearch.m
//  WebInfo
//
//  Created by Nicholas Jitkoff on 5/1/08.
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

#import "HGSOpenSearch.h"


@implementation HGSOpenSearch
- (id)initWithData:(NSData *)data{
  self = [super init];
  if (self != nil) {
    infoDict_ = [[NSMutableDictionary alloc] init];
    NSXMLParser *parser = [[NSXMLParser alloc] initWithData:data];
    [parser setDelegate:self];
    
    // if data is nil, this fails
    if (![parser parse]) {
      [self release];
      self = nil;
    }
    [parser release];
  }
  return self;
}

- (void)dealloc {
  [infoDict_ release];
  [super dealloc];
}

- (NSDictionary *)searchURLInfo {
  return [infoDict_ valueForKey:@"text/html"];
}

- (NSDictionary *)suggestURLInfo {
  return [infoDict_ valueForKey:@"application/x-suggestions+json"];
}

// Parser handles blocks like this:
//
//<?xml version="1.0"?>
//<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
//<ShortName>Wikipedia (en)</ShortName>
//<Description>Wikipedia (en)</Description>
//<Image height="16" width="16" type="image/x-icon">http://en.wikipedia.org/favicon.ico</Image>
//<Url type="text/html" method="get" template="http://en.wikipedia.org/w/index.php?title=Special:Search&amp;search={searchTerms}"/>
//<Url type="application/x-suggestions+json" method="GET" template="http://en.wikipedia.org/w/api.php?action=opensearch&amp;search={searchTerms}&amp;namespace=0"/>
//</OpenSearchDescription>

- (void)parser:(NSXMLParser *)parser
didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI 
 qualifiedName:(NSString *)qualifiedName
    attributes:(NSDictionary *)attributeDict {
  // TODO(alcor): strip off namespace
  if ([elementName caseInsensitiveCompare:@"url"] == NSOrderedSame) {
    NSString *type = [attributeDict objectForKey:@"type"];
    [infoDict_ setObject:attributeDict forKey:type];
  }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName{
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
 NSLog(@"OpenSearch parse error: %@", parseError);
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
}

@end
