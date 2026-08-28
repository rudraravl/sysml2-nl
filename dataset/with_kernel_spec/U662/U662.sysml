package 'ElectronLaunchVehicleSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;
	public import Definitions::*;

	package Definitions {
		item def TelemetryData {
			attribute altitude : LengthValue;
			attribute velocity : SpeedValue;
			attribute propellantLevel : Real;
			attribute healthStatus : String;
		}
		item def Command;
		item def AbortSignal :> Command;
		item def GuidanceCommand {
			attribute pitch : PlaneAngleValue;
			attribute yaw : PlaneAngleValue;
			attribute roll : PlaneAngleValue;
		}
		item def ThrottleCommand;
		item def SatellitePayload {
			attribute mass : MassValue;
		}

		attribute def 'Launch Authorization';
		attribute def 'Stage Separation';
		attribute def 'Fairing Jettison';
		attribute def 'Kick Stage Ignition';
		attribute def 'Payload Deploy';

		port def TelemetryPort {
			out item telemetry : TelemetryData;
			in item command : Command;
		}
		port def GuidancePort {
			out item guidance : GuidanceCommand;
		}
		port def ThrottlePort {
			out item throttle : ThrottleCommand;
		}

		part def RutherfordEngine {
			attribute isVacuumOptimized : Boolean;
			attribute maxThrust : ForceValue;
			attribute currentThrottle : Real;
			port throttleIn : ~ThrottlePort;
			perform action ignite : IgniteEngine;
		}

		part def FirstStage {
			attribute height : LengthValue = 12.2 [m];
			attribute dryMass : MassValue = 950 [kg];
			part engines : RutherfordEngine[9] {
				:>> isVacuumOptimized = false;
				:>> maxThrust = 24000 [N];
			}
			perform action separate : SeparateStage;
		}

		part def SecondStage {
			attribute height : LengthValue = 3.9 [m];
			attribute dryMass : MassValue = 250 [kg];
			part engine : RutherfordEngine[1] {
				:>> isVacuumOptimized = true;
				:>> maxThrust = 26000 [N];
			}
			perform action separate : SeparateStage;
		}

		part def KickStage {
			attribute dryMass : MassValue = 40 [kg];
			part engine : RutherfordEngine[1] {
				:>> isVacuumOptimized = false;
				:>> maxThrust = 120 [N];
			}
			perform action burn : KickStageBurn;
		}

		part def PayloadFairing {
			attribute height : LengthValue = 2.5 [m];
			attribute mass : MassValue = 50 [kg];
			perform action jettison : JettisonFairing;
		}

		part def PayloadBay {
			attribute maxPayloadMass : MassValue = 300 [kg];
			item payload : SatellitePayload;
			perform action deploy : DeployPayload;
		}

		action def ExecuteFlightSequence;
		action def MonitorHealth {
			out healthStatus : String;
			out criticalFailure : Boolean;
		}
		action def TransmitTelemetry {
			out telemetry : TelemetryData;
		}
		action def IgniteEngine;
		action def SeparateStage;
		action def JettisonFairing;
		action def DeployPayload;
		action def KickStageBurn;

		state def 'Avionics States';

		part def AvionicsSystem {
			port avionicsLink : TelemetryPort;
			port guidanceOut : GuidancePort;
			port throttleOut : ThrottlePort;
			attribute altitude : LengthValue;
			attribute velocity : SpeedValue;
			attribute propellantLevel : Real;
			attribute systemHealth : String;
			perform action executeFlightSequence : ExecuteFlightSequence;
			perform action monitorHealth : MonitorHealth;
			perform action transmitTelemetry : TransmitTelemetry;
			exhibit state 'avionics states' : 'Avionics States' {
				entry; then 'nominal';
				state 'nominal';
				accept when monitorHealth.criticalFailure
					then 'critical';
				state 'critical';
				accept when monitorHealth.criticalFailure == false
					then 'nominal';
			}
		}

		part def ElectronRocket {
			attribute height : LengthValue = 18 [m];
			port groundLink : ~TelemetryPort;
			part firstStage : FirstStage;
			part secondStage : SecondStage;
			part kickStage : KickStage;
			part payloadFairing : PayloadFairing;
			part payloadBay : PayloadBay;
			part avionics : AvionicsSystem;

			flow of telemetry : TelemetryData
				from avionics.avionicsLink.telemetry to groundLink.telemetry;
			flow of command : Command
				from groundLink.command to avionics.avionicsLink.command;

			perform action 'launch sequence' : 'Launch Sequence';
			exhibit state 'flight states' : 'Flight States';
		}

		part def GroundControlStation {
			port rocketLink : ~TelemetryPort;
			perform action 'manage mission' : 'Manage Mission';
			perform action 'perform pre-launch checks' : 'Perform Pre-Launch Checks';
			perform action 'send abort' : 'Send Abort Command';
		}

		action def 'Launch Sequence' {
			action 'pre-launch checks';
			then action 'first stage ascent';
			then action 'stage separation';
			then action 'second stage ascent';
			then action 'fairing jettison';
			then action 'coast';
			then action 'kick stage burn';
			then action 'deploy payload';
		}

		action def 'Manage Mission' {
			in telemetry : TelemetryData;
			out command : Command;
		}

		action def 'Perform Pre-Launch Checks' {
			out checksPassed : Boolean;
		}

		action def 'Send Abort Command' {
			out abortSignal : AbortSignal;
		}

		state def 'Flight States';

		requirement def 'Payload Capacity Requirement' {
			doc /* The rocket shall carry payloads up to 300 kg. */
			subject payloadBay : PayloadBay;
			constraint { payloadBay.maxPayloadMass >= 300 [kg] }
		}

		requirement def 'Orbital Accuracy Requirement' {
			doc /* The system shall place the payload in the exact target orbit. */
			subject kickStage : KickStage;
		}

		requirement def 'Reliability Requirement' {
			doc /* The system shall meet strict reliability standards throughout the autonomous flight sequence. */
			subject rocket : ElectronRocket;
		}

		requirement def 'Flight Safety Requirement' {
			doc /* The system shall support ground-initiated abort commands upon critical system failure. */
			subject groundStation : GroundControlStation;
		}
	}

	package Usages {
		private import Definitions::*;

		part electronSystem {
			part rocket : ElectronRocket;
			part groundStation : GroundControlStation;

			flow of telemetry : TelemetryData
				from rocket.groundLink.telemetry to groundStation.rocketLink.telemetry;

			flow of command : Command
				from groundStation.rocketLink.command to rocket.groundLink.command;
		}

		state 'flight states' : 'Flight States' {
			entry; then 'pre-launch';
			state 'pre-launch';
			accept 'Launch Authorization'
				then 'first stage ascent';
			state 'first stage ascent';
			accept 'Stage Separation'
				then 'second stage ascent';
			accept AbortSignal
				then 'aborted';
			state 'second stage ascent';
			accept 'Fairing Jettison'
				then 'coast';
			accept AbortSignal
				then 'aborted';
			state 'coast';
			accept 'Kick Stage Ignition'
				then 'kick stage burn';
			accept AbortSignal
				then 'aborted';
			state 'kick stage burn';
			accept 'Payload Deploy'
				then 'mission complete';
			accept AbortSignal
				then 'aborted';
			state 'mission complete';
			state 'aborted';
		}

		action 'launch sequence' : 'Launch Sequence' {
			action 'pre-launch checks';
			then action 'first stage ascent';
			then action 'stage separation';
			then action 'second stage ascent';
			then action 'fairing jettison';
			then action 'coast';
			then action 'kick stage burn';
			then action 'deploy payload';
		}

		requirement 'payload capacity' : 'Payload Capacity Requirement' {
			subject :>> payloadBay = electronSystem.rocket.payloadBay;
		}

		requirement 'orbital accuracy' : 'Orbital Accuracy Requirement' {
			subject :>> kickStage = electronSystem.rocket.kickStage;
		}

		requirement 'reliability' : 'Reliability Requirement' {
			subject :>> rocket = electronSystem.rocket;
		}

		requirement 'flight safety' : 'Flight Safety Requirement' {
			subject :>> groundStation = electronSystem.groundStation;
		}
	}
}
