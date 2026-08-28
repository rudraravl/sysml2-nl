package Acceleromyograph {

import ScalarValues::*;

// ================ VALUE TYPES ================

value type CurrentValue :> Real {
    doc /* Stimulator output current in milliamps (mA) */;
    :>> min = 0;
    :>> max = 60;
}

value type DurationValue :> Real {
    doc /* Pulse duration in milliseconds (ms) */;
    :>> min = 0.01;
    :>> max = 10;
}

value type IntervalValue :> Real {
    doc /* Interval between TOF pulses in milliseconds (ms) */;
    :>> min = 1;
    :>> max = 10000;
}

value type AccelerationValue :> Real {
    doc /* Muscle twitch acceleration in meters per second squared (m/s2) */;
    :>> min = 0;
}

value type TOFRatioValue :> Real {
    doc /* Train-of-Four ratio T4/T1, dimensionless, range 0.0 to 1.0 */;
    :>> min = 0.0;
    :>> max = 1.0;
}

value type BlockadePercentValue :> Real {
    doc /* Neuromuscular blockade percentage 0 to 100 */;
    :>> min = 0;
    :>> max = 100;
}

value type TimeStampValue :> Real {
    doc /* Elapsed time in seconds (s) */;
    :>> min = 0;
}

value type TrendValue :> Real {
    doc /* Recovery trend in percent per minute (%/min) */;
}

value type GainValue :> Real {
    doc /* Sensor gain factor, dimensionless */;
    :>> min = 0;
}

value type SignalValue :> Real {
    doc /* Raw signal amplitude from accelerometer, in m/s2 */;
    :>> min = 0;
}

// ================ ENUMERATIONS ================

enum def StimulationMode {
    TOF;
    SingleTwitch;
    Tetanus;
    DoubleBurst;
}

enum def BlockadeLevel {
    None;
    Partial;
    Deep;
    Profound;
}

enum def AlarmPriority {
    Info;
    Warning;
    Critical;
}

// ================ ITEM DEFINITIONS ================

item def StimulationCommand {
    attribute mode : StimulationMode;
    attribute current : CurrentValue;
    attribute pulseDuration : DurationValue;
    attribute pulseInterval : IntervalValue;
    attribute numberOfPulses : Integer;
    attribute timestamp : TimeStampValue;
}

item def TOFStimulusPattern {
    attribute mode : StimulationMode;
    attribute current : CurrentValue;
    attribute pulseDuration : DurationValue;
    attribute pulseInterval : IntervalValue;
    attribute numberOfPulses : Integer;
    attribute deliveredAt : TimeStampValue;
}

item def AccelerationSample {
    attribute pulseIndex : Integer;
    attribute acceleration : AccelerationValue;
    attribute measuredAt : TimeStampValue;
}

item def TwitchMeasurement {
    attribute pulseIndex : Integer;
    attribute peakAcceleration : AccelerationValue;
    attribute latency : DurationValue;
    attribute measuredAt : TimeStampValue;
}

item def TOFMeasurementSet {
    attribute twitches : TwitchMeasurement[4];
    attribute sequenceNumber : Integer;
    attribute capturedAt : TimeStampValue;
}

item def TOFAssessment {
    attribute tofRatio : TOFRatioValue;
    attribute blockadePercent : BlockadePercentValue;
    attribute blockadeLevel : BlockadeLevel;
    attribute recoveryTrend : TrendValue;
    attribute sequenceNumber : Integer;
    attribute assessedAt : TimeStampValue;
}

item def CalibrationData {
    attribute baselineAcceleration : AccelerationValue;
    attribute sensorGain : GainValue;
    attribute calibratedAt : TimeStampValue;
}

item def DisplayUpdate {
    attribute tofRatio : TOFRatioValue;
    attribute blockadePercent : BlockadePercentValue;
    attribute blockadeLevel : BlockadeLevel;
    attribute recoveryTrend : TrendValue;
    attribute alarmActive : Boolean;
    attribute alarmPriority : AlarmPriority;
    attribute message : String;
    attribute sequenceNumber : Integer;
    attribute updatedAt : TimeStampValue;
}

// ================ PORT DEFINITIONS ================

port def StimCommandOut {
    out item : StimulationCommand;
}

port def StimCommandIn {
    in item : StimulationCommand;
}

port def StimTriggerOut {
    out item : TOFStimulusPattern;
}

port def StimTriggerIn {
    in item : TOFStimulusPattern;
}

port def AccelDataOut {
    out item : AccelerationSample;
}

port def AccelDataIn {
    in item : AccelerationSample;
}

port def AssessmentOut {
    out item : TOFAssessment;
}

port def AssessmentIn {
    in item : TOFAssessment;
}

// ================ PART DEFINITIONS ================

part def NerveStimulator {
    doc /* Generates and delivers a Train-of-Four (TOF) pattern of small electrical pulses to a peripheral nerve, causing the corresponding muscle to contract or twitch. */;

    port cmdIn : StimCommandIn;
    port stimOut : StimTriggerOut;

    attribute defaultCurrent : CurrentValue = 40;
    attribute defaultPulseDuration : DurationValue = 0.2;
    attribute defaultPulseInterval : IntervalValue = 500;
    attribute defaultNumPulses : Integer = 4;

    attribute stimulusCount : Integer = 0;
    attribute isStimulating : Boolean = false;
    attribute electrodeImpedanceOk : Boolean = true;

    action def buildStimulusPattern(in cmd : StimulationCommand) : TOFStimulusPattern {
        // Construct a TOFStimulusPattern from the stimulation command parameters
        // using delivered current, pulse duration, interval, and number of pulses
    }

    action def deliverPulses(in pattern : TOFStimulusPattern) {
        // Deliver electrical pulses to the peripheral nerve via surface or needle electrode
        // Each pulse is a brief, constant-current stimulus of the specified duration
    }

    action performStimulation(in cmd : StimulationCommand) {
        // 1. Validate electrode impedance is within acceptable range
        // 2. Build the stimulus pattern from the command
        // 3. Increment stimulusCount
        // 4. Deliver pulses to the nerve
        // 5. Emit the delivered pattern on stimOut for sensor and analysis synchronization
    }
}

part def AccelerometerSensor {
    doc /* Attached to the target muscle (e.g. the thumb); precisely measures the acceleration of each muscle twitch in response to electrical nerve stimulation. */;

    port stimIn : StimTriggerIn;
    port accelOut : AccelDataOut;

    attribute sampleRateHz : Integer = 1000;
    attribute sensitivity : GainValue = 1.0;
    attribute isCalibrated : Boolean = false;
    attribute noiseThreshold : AccelerationValue = 0.05;
    attribute measurementWindowMs : DurationValue = 80;

    action def sampleAcceleration(in pulseIndex : Integer, in stimTimestamp : TimeStampValue) : AccelerationSample {
        // Read the accelerometer over the measurement window following the stimulus
        // Compute peak acceleration above noise threshold
        // Return AccelerationSample with pulseIndex, acceleration, measuredAt
    }

    action def calibrate() : CalibrationData {
        // Perform baseline calibration: measure noise floor, set sensitivity gain
        // Set isCalibrated to true
        // Return CalibrationData with baseline and gain
    }

    action respondToStimulus(in stim : TOFStimulusPattern) {
        // For each pulse index 0..(numberOfPulses - 1) in the stimulus:
        //   sample acceleration after the inter-pulse delay
        //   emit AccelerationSample on accelOut
    }
}

part def AnalysisUnit {
    doc /* Central processor: receives acceleration data, computes the Train-of-Four ratio (T4/T1), assesses the degree of neuromuscular blockade, tracks recovery trend, and orchestrates the monitoring cycle by issuing stimulation commands. */;

    port stimIn : StimTriggerIn;
    port accelIn : AccelDataIn;
    port cmdOut : StimCommandOut;
    port assessmentOut : AssessmentOut;

    attribute tofRatioDeepThreshold : TOFRatioValue = 0.4;
    attribute tofRatioProfoundThreshold : TOFRatioValue = 0.1;
    attribute blockadeAlarmThreshold : BlockadePercentValue = 90;
    attribute recoveryAdequateThreshold : TOFRatioValue = 0.9;
    attribute trendWindowSize : Integer = 10;

    attribute currentTwitches : TwitchMeasurement[0..4];
    attribute sequenceCounter : Integer = 0;
    attribute assessmentHistory : TOFAssessment[0..10];
    attribute lastAssessment : TOFAssessment;
    attribute blockadeTooDeep : Boolean = false;

    action def computeTOFRatio(in t1Peak : AccelerationValue, in t4Peak : AccelerationValue) : TOFRatioValue {
        // If t1Peak <= 0 return 0; otherwise return t4Peak / t1Peak clamped to [0, 1]
    }

    action def computeBlockadePercent(in ratio : TOFRatioValue) : BlockadePercentValue {
        // Map TOF ratio to percent blockade: (1 - ratio) * 100
    }

    action def classifyBlockade(in ratio : TOFRatioValue) : BlockadeLevel {
        // Profound if ratio < 0.1
        // Deep if ratio < 0.4
        // Partial if ratio < 0.9
        // None if ratio >= 0.9
    }

    action def computeRecoveryTrend(in history : TOFAssessment[0..10]) : TrendValue {
        // Linear regression on recent blockadePercent values over time
        // Returns rate of change in %/min; positive indicates recovery
    }

    action def assembleTOFSet(in twitches : TwitchMeasurement[4]) : TOFMeasurementSet {
        // Package four twitch measurements into a TOFMeasurementSet with sequence number
    }

    action def assess(in measurements : TOFMeasurementSet) : TOFAssessment {
        // 1. Extract T1 (pulseIndex 0) and T4 (pulseIndex 3) peak accelerations
        // 2. Compute TOF ratio via computeTOFRatio
        // 3. Compute blockade percent via computeBlockadePercent
        // 4. Classify blockade level via classifyBlockade
        // 5. Compute recovery trend from assessmentHistory
        // 6. Append to assessmentHistory
        // 7. Set blockadeTooDeep flag if blockadePercent >= blockadeAlarmThreshold
        // 8. Return complete TOFAssessment
    }

    action def generateStimCommand() : StimulationCommand {
        // Create a TOF stimulation command with default current, duration, interval, pulses
    }

    action processMonitoringCycle() {
        // 1. Generate a StimulationCommand and send it on cmdOut
        // 2. Receive AccelerationSamples on accelIn (four samples for TOF)
        // 3. Convert samples to TwitchMeasurements (extract peak per pulse)
        // 4. Assemble TOFMeasurementSet from four twitches
        // 5. Compute TOFAssessment via assess()
        // 6. Emit TOFAssessment on assessmentOut
        // 7. Increment sequenceCounter
    }
}

part def DisplayController {
    doc /* Receives blockade assessments and presents the TOF ratio, blockade percentage, blockade level, and recovery trend clearly to the clinician on a screen. Manages alarm indication when blockade is too deep. */;

    port assessmentIn : AssessmentIn;

    attribute currentDisplay : DisplayUpdate;
    attribute backlightOn : Boolean = true;
    attribute contrastLevel : Real = 0.7;
    attribute alarmVolumeDb : Integer = 70;
    attribute lastAlarmPriority : AlarmPriority = AlarmPriority::Info;
    attribute alarmActive : Boolean = false;

    action def formatDisplay(in assessment : TOFAssessment) : DisplayUpdate {
        // Convert assessment into DisplayUpdate with:
        //   tofRatio, blockadePercent, blockadeLevel, recoveryTrend
        //   alarmActive flag set if blockadeLevel is Deep or Profound
        //   alarmPriority set accordingly
        //   human-readable message string
    }

    action def updateScreen(in update : DisplayUpdate) {
        // Render the DisplayUpdate to the physical display:
        //   numeric TOF ratio, bar graph for blockade, trend line
        //   color-coded blockade level indicator
        //   alarm banner if alarmActive
    }

    action def raiseAlarm(in priority : AlarmPriority) {
        // Activate audible tone at alarmVolumeDb and visual alarm indicator
        // Set alarmActive to true and lastAlarmPriority to priority
    }

    action def clearAlarm() {
        // Deactivate audible and visual alarm indicators
        // Set alarmActive to false
    }

    action processAssessment(in assessment : TOFAssessment) {
        // 1. Format the assessment for display via formatDisplay()
        // 2. If blockadeLevel is Deep or Profound, call raiseAlarm(Critical)
        //    Otherwise call clearAlarm()
        // 3. Update the screen via updateScreen()
    }
}

// ================ REQUIREMENTS ================

requirement def NeuromuscularBlockadeMeasurement {
    doc /* The acceleromyograph shall quantitatively measure the degree of muscle relaxation (neuromuscular blockade) in a patient during anesthesia to help clinicians safely manage muscle-relaxant drugs. */;
    subject device : AcceleromyographDevice;
}

requirement def TOFStimulationRequirement {
    doc /* The nerve stimulator shall generate and deliver a Train-of-Four (TOF) pattern of electrical pulses to a peripheral nerve, consisting of four stimuli at 0.2 ms duration and 500 ms (2 Hz) intervals. */;
    subject stimulator : NerveStimulator;
    constraint { stimulator.defaultNumPulses == 4 }
    constraint { stimulator.defaultPulseDuration == 0.2 }
    constraint { stimulator.defaultPulseInterval == 500 }
}

requirement def AccelerationSensingRequirement {
    doc /* The accelerometer sensor shall measure the acceleration of the muscle twitch in response to each TOF electrical pulse with a sample rate of at least 1000 Hz. */;
    subject sensor : AccelerometerSensor;
    constraint { sensor.sampleRateHz >= 1000 }
}

requirement def TOFRatioCalculationRequirement {
    doc /* The analysis unit shall calculate the Train-of-Four ratio by comparing the strength of the fourth twitch to the first twitch (T4/T1), yielding a numerical value between 0.0 and 1.0. */;
    subject analysis : AnalysisUnit;
    constraint { analysis.lastAssessment.tofRatio >= 0.0 }
    constraint { analysis.lastAssessment.tofRatio <= 1.0 }
}

requirement def BlockadeAssessmentRequirement {
    doc /* The analysis unit shall assess the overall blockade and recovery trend based on the TOF ratio, classifying blockade as None, Partial, Deep, or Profound. */;
    subject analysis : AnalysisUnit;
    constraint { analysis.tofRatioDeepThreshold == 0.4 }
    constraint { analysis.tofRatioProfoundThreshold == 0.1 }
}

requirement def DisplayPresentationRequirement {
    doc /* The display controller shall present the TOF ratio, blockade percentage, blockade level, and recovery trend clearly to the clinician on a screen. */;
    subject display : DisplayController;
}

requirement def DeepBlockadeAlarmRequirement {
    doc /* The system shall activate an audible and visual alarm when neuromuscular blockade exceeds 90 percent (TOF ratio below 0.1). */;
    subject device : AcceleromyographDevice;
    constraint { device.analysisUnit.blockadeAlarmThreshold == 90 }
}

requirement def PauseResumeRequirement {
    doc /* The system shall allow the clinician to pause and resume monitoring as needed during a surgical procedure. */;
    subject device : AcceleromyographDevice;
}

requirement def InitializationRequirement {
    doc /* After being powered on, the device shall enter an initialization state for self-tests and sensor calibration before becoming ready for use. */;
    subject device : AcceleromyographDevice;
}

requirement def RecoveryConfirmationRequirement {
    doc /* The system shall help ensure the patient muscle function has returned (TOF ratio >= 0.9) before awakening by providing continuous recovery trend data to the clinician. */;
    subject device : AcceleromyographDevice;
    constraint { device.analysisUnit.recoveryAdequateThreshold == 0.9 }
}

requirement def StimulationCurrentLimit {
    doc /* The nerve stimulator shall not deliver current exceeding 60 mA to ensure patient safety. */;
    subject stimulator : NerveStimulator;
    constraint { stimulator.defaultCurrent <= 60 }
}

// ================ TOP-LEVEL DEVICE ================

part def AcceleromyographDevice {
    doc /* Acceleromyograph: a medical monitoring device used during anesthesia to quantitatively measure the degree of muscle relaxation (neuromuscular blockade), helping clinicians safely manage muscle-relaxant drugs and confirm muscle function recovery before awakening the patient. */;

    // --- Constituent parts ---
    part nerveStimulator : NerveStimulator;
    part accelerometerSensor : AccelerometerSensor;
    part analysisUnit : AnalysisUnit;
    part displayController : DisplayController;

    // --- State machine control signals ---
    attribute powerOnSignal : Boolean = false;
    attribute calibrationCompleteSignal : Boolean = false;
    attribute startSessionSignal : Boolean = false;
    attribute pauseSignal : Boolean = false;
    attribute resumeSignal : Boolean = false;
    attribute stopSessionSignal : Boolean = false;
    attribute powerOffSignal : Boolean = false;
    attribute blockadeTooDeepSignal : Boolean = false;
    attribute alarmAcknowledgedSignal : Boolean = false;

    // --- Device status ---
    attribute sessionId : Integer = 0;
    attribute sessionStartTime : TimeStampValue = 0;
    attribute totalAssessments : Integer = 0;

    // --- Inter-part connections ---
    connection stimCommand connect analysisUnit.cmdOut to nerveStimulator.cmdIn;
    connection stimToSensor connect nerveStimulator.stimOut to accelerometerSensor.stimIn;
    connection stimToAnalysis connect nerveStimulator.stimOut to analysisUnit.stimIn;
    connection accelToAnalysis connect accelerometerSensor.accelOut to analysisUnit.accelIn;
    connection assessmentToDisplay connect analysisUnit.assessmentOut to displayController.assessmentIn;

    // --- Device lifecycle state machine ---
    state lifecycle {

        state Off {
            doc /* Device powered off. */;
            entry / powerDownSequence();
        }

        state Initialization {
            doc /* Self-tests and sensor calibration upon power-on. */;
            entry / startSelfTest();
            do / runCalibration();
            exit / finalizeCalibration();
        }

        state Ready {
            doc /* Idle: waiting for clinician to start a monitoring session. */;
            entry / showReadyScreen();
            do / awaitStartCommand();
        }

        state Monitoring {
            doc /* Active monitoring: cycles through nerve stimulation, acceleration measurement, TOF analysis, and display update. */;
            entry / startMonitoringSession();
            do / monitoringLoop();
            exit / endMonitoringSession();
        }

        state Paused {
            doc /* Monitoring temporarily halted by the user; last display values are frozen. */;
            entry / freezeDisplay();
            do / awaitResumeOrStop();
        }

        state Alarm {
            doc /* Critical alarm: blockade has become too deep. Audible and visual alarms are active. */;
            entry / activateAlarm();
            do / flashAlarmDisplay();
            exit / deactivateAlarm();
        }

        // Power-on transition
        transition powerOnInit from Off to Initialization when powerOnSignal;

        // Initialization complete
        transition initReady from Initialization to Ready when calibrationCompleteSignal;

        // Start monitoring session
        transition readyMonitoring from Ready to Monitoring when startSessionSignal;

        // Pause monitoring
        transition monitoringPaused from Monitoring to Paused when pauseSignal;

        // Resume monitoring
        transition pausedMonitoring from Paused to Monitoring when resumeSignal;

        // Stop monitoring (return to ready)
        transition monitoringReady from Monitoring to Ready when stopSessionSignal;
        transition pausedReady from Paused to Ready when stopSessionSignal;

        // Alarm transitions
        transition monitoringAlarm from Monitoring to Alarm when blockadeTooDeepSignal;
        transition pausedAlarm from Paused to Alarm when blockadeTooDeepSignal;
        transition alarmMonitoring from Alarm to Monitoring when alarmAcknowledgedSignal;
        transition alarmReady from Alarm to Ready when stopSessionSignal;

        // Power-off transitions
        transition initOff from Initialization to Off when powerOffSignal;
        transition readyOff from Ready to Off when powerOffSignal;
        transition monitoringOff from Monitoring to Off when powerOffSignal;
        transition pausedOff from Paused to Off when powerOffSignal;
        transition alarmOff from Alarm to Off when powerOffSignal;
    }

    // --- Device-level actions invoked by the state machine ---

    action powerDownSequence() {
        // Safely power down all subsystems: stop stimulation, clear alarms, save session data
        powerOnSignal = false;
        calibrationCompleteSignal = false;
        startSessionSignal = false;
        pauseSignal = false;
        resumeSignal = false;
        stopSessionSignal = false;
        blockadeTooDeepSignal = false;
        alarmAcknowledgedSignal = false;
    }

    action startSelfTest() {
        // Initiate hardware self-tests: battery level, electrode impedance, sensor connectivity
        // Verify all subsystems are operational
    }

    action runCalibration() {
        // Calibrate the accelerometer sensor baseline via accelerometerSensor.calibrate()
        // Verify calibration results are within expected range
    }

    action finalizeCalibration() {
        // Store calibration data and signal readiness
        calibrationCompleteSignal = true;
    }

    action showReadyScreen() {
        // Display the ready/idle screen prompting clinician to start a session
        // Show device status, battery level, last calibration time
    }

    action awaitStartCommand() {
        // Wait for clinician input to begin monitoring; user presses start button
    }

    action startMonitoringSession() {
        // Initialize session: reset sequenceCounter, set sessionStartTime, increment sessionId
        // Clear any previous alarm state
    }

    action monitoringLoop() {
        // Continuously execute the monitoring cycle:
        // 1. analysisUnit.processMonitoringCycle() triggers stimulation and data collection
        // 2. After each assessment, check if blockadeTooDeep flag is set
        // 3. If blockade percent >= 90, set blockadeTooDeepSignal to trigger alarm
        // 4. If TOF ratio >= 0.9, indicate adequate recovery on display
        if (analysisUnit.blockadeTooDeep == true) {
            blockadeTooDeepSignal = true;
        }
    }

    action endMonitoringSession() {
        // Summarize session data, save to memory, return to ready state
        totalAssessments = totalAssessments + analysisUnit.sequenceCounter;
    }

    action freezeDisplay() {
        // Freeze the last displayed TOF values on screen; stop stimulation
        nerveStimulator.isStimulating = false;
    }

    action awaitResumeOrStop() {
        // Wait for clinician to resume or stop the session
    }

    action activateAlarm() {
        // Activate audible and visual alarm: blockade is too deep
        displayController.raiseAlarm(AlarmPriority::Critical);
    }

    action flashAlarmDisplay() {
        // Flash critical alarm message on display with blinking indicator
        // Continue showing last TOF values with alarm overlay
    }

    action deactivateAlarm() {
        // Silence alarm after clinician acknowledgment
        displayController.clearAlarm();
        alarmAcknowledgedSignal = false;
        blockadeTooDeepSignal = false;
        analysisUnit.blockadeTooDeep = false;
    }

    // --- Requirement satisfactions ---
    satisfy NeuromuscularBlockadeMeasurement by this;
    satisfy TOFStimulationRequirement by nerveStimulator;
    satisfy AccelerationSensingRequirement by accelerometerSensor;
    satisfy TOFRatioCalculationRequirement by analysisUnit;
    satisfy BlockadeAssessmentRequirement by analysisUnit;
    satisfy DisplayPresentationRequirement by displayController;
    satisfy DeepBlockadeAlarmRequirement by this;
    satisfy PauseResumeRequirement by this;
    satisfy InitializationRequirement by this;
    satisfy RecoveryConfirmationRequirement by this;
    satisfy StimulationCurrentLimit by nerveStimulator;
}

// ================ PACKAGE-LEVEL SATISFACTIONS ================

satisfy NeuromuscularBlockadeMeasurement by AcceleromyographDevice;
satisfy TOFStimulationRequirement by NerveStimulator;
satisfy AccelerationSensingRequirement by AccelerometerSensor;
satisfy TOFRatioCalculationRequirement by AnalysisUnit;
satisfy BlockadeAssessmentRequirement by AnalysisUnit;
satisfy DisplayPresentationRequirement by DisplayController;
satisfy DeepBlockadeAlarmRequirement by AcceleromyographDevice;
satisfy PauseResumeRequirement by AcceleromyographDevice;
satisfy InitializationRequirement by AcceleromyographDevice;
satisfy RecoveryConfirmationRequirement by AcceleromyographDevice;
satisfy StimulationCurrentLimit by NerveStimulator;

}
