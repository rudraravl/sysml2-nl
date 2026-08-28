package PulseDuplicator {
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    value def HeartRateValue :> Real { unit 'bpm'; }
    value def DurationValue :> Real { unit 's'; }
    value def PressureValue :> Real { unit 'kPa'; }
    value def FlowRateValue :> Real { unit 'L/min'; }
    value def VolumeValue :> Real { unit 'L'; }
    value def ResistanceValue :> Real { unit 'kPa*s/L'; }
    value def ComplianceValue :> Real { unit 'L/kPa'; }
    value def FrequencyValue :> Real { unit 'Hz'; }

    // ===== Item Types =====
    item def TestFluid {
        attribute density : Real = 1.06; // g/mL, blood analog
        attribute viscosity : Real = 3.5; // mPa*s
    }

    item def PressureWaveform {
        attribute systolicPhase : PressureValue;
        attribute diastolicPhase : PressureValue;
        attribute period : DurationValue;
    }

    item def ControllerCommand {
        attribute targetHeartRate : HeartRateValue;
        attribute testDuration : DurationValue;
        attribute waveform : PressureWaveform;
    }

    item def SensorReading {
        attribute pressureUpstream : PressureValue;
        attribute pressureDownstream : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute timestamp : DurationValue;
    }

    item def PerformanceReport {
        attribute pressureGradient : PressureValue;
        attribute meanFlowRate : FlowRateValue;
        attribute strokeVolume : VolumeValue;
        attribute testDuration : DurationValue;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        out item fluid : TestFluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def CommandPort {
        out item command : ControllerCommand;
    }

    port def DataPort {
        out item reading : SensorReading;
    }

    // ===== Requirements =====
    requirement def ReplicateHemodynamics {
        doc "The system shall replicate pulsating blood flow and pressure conditions of a human heart in a controlled, repeatable environment."
        attribute heartRateRange : HeartRateValue = 60;
        attribute pressureRange : PressureValue = 16.0;
    }

    requirement def MeasurePressureGradient {
        doc "The system shall measure pressure upstream and downstream of the test valve to calculate the pressure gradient."
        attribute accuracy : PressureValue = 0.1;
    }

    requirement def MeasureFlowRate {
        doc "The system shall measure the volume of fluid passing through the valve over time."
        attribute accuracy : FlowRateValue = 0.05;
    }

    requirement def SimulateAfterload {
        doc "The system shall simulate vascular resistance via a resistance valve at the end of the circuit."
        attribute resistanceRange : ResistanceValue = 0.5;
    }

    requirement def RunForDuration {
        doc "The system shall run continuously for a set test duration collecting pressure and flow data."
        attribute minDuration : DurationValue = 60.0;
    }

    // ===== Part Definitions =====

    part def SystemController {
        port commandOut : CommandPort;
        port dataIn : DataPort;

        attribute desiredHeartRate : HeartRateValue = 70;
        attribute testDuration : DurationValue = 120.0;
        attribute systolicPressure : PressureValue = 16.0;
        attribute diastolicPressure : PressureValue = 10.7;

        attribute collectedReadings : SensorReading[0..*];
        attribute currentReport : PerformanceReport;

        satisfy ReplicateHemodynamics {
            heartRateRange := desiredHeartRate;
            pressureRange := systolicPressure;
        }
        satisfy RunForDuration {
            minDuration := testDuration;
        }

        state def ControllerStates {
            entry; then Idle;
            state Idle;
            transition Idle_to_Configuring
                first Idle
                if (true)
                then Configuring;
            state Configuring {
                entry assign desiredHeartRate = 70;
                then;
            }
            transition Configuring_to_Running
                first Configuring
                if (true)
                then Running;
            state Running {
                entry;
                do send commandOut.command;
                accept dataIn.reading;
                then Running;
            }
            transition Running_to_Complete
                first Running
                if (testDuration <= 0.0)
                then Complete;
            state Complete {
                entry assign currentReport = computeReport();
            }
        }

        action computeReport() : PerformanceReport {
            // Aggregate collected readings into a performance report
        }

        action def send(out item cmd : ControllerCommand) {
            assign cmd.targetHeartRate = desiredHeartRate;
            assign cmd.testDuration = testDuration;
            assign cmd.waveform.systolicPhase = systolicPressure;
            assign cmd.waveform.diastolicPhase = diastolicPressure;
            assign cmd.waveform.period = 60.0 / desiredHeartRate;
        }
    }

    part def PulsatilePump {
        port commandIn : CommandPort;
        port fluidOut : FluidPort;

        attribute currentHeartRate : HeartRateValue;
        attribute strokeVolume : VolumeValue = 0.07;
        attribute generatedFlow : FlowRateValue;

        action def generatePulse() {
            // Generate rhythmic flow mimicking heartbeat
            assign generatedFlow = strokeVolume * (currentHeartRate / 60.0);
            assign fluidOut.flowRate = generatedFlow;
        }

        state def PumpStates {
            entry; then Standby;
            state Standby;
            transition to_Active
                first Standby
                if (commandIn.command.targetHeartRate > 0)
                then Active;
            state Active {
                do generatePulse();
                accept commandIn.command;
                then Active;
            }
        }
    }

    part def ComplianceChamber {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        attribute compliance : ComplianceValue = 1.5;
        attribute internalPressure : PressureValue;

        action def smoothWaveform() {
            // Simulate arterial elasticity to reduce pressure wave sharpness
            assign fluidOut.pressure = internalPressure;
            assign fluidOut.fluid = fluidIn.fluid;
        }
    }

    part def TestValve {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        attribute valveDiameter : Real = 0.023; // m
        attribute isOpen : Boolean = true;

        state def ValveStates {
            entry; then Closed;
            state Closed;
            transition to_Open
                first Closed
                if (fluidIn.pressure > fluidOut.pressure)
                then Open;
            state Open;
            transition to_Closed
                first Open
                if (fluidIn.pressure < fluidOut.pressure)
                then Closed;
        }
    }

    part def PressureSensor {
        port fluidPort : FluidPort;
        port dataOut : DataPort;

        attribute measuredPressure : PressureValue;
        attribute location : String;

        action def measure() {
            assign measuredPressure = fluidPort.pressure;
            assign dataOut.reading.pressureUpstream = measuredPressure;
        }

        satisfy MeasurePressureGradient {
            accuracy := 0.1;
        }
    }

    part def FlowMeter {
        port fluidPort : FluidPort;
        port dataOut : DataPort;

        attribute measuredFlowRate : FlowRateValue;
        attribute cumulativeVolume : VolumeValue = 0.0;

        action def measureFlow() {
            assign measuredFlowRate = fluidPort.flowRate;
            assign dataOut.reading.flowRate = measuredFlowRate;
        }

        satisfy MeasureFlowRate {
            accuracy := 0.05;
        }
    }

    part def ResistanceValve {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        attribute resistance : ResistanceValue = 0.8;
        attribute openingFraction : Real = 0.7;

        action def applyResistance() {
            // Simulate afterload by restricting flow
            assign fluidOut.pressure = fluidIn.pressure - (resistance * fluidIn.flowRate);
            assign fluidOut.flowRate = fluidIn.flowRate * openingFraction;
            assign fluidOut.fluid = fluidIn.fluid;
        }

        satisfy SimulateAfterload {
            resistanceRange := resistance;
        }
    }

    // ===== Top-level System =====
    part def PulseDuplicatorSystem {
        part controller : SystemController {
            attribute desiredHeartRate = 70;
            attribute testDuration = 120.0;
        }
        part pump : PulsatilePump;
        part compliance : ComplianceChamber;
        part testValve : TestValve;
        part upstreamPressureSensor : PressureSensor {
            attribute location = "upstream";
        }
        part downstreamPressureSensor : PressureSensor {
            attribute location = "downstream";
        }
        part flowMeter : FlowMeter;
        part resistanceValve : ResistanceValve;

        // Fluid circuit connections
        connection pumpToCompliance : FluidPort connect pump.fluidOut to compliance.fluidIn;
        connection complianceToTestValve : FluidPort connect compliance.fluidOut to testValve.fluidIn;
        connection testValveToResistance : FluidPort connect testValve.fluidOut to resistanceValve.fluidIn;
        connection resistanceToPump : FluidPort connect resistanceValve.fluidOut to pump.fluidOut;

        // Sensor connections
        connection upstreamSensorTap : FluidPort connect testValve.fluidIn to upstreamPressureSensor.fluidPort;
        connection downstreamSensorTap : FluidPort connect testValve.fluidOut to downstreamPressureSensor.fluidPort;
        connection flowMeterTap : FluidPort connect testValve.fluidOut to flowMeter.fluidPort;

        // Command and data connections
        connection controllerToPump : CommandPort connect controller.commandOut to pump.commandIn;
        connection upstreamToController : DataPort connect upstreamPressureSensor.dataOut to controller.dataIn;
        connection downstreamToController : DataPort connect downstreamPressureSensor.dataOut to controller.dataIn;
        connection flowMeterToController : DataPort connect flowMeter.dataOut to controller.dataIn;

        attribute systemHeartRate : HeartRateValue = controller.desiredHeartRate;
        attribute systemDuration : DurationValue = controller.testDuration;

        satisfy ReplicateHemodynamics;
        satisfy MeasurePressureGradient;
        satisfy MeasureFlowRate;
        satisfy SimulateAfterload;
        satisfy RunForDuration;
    }
}
