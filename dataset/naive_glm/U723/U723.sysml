package ImpactSensingUnit {
    import ScalarValues::*;

    // ============================================
    // Value Types
    // ============================================
    valueType AccelerationG :> Real {
        doc /* Acceleration measured in gravitational units (g) */
    }

    valueType AccelerationMs2 :> Real {
        doc /* Acceleration measured in meters per second squared (m/s^2) */
    }

    valueType TimestampMs :> Integer {
        doc /* Timestamp in milliseconds since power-on */
    }

    valueType SamplingRateHz :> Real {
        doc /* Sampling rate in Hertz (samples per second) */
    }

    valueType ResponseTimeMs :> Real {
        doc /* Response time in milliseconds */
    }

    valueType ThresholdG :> Real {
        doc /* Impact detection threshold in g */
    }

    // ============================================
    // Data Structures
    // ============================================
    item def AccelerationVector {
        doc /* Three-dimensional acceleration vector */
        attribute x : AccelerationMs2;
        attribute y : AccelerationMs2;
        attribute z : AccelerationMs2;
    }

    item def RawAccelerationSample {
        doc /* Raw noisy acceleration sample from the accelerometer */
        attribute value : AccelerationVector;
        attribute timestamp : TimestampMs;
    }

    item def RefinedAccelerationSample {
        doc /* Cleaned, amplified, and calibrated acceleration sample */
        attribute value : AccelerationVector;
        attribute magnitude : AccelerationMs2;
        attribute timestamp : TimestampMs;
    }

    item def ImpactEventData {
        doc /* Detailed data packet for an impact event */
        attribute eventId : Integer;
        attribute magnitude : AccelerationMs2;
        attribute direction : AccelerationVector;
        attribute timestamp : TimestampMs;
    }

    // ============================================
    // Port Definitions
    // ============================================
    port def RawAccelOutPort {
        out item rawSamples : RawAccelerationSample;
    }

    port def RawAccelInPort {
        in item rawSamples : RawAccelerationSample;
    }

    port def RefinedAccelOutPort {
        out item refinedSamples : RefinedAccelerationSample;
    }

    port def RefinedAccelInPort {
        in item refinedSamples : RefinedAccelerationSample;
    }

    port def ImpactEventOutPort {
        out item impactEvents : ImpactEventData;
    }

    port def ImpactEventInPort {
        in item impactEvents : ImpactEventData;
    }

    port def PowerOutPort {
        out attribute voltage : Real;
        out attribute current : Real;
        attribute isPowered : Boolean = true;
    }

    port def PowerInPort {
        in attribute voltage : Real;
        in attribute current : Real;
        in attribute isPowered : Boolean;
    }

    // ============================================
    // Requirements
    // ============================================
    requirement def HighSamplingRateRequirement {
        doc /* The Impact Sensing Unit shall sample acceleration at a high rate for precision */
        attribute minSamplingRate : SamplingRateHz = 1000;
        require { minSamplingRate >= 1000 }
    }

    requirement def ImpactThresholdRequirement {
        doc /* The system shall define a threshold for what constitutes an impact */
        attribute impactThreshold : ThresholdG = 5.0;
        require { impactThreshold > 0 }
    }

    requirement def RapidResponseTimeRequirement {
        doc /* The system shall respond rapidly to ensure events are captured almost instantaneously */
        attribute maxResponseTime : ResponseTimeMs = 10;
        require { maxResponseTime <= 10 }
    }

    // ============================================
    // Component: Accelerometer
    // ============================================
    part def Accelerometer {
        doc /* Three-axis accelerometer - the primary sensing element that continuously measures acceleration */
        attribute samplingRate : SamplingRateHz = 1000;
        attribute axes : Integer = 3;
        port rawOut : RawAccelOutPort;

        action def measureAcceleration {
            doc /* Continuously measures acceleration along three axes at the configured sampling rate */
            out sample : RawAccelerationSample;
        }
    }

    // ============================================
    // Component: Signal Processor
    // ============================================
    part def SignalProcessor {
        doc /* Cleans the signal by filtering noise, amplifying, and applying calibration adjustments */
        port rawIn : RawAccelInPort;
        port refinedOut : RefinedAccelOutPort;

        action def filterNoise {
            doc /* Filters out unwanted noise from the raw signal using digital filtering */
            in raw : RawAccelerationSample;
            out filtered : RawAccelerationSample;
        }

        action def amplifySignal {
            doc /* Amplifies the filtered signal for clarity */
            in filtered : RawAccelerationSample;
            out amplified : RawAccelerationSample;
        }

        action def applyCalibration {
            doc /* Applies calibration adjustments to ensure accuracy of the measured acceleration */
            in amplified : RawAccelerationSample;
            out refined : RefinedAccelerationSample;
        }

        action def processSignal {
            doc /* Full signal processing pipeline: filter noise, amplify, calibrate */
            in raw : RawAccelerationSample;
            out refined : RefinedAccelerationSample;
        }
    }

    // ============================================
    // Component: Impact Detector
    // ============================================
    part def ImpactDetector {
        doc /* Decision-making brain of the sensor - calculates magnitude, compares against threshold, registers impact events */
        attribute sensitivityThreshold : ThresholdG = 5.0;
        attribute responseTime : ResponseTimeMs = 8;
        attribute eventCounter : Integer = 0;
        port refinedIn : RefinedAccelInPort;
        port eventOut : ImpactEventOutPort;

        action def calculateMagnitude {
            doc /* Calculates the magnitude of the incoming acceleration vector */
            in value : AccelerationVector;
            out magnitude : AccelerationMs2;
        }

        action def compareThreshold {
            doc /* Compares acceleration magnitude against the pre-set sensitivity threshold */
            in magnitude : AccelerationMs2;
            out isImpact : Boolean;
        }

        action def createImpactEvent {
            doc /* Creates a detailed data packet including magnitude, direction, and precise timestamp */
            in magnitude : AccelerationMs2;
            in direction : AccelerationVector;
            in timestamp : TimestampMs;
            out event : ImpactEventData;
        }

        state def ImpactDetectionStateMachine {
            state idle initial {
                doc /* Powered but not yet actively monitoring */
            }
            state monitoring {
                doc /* Continuously evaluating incoming acceleration against threshold */
            }
            state impactDetected {
                doc /* Impact threshold exceeded - creating event data packet */
            }

            transition idle -> monitoring {
                doc /* Begin continuous monitoring when system is activated */
            }
            transition monitoring -> impactDetected {
                guard { refinedIn.refinedSamples.magnitude > sensitivityThreshold }
                doc /* Register impact when acceleration magnitude exceeds the sensitivity threshold */
            }
            transition impactDetected -> monitoring {
                doc /* Return to monitoring after event data packet has been generated and emitted */
            }
        }

        exhibit state ImpactDetectionStateMachine;
    }

    // ============================================
    // Component: Power Supply
    // ============================================
    part def PowerSupply {
        doc /* Integrated power supply - powers the entire Impact Sensing Unit */
        attribute outputVoltage : Real = 3.3;
        attribute capacity_mAh : Integer = 1000;
        attribute isPowered : Boolean = true;
        port powerOut : PowerOutPort;

        action supplyPower {
            doc /* Supplies continuous power to the Impact Sensor, Data Logger, and External Data Port */
        }
    }

    // ============================================
    // Component: Data Logger
    // ============================================
    part def DataLogger {
        doc /* Onboard data logger for storage of impact events and continuous acceleration readings */
        port samplesIn : RefinedAccelInPort;
        port eventsIn : ImpactEventInPort;
        port powerIn : PowerInPort;
        attribute storageCapacity : Integer = 1000000;
        attribute storedSamples : Integer = 0;
        attribute storedEvents : Integer = 0;

        action def logSample {
            doc /* Logs a refined acceleration sample to onboard storage */
            in sample : RefinedAccelerationSample;
        }

        action def logEvent {
            doc /* Logs an impact event to onboard storage */
            in event : ImpactEventData;
        }

        action def persistData {
            doc /* Continuously persists both refined samples and impact events to storage */
        }
    }

    // ============================================
    // Component: External Data Port
    // ============================================
    part def ExternalDataPort {
        doc /* External data port for streaming information to another system for real-time monitoring or later retrieval */
        port samplesIn : RefinedAccelInPort;
        port eventsIn : ImpactEventInPort;
        port externalSamplesOut : RefinedAccelOutPort;
        port externalEventsOut : ImpactEventOutPort;
        port powerIn : PowerInPort;

        action def streamData {
            doc /* Streams both refined acceleration samples and impact events to an external system */
        }
    }

    // ============================================
    // Assembly: Impact Sensor
    // ============================================
    part def ImpactSensor {
        doc /* Modular assembly of specialized parts - core sensing component of the unit */
        part accelerometer : Accelerometer;
        part signalProcessor : SignalProcessor;
        part impactDetector : ImpactDetector;

        port refinedDataOut : RefinedAccelOutPort;
        port impactEventOut : ImpactEventOutPort;
        port powerIn : PowerInPort;

        connection accelToProcessor connect accelerometer.rawOut to signalProcessor.rawIn;
        connection processorToDetector connect signalProcessor.refinedOut to impactDetector.refinedIn;
        connection detectorToSensorOut connect impactDetector.eventOut to impactEventOut;
        connection processorToRefinedOut connect signalProcessor.refinedOut to refinedDataOut;
    }

    // ============================================
    // Top-Level: Impact Sensing Unit
    // ============================================
    part def ImpactSensingUnit {
        doc /* Self-contained compact electronic device for detecting, analyzing, and recording physical impact events such as collisions, drops, or sudden jolts */
        satisfy highSamplingRateReq : HighSamplingRateRequirement;
        satisfy impactThresholdReq : ImpactThresholdRequirement;
        satisfy rapidResponseTimeReq : RapidResponseTimeRequirement;

        part impactSensor : ImpactSensor;
        part powerSupply : PowerSupply;
        part dataLogger : DataLogger;
        part externalDataPort : ExternalDataPort;

        port externalSamplesOut : RefinedAccelOutPort;
        port externalEventsOut : ImpactEventOutPort;

        connection powerToSensor connect powerSupply.powerOut to impactSensor.powerIn;
        connection powerToLogger connect powerSupply.powerOut to dataLogger.powerIn;
        connection powerToExternal connect powerSupply.powerOut to externalDataPort.powerIn;
        connection sensorSamplesToLogger connect impactSensor.refinedDataOut to dataLogger.samplesIn;
        connection sensorEventsToLogger connect impactSensor.impactEventOut to dataLogger.eventsIn;
        connection sensorSamplesToExternal connect impactSensor.refinedDataOut to externalDataPort.samplesIn;
        connection sensorEventsToExternal connect impactSensor.impactEventOut to externalDataPort.eventsIn;
        connection externalSamplesPassthrough connect externalDataPort.externalSamplesOut to externalSamplesOut;
        connection externalEventsPassthrough connect externalDataPort.externalEventsOut to externalEventsOut;
    }
}
