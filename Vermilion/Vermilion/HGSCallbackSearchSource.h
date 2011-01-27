//
//  HGSCallbackSearchSource.h
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

/*!
 @header
 @discussion HGSCallbackSearchSource
*/

#import <Vermilion/HGSSearchSource.h>
#import <Vermilion/HGSSimpleArraySearchOperation.h>

@class HGSSearchOperation;
/*!
 Subclass of HGSSearchSource that uses a search operation to call back
 into the SearchSource to do the actual search work.
*/
@interface HGSCallbackSearchSource : HGSSearchSource
@end

/*!
 Subclass of HGSSearchOperation that calls back into the SearchSource to do 
 the actual search work.
*/
@interface HGSCallbackSearchOperation : HGSSimpleArraySearchOperation 
- (id)initWithQuery:(HGSQuery *)query 
             source:(HGSCallbackSearchSource *)callbackSource;
@end

/*!
 These are methods subclasses can override to do the actual search.
*/
@interface HGSCallbackSearchSource (ProtectedMethods)

/*!
 Do the actual search, this must be overridden.  An implementor needs to call
 setResults: on the search operation if it has any results.  If the source
 returns YES for isSearchConcurrent, then it must also call finishQuery on the
 operation when it has completed.  See -[HGSSearchOperation main] for the full
 details on how this works.
*/
- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation;

/*!
 See -[HGSSearchOperation isConcurrent] for details.  The default is NO,
 meaning a thread will be created for each search operation.
*/
- (BOOL)isSearchConcurrent;

@end
