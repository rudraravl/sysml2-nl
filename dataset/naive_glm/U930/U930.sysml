package UWB_RTLS {
    import ScalarValues::*;
    import SI::*;
    
    // ===== Value Types with Units =====
    
    value def Distance :> Real {
    }
    
    value def TimeOfFlight :> Real {
    }
    
    value def Frequency :> Real {
    }
    
    value def Power :> Real {
    }
    
    value def Coordinate :> Real {
    }
    
    value def Velocity :> Real {
    }
    
    value def Position3D {
        attribute x : Coordinate;
        attribute y : Coordinate;
        attribute z : Coordinate;
    }
    
    value def TagId :> Integer {
    }
    
    value def AnchorId :> Integer {
    }
    
    value def Rssi :> Real {
    }
    
    // ===== Item Types =====
    
    item def UWBPulse {
        attribute frequency : Frequency = 6500e6;
        attribute durationNs : Real = 2.0;
        attribute bandwidth : Frequency = 500e6;
    }
    
    item def RangingMessage {
        attribute tagId : TagId;
        attribute anchorId : AnchorId;
        attribute timestamp : Real;
        attribute sequenceNumber : Integer;
    }
    
    item def DistanceMeasurement {
        attribute tagId : TagId;
        attribute anchorId : AnchorId;
        attribute distance : Distance;
        attribute timestamp : Real;
        attribute quality : Real;
    }
    
    item def PositionUpdate {
        attribute tagId : TagId;
        attribute position : Position3D;
        attribute timestamp : Real;
        attribute accuracy : Distance;
        attribute confidence : Real;
    }
    
    item def AnchorCalibrationData {
        attribute anchorId : AnchorId;
        attribute position : Position3D;
        attribute antennaDelay : TimeOfFlight;
    }
    
    // ===== Port Definitions =====
    
    port def UWBPort {
        out item pulse : UWBPulse;
        in item rangingMsg : RangingMessage;
    }
    
    port def AnchorDataPort {
        out item measurement : DistanceMeasurement;
        in item calibration : AnchorCalibrationData;
    }
    
    port def PositionOutputPort {
        out item position : PositionUpdate;
    }
    
    // ===== Interfaces =====
    
    interface def UWBInterface {
        end source : UWBPort;
        end destination : UWBPort;
        flow pulse of UWBPulse from source.pulse to destination.pulse;
        flow rangingMsg of RangingMessage from destination.rangingMsg to source.rangingMsg;
    }
    
    interface def AnchorDataInterface {
        end anchor : AnchorDataPort;
        end engine : AnchorDataPort;
        flow measurement of DistanceMeasurement from anchor.measurement to engine.measurement;
        flow calibration of AnchorCalibrationData from engine.calibration to anchor.calibration;
    }
    
    // ===== Parts =====
    
    part def MobileTag {
        attribute tagId : TagId;
        attribute batteryLevel : Power;
        attribute updateRateHz : Real = 10.0;
        
        port uwbPort : UWBPort;
        
        part radioTransmitter {
            attribute transmitPower : Power = -41.3;
            attribute centerFrequency : Frequency = 6500e6;
        }
        
        part radioReceiver {
            attribute sensitivity : Power = -100;
        }
        
        part timingUnit {
            attribute clockResolutionPs : Real = 15.65;
            attribute synchronizationError : TimeOfFlight;
        }
        
        part microcontroller {
            attribute processingFrequency : Frequency = 48e6;
        }
        
        part battery {
            attribute capacity_mAh : Real = 500;
            attribute voltage : Real = 3.7;
        }
        
        state tagBehavior {
            entry action { send UWBPulse(); }
            
            state Dormant;
            state Transmitting {
                entry action { 
                    "Generate UWB pulse burst"; 
                }
            }
            state Listening {
                entry action { "Wait for ranging response from anchors"; }
            }
            state Sleeping {
                entry action { "Enter low-power mode"; }
            }
            
            transition from Dormant to Transmitting when "ranging cycle triggered";
            transition from Transmitting to Listening when "pulse transmission complete";
            transition from Listening to Sleeping when "response window expired or response received";
            transition from Sleeping to Transmitting when "update interval elapsed";
        }
        
        action generatePulse {
            out pulse : UWBPulse;
        }
        
        action processRangingResponse {
            in msg : RangingMessage;
        }
    }
    
    part def FixedAnchor {
        attribute anchorId : AnchorId;
        attribute position : Position3D;
        attribute isCalibrated : Boolean = false;
        attribute antennaDelay : TimeOfFlight;
        
        port uwbPort : UWBPort;
        port dataPort : AnchorDataPort;
        
        part radioReceiver {
            attribute sensitivity : Power = -100;
            attribute samplingRate : Frequency = 1e9;
        }
        
        part radioTransmitter {
            attribute transmitPower : Power = -41.3;
        }
        
        part precisionClock {
            attribute resolutionPs : Real = 15.65;
            attribute driftPpb : Real = 20;
        }
        
        part processingUnit {
            attribute clockSpeed : Frequency = 100e6;
        }
        
        part networkInterface {
            attribute protocol : String = "Ethernet";
            attribute dataRateMbps : Real = 100;
        }
        
        state anchorBehavior {
            state Idle;
            state Receiving {
                entry action { "Listen for tag UWB pulses"; }
            }
            state Timestamping {
                entry action { "Record precise arrival time of pulse"; }
            }
            state Calculating {
                entry action { "Compute time-of-flight and distance"; }
            }
            state Reporting {
                entry action { "Send distance measurement to positioning engine"; }
            }
            
            transition from Idle to Receiving when "system active";
            transition from Receiving to Timestamping when "UWB pulse detected";
            transition from Timestamping to Calculating when "timestamp recorded";
            transition from Calculating to Reporting when "distance computed";
            transition from Reporting to Receiving when "measurement sent";
        }
        
        action receivePulse {
            in pulse : UWBPulse;
            out arrivalTime : TimeOfFlight;
        }
        
        action computeDistance {
            in arrivalTime : TimeOfFlight;
            in anchorPos : Position3D;
            out measurement : DistanceMeasurement;
        }
    }
    
    part def PositioningEngine {
        attribute minAnchorsRequired : Integer = 3;
        attribute maxLatencyMs : Real = 50.0;
        attribute algorithm : String = "Least-Squares Trilateration";
        
        port anchorDataPort : AnchorDataPort;
        port outputPort : PositionOutputPort;
        
        part processor {
            attribute clockSpeed : Frequency = 1e9;
            attribute cores : Integer = 4;
        }
        
        part memory {
            attribute sizeMB : Real = 2048;
        }
        
        part anchorDatabase {
            attribute anchorPositions : Position3D[4..*];
            attribute calibrationData : AnchorCalibrationData[4..*];
        }
        
        part trilaterationSolver {
            attribute convergenceThreshold : Real = 0.001;
            attribute maxIterations : Integer = 100;
        }
        
        state engineBehavior {
            state Idle {
                entry action { "System powered on, awaiting commands"; }
            }
            state Calibration {
                entry action { "Perform initial anchor position calibration"; }
            }
            state Ranging {
                entry action { "Perform individual distance measurements"; }
            }
            state Positioning {
                entry action { "Continuously calculate 3D tag positions"; }
            }
            state ErrorRecovery {
                entry action { "Handle faults and reinitialize"; }
            }
            
            transition from Idle to Calibration when "calibration command received";
            transition from Idle to Ranging when "ranging command received";
            transition from Idle to Positioning when "positioning command received";
            transition from Calibration to Idle when "calibration complete";
            transition from Ranging to Positioning when "continuous mode requested";
            transition from Positioning to Ranging when "single ranging requested";
            transition from Positioning to ErrorRecovery when "insufficient anchors or fault detected";
            transition from Ranging to ErrorRecovery when "communication failure";
            transition from ErrorRecovery to Idle when "recovery successful";
        }
        
        action collectMeasurements {
            in measurements : DistanceMeasurement[3..*];
            out collectedSet : DistanceMeasurement[3..*];
        }
        
        action trilaterate {
            in measurements : DistanceMeasurement[3..*];
            in anchorPositions : Position3D[3..*];
            out position : PositionUpdate;
            
            private action validateMeasurements {
                in measurements : DistanceMeasurement[3..*];
                out validSet : DistanceMeasurement[3..*];
            }
            
            private action solveLeastSquares {
                in validSet : DistanceMeasurement[3..*];
                in anchorPositions : Position3D[3..*];
                out rawPosition : Position3D;
            }
            
            private action computeAccuracy {
                in rawPosition : Position3D;
                in validSet : DistanceMeasurement[3..*];
                out accuracy : Distance;
            }
            
            flow from validateMeasurements.validSet to solveLeastSquares.validSet;
            flow from solveLeastSquares.rawPosition to computeAccuracy.rawPosition;
        }
        
        action outputPosition {
            in position : PositionUpdate;
            out position : PositionUpdate;
        }
    }
    
    // ===== Top-level System =====
    
    part def UWBLocationSystem {
        attribute systemAccuracyCm : Real = 10.0;
        attribute updateRateHz : Real = 10.0;
        attribute coverageRadiusM : Real = 100.0;
        attribute maxTags : Integer = 1000;
        
        port externalOutput : PositionOutputPort;
        
        part tags : MobileTag[1..*] {
            attribute tagId : TagId;
        }
        
        part anchors : FixedAnchor[4..*] {
            attribute anchorId : AnchorId;
            attribute position : Position3D;
        }
        
        part positioningEngine : PositioningEngine;
        
        // Connections between tags and anchors (UWB radio)
        connection tagToAnchor : UWBInterface connect tags.uwbPort to anchors.uwbPort;
        
        // Connections between anchors and positioning engine
        connection anchorToEngine : AnchorDataInterface connect anchors.dataPort to positioningEngine.anchorDataPort;
        
        // Output connection
        connection engineOutput connect positioningEngine.outputPort to externalOutput;
        
        state systemOperation {
            state SystemIdle {
                entry action { "All components powered, no active tracking"; }
            }
            state SystemCalibration {
                entry action { "Calibrate anchor positions and antenna delays"; }
            }
            state SystemActive {
                entry action { "Continuous real-time tracking operational"; }
            }
            state SystemFault {
                entry action { "Fault condition, diagnostic mode"; }
            }
            
            transition from SystemIdle to SystemCalibration when "startup initiated";
            transition from SystemCalibration to SystemActive when "all anchors calibrated";
            transition from SystemActive to SystemIdle when "shutdown command";
            transition from SystemActive to SystemFault when "critical failure";
            transition from SystemFault to SystemCalibration when "restart initiated";
        }
    }
    
    // ===== Requirements =====
    
    requirement def AccuracyRequirement {
        attribute requiredAccuracyCm : Real = 10.0;
        subject : UWBLocationSystem;
        objective {
            doc "The system shall achieve centimeter-level 3D positioning accuracy."
        }
        require that systemAccuracyCm <= requiredAccuracyCm
    }
    
    requirement def RealTimeRequirement {
        attribute maxLatencyMs : Real = 50.0;
        attribute minUpdateRateHz : Real = 10.0;
        subject : UWBLocationSystem;
        objective {
            doc "The system shall provide real-time position updates at minimum 10 Hz with less than 50 ms latency."
        }
        require that updateRateHz >= minUpdateRateHz
    }
    
    requirement def AnchorCountRequirement {
        attribute minAnchors : Integer = 4;
        subject : UWBLocationSystem;
        objective {
            doc "The system shall use at least four fixed anchors for 3D trilateration."
        }
        require that anchors->size() >= minAnchors
    }
    
    requirement def TrilaterationRequirement {
        attribute minMeasurements : Integer = 3;
        subject : PositioningEngine;
        objective {
            doc "The positioning engine shall collect distance measurements from at least three anchors to compute a 3D position."
        }
        require that minAnchorsRequired >= minMeasurements
    }
    
    requirement def CoverageRequirement {
        attribute minCoverageRadiusM : Real = 50.0;
        subject : UWBLocationSystem;
        objective {
            doc "The system shall provide coverage over a minimum radius of 50 meters."
        }
        require that coverageRadiusM >= minCoverageRadiusM
    }
    
    requirement def TagCapacityRequirement {
        attribute minTags : Integer = 100;
        subject : UWBLocationSystem;
        objective {
            doc "The system shall support tracking of at least 100 simultaneous tags."
        }
        require that maxTags >= minTags
    }
    
    requirement def CalibrationRequirement {
        subject : UWBLocationSystem;
        objective {
            doc "The system shall include a calibration mode for initial setup of anchor positions and antenna delays."
        }
        require that positioningEngine.engineBehavior.states->exists(s | s.name = "Calibration")
    }
    
    requirement def OperationalStatesRequirement {
        subject : UWBLocationSystem;
        objective {
            doc "The system shall support idle, calibration, ranging, and positioning operational states."
        }
        require that positioningEngine.engineBehavior.states->size() >= 4
    }
    
    requirement def TimeOfFlightRequirement {
        attribute clockResolutionPs : Real = 15.65;
        subject : FixedAnchor;
        objective {
            doc "Each anchor shall measure pulse arrival time with sub-nanosecond precision for accurate time-of-flight calculation."
        }
        require that precisionClock.resolutionPs <= clockResolutionPs
    }
    
    // ===== Verification =====
    
    verification AccuracyTest {
        subject : UWBLocationSystem;
        objective {
            doc "Verify that the system achieves 10 cm or better accuracy in controlled environment."
        }
        method {
            "Place reference tag at known positions and compare calculated positions to ground truth."
        }
    }
    
    verification LatencyTest {
        subject : UWBLocationSystem;
        objective {
            doc "Verify that position updates are delivered within 50 ms."
        }
        method {
            "Measure time from tag pulse transmission to position output."
        }
    }
    
    verification TrilaterationTest {
        subject : PositioningEngine;
        objective {
            doc "Verify that trilateration produces correct 3D coordinates from simulated distance inputs."
        }
        method {
            "Inject known distance measurements and verify computed position matches expected coordinates."
        }
    }
}
