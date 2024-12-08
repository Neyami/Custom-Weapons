namespace apacheweapon
{

const int APACHE_MAXBULLETS				= 100;
const int APACHE_MAXROCKETS				= 10;
const int APACHE_DEFAULT_AMMO			= 100;
const int APACHE_SLOT					= 1;
const int APACHE_POSITION				= 16;
const int APACHE_WEIGHT					= 0; //don't want to start the map with this deployed :D

const string APACHE_MODEL				= "models/apachef.mdl";
const float APACHE_SCALE				= 0.07;
const string APACHE_WORLDMODEL			= "models/w_weaponbox.mdl";
const float APACHE_WORLDMODEL_SCALE		= 1.0;
const int APACHE_SEQUENCE				= 0;
const int APACHE_FRAMERATE				= 10.0;

const float APACHE_HEALTH				= 1000.0;
const float APACHE_MAXSPEED				= 400.0;
const float APACHE_ROCKETSPEED			= 1000.0;
const float APACHE_HEIGHT				= 20.0;
const float APACHE_DISTANCE				= 70.0;

const float APACHE_DELAY_GUN			= 0.1;
const float APACHE_DELAY_ROCKETS		= 0.5;
const float APACHE_DELAY_DEATH			= 2.5;
const float APACHE_DAMAGE_GUN			= 10.0;
const float APACHE_DAMAGE_ROCKET		= 150.0; //200 causes the explosion to be too large
const float APACHE_DAMAGE_BOMB			= 150.0; //200
const float APACHE_RELOAD_GUN			= 2.0;
const float APACHE_RELOAD_ROCKETS		= 2.0;

const float APACHE_STEALTH_MAXSPEED		= 60.0;
const float APACHE_STEALTH_COOLDOWN		= 10.0;
const int APACHE_STEALTH_AMOUNT			= 40; //amount of transparency
const int APACHE_STEALTH_BRIGHTNESS		= 64;
const Vector APACHE_STEALTH_COLOR		= Vector(240, 180, 0);
const float APACHE_STEALTH_DMGMUL		= 0.6; //60% rocket and bomb damage when in stealth

const string APACHE_BOMB_MODEL			= "models/rpgrocket.mdl";
const float APACHE_BOMB_COOLDOWN		= 4.0;

const float APACHE_REPAIR_DELAY			= 1.3;
const float APACHE_REPAIR_AMOUNT		= 50.0;
const string APACHE_REPAIR_SOUND		= "tfc/weapons/turrset.wav";

class weapon_apache : ScriptBasePlayerWeaponEntity
{
	protected CBasePlayer@ m_pPlayer
	{
		get const { return cast<CBasePlayer@>(self.m_hPlayer.GetEntity()); }
		set { self.m_hPlayer = EHandle(@value); }
	}

	protected EHandle m_hApache;
	CBaseAnimating@ m_pApache
	{
		get const { return cast<CBaseAnimating@>(m_hApache.GetEntity()); }
		set { m_hApache = EHandle(@value); }
	}

	protected EHandle m_hCamera;
	CBaseEntity@ m_pCamera
	{
		get const { return m_hCamera.GetEntity(); }
		set { m_hCamera = EHandle(@value); }
	}

	private int m_iLaserbeam = 0, m_iSmoke = 0;
	private float m_flStealthRegen, m_flDefaultMaxSpeed, m_flApacheSpeed, m_flReloadGun, m_flReloadRockets, m_flReloadBomb, m_flRepair;
	private bool m_bStealth = false;
	private HUDTextParams m_textParams;
	private int m_iSpriteTexture = 0;
	private int m_iExplode = 0;
	private int m_sModelIndexSmoke = 0;
	private int m_iRepair = 0;
	private float m_iSide = 1.0;
	private int m_iAmmo, m_iRockets;
	private bool m_bBeams = false; //display a beam from the apache
	private bool m_bDebug = false; //camera won't be attached and the apache won't respond to player's movement + infinite ammo
	private bool m_bInvisiblePlayer = true;
	private bool m_bDropPlayer = false; //drop player off (teleport) to where the helicopter is when holstering?
	private bool m_bTransportPlayer = false; //move player with the Apache?

	void Spawn()
	{
		self.Precache();
		g_EntityFuncs.SetModel( self, APACHE_WORLDMODEL );
		self.pev.scale = APACHE_WORLDMODEL_SCALE;
		self.m_iDefaultAmmo = APACHE_DEFAULT_AMMO;
		self.FallInit();
		SetTextParams(); //for the HUD
		m_iSide = 1.0;
		m_iAmmo = APACHE_MAXBULLETS;
		m_iRockets = APACHE_MAXROCKETS;
	}

	void Precache()
	{
		self.PrecacheCustomModels();

		m_iLaserbeam = g_Game.PrecacheModel( "sprites/laserbeam.spr" );
		m_iSmoke = g_Game.PrecacheModel( "sprites/smoke.spr" );

		m_iSpriteTexture = g_Game.PrecacheModel( "sprites/white.spr" );
		m_iExplode	= g_Game.PrecacheModel( "sprites/fexplo.spr" );
		m_sModelIndexSmoke = g_Game.PrecacheModel( "sprites/steam1.spr" );

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
		if( m_iAmmo <= 0 and m_iRockets <= 0 )
			return false;

		return true;
	}

	void Holster( int skipLocal = 0 )
	{
		Vector vecApacheOrigin;

		if( m_pApache !is null )
		{
			vecApacheOrigin = m_pApache.pev.origin;
			destroy_apache();
		}

		ResetPlayer();

		if( m_bDropPlayer )
		{
			m_pPlayer.pev.origin = vecApacheOrigin;
		}

		BaseClass.Holster( skipLocal );
	}

	void PrimaryAttack()
	{
		if( m_pApache !is null )
		{
			if( m_iAmmo <= 0 )
				return;

			Math.MakeAimVectors( m_pApache.pev.angles );
			Vector vecSrc = m_pApache.pev.origin + g_Engine.v_forward * -32 + g_Engine.v_up * -7;

			m_pApache.FireBullets( 1, vecSrc, g_Engine.v_forward, VECTOR_CONE_4DEGREES, 8192.0, BULLET_MONSTER_12MM, 4, APACHE_DAMAGE_GUN, m_pPlayer.pev );
			g_SoundSystem.EmitSound( m_pApache.edict(), CHAN_WEAPON, "turret/tu_fire1.wav", VOL_NORM, 0.3 );

			if( !m_bDebug )
			{
				--m_iAmmo;
				self.m_iClip = m_iAmmo;
			}
		}
		else spawn_apache();

		self.m_flTimeWeaponIdle = self.m_flNextPrimaryAttack = g_Engine.time + APACHE_DELAY_GUN;
	}

	void SecondaryAttack()
	{
		if( m_pApache !is null )
		{
			if( m_iRockets <= 0 )
				return;

			Math.MakeAimVectors( m_pApache.pev.angles );
			Vector vecSrc = m_pApache.pev.origin + g_Engine.v_forward * -4 + g_Engine.v_right * 6.5 * m_iSide + g_Engine.v_up * -7;

			NetworkMessage m( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, vecSrc );
				m.WriteByte( TE_SMOKE );
				m.WriteCoord( vecSrc.x );
				m.WriteCoord( vecSrc.y );
				m.WriteCoord( vecSrc.z - 7 );
				m.WriteShort( m_sModelIndexSmoke );
				m.WriteByte( 2 ); // scale * 10
				m.WriteByte( 12 ); // framerate
			m.End();

			//CBaseEntity@ pRocket = g_EntityFuncs.Create( "hvr_rocket", vecSrc, m_pApache.pev.angles, false );
			CBaseEntity@ pRocket = g_EntityFuncs.Create( "hvr_rocket", vecSrc, m_pApache.pev.angles, false, m_pPlayer.edict() );

			if( pRocket !is null )
			{
				//@pRocket.pev.owner = m_pPlayer.pev.pContainingEntity;
				pRocket.pev.dmg = m_bStealth ? (APACHE_DAMAGE_ROCKET * APACHE_STEALTH_DMGMUL) : APACHE_DAMAGE_ROCKET;
				pRocket.pev.scale = 0.3f;
				pRocket.pev.velocity = m_pApache.pev.velocity + g_Engine.v_forward * APACHE_ROCKETSPEED;

				// the original trail is too thicc
				NetworkMessage killbeam( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY, null );
					killbeam.WriteByte(TE_KILLBEAM);
					killbeam.WriteShort(pRocket.entindex());
				killbeam.End();

				NetworkMessage trail( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
					trail.WriteByte( TE_BEAMFOLLOW );
					trail.WriteShort( pRocket.entindex() );
					trail.WriteShort( m_iSmoke );
					trail.WriteByte( 15 ); // life
					trail.WriteByte( 2 );  // width
					trail.WriteByte( 224 );   // r, g, b
					trail.WriteByte( 224 );   // r, g, b
					trail.WriteByte( 255 );   // r, g, b
					trail.WriteByte( 255 );	// brightness
				trail.End();
			}

			if( !m_bDebug )
			{
				--m_iRockets;
				m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_iRockets );
			}

			m_iSide = -m_iSide;
		}

		self.m_flTimeWeaponIdle = self.m_flNextSecondaryAttack = g_Engine.time + APACHE_DELAY_ROCKETS;
	}

	void TertiaryAttack()
	{
		if( m_pApache !is null )
		{
			if( m_flStealthRegen <= 0 )
			{
				if( !m_bStealth )
				{
					m_bStealth = true;
					g_SoundSystem.EmitSoundDyn( m_pApache.edict(), CHAN_VOICE, "apache/ap_rotor2.wav", 0.1, ATTN_NORM, 0, PITCH_NORM );
					m_pApache.pev.renderfx = kRenderFxGlowShell;
					m_pApache.pev.rendercolor = Vector(0, 0, 0);
					m_pApache.pev.rendermode = kRenderTransAlpha;
					m_pApache.pev.renderamt = APACHE_STEALTH_AMOUNT;

					g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance(m_pPlayer.pev), APACHE_STEALTH_COLOR, 0.01, 0.5, APACHE_STEALTH_BRIGHTNESS, (FFADE_OUT | FFADE_STAYOUT) );
				}
				else
				{
					m_bStealth = false;
					g_SoundSystem.EmitSoundDyn( m_pApache.edict(), CHAN_VOICE, "apache/ap_rotor2.wav", 0.8, ATTN_NORM, 0, PITCH_NORM );

					m_pApache.pev.renderfx = 0;
					m_pApache.pev.rendercolor = Vector(0, 0, 0);
					m_pApache.pev.rendermode = 0;
					m_pApache.pev.renderamt = 0;

					g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance(m_pPlayer.pev), APACHE_STEALTH_COLOR, 0.01, 0.5, APACHE_STEALTH_BRIGHTNESS, FFADE_IN );

					m_flStealthRegen = g_Engine.time + APACHE_STEALTH_COOLDOWN;
				}
			}
			else
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "Stealth cooldown: " + (m_flStealthRegen - g_Engine.time) + " second(s).\n" );
		}

		self.m_flTimeWeaponIdle = self.m_flNextTertiaryAttack = g_Engine.time + 0.5;
	}

	void Reload()
	{
		if( m_pApache !is null )
		{
			if( m_flReloadBomb <= 0 )
			{
				CBaseEntity@ pBomb = g_EntityFuncs.ShootContact( m_pPlayer.pev, m_pApache.pev.origin + Vector(0, 0, -16), g_vecZero );

				if( pBomb !is null )
				{
					g_EntityFuncs.SetModel( pBomb, APACHE_BOMB_MODEL );
					//g_EntityFuncs.SetSize( pBomb.pev, Vector(-1.0, -1.0, -1.0), Vector(1.0, 1.0, 1.0) );
					//pBomb.pev.solid = SOLID_TRIGGER;
					//pBomb.pev.movetype = MOVETYPE_TOSS;
					@pBomb.pev.owner = m_pPlayer.pev.pContainingEntity;
					pBomb.pev.dmg = m_bStealth ? (APACHE_DAMAGE_BOMB * APACHE_STEALTH_DMGMUL): APACHE_DAMAGE_BOMB;
				}

				m_flReloadBomb = g_Engine.time + APACHE_BOMB_COOLDOWN;
			}
			else
				g_EngineFuncs.ClientPrintf( m_pPlayer, print_center, "Bomb cooldown: " + (m_flReloadBomb - g_Engine.time) + " second(s).\n" );
		}
	}

	void WeaponIdle()
	{
		if( self.m_flTimeWeaponIdle > g_Engine.time )
			return;

		self.m_flTimeWeaponIdle = g_Engine.time + 1.0;
	}

	void ItemPreFrame()
	{
		if( m_pPlayer.IsAlive() and m_pApache !is null and m_pCamera !is null )
		{
			if( (m_pPlayer.pev.flags & FL_GODMODE) != 1 )
			{
				m_pPlayer.pev.flags |= FL_GODMODE;
				m_pPlayer.pev.takedamage = DAMAGE_NO;
			}

			if( m_bInvisiblePlayer and m_pPlayer.pev.flags & (EF_NODRAW|FL_NOTARGET) != 1 )
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

			if( m_pApache.pev.health < 5000 )
			{
				Vector vecSpot = m_pApache.pev.origin + (m_pApache.pev.mins + m_pApache.pev.maxs) * 0.5;

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
					m2.WriteShort( m_sModelIndexSmoke );
					m2.WriteByte( 25 ); // scale * 10
					m2.WriteByte( 5 ); // framerate
				m2.End();

				// blast circle
				NetworkMessage m3( MSG_PVS, NetworkMessages::SVC_TEMPENTITY, m_pApache.pev.origin );
					m3.WriteByte( TE_BEAMCYLINDER );
					m3.WriteCoord( m_pApache.pev.origin.x );
					m3.WriteCoord( m_pApache.pev.origin.y );
					m3.WriteCoord( m_pApache.pev.origin.z );
					m3.WriteCoord( m_pApache.pev.origin.x );
					m3.WriteCoord( m_pApache.pev.origin.y );
					m3.WriteCoord( m_pApache.pev.origin.z + 200 ); // reach damage radius over .2 seconds
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

				g_SoundSystem.EmitSoundDyn( m_pApache.edict(), CHAN_STATIC, "weapons/mortarhit.wav", VOL_NORM, 0.3, 0, PITCH_HIGH );

				g_WeaponFuncs.RadiusDamage( m_pApache.pev.origin, m_pApache.pev, m_pApache.pev, 50, 300, CLASS_NONE, DMG_BLAST ); 

				destroy_apache();
				ResetPlayer();
				self.m_flNextPrimaryAttack = g_Engine.time + APACHE_DELAY_DEATH;
			}

			if( m_pApache is null )
			{
				BaseClass.ItemPreFrame();
				return;
			}

			frame = m_pApache.pev.frame;
			if( frame < 0.0 || frame > 254.0 )
				m_pApache.pev.frame = 0.0;
			else
				m_pApache.pev.frame = frame + APACHE_FRAMERATE;

			button = m_pPlayer.pev.button;
			if( (button & IN_FORWARD) != 0 )
				m_flApacheSpeed += 5.0;

			if( (button & IN_BACK) != 0 )
				m_flApacheSpeed -= 5.0;

			if( (button & IN_USE) != 0 ) //stop_apache
			{
				// slow down to a complete stop
				if( m_flApacheSpeed > 0 )
					m_flApacheSpeed -= 5.0;
				else if( m_flApacheSpeed < 0 )
					m_flApacheSpeed += 5.0;

				// instantly stop if speed is low enough
				//if( m_flApacheSpeed <= 30 && m_flApacheSpeed >= -30 )
				//	m_flApacheSpeed = 0.0;
			}

			if( !m_bStealth )
				maxspeed = APACHE_MAXSPEED;
			else
				maxspeed = APACHE_STEALTH_MAXSPEED;

			if( m_flApacheSpeed > maxspeed )
				m_flApacheSpeed = maxspeed;

			if( m_flApacheSpeed < -80 )
				m_flApacheSpeed = -80;

			forigin = m_pApache.pev.origin;
			angles = m_pPlayer.pev.v_angle;
			angles.x = -angles.x;
			VelocityByAim( EHandle(m_pPlayer), m_flApacheSpeed, velocity );

			if( !m_bDebug ) m_pApache.pev.angles = angles;

			m_pApache.pev.velocity = velocity;

			if( !m_bDebug )
			{
				if( (button & IN_JUMP) != 0 )
				{
					forigin.z += 2.0;
					if( g_EngineFuncs.PointContents(forigin) != CONTENTS_SOLID )
						m_pApache.pev.origin = forigin;

					//m_pApache.pev.velocity.z += 200.0;
				}

				if( (button & IN_DUCK) != 0 )
				{
					forigin.z -= 2.0;
					if( g_EngineFuncs.PointContents(forigin) != CONTENTS_SOLID )
						m_pApache.pev.origin = forigin;

					//m_pApache.pev.velocity.z -= 200.0;
				}
			}

			if( g_EngineFuncs.PointContents(forigin) == CONTENTS_SOLID )
			{
				forigin.z += 10.0;
				if( g_EngineFuncs.PointContents(forigin) == CONTENTS_SOLID )
					forigin.z -= 60.0;

				m_pApache.pev.origin = forigin;
			}

			VelocityByAim( EHandle(m_pPlayer), APACHE_DISTANCE, dist_origin );
			camera_origin.x = forigin.x - dist_origin.x;
			camera_origin.y = forigin.y - dist_origin.y;
			camera_origin.z = forigin.z + APACHE_HEIGHT;
			m_pCamera.pev.origin = camera_origin;
			angles.x = -angles.x;
			m_pCamera.pev.angles = angles;

			if( !m_bDebug )
			{
				if( (button & IN_MOVELEFT) != 0 )
				{
					VelocityByAim( EHandle(m_pPlayer), m_flApacheSpeed, velocity, m_flApacheSpeed > 0 ? -1 : 1 );
					m_pApache.pev.velocity = velocity;
				}

				if( (button & IN_MOVERIGHT) != 0 )
				{
					VelocityByAim( EHandle(m_pPlayer), m_flApacheSpeed, velocity, m_flApacheSpeed > 0 ? 1 : -1 );
					m_pApache.pev.velocity = velocity;
				}
			}
			else m_pApache.pev.velocity = g_vecZero;

			if( m_bTransportPlayer ) m_pPlayer.pev.origin = m_pApache.pev.origin;

			if( m_bBeams )
			{
				VelocityByAim( EHandle(m_pPlayer), 9999, velocity );
				end_origin = forigin + velocity;

				TraceResult tr;
				g_Utility.TraceLine( forigin, end_origin, dont_ignore_monsters, m_pApache.edict(), tr );

				NetworkMessage beammsg( MSG_ONE_UNRELIABLE, NetworkMessages::SVC_TEMPENTITY, g_vecZero, m_pPlayer.edict() );
					beammsg.WriteByte( TE_BEAMENTPOINT );
					beammsg.WriteShort( m_pApache.entindex() );
					beammsg.WriteCoord( tr.vecEndPos.x );
					beammsg.WriteCoord( tr.vecEndPos.y );
					beammsg.WriteCoord( tr.vecEndPos.z );
					beammsg.WriteShort( m_iLaserbeam );
					beammsg.WriteByte( 1 ); //starting frame
					beammsg.WriteByte( 1 ); //framerate
					beammsg.WriteByte( 1 ); //life
					beammsg.WriteByte( 8 ); //line width
					beammsg.WriteByte( 0 ); //noise amplitude
					beammsg.WriteByte( 255 ); //color
					beammsg.WriteByte( 0 );
					beammsg.WriteByte( 0 );
					beammsg.WriteByte( 128 ); //brightness
					beammsg.WriteByte( 0 ); //scroll speed
				beammsg.End();
			}

			//g_PlayerFuncs.HudMessage( m_pPlayer, m_textParams, " [APACHE] Speed: " + m_flApacheSpeed + ", Health: " + string(int(Math.Floor(m_pApache.pev.health + 0.5)) - 5000) + ", Velocity: " + m_pApache.pev.velocity.ToString() + "\n" );
			g_PlayerFuncs.HudMessage( m_pPlayer, m_textParams, " [APACHE] Speed: " + m_flApacheSpeed + ", Health: " + string(int(Math.Floor(m_pApache.pev.health + 0.5)) - 5000) + "\n" );

			if( m_iAmmo <= 0 and m_flReloadGun <= 0 )
			{
				g_SoundSystem.EmitSound( m_pApache.edict(), CHAN_WEAPON, "weapons/gl_reload.wav", VOL_NORM, 0.3 );
				m_flReloadGun = g_Engine.time + APACHE_RELOAD_GUN;
				self.m_flNextPrimaryAttack = g_Engine.time + APACHE_RELOAD_GUN;
			}

			if( m_iRockets <= 0 and m_flReloadRockets <= 0 )
			{
				g_SoundSystem.EmitSound( m_pApache.edict(), CHAN_WEAPON, "weapons/gl_reload.wav", VOL_NORM, 0.3 );
				m_flReloadRockets = g_Engine.time + APACHE_RELOAD_ROCKETS;
				self.m_flNextSecondaryAttack = g_Engine.time + APACHE_RELOAD_ROCKETS;
			}

			if( m_flReloadGun > 0.0 and m_flReloadGun < g_Engine.time )
			{
				m_flReloadGun = 0.0;
				self.m_iClip = m_iAmmo = APACHE_MAXBULLETS;
			}

			if( m_flReloadRockets > 0 and m_flReloadRockets < g_Engine.time )
			{
				m_flReloadRockets = 0;
				m_iRockets = APACHE_MAXROCKETS;
				m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_iRockets );
			}

			if( m_flStealthRegen > 0 and m_flStealthRegen < g_Engine.time )
				m_flStealthRegen = 0;

			if( m_flReloadBomb > 0 and m_flReloadBomb < g_Engine.time )
				m_flReloadBomb = 0;

			if( m_flApacheSpeed == 0 and m_pApache.pev.health < APACHE_HEALTH + 5000 )
			{
				if( m_flRepair <= 0 ) m_flRepair = g_Engine.time + APACHE_REPAIR_DELAY;

				if( m_flRepair > 0 and m_flRepair < g_Engine.time )
				{
					m_pApache.pev.health += APACHE_REPAIR_AMOUNT;

					if( m_pApache.pev.health > APACHE_HEALTH + 5000 )
						m_pApache.pev.health = APACHE_HEALTH + 5000;

					g_SoundSystem.EmitSound( m_pApache.edict(), CHAN_BODY, APACHE_REPAIR_SOUND, 0.3, ATTN_NORM );

					NetworkMessage repair( MSG_BROADCAST, NetworkMessages::SVC_TEMPENTITY );
						repair.WriteByte( TE_FIREFIELD );
						repair.WriteCoord( m_pApache.pev.origin.x );
						repair.WriteCoord( m_pApache.pev.origin.y );
						repair.WriteCoord( m_pApache.pev.origin.z );
						repair.WriteShort( 8 );//radius
						repair.WriteShort( m_iRepair );
						repair.WriteByte( 4 );//count
						repair.WriteByte( TEFIRE_FLAG_ALLFLOAT );
						repair.WriteByte( 4 );//duration
					repair.End();

					m_flRepair = 0.0;
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

		@m_pApache = cast<CBaseAnimating@>( g_EntityFuncs.Create("info_apache", origin, angles, false) );

		if( m_pApache !is null )
		{
			@m_pApache.pev.owner = m_pPlayer.pev.pContainingEntity;

			m_flApacheSpeed = 50.0;

			Vector velocity(0, 0, 0);
			VelocityByAim( EHandle(m_pApache), m_flApacheSpeed, velocity );
			m_pApache.pev.velocity = velocity;

			if( !m_bDebug )
				g_SoundSystem.EmitSound( m_pApache.edict(), CHAN_VOICE, "apache/ap_rotor2.wav", 0.8, ATTN_NORM );
		}

		@m_pCamera = g_EntityFuncs.Create( "info_target", origin, angles, true );

		if( m_pCamera !is null )
		{
			g_EntityFuncs.SetModel( m_pCamera, "models/rpgrocket.mdl" );
			g_EntityFuncs.SetSize( m_pCamera.pev, Vector(0, 0, 0), Vector(0, 0, 0) );

			g_EntityFuncs.SetOrigin( m_pCamera, origin );
			m_pCamera.pev.angles = angles;
			m_pCamera.pev.solid = SOLID_NOT;
			m_pCamera.pev.movetype = MOVETYPE_NOCLIP;
			m_pCamera.pev.renderfx = kRenderFxGlowShell;
			m_pCamera.pev.rendercolor = Vector(0, 0, 0);
			m_pCamera.pev.rendermode = kRenderTransAlpha;
			m_pCamera.pev.renderamt = 0;

			if( !m_bDebug )
				g_EngineFuncs.SetView( m_pPlayer.edict(), m_pCamera.edict() );
		}

		m_flDefaultMaxSpeed = m_pPlayer.pev.maxspeed;

		if( !m_bDebug )
			m_pPlayer.pev.maxspeed = -1;

		m_flStealthRegen = 0.0;
		m_flReloadGun = 0.0;
		m_flReloadRockets = 0.0;
		m_bStealth = false;
		m_flReloadBomb = 0.0;
		m_flRepair = 0.0;
		m_pPlayer.m_rgAmmo( self.m_iPrimaryAmmoType, m_iRockets );
		self.m_iClip = m_iAmmo;
		m_pPlayer.pev.flags |= FL_GODMODE; // to prevent crashing from killing yourself with the rockets
		m_pPlayer.pev.takedamage = DAMAGE_NO;

		if( m_bInvisiblePlayer )
		{
			m_pPlayer.pev.solid = SOLID_NOT;
			m_pPlayer.pev.movetype = MOVETYPE_NOCLIP;
			m_pPlayer.pev.flags |= FL_NOTARGET;
			m_pPlayer.pev.effects |= EF_NODRAW;
		}
	}

	void destroy_apache()
	{
		if( m_pApache !is null )
		{
			g_EngineFuncs.SetView( m_pPlayer.edict(), m_pPlayer.edict() );
			g_SoundSystem.StopSound( m_pApache.edict(), CHAN_VOICE, "apache/ap_rotor2.wav" );
			//g_SoundSystem.EmitSound( m_pApache.edict(), CHAN_VOICE, "vox/_period.wav", 0.8, ATTN_NORM );
			m_pPlayer.pev.maxspeed = m_flDefaultMaxSpeed; //250.0f in most cases
			g_EntityFuncs.Remove( m_pApache );
		}

		if( m_pCamera !is null )
		{
			g_EngineFuncs.SetView( m_pPlayer.edict(), m_pPlayer.edict() );
			g_EntityFuncs.Remove( m_pCamera );
		}

		if( m_bStealth ) g_PlayerFuncs.ScreenFade( g_EntityFuncs.Instance(m_pPlayer.pev), APACHE_STEALTH_COLOR, 0.01f, 0.5f, APACHE_STEALTH_BRIGHTNESS, FFADE_IN );

		m_flStealthRegen = 0.0;
		m_flReloadGun = 0.0;
		m_flReloadRockets = 0.0;
		m_bStealth = false;
		m_flReloadBomb = 0.0;
		m_flRepair = 0.0;
	}

	void ResetPlayer()
	{
		if( (m_pPlayer.pev.flags & FL_GODMODE) != 1 )
		{
			m_pPlayer.pev.takedamage = DAMAGE_AIM;
			m_pPlayer.pev.flags &= ~FL_GODMODE;
		}

		if( m_bInvisiblePlayer )
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
		m_textParams.r1 = 250; //255
		m_textParams.g1 = 179; //255
		m_textParams.b1 = 209; //255
		m_textParams.x = -2.0f;
		m_textParams.y = 0.76f;
		m_textParams.effect = 0;
		m_textParams.fxTime = 1.0f;
		m_textParams.holdTime = 0.01f;
		m_textParams.fadeinTime = 0.001f;
		m_textParams.fadeoutTime = 0.2f;
		m_textParams.channel = 4;
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
*	- Setting m_bInvisiblePlayer to true will make the player invisible while piloting the helicopter
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
*	- Setting m_bDropPlayer to true will drop the player off at the Apache's position
*	- Setting m_bTransportPlayer to true will move the player with the Apache
*	-------------------------
*
*	Version: 	1.5
*	Date: 		December 08 2024
*	-------------------------
*	- Some minor things
*	-------------------------
*/
/*
*	ToDo
*
*	Try to fix hitbox (way larger than it should be, and rockets pass right through)
*	Move the heli directly instead of speeding up/down
Pretty fun plugin, sometimes got stuck on floor when I change the weapon, and if the apache gets "pressed" whit movable solids, the server crashs 
*/