package HospitalPatientGownSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====

    value def TemperatureValue :> Real {
        unit '°C';
    }

    value def DurationValue :> Real {
        unit 'h';
    }

    value def MassValue :> Real {
        unit 'g';
    }

    value def LengthValue :> Real {
        unit 'm';
    }

    value def CountValue :> Integer;

    item def CottonPolyesterBlend {
        attribute cottonFraction : Real;
        attribute polyesterFraction : Real;
        attribute breathabilityRating : Real;
        attribute durabilityRating : Real;
    }

    item def MedicalGradeDetergent {
        attribute concentration : Real;
        attribute disinfectionLevel : Real;
    }

    item def SoiledLinenBatch {
        attribute gownCount : CountValue;
        attribute contaminationLevel : Real;
    }

    // ===== Requirements =====

    requirement def ModestyRequirement {
        doc /* The gown shall cover the patient's front torso and maintain dignity. */
        subject gown : PatientGown;
        constraint { gown.frontCoverage >= 0.95 }
    }

    requirement def AccessibilityRequirement {
        doc /* The gown shall provide open back access for examinations. */
        subject gown : PatientGown;
        constraint { gown.backOpenArea >= 0.80 }
    }

    requirement def SterilizationRequirement {
        doc /* The gown shall withstand washing at high temperature for sterilization. */
        subject gown : PatientGown;
        constraint { gown.maxWashTemperature >= 90.0 }
    }

    requirement def FasteningRequirement {
        doc /* The gown shall have tie strings at neck and waist. */
        subject gown : PatientGown;
        constraint { gown.neckTieCount >= 2 and gown.waistTieCount >= 2 }
    }

    requirement def ComfortRequirement {
        doc /* The gown shall be comfortable for extended wear. */
        subject gown : PatientGown;
        constraint { gown.material.breathabilityRating >= 0.7 }
    }

    requirement def InfectionControlRequirement {
        doc /* The laundry system shall wash gowns at high temperature with medical-grade detergent. */
        subject laundry : LaundrySystem;
        constraint { laundry.washTemperature >= 90.0 and laundry.detergent.disinfectionLevel >= 0.99 }
    }

    // ===== Parts =====

    part def PatientGown {
        attribute maxWashTemperature : TemperatureValue = 95.0;
        attribute frontCoverage : Real = 0.97;
        attribute backOpenArea : Real = 0.85;
        attribute neckTieCount : CountValue = 2;
        attribute waistTieCount : CountValue = 2;
        attribute mass : MassValue = 250.0;
        attribute size : String = "universal";

        part material : CottonPolyesterBlend {
            reattribute cottonFraction = 0.60;
            reattribute polyesterFraction = 0.40;
            reattribute breathabilityRating = 0.85;
            reattribute durabilityRating = 0.90;
        }

        part neckTies[2] :> TieString;
        part waistTies[2] :> TieString;

        port def GownInteractionPort {
            in item soiledGown : PatientGown;
            out item cleanGown : PatientGown;
        }

        port interactionPort : GownInteractionPort;

        exhibit state gownLifecycle {
            entry; then clean;

            state clean {
                doc /* Gown is sanitized and ready for use. */
            }

            state issued {
                doc /* Gown has been issued to a patient. */
            }

            state worn {
                doc /* Gown is being worn and secured by patient. */
            }

            state adjusted {
                doc /* Gown is temporarily adjusted for examination. */
            }

            state soiled {
                doc /* Gown is removed and awaiting laundry. */
            }

            state washing {
                doc /* Gown is in the laundry wash cycle. */
            }

            state inspecting {
                doc /* Gown is being inspected post-wash. */
            }

            state damaged {
                doc /* Gown is damaged and to be discarded. */
            }

            state discarded {
                doc /* Gown is removed from service. */
            }

            transition clean -> issued
                when issuedToPatient;

            transition issued -> worn
                when securedByPatient;

            transition worn -> adjusted
                when staffAccessNeeded;

            transition adjusted -> worn
                when resecured;

            transition worn -> soiled
                when removedAfterUse;

            transition soiled -> washing
                when sentToLaundry;

            transition washing -> inspecting
                when washCycleComplete;

            transition inspecting -> clean
                when inspectionPassed;

            transition inspecting -> damaged
                when inspectionFailed;

            transition worn -> damaged
                when damageDetected;

            transition washing -> damaged
                when damageDuringWash;

            transition damaged -> discarded
                when removedFromService;
        }
    }

    part def TieString {
        attribute length : LengthValue = 0.45;
        attribute material : String = "cotton-polyester";
    }

    part def Patient {
        attribute mobilityLevel : Real;
        attribute requiresAssistance : Boolean;

        port def PatientGownPort {
            in item gown : PatientGown;
            out item usedGown : PatientGown;
        }

        port gownPort : PatientGownPort;

        exhibit state patientGownInteraction {
            entry; then awaitingGown;

            state awaitingGown;
            state receivingGown;
            state wearingGown;
            state beingExamined;
            state removingGown;

            transition awaitingGown -> receivingGown
                when gownIssued;

            transition receivingGown -> wearingGown
                when gownSecured;

            transition wearingGown -> beingExamined
                when examinationStarts;

            transition beingExamined -> wearingGown
                when examinationEnds;

            transition wearingGown -> removingGown
                when careComplete;
        }
    }

    part def ClinicalStaff {
        attribute role : String;
        attribute staffId : String;

        port def StaffGownPort {
            in item gown : PatientGown;
            out item adjustedGown : PatientGown;
        }

        port staffGownPort : StaffGownPort;

        exhibit state staffActions {
            entry; then idle;

            state idle;
            state assistingPatient;
            state adjustingGown;
            state performingProcedure;
            state collectingSoiledGown;

            transition idle -> assistingPatient
                when assistanceRequested;

            transition assistingPatient -> adjustingGown
                when gownNeedsAdjustment;

            transition adjustingGown -> performingProcedure
                when accessObtained;

            transition performingProcedure -> adjustingGown
                when procedureComplete;

            transition adjustingGown -> idle
                when gownResecured;

            transition idle -> collectingSoiledGown
                when gownRemoved;

            transition collectingSoiledGown -> idle
                when gownDeliveredToLaundry;
        }
    }

    part def LaundrySystem {
        attribute washTemperature : TemperatureValue = 92.0;
        attribute washDuration : DurationValue = 1.5;
        attribute capacity : CountValue = 200;

        part detergent : MedicalGradeDetergent {
            reattribute concentration = 0.15;
            reattribute disinfectionLevel = 0.995;
        }

        port def LaundryPort {
            in item soiledBatch : SoiledLinenBatch;
            out item cleanGowns : PatientGown[*];
        }

        port laundryPort : LaundryPort;

        exhibit state laundryCycle {
            entry; then ready;

            state ready;
            state receiving;
            state sorting;
            state washing;
            state rinsing;
            state drying;
            state inspecting;
            state dispatching;

            transition ready -> receiving
                when soiledGownsArrive;

            transition receiving -> sorting
                when batchReceived;

            transition sorting -> washing
                when sorted;

            transition washing -> rinsing
                when washComplete;

            transition rinsing -> drying
                when rinseComplete;

            transition drying -> inspecting
                when dryComplete;

            transition inspecting -> dispatching
                when qualityPassed;

            transition inspecting -> ready
                when qualityFailed;

            transition dispatching -> ready
                when gownsReturned;
        }
    }

    // ===== System Assembly =====

    part def HospitalGownEcosystem {

        part gownInventory : PatientGown[10];

        part patients : Patient[5];

        part staff : ClinicalStaff[3] {
            part nurse1 : ClinicalStaff {
                reattribute role = "nurse";
                reattribute staffId = "N001";
            }
            part nurse2 : ClinicalStaff {
                reattribute role = "nurse";
                reattribute staffId = "N002";
            }
            part physician1 : ClinicalStaff {
                reattribute role = "physician";
                reattribute staffId = "P001";
            }
        }

        part laundry : LaundrySystem;

        connection def GownIssuanceConnection {
            end source : LaundrySystem::laundryPort;
            end target : Patient::gownPort;
            item cleanGown : PatientGown;
        }

        connection def SoiledGownReturnConnection {
            end source : Patient::gownPort;
            end target : LaundrySystem::laundryPort;
            item soiledGown : PatientGown;
        }

        connection def StaffAssistConnection {
            end source : ClinicalStaff::staffGownPort;
            end target : Patient::gownPort;
            item adjustedGown : PatientGown;
        }

        connection gownToPatient : GownIssuanceConnection
            connect laundry.laundryPort to patients[1].gownPort;

        connection soiledReturn : SoiledGownReturnConnection
            connect patients[1].gownPort to laundry.laundryPort;

        connection staffAssist : StaffAssistConnection
            connect staff.nurse1.staffGownPort to patients[1].gownPort;

        // Requirement satisfactions
        satisfy ModestyRequirement by gownInventory[1];
        satisfy AccessibilityRequirement by gownInventory[1];
        satisfy SterilizationRequirement by gownInventory[1];
        satisfy FasteningRequirement by gownInventory[1];
        satisfy ComfortRequirement by gownInventory[1];
        satisfy InfectionControlRequirement by laundry;
    }

    // ===== Action Definitions =====

    action def IssueGownToPatient {
        in gown : PatientGown;
        in patient : Patient;
        out issuedGown : PatientGown;
    }

    action def AdjustGownForExamination {
        in gown : PatientGown;
        in staff : ClinicalStaff;
        in bodyRegion : String;
        out adjustedGown : PatientGown;
    }

    action def WashGownCycle {
        in soiledGowns : PatientGown[*];
        in detergent : MedicalGradeDetergent;
        in temperature : TemperatureValue;
        out cleanGowns : PatientGown[*];
        out damagedGowns : PatientGown[*];
    }

    action def InspectGown {
        in washedGown : PatientGown;
        out passedGown : PatientGown;
        out failedGown : PatientGown;
    }

    action def DiscardDamagedGown {
        in damagedGown : PatientGown;
    }

}
