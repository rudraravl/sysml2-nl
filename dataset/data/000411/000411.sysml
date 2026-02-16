package 'Taurob Inspector System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NavigationCommand;
	attribute def TelemetryPacket;
	attribute def VideoStream;
	attribute def GasConcentration;
	attribute def OperatorCommand;
	attribute def SystemStatus;
	
	attribute def InspectionData {
		attribute timestamp : TimeValue;
		attribute location : LengthValue[3];
		attribute gasLevel : Real;
		attribute thermalReading : ThermodynamicTemperatureValue;
		attribute visualData : VideoStream;
	}
	
	attribute def MissionParameters {
		attribute duration : TimeValue;
		attribute inspectionPoints : LengthValue[3][*];
		attribute hazardThreshold : Real;
	}
	
	port def PowerPort {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	port def DataPort {
		in command : OperatorCommand;
		out telemetry : TelemetryPacket;
	}
	
	port def SensorDataPort {
		out sensorReadings : InspectionData;
	}
	
	port def ControlPort {
		in navigationCmd : NavigationCommand;
		out status : SystemStatus;
	}
	
	part def TrackedChassis {
		doc /* Ruggedized tracked mobility platform for traversing rough terrain and obstacles */
		
		part leftTrack : Track;
		part rightTrack : Track;
		part driveMotors : Motor[2];
		part suspensionSystem : Suspension;
		
		port powerIn : PowerPort;
		port controlIn : ControlPort;
		
		attribute maxSpeed : SpeedValue;
		attribute maxClimbAngle : Real;
		attribute groundClearance : LengthValue;
		
		perform action executeMotion;
	}
	
	part def Track {
		attribute width : LengthValue;
		attribute length : LengthValue;
		attribute material : String;
	}
	
	part def Motor {
		attribute ratedPower : PowerValue;
		attribute maxTorque : TorqueValue;
		attribute efficiency : Real;
	}
	
	part def Suspension {
		attribute travel : LengthValue;
		attribute dampingFactor : Real;
	}
	
	part def MultiSensorArray {
		doc /* Integrated sensor suite for environmental monitoring and hazard detection */
		
		part visualCameras : Camera[4];
		part thermalCamera : ThermalImager;
		part gasDetectors : GasDetector[3];
		part lidarScanner : LidarUnit;
		part imuSensor : IMU;
		
		port powerIn : PowerPort;
		port dataOut : SensorDataPort;
		
		perform action acquireData;
	}
	
	part def Camera {
		attribute resolution : String;
		attribute frameRate : FrequencyValue;
		attribute fov : Real;
	}
	
	part def ThermalImager {
		attribute thermalSensitivity : ThermodynamicTemperatureValue;
		attribute temperatureRange : ThermodynamicTemperatureValue[2];
	}
	
	part def GasDetector {
		attribute detectedGases : String[*];
		attribute sensitivity : Real;
		attribute responseTime : TimeValue;
	}
	
	part def LidarUnit {
		attribute range : LengthValue;
		attribute angularResolution : Real;
		attribute scanRate : FrequencyValue;
	}
	
	part def IMU {
		attribute accelerometerRange : AccelerationValue;
		attribute gyroscopeRange : Real;
	}
	
	part def ArticulatedManipulator {
		doc /* Multi-degree-of-freedom robotic arm for object manipulation and sample collection */
		
		part baseJoint : Joint;
		part shoulderJoint : Joint;
		part elbowJoint : Joint;
		part wristJoint : Joint;
		part endEffector : Gripper;
		
		port powerIn : PowerPort;
		port controlIn : ControlPort;
		
		attribute reach : LengthValue;
		attribute payloadCapacity : MassValue;
		
		perform action manipulate;
	}
	
	part def Joint {
		attribute rangeOfMotion : Real;
		attribute maxTorque : TorqueValue;
		attribute actuatorType : String;
	}
	
	part def Gripper {
		attribute maxGripForce : ForceValue;
		attribute openingWidth : LengthValue;
	}
	
	part def OnboardComputer {
		doc /* Central processing unit for autonomous navigation and mission control */
		
		part mainProcessor : Processor;
		part navigationModule : NavigationController;
		part autonomyEngine : AutonomyModule;
		part safetyController : SafetySystem;
		
		port powerIn : PowerPort;
		port sensorIn : SensorDataPort;
		port controlOut : ControlPort;
		port commPort : DataPort;
		
		perform action processData;
		perform action planMission;
	}
	
	part def Processor {
		attribute cores : Integer;
		attribute clockSpeed : FrequencyValue;
		attribute memory : String;
	}
	
	part def NavigationController {
		perform action computePath;
		perform action avoidObstacles;
	}
	
	part def AutonomyModule {
		attribute autonomyLevel : Integer;
		perform action makeDecisions;
	}
	
	part def SafetySystem {
		perform action monitorSafety;
		perform action emergencyStop;
	}
	
	part def BatteryPack {
		doc /* High-capacity rechargeable battery system for extended operation */
		
		part cells : BatteryCell[*];
		part bms : BatteryManagementSystem;
		part chargingInterface : ChargingPort;
		
		port powerOut : PowerPort;
		
		attribute capacity : EnergyValue;
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute chargeLevel : Real;
		
		perform action supplyPower;
		perform action monitorCharge;
	}
	
	part def BatteryCell {
		attribute cellCapacity : EnergyValue;
		attribute cellVoltage : ISQ::ElectricPotentialValue;
		attribute chemistry : String;
	}
	
	part def BatteryManagementSystem {
		perform action balanceCells;
		perform action protectBattery;
	}
	
	part def ChargingPort {
		attribute chargingPower : PowerValue;
		attribute connectorType : String;
	}
	
	part def WirelessCommunication {
		doc /* Long-range wireless system for teleoperation and data transmission */
		
		part radioModule : Radio;
		part antennas : Antenna[2];
		part encryptionModule : Encryption;
		
		port powerIn : PowerPort;
		port dataPort : DataPort;
		
		attribute range : LengthValue;
		attribute bandwidth : String;
		
		perform action transmit;
		perform action receive;
	}
	
	part def Radio {
		attribute frequency : FrequencyValue;
		attribute transmitPower : PowerValue;
		attribute protocol : String;
	}
	
	part def Antenna {
		attribute gain : Real;
		attribute polarization : String;
	}
	
	part def Encryption {
		attribute algorithm : String;
		attribute keyLength : Integer;
	}
	
	part def TaurobInspector {
		doc /* Mobile robotic platform for autonomous inspection of hazardous and confined industrial environments */
		
		part chassis : TrackedChassis;
		part sensors : MultiSensorArray;
		part manipulator : ArticulatedManipulator;
		part computer : OnboardComputer;
		part battery : BatteryPack;
		part communications : WirelessCommunication;
		
		attribute missionActive : Boolean;
		attribute currentPosition : LengthValue[3];
		attribute batteryLow : Boolean;
		attribute arrivedAtInspectionPoint : Boolean;
		attribute sampleRequired : Boolean;
		attribute sampleCollected : Boolean;
		attribute inspectionComplete : Boolean;
		attribute missionComplete : Boolean;
		attribute hazardDetected : Boolean;
		attribute safetyCleared : Boolean;
		
		connect battery.powerOut to chassis.powerIn;
		connect battery.powerOut to sensors.powerIn;
		connect battery.powerOut to manipulator.powerIn;
		connect battery.powerOut to computer.powerIn;
		connect battery.powerOut to communications.powerIn;
		
		connect sensors.dataOut to computer.sensorIn;
		connect computer.controlOut to chassis.controlIn;
		connect computer.controlOut to manipulator.controlIn;
		connect computer.commPort to communications.dataPort;
		
		exhibit state machine OperationalBehavior {
			initial state Standby;
			
			state Active {
				entry action enterActive;
				
				state Navigating {
					entry action startNavigation;
				}
				
				state Inspecting {
					entry action startInspection;
				}
				
				state Manipulating {
					entry action startManipulation;
				}
				
				transition first from Navigating to Inspecting
					when arrivedAtInspectionPoint;
				
				transition second from Inspecting to Manipulating
					when sampleRequired;
				
				transition third from Manipulating to Navigating
					when sampleCollected;
				
				transition fourth from Inspecting to Navigating
					when inspectionComplete;
			}
			
			state Charging {
				entry action startCharging;
			}
			
			state Emergency {
				entry action activateEmergency;
			}
			
			transition t1 from Standby to Active
				when missionActive;
			
			transition t2 from Active to Standby
				when missionComplete;
			
			transition t3 from Active to Charging
				when batteryLow;
			
			transition t4 from Charging to Standby
				when battery.chargeLevel >= 0.95;
			
			transition t5 from Active to Emergency
				when hazardDetected;
			
			transition t6 from Emergency to Standby
				when safetyCleared;
		}
		
		perform action conductInspectionMission[*] ordered references inspectEnvironment;
	}
	
	action def InspectEnvironment {
		in missionParams : MissionParameters;
		out inspectionResults : InspectionData[*];
		out missionSuccess : Boolean;
	}
	
	action def NavigateToLocation {
		in targetPosition : LengthValue[3];
		in obstacleData : String;
		out arrived : Boolean;
		out pathTaken : LengthValue[3][*];
	}
	
	action def PerformInspection {
		in location : LengthValue[3];
		out visualData : VideoStream;
		out thermalData : ThermodynamicTemperatureValue[*];
		out gasData : Real[*];
		out pointCloud : LengthValue[3][*];
	}
	
	action def CollectSample {
		in targetObject : String;
		in approachStrategy : String;
		out sampleAcquired : Boolean;
		out sampleData : String;
	}
	
	action inspectEnvironment : InspectEnvironment {
		in missionParams : MissionParameters;
		out inspectionResults : InspectionData[*] := ( );
		out missionSuccess : Boolean;
		
		private attribute collectedData : InspectionData[*] := ( );
		private attribute currentIndex : Integer := 0;
		
		first start;
		
		then action initialize {
			action activateSystems {
				doc /* Power up all subsystems and perform self-diagnostics */
			}
			then action calibrateSensors {
				doc /* Calibrate IMU, cameras, and environmental sensors */
			}
			then action establishLink {
				doc /* Establish communication with operator control station */
			}
		}
		
		then merge missionLoop;
		
		action missionLoop {
			action getNextWaypoint {
				out waypoint : LengthValue[3];
			}
			
			then action navigateToWaypoint : NavigateToLocation {
				in targetPosition = getNextWaypoint.waypoint;
				in obstacleData;
				out arrived;
				out pathTaken;
				
				action scanForObstacles {
					doc /* Use LIDAR to detect obstacles in path */
				}
				then action planOptimalPath {
					doc /* Calculate collision-free trajectory */
				}
				then action executeTrajectory {
					doc /* Control tracks to follow planned path */
				}
				then action verifyArrival {
					doc /* Confirm position using IMU and sensors */
				}
			}
			
			then action performInspection : PerformInspection {
				in location = navigateToWaypoint.targetPosition;
				out visualData;
				out thermalData;
				out gasData;
				out pointCloud;
				
				action captureVisual {
					doc /* Record high-resolution video from all cameras */
				}
				then action scanThermal {
					doc /* Acquire thermal imagery to detect hot spots */
				}
				then action measureGas {
					doc /* Sample air for hazardous gas concentrations */
				}
				then action scanLidar {
					doc /* Generate 3D point cloud of surroundings */
				}
				then action compileData {
					doc /* Aggregate sensor data into inspection record */
				}
			}
			
			then decide;
				if gasLevelExceedsThreshold then collectSample;
				if moreWaypointsRemain then missionLoop;
				else finalizeMission;
			
			action collectSample : CollectSample {
				in targetObject;
				in approachStrategy;
				out sampleAcquired;
				out sampleData;
				
				action positionManipulator {
					doc /* Move arm to sample location */
				}
				then action graspSample {
					doc /* Close gripper on target object */
				}
				then action retrieveSample {
					doc /* Retract arm with sample */
				}
				then action storeSample {
					doc /* Place sample in storage compartment */
				}
			}
			then missionLoop;
		}
		
		action finalizeMission {
			action transmitResults {
				doc /* Send complete inspection data to operator */
			}
			then action returnToStart {
				doc /* Navigate back to deployment location */
			}
			then action shutdownSystems {
				doc /* Safe shutdown of all subsystems */
			}
			then assign missionSuccess := true;
		}
		
		then done;
	}
	
	part inspector : TaurobInspector {
		perform inspectEnvironment;
		
		part f : TrackedChassis {
			perform inspectEnvironment.navigateToWaypoint.executeTrajectory;
		}
		
		part s : MultiSensorArray {
			perform inspectEnvironment.performInspection.captureVisual;
			perform inspectEnvironment.performInspection.scanThermal;
			perform inspectEnvironment.performInspection.measureGas;
			perform inspectEnvironment.performInspection.scanLidar;
		}
		
		part m : ArticulatedManipulator {
			perform inspectEnvironment.collectSample.positionManipulator;
			perform inspectEnvironment.collectSample.graspSample;
		}
		
		part c : OnboardComputer {
			perform inspectEnvironment.initialize;
			perform inspectEnvironment.navigateToWaypoint.planOptimalPath;
			perform inspectEnvironment.performInspection.compileData;
		}
		
		part b : BatteryPack {
			perform inspectEnvironment.initialize.activateSystems;
		}
		
		part w : WirelessCommunication {
			perform inspectEnvironment.initialize.establishLink;
			perform inspectEnvironment.finalizeMission.transmitResults;
		}
	}
	
	requirement <'INSP-REQ-001'> primaryMissionCapability {
		doc /* The Taurob Inspector shall autonomously navigate hazardous industrial environments 
		       to perform comprehensive multi-modal inspections while maintaining continuous 
		       communication with remote operators, enabling safe assessment of dangerous areas 
		       without human exposure to risk. */
		
		require mobilityRequirement;
		require sensingRequirement;
		require enduranceRequirement;
		require communicationRequirement;
	}
	
	requirement <'INSP-REQ-002'> mobilityRequirement {
		doc /* The system shall traverse rough terrain with obstacles up to 45 degrees inclination */
		
		require constraint {
			inspector.chassis.maxClimbAngle >= 45.0
		}
	}
	
	requirement <'INSP-REQ-003'> sensingRequirement {
		doc /* The system shall provide visual, thermal, gas detection, and 3D mapping capabilities */
		
		require constraint {
			inspector.sensors.visualCameras->size() >= 4
		}
		
		require constraint {
			inspector.sensors.gasDetectors->size() >= 3
		}
	}
	
	requirement <'INSP-REQ-004'> enduranceRequirement {
		doc /* The system shall operate continuously for minimum 4 hours on single battery charge */
		
		require constraint {
			inspector.battery.capacity >= 2000.0
		}
	}
	
	requirement <'INSP-REQ-005'> communicationRequirement {
		doc /* The system shall maintain wireless communication over minimum 500 meter range */
		
		require constraint {
			inspector.communications.range >= 500.0
		}
	}
	
	requirement <'INSP-REQ-006'> manipulationRequirement {
		doc /* The manipulator shall handle objects up to 5 kg at full extension */
		
		require constraint {
			inspector.manipulator.payloadCapacity >= 5.0
		}
	}
}
