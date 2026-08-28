package PenningtonClampModel {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def SoftTissue;

    attribute def HandleSqueeze;
    attribute def RatchetEngage;
    attribute def LockDisengage;
    attribute def JawsFullyOpen;

    port def HandleMechanicalPort {
        out force : ISQ::force;
    }

    port def PivotInputPort {
        in handleForce : ISQ::force;
    }

    port def PivotOutputPort {
        out jawForce : ISQ::force;
    }

    port def JawMechanicalPort {
        in jawForce : ISQ::force;
    }

    port def TissueInterfacePort {
        out grip : ISQ::pressure;
        in item tissue : SoftTissue;
    }

    port def RatchetControlPort {
        in engage : RatchetEngage;
        in disengage : LockDisengage;
    }

    part def Handle {
        port mechanicalPort : HandleMechanicalPort;
    }

    part def PivotJoint {
        attribute mechanicalAdvantage : Real = 3.0;
        port inputPort : PivotInputPort;
        port outputPort : PivotOutputPort;
    }

    part def Jaw {
        attribute gripPressure : ISQ::pressure;
        attribute serrationCount : Integer = 12;
        port mechanicalPort : JawMechanicalPort;
        port tissuePort : TissueInterfacePort;
    }

    part def RatchetLock {
        attribute engaged : Boolean = false;
        attribute toothCount : Integer = 8;
        port controlPort : RatchetControlPort;
    }

    state def ClampOperation {
        entry; then open;
        state open;
        accept HandleSqueeze then closing;
        state closing;
        accept RatchetEngage then locked;
        state locked;
        accept LockDisengage then opening;
        state opening;
        accept JawsFullyOpen then open;
    }

    part def PenningtonClamp {
        part leftHandle : Handle;
        part rightHandle : Handle;
        part pivot : PivotJoint;
        part upperJaw : Jaw;
        part lowerJaw : Jaw;
        part ratchet : RatchetLock;

        interface leftHandleToPivot connect leftHandle.mechanicalPort to pivot.inputPort {
            flow forceFlow of ISQ::force from leftHandle.mechanicalPort.force to pivot.inputPort.handleForce;
        }
        interface rightHandleToPivot connect rightHandle.mechanicalPort to pivot.inputPort {
            flow forceFlow of ISQ::force from rightHandle.mechanicalPort.force to pivot.inputPort.handleForce;
        }
        interface pivotToUpperJaw connect pivot.outputPort to upperJaw.mechanicalPort {
            flow jawForceFlow of ISQ::force from pivot.outputPort.jawForce to upperJaw.mechanicalPort.jawForce;
        }
        interface pivotToLowerJaw connect pivot.outputPort to lowerJaw.mechanicalPort {
            flow jawForceFlow of ISQ::force from pivot.outputPort.jawForce to lowerJaw.mechanicalPort.jawForce;
        }

        state machine clampOperation : ClampOperation;
    }

    requirement def AtraumaticGripRequirement {
        doc /* The clamp must atraumatically grasp, hold, and manipulate soft tissue. */
        subject clamp : PenningtonClamp;
        requirement {
            subject jaw : Jaw;
            constraint { jaw.gripPressure <= 50000 [Pa] }
        }
    }

    requirement def SecureHoldRequirement {
        doc /* The clamp must maintain a constant, secure grip without continuous applied force. */
        subject clamp : PenningtonClamp;
        requirement {
            subject ratchet : RatchetLock;
            constraint { ratchet.engaged == true }
        }
    }
}
