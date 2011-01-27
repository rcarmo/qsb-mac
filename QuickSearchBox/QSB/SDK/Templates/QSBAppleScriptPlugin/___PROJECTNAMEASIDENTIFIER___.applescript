--  ___PROJECTNAMEASIDENTIFIER___.applescript
--  ___PROJECTNAME___
--
--  Created by ___FULLUSERNAME___ on ___DATE___.
--  Copyright ___ORGANIZATIONNAME___ ___YEAR___. All rights reserved.

-- Results is a list of records. Each result has a name and an
-- URI property.
on ___PROJECTNAMEASIDENTIFIER___(results)
	using terms from application "Quick Search Box"
		repeat with x in results
			display dialog "Name: " & name of x & return & "URI: " & URI of x
		end repeat
	end using terms from
end ___PROJECTNAMEASIDENTIFIER___

-- You can also write your script to be just an "open" handler
-- in that case the values passed to you will just be a list of
-- URLs as strings.
