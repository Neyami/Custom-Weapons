#include "proj_nuke"

const int REDEEMER_DEFAULT_GIVE			= 4;
const int REDEEMER_MAX_CARRY			= 12;
const int REDEEMER_MAX_CLIP				= 1;
const int REDEEMER_WEIGHT				= 110;
const int REDEEMER_DAMAGE				= 1500;
const int REDEEMER_SLOT					= 7;
const int REDEEMER_POSITION				= 14;

const string REDEEMER_SOUND_DRAW		= "custom_weapons/redeemer/redeemer_draw.wav";
const string REDEEMER_SOUND_FIRE		= "custom_weapons/redeemer/redeemer_fire.wav";
const string REDEEMER_SOUND_RELOAD		= "custom_weapons/redeemer/redeemer_reload.wav";
const string REDEEMER_SOUND_FLY			= "custom_weapons/redeemer/redeemer_wh_fly.wav";
const string REDEEMER_SOUND_EXPLODE		= "custom_weapons/redeemer/redeemer_wh_explode.wav";

const string REDEEMER_MODEL_VIEW		= "models/custom_weapons/redeemer/v_redeemer.mdl";
const string REDEEMER_MODEL_PLAYER		= "models/custom_weapons/redeemer/p_redeemer.mdl";
const string REDEEMER_MODEL_PROJECTILE	= "models/custom_weapons/hlwe/projectiles.mdl";
const string REDEEMER_MODEL_CLIP		= "models/custom_weapons/hlwe/projectiles.mdl";

enum redeemer_e
{
	REDEEMER_IDLE,
	REDEEMER_DRAW,
	REDEEMER_FIRE,
	REDEEMER_FIRE_SOLID,
	REDEEMER_HOLSTER,
	REDEEMER_RELOAD
};

class CRedeemer : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	float ATTN_LOW = 0.5;
	
	void Spawn()
	{
		g_EntityFuncs.SetModel( self, REDEEMER_MODEL_PLAYER );
		self.m_iDefaultAmmo = REDEEMER_DEFAULT_GIVE;
		self.pev.sequence = 1;
		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( REDEEMER_MODEL_VIEW );
		g_Game.PrecacheModel( REDEEMER_MODEL_PLAYER );
		g_Game.PrecacheModel( REDEEMER_MODEL_PROJECTILE );
		g_Game.PrecacheModel( "sprites/spray.spr" );
		g_Game.PrecacheModel( "sprites/fexplo.spr" );
		g_Game.PrecacheModel( "sprites/white.spr" );

		g_Game.PrecacheModel( REDEEMER_MODEL_CLIP );
		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );
		
		g_Game.PrecacheGeneric( "sound/" + REDEEMER_SOUND_DRAW );
		g_Game.PrecacheGeneric( "sound/" + REDEEMER_SOUND_FIRE );
		g_Game.PrecacheGeneric( "sound/" + REDEEMER_SOUND_RELOAD );
		g_Game.PrecacheGeneric( "sound/" + REDEEMER_SOUND_FLY );
		g_Game.PrecacheGeneric( "sound/" + REDEEMER_SOUND_EXPLODE );
		g_SoundSystem.PrecacheSound( REDEEMER_SOUND_DRAW );
		g_SoundSystem.PrecacheSound( REDEEMER_SOUND_FIRE );
		g_SoundSystem.PrecacheSound( REDEEMER_SOUND_RELOAD );
		g_SoundSystem.PrecacheSound( REDEEMER_SOUND_FLY );
		g_SoundSystem.PrecacheSound( REDEEMER_SOUND_EXPLODE );

		//Precache these for downloading
		g_Game.PrecacheGeneric( "sprites/custom_weapons/redeemer.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/redeemer_crosshairs.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/weapon_redeemer.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= REDEEMER_MAX_CARRY;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= REDEEMER_MAX_CLIP;
		info.iSlot 		= REDEEMER_SLOT-1;
		info.iPosition 	= REDEEMER_POSITION-1;
		info.iFlags 	= ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_NOAUTORELOAD;
		info.iWeight 	= REDEEMER_WEIGHT;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer(pPlayer) )
			return false;

		@m_pPlayer = pPlayer;
		int iIndex = pPlayer.entindex();
		g_bIsNukeFlying[ iIndex ] = false;
		NetworkMessage redeemer( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			redeemer.WriteLong( self.m_iId );
		redeemer.End();

		return true;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( self.GetV_Model( REDEEMER_MODEL_VIEW ), self.GetP_Model( REDEEMER_MODEL_PLAYER ), REDEEMER_DRAW, "gauss" );
	}

	bool CanHolster()
	{
		int iIndex = m_pPlayer.entindex();
		return ( !g_bIsNukeFlying[ iIndex ] );
	}

	void Holster( int skipLocal = 0 )
	{
		
		self.SendWeaponAnim( REDEEMER_HOLSTER );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time;
	}
	
	void PrimaryAttack()
	{
		int iIndex = m_pPlayer.entindex();
		
		if( g_bIsNukeFlying[ iIndex ] )
			return;

		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD || self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
			return;
		}

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( REDEEMER_FIRE );
		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, REDEEMER_SOUND_FIRE, 1.0, ATTN_LOW );
		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		ShootNuke( m_pPlayer.pev, m_pPlayer.GetGunPosition() + g_Engine.v_forward * 32 + g_Engine.v_up * 2 + g_Engine.v_right * -2, g_Engine.v_forward * 1500, false );

		--self.m_iClip;
		self.m_flNextPrimaryAttack = g_Engine.time + 1.5;
		self.m_flNextSecondaryAttack = g_Engine.time + 1.5;
		self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
		m_pPlayer.pev.punchangle.x -= 15;
	}

	void SecondaryAttack()
	{
		int iIndex = m_pPlayer.entindex();
		
		if( g_bIsNukeFlying[ iIndex ] )
			return;

		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD || self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextSecondaryAttack = g_Engine.time + 0.5;
			return;
		}

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( REDEEMER_FIRE );
		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, REDEEMER_SOUND_FIRE, 1.0, ATTN_LOW );
		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		ShootNuke( m_pPlayer.pev, m_pPlayer.GetGunPosition() + g_Engine.v_forward * 32 + g_Engine.v_up * 2 + g_Engine.v_right * -2, g_Engine.v_forward * 800, true );
		g_bIsNukeFlying[ iIndex ] = true;

		--self.m_iClip;
		self.m_flNextPrimaryAttack = g_Engine.time + 1.5;
		self.m_flNextSecondaryAttack = g_Engine.time + 1.5;
		self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
		m_pPlayer.pev.punchangle.x -= 15;
	}

	void WeaponIdle()
	{
		int iIndex = m_pPlayer.entindex();
		self.m_bExclusiveHold = g_bIsNukeFlying[iIndex] ? true : false;

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.SendWeaponAnim( REDEEMER_IDLE );
		self.m_flTimeWeaponIdle = g_Engine.time + 10.0;
	}

	void Reload()
	{
		int iIndex = m_pPlayer.entindex();
		
		if( self.m_iClip != 0 || g_bIsNukeFlying[ iIndex ] )
			return;
		
		self.DefaultReload( 1, REDEEMER_RELOAD, 3.6 );
	}
}

class NukeAmmoBox : ScriptBasePlayerAmmoEntity
{	
	void Spawn()
	{ 
		g_EntityFuncs.SetModel( self, REDEEMER_MODEL_CLIP );
		self.pev.body = 15;
		BaseClass.Spawn();
	}
	
	bool AddAmmo( CBaseEntity@ pOther )
	{ 
		int iGive;

		iGive = REDEEMER_DEFAULT_GIVE;

		if( pOther.GiveAmmo( iGive, "nuke", REDEEMER_MAX_CARRY ) != -1)
		{
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1, ATTN_NORM );
			return true;
		}
		return false;
	}
}

void RegisterRedeemer()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "CRedeemer", "weapon_redeemer" );
	g_ItemRegistry.RegisterWeapon( "weapon_redeemer", "custom_weapons", "nuke" );
	g_CustomEntityFuncs.RegisterCustomEntity( "NukeAmmoBox", "ammo_nuke" );
	g_CustomEntityFuncs.RegisterCustomEntity( "CNuke", "nuke" );
}