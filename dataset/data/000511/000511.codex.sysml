package TinnitracksSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    doc
    /*
     * High-level system definition for a Tinnitracks-based digital tinnitus therapy system.
     * Primary function: identify a user's tinnitus frequency and provide individualized
     * notched-music therapy by filtering user-selected audio around that frequency,
     * delivering structured listening sessions, and tracking adherence and outcomes.
     */

    attribute def FrequencyValue {
        value : Real;
        unit : Unit = Hz;
    }

    attribute def SoundPressureLevel {
        value : Real;
        unit : Unit = dB;
    }

    attribute def DurationValue {
        value : Real;
        unit : Unit = s;
    }

    attribute def PercentageValue {
        value : Real;
        unit : Unit = '%';
    }

    attribute def AudioBitRate {
        value : Real;
        unit : Unit = 'kbps';
    }

    enum def TherapySessionStatus {
        enum idle;
        enum preparing;
        enum active;
        enum paused;
        enum completed;
        enum aborted;
        enum failed;
    }

    enum def HearingSide {
        enum leftEar;
        enum rightEar;
        enum bothEars;
    }

    enum def AudioFormat {
        enum mp3;
        enum aac;
        enum wav;
        enum flac;
    }

    enum def ConsentState {
        enum notRequested;
        enum granted;
        enum denied;
        enum revoked;
    }

    item def RawMusicTrack {
        attribute title : String;
        attribute artist : String;
        attribute duration : DurationValue;
        attribute format : AudioFormat;
        attribute bitRate : AudioBitRate;
        attribute sampleRate : FrequencyValue;
        attribute containsProtectedContent : Boolean;
    }

    item def FilteredTherapyTrack {
        attribute title : String;
        attribute sourceTrackId : String;
        attribute notchCenterFrequency : FrequencyValue;
        attribute notchBandwidth : FrequencyValue;
        attribute duration : DurationValue;
        attribute format : AudioFormat;
        attribute processingQualityScore : PercentageValue;
    }

    item def TinnitusProfile {
        attribute patientId : String;
        attribute affectedSide : HearingSide;
        attribute dominantTinnitusFrequency : FrequencyValue;
        attribute tinnitusLoudness : SoundPressureLevel;
        attribute measurementConfidence : PercentageValue;
        attribute profileValid : Boolean;
    }

    item def TherapyPrescription {
        attribute prescriptionId : String;
        attribute dailyListeningGoal : DurationValue;
        attribute sessionMinimumDuration : DurationValue;
        attribute notchBandwidth : FrequencyValue;
        attribute maximumOutputLevel : SoundPressureLevel;
        attribute active : Boolean;
    }

    item def ListeningSessionRecord {
        attribute sessionId : String;
        attribute startedAtIso8601 : String;
        attribute completedDuration : DurationValue;
        attribute targetDuration : DurationValue;
        attribute averageOutputLevel : SoundPressureLevel;
        attribute status : TherapySessionStatus;
        attribute adherenceCredited : Boolean;
    }

    item def OutcomeAssessment {
        attribute assessmentId : String;
        attribute dateIso8601 : String;
        attribute tinnitusBurdenScore : Real;
        attribute perceivedLoudness : SoundPressureLevel;
        attribute sleepDisturbanceScore : Real;
        attribute concentrationDifficultyScore : Real;
    }

    item def AuthenticationCredential {
        attribute userName : String;
        attribute token : String;
        attribute expiresAtIso8601 : String;
    }

    item def ConsentRecord {
        attribute patientId : String;
        attribute medicalDataConsent : ConsentState;
        attribute therapyDataConsent : ConsentState;
        attribute analyticsConsent : ConsentState;
        attribute lastUpdatedIso8601 : String;
    }

    port def AudioInputPort {
        in rawTrack : RawMusicTrack;
    }

    port def AudioOutputPort {
        out therapyTrack : FilteredTherapyTrack;
    }

    port def ProfileInputPort {
        in profile : TinnitusProfile;
    }

    port def PrescriptionInputPort {
        in prescription : TherapyPrescription;
    }

    port def SessionRecordOutputPort {
        out record : ListeningSessionRecord;
    }

    port def AssessmentPort {
        in assessment : OutcomeAssessment;
        out trendSummary : String;
    }

    port def CredentialPort {
        in credential : AuthenticationCredential;
    }

    port def ConsentPort {
        in consent : ConsentRecord;
    }

    port def AudioPlaybackPort {
        out leftChannelLevel : SoundPressureLevel;
        out rightChannelLevel : SoundPressureLevel;
        out activeTrack : FilteredTherapyTrack;
    }

    part def TinnitracksBasedSystem {
        attribute systemName : String = "Tinnitracks-Based Individualized Notched Music Therapy System";
        attribute primaryFunction : String =
            "Provide individualized tinnitus therapy by determining the user's tinnitus frequency, creating frequency-notched music, guiding listening sessions, and tracking adherence and patient outcomes.";

        port credentialPort : CredentialPort;
        port consentPort : ConsentPort;
        port musicImportPort : AudioInputPort;
        port profilePort : ProfileInputPort;
        port prescriptionPort : PrescriptionInputPort;
        port playbackPort : AudioPlaybackPort;
        port sessionRecordPort : SessionRecordOutputPort;
        port assessmentPort : AssessmentPort;

        part mobileApplication : MobileTherapyApplication;
        part audioProcessingService : NotchedMusicProcessingService;
        part tinnitusAssessmentModule : TinnitusAssessmentModule;
        part therapyPlanner : TherapyPlanningModule;
        part playbackController : TherapyPlaybackController;
        part adherenceMonitor : AdherenceMonitoringModule;
        part outcomeTracker : OutcomeTrackingModule;
        part privacyManager : PrivacyAndConsentManager;
        part cloudRepository : SecureTherapyDataRepository;

        connect credentialPort to privacyManager.credentialPort;
        connect consentPort to privacyManager.consentPort;
        connect musicImportPort to mobileApplication.musicImportPort;
        connect profilePort to tinnitusAssessmentModule.profilePort;
        connect prescriptionPort to therapyPlanner.prescriptionPort;
        connect assessmentPort to outcomeTracker.assessmentPort;

        connect mobileApplication.rawMusicOut to audioProcessingService.rawMusicIn;
        connect tinnitusAssessmentModule.profileOut to audioProcessingService.profileIn;
        connect therapyPlanner.prescriptionOut to audioProcessingService.prescriptionIn;
        connect audioProcessingService.filteredTrackOut to playbackController.filteredTrackIn;
        connect playbackController.playbackOut to playbackPort;
        connect playbackController.sessionRecordOut to adherenceMonitor.sessionRecordIn;
        connect adherenceMonitor.sessionRecordOut to sessionRecordPort;
        connect adherenceMonitor.adherenceDataOut to cloudRepository.sessionRecordIn;
        connect outcomeTracker.assessmentOut to cloudRepository.assessmentIn;
        connect privacyManager.consentStatusOut to cloudRepository.consentIn;
    }

    part def MobileTherapyApplication {
        port musicImportPort : AudioInputPort;
        port rawMusicOut {
            out rawTrack : RawMusicTrack;
        }

        attribute availableStorage : Real;
        attribute networkAvailable : Boolean;
        attribute userAuthenticated : Boolean;

        action importUserMusic {
            in selectedTrack : RawMusicTrack;
            out acceptedTrack : RawMusicTrack;

            first start;
            then validateFormat;
            then rejectProtectedContent if selectedTrack.containsProtectedContent;
            then acceptTrack if not selectedTrack.containsProtectedContent;
            then done;

            action validateFormat;
            action rejectProtectedContent;
            action acceptTrack;
        }
    }

    part def TinnitusAssessmentModule {
        port profilePort : ProfileInputPort;
        port profileOut {
            out profile : TinnitusProfile;
        }

        attribute minimumSupportedFrequency : FrequencyValue = 1000 [Hz];
        attribute maximumSupportedFrequency : FrequencyValue = 12000 [Hz];
        attribute requiredConfidence : PercentageValue = 80 ['%'];

        action validateTinnitusProfile {
            in measuredProfile : TinnitusProfile;
            out validProfile : TinnitusProfile;

            first checkFrequencyRange;
            then checkConfidence;
            then publishProfile if
                measuredProfile.dominantTinnitusFrequency.value >= minimumSupportedFrequency.value and
                measuredProfile.dominantTinnitusFrequency.value <= maximumSupportedFrequency.value and
                measuredProfile.measurementConfidence.value >= requiredConfidence.value;
            then requestRetest if measuredProfile.measurementConfidence.value < requiredConfidence.value;
            then done;

            action checkFrequencyRange;
            action checkConfidence;
            action publishProfile;
            action requestRetest;
        }
    }

    part def TherapyPlanningModule {
        port prescriptionPort : PrescriptionInputPort;
        port prescriptionOut {
            out prescription : TherapyPrescription;
        }

        attribute defaultDailyGoal : DurationValue = 5400 [s];
        attribute defaultMinimumSession : DurationValue = 1800 [s];
        attribute defaultNotchBandwidth : FrequencyValue = 1000 [Hz];
        attribute defaultMaximumOutputLevel : SoundPressureLevel = 85 [dB];

        action createTherapyPrescription {
            in profile : TinnitusProfile;
            out prescription : TherapyPrescription;

            first verifyProfile;
            then setDailyGoal;
            then setNotchParameters;
            then setSafeOutputLimit;
            then activatePrescription;
            then done;

            action verifyProfile;
            action setDailyGoal;
            action setNotchParameters;
            action setSafeOutputLimit;
            action activatePrescription;
        }
    }

    part def NotchedMusicProcessingService {
        port rawMusicIn {
            in rawTrack : RawMusicTrack;
        }

        port profileIn {
            in profile : TinnitusProfile;
        }

        port prescriptionIn {
            in prescription : TherapyPrescription;
        }

        port filteredTrackOut : AudioOutputPort;

        attribute minimumProcessingQuality : PercentageValue = 95 ['%'];
        attribute maximumSupportedDuration : DurationValue = 7200 [s];

        action generateNotchedTherapyTrack {
            in sourceTrack : RawMusicTrack;
            in profile : TinnitusProfile;
            in prescription : TherapyPrescription;
            out therapyTrack : FilteredTherapyTrack;

            first decodeAudio;
            then calculateNotchFilter;
            then applyFrequencyNotch;
            then normalizeOutputLevel;
            then encodeTherapyTrack;
            then verifyProcessingQuality;
            then publishTrack if therapyTrack.processingQualityScore.value >= minimumProcessingQuality.value;
            then reportProcessingFailure if therapyTrack.processingQualityScore.value < minimumProcessingQuality.value;
            then done;

            action decodeAudio;
            action calculateNotchFilter;
            action applyFrequencyNotch;
            action normalizeOutputLevel;
            action encodeTherapyTrack;
            action verifyProcessingQuality;
            action publishTrack;
            action reportProcessingFailure;
        }

        constraint notchMustCenterOnTinnitusFrequency {
            filteredTrackOut.therapyTrack.notchCenterFrequency == profileIn.profile.dominantTinnitusFrequency;
        }

        constraint sourceTrackDurationLimit {
            rawMusicIn.rawTrack.duration.value <= maximumSupportedDuration.value;
        }
    }

    part def TherapyPlaybackController {
        port filteredTrackIn {
            in therapyTrack : FilteredTherapyTrack;
        }

        port playbackOut : AudioPlaybackPort;

        port sessionRecordOut {
            out record : ListeningSessionRecord;
        }

        attribute currentStatus : TherapySessionStatus = TherapySessionStatus::idle;
        attribute elapsedListeningTime : DurationValue = 0 [s];
        attribute targetListeningTime : DurationValue = 1800 [s];
        attribute outputLevelLimit : SoundPressureLevel = 85 [dB];

        state def PlaybackStateMachine {
            state idle;
            state loadingTrack;
            state ready;
            state playing;
            state paused;
            state completing;
            state completed;
            state failed;

            initial then idle;

            transition idle_to_loading
                first idle
                accept therapyTrackReceived
                then loadingTrack;

            transition loading_to_ready
                first loadingTrack
                accept trackDecoded
                then ready;

            transition ready_to_playing
                first ready
                accept startSession
                then playing;

            transition playing_to_paused
                first playing
                accept pauseSession
                then paused;

            transition paused_to_playing
                first paused
                accept resumeSession
                then playing;

            transition playing_to_completing
                first playing
                accept targetDurationReached
                then completing;

            transition completing_to_completed
                first completing
                accept sessionRecordStored
                then completed;

            transition playing_to_failed
                first playing
                accept playbackFault
                then failed;

            transition loading_to_failed
                first loadingTrack
                accept unsupportedTrack
                then failed;
        }

        action runTherapySession {
            in therapyTrack : FilteredTherapyTrack;
            in prescription : TherapyPrescription;
            out sessionRecord : ListeningSessionRecord;

            first loadTrack;
            then enforceOutputLimit;
            then startPlayback;
            then monitorElapsedTime;
            then pauseOrResumeOnUserCommand;
            then completeWhenGoalReached;
            then createSessionRecord;
            then done;

            action loadTrack;
            action enforceOutputLimit;
            action startPlayback;
            action monitorElapsedTime;
            action pauseOrResumeOnUserCommand;
            action completeWhenGoalReached;
            action createSessionRecord;
        }

        constraint outputLevelIsSafe {
            playbackOut.leftChannelLevel.value <= outputLevelLimit.value and
            playbackOut.rightChannelLevel.value <= outputLevelLimit.value;
        }
    }

    part def AdherenceMonitoringModule {
        port sessionRecordIn {
            in record : ListeningSessionRecord;
        }

        port sessionRecordOut : SessionRecordOutputPort;

        port adherenceDataOut {
            out record : ListeningSessionRecord;
        }

        attribute adherenceThreshold : PercentageValue = 90 ['%'];
        attribute dailyGoal : DurationValue = 5400 [s];

        action evaluateAdherence {
            in record : ListeningSessionRecord;
            out creditedRecord : ListeningSessionRecord;

            first calculateCompletionRatio;
            then creditSession if
                record.completedDuration.value >= record.targetDuration.value * adherenceThreshold.value / 100.0;
            then markIncomplete if
                record.completedDuration.value < record.targetDuration.value * adherenceThreshold.value / 100.0;
            then publishAdherenceRecord;
            then done;

            action calculateCompletionRatio;
            action creditSession;
            action markIncomplete;
            action publishAdherenceRecord;
        }
    }

    part def OutcomeTrackingModule {
        port assessmentPort : AssessmentPort;

        port assessmentOut {
            out assessment : OutcomeAssessment;
        }

        attribute baselineScore : Real;
        attribute latestScore : Real;
        attribute clinicallyMeaningfulImprovement : Real = 7.0;

        action assessTherapyOutcome {
            in baseline : OutcomeAssessment;
            in current : OutcomeAssessment;
            out trendSummary : String;

            first compareBurdenScores;
            then classifyImproved if
                baseline.tinnitusBurdenScore - current.tinnitusBurdenScore >= clinicallyMeaningfulImprovement;
            then classifyStable if
                abs(baseline.tinnitusBurdenScore - current.tinnitusBurdenScore) < clinicallyMeaningfulImprovement;
            then classifyWorsened if
                current.tinnitusBurdenScore - baseline.tinnitusBurdenScore >= clinicallyMeaningfulImprovement;
            then publishTrend;
            then done;

            action compareBurdenScores;
            action classifyImproved;
            action classifyStable;
            action classifyWorsened;
            action publishTrend;
        }
    }

    part def PrivacyAndConsentManager {
        port credentialPort : CredentialPort;
        port consentPort : ConsentPort;

        port consentStatusOut {
            out consent : ConsentRecord;
        }

        attribute sessionAuthenticated : Boolean = false;
        attribute activeConsentState : ConsentState = ConsentState::notRequested;

        action authorizeTherapyDataUse {
            in credential : AuthenticationCredential;
            in consent : ConsentRecord;
            out authorized : Boolean;

            first validateCredential;
            then evaluateConsent;
            then authorize if
                consent.medicalDataConsent == ConsentState::granted and
                consent.therapyDataConsent == ConsentState::granted;
            then deny if
                consent.medicalDataConsent != ConsentState::granted or
                consent.therapyDataConsent != ConsentState::granted;
            then done;

            action validateCredential;
            action evaluateConsent;
            action authorize;
            action deny;
        }
    }

    part def SecureTherapyDataRepository {
        port sessionRecordIn {
            in record : ListeningSessionRecord;
        }

        port assessmentIn {
            in assessment : OutcomeAssessment;
        }

        port consentIn {
            in consent : ConsentRecord;
        }

        attribute encryptionEnabled : Boolean = true;
        attribute retentionPeriod : DurationValue = 189216000 [s];
        attribute auditLoggingEnabled : Boolean = true;

        action storeTherapyData {
            in record : ListeningSessionRecord;
            in assessment : OutcomeAssessment;
            in consent : ConsentRecord;

            first verifyConsent;
            then encryptData;
            then storeSessionRecord;
            then storeAssessment;
            then writeAuditLog;
            then done;

            action verifyConsent;
            action encryptData;
            action storeSessionRecord;
            action storeAssessment;
            action writeAuditLog;
        }

        constraint protectedStorageRequired {
            encryptionEnabled == true and auditLoggingEnabled == true;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The system shall provide individualized notched-music therapy for tinnitus
         * by using the patient's dominant tinnitus frequency to process music and
         * deliver structured listening sessions.
         */

        subject system : TinnitracksBasedSystem;

        require constraint {
            system.audioProcessingService.filteredTrackOut.therapyTrack.notchCenterFrequency ==
            system.tinnitusAssessmentModule.profileOut.profile.dominantTinnitusFrequency;
        }
    }

    requirement def SafePlaybackRequirement {
        doc
        /*
         * The system shall limit therapy playback output level to a configured safe
         * maximum sound pressure level.
         */

        subject controller : TherapyPlaybackController;

        require constraint {
            controller.playbackOut.leftChannelLevel.value <= controller.outputLevelLimit.value and
            controller.playbackOut.rightChannelLevel.value <= controller.outputLevelLimit.value;
        }
    }

    requirement def AdherenceTrackingRequirement {
        doc
        /*
         * The system shall record listening session duration, status, and adherence
         * credit for each therapy session.
         */

        subject monitor : AdherenceMonitoringModule;

        require constraint {
            monitor.sessionRecordOut.record.sessionId != "" and
            monitor.sessionRecordOut.record.completedDuration.value >= 0.0;
        }
    }

    requirement def ConsentRequirement {
        doc
        /*
         * The system shall store therapy and assessment data only when required
         * medical and therapy data consent states are granted.
         */

        subject privacyManager : PrivacyAndConsentManager;

        require constraint {
            privacyManager.consentPort.consent.medicalDataConsent == ConsentState::granted and
            privacyManager.consentPort.consent.therapyDataConsent == ConsentState::granted;
        }
    }

    requirement def OutcomeMonitoringRequirement {
        doc
        /*
         * The system shall support repeated outcome assessments to evaluate changes
         * in tinnitus burden over time.
         */

        subject tracker : OutcomeTrackingModule;

        require constraint {
            tracker.assessmentPort.assessment.assessmentId != "" and
            tracker.assessmentPort.assessment.tinnitusBurdenScore >= 0.0;
        }
    }

    satisfy PrimaryFunctionRequirement by TinnitracksBasedSystem;
    satisfy SafePlaybackRequirement by TherapyPlaybackController;
    satisfy AdherenceTrackingRequirement by AdherenceMonitoringModule;
    satisfy ConsentRequirement by PrivacyAndConsentManager;
    satisfy OutcomeMonitoringRequirement by OutcomeTrackingModule;
}