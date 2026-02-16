package 'Cape Canaveral Launch System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def LaunchCommand;
	attribute def AbortCommand;
	attribute def GoCommand;
	attribute def HoldCommand;
	
	attribute def Altitude :> ISQ::LengthValue;
	attribute def Velocity :> ISQ::SpeedValue;
	attribute def Thrust :> ISQ::ForceValue;
	attribute def FuelLevel :> ScalarValues::Real;
	
	item def TelemetryData {
		attribute altitude : Altitude;
		attribute velocity : Velocity;
		attribute thrust : Thrust;
		attribute fuelRemaining : FuelLevel;
	}
	
	item def WeatherData {
		attribute windSpeed : ISQ::SpeedValue;
		attribute temperature : ISQ::TemperatureValue;
		attribute visibility : ISQ::LengthValue;
		attribute cloudCeiling : ISQ::LengthValue;
	}
	
	port def CommandPort {
		out launchCmd : LaunchCommand;
		out abortCmd : AbortCommand;
		out goCmd : GoCommand;
		out holdCmd : HoldCommand;
	}
	
	port def TelemetryPort {
		in telemetry : TelemetryData;
	}
	
	port def WeatherPort {
		in weather : WeatherData;
	}
	
	port def FuelPort {
		out fuelFlow : ISQ::VolumeFlowRateValue;
	}
	
	port def PowerPort {
		out power : ISQ::PowerValue;
	}
	
	part def MissionControl {
		port commandPort : CommandPort;
		port telemetryPort : TelemetryPort;
		port weatherPort : WeatherPort;
		
		perform action monitorMission {
			in telemetryData : TelemetryData;
			in weatherData : WeatherData;
			out decision : Boolean;
		}
		
		perform action issueCommand {
			in goDecision : Boolean;
			out command : LaunchCommand;
		}
	}
	
	part def LaunchPad {
		attribute padId : String;
		
		port fuelInput : FuelPort;
		port powerInput : PowerPort;
		port commandInput : CommandPort;
		
		part holddownArms {
			attribute armCount : Integer;
		}
		
		part serviceStructure {
			attribute height : ISQ::LengthValue;
		}
		
		part flameDeflector {
			attribute capacity : ISQ::PowerValue;
		}
	}
	
	part def PropellantFacility {
		attribute liquidOxygenCapacity : ISQ::VolumeValue;
		attribute liquidHydrogenCapacity : ISQ::VolumeValue;
		attribute rp1Capacity : ISQ::VolumeValue;
		
		port fuelOutput : FuelPort;
		port powerInput : PowerPort;
		
		perform action transferPropellant {
			in requestedVolume : ISQ::VolumeValue;
			in transferRate : ISQ::VolumeFlowRateValue;
			out deliveredVolume : ISQ::VolumeValue;
		}
	}
	
	part def TrackingStation {
		attribute radarRange : ISQ::LengthValue;
		attribute trackingAccuracy : ISQ::LengthValue;
		
		port telemetryOutput : TelemetryPort;
		port powerInput : PowerPort;
		
		perform action trackVehicle {
			in vehiclePosition : ISQ::LengthValue[3];
			in vehicleVelocity : ISQ::SpeedValue[3];
			out trackingData : TelemetryData;
		}
	}
	
	part def RangeSafety {
		port abortOutput : CommandPort;
		port telemetryInput : TelemetryPort;
		port powerInput : PowerPort;
		
		perform action monitorFlightPath {
			in telemetry : TelemetryData;
			out safetyStatus : Boolean;
		}
		
		perform action initiateAbort {
			in unsafeCondition : Boolean;
			out abortSignal : AbortCommand;
		}
	}
	
	part def LaunchVehicle {
		attribute vehicleMass : ISQ::MassValue;
		attribute maxThrust : ISQ::ForceValue;
		attribute stageCount : Integer;
		
		port fuelInput : FuelPort;
		port commandInput : CommandPort;
		port telemetryOutput : TelemetryPort;
		
		state def VehicleState {
			entry; then prelaunch;
			
			state prelaunch;
			state fueling;
			state countdown;
			state ignition;
			state liftoff;
			state ascent;
			state staging;
			state orbit;
			state aborted;
			
			transition first prelaunch
				then fueling;
			transition fueling
				then countdown;
			transition countdown
				then ignition;
			transition ignition
				then liftoff;
			transition liftoff
				then ascent;
			transition ascent
				then staging;
			transition staging
				then orbit;
			transition countdown
				then aborted;
			transition ignition
				then aborted;
			transition liftoff
				then aborted;
			transition ascent
				then aborted;
		}
		
		exhibit state vehicleLifecycle : VehicleState;
	}
	
	part def Payload {
		attribute payloadMass : ISQ::MassValue;
		attribute missionType : String;
		attribute targetOrbit : ISQ::LengthValue;
	}
	
	action def PreFlightChecks {
		in vehicleStatus : Boolean;
		in weatherStatus : Boolean;
		in rangeStatus : Boolean;
		out allSystemsGo : Boolean;
	}
	
	action def LoadPropellant {
		in fuelCapacity : ISQ::VolumeValue;
		in loadRate : ISQ::VolumeFlowRateValue;
		out fuelingComplete : Boolean;
	}
	
	action def CountdownSequence {
		in countdownDuration : ISQ::TimeValue;
		out countdownComplete : Boolean;
	}
	
	action def IgniteEngines {
		in ignitionCommand : LaunchCommand;
		out ignitionConfirmed : Boolean;
	}
	
	action def ReleaseVehicle {
		in thrustLevel : ISQ::ForceValue;
		in minThrust : ISQ::ForceValue;
		out vehicleReleased : Boolean;
	}
	
	action def MonitorAscent {
		in telemetry : TelemetryData;
		out ascentNominal : Boolean;
	}
	
	action def LaunchSequence {
		in launchCommand : LaunchCommand;
		in weatherConditions : WeatherData;
		in vehicleMass : ISQ::MassValue;
		in propellantVolume : ISQ::VolumeValue;
		out launchSuccess : Boolean;
		
		private attribute checksPass : Boolean;
		private attribute fuelingDone : Boolean;
		private attribute countdownDone : Boolean;
		private attribute ignitionDone : Boolean;
		private attribute vehicleAway : Boolean;
		
		first start;
		
		then action preFlightCheck : PreFlightChecks {
			in vehicleStatus = true;
			in weatherStatus = true;
			in rangeStatus = true;
			out allSystemsGo;
		}
		
		then assign checksPass := preFlightCheck.allSystemsGo;
		
		then decide;
			if checksPass then proceedToFueling;
			if not checksPass then abortSequence;
		
		action proceedToFueling : LoadPropellant {
			in fuelCapacity = propellantVolume;
			in loadRate : ISQ::VolumeFlowRateValue;
			out fuelingComplete;
		}
		
		then assign fuelingDone := proceedToFueling.fuelingComplete;
		
		then action countdown : CountdownSequence {
			in countdownDuration : ISQ::TimeValue;
			out countdownComplete;
		}
		
		then assign countdownDone := countdown.countdownComplete;
		
		then action ignition : IgniteEngines {
			in ignitionCommand = launchCommand;
			out ignitionConfirmed;
		}
		
		then assign ignitionDone := ignition.ignitionConfirmed;
		
		then action release : ReleaseVehicle {
			in thrustLevel : ISQ::ForceValue;
			in minThrust : ISQ::ForceValue;
			out vehicleReleased;
		}
		
		then assign vehicleAway := release.vehicleReleased;
		
		then action monitorFlight : MonitorAscent {
			in telemetry : TelemetryData;
			out ascentNominal;
		}
		
		then assign launchSuccess := monitorFlight.ascentNominal;
		then merge endSequence;
		
		action abortSequence {
			then assign launchSuccess := false;
		}
		
		then merge endSequence;
		then done;
	}
	
	requirement def LaunchCapability {
		doc /* The launch complex shall provide capability to prepare, 
		       launch, and track space vehicles to deliver payloads 
		       to specified orbits. */
	}
	
	requirement def SafetyRequirement {
		doc /* The launch complex shall provide continuous monitoring 
		       and abort capability to ensure range safety during 
		       all launch operations. */
	}
	
	requirement def WeatherRequirement {
		doc /* Launch operations shall only proceed when weather 
		       conditions meet specified criteria including wind speed 
		       less than 15 m/s and visibility greater than 5 km. */
	}
	
	part capeCanaveralComplex {
		doc /* Cape Canaveral Launch Complex is a comprehensive space launch 
		       facility that orchestrates the preparation, fueling, launch, 
		       and tracking of space vehicles to deliver payloads into orbit. 
		       Its primary function is to safely execute launch operations 
		       through coordinated activities of mission control, launch pads, 
		       propellant facilities, tracking stations, and range safety systems. */
		
		satisfy requirement launchCapability : LaunchCapability;
		satisfy requirement safetyReq : SafetyRequirement;
		satisfy requirement weatherReq : WeatherRequirement;
		
		part missionControl : MissionControl;
		
		part pad39A : LaunchPad {
			:>> padId = "LC-39A";
		}
		
		part pad39B : LaunchPad {
			:>> padId = "LC-39B";
		}
		
		part propellantFacility : PropellantFacility {
			:>> liquidOxygenCapacity = 3000000.0[SI::L];
			:>> liquidHydrogenCapacity = 2500000.0[SI::L];
			:>> rp1Capacity = 1000000.0[SI::L];
		}
		
		part trackingStation1 : TrackingStation {
			:>> radarRange = 500000.0[SI::m];
			:>> trackingAccuracy = 10.0[SI::m];
		}
		
		part trackingStation2 : TrackingStation {
			:>> radarRange = 500000.0[SI::m];
			:>> trackingAccuracy = 10.0[SI::m];
		}
		
		part rangeSafety : RangeSafety;
		
		part vehicle : LaunchVehicle {
			:>> vehicleMass = 550000.0[SI::kg];
			:>> maxThrust = 7500000.0[SI::N];
			:>> stageCount = 2;
		}
		
		part payload : Payload {
			:>> payloadMass = 22000.0[SI::kg];
			:>> missionType = "Satellite Deployment";
			:>> targetOrbit = 400000.0[SI::m];
		}
		
		connection fuelSupply39A connect propellantFacility.fuelOutput to pad39A.fuelInput;
		connection fuelSupply39B connect propellantFacility.fuelOutput to pad39B.fuelInput;
		connection fuelToVehicle connect pad39A.fuelInput to vehicle.fuelInput;
		
		connection commandToVehicle connect missionControl.commandPort to vehicle.commandInput;
		connection commandToPad connect missionControl.commandPort to pad39A.commandInput;
		
		connection telemetryFromVehicle connect vehicle.telemetryOutput to trackingStation1.telemetryInput;
		connection telemetryToControl connect trackingStation1.telemetryOutput to missionControl.telemetryPort;
		connection telemetryToSafety connect trackingStation1.telemetryOutput to rangeSafety.telemetryInput;
		
		connection abortToVehicle connect rangeSafety.abortOutput to vehicle.commandInput;
		
		perform action executeLaunch : LaunchSequence {
			in launchCommand : LaunchCommand;
			in weatherConditions : WeatherData {
				:>> windSpeed = 8.0[SI::m/SI::s];
				:>> temperature = 293.0[SI::K];
				:>> visibility = 15000.0[SI::m];
				:>> cloudCeiling = 3000.0[SI::m];
			}
			in vehicleMass = vehicle.vehicleMass;
			in propellantVolume = 2000000.0[SI::L];
			out launchSuccess : Boolean;
		}
	}
}
