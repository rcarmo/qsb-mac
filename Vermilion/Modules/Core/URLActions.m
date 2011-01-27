//
//  URLActions.m
//
//  Copyright (c) 2010 Google Inc. All rights reserved.
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
#import <JSON/JSON.h>
#import <GTM/GTMNSString+URLArguments.h>
#import <GTM/GTMMethodCheck.h>

// Shorten URL using goo.gl URL shortener.
// Using 3rd party shortening API
// Instructions here:
// http://ggl-shortener.appspot.com/instructions/
@interface GoogleShortenURLAction : HGSAction
@end

@implementation GoogleShortenURLAction

GTM_METHOD_CHECK(NSString, gtm_stringByEscapingForURLArgument);
GTM_METHOD_CHECK(NSString, JSONValue);

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  BOOL success = NO;
  if (directObjects) {
    if ([directObjects count] == 1) {
      HGSResult *result = [directObjects objectAtIndex:0];
      NSString *urlString = [[result url] absoluteString];
      urlString = [urlString gtm_stringByEscapingForURLArgument];
      NSString *shortenerURLString
        = [NSString stringWithFormat:@"http://ggl-shortener.appspot.com/?url=%@",
           urlString];
      NSURL *shortenerURL = [NSURL URLWithString:shortenerURLString];
      NSURLRequest *request = [NSURLRequest requestWithURL:shortenerURL];
      NSURLResponse *response = nil;
      NSError *error = nil;
      NSData *responseData = [NSURLConnection sendSynchronousRequest:request 
                                                   returningResponse:&response 
                                                               error:&error];
      if (!error) {
        NSString *responseString 
          = [[[NSString alloc] initWithData:responseData 
                                   encoding:NSUTF8StringEncoding] autorelease];
        NSDictionary *dict = [responseString JSONValue];
        if (dict) {
          NSString *value = [dict objectForKey:@"short_url"];
          if (value) {
            NSPasteboard *pb = [NSPasteboard generalPasteboard];
            [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] 
                       owner:self];
            [pb setString:value forType:NSStringPboardType];
            success = YES;
          }
        }
      } else {
        [NSApp presentError:error];
      }
    }
  }
  return success;
}

@end
