package KodiMediaCenter {
    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Time;

    // ---------- Value Types ----------
    value type DataRate > Real {
        unit 'Mbps';
    }
    value type BufferSize > Integer {
        unit 'KB';
    }
    value type VolumeLevel > Real {
        unit 'dB';
        min = 0.0;
        max = 100.0;
    }
    value type BrightnessLevel > Real {
        unit '%';
        min = 0.0;
        max = 100.0;
    }
    value type ResolutionWidth > Integer {
        unit 'px';
    }
    value type ResolutionHeight > Integer {
        unit 'px';
    }
    value type FrameRate > Real {
        unit 'fps';
    }
    value type SampleRate > Integer {
        unit 'Hz';
    }
    value type ChannelCount > Integer {
        unit 'ch';
    }

    // ---------- Enumerations ----------
    enum MediaKind { movie, tvShow, music, musicVideo, picture, liveStream }
    enum PlaybackState { idle, loading, playing, paused, stopped, buffering, error }
    enum ScanStatus { idle, scanning, completed, failed }
    enum SourceType { local, networkShare, internetStream }
    enum UserCommand { browse, search, select, play, pause, resume, stop, seekForward, seekBackward, volumeUp, volumeDown, toggleSubtitle, quit }

    // ---------- Item Definitions ----------
    item def MediaFile {
        attribute path : String;
        attribute kind : MediaKind;
        attribute source : SourceType;
        attribute size : Integer { unit 'KB'; }
        attribute duration : Time;
        attribute title : String;
        attribute artist : String[0..*];
        attribute genre : String[0..*];
        attribute releaseYear : Integer;
        attribute coverArtPath : String;
    }

    item def MediaMetadata {
        attribute title : String;
        attribute duration : Time;
        attribute coverArtPath : String;
        attribute kind : MediaKind;
        attribute rating : Real { min = 0.0; max = 10.0; }
        attribute plotSummary : String;
        attribute cast : String[0..*];
        attribute director : String;
    }

    item def CatalogEntry {
        attribute id : String;
        attribute metadata : MediaMetadata;
        attribute filePath : String;
        attribute source : SourceType;
        attribute dateAdded : String;
        attribute playCount : Integer;
        attribute lastPlayed : Time;
    }

    item def VideoStream {
        attribute codec : String;
        attribute width : ResolutionWidth;
        attribute height : ResolutionHeight;
        attribute frameRate : FrameRate;
        attribute bitRate : DataRate;
        attribute hasSubtitles : Boolean;
    }

    item def AudioStream {
        attribute codec : String;
        attribute sampleRate : SampleRate;
        attribute channels : ChannelCount;
        attribute bitRate : DataRate;
        attribute language : String;
    }

    item def DecodedFrame {
        attribute width : ResolutionWidth;
        attribute height : ResolutionHeight;
        attribute timestamp : Time;
        attribute data : String;
    }

    item def AudioPacket {
        attribute sampleRate : SampleRate;
        attribute channels : ChannelCount;
        attribute timestamp : Time;
        attribute data : String;
    }

    item def BufferedChunk {
        attribute sequence : Integer;
        attribute size : BufferSize;
        attribute data : String;
        attribute isLast : Boolean;
    }

    item def URL {
        attribute address : String;
        attribute protocol : String;
        attribute requiresAuth : Boolean;
    }

    item def ScanTarget {
        attribute path : String;
        attribute source : SourceType;
        attribute recursive : Boolean;
        attribute kind : MediaKind;
    }

    item def SearchQuery {
        attribute text : String;
        attribute filterKind : MediaKind[0..*];
        attribute filterGenre : String[0..*];
        attribute maxResults : Integer;
    }

    item def SearchResult {
        attribute entries : CatalogEntry[0..*];
        attribute totalCount : Integer;
    }

    item def PlaybackCommand {
        attribute command : UserCommand;
        attribute seekPosition : Time[0..1];
        attribute mediaId : String[0..1];
    }

    // ---------- Port Definitions ----------
    port def MediaFilePort {
        out mediaFile : MediaFile;
    }

    port def CatalogPort {
        out entries : CatalogEntry[0..*];
        in query : SearchQuery;
        out result : SearchResult;
    }

    port def CommandPort {
        in command : PlaybackCommand;
    }

    port def RawStreamPort {
        out data : String;
    }

    port def VideoStreamPort {
        out video : VideoStream;
    }

    port def AudioStreamPort {
        out audio : AudioStream;
    }

    port def DecodedVideoPort {
        out frame : DecodedFrame;
    }

    port def DecodedAudioPort {
        out packet : AudioPacket;
    }

    port def BufferedDataPort {
        out chunk : BufferedChunk;
    }

    port def URLRequestPort {
        in url : URL;
    }

    port def ScanTargetPort {
        in target : ScanTarget;
    }

    port def DisplayControlPort {
        in brightness : BrightnessLevel;
    }

    port def AudioControlPort {
        in volume : VolumeLevel;
    }

    // ---------- Media Library ----------
    part def MediaLibrary {
        port catalogPort : CatalogPort;
        port scanPort : ScanTargetPort;
        port filePort : MediaFilePort;

        attribute entries : CatalogEntry[0..*];
        attribute scanStatus : ScanStatus = ScanStatus::idle;
        attribute lastScanTime : Time;

        state machine LibraryBehavior {
            entry; then Idle;

            state Idle;
            transition from Idle to Scanning
                when scanPort.target is received
                guard scanPort.target.source != SourceType::internetStream;

            state Scanning {
                entry assign scanStatus = ScanStatus::scanning;
                do { scanLocation(); extractMetadata(); indexEntries(); }
            }
            transition from Scanning to Completed
                when scanStatus == ScanStatus::scanning
                guard entries->size() > 0;

            state Completed {
                entry assign scanStatus = ScanStatus::completed;
                entry assign lastScanTime = 0.0 [s];
            }
            transition from Completed to Idle
                when true;

            transition from Scanning to Failed
                when scanStatus == ScanStatus::scanning
                guard entries->size() == 0;
            state Failed {
                entry assign scanStatus = ScanStatus::failed;
            }
            transition from Failed to Idle when true;
        }

        action scanLocation {
            in target : ScanTarget;
        }
        action extractMetadata;
        action indexEntries;
        action searchCatalog {
            in query : SearchQuery;
            return result : SearchResult;
        }
    }

    // ---------- Playback Controller ----------
    part def PlaybackController {
        port commandPort : CommandPort;
        port rawStreamOut : RawStreamPort;
        port fileIn : MediaFilePort;
        port bufferedIn : BufferedDataPort;

        attribute currentState : PlaybackState = PlaybackState::idle;
        attribute currentPosition : Time = 0.0 [s];
        attribute totalDuration : Time;
        attribute volume : VolumeLevel = 50.0 [dB];
        attribute brightness : BrightnessLevel = 80.0 [%];

        state machine PlaybackBehavior {
            entry; then Idle;

            state Idle;
            transition from Idle to Loading
                when commandPort.command is received
                guard commandPort.command.command == UserCommand::play;

            state Loading {
                entry assign currentState = PlaybackState::loading;
                do { loadMedia(); }
            }
            transition from Loading to Playing
                when fileIn.mediaFile is received or bufferedIn.chunk is received;

            state Playing {
                entry assign currentState = PlaybackState::playing;
                do { sendStream(); updatePosition(); }
            }
            transition from Playing to Paused
                when commandPort.command is received
                guard commandPort.command.command == UserCommand::pause;
            transition from Playing to Stopped
                when commandPort.command is received
                guard commandPort.command.command == UserCommand::stop;
            transition from Playing to Playing
                when commandPort.command is received
                guard commandPort.command.command == UserCommand::seekForward
                do { currentPosition = currentPosition + 10.0 [s]; };
            transition from Playing to Playing
                when commandPort.command is received
                guard commandPort.command.command == UserCommand::seekBackward
                do { currentPosition = currentPosition - 10.0 [s]; };

            state Paused {
                entry assign currentState = PlaybackState::paused;
            }
            transition from Paused to Playing
                when commandPort.command is received
                guard commandPort.command.command == UserCommand::resume;
            transition from Paused to Stopped
                when commandPort.command is received
                guard commandPort.command.command == UserCommand::stop;

            state Stopped {
                entry assign currentState = PlaybackState::stopped;
                do { currentPosition = 0.0 [s]; }
            }
            transition from Stopped to Idle when true;

            transition from Playing to Error
                when rawStreamOut.data is not sent;
            state Error {
                entry assign currentState = PlaybackState::error;
            }
            transition from Error to Idle when true;
        }

        action loadMedia;
        action sendStream;
        action updatePosition;
    }

    // ---------- Media Decoder ----------
    part def MediaDecoder {
        port rawIn : RawStreamPort;
        port videoOut : VideoStreamPort;
        port audioOut : AudioStreamPort;
        port decodedVideoOut : DecodedVideoPort;
        port decodedAudioOut : DecodedAudioPort;

        attribute videoStream : VideoStream;
        attribute audioStream : AudioStream;
        attribute decodingActive : Boolean = false;

        state machine DecoderBehavior {
            entry; then Waiting;

            state Waiting;
            transition from Waiting to Demuxing
                when rawIn.data is received;

            state Demuxing {
                entry assign decodingActive = true;
                do { demuxStream(); }
            }
            transition from Demuxing to Decoding
                when videoOut.video is sent and audioOut.audio is sent;

            state Decoding {
                do { decodeVideo(); decodeAudio(); }
            }
            transition from Decoding to Demuxing
                when rawIn.data is received;
            transition from Decoding to Waiting
                when rawIn.data is not received
                do { decodingActive = false; };
        }

        action demuxStream {
            in data : String;
            out video : VideoStream;
            out audio : AudioStream;
        }
        action decodeVideo {
            out frame : DecodedFrame;
        }
        action decodeAudio {
            out packet : AudioPacket;
        }
    }

    // ---------- Display Device ----------
    part def DisplayDevice {
        port videoIn : DecodedVideoPort;
        port controlIn : DisplayControlPort;

        attribute currentBrightness : BrightnessLevel = 80.0 [%];
        attribute resolutionWidth : ResolutionWidth = 1920 [px];
        attribute resolutionHeight : ResolutionHeight = 1080 [px];
        attribute isPoweredOn : Boolean = true;

        state machine DisplayBehavior {
            entry; then PoweredOn;

            state PoweredOn {
                do { renderFrame(); }
            }
            transition from PoweredOn to PoweredOn
                when controlIn.brightness is received
                do { currentBrightness = controlIn.brightness; };
        }

        action renderFrame {
            in frame : DecodedFrame;
        }
    }

    // ---------- Audio Device ----------
    part def AudioDevice {
        port audioIn : DecodedAudioPort;
        port controlIn : AudioControlPort;

        attribute currentVolume : VolumeLevel = 50.0 [dB];
        attribute supportedChannels : ChannelCount = 2 [ch];
        attribute isMuted : Boolean = false;

        state machine AudioBehavior {
            entry; then Active;

            state Active {
                do { playAudio(); }
            }
            transition from Active to Muted
                when currentVolume == 0.0 [dB];
            transition from Active to Active
                when controlIn.volume is received
                do { currentVolume = controlIn.volume; };

            state Muted;
            transition from Muted to Active
                when controlIn.volume is received
                guard controlIn.volume > 0.0 [dB];
        }

        action playAudio {
            in packet : AudioPacket;
        }
    }

    // ---------- Network Streamer ----------
    part def NetworkStreamer {
        port urlIn : URLRequestPort;
        port bufferedOut : BufferedDataPort;

        attribute bufferCapacity : BufferSize = 8192 [KB];
        attribute currentBufferLevel : BufferSize = 0 [KB];
        attribute streamRate : DataRate = 5.0 [Mbps];
        attribute isConnected : Boolean = false;
        attribute currentURL : URL;

        state machine StreamerBehavior {
            entry; then Disconnected;

            state Disconnected;
            transition from Disconnected to Connecting
                when urlIn.url is received;

            state Connecting {
                do { establishConnection(); }
            }
            transition from Connecting to Buffering
                when isConnected == true;

            state Buffering {
                entry assign currentBufferLevel = 0 [KB];
                do { receiveData(); fillBuffer(); }
            }
            transition from Buffering to Streaming
                when currentBufferLevel >= bufferCapacity / 2;

            state Streaming {
                do { receiveData(); emitChunk(); }
            }
            transition from Streaming to Buffering
                when currentBufferLevel < bufferCapacity / 4;
            transition from Streaming to Disconnected
                when bufferedOut.chunk.isLast == true;
        }

        action establishConnection {
            in url : URL;
        }
        action receiveData;
        action fillBuffer;
        action emitChunk {
            out chunk : BufferedChunk;
        }
    }

    // ---------- User Interface ----------
    part def UserInterface {
        port commandOut : CommandPort;
        port catalogAccess : CatalogPort;
        port displayControlOut : DisplayControlPort;
        port audioControlOut : AudioControlPort;
        port scanTargetOut : ScanTargetPort;

        attribute currentView : String = "Home";
        attribute selectedMediaId : String;
        attribute searchResults : SearchResult;

        state machine UIBehavior {
            entry; then HomeView;

            state HomeView {
                entry assign currentView = "Home";
            }
            transition from HomeView to BrowseView
                when commandOut.command is received
                guard commandOut.command.command == UserCommand::browse;

            state BrowseView {
                entry assign currentView = "Browse";
                do { fetchCatalog(); }
            }
            transition from BrowseView to SearchView
                when commandOut.command is received
                guard commandOut.command.command == UserCommand::search;
            transition from BrowseView to HomeView
                when commandOut.command is received
                guard commandOut.command.command == UserCommand::quit;

            state SearchView {
                entry assign currentView = "Search";
                do { executeSearch(); }
            }
            transition from SearchView to BrowseView
                when catalogAccess.result is received;
            transition from SearchView to HomeView
                when commandOut.command is received
                guard commandOut.command.command == UserCommand::quit;

            transition from BrowseView to PlayingView
                when commandOut.command is received
                guard commandOut.command.command == UserCommand::select;

            state PlayingView {
                entry assign currentView = "Playing";
                do { sendPlaybackCommand(); }
            }
            transition from PlayingView to PlayingView
                when commandOut.command is received
                guard commandOut.command.command in { UserCommand::pause, UserCommand::resume, UserCommand::stop, UserCommand::seekForward, UserCommand::seekBackward, UserCommand::volumeUp, UserCommand::volumeDown };
            transition from PlayingView to HomeView
                when commandOut.command is received
                guard commandOut.command.command == UserCommand::quit;
        }

        action fetchCatalog;
        action executeSearch;
        action sendPlaybackCommand;
        action adjustVolume {
            in level : VolumeLevel;
        }
        action adjustBrightness {
            in level : BrightnessLevel;
        }
    }

    // ---------- Top-Level Kodi System ----------
    part def KodiSystem {
        part ui : UserInterface;
        part library : MediaLibrary;
        part playback : PlaybackController;
        part decoder : MediaDecoder;
        part display : DisplayDevice;
        part audio : AudioDevice;
        part streamer : NetworkStreamer;

        // UI to Library (catalog browsing and scan targets)
        connect ui.catalogAccess to library.catalogPort;
        connect ui.scanTargetOut to library.scanPort;

        // UI to Playback Controller (commands)
        connect ui.commandOut to playback.commandPort;

        // UI to Display and Audio (control)
        connect ui.displayControlOut to display.controlIn;
        connect ui.audioControlOut to audio.controlIn;

        // Library to Playback (selected media file)
        connect library.filePort to playback.fileIn;

        // Playback to Decoder (raw stream)
        connect playback.rawStreamOut to decoder.rawIn;

        // Decoder to Display (decoded video)
        connect decoder.decodedVideoOut to display.videoIn;

        // Decoder to Audio (decoded audio)
        connect decoder.decodedAudioOut to audio.audioIn;

        // Network Streamer to Playback (buffered data)
        connect streamer.bufferedOut to playback.bufferedIn;

        // UI to Network Streamer (URL request)
        // The UI sends URL through the playback command, which forwards to streamer
        // Modeled as a direct connection for internet stream selection
        connect ui.commandOut to streamer.urlIn {
            // Note: command port carries URL for internet streams
        }
    }

    // ---------- Requirements ----------
    requirement def MediaDiscoveryRequirement {
        subject : KodiSystem;
        objective {
            /* The system shall discover multimedia content from local storage, network shares, and internet streaming services. */
        }
    }

    requirement def LibraryIndexingRequirement {
        subject : MediaLibrary;
        objective {
            /* The Media Library shall scan specified locations, index media files, and gather metadata including titles, durations, and cover art. */
        }
    }

    requirement def PlaybackControlRequirement {
        subject : PlaybackController;
        objective {
            /* The Playback Controller shall handle user commands including play, pause, stop, and seek. */
        }
    }

    requirement def MediaDecodingRequirement {
        subject : MediaDecoder;
        objective {
            /* The Media Decoder shall process media files and separate them into distinct video and audio streams. */
        }
    }

    requirement def VideoOutputRequirement {
        subject : DisplayDevice;
        objective {
            /* The Display Device shall render the decoded video stream for the user. */
        }
    }

    requirement def AudioOutputRequirement {
        subject : AudioDevice;
        objective {
            /* The Audio Device shall play the decoded audio stream for the user. */
        }
    }

    requirement def NetworkStreamingRequirement {
        subject : NetworkStreamer;
        objective {
            /* The Network Streamer shall accept a URL, buffer incoming data, and feed content to the decoder for smooth playback. */
        }
    }

    requirement def UserInterfaceRequirement {
        subject : UserInterface;
        objective {
            /* The User Interface shall allow the user to browse the library, search for content, and manage playback. */
        }
    }

    requirement def BufferingRequirement {
        subject : NetworkStreamer;
        attribute minBufferCapacity : BufferSize = 4096 [KB];
        objective {
            /* The Network Streamer shall maintain a buffer of at least minBufferCapacity to ensure smooth playback. */
        }
    }

    requirement def ResolutionSupportRequirement {
        subject : DisplayDevice;
        attribute minWidth : ResolutionWidth = 1280 [px];
        attribute minHeight : ResolutionHeight = 720 [px];
        objective {
            /* The Display Device shall support video resolutions of at least minWidth by minHeight. */
        }
    }

    requirement def MultiSourceAggregationRequirement {
        subject : KodiSystem;
        objective {
            /* The Kodi system shall act as a central aggregator providing a single interface for accessing multimedia content regardless of storage location. */
        }
    }

    // ---------- Requirement Satisfaction ----------
    satisfaction mediaDiscoveryRequirement : MediaDiscoveryRequirement {
        subject :>> subject = kodiInstance;
    }
    satisfaction libraryIndexingRequirement : LibraryIndexingRequirement {
        subject :>> subject = kodiInstance.library;
    }
    satisfaction playbackControlRequirement : PlaybackControlRequirement {
        subject :>> subject = kodiInstance.playback;
    }
    satisfaction mediaDecodingRequirement : MediaDecodingRequirement {
        subject :>> subject = kodiInstance.decoder;
    }
    satisfaction videoOutputRequirement : VideoOutputRequirement {
        subject :>> subject = kodiInstance.display;
    }
    satisfaction audioOutputRequirement : AudioOutputRequirement {
        subject :>> subject = kodiInstance.audio;
    }
    satisfaction networkStreamingRequirement : NetworkStreamingRequirement {
        subject :>> subject = kodiInstance.streamer;
    }
    satisfaction userInterfaceRequirement : UserInterfaceRequirement {
        subject :>> subject = kodiInstance.ui;
    }
    satisfaction multiSourceAggregationRequirement : MultiSourceAggregationRequirement {
        subject :>> subject = kodiInstance;
    }

    // ---------- Instance ----------
    part kodiInstance : KodiSystem {
        attribute systemName : String = "Kodi Media Center";
        attribute version : String = "21.0";
    }
}
