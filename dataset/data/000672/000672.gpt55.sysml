package MaddoxWingSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    unit def prismDiopterUnit {
        symbol = "Δ";
    }

    attribute def LengthValue :> length {
        unit = m;
    }

    attribute def AngleValue :> planeAngle {
        unit = rad;
    }

    attribute def PrismDiopterValue :> ScalarValues::Real {
        unit = prismDiopterUnit;
    }

    attribute def IlluminanceValue :> luminousFluxPerArea {
        unit = lx;
    }

    attribute def TimeValue :> time {
        unit = s;
    }

    attribute def ForceValue :> force {
        unit = N;
    }

    attribute def PercentageValue :> ScalarValues::Real;

    enum def EyeSide {
        enum left;
        enum right;
        enum both;
    }

    enum def PhoriaAxis {
        enum horizontal;
        enum vertical;
        enum torsional;
    }

    enum def HorizontalPhoriaDirection {
        enum orthophoria;
        enum exophoria;
        enum esophoria;
    }

    enum def VerticalPhoriaDirection {
        enum orthophoria;
        enum rightHyperphoria;
        enum leftHyperphoria;
    }

    enum def ExaminationStatus {
        enum notStarted;
        enum ready;
        enum patientPositioned;
        enum stimuliDissociated;
        enum patientReporting;
        enum readingCaptured;
        enum resultComputed;
        enum completed;
        enum aborted;
        enum sanitizing;
    }

    item def EyeImage {
        attribute eye: EyeSide;
        attribute targetName: String;
        attribute apparentOffsetHorizontal: PrismDiopterValue;
        attribute apparentOffsetVertical: PrismDiopterValue;
        attribute luminanceAtEye: IlluminanceValue;
    }

    item def BinocularDissociatedStimulus {
        attribute workingDistance: LengthValue;
        attribute separationProvided: Boolean;
        attribute rightEyeTarget: String;
        attribute leftEyeTarget: String;
        attribute targetContrast: PercentageValue;
        attribute nearFixationDemand: PrismDiopterValue;
        item rightEyeImage: EyeImage;
        item leftEyeImage: EyeImage;
    }

    item def PatientAlignmentResponse {
        attribute patientIdentifier: String;
        attribute reportedHorizontalScaleMark: Integer;
        attribute reportedVerticalScaleMark: Integer;
        attribute reportedTorsionalMark: Integer;
        attribute responseTime: TimeValue;
        attribute confidence: PercentageValue;
        attribute comments: String;
    }

    item def RawScaleReading {
        attribute horizontalScaleMark: Integer;
        attribute verticalScaleMark: Integer;
        attribute torsionalScaleMark: Integer;
        attribute observedByClinician: Boolean;
        attribute capturedAt: TimeValue;
    }

    item def HeterophoriaMeasurement {
        attribute horizontalMagnitude: PrismDiopterValue;
        attribute verticalMagnitude: PrismDiopterValue;
        attribute torsionalAngle: AngleValue;
        attribute horizontalDirection: HorizontalPhoriaDirection;
        attribute verticalDirection: VerticalPhoriaDirection;
        attribute measurementDistance: LengthValue;
        attribute valid: Boolean;
    }

    item def ExaminationReport {
        attribute patientIdentifier: String;
        attribute instrumentSerialNumber: String;
        attribute examinationDateTime: String;
        attribute status: ExaminationStatus;
        item rawReading: RawScaleReading;
        item measurement: HeterophoriaMeasurement;
        attribute clinicalSummary: String;
    }

    port def PatientVisualPort {
        in item stimulus: BinocularDissociatedStimulus;
        out item response: PatientAlignmentResponse;
    }

    port def InstrumentViewingPort {
        out item stimulus: BinocularDissociatedStimulus;
        in item response: PatientAlignmentResponse;
    }

    port def ClinicianInstructionPort {
        out item instructionText: String;
        in item acknowledgement: String;
    }

    port def InstrumentOperatorPort {
        in item instructionText: String;
        out item acknowledgement: String;
    }

    port def ReadingOutputPort {
        out item report: ExaminationReport;
        out item rawReading: RawScaleReading;
    }

    port def RecordInputPort {
        in item report: ExaminationReport;
        in item rawReading: RawScaleReading;
    }

    port def AmbientLightPort {
        out attribute illuminance: IlluminanceValue;
    }

    port def LightReceivingPort {
        in attribute illuminance: IlluminanceValue;
    }

    part def Patient {
        attribute patientIdentifier: String;
        attribute interpupillaryDistance: LengthValue;
        attribute nearPointAvailable: Boolean;
        attribute canReportScaleNumbers: Boolean;
        attribute wearingNearCorrection: Boolean;
        port visualPort: PatientVisualPort;
        port clinicianPort: ClinicianInstructionPort;
    }

    part def Clinician {
        attribute clinicianIdentifier: String;
        attribute trainedForMaddoxWingUse: Boolean;
        port instructionPort: ClinicianInstructionPort;
        port recordReviewPort: RecordInputPort;
    }

    part def ExaminationRecordSystem {
        attribute storageEnabled: Boolean;
        attribute retentionPeriodDays: Integer;
        port recordInput: RecordInputPort;
    }

    part def AmbientIllumination {
        attribute roomIlluminance: IlluminanceValue = 500 [lx];
        attribute uniformity: PercentageValue = 80.0;
        port lightPort: AmbientLightPort;
    }

    part def OcularSeptum {
        attribute material: String = "opaque matte polymer";
        attribute length: LengthValue = 0.115 [m];
        attribute height: LengthValue = 0.045 [m];
        attribute edgeRadius: LengthValue = 0.001 [m];
        attribute blocksCrossEyeViewing: Boolean = true;
    }

    part def ViewingAperture {
        attribute side: EyeSide;
        attribute clearDiameter: LengthValue = 0.018 [m];
        attribute eyeRelief: LengthValue = 0.012 [m];
        attribute rimContactForceLimit: ForceValue = 1.5 [N];
    }

    part def NoseBridgeRest {
        attribute contactWidth: LengthValue = 0.026 [m];
        attribute contactMaterial: String = "cleanable elastomer";
        attribute adjustableHeightRange: LengthValue = 0.012 [m];
    }

    part def CalibratedScalePlate {
        attribute plateName: String;
        attribute minimumMark: Integer;
        attribute maximumMark: Integer;
        attribute scaleIncrement: PrismDiopterValue = 1.0 [prismDiopterUnit];
        attribute markLegibilityContrast: PercentageValue = 90.0;
        attribute locatedForEye: EyeSide;
    }

    part def PointerTarget {
        attribute targetName: String;
        attribute targetColor: String = "red";
        attribute lineWidth: LengthValue = 0.0005 [m];
        attribute locatedForEye: EyeSide;
    }

    part def NearFixationTarget {
        attribute targetText: String = "fixation numbers and arrows";
        attribute angularSubtense: AngleValue = 0.003 [rad];
        attribute targetContrast: PercentageValue = 85.0;
    }

    part def IlluminationWindow {
        attribute transmittance: PercentageValue = 70.0;
        attribute diffuserMaterial: String = "frosted translucent polymer";
        port lightReceiver: LightReceivingPort;
    }

    part def ClinicianReadingWindow {
        attribute visibleScales: String = "horizontal, vertical, torsional";
        attribute magnification: ScalarValues::Real = 1.0;
        attribute parallaxLimited: Boolean = true;
    }

    part def ScaleInterpreter {
        attribute horizontalZeroMark: Integer = 0;
        attribute verticalZeroMark: Integer = 0;
        attribute torsionalZeroMark: Integer = 0;
        attribute horizontalCalibration: PrismDiopterValue = 1.0 [prismDiopterUnit];
        attribute verticalCalibration: PrismDiopterValue = 1.0 [prismDiopterUnit];
        attribute torsionalCalibration: AngleValue = 0.0174533 [rad];

        action computeHorizontalPhoria {
            in item raw: RawScaleReading;
            out attribute magnitude: PrismDiopterValue;
            out attribute direction: HorizontalPhoriaDirection;
        }

        action computeVerticalPhoria {
            in item raw: RawScaleReading;
            out attribute magnitude: PrismDiopterValue;
            out attribute direction: VerticalPhoriaDirection;
        }

        action computeTorsion {
            in item raw: RawScaleReading;
            out attribute torsionalAngle: AngleValue;
        }
    }

    part def MaddoxWingInstrument {
        doc /* A Maddox wing based diagnostic instrument for near-vision assessment. Its high-level purpose is to dissociate the patient's two eye views and present calibrated near targets so the patient's reported alignment reveals horizontal, vertical, and torsional heterophoria. */

        attribute serialNumber: String;
        attribute nominalWorkingDistance: LengthValue = 0.333 [m];
        attribute workingDistanceTolerance: LengthValue = 0.020 [m];
        attribute horizontalMeasurementRange: PrismDiopterValue = 30.0 [prismDiopterUnit];
        attribute verticalMeasurementRange: PrismDiopterValue = 15.0 [prismDiopterUnit];
        attribute torsionalMeasurementRange: AngleValue = 0.261799 [rad];
        attribute mass: mass = 0.160 [kg];
        attribute portable: Boolean = true;
        attribute requiresExternalPower: Boolean = false;
        attribute reusableAfterCleaning: Boolean = true;
        attribute currentStatus: ExaminationStatus = ExaminationStatus::notStarted;

        port patientViewingPort: InstrumentViewingPort;
        port operatorPort: InstrumentOperatorPort;
        port readingPort: ReadingOutputPort;
        port ambientLightReceiver: LightReceivingPort;

        part housing {
            attribute material: String = "black matte molded polymer";
            attribute externalLength: LengthValue = 0.160 [m];
            attribute externalWidth: LengthValue = 0.085 [m];
            attribute externalHeight: LengthValue = 0.060 [m];
            attribute strayLightSuppressed: Boolean = true;
        }

        part septum: OcularSeptum;

        part leftAperture: ViewingAperture {
            attribute side = EyeSide::left;
        }

        part rightAperture: ViewingAperture {
            attribute side = EyeSide::right;
        }

        part noseRest: NoseBridgeRest;

        part horizontalScale: CalibratedScalePlate {
            attribute plateName = "horizontal heterophoria scale";
            attribute minimumMark = -30;
            attribute maximumMark = 30;
            attribute locatedForEye = EyeSide::right;
        }

        part verticalScale: CalibratedScalePlate {
            attribute plateName = "vertical heterophoria scale";
            attribute minimumMark = -15;
            attribute maximumMark = 15;
            attribute locatedForEye = EyeSide::right;
        }

        part torsionalScale: CalibratedScalePlate {
            attribute plateName = "torsional scale";
            attribute minimumMark = -15;
            attribute maximumMark = 15;
            attribute locatedForEye = EyeSide::right;
        }

        part pointerArrow: PointerTarget {
            attribute targetName = "alignment pointer arrow";
            attribute locatedForEye = EyeSide::left;
        }

        part fixationTarget: NearFixationTarget;

        part illuminationWindow: IlluminationWindow;

        part readingWindow: ClinicianReadingWindow;

        part interpreter: ScaleInterpreter;

        connection ambientToDiffuser connect ambientLightReceiver to illuminationWindow.lightReceiver;

        action prepareForPatient {
            in attribute patientInterpupillaryDistance: LengthValue;
            out attribute ready: Boolean;
        }

        action presentDissociatedNearStimulus {
            out item stimulus: BinocularDissociatedStimulus;
        }

        action acceptPatientReport {
            in item response: PatientAlignmentResponse;
            out item raw: RawScaleReading;
        }

        action deriveMeasurement {
            in item raw: RawScaleReading;
            out item measurement: HeterophoriaMeasurement;
        }

        action publishReport {
            in item measurement: HeterophoriaMeasurement;
            in item raw: RawScaleReading;
            out item report: ExaminationReport;
        }

        state operationalState {
            entry action prepareForPatient;
            state idle;
            state ready;
            state positioned;
            state dissociatingViews;
            state collectingResponse;
            state interpretingScales;
            state reportingResult;
            state cleaning;
            state aborted;

            transition initialize first idle then ready;
            transition positionPatient first ready then positioned;
            transition startStimulus first positioned then dissociatingViews;
            transition requestReport first dissociatingViews then collectingResponse;
            transition captureReading first collectingResponse then interpretingScales;
            transition completeComputation first interpretingScales then reportingResult;
            transition finishExam first reportingResult then cleaning;
            transition cleaned first cleaning then idle;
            transition abortFromReady first ready then aborted;
            transition abortFromPositioned first positioned then aborted;
            transition resetAfterAbort first aborted then idle;
        }
    }

    action def ConductMaddoxWingNearAssessment {
        in part instrument: MaddoxWingInstrument;
        in part patient: Patient;
        in part clinician: Clinician;
        out item report: ExaminationReport;

        action verifyPatientCanRespond {
            in attribute canReportScaleNumbers: Boolean;
            out attribute acceptable: Boolean;
        }

        action alignInstrumentAtNearWorkingDistance {
            in attribute nominalWorkingDistance: LengthValue;
            in attribute interpupillaryDistance: LengthValue;
            out attribute aligned: Boolean;
        }

        action dissociateOcularViews {
            in part septum: OcularSeptum;
            out attribute rightEyeSeesScale: Boolean;
            out attribute leftEyeSeesPointer: Boolean;
        }

        action askPatientForScaleCoincidence {
            out item patientResponse: PatientAlignmentResponse;
        }

        action recordScaleMarks {
            in item patientResponse: PatientAlignmentResponse;
            out item rawReading: RawScaleReading;
        }

        action calculateNearHeterophoria {
            in item rawReading: RawScaleReading;
            out item measurement: HeterophoriaMeasurement;
        }

        action generateClinicalReport {
            in item measurement: HeterophoriaMeasurement;
            in item rawReading: RawScaleReading;
            out item report: ExaminationReport;
        }

        first start;
        then verifyPatientCanRespond;
        then alignInstrumentAtNearWorkingDistance;
        then dissociateOcularViews;
        then askPatientForScaleCoincidence;
        then recordScaleMarks;
        then calculateNearHeterophoria;
        then generateClinicalReport;
        then done;
    }

    part def MaddoxWingBasedSystem {
        doc /* System context for a Maddox wing based near heterophoria assessment capability. The primary high-level function is to support a clinician in measuring latent binocular misalignment at near distance by separating the visual fields of the two eyes and translating the patient's perceived pointer-to-scale alignment into clinical phoria values. */

        attribute systemName: String = "Maddox Wing Near Heterophoria Assessment System";
        attribute intendedUse: String = "near binocular vision dissociation and heterophoria measurement";
        attribute nominalExaminationDuration: TimeValue = 120 [s];

        part instrument: MaddoxWingInstrument {
            attribute serialNumber = "MW-NEAR-001";
        }

        part patient: Patient {
            attribute patientIdentifier = "exam-subject";
            attribute interpupillaryDistance = 0.062 [m];
            attribute nearPointAvailable = true;
            attribute canReportScaleNumbers = true;
            attribute wearingNearCorrection = true;
        }

        part clinician: Clinician {
            attribute clinicianIdentifier = "vision-care-user";
            attribute trainedForMaddoxWingUse = true;
        }

        part recordSystem: ExaminationRecordSystem {
            attribute storageEnabled = true;
            attribute retentionPeriodDays = 2555;
        }

        part ambientLight: AmbientIllumination {
            attribute roomIlluminance = 500 [lx];
        }

        connection visualInteraction connect instrument.patientViewingPort to patient.visualPort;
        connection clinicianCommands connect clinician.instructionPort to instrument.operatorPort;
        connection resultRecording connect instrument.readingPort to recordSystem.recordInput;
        connection roomLightToInstrument connect ambientLight.lightPort to instrument.ambientLightReceiver;
        connection clinicianRecordReview connect recordSystem.recordInput to clinician.recordReviewPort;

        perform action nearAssessment: ConductMaddoxWingNearAssessment {
            in instrument = instrument;
            in patient = patient;
            in clinician = clinician;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide the primary high-level function of a Maddox wing: dissociate the patient's left-eye and right-eye near views and provide calibrated visual references so a clinician can determine near horizontal, vertical, and torsional heterophoria from the patient's reported alignment. */
        subject system: MaddoxWingBasedSystem;
        require constraint {
            system.instrument.nominalWorkingDistance == 0.333 [m]
        }
    }

    requirement def VisualDissociationRequirement {
        doc /* The instrument shall prevent either eye from directly seeing the complete target set intended for the other eye during the measurement. */
        subject instrument: MaddoxWingInstrument;
        require constraint {
            instrument.septum.blocksCrossEyeViewing == true
        }
    }

    requirement def MeasurementRangeRequirement {
        doc /* The instrument shall cover clinically useful near heterophoria ranges for screening and routine assessment. */
        subject instrument: MaddoxWingInstrument;
        require constraint {
            instrument.horizontalMeasurementRange >= 30.0 [prismDiopterUnit] and
            instrument.verticalMeasurementRange >= 15.0 [prismDiopterUnit] and
            instrument.torsionalMeasurementRange >= 0.261799 [rad]
        }
    }

    requirement def AmbientVisibilityRequirement {
        doc /* The visual targets and scales shall remain legible in ordinary examination-room illumination. */
        subject system: MaddoxWingBasedSystem;
        require constraint {
            system.ambientLight.roomIlluminance >= 300 [lx] and
            system.instrument.fixationTarget.targetContrast >= 80.0
        }
    }

    requirement def PatientSafetyAndComfortRequirement {
        doc /* Patient-contact surfaces shall limit contact force and be cleanable between examinations. */
        subject instrument: MaddoxWingInstrument;
        require constraint {
            instrument.leftAperture.rimContactForceLimit <= 1.5 [N] and
            instrument.rightAperture.rimContactForceLimit <= 1.5 [N] and
            instrument.reusableAfterCleaning == true
        }
    }

    requirement def ReportRequirement {
        doc /* The system shall produce an examination report containing raw scale readings and derived near heterophoria values. */
        subject system: MaddoxWingBasedSystem;
        require constraint {
            system.recordSystem.storageEnabled == true
        }
    }

    part maddoxWingSystem: MaddoxWingBasedSystem;

    requirement primaryFunction: PrimaryFunctionRequirement {
        subject system = maddoxWingSystem;
    }

    requirement visualDissociation: VisualDissociationRequirement {
        subject instrument = maddoxWingSystem.instrument;
    }

    requirement measurementRange: MeasurementRangeRequirement {
        subject instrument = maddoxWingSystem.instrument;
    }

    requirement ambientVisibility: AmbientVisibilityRequirement {
        subject system = maddoxWingSystem;
    }

    requirement patientSafetyAndComfort: PatientSafetyAndComfortRequirement {
        subject instrument = maddoxWingSystem.instrument;
    }

    requirement reportContent: ReportRequirement {
        subject system = maddoxWingSystem;
    }

    satisfy primaryFunction by maddoxWingSystem;
    satisfy visualDissociation by maddoxWingSystem.instrument.septum;
    satisfy measurementRange by maddoxWingSystem.instrument;
    satisfy ambientVisibility by maddoxWingSystem.instrument.fixationTarget;
    satisfy patientSafetyAndComfort by maddoxWingSystem.instrument.leftAperture;
    satisfy patientSafetyAndComfort by maddoxWingSystem.instrument.rightAperture;
    satisfy reportContent by maddoxWingSystem.recordSystem;
}
