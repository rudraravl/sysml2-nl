package SyphonSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    value def Volume;
    value def Pressure;
    value def Length;
    value def Area;
    value def FlowRate;
    value def Density;
    value def DynamicViscosity;
    value def Duration;

    item def Liquid {
        attribute density : Density;
        attribute viscosity : DynamicViscosity;
        attribute vaporPressure : Pressure;
        attribute temperature : TemperatureValue;
    }

    item def Air {
        attribute pressure : Pressure;
        attribute density : Density;
    }

    item def LiquidFlow {
        item liquid : Liquid;
        attribute volumetricFlowRate : FlowRate;
        attribute staticPressure : Pressure;
        attribute elevationHead : Length;
        attribute flowDirection : String;
    }

    item def PrimingLiquid {
        item liquid : Liquid;
        attribute fillFraction : Real;
    }

    port def LiquidPort {
        inout flow : LiquidFlow;
    }

    port def VentPort {
        inout air : Air;
    }

    part def Reservoir {
        attribute capacity : Volume;
        attribute containedVolume : Volume;
        attribute freeSurfaceElevation : Length;
        attribute bottomElevation : Length;
        attribute ambientPressure : Pressure;
        attribute liquidLevel : Length;
        port outlet : LiquidPort;
        port vent : VentPort;
    }

    part def SourceReservoir :> Reservoir {
        attribute minimumOperatingVolume : Volume;
        attribute usableHeadAboveInlet : Length;
    }

    part def DestinationReservoir :> Reservoir {
        attribute maximumAllowedVolume : Volume;
        attribute receivingElevation : Length;
    }

    part def SyphonTube {
        attribute innerDiameter : Length;
        attribute tubeLength : Length;
        attribute crestElevation : Length;
        attribute inletElevation : Length;
        attribute outletElevation : Length;
        attribute wallRoughness : Length;
        attribute crossSectionalArea : Area;
        attribute maximumAllowableVacuum : Pressure;

        port inlet : LiquidPort;
        port crest : LiquidPort;
        port outlet : LiquidPort;
        port primingAccess : LiquidPort;
    }

    part def InletScreen {
        attribute meshOpening : Length;
        attribute effectiveOpenArea : Area;
        attribute cloggingFraction : Real;
        port reservoirSide : LiquidPort;
        port tubeSide : LiquidPort;
    }

    part def OutletNozzle {
        attribute dischargeCoefficient : Real;
        attribute nozzleDiameter : Length;
        port tubeSide : LiquidPort;
        port dischargeSide : LiquidPort;
    }

    part def PrimingValve {
        attribute open : Boolean;
        attribute leakageRateWhenClosed : FlowRate;
        port fillSide : LiquidPort;
        port tubeSide : LiquidPort;
    }

    part def CheckValve {
        attribute crackingPressure : Pressure;
        attribute reverseLeakageRate : FlowRate;
        attribute open : Boolean;
        port upstream : LiquidPort;
        port downstream : LiquidPort;
    }

    part def FlowSensor {
        attribute measuredFlowRate : FlowRate;
        attribute samplePeriod : Duration;
        attribute accuracyFraction : Real;
        port sensedLine : LiquidPort;
    }

    part def PressureSensor {
        attribute measuredPressure : Pressure;
        attribute samplePeriod : Duration;
        attribute accuracy : Pressure;
        port sensedPoint : LiquidPort;
    }

    part def Controller {
        attribute syphonEnabled : Boolean;
        attribute primedConfirmed : Boolean;
        attribute faultDetected : Boolean;
        attribute lowSourceLevel : Boolean;
        attribute excessVacuum : Boolean;
        attribute reverseFlowDetected : Boolean;

        port sourceLevelInput : LiquidPort;
        port flowInput : LiquidPort;
        port crestPressureInput : LiquidPort;
    }

    action def PrimeSyphon {
        in primingVolume : Volume;
        inout tubeFill : PrimingLiquid;
        out primed : Boolean;

        first start;
        then fillTube;
        then purgeAir;
        then verifyContinuousLiquidColumn;
        then done;

        action fillTube;
        action purgeAir;
        action verifyContinuousLiquidColumn;
    }

    action def TransferLiquidBySyphon {
        in sourceHead : Length;
        in destinationHead : Length;
        in liquidDensity : Density;
        in tubeDiameter : Length;
        out deliveredFlow : FlowRate;
        out transferActive : Boolean;

        first establishPressureGradient;
        then sustainLiquidColumn;
        then dischargeToLowerReservoir;
        then done;

        action establishPressureGradient;
        action sustainLiquidColumn;
        action dischargeToLowerReservoir;
    }

    action def StopSyphon {
        in reason : String;
        out stopped : Boolean;

        first admitAirOrCloseValve;
        then breakContinuousLiquidColumn;
        then confirmNoFlow;
        then done;

        action admitAirOrCloseValve;
        action breakContinuousLiquidColumn;
        action confirmNoFlow;
    }

    state def SyphonOperatingState {
        entry action initializeMonitoring;

        state Unprimed;
        state Priming;
        state Ready;
        state Flowing;
        state Interrupted;
        state Fault;

        transition initial then Unprimed;

        transition Unprimed_to_Priming
            first Unprimed
            accept enableCommand
            then Priming;

        transition Priming_to_Ready
            first Priming
            accept primingComplete
            if primedConfirmed
            then Ready;

        transition Ready_to_Flowing
            first Ready
            accept outletOpened
            if sourceLevelAboveOutlet
            then Flowing;

        transition Flowing_to_Interrupted
            first Flowing
            accept lowHeadCondition
            if not sourceLevelAboveOutlet
            then Interrupted;

        transition Flowing_to_Fault
            first Flowing
            accept unsafeCondition
            if excessVacuum or reverseFlowDetected
            then Fault;

        transition Interrupted_to_Unprimed
            first Interrupted
            accept liquidColumnBroken
            then Unprimed;

        transition Fault_to_Unprimed
            first Fault
            accept resetCommand
            then Unprimed;
    }

    part def SyphonBasedTransferSystem {
        attribute primaryFunction : String = "Transfer liquid from an elevated source reservoir to a lower destination reservoir by using a primed continuous liquid column and gravity-induced pressure difference, without requiring continuous pumping power.";
        attribute designFlowRate : FlowRate;
        attribute maximumLiftHeight : Length;
        attribute allowableCrestAbsolutePressure : Pressure;
        attribute minimumSourceOperatingLevel : Length;
        attribute destinationElevationOffset : Length;
        attribute primingRequired : Boolean = true;

        part source : SourceReservoir {
            attribute capacity = 0.250 [m^3];
            attribute containedVolume = 0.180 [m^3];
            attribute freeSurfaceElevation = 1.800 [m];
            attribute bottomElevation = 0.000 [m];
            attribute ambientPressure = 101325 [Pa];
            attribute liquidLevel = 1.250 [m];
            attribute minimumOperatingVolume = 0.020 [m^3];
            attribute usableHeadAboveInlet = 1.000 [m];
        }

        part destination : DestinationReservoir {
            attribute capacity = 0.300 [m^3];
            attribute containedVolume = 0.060 [m^3];
            attribute freeSurfaceElevation = 0.350 [m];
            attribute bottomElevation = -0.400 [m];
            attribute ambientPressure = 101325 [Pa];
            attribute liquidLevel = 0.750 [m];
            attribute maximumAllowedVolume = 0.280 [m^3];
            attribute receivingElevation = -0.250 [m];
        }

        part tube : SyphonTube {
            attribute innerDiameter = 0.025 [m];
            attribute tubeLength = 3.600 [m];
            attribute crestElevation = 2.150 [m];
            attribute inletElevation = 0.800 [m];
            attribute outletElevation = -0.200 [m];
            attribute wallRoughness = 0.0000015 [m];
            attribute crossSectionalArea = 0.000491 [m^2];
            attribute maximumAllowableVacuum = 30000 [Pa];
        }

        part inletScreen : InletScreen {
            attribute meshOpening = 0.003 [m];
            attribute effectiveOpenArea = 0.0012 [m^2];
            attribute cloggingFraction = 0.050;
        }

        part outletNozzle : OutletNozzle {
            attribute dischargeCoefficient = 0.820;
            attribute nozzleDiameter = 0.020 [m];
        }

        part primingValve : PrimingValve {
            attribute open = false;
            attribute leakageRateWhenClosed = 0.0000001 [m^3/s];
        }

        part antiReverseCheckValve : CheckValve {
            attribute crackingPressure = 120 [Pa];
            attribute reverseLeakageRate = 0.0000002 [m^3/s];
            attribute open = true;
        }

        part flowSensor : FlowSensor {
            attribute measuredFlowRate = 0.00045 [m^3/s];
            attribute samplePeriod = 0.500 [s];
            attribute accuracyFraction = 0.030;
        }

        part crestPressureSensor : PressureSensor {
            attribute measuredPressure = 83000 [Pa];
            attribute samplePeriod = 0.250 [s];
            attribute accuracy = 250 [Pa];
        }

        part controller : Controller {
            attribute syphonEnabled = true;
            attribute primedConfirmed = true;
            attribute faultDetected = false;
            attribute lowSourceLevel = false;
            attribute excessVacuum = false;
            attribute reverseFlowDetected = false;
        }

        port sourceLiquidAccess : LiquidPort;
        port destinationLiquidAccess : LiquidPort;
        port primingAccess : LiquidPort;
        port atmosphericVent : VentPort;

        connection source.outlet to inletScreen.reservoirSide;
        connection inletScreen.tubeSide to antiReverseCheckValve.upstream;
        connection antiReverseCheckValve.downstream to tube.inlet;
        connection tube.outlet to outletNozzle.tubeSide;
        connection outletNozzle.dischargeSide to destination.outlet;
        connection primingValve.tubeSide to tube.primingAccess;
        connection primingValve.fillSide to primingAccess;
        connection tube.crest to crestPressureSensor.sensedPoint;
        connection tube.outlet to flowSensor.sensedLine;
        connection source.outlet to controller.sourceLevelInput;
        connection flowSensor.sensedLine to controller.flowInput;
        connection crestPressureSensor.sensedPoint to controller.crestPressureInput;
        connection source.vent to atmosphericVent;
        connection destination.vent to atmosphericVent;
        connection sourceLiquidAccess to source.outlet;
        connection destinationLiquidAccess to destination.outlet;

        perform action prime : PrimeSyphon {
            in primingVolume = 0.0020 [m^3];
            out primed = controller.primedConfirmed;
        }

        perform action transfer : TransferLiquidBySyphon {
            in sourceHead = 1.450 [m];
            in destinationHead = 0.150 [m];
            in liquidDensity = 998 [kg/m^3];
            in tubeDiameter = tube.innerDiameter;
            out deliveredFlow = designFlowRate;
            out transferActive = controller.syphonEnabled;
        }

        perform action stop : StopSyphon {
            in reason = "source level below minimum, destination full, air ingestion, reverse flow, or excessive crest vacuum";
            out stopped = not controller.syphonEnabled;
        }

        exhibit state operatingState : SyphonOperatingState;
    }

    requirement def HighLevelFunctionRequirement {
        subject system : SyphonBasedTransferSystem;

        require constraint {
            system.primaryFunction == "Transfer liquid from an elevated source reservoir to a lower destination reservoir by using a primed continuous liquid column and gravity-induced pressure difference, without requiring continuous pumping power."
        }

        doc /* The syphon-based transfer system shall provide passive liquid transfer from a higher reservoir to a lower reservoir after priming. */
    }

    requirement def ElevationRequirement {
        subject system : SyphonBasedTransferSystem;

        require constraint {
            system.source.freeSurfaceElevation > system.destination.receivingElevation
        }

        doc /* The source liquid free surface shall be higher than the destination receiving elevation during normal transfer. */
    }

    requirement def ContinuousLiquidColumnRequirement {
        subject system : SyphonBasedTransferSystem;

        require constraint {
            system.primingRequired == true and system.controller.primedConfirmed == true
        }

        doc /* The syphon tube shall be primed so that a continuous liquid column exists from source inlet through tube crest to outlet before sustained flow is credited. */
    }

    requirement def CrestPressureRequirement {
        subject system : SyphonBasedTransferSystem;

        require constraint {
            system.crestPressureSensor.measuredPressure > system.tube.maximumAllowableVacuum
        }

        doc /* The absolute pressure at the syphon crest shall remain above the allowable vacuum limit to prevent vapor formation and loss of prime. */
    }

    requirement def FlowDirectionRequirement {
        subject system : SyphonBasedTransferSystem;

        require constraint {
            system.antiReverseCheckValve.open == true and system.controller.reverseFlowDetected == false
        }

        doc /* The system shall permit normal flow from source to destination and inhibit reverse flow from destination to source. */
    }

    requirement def DestinationCapacityRequirement {
        subject system : SyphonBasedTransferSystem;

        require constraint {
            system.destination.containedVolume < system.destination.maximumAllowedVolume
        }

        doc /* The system shall stop or interrupt transfer before the destination reservoir exceeds its maximum allowed volume. */
    }

    requirement def SourceProtectionRequirement {
        subject system : SyphonBasedTransferSystem;

        require constraint {
            system.source.containedVolume >= system.source.minimumOperatingVolume
        }

        doc /* The source reservoir shall retain at least its minimum operating volume to avoid air ingestion and unintended draining. */
    }

    requirement def MonitoringRequirement {
        subject system : SyphonBasedTransferSystem;

        require constraint {
            system.flowSensor.samplePeriod <= 1.000 [s] and system.crestPressureSensor.samplePeriod <= 1.000 [s]
        }

        doc /* The system shall monitor flow and crest pressure at least once per second while transfer is enabled. */
    }

    part syphonTransferSystem : SyphonBasedTransferSystem {
        attribute designFlowRate = 0.00045 [m^3/s];
        attribute maximumLiftHeight = 1.350 [m];
        attribute allowableCrestAbsolutePressure = 30000 [Pa];
        attribute minimumSourceOperatingLevel = 0.900 [m];
        attribute destinationElevationOffset = -0.250 [m];
    }

    satisfy HighLevelFunctionRequirement by syphonTransferSystem;
    satisfy ElevationRequirement by syphonTransferSystem;
    satisfy ContinuousLiquidColumnRequirement by syphonTransferSystem;
    satisfy CrestPressureRequirement by syphonTransferSystem;
    satisfy FlowDirectionRequirement by syphonTransferSystem;
    satisfy DestinationCapacityRequirement by syphonTransferSystem;
    satisfy SourceProtectionRequirement by syphonTransferSystem;
    satisfy MonitoringRequirement by syphonTransferSystem;
}