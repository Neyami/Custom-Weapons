#include "../../custom_weapons/weapon_redeemer"

array<bool> g_bIsNukeFlying(33);

void MapInit()
{
	RegisterRedeemer();
	RegisterNuke();
	RegisterNukeAmmoBox();
}