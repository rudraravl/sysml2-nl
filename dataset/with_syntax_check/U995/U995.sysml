package 'Baby Monitor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SoundLevel {
        attribute value : Real;
        attribute unit : String = "dB";
    }
    
    attribute def VideoQuality {
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : Real;
    }
    
    attribute def RoomTemperature :> ISQ::ThermodynamicTemperatureValue;
    
    attribute def AlertType {
        attribute severity : String;
        attribute description : String;
    }
    
    item def AudioStream;
    item def VideoStream;
    item def SensorData;
    item def AlertSignal;
    
    port def AudioOutputPort {
        out audioSignal : AudioStream;
    }
    
    port def VideoOutputPort {
        out videoSignal : VideoStream;
    }
    
    port def SensorOutputPort {
        out sensorData : SensorData;
    }
    
    port def AudioInputPort {
        in audioSignal : AudioStream;
    }
    
    port def VideoInputPort {
        in videoSignal : VideoStream;
    }
    
    port def AlertOutputPort {
        out alert : AlertSignal;
    }
    
    port def AlertInputPort {
        in alert : AlertSignal;
    }
    
    part def Microphone {
        port audioOut : AudioOutputPort;
        attribute sensitivity : Real = 0.85;
        attribute maxSoundLevel : SoundLevel {
            attribute value = 120.0;
        }
    }
    
    part def Camera {
        port videoOut : VideoOutputPort;
        attribute resolution : VideoQuality {
            attribute width = 1920;
            attribute height = 1080;
            attribute frameRate = 30.0;
        }
        attribute nightVision : Boolean = true;
        attribute fieldOfView : Real = 110.0;
    }
    
    part def TemperatureSensor {
        port sensorOut : SensorOutputPort;
        attribute accuracy : Real = 0.5;
        attribute range : RoomTemperature;
    }
    
    part def MotionDetector {
        port alertOut : AlertOutputPort;
        attribute sensitivity : Real = 0.7;
        attribute detectionRange : ISQ::LengthValue;
    }
    
    part def SoundAnalyzer {
        port audioIn : AudioInputPort;
        port alertOut : AlertOutputPort;
        attribute cryDetectionThreshold : SoundLevel {
            attribute value = 55.0;
        }
        attribute noiseThreshold : SoundLevel {
            attribute value = 40.0;
        }
    }
    
    part def WirelessTransmitter {
        port audioIn : AudioInputPort;
        port videoIn : VideoInputPort;
        port sensorIn : SensorOutputPort;
        attribute frequency : Real = 2.4;
        attribute transmissionPower : ISQ::PowerValue;
        attribute range : ISQ::LengthValue;
    }
    
    part def WirelessReceiver {
        port audioOut : AudioOutputPort;
        port videoOut : VideoOutputPort;
        port alertOut : AlertOutputPort;
        attribute frequency : Real = 2.4;
    }
    
    part def Display {
        port videoIn : VideoInputPort;
        attribute screenSize : ISQ::LengthValue;
        attribute brightness : Real;
    }
    
    part def Speaker {
        port audioIn : AudioInputPort;
        attribute volumeLevel : Real;
        attribute maxOutput : ISQ::PowerValue;
    }
    
    part def AlertNotifier {
        port alertIn : AlertInputPort;
        attribute visualAlertEnabled : Boolean = true;
        attribute audioAlertEnabled : Boolean = true;
        attribute vibrationEnabled : Boolean = true;
    }
    
    part def BabyUnit {
        part microphone : Microphone {
            port audioOut;
        }
        
        part camera : Camera {
            port videoOut;
        }
        
        part tempSensor : TemperatureSensor {
            port sensorOut;
        }
        
        part motionDetector : MotionDetector {
            port alertOut;
        }
        
        part soundAnalyzer : SoundAnalyzer {
            port audioIn;
            port alertOut;
        }
        
        part transmitter : WirelessTransmitter {
            port audioIn;
            port videoIn;
            port sensorIn;
        }
        
        connect microphone.audioOut to soundAnalyzer.audioIn;
        connect microphone.audioOut to transmitter.audioIn;
        connect camera.videoOut to transmitter.videoIn;
        connect tempSensor.sensorOut to transmitter.sensorIn;
    }
    
    part def ParentUnit {
        part receiver : WirelessReceiver {
            port audioOut;
            port videoOut;
            port alertOut;
        }
        
        part display : Display {
            port videoIn;
        }
        
        part speaker : Speaker {
            port audioIn;
        }
        
        part alertNotifier : AlertNotifier {
            port alertIn;
        }
        
        connect receiver.videoOut to display.videoIn;
        connect receiver.audioOut to speaker.audioIn;
        connect receiver.alertOut to alertNotifier.alertIn;
    }
    
    action def CaptureAudio {
        out audioLevel : SoundLevel;
        out audioStream : AudioStream;
    }
    
    action def CaptureVideo {
        out videoStream : VideoStream;
    }
    
    action def MeasureTemperature {
        out temperature : RoomTemperature;
    }
    
    action def DetectMotion {
        out motionDetected : Boolean;
    }
    
    action def AnalyzeSound {
        in audioLevel : SoundLevel;
        in threshold : SoundLevel;
        out cryDetected : Boolean;
    }
    
    action def TransmitData {
        in audioStream : AudioStream;
        in videoStream : VideoStream;
        in sensorData : SensorData;
        out transmissionSuccess : Boolean;
    }
    
    action def ReceiveData {
        out audioStream : AudioStream;
        out videoStream : VideoStream;
        out alerts : AlertSignal;
    }
    
    action def DisplayContent {
        in videoStream : VideoStream;
        in audioStream : AudioStream;
    }
    
    action def IssueAlert {
        in alertType : AlertType;
        out visualAlert : Boolean;
        out audioAlert : Boolean;
        out vibrationAlert : Boolean;
    }
    
    action def MonitorBabyEnvironment {
        first start;
        then merge continuousMonitoring;
        
        action captureAudio : CaptureAudio {
            out audioLevel : SoundLevel;
            out audioStream : AudioStream;
        }
        
        action captureVideo : CaptureVideo {
            out videoStream : VideoStream;
        }
        
        action measureTemp : MeasureTemperature {
            out temperature : RoomTemperature;
        }
        
        action detectMotion : DetectMotion {
            out motionDetected : Boolean;
        }
        
        action analyzeSound : AnalyzeSound {
            in audioLevel = captureAudio.audioLevel;
            in threshold : SoundLevel;
            out cryDetected : Boolean;
        }
        
        then decide;
            if analyzeSound.cryDetected then notifyCrying;
            if detectMotion.motionDetected then notifyMotion;
            if measureTemp.temperature.num > 25.0 then notifyTemperature;
            else transmitNormal;
        
        action transmitNormal : TransmitData {
            in audioStream = captureAudio.audioStream;
            in videoStream = captureVideo.videoStream;
            in sensorData : SensorData;
            out transmissionSuccess : Boolean;
        }
        
        then continuousMonitoring;
        
        action notifyCrying : IssueAlert {
            in alertType : AlertType;
            out visualAlert : Boolean;
            out audioAlert : Boolean;
            out vibrationAlert : Boolean;
        }
        
        then continuousMonitoring;
        
        action notifyMotion : IssueAlert {
            in alertType : AlertType;
            out visualAlert : Boolean;
            out audioAlert : Boolean;
            out vibrationAlert : Boolean;
        }
        
        then continuousMonitoring;
        
        action notifyTemperature : IssueAlert {
            in alertType : AlertType;
            out visualAlert : Boolean;
            out audioAlert : Boolean;
            out vibrationAlert : Boolean;
        }
        
        then continuousMonitoring;
    }
    
    state def BabyMonitorStateMachine {
        entry; then Idle;
        
        state Idle;
        
        state Active {
            entry; then Monitoring;
            
            state Monitoring {
                entry action captureData : CaptureAudio;
            }
            
            state Alerting {
                entry action triggerAlert : IssueAlert;
            }
        }
        
        state LowPower;
        
        transition first Idle then Active accept systemPoweredOn;
        transition first Active.Monitoring then Active.Alerting accept soundLevelHigh;
        transition first Active.Alerting then Active.Monitoring accept alertAcknowledged;
        transition first Active then LowPower accept batteryLow;
        transition first LowPower then Active accept batteryCharged;
        transition first Active then Idle accept systemPoweredOff;
    }
    
    part babyMonitorSystem {
        part babyUnit : BabyUnit {
            perform action monitoring : MonitorBabyEnvironment;
        }
        
        part parentUnit : ParentUnit;
        
        connect babyUnit.transmitter.audioIn to parentUnit.receiver.audioOut;
        connect babyUnit.transmitter.videoIn to parentUnit.receiver.videoOut;
    }
    
    requirement def SystemPurpose {
        doc /* The baby monitor system shall provide continuous remote monitoring 
               of an infant's environment to ensure safety and enable timely caregiver response. */
        subject babyMonitorSystem;
    }
    
    requirement def AudioMonitoringRequirement {
        doc /* The system shall continuously capture and transmit audio from the baby's room, 
               detecting crying or distress sounds above 55 dB. */
        subject babyMonitorSystem.babyUnit.microphone;
    }
    
    requirement def VideoMonitoringRequirement {
        doc /* The system shall provide real-time video streaming at minimum 1080p resolution 
               with night vision capability. */
        subject babyMonitorSystem.babyUnit.camera;
    }
    
    requirement def TemperatureMonitoringRequirement {
        doc /* The system shall monitor room temperature with 0.5 degree accuracy and alert 
               if temperature exceeds safe thresholds. */
        subject babyMonitorSystem.babyUnit.tempSensor;
    }
    
    requirement def MotionDetectionRequirement {
        doc /* The system shall detect motion in the baby's vicinity and alert the caregiver. */
        subject babyMonitorSystem.babyUnit.motionDetector;
    }
    
    requirement def WirelessRangeRequirement {
        doc /* The wireless transmission shall maintain stable connection up to 300 meters 
               in open space. */
        subject babyMonitorSystem.babyUnit.transmitter;
    }
    
    requirement def AlertSystemRequirement {
        doc /* The parent unit shall provide multi-modal alerts including visual, audio, 
               and vibration notifications. */
        subject babyMonitorSystem.parentUnit.alertNotifier;
    }
    
    requirement def ReliabilityRequirement {
        doc /* The system shall operate continuously with 99.9% uptime and automatic 
               reconnection capability. */
        subject babyMonitorSystem;
    }
    
    requirement primaryFunction : SystemPurpose {
        require AudioMonitoringRequirement;
        require VideoMonitoringRequirement;
        require TemperatureMonitoringRequirement;
        require MotionDetectionRequirement;
        require WirelessRangeRequirement;
        require AlertSystemRequirement;
        require ReliabilityRequirement;
    }
}
