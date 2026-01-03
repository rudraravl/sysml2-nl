package 'Barrett Technology WAM System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def JointAngle {
        attribute value : Real;
        attribute unit : AngleUnit;
    }
    
    attribute def JointTorque {
        attribute value : Real;
        attribute unit : TorqueUnit;
    }
    
    attribute def JointVelocity {
        attribute value : Real;
        attribute unit : AngularVelocityUnit;
    }
    
    attribute def GripperForce {
        attribute value : Real;
        attribute unit : ForceUnit;
    }
    
    attribute def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def Orientation3D {
        attribute roll : JointAngle;
        attribute pitch : JointAngle;
        attribute yaw : JointAngle;
    }
    
    attribute def Pose {
        attribute position : Position3D;
        attribute orientation : Orientation3D;
    }
    
    attribute def TrajectoryPoint {
        attribute pointPose : Pose;
        attribute timestamp : TimeValue;
    }
    
    attribute def MotionCommand;
    attribute def GraspCommand;
    attribute def ReleaseCommand;
    attribute def EmergencyStop;
    
    port def ControlPort {
        in motionCmd : MotionCommand;
        in graspCmd : GraspCommand;
        in releaseCmd : ReleaseCommand;
        out currentPose : Pose;
        out jointStates : JointAngle[7];
    }
    
    port def PowerPort {
        in powerSupply : PowerValue;
        out powerDraw : PowerValue;
    }
    
    port def SensorPort {
        out torqueFeedback : JointTorque[7];
        out positionFeedback : JointAngle[7];
        out gripperForceFeedback : GripperForce;
    }
    
    part def WAM_Arm {
        attribute dof : Integer = 7;
        attribute maxReach : LengthValue;
        attribute maxPayload : MassValue;
        
        port controlInterface : ControlPort;
        port powerInterface : PowerPort;
        port sensorInterface : SensorPort;
        
        part shoulder : JointAssembly {
            attribute jointIndex : Integer = 1;
        }
        part upperArm : JointAssembly {
            attribute jointIndex : Integer = 2;
        }
        part elbow : JointAssembly {
            attribute jointIndex : Integer = 3;
        }
        part forearmRoll : JointAssembly {
            attribute jointIndex : Integer = 4;
        }
        part wristPitch : JointAssembly {
            attribute jointIndex : Integer = 5;
        }
        part wristYaw : JointAssembly {
            attribute jointIndex : Integer = 6;
        }
        part wristRoll : JointAssembly {
            attribute jointIndex : Integer = 7;
        }
        
        part motorController : MotorController[7];
        part torqueSensor : TorqueSensor[7];
        part encoderSystem : PositionEncoder[7];
        
        connect shoulder.output to upperArm.input;
        connect upperArm.output to elbow.input;
        connect elbow.output to forearmRoll.input;
        connect forearmRoll.output to wristPitch.input;
        connect wristPitch.output to wristYaw.input;
        connect wristYaw.output to wristRoll.input;
    }
    
    part def JointAssembly {
        attribute jointIndex : Integer;
        attribute currentAngle : JointAngle;
        attribute currentTorque : JointTorque;
        attribute currentVelocity : JointVelocity;
        
        port input;
        port output;
        
        part motor : BrushlessMotor;
        part gearbox : CableDriveTransmission;
        part brake : ElectromagneticBrake;
    }
    
    part def BrushlessMotor {
        attribute ratedTorque : JointTorque;
        attribute ratedSpeed : JointVelocity;
    }
    
    part def CableDriveTransmission {
        attribute gearRatio : Real;
        attribute efficiency : Real;
    }
    
    part def ElectromagneticBrake {
        attribute holdingTorque : JointTorque;
    }
    
    part def MotorController {
        attribute controlMode : ControlMode;
    }
    
    enum def ControlMode {
        positionControl;
        velocityControl;
        torqueControl;
        impedanceControl;
    }
    
    part def TorqueSensor {
        attribute sensitivity : Real;
        attribute range : JointTorque;
    }
    
    part def PositionEncoder {
        attribute resolution : Integer;
        attribute accuracy : JointAngle;
    }
    
    part def BarrettHand {
        attribute fingerCount : Integer = 3;
        attribute maxGraspForce : GripperForce;
        
        port mechanicalInterface;
        port controlInterface;
        
        part finger1 : RoboticFinger;
        part finger2 : RoboticFinger;
        part finger3 : RoboticFinger;
        part palm : Palm;
        part spreadMechanism : SpreadMechanism;
    }
    
    part def RoboticFinger {
        attribute fingerLength : LengthValue;
        
        part proximalLink : FingerLink;
        part distalLink : FingerLink;
        part tendonDrive : TendonActuator;
        part tactileSensor : TactileSensor;
    }
    
    part def FingerLink {
        attribute linkLength : LengthValue;
        attribute linkMass : MassValue;
    }
    
    part def TendonActuator {
        attribute maxForce : ForceValue;
    }
    
    part def TactileSensor {
        attribute sensorCount : Integer;
    }
    
    part def Palm {
        attribute mountingInterface : MountingInterface;
    }
    
    part def MountingInterface;
    
    part def SpreadMechanism {
        attribute spreadAngle : JointAngle;
    }
    
    part def SafetyController {
        attribute emergencyStopActive : Boolean;
        attribute collisionDetected : Boolean;
        attribute torqueLimitExceeded : Boolean;
    }
    
    part def TrajectoryPlanner {
        in targetPose : Pose;
        in currentPose : Pose;
        out trajectory : TrajectoryPoint[*];
    }
    
    part def InverseKinematics {
        in desiredPose : Pose;
        out jointAngles : JointAngle[7];
    }
    
    part def ForwardKinematics {
        in jointAngles : JointAngle[7];
        out endEffectorPose : Pose;
    }
    
    action def ComputeInverseKinematics {
        in targetPose : Pose;
        in currentJointAngles : JointAngle[7];
        out commandedJointAngles : JointAngle[7];
    }
    
    action def ExecuteTrajectory {
        in trajectory : TrajectoryPoint[*];
        in currentPose : Pose;
        out finalPose : Pose;
        
        private attribute position := currentPose;
        
        for waypoint in trajectory {
            perform action moveToWaypoint : ComputeInverseKinematics {
                in targetPose = waypoint.pointPose;
                in currentJointAngles;
                out commandedJointAngles;
            }
            then assign position := waypoint.pointPose;
        }
        then assign finalPose := position;
    }
    
    action def PerformGrasp {
        in graspForce : GripperForce;
        out graspSuccess : Boolean;
    }
    
    action def MonitorSafety {
        in jointTorques : JointTorque[7];
        in velocities : JointVelocity[7];
        out safetyStatus : Boolean;
        out emergencyStopRequired : Boolean;
    }
    
    action def ManipulateObject {
        in objectPose : Pose;
        in targetPose : Pose;
        in graspForce : GripperForce;
        out manipulationSuccess : Boolean;
        
        first start;
        then action planApproach : ComputeInverseKinematics {
            in targetPose = objectPose;
            out commandedJointAngles;
        }
        then action moveToObject : ExecuteTrajectory {
            in currentPose = objectPose;
            out finalPose;
        }
        then action graspObject : PerformGrasp {
            in graspForce = graspForce;
            out graspSuccess;
        }
        then decide;
            if graspObject.graspSuccess then moveWithObject;
            if not graspObject.graspSuccess then failManipulation;
        action moveWithObject : ExecuteTrajectory {
            in currentPose = targetPose;
            out finalPose;
        }
        then action releaseObject : PerformGrasp {
            in graspForce;
            out graspSuccess;
        }
        then assign manipulationSuccess := true;
        then done;
        action failManipulation {
            then assign manipulationSuccess := false;
            then done;
        }
    }
    
    part def BarrettRoboticSystem {
        doc /*
            Primary Function: Perform precise manipulation and grasping of objects in
            collaborative environments through compliant, backdrivable actuation and
            intelligent multi-fingered grasping with real-time force feedback.
        */
        
        part wam : WAM_Arm;
        part hand : BarrettHand;
        part safetySystem : SafetyController;
        part motionPlanner : TrajectoryPlanner;
        part kinematics : InverseKinematics;
        part forwardKin : ForwardKinematics;
    }
    
    part barrettSystem : BarrettRoboticSystem {
        doc /*
            Barrett Technology robotic manipulator system integrating a 7-DOF WAM arm
            with a multi-fingered BarrettHand end effector for precise manipulation tasks.
        */
        
        :>> wam {
            :>> maxReach = 1.0 [m];
            :>> maxPayload = 3.0 [kg];
        }
        
        :>> hand {
            :>> maxGraspForce = GripperForce { value = 50.0; unit = N; };
        }
        
        connect wam.wristRoll.output to hand.mechanicalInterface;
        
        perform action manipulateObjects : ManipulateObject[*] {
            in objectPose;
            in targetPose;
            in graspForce;
            out manipulationSuccess;
        }
        
        state operationalStates {
            entry; then idle;
            
            state idle;
            
            transition idle_to_moving
                first idle
                accept motionCmd : MotionCommand
                then moving;
            
            state moving {
                entry action executeMotion : ExecuteTrajectory;
                do action monitorMotion : MonitorSafety {
                    in jointTorques = wam.sensorInterface.torqueFeedback;
                    out safetyStatus;
                    out emergencyStopRequired;
                }
            }
            
            transition moving_to_grasping
                first moving
                accept graspCmd : GraspCommand
                then grasping;
            
            state grasping {
                entry action performCloseGripper : PerformGrasp;
            }
            
            transition grasping_to_holding
                first grasping
                if performCloseGripper.graspSuccess
                then holding;
            
            state holding;
            
            transition holding_to_releasing
                first holding
                accept releaseCmd : ReleaseCommand
                then releasing;
            
            state releasing {
                entry action openGripper : PerformGrasp;
            }
            
            transition releasing_to_idle
                first releasing
                then idle;
            
            transition any_to_emergency
                first idle
                accept emergencyStop : EmergencyStop
                then emergencyStop;
            
            transition moving_to_emergency
                first moving
                accept emergencyStop : EmergencyStop
                then emergencyStop;
            
            state emergencyStop {
                entry action activateBrakes;
            }
        }
    }
    
    requirement <'BR-001'> systemPerformanceRequirement {
        doc /*
            The Barrett robotic system shall perform object manipulation tasks with
            position accuracy better than 1mm and force control resolution better than 0.1N.
        */
        
        subject system : BarrettRoboticSystem;
        
        require constraint positionAccuracy {
            system.wam.maxReach >= 1.0 [m]
        }
        
        require constraint forceResolution {
            system.hand.maxGraspForce.value >= 50.0
        }
    }
    
    requirement <'BR-002'> safetyRequirement {
        doc /*
            The system shall detect collisions and excessive torques and activate
            emergency stop to ensure human safety in collaborative environments.
        */
        
        subject system : BarrettRoboticSystem;
        
        require constraint collisionDetection {
            system.safetySystem.emergencyStopActive or 
            not system.safetySystem.collisionDetected
        }
    }
    
    requirement <'BR-003'> manipulationCapability {
        doc /*
            The system shall successfully grasp and manipulate objects ranging
            from 10g to 3kg with adaptive finger compliance.
        */
        
        subject system : BarrettRoboticSystem;
        
        assume constraint payloadRange {
            system.wam.maxPayload == 3.0 [kg]
        }
        
        require constraint fingerAdaptation {
            system.hand.fingerCount == 3
        }
    }
}
