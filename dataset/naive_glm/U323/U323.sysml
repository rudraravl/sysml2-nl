package GastricIntubationSystem {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    def Length :> Real { unit "cm"; }
    def Volume :> Real { unit "mL"; }
    def Pressure :> Real { unit "mmHg"; }
    def FlowRate :> Real { unit "mL/hr"; }
    def pHValue :> Real;

    // Items
    item GastricContent;
    item EnteralFormula;
    item Water;
    item Medication;

    // Port Definitions
    port def TubeExternalPort {
        out item GastricContent;
        in item EnteralFormula;
        in item Water;
        in item Medication;
    }
    port def TubeInternalPort {
        in item GastricContent;
        out item EnteralFormula;
        out item Water;
        out item Medication;
    }
    port def SuctionPort {
        in item GastricContent;
    }
    port def PumpPort {
        out item EnteralFormula;
        out item Water;
    }
    port def NasalPassagePort;
    port def StomachPort {
        in item EnteralFormula;
        in item Water;
        in item Medication;
        out item GastricContent;
    }

    // Part Definitions
    part def Patient {
        port nasalPassage: NasalPassagePort;
        port stomach: StomachPort;
        attribute suitable: Boolean;
        attribute measuredDepth: Length;
    }

    part def NasogastricTube {
        attribute size: Length;
        attribute length: Length;
        attribute insertionDepth: Length;
        attribute prepared: Boolean;
        attribute advanced: Boolean;
        attribute correctPlacement: Boolean;
        attribute secured: Boolean;
        attribute needed: Boolean;
        attribute patent: Boolean;
        port externalPort: TubeExternalPort;
        port internalPort: TubeInternalPort;
    }

    part def SuctionApparatus {
        attribute suctionPressure: Pressure;
        attribute mode: String; // "Intermittent", "Continuous"
        port suctionPort: SuctionPort;
    }

    part def FeedingPump {
        attribute deliveryRate: FlowRate;
        port pumpPort: PumpPort;
    }

    part def VerificationEquipment {
        attribute type: String; // "pH strip", "X-ray"
        attribute pHReading: pHValue;
    }

    part def Clinician {
        attribute qualification: String;
    }

    // Action Definitions
    action def AssessPatient {
        in clinician: Clinician;
        in patient: Patient;
    }
    action def PrepareTube {
        in clinician: Clinician;
        in tube: NasogastricTube;
        in patient: Patient;
    }
    action def AdvanceTube {
        in clinician: Clinician;
        in tube: NasogastricTube;
        in patient: Patient;
    }
    action def VerifyPlacement {
        in equip: VerificationEquipment;
        in tube: NasogastricTube;
    }
    action def SecureTube {
        in clinician: Clinician;
        in tube: NasogastricTube;
        in patient: Patient;
    }
    action def MonitorAndFlush {
        in clinician: Clinician;
        in tube: NasogastricTube;
    }
    action def RemoveTube {
        in clinician: Clinician;
        in tube: NasogastricTube;
    }

    // System Definition
    part def GastricIntubationSystem {
        part clinician: Clinician;
        part patient: Patient;
        part ngTube: NasogastricTube;
        part suctionApp: SuctionApparatus;
        part feedingPump: FeedingPump;
        part verificationEquip: VerificationEquipment;

        connection def NasalInsertionConnection {
            end from: NasalPassagePort;
            end to: TubeInternalPort;
        }
        connection nasalInsertion: NasalInsertionConnection connect patient.nasalPassage to ngTube.internalPort;

        connection def SuctionConnection {
            end from: TubeExternalPort;
            end to: SuctionPort;
        }
        connection suctionConn: SuctionConnection connect ngTube.externalPort to suctionApp.suctionPort;

        connection def FeedingConnection {
            end from: PumpPort;
            end to: TubeExternalPort;
        }
        connection feedingConn: FeedingConnection connect feedingPump.pumpPort to ngTube.externalPort;

        // Behavior: State Machine
        behavior state def GastricIntubationProcedure {
            state Assessment {
                entry action assessPatient(clinician, patient);
            }
            state Preparation {
                entry action prepareTube(clinician, ngTube, patient);
            }
            state Insertion {
                entry action advanceTube(clinician, ngTube, patient);
            }
            state Verification {
                entry action verifyPlacement(verificationEquip, ngTube);
            }
            state Securing {
                entry action secureTube(clinician, ngTube, patient);
            }
            state InUse {
                do action monitorAndFlush(clinician, ngTube);
            }
            state Removal {
                entry action removeTube(clinician, ngTube);
            }

            transition from Assessment to Preparation when patient.suitable == true;
            transition from Preparation to Insertion when ngTube.prepared == true;
            transition from Insertion to Verification when ngTube.advanced == true;
            transition from Verification to Securing when ngTube.correctPlacement == true;
            transition from Verification to Insertion when ngTube.correctPlacement == false;
            transition from Securing to InUse when ngTube.secured == true;
            transition from InUse to Removal when ngTube.needed == false;
        }
    }

    // Requirements
    requirement def CorrectPlacementRequirement {
        doc /* The tube must be verified to be in the stomach, not the airway. */
        subject tube: NasogastricTube;
        require constraint { tube.correctPlacement == true }
    }

    requirement def PatencyRequirement {
        doc /* The tube must remain clear and unblocked. */
        subject tube: NasogastricTube;
        require constraint { tube.patent == true }
    }

    requirement def SuctionControlRequirement {
        doc /* The suction apparatus must apply controlled negative pressure. */
        subject suction: SuctionApparatus;
        require constraint { suction.suctionPressure < 0 }
    }

    requirement def FeedingRateRequirement {
        doc /* The feeding pump must deliver formula at a controlled rate. */
        subject pump: FeedingPump;
        require constraint { pump.deliveryRate > 0 }
    }
}
