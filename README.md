Various weapons ported to Sven Co-op.

They might not be the latest versions that I've made, but they are working releases

There might be changes made to the game that cause the scripts to fail and there's nothing I can do about it at this time. But the fixes should be simple.

It'll look really messy but should be relatively easy to use anyway.

Hopefully I can make it better in the future, but health reasons and being busy IRL currently prevents me from doing so.

<BR>

# Redeemer
From Unreal Tournament and Half-Life Weapons Edition.

[Video](https://youtu.be/Z9VHXZgFfbc)

ENTITIES

`weapon_redeemer` - Weapon

`ammo_nuke` - Ammo box

`nuke` - Projectile

AMMO NAME

`nuke`

REGISTRATION FUNCTIONS
`RegisterRedeemer();`

Also

`array<bool> g_bIsNukeFlying(33);`

Needs to be put somewhere, such as in a map script.


<BR>
<BR>

# SCIPG

Don't remember where it's from.

ENTITIES

`weapon_scientist` - Weapon

`ammo_scientist` - Ammo box

`scibolt` - Projectile

AMMO NAME

`scientist`


REGISTRATION FUNCTIONS

`RegisterSciPG();`

`RegisterSciPGAmmoBox();`

`RegisterSciPGBolt();`


<BR>
<BR>

# Bio Rifle

From Half-Life Weapon Edition.

[Video](https://youtu.be/0IRgOqIsMRg)

ENTITIES

`weapon_biorifle` - Weapon

`ammo_biocharge` - Ammo box

`biomass` - Projectile

AMMO NAME

`biocharge`

REGISTRATION FUNCTIONS
`RegisterBiorifle();`

`RegisterBRAmmoBox();`

`RegisterBiomass();`

<BR>

# Remote Control Apache

This is a port of amx_apache by "KRoTaL, Fox-NL" from [Allied Mods](https://forums.alliedmods.net/showthread.php?t=50638)

[Video1](https://youtu.be/FJpwvlEX4dY) -- [Video2](https://youtu.be/GMQKREr5uEU)


* USAGE
    * Use some give command to give yourself the weapon "weapon_apache".
Such as .player_give @me weapon_apache from [AFBase](https://github.com/Zode/AFBase)

    * When selected, use Primary Attack to spawn a small Apache helicopter that you control with your mouse and movement keys.


* CONTROLS
    * Forward increases speed
    * Back decreases speed
    * Jump increases elevation (makes it go up)
    * Crouch decreases elevation (makes it go down)
    * Strafe Left/Right makes it strafe (when speed is over 0, it's a bit weird because I suck at math :D)
    * +use is the break (the +speed key (IN_RUN) doesn't work ¯\_(ツ)_/¯)
    * Primary Fire fires the gun
    * Secondary Fire fires ze missiles
    * Tertiary Fire toggles stealth (almost invisible, green screen, lower max-speed and damage)
    * Reload drops bombs
