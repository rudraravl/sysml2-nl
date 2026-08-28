package LiftChairSystem {
    private import ScalarValues::*;

    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        attribute def MassValue :> Real;
        attribute def ForceValue :> Real;
        attribute def AngleValue :> Real;
        attribute def TimeValue :> Real;
        attribute def VoltageValue :> Real;
        attribute def CurrentValue :> Real;

        attribute def RaiseCommand;
        attribute def LowerCommand;
        attribute def StopCommand;
        attribute def EmergencyStopCommand;

        action def ConvertPower;
        action def Extend;
        action def Retract;
        action def Halt;
        action def MonitorLoad;
        action def SendRaise;
        action def SendLower;
        action def SendStop;

        part def SeatFrame {
            attribute maxWeight : MassValue = 136;
            attribute currentAngle : AngleValue;
            attribute maxAngle : AngleValue = 45;
            attribute minAngle : AngleValue = 0;
        }

        part def PowerSupply {
            port acInput {
                in attribute voltage : VoltageValue;
            }
            port dcOutput {
                out attribute voltage : VoltageValue;
                out attribute current : CurrentValue;
            }
            perform action convertPower : ConvertPower;
        }

        part def HandControl {
            port commandPort {
                out attribute command;
            }
            perform action sendRaise : SendRaise;
            perform action sendLower : SendLower;
            perform action sendStop : SendStop;
        }

        part def LinearActuator {
            port commandPort {
                in attribute command;
            }
            port safetyPort {
                in attribute override : EmergencyStopCommand;
            }
            port powerPort {
                in attribute voltage : VoltageValue;
                in attribute current : CurrentValue;
            }
            port feedbackPort {
                out attribute load : ForceValue;
                out attribute angle : AngleValue;
            }
            attribute maxAngle : AngleValue = 45;
            attribute minAngle : AngleValue = 0;
            perform action extend : Extend;
            perform action retract : Retract;
            perform action halt : Halt;
        }

        part def SafetyController {
            attribute loadThreshold : ForceValue = 1334;
            port monitorPort {
                in attribute load : ForceValue;
                in attribute angle : AngleValue;
            }
            port overridePort {
                out attribute override : EmergencyStopCommand;
            }
            perform action monitorLoad : MonitorLoad;
        }

        requirement def SupportCapacity {
            doc /* The system shall safely support a person weighing up to 136 kg. */
            attribute maxSupportedWeight : MassValue = 136;
        }

        requirement def LiftCycleTime {
            doc /* The system shall complete a full lift cycle in under 10 seconds. */
            attribute maxCycleTime : TimeValue = 10;
        }

        requirement def SafetyOverride {
            doc /* The safety controller shall stop all movement when the load exceeds the safety threshold. */
            attribute threshold : ForceValue = 1334;
        }

        part def LiftChair {
            part seatFrame : SeatFrame;
            part actuator : LinearActuator;
            part powerSupply : PowerSupply;
            part handControl : HandControl;
            part safetyController : SafetyController;

            connect powerSupply.dcOutput to actuator.powerPort;
            connect handControl.commandPort to actuator.commandPort;
            connect actuator.feedbackPort to safetyController.monitorPort;
            connect safetyController.overridePort to actuator.safetyPort;

            exhibit state chairStates {
                entry; then seated;
                state seated;
                accept RaiseCommand then lifting;
                state lifting;
                accept when actuator.feedbackPort.angle >= actuator.maxAngle then standing;
                accept StopCommand then stopped;
                accept EmergencyStopCommand then stopped;
                state standing;
                accept LowerCommand then lowering;
                state lowering;
                accept when actuator.feedbackPort.angle <= actuator.minAngle then seated;
                accept StopCommand then stopped;
                accept EmergencyStopCommand then stopped;
                state stopped;
                accept RaiseCommand then lifting;
                accept LowerCommand then lowering;
            }

            satisfy SupportCapacity;
            satisfy LiftCycleTime;
            satisfy SafetyOverride;
        }
    }

    package Usages {
        private import Definitions::*;

        part liftChair : LiftChair;
    }
}
