package PopMusicAutomationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BPMValue :> Real;
	attribute def LoudnessValue :> Real;
	
	item def AudioSignal {
		attribute sampleRate : FrequencyValue;
		attribute bitDepth : Integer;
		attribute channels : Integer;
		attribute duration : TimeValue;
	}
	
	item def MusicTrack {
		attribute trackID : String;
		attribute title : String;
		attribute artist : String;
		attribute genre : String;
		attribute tempo : BPMValue;
		attribute key : String;
		attribute energy : Real;
		attribute danceability : Real;
		attribute duration : TimeValue;
		attribute loudness : LoudnessValue;
	}
	
	item def Playlist {
		attribute playlistID : String;
		attribute tracks : MusicTrack[1..*];
		attribute totalDuration : TimeValue;
		attribute averageTempo : BPMValue;
		attribute transitionSmoothing : Real;
	}
	
	item def UserPreferences {
		attribute preferredGenres : String[*];
		attribute targetTempo : BPMValue;
		attribute energyLevel : Real;
		attribute playlistDuration : TimeValue;
	}
	
	port def AudioInputPort {
		in item audioIn : AudioSignal;
	}
	
	port def AudioOutputPort {
		out item audioOut : AudioSignal;
	}
	
	port def TrackDataPort {
		in item trackData : MusicTrack;
	}
	
	port def PlaylistPort {
		out item playlistOut : Playlist;
	}
	
	port def ControlPort {
		in attribute command : String;
		out attribute status : String;
	}
	
	part def MusicLibrary {
		port tracksOut : TrackDataPort[*];
		
		attribute catalogSize : Integer;
		attribute genres : String[*];
		
		action queryTracks {
			in criteria : UserPreferences;
			out matchingTracks : MusicTrack[*];
		}
	}
	
	part def AnalysisEngine {
		port tracksIn : TrackDataPort[*];
		
		attribute analysisAlgorithm : String;
		
		action analyzeMusicFeatures {
			in track : MusicTrack;
			out tempo : BPMValue;
			out key : String;
			out energy : Real;
			out danceability : Real;
		}
		
		action detectBeatGrid {
			in track : MusicTrack;
			out beatPositions : TimeValue[*];
		}
	}
	
	part def PlaylistGenerator {
		port preferencesIn : ControlPort;
		port tracksIn : TrackDataPort[*];
		port playlistOut : PlaylistPort;
		
		attribute selectionStrategy : String;
		attribute diversityFactor : Real;
		
		action selectTracks {
			in preferences : UserPreferences;
			in availableTracks : MusicTrack[*];
			out selectedTracks : MusicTrack[*];
		}
		
		action optimizeSequence {
			in tracks : MusicTrack[*];
			out orderedTracks : MusicTrack[*];
		}
		
		action createPlaylist {
			in prefs : UserPreferences;
			in library : MusicTrack[*];
			out playlist : Playlist;
			
			first start;
			then action select : selectTracks {
				in preferences = prefs;
				in availableTracks = library;
				out selectedTracks;
			}
			then action optimize : optimizeSequence {
				in tracks = select.selectedTracks;
				out orderedTracks;
			}
			then action assemble {
				in orderedTracks = optimize.orderedTracks;
				out finalPlaylist : Playlist;
			}
			then done;
		}
	}
	
	part def TransitionEngine {
		port trackAIn : AudioInputPort;
		port trackBIn : AudioInputPort;
		port mixedOut : AudioOutputPort;
		
		attribute crossfadeType : String;
		attribute beatMatching : Boolean;
		
		action calculateTransition {
			in trackA : MusicTrack;
			in trackB : MusicTrack;
			out transitionPoint : TimeValue;
			out crossfadeDuration : TimeValue;
		}
		
		action applyBeatMatching {
			in sourceTrack : AudioSignal;
			in targetTempo : BPMValue;
			out adjustedTrack : AudioSignal;
		}
		
		action crossfade {
			in trackA : AudioSignal;
			in trackB : AudioSignal;
			in duration : TimeValue;
			out blendedAudio : AudioSignal;
		}
	}
	
	part def AudioProcessor {
		port audioIn : AudioInputPort;
		port audioOut : AudioOutputPort;
		
		attribute eqBands : Integer;
		attribute compressionRatio : Real;
		attribute limiterThreshold : LoudnessValue;
		
		action normalizeVolume {
			in audio : AudioSignal;
			in targetLoudness : LoudnessValue;
			out normalizedAudio : AudioSignal;
		}
		
		action applyEQ {
			in audio : AudioSignal;
			in eqSettings : String;
			out processedAudio : AudioSignal;
		}
		
		action applyEffects {
			in audio : AudioSignal;
			in effectsChain : String[*];
			out effectiveAudio : AudioSignal;
		}
	}
	
	part def PlaybackController {
		port controlIn : ControlPort;
		port audioOut : AudioOutputPort;
		
		attribute currentTrackIndex : Integer;
		attribute playbackPosition : TimeValue;
		attribute isPlaying : Boolean;
		
		state def PlaybackStates {
			entry; then idle;
			
			state idle {
				entry assign isPlaying := false;
			}
			transition idle_to_loading
				first idle
				then loading;
			
			state loading {
				entry assign currentTrackIndex := 0;
			}
			transition loading_to_playing
				first loading
				then playing;
			
			state playing {
				entry assign isPlaying := true;
			}
			transition playing_to_transitioning
				first playing
				then transitioning;
			
			transition playing_to_paused
				first playing
				then paused;
			
			state transitioning {
				entry assign playbackPosition := 0.0;
			}
			transition transitioning_to_playing
				first transitioning
				then playing;
			
			state paused {
				entry assign isPlaying := false;
			}
			transition paused_to_playing
				first paused
				then playing;
			
			transition paused_to_stopped
				first paused
				then stopped;
			
			transition playing_to_stopped
				first playing
				then stopped;
			
			state stopped {
				entry assign isPlaying := false;
				entry assign playbackPosition := 0.0;
			}
			transition stopped_to_idle
				first stopped
				then idle;
		}
		
		action playTrack {
			in track : MusicTrack;
			out audio : AudioSignal;
		}
		
		action handleTransition {
			in currentTrack : MusicTrack;
			in nextTrack : MusicTrack;
			out transitionedAudio : AudioSignal;
		}
	}
	
	part def AutomationOrchestrator {
		port userInput : ControlPort;
		port audioOutput : AudioOutputPort;
		
		attribute automationMode : String;
		attribute adaptiveMixing : Boolean;
		
		action orchestratePlayback {
			in preferences : UserPreferences;
			out continuousAudio : AudioSignal;
			
			first start;
			then action queryLibrary {
				in userPrefs : UserPreferences = preferences;
				out availableTracks : MusicTrack[*];
			}
			then action analyzeCollection {
				in tracks : MusicTrack[*] = queryLibrary.availableTracks;
				out analyzedTracks : MusicTrack[*];
			}
			then action generatePlaylist {
				in prefs : UserPreferences = preferences;
				in tracks : MusicTrack[*] = analyzeCollection.analyzedTracks;
				out playlist : Playlist;
			}
			then merge playbackLoop;
			
			action playbackLoop {
				action loadTrack {
					in playlist : Playlist = generatePlaylist.playlist;
					out currentTrack : MusicTrack;
				}
				then action processAudio {
					in track : MusicTrack = loadTrack.currentTrack;
					out processedAudio : AudioSignal;
				}
				then action applyTransition {
					in audio : AudioSignal = processAudio.processedAudio;
					out transitionedAudio : AudioSignal;
				}
				then decide;
					if true then playbackLoop;
			}
			
			then done;
		}
	}
	
	part def PopMusicAutomationSystem {
		part library : MusicLibrary;
		part analyzer : AnalysisEngine;
		part playlistGen : PlaylistGenerator;
		part transitioner : TransitionEngine;
		part processor : AudioProcessor;
		part playback : PlaybackController;
		part orchestrator : AutomationOrchestrator;
		
		connection libraryToAnalyzer connect 
			library.tracksOut to analyzer.tracksIn;
		
		connection libraryToPlaylistGen connect 
			library.tracksOut to playlistGen.tracksIn;
		
		connection playlistGenToPlayback connect 
			playlistGen.playlistOut to playback.controlIn;
		
		connection playbackToTransitioner connect 
			playback.audioOut to transitioner.trackAIn;
		
		connection transitionerToProcessor connect 
			transitioner.mixedOut to processor.audioIn;
		
		connection processorToOrchestrator connect 
			processor.audioOut to orchestrator.audioOutput;
		
		perform action automatePopMusic : AutomationOrchestrator::orchestratePlayback;
	}
	
	part popAutomationSystem : PopMusicAutomationSystem;
	
	requirement def PrimaryFunctionRequirement {
		doc /* The system shall automatically curate and play continuous pop music by analyzing tracks, 
		       generating optimized playlists, and seamlessly transitioning between songs. */
		
		subject popSystem : PopMusicAutomationSystem;
		
		require constraint continuousPlayback {
			doc /* The system shall maintain uninterrupted audio playback through intelligent track sequencing. */
		}
		
		require constraint seamlessTransitions {
			doc /* Track transitions shall be beat-matched and crossfaded with duration between 2-8 seconds. */
		}
	}
	
	requirement def MusicQualityRequirement {
		doc /* The system shall maintain consistent audio quality and musical coherence. */
		
		require constraint volumeNormalization {
			doc /* All tracks shall be normalized to -14 LUFS +/- 1 dB. */
		}
		
		require constraint tempoMatching {
			doc /* Adjacent tracks shall have tempo variance within 10% or be beat-matched. */
		}
		
		require constraint keyCompatibility {
			doc /* Track sequences shall prefer harmonically compatible keys. */
		}
	}
	
	requirement def UserExperienceRequirement {
		doc /* The system shall provide intuitive control and adaptive behavior. */
		
		require constraint responsiveness {
			doc /* User commands shall be executed within 500 milliseconds. */
		}
		
		require constraint adaptability {
			doc /* Playlist generation shall adapt to user preferences with 85% satisfaction rate. */
		}
	}
	
	requirement def SystemRequirement {
		doc /* The pop music automation system shall provide fully automated, high-quality continuous music playback. */
		
		assume constraint musicLibraryAvailable {
			doc /* A music library with analyzed track metadata is available. */
		}
		
		assume constraint userPreferencesProvided {
			doc /* User preferences for genre, tempo, and duration are provided. */
		}
		
		require primaryFunc : PrimaryFunctionRequirement;
		require musicQual : MusicQualityRequirement;
		require userExp : UserExperienceRequirement;
	}
}
