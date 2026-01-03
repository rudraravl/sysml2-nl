package AutomatedTissueImageAnalysisSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImageResolution {
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute micronsPerPixel : Real;
    }
    
    attribute def TissueClassification {
        attribute tissueType : String;
        attribute pathologyCategory : String;
        attribute confidenceScore : Real;
    }
    
    attribute def CellMetrics {
        attribute cellCount : Integer;
        attribute averageCellArea : ISQ::AreaValue;
        attribute nuclearToPlasmaRatio : Real;
        attribute mitosisCount : Integer;
    }
    
    attribute def DiagnosticFindings {
        attribute abnormalCellPercentage : Real;
        attribute tumorGrade : String;
        attribute detectedAnomalies : String[*];
        attribute recommendedAction : String;
    }
    
    item def TissueSlide {
        attribute slideIdentifier : String;
        attribute patientID : String;
        attribute tissueSource : String;
        attribute stainType : String;
        attribute preparationDate : String;
    }
    
    item def RawDigitalImage {
        attribute imageID : String;
        attribute resolution : ImageResolution;
        attribute bitDepth : Integer;
        attribute compressionFormat : String;
        attribute captureTimestamp : String;
        attribute fileSize : Real;
    }
    
    item def ProcessedImage {
        attribute imageID : String;
        attribute enhancementApplied : String[*];
        attribute segmentationMask : String;
        attribute normalizedIntensity : Real;
    }
    
    item def AnalysisReport {
        attribute reportID : String;
        attribute slideID : String;
        attribute classification : TissueClassification;
        attribute cellMetrics : CellMetrics;
        attribute findings : DiagnosticFindings;
        attribute generationTimestamp : String;
        attribute reviewStatus : String;
    }
    
    port def SlideInputPort {
        in item slide : TissueSlide;
    }
    
    port def ImageOutputPort {
        out item digitalImage : RawDigitalImage;
    }
    
    port def ImageProcessingPort {
        in item rawImage : RawDigitalImage;
        out item processedImage : ProcessedImage;
    }
    
    port def AnalysisPort {
        in item processedImage : ProcessedImage;
        out attribute metrics : CellMetrics;
        out attribute classification : TissueClassification;
    }
    
    port def ReportPort {
        in attribute findings : DiagnosticFindings;
        out item report : AnalysisReport;
    }
    
    part def DigitalScanningMicroscope {
        port slideInput : SlideInputPort;
        port imageOutput : ImageOutputPort;
        
        attribute objectiveMagnification : Real = 40.0;
        attribute numericalAperture : Real = 0.95;
        attribute scanSpeed : Real;
        attribute illuminationWavelength : ISQ::LengthValue;
        
        action def AcquireImage {
            in slide : TissueSlide;
            out scannedImage : RawDigitalImage;
        }
    }
    
    part def ImagePreprocessingUnit {
        port imageInput : ~ImageOutputPort;
        port imageOutput : ~ImageProcessingPort;
        
        attribute noiseReductionLevel : Real = 0.8;
        attribute contrastEnhancementFactor : Real = 1.5;
        
        action def NormalizeImage {
            in rawImage : RawDigitalImage;
            out normalizedImage : ProcessedImage;
        }
        
        action def EnhanceContrast {
            in image : ProcessedImage;
            out enhancedImage : ProcessedImage;
        }
        
        action def ReduceNoise {
            in image : ProcessedImage;
            out cleanImage : ProcessedImage;
        }
    }
    
    part def CellSegmentationEngine {
        attribute segmentationAlgorithm : String = "DeepLearningUNet";
        attribute minimumCellSize : ISQ::AreaValue;
        attribute segmentationThreshold : Real = 0.85;
        
        action def SegmentCells {
            in processedImage : ProcessedImage;
            out cellBoundaries : Integer[*];
            out cellCount : Integer;
        }
        
        action def IdentifyNuclei {
            in processedImage : ProcessedImage;
            out nucleiLocations : Integer[*];
        }
    }
    
    part def FeatureExtractionModule {
        attribute featureSet : String[*] = ("morphology", "texture", "intensity");
        
        action def ExtractMorphologicalFeatures {
            in cellBoundaries : Integer[*];
            out cellAreas : ISQ::AreaValue[*];
            out cellPerimeters : ISQ::LengthValue[*];
        }
        
        action def ExtractTextureFeatures {
            in processedImage : ProcessedImage;
            in cellBoundaries : Integer[*];
            out textureDescriptors : Real[*];
        }
        
        action def ComputeCellMetrics {
            in cellAreas : ISQ::AreaValue[*];
            in cellPerimeters : ISQ::LengthValue[*];
            in nucleiLocations : Integer[*];
            out metrics : CellMetrics;
        }
    }
    
    part def ClassificationEngine {
        port analysisInput : ~AnalysisPort;
        port analysisOutput : AnalysisPort;
        
        attribute modelType : String = "ConvolutionalNeuralNetwork";
        attribute classificationConfidenceThreshold : Real = 0.90;
        attribute numberOfClasses : Integer = 5;
        
        action def ClassifyTissue {
            in processedImage : ProcessedImage;
            in cellMetrics : CellMetrics;
            out classification : TissueClassification;
        }
        
        action def DetectAnomalies {
            in processedImage : ProcessedImage;
            in cellMetrics : CellMetrics;
            out anomalies : String[*];
            out abnormalPercentage : Real;
        }
        
        action def GradeTumor {
            in classification : TissueClassification;
            in cellMetrics : CellMetrics;
            out tumorGrade : String;
        }
    }
    
    part def DiagnosticReportGenerator {
        port reportInput : ~ReportPort;
        port reportOutput : ReportPort;
        
        attribute reportTemplate : String = "CAP_Protocol";
        attribute includeAnnotatedImages : Boolean = true;
        
        action def CompileDiagnosticFindings {
            in classification : TissueClassification;
            in cellMetrics : CellMetrics;
            in anomalies : String[*];
            in tumorGrade : String;
            out findings : DiagnosticFindings;
        }
        
        action def GenerateReport {
            in slide : TissueSlide;
            in findings : DiagnosticFindings;
            in processedImage : ProcessedImage;
            out report : AnalysisReport;
        }
    }
    
    part def QualityControlModule {
        attribute minimumImageQuality : Real = 0.85;
        attribute calibrationStatus : String;
        
        action def ValidateImageQuality {
            in rawImage : RawDigitalImage;
            out qualityScore : Real;
            out isAcceptable : Boolean;
        }
        
        action def VerifyCalibration {
            out calibrationValid : Boolean;
        }
    }
    
    action def PerformTissueAnalysis {
        in tissueSlide : TissueSlide;
        out diagnosticReport : AnalysisReport;
        
        first start;
        
        then action scan {
            in slide = tissueSlide;
            out scannedImage : RawDigitalImage;
        }
        
        then action validateQuality {
            in rawImage = scan.scannedImage;
            out qualityScore : Real;
            out isAcceptable : Boolean;
        }
        
        then decide;
            if validateQuality.isAcceptable then preprocess;
            if !validateQuality.isAcceptable then rescan;
        
        action rescan {
            in slide = tissueSlide;
            out rescannedImage : RawDigitalImage;
        }
        then preprocess;
        
        action preprocess {
            in rawImage = scan.scannedImage;
            out processedImage : ProcessedImage;
        }
        
        then action segment {
            in processedImage = preprocess.processedImage;
            out cellBoundaries : Integer[*];
            out nucleiLocations : Integer[*];
            out cellCount : Integer;
        }
        
        then action extractFeatures {
            in processedImage = preprocess.processedImage;
            in cellBoundaries = segment.cellBoundaries;
            in nucleiLocations = segment.nucleiLocations;
            out cellMetrics : CellMetrics;
        }
        
        then action classify {
            in processedImage = preprocess.processedImage;
            in cellMetrics = extractFeatures.cellMetrics;
            out classification : TissueClassification;
        }
        
        then action detectAnomalies {
            in processedImage = preprocess.processedImage;
            in cellMetrics = extractFeatures.cellMetrics;
            out anomalies : String[*];
            out abnormalPercentage : Real;
        }
        
        then action gradeTumor {
            in classification = classify.classification;
            in cellMetrics = extractFeatures.cellMetrics;
            out tumorGrade : String;
        }
        
        then action compileFindings {
            in classification = classify.classification;
            in cellMetrics = extractFeatures.cellMetrics;
            in anomalies = detectAnomalies.anomalies;
            in tumorGrade = gradeTumor.tumorGrade;
            out findings : DiagnosticFindings;
        }
        
        then action generateReport {
            in slide = tissueSlide;
            in findings = compileFindings.findings;
            in processedImage = preprocess.processedImage;
            out report : AnalysisReport;
        }
        
        then assign diagnosticReport := generateReport.report;
        then done;
    }
    
    requirement def SystemPrimaryFunction {
        doc /* The automated tissue image analysis system shall acquire high-resolution 
               digital images of tissue samples, perform automated segmentation and 
               classification of cellular structures, detect pathological abnormalities, 
               and generate comprehensive diagnostic reports to support pathologists in 
               accurate and efficient disease diagnosis. */
    }
    
    requirement def ImageResolutionRequirement {
        doc /* The digital scanning microscope shall capture tissue images with a minimum 
               resolution of 0.25 microns per pixel to ensure adequate cellular detail 
               for diagnostic analysis. */
        
        require constraint {
            DigitalScanningMicroscope::objectiveMagnification >= 20.0
        }
    }
    
    requirement def SegmentationAccuracyRequirement {
        doc /* The cell segmentation engine shall identify and delineate individual cells 
               with a minimum accuracy of 85% compared to expert manual segmentation. */
        
        require constraint {
            CellSegmentationEngine::segmentationThreshold >= 0.85
        }
    }
    
    requirement def ClassificationAccuracyRequirement {
        doc /* The classification engine shall classify tissue types and pathological 
               conditions with a minimum confidence threshold of 90% to ensure diagnostic 
               reliability. */
        
        require constraint {
            ClassificationEngine::classificationConfidenceThreshold >= 0.90
        }
    }
    
    requirement def ProcessingThroughputRequirement {
        doc /* The system shall process and analyze a complete tissue slide within 
               10 minutes to support clinical workflow requirements and timely diagnosis. */
        
        attribute maxProcessingTime : ISQ::TimeValue;
        
        require constraint {
            maxProcessingTime <= 600.0
        }
    }
    
    requirement def ReportCompletenessRequirement {
        doc /* The diagnostic report shall include tissue classification, quantitative 
               cell metrics, detected anomalies, tumor grading when applicable, and 
               annotated images to provide comprehensive diagnostic information. */
    }
    
    requirement <'SYS-001'> automatedTissueAnalysisSystemRequirement {
        doc /* The automated tissue image analysis system shall provide end-to-end 
               automated analysis of tissue samples from image acquisition through 
               diagnostic report generation, enabling rapid, accurate, and reproducible 
               pathological assessment. */
        
        require imageResolutionReq : ImageResolutionRequirement;
        require segmentationAccuracyReq : SegmentationAccuracyRequirement;
        require classificationAccuracyReq : ClassificationAccuracyRequirement;
        require processingThroughputReq : ProcessingThroughputRequirement;
        require reportCompletenessReq : ReportCompletenessRequirement;
    }
    
    part automatedTissueAnalyzer {
        doc /* The automated tissue image analysis system integrates digital microscopy, 
               advanced image processing, machine learning-based classification, and 
               automated reporting to transform tissue pathology workflow. The system 
               acquires high-resolution digital images of stained tissue slides, applies 
               sophisticated preprocessing to enhance image quality, segments individual 
               cells and tissue structures, extracts quantitative morphological and 
               textural features, classifies tissue types and pathological conditions 
               using deep learning models, detects abnormalities and grades tumors, and 
               generates comprehensive diagnostic reports with annotated images for 
               pathologist review and clinical decision-making. */
        
        satisfy automatedTissueAnalysisSystemRequirement;
        
        part scanner : DigitalScanningMicroscope {
            perform tissueAnalysisWorkflow.scan;
        }
        
        part qualityControl : QualityControlModule {
            perform tissueAnalysisWorkflow.validateQuality;
        }
        
        part preprocessor : ImagePreprocessingUnit {
            perform tissueAnalysisWorkflow.preprocess;
        }
        
        part segmentationEngine : CellSegmentationEngine {
            perform tissueAnalysisWorkflow.segment;
        }
        
        part featureExtractor : FeatureExtractionModule {
            perform tissueAnalysisWorkflow.extractFeatures;
        }
        
        part classifier : ClassificationEngine {
            perform tissueAnalysisWorkflow.classify;
            perform tissueAnalysisWorkflow.detectAnomalies;
            perform tissueAnalysisWorkflow.gradeTumor;
        }
        
        part reportGenerator : DiagnosticReportGenerator {
            perform tissueAnalysisWorkflow.compileFindings;
            perform tissueAnalysisWorkflow.generateReport;
        }
        
        connection scanToPreprocess connect 
            scanner.imageOutput.digitalImage to preprocessor.imageInput.slide;
        
        connection preprocessToSegment connect 
            preprocessor.imageOutput.processedImage to segmentationEngine;
        
        connection segmentToExtract connect 
            segmentationEngine to featureExtractor;
        
        connection extractToClassify connect 
            featureExtractor to classifier.analysisInput.processedImage;
        
        connection classifyToReport connect 
            classifier.analysisOutput.classification to reportGenerator.reportInput.findings;
        
        perform action tissueAnalysisWorkflow : PerformTissueAnalysis {
            in tissueSlide : TissueSlide;
            out diagnosticReport : AnalysisReport;
        }
    }
}
