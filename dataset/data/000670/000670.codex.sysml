package LungCounterSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Count;
    attribute def Percentage;
    attribute def FlowRate;
    attribute def Pressure;
    attribute def Volume;
    attribute def Time;
    attribute def Frequency;
    attribute def Boolean;

    value type BreathCount specializes Count;
    value type BreathRate specializes Frequency {
        unit = "breath/min";
    }
    value type AirFlowRate specializes FlowRate {
        unit = "L/min";
    }
    value type AirwayPressure specializes Pressure {
        unit = "cmH2O";
    }
    value type LungVolume specializes Volume {
        unit = "L";
    }
    value type OxygenSaturation specializes Percentage {
        unit = "%";
    }
    value type SamplePeriod specializes Time {
        unit = "ms";
    }
    value type BatteryCharge specializes Percentage {
        unit = "%";
    }

    item def AirFlowSample {
        attribute flow: AirFlowRate;
        attribute pressure: AirwayPressure;
        attribute sampleTime: Time;
    }

    item def BreathEvent {
        attribute eventTime: Time;
        attribute tidalVolume: LungVolume;
        attribute peakInspiratoryFlow: AirFlowRate;
        attribute peakExpiratoryFlow: AirFlowRate;
        attribute validBreath: Boolean;
    }

    item def LungCounterReading {
        attribute totalBreaths: BreathCount;
        attribute currentBreathRate: BreathRate;
        attribute averageTidalVolume: LungVolume;
        attribute sessionDuration: Time;
        attribute signalQuality: Percentage;
    }

    item def UserCommand {
        attribute resetRequested: Boolean;
        attribute startRequested: Boolean;
        attribute stopRequested: Boolean;
    }

    item def AlertSignal {
        attribute lowBattery: Boolean;
        attribute highBreathRate: Boolean;
        attribute lowBreathRate: Boolean;
        attribute sensorFault: Boolean;
        attribute poorSeal: Boolean;
    }

    port def FlowSensorPort {
        out sample: AirFlowSample;
    }

    port def BreathEventPort {
        out breath: BreathEvent;
    }

    port def ReadingPort {
        out reading: LungCounterReading;
    }

    port def CommandPort {
        in command: UserCommand;
    }

    port def AlertPort {
        out alert: AlertSignal;
    }

    port def PowerPort {
        in charge: BatteryCharge;
    }

    part def LungCounter {
        attribute totalBreathCount: BreathCount = 0;
        attribute breathRate: BreathRate = 0 ["breath/min"];
        attribute averageTidalVolume: LungVolume = 0 ["L"];
        attribute sessionElapsedTime: Time = 0 ["s"];
        attribute minimumValidFlow: AirFlowRate = 3 ["L/min"];
        attribute maximumPhysiologicalRate: BreathRate = 60 ["breath/min"];
        attribute minimumPhysiologicalRate: BreathRate = 4 ["breath/min"];
        attribute sampleInterval: SamplePeriod = 20 ["ms"];
        attribute batteryRemaining: BatteryCharge = 100 ["%"];

        port flowInput: FlowSensorPort;
        port commandInput: CommandPort;
        port readingOutput: ReadingPort;
        port alertOutput: AlertPort;
        port powerInput: PowerPort;

        part flowSensor: DifferentialFlowSensor;
        part breathDetector: BreathDetectionProcessor;
        part counter: BreathCounter;
        part rateEstimator: BreathRateEstimator;
        part display: ReadingDisplay;
        part alarmManager: AlarmManager;
        part powerManager: PowerManager;
        part userInterface: UserInterface;

        connect flowSensor.samplePort to breathDetector.sampleInput;
        connect breathDetector.breathOutput to counter.breathInput;
        connect breathDetector.breathOutput to rateEstimator.breathInput;
        connect counter.countOutput to display.countInput;
        connect rateEstimator.rateOutput to display.rateInput;
        connect display.readingOutput to readingOutput;
        connect userInterface.commandOutput to commandInput;
        connect commandInput to counter.commandInput;
        connect commandInput to rateEstimator.commandInput;
        connect powerInput to powerManager.powerInput;
        connect powerManager.alertOutput to alarmManager.powerAlertInput;
        connect breathDetector.alertOutput to alarmManager.sensorAlertInput;
        connect rateEstimator.alertOutput to alarmManager.rateAlertInput;
        connect alarmManager.alertOutput to alertOutput;

        perform action countLungBreaths;
        exhibit state lungCounterOperatingStates;
    }

    part def DifferentialFlowSensor {
        attribute measuredFlow: AirFlowRate;
        attribute measuredPressure: AirwayPressure;
        attribute signalQuality: Percentage;
        attribute zeroOffset: AirFlowRate = 0 ["L/min"];

        port samplePort: FlowSensorPort;

        action acquireFlowSample {
            in rawPressure: AirwayPressure;
            out sample: AirFlowSample;

            first startSampling;
            then compensateZeroOffset;
            then convertPressureToFlow;
            then publishSample;

            action startSampling;
            action compensateZeroOffset;
            action convertPressureToFlow;
            action publishSample;
        }
    }

    part def BreathDetectionProcessor {
        attribute inspirationThreshold: AirFlowRate = 3 ["L/min"];
        attribute expirationThreshold: AirFlowRate = -3 ["L/min"];
        attribute minimumTidalVolume: LungVolume = 0.05 ["L"];
        attribute integratedVolume: LungVolume = 0 ["L"];
        attribute breathInProgress: Boolean = false;
        attribute sensorHealthy: Boolean = true;

        port sampleInput {
            in sample: AirFlowSample;
        }

        port breathOutput: BreathEventPort;
        port alertOutput: AlertPort;

        action detectBreath {
            in sample: AirFlowSample;
            out breath: BreathEvent;

            first filterFlowSignal;
            then identifyInspiratoryPhase;
            then integrateFlowToVolume;
            then identifyExpiratoryPhase;
            then validateCompleteBreath;
            then emitBreathEvent;

            action filterFlowSignal;
            action identifyInspiratoryPhase;
            action integrateFlowToVolume;
            action identifyExpiratoryPhase;
            action validateCompleteBreath;
            action emitBreathEvent;
        }

        state breathDetectionStates {
            entry; then WaitingForInspiration;

            state WaitingForInspiration;
            state InspirationDetected;
            state ExpirationDetected;
            state BreathValidated;
            state SensorFault;

            transition WaitingForInspiration_to_InspirationDetected
                first WaitingForInspiration
                accept sample
                if sample.flow > inspirationThreshold
                then InspirationDetected;

            transition InspirationDetected_to_ExpirationDetected
                first InspirationDetected
                accept sample
                if sample.flow < expirationThreshold
                then ExpirationDetected;

            transition ExpirationDetected_to_BreathValidated
                first ExpirationDetected
                if integratedVolume >= minimumTidalVolume
                then BreathValidated;

            transition BreathValidated_to_WaitingForInspiration
                first BreathValidated
                then WaitingForInspiration;

            transition Any_to_SensorFault
                first WaitingForInspiration
                accept sample
                if sample.signalQuality < 40 ["%"]
                then SensorFault;

            transition SensorFault_to_WaitingForInspiration
                first SensorFault
                accept sample
                if sample.signalQuality >= 70 ["%"]
                then WaitingForInspiration;
        }
    }

    part def BreathCounter {
        attribute count: BreathCount = 0;
        attribute lastBreathTime: Time = 0 ["s"];

        port breathInput {
            in breath: BreathEvent;
        }

        port commandInput: CommandPort;

        port countOutput {
            out count: BreathCount;
        }

        action updateCount {
            in breath: BreathEvent;
            out count: BreathCount;

            first checkBreathValidity;
            then incrementWhenValid;
            then publishCount;

            action checkBreathValidity;
            action incrementWhenValid;
            action publishCount;
        }

        action resetCount {
            out count: BreathCount;

            first clearStoredCount;
            then publishZeroCount;

            action clearStoredCount;
            action publishZeroCount;
        }
    }

    part def BreathRateEstimator {
        attribute currentRate: BreathRate = 0 ["breath/min"];
        attribute averagingWindow: Time = 60 ["s"];
        attribute highRateThreshold: BreathRate = 30 ["breath/min"];
        attribute lowRateThreshold: BreathRate = 8 ["breath/min"];

        port breathInput {
            in breath: BreathEvent;
        }

        port commandInput: CommandPort;

        port rateOutput {
            out rate: BreathRate;
        }

        port alertOutput: AlertPort;

        action estimateRate {
            in breath: BreathEvent;
            out rate: BreathRate;

            first recordBreathTimestamp;
            then removeOldBreathTimestamps;
            then computeBreathsPerMinute;
            then publishRate;

            action recordBreathTimestamp;
            action removeOldBreathTimestamps;
            action computeBreathsPerMinute;
            action publishRate;
        }
    }

    part def ReadingDisplay {
        attribute displayedCount: BreathCount;
        attribute displayedRate: BreathRate;
        attribute displayedVolume: LungVolume;
        attribute displayedSignalQuality: Percentage;

        port countInput {
            in count: BreathCount;
        }

        port rateInput {
            in rate: BreathRate;
        }

        port readingOutput: ReadingPort;

        action renderReading {
            in count: BreathCount;
            in rate: BreathRate;
            out reading: LungCounterReading;

            first composeReading;
            then updateNumericDisplay;
            then publishReading;

            action composeReading;
            action updateNumericDisplay;
            action publishReading;
        }
    }

    part def AlarmManager {
        attribute audibleEnabled: Boolean = true;
        attribute visualEnabled: Boolean = true;

        port powerAlertInput {
            in alert: AlertSignal;
        }

        port sensorAlertInput {
            in alert: AlertSignal;
        }

        port rateAlertInput {
            in alert: AlertSignal;
        }

        port alertOutput: AlertPort;

        action consolidateAlerts {
            in powerAlert: AlertSignal;
            in sensorAlert: AlertSignal;
            in rateAlert: AlertSignal;
            out alert: AlertSignal;

            first combineActiveAlerts;
            then prioritizeCriticalAlerts;
            then publishAlertSignal;

            action combineActiveAlerts;
            action prioritizeCriticalAlerts;
            action publishAlertSignal;
        }
    }

    part def PowerManager {
        attribute lowBatteryThreshold: BatteryCharge = 15 ["%"];
        attribute batteryCharge: BatteryCharge = 100 ["%"];
        attribute powered: Boolean = true;

        port powerInput: PowerPort;
        port alertOutput: AlertPort;

        action monitorPower {
            in charge: BatteryCharge;
            out alert: AlertSignal;

            first readBatteryCharge;
            then compareToThreshold;
            then issueLowBatteryAlert;

            action readBatteryCharge;
            action compareToThreshold;
            action issueLowBatteryAlert;
        }
    }

    part def UserInterface {
        port commandOutput: CommandPort;

        action startSession {
            out command: UserCommand;
        }

        action stopSession {
            out command: UserCommand;
        }

        action resetSession {
            out command: UserCommand;
        }
    }

    action def CountLungBreaths {
        in flowSample: AirFlowSample;
        in userCommand: UserCommand;
        out reading: LungCounterReading;
        out alert: AlertSignal;

        first initializeSession;
        then acquireRespiratoryFlow;
        then detectCompleteBreathCycle;
        then validateBreathEvent;
        then incrementBreathCounter;
        then estimateBreathRate;
        then updateDisplayedReading;
        then evaluateAlerts;

        action initializeSession;
        action acquireRespiratoryFlow;
        action detectCompleteBreathCycle;
        action validateBreathEvent;
        action incrementBreathCounter;
        action estimateBreathRate;
        action updateDisplayedReading;
        action evaluateAlerts;
    }

    state def LungCounterOperatingStates {
        entry; then Off;

        state Off;
        state SelfTest;
        state Ready;
        state Counting;
        state Paused;
        state Fault;
        state LowPowerShutdown;

        transition Off_to_SelfTest
            first Off
            accept command
            if command.startRequested == true
            then SelfTest;

        transition SelfTest_to_Ready
            first SelfTest
            if batteryRemaining > 15 ["%"]
            then Ready;

        transition Ready_to_Counting
            first Ready
            accept command
            if command.startRequested == true
            then Counting;

        transition Counting_to_Paused
            first Counting
            accept command
            if command.stopRequested == true
            then Paused;

        transition Paused_to_Counting
            first Paused
            accept command
            if command.startRequested == true
            then Counting;

        transition Counting_to_Ready
            first Counting
            accept command
            if command.resetRequested == true
            then Ready;

        transition Ready_to_Fault
            first Ready
            accept alert
            if alert.sensorFault == true
            then Fault;

        transition Counting_to_Fault
            first Counting
            accept alert
            if alert.sensorFault == true
            then Fault;

        transition Fault_to_Ready
            first Fault
            accept alert
            if alert.sensorFault == false
            then Ready;

        transition Counting_to_LowPowerShutdown
            first Counting
            accept alert
            if alert.lowBattery == true
            then LowPowerShutdown;

        transition LowPowerShutdown_to_Off
            first LowPowerShutdown
            then Off;
    }

    requirement def CountRespiratoryCyclesRequirement {
        doc /* The lung counter shall detect complete respiratory cycles from measured airflow and maintain a cumulative count of valid breaths during a user session. */
    }

    requirement def HighLevelFunctionRequirement {
        doc /* The primary function of the lung counter is to monitor respiratory airflow, recognize valid inhalation and exhalation cycles, count breaths, and provide a current breathing-rate indication for clinical or wellness observation. */
    }

    requirement def BreathRateRequirement {
        doc /* The lung counter shall estimate current breath rate in breaths per minute using valid breath events observed within a moving sixty-second window. */
    }

    requirement def InvalidSignalRejectionRequirement {
        doc /* The lung counter shall reject breath events when the measured signal quality is below forty percent or when integrated tidal volume is below 0.05 liters. */
    }

    requirement def AlertRequirement {
        doc /* The lung counter shall issue alerts for low battery, sensor fault, poor sensor seal, high breath rate, and low breath rate conditions. */
    }

    requirement def ResetRequirement {
        doc /* The lung counter shall reset cumulative count, elapsed session time, average tidal volume, and displayed breath rate when a reset command is received outside the off state. */
    }

    requirement def SampleRateRequirement {
        doc /* The lung counter shall sample respiratory airflow at intervals no greater than twenty milliseconds while in the counting state. */
    }

    requirement def PowerRequirement {
        doc /* The lung counter shall enter a controlled low-power shutdown when battery charge falls below fifteen percent during active counting. */
    }

    satisfy CountRespiratoryCyclesRequirement by LungCounter::counter;
    satisfy HighLevelFunctionRequirement by LungCounter;
    satisfy BreathRateRequirement by LungCounter::rateEstimator;
    satisfy InvalidSignalRejectionRequirement by LungCounter::breathDetector;
    satisfy AlertRequirement by LungCounter::alarmManager;
    satisfy ResetRequirement by LungCounter::userInterface;
    satisfy SampleRateRequirement by LungCounter::flowSensor;
    satisfy PowerRequirement by LungCounter::powerManager;

    package OperationalScenario {
        part lungCounter: LungCounter;

        item initialCommand: UserCommand {
            attribute startRequested = true;
            attribute stopRequested = false;
            attribute resetRequested = false;
        }

        item nominalReading: LungCounterReading {
            attribute totalBreaths = 18;
            attribute currentBreathRate = 14 ["breath/min"];
            attribute averageTidalVolume = 0.5 ["L"];
            attribute sessionDuration = 75 ["s"];
            attribute signalQuality = 96 ["%"];
        }

        action performNominalCountingSession {
            first powerOn;
            then completeSelfTest;
            then beginCounting;
            then countValidBreathEvents;
            then publishNominalReading;

            action powerOn;
            action completeSelfTest;
            action beginCounting;
            action countValidBreathEvents;
            action publishNominalReading;
        }
    }
}