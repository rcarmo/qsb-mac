--
--  iTunes.applescript
--
--  Copyright (c) 2008 Google Inc. All rights reserved.
--
--  Redistribution and use in source and binary forms, with or without
--  modification, are permitted provided that the following conditions are
--  met:
--
--    * Redistributions of source code must retain the above copyright
--  notice, this list of conditions and the following disclaimer.
--    * Redistributions in binary form must reproduce the above
--  copyright notice, this list of conditions and the following disclaimer
--  in the documentation and/or other materials provided with the
--  distribution.
--    * Neither the name of Google Inc. nor the names of its
--  contributors may be used to endorse or promote products derived from
--  this software without specific prior written permission.
--
--  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
--  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
--  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
--  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
--  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
--  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
--  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
--  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
--  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
--  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
--  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--

on libraryPlaylist()
	tell application "iTunes"
		return item 1 of (every source whose kind is library)
	end tell
end libraryPlaylist

on isPlaying()
	tell application "System Events"
		if (get name of every process) contains "iTunes" then
			tell application "iTunes"
				if player state is playing then return true
			end tell
		end if
	end tell
	return false
end isPlaying

on revealTrackID(trackID)
	tell application "iTunes"
		reveal (item 1 of (tracks of playlist "Music" whose database ID is trackID))
	end tell
end revealTrackID

on playTrackID(trackID)
	tell application "iTunes"
		play (item 1 of (tracks of playlist 1 whose database ID is trackID))
	end tell
end playTrackID

on playTrackIDInPlaylistID(trackID, playlistID)
	tell application "iTunes"
		reveal playlist id playlistID
		play (tracks of playlist id playlistID whose database ID is trackID)
	end tell
end playTrackIDInPlaylistID

on playArtist(artistName)
	set googlePlaylist to prepareGooglePlaylist()
	set libPlaylist to libraryPlaylist()
	tell application "iTunes"
		tell libPlaylist
			duplicate (every track whose enabled = true and artist = artistName) to googlePlaylist
		end tell
		play googlePlaylist
	end tell
end playArtist

on playAlbum(albumName)
	set googlePlaylist to prepareGooglePlaylist()
	set libPlaylist to libraryPlaylist()
	tell application "iTunes"
		tell libPlaylist
			duplicate (every track whose enabled = true and album = albumName) to googlePlaylist
		end tell
		play googlePlaylist
	end tell
end playAlbum

on playComposer(composerName)
	set googlePlaylist to prepareGooglePlaylist()
	set libPlaylist to libraryPlaylist()
	tell application "iTunes"
		tell libPlaylist
			duplicate (every track whose enabled = true and composer = composerName) to googlePlaylist
		end tell
		play googlePlaylist
	end tell
end playComposer

on playGenre(genreName)
	set googlePlaylist to prepareGooglePlaylist()
	set libPlaylist to libraryPlaylist()
	tell application "iTunes"
		tell libPlaylist
			duplicate (every track whose enabled = true and genre = genreName) to googlePlaylist
		end tell
		play googlePlaylist
	end tell
end playGenre

on playPlaylist(playlistName)
	tell application "iTunes"
		reveal playlist playlistName
		play playlist playlistName
	end tell
end playPlaylist

on prepareGooglePlaylist()
	set kGooglePlaylistName to "Google"
	tell application "iTunes"
		if not ((name of playlists) contains kGooglePlaylistName) then
			set googlePlaylist to make new playlist with properties {name:kGooglePlaylistName}
		else
			set googlePlaylist to playlist kGooglePlaylistName
			delete every track of googlePlaylist
		end if
		reveal googlePlaylist
	end tell
	return googlePlaylist
end prepareGooglePlaylist

on addToPartyShuffle(trackID)
	tell application "iTunes"
		set theTrackReference to (tracks of playlist 1 whose database ID is trackID)
		set thePlaylist to item 1 of (every playlist whose special kind is Party Shuffle)
		set theAddedTracks to (my safe_duplicate_tracks(theTrackReference, thePlaylist))
	end tell
end addToPartyShuffle

on playInPartyShuffle(trackID)
	tell application "iTunes"
		set theTrackReference to (tracks of playlist 1 whose database ID is trackID)
		set thePlaylist to item 1 of (every playlist whose special kind is Party Shuffle)
		set theAddedTracks to (my safe_duplicate_tracks_and_play(theTrackReference, thePlaylist, true))
	end tell
end playInPartyShuffle

on safe_duplicate_tracks(theReference, thePlaylist)
	safe_duplicate_tracks_and_play(theReference, thePlaylist, false)
end safe_duplicate_tracks

on safe_duplicate_tracks_and_play(theReference, thePlaylist, playFirst) -- normal version fails when tracks are missing
	try
		set theTracks to duplicate theReference to thePlaylist
		if playFirst then tell application "iTunes" to play item 1 of theTracks
	on error theError
		if class of theReference is record then return filtered_duplicate_tracks(theReference, thePlaylist, playFirst)
		set theTracks to {}
		tell application "iTunes"
			repeat with theTrack in theReference
				--try
				set end of theTracks to duplicate theTrack to thePlaylist
				if playFirst then
					play item 1 of theTracks
					set playFirst to false
				end if
				--end try
			end repeat
		end tell
		
		return theTracks
	end try
end safe_duplicate_tracks_and_play

on filtered_duplicate_tracks(theRecord, thePlaylist, playFirst) -- normal version fails when tracks are missing
	set sourceTracks to trackList of theRecord
	set theTracks to {}
	
	set theCriteria to criteria of theRecord
	set theValue to value of theCriteria
	
	tell application "iTunes"
		if (field of theCriteria is "Album") then
			repeat with theTrack in sourceTracks
				try
					if album of theTrack is theValue then set end of theTracks to duplicate theTrack to thePlaylist
					if playFirst then
						play item 1 of theTracks
						set playFirst to false
					end if
				end try
			end repeat
		else if (field of theCriteria is "Artist") then
			repeat with theTrack in sourceTracks
				try
					if artist of theTrack is theValue then set end of theTracks to duplicate theTrack to thePlaylist
					if playFirst then
						play item 1 of theTracks
						set playFirst to false
					end if
				end try
			end repeat
		else if (field of theCriteria is "Composer") then
			repeat with theTrack in sourceTracks
				try
					if composer of theTrack is theValue then set end of theTracks to duplicate theTrack to thePlaylist
					if playFirst then
						play item 1 of theTracks
						set playFirst to false
					end if
				end try
			end repeat
		end if
	end tell
	
	return theTracks
end filtered_duplicate_tracks


-- Actions
on toggleRepeat()
	tell application "iTunes"
		tell current playlist
			if song repeat is off then
				set song repeat to one
			else if song repeat is one then
				set song repeat to all
			else
				set song repeat to off
			end if
		end tell
	end tell
end toggleRepeat

on toggleShuffle()
	tell application "iTunes" to tell current playlist to set shuffle to not shuffle
end toggleShuffle

on setRatingTo0()
	tell application "iTunes" to set rating of current track to 0
end setRatingTo0

on setRatingTo1()
	tell application "iTunes" to set rating of current track to 20
end setRatingTo1

on setRatingTo2()
	tell application "iTunes" to set rating of current track to 40
end setRatingTo2

on setRatingTo3()
	tell application "iTunes" to set rating of current track to 60
end setRatingTo3

on setRatingTo4()
	tell application "iTunes" to set rating of current track to 80
end setRatingTo4

on setRatingTo5()
	tell application "iTunes" to set rating of current track to 100
end setRatingTo5

on decreaseVolume()
	tell application "iTunes" to set sound volume to sound volume - 10
end decreaseVolume

on increaseVolume()
	tell application "iTunes" to set sound volume to sound volume + 10
end increaseVolume

on toggleMute()
	tell application "iTunes" to set mute to not mute
end toggleMute

on increaseRating()
	tell application "iTunes"
		if rating of current track is less than 100 then set rating of current track to (rating of current track) + 20
	end tell
end increaseRating

on decreaseRating()
	tell application "iTunes"
		if rating of current track is greater than 0 then set rating of current track to (rating of current track) - 20
	end tell
end decreaseRating

on playNow()
	tell application "iTunes" to play
end playNow

on pauseNow()
	tell application "iTunes" to pause
end pauseNow

on goForward()
	tell application "iTunes" to next track
end goForward

on goBack()
	tell application "iTunes" to previous track
end goBack

