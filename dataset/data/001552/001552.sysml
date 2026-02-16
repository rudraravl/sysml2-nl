package 'Robotic Arm System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def JointAngle :> ISQ::AngleValue;
	
	attribute def TorqueValue :> ISQ::TorqueValue;
	
	attribute def GripForce :> ISQ::ForceValue;
	
	item def TargetPosition {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}
	
	item def JointCommand {
		attribute jointId : Integer;
		attribute targetAngle : JointAngle;
		attribute torque : TorqueValue;
	}
	
	item def GripperCommand {
		attribute gripForce : GripForce;
		attribute isOpen : Boolean;
	}
	
	item def SensorFeedback {
		attribute currentAngle : JointAngle;
		attribute currentTorque : TorqueValue;
		attribute timestamp : ISQ::TimeValue;
	}
	
	port def ControlPort {
		in item positionCommand : TargetPosition;
		out item statusFeedback : SensorFeedback;
	}
	
	port def PowerPort {
		in attribute voltage : ISQ::ElectricPotentialValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def JointControlPort {
		in item command : JointCommand;
		out item feedback : SensorFeedback;
	}
	
	part def Controller {
		port controlInterface : ControlPort;
		port jointPorts : JointControlPort[6];
		
		perform action computeInverseKinematics {
			in targetPos : TargetPosition;
			out jointAngles : JointAngle[6];
		}
		
		perform action generateJointCommands {
			in desiredAngles : JointAngle[6];
			in currentFeedback : SensorFeedback[6];
			out commands : JointCommand[6];
		}
	}
	
	part def Joint {
		attribute jointNumber : Integer;
		attribute currentAngle : JointAngle;
		attribute currentTorque : TorqueValue;
		
		port controlPort : JointControlPort;
		port powerInput : PowerPort;
		
		perform action rotateToAngle {
			in commandedAngle : JointAngle;
			in commandedTorque : TorqueValue;
		}
		
		exhibit state jointBehavior {
			state idle;
			
			accept at idle then moving;
			
			state moving {
				entry action applyTorque;
			}
			
			accept at moving then holding;
			
			state holding;
			
			accept at holding then idle;
		}
	}
	
	part def Gripper {
		attribute isGripping : Boolean;
		attribute currentForce : GripForce;
		
		port powerInput : PowerPort;
		
		perform action grip {
			in force : GripForce;
		}
		
		perform action release;
		
		exhibit state gripperBehavior {
			state open;
			
			accept at open then closing;
			
			state closing;
			
			accept at closing then gripping;
			
			state gripping;
			
			accept at gripping then releasing;
			
			state releasing;
			
			accept at releasing then open;
		}
	}
	
	part def EndEffector {
		part gripper : Gripper;
		attribute position : TargetPosition;
		
		perform action manipulateObject {
			in targetPos : TargetPosition;
			in gripStrength : GripForce;
		}
	}
	
	action def PickAndPlace {
		in pickupLocation : TargetPosition;
		in placeLocation : TargetPosition;
		in objectGripForce : GripForce;
		
		first start;
		then action moveToPickup {
			in target = pickupLocation;
		}
		then action graspObject {
			in force = objectGripForce;
		}
		then action liftObject;
		then action moveToPlace {
			in target = placeLocation;
		}
		then action lowerObject;
		then action releaseObject;
		then done;
	}
	
	part def RoboticArm {
		port controlPort : ControlPort;
		port mainPower : PowerPort;
		
		part controller : Controller {
			port :>> controlInterface connect to controlPort;
		}
		
		part shoulder : Joint {
			:>> jointNumber = 1;
		}
		
		part upperArm : Joint {
			:>> jointNumber = 2;
		}
		
		part elbow : Joint {
			:>> jointNumber = 3;
		}
		
		part forearm : Joint {
			:>> jointNumber = 4;
		}
		
		part wrist : Joint {
			:>> jointNumber = 5;
		}
		
		part wristRotate : Joint {
			:>> jointNumber = 6;
		}
		
		part endEffector : EndEffector;
		
		connect controller.jointPorts[1] to shoulder.controlPort;
		connect controller.jointPorts[2] to upperArm.controlPort;
		connect controller.jointPorts[3] to elbow.controlPort;
		connect controller.jointPorts[4] to forearm.controlPort;
		connect controller.jointPorts[5] to wrist.controlPort;
		connect controller.jointPorts[6] to wristRotate.controlPort;
		
		connect mainPower to shoulder.powerInput;
		connect mainPower to upperArm.powerInput;
		connect mainPower to elbow.powerInput;
		connect mainPower to forearm.powerInput;
		connect mainPower to wrist.powerInput;
		connect mainPower to wristRotate.powerInput;
		connect mainPower to endEffector.gripper.powerInput;
		
		perform action executePickAndPlace : PickAndPlace[*] ordered;
	}
	
	part roboticArmSystem : RoboticArm {
		perform action primaryFunction {
			doc /* 
			 * The robotic arm system's primary function is to precisely position 
			 * and manipulate objects in three-dimensional space through coordinated 
			 * multi-joint movement and controlled gripping. The system receives target 
			 * position commands, computes inverse kinematics to determine required joint 
			 * angles, coordinates the motion of six joints to move the end effector to 
			 * the desired location, and uses a gripper to grasp, transport, and release 
			 * objects with controlled force.
			 */
			
			first start;
			then merge awaitCommand;
			
			action awaitCommand;
			
			then action planMotion : controller.computeInverseKinematics;
			
			then action coordinateJoints {
				action moveShoulder : shoulder.rotateToAngle;
				action moveUpperArm : upperArm.rotateToAngle;
				action moveElbow : elbow.rotateToAngle;
				action moveForearm : forearm.rotateToAngle;
				action moveWrist : wrist.rotateToAngle;
				action rotateWrist : wristRotate.rotateToAngle;
			}
			
			then decide;
				if true then performGrip;
				if false then awaitCommand;
			
			action performGrip : endEffector.gripper.grip;
			then awaitCommand;
		}
	}
	
	requirement def <'REQ-001'> PositioningAccuracy {
		doc /* The robotic arm shall position the end effector within 0.5mm of the commanded target position. */
		
		subject roboticArmSystem;
	}
	
	requirement def <'REQ-002'> PayloadCapacity {
		doc /* The robotic arm shall manipulate objects with mass up to 5 kg. */
		
		subject roboticArmSystem;
	}
	
	requirement def <'REQ-003'> OperationalSafety {
		doc /* The robotic arm shall operate safely by limiting joint torques and monitoring collision conditions. */
		
		subject roboticArmSystem;
	}
	
	requirement <'SYS-001'> roboticArmMission {
		doc /* The robotic arm system shall perform precise pick-and-place operations in industrial automation environments. */
		
		require PositioningAccuracy;
		require PayloadCapacity;
		require OperationalSafety;
	}
}
