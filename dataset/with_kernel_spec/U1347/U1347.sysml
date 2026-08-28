package KodiMediaCenter {
    private import ScalarValues::*;

    value type Duration :> Real;

    item def MediaFile {
        attribute filePath : String;
        attribute sourceType : String;
    }

    item def MediaMetadata {
        attribute title : String;
        attribute duration : Duration;
        attribute coverArtUrl : String;
        attribute genre : String;
    }

    item def VideoStream {
        attribute codec : String;
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : Real;
    }

    item def AudioStream {
        attribute codec : String;
        attribute channels : Integer;
        attribute sampleRate : Integer;
    }

    item def PlaybackCommand {
        attribute command : String;
        attribute seekPosition : Duration;
        attribute mediaUrl : String;
    }

    item def LibraryQuery {
        attribute queryString : String;
        attribute filterGenre : String;
    }

    item def LibraryResult {
        attribute entries : MediaMetadata[*];
    }

    port def MediaDataPort;
    port def CommandPort;
    port def LibraryQueryPort;
    port def VideoOutputPort;
    port def AudioOutputPort;
    port def UserInputPort;

    requirement def MediaDiscoveryRequirement {
        text = "The system shall scan specified locations and index media files with metadata.";
    }

    requirement def PlaybackControlRequirement {
        text = "The system shall manage playback with play, pause, stop, and seek commands.";
    }

    requirement def MediaDecodingRequirement {
        text = "The system shall decode media into video and audio streams.";
    }

    requirement def NetworkStreamingRequirement {
        text = "The system shall stream content from internet sources with buffering.";
    }

    requirement def UserInterfaceRequirement {
        text = "The system shall provide a user interface for browsing and controlling playback.";
    }

    part def MediaLibrary {
        port queryPort : LibraryQueryPort;
        port mediaOutPort : ~MediaDataPort;
        attribute catalog : MediaMetadata[*];

        exhibit state libraryBehavior {
            entry; then scanning;
            state scanning;
            transition finishScan
                first scanning
                then idle;
            state idle;
            transition handleQuery
                first idle
                accept query : LibraryQuery via queryPort
                then idle;
        }
    }

    part def PlaybackController {
        port commandPort : CommandPort;
        port mediaInPort : MediaDataPort;
        port mediaOutPort : ~MediaDataPort;
        port networkControlPort : ~CommandPort;

        exhibit state playbackBehavior {
            entry; then stopped;
            state stopped;
            state playing;
            state paused;

            transition play
                first stopped
                accept cmd : PlaybackCommand via commandPort
                if cmd.command == "play"
                then playing;

            transition pause
                first playing
                accept cmd : PlaybackCommand via commandPort
                if cmd.command == "pause"
                then paused;

            transition resume
                first paused
                accept cmd : PlaybackCommand via commandPort
                if cmd.command == "play"
                then playing;

            transition stopFromPlaying
                first playing
                accept cmd : PlaybackCommand via commandPort
                if cmd.command == "stop"
                then stopped;

            transition stopFromPaused
                first paused
                accept cmd : PlaybackCommand via commandPort
                if cmd.command == "stop"
                then stopped;

            transition seekFromPlaying
                first playing
                accept cmd : PlaybackCommand via commandPort
                if cmd.command == "seek"
                then playing;

            transition seekFromPaused
                first paused
                accept cmd : PlaybackCommand via commandPort
                if cmd.command == "seek"
                then playing;
        }
    }

    part def MediaDecoder {
        port mediaInPort : MediaDataPort;
        port videoOutPort : ~VideoOutputPort;
        port audioOutPort : ~AudioOutputPort;

        perform action decodeBehavior {
            action parseContainer;
            action demuxVideo;
            action demuxAudio;
        }
    }

    part def NetworkStreamer {
        port controlPort : CommandPort;
        port streamOutPort : ~MediaDataPort;

        exhibit state streamerBehavior {
            entry; then idle;
            state idle;
            state buffering;
            state streaming;

            transition connectStream
                first idle
                accept cmd : PlaybackCommand via controlPort
                if cmd.command == "play"
                then buffering;

            transition startStreaming
                first buffering
                then streaming;

            transition stopStream
                first streaming
                accept cmd : PlaybackCommand via controlPort
                if cmd.command == "stop"
                then idle;
        }
    }

    part def UserInterface {
        port commandPort : ~CommandPort;
        port libraryQueryPort : ~LibraryQueryPort;
        port userInputPort : UserInputPort;

        exhibit state uiBehavior {
            entry; then browsing;
            state browsing;
            state controllingPlayback;

            transition selectMedia
                first browsing
                accept selection : String via userInputPort
                then controllingPlayback;

            transition controlMedia
                first controllingPlayback
                accept input : String via userInputPort
                then controllingPlayback;

            transition returnToBrowse
                first controllingPlayback
                accept input : String via userInputPort
                if input == "back"
                then browsing;
        }
    }

    part def DisplayDevice {
        port videoInPort : VideoOutputPort;
        perform action renderVideo {
            action displayFrame;
        }
    }

    part def AudioDevice {
        port audioInPort : AudioOutputPort;
        perform action playAudio {
            action outputSound;
        }
    }

    part def KodiSystem {
        part mediaLibrary : MediaLibrary;
        part playbackController : PlaybackController;
        part mediaDecoder : MediaDecoder;
        part networkStreamer : NetworkStreamer;
        part userInterface : UserInterface;
        part displayDevice : DisplayDevice;
        part audioDevice : AudioDevice;

        interface uiToLibrary connect userInterface.libraryQueryPort to mediaLibrary.queryPort;
        interface uiToController connect userInterface.commandPort to playbackController.commandPort;
        interface libraryToController connect mediaLibrary.mediaOutPort to playbackController.mediaInPort;
        interface controllerToDecoder connect playbackController.mediaOutPort to mediaDecoder.mediaInPort;
        interface controllerToStreamer connect playbackController.networkControlPort to networkStreamer.controlPort;
        interface streamerToDecoder connect networkStreamer.streamOutPort to mediaDecoder.mediaInPort;
        interface decoderToDisplay connect mediaDecoder.videoOutPort to displayDevice.videoInPort;
        interface decoderToAudio connect mediaDecoder.audioOutPort to audioDevice.audioInPort;
    }

    part kodiInstance : KodiSystem {
        satisfy MediaDiscoveryRequirement by mediaLibrary;
        satisfy PlaybackControlRequirement by playbackController;
        satisfy MediaDecodingRequirement by mediaDecoder;
        satisfy NetworkStreamingRequirement by networkStreamer;
        satisfy UserInterfaceRequirement by userInterface;
    }
}
