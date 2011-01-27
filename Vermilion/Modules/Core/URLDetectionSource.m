//
//  URLDetectionSource.m
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

// This source detects queries like "apple.com" and "http://merak" and turns 
// them into url results.
//
// WARNING: This source along w/ the suggest/navsuggest make for an interesting
// mix.  This source can decide not to accept something that source suggests, so
// if you are trying to debug something you don't want as a url result, it might
// not be this source.

// List of top level domains taken from IANA
// http://data.iana.org/TLD/tlds-alpha-by-domain.txt
// # Version 2010032300, Last Updated Tue Mar 23 14:07:01 2010 UTC

static const char kUDSIANATLDs[][8] = {
  "AC", "AD", "AE", "AERO", "AF", "AG", "AI", "AL", "AM", "AN", "AO",
  "AQ", "AR", "ARPA", "AS", "ASIA", "AT", "AU", "AW", "AX", "AZ", "BA",
  "BB", "BD", "BE", "BF", "BG", "BH", "BI", "BIZ", "BJ", "BM", "BN", "BO",
  "BR", "BS", "BT", "BV", "BW", "BY", "BZ", "CA", "CAT", "CC", "CD", "CF",
  "CG", "CH", "CI", "CK", "CL", "CM", "CN", "CO", "COM", "COOP", "CR",
  "CU", "CV", "CX", "CY", "CZ", "DE", "DJ", "DK", "DM", "DO", "DZ", "EC",
  "EDU", "EE", "EG", "ER", "ES", "ET", "EU", "FI", "FJ", "FK", "FM", "FO",
  "FR", "GA", "GB", "GD", "GE", "GF", "GG", "GH", "GI", "GL", "GM", "GN",
  "GOV", "GP", "GQ", "GR", "GS", "GT", "GU", "GW", "GY", "HK", "HM", "HN",
  "HR", "HT", "HU", "ID", "IE", "IL", "IM", "IN", "INFO", "INT", "IO",
  "IQ", "IR", "IS", "IT", "JE", "JM", "JO", "JOBS", "JP", "KE", "KG",
  "KH", "KI", "KM", "KN", "KP", "KR", "KW", "KY", "KZ", "LA", "LB", "LC",
  "LI", "LK", "LR", "LS", "LT", "LU", "LV", "LY", "MA", "MC", "MD", "ME",
  "MG", "MH", "MIL", "MK", "ML", "MM", "MN", "MO", "MOBI", "MP", "MQ",
  "MR", "MS", "MT", "MU", "MUSEUM", "MV", "MW", "MX", "MY", "MZ", "NA",
  "NAME", "NC", "NE", "NET", "NF", "NG", "NI", "NL", "NO", "NP", "NR",
  "NU", "NZ", "OM", "ORG", "PA", "PE", "PF", "PG", "PH", "PK", "PL", "PM",
  "PN", "PR", "PRO", "PS", "PT", "PW", "PY", "QA", "RE", "RO", "RS", "RU",
  "RW", "SA", "SB", "SC", "SD", "SE", "SG", "SH", "SI", "SJ", "SK", "SL",
  "SM", "SN", "SO", "SR", "ST", "SU", "SV", "SY", "SZ", "TC", "TD", "TEL",
  "TF", "TG", "TH", "TJ", "TK", "TL", "TM", "TN", "TO", "TP", "TR",
  "TRAVEL", "TT", "TV", "TW", "TZ", "UA", "UG", "UK", "US", "UY", "UZ",
  "VA", "VC", "VE", "VG", "VI", "VN", "VU", "WF", "WS", "YE", "YT", "YU",
  "ZA", "ZM", "ZW"
};

@interface URLDetectionSource : HGSCallbackSearchSource
@end

@implementation URLDetectionSource

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  // We use the raw query to see if it's url like
  BOOL isValid = [super isValidSourceForQuery:query];
  if (isValid) {
    HGSTokenizedString *tokenizedQueryString = [query tokenizedQueryString];
    NSString *urlString = [tokenizedQueryString originalString];
    if ([urlString rangeOfString:@" "].location != NSNotFound) {
      isValid = NO;
    } else {
      // Does it appear to have a scheme?
      if ([urlString rangeOfString:@":"].location != NSNotFound) {
        // nothing to do, already set to yes
        // isValid = YES;
      } else {
        // If it doesn't have a '.' or '/', give up.  (covers "internalsite/bar"
        // and "google.com")
        if ([urlString rangeOfString:@"."].location == NSNotFound
            && [urlString rangeOfString:@"/"].location == NSNotFound) {
          isValid = NO;
        }
      }
    }
  }
  return isValid;
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSQuery *query = [operation query];
  HGSTokenizedString *tokenizedQueryString = [query tokenizedQueryString];
  NSString *urlString = [tokenizedQueryString originalString];
  NSURL *url = [NSURL URLWithString:urlString];
  CGFloat score = 0;
  
  if ([url scheme]) {
    // NSURL seem happy, nothing more to do at this point, we'll use it.
    score = HGSCalibratedScore(kHGSCalibratedStrongScore);
  } else {
    // Try to see if it's "internalsite/bar" or "google.com" style
    NSArray *pathComponents = [urlString componentsSeparatedByString:@"/"];
    NSString *host = [pathComponents objectAtIndex:0];
    NSArray *hostComponents = [host componentsSeparatedByString:@"."];
    
    // IP Address
    if ([hostComponents count] == 4) {
      BOOL isNumber = YES;
      NSCharacterSet *decimalDigits = [NSCharacterSet decimalDigitCharacterSet];
      NSCharacterSet *nonDigits = [decimalDigits invertedSet];
      for (NSString *component in hostComponents) {
        if ([component rangeOfCharacterFromSet:nonDigits].length != 0) {
          isNumber = NO;
          break;
        }
      }
      if (isNumber) {
        score = HGSCalibratedScore(kHGSCalibratedStrongScore);
      }
    }
    
    // internalsite/[something]
    if ((!(score > 0)) && [host length] && [hostComponents count] == 1
        && [pathComponents count] > 1) {
      score = HGSCalibratedScore(kHGSCalibratedWeakScore);
    }
    // blah.com
    if ((!(score > 0)) && [hostComponents count] > 1) {
      NSString *lastComponent = [hostComponents lastObject];
      const char *cLastComponent = [[lastComponent uppercaseString] UTF8String];
      size_t lastLength = strlen(cLastComponent);
      for (size_t i = 0; 
           i < sizeof(kUDSIANATLDs) / sizeof(kUDSIANATLDs[0]); 
           ++i) {
        if (strncasecmp(cLastComponent, kUDSIANATLDs[i], lastLength) == 0) {
          score = HGSCalibratedScore(kHGSCalibratedStrongScore);
          size_t ianaLength = strlen(kUDSIANATLDs[i]);
          score *= (((float)lastLength) / ((float)ianaLength));
        }
      }
    }
    
    if (score > 0) {
      urlString = [@"http://" stringByAppendingString:urlString];
      url = [NSURL URLWithString:urlString];
    }
  }

  if (score > 0) {
    NSDictionary *attributes
      = [NSDictionary dictionaryWithObjectsAndKeys:
         [NSImage imageNamed:@"blue-nav"], kHGSObjectAttributeIconKey,
         [NSNumber numberWithBool:YES], kHGSObjectAttributeAllowSiteSearchKey,
         urlString, kHGSObjectAttributeSourceURLKey,
         [NSNumber numberWithBool:YES], kHGSObjectAttributeIsSyntheticKey,
         nil];
         
    HGSScoredResult *scoredResult 
      = [HGSScoredResult resultWithURI:[url absoluteString]
                                  name:urlString
                                  type:kHGSTypeWebpage
                                source:self
                            attributes:attributes
                                 score:score
                                 flags:0
                           matchedTerm:tokenizedQueryString 
                        matchedIndexes:nil];
    [operation setRankedResults:[NSArray arrayWithObject:scoredResult]];
  }
}

@end

