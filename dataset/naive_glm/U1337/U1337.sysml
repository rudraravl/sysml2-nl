package CastStreamingSystem {
    import ISQ::*;
    import ScalarValues::*;

    package Definitions {
        unit def BitsPerSecond;
        unit def Decibel;
        unit def DecibelMilliwatt;
        unit def Pixel;

        value type Bitrate :> Real { unit BitsPerSecond; }
        value type VolumeLevel :> Real { unit Decibel; }
        value type SignalStrength :> Real { unit DecibelMilliwatt; }
        value type ResolutionDimension :> Integer { unit Pixel; }
        value type PowerConsumption :> Power;

        enum PlaybackCommandKind { play, pause, stop, seek, setVolume, load, disconnect }
        enum ConnectionState { disconnected, discovering, connecting, connected, sessionActive, error }
        enum MediaKind { video, audio, image }
        enum DisplayState { standby, active }
        enum RouterState { poweredOff, booting, operational }

        item def Media {
            attribute title : String;
            attribute kind : MediaKind;
            attribute url : String;
            attribute duration : Duration;
            attribute width : ResolutionDimension;
            attribute height : ResolutionDimension;
            attribute bitrate : Bitrate;
        }

        item def MediaStream {
            attribute source : Media;
            attribute currentBitrate : Bitrate;
            attribute codec : String;
            attribute position : Duration;
        }

        item def PlaybackCommand {
            attribute kind : PlaybackCommandKind;
            attribute target : Media;
            attribute position : Duration;
            attribute volume : VolumeLevel;
        }

        item def DiscoveryMessage {
            attribute deviceId : String;
            attribute deviceName : String;
            attribute capabilities : String;
            attribute address : String;
        }

        item def AudioVideoSignal {
            attribute format : String;
            attribute width : ResolutionDimension;
            attribute height : ResolutionDimension;
            attribute sampleRate : Frequency;
            attribute frameRate : Frequency;
        }

        item def NetworkPacket {
            attribute source : String;
            attribute destination : String;
            attribute payload : String;
            attribute size : Integer;
        }
    }

    package Interfaces {
        import Definitions::*;

        port def WiFiPort {
            out discovery : DiscoveryMessage;
            in command : PlaybackCommand;
            out stream : MediaStream;
            in packet : NetworkPacket;
            attribute ipAddress : String;
            attribute signal : SignalStrength;
        }

        port def HDMIPort {
            out avSignal : AudioVideoSignal;
            attribute portVersion : String = "2.1";
        }

        port def ControlPort {
            in command : PlaybackCommand;
        }

        port def PowerPort {
            attribute voltage : Real = 5.0;
            attribute current : Real = 1.0;
            attribute powered : Boolean = true;
        }
    }

    package Components {
        import Definitions::*;
        import Interfaces::*;

        part def SenderDevice {
            attribute deviceName : String;
            attribute batteryLevel : Real;
            attribute maxVolume : VolumeLevel = 100.0;

            port wifiPort : WiFiPort;
            port controlPort : ControlPort;

            part mediaLibrary {
                attribute items : Media[0..*];
            }

            part userInterface {
                attribute currentVolume : VolumeLevel = 50.0;
                attribute currentPosition : Duration;
            }

            part discoveryManager {
                attribute discoveredReceivers : DiscoveryMessage[0..*];

                action discoverReceivers {
                    out foundReceivers : DiscoveryMessage[0..*];
                }
            }

            part sessionManager {
                attribute sessionId : String;
                attribute state : ConnectionState = ConnectionState::disconnected;
                attribute activeMedia : Media;

                action establishSession {
                    in target : Media;
                    out sessionId : String;
                }

                action terminateSession;
            }

            action streamMedia {
                in media : Media;
                out stream : MediaStream;
            }

            state def SenderBehavior {
                entry; then idle;

                state idle;

                transition idle_to_discovering
                    first idle
                    then discovering
                    when controlPort.command@
                    if controlPort.command.kind == PlaybackCommandKind::load;

                state discovering {
                    entry action {
                        perform discoveryManager.discoverReceivers;
                    }
                }

                transition discovering_to_connecting
                    first discovering
                    then connecting
                    when wifiPort.discovery@;

                state connecting {
                    entry action {
                        perform sessionManager.establishSession;
                    }
                }

                transition connecting_to_sessionActive
                    first connecting
                    then sessionActive
                    when sessionManager.state == ConnectionState::connected;

                state sessionActive {
                    entry action {
                        send wifiPort.command;
                    }
                }

                transition sessionActive_to_streaming
                    first sessionActive
                    then streaming
                    when wifiPort.stream@;

                state streaming {
                    do action {
                        perform streamMedia;
                        send wifiPort.stream;
                    }
                }

                transition streaming_to_terminating
                    first streaming
                    then terminating
                    when controlPort.command@
                    if controlPort.command.kind == PlaybackCommandKind::disconnect;

                state terminating {
                    entry action {
                        perform sessionManager.terminateSession;
                    }
                }

                transition terminating_to_idle
                    first terminating
                    then idle;

                transition any_to_error
                    first *
                    then errorState
                    when sessionManager.state == ConnectionState::error;

                state errorState;

                transition error_to_idle
                    first errorState
                    then idle;
            }

            behavior : SenderBehavior;

            requirement def SenderRequirements {
                requirement senderDiscoveryReq {
                    doc /* The sender shall discover available receivers on the WiFi network. */
                }
                requirement senderControlReq {
                    doc /* The sender shall send playback commands to the receiver. */
                }
                requirement senderStreamingReq {
                    doc /* The sender shall stream media to the receiver over WiFi. */
                }
            }
        }

        part def ReceiverDevice {
            attribute deviceId : String;
            attribute deviceName : String;
            attribute powerConsumption : PowerConsumption;
            attribute supportedResolutions : ResolutionDimension[0..*];

            port wifiPort : WiFiPort;
            port hdmiPort : HDMIPort;
            port powerPort : PowerPort;

            part networkInterface {
                attribute ipAddress : String;
                attribute macAddress : String;
                attribute connected : Boolean = false;
            }

            part mediaDecoder {
                attribute supportedCodecs : String[0..*];
                attribute currentCodec : String;
                attribute decoding : Boolean = false;

                action decodeStream {
                    in stream : MediaStream;
                    out signal : AudioVideoSignal;
                }
            }

            part videoRenderer {
                attribute outputWidth : ResolutionDimension;
                attribute outputHeight : ResolutionDimension;
                attribute rendering : Boolean = false;
            }

            part audioRenderer {
                attribute sampleRate : Frequency;
                attribute channels : Integer = 2;
            }

            state def ReceiverBehavior {
                entry; then offline;

                state offline;

                transition offline_to_broadcasting
                    first offline
                    then broadcasting
                    when powerPort.powered;

                state broadcasting {
                    entry action {
                        send wifiPort.discovery;
                    }
                    do action {
                        send wifiPort.discovery;
                    }
                }

                transition broadcasting_to_connected
                    first broadcasting
                    then connected
                    when wifiPort.command@;

                state connected;

                transition connected_to_decoding
                    first connected
                    then decoding
                    when wifiPort.stream@;

                state decoding {
                    do action {
                        perform mediaDecoder.decodeStream;
                    }
                }

                transition decoding_to_rendering
                    first decoding
                    then rendering
                    when mediaDecoder.decoding;

                state rendering {
                    do action {
                        send hdmiPort.avSignal;
                    }
                }

                transition rendering_to_connected
                    first rendering
                    then connected
                    when wifiPort.command@
                    if wifiPort.command.kind == PlaybackCommandKind::stop;

                transition any_to_offline
                    first *
                    then offline
                    when !powerPort.powered;
            }

            behavior : ReceiverBehavior;

            requirement def ReceiverRequirements {
                requirement receiverBroadcastReq {
                    doc /* The receiver shall broadcast its presence on the network. */
                }
                requirement receiverDecodeReq {
                    doc /* The receiver shall decode incoming media streams. */
                }
                requirement receiverRenderReq {
                    doc /* The receiver shall render audio/video to the HDMI output. */
                }
                requirement receiverHDMIReq {
                    doc /* The receiver shall output audio/video via HDMI to the display. */
                }
            }
        }

        part def Display {
            attribute displayName : String;
            attribute screenSize : Real;
            attribute maxResolution : ResolutionDimension;

            port hdmiPort : HDMIPort;
            port powerPort : PowerPort;

            part screen {
                attribute width : ResolutionDimension;
                attribute height : ResolutionDimension;
                attribute backlight : Boolean = true;
            }

            part speakers {
                attribute maxVolume : VolumeLevel;
                attribute currentVolume : VolumeLevel = 50.0;
            }

            state def DisplayBehavior {
                entry; then standby;

                state standby;

                transition standby_to_active
                    first standby
                    then active
                    when hdmiPort.avSignal@;

                state active {
                    do action {
                        /* render audio/video signal from HDMI input */
                    }
                }

                transition active_to_standby
                    first active
                    then standby
                    when !powerPort.powered;
            }

            behavior : DisplayBehavior;

            requirement def DisplayRequirements {
                requirement displayInputReq {
                    doc /* The display shall receive AV signal via HDMI input. */
                }
                requirement displayRenderReq {
                    doc /* The display shall present audio and video content to the user. */
                }
            }
        }

        part def WiFiRouter {
            attribute ssid : String;
            attribute ipAddress : String;
            attribute bandwidth : Bitrate;
            attribute connectedDevices : Integer = 0;

            port wifiPort : WiFiPort;
            port powerPort : PowerPort;

            part routerCore {
                attribute firmwareVersion : String;
                attribute routingTable : String[0..*];
            }

            part antenna {
                attribute gain : Real;
                attribute frequency : Frequency;
            }

            state def RouterBehavior {
                entry; then poweredOff;

                state poweredOff;

                transition poweredOff_to_booting
                    first poweredOff
                    then booting
                    when powerPort.powered;

                state booting {
                    do action {
                        /* initialize firmware and routing table */
                    }
                }

                transition booting_to_operational
                    first booting
                    then operational;

                state operational {
                    do action {
                        /* route packets between connected devices */
                    }
                }

                transition operational_to_poweredOff
                    first operational
                    then poweredOff
                    when !powerPort.powered;
            }

            behavior : RouterBehavior;

            requirement def RouterRequirements {
                requirement routerRoutingReq {
                    doc /* The router shall route packets between sender and receiver. */
                }
                requirement routerConnectivityReq {
                    doc /* The router shall provide WiFi connectivity to all devices. */
                }
            }
        }
    }

    package System {
        import Definitions::*;
        import Interfaces::*;
        import Components::*;

        part def CastStreamingSystem {
            part sender : SenderDevice;
            part receiver : ReceiverDevice;
            part display : Display;
            part router : WiFiRouter;

            connection senderToRouter connect sender.wifiPort to router.wifiPort;
            connection routerToReceiver connect router.wifiPort to receiver.wifiPort;
            connection receiverToDisplay connect receiver.hdmiPort to display.hdmiPort;

            requirement systemDiscoveryReq {
                doc /* The system shall allow the sender to discover the receiver on the WiFi network. */
            }
            requirement systemStreamingReq {
                doc /* The system shall stream media from sender to receiver over WiFi. */
            }
            requirement systemRenderingReq {
                doc /* The system shall render media on the display via HDMI. */
            }
            requirement systemLatencyReq {
                attribute maxLatency : Duration = 0.5 [s];
                doc /* End-to-end latency shall not exceed maxLatency. */
            }
            requirement systemQualityReq {
                attribute minResolution : ResolutionDimension = 1920 [Pixel];
                doc /* The system shall support at least 1080p video resolution. */
            }
            requirement systemBroadcastReq {
                doc /* The receiver shall broadcast its presence on the local WiFi network. */
            }
            requirement systemSessionReq {
                doc /* The sender shall establish a casting session with a specific receiver for a specific piece of media. */
            }

            satisfy systemDiscoveryReq by sender.discoveryManager;
            satisfy systemStreamingReq by sender.sessionManager;
            satisfy systemRenderingReq by receiver.videoRenderer;
            satisfy systemBroadcastReq by receiver.networkInterface;
            satisfy systemSessionReq by sender.sessionManager;
        }
    }
}
