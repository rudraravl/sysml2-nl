package TeleroboticSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def ControlCommand {
		attribute commandID : String;
		attribute timestamp : DurationValue;
		attribute jointAngles : PlaneAngleValue[6];
		attribute gripperState : GripperCommand;
		attribute forceLimit : ForceValue;
	}
	
	enum def GripperCommand {
		enum open;
		enum close;
		enum hold;
	}
	
	item def SensorFeedback {
		attribute timestamp : DurationValue;
		attribute jointPositions : PlaneAngleValue[6];
		attribute jointVelocities : AngularVelocityValue[6];
		attribute endEffectorPosition : LengthValue[3];
		attribute endEffectorOrientation : PlaneAngleValue[3];
		attribute appliedForce : ForceValue[3];
		attribute appliedTorque : TorqueValue[3];
		attribute gripperPosition : LengthValue;
	}
	
	item def VideoStream {
		attribute frameRate : FrequencyValue;
		attribute resolution : Integer[2];
		attribute compressionRatio : Real;
		attribute bandwidth : Real;
	}
	
	attribute def DataRateValue :> Real;
	attribute def LatencyValue :> DurationValue;
	
	port def OperatorControlPort {
		out item commandOut : ControlCommand;
		in item feedbackIn : SensorFeedback;
		in item videoIn : VideoStream;
	}
	
	port def CommunicationUplink {
		in item commandIn : ControlCommand;
		out item ackOut : Boolean;
	}
	
	port def CommunicationDownlink {
		out item feedbackOut : SensorFeedback;
		out item videoOut : VideoStream;
	}
	
	port def RobotCommandPort {
		in item commandIn : ControlCommand;
		out item statusOut : SensorFeedback;
	}
	
	port def ActuatorPort {
		in item setpoint : PlaneAngleValue;
		out item position : PlaneAngleValue;
		out item torque : TorqueValue;
	}
	
	port def SensorPort {
		out item measurement : SensorFeedback;
	}
	
	part def OperatorStation {
		doc /* Human-machine interface for remote robot control */
		
		port controlInterface : OperatorControlPort;
		
		part display {
			attribute screenSize : LengthValue;
			attribute refreshRate : FrequencyValue;
		}
		
		part inputDevice {
			attribute degreesOfFreedom : Integer = 6;
			attribute forceFeedbackEnabled : Boolean = true;
		}
		
		perform action operateRemoteRobot {
			first start;
			then observeEnvironment;
			
			action observeEnvironment {
				in videoFeed : VideoStream;
				in sensorData : SensorFeedback;
				out situationAssessment : String;
			}
			
			then planAction;
			
			action planAction {
				in assessment : String;
				out taskPlan : String;
			}
			
			then generateCommand;
			
			action generateCommand {
				in plan : String;
				out command : ControlCommand;
			}
			
			then transmitCommand;
			
			action transmitCommand {
				in command : ControlCommand;
			}
			
			then observeEnvironment;
		}
	}
	
	part def CommunicationSystem {
		doc /* Bidirectional communication link between operator and robot */
		
		port operatorSide : CommunicationUplink;
		port robotSide : CommunicationDownlink;
		
		attribute uplinkBandwidth : DataRateValue;
		attribute downlinkBandwidth : DataRateValue;
		attribute roundTripLatency : LatencyValue;
		attribute packetLossRate : Real;
		attribute encryptionEnabled : Boolean = true;
		
		attribute linkEstablished : Boolean;
		attribute signalWeakened : Boolean;
		attribute connectionLost : Boolean;
		attribute signalRestored : Boolean;
		attribute reconnectInitiated : Boolean;
		
		perform action maintainCommunication {
			first start;
			then merge commLoop;
			
			action receiveCommand {
				in command : ControlCommand;
				out encryptedCommand : ControlCommand;
			}
			
			then action forwardCommand {
				in encryptedCommand : ControlCommand;
			}
			
			then action receiveFeedback {
				in feedback : SensorFeedback;
				in video : VideoStream;
				out compressedData : SensorFeedback;
			}
			
			then action forwardFeedback {
				in compressedData : SensorFeedback;
			}
			
			then commLoop;
		}
		
		state def CommunicationStates {
			entry; then idle;
			
			state idle;
			transition idle_to_connecting
				first idle
				accept at startTime
				then connecting;
			
			state connecting {
				do action establishLink;
			}
			transition connecting_to_active
				first connecting
				if linkEstablished
				then active;
			
			state active {
				do action transferData;
			}
			transition active_to_degraded
				first active
				if signalWeakened
				then degraded;
			transition active_to_disconnected
				first active
				if connectionLost
				then disconnected;
			
			state degraded {
				do action reduceDataRate;
			}
			transition degraded_to_active
				first degraded
				if signalRestored
				then active;
			transition degraded_to_disconnected
				first degraded
				if connectionLost
				then disconnected;
			
			state disconnected {
				do action attemptReconnection;
			}
			transition disconnected_to_connecting
				first disconnected
				if reconnectInitiated
				then connecting;
		}
	}
	
	part def RobotController {
		attribute controlFrequency : FrequencyValue;
		attribute maxJointVelocity : AngularVelocityValue;
		attribute maxJointAcceleration : AngularAccelerationValue;
		
		perform action controlRobot {
			first start;
			then merge controlLoop;
			
			action readCommand {
				in command : ControlCommand;
				out parsedCommand : ControlCommand;
			}
			
			action computeInverseKinematics {
				in parsedCommand : ControlCommand;
				out jointSetpoints : PlaneAngleValue[6];
			}
			
			action generateTrajectory {
				in jointSetpoints : PlaneAngleValue[6];
				in currentPositions : PlaneAngleValue[6];
				out trajectoryPoints : PlaneAngleValue[*];
			}
			
			action applyControl {
				in trajectoryPoints : PlaneAngleValue[*];
				out controlSignals : TorqueValue[6];
			}
			
			action monitorSafety {
				in currentState : SensorFeedback;
				out safetyStatus : Boolean;
			}
			
			then decide;
			if monitorSafety.safetyStatus == true then controlLoop;
			if monitorSafety.safetyStatus == false then emergencyStop;
			
			action emergencyStop {
				out stopCommand : ControlCommand;
			}
		}
	}
	
	part def RoboticManipulator {
		attribute degreesOfFreedom : Integer = 6;
		attribute maxReach : LengthValue;
		attribute maxPayload : MassValue;
		attribute repeatability : LengthValue;
		
		part joint1 : RevoluteJoint;
		part joint2 : RevoluteJoint;
		part joint3 : RevoluteJoint;
		part joint4 : RevoluteJoint;
		part joint5 : RevoluteJoint;
		part joint6 : RevoluteJoint;
		part endEffector : Gripper;
		
		port actuatorPorts : ActuatorPort[6];
	}
	
	part def RevoluteJoint {
		attribute currentAngle : PlaneAngleValue;
		attribute targetAngle : PlaneAngleValue;
		attribute maxVelocity : AngularVelocityValue;
		attribute maxTorque : TorqueValue;
		attribute rangeMin : PlaneAngleValue;
		attribute rangeMax : PlaneAngleValue;
		
		part motor {
			attribute ratedTorque : TorqueValue;
			attribute ratedSpeed : AngularVelocityValue;
		}
		
		part gearbox {
			attribute ratio : Real;
			attribute efficiency : Real;
		}
		
		part encoder {
			attribute resolution : Integer;
			attribute accuracy : PlaneAngleValue;
		}
		
		perform action moveToTarget {
			first start;
			then calculateError;
			
			action calculateError {
				in target : PlaneAngleValue;
				in current : PlaneAngleValue;
				out error : PlaneAngleValue;
			}
			
			then applyControl;
			
			action applyControl {
				in error : PlaneAngleValue;
				out torque : TorqueValue;
			}
			
			then updatePosition;
			
			action updatePosition {
				in torque : TorqueValue;
				out newPosition : PlaneAngleValue;
			}
			
			then done;
		}
	}
	
	part def Gripper {
		attribute maxGripForce : ForceValue;
		attribute maxOpeningWidth : LengthValue;
		attribute currentOpening : LengthValue;
		attribute graspDetected : Boolean;
		attribute forceDetected : Boolean;
		
		part fingerLeft {
			attribute position : LengthValue;
		}
		
		part fingerRight {
			attribute position : LengthValue;
		}
		
		part forceSensor {
			attribute sensitivity : ForceValue;
			attribute range : ForceValue;
		}
		
		state def GripperStates {
			entry; then idle;
			
			state idle;
			transition idle_to_opening
				first idle
				accept at startTime
				then opening;
			transition idle_to_closing
				first idle
				accept at startTime
				then closing;
			
			state opening {
				entry assign graspDetected := false;
				do action moveFingers {
					out direction : String = "open";
				}
			}
			transition opening_to_open
				first opening
				if currentOpening >= maxOpeningWidth
				then open;
			
			state open {
				entry assign graspDetected := false;
			}
			transition open_to_closing
				first open
				accept at startTime
				then closing;
			
			state closing {
				do action moveFingers {
					out direction : String = "close";
				}
			}
			transition closing_to_grasping
				first closing
				if forceDetected
				then grasping;
			transition closing_to_closed
				first closing
				if currentOpening <= 0.0
				then closed;
			
			state grasping {
				entry assign graspDetected := true;
				do action maintainGrasp;
			}
			transition grasping_to_opening
				first grasping
				accept at startTime
				then opening;
			
			state closed;
			transition closed_to_opening
				first closed
				accept at startTime
				then opening;
		}
	}
	
	part def SensorArray {
		port sensorOutput : SensorPort;
		
		part forceTorqueSensor {
			attribute range : ForceValue[3];
			attribute resolution : ForceValue;
		}
		
		part positionSensor {
			attribute accuracy : LengthValue;
			attribute updateRate : FrequencyValue;
		}
		
		part proximityDetector {
			attribute detectionRange : LengthValue;
			attribute fieldOfView : PlaneAngleValue;
		}
		
		part tactileSensor {
			attribute sensitivity : PressureValue;
			attribute spatialResolution : LengthValue;
		}
		
		perform action collectData {
			action readForce {
				out forceData : ForceValue[3];
			}
			
			action readTorque {
				out torqueData : TorqueValue[3];
			}
			
			action readPosition {
				out positionData : LengthValue[3];
			}
			
			action readOrientation {
				out orientationData : PlaneAngleValue[3];
			}
			
			action aggregateSensorData {
				in forceData : ForceValue[3];
				in torqueData : TorqueValue[3];
				in positionData : LengthValue[3];
				in orientationData : PlaneAngleValue[3];
				out sensorPacket : SensorFeedback;
			}
		}
	}
	
	part def VisionSystem {
		attribute resolution : Integer[2];
		attribute frameRate : FrequencyValue;
		attribute fieldOfView : PlaneAngleValue;
		attribute depthSensingEnabled : Boolean = true;
		
		part camera {
			attribute sensorType : String = "CMOS";
			attribute pixelSize : LengthValue;
		}
		
		part lens {
			attribute focalLength : LengthValue;
			attribute aperture : Real;
		}
		
		part imageProcessor {
			attribute processingPower : Real;
		}
		
		perform action captureAndStream {
			first start;
			then merge streamLoop;
			
			action acquireFrame {
				out rawFrame : VideoStream;
			}
			
			then action processImage {
				in rawFrame : VideoStream;
				out processedFrame : VideoStream;
			}
			
			then action compressFrame {
				in processedFrame : VideoStream;
				out compressedFrame : VideoStream;
			}
			
			then action transmitFrame {
				in compressedFrame : VideoStream;
			}
			
			then streamLoop;
		}
	}
	
	part def RemoteRobot {
		doc /* Robotic manipulator system operating in remote environment */
		
		port commandInterface : RobotCommandPort;
		
		part controller : RobotController;
		part manipulator : RoboticManipulator;
		part sensorSuite : SensorArray;
		part camera : VisionSystem;
		part powerSupply {
			attribute voltage : ElectricPotentialValue;
			attribute capacity : EnergyValue;
		}
		
		perform action executeRemoteTask {
			first start;
			then merge executionLoop;
			
			action receiveCommand {
				in command : ControlCommand;
				out validatedCommand : ControlCommand;
			}
			
			then action planTrajectory {
				in validatedCommand : ControlCommand;
				out trajectory : PlaneAngleValue[*];
			}
			
			then action executeMotion {
				in trajectory : PlaneAngleValue[*];
			}
			
			then action acquireSensorData {
				out sensorData : SensorFeedback;
			}
			
			then action captureVideo {
				out videoStream : VideoStream;
			}
			
			then action transmitFeedback {
				in sensorData : SensorFeedback;
				in videoStream : VideoStream;
			}
			
			then executionLoop;
		}
	}
	
	part def TeleroboticSystemAssembly;
	
	part teleroboticSystem : TeleroboticSystemAssembly {
		doc /* 
		A telerobotics system enables remote operation of a robotic manipulator 
		across distance. The primary function is to allow a human operator to 
		perform dexterous manipulation tasks in hazardous, inaccessible, or 
		remote environments by transmitting control commands to the robot and 
		receiving real-time sensory feedback including video, force, and position 
		data through a bidirectional communication link.
		*/
		
		part operator : OperatorStation;
		part commSystem : CommunicationSystem;
		part robot : RemoteRobot;
		
		connect operator.controlInterface.commandOut to commSystem.operatorSide.commandIn;
		connect commSystem.robotSide.feedbackOut to operator.controlInterface.feedbackIn;
		connect commSystem.robotSide.videoOut to operator.controlInterface.videoIn;
		
		perform action performTeleoperation {
			first start;
			then initializeSystem;
			
			action initializeSystem {
				out systemReady : Boolean;
			}
			
			then establishLink;
			
			action establishLink {
				out linkActive : Boolean;
			}
			
			then merge operationLoop;
			
			action captureOperatorIntent {
				out operatorCommand : ControlCommand;
			}
			then operationLoop;
			
			action transmitToRobot {
				in operatorCommand : ControlCommand;
			}
			then operationLoop;
			
			action executeRobotMotion {
				in robotCommand : ControlCommand;
			}
			then operationLoop;
			
			action acquireFeedback {
				out feedback : SensorFeedback;
				out video : VideoStream;
			}
			then operationLoop;
			
			action presentToOperator {
				in feedback : SensorFeedback;
				in video : VideoStream;
			}
			then operationLoop;
			
			action monitorSystemHealth {
				out healthStatus : String;
			}
			then decide;
			
			if monitorSystemHealth.healthStatus == "nominal" then operationLoop;
			if monitorSystemHealth.healthStatus == "degraded" then handleDegradation;
			if monitorSystemHealth.healthStatus == "critical" then emergencyShutdown;
			
			action handleDegradation {
				out mitigationAction : String;
			}
			then operationLoop;
			
			action emergencyShutdown;
		}
		
		satisfy primaryFunctionRequirement;
		satisfy latencyRequirement;
		satisfy reliabilityRequirement;
		satisfy safetyRequirement;
	}
	
	requirement <'TR-REQ-001'> primaryFunctionRequirement {
		doc /* 
		The telerobotics system shall enable remote manipulation of objects 
		in hazardous or inaccessible environments through bidirectional 
		command and feedback transmission.
		*/
		
		subject system : TeleroboticSystemAssembly;
		
		require commandTransmission {
			doc /* System shall transmit operator commands to remote robot. */
		}
		
		require feedbackReception {
			doc /* System shall provide real-time sensory feedback to operator. */
		}
		
		require videoStreaming {
			doc /* System shall stream video from remote environment to operator. */
		}
	}
	
	requirement <'TR-REQ-002'> latencyRequirement {
		doc /* 
		End-to-end control latency from operator input to robot response 
		shall not exceed 150 milliseconds under nominal conditions.
		*/
		
		attribute maxLatency : DurationValue = 150[SI::ms];
		
		assume constraint nominalCommunication {
			teleroboticSystem.commSystem.roundTripLatency <= maxLatency
		}
	}
	
	requirement <'TR-REQ-003'> reliabilityRequirement {
		doc /* 
		The communication system shall maintain a packet delivery rate 
		of at least 99.5% during operation.
		*/
		
		attribute minDeliveryRate : Real = 0.995;
		
		require constraint reliableTransmission {
			teleroboticSystem.commSystem.packetLossRate <= (1.0 - minDeliveryRate)
		}
	}
	
	requirement <'TR-REQ-004'> safetyRequirement {
		doc /* 
		The system shall detect communication loss and command the robot 
		to enter safe mode within 500 milliseconds.
		*/
		
		attribute maxResponseTime : DurationValue = 500[SI::ms];
		
		require constraint rapidSafetyResponse {
			teleroboticSystem.robot.controller.controlFrequency >= 10[SI::Hz]
		}
	}
	
	requirement <'TR-REQ-005'> manipulationCapability {
		doc /* 
		The robotic manipulator shall provide 6 degrees of freedom with 
		positioning accuracy of +/- 1 millimeter.
		*/
		
		attribute requiredDOF : Integer = 6;
		attribute positionAccuracy : LengthValue = 1[SI::mm];
		
		require constraint dexterousManipulation {
			teleroboticSystem.robot.manipulator.degreesOfFreedom >= requiredDOF and
			teleroboticSystem.robot.manipulator.repeatability <= positionAccuracy
		}
	}
}
