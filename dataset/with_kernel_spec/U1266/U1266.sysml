package YaskawaMotomanRoboticCell {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def AngleValue :> ISQ::PlaneAngleValue;
    attribute def AngularSpeedValue :> ISQ::AngularVelocityValue;
    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def MassValue :> ISQ::MassValue;
    attribute def LengthValue :> ISQ::LengthValue;

    item def ACInputPower;
    item def DCOutputPower;
    item def MotionCommand {
        attribute targetJointPositions : AngleValue[6];
        attribute targetJointVelocities : AngularSpeedValue[6];
    }
    item def JointFeedback {
        attribute actualJointPositions : AngleValue[6];
        attribute actualJointVelocities : AngularSpeedValue[6];
        attribute actualMotorCurrents : CurrentValue[6];
    }
    item def SafetyBreachSignal;
    item def Part;
    attribute def Program {
        attribute name : String;
        attribute numberOfSteps : Integer;
    }

    port def ACPowerPort {
        out item power : ACInputPower;
    }
    port def DCPowerPort {
        out item power : DCOutputPower;
    }
    port def CommandPort {
        out item command : MotionCommand;
    }
    port def FeedbackPort {
        out item feedback : JointFeedback;
    }
    port def SafetyPort {
        out item signal : SafetyBreachSignal;
    }
    port def OperatorCommandPort {
        in attribute startProgram : Boolean;
        in attribute pauseProgram : Boolean;
        in attribute resumeProgram : Boolean;
        in attribute resetSystem : Boolean;
    }

    attribute def PowerOn;
    attribute def InitializationComplete;
    attribute def HomePositionReached;
    attribute def StartProgram;
    attribute def Pause;
    attribute def Resume;
    attribute def Stop;
    attribute def ProgramComplete;
    attribute def LightCurtainTripped;
    attribute def Reset;

    action def InitializeSystem;
    action def MoveToHomePosition;
    action def ExecuteProgram;
    action def CalculateTrajectories;
    action def MonitorFeedback;
    action def TriggerEmergencyStop;
    action def DisableMotors;
    action def ApplyBrakes;
    action def EmergencyStopSequence {
        action disableMotors : DisableMotors;
        then action applyBrakes : ApplyBrakes;
    }
    action def Grip;
    action def Release;

    part def ServoMotor {
        attribute ratedTorque : TorqueValue = 3.5 [N*m];
        attribute ratedSpeed : AngularSpeedValue = 300 [rad/s];
        port pwrIn : DCPowerPort;
    }
    part def AbsoluteEncoder {
        attribute resolutionBits : Integer = 24;
        port fbOut : FeedbackPort;
    }
    part def ServoAmplifier {
        attribute continuousCurrent : CurrentValue = 10 [A];
        port cmdIn : CommandPort;
        port pwrIn : DCPowerPort;
        port pwrOut : DCPowerPort;
        port fbIn : FeedbackPort;
    }
    part def Joint {
        attribute index : Integer;
        attribute jointAngle : AngleValue;
        attribute jointSpeed : AngularSpeedValue;
        port motionCommand : CommandPort;
        port feedback : FeedbackPort;
        port powerInput : DCPowerPort;
        part motor : ServoMotor;
        part encoder : AbsoluteEncoder;
        part amplifier : ServoAmplifier;
        connect powerInput to amplifier.pwrIn;
        connect motionCommand to amplifier.cmdIn;
        connect amplifier.pwrOut to motor.pwrIn;
        connect encoder.fbOut to amplifier.fbIn;
    }
    part def PneumaticGripper {
        attribute maxGripForce : ForceValue = 100 [N];
        perform action grip : Grip;
        perform action release : Release;
    }
    part def SixAxisRobotArm {
        attribute maxPayload : MassValue = 20 [kg];
        attribute maxReach : LengthValue = 1.44 [m];
        attribute repeatability : LengthValue = 0.02 [mm];
        port motionCommand : CommandPort[6];
        port feedback : FeedbackPort[6];
        port powerInput : DCPowerPort[6];
        part joints : Joint[6];
        part gripper : PneumaticGripper;
        connect motionCommand to joints.motionCommand;
        connect joints.feedback to feedback;
        connect powerInput to joints.powerInput;
    }
    part def YRC1000Controller {
        attribute firmwareVersion : String = "YRC1000";
        attribute currentProgram : Program;
        port cmdPorts : CommandPort[6];
        port fbPorts : FeedbackPort[6];
        port safetyIn : SafetyPort;
        port operatorCmd : OperatorCommandPort;
        port pwrIn : DCPowerPort;
        perform action calculateTrajectories : CalculateTrajectories;
        perform action monitorFeedback : MonitorFeedback;
        perform action triggerEmergencyStop : TriggerEmergencyStop;
    }
    part def PowerSupply {
        attribute inputVoltage : VoltageValue = 480 [V];
        attribute outputPower : PowerValue = 3000 [W];
        port acIn : ACPowerPort;
        port dcOut : DCPowerPort[6];
        port dcController : DCPowerPort;
    }
    part def SafetyLightCurtain {
        attribute beamWidth : LengthValue = 15 [mm];
        attribute beamBroken : Boolean;
        port safetyOut : SafetyPort;
    }
    part def MotomanRoboticCell {
        part arm : SixAxisRobotArm;
        part controller : YRC1000Controller;
        part powerSupply : PowerSupply;
        part lightCurtain : SafetyLightCurtain;
        port operatorCommand : OperatorCommandPort;
        port powerInput : ACPowerPort;

        connect powerInput to powerSupply.acIn;
        connect powerSupply.dcOut to arm.powerInput;
        connect powerSupply.dcController to controller.pwrIn;
        connect controller.cmdPorts to arm.motionCommand;
        connect arm.feedback to controller.fbPorts;
        connect lightCurtain.safetyOut to controller.safetyIn;
        connect operatorCommand to controller.operatorCmd;

        perform action initializeSystem : InitializeSystem;
        perform action moveToHomePosition : MoveToHomePosition;
        perform action executeProgram : ExecuteProgram;
        perform action emergencyStopSequence : EmergencyStopSequence;
        perform action monitorFeedback : MonitorFeedback;
        perform action calculateTrajectories : CalculateTrajectories;

        exhibit state cellStates {
            entry;
            then off;
            state off;
            transition off_to_initializing
                first off
                accept PowerOn
                then initializing;
            state initializing {
                entry initializeSystem;
            }
            transition initializing_to_homing
                first initializing
                accept InitializationComplete
                then homing;
            state homing {
                entry moveToHomePosition;
            }
            transition homing_to_ready
                first homing
                accept HomePositionReached
                then ready;
            state ready;
            transition ready_to_running
                first ready
                accept StartProgram
                then running;
            state running {
                entry executeProgram;
                do monitorFeedback;
            }
            transition running_to_paused
                first running
                accept Pause
                then paused;
            transition running_to_complete
                first running
                accept ProgramComplete
                then ready;
            transition running_to_emergencyStop
                first running
                accept LightCurtainTripped
                then emergencyStop;
            state paused;
            transition paused_to_running
                first paused
                accept Resume
                then running;
            transition paused_to_ready
                first paused
                accept Stop
                then ready;
            transition paused_to_emergencyStop
                first paused
                accept LightCurtainTripped
                then emergencyStop;
            state emergencyStop {
                entry emergencyStopSequence;
            }
            transition emergencyStop_to_off
                first emergencyStop
                accept Reset
                then off;
        }
    }

    requirement def PayloadCapacityRequirement {
        subject arm : SixAxisRobotArm;
        doc /* The robot arm shall handle payloads up to 20 kg. */
        constraint { arm.maxPayload <= 20 [kg] }
    }
    requirement def ReachRequirement {
        subject arm : SixAxisRobotArm;
        doc /* The robot arm shall have a reach of 1.44 meters. */
        constraint { arm.maxReach == 1.44 [m] }
    }
    requirement def RepeatabilityRequirement {
        subject arm : SixAxisRobotArm;
        doc /* The robot arm shall have repeatability of 0.02 mm. */
        constraint { arm.repeatability <= 0.02 [mm] }
    }
    requirement def EmergencyStopRequirement {
        subject cell : MotomanRoboticCell;
        doc /* If the safety light curtain beam is broken, the cell shall immediately trigger an emergency stop, disabling motors and applying brakes. */
    }
    requirement def ClosedLoopControlRequirement {
        subject joint : Joint;
        doc /* Each joint shall use a closed-loop servo configuration with motor, encoder, and amplifier to ensure exact and controlled movement. */
    }

    part roboticCell : MotomanRoboticCell {
        requirement payloadCapacity : PayloadCapacityRequirement {
            subject arm = arm;
        }
        requirement reach : ReachRequirement {
            subject arm = arm;
        }
        requirement repeatability : RepeatabilityRequirement {
            subject arm = arm;
        }
        requirement emergencyStop : EmergencyStopRequirement {
            subject cell = roboticCell;
        }
    }
}
