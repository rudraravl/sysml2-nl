package RadiologyInstrumentationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RadiationDoseValue :> ISQ::EnergyValue;
    attribute def TubePotentialValue :> ISQ::VoltageValue;
    attribute def TubeCurrentValue :> ISQ::ElectricCurrentValue;
    attribute def ExposureTimeValue :> ISQ::DurationValue;
    attribute def FieldOfViewValue :> ISQ::LengthValue;

    attribute def ImageResolutionSpec {
        attribute matrixWidth : Integer;
        attribute matrixHeight : Integer;
        attribute pixelSize : ISQ::LengthValue;
    }

    item def ExposureParameters {
        attribute tubePotential : TubePotentialValue;
        attribute tubeCurrent : TubeCurrentValue;
        attribute exposureTime : ExposureTimeValue;
        attribute fieldOfView : FieldOfViewValue;
    }

    item def RawProjectionData {
        attribute intensityValues : Real[*] ordered;
        attribute acquisitionTimestamp : String;
    }

    item def ProcessedRadiographicImage {
        attribute imageMatrix : Real[*] ordered;
        attribute resolution : ImageResolutionSpec;
        attribute contrastLevel : Real;
        attribute signalToNoiseRatio : Real;
    }

    item def PatientInformation {
        attribute patientID : String;
        attribute anatomicalRegion : String;
        attribute studyProtocol : String;
    }

    item def DoseReport {
        attribute totalDose : RadiationDoseValue;
        attribute doseAreaProduct : Real;
        attribute exposureIndex : Real;
    }

    port def ControlCommandPort {
        in item exposureCommand : ExposureParameters;
        out item statusFeedback : String;
    }

    port def HighVoltagePort {
        in attribute voltage : TubePotentialValue;
        in attribute current : TubeCurrentValue;
    }

    port def RadiationOutputPort {
        out attribute radiationIntensity : ISQ::PowerValue;
        out attribute beamQuality : Real;
    }

    port def DetectorInputPort {
        in attribute incidentRadiation : ISQ::PowerValue;
    }

    port def ImageDataPort {
        out item imageData : ProcessedRadiographicImage;
    }

    port def NetworkPort {
        out item transmittedImage : ProcessedRadiographicImage;
        in item retrievedStudy : String;
    }

    part def HighVoltageGenerator {
        attribute maxVoltage : TubePotentialValue;
        attribute maxCurrent : TubeCurrentValue;
        attribute powerRating : ISQ::PowerValue;

        port hvOutput : HighVoltagePort;
        port controlIn : ControlCommandPort;

        action generateHighVoltage {
            in requestedVoltage : TubePotentialValue;
            in requestedCurrent : TubeCurrentValue;
            out actualVoltage : TubePotentialValue;
            out actualCurrent : TubeCurrentValue;
        }
    }

    part def XRayTube {
        attribute anodeMaterial : String;
        attribute focalSpotSize : ISQ::LengthValue;
        attribute heatCapacity : ISQ::EnergyValue;
        attribute currentHeatLoad : ISQ::EnergyValue;

        port hvInput : HighVoltagePort;
        port radiationOut : RadiationOutputPort;

        action produceXRays {
            in voltage : TubePotentialValue;
            in current : TubeCurrentValue;
            in duration : ExposureTimeValue;
            out radiationOutput : ISQ::PowerValue;
            out heatGenerated : ISQ::EnergyValue;
        }
    }

    part def BeamCollimator {
        attribute bladePositionX1 : ISQ::LengthValue;
        attribute bladePositionX2 : ISQ::LengthValue;
        attribute bladePositionY1 : ISQ::LengthValue;
        attribute bladePositionY2 : ISQ::LengthValue;

        port radiationIn : RadiationOutputPort;
        port radiationOut : RadiationOutputPort;

        action collimateBeam {
            in incomingBeam : ISQ::PowerValue;
            in targetFieldSize : FieldOfViewValue;
            out collimatedBeam : ISQ::PowerValue;
            out beamGeometry : String;
        }
    }

    part def DigitalDetector {
        attribute detectorType : String;
        attribute activeArea : ISQ::AreaValue;
        attribute pixelPitch : ISQ::LengthValue;
        attribute quantumEfficiency : Real;

        port radiationIn : DetectorInputPort;
        port dataOut : ImageDataPort;

        action captureProjection {
            in incidentRadiation : ISQ::PowerValue;
            in integrationTime : ExposureTimeValue;
            out rawData : RawProjectionData;
        }

        action readoutData {
            in rawData : RawProjectionData;
            out digitalSignal : RawProjectionData;
        }
    }

    part def ImageProcessingUnit {
        attribute processingAlgorithm : String;
        attribute calibrationData : Real[*];

        port rawDataIn : ImageDataPort;
        port processedDataOut : ImageDataPort;

        action correctImage {
            in rawImage : RawProjectionData;
            out correctedImage : RawProjectionData;
        }

        action enhanceImage {
            in correctedImage : RawProjectionData;
            out enhancedImage : ProcessedRadiographicImage;
        }

        action applyFilters {
            in inputImage : ProcessedRadiographicImage;
            out filteredImage : ProcessedRadiographicImage;
        }
    }

    part def DoseManagementSystem {
        attribute doseLimit : RadiationDoseValue;
        attribute cumulativeDose : RadiationDoseValue;

        action calculateDose {
            in exposureParams : ExposureParameters;
            in patientData : PatientInformation;
            out estimatedDose : RadiationDoseValue;
        }

        action monitorDose {
            in currentDose : RadiationDoseValue;
            out withinLimits : Boolean;
            out doseAlert : String;
        }

        action generateDoseReport {
            in totalExposure : RadiationDoseValue;
            out report : DoseReport;
        }
    }

    part def OperatorWorkstation {
        attribute operatorID : String;
        attribute workstationID : String;

        port systemControl : ControlCommandPort;
        port imageDisplay : ImageDataPort;
        port networkInterface : NetworkPort;

        action selectProtocol {
            in patientInfo : PatientInformation;
            out protocol : ExposureParameters;
        }

        action initiateExposure {
            in protocol : ExposureParameters;
            out exposureCommand : ExposureParameters;
        }

        action reviewImage {
            in displayedImage : ProcessedRadiographicImage;
            out imageAccepted : Boolean;
        }
    }

    part def PatientPositioningTable {
        attribute tableHeight : ISQ::LengthValue;
        attribute longitudinalPosition : ISQ::LengthValue;
        attribute lateralPosition : ISQ::LengthValue;
        attribute angulation : Real;

        port positionControl : ControlCommandPort;

        action positionPatient {
            in targetPosition : ISQ::LengthValue;
            in targetHeight : ISQ::LengthValue;
            out positionAchieved : Boolean;
        }

        action alignToBeam {
            in anatomicalTarget : String;
            out alignmentComplete : Boolean;
        }
    }

    part def CoolingSystem {
        attribute coolantType : String;
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute coolantTemperature : ISQ::ThermodynamicTemperatureValue;

        action coolTube {
            in heatLoad : ISQ::EnergyValue;
            out coolingRate : ISQ::PowerValue;
        }

        action maintainTemperature {
            in targetTemp : ISQ::ThermodynamicTemperatureValue;
            out temperatureStable : Boolean;
        }
    }

    state def RadiographicSystemState {
        entry; then standby;

        state standby;
        
        transition standby_to_preparation
            first standby
            accept at prepareForExposure
            then preparation;

        state preparation;
        
        transition preparation_to_ready
            first preparation
            accept when systemConfigured
            then ready;

        state ready;
        
        transition ready_to_exposing
            first ready
            accept at triggerExposure
            then exposing;

        state exposing;
        
        transition exposing_to_acquiring
            first exposing
            accept when exposureComplete
            then acquiring;

        state acquiring;
        
        transition acquiring_to_processing
            first acquiring
            accept when dataTransferred
            then processing;

        state processing;
        
        transition processing_to_review
            first processing
            accept when processingComplete
            then review;

        state review;
        
        transition review_to_archiving
            first review
            accept when imageAccepted
            then archiving;
            
        transition review_to_preparation
            first review
            accept when imageRejected
            then preparation;

        state archiving;
        
        transition archiving_to_standby
            first archiving
            accept when archivingComplete
            then standby;

        transition exposing_to_emergency
            first exposing
            accept when doseLimitExceeded
            then emergency;

        state emergency;
        
        transition emergency_to_standby
            first emergency
            accept at acknowledgeEmergency
            then standby;
    }

    action def PerformRadiographicExamination {
        in patientData : PatientInformation;
        in examProtocol : ExposureParameters;
        out diagnosticImage : ProcessedRadiographicImage;
        out doseRecord : DoseReport;
        out examinationComplete : Boolean;

        first start;
        then action registerPatient {
            in patient : PatientInformation = patientData;
            out registrationConfirmed : Boolean;
        }
        then action positionPatientOnTable {
            in anatomicalTarget : String = patientData.anatomicalRegion;
            out positioningComplete : Boolean;
        }
        then action configureExposureSettings {
            in protocol : ExposureParameters = examProtocol;
            out settingsConfigured : Boolean;
        }
        then action estimateRadiationDose {
            in exposureSettings : ExposureParameters = examProtocol;
            in patient : PatientInformation = patientData;
            out estimatedDose : RadiationDoseValue;
        }
        then decide;
            if estimateRadiationDose.estimatedDose == estimateRadiationDose.estimatedDose then proceedWithExposure;

        merge exposurePreparation;
        action proceedWithExposure;
        then exposurePreparation;
        
        then action executeExposure {
            in settings : ExposureParameters = examProtocol;
            out exposureSuccessful : Boolean;
        }
        then action acquireImageData {
            out rawImageData : RawProjectionData;
        }
        then action processImageData {
            in rawData : RawProjectionData = acquireImageData.rawImageData;
            out processedImage : ProcessedRadiographicImage;
        }
        then action evaluateImageQuality {
            in image : ProcessedRadiographicImage = processImageData.processedImage;
            out qualityAcceptable : Boolean;
        }
        then decide;
            if evaluateImageQuality.qualityAcceptable then finalizeExam;

        action finalizeExam {
            in finalImage : ProcessedRadiographicImage = processImageData.processedImage;
        }
        then action recordDoseInformation {
            in deliveredDose : RadiationDoseValue = estimateRadiationDose.estimatedDose;
            out doseReport : DoseReport;
        }
        then action archiveStudy {
            in image : ProcessedRadiographicImage = processImageData.processedImage;
            in dose : DoseReport = recordDoseInformation.doseReport;
            out archiveComplete : Boolean;
        }
        then assign diagnosticImage := processImageData.processedImage;
        then assign doseRecord := recordDoseInformation.doseReport;
        then assign examinationComplete := true;
        then done;
    }

    part def DigitalRadiographySystem {
        doc /*
         * The Digital Radiography System is a medical imaging instrument that produces
         * diagnostic radiographic images of patient anatomy using ionizing radiation.
         * 
         * Primary Function:
         * The system's primary function is to acquire high-quality diagnostic images by
         * generating controlled X-ray radiation, directing it through the patient's body
         * to a digital detector, capturing the transmitted radiation pattern, processing
         * the raw detector data into clinically interpretable images, and managing radiation
         * dose to ensure patient safety while maintaining diagnostic image quality.
         */

        part hvGenerator : HighVoltageGenerator;

        part xRayTube : XRayTube {
            attribute :>> anodeMaterial = "Tungsten-Rhenium";
            perform action radiographicExam[*] ordered references PerformRadiographicExamination;
        }

        part collimator : BeamCollimator;

        part detector : DigitalDetector {
            attribute :>> detectorType = "Cesium Iodide Flat Panel";
            attribute :>> quantumEfficiency = 0.68;
        }

        part imageProcessor : ImageProcessingUnit {
            attribute :>> processingAlgorithm = "Multi-Scale Enhancement";
        }

        part doseManager : DoseManagementSystem;

        part workstation : OperatorWorkstation {
            attribute :>> operatorID = "RAD-OPS-001";
            attribute :>> workstationID = "WS-DR-01";
        }

        part positioningTable : PatientPositioningTable;

        part coolingSystem : CoolingSystem {
            attribute :>> coolantType = "Deionized Water-Glycol";
        }

        connection hvToTube connect hvGenerator.hvOutput to xRayTube.hvInput;
        connection tubeToCollimator connect xRayTube.radiationOut to collimator.radiationIn;
        connection collimatorToDetector connect collimator.radiationOut to detector.radiationIn;
        connection detectorToProcessor connect detector.dataOut to imageProcessor.rawDataIn;
        connection processorToWorkstation connect imageProcessor.processedDataOut to workstation.imageDisplay;
        connection workstationToGenerator connect workstation.systemControl to hvGenerator.controlIn;
        connection workstationToTable connect workstation.systemControl to positioningTable.positionControl;

        perform xRayTube.radiographicExam;
    }

    part radiologySystem : DigitalRadiographySystem;

    requirement def ImageQualityRequirement {
        doc /* The system shall produce images with sufficient spatial resolution and contrast for diagnostic interpretation */
        
        subject detector : DigitalDetector;
        
        require constraint {
            detector.quantumEfficiency >= 0.6
        }
    }

    requirement def DoseSafetyRequirement {
        doc /* The system shall limit radiation dose to patients according to ALARA principles */
        
        subject doseManager : DoseManagementSystem;
    }

    requirement def SystemPerformanceRequirement {
        doc /* The system shall complete image acquisition and processing within clinically acceptable timeframes */
        
        subject system : DigitalRadiographySystem;
    }

    requirement systemRequirements {
        doc /* Top-level requirements for digital radiography system */
        
        requirement imageQuality : ImageQualityRequirement;
        requirement doseSafety : DoseSafetyRequirement;
        requirement performance : SystemPerformanceRequirement;
    }
}
