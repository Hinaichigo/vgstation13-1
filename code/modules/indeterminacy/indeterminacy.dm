//Indeterminacy
var/indeterminacy = 0 //Can range from 0 (absolutely determinate) to 100 (absolutely indeterminate).
var/indeterminacy_trigger_prob = 100 //todo: put this back

/proc/indeterminacy_message()
	var/output = " Additionally, metaseismic probabilographs indicate " //todo.. change this?
	switch(indeterminacy)
		if(INDET_LVL_1)
			output += "mild levels of indeterminacy."
		if(INDET_LVL_2)
			output += "substantial levels of indeterministic deviance."
		if(INDET_LVL_3)
			output += "high levels of canonic splintering."
		if(INDET_LVL_4)
			output += "severe levels of narrativistic fracture."
		else
			output = " There is no additional data."
	return output

/proc/indeterminacy_level()
	switch(indeterminacy)
		if(INDET_LVL_1)
			return 1
		if(INDET_LVL_2)
			return 2
		if(INDET_LVL_3)
			return 3
		if(INDET_LVL_4)
			return 4
		else
			return 0

var/list/alljobtypes = subtypesof(/datum/job)