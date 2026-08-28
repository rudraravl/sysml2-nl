package TemperatureMeasurementSystem {

    import ScalarValues::*;

    // ===== Units =====
    unit kelvin;
    unit volt;
    unit hertz;

    // ===== Value Types =====
    value type Temperature :> Real {
        unit kelvin;
    }

    value type Voltage :> Real {
        unit volt;
    }

    value type DigitalCount :> Integer;

    value type SamplingRate :> Real {
        unit hertz;
    }

    // ===== Item Definitions =====
    item def ThermocoupleVoltage {
        attribute magnitude : Voltage;
        attribute hotJunctionTemp : Temperature;
        attribute coldJunctionTemp : Temperature;
    }

    item def CompensatedVoltage {
        attribute magnitude : Voltage;
        attribute coldJunctionTemp : Temperature;
    }

    item def AmplifiedVoltage {
        attribute magnitude : Voltage;
        attribute coldJunctionTemp : Temperature;
    }

    item def DigitalSample {
        attribute code : DigitalCount;
        attribute coldJunctionTemp : Temperature;
    }

    item def TemperatureReading {
        attribute value : Temperature;
        attribute timestamp : String;
        attribute valid : Boolean;
    }

    item def AmbientTemperature {
        attribute value : Temperature;
    }

    // ===== Port Definitions =====
    port def RawVoltagePort {
        out item : ThermocoupleVoltage;
    }

    port def CompensatedVoltagePort {
        out item : CompensatedVoltage;
    }

    port def AmplifiedVoltagePort {
        out item : AmplifiedVoltage;
    }

    port def DigitalPort {
        out item : DigitalSample;
    }

    port def TemperaturePort {
        out item : TemperatureReading;
    }

    port def AmbientTempPort {
        out item : AmbientTemperature;
    }

    // ===== Thermocouple Components =====
    part def ChromelWire {
        attribute material : String = "Chromel (90% Nickel, 10% Chromium)";
        attribute diameter : Real = 0.5;
    }

    part def AlumelWire {
        attribute material : String = "Alumel (95% Nickel, 2% Aluminum, 2% Manganese, 1% Silicon)";
        attribute diameter : Real = 0.5;
    }

    part def HotJunction {
        attribute location : String = "measurement point";
        attribute temperature : Temperature;
    }

    part def ColdJunction {
        attribute location : String = "connection point";
        attribute referenceTemperature : Temperature;
    }

    part def TypeKThermocouple {
        attribute thermocoupleType : String = "Type K";
        attribute seebeckCoefficient : Voltage = 41.0e-6;

        part chromelWire : ChromelWire;
        part alumelWire : AlumelWire;
        part hotJunction : HotJunction;
        part coldJunction : ColdJunction;

        out port voltageOutput : RawVoltagePort;

        action def GenerateThermocoupleVoltage {
            in hotTemp : Temperature;
            in coldTemp : Temperature;
            out voltage : Voltage;
        }
    }

    // ===== Ambient Temperature Sensor =====
    part def AmbientTempSensor {
        attribute accuracy : Temperature = 0.5;

        out port ambientTempOutput : AmbientTempPort;

        action def MeasureAmbient {
            out ambient : AmbientTemperature;
        }
    }

    // ===== Cold Junction Compensator =====
    part def ColdJunctionCompensator {
        attribute compensationAccuracy : Temperature = 0.5;

        in port rawVoltageInput : RawVoltagePort;
        in port ambientTempInput : AmbientTempPort;
        out port compensatedVoltageOutput : CompensatedVoltagePort;

        action def Compensate {
            in raw : ThermocoupleVoltage;
            in ambient : AmbientTemperature;
            out compensated : CompensatedVoltage;
        }
    }

    // ===== Signal Amplifier =====
    part def SignalAmplifier {
        attribute gain : Real = 1000.0;
        attribute inputOffset : Voltage = 0.0;

        in port voltageInput : CompensatedVoltagePort;
        out port amplifiedVoltageOutput : AmplifiedVoltagePort;

        action def Amplify {
            in input : CompensatedVoltage;
            out output : AmplifiedVoltage;
        }
    }

    // ===== Analog-to-Digital Converter =====
    part def AnalogToDigitalConverter {
        attribute resolution : Integer = 16;
        attribute samplingRate : SamplingRate = 1000.0;
        attribute referenceVoltage : Voltage = 5.0;

        in port analogInput : AmplifiedVoltagePort;
        out port digitalOutput : DigitalPort;

        action def Convert {
            in analog : AmplifiedVoltage;
            out digital : DigitalSample;
        }
    }

    // ===== Temperature Calculator =====
    part def TemperatureCalculator {
        attribute nistTable : String = "NIST ITS-90 Type K Thermocouple Table";
        attribute polynomialOrder : Integer = 9;

        in port digitalInput : DigitalPort;
        out port temperatureOutput : TemperaturePort;

        action def CalculateTemperature {
            in sample : DigitalSample;
            out reading : TemperatureReading;
        }
    }

    // ===== State Machine Definition =====
    state def SystemStateMachine {
        entry; then Idle;

        state Idle {
            entry {
                // System waiting for measurement command
            }
        }

        state Measuring {
            entry; then Sensing;

            state Sensing {
                entry {
                    // Thermocouple generates voltage via Seebeck effect
                }
            }

            state Compensating {
                entry {
                    // Cold junction compensation applied to raw voltage
                }
            }

            state Amplifying {
                entry {
                    // Compensated signal amplified to measurable level
                }
            }

            state Converting {
                entry {
                    // Analog signal converted to digital value by ADC
                }
            }

            state Calculating {
                entry {
                    // Final temperature computed using NIST calibration table
                }
            }

            transition first Sensing then Compensating;
            transition first Compensating then Amplifying;
            transition first Amplifying then Converting;
            transition first Converting then Calculating;
        }

        state Fault {
            entry {
                // Error condition detected, system in fault state
            }
        }

        transition first Idle accept StartMeasurement then Measuring;
        transition first Measuring accept MeasurementComplete then Idle;
        transition first Idle accept ErrorDetected then Fault;
        transition first Measuring accept ErrorDetected then Fault;
        transition first Fault accept Reset then Idle;
    }

    // ===== Temperature Measurement System =====
    part def TemperatureMeasurementSystem {
        attribute systemName : String = "Thermocouple Temperature Measurement System";
        attribute maxOperatingTemp : Temperature = 1370.0;

        part thermocouple : TypeKThermocouple;
        part ambientSensor : AmbientTempSensor;
        part coldJunctionCompensator : ColdJunctionCompensator;
        part signalAmplifier : SignalAmplifier;
        part adc : AnalogToDigitalConverter;
        part temperatureCalculator : TemperatureCalculator;

        out port systemOutput : TemperaturePort;

        connection thermocoupleToCompensator
            connect thermocouple.voltageOutput to coldJunctionCompensator.rawVoltageInput;

        connection ambientToCompensator
            connect ambientSensor.ambientTempOutput to coldJunctionCompensator.ambientTempInput;

        connection compensatorToAmplifier
            connect coldJunctionCompensator.compensatedVoltageOutput to signalAmplifier.voltageInput;

        connection amplifierToADC
            connect signalAmplifier.amplifiedVoltageOutput to adc.analogInput;

        connection adcToCalculator
            connect adc.digitalOutput to temperatureCalculator.digitalInput;

        connection calculatorToSystem
            connect temperatureCalculator.temperatureOutput to systemOutput;

        exhibit state behavior : SystemStateMachine;
    }

    // ===== Requirements =====
    requirement def TemperatureAccuracyRequirement {
        subject system : TemperatureMeasurementSystem;
        attribute requiredAccuracy : Temperature = 1.0;
        doc "The system shall measure temperature with an accuracy of plus or minus 1 K across the operating range.";
    }

    requirement def ThermocoupleVoltageRangeRequirement {
        subject sensor : TypeKThermocouple;
        attribute minVoltage : Voltage = -6.0e-3;
        attribute maxVoltage : Voltage = 55.0e-3;
        doc "The Type K thermocouple shall produce voltage in the range of -6 mV to 55 mV over its operating range.";
    }

    requirement def AmplificationRequirement {
        subject amplifier : SignalAmplifier;
        attribute minimumGain : Real = 100.0;
        doc "The signal amplifier shall amplify the compensated thermocouple voltage by a minimum gain factor of 100.";
    }

    requirement def ADCResolutionRequirement {
        subject converter : AnalogToDigitalConverter;
        attribute minimumResolution : Integer = 12;
        doc "The analog-to-digital converter shall have a resolution of at least 12 bits.";
    }

    requirement def ColdJunctionCompensationRequirement {
        subject compensator : ColdJunctionCompensator;
        attribute compensationAccuracy : Temperature = 0.5;
        doc "The cold junction compensator shall measure ambient temperature and compensate the raw voltage with an accuracy of plus or minus 0.5 K.";
    }

    requirement def OperatingStatesRequirement {
        subject system : TemperatureMeasurementSystem;
        doc "The system shall operate through idle, measuring, and fault states, with the measuring state consisting of sensing, compensating, amplifying, converting, and calculating sub-states.";
    }

    requirement def ContinuousOperationRequirement {
        subject system : TemperatureMeasurementSystem;
        doc "The system shall provide reliable and continuous temperature data for industrial process monitoring and control purposes.";
    }

    // ===== Requirement Satisfaction =====
    satisfy TemperatureAccuracyRequirement by system : TemperatureMeasurementSystem;
    satisfy OperatingStatesRequirement by system : TemperatureMeasurementSystem;
    satisfy ThermocoupleVoltageRangeRequirement by thermocouple : TypeKThermocouple;
    satisfy AmplificationRequirement by signalAmplifier : SignalAmplifier;
    satisfy ADCResolutionRequirement by adc : AnalogToDigitalConverter;
    satisfy ColdJunctionCompensationRequirement by coldJunctionCompensator : ColdJunctionCompensator;
    satisfy ContinuousOperationRequirement by system : TemperatureMeasurementSystem;
}
