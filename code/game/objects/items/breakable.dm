//Breakable items

/////////////////////
//Todo:
/////////////////////
//Break upon being bitten
//Break upon being used AS a weapon
//Getting hurt when holding an item as it breaks
//Sounds when the item is hit.
//If the item has reagents or components, spill them when it breaks
//Stop conflict with hitting a box and also putting the item into the box.
/////////////////////
//
/////////////////////
//Areas for expansion:
/////////////////////
//Damage considerations for the strength of the weapon wielder
//Make breakability into a component
//Generalize to /obj
//Integrate existing shrapnel system into fragments.
//Integrate with existing health system for other things like closets.
/////////////////////

/obj/item

	//Destructability parameters:
	var/breakable_flags = 0 /*possible flags include BREAKABLE_ALL | BREAKABLE_HIT | BREAKABLE_UNARMED | BREAKABLE_WEAPON | BREAKABLE_THROW
							BREAKABLE_HIT encompasses both BREAKABLE_UNARMED and BREAKABLE_WEAPON */
	var/health_item= 15 //Structural integrity of the item. at 0, the item breaks.
	var/health_item_max= 15
	var/damage_armor = 5 //Attacks of this much damage or below will glance off
	var/damage_resist = 5 //Attacks stronger than damage_armor will have their damage reduced by this much
	var/damaged_examine_text	//Addendum to the description when it's damaged eg. damaged_examine_text of "It is dented." null will skip this addendum.
	var/take_hit_text 	//String or list of strings when the item is damaged but not fully broken. eg. "chipping" becomes "..., chipping it!"
	var/breaks_text		//Visible message when the items breaks. eg. "breaks apart" null skips this.
	var/breaks_sound	//Path to audible sound when the item breaks. null skips this.
	var/glances_text	//String or list of strings when the item is attacked but the attack glances off. eg. "bounces" becomes "but it bounces off!"
	var/list/breakable_fragments //List of objects that will be produced when the item is broken apart. eg. /obj/weapon/item/shard.
	var/list/fragment_amounts //List of the number of fragments of each item type in breakable_fragments to be dropped. Should be either null (1 each) or the same length as breakabe_fragments
	var/list/breakable_exclude //List of objects that won't be used to hit the item even on harm intent, so as to allow for other interactions.

/obj/item/proc/on_broken(var/atom/target, var/range, var/speed, var/override, var/fly_speed, var/atom/hit_atom) //Called right before an object breaks.
	//Drop and and propel any fragments:
	drop_fragments(target,range,speed,override,fly_speed)
	//Drop and propel any contents:
	drop_contents(target,range,speed,override,fly_speed)
	//Spill any reagents:
	spill_reagents(hit_atom)
	if(!isnull(reagents))
		reagents.reaction(hit_atom)
	if(breaks_text)
		visible_message("<span class='warning'>\The [src] [breaks_text]!</span>")
	if(breaks_sound)
		playsound(src, breaks_sound, 50, 1)

/obj/item/proc/drop_fragments(var/atom/target, var/range, var/speed, var/override, var/fly_speed) //Separate proc in case special stuff happens with a given item's fragments. Parameters are for throwing the fragments.
	if(breakable_fragments.len)
		var/oneeach=(isnull(fragment_amounts) || breakable_fragments.len != fragment_amounts.len) //default to 1 of each fragment type if fragement_amounts isn't specified or there's a length mismatch
		var/numtodrop
		var/thisfragment
		for(var/frag_ind in 1 to breakable_fragments.len)
			if(oneeach)
				numtodrop=1
			else
				numtodrop=fragment_amounts[frag_ind]
			thisfragment=breakable_fragments[frag_ind]
			for(var/n in 1 to numtodrop)
				var/obj/item/O = new thisfragment (get_turf(src))
				//Transfer fingerprints, fibers, and bloodstains to the fragment.
				transfer_fingerprints(src,O)
				transfer_item_blood_data(src,O)
				if(target && range && speed) //Propel the fragment if specified.
					O.throw_at(target,range,speed,override,fly_speed)

/obj/item/proc/drop_contents(var/atom/target, var/range, var/speed, var/override, var/fly_speed) //Drop the contents of the item and propel them if the item itself received a propulsive blow.
	if(contents.len)
		for(var/obj/item/thiscontent in contents)
			thiscontent.loc = src.loc
			if(target && range && speed) //Propel the content if specified.
				thiscontent.throw_at(target,range,speed,override,fly_speed)

/obj/item/proc/spill_reagents(var/atom/hit_atom) //Spill any reagents contained within the item onto the floor, and the atom it hit when it broke, if applicable.
	if(!isnull(reagents))
		if(!isnull(hit_atom) && hit_atom != get_turf(src)) //If it hit something other than the floor, spill it onto that.
			reagents.reaction(hit_atom, TOUCH)
		reagents.reaction(get_turf(src), TOUCH) //Then spill it onto the floor.

/obj/item/proc/take_damage(var/incoming_damage)
	var/thisdmg=(incoming_damage>max(damage_armor,damage_resist)) * (incoming_damage-damage_resist) //damage is 0 if the incoming damage is less than either damage_armor or damage_resist, to prevent negative damage by weak attacks
	health_item-=thisdmg
	if(!thisdmg)
		return 0 //return 0 if the item took no damage (glancing attack)
	else
		return 1 //return 1 if the item took damage

/obj/item/examine(mob/user, var/size = "", var/show_name = TRUE, var/show_icon = TRUE)
	..()
	if(health_item<health_item_max && damaged_examine_text)
		user.simple_message("<span class='info'> [damaged_examine_text]</span>",\
			"<span class='notice'> It seems kinda messed up somehow.</span>")
/obj/item/proc/transfer_item_blood_data(obj/item/A,obj/item/B)	//Transfers blood data from one item to another.
	if(!A || !B)
		return
	if(A.had_blood)
		B.blood_color = A.blood_color
		B.blood_DNA = A.blood_DNA
		B.had_blood = TRUE

		if(!blood_overlays[B.type]) //If there isn't a precreated blood overlay make one
			B.generate_blood_overlay()

		if(B.blood_overlay != null) // Just if(blood_overlay) doesn't work.  Have to use isnull here.
			B.overlays.Remove(B.blood_overlay)
		else
			B.blood_overlay = blood_overlays[B.type]

		B.blood_overlay.color = B.blood_color
		B.overlays += B.blood_overlay

/obj/item/proc/generate_break_text(var/glanced = FALSE, var/suppress_glance_text) //Generates text for when an item is hit.
	if(glanced)
		if(suppress_glance_text)
			return "!"
		else if(glances_text)
			return ", but it [pick(glances_text)] off!"
		else
			return ", but it [pick("bounces","gleams","glances")] off!"
	else if(health_item > 0 && !isnull(take_hit_text))
		return ", [pick(take_hit_text)] it!"
	else
		return "!" //Don't say "cracking it" if it breaks because on_broken() will subsequently say "The item shatters!"

/obj/item/proc/break_item(var/atom/target, var/range, var/speed, var/override , var/fly_speed, var/hit_atom) //Breaks the item if its health_item is 0 or below. Passes throw-related parameters to on_broken() to allow for an object's fragments to be thrown upon breaking.
	if(health_item<=0)
		on_broken(target,range,speed,override,fly_speed,hit_atom)
		qdel(src)
		return TRUE //Return TRUE if the item was broken
	else
		return FALSE //Return FALSE if the item wasn't broken

/obj/item/throw_at(var/atom/target, var/range, var/speed, var/override , var/fly_speed) //Called when an item is thrown, and checks if it's broken or not. If it is broken the fragments are thrown instead, otherwise the item is thrown normally.
	if(breakable_flags && break_item(target,range,speed,override,fly_speed))
		return
	else
		..()

/////////////////////

//Breaking items:

//Attacking the item with a wielded weapon or other item
/obj/item/attackby(obj/item/W, mob/user)
	if(isobserver(user) || !Adjacent(user) || user.is_in_modules(src))
		return

	if(user.a_intent == I_HURT && breakable_flags & BREAKABLE_WEAPON)
		if(!isnull(breakable_exclude)) //Check that the weapon isn't specifically excluded from hitting this item
			for(var/obj/item/this_excl in breakable_exclude)
				if(istype(W,this_excl))
					return ..()
		user.do_attack_animation(src, W)
		user.delayNextAttack(1 SECONDS)
		add_fingerprint(user)
		var/glanced=!take_damage(W.force)
		user.visible_message("<span class='warning'>\The [user] [pick(W.attack_verb)] \the [src] with \the [W][generate_break_text(glanced,TRUE)]</span>","<span class='notice'>You hit \the [src] with \the [W][generate_break_text(glanced)]<span>")
		break_item()
		//Break the weapon as well, if applicable, based on its own force.
		if(W.breakable_flags & BREAKABLE_AS_MELEE)
			W.take_damage(min(W.force, BREAKARMOR_MEDIUM)) //Cap it at BREAKARMOR_MEDIUM to avoid a powerful weapon also needing really strong armor to avoid breaking apart when used.
			W.break_item()
	else
		..()

//Simple animals attacking the item
/obj/item/attack_animal(mob/living/simple_animal/M)
	if(M.melee_damage_upper && M.a_intent == I_HURT && breakable_flags & BREAKABLE_UNARMED)
		M.do_attack_animation(src, M)
		M.delayNextAttack(1 SECONDS)
		var/glanced=!take_damage(rand(M.melee_damage_lower,M.melee_damage_upper))
		M.visible_message("<span class='warning'>\The [M] [M.attacktext] \the [src][generate_break_text(glanced,TRUE)]</span>","<span class='notice'>You hit \the [src][generate_break_text(glanced)]</span>")
		break_item()
	else
		..()

//Item ballistically colliding with something

/obj/item/throw_impact(atom/hit_atom, var/speed, mob/user)
	..()
	if(!(breakable_flags & BREAKABLE_AS_THROWN))
		return
	if(breakable_flags & BREAKABLE_NOMOB && istype(hit_atom, /mob)) //Don't break when it hits a mob if it's flagged with BREAKABLE_NOMOB
		return
	if(isturf(loc)) //Don't take damage if it was caught mid-flight.
		//Unless the item falls to the floor unobstructed, impacts happens twice, once when it hits the target, and once when it falls to the floor.
		var/thisdmg = 5 * w_class / speed //impact damage scales with the weight class and speed of the item. since a smaller speed is faster, it's a divisor.
		if(istype(hit_atom, /turf/simulated/floor))
			take_damage(thisdmg/2)
		else
			take_damage(thisdmg)
	break_item(null,null,null,null,null,hit_atom)

//Item being hit by a projectile

/obj/item/bullet_act(var/obj/item/projectile/proj)
	.=..()
	if(breakable_flags & BREAKABLE_WEAPON)
		take_damage(proj.damage)
	var/impact_power = max(0,round((proj.damage_type == BRUTE) * (proj.damage / 3 - (get_total_scaled_w_class(3))))) //The range of the impact-throw is increased by the damage of the projectile, and decreased by the total weight class of the item.
	if(impact_power)
		//Throw the item in the direction the projectile was traveling
		var/propel_dir = get_dir(proj.starting, proj.target)
		var/turf/T = get_edge_target_turf(loc, propel_dir)
		throw_at(T, impact_power, proj.projectile_speed)
	else if(breakable_flags & BREAKABLE_WEAPON)
		break_item()

/obj/item/proc/get_total_scaled_w_class(var/scalepower=3) //Returns a scaled sum of the weight class of the item itself and all of its contents, if any.
	//scalepower raises the w_class of each item to that exponent before adding it to the total. This helps avoid things like a container full of tiny objects being heavier than it should.
	var/total_w_class = (w_class ** scalepower)
	if(!isnull(contents) && contents.len)
		for(var/obj/item/thiscontent in contents)
			total_w_class += (thiscontent.w_class ** scalepower)
	return total_w_class

/*
//Items being used to hit a mob
*/



//TODO:


/*
//Biting the item
/obj/item/bite_act(mob/living/carbon/human/biter)
	if(user.a_intent == I_HURT && breakable_flags & BREAKABLE_MELEE_UNARMED)
	else
		..()
*/




