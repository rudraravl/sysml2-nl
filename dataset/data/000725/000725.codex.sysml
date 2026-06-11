package PalatalObturatorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalarValues::Real;
        unit = "kPa";
    }

    attribute def Volume {
        :> scalarValues::Real;
        unit = "mL";
    }

    attribute def Mass {
        :> scalarValues::Real;
        unit = "g";
    }

    attribute def Length {
        :> scalarValues::Real;
        unit = "mm";
    }

    attribute def Force {
        :> scalarValues::Real;
        unit = "N";
    }

    attribute def Area {
        :> scalarValues::Real;
        unit = "mm^2";
    }

    attribute def FlowRate {
        :> scalarValues::Real;
        unit = "mL/s";
    }

    attribute def AcousticTransmissionLoss {
        :> scalarValues::Real;
        unit = "dB";
    }

    attribute def BiocompatibilityRating {
        :> scalarValues::Real;
        unit = "score";
    }

    item def AirFlow {
        attribute rate : FlowRate;
        attribute pressure : Pressure;
        attribute humidityFraction : scalarValues::Real;
    }

    item def OralBolus {
        attribute volume : Volume;
        attribute viscosityIndex : scalarValues::Real;
        attribute particleSizeMaximum : Length;
    }

    item def SpeechSound {
        attribute oralPressure : Pressure;
        attribute nasalAcousticLeakage : AcousticTransmissionLoss;
        attribute intelligibilityIndex : scalarValues::Real;
    }

    item def Saliva {
        attribute volumeRate : FlowRate;
        attribute pH : scalarValues::Real;
    }

    item def MechanicalLoad {
        attribute retentionForce : Force;
        attribute occlusalForce : Force;
        attribute insertionForce : Force;
    }

    port def OralCavityInterfacePort {
        out item oralAir : AirFlow;
        in item returningSaliva : Saliva;
        out item speechPressure : SpeechSound;
        out item foodBolus : OralBolus;
    }

    port def NasalCavityInterfacePort {
        in item leakageAir : AirFlow;
        in item leakageBolus : OralBolus;
        in item acousticLeakage : SpeechSound;
    }

    port def TissueContactPort {
        out item distributedLoad : MechanicalLoad;
        in item mucosalResponse : MechanicalLoad;
    }

    port def RetentionInterfacePort {
        out item retentionLoad : MechanicalLoad;
        in item supportReaction : MechanicalLoad;
    }

    port def ClinicalAdjustmentPort {
        in attribute borderTrimAmount : Length;
        in attribute claspAdjustmentForce : Force;
        out attribute fitAssessmentScore : scalarValues::Real;
    }

    part def PalatalObturatorSystem {

        attribute totalMass : Mass = 28.0 [g];
        attribute maximumThickness : Length = 5.0 [mm];
        attribute defectClosureArea : Area = 2200.0 [mm^2];
        attribute nominalRetentionForce : Force = 12.0 [N];
        attribute nasalLeakageLimit : FlowRate = 2.0 [mL/s];
        attribute targetSpeechIntelligibility : scalarValues::Real = 0.85;
        attribute biocompatibilityScore : BiocompatibilityRating = 0.98 [score];

        port oralInterface : OralCavityInterfacePort;
        port nasalInterface : NasalCavityInterfacePort;
        port tissueInterface : TissueContactPort;
        port retentionInterface : RetentionInterfacePort;
        port clinicalInterface : ClinicalAdjustmentPort;

        part prostheticPlate : ObturatorPlate;
        part sealingBulb : DefectSealingBulb;
        part retentionAssembly : RetentionAssembly;
        part softLiner : TissueBearingLiner;
        part hygieneSurface : CleanableSurface;
        part fitMonitor : FitAndSealMonitor;

        connect oralInterface to prostheticPlate.oralSide;
        connect prostheticPlate.defectSide to sealingBulb.oralBoundary;
        connect sealingBulb.nasalBoundary to nasalInterface;
        connect prostheticPlate.tissueSide to softLiner.prosthesisSide;
        connect softLiner.tissueSide to tissueInterface;
        connect prostheticPlate.retentionSeat to retentionAssembly.prosthesisAnchor;
        connect retentionAssembly.patientAnchor to retentionInterface;
        connect clinicalInterface to fitMonitor.adjustmentInput;
        connect fitMonitor.fitFeedback to clinicalInterface;

        action performPrimaryFunction {
            in item oralAirIn : AirFlow;
            in item oralBolusIn : OralBolus;
            in item speechIn : SpeechSound;
            out item separatedOralAir : AirFlow;
            out item retainedBolus : OralBolus;
            out item improvedSpeech : SpeechSound;

            first start;
            then seatDevice;
            then closePalatalDefect;
            then separateOralAndNasalCavities;
            then supportSpeechAndSwallowing;
            then finish;

            action seatDevice {
                in item seatingLoad : MechanicalLoad;
                out attribute seated : scalarValues::Boolean;
            }

            action closePalatalDefect {
                in attribute closureArea : Area;
                out attribute residualGapArea : Area;
            }

            action separateOralAndNasalCavities {
                in item oralFlow : AirFlow;
                out item controlledFlow : AirFlow;
                out item leakageFlow : AirFlow;
            }

            action supportSpeechAndSwallowing {
                in item speechPressureInput : SpeechSound;
                in item bolusInput : OralBolus;
                out item speechPressureOutput : SpeechSound;
                out item bolusOutput : OralBolus;
            }
        }

        state def UseLifecycle {
            state NotInserted;
            state Insertion;
            state SeatedAndSealing;
            state SpeechSupport;
            state SwallowingSupport;
            state Cleaning;
            state AdjustmentNeeded;
            state Removed;

            transition first NotInserted;
            transition insert from NotInserted to Insertion;
            transition achieveRetention from Insertion to SeatedAndSealing
                if retentionAssembly.availableRetentionForce >= nominalRetentionForce;
            transition speak from SeatedAndSealing to SpeechSupport;
            transition speechComplete from SpeechSupport to SeatedAndSealing;
            transition swallow from SeatedAndSealing to SwallowingSupport;
            transition swallowComplete from SwallowingSupport to SeatedAndSealing;
            transition detectPoorFit from SeatedAndSealing to AdjustmentNeeded
                if fitMonitor.detectedLeakageRate > nasalLeakageLimit;
            transition adjust from AdjustmentNeeded to SeatedAndSealing
                if fitMonitor.fitScore >= 0.90;
            transition removeForCleaning from SeatedAndSealing to Cleaning;
            transition cleaningComplete from Cleaning to Removed;
            transition store from Removed to NotInserted;
        }
    }

    part def ObturatorPlate {

        attribute plateThickness : Length = 3.0 [mm];
        attribute palateContactArea : Area = 3600.0 [mm^2];
        attribute flexuralStrength : Pressure = 90000.0 [kPa];
        attribute surfaceRoughnessRa : Length = 0.2 [mm];

        port oralSide : OralCavityInterfacePort;
        port defectSide : OralCavityInterfacePort;
        port tissueSide : TissueContactPort;
        port retentionSeat : RetentionInterfacePort;

        part anteriorPalatalShelf : PalatalShelf;
        part posteriorBorder : PosteriorSealBorder;
        part lateralFlanges : LateralStabilizingFlanges;
    }

    part def PalatalShelf {
        attribute supportArea : Area = 1800.0 [mm^2];
        attribute averageThickness : Length = 2.5 [mm];
    }

    part def PosteriorSealBorder {
        attribute compressiveSealWidth : Length = 4.0 [mm];
        attribute allowableCompression : Length = 0.7 [mm];
    }

    part def LateralStabilizingFlanges {
        attribute leftFlangeHeight : Length = 7.0 [mm];
        attribute rightFlangeHeight : Length = 7.0 [mm];
        attribute lateralStabilityForce : Force = 4.0 [N];
    }

    part def DefectSealingBulb {

        attribute bulbVolume : Volume = 18.0 [mL];
        attribute wallThickness : Length = 2.0 [mm];
        attribute sealCompression : Length = 0.6 [mm];
        attribute residualLeakageRate : FlowRate = 1.2 [mL/s];

        port oralBoundary : OralCavityInterfacePort;
        port nasalBoundary : NasalCavityInterfacePort;

        action blockCommunication {
            in item oralAir : AirFlow;
            in item oralBolus : OralBolus;
            out item leakageAir : AirFlow;
            out item retainedBolus : OralBolus;
        }
    }

    part def RetentionAssembly {

        attribute availableRetentionForce : Force = 14.0 [N];
        attribute claspCount : scalarValues::Integer = 4;
        attribute undercutEngagementDepth : Length = 0.5 [mm];

        port prosthesisAnchor : RetentionInterfacePort;
        port patientAnchor : RetentionInterfacePort;

        part leftMolarClasp : RetentionClasp;
        part rightMolarClasp : RetentionClasp;
        part anteriorRest : OcclusalRest;
        part posteriorRest : OcclusalRest;
    }

    part def RetentionClasp {
        attribute claspFlexibility : Force = 2.5 [N];
        attribute engagementDepth : Length = 0.5 [mm];
        attribute fatigueLifeCycles : scalarValues::Integer = 100000;
    }

    part def OcclusalRest {
        attribute supportForceCapacity : Force = 35.0 [N];
        attribute restSeatDepth : Length = 1.2 [mm];
    }

    part def TissueBearingLiner {

        attribute linerThickness : Length = 1.5 [mm];
        attribute compressiveModulus : Pressure = 1200.0 [kPa];
        attribute contactPressureLimit : Pressure = 35.0 [kPa];

        port prosthesisSide : TissueContactPort;
        port tissueSide : TissueContactPort;

        action distributePressure {
            in item appliedLoad : MechanicalLoad;
            out item distributedLoad : MechanicalLoad;
        }
    }

    part def CleanableSurface {

        attribute exposedSurfaceArea : Area = 5200.0 [mm^2];
        attribute minimumCleanabilityRadius : Length = 1.0 [mm];
        attribute microbialRetentionIndex : scalarValues::Real = 0.10;

        action clean {
            in attribute brushingDuration : Time = 120 [s];
            in attribute rinseVolume : Volume = 250 [mL];
            out attribute cleanlinessIndex : scalarValues::Real;
        }
    }

    part def FitAndSealMonitor {

        attribute detectedLeakageRate : FlowRate = 1.2 [mL/s];
        attribute fitScore : scalarValues::Real = 0.93;
        attribute pressureSpotCount : scalarValues::Integer = 0;

        port adjustmentInput : ClinicalAdjustmentPort;
        port fitFeedback : ClinicalAdjustmentPort;

        action assessFit {
            in attribute leakageRate : FlowRate;
            in attribute tissuePressure : Pressure;
            out attribute acceptableFit : scalarValues::Boolean;
            out attribute fitAssessmentScore : scalarValues::Real;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject obturator : PalatalObturatorSystem;
        doc
        /*
         The palatal obturator system shall close an acquired or congenital palatal opening sufficiently to separate the oral and nasal cavities during routine speaking and swallowing.
        */
        require constraint {
            obturator.fitMonitor.detectedLeakageRate <= obturator.nasalLeakageLimit
        }
    }

    requirement def SpeechSupportRequirement {
        subject obturator : PalatalObturatorSystem;
        doc
        /*
         The system shall support speech by enabling buildup of oral air pressure and reducing unintended nasal acoustic leakage.
        */
        require constraint {
            obturator.targetSpeechIntelligibility >= 0.85
        }
    }

    requirement def SwallowingSupportRequirement {
        subject obturator : PalatalObturatorSystem;
        doc
        /*
         The system shall reduce passage of food and liquid from the oral cavity into the nasal cavity during swallowing.
        */
        require constraint {
            obturator.sealingBulb.residualLeakageRate <= 2.0 [mL/s]
        }
    }

    requirement def RetentionRequirement {
        subject obturator : PalatalObturatorSystem;
        doc
        /*
         The system shall remain seated under normal speech, swallowing, and low-intensity chewing loads.
        */
        require constraint {
            obturator.retentionAssembly.availableRetentionForce >= obturator.nominalRetentionForce
        }
    }

    requirement def TissueProtectionRequirement {
        subject obturator : PalatalObturatorSystem;
        doc
        /*
         The tissue-bearing surfaces shall distribute load so that localized mucosal pressure remains below the defined comfort and injury-prevention limit.
        */
        require constraint {
            obturator.softLiner.contactPressureLimit <= 35.0 [kPa]
        }
    }

    requirement def BiocompatibilityRequirement {
        subject obturator : PalatalObturatorSystem;
        doc
        /*
         Patient-contacting materials shall be biocompatible for repeated intraoral use.
        */
        require constraint {
            obturator.biocompatibilityScore >= 0.95 [score]
        }
    }

    requirement def CleanabilityRequirement {
        subject obturator : PalatalObturatorSystem;
        doc
        /*
         The system shall provide accessible surfaces that can be cleaned by routine brushing and rinsing after removal.
        */
        require constraint {
            obturator.hygieneSurface.microbialRetentionIndex <= 0.15
        }
    }

    satisfy PrimaryFunctionRequirement by PalatalObturatorSystem::performPrimaryFunction;
    satisfy SpeechSupportRequirement by DefectSealingBulb::blockCommunication;
    satisfy SwallowingSupportRequirement by DefectSealingBulb::blockCommunication;
    satisfy RetentionRequirement by RetentionAssembly;
    satisfy TissueProtectionRequirement by TissueBearingLiner::distributePressure;
    satisfy BiocompatibilityRequirement by PalatalObturatorSystem;
    satisfy CleanabilityRequirement by CleanableSurface::clean;

    part palatalObturator : PalatalObturatorSystem;

}