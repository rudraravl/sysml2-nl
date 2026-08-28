package ThreeDPublishingPlatform {
    public import ScalarValues::*;
    public import ISQ::*;
    
    // ===== Value Types =====
    value type FileSize :> Real {
        unit 'B';
    }
    value type PolygonCount :> Integer {
        unit 'polygons';
    }
    value type QualityScore :> Real {
        unit 'score';
    }
    value type Duration_ms :> Real {
        unit 'ms';
    }
    value type Distance_km :> Real {
        unit 'km';
    }
    value type Bitrate_Mbps :> Real {
        unit 'Mbps';
    }
    
    // ===== Enumerations =====
    enum FileFormat { OBJ; FBX; GLTF; GLB; USDZ; }
    enum OptimizationLevel { low; medium; high; }
    enum ViewerEngine { WebGL; ThreeJS; BabylonJS; }
    enum InteractionMode { orbit; zoom; pan; }
    enum LightingPreset { studio; outdoor; neutral; dramatic; }
    enum CameraAngle { front; side; top; perspective; isometric; }
    enum ProcessingState { idle; ingesting; validating; optimizing; converting; qualityChecking; rendering; storing; distributing; generatingViewer; publishing; completed; failed; }
    enum ValidationStatus { valid; invalid; corrupted; unsupported; }
    enum QAStatus { passed; failed; pending; }
    
    // ===== Item Definitions =====
    item def Raw3DModel {
        attribute format : FileFormat;
        attribute fileSize : FileSize;
        attribute polygonCount : PolygonCount;
        attribute textureCount : Integer;
        attribute sourceFileName : String;
        attribute uploadedBy : String;
    }
    
    item def OptimizedModel {
        attribute format : FileFormat;
        attribute fileSize : FileSize;
        attribute polygonCount : PolygonCount;
        attribute optimizationLevel : OptimizationLevel;
        attribute compressionRatio : Real;
        attribute textureResolution : Integer;
    }
    
    item def ConvertedAsset {
        attribute targetFormat : FileFormat;
        attribute viewerEngine : ViewerEngine;
        attribute fileSize : FileSize;
        attribute polygonCount : PolygonCount;
    }
    
    item def ThumbnailImage {
        attribute cameraAngle : CameraAngle;
        attribute lightingPreset : LightingPreset;
        attribute width : Integer;
        attribute height : Integer;
        attribute fileSize : FileSize;
    }
    
    item def PreviewImage {
        attribute cameraAngle : CameraAngle;
        attribute lightingPreset : LightingPreset;
        attribute width : Integer;
        attribute height : Integer;
        attribute fileSize : FileSize;
    }
    
    item def EmbedCode {
        attribute htmlSnippet : String;
        attribute publicURL : String;
        attribute viewerEngine : ViewerEngine;
        attribute allowedInteractions : InteractionMode[0..*];
        attribute width : Integer;
        attribute height : Integer;
    }
    
    item def Metadata {
        attribute title : String;
        attribute author : String;
        attribute description : String;
        attribute tags : String[0..*];
        attribute license : String;
        attribute creationDate : String;
    }
    
    item def PublishedAsset {
        attribute assetId : String;
        attribute optimizedModel : OptimizedModel;
        attribute convertedAsset : ConvertedAsset;
        attribute thumbnails : ThumbnailImage[0..*];
        attribute previews : PreviewImage[0..*];
        attribute embedCode : EmbedCode;
        attribute metadata : Metadata;
        attribute publicURL : String;
        attribute qualityScore : QualityScore;
        attribute publishedTimestamp : String;
    }
    
    item def QAReport {
        attribute qualityScore : QualityScore;
        attribute status : QAStatus;
        attribute visualFidelityDelta : Real;
        attribute textureQualityLoss : Real;
        attribute geometryDeviation : Real;
        attribute notes : String;
    }
    
    item def StorageManifest {
        attribute primaryLocation : String;
        attribute replicaLocations : String[0..*];
        attribute redundancyLevel : Integer;
        attribute checksum : String;
    }
    
    item def DistributionRecord {
        attribute edgeServers : String[0..*];
        attribute regionCount : Integer;
        attribute closestEdgeDistance : Distance_km;
        attribute averageLatency : Duration_ms;
    }
    
    // ===== Port Definitions =====
    port def UploadPort {
        out item rawModel : Raw3DModel;
    }
    
    port def ValidatedModelPort {
        in item rawModel : Raw3DModel;
        out item validatedModel : Raw3DModel;
        out attribute validationStatus : ValidationStatus;
    }
    
    port def OptimizationPort {
        in item inputModel : Raw3DModel;
        in attribute level : OptimizationLevel;
        out item optimizedModel : OptimizedModel;
    }
    
    port def ConversionPort {
        in item optimizedModel : OptimizedModel;
        in attribute targetEngine : ViewerEngine;
        out item convertedAsset : ConvertedAsset;
    }
    
    port def QAPort {
        in item originalModel : Raw3DModel;
        in item convertedAsset : ConvertedAsset;
        out item qaReport : QAReport;
    }
    
    port def RenderingPort {
        in item convertedAsset : ConvertedAsset;
        out item thumbnails : ThumbnailImage[0..*];
        out item previews : PreviewImage[0..*];
    }
    
    port def StoragePort {
        in item convertedAsset : ConvertedAsset;
        in item thumbnails : ThumbnailImage[0..*];
        in item previews : PreviewImage[0..*];
        out item storageManifest : StorageManifest;
    }
    
    port def DistributionPort {
        in item storageManifest : StorageManifest;
        out item distributionRecord : DistributionRecord;
    }
    
    port def ViewerGenerationPort {
        in item convertedAsset : ConvertedAsset;
        in item metadata : Metadata;
        out item embedCode : EmbedCode;
    }
    
    port def MetadataPort {
        in item rawModel : Raw3DModel;
        in attribute title : String;
        in attribute author : String;
        in attribute tags : String[0..*];
        out item metadata : Metadata;
    }
    
    port def PublishedAssetPort {
        out item publishedAsset : PublishedAsset;
    }
    
    // ===== Requirements =====
    requirement def PlatformRequirement {
        doc "The 3D publishing platform shall process raw 3D models into interactive web-ready assets for global distribution."
    }
    
    requirement def IngestionRequirement :> PlatformRequirement {
        subject ingestionService : Anything;
        requirement {
            doc "The Ingestion Service shall accept uploads in OBJ, FBX, and GLTF formats and validate file integrity."
        }
    }
    
    requirement def OptimizationRequirement :> PlatformRequirement {
        subject optimizationEngine : Anything;
        requirement {
            doc "The Optimization Engine shall reduce polygon count and compress textures according to the selected optimization level."
        }
        attribute maxFileSizeAfterOptimization : FileSize = 50_000_000;
        attribute minCompressionRatio : Real = 0.3;
    }
    
    requirement def ConversionRequirement :> PlatformRequirement {
        subject conversionPipeline : Anything;
        requirement {
            doc "The Conversion Pipeline shall convert optimized models into WebGL-compatible formats."
        }
    }
    
    requirement def QARequirement :> PlatformRequirement {
        subject qaModule : Anything;
        requirement {
            doc "The QA module shall compare the converted asset against the original and compute a quality score."
        }
        attribute minAcceptableQualityScore : QualityScore = 0.75;
    }
    
    requirement def RenderingRequirement :> PlatformRequirement {
        subject renderingService : Anything;
        requirement {
            doc "The Rendering Service shall generate thumbnails and preview images from multiple camera angles and lighting presets."
        }
        attribute minThumbnailCount : Integer = 4;
        attribute minPreviewCount : Integer = 3;
    }
    
    requirement def StorageRequirement :> PlatformRequirement {
        subject storageManager : Anything;
        requirement {
            doc "The Storage Manager shall persist assets with redundancy to prevent data loss."
        }
        attribute minReplicaCount : Integer = 3;
    }
    
    requirement def DistributionRequirement :> PlatformRequirement {
        subject cdnDistributor : Anything;
        requirement {
            doc "The CDN Distributor shall distribute assets across global edge servers for low-latency delivery."
        }
        attribute maxEdgeLatency : Duration_ms = 200;
    }
    
    requirement def ViewerRequirement :> PlatformRequirement {
        subject viewerGenerator : Anything;
        requirement {
            doc "The Viewer Generator shall produce embeddable viewer code with configurable interaction options."
        }
    }
    
    requirement def MetadataRequirement :> PlatformRequirement {
        subject metadataService : Anything;
        requirement {
            doc "The Metadata Service shall enrich assets with searchable metadata including title, author, and tags."
        }
    }
    
    // ===== Parts =====
    part def IngestionService {
        port uploadPort : UploadPort;
        port validatedOutput : ValidatedModelPort;
        
        attribute supportedFormats : FileFormat[3] = (FileFormat::OBJ, FileFormat::FBX, FileFormat::GLTF);
        attribute maxUploadSize : FileSize = 2_000_000_000;
        
        action def performValidation {
            in item model : Raw3DModel;
            out item validatedModel : Raw3DModel;
            out attribute status : ValidationStatus;
            
            if model.format in supportedFormats then {
                if model.fileSize <= maxUploadSize then {
                    // Simulate integrity check
                    assign status := ValidationStatus::valid;
                    assign validatedModel := model;
                } else {
                    assign status := ValidationStatus::unsupported;
                }
            } else {
                assign status := ValidationStatus::unsupported;
            }
        }
        
        action validateAndForward {
            in item incomingModel : Raw3DModel;
            out item outgoingModel : Raw3DModel;
            out attribute validationStatus : ValidationStatus;
            
            perform performValidation(in incomingModel, out outgoingModel, out validationStatus);
        }
    }
    
    part def OptimizationEngine {
        port optimizationInput : OptimizationPort;
        
        attribute defaultLevel : OptimizationLevel = OptimizationLevel::medium;
        
        action def optimizeModel {
            in item inputModel : Raw3DModel;
            in attribute level : OptimizationLevel;
            out item result : OptimizedModel;
            
            attribute reductionFactor : Real;
            attribute textureScale : Real;
            
            if level == OptimizationLevel::low {
                assign reductionFactor := 0.8;
                assign textureScale := 0.9;
            } else if level == OptimizationLevel::medium {
                assign reductionFactor := 0.5;
                assign textureScale := 0.6;
            } else {
                assign reductionFactor := 0.25;
                assign textureScale := 0.35;
            }
            
            assign result.format := inputModel.format;
            assign result.polygonCount := Integer::round(inputModel.polygonCount * reductionFactor);
            assign result.fileSize := inputModel.fileSize * reductionFactor * textureScale;
            assign result.optimizationLevel := level;
            assign result.compressionRatio := reductionFactor * textureScale;
            assign result.textureResolution := Integer::round(2048 * textureScale);
        }
    }
    
    part def ConversionPipeline {
        port conversionInput : ConversionPort;
        
        action def convertModel {
            in item optimizedModel : OptimizedModel;
            in attribute targetEngine : ViewerEngine;
            out item result : ConvertedAsset;
            
            if targetEngine == ViewerEngine::WebGL {
                assign result.targetFormat := FileFormat::GLB;
            } else if targetEngine == ViewerEngine::ThreeJS {
                assign result.targetFormat := FileFormat::GLTF;
            } else {
                assign result.targetFormat := FileFormat::GLB;
            }
            
            assign result.viewerEngine := targetEngine;
            assign result.fileSize := optimizedModel.fileSize * 0.95;
            assign result.polygonCount := optimizedModel.polygonCount;
        }
    }
    
    part def QualityAssuranceModule {
        port qaInput : QAPort;
        
        attribute minAcceptableScore : QualityScore = 0.75;
        attribute maxRetries : Integer = 2;
        
        action def performQA {
            in item originalModel : Raw3DModel;
            in item convertedAsset : ConvertedAsset;
            out item report : QAReport;
            
            attribute polygonDelta : Real;
            attribute sizeDelta : Real;
            
            assign polygonDelta := (originalModel.polygonCount - convertedAsset.polygonCount) / originalModel.polygonCount;
            assign sizeDelta := (originalModel.fileSize - convertedAsset.fileSize) / originalModel.fileSize;
            assign report.qualityScore := 1.0 - (polygonDelta * 0.3);
            assign report.visualFidelityDelta := polygonDelta;
            assign report.textureQualityLoss := sizeDelta * 0.5;
            assign report.geometryDeviation := polygonDelta * 0.1;
            
            if report.qualityScore >= minAcceptableScore {
                assign report.status := QAStatus::passed;
            } else {
                assign report.status := QAStatus::failed;
            }
            assign report.notes := "Automated QA comparison complete.";
        }
    }
    
    part def RenderingService {
        port renderingInput : RenderingPort;
        
        attribute cameraAngles : CameraAngle[5] = (CameraAngle::front, CameraAngle::side, CameraAngle::top, CameraAngle::perspective, CameraAngle::isometric);
        attribute lightingPresets : LightingPreset[4] = (LightingPreset::studio, LightingPreset::outdoor, LightingPreset::neutral, LightingPreset::dramatic);
        
        action def generateThumbnails {
            in item asset : ConvertedAsset;
            out item thumbs : ThumbnailImage[0..*];
            
            for angle in cameraAngles {
                for preset in lightingPresets {
                    attribute thumb : ThumbnailImage;
                    assign thumb.cameraAngle := angle;
                    assign thumb.lightingPreset := preset;
                    assign thumb.width := 256;
                    assign thumb.height := 256;
                    assign thumb.fileSize := 50_000;
                    thumbs.append(thumb);
                }
            }
        }
        
        action def generatePreviews {
            in item asset : ConvertedAsset;
            out item prevs : PreviewImage[0..*];
            
            for angle in cameraAngles {
                attribute prev : PreviewImage;
                assign prev.cameraAngle := angle;
                assign prev.lightingPreset := LightingPreset::studio;
                assign prev.width := 1024;
                assign prev.height := 768;
                assign prev.fileSize := 250_000;
                prevs.append(prev);
            }
        }
        
        action renderAssets {
            in item asset : ConvertedAsset;
            out item thumbnails : ThumbnailImage[0..*];
            out item previews : PreviewImage[0..*];
            
            perform generateThumbnails(in asset, out thumbnails);
            perform generatePreviews(in asset, out previews);
        }
    }
    
    part def StorageManager {
        port storageInput : StoragePort;
        
        attribute primaryRegion : String = "us-east-1";
        attribute replicaRegions : String[3] = ("eu-west-1", "ap-southeast-1", "us-west-2");
        attribute minReplicas : Integer = 3;
        
        action def storeAsset {
            in item asset : ConvertedAsset;
            in item thumbnails : ThumbnailImage[0..*];
            in item previews : PreviewImage[0..*];
            out item manifest : StorageManifest;
            
            assign manifest.primaryLocation := primaryRegion;
            assign manifest.replicaLocations := replicaRegions;
            assign manifest.redundancyLevel := minReplicas;
            assign manifest.checksum := "sha256:auto-generated";
        }
    }
    
    part def CDNDistributor {
        port distributionInput : DistributionPort;
        
        attribute edgeRegions : String[6] = ("north-america-east", "north-america-west", "europe-central", "asia-pacific", "south-america", "africa-south");
        attribute maxLatency : Duration_ms = 200;
        
        action def distributeAsset {
            in item manifest : StorageManifest;
            out item record : DistributionRecord;
            
            assign record.edgeServers := edgeRegions;
            assign record.regionCount := edgeRegions.size();
            assign record.closestEdgeDistance := 50.0;
            assign record.averageLatency := 85.0;
        }
    }
    
    part def ViewerGenerator {
        port viewerInput : ViewerGenerationPort;
        
        attribute defaultInteractions : InteractionMode[3] = (InteractionMode::orbit, InteractionMode::zoom, InteractionMode::pan);
        
        action def generateEmbedCode {
            in item asset : ConvertedAsset;
            in item metadata : Metadata;
            out item code : EmbedCode;
            
            assign code.htmlSnippet := "<div data-viewer=\"" + asset.viewerEngine.toString() + "\"></div>";
            assign code.publicURL := "https://cdn.3dplatform.com/assets/" + metadata.title;
            assign code.viewerEngine := asset.viewerEngine;
            assign code.allowedInteractions := defaultInteractions;
            assign code.width := 800;
            assign code.height := 600;
        }
    }
    
    part def MetadataService {
        port metadataInput : MetadataPort;
        
        action def enrichMetadata {
            in item rawModel : Raw3DModel;
            in attribute title : String;
            in attribute author : String;
            in attribute tags : String[0..*];
            out item meta : Metadata;
            
            assign meta.title := title;
            assign meta.author := author;
            assign meta.description := "Auto-generated description for " + rawModel.sourceFileName;
            assign meta.tags := tags;
            assign meta.license := "CC-BY-4.0";
            assign meta.creationDate := "2025-01-01T00:00:00Z";
        }
    }
    
    // ===== Top-level Platform Part =====
    part def ThreeDPublishingPlatformSystem {
        port systemUploadPort : UploadPort;
        port systemOutputPort : PublishedAssetPort;
        
        attribute currentState : ProcessingState := ProcessingState::idle;
        attribute activeAssetId : String;
        
        part ingestion : IngestionService {
            requirement ingestionReq : IngestionRequirement;
        }
        
        part optimization : OptimizationEngine {
            requirement optReq : OptimizationRequirement;
        }
        
        part conversion : ConversionPipeline {
            requirement convReq : ConversionRequirement;
        }
        
        part qa : QualityAssuranceModule {
            requirement qaReq : QARequirement;
        }
        
        part rendering : RenderingService {
            requirement renderReq : RenderingRequirement;
        }
        
        part storage : StorageManager {
            requirement storageReq : StorageRequirement;
        }
        
        part cdn : CDNDistributor {
            requirement cdnReq : DistributionRequirement;
        }
        
        part viewerGen : ViewerGenerator {
            requirement viewerReq : ViewerRequirement;
        }
        
        part metadataSvc : MetadataService {
            requirement metaReq : MetadataRequirement;
        }
        
        // Internal flow connections
        connection ingestion.validatedOutput.validatedModel to optimization.optimizationInput.inputModel;
        connection optimization.optimizationInput.optimizedModel to conversion.conversionInput.optimizedModel;
        connection conversion.conversionInput.convertedAsset to qa.qaInput.convertedAsset;
        connection ingestion.validatedOutput.validatedModel to qa.qaInput.originalModel;
        connection conversion.conversionInput.convertedAsset to rendering.renderingInput.convertedAsset;
        connection conversion.conversionInput.convertedAsset to storage.storageInput.convertedAsset;
        connection rendering.renderingInput.thumbnails to storage.storageInput.thumbnails;
        connection rendering.renderingInput.previews to storage.storageInput.previews;
        connection storage.storageInput.storageManifest to cdn.distributionInput.storageManifest;
        connection conversion.conversionInput.convertedAsset to viewerGen.viewerInput.convertedAsset;
        connection metadataSvc.metadataInput.metadata to viewerGen.viewerInput.metadata;
        
        // State machine for the platform
        state def PlatformLifecycle {
            entry; then idle;
            
            state idle;
            state ingesting;
            state validating;
            state optimizing;
            state converting;
            state qualityChecking;
            state rendering;
            state storing;
            state distributing;
            state generatingViewer;
            state publishing;
            state completed;
            state failed;
            
            transition idle to ingesting
                when systemUploadPort.rawModel->notEmpty()
                do { assign currentState := ProcessingState::ingesting; };
            
            transition ingesting to validating
                do { assign currentState := ProcessingState::validating; };
            
            transition validating to optimizing
                when ingestion.validatedOutput.validationStatus == ValidationStatus::valid
                do { assign currentState := ProcessingState::optimizing; };
            
            transition validating to failed
                when ingestion.validatedOutput.validationStatus != ValidationStatus::valid
                do { assign currentState := ProcessingState::failed; };
            
            transition optimizing to converting
                do { assign currentState := ProcessingState::converting; };
            
            transition converting to qualityChecking
                do { assign currentState := ProcessingState::qualityChecking; };
            
            transition qualityChecking to rendering
                when qa.qaInput.qaReport.status == QAStatus::passed
                do { assign currentState := ProcessingState::rendering; };
            
            transition qualityChecking to optimizing
                when qa.qaInput.qaReport.status == QAStatus::failed
                do { assign currentState := ProcessingState::optimizing; };
            
            transition rendering to storing
                do { assign currentState := ProcessingState::storing; };
            
            transition storing to distributing
                do { assign currentState := ProcessingState::distributing; };
            
            transition distributing to generatingViewer
                do { assign currentState := ProcessingState::generatingViewer; };
            
            transition generatingViewer to publishing
                do { assign currentState := ProcessingState::publishing; };
            
            transition publishing to completed
                do { assign currentState := ProcessingState::completed; };
        }
        
        // Main processing action
        action def processModel {
            in item rawModel : Raw3DModel;
            in attribute optLevel : OptimizationLevel := OptimizationLevel::medium;
            in attribute targetEngine : ViewerEngine := ViewerEngine::ThreeJS;
            in attribute title : String;
            in attribute author : String;
            in attribute tags : String[0..*];
            out item publishedAsset : PublishedAsset;
            
            item validatedModel : Raw3DModel;
            item optimizedModel : OptimizedModel;
            item convertedAsset : ConvertedAsset;
            item qaReport : QAReport;
            item thumbnails : ThumbnailImage[0..*];
            item previews : PreviewImage[0..*];
            item storageManifest : StorageManifest;
            item distributionRecord : DistributionRecord;
            item metadata : Metadata;
            item embedCode : EmbedCode;
            
            // Step 1: Ingestion & Validation
            perform ingestion.validateAndForward(in rawModel, out validatedModel);
            
            // Step 2: Optimization
            perform optimization.optimizeModel(in validatedModel, in optLevel, out optimizedModel);
            
            // Step 3: Conversion
            perform conversion.convertModel(in optimizedModel, in targetEngine, out convertedAsset);
            
            // Step 4: Quality Assurance
            perform qa.performQA(in validatedModel, in convertedAsset, out qaReport);
            
            // Step 5: Rendering
            perform rendering.renderAssets(in convertedAsset, out thumbnails, out previews);
            
            // Step 6: Storage
            perform storage.storeAsset(in convertedAsset, in thumbnails, in previews, out storageManifest);
            
            // Step 7: CDN Distribution
            perform cdn.distributeAsset(in storageManifest, out distributionRecord);
            
            // Step 8: Metadata Enrichment
            perform metadataSvc.enrichMetadata(in validatedModel, in title, in author, in tags, out metadata);
            
            // Step 9: Viewer Generation
            perform viewerGen.generateEmbedCode(in convertedAsset, in metadata, out embedCode);
            
            // Step 10: Assemble Published Asset
            assign publishedAsset.assetId := "asset-" + rawModel.sourceFileName;
            assign publishedAsset.optimizedModel := optimizedModel;
            assign publishedAsset.convertedAsset := convertedAsset;
            assign publishedAsset.thumbnails := thumbnails;
            assign publishedAsset.previews := previews;
            assign publishedAsset.embedCode := embedCode;
            assign publishedAsset.metadata := metadata;
            assign publishedAsset.publicURL := embedCode.publicURL;
            assign publishedAsset.qualityScore := qaReport.qualityScore;
            assign publishedAsset.publishedTimestamp := "2025-01-01T12:00:00Z";
        }
        
        // Orchestrating action that ties to state machine
        action runPipeline {
            in item rawModel : Raw3DModel;
            out item publishedAsset : PublishedAsset;
            
            perform processModel(
                in rawModel = rawModel,
                in optLevel = OptimizationLevel::high,
                in targetEngine = ViewerEngine::ThreeJS,
                in title = "Untitled Model",
                in author = rawModel.uploadedBy,
                in tags = {},
                out publishedAsset = publishedAsset
            );
        }
        
        exhibit PlatformLifecycle;
    }
    
    // ===== Instantiation =====
    part platformInstance : ThreeDPublishingPlatformSystem {
        // Ready to receive uploads
    }
}
