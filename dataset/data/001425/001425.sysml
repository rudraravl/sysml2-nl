package 'FANUC Industrial Robot System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Position3D {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	attribute def Orientation3D {
		attribute roll : Real;
		attribute pitch : Real;
		attribute yaw : Real;
	}
	
	attribute def RobotPose {
		attribute position : Position3D;
		attribute orientation : Orientation3D;
	}
	
	enum def GripperStateKind {
		open;
		closed;
		gripping;
	}
	
	enum def RobotOperationMode {
		idle;
		manual;
		automatic;
		error;
	}
	
	item def Workpiece {
		attribute partID : String;
		attribute mass : MassValue;
		attribute dimensions : LengthValue[3];
	}
	
	item def MotionCommand {
		attribute targetPose : RobotPose;
		attribute speed : SpeedValue;
		attribute acceleration : AccelerationValue;
	}
	
	item def GripCommand {
		attribute targetState : GripperStateKind;
		attribute force : ForceValue;
	}
	
	part def RobotController {
		attribute operationMode : RobotOperationMode;
		attribute currentProgram : String;
		
		port commandPort;
		port feedbackPort;
		port safetyPort;
		port visionPort;
	}
	
	part def ServoMotor {
		attribute maxTorque : TorqueValue;
		attribute maxSpeed : AngularVelocityValue;
		
		in attribute commandTorque : TorqueValue;
		out attribute actualPosition : Real;
		out attribute actualVelocity : AngularVelocityValue;
		
		port powerPort;
		port encoderPort;
	}
	
	part def RobotJoint {
		attribute jointID : Integer;
		attribute minAngle : Real;
		attribute maxAngle : Real;
		attribute currentAngle : Real;
		
		part motor : ServoMotor;
		
		port controlPort;
	}
	
	part def RobotArm {
		attribute reach : LengthValue;
		attribute payloadCapacity : MassValue;
		
		part joint1 : RobotJoint { attribute :>> jointID = 1; }
		part joint2 : RobotJoint { attribute :>> jointID = 2; }
		part joint3 : RobotJoint { attribute :>> jointID = 3; }
		part joint4 : RobotJoint { attribute :>> jointID = 4; }
		part joint5 : RobotJoint { attribute :>> jointID = 5; }
		part joint6 : RobotJoint { attribute :>> jointID = 6; }
		
		port flangePort;
	}
	
	part def Gripper {
		attribute maxGripForce : ForceValue;
		attribute maxOpening : LengthValue;
		attribute currentState : GripperStateKind;
		
		port mountPort;
		port controlPort;
		port workpiecePort;
	}
	
	part def VisionSensor {
		attribute resolution : Integer[2];
		attribute frameRate : FrequencyValue;
		
		out attribute detectedParts : Workpiece[*];
		
		port cameraPort;
		port dataPort;
	}
	
	part def SafetyController {
		attribute emergencyStopActive : Boolean;
		attribute lightCurtainActive : Boolean;
		
		port sensorInputPort;
		port emergencyOutputPort;
	}
	
	part def Conveyor {
		attribute beltSpeed : SpeedValue;
		attribute beltLength : LengthValue;
		
		port motorPort;
		port workpieceOutputPort;
	}
	
	part def WorkStation {
		attribute stationID : String;
		
		port workpieceInputPort;
	}
	
	action def InitializeSystem {
		out systemReady : Boolean;
	}
	
	action def CalibrateRobot {
		in homePose : RobotPose;
		out calibrationComplete : Boolean;
	}
	
	action def DetectWorkpiece {
		out detectedPart : Workpiece;
		out partPose : RobotPose;
	}
	
	action def PlanMotion {
		in startPose : RobotPose;
		in targetPose : RobotPose;
		in obstacles : Position3D[*];
		out trajectory : RobotPose[*] ordered;
	}
	
	action def ExecuteMotion {
		in trajectory : RobotPose[*] ordered;
		in speed : SpeedValue;
		out motionComplete : Boolean;
	}
	
	action def GraspPart {
		in gripForce : ForceValue;
		out graspSuccessful : Boolean;
	}
	
	action def ReleasePart {
		out releaseSuccessful : Boolean;
	}
	
	action def PickAndPlaceOperation {
		in pickPose : RobotPose;
		in placePose : RobotPose;
		in workpiece : Workpiece;
		in gripForce : ForceValue;
		out operationComplete : Boolean;
		
		first start;
		then action approachPick : ExecuteMotion {
			in trajectory = (pickPose);
			in speed = 0.5[m/s];
			out motionComplete;
		}
		then action grasp : GraspPart {
			in gripForce = gripForce;
			out graspSuccessful;
		}
		then decide;
			if grasp.graspSuccessful then moveToPlace;
			if not grasp.graspSuccessful then retryGrasp;
		action moveToPlace : ExecuteMotion {
			in trajectory = (placePose);
			in speed = 0.4[m/s];
			out motionComplete;
		}
		then action release : ReleasePart {
			out releaseSuccessful;
		}
		then assign operationComplete := true;
		then done;
		action retryGrasp : GraspPart {
			in gripForce = gripForce;
			out graspSuccessful;
		}
		then moveToPlace;
	}
	
	action def AutomatedProductionCycle {
		in cycleCount : Integer;
		in pickLocation : RobotPose;
		in placeLocation : RobotPose;
		in gripForce : ForceValue;
		out completedCycles : Integer := 0;
		
		first start;
		then action init : InitializeSystem {
			out systemReady;
		}
		then action calibrate : CalibrateRobot {
			in homePose = RobotPose {
				position = Position3D { x = 0.0[m]; y = 0.0[m]; z = 0.5[m]; }
				orientation = Orientation3D { roll = 0.0; pitch = 0.0; yaw = 0.0; }
			}
			out calibrationComplete;
		}
		then merge continueProduction;
		then action processWorkpieces;
		for i in 1..cycleCount {
			perform action detect : DetectWorkpiece {
				out detectedPart;
				out partPose;
			}
			then perform action pickPlace : PickAndPlaceOperation {
				in pickPose = detect.partPose;
				in placePose = placeLocation;
				in workpiece = detect.detectedPart;
				in gripForce = gripForce;
				out operationComplete;
			}
			then decide;
				if pickPlace.operationComplete then incrementCounter;
			action incrementCounter {
				then assign completedCycles := completedCycles + 1;
			}
			then continueProduction;
		}
		then done;
	}
	
	part def FANUCRobotCell {
		doc /*
			FANUC-based robotic workcell for automated material handling and assembly.
			The system's primary function is to autonomously perform high-precision 
			pick-and-place operations in manufacturing environments. It integrates a 
			six-axis articulated robot arm with servo-driven joints, an adaptive gripper 
			for part manipulation, vision-guided workpiece detection, and comprehensive 
			safety systems. The robot controller coordinates all subsystems to execute 
			programmed motion sequences, performing real-time trajectory planning and 
			inverse kinematics calculations to achieve precise end-effector positioning 
			while maintaining safe operation through continuous monitoring of workspace 
			boundaries and emergency stop capabilities.
		*/
		
		part controller : RobotController {
			attribute :>> operationMode = RobotOperationMode::automatic;
		}
		
		part arm : RobotArm {
			attribute :>> reach = 1.8[m];
			attribute :>> payloadCapacity = 25.0[kg];
		}
		
		part gripper : Gripper {
			attribute :>> maxGripForce = 200.0[N];
			attribute :>> maxOpening = 0.15[m];
		}
		
		part vision : VisionSensor {
			attribute :>> resolution = (1920, 1080);
			attribute :>> frameRate = 30.0[Hz];
		}
		
		part safety : SafetyController;
		
		part inputConveyor : Conveyor {
			attribute :>> beltSpeed = 0.2[m/s];
			attribute :>> beltLength = 2.0[m];
		}
		
		part outputStation : WorkStation {
			attribute :>> stationID = "Assembly_Station_01";
		}
		
		connect arm.flangePort to gripper.mountPort;
		connect controller.commandPort to arm.joint1.controlPort;
		connect controller.commandPort to arm.joint2.controlPort;
		connect controller.commandPort to arm.joint3.controlPort;
		connect controller.commandPort to arm.joint4.controlPort;
		connect controller.commandPort to arm.joint5.controlPort;
		connect controller.commandPort to arm.joint6.controlPort;
		connect controller.commandPort to gripper.controlPort;
		connect vision.dataPort to controller.visionPort;
		connect safety.emergencyOutputPort to controller.safetyPort;
		connect inputConveyor.workpieceOutputPort to gripper.workpiecePort;
		connect gripper.workpiecePort to outputStation.workpieceInputPort;
		
		perform action productionCycle[*] ordered references runProduction;
	}
	
	action runProduction : AutomatedProductionCycle {
		in cycleCount : Integer;
		in pickLocation : RobotPose;
		in placeLocation : RobotPose;
		in gripForce : ForceValue;
		out completedCycles : Integer;
	}
	
	part fanucCell : FANUCRobotCell;
	
	requirement def PrimaryFunctionRequirement {
		doc /*
			The FANUC robotic system shall autonomously perform pick-and-place operations
			to transfer workpieces from the input conveyor to the designated assembly station
			with high precision and repeatability.
		*/
	}
	
	requirement def PositioningAccuracyRequirement {
		doc /*
			The robot shall achieve positioning repeatability of ±0.05 mm at the end effector
			under rated payload conditions.
		*/
		
		require constraint {
			doc /* Repeatability tolerance: ±0.05 mm */
		}
	}
	
	requirement def PayloadRequirement {
		doc /*
			The robot shall handle workpieces with mass up to 25 kg at full reach
			without degradation of positioning accuracy.
		*/
		
		require constraint {
			fanucCell.arm.payloadCapacity >= 25.0[kg]
		}
	}
	
	requirement def CycleTimeRequirement {
		doc /*
			The system shall complete a standard pick-and-place cycle in less than
			4 seconds from part detection to part release.
		*/
		
		require constraint {
			doc /* Maximum cycle time: 4 seconds */
		}
	}
	
	requirement def SafetyRequirement {
		doc /*
			The system shall comply with ISO 10218-1 and ISO 10218-2 safety standards
			for industrial robots, including emergency stop response time less than 150 ms.
		*/
		
		require constraint {
			doc /* Emergency stop response: < 150 ms */
		}
	}
	
	requirement systemRequirements {
		subject robotCell : FANUCRobotCell;
		
		require primaryFunction : PrimaryFunctionRequirement;
		require positioningAccuracy : PositioningAccuracyRequirement;
		require payload : PayloadRequirement;
		require cycleTime : CycleTimeRequirement;
		require safety : SafetyRequirement;
	}
}
