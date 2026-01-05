package 'Radar System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TargetDetected;
    attribute def TargetLost;
    attribute def ScanComplete;
    
    attribute def SignalPower :> ISQ::power;
    attribute def TargetRange :> ISQ::length;
    attribute def TargetVelocity :> ISQ::speed;
    attribute def TargetAzimuth :> ISQ::angle;
    attribute def TargetElevation :> ISQ::angle;
    attribute def RadarFrequency :> ISQ::frequency;
    attribute def PulseWidth :> ISQ::time;
    
    item def RFPulse {
        attribute frequency : RadarFrequency;
        attribute power : SignalPower;
        attribute duration : PulseWidth;
        attribute azimuth : TargetAzimuth;
        attribute elevation : TargetElevation;
    }
    
    item def EchoSignal {
        attribute receivedPower : SignalPower;
        attribute timeDelay : ISQ::time;
        attribute dopplerShift : RadarFrequency;
        attribute azimuth : TargetAzimuth;
        attribute elevation : TargetElevation;
    }
    
    item def TargetData {
        attribute range : TargetRange;
        attribute velocity : TargetVelocity;
        attribute azimuth : TargetAzimuth;
        attribute elevation : TargetElevation;
        attribute signalStrength : SignalPower;
        attribute confidence : Real;
    }
    
    port def RFTransmitPort {
        out pulse : RFPulse;
    }
    
    port def RFReceivePort {
        in echo : EchoSignal;
    }
    
    port def TargetDataPort {
        out targetInfo : TargetData;
    }
    
    port def ControlCommandPort {
        in searchCommand : Boolean;
        in trackCommand : Boolean;
        in standbyCommand : Boolean;
    }
    
    part def Transmitter {
        port txOut : RFTransmitPort;
        
        attribute carrierFrequency : RadarFrequency;
        attribute peakPower : SignalPower;
        attribute pulseRepetitionFrequency : RadarFrequency;
        
        action generatePulse {
            in frequency : RadarFrequency;
            in power : SignalPower;
            in width : PulseWidth;
            in azimuth : TargetAzimuth;
            in elevation : TargetElevation;
            out transmittedPulse : RFPulse;
            
            then assign transmittedPulse.frequency := frequency;
            then assign transmittedPulse.power := power;
            then assign transmittedPulse.duration := width;
            then assign transmittedPulse.azimuth := azimuth;
            then assign transmittedPulse.elevation := elevation;
        }
    }
    
    part def Receiver {
        port rxIn : RFReceivePort;
        
        attribute noiseFigure : Real;
        attribute bandwidth : RadarFrequency;
        attribute minimumDetectablePower : SignalPower;
        
        action amplifyEcho {
            in receivedEcho : EchoSignal;
            out amplifiedEcho : EchoSignal;
            
            then assign amplifiedEcho := receivedEcho;
        }
    }
    
    part def Antenna {
        port txPort : RFTransmitPort;
        port rxPort : RFReceivePort;
        
        attribute antennaGain : Real;
        attribute beamwidthAzimuth : TargetAzimuth;
        attribute beamwidthElevation : TargetElevation;
        attribute scanRate : ISQ::angularVelocity;
        
        action radiatePulse {
            in pulse : RFPulse;
        }
        
        action collectEcho {
            out echo : EchoSignal;
        }
        
        action pointBeam {
            in azimuth : TargetAzimuth;
            in elevation : TargetElevation;
        }
    }
    
    part def SignalProcessor {
        attribute processingGain : Real;
        attribute detectionThreshold : Real;
        
        action computeRange {
            in timeDelay : ISQ::time;
            out range : TargetRange;
        }
        
        action computeVelocity {
            in dopplerShift : RadarFrequency;
            in carrierFrequency : RadarFrequency;
            out velocity : TargetVelocity;
        }
        
        action processEcho {
            in echo : EchoSignal;
            in threshold : Real;
            out target : TargetData;
            
            then action rangeCalc : computeRange {
                in timeDelay = echo.timeDelay;
                out rangeOut;
            }
            then action velocityCalc : computeVelocity {
                in dopplerShift = echo.dopplerShift;
                in carrierFrequency;
                out velocityOut;
            }
            then assign target.range := rangeCalc.rangeOut;
            then assign target.velocity := velocityCalc.velocityOut;
            then assign target.azimuth := echo.azimuth;
            then assign target.elevation := echo.elevation;
            then assign target.signalStrength := echo.receivedPower;
        }
    }
    
    part def ModeController {
        port cmdPort : ControlCommandPort;
        
        attribute currentMode : String;
        
        state radarModes {
            entry; then standby;
            
            state standby {
                entry assign currentMode := "Standby";
            }
            
            state search {
                entry assign currentMode := "Search";
            }
            
            state track {
                entry assign currentMode := "Track";
            }
            
            transition standbyToSearch
                first standby
                accept searchCommand : Boolean via cmdPort
                if searchCommand
                then search;
            
            transition searchToTrack
                first search
                accept targetDetected : TargetDetected
                then track;
            
            transition trackToSearch
                first track
                accept targetLost : TargetLost
                then search;
            
            transition toStandby
                accept standbyCommand : Boolean via cmdPort
                if standbyCommand
                then standby;
        }
    }
    
    part radarSystem {
        attribute systemDesignation : String := "AN/APG-77 Surveillance Radar";
        attribute maxDetectionRange : TargetRange;
        attribute operatingFrequency : RadarFrequency;
        
        part transmitter : Transmitter {
            attribute :>> carrierFrequency;
            attribute :>> peakPower;
            attribute :>> pulseRepetitionFrequency;
        }
        
        part receiver : Receiver {
            attribute :>> noiseFigure;
            attribute :>> bandwidth;
            attribute :>> minimumDetectablePower;
        }
        
        part antenna : Antenna {
            attribute :>> antennaGain;
            attribute :>> beamwidthAzimuth;
            attribute :>> beamwidthElevation;
            attribute :>> scanRate;
        }
        
        part processor : SignalProcessor {
            attribute :>> processingGain;
            attribute :>> detectionThreshold;
        }
        
        part controller : ModeController;
        
        port controlInterface : ControlCommandPort;
        port targetDataOutput : TargetDataPort;
        
        connection txToAntenna connect transmitter.txOut to antenna.txPort;
        connection antennaToRx connect antenna.rxPort to receiver.rxIn;
        
        perform action detectAndTrackTargets {
            first start;
            then merge operationLoop;
            
            action initializeRadar {
                action powerUpTransmitter {
                    perform transmitter.generatePulse;
                }
                then action calibrateReceiver;
                then action positionAntenna {
                    perform antenna.pointBeam;
                }
            }
            
            then action radarCycle {
                action transmitPhase {
                    perform action genPulse : transmitter.generatePulse {
                        in frequency = transmitter.carrierFrequency;
                        in power = transmitter.peakPower;
                        in width;
                        in azimuth;
                        in elevation;
                        out transmittedPulse;
                    }
                    then perform action radiate : antenna.radiatePulse {
                        in pulse = genPulse.transmittedPulse;
                    }
                }
                
                then action scanPhase {
                    perform antenna.pointBeam;
                }
                
                then action receivePhase {
                    perform action collect : antenna.collectEcho {
                        out echo;
                    }
                    then perform action amplify : receiver.amplifyEcho {
                        in receivedEcho = collect.echo;
                        out amplifiedEcho;
                    }
                }
                
                then decide;
                    if amplify.amplifiedEcho.receivedPower > receiver.minimumDetectablePower
                        then processDetection;
                    else operationLoop;
                
                action processDetection {
                    perform action process : processor.processEcho {
                        in echo = amplify.amplifiedEcho;
                        in threshold = processor.detectionThreshold;
                        out target;
                    }
                    then action outputTarget {
                        flow process.target to targetDataOutput.targetInfo;
                    }
                }
                then operationLoop;
            }
            
            then operationLoop;
        }
    }
    
    requirement def <'REQ-RAD-001'> DetectionRangeRequirement {
        doc /* The radar system shall detect targets with a radar cross-section of 1 square meter 
               at ranges up to the specified maximum detection range. */
        
        subject system : radarSystem;
        
        require constraint {
            system.maxDetectionRange >= 200.0 [km]
        }
    }
    
    requirement def <'REQ-RAD-002'> TrackingAccuracyRequirement {
        doc /* The radar system shall provide target position data with specified accuracy 
               in range, azimuth, and elevation. */
        
        subject system : radarSystem;
    }
    
    requirement def <'REQ-RAD-003'> ModeTransitionRequirement {
        doc /* The radar system shall transition between standby, search, and track modes 
               in response to operator commands and target detection events. */
        
        subject ctrl : ModeController;
        
        require constraint {
            ctrl.currentMode == "Standby" or 
            ctrl.currentMode == "Search" or 
            ctrl.currentMode == "Track"
        }
    }
    
    requirement def <'REQ-RAD-004'> UpdateRateRequirement {
        doc /* The radar system shall provide target updates at a minimum rate of 1 Hz 
               during track mode operation. */
        
        subject system : radarSystem;
    }
    
    requirement <'SYS-RAD-001'> radarSystemRequirement {
        doc /* The radar system shall detect, locate, and track airborne and surface targets 
               within its surveillance volume by transmitting electromagnetic pulses and 
               processing reflected echoes to extract target range, velocity, and angular position. */
        
        subject system : radarSystem;
        
        require detectionReq : <'REQ-RAD-001'> DetectionRangeRequirement {
            subject system = radarSystem;
        }
        require trackingReq : <'REQ-RAD-002'> TrackingAccuracyRequirement {
            subject system = radarSystem;
        }
        require modeReq : <'REQ-RAD-003'> ModeTransitionRequirement {
            subject ctrl = radarSystem.controller;
        }
        require updateReq : <'REQ-RAD-004'> UpdateRateRequirement {
            subject system = radarSystem;
        }
    }
    
    action def DetectAndTrackTargets {
        in operatingMode : String;
        in scanSector : TargetAzimuth;
        out detectedTargets : TargetData[*];
    }
}
