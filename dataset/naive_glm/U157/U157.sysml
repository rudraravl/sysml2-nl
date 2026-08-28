package TissueImageAnalysisSystem {
    import ScalarValues::*;
    import ISQ::*;

    // --- Value Types and Units ---
    value type Micrometer :> Real;
    value type AreaMicrometerSq :> Real;
    value type NuclearToPlasmaRatio :> Real;
    value type MitoticCount :> Integer;

    // --- Item Definitions ---
    item def PhysicalSlide {
        attribute sampleId : String;
    }
    item def RawDigitalImage;
    item def QualityVerifiedImage;
    item def RefinedDigitalImage;
    item def SegmentedCellMap;
    item def CellMetricsDataset {
        attribute avgCellSize : AreaMicrometerSq;
        attribute npr : NuclearToPlasmaRatio;
        attribute dividingCells : MitoticCount;
    }
    item def ClassificationFindings {
        attribute tissueType : String;
        attribute anomalyDetected : Boolean;
        attribute tumorGrade : Integer;
    }
    item def DiagnosticReport {
        attribute reportId : String;
        attribute summary : String;
        item annotatedImage : RefinedDigitalImage;
        item findings : ClassificationFindings;
        item metrics : CellMetricsDataset;
    }

    // --- Port Definitions ---
    port def SlideInputPort {
        in item slide : PhysicalSlide;
    }
    port def RawImageOutputPort {
        out item image : RawDigitalImage;
    }
    port def RawImageInputPort {
        in item image : RawDigitalImage;
    }
    port def VerifiedImageOutputPort {
        out item image : QualityVerifiedImage;
    }
    port def VerifiedImageInputPort {
        in item image : QualityVerifiedImage;
    }
    port def RefinedImageOutputPort {
        out item image : RefinedDigitalImage;
    }
    port def RefinedImageInputPort {
        in item image : RefinedDigitalImage;
    }
    port def SegmentationOutputPort {
        out item map : SegmentedCellMap;
    }
    port def SegmentationInputPort {
        in item map : SegmentedCellMap;
    }
    port def MetricsOutputPort {
        out item metrics : CellMetricsDataset;
    }
    port def MetricsInputPort {
        in item metrics : CellMetricsDataset;
    }
    port def ClassificationOutputPort {
        out item findings : ClassificationFindings;
    }
    port def ClassificationInputPort {
        in item findings : ClassificationFindings;
    }
    port def ReportOutputPort {
        out item report : DiagnosticReport;
    }

    // --- Action Definitions ---
    action def ScanSlideAction {
        in item slide : PhysicalSlide;
        out item image : RawDigitalImage;
    }
    action def AssessQualityAction {
        in item image : RawDigitalImage;
        out item verifiedImage : QualityVerifiedImage;
    }
    action def PreprocessImageAction {
        in item verifiedImage : QualityVerifiedImage;
        out item refinedImage : RefinedDigitalImage;
    }
    action def SegmentCellsAction {
        in item refinedImage : RefinedDigitalImage;
        out item cellMap : SegmentedCellMap;
    }
    action def ExtractFeaturesAction {
        in item cellMap : SegmentedCellMap;
        out item metrics : CellMetricsDataset;
    }
    action def ClassifyTissueAction {
        in item metrics : CellMetricsDataset;
        in item refinedImage : RefinedDigitalImage;
        out item findings : ClassificationFindings;
    }
    action def GenerateReportAction {
        in item findings : ClassificationFindings;
        in item metrics : CellMetricsDataset;
        in item refinedImage : RefinedDigitalImage;
        out item report : DiagnosticReport;
    }

    // --- Requirement Definitions ---
    requirement HighResolutionScanning {
        doc "The system shall capture a detailed image of the entire tissue sample at a microscopic level.";
    }
    requirement QualityAssessment {
        doc "The system shall assess the raw image to ensure it meets clarity and focus standards required for accurate analysis.";
    }
    requirement ImageEnhancement {
        doc "The system shall enhance contrast and reduce visual noise to make individual cells and structures clearer.";
    }
    requirement AutomatedCellSegmentation {
        doc "The system shall use advanced deep-learning AI to automatically identify and outline every single cell and its nucleus.";
    }
    requirement QuantitativeFeatureExtraction {
        doc "The system shall measure critical characteristics including cell size, shape, nuclear-to-plasma ratio, and the number of dividing cells.";
    }
    requirement TissueClassificationAndGrading {
        doc "The system shall interpret findings to classify tissue type, detect specific anomalies, and assign a grade to a tumor.";
    }
    requirement StructuredReportGeneration {
        doc "The system shall compile classification, cell metrics, and diagnostic findings into a structured, easy-to-read report with annotated images.";
    }

    // --- Part Definitions ---
    part def DigitalScanningMicroscope {
        port slideInput : SlideInputPort;
        port rawImageOutput : RawImageOutputPort;
        perform action scan : ScanSlideAction {
            in item slide = slideInput.slide;
            out item image = rawImageOutput.image;
        }
        satisfy HighResolutionScanning;
    }

    part def QualityControlModule {
        port rawImageInput : RawImageInputPort;
        port verifiedOutput : VerifiedImageOutputPort;
        perform action assess : AssessQualityAction {
            in item image = rawImageInput.image;
            out item verifiedImage = verifiedOutput.image;
        }
        satisfy QualityAssessment;
    }

    part def ImagePreprocessingUnit {
        port verifiedInput : VerifiedImageInputPort;
        port refinedOutput : RefinedImageOutputPort;
        perform action preprocess : PreprocessImageAction {
            in item verifiedImage = verifiedInput.image;
            out item refinedImage = refinedOutput.image;
        }
        satisfy ImageEnhancement;
    }

    part def CellSegmentationEngine {
        port refinedInput : RefinedImageInputPort;
        port segmentationOutput : SegmentationOutputPort;
        perform action segment : SegmentCellsAction {
            in item refinedImage = refinedInput.image;
            out item cellMap = segmentationOutput.map;
        }
        satisfy AutomatedCellSegmentation;
    }

    part def FeatureExtractionModule {
        port segmentationInput : SegmentationInputPort;
        port metricsOutput : MetricsOutputPort;
        perform action extract : ExtractFeaturesAction {
            in item cellMap = segmentationInput.map;
            out item metrics = metricsOutput.metrics;
        }
        satisfy QuantitativeFeatureExtraction;
    }

    part def ClassificationEngine {
        port metricsInput : MetricsInputPort;
        port imageInput : RefinedImageInputPort;
        port classificationOutput : ClassificationOutputPort;
        perform action classify : ClassifyTissueAction {
            in item metrics = metricsInput.metrics;
            in item refinedImage = imageInput.image;
            out item findings = classificationOutput.findings;
        }
        satisfy TissueClassificationAndGrading;
    }

    part def DiagnosticReportGenerator {
        port classificationInput : ClassificationInputPort;
        port metricsInput : MetricsInputPort;
        port imageInput : RefinedImageInputPort;
        port reportOutput : ReportOutputPort;
        perform action generate : GenerateReportAction {
            in item findings = classificationInput.findings;
            in item metrics = metricsInput.metrics;
            in item refinedImage = imageInput.image;
            out item report = reportOutput.report;
        }
        satisfy StructuredReportGeneration;
    }

    part def AutomatedTissueImageAnalysisSystem {
        part microscope : DigitalScanningMicroscope;
        part qcModule : QualityControlModule;
        part preprocessingUnit : ImagePreprocessingUnit;
        part segmentationEngine : CellSegmentationEngine;
        part featureModule : FeatureExtractionModule;
        part classificationEngine : ClassificationEngine;
        part reportGenerator : DiagnosticReportGenerator;

        port systemSlideInput : SlideInputPort;
        port systemReportOutput : ReportOutputPort;

        connection slideLoad connect systemSlideInput to microscope.slideInput;
        connection rawImageFlow connect microscope.rawImageOutput to qcModule.rawImageInput;
        connection verifiedImageFlow connect qcModule.verifiedOutput to preprocessingUnit.verifiedInput;
        connection refinedImageToSegmentation connect preprocessingUnit.refinedOutput to segmentationEngine.refinedInput;
        connection refinedImageToClassification connect preprocessingUnit.refinedOutput to classificationEngine.imageInput;
        connection refinedImageToReport connect preprocessingUnit.refinedOutput to reportGenerator.imageInput;
        connection segmentationFlow connect segmentationEngine.segmentationOutput to featureModule.segmentationInput;
        connection metricsToClassification connect featureModule.metricsOutput to classificationEngine.metricsInput;
        connection metricsToReport connect featureModule.metricsOutput to reportGenerator.metricsInput;
        connection classificationFlow connect classificationEngine.classificationOutput to reportGenerator.classificationInput;
        connection reportDispense connect reportGenerator.reportOutput to systemReportOutput;

        state machine AnalysisStates {
            state idle;
            state scanning;
            state qualityControl;
            state preprocessing;
            state segmenting;
            state extracting;
            state classifying;
            state reporting;
            transition idle -> scanning;
            transition scanning -> qualityControl;
            transition qualityControl -> preprocessing;
            transition preprocessing -> segmenting;
            transition segmenting -> extracting;
            transition extracting -> classifying;
            transition classifying -> reporting;
            transition reporting -> idle;
        }
    }
}
