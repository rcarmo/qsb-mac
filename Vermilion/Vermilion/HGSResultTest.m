//
//  HGSResultTest.m
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


#import <GTM/GTMSenTestCase.h>
#import <GTM/GTMNSFileHandle+UniqueName.h>
#import <OCMock/OCMock.h>
#import "HGSResult.h"
#import "HGSSearchSource.h"

@interface HGSResultTest : GTMTestCase
@end

@implementation HGSResultTest

- (void)testStaticInit {
  NSString* path = @"file://url/to/path";
  // create an object with the full gamut and check the values
  HGSUnscoredResult* obj1 = [HGSUnscoredResult resultWithURI:path
                                                        name:@"everything"
                                                        type:@"text"
                                                      source:nil
                                                  attributes:nil];
  STAssertNotNil(obj1, @"can't create object");
  STAssertEqualObjects(path,
                       [obj1 uri],
                       @"invalid uri");
  STAssertEqualStrings(@"everything",
                       [obj1 valueForKey:kHGSObjectAttributeNameKey],
                       @"invalid name");
  STAssertEqualStrings(@"text",
                       [obj1 valueForKey:kHGSObjectAttributeTypeKey],
                       @"invalid type");

  // create an object with everything nil
  HGSUnscoredResult* obj3 = [HGSUnscoredResult resultWithURI:nil
                                                        name:nil
                                                        type:NULL
                                                      source:nil
                                                  attributes:nil];
  STAssertNil(obj3, @"created object");
}

- (void)testFilePathInit {

  NSString *path = nil;
  NSFileHandle *handle
    = [NSFileHandle gtm_fileHandleForTemporaryFileBasedOn:@"B;b"
                                                finalPath:&path];
  STAssertNotNil(handle, nil);
  STAssertNotNil(path, nil);
  HGSUnscoredResult *obj1 = [HGSUnscoredResult resultWithFilePath:path
                                                           source:nil
                                                       attributes:nil];
  STAssertNotNil(obj1, @"can't create object");
  STAssertEqualObjects([[NSURL URLWithString:[obj1 uri]] path],
                       path,
                       @"invalid uri %@", obj1);
  NSError *error = nil;
  STAssertTrue([[NSFileManager defaultManager] removeItemAtPath:path
                                                          error:&error],
               @"Unable to remove %@ (%@)", path, error);
}

- (void)testStaticInitFromDictionary {
  NSString* path = @"file:///bin/";

  // create an object from a dictionary and validate the keys are present. Since
  // we're setting the source, values we don't set should return non-nil.
  NSMutableDictionary* info = [NSMutableDictionary dictionary];
  [info setObject:path forKey:kHGSObjectAttributeURIKey];
  [info setObject:@"foo" forKey:kHGSObjectAttributeNameKey];
  [info setObject:@"bar" forKey:kHGSObjectAttributeTypeKey];
  id searchSourceMock = [OCMockObject mockForClass:[HGSSearchSource class]];
  HGSUnscoredResult* infoObject
    = [HGSUnscoredResult resultWithDictionary:info source:searchSourceMock];
  STAssertNotNil(infoObject, @"can't create object from dict");
  STAssertEqualObjects([NSURL URLWithString:path],
                       [infoObject url],
                       @"didn't find uri");
  [[[searchSourceMock expect]
    andReturn:kHGSObjectAttributeSnippetKey]
   provideValueForKey:kHGSObjectAttributeSnippetKey result:infoObject];
  STAssertEqualStrings(kHGSObjectAttributeSnippetKey,
                       [infoObject valueForKey:kHGSObjectAttributeSnippetKey],
                       @"didn't find template");
  [searchSourceMock verify];

  // create an object from a dictionary where the source doesn't implement
  // the correct protocol. This shouldn't throw or crash.
  NSMutableDictionary* info2 = [NSMutableDictionary dictionary];
  [info2 setObject:path forKey:kHGSObjectAttributeURIKey];
  [info2 setObject:@"foo" forKey:kHGSObjectAttributeNameKey];
  [info2 setObject:@"bar" forKey:kHGSObjectAttributeTypeKey];
  HGSUnscoredResult* infoObject2 = [HGSUnscoredResult resultWithDictionary:info2
                                                                    source:nil];
  STAssertNotNil(infoObject2, @"can't create object from dict");
  STAssertNil([infoObject2 valueForKey:kHGSObjectAttributeSnippetKey],
              @"found a snippet");

  // create an object wil a nil dictionary
  HGSUnscoredResult* nilObject = [HGSUnscoredResult resultWithDictionary:nil
                                                                  source:nil];
  STAssertNil(nilObject, @"created object from nil dict");

  // create an object with an empty dictionary
  HGSUnscoredResult* emptyObject
    = [HGSUnscoredResult resultWithDictionary:[NSDictionary dictionary]
                                       source:nil];
  STAssertNil(emptyObject, @"created object from empty dict");
}

- (void)testTypeCalls {
  NSString* url = @"http://someplace/";
  STAssertNotNil(url, nil);

  typedef struct {
    NSString *theType;
    BOOL tests[8];
  } TestData;

  TestData data[] = {
    { @"test",         { YES, NO,  NO,  NO,  YES, NO,  NO,  NO  } },
    { @"test.bar",     { NO,  YES, NO,  NO,  YES, YES, NO,  NO  } },
    { @"test.baz",     { NO,  NO,  NO,  NO,  YES, NO,  NO,  NO  } },
    { @"testbar",      { NO,  NO,  YES, NO,  NO,  NO,  YES, NO  } },
    { @"test.bar.baz", { NO,  NO,  NO,  NO,  YES, YES, NO,  NO  } },
    { @"bar",          { NO,  NO,  NO,  YES, NO,  NO,  NO,  YES } },
  };

  for (size_t i = 0; i < sizeof(data) / sizeof(TestData); i++) {

    // Create an object
    HGSUnscoredResult* obj = [HGSUnscoredResult resultWithURI:url
                                                         name:@"name"
                                                         type:data[i].theType
                                                       source:nil
                                                   attributes:nil];
    STAssertNotNil(obj, @"type %@", data[i].theType);
    STAssertEqualObjects(data[i].theType,
                         [obj type], @"type %@",
                         data[i].theType);

    // Test isOfType:
    STAssertEquals(data[i].tests[0],
                   [obj isOfType:@"test"],
                   @"type %@", data[i].theType);
    STAssertEquals(data[i].tests[1],
                   [obj isOfType:@"test.bar"],
                   @"type %@", data[i].theType);
    STAssertEquals(data[i].tests[2],
                   [obj isOfType:@"testbar"],
                   @"type %@", data[i].theType);
    STAssertEquals(data[i].tests[3],
                   [obj isOfType:@"bar"],
                   @"type %@", data[i].theType);

    // Test conformsToType:
    STAssertEquals(data[i].tests[4],
                   [obj conformsToType:@"test"],
                   @"type %@", data[i].theType);
    STAssertEquals(data[i].tests[5],
                   [obj conformsToType:@"test.bar"],
                   @"type %@", data[i].theType);
    STAssertEquals(data[i].tests[6],
                   [obj conformsToType:@"testbar"],
                   @"type %@", data[i].theType);
    STAssertEquals(data[i].tests[7],
                   [obj conformsToType:@"bar"],
                   @"type %@", data[i].theType);
  }
}

@end

@interface HGSResultArrayTest : GTMTestCase
@end

@implementation HGSResultArrayTest
- (void)testArrayWithFilePaths {
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  NSString *path1
    = [ws absolutePathForAppBundleWithIdentifier:@"com.apple.finder"];
  STAssertNotNil(path1, nil);
  NSString *path2
    = [ws absolutePathForAppBundleWithIdentifier:@"com.apple.Xcode"];
  STAssertNotNil(path2, nil);
  NSArray *paths = [NSArray arrayWithObjects:path1, path2, nil];
  HGSResultArray *results = [HGSResultArray arrayWithFilePaths:paths];
  STAssertNotNil(results, nil);
  STAssertEquals([results count], (NSUInteger)2, nil);
  STAssertEqualObjects([results displayName], @"Multiple Items", nil);
  HGSResult *result2 = [results objectAtIndex:1];
  STAssertEqualObjects(result2, [results lastObject], nil);
  NSArray *filePaths = [results filePaths];
  STAssertEquals([filePaths count], [results count], nil);
  NSArray *urls = [results urls];
  STAssertEquals([urls count], [results count], nil);

  BOOL isOfType = [results isOfType:@"badType"];
  STAssertFalse(isOfType, nil);
  NSString *resultType = [result2 type];
  isOfType = [results isOfType:resultType];
  STAssertTrue(isOfType, nil);
  isOfType = [results isOfType:nil];
  STAssertFalse(isOfType, nil);
  isOfType = [results isOfType:@""];
  STAssertFalse(isOfType, nil);


  BOOL conformsToType = [results conformsToType:@"badType"];
  STAssertFalse(conformsToType, nil);
  conformsToType = [results conformsToType:resultType];
  STAssertTrue(conformsToType, nil);
  conformsToType = [results conformsToType:nil];
  STAssertFalse(conformsToType, nil);
  conformsToType = [results conformsToType:@""];
  STAssertFalse(conformsToType, nil);

  NSImage *icon = [results icon];
  // Not using GTMAssertObjectImageEqualToImageNamed because it appears there
  // is an issue with the OS returning icons to us that aren't really
  // of generic color space.
  // TODO(dmaclach): dig into this and file a radar.
  STAssertNotNil(icon, nil);

  NSString *description = [results description];
  STAssertTrue([description hasPrefix:@"HGSResultArray results:"],
               @"description is %@", description);
}
@end

