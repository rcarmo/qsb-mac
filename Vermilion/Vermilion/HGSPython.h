//
//  HGSPython.h
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

// We need to use Python 2.5 that is available on Leopard and Snow Leopard.
// 2.6 is the default on SL, so we need to work around that.
#import <Python.framework/Versions/2.5/Headers/Python.h>

#ifdef __cplusplus

// Class to lock and automatically unlock the
// Python GIL, which is necessary for multithreaded
// applications
class PythonStackLock {
private:
  PyGILState_STATE state_;
  PythonStackLock(const PythonStackLock&);
public:
  explicit PythonStackLock() : state_(PyGILState_Ensure()) { }
  ~PythonStackLock() {
    PyGILState_Release(state_);
  }
};

#endif // __cplusplus

@class HGSQuery;
@class HGSSearchOperation;
@class HGSResult;
@class HGSResultArray;
@class HGSExtension;
@class HGSSearchSource;
@class HGSTokenizedString;

@interface HGSPythonObject : NSObject {
 @private
  PyObject *object_;
}
+ (HGSPythonObject *)pythonObjectWithObject:(PyObject *)object;
- (id)initWithObject:(PyObject *)object;
- (PyObject *)object;
@end

@interface HGSPython : NSObject {
 @private
  PyObject *vermilionModule_;
}
+ (HGSPython *)sharedPython;
+ (NSString *)stringAttribute:(NSString *)attr fromObject:(PyObject *)obj;
+ (NSString *)lastErrorString;
- (PyObject *)objectForResult:(HGSResult *)result;
- (PyObject *)tupleForResults:(HGSResultArray *)results;
- (PyObject *)objectForQuery:(HGSQuery *)query
         withSearchOperation:(HGSSearchOperation *)operation;
- (PyObject *)loadModule:(NSString *)moduleName;
- (void)appendPythonPath:(NSString *)path;
- (PyObject *)objectForExtension:(HGSExtension *)extension;
- (NSArray *)resultsFromObjects:(PyObject *)pythonResults
                 tokenizedQuery:(HGSTokenizedString *)tokenizedQuery
                         source:(HGSSearchSource *)source;
@end

extern const NSString *kHGSPythonPrivateValuesKey;
extern const NSString *kHGSPythonThreadExtensionKey;

// The two keys for things we pull from the config dictionary
extern NSString *const kPythonModuleNameKey;
extern NSString *const kPythonClassNameKey;
