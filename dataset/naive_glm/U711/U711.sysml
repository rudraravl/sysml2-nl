package HumiditySensorSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    attribute def VoltageValue :> Real {
        attribute unit : VoltageUnit[1] default V;
    }
    attribute def ResistanceValue :> Real {
        attribute unit : ResistanceUnit[1] default Ohm;
    }
    attribute def HumidityValue :> Real {
        attribute unit : Real[1] default 1; // percent relative humidity
        attribute min : Real default 0.0;
        attribute max : Real default 100.0;
    }
    attribute def TemperatureValue :> Real {
        attribute unit : TemperatureUnit[1] default 'degC';
    }
    attribute def DigitalCode :> Integer {
        attribute min : Integer default 0;
        attribute max : Integer default 4095;
    }
    attribute def FrequencyValue :> Real {
        attribute unit : FrequencyUnit[1] default Hz;
    }

    // ---- Items flowing through the system ----
    item def HumistorResistance {
        attribute value : ResistanceValue;
    }
    item def AnalogVoltage {
        attribute value : VoltageValue;
    }
    item def DigitalSample {
        attribute code : DigitalCode;
        attribute timestamp : TimeValue;
    }
    item def TemperatureSample {
        attribute value : TemperatureValue;
        attribute timestamp : TimeValue;
    }
    item def CalibratedHumidity {
        attribute value : HumidityValue;
        attribute temperatureCompensation : TemperatureValue;
        attribute timestamp : TimeValue;
    }
    item def RegulatedPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    item def CurrentValue :> Real {
        attribute unit : CurrentUnit[1] default A;
    }

    // ---- Port definitions ----
    port def PowerOutPort {
        out power : RegulatedPower;
    }
    port def PowerInPort {
        in power : RegulatedPower;
    }
    port def ResistancePort {
        out resistance : HumistorResistance;
    }
    port def AnalogVoltagePort {
        in analogIn : AnalogVoltage;
        out analogOut : AnalogVoltage;
    }
    port def DigitalOutPort {
        out sample : DigitalSample;
    }
    port def DigitalInPort {
        in sample : DigitalSample;
    }
    port def TemperaturePort {
        out temp : TemperatureSample;
    }
    port def HumidityReportPort {
        out humidity : CalibratedHumidity;
    }
    port def AmbientInterfacePort {
        in ambientHumidity : HumidityValue;
        in ambientTemperature : TemperatureValue;
    }

    // ---- Requirement definitions ----
    requirement def HumidityAccuracyRequirement {
        attribute maxError : HumidityValue default 2.0;
        subject : sensor :> HumiditySensorSystem::HumiditySensorSystem;
        objective {
            doc "The calibrated humidity reading shall be within +/-2% RH of the true ambient relative humidity across the operating range."
        }
    }
    requirement def MeasurementRangeRequirement {
        attribute minRH : HumidityValue default 0.0;
        attribute maxRH : HumidityValue default 100.0;
        subject : sensor :> HumiditySensorSystem::HumiditySensorSystem;
        objective {
            doc "The system shall measure relative humidity from 0% to 100% RH."
        }
    }
    requirement def ReportingIntervalRequirement {
        attribute interval : TimeValue default 1.0 [s];
        subject : sensor :> HumiditySensorSystem::HumiditySensorSystem;
        objective {
            doc "The system shall report a calibrated humidity reading at least once per second during continuous operation."
        }
    }
    requirement def PowerStabilityRequirement {
        attribute regulatedTolerance : VoltageValue default 0.05;
        subject : regulator :> HumiditySensorSystem::PowerRegulator;
        objective {
            doc "The power regulator shall maintain output voltage within +/-50 mV of nominal under load."
        }
    }
    requirement def TemperatureCompensationRequirement {
        subject : processor :> HumiditySensorSystem::SignalProcessor;
        objective {
            doc "The signal processor shall apply temperature compensation using measured temperature data to correct humidity readings."
        }
    }

    // ---- Part definitions ----
    part def Humistor {
        port powerIn : PowerInPort;
        port resistanceOut : ResistancePort;
        port ambient : AmbientInterfacePort;

        attribute nominalResistance : ResistanceValue default 100.0 [kOhm];
        attribute sensitivity : Real default 0.5; // %/kOhm per %RH approx
        attribute currentResistance : ResistanceValue;

        action def SenseResistance {
            in ambientRH : HumidityValue;
            in ambientT : TemperatureValue;
            out resistance : HumistorResistance;
        }
    }

    part def PowerRegulator {
        port rawIn : PowerInPort;
        port regulatedOut : PowerOutPort;

        attribute nominalVoltage : VoltageValue default 3.3 [V];
        attribute maxLoadCurrent : CurrentValue default 0.1 [A];

        action def Regulate {
            in raw : RegulatedPower;
            out regulated : RegulatedPower;
        }
    }

    part def VoltageDividerCircuit {
        port powerIn : PowerInPort;
        port resistanceIn : ResistancePort;
        port analogOut : AnalogVoltagePort;

        attribute referenceResistor : ResistanceValue default 10.0 [kOhm];
        attribute supplyVoltage : VoltageValue default 3.3 [V];

        action def ConvertToVoltage {
            in resistance : HumistorResistance;
            out voltage : AnalogVoltage;
        }
    }

    part def AnalogToDigitalConverter {
        port powerIn : PowerInPort;
        port analogIn : AnalogVoltagePort;
        port digitalOut : DigitalOutPort;

        attribute resolutionBits : Integer default 12;
        attribute referenceVoltage : VoltageValue default 3.3 [V];
        attribute samplingRate : FrequencyValue default 100.0 [Hz];

        action def Digitize {
            in voltage : AnalogVoltage;
            out sample : DigitalSample;
        }
    }

    part def SignalProcessor {
        port powerIn : PowerInPort;
        port digitalIn : DigitalInPort;
        port temperatureIn : TemperaturePort;
        port reportOut : HumidityReportPort;

        attribute calibrationCoefficients : Real[3] default (0.0, 1.0, 0.0);
        attribute temperatureCoefficient : Real default -0.15; // %RH per degC
        attribute referenceTemperature : TemperatureValue default 25.0 ['degC'];

        action def ProcessSample {
            in rawSample : DigitalSample;
            in tempSample : TemperatureSample;
            out calibrated : CalibratedHumidity;
        }

        action def ApplyCalibration {
            in code : DigitalCode;
            out calibratedRH : HumidityValue;
        }

        action def CompensateTemperature {
            in rh : HumidityValue;
            in temp : TemperatureValue;
            out compensatedRH : HumidityValue;
        }
    }

    part def TemperatureSensor {
        port powerIn : PowerInPort;
        port tempOut : TemperaturePort;
        port ambient : AmbientInterfacePort;

        attribute accuracy : TemperatureValue default 0.5 ['degC'];
        attribute range : TemperatureValue[2] default (-40.0 ['degC'], 125.0 ['degC']);

        action def MeasureTemperature {
            in ambientT : TemperatureValue;
            out temp : TemperatureSample;
        }
    }

    part def HumiditySensorSystem {
        port ambientInterface : AmbientInterfacePort;
        port humidityReport : HumidityReportPort;
        port rawPowerIn : PowerInPort;

        part regulator : PowerRegulator {
            satisfy PowerStabilityRequirement by regulator;
        }
        part humistor : Humistor;
        part divider : VoltageDividerCircuit;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor {
            satisfy TemperatureCompensationRequirement by processor;
        }
        part tempSensor : TemperatureSensor;

        // Internal connections
        connection rawPowerToRegulator connect rawPowerIn to regulator.rawIn;
        connection regulatorToHumistor connect regulator.regulatedOut to humistor.powerIn;
        connection regulatorToDivider connect regulator.regulatedOut to divider.powerIn;
        connection regulatorToADC connect regulator.regulatedOut to adc.powerIn;
        connection regulatorToProcessor connect regulator.regulatedOut to processor.powerIn;
        connection regulatorToTempSensor connect regulator.regulatedOut to tempSensor.powerIn;

        connection humistorToDivider connect humistor.resistanceOut to divider.resistanceIn;
        connection dividerToADC connect divider.analogOut to adc.analogIn;
        connection adcToProcessor connect adc.digitalOut to processor.digitalIn;
        connection tempSensorToProcessor connect tempSensor.tempOut to processor.temperatureIn;

        connection ambientToHumistor connect ambientInterface to humistor.ambient;
        connection ambientToTempSensor connect ambientInterface to tempSensor.ambient;
        connection processorReport connect processor.reportOut to humidityReport;

        // Requirements satisfaction
        satisfy HumidityAccuracyRequirement by this;
        satisfy MeasurementRangeRequirement by this;
        satisfy ReportingIntervalRequirement by this;

        // ---- Operational state machine ----
        state def OperatingBehavior {
            entry action {
                doc "Initialize all subsystems upon power-up.";
            }
            state Off;
            state Initializing {
                entry action {
                    doc "Power up regulator and initialize processor configuration registers.";
                }
            }
            state Stabilizing {
                attribute stabilizationDuration : TimeValue default 2.0 [s];
                entry action {
                    doc "Allow humistor to acclimate to ambient conditions.";
                }
            }
            state Sensing {
                entry action {
                    doc "Humistor senses ambient humidity; resistance is read by voltage divider.";
                }
            }
            state Converting {
                entry action {
                    doc "ADC digitizes the analog voltage from the divider.";
                }
            }
            state Processing {
                entry action {
                    doc "Signal processor applies calibration and temperature compensation.";
                }
            }
            state Reporting {
                entry action {
                    doc "Report calibrated humidity reading via output port.";
                }
            }
            state Idle {
                attribute idleDuration : TimeValue default 0.5 [s];
                entry action {
                    doc "Brief pause before next measurement cycle.";
                }
            }
            transition offToInit transition from Off to Initializing
                when rawPowerIn.power.voltage > 0.0 [V];
            transition initToStab transition from Initializing to Stabilizing
                after 0.5 [s];
            transition stabToSense transition from Stabilizing to Sensing
                after 2.0 [s];
            transition senseToConvert transition from Sensing to Converting
                when humistor.resistanceOut.resistance.value > 0.0 [Ohm];
            transition convertToProcess transition from Converting to Processing
                when adc.digitalOut.sample.code >= 0;
            transition processToReport transition from Processing to Reporting
                when processor.reportOut.humidity.value >= 0.0;
            transition reportToIdle transition from Reporting to Idle
                after 0.1 [s];
            transition idleToSense transition from Idle to Sensing
                after 0.5 [s];
        }

        state operatingBehavior : OperatingBehavior {
            exhibit state Off;
            exhibit state Initializing;
            exhibit state Stabilizing;
            exhibit state Sensing;
            exhibit state Converting;
            exhibit state Processing;
            exhibit state Reporting;
            exhibit state Idle;
        }

        // ---- Continuous measurement action chain ----
        action def MeasurementCycle {
            in ambientRH : HumidityValue;
            in ambientT : TemperatureValue;
            out reportedHumidity : CalibratedHumidity;

            action senseHumistor : Humistor::SenseResistance {
                in ambientRH = ambientRH;
                in ambientT = ambientT;
            }
            action senseTemperature : TemperatureSensor::MeasureTemperature {
                in ambientT = ambientT;
            }
            action convertVoltage : VoltageDividerCircuit::ConvertToVoltage {
                in resistance = senseHumistor.resistance;
            }
            action digitize : AnalogToDigitalConverter::Digitize {
                in voltage = convertVoltage.voltage;
            }
            action process : SignalProcessor::ProcessSample {
                in rawSample = digitize.sample;
                in tempSample = senseTemperature.temp;
                out calibrated = reportedHumidity;
            }
        }
    }
}
