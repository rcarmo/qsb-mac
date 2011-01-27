//
//  HGSPathCellElement.m
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

#import "HGSPathCellElement.h"
#import "QSBHGSResultAttributeKeys.h"

@implementation HGSPathCellElement

@synthesize title = title_;
@synthesize url = url_;
@synthesize image = image_;

+ (id)elementWithTitle:(NSString *)title url:(NSURL *)url {
  HGSPathCellElement *element
    = [[[HGSPathCellElement alloc]
        initElementWithTitle:title url:url image:nil] autorelease];
  return element;
}

- (id)initElementWithTitle:(NSString *)title
                       url:(NSURL *)url
                     image:(NSImage *)image {
  if ((self = [super init])) {
    title_ = ([title length]) ? [title copy] : @"";
    url_ = [url retain];
    image_ = [image retain];
  }
  return self;
}

- (void)dealloc {
  [title_ release];
  [url_ release];
  [image_ release];  
  [super dealloc];
}

+ (NSArray *)pathCellArrayWithElements:(NSArray *)elements {
  NSMutableArray *cellArray = nil;
  for (HGSPathCellElement *element in elements) {
    NSMutableDictionary *pathCell
      = [NSMutableDictionary dictionaryWithObject:[element title]
                                           forKey:kQSBPathCellDisplayTitleKey];
    if ([element url]) {
      [pathCell setObject:[element url] forKey:kQSBPathCellURLKey];
    }
    if ([element image]) {
      [pathCell setObject:[element image] forKey:kQSBPathCellImageKey];
    }
    if (cellArray) {
      [cellArray addObject:pathCell];
    } else {
      cellArray = [NSMutableArray arrayWithObject:pathCell];
    }
  }
  return cellArray;
}

@end

