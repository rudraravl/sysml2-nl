package HorizonScanningSystemModel {
    private import ScalarValues::*;
    private import SI::*;

    attribute def Distance :> Real { unit :> SI::m; }
    attribute def Speed :> Real { unit :> SI::m_per_s; }
    attribute def Angle :> Real { unit :> SI::rad; }
    attribute def TimePoint :> Real { unit :> SI::s; }
    attribute def Duration :> Real { unit :> SI::s; }
    attribute def Probability :> Real;

    item def Position {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
    }

    item def Velocity {
        attribute vx : Speed;
        attribute vy : Speed;
        attribute vz : Speed;
    }

    item def DetectionReport {
        attribute sensorId : String;
        attribute timestamp : TimePoint;
        attribute range : Distance;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute signalStrength : Real;
        attribute signalToNoiseRatio : Real;
        attribute position : Position;
    }

    item def ScanCommand {
        attribute sectorStartAzimuth : Angle;
        attribute sectorEndAzimuth : Angle;
        attribute sectorStartElevation : Angle;
        attribute sectorEndElevation : Angle;
        attribute dwellTime : Duration;
    }

    item def Track {
        attribute trackId : Integer;
        attribute trackState : String;
        attribute position : Position;
        attribute velocity : Velocity;
        attribute lastUpdateTime : TimePoint;
        attribute confidence : Probability;
    }

    item def Classification {
        attribute targetClass : String;
        attribute confidence : Probability;
        attribute signatureId : String;
    }

    item def ClassifiedTrack :> Track {
        attribute classification : Classification;
    }

    item def ThreatAssessment {
        attribute trackId : Integer;
        attribute classification : Classification;
        attribute threatLevel : Integer;
        attribute criticality : String;
        attribute recommendedResponse : String;
        attribute assessmentTime : TimePoint;
    }

    item def Alert {
        attribute alertId : Integer;
        attribute alertTime : TimePoint;
        attribute priority : Integer;
        attribute alertText : String;
        attribute associatedTrackId : Integer;
    }

    item def ThreatSignature {
        attribute signatureId : String;
        attribute radarCrossSection : Real;
        attribute irSignature : Real;
        attribute visualSignature : String;
        attribute knownClass : String;
        attribute defaultThreatLevel : Integer;
    }

    item def OperatorCommand {
        attribute commandType : String;
        attribute payload : String;
    }

    attribute def StartScanningSignal;
    attribute def CalibrationCompleteSignal;
    attribute def StopScanningSignal;
    attribute def FailureSignal;
    attribute def ClearFaultSignal;

    state def SystemStates {
        entry; then standby;
        state standby;
        accept StartScanningSignal then initializing;
        state initializing;
        accept CalibrationCompleteSignal then activeScanning;
        state activeScanning;
        accept StopScanningSignal then standby;
        accept FailureSignal then faulted;
        state faulted;
        accept ClearFaultSignal then standby;
    }

    action def CoordinateScan {
        out radarCommand : ScanCommand;
        out eoCommand : ScanCommand;
        out irCommand : ScanCommand;
        language "Alf"
            /*
             * Compute the next horizon sector and generate synchronized scan commands for all sensors.
             */
    }

    action def PerformRadarScan {
        in command : ScanCommand;
        out detections : DetectionReport[0..*];
        language "Alf"
            /*
             * Emit radar pulses, receive returns, and form detection reports.
             */
    }

    action def PerformEOScan {
        in command : ScanCommand;
        out detections : DetectionReport[0..*];
        language "Alf"
            /*
             * Steer the electro-optical sensor, capture visual images, and extract detections.
             */
    }

    action def PerformIRScan {
        in command : ScanCommand;
        out detections : DetectionReport[0..*];
        language "Alf"
            /*
             * Steer the infrared sensor, capture thermal images, and extract detections.
             */
    }

    action def FuseSensorData {
        in radarDetections : DetectionReport[0..*];
        in eoDetections : DetectionReport[0..*];
        in irDetections : DetectionReport[0..*];
        out fusedTracks : Track[0..*];
        language "Alf"
            /*
             * Correlate detections across sensor modalities, maintain kinematic tracks, and reduce false alarms.
             */
    }

    action def ClassifyTargets {
        in tracks : Track[0..*];
        in signatures : ThreatSignature[1..*];
        out classifiedTracks : ClassifiedTrack[0..*];
        language "Alf"
            /*
             * Compare track features against known signatures and assign classifications with confidence.
             */
    }

    action def EvaluateThreats {
        in classifiedTracks : ClassifiedTrack[0..*];
        out assessments : ThreatAssessment[0..*];
        out alerts : Alert[0..*];
        language "Alf"
            /*
             * Assess threat level based on classification, kinematics, and rules of engagement.
             */
    }

    action def SurveillanceCycle {
        first start;
        then action coordinate : CoordinateScan;
        then fork;
            action radarScan : PerformRadarScan { in command = coordinate.radarCommand; }
            action eoScan : PerformEOScan { in command = coordinate.eoCommand; }
            action irScan : PerformIRScan { in command = coordinate.irCommand; }
        then join;
        then action fuse : FuseSensorData {
            in radarDetections = radarScan.detections;
            in eoDetections = eoScan.detections;
            in irDetections = irScan.detections;
        }
        then action classify : ClassifyTargets {
            in tracks = fuse.fusedTracks;
        }
        then action evaluate : EvaluateThreats {
            in classifiedTracks = classify.classifiedTracks;
        }
        then done;
    }

    part def Radar {
        attribute maxRange : Distance = 75000.0;
        in port command : ScanCommand;
        out port detections : DetectionReport[0..*];
    }

    part def ElectroOpticalSensor {
        in port command : ScanCommand;
        out port detections : DetectionReport[0..*];
    }

    part def InfraredSensor {
        in port command : ScanCommand;
        out port detections : DetectionReport[0..*];
    }

    part def ScanCoordinator {
        in port operatorCommand : OperatorCommand;
        out port radarCommand : ScanCommand;
        out port eoCommand : ScanCommand;
        out port irCommand : ScanCommand;
    }

    part def FusionProcessor {
        in port radarDetections : DetectionReport[0..*];
        in port eoDetections : DetectionReport[0..*];
        in port irDetections : DetectionReport[0..*];
        out port tracks : Track[0..*];
    }

    part def ThreatClassifier {
        in port tracks : Track[0..*];
        in port signatureDb : ThreatSignature[1..*];
        out port classifiedTracks : ClassifiedTrack[0..*];
    }

    part def ThreatEvaluator {
        in port classifiedTracks : ClassifiedTrack[0..*];
        out port assessments : ThreatAssessment[0..*];
        out port alerts : Alert[0..*];
    }

    part def ThreatDatabase {
        attribute signatures : ThreatSignature[1..*];
        out port signatureOutput : ThreatSignature[1..*];
        in port signatureUpdate : ThreatSignature;
    }

    part def OperatorConsole {
        in port assessments : ThreatAssessment[0..*];
        in port alerts : Alert[0..*];
        out port operatorCommand : OperatorCommand;
        out port signatureUpdate : ThreatSignature;
    }

    part def HorizonScanningSystem {
        part radar : Radar;
        part electroOptical : ElectroOpticalSensor;
        part infrared : InfraredSensor;
        part scanCoordinator : ScanCoordinator;
        part fusionProcessor : FusionProcessor;
        part threatClassifier : ThreatClassifier;
        part threatEvaluator : ThreatEvaluator;
        part threatDatabase : ThreatDatabase;
        part operatorConsole : OperatorConsole;

        connect scanCoordinator.radarCommand to radar.command;
        connect scanCoordinator.eoCommand to electroOptical.command;
        connect scanCoordinator.irCommand to infrared.command;

        connect radar.detections to fusionProcessor.radarDetections;
        connect electroOptical.detections to fusionProcessor.eoDetections;
        connect infrared.detections to fusionProcessor.irDetections;

        connect fusionProcessor.tracks to threatClassifier.tracks;
        connect threatDatabase.signatureOutput to threatClassifier.signatureDb;

        connect threatClassifier.classifiedTracks to threatEvaluator.classifiedTracks;
        connect threatEvaluator.assessments to operatorConsole.assessments;
        connect threatEvaluator.alerts to operatorConsole.alerts;

        connect operatorConsole.operatorCommand to scanCoordinator.operatorCommand;
        connect operatorConsole.signatureUpdate to threatDatabase.signatureUpdate;

        state systemStates : SystemStates;

        action surveillanceCycle : SurveillanceCycle;
    }

    part scanningSystem : HorizonScanningSystem;

    requirement def FastResponseRequirement {
        doc
        /*
         * The entire process from initial sensor detection to threat evaluation
         * must complete in under one second to ensure timely warnings.
         */
        subject scanningSystem : HorizonScanningSystem;
        attribute detectionTime : TimePoint;
        attribute threatEvaluationTime : TimePoint;
        require constraint { (threatEvaluationTime - detectionTime) < 1.0 }
    }

    requirement def RadarRangeRequirement {
        doc
        /*
         * The Radar sensor shall detect objects at ranges up to 75 kilometers.
         */
        subject radar : Radar;
        attribute detectedRange : Distance;
        require constraint { detectedRange <= 75000.0 }
    }

    requirement def ThreatClassificationRequirement {
        doc
        /*
         * The system shall classify detected objects by comparing their characteristics
         * against the Threat Database of known signatures.
         */
        subject threatClassifier : ThreatClassifier;
        attribute trackCount : Integer;
        attribute classifiedTrackCount : Integer;
        require constraint { classifiedTrackCount <= trackCount }
    }

    requirement def HighPriorityAlertRequirement {
        doc
        /*
         * If the system identifies a high-priority threat, it shall automatically
         * issue an alert to the Operator Console.
         */
        subject threatEvaluator : ThreatEvaluator;
        attribute threatLevel : Integer;
        attribute alertCount : Integer;
        require constraint { threatLevel >= 8 implies alertCount >= 1 }
    }
}
