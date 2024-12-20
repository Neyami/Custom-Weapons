//Comment the #include and Register lines of the weapons you don't want.
//Put // in front of the lines to do so.
#include "../custom_weapons/weapon_biorifle"
#include "../custom_weapons/firearms/weapon_m16a2"
#include "../custom_weapons/weapon_apache"
#include "../custom_weapons/weapon_redeemer"
#include "../custom_weapons/weapon_scientist"

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nero" );
	g_Module.ScriptInfo.SetContactInfo( "https://discord.gg/0wtJ6aAd7XOGI6vI\n" );
}

void MapInit()
{
	hlwe_biorifle::Register();
	fa_m16a2::Register();
	apacheweapon::Register();
	hlwe_redeemer::Register();
	scipg::Register();
}