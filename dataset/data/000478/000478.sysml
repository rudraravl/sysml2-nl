package NeedlelessConnectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidType;
    attribute def SterilityStatus;
    attribute def ConnectionState;
    
    attribute def FluidPressure :> Real;
    attribute def FluidFlowRate :> Real;
    attribute def FluidVolume :> Real;
    attribute def ActivationForce :> Real;
    
    item def MedicalFluid {
        attribute fluidType: FluidType;
        attribute volume: FluidVolume;
        attribute pressure: FluidPressure;
        attribute sterile: Boolean;
    }
    
    port def FluidPort {
        attribute pressure: FluidPressure;
        attribute flowRate: FluidFlowRate;
        attribute connected: Boolean;
    }
    
    part def NeedlelessConnector {
        doc /* 
         * A needleless connector enables safe fluid transfer in medical applications
         * without the use of needles, reducing needlestick injury risk and maintaining
         * a sterile fluid pathway.
         */
        
        attribute connectorID: String;
        attribute maxOperatingPressure: FluidPressure;
        attribute minActivationForce: ActivationForce;
        
        port proximalPort: FluidPort;
        port distalPort: FluidPort;
        
        part mechanicalValve {
            attribute position: Real;
            attribute isClosed: Boolean;
            attribute sealIntegrity: Real;
        }
        
        part activationMechanism {
            attribute appliedForce: ActivationForce;
            attribute engaged: Boolean;
        }
        
        part fluidChannel {
            attribute channelOpen: Boolean;
            attribute internalVolume: FluidVolume;
        }
        
        part antimicrobialBarrier {
            attribute barrierIntact: Boolean;
            attribute sterilityMaintained: Boolean;
        }
    }
    
    part def IVLine {
        attribute lineLength: Real;
        attribute innerDiameter: Real;
        port catheterEnd: FluidPort;
    }
    
    part def SyringeAdapter {
        attribute adapterType: String;
        attribute lockingEnabled: Boolean;
        port syringeConnection: FluidPort;
    }
    
    part def FluidReservoir {
        attribute reservoirType: String;
        attribute capacity: FluidVolume;
        attribute currentVolume: FluidVolume;
        port outlet: FluidPort;
    }
    
    action def EstablishConnection {
        in connectorRef: NeedlelessConnector;
        in adapterRef: SyringeAdapter;
        out connectionSecure: Boolean;
        out sealVerified: Boolean;
        
        first start;
        then action alignDevices;
        then action applyActivationForce {
            in requiredForce: ActivationForce;
        }
        then action verifyEngagement {
            out engaged: Boolean;
        }
        then assign connectionSecure := verifyEngagement.engaged;
        then action checkSeal {
            out sealOK: Boolean;
        }
        then assign sealVerified := checkSeal.sealOK;
        then done;
    }
    
    action def TransferFluid {
        in sourcePressure: FluidPressure;
        in targetVolume: FluidVolume;
        in maxFlowRate: FluidFlowRate;
        out volumeDelivered: FluidVolume;
        out actualFlowRate: FluidFlowRate;
        
        private attribute transferred: FluidVolume;
        
        first start;
        then merge continueTransfer;
        
        action monitorFlow {
            in currentPressure: FluidPressure;
            out flowRate: FluidFlowRate;
        }
        
        then decide;
            if transferred < targetVolume then deliverIncrement;
            if transferred >= targetVolume then completeTransfer;
        
        action deliverIncrement {
            in incrementVolume: FluidVolume;
        }
        then continueTransfer;
        
        action completeTransfer {
            assign volumeDelivered := transferred;
        }
        then done;
    }
    
    action def TerminateConnection {
        in connectorRef: NeedlelessConnector;
        out valveSealed: Boolean;
        out sterilityPreserved: Boolean;
        
        first start;
        then action releaseAdapter;
        then action closeValve;
        then assign valveSealed := true;
        then action verifySterileBarrier {
            out barrierIntact: Boolean;
        }
        then assign sterilityPreserved := verifySterileBarrier.barrierIntact;
        then done;
    }
    
    action def PerformFluidAdministration {
        in reservoirRef: FluidReservoir;
        in targetVolume: FluidVolume;
        in targetFlowRate: FluidFlowRate;
        out administrationComplete: Boolean;
        
        first start;
        then action connect: EstablishConnection {
            out connectionSecure;
            out sealVerified;
        }
        
        then decide;
            if connect.connectionSecure and connect.sealVerified then initiateFlow;
            if not connect.connectionSecure or not connect.sealVerified then abortProcedure;
        
        action initiateFlow {
            action transfer: TransferFluid {
                in sourcePressure;
                in targetVolume = PerformFluidAdministration::targetVolume;
                in maxFlowRate = PerformFluidAdministration::targetFlowRate;
                out volumeDelivered;
                out actualFlowRate;
            }
        }
        
        then action disconnect: TerminateConnection {
            out valveSealed;
            out sterilityPreserved;
        }
        
        then assign administrationComplete := disconnect.valveSealed and disconnect.sterilityPreserved;
        then done;
        
        action abortProcedure {
            assign administrationComplete := false;
        }
        then done;
    }
    
    part needlelessFluidDeliverySystem {
        doc /*
         * The needleless connector system provides safe, sterile fluid transfer
         * in medical settings by enabling connection and disconnection of fluid
         * delivery devices without needles. This reduces needlestick injury risk
         * and maintains a closed, sterile pathway throughout the fluid administration
         * process.
         */
        
        part mainConnector: NeedlelessConnector {
            attribute connectorID = "NC-PRIMARY-001";
            attribute maxOperatingPressure: FluidPressure = 300.0;
            attribute minActivationForce: ActivationForce = 2.0;
        }
        
        part patientLine: IVLine {
            attribute lineLength: Real = 150.0;
            attribute innerDiameter: Real = 2.5;
        }
        
        part syringeInterface: SyringeAdapter {
            attribute adapterType = "Luer-Lock";
            attribute lockingEnabled = true;
        }
        
        part medicationReservoir: FluidReservoir {
            attribute reservoirType = "IV Bag";
            attribute capacity: FluidVolume = 1000.0;
            attribute currentVolume: FluidVolume = 500.0;
        }
        
        connection fluidPathway1 connect 
            medicationReservoir.outlet to mainConnector.proximalPort;
        
        connection fluidPathway2 connect 
            mainConnector.distalPort to patientLine.catheterEnd;
        
        connection deviceInterface connect 
            syringeInterface.syringeConnection to mainConnector.proximalPort;
        
        perform action administrationCycle: PerformFluidAdministration {
            in reservoirRef = medicationReservoir;
            in targetVolume: FluidVolume = 50.0;
            in targetFlowRate: FluidFlowRate = 100.0;
            out administrationComplete;
        }
    }
    
    requirement def SystemSafetyRequirement {
        doc /* Base requirement for safety-critical system specifications. */
        subject system: NeedlelessConnector;
    }
    
    requirement def SterilePathwayRequirement :> SystemSafetyRequirement {
        doc /* 
         * The connector shall maintain a sterile fluid pathway during all phases
         * of operation including connection, fluid transfer, and disconnection.
         */
    }
    
    requirement def PressureIntegrityRequirement :> SystemSafetyRequirement {
        doc /* 
         * The connector shall withstand maximum operating pressure without
         * leakage or structural failure.
         */
    }
    
    requirement def NeedlestickPreventionRequirement {
        doc /* 
         * The system shall eliminate needlestick injury risk by providing
         * needleless access for all fluid transfer operations.
         */
        
        subject system: needlelessFluidDeliverySystem;
    }
    
    requirement def AutomaticSealingRequirement {
        doc /* 
         * The connector valve shall automatically close and seal upon
         * disconnection to prevent fluid leakage and contamination.
         */
        
        subject connector: NeedlelessConnector;
    }
    
    requirement primarySystemMission {
        doc /* 
         * The needleless connector system shall enable safe, sterile transfer
         * of medical fluids between devices without the use of needles, thereby
         * reducing needlestick injury risk and maintaining infection control
         * throughout the fluid administration process.
         */
        
        require sterilePathway: SterilePathwayRequirement;
        require pressureIntegrity: PressureIntegrityRequirement;
        require needlestickPrevention: NeedlestickPreventionRequirement;
        require automaticSealing: AutomaticSealingRequirement;
    }
}
