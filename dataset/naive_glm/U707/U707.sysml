package HeatFluxSensingUnitModel {
    import ScalarValues::*;

    // ---- Value types with units ----
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def HeatFlux :> Real { unit 'W/m^2'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Dimensionless :> Real;
    value def Timestamp :> Integer;
    value def QualityIndicator :> Integer;
    value def SampleCount :> Integer;

    // ---- Item definitions ----
    item def HeatFlow {
        attribute flux : HeatFlux;
        attribute ambientTemp : Temperature;
    }

    item def RawVoltageSignal {
        attribute voltage : Voltage;
        attribute noiseLevel : Voltage;
        attribute sourceTemp : Temperature;
    }

    item def ConditionedAnalogSignal {
        attribute voltage : Voltage;
        attribute bandwidth : Frequency;
    }

    item def DigitalSample {
        attribute rawValue : Integer;
        attribute sampleTime : Timestamp;
        attribute resolutionBits : Integer;
    }

    item def TemperatureReading {
        attribute temperature : Temperature;
        attribute readTime : Timestamp;
    }

    item def CalibrationData {
        attribute sensitivity : Dimensionless;
        attribute voltageOffset : Voltage;
        attribute tempCoefficient : Dimensionless;
        attribute validRangeMin : HeatFlux;
        attribute validRangeMax : HeatFlux;
        attribute lastCalibrationTime : Timestamp;
    }

    item def HeatFluxDataPacket {
        attribute heatFlux : HeatFlux;
        attribute timestamp : Timestamp;
        attribute sensorTemperature : Temperature;
        attribute quality : QualityIndicator;
    }

    item def CommandSignal {
        attribute command : String;
        attribute parameter : String;
    }

    // ---- Port definitions ----
    port def HeatFlowPort {
        in item flow : HeatFlow;
    }

    port def PowerPort {
        attribute supplyVoltage : Voltage;
        attribute supplyCurrent : Current;
    }

    port def RawSignalOut {
        out item signal : RawVoltageSignal;
    }

    port def RawSignalIn {
        in item signal : RawVoltageSignal;
    }

    port def ConditionedSignalOut {
        out item signal : ConditionedAnalogSignal;
    }

    port def ConditionedSignalIn {
        in item signal : ConditionedAnalogSignal;
    }

    port def DigitalSampleOut {
        out item sample : DigitalSample;
    }

    port def DigitalSampleIn {
        in item sample : DigitalSample;
    }

    port def TemperatureSignalOut {
        out item reading : TemperatureReading;
    }

    port def TemperatureSignalIn {
        in item reading : TemperatureReading;
    }

    port def DataPacketOut {
        out item packet : HeatFluxDataPacket;
    }

    port def DataPacketIn {
        in item packet : HeatFluxDataPacket;
    }

    port def CommandIn {
        in item command : CommandSignal;
    }

    // ---- Internal part definitions ----

    part def ThermopileSensor {
        port heatIn : HeatFlowPort;
        port signalOut : RawSignalOut;
        port tempOut : TemperatureSignalOut;

        attribute sensitivity : Voltage; // V per (W/m^2)
        attribute internalResistance : Real;
        attribute nominalTemperature : Temperature;
        attribute warmUpTime : Frequency; // stabilization time constant

        action generateVoltage {
            in heatFlux : HeatFlux;
            in sensorTemp : Temperature;
            out rawSignal : RawVoltageSignal;
            rawSignal.voltage := heatFlux * sensitivity;
            rawSignal.sourceTemp := sensorTemp;
        }

        action measureTemperature {
            out reading : TemperatureReading;
            reading.temperature := nominalTemperature;
        }
    }

    part def SignalConditioner {
        port signalIn : RawSignalIn;
        port signalOut : ConditionedSignalOut;

        attribute gain : Dimensionless;
        attribute cutoffFreq : Frequency;
        attribute inputImpedance : Real;

        action conditionSignal {
            in raw : RawVoltageSignal;
            out conditioned : ConditionedAnalogSignal;
            conditioned.voltage := raw.voltage * gain;
            conditioned.bandwidth := cutoffFreq;
        }
    }

    part def AnalogToDigitalConverter {
        port signalIn : ConditionedSignalIn;
        port dataOut : DigitalSampleOut;

        attribute sampleRate : Frequency;
        attribute resolutionBits : Integer;
        attribute referenceVoltage : Voltage;

        action convert {
            in conditioned : ConditionedAnalogSignal;
            in sampleTime : Timestamp;
            out sample : DigitalSample;
            sample.rawValue := toInteger(conditioned.voltage / referenceVoltage * (2 ^ resolutionBits));
            sample.sampleTime := sampleTime;
            sample.resolutionBits := resolutionBits;
        }
    }

    part def CentralProcessingUnit {
        port sampleIn : DigitalSampleIn;
        port tempIn : TemperatureSignalIn;
        port packetOut : DataPacketOut;
        port storageOut : DataPacketOut;
        port commandIn : CommandIn;

        attribute calibration : CalibrationData;
        attribute clockFrequency : Frequency;
        attribute packetCount : SampleCount;
        attribute systemTime : Timestamp;

        action applyCalibration {
            in sample : DigitalSample;
            in tempReading : TemperatureReading;
            in calib : CalibrationData;
            out packet : HeatFluxDataPacket;
            attribute rawVoltage : Voltage;
            rawVoltage := sample.rawValue * calib.sensitivity;
            packet.heatFlux := (rawVoltage - calib.voltageOffset) * (1.0 + calib.tempCoefficient * (tempReading.temperature - 25.0));
            packet.timestamp := sample.sampleTime;
            packet.sensorTemperature := tempReading.temperature;
            packet.quality := computeQuality(sample, calib);
        }

        action computeQuality {
            in sample : DigitalSample;
            in calib : CalibrationData;
            return quality : QualityIndicator;
        }
    }

    part def DataStorageModule {
        port storageIn : DataPacketIn;

        attribute capacity : SampleCount;
        attribute recordCount : SampleCount;
        attribute overwriteEnabled : Boolean;

        action logPacket {
            in packet : HeatFluxDataPacket;
            if recordCount < capacity then {
                recordCount := recordCount + 1;
            } else if overwriteEnabled then {
                recordCount := 1;
            }
        }
    }

    // ---- The Heat Flux Sensing Unit ----

    part def HeatFluxSensingUnit {
        port heatFluxInput : HeatFlowPort;
        port powerInput : PowerPort;
        port commandInput : CommandIn;
        port dataOutput : DataPacketOut;

        attribute sensorTemperature : Temperature;
        attribute measurementActive : Boolean;
        attribute sensorStable : Boolean;
        attribute commandReceived : String;
        attribute errorDetected : Boolean;
        attribute calibrationComplete : Boolean;
        attribute recoveryInitiated : Boolean;
        attribute recoverySuccessful : Boolean;
        attribute warmUpElapsed : Boolean;

        part thermopile : ThermopileSensor {
            attribute sensitivity := 0.00001 [V]; // 10 uV per W/m^2
            attribute nominalTemperature := 25.0 [degC];
        }
        part conditioner : SignalConditioner {
            attribute gain := 1000.0;
            attribute cutoffFreq := 10.0 [Hz];
        }
        part adc : AnalogToDigitalConverter {
            attribute sampleRate := 100.0 [Hz];
            attribute resolutionBits := 24;
            attribute referenceVoltage := 5.0 [V];
        }
        part cpu : CentralProcessingUnit {
            attribute clockFrequency := 16000000.0 [Hz];
            attribute calibration.sensitivity := 1.0;
            attribute calibration.voltageOffset := 0.0 [V];
            attribute calibration.tempCoefficient := 0.001;
            attribute calibration.validRangeMin := -2000.0 [W/m^2];
            attribute calibration.validRangeMax := 2000.0 [W/m^2];
        }
        part tempSensor : ThermopileSensor {
            attribute nominalTemperature := 25.0 [degC];
        }
        part storage : DataStorageModule {
            attribute capacity := 1000000;
            attribute recordCount := 0;
            attribute overwriteEnabled := true;
        }

        // ---- Internal connections ----
        connection heatToSensor connect heatFluxInput to thermopile.heatIn;
        connection rawSignalLink connect thermopile.signalOut to conditioner.signalIn;
        connection conditionedSignalLink connect conditioner.signalOut to adc.signalIn;
        connection digitalSampleLink connect adc.dataOut to cpu.sampleIn;
        connection tempSignalLink connect tempSensor.tempOut to cpu.tempIn;
        connection dataPacketLink connect cpu.packetOut to dataOutput;
        connection storageLink connect cpu.storageOut to storage.storageIn;
        connection commandLink connect commandInput to cpu.commandIn;

        // ---- Operating state machine ----
        state def OperatingStates {
            entry; then initialize;

            state initialize {
                entry action {
                    sensorStable := false;
                    warmUpElapsed := false;
                    measurementActive := false;
                    errorDetected := false;
                }
                do action {
                    // Warm-up sequence: allow thermopile to stabilize
                    warmUpElapsed := true;
                    sensorStable := true;
                }
                transition init_to_ready
                    first initialize
                    then ready
                    when warmUpElapsed == true & sensorStable == true;
                transition init_to_fault
                    first initialize
                    then faultDetected
                    when errorDetected == true;
            }

            state ready {
                entry action {
                    measurementActive := false;
                }
                transition ready_to_measuring
                    first ready
                    then measuring
                    when commandReceived == "start";
                transition ready_to_calibration
                    first ready
                    then calibrationMode
                    when commandReceived == "calibrate";
                transition ready_to_fault
                    first ready
                    then faultDetected
                    when errorDetected == true;
            }

            state measuring {
                entry action {
                    measurementActive := true;
                }
                do action {
                    // Continuous sampling, calibration, packet output, and logging
                }
                transition measuring_to_ready
                    first measuring
                    then ready
                    when commandReceived == "stop";
                transition measuring_to_fault
                    first measuring
                    then faultDetected
                    when errorDetected == true;
            }

            state calibrationMode {
                entry action {
                    calibrationComplete := false;
                }
                do action {
                    // Apply known reference and update sensitivity, offsets, temp coefficient
                    calibrationComplete := true;
                }
                transition calibration_to_ready
                    first calibrationMode
                    then ready
                    when calibrationComplete == true;
                transition calibration_to_fault
                    first calibrationMode
                    then faultDetected
                    when errorDetected == true;
            }

            state faultDetected {
                entry action {
                    measurementActive := false;
                    recoveryInitiated := false;
                    recoverySuccessful := false;
                }
                do action {
                    // Log fault and attempt recovery
                    recoveryInitiated := true;
                    recoverySuccessful := true;
                }
                transition fault_to_init
                    first faultDetected
                    then initialize
                    when recoveryInitiated == true & recoverySuccessful == false;
                transition fault_to_ready
                    first faultDetected
                    then ready
                    when recoverySuccessful == true;
            }
        }

        state operatingState : OperatingStates;
    }

    // ---- Requirements ----

    requirement def MeasurementAccuracyRequirement {
        doc /* The sensing unit shall measure heat flux within +/-2% of reading across the calibrated range. */;
        subject unit : HeatFluxSensingUnit;
        objective {
            doc /* Verify output heatFlux accuracy against a reference standard. */;
        }
    }

    requirement def OutputPacketRequirement {
        doc /* The unit shall emit a data packet containing heat flux, timestamp, sensor temperature, and quality indicator. */;
        subject unit : HeatFluxSensingUnit;
        objective {
            doc /* Confirm dataOutput port provides complete HeatFluxDataPacket. */;
        }
    }

    requirement def SignalChainRequirement {
        doc /* Raw thermopile voltage shall be amplified, filtered, and digitized before processing. */;
        subject unit : HeatFluxSensingUnit;
        objective {
            doc /* Verify thermopile -> conditioner -> ADC -> CPU connectivity and data flow. */;
        }
    }

    requirement def StateBehaviorRequirement {
        doc /* The unit shall transition through initialize, ready, measuring, calibrationMode, and faultDetected states. */;
        subject unit : HeatFluxSensingUnit;
        objective {
            doc /* Verify state machine covers all defined states and transitions. */;
        }
    }

    requirement def FaultRecoveryRequirement {
        doc /* The unit shall detect faults, enter faultDetected state, and attempt recovery to return to ready. */;
        subject unit : HeatFluxSensingUnit;
        objective {
            doc /* Confirm fault detection and recovery transitions. */;
        }
    }

    requirement def DataLoggingRequirement {
        doc /* The unit shall log measurement packets to internal storage. */;
        subject unit : HeatFluxSensingUnit;
        objective {
            doc /* Verify storageLink delivers packets to DataStorageModule. */;
        }
    }

    requirement def WarmUpRequirement {
        doc /* The unit shall perform initialization and warm-up before entering ready state. */;
        subject unit : HeatFluxSensingUnit;
        objective {
            doc /* Confirm sensorStable and warmUpElapsed gate the transition to ready. */;
        }
    }

    requirement measurementAccuracy : MeasurementAccuracyRequirement {
        subject :>> unit : HeatFluxSensingUnit;
    }

    requirement outputPacket : OutputPacketRequirement {
        subject :>> unit : HeatFluxSensingUnit;
    }

    requirement signalChain : SignalChainRequirement {
        subject :>> unit : HeatFluxSensingUnit;
    }

    requirement stateBehavior : StateBehaviorRequirement {
        subject :>> unit : HeatFluxSensingUnit;
    }

    requirement faultRecovery : FaultRecoveryRequirement {
        subject :>> unit : HeatFluxSensingUnit;
    }

    requirement dataLogging : DataLoggingRequirement {
        subject :>> unit : HeatFluxSensingUnit;
    }

    requirement warmUp : WarmUpRequirement {
        subject :>> unit : HeatFluxSensingUnit;
    }
}
