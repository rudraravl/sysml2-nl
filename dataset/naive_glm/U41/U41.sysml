package EarDeformityCorrectionSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def PressureValue :> Real {
        :>> unit = 'N/cm2';
    }

    value def ForceValue :> Real {
        :>> unit = 'N';
    }

    value def DurationValue :> Real {
        :>> unit = 'd';
    }

    value def AgeValue :> Real {
        :>> unit = 'd';
    }

    value def MassValue :> Real {
        :>> unit = 'g';
    }

    value def TemperatureValue :> Real {
        :>> unit = 'degC';
    }

    value def LengthValue :> Real {
        :>> unit = 'mm';
    }

    value def PressureTolerance {
        attribute targetPressure : PressureValue;
        attribute minPressure : PressureValue;
        attribute maxPressure : PressureValue;
    }

    // ===== Enumerations =====

    enum def DeformityType {
        lopEar;
        cupEar;
        helixRimKink;
        stahlEar;
        conchalCrustration;
        mixed;
    }

    enum def CorrectionStatus {
        notAssessed;
        assessed;
        splintCustomized;
        splintApplied;
        underCorrection;
        adjustmentNeeded;
        correctionAchieved;
        deviceRemoved;
        treatmentTerminated;
    }

    enum def SkinCondition {
        normal;
        mildIrritation;
        moderateIrritation;
        severeIrritation;
    }

    enum def AdhesionQuality {
        secure;
        partial;
        failed;
    }

    // ===== Item Definitions =====

    item def BiocompatibleSilicone {
        attribute shoreHardness : Real;
        attribute biocompatibilityGrade : String;
        attribute sterilizationMethod : String;
    }

    item def SkinSafeAdhesive {
        attribute adhesiveStrength : ForceValue;
        attribute hypoallergenic : Boolean;
        attribute breathable : Boolean;
    }

    item def InfantEar {
        attribute deformityType : DeformityType;
        attribute cartilageFlexibility : Real;
        attribute skinCondition : SkinCondition;
        attribute earLength : LengthValue;
        attribute earWidth : LengthValue;
    }

    item def AssessmentReport {
        attribute deformityType : DeformityType;
        attribute severityIndex : Real;
        attribute recommendedPressure : PressureValue;
        attribute estimatedTreatmentTime : DurationValue;
        attribute patientAgeAtAssessment : AgeValue;
    }

    item def MonitoringRecord {
        attribute timestamp : String;
        attribute measuredPressure : PressureValue;
        attribute skinCondition : SkinCondition;
        attribute adhesionQuality : AdhesionQuality;
        attribute correctionProgressPercent : Real;
        attribute adjustmentRecommended : Boolean;
    }

    item def CustomizationSpec {
        attribute shellContourProfile : String;
        attribute bandLengthFront : LengthValue;
        attribute bandLengthRear : LengthValue;
        attribute targetPressure : PressureValue;
        attribute siliconeShoreHardness : Real;
    }

    // ===== Port Definitions =====

    port def MoldingPressurePort {
        out moldingPressure : PressureValue;
    }

    port def SkinContactPort {
        in appliedPressure : PressureValue;
        out skinResponse : SkinCondition;
    }

    port def RetentionForcePort {
        out retentionForce : ForceValue;
    }

    port def MonitoringPort {
        in monitoringRecord : MonitoringRecord;
        out adjustmentCommand : String;
    }

    port def AssessmentPort {
        in infantEar : InfantEar;
        out assessmentReport : AssessmentReport;
    }

    port def CustomizationPort {
        in assessmentReport : AssessmentReport;
        out customizationSpec : CustomizationSpec;
    }

    // ===== Parts =====

    part def AuricularShell {
        attribute material : BiocompatibleSilicone;
        attribute contourProfile : String;
        attribute thickness : LengthValue;
        attribute surfaceArea : Real;
        port moldingPressureOut : MoldingPressurePort;
        port skinContact : SkinContactPort;

        action def ApplyMoldingPressure {
            in targetPressure : PressureValue;
            out appliedPressure : PressureValue;
        }

        perform ApplyMoldingPressure;
    }

    part def AdhesiveRetentionBand {
        attribute adhesive : SkinSafeAdhesive;
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute placement : String;
        port retentionForceOut : RetentionForcePort;

        action def SecureToSkin {
            in requiredForce : ForceValue;
            out appliedForce : ForceValue;
        }

        perform SecureToSkin;
    }

    part def AuricularSplintDevice {
        part shell : AuricularShell;
        part frontBand : AdhesiveRetentionBand {
            :>> placement = "anterior";
        }
        part rearBand : AdhesiveRetentionBand {
            :>> placement = "posterior";
        }

        connection shellToFrontBand connect shell.skinContact to frontBand.retentionForceOut;
        connection shellToRearBand connect shell.skinContact to rearBand.retentionForceOut;

        attribute totalRetentionForce : ForceValue;
        attribute appliedMoldingPressure : PressureValue;

        action def ApplyDevice {
            in infantEar : InfantEar;
            in customizationSpec : CustomizationSpec;
            out applicationSuccess : Boolean;
        }

        perform ApplyDevice;
    }

    part def Patient {
        attribute patientId : String;
        attribute ageAtIntake : AgeValue;
        attribute weight : MassValue;
        part leftEar : InfantEar;
        part rightEar : InfantEar;

        port assessmentInterface : AssessmentPort;
        port skinInterface : SkinContactPort;

        invariant maxAgeEligibility { ageAtIntake <= 42 }
        invariant minAgeEligibility { ageAtIntake >= 1 }
    }

    part def AssessmentUnit {
        port assessmentPort : AssessmentPort;

        action def ConductAssessment {
            in infantEar : InfantEar;
            in patientAge : AgeValue;
            out report : AssessmentReport;

            // Determine deformity type and severity
            action classifyDeformity {
                in ear : InfantEar;
                out deformityType : DeformityType;
                out severity : Real;
            }

            // Calculate recommended pressure
            action calculatePressure {
                in severity : Real;
                in cartilageFlexibility : Real;
                out recommendedPressure : PressureValue;
            }

            // Estimate treatment duration
            action estimateDuration {
                in severity : Real;
                in patientAge : AgeValue;
                out estimatedTime : DurationValue;
            }

            flow classifyDeformity.deformityType to calculatePressure;
            flow classifyDeformity.severity to calculatePressure;
            flow classifyDeformity.severity to estimateDuration;
            flow calculatePressure.recommendedPressure to report;
            flow estimateDuration.estimatedTime to report;
        }

        perform ConductAssessment;
    }

    part def SplintCustomizationUnit {
        port customizationPort : CustomizationPort;

        action def CustomizeSplint {
            in report : AssessmentReport;
            out spec : CustomizationSpec;

            action designContour {
                in deformityType : DeformityType;
                in earLength : LengthValue;
                in earWidth : LengthValue;
                out contourProfile : String;
            }

            action selectPressureTarget {
                in recommendedPressure : PressureValue;
                out targetPressure : PressureValue;
            }

            action determineBandDimensions {
                in earLength : LengthValue;
                in earWidth : LengthValue;
                out frontLength : LengthValue;
                out rearLength : LengthValue;
            }

            flow designContour.contourProfile to spec;
            flow selectPressureTarget.targetPressure to spec;
            flow determineBandDimensions.frontLength to spec;
            flow determineBandDimensions.rearLength to spec;
        }

        perform CustomizeSplint;
    }

    part def MonitoringUnit {
        port monitoringPort : MonitoringPort;

        action def MonitorProgress {
            in appliedPressure : PressureValue;
            in skinCondition : SkinCondition;
            in adhesionQuality : AdhesionQuality;
            out record : MonitoringRecord;
            out adjustmentNeeded : Boolean;

            action evaluateCorrection {
                in measuredPressure : PressureValue;
                in targetPressure : PressureValue;
                out progressPercent : Real;
            }

            action evaluateSkinSafety {
                in skinCondition : SkinCondition;
                out safeToContinue : Boolean;
            }

            action evaluateAdhesion {
                in adhesionQuality : AdhesionQuality;
                out reapplicationNeeded : Boolean;
            }

            flow evaluateCorrection.progressPercent to record;
            flow evaluateSkinSafety.safeToContinue to adjustmentNeeded;
            flow evaluateAdhesion.reapplicationNeeded to adjustmentNeeded;
        }

        perform MonitorProgress;
    }

    part def TreatmentController {
        part patient : Patient;
        part assessmentUnit : AssessmentUnit;
        part customizationUnit : SplintCustomizationUnit;
        part splintDevice : AuricularSplintDevice;
        part monitoringUnit : MonitoringUnit;

        connection patientAssessment connect patient.assessmentInterface to assessmentUnit.assessmentPort;
        connection assessmentToCustomization connect assessmentUnit.assessmentPort to customizationUnit.customizationPort;
        connection customizationToSplint connect customizationUnit.customizationPort to splintDevice.shell.skinContact;
        connection splintToPatient connect splintDevice.shell.skinContact to patient.skinInterface;
        connection patientToMonitoring connect patient.skinInterface to monitoringUnit.monitoringPort;

        attribute currentStatus : CorrectionStatus = CorrectionStatus::notAssessed;

        state def TreatmentLifecycle {

            state Intake {
                entry action { send AssessPatient(patient) to assessmentUnit; }
                on completion transition to AssessmentComplete;
            }

            state AssessmentComplete {
                entry action { currentStatus = CorrectionStatus::assessed; }
                on completion transition to Customization;
            }

            state Customization {
                entry action { send CustomizeSplint(assessmentReport) to customizationUnit; }
                on completion transition to SplintReady;
            }

            state SplintReady {
                entry action { currentStatus = CorrectionStatus::splintCustomized; }
                on completion transition to Application;
            }

            state Application {
                entry action { send ApplyDevice(patient.infantEar, customizationSpec) to splintDevice; }
                on completion transition to ActiveCorrection;
            }

            state ActiveCorrection {
                entry action { currentStatus = CorrectionStatus::underCorrection; }

                do action MonitorContinuously {
                    send MonitorProgress(appliedPressure, skinCondition, adhesionQuality) to monitoringUnit;
                }

                transition on monitoringUnit.monitoringPort.adjustmentCommand
                    when monitoringUnit.monitoringPort.adjustmentCommand == "adjust"
                    to Adjustment;

                transition on monitoringUnit.monitoringPort.adjustmentCommand
                    when monitoringUnit.monitoringPort.adjustmentCommand == "remove"
                    to Removal;
            }

            state Adjustment {
                entry action { currentStatus = CorrectionStatus::adjustmentNeeded; }
                action ReapplyOrModify {
                    send ModifySplint(customizationSpec) to splintDevice;
                }
                on completion transition to ActiveCorrection;
            }

            state Removal {
                entry action { currentStatus = CorrectionStatus::deviceRemoved; }
                action RemoveDevice {
                    send RemoveSplint() to splintDevice;
                }
                on completion transition to TreatmentComplete;
            }

            state TreatmentComplete {
                entry action { currentStatus = CorrectionStatus::correctionAchieved; }
            }

            transition initial to Intake;
        }

        exhibit TreatmentLifecycle;
    }

    // ===== Requirements =====

    requirement def NonSurgicalCorrection {
        doc <<The system shall correct congenital ear deformities in newborn infants without surgical intervention.>>
        attribute maxPatientAgeDays : AgeValue = 42;
        subject patient : Patient;
        require patient.ageAtIntake <= maxPatientAgeDays;
    }

    requirement def GentleMoldingPressure {
        doc <<The system shall apply a controlled and continuous molding pressure gentle enough for infant delicate skin.>>
        attribute minMoldingPressure : PressureValue = 0.05;
        attribute maxMoldingPressure : PressureValue = 0.5;
        subject splint : AuricularSplintDevice;
        require splint.appliedMoldingPressure >= minMoldingPressure
            and splint.appliedMoldingPressure <= maxMoldingPressure;
    }

    requirement def BiocompatibleMaterials {
        doc <<All components in direct contact with infant skin shall be medical-grade and biocompatible.>>
        subject shell : AuricularShell;
        subject bands : AdhesiveRetentionBand;
        require shell.material.biocompatibilityGrade == "medical-grade"
            and bands.adhesive.hypoallergenic == true;
    }

    requirement def SecureRetention {
        doc <<The splint shall be held securely in place by two skin-safe adhesive retention bands, one anterior and one posterior.>>
        subject device : AuricularSplintDevice;
        require device.frontBand.placement == "anterior"
            and device.rearBand.placement == "posterior";
    }

    requirement def ContinuousWearDuration {
        doc <<The device shall be worn continuously for several weeks to achieve correction.>>
        attribute minWearDays : DurationValue = 14;
        attribute maxWearDays : DurationValue = 42;
        subject treatment : TreatmentController;
        require treatment.patient.ageAtIntake + minWearDays <= 84;
    }

    requirement def MonitoringAndAdjustment {
        doc <<The system shall monitor treatment progress and allow adjustments when necessary.>>
        subject monitoring : MonitoringUnit;
        require monitoring.monitoringPort <> null;
    }

    requirement def CustomFittedSplint {
        doc <<The splint shall be customized for each patient based on assessment of the specific ear deformity.>>
        subject customization : SplintCustomizationUnit;
        subject assessment : AssessmentUnit;
        require assessment.assessmentPort.assessmentReport.deformityType <> null
            and customization.customizationPort.customizationSpec.shellContourProfile <> null;
    }

    requirement def SafetyEffectiveness {
        doc <<The system shall be both safe and effective, using medical-grade materials and ensuring gentle applied pressure.>>
        satisfy NonSurgicalCorrection;
        satisfy GentleMoldingPressure;
        satisfy BiocompatibleMaterials;
        satisfy SecureRetention;
        satisfy ContinuousWearDuration;
        satisfy MonitoringAndAdjustment;
        satisfy CustomFittedSplint;
    }

    // ===== Top-level System =====

    part def EarDeformityCorrectionSystem {
        part controller : TreatmentController;

        satisfy SafetyEffectiveness;

        invariant pressureWithinSafeRange {
            controller.splintDevice.appliedMoldingPressure >= 0.05
            and controller.splintDevice.appliedMoldingPressure <= 0.5
        }

        invariant patientEligibility {
            controller.patient.ageAtIntake >= 1
            and controller.patient.ageAtIntake <= 42
        }
    }

}
