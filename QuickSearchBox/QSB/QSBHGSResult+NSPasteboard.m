//
//  QSBHGSResult+NSPasteboard.m
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

#import "QSBHGSResult+NSPasteboard.h"

@implementation HGSResultArray (HGSResultArrayPasteboard)

+ (HGSResultArray *)resultsWithPasteboard:(NSPasteboard *)pb {
  HGSResultArray *results = nil;  
  
  // TODO(alcor):keep track of the source of this copy/paste/service
  //  NSString *source = @"com.apple.clipboard";
  //  if (pasteboard == [NSPasteboard generalPasteboard]) {
  //    source = [[[NSWorkspace sharedWorkspace] activeApplication]
  //              objectForKey:@"NSApplicationBundleIdentifier"];
  //  }

  NSArray *paths = [pb propertyListForType:NSFilenamesPboardType];
  NSMutableArray *array = [NSMutableArray arrayWithCapacity:[paths count]];
  for (NSString *path in paths) {
    HGSUnscoredResult *result = [HGSUnscoredResult resultWithFilePath:path
                                                               source:nil
                                                           attributes:nil];
    HGSAssert(result, @"Unable to create result with %@", path);
    if (result) {
      [array addObject:result];
    }
  }
  if ([array count]) {
    results = [HGSResultArray arrayWithResults:array];
  }
  return results;
}

- (void)writeToPasteboard:(NSPasteboard *)pb {
  //TODO(alcor): support copy and paste
  NSBeep(); 
}

@end
