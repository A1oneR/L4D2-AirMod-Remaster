#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = 
{
    name = "AI Tank Penalty",
    author = "Stabby",
    version = "0.2",
    description = "Penalty tanks on pass to AI."
};

new Handle:hKillOnCrash = INVALID_HANDLE;

public OnPluginStart() 
{
	hKillOnCrash = CreateConVar("tankgank_killoncrash",	"0",
								"If 0, tank will not be killed if the player that controlled it crashes.",
								FCVAR_PLUGIN, true,  0.0, true, 1.0);
	HookEvent("player_bot_replace", OnTankGoneAi);
}

public Action:OnTankGoneAi(Handle:event, const String: name[], bool:dontBroadcast)
{	
	new formerTank = GetClientOfUserId(GetEventInt(event, "player"));
	new newTank = GetClientOfUserId(GetEventInt(event, "bot"));
	
	if (GetClientTeam(newTank) == 3 && GetEntProp(newTank, Prop_Send, "m_zombieClass") == 8)
	{
		if (formerTank == 0 && !GetConVarBool(hKillOnCrash) )	//if people disconnect, formerTank = 0 instead of the old player's id
		{
			CreateTimer(6.0, Timed_CheckAndKill, newTank);
			return;
		}
		CreateTimer(6.0, Timed_CheckAndKill, newTank);
	}
}

public Action:Timed_CheckAndKill(Handle:unused, any:newTank)
{
	if (IsFakeClient(newTank))
	{
		CreateTimer(60.0, Timed_Kill, newTank);	
		PrintToChatAll("\x03[\x01WM\x03]\x01 Tank进入AI阶段，将于60秒后处死");
	}
}

public Action:Timed_Kill(Handle:unused, any:newTank)
{
	if (IsFakeClient(newTank))
	{
		ForcePlayerSuicide(newTank);
	}
}