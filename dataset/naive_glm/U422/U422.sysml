package PatientTransferBoardSystem {

    import ScalarValues::*;

    //====================================
    // Value types with units
    //====================================
    value type Length :> Real {
        unit "m";
        doc /Linear dimension in meters./;
    }

    value type Mass :> Real {
        unit "kg";
        doc /Mass in kilograms./;
    }

    value type Force :> Real {
        unit "N";
        doc /Force in newtons./;
    }

    value type Time :> Real {
        unit "s";
        doc /Elapsed time in seconds./;
    }

    value type FrictionCoefficient :> Real {
        doc /Dimensionless coefficient of friction, nominally in [0.0, 1.0]./;
        constraint { 0.0 <= self and self <= 1.0 }
    }

    //====================================
    // Attribute definitions
    //====================================
    attribute def BoardGeometry {
        attribute length : Length;
        attribute width : Length;
        attribute thickness : Length;
    }

    attribute def LoadCapacity {
        attribute maximumWeight : Mass;
    }

    //====================================
    // Port definitions
    //====================================
    port def ContactPort {
        in attribute appliedForce : Force;
        attribute effectiveFriction : FrictionCoefficient;
        attribute anchored : Boolean;
    }

    port def PatientInterfacePort {
        in attribute patientWeight : Mass;
        attribute patientOnBoard : Boolean;
        attribute transferComplete : Boolean;
    }

    //====================================
    // Part definitions - surfaces
    //====================================
    part def TransferSurface {
        attribute frictionCoefficient : FrictionCoefficient;
        attribute material : String;
    }

    part def SupportSurface {
        attribute surfaceName : String;
        attribute surfaceFriction : FrictionCoefficient;
        port contactPort : ContactPort;
    }

    part def HospitalBed :> SupportSurface {
        redefinition attribute surfaceName : String := "Hospital bed";
        redefinition attribute surfaceFriction : FrictionCoefficient := 0.6;
    }

    part def StretcherGurney :> SupportSurface {
        redefinition attribute surfaceName : String := "Stretcher gurney";
        redefinition attribute surfaceFriction : FrictionCoefficient := 0.5;
    }

    //====================================
    // Part definitions - board, patient, caregiver
    //====================================
    part def TransferBoard {
        attribute geometry : BoardGeometry := BoardGeometry(1.8, 0.45, 0.015);
        attribute capacity : LoadCapacity := LoadCapacity(250);
        attribute currentLoad : Mass := 0;
        attribute stowed : Boolean := true;

        part topSurface : TransferSurface {
            attribute frictionCoefficient : FrictionCoefficient := 0.05;
            attribute material : String := "PTFE low-friction top coat";
        }

        part bottomSurface : TransferSurface {
            attribute frictionCoefficient : FrictionCoefficient := 0.9;
            attribute material : String := "High-friction rubberized base";
        }

        port originEnd : ContactPort;
        port destinationEnd : ContactPort;
        port patientInterface : PatientInterfacePort;

        constraint maxLoadConstraint {
            currentLoad <= capacity.maximumWeight
        }

        constraint dualSurfaceConstraint {
            topSurface.frictionCoefficient < 0.1 and
            bottomSurface.frictionCoefficient > 0.7
        }
    }

    part def Patient {
        attribute patientId : String;
        attribute weight : Mass;
        attribute cooperative : Boolean := true;
    }

    part def Caregiver {
        attribute caregiverId : String;
        attribute role : String := "attending";
    }

    //====================================
    // Connection definitions
    //====================================
    connection def AnchorLink {
        end source : ContactPort;
        end target : ContactPort;
        attribute anchorFriction : FrictionCoefficient;
    }

    //====================================
    // Action definitions
    //====================================
    action def PositionBoard {
        in board : TransferBoard;
        in origin : SupportSurface;
        in destination : SupportSurface;
        out boardAnchored : Boolean;
        private attribute completed : Boolean := false;
    }

    action def VerifyWeight {
        in patient : Patient;
        in board : TransferBoard;
        out weightVerified : Boolean;
        private attribute withinLimit : Boolean;
    }

    action def SlidePatient {
        in patient : Patient;
        in board : TransferBoard;
        out transferComplete : Boolean;
        private attribute travelTime : Time;
    }

    action def RemoveBoard {
        in board : TransferBoard;
        out boardRemoved : Boolean;
        private attribute completed : Boolean := false;
    }

    //====================================
    // State machine definition
    //====================================
    state def TransferProcedure {
        attribute boardAnchored : Boolean := false;
        attribute weightVerified : Boolean := false;
        attribute transferComplete : Boolean := false;
        attribute boardStowed : Boolean := true;
        attribute caregiverInitiates : Boolean := false;

        state idle;
        state positioning;
        state secured;
        state transferring;
        state removing;

        transition from idle to positioning when caregiverInitiates;
        transition from positioning to secured when boardAnchored;
        transition from secured to transferring when weightVerified;
        transition from transferring to removing when transferComplete;
        transition from removing to idle when boardStowed;
    }

    //====================================
    // Top-level system assembly
    //====================================
    part def PatientTransferSystem {
        part board : TransferBoard;
        part origin : HospitalBed;
        part destination : StretcherGurney;
        part patient : Patient;
        part caregiver : Caregiver;

        connection originAnchor : AnchorLink connect board.originEnd to origin.contactPort;
        connection destinationAnchor : AnchorLink connect board.destinationEnd to destination.contactPort;

        attribute boardAnchored : Boolean := false;
        attribute weightVerified : Boolean := false;
        attribute transferComplete : Boolean := false;
        attribute boardStowed : Boolean := true;
        attribute caregiverInitiates : Boolean := false;

        state transferProcedure : TransferProcedure {
            state idle {
                entry {
                    board.stowed := true;
                    board.currentLoad := 0;
                    boardAnchored := false;
                    weightVerified := false;
                    transferComplete := false;
                    boardStowed := true;
                }
            }

            state positioning {
                entry action performPositioning : PositionBoard {
                    in board = board;
                    in origin = origin;
                    in destination = destination;
                    out boardAnchored = boardAnchored;
                }
                exit {
                    board.originEnd.anchored := true;
                    board.destinationEnd.anchored := true;
                    boardAnchored := true;
                }
            }

            state secured {
                entry action performVerification : VerifyWeight {
                    in patient = patient;
                    in board = board;
                    out weightVerified = weightVerified;
                }
                exit {
                    weightVerified := (patient.weight <= board.capacity.maximumWeight);
                }
            }

            state transferring {
                entry {
                    board.currentLoad := patient.weight;
                    board.patientInterface.patientOnBoard := true;
                }
                entry action performSlide : SlidePatient {
                    in patient = patient;
                    in board = board;
                    out transferComplete = transferComplete;
                }
                exit {
                    board.patientInterface.patientOnBoard := false;
                    board.currentLoad := 0;
                    transferComplete := true;
                }
            }

            state removing {
                entry action performRemoval : RemoveBoard {
                    in board = board;
                    out boardRemoved = boardStowed;
                }
                exit {
                    board.stowed := true;
                    board.originEnd.anchored := false;
                    board.destinationEnd.anchored := false;
                    boardStowed := true;
                }
            }
        }
    }

    //====================================
    // Requirements
    //====================================
    requirement def DualSurfaceDesignRequirement {
        doc /The transfer board shall have a low-friction top surface (coefficient < 0.1) for sliding the patient and a high-friction bottom surface (coefficient > 0.7) for gripping the support surfaces./;
        subject board : TransferBoard;
        constraint { board.topSurface.frictionCoefficient < 0.1 }
        constraint { board.bottomSurface.frictionCoefficient > 0.7 }
    }

    requirement def LoadCapacityRequirement {
        doc /The transfer board shall safely support a maximum patient weight of at least 250 kg./;
        subject board : TransferBoard;
        constraint { board.capacity.maximumWeight >= 250 }
    }

    requirement def WeightVerificationRequirement {
        doc /Before initiating patient transfer, the system shall verify that the patient's weight does not exceed the board's maximum load capacity./;
        subject patient : Patient;
        subject board : TransferBoard;
        constraint { patient.weight <= board.capacity.maximumWeight }
    }

    requirement def BoardGeometryRequirement {
        doc /The board shall have defined physical dimensions suitable for bridging two adjacent surfaces: length at least 1.6 m, width at least 0.4 m, thickness no more than 0.02 m./;
        subject board : TransferBoard;
        constraint { board.geometry.length >= 1.6 }
        constraint { board.geometry.width >= 0.4 }
        constraint { board.geometry.thickness <= 0.02 }
    }

    requirement def SafeStateSequenceRequirement {
        doc /The transfer procedure shall progress through the ordered states: idle, positioning, secured, transferring, removing, and back to idle./;
        subject procedure : TransferProcedure;
    }

    requirement def OriginDestinationRequirement {
        doc /The system shall include an origin support surface and a destination support surface between which the patient is transferred./;
        subject system : PatientTransferSystem;
        constraint { system.origin <> system.destination }
    }

    requirement def CaregiverPresenceRequirement {
        doc /A qualified caregiver shall be present to perform the transfer procedure./;
        subject caregiver : Caregiver;
    }

    requirement def SafeTransferSystemRequirement {
        doc /The patient transfer board system shall provide a safe, structured procedure for moving a patient between two support surfaces while preventing board slippage and overload./;
        subject system : PatientTransferSystem;
    }

    requirement dualSurfaceReq : DualSurfaceDesignRequirement;
    requirement loadCapacityReq : LoadCapacityRequirement;
    requirement weightVerificationReq : WeightVerificationRequirement;
    requirement boardGeometryReq : BoardGeometryRequirement;
    requirement stateSequenceReq : SafeStateSequenceRequirement;
    requirement originDestinationReq : OriginDestinationRequirement;
    requirement caregiverPresenceReq : CaregiverPresenceRequirement;
    requirement safeTransferReq : SafeTransferSystemRequirement;

    //====================================
    // Satisfaction relationships
    //====================================
    satisfaction satisfyDualSurface : DualSurfaceDesignRequirement by board;
    satisfaction satisfyLoadCapacity : LoadCapacityRequirement by board;
    satisfaction satisfyBoardGeometry : BoardGeometryRequirement by board;
    satisfaction satisfyWeightVerification : WeightVerificationRequirement by patient;
    satisfaction satisfyStateSequence : SafeStateSequenceRequirement by transferProcedure;
    satisfaction satisfyOriginDestination : OriginDestinationRequirement by origin;
    satisfaction satisfyCaregiverPresence : CaregiverPresenceRequirement by caregiver;
    satisfaction satisfySafeTransfer : SafeTransferSystemRequirement by board;
}
