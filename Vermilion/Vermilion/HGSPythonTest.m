//
//  HGSPythonTest.m
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


#import "GTMSenTestCase.h"
#import "HGSPython.h"
#import "HGSQuery.h"
#import "HGSTokenizer.h"

@interface HGSPythonTest : GTMTestCase 
@end

// The bulk of the HGSPython class gets tested via
// HGSPythonActionTest and HGSPythonSourceTest

@implementation HGSPythonTest

- (void)testQuery {
  HGSPython *sharedPython = [HGSPython sharedPython];
  STAssertNotNil(sharedPython, nil);
  HGSQuery *query = [[[HGSQuery alloc] initWithString:@"Hello world"
                                       actionArgument:nil
                                      actionOperation:nil
                                         pivotObjects:nil
                                           queryFlags:0] autorelease];
  STAssertNotNil(query, nil);
  
  PyObject *py = [sharedPython objectForQuery:query
                          withSearchOperation:nil];
  STAssertNotNULL(py, nil);
  
  NSString *rawQuery = [HGSPython stringAttribute:@"raw_query"
                                       fromObject:py];
  STAssertNotNil(rawQuery, nil);
  STAssertEqualObjects(rawQuery, @"Hello world", nil);
  
  NSString *normalizedQuery = [HGSPython stringAttribute:@"normalized_query"
                                              fromObject:py];
  STAssertNotNil(normalizedQuery, nil);
  STAssertEqualObjects(normalizedQuery, @"hello world", nil);
  
  PyObject *pivotObjectString = PyString_FromString("pivot_object");
  STAssertNotNULL(pivotObjectString, nil);

  PyObject *pivotObject = PyObject_GetAttr(py, pivotObjectString);
  STAssertNotNULL(pivotObject, nil);
  
  Py_DECREF(pivotObjectString);
  Py_DECREF(py);
}

- (void)testHGSPythonObject {
  // Force Python to be initialized
  HGSPython *sharedPython = [HGSPython sharedPython];
  STAssertNotNil(sharedPython, nil);

  HGSPythonObject *object =
    [HGSPythonObject pythonObjectWithObject:PyString_FromString("hi!")];
  STAssertNotNULL([object object], nil);
  STAssertNotNil(object, nil);
}

@end
