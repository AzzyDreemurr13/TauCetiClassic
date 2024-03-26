/obj/machinery/holoposter
	name = "Holographic Poster"
	cases = list("голографический плакат", "голографического плаката", "голографическому плакату", "голографический плакат", "голографическим плакатом", "голографичееском плакате")
	desc = "Установленный на стене голографический проектор, показывающий рекламу всевозможных компаний. Сколько же они платят за рекламу здесь?"
	icon = 'icons/obj/holoposter_vr.dmi'
	icon_state = "off"
	anchored = TRUE
	use_power = 1
	idle_power_usage = 80
	power_channel = STATIC_ENVIRON
	vis_flags = VIS_HIDE // They have an emissive that looks bad in openspace due to their wall-mounted nature
	var/icon_forced = FALSE
	var/examine_addon = "Похоже, он выключен."
	var/mytimer
	var/alerting = FALSE

	var/global/list/postertypes = list(
		"hephaestus" = list(LIGHT_COLOR_CYAN, "Hephaestus Aeronautics, a subsidiary of Hephaestus Industries. Known to make the best - if pricy - atmospheric to orbit shuttles and gliders for the consumer market."),
		"aether" = list(LIGHT_COLOR_CYAN, "Aether Atmospherics, one of the lesser-known TSCs. They're ubiquitious in the Periphery - the very air you're breathing was probably sold and delivered by them."),
		"moreau" = list(LIGHT_COLOR_ORANGE, "Children of Moreau. The hologram is a call to action by the local Moreau sect. 'Terraform, Prosper, and Be Sustainable, children!'"),
		"cybersun" = list(LIGHT_COLOR_GREEN, "Cybersun Industries. A complex diagram without labels, showing the inner workings of a backup implant sold by Cybersun. 'The highest quality, for an affordable price!' says the tagline."),
		"veymed" = list(LIGHT_COLOR_GREEN, "Не забудь пройти медосмотр. Здоровье каждого - богатство всех"),
		"grayson" = list(LIGHT_COLOR_ORANGE, "Grayson Manufactories Ltd. An advertisement for a sale from Grayson, including up to 50% off on lathe parts. Truly, a delight for DIY tinkerers out there."),
		"ares" = list(LIGHT_COLOR_PINK, "Friends of Ares. Who managed to slip this poster into the rotation? A local charity set up by the Ares Confederation to help workers unionize or found their own colonies. 'Donate today!'"),
		"moebius" = list(LIGHT_COLOR_PURPLE, "Moebius. One of the few companies worth merit beyond their local bubble staffed completely by synthetics. 'For synths, by synths.'")
	)

/obj/machinery/holoposter/atom_init()
	. = ..()
	set_rand_sprite()
	holoposter_list += src
	mytimer = addtimer(CALLBACK(src, PROC_REF(set_rand_sprite)), 30 MINUTES + rand(0, 5 MINUTES), TIMER_STOPPABLE | TIMER_LOOP)

/obj/machinery/holoposter/Destroy()
	holoposter_list -= src
	return ..()

/obj/machinery/holoposter/process()
	return PROCESS_KILL

/obj/machinery/holoposter/examine(mob/user, infix, suffix)
	. = ..()
	. += examine_addon

/obj/machinery/holoposter/update_icon()
	if(stat & NOPOWER)
		icon_state = "off"
		examine_addon = "Похоже, он выключен."
		set_light(0)
		return
	var/new_color = LIGHT_COLOR_HALOGEN
	if(stat & BROKEN)
		icon_state = "glitch"
		examine_addon = "Похоже, произошёл сбой."
		new_color = "#6A6C71"
	else
		if(global.security_level) // 0 is fine, everything higher is alert levels
			icon_state = "attention"
			examine_addon = "Это предупреждает вас сохранять спокойствие и как можно скорее связаться со своим руководителем отдела."
			new_color =  "#AA7039"
			alerting = TRUE
		else if(alerting && !global.security_level) // coming out of alert
			alerting = FALSE
			set_rand_sprite()
			return
		else if(icon_state in postertypes)
			var/list/settings = postertypes[icon_state]
			new_color = settings[1]
			examine_addon = settings[2]

	set_light(l_range = 2, l_power = 2, l_color = new_color)

/obj/machinery/holoposter/proc/set_rand_sprite()
	if(alerting)
		return
	if(icon_forced && mytimer)
		deltimer(mytimer)
		return
	icon_state = pick(postertypes)
	update_icon()

/obj/machinery/holoposter/attackby(obj/item/W, mob/user)
	src.add_fingerprint(user)
	if(stat & (NOPOWER))
		return

/obj/machinery/holoposter/attack_ai(mob/user as mob)
	return attack_hand(user)

/obj/machinery/holoposter/power_change()
	var/wasUnpowered = stat & NOPOWER
	..()
	if(wasUnpowered != (stat & NOPOWER))
		update_icon()

/obj/machinery/holoposter/emp_act()
	stat |= BROKEN
	update_icon()
