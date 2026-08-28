package AutoInjector {
    public import ISQ::TorqueValue;
    public import ISQ::VolumeValue;
    public import ISQ::LengthValue;
    public import ISQ::MassValue;
    public import ISQ::DurationValue;
    public import ISQ::SpeedValue;
    public import ISQ::ForceValue;

    attribute def Gauge :>> Integer;

    value def ActivationForce :>> ForceValue;
    value def DoseVolume :>> VolumeValue;
    value def DeliveryRate :>> VolumeValue;
    value def NeedleLength :>> LengthValue;
    value def NeedleGauge :>> Gauge;
    value def ExtensionTime :>> DurationValue;
    value def InjectionTime :>> DurationValue;

    item def Medication {
        attribute drugName : String;
        attribute concentration : MassValue;
        attribute volume : DoseVolume;
    }

    enum def DeviceStatus {
        Sealed = 0;
        Ready = 1;
        Activated = 2;
        Injecting = 3;
        Completed = 4;
        Locked = 5;
        Disposed = 6;
    }

    port def MedicationPort {
        out item med : Medication;
    }

    port def TriggerPort {
        in attribute appliedForce : ActivationForce;
        out attribute triggered : Boolean;
    }

    port def SafetyPort {
        out attribute shieldDeployed : Boolean;
        out attribute locked : Boolean;
    }

    port def StatusPort {
        out attribute status : DeviceStatus;
    }

    part def SterilePackage {
        attribute sealed : Boolean = true;
        attribute integrityVerified : Boolean = false;
        
        action breakSeal();
        action verifyIntegrity() :>> Boolean;
    }

    part def ReservoirChamber {
        attribute capacity : DoseVolume;
        attribute fillVolume : DoseVolume;
        attribute remainingVolume : DoseVolume;
        attribute drug : Medication;
        
        port medOut : MedicationPort;
        
        action dispenseDose(out dispensed : DoseVolume) {
            if remainingVolume > 0.0 [mL] {
                dispensed := fillVolume;
                remainingVolume := 0.0 [mL];
            } else {
                dispensed := 0.0 [mL];
            }
        }
    }

    part def Needle {
        attribute gauge : NeedleGauge;
        attribute length : NeedleLength;
        attribute extended : Boolean = false;
        attribute shielded : Boolean = false;
        
        action extend() {
            extended := true;
        }
        
        action retract() {
            extended := false;
        }
    }

    part def DeliveryMechanism {
        part needle : Needle {
            attribute gauge = 27 :> NeedleGauge;
            attribute length = 12.7 [mm] :>> NeedleLength;
        }
        
        attribute deliveryRate : DeliveryRate = 0.5 [mL/s];
        attribute extensionTime : ExtensionTime = 0.2 [s];
        attribute injectionTime : InjectionTime = 10.0 [s];
        
        port medIn : MedicationPort;
        port medOut : MedicationPort;
        
        action extendNeedle() {
            needle.extend();
        }
        
        action deliverMedication(in dose : DoseVolume) {
            // Controlled delivery at specified rate
        }
        
        action retractNeedle() {
            needle.retract();
        }
    }

    part def ActivationTrigger {
        attribute requiredForce : ActivationForce = 15.0 [N];
        attribute currentForce : ActivationForce = 0.0 [N];
        attribute triggered : Boolean = false;
        
        port triggerOut : TriggerPort;
        
        action applyForce(in force : ActivationForce) {
            currentForce := force;
            if force >= requiredForce and not triggered {
                triggered := true;
                triggerOut.triggered := true;
            }
        }
    }

    part def NeedleShield {
        attribute deployed : Boolean = false;
        attribute locked : Boolean = false;
        
        port safetyOut : SafetyPort;
        
        action deploy() {
            deployed := true;
            safetyOut.shieldDeployed := true;
        }
        
        action lock() {
            locked := true;
            safetyOut.locked := true;
        }
    }

    part def UsageCounter {
        attribute activationCount : Integer = 0;
        attribute maxActivations : Integer = 1;
        attribute permanentlyDisabled : Boolean = false;
        
        action increment() {
            activationCount := activationCount + 1;
            if activationCount >= maxActivations {
                permanentlyDisabled := true;
            }
        }
        
        action checkAvailability() :>> Boolean {
            return not permanentlyDisabled;
        }
    }

    part def SafetyMechanism {
        part shield : NeedleShield;
        part counter : UsageCounter;
        
        attribute safetyEngaged : Boolean = false;
        
        port safetyOut : SafetyPort;
        
        action deployShield() {
            shield.deploy();
        }
        
        action lockShield() {
            shield.lock();
            safetyEngaged := true;
        }
        
        action disableDevice() {
            counter.increment();
        }
    }

    part def MainBody {
        part reservoir : ReservoirChamber {
            attribute capacity = 0.5 [mL] :>> DoseVolume;
            attribute fillVolume = 0.5 [mL] :>> DoseVolume;
            attribute remainingVolume = 0.5 [mL] :>> DoseVolume;
            attribute drug : Medication {
                attribute drugName = "Epinephrine";
                attribute concentration = 1.0 [mg/mL];
                attribute volume = 0.5 [mL];
            }
        }
        
        part delivery : DeliveryMechanism;
        part trigger : ActivationTrigger;
        part safety : SafetyMechanism;
        
        connection medFlow1 connect reservoir.medOut to delivery.medIn;
        connection triggerSignal connect trigger.triggerOut to delivery;
        
        attribute status : DeviceStatus = DeviceStatus::Sealed;
        attribute visualIndicator : Boolean = false;
        
        port statusOut : StatusPort;
        
        action updateStatus(in newStatus : DeviceStatus) {
            status := newStatus;
            statusOut.status := newStatus;
        }
        
        action initiateInjection() {
            if safety.counter.checkAvailability() {
                safety.disableDevice();
                delivery.extendNeedle();
                updateStatus(DeviceStatus::Injecting);
                reservoir.dispenseDose(dispensed);
                delivery.deliverMedication(dispensed);
                delivery.retractNeedle();
                safety.deployShield();
                safety.lockShield();
                visualIndicator := true;
                updateStatus(DeviceStatus::Locked);
            }
        }
    }

    part def AutoInjector {
        part package : SterilePackage;
        part body : MainBody;
        
        port statusOut : StatusPort;
        
        connection statusRelay connect body.statusOut to statusOut;
        
        state machine DeviceLifecycle {
            entry action { body.updateStatus(DeviceStatus::Sealed); }
            
            state Sealed {
                entry action { package.sealed := true; }
                
                transition Sealed to Ready
                    if package.sealed == false and package.integrityVerified == true
                    do action { body.updateStatus(DeviceStatus::Ready); }
            }
            
            state Ready {
                entry action { body.updateStatus(DeviceStatus::Ready); }
                
                transition Ready to Activated
                    if body.trigger.triggered == true
                    do action { body.updateStatus(DeviceStatus::Activated); }
            }
            
            state Activated {
                entry action { body.initiateInjection(); }
                
                transition Activated to Injecting
                    if body.delivery.needle.extended == true
                    do action { body.updateStatus(DeviceStatus::Injecting); }
            }
            
            state Injecting {
                transition Injecting to Completed
                    if body.reservoir.remainingVolume == 0.0 [mL]
                    do action { body.updateStatus(DeviceStatus::Completed); }
            }
            
            state Completed {
                entry action {
                    body.delivery.retractNeedle();
                    body.safety.deployShield();
                }
                
                transition Completed to Locked
                    if body.safety.shield.locked == true
                    do action { body.updateStatus(DeviceStatus::Locked); }
            }
            
            state Locked {
                entry action {
                    body.visualIndicator := true;
                }
                
                transition Locked to Disposed
                    if body.safety.counter.permanentlyDisabled == true
                    do action { body.updateStatus(DeviceStatus::Disposed); }
            }
            
            state Disposed {
                // Terminal state: device is biohazard waste
            }
        }
        
        action removePackaging() {
            package.breakSeal();
            package.integrityVerified := package.verifyIntegrity();
            package.sealed := false;
        }
        
        action inspectDevice() :>> Boolean {
            return package.integrityVerified;
        }
        
        action activate(in force : ActivationForce) {
            body.trigger.applyForce(force);
        }
    }

    requirement def AutoInjectorRequirements {
        subject : AutoInjector;
        
        requirement SterilityRequirement {
            doc "The device shall be sealed in a sterile package maintaining medication integrity until use."
            subject.package.sealed == true implies subject.body.reservoir.drug.volume > 0.0 [mL];
        }
        
        requirement DoseAccuracyRequirement {
            doc "The device shall deliver a pre-measured dose of 0.5 mL of medication."
            subject.body.reservoir.fillVolume == 0.5 [mL];
        }
        
        requirement ActivationForceRequirement {
            doc "The activation trigger shall require a specific force to initiate injection."
            subject.body.trigger.requiredForce >= 10.0 [N] and subject.body.trigger.requiredForce <= 20.0 [N];
        }
        
        requirement NeedleSpecificationRequirement {
            doc "The concealed needle shall be 27 gauge and 12.7 mm in length."
            subject.body.delivery.needle.gauge == 27 and subject.body.delivery.needle.length == 12.7 [mm];
        }
        
        requirement ControlledDeliveryRequirement {
            doc "The device shall deliver the full dose at a controlled rate."
            subject.body.delivery.deliveryRate == 0.5 [mL/s];
        }
        
        requirement SingleUseRequirement {
            doc "The device shall be permanently disabled after a single activation."
            subject.body.safety.counter.maxActivations == 1;
            subject.body.safety.counter.activationCount >= 1 implies subject.body.safety.counter.permanentlyDisabled == true;
        }
        
        requirement NeedleShieldRequirement {
            doc "A needle shield shall automatically deploy and lock after injection completion."
            subject.body.status == DeviceStatus::Locked implies subject.body.safety.shield.deployed == true and subject.body.safety.shield.locked == true;
        }
        
        requirement VisualIndicatorRequirement {
            doc "The locked shield shall provide a visual indicator that the device has been used."
            subject.body.safety.shield.locked == true implies subject.body.visualIndicator == true;
        }
        
        requirement SafetyLockRequirement {
            doc "The safety lock shall prevent accidental needlestick injuries after use."
            subject.body.safety.shield.locked == true implies subject.body.delivery.needle.shielded == true;
        }
        
        requirement DisposalRequirement {
            doc "After safety lock engagement, the device shall be disposed of as biohazard waste in a designated sharps container."
            subject.body.status == DeviceStatus::Disposed implies subject.body.safety.counter.permanentlyDisabled == true;
        }
    }
}
