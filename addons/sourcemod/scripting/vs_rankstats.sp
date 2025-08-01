#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <colors>

#undef REQUIRE_PLUGIN
#include <versus_stats>
#define REQUIRE_PLUGIN


public Plugin myinfo = { 
	name = "VersusStatsRankstats",
	author = "TouchMe",
	description = "Displaying statistics as a menu",
	version = "build_0001",
	url = "https://github.com/TouchMe-Inc/l4d2_versus_stats"
};


// Libs
#define LIB_VERSUS_STATS        "versus_stats"

// Other
#define PER_PAGE                7
#define TRANSLATIONS            "vs_rankstats.phrases"
#define CONFIG_FILEPATH         "configs/vs_rankstats.ini"

// Macros
#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)


ArrayList
	g_aViewStats = null;

bool
	g_bVersusStatsAvailable = false;

int
	g_iClientTarget[MAXPLAYERS + 1] = {0, ...},
	g_iClientPage[MAXPLAYERS + 1] = {0, ...};


/**
  * Global event. Called when all plugins loaded.
  */
public void OnAllPluginsLoaded() {
	g_bVersusStatsAvailable = LibraryExists(LIB_VERSUS_STATS);
}

/**
  * Global event. Called when a library is removed.
  *
  * @param sName     Library name
  */
public void OnLibraryRemoved(const char[] sName) 
{
	if (StrEqual(sName, LIB_VERSUS_STATS)) {
		g_bVersusStatsAvailable = false;
	}
}

/**
  * Global event. Called when a library is added.
  *
  * @param sName     Library name
  */
public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, LIB_VERSUS_STATS)) {
		g_bVersusStatsAvailable = true;
	}
}

/**
 * Called before OnPluginStart.
 * 
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure 
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2) {
		strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

/**
 * Loads dictionary files. On failure, stops the plugin execution.
 */
void InitTranslations()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "translations/" ... TRANSLATIONS ... ".txt");

	if (FileExists(sPath)) {
		LoadTranslations(TRANSLATIONS);
	} 
	
	else {
		SetFailState("Path %s not found", sPath);
	}
}

/**
 * Called when the plugin is fully initialized and all known external references are resolved.
 */
public void OnPluginStart()
{
	InitTranslations();

	g_aViewStats = new ArrayList();
	ReadViewStats();
	InitCmds();
}

public void OnPluginEnd()
{
	if (g_aViewStats != null) {
		delete g_aViewStats;
	}
}

/**
  * File reader. Opens and reads lines in config/weapon_vote.ini.
  */
void ReadViewStats()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, CONFIG_FILEPATH);
	
	if (!FileExists(sPath)) {
		SetFailState("Path %s not found", sPath);
	}

	File hFile = OpenFile(sPath, "rt");
	if (!hFile) {
		SetFailState("Could not open file %s!", sPath);
	}
	
	while (!hFile.EndOfFile())
	{
		char sCurLine[255];
		if (!hFile.ReadLine(sCurLine, sizeof(sCurLine))) {
			break;
		}
		
		int iLineLength = strlen(sCurLine);

		for (int iChar = 0; iChar < iLineLength; iChar++)
		{
			if (sCurLine[iChar] == '/' && iChar != iLineLength - 1 && sCurLine[iChar + 1] == '/')
			{
				sCurLine[iChar] = '\0';
				break;
			}
		}
		
		TrimString(sCurLine);
		
		if ((sCurLine[0] == '/' && sCurLine[1] == '/') || (sCurLine[0] == '\0')) {
			continue;
		}
	
		ParseLine(sCurLine);
	}
	
	hFile.Close();
}

/**
  * File line parser.
  *
  * @param sLine 			Line
  */
void ParseLine(const char[] sLine) { 
	g_aViewStats.Push(StringToInt(sLine));
}

/**
 * Fragment.
 */
void InitCmds()
{
	RegConsoleCmd("sm_rank", Cmd_ShowRank);
	RegConsoleCmd("sm_rankstats", Cmd_ShowRankStats);
}

public Action Cmd_ShowRank(int iClient, int iArgs)
{
	if (!g_bVersusStatsAvailable || !IS_VALID_CLIENT(iClient)) {
		return Plugin_Continue;
	}

	int iRank = GetClientRank(iClient);

	if (iRank > 0)
	{
		CPrintToChat(iClient, "%T", "RANK", iClient, iRank);
		return Plugin_Continue;
	}

	float fNeedPlayedTime = GetNeedPlayedTime(iClient);

	if (fNeedPlayedTime == 0.0) {
		CPrintToChat(iClient, "%T", "RANK_IN_PROGRESS", iClient);
	} else {
		CPrintToChat(iClient, "%T", "RANK_NONE", iClient, fNeedPlayedTime);
	}

	return Plugin_Continue;
}

public Action Cmd_ShowRankStats(int iClient, int iArgs)
{
	if (!g_bVersusStatsAvailable || !IS_VALID_CLIENT(iClient)) {
		return Plugin_Continue;
	}

	int iTarget = iClient;

	if (iArgs > 0)
	{
		char sArg[32];
		GetCmdArg(1, sArg, sizeof(sArg));

		iTarget = FindOneTarget(iClient, sArg);

		if (iTarget == -1)
		{
			CPrintToChat(iClient, "%T", "RANKSTATS_BAD_ARG", iClient, sArg);
			return Plugin_Continue;
		}
	}

	RankStats(iClient, g_iClientTarget[iClient] = iTarget, g_iClientPage[iClient] = 0);

	return Plugin_Continue;
}

void RankStats(int iClient, int iTarget, int iPage) 
{
	Panel hPanel = new Panel();

	char sTemp[128];

	Format(sTemp, sizeof(sTemp), "%T", "RANKSTATS_TITLE", iClient, GetClientRank(iTarget), iTarget, SecToHours(GetClientPlayedTime(iTarget)), GetClientRating(iTarget));
	hPanel.SetTitle(sTemp);
	hPanel.DrawText(" ");

	int iStart = iPage * PER_PAGE;
	int iEnd = (iPage + 1) * PER_PAGE;
	int iSpace = 0;
	int iSize = g_aViewStats.Length;

	if (iEnd > iSize)
	{
		iSpace = iEnd - iSize;
		iEnd = iSize;
	}

	int iCodeStats;
	char sPattern[16];
	for (int iItem = iStart; iItem < iEnd; iItem++)
	{
		iCodeStats = g_aViewStats.Get(iItem);
		Format(sPattern, sizeof(sPattern), "CODE_STATS_%d", iCodeStats);
		Format(sTemp, sizeof(sTemp), "%T", sPattern, iClient, GetClientStats(iTarget, iCodeStats));
		hPanel.DrawText(sTemp);
	}

	for (int i = 0; i < iSpace; i++)
	{
		hPanel.DrawText(" ");
	}

	hPanel.DrawText(" ");

	Format(sTemp, sizeof(sTemp), "%T", "NEXT", iClient);
	hPanel.DrawItem(sTemp, iEnd < iSize ? ITEMDRAW_CONTROL : ITEMDRAW_DISABLED);

	if (iPage == 0) {
		Format(sTemp, sizeof(sTemp), "%T", "CLOSE", iClient);
		hPanel.DrawItem(sTemp, ITEMDRAW_CONTROL);
	} else {
		Format(sTemp, sizeof(sTemp), "%T", "BACK", iClient);
		hPanel.DrawItem(sTemp, ITEMDRAW_CONTROL);
	}

	hPanel.Send(iClient, HandleRankStats, MENU_TIME_FOREVER);

	delete hPanel;
}

public int HandleRankStats(Menu hMenu, MenuAction action, int iClient, int iSelectedIndex)
{
	if (action == MenuAction_Select)
	{
		switch (iSelectedIndex) 
		{
			case 1: {
				if (++ g_iClientPage[iClient] * PER_PAGE < g_aViewStats.Length) {
					RankStats(iClient, g_iClientTarget[iClient], g_iClientPage[iClient]);
				}
			}

			case 2: {
				if (-- g_iClientPage[iClient] >= 0) {
					RankStats(iClient, g_iClientTarget[iClient], g_iClientPage[iClient]);
				}
			}
		}
	}

	return 0;
}

float GetNeedPlayedTime(int iClient) 
{
	float fDelta = GetMinRankedHours() - SecToHours(GetClientPlayedTime(iClient));

	return fDelta < 0.0 ? 0.0 : fDelta;
}

/*
 * Returns the player that was found by the request.
 */
int FindOneTarget(int iClient, const char[] sTarget)
{
	char iTargetName[MAX_TARGET_LENGTH];
	int iTargetList[1];
	bool isMl;
	
	if (ProcessTargetString(
			sTarget,
			iClient, 
			iTargetList, 
			1, 
			COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_BOTS,
			iTargetName,
			sizeof(iTargetName),
			isMl) > 0)
	{
		return iTargetList[0];
	}

	return -1;
}
