package ActigraphySystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;
    private import SequenceFunctions::*;

    enum def SleepPhase {
        Awake;
        Light;
        Deep;
        REM;
    }

    enum def WatchMode {
        Recording;
        Idle;
        Downloading;
        Charging;
    }

    attribute def ActivityCount :> Real;

    item def EpochData {
        attribute startTime :> ISQ::time;
        attribute activityCount : ActivityCount;
        attribute phase : SleepPhase;
    }

    item def SleepAnalysisReport {
        attribute totalSleepTime :> ISQ::time;
        attribute sleepEfficiency :> Real;
        attribute timeInLight :> ISQ::time;
        attribute timeInDeep :> ISQ::time;
        attribute timeInREM :> ISQ::time;
        attribute timeAwake :> ISQ::time;
    }

    port def MotionDataPort {
        out accelerationX :> ISQ::acceleration;
        out accelerationY :> ISQ::acceleration;
        out accelerationZ :> ISQ::acceleration;
    }

    port def EpochDataPort {
        inout epochData : EpochData[*];
    }

    port def PowerPort {
        in power :> ISQ::power;
    }

    port def ReportPort {
        out report : SleepAnalysisReport;
    }

    calc def CalculateActivityCount {
        in ax :> ISQ::acceleration;
        in ay :> ISQ::acceleration;
        in az :> ISQ::acceleration;
        return : ActivityCount = ax * ax + ay * ay + az * az;
    }

    calc def ClassifySleepPhase {
        in count : ActivityCount;
        in timeOfDay :> ISQ::time;
        return : SleepPhase;
    }

    action def ProcessEpoch {
        in ax :> ISQ::acceleration;
        in ay :> ISQ::acceleration;
        in az :> ISQ::acceleration;
        in time :> ISQ::time;
        attribute count : ActivityCount = CalculateActivityCount(ax, ay, az);
        attribute phase : SleepPhase = ClassifySleepPhase(count, time);
        out data : EpochData;
    }

    action def AnalyzeSleep {
        in data : EpochData[*];
        in epochDuration :> ISQ::time;
        attribute totalRecordingTime :> ISQ::time = data->size() * epochDuration;
        attribute sleepEpochs : EpochData[*] = data->select(e | e.phase <> SleepPhase::Awake);
        attribute totalSleepTime :> ISQ::time = sleepEpochs->size() * epochDuration;
        attribute timeInLight :> ISQ::time = sleepEpochs->select(e | e.phase == SleepPhase::Light)->size() * epochDuration;
        attribute timeInDeep :> ISQ::time = sleepEpochs->select(e | e.phase == SleepPhase::Deep)->size() * epochDuration;
        attribute timeInREM :> ISQ::time = sleepEpochs->select(e | e.phase == SleepPhase::REM)->size() * epochDuration;
        attribute timeAwake :> ISQ::time = totalRecordingTime - totalSleepTime;
        attribute sleepEfficiency :> Real = (totalSleepTime / totalRecordingTime) * 100.0;
        out report : SleepAnalysisReport;
    }

    requirement def BatteryLifeRequirement {
        doc /* The watch battery shall provide at least two weeks of continuous recording on a single charge. */
        subject watch : ActigraphyWatch;
        constraint { watch.battery.maxLife >= 14 [d] }
    }

    requirement def MemoryCapacityRequirement {
        doc /* The watch internal memory shall store at least several weeks of continuous epoch recordings. */
        subject watch : ActigraphyWatch;
        constraint { watch.memory.capacity >= 21 [d] }
    }

    requirement def SleepAnalysisRequirement {
        doc /* The analysis software shall calculate total sleep time, sleep efficiency, and time spent in each sleep stage. */
        subject software : AnalysisSoftware;
    }

    part def TriAxialAccelerometer {
        port motionOut : MotionDataPort;
    }

    part def Processor {
        port motionIn : MotionDataPort;
        port epochOut : EpochDataPort;
        attribute epochDuration :> ISQ::time = 60 [s];
    }

    part def InternalMemory {
        port dataIn : EpochDataPort;
        port dataOut : EpochDataPort;
        attribute capacity :> ISQ::time = 28 [d];
        attribute storedData : EpochData[*];
    }

    part def RechargeableBattery {
        port powerIn : PowerPort;
        attribute chargeLevel :> Real;
        attribute maxLife :> ISQ::time = 14 [d];
        attribute capacity :> ISQ::energy;
    }

    part def SiliconeStrap {
        attribute material : String = "Medical-grade silicone";
    }

    part def ActigraphyWatch {
        attribute mode : WatchMode;

        part strap : SiliconeStrap;
        part accelerometer : TriAxialAccelerometer;
        part processor : Processor;
        part memory : InternalMemory;
        part battery : RechargeableBattery;

        port dataPort : EpochDataPort;
        port chargingPort : PowerPort;

        connect accelerometer.motionOut to processor.motionIn;
        connect processor.epochOut to memory.dataIn;
        connect memory.dataOut to dataPort;
        connect chargingPort to battery.powerIn;

        state machine def WatchBehavior {
            entry; then Recording;

            state Recording;
            state Idle;
            state Downloading;
            state Charging;

            transition from Recording to Idle;
            transition from Idle to Recording;
            transition from Recording to Downloading;
            transition from Idle to Downloading;
            transition from Downloading to Idle;
            transition from Idle to Charging;
            transition from Charging to Idle;
        }

        perform WatchBehavior;

        satisfy BatteryLifeRequirement;
        satisfy MemoryCapacityRequirement;
    }

    part def AnalysisSoftware {
        port dataIn : EpochDataPort;
        port reportOut : ReportPort;
        attribute epochDuration :> ISQ::time = 60 [s];

        satisfy SleepAnalysisRequirement;
    }

    part def AnalysisWorkstation {
        part software : AnalysisSoftware;
        port dataPort : EpochDataPort;
        port reportPort : ReportPort;

        connect dataPort to software.dataIn;
        connect software.reportOut to reportPort;
    }

    connection def DataTransferLink {
        end source : EpochDataPort;
        end target : EpochDataPort;
    }

    part actigraphySystem {
        part watch : ActigraphyWatch;
        part workstation : AnalysisWorkstation;

        connection dataLink : DataTransferLink connect watch.dataPort to workstation.dataPort;
    }

    analysis def SleepAnalysisProcess {
        subject watch : ActigraphyWatch;
        subject workstation : AnalysisWorkstation;

        return attribute finalReport : SleepAnalysisReport;

        perform action analyze : AnalyzeSleep {
            in data = watch.memory.storedData;
            in epochDuration = 60 [s];
        }
        then assign finalReport := analyze.report;
    }
}
