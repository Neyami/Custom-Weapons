const int SF_DETONATE = 0x0001;
const float ATTN_LOW_HIGH = 0.5;
const float BM_EXPLOSION_VOLUME = 0.5;

enum biomasscode_e
{
	BIOMASS_DETONATE = 0,
	BIOMASS_RELEASE
};

class CBiomass : ScriptBaseMonsterEntity
{
	string BIOMASS_MODEL = "models/custom_weapons/biorifle/w_biomass.mdl";
	string BIOMASS_SOUND_HIT1 = "custom_weapons/biorifle/bustflesh1.wav";
	string BIOMASS_SOUND_HIT2 = "custom_weapons/biorifle/bustflesh2.wav";
	string BIOMASS_SOUND_EXPL = "custom_weapons/biorifle/biomass_exp.wav";
	
	string BIOMASS_EXPLOSION1 = "sprites/explode1.spr";
	string BIOMASS_EXPLOSION2 = "sprites/spore_exp_01.spr";
	string BIOMASS_EXPLOSION3 = "sprites/spore_exp_c_01.spr";
	string BIOMASS_EXPLOSION_WATER = "sprites/WXplo1.spr";	

	Vector dist;
	float angl_y, angl_x;
	bool b_attached;
	
	void Spawn()
	{
		Precache();
		g_EntityFuncs.SetModel( self, BIOMASS_MODEL );
		self.ResetSequenceInfo();
		self.pev.movetype = MOVETYPE_BOUNCE;
		self.pev.solid = SOLID_BBOX;
		self.pev.rendermode = kRenderTransTexture;
		self.pev.renderamt = 150;
		self.pev.scale = 1.5;
		@self.pev.enemy = null;
		dist = g_vecZero;
		angl_x = angl_y = 0;
		b_attached = false;
		g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );
	}

	void Precache()
	{
/*
		g_Game.PrecacheModel( BIOMASS_MODEL );
		g_Game.PrecacheGeneric( "sound/" + BIOMASS_SOUND_HIT1 );
		g_Game.PrecacheGeneric( "sound/" + BIOMASS_SOUND_HIT2 );
		g_Game.PrecacheGeneric( "sound/" + BIOMASS_SOUND_EXPL );
		g_SoundSystem.PrecacheSound( BIOMASS_SOUND_HIT1 );
		g_SoundSystem.PrecacheSound( BIOMASS_SOUND_HIT2 );
		g_SoundSystem.PrecacheSound( BIOMASS_SOUND_EXPL );
*/
	}

	void Killed( entvars_t@ pevAttacker, int iGib )
	{
		g_EntityFuncs.Remove( self );
	}

	int	Classify()
	{
		return CLASS_PLAYER_BIOWEAPON;
	}
	
	void Detonate()
	{
		TraceResult tr;
		Vector vecEnd = pev.origin + pev.angles + g_Engine.v_forward*20;
		g_Utility.TraceLine( self.pev.origin, vecEnd, ignore_monsters, self.edict(), tr );
		g_Utility.DecalTrace( tr, DECAL_OFSCORCH1 + Math.RandomLong( 0,2 ) );

		entvars_t@ pevOwner = self.pev.owner.vars;
		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg, self.pev.dmg*3, CLASS_NONE, DMG_SONIC );

		if( g_EngineFuncs.PointContents( self.pev.origin ) == CONTENTS_WATER )
		{
			te_explosion( self.pev.origin, BIOMASS_EXPLOSION_WATER, BIORIFLE_DAMAGE*1.2, 15, (TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND) );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, BIOMASS_SOUND_EXPL, BM_EXPLOSION_VOLUME, ATTN_LOW_HIGH, 0, 200 );
			DynamicLight( self.pev.origin, 12, 170, 250, 0, 1, 20 );
			g_Utility.Bubbles( self.pev.origin + Vector(0.2,0.2,0.5), self.pev.origin - Vector(0.2,0.2,0.5), 30 );
		}
		else
		{
			te_explosion( self.pev.origin, BIOMASS_EXPLOSION1, BIORIFLE_DAMAGE*1.2, 15, (TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND) );
			te_explosion( self.pev.origin, BIOMASS_EXPLOSION2, BIORIFLE_DAMAGE*1.2, 15, (TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND) );
			te_explosion( self.pev.origin, BIOMASS_EXPLOSION3, BIORIFLE_DAMAGE*1.3, 15, (TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND) );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, BIOMASS_SOUND_EXPL, BM_EXPLOSION_VOLUME, ATTN_LOW_HIGH, 0, PITCH_NORM );
			DynamicLight( self.pev.origin, 20, 170, 250, 0, 1, 50 );
		}

		g_EntityFuncs.Remove( self );
	}

	void DetonateUse( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value )
	{
		Detonate();
	}

	void Deactivate()
	{
		Detonate();
	}

	void SlideTouch( CBaseEntity@ pOther )
	{
		if( g_EngineFuncs.PointContents( self.pev.origin ) == CONTENTS_SKY )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		if( pOther.pev.takedamage == 1 && self.m_flNextAttack < g_Engine.time )
		{
			entvars_t@ pevOwner = self.pev.owner.vars;
			switch( Math.RandomLong( 0,1 ) )
			{
				case 0:	pOther.TakeDamage( self.pev, pevOwner, 1, DMG_POISON ); break;
				case 1:	pOther.TakeDamage( self.pev, pevOwner, 1, DMG_ACID ); break;
			}
			switch( Math.RandomLong( 0,1 ) )
			{
				case 0:	g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, BIOMASS_SOUND_HIT1, 1, ATTN_NORM ); break;
				case 1:	g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, BIOMASS_SOUND_HIT2, 1, ATTN_NORM ); break;
			}
			self.m_flNextAttack = g_Engine.time + 25;
		}
		else if( pOther.pev.solid == SOLID_BSP || pOther.pev.movetype == MOVETYPE_PUSHSTEP )
		{
			switch( Math.RandomLong( 0,1 ) )
			{
				case 0:	g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, BIOMASS_SOUND_HIT1, 1, ATTN_NORM ); break;
				case 1:	g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, BIOMASS_SOUND_HIT2, 1, ATTN_NORM ); break;
			}
		}

		self.pev.velocity = self.pev.velocity * 0.3;

		if( !b_attached && self.pev.waterlevel == WATERLEVEL_DRY )
		{
			b_attached = true;
			self.pev.velocity = self.pev.avelocity = g_vecZero;
			self.pev.movetype = MOVETYPE_FLY;
			self.pev.solid = SOLID_NOT;
			@self.pev.enemy = pOther.edict();
			dist = self.pev.origin - pOther.pev.origin;

			if( pOther.IsPlayer() )
			{
				angl_y = pOther.pev.v_angle.y;
			}
			else
			{
				angl_y = pOther.pev.angles.y;
				angl_x = pOther.pev.angles.x;
			}
		}
	}

	void StayInWorld()
	{
		self.pev.nextthink = g_Engine.time + 0.01;

		if( !self.IsInWorld() )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		self.pev.frags--;
		if( self.pev.frags <= 0 )
		{
			Detonate();
			return;
		}

		self.StudioFrameAdvance();

		if( self.pev.enemy !is null )
		{
			CBaseEntity@ owner = g_EntityFuncs.Instance( self.pev.enemy );

			if( owner is null )
			{
				b_attached = false;
				@self.pev.enemy = null;
				self.pev.movetype = MOVETYPE_TOSS;
				self.pev.solid = SOLID_BBOX;
				return;
			}

			if( owner.IsPlayer() && !owner.IsAlive() )
			{
				Detonate();
				return;
			}
			
			if( owner.pev.deadflag == DEAD_DEAD && owner.pev.health <= 0 )
			{
				Detonate();
				return;
			}

			float alpha, theta;

			if( owner.IsPlayer() )
			{
				alpha = angl_y - owner.pev.v_angle.y;
				theta = 0;
			}
			else
			{
				alpha = angl_y - owner.pev.angles.y;
				theta = angl_x - owner.pev.angles.x;
			}

			alpha *= Math.PI/180.0;
			theta *= Math.PI/180.0;

			//Vector offset (dist.x * cos(alpha) + dist.y * sin(alpha), dist.y * cos(alpha) - dist.x * sin(alpha), dist.z);
			Vector offset(dist.x * cos(alpha) * cos(theta) + dist.y * sin(alpha) - dist.z * cos(alpha) * sin(theta),
						  dist.y * cos(alpha) - dist.x * sin(alpha) * cos(theta) + dist.z * sin(alpha) * sin(theta),
						  dist.x * sin(theta) + dist.z * cos(theta));

			if( owner.IsPlayer() && owner.pev.waterlevel > WATERLEVEL_FEET )
				offset.z = 0;

			//pev.origin = owner.pev.origin + offset;
			self.pev.velocity = (owner.pev.origin + offset - self.pev.origin)/Math.max(0.05, g_Engine.frametime);
			return;
		}
		else if( b_attached )
		{
			b_attached = false;
			@self.pev.enemy = null;
			self.pev.movetype = MOVETYPE_TOSS;
			self.pev.solid = SOLID_BBOX;
			return;
		}

		if( self.pev.waterlevel == WATERLEVEL_HEAD)
		{
			b_attached = false;
			@self.pev.enemy = null;
			self.pev.movetype = MOVETYPE_TOSS;
			self.pev.solid = SOLID_BBOX;
		}
		else if( self.pev.waterlevel == WATERLEVEL_DRY )
			self.pev.movetype = MOVETYPE_BOUNCE;
		else
			self.pev.velocity.z -= 8;
	}
	
	void UseBiomass( entvars_t@ pevOwner, int code )
	{
		CBaseEntity@ pentFind;
		edict_t@ pentOwner;

		if( pevOwner is null )
			return;

		CBaseEntity@ pOwner = g_EntityFuncs.Instance( pevOwner );
		@pentOwner = pOwner.edict();

		@pentFind = g_EntityFuncs.FindEntityByClassname( null, "biomass" );

		while( !FNullEnt( pentFind ) )
		{
			CBaseEntity@ pEnt = pentFind;
			if( pEnt !is null )
			{
				if( self.pev.FlagBitSet(SF_DETONATE) && pEnt.pev.owner is pentOwner )
				{
					if( code == BIOMASS_DETONATE )
						pEnt.Use( pOwner, pOwner, USE_ON, 0 );
					else	
						@pEnt.pev.owner = null;
				}
			}
			@pentFind = g_EntityFuncs.FindEntityByClassname( pentFind, "biomass" );
		}
	}
	
	private void te_explosion( Vector origin, string sprite, int scale, int frameRate, int flags )
	{
		NetworkMessage exp1(MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY);
			exp1.WriteByte( TE_EXPLOSION );
			exp1.WriteCoord( origin.x );
			exp1.WriteCoord( origin.y );
			exp1.WriteCoord( origin.z );
			exp1.WriteShort( g_EngineFuncs.ModelIndex(sprite) );
			exp1.WriteByte( int((scale-50) * .60) );
			exp1.WriteByte( frameRate );
			exp1.WriteByte( flags );
		exp1.End();
	}

	private void DynamicLight( Vector vecPos, int radius, int r, int g, int b, int8 life, int decay )
	{
		NetworkMessage dl( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			dl.WriteByte( TE_DLIGHT );
			dl.WriteCoord( vecPos.x );
			dl.WriteCoord( vecPos.y );
			dl.WriteCoord( vecPos.z );
			dl.WriteByte( radius );
			dl.WriteByte( int(r) );
			dl.WriteByte( int(g) );
			dl.WriteByte( int(b) );
			dl.WriteByte( life );
			dl.WriteByte( decay );
		dl.End();
	}
}

CBiomass@ ShootBiomass( entvars_t@ pevOwner, Vector vecStart, Vector vecVelocity, float Time )
{
	CBaseEntity@ cbeBiomass = g_EntityFuncs.CreateEntity( "biomass", null,  false);
	CBiomass@ pBiomass = cast<CBiomass@>(CastToScriptClass(cbeBiomass));
	g_EntityFuncs.SetOrigin( pBiomass.self, vecStart );
	g_EntityFuncs.DispatchSpawn( pBiomass.self.edict() );
	pBiomass.pev.velocity = vecVelocity + g_Engine.v_right * Math.RandomFloat(-50,50) + g_Engine.v_up * Math.RandomFloat(-50,50);
	@pBiomass.pev.owner = pevOwner.pContainingEntity;
	pBiomass.SetThink( ThinkFunction( pBiomass.StayInWorld ) );
	pBiomass.pev.nextthink = g_Engine.time + 0.1;
	pBiomass.SetUse( UseFunction( pBiomass.DetonateUse ) );
	pBiomass.SetTouch( TouchFunction( pBiomass.SlideTouch ) );
	pBiomass.pev.spawnflags = SF_DETONATE;
	pBiomass.pev.frags = Time;
	pBiomass.pev.dmg = BIORIFLE_DAMAGE;

	return pBiomass;
}

void RegisterBiomass()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "CBiomass", "biomass" );
}