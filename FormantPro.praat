# _FormantPro.praat
# Version 1.4.3
# Last update: 2 Oct, 2020
# Written by:   Yi Xu (yi.xu@ucl.ac.uk); all rights reserved.

# SYNOPSIS: 
# 1) Automatically open each .wav file in a folder, manually label intervals; 
# 2) Save automatically trimmed (smoothed) formant contours (in Hz); 
# 3) Save time-normalized formants in Hz; 
# 4) Save time-normalized formants in Bark; 
# 5) Save continuous formant velocity (Hz/s); 
# 6) Save time-normalized formant velocity (Hz/s); 
# 7) Save mean, max and min formants, intensity, duration and peak formant velocity of labeled intervals;
# 8) Save results into ensemble files.
# 9) Save mean ensemble results averaged across repetitions.
# 9) Save mean normtime ensemble results averaged across speakers.

# INSTRUCTIONS:

# 1. put this script in the same folder as the .wav files to be analyzed, and launch Praat;

# 2. Select Open Praat Script... from the "Praat" menu (or the equivalent on pc);

# 3. Locate this script in the dialogue window and select it;

# 4. When the script window opens in Praat, select run from the Run menu (or use the key 
# shortcut command-r or control-r);

# 5. When dialogue window opens, check or uncheck the boxes in the dialogue window according to 
# your analysis needs. Set appropriate values in the text fields or simply use the default values.
# click OK and two windows will appear. 

# 6. The big window displays the waveform and the spectrogram together with optional 
# pitch tracks, formant tracks, vocal pulse markings, etc. But these are all for your 
# reference. Two label fields will be shown at the bottom of the window, and you can put any 
# labels you want to mark various boundaries, sound names, etc.

# 7. When you are done with manual correction and labeling, go to the upper-left hand corner 
# to activate the third, small window. Click "Continue" and the labels in the TextGrid together 
# with the data files corresponding to each sound will be saved; and a new window will appear,
# displaying the waveform and spectrogram of the next file. You can repeat this procedure
# until all the files in the folder are processed. Or you can stop at any point by clicking 
# the "Stop" button in the upper-left hand corner. Remember to note down the number of the 
# current file before stopping if there are many files in the folder and you want to 
# resume what you have been doing later on.

# 8. For each .wav file, various analysis results are saved into individual files as described
# below. If, however, you want to change certain analysis parameters after processing all
# sound files without having to do them one by one again, you can set the "Input File No" to
# 1 and uncheck the "Pause between sound files" button before pressing "OK".

# 9. After the analysis of all the individual files, you can put most of the analysis results 
# together into a number of ensemble files: 

# 1)	normtime_formant.txt
# 2)	normtime_barkformant.txt
# 3)	norm_actutime.txt
# 4)	normtime_formantvelocity.txt
# 5)	meanformant.txt
# 6)	maxformant.txt
# 7)	minformant.txt
# 8)	maxformantvelocity.txt
# 9) 	formant.txt
# 10) 	formant_velocity.txt
# 11)	duration.txt
# 12)	meanintensity.txt

# If your corpus consists of repeated trials, you can obtain average measurements over all the 
# repetitions of each unique condition. This can be done by changing the Nrepetitions in the 
# dialogue window to the repetition number in your corpus and then check Get ensemble files before 
# pressing the OK button. The following averaged files will be saved:

# 13)	mean_normtime_formant.txt
# 14)	mean_normtime_barkformant.txt
# 15)	mean_norm_actutime.txt
# 16)	mean_normtime_formantvelocity.txt
# 17)	mean_meanformant.txt
# 18)	mean_maxformant.txt
# 19)	mean_minformant.txt
# 20)	mean_maxformantvelocity.txt
# 21)	mean_duration.txt
# 22)	mean_meanintensity.txt

# You can also generate mean time-normalized contours averaged across speakers. To do this, first 
# create a text file (speaker_folders.txt) containing the speaker folder names arranged in a single 
# column. Then run FormantPro with the 4th task--Average across speakers--checked. The script will 
# read the mean time-normalized files from all the speaker folders, taking a cross-speaker average 
# of each value. The grand averages are saved in the files listed below. In the Start window, you 
# also need to tell FormantPro where the speaker folder file is. The default location is the current 
# directory: "./". If it is in an upper directory, you should enter "../"

# 23)	mean_normtime_formant_cross_speaker.txt
# 24)	mean_normtime_barkformant_cross_speaker.txt
# 25)	mean_normtime_formantvelocity_cross_speaker.txt
# 26)	mean_norm_actutime_cross_speaker.txt


form Start
	optionmenu Task: 1
		option 1. Interactive labeling
		option 2. Process all sounds without pause
		option 3. Get ensemble files
		option 4. Average across speakers
	integer Input_File_No 1
	integer Target_tier 1
	integer Nrepetitions 0
	boolean Ignore_extra_repetitions 0
	word Repetition_list repetition_list.txt
	boolean Use_repetition_list 0
	word TextGrid_extension .label
	word Sound_file_extension .wav
	comment Or .WAV, .aiff, .AIFF, .mp3, .MP3
	word Speaker_folder_location ./
	word Speaker_folder_file speaker_folders.txt
	comment Formant analysis options:	
		integer Max_number_of_formants 5
		integer Maximum_formant_(Hz) 5000 (= male; female = 5500)
		real Window_length_(s) 0.025
		real Time_step_(s) 0.025
		integer N._normalized_times_per_interval 20
		real Smoothing_window_width_(s) 0.10
endform

if task = 3
	printline 'newline$' 	Collecting data from all individual files. Please wait patiently...'newline$'
endif

if (praatVersion < 5107)
	printline Requires Praat version 5.1.07 or higher. Please upgrade your Praat version 
	exit
endif

npoints = n._normalized_times_per_interval

directory$ = "./"
Create Strings as file list... list 'directory$'*'sound_file_extension$'
numberOfFiles = Get number of strings
if !numberOfFiles
	Create Strings as file list... list 'directory$'*.WAV
	numberOfFiles = Get number of strings
endif
if !numberOfFiles and task != 4
	exit There are no sound files in the folder!
elsif task != 4
	Write to raw text file... 'directory$'FileList.txt
endif

if use_repetition_list
	Read Strings from raw text file... ./'repetition_list$'
	Rename... repetition_list
	nreplines = Get number of strings
endif

if nrepetitions > 0 and numberOfFiles mod nrepetitions and !ignore_extra_repetitions
	exit Averaging over repetitions failed. The total number of sound files cannot not be evenly divided by the number of repetitions. Please make sure to enter a correct Nrepetitions in the startup window.
endif
hasmeanstitle = 0
hasnormtime_formant = 0
hasnormtime = 0
hasnormactutime = 0
hasnormtime_barkformant = 0
hasformant = 0
hasformant_velocity = 0
hasnormtime_formantvelocity = 0
last_means_nrows = 0
found_interval = 0
number = input_File_No
repetition = 1
has_nrepetitions = 0

if task == 4
	call Cross_speaker_means mean_normtime_formant linear
	call Cross_speaker_means mean_normtime_formantvelocity linear
	call Cross_speaker_means mean_normtime_barkformant linear
	call Cross_speaker_means mean_norm_actutime linear
elsif task == 3 and use_repetition_list
	for current_file from 1 to nreplines
		select Strings repetition_list
		fileName$ = Get string... current_file
		if not has_nrepetitions
			nrepetitions = 0
			while not fileName$ == "" and not fileName$ == " "
				nrepetitions += 1
				fileName$ = Get string... current_file+nrepetitions
			endwhile
			has_nrepetitions = 1
		endif
		fileName$ = Get string... current_file
		if fileName$ == "" or fileName$ == " "
			has_nrepetitions = 0
		else
			name$ = fileName$ - ".wav" - ".WAV"
			printline Reading file 'name$'	number of repetitions = 'nrepetitions'
			if fileReadable ("'name$'.formantmeans")
				call All_means 'name$'
				call All_normtime_formants 'name$'
				call All_normtime_barkformants 'name$'
				call All_formantvelocity 'name$'
				call All_normtime_formantvelocity 'name$'
			endif
			if repetition >= nrepetitions
				repetition = 1
			else
				repetition += 1
			endif
		endif
	endfor
else	
	current_file = input_File_No
	while current_file <= numberOfFiles
		select Strings list
		fileName$ = Get string... current_file
		name$ = fileName$ - ".wav" - ".WAV"
		if task == 3
			rep$ = right$(name$, 1)
			if index_regex(rep$,"\D")
				rep$ = "0"
			endif

			if not (nrepetitions > 0 and 'rep$' > nrepetitions and ignore_extra_repetitions)
				printline Reading file 'name$'
				call All_formants 'name$'
				if fileReadable ("'name$'.formantmeans")
					call All_means 'name$'
					call All_normtime_formants 'name$'
					call All_normtime_barkformants 'name$'
					call All_formantvelocity 'name$'
					call All_normtime_formantvelocity 'name$'
				endif
			endif
			if nrepetitions > 0
				repetition = if repetition >= nrepetitions then 1 else repetition+1 fi
			endif
			current_file += 1
		else
			call Labeling 'fileName$'
#######################################################################################
			if task = 2
				current_file += 1
			else
				beginPause ("Press Done to save current results and exit")
					jump_to = current_file
					integer ("Jump to", jump_to)
				clicked2 = endPause ("Stop", "Back", "Next", "Jump", "Done", 3, 1)
				if clicked2 = 1
					plus TextGrid 'name$'
					Remove
					exit
				elsif clicked2 = 2
					current_file = if current_file > 1 then current_file-1 else 1 fi
				elsif clicked2 = 3
					if current_file < numberOfFiles
						current_file += 1
					else
						call Save 'directory$' 'name$'
						echo Current file number is 'current_file'.
						select Sound 'name$'
						Remove
						exit
					endif
				elsif clicked2 = 4
					current_file = if jump_to < numberOfFiles then jump_to else numberOfFiles fi
				elsif clicked2 = 5
					call Save 'directory$' 'name$'
					printline Current file number is 'current_file'.
					select Sound 'name$'
					Remove
					exit
				endif			
			endif
			call Save 'directory$' 'name$'
			select Sound 'name$'
			Remove
#######################################################################################
		endif
	endwhile
endif

if task == 3
	echo Ensemble files saved:
	printline 1)	normtime_formant.txt
	printline 2)	normtime_barkformant.txt
	printline 3)	norm_actutime.txt
	printline 4)	normtime_formantvelocity.txt
	printline 5)	meanformant.txt
	printline 6)	maxformant.txt
	printline 7)	minformant.txt
	printline 8)	maxformantvelocity.txt
	printline 9) 	formant.txt
	printline 10) 	formantvelocity.txt
	printline 11)	duration.txt
	printline 12)	meanintensity.txt
	if nrepetitions > 0 or use_repetition_list
		printline 13)	mean_normtime_formant.txt
		printline 14)	mean_normtime_barkformant.txt
		printline 15)	mean_norm_actutime.txt
		printline 16)	mean_normtime_formantvelocity.txt
		printline 17)	mean_meanformant.txt
		printline 18)	mean_maxformant.txt
		printline 19)	mean_minformant.txt
		printline 20)	mean_maxformantvelocity.txt
		printline 21)	mean_duration.txt
		printline 22)	mean_meanintensity.txt
	endif
endif

procedure Labeling file_name$ file_extension$
	Read from file... 'directory$''file_name$'
	name$ = file_name$ - ".wav" - ".WAV"
	labelfile$ = name$+"'TextGrid_extension$'"
	textgridfile$ = name$+".TextGrid"
	if fileReadable (labelfile$)
		Read from file... 'directory$''name$''TextGrid_extension$'
	elsif fileReadable (textgridfile$)
		Read from file... 'directory$''name$'.TextGrid
	else
		To TextGrid... "interval point" point
	endif
	plus Sound 'name$'
	Edit
endproc

procedure Save directory$ name$
	select TextGrid 'name$'
	nintervals = Get number of intervals... target_tier
	for m from 1 to nintervals
		select TextGrid 'name$'
		label$ = Get label of interval... target_tier m
		if label$ <> "" and label$ <> " " and label$ <> "\n" and label$ <> "'silence_marker$'" or nintervals = 1
			found_interval = 1
		endif
	endfor

	call Formants
	if found_interval
		select TableOfReal normtime_formant
		Write to headerless spreadsheet file... 'directory$''name$'.normtime_formant
		select TableOfReal normtime_barkformant
		Write to headerless spreadsheet file... 'directory$''name$'.normtime_barkformant
		select TableOfReal formant_velocity
		Write to headerless spreadsheet file... 'directory$''name$'.formant_velocity
		select TableOfReal normtime_formantvelocity
		Write to headerless spreadsheet file... 'directory$''name$'.normtime_formantvelocity
	endif
	Remove

	if found_interval
		call Means
		select TableOfReal means
		Write to headerless spreadsheet file... 'directory$''name$'.formantmeans
		plus FormantTier formant_velocity
		plus TableOfReal normtime_formant
		plus TableOfReal normtime_barkformant
		plus TableOfReal formant_velocity
		plus Intensity 'name$'
		Remove
		select TextGrid 'name$'
		Write to short text file... 'directory$''name$''TextGrid_extension$'
		Remove
	else
		select TextGrid 'name$'
		Write to short text file... 'directory$''name$''TextGrid_extension$'
		Remove
		printline
		printline 	No labeled intervals. Generating entire formant track instead!
		printline
		printline 	Note that this is not very useful for most purposes.
		printline
	endif
	select Formant 'name$'
	plus Formant barkformant
	plus FormantTier 'name$'
	plus FormantTier barkformant
	plus TableOfReal 'name$'
	Remove
	
endproc

procedure Formants
	select Sound 'name$'
	To Formant (burg)... time_step max_number_of_formants maximum_formant window_length 50
#	Using Praat's default Time step = 0.25 * 0.025 (window_length) = 0.00625 s
	Rename... 'name$'
	Down to FormantTier
	n = Get number of points
	for i from 1 to n
		time = Get time from index... i
		f1 = Get value at time... 1 time
		f2 = Get value at time... 2 time
		f3 = Get value at time... 3 time
		b1 = Get bandwidth at time... 1 time
		b2 = Get bandwidth at time... 2 time
		b3 = Get bandwidth at time... 3 time
		f2_3 = 0.5 * (f2 + f3)
		b2_3 = 0.5 * (b2 + b3)
		Remove point... i
		Add point... time 'f1' 'b1' 'f2' 'b2' 'f3' 'b3' 'f2_3' 'b2_3'
	endfor
	call Trimformants
	call Smooth_formants smoothing_window_width
	Down to TableOfReal... yes no
	Write to headerless spreadsheet file... 'directory$''name$'.formant
	select Formant 'name$'
	Copy... barkformant
	Formula (frequencies)... 7 * ln (self/650+sqrt(1+(self/650)^2))		; bark
	Down to FormantTier
	n = Get number of points
	for i from 1 to n
		time = Get time from index... i
		f1 = Get value at time... 1 time
		f2 = Get value at time... 2 time
		f3 = Get value at time... 3 time
		b1 = Get bandwidth at time... 1 time
		b2 = Get bandwidth at time... 2 time
		b3 = Get bandwidth at time... 3 time
		f2_3 = 0.5 * (f2 + f3)
		b2_3 = 0.5 * (b2 + b3)
		Remove point... i
		Add point... time 'f1' 'b1' 'f2' 'b2' 'f3' 'b3' 'f2_3' 'b2_3'
	endfor
	call Trimformants
	call Smooth_formants smoothing_window_width
	Create TableOfReal... normtime_formant 1 5
	Set column label (index)... 1 Time
	Set column label (index)... 2 F1
	Set column label (index)... 3 F2
	Set column label (index)... 4 F3
	Set column label (index)... 5 F2_3
	Create TableOfReal... normtime_barkformant 1 5
	Set column label (index)... 1 Time
	Set column label (index)... 2 F1
	Set column label (index)... 3 F2
	Set column label (index)... 4 F3
	Set column label (index)... 5 F2_3
	Create TableOfReal... normtime_formantvelocity 1 5
	Set column label (index)... 1 Time
	Set column label (index)... 2 F1
	Set column label (index)... 3 F2
	Set column label (index)... 4 F3
	Set column label (index)... 5 F2_3
	if found_interval
		call Differentiate_formant 'name$'
	endif

	interval = 0
	found_interval = 0
	nrows = 0
	for m from 1 to nintervals
		select TextGrid 'name$'
		label$ = Get label of interval... target_tier m
		if not label$ = ""
			start = Get starting point... target_tier m
			end = Get end point... target_tier m
			if found_interval = 0
				found_interval = 1
				select FormantTier 'name$'
				firstime = start
			endif
			call Normalize_formant 'name$' normtime_formant
			call Normalize_formant barkformant normtime_barkformant
			call Normalize_formant formant_velocity normtime_formantvelocity
			interval = interval + 1
		endif
	endfor
	if nrows > 1
		select TableOfReal normtime_formant
		nrows = Get number of rows
		Remove row (index)... nrows
		select TableOfReal normtime_barkformant
		Remove row (index)... nrows
		select TableOfReal normtime_formantvelocity
		Remove row (index)... nrows
	endif
endproc

procedure Normalize_formant formanttier$ tableOfReal$
	duration = end - start
	for x from 0 to npoints-1
		normtime = x / npoints
		select FormantTier 'formanttier$'
		f1 = Get value at time... 1 normtime*duration+start
		f2 = Get value at time... 2 normtime*duration+start
		f3 = Get value at time... 3 normtime*duration+start
		f2_3 = Get value at time... 4 normtime*duration+start
		select TableOfReal 'tableOfReal$'
		nrows = Get number of rows
		Set value... nrows 1 normtime*duration+start-firstime	
		Set value... nrows 2 f1
		Set value... nrows 3 f2
		Set value... nrows 4 f3
		Set value... nrows 5 f2_3
		Set row label (index)... nrows 'label$'
		Insert row (index)... nrows + 1
	endfor
endproc

procedure Trimformants
	maxbump = 0.01
	maxedge = 0.0
	maxgap = 0.033
	n = Get number of points
	
	tfirst = Get time from index... 1
	tlast = Get time from index... n
	for k from 1 to 3
		for m from 1 to 4
			call Trimformant m
		endfor
	endfor
endproc

procedure Trimformant m
	for i from 2 to n-1
		tleft = Get time from index... i-1
		tmid = Get time from index... i
		tright = Get time from index... i+1
		gap1 = tmid - tleft
		gap2 = tright - tmid
		left = Get value at time... m tleft
		mid = Get value at time... m tmid
		right = Get value at time... m tright
		f1 = Get value at time... 1 tmid
		f2 = Get value at time... 2 tmid
		f3 = Get value at time... 3 tmid
		f4 = Get value at time... 4 tmid
# when m = 4, f4 = f2_3
		b1 = Get bandwidth at time... 1 tmid
		b2 = Get bandwidth at time... 2 tmid
		b3 = Get bandwidth at time... 3 tmid
		b4 = Get bandwidth at time... 4 tmid
		diff1 = mid - left
		diff2 = mid - right
		if diff1 > maxbump and diff2 > maxedge and gap1 < maxgap and gap2 < maxgap
		... or diff2 > maxbump and diff1 > maxedge and gap1 < maxgap and gap2 < maxgap
			Remove point... i
			f'm' = left+(tmid-tleft)/(tright-tleft)*(right-left)
			Add point... tmid 'f1' 'b1' 'f2' 'b2' 'f3' 'b3' 'f4' 'b4'
		endif
		if diff1 > maxbump and gap2 >= maxgap
			Remove point... i
			f'm' = left + maxbump
			Add point... tmid 'f1' 'b1' 'f2' 'b2' 'f3' 'b3' 'f4' 'b4'
		endif
		if diff2 > maxbump and gap1 >= maxgap
			Remove point... i
			f'm' = right + maxbump
			Add point... tmid 'f1' 'b1' 'f2' 'b2' 'f3' 'b3' 'f4' 'b4'
		endif

		diff1 = left - mid
		diff2 = right - mid
		if diff1 > maxbump and diff2 > maxedge and gap1 < maxgap and gap2 < maxgap
		... or diff2 > maxbump and diff1 > maxedge and gap1 < maxgap and gap2 < maxgap
			Remove point... i
			f'm' = left+(tmid-tleft)/(tright-tleft)*(right-left)
			Add point... tmid 'f1' 'b1' 'f2' 'b2' 'f3' 'b3' 'f4' 'b4'
		endif
		if diff1 > maxbump and gap2 >= maxgap
			Remove point... i
			f'm' = left - maxbump
			Add point... tmid 'f1' 'b1' 'f2' 'b2' 'f3' 'b3' 'f4' 'b4'
		endif
		if diff2 > maxbump and gap1 >= maxgap
			Remove point... i
			f'm' = right - maxbump
			Add point... tmid 'f1' 'b1' 'f2' 'b2' 'f3' 'b3' 'f4' 'b4'
		endif
	endfor
endproc

procedure Smooth_formants smoothing_window_width
	formantStart = Get start time
	formantEnd = Get end time
	width = smoothing_window_width div 0.00625
	
	for j from 1 to width							; make a triangular window of size = width 
		if j < width / 2 + 0.5
			weight'j' = j
		else 
			weight'j' = width - j + 1
		endif
	endfor

	select FormantTier 'name$'
	smooth_end = Get number of points

	for i from 1 to width / 2						; smooth initial points: 0 to width/2 - 1 
	    n = 0.0
		smoothF1 = 0.0
		smoothF2 = 0.0
		smoothF3 = 0.0
		smoothF2_3 = 0.0
		smoothb1 = 0.0
		smoothb2 = 0.0
		smoothb3 = 0.0
		smoothb2_3 = 0.0
		select FormantTier 'name$'
		formant_time = Get time from index... i
	    for j from 1 to width/2 + i					; window size = width/2 to width - 1
	    	j = 'j:0'
			window_time = Get time from index... j
	    	rawF1 = Get value at time... 1 window_time
	    	rawF2 = Get value at time... 2 window_time
	    	rawF3 = Get value at time... 3 window_time
	    	rawF2_3 = Get value at time... 4 window_time
			rawb1 = Get bandwidth at time... 1 window_time
			rawb2 = Get bandwidth at time... 2 window_time
			rawb3 = Get bandwidth at time... 3 window_time
			rawb2_3 = Get bandwidth at time... 4 window_time
	    	index = width / 2 + j - i
	    	index = 'index:0'
			smoothF1 += weight'index' * rawF1
			smoothF2 += weight'index' * rawF2
			smoothF3 += weight'index' * rawF3
			smoothF2_3 += weight'index' * rawF2_3
			smoothb1 += weight'index' * rawb1
			smoothb2 += weight'index' * rawb2
			smoothb3 += weight'index' * rawb3
			smoothb2_3 += weight'index' * rawb2_3
			n += weight'index'
	    endfor
		smoothF1 /= n
		smoothF2 /= n
		smoothF3 /= n
		smoothF2_3 /= n
		smoothb1 /= n
		smoothb2 /= n
		smoothb3 /= n
		smoothb2_3 /= n
		select FormantTier 'name$'
		Add point... formant_time 'smoothF1' 'smoothb1' 'smoothF2' 'smoothb2' 'smoothF3' 'smoothb3' 'smoothF2_3' 'smoothb2_3'
	endfor
	
	for i from width/2 to smooth_end - width/2				; smooth from width/2 to end-width/2
		n = 0
		smoothF1 = 0.0
		smoothF2 = 0.0
		smoothF3 = 0.0
		smoothF2_3 = 0.0
		smoothb1 = 0.0
		smoothb2 = 0.0
		smoothb3 = 0.0
		smoothb2_3 = 0.0
		select FormantTier 'name$'
		norm_actutime = Get time from index... i
		for j from 1 to width
			window_time = Get time from index... i-width/2+j
	    	rawF1 = Get value at time... 1 window_time
	    	rawF2 = Get value at time... 2 window_time
	    	rawF3 = Get value at time... 3 window_time
			rawb1 = Get bandwidth at time... 1 window_time
			rawb2 = Get bandwidth at time... 2 window_time
			rawb3 = Get bandwidth at time... 3 window_time
			rawb2_3 = Get bandwidth at time... 4 window_time
			smoothF1 += weight'j' * rawF1
			smoothF2 += weight'j' * rawF2
			smoothF3 += weight'j' * rawF3
			smoothb1 += weight'index' * rawb1
			smoothb2 += weight'index' * rawb2
			smoothb3 += weight'index' * rawb3
			smoothb2_3 += weight'index' * rawb2_3
			n += weight'j'
		endfor
		smoothF1 /= n
		smoothF2 /= n
		smoothF3 /= n
		smoothF2_3 /= n
		smoothb1 /= n
		smoothb2 /= n
		smoothb3 /= n
		smoothb2_3 /= n
		select FormantTier 'name$'
		Add point... formant_time 'smoothF1' 'smoothb1' 'smoothF2' 'smoothb2' 'smoothF3' 'smoothb3' 'smoothF2_3' 'smoothb2_3'
	endfor
	
	i = width/2
	while i > 0										; smooth final points: end - width/2 to end
		n = 0.0
		smoothF1 = 0.0
		smoothF2 = 0.0
		smoothF3 = 0.0
		smoothF2_3 = 0.0
		smoothb1 = 0.0
		smoothb2 = 0.0
		smoothb3 = 0.0
		smoothb2_3 = 0.0
		select FormantTier 'name$'
		norm_actutime = Get time from index... smooth_end-i
		j = width/2 + i
		j = 'j:0'
		while j > 1									; window size = width - 1 to width/2 
	    	rawF1 = Get value at time... 1 window_time
	    	rawF2 = Get value at time... 2 window_time
	    	rawF3 = Get value at time... 3 window_time
			rawb1 = Get bandwidth at time... 1 window_time
			rawb2 = Get bandwidth at time... 2 window_time
			rawb3 = Get bandwidth at time... 3 window_time
			rawb2_3 = Get bandwidth at time... 4 window_time
	    	index = width/2+i-j + 1
	    	index = 'index:0'
			smoothF1 += weight'index' * rawF1
			smoothF2 += weight'index' * rawF2
			smoothF3 += weight'index' * rawF3
			smoothb1 += weight'index' * rawb1
			smoothb2 += weight'index' * rawb2
			smoothb3 += weight'index' * rawb3
			smoothb2_3 += weight'index' * rawb2_3
			n += weight'index'
			j -= 1
		endwhile
		smoothF1 /= n
		smoothF2 /= n
		smoothF3 /= n
		smoothF2_3 /= n
		smoothb1 /= n
		smoothb2 /= n
		smoothb3 /= n
		smoothb2_3 /= n
		select FormantTier 'name$'
		Add point... formant_time 'smoothF1' 'smoothb1' 'smoothF2' 'smoothb2' 'smoothF3' 'smoothb3' 'smoothF2_3' 'smoothb2_3'
		i -= 1
	endwhile
endproc

procedure Differentiate_formant	formanttier$
	select Formant 'name$'
	timestep = Get time step
	Create FormantTier... formant_velocity 0 1
	Create TableOfReal... formant_velocity 1 5
	Set column label (index)... 1 Time
	Set column label (index)... 2 F1_velocity (Hz/s)
	Set column label (index)... 3 F2_velocity (Hz/s)
	Set column label (index)... 4 F3_velocity (Hz/s)
	Set column label (index)... 5 F2_3_velocity (Hz/s)
	
	select TextGrid 'name$'
	nintervals = Get number of intervals... target_tier
	nrows = 0
	for m from 1 to nintervals
		select TextGrid 'name$'
		label$ = Get label of interval... target_tier m
		if not label$ = ""
			start = Get starting point... target_tier m
			end = Get end point... target_tier m
			select FormantTier 'formanttier$'
			index_first = Get high index from time... start
			index_last = Get low index from time... end
			for x from index_first to index_last - 1
				if x = index_first or x = index_last - 1
					x2 = x + 1
				else
					x2 = x + 2
				endif
				time_step =  timestep * (x2 - x)
				select FormantTier 'formanttier$'
				time1 = Get time from index... x
				time2 = Get time from index... x2
	   		 	f1_1 = Get value at time... 1 time1
	   		 	f1_2 = Get value at time... 1 time2
	   		 	f2_1 = Get value at time... 2 time1
	   		 	f2_2 = Get value at time... 2 time2
	   		 	f3_1 = Get value at time... 3 time1
	   		 	f3_2 = Get value at time... 3 time2
	   		 	f2_3_1 = Get value at time... 4 time1
	   		 	f2_3_2 = Get value at time... 4 time2
				f1_velocity = (f1_2 - f1_1) / time_step
				f2_velocity = (f2_2 - f2_1) / time_step
				f3_velocity = (f3_2 - f3_1) / time_step
				f2_3_velocity = (f2_3_2 - f2_3_1) / time_step
				velocity_time = 0.5 * (time1 + time2)
				select FormantTier formant_velocity
				Add point... velocity_time 'f1_velocity' 0 'f2_velocity' 0 'f3_velocity' 0 'f2_3_velocity' 0
				select TableOfReal formant_velocity
				nrows = Get number of rows
				Set value... nrows 1 velocity_time
				Set value... nrows 2 f1_velocity
				Set value... nrows 3 f2_velocity
				Set value... nrows 4 f3_velocity
				Set value... nrows 5 f2_3_velocity
				Set row label (index)... nrows 'label$'
				Insert row (index)... nrows + 1
			endfor
		endif
	endfor
	select TableOfReal formant_velocity
	nocheck Remove row (index)... nrows + 1
endproc

procedure Means
	select Sound 'name$'
	To Intensity... 100 0 yes

	select TextGrid 'name$'
	nintervals = Get number of intervals... target_tier
	Create TableOfReal... means 1 18
	Set column label (index)... 1 mean_F1
	Set column label (index)... 2 mean_F2
	Set column label (index)... 3 mean_F3
	Set column label (index)... 4 mean_F2_3
	Set column label (index)... 5 max_F1
	Set column label (index)... 6 max_F2
	Set column label (index)... 7 max_F3
	Set column label (index)... 8 max_F2_3
	Set column label (index)... 9 min_F1
	Set column label (index)... 10 min_F2
	Set column label (index)... 11 min_F3
	Set column label (index)... 12 min_F2_3
	Set column label (index)... 13 max_V1
	Set column label (index)... 14 max_V2
	Set column label (index)... 15 max_V3
	Set column label (index)... 16 max_V2_3
	Set column label (index)... 17 duration
	Set column label (index)... 18 mean_intensity
	interval = 0
	for m from 1 to nintervals
		select TextGrid 'name$'
		label$ = Get label of interval... target_tier m
		if not label$ = ""
			interval = interval + 1
			start = Get starting point... target_tier m
			end = Get end point... target_tier m
			duration = 1000 * (end - start)
			select TableOfReal means
			Set row label (index)... interval 'label$'
			select FormantTier 'name$'
			index1 = Get high index from time... start
			index2 = Get low index from time... end
			for j from 1 to 3
				meanformant'j' = 0
			endfor
			for j from 1 to 3
				meanF'j' = 0
				maxF'j' = 0
				minF'j' = 32767
				maxV'j' = 0
				for i from index1 to index2
					select FormantTier 'name$'
					time = Get time from index... i
					f = Get value at time... j time
					meanF'j' += f
					if f <> undefined and f > maxF'j'
						maxF'j' = f
					endif
					if f <> undefined and f < minF'j'
						minF'j' = f
					endif
					select FormantTier formant_velocity
					v = Get value at time... j time
					if v <> undefined and abs(v) > abs(maxV'j')
						maxV'j' = v
					endif
				endfor
				meanF'j' /= index2 - index1 + 1
			endfor

			meanF2_3 = 0
			maxF2_3 = 0
			minF2_3 = 32767
			maxV2_3 = 0
			for i from index1 to index2
				select FormantTier 'name$'
				time = Get time from index... i
				f = Get value at time... 4 time
				meanF2_3 += f
				if f > maxF2_3
					maxF2_3 = f
				endif
				if f < minF2_3
					minF2_3 = f
				endif
				select FormantTier formant_velocity
				v = Get value at time... j time
				if abs(v) > abs(maxV2_3)
					maxV2_3 = v
				endif
			endfor
			meanF2_3 /= index2 - index1 + 1

			select Intensity 'name$'
			intensity = Get mean... start end energy

			select TableOfReal means
			Set value... interval 1 meanF1
			Set value... interval 2 meanF2
			Set value... interval 3 meanF3
			Set value... interval 4 meanF2_3
			Set value... interval 5 maxF1
			Set value... interval 6 maxF2
			Set value... interval 7 maxF3
			Set value... interval 8 maxF2_3
			Set value... interval 9 minF1
			Set value... interval 10 minF2
			Set value... interval 11 minF3
			Set value... interval 12 minF2_3
			Set value... interval 13 maxV1
			Set value... interval 14 maxV2
			Set value... interval 15 maxV3
			Set value... interval 16 maxV2_3
			Set value... interval 17 duration
			Set value... interval 18 intensity
			Insert row (index)... interval + 1
		endif
	endfor
	select TableOfReal means
	nrows = Get number of rows
	if nrows > 1
		Remove row (index)... nrows
	endif
endproc

procedure All_means file_name$
	Read TableOfReal from headerless spreadsheet file... 'directory$''name$'.formantmeans
	nrows = Get number of rows
	if nrepetitions > 0 and repetition == 1
		for n from 1 to nrows
			mean_meanF1'n' = 0
			mean_meanF2'n' = 0
			mean_meanF3'n' = 0
			mean_meanF2_3'n' = 0
			mean_maxF1'n' = 0
			mean_maxF2'n' = 0
			mean_maxF3'n' = 0
			mean_maxF2_3'n' = 0
			mean_minF1'n' = 0
			mean_minF2'n' = 0
			mean_minF3'n' = 0
			mean_minF2_3'n' = 0
			mean_maxV1'n' = 0
			mean_maxV2'n' = 0
			mean_maxV3'n' = 0
			mean_maxV2_3'n' = 0
			mean_duration'n' = 0
			mean_meanintensity'n' = 0
		endfor
		last_means_nrows = nrows
	endif
	
	title_line$ = "Filename"
	meanF1_line$ = "_"+name$+"_F1"
	meanF2_line$ = "_"+name$+"_F2"
	meanF3_line$ = "_"+name$+"_F3"
	meanF2_3_line$ = "_"+name$+"_F2_3"
	maxF1_line$ = "_"+name$+"_F1"
	maxF2_line$ = "_"+name$+"_F2"
	maxF3_line$ = "_"+name$+"_F3"
	maxF2_3_line$ = "_"+name$+"_F2_3"
	minF1_line$ = "_"+name$+"_F1"
	minF2_line$ = "_"+name$+"_F2"
	minF3_line$ = "_"+name$+"_F3"
	minF2_3_line$ = "_"+name$+"_F2_3"
	maxV1_line$ = "_"+name$+"_V1"
	maxV2_line$ = "_"+name$+"_V2"
	maxV3_line$ = "_"+name$+"_V3"
	maxV2_3_line$ = "_"+name$+"_V2_3"
	duration_line$ = "_"+name$
	intensity_line$ = "_"+name$
	
	if nrepetitions > 0 
		shortname$ = left$(name$,length(name$)-1)
		mean_meanF1_line$ = "_"+shortname$+"_F1"
		mean_meanF2_line$ = "_"+shortname$+"_F2"
		mean_meanF3_line$ = "_"+shortname$+"_F3"
		mean_meanF2_3_line$ = "_"+shortname$+"_F2_3"
		mean_maxF1_line$ = "_"+shortname$+"_F1"
		mean_maxF2_line$ = "_"+shortname$+"_F2"
		mean_maxF3_line$ = "_"+shortname$+"_F3"
		mean_maxF2_3_line$ = "_"+shortname$+"_F2_3"
		mean_minF1_line$ = "_"+shortname$+"_F1"
		mean_minF2_line$ = "_"+shortname$+"_F2"
		mean_minF3_line$ = "_"+shortname$+"_F3"
		mean_minF2_3_line$ = "_"+shortname$+"_F2_3"
		mean_maxV1_line$ = "_"+shortname$+"_V1"
		mean_maxV2_line$ = "_"+shortname$+"_V2"
		mean_maxV3_line$ = "_"+shortname$+"_V3"
		mean_maxV2_3_line$ = "_"+shortname$+"_V2_3"
		mean_duration_line$ = "_"+shortname$
		mean_meanintensity_line$ = "_"+shortname$
		last_means_nrows = nrows
	endif

	for n from 1 to nrows
		if !hasmeanstitle
			rowname$ = Get row label... n
			title_line$ = "'title_line$'	'rowname$'"
		endif
		meanF1 = Get value... n 1
		meanF1_line$ = "'meanF1_line$'	'meanF1'"
		meanF2 = Get value... n 2
		meanF2_line$ = "'meanF2_line$'	'meanF2'"
		meanF3 = Get value... n 3
		meanF3_line$ = "'meanF3_line$'	'meanF3'"
		meanF2_3 = Get value... n 4
		meanF2_3_line$ = "'meanF2_3_line$'	'meanF2_3'"
		maxF1 = Get value... n 5
		maxF1_line$ = "'maxF1_line$'	'maxF1'"
		maxF2 = Get value... n 6
		maxF2_line$ = "'maxF2_line$'	'maxF2'"
		maxF3 = Get value... n 7
		maxF3_line$ = "'maxF3_line$'	'maxF3'"
		maxF2_3 = Get value... n 8
		maxF2_3_line$ = "'maxF2_3_line$'	'maxF2_3'"
		minF1 = Get value... n 9
		minF1_line$ = "'minF1_line$'	'minF1'"
		minF2 = Get value... n 10
		minF2_line$ = "'minF2_line$'	'minF2'"
		minF3 = Get value... n 11
		minF3_line$ = "'minF3_line$'	'minF3'"
		minF2_3 = Get value... n 12
		minF2_3_line$ = "'minF2_3_line$'	'minF2_3'"
		maxV1 = Get value... n 13
		maxV1_line$ = "'maxV1_line$'	'maxV1'"
		maxV2 = Get value... n 14
		maxV2_line$ = "'maxV2_line$'	'maxV2'"
		maxV3 = Get value... n 15
		maxV3_line$ = "'maxV3_line$'	'maxV3'"
		maxV2_3 = Get value... n 16
		maxV2_3_line$ = "'maxV2_3_line$'	'maxV2_3'"
		duration = Get value... n 17
		duration_line$ = "'duration_line$'	'duration'"
		intensity = Get value... n 18
		intensity_line$ = "'intensity_line$'	'intensity'"
		if nrepetitions > 0 
			if repetition <= nrepetitions
				mean_meanF1'n' += meanF1
				mean_meanF2'n' += meanF2
				mean_meanF3'n' += meanF3
				mean_meanF2_3'n' += meanF2_3
				mean_maxF1'n' += maxF1
				mean_maxF2'n' += maxF2
				mean_maxF3'n' += maxF3
				mean_maxF2_3'n' += maxF2_3
				mean_minF1'n' += minF1
				mean_minF2'n' += minF2
				mean_minF3'n' += minF3
				mean_minF2_3'n' += minF2_3
				mean_maxV1'n' += maxV1
				mean_maxV2'n' += maxV2
				mean_maxV3'n' += maxV3
				mean_maxV2_3'n' += maxV2_3
				mean_duration'n' += duration
				mean_meanintensity'n' += intensity
			endif

			if repetition == nrepetitions
				mean_meanF1 = mean_meanF1'n'/nrepetitions
				mean_meanF2 = mean_meanF2'n'/nrepetitions
				mean_meanF3 = mean_meanF3'n'/nrepetitions
				mean_meanF2_3 = mean_meanF2_3'n'/nrepetitions
				mean_maxF1 = mean_maxF1'n'/nrepetitions
				mean_maxF2 = mean_maxF2'n'/nrepetitions
				mean_maxF3 = mean_maxF3'n'/nrepetitions
				mean_maxF2_3 = mean_maxF2_3'n'/nrepetitions
				mean_minF1 = mean_minF1'n'/nrepetitions
				mean_minF2 = mean_minF2'n'/nrepetitions
				mean_minF3 = mean_minF3'n'/nrepetitions
				mean_minF2_3 = mean_minF2_3'n'/nrepetitions
				mean_maxV1 = mean_maxV1'n'/nrepetitions
				mean_maxV2 = mean_maxV2'n'/nrepetitions
				mean_maxV3 = mean_maxV3'n'/nrepetitions
				mean_maxV2_3 = mean_maxV2_3'n'/nrepetitions
				mean_duration = mean_duration'n'/nrepetitions
				mean_meanintensity = mean_meanintensity'n'/nrepetitions
				mean_meanF1_line$ = "'mean_meanF1_line$'	'mean_meanF1'"
				mean_meanF2_line$ = "'mean_meanF2_line$'	'mean_meanF2'"
				mean_meanF3_line$ = "'mean_meanF3_line$'	'mean_meanF3'"
				mean_meanF2_3_line$ = "'mean_meanF2_3_line$'	'mean_meanF2_3'"
				mean_maxF1_line$ = "'mean_maxF1_line$'	'mean_maxF1'"
				mean_maxF2_line$ = "'mean_maxF2_line$'	'mean_maxF2'"
				mean_maxF3_line$ = "'mean_maxF3_line$'	'mean_maxF3'"
				mean_maxF2_3_line$ = "'mean_maxF2_3_line$'	'mean_maxF2_3'"
				mean_minF1_line$ = "'mean_minF1_line$'	'mean_minF1'"
				mean_minF2_line$ = "'mean_minF2_line$'	'mean_minF2'"
				mean_minF3_line$ = "'mean_minF3_line$'	'mean_minF3'"
				mean_minF2_3_line$ = "'mean_minF2_3_line$'	'mean_minF2_3'"
				mean_maxV1_line$ = "'mean_maxV1_line$'	'mean_maxV1'"
				mean_maxV2_line$ = "'mean_maxV2_line$'	'mean_maxV2'"
				mean_maxV3_line$ = "'mean_maxV3_line$'	'mean_maxV3'"
				mean_maxV2_3_line$ = "'mean_maxV2_3_line$'	'mean_maxV2_3'"
				mean_duration_line$ = "'mean_duration_line$'	'mean_duration'"
				mean_meanintensity_line$ = "'mean_meanintensity_line$'	'mean_meanintensity'"
			endif
		endif
	endfor
	if !hasmeanstitle
		filedelete meanformant.txt
		filedelete maxformant.txt
		filedelete minformant.txt
		filedelete maxformantvelocity.txt
		filedelete duration.txt
		filedelete meanintensity.txt
		title_line$ = "'title_line$''newline$'"
		fileappend meanformant.txt 'title_line$'
		fileappend maxformant.txt 'title_line$'
		fileappend minformant.txt 'title_line$'
		fileappend maxformantvelocity.txt 'title_line$'
		fileappend duration.txt 'title_line$'
		fileappend meanintensity.txt 'title_line$'
		if nrepetitions > 0
			filedelete mean_meanformant.txt
			filedelete mean_maxformant.txt
			filedelete mean_minformant.txt
			filedelete mean_maxformantvelocity.txt
			filedelete mean_duration.txt
			filedelete mean_meanintensity.txt
			fileappend mean_meanformant.txt 'title_line$'
			fileappend mean_maxformant.txt 'title_line$'
			fileappend mean_minformant.txt 'title_line$'
			fileappend mean_maxformantvelocity.txt 'title_line$'
			fileappend mean_duration.txt 'title_line$'
			fileappend mean_meanintensity.txt 'title_line$'
		endif
		hasmeanstitle = 1
	endif
	fileappend "meanformant.txt" 'meanF1_line$''newline$'
	fileappend "meanformant.txt" 'meanF2_line$''newline$'
	fileappend "meanformant.txt" 'meanF3_line$''newline$'
	fileappend "meanformant.txt" 'meanF2_3_line$''newline$'
	fileappend "maxformant.txt" 'maxF1_line$''newline$'
	fileappend "maxformant.txt" 'maxF2_line$''newline$'
	fileappend "maxformant.txt" 'maxF3_line$''newline$'
	fileappend "maxformant.txt" 'maxF2_3_line$''newline$'
	fileappend "minformant.txt" 'minF1_line$''newline$'
	fileappend "minformant.txt" 'minF2_line$''newline$'
	fileappend "minformant.txt" 'minF3_line$''newline$'
	fileappend "minformant.txt" 'minF2_3_line$''newline$'
	fileappend "maxformantvelocity.txt" 'maxV1_line$''newline$'
	fileappend "maxformantvelocity.txt" 'maxV2_line$''newline$'
	fileappend "maxformantvelocity.txt" 'maxV3_line$''newline$'
	fileappend "maxformantvelocity.txt" 'maxV2_3_line$''newline$'
	fileappend "duration.txt" 'duration_line$''newline$'
	fileappend "meanintensity.txt" 'intensity_line$''newline$'

	if nrepetitions > 0 and repetition == nrepetitions
		fileappend "mean_meanformant.txt" 'mean_meanF1_line$''newline$'
		fileappend "mean_meanformant.txt" 'mean_meanF2_line$''newline$'
		fileappend "mean_meanformant.txt" 'mean_meanF3_line$''newline$'
		fileappend "mean_meanformant.txt" 'mean_meanF2_3_line$''newline$'
		fileappend "mean_maxformant.txt" 'mean_maxF1_line$''newline$'
		fileappend "mean_maxformant.txt" 'mean_maxF2_line$''newline$'
		fileappend "mean_maxformant.txt" 'mean_maxF3_line$''newline$'
		fileappend "mean_maxformant.txt" 'mean_maxF2_3_line$''newline$'
		fileappend "mean_minformant.txt" 'mean_minF1_line$''newline$'
		fileappend "mean_minformant.txt" 'mean_minF2_line$''newline$'
		fileappend "mean_minformant.txt" 'mean_minF3_line$''newline$'
		fileappend "mean_minformant.txt" 'mean_minF2_3_line$''newline$'
		fileappend "mean_maxformantvelocity.txt" 'mean_maxV1_line$''newline$'
		fileappend "mean_maxformantvelocity.txt" 'mean_maxV2_line$''newline$'
		fileappend "mean_maxformantvelocity.txt" 'mean_maxV3_line$''newline$'
		fileappend "mean_maxformantvelocity.txt" 'mean_maxV2_3_line$''newline$'
		fileappend "mean_duration.txt" 'mean_duration_line$''newline$'
		fileappend "mean_meanintensity.txt" 'mean_meanintensity_line$''newline$'
	endif
	Remove
endproc

procedure All_normtime_formants file_name$
	Read TableOfReal from headerless spreadsheet file... 'directory$''name$'.normtime_formant
	nrows = Get number of rows
	normtime = 0
	if nrepetitions > 0 and repetition == 1
		for n from 1 to nrows
			mean_actutime'n' = 0
			mean_normF1'n' = 0
			mean_normF2'n' = 0
			mean_normF3'n' = 0
			mean_normF2_3'n' = 0
		endfor
	endif
	title_line$ = "Normtime"
	time_line$ = "_"+name$
	f1_line$ = name$+"_F1"
	f2_line$ = name$+"_F2"
	f3_line$ = name$+"_F3"
	f2_3_line$ = name$+"_F2_3"
	if nrepetitions > 0
		mean_actutime_line$ = "_"+shortname$
		mean_normF1_line$ = "_"+shortname$+"_F1"
		mean_normF2_line$ = "_"+shortname$+"_F2"
		mean_normF3_line$ = "_"+shortname$+"_F3"
		mean_normF2_3_line$ = "_"+shortname$+"_F2_3"
	endif
	for n from 1 to nrows
		if !hasnormtime_formant
			normtime = normtime + 1
			title_line$ = "'title_line$'	'normtime'"
		endif
		time = Get value... n 1
		f1 = Get value... n 2
		f2 = Get value... n 3
		f3 = Get value... n 4
		f2_3 = Get value... n 5
		time_line$ = "'time_line$'	'time'"
		f1_line$ = "'f1_line$'	'f1'"
		f2_line$ = "'f2_line$'	'f2'"
		f3_line$ = "'f3_line$'	'f3'"
		f2_3_line$ = "'f2_3_line$'	'f2_3'"

		if nrepetitions > 0 
			nrows_meanformant = Get number of rows
			if repetition <= nrepetitions
				mean_actutime'n' += time
				mean_normF1'n' += f1
				mean_normF2'n' += f2
				mean_normF3'n' += f3
				mean_normF2_3'n' += f2_3
			endif
			if repetition == nrepetitions
				mean_actutime = mean_actutime'n'/nrepetitions
				mean_normF1 = mean_normF1'n'/nrepetitions
				mean_normF2 = mean_normF2'n'/nrepetitions
				mean_normF3 = mean_normF3'n'/nrepetitions
				mean_normF2_3 = mean_normF2_3'n'/nrepetitions
				mean_actutime_line$ = "'mean_actutime_line$'	'mean_actutime'"
				mean_normF1_line$ = "'mean_normF1_line$'	'mean_normF1'"
				mean_normF2_line$ = "'mean_normF2_line$'	'mean_normF2'"
				mean_normF3_line$ = "'mean_normF3_line$'	'mean_normF3'"
				mean_normF2_3_line$ = "'mean_normF2_3_line$'	'mean_normF2_3'"
			endif
		endif
	endfor
	if !hasnormtime_formant
		filedelete norm_actutime.txt
		fileappend norm_actutime.txt 'title_line$''newline$'
		filedelete normtime_formant.txt
		fileappend normtime_formant.txt 'title_line$''newline$'
		if nrepetitions > 0
			filedelete mean_normtime_formant.txt
			fileappend mean_normtime_formant.txt 'title_line$''newline$'
			filedelete mean_norm_actutime.txt
			fileappend mean_norm_actutime.txt 'title_line$''newline$'
		endif
		hasnormtime_formant = 1
	endif
	fileappend "norm_actutime.txt" 'time_line$''newline$'
	fileappend "normtime_formant.txt" 'f1_line$''newline$'
	fileappend "normtime_formant.txt" 'f2_line$''newline$'
	fileappend "normtime_formant.txt" 'f3_line$''newline$'
	fileappend "normtime_formant.txt" 'f2_3_line$''newline$'

	if nrepetitions > 0 
		if repetition == nrepetitions
			fileappend "mean_norm_actutime.txt" 'mean_actutime_line$''newline$'
			fileappend "mean_normtime_formant.txt" 'mean_normF1_line$''newline$'
			fileappend "mean_normtime_formant.txt" 'mean_normF2_line$''newline$'
			fileappend "mean_normtime_formant.txt" 'mean_normF3_line$''newline$'
			fileappend "mean_normtime_formant.txt" 'mean_normF2_3_line$''newline$'
		endif
	endif
	Remove
endproc

procedure All_normtime_barkformants file_name$
	Read TableOfReal from headerless spreadsheet file... 'directory$''name$'.normtime_barkformant
	nrows = Get number of rows
	normtime = 0
	if nrepetitions > 0 and repetition == 1
		for n from 1 to nrows
			mean_normbarkF1'n' = 0
			mean_normbarkF2'n' = 0
			mean_normbarkF3'n' = 0
			mean_normbarkF2_3'n' = 0
		endfor
	endif
	title_line$ = "Normtime"
	f1_line$ = name$+"_F1"
	f2_line$ = name$+"_F2"
	f3_line$ = name$+"_F3"
	f2_3_line$ = name$+"_F2_3"
	if nrepetitions > 0
		mean_normbarkF1_line$ = "_"+shortname$+"_F1"
		mean_normbarkF2_line$ = "_"+shortname$+"_F2"
		mean_normbarkF3_line$ = "_"+shortname$+"_F3"
		mean_normbarkF2_3_line$ = "_"+shortname$+"_F2_3"
	endif

	for n from 1 to nrows
		if !hasnormtime_barkformant
			normtime = normtime + 1
			title_line$ = "'title_line$'	'normtime'"
		endif
		f1 = Get value... n 2
		f2 = Get value... n 3
		f3 = Get value... n 4
		f2_3 = Get value... n 5
		f1_line$ = "'f1_line$'	'f1'"
		f2_line$ = "'f2_line$'	'f2'"
		f3_line$ = "'f3_line$'	'f3'"
		f2_3_line$ = "'f2_3_line$'	'f2_3'"

		if nrepetitions > 0 
			nrows_meanformant = Get number of rows
			if repetition <= nrepetitions
				mean_normbarkF1'n' += f1
				mean_normbarkF2'n' += f2
				mean_normbarkF3'n' += f3
				mean_normbarkF2_3'n' += f2_3
			endif
			if repetition == nrepetitions
				mean_normbarkF1 = mean_normbarkF1'n'/nrepetitions
				mean_normbarkF2 = mean_normbarkF2'n'/nrepetitions
				mean_normbarkF3 = mean_normbarkF3'n'/nrepetitions
				mean_normbarkF2_3 = mean_normbarkF2_3'n'/nrepetitions
				mean_normbarkF1_line$ = "'mean_normbarkF1_line$'	'mean_normbarkF1'"
				mean_normbarkF2_line$ = "'mean_normbarkF2_line$'	'mean_normbarkF2'"
				mean_normbarkF3_line$ = "'mean_normbarkF3_line$'	'mean_normbarkF3'"
				mean_normbarkF2_3_line$ = "'mean_normbarkF2_3_line$'	'mean_normbarkF2_3'"
			endif
		endif
	endfor
	if !hasnormtime_barkformant
		filedelete normtime_barkformant.txt
		fileappend normtime_barkformant.txt 'title_line$''newline$'
		if nrepetitions > 0
			filedelete mean_normtime_barkformant.txt
			fileappend mean_normtime_barkformant.txt 'title_line$''newline$'
		endif
		hasnormtime_barkformant = 1
	endif
	fileappend "normtime_barkformant.txt" 'f1_line$''newline$'
	fileappend "normtime_barkformant.txt" 'f2_line$''newline$'
	fileappend "normtime_barkformant.txt" 'f3_line$''newline$'
	fileappend "normtime_barkformant.txt" 'f2_3_line$''newline$'

	if nrepetitions > 0 
		if repetition == nrepetitions
			fileappend "mean_normtime_barkformant.txt" 'mean_normbarkF1_line$''newline$'
			fileappend "mean_normtime_barkformant.txt" 'mean_normbarkF2_line$''newline$'
			fileappend "mean_normtime_barkformant.txt" 'mean_normbarkF3_line$''newline$'
			fileappend "mean_normtime_barkformant.txt" 'mean_normbarkF2_3_line$''newline$'
		endif
	endif
	Remove
endproc

procedure All_normtime_formantvelocity file_name$
	Read TableOfReal from headerless spreadsheet file... 'directory$''name$'.normtime_formantvelocity
	nrows = Get number of rows
	normtime = 0
	if nrepetitions > 0 and repetition == 1
		for n from 1 to nrows
			mean_normV1'n' = 0
			mean_normV2'n' = 0
			mean_normV3'n' = 0
			mean_normV2_3'n' = 0
		endfor
	endif
	title_line$ = "Normtime"
	v1_line$ = name$+"_V1"
	v2_line$ = name$+"_V2"
	v3_line$ = name$+"_V3"
	v2_3_line$ = name$+"_V2_3"
	if nrepetitions > 0
		mean_normV1_line$ = "_"+shortname$+"_V1"
		mean_normV2_line$ = "_"+shortname$+"_V2"
		mean_normV3_line$ = "_"+shortname$+"_V3"
		mean_normV2_3_line$ = "_"+shortname$+"_V2_3"
	endif
	for n from 1 to nrows
		if !hasnormtime_formantvelocity
			normtime = normtime + 1
			title_line$ = "'title_line$'	'normtime'"
		endif
		v1 = Get value... n 2
		v2 = Get value... n 3
		v3 = Get value... n 4
		v2_3 = Get value... n 5
		v1_line$ = "'v1_line$'	'v1'"
		v2_line$ = "'v2_line$'	'v2'"
		v3_line$ = "'v3_line$'	'v3'"
		v2_3_line$ = "'v2_3_line$'	'v2_3'"

		if nrepetitions > 0 
			nrows_meanformant = Get number of rows
			if repetition <= nrepetitions
				mean_normV1'n' += v1
				mean_normV2'n' += v2
				mean_normV3'n' += v3
				mean_normV2_3'n' += v2_3
			endif
			if repetition == nrepetitions
				mean_normV1 = mean_normV1'n'/nrepetitions
				mean_normV2 = mean_normV2'n'/nrepetitions
				mean_normV3 = mean_normV3'n'/nrepetitions
				mean_normV2_3 = mean_normV2_3'n'/nrepetitions
				mean_normV1_line$ = "'mean_normV1_line$'	'mean_normV1'"
				mean_normV2_line$ = "'mean_normV2_line$'	'mean_normV2'"
				mean_normV3_line$ = "'mean_normV3_line$'	'mean_normV3'"
				mean_normV2_3_line$ = "'mean_normV2_3_line$'	'mean_normV2_3'"
			endif
		endif
	endfor
	if !hasnormtime_formantvelocity
		filedelete normtime_formantvelocity.txt
		fileappend normtime_formantvelocity.txt 'title_line$''newline$'
		if nrepetitions > 0
			filedelete mean_normtime_formantvelocity.txt
			fileappend mean_normtime_formantvelocity.txt 'title_line$''newline$'
		endif
		hasnormtime_formantvelocity = 1
	endif
	fileappend "normtime_formantvelocity.txt" 'v1_line$''newline$'
	fileappend "normtime_formantvelocity.txt" 'v2_line$''newline$'
	fileappend "normtime_formantvelocity.txt" 'v3_line$''newline$'
	fileappend "normtime_formantvelocity.txt" 'v2_3_line$''newline$'

	if nrepetitions > 0 
		if repetition == nrepetitions
			fileappend "mean_normtime_formantvelocity.txt" 'mean_normV1_line$''newline$'
			fileappend "mean_normtime_formantvelocity.txt" 'mean_normV2_line$''newline$'
			fileappend "mean_normtime_formantvelocity.txt" 'mean_normV3_line$''newline$'
			fileappend "mean_normtime_formantvelocity.txt" 'mean_normV2_3_line$''newline$'
		endif
	endif
	Remove
endproc

procedure All_formants file_name$
	Read TableOfReal from headerless spreadsheet file... 'directory$''name$'.formant
	nrows = Get number of rows
	time_line$ = "Time"
	f1_line$ = name$+"_F1"
	f2_line$ = name$+"_F2"
	f3_line$ = name$+"_F3"
	f2_3_line$ = name$+"_F2_3"
	for n from 1 to nrows
		formant_time = Get value... n 1
		f1 = Get value... n 2
		f2 = Get value... n 3
		f3 = Get value... n 4
		f2_3 = Get value... n 5
		time_line$ = "'time_line$'	'formant_time'"
		f1_line$ = "'f1_line$'	'f1'"
		f2_line$ = "'f2_line$'	'f2'"
		f3_line$ = "'f3_line$'	'f3'"
		f2_3_line$ = "'f2_3_line$'	'f2_3'"
	endfor
	if !hasformant
		filedelete formant.txt
		hasformant = 1
	endif
	fileappend "formant.txt" 'time_line$''newline$'
	fileappend "formant.txt" 'f1_line$''newline$'
	fileappend "formant.txt" 'f2_line$''newline$'
	fileappend "formant.txt" 'f3_line$''newline$'
	fileappend "formant.txt" 'f2_3_line$''newline$'
	Remove
endproc

procedure All_formantvelocity file_name$
	Read Table from tab-separated file... 'directory$''name$'.formant_velocity
	Down to TableOfReal... rowLabel
	nrows = Get number of rows
	time_line$ = "Time"
	f1_line$ = name$+"_F1"
	f2_line$ = name$+"_F2"
	f3_line$ = name$+"_F3"
	f2_3_line$ = name$+"_F2_3"
	for n from 1 to nrows
		sampletime = Get value... n 1
		f1 = Get value... n 2
		f2 = Get value... n 3
		f3 = Get value... n 4
		f2_3 = Get value... n 5
		time_line$ = "'time_line$'	'sampletime'"
		f1_line$ = "'f1_line$'	'f1'"
		f2_line$ = "'f2_line$'	'f2'"
		f3_line$ = "'f3_line$'	'f3'"
		f2_3_line$ = "'f2_3_line$'	'f2_3'"
	endfor
	if !hasformant_velocity
		filedelete formant_velocity.txt
		hasformant_velocity = 1
	endif
	fileappend "formant_velocity.txt" 'time_line$''newline$'
	fileappend "formant_velocity.txt" 'f1_line$''newline$'
	fileappend "formant_velocity.txt" 'f2_line$''newline$'
	fileappend "formant_velocity.txt" 'f3_line$''newline$'
	fileappend "formant_velocity.txt" 'f2_3_line$''newline$'
	plus Table 'name$'
	Remove
endproc

#######################################################################################
procedure Cross_speaker_means file_name$ mode_of_averaging$
	has_meanfile = 0
	title_line$ = "Normtime"
	Read Strings from raw text file... 'Speaker_folder_location$''Speaker_folder_file$'
	Rename... speaker_folders
	nspeakers = Get number of strings
	speaker1$ = Get string... 1											; Get n_rows from 1st speaker
	Read Strings from raw text file... 'Speaker_folder_location$''speaker1$'/'file_name$'.txt
	nrows = Get number of strings
	Remove
	
	for row from 1 to nrows
		newspeaker = 1
		for s from 1 to nspeakers
			select Strings speaker_folders
			speaker$ = Get string... s									; Set speaker folder name
			Read Strings from raw text file... 'Speaker_folder_location$''speaker$'/'file_name$'.txt
			Extract part... row row										; Extract 1 row
			line1$ = Get string... 1									; Get current line
			line_part$ = line1$
			wrd$ = extractWord$(line1$, "")								; Get word 1
			Remove
			if s == 1 and row > 1
				speaker_mean_line$ = wrd$								; Put sound name into column 1
			endif
			n = 1
			while wrd$ != ""
				line_part$ = extractLine$(line_part$, wrd$)				; Remove current word
				if row = 1 and n > 1 and s = 1
					title_line$ = "'title_line$'	'wrd$'"
				endif
				if n > 1 and wrd$ != "" and row > 1 and s <= nspeakers
					if not variableExists("speaker_mean'n'") or newspeaker == 1
						speaker_mean'n' = 0
					endif
					if mode_of_averaging$ = "logarithmic"
						speaker_mean'n' += ln('wrd$')
					else
						if wrd$ = "--undefined--"
							wrd$ = "0"
						endif
						speaker_mean'n' += 'wrd$'
					endif
				endif
				wrd$ = extractWord$(line_part$, "	")					; Get next word
				if s == nspeakers and n > 1 and row > 1 and variableExists("speaker_mean'n'")
					if mode_of_averaging$ = "logarithmic"
						speaker_mean = exp(speaker_mean'n'/nspeakers)
					else
						speaker_mean = speaker_mean'n' / nspeakers
					endif
					speaker_mean_line$ = "'speaker_mean_line$'	'speaker_mean'"
				endif
				n += 1
			endwhile
			newspeaker = 0
			select Strings 'file_name$'
			Remove
		endfor
		if !has_meanfile
			filedelete 'file_name$'_cross_speaker.txt
			fileappend "'file_name$'_cross_speaker.txt" 'title_line$''newline$'
			has_meanfile = 1
		endif
		if row > 1
			fileappend "'file_name$'_cross_speaker.txt" 'speaker_mean_line$''newline$'
		endif
	endfor
	printline File saved: 'file_name$'_cross_speaker.txt
	select Strings speaker_folders
	Remove
endproc
#######################################################################################

procedure Formant_turn starttime endtime which_formant max_min$ maxminformant maxmintime
	maxformant = 0
	minformant = 10000
	maxminformant = 0
	maxmintime = 0
	first = Get high index from time... starttime
	last = Get low index from time... endtime
	for index from first to last
		time = Get time from index... index
		value = Get value at time... which_formant time
		if value > maxformant and max_min$ == "maximum"
			maxformant = value
			maxminformant = value
			maxmintime = time
		elsif value < minformant and max_min$ == "minimum"
			minformant = value
			maxminformant = value
			maxmintime = time
		endif
	endfor
endproc
