package FlowControlValveSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Pressure {
        :> scalar;
        unit = "Pa";
    }

    attribute def FlowRate {
        :> scalar;
        unit = "m^3/s";
    }

    attribute def Temperature {
        :> scalar;
        unit = "K";
    }

    attribute def PositionPercent {
        :> scalar;
        unit = "%";
    }

    attribute def TimeDuration {
        :> scalar;
        unit = "s";
    }

    attribute def Voltage {
        :> scalar;
        unit = "V";
    }

    attribute def Current {
        :> scalar;
        unit = "A";
    }

    attribute def Force {
        :> scalar;
        unit = "N";
    }

    item def ProcessFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute volumetricFlow : FlowRate;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
    }

    item def ValveCommand {
        attribute requestedPosition : PositionPercent;
        attribute requestedFlow : FlowRate;
    }

    item def ValveStatus {
        attribute measuredPosition : PositionPercent;
        attribute measuredFlow : FlowRate;
        attribute inletPressure : Pressure;
        attribute outletPressure : Pressure;
        attribute faultActive : Boolean;
    }

    item def DiagnosticMessage {
        attribute faultCode : Integer;
        attribute severity : Integer;
        attribute messageValid : Boolean;
    }

    port def FluidPort {
        inout fluid : ProcessFluid;
    }

    port def PowerPort {
        in power : ElectricalPower;
    }

    port def CommandPort {
        in command : ValveCommand;
    }

    port def StatusPort {
        out status : ValveStatus;
        out diagnostic : DiagnosticMessage;
    }

    part def ValveBody {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute ratedPressure : Pressure = 1600000 [Pa];
        attribute nominalDiameter : LengthValue = 0.05 [m];
        attribute maximumTemperature : Temperature = 423.15 [K];

        perform action ContainPressure {
            in inletFluid : ProcessFluid;
            out outletFluid : ProcessFluid;
        }
    }

    part def ValveTrim {
        port upstream : FluidPort;
        port downstream : FluidPort;

        attribute flowCoefficient : Real = 12.5;
        attribute leakageClass : Integer = 4;
        attribute minimumControllableFlow : FlowRate = 0.0002 [m^3/s];

        perform action MeterFluid {
            in opening : PositionPercent;
            in upstreamFluid : ProcessFluid;
            out downstreamFluid : ProcessFluid;
        }
    }

    part def Actuator {
        port powerInput : PowerPort;
        port commandInput : CommandPort;

        attribute strokeTime : TimeDuration = 2.0 [s];
        attribute maximumActuationForce : Force = 1200 [N];
        attribute failSafePosition : PositionPercent = 0 [%];

        perform action MoveStem {
            in targetPosition : PositionPercent;
            out actualPosition : PositionPercent;
        }
    }

    part def PositionSensor {
        attribute sensingRangeMinimum : PositionPercent = 0 [%];
        attribute sensingRangeMaximum : PositionPercent = 100 [%];
        attribute accuracy : PositionPercent = 0.5 [%];

        perform action MeasurePosition {
            in actualPosition : PositionPercent;
            out measuredPosition : PositionPercent;
        }
    }

    part def FlowSensor {
        port measuredLine : FluidPort;

        attribute measurementRangeMinimum : FlowRate = 0 [m^3/s];
        attribute measurementRangeMaximum : FlowRate = 0.08 [m^3/s];
        attribute accuracy : FlowRate = 0.0005 [m^3/s];

        perform action MeasureFlow {
            in fluid : ProcessFluid;
            out measuredFlow : FlowRate;
        }
    }

    part def PressureSensor {
        port sensedLine : FluidPort;

        attribute measurementRangeMinimum : Pressure = 0 [Pa];
        attribute measurementRangeMaximum : Pressure = 2000000 [Pa];
        attribute accuracy : Pressure = 2500 [Pa];

        perform action MeasurePressure {
            in fluid : ProcessFluid;
            out measuredPressure : Pressure;
        }
    }

    part def ValveController {
        port commandInput : CommandPort;
        port statusOutput : StatusPort;

        attribute controlCycle : TimeDuration = 0.05 [s];
        attribute positionTolerance : PositionPercent = 1.0 [%];
        attribute flowTolerance : FlowRate = 0.001 [m^3/s];
        attribute maximumAllowedDifferentialPressure : Pressure = 800000 [Pa];

        perform action ComputeValvePosition {
            in requestedFlow : FlowRate;
            in measuredFlow : FlowRate;
            in measuredPosition : PositionPercent;
            out targetPosition : PositionPercent;
        }

        perform action DetectFaults {
            in inletPressure : Pressure;
            in outletPressure : Pressure;
            in measuredPosition : PositionPercent;
            in requestedPosition : PositionPercent;
            out faultActive : Boolean;
            out faultCode : Integer;
        }
    }

    part def FlowControlValve {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port power : PowerPort;
        port command : CommandPort;
        port status : StatusPort;

        attribute commandedPosition : PositionPercent = 0 [%];
        attribute actualPosition : PositionPercent = 0 [%];
        attribute measuredFlow : FlowRate = 0 [m^3/s];
        attribute inletPressure : Pressure = 101325 [Pa];
        attribute outletPressure : Pressure = 101325 [Pa];
        attribute isFaulted : Boolean = false;

        part body : ValveBody;
        part trim : ValveTrim;
        part actuator : Actuator;
        part positionSensor : PositionSensor;
        part flowSensor : FlowSensor;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part controller : ValveController;

        connect fluidIn to body.inlet;
        connect body.outlet to trim.upstream;
        connect trim.downstream to fluidOut;
        connect power to actuator.powerInput;
        connect command to actuator.commandInput;
        connect command to controller.commandInput;
        connect status to controller.statusOutput;
        connect trim.downstream to flowSensor.measuredLine;
        connect body.inlet to inletPressureSensor.sensedLine;
        connect trim.downstream to outletPressureSensor.sensedLine;

        action RegulateFlow {
            in commandSignal : ValveCommand;
            in supplyPower : ElectricalPower;
            in incomingFluid : ProcessFluid;
            out outgoingFluid : ProcessFluid;
            out reportedStatus : ValveStatus;

            first start;
            then measureCurrentFlow;
            then computePosition;
            then moveActuator;
            then meterFluid;
            then publishStatus;
            then done;

            action start;
            action measureCurrentFlow;
            action computePosition;
            action moveActuator;
            action meterFluid;
            action publishStatus;
            action done;
        }

        state def OperatingStateMachine {
            entry action Initialize {
                commandedPosition = 0 [%];
                actualPosition = 0 [%];
                isFaulted = false;
            }

            state Off;
            state Initializing;
            state Closed;
            state Opening;
            state Modulating;
            state Closing;
            state Fault;
            state FailSafe;

            transition initial then Off;

            transition Off_to_Initializing
                first Off
                accept ElectricalPower
                then Initializing;

            transition Initializing_to_Closed
                first Initializing
                if power.power.supplyVoltage >= 20 [V]
                then Closed;

            transition Closed_to_Opening
                first Closed
                accept ValveCommand
                if command.command.requestedPosition > 0 [%]
                then Opening;

            transition Opening_to_Modulating
                first Opening
                if actualPosition >= commandedPosition - 1 [%]
                then Modulating;

            transition Modulating_to_Opening
                first Modulating
                accept ValveCommand
                if command.command.requestedPosition > actualPosition + 1 [%]
                then Opening;

            transition Modulating_to_Closing
                first Modulating
                accept ValveCommand
                if command.command.requestedPosition < actualPosition - 1 [%]
                then Closing;

            transition Closing_to_Closed
                first Closing
                if actualPosition <= 1 [%]
                then Closed;

            transition Closing_to_Modulating
                first Closing
                if actualPosition <= commandedPosition + 1 [%] and commandedPosition > 1 [%]
                then Modulating;

            transition Any_to_Fault
                first Closed, Opening, Modulating, Closing
                if isFaulted
                then Fault;

            transition Fault_to_FailSafe
                first Fault
                then FailSafe;

            transition FailSafe_to_Closed
                first FailSafe
                if actualPosition <= actuator.failSafePosition + 1 [%] and isFaulted == false
                then Closed;
        }
    }

    part def PipingSegment {
        port upstreamEnd : FluidPort;
        port downstreamEnd : FluidPort;

        attribute internalDiameter : LengthValue = 0.05 [m];
        attribute length : LengthValue = 2.0 [m];
        attribute maximumPressure : Pressure = 1600000 [Pa];
    }

    part def SupervisoryController {
        port valveCommand : CommandPort;
        port valveStatus : StatusPort;

        attribute desiredProcessFlow : FlowRate = 0.025 [m^3/s];
        attribute normalSupplyVoltage : Voltage = 24 [V];

        action IssueFlowCommand {
            out command : ValveCommand;
        }

        action ReceiveValveStatus {
            in status : ValveStatus;
            in diagnostic : DiagnosticMessage;
        }
    }

    part def FlowControlValveAssembly {
        port processInlet : FluidPort;
        port processOutlet : FluidPort;
        port electricalSupply : PowerPort;

        part upstreamPipe : PipingSegment;
        part downstreamPipe : PipingSegment;
        part valve : FlowControlValve;
        part supervisor : SupervisoryController;

        connect processInlet to upstreamPipe.upstreamEnd;
        connect upstreamPipe.downstreamEnd to valve.fluidIn;
        connect valve.fluidOut to downstreamPipe.upstreamEnd;
        connect downstreamPipe.downstreamEnd to processOutlet;
        connect electricalSupply to valve.power;
        connect supervisor.valveCommand to valve.command;
        connect valve.status to supervisor.valveStatus;

        action ControlProcessFlow {
            in incomingFluid : ProcessFluid;
            in powerAvailable : ElectricalPower;
            out conditionedFluid : ProcessFluid;

            first receiveFluid;
            then commandValve;
            then regulateThroughValve;
            then dischargeFluid;
            then complete;

            action receiveFluid;
            action commandValve;
            action regulateThroughValve;
            action dischargeFluid;
            action complete;
        }
    }

    requirement def FlowControlValvePrimaryFunction {
        doc
        /*
         * The flow control valve system shall regulate the volumetric flow rate
         * of a process fluid by positioning a controllable valve trim between
         * the inlet and outlet fluid ports in response to a command signal.
         */
        subject assembly : FlowControlValveAssembly;

        require constraint {
            assembly.valve.measuredFlow >= 0 [m^3/s]
        }
    }

    requirement def FlowRateAccuracyRequirement {
        subject valve : FlowControlValve;

        attribute commandedFlow : FlowRate = 0.025 [m^3/s];

        require constraint {
            abs(valve.measuredFlow - commandedFlow) <= valve.controller.flowTolerance
        }
    }

    requirement def SafePressureRequirement {
        subject valve : FlowControlValve;

        require constraint {
            valve.inletPressure - valve.outletPressure <= valve.controller.maximumAllowedDifferentialPressure
        }
    }

    requirement def FailSafeRequirement {
        subject valve : FlowControlValve;

        require constraint {
            valve.isFaulted implies valve.actualPosition <= valve.actuator.failSafePosition + 1 [%]
        }
    }

    requirement def PositionFeedbackRequirement {
        subject valve : FlowControlValve;

        require constraint {
            valve.positionSensor.accuracy <= 0.5 [%]
        }
    }

    requirement def PowerCompatibilityRequirement {
        subject valve : FlowControlValve;

        require constraint {
            valve.power.power.supplyVoltage >= 20 [V] and valve.power.power.supplyVoltage <= 30 [V]
        }
    }

    satisfy FlowControlValvePrimaryFunction by FlowControlValveAssembly;
    satisfy FlowRateAccuracyRequirement by FlowControlValve;
    satisfy SafePressureRequirement by FlowControlValve;
    satisfy FailSafeRequirement by FlowControlValve;
    satisfy PositionFeedbackRequirement by PositionSensor;
    satisfy PowerCompatibilityRequirement by Actuator;

    part flowControlValveSystem : FlowControlValveAssembly {
        attribute nominalOperatingFlow : FlowRate = 0.025 [m^3/s];
        attribute maximumOperatingFlow : FlowRate = 0.06 [m^3/s];
        attribute nominalInletPressure : Pressure = 500000 [Pa];
        attribute nominalOutletPressure : Pressure = 350000 [Pa];
        attribute supplyVoltage : Voltage = 24 [V];
    }
}