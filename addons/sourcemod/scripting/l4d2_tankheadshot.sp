#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

const TANK_ZOMBIE_CLASS = 8;

#define HITGROUP_HEAD	1

#define DEBUG 0

new bool:bLateLoad;
new Handle:hCvarHeadShotFactor;

public const char g_sSniperWeapon[][ENTITY_MAX_NAME_LENGTH] =
{
	"weapon_sniper_scout",
	"weapon_sniper_awp"
};

public APLRes:AskPluginLoad2( Handle:plugin, bool:late, String:error[], errMax )
{
	bLateLoad = late;
	return APLRes_Success;
}

public Plugin:myinfo =
{
	name = "L4D2 TankHeadShot",
	author = "A1R",
	description = "Make Bullet on tank's head be more painful.",
	version = "0.2",
	url = "https://github.com/A1oneR/L4D2_DRDK_Plugins"
};

public OnPluginStart()
{
	if (bLateLoad)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
	hCvarHeadShotFactor = CreateConVar("l4d2_headshot_factor", "1", "the dmg * this one", FCVAR_NONE, true, 0.0);
}

public void OnClientPutInServer(int iClient)
{
	SDKHook(iClient, SDKHook_TraceAttack, TraceAttack);
}

public Action TraceAttack(int iVictim, int &iAttacker, int &iInflictor, float &fDamage, \
								int &fDamageType, int &iAmmoType, int iHitBox, int iHitGroup)
{
	if (iHitGroup != HITGROUP_HEAD) {
		#if DEBUG
			PrintToChatAll("NoHead");
		#endif
		return Plugin_Continue;
	}

	if (!IsValidSurvivor(iAttacker) || IsFakeClient(iAttacker)) {
		return Plugin_Continue;
	}
	
	int iWeapon = GetEntPropEnt(iAttacker, Prop_Send, "m_hActiveWeapon");
	if (iWeapon == -1) {
		return Plugin_Continue;
	}

	char sClassName[64];
	GetEdictClassname(iWeapon, sClassName, sizeof(sClassName));
	if (!IsValidSniper(sClassName)) {
		return Plugin_Continue;
	}

#if DEBUG
	char szHitgroup[32];
	HitgroupToString(iHitGroup, szHitgroup, sizeof(szHitgroup));
	PrintToChatAll("Victim %N, attacker %N, hitgroup %s (%d), weapon: %s, ", iVictim, iAttacker, szHitgroup, iHitGroup, sClassName);
#endif
	if (IsTank(iVictim))
	{
		fDamage = GetWeaponDamage(iWeapon) * GetConVarFloat(hCvarHeadShotFactor);
		//PrintToChatAll("Damage: %.2f", fDamage);
		//PrintToChatAll("\x04%N\x01 用\x05狙击枪\x01爆头了 \x04%N\x01的Tank，伤害: %.1f", iAttacker, iVictim, fdamage);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

bool IsValidSniper(const char[] sWeaponName)
{
	for (int i = 0; i < sizeof(g_sSniperWeapon); i++) {
		if (strcmp(sWeaponName, g_sSniperWeapon[i]) == 0) {
			return true;
		}
	}

	return false;
}

/*
HitgroupToString(hitgroup, String:destination[], maxlength)
{
	new String:buffer[32];
	switch (hitgroup)
	{
		case 0:
		{
			buffer = "generic";
		}
		case 1:
		{
			buffer = "head";
		}
		case 2:
		{
			buffer = "chest";
		}
		case 3:
		{
			buffer = "stomach";
		}
		case 4:
		{
			buffer = "left arm";
		}
		case 5:
		{
			buffer = "right arm";
		}
		case 6:
		{
			buffer = "left leg";
		}
		case 7:
		{
			buffer = "right leg";
		}
		case 10:
		{
			buffer = "gear";
		}
	}
	strcopy(destination, maxlength, buffer);
}
*/

GetClientActiveWeapon(client)
{
	return GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
}

GetWeaponDamage(weapon)
{
	decl String:classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	return L4D2_GetIntWeaponAttribute(classname, L4D2IntWeaponAttributes:L4D2IWA_Damage);
}
