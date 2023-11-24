namespace apacheweapon
{

const int APACHE_MAXBULLETS				= 100;
const int APACHE_MAXROCKETS				= 10;
const int APACHE_DEFAULT_AMMO			= 100;
const int APACHE_SLOT					= 1;
const int APACHE_POSITION				= 16;
const int APACHE_WEIGHT					= 0; //don't want to start the map with this deployed :D

const string APACHE_MODEL				= "models/apachef.mdl";
const float APACHE_SCALE				= 0.07f;
const string APACHE_WORLDMODEL			= "models/w_weaponbox.mdl";
const float APACHE_WORLDMODEL_SCALE		= 1.0f;
const int APACHE_SEQUENCE				= 0;
const int APACHE_FRAMERATE				= 10.0f;

const float APACHE_HEALTH				= 1000;
const float APACHE_MAXSPEED				= 400;
const float APACHE_ROCKETSPEED			= 1000;
const float APACHE_HEIGHT				= 20;
const float APACHE_DISTANCE				= 70;

const float APACHE_DELAY_GUN			= 0.1f;
const float APACHE_DELAY_ROCKETS		= 0.5f;
const float APACHE_DELAY_DEATH			= 2.5f;
const float APACHE_DAMAGE_GUN			= 10;
const float APACHE_DAMAGE_ROCKET		= 150; //200 causes the explosion to be too large
const float APACHE_DAMAGE_BOMB			= 150; //200
const float APACHE_RELOAD_GUN			= 2.0f;
const float APACHE_RELOAD_ROCKETS		= 2.0f;

const float APACHE_STEALTH_MAXSPEED		= 60;
const float APACHE_STEALTH_COOLDOWN		= 10.0f;
const int APACHE_STEALTH_AMOUNT			= 40; //amount of transparency
const int APACHE_STEALTH_BRIGHTNESS		= 64;
const Vector APACHE_STEALTH_COLOR		= Vector(240, 180, 0);
const float APACHE_STEALTH_DMGMUL		= 0.6f; //60% rocket and bomb damage when in stealth

const string APACHE_BOMB_MODEL			= "models/rpgrocket.mdl";
const float APACHE_BOMB_COOLDOWN		= 4.0f;

const float APACHE_REPAIR_DELAY			= 1.3f;
const float APACHE_REPAIR_AMOUNT		= 50;
const string APACHE_REPAIR_SOUND		= "tfc/weapons/turrset.wav";

class weapon_apache : ScriptBasePlayerWeaponEntity
{
	private CBasePlayer@ m_pPlayer = null;
	private CBaseAnimating@ apache = null;
	private CBaseEntity@ camera = null;
	private int laserbeam = 0, smoke = 0;
	private float g_flStealthRegen, g_flDefaultMaxSpeed, g_flApacheSpeed, g_flReloadGun, g_flReloadRockets, g_flReloadBomb, g_flRepair;
	private bool bStealth = false;
	private HUDTextParams textParams;
	private int m_iSpriteTexture = 0;
	private int m_iExplode = 0;
	private int g_sModelIndexSmoke = 0;
	private int m_iRepair = 0;
	private float side = 1.0f;
	private int g_iAmmo, g_iRockets;
	private bool bBeams = false; //display a beam from the apache
	private bool bDebug = false; //camera won't be attached and the apache won't respond to player's movement + infinite ammo
	private bool bInvisiblePlayer = true;
	private bool bDropPlayer = false; //drop player off (teleport) to where the helicopter is when holstering?
	private bool bTransportPlayer = false; //move player with the Apache?

	void Spawn()
	{
		self.Precache();
		g_EntityFuncs.SetModel( self, APACHE_WORLDMODEL );
		self.pev.scale = APACHE_WORLDMODEL_SCALE;
		self.m_iDefaultAmmo = APACHE_DEFAULT_AMMO;
		self.FallInit();
		SetTextParams(); //for the HUD
		side = 1.0f;
		g_iAmmo = APACHE_MAXBULLETS;
		g_iRockets = APACHE_MAXROCKETS;
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		laserbeam = g_Game.PrecacheModel( "sprites/laserbeam.spr" );
		smoke = g_Game.PrecacheModel( "sprites/smoke.spr" );

		m_iSpriteTexture = g_Game.PrecacheModel( "sprites/white.spr" );
		m_iExplode	= g_Game.PrecacheModel( "sprites/fexplo.spr" );
		g_sModelIndexSmoke = g_Game.PrecacheModel( "sprites/steam1.spr" );

		m_iRepair = g_Game.PrecacheModel( "sprites/saveme.spr" );

		g_Game.PrecacheModel( APACHE_WORLDMODEL );
		g_Game.PrecacheModel( APACHE_MODEL );
		g_Game.PrecacheModel( "models/rpgrocket.mdl" );
		g_Game.PrecacheModel( APACHE_BOMB_MODEL );

		//g_SoundSystem.PrecacheSound( "vox/_period.wav" ); //if StopSound doesn't work
		g_SoundSystem.PrecacheSound( "weapons/gl_reload.wav" );
		g_SoundSystem.PrecacheSound( "weapons/mortarhit.wav" );
		g_SoundSystem.PrecacheSound( "turret/tu_fire1.wav" );
		g_SoundSystem.PrecacheSound( "apache/ap_rotor2.wav" );
		g_SoundSystem.PrecacheSound( APACHE_REPAIR_SOUND );

		g_Game.PrecacheOther( "hvr_rocket" );

		//Precache these for downloading
		g_Game.PrecacheGeneric( "sprites/custom_weapons/weapon_apache.txt" );
	}

	bool GetItemInfo( ItemInfo& out info )
	{
		info.iMaxAmmo1		= APACHE_MAXBULLETS;
		info.iMaxAmmo2		= APACHE_MAXROCKETS;
		info.iMaxClip		= APACHE_MAXBULLETS;
		info.iSlot			= APACHE_SLOT - 1;
		info.iPosition		= APACHE_POSITION - 1;
		info.iFlags 		= ITEM_FLAG_SELECTONEMPTY; //to prevent apache from being despawned if both bullets AND rockets are out at the same time
		info.iWeight		= APACHE_WEIGHT;

		return true;
	}

	bool AddToPlayer( CBasePlayer@ pPlayer )
	{
		if( !BaseClass.AddToPlayer(pPlayer) )
			return false;

		@m_pPlayer = pPlayer;

		NetworkMessage apache( MSG_ONE, NetworkMessages::WeapPickup, pPlayer.edict() );
			apache.WriteLong( g_ItemRegistry.GetIdForName("weapon_apache") );
		apache.End();

		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, APACHE_MAXROCKETS );

		return true;
	}

	bool Deploy()
	{
		return self.DefaultDeploy( "", "", 0, "" );
	}

	bool CanHolster() //to prevent apache from being despawned if both bullets AND rockets are out at the same time
	{
		if( g_iAmmo <= 0 and g_iRockets <= 0 )
			return false;

		return true;
	}

	void Holster( int skipLocal = 0 )
	{
		Vector vecApacheOrigin;

		if( apache !is null )
		{
			vecApacheOrigin = apache.pev.origin;
			destroy_apache();
		}

		ResetPlayer();

		if( bDropPlayer )
		{
			m_pPlayer.pev.origin = vecApacheOrigin;
		}

		BaseClass.Holster( skipLocal );
	}

	void PrimaryAttack()
	{
		if( apache !is null )
		{
			if( g_iAmmo <= 0 )
				return;

			Math.MakeAimVectors( apache.pev.angles );
			Vector vecSrc = apache.pev.origin + g_Engine.v_forward * -32 + g_Engine.v_up * -7;

			apache.FireBullets( 1, vecSrc, g_Engine.v_forward, VECTOR_CONE_4DEGREES, 8192, BULLET_MONSTER_12MM, APACHE_DAMAGE_GUN );
			g_SoundSystem.EmitSound( apache.edict(), CHAN_WEAPON, "turret/tu_fire1.wav", 1, 0.3f );

			if( !bDebug )
			{
				--g_iAmmo;
				self.m_iClip = g_iAmmo;
			}
		}
		else spawn_apache();

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = g_Engine.time + APACHE_DELAY_GUN;
	}

	void SecondaryAttack()
	{
		if( apache !is null )
		{
			if( g_iRockets <= 0 )
				return;

			Math.MakeAimVectors( apache.pev.angles );
			Vector vecSrc = apache.pev.origin + g_Engine.v_forward * -4 + g_Engine.v_right * 6.5f * side + g_Engine.v_up * -7;

			NetworkMessage m( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecSrc );
				m.WriteByte( TE_SMOKE );
				m.WriteCoord( vecSrc.x );
				m.WriteCoord( vecSrc.y );
				m.WriteCoord( vecSrc.z - 7 );
				m.WriteShort( g_sModelIndexSmoke );
				m.WriteByte( 2 ); // scale * 10
				m.WriteByte( 12 ); // framerate
			m.End();

			//CBaseEntity@ pRocket = g_EntityFuncs.Create( "hvr_rocket", vecSrc, apache.pev.angles, false );
			CBaseEntity@ pRocket = g_EntityFuncs.Create( "hvr_rocket", vecSrc, apache.pev.angles, false, m_pPlayer.pev.pContainingEntity );

			if( pRocket !is null )
			{
				//@pRocket.pev.owner = m_pPlayer.pev.pContainingEntity;
				pRocket.pev.dmg = bStealth ? (APACHE_DAMAGE_ROCKET * APACHE_STEALTH_DMGMUL) : APACHE_DAMAGE_ROCKET;
				pRocket.pev.scale = 0.3f;
				pRocket.pev.velocity = apache.pev.velocity + g_Engine.v_forward * APACHE_ROCKETSPEED;

				// the original trail is too thicc
				NetworkMessage killbeam( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null );
					killbeam.WriteByte(TE_KILLBEAM);
					killbeam.WriteShort(pRocket.entindex());
				killbeam.End();

				NetworkMessage trail( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					trail.WriteByte( TE_BEAMFOLLOW );
					trail.WriteShort( pRocket.entindex() );
					trail.WriteShort( smoke );
					trail.WriteByte( 15 ); // life
					trail.WriteByte( 2 );  // width
					trail.WriteByte( 224 );   // r, g, b
					trail.WriteByte( 224 );   // r, g, b
					trail.WriteByte( 255 );   // r, g, b
					trail.WriteByte( 255 );	// brightness
				trail.End();
			}

			if( !bDebug )
			{
				--g_iRockets;
				m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, g_iRockets );
			}

			side = -side;
		}

		self.m_flTimeWeaponIdle = self.m_flNextSecondaryAttack = g_Engine.time + APACHE_DELAY_ROCKETS;
	}

	void TertiaryAttack()
	{
		if( apache !is null )
		{
			if( g_flStealthRegen <= 0 )
			{
				if( !bStealth )
				{
					bStealth = true;
					g_SoundSystem.EmitSoundDyn( apache.edict(), CHAN_VOICE, "apache/ap_rotor2.wav", 0.1f, ATTN_NORM, 0, PITCH_NORM );
					apache.pev.renderfx = kRenderFxGlowShell;
					apache.pev.rendercolor = Vector(0, 0, 0);
					apache.pev.rendermode = kRenderTransAlpha;
					apache.pev.renderamt = APACHE_STEALTH_AMOUNT;

					g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance(m_pPlayer.pev), APACHE_STEALTH_COLOR, 0.01f, 0.5f, APACHE_STEALTH_BRIGHTNESS, (FFADE_OUT | FFADE_STAYOUT) );
				}
				else
				{
					bStealth = false;
					g_SoundSystem.EmitSoundDyn( apache.edict(), CHAN_VOICE, "apache/ap_rotor2.wav", 0.8f, ATTN_NORM, 0, PITCH_NORM );

					apache.pev.renderfx = 0;
					apache.pev.rendercolor = Vector(0, 0, 0);
					apache.pev.rendermode = 0;
					apache.pev.renderamt = 0;

					g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance(m_pPlayer.pev), APACHE_STEALTH_COLOR, 0.01f, 0.5f, APACHE_STEALTH_BRIGHTNESS, FFADE_IN );

					g_flStealthRegen = g_Engine.time + APACHE_STEALTH_COOLDOWN;
				}
			}
			else
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "Stealth cooldown: " + (g_flStealthRegen - g_Engine.time) + " second(s).\n" );
		}

		self.m_flTimeWeaponIdle = self.m_flNextTertiaryAttack = g_Engine.time + 0.5f;
	}

	void Reload()
	{
		if( apache !is null )
		{
			if( g_flReloadBomb <= 0 )
			{
				CBaseEntity@ pBomb = g_EntityFuncs.ShootContact( m_pPlayer.pev, apache.pev.origin + Vector(0, 0, -16), g_vecZero );

				if( pBomb !is null )
				{
					g_EntityFuncs.SetModel( pBomb, APACHE_BOMB_MODEL );
					//g_EntityFuncs.SetSize( pBomb.pev, Vector(-1.0f, -1.0f, -1.0f), Vector(1.0f, 1.0f, 1.0f) );
					//pBomb.pev.solid = SOLID_TRIGGER;
					//pBomb.pev.movetype = MOVETYPE_TOSS;
					@pBomb.pev.owner = m_pPlayer.pev.pContainingEntity;
					pBomb.pev.dmg = bStealth ? (APACHE_DAMAGE_BOMB * APACHE_STEALTH_DMGMUL): APACHE_DAMAGE_BOMB;
				}

				g_flReloadBomb = g_Engine.time + APACHE_BOMB_COOLDOWN;
			}
			else
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "Bomb cooldown: " + (g_flReloadBomb - g_Engine.time) + " second(s).\n" );
		}
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.m_flTimeWeaponIdle = g_Engine.time + 1.0f;
	}

	void ItemPreFrame()
	{
		if( m_pPlayer.IsAlive() and apache !is null and camera !is null )
		{
			if( (m_pPlayer.pev.flags & FL_GODMODE) != 1 )
			{
				m_pPlayer.pev.flags |= FL_GODMODE;
				m_pPlayer.pev.takedamage = DAMAGE_NO;
			}

			if( bInvisiblePlayer and m_pPlayer.pev.flags & (EF_NODRAW|FL_NOTARGET) != 1 )
			{
				m_pPlayer.pev.solid = SOLID_NOT;
				m_pPlayer.pev.movetype = MOVETYPE_NOCLIP;
				m_pPlayer.pev.flags |= FL_NOTARGET;
				m_pPlayer.pev.effects |= EF_NODRAW;
			}

			Vector forigin, dist_origin, camera_origin;
			int button;
			float maxspeed, frame;
			Vector angles, velocity;
			Vector aim_origin, end_origin;

			if( apache.pev.health < 5000 )
			{
				Vector vecSpot = apache.pev.origin + (apache.pev.mins + apache.pev.maxs) * 0.5f;

				// fireball
				NetworkMessage m1( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecSpot );
					m1.WriteByte( TE_SPRITE );
					m1.WriteCoord( vecSpot.x );
					m1.WriteCoord( vecSpot.y );
					m1.WriteCoord( vecSpot.z + 25 );
					m1.WriteShort( m_iExplode );
					m1.WriteByte( 12 ); // scale * 10
					m1.WriteByte( 255 ); // brightness
				m1.End();

				// big smoke
				NetworkMessage m2( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecSpot );
					m2.WriteByte( TE_SMOKE );
					m2.WriteCoord( vecSpot.x );
					m2.WriteCoord( vecSpot.y );
					m2.WriteCoord( vecSpot.z );
					m2.WriteShort( g_sModelIndexSmoke );
					m2.WriteByte( 25 ); // scale * 10
					m2.WriteByte( 5 ); // framerate
				m2.End();

				// blast circle
				NetworkMessage m3( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, apache.pev.origin );
					m3.WriteByte( TE_BEAMCYLINDER );
					m3.WriteCoord( apache.pev.origin.x );
					m3.WriteCoord( apache.pev.origin.y );
					m3.WriteCoord( apache.pev.origin.z );
					m3.WriteCoord( apache.pev.origin.x );
					m3.WriteCoord( apache.pev.origin.y );
					m3.WriteCoord( apache.pev.origin.z + 200 ); // reach damage radius over .2 seconds
					m3.WriteShort( m_iSpriteTexture );
					m3.WriteByte( 0 ); // startframe
					m3.WriteByte( 0 ); // framerate
					m3.WriteByte( 4 ); // life
					m3.WriteByte( 16 );  // width
					m3.WriteByte( 0 );   // noise
					m3.WriteByte( 255 );   // r, g, b
					m3.WriteByte( 255 );   // r, g, b
					m3.WriteByte( 192 );   // r, g, b
					m3.WriteByte( 128 ); // brightness
					m3.WriteByte( 0 );		// speed
				m3.End();

				g_SoundSystem.EmitSoundDyn( apache.edict(), CHAN_STATIC, "weapons/mortarhit.wav", 1.0f, 0.3f, 0, PITCH_HIGH );

				g_WeaponFuncs.RadiusDamage( apache.pev.origin, apache.pev, apache.pev, 50, 300, CLASS_NONE, DMG_BLAST ); 

				destroy_apache();
				ResetPlayer();
				self.m_flNextPrimaryAttack = g_Engine.time + APACHE_DELAY_DEATH;
			}

			if( apache is null )
			{
				BaseClass.ItemPreFrame();
				return;
			}

			frame = apache.pev.frame;
			if( frame < 0.0f || frame > 254.0f )
				apache.pev.frame = 0.0f;
			else
				apache.pev.frame = frame + APACHE_FRAMERATE;

			button = m_pPlayer.pev.button;
			if( (button & IN_FORWARD) != 0 )
				g_flApacheSpeed += 5;

			if( (button & IN_BACK) != 0 )
				g_flApacheSpeed -= 5;

			if( (button & IN_USE) != 0 ) //stop_apache
			{
				// slow down to a complete stop
				if( g_flApacheSpeed > 0 )
					g_flApacheSpeed -= 5;
				else if( g_flApacheSpeed < 0 )
					g_flApacheSpeed += 5;

				// instantly stop if speed is low enough
				//if( g_flApacheSpeed <= 30 && g_flApacheSpeed >= -30 )
				//	g_flApacheSpeed = 0;
			}

			if( !bStealth )
				maxspeed = APACHE_MAXSPEED;
			else
				maxspeed = APACHE_STEALTH_MAXSPEED;

			if( g_flApacheSpeed > maxspeed )
				g_flApacheSpeed = maxspeed;

			if( g_flApacheSpeed < -80 )
				g_flApacheSpeed = -80;

			forigin = apache.pev.origin;
			angles = m_pPlayer.pev.v_angle;
			angles.x = -angles.x;
			VelocityByAim( EHandle(m_pPlayer), g_flApacheSpeed, velocity );

			if( !bDebug ) apache.pev.angles = angles;

			apache.pev.velocity = velocity;

			if( !bDebug )
			{
				if( (button & IN_JUMP) != 0 )
				{
					forigin.z += 2.0f;
					if( g_EngineFuncs.PointContents(forigin) != CONTENTS_SOLID )
						apache.pev.origin = forigin;

					//apache.pev.velocity.z += 200.0f;
				}

				if( (button & IN_DUCK) != 0 )
				{
					forigin.z -= 2.0f;
					if( g_EngineFuncs.PointContents(forigin) != CONTENTS_SOLID )
						apache.pev.origin = forigin;

					//apache.pev.velocity.z -= 200.0f;
				}
			}

			if( g_EngineFuncs.PointContents(forigin) == CONTENTS_SOLID )
			{
				forigin.z += 10.0f;
				if( g_EngineFuncs.PointContents(forigin) == CONTENTS_SOLID )
					forigin.z -= 60.0f;

				apache.pev.origin = forigin;
			}

			VelocityByAim( EHandle(m_pPlayer), APACHE_DISTANCE, dist_origin );
			camera_origin.x = forigin.x - dist_origin.x;
			camera_origin.y = forigin.y - dist_origin.y;
			camera_origin.z = forigin.z + APACHE_HEIGHT;
			camera.pev.origin = camera_origin;
			angles.x = -angles.x;
			camera.pev.angles = angles;

			if( !bDebug )
			{
				if( (button & IN_MOVELEFT) != 0 )
				{
					VelocityByAim( EHandle(m_pPlayer), g_flApacheSpeed, velocity, g_flApacheSpeed > 0 ? -1 : 1 );
					apache.pev.velocity = velocity;
				}

				if( (button & IN_MOVERIGHT) != 0 )
				{
					VelocityByAim( EHandle(m_pPlayer), g_flApacheSpeed, velocity, g_flApacheSpeed > 0 ? 1 : -1 );
					apache.pev.velocity = velocity;
				}
			}
			else apache.pev.velocity = g_vecZero;

			if( bTransportPlayer ) m_pPlayer.pev.origin = apache.pev.origin;

			if(bBeams)
			{
				VelocityByAim( EHandle(m_pPlayer), 9999, velocity );
				end_origin = forigin + velocity;

				TraceResult tr;
				g_Utility.TraceLine( forigin, end_origin, dont_ignore_monsters, apache.edict(), tr );

				NetworkMessage beammsg( MSG_ONE_UNRELIABLE, NetworkMessages::SVC_TEMPENTITY, g_vecZero, m_pPlayer.edict() );
					beammsg.WriteByte(TE_BEAMENTPOINT);
					beammsg.WriteShort(apache.entindex());
					beammsg.WriteCoord(tr.vecEndPos.x);
					beammsg.WriteCoord(tr.vecEndPos.y);
					beammsg.WriteCoord(tr.vecEndPos.z);
					beammsg.WriteShort(laserbeam);
					beammsg.WriteByte(1); //starting frame
					beammsg.WriteByte(1); //framerate
					beammsg.WriteByte(1); //life
					beammsg.WriteByte(8); //line width
					beammsg.WriteByte(0); //noise amplitude
					beammsg.WriteByte(255); //color
					beammsg.WriteByte(0);
					beammsg.WriteByte(0);
					beammsg.WriteByte(128); //brightness
					beammsg.WriteByte(0); //scroll speed
				beammsg.End();
			}

			//g_PlayerFuncs.HudMessage( m_pPlayer, textParams, " [APACHE] Speed: " + g_flApacheSpeed + ", Health: " + string(int(Math.Floor(apache.pev.health + 0.5f)) - 5000) + ", Velocity: " + apache.pev.velocity.ToString() + "\n" );
			g_PlayerFuncs.HudMessage( m_pPlayer, textParams, " [APACHE] Speed: " + g_flApacheSpeed + ", Health: " + string(int(Math.Floor(apache.pev.health + 0.5f)) - 5000) + "\n" );

			if( g_iAmmo <= 0 and g_flReloadGun <= 0 )
			{
				g_SoundSystem.EmitSound( apache.edict(), CHAN_WEAPON, "weapons/gl_reload.wav", 1, 0.3f );
				g_flReloadGun = g_Engine.time + APACHE_RELOAD_GUN;
				self.m_flNextPrimaryAttack = g_Engine.time + APACHE_RELOAD_GUN;
			}

			if( g_iRockets <= 0 and g_flReloadRockets <= 0 )
			{
				g_SoundSystem.EmitSound( apache.edict(), CHAN_WEAPON, "weapons/gl_reload.wav", 1, 0.3f );
				g_flReloadRockets = g_Engine.time + APACHE_RELOAD_ROCKETS;
				self.m_flNextSecondaryAttack = g_Engine.time + APACHE_RELOAD_ROCKETS;
			}

			if( g_flReloadGun > 0 and g_flReloadGun < g_Engine.time )
			{
				g_flReloadGun = 0;
				self.m_iClip = g_iAmmo = APACHE_MAXBULLETS;
			}

			if( g_flReloadRockets > 0 and g_flReloadRockets < g_Engine.time )
			{
				g_flReloadRockets = 0;
				g_iRockets = APACHE_MAXROCKETS;
				m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, g_iRockets );
			}

			if( g_flStealthRegen > 0 and g_flStealthRegen < g_Engine.time )
				g_flStealthRegen = 0;

			if( g_flReloadBomb > 0 and g_flReloadBomb < g_Engine.time )
				g_flReloadBomb = 0;

			if( g_flApacheSpeed == 0 and apache.pev.health < APACHE_HEALTH + 5000 )
			{
				if( g_flRepair <= 0 ) g_flRepair = g_Engine.time + APACHE_REPAIR_DELAY;

				if( g_flRepair > 0 and g_flRepair < g_Engine.time )
				{
					apache.pev.health += APACHE_REPAIR_AMOUNT;

					if( apache.pev.health > APACHE_HEALTH + 5000 )
						apache.pev.health = APACHE_HEALTH + 5000;

					g_SoundSystem.EmitSound( apache.edict(), CHAN_BODY, APACHE_REPAIR_SOUND, 0.3f, ATTN_NORM );

					NetworkMessage repair( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
						repair.WriteByte( TE_FIREFIELD );
						repair.WriteCoord( apache.pev.origin.x );
						repair.WriteCoord( apache.pev.origin.y );
						repair.WriteCoord( apache.pev.origin.z );
						repair.WriteShort( 8 );//radius
						repair.WriteShort( m_iRepair );
						repair.WriteByte( 4 );//count
						repair.WriteByte( TEFIRE_FLAG_ALLFLOAT );
						repair.WriteByte( 4 );//duration
					repair.End();

					g_flRepair = 0;
				}
			}
		}

		BaseClass.ItemPreFrame();
	}

	void spawn_apache()
	{
		Vector origin = m_pPlayer.pev.origin;
		Vector angles = m_pPlayer.pev.v_angle;
		angles.x = -angles.x;

		@apache = cast<CBaseAnimating@>( g_EntityFuncs.Create("info_apache", origin, angles, false) );

		if( apache !is null )
		{
			@apache.pev.owner = m_pPlayer.pev.pContainingEntity;

			g_flApacheSpeed = 50.0f;

			Vector velocity(0, 0, 0);
			VelocityByAim( EHandle(apache), g_flApacheSpeed, velocity );
			apache.pev.velocity = velocity;

			if( !bDebug )
				g_SoundSystem.EmitSound( apache.edict(), CHAN_VOICE, "apache/ap_rotor2.wav", 0.8f, ATTN_NORM );
		}

		@camera = g_EntityFuncs.Create( "info_target", origin, angles, true );

		if( camera !is null )
		{
			g_EntityFuncs.SetModel( camera, "models/rpgrocket.mdl" );
			g_EntityFuncs.SetSize( camera.pev, Vector(0, 0, 0), Vector(0, 0, 0) );

			g_EntityFuncs.SetOrigin( camera, origin );
			camera.pev.angles = angles;
			camera.pev.solid = SOLID_NOT;
			camera.pev.movetype = MOVETYPE_NOCLIP;
			camera.pev.renderfx = kRenderFxGlowShell;
			camera.pev.rendercolor = Vector(0, 0, 0);
			camera.pev.rendermode = kRenderTransAlpha;
			camera.pev.renderamt = 0;

			if( !bDebug )
				g_EngineFuncs.SetView( m_pPlayer.edict(), camera.edict() );
		}

		g_flDefaultMaxSpeed = m_pPlayer.pev.maxspeed;

		if( !bDebug )
			m_pPlayer.pev.maxspeed = -1;

		g_flStealthRegen = 0;
		g_flReloadGun = 0;
		g_flReloadRockets = 0;
		bStealth = false;
		g_flReloadBomb = 0;
		g_flRepair = 0;
		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, g_iRockets );
		self.m_iClip = g_iAmmo;
		m_pPlayer.pev.flags |= FL_GODMODE; // to prevent crashing from killing yourself with the rockets
		m_pPlayer.pev.takedamage = DAMAGE_NO;

		if( bInvisiblePlayer )
		{
			m_pPlayer.pev.solid = SOLID_NOT;
			m_pPlayer.pev.movetype = MOVETYPE_NOCLIP;
			m_pPlayer.pev.flags |= FL_NOTARGET;
			m_pPlayer.pev.effects |= EF_NODRAW;
		}
	}

	void destroy_apache()
	{
		if( apache !is null )
		{
			g_EngineFuncs.SetView( m_pPlayer.edict(), m_pPlayer.edict() );
			g_SoundSystem.StopSound( apache.edict(), CHAN_VOICE, "apache/ap_rotor2.wav" );
			//g_SoundSystem.EmitSound( apache.edict(), CHAN_VOICE, "vox/_period.wav", 0.8f, ATTN_NORM );
			m_pPlayer.pev.maxspeed = g_flDefaultMaxSpeed; //250.0f in most cases
			g_EntityFuncs.Remove(apache);
			@apache = null;
		}

		if( camera !is null )
		{
			g_EngineFuncs.SetView( m_pPlayer.edict(), m_pPlayer.edict() );
			g_EntityFuncs.Remove(camera);
			@camera = null;
		}

		if( bStealth ) g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance(m_pPlayer.pev), APACHE_STEALTH_COLOR, 0.01f, 0.5f, APACHE_STEALTH_BRIGHTNESS, FFADE_IN );

		g_flStealthRegen = 0;
		g_flReloadGun = 0;
		g_flReloadRockets = 0;
		bStealth = false;
		g_flReloadBomb = 0;
		g_flRepair = 0;
	}

	void ResetPlayer()
	{
		if( (m_pPlayer.pev.flags & FL_GODMODE) != 1 )
		{
			m_pPlayer.pev.takedamage = DAMAGE_AIM;
			m_pPlayer.pev.flags &= ~FL_GODMODE;
		}

		if( bInvisiblePlayer )
		{
			m_pPlayer.pev.solid = SOLID_SLIDEBOX;
			m_pPlayer.pev.movetype = MOVETYPE_WALK;
			m_pPlayer.pev.flags &= ~FL_NOTARGET;
			m_pPlayer.pev.effects &= ~EF_NODRAW;
		}
	}

	void VelocityByAim( EHandle &in eEnt, const float &in flVelocity, Vector &out vecOut, const float &in flStrafe = 0 )
	{
		if( !eEnt.IsValid() )
		{
			g_Game.AlertMessage( at_console, "[APACHE DEBUG] eEnt isn't valid in VelocityByAim!\n");
			return;
		}

		CBaseEntity@ pEnt = eEnt.GetEntity();

		if( pEnt is null )
		{
			g_Game.AlertMessage( at_console, "[APACHE DEBUG] pEnt is null in VelocityByAim!\n");
			return;
		}

		g_EngineFuncs.MakeVectors(pEnt.pev.v_angle);
		Vector vecTemp = g_Engine.v_forward * flVelocity;

		if( flStrafe != 0 )
		{
			vecTemp.x += g_Engine.v_right.x * flStrafe * flVelocity;
			vecTemp.y += g_Engine.v_right.y * flStrafe * flVelocity;
			vecTemp.z += g_Engine.v_right.z * flStrafe * flVelocity;
		}

		vecOut = vecTemp;
	}

	void SetTextParams()
	{
		textParams.r1 = 250; //255
		textParams.g1 = 179; //255
		textParams.b1 = 209; //255
		textParams.x = -2.0f;
		textParams.y = 0.76f;
		textParams.effect = 0;
		textParams.fxTime = 1.0f;
		textParams.holdTime = 0.01f;
		textParams.fadeinTime = 0.001f;
		textParams.fadeoutTime = 0.2f;
		textParams.channel = 4;
	}
}

class info_apache : ScriptBaseAnimating
{
	void Spawn()
	{
		g_EntityFuncs.SetModel( self, APACHE_MODEL );
		self.pev.scale = APACHE_SCALE;
		g_EntityFuncs.SetSize( self.pev, Vector(-12, -12, -6), Vector(12, 12, 6) );
		self.pev.solid = SOLID_BBOX; //SOLID_SLIDEBOX
		self.pev.movetype = MOVETYPE_FLY; //MOVETYPE_WALK
		self.pev.sequence = APACHE_SEQUENCE;
		self.pev.takedamage = DAMAGE_AIM; //DAMAGE_YES
		self.pev.health = APACHE_HEALTH + 5000; //failsafe?
		self.SetBoneController( 0, 0 );
		self.SetBoneController( 1, 0 );
	}

	int TakeDamage( entvars_t@ pevInflictor, entvars_t@ pevAttacker, float flDamage, int bitsDamageType )
	{
		//g_Game.AlertMessage( at_console, "[APACHE DEBUG] pevInflictor: %1, pevAttacker: %2, flDamage: %3, bitsDamageType: %4\n", pevInflictor.classname, pevAttacker.classname, flDamage, bitsDamageType );

		if( pevAttacker is null )
			return 0;

		if( (bitsDamageType & DMG_CRUSH) != 0 and (pevAttacker.classname != "player" or pevAttacker.classname != "info_apache") )
			return 0;

		int ret = BaseClass.TakeDamage( pevInflictor, pevAttacker, flDamage, bitsDamageType );

		return ret;
	}

	int	ObjectCaps() { return BaseClass.ObjectCaps(); }
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "apacheweapon::info_apache", "info_apache" );
	g_CustomEntityFuncs.RegisterCustomEntity( "apacheweapon::weapon_apache", "weapon_apache" );
	g_ItemRegistry.RegisterWeapon( "weapon_apache", "custom_weapons/hl_npc", "apacheammo" );
}

void WriteToLog( const string &in sMsg )
{
	File@ file = g_FileSystem.OpenFile( "scripts/plugins/store/debuglog.txt", OpenFile::WRITE );

	if( file !is null and file.IsOpen() )
	{
		file.Write( sMsg + "\n" );

		file.Close();
	}
}

} //end of namespace apacheweapon

/*
*	Changelog
*
*	Version: 	1.0
*	Date: 		December 14 2017
*	-------------------------
*	- Release
*	- Bugfixes
*	-------------------------
*
*	Version: 	1.1
*	Date: 		December 15 2017
*	-------------------------
*	- Player is now invincible while piloting the helicopter (to prevent seemingly unfixable crash when killing self with rockets)
*	- Setting bInvisiblePlayer to true will make the player invisible while piloting the helicopter
*	- Helicopter will slowly repair itself while hovering (0 speed)
*	-------------------------
*
*	Version: 	1.2
*	Date: 		December 20 2017
*	-------------------------
*	- Gun and rockets now reload automatically when empty
*	- Apache is no longer removed if both bullets and rockets are at 0
*	- Gun and rockets can no be fired simultaneously
*	- Possible stability fixes; but impossible for me to test
*	-------------------------
*
*	Version: 	1.4
*	Date: 		December 27 2017
*	-------------------------
*	- Apache is no longer automatically spawned when selecting the weapon; spawn with Primary Fire
*	- Should no longer crash when destroying helicopters with rockets
*	- No longer takes crushing damage from non-players (causing CTD)
*	- Increased framerate to make the blades spin faster
*	- Setting bDropPlayer to true will drop the player off at the Apache's position
*	- Setting bTransportPlayer to true will move the player with the Apache
*	-------------------------
*/
/*
*	ToDo
*
*	Try to fix hitbox (way larger than it should be, and rockets pass right through)
*	Move the heli directly instead of speeding up/down
Pretty fun plugin, sometimes got stuck on floor when I change the weapon, and if the apache gets "pressed" whit movable solids, the server crashs 
*/