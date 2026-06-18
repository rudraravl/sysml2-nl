package InhalerSpacerHighLevelModel {
    import ScalarValues::*;

    attribute def Volume_mL :> Real {
        attribute unitSymbol : String = "mL";
    }

    attribute def FlowRate_L_per_min :> Real {
        attribute unitSymbol : String = "L/min";
    }

    attribute def Pressure_Pa :> Real {
        attribute unitSymbol : String = "Pa";
    }

    attribute def Time_s :> Real {
        attribute unitSymbol : String = "s";
    }

    attribute def Length_um :> Real {
        attribute unitSymbol : String = "um";
    }

    attribute def Mass_ug :> Real {
        attribute unitSymbol : String = "ug";
    }

    attribute def Fraction_0_to_1 :> Real {
        attribute unitSymbol : String = "1";
    }

    attribute def Temperature_C :> Real {
        attribute unitSymbol : String = "degC";
    }

    attribute def RelativeHumidity_percent :> Real {
        attribute unitSymbol : String = "%";
    }

    enum def ValvePosition {
        enum closed;
        enum open;
        enum partiallyOpen;
    }

    enum def DoseCloudStatus {
        enum nonePresent;
        enum freshlyActuated;
        enum suspended;
        enum partiallyInhaled;
        enum cleared;
        enum expired;
    }

    enum def PatientBreathingPhase {
        enum notBreathingThroughSpacer;
        enum inhaling;
        enum breathHold;
        enum exhaling;
    }

    item def MeteredMedicationDose {
        attribute nominalMedicationMass : Mass_ug = 100.0;
        attribute emittedFineParticleFraction : Fraction_0_to_1 = 0.42;
        attribute nominalParticleDiameter : Length_um = 3.5;
    }

    item def AerosolMedicationCloud {
        attribute medicationMass : Mass_ug;
        attribute fineParticleMassFraction : Fraction_0_to_1;
        attribute massMedianAerodynamicDiameter : Length_um;
        attribute cloudAge : Time_s;
        attribute status : DoseCloudStatus;
    }

    item def Air {
        attribute temperature : Temperature_C = 22.0;
        attribute relativeHumidity : RelativeHumidity_percent = 45.0;
    }

    item def AerosolAirMixture {
        item aerosol : AerosolMedicationCloud;
        item carrierAir : Air;
        attribute volumetricFlowRate : FlowRate_L_per_min;
        attribute pressureRelativeToAmbient : Pressure_Pa;
    }

    item def ExhaledBreath {
        attribute volumetricFlowRate : FlowRate_L_per_min;
        attribute temperature : Temperature_C = 34.0;
        attribute relativeHumidity : RelativeHumidity_percent = 95.0;
    }

    item def DepositedMedication {
        attribute depositedMass : Mass_ug;
        attribute dominantParticleDiameter : Length_um;
    }

    item def ActuationCommand {
        attribute commandDuration : Time_s = 0.25;
    }

    item def InspiratoryEffort {
        attribute peakInspiratoryFlow : FlowRate_L_per_min;
        attribute inhalationDuration : Time_s;
    }

    port def MeteredDoseInletPort {
        in item doseCloud : AerosolMedicationCloud;
        in item actuationCommand : ActuationCommand;
    }

    port def AerosolFlowPort {
        inout item mixture : AerosolAirMixture;
        attribute localGaugePressure : Pressure_Pa;
        attribute localFlowRate : FlowRate_L_per_min;
    }

    port def PatientBreathingPort {
        out item inhaledMixture : AerosolAirMixture;
        in item exhaledBreath : ExhaledBreath;
        in item inspiratoryEffort : InspiratoryEffort;
        attribute breathingPhase : PatientBreathingPhase;
    }

    port def AmbientVentPort {
        out item ventedBreath : ExhaledBreath;
        out item lostAerosol : AerosolAirMixture;
        attribute ventPressureDrop : Pressure_Pa;
    }

    port def AmbientAirPort {
        inout item ambientAir : Air;
        attribute ambientPressureReference : Pressure_Pa = 0.0;
    }

    port def MechanicalFitPort {
        attribute insertionDepth : Length_um;
        attribute leakageFraction : Fraction_0_to_1;
    }

    constraint def ChamberVolumeRange {
        in volume : Volume_mL;
        require constraint { volume >= 120.0 and volume <= 250.0 }
    }

    constraint def ValveOpeningRule {
        in upstreamPressure : Pressure_Pa;
        in downstreamPressure : Pressure_Pa;
        in crackingPressure : Pressure_Pa;
        require constraint { upstreamPressure - downstreamPressure >= crackingPressure }
    }

    constraint def AcceptableDoseDelivery {
        in deliveredFineParticleFraction : Fraction_0_to_1;
        in throatDepositionFraction : Fraction_0_to_1;
        require constraint { deliveredFineParticleFraction >= 0.30 and throatDepositionFraction <= 0.25 }
    }

    constraint def LowResistanceBreathing {
        in pressureDropAtThirtyLpm : Pressure_Pa;
        require constraint { pressureDropAtThirtyLpm <= 80.0 }
    }

    action def ReceiveMeteredDose {
        in item incomingDose : AerosolMedicationCloud;
        out item capturedCloud : AerosolMedicationCloud;
        attribute captureDuration : Time_s = 0.30;
    }

    action def DecelerateAndSuspendAerosol {
        in item capturedCloud : AerosolMedicationCloud;
        out item suspendedMixture : AerosolAirMixture;
        out item impactedLargeParticles : DepositedMedication;
        attribute nominalResidenceTime : Time_s = 8.0;
        attribute largeParticleCutoffDiameter : Length_um = 5.0;
    }

    action def RouteInhaledDose {
        in item suspendedMixture : AerosolAirMixture;
        in item inspiratoryEffort : InspiratoryEffort;
        out item patientDeliveredMixture : AerosolAirMixture;
        attribute intendedInspiratoryFlow : FlowRate_L_per_min = 30.0;
        attribute intendedInhalationDuration : Time_s = 4.0;
    }

    action def BlockReverseFlow {
        in item exhaledBreath : ExhaledBreath;
        out item divertedBreath : ExhaledBreath;
        attribute reverseFlowBlockedFraction : Fraction_0_to_1 = 0.98;
    }

    action def VentExhalation {
        in item divertedBreath : ExhaledBreath;
        out item ventedBreath : ExhaledBreath;
        attribute ventingPressureDrop : Pressure_Pa = 55.0;
    }

    action def InhalerSpacerPrimaryFunction {
        in item meteredDose : AerosolMedicationCloud;
        in item patientEffort : InspiratoryEffort;
        in item exhalation : ExhaledBreath;
        out item deliveredRespirableAerosol : AerosolAirMixture;
        out item ventedExhalation : ExhaledBreath;
        out item retainedDeposits : DepositedMedication;

        action receiveDose : ReceiveMeteredDose;
        action suspendDose : DecelerateAndSuspendAerosol;
        action deliverDose : RouteInhaledDose;
        action preventReverseFlow : BlockReverseFlow;
        action ventBreath : VentExhalation;

        flow meteredDose to receiveDose.incomingDose;
        flow receiveDose.capturedCloud to suspendDose.capturedCloud;
        flow suspendDose.suspendedMixture to deliverDose.suspendedMixture;
        flow patientEffort to deliverDose.inspiratoryEffort;
        flow deliverDose.patientDeliveredMixture to deliveredRespirableAerosol;
        flow suspendDose.impactedLargeParticles to retainedDeposits;
        flow exhalation to preventReverseFlow.exhaledBreath;
        flow preventReverseFlow.divertedBreath to ventBreath.divertedBreath;
        flow ventBreath.ventedBreath to ventedExhalation;

        succession first receiveDose then suspendDose;
        succession first suspendDose then deliverDose;
        succession first preventReverseFlow then ventBreath;
    }

    state def SpacerOperationalStates {
        in item doseCommand : ActuationCommand;
        in item inspiratoryEffort : InspiratoryEffort;
        in item exhaledBreath : ExhaledBreath;

        state Ready {
            entry action {
                attribute chamberCloudStatus : DoseCloudStatus = DoseCloudStatus::nonePresent;
            }
        }

        state DoseCaptured {
            entry action {
                attribute chamberCloudStatus : DoseCloudStatus = DoseCloudStatus::freshlyActuated;
            }
        }

        state AerosolSuspended {
            do action {
                attribute chamberCloudStatus : DoseCloudStatus = DoseCloudStatus::suspended;
                attribute suspensionLimit : Time_s = 10.0;
            }
        }

        state InhalationDelivery {
            do action {
                attribute breathingPhase : PatientBreathingPhase = PatientBreathingPhase::inhaling;
            }
        }

        state ExhalationVenting {
            do action {
                attribute breathingPhase : PatientBreathingPhase = PatientBreathingPhase::exhaling;
            }
        }

        state Cleared {
            entry action {
                attribute chamberCloudStatus : DoseCloudStatus = DoseCloudStatus::cleared;
            }
        }

        transition readyToDoseCaptured first Ready then DoseCaptured accept doseCommand;
        transition doseCapturedToSuspended first DoseCaptured then AerosolSuspended;
        transition suspendedToDelivery first AerosolSuspended then InhalationDelivery accept inspiratoryEffort;
        transition deliveryToCleared first InhalationDelivery then Cleared;
        transition clearedToReady first Cleared then Ready;
        transition deliveryToExhalation first InhalationDelivery then ExhalationVenting accept exhaledBreath;
        transition exhalationToReady first ExhalationVenting then Ready;
    }

    part def MeteredDoseInhaler {
        attribute meteredDoseMass : Mass_ug = 100.0;
        attribute plumeDuration : Time_s = 0.25;
        attribute initialPlumeParticleDiameter : Length_um = 7.0;
        attribute outletLeakageFraction : Fraction_0_to_1 = 0.02;

        port doseOutlet : MeteredDoseInletPort;
        port canisterFit : MechanicalFitPort;

        action actuate {
            out item emittedCloud : AerosolMedicationCloud;
            attribute actuationTime : Time_s = 0.25;
        }
    }

    part def InletAdapter {
        attribute elastomerSealLeakageFraction : Fraction_0_to_1 = 0.03;
        attribute compatibleMouthpieceWidth : Length_um = 22000.0;
        attribute internalDeadVolume : Volume_mL = 8.0;

        port inhalerSide : MeteredDoseInletPort;
        port chamberSide : AerosolFlowPort;
        port fitInterface : MechanicalFitPort;

        action guidePlume {
            in item doseCloud : AerosolMedicationCloud;
            out item centeredCloud : AerosolMedicationCloud;
        }
    }

    part def AntiStaticHoldingChamber {
        attribute nominalInternalVolume : Volume_mL = 145.0;
        attribute maximumInternalVolume : Volume_mL = 160.0;
        attribute minimumInternalVolume : Volume_mL = 130.0;
        attribute internalDiameter : Length_um = 52000.0;
        attribute internalLength : Length_um = 125000.0;
        attribute wallDepositionFraction : Fraction_0_to_1 = 0.18;
        attribute electrostaticRetentionFraction : Fraction_0_to_1 = 0.04;
        attribute usefulSuspensionTime : Time_s = 8.0;

        port inlet : AerosolFlowPort;
        port outlet : AerosolFlowPort;

        constraint volumeIsTherapeutic : ChamberVolumeRange {
            in volume = nominalInternalVolume;
        }

        action slowPlumeAndMix {
            in item inletCloud : AerosolMedicationCloud;
            out item suspendedMixture : AerosolAirMixture;
            out item wallDeposit : DepositedMedication;
        }
    }

    part def InspiratoryOneWayValve {
        attribute crackingPressure : Pressure_Pa = 12.0;
        attribute pressureDropAt30Lpm : Pressure_Pa = 45.0;
        attribute closedReverseLeakageFraction : Fraction_0_to_1 = 0.01;
        attribute openAreaEquivalentDiameter : Length_um = 18000.0;
        attribute position : ValvePosition = ValvePosition::closed;

        port chamberSide : AerosolFlowPort;
        port patientSide : AerosolFlowPort;

        constraint lowResistance : LowResistanceBreathing {
            in pressureDropAtThirtyLpm = pressureDropAt30Lpm;
        }

        action openOnInhalation {
            in item inspiratoryEffort : InspiratoryEffort;
            out item passedMixture : AerosolAirMixture;
        }

        action closeOnExhalation {
            in item exhaledBreath : ExhaledBreath;
        }
    }

    part def ExpiratoryOneWayValve {
        attribute crackingPressure : Pressure_Pa = 20.0;
        attribute pressureDropAt30Lpm : Pressure_Pa = 55.0;
        attribute inwardLeakageFraction : Fraction_0_to_1 = 0.02;
        attribute position : ValvePosition = ValvePosition::closed;

        port patientSide : PatientBreathingPort;
        port ambientSide : AmbientVentPort;

        action openOnExhalation {
            in item exhaledBreath : ExhaledBreath;
            out item ventedBreath : ExhaledBreath;
        }
    }

    part def Mouthpiece {
        attribute biteFlangeWidth : Length_um = 28000.0;
        attribute outletOvalHeight : Length_um = 15000.0;
        attribute outletOvalWidth : Length_um = 22000.0;
        attribute deadVolume : Volume_mL = 12.0;
        attribute patientSealLeakageFraction : Fraction_0_to_1 = 0.05;

        port valveSide : AerosolFlowPort;
        port patientInterface : PatientBreathingPort;

        action deliverToMouth {
            in item inhaledMixture : AerosolAirMixture;
            out item patientMixture : AerosolAirMixture;
        }
    }

    part def OptionalFaceMask {
        attribute maskDeadVolume : Volume_mL = 45.0;
        attribute sealLeakageFraction : Fraction_0_to_1 = 0.08;
        attribute intendedPatientAgeMinimumMonths : Real = 6.0;

        port mouthpieceSide : PatientBreathingPort;
        port patientFaceSide : PatientBreathingPort;
    }

    part def ExhalationVent {
        attribute ventSlotAreaEquivalentDiameter : Length_um = 12000.0;
        attribute ambientBackPressure : Pressure_Pa = 0.0;

        port valveSide : AmbientVentPort;
        port atmosphere : AmbientAirPort;

        action exhaustBreathToAmbient {
            in item ventedBreath : ExhaledBreath;
            out item ambientReleasedBreath : ExhaledBreath;
        }
    }

    part def Patient {
        attribute tidalVolume : Volume_mL = 500.0;
        attribute nominalPeakInspiratoryFlow : FlowRate_L_per_min = 30.0;
        attribute nominalInhalationDuration : Time_s = 4.0;
        attribute breathHoldAfterInhalation : Time_s = 10.0;

        port airwayPort : PatientBreathingPort;

        action inhaleFromSpacer {
            out item effort : InspiratoryEffort;
            in item deliveredMixture : AerosolAirMixture;
        }

        action exhaleThroughSpacer {
            out item exhaledBreath : ExhaledBreath;
        }
    }

    part def ClinicalRoomAir {
        attribute roomTemperature : Temperature_C = 22.0;
        attribute roomRelativeHumidity : RelativeHumidity_percent = 45.0;
        attribute roomPressureReference : Pressure_Pa = 0.0;

        port ambientInterface : AmbientAirPort;
    }

    part def InhalerSpacer {
        attribute deviceMass : Mass_ug = 85000.0;
        attribute nominalDeliveredFineParticleFraction : Fraction_0_to_1 = 0.36;
        attribute nominalThroatDepositionFraction : Fraction_0_to_1 = 0.20;
        attribute intendedDoseHoldTime : Time_s = 8.0;
        attribute maximumRecommendedDelayBeforeInhalation : Time_s = 10.0;

        port inhalerDoseIn : MeteredDoseInletPort;
        port patientMouthPort : PatientBreathingPort;
        port ambientExhaust : AmbientVentPort;

        part inletAdapter : InletAdapter;
        part chamber : AntiStaticHoldingChamber;
        part inspiratoryValve : InspiratoryOneWayValve;
        part mouthpiece : Mouthpiece;
        part expiratoryValve : ExpiratoryOneWayValve;
        part exhalationVent : ExhalationVent;

        connect doseEntry connect inhalerDoseIn to inletAdapter.inhalerSide;
        connect adapterToChamber connect inletAdapter.chamberSide to chamber.inlet;
        connect chamberToInspiratoryValve connect chamber.outlet to inspiratoryValve.chamberSide;
        connect inspiratoryValveToMouthpiece connect inspiratoryValve.patientSide to mouthpiece.valveSide;
        connect mouthpieceToPatientPort connect mouthpiece.patientInterface to patientMouthPort;
        connect patientPortToExpiratoryValve connect patientMouthPort to expiratoryValve.patientSide;
        connect expiratoryValveToVent connect expiratoryValve.ambientSide to exhalationVent.valveSide;
        connect ventToAmbientExhaust connect exhalationVent.valveSide to ambientExhaust;

        perform action primaryFunction : InhalerSpacerPrimaryFunction;
        exhibit state operatingState : SpacerOperationalStates;

        constraint deliveryPerformance : AcceptableDoseDelivery {
            in deliveredFineParticleFraction = nominalDeliveredFineParticleFraction;
            in throatDepositionFraction = nominalThroatDepositionFraction;
        }
    }

    part def InhalerSpacerTherapySetup {
        part mdi : MeteredDoseInhaler;
        part spacer : InhalerSpacer;
        part patient : Patient;
        part roomAir : ClinicalRoomAir;

        connect mdiToSpacer connect mdi.doseOutlet to spacer.inhalerDoseIn;
        connect spacerToPatient connect spacer.patientMouthPort to patient.airwayPort;
        connect spacerVentToRoom connect spacer.exhalationVent.atmosphere to roomAir.ambientInterface;
    }

    requirement def PrimaryFunctionRequirement {
        subject spacer : InhalerSpacer;

        attribute statement : String = "The inhaler spacer shall receive a metered-dose inhaler aerosol plume, hold and decelerate the aerosol in a chamber, reduce large-particle oropharyngeal deposition, and deliver a respirable medication-air mixture to the patient during inhalation while routing exhaled breath away from the chamber.";
        require constraint { spacer.chamber.nominalInternalVolume >= 120.0 and spacer.chamber.nominalInternalVolume <= 250.0 }
        require constraint { spacer.nominalDeliveredFineParticleFraction >= 0.30 }
        require constraint { spacer.nominalThroatDepositionFraction <= 0.25 }
        require constraint { spacer.maximumRecommendedDelayBeforeInhalation <= 10.0 }
    }

    requirement def LowBreathingResistanceRequirement {
        subject spacer : InhalerSpacer;

        attribute statement : String = "The spacer shall not impose excessive breathing resistance at an inspiratory flow of 30 L/min.";
        require constraint { spacer.inspiratoryValve.pressureDropAt30Lpm <= 80.0 }
    }

    requirement def OneWayFlowRequirement {
        subject spacer : InhalerSpacer;

        attribute statement : String = "The spacer shall permit inhaled flow from the chamber to the patient and shall inhibit patient exhalation from entering the aerosol holding chamber.";
        require constraint { spacer.inspiratoryValve.closedReverseLeakageFraction <= 0.02 }
        require constraint { spacer.expiratoryValve.inwardLeakageFraction <= 0.03 }
    }

    requirement def DoseRetentionRequirement {
        subject spacer : InhalerSpacer;

        attribute statement : String = "The chamber shall keep a clinically useful suspended aerosol cloud available long enough for coordinated patient inhalation.";
        require constraint { spacer.chamber.usefulSuspensionTime >= 8.0 }
        require constraint { spacer.intendedDoseHoldTime >= 8.0 }
    }

    requirement def PatientInterfaceLeakageRequirement {
        subject spacer : InhalerSpacer;

        attribute statement : String = "The mouthpiece interface shall maintain a sufficiently low leakage fraction during normal inhalation.";
        require constraint { spacer.mouthpiece.patientSealLeakageFraction <= 0.08 }
    }

    part therapyUseCase : InhalerSpacerTherapySetup {
        satisfy PrimaryFunctionRequirement by spacer;
        satisfy LowBreathingResistanceRequirement by spacer;
        satisfy OneWayFlowRequirement by spacer;
        satisfy DoseRetentionRequirement by spacer;
        satisfy PatientInterfaceLeakageRequirement by spacer;
    }
}
