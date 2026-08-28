package 'ScrewFasteningSystem' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def TorqueValue :> ISQ::TorqueValue;
    attribute def ClampingForceValue :> ISQ::ForceValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def HardnessValue :> Real;

    item def WorkpieceMaterial {
        attribute thickness : LengthValue;
        attribute hardness : HardnessValue;
    }

    port def TorquePort {
        in torque : TorqueValue;
    }
    port def ClampingForcePort {
        out clampingForce : ClampingForceValue;
    }

    action def ApplyTorque {
        in appliedTorque : TorqueValue;
        out transferredTorque : TorqueValue;
    }
    action def ConvertTorqueToForce {
        in inputTorque : TorqueValue;
        out outputForce : ClampingForceValue;
    }
    action def ApplyClampingForce {
        in force : ClampingForceValue;
        out seatedForce : ClampingForceValue;
    }
    action def FastenWorkpieces {
        in appliedTorque : TorqueValue;
        out finalClampingForce : ClampingForceValue;

        action applyTorque : ApplyTorque;
        action convertTorqueToForce : ConvertTorqueToForce;
        action applyClampingForce : ApplyClampingForce;

        flow applyTorque.transferredTorque to convertTorqueToForce.inputTorque;
        flow convertTorqueToForce.outputForce to applyClampingForce.force;
    }

    part def ScrewHead {
        attribute headType : String;
        port torqueInput : TorquePort;
        port torqueOutput : ~TorquePort;
        perform action applyTorque : ApplyTorque {
            in appliedTorque = torqueInput.torque;
            out transferredTorque = torqueOutput.torque;
        }
    }

    part def ThreadedShaft {
        attribute threadPitch : LengthValue;
        attribute threadLength : LengthValue;
        port torqueInput : TorquePort;
        port forceOutput : ClampingForcePort;
        perform action convertTorqueToForce : ConvertTorqueToForce {
            in inputTorque = torqueInput.torque;
            out outputForce = forceOutput.clampingForce;
        }
    }

    part def ScrewTip {
        port forceInput : ~ClampingForcePort;
        port clampingOutput : ClampingForcePort;
        perform action applyClampingForce : ApplyClampingForce {
            in force = forceInput.clampingForce;
            out seatedForce = clampingOutput.clampingForce;
        }
    }

    part def Screw {
        part head : ScrewHead;
        part threadedShaft : ThreadedShaft;
        part tip : ScrewTip;

        connect head.torqueOutput to threadedShaft.torqueInput;
        connect threadedShaft.forceOutput to tip.forceInput;

        port externalTorqueInput : TorquePort;
        connect externalTorqueInput to head.torqueInput;

        port externalClampingOutput : ClampingForcePort;
        connect tip.clampingOutput to externalClampingOutput;

        perform action fastenWorkpieces : FastenWorkpieces {
            in appliedTorque = externalTorqueInput.torque;
            out finalClampingForce = externalClampingOutput.clampingForce;
        }
    }

    part def Workpiece {
        item material : WorkpieceMaterial;
        port forceInput : ~ClampingForcePort;
    }

    part def ScrewFasteningAssembly {
        part screw : Screw;
        part workpiece : Workpiece;
        connect screw.externalClampingOutput to workpiece.forceInput;
    }

    occurrence def TorqueApplied;
    occurrence def ThreadsEngaged;
    occurrence def DesiredForceAchieved;

    state def ScrewFasteningStates;
    state screwFasteningStates : ScrewFasteningStates {
        entry; then idle;
        state idle;
        accept TorqueApplied then engaging;
        state engaging;
        accept ThreadsEngaged then tightening;
        state tightening;
        accept DesiredForceAchieved then seated;
        state seated;
    }

    requirement def SufficientClampingForceRequirement {
        doc /* Reliably and efficiently generate sufficient clamping force to prevent fastened workpieces from separating under operational loads. */
        subject fasteningAssembly : ScrewFasteningAssembly;
        require constraint {
            fasteningAssembly.screw.externalClampingOutput.clampingForce >= 500.0 [N]
        }
    }

    requirement sufficientClampingForce : SufficientClampingForceRequirement;

    part fasteningSystem : ScrewFasteningAssembly {
        part screw : Screw {
            part head : ScrewHead {
                attribute redefines headType = "Phillips";
            }
            part threadedShaft : ThreadedShaft {
                attribute redefines threadPitch = 1.5 [mm];
                attribute redefines threadLength = 25.0 [mm];
            }
            part tip : ScrewTip;
        }
        part workpiece : Workpiece {
            item material : WorkpieceMaterial {
                attribute redefines thickness = 10.0 [mm];
                attribute redefines hardness = 200.0;
            }
        }
        exhibit state fasteningState : ScrewFasteningStates {
            entry; then idle;
            state idle;
            accept TorqueApplied then engaging;
            state engaging;
            accept ThreadsEngaged then tightening;
            state tightening;
            accept DesiredForceAchieved then seated;
            state seated;
        }
    }

    satisfy sufficientClampingForce by fasteningSystem;
}
