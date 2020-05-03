Menu MenuHandler[MAXPLAYERS + 1] = { null };

public int MenuMyRankHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action MenuMyRank(int client, int args)
{
	if(IsInvalidClient(client)) 
		return Plugin_Handled;
	
	char query[255];
	char unescapedMap[32];
	char Map[65];
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	if(!SQL_EscapeString(g_hDatabase, unescapedMap, Map, sizeof(Map)))
	{
		LogError("Escape Error");
		return Plugin_Handled;
	}
	FormatEx(query, sizeof(query), sql_selectPlayerScoreByMap, GetSteamAccountID(client), Map);
	g_hDatabase.Query(T_MenuMyRankRetrive, query, GetClientSerial(client));
	
	return Plugin_Handled;
}

public void T_MenuMyRankRetrive(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	
	if ((client = GetClientFromSerial(data)) == 0)
		return;
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	Menu menu = new Menu(MenuMyRankHandler, MenuAction_Select|MenuAction_Cancel);
	
	char buffer[256];
	char TimeStamp[32];
	float Score;
	
	while(SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		SQL_FetchString(results, 0, TimeStamp, sizeof(TimeStamp));
		Score = SQL_FetchFloat(results, 1);
		FormatEx(buffer, sizeof(buffer), "%s : %.3f sec", TimeStamp, Score);
		menu.AddItem(buffer, buffer);
	}
	
	delete results;
	
	menu.SetTitle("Your Record");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuRankHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char ID[16];
			menu.GetItem(param2, ID, sizeof(ID));
			MenuRankSubmenu(param1, StringToInt(ID)); // Param1 is client
		}
		case MenuAction_Cancel:
		{
			delete MenuHandler[param1];
		}
		case MenuAction_End:
		{
			
		}
	} 
}

public Action MenuRank(int client, int args)
{
	if(IsInvalidClient(client)) 
		return Plugin_Handled;
	
	DataPack pack = CreateDataPack();
	char query[1024];
	char unescapedMap[32];
	char Map[65];
	
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	if(!SQL_EscapeString(g_hDatabase, unescapedMap, Map, sizeof(Map)))
	{
		LogError("Escape Error");
		return Plugin_Handled;
	}
	FormatEx(query, sizeof(query), sql_selectScore, Map, Map);
	pack.WriteCell(GetClientSerial(client));
	pack.WriteString(unescapedMap);
	g_hDatabase.Query(T_MenuRankRetrive, query, pack);
	
	return Plugin_Handled;
}

public void T_MenuRankRetrive(Database db, DBResultSet results, const char[] error, any data)
{
	int client;
	
	DataPack pack = view_as<DataPack>(data);
	
	pack.Reset();
	
	if ((client = GetClientFromSerial(pack.ReadCell())) == 0)
		return;
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	Menu menu = new Menu(MenuRankHandler, MenuAction_Start|MenuAction_Select|MenuAction_Cancel|MenuAction_End);
	
	int count = 0;
	char buffer[256], Name[32], ID[16];
	float Score;
	int ScoreMinute;
	
	while(SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		SQL_FetchString(results, 2, Name, sizeof(Name));
		Score = SQL_FetchFloat(results, 3);
		SQL_FetchString(results, 0, ID, sizeof(ID));
		ScoreMinute = RoundToFloor(Score) / 60;
		FormatEx(buffer, sizeof(buffer), "#%d - %s - %02d:%06.3f", ++count, Name, ScoreMinute, Score - ScoreMinute * 60.0);
		menu.AddItem(ID, buffer);
	}
	
	delete results;
	
	if(count == 0)
	{
		menu.AddItem("There is Nothing To Show :(", "There is Nothing To Show :(");
	}
	
	pack.ReadString(Name, sizeof(Name));
	menu.SetTitle("Records For %s:\n(%d records)", Name, count);
	
	CloseHandle(pack);
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	MenuHandler[client] = menu;
}

void MenuRankSubmenu(int client, int ID)
{
	char query[256];
	FormatEx(query, sizeof(query), sql_selectScoreByID, ID);
	g_hDatabase.Query(T_MenuRankSubmenu, query, GetClientSerial(client));
}

public void T_MenuRankSubmenu(Database db, DBResultSet results, const char[] error, any data)
{
	int client = GetClientFromSerial(data);
	
	if(client == 0)
		return;
		
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("Query failed! %s", error);
		return;
	}
	
	Menu menu = new Menu(MenuRankSubmenuHandler, MenuAction_Start|MenuAction_Select|MenuAction_Cancel|MenuAction_End);
	
	char buffer[64];
	char UserName[32], MapName[32], TimeStamp[32];
	int UserID;
	float Time;
	
	int TimeMinute;
	if(SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		SQL_FetchString(results, 0, UserName, sizeof(UserName));
		UserID = SQL_FetchInt(results, 1);
		SQL_FetchString(results, 2, MapName, sizeof(MapName));
		Time = SQL_FetchFloat(results, 3);
		SQL_FetchString(results, 4, TimeStamp, sizeof(TimeStamp));
	}
	
	menu.SetTitle("%s [U:1:%d]\n--- %s:", UserName, UserID, MapName);
	
	TimeMinute = RoundToFloor(Time) / 60;
	
	FormatEx(buffer, sizeof(buffer), "Time: %02d:%06.3fs", TimeMinute, Time - TimeMinute * 60);
	menu.AddItem("1", buffer);
	FormatEx(buffer, sizeof(buffer), "Date: %s", TimeStamp);
	menu.AddItem("2", buffer);
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	delete results;
}

public int MenuRankSubmenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select || action == MenuAction_Cancel)
	{
		MenuHandler[param1].Display(param1, MENU_TIME_FOREVER);
	} 
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}