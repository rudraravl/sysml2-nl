package EyepatchSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percentage :> Real {
        unit = "%";
    }

    attribute def LightTransmittance :> Percentage;
    attribute def Pressure :> Real {
        unit = "Pa";
    }
    attribute def Force :> Real {
        unit = "N";
    }
    attribute def Length :> Real {
        unit = "mm";
    }
    attribute def Area :> Real {
        unit = "mm^2";
    }
    attribute def Mass :> Real {
        unit = "g";
    }
    attribute def TimeDuration :> Real {
        unit = "h";
    }

    enum def EyeSide {
        enum left;
        enum right;
    }

    enum def MaterialKind {
        enum cottonBlend;
        enum hypoallergenicFoam;
        enum elasticTextile;
        enum polymerShield;
        enum medicalAdhesive;
    }

    item def AmbientLight {
        attribute illuminance : Real { unit = "lux"; }
        attribute spectrumClass : String;
    }

    item def BlockedLight {
        attribute residualTransmittance : LightTransmittance;
    }

    item def UserAdjustment {
        attribute strapTensionChange : Force;
        attribute requestedSide : EyeSide;
    }

    item def SkinContactLoad {
        attribute averagePressure : Pressure;
        attribute peakPressure : Pressure;
        attribute contactArea : Area;
    }

    item def ComfortFeedback {
        attribute irritationReported : Boolean;
        attribute perceivedTightness : Percentage;
        attribute fitStable : Boolean;
    }

    port def LightFacingPort {
        in item incidentLight : AmbientLight;
        out item attenuatedLight : BlockedLight;
    }

    port def FaceInterfacePort {
        out item contactLoad : SkinContactLoad;
        in item feedback : ComfortFeedback;
    }

    port def AdjustmentPort {
        in item adjustment : UserAdjustment;
    }

    part def EyepatchSystem {
        attribute coveredEye : EyeSide;
        attribute totalMass : Mass;
        attribute nominalWearDuration : TimeDuration;
        attribute primaryFunction : String =
            "Cover one eye to reduce visual input and protect or rest the covered eye while remaining wearable and adjustable.";

        port lightPort : LightFacingPort;
        port facePort : FaceInterfacePort;
        port adjustmentPort : AdjustmentPort;

        part opticalCover : OpaqueCover;
        part softPad : CushionPad;
        part retentionAssembly : RetentionAssembly;
        part skinInterface : SkinInterface;
        part fitController : FitController;

        connect lightPort to opticalCover.externalLightPort;
        connect opticalCover.innerPadPort to softPad.coverPort;
        connect softPad.facePort to skinInterface.padPort;
        connect skinInterface.userFacePort to facePort;
        connect adjustmentPort to fitController.adjustmentPort;
        connect fitController.tensionCommandPort to retentionAssembly.tensionPort;
        connect retentionAssembly.faceLoadPort to skinInterface.retentionLoadPort;

        action useEyepatch {
            first start;
            then placeCoverOverSelectedEye;
            then adjustRetentionTension;
            then verifyCoverageAndComfort;
            then maintainCoverageDuringWear;
            then removeEyepatch;
            then done;

            action placeCoverOverSelectedEye {
                in side : EyeSide;
                out aligned : Boolean;
            }

            action adjustRetentionTension {
                in desiredComfort : Percentage;
                out appliedTension : Force;
            }

            action verifyCoverageAndComfort {
                in residualLight : LightTransmittance;
                in contactPressure : Pressure;
                out acceptableFit : Boolean;
            }

            action maintainCoverageDuringWear {
                in duration : TimeDuration;
                out coverageMaintained : Boolean;
            }

            action removeEyepatch {
                out removedWithoutIrritation : Boolean;
            }
        }

        state def OperatingStateMachine {
            state stored;
            state positioned;
            state adjusted;
            state worn;
            state discomfortDetected;
            state removed;

            initial then stored;

            transition stored_to_positioned
                first stored
                accept UserAdjustment
                then positioned;

            transition positioned_to_adjusted
                first positioned
                accept UserAdjustment
                then adjusted;

            transition adjusted_to_worn
                first adjusted
                if fitController.fitAcceptable
                then worn;

            transition worn_to_discomfort
                first worn
                if skinInterface.irritationRiskHigh
                then discomfortDetected;

            transition discomfort_to_adjusted
                first discomfortDetected
                accept UserAdjustment
                then adjusted;

            transition worn_to_removed
                first worn
                then removed;

            transition adjusted_to_removed
                first adjusted
                then removed;
        }
    }

    part def OpaqueCover {
        attribute material : MaterialKind = MaterialKind::polymerShield;
        attribute width : Length;
        attribute height : Length;
        attribute thickness : Length;
        attribute opticalTransmittance : LightTransmittance;
        attribute minimumBlockedIlluminance : Real { unit = "lux"; }

        port externalLightPort : LightFacingPort;
        port innerPadPort : LightFacingPort;

        action attenuateLight {
            in incident : AmbientLight;
            out blocked : BlockedLight;
        }
    }

    part def CushionPad {
        attribute material : MaterialKind = MaterialKind::hypoallergenicFoam;
        attribute padThickness : Length;
        attribute edgeRadius : Length;
        attribute contactArea : Area;
        attribute compressionUnderNominalLoad : Percentage;

        port coverPort : LightFacingPort;
        port facePort : FaceInterfacePort;

        action distributeLoad {
            in retentionForce : Force;
            out contactLoad : SkinContactLoad;
        }
    }

    part def RetentionAssembly {
        attribute material : MaterialKind = MaterialKind::elasticTextile;
        attribute strapLength : Length;
        attribute strapWidth : Length;
        attribute nominalTension : Force;
        attribute maximumSafeTension : Force;

        port tensionPort {
            in attribute commandedTension : Force;
        }

        port faceLoadPort : FaceInterfacePort;

        action applyRetention {
            in commandedTension : Force;
            out stabilized : Boolean;
            out transmittedLoad : SkinContactLoad;
        }
    }

    part def SkinInterface {
        attribute adhesivePresent : Boolean;
        attribute material : MaterialKind = MaterialKind::cottonBlend;
        attribute maximumAllowedAveragePressure : Pressure;
        attribute maximumAllowedPeakPressure : Pressure;
        attribute irritationRiskHigh : Boolean;

        port padPort : FaceInterfacePort;
        port retentionLoadPort : FaceInterfacePort;
        port userFacePort : FaceInterfacePort;

        action evaluateComfort {
            in contactLoad : SkinContactLoad;
            in feedback : ComfortFeedback;
            out acceptable : Boolean;
            out irritationRiskHigh : Boolean;
        }
    }

    part def FitController {
        attribute targetContactPressure : Pressure;
        attribute fitAcceptable : Boolean;
        attribute minimumCoverageStability : Percentage;

        port adjustmentPort : AdjustmentPort;

        port tensionCommandPort {
            out attribute commandedTension : Force;
        }

        action computeTension {
            in adjustment : UserAdjustment;
            in comfortFeedback : ComfortFeedback;
            out commandedTension : Force;
            out fitAcceptable : Boolean;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The eyepatch system shall cover one selected eye and reduce visual input
         * through that eye while maintaining stable, comfortable contact with the
         * user's face during normal wear.
         */
        subject eyepatch : EyepatchSystem;

        require constraint {
            eyepatch.opticalCover.opticalTransmittance <= 5.0
        }

        require constraint {
            eyepatch.skinInterface.maximumAllowedAveragePressure <= 1800.0
        }

        require constraint {
            eyepatch.retentionAssembly.nominalTension <= eyepatch.retentionAssembly.maximumSafeTension
        }
    }

    requirement def LightBlockingRequirement {
        doc
        /*
         * The optical cover shall block at least 95 percent of incident visible light
         * reaching the selected eye under ordinary indoor and outdoor lighting.
         */
        subject cover : OpaqueCover;

        require constraint {
            cover.opticalTransmittance <= 5.0
        }
    }

    requirement def ComfortRequirement {
        doc
        /*
         * The eyepatch shall distribute contact loads so that local pressure remains
         * below irritation thresholds for the intended nominal wear duration.
         */
        subject pad : CushionPad;
        subject interface : SkinInterface;

        require constraint {
            pad.contactArea >= 3200.0
        }

        require constraint {
            interface.maximumAllowedPeakPressure <= 4500.0
        }
    }

    requirement def AdjustabilityRequirement {
        doc
        /*
         * The retention assembly shall allow the user to adjust fit for either the
         * left or right eye without tools.
         */
        subject retention : RetentionAssembly;

        require constraint {
            retention.strapLength >= 220.0
        }

        require constraint {
            retention.maximumSafeTension >= 8.0
        }
    }

    part eyepatchSystem : EyepatchSystem {
        attribute coveredEye = EyeSide::left;
        attribute totalMass = 18.0;
        attribute nominalWearDuration = 8.0;

        part opticalCover : OpaqueCover {
            attribute width = 72.0;
            attribute height = 58.0;
            attribute thickness = 1.8;
            attribute opticalTransmittance = 2.0;
            attribute minimumBlockedIlluminance = 9500.0;
        }

        part softPad : CushionPad {
            attribute padThickness = 5.0;
            attribute edgeRadius = 8.0;
            attribute contactArea = 3800.0;
            attribute compressionUnderNominalLoad = 22.0;
        }

        part retentionAssembly : RetentionAssembly {
            attribute strapLength = 330.0;
            attribute strapWidth = 14.0;
            attribute nominalTension = 4.2;
            attribute maximumSafeTension = 9.0;
        }

        part skinInterface : SkinInterface {
            attribute adhesivePresent = false;
            attribute maximumAllowedAveragePressure = 1500.0;
            attribute maximumAllowedPeakPressure = 4000.0;
            attribute irritationRiskHigh = false;
        }

        part fitController : FitController {
            attribute targetContactPressure = 900.0;
            attribute fitAcceptable = true;
            attribute minimumCoverageStability = 95.0;
        }
    }

    satisfy PrimaryFunctionRequirement by eyepatchSystem;
    satisfy LightBlockingRequirement by eyepatchSystem.opticalCover;
    satisfy ComfortRequirement by eyepatchSystem.softPad;
    satisfy ComfortRequirement by eyepatchSystem.skinInterface;
    satisfy AdjustabilityRequirement by eyepatchSystem.retentionAssembly;
}