//Fluids as objects.

/obj/fluid
	var/skip_flow = FALSE //Temporarily set to skip the flow step in a given round of fluid processing.
	//Can maybe be expanded to include things like fluids moving through a pipe, coatings on mobs or objects, and things like that.

/obj/fluid/proc/pre_flow()
	return

/obj/fluid/proc/handle_flow()
	return

/obj/fluid/proc/post_flow()
	return

/obj/fluid/proc/get_pressure()
	return 0

/obj/fluid/puddle
	name = 	"puddle"
	desc = "A quantity of fluid, typically on the floor."
	icon = 'icons/obj/puddles.dmi'
	icon_state = "puddle"
	anchored = TRUE //Can move via flow, but not by being pulled around.

/obj/fluid/puddle/pre_flow()
	return
	//Everything that happens before the flow step

	//If the puddle isn't in an open turf, delete it.
	var/turf/T = get_turf(src)
	if(!T || T.density)
		qdel(src)
		return

	//Check for additional puddles on the same tile and merge them into this one.
	for (var/obj/fluid/puddle/P in loc.contents)
		if (P ~= src)
			P.reagents.trans_to(src, P.reagents.total_volume)
			qdel(P)
		//todo: considerations for max volume not transferring all fluid? this is mainly for multi z if puddles fall onto each other

	//Heat transfer with the air in the same tile
	var/datum/gas_mixture/A = T.return_air()
	if (A)
		if (abs(A.temperature - reagents.chem_temp) >= MINIMUM_TEMPERATURE_DELTA_TO_CONSIDER) //todo: revisit this
			var/new_temp = reagents.get_equalized_temperature(reagents.chem_temp, reagents.get_thermal_mass(), A.temperature, A.heat_capacity())
		reagents.chem_temp = new_temp
		A.add_thermal_energy(A.get_thermal_energy_change(new_temp))

	//todo: considerations for all of the heat not immediately transferring?
		//todo: make dummy proc for this and also use it in mob thermal mass etc.?
	reagents.handle_reactions()

	if (!(reagents.total_volume))
		qdel(src)

/obj/fluid/puddle/handle_flow()

//todo: need to have flow-sink puddles not also try to be a flow-source on the same tick
//Find if there's any direction to flow in and transfer an appropriate amount of fluid into the target tile, creating a new puddle if necessary.
		//todo:
		//todo: var/airflow_pressure (also change desc. below)
	var/flowable_volume = reagents.total_volume - PUDDLE_VOL_THRESH_SPREAD
	if (flowable_volume > 0)
		//Check puddle volume of the cardinally adjacent turfs in a random order.
		var/list/possible_flowtarget_turfs = list()
		var/target_fluid_diff = reagents.total_volume //We flow into the neighbor with the lowest volume (random in the case of a tie) so we keep track of the highest volume difference.
		var/existing_fluid_at_flow_target = FALSE
		for (var/turf/T in orange(1))
			if (T.density) //Don't flow into walls.
				continue
			//todo: check for special cases like windows and stuff (maybe same criteria as a mouse entering or not.. or better yet gas permeability)
			for (var/obj/fluid/puddle/P in T.contents)
				existing_fluid_at_flow_target = TRUE
				var/this_fluid_diff = reagents.total_volume - P.reagents.total_volume
				if (this_fluid_diff > target_fluid_diff)
					target_fluid_diff = this_fluid_diff
					possible_flowtarget_turfs.len = 0
					possible_flowtarget_turfs += T
				else if (this_fluid_diff == target_fluid_diff)
					possible_flowtarget_turfs += T
				break
			if (!existing_fluid_at_flow_target)
				if (reagents.total_volume > target_fluid_diff)
					target_fluid_diff = reagents.total_volume
					possible_flowtarget_turfs.len = 0
					possible_flowtarget_turfs += T
		if (possible_flowtarget_turfs.len)
			var/turf/flow_target = pick(possible_flowtarget_turfs)
			//todo: more considerations as to how much flows to the target puddle per tick (viscosity, powder versus liquid, and minimum to move based on surface tension)
			if (existing_fluid_at_flow_target)
				for (var/obj/fluid/puddle/target_puddle in flow_target.contents)
					reagents.trans_to(target_puddle, min(flowable_volume, 0.5 * target_fluid_diff)) //Don't transfer more than half of the difference in reagent volume to the new puddle.
					target_puddle.skip_flow = TRUE
					break
			else
				var/obj/fluid/puddle/new_puddle = new /obj/fluid/puddle(flow_target)
				reagents.trans_to(new_puddle, min(flowable_volume, 0.5 * reagents.total_volume)) //Don't transfer more than half of the reagents to the new puddle.
				new_puddle.skip_flow = TRUE
			//todo:
		//Puddles move via fluid pressure differentials. Due to there being no notion of fluid layers (oil floating on water, mercury sinking in ethanol), the fluid pressure is based on differences in the the volume of the fluid (volume scales linearly with height once the puddle has grown beyond being a round spatter and covers the full surface area of the floor tile).

/obj/fluid/puddle/post_flow()
	//Everything that happens after the flow step

	//Mixing //todo: decide here or during (pre)flow step?
		//todo: both thermal and chemical mixing
		//todo: consider priority with regard to gas thermal mixing
		//todo: chemical reactions with gas?

	//Interactions with mobs in the same tile
		//todo:

	//Interactions with objects in the same tile
		//todo:

	//Evaporation considerations
		//todo: phase changes,

	if (!(reagents.total_volume && reagents.total_volume >= PUDDLE_VOL_THRESH_EXIST)) //todo: revisit this
		qdel(src)

	//Update name, desc, and appearance
		//todo: pool of milk, puddle of blah blah, etc
		//todo: consider not being clickable? no visible name?
	//todo: consider visibility
	if (reagents.total_volume < PUDDLE_VOL_THRESH_PUDDLE)
		icon_state = "spatter_[rand(1,3)]" //todo: need to persist spatter type across ticks
		name = "spatter"
		desc = "A spatter of something." //todo: update all descs and names dynamically
	else if (reagents.total_volume < PUDDLE_VOL_THRESH_POOL)
		icon_state = "puddle" //todo: need to persist spatter type across ticks
		name = "puddle"
		desc = "A puddle of something." //todo: update all descs and names dynamically
	else if (reagents.total_volume < PUDDLE_VOL_THRESH_FULL)
		icon_state = "pool" //todo: need to persist spatter type across ticks
		name = "pool"
		desc = "A pool of something." //todo: update all descs and names dynamically
	else
		icon_state = "full"
		name = "pool"
		desc = "A pool of something." //todo: consider changing these for full
		//todo: consider switch statement
		//todo: add flag for updating appearance to avoid continually doing it every tick when unnecessary

/obj/fluid/puddle/ex_act()
	//todo:
	.=..()

//todo:

//edge of map considerations
//mouse click transparency considerations/layer ordering
//flow logic
//what happens with explosions?
//mixing
//heat transfer with gases
//heat transfer with mobs (dependent on mob thermal mass)
//heat transfer with objs (dependent on obj thermal mass)
//interaction with mobs standing or lying in the puddle
//interaction with objs in the puddle
//falling to lower z levels
//reagent transferring to and from reagent containers
//spilling directly onto the floor
//spilling onto the floor after it drips (floor turf reaction)
//evaporation
//cleaning
	//cleaning spray
	//janitor methods
//chemical reactions
//blood scanning
//reagent scanning
//order of things happening
//check z-level falling stuff
//consider more intermediate pool size stages
//tweak volume threshold values
//todo: edge cases with falling diagonally downwards when there's a strong airflow while also an open z-level hole?
//todo: air volume of tile reduces (pressure increases) as fluid is pumped into it? (hydraulics)
//todo: optimize
//todo: change name of blobs of liquids in space/no gravity
//todo: max volume
//todo: disappearing if there's not any volume in them (and remove from list?)
//todo: minimum volume and disappearing otherwise?
//todo: what happens if it a door closes on the puddle/the puddle flows from a closed door?
//todo: simplify
//todo: somehow stagger things so that it doesn't happen too mechanically every tick
//todo: only do a certain percentage of puddles?
//todo: change names of defines from puddle to fluid?
//todo: two puddles being on the same tile automatically merge
//todo: not putting puddles in lockers
//todo: not building walls on puddles
//todo: heat and reagent mixing even with similar volumes
//todo: min volume to exist
//todo: initializing for mappers
//todo: sprites
	//random spatters, offsets, edge logic, inherit from bloodstains and stuff?