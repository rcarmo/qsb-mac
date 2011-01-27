--
--   SLFilesSourceTestScript.applescript
--
--  Copyright (c) 2009 Google Inc. All rights reserved.
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

on setSpotlightComment(fileName, slComment)
	tell application "Finder"
		-- Make sure the finder is aware of the file we just created
		set macPath to POSIX file fileName as Unicode text
		set AppleScript's text item delimiters to ":"
		set pathBits to every text item of macPath
		set AppleScript's text item delimiters to ""
		set wholePath to ""
		repeat with bits in pathBits
			set wholePath to wholePath & bits & ":"
			update wholePath
		end repeat
		
		-- Set our comment
		set anItem to item macPath
		set comment of anItem to slComment
	end tell
end setSpotlightComment


-- Useful for testing
on run
	set a to choose file
	tell application "Finder"
		set b to display dialog "Set Comment" buttons {"OK", "Cancel"} default button "OK" cancel button "Cancel" default answer "a comment"
	end tell
	if button returned of b is "OK" then
		tell me to setSpotlightComment(POSIX path of a, text returned of b)
	end if
end run