package PenningtonClampModel {

    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value types with units ----------
    value def Force :> Real { unit 'N'; }
    value def Pressure :> Real { unit 'kPa'; }
    value def Angle :> Real { unit 'deg'; }
    value def Length :> Real {> Real { unit 'mm'; }
    value def ToothCount :> Integer;
    value def ForceRatio :> Real;

    // ---------- Item types ----------
    item def SoftTissue {
        attribute compressiveStrength : Pressure;
        attribute thickness : Length;
    }

    // ---------- Interfaces ----------
    interface def HandForceInterface {
        in force : Force;
    }

    interface def JawTissueInterface {
        in clampingForce : Force;
        in contactPressure : Pressure;
        inout tissue : SoftTissue;
    }

    interface def MechanicalLinkInterface {
        in transmittedForce : Force;
        in position : Angle;
    }

    interface def RatchetLockInterface {
        in engagement : Boolean;
        in toothIndex : ToothCount;
    }

    // ---------- Parts ----------
    part def Handle {
        port handInput : HandForceInterface;
        port linkOutput : MechanicalLinkInterface;
        attribute length : Length = 120 [mm];
        attribute gripTexture : String = "knurled";
        attribute appliedForce : Force;
        attribute deflection : Angle;

        action applyHandForce {
            in force : Force;
            out deflectionOut : Angle;
        }
    }

    part def PivotJoint {
        port leftLink : MechanicalLinkInterface;
        port rightLink : MechanicalLinkInterface;
        port jawLinkLeft : MechanicalLinkInterface;
        port jawLinkRight : MechanicalLinkInterface;
        attribute mechanicalAdvantage : ForceRatio = 3.0;
        attribute pivotAngle : Angle;

        action transmitForce {
            in inputForce : Force;
            out outputForce : Force;
        }
    }

    part def Jaw {
        port tissueContact : JawTissueInterface;
        port pivotInput : MechanicalLinkInterface;
        attribute length : Length = 60 [mm];
        attribute serrationPitch : Length = 1.2 [mm];
        attribute serrationDepth : Length = 0.5 [mm];
        attribute contactArea : Length = 40 [mm];
        attribute clampingForce : Force;
        attribute contactPressure : Pressure;

        action gripTissue {
            in tissue : SoftTissue;
            in force : Force;
            out pressure : Pressure;
        }
    }

    part def RatchetLock {
        port lockInterface : RatchetLockInterface;
        attribute toothCount : ToothCount = 8;
        attribute currentTooth : ToothCount;
        attribute engaged : Boolean = false;
        attribute lockForce : Force;

        action engage {
            in handlePosition : Angle;
            out toothIndex : ToothCount;
            out locked : Boolean;
        }

        action disengage {
            out released : Boolean;
        }
    }

    part def ReturnSpring {
        attribute stiffness : Real = 2.5; // N/mm
        attribute freeLength : Length = 15 [mm];
        action openJaws {
            out restoringForce : Force;
        }
    }

    // ---------- Pennington Clamp assembly ----------
    part def PenningtonClamp {
        part leftHandle : Handle;
        part rightHandle : Handle;
        part pivot : PivotJoint;
        part leftJaw : Jaw;
        part rightJaw : Jaw;
        part ratchet : RatchetLock;
        part spring : ReturnSpring;

        attribute totalLength : Length = 180 [mm];
        attribute jawOpeningAngle : Angle = 30 [deg];
        attribute maxClampingForce : Force = 25 [N];
        attribute maxContactPressure : Pressure = 30 [kPa];

        // Connections
        connection leftHandle.linkOutput to pivot.leftLink;
        connection rightHandle.linkOutput to pivot.rightLink;
        connection pivot.jawLinkLeft to leftJaw.pivotInput;
        connection pivot.jawLinkRight to rightJaw.pivotInput;
        connection leftJaw.tissueContact to rightJaw.tissueContact;
        connection ratchet.lockInterface to pivot.leftLink;

        // State machine behavior
        state def ClampOperation {
            entry; then Open;

            state Open {
                entry action {
                    // Jaws fully open, ready for positioning
                }
                do action positionClamp;
                transition Open to Closing
                    when leftHandle.appliedForce > 0 [N]
                    accept Handle.applyHandForce;
            }

            state Closing {
                entry action {
                    // Handles being squeezed, jaws approaching tissue
                }
                do action closeJaws;
                transition Closing to Locked
                    when ratchet.engaged == true
                    accept RatchetLock.engage;
                transition Closing to Open
                    when leftHandle.appliedForce == 0 [N]
                    accept ReturnSpring.openJaws;
            }

            state Locked {
                entry action {
                    // Ratchet engaged, constant grip maintained
                }
                do action maintainGrip;
                transition Locked to Open
                    when ratchet.engaged == false
                    accept RatchetLock.disengage;
            }
        }

        // Actions
        action def positionClamp {
            in clamp : PenningtonClamp;
            out positioned : Boolean;
        }

        action def closeJaws {
            in handles : Handle[2];
            in pivot : PivotJoint;
            out jawsClosed : Boolean;
        }

        action def maintainGrip {
            in ratchet : RatchetLock;
            in jaws : Jaw[2];
            out gripMaintained : Boolean;
        }

        exhibit state behavior ClampOperation;
    }

    // ---------- Requirements ----------
    requirement def AtraumaticGripRequirement {
        subject clamp : PenningtonClamp;
        requirement {
            doc /* The clamp shall grasp soft tissue without causing tissue damage. */
            constraint clamp.maxContactPressure <= 30 [kPa];
        }
    }

    requirement def SecureHoldRequirement {
        subject clamp : PenningtonClamp;
        requirement {
            doc /* The clamp shall maintain a secure grip without slippage. */
            constraint clamp.maxClampingForce >= 15 [N];
        }
    }

    requirement def RatchetLockRequirement {
        subject ratchet : RatchetLock;
        requirement {
            doc /* The ratchet shall automatically engage when jaws close and maintain lock until manually disengaged. */
            constraint ratchet.toothCount >= 5;
        }
    }

    requirement def MechanicalAdvantageRequirement {
        subject pivot : PivotJoint;
        requirement {
            doc /* The pivot shall multiply input hand force to achieve required clamping force. */
            constraint pivot.mechanicalAdvantage >= 2.5;
        }
    }

    requirement def ErgonomicHandleRequirement {
        subject handle : Handle;
        requirement {
            doc /* Handles shall be ergonomic and operable by single hand. */
            constraint handle.length >= 100 [mm];
        }
    }

    requirement def SerrationRequirement {
        subject jaw : Jaw;
        requirement {
            doc /* Jaws shall have serrated surfaces to prevent tissue slippage. */
            constraint jaw.serrationDepth >= 0.3 [mm];
            constraint jaw.serrationPitch <= 2.0 [mm];
        }
    }

    // ---------- Requirement satisfaction ----------
    satisfaction AtraumaticGripRequirement by PenningtonClamp;
    satisfaction SecureHoldRequirement by PenningtonClamp;
    satisfaction RatchetLockRequirement by PenningtonClamp.ratchet;
    satisfaction MechanicalAdvantageRequirement by PenningtonClamp.pivot;
    satisfaction ErgonomicHandleRequirement by PenningtonClamp.leftHandle;
    satisfaction ErgonomicHandleRequirement by PenningtonClamp.rightHandle;
    satisfaction SerrationRequirement by PenningtonClamp.leftJaw;
    satisfaction SerrationRequirement by PenningtonClamp.rightJaw;

}
