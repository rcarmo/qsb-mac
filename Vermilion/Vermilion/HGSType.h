//
//  HGSType.h
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
 @discussion HGSType
*/

/*!
 The "type" system used for results is based on string hierarchies (similar to
 reverse dns names).  The common bases are "contact", "file", "webpage", etc.
 A source can then refine them to be more specific: "contact.addressbook",
 "contact.google", "webpage.bookmark".  These strings are meant to be case
 sensitive (to allow for faster compares).  There are helper functions below
 that allow the caller to check to see if a result is of a certain type or 
 refinement of that type.  The HGS_SUBTYPE macro is to be used in the 
 construction of string hierarchies with more than one segment.
 Types can be made up of multiple segments to refine them as specifically as
 needed.
*/
#define HGS_SUBTYPE(x,y) x @"." y

/*!
 The "all types" meta type. Everything conforms to this.
*/
#define kHGSTypeAllTypes @"*"

/*!
 Here are the current bases/common types. This DOES NOT mean that this is all 
 the possible valid base types.  New sources are free to add new types.
*/
#define kHGSTypeContact @"contact"
#define kHGSTypeFile    @"file"
#define kHGSTypeEmail   @"email"
#define kHGSTypeWebpage @"webpage"
#define kHGSTypeOnebox  @"onebox"
#define kHGSTypeAction  @"action"
#define kHGSTypeText    @"text"
#define kHGSTypeScript  @"script"
#define kHGSTypeDateTime @"datetime"
#define kHGSTypeGeolocation @"geolocation"
#define kHGSTypeSearch           HGS_SUBTYPE(kHGSTypeText, @"search")
#define kHGSTypeSuggest          HGS_SUBTYPE(kHGSTypeText, @"suggestion")
#define kHGSTypeDirectory        HGS_SUBTYPE(kHGSTypeFile, @"directory")
#define kHGSTypeTextFile         HGS_SUBTYPE(kHGSTypeFile, @"text")
#define kHGSTypeFileApplication  HGS_SUBTYPE(kHGSTypeFile, @"application")
#define kHGSTypeWebBookmark      HGS_SUBTYPE(kHGSTypeWebpage, @"bookmark")
#define kHGSTypeWebHistory       HGS_SUBTYPE(kHGSTypeWebpage, @"history")
#define kHGSTypeWebApplication   HGS_SUBTYPE(kHGSTypeWebpage, @"application")
#define kHGSTypeGoogleSuggest    HGS_SUBTYPE(kHGSTypeSuggest, @"googlesuggest")
#define kHGSTypeGoogleNavSuggest HGS_SUBTYPE(kHGSTypeWebpage, @"googlenavsuggest")
#define kHGSTypeGoogleSearch     HGS_SUBTYPE(kHGSTypeSearch,  @"googlesearch")
// Media splits into file. and webpage. because most actions will need to know
// how to act on them based on how they are fetched.
#define kHGSTypeFileMedia        HGS_SUBTYPE(kHGSTypeFile, @"media")
#define kHGSTypeFileMusic        HGS_SUBTYPE(kHGSTypeFileMedia, @"music")
#define kHGSTypeFileImage        HGS_SUBTYPE(kHGSTypeFileMedia, @"image")
#define kHGSTypeFileMovie        HGS_SUBTYPE(kHGSTypeFileMedia, @"movie")
#define kHGSTypeFilePDF          HGS_SUBTYPE(kHGSTypeFile, @"pdf")
#define kHGSTypeFilePresentation HGS_SUBTYPE(kHGSTypeFile, @"presentation")
#define kHGSTypeFileFont         HGS_SUBTYPE(kHGSTypeFile, @"font")
#define kHGSTypeFileCalendar     HGS_SUBTYPE(kHGSTypeFile, @"calendar")
#define kHGSTypeWebMedia         HGS_SUBTYPE(kHGSTypeWebpage, @"media")
#define kHGSTypeWebMusic         HGS_SUBTYPE(kHGSTypeWebMedia, @"music")
#define kHGSTypeWebImage         HGS_SUBTYPE(kHGSTypeWebMedia, @"image")
#define kHGSTypeWebMovie         HGS_SUBTYPE(kHGSTypeWebMedia, @"movie")
// TODO(dmaclach): should album inherit from image?
#define kHGSTypeFilePhotoAlbum   HGS_SUBTYPE(kHGSTypeFileImage, @"album") 
#define kHGSTypeWebPhotoAlbum    HGS_SUBTYPE(kHGSTypeWebImage, @"album") 
#define kHGSTypeTextUserInput    HGS_SUBTYPE(kHGSTypeText, @"userinput")
#define kHGSTypeTextPhoneNumber  HGS_SUBTYPE(kHGSTypeText, @"phonenumber")
#define kHGSTypeTextEmailAddress HGS_SUBTYPE(kHGSTypeText, @"emailaddress")
#define kHGSTypeTextInstantMessage HGS_SUBTYPE(kHGSTypeText, @"instantmessage")
#define kHGSTypeTextAddress      HGS_SUBTYPE(kHGSTypeText, @"address")
#define kHGSTypeWebCalendar      HGS_SUBTYPE(kHGSTypeWebpage, @"calendar") 
#define kHGSTypeWebCalendarEvent HGS_SUBTYPE(kHGSTypeWebpage, @"event") 
