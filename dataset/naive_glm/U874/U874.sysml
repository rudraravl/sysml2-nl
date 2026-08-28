package EnvironmentalSensingUnit {

    import ScalarValues::*;

    // ---- Units ----
    unit 'degC' {
        doc "Degree Celsius";
    }
    unit 'V' {
        doc "Volt";
    }
    unit 'mV' {
        doc "Millivolt";
    }
    unit 's' {
        doc "Second";
    }
    unit 'Hz' {
        doc "Hertz";
    }

    // ---- Value Types ----
    value type Temperature :> Real {
        unit 'degC';
    }
    value type Voltage :> Real {
        unit 'V';
    }
    value type Millivoltage :> Real {
        unit 'mV';
    }
    value type Duration :> Real {
        unit 's';
    }
    value type Frequency :> Real {
        unit 'Hz';
    }
    value type Confidence :> Real {
        doc "Confidence level between 0.0 and 1.0";
    }

    // ---- Item Definitions ----
    item def RawElectricalSignal {
        attribute magnitude : Millivoltage;
        attribute noiseLevel : Millivoltage;
    }

    item def DigitalTemperature {
        attribute value : Temperature;
        attribute valid : Boolean;
        attribute confidence : Confidence;
        attribute timestamp : Duration;
    }

    item def RegulatedPower {
        attribute voltage : Voltage;
        attribute stable : Boolean;
    }

    item def CalibrationReference {
        attribute referenceTemp : Temperature;
    }

    // ---- Port Definitions ----
    port def RawSignalOutPort {
        out rawSignal : RawElectricalSignal;
    }

    port def RawSignalInPort {
        in rawSignal : RawElectricalSignal;
    }

    port def DigitalTempOutPort {
        out tempData : DigitalTemperature;
    }

    port def DigitalTempInPort {
        in tempData : DigitalTemperature;
    }

    port def PowerOutPort {
        out power : RegulatedPower;
    }

    port def PowerInPort {
        in power : RegulatedPower;
    }

    // ---- Sensing Element ----
    part def SensingElement {
        attribute material : String = "stainless steel";
        attribute sensingRangeMin : Temperature = -40 ['degC'];
        attribute sensingRangeMax : Temperature = 100 ['degC'];
        attribute sensitivity : Millivoltage = 10.0 ['mV'/'degC'];

        port rawOut : RawSignalOutPort;

        action def SenseTemperature {
            in ambientTemp : Temperature;
            out raw : RawElectricalSignal;
        }

        action sense : SenseTemperature {
            in ambientTemp;
            out raw = rawOut.rawSignal;
        }
    }

    // ---- Signal Processor ----
    part def SignalProcessor {
        attribute amplificationGain : Real = 10.0;
        attribute filterCutoff : Frequency = 50.0 ['Hz'];
        attribute validationThreshold : Confidence = 0.9;

        port rawIn : RawSignalInPort;
        port digitalOut : DigitalTempOutPort;
        port powerIn : PowerInPort;

        action def Amplify {
            in raw : RawElectricalSignal;
            out amplified : RawElectricalSignal;
        }

        action def Filter {
            in input : RawElectricalSignal;
            out filtered : RawElectricalSignal;
        }

        action def Convert {
            in filtered : RawElectricalSignal;
            out digital : DigitalTemperature;
        }

        action def Validate {
            in digital : DigitalTemperature;
            out validated : DigitalTemperature;
        }

        action def ProcessSignal {
            in raw : RawElectricalSignal;
            out digital : DigitalTemperature;

            action a1 : Amplify {
                in raw;
                out amplified;
            }
            action a2 : Filter {
                in input = a1.amplified;
                out filtered;
            }
            action a3 : Convert {
                in filtered = a2.filtered;
                out digital;
            }
            action a4 : Validate {
                in digital = a3.digital;
                out validated;
            }

            return a4.validated;
        }

        action process : ProcessSignal {
            in raw = rawIn.rawSignal;
            out digital = digitalOut.tempData;
        }
    }

    // ---- Power Management ----
    part def PowerManagement {
        attribute operatingVoltage : Voltage = 5.0 ['V'];
        attribute regulationTolerance : Voltage = 0.05 ['V'];

        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;

        action def Regulate {
            in input : RegulatedPower;
            out output : RegulatedPower;
        }

        action regulate : Regulate {
            in input = powerIn.power;
            out output = powerOut.power;
        }
    }

    // ---- Data Buffer ----
    part def DataBuffer {
        attribute capacity : Integer = 16;
        attribute storedMeasurements : DigitalTemperature[0..capacity];

        action def Store {
            in measurement : DigitalTemperature;
        }

        action def Retrieve {
            out measurement : DigitalTemperature;
        }

        action def Clear {}

        action store : Store;
        action retrieve : Retrieve;
    }

    // ---- Sensor Node ----
    part def SensorNode {

        port externalPowerIn : PowerInPort;
        port measurementOut : DigitalTempOutPort;
        port calibrationIn : DigitalTempInPort;

        part sensingElement : SensingElement;
        part signalProcessor : SignalProcessor;
        part powerManagement : PowerManagement;
        part dataBuffer : DataBuffer;

        connection rawSignalLink connect sensingElement.rawOut to signalProcessor.rawIn;
        connection internalPowerLink connect powerManagement.powerOut to signalProcessor.powerIn;
        connection externalPowerLink connect externalPowerIn to powerManagement.powerIn;
        connection bufferStoreLink connect signalProcessor.digitalOut to dataBuffer.store.measurement;

        attribute lastMeasurement : DigitalTemperature;

        // ---- Lifecycle State Machine ----
        state def Lifecycle {

            entry action initialize {
                doc "Initialize sensor node subsystems.";
            }

            state idle {
                entry action enterIdle {
                    doc "Enter low-power idle mode.";
                }
            }

            state sensing {
                entry action startSensing {
                    doc "Trigger sensing element to acquire raw signal.";
                }
                do action acquireReading {
                    doc "Continuously acquire raw signal until reading complete.";
                }
            }

            state processing {
                entry action startProcessing {
                    doc "Amplify, filter, convert, and validate the raw signal.";
                }
            }

            state outputting {
                entry action startOutput {
                    doc "Make validated measurement available on output port.";
                }
            }

            state calibration {
                entry action startCalibration {
                    doc "Adjust accuracy against known reference temperature.";
                }
            }

            state error {
                entry action handleError {
                    doc "Log fault and isolate faulty subsystem.";
                }
            }

            transition idle_to_sensing
                from idle to sensing
                when startMeasurement;

            transition sensing_to_processing
                from sensing to processing
                when readingComplete;

            transition processing_to_outputting
                from processing to outputting
                when validationPassed;

            transition processing_to_error
                from processing to error
                when validationFailed;

            transition outputting_to_idle
                from outputting to idle
                when outputAcknowledged;

            transition idle_to_calibration
                from idle to calibration
                when calibrateCommand;

            transition calibration_to_idle
                from calibration to idle
                when calibrationComplete;

            transition sensing_to_error
                from sensing to error
                when sensorFault;

            transition error_to_idle
                from error to idle
                when faultCleared;
        }

        state machine lifecycle : Lifecycle;

        // Events
        event startMeasurement;
        event readingComplete;
        event validationPassed;
        event validationFailed;
        event outputAcknowledged;
        event calibrateCommand;
        event calibrationComplete;
        event sensorFault;
        event faultCleared;
    }

    // ---- Power Supply ----
    part def PowerSupply {
        attribute outputVoltage : Voltage = 5.0 ['V'];
        attribute ratedPower : Real = 2.5;
        attribute protected : Boolean = true;

        port powerOut : PowerOutPort;

        action def SupplyPower {
            out power : RegulatedPower;
        }

        action supply : SupplyPower {
            out power = powerOut.power;
        }
    }

    // ---- Data Acquisition System ----
    part def DataAcquisitionSystem {
        attribute samplingRate : Frequency = 1.0 ['Hz'];
        attribute storageCapacity : Integer = 1000;

        port measurementIn : DigitalTempInPort;

        action def ReceiveMeasurement {
            in measurement : DigitalTemperature;
        }

        action def LogMeasurement {
            in measurement : DigitalTemperature;
        }

        action receive : ReceiveMeasurement {
            in measurement = measurementIn.tempData;
        }
    }

    // ---- Environmental Sensing Unit (Top-Level) ----
    part def EnvironmentalSensingUnit {
        attribute enclosureRating : String = "IP67";
        attribute enclosureMaterial : String = "stainless steel";
        attribute mountingType : String = "wall-mountable";
        attribute operationalTempMin : Temperature = -40 ['degC'];
        attribute operationalTempMax : Temperature = 100 ['degC'];

        port powerInput : PowerInPort;
        port dataOutput : DigitalTempOutPort;

        part sensorNode : SensorNode;
        part powerSupply : PowerSupply;
        part dataAcquisition : DataAcquisitionSystem;

        connection supplyToNode connect powerSupply.powerOut to sensorNode.externalPowerIn;
        connection nodeToAcquisition connect sensorNode.measurementOut to dataAcquisition.measurementIn;
        connection externalPower connect powerInput to powerSupply.powerOut;
        connection acquisitionOutput connect dataAcquisition.measurementIn to dataOutput;

        attribute measurementError : Temperature;
        attribute responseTime : Duration;
    }

    // ---- Requirements ----
    requirement def MeasurementAccuracyRequirement {
        doc "The environmental sensing unit shall measure ambient temperature with an accuracy of ±0.5°C across the operational range.";
        subject sensingUnit : EnvironmentalSensingUnit;
        constraint {
            sensingUnit.measurementError <= 0.5 ['degC']
        }
    }

    requirement def ResponseTimeRequirement {
        doc "The environmental sensing unit shall complete a full measurement cycle (sensing, processing, outputting) in under one second.";
        subject sensingUnit : EnvironmentalSensingUnit;
        constraint {
            sensingUnit.responseTime < 1.0 ['s']
        }
    }

    requirement def OperationalTemperatureRangeRequirement {
        doc "The environmental sensing unit shall operate reliably across an ambient temperature range of -40°C to 100°C.";
        subject sensingUnit : EnvironmentalSensingUnit;
        constraint {
            sensingUnit.operationalTempMin <= -40 ['degC'] and
            sensingUnit.operationalTempMax >= 100 ['degC']
        }
    }

    requirement def EnclosureRequirement {
        doc "The unit shall be housed in a stainless steel, IP67-rated, wall-mountable enclosure suitable for harsh industrial conditions.";
        subject sensingUnit : EnvironmentalSensingUnit;
        constraint {
            sensingUnit.enclosureRating == "IP67" and
            sensingUnit.enclosureMaterial == "stainless steel" and
            sensingUnit.mountingType == "wall-mountable"
        }
    }

    requirement def ValidationRequirement {
        doc "All measurements provided to the external system shall be validated with a confidence level of at least 0.9.";
        subject sensorNode : SensorNode;
        constraint {
            sensorNode.lastMeasurement.confidence >= 0.9 and
            sensorNode.lastMeasurement.valid == true
        }
    }

    // ---- Requirement Satisfaction ----
    part sensingUnitInstance : EnvironmentalSensingUnit {
        satisfy MeasurementAccuracyRequirement;
        satisfy ResponseTimeRequirement;
        satisfy OperationalTemperatureRangeRequirement;
        satisfy EnclosureRequirement;
    }

    part sensorNodeInstance : SensorNode {
        satisfy ValidationRequirement;
    }

}
