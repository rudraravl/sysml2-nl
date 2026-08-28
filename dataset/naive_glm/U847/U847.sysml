package RadarTrackerSystem {
    import ScalarValues::*;
    
    // ---- Value Types with Units ----
    value type PowerUnit > Real { unit "W"; }
    value type FrequencyUnit > Real { unit "Hz"; }
    value type DistanceUnit > Real { unit "m"; }
    value type VelocityUnit > Real { unit "m/s"; }
    value type AngleUnit > Real { unit "rad"; }
    value type TimeUnit > Real { unit "s"; }
    value type SNRUnit > Real { unit "dB"; }
    value type ConfidenceUnit > Real { unit "ratio"; }
    value type GainUnit > Real { unit "dB"; }
    
    // ---- Item Definitions ----
    item def RadarPulse {
        attribute frequency : FrequencyUnit;
        attribute pulseWidth : TimeUnit;
        attribute peakPower : PowerUnit;
        attribute timestamp : TimeUnit;
    }
    
    item def SteeringCommand {
        attribute azimuth : AngleUnit;
        attribute elevation : AngleUnit;
        attribute scanMode : String;
        attribute priorityTrackId : Integer;
    }
    
    item def RawEcho {
        attribute amplitude : PowerUnit;
        attribute range : DistanceUnit;
        attribute azimuth : AngleUnit;
        attribute elevation : AngleUnit;
        attribute dopplerShift : FrequencyUnit;
        attribute timestamp : TimeUnit;
    }
    
    item def Detection {
        attribute detectionId : Integer;
        attribute range : DistanceUnit;
        attribute azimuth : AngleUnit;
        attribute elevation : AngleUnit;
        attribute radialVelocity : VelocityUnit;
        attribute snr : SNRUnit;
        attribute timestamp : TimeUnit;
    }
    
    item def TrackState {
        attribute trackId : Integer;
        attribute posX : DistanceUnit;
        attribute posY : DistanceUnit;
        attribute posZ : DistanceUnit;
        attribute velX : VelocityUnit;
        attribute velY : VelocityUnit;
        attribute velZ : VelocityUnit;
        attribute confidence : ConfidenceUnit;
        attribute lastUpdate : TimeUnit;
        attribute trackQuality : Integer;
    }
    
    item def TrackReport {
        attribute reportId : Integer;
        attribute tracks : TrackState[0..*];
        attribute timestamp : TimeUnit;
        attribute systemMode : String;
    }
    
    item def ClutterMap {
        attribute clutterCells : RawEcho[0..*];
        attribute lastRefresh : TimeUnit;
    }
    
    // ---- Port Definitions ----
    port def PulseOutPort {
        out pulse : RadarPulse;
    }
    
    port def PulseInPort {
        in pulse : RadarPulse;
    }
    
    port def EchoOutPort {
        out echo : RawEcho;
    }
    
    port def EchoInPort {
        in echo : RawEcho;
    }
    
    port def DetectionOutPort {
        out detection : Detection;
    }
    
    port def DetectionInPort {
        in detection : Detection;
    }
    
    port def SteeringOutPort {
        out command : SteeringCommand;
    }
    
    port def SteeringInPort {
        in command : SteeringCommand;
    }
    
    port def TrackOutPort {
        out report : TrackReport;
    }
    
    // ---- Transmitter ----
    part def Transmitter {
        port pulseOut : PulseOutPort;
        attribute peakPower : PowerUnit = 5000000;
        attribute operatingFrequency : FrequencyUnit = 9400000000;
        attribute pulseWidth : TimeUnit = 0.000001;
        attribute pulseRepetitionInterval : TimeUnit = 0.001;
        
        action generatePulse {
            out p : RadarPulse;
        }
        
        action TransmitCycle {
            action generate {
                out p : RadarPulse;
            }
            action amplify {
                in p : RadarPulse;
                out amplified : RadarPulse;
            }
            flow generate.p to amplify.p;
            flow amplify.amplified to pulseOut.pulse;
        }
    }
    
    // ---- Antenna Assembly ----
    part def AntennaAssembly {
        port pulseIn : PulseInPort;
        port echoOut : EchoOutPort;
        port steeringIn : SteeringInPort;
        attribute beamwidthAzimuth : AngleUnit = 0.01745;
        attribute beamwidthElevation : AngleUnit = 0.01745;
        attribute antennaGain : GainUnit = 45.0;
        attribute currentAzimuth : AngleUnit = 0.0;
        attribute currentElevation : AngleUnit = 0.0;
        
        action broadcast {
            in p : RadarPulse;
        }
        action listen {
            out e : RawEcho;
        }
        action steer {
            in c : SteeringCommand;
        }
        
        action AntennaCycle {
            action receiveSteering {
                in c : SteeringCommand;
            }
            action positionBeam {
                in c : SteeringCommand;
            }
            action radiate {
                in p : RadarPulse;
            }
            action collect {
                out e : RawEcho;
            }
            flow receiveSteering.c to positionBeam.c;
            flow pulseIn.pulse to radiate.p;
            flow collect.e to echoOut.echo;
        }
    }
    
    // ---- Receiver ----
    part def Receiver {
        port echoIn : EchoInPort;
        port detectionOut : DetectionOutPort;
        attribute noiseFigure : Real = 2.5;
        attribute bandwidth : FrequencyUnit = 10000000;
        attribute dynamicRange : GainUnit = 80.0;
        attribute detectionCounter : Integer = 0;
        
        action capture {
            in e : RawEcho;
            out d : Detection;
        }
        
        action ReceiveCycle {
            action downconvert {
                in e : RawEcho;
                out ifSignal : RawEcho;
            }
            action digitize {
                in ifSignal : RawEcho;
                out samples : RawEcho;
            }
            action measure {
                in samples : RawEcho;
                out d : Detection;
            }
            flow echoIn.echo to downconvert.e;
            flow downconvert.ifSignal to digitize.ifSignal;
            flow digitize.samples to measure.samples;
            flow measure.d to detectionOut.detection;
        }
    }
    
    // ---- Signal Processor ----
    part def SignalProcessor {
        port detectionIn : DetectionInPort;
        port processedOut : DetectionOutPort;
        attribute clutterThreshold : SNRUnit = 12.0;
        attribute minDetectionSNR : SNRUnit = 15.0;
        attribute clutterMap : ClutterMap;
        
        action filterClutter {
            in d : Detection;
            out filtered : Detection;
        }
        action analyze {
            in filtered : Detection;
            out confirmed : Detection;
        }
        
        action ProcessingCycle {
            action receiveDetection {
                in d : Detection;
            }
            action applyCFAR {
                in d : Detection;
                out thresholded : Detection;
            }
            action suppressClutter {
                in thresholded : Detection;
                out cleaned : Detection;
            }
            action confirmDetection {
                in cleaned : Detection;
                out confirmed : Detection;
            }
            flow detectionIn.detection to receiveDetection.d;
            flow receiveDetection.d to applyCFAR.d;
            flow applyCFAR.thresholded to suppressClutter.thresholded;
            flow suppressClutter.cleaned to confirmDetection.cleaned;
            flow confirmDetection.confirmed to processedOut.detection;
        }
    }
    
    // ---- Track Manager ----
    part def TrackManager {
        port detectionIn : DetectionInPort;
        port steeringOut : SteeringOutPort;
        port trackOut : TrackOutPort;
        attribute trackFile : TrackState[0..*];
        attribute maxTracks : Integer = 100;
        attribute trackCounter : Integer = 0;
        attribute predictionTimeHorizon : TimeUnit = 0.5;
        attribute confidenceThreshold : ConfidenceUnit = 0.3;
        attribute trackDeletionTime : TimeUnit = 3.0;
        
        action predict {
            in t : TrackState;
            out predicted : TrackState;
        }
        action correlate {
            in d : Detection;
            in predicted : TrackState;
            out matched : Boolean;
        }
        action updateTrack {
            in d : Detection;
            in t : TrackState;
            out updated : TrackState;
        }
        action initiateTrack {
            in d : Detection;
            out newTrack : TrackState;
        }
        action pruneTracks {
            in tracks : TrackState[0..*];
            out remaining : TrackState[0..*];
        }
        action generateSteering {
            in tracks : TrackState[0..*];
            out cmd : SteeringCommand;
        }
        action generateReport {
            in tracks : TrackState[0..*];
            out report : TrackReport;
        }
        
        action TrackManagementCycle {
            action ingestDetection {
                in d : Detection;
            }
            action predictAll {
                in tracks : TrackState[0..*];
                out predictions : TrackState[0..*];
            }
            action gateAndAssociate {
                in d : Detection;
                in predictions : TrackState[0..*];
                out associatedTrack : TrackState;
                out isNewTarget : Boolean;
            }
            action kalmanUpdate {
                in d : Detection;
                in associatedTrack : TrackState;
                out updated : TrackState;
            }
            action createNewTrack {
                in d : Detection;
                out newTrack : TrackState;
            }
            action cleanupTracks {
                in allTracks : TrackState[0..*];
                out survivors : TrackState[0..*];
            }
            action computeSteering {
                in survivors : TrackState[0..*];
                out cmd : SteeringCommand;
            }
            action buildReport {
                in survivors : TrackState[0..*];
                out report : TrackReport;
            }
            
            flow detectionIn.detection to ingestDetection.d;
            flow trackFile to predictAll.tracks;
            flow ingestDetection.d to gateAndAssociate.d;
            flow predictAll.predictions to gateAndAssociate.predictions;
            flow gateAndAssociate.associatedTrack to kalmanUpdate.associatedTrack;
            flow gateAndAssociate.isNewTarget to createNewTrack;
            flow ingestDetection.d to kalmanUpdate.d;
            flow ingestDetection.d to createNewTrack.d;
            flow kalmanUpdate.updated to cleanupTracks.allTracks;
            flow createNewTrack.newTrack to cleanupTracks.allTracks;
            flow cleanupTracks.survivors to computeSteering.survivors;
            flow cleanupTracks.survivors to buildReport.survivors;
            flow computeSteering.cmd to steeringOut.command;
            flow buildReport.report to trackOut.report;
        }
    }
    
    // ---- System State Machine ----
    state def RadarOperatingMode {
        attribute currentMode : String;
        
        state standby {
            entry action { assign currentMode = "standby"; }
        }
        state searching {
            entry action { assign currentMode = "searching"; }
        }
        state tracking {
            entry action { assign currentMode = "tracking"; }
        }
        state multiTarget {
            entry action { assign currentMode = "multi-target"; }
        }
        
        transition standby to searching
            if [powerOn == true];
        transition searching to tracking
            if [targetAcquired == true and confirmedTrackCount == 1];
        transition searching to multiTarget
            if [confirmedTrackCount >= 2];
        transition tracking to multiTarget
            if [confirmedTrackCount >= 2];
        transition tracking to searching
            if [confirmedTrackCount == 0];
        transition multiTarget to tracking
            if [confirmedTrackCount == 1];
        transition multiTarget to searching
            if [confirmedTrackCount == 0];
        transition tracking to standby
            if [powerOn == false];
        transition multiTarget to standby
            if [powerOn == false];
        transition searching to standby
            if [powerOn == false];
    }
    
    // ---- Main Radar Tracker System ----
    part def RadarTracker {
        port systemSteeringOut : SteeringOutPort;
        port systemTrackOut : TrackOutPort;
        port systemSteeringIn : SteeringInPort;
        
        attribute powerOn : Boolean = false;
        attribute targetAcquired : Boolean = false;
        attribute confirmedTrackCount : Integer = 0;
        attribute maxRange : DistanceUnit = 100000;
        attribute minUpdateInterval : TimeUnit = 0.5;
        
        part transmitter : Transmitter {
            attribute peakPower : PowerUnit = 5000000;
            attribute operatingFrequency : FrequencyUnit = 9400000000;
        }
        part antenna : AntennaAssembly {
            attribute antennaGain : GainUnit = 45.0;
            attribute beamwidthAzimuth : AngleUnit = 0.01745;
            attribute beamwidthElevation : AngleUnit = 0.01745;
        }
        part receiver : Receiver {
            attribute noiseFigure : Real = 2.5;
            attribute bandwidth : FrequencyUnit = 10000000;
        }
        part signalProcessor : SignalProcessor {
            attribute clutterThreshold : SNRUnit = 12.0;
            attribute minDetectionSNR : SNRUnit = 15.0;
        }
        part trackManager : TrackManager {
            attribute maxTracks : Integer = 100;
            attribute confidenceThreshold : ConfidenceUnit = 0.3;
            attribute trackDeletionTime : TimeUnit = 3.0;
        }
        
        // Internal connections
        connection transmitter.pulseOut to antenna.pulseIn;
        connection antenna.echoOut to receiver.echoIn;
        connection receiver.detectionOut to signalProcessor.detectionIn;
        connection signalProcessor.processedOut to trackManager.detectionIn;
        connection trackManager.steeringOut to antenna.steeringIn;
        connection trackManager.steeringOut to systemSteeringOut;
        connection trackManager.trackOut to systemTrackOut;
        connection systemSteeringIn to antenna.steeringIn;
        
        // System behavior
        action RadarCycle {
            action transmit {
                out p : RadarPulse;
            }
            action radiate {
                in p : RadarPulse;
                out echo : RawEcho;
            }
            action receive {
                in echo : RawEcho;
                out rawDetection : Detection;
            }
            action process {
                in rawDetection : Detection;
                out confirmedDetection : Detection;
            }
            action manageTracks {
                in confirmedDetection : Detection;
                out report : TrackReport;
                out cmd : SteeringCommand;
            }
            action steer {
                in cmd : SteeringCommand;
            }
            
            flow transmit.p to radiate.p;
            flow radiate.echo to receive.echo;
            flow receive.rawDetection to process.rawDetection;
            flow process.confirmedDetection to manageTracks.confirmedDetection;
            flow manageTracks.cmd to steer.cmd;
            
            then transmit;
        }
        
        exhibit RadarOperatingMode {
            attribute powerOn : Boolean;
            attribute targetAcquired : Boolean;
            attribute confirmedTrackCount : Integer;
        }
    }
    
    // ---- Requirements ----
    requirement def DetectionRangeRequirement {
        subject radar : RadarTracker;
        doc /* The radar tracker system shall detect objects at ranges up to 100 km. */
        attribute requiredMaxRange : DistanceUnit = 100000;
    }
    
    requirement def MultiTargetTrackingRequirement {
        subject radar : RadarTracker;
        doc /* The radar tracker system shall simultaneously track up to 100 targets. */
        attribute requiredMaxTracks : Integer = 100;
    }
    
    requirement def UpdateRateRequirement {
        subject radar : RadarTracker;
        doc /* The radar tracker system shall update each track at least every 0.5 seconds. */
        attribute requiredMinUpdateInterval : TimeUnit = 0.5;
    }
    
    requirement def PositionAccuracyRequirement {
        subject radar : RadarTracker;
        doc /* The radar tracker system shall provide 3D position estimates within 10 m accuracy. */
        attribute requiredPositionAccuracy : DistanceUnit = 10.0;
    }
    
    requirement def VelocityAccuracyRequirement {
        subject radar : RadarTracker;
        doc /* The radar tracker system shall provide velocity estimates within 5 m/s accuracy. */
        attribute requiredVelocityAccuracy : VelocityUnit = 5.0;
    }
    
    requirement def ModeTransitionRequirement {
        subject radar : RadarTracker;
        doc /* The radar tracker system shall automatically transition between standby, searching, tracking, and multi-target modes based on the detection and tracking situation. */
    }
    
    requirement def TrackQualityMetricRequirement {
        subject radar : RadarTracker;
        doc /* The radar tracker system shall output a quality metric for each track in the track report. */
    }
    
    requirement def SteeringOptimizationRequirement {
        subject radar : RadarTracker;
        doc /* The radar tracker system shall send steering commands to the antenna to optimize scanning or follow tracked targets. */
    }
    
    requirement def ClutterSuppressionRequirement {
        subject radar : RadarTracker;
        doc /* The signal processor shall filter noise and environmental clutter before identifying detections. */
    }
    
    requirement def TrackLifecycleRequirement {
        subject radar : RadarTracker;
        doc /* The track manager shall initiate new tracks for unmatched detections and prune tracks with low confidence or lost tracks. */
    }
    
    // ---- Requirement Satisfaction ----
    part radarSystem : RadarTracker {
        satisfy DetectionRangeRequirement by radarSystem;
        satisfy MultiTargetTrackingRequirement by radarSystem;
        satisfy UpdateRateRequirement by radarSystem;
        satisfy PositionAccuracyRequirement by radarSystem;
        satisfy VelocityAccuracyRequirement by radarSystem;
        satisfy ModeTransitionRequirement by radarSystem;
        satisfy TrackQualityMetricRequirement by radarSystem;
        satisfy SteeringOptimizationRequirement by radarSystem;
        satisfy ClutterSuppressionRequirement by signalProcessor;
        satisfy TrackLifecycleRequirement by trackManager;
    }
}
