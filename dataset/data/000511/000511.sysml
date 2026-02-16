package TinnitracksTherapySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FrequencyHz :> ISQ::FrequencyValue;
    attribute def DecibelLevel :> Real;
    attribute def SessionDuration :> ISQ::TimeValue;
    attribute def FilterBandwidth :> ISQ::FrequencyValue;
    
    item def AudioSignal {
        attribute frequency : FrequencyHz;
        attribute amplitude : DecibelLevel;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def MusicTrack {
        attribute duration : SessionDuration;
        attribute sampleRate : FrequencyHz;
        attribute bitDepth : Real;
    }
    
    item def TinnitusProfile {
        attribute characteristicFrequency : FrequencyHz;
        attribute notchWidth : FilterBandwidth;
        attribute attenuationDepth : DecibelLevel;
    }
    
    item def TherapeuticAudio {
        attribute processedTrack : MusicTrack;
        attribute appliedProfile : TinnitusProfile;
    }
    
    port def AudioInputPort {
        in item musicIn : MusicTrack;
    }
    
    port def AudioOutputPort {
        out item audioOut : TherapeuticAudio;
    }
    
    port def ProfileInputPort {
        in item profile : TinnitusProfile;
    }
    
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }
    
    part def FrequencyAnalyzer {
        port audioIn : AudioInputPort;
        port profileOut : ProfileInputPort;
        
        attribute detectedFrequency : FrequencyHz;
        attribute confidenceLevel : Real;
        
        perform action analyzeTinnitusFrequency {
            in signal : AudioSignal;
            out tinnitusFreq : FrequencyHz;
            out confidence : Real;
        }
    }
    
    part def NotchFilterProcessor {
        port musicIn : AudioInputPort;
        port profileIn : ProfileInputPort;
        port filteredOut : AudioOutputPort;
        
        attribute centerFrequency : FrequencyHz;
        attribute bandwidth : FilterBandwidth;
        attribute attenuation : DecibelLevel;
        
        perform action applyNotchFilter {
            in inputMusic : MusicTrack;
            in filterProfile : TinnitusProfile;
            out filteredMusic : TherapeuticAudio;
        }
    }
    
    part def MusicLibrary {
        port musicOut : AudioOutputPort;
        
        attribute trackCount : Integer;
        attribute currentTrack : MusicTrack;
        
        perform action selectMusic {
            in userPreference : String;
            out selectedTrack : MusicTrack;
        }
    }
    
    part def TherapyController {
        port controlIn : ControlPort;
        port controlOut : ControlPort;
        
        attribute sessionActive : Boolean;
        attribute elapsedTime : SessionDuration;
        attribute targetDuration : SessionDuration;
        
        perform action manageTherapySession;
    }
    
    part def AudioOutputDevice {
        port audioIn : AudioInputPort;
        
        attribute outputLevel : DecibelLevel;
        attribute deviceType : String;
        
        perform action deliverAudio {
            in therapeuticAudio : TherapeuticAudio;
        }
    }
    
    action def AnalyzeTinnitusCharacteristics {
        in userInput : AudioSignal;
        out profile : TinnitusProfile;
    }
    
    action def ConfigureNotchFilter {
        in tinnitusProfile : TinnitusProfile;
        out filterParameters : TinnitusProfile;
    }
    
    action def ProcessMusicWithFilter {
        in originalMusic : MusicTrack;
        in filterConfig : TinnitusProfile;
        out therapeuticMusic : TherapeuticAudio;
    }
    
    action def DeliverTherapeuticAudio {
        in processedAudio : TherapeuticAudio;
        in sessionDuration : SessionDuration;
    }
    
    action def MonitorTherapyProgress {
        in currentTime : SessionDuration;
        in targetTime : SessionDuration;
        out progressStatus : String;
    }
    
    part def TinnitracksDevice {
        doc /*
            Tinnitracks is an innovative therapeutic audio system designed to provide 
            personalized tinnitus relief through customized music therapy.
            
            The system's primary function is to deliver therapeutic audio treatment by 
            applying a precisely tuned notch filter to music selected by the user. This 
            filter removes a narrow frequency band centered on the individual's specific 
            tinnitus frequency, creating a customized listening experience that promotes 
            neuroplastic changes and reduces tinnitus perception over time.
        */
        
        part analyzer : FrequencyAnalyzer;
        part library : MusicLibrary;
        part processor : NotchFilterProcessor;
        part controller : TherapyController;
        part outputDevice : AudioOutputDevice;
        
        connection analyzerToProcessor connect 
            analyzer.profileOut to processor.profileIn;
        
        connection libraryToProcessor connect 
            library.musicOut to processor.musicIn;
        
        connection processorToOutput connect 
            processor.filteredOut to outputDevice.audioIn;
    }
    
    part tinnitracksSystem : TinnitracksDevice {
        perform action provideTherapy {
            first start;
            
            then action assessTinnitus : AnalyzeTinnitusCharacteristics {
                in userInput : AudioSignal;
                out profile : TinnitusProfile;
            }
            
            then action configureFilter : ConfigureNotchFilter {
                in tinnitusProfile = assessTinnitus.profile;
                out filterParameters : TinnitusProfile;
            }
            
            then merge therapyLoop;
            
            then action processMusic : ProcessMusicWithFilter {
                in originalMusic : MusicTrack;
                in filterConfig = configureFilter.filterParameters;
                out therapeuticMusic : TherapeuticAudio;
            }
            
            then action deliverAudio : DeliverTherapeuticAudio {
                in processedAudio = processMusic.therapeuticMusic;
                in sessionDuration : SessionDuration;
            }
            
            then action monitorProgress : MonitorTherapyProgress {
                in currentTime : SessionDuration;
                in targetTime : SessionDuration;
                out progressStatus : String;
            }
            
            then decide;
                if monitorProgress.progressStatus == "continue" then therapyLoop;
                if monitorProgress.progressStatus == "complete" then endTherapy;
            
            action endTherapy;
            then done;
        }
    }
    
    requirement def TherapeuticEffectivenessRequirement {
        doc /*
            The system shall deliver effective tinnitus therapy through precise 
            frequency-specific audio filtering.
        */
        
        require constraint notchFilterAccuracy {
            doc /* 
                The notch filter center frequency shall match the detected tinnitus 
                frequency within ±25 Hz.
            */
        }
        
        require constraint attenuationDepth {
            doc /*
                The notch filter shall attenuate the target frequency by at least 
                40 dB while maintaining adjacent frequencies within 3 dB of original levels.
            */
        }
        
        require constraint bandwidthPrecision {
            doc /*
                The notch filter bandwidth shall be adjustable between 50 Hz and 500 Hz 
                to accommodate individual tinnitus characteristics.
            */
        }
    }
    
    requirement def SafetyRequirement {
        doc /*
            The system shall ensure safe audio delivery to prevent hearing damage 
            during therapy sessions.
        */
        
        require constraint maximumOutputLevel {
            doc /*
                The maximum audio output level shall not exceed 85 dB SPL to prevent 
                noise-induced hearing damage.
            */
        }
        
        require constraint gradualVolumeControl {
            doc /*
                Volume changes shall be gradual with a maximum rate of 10 dB per second 
                to prevent acoustic shock.
            */
        }
    }
    
    requirement def UsabilityRequirement {
        doc /*
            The system shall provide an intuitive and comfortable user experience 
            for therapy sessions.
        */
        
        require constraint sessionDurationFlexibility {
            doc /*
                Therapy sessions shall be configurable between 15 and 120 minutes 
                to accommodate user preferences and schedules.
            */
        }
        
        require constraint audioQuality {
            doc /*
                The filtering process shall maintain music quality with total harmonic 
                distortion below 0.1% outside the notch frequency band.
            */
        }
        
        require constraint processingLatency {
            doc /*
                Audio processing latency shall not exceed 20 milliseconds to ensure 
                real-time playback without perceptible delay.
            */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /*
            The system shall operate reliably and efficiently throughout therapy sessions.
        */
        
        require constraint frequencyAnalysisAccuracy {
            doc /*
                Tinnitus frequency detection shall achieve 95% accuracy within the 
                range of 250 Hz to 12 kHz.
            */
        }
        
        require constraint continuousOperation {
            doc /*
                The system shall operate continuously for sessions up to 2 hours 
                without degradation in performance.
            */
        }
    }
    
    requirement tinnitracksSystemRequirements {
        doc /*
            Top-level requirements for the Tinnitracks therapeutic audio system 
            ensuring effective, safe, and user-friendly tinnitus treatment.
        */
        
        require therapeuticEffectiveness : TherapeuticEffectivenessRequirement;
        require safety : SafetyRequirement;
        require usability : UsabilityRequirement;
        require performance : PerformanceRequirement;
    }
}
