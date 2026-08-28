package VisualSensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Time::*;
    import ISQ::ElectricPotential::*;
    import ISQ::Power::*;
    import ISQ::Area::*;
    import ISQ::Frequency::*;

    attribute def Illuminance :> Real {
        unit lux;
    }

    attribute def LatencyDuration :> Real {
        unit ms;
    }

    attribute def PixelCount :> Integer;
    attribute def SensorId :> Integer;
    attribute def QualityScore :> Real {
        doc /* 0.0 to 1.0 */;
    }

    item def RawImageData {
        attribute sensorId : SensorId;
        attribute pixelWidth : PixelCount;
        attribute pixelHeight : PixelCount;
        attribute captureTimestamp : TimeValue;
    }

    item def ProcessedImageData {
        attribute sensorId : SensorId;
        attribute enhancedImageData : RawImageData;
        attribute extractedFeatures : String;
        attribute localIlluminance : Illuminance;
        attribute coverageArea : AreaValue;
        attribute processingTimestamp : TimeValue;
    }

    item def FusedEnvironmentalModel {
        attribute aggregatedIlluminance : Illuminance;
        attribute totalCoverageArea : AreaValue;
        attribute fusedQualityScore : QualityScore;
        attribute activeSensorCount : Integer;
        attribute fusionTimestamp : TimeValue;
    }

    item def MeasurementReport {
        attribute model : FusedEnvironmentalModel;
        attribute reportTimestamp : TimeValue;
        attribute operatingMode : String;
        attribute systemHealthStatus : String;
    }

    enum def OperatingMode {
        normal;
        highPrecision;
        lowPower;
    }

    enum def SystemHealth {
        fullyOperational;
        degraded;
        critical;
    }

    port def RawImageOut {
        out rawImage : RawImageData;
    }

    port def RawImageIn {
        in rawImage : RawImageData;
    }

    port def ProcessedImageOut {
        out processedData : ProcessedImageData;
    }

    port def ProcessedImageIn {
        in processedData : ProcessedImageData;
    }

    port def FusedModelOut {
        out fusedModel : FusedEnvironmentalModel;
    }

    port def FusedModelIn {
        in fusedModel : FusedEnvironmentalModel;
    }

    port def ReportOut {
        out report : MeasurementReport;
    }

    port def SynchronizationSignal {
        out trigger : TimeValue;
        out mode : OperatingMode;
    }

    port def SynchronizationReceive {
        in trigger : TimeValue;
        in mode : OperatingMode;
    }

    port def ControlCommand {
        in command : String;
        in targetMode : OperatingMode;
    }

    port def ControlDispatch {
        out command : String;
        out targetMode : OperatingMode;
    }

    part def OpticalAssembly {
        attribute focalLength : Real { unit mm; }
        attribute aperture : Real { unit mm; }
        attribute filterType : String;
        port def OpticalOut {
            out focusedLight : RawImageData;
        }
        port opticalOut : OpticalOut;
    }

    part def ImageSensorArray {
        attribute resolutionWidth : PixelCount;
        attribute resolutionHeight : PixelCount;
        attribute quantumEfficiency : Real;
        port def ImageOut {
            out capturedImage : RawImageData;
        }
        port imageOut : ImageOut;
    }

    part def LocalSignalProcessor {
        attribute clockFrequency : Real { unit Hz; }
        port def LocalProcIn {
            in inputImage : RawImageData;
        }
        port def LocalProcOut {
            out outputImage : RawImageData;
        }
        port localProcIn : LocalProcIn;
        port localProcOut : LocalProcOut;
    }

    part def VisualSensor {
        attribute sensorId : SensorId;
        attribute fieldOfView : Real { unit deg; }
        attribute isOperational : Boolean;
        port syncIn : SynchronizationReceive;
        port rawImageOut : RawImageOut;
        port processedOut : ProcessedImageOut;
        part opticalAssembly : OpticalAssembly {
            attribute focalLength = 35.0;
            attribute aperture = 8.0;
            attribute filterType = "IR-cut";
        }
        part imageSensorArray : ImageSensorArray {
            attribute resolutionWidth = 1920;
            attribute resolutionHeight = 1080;
            attribute quantumEfficiency = 0.85;
        }
        part localSignalProcessor : LocalSignalProcessor {
            attribute clockFrequency = 240e6;
        }
        connection opticalToSensor connect opticalAssembly.opticalOut to imageSensorArray.imageOut;
        connection sensorToProc connect imageSensorArray.imageOut to localSignalProcessor.localProcIn;
        action def captureAndProcess {
            in trigger : TimeValue;
            in mode : OperatingMode;
            out processed : ProcessedImageData;
            action captureRaw {
                out raw : RawImageData;
            }
            action enhanceImage {
                in raw : RawImageData;
                out enhanced : RawImageData;
            }
            action extractFeatures {
                in enhanced : RawImageData;
                out features : String;
                out localIllum : Illuminance;
                out coverage : AreaValue;
            }
            action assembleOutput {
                in enhanced : RawImageData;
                in features : String;
                in localIllum : Illuminance;
                in coverage : AreaValue;
                out processed : ProcessedImageData;
            }
            flow captureRaw.raw to enhanceImage.raw;
            flow enhanceImage.enhanced to extractFeatures.enhanced;
            flow enhanceImage.enhanced to assembleOutput.enhanced;
            flow extractFeatures.features to assembleOutput.features;
            flow extractFeatures.localIllum to assembleOutput.localIllum;
            flow extractFeatures.coverage to assembleOutput.coverage;
            flow assembleOutput.processed to processed;
        }
        state def SensorBehavior {
            entry action { send syncIn.trigger to self; }
            state idle;
            state capturing;
            state processing;
            state transmitting;
            transition idle to capturing when syncIn.trigger is received;
            transition capturing to processing when captureRaw is done;
            transition processing to transmitting when extractFeatures is done;
            transition transmitting to idle when processedOut.processedData is sent;
        }
    }

    part def DataProcessor {
        attribute processorId : SensorId;
        attribute enhancementAlgorithm : String;
        port rawImageIn : RawImageIn;
        port processedOut : ProcessedImageOut;
        action def enhanceAndExtract {
            in raw : RawImageData;
            out processed : ProcessedImageData;
            action denoise {
                in raw : RawImageData;
                out denoised : RawImageData;
            }
            action enhance {
                in denoised : RawImageData;
                out enhanced : RawImageData;
            }
            action featureExtraction {
                in enhanced : RawImageData;
                out features : String;
                out localIllum : Illuminance;
                out coverage : AreaValue;
            }
            action packageData {
                in enhanced : RawImageData;
                in features : String;
                in localIllum : Illuminance;
                in coverage : AreaValue;
                out processed : ProcessedImageData;
            }
            flow denoise.denoised to enhance.denoised;
            flow enhance.enhanced to featureExtraction.enhanced;
            flow enhance.enhanced to packageData.enhanced;
            flow featureExtraction.features to packageData.features;
            flow featureExtraction.localIllum to packageData.localIllum;
            flow featureExtraction.coverage to packageData.coverage;
            flow packageData.processed to processed;
        }
    }

    part def DataFusionUnit {
        attribute fusionAlgorithm : String;
        attribute maxLatency : LatencyDuration = 50.0;
        port processedIn1 : ProcessedImageIn;
        port processedIn2 : ProcessedImageIn;
        port processedIn3 : ProcessedImageIn;
        port processedIn4 : ProcessedImageIn;
        port fusedOut : FusedModelOut;
        action def fuseData {
            in data1 : ProcessedImageData;
            in data2 : ProcessedImageData;
            in data3 : ProcessedImageData;
            in data4 : ProcessedImageData;
            out fused : FusedEnvironmentalModel;
            action aggregateIlluminance {
                in d1 : ProcessedImageData;
                in d2 : ProcessedImageData;
                in d3 : ProcessedImageData;
                in d4 : ProcessedImageData;
                out totalIllum : Illuminance;
            }
            action computeCoverage {
                in d1 : ProcessedImageData;
                in d2 : ProcessedImageData;
                in d3 : ProcessedImageData;
                in d4 : ProcessedImageData;
                out totalArea : AreaValue;
            }
            action assessQuality {
                in d1 : ProcessedImageData;
                in d2 : ProcessedImageData;
                in d3 : ProcessedImageData;
                in d4 : ProcessedImageData;
                out quality : QualityScore;
                out activeCount : Integer;
            }
            action assembleModel {
                in totalIllum : Illuminance;
                in totalArea : AreaValue;
                in quality : QualityScore;
                in activeCount : Integer;
                out fused : FusedEnvironmentalModel;
            }
            flow aggregateIlluminance.totalIllum to assembleModel.totalIllum;
            flow computeCoverage.totalArea to assembleModel.totalArea;
            flow assessQuality.quality to assembleModel.quality;
            flow assessQuality.activeCount to assembleModel.activeCount;
            flow assembleModel.fused to fused;
        }
    }

    part def ReportGenerator {
        attribute reportFormat : String;
        port fusedIn : FusedModelIn;
        port reportOut : ReportOut;
        action def generateReport {
            in fused : FusedEnvironmentalModel;
            in mode : OperatingMode;
            in health : SystemHealth;
            out report : MeasurementReport;
            action compileSummary {
                in fused : FusedEnvironmentalModel;
                out summary : FusedEnvironmentalModel;
            }
            action annotateMetadata {
                in summary : FusedEnvironmentalModel;
                in mode : OperatingMode;
                in health : SystemHealth;
                out report : MeasurementReport;
            }
            flow compileSummary.summary to annotateMetadata.summary;
            flow annotateMetadata.report to report;
        }
    }

    part def NetworkController {
        attribute currentMode : OperatingMode = normal;
        attribute healthStatus : SystemHealth = fullyOperational;
        attribute syncInterval : Real { unit ms; } = 33.0;
        port controlIn : ControlCommand;
        port syncOut1 : SynchronizationSignal;
        port syncOut2 : SynchronizationSignal;
        port syncOut3 : SynchronizationSignal;
        port syncOut4 : SynchronizationSignal;
        port fusedMonitor : FusedModelIn;
        action def orchestrate {
            in command : String;
            in targetMode : OperatingMode;
            out trigger1 : TimeValue;
            out trigger2 : TimeValue;
            out trigger3 : TimeValue;
            out trigger4 : TimeValue;
            out dispatchedMode : OperatingMode;
            action evaluateCommand {
                in command : String;
                in targetMode : OperatingMode;
                out selectedMode : OperatingMode;
            }
            action generateTriggers {
                in selectedMode : OperatingMode;
                out t1 : TimeValue;
                out t2 : TimeValue;
                out t3 : TimeValue;
                out t4 : TimeValue;
                out mode : OperatingMode;
            }
            flow evaluateCommand.selectedMode to generateTriggers.selectedMode;
            flow generateTriggers.t1 to trigger1;
            flow generateTriggers.t2 to trigger2;
            flow generateTriggers.t3 to trigger3;
            flow generateTriggers.t4 to trigger4;
            flow generateTriggers.mode to dispatchedMode;
        }
        state def ControllerBehavior {
            state standby;
            state normalOperation;
            state highPrecisionOperation;
            state lowPowerOperation;
            state faultRecovery;
            transition standby to normalOperation when controlIn.command is received;
            transition normalOperation to highPrecisionOperation when controlIn.targetMode == highPrecision;
            transition normalOperation to lowPowerOperation when controlIn.targetMode == lowPower;
            transition highPrecisionOperation to normalOperation when controlIn.targetMode == normal;
            transition lowPowerOperation to normalOperation when controlIn.targetMode == normal;
            transition normalOperation to faultRecovery when fusedMonitor.fusedModel.activeSensorCount < 4;
            transition highPrecisionOperation to faultRecovery when fusedMonitor.fusedModel.activeSensorCount < 4;
            transition lowPowerOperation to faultRecovery when fusedMonitor.fusedModel.activeSensorCount < 4;
            transition faultRecovery to normalOperation when fusedMonitor.fusedModel.activeSensorCount >= 3;
        }
    }

    part def VisualSensingSystem {
        attribute systemId : String = "VSU-001";
        attribute maxEndToEndLatency : LatencyDuration = 100.0;
        attribute minOperationalSensors : Integer = 3;
        port externalControl : ControlCommand;
        port reportOutput : ReportOut;
        part networkController : NetworkController;
        part sensor1 : VisualSensor {
            attribute sensorId = 1;
            attribute fieldOfView = 90.0;
            attribute isOperational = true;
        }
        part sensor2 : VisualSensor {
            attribute sensorId = 2;
            attribute fieldOfView = 90.0;
            attribute isOperational = true;
        }
        part sensor3 : VisualSensor {
            attribute sensorId = 3;
            attribute fieldOfView = 90.0;
            attribute isOperational = true;
        }
        part sensor4 : VisualSensor {
            attribute sensorId = 4;
            attribute fieldOfView = 90.0;
            attribute isOperational = true;
        }
        part processor1 : DataProcessor {
            attribute processorId = 1;
            attribute enhancementAlgorithm = "adaptiveHDR";
        }
        part processor2 : DataProcessor {
            attribute processorId = 2;
            attribute enhancementAlgorithm = "adaptiveHDR";
        }
        part processor3 : DataProcessor {
            attribute processorId = 3;
            attribute enhancementAlgorithm = "adaptiveHDR";
        }
        part processor4 : DataProcessor {
            attribute processorId = 4;
            attribute enhancementAlgorithm = "adaptiveHDR";
        }
        part fusionUnit : DataFusionUnit {
            attribute fusionAlgorithm = "weightedBayesian";
        }
        part reportGenerator : ReportGenerator {
            attribute reportFormat = "JSON";
        }
        connection controllerToSensor1Sync connect networkController.syncOut1 to sensor1.syncIn;
        connection controllerToSensor2Sync connect networkController.syncOut2 to sensor2.syncIn;
        connection controllerToSensor3Sync connect networkController.syncOut3 to sensor3.syncIn;
        connection controllerToSensor4Sync connect networkController.syncOut4 to sensor4.syncIn;
        connection sensor1ToProcessor1 connect sensor1.rawImageOut to processor1.rawImageIn;
        connection sensor2ToProcessor2 connect sensor2.rawImageOut to processor2.rawImageIn;
        connection sensor3ToProcessor3 connect sensor3.rawImageOut to processor3.rawImageIn;
        connection sensor4ToProcessor4 connect sensor4.rawImageOut to processor4.rawImageIn;
        connection processor1ToFusion connect processor1.processedOut to fusionUnit.processedIn1;
        connection processor2ToFusion connect processor2.processedOut to fusionUnit.processedIn2;
        connection processor3ToFusion connect processor3.processedOut to fusionUnit.processedIn3;
        connection processor4ToFusion connect processor4.processedOut to fusionUnit.processedIn4;
        connection fusionToReport connect fusionUnit.fusedOut to reportGenerator.fusedIn;
        connection fusionToController connect fusionUnit.fusedOut to networkController.fusedMonitor;
        connection reportToOutput connect reportGenerator.reportOut to reportOutput;
        connection externalControlToController connect externalControl to networkController.controlIn;
        action def fullPipeline {
            in command : String;
            in targetMode : OperatingMode;
            out finalReport : MeasurementReport;
            action synchronize {
                in command : String;
                in targetMode : OperatingMode;
                out triggers : TimeValue[4];
                out mode : OperatingMode;
            }
            action captureAll {
                in triggers : TimeValue[4];
                out rawImages : RawImageData[4];
            }
            action processAll {
                in rawImages : RawImageData[4];
                out processedSet : ProcessedImageData[4];
            }
            action fuseAll {
                in processedSet : ProcessedImageData[4];
                out fused : FusedEnvironmentalModel;
            }
            action report {
                in fused : FusedEnvironmentalModel;
                out finalReport : MeasurementReport;
            }
            flow synchronize.triggers to captureAll.triggers;
            flow synchronize.mode to report.mode;
            flow captureAll.rawImages to processAll.rawImages;
            flow processAll.processedSet to fuseAll.processedSet;
            flow fuseAll.fused to report.fused;
            flow report.finalReport to finalReport;
        }
        state def SystemOperationMode {
            state initializing;
            state normalMode;
            state highPrecisionMode;
            state lowPowerMode;
            state degradedMode;
            state shutdown;
            transition initializing to normalMode when networkController.healthStatus == fullyOperational;
            transition normalMode to highPrecisionMode when externalControl.targetMode == highPrecision;
            transition normalMode to lowPowerMode when externalControl.targetMode == lowPower;
            transition highPrecisionMode to normalMode when externalControl.targetMode == normal;
            transition lowPowerMode to normalMode when externalControl.targetMode == normal;
            transition normalMode to degradedMode when fusionUnit.fusedOut.fusedModel.activeSensorCount < 4;
            transition highPrecisionMode to degradedMode when fusionUnit.fusedOut.fusedModel.activeSensorCount < 4;
            transition lowPowerMode to degradedMode when fusionUnit.fusedOut.fusedModel.activeSensorCount < 4;
            transition degradedMode to normalMode when fusionUnit.fusedOut.fusedModel.activeSensorCount >= 4;
            transition degradedMode to shutdown when fusionUnit.fusedOut.fusedModel.activeSensorCount < 3;
        }
    }

    requirement def EnvironmentalMonitoringRequirement {
        subject : VisualSensingSystem;
        attribute requiredCoverageArea : AreaValue = 1000.0 [m^2];
        attribute requiredLatency : LatencyDuration = 100.0;
        attribute requiredSensorCount : Integer = 4;
        attribute minOperationalSensors : Integer = 3;
        requirement measureIlluminance {
            subject :> subject;
            doc /* The system shall measure illuminance across the defined monitoring area. */
        }
        requirement measureSpatialCharacteristics {
            subject :> subject;
            doc /* The system shall determine spatial characteristics including total coverage area. */
        }
        requirement operateInRealTime {
            subject :> subject;
            doc /* End-to-end latency from capture to report shall not exceed requiredLatency. */
            constraint { subject.maxEndToEndLatency <= requiredLatency }
        }
        requirement faultTolerance {
            subject :> subject;
            doc /* The system shall continue operation with at least minOperationalSensors active. */
            constraint { subject.minOperationalSensors >= 3 }
        }
        requirement multiModeOperation {
            subject :> subject;
            doc /* The system shall support normal, high-precision, and low-power modes. */
        }
        requirement coordinatedSensorNetwork {
            subject :> subject;
            doc /* Four identical visual sensors shall operate in parallel under central synchronization. */
            constraint { subject.sensor1.isOperational and subject.sensor2.isOperational and subject.sensor3.isOperational and subject.sensor4.isOperational }
        }
    }

    requirement environmentalMonitoring : EnvironmentalMonitoringRequirement {
        subject : VisualSensingSystem;
    }
}
