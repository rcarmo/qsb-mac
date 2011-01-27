//
//  FileSystemsActionsTest.m
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

#import "HGSUnitTestingUtilities.h"
#include <unistd.h>
#import <GTM/GTMNSFileHandle+UniqueName.h>
#import "FilesystemActions.h"

@interface FileSystemRenameActionTest : HGSActionAbstractTestCase
@end

@implementation FileSystemRenameActionTest

- (id)initWithInvocation:(NSInvocation *)invocation {
  self = [super initWithInvocation:invocation
                       pluginNamed:@"CorePlugin"
               extensionIdentifier:@"com.google.core.filesystem.action.rename"];
  return self;
}

- (NSString *)returnParentDirForRenameTemplate:(NSString *)template
                                     toNewName:(NSString *)newName {
  // Create a temp file to play with
  NSString *path = nil;
  NSFileHandle *handle
    = [NSFileHandle gtm_fileHandleForTemporaryFileBasedOn:template
                                                finalPath:&path];
  STAssertNotNil(handle, nil);
  STAssertNotNil(path, nil);

  // Create up our file result
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  HGSSearchSource *source = [HGSUnitTestingSource sourceWithBundle:bundle];
  STAssertNotNil(source, nil);
  HGSScoredResult *scoredResult
    = [HGSScoredResult resultWithFilePath:path
                                   source:source
                               attributes:nil
                                    score:0
                                    flags:0
                              matchedTerm:nil
                           matchedIndexes:nil];
  STAssertNotNil(scoredResult, nil);

  // Create our text result
  HGSSearchSource *textSource
    = (HGSSearchSource *)[self extensionWithIdentifier:@"com.google.qsb.core.textinput.source"
                                       fromPluginNamed:@"CorePlugin"
                              extensionPointIdentifier:kHGSSourcesExtensionPoint
                                              delegate:nil];
  STAssertNotNil(textSource, nil);

  NSDictionary *pasteBoardValue
    = [NSDictionary dictionaryWithObject:newName
                                  forKey:NSStringPboardType];
  NSDictionary *attributes
    = [NSDictionary dictionaryWithObject:pasteBoardValue
                                  forKey:kHGSObjectAttributePasteboardValueKey];

  HGSUnscoredResult *textResult
    = [HGSUnscoredResult resultWithURI:@"userinput:text"
                                  name:newName
                                  type:kHGSTypeTextUserInput
                                source:textSource
                            attributes:attributes];

  // Create our action info
  STAssertNotNil(textResult, nil);
  HGSResultArray *directObjects = [HGSResultArray arrayWithResult:scoredResult];
  STAssertNotNil(directObjects, nil);
  HGSResultArray *names = [HGSResultArray arrayWithResult:textResult];
  STAssertNotNil(names, nil);
  NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                        directObjects, kHGSActionDirectObjectsKey,
                        names, @"com.google.core.filesystem.action.rename.name",
                        nil];

  // Perform rename
  HGSAction *action = [self action];
  STAssertNotNil(action, nil);
  BOOL isGood = [action performWithInfo:info];
  STAssertTrue(isGood, nil);
  return [path stringByDeletingLastPathComponent];
}

- (void)testRenameUseOldExtension {
  // New Name no extension
  NSString *newName
    = GTMUniqueFileObjectPathBasedOn(@"FileSystemRenameActionTestNewName1XXXXXX");
  STAssertNotNil(newName, nil);
  NSString *parent
    = [self returnParentDirForRenameTemplate:@"FileSystemRenameActionTest1XXXXXX.txt"
                                   toNewName:newName];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *expectedPath = [parent stringByAppendingPathComponent:newName];
  expectedPath = [expectedPath stringByAppendingPathExtension:@"txt"];
  STAssertTrue([fm fileExistsAtPath:expectedPath], @"File not at %@",
               expectedPath);
  NSError *error = nil;
  STAssertTrue([fm removeItemAtPath:expectedPath error:&error],
               @"Unable to remove file at %@ (%@)", expectedPath, error);
}

- (void)testRenameUseNewExtension {
  NSString *newName
    = GTMUniqueFileObjectPathBasedOn(@"FileSystemRenameActionTestNewName2XXXXXX");
  newName = [newName stringByAppendingPathExtension:@"bar"];
  NSString *parent
    = [self returnParentDirForRenameTemplate:@"FileSystemRenameActionTest2XXXXXX.txt"
                                   toNewName:newName];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *expectedPath = [parent stringByAppendingPathComponent:newName];
  STAssertTrue([fm fileExistsAtPath:expectedPath], @"File not at %@",
               expectedPath);
  NSError *error = nil;
  STAssertTrue([fm removeItemAtPath:expectedPath error:&error],
               @"Unable to remove file at %@ (%@)", expectedPath, error);
}

- (void)testRenameNoExtension {
  // No extensions
  NSString *newName
    = GTMUniqueFileObjectPathBasedOn(@"FileSystemRenameActionTestNewName3XXXXXX");
  NSString *parent
    = [self returnParentDirForRenameTemplate:@"FileSystemRenameActionTest3XXXXXX"
                                   toNewName:newName];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *expectedPath = [parent stringByAppendingPathComponent:newName];
  STAssertTrue([fm fileExistsAtPath:expectedPath], @"File not at %@",
               expectedPath);
  NSError *error = nil;
  STAssertTrue([fm removeItemAtPath:expectedPath error:&error],
               @"Unable to remove file at %@ (%@)", expectedPath, error);
}

@end

