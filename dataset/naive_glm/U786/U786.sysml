package NOxSensingUnit {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types ----------
    value type NOxConcentration :> Real {
        :>> unit 'ppm';
    }

    value type TemperatureValue :> Real {
        :>> unit 'degC';
    }

    value type Voltage :> Real {
        :>> unit 'mV';
    }

    value type DigitalCount :> Integer {
        :>> unit 'count';
    }

    value type PowerState :> String;
    value type ErrorCode :> Integer;
    value type Timestamp :> Integer {
        :>> unit 'ms';
    }

    item def RawGas {
        attribute noxConcentration : NOxConcentration;
        attribute flowRate : Real {:>> unit 'L/min';};
    }

    item def ExhaustGas :> RawGas;

    item def RawElectricalSignal {
        attribute amplitude : Voltage;
        attribute noiseLevel : Voltage;
    }

    item def RefinedAnalogSignal {
        attribute amplitude : Voltage;
        attribute snr : Real;
    }

    item def DigitalSample {
        attribute rawValue : DigitalCount;
        attribute timestamp : Timestamp;
    }

    item def NOxDataPacket {
        attribute noxConcentration : NOxConcentration;
        attribute sensorTemperature : TemperatureValue;
        attribute timestamp : Timestamp;
        attribute valid : Boolean;
        attribute errorCode : ErrorCode;
    }

    item def ControlCommand {
        attribute command : String;
    }

    // ---------- Port Definitions ----------
    port def GasInPort {
        in item gas : ExhaustGas;
    }

    port def RawSignalPort {
        out item signal : RawElectricalSignal;
    }

    port def RefinedSignalPort {
        out item signal : RefinedAnalogSignal;
    }

    port def DigitalSamplePort {
        out item sample : DigitalSample;
    }

    port def DataPacketPort {
        out item packet : NOxDataPacket;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def ThermalPort {
        out attribute temperature : TemperatureValue;
    }

    port def PowerPort {
        in attribute voltage : Voltage;
        in attribute current : Real {:>> unit 'A';};
    }

    // ---------- Component Definitions ----------

    part def HeatingElement {
        port powerIn : PowerPort;
        port thermalOut : ThermalPort;

        attribute targetTemperature : TemperatureValue = 300 [degC];
        attribute currentTemperature : TemperatureValue;

        state heatingBehavior {
            entry; then Off;
            state Off;
            state Heating;
            state Stabilized;
            transition off_to_heating
                first Off
                then Heating
                when powerIn.voltage > 0 [mV];
            transition heating_to_stabilized
                first Heating
                then Stabilized
                when currentTemperature >= targetTemperature;
            transition stabilized_to_heating
                first Stabilized
                then Heating
                when currentTemperature < targetTemperature - 5 [degC];
        }

        action def generateHeat {
            in target : TemperatureValue;
            out temp : TemperatureValue;
        }
    }

    part def SensingElement {
        port gasIn : GasInPort;
        port rawSignalOut : RawSignalPort;
        port thermalIn : ThermalPort;

        attribute operatingTemperatureMin : TemperatureValue = 290 [degC];
        attribute operatingTemperatureMax : TemperatureValue = 310 [degC];
        attribute sensitivity : Real = 0.05 {:>> unit 'mV/ppm';};

        action def reactWithNOx {
            in gas : ExhaustGas;
            in temp : TemperatureValue;
            out signal : RawElectricalSignal;
        }

        action def sense {
            in gas : ExhaustGas;
            in temp : TemperatureValue;
            out signal : RawElectricalSignal;
            if temp >= operatingTemperatureMin and temp <= operatingTemperatureMax {
                call reactWithNOx(gas, temp) -> signal;
            } else {
                assign signal.amplitude = 0 [mV];
                assign signal.noiseLevel = 0 [mV];
            }
        }
    }

    part def TemperatureMonitor {
        port thermalIn : ThermalPort;
        port thermalReport : ThermalPort;

        attribute lowerBound : TemperatureValue = 290 [degC];
        attribute upperBound : TemperatureValue = 310 [degC];
        attribute currentReading : TemperatureValue;
        attribute inRange : Boolean;

        action def monitorTemperature {
            in temp : TemperatureValue;
            out reading : TemperatureValue;
            out valid : Boolean;
            assign reading = temp;
            assign valid = (temp >= lowerBound) and (temp <= upperBound);
        }
    }

    part def SignalProcessor {
        port rawSignalIn : RawSignalPort;
        port refinedSignalOut : RefinedSignalPort;

        attribute gain : Real = 100;
        attribute cutoffFrequency : Real = 1000 {:>> unit 'Hz';};

        action def amplify {
            in signal : RawElectricalSignal;
            out amplified : RawElectricalSignal;
            assign amplified.amplitude = signal.amplitude * gain;
            assign amplified.noiseLevel = signal.noiseLevel;
        }

        action def filter {
            in signal : RawElectricalSignal;
            out filtered : RefinedAnalogSignal;
            assign filtered.amplitude = signal.amplitude;
            assign filtered.snr = signal.amplitude / (signal.noiseLevel + 0.001 [mV]);
        }

        action def process {
            in raw : RawElectricalSignal;
            out refined : RefinedAnalogSignal;
            var amplified : RawElectricalSignal;
            call amplify(raw) -> amplified;
            call filter(amplified) -> refined;
        }
    }

    part def AnalogToDigitalConverter {
        port analogIn : RefinedSignalPort;
        port digitalOut : DigitalSamplePort;

        attribute resolution : Integer = 16;
        attribute referenceVoltage : Voltage = 3300 [mV];
        attribute samplingRate : Real = 100 {:>> unit 'Hz';};

        action def convert {
            in analog : RefinedAnalogSignal;
            out digital : DigitalSample;
            assign digital.rawValue = (analog.amplitude / referenceVoltage) * (2^resolution - 1);
            assign digital.timestamp = 0 [ms];
        }
    }

    part def ProcessingUnit {
        port digitalIn : DigitalSamplePort;
        port thermalIn : ThermalPort;
        port commandIn : CommandPort;
        port dataOut : DataPacketPort;

        attribute calibrationOffset : NOxConcentration = 0 [ppm];
        attribute calibrationScale : Real = 1.0;
        attribute lastErrorCode : ErrorCode = 0;
        attribute measurementActive : Boolean = false;

        action def calculateConcentration {
            in sample : DigitalSample;
            in temp : TemperatureValue;
            out packet : NOxDataPacket;
            var rawConc : NOxConcentration;
            assign rawConc = (sample.rawValue * 1.0 [ppm/count]) * calibrationScale + calibrationOffset;
            assign packet.noxConcentration = rawConc;
            assign packet.sensorTemperature = temp;
            assign packet.timestamp = sample.timestamp;
            assign packet.valid = (temp >= 290 [degC]) and (temp <= 310 [degC]) and (lastErrorCode == 0);
            assign packet.errorCode = lastErrorCode;
        }

        action def runDiagnostics {
            out errorCode : ErrorCode;
            assign errorCode = 0;
        }

        action def calibrate {
            in referenceConc : NOxConcentration;
            in measuredConc : NOxConcentration;
            assign calibrationScale = referenceConc / measuredConc;
            assign calibrationOffset = 0 [ppm];
        }

        action def processCommand {
            in cmd : ControlCommand;
            if cmd.command == "start" {
                assign measurementActive = true;
            } elif cmd.command == "stop" {
                assign measurementActive = false;
            } elif cmd.command == "diagnose" {
                call runDiagnostics() -> lastErrorCode;
            } elif cmd.command == "reset" {
                assign lastErrorCode = 0;
                assign measurementActive = false;
            } elif cmd.command == "calibrate" {
                // calibration handled externally via calibrate action
            }
        }
    }

    // ---------- Top-level NOx Sensor Unit ----------
    part def NOxSensorUnit {

        port gasInput : GasInPort;
        port commandInput : CommandPort;
        port dataOutput : DataPacketPort;
        port powerInput : PowerPort;

        part heater : HeatingElement {
            :>> powerIn = powerInput;
        }

        part sensor : SensingElement {
            :>> gasIn = gasInput;
        }

        part tempMonitor : TemperatureMonitor;

        part signalProc : SignalProcessor;

        part adc : AnalogToDigitalConverter;

        part processor : ProcessingUnit {
            :>> commandIn = commandInput;
            :>> dataOut = dataOutput;
        }

        // Thermal connections
        connection heaterThermal to sensorThermal
            connect heater.thermalOut to sensor.thermalIn;
        connection heaterThermalToMonitor
            connect heater.thermalOut to tempMonitor.thermalIn;
        connection monitorReport
            connect tempMonitor.thermalReport to processor.thermalIn;

        // Signal chain
        connection rawSignalFlow
            connect sensor.rawSignalOut to signalProc.rawSignalIn;
        connection refinedSignalFlow
            connect signalProc.refinedSignalOut to adc.analogIn;
        connection digitalSignalFlow
            connect adc.digitalOut to processor.digitalIn;

        // ---------- Lifecycle State Machine ----------
        state sensorLifecycle {
            entry; then Initializing;
            state Initializing;
            state Warmup;
            state Ready;
            state Measuring;
            state Diagnostics;
            state Fault;
            state Calibration;

            transition init_to_warmup
                first Initializing
                then Warmup
                when heater.currentTemperature > 20 [degC];

            transition warmup_to_ready
                first Warmup
                then Ready
                when heater.currentTemperature >= heater.targetTemperature
                    and tempMonitor.inRange == true;

            transition ready_to_measuring
                first Ready
                then Measuring
                when commandInput.command.command == "start";

            transition measuring_to_ready
                first Measuring
                then Ready
                when commandInput.command.command == "stop";

            transition ready_to_diagnostics
                first Ready
                then Diagnostics
                when commandInput.command.command == "diagnose";

            transition diagnostics_to_ready
                first Diagnostics
                then Ready
                when processor.lastErrorCode == 0;

            transition diagnostics_to_fault
                first Diagnostics
                then Fault
                when processor.lastErrorCode != 0;

            transition ready_to_calibration
                first Ready
                then Calibration
                when commandInput.command.command == "calibrate";

            transition calibration_to_ready
                first Calibration
                then Ready
                accept 'done';

            transition any_to_fault
                first Ready, Measuring, Warmup
                then Fault
                when tempMonitor.inRange == false
                    or heater.currentTemperature > 350 [degC];

            transition fault_to_init
                first Fault
                then Initializing
                when commandInput.command.command == "reset";
        }

        // ---------- Main Measurement Action ----------
        action def performMeasurement {
            in gas : ExhaustGas;
            in temp : TemperatureValue;
            out packet : NOxDataPacket;
            var rawSignal : RawElectricalSignal;
            var refinedSignal : RefinedAnalogSignal;
            var digitalSample : DigitalSample;
            call sensor.sense(gas, temp) -> rawSignal;
            call signalProc.process(rawSignal) -> refinedSignal;
            call adc.convert(refinedSignal) -> digitalSample;
            call processor.calculateConcentration(digitalSample, temp) -> packet;
        }
    }

    // ---------- Requirements ----------
    requirement def NOxMeasurementRequirement {
        subject sensorUnit : NOxSensorUnit;
        objective {
            /* The sensor unit shall measure NOx concentration in exhaust gas
               and output a data packet containing concentration in ppm,
               sensor temperature, timestamp, validity flag, and error code. */
        }
        assume {
            gasInput.gas.noxConcentration >= 0 [ppm];
            gasInput.gas.noxConcentration <= 5000 [ppm];
        }
    }

    requirement def HeatingRequirement {
        subject heater : HeatingElement;
        attribute targetTemp : TemperatureValue = 300 [degC];
        attribute tolerance : TemperatureValue = 10 [degC];
        objective {
            /* The heating element shall bring the sensor to 300°C ±10°C
               and maintain it during operation. */
        }
        require {
            heater.targetTemperature == 300 [degC];
        }
    }

    requirement def SignalProcessingRequirement {
        subject proc : SignalProcessor;
        objective {
            /* The signal processor shall amplify and filter the raw signal
               from the sensing element before analog-to-digital conversion. */
        }
        require {
            proc.gain > 0;
            proc.cutoffFrequency > 0 [Hz];
        }
    }

    requirement def LifecycleRequirement {
        subject unit : NOxSensorUnit;
        objective {
            /* The sensor shall initialize, warm up, become ready, and
               support start, stop, diagnostics, reset, and calibration commands. */
        }
    }

    requirement def DataPacketRequirement {
        subject packet : NOxDataPacket;
        objective {
            /* The output data packet shall include NOx concentration (ppm),
               sensor temperature, timestamp, validity flag, and error code. */
        }
        require {
            packet.noxConcentration.unit == 'ppm';
            packet.sensorTemperature.unit == 'degC';
        }
    }

    // ---------- Requirement Satisfaction ----------
    satisfaction heatingSatisfies : HeatingRequirement {
        subject :>> heater;
    }

    satisfaction signalProcSatisfies : SignalProcessingRequirement {
        subject :>> signalProc;
    }

    satisfaction lifecycleSatisfies : LifecycleRequirement {
        subject :>> NOxSensorUnit;
    }

    satisfaction dataPacketSatisfies : DataPacketRequirement {
        subject :>> NOxDataPacket;
    }

    satisfaction measurementSatisfies : NOxMeasurementRequirement {
        subject :>> NOxSensorUnit;
    }

}
