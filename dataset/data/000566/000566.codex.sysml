package CarpujectSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Milliliter :> Real;
    attribute def Millimeter :> Real;
    attribute def Newton :> Real;
    attribute def Second :> Real;
    attribute def Percent :> Real;
    attribute def BooleanFlag :> Boolean;

    item def MedicationSolution {
        attribute medicationName : String;
        attribute concentration_mg_per_mL : Real;
        attribute volume_mL : Milliliter;
        attribute sterilityMaintained : BooleanFlag;
        attribute particulateFree : BooleanFlag;
    }

    item def Dose {
        attribute orderedVolume_mL : Milliliter;
        attribute deliveredVolume_mL : Milliliter;
        attribute maximumAllowedVolume_mL : Milliliter;
        attribute deliveryTolerance_percent : Percent;
    }

    item def UserForce {
        attribute axialForce_N : Newton;
        attribute duration_s : Second;
    }

    item def InjectionStatus {
        attribute needleAttached : BooleanFlag;
        attribute cartridgeSeated : BooleanFlag;
        attribute doseReady : BooleanFlag;
        attribute injectionComplete : BooleanFlag;
        attribute safetyRiskDetected : BooleanFlag;
    }

    port def MedicationOutletPort {
        out item medication : MedicationSolution;
        out item status : InjectionStatus;
    }

    port def CartridgePort {
        in item cartridgeMedication : MedicationSolution;
        out item seatingStatus : InjectionStatus;
    }

    port def NeedleInterfacePort {
        in item medicationFromHolder : MedicationSolution;
        out item medicationToPatient : MedicationSolution;
        out item needleStatus : InjectionStatus;
    }

    port def UserInputPort {
        in item appliedForce : UserForce;
    }

    port def PatientInterfacePort {
        in item receivedMedication : MedicationSolution;
    }

    part def CarpujectSystem {
        attribute primaryFunction : String = "Provide controlled manual administration of medication from a prefilled Carpuject cartridge through an attached sterile needle into a patient.";
        attribute nominalDoseVolume_mL : Milliliter = 2.0;
        attribute maximumDoseVolume_mL : Milliliter = 5.0;
        attribute minimumOperatingForce_N : Newton = 8.0;
        attribute maximumOperatingForce_N : Newton = 45.0;
        attribute doseAccuracyTolerance_percent : Percent = 5.0;

        port userInput : UserInputPort;
        port patientInterface : PatientInterfacePort;

        part holder : CartridgeHolder;
        part cartridge : PrefilledMedicationCartridge;
        part plungerRod : PlungerRod;
        part needleAssembly : NeedleAssembly;
        part doseIndicator : DoseIndicator;
        part safetyInterlock : SafetyInterlock;

        connect userInput to plungerRod.forceInput;
        connect cartridge.medicationPort to holder.cartridgeInterface;
        connect holder.outlet to needleAssembly.needleInterface;
        connect needleAssembly.patientPort to patientInterface;
        connect holder.statusPort to safetyInterlock.holderStatusPort;
        connect needleAssembly.statusPort to safetyInterlock.needleStatusPort;
        connect plungerRod.positionPort to doseIndicator.plungerPositionPort;
    }

    part def CartridgeHolder {
        attribute internalDiameter_mm : Millimeter = 10.0;
        attribute cartridgeSupported : BooleanFlag;
        attribute luerLockEngaged : BooleanFlag;

        port cartridgeInterface : CartridgePort;
        port outlet : MedicationOutletPort;
        port statusPort {
            out item holderStatus : InjectionStatus;
        }

        action alignCartridge {
            in item medication : MedicationSolution;
            out item status : InjectionStatus;
        }

        action transferMedicationToNeedle {
            in item medicationFromCartridge : MedicationSolution;
            out item medicationToNeedle : MedicationSolution;
        }
    }

    part def PrefilledMedicationCartridge {
        attribute labeledVolume_mL : Milliliter = 2.0;
        attribute residualVolume_mL : Milliliter;
        attribute stopperTravel_mm : Millimeter;
        attribute glassBodyIntegrity : BooleanFlag;
        attribute tamperSealIntact : BooleanFlag;

        item medication : MedicationSolution {
            attribute medicationName = "injectable medication";
            attribute concentration_mg_per_mL = 10.0;
            attribute volume_mL = 2.0;
            attribute sterilityMaintained = true;
            attribute particulateFree = true;
        }

        port medicationPort {
            out item cartridgeMedication : MedicationSolution;
        }

        state def CartridgeState {
            state sealed;
            state seated;
            state dispensing;
            state empty;
            state rejected;

            transition first sealed then seated
                accept seatedInHolder
                if glassBodyIntegrity and tamperSealIntact;

            transition first sealed then rejected
                accept integrityCheckFailed
                if not glassBodyIntegrity or not tamperSealIntact;

            transition first seated then dispensing
                accept plungerForceApplied;

            transition first dispensing then empty
                accept residualVolumeDepleted;
        }
    }

    part def PlungerRod {
        attribute axialPosition_mm : Millimeter;
        attribute travelLimit_mm : Millimeter = 45.0;
        attribute appliedForce_N : Newton;
        attribute locked : BooleanFlag;

        port forceInput : UserInputPort;
        port positionPort {
            out attribute axialPosition_mm : Millimeter;
        }

        action convertUserForceToStopperTravel {
            in item force : UserForce;
            out attribute stopperDisplacement_mm : Millimeter;
        }

        action advanceStopper {
            in attribute stopperDisplacement_mm : Millimeter;
            out item dispensedDose : Dose;
        }
    }

    part def NeedleAssembly {
        attribute needleGauge : Integer = 22;
        attribute needleLength_mm : Millimeter = 38.0;
        attribute sterileCapRemoved : BooleanFlag;
        attribute attachedToHolder : BooleanFlag;
        attribute lumenPatent : BooleanFlag;

        port needleInterface : NeedleInterfacePort;
        port patientPort : PatientInterfacePort;
        port statusPort {
            out item needleStatus : InjectionStatus;
        }

        action attachNeedle {
            out item status : InjectionStatus;
        }

        action deliverMedication {
            in item medicationFromHolder : MedicationSolution;
            out item medicationToPatient : MedicationSolution;
        }
    }

    part def DoseIndicator {
        attribute indicatedVolume_mL : Milliliter;
        attribute scaleResolution_mL : Milliliter = 0.1;
        attribute visibleToUser : BooleanFlag;

        port plungerPositionPort {
            in attribute axialPosition_mm : Millimeter;
        }

        action computeIndicatedDose {
            in attribute axialPosition_mm : Millimeter;
            out item dose : Dose;
        }
    }

    part def SafetyInterlock {
        attribute preventsInjectionWhenNeedleAbsent : BooleanFlag = true;
        attribute preventsInjectionWhenCartridgeUnseated : BooleanFlag = true;
        attribute faultDetected : BooleanFlag;

        port holderStatusPort {
            in item holderStatus : InjectionStatus;
        }

        port needleStatusPort {
            in item needleStatus : InjectionStatus;
        }

        action evaluateReadiness {
            in item holderStatus : InjectionStatus;
            in item needleStatus : InjectionStatus;
            out item readiness : InjectionStatus;
        }
    }

    action def PrepareCarpuject {
        in part system : CarpujectSystem;
        out item readiness : InjectionStatus;

        first start;
        then verifyCartridge {
            out item status : InjectionStatus;
        }
        then attachNeedle {
            out item status : InjectionStatus;
        }
        then confirmReady {
            out item readiness : InjectionStatus;
        }
    }

    action def AdministerMedication {
        in part system : CarpujectSystem;
        in item prescribedDose : Dose;
        in item appliedForce : UserForce;
        out item deliveredDose : Dose;
        out item patientMedication : MedicationSolution;

        first start;
        then checkReadiness {
            out item status : InjectionStatus;
        }
        then depressPlunger {
            in item force = appliedForce;
            out item dispensedDose : Dose;
        }
        then deliverThroughNeedle {
            out item medicationToPatient : MedicationSolution;
        }
        then verifyCompletion {
            out item deliveredDose : Dose;
        }
    }

    state def CarpujectOperationalState {
        state packaged;
        state prepared;
        state needleAttached;
        state readyForInjection;
        state injecting;
        state doseDelivered;
        state disposed;
        state fault;

        transition first packaged then prepared
            accept cartridgeInserted;

        transition first prepared then needleAttached
            accept sterileNeedleAttached;

        transition first needleAttached then readyForInjection
            accept readinessConfirmed;

        transition first readyForInjection then injecting
            accept plungerDepressed;

        transition first injecting then doseDelivered
            accept orderedDoseDelivered;

        transition first doseDelivered then disposed
            accept sharpsDisposed;

        transition first prepared then fault
            accept cartridgeFaultDetected;

        transition first needleAttached then fault
            accept needleFaultDetected;

        transition first readyForInjection then fault
            accept unsafeConditionDetected;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Carpuject system shall enable a clinician to manually administer a controlled dose of medication from a prefilled cartridge to a patient through a sterile needle. */
    }

    requirement def DoseAccuracyRequirement {
        attribute tolerance_percent : Percent = 5.0;
        doc /* The delivered medication volume shall be within the specified tolerance of the ordered dose when operated within the allowed force range. */
    }

    requirement def SterilityRequirement {
        doc /* The medication path from sealed cartridge through needle outlet shall preserve sterility until delivery to the patient. */
    }

    requirement def ReadinessRequirement {
        doc /* The system shall indicate readiness only when the cartridge is seated, the needle is attached, and no safety fault is detected. */
    }

    requirement def ForceRequirement {
        attribute minimumForce_N : Newton = 8.0;
        attribute maximumForce_N : Newton = 45.0;
        doc /* The plunger mechanism shall dispense medication under manual axial force within the specified operating range. */
    }

    requirement def SingleUseDisposalRequirement {
        doc /* After dose delivery, the cartridge, needle, and medication-contacting flow path shall be treated as single-use disposable components. */
    }

    satisfy PrimaryFunctionRequirement by CarpujectSystem;
    satisfy DoseAccuracyRequirement by PlungerRod;
    satisfy DoseAccuracyRequirement by DoseIndicator;
    satisfy SterilityRequirement by PrefilledMedicationCartridge;
    satisfy SterilityRequirement by NeedleAssembly;
    satisfy ReadinessRequirement by SafetyInterlock;
    satisfy ForceRequirement by PlungerRod;
    satisfy SingleUseDisposalRequirement by PrefilledMedicationCartridge;
    satisfy SingleUseDisposalRequirement by NeedleAssembly;

    constraint def DoseWithinTolerance {
        in ordered_mL : Milliliter;
        in delivered_mL : Milliliter;
        in tolerance_percent : Percent;

        ordered_mL > 0.0 and
        abs(delivered_mL - ordered_mL) <= ordered_mL * tolerance_percent / 100.0;
    }

    constraint def OperatingForceWithinRange {
        in force_N : Newton;
        in minimum_N : Newton;
        in maximum_N : Newton;

        force_N >= minimum_N and force_N <= maximum_N;
    }

    constraint def InjectionReadiness {
        in needleAttached : BooleanFlag;
        in cartridgeSeated : BooleanFlag;
        in safetyRiskDetected : BooleanFlag;

        needleAttached and cartridgeSeated and not safetyRiskDetected;
    }

}