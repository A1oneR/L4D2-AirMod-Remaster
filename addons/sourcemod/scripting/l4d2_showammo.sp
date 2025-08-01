#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

public Plugin:myinfo =
{
	name = "L4D2 ShowAmmo",
	author = "A1R",
	description = "Show teammates ur ammo.",
	version = "0.1",
	url = "https://github.com/A1oneR/L4D2_DRDK_Plugins"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_ammo", ShowAmmo);
}

public Action:ShowAmmo(client, args)
{
	char buffer[32];
	int activeWep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int activeWepId = IdentifyWeapon(activeWep);
	GetLongWeaponName(activeWepId, buffer, sizeof(buffer));
	char name[MAX_NAME_LENGTH]; // string where store text
	GetClientName(client, name, sizeof(name));
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i))
		{
			CPrintToChat(i, "{olive}%s{default} 的 {blue}%s{default} 剩余子弹：[{olive}%i{default}/{olive}%i{default}]", name, buffer, GetWeaponClipAmmo(activeWep), GetWeaponExtraAmmo(client, activeWepId));
		}
	}
	return Plugin_Handled;
}

/**
 *	Stocks
**/
/**
 *	Datamap m_iAmmo
 *	offset to add - gun(s) - control cvar
 *	
 *	+12: M4A1, AK74, Desert Rifle, also SG552 - ammo_assaultrifle_max
 *	+20: both SMGs, also the MP5 - ammo_smg_max
 *	+28: both Pump Shotguns - ammo_shotgun_max
 *	+32: both autoshotguns - ammo_autoshotgun_max
 *	+36: Hunting Rifle - ammo_huntingrifle_max
 *	+40: Military Sniper, AWP, Scout - ammo_sniperrifle_max
 *	+68: Grenade Launcher - ammo_grenadelauncher_max
 */

#define	ASSAULT_RIFLE_OFFSET_IAMMO		12;
#define	SMG_OFFSET_IAMMO				20;
#define	PUMPSHOTGUN_OFFSET_IAMMO		28;
#define	AUTO_SHOTGUN_OFFSET_IAMMO		32;
#define	HUNTING_RIFLE_OFFSET_IAMMO		36;
#define	MILITARY_SNIPER_OFFSET_IAMMO	40;
#define	GRENADE_LAUNCHER_OFFSET_IAMMO	68;

stock int GetWeaponExtraAmmo(int client, int wepid)
{
	static int ammoOffset;
	if (!ammoOffset) ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	
	int offset;
	switch (wepid)
	{
		case WEPID_RIFLE, WEPID_RIFLE_AK47, WEPID_RIFLE_DESERT, WEPID_RIFLE_SG552:
			offset = ASSAULT_RIFLE_OFFSET_IAMMO
		case WEPID_SMG, WEPID_SMG_SILENCED:
			offset = SMG_OFFSET_IAMMO
		case WEPID_PUMPSHOTGUN, WEPID_SHOTGUN_CHROME:
			offset = PUMPSHOTGUN_OFFSET_IAMMO
		case WEPID_AUTOSHOTGUN, WEPID_SHOTGUN_SPAS:
			offset = AUTO_SHOTGUN_OFFSET_IAMMO
		case WEPID_HUNTING_RIFLE:
			offset = HUNTING_RIFLE_OFFSET_IAMMO
		case WEPID_SNIPER_MILITARY, WEPID_SNIPER_AWP, WEPID_SNIPER_SCOUT:
			offset = MILITARY_SNIPER_OFFSET_IAMMO
		case WEPID_GRENADE_LAUNCHER:
			offset = GRENADE_LAUNCHER_OFFSET_IAMMO
		default:
			return -1;
	}
	return GetEntData(client, ammoOffset + offset);
} 

stock int GetWeaponClipAmmo(int weapon)
{
	return (weapon > 0 ? GetEntProp(weapon, Prop_Send, "m_iClip1") : -1);
}