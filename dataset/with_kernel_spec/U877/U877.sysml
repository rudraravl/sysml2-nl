package ShockDataLogger {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package Definitions {
        attribute def AccelerationSample {
            attribute time :> ISQ::time;
            attribute ax :> ISQ::acceleration;
            attribute ay :> ISQ::acceleration;
            attribute az :> ISQ::acceleration;
        }

        attribute def ShockEventRecord {
            attribute id : ScalarValues::Integer;
            attribute peakAcceleration :> ISQ::acceleration;
            attribute duration :> ISQ::time;
            attribute timestamp : Time::DateTime;
            attribute samples : AccelerationSample[*];
        }

        attribute def 'PowerOnSignal';
        attribute def 'ShockDetectedSignal';
        attribute def 'EventStoredSignal';
        attribute def 'RechargeSignal';
        attribute def 'DownloadRequest';
        attribute def 'ThresholdUpdate' {
            attribute threshold :> ISQ::acceleration;
        }

        port def RawAccelerationPort {
            out sample : AccelerationSample;
        }
        port def ShockEventPort {
            out record : ShockEventRecord;
        }
        port def DataConfigPort {
            in downloadRequest : DownloadRequest;
            out records : ShockEventRecord[*];
            in thresholdUpdate : ThresholdUpdate;
        }
        port def PowerPort {
            out voltage : ISQ::ElectricPotentialValue;
            out chargeLevel : Real;
        }

        connection def RawAccelerationConnection {
            end port source : RawAccelerationPort;
            end port target : ~RawAccelerationPort;
        }
        connection def ShockEventConnection {
            end port source : ShockEventPort;
            end port target : ~ShockEventPort;
        }
        connection def DataConfigConnection {
            end port source : DataConfigPort;
            end port target : ~DataConfigPort;
        }
        connection def PowerConnection {
            end port source : PowerPort;
            end port target : ~PowerPort;
        }

        action def MeasureAcceleration {
            out sample : AccelerationSample;
        }
        action def ProcessAcceleration {
            in sample : AccelerationSample;
            in threshold :> ISQ::acceleration;
            out magnitude :> ISQ::acceleration;
            out isShock : Boolean;
        }
        action def RecordShockEvent {
            in magnitude :> ISQ::acceleration;
            out record : ShockEventRecord;
        }
        action def StoreRecord {
            in record : ShockEventRecord;
        }
        action def DownloadRecords {
            out records : ShockEventRecord[*];
        }
        action def ConfigureThreshold {
            in newThreshold :> ISQ::acceleration;
        }

        state def SignalProcessorStates;
        state def BatteryStates {
            in chargeLevel : Real;
            entry; then charged;
            state charged;
            accept when chargeLevel < 0.3 then normal;
            state normal;
            accept when chargeLevel < 0.1 then low;
            state low;
            accept when chargeLevel <= 0.0 then depleted;
            state depleted;
        }

        part def TriaxialAccelerometer {
            attribute sampleRate :> ISQ::frequency;
            port rawOut : RawAccelerationPort;
            port powerIn : ~PowerPort;
            perform action 'measure acceleration' : MeasureAcceleration;
        }

        part def SignalProcessor {
            attribute shockThreshold :> ISQ::acceleration;
            port rawIn : ~RawAccelerationPort;
            port eventOut : ShockEventPort;
            port configIn : ~DataConfigPort;
            port powerIn : ~PowerPort;
            perform action 'process acceleration' : ProcessAcceleration;
            perform action 'record shock event' : RecordShockEvent;
            perform action 'download records' : DownloadRecords;
            perform action 'configure threshold' : ConfigureThreshold;
            exhibit state processorStates : SignalProcessorStates;
        }

        part def NonVolatileMemory {
            attribute maxRecords : ScalarValues::Integer := 10000;
            attribute storedRecords : ShockEventRecord[*] := ();
            port eventIn : ~ShockEventPort;
            port powerIn : ~PowerPort;
            perform action 'store record' : StoreRecord;
        }

        part def BatteryUnit {
            attribute chargeLevel : ScalarValues::Real := 1.0;
            port powerOut : PowerPort;
            exhibit state batteryStates : BatteryStates {
                in chargeLevel = chargeLevel;
            }
        }

        part def CommunicationModule {
            port dataPort : DataConfigPort;
            port powerIn : ~PowerPort;
            perform action 'download records' : DownloadRecords;
            perform action 'configure threshold' : ConfigureThreshold;
        }

        part def ShockDataLoggerDevice {
            part accelerometer : TriaxialAccelerometer;
            part processor : SignalProcessor;
            part memory : NonVolatileMemory;
            part battery : BatteryUnit;
            part commModule : CommunicationModule;

            connection accelToProcessor : RawAccelerationConnection {
                end port src : RawAccelerationPort ::> accelerometer.rawOut;
                end port tgt : ~RawAccelerationPort ::> processor.rawIn;
            }
            connection processorToMemory : ShockEventConnection {
                end port src : ShockEventPort ::> processor.eventOut;
                end port tgt : ~ShockEventPort ::> memory.eventIn;
            }
            connection commToProcessor : DataConfigConnection {
                end port src : DataConfigPort ::> commModule.dataPort;
                end port tgt : ~DataConfigPort ::> processor.configIn;
            }
            connection powerToAccel : PowerConnection {
                end port src : PowerPort ::> battery.powerOut;
                end port tgt : ~PowerPort ::> accelerometer.powerIn;
            }
            connection powerToProcessor : PowerConnection {
                end port src : PowerPort ::> battery.powerOut;
                end port tgt : ~PowerPort ::> processor.powerIn;
            }
            connection powerToMemory : PowerConnection {
                end port src : PowerPort ::> battery.powerOut;
                end port tgt : ~PowerPort ::> memory.powerIn;
            }
            connection powerToComm : PowerConnection {
                end port src : PowerPort ::> battery.powerOut;
                end port tgt : ~PowerPort ::> commModule.powerIn;
            }
        }

        requirement def StorageCapacityRequirement {
            doc /* The non-volatile memory shall store at least 10000 shock event records. */
            attribute minimumRecords : ScalarValues::Integer := 10000;
        }
        requirement def SamplingRateRequirement {
            doc /* The accelerometer shall sample at a rate of at least 1000 Hz. */
            attribute minimumSampleRate :> ISQ::frequency;
        }
        requirement def BatteryLifeRequirement {
            doc /* The battery shall provide continuous operation for at least 30 days. */
            attribute minimumOperatingDays : ScalarValues::Real := 30.0;
        }
        requirement def ShockDetectionRequirement {
            doc /* The system shall detect shock events with peak acceleration above the configurable threshold. */
            attribute threshold :> ISQ::acceleration;
        }
    }

    package Usages {
        private import Definitions::*;

        part logger : ShockDataLoggerDevice;

        action 'measure acceleration' : MeasureAcceleration;
        action 'process acceleration' : ProcessAcceleration;
        action 'record shock event' : RecordShockEvent;
        action 'store record' : StoreRecord;
        action 'download records' : DownloadRecords;
        action 'configure threshold' : ConfigureThreshold;

        state 'processor states' : SignalProcessorStates {
            entry; then idle;
            state idle;
            accept 'PowerOnSignal' then monitoring;
            state monitoring {
                do 'process acceleration';
            }
            accept 'ShockDetectedSignal' then capturing;
            state capturing {
                do 'record shock event';
            }
            accept 'EventStoredSignal' then monitoring;
        }

        state 'battery states' : BatteryStates {
            in chargeLevel = logger.battery.chargeLevel;
        }

        requirement storageReq : StorageCapacityRequirement;
        requirement samplingReq : SamplingRateRequirement;
        requirement batteryReq : BatteryLifeRequirement;
        requirement shockReq : ShockDetectionRequirement;
    }
}
