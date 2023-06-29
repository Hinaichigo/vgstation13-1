var/datum/subsystem/fluids/SSfluids

var/list/fluids_list = list() //todo: descs
var/list/nascent_fluids_list = list()

//todo: descs throughout here and all relevant files


/datum/subsystem/fluids
	name          = "Fluids"
	wait          = SS_WAIT_FLUIDS
	flags         = SS_KEEP_TIMING
	priority      = SS_PRIORITY_FLUIDS
	display_order = SS_DISPLAY_FLUIDS

	var/currentrun[3] //todo: desc
	var/fluid_processing_stage = FLUID_PROCESSING_STAGE_PREFLOW
	//var/list/currentrun_currentstage = list()

/datum/subsystem/fluids/New()
	NEW_SS_GLOBAL(SSfluids)

/datum/subsystem/fluids/stat_entry(var/msg)
	if (msg)
		return ..()

	..("M:[fluids_list.len]")

/datum/subsystem/fluids/fire(resumed = FALSE)


	//todo: revisit
//	if(!(fluids_list.len)) //todo: move this down a block?
//		return

	//todo: use nascent flag or remove?

	message_admins("DEBUG 000 [fluids_list.len]")
	//Get a random ordering to process the fluids in.
	if (!resumed)
		var/list/processing_order = list()

		for (var/obj/fluid/F in nascent_fluids_list)
		//	if (F.fluid_flags & FLUID_PROCESSING_NASCENT) //Check in order to allow fluids not being added to fluids_list in certain conditions, like mixing.
		//		fluids_list += F
			fluids_list += F
			nascent_fluids_list -= F

		for (var/i in 1 to fluids_list.len)
			processing_order += i

		for (var/i = processing_order.len, i>1, --i)
			var/j = rand(1, i)
			if (i > j) processing_order.Swap(i, j)

	//todo: consider this
		currentrun[FLUID_PROCESSING_STAGE_PREFLOW] = processing_order.Copy()
		currentrun[FLUID_PROCESSING_STAGE_FLOW] = processing_order.Copy()
		currentrun[FLUID_PROCESSING_STAGE_POSTFLOW] = processing_order.Copy()
		//currentrun = list(processing_order.Copy(), processing_order.Copy(), processing_order.Copy()) //3 copies; for pre-flow, flow, and post-flow steps

	for (var/obj/fluid/F in fluids_list) //todo: revisit
		if (F && F.timestopped)
			F.fluid_flags = FLUID_PROCESSING_SKIP_ALL

	//message_admins("DEBUG 001 | [currentrun] | [currentrun.len]")
	//Pre-flow step
	//currentrun_currentstage = currentrun[1]
	//while (currentrun_currentstage.len)

	//todo: consolidate these

//	message_admins("DEBUG 100")
	while (fluid_processing_stage == FLUID_PROCESSING_STAGE_PREFLOW)
//		message_admins("DEBUG 101")
		while (currentrun[fluid_processing_stage].len)
			var/obj/fluid/F = fluids_list[currentrun[fluid_processing_stage][currentrun[fluid_processing_stage].len]]
			if (F)
				F.pre_flow()
			else //todo: remove this?
				message_admins("ERROR: null fluid in pre-flow step")
			currentrun[fluid_processing_stage].len--
		fluid_processing_stage = FLUID_PROCESSING_STAGE_FLOW

//	message_admins("DEBUG 200")
	while (fluid_processing_stage == FLUID_PROCESSING_STAGE_FLOW)
//		message_admins("DEBUG 201")
		while (currentrun[fluid_processing_stage].len)
			var/obj/fluid/F = fluids_list[currentrun[fluid_processing_stage][currentrun[fluid_processing_stage].len]]
			if (F && !(F.fluid_flags & FLUID_PROCESSING_SKIP_FLOW))
				F.handle_flow()
			else //todo: remove this?
				message_admins("ERROR: null fluid in flow step")
			currentrun[fluid_processing_stage].len--
		fluid_processing_stage = FLUID_PROCESSING_STAGE_POSTFLOW


//	message_admins("DEBUG 300")
	while (fluid_processing_stage == FLUID_PROCESSING_STAGE_POSTFLOW)
//		message_admins("DEBUG 301")
		while (currentrun[fluid_processing_stage].len)
			var/obj/fluid/F = fluids_list[currentrun[fluid_processing_stage][currentrun[fluid_processing_stage].len]]
			if (F)
				F.post_flow()
			else //todo: remove this?
				message_admins("ERROR: null fluid in post-flow step")
			currentrun[fluid_processing_stage].len--
		fluid_processing_stage = FLUID_PROCESSING_STAGE_PREFLOW

/*
	switch (stage)
		if (FLUID_PROCESSING_STAGE_PREFLOW)
			var/i = 1
			while (i < currentstage_len)
				i++

		if (FLUID_PROCESSING_STAGE_FLOW)
		if (FLUID_PROCESSING_STAGE_POSTFLOW)

	while (currentrun.len)
		var/obj/fluid/F = fluids_list[currentrun_currentstage[currentrun_currentstage.len]]
		currentrun.len--
		if (F)
			F.pre_flow()

	//Flow step
	//currentrun_currentstage = currentrun[2]
	//while (currentrun_currentstage.len)
	while (currentrun.len)
		var/obj/fluid/F = fluids_list[currentrun_currentstage[currentrun_currentstage.len]]
		currentrun.len--
		if (F && !(F.fluid_flags & FLUID_PROCESSING_SKIP_FLOW))
			F.handle_flow()

	//Post-flow step
	//currentrun_currentstage = currentrun[3]
	//message_admins("DEBUG 002 | [currentrun_currentstage] | [currentrun_currentstage.len]")
	//while (currentrun_currentstage.len)
		//break //todo: for debugging
	while (currentrun.len)
		var/obj/fluid/F = fluids_list[currentrun_currentstage[currentrun_currentstage.len]]
		currentrun.len--
		if (F)
			F.post_flow()

*/

	//Prepare for the next cycle.
	for (var/obj/fluid/F in fluids_list.Copy())
		if (F.fluid_flags & FLUID_PROCESSING_MORIBUND)
			fluids_list -= F
			qdel(F)
		else if (F.fluid_flags & FLUID_PROCESSING_DELAY_FLAG_RESET)
			F.fluid_flags &= !FLUID_PROCESSING_DELAY_FLAG_RESET
		else
//			if (F.fluid_flags & FLUID_PROCESSING_NASCENT)
//				fluids_list += F
			F.fluid_flags = 0 //todo: check this

//todo: timestopped considerations?

/*
	while (currentrun.len)
		var/obj/fluid/F = currentrun[currentrun.len]
		currentrun.len--

		if (!F || F.timestopped)
			continue

		//todo: considerations for if F disappears somehow during any of the steps
		//todo: do mixing steps after flow steps? change order to multiphase?

		if (F)
			F.pre_flow()
			if (F.skip_flow) //Skip fluids that have already acted as flow-sinks this tick.
				F.skip_flow = FALSE
			else
				F?.handle_flow()
			F?.post_flow() //todo: some check for skip_mix in here to avoid mixing more than once

		if (MC_TICK_CHECK)
			return
*/