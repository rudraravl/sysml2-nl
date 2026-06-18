package AutomaticNumberPlateRecognitionModel {

    import ScalarValues::*;
    import SI::*;

    /* Value Types */

    attribute def Percent :> Real {
        doc "Dimensionless percentage expressed from 0.0 to 100.0.";
    }

    attribute def Probability :> Real {
        doc "Dimensionless probability expressed from 0.0 to 1.0.";
    }

    attribute def PixelCount :> Integer {
        doc "Count of image pixels.";
    }

    attribute def FrameRate_Hz :> Real {
        doc "Video frames per second.";
        unit = "Hz";
    }

    attribute def Latency_ms :> Real {
        doc "Processing latency in milliseconds.";
        unit = "ms";
    }

    attribute def Speed_km_per_h :> Real {
        doc "Vehicle speed in kilometers per hour.";
        unit = "km/h";
    }

    attribute def Distance_m :> Real {
        doc "Distance in meters.";
        unit = "m";
    }

    attribute def Illuminance_lx :> Real {
        doc "Scene illumination in lux.";
        unit = "lx";
    }

    attribute def Temperature_C :> Real {
        doc "Temperature in degrees Celsius.";
        unit = "degC";
    }

    attribute def Voltage_V :> Real {
        doc "Electrical voltage.";
        unit = "V";
    }

    attribute def Power_W :> Real {
        doc "Electrical power.";
        unit = "W";
    }

    attribute def DataRate_Mbps :> Real {
        doc "Digital data rate in megabits per second.";
        unit = "Mb/s";
    }

    attribute def StorageCapacity_GB :> Real {
        doc "Persistent storage capacity in gigabytes.";
        unit = "GB";
    }

    attribute def Duration_s :> Real {
        doc "Duration in seconds.";
        unit = "s";
    }

    attribute def CharacterCount :> Integer {
        doc "Number of alphanumeric characters.";
    }

    /* Item Types */

    item def VehiclePresenceEvent {
        attribute laneId : Integer;
        attribute triggerDistance : Distance_m;
        attribute estimatedSpeed : Speed_km_per_h;
        attribute timestamp_s : Duration_s;
    }

    item def IlluminationCommand {
        attribute enable : Boolean;
        attribute intensityPercent : Percent;
        attribute pulseDuration_ms : Latency_ms;
    }

    item def CameraExposureCommand {
        attribute exposureTime_ms : Latency_ms;
        attribute gainPercent : Percent;
        attribute infraredModeEnabled : Boolean;
    }

    item def ImageFrame {
        attribute frameId : Integer;
        attribute widthPixels : PixelCount;
        attribute heightPixels : PixelCount;
        attribute timestamp_s : Duration_s;
        attribute exposureTime_ms : Latency_ms;
        attribute sceneIlluminance : Illuminance_lx;
        attribute laneId : Integer;
    }

    item def PlateCandidateImage {
        attribute candidateId : Integer;
        attribute sourceFrameId : Integer;
        attribute boundingBoxX : PixelCount;
        attribute boundingBoxY : PixelCount;
        attribute boundingBoxWidth : PixelCount;
        attribute boundingBoxHeight : PixelCount;
        attribute detectionConfidence : Probability;
    }

    item def PlateText {
        attribute normalizedText : String;
        attribute characterCount : CharacterCount;
        attribute countryCode : String;
        attribute syntaxConfidence : Probability;
        attribute opticalConfidence : Probability;
    }

    item def RecognitionResult {
        attribute transactionId : Integer;
        attribute laneId : Integer;
        attribute plateString : String;
        attribute countryCode : String;
        attribute overallConfidence : Probability;
        attribute vehicleSpeed : Speed_km_per_h;
        attribute captureTimestamp_s : Duration_s;
        attribute processingLatency_ms : Latency_ms;
        attribute isReadable : Boolean;
    }

    item def AuditRecord {
        attribute transactionId : Integer;
        attribute plateString : String;
        attribute confidence : Probability;
        attribute retainedImageReference : String;
        attribute eventTimestamp_s : Duration_s;
        attribute operatorReviewRequired : Boolean;
    }

    item def OperatorAlert {
        attribute severity : String;
        attribute message : String;
        attribute transactionId : Integer;
        attribute timestamp_s : Duration_s;
    }

    item def HealthStatus {
        attribute componentName : String;
        attribute operational : Boolean;
        attribute temperature : Temperature_C;
        attribute voltage : Voltage_V;
        attribute message : String;
    }

    item def NetworkPacket {
        attribute payloadBytes : Integer;
        attribute encrypted : Boolean;
        attribute destination : String;
        attribute timestamp_s : Duration_s;
    }

    item def PowerSupply {
        attribute voltage : Voltage_V;
        attribute availablePower : Power_W;
    }

    /* Ports */

    port def VehicleDetectionPort {
        out item event : VehiclePresenceEvent;
    }

    port def IlluminationControlPort {
        in item command : IlluminationCommand;
        out item status : HealthStatus;
    }

    port def CameraControlPort {
        in item exposureCommand : CameraExposureCommand;
        out item frame : ImageFrame;
        out item status : HealthStatus;
    }

    port def FrameProcessingPort {
        in item frame : ImageFrame;
        out item candidate : PlateCandidateImage;
        out item status : HealthStatus;
    }

    port def OpticalRecognitionPort {
        in item candidate : PlateCandidateImage;
        out item text : PlateText;
        out item status : HealthStatus;
    }

    port def ResultPublicationPort {
        in item result : RecognitionResult;
        out item packet : NetworkPacket;
    }

    port def AuditPort {
        in item record : AuditRecord;
        out item alert : OperatorAlert;
    }

    port def PowerPort {
        in item supply : PowerSupply;
        out item status : HealthStatus;
    }

    port def HealthMonitoringPort {
        in item status : HealthStatus;
        out item alert : OperatorAlert;
    }

    /* Actions */

    action def DetectVehicle {
        in item sensorEvent : VehiclePresenceEvent;
        out item captureRequest : CameraExposureCommand;

        attribute minimumTriggerDistance : Distance_m = 2.5;
        attribute maximumSupportedSpeed : Speed_km_per_h = 180.0;
        attribute defaultExposureTime : Latency_ms = 1.2;
        attribute defaultGain : Percent = 45.0;

        doc "Interprets a vehicle presence event and produces camera exposure settings for plate image capture.";
    }

    action def IlluminatePlate {
        in item sensorEvent : VehiclePresenceEvent;
        out item illuminationCommand : IlluminationCommand;

        attribute nightIlluminanceThreshold : Illuminance_lx = 100.0;
        attribute infraredIntensity : Percent = 85.0;
        attribute visibleIntensity : Percent = 0.0;
        attribute pulseDuration : Latency_ms = 4.0;

        doc "Controls visible or infrared lighting so the number plate can be captured with readable contrast.";
    }

    action def CapturePlateImage {
        in item exposureCommand : CameraExposureCommand;
        out item image : ImageFrame;

        attribute nominalFrameRate : FrameRate_Hz = 60.0;
        attribute sensorWidth : PixelCount = 4096;
        attribute sensorHeight : PixelCount = 2160;
        attribute maximumCaptureLatency : Latency_ms = 20.0;

        doc "Captures a time-stamped high-resolution image frame of the vehicle and number plate region.";
    }

    action def LocatePlateRegion {
        in item image : ImageFrame;
        out item candidate : PlateCandidateImage;

        attribute minimumPlateWidth : PixelCount = 80;
        attribute minimumPlateHeight : PixelCount = 20;
        attribute requiredDetectionConfidence : Probability = 0.90;
        attribute maximumLocalizationLatency : Latency_ms = 35.0;

        doc "Finds rectangular number-plate candidates in the camera frame using image preprocessing and localization.";
    }

    action def RecognizePlateCharacters {
        in item candidate : PlateCandidateImage;
        out item plate : PlateText;

        attribute minimumCharacters : CharacterCount = 4;
        attribute maximumCharacters : CharacterCount = 10;
        attribute requiredOpticalConfidence : Probability = 0.92;
        attribute maximumRecognitionLatency : Latency_ms = 60.0;

        doc "Converts the localized number-plate image into normalized alphanumeric text.";
    }

    action def ValidateRecognition {
        in item plate : PlateText;
        in item candidate : PlateCandidateImage;
        out item result : RecognitionResult;

        attribute minimumOverallConfidence : Probability = 0.95;
        attribute maximumEndToEndLatency : Latency_ms = 250.0;

        doc "Combines optical confidence, plate syntax validity, and detection confidence into a final ANPR transaction result.";
    }

    action def StoreAuditEvidence {
        in item result : RecognitionResult;
        out item record : AuditRecord;

        attribute retentionPeriodDays : Integer = 30;
        attribute minimumStoredConfidence : Probability = 0.50;

        doc "Stores recognition evidence, metadata, and review flags for audit and operational traceability.";
    }

    action def PublishRecognitionResult {
        in item result : RecognitionResult;
        out item packet : NetworkPacket;

        attribute encryptionRequired : Boolean = true;
        attribute maximumPublicationLatency : Latency_ms = 100.0;

        doc "Publishes the recognized plate result to an authorized external traffic, access-control, or enforcement service.";
    }

    action def HighLevelANPRFunction {
        in item vehicleEvent : VehiclePresenceEvent;
        out item finalResult : RecognitionResult;

        action detectVehicle : DetectVehicle;
        action illuminatePlate : IlluminatePlate;
        action capturePlateImage : CapturePlateImage;
        action locatePlateRegion : LocatePlateRegion;
        action recognizePlateCharacters : RecognizePlateCharacters;
        action validateRecognition : ValidateRecognition;

        flow vehicleEvent to detectVehicle.sensorEvent;
        flow vehicleEvent to illuminatePlate.sensorEvent;
        flow detectVehicle.captureRequest to capturePlateImage.exposureCommand;
        flow capturePlateImage.image to locatePlateRegion.image;
        flow locatePlateRegion.candidate to recognizePlateCharacters.candidate;
        flow recognizePlateCharacters.plate to validateRecognition.plate;
        flow locatePlateRegion.candidate to validateRecognition.candidate;
        flow validateRecognition.result to finalResult;

        doc "Primary high-level function: automatically capture a vehicle image, locate its number plate, read the plate characters, validate confidence, and output a time-stamped recognition result.";
    }

    /* State Machines */

    state def ANPROperationalStateMachine {
        doc "Lifecycle behavior of the automatic number-plate recognition system.";

        state initializing;
        state standby;
        state vehicleDetected;
        state imageCapture;
        state plateLocalization;
        state opticalRecognition;
        state validation;
        state resultPublication;
        state auditStorage;
        state degradedOperation;
        state fault;
        state maintenance;

        transition initial_to_initializing first initializing;

        transition initializing_to_standby
            first initializing
            then standby;

        transition standby_to_vehicleDetected
            first standby
            accept VehiclePresenceEvent
            then vehicleDetected;

        transition vehicleDetected_to_imageCapture
            first vehicleDetected
            then imageCapture;

        transition imageCapture_to_plateLocalization
            first imageCapture
            then plateLocalization;

        transition plateLocalization_to_opticalRecognition
            first plateLocalization
            then opticalRecognition;

        transition opticalRecognition_to_validation
            first opticalRecognition
            then validation;

        transition validation_to_resultPublication
            first validation
            then resultPublication;

        transition resultPublication_to_auditStorage
            first resultPublication
            then auditStorage;

        transition auditStorage_to_standby
            first auditStorage
            then standby;

        transition standby_to_degradedOperation
            first standby
            accept HealthStatus
            if not operational
            then degradedOperation;

        transition degradedOperation_to_fault
            first degradedOperation
            accept HealthStatus
            if not operational
            then fault;

        transition fault_to_maintenance
            first fault
            then maintenance;

        transition maintenance_to_initializing
            first maintenance
            then initializing;
    }

    state def RecognitionTransactionStateMachine {
        doc "State progression for one vehicle recognition transaction.";

        state triggered;
        state frameAcquired;
        state plateCandidateFound;
        state textDecoded;
        state accepted;
        state manualReviewRequired;
        state rejected;

        transition start_to_triggered first triggered;

        transition triggered_to_frameAcquired
            first triggered
            then frameAcquired;

        transition frameAcquired_to_plateCandidateFound
            first frameAcquired
            then plateCandidateFound;

        transition plateCandidateFound_to_textDecoded
            first plateCandidateFound
            then textDecoded;

        transition textDecoded_to_accepted
            first textDecoded
            if overallConfidence >= 0.95
            then accepted;

        transition textDecoded_to_manualReviewRequired
            first textDecoded
            if overallConfidence < 0.95 and overallConfidence >= 0.70
            then manualReviewRequired;

        transition textDecoded_to_rejected
            first textDecoded
            if overallConfidence < 0.70
            then rejected;
    }

    /* Parts */

    part def InductiveLoopSensor {
        port detection : VehicleDetectionPort;
        port power : PowerPort;

        attribute detectionRange : Distance_m = 3.0;
        attribute minimumDetectableSpeed : Speed_km_per_h = 1.0;
        attribute maximumDetectableSpeed : Speed_km_per_h = 220.0;
        attribute nominalPower : Power_W = 8.0;

        doc "Roadside vehicle sensor that detects an approaching vehicle and initiates an ANPR transaction.";
    }

    part def InfraredIlluminator {
        port control : IlluminationControlPort;
        port power : PowerPort;

        attribute wavelength_nm : Real = 850.0;
        attribute maximumIntensity : Percent = 100.0;
        attribute nominalPower : Power_W = 35.0;
        attribute minimumOperatingTemperature : Temperature_C = -30.0;
        attribute maximumOperatingTemperature : Temperature_C = 60.0;

        doc "Controlled illumination source used to increase number-plate contrast during capture.";
    }

    part def ANPRCamera {
        port cameraControl : CameraControlPort;
        port power : PowerPort;

        attribute sensorWidth : PixelCount = 4096;
        attribute sensorHeight : PixelCount = 2160;
        attribute maximumFrameRate : FrameRate_Hz = 120.0;
        attribute lensFocalLength_mm : Real = 25.0;
        attribute fieldOfView_m : Distance_m = 6.0;
        attribute nominalPower : Power_W = 18.0;

        doc "High-resolution camera that captures images of vehicles and their number plates.";
    }

    part def EdgeProcessingUnit {
        port frameProcessor : FrameProcessingPort;
        port opticalRecognizer : OpticalRecognitionPort;
        port publication : ResultPublicationPort;
        port audit : AuditPort;
        port health : HealthMonitoringPort;
        port power : PowerPort;

        attribute cpuUtilizationLimit : Percent = 85.0;
        attribute acceleratorThroughput : FrameRate_Hz = 80.0;
        attribute memoryCapacity_GB : StorageCapacity_GB = 16.0;
        attribute localStorageCapacity_GB : StorageCapacity_GB = 512.0;
        attribute nominalPower : Power_W = 65.0;
        attribute maximumProcessingLatency : Latency_ms = 250.0;

        action highLevelRecognition : HighLevelANPRFunction;
        state lifecycle : ANPROperationalStateMachine;
        state transaction : RecognitionTransactionStateMachine;

        doc "Edge computer that performs plate localization, optical character recognition, validation, audit recording, and result publication.";
    }

    part def PlateLocalizationModule {
        port processing : FrameProcessingPort;

        attribute minimumDetectionConfidence : Probability = 0.90;
        attribute maximumLocalizationLatency : Latency_ms = 35.0;
        attribute supportedMinimumPlateWidth : PixelCount = 80;
        attribute supportedMinimumPlateHeight : PixelCount = 20;

        action locate : LocatePlateRegion;

        doc "Software module that identifies plate regions within captured vehicle images.";
    }

    part def OCRModule {
        port recognition : OpticalRecognitionPort;

        attribute supportedAlphabet : String = "A-Z,0-9";
        attribute minimumOpticalConfidence : Probability = 0.92;
        attribute maximumRecognitionLatency : Latency_ms = 60.0;

        action recognize : RecognizePlateCharacters;

        doc "Software module that reads characters from localized plate images.";
    }

    part def PlateValidationModule {
        attribute minimumOverallConfidence : Probability = 0.95;
        attribute supportedCountryCodes : String = "GB,FR,DE,NL,ES,IT,US";
        attribute maximumValidationLatency : Latency_ms = 20.0;

        action validate : ValidateRecognition;

        doc "Software module that checks OCR output against plate syntax rules and confidence thresholds.";
    }

    part def EvidenceRepository {
        port audit : AuditPort;
        port power : PowerPort;

        attribute storageCapacity : StorageCapacity_GB = 2048.0;
        attribute retentionPeriodDays : Integer = 30;
        attribute encryptionAtRestRequired : Boolean = true;
        attribute nominalPower : Power_W = 20.0;

        action storeEvidence : StoreAuditEvidence;

        doc "Secure local repository for images, recognition metadata, and review audit records.";
    }

    part def NetworkGateway {
        port publication : ResultPublicationPort;
        port health : HealthMonitoringPort;
        port power : PowerPort;

        attribute uplinkDataRate : DataRate_Mbps = 100.0;
        attribute encryptionRequired : Boolean = true;
        attribute maximumTransmissionLatency : Latency_ms = 100.0;
        attribute nominalPower : Power_W = 12.0;

        action publishResult : PublishRecognitionResult;

        doc "Secure network interface for sending ANPR results to authorized external services.";
    }

    part def OperatorConsole {
        port audit : AuditPort;
        port health : HealthMonitoringPort;
        port power : PowerPort;

        attribute displayRefreshRate : FrameRate_Hz = 60.0;
        attribute maximumAlertLatency : Latency_ms = 500.0;
        attribute nominalPower : Power_W = 45.0;

        doc "Human-machine interface for reviewing low-confidence recognitions and system health alerts.";
    }

    part def PowerDistributionUnit {
        port inputPower : PowerPort;
        port sensorPower : PowerPort;
        port illuminationPower : PowerPort;
        port cameraPower : PowerPort;
        port processorPower : PowerPort;
        port repositoryPower : PowerPort;
        port gatewayPower : PowerPort;
        port consolePower : PowerPort;

        attribute inputVoltage : Voltage_V = 24.0;
        attribute availablePower : Power_W = 300.0;
        attribute backupRuntime : Duration_s = 900.0;

        doc "Supplies regulated electrical power to ANPR roadside equipment.";
    }

    part def AutomaticNumberPlateRecognitionSystem {
        doc "A roadside automatic number-plate recognition system whose primary function is to automatically identify a vehicle by capturing its plate image, reading the plate characters, validating the result, and publishing a trusted recognition record.";

        port vehicleDetectionInput : VehicleDetectionPort;
        port recognitionOutput : ResultPublicationPort;
        port operatorInterface : AuditPort;
        port healthInterface : HealthMonitoringPort;
        port powerInput : PowerPort;

        part vehicleSensor : InductiveLoopSensor;
        part illuminator : InfraredIlluminator;
        part camera : ANPRCamera;
        part edgeProcessor : EdgeProcessingUnit;
        part plateLocalizer : PlateLocalizationModule;
        part ocrEngine : OCRModule;
        part validationEngine : PlateValidationModule;
        part evidenceStore : EvidenceRepository;
        part networkGateway : NetworkGateway;
        part operatorConsole : OperatorConsole;
        part pdu : PowerDistributionUnit;

        attribute requiredRecognitionAccuracy : Probability = 0.95;
        attribute requiredDetectionConfidence : Probability = 0.90;
        attribute maximumEndToEndLatency : Latency_ms = 500.0;
        attribute supportedVehicleSpeed : Speed_km_per_h = 180.0;
        attribute minimumSceneIlluminanceWithoutIR : Illuminance_lx = 100.0;
        attribute nominalSystemPower : Power_W = 203.0;
        attribute operationalAvailability : Probability = 0.995;

        action primaryFunction : HighLevelANPRFunction;
        state operatingMode : ANPROperationalStateMachine;

        connect vehicleDetectionInput to vehicleSensor.detection;
        connect vehicleSensor.detection to edgeProcessor.frameProcessor;
        connect vehicleSensor.detection to illuminator.control;
        connect illuminator.control to camera.cameraControl;
        connect camera.cameraControl to edgeProcessor.frameProcessor;
        connect edgeProcessor.frameProcessor to plateLocalizer.processing;
        connect plateLocalizer.processing to ocrEngine.recognition;
        connect ocrEngine.recognition to edgeProcessor.opticalRecognizer;
        connect edgeProcessor.publication to networkGateway.publication;
        connect networkGateway.publication to recognitionOutput;
        connect edgeProcessor.audit to evidenceStore.audit;
        connect evidenceStore.audit to operatorConsole.audit;
        connect operatorConsole.audit to operatorInterface;
        connect edgeProcessor.health to networkGateway.health;
        connect networkGateway.health to healthInterface;

        connect powerInput to pdu.inputPower;
        connect pdu.sensorPower to vehicleSensor.power;
        connect pdu.illuminationPower to illuminator.power;
        connect pdu.cameraPower to camera.power;
        connect pdu.processorPower to edgeProcessor.power;
        connect pdu.repositoryPower to evidenceStore.power;
        connect pdu.gatewayPower to networkGateway.power;
        connect pdu.consolePower to operatorConsole.power;
    }

    /* Requirements */

    requirement def PrimaryFunctionRequirement {
        doc "The ANPR system shall automatically identify a vehicle at a high level by detecting vehicle presence, capturing a plate image, locating the number plate, recognizing its characters, validating confidence, and publishing a recognition result.";
        subject system : AutomaticNumberPlateRecognitionSystem;

        require constraint {
            system.requiredRecognitionAccuracy >= 0.95
        }
    }

    requirement def EndToEndLatencyRequirement {
        doc "The ANPR system shall produce and publish a recognition result within 500 ms of vehicle detection under nominal operating conditions.";
        subject system : AutomaticNumberPlateRecognitionSystem;

        require constraint {
            system.maximumEndToEndLatency <= 500.0
        }
    }

    requirement def PlateDetectionConfidenceRequirement {
        doc "The ANPR system shall localize a plate candidate with at least 0.90 detection confidence before optical recognition is attempted.";
        subject system : AutomaticNumberPlateRecognitionSystem;

        require constraint {
            system.requiredDetectionConfidence >= 0.90
        }
    }

    requirement def RecognitionAccuracyRequirement {
        doc "The ANPR system shall achieve at least 95 percent correct plate recognition for readable plates within the supported speed and illumination envelope.";
        subject system : AutomaticNumberPlateRecognitionSystem;

        require constraint {
            system.requiredRecognitionAccuracy >= 0.95
        }
    }

    requirement def SupportedSpeedRequirement {
        doc "The ANPR system shall support recognition of vehicles traveling up to 180 km/h in the monitored lane.";
        subject system : AutomaticNumberPlateRecognitionSystem;

        require constraint {
            system.supportedVehicleSpeed >= 180.0
        }
    }

    requirement def IlluminationRequirement {
        doc "The ANPR system shall provide controlled infrared illumination when ambient illumination is insufficient for reliable plate imaging.";
        subject system : AutomaticNumberPlateRecognitionSystem;

        require constraint {
            system.minimumSceneIlluminanceWithoutIR <= 100.0
        }
    }

    requirement def AuditRequirement {
        doc "The ANPR system shall store recognition evidence and metadata for audit, including low-confidence cases requiring operator review.";
        subject repository : EvidenceRepository;

        require constraint {
            repository.retentionPeriodDays >= 30
        }
    }

    requirement def SecurityRequirement {
        doc "The ANPR system shall encrypt recognition result transmissions and stored evidence.";
        subject gateway : NetworkGateway;
        subject repository : EvidenceRepository;

        require constraint {
            gateway.encryptionRequired == true and repository.encryptionAtRestRequired == true
        }
    }

    requirement def AvailabilityRequirement {
        doc "The ANPR system shall maintain operational availability of at least 0.995 for roadside recognition service.";
        subject system : AutomaticNumberPlateRecognitionSystem;

        require constraint {
            system.operationalAvailability >= 0.995
        }
    }

    requirement def PowerBudgetRequirement {
        doc "The ANPR system nominal power consumption shall remain below the available power from the distribution unit.";
        subject system : AutomaticNumberPlateRecognitionSystem;
        subject pdu : PowerDistributionUnit;

        require constraint {
            system.nominalSystemPower <= pdu.availablePower
        }
    }

    /* Requirement Satisfaction */

    satisfy PrimaryFunctionRequirement by AutomaticNumberPlateRecognitionSystem::primaryFunction;
    satisfy EndToEndLatencyRequirement by AutomaticNumberPlateRecognitionSystem::edgeProcessor;
    satisfy PlateDetectionConfidenceRequirement by AutomaticNumberPlateRecognitionSystem::plateLocalizer;
    satisfy RecognitionAccuracyRequirement by AutomaticNumberPlateRecognitionSystem::ocrEngine;
    satisfy RecognitionAccuracyRequirement by AutomaticNumberPlateRecognitionSystem::validationEngine;
    satisfy SupportedSpeedRequirement by AutomaticNumberPlateRecognitionSystem::vehicleSensor;
    satisfy IlluminationRequirement by AutomaticNumberPlateRecognitionSystem::illuminator;
    satisfy AuditRequirement by AutomaticNumberPlateRecognitionSystem::evidenceStore;
    satisfy SecurityRequirement by AutomaticNumberPlateRecognitionSystem::networkGateway;
    satisfy SecurityRequirement by AutomaticNumberPlateRecognitionSystem::evidenceStore;
    satisfy AvailabilityRequirement by AutomaticNumberPlateRecognitionSystem::operatingMode;
    satisfy PowerBudgetRequirement by AutomaticNumberPlateRecognitionSystem::pdu;
}
