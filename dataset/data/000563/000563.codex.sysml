package CannulaSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MilliliterPerMinute :> Real;
    attribute def MillimeterMercury :> Real;
    attribute def Millimeter :> Real;
    attribute def Milliliter :> Real;
    attribute def Newton :> Real;

    item def SterileFluid {
        attribute fluidName : String;
        attribute volume : Milliliter;
        attribute viscosity : Real;
        attribute sterilityAssuranceLevel : Real;
    }

    item def BiologicalFluid {
        attribute fluidName : String;
        attribute volume : Milliliter;
        attribute contaminationRisk : Real;
    }

    item def PressureSignal {
        attribute pressure : MillimeterMercury;
        attribute sampleTime : Real;
    }

    item def FlowCommand {
        attribute requestedFlowRate : MilliliterPerMinute;
        attribute mode : String;
    }

    item def OcclusionAlert {
        attribute severity : String;
        attribute detectedPressure : MillimeterMercury;
        attribute recommendedAction : String;
    }

    port def FluidPort {
        in item inputFluid : SterileFluid;
        out item outputFluid : SterileFluid;
    }

    port def DrainPort {
        in item drainedFluid : BiologicalFluid;
        out item sampledFluid : BiologicalFluid;
    }

    port def SignalPort {
        in item command : FlowCommand;
        out item pressureStatus : PressureSignal;
        out item alert : OcclusionAlert;
    }

    part def CannulaTip {
        attribute outerDiameter : Millimeter;
        attribute innerDiameter : Millimeter;
        attribute insertionLength : Millimeter;
        attribute tipAngle : Real;
        attribute roundedEdgeRadius : Millimeter;
        port distalOpening : FluidPort;
    }

    part def CannulaShaft {
        attribute shaftLength : Millimeter;
        attribute outerDiameter : Millimeter;
        attribute lumenDiameter : Millimeter;
        attribute flexibilityIndex : Real;
        attribute kinkResistanceForce : Newton;
        part distalTip : CannulaTip;
        port proximalLumen : FluidPort;
        port distalLumen : FluidPort;
    }

    part def HubConnector {
        attribute luerLockCompatible : Boolean;
        attribute primingVolume : Milliliter;
        attribute maximumConnectionPressure : MillimeterMercury;
        port externalInterface : FluidPort;
        port cannulaInterface : FluidPort;
    }

    part def FlowRegulator {
        attribute minimumFlowRate : MilliliterPerMinute;
        attribute maximumFlowRate : MilliliterPerMinute;
        attribute commandedFlowRate : MilliliterPerMinute;
        attribute regulationAccuracy : Real;
        port inlet : FluidPort;
        port outlet : FluidPort;
        port control : SignalPort;
    }

    part def PressureMonitor {
        attribute lowPressureLimit : MillimeterMercury;
        attribute highPressureLimit : MillimeterMercury;
        attribute occlusionThreshold : MillimeterMercury;
        attribute measuredPressure : MillimeterMercury;
        port measurementPoint : FluidPort;
        port telemetry : SignalPort;
    }

    part def StabilizationFeature {
        attribute adhesiveArea : Real;
        attribute retentionForce : Newton;
        attribute skinContactMaterial : String;
        attribute removableWithoutTool : Boolean;
    }

    part def SterileBarrier {
        attribute packageIntegrity : Boolean;
        attribute sterilizationMethod : String;
        attribute shelfLifeMonths : Integer;
    }

    part def PatientInterface {
        attribute targetAccessSite : String;
        attribute tissueCompatibilityRating : Real;
        port accessOpening : FluidPort;
        port drainageOpening : DrainPort;
    }

    action def PrimeCannula {
        in item primingFluid : SterileFluid;
        inout part cannula : CannulaAssembly;
        out item displacedAirVolume : Milliliter;
        objective {
            doc /* Fill the cannula lumen with sterile fluid before use and reduce trapped air. */
        }
    }

    action def InsertCannula {
        inout part cannula : CannulaAssembly;
        inout part patientInterface : PatientInterface;
        out success : Boolean;
        objective {
            doc /* Position the distal cannula tip at the intended access site while maintaining lumen patency. */
        }
    }

    action def DeliverControlledFluid {
        in item command : FlowCommand;
        in item sourceFluid : SterileFluid;
        inout part cannula : CannulaAssembly;
        out item deliveredFluid : SterileFluid;
        objective {
            doc /* Transfer sterile fluid through the cannula lumen at a controlled rate. */
        }
    }

    action def MonitorPatency {
        inout part cannula : CannulaAssembly;
        out item pressure : PressureSignal;
        out item occlusionAlert : OcclusionAlert;
        objective {
            doc /* Detect abnormal pressure conditions that indicate restriction, disconnection, or occlusion. */
        }
    }

    action def RemoveCannula {
        inout part cannula : CannulaAssembly;
        out removedIntact : Boolean;
        objective {
            doc /* Withdraw the cannula from the access site while preserving device integrity. */
        }
    }

    state def CannulaUseStateMachine {
        entry action InitializeDevice;

        state Packaged;
        state Inspected;
        state Primed;
        state Inserted;
        state DeliveringFluid;
        state Monitoring;
        state Occluded;
        state Removed;
        state Disposed;

        transition first Packaged;
        transition Packaged_to_Inspected
            first Packaged then Inspected
            accept InspectPackage;

        transition Inspected_to_Primed
            first Inspected then Primed
            accept PrimeRequested
            effect PrimeCannula;

        transition Primed_to_Inserted
            first Primed then Inserted
            accept InsertRequested
            effect InsertCannula;

        transition Inserted_to_DeliveringFluid
            first Inserted then DeliveringFluid
            accept StartFlow
            effect DeliverControlledFluid;

        transition DeliveringFluid_to_Monitoring
            first DeliveringFluid then Monitoring
            accept SamplePressure
            effect MonitorPatency;

        transition Monitoring_to_DeliveringFluid
            first Monitoring then DeliveringFluid
            accept PressureNormal;

        transition Monitoring_to_Occluded
            first Monitoring then Occluded
            accept PressureHigh;

        transition Occluded_to_Monitoring
            first Occluded then Monitoring
            accept OcclusionCleared
            effect MonitorPatency;

        transition DeliveringFluid_to_Removed
            first DeliveringFluid then Removed
            accept StopAndRemove
            effect RemoveCannula;

        transition Inserted_to_Removed
            first Inserted then Removed
            accept RemoveWithoutFlow
            effect RemoveCannula;

        transition Removed_to_Disposed
            first Removed then Disposed
            accept DisposeDevice;
    }

    part def CannulaAssembly {
        attribute deviceIdentifier : String;
        attribute singleUse : Boolean = true;
        attribute sterileAtOpening : Boolean = true;
        attribute nominalFlowRate : MilliliterPerMinute;
        attribute maximumSafePressure : MillimeterMercury;
        attribute totalPrimingVolume : Milliliter;

        part hub : HubConnector;
        part shaft : CannulaShaft;
        part regulator : FlowRegulator;
        part pressureMonitor : PressureMonitor;
        part stabilizer : StabilizationFeature;
        part sterileBarrier : SterileBarrier;

        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port controlInterface : SignalPort;

        connection inletToRegulator
            connect fluidInlet to regulator.inlet;

        connection regulatorToHub
            connect regulator.outlet to hub.externalInterface;

        connection hubToShaft
            connect hub.cannulaInterface to shaft.proximalLumen;

        connection shaftToDistalTip
            connect shaft.distalLumen to shaft.distalTip.distalOpening;

        connection distalTipToOutlet
            connect shaft.distalTip.distalOpening to fluidOutlet;

        connection pressureTap
            connect pressureMonitor.measurementPoint to hub.cannulaInterface;

        connection commandLink
            connect controlInterface to regulator.control;

        connection telemetryLink
            connect controlInterface to pressureMonitor.telemetry;

        perform state CannulaUseStateMachine;
    }

    part def CannulaBasedFluidAccessSystem {
        attribute systemName : String = "Cannula Based Fluid Access System";
        attribute primaryFunction : String =
            "Provide a sterile, controlled conduit between an external fluid source and a target access site for delivery or removal of fluid while preserving patency and monitoring pressure.";

        part cannula : CannulaAssembly {
            attribute nominalFlowRate = 50.0;
            attribute maximumSafePressure = 300.0;
            attribute totalPrimingVolume = 1.2;
        }

        part patientInterface : PatientInterface {
            attribute targetAccessSite = "controlled clinical access site";
            attribute tissueCompatibilityRating = 0.95;
        }

        port sourceConnection : FluidPort;
        port accessConnection : FluidPort;
        port operatorControl : SignalPort;

        connection sourceToCannula
            connect sourceConnection to cannula.fluidInlet;

        connection cannulaToPatient
            connect cannula.fluidOutlet to patientInterface.accessOpening;

        connection userControlToCannula
            connect operatorControl to cannula.controlInterface;
    }

    requirement def HighLevelFunctionRequirement {
        subject system : CannulaBasedFluidAccessSystem;
        doc /* The system shall provide a sterile conduit for controlled fluid transfer between an external source and a target access site. */
    }

    requirement def FlowControlRequirement {
        subject cannula : CannulaAssembly;
        attribute requiredMinimumFlow : MilliliterPerMinute = 1.0;
        attribute requiredMaximumFlow : MilliliterPerMinute = 250.0;
        doc /* The cannula assembly shall support regulated flow across the required operating range. */
    }

    requirement def PatencyMonitoringRequirement {
        subject cannula : CannulaAssembly;
        attribute occlusionPressureLimit : MillimeterMercury = 300.0;
        doc /* The cannula assembly shall monitor pressure and generate an occlusion alert when measured pressure exceeds the occlusion limit. */
    }

    requirement def SterilityRequirement {
        subject cannula : CannulaAssembly;
        doc /* The cannula assembly shall maintain a sterile fluid path from package opening through completion of intended single use. */
    }

    requirement def MechanicalIntegrityRequirement {
        subject cannula : CannulaAssembly;
        attribute minimumKinkResistanceForce : Newton = 2.0;
        doc /* The cannula shaft shall resist kinking sufficiently to preserve lumen patency during normal handling and placement. */
    }

    requirement def SingleUseRequirement {
        subject cannula : CannulaAssembly;
        doc /* The cannula assembly shall be intended for one use cycle and disposal after removal. */
    }

    satisfy HighLevelFunctionRequirement by CannulaBasedFluidAccessSystem;
    satisfy FlowControlRequirement by CannulaAssembly;
    satisfy PatencyMonitoringRequirement by PressureMonitor;
    satisfy SterilityRequirement by SterileBarrier;
    satisfy MechanicalIntegrityRequirement by CannulaShaft;
    satisfy SingleUseRequirement by CannulaAssembly;
}