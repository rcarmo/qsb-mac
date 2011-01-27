//
//  HGSBundle.h
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

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// If you get an error for HGSGetPluginBundle not being defined, 
// you need to link in HGSBundle.m. We keep it hidden so that we can have it
// living in several separate images without conflict.
// Functions with the ((constructor)) attribute are called after all +loads
// have been called. See "Initializing Objective-C Classes" in 
// http://developer.apple.com/documentation/DeveloperTools/Conceptual/DynamicLibraries/Articles/DynamicLibraryDesignGuidelines.html#//apple_ref/doc/uid/TP40002013-DontLinkElementID_20

// Returns the bundle for the image that this function is defined in.
// Therefore EACH plugin that wants to do localization needs to include
// HGSBundle.m in it's image. HGSGetPluginBundle is threadsafe ONCE
// HGSInitPluginBundle has been called.
__attribute__ ((visibility("hidden"))) NSBundle* HGSGetPluginBundle();

// Normally HGSInitPluginBundle will be called for each image, however there
// is the small caveat that +load (and any routine called directly or indirectly
// from +load such as +initialize and leaf routines) will be called before
// HGSInitPluginBundle is called. This means if you need access to the plugin
// bundle you must call HGSInitPluginBundle yourself. It is safe to call it
// multiple times, but is not thread safe. Do not call init from a thread.
__attribute__ ((constructor, visibility("hidden"))) void HGSInitPluginBundle();

// Localized macros that work similar to NSLocalizedString, except they
// grab strings from the same bundle as this function is defined in.
// Note that you can still use genstrings with the -s HGSLocalizedString option.
#define HGSLocalizedString(key, comment) \
  [HGSGetPluginBundle() localizedStringForKey:(key) value:@"" table:nil]
#define HGSLocalizedStringFromTable(key, tbl, comment) \
  [HGSGetPluginBundle() localizedStringForKey:(key) value:@"" table:(tbl)]

#ifdef __cplusplus
}
#endif
