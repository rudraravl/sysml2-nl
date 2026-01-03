package LaryngoscopySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageQualityMetric;
    attribute def IlluminationIntensity;
    attribute def AnatomicalVisibility;
    attribute def TissueDisplacement;
    
    attribute def LightIntensityValue :> ISQ::LuminousIntensityValue;
    attribute def ViewingAngleValue :> ISQ::AngleValue;
    attribute def BladeForceValue :> ISQ::ForceValue;
    
    attribute def ImageResolutionValue {
        attribute horizontalPixels : Real;
        attribute verticalPixels : Real;
    }
    
    item def AirwayImage;
    item def DiagnosticData;
    item def PowerSupply;
    
    port def OpticalOutputPort {
        out visualData : AirwayImage;
    }
    
    port def IlluminationInputPort {
        in lightIntensity : LightIntensityValue;
    }
    
    port def PowerInputPort {
        in electricalPower : ISQ::PowerValue;
    }
    
    port def ImageDisplayPort {
        in imageData : AirwayImage;
        out renderedImage : ImageQualityMetric;
    }
    
    part def LightingModule {
        attribute outputIntensity : LightIntensityValue;
        attribute colorTemperature : ISQ::ThermodynamicTemperatureValue;
        port powerIn : PowerInputPort;
        port lightOut : IlluminationInputPort;
        
        action emitLight {
            in powerLevel : ISQ::PowerValue;
            out illumination : LightIntensityValue;
        }
    }
    
    part def OpticalChannel {
        attribute viewAngle : ViewingAngleValue;
        attribute resolution : ImageResolutionValue;
        attribute focalLength : ISQ::LengthValue;
        port illuminationIn : IlluminationInputPort;
        port imageOut : OpticalOutputPort;
        
        part lensAssembly;
        part fiberOpticBundle;
        part imageProcessor;
        
        action acquireImage {
            in illuminatedField : IlluminationIntensity;
            in viewingAngle : ViewingAngleValue;
            out capturedImage : AirwayImage;
        }
    }
    
    part def BladeAssembly {
        attribute bladeLength : ISQ::LengthValue;
        attribute bladeCurvature : ViewingAngleValue;
        attribute maxForce : BladeForceValue;
        
        action displaceTissue {
            in insertionDepth : ISQ::LengthValue;
            in appliedForce : BladeForceValue;
            out tissuePosition : TissueDisplacement;
        }
    }
    
    part def HandleUnit {
        attribute batteryCapacity : ISQ::EnergyValue;
        attribute currentCharge : Real;
        port powerOut : PowerInputPort;
        
        part batteryPack;
        part powerRegulator;
        part controlSwitch;
        
        action supplyPower {
            in chargeLevel : Real;
            out outputPower : ISQ::PowerValue;
        }
    }
    
    part def VideoDisplay {
        attribute screenDiagonal : ISQ::LengthValue;
        attribute displayBrightness : LightIntensityValue;
        attribute refreshRate : ISQ::FrequencyValue;
        port videoIn : ImageDisplayPort;
        
        action displayImage {
            in imageData : AirwayImage;
            out visualOutput : ImageQualityMetric;
        }
    }
    
    requirement def <'REQ-LRY-001'> PrimaryVisualizationRequirement {
        doc /* The laryngoscopy system shall provide real-time, high-quality 
             visualization of the laryngeal structures including vocal cords, 
             epiglottis, and surrounding anatomy for diagnostic and therapeutic procedures. */
        
        require constraint minimumIllumination {
            doc /* The system shall provide illumination intensity of at least 
                 5000 candela at the target tissue surface. */
        }
        
        require constraint imageResolution {
            doc /* The optical system shall deliver minimum resolution of 
                 1920x1080 pixels for anatomical detail. */
        }
        
        require constraint viewingAngle {
            doc /* The optical channel shall provide a viewing angle between 
                 60 and 90 degrees for adequate field of view. */
        }
    }
    
    requirement def <'REQ-LRY-002'> AirwayExposureRequirement {
        doc /* The system shall enable adequate exposure and visualization 
             of the airway structures through controlled tissue displacement. */
        
        require constraint bladeDesign {
            doc /* The blade assembly shall provide sufficient curvature and 
                 length to expose the glottic opening. */
        }
        
        require constraint forceLimit {
            doc /* Applied tissue displacement force shall not exceed 
                 safe physiological limits to prevent trauma. */
        }
    }
    
    requirement def <'REQ-LRY-003'> OperationalSafetyRequirement {
        doc /* The system shall operate safely without causing patient harm 
             or equipment malfunction during clinical use. */
        
        require constraint thermalSafety {
            doc /* Light source surface temperature shall not exceed 
                 41 degrees Celsius at patient contact points. */
        }
        
        require constraint powerSafety {
            doc /* Electrical isolation shall prevent current leakage 
                 exceeding 100 microamperes. */
        }
        
        require constraint sterilization {
            doc /* Patient-contact components shall withstand standard 
                 sterilization protocols without degradation. */
        }
    }
    
    requirement def <'REQ-LRY-004'> PowerManagementRequirement {
        doc /* The system shall provide reliable power for complete 
             examination procedures. */
        
        require constraint batteryLife {
            doc /* Battery capacity shall support minimum 120 minutes 
                 of continuous operation. */
        }
        
        require constraint powerStability {
            doc /* Output power variation shall not exceed 5 percent 
                 during discharge cycle. */
        }
    }
    
    action def PerformLaryngoscopy {
        in patientAnatomy : TissueDisplacement;
        in procedureType : String;
        out diagnosticImages : AirwayImage;
        out clinicalFindings : DiagnosticData;
        
        first start;
        then action positionBlade {
            in anatomy : TissueDisplacement;
            out bladePosition : ISQ::LengthValue;
            out exposedAirway : AnatomicalVisibility;
        }
        then action activateIllumination {
            out lightingActive : Boolean;
            out illuminationLevel : LightIntensityValue;
        }
        then action captureVisualization {
            in airwayExposure : AnatomicalVisibility;
            in illumination : LightIntensityValue;
            out airwayImages : AirwayImage;
        }
        then action evaluateAnatomy {
            in visualData : AirwayImage;
            out anatomicalAssessment : DiagnosticData;
            out pathologyDetected : Boolean;
        }
        then decide;
            if evaluateAnatomy.pathologyDetected then documentFindings;
            else completeExamination;
        action documentFindings {
            in assessment : DiagnosticData;
            in images : AirwayImage;
            out clinicalReport : DiagnosticData;
        }
        then completeExamination;
        action completeExamination {
            out procedureComplete : Boolean;
        }
        then action withdrawBlade;
        then done;
    }
    
    part def LaryngoscopeSystem {
        doc /* Complete laryngoscopy system for visualization and examination 
             of laryngeal and pharyngeal structures during medical procedures. */
        
        part handle : HandleUnit {
            attribute batteryCapacity = 50.0;
            attribute currentCharge = 0.95;
        }
        
        part blade : BladeAssembly {
            attribute bladeLength = 100.0;
            attribute bladeCurvature = 15.0;
            attribute maxForce = 5.0;
        }
        
        part lightSource : LightingModule {
            attribute outputIntensity = 6000.0;
            attribute colorTemperature = 5500.0;
        }
        
        part opticalSystem : OpticalChannel {
            attribute viewAngle = 75.0;
            attribute focalLength = 25.0;
        }
        
        part display : VideoDisplay {
            attribute screenDiagonal = 150.0;
            attribute refreshRate = 60.0;
        }
        
        connection powerConnection connect handle.powerOut to lightSource.powerIn;
        connection illuminationPath connect lightSource.lightOut to opticalSystem.illuminationIn;
        connection imagePath connect opticalSystem.imageOut to display.videoIn;
        
        action executeProcedure : PerformLaryngoscopy {
            in patientAnatomy;
            in procedureType;
            out diagnosticImages;
            out clinicalFindings;
        }
    }
    
    part laryngoscope : LaryngoscopeSystem {
        satisfy requirement primaryViz : PrimaryVisualizationRequirement;
        satisfy requirement airwayExp : AirwayExposureRequirement;
        satisfy requirement opSafety : OperationalSafetyRequirement;
        satisfy requirement powerMgmt : PowerManagementRequirement;
    }
    
    state def LaryngoscopyProcedureStateMachine {
        entry; then systemIdle;
        
        state systemIdle {
            attribute systemReady : Boolean;
            attribute illuminationActive : Boolean;
        }
        
        transition idleToPreparation
            first systemIdle
            then preparation;
        
        state preparation {
            attribute batteryChecked : Boolean;
        }
        
        transition preparationToInsertion
            first preparation
            then bladeInsertion;
        
        state bladeInsertion {
            attribute insertionDepth : Real;
        }
        
        transition insertionToVisualization
            first bladeInsertion
            then activeVisualization;
        
        state activeVisualization {
            attribute illuminationActive : Boolean;
            attribute imagingActive : Boolean;
            attribute adequateView : Boolean;
        }
        
        transition visualizationToAssessment
            first activeVisualization
            then anatomicalAssessment;
        
        state anatomicalAssessment {
            attribute assessmentComplete : Boolean;
        }
        
        transition assessmentToDocumentation
            first anatomicalAssessment
            then documentation;
        
        state documentation;
        
        transition documentationToWithdrawal
            first documentation
            then bladeWithdrawal;
        
        state bladeWithdrawal;
        
        transition withdrawalToIdle
            first bladeWithdrawal
            then systemIdle;
    }
    
    action def VisualizeLaryngealStructures {
        in illuminationLevel : LightIntensityValue;
        in viewingAngle : ViewingAngleValue;
        out vocalCordImage : AirwayImage;
        out epiglottisImage : AirwayImage;
        out glotticOpening : AnatomicalVisibility;
    }
    
    action def AssessVocalCordFunction {
        in laryngealImages : AirwayImage;
        out cordMobility : DiagnosticData;
        out cordSymmetry : DiagnosticData;
        out lesionDetection : DiagnosticData;
        out functionalAssessment : DiagnosticData;
    }
    
    action def MonitorTissueContact {
        in appliedForce : BladeForceValue;
        in contactDuration : ISQ::TimeValue;
        out safetyStatus : Boolean;
        out forceWarning : Boolean;
    }
}
