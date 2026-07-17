package TelepresenceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VideoResolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    attribute def AudioQuality {
        attribute sampleRate : Real;
        attribute bitDepth : Integer;
    }
    
    attribute def NetworkBandwidth :> Real;
    
    attribute def LatencyValue :> ISQ::DurationValue;
    
    item def VideoStream {
        attribute resolution : VideoResolution;
        attribute frameRate : Real;
        attribute bandwidth : NetworkBandwidth;
    }
    
    item def AudioStream {
        attribute quality : AudioQuality;
        attribute bandwidth : NetworkBandwidth;
    }
    
    item def ControlCommand {
        attribute commandType : String;
        attribute timestamp : Real;
    }
    
    item def DataPacket {
        attribute timestamp : Real;
        attribute sequenceNumber : Integer;
        attribute payload : String;
    }
    
    port def VideoInputPort {
        in item videoSignal : VideoStream;
    }
    
    port def AudioInputPort {
        in item audioSignal : AudioStream;
    }
    
    port def VideoOutputPort {
        out item videoSignal : VideoStream;
    }
    
    port def AudioOutputPort {
        out item audioSignal : AudioStream;
    }
    
    port def NetworkPort {
        in item receivedData : DataPacket;
        out item transmittedData : DataPacket;
    }
    
    port def ControlPort {
        in item command : ControlCommand;
        out item status : ControlCommand;
    }
    
    part def Camera {
        attribute resolution : VideoResolution;
        attribute fieldOfView : ISQ::PlaneAngleValue;
        port videoOut : VideoOutputPort;
        port control : ControlPort;
    }
    
    part def Microphone {
        attribute sensitivity : Real;
        attribute frequencyResponse : Real;
        port audioOut : AudioOutputPort;
    }
    
    part def Display {
        attribute screenSize : ISQ::LengthValue;
        attribute resolution : VideoResolution;
        port videoIn : VideoInputPort;
    }
    
    part def Speaker {
        attribute powerOutput : ISQ::PowerValue;
        attribute frequencyRange : Real;
        port audioIn : AudioInputPort;
    }
    
    part def VideoEncoder {
        attribute compressionRatio : Real;
        port videoIn : VideoInputPort;
        port encodedOut : NetworkPort;
    }
    
    part def AudioEncoder {
        attribute codec : String;
        port audioIn : AudioInputPort;
        port encodedOut : NetworkPort;
    }
    
    part def VideoDecoder {
        port encodedIn : NetworkPort;
        port videoOut : VideoOutputPort;
    }
    
    part def AudioDecoder {
        port encodedIn : NetworkPort;
        port audioOut : AudioOutputPort;
    }
    
    state def ConnectionStateMachine {
        entry; then Disconnected;
        
        state Disconnected;
        accept at Disconnected then Connecting;
        
        state Connecting;
        accept at Connecting then Connected;
        accept at Connecting then Disconnected;
        
        state Connected;
        accept at Connected then Reconnecting;
        accept at Connected then Disconnecting;
        
        state Reconnecting;
        accept at Reconnecting then Connected;
        accept at Reconnecting then Disconnected;
        
        state Disconnecting;
        accept at Disconnecting then Disconnected;
    }
    
    part def NetworkInterface {
        attribute bandwidth : NetworkBandwidth;
        attribute latency : LatencyValue;
        port localPort : NetworkPort;
        port remotePort : NetworkPort;
        
        exhibit state connectionState : ConnectionStateMachine;
    }
    
    action def CaptureVideo {
        in cameraSettings : VideoResolution;
        out videoStream : VideoStream;
    }
    
    action def CaptureAudio {
        in microphoneSettings : AudioQuality;
        out audioStream : AudioStream;
    }
    
    action def EncodeMedia {
        in rawVideo : VideoStream;
        in rawAudio : AudioStream;
        out encodedData : DataPacket;
    }
    
    action def TransmitData {
        in data : DataPacket;
        in networkBandwidth : NetworkBandwidth;
        out transmissionStatus : Boolean;
    }
    
    action def ReceiveData {
        in networkBandwidth : NetworkBandwidth;
        out receivedData : DataPacket;
    }
    
    action def DecodeMedia {
        in encodedData : DataPacket;
        out decodedVideo : VideoStream;
        out decodedAudio : AudioStream;
    }
    
    action def RenderVideo {
        in videoStream : VideoStream;
        out displaySignal : Boolean;
    }
    
    action def PlayAudio {
        in audioStream : AudioStream;
        out audioSignal : Boolean;
    }
    
    action def EstablishConnection {
        in remoteAddress : String;
        in localBandwidth : NetworkBandwidth;
        out connectionEstablished : Boolean;
    }
    
    action def MonitorQuality {
        in currentLatency : LatencyValue;
        in currentBandwidth : NetworkBandwidth;
        out qualityScore : Real;
    }
    
    action def TelepresenceSession {
        first start;
        then action establishConnection : EstablishConnection {
            in remoteAddress : String;
            in localBandwidth : NetworkBandwidth;
            out connectionEstablished : Boolean;
        }
        then decide;
            if establishConnection.connectionEstablished then beginSession;
            if not establishConnection.connectionEstablished then endSession;
        
        action beginSession {
            first merge continueSession;
            then action parallelCapture {
                action captureVideo : CaptureVideo {
                    in cameraSettings : VideoResolution;
                    out videoStream : VideoStream;
                }
                action captureAudio : CaptureAudio {
                    in microphoneSettings : AudioQuality;
                    out audioStream : AudioStream;
                }
            }
            then action encodeMedia : EncodeMedia {
                in rawVideo : VideoStream = parallelCapture.captureVideo.videoStream;
                in rawAudio : AudioStream = parallelCapture.captureAudio.audioStream;
                out encodedData : DataPacket;
            }
            then action transmitData : TransmitData {
                in data : DataPacket = encodeMedia.encodedData;
                in networkBandwidth : NetworkBandwidth;
                out transmissionStatus : Boolean;
            }
            then action receiveData : ReceiveData {
                in networkBandwidth : NetworkBandwidth;
                out receivedData : DataPacket;
            }
            then action decodeMedia : DecodeMedia {
                in encodedData : DataPacket = receiveData.receivedData;
                out decodedVideo : VideoStream;
                out decodedAudio : AudioStream;
            }
            then action parallelRender {
                action renderVideo : RenderVideo {
                    in videoStream : VideoStream = decodeMedia.decodedVideo;
                    out displaySignal : Boolean;
                }
                action playAudio : PlayAudio {
                    in audioStream : AudioStream = decodeMedia.decodedAudio;
                    out audioSignal : Boolean;
                }
            }
            then action monitorQuality : MonitorQuality {
                in currentLatency : LatencyValue;
                in currentBandwidth : NetworkBandwidth;
                out qualityScore : Real;
            }
            then decide;
                if monitorQuality.qualityScore > 0.5 then continueSession;
                if monitorQuality.qualityScore <= 0.5 then endSession;
        }
        
        action endSession;
        then done;
    }
    
    part def TelepresenceEndpoint {
        part camera : Camera;
        part microphone : Microphone;
        part display : Display;
        part speaker : Speaker;
        part videoEncoder : VideoEncoder;
        part audioEncoder : AudioEncoder;
        part videoDecoder : VideoDecoder;
        part audioDecoder : AudioDecoder;
        part networkInterface : NetworkInterface;
        
        connection connect camera.videoOut to videoEncoder.videoIn;
        connection connect microphone.audioOut to audioEncoder.audioIn;
        connection connect videoDecoder.videoOut to display.videoIn;
        connection connect audioDecoder.audioOut to speaker.audioIn;
    }
    
    part telepresenceSystem {
        part localEndpoint : TelepresenceEndpoint;
        part remoteEndpoint : TelepresenceEndpoint;
        
        connection networkLink connect localEndpoint.networkInterface.remotePort 
            to remoteEndpoint.networkInterface.localPort;
        
        perform action session : TelepresenceSession;
    }
    
    requirement def AudioVideoSyncRequirement {
        doc /* The audio and video streams shall be synchronized within 40 milliseconds. */
        subject syncedStreams : TelepresenceEndpoint;
        require constraint {
            syncedStreams.videoDecoder.encodedIn.receivedData.timestamp - 
            syncedStreams.audioDecoder.encodedIn.receivedData.timestamp <= 0.04
        }
    }
    
    requirement def MinimumBandwidthRequirement {
        doc /* The network connection shall support a minimum bandwidth of 2 Mbps. */
        subject network : NetworkInterface;
        require constraint {
            network.bandwidth >= 2.0e6
        }
    }
    
    requirement def MaximumLatencyRequirement {
        doc /* The end-to-end latency shall not exceed 150 milliseconds. */
        subject network : NetworkInterface;
        require constraint {
            network.latency <= 0.15[SI::s]
        }
    }
    
    requirement def VideoQualityRequirement {
        doc /* The video resolution shall be at least 1280x720 at 30 frames per second. */
        subject videoStream : VideoStream;
        require constraint {
            videoStream.resolution.width >= 1280 and 
            videoStream.resolution.height >= 720 and 
            videoStream.frameRate >= 30.0
        }
    }
    
    requirement telepresenceSystemRequirements {
        doc /* The telepresence system shall enable real-time audio and video communication 
               between remote participants with high quality and low latency. */
        
        require audioVideoSyncRequirement : AudioVideoSyncRequirement;
        require minimumBandwidthRequirement : MinimumBandwidthRequirement;
        require maximumLatencyRequirement : MaximumLatencyRequirement;
        require videoQualityRequirement : VideoQualityRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import TelepresenceSystem::*;

    part testSubject : NetworkInterface {
        exhibit state connectionState : ConnectionStateMachine;
    }

    action orchestrator {
        attribute testCameraSettings : VideoResolution {
            attribute width = 0;
            attribute height = 0;
        }
        action captureVideoProbe : CaptureVideo {
            in cameraSettings = testCameraSettings;
        }
        first captureVideoProbe;
    }
}
