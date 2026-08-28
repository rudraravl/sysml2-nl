package 'Infant Ear Deformity Correction System' {
    private import ScalarValues::*;

    package Definitions {
        attribute def CorrectionPressure :> Real;
        attribute def TreatmentDuration :> Real;
        attribute def MoldingForce :> Real;
        attribute def CartilageFlexibility :> Real;
        attribute def DeformityType :> String;
        attribute def CorrectionProgress :> Real;
        attribute def ContourProfile :> String;

        item def AssessmentRecord {
            attribute deformityType : DeformityType;
            attribute targetPressure : CorrectionPressure;
            attribute estimatedDuration : TreatmentDuration;
            attribute flexibility : CartilageFlexibility;
        }

        item def ProgressRecord {
            attribute correctionAchieved : CorrectionProgress;
            attribute pressureApplied : CorrectionPressure;
            attribute timeElapsed : TreatmentDuration;
        }

        item def AdjustmentCommand {
            attribute newPressure : CorrectionPressure;
        }

        item def StartSignal;
        item def SplintReadySignal;
        item def ApplicationCompleteSignal;
        item def ShapeAchievedSignal;
        item def OverPressureAlert;
        item def UnderPressureAlert;
        item def AdjustmentResolvedSignal;
        item def RemovalSignal;

        part def SiliconeShell {
            attribute material : String = "medical-grade biocompatible silicone";
            attribute hardness : Real;
            attribute contourProfile : ContourProfile;
            attribute targetPressure : CorrectionPressure;
            attribute appliedPressure : CorrectionPressure;
        }

        part def RetentionBand {
            attribute position : String;
            attribute adhesiveType : String = "skin-safe acrylic adhesive";
            attribute adhesionForce : MoldingForce;
        }

        part def AuricularSplintDevice {
            attribute maxSafePressure : CorrectionPressure;
            attribute minEffectivePressure : CorrectionPressure;
            attribute appliedPressure : CorrectionPressure;
            part shell : SiliconeShell;
            part frontBand : RetentionBand;
            part rearBand : RetentionBand;
        }

        part def InfantEar {
            attribute deformityType : DeformityType;
            attribute flexibility : CartilageFlexibility;
            attribute currentShape : ContourProfile;
            attribute targetShape : ContourProfile;
        }

        part def PatientInfant {
            attribute age : Real;
            attribute weight : Real;
            part ear : InfantEar;
        }

        connection def SplintApplication {
            end splintEnd : AuricularSplintDevice;
            end earEnd : InfantEar;
        }

        action def AssessDeformity {
            in patient : PatientInfant;
            out assessment : AssessmentRecord;
        }

        action def CustomizeSplint {
            in assessment : AssessmentRecord;
            out splint : AuricularSplintDevice;
        }

        action def ApplySplint {
            in splint : AuricularSplintDevice;
            in patient : PatientInfant;
        }

        action def MonitorProgress {
            in patient : PatientInfant;
            in splint : AuricularSplintDevice;
            out progress : ProgressRecord;
        }

        action def AdjustSplint {
            inout splint : AuricularSplintDevice;
            in command : AdjustmentCommand;
        }

        action def RemoveSplint {
            in splint : AuricularSplintDevice;
            in patient : PatientInfant;
        }

        state def TreatmentLifecycle;

        part def AuricularSplintSystem {
            part patient : PatientInfant;
            part device : AuricularSplintDevice;
            connection splintApplication : SplintApplication[0..1]
                connect device to patient.ear;
            action assess : AssessDeformity;
            action customize : CustomizeSplint;
            action apply : ApplySplint;
            action monitor : MonitorProgress;
            action adjust : AdjustSplint;
            action remove : RemoveSplint;
            exhibit state 'treatment lifecycle' : TreatmentLifecycle;
        }

        requirement def PressureSafetyRequirement {
            doc /* The maximum applied pressure shall not exceed 5 kPa to ensure the infant's delicate skin is not injured. The applied pressure shall always be less than or equal to the device's maximum safe pressure. */;
        }

        requirement def EffectivenessRequirement {
            doc /* The device shall apply at least the minimum effective pressure to correct the deformity over the treatment period. */;
            attribute minCorrection : CorrectionProgress = 0.9;
        }

        requirement def BiocompatibilityRequirement {
            doc /* All materials in contact with the patient shall be medical-grade and biocompatible. */;
        }

        requirement def RetentionRequirement {
            doc /* The two retention bands shall securely hold the splint shell in place during the entire treatment duration. */;
        }

        requirement def AgeWindowRequirement {
            doc /* Treatment shall be initiated within the first few weeks after birth to leverage the natural flexibility of the infant's ear cartilage. */;
        }

        requirement def ContinuousMonitoringRequirement {
            doc /* The treatment progress shall be monitored regularly to ensure proper correction and detect any need for adjustment. */;
        }
    }

    package Usages {
        private import Definitions::*;

        individual def Patient_1 :> PatientInfant;
        individual def Splint_1 :> AuricularSplintDevice;
        individual def System_1 :> AuricularSplintSystem;

        individual part patient_1 : Patient_1 {
            :>> age = 14;
            :>> weight = 3.5;
            part ear : InfantEar {
                :>> deformityType = "Stahl's ear";
                :>> flexibility = 0.85;
                :>> currentShape = "deformed helical rim";
                :>> targetShape = "natural helical rim";
            }
        }

        individual part splint_1 : Splint_1 {
            :>> maxSafePressure = 5.0;
            :>> minEffectivePressure = 1.2;
            :>> appliedPressure = 2.8;
            part shell : SiliconeShell {
                :>> hardness = 30;
                :>> contourProfile = "custom contoured anatomical fit";
                :>> targetPressure = 2.8;
                :>> appliedPressure = 2.8;
            }
            part frontBand : RetentionBand {
                :>> position = "anterior";
                :>> adhesionForce = 0.8;
            }
            part rearBand : RetentionBand {
                :>> position = "posterior";
                :>> adhesionForce = 0.8;
            }
        }

        individual part system_1 : System_1 {
            :>> patient :> patient_1;
            :>> device :> splint_1;

            state 'treatment lifecycle' : TreatmentLifecycle {
                entry; then 'patient intake';
                state 'patient intake';
                accept StartSignal
                    then assessment;
                state assessment {
                    do assess;
                }
                accept AssessmentRecord
                    then customization;
                state customization {
                    do customize;
                }
                accept SplintReadySignal
                    then application;
                state application {
                    do apply;
                }
                accept ApplicationCompleteSignal
                    then 'active correction';
                state 'active correction' {
                    do monitor;
                }
                accept ShapeAchievedSignal
                    then removal;
                accept OverPressureAlert
                    then adjustment;
                accept UnderPressureAlert
                    then adjustment;
                state adjustment {
                    do adjust;
                }
                accept AdjustmentResolvedSignal
                    then 'active correction';
                state removal {
                    do remove;
                }
                accept RemovalSignal
                    then completed;
                state completed;
            }

            timeslice system_1_intake {
                perform action :>> assess {
                    in :>> patient :> patient_1;
                }
            }
            then timeslice system_1_customization {
                perform action :>> customize {
                    out :>> splint :> splint_1;
                }
            }
            then timeslice system_1_application {
                perform action :>> apply {
                    in :>> splint :> splint_1;
                    in :>> patient :> patient_1;
                }
            }
            then timeslice system_1_correction {
                perform action :>> monitor {
                    in :>> patient :> patient_1;
                    in :>> splint :> splint_1;
                }
            }
            then timeslice system_1_removal {
                perform action :>> remove {
                    in :>> splint :> splint_1;
                    in :>> patient :> patient_1;
                }
            }
        }
    }

    package Requirements {
        private import Definitions::*;
        private import Usages::*;

        requirement pressureSafety : PressureSafetyRequirement {
            subject device : AuricularSplintDevice;
        }

        requirement effectiveness : EffectivenessRequirement {
            subject device : AuricularSplintDevice;
        }

        requirement biocompatibility : BiocompatibilityRequirement {
            subject device : AuricularSplintDevice;
        }

        requirement retention : RetentionRequirement {
            subject device : AuricularSplintDevice;
        }

        requirement ageWindow : AgeWindowRequirement {
            subject patient : PatientInfant;
        }

        requirement monitoring : ContinuousMonitoringRequirement {
            subject system : AuricularSplintSystem;
        }
    }
}
