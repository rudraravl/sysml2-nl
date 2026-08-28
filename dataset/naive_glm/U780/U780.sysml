package MotionDetectionSystem {
    import ScalarValues::*;

    // ================================================
    // Value Types with Units
    // ================================================

    value type DistanceValue = Real {
        doc "Distance in meters";
        unit m;
    }

    value type PercentValue = Real {
        doc "Percentage value from 0 to 100";
        unit percent;
    }

    value type DurationValue = Real {
        doc "Duration in seconds";
        unit s;
    }

    value type TimestampValue = Real {
        doc "Timestamp in seconds since system epoch";
        unit s;
    }

    value type SignalAmplitudeValue = Real {
        doc "Signal amplitude in volts";
        unit V;
    }

    value type FrequencyValue = Real {
        doc "Frequency in hertz";
        unit Hz;
    }

    value type SensitivityValue = Real {
        doc "Sensitivity setting in percent";
        unit percent;
    }

    value type ThresholdValue = Real {
        doc "Noise threshold in percent";
        unit percent;
    }

    value type PowerValue = Real {
        doc "Power consumption in watts";
        unit W;
    }

    // ================================================
    // Enumeration
    // ================================================

    enum SeverityLevel {
        low;
        medium;
        high;
    }

    // ================================================
    // Item Definitions
    // ================================================

    item def MotionSignal {
        doc "Raw motion signal produced by the PIR sensor";
        attribute amplitude : SignalAmplitudeValue;
        attribute frequency : FrequencyValue;
        attribute duration : DurationValue;
        attribute timestamp : TimestampValue;
    }

    item def AnalysisResult {
        doc "Result of signal analysis indicating whether motion is genuine";
        attribute isGenuine : Boolean;
        attribute confidence : PercentValue;
        attribute timestamp : TimestampValue;
    }

    item def AlertSignal {
        doc "Formal alert signal sent to the security monitoring system";
        attribute eventTime : TimestampValue;
        attribute confidence : PercentValue;
        attribute severity : SeverityLevel;
    }

    // ================================================
    // Port Definitions
    // ================================================

    port def MotionOutPort {
        out signal : MotionSignal;
    }

    port def MotionInPort {
        in signal : MotionSignal;
    }

    port def AnalysisOutPort {
        out result : AnalysisResult;
    }

    port def AnalysisInPort {
        in result : AnalysisResult;
    }

    port def AlertOutPort {
        out alert : AlertSignal;
    }

    // ================================================
    // Action Definitions
    // ================================================

    action def DetectMotion {
        doc "Detect motion using the PIR sensor based on infrared radiation changes";
        in range : DistanceValue;
        in sensitivity : SensitivityValue;
        in noiseFloor : SignalAmplitudeValue;
        out motion : MotionSignal;
    }

    action def AnalyzeSignal {
        doc "Analyze the raw motion signal against a noise threshold to determine if motion is genuine";
        in rawSignal : MotionSignal;
        in noiseThreshold : ThresholdValue;
        in sampleWindow : DurationValue;
        out result : AnalysisResult;
    }

    action def GenerateAlert {
        doc "Generate a formal alert signal if the detection confidence exceeds the minimum threshold";
        in result : AnalysisResult;
        in minConfidence : PercentValue;
        out alert : AlertSignal;
    }

    // ================================================
    // Part Definition: PIR Sensor
    // ================================================

    part def PIRSensor {
        doc "Passive infrared sensor. Acts as the primary detector, sensing changes in infrared radiation caused by movement such as a person walking by. Range and sensitivity are adjustable.";

        attribute detectionRange : DistanceValue = 12 [m];
        attribute sensitivity : SensitivityValue = 75 [%];
        attribute noiseFloor : SignalAmplitudeValue = 0.1 [V];
        attribute powerConsumption : PowerValue = 0.5 [W];

        port output : MotionOutPort;

        action detect : DetectMotion {
            in range = detectionRange;
            in sensitivity = sensitivity;
            in noiseFloor = noiseFloor;
            out motion = output.signal;
        }
    }

    // ================================================
    // Part Definition: Signal Analyzer
    // ================================================

    part def SignalAnalyzer {
        doc "Signal analyzer responsible for determining if a detected signal is genuine motion or environmental noise such as a gust of wind. Analyzes signal characteristics against a pre-set noise threshold and calculates a confidence level.";

        attribute noiseThreshold : ThresholdValue = 30 [%];
        attribute minConfidence : PercentValue = 80 [%];
        attribute sampleWindow : DurationValue = 5 [s];

        port input : MotionInPort;
        port output : AnalysisOutPort;

        action analyze : AnalyzeSignal {
            in rawSignal = input.signal;
            in noiseThreshold = noiseThreshold;
            in sampleWindow = sampleWindow;
            out result = output.result;
        }
    }

    // ================================================
    // Part Definition: Alert Generator
    // ================================================

    part def AlertGenerator {
        doc "Alert generator that creates and sends a formal alert signal specifying the time of the event, the confidence in the detection, and a severity level (low, medium, or high).";

        attribute minConfidence : PercentValue = 80 [%];

        port input : AnalysisInPort;
        port output : AlertOutPort;

        action generate : GenerateAlert {
            in result = input.result;
            in minConfidence = minConfidence;
            out alert = output.alert;
        }
    }

    // ================================================
    // Top-Level System: MotionDetector
    // ================================================

    part MotionDetector {
        doc "Automated motion detection system for security and surveillance. Continuously monitors a specific area using a PIR sensor and intelligently analyzes signals to avoid false alarms before issuing an alert.";

        attribute systemName : String = "MotionGuard Pro";
        attribute operationalRange : DistanceValue = 12 [m];
        attribute minDetectionRange : DistanceValue = 10 [m];
        attribute requiredConfidence : PercentValue = 80 [%];

        // State machine trigger flags
        attribute isPowered : Boolean = false;
        attribute motionDetected : Boolean = false;
        attribute analysisComplete : Boolean = false;
        attribute motionConfirmed : Boolean = false;
        attribute alertDispatched : Boolean = false;

        // ---- Component Parts ----

        part pirSensor : PIRSensor {
            doc "Primary PIR detector with adjustable range and sensitivity";
            :>> detectionRange = operationalRange;
            :>> sensitivity = 80 [%];
            :>> noiseFloor = 0.08 [V];
        }

        part signalAnalyzer : SignalAnalyzer {
            doc "Intelligent signal analyzer with noise threshold and confidence calculation";
            :>> noiseThreshold = 25 [%];
            :>> minConfidence = requiredConfidence;
            :>> sampleWindow = 3 [s];
        }

        part alertGenerator : AlertGenerator {
            doc "Alert generation component producing formal alert signals";
            :>> minConfidence = requiredConfidence;
        }

        // ---- Inter-Component Connections ----

        connection pirToAnalyzer from pirSensor.output to signalAnalyzer.input;
        connection analyzerToAlert from signalAnalyzer.output to alertGenerator.input;

        // ---- External Port ----

        port alertOut : AlertOutPort;
        connection alertDispatchConn from alertGenerator.output to alertOut;

        // ---- System State Machine ----

        state machine MotionDetectionStateMachine {
            doc "The system operates through four states: standby (power-saving), active (monitoring), detecting (processing a signal), and alerting (sending a notification).";

            initial init;

            state standby {
                doc "Power-saving standby mode. The system is not actively monitoring.";
                entry {
                    isPowered = false;
                }
                do {
                    // Maintain low-power state, await activation command
                }
            }

            state active {
                doc "Active monitoring state. The system is actively monitoring the area for motion.";
                entry {
                    isPowered = true;
                    motionDetected = false;
                }
                do {
                    // Continuously monitor PIR sensor output for motion signals
                }
                exit {
                    motionDetected = false;
                }
            }

            state detecting {
                doc "Detecting state. The system is processing a potential motion signal through the signal analyzer.";
                entry {
                    analysisComplete = false;
                    motionConfirmed = false;
                }
                do {
                    // PIR sensor detects motion and sends raw signal to analyzer
                    pirSensor.detect;
                    // Signal analyzer processes the signal and produces a result
                    signalAnalyzer.analyze;
                    // Evaluate analysis result against confidence threshold
                    motionConfirmed = signalAnalyzer.output.result.isGenuine
                        && signalAnalyzer.output.result.confidence >= requiredConfidence;
                }
                exit {
                    analysisComplete = true;
                }
            }

            state alerting {
                doc "Alerting state. The system is dispatching a formal alert notification.";
                entry {
                    alertDispatched = false;
                }
                do {
                    // Generate and send alert through the alert generator
                    alertGenerator.generate;
                }
                exit {
                    alertDispatched = true;
                    motionConfirmed = false;
                    motionDetected = false;
                }
            }

            // ---- Transitions ----

            transition init_to_standby from init to standby;

            transition standby_to_active from standby to active when isPowered;

            transition active_to_detecting from active to detecting when motionDetected;

            transition detecting_to_alerting from detecting to alerting
                when analysisComplete && motionConfirmed;

            transition detecting_to_active from detecting to active
                when analysisComplete && !motionConfirmed;

            transition alerting_to_active from alerting to active when alertDispatched;

            transition active_to_standby from active to standby when !isPowered;
        }
    }

    // ================================================
    // Requirements
    // ================================================

    requirement OperationalRangeRequirement {
        doc "The system shall have an operational detection range of at least 10 meters.";
        subject detector : MotionDetector;
        attribute minimumRange : DistanceValue = 10 [m];
        constraint { detector.operationalRange >= minimumRange }
    }

    requirement PIRDetectionRequirement {
        doc "The system shall use a passive infrared sensor as the primary detector to sense changes in infrared radiation caused by movement such as a person walking by.";
        subject detector : MotionDetector;
        attribute minSensorRange : DistanceValue = 10 [m];
        constraint { detector.pirSensor.detectionRange >= minSensorRange }
    }

    requirement AdjustableSensitivityRequirement {
        doc "The range and sensitivity of the PIR sensor shall be adjustable.";
        subject sensor : PIRSensor;
        constraint { sensor.sensitivity > 0 [%] && sensor.sensitivity <= 100 [%] }
    }

    requirement FalseAlarmAvoidanceRequirement {
        doc "The system shall analyze detected signals against a noise threshold to distinguish genuine motion from environmental noise such as a gust of wind.";
        subject analyzer : SignalAnalyzer;
        attribute maxNoiseThreshold : ThresholdValue = 35 [%];
        constraint { analyzer.noiseThreshold <= maxNoiseThreshold }
    }

    requirement ConfidenceThresholdRequirement {
        doc "The system shall only trigger an alert when the confidence level of the detection exceeds a required minimum of 80 percent.";
        subject detector : MotionDetector;
        attribute minimumConfidence : PercentValue = 80 [%];
        constraint { detector.requiredConfidence >= minimumConfidence }
    }

    requirement AlertContentRequirement {
        doc "The alert signal shall specify the time of the event, the confidence in the detection, and a severity level of low, medium, or high.";
        subject alert : AlertSignal;
        constraint { alert.eventTime >= 0 [s] }
        constraint { alert.confidence >= 0 [%] && alert.confidence <= 100 [%] }
    }

    requirement StateBasedOperationRequirement {
        doc "The system shall operate through standby, active, detecting, and alerting states, transitioning based on system events and detection results.";
        subject detector : MotionDetector;
    }

    requirement DetectionAccuracyRequirement {
        doc "The system shall achieve a high degree of accuracy in its detections to ensure reliable security and surveillance operation.";
        subject detector : MotionDetector;
        attribute minAccuracy : PercentValue = 95 [%];
    }

    requirement ContinuousMonitoringRequirement {
        doc "The system shall continuously monitor the specified area while in the active state.";
        subject detector : MotionDetector;
        constraint { detector.operationalRange >= 10 [m] }
    }

    // ================================================
    // Verification Assignments
    // ================================================

    assignment OperationalRangeVerification {
        requirement OperationalRangeRequirement;
        subject detector = MotionDetector;
        constraint { MotionDetector.operationalRange >= 10 [m] }
    }

    assignment PIRDetectionVerification {
        requirement PIRDetectionRequirement;
        subject detector = MotionDetector;
        constraint { MotionDetector.pirSensor.detectionRange >= 10 [m] }
    }

    assignment ConfidenceThresholdVerification {
        requirement ConfidenceThresholdRequirement;
        subject detector = MotionDetector;
        constraint { MotionDetector.requiredConfidence >= 80 [%] }
    }
}
