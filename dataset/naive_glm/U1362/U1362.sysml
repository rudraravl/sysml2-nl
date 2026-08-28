package MultiRoomAudioSystem {

    import ScalarValues::*;
    import ISQ::*;
    import ISQTime::*;
    import ISQVolume::*;

    // ---------- Value Types ----------
    value def Latency :> RealValue { unit 'ms'; }
    value def VolumeLevel :> RealValue { unit 'percent'; }
    value def BitRate :> RealValue { unit 'kbps'; }
    value def SampleRate :> RealValue { unit 'kHz'; }
    value def Frequency :> RealValue { unit 'Hz'; }
    value def Power :> RealValue { unit 'W'; }

    attribute def RoomName :> String;
    attribute def GroupId :> String;
    attribute def TrackId :> String;

    // ---------- Items ----------
    item def AudioStream {
        attribute sampleRate : SampleRate;
        attribute bitRate : BitRate;
        attribute codec : String;
        attribute trackId : TrackId;
    }

    item def ControlCommand {
        attribute command : String; // play, pause, stop, resume, volume, group, ungroup
        attribute targetRoom : RoomName;
        attribute volume : VolumeLevel;
        attribute groupId : GroupId;
    }

    item def SyncPacket {
        attribute timestamp : TimeValue;
        attribute sequence : Integer;
        attribute groupId : GroupId;
        attribute offset : Latency;
    }

    item def StatusReport {
        attribute room : RoomName;
        attribute state : String;
        attribute volume : VolumeLevel;
        attribute groupId : GroupId;
    }

    // ---------- Interfaces ----------
    interface def WiFiLink {
        end wifiClient;
        end wifiAp;
        item controlCommands : ControlCommand[*];
        item audio : AudioStream[*];
        item status : StatusReport[*];
    }

    interface def MeshLink {
        end meshA;
        end meshB;
        item sync : SyncPacket[*];
    }

    port def WiFiPort {
        in controlCommands : ControlCommand[*];
        out status : StatusReport[*];
        inout audio : AudioStream[*];
    }

    port def MeshPort {
        inout sync : SyncPacket[*];
    }

    // ---------- Requirements ----------
    requirement def SyncLatencyRequirement {
        doc { The audio playback latency between grouped speakers shall be less than 2 milliseconds. }
        attribute maxLatency : Latency = 2.0;
        subject speakerGroup;
        predicate { speakerGroup.latency < maxLatency }
    }

    requirement def MultiRoomPlaybackRequirement {
        doc { The system shall support synchronized playback across multiple grouped speakers. }
        subject system;
        predicate { system.groupedSpeakers > 1 implies system.synchronized }
    }

    requirement def CommandResponseRequirement {
        doc { Each speaker shall respond to controller commands within 500 milliseconds. }
        attribute maxResponse : TimeValue = 500 [ms];
        subject speaker;
        predicate { speaker.responseTime < maxResponse }
    }

    // ---------- Part Definitions ----------
    part def WiFiModule {
        port wifiPort : WiFiPort;
        attribute ssid : String;
        attribute connected : Boolean;
        perform action transmit {
            in command : ControlCommand;
            out ack : StatusReport;
        }
    }

    part def MeshModule {
        port meshPort : MeshPort;
        attribute meshId : String;
        attribute peers : String[*];
        perform action relaySync {
            in syncIn : SyncPacket;
            out syncOut : SyncPacket;
        }
    }

    part def AudioProcessor {
        in stream : AudioStream;
        out decoded : AudioStream;
        perform action decode {
            in encoded : AudioStream;
            out pcm : AudioStream;
        }
        perform action buffer {
            in pcm : AudioStream;
            out buffered : AudioStream;
        }
    }

    part def Amplifier {
        attribute power : Power = 50 [W];
        in audioIn : AudioStream;
        out audioOut : AudioStream;
        perform action amplify {
            in signal : AudioStream;
            out amplified : AudioStream;
        }
    }

    part def SpeakerDriver {
        attribute frequencyRange : Frequency;
        in audioIn : AudioStream;
        perform action emit {
            in signal : AudioStream;
        }
    }

    part def SonosSpeaker {
        attribute room : RoomName;
        attribute volume : VolumeLevel = 50;
        attribute groupId : GroupId;
        attribute latency : Latency;

        part wifi : WiFiModule;
        part mesh : MeshModule;
        part processor : AudioProcessor;
        part amplifier : Amplifier;
        part driver : SpeakerDriver;

        port wifiPort : WiFiPort;
        port meshPort : MeshPort;

        // Internal connections
        connection wifiToProcessor connect wifi.wifiPort.audio to processor.stream;
        connection processorToAmp connect processor.decoded to amplifier.audioIn;
        connection ampToDriver connect amplifier.audioOut to driver.audioIn;

        // State machine
        state def SpeakerLifecycle {
            entry; then idle;

            state idle;
            transition idle_to_ready
                first idle
                accept ControlCommand
                then ready;

            state ready;
            transition ready_to_buffering
                first ready
                accept ControlCommand[command == "play"]
                then buffering;

            state buffering {
                entry action loadBuffer {
                    in stream : AudioStream;
                }
            }
            transition buffering_to_playing
                first buffering
                accept AudioStream
                then playing;

            state playing {
                do action emitAudio {
                    in audio : AudioStream;
                }
            }
            transition playing_to_paused
                first playing
                accept ControlCommand[command == "pause"]
                then paused;
            transition playing_to_stopped
                first playing
                accept ControlCommand[command == "stop"]
                then stopped;

            state paused;
            transition paused_to_playing
                first paused
                accept ControlCommand[command == "resume"]
                then playing;
            transition paused_to_stopped
                first paused
                accept ControlCommand[command == "stop"]
                then stopped;

            state stopped;
            transition stopped_to_ready
                first stopped
                accept ControlCommand
                then ready;
        }

        exhibit state behavior : SpeakerLifecycle;

        satisfy SyncLatencyRequirement by latency;
    }

    part def SonosController {
        port wifiPort : WiFiPort;
        attribute connectedSpeakers : RoomName[*];
        attribute activeGroups : GroupId[*];

        perform action issueCommand {
            out command : ControlCommand;
        }
        perform action groupRooms {
            in rooms : RoomName[*];
            out groupId : GroupId;
        }
        perform action ungroupRooms {
            in groupId : GroupId;
        }
        perform action adjustVolume {
            in room : RoomName;
            in volume : VolumeLevel;
            out command : ControlCommand;
        }
    }

    part def MusicSource {
        attribute name : String;
        attribute type : String; // streaming or local
        port wifiPort : WiFiPort;
        perform action streamAudio {
            out stream : AudioStream;
        }
    }

    part def StreamingService :> MusicSource {
        attribute serviceName : String;
        attribute url : String;
    }

    part def LocalLibrary :> MusicSource {
        attribute host : String;
        attribute trackCount : Integer;
    }

    part def HomeWiFiNetwork {
        port apPort : WiFiPort;
        attribute ssid : String;
        attribute channel : Integer;
    }

    part def SpeakerMesh {
        port meshPort : MeshPort;
        attribute meshId : String;
        attribute members : String[*];
    }

    // ---------- System ----------
    part def MultiRoomAudioSystem {
        part controller : SonosController;
        part speakers : SonosSpeaker[*];
        part sources : MusicSource[*];
        part homeWiFi : HomeWiFiNetwork;
        part mesh : SpeakerMesh;

        // WiFi connections
        connection controllerToWiFi connect controller.wifiPort to homeWiFi.apPort;
        connection sourceToWiFi connect sources.wifiPort to homeWiFi.apPort;
        connection speakersToWiFi connect speakers.wifiPort to homeWiFi.apPort;

        // Mesh connections between speakers
        connection meshLinks connect speakers.meshPort to speakers.meshPort;

        satisfy MultiRoomPlaybackRequirement;
        satisfy CommandResponseRequirement by speakers;
    }

    // ---------- Instantiation ----------
    part livingRoomSpeaker : SonosSpeaker {
        attribute room = "Living Room";
        attribute volume = 60;
    }
    part kitchenSpeaker : SonosSpeaker {
        attribute room = "Kitchen";
        attribute volume = 45;
    }
    part bedroomSpeaker : SonosSpeaker {
        attribute room = "Bedroom";
        attribute volume = 30;
    }

    part spotifySource : StreamingService {
        attribute serviceName = "Spotify";
        attribute type = "streaming";
    }
    part localMusic : LocalLibrary {
        attribute name = "Home Library";
        attribute type = "local";
        attribute trackCount = 5000;
    }

    part systemInstance : MultiRoomAudioSystem {
        part controller;
        part speakers = (livingRoomSpeaker, kitchenSpeaker, bedroomSpeaker);
        part sources = (spotifySource, localMusic);
        part homeWiFi {
            attribute ssid = "HomeNet";
            attribute channel = 6;
        }
        part mesh {
            attribute meshId = "SonosMesh-01";
        }
    }
}
