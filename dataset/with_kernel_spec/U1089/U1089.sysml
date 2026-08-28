package CollaborativeRoboticAssemblySystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        item def AssemblyPart {
            attribute partId : String;
            attribute partMass :> ISQ::mass;
        }
        item def AssemblyStep {
            attribute stepId : String;
            attribute targetPart : String;
        }
        item def StatusData {
            attribute statusText : String;
        }
        item def SafetyAlert {
            attribute operatorDistance :> ISQ::length;
            attribute isSafe : Boolean;
        }
        item def PartLocation {
            attribute x :> ISQ::length;
            attribute y :> ISQ::length;
            attribute z :> ISQ::length;
        }

        item def Command;
        item def StartCommand :> Command;
        item def PauseCommand :> Command;
        item def ApproveCommand :> Command;
        item def RejectCommand :> Command;
        item def EmergencyStopCommand :> Command;
        item def ResetCommand :> Command;
        item def PlanComplete;
        item def StepComplete;

        port def CommandPort {
            in item command : Command;
        }
        port def SafetyPort {
            out item alert : SafetyAlert;
        }
        port def VisionPort {
            out item location : PartLocation;
        }
        port def DisplayPort {
            in item status : StatusData;
        }
        port def AudioPort {
            in attribute alertText : String;
        }
        port def LEDPort {
            in attribute ledColor : String;
        }

        part def HumanOperator {
            port commandOut : ~CommandPort;
        }
        part def TouchscreenInterface {
            port commandIn : CommandPort;
            port commandForward : ~CommandPort;
            port displayIn : DisplayPort;
        }
        part def ControlUnit {
            port commandIn : CommandPort;
            port safetyIn : ~SafetyPort;
            port visionIn : ~VisionPort;
            port displayOut : ~DisplayPort;
            port audioOut : ~AudioPort;
            port ledOut : ~LEDPort;
            port armCommandOut : ~CommandPort;
            perform action identifyParts : IdentifyParts;
            perform action executeStep : ExecuteStep;
            perform action requestApproval : RequestApproval;
            perform action haltMotion : HaltMotion;
            exhibit state systemStates : RobotStates;
        }
        part def VisionSystem {
            port visionOut : VisionPort;
            perform action identifyParts : IdentifyParts;
        }
        part def SafetySystem {
            port safetyOut : SafetyPort;
            perform action monitorWorkspace : MonitorWorkspace;
            attribute safeDistanceThreshold :> ISQ::length;
        }
        part def RobotArm {
            port commandIn : CommandPort;
            part gripper : Gripper;
            perform action executeStep : ExecuteStep;
            perform action haltMotion : HaltMotion;
        }
        part def Gripper;
        part def Workstation {
            part fixture : Fixture;
            part storage : Storage;
        }
        part def Fixture;
        part def Storage;
        part def LaserScanner;
        part def ProximitySensor;
        part def RGBDCamera;
        part def AudioAlert {
            port audioIn : AudioPort;
        }
        part def LEDStatusIndicators {
            port ledIn : LEDPort;
        }

        action def IdentifyParts {
            out item location : PartLocation;
        }
        action def ExecuteStep;
        action def RequestApproval;
        action def HaltMotion;
        action def MonitorWorkspace {
            out item alert : SafetyAlert;
        }

        state def RobotStates;

        requirement def SafetyDistanceRequirement {
            doc /* The robot must maintain a safe distance from the human operator. */
            attribute minDistance :> ISQ::length;
        }
        requirement def HumanApprovalRequirement {
            doc /* The robot must pause and await human approval after critical steps. */
        }
        requirement def EmergencyStopResponseRequirement {
            doc /* All robot motion must halt immediately upon an emergency stop command. */
        }
    }

    public import Definitions::*;

    package Usages {
        private import Definitions::*;

        action identifyParts : IdentifyParts;
        action executeStep : ExecuteStep;
        action requestApproval : RequestApproval;
        action haltMotion : HaltMotion;
        action monitorWorkspace : MonitorWorkspace;

        part system {
            part operator : HumanOperator;
            part touchscreen : TouchscreenInterface;
            part controller : ControlUnit;
            part vision : VisionSystem {
                part camera : RGBDCamera;
            }
            part safety : SafetySystem {
                part laser : LaserScanner;
                part proximity : ProximitySensor;
            }
            part robot : RobotArm {
                part gripper : Gripper;
            }
            part workstation : Workstation;
            part audio : AudioAlert;
            part leds : LEDStatusIndicators;
        }

        connect system.operator.commandOut to system.touchscreen.commandIn;
        connect system.touchscreen.commandForward to system.controller.commandIn;
        connect system.controller.displayOut to system.touchscreen.displayIn;
        connect system.vision.visionOut to system.controller.visionIn;
        connect system.safety.safetyOut to system.controller.safetyIn;
        connect system.controller.armCommandOut to system.robot.commandIn;
        connect system.controller.audioOut to system.audio.audioIn;
        connect system.controller.ledOut to system.leds.ledIn;

        state systemStates : RobotStates {
            entry; then idle;

            state idle;
            accept StartCommand then planning;

            state planning {
                entry identifyParts;
            }
            accept PlanComplete then executing;
            accept EmergencyStopCommand then emergencyStop;

            state executing {
                entry executeStep;
            }
            accept StepComplete then awaitingApproval;
            accept EmergencyStopCommand then emergencyStop;

            state awaitingApproval {
                entry requestApproval;
            }
            accept ApproveCommand then executing;
            accept RejectCommand then executing;
            accept EmergencyStopCommand then emergencyStop;

            state emergencyStop {
                entry haltMotion;
            }
            accept ResetCommand then idle;
        }

        requirement safetyDistanceReq : SafetyDistanceRequirement;
        requirement humanApprovalReq : HumanApprovalRequirement;
        requirement eStopReq : EmergencyStopResponseRequirement;

        satisfy safetyDistanceReq by system.safety;
        satisfy humanApprovalReq by system.controller;
        satisfy eStopReq by system.robot;
    }
}
