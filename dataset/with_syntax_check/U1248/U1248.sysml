package UnmannedVehicleSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import SequenceFunctions::*;
	
	attribute def Coordinate {
		attribute latitude : Real;
		attribute longitude : Real;
		attribute altitude : LengthValue;
	}
	
	attribute def Waypoint {
		attribute location : Coordinate;
		attribute arrivalSpeed : SpeedValue;
		attribute loiterTime : TimeValue;
	}
	
	item def MissionPlan {
		attribute missionId : String;
		attribute waypoints : Waypoint[1..*] ordered;
		attribute maxDuration : TimeValue;
	}
	
	item def NavigationCommand {
		attribute targetWaypoint : Waypoint;
		attribute cruiseSpeed : SpeedValue;
		attribute cruiseAltitude : LengthValue;
	}
	
	item def VehicleState {
		attribute currentPosition : Coordinate;
		attribute currentSpeed : SpeedValue;
		attribute currentHeading : Real;
		attribute batteryLevel : Real;
	}
	
	item def SensorData {
		attribute timestamp : Real;
		attribute position : Coordinate;
		attribute obstacleDetected : Boolean;
		attribute obstacleDistance : LengthValue;
		attribute imageData : String;
	}
	
	item def ControlCommand {
		attribute throttle : Real;
		attribute rudder : Real;
		attribute elevator : Real;
		attribute aileron : Real;
	}
	
	item def TelemetryPacket {
		attribute vehicleState : VehicleState;
		attribute sensorData : SensorData;
		attribute systemHealth : Real;
	}
	
	enum def FlightMode {
		enum manual;
		enum autonomous;
		enum returnToBase;
		enum emergency;
	}
	
	enum def MissionPhase {
		enum preflight;
		enum takeoff;
		enum transit;
		enum surveillance;
		enum returning;
		enum landing;
		enum complete;
	}
	
	port def CommandPort {
		in item missionPlan : MissionPlan;
		in item navigationCmd : NavigationCommand;
		out item acknowledgment : Boolean;
	}
	
	port def TelemetryPort {
		out item telemetry : TelemetryPacket;
	}
	
	port def SensorDataPort {
		out item sensorOutput : SensorData;
	}
	
	port def ControlPort {
		in item controlInput : ControlCommand;
	}
	
	port def PowerPort {
		out attribute voltage : ISQ::ElectricPotentialValue;
		out attribute current : ISQ::ElectricCurrentValue;
		in attribute powerDemand : PowerValue;
	}
	
	part def PowerSystem {
		attribute batteryCapacity : EnergyValue;
		attribute currentCharge : EnergyValue;
		attribute dischargingRate : PowerValue;
		port powerOut : PowerPort;
		
		action monitorBattery {
			out chargeLevel : Real;
			out remainingTime : TimeValue;
			out voltage : ISQ::ElectricPotentialValue;
		}
		
		action supplyPower {
			in demand : PowerValue;
			out supplied : PowerValue;
			out updated_charge : EnergyValue;
		}
	}
	
	part def PropulsionSystem {
		attribute maxThrust : ForceValue;
		attribute currentThrust : ForceValue;
		attribute efficiency : Real;
		port controlIn : ControlPort;
		port powerIn : PowerPort;
		
		part motor {
			attribute ratedPower : PowerValue;
			attribute rpm : Real;
		}
		
		part propeller {
			attribute diameter : LengthValue;
			attribute pitch : LengthValue;
		}
		
		action generateThrust {
			in throttleCommand : Real;
			in availablePower : PowerValue;
			out thrust : ForceValue;
			out powerConsumed : PowerValue;
		}
	}
	
	part def SensorSuite {
		port sensorOut : SensorDataPort;
		
		part camera {
			attribute resolution : Integer;
			attribute frameRate : Real;
			attribute fieldOfView : Real;
		}
		
		part lidar {
			attribute range : LengthValue;
			attribute accuracy : LengthValue;
			attribute scanRate : Real;
		}
		
		part gps {
			attribute accuracy : LengthValue;
			attribute updateRate : Real;
		}
		
		part imu {
			attribute gyroRange : Real;
			attribute accelRange : AccelerationValue;
		}
		
		action acquireData {
			out position : Coordinate;
			out obstacleInfo : Boolean;
			out distance : LengthValue;
			out imageCapture : String;
		}
	}
	
	part def NavigationSystem {
		attribute currentWaypoint : Integer;
		attribute totalWaypoints : Integer;
		port commandIn : CommandPort;
		port sensorIn : SensorDataPort;
		
		action planRoute {
			in mission : MissionPlan;
			in currentPos : Coordinate;
			out route : Waypoint[*] ordered;
		}
		
		action updatePosition {
			in sensorInput : SensorData;
			out position : Coordinate;
			out heading : Real;
		}
		
		action calculateNavigation {
			in currentPos : Coordinate;
			in targetWaypoint : Waypoint;
			out navCommand : NavigationCommand;
		}
	}
	
	part def FlightController {
		attribute mode : FlightMode;
		port navIn : CommandPort;
		port sensorIn : SensorDataPort;
		port controlOut : ControlPort;
		
		action processNavigation {
			in navCmd : NavigationCommand;
			in vehicleState : VehicleState;
			out controlCmd : ControlCommand;
		}
		
		action detectObstacles {
			in sensorInput : SensorData;
			out obstacleAvoidance : ControlCommand;
			out emergencyFlag : Boolean;
		}
		
		action stabilize {
			in currentState : VehicleState;
			out stabilizationCmd : ControlCommand;
		}
	}
	
	part def CommunicationSystem {
		attribute linkQuality : Real;
		attribute bandwidth : Real;
		port commandIn : CommandPort;
		port telemetryOut : TelemetryPort;
		
		action receiveCommands {
			out mission : MissionPlan;
			out navCmd : NavigationCommand;
		}
		
		action transmitTelemetry {
			in data : TelemetryPacket;
			out transmissionSuccess : Boolean;
		}
	}
	
	part def UnmannedVehicle {
		attribute vehicleId : String;
		attribute mass : MassValue;
		attribute maxSpeed : SpeedValue;
		attribute operationalAltitude : LengthValue;
		attribute currentMode : FlightMode;
		attribute missionPhase : MissionPhase;
		
		part power : PowerSystem {
			attribute :>> batteryCapacity = 100000.0[J];
			attribute :>> currentCharge = 95000.0[J];
			attribute :>> dischargingRate = 500.0[W];
		}
		
		part propulsion : PropulsionSystem {
			attribute :>> maxThrust = 800.0[N];
			attribute :>> currentThrust = 0.0[N];
			attribute :>> efficiency = 0.85;
			
			part :>> motor {
				attribute :>> ratedPower = 600.0[W];
				attribute :>> rpm = 0.0;
			}
			
			part :>> propeller {
				attribute :>> diameter = 0.3[m];
				attribute :>> pitch = 0.15[m];
			}
		}
		
		part sensors : SensorSuite {
			part :>> camera {
				attribute :>> resolution = 1920;
				attribute :>> frameRate = 30.0;
				attribute :>> fieldOfView = 90.0;
			}
			
			part :>> lidar {
				attribute :>> range = 150.0[m];
				attribute :>> accuracy = 0.03[m];
				attribute :>> scanRate = 10.0;
			}
			
			part :>> gps {
				attribute :>> accuracy = 2.5[m];
				attribute :>> updateRate = 10.0;
			}
			
			part :>> imu {
				attribute :>> gyroRange = 2000.0;
				attribute :>> accelRange = 16.0[m/s^2];
			}
		}
		
		part navigation : NavigationSystem {
			attribute :>> currentWaypoint = 0;
			attribute :>> totalWaypoints = 0;
		}
		
		part flightController : FlightController {
			attribute :>> mode = FlightMode::autonomous;
		}
		
		part communications : CommunicationSystem {
			attribute :>> linkQuality = 0.95;
			attribute :>> bandwidth = 1000000.0;
		}
		
		connection powerToPropulsion connect power.powerOut to propulsion.powerIn;
		connection sensorsToNav connect sensors.sensorOut to navigation.sensorIn;
		connection sensorsToController connect sensors.sensorOut to flightController.sensorIn;
		connection navToController connect navigation.commandIn to flightController.navIn;
		connection controllerToPropulsion connect flightController.controlOut to propulsion.controlIn;
		connection commsToNav connect communications.commandIn to navigation.commandIn;
	}
	
	part groundControlStation {
		attribute stationId : String;
		attribute operatorCount : Integer;
		port commandOut : CommandPort;
		port telemetryIn : TelemetryPort;
		
		action planMission {
			in targetArea : Coordinate;
			in duration : TimeValue;
			out mission : MissionPlan;
		}
		
		action monitorVehicle {
			in telemetry : TelemetryPacket;
			out status : String;
			out alertLevel : Integer;
		}
		
		action issueCommand {
			in command : NavigationCommand;
			out commandSent : Boolean;
		}
	}
	
	action def ExecuteAutonomousMission {
		in mission : MissionPlan;
		in initialState : VehicleState;
		out missionSuccess : Boolean;
		out collectedData : SensorData[*];
		out finalState : VehicleState;
	}
	
	action executeReconnaissanceMission : ExecuteAutonomousMission {
		in mission : MissionPlan;
		in initialState : VehicleState;
		out missionSuccess : Boolean;
		out collectedData : SensorData[*];
		out finalState : VehicleState;
		
		private attribute currentWaypointIndex : Integer := 0;
		private attribute waypointCount : Integer := mission.waypoints->size();
		private attribute vehiclePosition : Coordinate := initialState.currentPosition;
		private attribute batteryRemaining : Real := initialState.batteryLevel;
		private attribute dataCollected : SensorData[*] := ();
		
		first start;
		then action initializeMission {
			out initialized : Boolean;
			out phase : MissionPhase = MissionPhase::preflight;
		}
		
		then action takeoff {
			in startPosition : Coordinate = executeReconnaissanceMission::vehiclePosition;
			out takeoffComplete : Boolean;
			out newAltitude : LengthValue;
		}
		
		then merge waypointLoop;
		
		action waypointLoop {
			action navigateToWaypoint {
				in targetWaypoint : Waypoint = executeReconnaissanceMission::mission.waypoints#(executeReconnaissanceMission::currentWaypointIndex);
				in currentPos : Coordinate = executeReconnaissanceMission::vehiclePosition;
				out navigationControl : ControlCommand;
				out arrived : Boolean;
			}
			
			flow navigateToWaypoint.navigationControl to collectSurveillanceData.controlInput;
			
			action collectSurveillanceData {
				in controlInput : ControlCommand;
				in waypoint : Waypoint = executeReconnaissanceMission::mission.waypoints#(executeReconnaissanceMission::currentWaypointIndex);
				out data : SensorData;
				out collectionComplete : Boolean;
			}
			
			then action updateMissionState {
				in sensorData : SensorData = collectSurveillanceData.data;
				in waypointReached : Boolean = navigateToWaypoint.arrived;
				out updatedIndex : Integer;
				out updatedData : SensorData[*];
				out allWaypointsComplete : Boolean;
			}
			
			then assign executeReconnaissanceMission::currentWaypointIndex := updateMissionState.updatedIndex;
			then assign executeReconnaissanceMission::dataCollected := updateMissionState.updatedData;
			
			then decide;
				if updateMissionState.allWaypointsComplete then returnToBase;
				if not updateMissionState.allWaypointsComplete then waypointLoop;
			
			action returnToBase {
				in collectedData : SensorData[*] = executeReconnaissanceMission::dataCollected;
				out returnComplete : Boolean;
				out landingPosition : Coordinate;
			}
			
			then action landVehicle {
				in approachPosition : Coordinate = returnToBase.landingPosition;
				out landingComplete : Boolean;
				out finalPosition : Coordinate;
			}
			
			then assign executeReconnaissanceMission::missionSuccess := landVehicle.landingComplete;
			then assign executeReconnaissanceMission::collectedData := executeReconnaissanceMission::dataCollected;
			then assign executeReconnaissanceMission::finalState := VehicleState {
				currentPosition = landVehicle.finalPosition;
				currentSpeed = 0.0[m/s];
				currentHeading = 0.0;
				batteryLevel = executeReconnaissanceMission::batteryRemaining;
			};
		}
		
		then done;
	}
	
	state def VehicleOperationalStates {
		entry; then idle;
		
		state idle {
			entry assign currentMode = FlightMode::manual;
			entry assign missionPhase = MissionPhase::preflight;
		}
		
		transition idle_to_missionPrep
			first idle
			accept missionReceived : MissionPlan
			then missionPreparation;
		
		state missionPreparation {
			entry assign missionPhase = MissionPhase::preflight;
			do action validateMission {
				in mission : MissionPlan;
				out valid : Boolean;
			}
			do action performPreflightChecks {
				out checksComplete : Boolean;
				out systemsNominal : Boolean;
			}
		}
		
		transition prep_to_takeoff
			first missionPreparation
			if systemsNominal and missionValid
			then takeoff;
		
		state takeoff {
			entry assign currentMode = FlightMode::autonomous;
			entry assign missionPhase = MissionPhase::takeoff;
			do action executeAutonomousMission;
		}
		
		transition takeoff_to_transit
			first takeoff
			if altitudeReached
			then transit;
		
		state transit {
			entry assign missionPhase = MissionPhase::transit;
			
			state navigating {
				do action navigateToWaypoint;
			}
			
			state avoiding {
				do action detectObstacles;
				do action executeAvoidance;
			}
			
			transition navigating_to_avoiding
				first navigating
				if obstacleDetected
				then avoiding;
			
			transition avoiding_to_navigating
				first avoiding
				if obstacleClear
				then navigating;
		}
		
		transition transit_to_surveillance
			first transit
			if waypointReached
			then surveillance;
		
		state surveillance {
			entry assign missionPhase = MissionPhase::surveillance;
			do action collectSurveillanceData;
			do action transmitData;
		}
		
		transition surveillance_to_transit
			first surveillance
			if dataCollected and moreWaypoints
			then transit;
		
		transition surveillance_to_returning
			first surveillance
			if dataCollected and allWaypointsComplete
			then returning;
		
		state returning {
			entry assign currentMode = FlightMode::returnToBase;
			entry assign missionPhase = MissionPhase::returning;
			do action returnToBase;
		}
		
		transition returning_to_landing
			first returning
			if baseReached
			then landing;
		
		state landing {
			entry assign missionPhase = MissionPhase::landing;
			do action landVehicle;
		}
		
		transition landing_to_complete
			first landing
			if landingComplete
			then missionComplete;
		
		state missionComplete {
			entry assign missionPhase = MissionPhase::complete;
		}
		
		transition complete_to_idle
			first missionComplete
			accept missionReset
			then idle;
		
		transition any_to_emergency
			first transit, surveillance, returning
			accept emergencySignal
			then emergency;
		
		transition any_to_emergency_battery
			first transit, surveillance, returning
			if batteryLevel < 15.0
			then emergency;
		
		state emergency {
			entry assign currentMode = FlightMode::emergency;
			entry assign missionPhase = MissionPhase::returning;
			do action emergencyLanding {
				out landingSite : Coordinate;
				out landingSuccess : Boolean;
			}
		}
		
		transition emergency_to_idle
			first emergency
			if safetyRestored
			then idle;
	}
	
	requirement def <'REQ-UV-001'> AutonomousMissionExecutionRequirement {
		doc /* The unmanned vehicle shall autonomously execute reconnaissance missions by 
		       navigating to designated waypoints, collecting surveillance data, and returning 
		       to base without continuous human intervention. */
		
		subject vehicle : UnmannedVehicle;
		
		require constraint {
			vehicle.currentMode == FlightMode::autonomous
		}
		
		require constraint {
			vehicle.flightController.mode == FlightMode::autonomous
		}
		
		require constraint {
			vehicle.navigation.totalWaypoints >= 1
		}
	}
	
	requirement def <'REQ-UV-002'> NavigationAccuracyRequirement {
		doc /* The unmanned vehicle shall navigate to waypoints with a position accuracy 
		       of 5 meters or better using GPS and inertial navigation. */
		
		subject vehicle : UnmannedVehicle;
		
		attribute requiredAccuracy : LengthValue = 5.0[m];
		
		require constraint {
			vehicle.sensors.gps.accuracy <= requiredAccuracy
		}
	}
	
	requirement def <'REQ-UV-003'> ObstacleAvoidanceRequirement {
		doc /* The unmanned vehicle shall detect obstacles within 150 meters and execute 
		       avoidance maneuvers to maintain safe separation during flight. */
		
		subject vehicle : UnmannedVehicle;
		
		attribute minimumDetectionRange : LengthValue = 150.0[m];
		attribute minimumAccuracy : LengthValue = 0.05[m];
		
		require constraint {
			vehicle.sensors.lidar.range >= minimumDetectionRange
		}
		
		require constraint {
			vehicle.sensors.lidar.accuracy <= minimumAccuracy
		}
	}
	
	requirement def <'REQ-UV-004'> EnduranceRequirement {
		doc /* The unmanned vehicle shall operate for at least 60 minutes on internal 
		       battery power while performing surveillance missions. */
		
		subject vehicle : UnmannedVehicle;
		
		attribute minimumEndurance : TimeValue = 60.0[min];
		attribute minimumBatteryCapacity : EnergyValue = 100000.0[J];
		
		assume constraint {
			vehicle.power.dischargingRate <= 500.0[W]
		}
		
		require constraint {
			vehicle.power.batteryCapacity >= minimumBatteryCapacity
		}
	}
	
	requirement def <'REQ-UV-005'> CommunicationRequirement {
		doc /* The unmanned vehicle shall maintain reliable bidirectional communication 
		       with ground control for command reception and telemetry transmission with 
		       link quality above 80%. */
		
		subject vehicle : UnmannedVehicle;
		
		attribute minimumLinkQuality : Real = 0.80;
		
		require constraint {
			vehicle.communications.linkQuality >= minimumLinkQuality
		}
	}
	
	requirement def <'REQ-UV-006'> DataCollectionRequirement {
		doc /* The unmanned vehicle shall collect high-resolution imagery and sensor data 
		       at each waypoint with minimum 1920 pixel resolution at 30 frames per second. */
		
		subject vehicle : UnmannedVehicle;
		
		attribute minimumResolution : Integer = 1920;
		attribute minimumFrameRate : Real = 30.0;
		
		require constraint {
			vehicle.sensors.camera.resolution >= minimumResolution
		}
		
		require constraint {
			vehicle.sensors.camera.frameRate >= minimumFrameRate
		}
	}
	
	requirement systemRequirements {
		subject testVehicle : UnmannedVehicle;
		
		require autonomousMission : AutonomousMissionExecutionRequirement {
			subject vehicle :>> testVehicle;
		}
		
		require navAccuracy : NavigationAccuracyRequirement {
			subject vehicle :>> testVehicle;
		}
		
		require obstacleAvoidance : ObstacleAvoidanceRequirement {
			subject vehicle :>> testVehicle;
		}
		
		require endurance : EnduranceRequirement {
			subject vehicle :>> testVehicle;
		}
		
		require communication : CommunicationRequirement {
			subject vehicle :>> testVehicle;
		}
		
		require dataCollection : DataCollectionRequirement {
			subject vehicle :>> testVehicle;
		}
	}
	
	part vehicleInstance : UnmannedVehicle {
		attribute :>> vehicleId = "UAV-RECON-001";
		attribute :>> mass = 35.0[kg];
		attribute :>> maxSpeed = 25.0[m/s];
		attribute :>> operationalAltitude = 500.0[m];
		attribute :>> currentMode = FlightMode::autonomous;
		attribute :>> missionPhase = MissionPhase::preflight;
	}
	
	part groundStation : groundControlStation {
		attribute :>> stationId = "GCS-ALPHA-01";
		attribute :>> operatorCount = 2;
	}
	
	connection vehicleToGroundLink connect 
		vehicleInstance.communications.commandIn to groundStation.commandOut;
	
	connection groundToVehicleLink connect 
		vehicleInstance.communications.telemetryOut to groundStation.telemetryIn;
}
