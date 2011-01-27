//
//  iTunesSource.h
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
#import <Vermilion/Vermilion.h>

#define kTypeITunes    @"itunes"
#define kTypeITunesArtist    HGS_SUBTYPE(kTypeITunes, @"artist")
#define kTypeITunesAlbum     HGS_SUBTYPE(kTypeITunes, @"album")
#define kTypeITunesComposer  HGS_SUBTYPE(kTypeITunes, @"composer")
#define kTypeITunesGenre     HGS_SUBTYPE(kTypeITunes, @"genre")
#define kTypeITunesPlaylist  HGS_SUBTYPE(kTypeITunes, @"playlist")

extern NSString* const kITunesAttributeTrackIdKey;  // NSNumber
extern NSString* const kITunesAttributeArtistKey; // NSString
extern NSString* const kITunesAttributeAlbumKey; // NSString
extern NSString* const kITunesAttributeComposerKey; // NSString
extern NSString* const kITunesAttributeGenreKey; // NSString
extern NSString* const kITunesAttributePlaylistKey; // NSString
extern NSString* const kITunesAttributePlaylistIdKey; // NSNumber
extern NSString* const kITunesAttributeIconFileKey; // NSURL


