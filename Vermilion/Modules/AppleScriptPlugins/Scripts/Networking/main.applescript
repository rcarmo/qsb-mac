--
--  main.applescript
--  Networking Plugin
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

--  The weird hack with appID is required due to Applescript not
--  always being able to find our script definitions at build time
--  especially on a build machine using a build system like pulse.
--  This avoids the issue.

on getIP()
	set theIP to do shell script "ifconfig | grep 'broadcast' | awk '{print $2}'"
	set appID to "com.google.qsb"
	tell application id appID to «event QSBSLaTy» (theIP)
	return theIP
end getIP

-- TODO(dmaclach): do we want to ship with checkip.dyndns.org?
on getExternalIP()
	set theIP to do shell script "curl -sf http://checkip.dyndns.org/|cut -d ':' -f 2|cut -d '<' -f1|sed -e 's/ //g'"
	set appID to "com.google.qsb"
	tell application id appID to «event QSBSLaTy» (theIP)
	return theIP
end getExternalIP
