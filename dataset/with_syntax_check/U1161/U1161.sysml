package PerceptualRoboticsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def ImageData {
        attribute width : Integer;
        attribute height : Integer;
        attribute timestamp : TimeValue;
    }
    
    attribute def PointCloud {
        attribute numPoints : Integer;
        attribute timestamp : TimeValue;
    }
    
    attribute def ObjectDetection {
        attribute objectId : String;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute positionZ : LengthValue;
        attribute classification : String;
        attribute confidence : Real;
    }
    
    attribute def WorldModel {
        attribute numObjects : Integer;
        attribute robotX : LengthValue;
        attribute robotY : LengthValue;
        attribute robotZ : LengthValue;
        attribute lastUpdate : TimeValue;
    }
    
    attribute def MotionCommand {
        attribute linearVelocity : SpeedValue;
        attribute angularVelocity : Real;
        attribute duration : TimeValue;
    }
    
    attribute def ManipulatorCommand {
        attribute joint1 : Real;
        attribute joint2 : Real;
        attribute joint3 : Real;
        attribute joint4 : Real;
        attribute joint5 : Real;
        attribute joint6 : Real;
        attribute gripperState : Boolean;
        attribute targetForce : ForceValue;
    }
    
    attribute def TaskGoal {
        attribute goalType : String;
        attribute targetObjectId : String;
        attribute targetX : LengthValue;
        attribute targetY : LengthValue;
        attribute targetZ : LengthValue;
    }
    
    port def VisionPort {
        out rgbImage : ImageData;
        out depthImage : ImageData;
    }
    
    port def LidarPort {
        out pointCloudData : PointCloud;
    }
    
    port def PerceptionOutputPort {
        out detections : ObjectDetection;
        out worldModel : WorldModel;
    }
    
    port def PlanningPort {
        in currentWorldModel : WorldModel;
        in taskGoal : TaskGoal;
        out motionPlan : MotionCommand;
        out manipulationPlan : ManipulatorCommand;
    }
    
    port def ControlPort {
        in motionCmd : MotionCommand;
        out actualVelocity : SpeedValue;
        out actualX : LengthValue;
        out actualY : LengthValue;
        out actualZ : LengthValue;
    }
    
    port def ManipulatorPort {
        in manipCmd : ManipulatorCommand;
        out joint1State : Real;
        out joint2State : Real;
        out joint3State : Real;
        out joint4State : Real;
        out joint5State : Real;
        out joint6State : Real;
        out gripperForce : ForceValue;
    }
    
    action def CaptureImage {
        out image : ImageData;
        out depth : ImageData;
    }
    
    action def ScanEnvironment {
        out scan : PointCloud;
    }
    
    action def DetectObjects {
        in rgbData : ImageData;
        in depthData : ImageData;
        in lidarData : PointCloud;
        out objects : ObjectDetection;
    }
    
    action def BuildWorldModel {
        in detections : ObjectDetection;
        in previousModel : WorldModel;
        out updatedModel : WorldModel;
    }
    
    action def PlanPath {
        in world : WorldModel;
        in goal : TaskGoal;
        out trajectory : MotionCommand;
    }
    
    action def PlanManipulation {
        in targetObject : ObjectDetection;
        in world : WorldModel;
        out manipSequence : ManipulatorCommand;
    }
    
    action def ExecuteMotion {
        in command : MotionCommand;
        out posX : LengthValue;
        out posY : LengthValue;
        out posZ : LengthValue;
        out velocity : SpeedValue;
    }
    
    action def ExecuteManipulation {
        in command : ManipulatorCommand;
        out j1 : Real;
        out j2 : Real;
        out j3 : Real;
        out j4 : Real;
        out j5 : Real;
        out j6 : Real;
        out graspForce : ForceValue;
    }
    
    part def RGBDCamera {
        port visionOut : VisionPort;
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute depthRange : LengthValue = 10.0 [m];
        attribute frameRate : FrequencyValue = 30.0 [Hz];
        
        perform action capture : CaptureImage {
            out image = visionOut.rgbImage;
            out depth = visionOut.depthImage;
        }
    }
    
    part def LidarSensor {
        port lidarOut : LidarPort;
        attribute scanRate : FrequencyValue = 10.0 [Hz];
        attribute range : LengthValue = 30.0 [m];
        attribute angularResolution : Real = 0.25;
        
        perform action scan : ScanEnvironment {
            out scan = lidarOut.pointCloudData;
        }
    }
    
    part def PerceptionSubsystem {
        port visionIn : ~VisionPort;
        port lidarIn : ~LidarPort;
        port perceptionOut : PerceptionOutputPort;
        
        attribute currentModel : WorldModel;
        
        action perceiveEnvironment {
            in rgb : ImageData;
            in depth : ImageData;
            in lidar : PointCloud;
            out model : WorldModel;
            
            first start;
            then action detect : DetectObjects {
                in rgbData = rgb;
                in depthData = depth;
                in lidarData = lidar;
                out objects;
            }
            then action buildModel : BuildWorldModel {
                in detections = detect.objects;
                in previousModel = currentModel;
                out updatedModel;
            }
            then assign currentModel := buildModel.updatedModel;
            then assign model := buildModel.updatedModel;
            then done;
        }
    }
    
    part def PlanningSubsystem {
        port planningIn : ~PlanningPort;
        port planningOut : PlanningPort;
        
        action generatePlan {
            in worldModel : WorldModel;
            in goal : TaskGoal;
            out motionCommands : MotionCommand;
            out manipCommands : ManipulatorCommand;
            
            first start;
            then decide;
                if goal.goalType == "navigate" then planNavigation;
                if goal.goalType == "manipulate" then planGrasping;
            
            action planNavigation {
                action pathPlan : PlanPath {
                    in world = worldModel;
                    in goal = goal;
                    out trajectory;
                }
                then assign motionCommands := pathPlan.trajectory;
            }
            then done;
            
            action planGrasping {
                action manipPlan : PlanManipulation {
                    in targetObject : ObjectDetection;
                    in world = worldModel;
                    out manipSequence;
                }
                then assign manipCommands := manipPlan.manipSequence;
            }
            then done;
        }
    }
    
    part def MobileBase {
        port controlIn : ~ControlPort;
        
        attribute maxSpeed : SpeedValue = 2.0 [m/s];
        attribute maxAcceleration : AccelerationValue = 1.0 [m/s^2];
        attribute currentX : LengthValue;
        attribute currentY : LengthValue;
        attribute currentZ : LengthValue;
        
        action executeBaseMotion {
            in cmd : MotionCommand;
            out posX : LengthValue;
            out posY : LengthValue;
            out posZ : LengthValue;
            out vel : SpeedValue;
            
            first start;
            then action move : ExecuteMotion {
                in command = cmd;
                out posX;
                out posY;
                out posZ;
                out velocity;
            }
            then assign currentX := move.posX;
            then assign currentY := move.posY;
            then assign currentZ := move.posZ;
            then assign posX := move.posX;
            then assign posY := move.posY;
            then assign posZ := move.posZ;
            then assign vel := move.velocity;
            then done;
        }
    }
    
    part def RoboticArm {
        port manipIn : ~ManipulatorPort;
        
        attribute numJoints : Integer = 6;
        attribute maxReach : LengthValue = 0.85 [m];
        attribute maxPayload : MassValue = 5.0 [kg];
        attribute currentJ1 : Real;
        attribute currentJ2 : Real;
        attribute currentJ3 : Real;
        attribute currentJ4 : Real;
        attribute currentJ5 : Real;
        attribute currentJ6 : Real;
        
        action executeArmMotion {
            in cmd : ManipulatorCommand;
            out j1 : Real;
            out j2 : Real;
            out j3 : Real;
            out j4 : Real;
            out j5 : Real;
            out j6 : Real;
            out force : ForceValue;
            
            first start;
            then action manipulate : ExecuteManipulation {
                in command = cmd;
                out j1;
                out j2;
                out j3;
                out j4;
                out j5;
                out j6;
                out graspForce;
            }
            then assign currentJ1 := manipulate.j1;
            then assign currentJ2 := manipulate.j2;
            then assign currentJ3 := manipulate.j3;
            then assign currentJ4 := manipulate.j4;
            then assign currentJ5 := manipulate.j5;
            then assign currentJ6 := manipulate.j6;
            then assign j1 := manipulate.j1;
            then assign j2 := manipulate.j2;
            then assign j3 := manipulate.j3;
            then assign j4 := manipulate.j4;
            then assign j5 := manipulate.j5;
            then assign j6 := manipulate.j6;
            then assign force := manipulate.graspForce;
            then done;
        }
    }
    
    part def ControlSubsystem {
        action coordinateExecution {
            in motionPlan : MotionCommand;
            in manipPlan : ManipulatorCommand;
            out baseCmd : MotionCommand;
            out armCmd : ManipulatorCommand;
            
            first start;
            then assign baseCmd := motionPlan;
            then assign armCmd := manipPlan;
            then done;
        }
    }
    
    state def RobotOperationalState {
        entry; then Initializing;
        
        state Initializing;
        state Ready;
        state Perceiving;
        state Planning;
        state Executing;
        state Error;
        
        transition init : Initializing -> Ready;
        transition startPerception : Ready -> Perceiving;
        transition perceptionComplete : Perceiving -> Planning;
        transition planningComplete : Planning -> Executing;
        transition executionComplete : Executing -> Perceiving;
        transition taskDone : Executing -> Ready;
        transition errorDetected : Perceiving -> Error;
        transition errorDetected2 : Executing -> Error;
        transition recover : Error -> Initializing;
    }
    
    requirement def SystemMissionRequirement {
        doc /* The perceptual robotics system shall autonomously perceive, understand, 
        and interact with its environment to accomplish manipulation and navigation tasks. */
    }
    
    requirement def PerceptionAccuracyRequirement {
        doc /* Object detection shall achieve minimum 90% accuracy at ranges up to 5 meters. */
        
        require constraint {
            doc /* Detection confidence must exceed 0.90 */
        }
    }
    
    requirement def RealtimePerformanceRequirement {
        doc /* The perception-planning-execution cycle shall complete within 200 milliseconds. */
        
        require constraint {
            doc /* Cycle time <= 200 ms */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The system shall detect and avoid collisions with obstacles and humans. */
        
        require constraint {
            doc /* Minimum clearance of 0.3 m from obstacles */
        }
    }
    
    requirement def ManipulationPrecisionRequirement {
        doc /* End effector positioning accuracy shall be within 5 millimeters. */
        
        require constraint {
            doc /* Position error <= 5 mm */
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for the perceptual robotics system. */
        
        require missionReq : SystemMissionRequirement;
        require perceptionReq : PerceptionAccuracyRequirement;
        require performanceReq : RealtimePerformanceRequirement;
        require safetyReq : SafetyRequirement;
        require precisionReq : ManipulationPrecisionRequirement;
    }
    
    part def PerceptualRobot;
    
    part perceptualRobot : PerceptualRobot {
        doc /* 
        An autonomous perceptual robotics system that integrates vision and lidar sensing
        to build a comprehensive understanding of its environment. The system continuously
        perceives the world through multiple sensor modalities, fuses this information into
        a coherent world model, plans appropriate actions to achieve task goals, and executes
        coordinated motion and manipulation behaviors. The primary function is to enable
        autonomous interaction with unstructured environments through real-time perception,
        intelligent planning, and precise execution of navigation and manipulation tasks.
        */
        
        satisfy systemRequirements;
        
        part camera : RGBDCamera {
            :>> resolutionWidth = 1920;
            :>> resolutionHeight = 1080;
            :>> depthRange = 10.0 [m];
            :>> frameRate = 30.0 [Hz];
        }
        
        part lidar : LidarSensor {
            :>> scanRate = 10.0 [Hz];
            :>> range = 30.0 [m];
            :>> angularResolution = 0.25;
        }
        
        part perception : PerceptionSubsystem;
        part planner : PlanningSubsystem;
        part controller : ControlSubsystem;
        part base : MobileBase;
        part arm : RoboticArm;
        
        attribute operationalState : RobotOperationalState;
        attribute currentGoal : TaskGoal;
        
        connect camera.visionOut to perception.visionIn;
        connect lidar.lidarOut to perception.lidarIn;
        
        action operateAutonomously {
            in goal : TaskGoal;
            
            first start;
            then merge continuousOperation;
            
            then action senseWorld {
                action captureVision {
                    perform camera.capture;
                }
                action captureLidar {
                    perform lidar.scan;
                }
            }
            
            then action perceive {
                perform perception.perceiveEnvironment;
            }
            
            then action plan {
                perform planner.generatePlan;
            }
            
            then action control {
                perform controller.coordinateExecution;
            }
            
            then decide;
                if controller.coordinateExecution.baseCmd != null then moveBase;
                if controller.coordinateExecution.armCmd != null then moveArm;
            
            action moveBase {
                perform base.executeBaseMotion;
            }
            then continuousOperation;
            
            action moveArm {
                perform arm.executeArmMotion;
            }
            then continuousOperation;
        }
        
        perform action mainOperation : operateAutonomously;
    }
}
