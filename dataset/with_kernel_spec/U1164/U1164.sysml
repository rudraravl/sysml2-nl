package 'Automated DJ System' {
    private import ScalarValues::*;
    private import ISQ::*;

    item def MusicalKey {
        attribute name : ScalarValues::String;
        attribute camelotCode : ScalarValues::String;
    }

    item def BeatGrid {
        attribute bpm : ScalarValues::Real;
        attribute beatTimes : ISQ::TimeValue[*];
    }

    item def Track {
        attribute title : ScalarValues::String;
        attribute artist : ScalarValues::String;
        attribute tempo : ScalarValues::Real;
        attribute key : MusicalKey;
        attribute energy : ScalarValues::Real;
        attribute danceability : ScalarValues::Real;
        attribute beatGrid : BeatGrid;
        attribute duration : ISQ::TimeValue;
    }

    item def Playlist {
        attribute tracks : Track[*];
    }

    item def UserPreferences {
        attribute genre : ScalarValues::String;
        attribute mood : ScalarValues::String;
        attribute targetEnergy : ScalarValues::Real;
    }

    item def AudioStream {
        attribute sampleRate : ISQ::FrequencyValue;
        attribute channels : ScalarValues::Integer;
        attribute duration : ISQ::TimeValue;
    }

    item def ControlCommand {
        attribute command : ScalarValues::String;
        attribute timestamp : ISQ::TimeValue;
    }

    item def StatusReport {
        attribute currentState : ScalarValues::String;
        attribute elapsedTime : ISQ::TimeValue;
    }

    action def AnalyzeTrack {
        in rawTrack : Track;
        out analyzedTrack : Track;
    }

    action def GeneratePlaylistAction {
        in preferences : UserPreferences;
        in availableTracks : Track[*];
        out playlist : Playlist;
    }

    action def CrossfadeTracks {
        in currentTrack : Track;
        in nextTrack : Track;
        in crossfadeDuration : ISQ::TimeValue;
        out audio : AudioStream;
    }

    action def ProcessAudioAction {
        in rawAudio : AudioStream;
        in targetVolume : ScalarValues::Real;
        out processedAudio : AudioStream;
    }

    state machine def PlaybackStates {
        initial Idle;
        state Playing;
        state Paused;
        state Transitioning;
        transition from Idle to Playing on play;
        transition from Playing to Paused on pause;
        transition from Paused to Playing on resume;
        transition from Playing to Transitioning on nextTrack;
        transition from Transitioning to Playing on transitionComplete;
        transition from Playing to Idle on stop;
    }

    part def MusicLibrary {
        in port queryPort : UserPreferences;
        out port trackPort : Track[*];
        attribute catalog : Track[*];
    }

    part def AnalysisEngine {
        in port rawTrackPort : Track[*];
        out port analyzedTrackPort : Track[*];
    }

    part def PlaylistGenerator {
        in port prefsPort : UserPreferences;
        in port trackPort : Track[*];
        out port playlistPort : Playlist;
    }

    part def TransitionEngine {
        in port currentTrackPort : Track;
        in port nextTrackPort : Track;
        out port audioPort : AudioStream;
    }

    part def AudioProcessor {
        in port audioInPort : AudioStream;
        out port audioOutPort : AudioStream;
    }

    part def PlaybackController {
        in port controlPort : ControlCommand;
        in port audioInPort : AudioStream;
        out port audioOutPort : AudioStream;
        out port statusPort : StatusReport;
        exhibit playbackBehavior : PlaybackStates;
    }

    part def AutomationOrchestrator {
        out port queryPort : UserPreferences;
        out port prefsPort : UserPreferences;
        out port currentTrackPort : Track;
        out port nextTrackPort : Track;
        out port controlPort : ControlCommand;
        in port playlistPort : Playlist;
        in port statusPort : StatusReport;
    }

    part def DJSystem {
        out port externalOutput : AudioStream;

        part orchestrator : AutomationOrchestrator;
        part library : MusicLibrary;
        part analyzer : AnalysisEngine;
        part generator : PlaylistGenerator;
        part transitionEngine : TransitionEngine;
        part audioProcessor : AudioProcessor;
        part playbackController : PlaybackController;

        connect orchestrator.queryPort to library.queryPort;
        connect library.trackPort to analyzer.rawTrackPort;
        connect analyzer.analyzedTrackPort to generator.trackPort;
        connect orchestrator.prefsPort to generator.prefsPort;
        connect generator.playlistPort to orchestrator.playlistPort;
        connect orchestrator.currentTrackPort to transitionEngine.currentTrackPort;
        connect orchestrator.nextTrackPort to transitionEngine.nextTrackPort;
        connect transitionEngine.audioPort to audioProcessor.audioInPort;
        connect audioProcessor.audioOutPort to playbackController.audioInPort;
        connect orchestrator.controlPort to playbackController.controlPort;
        connect playbackController.audioOutPort to externalOutput;
        connect playbackController.statusPort to orchestrator.statusPort;
    }

    requirement def SeamlessMixing {
        doc "The system shall create continuous, seamless mixes of music without perceptible gaps between tracks."
    }

    requirement def UserTailoredPlayback {
        doc "The system shall tailor music selection to user preferences including genre, mood, and energy level."
    }

    requirement def ConsistentSoundQuality {
        doc "The system shall normalize volume and apply equalization for consistent sound quality across all tracks."
    }

    requirement def AutomatedOperation {
        doc "The automation orchestrator shall control the entire pipeline from library query to continuous playback without manual intervention."
    }
}
