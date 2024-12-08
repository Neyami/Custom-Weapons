#include "proj_scibolt"

namespace scipg
{

const int SCIPG_DEFAULT_GIVE		= 15;
const int SCIPG_MAX_CARRY			= 99;
const int SCIPG_WEIGHT				= 25;
const int SCIPG_DAMAGE				= 999;
const int SCIPG_SLOT					= 2;
const int SCIPG_POSITION				= 10;

const string SCIPG_SOUND_FIRE1		= "weapons/rocketfire1.wav";
const string SCIPG_SOUND_FIRE2		= "weapons/glauncher.wav";
const string SCIPG_SOUND_FLY		= "custom_weapons/scipg/sci_scream.wav";
const string SCIPG_SOUND_EXPLODE	= "custom_weapons/scipg/kill.wav";

const string SCIPG_MODEL_VIEW		= "models/v_rpg.mdl";
const string SCIPG_MODEL_PLAYER		= "models/p_rpg.mdl";
const string SCIPG_MODEL_WORLD		= "models/w_rpg.mdl";
const string SCIPG_MODEL_CLIP		= "models/scientist.mdl";
const string SCIPG_MODEL_BOLT		= "models/custom_weapons/scipg/sci_rocket.mdl";

const int BOLT_AIR_VELOCITY		= 800;
const int BOLT_WATER_VELOCITY	= 450;

enum sci_e
{
	SCIPG_IDLE = 0,
	SCIPG_FIDGET,
	SCIPG_RELOAD,
	SCIPG_FIRE,		// to empty
	SCIPG_HOLSTER1,	// loaded
	SCIPG_DRAW,		// loaded
	SCIPG_HOLSTER2,	// unloaded
	SCIPG_DRAW_UL,
	SCIPG_IDLE_UL,
	SCIPG_FIDGET_UL,
};

class CSciPG : ScriptBasePlayerWeaponEntity
{
	protected CBasePlayer@ m_pPlayer
	{
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel( self, SCIPG_MODEL_WORLD );
		self.m_iDefaultAmmo = SCIPG_DEFAULT_GIVE;
		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( SCIPG_MODEL_VIEW );
		g_Game.PrecacheModel( SCIPG_MODEL_PLAYER );
		g_Game.PrecacheModel( SCIPG_MODEL_WORLD );
		g_Game.PrecacheModel( SCIPG_MODEL_BOLT );
		g_Game.PrecacheModel( SCIPG_MODEL_CLIP );
		
		g_Game.PrecacheModel( "sprites/custom_weapons/spinning_coin.spr");
		g_Game.PrecacheModel( "sprites/zerogxplode.spr" );
		g_Game.PrecacheModel( "sprites/WXplo1.spr" );
		
		g_SoundSystem.PrecacheSound( SCIPG_SOUND_FIRE1 );
		g_SoundSystem.PrecacheSound( SCIPG_SOUND_FIRE2 );
		
		g_Game.PrecacheGeneric( "sound/" + SCIPG_SOUND_FLY );
		g_Game.PrecacheGeneric( "sound/" + SCIPG_SOUND_EXPLODE );
		g_SoundSystem.PrecacheSound( SCIPG_SOUND_FLY );
		g_SoundSystem.PrecacheSound( SCIPG_SOUND_EXPLODE );

		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );
		g_SoundSystem.PrecacheSound( "weapons/357_cock1.wav" );

		//Precache these for downloading
		g_Game.PrecacheGeneric( "sprites/custom_weapons/scientist.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/weapon_scientist.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= SCIPG_MAX_CARRY;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= WEAPON_NOCLIP;
		info.iSlot 		= SCIPG_SLOT-1;
		info.iPosition 	= SCIPG_POSITION-1;
		info.iFlags 	= 0;
		info.iWeight 	= SCIPG_WEIGHT;
		
		return true;
	}	

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer(pPlayer) )
			return false;

		@m_pPlayer = pPlayer;

		NetworkMessage m1( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			m1.WriteLong( g_ItemRegistry.GetIdForName("weapon_scientist") );
		m1.End();
			
		return true;
	}
	
	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			
			g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, "weapons/357_cock1.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );
		}
		
		return false;
	}
	
	bool Deploy()
	{	
		return self.DefaultDeploy( self.GetV_Model( SCIPG_MODEL_VIEW ), self.GetP_Model( SCIPG_MODEL_PLAYER ), SCIPG_DRAW, "gauss" );
	}

	void Holster( int skipLocal = 0 )
	{
		self.m_fInReload = false;

		self.SendWeaponAnim( SCIPG_HOLSTER1 );
	}

	void PrimaryAttack()
	{
		FireBolt();
	}

	void FireBolt()
	{
		TraceResult tr;

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0)
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
			return;
		}

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) - 1 );

		self.SendWeaponAnim( SCIPG_FIRE );
		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, SCIPG_SOUND_FIRE1, 0.9, ATTN_NORM );
		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_ITEM, SCIPG_SOUND_FIRE2, 0.7, ATTN_NORM );

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		Vector vecAnglesAim = m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle;
		Math.MakeVectors( vecAnglesAim );
		
		vecAnglesAim.x = -vecAnglesAim.x;
		Vector vecOrigin = m_pPlayer.GetGunPosition() - g_Engine.v_up * 2;
		Vector vecDir = g_Engine.v_forward;

		BoltCreate( vecOrigin, vecAnglesAim, vecDir );

		if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = g_Engine.time + 0.75;

		self.m_flNextSecondaryAttack = g_Engine.time + 0.75;

		self.m_flTimeWeaponIdle = g_Engine.time + 5.0;
	}

	void WeaponIdle()
	{
		m_pPlayer.GetAutoaimVector( AUTOAIM_2DEGREES );  // get the autoaim vector but ignore it;  used for autoaim crosshair in DM

		self.ResetEmptySound();
		
		if( self.m_flTimeWeaponIdle < g_Engine.time )
		{
			float flRand = g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 0, 1 );
			if (flRand <= 0.75)
			{
				self.SendWeaponAnim( SCIPG_IDLE );
				self.m_flTimeWeaponIdle = g_Engine.time + g_PlayerFuncs.SharedRandomFloat( m_pPlayer.random_seed, 10, 15 );
			}
			else
			{
				self.SendWeaponAnim( SCIPG_FIDGET );
				self.m_flTimeWeaponIdle = g_Engine.time + 90.0 / 30.0;
			}
		}
	}

	void BoltCreate( Vector vecOrigin, Vector vecAnglesAim, Vector vecDir )
	{
		CBaseEntity@ pBolt = g_EntityFuncs.Create( "scibolt", vecOrigin, vecOrigin, false, m_pPlayer.edict() );
		pBolt.pev.angles = vecAnglesAim;

		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD )
		{
			pBolt.pev.velocity = vecDir * BOLT_WATER_VELOCITY;
			pBolt.pev.speed = BOLT_WATER_VELOCITY;
		}
		else
		{
			pBolt.pev.velocity = vecDir * BOLT_AIR_VELOCITY;
			pBolt.pev.speed = BOLT_AIR_VELOCITY;
		}

		pBolt.pev.avelocity.z = 10;
	}
}

class CSciPGAmmo : ScriptBasePlayerAmmoEntity
{	
	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel( self, SCIPG_MODEL_CLIP );
		self.pev.sequence = 13;//20
		self.pev.scale = 0.3;
		BaseClass.Spawn();
	}
	
	void Precache()
	{
		g_Game.PrecacheModel( SCIPG_MODEL_CLIP );
		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );
	}
	
	bool AddAmmo( CBaseEntity@ pOther )
	{ 
		if( pOther.GiveAmmo( 30, "scientist", SCIPG_MAX_CARRY ) != -1)
		{
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1, ATTN_NORM );
			return true;
		}
		return false;
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "CSciPGBolt", "scibolt" );
	g_CustomEntityFuncs.RegisterCustomEntity( "scipg::CSciPGAmmo", "ammo_scientist" );
	g_CustomEntityFuncs.RegisterCustomEntity( "scipg::CSciPG", "weapon_scientist" );
	g_ItemRegistry.RegisterWeapon( "weapon_scientist", "custom_weapons", "scientist" );
}

} //namespace scipg END