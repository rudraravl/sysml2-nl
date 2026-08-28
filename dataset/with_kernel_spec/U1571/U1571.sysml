package 'Autonomous Orbital Spacecraft Mission' {
	private import ScalarValues::*;

	package Definitions {
		attribute def Altitude :> Real;
		attribute def DeltaV :> Real;
		attribute def ThrustForce :> Real;
		attribute def PowerOutput :> Real;
		attribute def PropellantMass :> Real;
		attribute def Duration :> Real;
		attribute def DataRate :> Real;
		attribute def AngleValue :> Real;

		item def ElectricalPower;
		item def TelemetryData;
		item def CommandData;
		item def PayloadData;
		item def PositionData {
			attribute altitude : Altitude;
			attribute velocity : DeltaV;
		}
		item def AttitudeData {
			attribute roll : AngleValue;
			attribute pitch : AngleValue;
			attribute yaw : AngleValue;
		}
		item def ThrustCommand {
			attribute magnitude : ThrustForce;
			attribute duration : Duration;
		}

		attribute def SeparationSignal;
		attribute def OrbitInsertionComplete;
		attribute def PayloadActivateCommand;
		attribute def PayloadDeactivateCommand;
		attribute def DeploymentComplete;
		attribute def MissionCompleteSignal;
		attribute def EclipseEntrySignal;
		attribute def SunlightEntrySignal;

		port def PowerOutPort { out power : ElectricalPower; }
		port def PowerInPort { in power : ElectricalPower; }
		port def ThrustCmdOutPort { out cmd : ThrustCommand; }
		port def ThrustCmdInPort { in cmd : ThrustCommand; }
		port def GncDataOutPort { out position : PositionData; out attitude : AttitudeData; }
		port def GncDataInPort { in position : PositionData; in attitude : AttitudeData; }
		port def PayloadDataOutPort { out data : PayloadData; }
		port def PayloadDataInPort { in data : PayloadData; }
		port def SpacecraftCommsPort { out telemetry : TelemetryData; in commands : CommandData; }
		port def GroundCommsPort { in telemetry : TelemetryData; out commands : CommandData; }

		action def InitializeSystems;
		action def DeterminePosition { out position : PositionData; }
		action def DetermineAttitude { out attitude : AttitudeData; }
		action def CalculateBurn { in position : PositionData; in targetAltitude : Altitude; out cmd : ThrustCommand; }
		action def ExecuteBurn { in cmd : ThrustCommand; out thrust : ThrustForce; }
		action def GenerateSolarPower { out power : ElectricalPower; }
		action def ChargeBattery { in power : ElectricalPower; }
		action def DischargeBattery { out power : ElectricalPower; }
		action def TransmitTelemetry { in telemetry : TelemetryData; }
		action def ReceiveCommands { out commands : CommandData; }
		action def OperatePayload { out data : PayloadData; }
		action def DeployPayload;

		action def DetermineNavState {
			action determinePosition : DeterminePosition;
			action determineAttitude : DetermineAttitude;
		}
		action def ExecuteOrbitRaise {
			action calculateBurn : CalculateBurn;
			action executeBurn : ExecuteBurn;
			action determinePosition : DeterminePosition;
		}
		action def OnStationOps {
			action operatePayload : OperatePayload;
			action transmitTelemetry : TransmitTelemetry;
		}
		action def SolarOperations {
			action generateSolarPower : GenerateSolarPower;
			action chargeBattery : ChargeBattery;
		}

		state def SpacecraftMissionStates;
		state def GncOperationalStates;
		state def EpsOperationalStates;
		state def PayloadOperationalStates;

		part def GroundControlStation {
			port commsPort : GroundCommsPort;
			perform action 'send commands' : ReceiveCommands;
			perform action 'receive telemetry' : TransmitTelemetry;
		}

		part def Spacecraft {
			port groundLink : SpacecraftCommsPort;
			attribute missionDuration : Duration;
			exhibit state 'mission states' : SpacecraftMissionStates;
		}

		part def GncSubsystem {
			port thrustCmdOut : ThrustCmdOutPort;
			port gncDataOut : GncDataOutPort;
			port powerIn : PowerInPort;
			attribute targetAltitude : Altitude;
			perform action 'determine position' : DeterminePosition;
			perform action 'determine attitude' : DetermineAttitude;
			perform action 'calculate burn' : CalculateBurn;
			exhibit state 'gnc states' : GncOperationalStates;
		}

		part def PropulsionSubsystem {
			port thrustCmdIn : ThrustCmdInPort;
			port powerIn : PowerInPort;
			attribute propellantCapacity : PropellantMass;
			attribute propellantRemaining : PropellantMass;
			perform action 'execute burn' : ExecuteBurn;
		}

		part def EpsSubsystem {
			port powerOut : PowerOutPort;
			attribute solarArrayPower : PowerOutput;
			attribute batteryCapacity : PowerOutput;
			attribute inEclipse : Boolean;
			perform action 'generate solar power' : GenerateSolarPower;
			perform action 'charge battery' : ChargeBattery;
			perform action 'discharge battery' : DischargeBattery;
			exhibit state 'eps states' : EpsOperationalStates;
		}

		part def CommunicationsSubsystem {
			port payloadDataIn : PayloadDataInPort;
			port gncDataIn : GncDataInPort;
			port powerIn : PowerInPort;
			port groundLink : SpacecraftCommsPort;
			attribute downlinkRate : DataRate;
			attribute uplinkRate : DataRate;
			perform action 'transmit telemetry' : TransmitTelemetry;
			perform action 'receive commands' : ReceiveCommands;
		}

		part def PayloadSubsystem {
			port payloadDataOut : PayloadDataOutPort;
			port powerIn : PowerInPort;
			attribute powerDraw : PowerOutput;
			perform action 'operate payload' : OperatePayload;
			perform action 'deploy payload' : DeployPayload;
			exhibit state 'payload states' : PayloadOperationalStates;
		}

		requirement def OrbitalAccuracyRequirement {
			attribute targetAltitude : Altitude;
			attribute altitudeTolerance : Altitude;
			doc
			/* The spacecraft shall achieve and maintain the target
			 * operational orbit within the specified altitude tolerance. */
		}

		requirement def PropulsiveCapabilityRequirement {
			attribute requiredDeltaV : DeltaV;
			attribute minPropellant : PropellantMass;
			doc
			/* The propulsion subsystem shall provide sufficient delta-V
			 * capability using the available propellant to complete all
			 * mission maneuvers. */
		}

		requirement def PowerGenerationRequirement {
			attribute minPowerOutput : PowerOutput;
			doc
			/* The electrical power subsystem shall generate sufficient
			 * power to support all spacecraft operations including
			 * payload activity. */
		}

		requirement def CommunicationsReliabilityRequirement {
			attribute minDownlinkRate : DataRate;
			attribute minUplinkRate : DataRate;
			doc
			/* The communications subsystem shall maintain reliable
			 * telemetry downlink and command uplink with the ground
			 * control station. */
		}

		requirement def MissionSuccessRequirement {
			doc
			/* The spacecraft shall complete its mission: reach target
			 * orbit, deploy payload, and operate for the designed
			 * mission duration. */
		}
	}

	import Definitions::*;

	package Usages {
		private import Definitions::*;

		action 'initialize systems' : InitializeSystems;
		action 'determine position' : DeterminePosition;
		action 'determine attitude' : DetermineAttitude;
		action 'calculate burn' : CalculateBurn;
		action 'execute burn' : ExecuteBurn;
		action 'generate solar power' : GenerateSolarPower;
		action 'charge battery' : ChargeBattery;
		action 'discharge battery' : DischargeBattery;
		action 'transmit telemetry' : TransmitTelemetry;
		action 'receive commands' : ReceiveCommands;
		action 'operate payload' : OperatePayload;
		action 'deploy payload' : DeployPayload;
		action 'determine nav state' : DetermineNavState;
		action 'execute orbit raise' : ExecuteOrbitRaise;
		action 'on station ops' : OnStationOps;
		action 'solar operations' : SolarOperations;

		part groundStation : GroundControlStation;

		part spacecraft : Spacecraft {
			part gnc : GncSubsystem;
			part propulsion : PropulsionSubsystem;
			part eps : EpsSubsystem;
			part comms : CommunicationsSubsystem;
			part payload : PayloadSubsystem;

			connect eps.powerOut to gnc.powerIn;
			connect eps.powerOut to propulsion.powerIn;
			connect eps.powerOut to comms.powerIn;
			connect eps.powerOut to payload.powerIn;
			connect gnc.thrustCmdOut to propulsion.thrustCmdIn;
			connect payload.payloadDataOut to comms.payloadDataIn;
			connect gnc.gncDataOut to comms.gncDataIn;
		}

		connect spacecraft.groundLink to groundStation.commsPort;

		state 'mission states' : SpacecraftMissionStates {
			entry; then awaitingSeparation;
			state awaitingSeparation {
				entry 'initialize systems';
				do 'determine nav state';
			}
			accept SeparationSignal then orbitRaising;
			state orbitRaising {
				do 'execute orbit raise';
			}
			accept OrbitInsertionComplete then onStation;
			state onStation {
				entry 'deploy payload';
				do 'on station ops';
			}
			accept MissionCompleteSignal then decommissioned;
			state decommissioned;
		}

		state 'gnc states' : GncOperationalStates {
			entry; then initializing;
			state initializing;
			accept SeparationSignal then navigating;
			state navigating {
				do 'determine nav state';
			}
			accept OrbitInsertionComplete then stationKeeping;
			state stationKeeping {
				do 'determine position';
			}
		}

		state 'eps states' : EpsOperationalStates {
			entry; then sunlight;
			state sunlight {
				do 'solar operations';
			}
			accept EclipseEntrySignal then eclipse;
			state eclipse {
				do 'discharge battery';
			}
			accept SunlightEntrySignal then sunlight;
		}

		state 'payload states' : PayloadOperationalStates {
			entry; then stowed;
			state stowed;
			accept PayloadActivateCommand then deploying;
			state deploying {
				entry 'deploy payload';
			}
			accept DeploymentComplete then operational;
			state operational {
				do 'operate payload';
			}
			accept PayloadDeactivateCommand then stowed;
		}

		requirement orbitalAccuracy : OrbitalAccuracyRequirement {
			attribute targetAltitude : Altitude;
			attribute altitudeTolerance : Altitude;
		}
		requirement propulsiveCapability : PropulsiveCapabilityRequirement {
			attribute requiredDeltaV : DeltaV;
			attribute minPropellant : PropellantMass;
		}
		requirement powerGeneration : PowerGenerationRequirement {
			attribute minPowerOutput : PowerOutput;
		}
		requirement commsReliability : CommunicationsReliabilityRequirement {
			attribute minDownlinkRate : DataRate;
			attribute minUplinkRate : DataRate;
		}
		requirement missionSuccess : MissionSuccessRequirement;

		satisfy orbitalAccuracy by spacecraft;
		satisfy propulsiveCapability by spacecraft.propulsion;
		satisfy powerGeneration by spacecraft.eps;
		satisfy commsReliability by spacecraft.comms;
		satisfy missionSuccess by spacecraft;
	}
}
