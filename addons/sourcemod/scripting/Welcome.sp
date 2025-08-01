
#include <sourcemod>   
#include <colors>
#include <l4d2_playtime_interface>
#include <versus_stats>
#include <clientprefs>
#include <hexstocks>

// COOKIES
Handle hVibilityCookie;
bool bHide[MAXPLAYERS + 1];

public Plugin:myinfo =    
{   
        name = "Show Your PlayTime",   
        author = "A1R",   
        description = "Show the players real play time.",   
        version = "1.0",   
        url = ""  
}   
   
public OnPluginStart()   
{   
		RegConsoleCmd("sm_display", Player_Time);
		RegConsoleCmd("sm_towel", Cmd_ToggleVis);
		hVibilityCookie = RegClientCookie("Welcome_Vibility", "Show or hide the tags.", CookieAccess_Private);
} 
 
public OnClientConnected(client)   
{       
        char authId[65];
        GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
        int playtime = L4D2_GetTotalPlaytime(authId, true) / 60 / 60;
        if(!IsFakeClient(client))
        {   
                if (playtime > 0)
                {
                        CPrintToChatAll("{olive} %N {default} [{olive}%i小时{default}]正在连接中...",client,playtime);
                        PrintToConsoleAll("\x04 %N \x01 [\x04%i小时]正在连接中...",client,playtime);
                }
                else
                {
                        CPrintToChatAll("{olive} %N {default} 正在连接中...",client);
                        PrintToConsoleAll("\x04 %N \x01 正在连接中...",client);
                }
        }
}

public OnClientPutInServer(client)
{
	if(!IsFakeClient(client) && !bHide[client])
	{
		CreateTimer(1.0, Timer_Welcome, client, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_Welcome(Handle timer, int client)
{
		char authId[65];
		GetClientAuthId(client, AuthId_Steam2, authId, sizeof(authId));
		int playtime = L4D2_GetTotalPlaytime(authId, true) / 60 / 60;
		float sPoints;
		sPoints = GetClientRating(client);
		char Level[16];
		//char name[2048];
		char buffer[MAX_NAME_LENGTH];
		GetClientName(client,buffer,sizeof(buffer));
		if(!IsFakeClient(client) && IsClientInGame(client) && !bHide[client])
        {   
				if (playtime > 0)
				{
						//CPrintToChatAll("{olive} %N {default} [{olive}%i小时{default}]进入了服务器",client,playtime);
						//PrintToConsoleAll("\x04 %N \x01 [\x04%i小时]进入了服务器",client,playtime);
				}
				else
				{
						//CPrintToChatAll("{olive} %N {default} 进入了服务器",client);
						//PrintToConsoleAll("\x04 %N \x01 进入了服务器",client);
				}
				if (sPoints <= 0)
				{
					Level = "UR";
				}
				else if (sPoints > 0 && sPoints < 3)
				{
					Level = "D5";
				}
				else if (sPoints >= 3 && sPoints < 6)
				{
					Level = "D4";
				}
				else if (sPoints >= 6 && sPoints < 9)
				{
					Level = "D3";
				}
				else if (sPoints >= 9 && sPoints < 12)
				{
					Level = "D2";
				}
				else if (sPoints >= 12 && sPoints < 15)
				{
					Level = "D1";
				}
				else if (sPoints >= 15 && sPoints < 20)
				{
					Level = "C5";
				}
				else if (sPoints >= 20 && sPoints < 25)
				{
					Level = "C4";
				}
				else if (sPoints >= 25 && sPoints < 30)
				{
					Level = "C3";
				}
				else if (sPoints >= 30 && sPoints < 35)
				{
					Level = "C2";
				}
				else if (sPoints >= 35 && sPoints < 40)
				{
					Level = "C1";
				}
				else if (sPoints >= 40 && sPoints < 47)
				{
					Level = "B5";
				}
				else if (sPoints >= 47 && sPoints < 54)
				{
					Level = "B4";
				}
				else if (sPoints >= 54 && sPoints < 61)
				{
					Level = "B3";
				}
				else if (sPoints >= 61 && sPoints < 68)
				{
					Level = "B2";
				}
				else if (sPoints >= 68 && sPoints < 75)
				{
					Level = "B1";
				}
				else if (sPoints >= 75 && sPoints < 85)
				{
					Level = "A5";
				}
				else if (sPoints >= 85 && sPoints < 95)
				{
					Level = "A4";
				}
				else if (sPoints >= 95 && sPoints < 105)
				{
					Level = "A3";
				}
				else if (sPoints >= 105 && sPoints < 115)
				{
					Level = "A2";
				}
				else if (sPoints >= 115 && sPoints < 125)
				{
					Level = "A1";
				}
				else if (sPoints >= 125 && sPoints < 140)
				{
					Level = "S3";
				}
				else if (sPoints >= 140 && sPoints < 155)
				{
					Level = "S2";
				}
				else if (sPoints >= 155 && sPoints < 180)
				{
					Level = "S1";
				}
				else if (sPoints >= 180)
				{
					Level = "SS";
				}
				CPrintToChatAll("{olive}%s {default}[Rating:{olive}%.2f{default}; Level:{olive}%s{default}]进入了服务器",buffer,sPoints,Level);
        }
}

public Action Player_Time(int client, int args)
{
        char id[30];
        for (new i = 1 ; i <= MaxClients ; i++)
        {
	        if (IsClientConnected(i) && IsClientInGame(i))
	        {
                        char authId[65];
                        GetClientAuthId(i, AuthId_Steam2, authId, sizeof(authId));
                        int playtime = L4D2_GetTotalPlaytime(authId, true) / 60 / 60;
                        //int playtime2 = L4D2_GetTotalPlaytime(authId, false) / 60 / 24; //DEBUG
                        //int playtime3 = L4D2_GetTotalPlaytime(authId, 1) / 60 / 24; //DEBUG
	        	GetClientAuthId(i,AuthId_Steam2,id,sizeof(id));
	        	if (!StrEqual(id, "BOT"))
	        		if(playtime > 0 )
                                {
                                        CPrintToChat(client, "{olive}%N{default} Has played {red}%i Hours{default}",i,playtime);
                                        //CPrintToChatAll("{olive}%N{default} Has Hold {red}%i Hours{default}",i,playtime2);
                                        //CPrintToChatAll("{olive}%N{default} Has Done {red}%i Hours{default}",i,playtime3);
                                }	
	        		else 
	        			CPrintToChat(client, "{olive}%N{default} Has played {red}Unkown{default} Time",i); 
	        }
        }
}

public Action Cmd_ToggleVis(int client, int args)
{
	if (bHide[client])
	{
		bHide[client] = false;
		ReplyToCommand(client, "[SM] 你的时长已经能被看见.");
	}
	else
	{
		bHide[client] = true;
		ReplyToCommand(client, "[SM] 你的时长已经不可见.");
	}
	
	SetClientCookie(client, hVibilityCookie, bHide[client] ? "0" : "1");
}

public void OnClientCookiesCached(int client)
{
	if (!IsValidClient(client))
		return;
	
	// HideTag cookie
	static char sValue[32];
	GetClientCookie(client, hVibilityCookie, sValue, sizeof(sValue));
	
	bHide[client] = sValue[0] == '\0' ? false : !StringToInt(sValue);
	
	return;
}