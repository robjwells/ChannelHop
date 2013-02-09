--	ChannelHop, automatic TV listings layout for the Morning Star

--	First created:	08/09/2012
--	Last updated:	09/02/2013
--	Version:	1.2

--	Icon originally by Travis Yunis, available from thenounproject.com

property listingsFTP : "Your FTP server details here"


launch application "TextWrangler"
set dateObject to getDate()
set listingsFolder to createListingsFolder(dateObject)
set fileObject to getFiles(dateObject, listingsFolder)
processListings(fileObject's _dF, fileObject's _rdF, fileObject's _rgF, fileObject's _tF, dateObject's _day, false)
if dateObject's _day is "Saturday" then
	processListings(fileObject's s_dF, fileObject's s_rdF, fileObject's s_rgF, fileObject's s_tF, dateObject's _day, true)
end if
tell application "Finder" to delete listingsFolder
tell application "Adobe InDesign CS5.5" to activate


-- Handler definitions

-- TextWrangler replace convenience functions
on _grep(searchString, replaceString)
	tell application "TextWrangler"
		replace searchString using replaceString searching in text 1 of text document 1 options {search mode:grep, starting at top:true}
	end tell
end _grep

on _lit(searchString, replaceString)
	tell application "TextWrangler"
		replace searchString using replaceString searching in text 1 of text document 1 options {search mode:literal, starting at top:true}
	end tell
end _lit


-- Returns theItem's position in theList as an integer
on list_position(this_item, this_list)
	repeat with i from 1 to count of this_list
		if item i of this_list is this_item then return i
	end repeat
end list_position


-- Create and return an object containing the weekday, MMDD edition date and MMDD date for Sunday (if necessary)
on getDate()
	set theTitle to "Automatic TV listings"
	set days_list to {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}
	set months_list to {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"}
	set dateObject to {_day:"", _revDate:"", s_revDate:""}
	
	-- Get tomorrow's weekday as a seed default for the prompt
	if (the weekday of the (current date)) as string is not "Saturday" then
		set tomorrow to (the (current date) + (1 * days))
	else -- Jump ahead a day if Saturday (mostly for dev)
		set tomorrow to (the (current date) + (2 * days))
	end if
	set tmDay to {(tomorrow's weekday as string)} -- "Choose from list" requires a list for its default selection
	
	set theDay to (choose from list days_list with prompt "Please pick the edition day:" default items tmDay with title theTitle) as string
	if result is "false" then error number -128 -- Choosing "Cancel" in the dialog ends the script
	
	-- Predicted date crunching
	if theDay is (tmDay as string) then -- Chosen day is tomorrow
		-- Set defaults to tomorrow's details
		set prDate to tomorrow's day
		set prMonth to {(tomorrow's month as string)}
		set prYear to tomorrow's year -- Needed for creating a Sunday AS date object
	else if theDay is not (tmDay as string) then -- Chosen day is not tomorrow
		-- Determine offset from tomorrow and create a date object for it
		set predictPos to my list_position((tmDay as string), days_list)
		set actualPos to my list_position(theDay, days_list)
		set shiftPos to actualPos - predictPos
		if shiftPos is greater than 0 then -- Another day in current week
			set predictedDay to tomorrow + (shiftPos * days)
		else if shiftPos is less than 0 then -- Implies next week
			set predictedDay to tomorrow + ((7 + shiftPos) * days)
		end if
		
		-- Set defaults with chosen day's details
		set prDate to predictedDay's day
		set prMonth to {(predictedDay's month as string)}
		set prYear to predictedDay's year -- Needed for creating a Sunday AS date object
	end if
	
	-- Prompt for the date
	set theMonth to (choose from list months_list default items prMonth with prompt "Please pick the month:" with title theTitle) as text
	if result is "false" then error number -128
	set theDate to the text returned of (display dialog "Please type the date:" default answer prDate with title theTitle) as text
	if result is "false" then error number -128
	
	set dateObject's _day to theDay
	set shortDay to (characters 1 through 3 of theDay) as text
	
	-- Get the month number and add a leading zero if necessary
	set numMonth to my list_position(theMonth, months_list)
	if numMonth is less than 10 then set numMonth to ("0" & numMonth)
	
	-- Add an initial zero to the date if necessary
	if (theDate as integer is less than 10) and (character 1 of theDate is not "0") then set theDate to ("0" & theDate)
	
	set dateObject's _revDate to (shortDay & "_" & numMonth & theDate)
	
	-- Create a Sunday date
	if theDay is "Saturday" then
		-- Create an AppleScript date object for Sunday. Using predicted year could cause problems in theory, but unlikely
		set sun to ((date (theDay & ", " & theDate & " " & theMonth & " " & prYear)) + 1 * days)
		
		set Sun_date to sun's day
		if Sun_date is less than 10 then set Sun_date to ("0" & Sun_date)
		
		set Sun_numMonth to sun's month as number
		if Sun_numMonth is less than 10 then set Sun_numMonth to ("0" & Sun_numMonth)
		
		set dateObject's s_revDate to ("Sun_" & Sun_numMonth & Sun_date)
	end if
	return dateObject
end getDate


-- Create temporary listings folder
on createListingsFolder(dateObject)
	tell application "Finder"
		try
			set listingsFolder to (make new folder at desktop with properties {name:(dateObject's _day) & "'s listings"}) as text
		on error number -48 -- If the folder already exists, empty it
			set listingsFolder to (((path to desktop) as text) & ((dateObject's _day) & "'s listings:"))
			delete every item of folder listingsFolder
		end try
	end tell
	return listingsFolder
end createListingsFolder


-- File transfer handler
on getFiles(dateObject, listingsFolder)
	set fileObject to {_dF:"", _rdF:"", _rgF:"", _tF:"", s_dF:"", s_rdF:"", s_rgF:"", s_tF:""}
	set ejectFile to mount volume listingsFTP
	tell application "Finder"
		set listingsServer to ((get the name of the startup disk) & ":Volumes:listings.bds.tv:") -- Path, differs from ejectFile, allows copying
		
		script filesInner -- Closure
			on _dupe(listingsType, sun) -- Copy files from server. 'sun' is Sunday flag
				if sun is false then
					set dupeDate to dateObject's _revDate
				else
					set dupeDate to dateObject's s_revDate
				end if
				tell application "Finder"
					duplicate file (listingsServer & "a_" & listingsType & "_" & dupeDate & ".txt") to folder listingsFolder
				end tell
			end _dupe
			
			on noFiles(sun) -- Eject server, delete temp folder, display alert, stop the script
				tell application "Finder"
					eject ejectFile
					delete listingsFolder
					set msg to "It doesn't look like the server has any listings files for "
					if sun is false then
						set msg to msg & (dateObject's _day) & "."
					else
						set msg to msg & "Sunday."
					end if
					display alert "Whoops" message msg
					error number -128
				end tell
			end noFiles
			
			try -- Copy the files from the server
				set fileObject's _dF to my _dupe("digital", false)
				set fileObject's _rdF to my _dupe("radio", false)
				set fileObject's _rgF to my _dupe("regional", false)
				set fileObject's _tF to my _dupe("terrestrial", false)
			on error number -10006 -- File not found
				my noFiles(false)
			end try
			
			if dateObject's _day is "Saturday" then
				try -- Copy the Sunday files from the server
					set fileObject's s_dF to _dupe("digital", true)
					set fileObject's s_rdF to _dupe("radio", true)
					set fileObject's s_rgF to _dupe("regional", true)
					set fileObject's s_tF to _dupe("terrestrial", true)
				on error number -10006 -- File not found
					my noFiles(true)
				end try
			end if
		end script
		
		delay 2 -- Gives the server time to mount
		run filesInner
		eject ejectFile
	end tell
	return fileObject
end getFiles


-- Clean-up handlers
on basicClean()
	tell application "TextWrangler"
		my _lit("...", "…")
		my _lit(" - ", " — ")
		educate quotes text 1 of text document 1 with replacing target
	end tell
end basicClean

on digitalClean()
	tell application "TextWrangler"
		-- Delete ITV3 listings
		my _grep("(^\\ ITV3[\\s\\S]+)(^\\ E4)", "\\2")
		-- Clean and space out channel-name lines
		my _grep("^(\\ |\\:\\ )(.+)$", "\\r\\r\\r\\2\\r")
	end tell
end digitalClean

on terrestrialClean()
	tell application "TextWrangler"
		-- Space out channel-name lines
		my _grep("(^BBC\\ One$|^BBC\\ Two$|^ITV1\\ London:$|^Channel\\ 4$|^Channel\\ Five$)", "\\r\\r\\r\\1\\r")
		-- Clean up ITV1 channel-name line
		my _grep("^(ITV1)\\ London:$", "\\1")
	end tell
end terrestrialClean

on digital_terrestrialShared()
	tell application "TextWrangler"
		-- Break morning listings on to individual lines
		my _grep("(\\.|\\!|\\?)\\ (\\d+\\.)", "\\1\\r\\2")
		
		-- Break up morning and afternoon listings
		my _grep("(^[1-5]\\..+\\r)(^([6-9]|10|11|12)\\.)", "\\1\\r\\2")
		my _grep("(^(9|10|11|12)\\..+\\r)(^[6-8]\\.)", "\\1\\r\\3")
		my _grep("(^(10|11|12)\\..+\\r)(^[6-9]\\.)", "\\1\\r\\3")
		my _grep("(^(11|12)\\..+\\r)(^([6-9]|10)\\.)", "\\1\\r\\3")
		my _grep("(^(12)\\..+\\r)(^([6-9]|10|11)\\.)", "\\1\\r\\3")
		
		-- Remove "Close" from non-24 hour channels
		my _grep("$\\r^\\d+\\.\\d+\\ Close\\.$", "")
		
		-- Put full stop after film name
		my _grep("([[:alnum:]])(\\ \\d{4}\\ Film\\.)", "\\1\\.\\2")
	end tell
end digital_terrestrialShared

on radioClean()
	tell application "TextWrangler"
		my _grep("\\ARadio\\ listings\\r", "")
		my _grep("^\\ BBC\\ (Radio\\ \\d.*)$", "\\1")
	end tell
end radioClean

on regionalClean()
	tell application "TextWrangler"
		my _grep("\\ARegional\\ Variations\\r", "")
		my _grep("(^\\ S4C\\:[\\s\\S]+This channel has ceased broadcasting[\\s\\S]+)(^\\ STV\\ )", "\\2")
		my _grep("^ (.+:)\\r", "\\1\\ ") -- Put channel names inline with listings
		my _grep("(\\d+\\.\\d+\\ As BBC1\\.\\ |\\ \\d+\\.\\d+\\ As BBC1\\.$)", "") -- Remove useless "As BBC1" listings
		my _grep("^ITV1\\ .+:\\ (\\d+\\.\\d+)[[:alpha:]&\\ ]+\\.$", "ITV1: \\1 Regional News and Weather\\.") -- Format identical ITV regions
		my _grep("([[:alnum:]])(\\ \\d{4}\\ Film\\.)", "\\1\\.\\2")
		my _lit(" \\a9 f190 B18jc\\SIANEL 4 CYMRU\\r", "S4C: ")
		my _grep("$\\r^\\d+\\.\\d+\\ Close\\.$", "")
		my _lit("  ", " ")
		my _grep("(\\. )\\r(\\d+\\.)", "\\1\\2") -- Close-up single-line listings
		-- Remove identical ITV regions
		process duplicate lines text 1 of text document 1 duplicates options {match mode:leaving_one, match pattern:"^ITV1\\:\\ \\d+\\.\\d+.+\\.$", match subpattern key:entire_match} output options {deleting duplicates:true}
		my _grep("\\Z\\r", "") -- Remove trailing blank line
	end tell
end regionalClean


-- Main processing function. Takes a set of files, weekday, boolean Sunday flag
on processListings(digitalFile, radioFile, regionalFile, terrestrialFile, _day, sun)
	set lastChannels to {"Film4", "Channel Five"}
	set shortChannels to {"BBC Three", "BBC Four"}
	
	script workhorse -- Closure
		-- Place digital and terrestrial listings
		on grepChannel(channelName, indesignLabel)
			-- Catch unset channel names (avoids repetition in call)
			if indesignLabel is "" then set indesignLabel to channelName
			
			if channelName is in shortChannels then
				-- Find a single block (i.e. for evening-only channels)
				set grepPattern to "^" & channelName & "\\r{2}((?:(?:[ [:alnum:][:punct:]]+)\\r)+)"
			else if channelName is in lastChannels then
				-- Find two blocks and doesn't expect a return at the end of the second block (i.e. at the end of the file)
				set grepPattern to "^" & channelName & "\\r{2}((?:(?:[ \\d\\w[:punct:]]+)\\r)+)\\r((?:(?:[ \\d\\w[:punct:]]+)\\r)+[ \\d\\w[:punct:]]+)"
			else
				-- Find two blocks, with a return as the last character
				set grepPattern to "^" & channelName & "\\r{2}((?:(?:[ \\d\\w[:punct:]]+)\\r)+)\\r((?:(?:[ \\d\\w[:punct:]]+)\\r)+)"
			end if
			
			tell application "TextWrangler"
				find grepPattern searching in text 1 of text document 1 options {search mode:grep, starting at top:true, case sensitive:false} without selecting match
				set grep1 to the grep substitution of "\\1" -- Short channels and AM listings
				set grep2 to the grep substitution of "\\2" -- PM listings
			end tell
			
			-- Set correct frame name with AM/PM, Sat/Sun permutations
			if channelName is in shortChannels then
				set firstFrame to indesignLabel
				set secondframe to ""
			else
				set firstFrame to indesignLabel & " AM"
				set secondframe to indesignLabel & " PM"
			end if
			
			if _day is "Saturday" then
				if sun is false then
					set firstFrame to (firstFrame & " (Sat)")
					if secondframe is not "" then set secondframe to (secondframe & " (Sat)")
				else
					set firstFrame to (firstFrame & " (Sun)")
					if secondframe is not "" then set secondframe to (secondframe & " (Sun)")
				end if
			end if
			
			-- Set the text in InDesign
			tell application "Adobe InDesign CS5.5"
				tell the front document
					set the contents of text frame firstFrame to grep1
					if secondframe is not "" then set the contents of text frame secondframe to grep2
				end tell
			end tell
		end grepChannel
		
		---- Place radio and regional listings
		on grepAll(radioRegional)
			-- Get all text
			tell application "TextWrangler"
				set theText to (the text of front text document)
			end tell
			
			-- Add Sat/Sun at weekend
			if _day is "Saturday" then
				if sun is false then
					set radioRegional to (radioRegional & " (Sat)")
				else
					set radioRegional to (radioRegional & " (Sun)")
				end if
			end if
			
			-- Set the text in InDesign
			tell application "Adobe InDesign CS5.5"
				tell the front document
					set the contents of text frame radioRegional to theText
				end tell
			end tell
		end grepAll
		
		-- Apply cleaning and setting functions to each listings file
		tell application "TextWrangler"
			open digitalFile
			-- Clean up
			my digitalClean()
			my digital_terrestrialShared()
			my basicClean()
			-- Get listings and pass to InDesign
			my grepChannel("BBC THREE", "BBC3")
			my grepChannel("BBC Four", "BBC4")
			my grepChannel("BBC Parliament", "BBCParl")
			my grepChannel("E4", "")
			my grepChannel("More4", "")
			my grepChannel("Film4", "")
			close the front document saving no
			
			open radioFile
			-- Clean up
			my radioClean()
			my basicClean()
			-- Get listings and pass to InDesign
			my grepAll("Radio")
			close the front document saving no
			
			open regionalFile
			-- Clean up
			my regionalClean()
			my basicClean()
			-- Get listings and pass to InDesign
			my grepAll("Regional")
			close the front document saving no
			
			open terrestrialFile
			-- Clean up
			my terrestrialClean()
			my digital_terrestrialShared()
			my basicClean()
			-- Get listings and pass to InDesign
			my grepChannel("BBC One", "BBC1")
			my grepChannel("BBC Two", "BBC2")
			my grepChannel("ITV1", "")
			my grepChannel("Channel 4", "C4")
			my grepChannel("Channel Five", "Five")
			close the front document saving no
		end tell
	end script
	run workhorse
end processListings