//Fluids as objects.

/obj/fluid
	var/fluid_flags = 0 // Flags to skip steps in a certain round of fluid processing. See setup.dm.

/obj/fluid/New()
	. = ..()
	#define CC_PER_U 10 //todo: remove this
	create_reagents(CELL_VOLUME * 1000 / CC_PER_U) //Cell volume in u.

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
	icon = 'icons/obj/puddle.dmi'
	icon_state = "puddle0"
	anchored = TRUE //Can move via flow, but not by being pulled around.

/obj/fluid/puddle/New()
	. = ..()
	fluid_flags |= FLUID_PROCESSING_NASCENT //todo: remove this?
	nascent_fluids_list += src //todo: check if this is okay? add desc if so

/obj/fluid/puddle/Destroy()
	//fluids_list -= src
	update_cardinal_neighbor_icons()
	. = ..()

/obj/fluid/puddle/pre_flow()
	//Everything that happens before the flow step

	//If the puddle isn't on an open turf, delete it.
	var/turf/T = get_turf(src)
	if(!T || T.density)
		//message_admins("Deletion debug 001")
		prepare_for_deletion()
		return

	//Check for additional fluids on the same tile and merge them into this one.
	absorb_other_fluids()

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
		//message_admins("Deletion debug 003")
		prepare_for_deletion()

/obj/fluid/proc/prepare_for_deletion()
	fluid_flags |= (FLUID_PROCESSING_SKIP_ALL | FLUID_PROCESSING_MORIBUND)
	//todo: other stuff like hide the puddle and make it not do anything and stuff

/obj/fluid/puddle/handle_flow()
//todo: need to have flow-sink puddles not also try to be a flow-source on the same tick
//Find if there's any direction to flow in and transfer an appropriate amount of fluid into the target tile, creating a new puddle if necessary.
		//todo:
		//todo: var/airflow_pressure (also change desc. below)
	var/flowable_volume = reagents.total_volume - PUDDLE_VOL_THRESH_SPREAD
	if (flowable_volume >= PUDDLE_FLOW_VOL_MIN)
		message_admins("DEBUG 003 [src] flowable_volume: [flowable_volume]")
		//Check puddle volume of the cardinally adjacent turfs in a random order.
		var/list/possible_flowtarget_turfs = list()
		var/target_fluid_diff = 0 //We flow into the neighbor with the lowest volume (random in the case of a tie) so we keep track of the highest volume difference.
		for (var/turf/T in get_cardinal_neighbors())
			message_admins("DEBUG 0031 [T]")
			if (!(T.puddle_can_exist_in())) //Don't flow into walls.
				continue
			//todo: check for special cases like windows and stuff (maybe same criteria as a mouse entering or not.. or better yet gas permeability)

			var/this_fluid_diff = reagents.total_volume - T.return_puddle_volume()
			message_admins("DEBUG 0032 [this_fluid_diff]")
			if (this_fluid_diff > target_fluid_diff) //todo: consider making minimum difference
				target_fluid_diff = this_fluid_diff
				possible_flowtarget_turfs.len = 0
				possible_flowtarget_turfs += T
			else if (this_fluid_diff == target_fluid_diff)
				possible_flowtarget_turfs += T
		message_admins("DEBUG 004 [possible_flowtarget_turfs.len]")
		if (possible_flowtarget_turfs.len)
			var/vol_to_flow = min(flowable_volume, 0.5 * target_fluid_diff) //Don't transfer more than half of the difference in reagent volume to the new puddle.
			message_admins("DEBUG 005")
			var/turf/flow_target = pick(possible_flowtarget_turfs)
			//todo: more considerations as to how much flows to the target puddle per tick (viscosity, powder versus liquid, and minimum to move based on surface tension)
			var/obj/fluid/puddle/target_puddle = flow_target.return_puddle()
			if (!target_puddle)
				if (vol_to_flow < PUDDLE_VOL_THRESH_EXIST) //Don't transfer to a new puddle if it would immediately disappear.
					return
				target_puddle = new /obj/fluid/puddle(flow_target)
			reagents.trans_to(target_puddle, vol_to_flow)
			target_puddle.fluid_flags |= FLUID_PROCESSING_SKIP_FLOW
			//target_puddle.update_icon() //todo: added for debug, maybe remove?
			//todo:
		//Puddles flow across fluid pressure gradients. Due to there being no notion of fluid layering (oil floating on water, mercury sinking in ethanol), the fluid pressure gradient is approximated by the difference in the the volume of the fluid across tiles (volume scales linearly with height once the puddle has grown beyond being a round spatter and covers the full surface area of the floor tile).

/obj/fluid/puddle/proc/get_cardinal_neighbors() //todo: define this elsewhere?
	var/list/cardinal_neighbors = list()
	for(var/check_dir in cardinal)
		var/turf/simulated/T = get_step(get_turf(src), check_dir)
		if(T)
			cardinal_neighbors |= T
	return cardinal_neighbors

//todo: consider moving/using these more
/turf/proc/puddle_can_exist_in()
	if (!src || density)
		return FALSE
	else
		return TRUE

/turf/proc/return_puddle()
	if(src)
		for(var/obj/fluid/puddle/P in contents)
			return P

/turf/proc/return_puddle_volume() //todo: should this be fluids?
	var/puddle_volume = 0
	if(src)
		for(var/obj/fluid/puddle/P in contents)
			puddle_volume += P.reagents.total_volume
	return puddle_volume

/*
turf/create_puddle_here(add_to_fluids_list = TRUE) //We have a flag here to allow for non-processed puddles that won't be added to the fluids list and will simply be merged into... //todo: ...
	var/obj/fluid/puddle/P = new /obj/fluid/puddle(
	if (add_to_fluids_list)
		fluids_list += P
*/

/obj/fluid/puddle/post_flow()
	//message_admins("DEBUG: post_flow() called on [src] at [loc] with [reagents.total_volume] u of: [reagents.get_master_reagent_name()]")
	//Everything that happens after the flow step

	//Mixing
		//works by making new puddles on neighboring tiles, the puddles on which then get merged together
	if (!(fluid_flags & FLUID_PROCESSING_SKIP_MIX) && reagents.total_volume >= PUDDLE_VOL_THRESH_MERGE)
		var/list/mix_partners = list()
		//var/total_mixing_partners_volume
		for (var/turf/T in get_cardinal_neighbors())
			var/obj/fluid/puddle/P = T.return_puddle()
			if (P && !(P.fluid_flags & FLUID_PROCESSING_SKIP_MIX) && P.reagents.total_volume >= PUDDLE_VOL_THRESH_MERGE)
				mix_partners += P
				//total_mixing_partners_volume += P.reagents.total_volume
		//var/list/transfer_volumes = list()
		for (var/obj/fluid/puddle/P in mix_partners)
			var/transfer_volume = (0.5 / mix_partners.len) * min(reagents.total_volume, P.reagents.total_volume) //0.5 to diffuse evenly. Could be less, but shouldn't be more.
			var/obj/fluid/puddle/new_puddle_here = new /obj/fluid/puddle/(loc)
			var/obj/fluid/puddle/new_puddle_there = new /obj/fluid/puddle/(P.loc)
			reagents.trans_to(new_puddle_there, transfer_volume)
			P.reagents.trans_to(new_puddle_here, transfer_volume)
			/*
			//Disable mixing on these new puddles because they're what was mixed and will soon be absorbed by the mixing partner.
			new_puddle_here.fluid_flags |= FLUID_PROCESSING_SKIP_MIX
			new_puddle_there.fluid_flags |= FLUID_PROCESSING_SKIP_MIX
			*/
			new_puddle_here.fluid_flags |= (FLUID_PROCESSING_SKIP_ALL & FLUID_PROCESSING_DELAY_FLAG_RESET)
			new_puddle_there.fluid_flags |= (FLUID_PROCESSING_SKIP_ALL & FLUID_PROCESSING_DELAY_FLAG_RESET)
		//todo: revisit/symmetry considerations on the below?
		fluid_flags |= FLUID_PROCESSING_SKIP_MIX //We've mixed with all potential partners so we don't need to do it again this round.

/*
	//Mixing //todo: decide here or during (pre)flow step?
	if (!(fluid_flags & FLUID_PROCESSING_SKIP_MIX) && reagents.total_volume >= PUDDLE_VOL_THRESH_MERGE)
		//message_admins("DEBUG: flags OK")
		//message_admins("DEBUG 001")
		var/list/mix_partners = list()
		for (var/turf/T in get_cardinal_neighbors())
			//message_admins("DEBUG 002: neighbor turf [T]")
			var/obj/fluid/puddle/P = T.return_puddle()
			if (P && !(P.fluid_flags & FLUID_PROCESSING_SKIP_MIX) && P.reagents.total_volume >= PUDDLE_VOL_THRESH_MERGE)
				//message_admins("DEBUG 003:  [P]")
				mix_partners += P
		//message_admins("DEBUG 003 [mix_partners.len]")
		for (var/obj/fluid/puddle/P in mix_partners) //todo: get random ordering? or do this simultaneously with all 4?
			//message_admins("DEBUG 004")
			src.reagents.mix_with(P.reagents)
			P.update_icon()
			P.fluid_flags |= FLUID_PROCESSING_SKIP_MIX
		update_icon()
		fluid_flags |= FLUID_PROCESSING_SKIP_MIX //todo: fix these
		message_admins("DEBUG 001: Mixed [src] with [mix_partners.len] neighbors.")
*/
		//todo: new psuedo puddles shouldn't be added to the fluids list?
		//todo: change it so smaller puddles get readily mixed with larger puddles? (change transfer_volme calc)
		//todo: consider moving 0.5 to define
		//todo: keep pre_mixing volume noted to avoid bias towards random order
		//todo: add "stale" notion to avoid keep doing the same thing until the puddle contents are updated again?
		//todo: consider priority with regard to gas thermal mixing
		//todo: chemical reactions with gas?

	//Interactions with mobs in the same tile
		//todo:

	//Interactions with objects in the same tile
		//todo:

	//Evaporation considerations
		//todo: phase changes,

	if (reagents.total_volume < PUDDLE_VOL_THRESH_EXIST) //todo: revisit this
		message_admins("DEBUG: [src] volume too low ([reagents.total_volume]), preparing for deletion")
		//message_admins("Deletion debug 004")
		prepare_for_deletion()

/*
/obj/fluid/puddle/update_icon()
		//Update name, desc, and appearance
		//todo: pool of milk, puddle of blah blah, etc
		//todo: consider not being clickable? no visible name?
	//todo: consider visibility
	if (reagents.total_volume)
		color = mix_color_from_reagents(turf_on.reagents.reagent_list,TRUE)
		alpha = mix_alpha_from_reagents(turf_on.reagents.reagent_list,TRUE)
	if (reagents.total_volume < PUDDLE_VOL_THRESH_PUDDLE)
		icon_state = "spatter_[rand(1,3)]" //todo: need to persist spatter type across ticks
		name = "spatter"
		desc = "A spatter of something." //todo: update all descs and names dynamically
	else if (reagents.total_volume < PUDDLE_VOL_THRESH_POOL)
		icon_state = "puddle" //todo: need to persist spatter type across ticks
		name = "puddle"
		desc = "A puddle of something." //todo: update all descs and names dynamically
	else if (reagents.total_volume < PUDDLE_VOL_THRESH_SPREAD)
		icon_state = "pool" //todo: need to persist spatter type across ticks
		name = "pool"
		desc = "A pool of something." //todo: update all descs and names dynamically
	else
		icon_state = "full"
		name = "pool"
		desc = "A pool of something." //todo: consider changing these for full
		//todo: consider switch statement
		//todo: add flag for updating appearance to avoid continually doing it every tick when unnecessary
		relativewall()
*/

/obj/fluid/puddle/proc/absorb_other_fluids() //Absorb all other fluids on the same tile.
	if (fluid_flags & FLUID_PROCESSING_SKIP_ABSORB)
		return
	message_admins("[src] absorbing other fluids")
	for (var/obj/fluid/F in loc.contents)
		//message_admins("checking [F]")
		//if ((F != src)) //todo: revert this to below
		if ((F != src) && !((fluid_flags | F.fluid_flags) & FLUID_PROCESSING_MORIBUND))
			//message_admins("okay to transfer")
			F.reagents.trans_to(src, F.reagents.total_volume)
			//message_admins("Deletion debug 002")
			F.prepare_for_deletion()
		//todo: considerations for max volume not transferring all fluid? this is mainly for multi z if puddles fall onto each other

/obj/fluid/puddle/update_icon()
		//Update name, desc, and appearance
		//todo: pool of milk, puddle of blah blah, etc
		//todo: consider not being clickable? no visible name?
	//todo: consider visibility
	var/total_fluid_volume_here = total_fluid_volume_here()
	if (total_fluid_volume_here)
		color = mix_color_from_reagents(reagents.reagent_list, TRUE)
		alpha = mix_alpha_from_reagents(reagents.reagent_list, TRUE)
	if (total_fluid_volume_here < PUDDLE_VOL_THRESH_PUDDLE)
		icon_state = "spatter[rand(1,3)]" //todo: need to persist spatter type across ticks
		name = "spatter"
		desc = "A spatter of something." //todo: update all descs and names dynamically
	else if (total_fluid_volume_here < PUDDLE_VOL_THRESH_MERGE)
		icon_state = "puddle0" //todo: need to persist spatter type across ticks
		name = "puddle"
		desc = "A puddle of something." //todo: update all descs and names dynamically
	else if (total_fluid_volume_here < PUDDLE_VOL_THRESH_SPREAD)
		relativewall()
		name = "pool"
		desc = "A pool of something." //todo: update all descs and names dynamically
	else
		icon_state = "full"
		name = "pool"
		desc = "A pool of something." //todo: consider changing these for full
		//todo: consider switch statement
		//todo: add flag for updating appearance to avoid continually doing it every tick when unnecessary
		relativewall()

//todo: add this (also change?)
	//		transform = matrix(min(1, turf_on.reagents.total_volume / CIRCLE_PUDDLE_VOLUME), 0, 0, 0, min(1, turf_on.reagents.total_volume / CIRCLE_PUDDLE_VOLUME), 0)

/obj/fluid/puddle/findSmoothingNeighbors()
	. = 0
	for (var/cdir in cardinal)
		var/turf/T = get_step(src,cdir)
		for (var/obj/fluid/puddle/P in T)
			if(P.total_fluid_volume_here() >= PUDDLE_VOL_THRESH_MERGE)
				. |= cdir
				break

/obj/fluid/puddle/relativewall()
	var/junction = findSmoothingNeighbors()
	icon_state = "puddle[junction]"

/obj/fluid/puddle/on_reagent_change()
	update_icon()
	update_cardinal_neighbor_icons()
	//todo: consider edge cases here (break?)

/obj/fluid/puddle/proc/update_cardinal_neighbor_icons()
	for (var/cdir in cardinal)
		var/turf/T = get_step(src,cdir)
		for (var/obj/fluid/puddle/P in T)
			if(P.reagents.total_volume >= PUDDLE_VOL_THRESH_MERGE)
				P.update_icon()

/obj/fluid/proc/total_fluid_volume_here() //todo: move this? define it on a turf?
	var/total_fluid_volume_here = 0
	//var/total_fluid_volume_here = reagents.total_volume
	if (loc)
		for (var/obj/fluid/F in loc.contents)
			total_fluid_volume_here += F.reagents.total_volume
	return total_fluid_volume_here


/obj/fluid/puddle/ex_act()
	//todo:
	. = ..()

//todo:

//todo: seems like "master puddle" is being deleted? instead of just persisting and having the mixing partners go as expected
//todo: update only color/alpha in cases of post mixing to avoid checking amount since amount doesn't change.
//todo: may need to move to a datum or thing on a turf? with a list of parcels of fluids
//todo: fix list index out of bounds stuff? (need to re-consider all the existing fluids
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
//todo: find a use for SKIP_MIX or remove?
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
//todo: dont spread when the target would have less than the minimum threshold?
	//todo: incl on existing puddles?
//todo: you splash onto the pool/ vs into pool
//todo sprite flickering to full size?
//splashing onto puddle doesnt add to the puddle? should also apply to objs?
//handle puddle merging more nicely without having to do it in  the flow step?
//plane layer under tables etc
//test z-levels falling
//flow pushing objects
//dont flow sideways when theres no gravity or floor?
//todo: resolve conflicts with old blood spatters/water/lube/etc system
//todo: sprite issues with full/pool/puddle/etc and being full on all sides but not being full?
//todo: smoothing against walls beyond a certain volume?
//todo: spread into multiple directions simultaneously instead of one random direction?
//todo: gradient blur of colors?
//todo: initializing puddles with a given amount of reagents
//todo: don't merge where a window separates it
//todo: update icon of neighbors etc when puddle destroyed?
//todo: only fluids mix and not just powders?
//todo: use MINIMUM_TRANSFER_VOLUME?
//todo: config options?
//todo: admin logging for puddle transfers?
//todo: opencontainer hot spot etc.
//todo: pepper etc opacity etc
//todo: randomize reagent order? or change diffusion to add reagents then update and not one by one?
//todo: pause due to lack of fluids
//todo: touch reactions on adjacent walls?
//todo: fix diffusion keep going back and forth?
//todo: fix spatters also being diffused
//todo: fix puddles changing size? (going from pool to puddle?)
//todo: consider rounding errors with puddle diffusion?
//todo: don't flow so much that it'd take the volume under the merge threshold?
	//todo: puddle size change is caused by the mixing step
//todo: merge/flow threshold/diffusions threshold should be diff?
//todo: round mixing amounts?
//todo: change flow to keep going to edge?
//todo: descs here and throughout
//todo: change defines names?