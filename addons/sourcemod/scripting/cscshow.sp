#include <sourcemod>   
#include <multicolors>

public Plugin myinfo =
{
	name = "Show Server Cross Chat",
	author = "A1R",
	description = "Show the server cross chat, and punish someone use /pw command",
	version = "1.0",
	url = "https://github.com/A1oneR/L4D2_DRDK_Plugins"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_msg", CMD_SendMessage, "Listen to this command.");
	RegConsoleCmd("sm_pw", CMD_Password, "And punish this command.");
}

public Action CMD_SendMessage(int client, int args)
{
	if (args < 1)
	{
		return Plugin_Handled;
	}
	
	char arg[32] = "";
	char message[168] = "";
	for (int i = 1; i <= args; i++)
	{
		GetCmdArg(i, arg, sizeof(arg));
		Format(message, sizeof(message), "%s %s", message, arg);
	}
	
	CPrintToChatAll("{lightgreen}[RC]{default} {olive}%N{default}: %s", client, message);
	return;
}

public Action CMD_Password(int client, int args)
{
	FakeClientCommand(client, "say 我是弱智");
	return;
}


