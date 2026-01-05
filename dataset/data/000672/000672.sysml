package MaddoxWingPhoriaTestSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def PrismDiopterValue :> Real {
        doc /* Measurement unit for ocular deviation in prism diopters. */
    }
    
    attribute def AngularDeviationValue :> ISQ::AngleValue {
        doc /* Angular measurement of ocular misalignment. */
    }
    
    attribute def LuminanceValue :> ISQ::LuminousIntensityValue {
        doc /* Light intensity for visual stimulus. */
    }
    
    item def VisualStimulus {
        attribute luminance : LuminanceValue;
        attribute position : LengthValue;
        attribute orientation : ISQ::AngleValue;
    }
    
    item def PointLightSource {
        attribute intensity : LuminanceValue;
        attribute wavelength : LengthValue;
    }
    
    item def LinearStimulus {
        attribute orientation : ISQ::AngleValue;
        attribute length : LengthValue;
        attribute apparentIntensity : LuminanceValue;
    }
    
    item def PatientResponse {
        attribute reportedHorizontalOffset : LengthValue;
        attribute reportedVerticalOffset : LengthValue;
        attribute responseTime : TimeValue;
    }
    
    item def PhoriaResult {
        attribute horizontalDeviation : PrismDiopterValue;
        attribute verticalDeviation : PrismDiopterValue;
        attribute esophoria : Boolean;
        attribute exophoria : Boolean;
        attribute hyperphoria : Boolean;
        attribute hypophoria : Boolean;
    }
    
    port def StimulusPort {
        out stimulus : VisualStimulus;
    }
    
    port def ResponsePort {
        in response : PatientResponse;
    }
    
    port def MeasurementPort {
        out result : PhoriaResult;
    }
    
    part def IlluminationSource {
        attribute operatingVoltage : ISQ::ElectricPotentialValue;
        attribute outputIntensity : LuminanceValue;
        port stimulusOut : StimulusPort;
        
        action def GeneratePointLight {
            out pointSource : PointLightSource;
        }
    }
    
    part def MaddoxRod {
        attribute rodSpacing : LengthValue;
        attribute rodDiameter : LengthValue;
        attribute rodOrientation : ISQ::AngleValue;
        port lightIn : StimulusPort;
        port lineOut : StimulusPort;
        
        action def TransformPointToLine {
            in pointLight : PointLightSource;
            out linearImage : LinearStimulus;
            doc /* Transforms point light source into perpendicular linear streak through cylindrical rod array. */
        }
    }
    
    part def CalibrationScale {
        attribute horizontalRange : PrismDiopterValue;
        attribute verticalRange : PrismDiopterValue;
        attribute scaleResolution : PrismDiopterValue;
        
        action def ConvertOffsetToPrismDiopter {
            in offsetDistance : LengthValue;
            in viewingDistance : LengthValue;
            out prismValue : PrismDiopterValue;
        }
    }
    
    part def PatientInterface {
        attribute viewingDistance : LengthValue;
        port uncoveredEyeInput : StimulusPort;
        port coveredEyeInput : StimulusPort;
        port responseOutput : ResponsePort;
        
        action def PerceiveDissociatedImages {
            in directStimulus : PointLightSource;
            in transformedStimulus : LinearStimulus;
            out perceivedSeparation : PatientResponse;
            doc /* Patient perceives point light with one eye and linear streak with other eye. */
        }
    }
    
    part def Examiner {
        port patientResponseIn : ResponsePort;
        port measurementOut : MeasurementPort;
        
        action def InterpretDeviation {
            in patientReport : PatientResponse;
            in calibrationData : CalibrationScale;
            out phoriaAssessment : PhoriaResult;
            doc /* Examiner interprets patient response to quantify ocular deviation. */
        }
    }
    
    action def PerformPhoriaAssessment {
        in testingDistance : LengthValue;
        out finalResult : PhoriaResult;
        
        first start;
        then merge assessmentCycle;
        
        then action setupTest {
            out initializedDistance : LengthValue;
            out calibratedScale : CalibrationScale;
        }
        
        then action generateStimulus {
            out pointLight : PointLightSource;
        }
        
        flow generateStimulus.pointLight to transformStimulus.pointLight;
        
        then action transformStimulus {
            in pointLight : PointLightSource;
            out linearStreak : LinearStimulus;
        }
        
        flow generateStimulus.pointLight to presentToPatient.directStimulus;
        flow transformStimulus.linearStreak to presentToPatient.transformedStimulus;
        
        then action presentToPatient {
            in directStimulus : PointLightSource;
            in transformedStimulus : LinearStimulus;
            out patientObservation : PatientResponse;
        }
        
        flow presentToPatient.patientObservation to analyzeResponse.patientReport;
        
        then action analyzeResponse {
            in patientReport : PatientResponse;
            in scaleData : CalibrationScale;
            out measurement : PhoriaResult;
        }
        
        then decide;
            if analyzeResponse.measurement.horizontalDeviation > 0.0 then recordResult;
            else repeatMeasurement;
        
        action repeatMeasurement then assessmentCycle;
        
        action recordResult {
            in finalMeasurement : PhoriaResult;
        }
        then done;
    }
    
    part def MaddoxWingPhoriaTestDevice {
        doc /* Maddox wing device for clinical assessment of ocular alignment. */
    }
    
    part maddoxWingSystem : MaddoxWingPhoriaTestDevice {
        doc /* Complete Maddox wing system for measuring latent ocular deviation (phoria). */
        
        part illuminator : IlluminationSource {
            attribute :>> operatingVoltage = 6.0 [SI::V];
            attribute :>> outputIntensity = 50.0 [SI::cd];
        }
        
        part maddoxRodAssembly : MaddoxRod {
            attribute :>> rodSpacing = 0.5 [SI::mm];
            attribute :>> rodDiameter = 0.3 [SI::mm];
            attribute :>> rodOrientation = 90.0 [SI::deg];
        }
        
        part scale : CalibrationScale {
            attribute :>> horizontalRange = 20.0;
            attribute :>> verticalRange = 15.0;
            attribute :>> scaleResolution = 0.5;
        }
        
        part patient : PatientInterface {
            attribute :>> viewingDistance = 0.33 [SI::m];
        }
        
        part examiner : Examiner;
        
        connect illuminator.stimulusOut to maddoxRodAssembly.lightIn;
        connect illuminator.stimulusOut to patient.uncoveredEyeInput;
        connect maddoxRodAssembly.lineOut to patient.coveredEyeInput;
        connect patient.responseOutput to examiner.patientResponseIn;
        
        perform action phoriaTest : PerformPhoriaAssessment {
            in testingDistance = patient.viewingDistance;
            out finalResult : PhoriaResult;
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'MWS-REQ-001'> measureLatentDeviation : FunctionalRequirement {
        doc /* The Maddox wing system shall measure latent ocular deviation (phoria) 
               by dissociating binocular fusion through presentation of dissimilar 
               stimuli to each eye. */
        subject maddoxWingSystem;
    }
    
    requirement <'MWS-REQ-002'> horizontalPhoriaRange : PerformanceRequirement {
        doc /* The system shall measure horizontal phoria across a range of 
               at least 20 prism diopters. */
        require constraint {
            maddoxWingSystem.scale.horizontalRange >= 20.0
        }
    }
    
    requirement <'MWS-REQ-003'> verticalPhoriaRange : PerformanceRequirement {
        doc /* The system shall measure vertical phoria across a range of 
               at least 15 prism diopters. */
        require constraint {
            maddoxWingSystem.scale.verticalRange >= 15.0
        }
    }
    
    requirement <'MWS-REQ-004'> measurementResolution : PerformanceRequirement {
        doc /* The system shall provide measurement resolution of 0.5 prism diopters 
               or better. */
        require constraint {
            maddoxWingSystem.scale.scaleResolution <= 0.5
        }
    }
    
    requirement <'MWS-REQ-005'> patientSafety : SafetyRequirement {
        doc /* The illumination source shall not exceed safe luminance levels 
               for patient viewing. */
        require constraint {
            maddoxWingSystem.illuminator.outputIntensity <= 100.0 [SI::cd]
        }
    }
    
    requirement <'MWS-REQ-006'> standardViewingDistance : PerformanceRequirement {
        doc /* The system shall operate at standard near viewing distance 
               of 33 centimeters. */
        require constraint {
            maddoxWingSystem.patient.viewingDistance == 0.33 [SI::m]
        }
    }
    
    requirement <'MWS-SYS-001'> systemMission {
        doc /* The Maddox wing system shall enable clinical assessment of ocular 
               alignment by measuring horizontal and vertical phoria through 
               dissociation of binocular fusion. */
        
        assume constraint operatingConditions {
            doc /* System operates in controlled clinical environment with 
                   cooperative patient capable of reporting visual perception. */
        }
        
        require measureLatentDeviation;
        require horizontalPhoriaRange;
        require verticalPhoriaRange;
        require measurementResolution;
        require patientSafety;
        require standardViewingDistance;
    }
    
    satisfy measureLatentDeviation by maddoxWingSystem.phoriaTest;
    satisfy horizontalPhoriaRange by maddoxWingSystem.scale;
    satisfy verticalPhoriaRange by maddoxWingSystem.scale;
    satisfy measurementResolution by maddoxWingSystem.scale;
    satisfy patientSafety by maddoxWingSystem.illuminator;
    satisfy standardViewingDistance by maddoxWingSystem.patient;
}
