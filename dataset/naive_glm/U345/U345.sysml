package PalatalObturatorSystem {

    import ScalarValues::*;

    // ============================================================
    // Value Types and Units
    // ============================================================
    value type LengthValue :> Real {
        unit m;
    }
    value type WidthValue :> Real {
        unit m;
    }
    value type DepthValue :> Real {
        unit m;
    }
    value type AreaValue :> Real {
        unit m2;
    }
    value type VolumeValue :> Real {
        unit m3;
    }
    value type MassValue :> Real {
        unit kg;
    }
    value type ForceValue :> Real {
        unit N;
    }
    value type PressureValue :> Real {
        unit Pa;
    }
    value type TemperatureValue :> Real {
        unit K;
    }
    value type TimeValue :> Real {
        unit s;
    }
    value type SoundPressureLevelValue :> Real {
        unit dB;
    }
    value type DimensionlessRatio :> Real;
    value type ComplianceValue :> Real {
        unit m3/N;
    }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def BiocompatibleMaterial {
        attribute biocompatible: Boolean = true;
        attribute medicalGrade: Boolean = true;
    }
    item def MedicalGradeAcrylic :> BiocompatibleMaterial {
        attribute flexuralStrength: PressureValue;
        attribute density: Real;
    }
    item def SiliconeElastomer :> BiocompatibleMaterial {
        attribute hardnessShoreA: Real;
        attribute maxElongation: DimensionlessRatio;
    }
    item def CobaltChromiumAlloy :> BiocompatibleMaterial {
        attribute yieldStrength: PressureValue;
        attribute elasticModulus: PressureValue;
    }
    item def DentalImpressionPaste;
    item def Food;
    item def Liquid;
    item def Air;
    item def SpeechSound;
    item def NasalDischarge;

    // ============================================================
    // Port Definitions
    // ============================================================
    port def OralInterface {
        attribute exposedArea: AreaValue;
        in airFlow: Air;
        in food: Food;
        in liquid: Liquid;
        in speechInput: SpeechSound;
    }
    port def NasalInterface {
        attribute projectedArea: AreaValue;
        out air: Air;
        out discharge: NasalDischarge;
    }
    port def ToothInterface {
        attribute contactForce: ForceValue;
        attribute toothIndex: Integer;
        in retentionLoad: ForceValue;
    }
    port def DefectInterface {
        attribute defectVolume: VolumeValue;
        attribute sealPressure: PressureValue;
    }
    port def MechanicalJoin {
        attribute jointStrength: ForceValue;
    }

    // ============================================================
    // Action Definitions
    // ============================================================
    action def ClinicalAssessment {
        in patient: Patient;
        in clinician: MaxillofacialProsthodontist;
        out defectMeasurements: VolumeValue;
        out archWidth: WidthValue;
        out archDepth: DepthValue;
        out remainingTeethCount: Integer;
    }

    action def ImpressionTaking {
        in patient: Patient;
        in impressionMaterial: DentalImpressionPaste;
        out dentalCast: VolumeValue;
    }

    action def Fabrication {
        in measurements: VolumeValue;
        in bodyMaterial: MedicalGradeAcrylic;
        in bulbMaterial: SiliconeElastomer;
        in claspMaterial: CobaltChromiumAlloy;
        out fabricatedDevice: PalatalObturator;
    }

    action def Fitting {
        in patient: Patient;
        in device: PalatalObturator;
        in clinician: MaxillofacialProsthodontist;
        out fittedDevice: PalatalObturator;
        attribute sealQuality: DimensionlessRatio;
    }

    action def Adjustment {
        in device: PalatalObturator;
        out adjustedDevice: PalatalObturator;
    }

    action def Maintenance {
        in device: PalatalObturator;
        out servicedDevice: PalatalObturator;
        attribute servicingTime: TimeValue;
    }

    action def SealEvaluation {
        in device: PalatalObturator;
        in patient: Patient;
        out sealPressure: PressureValue;
        out airLeakage: DimensionlessRatio;
        out liquidLeakage: DimensionlessRatio;
    }

    // ============================================================
    // Part Definitions
    // ============================================================
    part def Patient {
        attribute patientId: String;
        attribute defectEtiology: String;
        attribute defectVolume: VolumeValue;
        attribute defectWidth: WidthValue;
        attribute defectDepth: DepthValue;
        attribute remainingTeethCount: Integer;
        attribute speechIntelligibility: SoundPressureLevelValue;
        attribute regurgitationRate: DimensionlessRatio;
        attribute masticationEfficiency: DimensionlessRatio;

        port oralCavity: OralInterface;
        port nasalCavity: NasalInterface;
        port teeth: ToothInterface;
        port palatalDefect: DefectInterface;

        exhibit behavior PatientStates {
            state Initial {
                entry action initialize;
            }
            state Assessed {
                entry action recordAssessment;
            }
            state DeviceInUse {
                entry action beginUse;
            }
            state FollowUp {
                entry action scheduleReview;
            }
            transition Initial -> Assessed when assessmentComplete;
            transition Assessed -> DeviceInUse when obturatorFitted;
            transition DeviceInUse -> FollowUp when maintenanceDue;
            transition FollowUp -> DeviceInUse when adjustmentComplete;
        }
    }

    part def MaxillofacialProsthodontist {
        attribute clinicianId: String;
        attribute specialty: String = "Maxillofacial Prosthodontics";

        perform action assess;
        perform action takeImpression;
        perform action fitDevice;
        perform action adjustDevice;
        perform action evaluateSeal;
    }

    part def DentalLaboratory {
        attribute labId: String;
        attribute certifications: String;

        perform action fabricate;
        perform action adjust;
        perform action repair;
    }

    part def ObturatorBody {
        attribute mass: MassValue;
        attribute material: MedicalGradeAcrylic;
        attribute bodyLength: LengthValue;
        attribute bodyWidth: WidthValue;
        attribute bodyThickness: DepthValue;
        attribute surfaceFinish: DimensionlessRatio;

        port bulbReceptacle: MechanicalJoin;
        port claspMount[*]: MechanicalJoin;
        port oralFacingSurface: OralInterface;
        port palatalFacingSurface: DefectInterface;
    }

    part def ObturatorBulb {
        attribute mass: MassValue;
        attribute material: SiliconeElastomer;
        attribute projectedVolume: VolumeValue;
        attribute compressibility: ComplianceValue;
        attribute sealPressure: PressureValue;
        attribute maxOperatingTemperature: TemperatureValue;
        attribute hardnessShoreA: Real;

        port bodyMount: MechanicalJoin;
        port defectFill: DefectInterface;
        port nasalEnd: NasalInterface;
    }

    part def RetentionClasp {
        attribute mass: MassValue;
        attribute material: CobaltChromiumAlloy;
        attribute gripForce: ForceValue;
        attribute elasticRange: ForceValue;
        attribute targetToothIndex: Integer;
        attribute claspArmLength: LengthValue;
        attribute claspDiameter: LengthValue;

        port bodyMount: MechanicalJoin;
        port toothEngagement: ToothInterface;
    }

    part def PalatalObturator {
        attribute serialNumber: String;
        attribute totalMass: MassValue;
        attribute overallLength: LengthValue;
        attribute overallWidth: WidthValue;
        attribute overallDepth: DepthValue;
        attribute sealPressureRating: PressureValue;
        attribute fabricationDate: String;
        attribute serviceLife: TimeValue;

        port oralSurface: OralInterface;
        port bulbSeal: DefectInterface;
        port nasalProjection: NasalInterface;
        port toothContact: ToothInterface;

        part body: ObturatorBody;
        part bulb: ObturatorBulb;
        part clasps[*]: RetentionClasp;

        connection bodyBulbJoin connect body.bulbReceptacle to bulb.bodyMount;
        connection bodyClaspJoin[*] connect body.claspMount to clasps.bodyMount;
        connection bulbToDefect connect bulb.defectFill to bulbSeal;
        connection bodyToOral connect body.oralFacingSurface to oralSurface;
        connection claspToTooth[*] connect clasps.toothEngagement to toothContact;

        exhibit behavior ObturatorLifecycle {
            state Designed {
                entry action recordDesignSpecifications;
            }
            state Fabricated {
                entry action finalizeFabrication;
            }
            state InitialFitting {
                entry action beginFitting;
            }
            state InUse {
                entry action beginFunctionalUse;
            }
            state UnderMaintenance {
                entry action beginServicing;
            }
            state Adjusted {
                entry action applyAdjustment;
            }
            state Replaced {
                entry action retireDevice;
            }
            transition Designed -> Fabricated when fabricationComplete;
            transition Fabricated -> InitialFitting when deliveredToClinician;
            transition InitialFitting -> InUse when optimalFitAchieved;
            transition InUse -> UnderMaintenance when fitDeteriorates;
            transition UnderMaintenance -> Adjusted when adjustmentNeeded;
            transition Adjusted -> InUse when adjustmentComplete;
            transition InUse -> Replaced when endOfLife;
            transition UnderMaintenance -> Replaced when replacementRequired;
        }
    }

    // ============================================================
    // Connection Definitions
    // ============================================================
    connection def PatientObturatorOral {
        end patientOral: OralInterface;
        end obturatorOral: OralInterface;
    }
    connection def PatientObturatorDefect {
        end patientDefect: DefectInterface;
        end obturatorBulb: DefectInterface;
    }
    connection def PatientObturatorNasal {
        end patientNasal: NasalInterface;
        end obturatorNasal: NasalInterface;
    }
    connection def ClaspToothEngagement {
        end claspTooth: ToothInterface;
        end patientTooth: ToothInterface;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def RestorationOfOralNasalSeparation {
        doc /* The palatal obturator system shall restore the natural physical separation between the oral and nasal cavities for patients presenting with a palatal defect. */
    }
    requirement def SealEfficacy {
        doc /* The obturator bulb shall create a tight yet comfortable seal preventing passage of air, liquids, and food from the oral cavity into the nasal cavity. */
        attribute minimumSealPressure: PressureValue = 800 [Pa];
        attribute maximumAirLeakage: DimensionlessRatio = 0.02;
        attribute maximumLiquidLeakage: DimensionlessRatio = 0.0;
    }
    requirement def SpeechRestoration {
        doc /* Once fitted, the patient shall achieve clear and intelligible speech. */
        attribute minimumIntelligibility: SoundPressureLevelValue = 60 [dB];
    }
    requirement def SwallowingRestoration {
        doc /* The patient shall swallow without nasal regurgitation. */
        attribute maximumRegurgitationRate: DimensionlessRatio = 0.0;
    }
    requirement def ChewingRestoration {
        doc /* The patient shall be able to chew food effectively. */
        attribute minimumMasticationEfficiency: DimensionlessRatio = 0.8;
    }
    requirement def RetentionStability {
        doc /* Retention clasps shall securely anchor the device to remaining teeth during normal functions. */
        attribute minimumRetentionForce: ForceValue = 5 [N];
        attribute maximumDisplacement: LengthValue = 1e-3 [m];
    }
    requirement def Biocompatibility {
        doc /* All materials contacting patient tissues shall be medical-grade and biocompatible. */
    }
    requirement def LongTermDurability {
        doc /* The system shall be designed for long-term use with periodic maintenance. */
        attribute minimumServiceLife: TimeValue = 157680000 [s];
    }
    requirement def CustomFit {
        doc /* The obturator shall be custom-fabricated to match the specific dimensions of the patient's palatal defect. */
    }
    requirement def IterativeFitting {
        doc /* Fitting shall be an iterative process evaluating seal effectiveness with adjustments until optimal fit is achieved. */
    }

    // ============================================================
    // Top-Level System
    // ============================================================
    part def PalatalObturatorSystem {
        attribute systemId: String;
        attribute patientCondition: String;

        part patient: Patient;
        part clinician: MaxillofacialProsthodontist;
        part laboratory: DentalLaboratory;
        part obturator: PalatalObturator;

        connection oralInterface: PatientObturatorOral
            connect patient.oralCavity to obturator.oralSurface;
        connection defectInterface: PatientObturatorDefect
            connect patient.palatalDefect to obturator.bulbSeal;
        connection nasalInterface: PatientObturatorNasal
            connect patient.nasalCavity to obturator.nasalProjection;
        connection toothEngagement[*]: ClaspToothEngagement
            connect obturator.toothContact to patient.teeth;

        satisfy RestorationOfOralNasalSeparation by patient;
        satisfy SealEfficacy by obturator.bulb;
        satisfy SpeechRestoration by patient;
        satisfy SwallowingRestoration by patient;
        satisfy ChewingRestoration by patient;
        satisfy RetentionStability by obturator.clasps;
        satisfy Biocompatibility by obturator;
        satisfy LongTermDurability by obturator;
        satisfy CustomFit by obturator;
        satisfy IterativeFitting by clinician;

        exhibit behavior SystemOperationFlow {
            state Unassessed;
            state Assessing {
                perform ClinicalAssessment;
            }
            state Impressioning {
                perform ImpressionTaking;
            }
            state Manufacturing {
                perform Fabrication;
            }
            state FittingPhase {
                perform Fitting;
                perform SealEvaluation;
                perform Adjustment;
            }
            state Active {
                entry action markActive;
            }
            state Servicing {
                perform Maintenance;
            }
            transition Unassessed -> Assessing when patientReferral;
            transition Assessing -> Impressioning when assessmentComplete;
            transition Impressioning -> Manufacturing when castComplete;
            transition Manufacturing -> FittingPhase when fabricationComplete;
            transition FittingPhase -> Active when optimalFitAchieved;
            transition Active -> Servicing when maintenanceDue;
            transition Servicing -> Active when servicingComplete;
        }
    }
}
