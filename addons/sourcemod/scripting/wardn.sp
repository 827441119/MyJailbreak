#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <wardn>

#define LoopAliveClients(%1) for(int %1 = 1;%1 <= MaxClients;%1++) if(IsValidClient(%1, true))

#define PLUGIN_VERSION   "0.1"

int Warden = -1;
int tempwarden[MAXPLAYERS+1] = -1;

Handle g_cVar_mnotes;
Handle g_fward_onBecome;
Handle g_fward_onRemove;
Handle gF_OnWardenCreatedByUser = null;
Handle gF_OnWardenCreatedByAdmin = null;
Handle gF_OnWardenDisconnected = null;
Handle gF_OnWardenDeath = null;
Handle gF_OnWardenRemovedBySelf = null;
Handle gF_OnWardenRemovedByAdmin = null;

public Plugin myinfo = {
	name = "MyJailbreak - Warden",
	author = "shanapu, ecca & .#zipcore",
	description = "Jailbreak Warden script",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart() 
{
    // Translation
	LoadTranslations("warden.phrases");
	// Client commands
	RegConsoleCmd("sm_w", BecomeWarden);
	RegConsoleCmd("sm_warden", BecomeWarden);
	RegConsoleCmd("sm_uw", ExitWarden);
	RegConsoleCmd("sm_unwarden", ExitWarden);
	RegConsoleCmd("sm_c", BecomeWarden);
	RegConsoleCmd("sm_commander", BecomeWarden);
	RegConsoleCmd("sm_uc", ExitWarden);
	RegConsoleCmd("sm_uncommander", ExitWarden);
	// Admin commands
	RegAdminCmd("sm_sw", SetWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_setwarden", SetWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_rw", RemoveWarden, ADMFLAG_GENERIC);
	RegAdminCmd("sm_removewarden", RemoveWarden, ADMFLAG_GENERIC);
    //Hooks
	HookEvent("round_start", roundStart);
	HookEvent("player_death", playerDeath);
	HookEvent("player_team", playerTeam);
	//Forwards
	gF_OnWardenCreatedByUser = CreateGlobalForward("Warden_OnWardenCreatedByUser", ET_Ignore, Param_Cell);
	gF_OnWardenCreatedByAdmin = CreateGlobalForward("Warden_OnWardenCreatedByAdmin", ET_Ignore, Param_Cell);
	g_fward_onBecome = CreateGlobalForward("warden_OnWardenCreated", ET_Ignore, Param_Cell);
	gF_OnWardenDisconnected = CreateGlobalForward("Warden_OnWardenDisconnected", ET_Ignore, Param_Cell);
	gF_OnWardenDeath = CreateGlobalForward("Warden_OnWardenDeath", ET_Ignore, Param_Cell);
	gF_OnWardenRemovedBySelf = CreateGlobalForward("Warden_OnWardenRemovedBySelf", ET_Ignore, Param_Cell);
	gF_OnWardenRemovedByAdmin = CreateGlobalForward("Warden_OnWardenRemovedByAdmin", ET_Ignore, Param_Cell);
	g_fward_onRemove = CreateGlobalForward("warden_OnWardenRemoved", ET_Ignore, Param_Cell);
	
	
	AddCommandListener(HookPlayerChat, "say");
	
	
	//ConVars
	CreateConVar("sm_warden_version", PLUGIN_VERSION,  "The version of the SourceMod plugin MyJailBreak - Warden", FCVAR_REPLICATED|FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_cVar_mnotes = CreateConVar("sm_warden_better_notifications", "0", "0 - disabled, 1 - Will use hint and center text", _, true, 0.0, true, 1.0);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, interr_max)
{
	CreateNative("warden_exist", Native_ExistWarden);
	CreateNative("warden_iswarden", Native_IsWarden);
	CreateNative("warden_set", Native_SetWarden);
	CreateNative("warden_remove", Native_RemoveWarden);
	CreateNative("warden_get", Native_GetWarden);
	
	RegPluginLibrary("warden");
	return APLRes_Success;
}

public Action BecomeWarden(int client, int args) 
{
	if (Warden == -1)
	{
		if (GetClientTeam(client) == CS_TEAM_CT)
		{
			if (IsPlayerAlive(client))
			{
			SetTheWarden(client);
			Call_StartForward(gF_OnWardenCreatedByUser);
			Call_PushCell(client);
			Call_Finish();
			}
			else PrintToChat(client, "Warden ~ %t", "warden_playerdead");
		}
		else PrintToChat(client, "Warden ~ %t", "warden_ctsonly");
	}
	else PrintToChat(client, "Warden ~ %t", "warden_exist", Warden);
}

public Action ExitWarden(int client, int args) 
{
	if(client == Warden)
	{
		PrintToChatAll("Warden ~ %t", "warden_retire", client);
		
		if(GetConVarBool(g_cVar_mnotes))
		{
			PrintCenterTextAll("Warden ~ %t", "warden_retire", client);
			PrintHintTextToAll("Warden ~ %t", "warden_retire", client);
		}
		
		Warden = -1;
		Forward_OnWardenRemoved(client);
		SetEntityRenderColor(client, 255, 255, 255, 255);
	}
	else PrintToChat(client, "Warden ~ %t", "warden_notwarden");
}

public Action roundStart(Handle event, const char[] name, bool dontBroadcast) 
{
//	Warden = -1;
}

public Action playerDeath(Handle event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client == Warden)
	{
		PrintToChatAll("Warden ~ %t", "warden_dead", client);
		
		if(GetConVarBool(g_cVar_mnotes))
		{
			PrintCenterTextAll("Warden ~ %t", "warden_dead", client);
			PrintHintTextToAll("Warden ~ %t", "warden_dead", client);
		}
		
		RemoveTheWarden(client);
		Call_StartForward(gF_OnWardenDeath);
		Call_PushCell(client);
		Call_Finish();
    }
}
public Action SetWarden(int client,int args)
{
  if(IsValidClient(client))
  {
    Menu menu = CreateMenu(m_SetWarden);
    menu.SetTitle("Select players");
    LoopAliveClients(i)
    {
      if(GetClientTeam(i) == CS_TEAM_CT && IsClientWarden(i) == false)
      {
        char userid[11];
        char username[MAX_NAME_LENGTH];
        IntToString(GetClientUserId(i), userid, sizeof(userid));
        Format(username, sizeof(username), "%N", i);
        menu.AddItem(userid,username);
      }
    }
    menu.ExitButton = true;
    menu.Display(client,MENU_TIME_FOREVER);
  }
  return Plugin_Handled;
}

public int m_SetWarden(Menu menu, MenuAction action, int client, int Position)
{
  if(action == MenuAction_Select)
  {
    char Item[11];
    menu.GetItem(Position,Item,sizeof(Item));
    LoopAliveClients(i)
    {
      if(GetClientTeam(i) == CS_TEAM_CT && IsClientWarden(i) == false)
      {
        int userid = GetClientUserId(i);
        if(userid == StringToInt(Item))
        {
          if(IsWarden() == true)
          {
            tempwarden[client] = userid;
            Menu menu1 = CreateMenu(m_WardenOverwrite);
            char buffer[64];
            Format(buffer,sizeof(buffer), "Current Warden is %N, do you want to replace him?", Warden);
            menu1.SetTitle(buffer);
            menu1.AddItem("1", "Yes");
            menu1.AddItem("0", "No");
            menu1.ExitButton = false;
            menu1.Display(client,MENU_TIME_FOREVER);
          }
          else
          {
            Warden = i;
            PrintToChatAll("[Warden] Admin set %N as a Warden!", i);
            CreateTimer(0.5, Timer_WardenFixColor, i, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
            Call_StartForward(gF_OnWardenCreatedByAdmin);
            Call_PushCell(i);
            Call_Finish();
          }
        }
      }
    }
  }
}
public int m_WardenOverwrite(Menu menu, MenuAction action, int client, int Position)
{
  if(action == MenuAction_Select && IsClientWarden(client))
  {
    char Item[11];
    menu.GetItem(Position,Item,sizeof(Item));
    int choice = StringToInt(Item);
    if(choice == 1)
    {
      int newwarden = GetClientOfUserId(tempwarden[client]);
      PrintToChatAll("[Warden] Current Warden %N has been fired!", Warden);
      PrintToChatAll("[Warden] Admin set %N as a Warden!", newwarden);
      Warden = newwarden;
      CreateTimer(0.5, Timer_WardenFixColor, newwarden, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
      Call_StartForward(gF_OnWardenCreatedByAdmin);
      Call_PushCell(newwarden);
      Call_Finish();
    }
  }
}
public Action Timer_WardenFixColor(Handle timer,any client)
{
  if(IsValidClient(client, true))
  {
    if(IsClientWarden(client))
    {
      SetEntityRenderColor(client,0,102,204);
    }
    else
    {
      SetEntityRenderColor(client);
      return Plugin_Stop;
    }
  }
  else
  {
    return Plugin_Stop;
  }
  return Plugin_Continue;
}
public Action playerTeam(Handle event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if(client == Warden)
		RemoveTheWarden(client);
}

public void OnClientDisconnect(int client)
{
	if(client == Warden)
	{
		PrintToChatAll("Warden ~ %t", "warden_disconnected");
		
		if(GetConVarBool(g_cVar_mnotes))
		{
			PrintCenterTextAll("Warden ~ %t", "warden_disconnected", client);
			PrintHintTextToAll("Warden ~ %t", "warden_disconnected", client);
		}
		
		Warden = -1;
		Forward_OnWardenRemoved(client);
		Call_StartForward(gF_OnWardenDisconnected);
		Call_PushCell(client);
		Call_Finish();
    }
}

public Action RemoveWarden(int client, int args)
{
	if(Warden != -1)
	{
	RemoveTheWarden(client);
	Call_StartForward(gF_OnWardenRemovedByAdmin);
	Call_PushCell(client);
	Call_Finish();
	}
	else PrintToChatAll("Warden ~ %t", "warden_noexist");
	return Plugin_Handled;
	}

public Action HookPlayerChat(int client, const char[] command, int args)
{
	if(Warden == client && client)
	{
		char szText[256];
		GetCmdArg(1, szText, sizeof(szText));
		
		if(szText[0] == '/' || szText[0] == '@' || IsChatTrigger())
			return Plugin_Handled;
		
		if(IsClientInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == CS_TEAM_CT)
		{
			PrintToChatAll("[Warden] %N : %s", client, szText);
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

void SetTheWarden(int client)
{
	PrintToChatAll("Warden ~ %t", "warden_new", client);
	
	if(GetConVarBool(g_cVar_mnotes))
	{
		PrintCenterTextAll("Warden ~ %t", "warden_new", client);
		PrintHintTextToAll("Warden ~ %t", "warden_new", client);
	}
	
	Warden = client;
	CreateTimer(0.5, Timer_WardenFixColor, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	SetClientListeningFlags(client, VOICE_NORMAL);
	
	Forward_OnWardenCreation(client);
}

void RemoveTheWarden(int client)
{
	PrintToChatAll("Warden ~ %t", "warden_removed", client, Warden);
	
	if(GetConVarBool(g_cVar_mnotes))
	{
		PrintCenterTextAll("Warden ~ %t", "warden_removed", client);
		PrintHintTextToAll("Warden ~ %t", "warden_removed", client);
	}
	
	if(IsClientInGame(client) && IsPlayerAlive(client))
		SetEntityRenderColor(Warden, 255, 255, 255, 255);
		
	Warden = -1;
	Call_StartForward(gF_OnWardenRemovedBySelf);
	Call_PushCell(client);
	Call_Finish();
	Forward_OnWardenRemoved(client);
}

public int Native_ExistWarden(Handle plugin, int numParams)
{
	if(Warden != -1)
		return true;
	
	return false;
}

public int Native_IsWarden(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if(!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if(client == Warden)
		return true;
	
	return false;
}

public int Native_SetWarden(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if(Warden == -1)
		SetTheWarden(client);
}

public int Native_RemoveWarden(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	
	if (!IsClientInGame(client) && !IsClientConnected(client))
		ThrowNativeError(SP_ERROR_INDEX, "Client index %i is invalid", client);
	
	if(client == Warden)
		RemoveTheWarden(client);
}

public int Native_GetWarden(Handle:plugin, argc)
{    
    	return Warden;
}

void Forward_OnWardenCreation(int client)
{
	Call_StartForward(g_fward_onBecome);
	Call_PushCell(client);
	Call_Finish();
}

void Forward_OnWardenRemoved(int client)
{
	Call_StartForward(g_fward_onRemove);
	Call_PushCell(client);
	Call_Finish();
}


stock bool IsWarden()
{
  if(Warden != -1)
  {
    return true;
  }
  return false;
}
stock bool IsClientWarden(int client)
{
  if(client == Warden)
  {
    return true;
  }
  return false;
}
stock bool IsValidClient(int client, bool alive = false)
{
  if(client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && (alive == false || IsPlayerAlive(client)))
  {
    return true;
  }
  return false;
}