#include "proj_biomass"

namespace biorifle
{

const int BIORIFLE_DAMAGE		= 60;
const int BIORIFLE_WEIGHT		= 36;
const int BR_MAX_CLIP			= 18;
const int BR_DEFAULT_GIVE		= BR_MAX_CLIP;
const int BR_MAX_CARRY			= 72;
const int BIOMASS_TIMER			= 1000;

const string BR_MODEL_CLIP		= "models/w_weaponbox.mdl";
const string BR_MODEL_VIEW		= "models/custom_weapons/biorifle/v_biorifle.mdl";
const string BR_MODEL_PLAYER	= "models/custom_weapons/biorifle/p_biorifle.mdl";
const string BR_SOUND_FIRE		= "custom_weapons/biorifle/biorifle_fire.wav";
const string BR_SOUND_DRY		= "custom_weapons/biorifle/biorifle_dryfire.wav";

enum biorifle_e
{
	BIORIFLE_IDLE = 0,
	BIORIFLE_IDLE2,
	BIORIFLE_IDLE3,
	BIORIFLE_FIRE,
	BIORIFLE_FIRE_SOLID,
	BIORIFLE_RELOAD,
	BIORIFLE_DRAW,
	BIORIFLE_HOLSTER
};

class CWeaponBiorifle : ScriptBasePlayerWeaponEntity
{
	void Spawn()
	{
		self.Precache();
		g_EntityFuncs.SetModel( self, self.GetW_Model(BR_MODEL_PLAYER) );
		self.m_iDefaultAmmo = BR_DEFAULT_GIVE;
		self.pev.sequence = 1;
		self.FallInit();
	}

	void Precache()
	{
		g_Game.PrecacheModel( BR_MODEL_VIEW );
		g_Game.PrecacheModel( BR_MODEL_PLAYER );
		
		g_Game.PrecacheGeneric( "sound/" + BR_SOUND_FIRE );
		g_Game.PrecacheGeneric( "sound/" + BR_SOUND_DRY );
		
		g_SoundSystem.PrecacheSound( BR_SOUND_FIRE );
		g_SoundSystem.PrecacheSound( BR_SOUND_DRY );

		g_Game.PrecacheModel( "sprites/explode1.spr" );
		g_Game.PrecacheModel( "sprites/spore_exp_01.spr" );
		g_Game.PrecacheModel( "sprites/spore_exp_c_01.spr" );
		g_Game.PrecacheModel( "sprites/WXplo1.spr" );
		
		g_Game.PrecacheModel( "models/custom_weapons/biorifle/w_biomass.mdl" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/biorifle/bustflesh1.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/biorifle/bustflesh2.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/biorifle/biomass_exp.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/biorifle/bustflesh1.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/biorifle/bustflesh2.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/biorifle/biomass_exp.wav" );

		//Precache these for downloading
		g_Game.PrecacheGeneric( "sprites/custom_weapons/biorifle.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/biorifle_crosshairs.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/weapon_biorifle.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= BR_MAX_CARRY;
		info.iMaxClip 	= BR_MAX_CLIP;
		info.iSlot 		= 5;
		info.iPosition 	= 5;
		info.iFlags 	= ITEM_FLAG_SELECTONEMPTY;
		info.iWeight 	= BIORIFLE_WEIGHT;

		return true;
	}
	
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( BaseClass.AddToPlayer( pPlayer ) )
		{
			NetworkMessage message( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
				message.WriteLong( self.m_iId );
			message.End();
			return true;
		}
		
		return false;
	}

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			
			g_SoundSystem.EmitSound( self.m_pPlayer.edict(), CHAN_WEAPON, BR_SOUND_DRY, 0.8, ATTN_NORM );
		}
		
		return false;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( BR_MODEL_VIEW ), self.GetP_Model( BR_MODEL_PLAYER ), BIORIFLE_DRAW, "gauss" );
	}
	
	void Holster( int skiplocal = 0 )
	{
		self.m_fInReload = false;
		self.m_pPlayer.m_flNextAttack = g_Engine.time + 0.9;
		self.SendWeaponAnim( BIORIFLE_HOLSTER );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time;
	}
	
	void PrimaryAttack()
	{
		if( self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15;
			return;
		}

		--self.m_iClip;
		//++m_iFiredAmmo; //Used for dropping clip on the ground when out of ammo. Might be implemented in the future.
		self.m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( BIORIFLE_FIRE );

		Math.MakeVectors( self.m_pPlayer.pev.v_angle + self.m_pPlayer.pev.punchangle );
		ShootBiomass( self.m_pPlayer.pev, self.m_pPlayer.pev.origin + self.m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16 + g_Engine.v_right * 7 + g_Engine.v_up * -8, g_Engine.v_forward * 3000, BIOMASS_TIMER );
		g_SoundSystem.EmitSoundDyn( self.m_pPlayer.edict(), CHAN_WEAPON, BR_SOUND_FIRE, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xF ) );


		if( self.m_iClip == 0 && self.m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			self.m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = g_Engine.time + 0.3;
		self.m_flNextSecondaryAttack = g_Engine.time + 0.1;
		self.m_flTimeWeaponIdle = g_Engine.time + 2;
		
		self.m_pPlayer.pev.punchangle.x -= Math.RandomFloat( -2,5 );
		self.m_pPlayer.pev.punchangle.y -= 1;
	}

	void SecondaryAttack()
	{
		edict_t@ pPlayer = self.m_pPlayer.edict();
		CBaseEntity@ pBioCharge = null;

		while( ( @pBioCharge = g_EntityFuncs.FindEntityInSphere( pBioCharge, self.m_pPlayer.pev.origin, 16384, "biomass", "classname" ) ) !is null )
		{
			if( pBioCharge.pev.owner is pPlayer )
			{
				pBioCharge.Use( self.m_pPlayer, self.m_pPlayer, USE_ON, 0 );
			}
		}
		self.m_flNextPrimaryAttack = g_Engine.time + 0.1;
		self.m_flNextSecondaryAttack = g_Engine.time + 0.1;
	}

	void Reload()
	{
		self.DefaultReload( BR_MAX_CLIP, BIORIFLE_RELOAD, 2.7, 0 );
		BaseClass.Reload();
	}

	void WeaponIdle()
	{
		self.ResetEmptySound();

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		int iAnim;
		switch( Math.RandomLong( 0, 2 ) )
		{
			case 0:	iAnim = BIORIFLE_IDLE2;	break;
			case 1:	iAnim = BIORIFLE_IDLE3;	break;
			case 2: iAnim = BIORIFLE_IDLE; break;
		}

		self.SendWeaponAnim( iAnim );
		self.m_flTimeWeaponIdle = g_Engine.time + Math.RandomFloat( 10, 15 );
	}
/* Used for if the player dies while having active blobs, not sure how to/if it is possible to implement this properly
	void DeactivateBiomass( CBasePlayer@ pOwner )
	{
		//edict_t@ pFind = g_EntityFuncs.FindEntityByClassname( null, "biomass" );
		CBaseEntity@ pFind = g_EntityFuncs.FindEntityByClassname( null, "biomass" );

		while( !FNullEnt( pFind ) )
		{
			//CBaseEntity@ pEnt = CBaseEntity::Instance( pFind );
			CBaseEntity@ pEnt = pFind;
			//CBiomass@ pBioCharge = (CBiomass *)pEnt;
			CBiomass@ pBiocharge = cast<CBiomass@>(pEnt);

			if( pBioCharge !is null )
			{
				if( pBioCharge.pev.owner is pOwner.edict() )
					pBioCharge.Deactivate();
			}
			pFind = g_EntityFuncs.FindEntityByClassname( pFind, "biomass" );
		}
	}
*/
}

class BRAmmoBox : ScriptBasePlayerAmmoEntity
{	
	void Spawn()
	{ 
		Precache();
		g_EntityFuncs.SetModel( self, BR_MODEL_CLIP );
		BaseClass.Spawn();
	}
	
	void Precache()
	{
		g_Game.PrecacheModel( BR_MODEL_CLIP );
		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );
	}
	
	bool AddAmmo( CBaseEntity@ pOther )
	{ 
		int iGive;

		iGive = BR_DEFAULT_GIVE;

		if( pOther.GiveAmmo( iGive, "biocharge", BR_MAX_CARRY ) != -1)
		{
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1, ATTN_NORM );
			return true;
		}
		return false;
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "biorifle::CWeaponBiorifle", "weapon_biorifle" );
	g_CustomEntityFuncs.RegisterCustomEntity( "biorifle::BRAmmoBox", "ammo_biocharge" );
	g_ItemRegistry.RegisterWeapon( "weapon_biorifle", "custom_weapons", "biocharge" );
}

} //namespace biorifle END
