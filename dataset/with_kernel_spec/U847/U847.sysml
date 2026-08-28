package 'Radar Tracker System' {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;
    private import MeasurementReferences::*;

    item def RadarPulse {
        attribute power : PowerValue;
        attribute frequency : FrequencyValue;
        attribute pulseWidth : TimeValue;
    }

    item def Echo {
        attribute range : LengthValue;
        attribute azimuth : PlaneAngleValue;
        attribute elevation : PlaneAngleValue;
        attribute dopplerShift : FrequencyValue;
        attribute amplitude : PowerValue;
    }

    item def Detection {
        attribute range : LengthValue;
        attribute azimuth : PlaneAngleValue;
        attribute elevation : PlaneAngleValue;
        attribute radialVelocity : SpeedValue;
        attribute signalToNoiseRatio : Real;
        attribute timestamp : TimeValue;
    }

    item def Track {
        attribute trackId : Integer;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute positionZ : LengthValue;
        attribute velocityX : SpeedValue;
        attribute velocityY : SpeedValue;
        attribute velocityZ : SpeedValue;
        attribute quality : Real;
        attribute confidence : Real;
        attribute lastUpdate : TimeValue;
    }

    item def SteeringCommand {
        attribute targetAzimuth : PlaneAngleValue;
        attribute targetElevation : PlaneAngleValue;
        attribute scanMode : String;
    }

    item def StartSearch;
    item def TargetAcquired;
    item def MultipleTargetsDetected;
    item def TargetLost;
    item def Shutdown;

    part def Transmitter {
        port pulseOut {
            out pulse : RadarPulse;
        }
        attribute transmitPower : PowerValue := 1000 [W];
        attribute carrierFrequency : FrequencyValue := 10000 [MHz];
        attribute pulseWidth : TimeValue := 0.000001 [s];
    }

    part def AntennaAssembly {
        port pulseIn {
            in pulse : RadarPulse;
        }
        port echoOut {
            out echo : Echo;
        }
        port steeringIn {
            in command : SteeringCommand;
        }
        attribute currentAzimuth : PlaneAngleValue := 0 [deg];
        attribute currentElevation : PlaneAngleValue := 0 [deg];
        attribute beamWidth : PlaneAngleValue := 2 [deg];
        attribute gain : Real := 40;
    }

    part def Receiver {
        port echoIn {
            in echo : Echo;
        }
        port rawSignalOut {
            out rawSignal : Echo;
        }
        attribute noiseFigure : Real := 3;
        attribute bandwidth : FrequencyValue := 10000 [kHz];
        attribute sensitivity : PowerValue := 0.000000000001 [W];
    }

    part def SignalProcessor {
        port rawSignalIn {
            in rawSignal : Echo;
        }
        port detectionOut {
            out detection : Detection;
        }
        attribute clutterThreshold : Real := 0.5;
        attribute noiseFloor : PowerValue := 0.0000000000001 [W];
    }

    part def TrackManager {
        port detectionIn {
            in detection : Detection;
        }
        port steeringOut {
            out command : SteeringCommand;
        }
        port trackOut {
            out track : Track;
        }
        attribute trackFile : Track[*] := ( );
        attribute predictionTimeStep : TimeValue := 0.1 [s];
        attribute maxTracks : Integer := 100;
        attribute confidenceThreshold : Real := 0.3;
    }

    part def RadarTracker {
        port trackStreamOut {
            out track : Track;
        }
        
        part transmitter : Transmitter;
        part antenna : AntennaAssembly;
        part receiver : Receiver;
        part signalProcessor : SignalProcessor;
        part trackManager : TrackManager;

        flow pulseFlow of RadarPulse
            from transmitter.pulseOut.pulse to antenna.pulseIn.pulse;
        flow echoFlow of Echo
            from antenna.echoOut.echo to receiver.echoIn.echo;
        flow rawSignalFlow of Echo
            from receiver.rawSignalOut.rawSignal to signalProcessor.rawSignalIn.rawSignal;
        flow detectionFlow of Detection
            from signalProcessor.detectionOut.detection to trackManager.detectionIn.detection;
        flow steeringFlow of SteeringCommand
            from trackManager.steeringOut.command to antenna.steeringIn.command;
        flow trackOutputFlow of Track
            from trackManager.trackOut.track to trackStreamOut.track;

        state trackerBehavior : TrackerStates;
    }

    part radarTracker : RadarTracker;

    state def TrackerStates {
        entry; then Standby;

        state Standby {
            do action PerformStandby;
        }
        state Searching {
            do action PerformSearch;
        }
        state Tracking {
            do action PerformTrack;
        }
        state MultiTarget {
            do action PerformMultiTarget;
        }

        transition first Standby accept StartSearch then Searching;
        transition first Searching accept TargetAcquired then Tracking;
        transition first Searching accept MultipleTargetsDetected then MultiTarget;
        transition first Tracking accept MultipleTargetsDetected then MultiTarget;
        transition first Tracking accept TargetLost then Searching;
        transition first MultiTarget accept TargetLost then Tracking;
        transition first MultiTarget accept StartSearch then Searching;
        transition first Searching accept Shutdown then Standby;
        transition first Tracking accept Shutdown then Standby;
        transition first MultiTarget accept Shutdown then Standby;
    }

    action def PerformStandby;
    action def PerformSearch;
    action def PerformTrack;
    action def PerformMultiTarget;

    action def FilterNoise {
        in rawSignal : Echo;
        out cleanSignal : Echo;
    }

    action def AnalyzeSignal {
        in filteredSignal : Echo;
        out detectedTarget : Detection;
    }

    action def ProcessSignal {
        in rawSignal : Echo;
        out detection : Detection;
        private attribute filtered : Echo;

        perform action filter : FilterNoise {
            in rawSignal = rawSignal;
            out cleanSignal;
        }
        then assign filtered := filter.cleanSignal;
        then perform action analyze : AnalyzeSignal {
            in filteredSignal = filtered;
            out detectedTarget;
        }
        then assign detection := analyze.detectedTarget;
    }

    action def PredictTrackPositions {
        in tracks : Track[*];
        in timeStep : TimeValue;
        out predicted : Track[*];
    }

    action def CorrelateDetections {
        in detection : Detection;
        in predictions : Track[*];
        out correlated : Track[*];
    }

    action def InitiateNewTracks {
        in detection : Detection;
        in existingTracks : Track[*];
        out initiated : Track[*];
    }

    action def PruneTracks {
        in tracks : Track[*];
        in confidenceThreshold : Real;
        out pruned : Track[*];
    }

    action def UpdateTracks {
        in detection : Detection;
        in currentTracks : Track[*];
        in timeStep : TimeValue;
        in confidenceThreshold : Real;
        out updatedTracks : Track[*];
        private attribute predictedTracks : Track[*];
        private attribute correlatedTracks : Track[*];
        private attribute initiatedTracks : Track[*];

        perform action predict : PredictTrackPositions {
            in tracks = currentTracks;
            in timeStep = timeStep;
            out predicted;
        }
        then assign predictedTracks := predict.predicted;
        then perform action correlate : CorrelateDetections {
            in detection = detection;
            in predictions = predictedTracks;
            out correlated;
        }
        then assign correlatedTracks := correlate.correlated;
        then perform action initiate : InitiateNewTracks {
            in detection = detection;
            in existingTracks = correlatedTracks;
            out initiated;
        }
        then assign initiatedTracks := initiate.initiated;
        then perform action prune : PruneTracks {
            in tracks = initiatedTracks;
            in confidenceThreshold = confidenceThreshold;
            out pruned;
        }
        then assign updatedTracks := prune.pruned;
    }

    requirement def DetectionRangeRequirement {
        subject tracker : RadarTracker;
        attribute minDetectionRange : LengthValue := 100 [m];
        attribute maxDetectionRange : LengthValue := 100000 [m];
        require tracker shall detect objects at ranges between minDetectionRange and maxDetectionRange;
    }

    requirement def TrackingAccuracyRequirement {
        subject tracker : RadarTracker;
        attribute positionAccuracy : LengthValue := 10 [m];
        attribute velocityAccuracy : SpeedValue := 1 [m/s];
        require tracker shall provide 3D position data accurate to within positionAccuracy;
        require tracker shall provide 3D velocity data accurate to within velocityAccuracy;
    }

    requirement def MultiTargetRequirement {
        subject tracker : RadarTracker;
        attribute maxConcurrentTracks : Integer := 100;
        attribute updateRate : FrequencyValue := 10 [Hz];
        require tracker shall maintain tracks for up to maxConcurrentTracks targets simultaneously;
        require tracker shall update each track at a rate of at least updateRate;
    }

    requirement def ModeTransitionRequirement {
        subject tracker : RadarTracker;
        require tracker shall support standby, searching, tracking, and multi-target tracking modes;
        require tracker shall automatically transition from searching to tracking upon target detection;
        require tracker shall transition to multi-target tracking when multiple targets are detected;
        require tracker shall provide a continuously updated data stream of all tracked objects including 3D position, velocity, and a quality metric;
    }

    requirement detectionRangeReq : DetectionRangeRequirement;
    requirement trackingAccuracyReq : TrackingAccuracyRequirement;
    requirement multiTargetReq : MultiTargetRequirement;
    requirement modeTransitionReq : ModeTransitionRequirement;
}
