package TinnitracksSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQDuration::*;
    import ISQFrequency::*;

    // ===== Value Types =====
    value type TinnitusFrequencyValue :> Real { 
        unit Hz; 
        doc "User-specific tinnitus pitch frequency.";
    }
    value type NotchBandwidthValue :> Real { 
        unit Hz; 
        doc "Half-width of the notch filter band.";
    }
    value type VolumeLevelValue :> Real { 
        unit dB; 
        doc "Sound pressure level in decibels.";
    }
    value type SafeMaxVolumeValue :> Real { 
        unit dB; 
        doc "Maximum safe output volume threshold.";
        default 85.0;
    }
    value type SessionDurationValue :> Real { 
        unit min; 
        doc "Duration of a therapy session.";
    }
    value type FrequencyPrecisionValue :> Real { 
        unit Hz; 
        doc "Precision of frequency detection.";
    }
    value type FilterAttenuationValue :> Real { 
        unit dB; 
        doc "Attenuation depth of the notch filter.";
    }
    value type SampleRateValue :> Real { 
        unit Hz; 
        doc "Audio sample rate.";
    }

    // ===== Item Types =====
    item def RawAudioSignal {
        attribute sampleRate : SampleRateValue;
        attribute channelCount : Integer;
        attribute samples : Real[0..*];
    }
    item def ProcessedAudioSignal {
        attribute sampleRate : SampleRateValue;
        attribute channelCount : Integer;
        attribute samples : Real[0..*];
        attribute notchCenter : TinnitusFrequencyValue;
        attribute notchBandwidth : NotchBandwidthValue;
    }
    item def TestTone {
        attribute frequency : TinnitusFrequencyValue;
        attribute amplitude : VolumeLevelValue;
    }
    item def MusicTrack {
        attribute trackId : String;
        attribute title : String;
        attribute artist : String;
        attribute duration : SessionDurationValue;
        attribute rawAudio : RawAudioSignal;
    }
    item def TinnitusProfile {
        attribute profileId : String;
        attribute tinnitusFrequency : TinnitusFrequencyValue;
        attribute notchBandwidth : NotchBandwidthValue;
        attribute filterAttenuation : FilterAttenuationValue;
        attribute createdAt : String;
    }
    item def TherapySessionConfig {
        attribute sessionId : String;
        attribute duration : SessionDurationValue;
        attribute targetVolume : VolumeLevelValue;
        attribute selectedTrackId : String;
        attribute profileId : String;
    }

    // ===== Port Definitions =====
    port def AudioOutPort {
        out audio : ProcessedAudioSignal;
    }
    port def AudioInPort {
        in audio : RawAudioSignal;
    }
    port def ProcessedAudioInPort {
        in audio : ProcessedAudioSignal;
    }
    port def TestToneOutPort {
        out tone : TestTone;
    }
    port def ProfileOutPort {
        out profile : TinnitusProfile;
    }
    port def ProfileInPort {
        in profile : TinnitusProfile;
    }
    port def TrackOutPort {
        out track : MusicTrack;
    }
    port def TrackInPort {
        in track : MusicTrack;
    }
    port def SessionConfigOutPort {
        out config : TherapySessionConfig;
    }
    port def SessionConfigInPort {
        in config : TherapySessionConfig;
    }
    port def CommandPort {
        out command : String;
    }
    port def CommandInPort {
        in command : String;
    }

    // ===== Parts =====
    part def FrequencyAnalyzer {
        port testToneOut : TestToneOutPort;
        port profileOut : ProfileOutPort;
        port commandIn : CommandInPort;

        attribute currentFrequency : TinnitusFrequencyValue;
        attribute frequencyPrecision : FrequencyPrecisionValue := 1.0;
        attribute minFrequency : TinnitusFrequencyValue := 100.0;
        attribute maxFrequency : TinnitusFrequencyValue := 16000.0;

        action determineTinnitusFrequency {
            in testTone : TestTone;
            out detectedFrequency : TinnitusFrequencyValue;
            
            // Binary search approach: user responds to tones
            perform {
                // Generate test tone at candidate frequency
                // User confirms match
                // Record frequency
            }
        }

        action createProfile {
            in frequency : TinnitusFrequencyValue;
            out profile : TinnitusProfile;
        }

        state analyzerBehavior {
            entry { send "analyzer_ready" to commandIn; }
            state Idle;
            state GeneratingTone {
                entry { /* generate test tone */ }
                do { /* play tone to user */ }
            }
            state AwaitingUserResponse {
                do { /* wait for user confirmation */ }
            }
            state ProfileCreated {
                entry { /* emit profile */ }
            }
            transition Idle to GeneratingTone 
                when commandIn.command == "start_analysis";
            transition GeneratingTone to AwaitingUserResponse 
                when true;
            transition AwaitingUserResponse to GeneratingTone 
                when commandIn.command == "next_tone";
            transition AwaitingUserResponse to ProfileCreated 
                when commandIn.command == "confirm_frequency";
            transition ProfileCreated to Idle 
                when commandIn.command == "reset";
        }
    }

    part def MusicLibrary {
        port trackOut : TrackOutPort;
        port commandIn : CommandInPort;

        attribute tracks : MusicTrack[0..*];
        attribute libraryCapacity : Integer := 1000;

        action retrieveTrack {
            in trackId : String;
            out track : MusicTrack;
        }

        action addTrack {
            in track : MusicTrack;
        }

        action removeTrack {
            in trackId : String;
        }

        state libraryBehavior {
            state Idle;
            state Retrieving {
                do { /* fetch track by ID */ }
            }
            state Updating {
                do { /* add or remove track */ }
            }
            transition Idle to Retrieving 
                when commandIn.command == "get_track";
            transition Retrieving to Idle 
                when true;
            transition Idle to Updating 
                when commandIn.command == "add_track" or commandIn.command == "remove_track";
            transition Updating to Idle 
                when true;
        }
    }

    part def NotchFilterProcessor {
        port trackIn : TrackInPort;
        port profileIn : ProfileInPort;
        port audioOut : AudioOutPort;
        port commandIn : CommandInPort;

        attribute sampleRate : SampleRateValue := 44100.0;
        attribute filterOrder : Integer := 4;
        attribute currentProfile : TinnitusProfile;

        action applyNotchFilter {
            in rawAudio : RawAudioSignal;
            in profile : TinnitusProfile;
            out processedAudio : ProcessedAudioSignal;
            
            // Apply digital notch filter centered on tinnitus frequency
            // with specified bandwidth and attenuation
        }

        action streamProcessedAudio {
            in processedAudio : ProcessedAudioSignal;
            out audioStream : ProcessedAudioSignal;
        }

        state processorBehavior {
            state Idle;
            state Configured {
                entry { /* store profile */ }
            }
            state Processing {
                do { /* real-time notch filtering */ }
            }
            state Streaming {
                do { /* stream processed audio */ }
            }
            transition Idle to Configured 
                when profileIn.profile is received;
            transition Configured to Processing 
                when trackIn.track is received;
            transition Processing to Streaming 
                when true;
            transition Streaming to Processing 
                when trackIn.track is received;
            transition Streaming to Idle 
                when commandIn.command == "stop";
            transition Processing to Idle 
                when commandIn.command == "stop";
        }
    }

    part def TherapyController {
        port sessionConfigOut : SessionConfigOutPort;
        port profileIn : ProfileInPort;
        port commandOut : CommandPort;
        port commandIn : CommandInPort;

        attribute sessionDuration : SessionDurationValue := 60.0;
        attribute maxSafeVolume : SafeMaxVolumeValue := 85.0;
        attribute currentSession : TherapySessionConfig;
        attribute elapsedTime : SessionDurationValue;
        attribute activeProfile : TinnitusProfile;

        action startSession {
            in config : TherapySessionConfig;
            out startCommand : String;
        }

        action stopSession {
            out stopCommand : String;
        }

        action monitorDuration {
            in duration : SessionDurationValue;
            out sessionComplete : Boolean;
        }

        action validateVolume {
            in requestedVolume : VolumeLevelValue;
            out safeVolume : VolumeLevelValue;
            
            // Ensure volume does not exceed safe threshold
            if requestedVolume > maxSafeVolume {
                safeVolume := maxSafeVolume;
            } else {
                safeVolume := requestedVolume;
            }
        }

        state controllerBehavior {
            entry { elapsedTime := 0.0; }
            state Idle;
            state ProfileLoaded {
                entry { /* store profile */ }
            }
            state SessionActive {
                entry { send "start" to commandOut; }
                do { /* monitor elapsed time */ }
            }
            state Paused {
                do { /* hold session */ }
            }
            state SessionComplete {
                entry { send "stop" to commandOut; }
            }
            transition Idle to ProfileLoaded 
                when profileIn.profile is received;
            transition ProfileLoaded to SessionActive 
                when commandIn.command == "start_session";
            transition SessionActive to Paused 
                when commandIn.command == "pause";
            transition Paused to SessionActive 
                when commandIn.command == "resume";
            transition SessionActive to SessionComplete 
                when elapsedTime >= sessionDuration;
            transition SessionActive to SessionComplete 
                when commandIn.command == "stop_session";
            transition SessionComplete to Idle 
                when commandIn.command == "reset";
        }
    }

    part def AudioOutputDevice {
        port audioIn : ProcessedAudioInPort;
        port commandIn : CommandInPort;

        attribute outputVolume : VolumeLevelValue;
        attribute maxVolume : SafeMaxVolumeValue := 85.0;
        attribute isConnected : Boolean;

        action playAudio {
            in audio : ProcessedAudioSignal;
        }

        action setVolume {
            in requestedVolume : VolumeLevelValue;
            out actualVolume : VolumeLevelValue;
        }

        action stopPlayback {
        }

        state outputBehavior {
            state Idle;
            state Playing {
                do { /* output processed audio to user */ }
            }
            state Muted {
                do { /* no output */ }
            }
            transition Idle to Playing 
                when audioIn.audio is received;
            transition Playing to Muted 
                when commandIn.command == "mute";
            transition Muted to Playing 
                when commandIn.command == "unmute";
            transition Playing to Idle 
                when commandIn.command == "stop";
            transition Muted to Idle 
                when commandIn.command == "stop";
        }
    }

    // ===== Top-level System =====
    part def TinnitracksTherapeuticAudioSystem {
        port userCommandIn : CommandInPort;
        port testToneOut : TestToneOutPort;
        port audioOut : AudioOutPort;

        part frequencyAnalyzer : FrequencyAnalyzer {
            port testToneOut : TestToneOutPort;
            port profileOut : ProfileOutPort;
            port commandIn : CommandInPort;
        }
        
        part musicLibrary : MusicLibrary {
            port trackOut : TrackOutPort;
            port commandIn : CommandInPort;
        }
        
        part notchFilterProcessor : NotchFilterProcessor {
            port trackIn : TrackInPort;
            port profileIn : ProfileInPort;
            port audioOut : AudioOutPort;
            port commandIn : CommandInPort;
        }
        
        part therapyController : TherapyController {
            port sessionConfigOut : SessionConfigOutPort;
            port profileIn : ProfileInPort;
            port commandOut : CommandPort;
            port commandIn : CommandInPort;
        }
        
        part audioOutputDevice : AudioOutputDevice {
            port audioIn : ProcessedAudioInPort;
            port commandIn : CommandInPort;
        }

        // Internal connections
        connection frequencyAnalyzer_profileOut to notchFilterProcessor_profileIn : ProfileOutPort connects 
            frequencyAnalyzer.profileOut to notchFilterProcessor.profileIn;
        
        connection frequencyAnalyzer_profileOut_to_controller : ProfileOutPort connects 
            frequencyAnalyzer.profileOut to therapyController.profileIn;
        
        connection musicLibrary_trackOut to notchFilterProcessor_trackIn : TrackOutPort connects 
            musicLibrary.trackOut to notchFilterProcessor.trackIn;
        
        connection notchFilterProcessor_audioOut to audioOutputDevice_audioIn : AudioOutPort connects 
            notchFilterProcessor.audioOut to audioOutputDevice.audioIn;
        
        connection therapyController_commandOut_to_analyzer : CommandPort connects 
            therapyController.commandOut to frequencyAnalyzer.commandIn;
        
        connection therapyController_commandOut_to_library : CommandPort connects 
            therapyController.commandOut to musicLibrary.commandIn;
        
        connection therapyController_commandOut_to_processor : CommandPort connects 
            therapyController.commandOut to notchFilterProcessor.commandIn;
        
        connection therapyController_commandOut_to_output : CommandPort connects 
            therapyController.commandOut to audioOutputDevice.commandIn;
        
        // External port bindings
        bind userCommandIn to therapyController.commandIn;
        bind testToneOut to frequencyAnalyzer.testToneOut;
        bind audioOut to notchFilterProcessor.audioOut;

        // System-level behavior
        state systemBehavior {
            state PoweredOff;
            state Initializing {
                do { /* boot up all components */ }
            }
            state Ready;
            state Analyzing {
                do { /* frequency analysis phase */ }
            }
            state TherapyActive {
                do { /* therapy session running */ }
            }
            state ShuttingDown {
                do { /* graceful shutdown */ }
            }
            transition PoweredOff to Initializing 
                when userCommandIn.command == "power_on";
            transition Initializing to Ready 
                when true;
            transition Ready to Analyzing 
                when userCommandIn.command == "start_analysis";
            transition Analyzing to Ready 
                when frequencyAnalyzer.profileOut.profile is received;
            transition Ready to TherapyActive 
                when userCommandIn.command == "start_therapy";
            transition TherapyActive to Ready 
                when userCommandIn.command == "stop_therapy";
            transition Ready to ShuttingDown 
                when userCommandIn.command == "power_off";
            transition ShuttingDown to PoweredOff 
                when true;
        }
    }

    // ===== Requirements =====
    requirement def TinnitusReliefRequirement {
        doc "The system shall reduce perceived tinnitus loudness through personalized notch-filtered music therapy.";
        attribute targetReduction : Real := 30.0; // percentage
        attribute therapyPeriodWeeks : Integer := 12;
    }

    requirement def FrequencyAnalysisRequirement {
        doc "The system shall determine the user's tinnitus frequency with high precision.";
        attribute frequencyRange : TinnitusFrequencyValue := 100.0;
        attribute frequencyRangeMax : TinnitusFrequencyValue := 16000.0;
        attribute precision : FrequencyPrecisionValue := 1.0;
        attribute maxAnalysisTime : SessionDurationValue := 15.0;
    }

    requirement def NotchFilterRequirement {
        doc "The system shall apply a narrow notch filter centered on the user's tinnitus frequency.";
        attribute minBandwidth : NotchBandwidthValue := 50.0;
        attribute maxBandwidth : NotchBandwidthValue := 500.0;
        attribute minAttenuation : FilterAttenuationValue := 30.0;
        attribute maxSignalDelay : Real := 20.0; // ms
    }

    requirement def SafetyRequirement {
        doc "The system shall ensure output volume never exceeds safe hearing levels.";
        attribute maxSafeOutput : SafeMaxVolumeValue := 85.0;
        attribute warningThreshold : VolumeLevelValue := 80.0;
    }

    requirement def SessionManagementRequirement {
        doc "The system shall manage therapy sessions with configurable duration.";
        attribute minDuration : SessionDurationValue := 30.0;
        attribute maxDuration : SessionDurationValue := 120.0;
        attribute defaultDuration : SessionDurationValue := 60.0;
    }

    requirement def AudioQualityRequirement {
        doc "The system shall maintain overall music quality during filtering.";
        attribute minSampleRate : SampleRateValue := 44100.0;
        attribute minBitDepth : Integer := 16;
        attribute maxTotalHarmonicDistortion : Real := 0.01;
    }

    requirement tinnitusReliefReq : TinnitusReliefRequirement {
        subject TinnitracksTherapeuticAudioSystem;
    }
    requirement frequencyAnalysisReq : FrequencyAnalysisRequirement {
        subject FrequencyAnalyzer;
    }
    requirement notchFilterReq : NotchFilterRequirement {
        subject NotchFilterProcessor;
    }
    requirement safetyReq : SafetyRequirement {
        subject AudioOutputDevice;
    }
    requirement sessionMgmtReq : SessionManagementRequirement {
        subject TherapyController;
    }
    requirement audioQualityReq : AudioQualityRequirement {
        subject NotchFilterProcessor;
    }

    // ===== Verification =====
    verification verifyFrequencyAnalysis : FrequencyAnalysisRequirement {
        subject FrequencyAnalyzer;
        objective {
            doc "Verify that the frequency analyzer can detect tinnitus frequencies within the specified range and precision.";
        }
        method {
            doc "Conduct frequency sweep tests with known reference tones and measure detection accuracy.";
        }
    }

    verification verifyNotchFilter : NotchFilterRequirement {
        subject NotchFilterProcessor;
        objective {
            doc "Verify that the notch filter attenuates the correct frequency band with required depth.";
        }
        method {
            doc "Apply filter to test signals and measure frequency response using spectrum analyzer.";
        }
    }

    verification verifySafetyLimit : SafetyRequirement {
        subject AudioOutputDevice;
        objective {
            doc "Verify that output volume is clamped to safe levels under all conditions.";
        }
        method {
            doc "Inject high-volume requests and measure actual output with sound level meter.";
        }
    }
}
