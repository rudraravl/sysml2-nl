package 'Articulated Robotic System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package DataTypes {
		enum def RobotType {
			Articulated;
			SCARA;
			Cartesian;
			Delta;
		}
		
		enum def TaskStatus {
			Idle;
			Executing;
			Completed;
			Error;
		}
		
		enum def GripperState {
			Open;
			Closed;
			Gripping;
		}
		
		attribute def Position3D {
			attribute x :> ISQ::length;
			attribute y :> ISQ::length;
			attribute z :> ISQ::length;
		}
		
		attribute def Orientation3D {
			attribute roll :> ISQ::planeAngle;
			attribute pitch :> ISQ::planeAngle;
			attribute yaw :> ISQ::planeAngle;
		}
		
		attribute def Pose {
			attribute position : Position3D;
			attribute orientation : Orientation3D;
		}
		
		item def MotionCommand {
			attribute targetPose : Pose;
			attribute velocity :> ISQ::speed;
		}
		
		item def GripperCommand {
			attribute gripState : GripperState;
			attribute force :> ISQ::force;
		}
		
		item def WorkPiece {
			attribute id : String;
			attribute mass :> ISQ::mass;
			attribute currentPose : Pose;
		}
	}
	
	package PhysicalModel {
		private import DataTypes::*;
		
		port def PowerPort {
			attribute voltage :> ISQ::voltage;
			attribute current :> ISQ::electricCurrent;
		}
		
		port def ControlPort {
			in item motionCommands : MotionCommand[0..*];
			out item poseFeedback : Pose[0..*];
		}
		
		port def GripperControlPort {
			in item gripCommands : GripperCommand[0..*];
			out item gripStates : GripperState[0..*];
		}
		
		port def SensorPort {
			out item sensorData : WorkPiece[0..*];
		}
		
		part def Joint {
			attribute jointAngle :> ISQ::planeAngle;
			attribute maxAngle :> ISQ::planeAngle;
			attribute minAngle :> ISQ::planeAngle;
			attribute angularVelocity :> ISQ::angularVelocity;
			attribute torque :> ISQ::torque;
			
			port power : PowerPort;
		}
		
		part def Link {
			attribute linkLength :> ISQ::length;
			attribute linkMass :> ISQ::mass;
		}
		
		part def EndEffector {
			attribute gripperState : GripperState;
			attribute maxGripForce :> ISQ::force;
			attribute currentForce :> ISQ::force;
			
			port gripControl : GripperControlPort;
		}
		
		part def VisionSensor {
			attribute resolution : Integer;
			attribute frameRate :> ISQ::frequency;
			
			port sensorOutput : SensorPort;
		}
		
		part def ArticulatedRobot {
			attribute robotType : RobotType = RobotType::Articulated;
			attribute positionAccuracy :> ISQ::length;
			attribute maxPayload :> ISQ::mass;
			attribute reachRadius :> ISQ::length;
			attribute currentPose : Pose;
			
			port mainPower : PowerPort;
			port controlInterface : ControlPort;
			
			part baseJoint : Joint {
				attribute :>> maxAngle = 3.14159 [rad];
				attribute :>> minAngle = -3.14159 [rad];
				attribute :>> torque = 100.0 [N*m];
			}
			
			part link1 : Link {
				attribute :>> linkLength = 450.0 [mm];
				attribute :>> linkMass = 6.0 [kg];
			}
			
			part shoulderJoint : Joint {
				attribute :>> maxAngle = 2.61799 [rad];
				attribute :>> minAngle = -2.61799 [rad];
				attribute :>> torque = 80.0 [N*m];
			}
			
			part link2 : Link {
				attribute :>> linkLength = 400.0 [mm];
				attribute :>> linkMass = 5.0 [kg];
			}
			
			part elbowJoint : Joint {
				attribute :>> maxAngle = 2.79253 [rad];
				attribute :>> minAngle = -2.79253 [rad];
				attribute :>> torque = 60.0 [N*m];
			}
			
			part link3 : Link {
				attribute :>> linkLength = 350.0 [mm];
				attribute :>> linkMass = 4.0 [kg];
			}
			
			part wristJoint1 : Joint {
				attribute :>> maxAngle = 3.14159 [rad];
				attribute :>> minAngle = -3.14159 [rad];
				attribute :>> torque = 30.0 [N*m];
			}
			
			part wristJoint2 : Joint {
				attribute :>> maxAngle = 2.0944 [rad];
				attribute :>> minAngle = -2.0944 [rad];
				attribute :>> torque = 20.0 [N*m];
			}
			
			part wristJoint3 : Joint {
				attribute :>> maxAngle = 3.14159 [rad];
				attribute :>> minAngle = -3.14159 [rad];
				attribute :>> torque = 15.0 [N*m];
			}
			
			part gripper : EndEffector {
				attribute :>> maxGripForce = 100.0 [N];
			}
			
			connection connect mainPower to baseJoint.power;
			connection connect mainPower to shoulderJoint.power;
			connection connect mainPower to elbowJoint.power;
			connection connect mainPower to wristJoint1.power;
			connection connect mainPower to wristJoint2.power;
			connection connect mainPower to wristJoint3.power;
		}
		
		part def RobotController {
			port controlOutput : ControlPort;
			port gripperOutput : GripperControlPort;
			port sensorInput : SensorPort;
			port powerInput : PowerPort;
			
			attribute currentStatus : TaskStatus;
		}
		
		part def WorkCell {
			attribute cellId : String;
			
			part workTable {
				attribute tableHeight :> ISQ::length = 850.0 [mm];
				attribute tableArea :> ISQ::area = 2.5 [m^2];
			}
			
			part safetyFence {
				attribute fenceHeight :> ISQ::length = 2100.0 [mm];
			}
		}
		
		connection def PowerConnection {
			end source : PowerPort;
			end target : PowerPort;
		}
		
		connection def ControlConnection {
			end controller : ControlPort;
			end device : ControlPort;
		}
		
		connection def GripperConnection {
			end controller : GripperControlPort;
			end gripper : GripperControlPort;
		}
		
		connection def SensorConnection {
			end sensor : SensorPort;
			end processor : SensorPort;
		}
		
		part def ArticulatedRoboticSystem {
			attribute cycleTime :> ISQ::time;
			
			port systemPower : PowerPort {
				attribute :>> voltage = 230.0 [V];
				attribute :>> current = 15.0 [A];
			}
			
			part robot : ArticulatedRobot {
				attribute :>> positionAccuracy = 0.3 [mm];
				attribute :>> maxPayload = 12.0 [kg];
				attribute :>> reachRadius = 1200.0 [mm];
			}
			
			part controller : RobotController;
			
			part visionSystem : VisionSensor {
				attribute :>> resolution = 1920;
				attribute :>> frameRate = 30.0 [Hz];
			}
			
			part cell : WorkCell {
				attribute :>> cellId = "CELL-ART-001";
			}
			
			connection powerToRobot : PowerConnection 
				connect systemPower to robot.mainPower;
			
			connection powerToController : PowerConnection 
				connect systemPower to controller.powerInput;
			
			connection controlLink : ControlConnection 
				connect controller.controlOutput to robot.controlInterface;
			
			connection gripperLink : GripperConnection 
				connect controller.gripperOutput to robot.gripper.gripControl;
			
			connection sensorLink : SensorConnection 
				connect visionSystem.sensorOutput to controller.sensorInput;
		}
		
		part articulatedSystem : ArticulatedRoboticSystem {
			attribute :>> cycleTime = 28.0 [s];
		}
	}
	
	package LogicalModel {
		private import DataTypes::*;
		
		action def PerformPrimaryTask {
			in workPiece : WorkPiece;
			in pickPose : Pose;
			in placePose : Pose;
			out taskStatus : TaskStatus;
		}
		
		action def MoveToPosition {
			in targetPose : Pose;
			in moveVelocity :> ISQ::speed;
			out currentPose : Pose;
			out success : Boolean;
		}
		
		action def OperateGripper {
			in command : GripperCommand;
			out gripperState : GripperState;
			out success : Boolean;
		}
		
		action def ScanWorkspace {
			out detectedPieces : WorkPiece[0..*];
		}
		
		action def PickAndPlaceSequence {
			in piece : WorkPiece;
			in pickLocation : Pose;
			in placeLocation : Pose;
			out completed : Boolean;
			
			first start;
			then action moveAbovePick : MoveToPosition;
			then action descendToPick : MoveToPosition;
			then action closeGripper : OperateGripper;
			then action liftPiece : MoveToPosition;
			then action moveAbovePlace : MoveToPosition;
			then action descendToPlace : MoveToPosition;
			then action openGripper : OperateGripper;
			then action retractFromPlace : MoveToPosition;
			then assign completed := retractFromPlace.success;
			then done;
		}
		
		part def TaskController {
			perform action primaryTask : PerformPrimaryTask;
		}
		
		part def MotionPlanner {
			perform action planMotion : MoveToPosition;
		}
		
		part def GripperController {
			perform action controlGripper : OperateGripper;
		}
		
		part taskController : TaskController {
			perform action executeTask : PerformPrimaryTask;
		}
	}
	
	package RequirementsModel {
		private import DataTypes::*;
		private import PhysicalModel::*;
		
		requirement primaryTaskRequirement {
			doc /* The robotic system shall perform its primary task using an articulated robot. */
			subject system : ArticulatedRoboticSystem;
			require constraint {
				system.robot.robotType == RobotType::Articulated
			}
		}
		
		requirement positionAccuracyRequirement {
			doc /* The articulated robot shall achieve positioning accuracy within 0.5mm. */
			subject robot : ArticulatedRobot;
			require constraint {
				robot.positionAccuracy <= 0.5 [mm]
			}
		}
		
		requirement payloadCapacityRequirement {
			doc /* The articulated robot shall handle payloads up to 10kg. */
			subject robot : ArticulatedRobot;
			require constraint {
				robot.maxPayload >= 10.0 [kg]
			}
		}
		
		requirement cycleTimeRequirement {
			doc /* The system shall complete a pick-and-place cycle within 30 seconds. */
			subject system : ArticulatedRoboticSystem;
			require constraint {
				system.cycleTime <= 30.0 [s]
			}
		}
	}
	
	package BehaviorModel {
		private import DataTypes::*;
		
		state def RobotOperationStates {
			entry; then idle;
			
			state idle;
			accept StartTask;
			then executing;
			
			state executing;
			accept TaskComplete;
			then completed;
			accept TaskFailed;
			then error;
			
			state completed;
			accept Reset;
			then idle;
			
			state error;
			accept Reset;
			then idle;
		}
	}
	
	allocation def LogicalToPhysical {
		end logical : LogicalModel::TaskController;
		end physical : PhysicalModel::ArticulatedRoboticSystem;
	}
	
	allocation systemAllocation : LogicalToPhysical 
		allocate logical ::> LogicalModel::taskController 
		to physical ::> PhysicalModel::articulatedSystem {
		allocate taskController.executeTask to articulatedSystem.controller.currentStatus;
	}
	
	satisfy RequirementsModel::primaryTaskRequirement by PhysicalModel::articulatedSystem;
	satisfy RequirementsModel::positionAccuracyRequirement by PhysicalModel::articulatedSystem.robot;
	satisfy RequirementsModel::payloadCapacityRequirement by PhysicalModel::articulatedSystem.robot;
	satisfy RequirementsModel::cycleTimeRequirement by PhysicalModel::articulatedSystem;
}
