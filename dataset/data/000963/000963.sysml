package ActigraphySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def AccelerationMagnitude :> Real;
    attribute def ActivityCountValue :> Integer;
    attribute def EpochDurationValue :> DurationValue;
    attribute def SleepEfficiencyValue :> Real;

    enum def SleepPhase {
        awake;
        light;
        deep;
        rem;
    }

    enum def DeviceMode {
        idle;
        recording;
        downloading;
        charging;
    }

    item def AccelerationSample {
        attribute timestamp : String;
        attribute xAxis : AccelerationMagnitude;
        attribute yAxis : AccelerationMagnitude;
        attribute zAxis : AccelerationMagnitude;
    }

    item def ActivityEpoch {
        attribute startTime : String;
        attribute duration : EpochDurationValue;
        attribute activityCount : ActivityCountValue;
        attribute sleepPhase : SleepPhase;
    }

    item def SleepAnalysisReport {
        attribute totalSleepTime : DurationValue;
        attribute sleepEfficiency : SleepEfficiencyValue;
        attribute wakeAfterSleepOnset : DurationValue;
        attribute sleepLatency : DurationValue;
        attribute remPercentage : Real;
        attribute deepSleepPercentage : Real;
    }

    port def AccelDataPort {
        out samples : AccelerationSample[*];
    }

    port def ProcessedDataPort {
        out epochs : ActivityEpoch[*];
    }

    port def AnalysisPort {
        in epochData : ActivityEpoch[*];
        out report : SleepAnalysisReport;
    }

    part def TriaxialAccelerometer {
        attribute samplingRate : FrequencyValue = 32 [Hz];
        attribute sensitivity : AccelerationValue = 0.001 [m/s^2];
        attribute range : AccelerationValue = 8.0 [m/s^2];
        
        port dataOutput : AccelDataPort;

        action def SampleAcceleration {
            out sample : AccelerationSample;
        }
    }

    part def DataProcessor {
        attribute epochLength : DurationValue = 60 [s];
        
        port accelInput {
            in samples : AccelerationSample[*];
        }
        port epochOutput : ProcessedDataPort;

        action def ComputeActivityCount {
            in rawSamples : AccelerationSample[*];
            out activityCount : ActivityCountValue;
        }

        action def ClassifyEpoch {
            in activityCount : ActivityCountValue;
            in timeOfDay : String;
            out phase : SleepPhase;
        }
    }

    part def MemoryStorage {
        attribute capacity : Real = 512.0;
        attribute recordedDays : DurationValue;
        
        port dataInput {
            in epochs : ActivityEpoch[*];
        }
    }

    part def RechargeableBattery {
        attribute capacity : Real = 300.0;
        attribute voltage : ElectricPotentialValue = 3.7 [V];
        attribute currentCharge : Real;
        attribute minOperatingCharge : Real = 30.0;
    }

    part def WristStrap {
        attribute material : String = "medical-grade silicone";
        attribute adjustable : Boolean = true;
    }

    action def MonitorActivity {
        first start;
        then merge continuousLoop;

        then action sampleMotion {
            out accelSample : AccelerationSample;
        }

        then action computeActivity {
            in rawSamples : AccelerationSample[*];
            out counts : ActivityCountValue;
        }

        then action classifySleep {
            in activityCount : ActivityCountValue;
            in timeOfDay : String;
            out sleepPhase : SleepPhase;
        }

        then action storeEpoch {
            in epochData : ActivityEpoch;
        }

        then continuousLoop;
    }

    action def TransferStoredData {
        in storedEpochs : ActivityEpoch[*];
        out transferredData : ActivityEpoch[*];
    }

    action def ChargeBattery {
        inout batteryCharge : Real;
    }

    part def ActigraphyWatchDevice {
        attribute deviceID : String;
        attribute firmwareVersion : String = "3.2.1";

        part accelerometer : TriaxialAccelerometer;
        part processor : DataProcessor;
        part memory : MemoryStorage;
        part battery : RechargeableBattery;
        part strap : WristStrap;

        port sensorPort :>> accelerometer.dataOutput;
        port dataPort :>> processor.epochOutput;

        connection accelToProcessor connect accelerometer.dataOutput to processor.accelInput;
        connection processorToMemory connect processor.epochOutput to memory.dataInput;

        state def DeviceStateMachine {
            entry; then idle;

            state idle;

            state recording {
                do action continuousMonitoring : MonitorActivity;
            }

            state downloading {
                do action transferData : TransferStoredData;
            }

            state charging {
                do action recharge : ChargeBattery;
            }

            transition idle_to_recording
                first idle
                accept StartRecording
                then recording;

            transition recording_to_downloading
                first recording
                accept DownloadRequest
                then downloading;

            transition downloading_to_idle
                first downloading
                accept DownloadComplete
                then idle;

            transition recording_to_charging
                first recording
                accept LowBattery
                then charging;

            transition charging_to_idle
                first charging
                accept FullyCharged
                then idle;

            transition idle_to_charging
                first idle
                accept ChargeConnected
                then charging;
        }

        exhibit state deviceStates : DeviceStateMachine;
    }

    part def AnalysisWorkstation {
        attribute softwareVersion : String = "4.1.0";

        port dataInput : AnalysisPort;

        action def AnalyzeSleepPatterns {
            in epochSequence : ActivityEpoch[*];
            out sleepReport : SleepAnalysisReport;

            first start;
            then action identifySleepPeriods {
                in epochs : ActivityEpoch[*];
                out sleepOnset : String;
                out sleepOffset : String;
            }

            then action calculateMetrics {
                in sleepStart : String;
                in sleepEnd : String;
                in allEpochs : ActivityEpoch[*];
                out totalSleep : DurationValue;
                out efficiency : SleepEfficiencyValue;
                out waso : DurationValue;
                out latency : DurationValue;
            }

            then action generateReport {
                out report : SleepAnalysisReport;
            }

            then done;
        }
    }

    part def ActigraphyMonitoringSystem {
        part wearableDevice : ActigraphyWatchDevice {
            attribute :>> deviceID = "ACT-2024-7821";
        }

        part analysisStation : AnalysisWorkstation;

        connection deviceToStation connect wearableDevice.dataPort to analysisStation.dataInput;
    }

    requirement def SystemObjective {
        doc /* The actigraphy system shall continuously monitor and objectively 
             * quantify rest-activity patterns and sleep-wake cycles through 
             * wrist-worn accelerometry for clinical assessment and research. */
        subject system : ActigraphyMonitoringSystem;
    }

    requirement <'REQ-ACT-100'> continuousMonitoring {
        doc /* The actigraphy device shall continuously record tri-axial 
             * acceleration data at a minimum sampling rate of 32 Hz. */
        subject device : ActigraphyWatchDevice;
        
        assert constraint {
            device.accelerometer.samplingRate >= 32 [Hz]
        }
    }

    requirement <'REQ-ACT-101'> dataRetention {
        doc /* The device shall store at least 30 days of continuous 
             * activity data at 60-second epoch resolution. */
        subject storage : MemoryStorage;
        
        assert constraint {
            storage.capacity >= 256.0
        }
    }

    requirement <'REQ-ACT-102'> batteryEndurance {
        doc /* The device shall operate continuously for at least 14 days 
             * on a single full charge under normal monitoring conditions. */
        subject battery : RechargeableBattery;
        
        assert constraint {
            battery.capacity >= 300.0
        }
    }

    requirement <'REQ-ACT-103'> wearComfort {
        doc /* The device shall be designed for comfortable continuous wear 
             * on the wrist during sleep and daily activities. */
        subject device : ActigraphyWatchDevice;
    }

    part actigraphySystem : ActigraphyMonitoringSystem;

    satisfy SystemObjective by actigraphySystem;
    satisfy continuousMonitoring by actigraphySystem.wearableDevice;
    satisfy dataRetention by actigraphySystem.wearableDevice.memory;
    satisfy batteryEndurance by actigraphySystem.wearableDevice.battery;
    satisfy wearComfort by actigraphySystem.wearableDevice;
}
