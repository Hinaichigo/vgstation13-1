/proc/wormhole_event()
	spawn()
		var/list/pick_turfs = list()
		for(var/turf/simulated/floor/T in world)
			if(T.z == map.zMainStation)
				//Check for and avoid grilles and closed doors.
				for(var/obj/structure/grille/G in T.contents)
					break
				for(var/obh/machinery/door/D in T.contents)
					if(D.density)
						break
				pick_turfs += T

		if(pick_turfs.len)
			//All ready. Announce that bad juju is afoot.
			if(prob(indeterminacy_trigger_prob)) //Potential for indeterminacy.
				indeterminacy = 100
				for(var/i in 1 to 2)
					indeterminacy = min(rand(1,100), indeterminacy)
					indeterminacy = 100 //todo: put this back
			command_alert(/datum/command_alert/wormholes)
			//prob(20) can be approximated to 1 wormhole every 5 turfs!
			//admittedly less random but totally worth it >_<
			var/event_duration = 3000	//~5 minutes in ticks
			var/number_of_selections = (pick_turfs.len/5)+1	//+1 to avoid division by zero!
			var/sleep_duration = round( event_duration / number_of_selections )
			var/end_time = world.time + event_duration	//the time by which the event should have ended

			var/increment =	max(1,round(number_of_selections/50))
//			to_chat(world, "DEBUG: number_of_selections: [number_of_selections] | sleep_duration: [sleep_duration]")

			var/i = 1
			while( 1 )

				//we've run into overtime. End the event
				if( end_time < world.time )
//					to_chat(world, "DEBUG: we've run into overtime. End the event")
					return
				if( !pick_turfs.len )
//					to_chat(world, "DEBUG: we've run out of turfs to pick. End the event")
					return

				//loop it round
				i += increment
				i %= pick_turfs.len
				i++

				//get our enter and exit locations
				var/turf/simulated/floor/enter = pick_turfs[i]
				pick_turfs -= enter							//remove it from pickable turfs list
				if( !enter || !istype(enter) )
					continue	//sanity

				var/turf/simulated/floor/exit = pick(pick_turfs)
				pick_turfs -= exit
				if( !exit || !istype(exit) )
					continue	//sanity

				create_wormhole(enter,exit)

				sleep(sleep_duration)						//have a well deserved nap!
			indeterminacy = 0

//maybe this proc can even be used as an admin tool for teleporting players without ruining immulsions?
/proc/create_wormhole(var/turf/enter as turf, var/turf/exit as turf)
	if(indeterminacy)
		var/obj/effect/portal/scrambling/S = new /obj/effect/portal/scrambling( enter )
		S.target = exit
		S.icon = 'icons/obj/objects.dmi'
		S.icon_state = "anom"
		S.name = "wormhole"
		spawn(rand(300,600)) //This isn't useful, the new in hand tele will likely override it
			qdel(S)
	else
		var/obj/effect/portal/P = new /obj/effect/portal( enter )
		P.target = exit
		P.icon = 'icons/obj/objects.dmi'
		P.icon_state = "anom"
		P.name = "wormhole"
		spawn(rand(300,600)) //This isn't useful, the new in hand tele will likely override it
			qdel(P)
