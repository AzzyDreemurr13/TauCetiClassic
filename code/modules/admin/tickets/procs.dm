//
// CLIENT PROCS
//

/client/verb/mentorhelp(msg as text)
	set category = "Admin"
	set name = "Mentorhelp"

	//handle muting and automuting
	if(prefs.muted & MUTE_PM)
		to_chat(src, span_danger("Error: Mentor-PM: You cannot send adminhelps (Muted)."))
		return
	if(handle_spam_prevention(msg,MUTE_PM))
		return

	if(!msg)
		return

	//remove out adminhelp verb temporarily to prevent spamming of admins.
	remove_verb(src,/client/verb/mentorhelp)
	spawn(600)
		add_verb(src,/client/verb/mentorhelp	) // 1 minute cool-down for mentorhelps

	feedback_add_details("admin_verb","Mentorhelp") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!
	if(current_ticket)
		var/input = tgui_alert(src, "You already have a ticket open. Is this for the same issue?","Duplicate?",list("Yes","No"))
		if(!input)
			return
		if(input == "Yes")
			if(current_ticket)
				log_admin("Mentorhelp: [key_name(src)]: [msg]")
				current_ticket.MessageNoRecipient(msg)
				to_chat(src, span_adminnotice(span_mentor("Mentor-PM to-" + span_bold("Mentors") + ": [msg]")))
				return
			else
				to_chat(src, span_warning("Ticket not found, creating new one..."))
		else
			current_ticket.AddInteraction("[usr.ckey] opened a new ticket.")
			current_ticket.Resolve()

	new /datum/ticket(msg, src, FALSE, 0)

//admin proc
ADMIN_VERB(cmd_mentor_ticket_panel, (R_ADMIN|R_SERVER) && !(ckey in mentor_ckeys), "Mentor Ticket List", "Opens the list of mentor tickets", "Admin.Misc")
	var/browse_to

	switch(tgui_input_list(user, "Display which ticket list?", "List Choice", list("Active Tickets", "Resolved Tickets")))
		if("Active Tickets")
			browse_to = AHELP_ACTIVE
		if("Resolved Tickets")
			browse_to = AHELP_RESOLVED
		else
			return

	GLOB.tickets.BrowseTickets(browse_to)

/proc/message_mentors(var/msg)
	msg = span_mentor_channel(span_prefix("Mentor:") + span_message("[msg]"))

	for(var/client/C in GLOB.admins)
		to_chat(C, msg)

//
// CLIENT PROCS
//

/client/verb/requesthelp()
	set category = "Admin"
	set name = "Request help"
	set hidden = 1

	var/mhelp = tgui_alert(usr, "Select the help you need.","Request for Help",list("Adminhelp","Mentorhelp"))
	if(!mhelp)
		return

	var/msg = tgui_input_text(usr, "Input your request for help.", "Request for Help ([mhelp])", multiline = TRUE)
	if(!msg)
		return

	if (mhelp == "Mentorhelp")
		mentorhelp(msg)
		return

	adminhelp(msg)

//
// CLIENT PROCS
//

/client/proc/is_ahelp_cooldown()
	var/ahelp_cooldown_timeleft = ahelp_tickets.ckey_cooldown_holder[ckey]
	if(ahelp_cooldown_timeleft && world.time < ahelp_cooldown_timeleft)
		to_chat_admin_pm(src, "<span class='notice'>You cannot use \"Adminhelp\" so often. Please wait another [round((ahelp_cooldown_timeleft - world.time) / 10, 1)] seconds.</span>")
		return TRUE
	else
		return FALSE

/proc/giveadminhelpverb(ckey)
	ahelp_tickets.ckey_cooldown_holder[ckey] = 0

/client/verb/adminhelp()
	set category = "Admin"
	set name = "Adminhelp"

	if(global.say_disabled)	//This is here to try to identify lag problems
		to_chat_admin_pm(src, "<span class='warning'>Speech is currently admin-disabled.</span>")
		return

	//handle muting and automuting
	if(prefs.muted & MUTE_PM || IS_ON_ADMIN_CD(src, ADMIN_CD_PM))
		to_chat_admin_pm(src, "<span class='warning'>Error: Admin-PM: You cannot send adminhelps (Muted).</span>")
		return

	if(is_ahelp_cooldown())
		return

	var/msg = sanitize(input(src, "Please describe your problem concisely and an admin will help as soon as they're able.", "Adminhelp contents") as message|null)
	if(!msg)
		return

	if(is_ahelp_cooldown())
		return

	if(handle_spam_prevention(msg, ADMIN_CD_PM))
		return

	if(current_ticket)
		if(tgui_alert(src, "You already have a ticket open. Is this for the same issue?",, list("Yes","No")) != "No")
			if(current_ticket)
				current_ticket.MessageNoRecipient(msg, TRUE)
				current_ticket.TimeoutVerb()
				return
			else
				to_chat_admin_pm(src, "<span class='warning'>Ticket not found, creating new one...</span>")
		else
			current_ticket.AddInteraction("[key_name_admin(src)] opened a new ticket.")
			current_ticket.Close()

	new /datum/admin_help(msg, src, FALSE)

//
// LOGGING
//

//Use this proc when an admin takes action that may be related to an open ticket on what
//what can be a client, ckey, or mob
/proc/admin_ticket_log(what, message)
	var/client/C
	var/mob/Mob = what
	if(istype(Mob))
		C = Mob.client
	else
		C = what
	if(istype(C) && C.current_ticket)
		C.current_ticket.AddInteraction(message)
		return C.current_ticket
	if(istext(what))	//ckey
		var/datum/admin_help/AH = global.ahelp_tickets.CKey2ActiveTicket(what)
		if(AH)
			AH.AddInteraction(message)
			return AH

//
// HELPER PROCS
//

/proc/get_admin_counts(requiredflags = R_BAN)
	. = list("total" = list(), "noflags" = list(), "afk" = list(), "stealth" = list(), "present" = list())
	for(var/client/X in global.admins)
		.["total"] += X
		if(requiredflags != 0 && !check_rights_for(X, requiredflags))
			.["noflags"] += X
		else if(X.is_afk())
			.["afk"] += X
		else if(X.holder.fakekey)
			.["stealth"] += X
		else
			.["present"] += X

/proc/get_admin_counts_formatted(requiredflags = R_BAN)
	var/list/adm = get_admin_counts(requiredflags)

	if(!length(adm["total"]))
		. = "No admins online"
	else if (!length(adm["present"]))
		. = "No active admins online; Stealthed\[[get_english_list(adm["stealth"])]\]; AFK\[[get_english_list(adm["afk"])]\]; Powerless\[[get_english_list(adm["noflags"])]\];"
	else
		. = "Active\[[get_english_list(adm["present"])]\]; Stealthed\[[get_english_list(adm["stealth"])]\]; AFK\[[get_english_list(adm["afk"])]\]; Powerless\[[get_english_list(adm["noflags"])]\];"

/proc/send2bridge_adminless_only(title, msg, requiredflags = R_BAN, type, mention)
	var/list/adm = get_admin_counts(requiredflags)
	var/list/activemins = adm["present"]
	. = activemins.len
	if(. <= 0)
		var/final = ""
		var/list/afkmins = adm["afk"]
		var/list/stealthmins = adm["stealth"]
		var/list/powerlessmins = adm["noflags"]
		var/list/allmins = adm["total"]
		if(!afkmins.len && !stealthmins.len && !powerlessmins.len)
			final = "No admins online"
		else
			final = "All admins stealthed\[[get_english_list(stealthmins)]\], AFK\[[get_english_list(afkmins)]\], or lacks +BAN\[[get_english_list(powerlessmins)]\]! Total: [allmins.len] "

		world.send2bridge(
			type = type,
			attachment_title = title,
			attachment_msg = msg,
			attachment_color = BRIDGE_COLOR_ADMINALERT,
			attachment_footer = final,
			mention = mention,
		)

//
// MENTOR PROCS
//

/client/proc/cmd_mhelp_reply(whom)
	if(prefs.muted & MUTE_ADMINHELP)
		to_chat(src, span_admin_pm_warning("Error: Mentor-PM: You are unable to use admin PM-s (muted)."))
		return
	var/client/C
	if(istext(whom))
		C = GLOB.directory[whom]
	else if(istype(whom,/client))
		C = whom
	if(!C)
		if(src.holder)
			to_chat(src, span_admin_pm_warning("Error: Mentor-PM: Client not found."))
		return

	var/datum/ticket/T = C.current_ticket

	if(T)
		message_mentors(span_mentor_channel("[src] has started replying to [C]'s mentor help."))
	var/msg = tgui_input_text(src,"Message:", "Private message to [C]", multiline = TRUE)
	if (!msg)
		message_mentors(span_mentor_channel("[src] has cancelled their reply to [C]'s mentor help."))
		return
	cmd_mentor_pm(whom, msg, T)

/client/proc/cmd_mentor_pm(whom, msg, datum/ticket/T)
	set category = "Admin"
	set name = "Mentor-PM"
	set hidden = 1

	if(prefs.muted & MUTE_ADMINHELP)
		to_chat(src, span_mentor_warning("Error: Mentor-PM: You are unable to use mentor PM-s (muted)."))
		return

	//Not a mentor and no open ticket
	if(!src.holder && !current_ticket)
		to_chat(src, span_mentor_warning("You can no longer reply to this ticket, please open another one by using the Mentorhelp verb if need be."))
		to_chat(src, span_mentor_notice("Message: [msg]"))
		return

	var/client/recipient

	if(istext(whom))
		recipient = GLOB.directory[whom]

	else if(istype(whom,/client))
		recipient = whom

	//get message text, limit it's length.and clean/escape html
	if(!msg)
		msg = tgui_input_text(src,"Message:", "Mentor-PM to [whom]", multiline = TRUE)

		if(!msg)
			return

		if(prefs.muted & MUTE_ADMINHELP)
			to_chat(src, span_mentor_warning("Error: Mentor-PM: You are unable to use mentor PM-s (muted)."))
			return

		if(!recipient)
			if(src.holder)
				to_chat(src, span_mentor_warning("Error:Mentor-PM: Client not found."))
				to_chat(src, msg)
			else
				log_admin("Mentorhelp: [key_name(src)]: [msg]")
				current_ticket.MessageNoRecipient(msg)
			return

	//Has mentor powers but the recipient no longer has an open ticket
	if(src.holder && !recipient.current_ticket)
		to_chat(src, span_mentor_warning("You can no longer reply to this ticket."))
		to_chat(src, span_mentor_notice("Message: [msg]"))
		return

	if (src.handle_spam_prevention(msg,MUTE_ADMINHELP))
		return

	msg = trim(sanitize(copytext(msg,1,MAX_MESSAGE_LEN)))
	if(!msg)
		return

	var/interaction_message = span_mentor_notice("Mentor-PM from-<b>[src]</b> to-<b>[recipient]</b>: [msg]")

	if (recipient.current_ticket && !recipient.holder && recipient.current_ticket.level == 0)
		recipient.current_ticket.AddInteraction(interaction_message)
	if (src.current_ticket && !src.holder && src.current_ticket.level == 0)
		src.current_ticket.AddInteraction(interaction_message)

	// It's a little fucky if they're both mentors, but while admins may need to adminhelp I don't really see any reason a mentor would have to mentorhelp since you can literally just ask any other mentors online
	if (recipient.holder && src.holder)
		if (recipient.current_ticket && recipient != src && recipient.current_ticket.level == 0)
			recipient.current_ticket.AddInteraction(interaction_message)
		if (src.current_ticket && src.current_ticket.level == 0)
			src.current_ticket.AddInteraction(interaction_message)

	to_chat(recipient, span_mentor(span_italics("Mentor-PM from-<b><a href='byond://?mentorhelp_msg=\ref[src]'>[src]</a></b>: [msg]")))
	to_chat(src, span_mentor(span_italics("Mentor-PM to-<b>[recipient]</b>: [msg]")))

	log_admin("[key_name(src)]->[key_name(recipient)]: [msg]")

	if(recipient.prefs?.read_preference(/datum/preference/toggle/play_mentorhelp_ping))
		recipient << 'sound/effects/mentorhelp.mp3'

	for(var/client/C in GLOB.admins)
		if (C != recipient && C != src)
			to_chat(C, interaction_message)
