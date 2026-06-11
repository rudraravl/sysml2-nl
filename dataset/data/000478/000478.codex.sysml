package NeedlelessConnectorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Volume :> ISQ::volume {
        unit = SI::millilitre;
    }

    attribute def Pressure :> ISQ::pressure {
        unit = SI::kilopascal;
    }

    attribute def FlowRate {
        unit = SI::millilitre / SI::second;
    }

    attribute def Force :> ISQ::force {
        unit = SI::newton;
    }

    attribute def Time :> ISQ::time {
        unit = SI::second;
    }

    attribute def DoseVolume :> Volume;
    attribute def ResidualVolume :> Volume;
    attribute def SealPressure :> Pressure;
    attribute def ConnectorFlowRate :> FlowRate;
    attribute def ActivationForce :> Force;

    enum def ConnectionState {
        enum disconnected;
        enum attached;
        enum flushing;
        enum infusing;
        enum sealed;
        enum faulted;
    }

    enum def FluidCompatibility {
        enum saline;
        enum medication;
        enum bloodProduct;
        enum lipidSolution;
        enum disinfectant;
    }

    item def SterileFluid {
        attribute volume : DoseVolume;
        attribute pressure : Pressure;
        attribute compatibility : FluidCompatibility;
    }

    item def Contaminant {
        attribute particleVolume : Volume;
    }

    item def AirBubble {
        attribute bubbleVolume : Volume;
    }

    item def ClinicianCommand {
        attribute requestedFlowRate : ConnectorFlowRate;
        attribute requestedVolume : DoseVolume;
    }

    item def ConnectorStatus {
        attribute state : ConnectionState;
        attribute internalPressure : Pressure;
        attribute residualVolume : ResidualVolume;
        attribute leakDetected : Boolean;
        attribute airDetected : Boolean;
    }

    port def FluidInletPort {
        in item incomingFluid : SterileFluid;
        out item displacedAir : AirBubble;
    }

    port def FluidOutletPort {
        out item deliveredFluid : SterileFluid;
        in item backPressureSignal : ConnectorStatus;
    }

    port def LuerInterfacePort {
        in item command : ClinicianCommand;
        out item status : ConnectorStatus;
    }

    port def BarrierPort {
        in item contaminant : Contaminant;
        out item rejectedContaminant : Contaminant;
    }

    action def OpenFluidPath {
        in activationForce : ActivationForce;
        out pathOpen : Boolean;
    }

    action def SealFluidPath {
        in internalPressure : Pressure;
        out pathSealed : Boolean;
    }

    action def TransferFluid {
        in fluidIn : SterileFluid;
        in targetFlowRate : ConnectorFlowRate;
        out fluidOut : SterileFluid;
        out residualVolume : ResidualVolume;
    }

    action def RejectContamination {
        in surfaceContaminant : Contaminant;
        out isolatedContaminant : Contaminant;
        out barrierIntact : Boolean;
    }

    action def DetectFaults {
        in pressure : Pressure;
        in residualVolume : ResidualVolume;
        out leakDetected : Boolean;
        out airDetected : Boolean;
    }

    part def NeedlelessConnector {
        attribute maximumWorkingPressure : Pressure = 325 [SI::kilopascal];
        attribute minimumSealPressure : SealPressure = 20 [SI::kilopascal];
        attribute maximumResidualVolume : ResidualVolume = 0.08 [SI::millilitre];
        attribute nominalFlowRate : ConnectorFlowRate = 1.5 [SI::millilitre / SI::second];
        attribute requiredActivationForce : ActivationForce = 8 [SI::newton];
        attribute currentState : ConnectionState = ConnectionState::sealed;

        port proximalLuer : LuerInterfacePort;
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port externalBarrier : BarrierPort;

        part housing {
            attribute internalVolume : Volume = 0.35 [SI::millilitre];
            attribute ratedPressure : Pressure = 325 [SI::kilopascal];
        }

        part compressibleSeptum {
            attribute resealPressure : SealPressure = 25 [SI::kilopascal];
            attribute activationForce : ActivationForce = 8 [SI::newton];
            port exposedSurface : BarrierPort;
        }

        part internalValve {
            attribute crackingPressure : Pressure = 15 [SI::kilopascal];
            attribute openAreaStable : Boolean = true;
        }

        part fluidChannel {
            attribute primingVolume : Volume = 0.22 [SI::millilitre];
            attribute residualHoldUpVolume : ResidualVolume = 0.05 [SI::millilitre];
            port channelIn : FluidInletPort;
            port channelOut : FluidOutletPort;
        }

        part distalAdapter {
            attribute secureLuerLock : Boolean = true;
            port patientSideOutlet : FluidOutletPort;
        }

        part microbialBarrier {
            attribute blocksDirectNeedleAccess : Boolean = true;
            attribute supportsDisinfection : Boolean = true;
            port barrierSurface : BarrierPort;
        }

        connect inlet to fluidChannel.channelIn;
        connect fluidChannel.channelOut to outlet;
        connect outlet to distalAdapter.patientSideOutlet;
        connect externalBarrier to microbialBarrier.barrierSurface;
        connect compressibleSeptum.exposedSurface to microbialBarrier.barrierSurface;

        state def OperatingStateMachine {
            state sealed;
            state disinfecting;
            state connected;
            state open;
            state delivering;
            state flushing;
            state resealing;
            state fault;

            transition first sealed;

            transition sealed_to_disinfecting
                first sealed
                then disinfecting;

            transition disinfecting_to_connected
                first disinfecting
                then connected;

            transition connected_to_open
                first connected
                then open
                action OpenFluidPath {
                    in activationForce = requiredActivationForce;
                }

            transition open_to_delivering
                first open
                then delivering;

            transition delivering_to_flushing
                first delivering
                then flushing;

            transition flushing_to_resealing
                first flushing
                then resealing;

            transition resealing_to_sealed
                first resealing
                then sealed
                action SealFluidPath {
                    in internalPressure = minimumSealPressure;
                }

            transition connected_to_fault
                first connected
                then fault;

            transition delivering_to_fault
                first delivering
                then fault;
        }

        action performPrimaryFunction {
            in clinicianCommand : ClinicianCommand;
            in sourceFluid : SterileFluid;
            out patientFluid : SterileFluid;
            out status : ConnectorStatus;

            action openPath : OpenFluidPath {
                in activationForce = requiredActivationForce;
            }

            action rejectContamination : RejectContamination;

            action transferDose : TransferFluid {
                in fluidIn = sourceFluid;
                in targetFlowRate = clinicianCommand.requestedFlowRate;
            }

            action monitor : DetectFaults {
                in pressure = sourceFluid.pressure;
                in residualVolume = transferDose.residualVolume;
            }

            bind patientFluid = transferDose.fluidOut;
            bind status.leakDetected = monitor.leakDetected;
            bind status.airDetected = monitor.airDetected;
            bind status.residualVolume = transferDose.residualVolume;
        }
    }

    part def InfusionSource {
        attribute availableVolume : Volume = 250 [SI::millilitre];
        attribute deliveryPressure : Pressure = 120 [SI::kilopascal];
        port sourceOutlet : FluidInletPort;
    }

    part def PatientVascularAccess {
        attribute allowablePressure : Pressure = 200 [SI::kilopascal];
        port accessInlet : FluidOutletPort;
    }

    part def ClinicianInterface {
        port luerCommandPort : LuerInterfacePort;
    }

    part def NeedlelessConnectorBasedSystem {
        attribute intendedUse : String = "Provide a closed, needle-free access point that permits sterile fluid transfer into vascular access equipment while reducing needlestick exposure and limiting contamination ingress.";

        part connector : NeedlelessConnector;
        part infusionSource : InfusionSource;
        part vascularAccess : PatientVascularAccess;
        part clinicianInterface : ClinicianInterface;

        connect infusionSource.sourceOutlet to connector.inlet;
        connect connector.outlet to vascularAccess.accessInlet;
        connect clinicianInterface.luerCommandPort to connector.proximalLuer;

        action administerFluidWithoutNeedle {
            in command : ClinicianCommand;
            out deliveredFluid : SterileFluid;
            out connectorStatus : ConnectorStatus;

            action primaryFunction : connector.performPrimaryFunction {
                in clinicianCommand = command;
            }

            bind deliveredFluid = primaryFunction.patientFluid;
            bind connectorStatus = primaryFunction.status;
        }
    }

    requirement def PrimaryNeedlelessAccessRequirement {
        doc /* The system shall enable fluid administration or aspiration through a vascular access path without use of a hypodermic needle. */
        subject system : NeedlelessConnectorBasedSystem;
        require constraint {
            system.connector.compressibleSeptum.blocksDirectNeedleAccess == true
        }
    }

    requirement def ClosedFluidPathRequirement {
        doc /* The connector shall maintain a closed fluid path from source to patient-side outlet during attachment, infusion, flushing, and disconnection. */
        subject connector : NeedlelessConnector;
        require constraint {
            connector.maximumResidualVolume <= 0.10 [SI::millilitre]
        }
    }

    requirement def SealAfterDisconnectionRequirement {
        doc /* The connector shall automatically reseal after disconnection to reduce leakage and contamination ingress. */
        subject connector : NeedlelessConnector;
        require constraint {
            connector.minimumSealPressure >= 20 [SI::kilopascal]
        }
    }

    requirement def WorkingPressureRequirement {
        doc /* The connector shall withstand normal infusion pressure without leakage. */
        subject connector : NeedlelessConnector;
        require constraint {
            connector.maximumWorkingPressure >= 300 [SI::kilopascal]
        }
    }

    requirement def FlowCapabilityRequirement {
        doc /* The connector shall support clinically useful low-volume fluid delivery through the internal channel. */
        subject connector : NeedlelessConnector;
        require constraint {
            connector.nominalFlowRate >= 1.0 [SI::millilitre / SI::second]
        }
    }

    requirement def ContaminationBarrierRequirement {
        doc /* The exposed access surface shall support disinfection and isolate external contamination from the internal sterile fluid path. */
        subject connector : NeedlelessConnector;
        require constraint {
            connector.microbialBarrier.supportsDisinfection == true
        }
    }

    satisfy PrimaryNeedlelessAccessRequirement by NeedlelessConnectorBasedSystem;
    satisfy ClosedFluidPathRequirement by NeedlelessConnector;
    satisfy SealAfterDisconnectionRequirement by NeedlelessConnector;
    satisfy WorkingPressureRequirement by NeedlelessConnector;
    satisfy FlowCapabilityRequirement by NeedlelessConnector;
    satisfy ContaminationBarrierRequirement by NeedlelessConnector;
}