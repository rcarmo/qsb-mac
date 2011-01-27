//
//  iTunesAction.m
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

#import "ITunesSource.h"
#import "GTMMethodCheck.h"
#import "GTMNSAppleScript+Handler.h"
#import "GTMObjectSingleton.h"
#import "HGSAppleScriptAction.h"
#import "GTMDebugThreadValidation.h"
#import "GTMNSWorkspace+Running.h"

static NSString *const kITunesAppleScriptHandlerKey
  = @"kITunesAppleScriptHandlerKey";
static NSString *const kITunesAppleScriptParametersKey
  = @"kITunesAppleScriptParametersKey";
static NSString *const kITunesPlayerInfoNotification
  = @"com.apple.iTunes.playerInfo";
static NSString *const kITunesAppBundleID = @"com.apple.iTunes";
static NSString *const kITunesShowIfPlayingKey = @"ITunesShowIfPlaying";

// Music tracks are of type file.media.music.
// ITunesTrackAction actions requires that they be file.media.music tracks that
// come from the iTunes source.
@interface ITunesTrackAction : HGSAction
@end

@interface ITunesPlayAction : ITunesTrackAction
@end

@interface ITunesPartyShuffleAction : ITunesTrackAction
- (NSString *)shuffleActionName;
@end

@interface ITunesPlayInPartyShuffleAction : ITunesPartyShuffleAction
@end

@interface ITunesAddToPartyShuffleAction : ITunesPartyShuffleAction
@end

enum ITunesAppPlayingState {
  eITunesPaused = 0,
  eITunesPlaying = 1,
  eITunesUnknown = 2
};

@interface ITunesAppPlayingAction : HGSAppleScriptAction {
 @private
  BOOL showIfPlaying_;
  enum ITunesAppPlayingState playingState_;
}

- (BOOL)isPlaying;
- (void)iTunesPlayerInfoNotification:(NSNotification *)notification;
@end

@interface ITunesActionSupport : NSObject {
  NSAppleScript *script_; // STRONG
}
@end

@implementation ITunesActionSupport

GTMOBJECT_SINGLETON_BOILERPLATE(ITunesActionSupport, sharedSupport);

- (id)init {
  if ((self = [super init])) {
    NSBundle *bundle = HGSGetPluginBundle();
    NSString *path = [bundle pathForResource:@"iTunes"
                                      ofType:@"scpt"
                                 inDirectory:@"Scripts"];
    NSURL *url = [NSURL fileURLWithPath:path];
    NSDictionary *error = nil;
    script_ = [[NSAppleScript alloc] initWithContentsOfURL:url error:&error];
    if (!script_) {
      HGSLogDebug(@"Unable to load script: %@ error: %@", url, error);
      [self release];
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [script_ release];
  [super dealloc];
}

- (NSAppleEventDescriptor *)execute:(NSDictionary *)params {
  NSDictionary *errorDictionary = nil;
  NSAppleEventDescriptor *result;
  NSString *handler = [params objectForKey:kITunesAppleScriptHandlerKey];
  NSArray *args = [params objectForKey:kITunesAppleScriptParametersKey];
  result = [script_ gtm_executePositionalHandler:handler
                                      parameters:args
                                           error:&errorDictionary];
  if (errorDictionary) {
    HGSLog(@"iTunes script failed %@(%@): %@", handler, args, errorDictionary);
  }
  return result;
}

@end

@implementation ITunesTrackAction

- (BOOL)appliesToResult:(HGSResult *)result {
  BOOL isGood = [super appliesToResult:result];
  if (isGood) {
    if ([result conformsToType:kHGSTypeFileMusic]) {
      isGood = [result valueForKey:kITunesAttributeTrackIdKey] != nil;
    }
  }
  return isGood;
}

@end

// "Play in iTunes" action for iTunes search results
@implementation ITunesPlayAction

GTM_METHOD_CHECK(NSAppleScript, gtm_executePositionalHandler:parameters:error:);

- (BOOL)appliesToResults:(HGSResultArray *)results {
  BOOL doesApply = [results count] == 1;
  if (doesApply) {
    doesApply = [super appliesToResults:results];
  }
  return doesApply;
}

- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  NSString *handler = nil;
  NSString *directObjectKey = nil;
  id extraArg = nil;
  HGSResult *directObject = [directObjects objectAtIndex:0];
  if ([directObject isOfType:kHGSTypeFileMusic]) {
    extraArg = [directObject valueForKey:kITunesAttributePlaylistIdKey];
    if (extraArg) {
      handler = @"playTrackIDInPlaylistID";
      directObjectKey = kITunesAttributeTrackIdKey;
    } else {
      handler = @"playTrackID";
      directObjectKey = kITunesAttributeTrackIdKey;
    }
  } else if ([directObject isOfType:kTypeITunesArtist]) {
    handler = @"playArtist";
    directObjectKey = kITunesAttributeArtistKey;
  } else if ([directObject isOfType:kTypeITunesAlbum]) {
    handler = @"playAlbum";
    directObjectKey = kITunesAttributeAlbumKey;
  } else if ([directObject isOfType:kTypeITunesComposer]) {
    handler = @"playComposer";
    directObjectKey = kITunesAttributeComposerKey;
  } else if ([directObject isOfType:kTypeITunesGenre]) {
    handler = @"playGenre";
    directObjectKey = kITunesAttributeGenreKey;
  } else if ([directObject isOfType:kTypeITunesPlaylist]) {
    handler = @"playPlaylist";
    directObjectKey = kITunesAttributePlaylistKey;
  }
  if (handler && directObjectKey) {
    id directObjectVal = [directObject valueForKey:directObjectKey];
    NSArray *parameters
      = [NSArray arrayWithObjects:directObjectVal, extraArg, nil];
    NSDictionary *scriptParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                  handler, kITunesAppleScriptHandlerKey,
                                  parameters, kITunesAppleScriptParametersKey,
                                  nil];
    ITunesActionSupport *support = [ITunesActionSupport sharedSupport];
    [support performSelectorOnMainThread:@selector(execute:)
                              withObject:scriptParams
                           waitUntilDone:NO];
  }
  return YES;
}

@end

@implementation ITunesPartyShuffleAction
- (BOOL)performWithInfo:(NSDictionary *)info {
  HGSResultArray *directObjects
    = [info objectForKey:kHGSActionDirectObjectsKey];
  NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:[directObjects count]];
  for (HGSResult *result in directObjects) {
    NSString *trackID = [result valueForKey:kITunesAttributeTrackIdKey];
    [tracks addObject:trackID];
  }
  NSString *shuffleActioName = [self shuffleActionName];
  NSDictionary *scriptParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                shuffleActioName, kITunesAppleScriptHandlerKey,
                                [NSArray arrayWithObject:tracks],
                                kITunesAppleScriptParametersKey, nil];
  ITunesActionSupport *support = [ITunesActionSupport sharedSupport];
  [support performSelectorOnMainThread:@selector(execute:)
                            withObject:scriptParams
                         waitUntilDone:NO];
  return YES;
}

- (NSString *)shuffleActionName {
  HGSAssert(NO, @"Must be overridden by subclass");
  return @"";
}

@end

// "Play in iTunes Party Shuffle" action for iTunes search results
@implementation ITunesPlayInPartyShuffleAction

- (BOOL)appliesToResults:(HGSResultArray *)results {
  // We don't want to show play in party shuffle if the user has selected
  // only one track.
  BOOL doesApply = [super appliesToResults:results];
  if (doesApply) {
    if ([results count] == 1) {
      HGSResult *result = [results objectAtIndex:0];
      if ([result isOfType:kHGSTypeFileMusic]) {
        doesApply = NO;
      }
    }
  }
  return doesApply;
}

- (NSString *)shuffleActionName {
  return @"playInPartyShuffle";
}

@end

// "Add to iTunes Party Shuffle" action for iTunes search results
@implementation ITunesAddToPartyShuffleAction
- (NSString *)shuffleActionName {
  return @"addToPartyShuffle";
}
@end

// Actions that are applied to the iTunes application while it's playing
// music
@implementation ITunesAppPlayingAction
GTM_METHOD_CHECK(NSWorkspace, gtm_isAppWithIdentifierRunning:);

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    NSDistributedNotificationCenter *nc
      = [NSDistributedNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(iTunesPlayerInfoNotification:)
               name:kITunesPlayerInfoNotification object:NULL];
    playingState_ = eITunesUnknown;
    showIfPlaying_
      = [[configuration objectForKey:kITunesShowIfPlayingKey] boolValue];
  }
  return self;
}

- (void)dealloc {
  NSDistributedNotificationCenter *nc
    = [NSDistributedNotificationCenter defaultCenter];
  [nc removeObserver:self];
  [super dealloc];
}

- (void)iTunesPlayerInfoNotification:(NSNotification *)notification {
  NSString *state = [[notification userInfo] objectForKey:@"Player State"];
  BOOL isPlaying = [state isEqualToString:@"Playing"];
  playingState_ = isPlaying ? eITunesPlaying : eITunesPaused;
}

- (BOOL)isPlaying {
  if (playingState_ == eITunesUnknown) {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    if ([ws gtm_isAppWithIdentifierRunning:kITunesAppBundleID]) {
      NSDictionary *scriptParams = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"isPlaying", kITunesAppleScriptHandlerKey,
                                    nil];
      ITunesActionSupport *support = [ITunesActionSupport sharedSupport];
      NSAppleEventDescriptor *result = [support execute:scriptParams];
      BOOL isPlaying = [result booleanValue];
      playingState_ = isPlaying ? eITunesPlaying : eITunesPaused;
    } else {
      playingState_ = eITunesPaused;
    }
  }
  return playingState_ == eITunesPlaying;
}

- (BOOL)showInGlobalSearchResults {
  BOOL shouldShow = [super showInGlobalSearchResults];
  return shouldShow && (showIfPlaying_ == [self isPlaying]);
}

- (BOOL)appliesToResults:(HGSResultArray *)results {
  BOOL doesApply = [super appliesToResults:results];
  return doesApply && (showIfPlaying_ == [self isPlaying]);
}

@end
