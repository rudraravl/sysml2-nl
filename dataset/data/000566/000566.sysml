package CarpujectMedicationDeliverySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MedicationDose {
        attribute volume :> ISQ::VolumeValue;
        attribute concentration : Real;
        attribute drugName : String;
    }
    
    attribute def InjectionPressure :> ISQ::PressureValue;
    attribute def ActivationForce :> ISQ::ForceValue;
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    
    item def Medication {
        attribute dose : MedicationDose;
        attribute lotNumber : String;
        attribute expirationDate : String;
        attribute isExpired : Boolean;
    }
    
    port def MedicationFlowPort {
        out item medication : Medication;
        out attribute flowRate : FlowRate;
    }
    
    port def PatientDeliveryPort {
        in item medication : Medication;
        in attribute deliveryPressure : InjectionPressure;
    }
    
    port def ActivationPort {
        in attribute appliedForce : ActivationForce;
        out attribute isActivated : Boolean;
    }
    
    part def SterileCartridge {
        doc /* Pre-filled, sterile glass cartridge containing medication */
        attribute capacity :> ISQ::VolumeValue;
        attribute currentVolume :> ISQ::VolumeValue;
        attribute isSterile : Boolean;
        port medicationOutput : MedicationFlowPort;
        
        assert constraint volumeConstraint {
            currentVolume >= 0.0 and currentVolume <= capacity
        }
    }
    
    part def Plunger {
        doc /* Rubber plunger that seals cartridge and expels medication */
        attribute position :> ISQ::LengthValue;
        attribute maxTravel :> ISQ::LengthValue;
        attribute velocity :> ISQ::SpeedValue;
        
        assert constraint positionLimit {
            position >= 0.0 and position <= maxTravel
        }
    }
    
    part def NeedleAssembly {
        doc /* Sterile needle assembly for patient injection */
        attribute needleGauge : Integer;
        attribute needleLength :> ISQ::LengthValue;
        attribute isSterile : Boolean;
        port deliveryPort : PatientDeliveryPort;
    }
    
    part def BarrelHolder {
        doc /* Reusable holder that secures cartridge and applies force */
        part cartridge : SterileCartridge {
            attribute capacity = 2.5;
            attribute isSterile = true;
        }
        part plunger : Plunger {
            attribute maxTravel = 50.0;
        }
        
        connect plunger to cartridge;
    }
    
    part def SafetyMechanism {
        doc /* Safety lock preventing accidental activation */
        attribute isLocked : Boolean;
        attribute isEngaged : Boolean;
        attribute requiresDeliberate : Boolean;
    }
    
    part def ActivationTrigger {
        doc /* Mechanism for controlled activation of injection */
        attribute requiredForce :> ISQ::ForceValue;
        attribute isPressed : Boolean;
        port activationPort : ActivationPort;
    }
    
    attribute def UnlockEvent;
    attribute def PrimeEvent;
    attribute def ActivateEvent;
    attribute def DisposeEvent;
    
    state def CarpujectOperationalStates {
        in safetyRef : SafetyMechanism;
        in triggerRef : ActivationTrigger;
        in barrelRef : BarrelHolder;
        
        entry; then secured;
        
        state secured {
            doc /* Initial state with safety engaged */
            entry assign safetyRef.isLocked := true;
            entry assign safetyRef.isEngaged := true;
        }
        
        transition secured_to_ready
            first secured
            accept unlockSignal : UnlockEvent
            if safetyRef.isLocked == true
            then ready;
        
        state ready {
            doc /* Safety unlocked, ready for activation */
            entry assign safetyRef.isLocked := false;
        }
        
        transition ready_to_primed
            first ready
            accept primeSignal : PrimeEvent
            then primed;
        
        state primed {
            doc /* System primed and ready to inject */
        }
        
        transition primed_to_injecting
            first primed
            accept activateSignal : ActivateEvent
            if triggerRef.isPressed == true
            then injecting;
        
        state injecting {
            doc /* Active medication delivery in progress */
            entry assign triggerRef.isPressed := true;
        }
        
        transition injecting_to_complete
            first injecting
            if barrelRef.cartridge.currentVolume <= 0.0
            then complete;
        
        state complete {
            doc /* Injection complete, ready for disposal */
            entry assign safetyRef.isEngaged := true;
            entry assign triggerRef.isPressed := false;
        }
        
        transition complete_to_disposed
            first complete
            accept disposeSignal : DisposeEvent
            then disposed;
        
        state disposed {
            doc /* System disposed, end of lifecycle */
        }
    }
    
    action def UnlockSafety {
        in safetyMech : SafetyMechanism;
        out unlockedSafety : SafetyMechanism;
        doc /* Disengage safety lock to prepare for use */
    }
    
    action def PrimeSystem {
        in barrel : BarrelHolder;
        in needle : NeedleAssembly;
        out isPrimed : Boolean;
        doc /* Remove air and prepare fluid path */
    }
    
    action def ActivateInjection {
        in trigger : ActivationTrigger;
        in appliedForce : ActivationForce;
        out isActivated : Boolean;
        doc /* Initiate controlled injection sequence */
    }
    
    action def AdvancePlunger {
        in plunger : Plunger;
        in targetVelocity :> ISQ::SpeedValue;
        in distance :> ISQ::LengthValue;
        out newPosition :> ISQ::LengthValue;
        doc /* Move plunger to expel medication */
    }
    
    action def ExpelMedication {
        in cartridge : SterileCartridge;
        in targetFlowRate : FlowRate;
        in duration :> ISQ::TimeValue;
        out deliveredVolume :> ISQ::VolumeValue;
        out remainingVolume :> ISQ::VolumeValue;
        doc /* Expel medication at controlled rate */
    }
    
    action def MonitorPressure {
        in deliveryPressure : InjectionPressure;
        in maxPressure : InjectionPressure;
        out isSafe : Boolean;
        doc /* Monitor injection pressure for safety */
    }
    
    action def DeliverMedicationDose {
        doc /* Primary function: deliver precise medication dose to patient */
        in attribute targetDose : MedicationDose;
        in attribute maxPressure : InjectionPressure;
        in attribute injectionDuration :> ISQ::TimeValue;
        out attribute actualDeliveredVolume :> ISQ::VolumeValue;
        out attribute deliverySuccess : Boolean;
        
        first start;
        then action unlock : UnlockSafety;
        then action prime : PrimeSystem {
            out isPrimed;
        }
        then decide;
            if prime.isPrimed == true then activate;
            if prime.isPrimed == false then abortDelivery;
        action activate : ActivateInjection {
            out isActivated;
        }
        then action advance : AdvancePlunger;
        then merge deliveryLoop;
        action deliveryLoop {
            action expel : ExpelMedication {
                out deliveredVolume;
                out remainingVolume;
            }
            then action monitor : MonitorPressure {
                out isSafe;
            }
            then decide;
                if monitor.isSafe == true and expel.remainingVolume > 0.0 
                    then deliveryLoop;
                if monitor.isSafe == false then abortDelivery;
                if expel.remainingVolume <= 0.0 then completeDelivery;
        }
        action completeDelivery {
            then assign deliverySuccess := true;
        }
        then done;
        action abortDelivery {
            then assign deliverySuccess := false;
        }
        then done;
    }
    
    part def Carpuject {
        doc /* 
            A Carpuject is a sterile, pre-filled medication delivery system 
            combining a glass cartridge with an integrated needle assembly, 
            designed for rapid, accurate injection of precise medication doses 
            in clinical settings. The system ensures sterility, dosage accuracy, 
            and safe single-use operation through integrated safety mechanisms.
        */
        
        part barrel : BarrelHolder;
        part needle : NeedleAssembly {
            attribute needleGauge = 21;
            attribute needleLength = 25.0;
            attribute isSterile = true;
        }
        part safety : SafetyMechanism {
            attribute isLocked = true;
            attribute isEngaged = true;
            attribute requiresDeliberate = true;
        }
        part trigger : ActivationTrigger {
            attribute requiredForce = 20.0;
            attribute isPressed = false;
        }
        
        connect barrel.cartridge.medicationOutput to needle.deliveryPort;
        
        perform action primaryFunction : DeliverMedicationDose[*] ordered {
            doc /* Execute controlled medication delivery */
        }
        
        exhibit state operationalBehavior : CarpujectOperationalStates {
            in safetyRef = safety;
            in triggerRef = trigger;
            in barrelRef = barrel;
        }
    }
    
    part carpujectSystem : Carpuject {
        doc /* 
            The Carpuject system provides rapid, sterile delivery of pre-measured 
            medication doses through an integrated cartridge-needle assembly. 
            Its primary function is to enable healthcare providers to safely 
            administer precise medication volumes with minimal preparation time, 
            while maintaining sterility and preventing medication errors through 
            pre-filled, single-use design with integrated safety features.
        */
        
        perform action deliverDose : DeliverMedicationDose {
            in attribute targetDose : MedicationDose {
                attribute volume = 2.0;
                attribute concentration = 10.0;
                attribute drugName = "Example Medication";
            }
            in attribute maxPressure = 300.0;
            in attribute injectionDuration = 3.0;
            out attribute actualDeliveredVolume;
            out attribute deliverySuccess;
        }
    }
    
    requirement def SafetyRequirement {
        doc /* Safety requirements for Carpuject operation */
        subject carpuject : Carpuject;
        
        require constraint safetyLockRequired {
            doc /* Safety lock must prevent accidental activation */
            carpuject.safety.isLocked == true or 
            carpuject.safety.isEngaged == true
        }
        
        require constraint deliberateActivation {
            doc /* Activation must require deliberate force application */
            carpuject.safety.requiresDeliberate == true
        }
    }
    
    requirement def DosageAccuracyRequirement {
        doc /* Dosage delivery accuracy requirement */
        subject carpuject : Carpuject;
        attribute tolerance : Real = 0.05;
        
        require constraint accuracyTolerance {
            doc /* Delivered dose must be within 5% of target dose */
            (carpuject.primaryFunction.actualDeliveredVolume - 
                carpuject.primaryFunction.targetDose.volume) <= 
                tolerance * carpuject.primaryFunction.targetDose.volume and
            (carpuject.primaryFunction.targetDose.volume -
                carpuject.primaryFunction.actualDeliveredVolume) <=
                tolerance * carpuject.primaryFunction.targetDose.volume
        }
    }
    
    requirement def SterilityRequirement {
        doc /* Sterility maintenance requirement */
        subject carpuject : Carpuject;
        
        require constraint maintainSterility {
            doc /* System must maintain sterile barrier until use */
            carpuject.barrel.cartridge.isSterile == true and
            carpuject.needle.isSterile == true
        }
    }
    
    requirement def PressureSafetyRequirement {
        doc /* Injection pressure safety requirement */
        subject carpuject : Carpuject;
        
        require constraint pressureLimit {
            doc /* Delivery pressure must not exceed safe limits */
            carpuject.primaryFunction.maxPressure <= 350.0
        }
    }
    
    requirement carpujectSystemRequirements {
        doc /* Top-level requirements for Carpuject medication delivery system */
        
        require safetyReq : SafetyRequirement {
            subject carpuject = carpujectSystem;
        }
        require dosageReq : DosageAccuracyRequirement {
            subject carpuject = carpujectSystem;
        }
        require sterilityReq : SterilityRequirement {
            subject carpuject = carpujectSystem;
        }
        require pressureReq : PressureSafetyRequirement {
            subject carpuject = carpujectSystem;
        }
    }
}
