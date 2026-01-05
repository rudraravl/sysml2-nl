package AutonomousUnderwaterVehicleSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def BatteryChargeLevel :> Real;
	
	attribute def GPSCoordinate {
		attribute latitude : Real;
		attribute longitude : Real;
	}
	
	attribute def Waypoint {
		attribute position : GPSCoordinate;
		attribute targetDepth : LengthValue;
		attribute surveySpeed : SpeedValue;
	}
	
	attribute def MissionPlan {
		attribute waypoints : Waypoint[1..*] ordered;
		attribute missionId : String;
	}
	
	attribute def VehiclePose {
		attribute position : GPSCoordinate;
		attribute depth : LengthValue;
		attribute heading : Real;
		attribute speed : SpeedValue;
	}
	
	item def SensorReading {
		attribute timestamp : Real;
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute salinity : Real;
	}
	
	item def ImageData {
		attribute timestamp : Real;
		attribute resolution : String;
		attribute dataSize : Real;
	}
	
	item def SonarData {
		attribute timestamp : Real;
		attribute range : LengthValue;
		attribute bearing : Real;
	}
	
	item def ThrustCommand {
		attribute forwardThrust : ForceValue;
		attribute lateralThrust : ForceValue;
		attribute verticalThrust : ForceValue;
	}
	
	item def NavigationCommand {
		attribute targetHeading : Real;
		attribute targetDepth : LengthValue;
		attribute targetSpeed : SpeedValue;
	}
	
	item def MissionLoadedSignal;
	item def MissionCompleteSignal;
	item def EmergencySignal;
	
	port def PowerPort {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	port def DataPort {
		out item dataPacket;
	}
	
	port def ControlPort {
		in item command;
		out item status;
	}
	
	part def BatteryPack {
		attribute capacity : EnergyValue;
		attribute chargeLevel : BatteryChargeLevel;
		port powerOutput : PowerPort;
		
		action def SupplyPower {
			in powerDemand : PowerValue;
			out availablePower : PowerValue;
			out updatedCharge : BatteryChargeLevel;
		}
	}
	
	part def PropulsionSystem {
		attribute maxThrust : ForceValue;
		port powerInput : PowerPort;
		port controlInput : ControlPort;
		
		part forwardThruster {
			attribute thrustCapacity : ForceValue;
		}
		part verticalThruster {
			attribute thrustCapacity : ForceValue;
		}
		part lateralThruster {
			attribute thrustCapacity : ForceValue;
		}
		
		action def GenerateThrust {
			in command : ThrustCommand;
			in powerAvailable : PowerValue;
			out actualThrust : ThrustCommand;
			out powerConsumed : PowerValue;
		}
	}
	
	part def NavigationSystem {
		attribute currentPose : VehiclePose;
		port powerInput : PowerPort;
		port dataOutput : DataPort;
		
		part imu {
			attribute accuracy : Real;
		}
		part depthSensor {
			attribute maxDepth : LengthValue;
			attribute resolution : LengthValue;
		}
		part gpsReceiver {
			attribute accuracy : LengthValue;
		}
		part doppler {
			attribute velocityAccuracy : SpeedValue;
		}
		
		action def UpdatePose {
			in sensorInputs;
			in previousPose : VehiclePose;
			out updatedPose : VehiclePose;
		}
		
		action def ComputeNavigation {
			in currentPose : VehiclePose;
			in targetWaypoint : Waypoint;
			out navCommand : NavigationCommand;
		}
	}
	
	part def SensorPayload {
		port powerInput : PowerPort;
		port dataOutput : DataPort;
		
		part ctdSensor {
			attribute samplingRate : FrequencyValue;
		}
		part camera {
			attribute resolution : String;
			attribute frameRate : FrequencyValue;
		}
		part sonar {
			attribute frequency : FrequencyValue;
			attribute maxRange : LengthValue;
		}
		
		action def CollectEnvironmentalData {
			out reading : SensorReading;
		}
		
		action def CaptureImage {
			out image : ImageData;
		}
		
		action def PerformSonarScan {
			out scan : SonarData;
		}
	}
	
	part def MissionController {
		attribute activeMission : MissionPlan;
		attribute currentWaypointIndex : Integer;
		port powerInput : PowerPort;
		port navigationInput : DataPort;
		port propulsionControl : ControlPort;
		port sensorControl : ControlPort;
		
		action def PlanTrajectory {
			in currentPose : VehiclePose;
			in targetWaypoint : Waypoint;
			out trajectory : NavigationCommand[*];
		}
		
		action def ComputeThrustCommands {
			in navCommand : NavigationCommand;
			in currentPose : VehiclePose;
			out thrustCmd : ThrustCommand;
		}
		
		action def DescendToDepth {
			in targetDepth : LengthValue;
			out depthReached : Boolean;
		}
		
		action def NavigateToWaypoint {
			in waypoint : Waypoint;
			out arrived : Boolean;
		}
		
		action def PerformSurvey {
			out surveyComplete : Boolean;
		}
		
		action def AscendToSurface {
			out surfaceReached : Boolean;
		}
		
		state def MissionStateMachine {
			entry; then standby;
			
			state standby {
				entry assign currentWaypointIndex := 0;
			}
			
			transition standby_to_descent
				first standby
				accept missionLoaded : MissionLoadedSignal
				then descending;
			
			state descending {
				do descendAction : DescendToDepth;
			}
			
			transition descending_to_transit
				first descending
				if descendAction.depthReached
				then transiting;
			
			state transiting {
				do navigateAction : NavigateToWaypoint;
			}
			
			transition transiting_to_surveying
				first transiting
				if navigateAction.arrived
				then surveying;
			
			state surveying {
				do surveyAction : PerformSurvey;
			}
			
			transition surveying_to_transiting
				first surveying
				if surveyAction.surveyComplete and currentWaypointIndex < activeMission.waypoints->size()
				then transiting;
			
			transition surveying_to_ascending
				first surveying
				if surveyAction.surveyComplete and currentWaypointIndex >= activeMission.waypoints->size()
				then ascending;
			
			state ascending {
				do ascendAction : AscendToSurface;
			}
			
			transition ascending_to_recovery
				first ascending
				if ascendAction.surfaceReached
				then recovery;
			
			state recovery;
			
			transition recovery_to_standby
				first recovery
				accept missionComplete : MissionCompleteSignal
				then standby;
			
			transition emergency_abort
				first transiting
				accept emergencySignal : EmergencySignal
				then ascending;
		}
	}
	
	part def CommunicationSystem {
		attribute linkStatus : String;
		port powerInput : PowerPort;
		port dataInput : DataPort;
		
		part acousticModem {
			attribute dataRate : Real;
			attribute range : LengthValue;
		}
		part satelliteTransceiver {
			attribute bandwidth : Real;
		}
		
		action def TransmitData {
			in dataPacket;
			out transmissionStatus : String;
		}
		
		action def ReceiveMissionUpdate {
			out updatedMission : MissionPlan;
		}
	}
	
	part def AutonomousUnderwaterVehicle {
		attribute vehicleMass : MassValue;
		attribute maxOperatingDepth : LengthValue;
		attribute cruiseSpeed : SpeedValue;
		
		part battery : BatteryPack {
			attribute capacity = 50000.0[J];
			attribute chargeLevel = 100.0;
		}
		
		part propulsion : PropulsionSystem {
			attribute maxThrust = 500.0[N];
		}
		
		part navigation : NavigationSystem;
		
		part sensors : SensorPayload;
		
		part controller : MissionController;
		
		part communications : CommunicationSystem;
		
		part hull {
			attribute volume : VolumeValue;
			attribute buoyancy : ForceValue;
		}
		
		connection batteryToPropulsion connect battery.powerOutput to propulsion.powerInput;
		connection batteryToNavigation connect battery.powerOutput to navigation.powerInput;
		connection batteryToSensors connect battery.powerOutput to sensors.powerInput;
		connection batteryToController connect battery.powerOutput to controller.powerInput;
		connection batteryToComms connect battery.powerOutput to communications.powerInput;
		
		connection navToController connect navigation.dataOutput to controller.navigationInput;
		connection controllerToPropulsion connect controller.propulsionControl to propulsion.controlInput;
		connection controllerToSensors connect controller.sensorControl to sensors.dataOutput;
		connection sensorsToComms connect sensors.dataOutput to communications.dataInput;
	}
	
	action def ExecuteAutonomousMission {
		in missionPlan : MissionPlan;
		in initialPose : VehiclePose;
		in initialCharge : BatteryChargeLevel;
		out collectedData : SensorReading[*] := ( );
		out missionStatus : String;
		
		private attribute pose := initialPose;
		private attribute charge := initialCharge;
		private attribute dataBuffer : SensorReading[*] := ( );
		
		first start;
		
		then action loadMission {
			in mission = missionPlan;
			out validated : Boolean;
		}
		
		then action descendToOperatingDepth {
			in targetDepth : LengthValue = missionPlan.waypoints->at(1).targetDepth;
			out currentDepth : LengthValue;
		}
		
		then merge waypointLoop;
		
		for waypoint in missionPlan.waypoints {
			action navigateToWaypoint {
				in target = waypoint;
				in current = pose;
				out newPose : VehiclePose;
			}
			then action arriveAtWaypoint {
				in position = navigateToWaypoint.newPose;
				out stabilized : Boolean;
			}
			then action collectData {
				out reading : SensorReading;
			}
			then assign dataBuffer := dataBuffer->including(collectData.reading);
			then assign pose := navigateToWaypoint.newPose;
			
			then action monitorBattery {
				in currentCharge = charge;
				out sufficient : Boolean;
			}
			then decide;
				if monitorBattery.sufficient then waypointLoop;
				if not monitorBattery.sufficient then emergencyAscent;
		}
		
		then action ascendToSurface {
			in currentDepth = pose.depth;
			out surfaced : Boolean;
		}
		then action transmitCollectedData {
			in data = dataBuffer;
			out transmissionComplete : Boolean;
		}
		then assign collectedData := dataBuffer;
		then assign missionStatus := "completed";
		then done;
		
		action emergencyAscent {
			out surfaced : Boolean;
		}
		then assign missionStatus := "aborted_low_battery";
		then done;
	}
	
	requirement def <'AUV-REQ-001'> AutonomousOperationRequirement {
		doc /* The AUV shall autonomously execute underwater survey missions by 
		     navigating through predefined waypoints, collecting environmental and 
		     imaging data, and returning to the surface for data transmission without 
		     continuous human intervention. */
		
		subject vehicle : AutonomousUnderwaterVehicle;
		
		require constraint {
			vehicle.controller.MissionStateMachine != null
		}
	}
	
	requirement def <'AUV-REQ-002'> DepthCapabilityRequirement {
		doc /* The AUV shall operate at depths up to 1000 meters. */
		
		subject vehicle : AutonomousUnderwaterVehicle;
		
		require constraint {
			vehicle.maxOperatingDepth >= 1000.0[m]
		}
	}
	
	requirement def <'AUV-REQ-003'> EnduranceRequirement {
		doc /* The AUV shall maintain continuous operation for at least 12 hours 
		     on a single battery charge under nominal survey conditions. */
		
		subject battery : BatteryPack;
		
		require constraint {
			battery.capacity >= 43200000.0[J]
		}
	}
	
	requirement def <'AUV-REQ-004'> NavigationAccuracyRequirement {
		doc /* The AUV shall maintain position accuracy within 5 meters during 
		     waypoint navigation. */
		
		subject navSystem : NavigationSystem;
		
		require constraint {
			navSystem.gpsReceiver.accuracy <= 5.0[m]
		}
	}
	
	requirement def <'AUV-REQ-005'> DataCollectionRequirement {
		doc /* The AUV shall collect environmental data including temperature, 
		     pressure, salinity, and high-resolution imagery at each waypoint. */
		
		subject payload : SensorPayload;
		
		require constraint {
			payload.ctdSensor != null and payload.camera != null
		}
	}
	
	requirement def <'AUV-REQ-006'> CommunicationRequirement {
		doc /* The AUV shall transmit collected data to a surface station upon 
		     mission completion with latency less than 60 seconds. */
		
		subject comms : CommunicationSystem;
	}
	
	requirement <'AUV-SYS-REQ'> systemRequirements {
		doc /* Top-level requirements for the autonomous underwater vehicle system 
		     to perform deep-sea exploration and oceanographic data collection. */
		
		require AutonomousOperationRequirement;
		require DepthCapabilityRequirement;
		require EnduranceRequirement;
		require NavigationAccuracyRequirement;
		require DataCollectionRequirement;
		require CommunicationRequirement;
	}
	
	action primaryMissionFunction : ExecuteAutonomousMission {
		doc /* Primary Function: The autonomous underwater vehicle autonomously executes 
		     oceanographic survey missions by descending to operating depth, navigating 
		     through a series of predefined waypoints while collecting environmental sensor 
		     data and imagery, then ascending to the surface to transmit the collected data 
		     to operators. The system operates independently without real-time human control, 
		     managing its navigation, data collection, and energy resources to complete the 
		     mission successfully. */
	}
}
