#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>

#define PLUGIN_VERSION "1.2"

#define STRINGLENGTH_CLASSES				  64

static const Float:TRACE_TOLERANCE 			= 25.0;
static const Float:BILE_POS_HEIGHT_FIX		= 70.0;
static const ZOMBIECLASS_BOOMER				= 2;
static const L4D2Team_Survivors				= 2;
static const L4D2Team_Infected				= 3;
static const String:ENTPROP_ZOMBIE_CLASS[] 	= "m_zombieClass";
static const String:GAMEDATA_FILE[]			= "l4d2addresses";
static const String:ENTPROP_IS_GHOST[]		= "m_isGhost";
static const String:CLASS_BILEJAR[]			= "vomitjar_projectile";
static const String:CLASS_ZOMBIE[]			= "infected";
static const String:CLASS_WITCH[]			= "witch";

static const String:VELOCITY_ENTPROP[]		= "m_vecVelocity";
static const Float:SLAP_VERTICAL_MULTIPLIER	= 1.5;

static Handle:isEnabled = 				INVALID_HANDLE;
static Handle:splashRadius = 			INVALID_HANDLE;
static Handle:sdkCallVomitOnPlayer = 	INVALID_HANDLE;
static Handle:sdkCallBileJarPlayer = 	INVALID_HANDLE;
static Handle:sdkCallBileJarInfected = 	INVALID_HANDLE;
static Handle:sdkCallFling			 = 	INVALID_HANDLE;

static Handle:cvar_slapPower		 = INVALID_HANDLE;
static Handle:cvar_slapPower2		 = INVALID_HANDLE;
static Handle:cvar_bFling			 = INVALID_HANDLE;

/* 大巴掌部分 */
#define CHARACTER_NICK								0
#define CHARACTER_ROCHELLE							1
#define CHARACTER_COACH								2
#define CHARACTER_ELLIS								3

#define STRING_LENGHT								56

static const String:GAMEDATA_FILENAME[]				= "l4d2addresses";
static const String:INCAP_ENTPROP[]					= "m_isIncapacitated";
static const String:HANGING_ENTPROP[]				= "m_isHangingFromLedge";
static const String:LEDGEFALLING_ENTPROP[]			= "m_isFallingFromLedge";
static const String:BOOMER_WEAPON[]					= "boomer_claw";
static const String:PUNCH_SOUND[]					= "player/survivor/hit/int/Punch_Boxing_FaceHit1.wav";
static const TEAM_SURVIVOR							= 2;
static Handle:cvar_enabled							= INVALID_HANDLE;
static Handle:cvar_slapCooldownTime					= INVALID_HANDLE;
static Handle:cvar_slapAnnounceMode					= INVALID_HANDLE;
static Handle:cvar_slapOffLedges					= INVALID_HANDLE;
static Handle:cvar_slapOffScreen					= INVALID_HANDLE;
static Handle:cvar_slapOffFadeNum					= INVALID_HANDLE;
static Handle:cvar_VomitPlayer					= INVALID_HANDLE;

static Float:lastSlapTime[MAXPLAYERS+1]				= 0.0;
new bool:ScreenFadeActive[MAXPLAYERS+1];
new ScreenedNumber[MAXPLAYERS+1];

public Plugin:myinfo = 
{
	name = "L4D2 Boomer 增强插件",
	author = " AtomicStryker && 藤野深月(整合修改)",
	description = "对 Boomer 进行增强，胆汁粘液感染",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?p=1237748"
}

public OnPluginStart()
{
	decl String:game[32];
	GetGameFolderName(game, sizeof(game));
	if (!StrEqual(game, "left4dead2", false))
		SetFailState("插件仅仅支持 L4D2.");
	
	PrepSDKCalls();

	CreateConVar("l4d2_bile_the_world_version", PLUGIN_VERSION, " L4D2 Boomer增强 插件版本 "); 
	splashRadius = 	CreateConVar("l4d2_bile_the_world_radius", 	"200", 			" Boomer死亡和呕吐罐上的胆汁飞溅半径 ");
	isEnabled = 	CreateConVar("l4d2_bile_the_world_enabled", "0", 			" Boomer胆汁感染插件开关[0=关 1=开] ");
	cvar_slapPower = CreateConVar("l4d2_bile_the_world_expl_pwr", "150.0", " Boomer死亡对受害者施加了多少推力？ ");
	cvar_bFling  = 	CreateConVar("l4d2_bile_the_world_flingenabled", "0", " 打开和关闭Boomer爆炸投掷 ");
	cvar_VomitPlayer = CreateConVar("l4d2_VomitPlayer_enabled", "0", " Boomer攻击是否胆汁化幸存者 [0=关 1=开] ");
	cvar_enabled = CreateConVar("l4d2_boomerbitchslap_enabled", "0", " 是否开启Boomer 大巴掌？ [0=关 1=开] ");
	cvar_slapPower2 = CreateConVar("l4d2_boomerbitchslap_power", "350.0", " Boomer大巴掌的击飞力量 ");
	cvar_slapCooldownTime = CreateConVar("l4d2_boomerbitchslap_cooldown", "15.0", " Boomer大巴掌的攻击冷却间隔 \n 冷却完成后才能拍飞幸存者 ");
	cvar_slapAnnounceMode = CreateConVar("l4d2_boomerbitchslap_announce", "0", " 是否对玩家进行公告？ ");
	cvar_slapOffLedges = CreateConVar("l4d2_boomerbitchslap_ledgeslap", "0", " Boomer大巴掌拍打玩家能否挂边？");
	cvar_slapOffScreen = CreateConVar("l4d2_boomerbitchslap_Screenslap", "1", " Boomer胆汁是否能够模糊幸存者视线？ [0=关 1=开] ");
	cvar_slapOffFadeNum	 = CreateConVar("l4d2_boomerbitchslap_FadeNum", "150", " Boomer胆汁模糊幸存者最大浓度(0~255) [数值越低越清晰] ");
	
	AutoExecConfig(true, "L4D2_BoomerEnhance_CHS");
	
	//HookEvent("player_death", event_PlayerDeath);
	HookEvent("player_hurt", PlayerHurt);
	HookEvent("round_start", OnRoundStart);
	HookEvent("player_now_it", PlayerNow_It);
	//HookEvent("boomer_exploded", BoomerExploded);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsSurvivor(i) && !IsFakeClient(i))
		{
			ScreenFadeActive[i] = false;
			ScreenedNumber[i] = 0;
		}
	}
}

public Action:BoomerExploded(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	for(new Client = 1; Client <= MaxClients; Client++)
	{
		if (IsSurvivor(Client) && IsPlayerAlive(Client) && GetConVarInt(cvar_slapOffScreen) == 1)
		{
			new Float:PlayerPos[3], Float:InfectedPos[3];
			GetClientAbsOrigin(victim, InfectedPos);
			GetClientAbsOrigin(Client, PlayerPos);
			new Float:Distance = GetVectorDistance(PlayerPos, InfectedPos);
			if (Distance < 100.0 && !ScreenFadeActive[Client])
			{
				ScreenFadeActive[victim] = true;
				//SetEntProp(victim, Prop_Send, "m_iHideHUD", 64);
				CreateTimer(0.1, CreateFade, Client, TIMER_REPEAT);
			}
		}
	}
}

public Action:PlayerNow_It(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsSurvivor(victim) && !ScreenFadeActive[victim] && GetConVarInt(cvar_slapOffScreen) == 1)
	{
		ScreenFadeActive[victim] = true;
		//SetEntProp(victim, Prop_Send, "m_iHideHUD", 64);
		CreateTimer(0.2, CreateFade, victim, TIMER_REPEAT);
	}
}

public Action:CreateFade(Handle:timer, any:victim)
{
	if(IsValidClient(victim) && ScreenFadeActive[victim])
	{
		ScreenedNumber[victim] += 7;
		if(ScreenedNumber[victim] < GetConVarInt(cvar_slapOffFadeNum))
			ScreenFade(victim, 127, 255, 0, ScreenedNumber[victim], 100, 0);
		else
		{
			ScreenedNumber[victim] = GetConVarInt(cvar_slapOffFadeNum);
			ScreenFade(victim, 127, 255, 0, ScreenedNumber[victim], 100, 0);
			KillTimer(timer);
			CreateTimer(10.0, DeleteFade, victim);
		}
	}
}

public Action:DeleteFade(Handle:timer, any:victim)
{
	if(IsValidClient(victim) && ScreenFadeActive[victim])
	{
		//ScreenFade(victim, 0, 0, 0, 0, 0, 1);
		ScreenFade(victim, 127, 255, 0, ScreenedNumber[victim], 100, 1);
		ScreenedNumber[victim] = 0;
		ScreenFadeActive[victim] = false;
		SetEntProp(victim, Prop_Send, "m_iHideHUD", 0);
		L4D_OnITExpired(victim);
		KillTimer(timer);
	}
}

public Action:PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new slapper = GetClientOfUserId(GetEventInt(event, "attacker"));
	new target = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!slapper) slapper = 1;
	if (!target || !IsClientInGame(target)) return;
	
	decl String:weapon[STRING_LENGHT];
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	
	//启用右键胆汁化幸存者
	if (GetConVarInt(cvar_VomitPlayer) != 0 && GetClientTeam(slapper) == 3 && StrEqual(weapon, BOOMER_WEAPON))
	{
		if (IsSurvivor(target) && IsPlayerAlive(target))
		{
			SDKCall(sdkCallBileJarPlayer, target, GetAnyValidSurvivor());
			if (!ScreenFadeActive[target] && GetConVarInt(cvar_slapOffScreen) == 1)
			{
				ScreenFadeActive[target] = true;
				//SetEntProp(target, Prop_Send, "m_iHideHUD", 64);
				CreateTimer(0.1, CreateFade, target, TIMER_REPEAT);
			}
		}
	}
	
	if (GetConVarInt(cvar_enabled)
		&& GetClientTeam(target) == TEAM_SURVIVOR
		&& StrEqual(weapon, BOOMER_WEAPON)
		&& CanSlapAgain(slapper))
	{
		if (!GetEntProp(target, Prop_Send, INCAP_ENTPROP))
		{
			if (!IsFakeClient(target)) // none of this applies for bots.
			{
				PrintCenterText(target, "你被 %N 拍飞了!", slapper);
				
				if (GetConVarInt(cvar_slapAnnounceMode))
					PrintToChatAll("\x04[提示]\x03玩家: \x05%N \x03被\x05 %N \x03一巴掌拍飞了!", target, slapper);

				for (new i=1; i <= MaxClients; i++)
				{
					if (IsClientInGame(i) && !IsFakeClient(i))
					{
						EmitSoundToClient(i, PUNCH_SOUND, target, SNDCHAN_AUTO, SNDLEVEL_GUNFIRE);
					}
				}
			}
			
			PrintCenterText(slapper, "你把玩家 %N 拍飞了!", target);
			
			decl Float:HeadingVector[3], Float:AimVector[3];
			new Float:power = GetConVarFloat(cvar_slapPower2);

			GetClientEyeAngles(slapper, HeadingVector);
		
			AimVector[0] = Cosine(DegToRad(HeadingVector[1])) * power;
			AimVector[1] = Sine(DegToRad(HeadingVector[1]))   * power;
			
			decl Float:current[3];
			GetEntPropVector(target, Prop_Data, VELOCITY_ENTPROP, current);
			
			decl Float:resulting[3];
			resulting[0] = current[0] + AimVector[0];	
			resulting[1] = current[1] + AimVector[1];
			resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
			
			L4D2_Fling(target, resulting, slapper);
			
			lastSlapTime[slapper] = GetEngineTime();
		}
		else if (GetEntProp(target, Prop_Send, HANGING_ENTPROP) && GetConVarBool(cvar_slapOffLedges))
		{
			SetEntProp(target, Prop_Send, INCAP_ENTPROP, 0);
			SetEntProp(target, Prop_Send, HANGING_ENTPROP, 0);
			SetEntProp(target, Prop_Send, LEDGEFALLING_ENTPROP, 0);
		
			StopFallingSounds(target);
			
			PrintCenterText(slapper, "你把玩家 %N 拍飞了!", target);
			PrintCenterText(target, "你被 %N 拍飞了!", slapper);
		}
	}
}

static bool:CanSlapAgain(client)
{
	return ((GetEngineTime() - lastSlapTime[client]) > GetConVarFloat(cvar_slapCooldownTime));
}

stock L4D2_Fling(target, Float:vector[3], attacker, Float:incaptime = 3.0)
{
	new Handle:MySDKCall = INVALID_HANDLE;
	new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
	
	StartPrepSDKCall(SDKCall_Player);
	new bool:bFlingFuncLoaded = PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	if(!bFlingFuncLoaded)
	{
		LogError("Could not load the Fling signature");
	}
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);

	MySDKCall = EndPrepSDKCall();
	if(MySDKCall == INVALID_HANDLE)
	{
		LogError("Could not prep the Fling function");
	}
	
	SDKCall(MySDKCall, target, vector, 76, attacker, incaptime);
}

stock StopFallingSounds(client)
{
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangTwoHands");
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangOneHand");
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangFingers");
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangAboutToFall");
	ClientCommand(client, "music_dynamic_stop_playing Event.LedgeHangFalling");
}

public Action:event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client
	|| !IsClientInGame(client)
	|| GetClientTeam(client) != L4D2Team_Infected
	|| GetEntProp(client, Prop_Send, ENTPROP_ZOMBIE_CLASS) != ZOMBIECLASS_BOOMER)
	{
		return;
	}
	
	decl Float:pos[3];
	GetClientEyePosition(client, pos);

	VomitSplash(true, pos, client);
}

public OnEntityDestroyed(entity)
{
	if (!IsValidEdict(entity)) return;

	decl String:class[STRINGLENGTH_CLASSES];
	GetEdictClassname(entity, class, sizeof(class));
	
	if (!StrEqual(class, CLASS_BILEJAR)) return;
	
	decl Float:pos[3];
	GetEntityAbsOrigin(entity, pos);
	pos[2] += BILE_POS_HEIGHT_FIX;
	
	VomitSplash(false, pos, 0);
}

static VomitSplash(bool:BoomerDeath, Float:pos[3], boomer)
{		
	if (!GetConVarBool(isEnabled)) return;
	
	decl Float:targetpos[3];
	new Float:distancesetting = GetConVarFloat(splashRadius);
	
	if (BoomerDeath)
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)
			|| GetClientTeam(i) != L4D2Team_Infected
			|| !IsPlayerAlive(i)
			|| GetEntProp(i, Prop_Send, ENTPROP_IS_GHOST) != 0)
			{
				continue;
			}
			
			GetClientEyePosition(i, targetpos);
			if (GetVectorDistance(pos, targetpos) > distancesetting
			|| !IsVisibleTo(pos, targetpos))
			{
				continue;
			}
			
			if (GetConVarBool(cvar_bFling))
			{
				decl Float:HeadingVector[3], Float:AimVector[3];
				new Float:power = GetConVarFloat(cvar_slapPower);
				
				HeadingVector[0] = targetpos[0] - pos[0];
				HeadingVector[1] = targetpos[1] - pos[1];
				HeadingVector[2] = targetpos[2] - pos[2];
			
				AimVector[0] = Cosine( DegToRad(HeadingVector[1])  ) * power;
				AimVector[1] = Sine( DegToRad(HeadingVector[1])  )   * power;
				
				decl Float:current[3];
				GetEntPropVector(i, Prop_Data, VELOCITY_ENTPROP, current);
				
				decl Float:resulting[3];
				resulting[0] = current[0] + AimVector[0];	
				resulting[1] = current[1] + AimVector[1];
				resulting[2] = power * SLAP_VERTICAL_MULTIPLIER;
				
				L4D2_Fling2(i, resulting, boomer);
			}
			else
			{
				SDKCall(sdkCallBileJarPlayer, i, GetAnyValidSurvivor());
			}
		}
	
		decl String:class[STRINGLENGTH_CLASSES];
	
		new maxents = GetMaxEntities();
		for (new i = MaxClients+1; i <= maxents; i++)
		{
			if (!IsValidEdict(i)) continue;
			GetEdictClassname(i, class, sizeof(class));
			
			if (!StrEqual(class, CLASS_ZOMBIE)
			&& !StrEqual(class, CLASS_WITCH)) continue;
			
			GetEntityAbsOrigin(i, targetpos);
			if (GetVectorDistance(pos, targetpos) > distancesetting
			|| !IsVisibleTo(pos, targetpos))
			{
				continue;
			}
			SDKCall(sdkCallBileJarInfected, i, GetAnyValidSurvivor());
		}
	}
	else
	{
		for (new i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)
			|| GetClientTeam(i) != L4D2Team_Survivors
			|| !IsPlayerAlive(i))
			{
				continue;
			}
			
			GetClientEyePosition(i, targetpos);
			if (GetVectorDistance(pos, targetpos) > distancesetting
			|| !IsVisibleTo(pos, targetpos))
			{
				continue;
			}
			
			SDKCall(sdkCallVomitOnPlayer, i, GetAnyValidSurvivor(), true);
		}
	}
}

static PrepSDKCalls()
{
	new Handle:ConfigFile = LoadGameConfigFile(GAMEDATA_FILE);
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkCallVomitOnPlayer = EndPrepSDKCall();
	
	if (sdkCallVomitOnPlayer == INVALID_HANDLE)
	{
		SetFailState("Cant initialize OnVomitedUpon SDKCall");
		return;
	}

	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_OnHitByVomitJar");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	sdkCallBileJarPlayer = EndPrepSDKCall();
	
	if (sdkCallBileJarPlayer == INVALID_HANDLE)
	{
		SetFailState("Cant initialize CTerrorPlayer_OnHitByVomitJar SDKCall");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "Infected_OnHitByVomitJar");
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	sdkCallBileJarInfected = EndPrepSDKCall();
	
	if (sdkCallBileJarInfected == INVALID_HANDLE)
	{
		SetFailState("Cant initialize Infected_OnHitByVomitJar SDKCall");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	
	if (sdkCallFling == INVALID_HANDLE)
	{
		SetFailState("Cant initialize Fling SDKCall");
		return;
	}
	
	CloseHandle(ConfigFile);
}

static bool:IsVisibleTo(Float:position[3], Float:targetposition[3])
{
	decl Float:vAngles[3], Float:vLookAt[3];
	
	MakeVectorFromPoints(position, targetposition, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
	
	new Handle:trace = TR_TraceRayFilterEx(position, vAngles, MASK_SHOT, RayType_Infinite, _TraceFilter);
	
	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace);
		
		if ((GetVectorDistance(position, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(position, targetposition))
		{
			isVisible = true;
		}
	}
	else
	{
		LogError("Tracer Bug: Player-Zombie Trace did not hit anything, WTF");
		isVisible = true;
	}
	CloseHandle(trace);
	
	return isVisible;
}

public bool:_TraceFilter(entity, contentsMask)
{
	if (!entity || !IsValidEntity(entity))
	{
		return false;
	}
	
	return true;
}

stock GetEntityAbsOrigin(entity, Float:origin[3])
{
	if (entity && IsValidEntity(entity)
	&& (GetEntSendPropOffs(entity, "m_vecOrigin") != -1)
	&& (GetEntSendPropOffs(entity, "m_vecMins") != -1)
	&& (GetEntSendPropOffs(entity, "m_vecMaxs") != -1))
	{
		decl Float:mins[3], Float:maxs[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
		GetEntPropVector(entity, Prop_Send, "m_vecMins", mins);
		GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxs);
		
		origin[0] += (mins[0] + maxs[0]) * 0.5;
		origin[1] += (mins[1] + maxs[1]) * 0.5;
		origin[2] += (mins[2] + maxs[2]) * 0.5;
	}
}

stock GetAnyValidSurvivor()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)
		&& GetClientTeam(i) == L4D2Team_Survivors)
		{
			return i;
		}
	}
	return 1;
}

stock L4D2_Fling2(target, Float:vector[3], attacker, Float:incaptime = 3.0)
{	
	SDKCall(sdkCallFling, target, vector, 76, attacker, incaptime);
}

stock bool IsSurvivor(client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

public ScreenFade(target, red, green, blue, alpha, duration, type)
{
	if(IsClientInGame(target)){
		new Handle:msg = StartMessageOne("Fade", target);
		BfWriteShort(msg, 500);
		BfWriteShort(msg, duration);
		if (type == 0)
			BfWriteShort(msg, (0x0002 | 0x0008));
		else
			BfWriteShort(msg, (0x0001 | 0x0010));
		BfWriteByte(msg, red);
		BfWriteByte(msg, green);
		BfWriteByte(msg, blue);
		BfWriteByte(msg, alpha);
		EndMessage();
	}
}
