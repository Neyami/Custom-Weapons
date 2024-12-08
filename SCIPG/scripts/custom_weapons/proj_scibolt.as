class CSciPGBolt : ScriptBaseEntity
{
	string m_iExplode = "sprites/custom_weapons/spinning_coin.spr";
	string g_sModelIndexFireball = "sprites/zerogxplode.spr";
	string g_sModelIndexWExplosion = "sprites/WXplo1.spr";

	void Spawn()
	{
		self.pev.movetype = MOVETYPE_FLY;
		self.pev.solid = SOLID_BBOX;

		self.pev.gravity = 0.5;

		g_EntityFuncs.SetModel( self, scipg::SCIPG_MODEL_BOLT );
		g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, scipg::SCIPG_SOUND_FLY, VOL_NORM, ATTN_NORM );

		g_EntityFuncs.SetOrigin( self, self.pev.origin );
		g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );

		SetTouch( TouchFunction( this.BoltTouch ) );
		SetThink( ThinkFunction( this.BubbleThink ) );
		self.pev.nextthink = g_Engine.time + 0.2;
	}

	int Classify ()
	{
		return CLASS_NONE;
	}

	void BoltTouch( CBaseEntity@ pOther )
	{
		SetTouch( null );
		SetThink( null );

		if( pOther.pev.takedamage != DAMAGE_NO )
		{
			TraceResult tr = g_Utility.GetGlobalTrace();
			entvars_t@ pevOwner = self.pev.owner.vars;

			// UNDONE: this needs to call TraceAttack instead
			g_WeaponFuncs.ClearMultiDamage();

			pOther.TraceAttack( pevOwner, scipg::SCIPG_DAMAGE, self.pev.velocity.Normalize(), tr, DMG_BULLET | DMG_ALWAYSGIB );

			g_WeaponFuncs.ApplyMultiDamage( self.pev, pevOwner );
			
			if( pOther.pev.targetname == "nero_boss01" )
				pOther.pev.health -= scipg::SCIPG_DAMAGE/3;

			self.pev.velocity = g_vecZero;

			g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, scipg::SCIPG_SOUND_FLY );
			SetThink( ThinkFunction( this.ExplodeThink ) );
			SprayTest( self.pev.origin, Vector(0,0,1), m_iExplode, 24 );
			g_EntityFuncs.Remove( self );
		}
		else
		{
			SetThink( ThinkFunction( this.SUB_Remove ) );
			SetThink( ThinkFunction( this.ExplodeThink ) );
			self.pev.nextthink = g_Engine.time;

			if( pOther.pev.ClassNameIs("worldspawn") )
			{
				g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, scipg::SCIPG_SOUND_FLY );
				SetThink( ThinkFunction( this.ExplodeThink ) );
				SprayTest( self.pev.origin, Vector(0,0,1), m_iExplode, 24 );
				SetThink( ThinkFunction( this.SUB_Remove ) );
			}

			if( g_EngineFuncs.PointContents( self.pev.origin ) != CONTENTS_WATER )
			{
				g_SoundSystem.StopSound( self.edict(), CHAN_VOICE, scipg::SCIPG_SOUND_FLY );
				SetThink( ThinkFunction( this.ExplodeThink ) );
				SprayTest( self.pev.origin, Vector(0,0,1), m_iExplode, 24 );
				g_EntityFuncs.Remove( self );
			}
		}
	}

	void SprayTest( const Vector& in position, const Vector& in direction, string spriteModel, int count )
	{
		int iSpeed;
		iSpeed = 130;
		
		g_SoundSystem.EmitSound( self.edict(), CHAN_VOICE, scipg::SCIPG_SOUND_EXPLODE, 1, ATTN_NORM );
		
		NetworkMessage coinexp( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			coinexp.WriteByte( TE_SPRITE_SPRAY );
			coinexp.WriteCoord( position.x );
			coinexp.WriteCoord( position.y );
			coinexp.WriteCoord( position.z );
			coinexp.WriteCoord( direction.x );
			coinexp.WriteCoord( direction.y );
			coinexp.WriteCoord( direction.z );
			coinexp.WriteShort( g_EngineFuncs.ModelIndex(spriteModel) );
			coinexp.WriteByte( count );
			coinexp.WriteByte( iSpeed );//speed
			coinexp.WriteByte( 80 );//noise ( client will divide by 100 )
		coinexp.End();
	}

	void BubbleThink()
	{
		self.pev.nextthink = g_Engine.time + 0.1;

		if( self.pev.waterlevel == WATERLEVEL_DRY )
			return;

		g_Utility.BubbleTrail( self.pev.origin - self.pev.velocity * 0.1, self.pev.origin, 20 );
	}

	void ExplodeThink()
	{
		int iContents = g_EngineFuncs.PointContents ( self.pev.origin );
		int iScale;
		
		self.pev.dmg = 40;
		iScale = 10;

		NetworkMessage exp1( MSG_PVS, NetworkMessages::SVC_TEMPENTITY );
			exp1.WriteByte( TE_EXPLOSION );
			exp1.WriteCoord( self.pev.origin.x );
			exp1.WriteCoord( self.pev.origin.y );
			exp1.WriteCoord( self.pev.origin.z );
			if( iContents != CONTENTS_WATER )
			{
				exp1.WriteShort( g_EngineFuncs.ModelIndex(g_sModelIndexFireball) );
			}
			else
			{
				exp1.WriteShort( g_EngineFuncs.ModelIndex(g_sModelIndexWExplosion) );
			}
			exp1.WriteByte( iScale );
			exp1.WriteByte( 15 ); //framerate
			exp1.WriteByte( TE_EXPLFLAG_NONE );
		exp1.End();

		entvars_t@ pevOwner;

		if( self.pev.owner !is null )
			@pevOwner = self.pev.owner.vars;
		else
			@pevOwner = null;

		@self.pev.owner = null; // can't traceline attack owner if this is set

		g_WeaponFuncs.RadiusDamage( self.pev.origin, self.pev, pevOwner, self.pev.dmg, 128, CLASS_PLAYER, DMG_BLAST | DMG_ALWAYSGIB );

		g_EntityFuncs.Remove( self );
	}
	
	void SUB_Remove()
	{
		self.SUB_Remove();
	}
}