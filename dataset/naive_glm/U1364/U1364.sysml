package VideoDiskRecorder {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import SI::*;

    // ===== Unit Definitions =====
    unit GB;
    unit Mbps;
    unit MHz;
    unit dBm;
    unit fps;

    // ===== Value Type Definitions =====
    value type StorageSizeValue :> Real {
        unit GB;
    }

    value type DataRateValue :> Real {
        unit Mbps;
    }

    value type FrequencyValue :> Real {
        unit MHz;
    }

    value type SignalStrengthValue :> Real {
        unit dBm;
    }

    value type FrameRateValue :> Real {
        unit fps;
    }

    value type DurationValue :> Real {
        unit s;
    }

    // ===== Enumeration Definitions =====
    enum def CommandType {
        literal record;
        literal play;
        literal pause;
        literal stop;
        literal delete;
        literal selectChannel;
    }

    enum def ModulationType {
        literal QAM;
        literal QPSK;
        literal OFDM;
        literal VSB;
    }

    // ===== Item Definitions =====
    item def BroadcastSignal {
        attribute carrierFrequency : FrequencyValue;
        attribute strength : SignalStrengthValue;
        attribute modulation : ModulationType;
    }

    item def RawVideoStream {
        attribute resolution : String;
        attribute frameRate : FrameRateValue;
        attribute dataRate : DataRateValue;
    }

    item def RawAudioStream {
        attribute sampleRate : Real;
        attribute channels : Integer;
        attribute dataRate : DataRateValue;
    }

    item def CompressedVideoStream {
        attribute codec : String;
        attribute bitrate : DataRateValue;
    }

    item def CompressedAudioStream {
        attribute codec : String;
        attribute bitrate : DataRateValue;
    }

    item def ProgramMetadata {
        attribute title : String;
        attribute channel : Integer;
        attribute duration : DurationValue;
        attribute recordStartTime : String;
    }

    item def RecordedProgram {
        attribute metadata : ProgramMetadata;
        attribute video : CompressedVideoStream;
        attribute audio : CompressedAudioStream;
        attribute size : StorageSizeValue;
    }

    item def UserCommand {
        attribute type : CommandType;
        attribute channel : Integer;
        attribute programTitle : String;
    }

    item def ControlMessage {
        attribute command : CommandType;
        attribute channel : Integer;
        attribute programTitle : String;
    }

    // ===== Port Definitions =====
    port def BroadcastPort {
        in item signal : BroadcastSignal;
    }

    port def RawStreamSinkPort {
        in item video : RawVideoStream;
        in item audio : RawAudioStream;
    }

    port def RawStreamSourcePort {
        out item video : RawVideoStream;
        out item audio : RawAudioStream;
    }

    port def CompressedStreamSinkPort {
        in item video : CompressedVideoStream;
        in item audio : CompressedAudioStream;
        in item metadata : ProgramMetadata;
    }

    port def CompressedStreamSourcePort {
        out item video : CompressedVideoStream;
        out item audio : CompressedAudioStream;
        out item metadata : ProgramMetadata;
    }

    port def CommandSinkPort {
        in item command : ControlMessage;
    }

    port def CommandSourcePort {
        out item command : ControlMessage;
    }

    port def DisplayPort {
        out item video : RawVideoStream;
        out item audio : RawAudioStream;
    }

    // ===== Part Definitions =====

    part def TunerUnit {
        port broadcastIn : BroadcastPort;
        port rawOut : RawStreamSourcePort;
        port controlIn : CommandSinkPort;

        attribute selectedChannel : Integer = 1;
        attribute signalLocked : Boolean = false;

        state tunerState {
            entry; then Idle;

            state Idle {
                entry action { /* Tuner idle, no A/V output */ }
            }

            state Tuning {
                entry action { /* Tuning to selected channel frequency */ }
            }

            state Streaming {
                entry action { /* Outputting raw video and audio streams */ }
            }

            transition t1 first Idle
                if controlIn.command.command == CommandType::selectChannel
                then Tuning;

            transition t2 first Tuning
                if signalLocked == true
                then Streaming;

            transition t3 first Streaming
                if controlIn.command.command == CommandType::stop
                then Idle;
        }
    }

    part def EncoderUnit {
        port rawIn : RawStreamSinkPort;
        port compressedOut : CompressedStreamSourcePort;
        port controlIn : CommandSinkPort;

        attribute videoCodec : String = "H.264";
        attribute audioCodec : String = "AAC";
        attribute compressionRatio : Real = 10.0;

        state encoderState {
            entry; then Standby;

            state Standby {
                entry action { /* Encoder in standby mode */ }
            }

            state Encoding {
                entry action { /* Compressing raw A/V into digital format */ }
            }

            transition t1 first Standby
                if controlIn.command.command == CommandType::record
                then Encoding;

            transition t2 first Encoding
                if controlIn.command.command == CommandType::stop
                then Standby;
        }
    }

    part def StorageUnit {
        port writeIn : CompressedStreamSinkPort;
        port readOut : CompressedStreamSourcePort;
        port controlIn : CommandSinkPort;

        attribute capacity : StorageSizeValue = 500 [GB];
        attribute usedSpace : StorageSizeValue = 0 [GB];
        attribute programCount : Integer = 0;

        state storageState {
            entry; then Ready;

            state Ready {
                entry action { /* Storage ready for read/write/delete */ }
            }

            state Writing {
                entry action { /* Writing compressed program to disk */ }
            }

            state Reading {
                entry action { /* Reading requested program from disk */ }
            }

            state Deleting {
                entry action { /* Deleting specified program from library */ }
            }

            transition t1 first Ready
                if controlIn.command.command == CommandType::record
                then Writing;

            transition t2 first Writing
                if controlIn.command.command == CommandType::stop
                then Ready;

            transition t3 first Ready
                if controlIn.command.command == CommandType::play
                then Reading;

            transition t4 first Reading
                if controlIn.command.command == CommandType::stop
                then Ready;

            transition t5 first Ready
                if controlIn.command.command == CommandType::delete
                then Deleting;

            transition t6 first Deleting
                if true
                then Ready;
        }
    }

    part def DecoderUnit {
        port compressedIn : CompressedStreamSinkPort;
        port rawOut : RawStreamSourcePort;
        port controlIn : CommandSinkPort;

        attribute videoCodec : String = "H.264";
        attribute audioCodec : String = "AAC";

        state decoderState {
            entry; then Standby;

            state Standby {
                entry action { /* Decoder in standby mode */ }
            }

            state Decoding {
                entry action { /* Decompressing data to raw A/V streams */ }
            }

            state Paused {
                entry action { /* Playback paused, buffers held */ }
            }

            transition t1 first Standby
                if controlIn.command.command == CommandType::play
                then Decoding;

            transition t2 first Decoding
                if controlIn.command.command == CommandType::pause
                then Paused;

            transition t3 first Paused
                if controlIn.command.command == CommandType::play
                then Decoding;

            transition t4 first Decoding
                if controlIn.command.command == CommandType::stop
                then Standby;

            transition t5 first Paused
                if controlIn.command.command == CommandType::stop
                then Standby;
        }
    }

    part def ControllerUnit {
        port userCommandIn : CommandSinkPort;
        port tunerControl : CommandSourcePort;
        port encoderControl : CommandSourcePort;
        port storageControl : CommandSourcePort;
        port decoderControl : CommandSourcePort;

        attribute currentChannel : Integer = 1;
        attribute recordingActive : Boolean = false;
        attribute playbackActive : Boolean = false;

        state controllerState {
            entry; then Idle;

            state Idle {
                entry action { /* System idle, awaiting user commands */ }
            }

            state Recording {
                entry action { /* Recording in progress, no playback */ }
            }

            state Playing {
                entry action { /* Playback in progress, no recording */ }
            }

            state Paused {
                entry action { /* Playback paused, no recording */ }
            }

            state RecordingAndPlaying {
                entry action { /* Simultaneous recording and playback */ }
            }

            state RecordingAndPaused {
                entry action { /* Recording while playback is paused */ }
            }

            transition t1 first Idle
                if userCommandIn.command.command == CommandType::record
                then Recording;

            transition t2 first Idle
                if userCommandIn.command.command == CommandType::play
                then Playing;

            transition t3 first Recording
                if userCommandIn.command.command == CommandType::play
                then RecordingAndPlaying;

            transition t4 first Recording
                if userCommandIn.command.command == CommandType::stop
                then Idle;

            transition t5 first Playing
                if userCommandIn.command.command == CommandType::pause
                then Paused;

            transition t6 first Playing
                if userCommandIn.command.command == CommandType::stop
                then Idle;

            transition t7 first Playing
                if userCommandIn.command.command == CommandType::record
                then RecordingAndPlaying;

            transition t8 first Paused
                if userCommandIn.command.command == CommandType::play
                then Playing;

            transition t9 first Paused
                if userCommandIn.command.command == CommandType::stop
                then Idle;

            transition t10 first Paused
                if userCommandIn.command.command == CommandType::record
                then RecordingAndPaused;

            transition t11 first RecordingAndPlaying
                if userCommandIn.command.command == CommandType::pause
                then RecordingAndPaused;

            transition t12 first RecordingAndPlaying
                if userCommandIn.command.command == CommandType::stop
                then Recording;

            transition t13 first RecordingAndPaused
                if userCommandIn.command.command == CommandType::play
                then RecordingAndPlaying;

            transition t14 first RecordingAndPaused
                if userCommandIn.command.command == CommandType::stop
                then Recording;
        }
    }

    // ===== System Assembly =====
    part def VDRSystem {
        port antennaIn : BroadcastPort;
        port displayOut : DisplayPort;
        port userIn : CommandSinkPort;

        part tuner : TunerUnit;
        part encoder : EncoderUnit;
        part storage : StorageUnit;
        part decoder : DecoderUnit;
        part controller : ControllerUnit;

        // Broadcast signal and data stream connections
        connection broadcastConn
            connect antennaIn to tuner.broadcastIn;

        connection tunerToEncoder
            connect tuner.rawOut to encoder.rawIn;

        connection encoderToStorage
            connect encoder.compressedOut to storage.writeIn;

        connection storageToDecoder
            connect storage.readOut to decoder.compressedIn;

        connection decoderToDisplay
            connect decoder.rawOut to displayOut;

        // Control signal connections
        connection userToController
            connect userIn to controller.userCommandIn;

        connection ctrlToTuner
            connect controller.tunerControl to tuner.controlIn;

        connection ctrlToEncoder
            connect controller.encoderControl to encoder.controlIn;

        connection ctrlToStorage
            connect controller.storageControl to storage.controlIn;

        connection ctrlToDecoder
            connect controller.decoderControl to decoder.controlIn;
    }

    // ===== Requirements =====
    requirement def ReceiveBroadcastRequirement {
        subject vdr : VDRSystem;
        doc /* The VDR shall receive live television broadcasts via the tuner unit. */;
    }

    requirement def ChannelSelectionRequirement {
        subject tuner : TunerUnit;
        doc /* The tuner shall isolate a specific channel selected by the user from the incoming broadcast signal. */;
    }

    requirement def RecordProgramRequirement {
        subject vdr : VDRSystem;
        doc /* The VDR shall record selected programs to internal digital storage. */;
    }

    requirement def CompressionRequirement {
        subject encoder : EncoderUnit;
        doc /* The encoder shall compress video and audio data into a compact digital format for efficient storage. */;
    }

    requirement def MetadataStorageRequirement {
        subject vdr : VDRSystem;
        doc /* The system shall store program metadata including title and channel alongside compressed data. */;
    }

    requirement def StorageCapacityRequirement {
        subject storage : StorageUnit;
        doc /* The storage unit shall provide a total capacity of 500 GB. */;
        constraint { storage.capacity == 500 [GB] }
    }

    requirement def StorageOperationsRequirement {
        subject storage : StorageUnit;
        doc /* The storage unit shall support writing new recordings, reading existing recordings, and deleting recordings. */;
    }

    requirement def PlaybackRequirement {
        subject vdr : VDRSystem;
        doc /* The VDR shall play back recorded programs on demand. */;
    }

    requirement def DecompressionRequirement {
        subject decoder : DecoderUnit;
        doc /* The decoder shall decompress recorded data back into standard video and audio streams. */;
    }

    requirement def DisplayOutputRequirement {
        subject vdr : VDRSystem;
        doc /* The VDR shall output decompressed video and audio streams to a display device. */;
    }

    requirement def StateManagementRequirement {
        subject controller : ControllerUnit;
        doc /* The controller shall manage system states: idle, recording, playing, and paused. */;
    }

    requirement def SimultaneousOpsRequirement {
        subject vdr : VDRSystem;
        doc /* The VDR shall support recording one program while playing back another simultaneously. */;
    }

    requirement def UserControlRequirement {
        subject controller : ControllerUnit;
        doc /* The controller shall receive user commands including record, play, pause, and stop, and orchestrate all components accordingly. */;
    }
}
