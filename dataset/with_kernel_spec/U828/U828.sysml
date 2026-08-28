package PositionSensitiveDevice {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    value def Photocurrent :> ElectricCurrentValue;
    value def ElectrodeCurrent :> Photocurrent;
    value def AnalogVoltage :> VoltageValue;
    value def BiasVoltage :> VoltageValue;
    value def Temperature :> ThermodynamicTemperatureValue;
    value def DigitalSample :> Real;
    value def ConfidenceScore :> Real;
    value def PositionCoordinate :> LengthValue;
    value def SampleRate :> FrequencyValue;

    attribute def Position2D {
        attribute x : PositionCoordinate;
        attribute y : PositionCoordinate;
    }

    item def LightBeam {
        attribute intensity : Real;
        attribute wavelength : LengthValue;
    }
    item def ElectrodeCurrents {
        attribute currents : ElectrodeCurrent[1..*] ordered;
    }
    item def AnalogVoltages {
        attribute voltages : AnalogVoltage[1..*] ordered;
    }
    item def DigitalSamples {
        attribute samples : DigitalSample[1..*] ordered;
    }
    item def CalibrationData {
        attribute electrodePositions : Position2D[1..*] ordered;
        attribute gainFactors : Real[1..*] ordered;
        attribute surfaceWidth : PositionCoordinate;
        attribute surfaceHeight : PositionCoordinate;
    }
    item def Measurement {
        attribute position : Position2D;
        attribute confidence : ConfidenceScore;
        attribute timestamp : TimeInstantValue;
    }

    attribute def PowerUp;
    attribute def PowerDown;
    attribute def BiasOn;
    attribute def OverTempAlert;
    attribute def TempRestored;

    port def LightInputPort { in item beam : LightBeam; }
    port def CurrentOutputPort { out item currents : ElectrodeCurrents; }
    port def CurrentInputPort { in item currents : ElectrodeCurrents; }
    port def VoltageOutputPort { out item voltages : AnalogVoltages; }
    port def VoltageInputPort { in item voltages : AnalogVoltages; }
    port def DigitalOutputPort { out item samples : DigitalSamples; }
    port def DigitalInputPort { in item samples : DigitalSamples; }
    port def MeasurementOutputPort { out item measurement : Measurement; }
    port def BiasOutputPort { out attribute bias : BiasVoltage; }
    port def BiasInputPort { in attribute bias : BiasVoltage; }
    port def TemperaturePort { out attribute temp : Temperature; }

    action def GenerateCurrents {
        in item beam : LightBeam;
        in attribute bias : BiasVoltage;
        out item currents : ElectrodeCurrents;
    }
    action def AmplifyCurrents {
        in item currents : ElectrodeCurrents;
        out item voltages : AnalogVoltages;
    }
    action def ConvertToDigital {
        in item voltages : AnalogVoltages;
        in attribute sampleRate : SampleRate;
        out item samples : DigitalSamples;
    }
    action def CalculatePosition {
        in item samples : DigitalSamples;
        in item calibration : CalibrationData;
        out item measurement : Measurement;
    }
    action def RegulateBias {
        in attribute temp : Temperature;
        in attribute nominalBias : BiasVoltage;
        out attribute adjustedBias : BiasVoltage;
    }

    part def PhotodetectorArray;
    part def TransimpedanceAmplifier;
    part def AnalogDigitalConverter;
    part def PositionCalculator;
    part def BiasController;
    part def TemperatureSensor;
    part def PSDSystem;

    state def PSDOperationalStates;

    requirement def PositionAccuracyRequirement {
        attribute maxError : PositionCoordinate;
        subject positionError : PositionCoordinate;
        assert constraint positionErrorConstraint { positionError <= maxError }
    }
    requirement def LatencyRequirement {
        attribute maxLatency : DurationValue;
        subject actualLatency : DurationValue;
        assert constraint latencyConstraint { actualLatency <= maxLatency }
    }
    requirement def SampleRateRequirement {
        attribute minSampleRate : SampleRate;
        subject actualSampleRate : SampleRate;
        assert constraint sampleRateConstraint { actualSampleRate >= minSampleRate }
    }

    part psdSystem : PSDSystem {
        attribute surfaceWidth : PositionCoordinate = 0.01;
        attribute surfaceHeight : PositionCoordinate = 0.01;
        attribute nominalBias : BiasVoltage = 5.0;
        attribute maxOperatingTemp : Temperature = 343.15;
        attribute minSampleRate : SampleRate = 10000.0;

        in port lightInput : LightInputPort;
        out port dataOutput : MeasurementOutputPort;

        flow lightInput.beam to photodetector.lightIn.beam;
        flow photodetector.currentOut.currents to amplifier.currentIn.currents;
        flow amplifier.voltageOut.voltages to adc.voltageIn.voltages;
        flow adc.digitalOut.samples to calculator.digitalIn.samples;
        flow biasController.biasOut.bias to photodetector.biasIn.bias;
        flow biasController.biasOut.bias to amplifier.biasRef.bias;
        flow temperatureSensor.tempOut.temp to biasController.tempIn.temp;
        flow calculator.measurementOut.measurement to dataOutput.measurement;

        part photodetector : PhotodetectorArray {
            in port lightIn : LightInputPort;
            in port biasIn : BiasInputPort;
            out port currentOut : CurrentOutputPort;
            perform action generate : GenerateCurrents {
                in item beam = lightIn.beam;
                in attribute bias = biasIn.bias;
                out item currents = currentOut.currents;
            }
        }

        part amplifier : TransimpedanceAmplifier {
            in port currentIn : CurrentInputPort;
            in port biasRef : BiasInputPort;
            out port voltageOut : VoltageOutputPort;
            perform action amplify : AmplifyCurrents {
                in item currents = currentIn.currents;
                out item voltages = voltageOut.voltages;
            }
        }

        part adc : AnalogDigitalConverter {
            in port voltageIn : VoltageInputPort;
            out port digitalOut : DigitalOutputPort;
            attribute sampleRate : SampleRate = minSampleRate;
            perform action convert : ConvertToDigital {
                in item voltages = voltageIn.voltages;
                in attribute sampleRate = sampleRate;
                out item samples = digitalOut.samples;
            }
        }

        part calculator : PositionCalculator {
            in port digitalIn : DigitalInputPort;
            out port measurementOut : MeasurementOutputPort;
            item calibration : CalibrationData {
                attribute surfaceWidth = psdSystem.surfaceWidth;
                attribute surfaceHeight = psdSystem.surfaceHeight;
            }
            perform action calculate : CalculatePosition {
                in item samples = digitalIn.samples;
                in item calibration = calibration;
                out item measurement = measurementOut.measurement;
            }
        }

        part biasController : BiasController {
            in port tempIn : TemperaturePort;
            out port biasOut : BiasOutputPort;
            perform action regulate : RegulateBias {
                in attribute temp = tempIn.temp;
                in attribute nominalBias = psdSystem.nominalBias;
                out attribute adjustedBias = biasOut.bias;
            }
        }

        part temperatureSensor : TemperatureSensor {
            out port tempOut : TemperaturePort;
            attribute currentTemp : Temperature = 298.15;
            bind tempOut.temp = currentTemp;
        }

        exhibit state operationalStates : PSDOperationalStates parallel {
            state powerStates {
                entry; then off;
                state off;
                accept PowerUp
                    do send new BiasOn() to biasController
                    then initializing;
                state initializing {
                    entry; then active;
                }
                state active;
                accept PowerDown
                    then off;
            }
            state healthStates {
                entry; then normal;
                state normal;
                accept when temperatureSensor.currentTemp > maxOperatingTemp
                    do send new OverTempAlert() to biasController
                    then degraded;
                state degraded;
                accept TempRestored
                    then normal;
            }
        }

        requirement positionAccuracy : PositionAccuracyRequirement {
            attribute maxError = 0.00005;
        }
        requirement latency : LatencyRequirement {
            attribute maxLatency = 0.001;
        }
        requirement sampleRate : SampleRateRequirement {
            attribute minSampleRate = psdSystem.minSampleRate;
        }
    }
}
