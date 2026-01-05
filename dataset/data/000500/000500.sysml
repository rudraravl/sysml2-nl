package SingleUseMedicalDeviceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SterilityStatus;
    attribute def DeviceIntegrity;
    
    attribute def DoseVolume :> VolumeValue {
        doc /* Volume of medication to be delivered */
    }
    
    attribute def InjectionForce :> ForceValue {
        doc /* Force required for injection */
    }
    
    attribute def FlowRate :> Real {
        doc /* Rate of fluid delivery */
    }
    
    item def Medication {
        attribute dosageAmount : DoseVolume;
        attribute concentration : Real;
        attribute drugName : String;
    }
    
    item def BiohazardWaste {
        attribute contaminated : Boolean;
        attribute needlePresent : Boolean;
    }
    
    port def SterileBarrier {
        attribute sealed : Boolean;
        attribute breached : Boolean;
    }
    
    port def FluidDeliveryPort {
        in item medication : Medication;
        attribute deliveryRate : FlowRate;
    }
    
    port def MechanicalInterface {
        in force : InjectionForce;
        out displacement : LengthValue;
    }
    
    port def SafetyLockInterface {
        attribute engaged : Boolean;
        attribute tamperEvident : Boolean;
    }
    
    part def SterilePackage {
        attribute sealed : Boolean = true;
        attribute integrityMaintained : Boolean = true;
        attribute expirationDate : String;
        attribute lotNumber : String;
        
        port barrier : SterileBarrier;
    }
    
    part def ReservoirChamber {
        attribute capacity : DoseVolume;
        attribute currentVolume : DoseVolume;
        attribute pressurized : Boolean;
        
        port outlet : FluidDeliveryPort;
    }
    
    part def DeliveryMechanism {
        attribute needleGauge : Real;
        attribute needleLength : LengthValue;
        attribute retracted : Boolean = false;
        
        port inlet : FluidDeliveryPort;
        port tissueInterface : FluidDeliveryPort;
        port actuator : MechanicalInterface;
    }
    
    part def ActivationTrigger {
        attribute pressed : Boolean = false;
        attribute forceThreshold : InjectionForce;
        
        port mechanicalOutput : MechanicalInterface;
    }
    
    part def SafetyMechanism {
        attribute needleShieldDeployed : Boolean = false;
        attribute lockEngaged : Boolean = false;
        attribute visualIndicator : String = "unused";
        
        port lockInterface : SafetyLockInterface;
    }
    
    part def UsageCounter {
        attribute activationCount : Integer = 0;
        attribute maximumUses : Integer = 1;
        attribute permanentlyDisabled : Boolean = false;
    }
    
    requirement def SingleUseEnforcement {
        doc /* Device shall mechanically prevent reuse after single activation */
        
        require constraint preventReuse {
            UsageCounter::activationCount <= UsageCounter::maximumUses
        }
    }
    
    requirement def SterilityMaintenance {
        doc /* Device shall maintain sterile fluid path until point of use */
        
        require constraint sterileIntegrity {
            SterilePackage::sealed implies SterileBarrier::sealed
        }
    }
    
    requirement def DoseAccuracy {
        doc /* Device shall deliver prescribed dose within acceptable tolerance */
        
        require constraint accurateDosing {
            ReservoirChamber::currentVolume >= 0.95 * ReservoirChamber::capacity and
            ReservoirChamber::currentVolume <= 1.05 * ReservoirChamber::capacity
        }
    }
    
    requirement def PostUseSafety {
        doc /* Device shall prevent needlestick injury after use */
        
        require constraint needleProtection {
            UsageCounter::activationCount >= 1 implies SafetyMechanism::needleShieldDeployed
        }
    }
    
    requirement singleUseMedicalDeviceRequirements {
        doc /* Comprehensive requirements for single-use medical device system */
        
        require singleUseReq : SingleUseEnforcement;
        require sterilityReq : SterilityMaintenance;
        require doseReq : DoseAccuracy;
        require safetyReq : PostUseSafety;
    }
    
    action def RemoveFromPackage {
        in packagedDevice;
        out exposedDevice;
        out sterilityStatus : Boolean;
    }
    
    action def InspectDevice {
        in device;
        out inspectionPassed : Boolean;
    }
    
    action def PrepareForAdministration {
        in inspectedDevice;
        out readyDevice;
    }
    
    action def ActivateDevice {
        in readyDevice;
        in activationForce : InjectionForce;
        out activatedDevice;
    }
    
    action def DeliverDose {
        in activatedDevice;
        in medication : Medication;
        out deliveredVolume : DoseVolume;
    }
    
    action def EngageSafetyLock {
        in usedDevice;
        out securedDevice;
    }
    
    action def DisposeInSharpsContainer {
        in securedDevice;
        out waste : BiohazardWaste;
    }
    
    action def PerformSingleUseDeviceCycle {
        doc /* Complete operational cycle from package opening to safe disposal */
        
        first start;
        
        then action removePackage : RemoveFromPackage {
            in packagedDevice;
            out exposedDevice;
            out sterilityStatus;
        }
        
        then decide;
            if removePackage.sterilityStatus == true then inspect;
            if removePackage.sterilityStatus == false then abort;
        
        action inspect : InspectDevice {
            in device = removePackage.exposedDevice;
            out inspectionPassed;
        }
        
        then decide;
            if inspect.inspectionPassed == true then prepare;
            if inspect.inspectionPassed == false then abort;
        
        action prepare : PrepareForAdministration {
            in inspectedDevice = inspect.device;
            out readyDevice;
        }
        
        then action activate : ActivateDevice {
            in readyDevice = prepare.readyDevice;
            in activationForce;
            out activatedDevice;
        }
        
        then action deliver : DeliverDose {
            in activatedDevice = activate.activatedDevice;
            in medication;
            out deliveredVolume;
        }
        
        then action engageSafety : EngageSafetyLock {
            in usedDevice = deliver.activatedDevice;
            out securedDevice;
        }
        
        then action dispose : DisposeInSharpsContainer {
            in securedDevice = engageSafety.securedDevice;
            out waste;
        }
        
        then done;
        
        action abort {
            doc /* Abort procedure due to integrity failure */
        }
        
        then done;
    }
    
    part def AutoInjectorDevice {
        doc /* Single-use auto-injector for emergency medication delivery */
        
        part package : SterilePackage {
            attribute sealed = true;
            attribute integrityMaintained = true;
            attribute expirationDate = "2026-06-30";
            attribute lotNumber = "LOT-2024-A1234";
        }
        
        part reservoir : ReservoirChamber;
        
        part deliverySystem : DeliveryMechanism {
            attribute needleGauge = 26.0;
            attribute retracted = false;
        }
        
        part trigger : ActivationTrigger {
            attribute pressed = false;
        }
        
        part safety : SafetyMechanism {
            attribute needleShieldDeployed = false;
            attribute lockEngaged = false;
            attribute visualIndicator = "unused";
        }
        
        part counter : UsageCounter {
            attribute activationCount = 0;
            attribute maximumUses = 1;
            attribute permanentlyDisabled = false;
        }
        
        connect reservoir.outlet to deliverySystem.inlet;
        connect trigger.mechanicalOutput to deliverySystem.actuator;
        connect safety.lockInterface to trigger.mechanicalOutput;
        
        perform action operationalCycle[*] ordered
            references PerformSingleUseDeviceCycle;
        
        state lifecycle {
            entry; then packaged;
            
            state packaged {
                doc /* Device sealed in sterile packaging */
            }
            then unpackaged;
            
            state unpackaged {
                doc /* Device removed from package, sterility exposed */
            }
            then inspected;
            
            state inspected {
                doc /* Device visually inspected for defects */
            }
            then ready;
            
            state ready {
                doc /* Device prepared and positioned for use */
            }
            then activated;
            
            state activated {
                doc /* Trigger mechanism engaged, delivery initiated */
            }
            then delivering;
            
            state delivering {
                doc /* Medication actively being delivered */
            }
            then delivered;
            
            state delivered {
                doc /* Full dose delivered, device spent */
            }
            then secured;
            
            state secured {
                doc /* Safety mechanism locked, needle shielded */
            }
            then disposed;
            
            state disposed {
                doc /* Device placed in biohazard waste container */
            }
            then done;
        }
    }
    
    part autoInjectorDevice : AutoInjectorDevice;
    
    part clinicalEnvironment {
        doc /* Healthcare setting where single-use device is deployed */
        
        part deviceInventory[*] : AutoInjectorDevice;
        
        part healthcareProvider {
            doc /* Clinician administering treatment */
            perform autoInjectorDevice.operationalCycle;
        }
        
        part sharpsContainer {
            doc /* Biohazard waste receptacle for used devices */
            accept item disposedWaste : BiohazardWaste;
        }
        
        connection deviceToWaste
            connect autoInjectorDevice to sharpsContainer;
    }
    
    requirement systemCompliance : singleUseMedicalDeviceRequirements {
        subject autoInjectorDevice;
        
        assume constraint validPackaging {
            autoInjectorDevice.package.sealed and
            autoInjectorDevice.package.integrityMaintained
        }
        
        assume constraint withinShelfLife {
            autoInjectorDevice.package.expirationDate >= "2024-01-01"
        }
        
        require constraint enforceSingleActivation {
            autoInjectorDevice.counter.activationCount <= 1
        }
        
        require constraint permanentDisablement {
            autoInjectorDevice.counter.activationCount >= 1 implies
            autoInjectorDevice.counter.permanentlyDisabled
        }
        
        require constraint safetyDeployment {
            autoInjectorDevice.counter.activationCount >= 1 implies
            autoInjectorDevice.safety.needleShieldDeployed and
            autoInjectorDevice.safety.lockEngaged
        }
    }
}
