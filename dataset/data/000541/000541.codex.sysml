package AutomatedTissueImageAnalysis {

    import ScalarValues::*;
    import SI::*;

    attribute def PixelCount :> ScalarValues::Integer;
    attribute def Percentage :> ScalarValues::Real {
        unit = "%";
    }
    attribute def ConfidenceScore :> ScalarValues::Real {
        unit = "1";
    }
    attribute def Micrometer :> ISQ::length {
        unit = "um";
    }
    attribute def SquareMicrometer :> ISQ::area {
        unit = "um^2";
    }
    attribute def Seconds :> ISQ::time {
        unit = "s";
    }
    attribute def Megabyte :> ScalarValues::Real {
        unit = "MB";
    }
    attribute def SlidesPerHour :> ScalarValues::Real {
        unit = "slide/h";
    }

    enum def StainKind {
        enum H_AND_E;
        enum IHC_DAB;
        enum IHC_FLUORESCENCE;
        enum SPECIAL_STAIN;
    }

    enum def TissueClass {
        enum BACKGROUND;
        enum NORMAL_EPITHELIUM;
        enum STROMA;
        enum NECROSIS;
        enum INFLAMMATION;
        enum TUMOR;
        enum ARTIFACT;
    }

    enum def AnalysisDisposition {
        enum ACCEPTED;
        enum REVIEW_REQUIRED;
        enum REJECTED;
    }

    item def GlassSlide {
        attribute slideIdentifier : String;
        attribute specimenIdentifier : String;
        attribute stain : StainKind;
    }

    item def WholeSlideImage {
        attribute imageIdentifier : String;
        attribute widthPixels : PixelCount;
        attribute heightPixels : PixelCount;
        attribute pixelSizeX : Micrometer;
        attribute pixelSizeY : Micrometer;
        attribute fileSize : Megabyte;
        attribute stain : StainKind;
    }

    item def ImageTile {
        attribute tileIdentifier : String;
        attribute originX : PixelCount;
        attribute originY : PixelCount;
        attribute widthPixels : PixelCount;
        attribute heightPixels : PixelCount;
        attribute pixelSizeX : Micrometer;
        attribute pixelSizeY : Micrometer;
    }

    item def TissueMask {
        attribute tissueArea : SquareMicrometer;
        attribute tissueCoverage : Percentage;
        attribute artifactCoverage : Percentage;
    }

    item def SegmentationMap {
        attribute mapIdentifier : String;
        attribute tissueArea : SquareMicrometer;
        attribute tumorArea : SquareMicrometer;
        attribute necrosisArea : SquareMicrometer;
        attribute artifactArea : SquareMicrometer;
    }

    item def CellDetectionSet {
        attribute detectedCellCount : PixelCount;
        attribute tumorCellCount : PixelCount;
        attribute lymphocyteCount : PixelCount;
        attribute meanNuclearArea : SquareMicrometer;
    }

    item def TissueFeatureSet {
        attribute tumorFraction : Percentage;
        attribute stromalFraction : Percentage;
        attribute necrosisFraction : Percentage;
        attribute inflammationScore : ConfidenceScore;
        attribute imageQualityScore : ConfidenceScore;
    }

    item def DiagnosticFinding {
        attribute findingClass : TissueClass;
        attribute confidence : ConfidenceScore;
        attribute affectedArea : SquareMicrometer;
    }

    item def AnalysisReport {
        attribute reportIdentifier : String;
        attribute slideIdentifier : String;
        attribute tumorFraction : Percentage;
        attribute detectedCellCount : PixelCount;
        attribute imageQualityScore : ConfidenceScore;
        attribute modelConfidence : ConfidenceScore;
        attribute disposition : AnalysisDisposition;
        attribute processingTime : Seconds;
    }

    port def SlideInputPort {
        in item slide : GlassSlide;
    }

    port def ImagePort {
        inout item image : WholeSlideImage;
    }

    port def TilePort {
        inout item tile : ImageTile;
    }

    port def MaskPort {
        inout item mask : TissueMask;
    }

    port def SegmentationPort {
        inout item segmentation : SegmentationMap;
    }

    port def CellSetPort {
        inout item cells : CellDetectionSet;
    }

    port def FeaturePort {
        inout item features : TissueFeatureSet;
    }

    port def FindingPort {
        inout item finding : DiagnosticFinding;
    }

    port def ReportPort {
        out item report : AnalysisReport;
    }

    port def ControlPort {
        inout attribute ready : Boolean;
        inout attribute faulted : Boolean;
        inout attribute progress : Percentage;
    }

    action def AcquireDigitalSlide {
        in item slide : GlassSlide;
        out item image : WholeSlideImage;
        attribute targetPixelSize : Micrometer = 0.25 [um];
    }

    action def NormalizeImageColor {
        in item rawImage : WholeSlideImage;
        out item normalizedImage : WholeSlideImage;
        attribute stainReferenceConfidence : ConfidenceScore;
    }

    action def PartitionImage {
        in item image : WholeSlideImage;
        out item tile : ImageTile;
        attribute tileWidth : PixelCount = 1024;
        attribute tileHeight : PixelCount = 1024;
    }

    action def DetectTissueRegion {
        in item image : WholeSlideImage;
        out item mask : TissueMask;
        attribute minimumTissueCoverage : Percentage = 2.0 [%];
    }

    action def SegmentTissueClasses {
        in item tile : ImageTile;
        in item mask : TissueMask;
        out item segmentation : SegmentationMap;
        attribute classifierConfidence : ConfidenceScore;
    }

    action def DetectCells {
        in item tile : ImageTile;
        in item segmentation : SegmentationMap;
        out item cells : CellDetectionSet;
        attribute minimumNucleusConfidence : ConfidenceScore = 0.70;
    }

    action def ExtractQuantitativeFeatures {
        in item segmentation : SegmentationMap;
        in item cells : CellDetectionSet;
        out item features : TissueFeatureSet;
    }

    action def GenerateFinding {
        in item features : TissueFeatureSet;
        out item finding : DiagnosticFinding;
        attribute reviewThreshold : ConfidenceScore = 0.85;
    }

    action def CompileAnalysisReport {
        in item image : WholeSlideImage;
        in item features : TissueFeatureSet;
        in item finding : DiagnosticFinding;
        out item report : AnalysisReport;
    }

    action def AnalyzeTissueImage {
        in item slide : GlassSlide;
        out item report : AnalysisReport;

        action acquire : AcquireDigitalSlide {
            in item slide = AnalyzeTissueImage::slide;
        }

        action normalize : NormalizeImageColor {
            in item rawImage = acquire.image;
        }

        action detectTissue : DetectTissueRegion {
            in item image = normalize.normalizedImage;
        }

        action tileImage : PartitionImage {
            in item image = normalize.normalizedImage;
        }

        action segment : SegmentTissueClasses {
            in item tile = tileImage.tile;
            in item mask = detectTissue.mask;
        }

        action detectCells : DetectCells {
            in item tile = tileImage.tile;
            in item segmentation = segment.segmentation;
        }

        action extractFeatures : ExtractQuantitativeFeatures {
            in item segmentation = segment.segmentation;
            in item cells = detectCells.cells;
        }

        action generateFinding : GenerateFinding {
            in item features = extractFeatures.features;
        }

        action compileReport : CompileAnalysisReport {
            in item image = normalize.normalizedImage;
            in item features = extractFeatures.features;
            in item finding = generateFinding.finding;
            out item report = AnalyzeTissueImage::report;
        }

        succession first acquire then normalize;
        succession first normalize then detectTissue;
        succession first detectTissue then tileImage;
        succession first tileImage then segment;
        succession first segment then detectCells;
        succession first detectCells then extractFeatures;
        succession first extractFeatures then generateFinding;
        succession first generateFinding then compileReport;
    }

    state def AnalyzerOperatingState {
        entry action initialize {
            out attribute initialized : Boolean = true;
        }

        state idle;
        state slideLoaded;
        state scanning;
        state preprocessing;
        state analyzing;
        state validating;
        state reporting;
        state reviewRequired;
        state completed;
        state fault;

        transition initial then idle;

        transition idle_to_slideLoaded
            first idle
            accept item slide : GlassSlide
            then slideLoaded;

        transition slideLoaded_to_scanning
            first slideLoaded
            accept signal startScan
            then scanning;

        transition scanning_to_preprocessing
            first scanning
            if scanComplete == true
            then preprocessing;

        transition preprocessing_to_analyzing
            first preprocessing
            if imageQualityScore >= 0.75
            then analyzing;

        transition preprocessing_to_fault
            first preprocessing
            if imageQualityScore < 0.50
            then fault;

        transition analyzing_to_validating
            first analyzing
            if modelConfidence >= 0.60
            then validating;

        transition validating_to_reporting
            first validating
            if modelConfidence >= 0.85 and artifactCoverage <= 10.0 [%]
            then reporting;

        transition validating_to_reviewRequired
            first validating
            if modelConfidence < 0.85 or artifactCoverage > 10.0 [%]
            then reviewRequired;

        transition reporting_to_completed
            first reporting
            if reportGenerated == true
            then completed;

        transition reviewRequired_to_completed
            first reviewRequired
            accept signal pathologistReviewComplete
            then completed;

        transition completed_to_idle
            first completed
            accept signal reset
            then idle;

        transition fault_to_idle
            first fault
            accept signal reset
            then idle;

        attribute scanComplete : Boolean;
        attribute reportGenerated : Boolean;
        attribute imageQualityScore : ConfidenceScore;
        attribute modelConfidence : ConfidenceScore;
        attribute artifactCoverage : Percentage;
    }

    part def SlideScanner {
        port slideIn : SlideInputPort;
        port imageOut : ImagePort;
        port control : ControlPort;

        attribute opticalResolution : Micrometer = 0.25 [um];
        attribute scanThroughput : SlidesPerHour = 18.0 [slide/h];
        attribute maximumImageSize : Megabyte = 120000.0 [MB];

        perform action acquire : AcquireDigitalSlide;
    }

    part def ImagePreprocessor {
        port rawImageIn : ImagePort;
        port normalizedImageOut : ImagePort;
        port maskOut : MaskPort;
        port control : ControlPort;

        attribute maximumNormalizationTime : Seconds = 120.0 [s];
        attribute minimumQualityScore : ConfidenceScore = 0.75;

        perform action normalize : NormalizeImageColor;
        perform action detectTissue : DetectTissueRegion;
    }

    part def TileManager {
        port imageIn : ImagePort;
        port tileOut : TilePort;
        port control : ControlPort;

        attribute tileWidth : PixelCount = 1024;
        attribute tileHeight : PixelCount = 1024;
        attribute overlapPixels : PixelCount = 64;

        perform action tileImage : PartitionImage;
    }

    part def TissueSegmentationEngine {
        port tileIn : TilePort;
        port maskIn : MaskPort;
        port segmentationOut : SegmentationPort;
        port control : ControlPort;

        attribute minimumClassConfidence : ConfidenceScore = 0.80;
        attribute supportedStainCount : PixelCount = 4;

        perform action segment : SegmentTissueClasses;
    }

    part def CellQuantificationEngine {
        port tileIn : TilePort;
        port segmentationIn : SegmentationPort;
        port cellsOut : CellSetPort;
        port control : ControlPort;

        attribute minimumNuclearDiameter : Micrometer = 4.0 [um];
        attribute maximumNuclearDiameter : Micrometer = 30.0 [um];

        perform action detectCells : DetectCells;
    }

    part def FeatureAnalyticsEngine {
        port segmentationIn : SegmentationPort;
        port cellsIn : CellSetPort;
        port featuresOut : FeaturePort;
        port findingOut : FindingPort;
        port control : ControlPort;

        attribute reviewThreshold : ConfidenceScore = 0.85;
        attribute maximumFeatureExtractionTime : Seconds = 180.0 [s];

        perform action extractFeatures : ExtractQuantitativeFeatures;
        perform action generateFinding : GenerateFinding;
    }

    part def ReportGenerator {
        port imageIn : ImagePort;
        port featureIn : FeaturePort;
        port findingIn : FindingPort;
        port reportOut : ReportPort;
        port control : ControlPort;

        attribute maximumReportGenerationTime : Seconds = 30.0 [s];

        perform action compile : CompileAnalysisReport;
    }

    part def AutomatedTissueImageAnalyzer {
        doc /* Primary function: automatically convert a stained tissue slide into a quantitative digital pathology report by scanning the slide, detecting tissue regions, segmenting biologically relevant structures, quantifying cells and tissue composition, assessing confidence and image quality, and routing uncertain cases for expert review. */

        port slideInput : SlideInputPort;
        port reportOutput : ReportPort;
        port systemControl : ControlPort;

        part scanner : SlideScanner;
        part preprocessor : ImagePreprocessor;
        part tileManager : TileManager;
        part segmentationEngine : TissueSegmentationEngine;
        part cellEngine : CellQuantificationEngine;
        part analyticsEngine : FeatureAnalyticsEngine;
        part reportGenerator : ReportGenerator;

        attribute requiredPixelSize : Micrometer = 0.25 [um];
        attribute maximumEndToEndProcessingTime : Seconds = 900.0 [s];
        attribute minimumReportConfidence : ConfidenceScore = 0.85;
        attribute maximumArtifactCoverage : Percentage = 10.0 [%];

        perform action analysisWorkflow : AnalyzeTissueImage;

        exhibit state operatingState : AnalyzerOperatingState;

        connect slideInput to scanner.slideIn;
        connect scanner.imageOut to preprocessor.rawImageIn;
        connect preprocessor.normalizedImageOut to tileManager.imageIn;
        connect preprocessor.normalizedImageOut to reportGenerator.imageIn;
        connect preprocessor.maskOut to segmentationEngine.maskIn;
        connect tileManager.tileOut to segmentationEngine.tileIn;
        connect tileManager.tileOut to cellEngine.tileIn;
        connect segmentationEngine.segmentationOut to cellEngine.segmentationIn;
        connect segmentationEngine.segmentationOut to analyticsEngine.segmentationIn;
        connect cellEngine.cellsOut to analyticsEngine.cellsIn;
        connect analyticsEngine.featuresOut to reportGenerator.featureIn;
        connect analyticsEngine.findingOut to reportGenerator.findingIn;
        connect reportGenerator.reportOut to reportOutput;

        connect systemControl to scanner.control;
        connect systemControl to preprocessor.control;
        connect systemControl to tileManager.control;
        connect systemControl to segmentationEngine.control;
        connect systemControl to cellEngine.control;
        connect systemControl to analyticsEngine.control;
        connect systemControl to reportGenerator.control;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall perform automated tissue image analysis by transforming a stained glass slide or whole-slide image into a quantitative report describing tissue composition, cell counts, diagnostic findings, confidence, and review disposition. */

        subject analyzer : AutomatedTissueImageAnalyzer;

        require constraint {
            analyzer.maximumEndToEndProcessingTime <= 900.0 [s]
        }
    }

    requirement def TissueDetectionRequirement {
        doc /* The analyzer shall detect tissue-containing regions and exclude background before segmentation and cell quantification. */

        subject analyzer : AutomatedTissueImageAnalyzer;

        require constraint {
            analyzer.maximumArtifactCoverage <= 10.0 [%]
        }
    }

    requirement def QuantificationRequirement {
        doc /* The analyzer shall quantify tumor fraction, necrosis fraction, inflammation score, and detected cell count for accepted tissue images. */

        subject report : AnalysisReport;

        require constraint {
            report.detectedCellCount >= 0 and
            report.tumorFraction >= 0.0 [%] and
            report.tumorFraction <= 100.0 [%]
        }
    }

    requirement def ConfidenceRoutingRequirement {
        doc /* The analyzer shall mark cases for review when model confidence is below the acceptance threshold or image quality is insufficient for autonomous acceptance. */

        subject report : AnalysisReport;

        require constraint {
            (report.modelConfidence >= 0.85 and report.disposition == AnalysisDisposition::ACCEPTED) or
            (report.modelConfidence < 0.85 and report.disposition == AnalysisDisposition::REVIEW_REQUIRED)
        }
    }

    requirement def SpatialCalibrationRequirement {
        doc /* The analyzer shall preserve spatial calibration so reported tissue and nuclear measurements are traceable to micrometer-scale image resolution. */

        subject image : WholeSlideImage;

        require constraint {
            image.pixelSizeX > 0.0 [um] and
            image.pixelSizeY > 0.0 [um]
        }
    }

    satisfy PrimaryFunctionRequirement by AutomatedTissueImageAnalyzer;
    satisfy TissueDetectionRequirement by ImagePreprocessor;
    satisfy QuantificationRequirement by FeatureAnalyticsEngine;
    satisfy ConfidenceRoutingRequirement by ReportGenerator;
    satisfy SpatialCalibrationRequirement by SlideScanner;

    part automatedTissueImageAnalysisSystem : AutomatedTissueImageAnalyzer {
        attribute requiredPixelSize = 0.25 [um];
        attribute maximumEndToEndProcessingTime = 900.0 [s];
        attribute minimumReportConfidence = 0.85;
        attribute maximumArtifactCoverage = 10.0 [%];
    }
}