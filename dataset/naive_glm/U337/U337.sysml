package OEP_System {
    import ScalarValues::*;
    import ISQ::*;

    // Value Types
    value type LengthValue :> Real { unit = 'm'; }
    value type VolumeValue :> Real { unit = 'L'; }
    value type RateValue :> Real { unit = 'breaths/min'; }
    value type FlowRateValue :> Real { unit = 'L/min'; }
    value type CoordinateValue :> Real { unit = 'm'; }
    
    // Item Definitions
    item def VideoFrame {
        attribute frameID : Integer;
        attribute timestamp : Real;
    }
    
    item def MarkerPosition3D {
        attribute markerID : Integer;
        attribute x : CoordinateValue;
        attribute y : CoordinateValue;
        attribute z : CoordinateValue;
    }
    
    item def CompartmentVolume {
        attribute timestamp : Real;
        attribute ribCageVolume : VolumeValue;
        attribute abdominalVolume : VolumeValue;
    }
    
    item def RespiratoryMetrics {
        attribute timestamp : Real;
        attribute tidalVolume : VolumeValue;
        attribute respiratoryRate : RateValue;
        attribute minuteVentilation : FlowRateValue;
    }
    
    item def AlertSignal {
        attribute alertType : String;
        attribute severity : Integer;
    }

    // Port Definitions
    port def VideoPort {
        out videoStream : VideoFrame;
    }
    
    port def PositionPort {
        out positions : MarkerPosition3D[0..*];
    }
    
    port def VolumePort {
        out volumeStream : CompartmentVolume;
    }
    
    port def MetricsPort {
        out metrics : RespiratoryMetrics;
        out alert : AlertSignal;
    }
    
    port def ControlPort {
        out status : String;
    }
    
    port def DisplayPort {
        in metrics : RespiratoryMetrics;
        in alert : AlertSignal;
        in status : String;
    }
    
    port def PowerPort {
        out voltage : Real;
        out current : Real;
    }

    // Part Definitions
    part def ReflectiveMarker {
        attribute markerID : Integer;
    }
    
    part def IRSource {
        attribute wavelength : LengthValue;
    }
    
    part def IRCamera {
        attribute resolution : Integer;
        attribute frameRate : Real;
        port powerIn : PowerPort;
        port videoOut : VideoPort;
    }
    
    part def ImageProcessingUnit {
        port powerIn : PowerPort;
        port videoIn : VideoPort[8];
        port positionOut : PositionPort;
        
        action def ProcessImages {
            in frames : VideoFrame[8];
            out positions : MarkerPosition3D[0..*];
        }
    }
    
    part def VolumeComputationUnit {
        port powerIn : PowerPort;
        port positionIn : PositionPort;
        port volumeOut : VolumePort;
        
        action def ComputeVolumes {
            in positions : MarkerPosition3D[0..*];
            out volumes : CompartmentVolume;
        }
    }
    
    part def RespiratoryAnalysisUnit {
        port powerIn : PowerPort;
        port volumeIn : VolumePort;
        port metricsOut : MetricsPort;
        
        action def AnalyzeRespiration {
            in volumes : CompartmentVolume;
            out metrics : RespiratoryMetrics;
            out alert : AlertSignal;
        }
    }
    
    part def DisplayMonitor {
        port powerIn : PowerPort;
        port displayIn : DisplayPort;
    }
    
    part def PowerSupply {
        port powerOut : PowerPort;
    }
    
    part def CentralController {
        port powerIn : PowerPort;
        port controlOut : ControlPort;
        
        attribute currentState : String;
        
        state def ControllerStates {
            initial transition to Offline;
            
            state Offline {
                entry { currentState = "Offline"; }
                transition to Calibrating on powerOn;
            }
            
            state Calibrating {
                entry { currentState = "Calibrating"; }
                transition to Monitoring on calibrationComplete;
            }
            
            state Monitoring {
                entry { currentState = "Monitoring"; }
                transition to Alerting on abnormalPatternDetected;
                transition to Offline on powerOff;
            }
            
            state Alerting {
                entry { currentState = "Alerting"; }
                transition to Monitoring on alertAcknowledged;
                transition to Offline on powerOff;
            }
        }
    }

    part def OEP_System {
        part powerSupply : PowerSupply;
        part controller : CentralController;
        part markers : ReflectiveMarker[89];
        part illumination : IRSource[8];
        part cameras : IRCamera[8];
        part imageProcessor : ImageProcessingUnit;
        part volumeComputer : VolumeComputationUnit;
        part respiratoryAnalyzer : RespiratoryAnalysisUnit;
        part display : DisplayMonitor;
        
        connection powerToController : PowerPort connect powerSupply.powerOut to controller.powerIn;
        connection powerToCameras : PowerPort connect powerSupply.powerOut to cameras.powerIn;
        connection powerToProcessor : PowerPort connect powerSupply.powerOut to imageProcessor.powerIn;
        connection powerToVolume : PowerPort connect powerSupply.powerOut to volumeComputer.powerIn;
        connection powerToResp : PowerPort connect powerSupply.powerOut to respiratoryAnalyzer.powerIn;
        connection powerToDisplay : PowerPort connect powerSupply.powerOut to display.powerIn;
        
        connection videoFeeds : VideoPort connect cameras.videoOut to imageProcessor.videoIn;
        connection positionData : PositionPort connect imageProcessor.positionOut to volumeComputer.positionIn;
        connection volumeData : VolumePort connect volumeComputer.volumeOut to respiratoryAnalyzer.volumeIn;
        connection metricsData : MetricsPort connect respiratoryAnalyzer.metricsOut to display.displayIn;
        connection controlData : ControlPort connect controller.controlOut to display.displayIn;
    }

    // Requirements
    requirement def OEP_Requirements {
        requirement Track3DMovement {
            doc "The system shall track the 3D movement of 89 markers on the patient's torso."
        }
        requirement IlluminateWithIR {
            doc "The system shall illuminate the markers with 8 infrared light sources."
        }
        requirement CaptureWithIRCameras {
            doc "The system shall capture reflected light with 8 high-speed infrared cameras."
        }
        requirement ProcessImages {
            doc "The Image Processing Unit shall identify markers and calculate 3D coordinates via triangulation."
        }
        requirement ComputeVolume {
            doc "The Volume Computation Unit shall reconstruct the chest wall and calculate rib cage and abdominal volumes."
        }
        requirement AnalyzeRespiration {
            doc "The Respiratory Analysis Unit shall calculate tidal volume, respiratory rate, and minute ventilation."
        }
        requirement SafetyAlerts {
            doc "The Respiratory Analysis Unit shall trigger an alert if abnormal breathing patterns are detected."
        }
        requirement SystemStates {
            doc "The Central Controller shall manage system states: offline, calibrating, monitoring, and alerting."
        }
        requirement DisplayMetrics {
            doc "The system shall display computed respiratory information on a display monitor."
        }
    }
}
