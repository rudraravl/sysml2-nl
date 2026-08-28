package 'Cape Canaveral Launch Complex' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Time::*;

	item def TelemetryData {
		attribute altitude : LengthValue;
		attribute velocity : SpeedValue;
		attribute thrust : ForceValue;
		attribute fuelLevel : MassValue;
	}

	attribute def WeatherData {
		attribute windSpeed : SpeedValue;
		attribute lightningRisk : Boolean;
		attribute clear : Boolean;
	}

	attribute def Command {
		attribute commandType : String;
	}

	item def LiquidOxygen;
	item def LiquidHydrogen;
	item def RP1;

	item def Propellant {
		attribute type : String;
		attribute mass : MassValue;
	}

	item def RadarData {
		attribute position : LengthValue;
		attribute velocity : SpeedValue;
	}

	attribute def GoCommand :> Command;
	attribute def HoldCommand :> Command;
	attribute def LaunchCommand :> Command;
	attribute def AbortCommand :> Command;
	attribute def ReleaseCommand :> Command;
	attribute def PropellantTransferComplete;

	port def CommandPort {
		out command : Command;
	}
	port def TelemetryPort {
		out telemetry : TelemetryData;
	}
	port def PropellantPort {
		out propellant : Propellant;
	}
	port def RadarPort {
		out radarData : RadarData;
	}

	action def PerformChecks { out result : Boolean; }
	action def TransferPropellant { out propellant : Propellant; }
	action def IgniteEngines { out thrust : ForceValue; }
	action def ReleaseHoldDownArms;
	action def TrackVehicle { out radarData : RadarData; }
	action def MonitorFlightPath { in telemetry : TelemetryData; in radarData : RadarData; out safe : Boolean; }
	action def DeployPayload;
	action def AssessWeather { in weather : WeatherData; out goForLaunch : Boolean; }
	action def SendTelemetry { out telemetry : TelemetryData; }

	state def LaunchVehicleStates;
	state def MissionControlStates;
	state def LaunchPadStates;
	state def PropellantFacilityStates;
	state def TrackingStationStates;
	state def RangeSafetyStates;

	part def Payload {
		attribute mass : MassValue;
		attribute targetOrbitAltitude : LengthValue;
		attribute targetOrbitInclination : Real;
	}

	part def LaunchPad {
		attribute padName : String;
		attribute holdDownArmsEngaged : Boolean = true;
		attribute flameDeflectorActive : Boolean = false;
		port commandIn : CommandPort;
		port propellantIn : PropellantPort;
		port propellantOut : PropellantPort;
		exhibit state padStates : LaunchPadStates;
	}

	part def PropellantFacility {
		attribute loxStorage : MassValue;
		attribute lh2Storage : MassValue;
		attribute rp1Storage : MassValue;
		port propellantOut : PropellantPort;
		port commandOut : CommandPort;
		exhibit state facilityStates : PropellantFacilityStates;
	}

	part def TrackingStation {
		port telemetryOut : TelemetryPort;
		port radarOut : RadarPort;
		exhibit state trackingStates : TrackingStationStates;
	}

	part def RangeSafety {
		port telemetryIn : TelemetryPort;
		port radarIn : RadarPort;
		port commandOut : CommandPort;
		exhibit state safetyStates : RangeSafetyStates;
	}

	part def MissionControl {
		port telemetryIn : TelemetryPort;
		port commandOut : CommandPort;
		attribute weatherData : WeatherData;
		exhibit state controlStates : MissionControlStates;
	}

	part def LaunchVehicle {
		part payload : Payload;
		port telemetryOut : TelemetryPort;
		port commandIn : CommandPort;
		port propellantIn : PropellantPort;
		attribute requiredThrust : ForceValue;
		attribute currentThrust : ForceValue;
		attribute currentAltitude : LengthValue;
		attribute currentFuel : MassValue;
		attribute requiredFuel : MassValue;
		attribute targetOrbitAltitude : LengthValue;
		exhibit state vehicleStates : LaunchVehicleStates;
	}

	part def LaunchComplex {
		part missionControl : MissionControl;
		part launchVehicle : LaunchVehicle;
		part pad39A : LaunchPad;
		part pad39B : LaunchPad;
		part propellantFacility : PropellantFacility;
		part trackingStation : TrackingStation;
		part rangeSafety : RangeSafety;
	}

	requirement def LaunchSequenceRequirement {
		doc /* The launch sequence must follow: prelaunch checks, fueling, countdown, ignition, liftoff, ascent, orbit. */
		subject lc : LaunchComplex;
	}

	requirement def SafetyRequirement {
		doc /* Range Safety must issue an abort command if the vehicle deviates from the planned trajectory. */
		subject rs : RangeSafety;
	}

	requirement def PayloadDeliveryRequirement {
		doc /* The launch vehicle shall deliver the payload to the specified target orbit. */
		subject lv : LaunchVehicle;
	}

	requirement def TelemetryRequirement {
		doc /* Mission Control shall continuously receive and process telemetry data during flight. */
		subject mc : MissionControl;
	}

	part launchComplex : LaunchComplex {
		connect missionControl.commandOut to launchVehicle.commandIn;
		connect missionControl.commandOut to pad39A.commandIn;
		connect missionControl.commandOut to pad39B.commandIn;
		connect launchVehicle.telemetryOut to missionControl.telemetryIn;
		connect trackingStation.telemetryOut to missionControl.telemetryIn;
		connect trackingStation.telemetryOut to rangeSafety.telemetryIn;
		connect rangeSafety.commandOut to launchVehicle.commandIn;
		connect propellantFacility.propellantOut to pad39A.propellantIn;
		connect propellantFacility.propellantOut to pad39B.propellantIn;
		connect pad39A.propellantOut to launchVehicle.propellantIn;
		connect pad39B.propellantOut to launchVehicle.propellantIn;
		connect trackingStation.radarOut to rangeSafety.radarIn;
		connect propellantFacility.commandOut to pad39A.commandIn;
		connect propellantFacility.commandOut to pad39B.commandIn;
	}

	action performChecks : PerformChecks;
	action igniteEngines : IgniteEngines;
	action releaseHoldDownArms : ReleaseHoldDownArms;
	action trackVehicle : TrackVehicle;
	action monitorFlightPath : MonitorFlightPath;
	action deployPayload : DeployPayload;
	action assessWeather : AssessWeather;
	action sendTelemetry : SendTelemetry;
	action facilityTransfer : TransferPropellant;

	state vehicleStates : LaunchVehicleStates {
		in vehicle : LaunchVehicle;
		entry; then prelaunch;
		state prelaunch {
			do performChecks { out result; }
		}
		accept when performChecks.result == true
			then fueling;
		state fueling;
		accept when vehicle.currentFuel >= vehicle.requiredFuel
			then countdown;
		state countdown;
		accept LaunchCommand
			then ignition;
		state ignition {
			do igniteEngines { out thrust; }
		}
		accept when igniteEngines.thrust >= vehicle.requiredThrust
			then liftoff;
		state liftoff;
		accept after 10 [s]
			then ascent;
		state ascent {
			do sendTelemetry { out telemetry; }
		}
		accept when sendTelemetry.telemetry.altitude >= vehicle.targetOrbitAltitude
			then orbit;
		state orbit {
			do deployPayload;
		}
		accept AbortCommand
			then aborted;
		state aborted;
	}

	state controlStates : MissionControlStates {
		in mc : MissionControl;
		entry; then monitoring;
		state monitoring {
			do assessWeather { in weather = mc.weatherData; out goForLaunch; }
		}
		accept when assessWeather.goForLaunch == true
			do send new GoCommand() to mc.commandOut
			then ready;
		state ready;
		accept when assessWeather.goForLaunch == false
			do send new HoldCommand() to mc.commandOut
			then monitoring;
		accept after 10 [s]
			do send new LaunchCommand() to mc.commandOut
			then launching;
		state launching;
		accept after 5 [s]
			do send new ReleaseCommand() to mc.commandOut
			then monitoring;
	}

	state padStates : LaunchPadStates {
		in pad : LaunchPad;
		entry; then idle;
		state idle;
		accept GoCommand
			then fueling;
		state fueling;
		accept PropellantTransferComplete
			then ready;
		state ready;
		accept LaunchCommand
			then ignition;
		state ignition;
		accept ReleaseCommand
			do releaseHoldDownArms
			then postLaunch;
		state postLaunch;
	}

	state facilityStates : PropellantFacilityStates {
		in facility : PropellantFacility;
		entry; then standby;
		state standby;
		accept GoCommand
			then transferring;
		state transferring {
			do facilityTransfer { out propellant; }
		}
		accept when facilityTransfer.propellant.mass >= 100000 [kg]
			do send new PropellantTransferComplete() to facility.commandOut
			then standby;
	}

	state trackingStates : TrackingStationStates {
		in station : TrackingStation;
		entry; then idle;
		state idle;
		accept LaunchCommand
			then tracking;
		state tracking {
			do trackVehicle { out radarData; }
		}
		accept when trackVehicle.radarData.position >= 100000 [m]
			then idle;
	}

	state safetyStates : RangeSafetyStates {
		in safety : RangeSafety;
		entry; then monitoring;
		state monitoring {
			do monitorFlightPath { in telemetry = safety.telemetryIn.telemetry; in radarData = safety.radarIn.radarData; out safe; }
		}
		accept when monitorFlightPath.safe == false
			do send new AbortCommand() to safety.commandOut
			then abort;
		state abort;
	}
}
