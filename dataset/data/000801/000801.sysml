package TransferBoardSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TransferCommand;
    attribute def SafetyStatus {
        attribute isLocked : Boolean;
        attribute loadWithinLimits : Boolean;
        attribute positionStable : Boolean;
    }
    
    item def Patient {
        attribute mass : MassValue;
        attribute identifier : String;
    }
    
    attribute def FrictionCoefficient :> Real;
    attribute def SurfaceAreaValue :> ISQ::AreaValue;
    
    port def PatientContactPort {
        in item patient : Patient;
        out attribute contactForce : ForceValue;
    }
    
    port def SurfaceInterfacePort {
        attribute normalForce : ForceValue;
        attribute frictionForce : ForceValue;
    }
    
    port def ControlInterfacePort {
        in attribute command : TransferCommand;
        out attribute status : SafetyStatus;
    }
    
    part def SupportSurface {
        attribute surfaceHeight : LengthValue;
        attribute surfaceWidth : LengthValue;
        attribute maxLoadCapacity : MassValue;
        
        port surfaceContact : SurfaceInterfacePort;
    }
    
    part def TransferBoard {
        doc /* A rigid sliding board that bridges two surfaces to enable safe patient transfer. */
        
        attribute boardLength : LengthValue;
        attribute boardWidth : LengthValue;
        attribute boardThickness : LengthValue;
        attribute maxLoadCapacity : MassValue;
        attribute topSurfaceFriction : FrictionCoefficient;
        attribute bottomSurfaceFriction : FrictionCoefficient;
        attribute surfaceArea : SurfaceAreaValue;
        
        port patientContact : PatientContactPort;
        port originInterface : SurfaceInterfacePort;
        port destinationInterface : SurfaceInterfacePort;
        port controlInterface : ControlInterfacePort;
    }
    
    part def CaregiverOperator {
        attribute operatorID : String;
        attribute certificationLevel : String;
    }
    
    action def PositionBoard {
        doc /* Position the transfer board to bridge origin and destination surfaces. */
        
        in board : TransferBoard;
        in originSurface : SupportSurface;
        in destinationSurface : SupportSurface;
        out boardPositioned : Boolean;
    }
    
    action def SecureBoard {
        doc /* Ensure the board is stable and locked in position. */
        
        in board : TransferBoard;
        out boardSecured : Boolean;
    }
    
    action def VerifyPatientLoad {
        doc /* Verify patient mass is within board capacity limits. */
        
        in patient : Patient;
        in maxCapacity : MassValue;
        out loadSafe : Boolean;
    }
    
    action def SlidePatient {
        doc /* Slide the patient across the board from origin to destination. */
        
        in patient : Patient;
        in board : TransferBoard;
        in appliedForce : ForceValue;
        out patientMoved : Boolean;
    }
    
    action def RemoveBoard {
        doc /* Remove the transfer board after patient transfer is complete. */
        
        in board : TransferBoard;
        out boardRemoved : Boolean;
    }
    
    action def PerformPatientTransfer {
        doc /* Execute the complete patient transfer procedure using the transfer board. */
        
        in attribute patientToTransfer : Patient;
        in attribute transferBoard : TransferBoard;
        in attribute origin : SupportSurface;
        in attribute destination : SupportSurface;
        in attribute operator : CaregiverOperator;
        out attribute transferComplete : Boolean;
        out attribute safetyStatus : SafetyStatus;
        
        private attribute boardReady : Boolean := false;
        private attribute loadVerified : Boolean := false;
        private attribute transferSuccessful : Boolean := false;
        
        first start;
        
        then action positionBoard : PositionBoard {
            in board = transferBoard;
            in originSurface = origin;
            in destinationSurface = destination;
            out boardPositioned;
        }
        
        then action secureBoard : SecureBoard {
            in board = transferBoard;
            out boardSecured;
        }
        
        then assign boardReady := secureBoard.boardSecured;
        
        then decide;
            if boardReady then verifyLoad;
            if not boardReady then abortTransfer;
        
        action verifyLoad : VerifyPatientLoad {
            in patient = patientToTransfer;
            in maxCapacity = transferBoard.maxLoadCapacity;
            out loadSafe;
        }
        
        then assign loadVerified := verifyLoad.loadSafe;
        
        then decide;
            if loadVerified then slidePatient;
            if not loadVerified then abortTransfer;
        
        action slidePatient : SlidePatient {
            in patient = patientToTransfer;
            in board = transferBoard;
            in appliedForce = 50.0 [SI::N];
            out patientMoved;
        }
        
        then assign transferSuccessful := slidePatient.patientMoved;
        
        then action removeBoard : RemoveBoard {
            in board = transferBoard;
            out boardRemoved;
        }
        
        then assign transferComplete := removeBoard.boardRemoved and transferSuccessful;
        then assign safetyStatus := SafetyStatus {
            isLocked = boardReady;
            loadWithinLimits = loadVerified;
            positionStable = transferSuccessful;
        }
        then merge completeTransfer;
        
        action abortTransfer {
            assign transferComplete := false;
            assign safetyStatus := SafetyStatus {
                isLocked = false;
                loadWithinLimits = false;
                positionStable = false;
            };
        }
        
        then completeTransfer;
        
        merge completeTransfer;
        
        then done;
    }
    
    state def TransferBoardLifecycle {
        doc /* State machine governing the transfer board operational states. */
        
        entry; then idle;
        
        state idle {
            doc /* Board is not in use and ready for deployment. */
        }
        
        transition idle_to_positioning
            first idle
            accept deployCommand : TransferCommand
            then positioning;
        
        state positioning {
            doc /* Board is being positioned between surfaces. */
            entry action positionBoardAction : PositionBoard;
        }
        
        transition positioning_to_secured
            first positioning
            if positionBoardAction.boardPositioned
            then secured;
        
        transition positioning_to_idle
            first positioning
            if not positionBoardAction.boardPositioned
            then idle;
        
        state secured {
            doc /* Board is locked in position and ready for patient transfer. */
            entry action secureBoardAction : SecureBoard;
        }
        
        transition secured_to_transferring
            first secured
            accept transferCommand : TransferCommand
            then transferring;
        
        state transferring {
            doc /* Patient is being moved across the board. */
            entry action slidePatientAction : SlidePatient;
        }
        
        transition transferring_to_removing
            first transferring
            if slidePatientAction.patientMoved
            then removing;
        
        transition transferring_to_secured
            first transferring
            if not slidePatientAction.patientMoved
            then secured;
        
        state removing {
            doc /* Board is being removed after successful transfer. */
            entry action removeBoardAction : RemoveBoard;
        }
        
        transition removing_to_idle
            first removing
            if removeBoardAction.boardRemoved
            then idle;
    }
    
    part transferBoardSystem : TransferBoard {
        doc /* A complete transfer board system for safe patient mobility between surfaces. */
        
        attribute :>> boardLength = 1.8 [SI::m];
        attribute :>> boardWidth = 0.45 [SI::m];
        attribute :>> boardThickness = 0.01 [SI::m];
        attribute :>> maxLoadCapacity = 180.0 [SI::kg];
        attribute :>> topSurfaceFriction = 0.15;
        attribute :>> bottomSurfaceFriction = 0.75;
        attribute :>> surfaceArea = 0.81 [SI::m^2];
        
        part originSurface : SupportSurface {
            attribute :>> surfaceHeight = 0.6 [SI::m];
            attribute :>> surfaceWidth = 0.9 [SI::m];
            attribute :>> maxLoadCapacity = 200.0 [SI::kg];
        }
        
        part destinationSurface : SupportSurface {
            attribute :>> surfaceHeight = 0.6 [SI::m];
            attribute :>> surfaceWidth = 0.9 [SI::m];
            attribute :>> maxLoadCapacity = 200.0 [SI::kg];
        }
        
        part caregiver : CaregiverOperator {
            attribute :>> operatorID = "CG-001";
            attribute :>> certificationLevel = "Certified Nursing Assistant";
        }
        
        connection boardToOrigin : FlowConnection connect originInterface to originSurface.surfaceContact;
        connection boardToDestination : FlowConnection connect destinationInterface to destinationSurface.surfaceContact;
        
        perform action transferOperation : PerformPatientTransfer {
            in patientToTransfer := Patient {
                mass = 75.0 [SI::kg];
                identifier = "PT-12345";
            };
            in transferBoard = transferBoardSystem;
            in origin = originSurface;
            in destination = destinationSurface;
            in operator = caregiver;
            out transferComplete;
            out safetyStatus;
        }
        
        exhibit state boardLifecycle : TransferBoardLifecycle;
    }
    
    requirement def LoadCapacityRequirement {
        doc /* The transfer board shall support patient loads up to the specified maximum capacity. */
        
        subject board : TransferBoard;
        
        require constraint {
            board.patientContact.patient.mass <= board.maxLoadCapacity
        }
    }
    
    requirement def FrictionRequirement {
        doc /* The board shall provide low friction on top surface for patient sliding and high friction on bottom for stability. */
        
        subject board : TransferBoard;
        
        require constraint {
            board.topSurfaceFriction < 0.25 and board.bottomSurfaceFriction > 0.6
        }
    }
    
    requirement def StructuralIntegrityRequirement {
        doc /* The board shall maintain structural integrity under maximum load conditions. */
        
        subject board : TransferBoard;
        
        assume constraint {
            board.boardThickness >= 0.008 [SI::m]
        }
        
        require constraint {
            board.maxLoadCapacity >= 150.0 [SI::kg]
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The transfer board system shall enable safe transfer of patients between two support surfaces by providing a low-friction sliding surface that bridges the gap while maintaining stability. */
        
        subject system : TransferBoard;
        
        require loadCapacityReq : LoadCapacityRequirement {
            subject board = system;
        }
        
        require frictionReq : FrictionRequirement {
            subject board = system;
        }
        
        require structuralReq : StructuralIntegrityRequirement {
            subject board = system;
        }
        
        satisfy by system.transferOperation;
    }
}
