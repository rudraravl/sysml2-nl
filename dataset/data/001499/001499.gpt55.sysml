package MicrosoftResearchProjectSilicaArchiveModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    doc /* System based on Microsoft Research Project Silica. Primary high-level function: preserve digital information for very long-term archival storage by encoding data as optical voxels in durable quartz glass, then reading and reconstructing the original data when requested. */

    attribute def ByteCount {
        attribute value : Integer;
        doc /* Unit: byte. */
    }

    attribute def GigaByteCount {
        attribute value : Real;
        doc /* Unit: gigabyte. */
    }

    attribute def TeraByteCount {
        attribute value : Real;
        doc /* Unit: terabyte. */
    }

    attribute def DataRate {
        attribute value : Real;
        doc /* Unit: gigabyte per second. */
    }

    attribute def ErrorRate {
        attribute value : Real;
        doc /* Unit: dimensionless bit error ratio. */
    }

    attribute def HashValue {
        attribute value : String;
        doc /* Unit: hexadecimal digest string. */
    }

    attribute def Years {
        attribute value : Real;
        doc /* Unit: year. */
    }

    attribute def Nanometers {
        attribute value : Real;
        doc /* Unit: nanometer. */
    }

    attribute def Femtoseconds {
        attribute value : Real;
        doc /* Unit: femtosecond. */
    }

    attribute def Millimeters {
        attribute value : Real;
        doc /* Unit: millimeter. */
    }

    attribute def Micrometers {
        attribute value : Real;
        doc /* Unit: micrometer. */
    }

    attribute def Watts {
        attribute value : Real;
        doc /* Unit: watt. */
    }

    attribute def Celsius {
        attribute value : Real;
        doc /* Unit: degree Celsius. */
    }

    attribute def RelativeHumidity {
        attribute value : Real;
        doc /* Unit: percent relative humidity. */
    }

    attribute def Joules {
        attribute value : Real;
        doc /* Unit: joule. */
    }

    attribute def Seconds {
        attribute value : Real;
        doc /* Unit: second. */
    }

    enum def ArchiveCommandKind {
        enum archive;
        enum retrieve;
        enum audit;
        enum purgeCatalogEntry;
        enum standby;
    }

    enum def MediaConditionKind {
        enum blank;
        enum written;
        enum verified;
        enum stored;
        enum readInProgress;
        enum retired;
        enum quarantined;
    }

    enum def OperationModeKind {
        enum offline;
        enum standby;
        enum ingesting;
        enum encoding;
        enum writing;
        enum verifying;
        enum storing;
        enum retrieving;
        enum reconstructing;
        enum audit;
        enum fault;
        enum maintenance;
    }

    item def ArchiveRequest {
        attribute requestId : String;
        attribute command : ArchiveCommandKind;
        attribute collectionName : String;
        attribute priority : Integer;
        attribute requestedRetention : Years;
        attribute requestedBy : String;
    }

    item def RetrievalRequest {
        attribute requestId : String;
        attribute collectionName : String;
        attribute objectId : String;
        attribute requestedBy : String;
        attribute priority : Integer;
    }

    item def RawDataSet {
        attribute objectId : String;
        attribute logicalName : String;
        attribute size : ByteCount;
        attribute sourceHash : HashValue;
        attribute creationTimeUtc : String;
        attribute contentType : String;
    }

    item def EncodedShard {
        attribute shardId : String;
        attribute payloadSize : ByteCount;
        attribute paritySize : ByteCount;
        attribute erasureCodeRate : Real;
        attribute encodedHash : HashValue;
    }

    item def EncodedVoxelMap {
        attribute mapId : String;
        attribute shardCount : Integer;
        attribute layerCount : Integer;
        attribute voxelCount : Integer;
        attribute nominalVoxelPitch : Micrometers;
        attribute codingRate : Real;
        attribute mapHash : HashValue;
    }

    item def QuartzSlide {
        attribute slideId : String;
        attribute condition : MediaConditionKind;
        attribute thickness : Millimeters;
        attribute width : Millimeters;
        attribute length : Millimeters;
        attribute usableCapacity : TeraByteCount;
        attribute writtenVoxelCount : Integer;
        attribute mediaTemperature : Celsius;
    }

    item def LaserWriteJob {
        attribute jobId : String;
        attribute slideId : String;
        attribute mapId : String;
        attribute pulseDuration : Femtoseconds;
        attribute wavelength : Nanometers;
        attribute averagePower : Watts;
        attribute estimatedEnergy : Joules;
        attribute estimatedDuration : Seconds;
    }

    item def OpticalImageStack {
        attribute stackId : String;
        attribute slideId : String;
        attribute planeCount : Integer;
        attribute imageCount : Integer;
        attribute pixelSize : Micrometers;
        attribute acquisitionDuration : Seconds;
    }

    item def RestoredDataSet {
        attribute objectId : String;
        attribute logicalName : String;
        attribute size : ByteCount;
        attribute restoredHash : HashValue;
        attribute uncorrectedBitErrorRate : ErrorRate;
        attribute correctedBitErrorRate : ErrorRate;
    }

    item def ArchiveCatalogRecord {
        attribute recordId : String;
        attribute objectId : String;
        attribute logicalName : String;
        attribute collectionName : String;
        attribute slideId : String;
        attribute voxelMapId : String;
        attribute sourceHash : HashValue;
        attribute retentionTarget : Years;
        attribute storageLocation : String;
        attribute verified : Boolean;
    }

    item def HealthTelemetry {
        attribute subsystemName : String;
        attribute mode : OperationModeKind;
        attribute temperature : Celsius;
        attribute humidity : RelativeHumidity;
        attribute errorRate : ErrorRate;
        attribute message : String;
    }

    item def SafetyEvent {
        attribute eventId : String;
        attribute source : String;
        attribute severity : Integer;
        attribute description : String;
    }

    port def ArchiveCommandPort {
        in item request : ArchiveRequest;
        in item retrieval : RetrievalRequest;
        out item status : HealthTelemetry;
    }

    port def RawDataPort {
        in item dataIn : RawDataSet;
        out item dataOut : RawDataSet;
    }

    port def EncodedShardPort {
        in item shardIn : EncodedShard;
        out item shardOut : EncodedShard;
    }

    port def VoxelMapPort {
        in item mapIn : EncodedVoxelMap;
        out item mapOut : EncodedVoxelMap;
    }

    port def QuartzMediaPort {
        in item mediaIn : QuartzSlide;
        out item mediaOut : QuartzSlide;
    }

    port def WriteJobPort {
        in item jobIn : LaserWriteJob;
        out item jobOut : LaserWriteJob;
    }

    port def ImageStackPort {
        in item stackIn : OpticalImageStack;
        out item stackOut : OpticalImageStack;
    }

    port def RestoredDataPort {
        in item restoredIn : RestoredDataSet;
        out item restoredOut : RestoredDataSet;
    }

    port def CatalogPort {
        in item recordIn : ArchiveCatalogRecord;
        out item recordOut : ArchiveCatalogRecord;
    }

    port def TelemetryPort {
        in item telemetryIn : HealthTelemetry;
        out item telemetryOut : HealthTelemetry;
    }

    port def SafetyPort {
        in item safetyIn : SafetyEvent;
        out item safetyOut : SafetyEvent;
    }

    action def ValidateArchiveRequest {
        in item request : ArchiveRequest;
        in item data : RawDataSet;
        out item acceptedData : RawDataSet;
        out item status : HealthTelemetry;
    }

    action def EncodeForQuartzStorage {
        in item data : RawDataSet;
        out item voxelMap : EncodedVoxelMap;
        out item shard : EncodedShard;
        attribute targetErasureCodeRate : Real = 0.72;
        attribute targetVoxelPitch : Micrometers = 1.5;
    }

    action def PrepareQuartzSlide {
        in item blankSlide : QuartzSlide;
        out item preparedSlide : QuartzSlide;
        attribute cleaningDuration : Seconds = 180.0;
        attribute maximumParticleSize : Micrometers = 0.5;
    }

    action def GenerateLaserWriteJob {
        in item voxelMap : EncodedVoxelMap;
        in item preparedSlide : QuartzSlide;
        out item writeJob : LaserWriteJob;
        attribute defaultPulseDuration : Femtoseconds = 250.0;
        attribute defaultWavelength : Nanometers = 1030.0;
        attribute nominalAveragePower : Watts = 8.0;
    }

    action def WriteVoxelsToQuartz {
        in item writeJob : LaserWriteJob;
        in item preparedSlide : QuartzSlide;
        out item writtenSlide : QuartzSlide;
        attribute allowedFocusError : Micrometers = 0.2;
        attribute maximumSlideTemperature : Celsius = 55.0;
    }

    action def ReadQuartzSlide {
        in item slide : QuartzSlide;
        out item imageStack : OpticalImageStack;
        attribute polarizerAngles : Integer = 4;
        attribute nominalPixelSize : Micrometers = 0.35;
    }

    action def ReconstructDataFromImages {
        in item imageStack : OpticalImageStack;
        out item restored : RestoredDataSet;
        attribute maximumCorrectedBitErrorRate : ErrorRate = 0.000000000001;
    }

    action def VerifyRestoredData {
        in item source : RawDataSet;
        in item restored : RestoredDataSet;
        out item verifiedRecord : ArchiveCatalogRecord;
        out item status : HealthTelemetry;
    }

    action def StoreVerifiedMedia {
        in item slide : QuartzSlide;
        in item record : ArchiveCatalogRecord;
        out item storedSlide : QuartzSlide;
        out item storedRecord : ArchiveCatalogRecord;
        attribute storageTemperature : Celsius = 20.0;
        attribute maximumStorageHumidity : RelativeHumidity = 60.0;
    }

    action def RetrieveArchivedObject {
        in item retrieval : RetrievalRequest;
        in item catalogRecord : ArchiveCatalogRecord;
        in item storedSlide : QuartzSlide;
        out item restored : RestoredDataSet;
        out item status : HealthTelemetry;
    }

    action def RunArchiveWorkflow {
        in item request : ArchiveRequest;
        in item data : RawDataSet;
        in item blankSlide : QuartzSlide;
        out item catalogRecord : ArchiveCatalogRecord;
        out item storedSlide : QuartzSlide;
        out item status : HealthTelemetry;

        action validate : ValidateArchiveRequest {
            in item request = RunArchiveWorkflow::request;
            in item data = RunArchiveWorkflow::data;
        }

        action encode : EncodeForQuartzStorage {
            in item data = validate.acceptedData;
        }

        action prepare : PrepareQuartzSlide {
            in item blankSlide = RunArchiveWorkflow::blankSlide;
        }

        action planWrite : GenerateLaserWriteJob {
            in item voxelMap = encode.voxelMap;
            in item preparedSlide = prepare.preparedSlide;
        }

        action write : WriteVoxelsToQuartz {
            in item writeJob = planWrite.writeJob;
            in item preparedSlide = prepare.preparedSlide;
        }

        action readBack : ReadQuartzSlide {
            in item slide = write.writtenSlide;
        }

        action reconstruct : ReconstructDataFromImages {
            in item imageStack = readBack.imageStack;
        }

        action verify : VerifyRestoredData {
            in item source = RunArchiveWorkflow::data;
            in item restored = reconstruct.restored;
        }

        action store : StoreVerifiedMedia {
            in item slide = write.writtenSlide;
            in item record = verify.verifiedRecord;
        }

        out item catalogRecord = store.storedRecord;
        out item storedSlide = store.storedSlide;
        out item status = verify.status;
    }

    state def SilicaArchiveOperationalStateMachine {
        attribute mode : OperationModeKind = OperationModeKind::offline;

        state offline;
        state standby;
        state ingesting;
        state encoding;
        state writing;
        state verifying;
        state storing;
        state retrieving;
        state reconstructing;
        state audit;
        state fault;
        state maintenance;

        transition powerOn first offline then standby;
        transition acceptArchiveRequest first standby then ingesting accept ArchiveRequest;
        transition beginEncoding first ingesting then encoding;
        transition beginWriting first encoding then writing;
        transition beginVerification first writing then verifying;
        transition verificationPassed first verifying then storing;
        transition archiveComplete first storing then standby;
        transition acceptRetrievalRequest first standby then retrieving accept RetrievalRequest;
        transition beginReconstruction first retrieving then reconstructing;
        transition retrievalComplete first reconstructing then standby;
        transition beginAudit first standby then audit;
        transition auditComplete first audit then standby;
        transition detectedFaultFromStandby first standby then fault accept SafetyEvent;
        transition detectedFaultFromWriting first writing then fault accept SafetyEvent;
        transition detectedFaultFromRetrieving first retrieving then fault accept SafetyEvent;
        transition enterMaintenance first fault then maintenance;
        transition maintenanceComplete first maintenance then standby;
        transition shutdown first standby then offline;
    }

    constraint def RetentionConstraint {
        in retention : Years;
        require constraint { retention.value >= 10000.0 }
    }

    constraint def IntegrityConstraint {
        in correctedBitErrorRate : ErrorRate;
        require constraint { correctedBitErrorRate.value <= 0.000000000001 }
    }

    constraint def StorageEnvironmentConstraint {
        in temperature : Celsius;
        in humidity : RelativeHumidity;
        require constraint { temperature.value >= 5.0 and temperature.value <= 35.0 and humidity.value <= 60.0 }
    }

    constraint def LaserSafetyConstraint {
        in enclosureClosed : Boolean;
        in interlockHealthy : Boolean;
        require constraint { enclosureClosed and interlockHealthy }
    }

    constraint def SlideGeometryConstraint {
        in thickness : Millimeters;
        in width : Millimeters;
        in length : Millimeters;
        require constraint { thickness.value >= 1.0 and thickness.value <= 3.0 and width.value >= 70.0 and length.value >= 70.0 }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : SilicaArchiveSystem;
        doc /* The system shall provide durable archival preservation of digital data by encoding, writing, storing, reading, and reconstructing data using quartz glass media inspired by Microsoft Research Project Silica. */
        require constraint { system.nominalRetention.value >= 10000.0 }
    }

    requirement def ArchiveCapacityRequirement {
        subject system : SilicaArchiveSystem;
        doc /* The system shall support at least 7 TB of usable data per quartz slide. */
        require constraint { system.usableCapacityPerSlide.value >= 7.0 }
    }

    requirement def DataIntegrityRequirement {
        subject system : SilicaArchiveSystem;
        doc /* The system shall verify written media by reading back the quartz slide and reconstructing the original data before accepting the media into storage. */
        require constraint { system.maximumCorrectedBitErrorRate.value <= 0.000000000001 }
    }

    requirement def RetentionRequirement {
        subject system : SilicaArchiveSystem;
        doc /* The archive shall target a preservation lifetime of 10,000 years under controlled storage conditions. */
        require RetentionConstraint { retention = system.nominalRetention }
    }

    requirement def EnvironmentalStorageRequirement {
        subject library : QuartzMediaLibrary;
        doc /* Stored quartz slides shall be maintained in a benign archival environment. */
        require StorageEnvironmentConstraint { temperature = library.nominalTemperature; humidity = library.maximumHumidity }
    }

    requirement def LaserSafetyRequirement {
        subject writer : FemtosecondLaserWriter;
        doc /* The laser writer shall prevent emission unless the optical enclosure is closed and all interlocks are healthy. */
        require LaserSafetyConstraint { enclosureClosed = writer.enclosureClosed; interlockHealthy = writer.interlockHealthy }
    }

    requirement def MediaGeometryRequirement {
        subject media : QuartzMediaLibrary;
        doc /* Quartz media handled by the system shall conform to the supported slide geometry envelope. */
        require SlideGeometryConstraint { thickness = media.nominalSlideThickness; width = media.nominalSlideWidth; length = media.nominalSlideLength }
    }

    part def IngestionGateway {
        port command : ArchiveCommandPort;
        port rawData : RawDataPort;
        port telemetry : TelemetryPort;

        attribute maximumObjectSize : TeraByteCount = 2.0;
        attribute ingestRate : DataRate = 4.0;
        attribute validatesHash : Boolean = true;

        perform action validate : ValidateArchiveRequest;
    }

    part def ErrorCorrectionCodecService {
        port rawData : RawDataPort;
        port shards : EncodedShardPort;
        port voxelMap : VoxelMapPort;
        port telemetry : TelemetryPort;

        attribute erasureCodeRate : Real = 0.72;
        attribute parityOverhead : Real = 0.39;
        attribute nominalEncodeRate : DataRate = 1.2;
        attribute targetVoxelPitch : Micrometers = 1.5;

        perform action encode : EncodeForQuartzStorage;
    }

    part def FemtosecondLaserWriter {
        port voxelMap : VoxelMapPort;
        port media : QuartzMediaPort;
        port writeJob : WriteJobPort;
        port telemetry : TelemetryPort;
        port safety : SafetyPort;

        attribute laserWavelength : Nanometers = 1030.0;
        attribute pulseDuration : Femtoseconds = 250.0;
        attribute averagePower : Watts = 8.0;
        attribute maximumSlideTemperature : Celsius = 55.0;
        attribute focusTolerance : Micrometers = 0.2;
        attribute enclosureClosed : Boolean = true;
        attribute interlockHealthy : Boolean = true;

        perform action planWrite : GenerateLaserWriteJob;
        perform action writeVoxels : WriteVoxelsToQuartz;
    }

    part def QuartzMediaLibrary {
        port media : QuartzMediaPort;
        port catalog : CatalogPort;
        port telemetry : TelemetryPort;

        attribute slideInventoryCount : Integer = 1200;
        attribute usableCapacityPerSlide : TeraByteCount = 7.0;
        attribute nominalSlideThickness : Millimeters = 2.0;
        attribute nominalSlideWidth : Millimeters = 75.0;
        attribute nominalSlideLength : Millimeters = 75.0;
        attribute nominalTemperature : Celsius = 20.0;
        attribute maximumHumidity : RelativeHumidity = 60.0;
        attribute retentionTarget : Years = 10000.0;

        perform action storeMedia : StoreVerifiedMedia;
    }

    part def RoboticMediaHandler {
        port mediaSource : QuartzMediaPort;
        port mediaDestination : QuartzMediaPort;
        port telemetry : TelemetryPort;
        port safety : SafetyPort;

        attribute placementAccuracy : Micrometers = 10.0;
        attribute transferDuration : Seconds = 12.0;
        attribute gripperForceLimited : Boolean = true;
    }

    part def PolarizedMicroscopeReader {
        port media : QuartzMediaPort;
        port imageStack : ImageStackPort;
        port telemetry : TelemetryPort;

        attribute polarizerAngleCount : Integer = 4;
        attribute illuminationWavelength : Nanometers = 530.0;
        attribute pixelSize : Micrometers = 0.35;
        attribute nominalReadRate : DataRate = 0.8;

        perform action read : ReadQuartzSlide;
    }

    part def ReconstructionComputeCluster {
        port imageStack : ImageStackPort;
        port restoredData : RestoredDataPort;
        port telemetry : TelemetryPort;

        attribute nodeCount : Integer = 16;
        attribute reconstructionRate : DataRate = 1.0;
        attribute maximumCorrectedBitErrorRate : ErrorRate = 0.000000000001;

        perform action reconstruct : ReconstructDataFromImages;
    }

    part def ArchiveCatalogService {
        port catalog : CatalogPort;
        port command : ArchiveCommandPort;
        port telemetry : TelemetryPort;

        attribute replicatedCopies : Integer = 3;
        attribute catalogEntryCount : Integer;
        attribute catalogIntegrityChecked : Boolean = true;
    }

    part def IntegrityMonitor {
        port catalog : CatalogPort;
        port telemetry : TelemetryPort;
        port safety : SafetyPort;

        attribute auditIntervalDays : Integer = 365;
        attribute maximumCorrectedBitErrorRate : ErrorRate = 0.000000000001;
        attribute quarantineOnMismatch : Boolean = true;
    }

    part def OperatorConsole {
        port command : ArchiveCommandPort;
        port telemetry : TelemetryPort;

        attribute authenticatedOperator : Boolean = true;
        attribute displaysPrimaryFunction : String = "Preserve digital data for long-term archival storage in quartz glass and restore it on demand.";
    }

    part def SilicaArchiveSystem {
        port userCommand : ArchiveCommandPort;
        port userData : RawDataPort;
        port restoredOutput : RestoredDataPort;
        port systemTelemetry : TelemetryPort;
        port safetyEvents : SafetyPort;

        attribute systemName : String = "Microsoft Research Project Silica Inspired Archive";
        attribute primaryFunction : String = "Encode digital data into optical voxels in quartz glass, preserve the media for long-duration storage, and reconstruct the data when retrieved.";
        attribute nominalRetention : Years = 10000.0;
        attribute usableCapacityPerSlide : TeraByteCount = 7.0;
        attribute maximumCorrectedBitErrorRate : ErrorRate = 0.000000000001;
        attribute normalMode : OperationModeKind = OperationModeKind::standby;

        part ingestionGateway : IngestionGateway;
        part codecService : ErrorCorrectionCodecService;
        part laserWriter : FemtosecondLaserWriter;
        part mediaLibrary : QuartzMediaLibrary;
        part roboticHandler : RoboticMediaHandler;
        part microscopeReader : PolarizedMicroscopeReader;
        part reconstructionCluster : ReconstructionComputeCluster;
        part catalogService : ArchiveCatalogService;
        part integrityMonitor : IntegrityMonitor;
        part operatorConsole : OperatorConsole;

        perform action archiveWorkflow : RunArchiveWorkflow;
        perform action retrievalWorkflow : RetrieveArchivedObject;

        exhibit state operationalStates : SilicaArchiveOperationalStateMachine;

        connect userCommand to operatorConsole.command;
        connect operatorConsole.command to ingestionGateway.command;
        connect userData to ingestionGateway.rawData;
        connect ingestionGateway.rawData to codecService.rawData;
        connect codecService.voxelMap to laserWriter.voxelMap;
        connect codecService.shards to catalogService.catalog;
        connect mediaLibrary.media to roboticHandler.mediaSource;
        connect roboticHandler.mediaDestination to laserWriter.media;
        connect laserWriter.writeJob to laserWriter.writeJob;
        connect laserWriter.media to microscopeReader.media;
        connect microscopeReader.imageStack to reconstructionCluster.imageStack;
        connect reconstructionCluster.restoredData to restoredOutput;
        connect reconstructionCluster.restoredData to catalogService.catalog;
        connect catalogService.catalog to mediaLibrary.catalog;
        connect catalogService.catalog to integrityMonitor.catalog;
        connect ingestionGateway.telemetry to systemTelemetry;
        connect codecService.telemetry to systemTelemetry;
        connect laserWriter.telemetry to systemTelemetry;
        connect mediaLibrary.telemetry to systemTelemetry;
        connect roboticHandler.telemetry to systemTelemetry;
        connect microscopeReader.telemetry to systemTelemetry;
        connect reconstructionCluster.telemetry to systemTelemetry;
        connect catalogService.telemetry to systemTelemetry;
        connect integrityMonitor.telemetry to systemTelemetry;
        connect operatorConsole.telemetry to systemTelemetry;
        connect laserWriter.safety to safetyEvents;
        connect roboticHandler.safety to safetyEvents;
        connect integrityMonitor.safety to safetyEvents;

        satisfy PrimaryFunctionRequirement by this;
        satisfy ArchiveCapacityRequirement by this;
        satisfy DataIntegrityRequirement by this;
        satisfy RetentionRequirement by this;
        satisfy EnvironmentalStorageRequirement by mediaLibrary;
        satisfy LaserSafetyRequirement by laserWriter;
        satisfy MediaGeometryRequirement by mediaLibrary;
    }

    part silicaArchiveSystem : SilicaArchiveSystem {
        attribute systemName = "Project Silica Long-Term Quartz Archive";
        attribute primaryFunction = "Long-term preservation and retrieval of digital data using Microsoft Research Project Silica inspired quartz-glass optical storage.";
        attribute nominalRetention : Years = 10000.0;
        attribute usableCapacityPerSlide : TeraByteCount = 7.0;
        attribute maximumCorrectedBitErrorRate : ErrorRate = 0.000000000001;
    }
}
