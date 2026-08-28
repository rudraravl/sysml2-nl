package 'Video Disk Recorder System' {
    private import ScalarValues::*;

    item def BroadcastSignal;
    item def RawVideoAudio;
    attribute def Metadata {
        attribute title : String;
        attribute channel : String;
    }
    item def CompressedData {
        attribute programInfo : Metadata;
        attribute videoData : String;
        attribute audioData : String;
    }
    item def PlaybackData :> CompressedData;
    item def DecodedVideoAudio;

    item def UserCommand;
    item def RecordCommand :> UserCommand;
    item def PlayCommand :> UserCommand;
    item def PauseCommand :> UserCommand;
    item def StopCommand :> UserCommand;
    item def ChannelSelection :> UserCommand;

    port def BroadcastOutPort { out signal : BroadcastSignal; }
    port def BroadcastInPort { in signal : BroadcastSignal; }
    port def RawStreamOutPort { out stream : RawVideoAudio; }
    port def RawStreamInPort { in stream : RawVideoAudio; }
    port def CompressedDataOutPort { out data : CompressedData; }
    port def CompressedDataInPort { in data : CompressedData; }
    port def PlaybackDataOutPort { out data : PlaybackData; }
    port def PlaybackDataInPort { in data : PlaybackData; }
    port def DecodedStreamOutPort { out stream : DecodedVideoAudio; }
    port def DecodedStreamInPort { in stream : DecodedVideoAudio; }
    port def CommandOutPort { out command : UserCommand; }
    port def CommandInPort { in command : UserCommand; }

    part def Antenna {
        port broadcastOut : BroadcastOutPort;
    }

    part def User {
        port commandOut : CommandOutPort;
    }

    part def TunerUnit {
        port broadcastIn : BroadcastInPort;
        port rawStreamOut : RawStreamOutPort;
        port controlIn : CommandInPort;
        attribute selectedChannel : String;
    }

    part def EncoderUnit {
        port rawStreamIn : RawStreamInPort;
        port compressedDataOut : CompressedDataOutPort;
        port controlIn : CommandInPort;
    }

    part def StorageUnit {
        port compressedDataIn : CompressedDataInPort;
        port playbackDataOut : PlaybackDataOutPort;
        port controlIn : CommandInPort;
        attribute capacityGB : Real = 500;
    }

    part def DecoderUnit {
        port playbackDataIn : PlaybackDataInPort;
        port decodedStreamOut : DecodedStreamOutPort;
        port controlIn : CommandInPort;
    }

    part def DisplayOutput {
        port decodedStreamIn : DecodedStreamInPort;
    }

    part def ControllerUnit {
        port commandIn : CommandInPort;
        port tunerControl : CommandOutPort;
        port encoderControl : CommandOutPort;
        port storageControl : CommandOutPort;
        port decoderControl : CommandOutPort;

        state controllerStates {
            entry; then idle;

            state idle;
            state recording;
            state playing;
            state paused;

            transition idle_to_recording first idle accept RecordCommand then recording;
            transition idle_to_playing first idle accept PlayCommand then playing;
            transition recording_to_idle first recording accept StopCommand then idle;
            transition playing_to_paused first playing accept PauseCommand then paused;
            transition paused_to_playing first paused accept PlayCommand then playing;
            transition playing_to_idle first playing accept StopCommand then idle;
            transition paused_to_idle first paused accept StopCommand then idle;
        }
    }

    part def VideoDiskRecorder {
        part antenna : Antenna;
        part user : User;
        part tuner : TunerUnit;
        part encoder : EncoderUnit;
        part storage : StorageUnit;
        part decoder : DecoderUnit;
        part display : DisplayOutput;
        part controller : ControllerUnit;

        connect antenna.broadcastOut to tuner.broadcastIn;
        connect user.commandOut to controller.commandIn;
        connect controller.tunerControl to tuner.controlIn;
        connect controller.encoderControl to encoder.controlIn;
        connect controller.storageControl to storage.controlIn;
        connect controller.decoderControl to decoder.controlIn;

        connect tuner.rawStreamOut to encoder.rawStreamIn;
        connect encoder.compressedDataOut to storage.compressedDataIn;
        connect storage.playbackDataOut to decoder.playbackDataIn;
        connect decoder.decodedStreamOut to display.decodedStreamIn;
    }

    part vdrSystem : VideoDiskRecorder;

    requirement storageCapacityRequirement {
        doc /* The storage unit shall have a capacity of 500 GB. */
    }

    requirement simultaneousOpsRequirement {
        doc /* The system shall support simultaneous recording and playback. */
    }

    requirement stateBasedOperationRequirement {
        doc /* The controller shall manage system states including idle, recording, playing, and paused. */
    }

    satisfy storageCapacityRequirement by vdrSystem;
    satisfy simultaneousOpsRequirement by vdrSystem;
    satisfy stateBasedOperationRequirement by vdrSystem;
}
