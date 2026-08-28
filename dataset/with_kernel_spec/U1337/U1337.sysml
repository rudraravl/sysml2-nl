package WirelessMediaStreamingSystem {
    private import ScalarValues::*;

    attribute def DataRate :> Real {
        attribute unit : String = "Mbit/s";
    }
    attribute def FrameRate :> Real {
        attribute unit : String = "Hz";
    }
    attribute def VolumeLevel :> Real {
        attribute min : Real = 0.0;
        attribute max : Real = 100.0;
    }

    item def MediaItem {
        attribute id : String;
        attribute title : String;
        attribute url : String;
    }

    item def MediaStream {
        attribute mediaId : String;
        attribute dataRate : DataRate;
    }

    item def AudioVideoSignal {
        attribute resolution : String;
        attribute frameRate : FrameRate;
    }

    item def Command {
        attribute commandType : String;
        attribute mediaId : String;
    }

    item def DiscoveryMessage {
        attribute deviceName : String;
        attribute deviceType : String;
    }

    item def StatusUpdate {
        attribute status : String;
    }

    item def UserInput {
        attribute actionType : String;
        attribute mediaId : String;
    }

    item def PowerEvent {
        attribute powerState : String;
    }

    port def WiFiPort {
        in ref discovery : DiscoveryMessage;
        out ref discoveryResponse : DiscoveryMessage;
        in ref command : Command;
        out ref status : StatusUpdate;
        in ref mediaStream : MediaStream;
    }

    port def HDMIPort {
        in ref audioVideo : AudioVideoSignal;
    }

    interface def WiFiInterface {
        end source : ~WiFiPort;
        end target : WiFiPort;
    }

    interface def HDMIInterface {
        end source : ~HDMIPort;
        end target : HDMIPort;
    }

    part def SenderDevice {
        attribute deviceName : String;
        attribute mediaLibrary : MediaItem[0..*];
        port wifiPort : ~WiFiPort;

        exhibit state SenderBehavior {
            entry; then idle;
            state idle;
            state discovering;
            state casting;

            transition discoverInit
                first idle
                accept ui : UserInput
                if ui.actionType == "DISCOVER"
                then discovering;

            transition discoverSend
                first discovering
                do send new DiscoveryMessage(deviceName, "Sender") via wifiPort.discovery
                then discovering;

            transition discoverRecv
                first discovering
                accept resp : DiscoveryMessage via wifiPort.discoveryResponse
                then idle;

            transition startCast
                first idle
                accept ui : UserInput
                if ui.actionType == "PLAY"
                do send new Command("PLAY", ui.mediaId) via wifiPort.command
                then casting;

            transition streamMedia
                first casting
                do send new MediaStream("media1", 15.0) via wifiPort.mediaStream
                then casting;

            transition stopCast
                first casting
                accept ui : UserInput
                if ui.actionType == "STOP"
                do send new Command("STOP", "") via wifiPort.command
                then idle;
        }
    }

    part def ReceiverDevice {
        attribute deviceName : String;
        attribute deviceType : String = "Chromecast";
        port wifiPort : WiFiPort;
        port hdmiPort : ~HDMIPort;

        exhibit state ReceiverBehavior {
            entry; then waiting;
            state waiting;
            state receiving;
            state decoding;

            transition broadcast
                first waiting
                accept disc : DiscoveryMessage via wifiPort.discovery
                do send new DiscoveryMessage(deviceName, deviceType) via wifiPort.discoveryResponse
                then waiting;

            transition recvCmd
                first waiting
                accept cmd : Command via wifiPort.command
                if cmd.commandType == "PLAY"
                then receiving;

            transition recvStream
                first receiving
                accept mediaStream : MediaStream via wifiPort.mediaStream
                then decoding;

            transition decodeRender
                first decoding
                do send new AudioVideoSignal("1080p", 60.0) via hdmiPort.audioVideo
                then receiving;

            transition stop
                first receiving
                accept cmd : Command via wifiPort.command
                if cmd.commandType == "STOP"
                then waiting;
        }
    }

    part def Display {
        attribute displaySize : Real;
        attribute displayUnit : String = "inch";
        port hdmiPort : HDMIPort;

        exhibit state DisplayBehavior {
            entry; then poweredOff;
            state poweredOff;
            state poweredOn;

            transition powerOn
                first poweredOff
                accept powerEvt : PowerEvent
                if powerEvt.powerState == "ON"
                then poweredOn;

            transition render
                first poweredOn
                accept av : AudioVideoSignal via hdmiPort.audioVideo
                then poweredOn;
        }
    }

    part def WiFiRouter {
        attribute networkSSID : String;
        attribute frequencyValue : Real;
        attribute frequencyUnit : String = "GHz";
        port senderPort : WiFiPort;
        port receiverPort : ~WiFiPort;

        flow discoveryFlow from senderPort.discovery to receiverPort.discovery;
        flow responseFlow from receiverPort.discoveryResponse to senderPort.discoveryResponse;
        flow commandFlow from senderPort.command to receiverPort.command;
        flow statusFlow from receiverPort.status to senderPort.status;
        flow streamFlow from senderPort.mediaStream to receiverPort.mediaStream;
    }

    part castSystem {
        part sender : SenderDevice {
            attribute :>> deviceName = "Smartphone";
        }
        part receiver : ReceiverDevice {
            attribute :>> deviceName = "Living Room Chromecast";
        }
        part display : Display {
            attribute :>> displaySize = 55;
        }
        part router : WiFiRouter {
            attribute :>> networkSSID = "HomeNetwork";
            attribute :>> frequencyValue = 5.0;
        }

        interface sender_router : WiFiInterface connect sender.wifiPort to router.senderPort {
            flow discoveryFlow from sender_router.source.discovery to sender_router.target.discovery;
            flow responseFlow from sender_router.target.discoveryResponse to sender_router.source.discoveryResponse;
            flow commandFlow from sender_router.source.command to sender_router.target.command;
            flow statusFlow from sender_router.target.status to sender_router.source.status;
            flow streamFlow from sender_router.source.mediaStream to sender_router.target.mediaStream;
        }

        interface receiver_router : WiFiInterface connect router.receiverPort to receiver.wifiPort {
            flow discoveryFlow from receiver_router.source.discovery to receiver_router.target.discovery;
            flow responseFlow from receiver_router.target.discoveryResponse to receiver_router.source.discoveryResponse;
            flow commandFlow from receiver_router.source.command to receiver_router.target.command;
            flow statusFlow from receiver_router.target.status to receiver_router.source.status;
            flow streamFlow from receiver_router.source.mediaStream to receiver_router.target.mediaStream;
        }

        interface receiver_display : HDMIInterface connect receiver.hdmiPort to display.hdmiPort {
            flow avFlow from receiver_display.source.audioVideo to receiver_display.target.audioVideo;
        }
    }

    requirement def CastStreamingRequirement {
        doc /* The system shall stream media from a sender to a display via a receiver over WiFi. */
        subject sys : castSystem;
    }

    requirement castStreamingRequirement : CastStreamingRequirement {
        subject :>> sys = castSystem;
    }

    requirement def DiscoveryRequirement {
        doc /* The Receiver Device shall broadcast its presence on the WiFi network. */
        subject receiver : ReceiverDevice;
    }

    requirement discoveryRequirement : DiscoveryRequirement {
        subject :>> receiver = castSystem.receiver;
    }

    requirement def PlaybackControlRequirement {
        doc /* The Sender Device shall control playback on the Receiver Device. */
        subject sender : SenderDevice;
    }

    requirement playbackControlRequirement : PlaybackControlRequirement {
        subject :>> sender = castSystem.sender;
    }
}
