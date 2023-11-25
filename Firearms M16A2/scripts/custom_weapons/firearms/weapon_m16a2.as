namespace fa_m16a2
{

const int M16A2_DAMAGE			= 34;
const int M16A2_DAMAGE_M203		= 120;
const int M16A2_DEFAULT_GIVE 	= 30;
const int M16A2_MAX_AMMO		= 600;
const int M16A2_MAX_AMMO2		= 10;
const int M16A2_MAX_CLIP		= 30;
const int M16A2_WEIGHT			= 5;

const string M16A2_MODEL_VIEW		= "models/custom_weapons/firearms/v_m16a2.mdl";
const string M16A2_MODEL_PLAYER		= "models/custom_weapons/firearms/p_m16a2.mdl";
const string M16A2_MODEL_WORLD		= "models/custom_weapons/firearms/w_m16a2.mdl";
const string M16A2_MODEL_GRENADE	= "models/custom_weapons/firearms/grenade.mdl";
const string M16A2_MODEL_SHELL		= "models/custom_weapons/firearms/m16shell.mdl";
const string M16A2_MODEL_CLIP		= "models/custom_weapons/firearms/m16clip.mdl";
const string M16A2_MODEL_GRENCLIP	= "models/custom_weapons/firearms/m203shell.mdl";
const string M16A2_MODEL_GRENGIBS	= "models/custom_weapons/hlwe/w_gibs_01.mdl";

const string M16A2_SPRITE_TRAIL = "sprites/custom_weapons/firearms/fasmoke2.spr";
const string M16A2_SPRITE_EXPLOSION = "sprites/custom_weapons/firearms/faexplode1.spr";

enum M16A2Animation
{
	M16A2_IDLE1 = 0,
	M16A2_IDLE2,
	M16A2_FIRE1,
	M16A2_FIRE2,
	M16A2_FIRE3RND,
	M16A2_FIRE2RND,
	M16A2_RELOAD,
	M16A2_RELOAD_1,
	M16A2_RELOAD_EMPTY,
	M16A2_RELOAD_NMC,
	M16A2_RELOAD_NMC_1,
	M16A2_RELOAD_NMC_EMPTY,
	M16A2_DEPLOY_FIRST,
	M16A2_DEPLOY,
	M16A2_HOLSTER,
	M16A2_M203_PREP,
	M16A2_M203_FIRE,
	M16A2_M203_RELOAD,
	M16A2_M203_IDLE,
	M16A2_M203_DEPREP,
	M16A2_M203_HOLSTER
};

enum M16A2FireMode
{
	M16A2_MODE_BURST = 0,
	M16A2_MODE_SEMIAUTO,
	M16A2_MODE_M16,
	M16A2_MODE_M203
};
	
class CWeaponM16A2 : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	int m_iShell, m_iM16Clip, m_iM203Shell;
	int m_iDroppedM16Clip;
	int m_iFiremode = M16A2_MODE_BURST, m_iWeaponmode = M16A2_MODE_M16;
	int m_iBurstLeft = 0, m_iBurstCount = 0;
	float m_flNextBurstFireTime = 0.0f;
	bool m_bGrenadeLoaded = false;
	bool m_bFirstDeploy = true;
	
	void Spawn()
	{
		g_EntityFuncs.SetModel( self, M16A2_MODEL_WORLD );
		m_iShell = g_Game.PrecacheModel( M16A2_MODEL_SHELL );
		m_iM16Clip = g_Game.PrecacheModel( M16A2_MODEL_CLIP );
		m_iM203Shell = g_Game.PrecacheModel( M16A2_MODEL_GRENCLIP );

		self.m_iDefaultAmmo = M16A2_DEFAULT_GIVE;

		self.m_iSecondaryAmmoType = 0;
		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( M16A2_MODEL_VIEW );
		g_Game.PrecacheModel( M16A2_MODEL_PLAYER );
		g_Game.PrecacheModel( M16A2_MODEL_WORLD );
		g_Game.PrecacheModel( M16A2_MODEL_GRENADE );
		g_Game.PrecacheModel( M16A2_SPRITE_TRAIL );
		g_Game.PrecacheModel( M16A2_SPRITE_EXPLOSION );
		
		g_Game.PrecacheModel( M16A2_MODEL_SHELL );
		g_Game.PrecacheModel( M16A2_MODEL_CLIP );
		g_Game.PrecacheModel( M16A2_MODEL_GRENCLIP );
		g_Game.PrecacheModel( M16A2_MODEL_GRENGIBS );

		g_SoundSystem.PrecacheSound( "items/9mmclip1.wav" );

		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/de_magout.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/explode3.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/explode4.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/explode5.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/fireswitch.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/g3a3_magin.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_boltcatch.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_burst.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_burst2.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_clipin.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_clipout.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_fire1.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_getmag.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_magin.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m16_magout.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m203_back.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m203_fire1.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m203_forward.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/m79_insert.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/outofammo.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/sterling_cock.wav" );
		g_SoundSystem.PrecacheSound( "custom_weapons/firearms/sterling_magin.wav" );

		g_SoundSystem.PrecacheSound( "buttons/lightswitch2.wav" );

		//Precache these for downloading
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/de_magout.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/explode3.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/explode4.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/explode5.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/fireswitch.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/g3a3_magin.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_boltcatch.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_burst.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_burst2.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_clipin.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_clipout.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_fire1.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_getmag.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_magin.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m16_magout.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m203_back.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m203_fire1.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m203_forward.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/m79_insert.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/outofammo.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/sterling_cock.wav" );
		g_Game.PrecacheGeneric( "sound/custom_weapons/firearms/sterling_magin.wav" );

		g_Game.PrecacheGeneric( "sprites/custom_weapons/firearms/weapon_m16a2.txt" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/firearms/640hud01_2.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/firearms/640hud04.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/firearms/640hud04_2.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/firearms/crosshairs.spr" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= M16A2_MAX_AMMO;
		info.iMaxAmmo2 	= M16A2_MAX_AMMO2;
		info.iMaxClip 	= M16A2_MAX_CLIP;
		info.iSlot 		= 4;
		info.iPosition 	= 14;
		info.iFlags 	= ITEM_FLAG_NOAUTORELOAD;
		info.iWeight 	= M16A2_WEIGHT;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer(pPlayer) )
			return false;

		@m_pPlayer = pPlayer;

		NetworkMessage m16a2( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			m16a2.WriteLong( g_ItemRegistry.GetIdForName("weapon_m16a2") );
		m16a2.End();

		return true;
	}
	
	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			
			g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "custom_weapons/firearms/outofammo.wav", 1, ATTN_NORM );
		}
		
		return false;
	}

	bool Deploy()
	{	
		bool bResult;
		{
			if( m_bFirstDeploy )
			{
				bResult = self.DefaultDeploy( self.GetV_Model( M16A2_MODEL_VIEW ), self.GetP_Model( M16A2_MODEL_PLAYER ), M16A2_DEPLOY_FIRST, "m16" );
				m_bFirstDeploy = false;
			}
			else
				bResult = self.DefaultDeploy( self.GetV_Model( M16A2_MODEL_VIEW ), self.GetP_Model( M16A2_MODEL_PLAYER ), M16A2_DEPLOY, "m16" );
			
			float deployTime = 1.0f;
			
			self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = self.m_flNextTertiaryAttack = g_Engine.time + deployTime;

			return bResult;
		}
	}

	void Holster( int skipLocal = 0 ) 
    {     
        self.m_fInReload = false; 
		m_iBurstLeft = 0;
		SetThink( null );
		BaseClass.Holster( skipLocal ); 
    }
	
	float WeaponTimeBase()
	{
		return g_Engine.time;
	}

	void PrimaryAttack()
	{
		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD || self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15f;
			return;
		}

		if( m_iWeaponmode == M16A2_MODE_M16 )
		{
			if( m_iFiremode == M16A2_MODE_BURST )
			{
				m_iBurstCount = Math.min( 3, self.m_iClip );
				m_iBurstLeft = m_iBurstCount - 1;
	 
				m_flNextBurstFireTime = WeaponTimeBase() + 0.065f;//0.25
				self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.65f;//0.25
			   
				if( m_iBurstCount == 3 )
				{
					g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "custom_weapons/firearms/m16_burst.wav", 1, ATTN_NORM );
				}
				else if( m_iBurstCount == 2 )
				{
					g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "custom_weapons/firearms/m16_burst2.wav", 1, ATTN_NORM );
				}
				else
				{
					g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "custom_weapons/firearms/m16_fire1.wav", 1, ATTN_NORM );
				}
			}
			else if( m_iFiremode == M16A2_MODE_SEMIAUTO )
			{
				if( ( m_pPlayer.m_afButtonPressed & IN_ATTACK == 0 ))
					return;

				g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "custom_weapons/firearms/m16_fire1.wav", 1, ATTN_NORM );
			}
			Shoot( 0.2 );
		}
		else if( m_iWeaponmode == M16A2_MODE_M203 )
		{
			if( m_bGrenadeLoaded )
				LaunchGrenade();
			else
				g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "custom_weapons/firearms/outofammo.wav", 1, ATTN_NORM );

			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.4f;//0.25
		}
	}

	void Shoot( float flCycleTime )
	{
		flCycleTime -= 0.075;

		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD || self.m_iClip <= 0 )
		{
			self.PlayEmptySound( );
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15f;
			return;
		}

		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

		--self.m_iClip;

		self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
		
		m_pPlayer.pev.effects |= EF_MUZZLEFLASH;
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		if( m_iFiremode == M16A2_MODE_BURST )
		{
			if( m_iBurstCount == 3 )
			{
				self.SendWeaponAnim( M16A2_FIRE3RND, 0, 0 );
			}
			else if( m_iBurstCount == 2 )
			{
				self.SendWeaponAnim( M16A2_FIRE2RND, 0, 0 );
			}
			else
			{
				switch( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 1 ) )
				{
					case 0: self.SendWeaponAnim( M16A2_FIRE1, 0, 0 ); break;
					case 1: self.SendWeaponAnim( M16A2_FIRE2, 0, 0 ); break;
				}
			}
		}
		else if( m_iFiremode == M16A2_MODE_SEMIAUTO )
		{
			switch( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed, 0, 1 ) )
			{
				case 0: self.SendWeaponAnim( M16A2_FIRE1, 0, 0 ); break;
				case 1: self.SendWeaponAnim( M16A2_FIRE2, 0, 0 ); break;
			}
		}

		Vector vecSrc	 = m_pPlayer.GetGunPosition();
		Vector vecAiming = m_pPlayer.GetAutoaimVector( AUTOAIM_5DEGREES );
		
		if( m_iFiremode == M16A2_MODE_SEMIAUTO )
		{
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 6.9f;
			self.m_flNextPrimaryAttack = WeaponTimeBase() + flCycleTime;
		}

		m_pPlayer.FireBullets( 1, vecSrc, vecAiming, m_iFiremode == M16A2_MODE_BURST ? VECTOR_CONE_3DEGREES : VECTOR_CONE_1DEGREES, 8192, BULLET_PLAYER_CUSTOMDAMAGE, 2, 0 );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		m_pPlayer.pev.punchangle.x = Math.RandomLong( -2, 2 );

		if( self.m_flNextPrimaryAttack < WeaponTimeBase() )
			self.m_flNextPrimaryAttack = WeaponTimeBase() + 0.15f;

		self.m_flTimeWeaponIdle = WeaponTimeBase() + 6.9f;

		TraceResult tr;

		float x, y;

		g_Utility.GetCircularGaussianSpread( x, y );

		Vector vecDir = vecAiming 
						+ x * ( m_iFiremode == M16A2_MODE_BURST ? VECTOR_CONE_3DEGREES.x : VECTOR_CONE_1DEGREES.x ) * g_Engine.v_right 
						+ y * ( m_iFiremode == M16A2_MODE_BURST ? VECTOR_CONE_3DEGREES.y : VECTOR_CONE_1DEGREES.y ) * g_Engine.v_up;

		Vector vecEnd	= vecSrc + vecDir * 8192;

		g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, m_pPlayer.edict(), tr );

		if( tr.flFraction < 1.0f )
		{
			if( tr.pHit !is null )
			{
				CBaseEntity@ pHit = g_EntityFuncs.Instance( tr.pHit );
				
				if( pHit is null || pHit.IsBSPModel() == true )
				{
					g_WeaponFuncs.DecalGunshot( tr, BULLET_PLAYER_MP5 );
				}
					
				g_WeaponFuncs.ClearMultiDamage();
					
				if( pHit.pev.takedamage != DAMAGE_NO && pHit.pev.classname != "monster_barney" && pHit.pev.classname != "monster_robogrunt" )
					pHit.TraceAttack( m_pPlayer.pev, M16A2_DAMAGE, vecDir, tr, DMG_SNIPER | DMG_NEVERGIB ); 
				else if( pHit.pev.classname == "monster_barney")
					pHit.TraceAttack( m_pPlayer.pev, (tr.iHitgroup == 10 ? M16A2_DAMAGE : M16A2_DAMAGE), vecDir, tr, DMG_SNIPER | DMG_NEVERGIB );
				else if( pHit.pev.classname == "monster_robogrunt" && pHit.IsAlive() == true )
					pHit.TraceAttack( m_pPlayer.pev, M16A2_DAMAGE, vecDir, tr, DMG_ENERGYBEAM | DMG_NEVERGIB ); 

				g_WeaponFuncs.ApplyMultiDamage( m_pPlayer.pev, m_pPlayer.pev );
			}
		}

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );

		Vector vecShellOrigin = m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_up * -5 + g_Engine.v_forward * 12 + g_Engine.v_right * 5;

		Vector vecShellVelocity = m_pPlayer.pev.velocity 
						+ g_Engine.v_right * Math.RandomFloat(50, 70) 
						+ g_Engine.v_up * Math.RandomFloat(100, 150) 
						+ g_Engine.v_forward * 25;

		g_EntityFuncs.EjectBrass( vecShellOrigin, vecShellVelocity, m_pPlayer.pev.angles[ 1 ], m_iShell, TE_BOUNCE_SHELL );
	}

	void LaunchGrenade()
	{
		m_pPlayer.m_iWeaponVolume = NORMAL_GUN_VOLUME;
		m_pPlayer.m_iWeaponFlash = BRIGHT_GUN_FLASH;

		m_pPlayer.m_iExtraSoundTypes = bits_SOUND_DANGER;
		m_pPlayer.m_flStopExtraSoundTime = WeaponTimeBase() + 0.2;

		m_pPlayer.m_rgAmmo( self.m_iSecondaryAmmoType, m_pPlayer.m_rgAmmo( self.m_iSecondaryAmmoType ) - 1 );

		m_pPlayer.pev.punchangle.x = -10.0;

		self.SendWeaponAnim( M16A2_M203_FIRE );

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );

		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, "custom_weapons/firearms/m203_fire1.wav", 1, ATTN_NORM );

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );

		if(( m_pPlayer.pev.button & IN_DUCK ) != 0 )
			ShootM203Grenade( m_pPlayer.pev, m_pPlayer.pev.origin + g_Engine.v_forward * 16 + g_Engine.v_right * 6, g_Engine.v_forward * 900 );
		else
			ShootM203Grenade( m_pPlayer.pev, m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs * 0.5 + g_Engine.v_forward * 16 + g_Engine.v_right * 6, g_Engine.v_forward * 900 );

		m_bGrenadeLoaded = false;
		self.m_flNextPrimaryAttack = WeaponTimeBase() + 1;
		self.m_flNextSecondaryAttack = WeaponTimeBase() + 1;
		self.m_flTimeWeaponIdle = WeaponTimeBase() + 5;

		if( m_pPlayer.m_rgAmmo(self.m_iSecondaryAmmoType) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );
	}
	
	void SecondaryAttack()
	{
		switch( m_iWeaponmode )
		{
			case M16A2_MODE_M16:
			{
				m_iWeaponmode = M16A2_MODE_M203;
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "Switched to M203 fire\n" );
				self.SendWeaponAnim( M16A2_M203_PREP );
				self.m_flNextPrimaryAttack = WeaponTimeBase() + 2.2f;
				break;
			}
			case M16A2_MODE_M203:
			{
				m_iWeaponmode = M16A2_MODE_M16;
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "Switched to M16 fire\n" );
				self.SendWeaponAnim( M16A2_M203_DEPREP );
				self.m_flNextPrimaryAttack = WeaponTimeBase() + 2.2f;
				break;
			}
		}

		self.m_flNextSecondaryAttack = WeaponTimeBase() + 2.2f;
	}
	
	void TertiaryAttack()
	{
		switch( m_iFiremode )
		{
			case M16A2_MODE_BURST:
			{
				m_iFiremode = M16A2_MODE_SEMIAUTO;
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "--> Switched to Semi-Auto <--\n" );
				break;
			}
			case M16A2_MODE_SEMIAUTO:
			{
				m_iFiremode = M16A2_MODE_BURST;
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "--> Switched to Burst Fire <--\n" );
				break;
			}
		}
		
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_ITEM, "buttons/lightswitch2.wav", 1, ATTN_NORM, 0, 92 );
		self.m_flNextTertiaryAttack = WeaponTimeBase() + 0.8f;
	}

	void Reload()
	{
		if( m_iWeaponmode == M16A2_MODE_M16 )
		{
			if( m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 || self.m_iClip == M16A2_MAX_CLIP )
				return;

			m_iBurstLeft = 0;

			switch( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed,  0, 5 ) )
			{
				case 0: self.DefaultReload( M16A2_MAX_CLIP, M16A2_RELOAD, 2.6f, 0 ); break;
				case 1: self.DefaultReload( M16A2_MAX_CLIP, M16A2_RELOAD_1, 2.6f, 0 ); break;
				case 2: self.DefaultReload( M16A2_MAX_CLIP, M16A2_RELOAD_EMPTY, 3.3f, 0 ); break;
				case 3: self.DefaultReload( M16A2_MAX_CLIP, M16A2_RELOAD_NMC, 2.3f, 0 ); break;
				case 4: self.DefaultReload( M16A2_MAX_CLIP, M16A2_RELOAD_NMC_1, 2.3f, 0 ); break;
				case 5: self.DefaultReload( M16A2_MAX_CLIP, M16A2_RELOAD_NMC_EMPTY, 2.7f, 0 ); break;
			}
			self.m_flTimeWeaponIdle = WeaponTimeBase() + 6.9f;
			BaseClass.Reload();
		}
		else if( m_iWeaponmode == M16A2_MODE_M203 )
		{
			if( m_pPlayer.m_rgAmmo(self.m_iSecondaryAmmoType) <= 0 || m_bGrenadeLoaded )
				return;

			self.SendWeaponAnim( M16A2_M203_RELOAD );

			BaseClass.Reload();
			
			m_bGrenadeLoaded = true;
			self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = WeaponTimeBase() + 2.7f;
		}

		self.pev.nextthink = WeaponTimeBase() + 0.85f;
		SetThink( ThinkFunction(EjectClipThink) );
	}

	void EjectClipThink()
	{
		ClipCasting( m_pPlayer.pev.origin );
	}
	
	void ClipCasting( Vector origin )
	{
		if( m_iDroppedM16Clip == 1 )
			return;
			
		int lifetime = 69;
		
		NetworkMessage m16clip( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
				m16clip.WriteByte( TE_BREAKMODEL );
				m16clip.WriteCoord( origin.x );
				m16clip.WriteCoord( origin.y );
				m16clip.WriteCoord( origin.z );
				m16clip.WriteCoord( 0 );
				m16clip.WriteCoord( 0 );
				m16clip.WriteCoord( 0 );
				m16clip.WriteCoord( 0 ); // velocity
				m16clip.WriteCoord( 0 ); // velocity
				m16clip.WriteCoord( 0 ); // velocity
				m16clip.WriteByte( 0 );
				m16clip.WriteShort( (m_iWeaponmode == M16A2_MODE_M16 ? m_iM16Clip : m_iM203Shell) );
				m16clip.WriteByte( 1); // bounce sound
				m16clip.WriteByte( int(lifetime) );
				m16clip.WriteByte( 2 ); // metallic sound
		m16clip.End();
		
		m_iDroppedM16Clip = 1;
	}

	void ItemPostFrame()
	{
		if( m_iBurstLeft > 0 )
		{
			if( m_flNextBurstFireTime < WeaponTimeBase() )
			{
				if( self.m_iClip <= 0 )
				{
					m_iBurstLeft = 0;
					return;
				}
				else
				{
					--m_iBurstLeft;
				}

				Shoot( 0.2 );

				if( m_iBurstLeft > 0 )
					m_flNextBurstFireTime = WeaponTimeBase() + 0.1f;
				else
					m_flNextBurstFireTime = 0;
			}
			return;
		}

		BaseClass.ItemPostFrame();
	}

	void WeaponIdle()
	{
		int iAnim;
		self.ResetEmptySound();

		m_pPlayer.GetAutoaimVector( AUTOAIM_10DEGREES );

		if( m_iDroppedM16Clip == 1)
			m_iDroppedM16Clip = 0;

		if( self.m_flTimeWeaponIdle > WeaponTimeBase() )
			return;

		if( m_iWeaponmode == M16A2_MODE_M16 )
		{
			switch( g_PlayerFuncs.SharedRandomLong( m_pPlayer.random_seed,  0, 1 ) )
			{
				case 0: iAnim = M16A2_IDLE1; break;
				case 1: iAnim = M16A2_IDLE2; break;
			}
		}
		else if( m_iWeaponmode == M16A2_MODE_M203 )
			iAnim = M16A2_M203_IDLE;

		self.SendWeaponAnim( iAnim );

		self.m_flTimeWeaponIdle = WeaponTimeBase() + 6.9f;
	}
}

class CM203Grenade : ScriptBaseMonsterEntity
{
	int m_iExplodeModel;

	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, M16A2_MODEL_GRENADE );
	}

	void Precache()
	{
		m_iExplodeModel = g_Game.PrecacheModel( M16A2_MODEL_GRENGIBS );
	}
	
	void Think()
	{
		self.pev.angles.x = Math.VecToAngles( self.pev.velocity ).x;
		if( !self.IsInWorld() )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		self.pev.nextthink = g_Engine.time + 0.1f;
	}

	void Touch( CBaseEntity@ pOther )
	{
		if( g_EngineFuncs.PointContents( self.pev.origin ) == CONTENTS_SKY )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		if( pOther.IsMonster() && pOther.IsAlive())
		{
			ExplodeContact();
		}
		else
		{
			Explode();
		}
	}
	
	void ExplodeContact()
	{
		TraceResult tr;
		tr = g_Utility.GetGlobalTrace();
			
		entvars_t@ pevOwner = self.pev.owner.vars;
		te_explosion( self.pev.origin, M16A2_SPRITE_EXPLOSION, int(self.pev.dmg/1.5) );
		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg*1.5f, 300.0f, CLASS_NONE, DMG_BLAST );
		switch( Math.RandomLong(0, 2) )
		{
			case 0: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "custom_weapons/firearms/explode3.wav", 1, 0.3f ); break;
			case 1: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "custom_weapons/firearms/explode4.wav", 1, 0.3f ); break;
			case 2: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "custom_weapons/firearms/explode5.wav", 1, 0.3f ); break;
		}
		g_Utility.DecalTrace( tr, DECAL_SCORCH1 + Math.RandomLong(0,1) );
		g_EntityFuncs.Remove( self );
	}
	
	void Explode()
	{
		TraceResult tr;
		tr = g_Utility.GetGlobalTrace();
			
		entvars_t@ pevOwner = self.pev.owner.vars;
		te_explosion( self.pev.origin, M16A2_SPRITE_EXPLOSION, int(self.pev.dmg/1.5) );
		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg, 300.0f, CLASS_NONE, DMG_BLAST );
		switch( Math.RandomLong(0, 2) )
		{
			case 0: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "custom_weapons/firearms/explode3.wav", 1, 0.3f ); break;
			case 1: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "custom_weapons/firearms/explode4.wav", 1, 0.3f ); break;
			case 2: g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, "custom_weapons/firearms/explode5.wav", 1, 0.3f ); break;
		}
		g_Utility.DecalTrace( tr, DECAL_SCORCH1 + Math.RandomLong(0,1) );
		g_EntityFuncs.Remove( self );
	}

	void te_explosion( Vector origin, string sprite, int scale )
	{
		NetworkMessage exp1( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			exp1.WriteByte( TE_EXPLOSION );
			exp1.WriteCoord( origin.x );
			exp1.WriteCoord( origin.y );
			exp1.WriteCoord( origin.z );
			exp1.WriteShort( g_EngineFuncs.ModelIndex(sprite) );
			exp1.WriteByte( int((scale-50) * .90) );
			exp1.WriteByte( 60 );
			exp1.WriteByte( 4 );
		exp1.End();

		NetworkMessage exp2( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			exp2.WriteByte( TE_FIREFIELD );
			exp2.WriteCoord( origin.x );
			exp2.WriteCoord( origin.y );
			exp2.WriteCoord( origin.z );
			exp2.WriteShort( 80 );//radius
			exp2.WriteShort( g_EngineFuncs.ModelIndex(sprite) );
			exp2.WriteByte( 16 );//count
			exp2.WriteByte( TEFIRE_FLAG_ADDITIVE );
			exp2.WriteByte( 4 );//duration
		exp2.End();

		int lifetime = 300;

		NetworkMessage explodemdl(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			explodemdl.WriteByte( TE_EXPLODEMODEL );
			explodemdl.WriteCoord( origin.x );
			explodemdl.WriteCoord( origin.y );
			explodemdl.WriteCoord( origin.z );
			explodemdl.WriteCoord( 500 ); // velocity
			explodemdl.WriteShort( m_iExplodeModel ); // model
			explodemdl.WriteShort( 15 ); // amount of models created
			explodemdl.WriteByte( int(lifetime) ); // decay time
		explodemdl.End();
	}
}

CM203Grenade ShootM203Grenade( entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity )
{
	int r = 200, g = 200, b = 200, br = 200;
	
	CBaseEntity@ cbeGrenade = g_EntityFuncs.CreateEntity( "m203nade", null,  false);
	CM203Grenade@ pGrenade = cast<CM203Grenade@>(CastToScriptClass(cbeGrenade));
	g_EntityFuncs.SetOrigin( pGrenade.self, vecStart );
	g_EntityFuncs.DispatchSpawn( pGrenade.self.edict() );
	pGrenade.pev.gravity = 0.5f;
	pGrenade.pev.movetype = MOVETYPE_TOSS;
	pGrenade.pev.solid = SOLID_BBOX;
	g_EntityFuncs.SetSize( pGrenade.pev, g_vecZero, g_vecZero );
	@pGrenade.pev.owner = pevOwner.pContainingEntity;
	pGrenade.pev.velocity = vecVelocity;
	pGrenade.pev.angles = Math.VecToAngles( pGrenade.pev.velocity );
	const Vector vecAngles = Math.VecToAngles( pGrenade.pev.velocity );
	pGrenade.SetThink( ThinkFunction( pGrenade.Think ) );
	pGrenade.pev.nextthink = g_Engine.time + 0.1f;
	pGrenade.SetTouch( TouchFunction( pGrenade.Touch ) );
	pGrenade.pev.dmg = M16A2_DAMAGE_M203;

	NetworkMessage trail( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
		trail.WriteByte( TE_BEAMFOLLOW );
		trail.WriteShort( pGrenade.self.entindex() );
		trail.WriteShort( g_EngineFuncs.ModelIndex(M16A2_SPRITE_TRAIL) );
		trail.WriteByte( 20 );//Life
		trail.WriteByte( 2 );//Width
		trail.WriteByte( int(r) );
		trail.WriteByte( int(g) );
		trail.WriteByte( int(b) );
		trail.WriteByte( int(br) );
	trail.End();

	return pGrenade;
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "fa_m16a2::CWeaponM16A2", "weapon_m16a2" );
	g_ItemRegistry.RegisterWeapon( "weapon_m16a2", "custom_weapons/firearms", "556", "ARgrenades" );
	g_CustomEntityFuncs.RegisterCustomEntity( "fa_m16a2::CM203Grenade", "m203nade" );
}

} //namespace fa_m16a2 END