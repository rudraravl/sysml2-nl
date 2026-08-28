package MediaStreamingEcosystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQElectromagnetism::*;

    attribute def Resolution {
        attribute width : Integer;
        attribute height : Integer;
    }
    attribute def PowerConsumption {
        attribute voltage : ElectricPotentialUnit;
        attribute current : ElectricCurrentUnit;
    }
    attribute def Frequency {
        attribute value : Real;
    }
    attribute def DataRate {
        attribute value : Real;
    }
    attribute def BufferSize {
        attribute value : Integer;
    }

    item def CastCommand {
        attribute mediaUrl : String;
        attribute requestedQuality : String;
    }
    item def MediaContent {
        attribute streamUrl : String;
        attribute quality : String;
        attribute dataRate : DataRate;
    }
    item def VideoSignal {
        attribute resolution : Resolution;
        attribute frameRate : Frequency;
    }
    item def AudioSignal;
    item def PowerSupply {
        attribute voltage : ElectricPotentialUnit;
        attribute current : ElectricCurrentUnit;
    }
    item def WiFiData;
    item def NetworkCredential {
        attribute ssid : String;
        attribute passphrase : String;
    }

    port def HDMIOutput {
        out item videoOut : VideoSignal;
        out item audioOut : AudioSignal;
    }
    port def HDMIInput {
        in item videoIn : VideoSignal;
        in item audioIn : AudioSignal;
    }
    port def USBPowerPort {
        in item powerIn : PowerSupply;
    }
    port def USBPowerSourcePort {
        out item powerOut : PowerSupply;
    }
    port def WiFiPort {
        in item incomingData : WiFiData;
        out item outgoingData : WiFiData;
    }
    port def CastCommandPort {
        in item castCommand : CastCommand;
    }
    port def CastSenderPort {
        out item castCommand : CastCommand;
    }
    port def MediaStreamPort {
        in item mediaIn : MediaContent;
    }
    port def MediaSourcePort {
        out item mediaOut : MediaContent;
    }
    port def VideoRenderPort {
        in item videoIn : VideoSignal;
    }
    port def ProcessedVideoPort {
        out item videoOut : VideoSignal;
    }
    port def RawMediaPort {
        in item rawMediaIn : MediaContent;
    }
    port def DecodedMediaPort {
        out item decodedVideo : VideoSignal;
        out item decodedAudio : AudioSignal;
    }
    port def CredentialPort {
        in item credential : NetworkCredential;
    }

    part def PowerAdapter {
        out port usbPower : USBPowerSourcePort;
        attribute outputVoltage : ElectricPotentialUnit;
        attribute outputCurrent : ElectricCurrentUnit;
    }

    part def Television {
        in port hdmiInput : HDMIInput;
        attribute maxResolution : Resolution;
    }

    part def WiFiRouter {
        port wifi : WiFiPort;
        attribute operatingFrequency : Frequency;
    }

    part def MobilePhone {
        out port castSender : CastSenderPort;
        port wifi : WiFiPort;
        action def SendCastCommand {
            out item command : CastCommand;
        }
    }

    part def NetworkInterface {
        port wifi : WiFiPort;
        out port mediaStream : MediaSourcePort;
        in port credentials : CredentialPort;
        attribute supportedFrequencies : Frequency[2];
        attribute maxDataRate : DataRate;

        action def ReceiveCastCommand {
            in item data : WiFiData;
            out item command : CastCommand;
        }
        action def FetchMediaStream {
            in item command : CastCommand;
            out item media : MediaContent;
        }
    }

    part def MediaProcessor {
        in port rawMedia : RawMediaPort;
        out port decodedMedia : DecodedMediaPort;
        attribute bufferCapacity : BufferSize;
        attribute currentBufferLevel : BufferSize;
        attribute supportedCodecs : String[*];

        action def BufferMedia {
            in item media : MediaContent;
            out item bufferedMedia : MediaContent;
        }
        action def DecodeMedia {
            in item media : MediaContent;
            out item video : VideoSignal;
            out item audio : AudioSignal;
        }
        action def AdjustQuality {
            in item media : MediaContent;
            in networkCondition : String;
            out item adjustedMedia : MediaContent;
        }
    }

    part def VideoRenderer {
        in port decodedVideo : VideoRenderPort;
        out port hdmiOutput : HDMIOutput;
        attribute maxResolution : Resolution;
        attribute supportedColorDepth : Integer;

        action def RenderVideo {
            in item video : VideoSignal;
            out item renderedVideo : VideoSignal;
        }
    }

    part def PowerController {
        in port usbPower : USBPowerPort;
        attribute powerConsumption : PowerConsumption;
        attribute inputVoltage : ElectricPotentialUnit;

        action def RegulatePower {
            in item supply : PowerSupply;
            out item regulatedSupply : PowerSupply;
        }
    }

    state def ChromecastStates {
        entry; then idle;

        state idle;
        transition idle_to_discovering
            first idle
            accept CastCommand
            then discovering;

        state discovering;
        transition discovering_to_authenticating
            first discovering
            accept NetworkCredential
            then authenticating;

        state authenticating;
        transition authenticating_to_connecting
            first authenticating
            accept WiFiData
            then connecting;
        transition authenticating_to_error
            first authenticating
            accept WiFiData
            then error;

        state connecting;
        transition connecting_to_ready
            first connecting
            accept MediaContent
            then ready;
        transition connecting_to_error
            first connecting
            accept WiFiData
            then error;

        state ready;
        transition ready_to_playing
            first ready
            accept MediaContent
            then playing;

        state playing;
        transition playing_to_buffering
            first playing
            accept WiFiData
            then buffering;
        transition playing_to_paused
            first playing
            accept CastCommand
            then paused;

        state buffering;
        transition buffering_to_playing
            first buffering
            accept MediaContent
            then playing;

        state paused;
        transition paused_to_playing
            first paused
            accept CastCommand
            then playing;
        transition paused_to_idle
            first paused
            accept CastCommand
            then idle;

        state error;
        transition error_to_idle
            first error
            accept CastCommand
            then idle;
    }

    part def ChromecastDevice {
        out port hdmiOut : HDMIOutput;
        in port usbPowerIn : USBPowerPort;
        port wifi : WiFiPort;
        in port castReceiver : CastCommandPort;

        attribute weight : Real;
        attribute isPortable : Boolean;

        part networkInterface : NetworkInterface;
        part mediaProcessor : MediaProcessor;
        part videoRenderer : VideoRenderer;
        part powerController : PowerController;

        connection def MediaFlow {
            end port source : MediaSourcePort;
            end port target : RawMediaPort;
            item mediaContent : MediaContent;
        }
        connection def DecodedVideoFlow {
            end port source : DecodedMediaPort;
            end port target : VideoRenderPort;
            item videoSignal : VideoSignal;
        }
        connection def PowerFlow {
            end port source : USBPowerPort;
            end port target : USBPowerPort;
            item supply : PowerSupply;
        }

        connection mediaConnection : MediaFlow connect networkInterface.mediaStream to mediaProcessor.rawMedia;
        connection decodedVideoConnection : DecodedVideoFlow connect mediaProcessor.decodedMedia to videoRenderer.decodedVideo;
        connection powerConnection : PowerFlow connect usbPowerIn to powerController.usbPower;

        state chromecastStates : ChromecastStates;
        exhibit chromecastStates;
    }

    part def StreamingSystem {
        part chromecast : ChromecastDevice;
        part tv : Television;
        part powerAdapter : PowerAdapter;
        part wifiRouter : WiFiRouter;
        part phone : MobilePhone;

        connection def HDMIConnection {
            end port source : HDMIOutput;
            end port target : HDMIInput;
            item video : VideoSignal;
            item audio : AudioSignal;
        }
        connection def WiFiLink {
            end port end1 : WiFiPort;
            end port end2 : WiFiPort;
            item data : WiFiData;
        }
        connection def USBPowerLink {
            end port source : USBPowerSourcePort;
            end port target : USBPowerPort;
            item supply : PowerSupply;
        }
        connection def CastCommandLink {
            end port source : CastSenderPort;
            end port target : CastCommandPort;
            item command : CastCommand;
        }

        connection hdmiLink : HDMIConnection connect chromecast.hdmiOut to tv.hdmiInput;
        connection powerLink : USBPowerLink connect powerAdapter.usbPower to chromecast.usbPowerIn;
        connection routerToChromecast : WiFiLink connect wifiRouter.wifi to chromecast.wifi;
        connection routerToPhone : WiFiLink connect wifiRouter.wifi to phone.wifi;
        connection castLink : CastCommandLink connect phone.castSender to chromecast.castReceiver;
    }

    requirement def StreamingCapability {
        doc /** The Chromecast device shall stream media content from a mobile phone to a television via WiFi. */
    }
    requirement def VideoOutputRequirement {
        doc /** The Chromecast device shall output video at up to 4K UHD resolution (3840x2160) through its HDMI port. */
    }
    requirement def PowerEfficiencyRequirement {
        doc /** The Chromecast device shall operate with power consumption not exceeding 3.0 watts. */
    }
    requirement def ErrorHandlingRequirement {
        doc /** The Chromecast device shall gracefully handle connection and authentication errors and return to an idle state. */
    }
    requirement def BufferingRequirement {
        doc /** The Chromecast device shall buffer media content to prevent playback stuttering during network fluctuations. */
    }

    requirement streamingReq : StreamingCapability;
    requirement videoReq : VideoOutputRequirement;
    requirement powerReq : PowerEfficiencyRequirement;
    requirement errorReq : ErrorHandlingRequirement;
    requirement bufferReq : BufferingRequirement;

    part streamingSystem : StreamingSystem {
        satisfy streamingReq by chromecast;
        satisfy videoReq by chromecast;
        satisfy powerReq by chromecast;
        satisfy errorReq by chromecast;
        satisfy bufferReq by chromecast;
    }
}
