package CarpujectMedicationDeliverySystem {

import ScalarValues::*;

// ==================== Value Types ====================

value type ForceValue :> Real {
    doc /* Force measured in Newtons (N) */;
}

value type VolumeValue :> Real {
    doc /* Volume measured in milliliters (mL) */;
}

value type FlowRateValue :> Real {
    doc /* Volumetric flow rate in milliliters per second (mL/s) */;
}

value type PressureValue :> Real {
    doc /* Pressure measured in bar */;
}

value type LengthValue :> Real {
    doc /* Length measured in millimeters (mm) */;
}

value type MassValue :> Real {
    doc /* Mass measured in milligrams (mg) */;
}

value type ConcentrationValue :> Real {
    doc /* Concentration measured in milligrams per milliliter (mg/mL) */;
}

// ==================== Item Definitions ====================

item def Medication {
    attribute drugName : String;
    attribute concentration : ConcentrationValue;
    attribute volume : VolumeValue;
    attribute mass : MassValue;
    attribute isSterile : Boolean = true;
}

item def AirBubble {
    attribute volume : VolumeValue;
}

// ==================== Port Definitions ====================

port def MechanicalPort {
    attribute appliedForce : ForceValue;
    attribute isEngaged : Boolean;
}

port def FluidPort {
    attribute flowRate : FlowRateValue;
    attribute pressure : PressureValue;
    attribute isSterile : Boolean;
}

// ==================== Action Definitions ====================

action def UnlockSafety {
    doc /* Deliberate user action to unlock the safety mechanism */;
    in appliedForce : ForceValue;
}

action def PrimeNeedle {
    doc /* Remove air from the needle before injection */;
    in airVolume : VolumeValue;
    out expelledAir : AirBubble;
}

action def TriggerActivation {
    doc /* Press the trigger to start injection with required force */;
    in appliedForce : ForceValue;
    out activated : Boolean;
}

action def AdvancePlungerAction {
    doc /* Advance plunger to expel medication at controlled rate and pressure */;
    in flowRate : FlowRateValue;
    in maxPressure : PressureValue;
    out expelledVolume : VolumeValue;
}

action def AssembleDevice {
    doc /* Insert cartridge into barrel holder and attach sterile needle assembly */;
    out assembled : Boolean;
}

action def DisposeDevice {
    doc /* Safely dispose of used device after injection complete */;
}

// ==================== Part Definitions ====================

part def BarrelHolder {
    doc /* Reusable barrel holder that houses the disposable pre-filled cartridge */;
    attribute isReusable : Boolean = true;
    attribute material : String = "polypropylene";
    attribute isSterile : Boolean = false;

    port cartridgeHousingPort : MechanicalPort;
    port triggerMountPort : MechanicalPort;
}

part def RubberPlunger {
    doc /* Rubber plunger that seals the medication inside the glass cartridge */;
    attribute position : LengthValue = 0.0;
    attribute maxPosition : LengthValue;
    attribute sealIntegrity : Boolean = true;
    attribute isAdvanced : Boolean = false;

    port driveInterface : MechanicalPort;

    action advance {
        doc /* Advance plunger by specified distance */;
        in distance : LengthValue;
    }

    action resetPosition {
        doc /* Reset plunger to initial position */;
    }
}

part def MedicationCartridge {
    doc /* Disposable, pre-filled, sterile glass cartridge containing medication */;
    attribute isDisposable : Boolean = true;
    attribute isSterile : Boolean = true;
    attribute material : String = "glass";
    attribute capacity : VolumeValue;
    attribute currentVolume : VolumeValue;
    attribute isEmpty : Boolean = false;

    port holderInterface : MechanicalPort;
    port plungerInterface : MechanicalPort;
    port needleInterface : FluidPort;

    part plunger : RubberPlunger;
    item medication : Medication;

    action checkEmpty {
        doc /* Check if cartridge is empty after plunger fully advanced */;
        out empty : Boolean;
    }

    action sealCheck {
        doc /* Verify plunger seal integrity before use */;
        out sealIntact : Boolean;
    }
}

part def NeedleAssembly {
    doc /* Sterile, single-use needle assembly for medication delivery to patient */;
    attribute isSterile : Boolean = true;
    attribute isSingleUse : Boolean = true;
    attribute isAttached : Boolean = false;
    attribute isCapped : Boolean = true;
    attribute isPrimed : Boolean = false;
    attribute gauge : Real;
    attribute needleLength : LengthValue;
    attribute lumenDiameter : LengthValue;

    port cartridgeInterface : FluidPort;
    port patientInterface : FluidPort;

    action attach {
        doc /* Attach needle assembly to cartridge fluid port */;
        out attached : Boolean;
    }

    action removeCap {
        doc /* Remove sterile protective cap before use */;
        out capRemoved : Boolean;
    }

    action primeNeedle {
        doc /* Expel air from needle lumen to ensure medication path is primed */;
        in airVolume : VolumeValue;
        out expelledAir : AirBubble;
        out primed : Boolean;
    }
}

part def SafetyMechanism {
    doc /* Safety mechanism initially locked and engaged to prevent accidental activation */;
    attribute isLocked : Boolean = true;
    attribute isEngaged : Boolean = true;
    attribute lockType : String = "mechanical";

    port controlPort : MechanicalPort;
    port triggerLockPort : MechanicalPort;

    action unlock {
        doc /* Unlock the safety with deliberate user action */;
        in unlockingForce : ForceValue;
        out unlocked : Boolean;
    }

    action engage {
        doc /* Re-engage safety lock */;
        out engaged : Boolean;
    }
}

part def ActivationTrigger {
    doc /* Trigger requiring specific minimum force to operate, preventing accidental discharge */;
    attribute isActivated : Boolean = false;
    attribute appliedForce : ForceValue;
    attribute requiredForce : ForceValue;
    attribute triggerTravelDistance : LengthValue;

    port actuationPort : MechanicalPort;
    port safetyLockPort : MechanicalPort;

    action activate {
        doc /* Activate trigger when applied force exceeds required threshold */;
        in force : ForceValue;
        in threshold : ForceValue;
        out activated : Boolean;
    }

    action reset {
        doc /* Reset trigger to unactivated state */;
        out resetComplete : Boolean;
    }
}

part def PlungerDriveMechanism {
    doc /* Mechanism that advances the plunger at controlled flow rate and pressure */;
    attribute driveForce : ForceValue;
    attribute currentFlowRate : FlowRateValue;
    attribute currentPressure : PressureValue;
    attribute maxPressure : PressureValue;
    attribute isAdvancing : Boolean = false;
    attribute totalExpelled : VolumeValue = 0.0;

    port inputPort : MechanicalPort;
    port plungerPort : MechanicalPort;

    action advance {
        doc /* Advance plunger at controlled flow rate, monitoring pressure */;
        in flowRate : FlowRateValue;
        in maxPressure : PressureValue;
        out expelledVolume : VolumeValue;
    }

    action stop {
        doc /* Stop plunger advancement */;
        out stopped : Boolean;
    }

    action monitorPressure {
        doc /* Continuously monitor injection pressure to ensure it remains within limits */;
        in currentPressure : PressureValue;
        in maxPressure : PressureValue;
        out pressureOK : Boolean;
    }
}

// ==================== Main System Part ====================

part def CarpujectSystem {
    doc /* Carpuject medication delivery system for rapid, safe, sterile single-use injections in clinical settings */;

    // External ports
    port userActivationPort : MechanicalPort;
    port userSafetyPort : MechanicalPort;
    port patientDeliveryPort : FluidPort;

    // Configuration attributes
    attribute minTriggerForce : ForceValue = 10.0;
    attribute maxInjectionPressure : PressureValue = 5.0;
    attribute nominalFlowRate : FlowRateValue = 1.0;
    attribute cartridgeCapacity : VolumeValue = 5.0;
    attribute systemName : String = "Carpuject";

    // State attributes
    attribute remainingVolume : VolumeValue;
    attribute isAssembled : Boolean = false;
    attribute isPrimed : Boolean = false;
    attribute totalDelivered : VolumeValue = 0.0;

    // Parts
    part barrelHolder : BarrelHolder;
    part cartridge : MedicationCartridge;
    part needleAssembly : NeedleAssembly;
    part safetyMechanism : SafetyMechanism;
    part trigger : ActivationTrigger;
    part plungerDrive : PlungerDriveMechanism;

    // Connections
    connect barrelHolder.cartridgeHousingPort to cartridge.holderInterface;
    connect cartridge.plungerInterface to plungerDrive.plungerPort;
    connect cartridge.needleInterface to needleAssembly.cartridgeInterface;
    connect needleAssembly.patientInterface to patientDeliveryPort;
    connect safetyMechanism.triggerLockPort to trigger.safetyLockPort;
    connect trigger.actuationPort to plungerDrive.inputPort;
    connect userActivationPort to trigger.actuationPort;
    connect userSafetyPort to safetyMechanism.controlPort;
    connect barrelHolder.triggerMountPort to trigger.actuationPort;

    // Lifecycle state machine
    state machine injectionLifecycle {
        doc /* Device lifecycle from secured state through safe disposal */;

        state secured {
            doc /* Initial state with safety locked and engaged, preventing accidental activation */;
        }

        state ready {
            doc /* Safety unlocked, needle attached, device ready for priming */;
        }

        state primed {
            doc /* Air removed from needle, medication path established, ready for injection */;
        }

        state injecting {
            doc /* Plunger advancing, expelling medication at controlled flow rate and pressure */;
        }

        state complete {
            doc /* Injection complete, cartridge empty, ready for safe disposal */;
        }

        // Transitions
        transition secured to ready when safetyMechanism.isLocked == false {
            doc /* User performs deliberate action to unlock safety mechanism */;
        }

        transition ready to primed when isPrimed == true {
            doc /* Needle primed to remove any air from the medication path */;
        }

        transition primed to injecting when trigger.isActivated == true {
            doc /* Trigger activated with sufficient force, injection begins */;
        }

        transition injecting to complete when cartridge.isEmpty == true {
            doc /* Cartridge empty, injection complete, transition to disposal-ready state */;
        }
    }

    // System actions
    action assemble : AssembleDevice {
        doc /* Assemble device by inserting pre-filled cartridge into barrel holder and attaching sterile needle */;
    }

    action unlock : UnlockSafety {
        doc /* Unlock safety mechanism with deliberate user action */;
    }

    action prime : PrimeNeedle {
        doc /* Prime needle to remove air before injection */;
    }

    action inject : AdvancePlungerAction {
        doc /* Inject medication at controlled flow rate and pressure until cartridge empty */;
    }

    action dispose : DisposeDevice {
        doc /* Safely dispose of used single-use components after injection complete */;
    }
}

// ==================== Requirements ====================

requirement def SterilityRequirement {
    doc /* The medication path shall remain sterile until the point of use */;
    subject device : CarpujectSystem;
    assert device.cartridge.isSterile == true;
    assert device.needleAssembly.isSterile == true;
}

requirement def SafetyLockRequirement {
    doc /* The safety mechanism shall be initially locked and engaged, preventing accidental activation */;
    subject device : CarpujectSystem;
    assert device.safetyMechanism.isLocked == true;
    assert device.safetyMechanism.isEngaged == true;
}

requirement def SafetyUnlockRequirement {
    doc /* A user shall perform a deliberate action to unlock the safety mechanism before injection can proceed */;
    subject device : CarpujectSystem;
    assert device.safetyMechanism.isLocked == false;
}

requirement def TriggerForceRequirement {
    doc /* The activation trigger shall require a specific minimum force to operate, preventing accidental discharge */;
    subject device : CarpujectSystem;
    assert device.trigger.requiredForce >= device.minTriggerForce;
}

requirement def ControlledDeliveryRequirement {
    doc /* Medication shall be expelled at a controlled flow rate and pressure during injection */;
    subject device : CarpujectSystem;
    assert device.plungerDrive.currentPressure <= device.maxInjectionPressure;
    assert device.plungerDrive.currentFlowRate == device.nominalFlowRate;
}

requirement def SingleUseRequirement {
    doc /* The cartridge and needle assembly shall be single-use and disposable */;
    subject device : CarpujectSystem;
    assert device.cartridge.isDisposable == true;
    assert device.needleAssembly.isSingleUse == true;
}

requirement def ReusableHolderRequirement {
    doc /* The barrel holder shall be reusable across multiple cartridge insertions */;
    subject device : CarpujectSystem;
    assert device.barrelHolder.isReusable == true;
}

requirement def PrimingRequirement {
    doc /* The system shall be primed to remove air from the needle before injection begins */;
    subject device : CarpujectSystem;
    assert device.isPrimed == true;
}

requirement def EmptyCartridgeRequirement {
    doc /* The injection shall continue until the cartridge is empty, then transition to complete state */;
    subject device : CarpujectSystem;
    assert device.cartridge.isEmpty == true;
}

requirement def RapidDeliveryRequirement {
    doc /* The system shall be designed for rapid medication delivery with minimal preparation */;
    subject device : CarpujectSystem;
    assert device.nominalFlowRate >= 0.5;
}

requirement def CartridgeSealRequirement {
    doc /* The rubber plunger shall maintain seal integrity throughout the injection process */;
    subject device : CarpujectSystem;
    assert device.cartridge.plunger.sealIntegrity == true;
}

requirement def PressureLimitRequirement {
    doc /* The system shall not exceed the maximum injection pressure during delivery */;
    subject device : CarpujectSystem;
    assert device.plungerDrive.maxPressure <= device.maxInjectionPressure;
}

} // end package CarpujectMedicationDeliverySystem
