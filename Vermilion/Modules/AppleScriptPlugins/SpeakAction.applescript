-- A simple demo script for testing QSB2
-- © Google 2008

using terms from application "Google Quick Search"
	script Speak
		on perform action on a
			say name of a
		end perform action on
		
		on does action apply to a
			return true
		end does action apply to
		
		on get action name with a
			return "Speak " & name of a
		end get action name with
	end script
	
	on get actions
		return {Speak}
	end get actions
end using terms from