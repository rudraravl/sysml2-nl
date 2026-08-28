package NetRadiometerSystem {
    import ScalarValues::*;

    // ==================== Units ====================
    unit V;
    unit W;
    unit m2;
    unit W_per_m2;
    unit degC;
    unit s;

    // ==================== Value Types ====================
    value type Voltage :> Real {
        unit : V;
    }

    value type Temperature :> Real {
        unit : degC;
    }

    value type Irradiance :> Real {
        unit : W_per_m2;
    }

    value type TimeDuration :> Real {
        unit : s;
    }

    value type Sensitivity :> Real {
        doc /* Calibration sensitivity in V per (W/m2) */;
    }

    // ==================== Items ====================
    item RawSignal {
        attribute signalVoltage : Voltage;
        attribute bodyTemperature : Temperature;
    }

    item ProcessedData {
        attribute downwardIrradiance : Irradiance;
        attribute upwardIrradiance : Irradiance;
        attribute netIrradiance : Irradiance;
        attribute sensorTemperature : Temperature;
        attribute timestamp : TimeDuration;
        attribute valid : Boolean;
    }

    // ==================== Port Definitions ====================
    port def RawSignalOutPort {
        out rawSignal : RawSignal;
    }

    port def DataOutPort {
        out processedData : ProcessedData;
    }

    port def PowerOutPort {
        out supplyVoltage : Voltage;
    }

    // ==================== Action Definitions ====================
    action def AcquireRawSignals {
        out rawUp : RawSignal;
        out rawDown : RawSignal;
    }

    action def ConvertSignal {
        in raw : RawSignal;
        in sensitivity : Sensitivity;
        in bodyTemp : Temperature;
        out irradiance : Irradiance;
    }

    action def ComputeNetIrradiance {
        in downward : Irradiance;
        in upward : Irradiance;
        out net : Irradiance;
    }

    action def ValidateMeasurement {
        in data : ProcessedData;
        out validatedData : ProcessedData;
        attribute minValid : Irradiance = -300 [W_per_m2];
        attribute maxValid : Irradiance = 1000 [W_per_m2];
    }

    action def StoreMeasurement {
        in data : ProcessedData;
    }

    // ==================== Part Definitions ====================
    part def Pyrgeometer {
        attribute orientation : String;
        attribute sensitivity : Sensitivity;
        attribute fieldOfView : Real;
        attribute spectralRangeMin : Real;
        attribute spectralRangeMax : Real;
        attribute responseTime : TimeDuration;

        port signalOut : RawSignalOutPort;
        port powerIn : ~PowerOutPort;

        action acquire : AcquireRawSignals;
    }

    part def SignalProcessor {
        attribute upSensitivity : Sensitivity;
        attribute downSensitivity : Sensitivity;
        attribute adcResolution : Integer;
        attribute processingDelay : TimeDuration;

        port upSignalIn : ~RawSignalOutPort;
        port downSignalIn : ~RawSignalOutPort;
        port dataOut : DataOutPort;
        port powerIn : ~PowerOutPort;

        action convertUp : ConvertSignal;
        action convertDown : ConvertSignal;
        action computeNet : ComputeNetIrradiance;
        action validate : ValidateMeasurement;
    }

    part def DataLogger {
        attribute samplingInterval : TimeDuration;
        attribute recordCount : Integer;
        attribute maxRecords : Integer;
        attribute storageCapacityMB : Integer;

        port dataIn : ~DataOutPort;
        port powerIn : ~PowerOutPort;

        action store : StoreMeasurement;
    }

    part def PowerSupply {
        attribute nominalVoltage : Voltage;
        attribute inputVoltageMin : Voltage;
        attribute inputVoltageMax : Voltage;
        attribute maxCurrent : Real;

        port powerOut1 : PowerOutPort;
        port powerOut2 : PowerOutPort;
        port powerOut3 : PowerOutPort;
        port powerOut4 : PowerOutPort;
    }

    // ==================== System Definition ====================
    part def NetRadiometerSystem {
        attribute systemId : String;
        attribute accuracySpec : Irradiance = 10 [W_per_m2];
        attribute responseTime95 : TimeDuration = 10 [s];
        attribute samplingInterval : TimeDuration = 1 [s];
        attribute minRange : Irradiance = -300 [W_per_m2];
        attribute maxRange : Irradiance = 1000 [W_per_m2];

        part pyrgeometerUp : Pyrgeometer {
            attribute orientation = "upward";
            attribute sensitivity = 1.0e-6;
            attribute fieldOfView = 180.0;
            attribute spectralRangeMin = 4.5;
            attribute spectralRangeMax = 42.0;
            attribute responseTime = 10 [s];
        }

        part pyrgeometerDown : Pyrgeometer {
            attribute orientation = "downward";
            attribute sensitivity = 1.0e-6;
            attribute fieldOfView = 180.0;
            attribute spectralRangeMin = 4.5;
            attribute spectralRangeMax = 42.0;
            attribute responseTime = 10 [s];
        }

        part signalProcessor : SignalProcessor {
            attribute upSensitivity = 1.0e-6;
            attribute downSensitivity = 1.0e-6;
            attribute adcResolution = 24;
            attribute processingDelay = 0.1 [s];
        }

        part dataLogger : DataLogger {
            attribute samplingInterval = 1 [s];
            attribute recordCount = 0;
            attribute maxRecords = 86400;
            attribute storageCapacityMB = 512;
        }

        part powerSupply : PowerSupply {
            attribute nominalVoltage = 12 [V];
            attribute inputVoltageMin = 10 [V];
            attribute inputVoltageMax = 24 [V];
            attribute maxCurrent = 2.0;
        }

        // ----- Signal connections -----
        connection pyrgeometerUp.signalOut to signalProcessor.upSignalIn;
        connection pyrgeometerDown.signalOut to signalProcessor.downSignalIn;
        connection signalProcessor.dataOut to dataLogger.dataIn;

        // ----- Power connections -----
        connection powerSupply.powerOut1 to pyrgeometerUp.powerIn;
        connection powerSupply.powerOut2 to pyrgeometerDown.powerIn;
        connection powerSupply.powerOut3 to signalProcessor.powerIn;
        connection powerSupply.powerOut4 to dataLogger.powerIn;

        // ----- State Machine -----
        stateMachine operation {
            state idle {
                entry {
                    /* Initialize sensors and await start command */
                }
            }

            state active {
                state acquiring {
                    entry {
                        /* Acquire raw voltage and temperature from both pyrgeometers */
                    }
                }

                state converting {
                    entry {
                        /* Convert raw voltages to irradiance using calibration sensitivity */
                    }
                }

                state computingNet {
                    entry {
                        /* Compute net irradiance as downward minus upward */
                    }
                }

                state validating {
                    entry {
                        /* Validate that measurement values fall within expected bounds */
                    }
                }

                state storing {
                    entry {
                        /* Store validated data record in the data logger */
                    }
                }

                transition acquiring to converting;
                transition converting to computingNet;
                transition computingNet to validating;
                transition validating to storing;
                transition storing to acquiring;
            }

            transition idle to active;
            transition active to idle;
        }
    }

    // ==================== Requirement Definitions ====================
    requirement def MeasurementAccuracyRequirement {
        doc /* The net radiometer system shall measure net irradiance with an accuracy of plus or minus 10 W/m2. */;
        attribute maxError : Irradiance = 10 [W_per_m2];
    }

    requirement def ResponseTimeRequirement {
        doc /* The system shall achieve 95 percent of the final reading within 10 seconds. */;
        attribute responseTime : TimeDuration = 10 [s];
        attribute settlingPercent : Real = 95.0;
    }

    requirement def MeasurementRangeRequirement {
        doc /* The system shall measure irradiance over the range minus 300 to plus 1000 W/m2. */;
        attribute minRange : Irradiance = -300 [W_per_m2];
        attribute maxRange : Irradiance = 1000 [W_per_m2];
    }

    requirement def DataStorageRequirement {
        doc /* The data logger shall store measurements at the defined sampling interval. */;
        attribute samplingInterval : TimeDuration = 1 [s];
    }

    requirement def PowerStabilityRequirement {
        doc /* The power supply shall provide regulated power to all electronic components. */;
        attribute nominalVoltage : Voltage = 12 [V];
    }

    requirement def ContinuousCycleRequirement {
        doc /* When active the system shall continuously cycle through acquisition, conversion, net computation, validation, and storage. */;
        attribute cyclePeriod : TimeDuration = 1 [s];
    }

    // ==================== Requirement Usages ====================
    requirement measurementAccuracy : MeasurementAccuracyRequirement {
        subject system : NetRadiometerSystem;
        assert { system.accuracySpec <= 10 [W_per_m2] }
    }

    requirement responseTime : ResponseTimeRequirement {
        subject system : NetRadiometerSystem;
        assert { system.responseTime95 <= 10 [s] }
    }

    requirement measurementRange : MeasurementRangeRequirement {
        subject system : NetRadiometerSystem;
        assert { system.minRange >= -300 [W_per_m2] && system.maxRange <= 1000 [W_per_m2] }
    }

    requirement dataStorage : DataStorageRequirement {
        subject logger : DataLogger;
        assert { logger.samplingInterval <= 1 [s] }
    }

    requirement powerStability : PowerStabilityRequirement {
        subject supply : PowerSupply;
        assert { supply.nominalVoltage == 12 [V] }
    }

    requirement continuousCycle : ContinuousCycleRequirement {
        subject system : NetRadiometerSystem;
        assert { system.samplingInterval <= 1 [s] }
    }
}
