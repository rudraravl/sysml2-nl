package DJSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value def BPM :> Real {
        doc /* Beats per minute */
        unit bpm;
    }

    unit bpm {
        definition = 1 / (60 [s]);
    }

    value def EnergyLevel :> Real {
        doc /* Normalized energy level 0.0 to 1.0 */
        unit dimensionless;
    }

    value def Danceability :> Real {
        doc /* Normalized danceability 0.0 to 1.0 */
        unit dimensionless;
    }

    value def Loudness :> Real {
        doc /* Loudness in decibels relative to full scale */
        unit dBFS;
    }

    unit dBFS {
        definition = 1 [dB];
    }

    value def VolumeGain :> Real {
        doc /* Linear gain factor */
        unit dimensionless;
    }

    value def CrossfadeDuration :> Real {
        unit s;
    }

    value def FrequencyHz :> Real {
        unit Hz;
    }

    value def MusicalKey :> String;

    value def Genre :> String;

    value def Mood :> String;

    value def TrackId :> String;

    value def Timestamp :> Real {
        unit s;
    }

    // ---- Item Definitions ----

    item def RawAudio {
        attribute sampleRate : FrequencyHz;
        attribute channels : Integer;
        attribute duration : TimeValue;
    }

    item def Track {
        attribute id : TrackId;
        attribute title : String;
        attribute artist : String;
        attribute genre : Genre;
        attribute mood : Mood;
        attribute tempo : BPM;
        attribute key : MusicalKey;
        attribute energy : EnergyLevel;
        attribute danceability : Danceability;
        attribute loudness : Loudness;
        attribute beatGrid : ListOfBeats;
        attribute audio : RawAudio;
    }

    item def ListOfBeats :> List {
        :>> elementType = Timestamp;
    }

    item def Playlist {
        attribute name : String;
        attribute tracks : ListOfTracks;
        attribute targetEnergy : EnergyLevel;
        attribute targetGenre : Genre;
        attribute targetMood : Mood;
    }

    item def ListOfTracks :> List {
        :>> elementType = Track;
    }

    item def UserPreferences {
        attribute desiredGenre : Genre;
        attribute desiredMood : Mood;
        attribute desiredEnergy : EnergyLevel;
        attribute desiredDanceability : Danceability;
        attribute sessionDuration : TimeValue;
    }

    item def TransitionPlan {
        attribute outgoingTrack : TrackId;
        attribute incomingTrack : TrackId;
        attribute crossfadeDuration : CrossfadeDuration;
        attribute beatMatchOffset : Timestamp;
        attribute tempoAdjustment : BPM;
    }

    item def ProcessedAudio {
        attribute sampleRate : FrequencyHz;
        attribute channels : Integer;
        attribute gain : VolumeGain;
        attribute eqLow : VolumeGain;
        attribute eqMid : VolumeGain;
        attribute eqHigh : VolumeGain;
    }

    item def PlaybackState {
        attribute currentTrack : TrackId;
        attribute position : Timestamp;
        attribute isPlaying : Boolean;
    }

    // ---- Port Definitions ----

    port def AudioOutPort {
        out audio : ProcessedAudio;
    }

    port def AudioInPort {
        in audio : RawAudio;
    }

    port def TrackQueryPort {
        in query : String;
        out result : ListOfTracks;
    }

    port def PlaylistPort {
        in preferences : UserPreferences;
        out playlist : Playlist;
    }

    port def TransitionPort {
        in currentTrack : Track;
        in nextTrack : Track;
        out plan : TransitionPlan;
    }

    port def ControlPort {
        in command : String;
        out status : String;
    }

    port def AnalysisRequestPort {
        in rawAudio : RawAudio;
        out track : Track;
    }

    // ---- Interfaces ----

    interface def AudioStreamInterface {
        end source : AudioOutPort;
        end sink : AudioInPort;
        flow audio from source.audio to sink.audio;
    }

    interface def LibraryQueryInterface {
        end requester : TrackQueryPort;
        end library : TrackQueryPort;
        flow query from requester.query to library.query;
        flow result from library.result to requester.result;
    }

    interface def PlaylistInterface {
        end generator : PlaylistPort;
        end consumer : PlaylistPort;
        flow preferences from consumer.preferences to generator.preferences;
        flow playlist from generator.playlist to consumer.playlist;
    }

    interface def TransitionInterface {
        end engine : TransitionPort;
        end controller : TransitionPort;
        flow currentTrack from controller.currentTrack to engine.currentTrack;
        flow nextTrack from controller.nextTrack to engine.nextTrack;
        flow plan from engine.plan to controller.plan;
    }

    interface def ControlInterface {
        end orchestrator : ControlPort;
        end component : ControlPort;
        flow command from orchestrator.command to component.command;
        flow status from component.status to orchestrator.status;
    }

    // ---- Part Definitions ----

    part def MusicLibrary {
        port queryPort : TrackQueryPort;
        attribute tracks : ListOfTracks;
        attribute totalTracks : Integer;

        action def QueryTracks {
            in query : String;
            out result : ListOfTracks;
            // Filter tracks by genre, mood, energy, danceability
        }

        action def AddTrack {
            in newTrack : Track;
            // Add to library
        }

        action def RemoveTrack {
            in trackId : TrackId;
            // Remove from library
        }

        action def GetTrackById {
            in id : TrackId;
            out track : Track;
        }
    }

    part def AnalysisEngine {
        port analysisPort : AnalysisRequestPort;
        port controlPort : ControlPort;

        action def AnalyzeTrack {
            in rawAudio : RawAudio;
            out track : Track;

            action DetectTempo {
                in audio : RawAudio;
                out tempo : BPM;
            }

            action DetectKey {
                in audio : RawAudio;
                out key : MusicalKey;
            }

            action DetectEnergy {
                in audio : RawAudio;
                out energy : EnergyLevel;
            }

            action DetectDanceability {
                in audio : RawAudio;
                out danceability : Danceability;
            }

            action DetectLoudness {
                in audio : RawAudio;
                out loudness : Loudness;
            }

            action ExtractBeatGrid {
                in audio : RawAudio;
                out beats : ListOfBeats;
            }

            flow from rawAudio to DetectTempo.audio;
            flow from rawAudio to DetectKey.audio;
            flow from rawAudio to DetectEnergy.audio;
            flow from rawAudio to DetectDanceability.audio;
            flow from rawAudio to DetectLoudness.audio;
            flow from rawAudio to ExtractBeatGrid.audio;

            flow from DetectTempo.tempo to track.tempo;
            flow from DetectKey.key to track.key;
            flow from DetectEnergy.energy to track.energy;
            flow from DetectDanceability.danceability to track.danceability;
            flow from DetectLoudness.loudness to track.loudness;
            flow from ExtractBeatGrid.beats to track.beatGrid;
        }

        state analysisStateMachine {
            entry; then Idle;
            state Idle;
            transition from Idle to Analyzing
                when analysisPort.rawAudio is received;
            state Analyzing {
                entry do AnalyzeTrack;
            }
            transition from Analyzing to Idle
                when analysisPort.track is sent;
        }
    }

    part def PlaylistGenerator {
        port playlistPort : PlaylistPort;
        port queryPort : TrackQueryPort;
        port controlPort : ControlPort;

        action def GeneratePlaylist {
            in preferences : UserPreferences;
            out playlist : Playlist;

            action QuerySuitableTracks {
                in genre : Genre;
                in mood : Mood;
                in energy : EnergyLevel;
                out candidates : ListOfTracks;
            }

            action ScoreTracks {
                in candidates : ListOfTracks;
                in preferences : UserPreferences;
                out scored : ListOfTracks;
            }

            action SequenceTracks {
                in scored : ListOfTracks;
                out ordered : ListOfTracks;
                // Arrange for smooth tempo and key transitions
            }

            action ValidateFlow {
                in ordered : ListOfTracks;
                out validated : ListOfTracks;
                // Ensure tempo and key compatibility between consecutive tracks
            }

            flow from preferences to QuerySuitableTracks.genre;
            flow from preferences to QuerySuitableTracks.mood;
            flow from preferences to QuerySuitableTracks.energy;
            flow from QuerySuitableTracks.candidates to ScoreTracks.candidates;
            flow from preferences to ScoreTracks.preferences;
            flow from ScoreTracks.scored to SequenceTracks.scored;
            flow from SequenceTracks.ordered to ValidateFlow.ordered;
            flow from ValidateFlow.validated to playlist.tracks;
        }

        state generatorStateMachine {
            entry; then Waiting;
            state Waiting;
            transition from Waiting to Generating
                when playlistPort.preferences is received;
            state Generating {
                entry do GeneratePlaylist;
            }
            transition from Generating to Waiting
                when playlistPort.playlist is sent;
        }
    }

    part def TransitionEngine {
        port transitionPort : TransitionPort;
        port controlPort : ControlPort;

        action def CreateTransition {
            in currentTrack : Track;
            in nextTrack : Track;
            out plan : TransitionPlan;

            action BeatMatch {
                in currentTempo : BPM;
                in nextTempo : BPM;
                in currentBeats : ListOfBeats;
                in nextBeats : ListOfBeats;
                out tempoAdjustment : BPM;
                out beatMatchOffset : Timestamp;
            }

            action CalculateCrossfade {
                in currentEnergy : EnergyLevel;
                in nextEnergy : EnergyLevel;
                out crossfadeDuration : CrossfadeDuration;
            }

            action BuildPlan {
                in outgoingId : TrackId;
                in incomingId : TrackId;
                in crossfadeDuration : CrossfadeDuration;
                in beatMatchOffset : Timestamp;
                in tempoAdjustment : BPM;
                out plan : TransitionPlan;
            }

            flow from currentTrack.tempo to BeatMatch.currentTempo;
            flow from nextTrack.tempo to BeatMatch.nextTempo;
            flow from currentTrack.beatGrid to BeatMatch.currentBeats;
            flow from nextTrack.beatGrid to BeatMatch.nextBeats;
            flow from currentTrack.energy to CalculateCrossfade.currentEnergy;
            flow from nextTrack.energy to CalculateCrossfade.nextEnergy;
            flow from currentTrack.id to BuildPlan.outgoingId;
            flow from nextTrack.id to BuildPlan.incomingId;
            flow from CalculateCrossfade.crossfadeDuration to BuildPlan.crossfadeDuration;
            flow from BeatMatch.beatMatchOffset to BuildPlan.beatMatchOffset;
            flow from BeatMatch.tempoAdjustment to BuildPlan.tempoAdjustment;
            flow from BuildPlan.plan to plan;
        }

        state transitionStateMachine {
            entry; then Ready;
            state Ready;
            transition from Ready to Planning
                when transitionPort.currentTrack is received
                and transitionPort.nextTrack is received;
            state Planning {
                entry do CreateTransition;
            }
            transition from Planning to Ready
                when transitionPort.plan is sent;
        }
    }

    part def AudioProcessor {
        port inPort : AudioInPort;
        port outPort : AudioOutPort;
        port controlPort : ControlPort;

        attribute targetLoudness : Loudness = -14.0 [dBFS];
        attribute eqLowGain : VolumeGain = 1.0;
        attribute eqMidGain : VolumeGain = 1.0;
        attribute eqHighGain : VolumeGain = 1.0;

        action def ProcessAudio {
            in rawAudio : RawAudio;
            out processed : ProcessedAudio;

            action NormalizeVolume {
                in audio : RawAudio;
                in target : Loudness;
                out gain : VolumeGain;
            }

            action ApplyEqualization {
                in audio : RawAudio;
                in lowGain : VolumeGain;
                in midGain : VolumeGain;
                in highGain : VolumeGain;
                out eqLow : VolumeGain;
                out eqMid : VolumeGain;
                out eqHigh : VolumeGain;
            }

            action ApplyEffects {
                in audio : RawAudio;
                out enhanced : RawAudio;
            }

            action AssembleOutput {
                in gain : VolumeGain;
                in eqLow : VolumeGain;
                in eqMid : VolumeGain;
                in eqHigh : VolumeGain;
                in audio : RawAudio;
                out processed : ProcessedAudio;
            }

            flow from rawAudio to NormalizeVolume.audio;
            flow from targetLoudness to NormalizeVolume.target;
            flow from rawAudio to ApplyEqualization.audio;
            flow from eqLowGain to ApplyEqualization.lowGain;
            flow from eqMidGain to ApplyEqualization.midGain;
            flow from eqHighGain to ApplyEqualization.highGain;
            flow from rawAudio to ApplyEffects.audio;
            flow from NormalizeVolume.gain to AssembleOutput.gain;
            flow from ApplyEqualization.eqLow to AssembleOutput.eqLow;
            flow from ApplyEqualization.eqMid to AssembleOutput.eqMid;
            flow from ApplyEqualization.eqHigh to AssembleOutput.eqHigh;
            flow from ApplyEffects.enhanced to AssembleOutput.audio;
            flow from AssembleOutput.processed to processed;
        }

        state processorStateMachine {
            entry; then Passive;
            state Passive;
            transition from Passive to Processing
                when inPort.audio is received;
            state Processing {
                entry do ProcessAudio;
            }
            transition from Processing to Passive
                when outPort.audio is sent;
        }
    }

    part def PlaybackController {
        port transitionPort : TransitionPort;
        port inPort : AudioInPort;
        port outPort : AudioOutPort;
        port controlPort : ControlPort;

        attribute currentTrack : Track;
        attribute nextTrack : Track;
        attribute currentPosition : Timestamp;
        attribute currentPlan : TransitionPlan;
        attribute volume : VolumeGain = 1.0;

        action def PlayTrack {
            in track : Track;
            in position : Timestamp;
            out audio : RawAudio;
        }

        action def PausePlayback {
            in position : Timestamp;
            out pausedPosition : Timestamp;
        }

        action def StopPlayback {
            out finalPosition : Timestamp;
        }

        action def ExecuteTransition {
            in plan : TransitionPlan;
            in outgoingAudio : RawAudio;
            in incomingAudio : RawAudio;
            out mixedAudio : RawAudio;
            // Perform crossfade using beat-matched alignment
        }

        state playbackStateMachine {
            entry; then Stopped;
            state Stopped {
                entry do StopPlayback;
            }
            transition from Stopped to Playing
                when controlPort.command == "play";
            state Playing {
                entry do PlayTrack;
            }
            transition from Playing to Paused
                when controlPort.command == "pause";
            state Paused {
                entry do PausePlayback;
            }
            transition from Paused to Playing
                when controlPort.command == "resume";
            transition from Playing to Transitioning
                when currentPosition >= (currentTrack.audio.duration - currentPlan.crossfadeDuration);
            state Transitioning {
                entry do ExecuteTransition;
            }
            transition from Transitioning to Playing
                when transitionPort.plan is received;
            transition from Playing to Stopped
                when controlPort.command == "stop";
            transition from Paused to Stopped
                when controlPort.command == "stop";
        }
    }

    part def AutomationOrchestrator {
        port libraryControl : ControlPort;
        port analysisControl : ControlPort;
        port generatorControl : ControlPort;
        port transitionControl : ControlPort;
        port processorControl : ControlPort;
        port playbackControl : ControlPort;

        attribute activePlaylist : Playlist;
        attribute currentIndex : Integer = 0;
        attribute sessionActive : Boolean = false;

        action def StartSession {
            in preferences : UserPreferences;

            action RequestPlaylist {
                in prefs : UserPreferences;
                out playlist : Playlist;
            }

            action LoadFirstTrack {
                in playlist : Playlist;
                out track : Track;
            }

            action BeginPlayback {
                in track : Track;
            }

            flow from preferences to RequestPlaylist.prefs;
            flow from RequestPlaylist.playlist to LoadFirstTrack.playlist;
            flow from LoadFirstTrack.track to BeginPlayback.track;
        }

        action def AdvanceToNextTrack {
            in playlist : Playlist;
            in currentIndex : Integer;
            out nextTrack : Track;

            action SelectNextTrack {
                in playlist : Playlist;
                in index : Integer;
                out track : Track;
            }

            action RequestTransition {
                in currentTrack : Track;
                in nextTrack : Track;
                out plan : TransitionPlan;
            }

            flow from playlist to SelectNextTrack.playlist;
            flow from currentIndex to SelectNextTrack.index;
            flow from SelectNextTrack.track to nextTrack;
        }

        action def EndSession {
            // Stop playback, clear playlist
        }

        state orchestratorStateMachine {
            entry; then Inactive;
            state Inactive;
            transition from Inactive to Initializing
                when libraryControl.command == "startSession";
            state Initializing {
                entry do StartSession;
            }
            transition from Initializing to Active
                when playbackControl.status == "playing";
            state Active;
            transition from Active to Advancing
                when playbackControl.status == "transitioning";
            state Advancing {
                entry do AdvanceToNextTrack;
            }
            transition from Advancing to Active
                when playbackControl.status == "playing";
            transition from Active to ShuttingDown
                when libraryControl.command == "endSession";
            transition from Advancing to ShuttingDown
                when libraryControl.command == "endSession";
            state ShuttingDown {
                entry do EndSession;
            }
            transition from ShuttingDown to Inactive
                when playbackControl.status == "stopped";
        }
    }

    // ---- Top-Level System ----

    part def DJStreamingSystem {
        part library : MusicLibrary;
        part analysisEngine : AnalysisEngine;
        part playlistGenerator : PlaylistGenerator;
        part transitionEngine : TransitionEngine;
        part audioProcessor : AudioProcessor;
        part playbackController : PlaybackController;
        part orchestrator : AutomationOrchestrator;

        // Connections between components
        connection def LibraryToGenerator {
            end libraryQuery : TrackQueryPort;
            end generatorQuery : TrackQueryPort;
        }

        connection libraryToGenerator : LibraryToGenerator
            connect library.queryPort to playlistGenerator.queryPort;

        connection def GeneratorToOrchestrator {
            end generatorPlaylist : PlaylistPort;
            end orchestratorPlaylist : PlaylistPort;
        }

        connection generatorToOrchestrator : GeneratorToOrchestrator
            connect playlistGenerator.playlistPort to orchestrator.libraryControl;

        connection def TransitionToPlayback {
            end engineTransition : TransitionPort;
            end controllerTransition : TransitionPort;
        }

        connection transitionToPlayback : TransitionToPlayback
            connect transitionEngine.transitionPort to playbackController.transitionPort;

        connection def PlaybackToProcessor {
            end playbackOut : AudioOutPort;
            end processorIn : AudioInPort;
        }

        connection playbackToProcessor : PlaybackToProcessor
            connect playbackController.outPort to audioProcessor.inPort;

        connection def ProcessorToOutput {
            end processorOut : AudioOutPort;
            end systemOut : AudioOutPort;
        }

        connection processorToOutput : ProcessorToOutput
            connect audioProcessor.outPort to playbackController.inPort;

        // Control connections from orchestrator
        connection orchestratorToLibrary : ControlInterface
            connect orchestrator.libraryControl to library.controlPort;

        connection orchestratorToAnalysis : ControlInterface
            connect orchestrator.analysisControl to analysisEngine.controlPort;

        connection orchestratorToGenerator : ControlInterface
            connect orchestrator.generatorControl to playlistGenerator.controlPort;

        connection orchestratorToTransition : ControlInterface
            connect orchestrator.transitionControl to transitionEngine.controlPort;

        connection orchestratorToProcessor : ControlInterface
            connect orchestrator.processorControl to audioProcessor.controlPort;

        connection orchestratorToPlayback : ControlInterface
            connect orchestrator.playbackControl to playbackController.controlPort;

        // Analysis to Library connection
        connection def AnalysisToLibrary {
            end analysisOut : AnalysisRequestPort;
            end libraryIn : AnalysisRequestPort;
        }

        // System-level external output port
        port systemOutput : AudioOutPort;
    }

    // ---- Requirements ----

    requirement def ContinuousMixRequirement {
        doc /* The system shall produce a continuous, seamless mix of music with no audible gaps between tracks. */
        subject djSystem : DJStreamingSystem;
        requirement {
            subject transitionEngine : TransitionEngine;
            doc /* The transition engine shall crossfade between consecutive tracks with a duration between 4 and 12 seconds. */
            constraint { crossfadeDuration >= 4.0 [s] and crossfadeDuration <= 12.0 [s] }
        }
    }

    requirement def BeatMatchingRequirement {
        doc /* The transition engine shall beat-match outgoing and incoming tracks to align their tempos within 2 BPM. */
        subject transitionEngine : TransitionEngine;
        constraint { |outgoingTrack.tempo - incomingTrack.tempo| <= 2.0 [bpm] }
    }

    requirement def AnalysisAccuracyRequirement {
        doc /* The analysis engine shall determine tempo with accuracy within 1 BPM of ground truth. */
        subject analysisEngine : AnalysisEngine;
        constraint { |detectedTempo - actualTempo| <= 1.0 [bpm] }
    }

    requirement def PlaylistFlowRequirement {
        doc /* The playlist generator shall arrange tracks so that consecutive tracks have compatible musical keys and smoothly varying tempo. */
        subject playlistGenerator : PlaylistGenerator;
        constraint {
            for all i in playlist.tracks.indices {
                |playlist.tracks[i].tempo - playlist.tracks[i+1].tempo| <= 10.0 [bpm]
            }
        }
    }

    requirement def LoudnessNormalizationRequirement {
        doc /* The audio processor shall normalize all tracks to a target loudness of -14 dBFS +/- 1 dB. */
        subject audioProcessor : AudioProcessor;
        constraint { processed.loudness >= -15.0 [dBFS] and processed.loudness <= -13.0 [dBFS] }
    }

    requirement def PlaybackControlRequirement {
        doc /* The playback controller shall support play, pause, stop, and transition states with no audible artifacts. */
        subject playbackController : PlaybackController;
        constraint { playbackController.stateMachine.states includes {"Playing", "Paused", "Stopped", "Transitioning"} }
    }

    requirement def OrchestrationRequirement {
        doc /* The automation orchestrator shall coordinate all components to manage continuous mixed playback from session start to end. */
        subject orchestrator : AutomationOrchestrator;
        constraint { orchestrator.stateMachine.states includes {"Inactive", "Initializing", "Active", "Advancing", "ShuttingDown"} }
    }

    requirement def UserPreferenceTailoringRequirement {
        doc /* The system shall tailor playlists to user-specified genre, mood, and energy level. */
        subject djSystem : DJStreamingSystem;
        constraint {
            playlist.targetGenre == preferences.desiredGenre
            and playlist.targetMood == preferences.desiredMood
            and |playlist.targetEnergy - preferences.desiredEnergy| <= 0.1
        }
    }

    requirement def LibraryCompletenessRequirement {
        doc /* Every track in the library shall have complete musical characteristics including tempo, key, energy, danceability, loudness, and beat grid. */
        subject library : MusicLibrary;
        constraint {
            for all track in library.tracks {
                track.tempo is not null
                and track.key is not null
                and track.energy is not null
                and track.danceability is not null
                and track.loudness is not null
                and track.beatGrid is not null
            }
        }
    }

    // ---- Requirement Satisfaction ----

    satisfaction satisfyContinuousMix : ContinuousMixRequirement satisfy djSystem;
    satisfaction satisfyBeatMatching : BeatMatchingRequirement satisfy transitionEngine;
    satisfaction satisfyAnalysisAccuracy : AnalysisAccuracyRequirement satisfy analysisEngine;
    satisfaction satisfyPlaylistFlow : PlaylistFlowRequirement satisfy playlistGenerator;
    satisfaction satisfyLoudness : LoudnessNormalizationRequirement satisfy audioProcessor;
    satisfaction satisfyPlayback : PlaybackControlRequirement satisfy playbackController;
    satisfaction satisfyOrchestration : OrchestrationRequirement satisfy orchestrator;
    satisfaction satisfyUserPrefs : UserPreferenceTailoringRequirement satisfy djSystem;
    satisfaction satisfyLibrary : LibraryCompletenessRequirement satisfy library;

}
