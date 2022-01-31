// This plugin shows a level change message when a trigger_changelevel is touched/triggered

uint g_id = 0;
const string LEVEL_CHANGE_HOOK_TEXT = "MapChangeMsg_DoMsg";
float level_change_delay = 0.05f; // increase this if the level change message is not always shown

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "w00tguy" );
	g_Module.ScriptInfo.SetContactInfo( "github" );
	
	g_Hooks.RegisterHook( Hooks::Game::EntityCreated, @EntityCreated );
}

void MapActivate()
{
	g_id = 0;
	processLevelChangeEnts();
}

void PreLevelChangeHook() {
	// only use unreliable messages because the server won't be able to reply while its loading the next level

	NetworkMessage message(MSG_BROADCAST, NetworkMessages::SVC_INTERMISSION, null);
	message.End();
	
	NetworkMessage m(MSG_BROADCAST, NetworkMessages::NetworkMessageType(74), null);
        m.WriteByte(0); // not a player
        m.WriteString("Loading next map...\n");
    m.End();
}

// targetname not valid until 1 frame after the entity is created
void delay_check_ent(EHandle h_ent) {
	CBaseEntity@ ent = h_ent;
	
	if (ent !is null and ent.pev.targetname == LEVEL_CHANGE_HOOK_TEXT) {
		PreLevelChangeHook();
		g_Scheduler.SetTimeout("delay_trigger", 0.05f, string(ent.pev.target)); 
	}
}

void delay_trigger(string tname) {
	CBaseEntity@ ent = g_EntityFuncs.FindEntityByTargetname(ent, tname);
	
	CBasePlayer@ anyPlayer = null;
	for (int i = 1; i <= g_Engine.maxClients; i++) {
		CBasePlayer@ p = g_PlayerFuncs.FindPlayerByIndex(i);
		
		if (p is null or !p.IsConnected()) {
			continue;
		}
		
		@anyPlayer = @p;
		break;
	}
	
	if (ent !is null) {
		println("[MapChangeMsg] Triggering level change " + tname);
		ent.Use(anyPlayer, anyPlayer, USE_TOGGLE); // works only for use-only changelevels
		ent.Touch(anyPlayer); // works only for touched level changes		
	} else {
		g_Log.PrintF("[MapChangeMsg] Failed to trigger level change " + tname + "\n");
	}
}

HookReturnCode EntityCreated(CBaseEntity@ ent){
	if (ent.pev.classname == "info_target") {
		g_Scheduler.SetTimeout("delay_check_ent", 0.0f, EHandle(ent));
	}
	
	return HOOK_CONTINUE;
}

void hook_trigger_changelevel(CBaseEntity@ changelevel) {
	if (changelevel.pev.solid == SOLID_BSP)
		return; // changelevel disabled because it points to the previous level or something
	
	bool isTriggered = (changelevel.pev.spawnflags & 2) != 0;
	
	if (isTriggered and changelevel.pev.targetname == "")
		return; // trigger-only but isn't triggered by anything
	
	string original_changelevel_name = changelevel.pev.targetname;
	string hook_ent_name = "MapChangeMsgHook" + g_id++;
	string new_changelevel_name = "MapChangeMsgTrigger" + g_id++;
	
	// use trigger_multiple to handle level change touches
	{
		dictionary keys;
		keys["targetname"] = original_changelevel_name;
		keys["target"] = hook_ent_name;
		keys["spawnflags"] = "16"; // fire on enter
		keys["wait"] = "3";
		keys["model"] = string(changelevel.pev.model);
		keys["origin"] = changelevel.pev.origin.ToString();
		
		g_EntityFuncs.CreateEntity("trigger_multiple", keys);
		
		changelevel.pev.solid = SOLID_NOT;
		changelevel.pev.spawnflags = 2;
		changelevel.Respawn();
	}
	
	// create a relay always, for when a changelevel is both touchable and triggerable
	// (trigger_multiple can't be triggered by name)
	{
		dictionary keys;
		keys["targetname"] = original_changelevel_name;
		keys["target"] = hook_ent_name;
		
		g_EntityFuncs.CreateEntity("trigger_relay", keys);
	}
	
	dictionary keys;
	keys["targetname"] = hook_ent_name;
	keys["m_iszCrtEntChildClass"] = "info_target";
	keys["m_iszCrtEntChildName"] = LEVEL_CHANGE_HOOK_TEXT;
	keys["-target"] = new_changelevel_name;
	g_EntityFuncs.CreateEntity("trigger_createentity", keys);
	
	changelevel.pev.targetname = new_changelevel_name;
}

void processLevelChangeEnts()
{
	int triggersFound = 0;
	
	CBaseEntity@ ent = null;
	do {
		@ent = g_EntityFuncs.FindEntityByClassname(ent, "trigger_changelevel");
		
		if (ent is null)
			break;
			
		if (ent.pev.classname == "trigger_changelevel") {
			hook_trigger_changelevel(ent);
			triggersFound++;
		}	
	} while (ent !is null);
	
	println("[MapChangeMsg] Processed " + triggersFound + " triggers");
}

void print(string text) { g_Game.AlertMessage( at_console, text); }
void println(string text) { print(text + "\n"); }