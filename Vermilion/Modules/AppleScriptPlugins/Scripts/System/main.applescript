--
--  main.applescript
--  System Plugin
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

on closeDiskTray()
	do shell script "drutil tray close"
end closeDiskTray

on ejectDiskTray()
	do shell script "drutil tray eject"
end ejectDiskTray

on emptyTrash()
	tell application "Finder" to empty trash
end emptyTrash

on hideOthers()
	tell application "System Events"
		set visible of every process whose frontmost is false to false
	end tell
end hideOthers

on lockScreen()
	do shell script "'/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession' -suspend > /dev/null"
end lockScreen

on logout()
	tell application "System Events" to log out
end logout

on quitVisibleApps()
	tell application "System Events"
		set theApps to name of every process whose accepts high level events is true and visible is true and name is not "Finder" and name is not "Quick Search Box"
	end tell
	ignoring application responses
		repeat with theApp in theApps
			try
				tell application theApp to quit
			end try
		end repeat
		
	end ignoring
end quitVisibleApps

on restart()
	tell application "System Events" to restart
end restart

on showAll()
	tell application "System Events"
		set visible of every process to true
	end tell
end showAll

on shutDown()
	tell application "System Events" to shut down
end shutDown

on sleep()
	tell application "System Events" to sleep
end sleep

on uniqueName(baseName)
	tell application "System Events"
		set dFolder to (POSIX path of desktop folder)
		set basePath to dFolder & "/" & baseName
		set i to 1
		set finalPath to ""
		repeat while true
			set finalPath to basePath & i & ".png"
			try
				set finalItem to file finalPath
			on error e
				exit repeat
			end try
			set i to i + 1
		end repeat
		finalPath
	end tell
end uniqueName

on captureRegion()
	set pictureString to (localized string "^Picture ")
	tell me to set picName to uniqueName(pictureString)
	do shell script "syslog -s -l 1 " & picName
	do shell script "screencapture -i \"" & picName & "\""
end captureRegion

on captureWindow()
	set pictureString to (localized string "^Picture ")
	tell me to set picName to uniqueName(pictureString)
	do shell script "screencapture -iW \"" & picName & "\""
end captureWindow
