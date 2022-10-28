#include "meta_init.h"
#include <string>

using namespace std;

// Description of plugin
plugin_info_t Plugin_info = {
	META_INTERFACE_VERSION,	// ifvers
	"MapChangeMsg",	// name
	"1.0",	// version
	__DATE__,	// date
	"w00tguy",	// author
	"https://github.com/wootguy/",	// url
	"MAPCHGMSG",	// logtag, all caps please
	PT_ANYTIME,	// (when) loadable
	PT_ANYPAUSE,	// (when) unloadable
};

bool g_waiting_for_change = false;
float g_level_change_time = 0;
string g_load_map;
string g_load_map_arg; // not sure what this does but using it just in case

cvar_t* g_change_delay;

#define MAX_CVARS 8
cvar_t g_cvar_data[MAX_CVARS];
int g_cvar_count = 0;

#define println(fmt,...) {ALERT(at_console, (char*)(string(fmt) + "\n").c_str(), ##__VA_ARGS__); }

cvar_t* RegisterCVar(char* name, char* strDefaultValue, int intDefaultValue, int flags) {

	if (g_cvar_count >= MAX_CVARS) {
		println("Failed to add cvar '%s'. Increase MAX_CVARS and recompile.", name);
		return NULL;
	}

	g_cvar_data[g_cvar_count].name = name;
	g_cvar_data[g_cvar_count].string = strDefaultValue;
	g_cvar_data[g_cvar_count].flags = flags | FCVAR_EXTDLL;
	g_cvar_data[g_cvar_count].value = intDefaultValue;
	g_cvar_data[g_cvar_count].next = NULL;

	CVAR_REGISTER(&g_cvar_data[g_cvar_count]);

	g_cvar_count++;

	return CVAR_GET_POINTER(name);
}

void ChangeLevel(char* s1, char* s2) {
	if (g_change_delay->value < 0) {
		RETURN_META(MRES_IGNORED);
	}

	if (g_waiting_for_change) {
		RETURN_META(MRES_SUPERCEDE);
	}

	MESSAGE_BEGIN(MSG_BROADCAST, 74);
	WRITE_BYTE(0); // not a player
	WRITE_STRING((string("Loading ") + s1 + "...\n").c_str());
	MESSAGE_END();

	MESSAGE_BEGIN(MSG_BROADCAST, SVC_INTERMISSION);
	MESSAGE_END();

	g_load_map = s1 ? s1 : "";
	g_load_map_arg = s2 ? s2 : "";
	g_level_change_time = gpGlobals->time + g_change_delay->value;
	g_waiting_for_change = true;

	RETURN_META(MRES_SUPERCEDE);
}

void MapInit(edict_t* pEdictList, int edictCount, int clientMax) {
	g_waiting_for_change = false;
	g_load_map = "";
	g_load_map_arg = "";
	g_level_change_time = 0;
	RETURN_META(MRES_IGNORED);
}

void StartFrame() {
	if (!g_waiting_for_change || g_level_change_time > gpGlobals->time) {
		RETURN_META(MRES_IGNORED);
	}

	g_engfuncs.pfnServerCommand((char*)(string("changelevel ") + g_load_map + " " + g_load_map_arg + ";").c_str());
	RETURN_META(MRES_IGNORED);
}

void PluginInit() {
	g_engine_hooks.pfnChangeLevel = ChangeLevel;
	g_dll_hooks.pfnServerActivate = MapInit;
	g_dll_hooks.pfnStartFrame = StartFrame;

	// set to -1 to disable plugin
	g_change_delay = RegisterCVar("mapchangemsg.delay", "0.05", 0.05, 0);
}

void PluginExit() {}