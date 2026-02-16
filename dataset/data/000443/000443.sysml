package DrYoungsIdealRectalDilatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DiameterValue :> ISQ::LengthValue;
    attribute def InsertionDepthValue :> ISQ::LengthValue;
    attribute def ForceValue :> ISQ::ForceValue;
    attribute def ComfortScore :> Real;
    attribute def DurationValue :> ISQ::DurationValue;
    
    enum def MaterialType {
        medicalGradeHardRubber;
        biocompatibleSilicone;
        autoclavablePlastic;
    }
    
    enum def SurfaceFinish {
        highlyPolished;
        smoothMatte;
    }
    
    item def SterileLubricant {
        attribute viscosity : Real;
        attribute waterSoluble : Boolean;
        attribute hypoallergenic : Boolean;
    }
    
    attribute def DilatorSize {
        attribute diameter : DiameterValue;
        attribute insertionLength : InsertionDepthValue;
        attribute taperAngle : Real;
    }
    
    part def DilatorInstrument {
        attribute size : DilatorSize;
        attribute material : MaterialType;
        attribute surfaceFinish : SurfaceFinish;
        attribute sterilized : Boolean;
    }
    
    part def GraduatedDilatorSet {
        attribute setSize : Integer;
        part dilators : DilatorInstrument[4..12] ordered;
    }
    
    part def Patient {
        attribute medicalHistory : String[*];
        attribute currentCondition : String;
        attribute painThreshold : ComfortScore;
        attribute consentProvided : Boolean;
    }
    
    part def Clinician {
        attribute certification : String;
        attribute yearsExperience : Real;
        attribute trainingCompleted : Boolean;
    }
    
    port def TherapeuticApplicationPort {
        out item appliedDilator : DilatorInstrument;
        in attribute patientComfort : ComfortScore;
        out attribute appliedForce : ForceValue;
        in attribute tissueResistance : ForceValue;
    }
    
    port def PatientMonitoringPort {
        in attribute vitalSigns : Real;
        in attribute painLevel : ComfortScore;
        in attribute anxietyLevel : Real;
        out attribute reassurance : String;
    }
    
    action def PreparePatient {
        in patient : Patient;
        in clinician : Clinician;
        out patientReady : Boolean;
        out consentConfirmed : Boolean;
    }
    
    action def SterilizeInstrument {
        in dilator : DilatorInstrument;
        in sterilizationMethod : String;
        out sterilizedDilator : DilatorInstrument;
    }
    
    action def ApplyLubricant {
        in dilator : DilatorInstrument;
        in lubricant : SterileLubricant;
        out lubricatedDilator : DilatorInstrument;
    }
    
    action def AssessPatientAnatomy {
        in patient : Patient;
        out baselineDiameter : DiameterValue;
        out targetDiameter : DiameterValue;
        out treatmentPlan : String;
    }
    
    action def SelectInitialDilator {
        in dilatorSet : GraduatedDilatorSet;
        in baselineDiameter : DiameterValue;
        out selectedDilator : DilatorInstrument;
    }
    
    action def InsertDilator {
        in dilator : DilatorInstrument;
        in targetDepth : InsertionDepthValue;
        in maxForce : ForceValue;
        out insertionDepth : InsertionDepthValue;
        out patientResponse : ComfortScore;
        out successful : Boolean;
    }
    
    action def MaintainDilation {
        in dilator : DilatorInstrument;
        in duration : DurationValue;
        out tissueAdaptation : Boolean;
    }
    
    action def MonitorPatientResponse {
        in patient : Patient;
        out comfortLevel : ComfortScore;
        out adverseReaction : Boolean;
        out vitalStability : Boolean;
    }
    
    action def WithdrawDilator {
        in dilator : DilatorInstrument;
        out removalComplete : Boolean;
    }
    
    action def EvaluateProgression {
        in currentDilator : DilatorInstrument;
        in dilatorSet : GraduatedDilatorSet;
        in patientTolerance : ComfortScore;
        in targetDiameter : DiameterValue;
        out progressToNext : Boolean;
        out nextDilator : DilatorInstrument;
        out goalAchieved : Boolean;
    }
    
    action def ProvidePostProcedureCare {
        in patient : Patient;
        out instructions : String[*];
        out followUpScheduled : Boolean;
    }
    
    action def PerformGradualDilationTherapy {
        in patient : Patient;
        in clinician : Clinician;
        in dilatorSet : GraduatedDilatorSet;
        in lubricant : SterileLubricant;
        in sessionDuration : DurationValue;
        out finalDiameter : DiameterValue;
        out treatmentSuccess : Boolean;
        
        private attribute currentDilator : DilatorInstrument;
        private attribute procedureHalted : Boolean;
        
        first start;
        
        then action preparePatient : PreparePatient {
            in patient = PerformGradualDilationTherapy::patient;
            in clinician = PerformGradualDilationTherapy::clinician;
            out patientReady;
            out consentConfirmed;
        }
        
        then action assessAnatomy : AssessPatientAnatomy {
            in patient = PerformGradualDilationTherapy::patient;
            out baselineDiameter;
            out targetDiameter;
            out treatmentPlan;
        }
        
        then action selectDilator : SelectInitialDilator {
            in dilatorSet = PerformGradualDilationTherapy::dilatorSet;
            in baselineDiameter = assessAnatomy.baselineDiameter;
            out selectedDilator;
        }
        
        then assign currentDilator := selectDilator.selectedDilator;
        
        then merge dilationCycle;
        
        then action sterilize : SterilizeInstrument {
            in dilator = currentDilator;
            in sterilizationMethod = "autoclave";
            out sterilizedDilator;
        }
        
        then action lubricate : ApplyLubricant {
            in dilator = sterilize.sterilizedDilator;
            in lubricant = PerformGradualDilationTherapy::lubricant;
            out lubricatedDilator;
        }
        
        then action insert : InsertDilator {
            in dilator = lubricate.lubricatedDilator;
            in targetDepth = 90.0 [SI::mm];
            in maxForce = 8.0 [SI::N];
            out insertionDepth;
            out patientResponse;
            out successful;
        }
        
        then action monitor : MonitorPatientResponse {
            in patient = PerformGradualDilationTherapy::patient;
            out comfortLevel;
            out adverseReaction;
            out vitalStability;
        }
        
        then decide;
            if monitor.adverseReaction or not monitor.vitalStability then abortSequence;
            if monitor.comfortLevel >= 5.0 and insert.successful then continueTreatment;
        
        action continueTreatment {
            first action maintain : MaintainDilation {
                in dilator = insert.dilator;
                in duration = 120.0 [SI::s];
                out tissueAdaptation;
            }
            
            then action withdraw : WithdrawDilator {
                in dilator = insert.dilator;
                out removalComplete;
            }
            
            then action evaluate : EvaluateProgression {
                in currentDilator = PerformGradualDilationTherapy::currentDilator;
                in dilatorSet = PerformGradualDilationTherapy::dilatorSet;
                in patientTolerance = monitor.comfortLevel;
                in targetDiameter = assessAnatomy.targetDiameter;
                out progressToNext;
                out nextDilator;
                out goalAchieved;
            }
            
            then decide;
                if evaluate.progressToNext and not evaluate.goalAchieved then advanceSize;
                if evaluate.goalAchieved or not evaluate.progressToNext then completeSession;
            
            action advanceSize {
                then assign currentDilator := evaluate.nextDilator;
            }
            then dilationCycle;
        }
        
        action abortSequence {
            first action emergencyWithdraw : WithdrawDilator {
                in dilator = insert.dilator;
            }
            then assign procedureHalted := true;
        }
        then completeSession;
        
        action completeSession {
            first action provideCare : ProvidePostProcedureCare {
                in patient = PerformGradualDilationTherapy::patient;
                out instructions;
                out followUpScheduled;
            }
            
            then assign finalDiameter := currentDilator.size.diameter;
            then assign treatmentSuccess := (finalDiameter >= assessAnatomy.targetDiameter);
        }
        then done;
    }
    
    part drYoungsSystem {
        doc /* Dr. Young's Ideal Rectal Dilator System for therapeutic dilation of rectal strictures. */
        
        part dilatorSet : GraduatedDilatorSet {
            attribute :>> setSize = 8;
            part :>> dilators : DilatorInstrument[8] ordered {
                attribute :>> material = MaterialType::medicalGradeHardRubber;
                attribute :>> surfaceFinish = SurfaceFinish::highlyPolished;
                attribute :>> sterilized = true;
            }
        }
        
        part lubricant : SterileLubricant {
            attribute :>> viscosity = 1.2;
            attribute :>> waterSoluble = true;
            attribute :>> hypoallergenic = true;
        }
        
        part clinician : Clinician {
            attribute :>> certification = "Board Certified Proctologist";
            attribute :>> yearsExperience = 10.0;
            attribute :>> trainingCompleted = true;
        }
        
        part patient : Patient {
            attribute :>> consentProvided = true;
        }
        
        port therapeuticPort : TherapeuticApplicationPort;
        port monitoringPort : PatientMonitoringPort;
        
        perform action therapy : PerformGradualDilationTherapy {
            in patient = drYoungsSystem::patient;
            in clinician = drYoungsSystem::clinician;
            in dilatorSet = drYoungsSystem::dilatorSet;
            in lubricant = drYoungsSystem::lubricant;
            in sessionDuration = 1800.0 [SI::s];
            out finalDiameter;
            out treatmentSuccess;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide graduated rectal dilation therapy to treat strictures, 
               hemorrhoids, and anorectal conditions through controlled, progressive stretching 
               of tissue using a series of increasingly larger dilator instruments under 
               medical supervision. */
    }
    
    requirement def SafetyRequirement {
        doc /* All dilator instruments shall be manufactured from biocompatible, sterilizable 
               materials with smooth, non-traumatic surfaces. */
    }
    
    requirement def GradualProgressionRequirement {
        doc /* The dilator set shall provide graduated sizes with incremental diameter increases 
               not exceeding 4mm between consecutive instruments to ensure safe, comfortable progression. */
    }
    
    requirement def PatientComfortRequirement {
        doc /* The procedure shall be performed with continuous patient monitoring and shall be 
               halted if patient comfort falls below acceptable threshold. */
    }
    
    requirement def SterilizationRequirement {
        doc /* All instruments shall be properly sterilized before each use according to 
               established medical protocols. */
    }
    
    requirement def ClinicalTrainingRequirement {
        doc /* The system shall only be operated by trained, certified medical professionals 
               with appropriate clinical experience. */
    }
    
    requirement therapeuticObjective {
        doc /* Dr. Young's Ideal Rectal Dilator System provides controlled therapeutic dilation 
               for treatment of rectal strictures, post-surgical stenosis, hemorrhoidal conditions, 
               and other anorectal disorders requiring gradual tissue expansion through progressive 
               application of graduated dilator instruments under medical supervision with continuous 
               patient monitoring and comfort assessment. */
        
        require PrimaryFunctionRequirement;
        require SafetyRequirement;
        require GradualProgressionRequirement;
        require PatientComfortRequirement;
        require SterilizationRequirement;
        require ClinicalTrainingRequirement;
    }
}
