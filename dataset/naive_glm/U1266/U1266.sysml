package MotomanRoboticCell {
    import ScalarValues::*;
    import ISQ::*;
    
    value def Mass :> Real { unit = "kg"; }
    value def Length :> Real { unit = "m"; }
    value def Distance :> Real { unit = "mm"; }
    value def Angle :> Real { unit = "deg"; }
    value def AngularVelocity :> Real { unit = "deg/s"; }
    value def Current :> Real { unit = "A"; }
    value def Voltage :> Real { unit = "V"; }
    
    item def Part;
    item def ElectricalPower;
    item def MotionCommand;
    item def FeedbackData {
        attribute position : Angle;
        attribute velocity : AngularVelocity;
        attribute current : Current;
    }
    item def SafetySignal;
    
    port def PowerPort {
        out power : ElectricalPower;
    }
    port def CommandPort {
        out command : MotionCommand;
    }
    port def FeedbackPort {
        out feedback : FeedbackData;
    }
    port def SafetyPort {
        out signal : SafetySignal;
    }
    port def PartPort {
        in part : Part;
    }
    
    enum def ControlCommand { Off, Initialize, Home, Ready, Run, Pause, Resume, Reset; }
    
    requirement def PayloadCapacity {
        doc "The robot arm must handle payloads up to 20 kg."
        constraint { payload <= 20 [kg] }
    }
    requirement def ReachCapacity {
        doc "The robot arm must have a reach of 1.44 meters."
        constraint { reach >= 1.44 [m] }
    }
    requirement def RepeatabilitySpec {
        doc "The robot arm must have a repeatability of 0.02 mm."
        constraint { repeatability <= 0.02 [mm] }
    }
    
    part def ServoMotor {
        port powerIn : PowerPort;
        attribute current : Current;
    }
    part def AbsoluteEncoder {
        port feedbackOut : FeedbackPort;
    }
    part def ServoAmplifier {
        port commandIn : CommandPort;
        port feedbackIn : FeedbackPort;
        port powerOut : PowerPort;
    }
    
    part def Joint {
        attribute index : Integer;
        part amplifier : ServoAmplifier;
        part motor : ServoMotor;
        part encoder : AbsoluteEncoder;
        
        connect amplifier.powerOut to motor.powerIn;
        connect encoder.feedbackOut to amplifier.feedbackIn;
    }
    
    part def PneumaticGripper {
        port partInteraction : PartPort;
        attribute actuated : Boolean;
    }
    
    part def RobotArm {
        satisfy PayloadCapacity;
        satisfy ReachCapacity;
        satisfy RepeatabilitySpec;
        
        attribute payload : Mass = 20 [kg];
        attribute reach : Length = 1.44 [m];
        attribute repeatability : Distance = 0.02 [mm];
        
        part joints : Joint[6];
        part gripper : PneumaticGripper;
        
        port commandPorts : CommandPort[6];
        port powerPorts : PowerPort[6];
        
        connect commandPorts to joints.amplifier.commandIn;
        connect powerPorts to joints.amplifier.powerOut;
    }
    
    part def YRC1000Controller {
        port armCommandPorts : CommandPort[6];
        port safetyIn : SafetyPort;
        
        attribute command : ControlCommand;
        
        action def CalculateTrajectories {
            in joints : Joint[6];
            out commands : MotionCommand[6];
        }
        
        action calculateTrajectories : CalculateTrajectories;
    }
    
    part def MainPowerSupply {
        port dcOutputs : PowerPort[6];
        attribute inputVoltage : Voltage = 480 [V];
    }
    
    part def SafetyLightCurtain {
        port safetyOut : SafetyPort;
        attribute breached : Boolean;
    }
    
    part def MotomanCell {
        part arm : RobotArm;
        part controller : YRC1000Controller;
        part powerSupply : MainPowerSupply;
        part lightCurtain : SafetyLightCurtain;
        
        connect controller.armCommandPorts to arm.commandPorts;
        connect powerSupply.dcOutputs to arm.powerPorts;
        connect lightCurtain.safetyOut to controller.safetyIn;
        
        state def CellLifecycle {
            initial start;
            state Off;
            state Initializing;
            state Home;
            state Ready;
            state Running;
            state Paused;
            state EmergencyStop;
            
            transition from Off to Initializing when controller.command == ControlCommand::Initialize;
            transition from Initializing to Home when controller.command == ControlCommand::Home;
            transition from Home to Ready when controller.command == ControlCommand::Ready;
            transition from Ready to Running when controller.command == ControlCommand::Run;
            transition from Running to Paused when controller.command == ControlCommand::Pause;
            transition from Paused to Running when controller.command == ControlCommand::Resume;
            transition from Ready to EmergencyStop when lightCurtain.breached == true;
            transition from Running to EmergencyStop when lightCurtain.breached == true;
            transition from Paused to EmergencyStop when lightCurtain.breached == true;
            transition from EmergencyStop to Off when controller.command == ControlCommand::Reset;
        }
    }
}
