Vector vecCamColor(240,180,0);
int iCamBrightness = 64;
	
class CNuke : ScriptBaseEntity
{
	float m_yawCenter;
	float m_pitchCenter;
	float RadiationStayTime;
	float ATTN_LOW_HIGH = 0.5f;
	int m_iExplode, m_iSpriteTexture, m_iSpriteTexture2, m_iGlow, m_iSmoke, m_iTrail;
	
	void Spawn()
	{
		Precache();
		self.pev.movetype = MOVETYPE_FLY;
		self.pev.solid = SOLID_BBOX;
		g_EntityFuncs.SetModel( self, REDEEMER_MODEL_PROJECTILE );
		self.pev.body = 15;
		m_yawCenter = pev.angles.y;
		m_pitchCenter = pev.angles.x;
		g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );
		SetTouch( TouchFunction( this.ExplodeTouch ) );
		NukeDynamicLight( self.pev.origin, 32, 240, 180, 0, 10, 50 );
		self.pev.effects |= EF_DIMLIGHT;
	}
	
	void Precache()
	{
		m_iExplode = g_Game.PrecacheModel( "sprites/fexplo.spr" );
		m_iSpriteTexture = g_Game.PrecacheModel( "sprites/white.spr" );
		m_iSpriteTexture2 = g_Game.PrecacheModel( "sprites/spray.spr" );
		m_iGlow = g_Game.PrecacheModel( "sprites/hotglow.spr" );
		m_iSmoke = g_Game.PrecacheModel( "sprites/steam1.spr" );
		m_iTrail = g_Game.PrecacheModel( "sprites/smoke.spr" );
	}
	
	void Ignite()
	{
		int r=128, g=128, b=128, br=128;
		int r2=255, g2=200, b2=200, br2=128;
		
		g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, REDEEMER_SOUND_FLY, 1, ATTN_LOW_HIGH );
		
		// rocket trail
		NetworkMessage ntrail1( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			ntrail1.WriteByte( TE_BEAMFOLLOW );
			ntrail1.WriteShort( self.entindex() );
			ntrail1.WriteShort( m_iTrail );
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
			ntrail2.WriteShort( m_iSpriteTexture2 );
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
		
		g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, REDEEMER_SOUND_FLY, 1.0, ATTN_LOW_HIGH );
		SetThink( ThinkFunction( this.Follow ) );
		self.pev.nextthink = g_Engine.time + 0.1;
		// rocket trail
		NetworkMessage ntrail3( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
			ntrail3.WriteByte( TE_BEAMFOLLOW );
			ntrail3.WriteShort( self.entindex() );
			ntrail3.WriteShort( m_iTrail );
			ntrail3.WriteByte( Math.RandomLong(5,30) );//Life
			ntrail3.WriteByte( Math.RandomLong(4,5) );//Width
			ntrail3.WriteByte( int(r) );
			ntrail3.WriteByte( int(g) );
			ntrail3.WriteByte( int(b) );
			ntrail3.WriteByte( int(br) );
		ntrail3.End();
		NetworkMessage ntrail4( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			ntrail4.WriteByte( TE_BEAMFOLLOW );
			ntrail4.WriteShort( self.entindex() );
			ntrail4.WriteShort( m_iSpriteTexture2 );
			ntrail4.WriteByte( Math.RandomLong(5,30) );//Life
			ntrail4.WriteByte( Math.RandomLong(4,5) );//Width
			ntrail4.WriteByte( int(r2) );
			ntrail4.WriteByte( int(g2) );
			ntrail4.WriteByte( int(b2) );
			ntrail4.WriteByte( int(br2) );
		ntrail4.End();
	}

	void Follow()
	{
		entvars_t@ pevOwner = self.pev.owner.vars;
		Vector velocity;
		g_EngineFuncs.MakeVectors(pevOwner.v_angle);
		velocity = g_Engine.v_forward * 800;
		pev.velocity = velocity;

		Vector angles = pevOwner.v_angle;
		pev.angles = angles;
		self.pev.nextthink = g_Engine.time + 0.01f;

		if( (pevOwner.button & IN_ATTACK) != 0 )
			ExplodeTouch(null);
	}

	void ExplodeTouch( CBaseEntity@ pOther )
	{
		int iIndex;
		entvars_t@ pevOwner = self.pev.owner.vars;
		if( pevOwner.ClassNameIs( "player" ) )
		{
			iIndex = cast<CBasePlayer@>( g_EntityFuncs.Instance(self.pev.owner) ).entindex();
			g_bIsNukeFlying[ iIndex ] = false;
			g_EngineFuncs.SetView( self.pev.owner, self.pev.owner );
			g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance( self.pev.owner ), vecCamColor, 0.01f, 0.1f, iCamBrightness, FFADE_IN );
		}
		
		g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, REDEEMER_SOUND_FLY );

		if( g_EngineFuncs.PointContents( self.pev.origin ) == CONTENTS_SKY )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		RadiationStayTime = self.pev.dmg/30;

		TraceResult tr;
		Vector vecSpot = self.pev.origin - self.pev.velocity.Normalize() * 32;
		Vector vecEnd = self.pev.origin + self.pev.velocity.Normalize() * 64;
		g_Utility.TraceLine( vecSpot, vecEnd, ignore_monsters, self.edict(), tr );

		Explode( tr, DMG_BLAST );
		g_Utility.DecalTrace( tr, DECAL_SCORCH1 + Math.RandomLong(0,1) );
		
		if( pOther !is null && pOther.pev.takedamage == 1 )
		{
			g_WeaponFuncs.ClearMultiDamage();
			pOther.TraceAttack( pevOwner, self.pev.dmg/8, g_Engine.v_forward, tr, DMG_BULLET ); 
			g_WeaponFuncs.ApplyMultiDamage( self.pev, pevOwner);
		}
	}

	void Explode( TraceResult pTrace, int bitsDamageType )
	{
		g_PlayerFuncs.ScreenShake( self.pev.origin, 80, 8, 5, self.pev.dmg*2.5f );
		entvars_t@ pevOwner = self.pev.owner.vars;
		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg, self.pev.dmg, CLASS_NONE, DMG_BLAST | DMG_NEVERGIB);
		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg/20, self.pev.dmg/3, CLASS_NONE, DMG_PARALYZE );
		NukeEffect( self.pev.origin );
		g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, REDEEMER_SOUND_EXPLODE, 1, ATTN_NONE );

		self.pev.effects |= EF_NODRAW;
		self.pev.velocity = g_vecZero;
		SetTouch( null );
		SetThink( ThinkFunction( this.Irradiate ) );
		self.pev.nextthink = g_Engine.time + 0.3f;
	}
	
	void Irradiate()
	{
		//CBaseEntity@ pentFind;
		float range;
		Vector vecSpot1, vecSpot2;
		
		if( RadiationStayTime <=0 )
		{
/*
			@pentFind = g_EntityFuncs.FindEntityByClassname( null, "player" );
			if( pentFind !is null && pentFind.IsPlayer() && pentFind.IsAlive() )
			{
				range = (self.pev.origin - pentFind.pev.origin).Length();

				NetworkMessage geiger( MSG_ONE, NetworkMessages::Geiger, pentFind.edict() );
					geiger.WriteByte( 0 );
				geiger.End();
			}
*/
			g_EntityFuncs.Remove( self );
		}
		else
		{
			--RadiationStayTime;

/*			
			@pentFind = g_EntityFuncs.FindEntityByClassname( null, "player" );
			if( pentFind !is null && pentFind.IsPlayer() && pentFind.IsAlive() )
			{
				range = (self.pev.origin - pentFind.pev.origin).Length();
				
				vecSpot1 = (self.pev.absmin + self.pev.absmax) * 0.5f;
				vecSpot2 = (pentFind.pev.absmin + pentFind.pev.absmax) * 0.5f;
				
				range = (vecSpot1 - vecSpot2).Length();

				NetworkMessage geiger( MSG_ONE, NetworkMessages::Geiger, pentFind.edict() );
					geiger.WriteByte( int(range) );
				geiger.End();
			}
*/
		}

		entvars_t@ pevOwner = self.pev.owner.vars;
		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, RadiationStayTime/2, self.pev.dmg/3, CLASS_MACHINE, DMG_RADIATION | DMG_NEVERGIB );
		
		self.pev.nextthink = g_Engine.time + 0.3f;
	}

	void Killed( entvars_t@ pevAttacker, int iGib )
	{
		entvars_t@ pevOwner = self.pev.owner.vars;
		if( pevOwner.ClassNameIs("player") )
		{
			g_EngineFuncs.SetView( self.pev.owner, self.pev.owner );
			g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance( self.pev.owner ), vecCamColor, 0.01f, 0.1f, iCamBrightness, FFADE_IN );
		}
		g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, REDEEMER_SOUND_FLY );
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
			nukexp1.WriteShort( m_iExplode );
			nukexp1.WriteByte( int(fireballScale) );
			nukexp1.WriteByte( int(fireballBrightness) );
		nukexp1.End();

		// Big Plume of Smoke
		NetworkMessage nukexp2( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			nukexp2.WriteByte( TE_SMOKE );
			nukexp2.WriteCoord( origin.x );
			nukexp2.WriteCoord( origin.y );
			nukexp2.WriteCoord( origin.z + 256 );
			nukexp2.WriteShort( m_iSmoke );
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
			nukexp3.WriteShort( m_iSpriteTexture );
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
			nukexp4.WriteShort( m_iGlow );
			nukexp4.WriteByte( glowLife );
			nukexp4.WriteByte( int(glowScale) );
			nukexp4.WriteByte( int(glowBrightness) );
		nukexp4.End();
	}
}

CNuke@ ShootNuke( entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, bool Camera )
{
	CBaseEntity@ cbeNuke = g_EntityFuncs.CreateEntity( "nuke", null,  false);
	CNuke@ pNuke = cast<CNuke@>(CastToScriptClass(cbeNuke));
	g_EntityFuncs.DispatchSpawn( pNuke.self.edict() );
	g_EntityFuncs.SetOrigin( pNuke.self, vecStart );
	
	pNuke.pev.velocity = vecVelocity;
	pNuke.pev.angles = Math.VecToAngles( pNuke.pev.velocity );
	@pNuke.pev.owner = pevOwner.pContainingEntity;
	pNuke.pev.dmg = REDEEMER_DAMAGE;
	NukeDynamicLight( pNuke.pev.origin, 32, 240, 180, 0, 10, 50 );
	pNuke.pev.effects |= EF_DIMLIGHT;

	if( Camera )
	{
		g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance( pevOwner ), vecCamColor, 0.01f, 0.5f, iCamBrightness, FFADE_OUT | FFADE_STAYOUT );
		g_EngineFuncs.SetView( pevOwner.pContainingEntity, pNuke.self.edict() );
		pNuke.pev.angles.x = -pNuke.pev.angles.x;

		pNuke.SetThink( ThinkFunction( pNuke.IgniteFollow ) );
		pNuke.pev.nextthink = 0.1f;
	}
	else
	{
		pNuke.SetThink( ThinkFunction( pNuke.Ignite ) );
		pNuke.pev.nextthink = 0.1f;
	}
	return pNuke;
}

void NukeDynamicLight( Vector vecPos, int radius, int r, int g, int b, int8 life, int decay )
{
	NetworkMessage ndl( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
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