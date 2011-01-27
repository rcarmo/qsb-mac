//
//  GoogleCorporaSource.m
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

#import <Vermilion/Vermilion.h>

@interface GoogleCorporaSource : HGSCorporaSource
@end
  
@implementation GoogleCorporaSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  self = [super initWithConfiguration:configuration];
  return self;
}

- (NSString *)dasherAccountDomain:(HGSAccount *)account {
  NSString *name = [account userName];
  NSString *domain = nil;
  NSInteger location = [name rangeOfString:@"@"].location;
  if (location != NSNotFound) {
    domain = [name substringFromIndex:location + 1]; 
  }
  return domain;
}

- (NSString *)uriForCorpus:(NSDictionary *)corpusDict 
                   account:(HGSAccount *)account {
  NSString *domain = [self dasherAccountDomain:account];
  NSString *uri = [super uriForCorpus:corpusDict account:account];
  return [NSString stringWithFormat:uri, domain];
}

- (NSString *)webSearchTemplateForCorpus:(NSDictionary *)corpusDict 
                                 account:(HGSAccount *)account {
  NSString *domain = [self dasherAccountDomain:account];
  NSString *template = [super webSearchTemplateForCorpus:corpusDict
                                                 account:account];
  if (template) {
    template = [NSString stringWithFormat:template, domain];
  }
  return template;
}

- (NSString *)displayNameForCorpus:(NSDictionary *)corpusDict 
                           account:(HGSAccount *)account {
  NSString *domain = [self dasherAccountDomain:account];
  NSString *name = [super displayNameForCorpus:corpusDict
                                       account:account];
  return [NSString stringWithFormat:name, domain];
}

@end
