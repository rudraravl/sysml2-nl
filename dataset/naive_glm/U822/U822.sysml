package PiezometerSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ===== Value Types with Units =====
    value def PressureValue :> Real {
        unit 'kPa';
    }
    value def TemperatureValue :> Real {
        unit 'degC';
    }
    value def DepthValue :> Real {
        unit 'm';
    }
    value def VoltageValue :> Real {
        unit 'mV';
    }
    value def DigitalCount :> Integer {
        unit 'count';
    }
    value def BatteryLevel :> Real {
        unit 'percent';
    }
    value def TimeInterval :> Real {
        unit 's';
    }
    value def FrequencyValue :> Real {
        unit 'Hz';
    }

    // ===== Item Definitions =====
    item def RawElectricalSignal {
        attribute voltage : VoltageValue;
        attribute noiseLevel : VoltageValue;
    }
    item def CleanedAnalogSignal {
        attribute voltage : VoltageValue;
        attribute gain : Real;
    }
    item def DigitalSample {
        attribute rawCount : DigitalCount;
        attribute channel : String;
    }
    item def CalibrationCoefficients {
        attribute offset : Real;
        attribute scale : Real;
        attribute tempCoeff : Real;
        attribute referenceTemp : TemperatureValue;
    }
    item def DataRecord {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute depth : DepthValue;
        attribute timestamp : String;
        attribute recordId : Integer;
    }
    item def MeasurementSchedule {
        attribute interval : TimeInterval;
        attribute nextWakeTime : String;
    }

    // ===== Port Definitions =====
    port def GroundwaterInterface {
        out attribute ambientPressure : PressureValue;
        out attribute ambientTemperature : TemperatureValue;
    }
    port def RawSignalPort {
        out item rawSignal : RawElectricalSignal;
    }
    port def CleanedSignalPort {
        out item cleanedSignal : CleanedAnalogSignal;
    }
    port def DigitalDataPort {
        out item digitalSample : DigitalSample;
    }
    port def RecordDataPort {
        in item dataRecord : DataRecord;
        out item storedRecord : DataRecord;
    }
    port def TelemetryPort {
        out item transmittedRecord : DataRecord;
    }
    port def PowerPort {
        out attribute voltageSupply : VoltageValue;
        out attribute remainingCharge : BatteryLevel;
    }
    port def CalibrationPort {
        in item coefficients : CalibrationCoefficients;
    }

    // ===== Part Definitions =====
    part def PressureTransducer {
        port groundwaterIf : GroundwaterInterface;
        port rawOut : RawSignalPort;
        port powerIn : PowerPort;

        attribute sensingRange : PressureValue = 2000 [kPa];
        attribute accuracy : Real = 0.1;

        action def SensePressure {
            in ambientPressure : PressureValue;
            in ambientTemperature : TemperatureValue;
            out signal : RawElectricalSignal;
        }

        action sense : SensePressure {
            in ambientPressure = groundwaterIf.ambientPressure;
            in ambientTemperature = groundwaterIf.ambientTemperature;
            out signal -> rawOut.rawSignal;
        }
    }

    part def SignalConditioner {
        port rawIn : RawSignalPort;
        port cleanedOut : CleanedSignalPort;
        port powerIn : PowerPort;

        attribute amplifierGain : Real = 100;
        attribute filterCutoff : FrequencyValue = 10 [Hz];

        action def ConditionSignal {
            in raw : RawElectricalSignal;
            out cleaned : CleanedAnalogSignal;
        }

        action condition : ConditionSignal {
            in raw = rawIn.rawSignal;
            out cleaned -> cleanedOut.cleanedSignal;
        }
    }

    part def AnalogToDigitalConverter {
        port cleanedIn : CleanedSignalPort;
        port digitalOut : DigitalDataPort;
        port powerIn : PowerPort;

        attribute resolutionBits : Integer = 16;
        attribute samplingRate : FrequencyValue = 100 [Hz];

        action def Convert {
            in cleaned : CleanedAnalogSignal;
            out sample : DigitalSample;
        }

        action convert : Convert {
            in cleaned = cleanedIn.cleanedSignal;
            out sample -> digitalOut.digitalSample;
        }
    }

    part def Microprocessor {
        port digitalIn : DigitalDataPort;
        port recordOut : RecordDataPort;
        port calibrationIn : CalibrationPort;
        port powerIn : PowerPort;

        attribute deviceDepth : DepthValue = 15 [m];
        attribute storedCoefficients : CalibrationCoefficients;
        attribute clockAccuracy : Real = 5e-6;

        action def Calibrate {
            in sample : DigitalSample;
            in coefficients : CalibrationCoefficients;
            out pressure : PressureValue;
            out temperature : TemperatureValue;
        }

        action def AssembleRecord {
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            in depth : DepthValue;
            out record : DataRecord;
        }

        action calibrate : Calibrate {
            in sample = digitalIn.digitalSample;
            in coefficients = storedCoefficients;
            out pressure;
            out temperature;
        }

        action assemble : AssembleRecord {
            in pressure = calibrate.pressure;
            in temperature = calibrate.temperature;
            in depth = deviceDepth;
            out record -> recordOut.dataRecord;
        }
    }

    part def MemoryModule {
        port recordIn : RecordDataPort;
        port powerIn : PowerPort;

        attribute capacity : Integer = 100000;
        attribute storedRecords : DataRecord[*] ordered;

        action def StoreRecord {
            in record : DataRecord;
        }

        action store : StoreRecord {
            in record = recordIn.dataRecord;
        }
    }

    part def CommunicationModule {
        port recordIn : RecordDataPort;
        port telemetryOut : TelemetryPort;
        port powerIn : PowerPort;

        attribute protocol : String = "ModbusRTU";
        attribute baudRate : Integer = 9600;
        attribute transmitInterval : TimeInterval = 3600 [s];

        action def Transmit {
            in record : DataRecord;
            out transmitted : DataRecord;
        }

        action transmit : Transmit {
            in record = recordIn.storedRecord;
            out transmitted -> telemetryOut.transmittedRecord;
        }
    }

    part def Battery {
        port powerOut : PowerPort;

        attribute nominalVoltage : VoltageValue = 3600 [mV];
        attribute capacity_mAh : Real = 10000;
        attribute currentCharge : BatteryLevel = 100 [percent];
        attribute lowThreshold : BatteryLevel = 15 [percent];

        action def SupplyPower {
            out voltage : VoltageValue;
            out charge : BatteryLevel;
        }

        action supply : SupplyPower {
            out voltage -> powerOut.voltageSupply;
            out charge -> powerOut.remainingCharge;
        }
    }

    // ===== Top-level Piezometer Assembly =====
    part def ElectronicPiezometer {
        port groundwaterIf : GroundwaterInterface;
        port telemetryOut : TelemetryPort;
        port calibrationIn : CalibrationPort;

        part transducer : PressureTransducer {
            port groundwaterIf redefines ElectronicPiezometer::groundwaterIf;
        }
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part processor : Microprocessor {
            port calibrationIn redefines ElectronicPiezometer::calibrationIn;
        }
        part memory : MemoryModule;
        part comm : CommunicationModule {
            port telemetryOut redefines ElectronicPiezometer::telemetryOut;
        }
        part battery : Battery;

        // Internal connections
        connection rawLink connect transducer.rawOut to conditioner.rawIn;
        connection cleanedLink connect conditioner.cleanedOut to adc.cleanedIn;
        connection digitalLink connect adc.digitalOut to processor.digitalIn;
        connection recordLink connect processor.recordOut to memory.recordIn;
        connection memoryLink connect memory.recordIn to comm.recordIn;
        connection powerToTransducer connect battery.powerOut to transducer.powerIn;
        connection powerToConditioner connect battery.powerOut to conditioner.powerIn;
        connection powerToAdc connect battery.powerOut to adc.powerIn;
        connection powerToProcessor connect battery.powerOut to processor.powerIn;
        connection powerToMemory connect battery.powerOut to memory.powerIn;
        connection powerToComm connect battery.powerOut to comm.powerIn;

        // ===== State Machine =====
        state def PiezometerStateMachine {
            entry action {
                // Initialize system on power-up
            }
            exit action {
                // Safe shutdown procedure
            }

            state standby {
                entry action {
                    // Enter low-power standby mode
                }
                do action {
                    // Maintain RTC, await scheduled wake
                }
            }

            state activeMeasurement {
                entry action {
                    // Power up transducer and signal chain
                }
                do action {
                    transducer.sense();
                    conditioner.condition();
                    adc.convert();
                    processor.calibrate();
                    processor.assemble();
                    memory.store();
                }
                exit action {
                    // Power down measurement chain
                }
            }

            state dataTransmission {
                entry action {
                    // Power up communication module
                }
                do action {
                    comm.transmit();
                }
                exit action {
                    // Power down communication module
                }
            }

            state calibrationMode {
                entry action {
                    // Accept field calibration coefficients
                }
                do action {
                    // Apply new coefficients and verify
                }
                exit action {
                    // Persist coefficients to processor
                }
            }

            state lowPowerMode {
                entry action {
                    // Reduce clock rate, disable non-essential subsystems
                }
                do action {
                    // Monitor battery recovery
                }
            }

            transition standby -> activeMeasurement
                when transducer.sense.signal.signalReady
                guard battery.currentCharge > battery.lowThreshold;

            transition activeMeasurement -> dataTransmission
                when memory.store.done;

            transition dataTransmission -> standby
                when comm.transmit.done;

            transition standby -> calibrationMode
                when processor.calibrationIn.coefficients.received;

            transition calibrationMode -> standby
                when calibrationMode.exit.done;

            transition standby -> lowPowerMode
                when battery.currentCharge <= battery.lowThreshold;

            transition lowPowerMode -> standby
                when battery.currentCharge > 30 [percent];
        }

        attribute stateMachine : PiezometerStateMachine;

        // Operational attributes
        attribute measurementInterval : TimeInterval = 600 [s];
        attribute deploymentDepth : DepthValue = 15 [m];
        attribute firmwareVersion : String = "2.1.0";
    }

    // ===== Requirements =====
    requirement def MeasurementAccuracyRequirement {
        subject piezometer : ElectronicPiezometer;
        objective {
            doc "The piezometer shall measure pore water pressure with an accuracy of at least 0.1% of full scale over the operating temperature range."
        }
        assume {
            piezometer.transducer.sensingRange <= 2000 [kPa];
        }
    }

    requirement def BatteryLifeRequirement {
        subject piezometer : ElectronicPiezometer;
        attribute minDurationDays : Real = 365;
        objective {
            doc "The piezometer shall operate autonomously on internal battery power for a minimum of one year under the configured measurement interval."
        }
        assume {
            piezometer.measurementInterval >= 600 [s];
        }
    }

    requirement def DataIntegrityRequirement {
        subject piezometer : ElectronicPiezometer;
        objective {
            doc "Each data record shall contain calibrated pressure, temperature, device depth, and a timestamp with a clock accuracy of 5 ppm."
        }
    }

    requirement def EnvironmentalSurvivabilityRequirement {
        subject piezometer : ElectronicPiezometer;
        attribute maxOperatingPressure : PressureValue = 2000 [kPa];
        attribute operatingTempMin : TemperatureValue = -20 [degC];
        attribute operatingTempMax : TemperatureValue = 70 [degC];
        objective {
            doc "The piezometer shall remain operational when submerged in groundwater at pressures up to 2000 kPa and temperatures between -20 and 70 degrees Celsius."
        }
    }

    requirement def TelemetryRequirement {
        subject piezometer : ElectronicPiezometer;
        objective {
            doc "The communication module shall transmit stored data records to an external receiver at scheduled intervals without data loss."
        }
    }

    requirement piezometerAccuracy : MeasurementAccuracyRequirement {
        subject = ElectronicPiezometer;
    }
    requirement piezometerBatteryLife : BatteryLifeRequirement {
        subject = ElectronicPiezometer;
    }
    requirement piezometerDataIntegrity : DataIntegrityRequirement {
        subject = ElectronicPiezometer;
    }
    requirement piezometerEnvironmental : EnvironmentalSurvivabilityRequirement {
        subject = ElectronicPiezometer;
    }
    requirement piezometerTelemetry : TelemetryRequirement {
        subject = ElectronicPiezometer;
    }
}
