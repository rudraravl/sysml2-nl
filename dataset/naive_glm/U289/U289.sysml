package MaddoxWingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ============================================================
    // Units and Value Types
    // ============================================================

    unit def PrismDiopterUnit {
        shortName = "PD";
        symbol = "Δ";
    }

    value def PrismDiopter :> Real {
        unit = PrismDiopterUnit;
    }

    value def LuminousIntensityValue :> Real {
        unit = Candela;
    }

    value def WavelengthValue :> LengthValue {
        unit = Nanometre;
    }

    value def ViewingDistanceValue :> LengthValue {
        unit = Centimetre;
    }

    value def RodPitchValue :> LengthValue {
        unit = Millimetre;
    }

    // ============================================================
    // Enumerations
    // ============================================================

    enum def RodOrientation {
        horizontal;
        vertical;
    }

    enum def SafetyStatus {
        nominal;
        warning;
        fault;
    }

    enum def PhoriaType {
        orthophoria;
        esophoria;
        exophoria;
        hyperphoria;
        hypophoria;
    }

    // ============================================================
    // Item Types
    // ============================================================

    item def VisualImage;

    item def LightBeam :> VisualImage {
        attribute intensity : LuminousIntensityValue;
        attribute wavelength : WavelengthValue = 550 [nm];
    }

    item def PointImage :> VisualImage {
        attribute horizontalPosition : PrismDiopter = 0.0;
        attribute verticalPosition : PrismDiopter = 0.0;
    }

    item def LineImage :> VisualImage {
        attribute orientation : RodOrientation;
        attribute offset : PrismDiopter;
    }

    item def PatientReport {
        attribute lineHorizontalPosition : PrismDiopter;
        attribute lineVerticalPosition : PrismDiopter;
        attribute verbalDescription : String;
    }

    item def DiagnosisResult {
        attribute horizontalDeviation : PrismDiopter;
        attribute verticalDeviation : PrismDiopter;
        attribute phoriaType : PhoriaType;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def OpticalOutputPort {
        out beam : LightBeam;
    }

    port def OpticalInputPort {
        in beam : LightBeam;
    }

    port def PatientViewPort {
        out image : VisualImage;
    }

    port def ExaminerControlPort {
        in intensitySetting : LuminousIntensityValue;
        in rodOrientation : RodOrientation;
    }

    port def SafetyMonitorPort {
        out measuredIntensity : LuminousIntensityValue;
        out status : SafetyStatus;
    }

    port def ExaminerFeedbackPort {
        in report : PatientReport;
    }

    // ============================================================
    // Action Definitions
    // ============================================================

    action def GenerateLight {
        in intensity : LuminousIntensityValue;
        out beam : LightBeam;
    }

    action def TransformBeam {
        in beam : LightBeam;
        in orientation : RodOrientation;
        out lineImage : LineImage;
    }

    action def ReadScale {
        in reportedHorizontal : PrismDiopter;
        in reportedVertical : PrismDiopter;
        out horizontalDeviation : PrismDiopter;
        out verticalDeviation : PrismDiopter;
    }

    action def PerceiveImages {
        in pointImage : PointImage;
        in lineImage : LineImage;
        out perceivedHorizontal : PrismDiopter;
        out perceivedVertical : PrismDiopter;
    }

    action def ReportPerception {
        in perceivedHorizontal : PrismDiopter;
        in perceivedVertical : PrismDiopter;
        out report : PatientReport;
    }

    action def InterpretReport {
        in report : PatientReport;
        out diagnosis : DiagnosisResult;
    }

    action def SetIntensity {
        out intensity : LuminousIntensityValue;
    }

    action def SetRodOrientation {
        out orientation : RodOrientation;
    }

    // ============================================================
    // Part Definitions
    // ============================================================

    part def IlluminationSource {
        port opticalOut : OpticalOutputPort;
        port controlIn : ExaminerControlPort;
        port monitorOut : SafetyMonitorPort;

        attribute targetIntensity : LuminousIntensityValue = 0.5 [cd];
        attribute maxSafeIntensity : LuminousIntensityValue = 1.0 [cd];
        attribute currentIntensity : LuminousIntensityValue = 0.5 [cd];
        attribute powerState : Boolean = true;
        attribute bulbType : String = "LED";
        attribute bulbLifetime : Integer = 50000;

        perform GenerateLight(intensity := currentIntensity, beam := opticalOut.beam);

        // Continuously report measured intensity to safety controller
        assign monitorOut.measuredIntensity = currentIntensity;
    }

    part def MaddoxRod {
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        attribute orientation : RodOrientation = RodOrientation::horizontal;
        attribute cylinderCount : Integer = 20;
        attribute cylinderPitch : RodPitchValue = 1.0 [mm];
        attribute material : String = "Optical glass";
        attribute rodDiameter : LengthValue = 5.0 [mm];

        perform TransformBeam(
            beam := opticalIn.beam,
            orientation := orientation,
            lineImage := opticalOut.beam
        );

        // When orientation is horizontal, line appears vertical (measures horizontal phoria)
        // When orientation is vertical, line appears horizontal (measures vertical phoria)
    }

    part def CalibratedScale {
        attribute horizontalRange : PrismDiopter = 20.0;
        attribute verticalRange : PrismDiopter = 20.0;
        attribute resolution : PrismDiopter = 1.0;
        attribute viewingDistance : ViewingDistanceValue = 33.0 [cm];
        attribute scaleType : String = "Prism diopter scale";

        perform ReadScale(
            reportedHorizontal := 0.0,
            reportedVertical := 0.0,
            horizontalDeviation := 0.0,
            verticalDeviation := 0.0
        );
    }

    part def SafetyController {
        port monitorIn : SafetyMonitorPort;
        port controlOut : ExaminerControlPort;

        attribute maxSafeIntensity : LuminousIntensityValue = 1.0 [cd];
        attribute warningThreshold : LuminousIntensityValue = 0.8 [cd];
        attribute currentStatus : SafetyStatus = SafetyStatus::nominal;
        attribute overrideIntensity : LuminousIntensityValue = 0.0 [cd];
        attribute overrideActive : Boolean = false;

        state def SafetyStateMachine {
            initial Initial;

            state nominal {
                entry assign currentStatus = SafetyStatus::nominal;
                entry assign overrideActive = false;

                transition toWarning
                    first nominal to warning
                    if monitorIn.measuredIntensity > warningThreshold;
            }

            state warning {
                entry assign currentStatus = SafetyStatus::warning;
                entry assign overrideActive = false;

                transition toFault
                    first warning to fault
                    if monitorIn.measuredIntensity > maxSafeIntensity;

                transition backToNominal
                    first warning to nominal
                    if monitorIn.measuredIntensity <= warningThreshold;
            }

            state fault {
                entry assign currentStatus = SafetyStatus::fault;
                entry assign overrideActive = true;
                entry assign overrideIntensity = 0.0 [cd];
                entry assign controlOut.intensitySetting = 0.0 [cd];

                transition faultRecovery
                    first fault to nominal
                    if monitorIn.measuredIntensity <= warningThreshold;
            }

            transition init first Initial to nominal;
        }

        perform SafetyStateMachine;
    }

    part def Housing {
        attribute material : String = "ABS Plastic";
        attribute length : LengthValue = 15.0 [cm];
        attribute width : LengthValue = 8.0 [cm];
        attribute height : LengthValue = 5.0 [cm];
        attribute color : String = "Matte black";
        attribute weight : MassValue = 0.3 [kg];
        attribute hasEyeRest : Boolean = true;
        attribute hasHandle : Boolean = true;
    }

    part def Patient {
        port leftEyeView : PatientViewPort;
        port rightEyeView : PatientViewPort;

        attribute leftEyeAlignment : PrismDiopter = 0.0;
        attribute rightEyeAlignment : PrismDiopter = 0.0;
        attribute fusionDisrupted : Boolean = true;
        attribute viewingDistance : ViewingDistanceValue = 33.0 [cm];

        perform PerceiveImages(
            pointImage := leftEyeView.image,
            lineImage := rightEyeView.image
        );

        perform ReportPerception;
    }

    part def Examiner {
        port controlOut : ExaminerControlPort;
        port feedbackIn : ExaminerFeedbackPort;

        perform SetIntensity(intensity := controlOut.intensitySetting);
        perform SetRodOrientation(orientation := controlOut.rodOrientation);
        perform InterpretReport(report := feedbackIn.report);
    }

    // ============================================================
    // Top-Level System: Maddox Wing
    // ============================================================

    part def MaddoxWing {
        port patientLeftEye : PatientViewPort;
        port patientRightEye : PatientViewPort;
        port examinerControl : ExaminerControlPort;
        port examinerFeedback : ExaminerFeedbackPort;

        part illuminationSource : IlluminationSource;
        part maddoxRod : MaddoxRod;
        part scale : CalibratedScale;
        part safetyController : SafetyController;
        part housing : Housing;

        attribute standardViewingDistance : ViewingDistanceValue = 33.0 [cm];
        attribute systemCalibrated : Boolean = true;

        // Direct path: point light source to patient's left eye
        connection directLightPath
            connect illuminationSource.opticalOut to patientLeftEye;

        // Rod path: light through Maddox rod to patient's right eye
        connection sourceToRod
            connect illuminationSource.opticalOut to maddoxRod.opticalIn;
        connection rodToPatient
            connect maddoxRod.opticalOut to patientRightEye;

        // Safety monitoring loop
        connection safetyFeedback
            connect illuminationSource.monitorOut to safetyController.monitorIn;
        connection safetyControlOverride
            connect safetyController.controlOut to illuminationSource.controlIn;

        // Examiner control interface
        connection examinerToSource
            connect examinerControl to illuminationSource.controlIn;
        connection examinerToSafety
            connect examinerControl to safetyController.controlOut;

        // Examiner feedback
        connection feedbackPath
            connect examinerFeedback to examinerFeedback;

        satisfy DissociationRequirement by self;
        satisfy ViewingDistanceRequirement by self;
        satisfy PhoriaMeasurementRequirement by self;
        satisfy SafetyRequirement by illuminationSource;
        satisfy ScaleCalibrationRequirement by scale;
        satisfy RodOrientationRequirement by maddoxRod;
        satisfy DiagnosisRequirement by Examiner;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def DissociationRequirement {
        doc /* The system must present a point image to one eye and a line image to the other eye simultaneously to prevent binocular fusion and reveal the eyes' natural resting position. */
        attribute fusionPrevented : Boolean = true;
        attribute pointImageProvided : Boolean = true;
        attribute lineImageProvided : Boolean = true;
    }

    requirement def ScaleCalibrationRequirement {
        doc /* The integrated scale must be calibrated in prism diopters with 1 PD resolution over a range of at least 20 PD in both horizontal and vertical directions. */
        attribute requiredResolution : PrismDiopter = 1.0;
        attribute requiredHorizontalRange : PrismDiopter = 20.0;
        attribute requiredVerticalRange : PrismDiopter = 20.0;
        attribute unit : String = "prism diopter";
    }

    requirement def ViewingDistanceRequirement {
        doc /* The device must be designed for a standard near-viewing distance of 33 cm. */
        attribute requiredDistance : ViewingDistanceValue = 33.0 [cm];
        attribute tolerance : LengthValue = 1.0 [cm];
    }

    requirement def SafetyRequirement {
        doc /* The light source intensity must not exceed 1.0 cd to ensure patient comfort and ocular safety during prolonged testing. */
        attribute maxIntensity : LuminousIntensityValue = 1.0 [cd];
        attribute warningThreshold : LuminousIntensityValue = 0.8 [cd];
        attribute automaticShutoff : Boolean = true;
    }

    requirement def PhoriaMeasurementRequirement {
        doc /* The system must allow measurement of both horizontal and vertical phoria deviations in prism diopters. */
        attribute measuresHorizontal : Boolean = true;
        attribute measuresVertical : Boolean = true;
        attribute measurementUnit : String = "prism diopter";
    }

    requirement def DiagnosisRequirement {
        doc /* The examiner must be able to diagnose esophoria, exophoria, hyperphoria, and hypophoria based on patient reports of line position relative to the scale. */
        attribute canDiagnoseEsophoria : Boolean = true;
        attribute canDiagnoseExophoria : Boolean = true;
        attribute canDiagnoseHyperphoria : Boolean = true;
        attribute canDiagnoseHypophoria : Boolean = true;
    }

    requirement def RodOrientationRequirement {
        doc /* The Maddox rod must be rotatable between horizontal and vertical orientations to measure both horizontal and vertical phoria. */
        attribute supportsHorizontal : Boolean = true;
        attribute supportsVertical : Boolean = true;
        attribute rotationMechanism : Boolean = true;
    }

    requirement def ImageTransformationRequirement {
        doc /* The Maddox rod must transform a point of light into a perpendicular line or streak of light. */
        attribute transformsPointToLine : Boolean = true;
        attribute linePerpendicularToRod : Boolean = true;
    }

    requirement def DissociationEffectivenessRequirement {
        doc /* The dissociation method must reliably prevent binocular fusion by presenting dissimilar images to each eye. */
        attribute dissimilarImagesPresented : Boolean = true;
        attribute fusionDisruptionReliability : Real = 0.95;
    }
}
