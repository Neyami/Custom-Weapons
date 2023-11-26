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

const int SF_DETONATE = 0x0001;
const float ATTN_LOW_HIGH = 0.5;
const float BM_EXPLOSION_VOLUME = 0.5;

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

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "biorifle::CWeaponBiorifle", "weapon_biorifle" );
	g_CustomEntityFuncs.RegisterCustomEntity( "biorifle::BRAmmoBox", "ammo_biocharge" );
	g_CustomEntityFuncs.RegisterCustomEntity( "biorifle::CBiomass", "biomass" );
	g_ItemRegistry.RegisterWeapon( "weapon_biorifle", "custom_weapons", "biocharge" );
}

} //namespace biorifle END
