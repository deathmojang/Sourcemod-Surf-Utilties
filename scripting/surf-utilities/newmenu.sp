//#define DEBUG

//Menu MenuHandle[MAXPLAYERS + 1] = { null };

public Action MenuMyRank(int client, int args)
{
	if(IsInvalidClient(client))
	{
		LogError("An error occurred in \'MenuMyRank\' Function: client is invalid.");
		return Plugin_Handled;
	}
	
	char query[1024], unescapedMap[32], map[65];
	
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	
	if(!SQL_EscapeString(g_hDatabase, unescapedMap, map, sizeof(map)))
	{
		LogError("An error occurred in \'MenuMyRank\' Function: SQL_EscapeString Error.");
		return Plugin_Handled;
	}
	
	FormatEx(query, sizeof(query), sql_selectPlayerScoreByMap, GetSteamAccountID(client), map);
	g_hDatabase.Query(T_MenuMyRank, query, GetClientSerial(client));
	
	return Plugin_Handled;
}

public void T_MenuMyRank(Database db, DBResultSet results, const char[] error, int serial)
{
	int client;
	
	if((client = GetClientFromSerial(serial)) == 0)
	{
		LogError("An error occurred in \'T_MenuMyRank\' Function: client is invalid.");
		return;
	}
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("An error occurred in \'T_MenuMyRank\' Function: SQL query failed! %s", error);
		return;
	}
	
	char buffer[256], countBuffer[16], timeStamp[32];
	float score;
	int count = 0;
	
	Menu menu = new Menu(Handler_MenuMyRank, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	
	while(SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		count++;
		SQL_FetchString(results, 0, timeStamp, sizeof(timeStamp));
		score = SQL_FetchFloat(results, 1);
		FormatEx(buffer, sizeof(buffer), "%s : %.3f sec", timeStamp, score);
		IntToString(count, countBuffer, sizeof(countBuffer));
		menu.AddItem(countBuffer, buffer);
	}
	
	delete results;
	
	if(count == 0)
	{
		menu.AddItem("-1", "There is Nothing To Show :(", ITEMDRAW_DISABLED);
	}
	
	menu.SetTitle("Your Record");
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_MenuMyRank(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Display:
		{
			//param1 is client, param2 is panel handle

			char title[255];
			Format(title, sizeof(title), "%T", "MenuMyRankTitle", param1);
			menu.SetTitle(title);
		}

		case MenuAction_Select:
		{
			//param1 is client, param2 is item

		}

		case MenuAction_Cancel:
		{
			//param1 is client, param2 is cancel reason (see MenuCancel types)
#if defined DEBUG
			LogMessage("Handler_MenuMyRank: MenuAction_Cancel");
#endif
		}

		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
#if defined DEBUG
			LogMessage("Handler_MenuMyRank: MenuAction_End");
#endif
			CloseHandle(menu);
		}

		case MenuAction_DisplayItem:
		{
			//param1 is client, param2 is item

			char item[64];
			menu.GetItem(param2, item, sizeof(item));

			if (StrEqual(item, "-1"))
			{
				char translation[128];
				Format(translation, sizeof(translation), "%T", "ThereIsNothingToShow", param1);
				return RedrawMenuItem(translation);
			}
		}
	}
	return 0;
}




public Action MenuWorldRank(int client, int args)
{
	if(IsInvalidClient(client))
	{
		LogError("An error occurred in \'MenuWorldRank\' Function: client is invalid.");
		return Plugin_Handled;
	}
	
	DataPack pack = new DataPack();
	char query[1024], unescapedMap[32], map[65];
	
	GetCurrentMap(unescapedMap, sizeof(unescapedMap));
	
	if(!SQL_EscapeString(g_hDatabase, unescapedMap, map, sizeof(map)))
	{
		LogError("An error occurred in \'MenuWorldRank\' Function: SQL_EscapeString Error.");
		return Plugin_Handled;
	}
	
	FormatEx(query, sizeof(query), sql_selectScore, map, map);
	pack.WriteCell(GetClientSerial(client));
	pack.WriteString(map);
	
	g_hDatabase.Query(T_MenuWorldRank, query, pack);
	
	return Plugin_Handled;
}

public void T_MenuWorldRank(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	int client;
	
	pack.Reset();
	
	if((client = GetClientFromSerial(pack.ReadCell())) == 0)
	{
		LogError("An error occurred in \'T_MenuWorldRank\' Function: client is invalid.");
		return;
	}
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("An error occurred in \'T_MenuWorldRank\' Function: SQL query failed! %s", error);
		return;
	}
	
	char buffer[256], name[32], ID[16];
	float score;
	int count = 0;
	int scoreMinute;
	
	Menu menu = new Menu(Handler_MenuWorldRank, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	
	while(SQL_FetchRow(results) && SQL_HasResultSet(results))
	{
		count++;
		SQL_FetchString(results, 2, name, sizeof(name));
		score = SQL_FetchFloat(results, 3);
		SQL_FetchString(results, 0, ID, sizeof(ID));
		scoreMinute = RoundToFloor(score) / 60;
		FormatEx(buffer, sizeof(buffer), "#%d - %s - %02d:%06.3f", count, name, scoreMinute, score - scoreMinute * 60.0);
		menu.AddItem(ID, buffer);
	}
	
	delete results;
	
	if(count == 0)
	{
		menu.AddItem("-1", "There is Nothing To Show :(", ITEMDRAW_DISABLED);
	}
	
	pack.ReadString(name, sizeof(name));
	menu.SetTitle("%s;%d", name, count);
	
	delete pack;
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_MenuWorldRank(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Display:
		{
			//param1 is client, param2 is panel handle
			
			char title[255];
			char map[64], numRecords[64];
			int length;
			
			menu.GetTitle(title, sizeof(title));
			
			length = SplitString(title, ";", map, sizeof(map));
			strcopy(numRecords, sizeof(numRecords), title[length]);
			
#if defined DEBUG
			LogMessage(title[length]);
			LogMessage(numRecords);
#endif

			Format(title, sizeof(title), "%T", "MenuWorldRankTitle", param1, map, StringToInt(numRecords));
			menu.SetTitle(title);
		}

		case MenuAction_Select:
		{
			//param1 is client, param2 is item

			char item[64];
			menu.GetItem(param2, item, sizeof(item));
			
			int ID = StringToInt(item);
			
			if(ID == -1)
			{
				menu.Display(param1, MENU_TIME_FOREVER);
			}
			else
			{
				MenuWorldRankSubmenu(param1, ID);
			}
		}

		case MenuAction_Cancel:
		{
			//param1 is client, param2 is cancel reason (see MenuCancel types)
#if defined DEBUG
			LogMessage("Handler_MenuWorldRank: MenuAction_Cancel");
#endif
		}

		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
#if defined DEBUG
			LogMessage("Handler_MenuWorldRank: MenuAction_End");
#endif
			CloseHandle(menu);
		}

		case MenuAction_DisplayItem:
		{
			//param1 is client, param2 is item

			char item[64];
			menu.GetItem(param2, item, sizeof(item));

			if (StrEqual(item, "-1"))
			{
				char translation[128];
				Format(translation, sizeof(translation), "%T", "ThereIsNothingToShow", param1);
				return RedrawMenuItem(translation);
			}
		}
	}
	return 0;
}

void MenuWorldRankSubmenu(int client, int ID)
{
	char query[256];
	FormatEx(query, sizeof(query), sql_selectScoreByID, ID);
	g_hDatabase.Query(T_MenuWorldRankSubmenu, query, GetClientSerial(client));
}

public void T_MenuWorldRankSubmenu(Database db, DBResultSet results, const char[] error, int serial)
{
	int client;
	
	if((client = GetClientFromSerial(serial)) == 0)
	{
		LogError("An error occurred in \'T_MenuWorldRankSubmenu\' Function: client is invalid.");
		return;
	}
	
	if (db == null || results == null || error[0] != '\0')
	{
		LogError("An error occurred in \'T_MenuWorldRankSubmenu\' Function: SQL query failed! %s", error);
		return;
	}
	
	Menu menu = new Menu(MenuWorldRankSubmenuHandler, MenuAction_Display | MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DisplayItem);
	
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
	
	FormatEx(buffer, sizeof(buffer), ": %02d:%06.3fs", TimeMinute, Time - TimeMinute * 60);
	menu.AddItem("1", buffer);
	FormatEx(buffer, sizeof(buffer), ": %s", TimeStamp);
	menu.AddItem("2", buffer);
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	delete results;
}

public int MenuWorldRankSubmenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Display:
		{
			//param1 is client, param2 is panel handle
			
		}

		case MenuAction_Select:
		{
			//param1 is client, param2 is item

			FakeClientCommandEx(param1, "sm_wr");
		}

		case MenuAction_Cancel:
		{
			//param1 is client, param2 is cancel reason (see MenuCancel types)
#if defined DEBUG
			LogMessage("Handler_MenuMyRank: MenuAction_Cancel");
#endif
		}

		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
#if defined DEBUG
			LogMessage("Handler_MenuMyRank: MenuAction_End");
#endif
			CloseHandle(menu);
		}

		case MenuAction_DisplayItem:
		{
			//param1 is client, param2 is item

			char item[64], display[256];
			int style;
			menu.GetItem(param2, item, sizeof(item), style, display, sizeof(display));

			if (StrEqual(item, "1"))
			{
				char translation[128];
				Format(translation, sizeof(translation), "%T%s", "MenuWorldRankSubmenu_Time", param1, display);
				return RedrawMenuItem(translation);
			}
			else if(StrEqual(item, "2"))
			{
				char translation[128];
				Format(translation, sizeof(translation), "%T%s", "MenuWorldRankSubmenu_Date", param1, display);
				return RedrawMenuItem(translation);
			}
		}
	}
	return 0;
}