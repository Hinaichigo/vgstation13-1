var/datum/subsystem/fluids/SSfluids

var/list/fluids_list = list()


/datum/subsystem/fluids
	name          = "Fluids"
	wait          = SS_WAIT_FLUIDS
	flags         = SS_NO_INIT | SS_KEEP_TIMING
	priority      = SS_PRIORITY_FLUIDS
	display_order = SS_DISPLAY_FLUIDS

	var/list/currentrun

/datum/subsystem/fluids/New()
	NEW_SS_GLOBAL(SSfluids)

/datum/subsystem/fluids/stat_entry(var/msg)
	if (msg)
		return ..()

	..("M:[fluids_list.len]")

/datum/subsystem/fluids/fire(resumed = FALSE)
	if (!resumed)
		currentrun = fluids_list.Copy()

	while (currentrun.len)
		var/obj/fluid/F = currentrun[currentrun.len]
		currentrun.len--

		if (!F || F.timestopped)
			continue

		//todo: proper fluids_list upon New?
		//todo: randomize order
		//todo: considerations for if F disappears somehow during any of the steps
		//todo: do mixing steps after flow steps? change order to multiphase?

		if (F)
			F.pre_flow()
			if (F.skip_flow) //Skip fluids that have already acted as flow-sinks this tick.
				F.skip_flow = FALSE
			else
				F?.handle_flow()
			F?.post_flow()

		if (MC_TICK_CHECK)
			return
