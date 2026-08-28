package SonosMultiRoomAudioSystem {
    private import ScalarValues::*;
    private import ISQSpaceTime::TimeUnit;

    attribute def VolumeLevel :> Real;

    enum def CommandKind {
        connectSpeaker; play; pause; stop; resume; group; ungroup; volume;
    }

    item def Command {
        attribute kind: CommandKind;
        attribute targetRoom: String;
        attribute volume: VolumeLevel;
    }

    item def AudioStream;

    item def SyncData {
        attribute latency: Real;
    }

    port def HomeWiFiPort {
        in item command: Command;
        in item stream: AudioStream;
    }

    port def MeshPort {
        in item syncIn: SyncData;
        out item syncOut: SyncData;
    }

    port def AudioOutPort {
        out item audio: AudioStream;
    }

    port def AudioInPort {
        in item audio: AudioStream;
    }

    port def SpeakerPort {
        in item audio: AudioStream;
    }

    part def WiFiModule {
        port homeWiFi: HomeWiFiPort;
        port mesh: MeshPort;
        port audioOut: AudioOutPort;
    }

    part def AudioProcessor {
        port audioIn: AudioInPort;
        port audioOut: AudioOutPort;
    }

    part def Amplifier {
        port audioIn: AudioInPort;
        port audioOut: AudioOutPort;
        attribute gain: VolumeLevel;
    }

    part def SpeakerDrivers {
        port speakerIn: SpeakerPort;
    }

    part def SonosSpeaker {
        attribute roomName: String;
        attribute volume: VolumeLevel;

        part wifi: WiFiModule;
        part processor: AudioProcessor;
        part amp: Amplifier;
        part drivers: SpeakerDrivers;

        port homeWiFi: HomeWiFiPort;
        port mesh: MeshPort;

        connect homeWiFi to wifi.homeWiFi;
        connect mesh to wifi.mesh;
        connect wifi.audioOut to processor.audioIn;
        connect processor.audioOut to amp.audioIn;
        connect amp.audioOut to drivers.speakerIn;

        exhibit state SpeakerStateMachine {
            entry; then idle;
            state idle;
            transition idle_to_ready
                first idle
                accept cmd: Command via homeWiFi
                if cmd.kind == CommandKind::connectSpeaker
                then ready;
            state ready;
            transition ready_to_buffering
                first ready
                accept cmd: Command via homeWiFi
                if cmd.kind == CommandKind::play
                then buffering;
            state buffering;
            transition buffering_to_playing
                first buffering
                then playing;
            state playing;
            transition playing_to_paused
                first playing
                accept cmd: Command via homeWiFi
                if cmd.kind == CommandKind::pause
                then paused;
            transition playing_to_stopped
                first playing
                accept cmd: Command via homeWiFi
                if cmd.kind == CommandKind::stop
                then stopped;
            state paused;
            transition paused_to_playing
                first paused
                accept cmd: Command via homeWiFi
                if cmd.kind == CommandKind::resume
                then playing;
            transition paused_to_stopped
                first paused
                accept cmd: Command via homeWiFi
                if cmd.kind == CommandKind::stop
                then stopped;
            state stopped;
            transition stopped_to_idle
                first stopped
                then idle;
        }
    }

    part def SonosController {
        port homeWiFi: ~HomeWiFiPort;
        perform action control {
            action sendPlay {
                send new Command(CommandKind::play, "Living Room", 0.5) via homeWiFi;
            }
            action sendPause {
                send new Command(CommandKind::pause, "Living Room", 0.0) via homeWiFi;
            }
            action sendStop {
                send new Command(CommandKind::stop, "Living Room", 0.0) via homeWiFi;
            }
            action sendResume {
                send new Command(CommandKind::resume, "Living Room", 0.0) via homeWiFi;
            }
            action sendGroup {
                send new Command(CommandKind::group, "Living Room", 0.0) via homeWiFi;
            }
            action sendUngroup {
                send new Command(CommandKind::ungroup, "Living Room", 0.0) via homeWiFi;
            }
        }
    }

    part def MusicSource {
        port homeWiFi: ~HomeWiFiPort;
        perform action stream {
            action sendAudio {
                send new AudioStream() via homeWiFi;
            }
        }
    }

    part def StreamingService :> MusicSource;
    part def LocalLibrary :> MusicSource;

    part def HomeWiFiNetwork {
        port controllerPort: HomeWiFiPort;
        port sourcePort1: HomeWiFiPort;
        port sourcePort2: HomeWiFiPort;
        port speakerPort1: HomeWiFiPort;
        port speakerPort2: HomeWiFiPort;
    }

    part def MeshNetwork {
        port speakerPort1: MeshPort;
        port speakerPort2: MeshPort;
    }

    requirement def SyncLatencyRequirement {
        doc /* The mesh network must deliver sync packets with latency less than 2 milliseconds. */
        attribute maxLatency : Real = 2.0;
        subject syncData : SyncData;
        constraint { syncData.latency < maxLatency }
    }

    part system {
        part livingRoomSpeaker: SonosSpeaker {
            attribute :>> roomName = "Living Room";
        }
        part kitchenSpeaker: SonosSpeaker {
            attribute :>> roomName = "Kitchen";
        }
        part controller: SonosController;
        part streamingSource: StreamingService;
        part localSource: LocalLibrary;
        part wifiNetwork: HomeWiFiNetwork;
        part meshNetwork: MeshNetwork;

        connect controller.homeWiFi to wifiNetwork.controllerPort;
        connect streamingSource.homeWiFi to wifiNetwork.sourcePort1;
        connect localSource.homeWiFi to wifiNetwork.sourcePort2;
        connect livingRoomSpeaker.homeWiFi to wifiNetwork.speakerPort1;
        connect kitchenSpeaker.homeWiFi to wifiNetwork.speakerPort2;

        connect livingRoomSpeaker.mesh to meshNetwork.speakerPort1;
        connect kitchenSpeaker.mesh to meshNetwork.speakerPort2;

        requirement syncReq : SyncLatencyRequirement;
    }
}
