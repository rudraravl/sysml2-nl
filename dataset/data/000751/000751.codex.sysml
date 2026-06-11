package SafetySyringeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def milliliter :> Real;
    attribute def millimeter :> Real;
    attribute def newton :> Real;
    attribute def second :> Real;
    attribute def kilopascal :> Real;
    attribute def percent :> Real;

    enum def SyringeUseState {
        enum idle;
        enum needleCovered;
        enum readyForFilling;
        enum filled;
        enum injectionReady;
        enum medicationDelivered;
        enum safetyActivated;
        enum disposalReady;
    }

    enum def NeedleShieldPosition {
        enum retracted;
        enum extended;
        enum locked;
    }

    enum def PlungerPosition {
        enum fullyRetracted;
        enum partiallyRetracted;
        enum partiallyDepressed;
        enum fullyDepressed;
    }

    enum def FluidSterilityState {
        enum sterile;
        enum exposed;
        enum contaminated;
    }

    item def MedicationFluid {
        attribute volume : milliliter;
        attribute viscosity : Real;
        attribute sterility : FluidSterilityState;
        attribute doseConcentration : Real;
    }

    item def Air {
        attribute volume : milliliter;
        attribute pressure : kilopascal;
    }

    item def UserForce {
        attribute magnitude : newton;
        attribute duration : second;
    }

    item def SharpsHazard {
        attribute exposedNeedleLength : millimeter;
        attribute hazardPresent : Boolean;
    }

    port def FluidPort {
        inout fluid : MedicationFluid;
    }

    port def ForcePort {
        in force : UserForce;
    }

    port def HazardPort {
        out hazard : SharpsHazard;
    }

    port def MechanicalLockPort {
        out locked : Boolean;
    }

    part def NeedleAssembly {
        attribute needleLength : millimeter = 16.0;
        attribute outerDiameter : millimeter = 0.5;
        attribute lumenDiameter : millimeter = 0.26;
        attribute bevelAngle : Real = 12.0;
        attribute sterileBarrierIntact : Boolean = true;

        port hubFluidPort : FluidPort;
        port tipFluidPort : FluidPort;
        port hazardPort : HazardPort;

        action pierceTissue {
            in insertionForce : UserForce;
            out tissueAccessEstablished : Boolean;
            first start;
            then verifySterileBarrier;
            then penetrate;
            then done;

            action verifySterileBarrier {
                out acceptable : Boolean;
            }

            action penetrate {
                in forceApplied : UserForce;
                out access : Boolean;
            }
        }

        action conductFluid {
            in incomingMedication : MedicationFluid;
            out deliveredMedication : MedicationFluid;
        }
    }

    part def Barrel {
        attribute nominalCapacity : milliliter = 3.0;
        attribute usableDoseVolume : milliliter = 3.0;
        attribute graduationIncrement : milliliter = 0.1;
        attribute internalDiameter : millimeter = 8.65;
        attribute residualVolumeLimit : milliliter = 0.07;
        attribute transparentWall : Boolean = true;

        port proximalFluidPort : FluidPort;
        port distalFluidPort : FluidPort;

        part medicationChamber {
            attribute containedVolume : milliliter = 0.0;
            attribute maximumVolume : milliliter = 3.0;
            attribute sterility : FluidSterilityState = FluidSterilityState::sterile;
        }
    }

    part def PlungerAssembly {
        attribute position : PlungerPosition = PlungerPosition::fullyDepressed;
        attribute sealIntegrity : percent = 99.5;
        attribute thumbPadDiameter : millimeter = 14.0;
        attribute stopperFrictionForce : newton = 3.0;
        attribute maximumOperatingForce : newton = 25.0;

        port userForcePort : ForcePort;
        port barrelFluidPort : FluidPort;

        action aspirateMedication {
            in pullForce : UserForce;
            in requestedVolume : milliliter;
            out aspiratedFluid : MedicationFluid;
        }

        action expelMedication {
            in pushForce : UserForce;
            in targetDose : milliliter;
            out expelledFluid : MedicationFluid;
            out doseComplete : Boolean;
        }
    }

    part def NeedleSafetyShield {
        attribute position : NeedleShieldPosition = NeedleShieldPosition::extended;
        attribute activationForceThreshold : newton = 8.0;
        attribute lockEngagementTravel : millimeter = 4.0;
        attribute shieldLength : millimeter = 22.0;
        attribute lockReusable : Boolean = false;
        attribute lockEngaged : Boolean = false;

        port userForcePort : ForcePort;
        port lockPort : MechanicalLockPort;
        port hazardPort : HazardPort;

        state def ShieldLifecycle {
            state covered;
            state retracted;
            state deploying;
            state locked;

            initial then covered;

            transition covered_to_retracted
                first covered
                accept retractCommand
                then retracted;

            transition retracted_to_deploying
                first retracted
                accept injectionComplete
                then deploying;

            transition deploying_to_locked
                first deploying
                accept shieldFullyAdvanced
                then locked;
        }

        action retractForInjection {
            in retractForce : UserForce;
            out needleAvailable : Boolean;
        }

        action activateSafetyLock {
            in activationForce : UserForce;
            out locked : Boolean;
            out residualHazard : SharpsHazard;
        }
    }

    part def DoseStopMechanism {
        attribute selectedDose : milliliter = 1.0;
        attribute doseAccuracyTolerance : milliliter = 0.05;
        attribute minimumSelectableDose : milliliter = 0.1;
        attribute maximumSelectableDose : milliliter = 3.0;

        port plungerForcePort : ForcePort;

        action limitStroke {
            in commandedDose : milliliter;
            out permittedDose : milliliter;
            out stopReached : Boolean;
        }
    }

    part def SterileNeedleCap {
        attribute attached : Boolean = true;
        attribute sterilitySealIntact : Boolean = true;
        attribute removalForce : newton = 5.0;

        action removeCap {
            in appliedForce : UserForce;
            out capRemoved : Boolean;
            out sterileNeedleExposed : Boolean;
        }
    }

    part def SafetySyringe {
        attribute currentState : SyringeUseState = SyringeUseState::needleCovered;
        attribute totalCapacity : milliliter = 3.0;
        attribute intendedSingleUse : Boolean = true;
        attribute maximumNeedleExposureAfterUse : millimeter = 0.0;
        attribute deliveredDoseAccuracy : percent = 95.0;
        attribute primaryFunction : String = "Store, measure, and inject a controlled dose of medication while reducing post-use needle-stick injury risk by locking a protective shield over the needle.";

        port medicationInlet : FluidPort;
        port medicationOutlet : FluidPort;
        port operatorInput : ForcePort;
        port sharpsHazardOutput : HazardPort;
        port safetyLockStatus : MechanicalLockPort;

        part barrel : Barrel;
        part plunger : PlungerAssembly;
        part needle : NeedleAssembly;
        part shield : NeedleSafetyShield;
        part doseStop : DoseStopMechanism;
        part cap : SterileNeedleCap;

        connect medicationInlet to barrel::proximalFluidPort;
        connect barrel::distalFluidPort to needle::hubFluidPort;
        connect needle::tipFluidPort to medicationOutlet;
        connect operatorInput to plunger::userForcePort;
        connect operatorInput to shield::userForcePort;
        connect operatorInput to doseStop::plungerForcePort;
        connect plunger::barrelFluidPort to barrel::proximalFluidPort;
        connect shield::lockPort to safetyLockStatus;
        connect needle::hazardPort to sharpsHazardOutput;
        connect shield::hazardPort to sharpsHazardOutput;

        action prepareForUse {
            in capRemovalForce : UserForce;
            out ready : Boolean;
            first removeSterileCap;
            then retractShield;
            then confirmReady;

            action removeSterileCap : cap::removeCap;
            action retractShield : shield::retractForInjection;
            action confirmReady {
                out readyConfirmed : Boolean;
            }
        }

        action fillDose {
            in pullForce : UserForce;
            in desiredDose : milliliter;
            out containedDose : MedicationFluid;
            first setDoseLimit;
            then withdrawMedication;
            then verifyDose;

            action setDoseLimit : doseStop::limitStroke;
            action withdrawMedication : plunger::aspirateMedication;
            action verifyDose {
                in measuredVolume : milliliter;
                out withinTolerance : Boolean;
            }
        }

        action injectMedication {
            in injectionForce : UserForce;
            in prescribedDose : milliliter;
            out deliveredMedication : MedicationFluid;
            out deliveryComplete : Boolean;
            first pierce;
            then depressPlunger;
            then verifyDelivery;

            action pierce : needle::pierceTissue;
            action depressPlunger : plunger::expelMedication;
            action verifyDelivery {
                in residualVolume : milliliter;
                out complete : Boolean;
            }
        }

        action secureAfterUse {
            in activationForce : UserForce;
            out lockedShield : Boolean;
            out safeForDisposal : Boolean;
            first advanceShield;
            then verifyLock;
            then classifyDisposalReadiness;

            action advanceShield : shield::activateSafetyLock;
            action verifyLock {
                in lockSignal : Boolean;
                out lockVerified : Boolean;
            }
            action classifyDisposalReadiness {
                in lockVerified : Boolean;
                out disposalReady : Boolean;
            }
        }

        state def UseLifecycle {
            state needleCovered;
            state readyForFilling;
            state filled;
            state injectionReady;
            state medicationDelivered;
            state safetyActivated;
            state disposalReady;

            initial then needleCovered;

            transition needleCovered_to_readyForFilling
                first needleCovered
                accept capRemoved
                then readyForFilling;

            transition readyForFilling_to_filled
                first readyForFilling
                accept doseAspirated
                then filled;

            transition filled_to_injectionReady
                first filled
                accept shieldRetracted
                then injectionReady;

            transition injectionReady_to_medicationDelivered
                first injectionReady
                accept plungerFullyDepressed
                then medicationDelivered;

            transition medicationDelivered_to_safetyActivated
                first medicationDelivered
                accept shieldLocked
                then safetyActivated;

            transition safetyActivated_to_disposalReady
                first safetyActivated
                accept hazardContained
                then disposalReady;
        }
    }

    requirement def StoreDoseRequirement {
        subject syringe : SafetySyringe;
        require constraint {
            syringe.totalCapacity >= 1.0 and syringe.totalCapacity <= 5.0
        }
    }

    requirement def DoseDeliveryAccuracyRequirement {
        subject syringe : SafetySyringe;
        require constraint {
            syringe.deliveredDoseAccuracy >= 95.0
        }
    }

    requirement def SingleUseSafetyRequirement {
        subject syringe : SafetySyringe;
        require constraint {
            syringe.intendedSingleUse == true
        }
    }

    requirement def NeedleShieldLockRequirement {
        subject syringe : SafetySyringe;
        require constraint {
            syringe.shield.lockReusable == false and syringe.shield.lockEngaged == true
        }
    }

    requirement def PostUseNeedleExposureRequirement {
        subject syringe : SafetySyringe;
        require constraint {
            syringe.maximumNeedleExposureAfterUse == 0.0
        }
    }

    requirement def ResidualMedicationRequirement {
        subject syringe : SafetySyringe;
        require constraint {
            syringe.barrel.residualVolumeLimit <= 0.07
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject syringe : SafetySyringe;
        require constraint {
            syringe.primaryFunction == "Store, measure, and inject a controlled dose of medication while reducing post-use needle-stick injury risk by locking a protective shield over the needle."
        }
    }

    part safetySyringeSystem {
        part syringe : SafetySyringe;

        assert constraint {
            syringe.totalCapacity == syringe.barrel.nominalCapacity
        }

        satisfy StoreDoseRequirement by syringe;
        satisfy DoseDeliveryAccuracyRequirement by syringe;
        satisfy SingleUseSafetyRequirement by syringe;
        satisfy NeedleShieldLockRequirement by syringe;
        satisfy PostUseNeedleExposureRequirement by syringe;
        satisfy ResidualMedicationRequirement by syringe;
        satisfy PrimaryFunctionRequirement by syringe;
    }
}