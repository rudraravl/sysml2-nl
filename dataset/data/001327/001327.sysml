package '3D Publishing Platform' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ModelingMetadata::*;
    private import RiskMetadata::*;
    private import RiskLevelEnum::*;

    attribute def PolygonCount :> Integer;
    attribute def TextureResolution :> Integer;
    attribute def FileSize :> ISQ::MassValue;
    attribute def ProcessingTime :> ISQ::TimeValue;
    attribute def CompressionRatio :> Real;
    attribute def QualityScore :> Real;
    
    enum def ModelFormat {
        obj;
        fbx;
        gltf;
        usd;
        stl;
    }
    
    enum def OutputFormat {
        webGL;
        threejs;
        babylon;
        unity;
        unreal;
    }
    
    enum def OptimizationLevel {
        low;
        medium;
        high;
        ultra;
    }

    item def RawModel {
        attribute format : ModelFormat;
        attribute polygonCount : PolygonCount;
        attribute textureResolution : TextureResolution;
        attribute fileSize : FileSize;
        attribute hasAnimations : Boolean;
        attribute materialCount : Integer;
    }

    item def OptimizedModel {
        attribute format : OutputFormat;
        attribute reducedPolygons : PolygonCount;
        attribute compressedTextures : TextureResolution;
        attribute optimizedSize : FileSize;
        attribute compressionRatio : CompressionRatio;
        attribute qualityScore : QualityScore;
    }

    item def AssetMetadata {
        attribute title : String;
        attribute description : String;
        attribute author : String;
        attribute tags : String[*];
        attribute license : String;
        attribute creationDate : String;
    }

    item def PublishedAsset {
        attribute assetId : String;
        attribute publicUrl : String;
        attribute embedCode : String;
        attribute viewerConfig : String;
        attribute model : OptimizedModel;
        attribute assetMetadata : AssetMetadata;
    }

    port def ModelInputPort {
        in item rawModel : RawModel;
        in attribute uploadToken : String;
    }

    port def ModelOutputPort {
        out item publishedAsset : PublishedAsset;
        out attribute status : String;
    }

    port def OptimizationControlPort {
        in attribute targetLevel : OptimizationLevel;
        in attribute maxPolygons : PolygonCount;
        out attribute progress : Real;
    }

    port def StoragePort {
        in item modelData : OptimizedModel;
        out attribute storageUrl : String;
        out attribute storageSize : FileSize;
    }

    port def DeliveryPort {
        in attribute assetUrl : String;
        out attribute cdnUrl : String;
        out attribute bandwidth : ISQ::PowerValue;
    }

    part def IngestionService {
        port input : ModelInputPort;
        
        attribute maxFileSize : FileSize;
        attribute supportedFormats : ModelFormat[*];
        attribute validationRules : String[*];

        action def validateAndIngest {
            in rawModel : RawModel;
            in uploadToken : String;
            out validated : Boolean;
            out ingestedModel : RawModel;
        }
    }

    part def OptimizationEngine {
        port optimizationControl : OptimizationControlPort;
        
        attribute targetPolyReduction : Real;
        attribute textureCompressionQuality : Real;
        attribute lodLevels : Integer;

        action def optimizeGeometry {
            in model : RawModel;
            in targetLevel : OptimizationLevel;
            in maxPolygons : PolygonCount;
            out optimized : OptimizedModel;
            out progress : Real;
        }
    }

    part def RenderingService {
        attribute renderQuality : String;
        attribute lightingPresets : String[*];
        attribute cameraAngles : Integer;

        action def generatePreviews {
            in model : OptimizedModel;
            out thumbnailUrl : String;
            out previewUrls : String[*];
        }
    }

    part def ConversionPipeline {
        attribute outputFormats : OutputFormat[*];
        attribute conversionThreads : Integer;

        action def convertFormat {
            in source : OptimizedModel;
            in targetFormat : OutputFormat;
            out converted : OptimizedModel;
        }
    }

    part def QualityAssurance {
        attribute minQualityThreshold : QualityScore;
        attribute validationChecks : String[*];

        action def assessQuality {
            in model : OptimizedModel;
            in original : RawModel;
            out qualityScore : QualityScore;
            out passed : Boolean;
        }
    }

    part def StorageManager {
        port storage : StoragePort;
        
        attribute storageCapacity : FileSize;
        attribute redundancyLevel : Integer;
        attribute compressionEnabled : Boolean;

        action def storeAsset {
            in modelData : OptimizedModel;
            out storageUrl : String;
            out storageSize : FileSize;
        }
    }

    part def CDNDistributor {
        port delivery : DeliveryPort;
        
        attribute edgeLocations : Integer;
        attribute cachePolicy : String;
        attribute maxBandwidth : ISQ::PowerValue;

        action def distributeAsset {
            in assetUrl : String;
            out cdnUrl : String;
            out bandwidth : ISQ::PowerValue;
        }
    }

    part def ViewerGenerator {
        attribute viewerTemplates : String[*];
        attribute interactionModes : String[*];

        action def generateViewer {
            in model : OptimizedModel;
            in config : String;
            out embedCode : String;
            out viewerConfig : String;
        }
    }

    part def MetadataService {
        attribute indexingEnabled : Boolean;
        attribute searchOptimized : Boolean;

        action def enrichMetadata {
            in baseMetadata : AssetMetadata;
            in model : OptimizedModel;
            out enrichedMetadata : AssetMetadata;
        }
    }

    action def ProcessAndPublish3DModel {
        in attribute inputModel : RawModel;
        in attribute uploadToken : String;
        in attribute targetOptimization : OptimizationLevel;
        in attribute maxPolygonTarget : PolygonCount;
        in attribute outputFormat : OutputFormat;
        in attribute inputMetadata : AssetMetadata;
        out attribute publishedAsset : PublishedAsset;
        out attribute processingTime : ProcessingTime;

        first start;
        
        then action ingest : IngestionService::validateAndIngest {
            in rawModel = inputModel;
            in uploadToken = uploadToken;
            out validated;
            out ingestedModel;
        }

        then decide;
            if ingest.validated then optimize;
            if not ingest.validated then reject;

        action optimize : OptimizationEngine::optimizeGeometry {
            in model = ingest.ingestedModel;
            in targetLevel = targetOptimization;
            in maxPolygons = maxPolygonTarget;
            out optimized;
            out progress;
        }

        then action convert : ConversionPipeline::convertFormat {
            in source = optimize.optimized;
            in targetFormat = outputFormat;
            out converted;
        }

        then action assess : QualityAssurance::assessQuality {
            in model = convert.converted;
            in original = ingest.ingestedModel;
            out qualityScore;
            out passed;
        }

        then decide;
            if assess.passed then render;
            if not assess.passed then reoptimize;

        action render : RenderingService::generatePreviews {
            in model = convert.converted;
            out thumbnailUrl;
            out previewUrls;
        }

        then action store : StorageManager::storeAsset {
            in modelData = convert.converted;
            out storageUrl;
            out storageSize;
        }

        then action distribute : CDNDistributor::distributeAsset {
            in assetUrl = store.storageUrl;
            out cdnUrl;
            out bandwidth;
        }

        then action generateView : ViewerGenerator::generateViewer {
            in model = convert.converted;
            in config = "defaultInteractive";
            out embedCode;
            out viewerConfig;
        }

        then action enrich : MetadataService::enrichMetadata {
            in baseMetadata = inputMetadata;
            in model = convert.converted;
            out enrichedMetadata;
        }

        then assign publishedAsset := PublishedAsset {
            assetId = store.storageUrl;
            publicUrl = distribute.cdnUrl;
            embedCode = generateView.embedCode;
            viewerConfig = generateView.viewerConfig;
            model = convert.converted;
            assetMetadata = enrich.enrichedMetadata;
        }

        then success;

        action reoptimize : OptimizationEngine::optimizeGeometry {
            in model = ingest.ingestedModel;
            in targetLevel = OptimizationLevel::medium;
            in maxPolygons = maxPolygonTarget;
            out optimized;
            out progress;
        }
        then convert;

        action reject;
        then done;

        join success, done;
    }

    state def PublishingWorkflowStates {
        entry; then idle;

        state idle;
        accept UploadRequest;
        then ingesting;

        state ingesting {
            entry; then validate;
            state validate;
        }
        if validationPassed then optimizing;
        if validationFailed then idle;

        state optimizing {
            entry; then process;
            state process;
        }
        then converting;

        state converting {
            entry; then convert;
            state convert;
        }
        then qualityCheck;

        state qualityCheck {
            entry; then assess;
            state assess;
        }
        if qualityPassed then publishing;
        if qualityFailed then optimizing;

        state publishing {
            entry; then store;
            state store;
            then distribute;
            state distribute;
            then finalize;
            state finalize;
        }
        then idle;
    }

    part def ThreeDPublishingPlatform {
        doc /*
            A comprehensive 3D publishing platform that transforms raw 3D models into 
            optimized, web-ready interactive assets for global distribution.
            
            The system's primary function is to accept user-uploaded 3D models in various 
            formats, automatically optimize them for web performance through polygon reduction 
            and texture compression, convert them to web-compatible formats, validate quality, 
            generate interactive viewers with multiple camera angles and lighting presets, 
            store the assets with redundancy, distribute them via a global CDN, and provide 
            embeddable viewer code for seamless integration into websites and applications.
            
            This enables creators to publish high-quality 3D content that loads quickly and 
            runs smoothly across devices while maintaining visual fidelity.
        */

        attribute platformName : String = "Universal 3D Publishing Platform";
        attribute version : String = "3.0.0";
        attribute maxConcurrentJobs : Integer = 100;
        attribute averageProcessingTime : ProcessingTime = 180.0;
        attribute supportedInputFormats : Integer = 5;
        attribute supportedOutputFormats : Integer = 5;
    }

    part publishingPlatform : ThreeDPublishingPlatform {
        part ingestion : IngestionService {
            :>> maxFileSize = 500.0;
            :>> supportedFormats = (ModelFormat::obj, ModelFormat::fbx, ModelFormat::gltf, ModelFormat::usd, ModelFormat::stl);
            :>> validationRules = ("geometryIntegrity", "textureValidity", "materialConsistency");
        }

        part optimizer : OptimizationEngine {
            :>> targetPolyReduction = 0.7;
            :>> textureCompressionQuality = 0.85;
            :>> lodLevels = 4;
        }

        part renderer : RenderingService {
            :>> renderQuality = "high";
            :>> lightingPresets = ("studio", "outdoor", "neutral");
            :>> cameraAngles = 8;
        }

        part converter : ConversionPipeline {
            :>> outputFormats = (OutputFormat::webGL, OutputFormat::threejs, OutputFormat::babylon);
            :>> conversionThreads = 4;
        }

        part qa : QualityAssurance {
            :>> minQualityThreshold = 0.80;
            :>> validationChecks = ("geometryAccuracy", "textureQuality", "performanceMetrics");
        }

        part storage : StorageManager {
            :>> storageCapacity = 10000.0;
            :>> redundancyLevel = 3;
            :>> compressionEnabled = true;
        }

        part cdn : CDNDistributor {
            :>> edgeLocations = 50;
            :>> cachePolicy = "aggressive";
            :>> maxBandwidth = 1000.0;
        }

        part viewer : ViewerGenerator {
            :>> viewerTemplates = ("basic", "interactive", "vr", "ar");
            :>> interactionModes = ("orbit", "pan", "zoom", "annotate");
        }

        part metadata : MetadataService {
            :>> indexingEnabled = true;
            :>> searchOptimized = true;
        }

        connect ingestion.input to optimizer.optimizationControl;
        connect optimizer.optimizationControl to converter;
        connect converter to qa;
        connect qa to renderer;
        connect renderer to storage.storage;
        connect storage.storage to cdn.delivery;
        connect cdn.delivery to viewer;
        connect viewer to metadata;

        perform action mainWorkflow : ProcessAndPublish3DModel;
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def QualityRequirement;
    requirement def ScalabilityRequirement;

    requirement <'REQ-001'> primaryFunction : FunctionalRequirement {
        doc /*
            The 3D publishing platform shall accept 3D models in standard formats, 
            optimize them for web delivery, and publish them as interactive embeddable assets.
        */
        subject publishingPlatform;
    }

    requirement <'REQ-002'> processingPerformance : PerformanceRequirement {
        doc /*
            The system shall process and publish a standard 3D model (up to 100MB, 500K polygons) 
            within 3 minutes on average.
        */
        subject publishingPlatform;
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = medium;
                technicalRisk = medium;
                scheduleRisk = low;
                costRisk = low;
            }
            owner = "Platform Architect";
        }
    }

    requirement <'REQ-003'> optimizationQuality : QualityRequirement {
        doc /*
            Optimized models shall maintain a quality score of at least 80% compared to 
            the original while achieving at least 70% file size reduction.
        */
        subject publishingPlatform.optimizer;
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = high;
                technicalRisk = high;
                scheduleRisk = medium;
                costRisk = medium;
            }
            owner = "Quality Lead";
        }
    }

    requirement <'REQ-004'> formatSupport : FunctionalRequirement {
        doc /*
            The platform shall support ingestion of at least 5 industry-standard 3D formats 
            and export to at least 3 web-optimized formats.
        */
        subject publishingPlatform.ingestion;
        subject publishingPlatform.converter;
    }

    requirement <'REQ-005'> globalDistribution : ScalabilityRequirement {
        doc /*
            Published assets shall be distributed via CDN with at least 50 edge locations 
            to ensure sub-second load times globally.
        */
        subject publishingPlatform.cdn;
        @StatusInfo {
            status = StatusKind::required;
            risk {
                totalRisk = medium;
                technicalRisk = low;
                scheduleRisk = low;
                costRisk = high;
            }
            owner = "Infrastructure Lead";
        }
    }

    requirement <'REQ-006'> concurrentProcessing : ScalabilityRequirement {
        doc /*
            The system shall support processing at least 100 concurrent publishing jobs 
            without degradation in individual job performance.
        */
        subject publishingPlatform;
    }

    requirement systemRequirements {
        doc /* Top-level requirements for the 3D publishing platform. */
        require primaryFunction;
        require processingPerformance;
        require optimizationQuality;
        require formatSupport;
        require globalDistribution;
        require concurrentProcessing;
    }

    satisfy primaryFunction by publishingPlatform.mainWorkflow;
    satisfy processingPerformance by publishingPlatform.optimizer;
    satisfy optimizationQuality by publishingPlatform.qa;
    satisfy formatSupport by publishingPlatform.ingestion;
    satisfy formatSupport by publishingPlatform.converter;
    satisfy globalDistribution by publishingPlatform.cdn;
    satisfy concurrentProcessing by publishingPlatform;
}
