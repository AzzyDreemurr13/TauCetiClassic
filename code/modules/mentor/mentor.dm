/var/list/mentor_ckeys = list()//all server mentors list
/var/list/mentors = list()     //online mentors

/proc/message_mentors(msg, observer_only = FALSE, emphasize = FALSE)
	var/style = "admin"
	if (emphasize)
		style += " emphasized"
	msg = "<span class='[style]'><span class='prefix'>MENTOR LOG:</span> <span class='message'>[msg]</span></span>"
	for(var/client/C in mentors)
		if(!observer_only || (observer_only && isobserver(C.mob)))
			to_chat(C, msg)
