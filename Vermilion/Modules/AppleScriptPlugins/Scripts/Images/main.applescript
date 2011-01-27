--
--  main.applescript
--  Images Plugin
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

-- Factories
on makeRotater(anAngle)
	script rotater
		property pAngle : anAngle
		on perform(anAlias)
			tell application "Image Events"
				activate
				set anImage to open anAlias
				rotate anImage to angle pAngle
				save anImage
				close anImage
			end tell
		end perform
	end script
	return rotater
end makeRotater

on makeScaler(aFactor)
	script scaler
		property pFactor : aFactor
		on perform(anAlias)
			tell application "Image Events"
				activate
				set anImage to open anAlias
				scale anImage by factor pFactor
				save anImage
				close anImage
			end tell
		end perform
	end script
	return scaler
end makeScaler

on makeConverter(aFormat, anExtension)
	script converter
		property pFormat : aFormat
		property pExtension : anExtension
		on perform(anAlias)
			set posixPath to POSIX path of anAlias
			set newPath to removeExtension(posixPath) & "." & anExtension
			tell application "Image Events"
				activate
				set anImage to open anAlias
				save anImage as pFormat in newPath
				close anImage
			end tell
			tell application "Finder"
				move anAlias to trash
			end tell
		end perform
		
		on removeExtension(fName)
			set a to characters of fName
			set b to reverse of a
			set c to offset of "." in (b as string)
			return (text 1 thru -(c + 1)) of fName
		end removeExtension
		
	end script
	return converter
end makeConverter

-- Utility Functions
on filePathForURL(anURL)
	set appID to "com.google.qsb"
	tell application id appID
		set filePath to «event QSBSFiUr» (anURL)
	end tell
	return filePath
end filePathForURL

on repeater(results, aScript)
	repeat with x in results
		set theURL to «class pURI» of x
		tell me to set thePath to filePathForURL(theURL)
		if length of thePath ≠ 0 then
			set asFile to POSIX file (thePath)
			set asAlias to (asFile as alias)
			tell aScript to perform(asAlias)
		end if
	end repeat
end repeater

-- Handlers
on rotateCW(results)
	set rotater to makeRotater(90)
	repeater(results, rotater)
end rotateCW


on rotateCCW(results)
	set rotater to makeRotater(270)
	repeater(results, rotater)
end rotateCCW

on scale(results)
	tell application "System Events"
		activate
		set scaleFactorReply to display dialog "Scale by (percent):" default answer "50"
	end tell
	set scaleFactorText to text returned of scaleFactorReply
	set scaleFactor to scaleFactorText as number
	if scaleFactor is less than or equal to 0 then return
	set scaleFactor to scaleFactor / 100.0
	set scaler to makeScaler(scaleFactor)
	repeater(results, scaler)
end scale

on convert(results)
	tell application "System Events"
		activate
		set aFormatName to choose from list {"BMP", "JPEG", "JPEG2", "PICT", "PNG", "PSD", "TIFF"} with title "Convert Format" with prompt "Please select a format to convert to:" without multiple selections allowed and empty selection allowed
	end tell
	if aFormatName is not false then
		set aFormatName to item 1 of aFormatName
		tell application "Image Events"
			if aFormatName is "BMP" then
				set aFormat to BMP
				set anExtension to "bmp"
			else if aFormatName is "JPEG" then
				set aFormat to JPEG
				set anExtension to "jpg"
			else if aFormatName is "JPEG2" then
				set aFormat to JPEG2
				set anExtension to "jp2"
			else if aFormatName is "PICT" then
				set aFormat to PICT
				set anExtension to "pict"
			else if aFormatName is "PNG" then
				set aFormat to PNG
				set anExtension to "png"
			else if aFormatName is "PSD" then
				set aFormat to PSD
				set anExtension to "psd"
			else if aFormatName is "TIFF" then
				set aFormat to TIFF
				set anExtension to "tiff"
			else
				error "Unknown format " & aFormatName
			end if
			
		end tell
		set converter to makeConverter(aFormat, anExtension)
		repeater(results, converter)
	end if
end convert

on setAsDesktopPicture(results)
	set theResult to item 1 of results
	set theURL to «class pURI» of theResult
	tell me to set thePath to filePathForURL(theURL)
	if length of thePath ≠ 0 then
		set asFile to POSIX file (thePath)
		tell application "System Events"
			set picture of current desktop to asFile
		end tell
	end if
end setAsDesktopPicture
end

