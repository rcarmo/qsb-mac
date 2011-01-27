--
--  FileSystemActions.applescript
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

-- Script for FileSystemShowInFinderAction
on showInFinder(x)
	repeat with y in x
		set macpath to POSIX file y as text
		tell application "Finder" to reveal macpath
	end repeat
	tell application "Finder" to activate
end showInFinder

-- Script for FileSystemGetInfoAction
on getInfo(x)
	repeat with y in x
		set macpath to POSIX file y as text
		tell application "Finder" to open information window of item macpath
	end repeat
	tell application "Finder" to activate
end getInfo

-- Script for FileSystemMoveToAction
on moveto(sourceFiles, dest)
	set macdest to POSIX file dest as text
	repeat with sourceFile in sourceFiles
		set macsource to POSIX file sourceFile as text
		tell application "Finder" to move macsource to macdest
	end repeat
end moveto

on copyto(sourceFiles, dest)
	set macdest to POSIX file dest as text
	repeat with sourceFile in sourceFiles
		set macsource to POSIX file sourceFile as text
		tell application "Finder" to duplicate macsource to macdest
	end repeat
end copyto
