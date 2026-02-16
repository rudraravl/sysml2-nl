package MotionDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DetectionRange :> LengthValue;
    attribute def SensitivityLevel :> Real;
    attribute def ConfidenceLevel :> Real;
    
    item def MotionSignal {
        attribute intensity : Real;
        attribute timestamp : TimeValue;
        attribute detectionDistance : DetectionRange;
    }
    
    item def AlertSignal {
        attribute severity : AlertLevel;
        attribute confidence : ConfidenceLevel;
        attribute detectionTime : TimeValue;
    }
    
    enum def AlertLevel {
        enum low;
        enum medium;
        enum high;
    }
    
    enum def SystemState {
        enum standby;
        enum active;
        enum detecting;
        enum alerting;
    }
    
    port def SensorOutputPort {
        out signal : MotionSignal;
    }
    
    port def AlertOutputPort {
        out alert : AlertSignal;
    }
    
    port def ControlInputPort {
        in sensitivity : SensitivityLevel;
        in enable : Boolean;
        out status : SystemState;
    }
    
    part def PIRSensor {
        attribute detectionRange : DetectionRange;
        attribute sensitivity : SensitivityLevel;
        port sensorOut : SensorOutputPort;
        
        action def SenseMotion {
            out detectedSignal : MotionSignal;
        }
    }
    
    part def SignalAnalyzer {
        attribute noiseThreshold : Real;
        attribute confidenceThreshold : ConfidenceLevel;
        
        action def AnalyzeMotionSignal {
            in rawSignal : MotionSignal;
            in sensitivitySetting : SensitivityLevel;
            out confidence : ConfidenceLevel;
            out motionConfirmed : Boolean;
        }
    }
    
    part def AlertGenerator {
        attribute minimumConfidence : ConfidenceLevel;
        port alertOut : AlertOutputPort;
        
        action def GenerateAlert {
            in confidence : ConfidenceLevel;
            in timestamp : TimeValue;
            out alertSignal : AlertSignal;
        }
    }
    
    part def MotionDetector {
        doc /* A motion detection system that continuously monitors an area for movement,
             analyzes detected signals to filter false positives, and generates alerts
             when motion is confirmed with sufficient confidence. */
        
        attribute operatingRange : DetectionRange = 15.0 [m];
        attribute systemSensitivity : SensitivityLevel = 0.75;
        attribute minConfidence : ConfidenceLevel = 0.80;
        
        port controlPort : ControlInputPort;
        port alertPort : AlertOutputPort;
        
        part sensor : PIRSensor {
            :>> detectionRange = operatingRange;
            :>> sensitivity = systemSensitivity;
        }
        
        part analyzer : SignalAnalyzer {
            :>> noiseThreshold = 0.15;
            :>> confidenceThreshold = minConfidence;
        }
        
        part alertGen : AlertGenerator {
            :>> minimumConfidence = minConfidence;
        }
        
        connection sensorToAnalyzer connect sensor.sensorOut to analyzer;
        connection analyzerToAlert connect analyzer to alertGen;
        binding alertPort = alertGen.alertOut;
        
        action motionDetectionBehavior : MonitorAndAlert {
            in systemEnabled = controlPort.enable;
            in sensitivityConfig = controlPort.sensitivity;
            out systemStatus : SystemState;
            out generatedAlert = alertPort.alert;
        }
        
        perform motionDetectionBehavior;
    }
    
    action def MonitorAndAlert {
        in systemEnabled : Boolean;
        in sensitivityConfig : SensitivityLevel;
        out systemStatus : SystemState;
        out generatedAlert : AlertSignal;
        
        first start;
        then merge checkEnabled;
        
        action checkEnabled {
            decide;
                if systemEnabled then activateMonitoring;
                if !systemEnabled then enterStandby;
        }
        
        action enterStandby {
            assign systemStatus := SystemState::standby;
        }
        then checkEnabled;
        
        action activateMonitoring {
            assign systemStatus := SystemState::active;
        }
        then captureSignal;
        
        action captureSignal : PIRSensor::SenseMotion {
            out detectedSignal : MotionSignal;
        }
        then assign systemStatus := SystemState::detecting;
        then analyzeSignal;
        
        action analyzeSignal : SignalAnalyzer::AnalyzeMotionSignal {
            in rawSignal = captureSignal.detectedSignal;
            in sensitivitySetting = sensitivityConfig;
            out confidence : ConfidenceLevel;
            out motionConfirmed : Boolean;
        }
        then evaluateConfidence;
        
        action evaluateConfidence {
            decide;
                if analyzeSignal.motionConfirmed && analyzeSignal.confidence >= 0.80
                    then issueAlert;
                else then continueMonitoring;
        }
        
        action issueAlert {
            assign systemStatus := SystemState::alerting;
        }
        then createAlert;
        
        action createAlert : AlertGenerator::GenerateAlert {
            in confidence = analyzeSignal.confidence;
            in timestamp : TimeValue;
            out alertSignal : AlertSignal;
        }
        then assign generatedAlert := createAlert.alertSignal;
        then continueMonitoring;
        
        action continueMonitoring;
        then checkEnabled;
    }
    
    requirement def DetectionPerformanceRequirement {
        doc /* The motion detector shall achieve minimum detection confidence
             of 80% for motion within the operational range. */
        
        subject detector : MotionDetector;
        
        require constraint {
            detector.minConfidence >= 0.80
        }
    }
    
    requirement def RangeRequirement {
        doc /* The motion detector shall reliably detect motion within
             a minimum range of 10 meters. */
        
        subject detector : MotionDetector;
        
        require constraint {
            detector.operatingRange >= 10.0 [m]
        }
    }
    
    requirement def ResponseRequirement {
        doc /* The motion detector shall analyze and respond to detected
             motion within 500 milliseconds. */
        
        subject detector : MotionDetector;
        
        require constraint {
            detector.analyzer.noiseThreshold <= 0.20
        }
    }
    
    requirement <'MD-001'> motionDetectionSystemRequirement {
        doc /* The motion detection system shall continuously monitor a designated area,
             detect movement using passive infrared sensing, analyze signals to determine
             motion confidence, and generate alerts when motion is confirmed above the
             confidence threshold, enabling automated security and surveillance applications. */
        
        subject system : MotionDetector;
        
        require DetectionPerformanceRequirement;
        require RangeRequirement;
        require ResponseRequirement;
    }
    
    part systemContext : MotionDetector {
        attribute :>> operatingRange = 12.0 [m];
        attribute :>> systemSensitivity = 0.80;
        attribute :>> minConfidence = 0.85;
    }
}
