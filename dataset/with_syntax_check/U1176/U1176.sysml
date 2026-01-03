package 'Remotely Operated Underwater Vehicle System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VideoResolution {
		attribute horizontalPixels : Integer;
		attribute verticalPixels : Integer;
	}
	
	attribute def GPSCoordinates {
		attribute latitude : Real;
		attribute longitude : Real;
	}
	
	item def ControlCommand {
		attribute targetDepth : LengthValue;
		attribute targetHeading : Real;
		attribute thrustVector : Real[3];
		attribute manipulatorAction : ManipulatorAction;
	}
	
	item def TelemetryData {
		attribute currentDepth : LengthValue;
		attribute currentHeading : Real;
		attribute currentPosition : GPSCoordinates;
		attribute temperature : ThermodynamicTemperatureValue;
		attribute pressure : PressureValue;
		attribute batteryLevel : Real;
	}
	
	item def VideoStream {
		attribute resolution : VideoResolution;
		attribute frameRate : FrequencyValue;
		attribute compressionFormat : String;
	}
	
	item def SonarData {
		attribute range : LengthValue;
		attribute bearingAngle : Real;
		attribute objectDistance : LengthValue;
	}
	
	item def PowerSignal {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	enum def ManipulatorAction {
		enum open;
		enum close;
		enum rotate_cw;
		enum rotate_ccw;
		enum extend;
		enum retract;
	}
	
	enum def MissionStatus {
		enum standby;
		enum deploying;
		enum operational;
		enum recovering;
		enum emergency;
	}
	
	port def ControlPort {
		in item commandIn : ControlCommand;
		out item telemetryOut : TelemetryData;
	}
	
	port def VideoPort {
		out item videoOut : VideoStream;
	}
	
	port def PowerPort {
		in item powerIn : PowerSignal;
	}
	
	port def ThrusterPort {
		in item thrustCommand : Real[3];
	}
	
	port def SensorPort {
		out item sensorData : TelemetryData;
	}
	
	part def SurfaceControlStation {
		port controlInterface : ~ControlPort;
		port videoReceiver : ~VideoPort;
		port powerSupply : ~PowerPort;
		
		part operatorConsole {
			attribute operatorName : String;
			attribute displayCount : Integer;
		}
		
		part powerGenerator {
			attribute ratedPower : PowerValue;
			attribute fuelCapacity : VolumeValue;
		}
		
		part communicationSystem {
			attribute bandwidth : Real;
			attribute signalStrength : Real;
		}
	}
	
	part def UmbilicalTether {
		port surfaceEnd : ControlPort;
		port vehicleEnd : ~ControlPort;
		port powerLine : PowerPort;
		
		attribute length : LengthValue;
		attribute maxTension : ForceValue;
		attribute cableWeight : MassValue;
		attribute communicationBandwidth : Real;
	}
	
	part def Thruster {
		port control : ThrusterPort;
		port power : PowerPort;
		
		attribute maxThrust : ForceValue;
		attribute powerConsumption : PowerValue;
		attribute efficiency : Real;
	}
	
	part def CameraSystem {
		port videoOutput : VideoPort;
		port power : PowerPort;
		
		attribute resolution : VideoResolution;
		attribute frameRate : FrequencyValue;
		attribute lightSensitivity : Real;
		attribute panRange : Real;
		attribute tiltRange : Real;
	}
	
	part def SonarSystem {
		port power : PowerPort;
		
		attribute maxRange : LengthValue;
		attribute resolution : LengthValue;
		attribute scanRate : FrequencyValue;
		attribute beamWidth : Real;
	}
	
	part def NavigationSystem {
		port sensorOutput : SensorPort;
		port power : PowerPort;
		
		attribute depthSensor {
			attribute maxDepth : LengthValue;
			attribute accuracy : LengthValue;
		}
		
		attribute compass {
			attribute accuracy : Real;
		}
		
		attribute gyroscope {
			attribute driftRate : Real;
		}
		
		attribute altimeter {
			attribute range : LengthValue;
		}
	}
	
	part def ManipulatorArm {
		port control : ControlPort;
		port power : PowerPort;
		
		attribute reach : LengthValue;
		attribute graspForce : ForceValue;
		attribute degreesOfFreedom : Integer;
		attribute payloadCapacity : MassValue;
		
		part gripper {
			attribute maxOpening : LengthValue;
			attribute gripStrength : ForceValue;
		}
		
		part joints[6] {
			attribute rotationRange : Real;
			attribute torque : TorqueValue;
		}
	}
	
	part def LightingSystem {
		port power : PowerPort;
		
		attribute intensity : LuminousIntensityValue;
		attribute beamAngle : Real;
		attribute powerConsumption : PowerValue;
		attribute numberOfLights : Integer;
	}
	
	part def BatteryPack {
		port powerOutput : ~PowerPort;
		
		attribute capacity : Real;
		attribute voltage : ElectricPotentialValue;
		attribute stateOfCharge : Real;
		attribute maxDischargeCurrent : ElectricCurrentValue;
	}
	
	part def ROVFrame {
		port mainControl : ControlPort;
		port videoOut : VideoPort;
		port powerIn : PowerPort;
		
		attribute mass : MassValue;
		attribute buoyancy : ForceValue;
		attribute dragCoefficient : Real;
		attribute maxDepthRating : LengthValue;
		
		part navigation : NavigationSystem;
		part cameras : CameraSystem[2];
		part sonar : SonarSystem;
		part manipulator : ManipulatorArm;
		part lighting : LightingSystem;
		part battery : BatteryPack;
		part thrusters : Thruster[6];
		
		part controlComputer {
			attribute processorSpeed : FrequencyValue;
			attribute memoryCapacity : Real;
		}
		
		part pressureHousing {
			attribute maxPressure : PressureValue;
			attribute material : String;
		}
	}
	
	part rovSystem {
		part surfaceStation : SurfaceControlStation;
		part tether : UmbilicalTether;
		part rov : ROVFrame;
		
		connect surfaceStation.controlInterface to tether.surfaceEnd;
		connect tether.vehicleEnd to rov.mainControl;
		connect surfaceStation.powerSupply to tether.powerLine;
		connect tether.powerLine to rov.powerIn;
		connect rov.videoOut to surfaceStation.videoReceiver;
	}
	
	action def TransmitControl {
		in command : ControlCommand;
		out transmittedCommand : ControlCommand;
	}
	
	action def ProcessTelemetry {
		in sensorData : TelemetryData;
		in sonarData : SonarData;
		out displayData : TelemetryData;
	}
	
	action def ComputeThrusterCommands {
		in targetDepth : LengthValue;
		in targetHeading : Real;
		in currentDepth : LengthValue;
		in currentHeading : Real;
		out thrustVector : Real[3];
	}
	
	action def CaptureVideo {
		in lightLevel : LuminousIntensityValue;
		in cameraSettings : VideoResolution;
		out videoFeed : VideoStream;
	}
	
	action def OperateManipulator {
		in action : ManipulatorAction;
		in targetPosition : LengthValue[3];
		out armPosition : LengthValue[3];
		out graspState : Boolean;
	}
	
	action def ScanEnvironment {
		in sonarRange : LengthValue;
		out sonarData : SonarData;
	}
	
	action def PerformUnderwaterInspection {
		in missionParameters : ControlCommand;
		out inspectionData : VideoStream;
		out environmentalData : TelemetryData;
		
		first start;
		then merge missionLoop;
		
		then action deploy {
			doc /* Deploy ROV from surface station into water */
		}
		
		then action descend : ComputeThrusterCommands {
			in targetDepth;
			in targetHeading;
			in currentDepth;
			in currentHeading;
			out thrustVector;
		}
		
		then action navigate {
			action transmitCommand : TransmitControl;
			action adjustThrusters : ComputeThrusterCommands;
			action scanSonar : ScanEnvironment;
		}
		
		then action inspect {
			action captureVideo : CaptureVideo;
			action operateArm : OperateManipulator;
			action measureEnvironment;
		}
		
		then action transmitData : ProcessTelemetry {
			in sensorData;
			in sonarData;
			out displayData;
		}
		
		then decide;
			if missionComplete then ascend;
			if not missionComplete then missionLoop;
		
		action ascend : ComputeThrusterCommands {
			in targetDepth = 0.0 [m];
			in targetHeading;
			in currentDepth;
			in currentHeading;
			out thrustVector;
		}
		
		then action recover {
			doc /* Recover ROV to surface station */
		}
		
		then done;
		
		attribute missionComplete : Boolean;
	}
	
	state def ROVOperationalStates {
		entry; then standby;
		
		state standby {
			do action performPreflightChecks;
		}
		
		transition standby_to_deploying
			first standby
			accept deployCommand : ControlCommand
			then deploying;
		
		state deploying {
			entry action lowerIntoWater;
			do action establishCommunications;
			do action checkSystems;
		}
		
		transition deploying_to_descending
			first deploying
			if systemsNominal
			then descending;
		
		state descending {
			do action descendToDepth : ComputeThrusterCommands;
			do action monitorDepth;
		}
		
		transition descending_to_operational
			first descending
			if targetDepthReached
			then operational;
		
		state operational {
			entry action enableAllSystems;
			
			state navigating {
				do action maintainPosition : ComputeThrusterCommands;
				do action scanEnvironment : ScanEnvironment;
			}
			
			state inspecting {
				do action captureVideo : CaptureVideo;
				do action recordData;
			}
			
			state manipulating {
				do action operateManipulator : OperateManipulator;
				do action monitorGripper;
			}
			
			transition navigating_to_inspecting
				first navigating
				accept inspectCommand
				then inspecting;
			
			transition inspecting_to_manipulating
				first inspecting
				accept manipulateCommand
				then manipulating;
			
			transition manipulating_to_navigating
				first manipulating
				accept navigateCommand
				then navigating;
		}
		
		transition operational_to_ascending
			first operational
			accept recallCommand : ControlCommand
			then ascending;
		
		transition operational_to_emergency
			first operational
			if emergencyCondition
			then emergency;
		
		state ascending {
			do action ascendToSurface : ComputeThrusterCommands;
			do action monitorAscent;
		}
		
		transition ascending_to_recovery
			first ascending
			if surfaceReached
			then recovery;
		
		state recovery {
			do action retrieveROV;
			do action secureEquipment;
		}
		
		transition recovery_to_standby
			first recovery
			if rovSecured
			then standby;
		
		state emergency {
			entry action dropWeights;
			do action emergencyAscent : ComputeThrusterCommands;
			do action activateBeacon;
		}
		
		transition emergency_to_recovery
			first emergency
			if surfaceReached
			then recovery;
		
		attribute systemsNominal : Boolean;
		attribute targetDepthReached : Boolean;
		attribute surfaceReached : Boolean;
		attribute rovSecured : Boolean;
		attribute emergencyCondition : Boolean;
	}
	
	requirement def DepthCapabilityRequirement {
		doc /* The ROV shall operate at depths up to 3000 meters. */
		
		subject rov : ROVFrame;
		
		require constraint {
			rov.navigation.depthSensor.maxDepth >= 3000.0 [m]
		}
	}
	
	requirement def EnduranceRequirement {
		doc /* The ROV shall operate continuously for at least 8 hours on battery power. */
		
		subject rov : ROVFrame;
		
		require constraint {
			rov.battery.capacity >= 8.0
		}
	}
	
	requirement def VideoQualityRequirement {
		doc /* The camera system shall provide high-definition video at minimum 30 fps. */
		
		subject camera : CameraSystem;
		
		require constraint {
			camera.frameRate >= 30.0 [Hz]
		}
		
		require constraint {
			camera.resolution.verticalPixels >= 1080
		}
	}
	
	requirement def ManipulationRequirement {
		doc /* The manipulator arm shall have at least 5 degrees of freedom and lift 50 kg. */
		
		subject manipulator : ManipulatorArm;
		
		require constraint {
			manipulator.degreesOfFreedom >= 5
		}
		
		require constraint {
			manipulator.payloadCapacity >= 50.0 [kg]
		}
	}
	
	requirement def TetherIntegrityRequirement {
		doc /* The tether shall maintain structural integrity under maximum operating tension. */
		
		subject tether : UmbilicalTether;
		
		require constraint {
			tether.maxTension >= 5000.0 [N]
		}
	}
	
	requirement <'ROV-SYS-001'> primaryMissionRequirement {
		doc /* The ROV system shall enable remote underwater observation, inspection, and intervention operations by transmitting real-time video and telemetry to a surface control station while executing operator commands to navigate, manipulate objects, and collect environmental data at depths up to 3000 meters. */
		
		subject system : rovSystem;
		
		assume constraint operatorPresent {
			doc /* A trained operator is present at the surface control station. */
		}
		
		assume constraint environmentalLimits {
			doc /* Operating environment is within specified temperature (-2 to 35 degrees C) and current (less than 2 knots) ranges. */
		}
		
		require depthCapability : DepthCapabilityRequirement {
			subject rov = system.rov;
		}
		
		require endurance : EnduranceRequirement {
			subject rov = system.rov;
		}
		
		require videoQuality : VideoQualityRequirement {
			subject camera = system.rov.cameras[1];
		}
		
		require manipulation : ManipulationRequirement {
			subject manipulator = system.rov.manipulator;
		}
		
		require tetherIntegrity : TetherIntegrityRequirement {
			subject tether = system.tether;
		}
	}
}
