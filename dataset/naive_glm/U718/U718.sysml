package HyperspectralImagingSystem {
    import ScalarValues::*;

    // ===== Units =====
    unit nm;
    unit mm;
    unit percent;
    unit Mbps;
    unit GB;
    unit deg;
    unit "deg/s";
    unit K;
    unit "W/m^2";
    unit "W/(m^2 sr nm)";
    unit DN;
    unit s;
    unit ms;

    // ===== Value Types =====
    value type Wavelength :> Real { unit nm; }
    value type SpectralRadiance :> Real { unit "W/(m^2 sr nm)"; }
    value type Irradiance :> Real { unit "W/m^2"; }
    value type PixelValue :> Real { unit DN; }
    value type ConfidenceLevel :> Real { unit percent; }
    value type DataRate :> Real { unit Mbps; }
    value type AngularPosition :> Real { unit deg; }
    value type ScanRate :> Real { unit "deg/s"; }
    value type Temperature :> Real { unit K; }
    value type StorageCapacity :> Real { unit GB; }
    value type TimeValue :> Real { unit s; }
    value type FocalLength :> Real { unit mm; }
    value type Aperture :> Real { unit mm; }

    // ===== Item Definitions =====
    item def SceneLight {
        attribute wavelengthMin : Wavelength;
        attribute wavelengthMax : Wavelength;
        attribute radiance : SpectralRadiance;
        attribute incidentAngle : AngularPosition;
    }

    item def FocusedLight {
        attribute wavelengthMin : Wavelength;
        attribute wavelengthMax : Wavelength;
        attribute radiance : SpectralRadiance;
        attribute focalPointPosition : Real;
    }

    item def DispersedSpectrum {
        attribute numBands : Integer;
        attribute wavelengths : Wavelength[0..*];
        attribute radiances : SpectralRadiance[0..*];
        attribute spatialLine : Integer;
    }

    item def RawSpectralCube {
        attribute spatialLines : Integer;
        attribute spatialSamples : Integer;
        attribute spectralBands : Integer;
        attribute pixelData : PixelValue[0..*];
        attribute timestamp : TimeValue;
        attribute gainSetting : Real;
    }

    item def CalibrationCoefficients {
        attribute darkFrame : PixelValue[0..*];
        attribute flatField : Real[0..*];
        attribute wavelengthMap : Wavelength[0..*];
        attribute radiometricGains : Real[0..*];
        attribute atmosphericModelType : String;
        attribute atmosphericCoefficients : Real[0..*];
        attribute calibrationTimestamp : TimeValue;
    }

    item def CorrectedSpectralCube {
        attribute spatialLines : Integer;
        attribute spatialSamples : Integer;
        attribute spectralBands : Integer;
        attribute radianceData : SpectralRadiance[0..*];
        attribute timestamp : TimeValue;
    }

    item def SpectralSignature {
        attribute materialName : String;
        attribute wavelengths : Wavelength[0..*];
        attribute reflectance : Real[0..*];
        attribute similarityScore : Real;
    }

    item def ClassificationMap {
        attribute spatialLines : Integer;
        attribute spatialSamples : Integer;
        attribute materialClasses : String[0..*];
        attribute confidenceValues : ConfidenceLevel[0..*];
        attribute timestamp : TimeValue;
        attribute sceneId : String;
    }

    item def SystemStatus {
        attribute operationalState : String;
        attribute mirrorPosition : AngularPosition;
        attribute detectorTemperature : Temperature;
        attribute storageRemaining : StorageCapacity;
        attribute currentDataRate : DataRate;
        attribute errorCode : Integer;
    }

    item def CommandMessage {
        attribute commandType : String;
        attribute parameters : String[0..*];
        attribute timestamp : TimeValue;
    }

    // ===== Port Definitions =====
    port def SceneLightPort {
        in light : SceneLight;
        out light : SceneLight;
    }

    port def FocusedLightPort {
        in light : FocusedLight;
        out light : FocusedLight;
    }

    port def DispersedSpectrumPort {
        in spectrum : DispersedSpectrum;
        out spectrum : DispersedSpectrum;
    }

    port def RawDataPort {
        in rawCube : RawSpectralCube;
        out rawCube : RawSpectralCube;
    }

    port def CalibrationPort {
        in coefficients : CalibrationCoefficients;
        out coefficients : CalibrationCoefficients;
    }

    port def ClassificationMapPort {
        in classificationMap : ClassificationMap;
        out classificationMap : ClassificationMap;
    }

    port def CommandPort {
        in command : CommandMessage;
        out command : CommandMessage;
    }

    port def StatusPort {
        in status : SystemStatus;
        out status : SystemStatus;
    }

    // ===== Part Definitions =====

    part def ScanMirrorAssembly {
        port sceneLightIn : SceneLightPort;
        port focusedLightOut : FocusedLightPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute currentAngle : AngularPosition = 0 [deg];
        attribute scanRate : ScanRate = 5 ["deg/s"];
        attribute scanRange : AngularPosition = 30 [deg];
        attribute stepAngle : AngularPosition = 0.5 [deg];
        attribute scanActive : Boolean = false;

        part mirror {
            attribute position : AngularPosition = 0 [deg];
            attribute reflectivity : Real = 0.95;
        }

        part actuator {
            attribute maxTorque : Real = 0.5;
            attribute stepResolution : AngularPosition = 0.1 [deg];
        }

        part encoder {
            attribute resolution : AngularPosition = 0.01 [deg];
            attribute currentPosition : AngularPosition = 0 [deg];
        }

        state MirrorControl {
            state Idle;
            state Scanning;
            state Returning;
            state Parked;

            transition Idle to Scanning when commandIn.command.commandType == "startScan";
            transition Scanning to Scanning when mirror.position < scanRange;
            transition Scanning to Returning when mirror.position >= scanRange;
            transition Returning to Parked when mirror.position <= 0 [deg];
            transition Parked to Idle when commandIn.command.commandType == "reset";
            transition Scanning to Parked when commandIn.command.commandType == "stopScan";
        }

        action deflectLight {
            in sceneLight : SceneLight;
            out focusedLight : FocusedLight;

            first receiveSceneLight;
            then adjustMirrorAngle;
            then reflectLight;
            then outputFocusedLight;

            action receiveSceneLight {
                in light : SceneLight;
            }
            action adjustMirrorAngle {
                in angle : AngularPosition;
            }
            action reflectLight {
                in light : SceneLight;
                in angle : AngularPosition;
                out reflected : FocusedLight;
            }
            action outputFocusedLight {
                in light : FocusedLight;
            }
        }
    }

    part def ForeopticAssembly {
        port focusedLightIn : FocusedLightPort;
        port focusedLightOut : FocusedLightPort;

        attribute focalLength : FocalLength = 50 [mm];
        attribute aperture : Aperture = 25 [mm];
        attribute fNumber : Real = 2.0;
        attribute transmissionEfficiency : Real = 0.92;

        part primaryLens {
            attribute diameter : Aperture = 25 [mm];
            attribute material : String = "fused silica";
        }

        part secondaryLens {
            attribute diameter : Aperture = 15 [mm];
            attribute material : String = "fused silica";
        }

        part filterWheel {
            attribute currentPosition : Integer = 0;
            attribute numPositions : Integer = 6;
        }

        action focusLight {
            in incoming : FocusedLight;
            out focused : FocusedLight;

            first collectLight;
            then applyFilter;
            then convergeRays;
            then outputFocused;

            action collectLight {
                in light : FocusedLight;
            }
            action applyFilter {
                in light : FocusedLight;
                out filtered : FocusedLight;
            }
            action convergeRays {
                in light : FocusedLight;
                out converged : FocusedLight;
            }
            action outputFocused {
                in light : FocusedLight;
            }
        }
    }

    part def SpectralDispersionUnit {
        port focusedLightIn : FocusedLightPort;
        port dispersedSpectrumOut : DispersedSpectrumPort;

        attribute wavelengthMin : Wavelength = 400 [nm];
        attribute wavelengthMax : Wavelength = 2500 [nm];
        attribute numBands : Integer = 224;
        attribute bandWidth : Wavelength = 9.4 [nm];
        attribute dispersionEfficiency : Real = 0.85;

        part collimator {
            attribute focalLength : FocalLength = 30 [mm];
        }

        part dispersiveGrating {
            attribute grooveDensity : Real = 300;
            attribute blazeAngle : AngularPosition = 15 [deg];
            attribute order : Integer = 1;
        }

        part focusingMirror {
            attribute focalLength : FocalLength = 45 [mm];
        }

        action disperseLight {
            in focused : FocusedLight;
            out dispersed : DispersedSpectrum;

            first collimateInput;
            then splitByWavelength;
            then focusSpectrum;
            then outputSpectrum;

            action collimateInput {
                in light : FocusedLight;
                out collimated : FocusedLight;
            }
            action splitByWavelength {
                in light : FocusedLight;
                out spectrum : DispersedSpectrum;
            }
            action focusSpectrum {
                in spectrum : DispersedSpectrum;
                out focused : DispersedSpectrum;
            }
            action outputSpectrum {
                in spectrum : DispersedSpectrum;
            }
        }
    }

    part def FocalPlaneArray {
        port dispersedSpectrumIn : DispersedSpectrumPort;
        port rawDataOut : RawDataPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute numPixelsX : Integer = 1024;
        attribute numPixelsY : Integer = 256;
        attribute integrationTime : TimeValue = 0.005 [s];
        attribute operatingTemperature : Temperature = 120 [K];
        attribute quantumEfficiency : Real = 0.85;
        attribute readoutNoise : PixelValue = 20 [DN];
        attribute dynamicRange : Real = 16384;
        attribute captureComplete : Boolean = false;

        part detectorArray {
            attribute rows : Integer = 256;
            attribute columns : Integer = 1024;
            attribute pixelPitch : Real = 0.018;
            attribute material : String = "MCT";
        }

        part readoutCircuit {
            attribute gain : Real = 1.0;
            attribute adcResolution : Integer = 14;
            attribute maxFrameRate : Real = 200;
        }

        part cooler {
            attribute targetTemperature : Temperature = 120 [K];
            attribute coolingCapacity : Real = 1.0;
            attribute currentTemperature : Temperature = 120 [K];
        }

        state DetectorControl {
            state Idle;
            state Integrating;
            state Reading;
            state Cooling;

            transition Idle to Integrating when dispersedSpectrumIn.spectrum != null;
            transition Integrating to Reading when captureComplete == true;
            transition Reading to Idle when rawDataOut.rawCube != null;
            transition Idle to Cooling when cooler.currentTemperature > 130 [K];
            transition Cooling to Idle when cooler.currentTemperature <= 120 [K];
        }

        action captureSpectrum {
            in dispersed : DispersedSpectrum;
            out rawCube : RawSpectralCube;

            first integrateCharge;
            then readPixels;
            then digitize;
            then assembleCube;
            then outputData;

            action integrateCharge {
                in spectrum : DispersedSpectrum;
                out charge : Real[0..*];
            }
            action readPixels {
                in charge : Real[0..*];
                out pixelValues : PixelValue[0..*];
            }
            action digitize {
                in pixelValues : PixelValue[0..*];
                out digitalValues : PixelValue[0..*];
            }
            action assembleCube {
                in digitalValues : PixelValue[0..*];
                out cube : RawSpectralCube;
            }
            action outputData {
                in cube : RawSpectralCube;
            }
        }
    }

    part def CalibrationUnit {
        port calibrationOut : CalibrationPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute lastCalibrationTime : TimeValue = 0 [s];
        attribute calibrationInterval : TimeValue = 3600 [s];
        attribute calibrationMode : String = "auto";
        attribute calibrationComplete : Boolean = false;

        part darkCurrentCalibrator {
            attribute darkFrame : PixelValue[0..*];
            attribute exposureTime : TimeValue = 0.005 [s];
        }

        part flatFieldCalibrator {
            attribute flatField : Real[0..*];
            attribute uniformity : Real = 0.98;
        }

        part wavelengthCalibrator {
            attribute wavelengthMap : Wavelength[0..*];
            attribute referenceLamp : String = "HgAr";
        }

        part radiometricCalibrator {
            attribute gainCoefficients : Real[0..*];
            attribute integratingSphere : String = "1000W";
        }

        part atmosphericModel {
            attribute modelType : String = "MODTRAN";
            attribute coefficients : Real[0..*];
            attribute waterVapor : Real = 2.5;
            attribute visibility : Real = 23.0;
        }

        state CalibrationControl {
            state Idle;
            state MeasuringDark;
            state MeasuringFlat;
            state VerifyingWavelength;
            state ComputingRadiometric;
            state UpdatingAtmospheric;
            state Complete;

            transition Idle to MeasuringDark when commandIn.command.commandType == "calibrate";
            transition MeasuringDark to MeasuringFlat when darkCurrentCalibrator.darkFrame != null;
            transition MeasuringFlat to VerifyingWavelength when flatFieldCalibrator.flatField != null;
            transition VerifyingWavelength to ComputingRadiometric when wavelengthCalibrator.wavelengthMap != null;
            transition ComputingRadiometric to UpdatingAtmospheric when radiometricCalibrator.gainCoefficients != null;
            transition UpdatingAtmospheric to Complete when atmosphericModel.coefficients != null;
            transition Complete to Idle when calibrationComplete == true;
        }

        action generateCalibration {
            out coefficients : CalibrationCoefficients;

            first measureDarkCurrent;
            then measureFlatField;
            then verifyWavelengths;
            then computeRadiometric;
            then updateAtmospheric;
            then assembleCoefficients;
            then outputCoefficients;

            action measureDarkCurrent {
                out dark : PixelValue[0..*];
            }
            action measureFlatField {
                out flat : Real[0..*];
            }
            action verifyWavelengths {
                out wavelengths : Wavelength[0..*];
            }
            action computeRadiometric {
                out gains : Real[0..*];
            }
            action updateAtmospheric {
                out model : String;
                out coeffs : Real[0..*];
            }
            action assembleCoefficients {
                in dark : PixelValue[0..*];
                in flat : Real[0..*];
                in wavelengths : Wavelength[0..*];
                in gains : Real[0..*];
                in model : String;
                in atmCoeffs : Real[0..*];
                out coeffs : CalibrationCoefficients;
            }
            action outputCoefficients {
                in coeffs : CalibrationCoefficients;
            }
        }
    }

    part def SignalProcessingUnit {
        port rawDataIn : RawDataPort;
        port calibrationIn : CalibrationPort;
        port classificationMapOut : ClassificationMapPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute processingRate : DataRate = 200 [Mbps];
        attribute confidenceThreshold : ConfidenceLevel = 85 [percent];
        attribute spectralLibrarySize : Integer = 500;
        attribute classificationMethod : String = "spectral angle mapper";
        attribute noiseFilterType : String = "median";
        attribute preprocessingComplete : Boolean = false;
        attribute correctionComplete : Boolean = false;
        attribute extractionComplete : Boolean = false;
        attribute classificationComplete : Boolean = false;
        attribute currentConfidence : ConfidenceLevel = 0 [percent];

        part preprocessor {
            attribute darkCorrectionApplied : Boolean = false;
            attribute flatFieldApplied : Boolean = false;
        }

        part atmosphericCorrector {
            attribute modelType : String = "MODTRAN";
            attribute correctionApplied : Boolean = false;
        }

        part signatureExtractor {
            attribute algorithm : String = "PCA";
            attribute numComponents : Integer = 10;
        }

        part classifier {
            attribute method : String = "SAM";
            attribute numClasses : Integer = 16;
            attribute libraryPath : String = "spectral_library";
        }

        part confidenceEvaluator {
            attribute threshold : ConfidenceLevel = 85 [percent];
        }

        state ProcessingControl {
            state Waiting;
            state Preprocessing;
            state Correcting;
            state Extracting;
            state Classifying;
            state Evaluating;
            state Storing;
            state Error;

            transition Waiting to Preprocessing when rawDataIn.rawCube != null;
            transition Preprocessing to Correcting when preprocessingComplete == true;
            transition Correcting to Extracting when correctionComplete == true;
            transition Extracting to Classifying when extractionComplete == true;
            transition Classifying to Evaluating when classificationComplete == true;
            transition Evaluating to Storing when currentConfidence >= confidenceThreshold;
            transition Evaluating to Waiting when currentConfidence < confidenceThreshold;
            transition Storing to Waiting when classificationMapOut.classificationMap != null;
            transition Waiting to Error when statusOut.status.errorCode != 0;
            transition Preprocessing to Error when statusOut.status.errorCode != 0;
            transition Correcting to Error when statusOut.status.errorCode != 0;
            transition Extracting to Error when statusOut.status.errorCode != 0;
            transition Classifying to Error when statusOut.status.errorCode != 0;
            transition Evaluating to Error when statusOut.status.errorCode != 0;
            transition Storing to Error when statusOut.status.errorCode != 0;
            transition Error to Waiting when statusOut.status.errorCode == 0;
        }

        action processSpectralCube {
            in rawCube : RawSpectralCube;
            in calibration : CalibrationCoefficients;
            out classificationMap : ClassificationMap;

            first applyDarkCorrection;
            then applyFlatField;
            then applyRadiometric;
            then applyAtmospheric;
            then extractSignatures;
            then classifyMaterials;
            then evaluateConfidence;
            then decideStore;

            action applyDarkCorrection {
                in raw : RawSpectralCube;
                in dark : PixelValue[0..*];
                out corrected : RawSpectralCube;
            }
            action applyFlatField {
                in raw : RawSpectralCube;
                in flat : Real[0..*];
                out corrected : RawSpectralCube;
            }
            action applyRadiometric {
                in raw : RawSpectralCube;
                in gains : Real[0..*];
                in wavelengths : Wavelength[0..*];
                out radianceCube : CorrectedSpectralCube;
            }
            action applyAtmospheric {
                in cube : CorrectedSpectralCube;
                in model : String;
                in coeffs : Real[0..*];
                out corrected : CorrectedSpectralCube;
            }
            action extractSignatures {
                in cube : CorrectedSpectralCube;
                out signatures : SpectralSignature[0..*];
            }
            action classifyMaterials {
                in signatures : SpectralSignature[0..*];
                out map : ClassificationMap;
            }
            action evaluateConfidence {
                in map : ClassificationMap;
                out confidence : ConfidenceLevel;
            }
            action decideStore {
                in map : ClassificationMap;
                in confidence : ConfidenceLevel;

                first checkThreshold;
                then outputMap;

                action checkThreshold {
                    in confidence : ConfidenceLevel;
                }
                action outputMap {
                    in map : ClassificationMap;
                }
            }
        }
    }

    part def DataStorageUnit {
        port classificationMapIn : ClassificationMapPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute totalCapacity : StorageCapacity = 2000 [GB];
        attribute usedCapacity : StorageCapacity = 0 [GB];
        attribute writeSpeed : DataRate = 500 [Mbps];
        attribute fileSystemType : String = "redundant";
        attribute writeComplete : Boolean = false;
        attribute verifySuccess : Boolean = false;

        part solidStateRecorder {
            attribute capacity : StorageCapacity = 2000 [GB];
            attribute health : Real = 1.0;
            attribute writeCycles : Integer = 0;
        }

        part fileManager {
            attribute fileCount : Integer = 0;
            attribute indexSize : Integer = 0;
        }

        part errorCorrection {
            attribute algorithm : String = "Reed-Solomon";
            attribute redundancy : Real = 0.1;
        }

        state StorageControl {
            state Ready;
            state Writing;
            state Verifying;
            state Full;
            state Error;

            transition Ready to Writing when classificationMapIn.classificationMap != null;
            transition Writing to Verifying when writeComplete == true;
            transition Verifying to Ready when verifySuccess == true;
            transition Ready to Full when usedCapacity >= totalCapacity;
            transition Full to Ready when commandIn.command.commandType == "purge";
            transition Ready to Error when statusOut.status.errorCode != 0;
            transition Writing to Error when statusOut.status.errorCode != 0;
            transition Verifying to Error when statusOut.status.errorCode != 0;
            transition Error to Ready when statusOut.status.errorCode == 0;
        }

        action storeData {
            in map : ClassificationMap;

            first verifyCapacity;
            then writeData;
            then applyErrorCorrection;
            then verifyIntegrity;
            then updateIndex;

            action verifyCapacity {
                in map : ClassificationMap;
                out hasSpace : Boolean;
            }
            action writeData {
                in map : ClassificationMap;
                out written : Boolean;
            }
            action applyErrorCorrection {
                in data : ClassificationMap;
                out corrected : ClassificationMap;
            }
            action verifyIntegrity {
                out checksum : Real;
                out valid : Boolean;
            }
            action updateIndex {
                in map : ClassificationMap;
            }
        }
    }

    part def SystemController {
        port scanMirrorCommand : CommandPort;
        port calibrationCommand : CommandPort;
        port processingCommand : CommandPort;
        port storageCommand : CommandPort;
        port scanMirrorStatusIn : StatusPort;
        port focalPlaneStatusIn : StatusPort;
        port processorStatusIn : StatusPort;
        port calibratorStatusIn : StatusPort;
        port storageStatusIn : StatusPort;
        port statusOut : StatusPort;
        port externalCommandIn : CommandPort;

        attribute operatingMode : String = "standby";
        attribute missionPhase : String = "initialization";
        attribute scanProgress : Real = 0.0;
        attribute totalLines : Integer = 0;
        attribute processedLines : Integer = 0;
        attribute initializationComplete : Boolean = false;

        part commandInterpreter {
            attribute commandQueueSize : Integer = 0;
        }

        part statusAggregator {
            attribute lastUpdateTime : TimeValue = 0 [s];
        }

        part missionScheduler {
            attribute currentTask : String = "none";
            attribute taskPriority : Integer = 0;
        }

        state ControllerControl {
            state Initialization;
            state Standby;
            state ActiveScanning;
            state CalibrationMode;
            state DataProcessing;
            state Shutdown;

            transition Initialization to Standby when initializationComplete == true;
            transition Standby to ActiveScanning when missionPhase == "dataCollection";
            transition Standby to CalibrationMode when missionPhase == "calibration";
            transition ActiveScanning to DataProcessing when scanProgress >= 1.0;
            transition DataProcessing to ActiveScanning when processedLines < totalLines;
            transition DataProcessing to Standby when processedLines >= totalLines;
            transition ActiveScanning to Standby when missionPhase == "standby";
            transition CalibrationMode to Standby when missionPhase == "standby";
            transition Standby to Shutdown when missionPhase == "shutdown";
        }

        action coordinateOperation {
            first initialize;
            then enterStandby;
            then monitorStatus;
            then issueCommands;
            then checkCompletion;

            action initialize;
            action enterStandby;
            action monitorStatus;
            action issueCommands;
            action checkCompletion;
        }
    }

    // ===== Top-Level System =====
    part def HyperspectralImager {
        port sceneInput : SceneLightPort;
        port externalCommand : CommandPort;
        port systemStatus : StatusPort;

        part scanMirror : ScanMirrorAssembly;
        part foreoptic : ForeopticAssembly;
        part disperser : SpectralDispersionUnit;
        part focalPlane : FocalPlaneArray;
        part processor : SignalProcessingUnit;
        part calibrator : CalibrationUnit;
        part storage : DataStorageUnit;
        part controller : SystemController;

        // Optical path connections
        connection sceneInput to scanMirror.sceneLightIn;
        connection scanMirror.focusedLightOut to foreoptic.focusedLightIn;
        connection foreoptic.focusedLightOut to disperser.focusedLightIn;
        connection disperser.dispersedSpectrumOut to focalPlane.dispersedSpectrumIn;

        // Data path connections
        connection focalPlane.rawDataOut to processor.rawDataIn;

        // Calibration connection
        connection calibrator.calibrationOut to processor.calibrationIn;

        // Storage connection
        connection processor.classificationMapOut to storage.classificationMapIn;

        // Command connections
        connection externalCommand to controller.externalCommandIn;
        connection controller.scanMirrorCommand to scanMirror.commandIn;
        connection controller.calibrationCommand to calibrator.commandIn;
        connection controller.processingCommand to processor.commandIn;
        connection controller.storageCommand to storage.commandIn;

        // Status connections
        connection scanMirror.statusOut to controller.scanMirrorStatusIn;
        connection focalPlane.statusOut to controller.focalPlaneStatusIn;
        connection processor.statusOut to controller.processorStatusIn;
        connection calibrator.statusOut to controller.calibratorStatusIn;
        connection storage.statusOut to controller.storageStatusIn;
        connection controller.statusOut to systemStatus;
    }

    // ===== Requirements =====
    requirement def SpectralCoverageRequirement {
        subject imager : HyperspectralImager;
        doc /* The system shall cover wavelengths from 400 nm to 2500 nm */
        require imager.disperser.wavelengthMin <= 400 [nm];
        require imager.disperser.wavelengthMax >= 2500 [nm];
    }

    requirement def SpectralResolutionRequirement {
        subject imager : HyperspectralImager;
        doc /* The system shall have spectral resolution of 10 nm or better with at least 200 bands */
        require imager.disperser.bandWidth <= 10 [nm];
        require imager.disperser.numBands >= 200;
    }

    requirement def SpatialResolutionRequirement {
        subject imager : HyperspectralImager;
        doc /* The focal plane array shall have at least 1024 x 256 pixels */
        require imager.focalPlane.numPixelsX >= 1024;
        require imager.focalPlane.numPixelsY >= 256;
    }

    requirement def DataRateRequirement {
        subject imager : HyperspectralImager;
        doc /* The signal processor shall handle at least 200 Mbps */
        require imager.processor.processingRate >= 200 [Mbps];
    }

    requirement def StorageCapacityRequirement {
        subject imager : HyperspectralImager;
        doc /* The storage unit shall have at least 2000 GB capacity */
        require imager.storage.totalCapacity >= 2000 [GB];
    }

    requirement def ConfidenceThresholdRequirement {
        subject imager : HyperspectralImager;
        doc /* Classification confidence threshold shall be at least 85 percent */
        require imager.processor.confidenceThreshold >= 85 [percent];
    }

    requirement def ScanRangeRequirement {
        subject imager : HyperspectralImager;
        doc /* The scan mirror shall cover at least 30 degrees */
        require imager.scanMirror.scanRange >= 30 [deg];
    }

    requirement def DetectorTemperatureRequirement {
        subject imager : HyperspectralImager;
        doc /* The detector shall operate at 150 K or below */
        require imager.focalPlane.operatingTemperature <= 150 [K];
    }

    requirement def CalibrationIntervalRequirement {
        subject imager : HyperspectralImager;
        doc /* Calibration shall be performed at least every 3600 seconds */
        require imager.calibrator.calibrationInterval <= 3600 [s];
    }

    requirement def SystemAutonomyRequirement {
        subject imager : HyperspectralImager;
        doc /* The system shall support autonomous operation mode */
        require imager.controller.missionPhase == "dataCollection" or imager.controller.missionPhase == "calibration";
    }

    requirement def OpticalThroughputRequirement {
        subject imager : HyperspectralImager;
        doc /* The optical path shall maintain throughput efficiency above 70 percent */
        require imager.foreoptic.transmissionEfficiency * imager.disperser.dispersionEfficiency * imager.scanMirror.mirror.reflectivity >= 0.70;
    }

    requirement def DataIntegrityRequirement {
        subject imager : HyperspectralImager;
        doc /* The storage unit shall use error correction */
        require imager.storage.errorCorrection.algorithm == "Reed-Solomon";
    }
}
