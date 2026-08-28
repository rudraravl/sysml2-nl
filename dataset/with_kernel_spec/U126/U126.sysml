package TinnitracksTherapeuticAudioSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def FrequencyValue :> Real;
    attribute def BandwidthValue :> Real;
    attribute def DurationValue :> Real;
    attribute def SoundPressureLevelValue :> Real;

    item def TestTone {
        attribute frequency : FrequencyValue;
    }

    item def TinnitusProfile {
        attribute tinnitusFrequency : FrequencyValue;
        attribute notchBandwidth : BandwidthValue;
    }

    item def MusicTrack {
        attribute trackId : String;
        attribute title : String;
    }

    item def TrackRequest {
        attribute trackId : String;
    }

    item def FilteredAudio {
        attribute notchCenterFreq : FrequencyValue;
        attribute outputVolume : SoundPressureLevelValue;
    }

    item def TherapyCommand {
        attribute commandType : String;
        attribute sessionDuration : DurationValue;
    }

    item def VolumeCommand {
        attribute maxVolume : SoundPressureLevelValue;
    }

    item def TherapyStatus {
        attribute status : String;
        attribute remainingTime : DurationValue;
    }

    action def AnalyzeTinnitusFrequency {
        in testToneResponse : TestTone;
        out profile : TinnitusProfile;
    }

    action def ApplyNotchFilter {
        in track : MusicTrack;
        in profile : TinnitusProfile;
        out audio : FilteredAudio;
    }

    action def EnforceVolumeLimit {
        in audio : FilteredAudio;
        in maxVolume : SoundPressureLevelValue;
    }

    action def MonitorTherapySession {
        in duration : DurationValue;
        out status : TherapyStatus;
    }

    state def TherapyControllerStates;

    part def User {
        port testToneReceivePort {
            in testTone : TestTone;
        }
        port testToneResponsePort {
            out testToneResponse : TestTone;
        }
        port audioReceivePort {
            in audio : FilteredAudio;
        }
        port commandPort {
            out command : TherapyCommand;
        }
    }

    part def FrequencyAnalyzer {
        port testToneSendPort {
            out testTone : TestTone;
        }
        port testToneReceivePort {
            in testToneResponse : TestTone;
        }
        port profilePort {
            out profile : TinnitusProfile;
        }
        perform action analyze : AnalyzeTinnitusFrequency;
    }

    part def MusicLibrary {
        port trackRequestPort {
            in trackRequest : TrackRequest;
        }
        port trackSupplyPort {
            out track : MusicTrack;
        }
    }

    part def NotchFilterProcessor {
        port profileInPort {
            in profile : TinnitusProfile;
        }
        port trackInPort {
            in track : MusicTrack;
        }
        port filteredAudioPort {
            out filteredAudio : FilteredAudio;
        }
        perform action applyFilter : ApplyNotchFilter;
        perform action enforceVolume : EnforceVolumeLimit;
    }

    part def TherapyController {
        port commandPort {
            in command : TherapyCommand;
        }
        port profilePort {
            in profile : TinnitusProfile;
        }
        port trackRequestPort {
            out trackRequest : TrackRequest;
        }
        port trackReceivePort {
            in track : MusicTrack;
        }
        port filterProfilePort {
            out filterProfile : TinnitusProfile;
        }
        port volumeCommandPort {
            out volumeCommand : VolumeCommand;
        }
        port statusPort {
            out status : TherapyStatus;
        }
        attribute maxSafeVolume : SoundPressureLevelValue = 85;
        exhibit state sessionStates : TherapyControllerStates;
    }

    part def AudioOutputDevice {
        port audioInPort {
            in audio : FilteredAudio;
        }
        port volumeLimitPort {
            in maxVolume : VolumeCommand;
        }
        port audioOutPort {
            out outputAudio : FilteredAudio;
        }
        attribute currentVolume : SoundPressureLevelValue;
    }

    part def TinnitracksSystem {
        port commandPort {
            in command : TherapyCommand;
        }
        port statusPort {
            out status : TherapyStatus;
        }
        part user : User;
        part frequencyAnalyzer : FrequencyAnalyzer;
        part musicLibrary : MusicLibrary;
        part notchFilterProcessor : NotchFilterProcessor;
        part therapyController : TherapyController;
        part audioOutputDevice : AudioOutputDevice;
    }

    requirement def HearingSafetyRequirement {
        doc /* The system shall ensure output volume never exceeds safe levels that could cause hearing damage. */
        attribute maxOutputLevel : SoundPressureLevelValue;
        constraint { maxOutputLevel <= 85 }
    }

    requirement def FrequencyDetectionPrecisionRequirement {
        doc /* The frequency analyzer must detect the tinnitus frequency with high precision for effective therapy. */
        attribute precision : FrequencyValue;
        constraint { precision <= 10 }
    }

    requirement def FilterPrecisionRequirement {
        doc /* The notch filter must apply a narrow band centered on the tinnitus frequency to maintain overall music quality. */
        attribute maxBandwidth : BandwidthValue;
        constraint { maxBandwidth <= 100 }
    }

    requirement def SessionDurationRequirement {
        doc /* Each therapy session must run for a pre-set minimum duration to achieve therapeutic effect. */
        attribute minDuration : DurationValue;
        constraint { minDuration >= 1800 }
    }

    requirement hearingSafetyReq : HearingSafetyRequirement {
        attribute maxOutputLevel = 85;
    }

    requirement detectionPrecisionReq : FrequencyDetectionPrecisionRequirement {
        attribute precision = 10;
    }

    requirement filterPrecisionReq : FilterPrecisionRequirement {
        attribute maxBandwidth = 80;
    }

    requirement sessionDurationReq : SessionDurationRequirement {
        attribute minDuration = 1800;
    }

    part tinnitracksDevice : TinnitracksSystem {
        bind commandPort = therapyController.commandPort;
        bind statusPort = therapyController.statusPort;

        flow testToneFlow of TestTone
            from frequencyAnalyzer.testToneSendPort.testTone
            to user.testToneReceivePort.testTone;

        flow testToneResponseFlow of TestTone
            from user.testToneResponsePort.testToneResponse
            to frequencyAnalyzer.testToneReceivePort.testToneResponse;

        flow profileFlow of TinnitusProfile
            from frequencyAnalyzer.profilePort.profile
            to therapyController.profilePort.profile;

        flow trackRequestFlow of TrackRequest
            from therapyController.trackRequestPort.trackRequest
            to musicLibrary.trackRequestPort.trackRequest;

        flow trackSupplyFlow of MusicTrack
            from musicLibrary.trackSupplyPort.track
            to therapyController.trackReceivePort.track;

        flow trackToFilterFlow of MusicTrack
            from therapyController.trackReceivePort.track
            to notchFilterProcessor.trackInPort.track;

        flow filterProfileFlow of TinnitusProfile
            from therapyController.filterProfilePort.filterProfile
            to notchFilterProcessor.profileInPort.profile;

        flow filteredAudioFlow of FilteredAudio
            from notchFilterProcessor.filteredAudioPort.filteredAudio
            to audioOutputDevice.audioInPort.audio;

        flow volumeCommandFlow of VolumeCommand
            from therapyController.volumeCommandPort.volumeCommand
            to audioOutputDevice.volumeLimitPort.maxVolume;

        flow outputAudioFlow of FilteredAudio
            from audioOutputDevice.audioOutPort.outputAudio
            to user.audioReceivePort.audio;

        satisfy hearingSafetyReq by audioOutputDevice;
        satisfy detectionPrecisionReq by frequencyAnalyzer;
        satisfy filterPrecisionReq by notchFilterProcessor;
        satisfy sessionDurationReq by therapyController;
    }

    state therapyControllerStates : TherapyControllerStates {
        entry action initial {}
        transition initial then idle;
        state idle;
        transition 'idle-analyzing'
            first idle
            accept TherapyCommand
            then analyzing;
        state analyzing;
        transition 'analyzing-filtering'
            first analyzing
            accept TinnitusProfile
            do send new TrackRequest() to tinnitracksDevice.musicLibrary
            then filtering;
        state filtering;
        transition 'filtering-delivering'
            first filtering
            accept MusicTrack
            do send new VolumeCommand() to tinnitracksDevice.audioOutputDevice
            then delivering;
        state delivering;
        transition 'delivering-stopped'
            first delivering
            accept TherapyCommand
            then stopped;
        state stopped;
        transition 'stopped-idle'
            first stopped
            then idle;
    }
}
