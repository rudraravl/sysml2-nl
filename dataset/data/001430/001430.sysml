package 'FosterMillerTALONSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def ControlCommand;
	attribute def VideoData;
	attribute def TelemetryData;
	attribute def NavigationData;
	attribute def ManipulatorData;
	attribute def ObstacleInfo {
		attribute requiresManipulation : Boolean;
	}
	attribute def MissionStatus;

	port def ControlPort {
		in command : ControlCommand;
		out feedback : TelemetryData;
	}

	port def PowerPort {
		in voltage : ISQ::ElectricPotentialValue;
		in current : ISQ::ElectricCurrentValue;
	}

	port def CommunicationPort {
		in commandStream : ControlCommand;
		out videoStream : VideoData;
		out telemetry : TelemetryData;
	}

	port def DrivePort {
		in driveCommand : NavigationData;
		out odometry : TelemetryData;
	}

	port def ManipulatorPort {
		in armCommand : ManipulatorData;
		out gripperFeedback : TelemetryData;
	}

	port def SensorPort {
		out sensorData : ObstacleInfo;
	}

	part def BatteryPack {
		attribute capacity : ISQ::EnergyValue;
		attribute chargeLevel : ISQ::EnergyValue;
		attribute nominalVoltage : ISQ::ElectricPotentialValue;
		port powerOutput : PowerPort;
	}

	part def DriveMotor {
		attribute maxTorque : ISQ::TorqueValue;
		attribute operatingSpeed : ISQ::AngularVelocityValue;
		port powerInput : PowerPort;
		port control : ControlPort;
	}

	part def TrackedWheel {
		attribute diameter : ISQ::LengthValue;
		attribute width : ISQ::LengthValue;
	}

	part def VideoCamera {
		attribute resolution : String;
		attribute fieldOfView : Real;
		attribute frameRate : Real;
		port videoOutput : CommunicationPort;
		port powerInput : PowerPort;
	}

	part def RoboticManipulator {
		attribute maxReach : ISQ::LengthValue;
		attribute payloadCapacity : ISQ::MassValue;
		attribute joints : Integer;
		port manipulatorControl : ManipulatorPort;
		port powerInput : PowerPort;

		part shoulderJoint;
		part elbowJoint;
		part wristJoint;
		part endEffector;
	}

	part def ProximitySensor {
		attribute range : ISQ::LengthValue;
		attribute accuracy : ISQ::LengthValue;
		port sensorOutput : SensorPort;
		port powerInput : PowerPort;
	}

	part def MainController {
		attribute processorSpeed : Real;
		port commandInput : CommunicationPort;
		port driveControl : DrivePort;
		port armControl : ManipulatorPort;
		port sensorInput : SensorPort;
	}

	part def RadioTransceiver {
		attribute operatingFrequency : Real;
		attribute transmitPower : ISQ::PowerValue;
		attribute communicationRange : ISQ::LengthValue;
		port dataLink : CommunicationPort;
		port powerInput : PowerPort;
	}

	part def OperatorConsole {
		attribute screenSize : ISQ::LengthValue;
		port remoteLink : CommunicationPort;

		part controlJoystick;
		part videoDisplay;
		part commandInterface;
	}

	action def NavigateToPosition {
		in targetLocation : ISQ::LengthValue;
		in currentLocation : ISQ::LengthValue;
		in obstacles : ObstacleInfo;
		out navigationCommand : NavigationData;
	}

	action def PerformManipulation {
		in targetObject : ISQ::LengthValue;
		in gripperState : TelemetryData;
		out manipulationCommand : ManipulatorData;
	}

	action def StreamVideo {
		in rawVideo : VideoData;
		out encodedVideo : VideoData;
	}

	action def AnalyzeSensors {
		in sensorInput : ObstacleInfo;
		out processedObstacles : ObstacleInfo;
	}

	action def ExecuteRemoteMission {
		first start;
		then merge operationLoop;

		action receiveCommand {
			out operatorCommand : ControlCommand;
		}
		then operationLoop;

		then decide;
			if receiveCommand.operatorCommand != null then processCommand;
			if receiveCommand.operatorCommand == null then completeMission;

		action processCommand : NavigateToPosition {
			in targetLocation;
			in currentLocation;
			in obstacles;
			out navigationCommand;
		}
		then action transmitVideo : StreamVideo {
			in rawVideo;
			out encodedVideo;
		}
		then action analyzeSensors : AnalyzeSensors {
			in sensorInput;
			out processedObstacles;
		}
		then decide;
			if analyzeSensors.processedObstacles.requiresManipulation then executeManipulation;
			else operationLoop;

		action executeManipulation : PerformManipulation {
			in targetObject;
			in gripperState;
			out manipulationCommand;
		}
		then operationLoop;

		action completeMission;
		then done;
	}

	state def TALONOperationalStates {
		entry; then standby;

		state standby {
			entry;
		}
		transition standby_to_operational
			first standby
			accept activationSignal : ControlCommand
			then operational;

		state operational {
			entry;

			state driving;
			state manipulatingObject;
			state surveillanceMode;

			transition drive_to_manipulate
				first driving
				accept ControlCommand
				then manipulatingObject;

			transition manipulate_to_drive
				first manipulatingObject
				accept ControlCommand
				then driving;

			transition any_to_surveillance
				accept ControlCommand
				then surveillanceMode;
		}

		transition operational_to_standby
			first operational
			accept deactivationSignal : ControlCommand
			then standby;

		state emergencyStop {
			entry;
		}

		transition any_to_emergency
			accept emergencyCommand : ControlCommand
			then emergencyStop;
	}

	requirement def MissionCapability {
		doc /* The TALON robot shall perform reconnaissance, surveillance, 
		       and hazardous material handling in dangerous environments 
		       while keeping operators at safe distance. */

		require mobilityCapability : MobilityCapability;
		require manipulationCapability : ManipulationCapability;
		require communicationCapability : CommunicationCapability;
	}

	requirement def MobilityCapability {
		doc /* The robot shall navigate rough terrain including stairs, 
		       debris, and obstacles while maintaining stability. */

		attribute maxObstacleHeight : ISQ::LengthValue;
		attribute maxIncline : Real;
		attribute groundClearance : ISQ::LengthValue;
	}

	requirement def ManipulationCapability {
		doc /* The robotic arm shall grasp, lift, and manipulate objects 
		       with precision for EOD and hazmat operations. */

		attribute minimumReach : ISQ::LengthValue;
		attribute maximumPayload : ISQ::MassValue;
		attribute positionAccuracy : ISQ::LengthValue;
	}

	requirement def CommunicationCapability {
		doc /* The system shall maintain reliable wireless communication 
		       and real-time video transmission to operator console. */

		attribute minimumRange : ISQ::LengthValue;
		attribute maxVideoLatency : ISQ::TimeValue;
		attribute dataRate : Real;
	}

	requirement def EnduranceRequirement {
		doc /* The robot shall operate continuously for mission duration 
		       on single battery charge. */

		attribute minimumOperatingDuration : ISQ::TimeValue;
		attribute batteryRechargeTime : ISQ::TimeValue;
	}

	part def TALONRobotPlatform;

	part talonSystem : TALONRobotPlatform {
		doc /* Foster-Miller TALON unmanned ground vehicle for explosive 
		       ordnance disposal, reconnaissance, and hazardous material 
		       handling in dangerous environments. */

		satisfy missionCapability : MissionCapability {
			require mobilityReq : MobilityCapability {
				attribute redefines maxObstacleHeight = 0.35 [SI::m];
				attribute redefines maxIncline = 60.0;
				attribute redefines groundClearance = 0.10 [SI::m];
			}
			require manipulationReq : ManipulationCapability {
				attribute redefines minimumReach = 1.5 [SI::m];
				attribute redefines maximumPayload = 15.0 [SI::kg];
				attribute redefines positionAccuracy = 0.01 [SI::m];
			}
			require commReq : CommunicationCapability {
				attribute redefines minimumRange = 1000.0 [SI::m];
				attribute redefines maxVideoLatency = 0.15 [SI::s];
				attribute redefines dataRate = 2.0;
			}
		}

		satisfy enduranceReq : EnduranceRequirement {
			attribute redefines minimumOperatingDuration = 8.0 [SI::h];
			attribute redefines batteryRechargeTime = 4.0 [SI::h];
		}

		part battery : BatteryPack {
			attribute redefines capacity = 2000.0 [SI::J];
			attribute redefines nominalVoltage = 28.0 [SI::V];
		}

		part leftTrack : TrackedWheel {
			attribute redefines diameter = 0.20 [SI::m];
			attribute redefines width = 0.12 [SI::m];
		}

		part rightTrack : TrackedWheel {
			attribute redefines diameter = 0.20 [SI::m];
			attribute redefines width = 0.12 [SI::m];
		}

		part leftMotor : DriveMotor {
			attribute redefines maxTorque = 60.0 [SI::N*SI::m];
		}

		part rightMotor : DriveMotor {
			attribute redefines maxTorque = 60.0 [SI::N*SI::m];
		}

		part primaryCamera : VideoCamera {
			attribute redefines resolution = "720x480";
			attribute redefines fieldOfView = 60.0;
			attribute redefines frameRate = 30.0;
		}

		part armCamera : VideoCamera {
			attribute redefines resolution = "640x480";
			attribute redefines fieldOfView = 45.0;
			attribute redefines frameRate = 30.0;
		}

		part manipulator : RoboticManipulator {
			attribute redefines maxReach = 1.5 [SI::m];
			attribute redefines payloadCapacity = 15.0 [SI::kg];
			attribute redefines joints = 6;
		}

		part frontSensor : ProximitySensor {
			attribute redefines range = 3.0 [SI::m];
			attribute redefines accuracy = 0.05 [SI::m];
		}

		part rearSensor : ProximitySensor {
			attribute redefines range = 3.0 [SI::m];
			attribute redefines accuracy = 0.05 [SI::m];
		}

		part controller : MainController {
			attribute redefines processorSpeed = 1200.0;
		}

		part radio : RadioTransceiver {
			attribute redefines operatingFrequency = 2450.0;
			attribute redefines transmitPower = 2.0 [SI::W];
			attribute redefines communicationRange = 1000.0 [SI::m];
		}

		connect battery.powerOutput to leftMotor.powerInput;
		connect battery.powerOutput to rightMotor.powerInput;
		connect battery.powerOutput to primaryCamera.powerInput;
		connect battery.powerOutput to armCamera.powerInput;
		connect battery.powerOutput to manipulator.powerInput;
		connect battery.powerOutput to frontSensor.powerInput;
		connect battery.powerOutput to rearSensor.powerInput;
		connect battery.powerOutput to radio.powerInput;

		connect controller.driveControl to leftMotor.control;
		connect controller.driveControl to rightMotor.control;
		connect controller.armControl to manipulator.manipulatorControl;
		connect controller.sensorInput to frontSensor.sensorOutput;
		connect controller.sensorInput to rearSensor.sensorOutput;

		connect primaryCamera.videoOutput to radio.dataLink;
		connect armCamera.videoOutput to radio.dataLink;
		connect controller.commandInput to radio.dataLink;

		perform action mission : ExecuteRemoteMission;

		exhibit state behavior : TALONOperationalStates;
	}

	part operatorStation : OperatorConsole {
		attribute redefines screenSize = 0.30 [SI::m];

		connect remoteLink to talonSystem.radio.dataLink;
	}
}
