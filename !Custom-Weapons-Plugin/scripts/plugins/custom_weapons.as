#include "../maps/hunger/weapons/baseweapon"

#include "../custom_weapons/weapon_biorifle"

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI" );
}

void MapInit()
{
	biorifle::Register();
}
