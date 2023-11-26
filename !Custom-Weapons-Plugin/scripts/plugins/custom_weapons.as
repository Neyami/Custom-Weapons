#include "../maps/hunger/weapons/baseweapon"

//Comment the #include and Register lines of the weapons you don't want.
//Put // in front of the lines to do so.
#include "../custom_weapons/weapon_biorifle"
#include "../custom_weapons/firearms/weapon_m16a2"
#include "../custom_weapons/weapon_apache"
#include "../custom_weapons/weapon_redeemer"
#include "../custom_weapons/weapon_scientist"

//Required for the Redeemer
array<bool> g_bIsNukeFlying(33);

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI" );
}

void MapInit()
{
	biorifle::Register();
	fa_m16a2::Register();
	apacheweapon::Register();
	redeemer::Register();
	scipg::Register();
}
