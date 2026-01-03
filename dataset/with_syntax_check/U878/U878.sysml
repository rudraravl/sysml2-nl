package 'Shock Detector System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AccelerationThreshold {
        attribute value : AccelerationValue;
    }
    
    attribute def ShockMeasurement {
        attribute peakAcceleration : AccelerationValue;
        attribute duration : TimeValue;
        attribute timestamp : TimeValue;
    }
    
    enum def ShockSeverityLevel {
        none;
        minor;
        moderate;
        severe;
        critical;
    }
    
    attribute def ShockEventData {
        attribute severity : ShockSeverityLevel;
        attribute measurement : ShockMeasurement;
        attribute location : String;
    }
    
    port def AccelerationSensorPort {
        out accelerationReading : AccelerationValue;
    }
    
    port def ShockAlertPort {
        out shockEvent : ShockEventData;
    }
    
    port def ConfigurationPort {
        in thresholdSettings : AccelerationThreshold;
    }
    
    part def AccelerationSensor {
        doc /* Measures acceleration in three axes and outputs magnitude. */
        
        attribute samplingFrequency : FrequencyValue;
        attribute measurementRange : AccelerationValue;
        
        port sensorOutput : AccelerationSensorPort;
        
        action def MeasureAcceleration {
            out xAxis : AccelerationValue;
            out yAxis : AccelerationValue;
            out zAxis : AccelerationValue;
            out magnitude : AccelerationValue;
        }
        
        perform action continuousMeasurement {
            first start;
            then merge measureLoop;
            action measure : MeasureAcceleration;
            then measureLoop;
        }
    }
    
    part def SignalConditioner {
        doc /* Filters and processes raw acceleration signals. */
        
        port rawInput : ~AccelerationSensorPort;
        port conditionedOutput : AccelerationSensorPort;
        
        attribute filterFrequency : FrequencyValue;
        
        action def ApplyLowPassFilter {
            in rawSignal : AccelerationValue;
            out filteredSignal : AccelerationValue;
        }
        
        action def RemoveNoise {
            in signal : AccelerationValue;
            out cleanSignal : AccelerationValue;
        }
        
        perform action conditionSignal {
            first start;
            then merge conditionLoop;
            action filterAction : ApplyLowPassFilter;
            then action denoiseAction : RemoveNoise {
                in signal = filterAction.filteredSignal;
            }
            then conditionLoop;
        }
    }
    
    part def ShockDetectionProcessor {
        doc /* Analyzes conditioned signals and detects shock events. */
        
        port signalInput : ~AccelerationSensorPort;
        port configInput : ~ConfigurationPort;
        port eventOutput : ShockAlertPort;
        
        attribute minorThreshold : AccelerationValue;
        attribute moderateThreshold : AccelerationValue;
        attribute severeThreshold : AccelerationValue;
        attribute criticalThreshold : AccelerationValue;
        attribute minimumDuration : TimeValue;
        
        action def ClassifyShock {
            in acceleration : AccelerationValue;
            in duration : TimeValue;
            out severity : ShockSeverityLevel;
        }
        
        action def CreateShockEvent {
            in measurement : ShockMeasurement;
            in severity : ShockSeverityLevel;
            out event : ShockEventData;
        }
        
        state machine ShockDetectionStateMachine {
            initial state Idle;
            
            state Monitoring {
                doc /* Continuously monitoring acceleration levels. */
            }
            
            state ShockDetected {
                doc /* Shock event has been detected and is being processed. */
            }
            
            state EventProcessing {
                doc /* Classifying and creating shock event data. */
            }
            
            transition from Idle to Monitoring;
            
            transition from Monitoring to ShockDetected;
            
            transition from ShockDetected to EventProcessing;
            
            transition from EventProcessing to Monitoring;
        }
        
        perform action detectShocks {
            first start;
            then merge monitoringLoop;
            
            action readAcceleration {
                out currentAccel : AccelerationValue;
                out currentTime : TimeValue;
            }
            
            then decide;
                if readAcceleration.currentAccel >= minorThreshold then analyzeShock;
                if readAcceleration.currentAccel < minorThreshold then monitoringLoop;
            
            action analyzeShock {
                action classify : ClassifyShock {
                    in acceleration = readAcceleration.currentAccel;
                    out severity;
                }
                then action createEvent : CreateShockEvent {
                    in severity = classify.severity;
                    out event;
                }
                then action emitEvent {
                    out shockAlert : ShockEventData;
                }
            }
            
            then monitoringLoop;
        }
    }
    
    part def EventLogger {
        doc /* Records all shock events for historical analysis. */
        
        port eventInput : ~ShockAlertPort;
        
        attribute eventHistory : ShockEventData[*];
        attribute maxStorageCapacity : Real;
        
        action def LogEvent {
            in event : ShockEventData;
            inout history : ShockEventData[*];
        }
        
        action def RetrieveEvents {
            in startTime : TimeValue;
            in endTime : TimeValue;
            out events : ShockEventData[*];
        }
        
        perform action recordEvents {
            first start;
            then merge recordLoop;
            accept incomingEvent : ShockEventData;
            then action log : LogEvent {
                in event = incomingEvent;
                inout history = eventHistory;
            }
            then recordLoop;
        }
    }
    
    part def AlertNotificationSystem {
        doc /* Provides visual, audible, and remote notifications of shock events. */
        
        port alertInput : ~ShockAlertPort;
        
        attribute activeAlerts : ShockEventData[*];
        
        action def ActivateVisualIndicator {
            in event : ShockEventData;
        }
        
        action def ActivateAudibleAlarm {
            in event : ShockEventData;
        }
        
        action def SendRemoteNotification {
            in event : ShockEventData;
            out message : String;
        }
        
        perform action handleAlerts {
            first start;
            then merge alertLoop;
            accept shockEvent : ShockEventData;
            then decide;
                if shockEvent.severity == ShockSeverityLevel::minor then minorAlert;
                if shockEvent.severity == ShockSeverityLevel::moderate then moderateAlert;
                if shockEvent.severity == ShockSeverityLevel::severe then severeAlert;
                if shockEvent.severity == ShockSeverityLevel::critical then criticalAlert;
            
            action minorAlert {
                action visual : ActivateVisualIndicator {
                    in event = shockEvent;
                }
            }
            then alertLoop;
            
            action moderateAlert {
                action visual : ActivateVisualIndicator {
                    in event = shockEvent;
                }
                then action audio : ActivateAudibleAlarm {
                    in event = shockEvent;
                }
            }
            then alertLoop;
            
            action severeAlert {
                action visual : ActivateVisualIndicator {
                    in event = shockEvent;
                }
                then action audio : ActivateAudibleAlarm {
                    in event = shockEvent;
                }
                then action remote : SendRemoteNotification {
                    in event = shockEvent;
                }
            }
            then alertLoop;
            
            action criticalAlert {
                action visual : ActivateVisualIndicator {
                    in event = shockEvent;
                }
                then action audio : ActivateAudibleAlarm {
                    in event = shockEvent;
                }
                then action remote : SendRemoteNotification {
                    in event = shockEvent;
                }
            }
            then alertLoop;
        }
    }
    
    part def ShockDetectorSystem {
        doc /* 
        A comprehensive shock detection system that continuously monitors physical impacts 
        and sudden accelerations. Its primary function is to sense acceleration forces across 
        multiple axes, process and filter the signals, detect shock events exceeding configurable 
        thresholds, classify their severity levels, maintain a complete historical record, and 
        provide immediate multi-level alerts to protect equipment, ensure safety, and enable 
        post-event analysis.
        */
        
        part sensor : AccelerationSensor {
            attribute :>> samplingFrequency = 1000.0 [Hz];
            attribute :>> measurementRange = 200.0 [m/(s^2)];
        }
        
        part conditioner : SignalConditioner {
            attribute :>> filterFrequency = 50.0 [Hz];
        }
        
        part processor : ShockDetectionProcessor {
            attribute :>> minorThreshold = 10.0 [m/(s^2)];
            attribute :>> moderateThreshold = 30.0 [m/(s^2)];
            attribute :>> severeThreshold = 60.0 [m/(s^2)];
            attribute :>> criticalThreshold = 100.0 [m/(s^2)];
            attribute :>> minimumDuration = 0.005 [s];
        }
        
        part logger : EventLogger {
            attribute :>> maxStorageCapacity = 50000.0;
        }
        
        part notifier : AlertNotificationSystem;
        
        connect sensor.sensorOutput to conditioner.rawInput;
        connect conditioner.conditionedOutput to processor.signalInput;
        connect processor.eventOutput to logger.eventInput;
        connect processor.eventOutput to notifier.alertInput;
        
        perform action operateShockDetection {
            doc /* 
            The shock detector system operates continuously to protect assets and personnel.
            It measures acceleration, conditions signals to remove noise, analyzes data against
            severity thresholds, logs all events for compliance and analysis, and triggers
            appropriate alerts based on shock severity to enable rapid response.
            */
            
            first start;
            then action initialize {
                action configureSensor;
                then action setThresholds;
                then action prepareLogging;
                then action testAlerts;
            }
            then merge operationalCycle;
            
            action monitorAndRespond {
                action sensing references sensor.continuousMeasurement;
                then action conditioning references conditioner.conditionSignal;
                then action detection references processor.detectShocks;
                then action logging references logger.recordEvents;
                then action alerting references notifier.handleAlerts;
            }
            
            then operationalCycle;
        }
    }
    
    requirement <'SDS-REQ-001'> shockDetectionCapability {
        doc /* 
        The system shall detect shock events with peak acceleration exceeding 10 m/s²
        and duration greater than 5 milliseconds across all three axes.
        */
        
        subject detectionSystem : ShockDetectorSystem;
        
        require constraint {
            detectionSystem.processor.minorThreshold <= 10.0 [m/(s^2)]
        }
        
        require constraint {
            detectionSystem.processor.minimumDuration <= 0.005 [s]
        }
    }
    
    requirement <'SDS-REQ-002'> severityClassification {
        doc /* 
        The system shall classify detected shocks into at least four severity levels
        based on peak acceleration magnitude.
        */
        
        subject classificationSystem : ShockDetectorSystem;
    }
    
    requirement <'SDS-REQ-003'> responseTimeRequirement {
        doc /* 
        The system shall generate an alert within 50 milliseconds of detecting
        a shock event exceeding the moderate threshold.
        */
        
        subject responseSystem : ShockDetectorSystem;
    }
    
    requirement <'SDS-REQ-004'> dataRetention {
        doc /* 
        The system shall maintain a persistent log of at least 50,000 shock events
        including timestamp, severity, peak acceleration, duration, and location.
        */
        
        subject loggingSystem : ShockDetectorSystem;
        
        require constraint {
            loggingSystem.logger.maxStorageCapacity >= 50000.0
        }
    }
    
    requirement <'SDS-REQ-005'> multiLevelAlerting {
        doc /* 
        The system shall provide differentiated alert mechanisms based on shock severity,
        including visual indicators for minor events, audible alarms for moderate events,
        and remote notifications for severe and critical events.
        */
        
        subject alertingSystem : ShockDetectorSystem;
    }
    
    requirement systemRequirements {
        doc /* 
        Top-level requirements for the shock detector system encompassing detection,
        classification, response, logging, and alerting capabilities.
        */
        
        require shockDetectionCapability;
        require severityClassification;
        require responseTimeRequirement;
        require dataRetention;
        require multiLevelAlerting;
    }
    
    part shockDetectorSystem : ShockDetectorSystem;
}
