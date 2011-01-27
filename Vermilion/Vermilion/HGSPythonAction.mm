//
//  HGSPythonAction.m
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

#import "HGSPythonAction.h"
#import "HGSLog.h"
#import "HGSBundle.h"
#import "HGSResult.h"

static const char *const kHGSPythonAppliesToResults = "AppliesToResults";
static const char *const kHGSPythonPerform = "Perform";

@implementation HGSPythonAction

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    NSString *moduleName = [configuration objectForKey:kPythonModuleNameKey];
    NSString *className = [configuration objectForKey:kPythonClassNameKey];
    // Default module to class if it's not set specifically
    if ([moduleName length] == 0) {
      moduleName = className;
    }
    if (!moduleName || !className) {
      HGSLogDebug(@"Can't instantiate python action. "
                  @"Missing %@ or %@ in %@", kPythonModuleNameKey,
                  kPythonClassNameKey, configuration);
      [self release];
      return nil;
    }
    NSString *resourcePath = [[self bundle] resourcePath];
    HGSPython *sharedPython = [HGSPython sharedPython];
    if (resourcePath) {
      [sharedPython appendPythonPath:resourcePath];
    }
    
    PythonStackLock gilLock;
    
    module_ = [sharedPython loadModule:moduleName];
    if (!module_) {
      HGSLogDebug(@"failed to load Python module %@", moduleName);
      [self release];
      return nil;
    }
    
    // Instantiate the class
    PyObject *dict = PyModule_GetDict(module_);
    PyObject *pythonClass = PyDict_GetItemString(dict, [className UTF8String]);
    if (!pythonClass) {
      NSString *error = [HGSPython lastErrorString];
      HGSLogDebug(@"could not find Python class %@.\n%@", className, error);
      [self release];
      return nil;
    }
    if (!PyCallable_Check(pythonClass)) {
      NSString *error = [HGSPython lastErrorString];
      HGSLogDebug(@"no ctor for Python class %@.\n%@", className, error);
      [self release];
      return nil;
    }
    PyObject *args = PyTuple_New(1);
    PyObject *opaqueExtension = [sharedPython objectForExtension:self];
    PyTuple_SetItem(args, 0, opaqueExtension);
    instance_ = PyObject_CallObject(pythonClass, args);
    Py_DECREF(opaqueExtension);
    if (!instance_) {
      NSString *error = [HGSPython lastErrorString];
      HGSLogDebug(@"could not instantiate Python class %@.\n%@", 
                  className, error);
      [self release];
      return nil;
    }
    perform_ = PyString_FromString(kHGSPythonPerform);
    if (!perform_) {
      NSString *error = [HGSPython lastErrorString];
      HGSLogDebug(@"could not create Python string %s.\n%@", 
                  kHGSPythonPerform, error);
      [self release];
      return nil;
    }
    appliesTo_ = PyString_FromString(kHGSPythonAppliesToResults);
    if (!appliesTo_) {
      NSString *error = [HGSPython lastErrorString];
      HGSLogDebug(@"could not create Python string %s.\n%@", 
                  kHGSPythonAppliesToResults, error);
      [self release];
      return nil;
    }
  }

  return self;
}

- (void)dealloc {
  if (perform_ || appliesTo_ || instance_ || module_) {
    PythonStackLock gilLock;
    if (perform_) {
      Py_DECREF(perform_);
    }
    if (appliesTo_) {
      Py_DECREF(appliesTo_);
    }
    if (instance_) {
      Py_DECREF(instance_);
    }
    if (module_) {
      Py_DECREF(module_);
    }
  }
  [super dealloc];
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  BOOL result = NO;
  
  HGSResultArray *directs 
    = [info objectForKey:kHGSActionDirectObjectsKey];

  if (instance_ && directs) {
    PythonStackLock gilLock;
    HGSPython *sharedPython = [HGSPython sharedPython];
    PyObject *pyDirects = [sharedPython tupleForResults:directs];
    
    if (pyDirects) {
      
      PyObject *pyIndirects = NULL;
      NSMutableDictionary *indirects 
        = [NSMutableDictionary dictionaryWithDictionary:info];
      [indirects removeObjectForKey:kHGSActionDirectObjectsKey];
      if ([indirects count]) {
        pyIndirects = PyDict_New();
        if (pyIndirects) {
          for (NSString *key in indirects) {
            HGSResultArray *indirectValues = [indirects objectForKey:key];
            PyObject *pyIndirectValues 
              = [sharedPython tupleForResults:indirectValues];
            PyDict_SetItemString(pyIndirects, 
                                 [key UTF8String], pyIndirectValues);
            Py_DECREF(pyIndirectValues);
          }
        }
      }
      PyObject *pythonResult = PyObject_CallMethodObjArgs(instance_,
                                                          perform_,
                                                          pyDirects,
                                                          pyIndirects,
                                                          NULL);
      if (pyIndirects) {
        Py_DECREF(pyIndirects);
      }
      
      if (pythonResult) {
        result = (pythonResult == Py_True);
        Py_DECREF(pythonResult);
      }
      Py_DECREF(pyDirects);
    }
  }
  return result;
}

- (HGSResultArray *)performReturningResultsWithInfo:(NSDictionary *)info {
  HGSResultArray* results = nil;
  
  HGSResultArray *directs 
    = [info objectForKey:kHGSActionDirectObjectsKey];

  if (instance_ && directs) {
    PythonStackLock gilLock;
    HGSPython *sharedPython = [HGSPython sharedPython];
    PyObject *pyDirects = [sharedPython tupleForResults:directs];
    
    if (pyDirects) {
      
      PyObject *pyIndirects = NULL;
      NSMutableDictionary *indirects 
        = [NSMutableDictionary dictionaryWithDictionary:info];
      [indirects removeObjectForKey:kHGSActionDirectObjectsKey];
      if ([indirects count]) {
        pyIndirects = PyDict_New();
        if (pyIndirects) {
          for (NSString *key in indirects) {
            HGSResultArray *indirectValues = [indirects objectForKey:key];
            PyObject *pyIndirectValues 
              = [sharedPython tupleForResults:indirectValues];
            PyDict_SetItemString(pyIndirects, 
                                 [key UTF8String], pyIndirectValues);
            Py_DECREF(pyIndirectValues);
          }
        }
      }
      PyObject *pythonResult = PyObject_CallMethodObjArgs(instance_,
                                                          perform_,
                                                          pyDirects,
                                                          pyIndirects,
                                                          NULL);
      if (pyIndirects) {
        Py_DECREF(pyIndirects);
      }
      
      if (pythonResult) {
        if (PyDict_Check(pythonResult)) {
          NSArray *array = [sharedPython resultsFromObjects:pythonResult
                                             tokenizedQuery:nil 
                                                     source:nil];
          results = [HGSResultArray arrayWithResults:array];
        }
        Py_DECREF(pythonResult);
      }
      Py_DECREF(pyDirects);
    }
  }
  
  return results;
}

- (BOOL)appliesToResults:(HGSResultArray *)results {
  BOOL doesApply = [super appliesToResults:results];
  if (doesApply) {
    PythonStackLock gilLock;
    doesApply = NO;
    PyObject *pyResult = [[HGSPython sharedPython] tupleForResults:results];
    if (pyResult) {
      PyObject *pyApplies = PyObject_CallMethodObjArgs(instance_,
                                                       appliesTo_,
                                                       pyResult,
                                                       NULL);
      if (pyApplies) {
        if (PyBool_Check(pyApplies) && pyApplies == Py_True) {
          doesApply = YES;
        }
        Py_DECREF(pyApplies);
      }
      Py_DECREF(pyResult);
    }
  }
  return doesApply;
}

@end
