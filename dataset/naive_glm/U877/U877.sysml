package ShockDataLoggerSystem {

    import ScalarValues::*;

    // ================================================================
    // Value Types
    // ================================================================

    value type AccelerationG :> Real {
        doc /* Acceleration measured in units of g (9.81 m/s^2) */;
    }

    value type FrequencyHz :> Real {
        doc /* Frequency measured in hertz */;
    }

    value type DurationMs :> Integer {
        doc /* Duration measured in milliseconds */;
    }

    value type DurationSec :> Real {
        doc /* Duration measured in seconds */;
    }

    value type VoltageV :> Real {
        doc /* Electric potential measured in volts */;
    }

    value type CurrentA :> Real {
        doc /* Electric current measured in amperes */;
    }

    value type BatteryPct :> Real {
        doc /* Battery state-of-charge as percentage, 0 to 100 */;
    }

    value type TimestampMs :> Integer {
        doc /* Millisecond-precision timestamp since device boot */;
    }

    value type EventIdType :> Integer {
        doc /* Monotonically increasing event identifier */;
    }

    value type TemperatureC :> Real {
        doc /* Temperature in degrees Celsius */;
    }

    // ================================================================
    // Enumeration Definitions
    // ================================================================

    enum def CommandType {
        DOWNLOAD;
        CONFIGURE;
        STATUS;
        ERASE;
    }

    // ================================================================
    // Item Definitions
    // ================================================================

    item def AccelSample {
        attribute x : AccelerationG;
        attribute y : AccelerationG;
        attribute z : AccelerationG;
        attribute timestamp : TimestampMs;
    }

    item def AccelProfile {
        attribute samples : AccelSample[0..*] = ();
    }

    item def ShockRecord {
        attribute id : EventIdType;
        attribute peakAcceleration : AccelerationG;
        attribute duration : DurationMs;
        attribute startTimestamp : TimestampMs;
        attribute profile : AccelProfile;
    }

    item def ConfigSettings {
        attribute shockThreshold : AccelerationG;
        attribute sampleFrequency : FrequencyHz;
    }

    item def Command {
        attribute type : CommandType;
        attribute settings : ConfigSettings;
    }

    item def Response {
        attribute records : ShockRecord[0..*] = ();
        attribute success : Boolean;
        attribute message : String;
    }

    item def PowerFlow {
        attribute voltage : VoltageV;
        attribute current : CurrentA;
    }

    // ================================================================
    // Port Definitions
    // ================================================================

    port def AccelDataOutPort {
        out sample : AccelSample;
    }

    port def AccelDataInPort {
        in sample : AccelSample;
    }

    port def RecordWriteOutPort {
        out record : ShockRecord;
    }

    port def RecordWriteInPort {
        in record : ShockRecord;
    }

    port def RecordsReadOutPort {
        out records : ShockRecord[0..*];
    }

    port def RecordsReadInPort {
        in records : ShockRecord[0..*];
    }

    port def PowerOutPort {
        out supply : PowerFlow;
    }

    port def PowerInPort {
        in supply : PowerFlow;
    }

    port def ConfigInPort {
        in config : ConfigSettings;
    }

    port def ConfigOutPort {
        out config : ConfigSettings;
    }

    port def DataOutPort {
        out records : ShockRecord[0..*];
    }

    port def DataInPort {
        in records : ShockRecord[0..*];
    }

    port def ExtCommPort {
        in command : Command;
        out response : Response;
    }

    // ================================================================
    // Part: Triaxial Accelerometer
    // ================================================================

    part def TriaxialAccelerometer {
        attribute sampleFrequency : FrequencyHz = 1000;
        attribute fullScaleRange : AccelerationG = 50;
        attribute noiseDensity : AccelerationG = 0.001;
        attribute axisCount : Integer = 3;

        port accelOut : AccelDataOutPort;
        port powerPort : PowerInPort;

        private attribute sampleCount : Integer = 0;
        private attribute operational : Boolean = true;

        action def TakeSample {
            out sample : AccelSample;
        }

        action def Calibrate {
        }

        state machine accelerometerStates {
            state Active {
                entry { sampleCount = 0; }
                do { perform TakeSample; }
            }
            state Inactive {
                entry { operational = false; }
            }
            state Calibrating {
                do { perform Calibrate; }
            }

            transition Active -> Inactive
                [powerPort.supply.voltage < 3.0];
            transition Inactive -> Active
                [powerPort.supply.voltage >= 3.0];
            transition Active -> Calibrating
                when calibrationRequested;
            transition Calibrating -> Active
                when calibrationComplete;
        }
    }

    // ================================================================
    // Part: Signal Processor
    // ================================================================

    part def SignalProcessor {
        attribute shockThreshold : AccelerationG = 5;
        attribute sampleRate : FrequencyHz = 1000;
        attribute eventCounter : EventIdType = 0;
        attribute windowSize : Integer = 100;

        port accelIn : AccelDataInPort;
        port memWrite : RecordWriteOutPort;
        port configIn : ConfigInPort;
        port dataOut : DataOutPort;
        port powerPort : PowerInPort;

        private attribute currentMagnitude : AccelerationG = 0;
        private attribute recording : Boolean = false;
        private attribute eventStartTime : TimestampMs = 0;
        private attribute currentProfile : AccelProfile;
        private attribute peakValue : AccelerationG = 0;

        action def ComputeMagnitude {
            in sample : AccelSample;
            out magnitude : AccelerationG;
        }

        action def DetectShock {
            in sample : AccelSample;
        }

        action def CaptureSample {
            in sample : AccelSample;
        }

        action def CreateEventRecord {
            out record : ShockRecord;
        }

        action def ApplyConfig {
            in config : ConfigSettings;
        }

        state machine processorStates {
            state Monitoring {
                entry { recording = false; }
                do {
                    perform ComputeMagnitude;
                    perform DetectShock;
                }
            }
            state ShockDetected {
                entry {
                    recording = true;
                    eventStartTime = accelIn.sample.timestamp;
                    currentProfile.samples = ();
                    peakValue = 0;
                    eventCounter = eventCounter + 1;
                }
            }
            state Recording {
                do { perform CaptureSample; }
            }
            state FinalizingRecord {
                do { perform CreateEventRecord; }
            }
            state Idle {
            }

            transition Monitoring -> ShockDetected
                [currentMagnitude > shockThreshold];
            transition ShockDetected -> Recording;
            transition Recording -> FinalizingRecord
                [currentMagnitude < shockThreshold];
            transition FinalizingRecord -> Monitoring
                when recordCreated;
            transition Monitoring -> Idle
                [powerPort.supply.voltage < 3.0];
            transition Idle -> Monitoring
                [powerPort.supply.voltage >= 3.0];
        }
    }

    // ================================================================
    // Part: Non-Volatile Memory
    // ================================================================

    part def NonVolatileMemory {
        attribute maxCapacity : Integer = 10000;
        attribute usedSpace : Integer = 0;
        attribute accessTime : DurationMs = 10;
        attribute enduranceCycles : Integer = 100000;

        port writePort : RecordWriteInPort;
        port readPort : RecordsReadOutPort;
        port powerPort : PowerInPort;

        private attribute storedRecords : ShockRecord[0..*] = ();

        action def WriteRecord {
            in record : ShockRecord;
        }

        action def ReadAllRecords {
            out records : ShockRecord[0..*];
        }

        action def EraseAll {
        }

        state machine memoryStates {
            state Ready {
            }
            state Writing {
                do { perform WriteRecord; }
            }
            state Reading {
                do { perform ReadAllRecords; }
            }
            state Full {
                guard { usedSpace >= maxCapacity; }
            }
            state Erasing {
                do { perform EraseAll; }
            }

            transition Ready -> Writing
                when writeRequested;
            transition Writing -> Ready
                when writeComplete;
            transition Ready -> Reading
                when readRequested;
            transition Reading -> Ready
                when readComplete;
            transition Ready -> Full
                [usedSpace >= maxCapacity];
            transition Full -> Erasing
                when eraseRequested;
            transition Erasing -> Ready
                when eraseComplete;
        }
    }

    // ================================================================
    // Part: Battery Unit
    // ================================================================

    part def BatteryUnit {
        attribute nominalVoltage : VoltageV = 3.6;
        attribute maxLevel : BatteryPct = 100;
        attribute currentLevel : BatteryPct = 100;
        attribute capacityMah : CurrentA = 2.0;
        attribute selfDischargePerDay : BatteryPct = 0.01;

        port powerOut : PowerOutPort;

        action def Discharge {
        }

        state machine batteryStates {
            state FullyCharged {
                guard { currentLevel >= 90; }
                entry { powerOut.supply.voltage = nominalVoltage; }
                do { perform Discharge; }
            }
            state Normal {
                guard { currentLevel >= 30 && currentLevel < 90; }
                entry { powerOut.supply.voltage = nominalVoltage; }
                do { perform Discharge; }
            }
            state LowPower {
                guard { currentLevel >= 10 && currentLevel < 30; }
                entry { powerOut.supply.voltage = nominalVoltage * 0.9; }
            }
            state Critical {
                guard { currentLevel < 10; }
                entry { powerOut.supply.voltage = nominalVoltage * 0.8; }
            }

            transition FullyCharged -> Normal
                [currentLevel < 90];
            transition Normal -> LowPower
                [currentLevel < 30];
            transition LowPower -> Critical
                [currentLevel < 10];
            transition Normal -> FullyCharged
                [currentLevel >= 90];
            transition LowPower -> Normal
                [currentLevel >= 30];
            transition Critical -> LowPower
                [currentLevel >= 10];
        }
    }

    // ================================================================
    // Part: Communication Module
    // ================================================================

    part def CommunicationModule {
        attribute baudRate : Integer = 115200;
        attribute protocol : String = "UART";
        attribute bufferSize : Integer = 4096;

        port external : ExtCommPort;
        port toProcessorConfig : ConfigOutPort;
        port toProcessorData : DataInPort;
        port fromMemory : RecordsReadInPort;
        port powerPort : PowerInPort;

        private attribute connected : Boolean = false;
        private attribute transferProgress : Integer = 0;

        action def ReceiveCommand {
            out command : Command;
        }

        action def SendResponse {
            in response : Response;
        }

        action def DownloadRecords {
        }

        action def ApplyConfiguration {
            in config : ConfigSettings;
        }

        action def GetStatus {
            out response : Response;
        }

        state machine commStates {
            state Disconnected {
                entry { connected = false; }
            }
            state Connected {
                entry { connected = true; }
                do { perform ReceiveCommand; }
            }
            state Transferring {
                entry { transferProgress = 0; }
                do {
                    perform DownloadRecords;
                    perform SendResponse;
                }
            }
            state Configuring {
                do { perform ApplyConfiguration; }
            }
            state StatusQuery {
                do { perform GetStatus; }
            }

            transition Disconnected -> Connected
                when external.command received;
            transition Connected -> Transferring
                [external.command.type == CommandType::DOWNLOAD];
            transition Connected -> Configuring
                [external.command.type == CommandType::CONFIGURE];
            transition Connected -> StatusQuery
                [external.command.type == CommandType::STATUS];
            transition Transferring -> Connected
                when transferComplete;
            transition Configuring -> Connected
                when configApplied;
            transition StatusQuery -> Connected
                when statusSent;
            transition Connected -> Disconnected
                when connectionLost;
        }
    }

    // ================================================================
    // Part: Shock Data Logger (Top-Level System)
    // ================================================================

    part def ShockDataLogger {
        attribute deviceId : String;
        attribute firmwareVersion : String = "1.0";
        attribute serialNumber : String;
        attribute manufactureDate : TimestampMs;
        attribute housingRating : String = "IP67";
        attribute operatingTempMin : TemperatureC = -20;
        attribute operatingTempMax : TemperatureC = 70;

        port externalInterface : ExtCommPort;

        part accelerometer : TriaxialAccelerometer;
        part processor : SignalProcessor;
        part memory : NonVolatileMemory;
        part battery : BatteryUnit;
        part communication : CommunicationModule;

        // --- Internal connections: sensor data path ---
        connect accelerometer.accelOut to processor.accelIn;

        // --- Internal connections: processor to memory ---
        connect processor.memWrite to memory.writePort;

        // --- Internal connections: processor to communication ---
        connect processor.dataOut to communication.toProcessorData;
        connect communication.toProcessorConfig to processor.configIn;

        // --- Internal connections: communication to memory ---
        connect communication.fromMemory to memory.readPort;

        // --- Internal connections: power distribution ---
        connect battery.powerOut to accelerometer.powerPort;
        connect battery.powerOut to processor.powerPort;
        connect battery.powerOut to memory.powerPort;
        connect battery.powerOut to communication.powerPort;

        // --- External interface ---
        connect communication.external to externalInterface;
    }

    // ================================================================
    // Requirements
    // ================================================================

    requirement def ShockMonitoringRequirement {
        doc /* The system shall continuously monitor triaxial acceleration
             at high frequency to detect potentially damaging events. */;
        attribute minSampleFrequency : FrequencyHz;
        attribute measurementRange : AccelerationG;
        attribute axisCount : Integer;
    }

    requirement def ShockDetectionRequirement {
        doc /* The system shall identify a shock event when the computed
             acceleration magnitude exceeds a user-configurable threshold. */;
        attribute defaultThreshold : AccelerationG;
        attribute thresholdConfigurable : Boolean;
    }

    requirement def EventRecordingRequirement {
        doc /* Upon detecting a shock event, the system shall capture the
             full acceleration profile and persist a structured ShockRecord
             in non-volatile memory. The record shall include a unique ID,
             peak acceleration, duration, timestamp, and complete profile data. */;
        attribute minRecordCount : Integer;
        attribute recordFields : String;
    }

    requirement def PowerManagementRequirement {
        doc /* The system shall be powered by an internal battery with
             power-state management to maximize unattended operating life. */;
        attribute minOperatingDays : Integer;
        attribute minPowerStates : Integer;
    }

    requirement def CommunicationRequirement {
        doc /* The system shall provide an external interface for downloading
             stored shock records and updating device configuration. */;
        attribute supportedCommandTypes : Integer;
    }

    requirement shockMonitoringReq : ShockMonitoringRequirement {
        :>> minSampleFrequency = 1000;
        :>> measurementRange = 50;
        :>> axisCount = 3;
    }

    requirement shockDetectionReq : ShockDetectionRequirement {
        :>> defaultThreshold = 5;
        :>> thresholdConfigurable = true;
    }

    requirement eventRecordingReq : EventRecordingRequirement {
        :>> minRecordCount = 10000;
        :>> recordFields = "id, peakAcceleration, duration, startTimestamp, profile";
    }

    requirement powerMgmtReq : PowerManagementRequirement {
        :>> minOperatingDays = 365;
        :>> minPowerStates = 4;
    }

    requirement communicationReq : CommunicationRequirement {
        :>> supportedCommandTypes = 4;
    }

    // ================================================================
    // Requirement Allocations
    // ================================================================

    satisfy shockMonitoringReq by ShockDataLogger::accelerometer;
    satisfy shockDetectionReq by ShockDataLogger::processor;
    satisfy eventRecordingReq by ShockDataLogger::memory;
    satisfy powerMgmtReq by ShockDataLogger::battery;
    satisfy communicationReq by ShockDataLogger::communication;

}
