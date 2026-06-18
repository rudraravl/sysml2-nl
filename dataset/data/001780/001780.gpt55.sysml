package FlowControlValveSystemModel {
    import ScalarValues::*;

    attribute def VolumeFlowRate :> Real {
        doc /* Unit: cubic metre per second, m^3/s. */
    }

    attribute def Pressure :> Real {
        doc /* Unit: pascal, Pa. */
    }

    attribute def Temperature :> Real {
        doc /* Unit: kelvin, K. */
    }

    attribute def Density :> Real {
        doc /* Unit: kilogram per cubic metre, kg/m^3. */
    }

    attribute def DynamicViscosity :> Real {
        doc /* Unit: pascal second, Pa*s. */
    }

    attribute def Length :> Real {
        doc /* Unit: metre, m. */
    }

    attribute def Diameter :> Real {
        doc /* Unit: metre, m. */
    }

    attribute def Area :> Real {
        doc /* Unit: square metre, m^2. */
    }

    attribute def TimeDuration :> Real {
        doc /* Unit: second, s. */
    }

    attribute def Voltage :> Real {
        doc /* Unit: volt, V. */
    }

    attribute def Current :> Real {
        doc /* Unit: ampere, A. */
    }

    attribute def Power :> Real {
        doc /* Unit: watt, W. */
    }

    attribute def PercentOpen :> Real {
        doc /* Unit: percent of full valve travel, %. */
    }

    attribute def FlowCoefficient :> Real {
        doc /* Unit: SI flow coefficient approximation, m^3/(s*sqrt(Pa)). */
    }

    attribute def DimensionlessRatio :> Real {
        doc /* Unit: one, dimensionless. */
    }

    enum def ValveCommandMode {
        enum close;
        enum manualPosition;
        enum automaticFlowControl;
        enum failSafe;
    }

    enum def ValveHealthState {
        enum healthy;
        enum degraded;
        enum failedClosed;
        enum failedOpen;
        enum sensorFault;
        enum actuatorFault;
    }

    enum def FluidClass {
        enum waterLikeLiquid;
        enum lightOil;
        enum processGas;
        enum corrosiveLiquid;
    }

    item def ProcessFluid {
        doc /* Fluid whose flow is throttled by the flow control valve. */
        attribute fluidClass : FluidClass = FluidClass::waterLikeLiquid;
        attribute density : Density = 998.0;
        attribute dynamicViscosity : DynamicViscosity = 0.001;
        attribute temperature : Temperature = 293.15;
        attribute vaporPressure : Pressure = 2339.0;
    }

    item def ValveCommand {
        attribute commandMode : ValveCommandMode = ValveCommandMode::automaticFlowControl;
        attribute targetFlowRate : VolumeFlowRate = 0.010;
        attribute requestedOpening : PercentOpen = 50.0;
    }

    item def ValveStatus {
        attribute measuredFlowRate : VolumeFlowRate = 0.0;
        attribute measuredInletPressure : Pressure = 0.0;
        attribute measuredOutletPressure : Pressure = 0.0;
        attribute actualOpening : PercentOpen = 0.0;
        attribute health : ValveHealthState = ValveHealthState::healthy;
    }

    item def PositionCommand {
        attribute commandedOpening : PercentOpen = 0.0;
    }

    item def PositionFeedback {
        attribute actualOpening : PercentOpen = 0.0;
        attribute travelValid : Boolean = true;
    }

    item def FlowMeasurement {
        attribute measuredFlowRate : VolumeFlowRate = 0.0;
        attribute measurementValid : Boolean = true;
    }

    item def PressureMeasurement {
        attribute measuredPressure : Pressure = 0.0;
        attribute measurementValid : Boolean = true;
    }

    port def FluidPort {
        inout item fluid : ProcessFluid;
        attribute pressure : Pressure = 101325.0;
        attribute flowRate : VolumeFlowRate = 0.0;
    }

    port def CommandPort {
        in item command : ValveCommand;
        out item status : ValveStatus;
    }

    port def PositionControlPort {
        in item positionCommand : PositionCommand;
        out item positionFeedback : PositionFeedback;
    }

    port def FlowSignalPort {
        out item flowMeasurement : FlowMeasurement;
    }

    port def PressureSignalPort {
        out item pressureMeasurement : PressureMeasurement;
    }

    port def ElectricalPowerPort {
        in attribute supplyVoltage : Voltage = 24.0;
        in attribute supplyCurrent : Current = 0.0;
        attribute availablePower : Power = 0.0;
    }

    constraint def FlowAccuracyConstraint {
        in targetFlowRate : VolumeFlowRate;
        in deliveredFlowRate : VolumeFlowRate;
        in tolerance : VolumeFlowRate;
        constraint accuracy {
            abs(deliveredFlowRate - targetFlowRate) <= tolerance
        }
    }

    constraint def PressureContainmentConstraint {
        in operatingPressure : Pressure;
        in ratedPressure : Pressure;
        constraint containment {
            operatingPressure <= ratedPressure
        }
    }

    constraint def ValveTravelLimitConstraint {
        in actualOpening : PercentOpen;
        constraint travelRange {
            actualOpening >= 0.0 and actualOpening <= 100.0
        }
    }

    constraint def FlowCapacityConstraint {
        in requestedFlowRate : VolumeFlowRate;
        in maximumFlowRate : VolumeFlowRate;
        constraint capacity {
            requestedFlowRate <= maximumFlowRate
        }
    }

    action def RegulateFlowToSetpoint {
        doc /* High-level primary function: compare requested flow to measured flow and position the throttling element so that downstream process flow is held near the commanded setpoint. */
        in item command : ValveCommand;
        in item measuredFlow : FlowMeasurement;
        in item measuredInletPressure : PressureMeasurement;
        in item measuredOutletPressure : PressureMeasurement;
        in actualOpening : PercentOpen;
        out item positionCommand : PositionCommand;
        out item status : ValveStatus;

        attribute flowError : VolumeFlowRate;
        attribute controlDeadband : VolumeFlowRate = 0.00010;
        attribute nominalStep : PercentOpen = 1.0;

        action readSetpoint;
        action compareFlow;
        action computeOpeningCorrection;
        action issuePositionCommand;
        action publishStatus;

        first readSetpoint then compareFlow;
        then computeOpeningCorrection;
        then issuePositionCommand;
        then publishStatus;
    }

    action def MoveValveTrim {
        doc /* Converts an electrical position command into mechanical travel of stem, plug, and trim. */
        in item positionCommand : PositionCommand;
        in supplyVoltage : Voltage;
        out item positionFeedback : PositionFeedback;

        attribute travelTime : TimeDuration = 2.0;
        attribute achievedOpening : PercentOpen;

        action energizeActuator;
        action translateStem;
        action verifyPosition;

        first energizeActuator then translateStem;
        then verifyPosition;
    }

    action def MeasureFlow {
        doc /* Measures volumetric flow through the valve assembly and emits a validated flow measurement. */
        in item processFluid : ProcessFluid;
        in inletPressure : Pressure;
        in outletPressure : Pressure;
        out item flowMeasurement : FlowMeasurement;

        attribute samplePeriod : TimeDuration = 0.10;

        action senseDifferential;
        action compensateDensity;
        action filterSignal;
        action transmitMeasurement;

        first senseDifferential then compensateDensity;
        then filterSignal;
        then transmitMeasurement;
    }

    action def FailClosed {
        doc /* Drives valve to closed position when power, command, or safety interlock is lost. */
        out item positionCommand : PositionCommand;

        action detectFault;
        action commandClosed;
        action latchSafeState;

        first detectFault then commandClosed;
        then latchSafeState;
    }

    state def ValveOperationalStates {
        doc /* Discrete operating states of the flow control valve system. */

        state unpowered;
        state initializing;
        state closed;
        state manualPositioning;
        state automaticRegulating;
        state failSafeClosing;
        state faulted;

        transition initialToUnpowered first start then unpowered;

        transition powerUp first unpowered then initializing;
        transition initialized first initializing then closed;

        transition closeCommand first manualPositioning then closed;
        transition closeCommandFromAuto first automaticRegulating then closed;

        transition manualCommand first closed then manualPositioning;
        transition manualToAutomatic first manualPositioning then automaticRegulating;

        transition automaticCommand first closed then automaticRegulating;

        transition faultFromInitializing first initializing then faulted;
        transition faultFromManual first manualPositioning then faulted;
        transition faultFromAutomatic first automaticRegulating then faulted;

        transition failSafeFromClosed first closed then failSafeClosing;
        transition failSafeFromManual first manualPositioning then failSafeClosing;
        transition failSafeFromAutomatic first automaticRegulating then failSafeClosing;

        transition safePositionReached first failSafeClosing then closed;
        transition resetFault first faulted then initializing;
    }

    part def ValveBody {
        doc /* Pressure-retaining housing for the flow control valve. */
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute nominalDiameter : Diameter = 0.050;
        attribute internalFlowArea : Area = 0.00196;
        attribute ratedPressure : Pressure = 1600000.0;
        attribute maximumFluidTemperature : Temperature = 423.15;
        attribute corrosionAllowance : Length = 0.0015;
    }

    part def ValveTrim {
        doc /* Internal throttling geometry that creates controlled pressure drop. */
        attribute seatDiameter : Diameter = 0.035;
        attribute plugTravel : Length = 0.020;
        attribute ratedFlowCoefficient : FlowCoefficient = 0.000010;
        attribute rangeability : DimensionlessRatio = 50.0;
        attribute leakageAtClosed : VolumeFlowRate = 0.000001;
    }

    part def ValveStem {
        attribute stemDiameter : Diameter = 0.010;
        attribute maximumTravel : Length = 0.020;
        attribute currentTravel : Length = 0.0;
    }

    part def FlowControlValve {
        doc /* Core valve assembly that throttles process fluid by varying the opening between plug and seat. */

        port inlet : FluidPort;
        port outlet : FluidPort;
        port positionControl : PositionControlPort;

        part body : ValveBody;
        part trim : ValveTrim;
        part stem : ValveStem;

        attribute commandedOpening : PercentOpen = 0.0;
        attribute actualOpening : PercentOpen = 0.0;
        attribute maximumWorkingPressure : Pressure = 1600000.0;
        attribute normalPressureDrop : Pressure = 150000.0;
        attribute maximumFlowRate : VolumeFlowRate = 0.015;
        attribute minimumControllableFlowRate : VolumeFlowRate = 0.0003;
        attribute failPosition : PercentOpen = 0.0;

        constraint travelLimit : ValveTravelLimitConstraint {
            in actualOpening = actualOpening;
        }

        constraint pressureRating : PressureContainmentConstraint {
            in operatingPressure = inlet.pressure;
            in ratedPressure = maximumWorkingPressure;
        }

        connection internalInlet connect inlet to body.inlet;
        connection internalOutlet connect body.outlet to outlet;

        perform action moveTrim : MoveValveTrim;
    }

    part def ElectromechanicalActuator {
        doc /* Powered actuator that positions the valve stem according to controller commands. */
        port powerInput : ElectricalPowerPort;
        port positionControl : PositionControlPort;

        attribute nominalVoltage : Voltage = 24.0;
        attribute peakCurrent : Current = 2.0;
        attribute holdingCurrent : Current = 0.25;
        attribute fullStrokeTime : TimeDuration = 2.5;
        attribute positioningResolution : PercentOpen = 0.25;
        attribute springReturnPosition : PercentOpen = 0.0;

        perform action positionValve : MoveValveTrim;
    }

    part def FlowSensor {
        doc /* Inline sensor used by the controller to determine actual process flow rate. */
        port inlet : FluidPort;
        port outlet : FluidPort;
        port signalOut : FlowSignalPort;
        port powerInput : ElectricalPowerPort;

        attribute measurementRangeLow : VolumeFlowRate = 0.0;
        attribute measurementRangeHigh : VolumeFlowRate = 0.020;
        attribute accuracyBand : VolumeFlowRate = 0.00010;
        attribute responseTime : TimeDuration = 0.25;
        attribute samplePeriod : TimeDuration = 0.10;

        connection sensedFluidPath connect inlet to outlet;

        perform action measureFlow : MeasureFlow;
    }

    part def PressureSensor {
        port processConnection : FluidPort;
        port signalOut : PressureSignalPort;
        port powerInput : ElectricalPowerPort;

        attribute measurementRangeLow : Pressure = 0.0;
        attribute measurementRangeHigh : Pressure = 2000000.0;
        attribute accuracyBand : Pressure = 5000.0;
        attribute responseTime : TimeDuration = 0.10;
    }

    part def ValveController {
        doc /* Digital controller that implements closed-loop flow regulation. */
        port commandInterface : CommandPort;
        port flowInput : FlowSignalPort;
        port inletPressureInput : PressureSignalPort;
        port outletPressureInput : PressureSignalPort;
        port actuatorInterface : PositionControlPort;
        port powerInput : ElectricalPowerPort;

        attribute targetFlowRate : VolumeFlowRate = 0.010;
        attribute flowTolerance : VolumeFlowRate = 0.00025;
        attribute proportionalGain : DimensionlessRatio = 35.0;
        attribute integralGain : DimensionlessRatio = 5.0;
        attribute derivativeGain : DimensionlessRatio = 0.0;
        attribute controlPeriod : TimeDuration = 0.10;
        attribute commandedOpening : PercentOpen = 0.0;
        attribute controllerHealth : ValveHealthState = ValveHealthState::healthy;

        perform action regulate : RegulateFlowToSetpoint;
        perform action failClosed : FailClosed;

        exhibit state operationalStates : ValveOperationalStates;
    }

    part def PipeSegment {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute length : Length = 1.0;
        attribute insideDiameter : Diameter = 0.050;
        attribute roughness : Length = 0.000045;
        attribute pressureLossAtNominalFlow : Pressure = 8000.0;

        connection pipeFlowPath connect inlet to outlet;
    }

    part def PowerSupply {
        port outputPower : ElectricalPowerPort;

        attribute outputVoltage : Voltage = 24.0;
        attribute maximumCurrent : Current = 5.0;
        attribute maximumPower : Power = 120.0;
        attribute holdUpTime : TimeDuration = 0.25;
    }

    part def FlowControlValveAssembly {
        doc /* System based on a flow control valve. Its primary high-level function is to regulate the volumetric flow of process fluid from the inlet to the outlet by measuring actual flow and modulating valve opening to match a commanded setpoint. */

        port inlet : FluidPort;
        port outlet : FluidPort;
        port operatorCommand : CommandPort;
        port electricalSupply : ElectricalPowerPort;

        part upstreamPipe : PipeSegment {
            :>> length = 0.75;
            :>> insideDiameter = 0.050;
            :>> pressureLossAtNominalFlow = 5000.0;
        }

        part inletPressureSensor : PressureSensor {
            :>> measurementRangeHigh = 2000000.0;
        }

        part primaryValve : FlowControlValve {
            :>> maximumWorkingPressure = 1600000.0;
            :>> maximumFlowRate = 0.015;
            :>> minimumControllableFlowRate = 0.0003;
            :>> normalPressureDrop = 150000.0;
        }

        part actuator : ElectromechanicalActuator {
            :>> nominalVoltage = 24.0;
            :>> fullStrokeTime = 2.5;
            :>> springReturnPosition = 0.0;
        }

        part flowSensor : FlowSensor {
            :>> measurementRangeHigh = 0.020;
            :>> accuracyBand = 0.00010;
        }

        part outletPressureSensor : PressureSensor {
            :>> measurementRangeHigh = 2000000.0;
        }

        part downstreamPipe : PipeSegment {
            :>> length = 1.25;
            :>> insideDiameter = 0.050;
            :>> pressureLossAtNominalFlow = 7000.0;
        }

        part controller : ValveController {
            :>> targetFlowRate = 0.010;
            :>> flowTolerance = 0.00025;
            :>> controlPeriod = 0.10;
        }

        part localPowerSupply : PowerSupply {
            :>> outputVoltage = 24.0;
            :>> maximumCurrent = 5.0;
        }

        attribute targetFlowRate : VolumeFlowRate = 0.010;
        attribute deliveredFlowRate : VolumeFlowRate = 0.010;
        attribute allowableFlowError : VolumeFlowRate = 0.00025;
        attribute inletDesignPressure : Pressure = 1200000.0;
        attribute outletDesignPressure : Pressure = 1050000.0;
        attribute nominalPressureDrop : Pressure = 150000.0;
        attribute designMaximumFlowRate : VolumeFlowRate = 0.015;
        attribute designMinimumFlowRate : VolumeFlowRate = 0.0003;
        attribute primaryFunctionAvailable : Boolean = true;

        connection externalInletToPipe connect inlet to upstreamPipe.inlet;
        connection pipeToInletPressureSensor connect upstreamPipe.outlet to inletPressureSensor.processConnection;
        connection pipeToValve connect upstreamPipe.outlet to primaryValve.inlet;
        connection valveToFlowSensor connect primaryValve.outlet to flowSensor.inlet;
        connection flowSensorToOutletPressureSensor connect flowSensor.outlet to outletPressureSensor.processConnection;
        connection flowSensorToDownstreamPipe connect flowSensor.outlet to downstreamPipe.inlet;
        connection downstreamPipeToExternalOutlet connect downstreamPipe.outlet to outlet;

        connection commandToController connect operatorCommand to controller.commandInterface;
        connection flowSignalToController connect flowSensor.signalOut to controller.flowInput;
        connection inletPressureSignalToController connect inletPressureSensor.signalOut to controller.inletPressureInput;
        connection outletPressureSignalToController connect outletPressureSensor.signalOut to controller.outletPressureInput;
        connection controllerToActuator connect controller.actuatorInterface to actuator.positionControl;
        connection actuatorToValve connect actuator.positionControl to primaryValve.positionControl;

        connection externalPowerToSupply connect electricalSupply to localPowerSupply.outputPower;
        connection powerToController connect localPowerSupply.outputPower to controller.powerInput;
        connection powerToActuator connect localPowerSupply.outputPower to actuator.powerInput;
        connection powerToFlowSensor connect localPowerSupply.outputPower to flowSensor.powerInput;
        connection powerToInletPressureSensor connect localPowerSupply.outputPower to inletPressureSensor.powerInput;
        connection powerToOutletPressureSensor connect localPowerSupply.outputPower to outletPressureSensor.powerInput;

        constraint deliveredFlowAccuracy : FlowAccuracyConstraint {
            in targetFlowRate = targetFlowRate;
            in deliveredFlowRate = deliveredFlowRate;
            in tolerance = allowableFlowError;
        }

        constraint requestedFlowCapacity : FlowCapacityConstraint {
            in requestedFlowRate = targetFlowRate;
            in maximumFlowRate = designMaximumFlowRate;
        }

        exhibit state assemblyStates : ValveOperationalStates;

        perform action primaryFunction : RegulateFlowToSetpoint;
    }

    requirement def PrimaryFlowControlFunctionRequirement {
        doc /* The system shall provide the high-level primary function of regulating process-fluid volumetric flow between its inlet and outlet by adjusting a flow control valve opening in response to a commanded flow setpoint and measured actual flow. */
        subject system : FlowControlValveAssembly;

        require constraint primaryFunctionConstraint {
            system.primaryFunctionAvailable == true and
            abs(system.deliveredFlowRate - system.targetFlowRate) <= system.allowableFlowError
        }
    }

    requirement def FlowRangeRequirement {
        doc /* The system shall control flow over the specified operating range. */
        subject system : FlowControlValveAssembly;

        require constraint flowRangeConstraint {
            system.designMinimumFlowRate <= system.targetFlowRate and
            system.targetFlowRate <= system.designMaximumFlowRate
        }
    }

    requirement def PressureContainmentRequirement {
        doc /* Pressure-retaining components shall be rated above the maximum design inlet pressure. */
        subject system : FlowControlValveAssembly;

        require constraint pressureConstraint {
            system.inletDesignPressure <= system.primaryValve.maximumWorkingPressure
        }
    }

    requirement def FailClosedRequirement {
        doc /* On loss of command or electrical power, the valve shall move to the closed fail-safe position. */
        subject system : FlowControlValveAssembly;

        require constraint failClosedConstraint {
            system.primaryValve.failPosition == 0.0
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The actuator shall be able to drive the valve through full travel within the allowed response time. */
        subject system : FlowControlValveAssembly;

        require constraint responseConstraint {
            system.actuator.fullStrokeTime <= 3.0
        }
    }

    requirement def LeakageRequirement {
        doc /* The valve trim shall limit closed-seat leakage to a small fraction of maximum controlled flow. */
        subject system : FlowControlValveAssembly;

        require constraint leakageConstraint {
            system.primaryValve.trim.leakageAtClosed <= 0.000001
        }
    }

    part valveControlAssembly : FlowControlValveAssembly {
        :>> targetFlowRate = 0.010;
        :>> deliveredFlowRate = 0.010;
        :>> allowableFlowError = 0.00025;
        :>> inletDesignPressure = 1200000.0;
        :>> outletDesignPressure = 1050000.0;
        :>> nominalPressureDrop = 150000.0;
    }

    requirement primaryFunctionRequirement : PrimaryFlowControlFunctionRequirement {
        subject system = valveControlAssembly;
    }

    requirement flowRangeRequirement : FlowRangeRequirement {
        subject system = valveControlAssembly;
    }

    requirement pressureContainmentRequirement : PressureContainmentRequirement {
        subject system = valveControlAssembly;
    }

    requirement failClosedRequirement : FailClosedRequirement {
        subject system = valveControlAssembly;
    }

    requirement responseTimeRequirement : ResponseTimeRequirement {
        subject system = valveControlAssembly;
    }

    requirement leakageRequirement : LeakageRequirement {
        subject system = valveControlAssembly;
    }

    satisfy primaryFunctionRequirement by valveControlAssembly;
    satisfy flowRangeRequirement by valveControlAssembly;
    satisfy pressureContainmentRequirement by valveControlAssembly.primaryValve;
    satisfy failClosedRequirement by valveControlAssembly.primaryValve;
    satisfy responseTimeRequirement by valveControlAssembly.actuator;
    satisfy leakageRequirement by valveControlAssembly.primaryValve.trim;
}
