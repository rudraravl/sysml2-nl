package KUKA_Manufacturing_Cell {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value Types
    value type LengthValue :> Real { unit = 'm'; }
    value type MassValue :> Real { unit = 'kg'; }
    value type ForceValue :> Real { unit = 'N'; }
    value type VoltageValue :> Real { unit = 'V'; }
    value type AngleValue :> Real { unit = 'deg'; }
    
    // Item Types
    item def Workpiece {
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute position : LengthValue[3];
    }
    
    item def VisionData {
        attribute partPosition : LengthValue[3];
        attribute partDimensions : LengthValue[3];
        attribute partMass : MassValue;
    }
    
    item def MotionCommand {
        attribute targetPosition : LengthValue[3];
        attribute targetOrientation : AngleValue[6];
        attribute speed : Real;
    }
    
    item def SafetySignal {
        attribute isSafe : Boolean;
        attribute eStopTriggered : Boolean;
        attribute lightCurtainBroken : Boolean;
    }
    
    item def ElectricPower {
        attribute voltage : VoltageValue;
        attribute current : Real;
    }
    
    item def PneumaticPressure {
        attribute force : ForceValue;
        attribute isActuated : Boolean;
    }
    
    item def MotionFeedback {
        attribute currentJointAngles : AngleValue[6];
        attribute isMoving : Boolean;
    }
    
    // Ports
    port def PowerPort {
        out item power : ElectricPower;
    }
    
    port def ControlPort {
        out item commands : MotionCommand;
        in item feedback : MotionFeedback;
    }
    
    port def VisionDataPort {
        out item data : VisionData;
    }
    
    port def PneumaticPort {
        out item pressure : PneumaticPressure;
    }
    
    port def SafetyPort {
        out item signal : SafetySignal;
    }
    
    // Parts
    part def ManipulatorArm {
        attribute reach : LengthValue = 2.0;
        attribute payloadCapacity : MassValue = 16.0;
        attribute repeatability : LengthValue = 0.00003;
        
        port powerInput : PowerPort;
        port jointControl : ControlPort;
        port pneumaticOutput : PneumaticPort;
        
        part joints : Joints[6];
        part def Joints {
            attribute angle : AngleValue;
        }
        
        action def MoveTo {
            in target : LengthValue[3];
        }
    }
    
    part def PneumaticGripper {
        attribute maxForce : ForceValue = 100.0;
        
        port pneumaticInput : PneumaticPort;
        port gripOutput : PneumaticPort;
        
        action def Grasp {
            in workpiece : Workpiece;
        }
        action def Release {}
    }
    
    part def VisionSystem {
        port powerInput : PowerPort;
        port visionOutput : VisionDataPort;
        
        action def DetectWorkpiece {
            out data : VisionData;
        }
    }
    
    part def RobotController {
        port powerInput : PowerPort;
        port visionInput : VisionDataPort;
        port armControl : ControlPort;
        port safetyInput : SafetyPort;
        
        attribute currentProgram : String;
        
        action def CalculateMotion {
            in visionData : VisionData;
            out command : MotionCommand;
        }
    }
    
    part def SafetyController {
        port powerInput : PowerPort;
        port safetyOutput : SafetyPort;
        
        attribute eStopActive : Boolean;
        attribute lightCurtainBroken : Boolean;
        
        action def MonitorWorkspace {
            out signal : SafetySignal;
        }
    }
    
    part def PowerDistributionUnit {
        attribute inputVoltage : VoltageValue = 480.0;
        port robotPower : PowerPort;
        port controllerPower : PowerPort;
        port visionPower : PowerPort;
        port safetyPower : PowerPort;
    }
    
    // Cell Assembly
    part def ManufacturingCell {
        attribute productionStart : Boolean;
        attribute pauseCommand : Boolean;
        attribute resumeCommand : Boolean;
        attribute safetyReset : Boolean;
        
        part pdu : PowerDistributionUnit;
        part manipulator : ManipulatorArm;
        part gripper : PneumaticGripper;
        part vision : VisionSystem;
        part robotController : RobotController;
        part safetyController : SafetyController;
        
        connection def PowerConnection {
            end source : PowerPort;
            end target : PowerPort;
        }
        connection def ControlConnection {
            end source : ControlPort;
            end target : ControlPort;
        }
        connection def VisionConnection {
            end source : VisionDataPort;
            end target : VisionDataPort;
        }
        connection def PneumaticConnection {
            end source : PneumaticPort;
            end target : PneumaticPort;
        }
        connection def SafetyConnection {
            end source : SafetyPort;
            end target : SafetyPort;
        }
        
        // Connections
        connection powerToManipulator : PowerConnection connect pdu.robotPower to manipulator.powerInput;
        connection powerToController : PowerConnection connect pdu.controllerPower to robotController.powerInput;
        connection powerToVision : PowerConnection connect pdu.visionPower to vision.powerInput;
        connection powerToSafety : PowerConnection connect pdu.safetyPower to safetyController.powerInput;
        
        connection visionToController : VisionConnection connect vision.visionOutput to robotController.visionInput;
        connection controllerToManipulator : ControlConnection connect robotController.armControl to manipulator.jointControl;
        connection manipulatorToGripper : PneumaticConnection connect manipulator.pneumaticOutput to gripper.pneumaticInput;
        connection safetyToController : SafetyConnection connect safetyController.safetyOutput to robotController.safetyInput;
        
        // State Machine
        state machine cellLifecycle {
            entry; then standby;
            
            state standby;
            state automatic {
                do pickAndPlaceCycle;
            }
            state paused;
            state emergencyStopped;
            
            transition standby_to_automatic first standby if (productionStart) -> automatic;
            transition automatic_to_paused first automatic if (pauseCommand) -> paused;
            transition paused_to_automatic first paused if (resumeCommand) -> automatic;
            
            transition automatic_to_emergency first automatic if (!safetyController.safetyOutput.signal.isSafe) -> emergencyStopped;
            transition paused_to_emergency first paused if (!safetyController.safetyOutput.signal.isSafe) -> emergencyStopped;
            transition standby_to_emergency first standby if (!safetyController.safetyOutput.signal.isSafe) -> emergencyStopped;
            transition emergency_to_standby first emergencyStopped if (safetyReset) -> standby;
            
            action pickAndPlaceCycle {
                action detectWorkpiece : vision.DetectWorkpiece;
                then calculateMotion : robotController.CalculateMotion;
                then moveToWorkpiece : manipulator.MoveTo;
                then graspWorkpiece : gripper.Grasp;
                then moveToAssembly : manipulator.MoveTo;
                then releaseWorkpiece : gripper.Release;
                then returnHome : manipulator.MoveTo;
                then detectWorkpiece;
            }
        }
        
        // Requirements
        requirement def RoboticAssemblyRequirements {
            subject cell : ManufacturingCell;
            
            requirement manipulatorReach {
                subject arm : ManipulatorArm;
                require arm.reach >= 2.0;
            }
            requirement manipulatorPayload {
                subject arm : ManipulatorArm;
                require arm.payloadCapacity >= 16.0;
            }
            requirement manipulatorRepeatability {
                subject arm : ManipulatorArm;
                require arm.repeatability <= 0.00003;
            }
            requirement safetyMonitoring {
                subject safetyCtrl : SafetyController;
                require safetyCtrl.eStopActive == false;
            }
        }
    }
}
