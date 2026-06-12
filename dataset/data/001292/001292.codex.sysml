package TransducerBasedMeasurementSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Sensitivity {
        input measurand : Real;
        output electricalSignal : Real;
    }

    item def PhysicalStimulus {
        attribute magnitude : Real;
        attribute frequency : Real;
        attribute timestamp : Real;
    }

    item def MechanicalStimulus specializes PhysicalStimulus {
        attribute force : Real;
        attribute displacement : Real;
    }

    item def ElectricalSignal {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
        attribute noiseLevel : Real;
        attribute timestamp : Real;
    }

    item def DigitalMeasurement {
        attribute value : Real;
        attribute engineeringUnit : String;
        attribute sampleTime : Real;
        attribute qualityCode : String;
    }

    item def Power {
        attribute voltage : Real;
        attribute current : Real;
        attribute ripple : Real;
    }

    item def ConfigurationData {
        attribute samplingRate : Real;
        attribute gainSetting : Real;
        attribute offsetCorrection : Real;
        attribute calibrationDate : String;
    }

    item def HealthStatus {
        attribute statusCode : String;
        attribute temperature : Real;
        attribute supplyVoltage : Real;
        attribute faultCount : Integer;
    }

    port def StimulusInputPort {
        in item stimulus : PhysicalStimulus;
    }

    port def AnalogSignalPort {
        out item analogSignal : ElectricalSignal;
    }

    port def AnalogInputPort {
        in item analogSignal : ElectricalSignal;
    }

    port def DigitalMeasurementPort {
        out item measurement : DigitalMeasurement;
    }

    port def PowerInputPort {
        in item power : Power;
    }

    port def ConfigurationPort {
        in item configuration : ConfigurationData;
    }

    port def StatusPort {
        out item status : HealthStatus;
    }

    action def ConvertStimulusToElectricalSignal {
        in item stimulus : PhysicalStimulus;
        in gain : Real;
        in offset : Real;
        out item signal : ElectricalSignal;

        first start;
        then computeSignal;

        action computeSignal {
            signal.voltage = stimulus.magnitude * gain + offset;
            signal.current = signal.voltage / 10000.0;
            signal.frequency = stimulus.frequency;
            signal.noiseLevel = 0.002;
            signal.timestamp = stimulus.timestamp;
        }
    }

    action def FilterAnalogSignal {
        in item rawSignal : ElectricalSignal;
        in cutoffFrequency : Real;
        out item filteredSignal : ElectricalSignal;

        first start;
        then attenuateNoise;

        action attenuateNoise {
            filteredSignal.voltage = rawSignal.voltage;
            filteredSignal.current = rawSignal.current;
            filteredSignal.frequency = rawSignal.frequency;
            filteredSignal.noiseLevel = rawSignal.noiseLevel * 0.15;
            filteredSignal.timestamp = rawSignal.timestamp;
        }
    }

    action def DigitizeSignal {
        in item analogSignal : ElectricalSignal;
        in sampleRate : Real;
        in resolutionBits : Integer;
        out item digitalMeasurement : DigitalMeasurement;

        first start;
        then sampleAndQuantize;

        action sampleAndQuantize {
            digitalMeasurement.value = analogSignal.voltage;
            digitalMeasurement.engineeringUnit = "V";
            digitalMeasurement.sampleTime = analogSignal.timestamp;
            digitalMeasurement.qualityCode = "VALID";
        }
    }

    action def MonitorHealth {
        in item power : Power;
        in internalTemperature : Real;
        out item health : HealthStatus;

        first start;
        then evaluate;

        action evaluate {
            health.supplyVoltage = power.voltage;
            health.temperature = internalTemperature;
            health.faultCount = 0;
            health.statusCode = "NOMINAL";
        }
    }

    state def TransducerOperatingState {
        entry action initialize;
        state Off;
        state SelfTest;
        state Ready;
        state Measuring;
        state Fault;
        state Calibrating;

        transition initial then Off;
        transition Off_to_SelfTest
            first Off
            accept PowerApplied
            then SelfTest;

        transition SelfTest_to_Ready
            first SelfTest
            accept SelfTestPassed
            then Ready;

        transition SelfTest_to_Fault
            first SelfTest
            accept SelfTestFailed
            then Fault;

        transition Ready_to_Measuring
            first Ready
            accept StimulusDetected
            then Measuring;

        transition Measuring_to_Ready
            first Measuring
            accept StimulusRemoved
            then Ready;

        transition Ready_to_Calibrating
            first Ready
            accept CalibrationRequested
            then Calibrating;

        transition Calibrating_to_Ready
            first Calibrating
            accept CalibrationCompleted
            then Ready;

        transition Any_to_Fault
            first Ready
            accept FaultDetected
            then Fault;

        transition Fault_to_SelfTest
            first Fault
            accept ResetRequested
            then SelfTest;
    }

    part def Transducer {
        attribute measurableRangeMin : Real = 0.0;
        attribute measurableRangeMax : Real = 1000.0;
        attribute nominalSensitivity : Real = 0.010;
        attribute linearityErrorPercent : Real = 0.25;
        attribute responseTime : Real = 0.005;
        attribute operatingTemperatureMin : Real = -40.0;
        attribute operatingTemperatureMax : Real = 85.0;

        port stimulusIn : StimulusInputPort;
        port signalOut : AnalogSignalPort;
        port powerIn : PowerInputPort;
        port configurationIn : ConfigurationPort;
        port statusOut : StatusPort;

        perform action convert : ConvertStimulusToElectricalSignal {
            in stimulus = stimulusIn.stimulus;
            in gain = nominalSensitivity;
            in offset = 0.0;
            out signal = signalOut.analogSignal;
        }

        exhibit state operatingState : TransducerOperatingState;
    }

    part def SignalConditioner {
        attribute gain : Real = 4.0;
        attribute cutoffFrequency : Real = 500.0;
        attribute inputImpedance : Real = 1000000.0;
        attribute outputImpedance : Real = 100.0;

        port analogIn : AnalogInputPort;
        port analogOut : AnalogSignalPort;
        port powerIn : PowerInputPort;

        perform action filter : FilterAnalogSignal {
            in rawSignal = analogIn.analogSignal;
            in cutoffFrequency = cutoffFrequency;
            out filteredSignal = analogOut.analogSignal;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute sampleRate : Real = 1000.0;
        attribute referenceVoltage : Real = 5.0;
        attribute conversionLatency : Real = 0.001;

        port analogIn : AnalogInputPort;
        port measurementOut : DigitalMeasurementPort;
        port powerIn : PowerInputPort;
        port configurationIn : ConfigurationPort;

        perform action digitize : DigitizeSignal {
            in analogSignal = analogIn.analogSignal;
            in sampleRate = sampleRate;
            in resolutionBits = resolutionBits;
            out digitalMeasurement = measurementOut.measurement;
        }
    }

    part def ProcessingController {
        attribute processorClockFrequency : Real = 48000000.0;
        attribute measurementUpdateRate : Real = 100.0;
        attribute diagnosticInterval : Real = 1.0;
        attribute internalTemperature : Real = 35.0;

        port measurementIn : DigitalMeasurementPort;
        port configurationIn : ConfigurationPort;
        port statusOut : StatusPort;
        port powerIn : PowerInputPort;

        perform action healthMonitoring : MonitorHealth {
            in power = powerIn.power;
            in internalTemperature = internalTemperature;
            out health = statusOut.status;
        }
    }

    part def PowerRegulator {
        attribute inputVoltageNominal : Real = 24.0;
        attribute outputVoltageNominal : Real = 5.0;
        attribute maxOutputCurrent : Real = 0.5;
        attribute efficiency : Real = 0.88;

        port externalPowerIn : PowerInputPort;
        port regulatedPowerOut : PowerInputPort;
    }

    part def TransducerMeasurementSystem {
        attribute primaryFunction : String =
            "Transform a physical stimulus into a calibrated digital measurement by sensing the stimulus, converting it to an electrical signal, conditioning the signal, digitizing it, and reporting measurement and health status.";

        port stimulusInput : StimulusInputPort;
        port externalPower : PowerInputPort;
        port configurationInput : ConfigurationPort;
        port measurementOutput : DigitalMeasurementPort;
        port statusOutput : StatusPort;

        part transducer : Transducer;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part controller : ProcessingController;
        part regulator : PowerRegulator;

        connect stimulusInput.stimulus to transducer.stimulusIn.stimulus;
        connect transducer.signalOut.analogSignal to conditioner.analogIn.analogSignal;
        connect conditioner.analogOut.analogSignal to adc.analogIn.analogSignal;
        connect adc.measurementOut.measurement to controller.measurementIn.measurement;
        connect adc.measurementOut.measurement to measurementOutput.measurement;

        connect externalPower.power to regulator.externalPowerIn.power;
        connect regulator.regulatedPowerOut.power to transducer.powerIn.power;
        connect regulator.regulatedPowerOut.power to conditioner.powerIn.power;
        connect regulator.regulatedPowerOut.power to adc.powerIn.power;
        connect regulator.regulatedPowerOut.power to controller.powerIn.power;

        connect configurationInput.configuration to transducer.configurationIn.configuration;
        connect configurationInput.configuration to adc.configurationIn.configuration;
        connect configurationInput.configuration to controller.configurationIn.configuration;

        connect controller.statusOut.status to statusOutput.status;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall convert an incoming physical stimulus into a calibrated digital measurement suitable for downstream monitoring, control, or recording. */
        subject system : TransducerMeasurementSystem;

        require constraint {
            system.primaryFunction != "";
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The transducer shall accept physical stimulus magnitudes from 0 to 1000 engineering units without saturation. */
        subject transducer : Transducer;

        require constraint {
            transducer.measurableRangeMin == 0.0 and
            transducer.measurableRangeMax == 1000.0;
        }
    }

    requirement def SensitivityRequirement {
        doc /* The transducer shall provide a nominal sensitivity of 10 mV per engineering unit of applied stimulus. */
        subject transducer : Transducer;

        require constraint {
            transducer.nominalSensitivity == 0.010;
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The transducer shall produce an electrical response within 5 ms after a valid stimulus change. */
        subject transducer : Transducer;

        require constraint {
            transducer.responseTime <= 0.005;
        }
    }

    requirement def SignalQualityRequirement {
        doc /* The signal conditioner shall reduce analog noise by at least 80 percent before analog-to-digital conversion. */
        subject conditioner : SignalConditioner;

        require constraint {
            conditioner.cutoffFrequency <= 500.0;
        }
    }

    requirement def DigitizationRequirement {
        doc /* The analog-to-digital converter shall sample conditioned signals at no less than 1000 samples per second with at least 16-bit resolution. */
        subject adc : AnalogToDigitalConverter;

        require constraint {
            adc.sampleRate >= 1000.0 and
            adc.resolutionBits >= 16;
        }
    }

    requirement def PowerRequirement {
        doc /* The regulated power subsystem shall provide 5 V DC power to all internal electronic parts. */
        subject regulator : PowerRegulator;

        require constraint {
            regulator.outputVoltageNominal == 5.0 and
            regulator.maxOutputCurrent >= 0.5;
        }
    }

    requirement def HealthMonitoringRequirement {
        doc /* The controller shall report system health status including supply voltage, internal temperature, fault count, and status code. */
        subject controller : ProcessingController;

        require constraint {
            controller.diagnosticInterval <= 1.0;
        }
    }

    requirement def OperatingTemperatureRequirement {
        doc /* The transducer shall operate over the industrial temperature range from -40 degrees C to 85 degrees C. */
        subject transducer : Transducer;

        require constraint {
            transducer.operatingTemperatureMin <= -40.0 and
            transducer.operatingTemperatureMax >= 85.0;
        }
    }

    part measurementSystem : TransducerMeasurementSystem;

    satisfy PrimaryFunctionRequirement by measurementSystem;
    satisfy MeasurementRangeRequirement by measurementSystem.transducer;
    satisfy SensitivityRequirement by measurementSystem.transducer;
    satisfy ResponseTimeRequirement by measurementSystem.transducer;
    satisfy SignalQualityRequirement by measurementSystem.conditioner;
    satisfy DigitizationRequirement by measurementSystem.adc;
    satisfy PowerRequirement by measurementSystem.regulator;
    satisfy HealthMonitoringRequirement by measurementSystem.controller;
    satisfy OperatingTemperatureRequirement by measurementSystem.transducer;
}