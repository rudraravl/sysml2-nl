package WorthFourDotTestModel {
    import ScalarValues::*;

    attribute def Length_mm :> Real {
        attribute unit: String = "mm";
    }

    attribute def Distance_m :> Real {
        attribute unit: String = "m";
    }

    attribute def Angle_deg :> Real {
        attribute unit: String = "deg";
    }

    attribute def Wavelength_nm :> Real {
        attribute unit: String = "nm";
    }

    attribute def Luminance_cd_per_m2 :> Real {
        attribute unit: String = "cd/m^2";
    }

    attribute def Illuminance_lux :> Real {
        attribute unit: String = "lux";
    }

    attribute def Time_s :> Real {
        attribute unit: String = "s";
    }

    attribute def Percent :> Real {
        attribute unit: String = "%";
    }

    enum def DotIdentifier {
        enum topRed;
        enum leftGreen;
        enum rightGreen;
        enum bottomWhite;
    }

    enum def StimulusColor {
        enum red;
        enum green;
        enum white;
        enum blackBackground;
    }

    enum def EyeSide {
        enum left;
        enum right;
        enum both;
    }

    enum def TestMode {
        enum distance;
        enum near;
    }

    enum def SessionStatus {
        enum idle;
        enum ready;
        enum presentingStimulus;
        enum awaitingResponse;
        enum interpreting;
        enum completed;
        enum faulted;
    }

    enum def ResponseInputMode {
        enum verbal;
        enum touchPanel;
        enum clinicianEntry;
    }

    enum def VisionAssessment {
        enum normalBinocularFusion;
        enum leftEyeSuppression;
        enum rightEyeSuppression;
        enum diplopiaUncrossed;
        enum diplopiaCrossed;
        enum anomalousCorrespondence;
        enum inconclusive;
    }

    item def TestCommand {
        attribute commandId: String;
        attribute mode: TestMode;
        attribute requestedViewingDistance: Distance_m;
        attribute startRequested: Boolean;
    }

    item def DotStimulus {
        attribute dotId: DotIdentifier;
        attribute color: StimulusColor;
        attribute peakWavelength: Wavelength_nm;
        attribute luminance: Luminance_cd_per_m2;
        attribute diameter: Length_mm;
        attribute horizontalOffset: Length_mm;
        attribute verticalOffset: Length_mm;
        attribute angularSubtense: Angle_deg;
    }

    item def FourDotPattern {
        attribute mode: TestMode;
        attribute backgroundColor: StimulusColor = StimulusColor::blackBackground;
        attribute viewingDistance: Distance_m;
        attribute dotDiameter: Length_mm;
        attribute dotSeparation: Length_mm;
        attribute redPeakWavelength: Wavelength_nm = 625.0;
        attribute greenPeakWavelength: Wavelength_nm = 530.0;
        attribute whiteCorrelatedPeak: Wavelength_nm = 555.0;
        attribute redLuminance: Luminance_cd_per_m2;
        attribute greenLuminance: Luminance_cd_per_m2;
        attribute whiteLuminance: Luminance_cd_per_m2;
    }

    item def FilteredVisualStimulus {
        attribute eye: EyeSide;
        attribute visibleRedDot: Boolean;
        attribute visibleLeftGreenDot: Boolean;
        attribute visibleRightGreenDot: Boolean;
        attribute visibleWhiteDotAsLensColor: Boolean;
        attribute effectiveLuminance: Luminance_cd_per_m2;
    }

    item def PatientReport {
        attribute inputMode: ResponseInputMode;
        attribute dotsSeen: Integer;
        attribute redDotsSeen: Integer;
        attribute greenDotsSeen: Integer;
        attribute whiteDotsSeen: Integer;
        attribute perceivedSeparation: Angle_deg;
        attribute perceivedLeftRightOrder: String;
        attribute reportConfidence: Percent;
    }

    item def DiagnosticReport {
        attribute subjectId: String;
        attribute mode: TestMode;
        attribute viewingDistance: Distance_m;
        attribute assessment: VisionAssessment;
        attribute interpretationText: String;
        attribute dotsSeen: Integer;
        attribute redDotsSeen: Integer;
        attribute greenDotsSeen: Integer;
        attribute whiteDotsSeen: Integer;
        attribute ambientIlluminance: Illuminance_lux;
        attribute sessionDuration: Time_s;
        attribute clinicianReviewRequired: Boolean;
    }

    item def AmbientLightMeasurement {
        attribute illuminance: Illuminance_lux;
        attribute stable: Boolean;
    }

    port def CommandOutPort {
        out item command: TestCommand;
    }

    port def CommandInPort {
        in item command: TestCommand;
    }

    port def PatternOutPort {
        out item pattern: FourDotPattern;
    }

    port def PatternInPort {
        in item pattern: FourDotPattern;
    }

    port def FilteredStimulusOutPort {
        out item stimulus: FilteredVisualStimulus;
    }

    port def FilteredStimulusInPort {
        in item stimulus: FilteredVisualStimulus;
    }

    port def PatientReportOutPort {
        out item report: PatientReport;
    }

    port def PatientReportInPort {
        in item report: PatientReport;
    }

    port def DiagnosticReportOutPort {
        out item report: DiagnosticReport;
    }

    port def AmbientMeasurementOutPort {
        out item measurement: AmbientLightMeasurement;
    }

    port def AmbientMeasurementInPort {
        in item measurement: AmbientLightMeasurement;
    }

    action def CalibrateAmbientLightAction {
        out item measurement: AmbientLightMeasurement;
        attribute maximumPermittedAmbientIlluminance: Illuminance_lux = 50.0;
        attribute calibrationTimeout: Time_s = 10.0;
    }

    action def GenerateWorthFourDotPatternAction {
        in item command: TestCommand;
        out item pattern: FourDotPattern;
        attribute distanceModeViewingDistance: Distance_m = 6.0;
        attribute nearModeViewingDistance: Distance_m = 0.33;
        attribute standardDotDiameter: Length_mm = 12.0;
        attribute standardDotSeparation: Length_mm = 28.0;
        attribute targetRedLuminance: Luminance_cd_per_m2 = 80.0;
        attribute targetGreenLuminance: Luminance_cd_per_m2 = 80.0;
        attribute targetWhiteLuminance: Luminance_cd_per_m2 = 120.0;
    }

    action def PresentFilteredStimulusAction {
        in item pattern: FourDotPattern;
        out item leftEyeStimulus: FilteredVisualStimulus;
        out item rightEyeStimulus: FilteredVisualStimulus;
        attribute minimumPresentationTime: Time_s = 3.0;
        attribute maximumPresentationTime: Time_s = 30.0;
    }

    action def AcquirePatientResponseAction {
        in item leftEyeStimulus: FilteredVisualStimulus;
        in item rightEyeStimulus: FilteredVisualStimulus;
        out item report: PatientReport;
        attribute responseTimeout: Time_s = 45.0;
        attribute minimumAcceptableConfidence: Percent = 60.0;
    }

    action def InterpretWorthFourDotResponseAction {
        in item report: PatientReport;
        in item ambient: AmbientLightMeasurement;
        out item diagnostic: DiagnosticReport;
        attribute normalFusionRule: String = "Four dots perceived with one red, two green, and one white or mixed white response.";
        attribute leftSuppressionRule: String = "Two red dots only indicate suppression of the eye behind the green lens.";
        attribute rightSuppressionRule: String = "Three green dots only indicate suppression of the eye behind the red lens.";
        attribute diplopiaRule: String = "Five dots or spatially separated red and green groups indicate simultaneous perception without fusion.";
        attribute inconclusiveRule: String = "One dot, no dots, excessive ambient illumination, or low confidence requires clinician review.";
    }

    state def WorthFourDotSessionStateMachine {
        attribute status: SessionStatus = SessionStatus::idle;

        state idle;
        state calibratingAmbient;
        state ready;
        state presentingStimulus;
        state awaitingPatientResponse;
        state interpretingResponse;
        state recordingResult;
        state complete;
        state faulted;

        transition initial_to_idle first idle;

        transition idle_to_calibrating
            first idle
            accept TestCommand
            then calibratingAmbient;

        transition calibrating_to_ready
            first calibratingAmbient
            then ready;

        transition ready_to_presenting
            first ready
            then presentingStimulus;

        transition presenting_to_awaiting
            first presentingStimulus
            then awaitingPatientResponse;

        transition awaiting_to_interpreting
            first awaitingPatientResponse
            accept PatientReport
            then interpretingResponse;

        transition interpreting_to_recording
            first interpretingResponse
            then recordingResult;

        transition recording_to_complete
            first recordingResult
            then complete;

        transition any_to_faulted
            first idle
            then faulted;
    }

    part def DotEmitter {
        attribute dotId: DotIdentifier;
        attribute color: StimulusColor;
        attribute peakWavelength: Wavelength_nm;
        attribute luminance: Luminance_cd_per_m2;
        attribute diameter: Length_mm;
        attribute horizontalOffset: Length_mm;
        attribute verticalOffset: Length_mm;
        port opticalOut: PatternOutPort;
    }

    part def FourDotStimulusDisplay {
        attribute viewingDistance: Distance_m = 6.0;
        attribute backgroundLuminance: Luminance_cd_per_m2 = 1.0;
        attribute refreshPeriod: Time_s = 0.0167;
        attribute dotDiameter: Length_mm = 12.0;
        attribute dotSeparation: Length_mm = 28.0;

        port commandIn: CommandInPort;
        port patternOut: PatternOutPort;

        part topRedDot: DotEmitter {
            attribute dotId: DotIdentifier = DotIdentifier::topRed;
            attribute color: StimulusColor = StimulusColor::red;
            attribute peakWavelength: Wavelength_nm = 625.0;
            attribute luminance: Luminance_cd_per_m2 = 80.0;
            attribute diameter: Length_mm = 12.0;
            attribute horizontalOffset: Length_mm = 0.0;
            attribute verticalOffset: Length_mm = 28.0;
        }

        part leftGreenDot: DotEmitter {
            attribute dotId: DotIdentifier = DotIdentifier::leftGreen;
            attribute color: StimulusColor = StimulusColor::green;
            attribute peakWavelength: Wavelength_nm = 530.0;
            attribute luminance: Luminance_cd_per_m2 = 80.0;
            attribute diameter: Length_mm = 12.0;
            attribute horizontalOffset: Length_mm = -28.0;
            attribute verticalOffset: Length_mm = 0.0;
        }

        part rightGreenDot: DotEmitter {
            attribute dotId: DotIdentifier = DotIdentifier::rightGreen;
            attribute color: StimulusColor = StimulusColor::green;
            attribute peakWavelength: Wavelength_nm = 530.0;
            attribute luminance: Luminance_cd_per_m2 = 80.0;
            attribute diameter: Length_mm = 12.0;
            attribute horizontalOffset: Length_mm = 28.0;
            attribute verticalOffset: Length_mm = 0.0;
        }

        part bottomWhiteDot: DotEmitter {
            attribute dotId: DotIdentifier = DotIdentifier::bottomWhite;
            attribute color: StimulusColor = StimulusColor::white;
            attribute peakWavelength: Wavelength_nm = 555.0;
            attribute luminance: Luminance_cd_per_m2 = 120.0;
            attribute diameter: Length_mm = 12.0;
            attribute horizontalOffset: Length_mm = 0.0;
            attribute verticalOffset: Length_mm = -28.0;
        }

        action generatePattern: GenerateWorthFourDotPatternAction;

        connect commandIn to generatePattern.command;
        connect generatePattern.pattern to patternOut;
    }

    part def SpectralFilterLens {
        attribute eyeServed: EyeSide;
        attribute passColor: StimulusColor;
        attribute passbandCenter: Wavelength_nm;
        attribute passbandWidth: Wavelength_nm;
        attribute inBandTransmittance: Percent;
        attribute outOfBandLeakage: Percent;
    }

    part def RedGreenSpectacles {
        attribute frameInterocularDistance: Length_mm = 63.0;
        attribute redLensSide: EyeSide = EyeSide::right;
        attribute greenLensSide: EyeSide = EyeSide::left;

        port patternIn: PatternInPort;
        port leftEyeOut: FilteredStimulusOutPort;
        port rightEyeOut: FilteredStimulusOutPort;

        part rightRedLens: SpectralFilterLens {
            attribute eyeServed: EyeSide = EyeSide::right;
            attribute passColor: StimulusColor = StimulusColor::red;
            attribute passbandCenter: Wavelength_nm = 625.0;
            attribute passbandWidth: Wavelength_nm = 80.0;
            attribute inBandTransmittance: Percent = 85.0;
            attribute outOfBandLeakage: Percent = 3.0;
        }

        part leftGreenLens: SpectralFilterLens {
            attribute eyeServed: EyeSide = EyeSide::left;
            attribute passColor: StimulusColor = StimulusColor::green;
            attribute passbandCenter: Wavelength_nm = 530.0;
            attribute passbandWidth: Wavelength_nm = 70.0;
            attribute inBandTransmittance: Percent = 82.0;
            attribute outOfBandLeakage: Percent = 3.0;
        }

        action presentFilteredStimulus: PresentFilteredStimulusAction;

        connect patternIn to presentFilteredStimulus.pattern;
        connect presentFilteredStimulus.leftEyeStimulus to leftEyeOut;
        connect presentFilteredStimulus.rightEyeStimulus to rightEyeOut;
    }

    part def AmbientLightSensor {
        attribute measurementRangeMaximum: Illuminance_lux = 1000.0;
        attribute accuracy: Percent = 5.0;
        attribute samplePeriod: Time_s = 0.5;
        port ambientOut: AmbientMeasurementOutPort;
        action calibrateAmbient: CalibrateAmbientLightAction;
        connect calibrateAmbient.measurement to ambientOut;
    }

    part def PatientResponseRecorder {
        attribute supportedVerbalEntry: Boolean = true;
        attribute supportedTouchEntry: Boolean = true;
        attribute minimumConfidenceAccepted: Percent = 60.0;
        port leftEyeStimulusIn: FilteredStimulusInPort;
        port rightEyeStimulusIn: FilteredStimulusInPort;
        port reportOut: PatientReportOutPort;
        action acquireResponse: AcquirePatientResponseAction;
        connect leftEyeStimulusIn to acquireResponse.leftEyeStimulus;
        connect rightEyeStimulusIn to acquireResponse.rightEyeStimulus;
        connect acquireResponse.report to reportOut;
    }

    part def DiagnosticInterpreter {
        attribute assumesRedLensOverRightEye: Boolean = true;
        attribute classifyTwoRedAsLeftSuppression: Boolean = true;
        attribute classifyThreeGreenAsRightSuppression: Boolean = true;
        attribute classifyFiveDotsAsDiplopia: Boolean = true;

        port reportIn: PatientReportInPort;
        port ambientIn: AmbientMeasurementInPort;
        port diagnosticOut: DiagnosticReportOutPort;

        action interpret: InterpretWorthFourDotResponseAction;

        connect reportIn to interpret.report;
        connect ambientIn to interpret.ambient;
        connect interpret.diagnostic to diagnosticOut;
    }

    part def SessionController {
        attribute status: SessionStatus = SessionStatus::idle;
        attribute maximumSessionDuration: Time_s = 180.0;
        attribute defaultMode: TestMode = TestMode::distance;
        attribute defaultDistance: Distance_m = 6.0;

        port commandOut: CommandOutPort;
        port diagnosticIn: DiagnosticReportOutPort;

        state lifecycle: WorthFourDotSessionStateMachine;
    }

    part def OperatorConsole {
        attribute displayResultToClinician: Boolean = true;
        attribute storeReportInRecord: Boolean = true;
        port commandOut: CommandOutPort;
        port reportIn: DiagnosticReportOutPort;
    }

    part def WorthFourDotTestSystem {
        attribute primaryFunction: String = "Present a chromatically separated four-dot visual target through red-green filters and transform the subject's reported perception into a high-level binocular vision assessment.";
        attribute supportsDistanceTesting: Boolean = true;
        attribute supportsNearTesting: Boolean = true;

        port clinicianCommandIn: CommandInPort;
        port finalReportOut: DiagnosticReportOutPort;

        part controller: SessionController;
        part console: OperatorConsole;
        part display: FourDotStimulusDisplay;
        part spectacles: RedGreenSpectacles;
        part ambientSensor: AmbientLightSensor;
        part responseRecorder: PatientResponseRecorder;
        part interpreter: DiagnosticInterpreter;

        connect clinicianCommandIn to controller.commandOut;
        connect controller.commandOut to display.commandIn;
        connect display.patternOut to spectacles.patternIn;
        connect spectacles.leftEyeOut to responseRecorder.leftEyeStimulusIn;
        connect spectacles.rightEyeOut to responseRecorder.rightEyeStimulusIn;
        connect ambientSensor.ambientOut to interpreter.ambientIn;
        connect responseRecorder.reportOut to interpreter.reportIn;
        connect interpreter.diagnosticOut to finalReportOut;
        connect console.commandOut to display.commandIn;
        connect interpreter.diagnosticOut to console.reportIn;
    }

    part def ExaminationSubject {
        attribute subjectId: String;
        attribute wearsCorrectiveLensesIfNeeded: Boolean;
        attribute responseMode: ResponseInputMode = ResponseInputMode::verbal;
        port leftEyeStimulusIn: FilteredStimulusInPort;
        port rightEyeStimulusIn: FilteredStimulusInPort;
        port reportOut: PatientReportOutPort;
    }

    part def WorthFourDotClinicalContext {
        part system: WorthFourDotTestSystem;
        part subject: ExaminationSubject {
            attribute subjectId: String = "Subject-W4D-001";
            attribute wearsCorrectiveLensesIfNeeded: Boolean = true;
            attribute responseMode: ResponseInputMode = ResponseInputMode::verbal;
        }

        connect system.spectacles.leftEyeOut to subject.leftEyeStimulusIn;
        connect system.spectacles.rightEyeOut to subject.rightEyeStimulusIn;
        connect subject.reportOut to system.responseRecorder.reportOut;
    }

    constraint def DotLuminanceBalanceConstraint {
        in redLuminance: Luminance_cd_per_m2;
        in greenLuminance: Luminance_cd_per_m2;
        in whiteLuminance: Luminance_cd_per_m2;
        redLuminance >= 60.0 and redLuminance <= 100.0 and
        greenLuminance >= 60.0 and greenLuminance <= 100.0 and
        whiteLuminance >= 90.0 and whiteLuminance <= 150.0;
    }

    constraint def AmbientIlluminationConstraint {
        in ambient: Illuminance_lux;
        ambient <= 50.0;
    }

    constraint def FilterIsolationConstraint {
        in inBandTransmittance: Percent;
        in outOfBandLeakage: Percent;
        inBandTransmittance >= 80.0 and outOfBandLeakage <= 5.0;
    }

    requirement def PrimaryFunctionRequirement {
        subject system: WorthFourDotTestSystem;
        doc "The Worth 4 dot test system shall provide the high-level function of assessing binocular single vision by presenting one red, two green, and one white dot through red-green spectacles and interpreting the subject's reported number and color of dots as fusion, suppression, diplopia, anomalous correspondence, or inconclusive."
    }

    requirement def FourDotStimulusRequirement {
        subject display: FourDotStimulusDisplay;
        doc "The display shall present exactly four illuminated dots on a dark background: a red dot above center, green dots to the left and right of center, and a white dot below center."
        require constraint {
            display.topRedDot.color == StimulusColor::red and
            display.leftGreenDot.color == StimulusColor::green and
            display.rightGreenDot.color == StimulusColor::green and
            display.bottomWhiteDot.color == StimulusColor::white;
        }
    }

    requirement def SpectacleFilterRequirement {
        subject spectacles: RedGreenSpectacles;
        doc "The spectacles shall place a red filter before the right eye and a green filter before the left eye, with at least 80 percent in-band transmittance and no more than 5 percent out-of-band leakage."
        require constraint {
            spectacles.rightRedLens.eyeServed == EyeSide::right and
            spectacles.leftGreenLens.eyeServed == EyeSide::left and
            spectacles.rightRedLens.inBandTransmittance >= 80.0 and
            spectacles.leftGreenLens.inBandTransmittance >= 80.0 and
            spectacles.rightRedLens.outOfBandLeakage <= 5.0 and
            spectacles.leftGreenLens.outOfBandLeakage <= 5.0;
        }
    }

    requirement def ResponseClassificationRequirement {
        subject interpreter: DiagnosticInterpreter;
        doc "The interpreter shall classify four-dot perception as fusion, two red dots as suppression of the eye behind the green lens, three green dots as suppression of the eye behind the red lens, five dots as diplopia, and low-confidence or inconsistent reports as inconclusive."
    }

    requirement def AmbientControlRequirement {
        subject sensor: AmbientLightSensor;
        doc "The system shall measure ambient illumination before stimulus presentation and flag the result as requiring clinician review when illumination exceeds 50 lux."
    }

    requirement def RecordResultRequirement {
        subject system: WorthFourDotTestSystem;
        doc "The system shall produce a diagnostic report containing subject identifier, test mode, viewing distance, ambient illumination, perceived dot count, perceived colors, and final high-level assessment."
    }

    part worthFourDotClinicalStation: WorthFourDotClinicalContext;

    satisfy PrimaryFunctionRequirement by WorthFourDotTestSystem;
    satisfy FourDotStimulusRequirement by FourDotStimulusDisplay;
    satisfy SpectacleFilterRequirement by RedGreenSpectacles;
    satisfy ResponseClassificationRequirement by DiagnosticInterpreter;
    satisfy AmbientControlRequirement by AmbientLightSensor;
    satisfy RecordResultRequirement by WorthFourDotTestSystem;
}
