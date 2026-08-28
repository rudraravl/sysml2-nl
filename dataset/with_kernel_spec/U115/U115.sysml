package 'Auto-Injector System' {
    private import ScalarValues::*;

    item def Drug;
    item def TriggerSignal {
        attribute force : Real;
    }
    item def RemoveSignal;
    item def InjectionCompleteSignal;
    item def DisposeSignal;
    item def BiohazardWaste;

    part def SterilePackage;
    part def SharpsContainer;

    part def AutoInjector {
        port activationPort;
        port removePort;
        port statusPort;

        part mainBody : MainBody;
        part sterilePackage : SterilePackage;

        exhibit state 'AutoInjector States' : AutoInjectorStates;
        perform action administer : AdministerMedication;
    }

    part def MainBody {
        part reservoir : ReservoirChamber;
        part deliveryMech : DeliveryMechanism;
        part trigger : ActivationTrigger;
        part safetyMech : SafetyMechanism;
        part counter : UsageCounter;

        connector drugFlow from reservoir.outletPort to deliveryMech.drugInPort;
    }

    part def ReservoirChamber {
        item drug : Drug;
        attribute volume : Real = 0.3;
        attribute deliveryRate : Real = 0.1;
        port outletPort;
    }

    part def DeliveryMechanism {
        part needle : Needle;
        port extendPort;
        port drugInPort;
    }

    part def Needle {
        attribute gauge : Integer = 22;
        attribute length : Real = 15;
    }

    part def ActivationTrigger {
        attribute requiredForce : Real = 15;
        port signalPort;
    }

    part def SafetyMechanism {
        part shield : NeedleShield;
        attribute isLocked : Boolean = false;
        attribute isDeployed : Boolean = false;
        port deployPort;
    }

    part def NeedleShield;

    part def UsageCounter {
        attribute count : Integer = 0;
        attribute isDisabled : Boolean = false;
    }

    action def RemoveFromPackaging;
    action def Inspect;
    action def ExtendNeedle;
    action def DeliverMedication {
        in drug : Drug;
        in volume : Real;
    }
    action def DeployShield;
    action def LockShield;
    action def DisableDevice;
    action def DisposeInSharps {
        in waste : BiohazardWaste;
    }

    action def AdministerMedication {
        in drug : Drug;
        in volume : Real;
        action remove : RemoveFromPackaging;
        then action inspect : Inspect;
        then action extend : ExtendNeedle;
        then action deliver : DeliverMedication {
            in drug;
            in volume;
        }
        then action deploy : DeployShield;
        then action lock : LockShield;
        then action disable : DisableDevice;
        then action dispose : DisposeInSharps {
            in waste : BiohazardWaste;
        }
    }

    state def AutoInjectorStates;

    part autoInjector : AutoInjector {
        state 'AutoInjector States' : AutoInjectorStates {
            entry; then sealed;
            state sealed;
            accept RemoveSignal via removePort
                then inspected;
            state inspected;
            accept trigger : TriggerSignal via activationPort
                if trigger.force >= mainBody.trigger.requiredForce
                and mainBody.counter.count == 0
                then injecting;
            state injecting {
                entry action extendNeedle : ExtendNeedle;
                then action deliverMedication : DeliverMedication {
                    in drug = mainBody.reservoir.drug;
                    in volume = mainBody.reservoir.volume;
                }
                then action deployShield : DeployShield;
                then action lockShield : LockShield;
                then action disableDevice : DisableDevice;
            }
            accept InjectionCompleteSignal via statusPort
                then safetyLocked;
            state safetyLocked;
            accept DisposeSignal via statusPort
                then disabled;
            state disabled;
        }
    }

    requirement def SingleUseRequirement {
        doc /* The device shall be capable of only one activation and shall be permanently disabled thereafter. */
        subject autoInjector;
    }

    requirement def DoseRequirement {
        doc /* The reservoir shall deliver a pre-measured volume of medication at a controlled rate. */
        subject autoInjector;
    }

    requirement def NeedleRequirement {
        doc /* The needle shall have a specific gauge and length for subcutaneous delivery. */
        subject autoInjector;
    }

    requirement def TriggerForceRequirement {
        doc /* The activation trigger shall require a minimum force to prevent accidental deployment. */
        subject autoInjector;
    }

    requirement def SafetyLockRequirement {
        doc /* A needle shield shall automatically deploy and lock after injection to prevent needlestick injuries. */
        subject autoInjector;
    }

    requirement def BiohazardDisposalRequirement {
        doc /* After use, the device shall be classified as biohazard waste and disposed of in a sharps container. */
        subject autoInjector;
    }

    metadata def SafetyCritical;
    metadata def SingleUseOnly;

    metadata SafetyCritical about
        SafetyMechanism,
        ActivationTrigger,
        ReservoirChamber;
    metadata SingleUseOnly about
        AutoInjector,
        UsageCounter;
}
