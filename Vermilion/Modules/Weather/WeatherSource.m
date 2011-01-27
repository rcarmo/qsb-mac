//
//  WeatherSource.m
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
#import "GTMNSString+URLArguments.h"
#import "GTMGoogleSearch.h"

// TODO: should either of these get a hl= based on our running UI?
static NSString *const kWeatherDataURL
  = @"http://www.google.com/ig/api?weather=%@&output=xml";
static NSString *const kWeatherResultURL
  = @"http://www.google.com/search?q=weather%%20%@";

@interface WeatherSource : HGSCallbackSearchSource {
 @private
  NSCharacterSet *nonDigitSet_;
  NSPredicate *canadianPostalCodePredicate_;
  NSPredicate *britishPostalCodePredicate_;
}
@end

@implementation WeatherSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    nonDigitSet_
      = [[[NSCharacterSet decimalDigitCharacterSet] invertedSet] retain];
    NSString *canadianPostalCodeRE 
      = @"^[:letter:][0-9][:letter:]\\s?[0-9][:letter:][0-9]$";
    canadianPostalCodePredicate_ 
      = [[NSPredicate predicateWithFormat:@"SELF MATCHES %@", 
          canadianPostalCodeRE] retain];
    // TODO(dmaclach): Add support for SAN[ ]{0,1}TA1 once 1691089 is fixed.
    NSString *britishPostalCodeRE
      = @"^([A-PR-UWYZ]([0-9]{1,2}|([A-HK-Y][0-9]|[A-HK-Y][0-9]([0-9]|"
        @"[ABEHMNPRV-Y]))|[0-9][A-HJKS-UW])[ ]{0,1}[0-9]"
        @"[ABD-HJLNP-UW-Z]{2})$";
    britishPostalCodePredicate_ 
      = [[NSPredicate predicateWithFormat:@"SELF MATCHES[c] %@", 
          britishPostalCodeRE] retain];
  }
  return self;
}

- (void)dealloc {
  [nonDigitSet_ release];
  [canadianPostalCodePredicate_ release];
  [britishPostalCodePredicate_ release];
  [super dealloc];
}

- (BOOL)isValidSourceForQuery:(HGSQuery *)query {
  BOOL isValid = [super isValidSourceForQuery:query];
  if (isValid) {
    // Must be "weather [something]"
    // or a US zip code or a British or Canadian Postal Code.
    NSString *rawQuery = [[query tokenizedQueryString] originalString];
    NSUInteger len = [rawQuery length];
    if (len == 5) {
      NSRange range = [rawQuery rangeOfCharacterFromSet:nonDigitSet_];
      isValid = (range.location == NSNotFound);
    } else if (len > 5 && len <= 8) {
      isValid = [canadianPostalCodePredicate_ evaluateWithObject:rawQuery];
      if (!isValid) {
        isValid = [britishPostalCodePredicate_ evaluateWithObject:rawQuery];
      }
    } else {
      NSString *localizedPrefix = HGSLocalizedString(@"weather ", 
                                                     @"A label denoting that "
                                                     @"the user is looking for "
                                                     @"weather information");  
      NSUInteger prefixLen = [localizedPrefix length];
      if (len > prefixLen) {
        isValid = [rawQuery compare:localizedPrefix
                            options:NSCaseInsensitiveSearch
                              range:NSMakeRange(0, prefixLen)] == NSOrderedSame;
      } else {
        isValid = NO;
      }
    }
  }
  return isValid;
}

- (void)performSearchOperation:(HGSCallbackSearchOperation *)operation {
  HGSTokenizedString *tokenizedQueryString = [[operation query] tokenizedQueryString];
  NSString *rawQuery = [tokenizedQueryString originalString];
  NSString *location;
  NSUInteger rawQueryLength = [rawQuery length];
  if (rawQueryLength >= 5 && rawQueryLength <= 8) {
    // It's a zip (US) or postal code (Canadian or British)
    location = rawQuery;
  } else {
    // Extract what's after our marker
    NSString *localizedPrefix = HGSLocalizedString(@"weather ", 
                                                   @"A label denoting that "
                                                   @"the user is looking for "
                                                   @"weather information");  
    location = [rawQuery substringFromIndex:[localizedPrefix length]];
  }
  NSString *escapedLocation = [location gtm_stringByEscapingForURLArgument];
  GTMGoogleSearch *gsearch = [GTMGoogleSearch sharedInstance];
  NSDictionary *arguments 
    = [NSDictionary dictionaryWithObjectsAndKeys:
       [NSNull null], @"q",
       escapedLocation, @"weather",
       @"xml", @"output",
       nil];
  NSString *urlStr = [gsearch searchURLFor:@"" 
                                    ofType:@"ig/api" 
                                 arguments:arguments];
  NSURL *url = [NSURL URLWithString:urlStr];
  if (url) {
    // TODO: make this an async using GDataHTTPFetcher (means this search op is
    // concurrent), instead of blocking here.
    NSXMLDocument *xmlDoc
      = [[[NSXMLDocument alloc] initWithContentsOfURL:url
                                              options:NSXMLDocumentTidyXML
                                                error:nil] autorelease];
    if (xmlDoc) {
      NSString *xPath 
        = @"/xml_api_reply/weather/forecast_information/city/@data";
      NSString *city
        = [[[xmlDoc nodesForXPath:xPath error:nil] lastObject] stringValue];
      
      NSLocale *locale = [NSLocale currentLocale];
      BOOL metric = [[locale objectForKey:NSLocaleUsesMetricSystem] boolValue];
      NSString *units = nil;
      if (metric) {
        xPath = @"/xml_api_reply/weather/current_conditions/temp_c/@data";
        units = HGSLocalizedString(@"C", @"Label for unit to denote Celsius");
      } else {
        xPath = @"/xml_api_reply/weather/current_conditions/temp_f/@data";
        units = HGSLocalizedString(@"F", @"Label for unit to denot Farenheit");
      }
      NSString *temp
        = [[[xmlDoc nodesForXPath:xPath error:nil] lastObject] stringValue];
      
      xPath = @"/xml_api_reply/weather/current_conditions/condition/@data";
      NSString *condition
        = [[[xmlDoc nodesForXPath:xPath error:nil] lastObject] stringValue];
      
      xPath = @"/xml_api_reply/weather/current_conditions/wind_condition/@data";
      NSString *wind
        = [[[xmlDoc nodesForXPath:xPath error:nil] lastObject] stringValue];
      
      if ([city length] && [temp length]&& [wind length]) {
        NSString *localizedString 
          = HGSLocalizedString(@"Weather for %@", 
                               @"A label in a result denoting that we are "
                               @"displaying the weather for the city %@");
        NSString *title
          = [NSString stringWithFormat:localizedString, city];
        NSString *details = nil;
        if ([condition length]) {
          localizedString = HGSLocalizedString(@"%1$@°%2$@ - %3$@ - %4$@",
                                               @"Weather condition details. "
                                               @"%1$@ is temperature "
                                               @"%2$@ is units "
                                               @"%3$@ is condition and "
                                               @"%4$@ is wind data.");
          details = [NSString stringWithFormat:localizedString, temp, units, 
                     condition, wind];
        } else {
          localizedString = HGSLocalizedString(@"%1$@°%2$@ - %3$@",
                                               @"Weather condition details. "
                                               @"%1$@ is temperature "
                                               @"%2$@ is units and"
                                               @"%3$@ is wind data.");
          details = [NSString stringWithFormat:localizedString, temp, units, 
                     wind];
        }          

        // build an open url
        NSString *searchStr = [NSString stringWithFormat:@"weather%%20%@", 
                               escapedLocation];
        NSString *resultURLStr = [gsearch searchURLFor:searchStr
                                                ofType:GTMGoogleSearchWeb
                                             arguments:nil];
        // Cheat, force this result high in the list.
        // TODO(dmaclach): figure out a cleaner way to get results like this 
        // high in the results.
        NSMutableDictionary *attributes
          = [NSMutableDictionary dictionaryWithObjectsAndKeys:
             details, kHGSObjectAttributeSnippetKey,
             nil];
        xPath = @"/xml_api_reply/weather/current_conditions/icon/@data";
        NSString *imageSRL
          = [[[xmlDoc nodesForXPath:xPath error:nil] lastObject] stringValue];
        if ([imageSRL length]) {
          NSURL *imgURL = [NSURL URLWithString:imageSRL relativeToURL:url];
          // TODO: do we really want to use initByReferencingURL or should we
          // just fetch the image some other way?
          NSImage *image 
            = [[[NSImage alloc] initByReferencingURL:imgURL] autorelease];
          if (image) {
            [attributes setObject:image forKey:kHGSObjectAttributeIconKey];
          }
        }
        HGSScoredResult *scoredResult
          = [HGSScoredResult resultWithURI:resultURLStr
                                      name:title
                                      type:HGS_SUBTYPE(kHGSTypeOnebox, @"weather")
                                    source:self
                                attributes:attributes
                                     score:HGSCalibratedScore(kHGSCalibratedPerfectScore) 
                                     flags:eHGSSpecialUIRankFlag
                               matchedTerm:tokenizedQueryString 
                            matchedIndexes:nil];
        NSArray *resultsArray = [NSArray arrayWithObject:scoredResult];
        [operation setRankedResults:resultsArray];
      }
    }
  }
  // query is concurrent, don't need to end it ourselves.
}

@end
