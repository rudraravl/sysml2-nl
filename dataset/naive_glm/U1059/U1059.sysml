package AutonomousHumanoidRobot {

    import ScalarValues::*;
    import ISQ::*;

    value def MassKg :> Mass;
    value def ForceN :> Force;
    value def DurationH :> TimeValue;
    value def PowerW :> Power;

    item def EnvironmentalModel;
    item def TaskInstruction;
    item def MotionPlan {
        attribute isActive : Boolean;
    }
    item def JointFeedback {
        attribute error : Real;
    }
    item def MotorCommand;
    item def SensorData;
    item def PowerFlow;

    port def EnvModelPort {
        out model : EnvironmentalModel;
    }
    port def TaskPort {
        in task : TaskInstruction;
    }
    port def MotionPlanPort {
        out plan : MotionPlan;
    }
    port def MotorCmdPort {
        out cmd : MotorCommand;
    }
    port def JointFeedbackPort {
        out feedback : JointFeedback;
    }
    port def SensorDataPort {
        out data : SensorData;
    }
    port def PowerPort {
        out pwr : PowerFlow;
    }

    requirement def RobotRequirements {
        subject robot : HumanoidRobot;
        requirement OperationalDuration {
            doc /* The robot shall operate for at least 4 hours continuously. */
            subject battery : robot.battery;
            constraint { battery.capacity >= 4 [h]; }
        }
        requirement PayloadCapacity {
            doc /* The gripper shall handle objects up to 20kg. */
            subject gripper : robot.leftArm.gripper;
            constraint { gripper.maxLoad >= 20 [kg]; }
        }
        requirement AutonomousOperation {
            doc /* The robot shall operate autonomously with minimal human intervention. */
        }
    }

    part def Joint {
        port cmdIn : ~MotorCmdPort;
        port fbOut : JointFeedbackPort;
        attribute maxTorque : Real;
    }

    part def Gripper :> Joint {
        attribute maxLoad : MassKg = 20 [kg];
        attribute appliedForce : ForceN;
    }

    part def Arm {
        port cmdIn : ~MotorCmdPort;
        port fbOut : JointFeedbackPort;
        part shoulder : Joint;
        part elbow : Joint;
        part wrist : Joint;
        part gripper : Gripper;
        
        connection cmdFlow : MotorCommand connect cmdIn to (shoulder.cmdIn, elbow.cmdIn, wrist.cmdIn, gripper.cmdIn);
        connection fbFlow : JointFeedback connect (shoulder.fbOut, elbow.fbOut, wrist.fbOut, gripper.fbOut) to fbOut;
    }

    part def Leg {
        port cmdIn : ~MotorCmdPort;
        port fbOut : JointFeedbackPort;
        part hip : Joint;
        part knee : Joint;
        part ankle : Joint;
        
        connection cmdFlow : MotorCommand connect cmdIn to (hip.cmdIn, knee.cmdIn, ankle.cmdIn);
        connection fbFlow : JointFeedback connect (hip.fbOut, knee.fbOut, ankle.fbOut) to fbOut;
    }

    part def MobilitySystem {
        port cmdIn : ~MotorCmdPort;
        port fbOut : JointFeedbackPort;
        part leftLeg : Leg;
        part rightLeg : Leg;
        part balanceController;
        
        connection cmdFlow : MotorCommand connect cmdIn to (leftLeg.cmdIn, rightLeg.cmdIn);
        connection fbFlow : JointFeedback connect (leftLeg.fbOut, rightLeg.fbOut) to fbOut;
    }

    part def BatterySystem {
        attribute capacity : DurationH = 4 [h];
        port powerOut : PowerPort;
    }

    part def Sensor {
        port dataOut : SensorDataPort;
        port powerIn : ~PowerPort;
    }

    part def VisionSensor :> Sensor;
    part def AudioSensor :> Sensor;
    part def TactileSensor :> Sensor;

    part def PerceptionSystem {
        port powerIn : ~PowerPort;
        port envModelOut : EnvModelPort;
        
        part vision : VisionSensor;
        part audio : AudioSensor;
        part tactile : TactileSensor;
        part dataFusion {
            port dataIn : ~SensorDataPort;
            port modelOut : EnvModelPort;
        }
        
        connection powerDist : PowerFlow connect powerIn to (vision.powerIn, audio.powerIn, tactile.powerIn);
        connection sensorDataFlow : SensorData connect (vision.dataOut, audio.dataOut, tactile.dataOut) to dataFusion.dataIn;
        connection modelFlow : EnvironmentalModel connect dataFusion.modelOut to envModelOut;
    }

    part def CognitionSystem {
        port powerIn : ~PowerPort;
        port envModelIn : ~EnvModelPort;
        port taskIn : TaskPort;
        port motionPlanOut : MotionPlanPort;
        
        part aiDecisionEngine {
            port modelIn : ~EnvModelPort;
            port taskIn : TaskPort;
            port planOut : MotionPlanPort;
        }
        part taskPlanner;
        part safetyMonitor;
        part learningModule;
        
        connection modelFlow : EnvironmentalModel connect envModelIn to aiDecisionEngine.modelIn;
        connection taskFlow : TaskInstruction connect taskIn to aiDecisionEngine.taskIn;
        connection planFlow : MotionPlan connect aiDecisionEngine.planOut to motionPlanOut;
    }

    part def MotionControlSystem {
        port powerIn : ~PowerPort;
        port motionPlanIn : ~MotionPlanPort;
        port motorCmdOut : MotorCmdPort;
        port jointFeedbackIn : ~JointFeedbackPort;
        
        state def ControlStates {
            entry; 
            state Idle;
            state Executing;
            state Correcting;
            transition init initial to Idle;
            transition start_execution first Idle to Executing when motionPlanIn.plan.isActive;
            transition feedback_correction Executing to Correcting when jointFeedbackIn.feedback.error > 0.1;
            transition correction_done Correcting to Executing when jointFeedbackIn.feedback.error <= 0.1;
            transition execution_done Executing to Idle when !motionPlanIn.plan.isActive;
        }
        
        exhibit state ControlStates;
    }

    part def HumanoidRobot {
        part leftArm : Arm;
        part rightArm : Arm;
        part mobilitySystem : MobilitySystem;
        part battery : BatterySystem;
        part perceptionSystem : PerceptionSystem;
        part cognitionSystem : CognitionSystem;
        part motionControlSystem : MotionControlSystem;
        
        port extTaskIn : TaskPort;
        
        connection powerToPerception : PowerFlow connect battery.powerOut to perceptionSystem.powerIn;
        connection powerToCognition : PowerFlow connect battery.powerOut to cognitionSystem.powerIn;
        connection powerToMotion : PowerFlow connect battery.powerOut to motionControlSystem.powerIn;
        
        connection envModelFlow : EnvironmentalModel connect perceptionSystem.envModelOut to cognitionSystem.envModelIn;
        
        connection taskFlow : TaskInstruction connect extTaskIn to cognitionSystem.taskIn;
        
        connection motionPlanFlow : MotionPlan connect cognitionSystem.motionPlanOut to motionControlSystem.motionPlanIn;
        
        connection cmdToArms : MotorCommand connect motionControlSystem.motorCmdOut to (leftArm.cmdIn, rightArm.cmdIn);
        connection cmdToLegs : MotorCommand connect motionControlSystem.motorCmdOut to mobilitySystem.cmdIn;
        
        connection fbFromArms : JointFeedback connect (leftArm.fbOut, rightArm.fbOut) to motionControlSystem.jointFeedbackIn;
        connection fbFromLegs : JointFeedback connect mobilitySystem.fbOut to motionControlSystem.jointFeedbackIn;
        
        satisfy RobotRequirements by self;
    }
}
