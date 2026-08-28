package GastricIntubationSystem {
    private import SI::*;
    private import ScalarValues::*;

    attribute def Length :> Real;
    attribute def FrenchSize :> Real;
    attribute def PressureValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def pHValue :> Real;

    item def GastricContents;
    item def NutritionalFormula;
    item def Medication;
    item def FlushingFluid;
    item def Air;

    attribute def InsertCommand;
    attribute def DepthReached;
    attribute def PlacementConfirmed;
    attribute def PlacementIncorrect;
    attribute def RepositionComplete;
    attribute def BeginUse;
    attribute def BlockageDetected;
    attribute def RemoveCommand;
    attribute def BlockageCleared;

    state def TubeStatus {
        entry; then prepared;
        state prepared;
        accept InsertCommand then inserting;
        state inserting;
        accept DepthReached then verifying;
        state verifying;
        accept PlacementConfirmed then secured;
        accept PlacementIncorrect then repositioning;
        state repositioning;
        accept RepositionComplete then inserting;
        state secured;
        accept BeginUse then inUse;
        state inUse;
        accept BlockageDetected then blocked;
        accept RemoveCommand then removed;
        state blocked;
        accept BlockageCleared then inUse;
        state removed;
    }

    action def AssessPatient {
        in patient : Patient;
        out isSuitable : Boolean;
    }
    action def SelectTubeSize {
        in patient : Patient;
        out selectedSize : FrenchSize;
    }
    action def MeasureDepth {
        in patient : Patient;
        out depth : Length;
    }
    action def PrepareTube {
        in tube : NasogastricTube;
    }
    action def InsertTube {
        in tube : NasogastricTube;
        in patient : Patient;
        in depth : Length;
    }
    action def VerifyPlacement {
        in tube : NasogastricTube;
        in equipment : VerificationEquipment;
        in patient : Patient;
        out placementCorrect : Boolean;
    }
    action def Reposition {
        in tube : NasogastricTube;
    }
    action def SecureTube {
        in tube : NasogastricTube;
        in patient : Patient;
    }
    action def ConnectSuction {
        in tube : NasogastricTube;
        in suction : SuctionApparatus;
    }
    action def ConnectFeedingPump {
        in tube : NasogastricTube;
        in pump : FeedingPump;
    }
    action def FlushTube {
        in tube : NasogastricTube;
        in flushVolume : VolumeValue;
    }
    action def ClearBlockage {
        in tube : NasogastricTube;
        out cleared : Boolean;
    }
    action def RemoveTube {
        in tube : NasogastricTube;
        in patient : Patient;
    }
    action def ApplySuction {
        in pressure : PressureValue;
        out drainedContents : GastricContents;
    }
    action def DeliverFormula {
        in rate : FlowRateValue;
        out deliveredFormula : NutritionalFormula;
    }
    action def TestPH {
        in sample : GastricContents;
        out pHReading : pHValue;
    }
    action def GastricIntubationProcedure {
        action assessPatient : AssessPatient;
        then action selectTubeSize : SelectTubeSize;
        then action measureDepth : MeasureDepth;
        then action prepareTube : PrepareTube;
        then action insertTube : InsertTube;
        then action verifyPlacement : VerifyPlacement;
        then action secureTube : SecureTube;
        then action connectSuction : ConnectSuction;
        then action flushTube : FlushTube;
        then action removeTube : RemoveTube;
    }

    part def NasogastricTube {
        attribute size : FrenchSize;
        attribute length : Length;
        attribute insertionDepth : Length;
        attribute isPatent : Boolean;
        attribute isSecured : Boolean;
        port externalPort {
            out item aspirateOut : GastricContents;
            in item feedingIn : NutritionalFormula;
            in item medicationIn : Medication;
            in item flushIn : FlushingFluid;
        }
        port internalPort {
            in item aspirateIn : GastricContents;
            out item feedingOut : NutritionalFormula;
            out item medicationOut : Medication;
            out item flushOut : FlushingFluid;
            in item airIn : Air;
        }
        exhibit state tubeStatus : TubeStatus;
    }

    part def SuctionApparatus {
        attribute suctionPressure : PressureValue;
        attribute isIntermittent : Boolean;
        port suctionPort {
            in item drainedContents : GastricContents;
            in item drainedAir : Air;
        }
        perform action applySuction : ApplySuction;
    }

    part def FeedingPump {
        attribute deliveryRate : FlowRateValue;
        attribute volumeToDeliver : VolumeValue;
        port pumpPort {
            out item deliveredFormula : NutritionalFormula;
        }
        perform action deliverFormula : DeliverFormula;
    }

    part def VerificationEquipment {
        attribute pHLowerBound : pHValue;
        attribute pHUpperBound : pHValue;
        port samplePort {
            in item sample : GastricContents;
        }
        perform action testPH : TestPH;
    }

    part def Patient {
        attribute isSuitable : Boolean;
        attribute nasalPatency : Boolean;
        attribute esophagealPatency : Boolean;
        attribute gastricResidualVolume : VolumeValue;
    }

    part def Clinician {
        perform action assessPatient : AssessPatient;
        perform action selectTubeSize : SelectTubeSize;
        perform action measureDepth : MeasureDepth;
        perform action prepareTube : PrepareTube;
        perform action insertTube : InsertTube;
        perform action verifyPlacement : VerifyPlacement;
        perform action reposition : Reposition;
        perform action secureTube : SecureTube;
        perform action connectSuction : ConnectSuction;
        perform action connectFeedingPump : ConnectFeedingPump;
        perform action flushTube : FlushTube;
        perform action clearBlockage : ClearBlockage;
        perform action removeTube : RemoveTube;
    }

    part def GastricIntubationSystem {
        part nasogastricTube : NasogastricTube;
        part suction : SuctionApparatus;
        part feedingPump : FeedingPump;
        part verifier : VerificationEquipment;
        ref clinician : Clinician;
        ref patient : Patient;
        perform action procedure : GastricIntubationProcedure;
    }

    requirement def ClinicalSafetyRequirement {
        /* The gastric intubation system shall ensure patient safety throughout the procedure. */
    }

    requirement def CorrectPlacementRequirement {
        /* The distal end of the nasogastric tube must be confirmed to reside within the stomach and not the airway before use. */
        subject tube : NasogastricTube;
        subject patient : Patient;
        subject equipment : VerificationEquipment;
    }

    requirement def TubePatencyRequirement {
        /* The nasogastric tube must remain patent during use and must be flushed periodically to prevent or resolve blockages. */
        subject tube : NasogastricTube;
    }

    requirement def ControlledFeedingRequirement {
        /* The feeding pump shall deliver nutritional formula at a precisely controlled flow rate not exceeding the prescribed value. */
        subject pump : FeedingPump;
    }

    requirement def SuctionSafetyRequirement {
        /* The suction apparatus shall apply controlled negative pressure, typically intermittent, to drain gastric contents without damaging gastric tissue. */
        subject suction : SuctionApparatus;
    }

    requirement def PatientSuitabilityRequirement :> ClinicalSafetyRequirement {
        /* The clinician shall assess the patient to confirm suitability for gastric intubation prior to insertion. */
        subject patient : Patient;
        subject clinician : Clinician;
    }

    requirement def SecureExternalFixationRequirement :> ClinicalSafetyRequirement {
        /* Once correct placement is confirmed, the tube shall be secured externally to the patient to prevent displacement during use. */
        subject tube : NasogastricTube;
        subject patient : Patient;
    }

    requirement def SafeRemovalRequirement :> ClinicalSafetyRequirement {
        /* The tube shall be carefully removed when it is no longer medically indicated. */
        subject tube : NasogastricTube;
        subject patient : Patient;
    }

    part gastricIntubationSystem : GastricIntubationSystem {
        part nasogastricTube : NasogastricTube {
            :>> size = 16;
            :>> length = 1200;
            :>> insertionDepth = 550;
            :>> isPatent = true;
            :>> isSecured = false;
        }
        part suction : SuctionApparatus {
            :>> suctionPressure = 80;
            :>> isIntermittent = true;
        }
        part feedingPump : FeedingPump {
            :>> deliveryRate = 100;
            :>> volumeToDeliver = 500;
        }
        part verifier : VerificationEquipment {
            :>> pHLowerBound = 1.0;
            :>> pHUpperBound = 5.5;
        }
        ref clinician : Clinician;
        ref patient : Patient {
            :>> isSuitable = true;
            :>> nasalPatency = true;
            :>> esophagealPatency = true;
            :>> gastricResidualVolume = 250;
        }
        connection tubeToSuction {
            end :>> nasogastricTube.externalPort;
            end :>> suction.suctionPort;
        }
        connection tubeToFeedingPump {
            end :>> nasogastricTube.externalPort;
            end :>> feedingPump.pumpPort;
        }
        connection tubeToVerifier {
            end :>> nasogastricTube.externalPort;
            end :>> verifier.samplePort;
        }
    }

    verification verifyCorrectPlacement : CorrectPlacementRequirement {
        subject tube :> gastricIntubationSystem.nasogastricTube;
        subject patient :> gastricIntubationSystem.patient;
        subject equipment :> gastricIntubationSystem.verifier;
    }
    verification verifyTubePatency : TubePatencyRequirement {
        subject tube :> gastricIntubationSystem.nasogastricTube;
    }
    verification verifyControlledFeeding : ControlledFeedingRequirement {
        subject pump :> gastricIntubationSystem.feedingPump;
    }
    verification verifySuctionSafety : SuctionSafetyRequirement {
        subject suction :> gastricIntubationSystem.suction;
    }
    verification verifyPatientSuitability : PatientSuitabilityRequirement {
        subject patient :> gastricIntubationSystem.patient;
        subject clinician :> gastricIntubationSystem.clinician;
    }
}
