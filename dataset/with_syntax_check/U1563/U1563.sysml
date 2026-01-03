package 'STS123_SpaceShuttleMissionSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MissionPhase;
	attribute def CrewCount;
	attribute def DockingStatus;
	
	item def Propellant {
		attribute mass : MassValue;
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def PayloadCargo {
		attribute mass : MassValue;
		attribute volume : VolumeValue;
		attribute powerRequirement : PowerValue;
	}
	
	item def TelemetryData {
		attribute timestamp : Real;
		attribute dataRate : Real;
	}
	
	item def NavigationData {
		attribute position : LengthValue[3];
		attribute velocity : SpeedValue[3];
		attribute attitude : Real[3];
	}
	
	port def PowerBus {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
		attribute power : PowerValue;
	}
	
	port def DataBus {
		attribute commandData : TelemetryData;
		attribute telemetryData : TelemetryData;
		attribute bandwidth : Real;
	}
	
	port def MechanicalInterface {
		attribute loadCapacity : ForceValue;
		attribute alignment : Boolean;
	}
	
	port def DockingInterface {
		attribute isAligned : Boolean;
		attribute isLocked : Boolean;
		attribute sealIntegrity : Boolean;
	}
	
	port def PropulsionInterface {
		attribute thrustCommand : ForceValue;
		attribute thrustDelivered : ForceValue;
		attribute propellantFlow : Real;
	}
	
	part def SpaceShuttleEndeavour {
		attribute dryMass : MassValue;
		attribute maxPayloadMass : MassValue;
		port mainPower : PowerBus;
		port avionics : DataBus;
		port dockingMechanism : DockingInterface;
	}
	
	part def ExternalFuelTank {
		attribute totalPropellantCapacity : MassValue;
		part liquidOxygen : Propellant;
		part liquidHydrogen : Propellant;
	}
	
	part def SolidRocketBooster {
		attribute thrustRating : ForceValue;
		attribute burnDuration : TimeValue;
		attribute propellantMass : MassValue;
		port thrustOutput : PropulsionInterface;
	}
	
	part def MainEngineCluster {
		attribute engineCount : Integer;
		attribute thrustPerEngine : ForceValue;
		port thrustVector : PropulsionInterface;
	}
	
	part def OrbitalManeuveringSystem {
		attribute maxDeltaV : SpeedValue;
		attribute propellantMass : MassValue;
		port thrustControl : PropulsionInterface;
	}
	
	part def ReactionControlSystem {
		attribute thrusterCount : Integer;
		attribute thrustPerThruster : ForceValue;
		port attitudeControl : PropulsionInterface;
	}
	
	part def PayloadBay {
		attribute length : LengthValue;
		attribute diameter : LengthValue;
		attribute maxCapacity : MassValue;
		port mechanicalAttach : MechanicalInterface;
		port payloadPower : PowerBus;
		port payloadData : DataBus;
	}
	
	part def KiboLogisticsModule {
		attribute mass : MassValue;
		attribute length : LengthValue;
		attribute diameter : LengthValue;
		attribute storageVolume : VolumeValue;
		attribute transferComplete : Boolean;
		port berthing : MechanicalInterface;
		port power : PowerBus;
		port data : DataBus;
	}
	
	part def DextreRoboticManipulator {
		attribute mass : MassValue;
		attribute armReach : LengthValue;
		attribute dexterityJoints : Integer;
		attribute payloadHandlingCapacity : MassValue;
		attribute installationComplete : Boolean;
		port mounting : MechanicalInterface;
		port power : PowerBus;
		port control : DataBus;
	}
	
	part def InternationalSpaceStation {
		attribute orbitalAltitude : LengthValue;
		attribute orbitalVelocity : SpeedValue;
		attribute mass : MassValue;
		port dockingAdapter : DockingInterface;
		port stationPower : PowerBus;
		port stationComms : DataBus;
		port berthingPort : MechanicalInterface;
	}
	
	part def GuidanceNavigationControl {
		port sensorInput : DataBus;
		port commandOutput : DataBus;
		action def ComputeTrajectory {
			in currentState : NavigationData;
			in targetState : NavigationData;
			out maneuverPlan : Real[*];
		}
		action def ExecuteManeuver {
			in maneuverPlan : Real[*];
			out thrustVector : ForceValue[3];
		}
	}
	
	action def LaunchSequence {
		in totalMass : MassValue;
		in targetOrbit : LengthValue;
		out orbitalVelocity : SpeedValue;
		out altitude : LengthValue;
	}
	
	action def AscentPhase {
		in srbThrust : ForceValue;
		in mainEngineThrust : ForceValue;
		in vehicleMass : MassValue;
		out velocity : SpeedValue;
		out altitude : LengthValue;
		out acceleration : Real;
	}
	
	action def OrbitalInsertion {
		in currentVelocity : SpeedValue;
		in targetVelocity : SpeedValue;
		in omsThrust : ForceValue;
		out finalOrbit : LengthValue;
	}
	
	action def RendezvousApproach {
		in shuttlePosition : LengthValue[3];
		in issPosition : LengthValue[3];
		in relativeVelocity : SpeedValue[3];
		out approachVector : Real[3];
		out closingRate : SpeedValue;
	}
	
	action def DockingOperation {
		in approachVelocity : SpeedValue;
		in alignmentError : Real;
		out dockingSuccess : Boolean;
		out contactForce : ForceValue;
	}
	
	action def PayloadTransfer {
		in payload : PayloadCargo;
		in transferMechanism : String;
		out transferComplete : Boolean;
		out installationVerified : Boolean;
	}
	
	action def UndockingSequence {
		in separationVelocity : SpeedValue;
		out clearanceDistance : LengthValue;
		out undockingComplete : Boolean;
	}
	
	action def DeorbitBurn {
		in currentOrbit : LengthValue;
		in deltaV : SpeedValue;
		out reentryTrajectory : Real[*];
	}
	
	action def AtmosphericReentry {
		in entryVelocity : SpeedValue;
		in entryAngle : Real;
		out heatShieldTemperature : TemperatureValue;
		out deceleration : Real;
	}
	
	action def TerminalApproachLanding {
		in approachSpeed : SpeedValue;
		in runwayAlignment : Real;
		out touchdownVelocity : SpeedValue;
		out landingSuccess : Boolean;
	}
	
	requirement def MissionObjective {
		doc /* STS-123 shall deliver critical ISS assembly components and return crew safely to Earth. */
	}
	
	requirement def PayloadDeliveryRequirement;
	requirement def CrewSafetyRequirement;
	requirement def OrbitalRequirement;
	
	requirement <'STS123-REQ-001'> deliverKiboModule : PayloadDeliveryRequirement {
		doc /* The mission shall successfully deliver the Kibo Japanese Experiment Logistics Module 
		       Pressurized Section (ELM-PS) to the International Space Station. */
		
		subject kiboModule : KiboLogisticsModule;
		
		assume constraint { kiboModule.mass <= 8600[kg] }
		assume constraint { kiboModule.length == 4.2[m] }
		require constraint { kiboModule.transferComplete == true }
	}
	
	requirement <'STS123-REQ-002'> deliverDextreManipulator : PayloadDeliveryRequirement {
		doc /* The mission shall successfully deliver and install the Special Purpose Dexterous 
		       Manipulator (Dextre) robotic system to the ISS. */
		
		subject dextre : DextreRoboticManipulator;
		
		assume constraint { dextre.mass <= 1560[kg] }
		assume constraint { dextre.armReach >= 3.35[m] }
		require constraint { dextre.installationComplete == true }
	}
	
	requirement <'STS123-REQ-003'> maintainCrewSafety : CrewSafetyRequirement {
		doc /* The mission shall maintain crew safety throughout all mission phases and 
		       return all seven crew members safely to Earth. */
		
		attribute crewCount : Integer;
		attribute landingSuccess : Boolean;
		attribute structuralIntegrity : Boolean;
		
		assume constraint { crewCount == 7 }
		require constraint { landingSuccess == true }
		require constraint { structuralIntegrity == true }
	}
	
	requirement <'STS123-REQ-004'> achieveTargetOrbit : OrbitalRequirement {
		doc /* The shuttle shall achieve and maintain orbital altitude between 330 km and 
		       350 km for ISS rendezvous and docking operations. */
		
		attribute orbitalAltitude : LengthValue;
		attribute orbitalVelocity : SpeedValue;
		
		require constraint { orbitalAltitude >= 330[km] and orbitalAltitude <= 350[km] }
		require constraint { orbitalVelocity >= 7.6[km/s] }
	}
	
	requirement <'STS123-REQ-005'> dockingPrecision : MissionObjective {
		doc /* The shuttle shall achieve docking with the ISS with approach velocity 
		       less than 0.1 m/s and alignment error less than 3 degrees. */
		
		attribute approachVelocity : SpeedValue;
		attribute alignmentError : Real;
		
		require constraint { approachVelocity <= 0.1[m/s] }
		require constraint { alignmentError <= 3.0 }
	}
	
	part sts123System : STS123MissionSystem;
	
	part def STS123MissionSystem {
		attribute missionDesignation : String = "STS-123";
		attribute launchDate : String = "March 11, 2008";
		attribute missionDuration : TimeValue = 15.75[day];
		attribute crewSize : CrewCount = 7;
		attribute totalMissionMass : MassValue;
		
		part orbiter : SpaceShuttleEndeavour {
			attribute dryMass = 78000[kg];
			attribute maxPayloadMass = 24400[kg];
		}
		
		part externalTank : ExternalFuelTank {
			attribute totalPropellantCapacity = 728000[kg];
			
			part lox : Propellant {
				attribute mass = 629000[kg];
				attribute temperature = 90[K];
				attribute pressure = 150000[Pa];
			}
			
			part lh2 : Propellant {
				attribute mass = 99000[kg];
				attribute temperature = 20[K];
				attribute pressure = 230000[Pa];
			}
		}
		
		part srbPort : SolidRocketBooster {
			attribute thrustRating = 12500000[N];
			attribute burnDuration = 124[s];
			attribute propellantMass = 503000[kg];
		}
		
		part srbStarboard : SolidRocketBooster {
			attribute thrustRating = 12500000[N];
			attribute burnDuration = 124[s];
			attribute propellantMass = 503000[kg];
		}
		
		part mainEngines : MainEngineCluster {
			attribute engineCount = 3;
			attribute thrustPerEngine = 1860000[N];
		}
		
		part oms : OrbitalManeuveringSystem {
			attribute maxDeltaV = 305[m/s];
			attribute propellantMass = 10500[kg];
		}
		
		part rcs : ReactionControlSystem {
			attribute thrusterCount = 44;
			attribute thrustPerThruster = 3870[N];
		}
		
		part payloadBay : PayloadBay {
			attribute length = 18.3[m];
			attribute diameter = 4.6[m];
			attribute maxCapacity = 24400[kg];
			
			part kiboModule : KiboLogisticsModule {
				attribute mass = 8600[kg];
				attribute length = 4.2[m];
				attribute diameter = 4.4[m];
				attribute storageVolume = 23[m^3];
				attribute transferComplete : Boolean;
			}
			
			part dextre : DextreRoboticManipulator {
				attribute mass = 1560[kg];
				attribute armReach = 3.35[m];
				attribute dexterityJoints = 15;
				attribute payloadHandlingCapacity = 600[kg];
				attribute installationComplete : Boolean;
			}
		}
		
		part gnc : GuidanceNavigationControl;
		
		part targetStation : InternationalSpaceStation {
			attribute orbitalAltitude = 340[km];
			attribute orbitalVelocity = 7.66[km/s];
			attribute mass = 300000[kg];
		}
		
		connection dockingLink connect orbiter.dockingMechanism to targetStation.dockingAdapter;
		connection powerToPayload connect orbiter.mainPower to payloadBay.payloadPower;
		connection dataToPayload connect orbiter.avionics to payloadBay.payloadData;
		connection kiboToStation connect payloadBay.kiboModule.berthing to targetStation.berthingPort;
		
		perform action executeSTS123Mission {
			first start;
			
			then action launch : LaunchSequence {
				in totalMass = 2030000[kg];
				in targetOrbit = 340[km];
				out orbitalVelocity;
				out altitude;
			}
			
			then action ascent : AscentPhase {
				in srbThrust = srbPort.thrustRating + srbStarboard.thrustRating;
				in mainEngineThrust = mainEngines.engineCount * mainEngines.thrustPerEngine;
				in vehicleMass = totalMissionMass;
				out velocity;
				out altitude;
				out acceleration;
			}
			
			then action orbitalInsertion : OrbitalInsertion {
				in currentVelocity = ascent.velocity;
				in targetVelocity = 7660[m/s];
				in omsThrust = oms.maxDeltaV;
				out finalOrbit;
			}
			
			then action rendezvous : RendezvousApproach {
				in shuttlePosition;
				in issPosition;
				in relativeVelocity;
				out approachVector;
				out closingRate;
			}
			
			then action dock : DockingOperation {
				in approachVelocity = rendezvous.closingRate;
				in alignmentError;
				out dockingSuccess;
				out contactForce;
			}
			
			then decide dockingCheck;
				if dock.dockingSuccess then payloadOps;
				else abortSequence;
			
			then merge payloadOps;
			
			then action transferKibo : PayloadTransfer {
				in payload = payloadBay.kiboModule;
				in transferMechanism = "Canadarm2";
				out transferComplete;
				out installationVerified;
			}
			
			then assign payloadBay.kiboModule.transferComplete := transferKibo.transferComplete;
			
			then action installDextre : PayloadTransfer {
				in payload = payloadBay.dextre;
				in transferMechanism = "Canadarm2_SSRMS";
				out transferComplete;
				out installationVerified;
			}
			
			then assign payloadBay.dextre.installationComplete := installDextre.installationVerified;
			
			then action undock : UndockingSequence {
				in separationVelocity = 0.1[m/s];
				out clearanceDistance;
				out undockingComplete;
			}
			
			then action deorbit : DeorbitBurn {
				in currentOrbit = orbitalInsertion.finalOrbit;
				in deltaV = 100[m/s];
				out reentryTrajectory;
			}
			
			then action reentry : AtmosphericReentry {
				in entryVelocity = 7800[m/s];
				in entryAngle = 40.0;
				out heatShieldTemperature;
				out deceleration;
			}
			
			then action landing : TerminalApproachLanding {
				in approachSpeed = 350[km/h];
				in runwayAlignment;
				out touchdownVelocity;
				out landingSuccess;
			}
			
			then done;
			
			then merge abortSequence;
			then action abortAction;
			then done;
		}
		
		state def MissionPhaseStateMachine {
			entry; then prelaunch;
			
			state prelaunch;
			
			state ascent {
				entry; then srbBurn;
				state srbBurn;
				state mainEngineBurn;
				transition srbSeparation first srbBurn then mainEngineBurn;
				transition meco first mainEngineBurn then done;
			}
			
			transition liftoff first prelaunch then ascent;
			
			state onOrbit {
				entry; then rendezvousPhase;
				state rendezvousPhase;
				state docked;
				state freeFlightReturn;
				transition dockingInitiated first rendezvousPhase then docked;
				transition undockInitiated first docked then freeFlightReturn;
			}
			
			transition orbitAchieved first ascent then onOrbit;
			
			state reentryPhase {
				entry; then deorbitBurnComplete;
				state deorbitBurnComplete;
				state atmosphericFlight;
				transition entryInterfaceCrossed first deorbitBurnComplete then atmosphericFlight;
			}
			
			transition deorbitInitiated first onOrbit then reentryPhase;
			
			state landed;
			
			transition touchdownAchieved first reentryPhase then landed;
		}
	}
	
	satisfy deliverKiboModule by sts123System.executeSTS123Mission.transferKibo;
	satisfy deliverDextreManipulator by sts123System.executeSTS123Mission.installDextre;
	satisfy maintainCrewSafety by sts123System.executeSTS123Mission.landing;
	satisfy achieveTargetOrbit by sts123System.executeSTS123Mission.orbitalInsertion;
	satisfy dockingPrecision by sts123System.executeSTS123Mission.dock;
}
