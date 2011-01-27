//
//  SLFilesSourceTest.m
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

#import "HGSUnitTestingUtilities.h"
#import "SLFilesSource.h"
#import "GTMNSAppleScript+Handler.h"
#import <OCMock/OCMock.h>

@interface SLFilesOperation (SLFilesOperationTesting)

- (HGSScoredResult *)resultFromQuery:(MDQueryRef)query
                                item:(MDItemRef)mdItem
                               group:(NSUInteger)group
                               index:(NSUInteger)idx;

@end

@interface SLFilesSourceTest : HGSSearchSourceAbstractTestCase {
 @private
  NSString *testFolderPath_;
  NSString *uniqueTestString_;
}
@end

@implementation SLFilesSourceTest
  
- (id)initWithInvocation:(NSInvocation *)invocation {
  NSString *cachePath = nil;
  NSProcessInfo *info = [NSProcessInfo processInfo];
  cachePath = [[info environment] objectForKey:@"DERIVED_FILES_DIR"];
  if (![cachePath length]) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory,
                                                         NSUserDomainMask, 
                                                         YES);
    STAssertTrue([paths count] > 0, nil);
    cachePath = [paths objectAtIndex:0];
  }
  
  testFolderPath_ 
    = [[cachePath stringByAppendingPathComponent:@"QSBMacTestFiles"] retain];
  NSString *volumePath;
  if ([testFolderPath_ hasPrefix:@"/Volumes/"]) {
    NSArray *pathElements = [testFolderPath_ pathComponents];
    pathElements = [pathElements subarrayWithRange:NSMakeRange(0,3)];
    volumePath = [NSString pathWithComponents:pathElements];
  } else {
    volumePath = @"/";
  }
  NSTask *slTestTask = [[[NSTask alloc] init] autorelease];
  [slTestTask setLaunchPath:@"/usr/bin/mdutil"];
  [slTestTask setArguments:[NSArray arrayWithObjects:@"-s", volumePath, nil]];
  NSPipe *outPipe = [NSPipe pipe];
  [slTestTask setStandardOutput:outPipe];
  [slTestTask launch];
  [slTestTask waitUntilExit];
  NSFileHandle *slOut = [outPipe fileHandleForReading];
  NSData *outData = [slOut readDataToEndOfFile];
  NSString *outString 
    = [[[NSString alloc] initWithData:outData 
                             encoding:NSUTF8StringEncoding] autorelease];
  if ([outString rangeOfString:@"Indexing enabled."].location != NSNotFound) {
    self = [super initWithInvocation:invocation 
                         pluginNamed:@"SpotlightFiles" 
                 extensionIdentifier:@"com.google.qsb.spotlightfiles.source"];
  } else {
    HGSLog(@"**** SLFilesSourceTests disabled because drive %@ does not have "
           @"indexing enabled.", volumePath);
    [self release];
    self = nil;
  }
  return self;
}

- (void)dealloc {
  [testFolderPath_ release];
  [super dealloc];
}

- (void)setUp {
  [super setUp];
  NSFileManager *manager = [NSFileManager defaultManager];
  BOOL isDir = YES;
  BOOL goodDir = [manager fileExistsAtPath:testFolderPath_ isDirectory:&isDir];
  if (!goodDir) {
    NSError *error = nil;
    STAssertTrue([manager createDirectoryAtPath:testFolderPath_
                    withIntermediateDirectories:YES 
                                     attributes:nil 
                                          error:&error],
                 @"Unable to create directory at %@ (%@)", 
                 testFolderPath_, error);
  } else {
    STAssertTrue(isDir, @"File at %@ isn't a directory", testFolderPath_);
  }
  
  // Weird split done so that spotlight doesn't find this source file for us
  // when we search for our "unique string"
  uniqueTestString_ 
    = [[NSString stringWithFormat:@"%@%@", @"aichmor", @"habdophobia"] retain];
}
  
- (void)tearDown {
  NSFileManager *manager = [NSFileManager defaultManager];
  NSError *error;
  STAssertTrue([manager removeItemAtPath:testFolderPath_ error:&error],
               @"Unable to remove folder at %@ (%@)", testFolderPath_, error);
  [super tearDown];
}

- (NSString *)createTestFile:(NSString *)name {
  NSString *testFilePath 
    = [testFolderPath_ stringByAppendingPathComponent:name];
  NSError *error = nil;
  BOOL goodFileWrite = [uniqueTestString_ writeToFile:testFilePath 
                                           atomically:YES 
                                             encoding:NSUTF8StringEncoding 
                                                error:&error];
  [[NSWorkspace sharedWorkspace] noteFileSystemChanged:testFilePath];
  STAssertTrue(goodFileWrite, @"Unable to write file to %@ (%@)",
               testFilePath, error);
  return testFilePath;
}
  
- (void)mdimportFile:(NSString *)path {
  NSArray *args = [NSArray arrayWithObjects:@"-d", @"2", path, nil];
  NSTask *mdimport = [NSTask launchedTaskWithLaunchPath:@"/usr/bin/mdimport" 
                                              arguments:args];
  [mdimport waitUntilExit];
  STAssertEquals([mdimport terminationStatus], 0, 
                 @"mdimport for %@ exited with %d", path, 
                 [mdimport terminationStatus]);
}

- (NSArray *)performSearchFor:(NSString *)value 
                   pivotingOn:(HGSResultArray *)pivots {
  HGSQuery *query = [[[HGSQuery alloc] initWithString:value 
                                       actionArgument:nil
                                      actionOperation:nil
                                         pivotObjects:pivots 
                                           queryFlags:0] autorelease];
  STAssertNotNil(query, nil);
  HGSSearchOperation *operation = [[self source] searchOperationForQuery:query];
  STAssertNotNil(operation, nil);
  [operation runOnCurrentThread:YES];
  NSSet *suggestSet = [NSSet setWithObject:kHGSTypeSuggest];
  HGSTypeFilter *filter
    = [HGSTypeFilter filterWithDoesNotConformTypes:suggestSet];
  NSUInteger count = [operation resultCountForFilter:filter];
  return [operation sortedRankedResultsInRange:NSMakeRange(0, count)
                                    typeFilter:filter];
}

- (HGSResult *)spotlightResultForQuery:(NSString *)queryString
                                  path:(NSString *)path {
  HGSQuery *query = [[[HGSQuery alloc] initWithString:queryString 
                                       actionArgument:nil
                                      actionOperation:nil
                                         pivotObjects:nil 
                                           queryFlags:0] autorelease];
  HGSSearchOperation *op = [[self source] searchOperationForQuery:query];
  Class cls = NSClassFromString(@"SLFilesOperation");
  STAssertTrue([op isKindOfClass:cls], nil);
  MDItemRef mdItem = MDItemCreate(kCFAllocatorDefault, (CFStringRef)path);
  STAssertNotNULL(mdItem, @"Unable to create mdItem for %@", path);  
  SLFilesOperation *slOp = (SLFilesOperation*)op;
  HGSResult *result = [slOp resultFromQuery:NULL item:mdItem group:0 index:0];
  STAssertNotNil(result, nil);
  CFRelease(mdItem);
  return result;
}

- (NSArray *)archivableResults {
  NSString *paths[] = {
    @"/Applications/TextEdit.app",
    @"/System"
  };
  size_t count = sizeof(paths) / sizeof(paths[0]);
  NSMutableArray *results 
    = [NSMutableArray arrayWithCapacity:count];
  for (size_t i = 0; i < count; ++i) {
    HGSResult *result = [self spotlightResultForQuery:uniqueTestString_
                                                 path:paths[i]];
    STAssertNotNil(result, nil);
    [results addObject:result];
  }
  return results;
}

- (void)testNilOperation {
  HGSSearchOperation *operation = [[self source] searchOperationForQuery:nil];
  STAssertNil(operation, nil);
}

- (void)testUtiFilter {
  NSString *testFilePath = [self createTestFile:@"testSimpleOperation.txt"];
  OCMockObject *bundleMock = [OCMockObject mockForClass:[NSBundle class]];
  NSDictionary *config = 
    [NSDictionary dictionaryWithObjectsAndKeys:
     bundleMock, kHGSExtensionBundleKey,
     @"SLFilesSourceTest.testUtiFilter.identifier", kHGSExtensionIdentifierKey,
     @"testUtiFilter", kHGSExtensionUserVisibleNameKey,
     @"testPath", kHGSExtensionIconImagePathKey,
     (NSString*)kUTTypeData, kHGSSearchSourceUTIsToExcludeFromDiskSourcesKey,
     nil];
  [[[bundleMock expect] andReturn:@"testUtiFilter"] 
   qsb_localizedInfoPListStringForKey:@"testUtiFilter"];
  [[[bundleMock expect] andReturn:@"imagePath"] pathForImageResource:@"testPath"];
  HGSSearchSource *source 
    = [[[HGSSearchSource alloc] initWithConfiguration:config] autorelease];
  HGSExtensionPoint *sourcesPoint = [HGSExtensionPoint sourcesPoint];
  [sourcesPoint extendWithObject:source];
  [self mdimportFile:testFilePath];
  NSArray *results = [self performSearchFor:uniqueTestString_ pivotingOn:nil];
  STAssertEquals([results count], (NSUInteger)0, @"Got results %@", results);
  [sourcesPoint removeExtension:source];
}

- (void)testValidSourceForQuery {
  HGSSearchSource *source = [self source];
  HGSQuery *query = [[[HGSQuery alloc] initWithString:@"ha" 
                                       actionArgument:nil
                                      actionOperation:nil
                                         pivotObjects:nil 
                                           queryFlags:0] autorelease]; 
  STAssertFalse([source isValidSourceForQuery:query], 
                @"Queries < 3 characters should be ignored");
  query = [[[HGSQuery alloc] initWithString:@"hap" 
                             actionArgument:nil
                            actionOperation:nil
                               pivotObjects:nil 
                                 queryFlags:0] autorelease]; 
  STAssertTrue([source isValidSourceForQuery:query], 
                @"Queries >= 3 characters should be accepted");
  
  NSDictionary *badTypeDict
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"http://www.google.com", kHGSObjectAttributeURIKey,
       @"badTypeDict", kHGSObjectAttributeNameKey,
       kHGSTypeFile, kHGSObjectAttributeTypeKey,
       nil];
  HGSUnscoredResult *badTypeResult 
    = [HGSUnscoredResult resultWithDictionary:badTypeDict source:source];
  query 
    = [[[HGSQuery alloc] initWithString:@"happy" 
                         actionArgument:nil
                        actionOperation:nil
                           pivotObjects:[NSArray arrayWithObject:badTypeResult] 
                             queryFlags:0] autorelease]; 
  STAssertFalse([source isValidSourceForQuery:query],
                @"Queries with pivot of type kHGSTypeFile should fail.");
  
  NSDictionary *goodTypeDict
    = [NSDictionary dictionaryWithObjectsAndKeys:
       @"http://www.google.com", kHGSObjectAttributeURIKey,
       @"goodTypeDict", kHGSObjectAttributeNameKey,
       kHGSTypeContact, kHGSObjectAttributeTypeKey,
       nil];
  HGSUnscoredResult *goodTypeResult = [HGSUnscoredResult resultWithDictionary:goodTypeDict 
                                                                       source:source];
  query 
    = [[[HGSQuery alloc] initWithString:@"happy" 
                         actionArgument:nil
                        actionOperation:nil
                           pivotObjects:[NSArray arrayWithObject:goodTypeResult] 
                             queryFlags:0] autorelease]; 
  STAssertTrue([source isValidSourceForQuery:query],
               @"Queries with pivot of type kHGSTypeContact should succeed.");
}

- (void)testBadMailPivot {
  HGSSearchSource *source = [self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *mailFilePath = [pluginBundle pathForResource:@"SampleEmail"
                                                  ofType:@"emlx"];
  STAssertNotNil(mailFilePath, nil);
  [self mdimportFile:mailFilePath];
  HGSScoredResult *mailResult = [HGSScoredResult resultWithFilePath:mailFilePath 
                                                             source:source
                                                         attributes:nil
                                                              score:0
                                                              flags:0
                                                        matchedTerm:nil 
                                                     matchedIndexes:nil];
  STAssertNotNil(mailResult, nil);
  HGSResultArray *array = [HGSResultArray arrayWithResult:mailResult];
  STAssertNotNil(array, nil);
  NSArray *results = [self performSearchFor:@"sender" pivotingOn:array];
  STAssertEquals([results count], (NSUInteger)0, nil);
}

- (void)testGoodMailPivot {
  HGSSearchSource *source = [self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *mailFilePath = [pluginBundle pathForResource:@"SampleEmail"
                                                  ofType:@"emlx"];
  STAssertNotNil(mailFilePath, nil);
  [self mdimportFile:mailFilePath];
  HGSUnscoredResult *mailResult 
    = [HGSUnscoredResult resultWithFilePath:mailFilePath
                                     source:source
                                 attributes:nil];
  STAssertNotNil(mailResult, nil);
  NSDictionary *attributes 
    = [NSDictionary dictionaryWithObject:@"willy_wonka@wonkamail.com"
                                  forKey:kHGSObjectAttributeContactEmailKey];
  HGSUnscoredResult *contactResult 
    = [HGSUnscoredResult resultWithURI:@"test:contact" 
                                  name:@"Willy Wonka" 
                                  type:kHGSTypeContact
                                source:source 
                            attributes:attributes];
  STAssertNotNil(contactResult, nil);
  HGSScoredResult *scoredResult 
    = [HGSScoredResult resultWithResult:contactResult 
                                  score:0 
                             flagsToSet:0
                           flagsToClear:0
                            matchedTerm:nil 
                         matchedIndexes:nil];
  STAssertNotNil(scoredResult, nil);
  HGSResultArray *array = [HGSResultArray arrayWithResult:scoredResult];
  STAssertNotNil(array, nil);
  NSArray *results = [self performSearchFor:@"vermicious" pivotingOn:array];
  STAssertNotNil(results, nil);
  BOOL foundResult = NO;
  for (HGSResult *result in results) {
    if ([[result filePath] isEqualToString:mailFilePath]) {
      foundResult = YES;
      NSArray *emailArray
        = [source provideValueForKey:kHGSObjectAttributeEmailAddressesKey 
                              result:result];
      NSSet *emailSet = [NSSet setWithArray:emailArray];
      NSSet *expectedEmailSet = [NSSet setWithObjects:
                                 @"deeproy_oompaloopa@wonkamail.com", 
                                 @"willy_wonka@wonkamail.com", 
                                 @"charles_bucket@wonkamail.com", 
                                 nil];
      STAssertEqualObjects(emailSet, expectedEmailSet, nil);
      NSArray *contactsArray
        = [source provideValueForKey:kHGSObjectAttributeContactsKey 
                              result:result];
      NSSet *contactsSet = [NSSet setWithArray:contactsArray];
      NSSet *expectedContacts = [NSSet setWithObjects:
                                 @"Deep Roy Oompa Loompa",
                                 @"Willy Wonka",
                                 @"Charlie Bucket",
                                 nil];
      STAssertEqualObjects(contactsSet, expectedContacts, nil);
      
      NSImage *icon = [source provideValueForKey:kHGSObjectAttributeIconKey 
                                          result:result];
      STAssertNil(icon, @"We only expect source to return icons for Web stuff");
      break;
    } else {
      HGSLog(@"%@ - %@", result, [result filePath]);
    }
  }
  STAssertTrue(foundResult, nil);
}

- (void)testIcon {
  HGSSearchSource *source = [self source];
  NSBundle *pluginBundle = HGSGetPluginBundle();
  NSString *webhistoryPath = [pluginBundle pathForResource:@"SampleWeb"
                                                    ofType:@"webhistory"];
  STAssertNotNil(webhistoryPath, nil);
  [self mdimportFile:webhistoryPath];
  HGSResult *result = [self spotlightResultForQuery:@"willywonkaschocolates"
                                               path:webhistoryPath];
  // Normally this would be pulled from the app bundle. When running tests
  // we don't have an app bundle, so we'll create our own.
  NSImage *cachedImage = [[[NSImage alloc] init] autorelease];
  [cachedImage setName:@"blue-nav"];
  NSImage *icon = [source provideValueForKey:kHGSObjectAttributeIconKey 
                                      result:result];
  STAssertEqualObjects([icon name], 
                       @"blue-nav", 
                       @"Source provides icons for things with URLS\n%@",
                       result);
}

- (void)testFileTypes {
  NSMutableArray *filePaths = [NSMutableArray array];
  NSMutableArray *expectedTypes = [NSMutableArray array];
  struct {
    NSString *fileName;
    NSString *fileExtension;
    NSString *expectedType;
  } fileMap[] = {
    { @"SampleMusic", @"mid", kHGSTypeFileMusic },
    { @"SampleMovie", @"mov", kHGSTypeFileMovie },
    { @"SampleImage", @"jpeg", kHGSTypeFileImage },
    { @"SamplePDF", @"pdf", kHGSTypeFilePDF },
    { @"SampleContact", @"abcdp", kHGSTypeContact },
    { @"SampleWeb", @"webhistory", kHGSTypeWebHistory },
    { @"SampleCal", @"ics", kHGSTypeFileCalendar },
    { @"SampleText", @"txt", kHGSTypeTextFile },
    { @"SampleEmail", @"emlx", kHGSTypeEmail },
    { @"SampleBookmark", @"webloc", kHGSTypeWebBookmark }
  };
  NSBundle *bundle = HGSGetPluginBundle();
  for (size_t i = 0; i < sizeof(fileMap) / sizeof(fileMap[0]); ++i) {
    NSString *path = [bundle pathForResource:fileMap[i].fileName 
                                      ofType:fileMap[i].fileExtension];
    STAssertNotNil(path, @"Unable to find %@.%@", 
                   fileMap[i].fileName, 
                   fileMap[i].fileExtension);
    [filePaths addObject:path];
    [expectedTypes addObject:fileMap[i].expectedType];
  }
  NSString *finderPath 
    = [[NSWorkspace sharedWorkspace] 
       absolutePathForAppBundleWithIdentifier:@"com.apple.Finder"];
  STAssertNotNil(finderPath, nil);
  [filePaths addObject:finderPath];
  [expectedTypes addObject:kHGSTypeFileApplication];
  [filePaths addObject:@"/Applications"];
  [expectedTypes addObject:kHGSTypeDirectory];
  [filePaths addObject:@"/System/Library/DTDs/sdef.dtd"];
  [expectedTypes addObject:kHGSTypeFile];
  NSUInteger i = 0;
  for (NSString *path in filePaths) {
    HGSResult *result = [self spotlightResultForQuery:uniqueTestString_ 
                                                 path:path];
    STAssertNotNil(result, @"No result for %@", path);
    STAssertEqualObjects([result type], 
                         [expectedTypes objectAtIndex:i], 
                          @"Path: %@", path);
    ++i;
  }
}

@end

