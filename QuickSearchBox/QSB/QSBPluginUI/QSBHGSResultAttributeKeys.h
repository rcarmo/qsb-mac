//
//  QSBHGSResultAttributeKeys.h
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

// QSB specific values that can be gotten from HGSResults using valueForKey:

// Path cell-related keys

// The path presentation shown in the search results window can be
// built from one of the following (in order of preference):
//   1. an array of cell descriptions
//   2. a file path URL (from our |identifier|).
//   3. a slash-delimeted string of cell titles
// Only the first option guarantees that a cell is clickable, the
// second option may but is not likely to support clicking, and the
// third definitely not.  We will return a decent cell array for regular URLs 
// and file URLs and a mediocre one for public.message results but you can 
// compose and provide your own in your source's provideValueForKey: method.

//   selector as string
#define kQSBObjectAttributePathCellClickHandlerKey \
  @"QSBObjectAttributePathCellClickHandler"
//   NSArray of NSDictionaries
#define kQSBObjectAttributePathCellsKey \
  @"QSBObjectAttributePathCells"
//   NSString
#define kQSBPathCellDisplayTitleKey @"QSBPathCellDisplayTitle"
//   NSImage
#define kQSBPathCellImageKey @"QSBPathCellImage"
//   NSURL
#define kQSBPathCellURLKey @"QSBPathCellURL"

// QSB Table result for a given HGSScoredResult
#define kQSBObjectTableResultAttributeKey @"QSBObjectTableResultAttributeKey"

