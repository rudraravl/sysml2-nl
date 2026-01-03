package 'Worth4DotTestSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    enum def PerceptionResult {
        fourDots;
        twoDots;
        threeDots;
        fiveDots;
    }

    enum def DiagnosisType {
        normalBinocularVision;
        leftEyeSuppression;
        rightEyeSuppression;
        diplopia;
    }

    attribute def ColorFilter {
        attribute filterType : String;
        attribute transmittedWavelength : LengthValue;
    }

    item def TestStimulus {
        attribute redDotCount : Integer;
        attribute greenDotCount : Integer;
        attribute whiteDotCount : Integer;
        attribute totalDots : Integer;
    }

    attribute def LuminanceValue :> LuminousIntensityValue;

    port def StimulusPort {
        out stimulus : TestStimulus;
        out luminance : LuminanceValue;
    }

    port def ResponsePort {
        in patientReport : PerceptionResult;
    }

    port def DiagnosticPort {
        out diagnosis : DiagnosisType;
    }

    port def PowerPort {
        in powerSupply : PowerValue;
    }

    part def IlluminationUnit {
        doc /* Provides controlled illumination for the four-dot pattern. */
        
        port powerIn : PowerPort;
        port stimulusOut : StimulusPort;
        
        attribute operatingVoltage : Real;
        attribute redLightIntensity : LuminanceValue;
        attribute greenLightIntensity : LuminanceValue;
        attribute whiteLightIntensity : LuminanceValue;
        
        part redDot {
            attribute position : String;
            attribute color : String = "red";
        }
        
        part greenDotTop {
            attribute position : String = "top";
            attribute color : String = "green";
        }
        
        part greenDotBottom {
            attribute position : String = "bottom";
            attribute color : String = "green";
        }
        
        part whiteDot {
            attribute position : String = "center";
            attribute color : String = "white";
        }
    }

    part def FilterGlasses {
        doc /* Red-green anaglyph glasses for ocular dissociation. */
        
        attribute viewingDistance : LengthValue;
        
        part rightLens {
            attribute filterColor : String = "red";
            attribute transmittedWavelength : LengthValue = 620.0[nm];
        }
        
        part leftLens {
            attribute filterColor : String = "green";
            attribute transmittedWavelength : LengthValue = 530.0[nm];
        }
    }

    part def PatientInterface {
        doc /* Interface for patient observation and response collection. */
        
        port responseOut : ResponsePort;
        
        attribute observationTime : TimeValue;
        attribute reportedPerception : PerceptionResult;
    }

    part def DiagnosticProcessor {
        doc /* Analyzes patient responses to determine binocular vision status. */
        
        port responseIn : ResponsePort;
        port diagnosticOut : DiagnosticPort;
        
        perform action analyzeBinocularVision;
    }

    action def InitializeTest {
        out testReady : Boolean;
        
        attribute standardStimulus : TestStimulus {
            :>> redDotCount = 1;
            :>> greenDotCount = 2;
            :>> whiteDotCount = 1;
            :>> totalDots = 4;
        }
    }

    action def PresentStimulus {
        in stimulus : TestStimulus;
        in viewingDistance : LengthValue;
        out stimulusPresented : Boolean;
    }

    action def CapturePatientResponse {
        in observationDuration : TimeValue;
        out perception : PerceptionResult;
    }

    action def AnalyzeBinocularVision {
        in patientPerception : PerceptionResult;
        out clinicalDiagnosis : DiagnosisType;
        
        first start;
        then decide;
            if patientPerception == PerceptionResult::fourDots then normalVision;
            if patientPerception == PerceptionResult::twoDots then leftSuppression;
            if patientPerception == PerceptionResult::threeDots then rightSuppression;
            if patientPerception == PerceptionResult::fiveDots then diplopia;
        
        action normalVision {
            assign clinicalDiagnosis = DiagnosisType::normalBinocularVision;
        }
        then done;
        
        action leftSuppression {
            assign clinicalDiagnosis = DiagnosisType::leftEyeSuppression;
        }
        then done;
        
        action rightSuppression {
            assign clinicalDiagnosis = DiagnosisType::rightEyeSuppression;
        }
        then done;
        
        action diplopia {
            assign clinicalDiagnosis = DiagnosisType::diplopia;
        }
        then done;
    }

    action def ConductWorth4DotTest {
        doc /* 
            Orchestrates the complete Worth 4 Dot test procedure from initialization 
            through stimulus presentation, response capture, and diagnostic analysis.
        */
        
        in patientID : String;
        out finalDiagnosis : DiagnosisType;
        out testComplete : Boolean;
        
        first start;
        
        then action initialize : InitializeTest {
            out testReady;
        }
        
        then action present : PresentStimulus {
            in stimulus = initialize.standardStimulus;
            in viewingDistance = 40.0[cm];
            out stimulusPresented;
        }
        
        then action capture : CapturePatientResponse {
            in observationDuration = 5.0[s];
            out perception;
        }
        
        then action analyze : AnalyzeBinocularVision {
            in patientPerception = capture.perception;
            out clinicalDiagnosis;
        }
        
        then action recordResults {
            assign finalDiagnosis = analyze.clinicalDiagnosis;
            assign testComplete = true;
        }
        
        then done;
    }

    part def Worth4DotTestSystem {
        part illumination : IlluminationUnit;
        part glasses : FilterGlasses;
        part patientInterface : PatientInterface;
        part processor : DiagnosticProcessor;
    }

    part worth4DotTestSystem : Worth4DotTestSystem {
        doc /* 
            The Worth 4 Dot Test System is a clinical diagnostic instrument designed to 
            evaluate binocular vision and detect abnormalities in ocular alignment and fusion.
            
            Its primary function is to assess a patient's ability to achieve and maintain 
            binocular fusion by presenting a standardized four-dot visual stimulus while the 
            patient wears red-green filter glasses. The system dissociates the visual input 
            to each eye through chromatic filtering: the right eye (red filter) perceives 
            only the red dot and white dot, while the left eye (green filter) perceives the 
            two green dots and white dot. A patient with normal binocular vision will report 
            seeing four dots through fusion of the monocular images. Deviations from this 
            response indicate suppression of one eye, diplopia, or abnormal retinal 
            correspondence, enabling clinicians to diagnose conditions such as strabismus, 
            amblyopia, or binocular vision dysfunction.
        */
        
        part illumination : IlluminationUnit {
            :>> operatingVoltage = 12.0;
            :>> redLightIntensity = 80.0[cd];
            :>> greenLightIntensity = 80.0[cd];
            :>> whiteLightIntensity = 100.0[cd];
        }
        
        part glasses : FilterGlasses {
            :>> viewingDistance = 40.0[cm];
        }
        
        part patientInterface : PatientInterface {
            :>> observationTime = 5.0[s];
        }
        
        part processor : DiagnosticProcessor;
        
        connect illumination.stimulusOut to processor.responseIn;
        connect patientInterface.responseOut to processor.responseIn;
        
        perform action executeTest : ConductWorth4DotTest {
            in patientID = "PT-001";
            out finalDiagnosis;
            out testComplete;
        }
    }

    requirement def BinocularVisionAssessmentCapability {
        doc /* The system shall provide the capability to assess binocular vision status. */
        
        subject testSystem : Worth4DotTestSystem;
        
        require constraint {
            testSystem.executeTest.testComplete == true
        }
    }

    requirement def StimulusPresentationRequirement {
        doc /* The system shall present a standard four-dot pattern with controlled luminance. */
        
        subject testSystem : Worth4DotTestSystem;
        
        require constraint {
            testSystem.illumination.redLightIntensity > 0.0[cd] and
            testSystem.illumination.greenLightIntensity > 0.0[cd] and
            testSystem.illumination.whiteLightIntensity > 0.0[cd]
        }
    }

    requirement def OcularDissociationRequirement {
        doc /* The system shall dissociate visual input to each eye using chromatic filters. */
        
        subject testSystem : Worth4DotTestSystem;
        
        require constraint {
            testSystem.glasses.rightLens.filterColor == "red" and
            testSystem.glasses.leftLens.filterColor == "green"
        }
    }

    requirement def DiagnosticAccuracyRequirement {
        doc /* The system shall correctly classify binocular vision status based on patient perception. */
        
        subject testSystem : Worth4DotTestSystem;
        
        require constraint {
            testSystem.executeTest.finalDiagnosis in DiagnosisType
        }
    }

    requirement systemRequirements {
        doc /* Top-level requirements for the Worth 4 Dot Test System. */
        
        subject testSystem : Worth4DotTestSystem;
        
        require assessmentCapability : BinocularVisionAssessmentCapability;
        require stimulusPresentation : StimulusPresentationRequirement;
        require ocularDissociation : OcularDissociationRequirement;
        require diagnosticAccuracy : DiagnosticAccuracyRequirement;
    }
}
