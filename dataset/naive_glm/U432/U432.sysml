package UnnasBootSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    value type PressureValue :> Real {
        :>> unit = 'Pa';
    }

    value type LengthValue :> Real {
        :>> unit = 'm';
    }

    value type AreaValue :> Real {
        :>> unit = 'm^2';
    }

    value type VolumeValue :> Real {
        :>> unit = 'm^3';
    }

    value type MassValue :> Real {
        :>> unit = 'kg';
    }

    value type DurationValue :> Real {
        :>> unit = 'd';
    }

    value type FlowRateValue :> Real {
        :>> unit = 'm^3/s';
    }

    value type ConcentrationValue :> Real {
        :>> unit = 'g/m^2';
    }

    value type TemperatureValue :> Real {
        :>> unit = 'K';
    }

    // ===== Item Types =====

    item def Exudate {
        attribute volume : VolumeValue;
        attribute absorptionCapacity : VolumeValue;
    }

    item def ZincOxidePaste {
        attribute concentration : ConcentrationValue;
        attribute antimicrobialEfficacy : Real; // normalized 0..1
    }

    item def VenousBlood {
        attribute volume : VolumeValue;
        attribute pressure : PressureValue;
        attribute oxygenSaturation : Real; // fraction 0..1
    }

    item def WoundFluid {
        attribute volume : VolumeValue;
        attribute bacterialLoad : Real; // CFU count proxy
    }

    // ===== Port Definitions =====

    port def WoundContactPort {
        in exudate : Exudate;
        out zincIons : ZincOxidePaste;
    }

    port def CompressionInterfacePort {
        out appliedPressure : PressureValue;
    }

    port def MuscleInteractionPort {
        in externalResistance : PressureValue;
        out muscleContractionPressure : PressureValue;
    }

    port def VenousReturnPort {
        out venousBlood : VenousBlood;
    }

    port def SkinSurfacePort {
        in compressionPressure : PressureValue;
        in zincPaste : ZincOxidePaste;
        out woundExudate : Exudate;
    }

    // ===== Requirements =====

    requirement def ShallProvideSustainedCompression {
        doc /* The compression layer shall apply sustained pressure to the lower leg. */
        attribute targetPressure : PressureValue = 4000.0; // ~40 mmHg
        subject compressionLayer : CompressionLayer;
        constraint { compressionLayer.appliedPressure >= targetPressure }
    }

    requirement def ShallMaintainMoistEnvironment {
        doc /* The primary layer shall maintain a moist healing environment at the wound site. */
        subject primaryLayer : PrimaryZincOxideGauze;
        constraint { primaryLayer.paste.concentration > 0.0 }
    }

    requirement def ShallProvideAntimicrobialEffect {
        doc /* The zinc oxide paste shall provide antimicrobial properties. */
        subject paste : ZincOxidePaste;
        constraint { paste.antimicrobialEfficacy >= 0.7 }
    }

    requirement def ShallAbsorbExudate {
        doc /* The primary layer shall absorb excess wound exudate. */
        subject primaryLayer : PrimaryZincOxideGauze;
        constraint { primaryLayer.absorbedExudate.volume <= primaryLayer.maxAbsorptionCapacity }
    }

    requirement def ShallFormSemiRigidBoot {
        doc /* The outer layer shall harden to form a semi-rigid, non-elastic boot. */
        subject outerLayer : OuterLayer;
        constraint { outerLayer.elasticity == 0.0 }
        constraint { outerLayer.hardened == true }
    }

    requirement def ShallEnhanceCalfMusclePump {
        doc /* The system shall enhance the calf muscle pump action during walking. */
        subject boot : UnnasBootDressing;
        constraint { boot.dynamicPressure > boot.staticPressure }
    }

    requirement def ShallReduceEdema {
        doc /* The system shall reduce lower leg edema over the treatment period. */
        subject patient : Patient;
        constraint { patient.leg.edemaVolume_final < patient.leg.edemaVolume_initial }
    }

    requirement def ShallPromoteUlcerHealing {
        doc /* The system shall promote healing of the venous ulcer. */
        subject patient : Patient;
        constraint { patient.leg.ulcer.area_final < patient.leg.ulcer.area_initial }
    }

    requirement def ShallBeWearableForOneWeek {
        doc /* The boot shall be wearable for approximately one week before removal. */
        subject boot : UnnasBootDressing;
        attribute minWearDuration : DurationValue = 5.0;
        attribute maxWearDuration : DurationValue = 7.0;
        constraint { boot.wearDuration >= minWearDuration and boot.wearDuration <= maxWearDuration }
    }

    requirement UnnasBootRequirements {
        satisfy ShallProvideSustainedCompression;
        satisfy ShallMaintainMoistEnvironment;
        satisfy ShallProvideAntimicrobialEffect;
        satisfy ShallAbsorbExudate;
        satisfy ShallFormSemiRigidBoot;
        satisfy ShallEnhanceCalfMusclePump;
        satisfy ShallReduceEdema;
        satisfy ShallPromoteUlcerHealing;
        satisfy ShallBeWearableForOneWeek;
    }

    // ===== Part Definitions =====

    part def PrimaryZincOxideGauze {
        attribute layerThickness : LengthValue = 0.002;
        attribute maxAbsorptionCapacity : VolumeValue = 0.00005; // 50 mL
        attribute absorbedExudate : Exudate;
        attribute paste : ZincOxidePaste;
        port woundContact : WoundContactPort;
        port outerSurface : CompressionInterfacePort;

        action def AbsorbExudate {
            in exudateIn : Exudate;
            out absorbed : Exudate;
            // Absorption logic
        }

        action def ReleaseZincIons {
            out zincOut : ZincOxidePaste;
        }

        perform AbsorbExudate;
        perform ReleaseZincIons;
    }

    part def CompressionLayer {
        attribute elasticity : Real = 0.3;
        attribute appliedPressure : PressureValue = 4000.0;
        attribute width : LengthValue = 0.10;
        attribute layerThickness : LengthValue = 0.0015;
        port innerSurface : CompressionInterfacePort;
        port outerSurface : CompressionInterfacePort;

        action def ApplyCompression {
            out pressure : PressureValue;
        }

        perform ApplyCompression;
    }

    part def OuterLayer {
        attribute elasticity : Real = 0.0;
        attribute hardened : Boolean = false;
        attribute hardeningTime : DurationValue = 0.04; // ~1 hour
        attribute layerThickness : LengthValue = 0.003;
        port innerSurface : CompressionInterfacePort;
        port externalSurface : CompressionInterfacePort;

        state def HardeningStates {
            entry; then Applied;
            state Applied {
                entry; then Hardening;
            }
            state Hardening {
                transition Hardening to Hardened
                    when hardeningTime <= 0.0;
            }
            state Hardened {
                entry { hardened = true; }
            }
        }

        exhibit HardeningStates;

        action def Harden {
            in duration : DurationValue;
            out isHardened : Boolean;
        }

        perform Harden;
    }

    part def UnnasBootDressing {
        attribute staticPressure : PressureValue;
        attribute dynamicPressure : PressureValue;
        attribute wearDuration : DurationValue;
        attribute applicationDate : String;
        attribute removalDate : String;

        part primaryLayer : PrimaryZincOxideGauze {
            :>> paste : ZincOxidePaste {
                :>> concentration = 15.0; // g/m^2
                :>> antimicrobialEfficacy = 0.85;
            }
            :>> absorbedExudate : Exudate {
                :>> volume = 0.0;
                :>> absorptionCapacity = 0.00005;
            }
        }

        part compressionLayer : CompressionLayer {
            :>> appliedPressure = 4000.0;
        }

        part outerLayer : OuterLayer;

        connection primaryToCompression connect primaryLayer.outerSurface to compressionLayer.innerSurface;
        connection compressionToOuter connect compressionLayer.outerSurface to outerLayer.innerSurface;

        port woundInterface : WoundContactPort;
        port externalSurface : CompressionInterfacePort;

        // Lifecycle state machine
        state def BootLifecycle {
            entry; then ReadyForApplication;
            state ReadyForApplication {
                transition ReadyForApplication to Applying
                    when applicationStarted;
            }
            state Applying {
                entry { /* Apply primary layer, then compression, then outer */ }
                do applyLayers;
                transition Applying to Hardening
                    when layersApplied;
            }
            state Hardening {
                entry { /* Outer layer hardens */ }
                do outerLayer.Harden;
                transition Hardening to ActiveTherapy
                    when outerLayer.hardened == true;
            }
            state ActiveTherapy {
                entry { /* Patient wears boot, walking provides therapy */ }
                do monitorTherapy;
                transition ActiveTherapy to ReadyForRemoval
                    when wearDuration >= 5.0;
            }
            state ReadyForRemoval {
                entry { /* Remove boot for wound assessment */ }
                do removeBoot;
                transition ReadyForRemoval to ReadyForApplication
                    when bootRemoved;
            }

            action applyLayers {
                // Sequential application of layers
            }
            action monitorTherapy {
                // Monitor wound healing and compression
            }
            action removeBoot {
                // Remove and assess
            }
        }

        exhibit BootLifecycle;

        satisfy ShallProvideSustainedCompression by compressionLayer;
        satisfy ShallMaintainMoistEnvironment by primaryLayer;
        satisfy ShallProvideAntimicrobialEffect by primaryLayer.paste;
        satisfy ShallAbsorbExudate by primaryLayer;
        satisfy ShallFormSemiRigidBoot by outerLayer;
        satisfy ShallEnhanceCalfMusclePump;
        satisfy ShallBeWearableForOneWeek;
    }

    part def VenousUlcer {
        attribute area_initial : AreaValue = 0.001; // 10 cm^2
        attribute area_final : AreaValue;
        attribute location : String = "lower leg";
        attribute depth : LengthValue;
        port woundSurface : SkinSurfacePort;
    }

    part def DeepVein {
        attribute bloodVolume : VolumeValue;
        attribute venousPressure : PressureValue;
        attribute bloodFlow : FlowRateValue;
        port venousOutflow : VenousReturnPort;
    }

    part def CalfMuscle {
        attribute contractionForce : PressureValue;
        attribute restingPressure : PressureValue = 2000.0;
        attribute contractedPressure : PressureValue = 8000.0;
        port muscleAction : MuscleInteractionPort;

        action def Contract {
            in externalResistance : PressureValue;
            out generatedPressure : PressureValue;
            // When outer layer is rigid, contraction generates high pressure
        }

        action def Relax {
            out restingPressureOut : PressureValue;
        }

        perform Contract;
        perform Relax;

        state def MuscleActivityStates {
            entry; then Relaxed;
            state Relaxed {
                transition Relaxed to Contracted
                    when walking == true;
            }
            state Contracted {
                transition Contracted to Relaxed
                    when walking == false;
            }
        }

        exhibit MuscleActivityStates;
    }

    part def LowerLeg {
        attribute edemaVolume_initial : VolumeValue = 0.0003; // 300 mL excess
        attribute edemaVolume_final : VolumeValue;
        attribute circumference : LengthValue = 0.30;

        part ulcer : VenousUlcer {
            :>> area_initial = 0.001;
            :>> area_final = 0.0003;
            :>> depth = 0.002;
        }

        part deepVein : DeepVein {
            :>> bloodVolume = 0.0001;
            :>> venousPressure = 6000.0;
            :>> bloodFlow = 0.000001;
        }

        part calfMuscle : CalfMuscle {
            :>> contractionForce = 8000.0;
        }

        port skinSurface : SkinSurfacePort;
        port venousReturn : VenousReturnPort;

        connection ulcerToVein connect ulcer.woundSurface to deepVein.venousOutflow;
    }

    part def VenousSystem {
        attribute insufficiencySeverity : Real = 0.7; // fraction
        attribute valveCompetence : Real = 0.3;
        attribute venousReturnRate : FlowRateValue;

        part superficialVeins : DeepVein {
            :>> bloodVolume = 0.0002;
            :>> venousPressure = 5000.0;
        }

        part deepVeins : DeepVein {
            :>> bloodVolume = 0.00015;
            :>> venousPressure = 6500.0;
        }

        port systemicReturn : VenousReturnPort;
    }

    part def Patient {
        attribute walking : Boolean = false;
        attribute age : Integer = 65;
        attribute bodyMassIndex : Real = 28.0;
        attribute hasVenousInsufficiency : Boolean = true;

        part leg : LowerLeg {
            :>> edemaVolume_initial = 0.0003;
            :>> edemaVolume_final = 0.0001;
        }

        part venousSystem : VenousSystem {
            :>> insufficiencySeverity = 0.7;
            :>> valveCompetence = 0.3;
            :>> venousReturnRate = 0.0000008;
        }

        action def Walk {
            out calfPumpActivation : Boolean;
            // Walking activates calf muscle pump
        }

        action def Rest {
            out calfPumpActivation : Boolean;
        }

        perform Walk;
        perform Rest;

        state def PatientActivityStates {
            entry; then Resting;
            state Resting {
                entry { walking = false; }
                transition Resting to Walking
                    when ambulationStarted;
            }
            state Walking {
                entry { walking = true; }
                do Walk;
                transition Walking to Resting
                    when ambulationStopped;
            }
        }

        exhibit PatientActivityStates;

        satisfy ShallReduceEdema;
        satisfy ShallPromoteUlcerHealing;
    }

    // ===== Top-level Context Part =====

    part UnnasBootTherapyContext {

        part patient : Patient;

        part boot : UnnasBootDressing {
            :>> staticPressure = 4000.0;
            :>> dynamicPressure = 8000.0;
            :>> wearDuration = 7.0;
        }

        // Connect boot wound interface to patient's leg skin surface
        connection bootToWound connect boot.woundInterface to patient.leg.skinSurface;

        // Connect boot external surface to calf muscle interaction
        connection bootToMuscle connect boot.externalSurface to patient.leg.calfMuscle.muscleAction;

        // Connect calf muscle to deep vein for pumping action
        connection muscleToVein connect patient.leg.calfMuscle.muscleAction to patient.leg.deepVein.venousOutflow;

        // Connect deep vein to venous system
        connection veinToSystem connect patient.leg.deepVein.venousOutflow to patient.venousSystem.systemicReturn;

        // Therapeutic process action
        action def TherapeuticCycle {
            in patientIn : Patient;
            in bootIn : UnnasBootDressing;

            action applyBoot {
                out bootApplied : UnnasBootDressing;
            }
            action hardenBoot {
                in boot : UnnasBootDressing;
                out hardenedBoot : UnnasBootDressing;
            }
            action activeTherapyPeriod {
                in boot : UnnasBootDressing;
                in patient : Patient;
                out healingProgress : Real;
            }
            action removeBoot {
                in boot : UnnasBootDressing;
                out woundAssessment : VenousUlcer;
            }
            action reassessAndReapply {
                in ulcer : VenousUlcer;
                out decision : String;
            }

            flow applyBoot.bootApplied to hardenBoot.boot;
            flow hardenBoot.hardenedBoot to activeTherapyPeriod.boot;
            flow activeTherapyPeriod.healingProgress to removeBoot;
            flow removeBoot.woundAssessment to reassessAndReapply.ulcer;
        }

        perform TherapeuticCycle {
            in patientIn = patient;
            in bootIn = boot;
        }

        satisfy UnnasBootRequirements;
    }

}
