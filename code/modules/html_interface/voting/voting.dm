var/global/datum/controller/vote/vote = new()
#define vote_head "<script type=\"text/javascript\" src=\"3-jquery.timers.js\"></script><script type=\"text/javascript\" src=\"libraries.min.js\"></script><link rel=\"stylesheet\" type=\"text/css\" href=\"html_interface_icons.css\" /><link rel=\"stylesheet\" type=\"text/css\" href=\"voting.css\" /><script type=\"text/javascript\" src=\"voting.js\"></script>"

#define VOTE_SCREEN_WIDTH 400
#define VOTE_SCREEN_HEIGHT 400

/datum/html_interface/nanotrasen/vote/registerResources()
	. = ..()

	register_asset("voting.js", 'voting.js')
	register_asset("voting.css", 'voting.css')

/datum/html_interface/nanotrasen/vote/sendAssets(var/client/client)
	..()

	send_asset(client, "voting.js")
	send_asset(client, "voting.css")

/datum/html_interface/nanotrasen/vote/Topic(href, href_list[])
	..()
	if(href_list["html_interface_action"] == "onclose")
		var/datum/html_interface_client/hclient = getClient(usr.client)
		if (istype(hclient))
			src.hide(hclient)
			vote.cancel_vote(usr)


/datum/controller/vote
	var/initiator      = null
	var/started_time   = null
	var/time_remaining = 0
	var/mode           = null
	var/question       = null
	var/list/ismapvote
	var/chosen_map
	var/winner 		 	= null
	name               = "datum"
	var/datum/html_interface/nanotrasen/vote/interface

	//vote data
	var/list/voters		//assoc. list: user.ckey, choices
	var/list/tally		//assoc. list: choices, count
	var/list/choices = list() //choices
	var/choice
	var/count

	var/list/status_data
	var/last_update    = 0
	var/initialized    = 0
	var/lastupdate     = 0

	var/currently_voting = FALSE // If we are already voting, don't allow another one

	// Jesus fuck some shitcode is breaking because it's sleeping and the SS doesn't like it.
	var/lock = FALSE

/datum/controller/vote/New()
	. = ..()
	src.voters = list()
	src.tally = list()
	src.status_data = list()
	src.choice = choice
	src.count = count
	spawn(5)
		if(!src.interface)
			src.interface = new/datum/html_interface/nanotrasen/vote(src, "Voting Panel", 400, 400, vote_head)
			src.interface.updateContent("content", "<div id='vote_main'></div><div id='vote_choices'></div><div id='vote_admin'></div>")
		initialized = 1
	if (vote != src)
		if (istype(vote))
			qdel(vote)
		vote = src

/datum/controller/vote/proc/process()	//called by master_controller
	if (lock)
		return
	if(mode)
		lock = TRUE
		// No more change mode votes after the game has started.
		// 3 is GAME_STATE_PLAYING, but that #define is undefined for some reason
		if(mode == "gamemode" && ticker.current_state >= 2)
			to_chat(world, "<b>Voting aborted due to game start.</b>")
			src.reset()
			return

		// Calculate how much time is remaining by comparing current time, to time of vote start,
		// plus vote duration
		time_remaining = (ismapvote && ismapvote.len) ? (round((started_time + 600 - world.time)/10)) : (round((started_time + config.vote_period - world.time)/10))

		if(time_remaining <= 0)
			result()
			for(var/ckey in voters) //hide voting interface using ckeys
				var/client/C = directory[ckey]
				if(C)
					src.interface.hide(C)
			src.reset()
		else
			update(1)

		lock = FALSE

/datum/controller/vote/proc/reset()
	currently_voting = FALSE
	winner = null
	initiator = null
	time_remaining = 0
	mode = null
	question = null
	choices.len = 0
	voters.len = 0
	tally.len = 0
	update(1)

/datum/controller/vote/proc/get_result()
	//get the highest number of votes
	currently_voting = FALSE
	//default-vote for everyone who didn't vote
	var/non_voters = clients.len - get_total()

	if(!config.vote_no_default && choices.len)
		//clients with voting initialized
		if(non_voters > 0)
			if(mode == "restart")
				tally["Continue Playing"] += non_voters
			if(mode == "gamemode")
				if(master_mode in choices)
					tally[master_mode] += non_voters
			if(mode == "crew_transfer")
				var/factor = 0.0107*world.time**0.393 //magical factor between approx. 0.5 and 1.4
				factor = max(factor,0.5)
				tally["Initiate Crew Transfer"] = round(tally["Initiate Crew Transfer"] * factor)
				to_chat(world, "<font color='purple'>Crew Transfer Factor: [factor]</font>")
	//choose the method for voting: "WEIGHTED" = 0, "MAJORITY" = 1		
	switch(config.toggle_vote_method)
		if(0)
			return weighted()
		if(1)
			return majority()
		if(2)
			if(mode == "map")
				return majority()//return persistent()
			else
				return majority()
		else
			return majority()
		
/datum/controller/vote/proc/majority()
	var/text
	var/feedbackanswer
	var/greatest_votes = 0
	if (tally.len > 0)
		var/list/winners = list()
		sortTim(tally, /proc/cmp_numeric_dsc,1)
		greatest_votes = tally[tally[1]]
		for (var/c in tally)
			if (tally[c]  == greatest_votes)//must be true a least once
				winners += c
		if (winners.len > 1)
			text = "<b>Vote Tied Between:</b><br>"
			for(var/option in winners)
				text += "\t[option]<br>"
				feedbackanswer = jointext(winners, " ")
		winner = tally[1]
		if(mode == "map")
			if(!feedbackanswer)
				feedbackanswer = winner
				feedback_set("map vote winner", feedbackanswer)
			else
				feedback_set("map vote tie", "[feedbackanswer] chosen: [winner]")
		text += "<b>Vote Result: [winner] won with [greatest_votes] vote\s.</b>"
		for(var/c in tally)
			if(winner != c)
				text += "<br>\t [c] had [tally[c] != null ? tally[c] : "0"]."
	else
		text += "<b>Vote Result: Inconclusive - No Votes!</b>"
	return text

/datum/controller/vote/proc/weighted()
	var/vote_threshold = 0.15
	var/list/discarded_choices = list()
	var/discarded_votes = 0
	var/total_votes = get_total()
	var/text
	var/list/filteredchoices = tally.Copy()
	var/qualified_votes
	if (total_votes > 0)
		for(var/a in filteredchoices)
			if(!filteredchoices[a])
				filteredchoices -= a //Remove choices with 0 votes, as pickweight gives them 1 vote
				continue
			if(filteredchoices[a] / total_votes < vote_threshold)
				discarded_votes += filteredchoices[a]
				filteredchoices -= a
				discarded_choices += a
		if(filteredchoices.len)
			winner = pickweight(filteredchoices.Copy())
		qualified_votes = total_votes - discarded_votes
		text += "<b>Random Weighted Vote Result: [winner] won with [tally[winner]] vote\s and a [round(100*tally[winner]/qualified_votes)]% chance of winning.</b>"
		for(var/choice in choices)
			if(winner != choice)
				text += "<br>\t [choice] had [tally[choice] != null ? tally[choice] : "0"] vote\s[(tally[choice])? " and [(choice in discarded_choices) ? "did not get enough votes to qualify" : "a [round(100*tally[choice]/qualified_votes)]% chance of winning"]" : null]."
	else
		text += "<b>Vote Result: Inconclusive - No Votes!</b>"
	return text

/datum/controller/vote/proc/announce_result()
	currently_voting = FALSE
	var/result = get_result()
	log_vote(result)
	to_chat(world, "<font color='purple'>[result]</font>")

/datum/controller/vote/proc/result()
	announce_result()
	currently_voting = FALSE
	var/restart = 0
	if(winner)
		switch(mode)
			if("restart")
				if(winner == "Restart Round")
					restart = 1
			if("gamemode")
				if(master_mode != winner)
					world.save_mode(winner)
					if(ticker && ticker.mode)
						restart = 1
					else
						master_mode = winner
				if(!going)
					going = 1
					to_chat(world, "<span class='red'><b>The round will start soon.</b></span>")
			if("crew_transfer")
				if(winner == "Initiate Crew Transfer")
					init_shift_change(null, 1)
			if("map")
				if(winner)
					chosen_map = "maps/voting/" + ismapvote[winner] + "/vgstation13.dmb"
					watchdog.chosen_map = ismapvote[winner]
					log_game("Players voted and chose.... [watchdog.chosen_map]!")
	if(restart)
		to_chat(world, "World restarting due to vote...")
		feedback_set_details("end_error","restart vote")
		if(blackbox)
			blackbox.save_all_data_to_sql()
		CallHook("Reboot",list())
		sleep(50)
		log_game("Rebooting due to restart vote")
		world.Reboot()

/datum/controller/vote/proc/submit_vote(var/mob/user, var/vote)
	if(mode)
		if(config.vote_no_dead && user.stat == DEAD && !user.client.holder)
			return 0
		if (isnum(vote) && (1>vote) || (vote > choices.len))
			to_chat(user, "<span class='warning'>Illegal vote.</span>")
			return 0
		if(mode == "map")
			if(!user.client.holder)
				if(isnewplayer(user))
					to_chat(user, "<span class='warning'>Only players that have joined the round may vote for the next map.</span>")
					return 0
				if(isobserver(user))
					var/mob/dead/observer/O = user
					if(O.started_as_observer)
						to_chat(user, "<span class='warning'>Only players that have joined the round may vote for the next map.</span>")
						return 0
		//check vote then remove vote
		if(vote && vote == "cancel_vote")
			cancel_vote(user)
		//add vote
		else if(vote && vote != "cancel_vote")
			add_vote(user, vote)
			return vote //do we need this?
		else
			to_chat(user, "<span class='warning'>You may only vote once.</span>")
	return 0

/datum/controller/vote/proc/get_vote(var/mob/user, var/num = FALSE)
	var/mob_ckey = user.ckey
	//returns voter's choice
	if(mob_ckey)
		if(voters[mob_ckey])
			if(num)
				return choices.Find(voters[mob_ckey])
			else
				return voters[mob_ckey]
	return 0

/datum/controller/vote/proc/add_vote(var/mob/user, var/vote)
	var/mob_ckey = user.ckey
	//adds voter's choice and adds to tally. vote was passed as numbers
	if(voters[mob_ckey])
		cancel_vote(user)
	tally[choices[vote]]++
	voters[mob_ckey] += choices[vote]

/datum/controller/vote/proc/cancel_vote(var/mob/user)
	var/mob_ckey = user.ckey
	if (voters[mob_ckey])
		tally[voters[mob_ckey]]--
		voters -= mob_ckey

/datum/controller/vote/proc/get_total()
	var/total = 0
	//loop through choices in tally for count and add them up
	for (var/c in tally)
		if(c)
			total += tally[c]
	return total

/datum/controller/vote/proc/initiate_vote(var/vote_type, var/initiator_key, var/popup = 0)
	var/mob/user = usr
	if(currently_voting)
		message_admins("<span class='info'>[initiator_key] attempted to begin a vote, however a vote is already in progress.</span>")
		return
	currently_voting = TRUE
	if(!mode)
		if(started_time != null && !check_rights(R_ADMIN))
			var/next_allowed_time = (started_time + config.vote_delay)
			if(next_allowed_time > world.time)
				return 0

		reset()
		switch(vote_type)
			if("restart")
				choices.Add("Restart Round","Continue Playing")
				question = "Restart the round?"
			if("gamemode")
				if(ticker.current_state >= 2)
					return 0
				choices.Add(config.votable_modes)
				question = "What gamemode?"
			if("crew_transfer")
				if(ticker.current_state <= 2)
					return 0
				question = "End the shift?"
				choices.Add("Initiate Crew Transfer", "Continue The Round")
			if("custom")
				question = html_encode(input(user,"What is the vote for?") as text|null)
				if(!question)
					return 0
				for(var/i in 1 to 10)
					var/option = capitalize(html_encode(input(user,"Please enter an option or hit cancel to finish") as text|null))
					if(!option || mode || !user.client)
						break
					choices.Add(option)
			if("map")
				var/list/maps
				question = "What should the next map be?"
				if (config.toggle_maps)
					maps = get_all_maps()
				else
					maps = get_votable_maps()
				for(var/map in maps)
					choices.Add(map)
				if(!choices.len)
					to_chat(world, "<span class='danger'>Failed to initiate map vote, no maps found.</span>")
					return 0
				ismapvote = maps
			else
				return 0

		mode = vote_type
		initiator = initiator_key
		started_time = world.time
		var/text = "[capitalize(mode)] vote started by [initiator]."
		choices = shuffle(choices)
		//initialize tally
		for (var/c in choices)
			tally[c] = 0
		if(mode == "custom")
			text += "<br>[question]"

		log_vote(text)
		update(1)
		if(popup)
			for(var/client/C in clients)
				if(vote_type == "map" && !C.holder)
					if(C.mob)
						var/mob/M = C.mob
						//Do not prompt non-admin new players or round start observers for a map vote - Pomf
						if(isnewplayer(M))
							continue
						if(isobserver(M))
							var/mob/dead/observer/O = M
							if(O.started_as_observer)
								continue
				interact(C)
		else
			if(istype(user) && user.client)
				interact(user.client)

		to_chat(world, "<font color='purple'><b>[text]</b><br> <a href='?src=\ref[vote]'>Click here</a> or type 'vote' to place your votes.<br>You have [ismapvote && ismapvote.len ? "60" : config.vote_period/10] seconds to vote.</font>")
		switch(vote_type)
			if("crew_transfer")
				world << sound('sound/voice/Serithi/Shuttlehere.ogg')
			if("gamemode")
				world << sound('sound/voice/Serithi/pretenddemoc.ogg')
			if("custom")
				world << sound('sound/voice/Serithi/weneedvote.ogg')
			if("map")
				world << sound('sound/misc/rockthevote.ogg')

		if(mode == "gamemode" && going)
			going = 0
			to_chat(world, "<span class='red'><b>Round start has been delayed.</b></span>")

		time_remaining = (ismapvote && ismapvote.len ? 60 : round(config.vote_period/10))
		return 1
	return 0

/datum/controller/vote/proc/updateFor(hclient_or_mob)
	// This check will succeed if updateFor is called after showing to the player, but will fail
	// on regular updates. Since we only really need this once we don't care if it fails.

	interface.callJavaScript("clearAll", new/list(), hclient_or_mob)
	interface.callJavaScript("update_mode", status_data, hclient_or_mob)
	if(tally.len)
		for (var/i = 1; i <= tally.len; i++)
			var/list/L = list(i, tally[i], tally[tally[i]])
			interface.callJavaScript("update_choices", L, hclient_or_mob)
			
/datum/controller/vote/proc/interact(client/user)
	set waitfor = FALSE // So we don't wait for each individual client's assets to be sent.

	if(!user || !initialized)
		return

	if(ismob(user))
		var/mob/M = user
		if(M.client)
			user = M.client
		else
			CRASH("The user [M.name] of type [M.type] has been passed as a mob reference without a client to voting.interact()")

	interface.show(user)
	var/list/client_data = list()
	var/admin = 0

	//adds client data
	if(get_vote(user))
		client_data += list(get_vote(user,TRUE))
	else
		client_data += list(0)
	if(user.holder)
		admin = 1
		if(user.holder.rights & R_ADMIN)
			admin = 2
	client_data += list(admin)
	interface.callJavaScript("client_data", client_data, user)
	src.updateFor(user, interface)

/datum/controller/vote/proc/update(refresh = 0)
	if(!interface)
		interface = new/datum/html_interface/nanotrasen/vote(src, "Voting Panel", 400, 400, vote_head)
		interface.updateContent("content", "<div id='vote_main'></div><div id='vote_choices'></div><div id='vote_admin'></div>")

	if(world.time < last_update + 2)
		return
	last_update = world.time
	status_data.len = 0
	status_data += list(mode)
	status_data += list(question)
	status_data += list(time_remaining)
	if(config.allow_vote_restart)
		status_data += list(1)
	else
		status_data += list(0)
	if(config.allow_vote_mode)
		status_data += list(1)
	else
		status_data += list(0)
	if(config.toggle_maps)
		status_data += list(1)
	else
		status_data += list(0)
	if(config.toggle_vote_method)
		status_data += list(1)
	else
		status_data += list(0)

	if(refresh && interface)
		updateFor()

/datum/controller/vote/Topic(href,href_list[],hsrc)
	var/mob/user = usr
	if(!user || !user.client)
		return	//not necessary but meh...just in-case somebody does something stupid
	switch(href_list["vote"])
		if ("cancel_vote")
			cancel_vote(user)
			src.updateFor(user.client)
			return 0
		if("cancel")
			if(user.client.holder)
				if(alert("Are you sure you want to cancel this vote? This will not display the results, and for a map vote, re-use the current map.","Confirm","Yes","No") != "Yes")
					return
				log_admin("[user] has cancelled a vote currently taking place. Vote type: [mode], question, [question].")
				message_admins("[user] has cancelled a vote currently taking place. Vote type: [mode], question, [question].")
				reset()
				update()
				currently_voting = FALSE
		if("toggle_restart")
			if(user.client.holder)
				config.allow_vote_restart = !config.allow_vote_restart
				update()
		if("toggle_gamemode")
			if(user.client.holder)
				config.allow_vote_mode = !config.allow_vote_mode
				update()
		if("restart")
			if(config.allow_vote_restart || user.client.holder)
				initiate_vote("restart",user)
		if("gamemode")
			if(config.allow_vote_mode || user.client.holder)
				initiate_vote("gamemode",user)
		if("crew_transfer")
			if(config.allow_vote_restart || user.client.holder)
				initiate_vote("crew_transfer",user)
		if("custom")
			if(user.client.holder)
				initiate_vote("custom",user)
		if("map")
			if(user.client.holder)
				initiate_vote("map",user)
		if("toggle_map")
			if(user.client.holder)
				config.toggle_maps = !config.toggle_maps
				update()
		if("toggle_vote_method")
			if(user.client.holder)
				config.toggle_vote_method = !config.toggle_vote_method
				update()
		else
			submit_vote(user, round(text2num(href_list["vote"])))
	user.vote()


/mob/verb/vote()
	var/mob/user = usr
	set category = "OOC"
	set name = "Vote"
	if(vote)
		if(!vote.initialized)
			to_chat(user, "<span class='info'>The voting controller isn't fully initialized yet.</span>")
		else
			vote.interact(user.client)