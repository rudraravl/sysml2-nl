package 'Rainbow Robotics Collaborative Robot System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def JointAngle :> AngleValue;
    
    attribute def JointTorque :> TorqueValue;
    
    attribute def GripperForce :> ForceValue;
    
    attribute def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    attribute def Orientation3D {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }
    
    attribute def Pose {
        attribute position : Position3D;
        attribute orientation : Orientation3D;
    }
    
    attribute def MotionCommand;
    attribute def GripperCommand;
    attribute def SafetyStatus;
    attribute def SensorData;
    
    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    port def ControlPort {
        in attribute command : MotionCommand;
        out attribute feedback : SensorData;
    }
    
    port def JointControlPort {
        in attribute targetAngle : JointAngle;
        in attribute targetTorque : JointTorque;
        out attribute actualAngle : JointAngle;
        out attribute actualTorque : JointTorque;
    }
    
    port def EndEffectorPort {
        in attribute targetPose : Pose;
        in attribute gripperCmd : GripperCommand;
        out attribute actualPose : Pose;
        out attribute gripperForce : GripperForce;
    }
    
    part def ControllerModule {
        port controlInterface : ControlPort;
        port powerInput : PowerPort;
        
        attribute processingFrequency : FrequencyValue;
        attribute memoryCapacity : Real;
    }
    
    part def JointActuator {
        port jointControl : JointControlPort;
        port powerInput : PowerPort;
        
        attribute maxTorque : JointTorque;
        attribute maxSpeed : AngularVelocityValue;
        attribute gearRatio : Real;
    }
    
    part def ArmLink {
        attribute linkLength : LengthValue;
        attribute linkMass : MassValue;
    }
    
    part def Gripper {
        port effectorControl : EndEffectorPort;
        port powerInput : PowerPort;
        
        attribute maxGripForce : GripperForce;
        attribute gripperStroke : LengthValue;
    }
    
    part def VisionSensor {
        out attribute imageData : SensorData;
        port powerInput : PowerPort;
        
        attribute resolution : Real;
        attribute frameRate : FrequencyValue;
    }
    
    part def ForceTorqueSensor {
        out attribute measuredForce : ForceValue;
        out attribute measuredTorque : TorqueValue;
        port powerInput : PowerPort;
        
        attribute sensitivity : Real;
    }
    
    action def InitializeSystem {
        in powerOn : Boolean;
        out systemReady : Boolean;
    }
    
    action def CalibrateJoints {
        in jointCount : Integer;
        out calibrationComplete : Boolean;
    }
    
    action def ComputeInverseKinematics {
        in targetPose : Pose;
        out jointAngles : JointAngle[6];
    }
    
    action def ExecuteTrajectory {
        in waypoints : Pose[*];
        in velocity : SpeedValue;
        out trajectoryComplete : Boolean;
    }
    
    action def PerformGrasp {
        in targetForce : GripperForce;
        in objectDetected : Boolean;
        out graspSuccess : Boolean;
    }
    
    action def MonitorCollision {
        in currentForces : ForceValue[*];
        in threshold : ForceValue;
        out collisionDetected : Boolean;
    }
    
    state def RobotOperationalStates {
        entry; then idle;
        
        state idle {
            entry action init : InitializeSystem;
        }
        
        transition idle_to_calibrating
            first idle
            accept calibrationRequest : MotionCommand
            then calibrating;
        
        state calibrating {
            entry action calibAction : CalibrateJoints;
        }
        
        transition calibrating_to_ready
            first calibrating
            if calibAction.calibrationComplete
            then ready;
        
        state ready;
        
        transition ready_to_executing
            first ready
            accept motionRequest : MotionCommand
            then executing;
        
        state executing {
            entry action executeAction : ExecuteTrajectory;
            do action safetyMonitor : MonitorCollision;
        }
        
        transition executing_to_grasping
            first executing
            if executeAction.trajectoryComplete
            then grasping;
        
        transition executing_to_emergency
            first executing
            if safetyMonitor.collisionDetected
            then emergency;
        
        state grasping {
            entry action graspAction : PerformGrasp;
        }
        
        transition grasping_to_ready
            first grasping
            if graspAction.graspSuccess
            then ready;
        
        state emergency {
            entry action emergencyStop;
        }
        
        transition emergency_to_idle
            first emergency
            accept resetCommand : MotionCommand
            then idle;
    }
    
    part def RainbowCollaborativeRobot {
        attribute robotModel : String;
        attribute numberOfJoints : Integer = 6;
        attribute maxPayload : MassValue;
        attribute maxReach : LengthValue;
        
        port mainControl : ControlPort;
        port mainPower : PowerPort;
        
        part controller : ControllerModule {
            port redefines controlInterface;
            port redefines powerInput;
        }
        
        part joint1 : JointActuator {
            port redefines powerInput;
        }
        
        part joint2 : JointActuator {
            port redefines powerInput;
        }
        
        part joint3 : JointActuator {
            port redefines powerInput;
        }
        
        part joint4 : JointActuator {
            port redefines powerInput;
        }
        
        part joint5 : JointActuator {
            port redefines powerInput;
        }
        
        part joint6 : JointActuator {
            port redefines powerInput;
        }
        
        part link1 : ArmLink;
        part link2 : ArmLink;
        part link3 : ArmLink;
        part link4 : ArmLink;
        part link5 : ArmLink;
        part link6 : ArmLink;
        
        part endEffector : Gripper {
            port redefines powerInput;
        }
        
        part visionSystem : VisionSensor {
            port redefines powerInput;
        }
        
        part forceSensor : ForceTorqueSensor {
            port redefines powerInput;
        }
        
        binding controllerToMain of controller.controlInterface = mainControl;
        binding controllerPower of controller.powerInput = mainPower;
        
        perform action operateRobot {
            first start;
            then merge monitorLoop;
            
            action monitorLoop : MonitorCollision {
                in currentForces;
                in threshold = 150[N];
                out collisionDetected;
            }
            
            then decide;
                if monitorLoop.collisionDetected then emergencyStop;
                if not monitorLoop.collisionDetected then planPath;
            
            action planPath : ComputeInverseKinematics {
                in targetPose;
                out jointAngles;
            }
            
            then action executeMove : ExecuteTrajectory {
                in waypoints;
                in velocity = 0.5[m/s];
                out trajectoryComplete;
            }
            
            then decide;
                if executeMove.trajectoryComplete then performGrip;
                else monitorLoop;
            
            action performGrip : PerformGrasp {
                in targetForce = 80[N];
                in objectDetected = true;
                out graspSuccess;
            }
            
            then monitorLoop;
            
            action emergencyStop;
            then done;
        }
        
        exhibit state robotBehavior : RobotOperationalStates;
    }
    
    requirement def SafetyRequirement {
        doc /* The collaborative robot shall detect and respond to collisions to ensure human safety. */
        
        subject robot : RainbowCollaborativeRobot;
        
        require constraint {
            doc /* Collision detection response time shall be less than 50 milliseconds. */
        }
        
        require constraint {
            doc /* Maximum contact force shall not exceed 150 Newtons during collision. */
        }
    }
    
    requirement def PositioningRequirement {
        doc /* The robot shall achieve specified positioning accuracy and repeatability. */
        
        subject robot : RainbowCollaborativeRobot;
        
        require constraint {
            doc /* Positioning accuracy shall be within ±0.05 mm. */
        }
        
        require constraint {
            doc /* Repeatability shall be within ±0.03 mm. */
        }
    }
    
    requirement def PayloadRequirement {
        doc /* The robot shall handle specified payload within its workspace. */
        
        subject robot : RainbowCollaborativeRobot;
        
        assume constraint {
            doc /* Payload mass is within rated capacity. */
            robot.maxPayload <= 10[kg]
        }
        
        require constraint {
            doc /* Robot shall maintain positioning accuracy under full payload. */
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for Rainbow collaborative robot system. */
        
        require safetyRequirement : SafetyRequirement;
        require positioningRequirement : PositioningRequirement;
        require payloadRequirement : PayloadRequirement;
    }
    
    part rainbowRB5 : RainbowCollaborativeRobot {
        attribute redefines robotModel = "RB-5";
        attribute redefines numberOfJoints = 6;
        attribute redefines maxPayload = 5[kg];
        attribute redefines maxReach = 700[mm];
        
        satisfy systemRequirements;
        
        part redefines controller {
            attribute redefines processingFrequency = 1000[Hz];
            attribute redefines memoryCapacity = 4.0;
        }
        
        part redefines joint1 {
            attribute redefines maxTorque = 20[N*m];
            attribute redefines maxSpeed = 180[deg/s];
            attribute redefines gearRatio = 100.0;
        }
        
        part redefines joint2 {
            attribute redefines maxTorque = 20[N*m];
            attribute redefines maxSpeed = 180[deg/s];
            attribute redefines gearRatio = 100.0;
        }
        
        part redefines joint3 {
            attribute redefines maxTorque = 15[N*m];
            attribute redefines maxSpeed = 180[deg/s];
            attribute redefines gearRatio = 100.0;
        }
        
        part redefines joint4 {
            attribute redefines maxTorque = 10[N*m];
            attribute redefines maxSpeed = 225[deg/s];
            attribute redefines gearRatio = 80.0;
        }
        
        part redefines joint5 {
            attribute redefines maxTorque = 10[N*m];
            attribute redefines maxSpeed = 225[deg/s];
            attribute redefines gearRatio = 80.0;
        }
        
        part redefines joint6 {
            attribute redefines maxTorque = 5[N*m];
            attribute redefines maxSpeed = 225[deg/s];
            attribute redefines gearRatio = 60.0;
        }
        
        part redefines link1 {
            attribute redefines linkLength = 150[mm];
            attribute redefines linkMass = 2.5[kg];
        }
        
        part redefines link2 {
            attribute redefines linkLength = 243[mm];
            attribute redefines linkMass = 3.0[kg];
        }
        
        part redefines link3 {
            attribute redefines linkLength = 213[mm];
            attribute redefines linkMass = 2.0[kg];
        }
        
        part redefines link4 {
            attribute redefines linkLength = 83[mm];
            attribute redefines linkMass = 1.0[kg];
        }
        
        part redefines link5 {
            attribute redefines linkLength = 83[mm];
            attribute redefines linkMass = 1.0[kg];
        }
        
        part redefines link6 {
            attribute redefines linkLength = 74[mm];
            attribute redefines linkMass = 0.5[kg];
        }
        
        part redefines endEffector {
            attribute redefines maxGripForce = 100[N];
            attribute redefines gripperStroke = 85[mm];
        }
        
        part redefines visionSystem {
            attribute redefines resolution = 1920.0 * 1080.0;
            attribute redefines frameRate = 30[Hz];
        }
        
        part redefines forceSensor {
            attribute redefines sensitivity = 0.1;
        }
    }
    
    action def PerformPickAndPlace {
        doc /* High-level pick-and-place task using Rainbow collaborative robot. */
        
        in pickupLocation : Pose;
        in placeLocation : Pose;
        in gripForce : GripperForce;
        out taskComplete : Boolean;
        
        first start;
        
        then action moveToPickup : ExecuteTrajectory {
            in waypoints = (pickupLocation,);
            in velocity = 0.5[m/s];
            out trajectoryComplete;
        }
        
        then action graspObject : PerformGrasp {
            in targetForce = gripForce;
            in objectDetected = true;
            out graspSuccess;
        }
        
        then decide;
            if graspObject.graspSuccess then moveToPlace;
            else start;
        
        action moveToPlace : ExecuteTrajectory {
            in waypoints = (placeLocation,);
            in velocity = 0.3[m/s];
            out trajectoryComplete;
        }
        
        then action releaseObject : PerformGrasp {
            in targetForce = 0[N];
            in objectDetected = false;
            out graspSuccess;
        }
        
        then assign taskComplete := true;
        then done;
    }
    
    part assemblyWorkstation {
        doc /* Complete workstation integrating Rainbow robot for automated assembly operations. */
        
        part robot : RainbowCollaborativeRobot = rainbowRB5;
        
        part workTable {
            attribute tableHeight : LengthValue = 750[mm];
            attribute tableWidth : LengthValue = 1200[mm];
            attribute tableDepth : LengthValue = 800[mm];
        }
        
        part partFeeder {
            out attribute partAvailable : Boolean;
            out attribute partPose : Pose;
        }
        
        part qualityInspection {
            in attribute inspectionImage : SensorData;
            out attribute partQuality : Boolean;
        }
        
        perform action automatedAssembly {
            first start;
            then merge waitForPart;
            
            action waitForPart {
                accept partReady : Boolean;
            }
            
            then action pickAndPlace : PerformPickAndPlace {
                in pickupLocation = partFeeder.partPose;
                in placeLocation;
                in gripForce = 50[N];
                out taskComplete;
            }
            
            then action inspect {
                in inspectionImage = robot.visionSystem.imageData;
            }
            
            then decide;
                if qualityInspection.partQuality then waitForPart;
                else rejectPart;
            
            action rejectPart;
            then waitForPart;
        }
    }
}
