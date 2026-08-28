package FreeFallSensingUnit {
    import ISQ::*;
    import ISQBase::*;
    import SI::*;
    import ScalarValues::*;
    import Time::*;

    // ============================================================
    // Item Definitions
    // ============================================================

    item def AccelerationSample {
        attribute ax : Acceleration;
        attribute ay : Acceleration;
        attribute az : Acceleration;
        attribute timestamp : Time;
    }

    item def ProcessedAcceleration {
        attribute magnitude : Acceleration;
        attribute timestamp : Time;
    }

    item def FreeFallEvent {
        attribute detectionTime : Time;
        attribute duration : Time;
        attribute minAcceleration : Acceleration;
        attribute eventIndex : Integer;
    }

    // ============================================================
    // Enumerations
    // ============================================================

    enum def OperationalStatus {
        disabled;
        idle;
        monitoring;
        freeFallDetected;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def RawDataPort {
        out raw : AccelerationSample;
    }

    port def ProcessedDataPort {
        out processed : ProcessedAcceleration;
    }

    port def EventInternalPort {
        out evt : FreeFallEvent;
    }

    port def AccelerationOutPort {
        out accelStream : ProcessedAcceleration;
    }

    port def EventOutPort {
        out freeFallEvent : FreeFallEvent;
    }

    port def ControlPort {
        in enable : Boolean;
        in thresholdSetting : Acceleration;
        in statusRequest : Boolean;
        out status : OperationalStatus;
    }

    // ============================================================
    // Part: Accelerometer
    // ============================================================

    part def Accelerometer {
        attribute sampleRate : Frequency = 100.0 [Hz];
        attribute resolution : Acceleration = 0.001 [m/s^2];
        attribute enabled : Boolean = true;

        port rawOut : RawDataPort;

        action def SampleAxes {
            out ax : Acceleration;
            out ay : Acceleration;
            out az : Acceleration;
        }

        perform action sampling : SampleAxes {
            // Samples each axis at sampleRate; rawOut emits AccelerationSample
        }

        action def EmitSample {
            in ax : Acceleration;
            in ay : Acceleration;
            in az : Acceleration;
            in ts : Time;
            out sample : AccelerationSample;
        }

        perform action emit : EmitSample;
    }

    // ============================================================
    // Part: SignalProcessor
    // ============================================================

    part def SignalProcessor {
        attribute filterCoeff : Real = 0.2;
        attribute noiseFloor : Acceleration = 0.05 [m/s^2];

        port rawIn : ~RawDataPort;
        port procOut : ProcessedDataPort;

        action def FilterNoise {
            in raw : AccelerationSample;
            out filteredX : Acceleration;
            out filteredY : Acceleration;
            out filteredZ : Acceleration;
        }

        action def ComputeMagnitude {
            in fx : Acceleration;
            in fy : Acceleration;
            in fz : Acceleration;
            out magnitude : Acceleration;
        }

        perform action filtering : FilterNoise;
        perform action magnitudeCalc : ComputeMagnitude;

        action def EmitProcessed {
            in mag : Acceleration;
            in ts : Time;
            out proc : ProcessedAcceleration;
        }

        perform action emitProc : EmitProcessed;
    }

    // ============================================================
    // Part: FreeFallDetector
    // ============================================================

    part def FreeFallDetector {
        attribute threshold : Acceleration = 2.0 [m/s^2];
        attribute minDuration : Time = 100 [ms];
        attribute belowThresholdStart : Time;
        attribute currentMinAccel : Acceleration = 0.0 [m/s^2];
        attribute inFreeFall : Boolean = false;
        attribute lastDetectionTime : Time;

        port procIn : ~ProcessedDataPort;
        port eventOut : EventInternalPort;

        action def EvaluateSample {
            in proc : ProcessedAcceleration;
            out isBelow : Boolean;
        }

        perform action evaluate : EvaluateSample;

        action def GenerateEvent {
            in detectionTime : Time;
            in duration : Time;
            in minAccel : Acceleration;
            out evt : FreeFallEvent;
        }

        perform action generate : GenerateEvent;

        state machine DetectorBehavior {
            state Idle;
            state BelowThreshold;
            state FreeFallConfirmed;

            transition init first to Idle;

            transition Idle_to_BelowThreshold
                from Idle to BelowThreshold
                when (procIn.processed.magnitude < threshold)
                then {
                    belowThresholdStart := procIn.processed.timestamp;
                    currentMinAccel := procIn.processed.magnitude;
                }

            transition BelowThreshold_to_Idle
                from BelowThreshold to Idle
                when (procIn.processed.magnitude >= threshold);

            transition BelowThreshold_to_FreeFallConfirmed
                from BelowThreshold to FreeFallConfirmed
                when (procIn.processed.timestamp - belowThresholdStart >= minDuration)
                then {
                    inFreeFall := true;
                }

            transition FreeFallConfirmed_to_BelowThreshold
                from FreeFallConfirmed to BelowThreshold
                when (procIn.processed.magnitude < threshold)
                then {
                    currentMinAccel := (if procIn.processed.magnitude < currentMinAccel
                                       then procIn.processed.magnitude else currentMinAccel);
                }

            transition FreeFallConfirmed_to_Idle
                from FreeFallConfirmed to Idle
                when (procIn.processed.magnitude >= threshold)
                then {
                    inFreeFall := false;
                }
        }
    }

    // ============================================================
    // Part: DataLogger
    // ============================================================

    part def DataLogger {
        attribute maxEvents : Integer = 1000;
        attribute eventCount : Integer = 0;
        attribute log : FreeFallEvent[0..1000] ordered;

        port eventIn : ~EventInternalPort;

        action def RecordEvent {
            in evt : FreeFallEvent;
            out success : Boolean;
        }

        perform action recording : RecordEvent {
            // If eventCount < maxEvents, append evt to log and increment eventCount
        }

        action def RetrieveLog {
            out events : FreeFallEvent[0..1000];
        }

        perform action retrieve : RetrieveLog;
    }

    // ============================================================
    // Root Part: FreeFallSensor
    // ============================================================

    part def FreeFallSensor {
        attribute enabled : Boolean = true;
        attribute thresholdSetting : Acceleration = 2.0 [m/s^2];
        attribute currentStatus : OperationalStatus = idle;

        port accelOut : AccelerationOutPort;
        port eventOut : EventOutPort;
        port control : ControlPort;

        part accelerometer : Accelerometer {
            attribute enabled :=>> FreeFallSensor::enabled;
        }

        part processor : SignalProcessor;
        part detector : FreeFallDetector {
            attribute threshold :=>> FreeFallSensor::thresholdSetting;
        }
        part logger : DataLogger;

        // ----- Internal flow connections -----
        connection rawLink connect accelerometer.rawOut to processor.rawIn;
        connection procToDetector connect processor.procOut to detector.procIn;
        connection procToExternal connect processor.procOut to accelOut.accelStream;
        connection eventToLogger connect detector.eventOut to logger.eventIn;
        connection eventToExternal connect detector.eventOut to eventOut.freeFallEvent;

        // ----- Control bindings -----
        binding control.enable = enabled;
        binding control.thresholdSetting = thresholdSetting;
        binding control.status = currentStatus;

        // ----- Root state machine -----
        state machine UnitLifecycle {
            state Disabled;
            state Idle;
            state Monitoring;
            state FreeFallDetected;

            transition init first to Disabled;

            transition Disabled_to_Idle
                from Disabled to Idle
                when (control.enable == true)
                then {
                    enabled := true;
                    currentStatus := idle;
                }

            transition Idle_to_Disabled
                from Idle to Disabled
                when (control.enable == false)
                then {
                    enabled := false;
                    currentStatus := disabled;
                }

            transition Idle_to_Monitoring
                from Idle to Monitoring
                when (enabled == true)
                then {
                    currentStatus := monitoring;
                }

            transition Monitoring_to_FreeFallDetected
                from Monitoring to FreeFallDetected
                when (detector.inFreeFall == true)
                then {
                    currentStatus := freeFallDetected;
                }

            transition FreeFallDetected_to_Monitoring
                from FreeFallDetected to Monitoring
                when (detector.inFreeFall == false)
                then {
                    currentStatus := monitoring;
                }

            transition Monitoring_to_Disabled
                from Monitoring to Disabled
                when (control.enable == false)
                then {
                    enabled := false;
                    currentStatus := disabled;
                }

            transition FreeFallDetected_to_Disabled
                from FreeFallDetected to Disabled
                when (control.enable == false)
                then {
                    enabled := false;
                    currentStatus := disabled;
                }
        }
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def FreeFallDetectionRequirements {
        subject sensor : FreeFallSensor;

        requirement ContinuousMonitoring {
            doc /* The unit shall continuously monitor acceleration when enabled. */
            require sensor.enabled == true implies sensor.currentStatus != disabled;
        }

        requirement SamplingRateRequirement {
            doc /* The accelerometer shall sample at 100 Hz. */
            require sensor.accelerometer.sampleRate == 100.0 [Hz];
        }

        requirement ThresholdRequirement {
            doc /* Free fall is detected when acceleration magnitude remains below threshold. */
            require sensor.detector.threshold <= 2.0 [m/s^2];
        }

        requirement DurationRequirement {
            doc /* The below-threshold condition must persist for at least minDuration. */
            require sensor.detector.minDuration >= 100 [ms];
        }

        requirement EventOutputRequirement {
            doc /* A free fall event shall be emitted on the event port. */
            require sensor.eventOut.freeFallEvent.detectionTime > 0 [s];
        }

        requirement LoggingRequirement {
            doc /* The data logger shall store up to 1000 events. */
            require sensor.logger.maxEvents == 1000;
        }

        requirement ControlRequirement {
            doc /* The unit shall be controllable via the control port. */
            require sensor.control.enable == sensor.enabled;
            require sensor.control.thresholdSetting == sensor.thresholdSetting;
        }

        requirement StatusReportingRequirement {
            doc /* The unit shall report its current operational status. */
            require sensor.control.status == sensor.currentStatus;
        }
    }

    // ============================================================
    // Verification
    // ============================================================

    verification VerifySamplingRate {
        subject sensor : FreeFallSensor;
        objective {
            doc /* Confirm accelerometer samples at 100 Hz. */
        }
        return pass : Boolean = (sensor.accelerometer.sampleRate == 100.0 [Hz]);
    }

    verification VerifyThresholdDefault {
        subject sensor : FreeFallSensor;
        objective {
            doc /* Confirm default threshold is 2.0 m/s^2. */
        }
        return pass : Boolean = (sensor.detector.threshold == 2.0 [m/s^2]);
    }

    verification VerifyMinDuration {
        subject sensor : FreeFallSensor;
        objective {
            doc /* Confirm minimum duration is 100 ms. */
        }
        return pass : Boolean = (sensor.detector.minDuration == 100 [ms]);
    }

    verification VerifyLoggerCapacity {
        subject sensor : FreeFallSensor;
        objective {
            doc /* Confirm logger capacity is 1000 events. */
        }
        return pass : Boolean = (sensor.logger.maxEvents == 1000);
    }
}
