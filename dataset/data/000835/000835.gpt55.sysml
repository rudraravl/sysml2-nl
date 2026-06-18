package YSetBasedSystemModel {

    import ScalarValues::*;

    attribute def Length_m :> Real {
        doc /* Linear dimension measured in meters. */
    }

    attribute def Area_m2 :> Real {
        doc /* Cross-sectional area measured in square meters. */
    }

    attribute def Volume_m3 :> Real {
        doc /* Volume measured in cubic meters. */
    }

    attribute def FlowRate_m3_per_s :> Real {
        doc /* Volumetric flow rate measured in cubic meters per second. */
    }

    attribute def Pressure_Pa :> Real {
        doc /* Static pressure measured in pascals. */
    }

    attribute def Temperature_K :> Real {
        doc /* Absolute temperature measured in kelvin. */
    }

    attribute def Power_W :> Real {
        doc /* Power measured in watts. */
    }

    attribute def Voltage_V :> Real {
        doc /* Electrical voltage measured in volts. */
    }

    attribute def Current_A :> Real {
        doc /* Electrical current measured in amperes. */
    }

    attribute def Ratio :> Real {
        doc /* Dimensionless ratio. */
    }

    attribute def Percent :> Real {
        doc /* Percentage value from 0 to 100. */
    }

    attribute def Time_s :> Real {
        doc /* Time duration measured in seconds. */
    }

    attribute def Identifier :> String {
        doc /* Human-readable or machine-readable identifier. */
    }

    item def ProcessMedium {
        attribute mediumId : Identifier;
        attribute temperature : Temperature_K;
        attribute pressure : Pressure_Pa;
        attribute volumetricFlowRate : FlowRate_m3_per_s;
        attribute particulateFraction : Ratio;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    item def ControlCommand {
        attribute commandId : Identifier;
        attribute targetBranch : Identifier;
        attribute requestedSplitRatio : Ratio;
        attribute requestedFlowRate : FlowRate_m3_per_s;
        attribute issuedAt : Time_s;
    }

    item def TelemetryFrame {
        attribute frameId : Identifier;
        attribute measuredTotalFlow : FlowRate_m3_per_s;
        attribute measuredBranchAFlow : FlowRate_m3_per_s;
        attribute measuredBranchBFlow : FlowRate_m3_per_s;
        attribute measuredStemFlow : FlowRate_m3_per_s;
        attribute measuredJunctionPressure : Pressure_Pa;
        attribute healthPercent : Percent;
    }

    item def FaultReport {
        attribute faultId : Identifier;
        attribute severity : Percent;
        attribute detectedAt : Time_s;
        attribute affectedElement : Identifier;
    }

    port def MediumInletPort {
        in item incomingMedium : ProcessMedium;
    }

    port def MediumOutletPort {
        out item outgoingMedium : ProcessMedium;
    }

    port def BidirectionalMediumPort {
        in item incomingMedium : ProcessMedium;
        out item outgoingMedium : ProcessMedium;
    }

    port def PowerInputPort {
        in item suppliedPower : ElectricalPower;
    }

    port def CommandInputPort {
        in item receivedCommand : ControlCommand;
    }

    port def TelemetryOutputPort {
        out item transmittedTelemetry : TelemetryFrame;
        out item transmittedFault : FaultReport;
    }

    port def ControlLinkPort {
        out item actuatorCommand : ControlCommand;
        in item actuatorFeedback : TelemetryFrame;
    }

    port def SensorLinkPort {
        out item sensorTelemetry : TelemetryFrame;
        out item sensorFault : FaultReport;
    }

    action def AcceptPrimaryInflow {
        in item rawMedium : ProcessMedium;
        out item acceptedMedium : ProcessMedium;

        doc /* Accepts the single incoming stream at the stem of the Y-set and validates that it is suitable for controlled distribution. */
    }

    action def SplitFlowByYSet {
        in item acceptedMedium : ProcessMedium;
        in attribute branchASplitRatio : Ratio;
        in attribute branchBSplitRatio : Ratio;
        out item branchAOutput : ProcessMedium;
        out item branchBOutput : ProcessMedium;

        doc /* Performs the high-level primary function of the Y-set system: divide one incoming stream into two controlled outgoing streams through a common Y-junction. */
    }

    action def MergeFlowByYSet {
        in item branchAInput : ProcessMedium;
        in item branchBInput : ProcessMedium;
        out item stemOutput : ProcessMedium;

        doc /* Alternative Y-set operation that combines two branch streams into one stem stream when configured for merge mode. */
    }

    action def MeasureYSetState {
        in item stemMedium : ProcessMedium;
        in item branchAMedium : ProcessMedium;
        in item branchBMedium : ProcessMedium;
        out item telemetry : TelemetryFrame;

        doc /* Measures flow, pressure, and health indicators for the Y-set junction and connected branches. */
    }

    action def RegulateBranchValves {
        in item command : ControlCommand;
        in item telemetry : TelemetryFrame;
        out item branchAValveCommand : ControlCommand;
        out item branchBValveCommand : ControlCommand;

        doc /* Computes branch valve commands needed to maintain the requested Y-set split ratio and flow rate. */
    }

    action def DetectYSetFaults {
        in item telemetry : TelemetryFrame;
        out item fault : FaultReport;

        doc /* Detects blocked branch, leakage, pressure imbalance, insufficient inlet flow, and actuator mismatch conditions. */
    }

    state def YSetOperatingStates {
        state Off;
        state Initializing;
        state Standby;
        state Distributing;
        state Merging;
        state Degraded;
        state Faulted;
        state Shutdown;

        transition initial then Off;

        transition PowerApplied
            first Off
            then Initializing;

        transition InitializationComplete
            first Initializing
            then Standby;

        transition StartDistribution
            first Standby
            then Distributing;

        transition StartMerge
            first Standby
            then Merging;

        transition MinorFaultDuringDistribution
            first Distributing
            then Degraded;

        transition MinorFaultDuringMerge
            first Merging
            then Degraded;

        transition RecoverFromDegraded
            first Degraded
            then Standby;

        transition CriticalFaultFromInitializing
            first Initializing
            then Faulted;

        transition CriticalFaultFromStandby
            first Standby
            then Faulted;

        transition CriticalFaultFromDistributing
            first Distributing
            then Faulted;

        transition CriticalFaultFromMerging
            first Merging
            then Faulted;

        transition CommandedShutdownFromStandby
            first Standby
            then Shutdown;

        transition CommandedShutdownFromDegraded
            first Degraded
            then Shutdown;

        transition ResetAfterFault
            first Faulted
            then Initializing;
    }

    part def BranchSegment {
        attribute branchId : Identifier;
        attribute internalLength : Length_m;
        attribute innerArea : Area_m2;
        attribute maximumFlowRate : FlowRate_m3_per_s;
        attribute pressureDropAtRatedFlow : Pressure_Pa;

        port proximalPort : BidirectionalMediumPort;
        port distalPort : BidirectionalMediumPort;

        action conveyMedium {
            in item mediumAtProximalEnd : ProcessMedium;
            out item mediumAtDistalEnd : ProcessMedium;
        }
    }

    part def StemSegment {
        attribute stemId : Identifier;
        attribute internalLength : Length_m;
        attribute innerArea : Area_m2;
        attribute maximumFlowRate : FlowRate_m3_per_s;
        attribute pressureDropAtRatedFlow : Pressure_Pa;

        port externalInlet : MediumInletPort;
        port junctionPort : BidirectionalMediumPort;

        action conveyToJunction {
            in item incomingMedium : ProcessMedium;
            out item deliveredMedium : ProcessMedium;
        }
    }

    part def YJunction {
        attribute junctionId : Identifier;
        attribute includedAngleBetweenBranches : Real;
        attribute junctionInternalVolume : Volume_m3;
        attribute ratedPressure : Pressure_Pa;
        attribute ratedTotalFlow : FlowRate_m3_per_s;
        attribute branchASplitRatio : Ratio;
        attribute branchBSplitRatio : Ratio;

        port stemPort : BidirectionalMediumPort;
        port branchAPort : BidirectionalMediumPort;
        port branchBPort : BidirectionalMediumPort;

        action splitAtJunction : SplitFlowByYSet;
        action mergeAtJunction : MergeFlowByYSet;
    }

    part def FlowSensor {
        attribute sensorId : Identifier;
        attribute measurementRange : FlowRate_m3_per_s;
        attribute accuracyPercent : Percent;
        attribute responseTime : Time_s;

        port mediumProbePort : BidirectionalMediumPort;
        port sensorOutput : SensorLinkPort;

        action sampleFlow {
            in item sampledMedium : ProcessMedium;
            out item telemetry : TelemetryFrame;
        }
    }

    part def PressureSensor {
        attribute sensorId : Identifier;
        attribute measurementRange : Pressure_Pa;
        attribute accuracyPercent : Percent;
        attribute responseTime : Time_s;

        port mediumProbePort : BidirectionalMediumPort;
        port sensorOutput : SensorLinkPort;

        action samplePressure {
            in item sampledMedium : ProcessMedium;
            out item telemetry : TelemetryFrame;
        }
    }

    part def ModulatingValve {
        attribute valveId : Identifier;
        attribute minimumOpenFraction : Ratio;
        attribute maximumOpenFraction : Ratio;
        attribute currentOpenFraction : Ratio;
        attribute failSafeOpenFraction : Ratio;
        attribute responseTime : Time_s;
        attribute ratedFlowRate : FlowRate_m3_per_s;

        port upstreamPort : BidirectionalMediumPort;
        port downstreamPort : BidirectionalMediumPort;
        port controlPort : ControlLinkPort;
        port electricalPort : PowerInputPort;

        action positionValve {
            in item valveCommand : ControlCommand;
            out item valveFeedback : TelemetryFrame;
        }
    }

    part def YSetController {
        attribute controllerId : Identifier;
        attribute targetTotalFlowRate : FlowRate_m3_per_s;
        attribute targetBranchASplitRatio : Ratio;
        attribute targetBranchBSplitRatio : Ratio;
        attribute controlCycleTime : Time_s;
        attribute allowableSplitError : Ratio;
        attribute allowablePressureImbalance : Pressure_Pa;

        port commandInput : CommandInputPort;
        port telemetryOutput : TelemetryOutputPort;
        port branchAValveControl : ControlLinkPort;
        port branchBValveControl : ControlLinkPort;
        port stemSensorInput : SensorLinkPort;
        port branchASensorInput : SensorLinkPort;
        port branchBSensorInput : SensorLinkPort;
        port junctionPressureInput : SensorLinkPort;
        port controllerPower : PowerInputPort;

        action regulate : RegulateBranchValves;
        action diagnose : DetectYSetFaults;
        state controllerStates : YSetOperatingStates;
    }

    part def PowerConditioner {
        attribute conditionerId : Identifier;
        attribute nominalInputVoltage : Voltage_V;
        attribute nominalOutputVoltage : Voltage_V;
        attribute maximumOutputPower : Power_W;
        attribute efficiency : Ratio;

        port externalPowerInput : PowerInputPort;
        port controllerPowerOutput : PowerInputPort;
        port branchAValvePowerOutput : PowerInputPort;
        port branchBValvePowerOutput : PowerInputPort;
    }

    part def YSetDistributionSystem {
        doc /* A Y-set based system whose primary high-level function is to accept a single incoming process-medium stream at the stem of a Y-shaped set, route it through a common junction, and deliver two controlled outgoing streams through the two branches according to commanded split ratios. */

        attribute systemId : Identifier = "YSET-DISTRIBUTION-SYSTEM-001";
        attribute designTotalFlowRate : FlowRate_m3_per_s = 0.060;
        attribute nominalBranchASplitRatio : Ratio = 0.500;
        attribute nominalBranchBSplitRatio : Ratio = 0.500;
        attribute maximumOperatingPressure : Pressure_Pa = 500000.0;
        attribute minimumOperatingTemperature : Temperature_K = 273.15;
        attribute maximumOperatingTemperature : Temperature_K = 333.15;
        attribute primaryFunctionDescription : String =
            "Divide one validated inlet flow into two regulated outlet flows using a monitored Y-set junction and independently actuated branch valves.";

        port inlet : MediumInletPort;
        port branchAOutlet : MediumOutletPort;
        port branchBOutlet : MediumOutletPort;
        port externalCommand : CommandInputPort;
        port externalTelemetry : TelemetryOutputPort;
        port externalPower : PowerInputPort;

        part stem : StemSegment {
            attribute stemId = "STEM";
            attribute internalLength = 0.750;
            attribute innerArea = 0.000314;
            attribute maximumFlowRate = 0.080;
            attribute pressureDropAtRatedFlow = 1200.0;
        }

        part junction : YJunction {
            attribute junctionId = "Y-JUNCTION";
            attribute includedAngleBetweenBranches = 60.0;
            attribute junctionInternalVolume = 0.00018;
            attribute ratedPressure = 600000.0;
            attribute ratedTotalFlow = 0.080;
            attribute branchASplitRatio = 0.500;
            attribute branchBSplitRatio = 0.500;
        }

        part branchA : BranchSegment {
            attribute branchId = "BRANCH-A";
            attribute internalLength = 0.900;
            attribute innerArea = 0.000201;
            attribute maximumFlowRate = 0.050;
            attribute pressureDropAtRatedFlow = 1500.0;
        }

        part branchB : BranchSegment {
            attribute branchId = "BRANCH-B";
            attribute internalLength = 0.900;
            attribute innerArea = 0.000201;
            attribute maximumFlowRate = 0.050;
            attribute pressureDropAtRatedFlow = 1500.0;
        }

        part branchAValve : ModulatingValve {
            attribute valveId = "VALVE-A";
            attribute minimumOpenFraction = 0.000;
            attribute maximumOpenFraction = 1.000;
            attribute currentOpenFraction = 0.500;
            attribute failSafeOpenFraction = 0.000;
            attribute responseTime = 0.250;
            attribute ratedFlowRate = 0.050;
        }

        part branchBValve : ModulatingValve {
            attribute valveId = "VALVE-B";
            attribute minimumOpenFraction = 0.000;
            attribute maximumOpenFraction = 1.000;
            attribute currentOpenFraction = 0.500;
            attribute failSafeOpenFraction = 0.000;
            attribute responseTime = 0.250;
            attribute ratedFlowRate = 0.050;
        }

        part stemFlowSensor : FlowSensor {
            attribute sensorId = "FLOW-STEM";
            attribute measurementRange = 0.100;
            attribute accuracyPercent = 1.000;
            attribute responseTime = 0.100;
        }

        part branchAFlowSensor : FlowSensor {
            attribute sensorId = "FLOW-A";
            attribute measurementRange = 0.060;
            attribute accuracyPercent = 1.000;
            attribute responseTime = 0.100;
        }

        part branchBFlowSensor : FlowSensor {
            attribute sensorId = "FLOW-B";
            attribute measurementRange = 0.060;
            attribute accuracyPercent = 1.000;
            attribute responseTime = 0.100;
        }

        part junctionPressureSensor : PressureSensor {
            attribute sensorId = "PRESSURE-JUNCTION";
            attribute measurementRange = 700000.0;
            attribute accuracyPercent = 0.500;
            attribute responseTime = 0.050;
        }

        part controller : YSetController {
            attribute controllerId = "YSET-CONTROLLER";
            attribute targetTotalFlowRate = 0.060;
            attribute targetBranchASplitRatio = 0.500;
            attribute targetBranchBSplitRatio = 0.500;
            attribute controlCycleTime = 0.050;
            attribute allowableSplitError = 0.030;
            attribute allowablePressureImbalance = 15000.0;
        }

        part powerConditioner : PowerConditioner {
            attribute conditionerId = "POWER-CONDITIONER";
            attribute nominalInputVoltage = 24.0;
            attribute nominalOutputVoltage = 12.0;
            attribute maximumOutputPower = 80.0;
            attribute efficiency = 0.920;
        }

        connect inlet to stem.externalInlet;
        connect stem.junctionPort to junction.stemPort;
        connect junction.branchAPort to branchA.proximalPort;
        connect junction.branchBPort to branchB.proximalPort;
        connect branchA.distalPort to branchAValve.upstreamPort;
        connect branchB.distalPort to branchBValve.upstreamPort;
        connect branchAValve.downstreamPort to branchAOutlet;
        connect branchBValve.downstreamPort to branchBOutlet;

        connect stem.junctionPort to stemFlowSensor.mediumProbePort;
        connect branchA.distalPort to branchAFlowSensor.mediumProbePort;
        connect branchB.distalPort to branchBFlowSensor.mediumProbePort;
        connect junction.stemPort to junctionPressureSensor.mediumProbePort;

        connect externalCommand to controller.commandInput;
        connect controller.telemetryOutput to externalTelemetry;

        connect stemFlowSensor.sensorOutput to controller.stemSensorInput;
        connect branchAFlowSensor.sensorOutput to controller.branchASensorInput;
        connect branchBFlowSensor.sensorOutput to controller.branchBSensorInput;
        connect junctionPressureSensor.sensorOutput to controller.junctionPressureInput;

        connect controller.branchAValveControl to branchAValve.controlPort;
        connect controller.branchBValveControl to branchBValve.controlPort;

        connect externalPower to powerConditioner.externalPowerInput;
        connect powerConditioner.controllerPowerOutput to controller.controllerPower;
        connect powerConditioner.branchAValvePowerOutput to branchAValve.electricalPort;
        connect powerConditioner.branchBValvePowerOutput to branchBValve.electricalPort;

        action primaryFunction {
            in item inletMedium : ProcessMedium;
            in item operatorCommand : ControlCommand;
            out item branchARegulatedMedium : ProcessMedium;
            out item branchBRegulatedMedium : ProcessMedium;
            out item systemTelemetry : TelemetryFrame;

            first start;
            then acceptFlow : AcceptPrimaryInflow;
            then splitFlow : SplitFlowByYSet;
            then measureState : MeasureYSetState;
            then regulateValves : RegulateBranchValves;
            then done;

            flow inletMedium to acceptFlow.rawMedium;
            flow acceptFlow.acceptedMedium to splitFlow.acceptedMedium;
            flow operatorCommand to regulateValves.command;
            flow splitFlow.branchAOutput to branchARegulatedMedium;
            flow splitFlow.branchBOutput to branchBRegulatedMedium;
            flow measureState.telemetry to regulateValves.telemetry;
            flow measureState.telemetry to systemTelemetry;
        }

        state systemStates : YSetOperatingStates;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Y-set based system shall perform the high-level primary function of controlled division of one incoming process-medium stream into two outgoing branch streams. */

        subject ysetSystem : YSetDistributionSystem;

        require constraint {
            ysetSystem.nominalBranchASplitRatio + ysetSystem.nominalBranchBSplitRatio == 1.0
        }
    }

    requirement def FlowCapacityRequirement {
        doc /* The Y-set based system shall support the design total inlet flow rate without exceeding rated flow limits of the stem, junction, or branch valves. */

        subject ysetSystem : YSetDistributionSystem;

        require constraint {
            ysetSystem.designTotalFlowRate <= ysetSystem.stem.maximumFlowRate and
            ysetSystem.designTotalFlowRate <= ysetSystem.junction.ratedTotalFlow and
            ysetSystem.designTotalFlowRate * ysetSystem.nominalBranchASplitRatio <= ysetSystem.branchAValve.ratedFlowRate and
            ysetSystem.designTotalFlowRate * ysetSystem.nominalBranchBSplitRatio <= ysetSystem.branchBValve.ratedFlowRate
        }
    }

    requirement def PressureContainmentRequirement {
        doc /* All pressure-containing Y-set elements shall be rated above the maximum operating pressure. */

        subject ysetSystem : YSetDistributionSystem;

        require constraint {
            ysetSystem.maximumOperatingPressure <= ysetSystem.junction.ratedPressure
        }
    }

    requirement def SplitAccuracyRequirement {
        doc /* During distribution mode, the controller shall regulate branch split ratio error to no more than the allowable split error. */

        subject ysetSystem : YSetDistributionSystem;

        require constraint {
            ysetSystem.controller.allowableSplitError <= 0.030
        }
    }

    requirement def TelemetryRequirement {
        doc /* The Y-set based system shall provide telemetry for total flow, branch flows, junction pressure, and health state. */

        subject ysetSystem : YSetDistributionSystem;

        require constraint {
            ysetSystem.controller.controlCycleTime <= 0.100
        }
    }

    requirement def FailSafeRequirement {
        doc /* On critical fault or loss of command authority, branch valves shall move to their fail-safe closed position. */

        subject ysetSystem : YSetDistributionSystem;

        require constraint {
            ysetSystem.branchAValve.failSafeOpenFraction == 0.0 and
            ysetSystem.branchBValve.failSafeOpenFraction == 0.0
        }
    }

    satisfy PrimaryFunctionRequirement by YSetDistributionSystem::primaryFunction;
    satisfy FlowCapacityRequirement by YSetDistributionSystem::stem;
    satisfy FlowCapacityRequirement by YSetDistributionSystem::junction;
    satisfy FlowCapacityRequirement by YSetDistributionSystem::branchAValve;
    satisfy FlowCapacityRequirement by YSetDistributionSystem::branchBValve;
    satisfy PressureContainmentRequirement by YSetDistributionSystem::junction;
    satisfy SplitAccuracyRequirement by YSetDistributionSystem::controller;
    satisfy TelemetryRequirement by YSetDistributionSystem::controller;
    satisfy FailSafeRequirement by YSetDistributionSystem::branchAValve;
    satisfy FailSafeRequirement by YSetDistributionSystem::branchBValve;

    part ySetDistributionSystem : YSetDistributionSystem;

}
