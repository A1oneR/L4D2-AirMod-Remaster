#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <colors>

Handle
	g_hTimer;

ConVar
	g_hDisplayTime;

float
	g_fDisplayTime;

bool
	g_bLeftSafeArea,
	bLetzPrintIt = false;

int g_iTotalSIDmg;
int g_iTotalSIKill;
int g_iTotalCIKill;
int g_iTotalFF;
int g_iTotalRF;

enum struct esData
{
	int iSIDmg;
	int iSIKill;
	int iCIKill;
	int iSIHead;
	int iCIHead;
	int iTeamFF;
	int iTeamRF;

	int iTotalTankDmg;
	int iLastTankHealth;
	int iTankDmg[MAXPLAYERS + 1];
	int iTankClaw[MAXPLAYERS + 1];
	int iTankRock[MAXPLAYERS + 1];
	int iTankHittable[MAXPLAYERS + 1];

	void CleanInfected()
	{
		this.iSIDmg = 0;
		this.iSIKill = 0;
		this.iCIKill = 0;
		this.iSIHead = 0;
		this.iCIHead = 0;
		this.iTeamFF = 0;
		this.iTeamRF = 0;
	}

	void CleanTank()
	{
		this.iTotalTankDmg = 0;
		this.iLastTankHealth = 0;

		for(int i = 1; i <= MaxClients; i++)
		{
			this.iTankDmg[i] = 0;
			this.iTankClaw[i] = 0;
			this.iTankRock[i] = 0;
			this.iTankHittable[i] = 0;
		}
	}
}

esData
	g_esData[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "击杀排行统计",
	description = "击杀排行统计",
	author = "白色幽灵 WhiteGT",
	version = "0.6",
	url = ""
};

public void OnPluginStart()
{
	//g_hDisplayTime = CreateConVar("sm_mvp_time", "240.0", "轮播时间间隔", FCVAR_NOTIFY, true, 0.0, true, 360.0);
	//g_hDisplayTime.AddChangeHook(vConVarChanged);

	//AutoExecConfig(true,"l4d_mvp");

	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("map_transition", Event_MapTransition);
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea);
	HookEvent("player_left_checkpoint", Event_PlayerLeftStartArea);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("infected_death", Event_InfectedDeath);
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_incapacitated_start", Event_PlayerIncapacitatedStart);
	
	RegConsoleCmd("sm_mvp", cmdDisplay, "Show Mvp");
}

/*
public void OnConfigsExecuted()
{
	g_fDisplayTime = g_hDisplayTime.FloatValue;
}

void vConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fDisplayTime = g_hDisplayTime.FloatValue;

	delete g_hTimer;
	if(g_fDisplayTime > 0.0 && g_bLeftSafeArea)
		g_hTimer = CreateTimer(g_fDisplayTime, tmrDisplayInfected);
}
*/

Action cmdDisplay(int client, int args)
{
	if(!client || !IsClientInGame(client))
		return Plugin_Handled;

	vDisplayInfectedManually(client);
	return Plugin_Handled;
}

/*
Action tmrDisplayInfected(Handle timer)
{
	g_hTimer = null;

	vDisplayInfected();

	if(g_fDisplayTime > 0.0)
		g_hTimer = CreateTimer(g_fDisplayTime, tmrDisplayInfected);

	return Plugin_Continue;
}
*/

public void OnClientDisconnect(int client)
{
	g_iTotalSIDmg -= g_esData[client].iSIDmg;
	g_iTotalSIKill -= g_esData[client].iSIKill;
	g_iTotalCIKill -= g_esData[client].iCIKill;
	g_iTotalFF -= g_esData[client].iTeamFF;
	g_iTotalRF -= g_esData[client].iTeamRF;
	
	g_esData[client].CleanInfected();
	g_esData[client].CleanTank();

	for(int i = 1; i <= MaxClients; i++)
	{
		g_esData[i].iTankDmg[client] = 0;
		g_esData[i].iTankClaw[client] = 0;
		g_esData[i].iTankRock[client] = 0;
		g_esData[i].iTankHittable[client] = 0;
	}
}

public void OnMapEnd()
{
	delete g_hTimer;
	g_bLeftSafeArea = false;

	vClearInfectedData();
	vClearTankData();
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (bLetzPrintIt)
    {
        vDisplayInfected();
    }
	bLetzPrintIt = false;
	OnMapEnd();
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	bLetzPrintIt = true;
	delete g_hTimer;
}

void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
	delete g_hTimer;
	//vDisplayInfected();
}

void Event_PlayerLeftStartArea(Event event, const char[] name, bool dontBroadcast)
{ 
	if(g_bLeftSafeArea)
		return;

	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client))
		CreateTimer(0.1, tmrPlayerLeftStartArea, _, TIMER_FLAG_NO_MAPCHANGE);
}

Action tmrPlayerLeftStartArea(Handle timer)
{
	if(!g_bLeftSafeArea && bHasAnySurvivorLeftSafeArea())
	{
		g_bLeftSafeArea = true;
		
		/*
		delete g_hTimer;
		if(g_fDisplayTime > 0.0)
			g_hTimer = CreateTimer(g_fDisplayTime, tmrDisplayInfected);
		*/
	}

	return Plugin_Continue;
}

bool bHasAnySurvivorLeftSafeArea()
{
	int entity = GetPlayerResourceEntity();
	if(entity == INVALID_ENT_REFERENCE)
		return false;

	return !!GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea");
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!attacker || !IsClientInGame(attacker))
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!victim || victim == attacker || !IsClientInGame(victim))
		return;

	switch(GetClientTeam(victim))
	{
		case 2:
		{
			switch(GetClientTeam(attacker))
			{
				case 2:
				{
					int dmg = event.GetInt("dmg_health");
					g_iTotalFF += dmg;
					g_esData[attacker].iTeamFF += dmg;

					g_iTotalRF += dmg;
					g_esData[victim].iTeamRF += dmg;
				}

				case 3:
				{
					if(GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8)
					{
						char sWeapon[32];
						event.GetString("weapon", sWeapon, sizeof sWeapon);
						if(strcmp(sWeapon, "tank_claw") == 0)
							g_esData[attacker].iTankClaw[victim]++;
						else if(strcmp(sWeapon, "tank_rock") == 0)
							g_esData[attacker].iTankRock[victim]++;
						else
							g_esData[attacker].iTankHittable[victim]++;
					}
				}
			}
		}
		
		case 3:
		{
			if(GetClientTeam(attacker) == 2)
			{
				int dmg = event.GetInt("dmg_health");
				switch(GetEntProp(victim, Prop_Send, "m_zombieClass"))
				{
					case 1, 2, 3, 4, 5, 6:
					{
						g_iTotalSIDmg += dmg;
						g_esData[attacker].iSIDmg += dmg;
					}
		
					case 8:
					{
						if(!GetEntProp(victim, Prop_Send, "m_isIncapacitated"))
						{
							g_esData[victim].iTotalTankDmg += dmg;
							g_esData[victim].iTankDmg[attacker] += dmg;

							g_esData[victim].iLastTankHealth = event.GetInt("health");
						}
					}
				}
			}
		}
	}
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 3)
		return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int iClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
	if(iClass == 8)
	{
		g_esData[victim].iTotalTankDmg += g_esData[victim].iLastTankHealth;
		g_esData[victim].iTankDmg[attacker] += g_esData[victim].iLastTankHealth;

		//vDisPlayTank(victim);
	}

	if(!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	if(event.GetBool("headshot"))
		g_esData[attacker].iSIHead++;

	switch(iClass)
	{
		case 1, 2, 3, 4, 5, 6:
		{
			g_iTotalSIKill++;
			g_esData[attacker].iSIKill++;
		}
		
		case 8:
			g_esData[attacker].iSIKill++;
	}
}

void Event_InfectedDeath(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 2)
		return;

	if(event.GetBool("headshot"))
		g_esData[attacker].iCIHead++;

	g_iTotalCIKill++;
	g_esData[attacker].iCIKill++;
}

void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(client && IsClientInGame(client))
		g_esData[client].CleanTank();
}

void Event_PlayerIncapacitatedStart(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if(!attacker || !IsClientInGame(attacker) || GetClientTeam(attacker) != 3 || GetEntProp(attacker, Prop_Send, "m_zombieClass") != 8)
		return;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if(!victim || !IsClientInGame(victim) || GetClientTeam(victim) != 2)
		return;
	
	char sWeapon[32];
	event.GetString("weapon", sWeapon, sizeof sWeapon);
	if(strcmp(sWeapon, "tank_claw") == 0)
		g_esData[attacker].iTankClaw[victim]++;
	else if(strcmp(sWeapon, "tank_rock") == 0)
		g_esData[attacker].iTankRock[victim]++;
	else
		g_esData[attacker].iTankHittable[victim]++;
}

void vDisplayInfected()
{
	int client;
	int iCount;
	int[] iClients = new int[MaxClients];
	for(client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && (!IsFakeClient(client) || GetClientTeam(client) == 2) && GetClientTeam(client) == 2)
			iClients[iCount++] = client;
	}

	if(!iCount)
		return;

	int iSIDmg;
	int iSIKill;
	int iSIHead;
	int iCIKill;
	int iCIHead;
	int iTeamFF;
	int iTeamRF;

	CPrintToChatAll("{olive}[{default}Air{olive}]{default}伤害统计");

	SortCustom1D(iClients, iCount, iSortSIKill);
	int iPlayer = iCount < 4 ? iCount : 4;
	for(int i; i < iPlayer; i++)
	{
		client = iClients[i];
		iSIKill = g_esData[client].iSIKill;
		iCIKill = g_esData[client].iCIKill;
		iSIHead = g_esData[client].iSIHead;
		iTeamFF = g_esData[client].iTeamFF;
		iTeamRF = g_esData[client].iTeamRF;
		iSIDmg = g_esData[client].iSIDmg;
		iCIHead = g_esData[client].iCIHead;
		CPrintToChatAll("{olive}%N{default} ★ {blue}[{default}特感: {olive}%d{default}/{olive}%d {blue}] [{default}丧尸: {olive}%d{default}/{olive}%d {blue}] [{default}伤害: {olive}%d {blue}] [友伤: \x05%d]", client, iSIKill, iSIHead, iCIKill, iCIHead, iSIDmg, iTeamFF);
	}

	SortCustom1D(iClients, iCount, iSortSIDamage);
	client = iClients[0];
	iSIDmg = g_esData[client].iSIDmg;
	iSIKill = g_esData[client].iSIKill;
	if(iSIKill > 0)
		PrintToChatAll("\x04★ \x01特感杀手: \x05%N \x01伤害: \x05%d\x01(\x04%d%%\x01) 击杀: \x05%d\x01(\x04%d%%\x01)", client, iSIDmg, RoundToNearest(float(iSIDmg) / float(g_iTotalSIDmg) * 100.0), iSIKill, RoundToNearest(float(iSIKill) / float(g_iTotalSIKill) * 100.0));

	SortCustom1D(iClients, iCount, iSortCIKill);
	client = iClients[0];
	iCIKill = g_esData[client].iCIKill;
	iCIHead = g_esData[client].iCIHead;
	if(iCIKill > 0)
		PrintToChatAll("\x04★ \x01清尸狂人: \x05%N \x01击杀: \x05%d\x01(\x04%d%%\x01) 爆头: \x05%d\x01(\x04%d%%\x01)", client, iCIKill, RoundToNearest(float(iCIKill) / float(g_iTotalCIKill) * 100.0), iCIHead, RoundToNearest(float(iCIHead) / float(iCIKill) * 100.0));

	SortCustom1D(iClients, iCount, iSortTeamFF);
	client = iClients[0];
	iTeamFF = g_esData[client].iTeamFF;
	if(iTeamFF > 0)
		PrintToChatAll("\x04★ \x01黑枪之王: \x05%N \x01友伤: \x05%d\x01(\x04%d%%\x01)", client, iTeamFF, RoundToNearest(float(iTeamFF) / float(g_iTotalFF) * 100.0));

	SortCustom1D(iClients, iCount, iSortTeamRF);
	client = iClients[0];
	iTeamRF = g_esData[client].iTeamRF;
	if(iTeamRF > 0)
		PrintToChatAll("\x04★ \x01挨枪之王: \x05%N \x01被黑: \x05%d\x01(\x04%d%%\x01)", client, iTeamRF, RoundToNearest(float(iTeamRF) / float(g_iTotalRF) * 100.0));
}

void vDisplayInfectedManually(int Iclient)
{
	int client;
	int iCount;
	int[] iClients = new int[MaxClients];
	for(client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && (!IsFakeClient(client) || GetClientTeam(client) == 2) && GetClientTeam(client) == 2)
			iClients[iCount++] = client;
	}

	if(!iCount)
		return;

	int iSIDmg;
	int iSIKill;
	int iSIHead;
	int iCIKill;
	int iCIHead;
	int iTeamFF;
	int iTeamRF;

	CPrintToChat(Iclient, "{olive}[{default}Air{olive}]{default}伤害统计");

	SortCustom1D(iClients, iCount, iSortSIKill);
	int iPlayer = iCount < 4 ? iCount : 4;
	for(int i; i < iPlayer; i++)
	{
		client = iClients[i];
		iSIKill = g_esData[client].iSIKill;
		iCIKill = g_esData[client].iCIKill;
		iSIHead = g_esData[client].iSIHead;
		iTeamFF = g_esData[client].iTeamFF;
		iTeamRF = g_esData[client].iTeamRF;
		iSIDmg = g_esData[client].iSIDmg;
		iCIHead = g_esData[client].iCIHead;
		CPrintToChat(Iclient, "{olive}%N{default} ★ {blue}[{default}特感: {olive}%d{default}/{olive}%d {blue}] [{default}丧尸: {olive}%d{default}/{olive}%d {blue}] [{default}伤害: {olive}%d {blue}] [友伤: \x05%d]", client, iSIKill, iSIHead, iCIKill, iCIHead, iSIDmg, iTeamFF);
	}

	SortCustom1D(iClients, iCount, iSortSIDamage);
	client = iClients[0];
	iSIDmg = g_esData[client].iSIDmg;
	iSIKill = g_esData[client].iSIKill;
	if(iSIKill > 0)
		PrintToChat(Iclient, "\x04★ \x01特感杀手: \x05%N \x01伤害: \x05%d\x01(\x04%d%%\x01) 击杀: \x05%d\x01(\x04%d%%\x01)", client, iSIDmg, RoundToNearest(float(iSIDmg) / float(g_iTotalSIDmg) * 100.0), iSIKill, RoundToNearest(float(iSIKill) / float(g_iTotalSIKill) * 100.0));

	SortCustom1D(iClients, iCount, iSortCIKill);
	client = iClients[0];
	iCIKill = g_esData[client].iCIKill;
	iCIHead = g_esData[client].iCIHead;
	if(iCIKill > 0)
		PrintToChat(Iclient, "\x04★ \x01清尸狂人: \x05%N \x01击杀: \x05%d\x01(\x04%d%%\x01) 爆头: \x05%d\x01(\x04%d%%\x01)", client, iCIKill, RoundToNearest(float(iCIKill) / float(g_iTotalCIKill) * 100.0), iCIHead, RoundToNearest(float(iCIHead) / float(iCIKill) * 100.0));

	SortCustom1D(iClients, iCount, iSortTeamFF);
	client = iClients[0];
	iTeamFF = g_esData[client].iTeamFF;
	if(iTeamFF > 0)
		PrintToChat(Iclient, "\x04★ \x01黑枪之王: \x05%N \x01友伤: \x05%d\x01(\x04%d%%\x01)", client, iTeamFF, RoundToNearest(float(iTeamFF) / float(g_iTotalFF) * 100.0));

	SortCustom1D(iClients, iCount, iSortTeamRF);
	client = iClients[0];
	iTeamRF = g_esData[client].iTeamRF;
	if(iTeamRF > 0)
		PrintToChat(Iclient, "\x04★ \x01挨枪之王: \x05%N \x01被黑: \x05%d\x01(\x04%d%%\x01)", client, iTeamRF, RoundToNearest(float(iTeamRF) / float(g_iTotalRF) * 100.0));
}

void vDisPlayTank(int tank)
{
	ArrayList aClients = new ArrayList(2);

	int i = 1;
	for(; i <= MaxClients; i++)
	{
		if(g_esData[tank].iTankDmg[i] > 0 && IsClientInGame(i) && (!IsFakeClient(i) || GetClientTeam(i) == 2))
			aClients.Set(aClients.Push(g_esData[tank].iTankDmg[i]), i, 1);
	}

	int iLength = aClients.Length;
	if(!iLength)
	{
		delete aClients;
		return;
	}

	char sName[MAX_NAME_LENGTH];
	FormatEx(sName, sizeof sName, "[%s] %N", IsFakeClient(tank) ? "AI" : "PLAYER", tank);
	CPrintToChatAll("{default}[{red}%s{default}] {olive}%N {default}伤害承受: {red}%d", IsFakeClient(tank) ? "AI" : "PLAYER", tank, g_esData[tank].iTotalTankDmg);
	aClients.Sort(Sort_Descending, Sort_Integer);

	int client;
	int damage;
	int percent;
	for(i = 0; i < iLength; i++)
	{
		client = aClients.Get(i, 1);
		damage = aClients.Get(i, 0);
		percent = RoundToNearest(float(damage) / float(g_esData[tank].iTotalTankDmg) * 100.0);
		CPrintToChatAll("{green}★ {red}%-5d{default}({green}%-2d%%{default}) 吃拳: {red}%-2d {default}吃饼: {red}%-2d {default}吃铁: {red}%-3d {olive}%N", damage , percent, g_esData[tank].iTankClaw[client], g_esData[tank].iTankRock[client], g_esData[tank].iTankHittable[client], client);
	}

	delete aClients;
}

int iSortSIDamage(int elem1, int elem2, const int[] array, Handle hndl)
{
	if(g_esData[elem2].iSIDmg < g_esData[elem1].iSIDmg)
		return -1;
	else if(g_esData[elem1].iSIDmg < g_esData[elem2].iSIDmg)
		return 1;

	if(elem1 > elem2)
		return -1;
	else if(elem2 > elem1)
		return 1;

	return 0;
}

int iSortSIKill(int elem1, int elem2, const int[] array, Handle hndl)
{
	if(g_esData[elem2].iSIKill < g_esData[elem1].iSIKill)
		return -1;
	else if(g_esData[elem1].iSIKill < g_esData[elem2].iSIKill)
		return 1;

	if(elem1 > elem2)
		return -1;
	else if(elem2 > elem1)
		return 1;

	return 0;
}

int iSortCIKill(int elem1, int elem2, const int[] array, Handle hndl)
{
	if(g_esData[elem2].iCIKill < g_esData[elem1].iCIKill)
		return -1;
	else if(g_esData[elem1].iCIKill < g_esData[elem2].iCIKill)
		return 1;

	if(elem1 > elem2)
		return -1;
	else if(elem2 > elem1)
		return 1;

	return 0;
}

int iSortTeamFF(int elem1, int elem2, const int[] array, Handle hndl)
{
	if(g_esData[elem2].iTeamFF < g_esData[elem1].iTeamFF)
		return -1;
	else if(g_esData[elem1].iTeamFF < g_esData[elem2].iTeamFF)
		return 1;

	if(elem1 > elem2)
		return -1;
	else if(elem2 > elem1)
		return 1;

	return 0;
}

int iSortTeamRF(int elem1, int elem2, const int[] array, Handle hndl)
{
	if(g_esData[elem2].iTeamRF < g_esData[elem1].iTeamRF)
		return -1;
	else if(g_esData[elem1].iTeamRF < g_esData[elem2].iTeamRF)
		return 1;

	if(elem1 > elem2)
		return -1;
	else if(elem2 > elem1)
		return 1;

	return 0;
}

void vClearInfectedData()
{
	g_iTotalSIDmg = 0;
	g_iTotalSIKill = 0;
	g_iTotalCIKill = 0;
	g_iTotalFF = 0;
	g_iTotalRF = 0;

	for(int i = 1; i <= MaxClients; i++)
		g_esData[i].CleanInfected();
}

void vClearTankData()
{
	for(int i = 1; i <= MaxClients; i++)
		g_esData[i].CleanTank();
}