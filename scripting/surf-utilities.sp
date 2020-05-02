#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>
#include <devzones>

#define VERSION "1.1.0"

#pragma newdecls required


//SQL Locking System

int g_sequence = 0;								// Global unique sequence number
int g_connectLock = 0;	
Database g_hDatabase;

//SQL Queries

char sql_createTables[] = "CREATE TABLE IF NOT EXISTS `rankings` ( \
							`ID` int(11) NOT NULL AUTO_INCREMENT,\
							`TimeStamp` timestamp, \
							`MapName` varchar(32) NOT NULL, \
							`UserName` varchar(32), \
							`UserID` int(11) NOT NULL, \
							`Score` float NOT NULL, \
							PRIMARY KEY (`ID`) \
						)";
char sql_selectPlayerScore[] = "SELECT `TimeStamp`, `Score` FROM `rankings` WHERE `UserID`='%d';"; // Arg: String:UserID
char sql_selectPlayerScoreByMap[] = "SELECT `TimeStamp`, `Score` FROM `rankings` WHERE `UserID`='%d' AND `MapName`='%s' ORDER BY `Score` ASC;"; // Arg: int32:UserID String:MapName(Must be escaped)
char sql_selectPersonalBestByMap[] = "SELECT `Score` FROM `rankings` WHERE `UserID`='%d' AND `MapName`='%s' ORDER BY `Score` ASC LIMIT 1;"; // Arg: int32:UserID String:MapName(Must be escaped)
char sql_selectScore[] = "SELECT `rankings1`.`ID`, `rankings2`.`UserID`, `rankings1`.`UserName`, `rankings2`.`MinScore` FROM ( SELECT `UserID`, Min(`Score`) as `MinScore` FROM `rankings` WHERE `MapName`='%s' GROUP BY `UserID` ) as `rankings2` JOIN `rankings` as `rankings1` ON `rankings1`.`Score` = `rankings2`.`MinScore` WHERE `MapName`='%s' GROUP BY `UserID`;"; // Arg: String:Map
char sql_selectScoreByID[] = "SELECT `UserName`, `UserID`, `MapName`, `Score`, `TimeStamp` FROM `rankings` WHERE `ID`='%d';"; // Arg int32:ID
char sql_insertScore[] = "INSERT INTO `rankings` SET `MapName`='%s', `UserName`= '%s', `UserID`='%d', `Score`='%.3f';"; // Arg: int32:UserID, float32:Score

//Plugin cvars and cookies

Handle g_cvarVersion = null;
Handle g_cvarMode = null;
Handle g_cookieHintMode = null;
char g_cookieClientHintMode[MAXPLAYERS + 1] = { 0 };


//Surf Timer Time ticking Process Variable

float g_surfPersonalBest[MAXPLAYERS + 1];
int g_surfPersonalBestMinute[MAXPLAYERS + 1];
float g_surfPersonalBestSecond[MAXPLAYERS + 1];
float g_surfTimerPoint[MAXPLAYERS + 1][32];
char g_surfTimerEnabled[MAXPLAYERS + 1] = { 0 }; // 0 on Surfing 1 on after reaching end zone 2 on being at start zone 3 on being at end zone

#include "surf-utilities/menu.sp"
#include "surf-utilities/hud.sp"

public Plugin myinfo =
{
	name = "Surf Utilities with DEV Zones",
	author = "Jobggun",
	description = "Surf Timer for TF2(or any) with Custom Zones",
	version = VERSION,
	url = "Not Specified"
};


//Forwards (CallBack functions?)

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	g_cvarVersion = CreateConVar("sm_surfutil_version", VERSION, "Surf Utilities Plugin's Version", FCVAR_NOTIFY | FCVAR_REPLICATED);
	g_cvarMode = CreateConVar("sm_surfutil_hudmode", "0", "Whether the surf timer shows on hint message or not globally.");
	g_cookieHintMode = RegClientCookie("sm_surfutil_hint_mode", "Whether the surf timer shows on hint message or not.", CookieAccess_Protected);
	SetCookiePrefabMenu(g_cookieHintMode, CookieMenu_YesNo_Int, "Surf Hint Mode");
	RegConsoleCmd("sm_my_rank", MenuMyRank, "A panel shows your record on this map.");
	RegConsoleCmd("sm_mr", MenuMyRank, "A panel shows your record on this map.");
	RegConsoleCmd("sm_rank", MenuRank, "A panel shows server top record on this map.");
	RegConsoleCmd("sm_wr", MenuRank, "A panel shows server top record on this map.");
	
	RequestDatabaseConnection();
	CreateTimer(1.0, TimerRequestDatabaseConnection, _, TIMER_REPEAT);
	
	g_syncHud = CreateHudSynchronizer();
}

public void OnClientPutInServer(int client)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client)) 
		return;
	
	g_surfPersonalBest[client] = 0.0;
	g_surfTimerEnabled[client] = 3;
	SurfGetPersonalBest(client);
}

public void OnClientDisconnect(int client)
{
	if (g_surfTimerHandle[client] != null)
		{
			delete g_surfTimerHandle[client];
		}
	ClearSyncHud(client, g_syncHud);
}
/*
public void OnClientCookiesCached(int client)
{
	char buffer[5];
	GetClientCookie(client, g_cookieHintMode, buffer, sizeof(buffer));
	if(buffer[0] == '\0')
		g_cookieClientHintMode[client] = GetConVarInt(g_cvarMode);
}
*/

public void OnMapStart()
{
	RequestDatabaseConnection();
	CreateTimer(1.0, TimerRequestDatabaseConnection, _, TIMER_REPEAT);
}
public void OnMapEnd()
{
	/**
	 * Clean up on map end just so we can start a fresh connection when we need it later.
	 */
	delete g_hDatabase;
}

///////////////////
//  Event Hook Functions

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(AreClientCookiesCached(client))
	{
		char buffer[5];
		GetClientCookie(client, g_cookieHintMode, buffer, sizeof(buffer));
		if(buffer[0] == '\0')
		{
			g_cookieClientHintMode[client] = GetConVarInt(g_cvarMode);
		}
		else
		{
			g_cookieClientHintMode[client] = StringToInt(buffer);
		}
	}
	
	g_surfTimerEnabled[client] = 2;
	
	SurfGetPersonalBest(client);
	
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client)) 
		return;
	
	DataPack pack;
	
	if (g_surfTimerHandle[client] != null)
		CloseHandle(g_surfTimerHandle[client]);
	
	g_surfTimerHandle[client] = CreateDataTimer(0.33, SurfPrepareAdvisor, pack, TIMER_REPEAT);
	
	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(g_cookieClientHintMode[client]);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client < 1 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client)) 
		return;
	
	g_surfTimerEnabled[client] = 2;
}

public void Zone_OnClientEntry(int client, const char[] zone)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) ||!IsPlayerAlive(client) || IsFakeClient(client)) 
		return;
	
	if(StrContains(zone, "surf_start", true) == 0)
	{
		g_surfTimerEnabled[client] = 2;
		
		return;
	}
	else if(StrContains(zone, "surf_stop", true) == 0)
	{
		if(g_surfTimerEnabled[client] == 0)
		{
			g_surfTimerPoint[client][1] = GetGameTime();
			float scoredTime = g_surfTimerPoint[client][1] - g_surfTimerPoint[client][0];
			PrintToChat(client, "You've reached to End Zone in %.3fs", scoredTime);
			SurfRecordInsert(client, scoredTime);
			SurfGetPersonalBest(client);
		}
		g_surfTimerEnabled[client] = 3;
		
		return;
	}
	else if(StrContains(zone, "surf_checkpoint", false) == 0)
	{
		
	}
}

public void Zone_OnClientLeave(int client, const char[] zone)
{
	if(client < 1 || client > MaxClients || !IsClientInGame(client) ||!IsPlayerAlive(client) || IsFakeClient(client)) 
		return;
	
	if(StrContains(zone, "surf_start", false) == 0)
	{
		g_surfTimerPoint[client][0] = GetGameTime();
		g_surfTimerEnabled[client] = 0;
		
		return;
	}
	else if(StrContains(zone, "surf_stop", false) == 0)
	{
		g_surfTimerEnabled[client] = 1;
		
		return;
	}
	else if(StrContains(zone, "surf_checkpoint", false) == 0)
	{
		
	}
}

////////////////
// Own Functions

void GetCurrentElapsedTime(int client, int &minute, float &second)
{
	if(g_surfTimerEnabled[client] != 0)
	{
		minute = 0;
		second = 0.0;
		
		return;
	}
	float delta = GetGameTime() - g_surfTimerPoint[client][0];
	
	minute = RoundToFloor(delta) / 60;
	second = delta - minute * 60.0;
	
	return;
}

public Action TimerRequestDatabaseConnection(Handle timer)
{
	if(g_hDatabase == null)
	{
		RequestDatabaseConnection();
		
		return Plugin_Continue;
	}
	else
	{
		return Plugin_Stop;
	}
}

void RequestDatabaseConnection()
{
	g_connectLock = ++g_sequence;
	
	if (SQL_CheckConfig("surf"))
	{
		Database.Connect(OnDatabaseConnect, "surf", g_connectLock);
	} else {
		Database.Connect(OnDatabaseConnect, "default", g_connectLock);
	}
	
	return;
}

public void OnDatabaseConnect(Database db, const char[] error, any data)
{
	/**
	 * If there is difference between data(old connectLock) and connectLock, It might be replaced by other thread.
	 * If g_hDatabase is not null, Threaded job is running now.
	 */
	if (data != g_connectLock || g_hDatabase != null)
	{
		delete db;
		return;
	}
	
	g_connectLock = 0;

	/**
	 * See if the connection is valid.  If not, don't un-mark the caches
	 * as needing rebuilding, in case the next connection request works.
	 */
	if(db == null)
	{
		LogError("Database failure: %s", error);
	}
	else 
	{
		g_hDatabase = db;
	}
}

void SurfRecordInsert(int client, float timeScored)
{
	char query[255];
	char unescapedName[32], unescapedMap[32];
	char Name[65], Map[65];
	
	GetClientName(client, unescapedName, sizeof(unescapedName));
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	
	if(!(SQL_EscapeString(g_hDatabase, unescapedName, Name, sizeof(Name)) && SQL_EscapeString(g_hDatabase, unescapedMap, Map, sizeof(Map))))
	{
		LogError("Escape Error");
		return;
	}
	
	FormatEx(query, sizeof(query), sql_insertScore, Map, Name, GetSteamAccountID(client), timeScored);
	g_hDatabase.Query(T_SurfRecordInsert, query, GetClientSerial(client));
}

public void T_SurfRecordInsert(Database db, DBResultSet results, const char[] error, any data)
{
	if (GetClientFromSerial(data) == 0)
		return;
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	delete results;
}

void SurfGetPersonalBest(int client)
{
	char query[255];
	char unescapedMap[32], Map[65];
	
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	
	if(!(SQL_EscapeString(g_hDatabase, unescapedMap, Map, sizeof(Map))))
	{
		LogError("Escape Error");
		return;
	}
	
	FormatEx(query, sizeof(query), sql_selectPersonalBestByMap, GetSteamAccountID(client), Map);
	g_hDatabase.Query(T_SurfGetPersonalBest, query, GetClientSerial(client));
}

public void T_SurfGetPersonalBest(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	
	if(client == 0)
	{
		return;
	}
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	g_surfPersonalBest[client] = 0.0;
	
	if (SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		g_surfPersonalBest[client] = SQL_FetchFloat(results, 0);
		g_surfPersonalBestMinute[client] = RoundToFloor(g_surfPersonalBest[client]) / 60;
		g_surfPersonalBestSecond[client] = g_surfPersonalBest[client] - g_surfPersonalBestMinute[client] * 60;
	}
	
	delete results;
}