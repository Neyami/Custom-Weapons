namespace hlwe_redeemer
{

const Vector CAMERA_COLOR		= Vector( 240, 180, 0 );
const int CAMERA_BRIGHTNESS	= 64;

const int DEFAULT_GIVE				= 4;
const int MAX_CARRY					= 12;
const int MAX_CLIP						= 1;
const int HLWE_DAMAGE				= 1500;
const int REDEEMER_WEIGHT		= 110;
const int REDEEMER_SLOT			= 7;
const int REDEEMER_POSITION	= 14;

const string SOUND_DRAW			= "custom_weapons/redeemer/redeemer_draw.wav";
const string SOUND_FIRE			= "custom_weapons/redeemer/redeemer_fire.wav";
const string SOUND_RELOAD		= "custom_weapons/redeemer/redeemer_reload.wav";
const string SOUND_FLY				= "custom_weapons/redeemer/redeemer_wh_fly.wav";
const string SOUND_EXPLODE		= "custom_weapons/redeemer/redeemer_wh_explode.wav";

const string MODEL_VIEW			= "models/custom_weapons/redeemer/v_redeemer.mdl";
const string MODEL_PLAYER		= "models/custom_weapons/redeemer/p_redeemer.mdl";
const string MODEL_PROJECTILE	= "models/custom_weapons/hlwe/projectiles.mdl";

enum redeemer_e
{
	REDEEMER_IDLE,
	REDEEMER_DRAW,
	REDEEMER_FIRE,
	REDEEMER_FIRE_SOLID,
	REDEEMER_HOLSTER,
	REDEEMER_RELOAD
};

class weapon_redeemer : ScriptBasePlayerWeaponEntity
{
	bool m_bIsNukeFlying;

	protected CBasePlayer@ m_pPlayer
	{
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel( self, MODEL_PLAYER );

		self.m_iDefaultAmmo = DEFAULT_GIVE;
		self.m_flCustomDmg = pev.dmg;
		pev.sequence = 1;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		g_Game.PrecacheModel( MODEL_VIEW );
		g_Game.PrecacheModel( MODEL_PLAYER );
		g_Game.PrecacheModel( MODEL_PROJECTILE );

		g_Game.PrecacheModel( "sprites/fexplo.spr" );
		g_Game.PrecacheModel( "sprites/white.spr" );
		g_Game.PrecacheModel( "sprites/spray.spr" );
		g_Game.PrecacheModel( "sprites/hotglow.spr" );
		g_Game.PrecacheModel( "sprites/steam1.spr" );
		g_Game.PrecacheModel( "sprites/smoke.spr" );

		g_Game.PrecacheGeneric( "sound/" + SOUND_DRAW );
		g_Game.PrecacheGeneric( "sound/" + SOUND_FIRE );
		g_Game.PrecacheGeneric( "sound/" + SOUND_RELOAD );
		g_Game.PrecacheGeneric( "sound/" + SOUND_FLY );
		g_Game.PrecacheGeneric( "sound/" + SOUND_EXPLODE );
		g_SoundSystem.PrecacheSound( SOUND_DRAW );
		g_SoundSystem.PrecacheSound( SOUND_FIRE );
		g_SoundSystem.PrecacheSound( SOUND_RELOAD );
		g_SoundSystem.PrecacheSound( SOUND_FLY );
		g_SoundSystem.PrecacheSound( SOUND_EXPLODE );

		//Precache these for downloading
		g_Game.PrecacheGeneric( "sprites/custom_weapons/redeemer.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/redeemer_crosshairs.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/weapon_redeemer.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= MAX_CARRY;
		info.iMaxAmmo2 	= -1;
		info.iMaxClip 	= MAX_CLIP;
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

		NetworkMessage redeemer( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			redeemer.WriteLong( g_ItemRegistry.GetIdForName("weapon_redeemer") );
		redeemer.End();

		return true;
	}

	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model(MODEL_VIEW), self.GetP_Model(MODEL_PLAYER), REDEEMER_DRAW, "gauss" );
			self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 1.0;

			return bResult;
		}
	}

	bool CanHolster()
	{
		return ( !m_bIsNukeFlying );
	}

	void Holster( int skipLocal = 0 )
	{
		m_bIsNukeFlying = false;

		BaseClass.Holster( skipLocal );
	}
	
	float WeaponTimeBase()
	{
		return g_Engine.time;
	}
	
	void PrimaryAttack()
	{
		if( m_bIsNukeFlying )
			return;

		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD or self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + 0.5;
			return;
		}

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( REDEEMER_FIRE );
		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, SOUND_FIRE, 1.0, 0.5 );
		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		ShootNuke( m_pPlayer.GetGunPosition() + g_Engine.v_forward * 32 + g_Engine.v_up * 2 + g_Engine.v_right * -2, g_Engine.v_forward * 1500, false );

		--self.m_iClip;
		self.m_flNextPrimaryAttack = g_Engine.time + 1.5;
		self.m_flNextSecondaryAttack = g_Engine.time + 1.5;
		self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
		m_pPlayer.pev.punchangle.x -= 15;
	}

	void SecondaryAttack()
	{
		if( m_bIsNukeFlying )
			return;

		if( m_pPlayer.pev.waterlevel == WATERLEVEL_HEAD or self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextSecondaryAttack = g_Engine.time + 0.5;
			return;
		}

		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( REDEEMER_FIRE );
		g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, SOUND_FIRE, 1.0, 0.5 );
		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		ShootNuke( m_pPlayer.GetGunPosition() + g_Engine.v_forward * 32 + g_Engine.v_up * 2 + g_Engine.v_right * -2, g_Engine.v_forward * 800, true );
		m_bIsNukeFlying = true;

		--self.m_iClip;
		self.m_flNextPrimaryAttack = g_Engine.time + 1.5;
		self.m_flNextSecondaryAttack = g_Engine.time + 1.5;
		self.m_flTimeWeaponIdle = g_Engine.time + 1.5;
		m_pPlayer.pev.punchangle.x -= 15;
	}

	void WeaponIdle()
	{
		self.m_bExclusiveHold = m_bIsNukeFlying ? true : false;

		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.SendWeaponAnim( REDEEMER_IDLE );
		self.m_flTimeWeaponIdle = g_Engine.time + 10.0;
	}

	void Reload()
	{		
		if( self.m_iClip != 0 or m_bIsNukeFlying )
			return;

		self.DefaultReload( 1, REDEEMER_RELOAD, 3.6 );
	}

	void ShootNuke( Vector vecStart, Vector vecVelocity, bool bCamera )
	{
		CBaseEntity@ cbeNuke = g_EntityFuncs.Create( "proj_nuke", vecStart, g_vecZero, false, m_pPlayer.edict() );
		proj_nuke@ pNuke = cast<proj_nuke@>(CastToScriptClass(cbeNuke));

		pNuke.pev.velocity = vecVelocity;
		pNuke.pev.angles = Math.VecToAngles( pNuke.pev.velocity );

		if( self.m_flCustomDmg > 0 )
			pNuke.pev.dmg = self.m_flCustomDmg;
		else
			pNuke.pev.dmg = HLWE_DAMAGE;

		if( bCamera )
		{
			g_PlayerFuncs.ScreenFade( m_pPlayer, CAMERA_COLOR, 0.01, 0.5, CAMERA_BRIGHTNESS, FFADE_OUT | FFADE_STAYOUT );
			g_EngineFuncs.SetView( m_pPlayer.edict(), pNuke.self.edict() );
			pNuke.pev.angles.x = -pNuke.pev.angles.x;

			pNuke.SetThink( ThinkFunction(pNuke.IgniteFollow) );
		}
		else
			pNuke.SetThink( ThinkFunction(pNuke.Ignite) );
	}
}

class proj_nuke : ScriptBaseEntity
{
	float flRadiationStayTime;

    protected CBasePlayer@ m_pOwner
    {
        get { return cast<CBasePlayer@>( g_EntityFuncs.Instance(pev.owner) ); }
    }

	void Spawn()
	{
		g_EntityFuncs.SetModel( self, MODEL_PROJECTILE );
		g_EntityFuncs.SetSize( self.pev, Vector(-1, -1, -1), Vector(1, 1, 1) );
		g_EntityFuncs.SetOrigin( self, pev.origin );

		pev.movetype = MOVETYPE_FLY;
		pev.solid = SOLID_BBOX;
		pev.body = 15;
		pev.effects |= EF_DIMLIGHT;

		SetTouch( TouchFunction(this.ExplodeTouch) );
		NukeDynamicLight( pev.origin, 32, 240, 180, 0, 10, 50 );

		pev.nextthink = 0.1;
	}

	void Ignite()
	{
		int r=128, g=128, b=128, br=128;
		int r2=255, g2=200, b2=200, br2=128;
		
		g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, SOUND_FLY, 1, 0.5 );
		
		// rocket trail
		NetworkMessage ntrail1( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			ntrail1.WriteByte( TE_BEAMFOLLOW );
			ntrail1.WriteShort( self.entindex() );
			ntrail1.WriteShort( g_EngineFuncs.ModelIndex("sprites/smoke.spr") );
			ntrail1.WriteByte( Math.RandomLong(5,30) );//Life
			ntrail1.WriteByte( Math.RandomLong(4,5) );//Width
			ntrail1.WriteByte( int(r) );
			ntrail1.WriteByte( int(g) );
			ntrail1.WriteByte( int(b) );
			ntrail1.WriteByte( int(br) );
		ntrail1.End();

		NetworkMessage ntrail2( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			ntrail2.WriteByte( TE_BEAMFOLLOW );
			ntrail2.WriteShort( self.entindex() );
			ntrail2.WriteShort( g_EngineFuncs.ModelIndex("sprites/spray.spr") );
			ntrail2.WriteByte( Math.RandomLong(5,30) );//Life
			ntrail2.WriteByte( Math.RandomLong(4,5) );//Width
			ntrail2.WriteByte( int(r2) );
			ntrail2.WriteByte( int(g2) );
			ntrail2.WriteByte( int(b2) );
			ntrail2.WriteByte( int(br2) );
		ntrail2.End();
	}

	void IgniteFollow()
	{
		int r=128, g=128, b=128, br=128;
		int r2=255, g2=200, b2=200, br2=128;
		
		g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, SOUND_FLY, 1.0, 0.5 );

		// rocket trail
		NetworkMessage ntrail3( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			ntrail3.WriteByte( TE_BEAMFOLLOW );
			ntrail3.WriteShort( self.entindex() );
			ntrail3.WriteShort( g_EngineFuncs.ModelIndex("sprites/smoke.spr") );
			ntrail3.WriteByte( Math.RandomLong(5, 30) );//Life
			ntrail3.WriteByte( Math.RandomLong(4, 5) );//Width
			ntrail3.WriteByte( int(r) );
			ntrail3.WriteByte( int(g) );
			ntrail3.WriteByte( int(b) );
			ntrail3.WriteByte( int(br) );
		ntrail3.End();

		NetworkMessage ntrail4( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			ntrail4.WriteByte( TE_BEAMFOLLOW );
			ntrail4.WriteShort( self.entindex() );
			ntrail4.WriteShort( g_EngineFuncs.ModelIndex("sprites/spray.spr") );
			ntrail4.WriteByte( Math.RandomLong(5, 30) );//Life
			ntrail4.WriteByte( Math.RandomLong(4, 5) );//Width
			ntrail4.WriteByte( int(r2) );
			ntrail4.WriteByte( int(g2) );
			ntrail4.WriteByte( int(b2) );
			ntrail4.WriteByte( int(br2) );
		ntrail4.End();

		SetThink( ThinkFunction(this.Follow) );
		pev.nextthink = g_Engine.time + 0.1;
	}

	void Follow()
	{
		if( m_pOwner is null or !m_pOwner.IsConnected() )
		{
			RemoveSelf();
			return;
		}

		if( pev.owner.vars.deadflag <= DEAD_NO )
		{
			Vector velocity;
			g_EngineFuncs.MakeVectors( pev.owner.vars.v_angle );
			velocity = g_Engine.v_forward * 800;
			pev.velocity = velocity;

			Vector angles = pev.owner.vars.v_angle;
			pev.angles = angles;
			pev.nextthink = g_Engine.time + 0.01;

			if( (pev.owner.vars.button & IN_ATTACK) != 0 )
				ExplodeTouch(null);
		}
	}

	void ExplodeTouch( CBaseEntity@ pOther )
	{
		g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, SOUND_FLY );

		if( m_pOwner is null or !m_pOwner.IsConnected() )
		{
			RemoveSelf();
			return;
		}

		CBaseEntity@ cbeOwner = g_EntityFuncs.Instance( pev.owner );
		CBasePlayer@ pOwner = cast<CBasePlayer@>( cbeOwner );

		if( m_pOwner.m_hActiveItem.GetEntity() !is null )
		{
			CBasePlayerWeapon@ pWeapon = cast<CBasePlayerWeapon@>( m_pOwner.m_hActiveItem.GetEntity() );

			if( pWeapon.GetClassname() == "weapon_redeemer" )
			{
				weapon_redeemer@ pRedeemer = cast<weapon_redeemer@>(CastToScriptClass(pWeapon));
				if( pRedeemer !is null )
					pRedeemer.m_bIsNukeFlying = false;
			}
		}

		g_EngineFuncs.SetView( m_pOwner.edict(), m_pOwner.edict() );
		g_PlayerFuncs.ScreenFade( m_pOwner, CAMERA_COLOR, 0.01, 0.1, CAMERA_BRIGHTNESS, FFADE_IN );

		if( g_EngineFuncs.PointContents(pev.origin) == CONTENTS_SKY )
		{
			RemoveSelf();
			return;
		}

		flRadiationStayTime = pev.dmg/30;

		TraceResult tr;
		Vector vecSpot = pev.origin - pev.velocity.Normalize() * 32;
		Vector vecEnd = pev.origin + pev.velocity.Normalize() * 64;
		g_Utility.TraceLine( vecSpot, vecEnd, ignore_monsters, self.edict(), tr );

		Explode( tr, DMG_BLAST );
		g_Utility.DecalTrace( tr, DECAL_SCORCH1 + Math.RandomLong(0,1) );
		
		if( pOther !is null and pOther.pev.takedamage == 1 )
		{
			g_WeaponFuncs.ClearMultiDamage();
			pOther.TraceAttack( pev.owner.vars, pev.dmg/8, g_Engine.v_forward, tr, DMG_BULLET ); 
			g_WeaponFuncs.ApplyMultiDamage( self.pev, pev.owner.vars );
		}
	}

	void Explode( TraceResult pTrace, int bitsDamageType )
	{
		g_PlayerFuncs.ScreenShake( pev.origin, 80, 8, 5, pev.dmg*2.5 );
		g_WeaponFuncs.RadiusDamage( pev.origin, self.pev, pev.owner.vars, pev.dmg, pev.dmg, CLASS_NONE, DMG_BLAST | DMG_NEVERGIB);
		g_WeaponFuncs.RadiusDamage( pev.origin, self.pev, pev.owner.vars, pev.dmg/20, pev.dmg/3, CLASS_NONE, DMG_PARALYZE );
		NukeEffect( pev.origin );
		g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, SOUND_EXPLODE, 1, ATTN_NONE );

		pev.effects |= EF_NODRAW;
		pev.velocity = g_vecZero;
		SetTouch( null );
		SetThink( ThinkFunction( this.Irradiate ) );
		pev.nextthink = g_Engine.time + 0.3;
	}
	
	void Irradiate()
	{
		//CBaseEntity@ pentFind;
		float range;
		Vector vecSpot1, vecSpot2;
		
		if( flRadiationStayTime <=0 )
		{
/*
			@pentFind = g_EntityFuncs.FindEntityByClassname( null, "player" );
			if( pentFind !is null and pentFind.IsPlayer() and pentFind.IsAlive() )
			{
				range = (self.pev.origin - pentFind.pev.origin).Length();

				NetworkMessage geiger( MSG_ONE, NetworkMessages::Geiger, pentFind.edict() );
					geiger.WriteByte( 0 );
				geiger.End();
			}
*/
			RemoveSelf();
		}
		else
		{
			--flRadiationStayTime;

/*
			@pentFind = g_EntityFuncs.FindEntityByClassname( null, "player" );
			if( pentFind !is null and pentFind.IsPlayer() and pentFind.IsAlive() )
			{
				range = (self.pev.origin - pentFind.pev.origin).Length();
				
				vecSpot1 = (self.pev.absmin + self.pev.absmax) * 0.5;
				vecSpot2 = (pentFind.pev.absmin + pentFind.pev.absmax) * 0.5;
				
				range = (vecSpot1 - vecSpot2).Length();

				NetworkMessage geiger( MSG_ONE, NetworkMessages::Geiger, pentFind.edict() );
					geiger.WriteByte( int(range) );
				geiger.End();
			}
*/
		}

		g_WeaponFuncs.RadiusDamage( pev.origin, self.pev, pev.owner.vars, flRadiationStayTime/2, pev.dmg/3, CLASS_MACHINE, DMG_RADIATION | DMG_NEVERGIB );
		
		pev.nextthink = g_Engine.time + 0.3;
	}

	void Killed( entvars_t@ pevAttacker, int iGib )
	{
		if( m_pOwner !is null and m_pOwner.IsConnected() )
		{
			if( pev.owner.vars.ClassNameIs("player") )
			{
				g_EngineFuncs.SetView( m_pOwner.edict(), m_pOwner.edict() );
				g_PlayerFuncs.ScreenFade( m_pOwner, CAMERA_COLOR, 0.01, 0.1, CAMERA_BRIGHTNESS, FFADE_IN );
			}
		}

		RemoveSelf();
	}

	void RemoveSelf()
	{
		g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, SOUND_FLY );
		g_EntityFuncs.Remove( self );
	}
	
	void NukeEffect( Vector origin )
	{
		int fireballScale = 60;
		int fireballBrightness = 255;
		int smokeScale = 125;
		int discLife = 12;
		int discWidth = 64;
		int discR = 255;
		int discG = 255;
		int discB = 192;
		int discBrightness = 128;
		int glowLife = int(self.pev.dmg/10);
		int glowScale = 128;
		int glowBrightness = 190;
		
		//Make a Big Fireball
		NetworkMessage nukexp1( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			nukexp1.WriteByte( TE_SPRITE );
			nukexp1.WriteCoord( origin.x );
			nukexp1.WriteCoord( origin.y );
			nukexp1.WriteCoord( origin.z + 128 );
			nukexp1.WriteShort( g_EngineFuncs.ModelIndex("sprites/fexplo.spr") );
			nukexp1.WriteByte( int(fireballScale) );
			nukexp1.WriteByte( int(fireballBrightness) );
		nukexp1.End();

		// Big Plume of Smoke
		NetworkMessage nukexp2( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			nukexp2.WriteByte( TE_SMOKE );
			nukexp2.WriteCoord( origin.x );
			nukexp2.WriteCoord( origin.y );
			nukexp2.WriteCoord( origin.z + 256 );
			nukexp2.WriteShort( g_EngineFuncs.ModelIndex("sprites/steam1.spr") );
			nukexp2.WriteByte( int(smokeScale) );
			nukexp2.WriteByte( 5 ); //framrate
		nukexp2.End();

		// blast circle "The Infamous Disc of Death"
		NetworkMessage nukexp3( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			nukexp3.WriteByte( TE_BEAMCYLINDER );
			nukexp3.WriteCoord( origin.x );
			nukexp3.WriteCoord( origin.y );
			nukexp3.WriteCoord( origin.z );
			nukexp3.WriteCoord( origin.x );
			nukexp3.WriteCoord( origin.y );
			nukexp3.WriteCoord( origin.z + 320 );
			nukexp3.WriteShort( g_EngineFuncs.ModelIndex("sprites/white.spr") );
			nukexp3.WriteByte( 0 );
			nukexp3.WriteByte( 0 );
			nukexp3.WriteByte( discLife );
			nukexp3.WriteByte( discWidth );
			nukexp3.WriteByte( 0 );
			nukexp3.WriteByte( int(discR) );
			nukexp3.WriteByte( int(discG) );
			nukexp3.WriteByte( int(discB) );
			nukexp3.WriteByte( int(discBrightness) );
			nukexp3.WriteByte( 0 );
		nukexp3.End();
		
		//insane glow
		NetworkMessage nukexp4( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			nukexp4.WriteByte( TE_GLOWSPRITE );
			nukexp4.WriteCoord( origin.x );
			nukexp4.WriteCoord( origin.y );
			nukexp4.WriteCoord( origin.z );
			nukexp4.WriteShort( g_EngineFuncs.ModelIndex("sprites/hotglow.spr") );
			nukexp4.WriteByte( glowLife );
			nukexp4.WriteByte( int(glowScale) );
			nukexp4.WriteByte( int(glowBrightness) );
		nukexp4.End();
	}
}

void NukeDynamicLight( Vector vecPos, int radius, int r, int g, int b, int8 life, int decay )
{
	NetworkMessage ndl( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecPos );
		ndl.WriteByte( TE_DLIGHT );
		ndl.WriteCoord( vecPos.x );
		ndl.WriteCoord( vecPos.y );
		ndl.WriteCoord( vecPos.z );
		ndl.WriteByte( radius );
		ndl.WriteByte( int(r) );
		ndl.WriteByte( int(g) );
		ndl.WriteByte( int(b) );
		ndl.WriteByte( life );
		ndl.WriteByte( decay );
	ndl.End();
}

class NukeAmmoBox : ScriptBasePlayerAmmoEntity
{	
	void Spawn()
	{ 
		g_EntityFuncs.SetModel( self, MODEL_PROJECTILE );
		pev.body = 15;
		BaseClass.Spawn();
	}
	
	bool AddAmmo( CBaseEntity@ pOther )
	{ 
		int iGive;

		iGive = DEFAULT_GIVE;

		if( pOther.GiveAmmo( iGive, "nuke", MAX_CARRY ) != -1)
		{
			g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, "items/9mmclip1.wav", 1, ATTN_NORM );
			return true;
		}

		return false;
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "hlwe_redeemer::weapon_redeemer", "weapon_redeemer" );
	g_ItemRegistry.RegisterWeapon( "weapon_redeemer", "custom_weapons", "nuke" );
	g_CustomEntityFuncs.RegisterCustomEntity( "hlwe_redeemer::NukeAmmoBox", "ammo_nuke" );
	g_CustomEntityFuncs.RegisterCustomEntity( "hlwe_redeemer::proj_nuke", "proj_nuke" );
}

} //namespace hlwe_redeemer END