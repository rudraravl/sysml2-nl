package 'Morphix Chameleon System' {
    private import ScalarValues::*;
    
    value type LightIntensity :> Real;
    value type Wavelength :> Real;
    value type AdaptationSpeed :> Real;
    value type PatternAccuracy :> Real;
    value type ResponseTime :> Real;
    
    item def OpticalData {
        attribute intensity : LightIntensity;
        attribute wavelength : Wavelength;
        attribute spatialPattern : String;
    }
    item def EnvironmentalSignature {
        attribute dominantColors : String;
        attribute textureMap : String;
        attribute averageIntensity : LightIntensity;
    }
    item def ThreatAssessment {
        attribute threatLevel : Real;
        attribute urgency : AdaptationSpeed;
    }
    item def AdaptationCommand {
        attribute targetPattern : EnvironmentalSignature;
        attribute changeSpeed : AdaptationSpeed;
    }
    item def PerformanceReport {
        attribute accuracy : PatternAccuracy;
        attribute responseTime : ResponseTime;
    }
    
    part def OpticalSensorArray {
        port visualOut {
            out rawVisualData : OpticalData;
        }
        action captureVisuals {
            out rawVisualData : OpticalData;
        }
    }
    
    part def PatternAnalysisUnit {
        port visualIn {
            in rawVisualData : OpticalData;
        }
        port signatureOut {
            out environmentalSignature : EnvironmentalSignature;
        }
        action analyzePattern {
            in rawVisualData : OpticalData;
            out environmentalSignature : EnvironmentalSignature;
        }
    }
    
    part def ThreatAssessmentModule {
        port signatureIn {
            in environmentalSignature : EnvironmentalSignature;
        }
        port threatOut {
            out threatLevel : ThreatAssessment;
        }
        action assessThreat {
            in environmentalSignature : EnvironmentalSignature;
            out threatLevel : ThreatAssessment;
        }
    }
    
    state machine def AdaptationControllerBehavior {
        state idle;
        state analyzing;
        state computing;
        state adapting;
        state monitoring;
        
        transition from idle to analyzing;
        transition from analyzing to computing;
        transition from computing to adapting;
        transition from adapting to monitoring;
        transition from monitoring to analyzing;
    }
    
    part def AdaptationController {
        port signatureIn {
            in environmentalSignature : EnvironmentalSignature;
        }
        port threatIn {
            in threatLevel : ThreatAssessment;
        }
        port feedbackIn {
            in performanceReport : PerformanceReport;
        }
        port commandOut {
            out camouflageCommand : AdaptationCommand;
        }
        
        action computeCamouflage {
            in signature : EnvironmentalSignature;
            in threat : ThreatAssessment;
            in feedback : PerformanceReport;
            out command : AdaptationCommand;
        }
    }
    
    part def ChromatophoreNetwork {
        port commandIn {
            in camouflageCommand : AdaptationCommand;
        }
        port displayOut {
            out displayedPattern : EnvironmentalSignature;
        }
        action displayPattern {
            in camouflageCommand : AdaptationCommand;
            out displayedPattern : EnvironmentalSignature;
        }
    }
    
    part def PerformanceMonitor {
        port targetIn {
            in environmentalSignature : EnvironmentalSignature;
        }
        port displayIn {
            in displayedPattern : EnvironmentalSignature;
        }
        port reportOut {
            out performanceReport : PerformanceReport;
        }
        action monitorPerformance {
            in target : EnvironmentalSignature;
            in displayed : EnvironmentalSignature;
            out feedback : PerformanceReport;
        }
    }
    
    part def MorphixSystem {
        part opticalSensorArray : OpticalSensorArray;
        part patternAnalysisUnit : PatternAnalysisUnit;
        part threatAssessmentModule : ThreatAssessmentModule;
        part adaptationController : AdaptationController {
            part controllerBehavior : AdaptationControllerBehavior;
        }
        part chromatophoreNetwork : ChromatophoreNetwork;
        part performanceMonitor : PerformanceMonitor;
        
        flow rawVisualDataFlow of OpticalData 
            from opticalSensorArray.visualOut.rawVisualData to patternAnalysisUnit.visualIn.rawVisualData;
            
        flow environmentalSignatureFlow1 of EnvironmentalSignature 
            from patternAnalysisUnit.signatureOut.environmentalSignature to threatAssessmentModule.signatureIn.environmentalSignature;
            
        flow environmentalSignatureFlow2 of EnvironmentalSignature 
            from patternAnalysisUnit.signatureOut.environmentalSignature to adaptationController.signatureIn.environmentalSignature;
            
        flow threatLevelFlow of ThreatAssessment 
            from threatAssessmentModule.threatOut.threatLevel to adaptationController.threatIn.threatLevel;
            
        flow camouflageCommandFlow of AdaptationCommand 
            from adaptationController.commandOut.camouflageCommand to chromatophoreNetwork.commandIn.camouflageCommand;
            
        flow displayedPatternFlow of EnvironmentalSignature 
            from chromatophoreNetwork.displayOut.displayedPattern to performanceMonitor.displayIn.displayedPattern;
            
        flow environmentalSignatureFlow3 of EnvironmentalSignature 
            from patternAnalysisUnit.signatureOut.environmentalSignature to performanceMonitor.targetIn.environmentalSignature;
            
        flow feedbackFlow of PerformanceReport 
            from performanceMonitor.reportOut.performanceReport to adaptationController.feedbackIn.performanceReport;
    }
    
    requirement def ConcealmentRequirement {
        doc /* The Morphix Chameleon System shall achieve dynamic, real-time concealment by replicating the surrounding visual environment's colors, patterns, and textures on its surface. */
        attribute minAccuracy : PatternAccuracy = 0.95;
        attribute maxResponseTime : ResponseTime = 0.5;
    }
    
    part morphixSystem : MorphixSystem;
    
    satisfy ConcealmentRequirement by morphixSystem;
}
