#include <sourcemod>
#include <clientprefs>
#include <sdktools_sound>

#pragma newdecls required

static const int MAX_TRIGGERS = 5;
static const char SoundLink[] = "items/gift_drop.wav";

Handle g_hCookie;
int Time[MAXPLAYERS + 1];
bool Admin[MAXPLAYERS + 1], Sound[MAXPLAYERS + 1], Link[MAXPLAYERS + 1], Save[MAXPLAYERS + 1];

char PrevTriggers[MAXPLAYERS + 1][256];

public Plugin myinfo = 
{
	name		= "Link Messages",
	version		= "1.0"
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	SetCookieMenuItem(CookieMenuH, 0, "Link Messages");
	g_hCookie = RegClientCookie("LinkMessage", "Link message settings", CookieAccess_Private);
}

public void OnMapStart()
{
	PrecacheSound(SoundLink, true);
}

public void CookieMenuH(int iClient, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
		{
			LinkMessagesMenu(iClient, true);
		}
	}
}

void LinkMessagesMenu(int iClient, bool bExitBackButton)
{
	char szBuffer[256], szBuffer2[8];
	IntToString(view_as<int>(bExitBackButton), szBuffer2, 8);
	Menu hMenu = new Menu(LinkMessagesMenuH);
	hMenu.SetTitle("Link Messages\n ");
	FormatEx(szBuffer, 256, "Allow link [%s]", Link[iClient] ? "✔":"×"); hMenu.AddItem(szBuffer2, szBuffer);
	FormatEx(szBuffer, 256, "Sound link [%s]", Sound[iClient] ? "✔":"×"); hMenu.AddItem(szBuffer2, szBuffer);
	hMenu.ExitBackButton = bExitBackButton;
	hMenu.Display(iClient, 0);
}

public int LinkMessagesMenuH(Menu hMenu, MenuAction action, int iClient, int iItem)
{
	switch(action)
	{
		case MenuAction_End:
		{
			delete hMenu;
		}
		case MenuAction_Cancel:
		{
			if(iItem == MenuCancel_ExitBack)
			{
				ShowCookieMenu(iClient);
			}
		}
		case MenuAction_Select:
		{
			char szBuffer[8];
			hMenu.GetItem(iItem, szBuffer, 8);
			Save[iClient] = true;
			if(iItem == 0)
			{
				Link[iClient] = !Link[iClient];
			}
			else if(iItem == 1)
			{
				Sound[iClient] = !Sound[iClient];
			}
			LinkMessagesMenu(iClient, view_as<bool>(StringToInt(szBuffer)));
		}
	}
}

public void OnPluginEnd()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientDisconnect(i);
		}
	}
}

public void OnClientCookiesCached(int iClient)
{
	char szBuffer[16];
	GetClientCookie(iClient, g_hCookie, szBuffer, 8);
	if(szBuffer[0])
	{
		Sound[iClient] = view_as<bool>(StringToInt(szBuffer[1]));
		szBuffer[1] = 0;
		Link[iClient] = view_as<bool>(StringToInt(szBuffer));
	}
	else
	{
		Sound[iClient] = true;
		Link[iClient] = true;
	}

}

public void OnClientPostAdminCheck(int iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	int iFlags = GetUserFlagBits(iClient);
	Admin[iClient] = (iFlags & ADMFLAG_GENERIC || iFlags & ADMFLAG_ROOT);
}

public void OnClientDisconnect(int iClient)
{
	if(IsFakeClient(iClient))
		return;
	
	if(Save[iClient])
	{
		Save[iClient] = false;
		
		char szBuffer[16];
		FormatEx(szBuffer, 16, "%i%i", view_as<int>(Link[iClient]), view_as<int>(Sound[iClient]));
		SetClientCookie(iClient, g_hCookie, szBuffer);
	}
	Admin[iClient]= false;
	Sound[iClient] = true;
	Link[iClient] = true;
	Time[iClient] = 0;
	PrevTriggers[iClient][0] = 0;
}



public Action OnClientSayCommand(int iClient, const char[] command, const char[] arg)
{
	if(strcmp(command, "say", false) || arg[0] != '@')
	{
		PrevTriggers[iClient][0] = 0;
		return Plugin_Continue;
	}
	
	if(arg[1] != ' ')
	{
		PrevTriggers[iClient][0] = 0;
	}
		
	int symbol, len = strlen(arg);
	
	if(!PrevTriggers[iClient][0])
	{
		if(len < 4 || (symbol = FindCharInString(arg[2], ' ')) == -1)
		{
			return Plugin_Handled;
		}
	}
	else if(len < 3)
	{
		return Plugin_Handled;
	}
	
	int iTime = GetTime();
	if(Time[iClient] > iTime)
	{
		PrintHintText(iClient, "Link Messages: wait %i seconds", Time[iClient] - iTime);
		return Plugin_Handled;
	}
	else if(!Admin[iClient])
	{
		Time[iClient] = iTime + 5;
	}
	int Triggers;
	char szMessage[256], szTrigger[256];
	bool Message[MAXPLAYERS + 1], Private[MAXPLAYERS + 1];
	strcopy(szMessage, 256, arg);
	if(PrevTriggers[iClient][0])
	{
		len += strlen(PrevTriggers[iClient]);
		Format(szMessage, 256, "%s%s", PrevTriggers[iClient], szMessage[1]);
		if((symbol = FindCharInString(szMessage[2], ' ')) == -1)
		{
			return Plugin_Handled;
		}
	}
	do
	{
		symbol += 2;
		char szBuffer[32];
		strcopy(szBuffer, 32, szMessage);
		szBuffer[symbol] = 0;
		StringToLowercase(szBuffer);
		
		strcopy(szMessage, 256, szMessage[symbol + 1]);
		len -= (symbol + 1);
			
		int[] Target = new int[MaxClients]; int Targets;
		char name[32]; bool tnisml;
		if((Targets = ProcessTargetString(szBuffer, iClient, Target, MaxClients, COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_IMMUNITY | COMMAND_FILTER_NO_BOTS, name, 32, tnisml)) > 0)
		{
			for(int i; i < Targets; i++)
			{
				Message[Target[i]] = true;
			}
			StringToUppercase(szBuffer);
			AddTriggerInChar(Triggers, szTrigger, 256, szBuffer);
		}
		else if(!Targets)
		{
			int iTarget = FindTarget(iClient, szBuffer[1], true, false);
		
			if(iTarget != -1)
			{
				Message[iTarget] = true;
				Private[iTarget] = true;
				GetClientName(iTarget, szBuffer[1], 31);
				AddTriggerInChar(Triggers, szTrigger, 256, szBuffer);
		
			}
		}
	}
	while(Triggers < MAX_TRIGGERS && len > 3 && szMessage[0] == '@' && (symbol = FindCharInString(szMessage[2], ' ')) != -1);
	
	if(Triggers)
	{
		Format(szMessage, 256, "\x04(%s) %N: \x01%s", szTrigger, iClient, szMessage);
		Message[iClient] = true;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && (Message[i]) && Link[i])
			{
				if(Admin[i] && Private[i] && Sound[i])
				{
					EmitSoundToClient(i, SoundLink, SOUND_FROM_PLAYER);
				}
				PrintToChat(i, szMessage);
			}
		}
		strcopy(PrevTriggers[iClient], 256, szTrigger);
		StringToLowercase(PrevTriggers[iClient]);
		
		LogMessage(szMessage);
	}
	return Plugin_Handled;
}

void AddTriggerInChar(int& count, char[] szTrigger, int size, const char[] trigger)
{
	if(!count++)
	{
		FormatEx(szTrigger, size, trigger);
	}
	else
	{
		Format(szTrigger, size, "%s %s", szTrigger, trigger);
		
	}
}

stock void StringToUppercase(char[] sText)
{
	int iLen = strlen(sText);
	for(int i; i < iLen; i++)
	{
		if(IsCharLower(sText[i]))
		{
			sText[i] = CharToUpper(sText[i]);
		}
	}
}

stock void StringToLowercase(char[] sText)
{
	int iLen = strlen(sText);
	for(int i; i < iLen; i++)
	{
		if(IsCharUpper(sText[i]))
		{
			sText[i] = CharToLower(sText[i]);
		}
	}
}