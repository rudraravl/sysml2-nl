package YaskawaIndustrialAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def PositionValue :> Real;
    attribute def VelocityValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def TemperatureValue :> Real;
    
    item def MotionCommand {
        attribute targetPosition : PositionValue;
        attribute targetVelocity : VelocityValue;
        attribute acceleration : Real;
    }
    
    item def FeedbackData {
        attribute actualPosition : PositionValue;
        attribute actualVelocity : VelocityValue;
        attribute motorCurrent : CurrentValue;
        attribute temperature : TemperatureValue;
    }
    
    item def SafetySignal {
        attribute emergencyStop : Boolean;
        attribute safetyZoneViolation : Boolean;
    }
    
    port def ControlPort {
        in item commandIn : MotionCommand;
        out item feedbackOut : FeedbackData;
    }
    
    port def PowerPort {
        in attribute voltage : VoltageValue;
        in attribute current : CurrentValue;
    }
    
    port def SafetyPort {
        in item safetyIn : SafetySignal;
        out item statusOut : SafetySignal;
    }
    
    part def YRC1000MicroController {
        doc /* Yaskawa robot controller for coordinated multi-axis motion control */
        attribute cycleTime : DurationValue = 1.0 [s];
        attribute maxAxes : Integer = 6;
        attribute programMemory : Real;
        
        port commandInterface : ControlPort;
        port axis1Port : ControlPort;
        port axis2Port : ControlPort;
        port axis3Port : ControlPort;
        port axis4Port : ControlPort;
        port axis5Port : ControlPort;
        port axis6Port : ControlPort;
        port safetyInterface : SafetyPort;
        
        perform action executeProgram : ExecuteRobotProgram;
    }
    
    part def Sigma7ServoAmplifier {
        doc /* High-performance servo amplifier with advanced control algorithms */
        attribute ratedCurrent : CurrentValue;
        attribute controlBandwidth : Real;
        attribute outputVoltage : VoltageValue;
        
        port controlInput : ControlPort;
        port motorOutput : ControlPort;
        port powerInput : PowerPort;
    }
    
    part def SGMGHServoMotor {
        doc /* Rotary servo motor with high torque density */
        attribute ratedPower : PowerValue;
        attribute ratedTorque : TorqueValue;
        attribute maxSpeed : VelocityValue;
        attribute rotorInertia : Real;
        attribute encoderResolution : Integer;
        
        attribute currentPosition : PositionValue;
        attribute currentVelocity : VelocityValue;
        attribute outputTorque : TorqueValue;
        
        port motorControl : ControlPort;
        port mechanicalOutput;
    }
    
    part def AbsoluteEncoder {
        doc /* High-resolution absolute position encoder */
        attribute resolution : Integer = 262144;
        attribute accuracy : PositionValue;
        
        port sensorOutput : ControlPort;
    }
    
    part def SafetyLightCurtain {
        doc /* Area safety monitoring device */
        attribute detectionRange : LengthValue;
        attribute responseTime : DurationValue;
        
        port safetyOutput : SafetyPort;
    }
    
    part def PowerSupply {
        doc /* Main power distribution unit */
        attribute inputVoltage : VoltageValue = 400.0;
        attribute outputVoltage : VoltageValue = 200.0;
        attribute maxCurrent : CurrentValue = 50.0;
        
        port acInput;
        port dcOutput1 : PowerPort;
        port dcOutput2 : PowerPort;
        port dcOutput3 : PowerPort;
        port dcOutput4 : PowerPort;
        port dcOutput5 : PowerPort;
        port dcOutput6 : PowerPort;
    }
    
    part def RobotArm {
        doc /* Six-axis articulated robot arm assembly */
        attribute payload : MassValue;
        attribute reach : LengthValue;
        attribute repeatability : LengthValue;
        
        part joint1 : RobotJoint;
        part joint2 : RobotJoint;
        part joint3 : RobotJoint;
        part joint4 : RobotJoint;
        part joint5 : RobotJoint;
        part joint6 : RobotJoint;
        part endEffector : Gripper;
    }
    
    part def RobotJoint {
        doc /* Single axis joint assembly with integrated servo system */
        attribute jointAngle : PlaneAngleValue;
        attribute jointVelocity : Real;
        
        port controlPort : ControlPort;
        port powerPort : PowerPort;
        
        part amplifier : Sigma7ServoAmplifier;
        part motor : SGMGHServoMotor;
        part encoder : AbsoluteEncoder;
        
        connection ampToMotor connect amplifier.motorOutput to motor.motorControl;
    }
    
    part def Gripper {
        doc /* Pneumatic end-effector for part handling */
        attribute gripForce : ForceValue;
        attribute openingWidth : LengthValue;
        attribute isClosed : Boolean;
        
        port controlInput;
    }
    
    action def InitializeSystem {
        first start;
        then action powerOn;
        then action homeAllAxes;
        then action enableServos;
        then done;
    }
    
    action def ExecuteRobotProgram {
        first start;
        then action loadProgram;
        then merge mainLoop;
        
        action readNextInstruction;
        then action parseCommand;
        then action calculateTrajectory {
            in targetPos : PositionValue;
            in currentPos : PositionValue;
            out trajectory : MotionCommand;
        }
        then action sendAxisCommands {
            in trajectory : MotionCommand;
        }
        then action monitorFeedback {
            in feedback : FeedbackData;
            out positionError : PositionValue;
        }
        then decide;
            if monitorFeedback.positionError < 0.01 then checkProgramEnd;
            if monitorFeedback.positionError >= 0.01 then mainLoop;
        
        action checkProgramEnd {
            out programDone : Boolean;
        }
        then decide;
            if checkProgramEnd.programDone then done;
            else mainLoop;
        
        then mainLoop;
        then done;
    }
    
    action def PerformPickAndPlace {
        first start;
        then action moveToPickPosition {
            out reached : Boolean;
        }
        then action openGripper;
        then action lowerToWorkpiece;
        then action closeGripper {
            out gripped : Boolean;
        }
        then action raiseFromWorkpiece;
        then action moveToPlacePosition;
        then action lowerToTarget;
        then action openGripper;
        then action raiseFromTarget;
        then action returnToHome;
        then done;
    }
    
    state def RobotControlState {
        entry; then powerOff;
        
        state powerOff;
        accept at powerOff.systemPowerOn;
        transition first powerOff then initializing;
        
        state initializing {
            entry action performInitialization;
        }
        accept at initializing.initComplete;
        transition first initializing then homing;
        
        state homing {
            entry action findHomePositions;
        }
        accept at homing.homeComplete;
        transition first homing then ready;
        
        state ready;
        accept at ready.startProgram;
        transition first ready then running;
        
        state running {
            entry action executeMotionProgram;
            do action continuousMonitoring;
        }
        accept at running.programComplete;
        transition first running then ready;
        
        accept at running.pauseRequested;
        transition first running then paused;
        
        state paused;
        accept at paused.resumeRequested;
        transition first paused then running;
        
        accept at paused.stopRequested;
        transition first paused then ready;
        
        state emergency {
            entry action disableAllServos;
            entry action applyBrakes;
        }
        accept at emergency.resetComplete;
        transition first emergency then powerOff;
    }
    
    part def YaskawaMotomanRoboticCell {
        doc /* Complete industrial robotic cell for automated manufacturing operations.
             * Primary function: Perform high-speed, high-precision pick-and-place operations
             * in a manufacturing environment with integrated safety systems and coordinated
             * multi-axis motion control. */
        
        attribute cellCycleTime : DurationValue;
        attribute throughput : Real;
        attribute operationalUptime : Real;
        
        part controller : YRC1000MicroController {
            attribute :>> cycleTime = 1.0 [s];
            attribute :>> maxAxes = 6;
            attribute :>> programMemory = 512000.0;
        }
        
        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 400.0;
            attribute :>> outputVoltage = 200.0;
            attribute :>> maxCurrent = 50.0;
        }
        
        part robotArm : RobotArm {
            attribute :>> payload = 20.0 [kg];
            attribute :>> reach = 1440.0 [mm];
            attribute :>> repeatability = 0.02 [mm];
        }
        
        part safetySystem : SafetyLightCurtain {
            attribute :>> detectionRange = 3000.0 [mm];
            attribute :>> responseTime = 15.0 [s];
        }
        
        connection controlToJoint1 connect 
            controller.axis1Port to robotArm.joint1.controlPort;
        
        connection controlToJoint2 connect 
            controller.axis2Port to robotArm.joint2.controlPort;
        
        connection controlToJoint3 connect 
            controller.axis3Port to robotArm.joint3.controlPort;
        
        connection controlToJoint4 connect 
            controller.axis4Port to robotArm.joint4.controlPort;
        
        connection controlToJoint5 connect 
            controller.axis5Port to robotArm.joint5.controlPort;
        
        connection controlToJoint6 connect 
            controller.axis6Port to robotArm.joint6.controlPort;
        
        connection powerToJoint1 connect 
            powerSupply.dcOutput1 to robotArm.joint1.powerPort;
        
        connection powerToJoint2 connect 
            powerSupply.dcOutput2 to robotArm.joint2.powerPort;
        
        connection powerToJoint3 connect 
            powerSupply.dcOutput3 to robotArm.joint3.powerPort;
        
        connection powerToJoint4 connect 
            powerSupply.dcOutput4 to robotArm.joint4.powerPort;
        
        connection powerToJoint5 connect 
            powerSupply.dcOutput5 to robotArm.joint5.powerPort;
        
        connection powerToJoint6 connect 
            powerSupply.dcOutput6 to robotArm.joint6.powerPort;
        
        connection safetyToController connect 
            safetySystem.safetyOutput to controller.safetyInterface;
        
        exhibit state machine cellStateMachine : RobotControlState;
        perform action pickAndPlaceOperation : PerformPickAndPlace;
    }
    
    requirement <'REQ-YAS-100'> primaryFunction {
        doc /* The Yaskawa robotic cell shall perform automated pick-and-place operations
             * with high speed and precision for industrial manufacturing applications. */
        subject cell : YaskawaMotomanRoboticCell;
    }
    
    requirement <'REQ-YAS-101'> positionAccuracy {
        doc /* The robot arm shall achieve positional repeatability of 0.02 mm or better
             * to ensure consistent part placement quality. */
        subject cell : YaskawaMotomanRoboticCell;
        
        require constraint {
            cell.robotArm.repeatability <= 0.02 [mm]
        }
    }
    
    requirement <'REQ-YAS-102'> payloadCapacity {
        doc /* The robot arm shall handle payloads up to 20 kg to accommodate
             * a wide range of manufacturing parts. */
        subject cell : YaskawaMotomanRoboticCell;
        
        require constraint {
            cell.robotArm.payload >= 20.0 [kg]
        }
    }
    
    requirement <'REQ-YAS-103'> controlCycleTime {
        doc /* The motion controller shall execute control cycles at 1 s intervals
             * to provide responsive and smooth motion control. */
        subject cell : YaskawaMotomanRoboticCell;
        
        require constraint {
            cell.controller.cycleTime <= 1.0 [s]
        }
    }
    
    requirement <'REQ-YAS-104'> safetyResponse {
        doc /* The safety system shall detect intrusions and halt robot motion
             * within 15 s to protect operators. */
        subject cell : YaskawaMotomanRoboticCell;
        
        require constraint {
            cell.safetySystem.responseTime <= 15.0 [s]
        }
    }
    
    requirement <'REQ-YAS-105'> multiAxisCoordination {
        doc /* The controller shall coordinate simultaneous motion of six servo axes
             * with synchronized trajectory planning. */
        subject cell : YaskawaMotomanRoboticCell;
        
        require constraint {
            cell.controller.maxAxes >= 6
        }
    }
    
    part yaskawaProductionCell : YaskawaMotomanRoboticCell {
        attribute :>> cellCycleTime = 3.5 [s];
        attribute :>> throughput = 1000.0;
        attribute :>> operationalUptime = 98.5;
    }
    
    satisfy primaryFunction by yaskawaProductionCell.pickAndPlaceOperation;
    satisfy positionAccuracy by yaskawaProductionCell.robotArm;
    satisfy payloadCapacity by yaskawaProductionCell.robotArm;
    satisfy controlCycleTime by yaskawaProductionCell.controller;
    satisfy safetyResponse by yaskawaProductionCell.safetySystem;
    satisfy multiAxisCoordination by yaskawaProductionCell.controller;
}
