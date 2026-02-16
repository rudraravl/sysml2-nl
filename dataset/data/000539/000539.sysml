package AutoinjectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MedicationDose :> VolumeValue {
        doc /* Medication dose volume in milliliters */
    }
    
    attribute def FlowRate :> Real {
        doc /* Flow rate in mL/s */
    }
    
    attribute def InjectionPressure :> PressureValue;
    attribute def InjectionDepth :> LengthValue;
    attribute def InjectionDuration :> TimeValue;
    attribute def ActivationForce :> ForceValue;
    
    item def Medication {
        attribute dose : MedicationDose;
        attribute concentration : Real;
        attribute activeIngredient : String;
        attribute expirationDate : String;
    }
    
    port def MedicationDeliveryPort {
        out item medication : Medication;
        out attribute flowRate : FlowRate;
    }
    
    port def ActivationPort {
        in attribute appliedForce : ActivationForce;
        out attribute activated : Boolean;
    }
    
    port def SafetyPort {
        in attribute capRemoved : Boolean;
        out attribute safetyCleared : Boolean;
    }
    
    part def SafetyCap {
        port safetyPort : SafetyPort;
        attribute isRemoved : Boolean := false;
        attribute lockingForce : ForceValue := 5.0[SI::N];
        
        action def RemoveCap {
            out capRemoved : Boolean;
        }
    }
    
    part def ActivationMechanism {
        port activationPort : ActivationPort;
        attribute requiredForce : ActivationForce := 30.0[SI::N];
        attribute isActivated : Boolean := false;
        
        action def DetectActivation {
            in appliedForce : ActivationForce;
            out activated : Boolean;
        }
    }
    
    part def NeedleAssembly {
        attribute needleLength : InjectionDepth := 15.0[SI::mm];
        attribute needleGauge : Real := 26.0;
        attribute isDeployed : Boolean := false;
        
        action def DeployNeedle {
            in deploymentSignal : Boolean;
            out needleDeployed : Boolean;
            out penetrationDepth : InjectionDepth;
        }
        
        action def RetractNeedle {
            out needleRetracted : Boolean;
        }
    }
    
    part def MedicationCartridge {
        port deliveryPort : MedicationDeliveryPort;
        attribute capacity : MedicationDose := 2.0[SI::mL];
        attribute currentVolume : MedicationDose := 2.0[SI::mL];
        item storedMedication : Medication;
        
        action def DispenseMedication {
            in requestedDose : MedicationDose;
            out dispensedMedication : Medication;
            out remainingVolume : MedicationDose;
        }
    }
    
    part def SpringDrivenPlunger {
        attribute springConstant : Real := 500.0;
        attribute preloadForce : ForceValue := 100.0[SI::N];
        attribute displacement : LengthValue := 0.0[SI::mm];
        
        action def ReleasePlunger {
            in releaseSignal : Boolean;
            out plungerForce : ForceValue;
            out plungerDisplacement : LengthValue;
        }
    }
    
    part def InjectionPump {
        attribute targetPressure : InjectionPressure := 200.0[SI::Pa];
        attribute flowRate : FlowRate := 0.2;
        
        action def DeliverMedication {
            in medication : Medication;
            in targetDepth : InjectionDepth;
            in plungerForce : ForceValue;
            out injectionComplete : Boolean;
            out actualDose : MedicationDose;
            out deliveryTime : InjectionDuration;
        }
    }
    
    part def StatusIndicator {
        attribute readyToUse : Boolean := true;
        attribute injectionInProgress : Boolean := false;
        attribute injectionComplete : Boolean := false;
        
        action def ProvideVisualFeedback {
            in systemState : String;
            out indicatorColor : String;
        }
        
        action def ProvideAudioFeedback {
            in systemState : String;
            out audioSignal : String;
        }
    }
    
    part def NeedleShield {
        attribute isLocked : Boolean := false;
        
        action def LockShield {
            out shieldLocked : Boolean;
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The autoinjector shall prevent accidental activation through dual safety mechanisms */
        subject autoinjector : Autoinjector;
        require constraint {
            autoinjector.safetyCap.isRemoved == true and 
            autoinjector.activationMechanism.isActivated == true
        }
    }
    
    requirement def DosageAccuracyRequirement {
        doc /* The autoinjector shall deliver medication dose within ±5% of prescribed dose */
        attribute targetDose : MedicationDose;
        attribute actualDose : MedicationDose;
        require constraint {
            (actualDose >= targetDose * 0.95) and 
            (actualDose <= targetDose * 1.05)
        }
    }
    
    requirement def InjectionDepthRequirement {
        doc /* The needle shall penetrate to subcutaneous tissue depth between 10-15mm */
        attribute minDepth : InjectionDepth := 10.0[SI::mm];
        attribute maxDepth : InjectionDepth := 15.0[SI::mm];
        require constraint {
            (NeedleAssembly::needleLength >= minDepth) and 
            (NeedleAssembly::needleLength <= maxDepth)
        }
    }
    
    requirement def InjectionTimeRequirement {
        doc /* The complete injection sequence shall occur within 10 seconds of activation */
        attribute maxDuration : InjectionDuration := 10.0[SI::s];
    }
    
    requirement def PostInjectionSafetyRequirement {
        doc /* The needle shall be automatically shielded and locked after injection completion */
        subject shield : NeedleShield;
        require constraint {
            shield.isLocked == true
        }
    }
    
    state def AutoinjectorStateMachine {
        entry; then ready;
        
        state ready {
            doc /* Device is in safe storage state with safety cap engaged */
            entry assign StatusIndicator::readyToUse := true;
        }
        
        state capRemoved {
            doc /* Safety cap has been removed, device is armed */
        }
        
        transition ready_to_capRemoved
            first ready
            accept SafetyCap::RemoveCap
            then capRemoved;
        
        state activated {
            doc /* Activation mechanism has been triggered by user */
            entry assign ActivationMechanism::isActivated := true;
        }
        
        transition capRemoved_to_activated
            first capRemoved
            accept ActivationMechanism::DetectActivation
            then activated;
        
        state needleDeployed {
            doc /* Needle has been deployed into injection site */
            entry assign NeedleAssembly::isDeployed := true;
        }
        
        transition activated_to_needleDeployed
            first activated
            accept NeedleAssembly::DeployNeedle
            then needleDeployed;
        
        state injecting {
            doc /* Medication is being delivered under controlled pressure */
            entry assign StatusIndicator::injectionInProgress := true;
        }
        
        transition needleDeployed_to_injecting
            first needleDeployed
            accept InjectionPump::DeliverMedication
            then injecting;
        
        state complete {
            doc /* Injection is complete, needle is being retracted and shielded */
            entry assign StatusIndicator::injectionComplete := true;
        }
        
        transition injecting_to_complete
            first injecting
            then complete;
        
        state locked {
            doc /* Needle is permanently shielded and device is disabled */
        }
        
        transition complete_to_locked
            first complete
            accept NeedleShield::LockShield
            then locked;
        
        state done;
        
        transition locked_to_done
            first locked
            then done;
    }
    
    action def PerformAutoinjection {
        doc /* 
            Primary function: Deliver a precise dose of medication subcutaneously 
            through an automated, user-activated injection sequence that ensures 
            safety before, during, and after medication delivery.
        */
        
        in prescribedDose : MedicationDose;
        in medication : Medication;
        out injectionSuccessful : Boolean;
        out deliveredDose : MedicationDose;
        out totalInjectionTime : InjectionDuration;
        
        first start;
        
        then action removeSafetyCap : SafetyCap::RemoveCap {
            out capRemoved : Boolean;
        }
        
        then action detectActivation : ActivationMechanism::DetectActivation {
            in appliedForce : ActivationForce;
            out activated : Boolean;
        }
        
        then action deployNeedle : NeedleAssembly::DeployNeedle {
            in deploymentSignal = detectActivation.activated;
            out needleDeployed : Boolean;
            out penetrationDepth : InjectionDepth;
        }
        
        then action releasePlunger : SpringDrivenPlunger::ReleasePlunger {
            in releaseSignal = deployNeedle.needleDeployed;
            out plungerForce : ForceValue;
            out plungerDisplacement : LengthValue;
        }
        
        then action dispenseMedication : MedicationCartridge::DispenseMedication {
            in requestedDose = prescribedDose;
            out dispensedMedication : Medication;
            out remainingVolume : MedicationDose;
        }
        
        then action deliverMedication : InjectionPump::DeliverMedication {
            in medication = dispenseMedication.dispensedMedication;
            in targetDepth = deployNeedle.penetrationDepth;
            in plungerForce = releasePlunger.plungerForce;
            out injectionComplete : Boolean;
            out actualDose : MedicationDose;
            out deliveryTime : InjectionDuration;
        }
        
        then action retractNeedle : NeedleAssembly::RetractNeedle {
            out needleRetracted : Boolean;
        }
        
        then action lockShield : NeedleShield::LockShield {
            out shieldLocked : Boolean;
        }
        
        then action provideVisualFeedback : StatusIndicator::ProvideVisualFeedback {
            in systemState = "injection_complete";
            out indicatorColor : String;
        }
        
        then action provideAudioFeedback : StatusIndicator::ProvideAudioFeedback {
            in systemState = "injection_complete";
            out audioSignal : String;
        }
        
        then assign injectionSuccessful := deliverMedication.injectionComplete;
        then assign deliveredDose := deliverMedication.actualDose;
        then assign totalInjectionTime := deliverMedication.deliveryTime;
        
        then done;
    }
    
    part def Autoinjector {
        doc /* 
            An autoinjector is a single-use, spring-driven medical device designed 
            for self-administration of a predetermined dose of medication via 
            subcutaneous injection. Its primary function is to safely and reliably 
            deliver medication through an automated sequence that includes safety 
            verification, needle deployment, controlled medication delivery, and 
            automatic needle shielding to prevent needlestick injuries.
        */
        
        attribute deviceId : String;
        attribute manufacturingDate : String;
        attribute lotNumber : String;
        attribute expirationDate : String;
        
        part safetyCap : SafetyCap {
            perform autoinjectionSequence.removeSafetyCap;
        }
        
        part activationMechanism : ActivationMechanism {
            perform autoinjectionSequence.detectActivation;
        }
        
        part needleAssembly : NeedleAssembly {
            perform autoinjectionSequence.deployNeedle;
            perform autoinjectionSequence.retractNeedle;
        }
        
        part medicationCartridge : MedicationCartridge {
            perform autoinjectionSequence.dispenseMedication;
        }
        
        part plunger : SpringDrivenPlunger {
            perform autoinjectionSequence.releasePlunger;
        }
        
        part injectionPump : InjectionPump {
            perform autoinjectionSequence.deliverMedication;
        }
        
        part statusIndicator : StatusIndicator {
            perform autoinjectionSequence.provideVisualFeedback;
            perform autoinjectionSequence.provideAudioFeedback;
        }
        
        part needleShield : NeedleShield {
            perform autoinjectionSequence.lockShield;
        }
        
        connect safetyCap.safetyPort to activationMechanism;
        connect activationMechanism.activationPort to needleAssembly;
        connect plunger to medicationCartridge;
        connect medicationCartridge.deliveryPort to injectionPump;
        connect injectionPump to needleAssembly;
        connect needleAssembly to needleShield;
        
        exhibit state stateMachine : AutoinjectorStateMachine;
        
        perform action autoinjectionSequence : PerformAutoinjection;
        
        satisfy requirement safetyReq : SafetyRequirement;
        satisfy requirement dosageReq : DosageAccuracyRequirement;
        satisfy requirement depthReq : InjectionDepthRequirement;
        satisfy requirement timeReq : InjectionTimeRequirement;
        satisfy requirement postInjectionSafetyReq : PostInjectionSafetyRequirement;
    }
    
    part epinephrine_autoinjector : Autoinjector {
        attribute deviceId = "EPI-AUTO-2024-001";
        attribute manufacturingDate = "2024-01-15";
        attribute lotNumber = "LOT-456789";
        attribute expirationDate = "2026-01-15";
        
        part redefines medicationCartridge {
            attribute capacity = 2.0[SI::mL];
            attribute currentVolume = 2.0[SI::mL];
            item redefines storedMedication {
                attribute dose = 0.3[SI::mL];
                attribute concentration = 1.0;
                attribute activeIngredient = "Epinephrine";
                attribute expirationDate = "2026-01-15";
            }
        }
        
        part redefines needleAssembly {
            attribute needleLength = 15.0[SI::mm];
            attribute needleGauge = 26.0;
        }
        
        part redefines injectionPump {
            attribute targetPressure = 200000.0[SI::Pa];
            attribute flowRate = 0.15;
        }
    }
}
