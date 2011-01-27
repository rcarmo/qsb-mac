//
//  NSString+ReadableURLTest.m
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
#import "NSString+ReadableURL.h"

@interface NSStringReadableURLTest : GTMTestCase
@end

@implementation NSStringReadableURLTest

- (void)testEverything {
  typedef struct  {
    NSString *original;
    NSString *expected;
  } TestData;
  
  TestData data[] = {
    // test each of the things handled on their own
    { @"http://google.com", @"google.com" },
    { @"www.google.com", @"google.com" },
    { @"google.com/foo?", @"google.com/foo" },
    { @"google.com/", @"google.com" },
    { @"google.com/index.html", @"google.com" },
    { @"GOOGLE.COM/INDEX.HTML", @"GOOGLE.COM" },
    { @"google.com/index.htm", @"google.com" },
    { @"google.com/index.php", @"google.com" },
    { @"google.com/index.asp", @"google.com" },
    { @"google.com/index.raw", @"google.com" },
    // now test some combinations
    { @"http://www.google.com/foo/bar/index.html", @"google.com/foo/bar" },
    { @"http://www.google.com/index.php?", @"google.com" },
    { @"http://www.google.com/?", @"google.com" },
    { @"https://www.google.com/", @"https://www.google.com" },
    { @"https://www.google.com/index.php?", @"https://www.google.com" },
    { @"ftp://www.google.com/", @"ftp://www.google.com" },
    // and some things that shouldn't be changed
    { @"https://www.google.com", @"https://www.google.com" },
    { @"ftp://www.google.com", @"ftp://www.google.com" },
    { @"https://mail.google.com:443/a/domain.com/#inbox", @"https://mail.google.com:443/a/domain.com/#inbox" },
    { @"https://www.google.com/index.xyz", @"https://www.google.com/index.xyz" },
    { @"https://www.google.com/index.php/foo", @"https://www.google.com/index.php/foo" },
  };

  for (size_t i = 0; i < sizeof(data) / sizeof(*data); i++) {
    NSString *original = data[i].original;
    NSString *expected = data[i].expected;
    STAssertEqualObjects([original readableURLString], expected,
                         @"test data index %lu", (unsigned long)i);
  }
}

@end
