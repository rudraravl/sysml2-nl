package ChromecastStreamingSystem {
    attribute def startStream;
    attribute def pauseCommand;
    attribute def resumeCommand;
    attribute def stopCommand;
    attribute def resetCommand;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def Resolution {
        attribute width : Integer;
        attribute height : Integer;
    }

    enum def StreamQuality {
        sd;
        hd;
        uhd;
    }

    enum def ConnectionState {
        disconnected;
        discovering;
        authenticating;
        connected;
        streaming;
        paused;
        error;
    }

    item def MediaStream {
        attribute contentUrl : String;
        attribute contentType : String;
        attribute quality : StreamQuality;
        attribute duration : DurationValue;
    }

    item def CastCommand {
        attribute commandType : String;
        attribute mediaUrl : String;
        attribute targetDeviceId : String;
    }

    item def HDMISignal {
        attribute videoResolution : Resolution;
        attribute audioChannels : Integer;
        attribute refreshRate : Real;
    }

    item def NetworkPacket {
        attribute payload : Real;
        attribute timestamp : Real;
    }

    port def WiFiPort {
        attribute signalStrength : Real;
        attribute bandwidth : Real;
        in item receivedPackets : NetworkPacket[*];
        out item transmittedPackets : NetworkPacket[*];
    }

    port def HDMIOutputPort {
        attribute version : String;
        attribute maxResolution : Resolution;
        out item videoSignal : HDMISignal[*];
    }

    port def USBPowerPort {
        attribute voltage : Real;
        attribute current : Real;
        in item powerInput[1];
    }

    part def NetworkInterface {
        attribute :>> mass : MassValue;
        port wifiPort : WiFiPort {
            attribute :>> signalStrength = 0.85;
            attribute :>> bandwidth = 300.0;
        }

        action receiveCommand {
            in command : CastCommand;
            out validatedCommand : CastCommand;
        }

        action receiveMediaData {
            in packets : NetworkPacket[*];
            out streamData : MediaStream;
        }
    }

    part def MediaProcessor {
        attribute :>> mass : MassValue;
        attribute processingCapacity : Real;
        attribute bufferSize : Real;

        action bufferStream {
            in incomingStream : MediaStream;
            out bufferedStream : MediaStream;
        }

        action decodeMedia {
            in encodedStream : MediaStream;
            out decodedStream : MediaStream;
        }

        action transcodeQuality {
            in inputStream : MediaStream;
            in targetQuality : StreamQuality;
            out outputStream : MediaStream;
        }
    }

    part def VideoRenderer {
        attribute :>> mass : MassValue;
        port hdmiPort : HDMIOutputPort {
            attribute :>> version = "2.0";
        }

        action renderToHDMI {
            in mediaContent : MediaStream;
            out hdmiOutput : HDMISignal;
        }
    }

    part def PowerController {
        attribute :>> mass : MassValue;
        port usbPower : USBPowerPort {
            attribute :>> voltage = 5.0;
            attribute :>> current = 1.5;
        }
        attribute powerConsumption : PowerValue;

        action managePower {
            in requiredPower : Real;
            out suppliedPower : Real;
        }
    }

    part def ChromecastDevice {
        attribute :>> mass : MassValue;
        attribute deviceId : String;
        attribute firmwareVersion : String;
        attribute currentState : ConnectionState;

        part networkInterface : NetworkInterface {
            attribute :>> mass = 12.0 [g];
        }

        part mediaProcessor : MediaProcessor {
            attribute :>> mass = 20.0 [g];
            attribute :>> processingCapacity = 2.0;
            attribute :>> bufferSize = 512.0;
        }

        part videoRenderer : VideoRenderer {
            attribute :>> mass = 8.0 [g];
        }

        part powerController : PowerController {
            attribute :>> mass = 5.0 [g];
            attribute :>> powerConsumption = 5.5 [W];
        }

        assert constraint totalMassConstraint {
            mass == networkInterface.mass + mediaProcessor.mass + 
                    videoRenderer.mass + powerController.mass
        }

        assert constraint massLimit {
            mass <= 50.0 [g]
        }

        perform action castMedia[*] ordered references executeCast;
    }

    action def InitiateConnection {
        in deviceId : String;
        out connectionEstablished : Boolean;
    }

    action def AuthenticateDevice {
        in credentials : String;
        out authenticated : Boolean;
    }

    action def ReceiveCastRequest {
        in sourceDevice : String;
        out castCommand : CastCommand;
    }

    action def LoadMediaStream {
        in mediaUrl : String;
        out mediaStream : MediaStream;
    }

    action def ProcessAndBuffer {
        in rawStream : MediaStream;
        out processedStream : MediaStream;
    }

    action def RenderOutput {
        in mediaContent : MediaStream;
        out displaySignal : HDMISignal;
    }

    action def MonitorPlayback {
        out bufferLevel : Real;
        out playbackStatus : String;
    }

    action def HandleConnectionError;
    action def HandleAuthError;

    action def ExecuteCast {
        first start;
        
        then action receiveCast : ReceiveCastRequest {
            in sourceDevice : String;
            out command : CastCommand;
        }
        
        then action initConnection : InitiateConnection {
            in deviceId = receiveCast.command.targetDeviceId;
            out connected : Boolean;
        }
        
        then decide;
            if initConnection.connected then authenticate;
            if !initConnection.connected then handleConnectionError;
        
        action authenticate : AuthenticateDevice {
            in credentials : String;
            out authSuccess : Boolean;
        }
        
        then decide;
            if authenticate.authSuccess then loadMedia;
            if !authenticate.authSuccess then handleAuthError;
        
        action loadMedia : LoadMediaStream {
            in mediaUrl = receiveCast.command.mediaUrl;
            out stream : MediaStream;
        }
        
        then merge streamingLoop;
        
        then action processBuffer : ProcessAndBuffer {
            in rawStream = loadMedia.stream;
            out bufferedStream : MediaStream;
        }
        
        then action render : RenderOutput {
            in mediaContent = processBuffer.bufferedStream;
            out signal : HDMISignal;
        }
        
        then action monitor : MonitorPlayback {
            out bufferStatus : Real;
            out status : String;
        }
        
        then decide;
            if monitor.bufferStatus > 0.2 then streamingLoop;
            if monitor.bufferStatus <= 0.2 then rebuffer;
            if monitor.status == "complete" then endCast;
        
        action rebuffer : ProcessAndBuffer {
            in rawStream : MediaStream;
            out bufferedStream : MediaStream;
        }
        then streamingLoop;
        
        action handleConnectionError : HandleConnectionError;
        then endCast;
        
        action handleAuthError : HandleAuthError;
        then endCast;
        
        action endCast;
        then done;
    }

    state def ChromecastOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign currentState = ConnectionState::disconnected;
        }
        
        transition idle_to_discovering
            first idle
            accept castRequest : CastCommand
            then discovering;
        
        state discovering {
            entry assign currentState = ConnectionState::discovering;
        }
        
        transition discovering_to_authenticating
            first discovering
            if deviceFound
            then authenticating;
        
        state authenticating {
            entry assign currentState = ConnectionState::authenticating;
        }
        
        transition authenticating_to_connected
            first authenticating
            if authenticationSuccess
            then connected;
        
        transition authenticating_to_error
            first authenticating
            if authenticationFailure
            then error;
        
        state connected {
            entry assign currentState = ConnectionState::connected;
        }
        
        transition connected_to_streaming
            first connected
            accept startStream
            then streaming;
        
        state streaming {
            entry assign currentState = ConnectionState::streaming;
            
            state buffering;
            state playing;
            
            transition buffering_to_playing
                first buffering
                if bufferSufficient
                then playing;
            
            transition playing_to_buffering
                first playing
                if bufferInsufficient
                then buffering;
        }
        
        transition streaming_to_paused
            first streaming
            accept pauseCommand
            then paused;
        
        state paused {
            entry assign currentState = ConnectionState::paused;
        }
        
        transition paused_to_streaming
            first paused
            accept resumeCommand
            then streaming;
        
        transition streaming_to_idle
            first streaming
            accept stopCommand
            then idle;
        
        transition paused_to_idle
            first paused
            accept stopCommand
            then idle;
        
        transition any_to_error
            first idle, discovering, authenticating, connected, streaming, paused
            accept errorEvent
            then error;
        
        state error {
            entry assign currentState = ConnectionState::error;
        }
        
        transition error_to_idle
            first error
            accept resetCommand
            then idle;
    }

    part def Television {
        attribute :>> mass : MassValue;
        attribute screenSize : Real;
        port hdmiInput : HDMIOutputPort;
        
        action displayContent {
            in hdmiSignal : HDMISignal;
        }
    }

    part def WiFiRouter {
        attribute :>> mass : MassValue;
        attribute throughput : Real;
        port wifiAccess : WiFiPort;
        
        action routePackets {
            in packets : NetworkPacket[*];
            out routedPackets : NetworkPacket[*];
        }
    }

    part def MobileDevice {
        attribute :>> mass : MassValue;
        port wifiConnection : WiFiPort;
        
        action sendCastCommand {
            in mediaUrl : String;
            out command : CastCommand;
        }
    }

    part def PowerAdapter {
        attribute :>> mass : MassValue;
        attribute outputVoltage : Real;
        attribute outputCurrent : Real;
        port usbOutput : USBPowerPort;
    }

    part chromecastSystem {
        part chromecast : ChromecastDevice {
            attribute :>> mass = 45.0 [g];
            attribute :>> deviceId = "CHROMECAST-XYZ-001";
            attribute :>> firmwareVersion = "2.1.5";
            
            exhibit state operationalBehavior : ChromecastOperationalStates;
            perform action executeCast : ExecuteCast;
        }
        
        part tv : Television {
            attribute :>> mass = 8500.0 [g];
            attribute :>> screenSize = 55.0;
        }
        
        part router : WiFiRouter {
            attribute :>> mass = 350.0 [g];
            attribute :>> throughput = 867.0;
        }
        
        part phone : MobileDevice {
            attribute :>> mass = 180.0 [g];
        }
        
        part adapter : PowerAdapter {
            attribute :>> mass = 40.0 [g];
            attribute :>> outputVoltage = 5.0;
            attribute :>> outputCurrent = 1.5;
        }
        
        connection hdmiConnection {
            end chromecast.videoRenderer.hdmiPort;
            end tv.hdmiInput;
        }
        
        connection chromecastWiFi {
            end chromecast.networkInterface.wifiPort;
            end router.wifiAccess;
        }
        
        connection phoneWiFi {
            end phone.wifiConnection;
            end router.wifiAccess;
        }
        
        connection powerConnection {
            end adapter.usbOutput;
            end chromecast.powerController.usbPower;
        }
    }

    requirement <'REQ-CAST-100'> primaryStreamingFunction {
        doc /* The Chromecast system shall enable wireless streaming of media content
             * from mobile devices to television displays by receiving cast commands
             * over WiFi, processing media streams, and outputting high-quality video
             * and audio signals via HDMI connection.
             */
        subject system : ChromecastDevice;
        
        require wirelessReception;
        require mediaProcessingCapability;
        require hdmiOutputCapability;
        require powerManagement;
    }

    requirement <'REQ-CAST-101'> wirelessReception {
        doc /* The device shall receive cast commands and media streams wirelessly
             * via WiFi with minimum signal strength of 0.7 and bandwidth of 100 Mbps.
             */
        subject network :>> chromecastSystem.chromecast.networkInterface;
        
        assert constraint {
            network.wifiPort.signalStrength >= 0.7 and
            network.wifiPort.bandwidth >= 100.0
        }
    }

    requirement <'REQ-CAST-102'> mediaProcessingCapability {
        doc /* The device shall buffer and decode media streams with processing
             * capacity of at least 1.5 and buffer size of at least 256 units.
             */
        subject processor :>> chromecastSystem.chromecast.mediaProcessor;
        
        assert constraint {
            processor.processingCapacity >= 1.5 and
            processor.bufferSize >= 256.0
        }
    }

    requirement <'REQ-CAST-103'> hdmiOutputCapability {
        doc /* The device shall output video via HDMI supporting resolutions
             * up to 4K UHD (3840x2160) using HDMI version 2.0 or higher.
             */
        subject renderer :>> chromecastSystem.chromecast.videoRenderer;
        
        assert constraint {
            renderer.hdmiPort.version == "2.0"
        }
    }

    requirement <'REQ-CAST-104'> powerManagement {
        doc /* The device shall operate with power consumption not exceeding
             * 7.5 watts during active streaming operations.
             */
        subject power :>> chromecastSystem.chromecast.powerController;
        
        assert constraint {
            power.powerConsumption <= 7.5 [W]
        }
    }

    requirement <'REQ-CAST-105'> compactFormFactor {
        doc /* The total mass of the Chromecast device shall not exceed
             * 50 grams to maintain portability and ease of installation.
             */
        subject device :>> chromecastSystem.chromecast;
        
        assert constraint {
            device.mass <= 50.0 [g]
        }
    }

    satisfy primaryStreamingFunction by chromecastSystem.chromecast;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    private import ChromecastStreamingSystem::*;

    part chromecast : NetworkInterface {
        exhibit state sm : ChromecastOperationalStates;
    }

    action orchestrator {
        action authenticateProbe : AuthenticateDevice {
            in credentials = "";
        }
        first authenticateProbe;
    }
}
