package RadarTrackerSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Probability {
        :> scalar;
    }

    attribute def Hertz {
        :> scalar;
    }

    attribute def Degree {
        :> scalar;
    }

    attribute def Decibel {
        :> scalar;
    }

    attribute def MeterPerSecond {
        :> scalar;
    }

    attribute def SquareMeter {
        :> scalar;
    }

    attribute def TrackIdentifier {
        :> scalar;
    }

    attribute def TimeStamp {
        :> scalar;
    }

    item def RadioFrequencyPulse {
        attribute carrierFrequency : Hertz;
        attribute bandwidth : Hertz;
        attribute pulseWidth : s;
        attribute peakPower : W;
        attribute polarization : String;
    }

    item def RadarEcho {
        attribute receivedPower : W;
        attribute rangeDelay : s;
        attribute dopplerShift : Hertz;
        attribute azimuthAngle : Degree;
        attribute elevationAngle : Degree;
        attribute signalToNoiseRatio : Decibel;
    }

    item def DetectionReport {
        attribute range : m;
        attribute radialVelocity : MeterPerSecond;
        attribute azimuth : Degree;
        attribute elevation : Degree;
        attribute detectionConfidence : Probability;
        attribute measuredAt : TimeStamp;
    }

    item def TrackState {
        attribute trackId : TrackIdentifier;
        attribute range : m;
        attribute radialVelocity : MeterPerSecond;
        attribute azimuth : Degree;
        attribute elevation : Degree;
        attribute positionUncertainty : m;
        attribute velocityUncertainty : MeterPerSecond;
        attribute classification : String;
        attribute trackConfidence : Probability;
        attribute lastUpdated : TimeStamp;
    }

    item def TrackFile {
        attribute numberOfTracks : Integer;
        item tracks : TrackState[0..*];
    }

    item def OperatorCommand {
        attribute commandName : String;
        attribute commandedScanCenterAzimuth : Degree;
        attribute commandedScanWidth : Degree;
        attribute trackingPriority : String;
    }

    port def RfTransmitPort {
        out item pulse : RadioFrequencyPulse;
    }

    port def RfReceivePort {
        in item echo : RadarEcho;
    }

    port def DetectionOutPort {
        out item detection : DetectionReport;
    }

    port def DetectionInPort {
        in item detection : DetectionReport;
    }

    port def TrackOutPort {
        out item trackFile : TrackFile;
    }

    port def CommandInPort {
        in item command : OperatorCommand;
    }

    port def StatusOutPort {
        out item status : String;
    }

    part def Transmitter {
        attribute carrierFrequency : Hertz = 9400000000;
        attribute pulseRepetitionFrequency : Hertz = 1200;
        attribute peakPower : W = 25000;
        attribute pulseWidth : s = 0.000001;

        port rfOut : RfTransmitPort;

        action generatePulse {
            out item pulse : RadioFrequencyPulse;
        }
    }

    part def AntennaArray {
        attribute apertureDiameter : m = 1.8;
        attribute azimuthCoverage : Degree = 120;
        attribute elevationCoverage : Degree = 45;
        attribute gain : Decibel = 36;

        port transmitInput : RfTransmitPort;
        port receiveOutput : RfReceivePort;

        action steerBeam {
            in attribute targetAzimuth : Degree;
            in attribute targetElevation : Degree;
        }
    }

    part def Receiver {
        attribute noiseFigure : Decibel = 3.2;
        attribute dynamicRange : Decibel = 92;
        attribute minimumDetectableSignal : W = 0.0000000000005;

        port rfIn : RfReceivePort;
        port detectionOut : DetectionOutPort;

        action convertEchoToDetection {
            in item echo : RadarEcho;
            out item detection : DetectionReport;
        }
    }

    part def SignalProcessor {
        attribute rangeResolution : m = 15;
        attribute velocityResolution : MeterPerSecond = 1.5;
        attribute falseAlarmProbability : Probability = 0.000001;
        attribute minimumDetectionConfidence : Probability = 0.72;

        port detectionIn : DetectionInPort;
        port detectionOut : DetectionOutPort;

        action filterAndValidateDetection {
            in item rawDetection : DetectionReport;
            out item validatedDetection : DetectionReport;
        }
    }

    part def TrackerProcessor {
        attribute maximumTrackCapacity : Integer = 512;
        attribute trackInitiationThreshold : Integer = 3;
        attribute trackDeletionTimeout : s = 8;
        attribute associationGateRange : m = 120;
        attribute associationGateVelocity : MeterPerSecond = 18;

        port detectionIn : DetectionInPort;
        port trackOut : TrackOutPort;

        action associateDetection {
            in item detection : DetectionReport;
            in item existingTrack : TrackState;
            out attribute isAssociated : Boolean;
        }

        action initiateTrack {
            in item detection : DetectionReport;
            out item newTrack : TrackState;
        }

        action updateTrack {
            in item detection : DetectionReport;
            in item priorTrack : TrackState;
            out item updatedTrack : TrackState;
        }

        action deleteStaleTrack {
            in item staleTrack : TrackState;
        }

        state def TrackingStateMachine {
            state initializing;
            state searching;
            state detecting;
            state tracking;
            state degraded;
            state faulted;

            transition first initializing then searching;

            transition searching_to_detecting
                first searching
                accept DetectionReport
                if detectionConfidence >= 0.72
                then detecting;

            transition detecting_to_tracking
                first detecting
                if trackInitiationThreshold >= 3
                then tracking;

            transition tracking_to_searching
                first tracking
                if numberOfTracks == 0
                then searching;

            transition tracking_to_degraded
                first tracking
                if trackConfidence < 0.45
                then degraded;

            transition degraded_to_tracking
                first degraded
                if trackConfidence >= 0.70
                then tracking;

            transition degraded_to_faulted
                first degraded
                if trackConfidence < 0.20
                then faulted;
        }
    }

    part def OperatorInterface {
        port commandOut : CommandInPort;
        port trackIn : TrackOutPort;
        port statusIn : StatusOutPort;

        action displayTrackFile {
            in item trackFile : TrackFile;
        }

        action submitCommand {
            out item command : OperatorCommand;
        }
    }

    part def HealthMonitor {
        attribute maximumAllowedProcessorLatency : s = 0.25;
        attribute minimumReceiverSnr : Decibel = 8;
        attribute healthState : String = "Nominal";

        port statusOut : StatusOutPort;

        action evaluateHealth {
            out attribute status : String;
        }
    }

    part def RadarTrackerSystem {
        attribute systemName : String = "High Level Radar Tracker";
        attribute primaryFunction : String = "Detect, associate, maintain, and report tracks for airborne or surface targets using radar measurements.";
        attribute surveillanceRange : m = 150000;
        attribute minimumTrackableRange : m = 500;
        attribute maximumTrackableVelocity : MeterPerSecond = 1200;
        attribute trackUpdateInterval : s = 1.0;
        attribute requiredTrackContinuity : Probability = 0.95;

        port commandIn : CommandInPort;
        port trackOut : TrackOutPort;
        port statusOut : StatusOutPort;

        part transmitter : Transmitter;
        part antenna : AntennaArray;
        part receiver : Receiver;
        part signalProcessor : SignalProcessor;
        part trackerProcessor : TrackerProcessor;
        part operatorInterface : OperatorInterface;
        part healthMonitor : HealthMonitor;

        connect transmitter.rfOut to antenna.transmitInput;
        connect antenna.receiveOutput to receiver.rfIn;
        connect receiver.detectionOut to signalProcessor.detectionIn;
        connect signalProcessor.detectionOut to trackerProcessor.detectionIn;
        connect trackerProcessor.trackOut to trackOut;
        connect commandIn to operatorInterface.commandOut;
        connect healthMonitor.statusOut to statusOut;

        action performSurveillanceAndTracking {
            first startRadarEmission;
            then collectEchoes;
            then produceDetections;
            then maintainTracks;
            then publishTrackFile;

            action startRadarEmission {
                out item emittedPulse : RadioFrequencyPulse;
            }

            action collectEchoes {
                in item emittedPulse : RadioFrequencyPulse;
                out item receivedEcho : RadarEcho;
            }

            action produceDetections {
                in item receivedEcho : RadarEcho;
                out item validatedDetection : DetectionReport;
            }

            action maintainTracks {
                in item validatedDetection : DetectionReport;
                out item currentTrackFile : TrackFile;
            }

            action publishTrackFile {
                in item currentTrackFile : TrackFile;
            }
        }
    }

    requirement def DetectTargets {
        doc /* The radar tracker system shall detect targets within the declared surveillance range when the received signal exceeds the configured detection threshold. */
        subject system : RadarTrackerSystem;
        require constraint {
            system.surveillanceRange >= 150000 [m]
        }
    }

    requirement def MaintainTrackContinuity {
        doc /* The radar tracker system shall maintain track continuity with at least 0.95 probability for maneuvering targets within coverage. */
        subject system : RadarTrackerSystem;
        require constraint {
            system.requiredTrackContinuity >= 0.95
        }
    }

    requirement def PublishTrackUpdates {
        doc /* The radar tracker system shall publish an updated track file at least once per second during nominal operation. */
        subject system : RadarTrackerSystem;
        require constraint {
            system.trackUpdateInterval <= 1.0 [s]
        }
    }

    requirement def SupportHighVelocityTargets {
        doc /* The radar tracker system shall track targets with radial velocity up to 1200 meters per second. */
        subject system : RadarTrackerSystem;
        require constraint {
            system.maximumTrackableVelocity >= 1200
        }
    }

    requirement def LimitFalseAlarms {
        doc /* The signal processing function shall limit the probability of false alarm to no more than one in one million detection opportunities. */
        subject processor : SignalProcessor;
        require constraint {
            processor.falseAlarmProbability <= 0.000001
        }
    }

    satisfy DetectTargets by RadarTrackerSystem;
    satisfy MaintainTrackContinuity by RadarTrackerSystem;
    satisfy PublishTrackUpdates by RadarTrackerSystem;
    satisfy SupportHighVelocityTargets by RadarTrackerSystem;
    satisfy LimitFalseAlarms by SignalProcessor;

}