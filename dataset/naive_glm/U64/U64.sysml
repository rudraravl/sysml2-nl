package GaitBeltSystem {
    import ScalarValues::*;
    import ISQ::*;

    value type MassValue :> Mass;
    value type ForceValue :> Force;
    value type LengthValue :> Length;
    value type Dimensionless :> Real;

    item def Patient {
        attribute mobilityLevel : String;
        attribute fatigueDetected : Boolean;
        attribute distressDetected : Boolean;
        attribute balanceStable : Boolean;
        attribute wobbleDetected : Boolean;
        attribute fallImminent : Boolean;
        attribute safelyLowered : Boolean;
        attribute weight : MassValue;
    }

    item def Caregiver {
        attribute assessmentComplete : Boolean;
        attribute gripEstablished : Boolean;
        attribute stabilizingForce : ForceValue;
        attribute upwardLift : ForceValue;
        attribute counterbalance : ForceValue;
    }

    item def TransferSurface {
        attribute surfaceType : String;
    }

    part def QuickReleaseBuckle {
        attribute material : String = "Metal";
        attribute releaseType : String = "Quick-release";
        attribute fastened : Boolean;
        attribute breakingStrength : ForceValue = 2500 [N];
    }

    part def NonSlipGripHandle {
        attribute material : String = "Non-slip rubber";
        attribute position : String = "Back";
        attribute gripFirmness : Dimensionless = 0.9;
    }

    port def BeltInterfacePort {
        attribute appliedForce : ForceValue;
        attribute liftForce : ForceValue;
        attribute stabilizingForce : ForceValue;
    }

    part def GaitBelt {
        attribute material : String = "Reinforced nylon webbing";
        attribute beltLength : LengthValue = 1.5 [m];
        attribute beltWidth : LengthValue = 0.05 [m];
        attribute breakingStrength : ForceValue = 2000 [N];
        attribute secured : Boolean;
        attribute snugFit : Boolean;

        part buckle : QuickReleaseBuckle;
        part handles : NonSlipGripHandle[0..2];

        port beltInterface : BeltInterfacePort;

        action def ApplyBelt(in p : Patient, in b : GaitBelt) {
            // Secure belt around patient waist
            // Ensure snug fit allowing two fingers underneath
        }

        action def RemoveBelt(in p : Patient, in b : GaitBelt) {
            // Release buckle and remove belt
        }
    }

    part def GaitBeltSystem {
        part belt : GaitBelt;
        ref item patient : Patient;
        ref item caregiver : Caregiver;
        ref item targetSurface : TransferSurface;

        connection caregiverToBelt : Caregiver ~> belt.beltInterface;
        connection beltToPatient : belt.beltInterface ~> patient;

        state def UsageStateMachine {
            entry action {
                caregiver.assessmentComplete := false;
                belt.secured := false;
                belt.snugFit := false;
                caregiver.gripEstablished := false;
                patient.balanceStable := true;
                patient.safelyLowered := false;
            }

            state AssessingMobility {
                entry action {
                    // Caregiver assesses patient mobility level
                    // Determine transfer type and assistance required
                    caregiver.assessmentComplete := true;
                }
            }

            state ApplyingBelt {
                entry action {
                    belt.ApplyBelt(patient, belt);
                    // Verify snug fit: two fingers slip underneath
                    belt.snugFit := true;
                    belt.secured := true;
                }
            }

            state EstablishingGrip {
                entry action {
                    // Caregiver establishes firm underhand grip on belt/handles
                    caregiver.gripEstablished := true;
                    caregiver.stabilizingForce := 20 [N];
                    caregiver.upwardLift := 0 [N];
                    caregiver.counterbalance := 0 [N];
                }
            }

            state AssistingTransfer {
                do action {
                    // Caregiver walks with patient
                    // Provides physical support, gentle upward lift, counterbalance
                    caregiver.upwardLift := 30 [N];
                    caregiver.counterbalance := 15 [N];
                    // Continuous monitoring for fatigue, distress, loss of balance
                    if patient.fatigueDetected or patient.distressDetected then {
                        patient.balanceStable := false;
                    }
                }
            }

            state RespondingToInstability {
                entry action {
                    // Patient begins to wobble
                    // Increase stabilizing force through belt
                    caregiver.stabilizingForce := 80 [N];
                    caregiver.counterbalance := 40 [N];
                }
                do action {
                    // Continue monitoring and stabilize
                    if patient.balanceStable then {
                        // return to assisting
                    }
                    if patient.fallImminent then {
                        // proceed to guided fall
                    }
                }
            }

            state GuidingFall {
                entry action {
                    // Significant loss of balance, fall imminent
                    // Use belt to safely guide patient down to nearest surface
                    caregiver.stabilizingForce := 120 [N];
                    caregiver.upwardLift := 50 [N];
                }
                do action {
                    // Guide patient to floor or chair
                    patient.safelyLowered := true;
                }
            }

            state RemovingBelt {
                entry action {
                    belt.RemoveBelt(patient, belt);
                    belt.secured := false;
                }
            }

            transition from AssessingMobility to ApplyingBelt
                when caregiver.assessmentComplete == true;

            transition from ApplyingBelt to EstablishingGrip
                when belt.secured == true and belt.snugFit == true;

            transition from EstablishingGrip to AssistingTransfer
                when caregiver.gripEstablished == true;

            transition from AssistingTransfer to RespondingToInstability
                when patient.wobbleDetected == true;

            transition from RespondingToInstability to AssistingTransfer
                when patient.balanceStable == true and patient.fallImminent == false;

            transition from RespondingToInstability to GuidingFall
                when patient.fallImminent == true;

            transition from AssistingTransfer to RemovingBelt
                when patient.balanceStable == true and patient.safelyLowered == false
                and transferComplete == true;

            transition from GuidingFall to RemovingBelt
                when patient.safelyLowered == true;

            attribute transferComplete : Boolean;
        }

        part usageController : UsageStateMachine;
    }

    requirement def SecureFasteningRequirement {
        subject belt : GaitBelt;
        requirement {
            belt.buckle.releaseType == "Quick-release" and
            belt.buckle.breakingStrength >= 1500 [N]
        }
    }

    requirement def DurableMaterialRequirement {
        subject belt : GaitBelt;
        requirement {
            belt.material == "Reinforced nylon webbing" and
            belt.breakingStrength >= 1500 [N]
        }
    }

    requirement def SnugFitRequirement {
        subject belt : GaitBelt;
        requirement {
            belt.snugFit == true
        }
        doc /* Belt must allow two fingers to slip underneath while remaining snug */
    }

    requirement def GripHandleRequirement {
        subject belt : GaitBelt;
        requirement {
            sizeOf(belt.handles) >= 0 and sizeOf(belt.handles) <= 2
        }
    }

    requirement def FallPreventionRequirement {
        subject system : GaitBeltSystem;
        requirement {
            // System must reduce risk of uncontrolled fall
            // and guide patient safely to nearest surface
        }
    }

    requirement def ContinuousMonitoringRequirement {
        subject system : GaitBeltSystem;
        requirement {
            // Caregiver must continuously monitor patient for
            // fatigue, distress, or loss of balance
        }
    }

    requirement def SafeDescentRequirement {
        subject system : GaitBeltSystem;
        requirement {
            // When fall is imminent, system procedure must guide
            // patient down to nearest surface preventing uncontrolled fall
        }
    }

    requirement def GaitBeltSystemRequirement {
        subject system : GaitBeltSystem;
        satisfy SecureFasteningRequirement by system.belt;
        satisfy DurableMaterialRequirement by system.belt;
        satisfy SnugFitRequirement by system.belt;
        satisfy GripHandleRequirement by system.belt;
        satisfy FallPreventionRequirement by system;
        satisfy ContinuousMonitoringRequirement by system;
        satisfy SafeDescentRequirement by system;
    }
}
