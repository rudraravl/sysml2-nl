package SafetySyringeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VolumeInMilliliters :> ISQ::VolumeValue;
    attribute def PressureInPascals :> ISQ::PressureValue;
    attribute def ForceInNewtons :> ISQ::ForceValue;
    attribute def LengthInMillimeters :> ISQ::LengthValue;
    
    item def Medication {
        attribute volume : VolumeInMilliliters;
        attribute viscosity : Real;
    }
    
    enum def NeedleStatus {
        exposed;
        shielded;
        locked;
    }
    
    enum def PlungerStatus {
        ready;
        depressing;
        fullyDepressed;
    }
    
    part def Barrel {
        attribute capacity : VolumeInMilliliters;
        attribute currentVolume : VolumeInMilliliters;
        port fluidChamber;
        port plungerInterface;
        port needleConnection;
    }
    
    part def Plunger {
        attribute position : LengthInMillimeters;
        attribute maxStroke : LengthInMillimeters;
        attribute status : PlungerStatus;
        port mechanicalDrive;
        port sealInterface;
    }
    
    part def Needle {
        attribute length : LengthInMillimeters;
        attribute gaugeSize : Real;
        attribute needleStatus : NeedleStatus;
        port fluidInlet;
        port deliveryTip;
    }
    
    part def SafetyShield {
        attribute isActivated : Boolean;
        attribute isLocked : Boolean;
        port shieldTrigger;
        port needleGuard;
    }
    
    part def SafetySyringe {
        doc /* A medical device designed to deliver precise medication doses 
             while automatically protecting healthcare workers from needlestick 
             injuries through an integrated safety mechanism. */
        
        attribute syringeID : String;
        attribute isSterile : Boolean;
        attribute isDisposed : Boolean;
        
        part barrel : Barrel {
            attribute capacity = 10.0 [mL];
            attribute currentVolume = 10.0 [mL];
        }
        
        part plunger : Plunger {
            attribute position = 0.0 [mm];
            attribute maxStroke = 85.0 [mm];
            attribute status = PlungerStatus::ready;
        }
        
        part needle : Needle {
            attribute length = 25.0 [mm];
            attribute gaugeSize = 22.0;
            attribute needleStatus = NeedleStatus::exposed;
        }
        
        part safetyShield : SafetyShield {
            attribute isActivated = false;
            attribute isLocked = false;
        }
        
        part medication : Medication {
            attribute volume = 10.0 [mL];
            attribute viscosity = 1.0;
        }
        
        connection barrelPlungerConnection connect barrel.plungerInterface to plunger.mechanicalDrive;
        connection barrelNeedleConnection connect barrel.needleConnection to needle.fluidInlet;
        connection plungerSealConnection connect plunger.sealInterface to barrel.fluidChamber;
        connection shieldNeedleConnection connect safetyShield.needleGuard to needle.deliveryTip;
        
        perform action operationalCycle;
    }
    
    action def PrepareForInjection {
        in initialVolume : VolumeInMilliliters;
        out isReady : Boolean;
    }
    
    action def PenetrateTarget {
        in needleLength : LengthInMillimeters;
        in penetrationForce : ForceInNewtons;
        out penetrationDepth : LengthInMillimeters;
    }
    
    action def DeliverMedication {
        in appliedForce : ForceInNewtons;
        in currentPosition : LengthInMillimeters;
        in remainingVolume : VolumeInMilliliters;
        out newPosition : LengthInMillimeters;
        out volumeDelivered : VolumeInMilliliters;
    }
    
    action def ActivateSafetyShield {
        out shieldActivated : Boolean;
        out needleLocked : Boolean;
    }
    
    action def RemoveFromPatient {
        in safetyEngaged : Boolean;
        out withdrawalComplete : Boolean;
    }
    
    action def DisposeDevice {
        out disposalConfirmed : Boolean;
    }
    
    action operationalCycle {
        doc /* Complete operational cycle of the safety syringe from preparation 
             through disposal, ensuring safe medication delivery and automatic 
             needle protection. */
        
        first start;
        
        then action prepare : PrepareForInjection {
            in initialVolume;
            out isReady;
        }
        
        then action penetrate : PenetrateTarget {
            in needleLength;
            in penetrationForce;
            out penetrationDepth;
        }
        
        then merge deliveryCycle;
        
        then action checkRemaining {
            out volumeLeft : VolumeInMilliliters;
        }
        
        then decide;
            if checkRemaining.volumeLeft > 0.1 [mL] then continueDelivery;
            if checkRemaining.volumeLeft <= 0.1 [mL] then activateSafety;
        
        action continueDelivery : DeliverMedication {
            in appliedForce;
            in currentPosition;
            in remainingVolume = checkRemaining.volumeLeft;
            out newPosition;
            out volumeDelivered;
        }
        then deliveryCycle;
        
        action activateSafety : ActivateSafetyShield {
            out shieldActivated;
            out needleLocked;
        }
        
        then action remove : RemoveFromPatient {
            in safetyEngaged = activateSafety.needleLocked;
            out withdrawalComplete;
        }
        
        then action dispose : DisposeDevice {
            out disposalConfirmed;
        }
        
        then done;
    }
    
    state def SafetySyringeLifecycle {
        entry; then sterile;
        
        state sterile;
        then prepared when PrepareForInjection;
        
        state prepared;
        then inserted when PenetrateTarget;
        
        state inserted;
        then delivering when DeliverMedication;
        
        state delivering;
        then if "medication depleted" safetyActivated;
        then if "continue injection" delivering;
        
        state safetyActivated;
        then withdrawn when RemoveFromPatient;
        
        state withdrawn;
        then disposed when DisposeDevice;
        
        state disposed;
    }
    
    part safetySyringe : SafetySyringe {
        exhibit state lifecycle : SafetySyringeLifecycle;
    }
    
    requirement def SafetyRequirement;
    requirement def FunctionalRequirement;
    requirement def UsabilityRequirement;
    requirement def SterilityRequirement;
    
    requirement <'REQ-SF-001'> automaticNeedleProtection : SafetyRequirement {
        doc /* The safety syringe shall automatically shield and permanently lock 
             the needle immediately upon completion of medication delivery to 
             prevent accidental needlestick injuries to healthcare workers. */
        
        subject safetySyringe;
        
        require constraint {
            safetySyringe.safetyShield.isActivated and
            safetySyringe.safetyShield.isLocked and
            safetySyringe.needle.needleStatus == NeedleStatus::locked
        }
    }
    
    requirement <'REQ-SF-002'> preventReuse : SafetyRequirement {
        doc /* The safety syringe shall prevent reuse once the safety mechanism 
             has been activated and locked, ensuring single-use compliance. */
        
        subject safetySyringe;
        
        require constraint {
            safetySyringe.safetyShield.isLocked implies
            safetySyringe.needle.needleStatus == NeedleStatus::locked
        }
    }
    
    requirement <'REQ-FN-001'> accurateDosing : FunctionalRequirement {
        doc /* The safety syringe shall deliver the prescribed medication volume 
             with an accuracy of ±2% to ensure proper patient treatment. */
        
        subject safetySyringe;
    }
    
    requirement <'REQ-US-001'> passiveActivation : UsabilityRequirement {
        doc /* The safety mechanism shall activate passively without requiring 
             additional deliberate action from the healthcare worker beyond 
             normal injection procedure. */
        
        subject safetySyringe.safetyShield;
    }
    
    requirement <'REQ-ST-001'> maintainSterility : SterilityRequirement {
        doc /* The safety syringe shall maintain sterility of the needle, fluid 
             pathway, and medication chamber until point of use. */
        
        subject safetySyringe;
        
        require constraint {
            safetySyringe.isSterile == true
        }
    }
    
    requirement <'REQ-MS-001'> primaryMission {
        doc /* The safety syringe system shall safely and accurately deliver 
             prescribed medication doses while providing automatic protection 
             against needlestick injuries through passive safety mechanism 
             activation and permanent needle lockout. */
        
        subject safetySyringe;
        
        assume constraint {
            safetySyringe.medication.volume > 0.0 [mL] and
            safetySyringe.isSterile == true and
            safetySyringe.isDisposed == false
        }
        
        require automaticNeedleProtection;
        require preventReuse;
        require accurateDosing;
        require passiveActivation;
        require maintainSterility;
    }
}
