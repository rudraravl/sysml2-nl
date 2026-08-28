package FreeFallSensingUnit {
    doc /* This package models a Free Fall Sensing Unit that continuously monitors 3-axis acceleration and detects free fall events. */
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def Acceleration :> ISQ::AccelerationValue;
    attribute def Duration :> ISQ::DurationValue;
    attribute def Frequency :> ISQ::FrequencyValue;

    item def AccelerationSample {
        attribute x : Acceleration;
        attribute y : Acceleration;
        attribute z : Acceleration;
        attribute timestamp : TimeValue;
    }

    item def ProcessedAcceleration {
        attribute magnitude : Acceleration;
        attribute timestamp : TimeValue;
    }

    item def FreeFallEvent {
        attribute detectionTime : TimeValue;
        attribute duration : Duration;
        attribute minAcceleration : Acceleration;
    }

    item def ControlCommand {
        attribute enable : Boolean;
        attribute threshold : Acceleration;
    }

    item def StatusReport {
        attribute enabled : Boolean;
        attribute currentThreshold : Acceleration;
        attribute loggedEventCount : Integer;
    }

    port def AccelerationDataPort {
        out acceleration : ProcessedAcceleration;
    }

    port def EventPort {
        out alert : FreeFallEvent;
    }

    port def ControlPort {
        in command : ControlCommand;
        out status : StatusReport;
    }

    port def RawSamplePort {
        out sample : AccelerationSample;
    }

    action def SampleData {
        out sample : AccelerationSample;
    }

    action def ProcessData {
        in rawSample : AccelerationSample;
        out processedData : ProcessedAcceleration;
    }

    action def LogEventAction {
        in alert : FreeFallEvent;
    }

    action def HandleControlAction {
        in command : ControlCommand;
        out status : StatusReport;
    }

    state def AccelerometerStates;
    state def DetectionStates;
    state def OperationalStates;

    part def Accelerometer {
        attribute samplingRate : Frequency := 100 [Hz];
        attribute enabled : Boolean := true;
        port sampleOut : RawSamplePort;
        perform action sampleData : SampleData;
        exhibit state accelStates : AccelerometerStates;
    }

    part def SignalProcessor {
        port sampleIn : ~RawSamplePort;
        port processedOut : AccelerationDataPort;
        perform action processData : ProcessData;
    }

    part def FreeFallDetector {
        attribute enabled : Boolean := true;
        attribute threshold : Acceleration := 2.0 [m/s^2];
        attribute minDuration : Duration := 100 [ms];
        port processedIn : ~AccelerationDataPort;
        port alertOut : EventPort;
        exhibit state detectionStates : DetectionStates;
    }

    part def DataLogger {
        attribute maxEvents : Integer := 1000;
        attribute loggedEvents : FreeFallEvent[*] := ();
        port alertIn : ~EventPort;
        perform action logEvent : LogEventAction;
    }

    part def FreeFallSensor {
        port accelerationOut : AccelerationDataPort;
        port eventOut : EventPort;
        port control : ControlPort;

        attribute enabled : Boolean := true;
        attribute threshold : Acceleration := 2.0 [m/s^2];
        attribute minDuration : Duration := 100 [ms];

        part accelerometer : Accelerometer;
        part signalProcessor : SignalProcessor;
        part freeFallDetector : FreeFallDetector;
        part dataLogger : DataLogger;

        exhibit state operationalStates : OperationalStates;
        perform action handleControl : HandleControlAction;
    }

    part freeFallSensor : FreeFallSensor {
        part accelerometer : Accelerometer {
            exhibit state accelStates : AccelerometerStates {
                entry; then Idle;
                state Idle;
                accept when enabled == true then Sampling;
                state Sampling;
                accept when enabled == false then Idle;
                accept after 0.01 [s] do sampleData then Sampling;
            }
        }

        part freeFallDetector : FreeFallDetector {
            exhibit state detectionStates : DetectionStates {
                entry; then Normal;
                state Normal;
                accept processedData : ProcessedAcceleration
                    if processedData.magnitude < threshold
                    then PotentialFreeFall;
                state PotentialFreeFall;
                accept processedData : ProcessedAcceleration
                    if processedData.magnitude >= threshold
                    then Normal;
                accept after minDuration
                    then FreeFallDetected;
                state FreeFallDetected;
                accept processedData : ProcessedAcceleration
                    if processedData.magnitude >= threshold
                    then Normal;
            }
        }

        exhibit state operationalStates : OperationalStates {
            entry; then Disabled;
            state Disabled;
            accept command : ControlCommand
                if command.enable
                do assign enabled := true
                then Enabled;
            state Enabled;
            accept command : ControlCommand
                if not command.enable
                do assign enabled := false
                then Disabled;
        }

        connect accelerometer.sampleOut to signalProcessor.sampleIn;
        connect signalProcessor.processedOut to freeFallDetector.processedIn;
        connect signalProcessor.processedOut to accelerationOut;
        connect freeFallDetector.alertOut to dataLogger.alertIn;
        connect freeFallDetector.alertOut to eventOut;

        bind accelerometer.enabled = enabled;
        bind freeFallDetector.enabled = enabled;
        bind freeFallDetector.threshold = threshold;
        bind freeFallDetector.minDuration = minDuration;
    }

    requirement def FreeFallDetectionRequirement {
        doc /* The system shall detect free fall when acceleration magnitude is below threshold for at least minimum duration. */
        subject freeFallDetector : FreeFallDetector;
        constraint { freeFallDetector.threshold == 2.0 [m/s^2] }
        constraint { freeFallDetector.minDuration == 100 [ms] }
    }

    requirement def SamplingRateRequirement {
        doc /* The accelerometer shall sample acceleration at 100 Hz. */
        subject accelerometer : Accelerometer;
        constraint { accelerometer.samplingRate == 100 [Hz] }
    }

    requirement def EventLoggingRequirement {
        doc /* The data logger shall store up to 1000 free fall events. */
        subject dataLogger : DataLogger;
        constraint { dataLogger.loggedEvents->size() <= 1000 }
    }

    requirement def ControlInterfaceRequirement {
        doc /* The unit shall support enable/disable, threshold adjustment, and status reporting via the control port. */
        subject freeFallSensor : FreeFallSensor;
    }

    requirement def RealTimeOutputRequirement {
        doc /* The system shall output real-time processed acceleration data externally. */
        subject freeFallSensor : FreeFallSensor;
    }
}
