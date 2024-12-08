namespace hlwe_biorifle
{

const int BR_SLOT						= 3;
const int BR_POSITION				= 10;
const int BIORIFLE_DAMAGE		= 60;
const int BIORIFLE_WEIGHT		= 36;
const int BR_MAX_CLIP				= 18;
const int BR_DEFAULT_GIVE		= BR_MAX_CLIP;
const int BR_MAX_CARRY				= 72;
const int BIOMASS_TIMER			= 1000;

const string MODEL_MAG				= "models/w_weaponbox.mdl";
const string MODEL_VIEW			= "models/custom_weapons/biorifle/v_biorifle.mdl";
const string MODEL_PLAYER		= "models/custom_weapons/biorifle/p_biorifle.mdl";
const string MODEL_WORLD		= "models/custom_weapons/biorifle/w_biorifle.mdl";
const string BR_SOUND_FIRE		= "custom_weapons/biorifle/biorifle_fire.wav";
const string BR_SOUND_DRY		= "custom_weapons/biorifle/biorifle_dryfire.wav";

const string BIOMASS_MODEL = "models/custom_weapons/biorifle/w_biomass.mdl";
const string BIOMASS_EXPLOSION1 = "sprites/explode1.spr";
const string BIOMASS_EXPLOSION2 = "sprites/spore_exp_01.spr";
const string BIOMASS_EXPLOSION3 = "sprites/spore_exp_c_01.spr";
const string BIOMASS_EXPLOSION_WATER = "sprites/WXplo1.spr";

const string BIOMASS_SOUND_HIT1 = "custom_weapons/biorifle/bustflesh1.wav";
const string BIOMASS_SOUND_HIT2 = "custom_weapons/biorifle/bustflesh2.wav";
const string BIOMASS_SOUND_EXPL = "custom_weapons/biorifle/biomass_exp.wav";

const int SF_DETONATE				= 0x0001;

enum biomasscode_e
{
	BIOMASS_DETONATE = 0,
	BIOMASS_RELEASE
};

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

class weapon_biorifle : ScriptBasePlayerWeaponEntity
{
	protected CBasePlayer@ m_pPlayer
	{
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}

	void Spawn()
	{
		Precache();

		g_EntityFuncs.SetModel( self, self.GetW_Model(MODEL_WORLD) );

		self.m_iDefaultAmmo = BR_DEFAULT_GIVE;
		self.m_flCustomDmg = pev.dmg;

		self.FallInit();
	}

	void Precache()
	{
		self.PrecacheCustomModels();
		g_Game.PrecacheModel( MODEL_VIEW );
		g_Game.PrecacheModel( MODEL_PLAYER );
		g_Game.PrecacheModel( MODEL_WORLD );
		
		g_Game.PrecacheGeneric( "sound/" + BR_SOUND_FIRE );
		g_Game.PrecacheGeneric( "sound/" + BR_SOUND_DRY );
		
		g_SoundSystem.PrecacheSound( BR_SOUND_FIRE );
		g_SoundSystem.PrecacheSound( BR_SOUND_DRY );

		g_Game.PrecacheModel( BIOMASS_EXPLOSION1 );
		g_Game.PrecacheModel( BIOMASS_EXPLOSION2 );
		g_Game.PrecacheModel( BIOMASS_EXPLOSION3 );
		g_Game.PrecacheModel( BIOMASS_EXPLOSION_WATER );
		g_Game.PrecacheModel( BIOMASS_MODEL );
		g_Game.PrecacheModel( MODEL_MAG );

		g_SoundSystem.PrecacheSound( BIOMASS_SOUND_HIT1 );
		g_SoundSystem.PrecacheSound( BIOMASS_SOUND_HIT2 );
		g_SoundSystem.PrecacheSound( BIOMASS_SOUND_EXPL );
		g_Game.PrecacheGeneric( "sound/" + BIOMASS_SOUND_HIT1 );
		g_Game.PrecacheGeneric( "sound/" + BIOMASS_SOUND_HIT2 );
		g_Game.PrecacheGeneric( "sound/" + BIOMASS_SOUND_EXPL );

		//Precache these for downloading
		g_Game.PrecacheGeneric( "sprites/custom_weapons/biorifle.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/biorifle_crosshairs.spr" );
		g_Game.PrecacheGeneric( "sprites/custom_weapons/superweapons/weapon_biorifle.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1 	= BR_MAX_CARRY;
		info.iMaxClip 	= BR_MAX_CLIP;
		info.iSlot 		= BR_SLOT-1;
		info.iPosition 	= BR_POSITION-1;
		info.iFlags 	= ITEM_FLAG_SELECTONEMPTY | ITEM_FLAG_NOAUTORELOAD;
		info.iWeight 	= BIORIFLE_WEIGHT;

		return true;
	}
	
	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer(pPlayer) )
			return false;

		@m_pPlayer = pPlayer;

		NetworkMessage biorifle( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			biorifle.WriteLong( self.m_iId );
		biorifle.End();

		return true;
	}

	bool PlayEmptySound()
	{
		if( self.m_bPlayEmptySound )
		{
			self.m_bPlayEmptySound = false;
			
			g_SoundSystem.EmitSound( m_pPlayer.edict(), CHAN_WEAPON, BR_SOUND_DRY, 0.8, ATTN_NORM );
		}
		
		return false;
	}

	bool Deploy()
	{
		bool bResult;
		{
			bResult = self.DefaultDeploy( self.GetV_Model(MODEL_VIEW), self.GetP_Model(MODEL_PLAYER), BIORIFLE_DRAW, "gauss" );
			self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = self.m_flNextSecondaryAttack = g_Engine.time + 1.0;

			return bResult;
		}
	}

	void PrimaryAttack()
	{
		if( self.m_iClip <= 0 )
		{
			self.PlayEmptySound();
			self.m_flNextPrimaryAttack = g_Engine.time + 0.15;
			return;
		}

		--self.m_iClip;
		//++m_iFiredAmmo; //Used for dropping clip on the ground when out of ammo. Might be implemented in the future.
		m_pPlayer.SetAnimation( PLAYER_ATTACK1 );
		self.SendWeaponAnim( BIORIFLE_FIRE );

		Math.MakeVectors( m_pPlayer.pev.v_angle + m_pPlayer.pev.punchangle );
		ShootBiomass( m_pPlayer.pev.origin + m_pPlayer.pev.view_ofs + g_Engine.v_forward * 16 + g_Engine.v_right * 7 + g_Engine.v_up * -8, g_Engine.v_forward * 3000, BIOMASS_TIMER );
		g_SoundSystem.EmitSoundDyn( m_pPlayer.edict(), CHAN_WEAPON, BR_SOUND_FIRE, 1, ATTN_NORM, 0, 94 + Math.RandomLong( 0, 0xF ) );

		if( self.m_iClip == 0 && m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType ) <= 0 )
			m_pPlayer.SetSuitUpdate( "!HEV_AMO0", false, 0 );

		self.m_flNextPrimaryAttack = g_Engine.time + 0.3;
		self.m_flNextSecondaryAttack = g_Engine.time + 0.1;
		self.m_flTimeWeaponIdle = g_Engine.time + 2;
		
		m_pPlayer.pev.punchangle.x -= Math.RandomFloat( -2, 5 );
		m_pPlayer.pev.punchangle.y -= 1;
	}

	void SecondaryAttack()
	{
		CBaseEntity@ pBioCharge = null;

		while( ( @pBioCharge = g_EntityFuncs.FindEntityInSphere( pBioCharge, m_pPlayer.pev.origin, 16384, "biomass", "classname" ) ) !is null )
		{
			if( pBioCharge.pev.owner is m_pPlayer.edict() )
				pBioCharge.Use( m_pPlayer, m_pPlayer, USE_ON, 0 );
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
		switch( Math.RandomLong(0, 2) )
		{
			case 0: iAnim = BIORIFLE_IDLE2; break;
			case 1: iAnim = BIORIFLE_IDLE3; break;
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

		while( pFind !is null )
		{
			//CBaseEntity@ pEnt = CBaseEntity::Instance( pFind );
			CBaseEntity@ pEnt = pFind;
			//biomass@ pBioCharge = (biomass *)pEnt;
			biomass@ pBiocharge = cast<biomass@>(pEnt);

			if( pBioCharge !is null )
			{
				if( pBioCharge.pev.owner is pOwner.edict() )
					pBioCharge.Deactivate();
			}
			pFind = g_EntityFuncs.FindEntityByClassname( pFind, "biomass" );
		}
	}
*/
	void ShootBiomass( Vector vecStart, Vector vecVelocity, float flTime )
	{
		CBaseEntity@ pBiomass = g_EntityFuncs.Create( "biomass", vecStart, g_vecZero, true, m_pPlayer.edict() );

		pBiomass.pev.velocity = vecVelocity + g_Engine.v_right * Math.RandomFloat(-50, 50) + g_Engine.v_up * Math.RandomFloat(-50, 50);
		pBiomass.pev.spawnflags = SF_DETONATE;
		pBiomass.pev.frags = flTime;

		if( self.m_flCustomDmg > 0 )
			pBiomass.pev.dmg = self.m_flCustomDmg;
		else
			pBiomass.pev.dmg = BIORIFLE_DAMAGE;

		g_EntityFuncs.DispatchSpawn( pBiomass.edict() );
	}
}

class biomass : ScriptBaseMonsterEntity
{
    protected CBasePlayer@ m_pOwner
    {
        get { return cast<CBasePlayer@>( g_EntityFuncs.Instance(pev.owner) ); }
    }

	Vector dist;
	float angl_y, angl_x;
	bool b_attached;
	
	void Spawn()
	{
		g_EntityFuncs.SetModel( self, BIOMASS_MODEL );
		g_EntityFuncs.SetSize( self.pev, g_vecZero, g_vecZero );
		g_EntityFuncs.SetOrigin( self, pev.origin );

		self.ResetSequenceInfo();

		pev.movetype = MOVETYPE_BOUNCE;
		pev.solid = SOLID_BBOX;
		pev.rendermode = kRenderTransTexture;
		pev.renderamt = 150;
		pev.scale = 1.5;
		@pev.enemy = null;

		dist = g_vecZero;
		angl_x = angl_y = 0;
		b_attached = false;

		SetUse( UseFunction(this.DetonateUse) );
		SetTouch( TouchFunction(this.SlideTouch) );
		SetThink( ThinkFunction(this.StayInWorld) );
		pev.nextthink = g_Engine.time + 0.1;
	}

	void Killed( entvars_t@ pevAttacker, int iGib )
	{
		g_EntityFuncs.Remove( self );
	}

	int Classify()
	{
		return CLASS_PLAYER_BIOWEAPON;
	}
	
	void Detonate()
	{
		TraceResult tr;
		Vector vecEnd = pev.origin + pev.angles + g_Engine.v_forward*20;
		g_Utility.TraceLine( pev.origin, vecEnd, ignore_monsters, self.edict(), tr );
		g_Utility.DecalTrace( tr, DECAL_OFSCORCH1 + Math.RandomLong( 0,2 ) );

		g_WeaponFuncs.RadiusDamage( pev.origin, self.pev, m_pOwner.pev, pev.dmg, pev.dmg*3, CLASS_NONE, DMG_BLAST );

		if( g_EngineFuncs.PointContents( pev.origin ) == CONTENTS_WATER )
		{
			te_explosion( pev.origin, BIOMASS_EXPLOSION_WATER, BIORIFLE_DAMAGE*1.2, 15, (TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND) );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, BIOMASS_SOUND_EXPL, 0.5, 0.5, 0, 200 );
			DynamicLight( pev.origin, 12, 170, 250, 0, 1, 20 );
			g_Utility.Bubbles( pev.origin + Vector(0.2,0.2,0.5), pev.origin - Vector(0.2,0.2,0.5), 30 );
		}
		else
		{
			te_explosion( pev.origin, BIOMASS_EXPLOSION1, BIORIFLE_DAMAGE*1.2, 15, (TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND) );
			te_explosion( pev.origin, BIOMASS_EXPLOSION2, BIORIFLE_DAMAGE*1.2, 15, (TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND) );
			te_explosion( pev.origin, BIOMASS_EXPLOSION3, BIORIFLE_DAMAGE*1.3, 15, (TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND) );
			g_SoundSystem.EmitSoundDyn( self.edict(), CHAN_VOICE, BIOMASS_SOUND_EXPL, 0.5, 0.5, 0, PITCH_NORM );
			DynamicLight( pev.origin, 20, 170, 250, 0, 1, 50 );
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
		if( g_EngineFuncs.PointContents( pev.origin ) == CONTENTS_SKY )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		if( pOther.pev.takedamage == 1 && self.m_flNextAttack < g_Engine.time )
		{
			switch( Math.RandomLong( 0,1 ) )
			{
				case 0:	pOther.TakeDamage( self.pev, m_pOwner.pev, 1, DMG_POISON ); break;
				case 1:	pOther.TakeDamage( self.pev, m_pOwner.pev, 1, DMG_ACID ); break;
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

		pev.velocity = pev.velocity * 0.3;

		if( !b_attached && pev.waterlevel == WATERLEVEL_DRY )
		{
			b_attached = true;
			pev.velocity = pev.avelocity = g_vecZero;
			pev.movetype = MOVETYPE_FLY;
			pev.solid = SOLID_NOT;
			@pev.enemy = pOther.edict();
			dist = pev.origin - pOther.pev.origin;

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
		pev.nextthink = g_Engine.time + 0.01;

		if( !self.IsInWorld() )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		pev.frags--;
		if( pev.frags <= 0 )
		{
			Detonate();
			return;
		}

		self.StudioFrameAdvance();

		if( pev.enemy !is null )
		{
			CBaseEntity@ owner = g_EntityFuncs.Instance( pev.enemy );

			if( owner is null )
			{
				b_attached = false;
				@pev.enemy = null;
				pev.movetype = MOVETYPE_TOSS;
				pev.solid = SOLID_BBOX;
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
			pev.velocity = (owner.pev.origin + offset - pev.origin)/Math.max(0.05, g_Engine.frametime);
			return;
		}
		else if( b_attached )
		{
			b_attached = false;
			@pev.enemy = null;
			pev.movetype = MOVETYPE_TOSS;
			pev.solid = SOLID_BBOX;
			return;
		}

		if( pev.waterlevel == WATERLEVEL_HEAD)
		{
			b_attached = false;
			@pev.enemy = null;
			pev.movetype = MOVETYPE_TOSS;
			pev.solid = SOLID_BBOX;
		}
		else if( pev.waterlevel == WATERLEVEL_DRY )
			pev.movetype = MOVETYPE_BOUNCE;
		else
			pev.velocity.z -= 8;
	}

	//unused??
	/*void UseBiomass( entvars_t@ pevOwner, int code )
	{
		CBaseEntity@ pentFind;
		edict_t@ pentOwner;

		if( pevOwner is null )
			return;

		CBaseEntity@ pOwner = g_EntityFuncs.Instance( pevOwner );
		@pentOwner = pOwner.edict();

		@pentFind = g_EntityFuncs.FindEntityByClassname( null, "biomass" );

		while( pentFind !is null )
		{
			CBaseEntity@ pEnt = pentFind;
			if( pEnt !is null )
			{
				if( pev.FlagBitSet(SF_DETONATE) && pEnt.pev.owner is pentOwner )
				{
					if( code == BIOMASS_DETONATE )
						pEnt.Use( pOwner, pOwner, USE_ON, 0 );
					else	
						@pEnt.pev.owner = null;
				}
			}
			@pentFind = g_EntityFuncs.FindEntityByClassname( pentFind, "biomass" );
		}
	}*/

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

class ammo_biocharge : ScriptBasePlayerAmmoEntity
{
	void Spawn()
	{ 
		g_EntityFuncs.SetModel( self, MODEL_MAG );
		BaseClass.Spawn();
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
	g_CustomEntityFuncs.RegisterCustomEntity( "hlwe_biorifle::ammo_biocharge", "ammo_biocharge" );
	g_CustomEntityFuncs.RegisterCustomEntity( "hlwe_biorifle::biomass", "biomass" );
	g_CustomEntityFuncs.RegisterCustomEntity( "hlwe_biorifle::weapon_biorifle", "weapon_biorifle" );
	g_ItemRegistry.RegisterWeapon( "weapon_biorifle", "custom_weapons/superweapons", "biocharge" );
}

} //namespace hlwe_biorifle END