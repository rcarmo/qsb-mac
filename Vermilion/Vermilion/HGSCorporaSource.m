//
//  HGSCorporaSource.m
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

#import "HGSCorporaSource.h"

#import "HGSAccount.h"
#import "HGSAccountsExtensionPoint.h"
#import "HGSCoreExtensionPoints.h"
#import "HGSGoogleAccountTypes.h"
#import "HGSLog.h"
#import "HGSResult.h"
#import "HGSType.h"

NSString *const kHGSCorporaDefinitionsKey
  = @"HGSCorporaDefinitions";  // NSArray of NSDictionaries
NSString *const kHGSCorporaSourceAttributeHideFromiPhoneKey
  = @"HGSCorporaSourceAttributeHideFromiPhone";  // BOOL
NSString *const kHGSCorporaSourceAttributeHideFromDesktopKey
  = @"HGSCorporaSourceAttributeHideFromDesktop";  // BOOL
NSString *const kHGSCorporaSourceAttributeHideFromDropdownKey
  = @"HGSCorporaSourceAttributeHideFromDropdown";  // BOOL

@interface HGSCorporaSource ()
- (BOOL)loadCorpora:(NSArray *)corpora;
- (void)didAddOrRemoveAccount:(NSNotification *)notification;
@end

@implementation HGSCorporaSource

@synthesize searchableCorpora = searchableCorpora_;

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    corpora_ = [[configuration objectForKey:kHGSCorporaDefinitionsKey] retain];
    if (![self loadCorpora:corpora_]) {
      HGSLogDebug(@"Unable to load corpora");
      [self release];
      self = nil;
    }
    HGSExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(didAddOrRemoveAccount:)
               name:kHGSExtensionPointDidAddExtensionNotification
             object:accountsPoint];
    [nc addObserver:self
           selector:@selector(didAddOrRemoveAccount:)
               name:kHGSExtensionPointDidRemoveExtensionNotification
             object:accountsPoint];
  }
  return self;
}

- (void)dealloc {
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [searchableCorpora_ release];
  [validCorpora_ release];
  [corpora_ release];
  [super dealloc];
}

- (NSString *)uriForCorpus:(NSDictionary *)corpusDict
                   account:(HGSAccount *)account {
  return [corpusDict objectForKey:kHGSObjectAttributeURIKey];
}

- (NSString *)webSearchTemplateForCorpus:(NSDictionary *)corpusDict
                                 account:(HGSAccount *)account {
  return [corpusDict objectForKey:kHGSObjectAttributeWebSearchTemplateKey];
}

- (NSString *)displayNameForCorpus:(NSDictionary *)corpusDict
                           account:(HGSAccount *)account {
  NSBundle *bundle = [self bundle];
  NSString *name = [corpusDict objectForKey:kHGSObjectAttributeNameKey];
  return [bundle qsb_localizedInfoPListStringForKey:name];
}

- (HGSResult *)resultForCorpus:(NSDictionary *)corpusDict
                       account:(HGSAccount *)account {
#if TARGET_OS_IPHONE
  if ([corpusDict objectForKey:kHGSCorporaSourceAttributeHideFromiPhoneKey]) {
    return nil;
  }
#else
  if ([corpusDict objectForKey:kHGSCorporaSourceAttributeHideFromDesktopKey]) {
    return nil;
  }
#endif  // TARGET_OS_IPHONE

  NSString *identifier = [self uriForCorpus:corpusDict account:account];
  NSString *name = [self displayNameForCorpus:corpusDict account:account];

  NSMutableDictionary *objectDict
    = [NSMutableDictionary dictionaryWithDictionary:corpusDict];
  [objectDict setObject:identifier forKey:kHGSObjectAttributeURIKey];
  [objectDict setObject:identifier forKey:kHGSObjectAttributeSourceURLKey];
  [objectDict setObject:name forKey:kHGSObjectAttributeNameKey];

  NSString *webTemplate = [self webSearchTemplateForCorpus:corpusDict
                                                   account:account];
  if (webTemplate) {
    [objectDict setObject:webTemplate
                   forKey:kHGSObjectAttributeWebSearchTemplateKey];
  }

  NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSLaunchableRankFlag];
  [objectDict setObject:rankFlags forKey:kHGSObjectAttributeRankFlagsKey];

  [objectDict setObject:kHGSTypeWebApplication
                 forKey:kHGSObjectAttributeTypeKey];

  NSString *iconName
    = [objectDict objectForKey:kHGSObjectAttributeIconPreviewFileKey];
  if (iconName) {
#if TARGET_OS_IPHONE
    // For mobile, we must append .png
    iconName = [iconName stringByAppendingPathExtension:@"png"];
#endif
    NSImage *icon = [self imageNamed:iconName];
    if (icon) {
      icon = [[icon copy] autorelease];
      [objectDict setObject:icon forKey:kHGSObjectAttributeIconKey];
    } else {
      HGSLog(@"Unable to load an icon for corpus %@", corpusDict);
    }
    [objectDict removeObjectForKey:kHGSObjectAttributeIconPreviewFileKey];
  }
  HGSUnscoredResult *corpus = [HGSUnscoredResult resultWithDictionary:objectDict
                                                               source:self];
  return corpus;
}


- (BOOL)loadCorpora:(NSArray *)corpora {

  // Initialization code
  NSMutableArray *allCorpora = [NSMutableArray array];
  HGSAccountsExtensionPoint *accountsPoint = [HGSExtensionPoint accountsPoint];

  for (NSDictionary *corpusDict in corpora) {
    NSString *accountType
      = [corpusDict objectForKey:kHGSAccountTypeKey];
    if (accountType) {
      NSArray *accounts
        = [accountsPoint accountsForType:accountType];
      for (HGSAccount *account in accounts) {
        HGSResult *corpus = [self resultForCorpus:corpusDict account:account];
        if (corpus) [allCorpora addObject:corpus];
      }
    } else {
      HGSResult *corpus = [self resultForCorpus:corpusDict account:nil];
      if (corpus) [allCorpora addObject:corpus];
    }
  }

  NSMutableArray *searchableCorpora = [NSMutableArray array];

  for (HGSResult *corpus in allCorpora) {
    if ([corpus valueForKey:kHGSObjectAttributeWebSearchTemplateKey]
    && ![[corpus valueForKey:kHGSCorporaSourceAttributeHideFromDropdownKey] boolValue]) {
      [searchableCorpora addObject:corpus];
    }
  }

  [validCorpora_ autorelease];
  [searchableCorpora_ autorelease];

  validCorpora_ = [allCorpora retain];
  searchableCorpora_ = [searchableCorpora retain];

  HGSMemorySearchSourceDB *db = [HGSMemorySearchSourceDB database];

  for (HGSResult *corpus in allCorpora) {
    [db indexResult:corpus];
  }

  [self replaceCurrentDatabaseWith:db];

  return YES;
}

- (NSMutableDictionary *)archiveRepresentationForResult:(HGSResult *)result {
  return [NSMutableDictionary
            dictionaryWithObject:[result uri]
                          forKey:kHGSObjectAttributeURIKey];
}

- (HGSResult *)resultWithArchivedRepresentation:(NSDictionary *)representation {
  HGSResult *result = nil;
  NSString *identifier = [representation objectForKey:kHGSObjectAttributeURIKey];
  for (HGSResult *corpus in validCorpora_) {
    NSString *uri = [corpus uri];
    if ([uri isEqual:identifier]) {
      result = corpus;
      break;
    }
  }
  return result;
}

- (void)didAddOrRemoveAccount:(NSNotification *)notification {
 [self loadCorpora:corpora_];
}

@end
