package 'Extron DTP CrossPoint 84 4K' {
    private import ScalarValues::*;
    
    attribute def Latency :> Real;
    attribute def Efficiency :> Real;
    attribute def Voltage :> Real;
    attribute def Current :> Real;
    attribute def Frequency :> Real;
    attribute def Decibel :> Real;
    
    item def VideoSignal {
        attribute resolution : String;
        attribute format : String;
        attribute frameRate : Frequency;
    }
    item def AudioSignal {
        attribute format : String;
        attribute channels : Integer;
        attribute sampleRate : Frequency;
        attribute level : Decibel;
    }
    item def ControlCommand {
        attribute commandType : String;
        attribute target : String;
        attribute parameters : String;
    }
    item def Power;
    
    port def VideoInputPort { in item video : VideoSignal; }
    port def VideoOutputPort { out item video : VideoSignal; }
    port def AudioInputPort { in item audio : AudioSignal; }
    port def AudioOutputPort { out item audio : AudioSignal; }
    port def ControlPort {
        in item command : ControlCommand;
        out item status : ControlCommand;
    }
    port def NetworkPort {
        in item command : ControlCommand;
        out item status : ControlCommand;
    }
    port def PowerPort { in item power : Power; }
    
    part def MatrixSwitcher {
        port videoIn : VideoInputPort[8];
        port directVideoOut : VideoOutputPort[6];
        port scaler1Feed : VideoOutputPort;
        port scaler2Feed : VideoOutputPort;
        port audioIn : AudioInputPort[8];
        port audioOut : AudioOutputPort[8];
        port controlPort : ControlPort;
        port powerIn : PowerPort;
        
        state SwitchingBehavior {
            entry; then Monitoring;
            state Monitoring {
                do action checkInputs;
            }
            transition
                first Monitoring
                accept command : ControlCommand via controlPort
                then Routing;
            state Routing {
                do action routeSignals;
            }
            transition
                first Routing
                then Monitoring;
        }
    }
    
    part def VideoScaler {
        port videoIn : VideoInputPort;
        port videoOut : VideoOutputPort;
        port controlPort : ControlPort;
        port powerIn : PowerPort;
        attribute maxLatency : Latency = 5;
        attribute targetResolution : String = "4K";
        
        state ScalingBehavior {
            entry; then Idle;
            state Idle;
            transition
                first Idle
                accept command : ControlCommand via controlPort
                then Processing;
            state Processing {
                do action scaleVideo;
            }
            transition
                first Processing
                then Idle;
        }
    }
    
    part def AudioProcessor {
        port audioIn : AudioInputPort[8];
        port audioOut : AudioOutputPort[8];
        port controlPort : ControlPort;
        port powerIn : PowerPort;
        attribute eqBands : Integer = 10;
        attribute surroundFormat : String = "7.1";
        
        state AudioBehavior {
            entry; then Idle;
            state Idle;
            transition
                first Idle
                accept command : ControlCommand via controlPort
                then Mixing;
            state Mixing {
                do action mixAudio;
            }
            transition
                first Mixing
                then Equalizing;
            state Equalizing {
                do action applyEQ;
            }
            transition
                first Equalizing
                then DynamicRange;
            state DynamicRange {
                do action compressDynamicRange;
            }
            transition
                first DynamicRange
                then Idle;
        }
    }
    
    part def ControlSystem {
        port networkPort : NetworkPort;
        port switcherControl : ~ControlPort;
        port scaler1Control : ~ControlPort;
        port scaler2Control : ~ControlPort;
        port audioControl : ~ControlPort;
        port powerIn : PowerPort;
        attribute ipAddress : String;
        attribute macAddress : String;
        attribute firmwareVersion : String;
        attribute authenticated : Boolean = false;
        
        state ControlBehavior {
            entry; then Idle;
            state Idle;
            transition
                first Idle
                accept command : ControlCommand via networkPort
                then Authenticating;
            state Authenticating {
                do action authenticate;
            }
            transition
                first Authenticating
                if authenticated
                then Dispatching;
            transition
                first Authenticating
                if not authenticated
                then Idle;
            state Dispatching {
                do action dispatch;
            }
            transition
                first Dispatching
                then Idle;
        }
    }
    
    part def PowerDistribution {
        port acIn : PowerPort;
        port dcOut : ~PowerPort;
        attribute efficiency : Efficiency = 88;
        attribute outputVoltage : Voltage = 12;
        attribute maxCurrent : Current = 10;
        
        constraint efficiencyConstraint {
            efficiency >= 88
        }
    }
    
    part def AVDistributionSystem {
        part matrixSwitcher : MatrixSwitcher;
        part videoScaler1 : VideoScaler;
        part videoScaler2 : VideoScaler;
        part audioProcessor : AudioProcessor;
        part controlSystem : ControlSystem;
        part powerDistribution : PowerDistribution;
        
        port sysVideoIn : ~VideoInputPort[8];
        port sysVideoOut1 : ~VideoOutputPort;
        port sysVideoOut2 : ~VideoOutputPort;
        port sysVideoOutDirect : ~VideoOutputPort[6];
        port sysAudioIn : ~AudioInputPort[8];
        port sysAudioOut : ~AudioOutputPort[8];
        port sysNetwork : ~NetworkPort;
        port sysPower : ~PowerPort;
        
        connect sysVideoIn to matrixSwitcher.videoIn;
        connect sysAudioIn to matrixSwitcher.audioIn;
        
        connect matrixSwitcher.scaler1Feed to videoScaler1.videoIn;
        connect matrixSwitcher.scaler2Feed to videoScaler2.videoIn;
        connect videoScaler1.videoOut to sysVideoOut1;
        connect videoScaler2.videoOut to sysVideoOut2;
        connect matrixSwitcher.directVideoOut to sysVideoOutDirect;
        
        connect matrixSwitcher.audioOut to audioProcessor.audioIn;
        connect audioProcessor.audioOut to sysAudioOut;
        
        connect sysNetwork to controlSystem.networkPort;
        connect controlSystem.switcherControl to matrixSwitcher.controlPort;
        connect controlSystem.scaler1Control to videoScaler1.controlPort;
        connect controlSystem.scaler2Control to videoScaler2.controlPort;
        connect controlSystem.audioControl to audioProcessor.controlPort;
        
        connect sysPower to powerDistribution.acIn;
        connect powerDistribution.dcOut to matrixSwitcher.powerIn;
        connect powerDistribution.dcOut to videoScaler1.powerIn;
        connect powerDistribution.dcOut to videoScaler2.powerIn;
        connect powerDistribution.dcOut to audioProcessor.powerIn;
        connect powerDistribution.dcOut to controlSystem.powerIn;
    }
    
    requirement def RoutingRequirement {
        subject system : AVDistributionSystem;
        doc /* The system shall route any video or audio input to any combination of outputs seamlessly. */
    }
    requirement def LatencyRequirement {
        subject scaler : VideoScaler;
        attribute maxLatency : Latency = 5;
        doc /* Video scaling latency shall be less than maxLatency milliseconds. */
    }
    requirement def AudioProcessingRequirement {
        subject processor : AudioProcessor;
        doc /* The audio processor shall support mixing, 10-band equalization, and dynamic range processing for stereo to 7.1 surround sound. */
    }
    requirement def ControlRequirement {
        subject controller : ControlSystem;
        doc /* The control system shall authenticate network commands before dispatching to subsystems. */
    }
    requirement def PowerRequirement {
        subject power : PowerDistribution;
        attribute minEfficiency : Efficiency = 88;
        doc /* The power distribution unit shall achieve efficiency greater than 88 percent. */
    }
}
