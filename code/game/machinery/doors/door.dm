/obj/machinery/door
	name = "door"
	desc = "It opens and closes."
	icon = 'icons/obj/doors/Doorint.dmi'
	icon_state = "door1"
	anchored = 1
	opacity = 1
	density = 1
	layer = OPEN_DOOR_LAYER
	power_channel = ENVIRON
	obj_integrity = 350
	max_integrity = 350
	armor = list(melee = 30, bullet = 30, laser = 20, energy = 20, bomb = 10, bio = 100, rad = 100, fire = 80, acid = 70)
	CanAtmosPass = ATMOS_PASS_DENSITY

	var/secondsElectrified = 0
	var/shockedby = list()
	var/visible = 1
	var/operating = 0
	var/glass = 0
	var/welded = 0
	var/normalspeed = 1
	var/heat_proof = 0 // For rglass-windowed airlocks and firedoors
	var/emergency = 0 // Emergency access override
	var/sub_door = 0 // 1 if it's meant to go under another door.
	var/closingLayer = CLOSED_DOOR_LAYER
	var/autoclose = 0 //does it automatically close after some time
	var/safe = 1 //whether the door detects things and mobs in its way and reopen or crushes them.
	var/locked = 0 //whether the door is bolted or not.
	var/assemblytype //the type of door frame to drop during deconstruction
	var/auto_close //TO BE REMOVED, no longer used, it's just preventing a runtime with a map var edit.
	var/datum/effect_system/spark_spread/spark_system
	var/damage_deflection = 10

/obj/machinery/door/New()
	..()
	if(density)
		layer = CLOSED_DOOR_LAYER //Above most items if closed
	else
		layer = OPEN_DOOR_LAYER //Under all objects if opened. 2.7 due to tables being at 2.6
	update_freelook_sight()
	air_update_turf(1)
	airlocks += src
	spark_system = new /datum/effect_system/spark_spread
	spark_system.set_up(2, 1, src)



/obj/machinery/door/Destroy()
	density = 0
	air_update_turf(1)
	update_freelook_sight()
	airlocks -= src
	if(spark_system)
		qdel(spark_system)
		spark_system = null
	return ..()

//process()
	//return

/obj/machinery/door/Bumped(atom/AM)
	if(operating || emagged)
		return

	if(isliving(AM))
		var/mob/living/M = AM
		if(world.time - M.last_bumped <= 10)
			return	//Can bump-open one airlock per second. This is to prevent shock spam.
		M.last_bumped = world.time
		if(M.restrained() && !check_access(null))
			return
		bumpopen(M)
		return

	if(istype(AM, /obj/mecha))
		var/obj/mecha/mecha = AM
		if(density)
			if(mecha.occupant)
				if(world.time - mecha.occupant.last_bumped <= 10)
					return
				mecha.occupant.last_bumped = world.time
			if(mecha.occupant && (src.allowed(mecha.occupant) || src.check_access_list(mecha.operation_req_access) || emergency == 1))
				open()
			else
				do_animate("deny")
		return
	return

/obj/machinery/door/Move()
	var/turf/T = loc
	..()
	move_update_air(T)

/obj/machinery/door/CanPass(atom/movable/mover, turf/target, height=0)
	if(istype(mover) && mover.checkpass(PASSGLASS))
		return !opacity
	return !density

/obj/machinery/door/proc/bumpopen(mob/user)
	if(operating)
		return
	src.add_fingerprint(user)
	if(!src.requiresID())
		user = null

	if(density && !emagged)
		if(allowed(user) || src.emergency == 1)
			open()
		else
			do_animate("deny")
	return


/obj/machinery/door/attack_ai(mob/user)
	return src.attack_hand(user)

/obj/machinery/door/attack_hand(mob/user)
	return try_to_activate_door(user)


/obj/machinery/door/attack_tk(mob/user)
	if(requiresID() && !allowed(null))
		return
	..()

/obj/machinery/door/proc/try_to_activate_door(mob/user)
	add_fingerprint(user)
	if(operating || emagged)
		return
	if(!requiresID())
		user = null //so allowed(user) always succeeds
	if(allowed(user) || emergency == 1)
		if(density)
			open()
		else
			close()
		return
	if(density)
		do_animate("deny")

/obj/machinery/door/proc/try_to_weld(obj/item/weapon/weldingtool/W, mob/user)
	return

/obj/machinery/door/proc/try_to_crowbar(obj/item/I, mob/user)
	return

/obj/machinery/door/attackby(obj/item/I, mob/user, params)
	if(user.a_intent != INTENT_HARM && (istype(I, /obj/item/weapon/crowbar) || istype(I, /obj/item/weapon/twohanded/fireaxe)))
		try_to_crowbar(I, user)
		return 1
	else if(istype(I, /obj/item/weapon/weldingtool))
		try_to_weld(I, user)
		return 1
	else if(!(I.flags & NOBLUDGEON) && user.a_intent != INTENT_HARM)
		try_to_activate_door(user)
		return 1
	else
		return ..()

/obj/machinery/door/run_obj_armor(damage_amount, damage_type, damage_flag = 0, attack_dir)
	if(damage_flag == "melee" && damage_amount < damage_deflection)
		return 0
	. = ..()

/obj/machinery/door/take_damage(damage_amount, damage_type = BRUTE, damage_flag = 0, sound_effect = 1, attack_dir)
	. = ..()
	if(. && obj_integrity > 0)
		if(damage_amount >= 10 && prob(30))
			spark_system.start()

/obj/machinery/door/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			if(glass)
				playsound(loc, 'sound/effects/Glasshit.ogg', 90, 1)
			else if(damage_amount)
				playsound(loc, 'sound/weapons/smash.ogg', 50, 1)
			else
				playsound(src, 'sound/weapons/tap.ogg', 50, 1)
		if(BURN)
			playsound(src.loc, 'sound/items/Welder.ogg', 100, 1)

/obj/machinery/door/emp_act(severity)
	if(prob(20/severity) && (istype(src,/obj/machinery/door/airlock) || istype(src,/obj/machinery/door/window)) )
		open()
	if(prob(40/severity))
		if(secondsElectrified == 0)
			secondsElectrified = -1
			shockedby += "\[[time_stamp()]\]EM Pulse"
			addtimer(src, "unelectrify", 300)
	..()

/obj/machinery/door/proc/unelectrify()
	secondsElectrified = 0

/obj/machinery/door/update_icon()
	if(density)
		icon_state = "door1"
	else
		icon_state = "door0"

/obj/machinery/door/proc/do_animate(animation)
	switch(animation)
		if("opening")
			if(panel_open)
				flick("o_doorc0", src)
			else
				flick("doorc0", src)
		if("closing")
			if(panel_open)
				flick("o_doorc1", src)
			else
				flick("doorc1", src)
		if("deny")
			if(!stat)
				flick("door_deny", src)


/obj/machinery/door/proc/open()
	if(!density)
		return 1
	if(operating)
		return
	if(!ticker || !ticker.mode)
		return 0
	operating = 1
	do_animate("opening")
	SetOpacity(0)
	sleep(5)
	density = 0
	sleep(5)
	layer = OPEN_DOOR_LAYER
	update_icon()
	SetOpacity(0)
	operating = 0
	air_update_turf(1)
	update_freelook_sight()
	if(autoclose)
		spawn(autoclose)
			close()
	return 1

/obj/machinery/door/proc/close()
	if(density)
		return 1
	if(operating)
		return
	if(safe)
		for(var/atom/movable/M in get_turf(src))
			if(M.density && M != src) //something is blocking the door
				if(autoclose)
					addtimer(src, "autoclose", 60)
				return
	operating = 1

	do_animate("closing")
	layer = closingLayer
	sleep(5)
	density = 1
	sleep(5)
	update_icon()
	if(visible && !glass)
		SetOpacity(1)
	operating = 0
	air_update_turf(1)
	update_freelook_sight()
	if(safe)
		CheckForMobs()
	else
		crush()
	return 1

/obj/machinery/door/proc/CheckForMobs()
	if(locate(/mob/living) in get_turf(src))
		sleep(1)
		open()

/obj/machinery/door/proc/crush()
	for(var/mob/living/L in get_turf(src))
		if(isalien(L))  //For xenos
			L.adjustBruteLoss(DOOR_CRUSH_DAMAGE * 1.5) //Xenos go into crit after aproximately the same amount of crushes as humans.
			L.emote("roar")
		else if(ishuman(L)) //For humans
			L.adjustBruteLoss(DOOR_CRUSH_DAMAGE)
			L.emote("scream")
			L.Weaken(5)
		else if(ismonkey(L)) //For monkeys
			L.adjustBruteLoss(DOOR_CRUSH_DAMAGE)
			L.Weaken(5)
		else //for simple_animals & borgs
			L.adjustBruteLoss(DOOR_CRUSH_DAMAGE)
		var/turf/location = get_turf(src)
		//add_blood doesn't work for borgs/xenos, but add_blood_floor does.
		L.add_splatter_floor(location)
	for(var/obj/mecha/M in get_turf(src))
		M.take_damage(DOOR_CRUSH_DAMAGE)

/obj/machinery/door/proc/autoclose()
	if(!qdeleted(src) && !density && !operating && !locked && !welded && autoclose)
		close()

/obj/machinery/door/proc/requiresID()
	return 1

/obj/machinery/door/proc/hasPower()
	return !(stat & NOPOWER)

/obj/machinery/door/proc/update_freelook_sight()
	if(!glass && cameranet)
		cameranet.updateVisibility(src, 0)

/obj/machinery/door/BlockSuperconductivity() // All non-glass airlocks block heat, this is intended.
	if(opacity || heat_proof)
		return 1
	return 0

/obj/machinery/door/morgue
	icon = 'icons/obj/doors/doormorgue.dmi'

/obj/machinery/door/storage_contents_dump_act(obj/item/weapon/storage/src_object, mob/user)
	return 0

/obj/machinery/door/proc/lock()
	return

/obj/machinery/door/proc/unlock()
	return

/obj/machinery/door/proc/hostile_lockdown(mob/origin)
	if(!stat) //So that only powered doors are closed.
		close() //Close ALL the doors!

/obj/machinery/door/proc/disable_lockdown()
	if(!stat) //Opens only powered doors.
		open() //Open everything!

