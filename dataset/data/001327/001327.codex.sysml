package ThreeDPublishingSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def PixelCount :> ScalarValues::Integer;
  attribute def Percentage :> ScalarValues::Real {
    unit = "%";
  }
  attribute def Megabyte :> ScalarValues::Real {
    unit = "MB";
  }
  attribute def MegabitPerSecond :> ScalarValues::Real {
    unit = "Mbit/s";
  }
  attribute def FramesPerSecond :> ScalarValues::Real {
    unit = "frame/s";
  }
  attribute def Millimeter :> ScalarValues::Real {
    unit = "mm";
  }
  attribute def Second :> ScalarValues::Real {
    unit = "s";
  }

  item def ThreeDAsset {
    attribute identifier : String;
    attribute polygonCount : ScalarValues::Integer;
    attribute textureResolution : PixelCount;
    attribute fileSize : Megabyte;
    attribute sourceFormat : String;
  }

  item def OptimizedThreeDAsset :> ThreeDAsset {
    attribute compressionRatio : Percentage;
    attribute targetFormat : String;
    attribute estimatedLoadTime : Second;
  }

  item def MetadataRecord {
    attribute title : String;
    attribute creator : String;
    attribute license : String;
    attribute description : String;
    attribute keywords : String;
  }

  item def PublicationPackage {
    attribute packageId : String;
    attribute publicUrl : String;
    attribute version : String;
    item asset : OptimizedThreeDAsset;
    item metadata : MetadataRecord;
  }

  item def ValidationReport {
    attribute passed : Boolean;
    attribute issueCount : ScalarValues::Integer;
    attribute maxTextureSize : PixelCount;
    attribute measuredFileSize : Megabyte;
  }

  item def RenderTelemetry {
    attribute averageFrameRate : FramesPerSecond;
    attribute loadTime : Second;
    attribute bandwidthUsed : MegabitPerSecond;
  }

  port def AssetInputPort {
    in item uploadedAsset : ThreeDAsset;
    in item metadata : MetadataRecord;
  }

  port def AssetOutputPort {
    out item publishedPackage : PublicationPackage;
  }

  port def ReviewPort {
    out item validationReport : ValidationReport;
    in attribute approvalDecision : Boolean;
  }

  port def DeliveryPort {
    out item packageToClient : PublicationPackage;
    in item telemetry : RenderTelemetry;
  }

  port def StoragePort {
    out item storedPackage : PublicationPackage;
    in item retrievedPackage : PublicationPackage;
  }

  part def ThreeDPublishingPlatform {
    attribute maxUploadSize : Megabyte = 2048;
    attribute targetFrameRate : FramesPerSecond = 60;
    attribute maximumViewerLoadTime : Second = 5;
    attribute primaryFunction : String =
      "Transform authored 3D content into validated, optimized, versioned, and web-deliverable interactive publications.";

    port publisherUpload : AssetInputPort;
    port curatorReview : ReviewPort;
    port publicDelivery : DeliveryPort;
    port archiveAccess : StoragePort;

    part ingestionService : AssetIngestionService;
    part validationService : AssetValidationService;
    part optimizationService : AssetOptimizationService;
    part metadataService : MetadataManagementService;
    part publicationService : PublicationService;
    part contentRepository : ContentRepository;
    part webViewerService : WebViewerService;
    part analyticsService : AnalyticsService;

    connect publisherUpload to ingestionService.uploadPort;
    connect ingestionService.assetOut to validationService.assetIn;
    connect validationService.reportOut to curatorReview;
    connect validationService.validAssetOut to optimizationService.assetIn;
    connect optimizationService.optimizedAssetOut to publicationService.assetIn;
    connect metadataService.metadataOut to publicationService.metadataIn;
    connect publicationService.packageOut to contentRepository.storePort;
    connect contentRepository.retrievePort to webViewerService.packageIn;
    connect webViewerService.deliveryOut to publicDelivery;
    connect publicDelivery to analyticsService.telemetryIn;
  }

  part def AssetIngestionService {
    port uploadPort : AssetInputPort;
    port assetOut {
      out item acceptedAsset : ThreeDAsset;
    }

    action ingestAsset {
      in item rawAsset : ThreeDAsset;
      in item submittedMetadata : MetadataRecord;
      out item acceptedAsset : ThreeDAsset;

      first start;
      then verifyFileSize;
      then normalizeCoordinateSystem;
      then emitAcceptedAsset;
      then done;

      action verifyFileSize;
      action normalizeCoordinateSystem;
      action emitAcceptedAsset;
    }
  }

  part def AssetValidationService {
    attribute maxPolygonCount : ScalarValues::Integer = 2000000;
    attribute maxTextureResolution : PixelCount = 8192;

    port assetIn {
      in item candidateAsset : ThreeDAsset;
    }

    port validAssetOut {
      out item validatedAsset : ThreeDAsset;
    }

    port reportOut : ReviewPort;

    action validateAsset {
      in item candidateAsset : ThreeDAsset;
      out item report : ValidationReport;
      out item validatedAsset : ThreeDAsset;

      first start;
      then inspectGeometry;
      then inspectTextures;
      then inspectMetadataLinkage;
      then produceValidationReport;
      then routeValidAsset;
      then done;

      action inspectGeometry;
      action inspectTextures;
      action inspectMetadataLinkage;
      action produceValidationReport;
      action routeValidAsset;
    }
  }

  part def AssetOptimizationService {
    attribute targetFileSize : Megabyte = 120;
    attribute geometricTolerance : Millimeter = 0.5;

    port assetIn {
      in item validatedAsset : ThreeDAsset;
    }

    port optimizedAssetOut {
      out item optimizedAsset : OptimizedThreeDAsset;
    }

    action optimizeForWebPublication {
      in item validatedAsset : ThreeDAsset;
      out item optimizedAsset : OptimizedThreeDAsset;

      first start;
      then decimateMeshes;
      then bakeTextures;
      then generateLevelsOfDetail;
      then compressGeometry;
      then packageRuntimeFormat;
      then done;

      action decimateMeshes;
      action bakeTextures;
      action generateLevelsOfDetail;
      action compressGeometry;
      action packageRuntimeFormat;
    }
  }

  part def MetadataManagementService {
    port metadataIn {
      in item submittedMetadata : MetadataRecord;
    }

    port metadataOut {
      out item curatedMetadata : MetadataRecord;
    }

    action curateMetadata {
      in item submittedMetadata : MetadataRecord;
      out item curatedMetadata : MetadataRecord;

      first start;
      then checkRequiredFields;
      then assignPersistentIdentifier;
      then applyLicensePolicy;
      then publishMetadata;
      then done;

      action checkRequiredFields;
      action assignPersistentIdentifier;
      action applyLicensePolicy;
      action publishMetadata;
    }
  }

  part def PublicationService {
    attribute currentVersion : String = "1.0.0";

    port assetIn {
      in item optimizedAsset : OptimizedThreeDAsset;
    }

    port metadataIn {
      in item curatedMetadata : MetadataRecord;
    }

    port packageOut {
      out item publicationPackage : PublicationPackage;
    }

    action publishPackage {
      in item optimizedAsset : OptimizedThreeDAsset;
      in item curatedMetadata : MetadataRecord;
      out item publicationPackage : PublicationPackage;

      first start;
      then bindAssetAndMetadata;
      then createVersionRecord;
      then generatePublicUrl;
      then signPublicationManifest;
      then releasePackage;
      then done;

      action bindAssetAndMetadata;
      action createVersionRecord;
      action generatePublicUrl;
      action signPublicationManifest;
      action releasePackage;
    }
  }

  part def ContentRepository {
    attribute retainedVersions : ScalarValues::Integer = 20;

    port storePort : StoragePort;
    port retrievePort : StoragePort;

    action storePublication {
      in item publicationPackage : PublicationPackage;
      out item storedPackage : PublicationPackage;

      first start;
      then writePackageObjects;
      then indexSearchMetadata;
      then registerVersion;
      then done;

      action writePackageObjects;
      action indexSearchMetadata;
      action registerVersion;
    }
  }

  part def WebViewerService {
    attribute minimumFrameRate : FramesPerSecond = 30;
    attribute preferredFrameRate : FramesPerSecond = 60;

    port packageIn : StoragePort;
    port deliveryOut : DeliveryPort;

    action deliverInteractiveScene {
      in item requestedPackage : PublicationPackage;
      out item packageToClient : PublicationPackage;
      out item telemetry : RenderTelemetry;

      first start;
      then resolveViewerCapabilities;
      then selectLevelOfDetail;
      then streamSceneAssets;
      then renderInteractiveScene;
      then emitTelemetry;
      then done;

      action resolveViewerCapabilities;
      action selectLevelOfDetail;
      action streamSceneAssets;
      action renderInteractiveScene;
      action emitTelemetry;
    }
  }

  part def AnalyticsService {
    port telemetryIn : DeliveryPort;

    action analyzePublicationPerformance {
      in item telemetry : RenderTelemetry;

      first start;
      then aggregateLoadTime;
      then aggregateFrameRate;
      then detectPerformanceRegression;
      then done;

      action aggregateLoadTime;
      action aggregateFrameRate;
      action detectPerformanceRegression;
    }
  }

  state def PublicationLifecycle {
    state draft;
    state uploaded;
    state validating;
    state rejected;
    state optimizing;
    state awaitingApproval;
    state published;
    state archived;

    entry action initializeDraft;

    transition first draft then uploaded
      accept UploadSubmitted;

    transition uploaded then validating
      accept IngestionCompleted;

    transition validating then rejected
      accept ValidationFailed;

    transition validating then optimizing
      accept ValidationPassed;

    transition optimizing then awaitingApproval
      accept OptimizationCompleted;

    transition awaitingApproval then published
      accept CuratorApproved;

    transition awaitingApproval then rejected
      accept CuratorRejected;

    transition published then archived
      accept RetentionLimitReached;
  }

  requirement def HighLevelFunctionRequirement {
    doc
      /* The platform shall provide the primary function of converting authored 3D assets and descriptive metadata into validated, optimized, versioned, and browser-deliverable interactive 3D publications. */
  }

  requirement def AssetAcceptanceRequirement {
    attribute maximumAcceptedUploadSize : Megabyte = 2048;
    doc
      /* The platform shall accept publisher-supplied 3D assets up to the configured maximum upload size with associated descriptive metadata. */
  }

  requirement def ValidationRequirement {
    attribute maximumPolygonCount : ScalarValues::Integer = 2000000;
    attribute maximumTextureResolution : PixelCount = 8192;
    doc
      /* The platform shall validate geometry, texture, file-size, and metadata constraints before publication. */
  }

  requirement def OptimizationRequirement {
    attribute targetPublishedAssetSize : Megabyte = 120;
    attribute maximumGeometricDeviation : Millimeter = 0.5;
    doc
      /* The platform shall optimize validated 3D assets for web delivery while preserving visual fidelity within the configured geometric tolerance. */
  }

  requirement def ViewerPerformanceRequirement {
    attribute maximumInitialLoadTime : Second = 5;
    attribute minimumInteractiveFrameRate : FramesPerSecond = 30;
    doc
      /* The web viewer shall load a published 3D scene within the maximum initial load time and maintain at least the minimum interactive frame rate under supported client conditions. */
  }

  requirement def TraceabilityRequirement {
    doc
      /* Each published package shall maintain traceability among source asset identifier, optimized asset, metadata record, public URL, version, and performance telemetry. */
  }

  satisfy HighLevelFunctionRequirement by ThreeDPublishingPlatform;
  satisfy AssetAcceptanceRequirement by AssetIngestionService;
  satisfy ValidationRequirement by AssetValidationService;
  satisfy OptimizationRequirement by AssetOptimizationService;
  satisfy ViewerPerformanceRequirement by WebViewerService;
  satisfy TraceabilityRequirement by PublicationService;

  part publishingSystem : ThreeDPublishingPlatform {
    state lifecycle : PublicationLifecycle;
  }
}