package AnthropomorphicRobotSystem {
    private import ScalarValues::*;
    
    enum def ArmSide {
        left;
        right;
    }
    
    attribute def Length :> Real;
    attribute def Angle :> Real;
    attribute def Force :> Real;
    attribute def Power :> Real;
    attribute def Voltage :> Real;
    attribute def ElectricCurrent :> Real;
    attribute def Percent :> Real;
    attribute def TimeDuration :> Real;
    
    item def Pose3D {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }
    
    item def JointCommand {
        attribute targetAngles : Angle[*];
        attribute duration : TimeDuration;
    }
    
    item def GripperCommand {
        attribute graspType : String;
        attribute force : Force;
        attribute fingerPositions : Angle[5];
    }
    
    item def ArmCommand {
        attribute sequence : JointCommand[*];
        attribute targetPose : Pose3D;
    }
    
    item def PerceptionData {
        attribute objectDetected : Boolean;
        attribute detectedObjects : Pose3D[*];
        attribute map3DGenerated : Boolean;
    }
    
    item def HighLevelTask {
        attribute taskId : String;
        attribute targetPose : Pose3D;
        attribute graspType : String;
        attribute maxForce : Force;
    }
    
    item def PowerStatus {
        attribute batteryLevel : Percent;
        attribute powerDraw : Power;
    }
    
    port def PowerInPort {
        in voltage : Voltage;
        in current : ElectricCurrent;
    }
    
    port def PowerOutPort {
        out voltage : Voltage;
        out current : ElectricCurrent;
    }
    
    port def PerceptionDataOutPort {
        out perception : PerceptionData;
    }
    
    port def PerceptionDataInPort {
        in perception : PerceptionData;
    }
    
    port def TaskCommandInPort {
        in task : HighLevelTask;
    }
    
    port def ArmCommandOutPort {
        out command : ArmCommand;
    }
    
    port def ArmCommandInPort {
        in command : ArmCommand;
    }
    
    port def GripperCommandOutPort {
        out command : GripperCommand;
    }
    
    port def GripperCommandInPort {
        in command : GripperCommand;
    }
    
    port def JointCommandOutPort {
        out command : JointCommand;
    }
    
    port def JointCommandInPort {
        in command : JointCommand;
    }
    
    port def PowerStatusOutPort {
        out status : PowerStatus;
    }
    
    part def CentralMotionPlanner {
        port powerIn : PowerInPort;
        port visionDataIn : PerceptionDataInPort;
        port taskCmdIn : TaskCommandInPort;
        port armCmdOutLeft : ArmCommandOutPort;
        port armCmdOutRight : ArmCommandOutPort;
        port gripperCmdOutLeft : GripperCommandOutPort;
        port gripperCmdOutRight : GripperCommandOutPort;
        
        perform action planMotion {
            in attribute task : HighLevelTask;
            in attribute perception : PerceptionData;
            out attribute armCommands : ArmCommand[2];
            out attribute gripperCommands : GripperCommand[2];
            first start;
            then action analyzeScene;
            then action computeCollisionFreeTrajectory;
            then action computeGripStrategy;
            then action assembleCommands;
            then done;
        }
    }
    
    part def StereoVisionSystem {
        port powerIn : PowerInPort;
        port perceptionOut : PerceptionDataOutPort;
        
        perform action captureAndProcess {
            out attribute perception : PerceptionData;
            first start;
            then action captureStereoImages;
            then action generateDepthMap;
            then action detectObjects;
            then action assemblePerception;
            then done;
        }
    }
    
    part def ArmController {
        port powerIn : PowerInPort;
        port armCmdIn : ArmCommandInPort;
        port shoulderCmdOut : JointCommandOutPort;
        port elbowCmdOut : JointCommandOutPort;
        port wristCmdOut : JointCommandOutPort;
        
        perform action decomposeArmCommand {
            in attribute armCmd : ArmCommand;
            out attribute shoulderCmd : JointCommand;
            out attribute elbowCmd : JointCommand;
            out attribute wristCmd : JointCommand;
            first start;
            then action extractShoulderCommand;
            then action extractElbowCommand;
            then action extractWristCommand;
            then done;
        }
    }
    
    part def ShoulderJoint {
        port powerIn : PowerInPort;
        port commandIn : JointCommandInPort;
        attribute axisCount : Integer = 3;
    }
    
    part def ElbowJoint {
        port powerIn : PowerInPort;
        port commandIn : JointCommandInPort;
        attribute axisCount : Integer = 1;
    }
    
    part def WristJoint {
        port powerIn : PowerInPort;
        port commandIn : JointCommandInPort;
        attribute axisCount : Integer = 2;
    }
    
    part def Finger;
    
    part def AnthropomorphicGripper {
        port powerIn : PowerInPort;
        port commandIn : GripperCommandInPort;
        part fingers[5] : Finger;
        attribute appliedForce : Force = 0.0;
    }
    
    part def ArmAssembly {
        attribute side : ArmSide;
        port powerIn : PowerInPort;
        port commandIn : ArmCommandInPort;
        port gripperCommandIn : GripperCommandInPort;
        part shoulder : ShoulderJoint;
        part elbow : ElbowJoint;
        part wrist : WristJoint;
        part hand : AnthropomorphicGripper;
        part controller : ArmController;
        
        connect powerIn to shoulder.powerIn;
        connect powerIn to elbow.powerIn;
        connect powerIn to wrist.powerIn;
        connect powerIn to hand.powerIn;
        connect powerIn to controller.powerIn;
        
        connect commandIn to controller.armCmdIn;
        connect controller.shoulderCmdOut to shoulder.commandIn;
        connect controller.elbowCmdOut to elbow.commandIn;
        connect controller.wristCmdOut to wrist.commandIn;
        connect gripperCommandIn to hand.commandIn;
    }
    
    part def PowerManagementUnit {
        port mainPowerIn : PowerInPort;
        port powerOutVision : PowerOutPort;
        port powerOutPlanner : PowerOutPort;
        port powerOutArmLeft : PowerOutPort;
        port powerOutArmRight : PowerOutPort;
        port statusOut : PowerStatusOutPort;
        attribute batteryLevel : Percent = 100.0;
        attribute powerDraw : Power = 0.0;
        
        perform action monitorPower {
            first start;
            then action senseBatteryLevel;
            then action computePowerDraw;
            then action updateStatus;
            then done;
        }
    }
    
    part def RobotSystem {
        port mainPowerIn : PowerInPort;
        port taskCmdIn : TaskCommandInPort;
        attribute commandReceived : Boolean = false;
        attribute perceptionComplete : Boolean = false;
        attribute planReady : Boolean = false;
        attribute taskComplete : Boolean = false;
        
        part vision : StereoVisionSystem;
        part planner : CentralMotionPlanner;
        part powerMgmt : PowerManagementUnit;
        part leftArm : ArmAssembly { :>> side = ArmSide::left; }
        part rightArm : ArmAssembly { :>> side = ArmSide::right; }
        
        connect mainPowerIn to powerMgmt.mainPowerIn;
        connect powerMgmt.powerOutVision to vision.powerIn;
        connect powerMgmt.powerOutPlanner to planner.powerIn;
        connect powerMgmt.powerOutArmLeft to leftArm.powerIn;
        connect powerMgmt.powerOutArmRight to rightArm.powerIn;
        
        connect vision.perceptionOut to planner.visionDataIn;
        connect taskCmdIn to planner.taskCmdIn;
        connect planner.armCmdOutLeft to leftArm.commandIn;
        connect planner.armCmdOutRight to rightArm.commandIn;
        connect planner.gripperCmdOutLeft to leftArm.gripperCommandIn;
        connect planner.gripperCmdOutRight to rightArm.gripperCommandIn;
        
        state machine operationalSequence {
            state idle {
                entry action awaitCommand;
            }
            state perceiving {
                entry action scanEnvironment;
            }
            state planning {
                entry action computePlan;
            }
            state executing {
                entry action executeAction;
            }
            transition first idle then perceiving;
            transition first perceiving then planning;
            transition first planning then executing;
            transition first executing then idle;
        }
    }
    
    requirement def AnthropomorphicRobotRequirement {
        text "This is an anthropomorphic robot system designed to replicate the upper body of a human for performing complex manipulation tasks. The system is built around a central controller and is equipped with a pair of highly articulated arms and a sophisticated stereo vision system, enabling it to operate with dexterity in human-centric environments.";
    }
    
    part anthropomorphicRobot : RobotSystem;
}
