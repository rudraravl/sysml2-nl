package 'Multi-function Autonomous Drone System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def FlightMode;
	attribute def NavigationData;
	attribute def ImageData;
	attribute def PackageInfo;
	attribute def EnvironmentData;
	attribute def CommandSignal;
	attribute def SystemHealth;
	
	port def NavigationPort {
		out position : NavigationData;
		in targetWaypoint : NavigationData;
	}
	
	port def SensorPort {
		out environmentData : EnvironmentData;
		out imageData : ImageData;
	}
	
	port def ActuatorPort {
		in thrustCommand : ISQ::ForceValue;
		in controlSurface : CommandSignal;
		out actuatorStatus : SystemHealth;
	}
	
	port def PayloadPort {
		in packageData : PackageInfo;
		out releaseConfirm : SystemHealth;
	}
	
	port def PowerPort {
		out batteryLevel : Real;
		in powerDemand : ISQ::PowerValue;
	}
	
	port def CommunicationPort {
		in remoteCommand : CommandSignal;
		out telemetry : NavigationData;
	}
	
	part def FlightControlModule {
		port navPort : NavigationPort;
		port actuatorCmd : ActuatorPort;
		port powerIn : PowerPort;
		
		attribute currentAltitude : ISQ::LengthValue;
		attribute currentVelocity : ISQ::SpeedValue;
		attribute stabilityMargin : Real;
		
		action controlFlight {
			in navData : NavigationData;
			out thrustCmd : ISQ::ForceValue;
			out surfaceCmd : CommandSignal;
		}
	}
	
	part def SensingModule {
		port sensorOut : SensorPort;
		port powerIn : PowerPort;
		
		attribute sensorRange : ISQ::LengthValue;
		attribute imageResolution : Integer;
		
		action captureEnvironment {
			out envData : EnvironmentData;
			out imgData : ImageData;
		}
	}
	
	part def NavigationModule {
		port navOut : NavigationPort;
		port commPort : CommunicationPort;
		port powerIn : PowerPort;
		
		attribute gpsAccuracy : ISQ::LengthValue;
		attribute waypointList : NavigationData[*];
		
		action calculateRoute {
			in currentPos : NavigationData;
			in targetPos : NavigationData;
			out flightPath : NavigationData;
		}
	}
	
	part def PayloadModule {
		port payloadCtrl : PayloadPort;
		port powerIn : PowerPort;
		
		attribute maxPayloadMass : ISQ::MassValue;
		attribute currentPayload : PackageInfo;
		
		action managePayload {
			in deliveryCmd : CommandSignal;
			out releaseStatus : SystemHealth;
		}
	}
	
	part def PropulsionModule {
		port actuatorIn : ActuatorPort;
		port powerIn : PowerPort;
		
		attribute maxThrust : ISQ::ForceValue;
		attribute motorCount : Integer;
		attribute efficiency : Real;
		
		action generateThrust {
			in thrustDemand : ISQ::ForceValue;
			out actualThrust : ISQ::ForceValue;
		}
	}
	
	part def PowerModule {
		port powerOut : ~PowerPort[*];
		
		attribute batteryCapacity : ISQ::EnergyValue;
		attribute currentCharge : Real;
		attribute voltageLevel : ISQ::ElectricPotentialValue;
		
		action managePower {
			in totalDemand : ISQ::PowerValue;
			out availablePower : ISQ::PowerValue;
		}
	}
	
	part def CommunicationModule {
		port commLink : CommunicationPort;
		port powerIn : PowerPort;
		
		attribute signalStrength : Real;
		attribute dataRate : ISQ::FrequencyValue;
		
		action transmitData {
			in telemetryData : NavigationData;
			out transmitStatus : SystemHealth;
		}
	}
	
	action def SurveyArea {
		in surveyZone : NavigationData;
		in flightAltitude : ISQ::LengthValue;
		out surveyImages : ImageData[*];
		out environmentMap : EnvironmentData;
	}
	
	action def DeliverPackage {
		in pickupLocation : NavigationData;
		in deliveryLocation : NavigationData;
		in packageDetails : PackageInfo;
		out deliveryConfirmation : SystemHealth;
	}
	
	action def PatrolRoute {
		in patrolPath : NavigationData[*];
		in patrolDuration : ISQ::DurationValue;
		out patrolReport : EnvironmentData[*];
	}
	
	action def ReturnToBase {
		in baseLocation : NavigationData;
		out arrivalStatus : SystemHealth;
	}
	
	state def DroneOperationalState {
		entry action initializeSystems;
		do action executeCurrentMission;
		exit action safeLanding;
		
		state standby {
			entry action powerSaveMode;
		}
		
		state preflight {
			entry action systemCheck;
		}
		
		state flying {
			state cruising;
			state hovering;
			state maneuvering;
			
			transition cruising_to_hovering
				first cruising
				then hovering;
			
			transition hovering_to_maneuvering
				first hovering
				then maneuvering;
			
			transition maneuvering_to_cruising
				first maneuvering
				then cruising;
		}
		
		state surveying {
			do action performSurvey;
		}
		
		state delivering {
			do action executeDelivery;
		}
		
		state patrolling {
			do action executePatrol;
		}
		
		state returning {
			do action navigateToBase;
		}
		
		state emergency {
			entry action emergencyProtocol;
			do action emergencyLanding;
		}
		
		transition standby_to_preflight
			first standby
			then preflight;
		
		transition preflight_to_flying
			first preflight
			then flying;
		
		transition flying_to_surveying
			first flying
			then surveying;
		
		transition flying_to_delivering
			first flying
			then delivering;
		
		transition flying_to_patrolling
			first flying
			then patrolling;
		
		transition surveying_to_flying
			first surveying
			then flying;
		
		transition delivering_to_flying
			first delivering
			then flying;
		
		transition patrolling_to_flying
			first patrolling
			then flying;
		
		transition flying_to_returning
			first flying
			then returning;
		
		transition returning_to_standby
			first returning
			then standby;
		
		transition emergency_to_standby
			first emergency
			then standby;
	}
	
	action def ExecuteMultiFunctionMission {
		in missionMode : FlightMode;
		in missionParameters : NavigationData;
		out missionResult : SystemHealth;
		
		private attribute currentPosition : NavigationData;
		private attribute environmentalData : EnvironmentData;
		private attribute batteryStatus : Real;
		
		first start;
		
		then action navigate {
			in currentPos = currentPosition;
			in targetPos = missionParameters;
			out flightPath : NavigationData;
		}
		
		then action sense {
			out envData : EnvironmentData;
			out imgData : ImageData;
		}
		
		then assign environmentalData := sense.envData;
		
		then action controlFlt {
			in navData = navigate.flightPath;
			out thrustCmd : ISQ::ForceValue;
			out surfaceCmd : CommandSignal;
		}
		
		then action propel {
			in thrustDemand = controlFlt.thrustCmd;
			out actualThrust : ISQ::ForceValue;
		}
		
		then action checkPower {
			in totalDemand : ISQ::PowerValue;
			out availablePower : ISQ::PowerValue;
		}
		
		then assign batteryStatus := 0.8;
		
		then decide;
			if batteryStatus > 0.2 then executeSurvey;
			if batteryStatus <= 0.2 then executeReturn;
		
		action executeSurvey : SurveyArea {
			in surveyZone = missionParameters;
			in flightAltitude : ISQ::LengthValue;
			out surveyImages;
			out environmentMap;
		}
		then merge missionComplete;
		
		action executeReturn : ReturnToBase {
			in baseLocation = missionParameters;
			out arrivalStatus;
		}
		then merge missionComplete;
		
		merge missionComplete;
		
		then action transmit {
			in telemetryData = currentPosition;
			out transmitStatus : SystemHealth;
		}
		
		then done;
	}
	
	part autonomousDrone : AutonomousDroneSystem {
		attribute operationalMode : FlightMode;
		attribute missionStatus : SystemHealth;
		attribute maxRange : ISQ::LengthValue;
		attribute maxFlightTime : ISQ::DurationValue;
		attribute totalMass : ISQ::MassValue;
		
		part flightControl : FlightControlModule;
		
		part sensing : SensingModule[2];
		
		part navigation : NavigationModule;
		
		part payload : PayloadModule;
		
		part propulsion : PropulsionModule[4];
		
		part power : PowerModule;
		
		part communication : CommunicationModule;
		
		connection powerToFlight : PowerConnection
			connect power.powerOut to flightControl.powerIn;
		
		connection powerToSensing : PowerConnection
			connect power.powerOut to sensing.powerIn;
		
		connection powerToNav : PowerConnection
			connect power.powerOut to navigation.powerIn;
		
		connection powerToPayload : PowerConnection
			connect power.powerOut to payload.powerIn;
		
		connection powerToPropulsion : PowerConnection
			connect power.powerOut to propulsion.powerIn;
		
		connection powerToComm : PowerConnection
			connect power.powerOut to communication.powerIn;
		
		connection navToFlight : NavigationConnection
			connect navigation.navOut to flightControl.navPort;
		
		connection flightToPropulsion : ActuationConnection
			connect flightControl.actuatorCmd to propulsion.actuatorIn;
		
		perform action multiFunctionMission : ExecuteMultiFunctionMission {
			in missionMode = operationalMode;
			in missionParameters;
			out missionResult;
		}
		
		exhibit state droneState : DroneOperationalState;
	}
	
	part def AutonomousDroneSystem;
	
	connection def PowerConnection {
		end source : PowerPort;
		end target : PowerPort;
	}
	
	connection def NavigationConnection {
		end source : NavigationPort;
		end target : NavigationPort;
	}
	
	connection def ActuationConnection {
		end source : ActuatorPort;
		end target : ActuatorPort;
	}
	
	requirement def PrimaryMissionRequirement;
	
	requirement <'REQ-001'> multiFunctionCapability : PrimaryMissionRequirement {
		doc /* The autonomous drone system shall perform multiple mission types including 
		       aerial surveillance, package delivery, route patrol, and autonomous return-to-base, 
		       integrating flight control, sensing, navigation, payload management, propulsion, 
		       power distribution, and communication subsystems in a coordinated manner. */
		
		subject autonomousDrone;
		
		require constraint surveillanceFunction {
			doc /* The system shall capture high-resolution imagery and environmental data 
			       while maintaining stable flight over designated survey areas. */
		}
		
		require constraint deliveryFunction {
			doc /* The system shall transport payloads up to maximum capacity between 
			       specified locations and execute controlled payload release. */
		}
		
		require constraint patrolFunction {
			doc /* The system shall autonomously follow predefined patrol routes while 
			       monitoring environmental conditions and detecting anomalies. */
		}
		
		require constraint autonomousNavigation {
			doc /* The system shall navigate autonomously using GPS and sensor fusion, 
			       avoiding obstacles and maintaining safe flight parameters. */
		}
	}
	
	requirement <'REQ-002'> powerManagement : PrimaryMissionRequirement {
		doc /* The system shall efficiently manage battery power across all subsystems 
		       and initiate return-to-base when charge drops below safety threshold. */
		
		subject autonomousDrone.power;
		
		require constraint batteryMonitoring {
			autonomousDrone.power.currentCharge >= 0.2
		}
		
		require constraint powerEfficiency {
			autonomousDrone.power.efficiency >= 0.80
		}
	}
	
	requirement <'REQ-003'> safetyAndReliability : PrimaryMissionRequirement {
		doc /* The system shall detect critical failures and execute emergency protocols 
		       including controlled descent and emergency landing procedures. */
		
		subject autonomousDrone;
		
		require constraint emergencyResponse {
			doc /* Upon detecting critical system failure, the drone shall transition 
			       to emergency state within 500 milliseconds. */
		}
		
		require constraint failsafeOperation {
			doc /* All subsystems shall report health status continuously and trigger 
			       appropriate responses to degraded conditions. */
		}
	}
	
	requirement <'REQ-004'> communicationReliability : PrimaryMissionRequirement {
		doc /* The system shall maintain reliable communication link with ground control 
		       and transmit telemetry data at regular intervals throughout mission. */
		
		subject autonomousDrone.communication;
		
		require constraint telemetryRate {
			autonomousDrone.communication.dataRate >= 1.0
		}
	}
}
