package InadineWoundDressingSystem {

    import ScalarValues::*;
    import Quantities::*;
    import ISQ::*;

    attribute def Millimeter :> LengthUnit;
    attribute def SquareCentimeter :> AreaUnit;
    attribute def Gram :> MassUnit;
    attribute def Milligram :> MassUnit;
    attribute def Hour :> TimeUnit;
    attribute def Day :> TimeUnit;
    attribute def Celsius :> TemperatureUnit;

    value type LengthMM :> Real {
        unit = Millimeter;
    }

    value type AreaCM2 :> Real {
        unit = SquareCentimeter;
    }

    value type MassMG :> Real {
        unit = Milligram;
    }

    value type TimeHour :> Real {
        unit = Hour;
    }

    value type TimeDay :> Real {
        unit = Day;
    }

    value type TemperatureC :> Real {
        unit = Celsius;
    }

    value type ConcentrationPercent :> Real {
        unit = "%";
    }

    value type MoistureLevel :> Real {
        unit = "%";
    }

    value type BioburdenIndex :> Real {
        unit = "CFU/cm^2 normalized";
    }

    value type ExudateRate :> Real {
        unit = "mL/day";
    }

    item def WoundExudate {
        attribute volumeRate : ExudateRate;
        attribute moistureContent : MoistureLevel;
        attribute bioburden : BioburdenIndex;
        attribute pH : Real;
    }

    item def IodineDose {
        attribute availableIodineMass : MassMG;
        attribute releaseRate : MassMG {
            unit = "mg/hour";
        }
        attribute antimicrobialPotency : Real;
    }

    item def AmbientAir {
        attribute temperature : TemperatureC;
        attribute relativeHumidity : MoistureLevel;
    }

    item def Contaminant {
        attribute organismLoad : BioburdenIndex;
        attribute source : String;
    }

    item def ClinicalObservation {
        attribute woundMoisture : MoistureLevel;
        attribute dressingColor : String;
        attribute adherenceLevel : Real;
        attribute replacementRecommended : Boolean;
    }

    port def WoundInterfacePort {
        in item woundExudate : WoundExudate;
        out item iodineDose : IodineDose;
        out item observation : ClinicalObservation;
    }

    port def EnvironmentPort {
        in item ambientAir : AmbientAir;
        in item contaminant : Contaminant;
    }

    port def CaregiverPort {
        in item applicationForce {
            attribute pressure : Real {
                unit = "kPa";
            }
        }
        out item replacementSignal {
            attribute replaceNow : Boolean;
            attribute reason : String;
        }
    }

    part def InadineDressing {
        attribute padLength : LengthMM = 95;
        attribute padWidth : LengthMM = 95;
        attribute effectiveContactArea : AreaCM2 = 81;
        attribute fabricThickness : LengthMM = 0.9;
        attribute povidoneIodineConcentration : ConcentrationPercent = 10;
        attribute nominalAvailableIodine : MassMG = 90;
        attribute maximumWearTime : TimeDay = 3;
        attribute minimumMoistureForRelease : MoistureLevel = 25;
        attribute colorWhenActive : String = "orange-brown";
        attribute colorWhenDepleted : String = "pale-yellow";

        port woundPort : WoundInterfacePort;
        port environmentPort : EnvironmentPort;
        port caregiverPort : CaregiverPort;

        part knittedViscoseFabric {
            attribute openMeshPorosity : Real = 0.62;
            attribute conformabilityIndex : Real = 0.88;
            attribute lowAdherenceCoefficient : Real = 0.18;
            attribute absorbedFluidCapacity : Real {
                unit = "mL";
            } = 4.5;
        }

        part povidoneIodineMatrix {
            attribute iodineCarrier : String = "povidone polymer complex";
            attribute availableIodineMass : MassMG = 90;
            attribute residualIodineMass : MassMG = 90;
            attribute releaseEnabled : Boolean = false;
            attribute releaseRate : MassMG {
                unit = "mg/hour";
            } = 0;
        }

        part protectiveWrapper {
            attribute sterileBarrierIntact : Boolean = true;
            attribute moistureIngressResistance : Real = 0.97;
        }

        part contactSurface {
            attribute targetSurface : String = "wound bed and peri-wound margin";
            attribute contactUniformity : Real = 0.9;
            attribute wrinkleTolerance : Real = 0.15;
        }

        action releaseIodine {
            in item localExudate : WoundExudate;
            out item dose : IodineDose;

            first start;
            then evaluateMoisture;

            action evaluateMoisture {
                out moistureSufficient : Boolean;
            }

            then computeDose;

            action computeDose {
                in moistureSufficient : Boolean;
                out item dose : IodineDose;
            }

            then reduceResidualIodine;

            action reduceResidualIodine {
                in item dose : IodineDose;
                out residualMass : MassMG;
            }

            then done;
        }

        action inhibitMicrobialGrowth {
            in item woundExudate : WoundExudate;
            in item dose : IodineDose;
            out item observation : ClinicalObservation;

            first start;
            then exposeOrganismsToIodine;
            then lowerBioburdenTrend;
            then assessDressingColor;
            then done;

            action exposeOrganismsToIodine;
            action lowerBioburdenTrend;
            action assessDressingColor;
        }

        action manageMoistWoundInterface {
            in item woundExudate : WoundExudate;
            out item observation : ClinicalObservation;

            first start;
            then wickExudateIntoMesh;
            then maintainNonAdherentContact;
            then reportMoistureState;
            then done;

            action wickExudateIntoMesh;
            action maintainNonAdherentContact;
            action reportMoistureState;
        }

        state def DressingUseStateMachine {
            entry; then Packaged;

            state Packaged {
                entry action verifySterileWrapper;
            }

            transition Packaged_to_Applied
                first Packaged
                accept event applicationStarted
                if protectiveWrapper.sterileBarrierIntact == true
                then Applied;

            state Applied {
                entry action conformToWoundSurface;
            }

            transition Applied_to_ActiveRelease
                first Applied
                accept item woundExudate : WoundExudate
                if woundExudate.moistureContent >= minimumMoistureForRelease
                then ActiveRelease;

            state ActiveRelease {
                entry action setReleaseEnabled;
                do action releaseIodine;
                do action inhibitMicrobialGrowth;
                do action manageMoistWoundInterface;
            }

            transition ActiveRelease_to_Monitoring
                first ActiveRelease
                accept event elapsedClinicalInterval
                then Monitoring;

            state Monitoring {
                do action assessColorAndMoisture;
            }

            transition Monitoring_to_ActiveRelease
                first Monitoring
                accept item woundExudate : WoundExudate
                if povidoneIodineMatrix.residualIodineMass > 10 and woundExudate.moistureContent >= minimumMoistureForRelease
                then ActiveRelease;

            transition Monitoring_to_Depleted
                first Monitoring
                accept event clinicalAssessment
                if povidoneIodineMatrix.residualIodineMass <= 10
                then Depleted;

            transition Monitoring_to_RemovalRequired
                first Monitoring
                accept event wearLimitReached
                then RemovalRequired;

            state Depleted {
                entry action signalReplacementDueToIodineDepletion;
            }

            transition Depleted_to_RemovalRequired
                first Depleted
                accept event caregiverAcknowledges
                then RemovalRequired;

            state RemovalRequired {
                entry action requestDressingChange;
            }

            transition RemovalRequired_to_Removed
                first RemovalRequired
                accept event dressingRemoved
                then Removed;

            state Removed {
                entry action terminateIodineRelease;
            }
        }
    }

    part def WoundSite {
        attribute woundArea : AreaCM2;
        attribute woundDepth : LengthMM;
        attribute exudateRate : ExudateRate;
        attribute baselineBioburden : BioburdenIndex;
        attribute targetMoistureRangeLow : MoistureLevel = 30;
        attribute targetMoistureRangeHigh : MoistureLevel = 70;
        attribute contraindicatedForIodineSensitivity : Boolean = false;

        port woundPort : WoundInterfacePort;

        part woundBed {
            attribute tissueType : String;
            attribute moistureLevel : MoistureLevel;
            attribute currentBioburden : BioburdenIndex;
        }

        part periWoundSkin {
            attribute irritationLevel : Real;
            attribute macerationRisk : Real;
        }

        action produceExudate {
            out item woundExudate : WoundExudate;
        }

        action receiveIodine {
            in item iodineDose : IodineDose;
            out bioburdenAfterExposure : BioburdenIndex;
        }
    }

    part def SecondaryRetentionDressing {
        attribute absorbentCapacity : Real {
            unit = "mL";
        } = 12;
        attribute fixationIntegrity : Real = 0.92;
        attribute changeInterval : TimeDay = 3;

        port innerInterface {
            in item woundObservation : ClinicalObservation;
        }

        port outerEnvironment : EnvironmentPort;

        action retainPrimaryDressing {
            in item observation : ClinicalObservation;
        }

        action absorbExcessExudate {
            in item woundExudate : WoundExudate;
        }
    }

    part def Caregiver {
        attribute trainedForAsepticApplication : Boolean = true;
        attribute inspectionInterval : TimeHour = 24;

        port caregiverPort : CaregiverPort;

        action applyDressing {
            in part dressing : InadineDressing;
            in part wound : WoundSite;
        }

        action inspectDressing {
            in item observation : ClinicalObservation;
            out replaceNow : Boolean;
        }

        action removeAndReplace {
            in part dressing : InadineDressing;
        }
    }

    part def InadineBasedWoundCareSystem {
        doc /* 
         * Primary function: provide a sterile, low-adherent povidone-iodine wound contact layer that releases iodine when moistened by wound exudate, reducing microbial burden while maintaining a conformable interface between the wound bed and a secondary dressing.
         */

        attribute intendedUse : String = "topical antimicrobial wound contact dressing";
        attribute operatingTemperatureLow : TemperatureC = 5;
        attribute operatingTemperatureHigh : TemperatureC = 30;
        attribute maximumContinuousWear : TimeDay = 3;

        part wound : WoundSite {
            attribute woundArea = 36;
            attribute woundDepth = 2;
            attribute exudateRate = 3.2;
            attribute baselineBioburden = 0.74;
        }

        part primaryDressing : InadineDressing;
        part secondaryDressing : SecondaryRetentionDressing;
        part caregiver : Caregiver;

        port environment : EnvironmentPort;

        connect wound.woundPort to primaryDressing.woundPort;
        connect primaryDressing.environmentPort to environment;
        connect secondaryDressing.outerEnvironment to environment;
        connect caregiver.caregiverPort to primaryDressing.caregiverPort;

        flow wound.produceExudate.woundExudate to primaryDressing.releaseIodine.localExudate;
        flow primaryDressing.releaseIodine.dose to wound.receiveIodine.iodineDose;
        flow primaryDressing.inhibitMicrobialGrowth.observation to secondaryDressing.innerInterface.woundObservation;
        flow primaryDressing.woundPort.observation to caregiver.inspectDressing.observation;

        action provideAntimicrobialWoundContact {
            in part woundSite : WoundSite;
            in part dressing : InadineDressing;
            out item clinicalObservation : ClinicalObservation;

            first prepareSterileField;
            then confirmNoIodineContraindication;
            then placeDressingOnWound;
            then secureWithSecondaryDressing;
            then releaseIodineWhenMoist;
            then monitorDressingEffectiveness;
            then recommendReplacementIfNeeded;
            then done;

            action prepareSterileField;

            action confirmNoIodineContraindication {
                in contraindicated : Boolean;
                out permitted : Boolean;
            }

            action placeDressingOnWound {
                in part dressing : InadineDressing;
                in part woundSite : WoundSite;
            }

            action secureWithSecondaryDressing {
                in part retentionLayer : SecondaryRetentionDressing;
            }

            action releaseIodineWhenMoist {
                in item woundExudate : WoundExudate;
                out item iodineDose : IodineDose;
            }

            action monitorDressingEffectiveness {
                out item clinicalObservation : ClinicalObservation;
            }

            action recommendReplacementIfNeeded {
                in item clinicalObservation : ClinicalObservation;
                out replaceNow : Boolean;
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : InadineBasedWoundCareSystem;

        require constraint {
            system.primaryDressing.povidoneIodineConcentration == 10
        }

        doc /* The system shall function as a sterile antimicrobial wound contact dressing that releases iodine at the wound interface when exposed to exudate. */
    }

    requirement def MoistureActivatedReleaseRequirement {
        subject dressing : InadineDressing;

        require constraint {
            dressing.minimumMoistureForRelease <= 25
        }

        doc /* Iodine release shall be enabled by wound moisture so that antimicrobial activity occurs at the wound contact surface. */
    }

    requirement def LowAdherenceRequirement {
        subject dressing : InadineDressing;

        require constraint {
            dressing.knittedViscoseFabric.lowAdherenceCoefficient <= 0.25
        }

        doc /* The contact layer shall minimize adherence to the wound bed during removal. */
    }

    requirement def WearTimeRequirement {
        subject system : InadineBasedWoundCareSystem;

        require constraint {
            system.primaryDressing.maximumWearTime <= system.maximumContinuousWear
        }

        doc /* The dressing shall be assessed and replaced no later than the maximum continuous wear interval or earlier when depleted or clinically saturated. */
    }

    requirement def AntimicrobialAvailabilityRequirement {
        subject dressing : InadineDressing;

        require constraint {
            dressing.nominalAvailableIodine >= 75
        }

        doc /* The dressing shall contain sufficient available iodine to provide topical antimicrobial action during its intended wear period. */
    }

    requirement def SecondaryRetentionRequirement {
        subject system : InadineBasedWoundCareSystem;

        require constraint {
            system.secondaryDressing.fixationIntegrity >= 0.85
        }

        doc /* The secondary dressing shall retain the primary Inadine contact layer in stable contact with the wound surface. */
    }

    satisfy PrimaryFunctionRequirement by InadineBasedWoundCareSystem;
    satisfy MoistureActivatedReleaseRequirement by InadineDressing;
    satisfy LowAdherenceRequirement by InadineDressing;
    satisfy WearTimeRequirement by InadineBasedWoundCareSystem;
    satisfy AntimicrobialAvailabilityRequirement by InadineDressing;
    satisfy SecondaryRetentionRequirement by SecondaryRetentionDressing;

}