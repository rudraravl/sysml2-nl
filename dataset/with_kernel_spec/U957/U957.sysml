package ThreeDPublishingPlatform {
    private import ScalarValues::*;

    doc /* Comprehensive 3D publishing platform for automated processing of raw 3D models into web-ready assets. */

    attribute def FileSize {
        attribute value : Real;
    }
    attribute def PolygonCount {
        attribute value : Integer;
    }
    attribute def QualityScore {
        attribute value : Real;
    }
    attribute def ProcessingTime {
        attribute value : Real;
    }
    attribute def ImageResolution {
        attribute value : Real;
    }

    item def RawModel {
        attribute fileName : String;
        attribute format : String;
        attribute fileSize : FileSize;
        attribute polygonCount : PolygonCount;
        attribute textureResolution : ImageResolution;
    }

    item def ValidatedModel :> RawModel;

    item def OptimizedModel {
        attribute optimizationLevel : String;
        attribute fileSize : FileSize;
        attribute polygonCount : PolygonCount;
        attribute data : String;
    }

    item def ConvertedModel {
        attribute webFormat : String;
        attribute fileSize : FileSize;
        attribute data : String;
    }

    item def QualityReport {
        attribute score : QualityScore;
        attribute passed : Boolean;
        attribute issues : String[0..*];
    }

    item def Thumbnail {
        attribute cameraAngle : String;
        attribute lightingPreset : String;
        attribute imageData : String;
    }

    item def AssetMetadata {
        attribute title : String;
        attribute author : String;
        attribute tags : String[0..*];
    }

    item def ViewerConfiguration {
        attribute allowOrbit : Boolean;
        attribute allowZoom : Boolean;
        attribute allowPan : Boolean;
    }

    item def EmbedCode {
        attribute htmlSnippet : String;
        item configuration : ViewerConfiguration;
    }

    item def StoredAsset {
        item convertedModel : ConvertedModel;
        item assetMeta : AssetMetadata;
        item thumbnails : Thumbnail[0..*];
        attribute redundantCopies : Integer;
        attribute storageLocation : String;
    }

    item def DistributedAsset {
        item storedAsset : StoredAsset;
        attribute edgeLocations : String[0..*];
        attribute publicUrl : String;
    }

    item def PublishedAsset {
        item model : ConvertedModel;
        attribute publicUrl : String;
        item embedCode : EmbedCode;
        item assetMeta : AssetMetadata;
        item thumbnails : Thumbnail[0..*];
    }

    constraint def ValidFormatConstraint;
    constraint def OptimizedSizeConstraint;
    constraint def QualityScoreConstraint;
    constraint def GlobalDistributionConstraint;
    constraint def EmbedCodeConstraint;

    requirement def AcceptedModelFormats {
        doc /* The Ingestion Service shall accept uploaded models in OBJ, FBX, or GLTF format and validate file integrity. */
        require constraint validFormat : ValidFormatConstraint;
    }

    requirement def FastLoadingRequirement {
        doc /* The Optimization Engine shall reduce polygon count and compress textures to ensure fast loading times with configurable levels. */
        require constraint optimizedSize : OptimizedSizeConstraint;
    }

    requirement def QualityPreservationRequirement {
        doc /* The Quality Assurance module shall compare the optimized model to the original and reject unacceptable degradation. */
        require constraint qualityScore : QualityScoreConstraint;
    }

    requirement def GlobalDistributionRequirement {
        doc /* The CDN Distributor shall distribute published assets across a global network of edge servers for low-latency delivery. */
        require constraint globalDistribution : GlobalDistributionConstraint;
    }

    requirement def EmbedCodeRequirement {
        doc /* The Viewer Generator shall produce embeddable viewer code with orbit, zoom, and pan configuration options. */
        require constraint embedCode : EmbedCodeConstraint;
    }

    action def IngestModel {
        in rawModel : RawModel;
        out validatedModel : RawModel;
    }

    action def OptimizeModel {
        in model : RawModel;
        in optimizationLevel : String;
        out optimizedModel : OptimizedModel;
    }

    action def ConvertModel {
        in optimizedModel : OptimizedModel;
        out convertedModel : ConvertedModel;
    }

    action def InspectQuality {
        in originalModel : RawModel;
        in convertedModel : ConvertedModel;
        out qualityReport : QualityReport;
        out approvedModel : ConvertedModel;
        out rejectedModel : RawModel;
    }

    action def RenderPreviews {
        in convertedModel : ConvertedModel;
        out thumbnails : Thumbnail[0..*];
    }

    action def StoreAsset {
        in convertedModel : ConvertedModel;
        in assetMeta : AssetMetadata;
        in thumbnails : Thumbnail[0..*];
        out storedAsset : StoredAsset;
    }

    action def DistributeAsset {
        in storedAsset : StoredAsset;
        out distributedAsset : DistributedAsset;
    }

    action def EnrichMetadata {
        in rawModel : RawModel;
        out assetMeta : AssetMetadata;
    }

    action def GenerateViewer {
        in distributedAsset : DistributedAsset;
        in viewerConfig : ViewerConfiguration;
        out embedCode : EmbedCode;
        out publishedAsset : PublishedAsset;
    }

    action def PublishModelPipeline {
        in rawModel : RawModel;
        in optimizationLevel : String;
        in viewerConfig : ViewerConfiguration;
        out publishedAsset : PublishedAsset;
        out embedCode : EmbedCode;
        out qualityReport : QualityReport;

        action ingest : IngestModel;
        action generateMetadata : EnrichMetadata;
        action optimize : OptimizeModel;
        action convert : ConvertModel;
        action inspect : InspectQuality;
        action renderPreviews : RenderPreviews;
        action store : StoreAsset;
        action distribute : DistributeAsset;
        action generateViewer : GenerateViewer;

        flow rawModel to ingest.rawModel;
        flow ingest.validatedModel to generateMetadata.rawModel;
        flow ingest.validatedModel to optimize.model;
        flow ingest.validatedModel to inspect.originalModel;
        flow optimizationLevel to optimize.optimizationLevel;
        flow optimize.optimizedModel to convert.optimizedModel;
        flow convert.convertedModel to inspect.convertedModel;
        flow inspect.approvedModel to renderPreviews.convertedModel;
        flow inspect.approvedModel to store.convertedModel;
        flow inspect.rejectedModel to optimize.model;
        flow generateMetadata.assetMeta to store.assetMeta;
        flow renderPreviews.thumbnails to store.thumbnails;
        flow store.storedAsset to distribute.storedAsset;
        flow distribute.distributedAsset to generateViewer.distributedAsset;
        flow viewerConfig to generateViewer.viewerConfig;
        flow generateViewer.publishedAsset to publishedAsset;
        flow generateViewer.embedCode to embedCode;
        flow inspect.qualityReport to qualityReport;

        ingest then optimize;
        ingest then generateMetadata;
        optimize then convert;
        convert then inspect;
        inspect then renderPreviews;
        renderPreviews then store;
        generateMetadata then store;
        store then distribute;
        distribute then generateViewer;
    }

    state machine def PublishingProcess {
        transition t_init from initial to ingesting;
        state ingesting;
        transition t1 from ingesting to optimizing;
        state optimizing;
        transition t2 from optimizing to converting;
        state converting;
        transition t3 from converting to qualityChecking;
        state qualityChecking;
        transition t4 from qualityChecking to rendering;
        transition t5 from qualityChecking to optimizing;
        state rendering;
        transition t6 from rendering to storing;
        state storing;
        transition t7 from storing to distributing;
        state distributing;
        transition t8 from distributing to publishing;
        state publishing;
        transition t9 from publishing to done;
        state done;
    }

    part def IngestionService {
        port uploadPort {
            in rawModel : RawModel;
        }
        port validatedPort {
            out validatedModel : RawModel;
        }
    }

    part def OptimizationEngine {
        port modelInputPort {
            in model : RawModel;
            in optimizationLevel : String;
        }
        port optimizedOutputPort {
            out optimizedModel : OptimizedModel;
        }
    }

    part def ConversionPipeline {
        port inputPort {
            in optimizedModel : OptimizedModel;
        }
        port outputPort {
            out convertedModel : ConvertedModel;
        }
    }

    part def QualityAssurance {
        port originalInputPort {
            in originalModel : RawModel;
        }
        port convertedInputPort {
            in convertedModel : ConvertedModel;
        }
        port reportPort {
            out qualityReport : QualityReport;
        }
        port approvedPort {
            out approvedModel : ConvertedModel;
        }
        port reworkPort {
            out rejectedModel : RawModel;
        }
    }

    part def RenderingService {
        port inputPort {
            in convertedModel : ConvertedModel;
        }
        port thumbnailOutputPort {
            out thumbnails : Thumbnail[0..*];
        }
    }

    part def StorageManager {
        port inputPort {
            in convertedModel : ConvertedModel;
            in assetMeta : AssetMetadata;
            in thumbnails : Thumbnail[0..*];
        }
        port storedOutputPort {
            out storedAsset : StoredAsset;
        }
    }

    part def CDNDistributor {
        port inputPort {
            in storedAsset : StoredAsset;
        }
        port distributedOutputPort {
            out distributedAsset : DistributedAsset;
        }
    }

    part def ViewerGenerator {
        port assetInputPort {
            in distributedAsset : DistributedAsset;
        }
        port configInputPort {
            in viewerConfig : ViewerConfiguration;
        }
        port embedOutputPort {
            out embedCode : EmbedCode;
        }
        port publishedOutputPort {
            out publishedAsset : PublishedAsset;
        }
    }

    part def MetadataService {
        port modelInputPort {
            in rawModel : RawModel;
        }
        port metadataOutputPort {
            out assetMeta : AssetMetadata;
        }
    }

    part def ThreeDPublishingPlatform {
        port uploadPort {
            in rawModel : RawModel;
        }
        port optimizationLevelPort {
            in optimizationLevel : String;
        }
        port viewerConfigPort {
            in viewerConfig : ViewerConfiguration;
        }
        port publishedOutputPort {
            out publishedAsset : PublishedAsset;
        }
        port embedCodePort {
            out embedCode : EmbedCode;
        }

        part ingestionService : IngestionService;
        part optimizationEngine : OptimizationEngine;
        part conversionPipeline : ConversionPipeline;
        part qualityAssurance : QualityAssurance;
        part renderingService : RenderingService;
        part storageManager : StorageManager;
        part cdnDistributor : CDNDistributor;
        part viewerGenerator : ViewerGenerator;
        part metadataService : MetadataService;

        bind uploadPort = ingestionService.uploadPort;
        bind publishedOutputPort = viewerGenerator.publishedOutputPort;
        bind embedCodePort = viewerGenerator.embedOutputPort;

        flow optimizationLevelFlow of String
            from optimizationLevelPort.optimizationLevel
            to optimizationEngine.modelInputPort.optimizationLevel;
        flow viewerConfigFlow of ViewerConfiguration
            from viewerConfigPort.viewerConfig
            to viewerGenerator.configInputPort.viewerConfig;

        flow validatedToOptFlow of RawModel
            from ingestionService.validatedPort.validatedModel
            to optimizationEngine.modelInputPort.model;
        flow validatedToMetadataFlow of RawModel
            from ingestionService.validatedPort.validatedModel
            to metadataService.modelInputPort.rawModel;
        flow validatedToQAFlow of RawModel
            from ingestionService.validatedPort.validatedModel
            to qualityAssurance.originalInputPort.originalModel;
        flow optimizedFlow of OptimizedModel
            from optimizationEngine.optimizedOutputPort.optimizedModel
            to conversionPipeline.inputPort.optimizedModel;
        flow convertedFlow of ConvertedModel
            from conversionPipeline.outputPort.convertedModel
            to qualityAssurance.convertedInputPort.convertedModel;
        flow approvedToRenderFlow of ConvertedModel
            from qualityAssurance.approvedPort.approvedModel
            to renderingService.inputPort.convertedModel;
        flow approvedToStorageFlow of ConvertedModel
            from qualityAssurance.approvedPort.approvedModel
            to storageManager.inputPort.convertedModel;
        flow reworkFlow of RawModel
            from qualityAssurance.reworkPort.rejectedModel
            to optimizationEngine.modelInputPort.model;
        flow metadataFlow of AssetMetadata
            from metadataService.metadataOutputPort.assetMeta
            to storageManager.inputPort.assetMeta;
        flow thumbnailsFlow of Thumbnail
            from renderingService.thumbnailOutputPort.thumbnails
            to storageManager.inputPort.thumbnails;
        flow storedFlow of StoredAsset
            from storageManager.storedOutputPort.storedAsset
            to cdnDistributor.inputPort.storedAsset;
        flow distributedFlow of DistributedAsset
            from cdnDistributor.distributedOutputPort.distributedAsset
            to viewerGenerator.assetInputPort.distributedAsset;

        exhibit publishingProcess : PublishingProcess;

        requirement acceptedFormatsReq : AcceptedModelFormats;
        satisfy acceptedFormatsReq by ingestionService;
        requirement fastLoadingReq : FastLoadingRequirement;
        satisfy fastLoadingReq by optimizationEngine;
        requirement qualityPreservationReq : QualityPreservationRequirement;
        satisfy qualityPreservationReq by qualityAssurance;
        requirement globalDistributionReq : GlobalDistributionRequirement;
        satisfy globalDistributionReq by cdnDistributor;
        requirement embedCodeReq : EmbedCodeRequirement;
        satisfy embedCodeReq by viewerGenerator;
    }

    part publishingPlatform : ThreeDPublishingPlatform;
}
