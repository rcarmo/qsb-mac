//
//  HGSCorporaSource.h
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
 @discussion HGSCorporaSource
*/

#import <Vermilion/HGSMemorySearchSource.h>

@class HGSAccount;

/*!
 @class HGSCorporaSource
 @discussion
 The base class for corpora sources. A corpora source is another site that we
 can search, such as imdb.com, amazon.com, google.com etc.
*/
@interface HGSCorporaSource : HGSMemorySearchSource {
 @private
  NSArray *corpora_;
  NSArray *validCorpora_;
  NSMutableArray *searchableCorpora_;
}

/*!
 Return an array of corpora that could be displayed in the UI like via the
 dropdown in QSB.
*/
@property (readonly, nonatomic, retain) NSArray *searchableCorpora;

/*! 
 Return a URI for the corpus described by corpusDict and account. 
 @param corpusDict The dictionary describing the corpus.
 @param account The account that is going to be accessing the 
                corpus. This can be nil.
 @result The URI for the corpus.
*/
- (NSString *)uriForCorpus:(NSDictionary *)corpusDict 
                   account:(HGSAccount *)account;

/*! 
 Return a web search template for the corpus described by corpusDict and 
 account. 
 @param corpusDict The dictionary describing the corpus.
 @param account The account that is going to be accessing the 
                corpus. This can be nil.
 @result The web search template for the corpus that contains "{searchterms}"
         which is a placemarker that will be replaced with the actual 
         search terms.
*/
- (NSString *)webSearchTemplateForCorpus:(NSDictionary *)corpusDict 
                                 account:(HGSAccount *)account;

/*! 
 Return a web search template for the corpus described by corpusDict and 
 account. 
 @param corpusDict The dictionary describing the corpus.
 @param account The account that is going to be accessing the 
                corpus. This can be nil.
 @result The display name for the corpus.
 */
- (NSString *)displayNameForCorpus:(NSDictionary *)corpusDict 
                           account:(HGSAccount *)account;

/*! 
 Return a HGSResult representing a corpus described by corpusDict and 
 account. This calls uriForCorpus:account:, webSearchTemplateForCorpus:account:
 and displayNameForCorpus:account:, so only override this if you can't get
 what you want using the above methods.
 @param corpusDict The dictionary describing the corpus.
 @param account The account that is going to be accessing the 
                corpus. This can be nil.
 @result A result representing the corpus.
*/
- (HGSResult *)resultForCorpus:(NSDictionary *)corpusDict 
                       account:(HGSAccount *)account;
@end

/*!
 Key for an array of corpus definitions, each one of which is a dictionary.
 Most keys are standard HGSResult keys. Corpus specific keys are described
 below.
*/
extern NSString *const kHGSCorporaDefinitionsKey;

/*! 
 @const
 Hide this corpus on iPhone. BOOL value. Default NO. 
*/
extern NSString *const kHGSCorporaSourceAttributeHideFromiPhoneKey;

/*! 
 @const
Hide this corpus on Desktop. BOOL value. Default NO. 
*/
extern NSString *const kHGSCorporaSourceAttributeHideFromDesktopKey;

/*! 
 @const
 Don't put this corpus in the drop down menu. BOL value. Default NO. 
*/
extern NSString *const kHGSCorporaSourceAttributeHideFromDropdownKey;
