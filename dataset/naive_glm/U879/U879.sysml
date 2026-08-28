package TemperatureSensingUnit {
    import ISQ::*;
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type Temperature :> Real { unit "K"; }
    value type CelsiusTemp :> Real { unit "degC"; }
    value type DigitalCode :> Integer;
    value type Frequency :> Real { unit "Hz"; }
    value type Power :> Real { unit "W"; }
    value type BitCount :> Integer;

    attribute def ADCResolution :> BitCount { :>> defaultValue = 12; }
    attribute def LSBValue :> Voltage { :>> defaultValue = 0.001220703125; } // Vref/2^12 with Vref=5V

    // ===== Item Types =====
    item def ElectricalPower;
    item def AnalogSignal {
        attribute voltage : Voltage;
    }
    item def DigitalSample {
        attribute code : DigitalCode;
        attribute resolution : ADCResolution;
    }
    item def CalibratedTemperature {
        attribute value : Temperature;
        attribute uncertainty : Temperature;
    }
    item def ControlCommand {
        attribute kind : String;
    }
    item def StatusReport {
        attribute state : String;
        attribute errorFlag : Boolean;
    }

    // ===== Port Definitions =====
    port def PowerPort {
        out item power : ElectricalPower;
    }
    port def AnalogOutPort {
        out item signal : AnalogSignal;
    }
    port def AnalogInPort {
        in item signal : AnalogSignal;
    }
    port def DigitalOutPort {
        out item sample : DigitalSample;
    }
    port def DigitalInPort {
        in item sample : DigitalSample;
    }
    port def TempOutputPort {
        out item measurement : CalibratedTemperature;
    }
    port def ControlPort {
        in item command : ControlCommand;
        out item status : StatusReport;
    }

    // ===== Requirements =====
    requirement def AccuracyRequirement {
        attribute maxError : Temperature = 0.5 [K];
        doc /* The unit shall measure temperature with accuracy within 0.5 Kelvin. */
        requireConstraint { abs(measured - actual) <= maxError }
    }

    requirement def OperatingRangeRequirement {
        attribute minTemp : CelsiusTemp = -40 [degC];
        attribute maxTemp : CelsiusTemp = 125 [degC];
        doc /* The unit shall operate over the range -40°C to 125°C. */
    }

    requirement def ResolutionRequirement {
        attribute bits : ADCResolution = 12;
        doc /* The ADC shall provide 12-bit resolution. */
    }

    requirement def PowerRequirement {
        attribute maxPower : Power = 0.05 [W];
        doc /* The unit shall consume no more than 50 mW during active measurement. */
    }

    // ===== Parts =====

    part def BipolarJunctionTransistor {
        attribute biasCurrent : Current;
        attribute areaRatio : Real;
        port def TerminalPort {
            out item voltage : Voltage;
        }
        port base : TerminalPort;
        port emitter : TerminalPort;
    }

    part def BandgapReference {
        attribute referenceVoltage : Voltage = 1.25 [V];
        port refOut : AnalogOutPort;
    }

    part def Amplifier {
        attribute gain : Real = 10.0;
        port inPort : AnalogInPort;
        port outPort : AnalogOutPort;
    }

    part def SiliconBandgapSensor {
        attribute proportionalToAbsoluteTemp : Real = 0.01 [V/K];
        attribute bjt1 : BipolarJunctionTransistor {
            :>> biasCurrent = 0.0001 [A];
            :>> areaRatio = 1.0;
        }
        attribute bjt2 : BipolarJunctionTransistor {
            :>> biasCurrent = 0.0001 [A];
            :>> areaRatio = 8.0;
        }
        attribute reference : BandgapReference;
        attribute amplifier : Amplifier;

        port powerIn : PowerPort;
        port measurementOut : AnalogOutPort;

        flow from powerIn.power to reference.refOut;
        flow from reference.refOut.signal to amplifier.inPort.signal;
        flow from amplifier.outPort.signal to measurementOut.signal;

        action def GeneratePTAT {
            in bjt1Voltage : Voltage;
            in bjt2Voltage : Voltage;
            out ptatVoltage : Voltage;
        }
        action def CombineWithReference {
            in ptat : Voltage;
            in ref : Voltage;
            out combined : Voltage;
        }
        action def AmplifySignal {
            in input : Voltage;
            out output : Voltage;
        }

        perform action generateMeasurement {
            action generatePTAT : GeneratePTAT;
            action combine : CombineWithReference;
            action amplify : AmplifySignal;
            flow generatePTAT.ptatVoltage to combine.ptat;
            flow reference.referenceVoltage to combine.ref;
            flow combine.combined to amplify.input;
            flow amplify.output to measurementOut.signal.voltage;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolution : ADCResolution = 12;
        attribute referenceVoltage : Voltage = 5.0 [V];
        attribute samplingFrequency : Frequency = 1000 [Hz];

        port analogIn : AnalogInPort;
        port digitalOut : DigitalOutPort;
        port powerIn : PowerPort;

        action def Sample {
            in analog : AnalogSignal;
            out sample : DigitalSample;
        }
        action def Quantize {
            in voltage : Voltage;
            out code : DigitalCode;
        }

        perform action convert {
            action sample : Sample;
            action quantize : Quantize;
            flow analogIn.signal to sample.analog;
            flow sample.sample to digitalOut.sample;
        }

        satisfy ResolutionRequirement by resolution;
    }

    part def SignalProcessor {
        attribute offsetCorrection : Temperature = 0.0 [K];
        attribute gainCorrection : Real = 1.0;
        attribute calibrationTable : DigitalCode [*] = ();

        port dataIn : DigitalInPort;
        port resultOut : TempOutputPort;

        action def ApplyCalibration {
            in raw : DigitalSample;
            in offset : Temperature;
            in gain : Real;
            out calibrated : CalibratedTemperature;
        }
        action def ValidateResult {
            in measurement : CalibratedTemperature;
            out valid : Boolean;
        }

        perform action process {
            action calibrate : ApplyCalibration;
            action validate : ValidateResult;
            flow dataIn.sample to calibrate.raw;
            flow calibrate.calibrated to validate.measurement;
            flow validate.valid to resultOut.measurement.uncertainty;
        }
    }

    part def SensorController {
        attribute currentState : String;
        attribute errorCount : Integer = 0;
        attribute maxErrors : Integer = 3;

        port control : ControlPort;
        port sensorEnable : out item enableSensor : Boolean;
        port adcEnable : out item enableADC : Boolean;
        port processorEnable : out item enableProcessor : Boolean;

        state machine def ControllerStateMachine {
            entry; then Idle;

            state Idle {
                entry { currentState = "Idle"; }
                transition idleToActive first Idle
                    accept ControlCommand { :>> kind == "start" }
                    then Active;
            }

            state Active {
                entry { currentState = "Active"; }
                do { send true to sensorEnable; send true to adcEnable; }
                transition activeToProcessing first Active
                    accept DigitalSample
                    then Processing;
                transition activeToError first Active
                    accept ControlCommand { :>> kind == "error" }
                    then ErrorHandling;
            }

            state Processing {
                entry { currentState = "Processing"; }
                do { send true to processorEnable; }
                transition processingToReady first Processing
                    accept CalibratedTemperature
                    then Ready;
                transition processingToError first Processing
                    accept ControlCommand { :>> kind == "error" }
                    then ErrorHandling;
            }

            state Ready {
                entry { currentState = "Ready"; }
                do { send false to sensorEnable; send false to adcEnable; }
                transition readyToIdle first Ready
                    accept ControlCommand { :>> kind == "ack" }
                    then Idle;
            }

            state ErrorHandling {
                entry { currentState = "Error"; errorCount = errorCount + 1; }
                do { send false to sensorEnable; send false to adcEnable; send false to processorEnable; }
                transition errorToIdle first ErrorHandling
                    accept ControlCommand { :>> kind == "reset" }
                    then Idle;
            }
        }

        exhibit state machine : ControllerStateMachine;
    }

    part def TemperatureSensingUnit {
        port powerInput : PowerPort;
        port temperatureOutput : TempOutputPort;
        port controlInterface : ControlPort;

        part sensor : SiliconBandgapSensor;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        part controller : SensorController;

        // Power distribution
        flow from powerInput.power to sensor.powerIn.power;
        flow from powerInput.power to adc.powerIn.power;

        // Signal chain
        flow from sensor.measurementOut.signal to adc.analogIn.signal;
        flow from adc.digitalOut.sample to processor.dataIn.sample;
        flow from processor.resultOut.measurement to temperatureOutput.measurement;

        // Control connections
        flow from controller.sensorEnable to sensor.powerIn.power;
        flow from controller.adcEnable to adc.powerIn.power;
        flow from controller.processorEnable to processor.dataIn.sample;

        // Control interface
        flow from controlInterface.command to controller.control.command;
        flow from controller.control.status to controlInterface.status;

        satisfy AccuracyRequirement;
        satisfy OperatingRangeRequirement;
        satisfy PowerRequirement;
    }
}
