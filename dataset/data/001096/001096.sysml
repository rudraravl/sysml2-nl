package ImageSensingUnitSpecification {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::DateTime;
    private import Measurement::*;
    
    attribute def PixelCountUnit :> MeasurementUnit;
    
    attribute def PixelCountValue {
        attribute num : Real;
        attribute mRef : PixelCountUnit;
    }
    
    attribute def IlluminanceUnit :> MeasurementUnit;
    
    attribute def IlluminanceValue {
        attribute num : Real;
        attribute mRef : IlluminanceUnit;
    }
    
    attribute def ExposureDurationValue {
        attribute num : Real;
        attribute mRef : TimeUnit;
    }
    
    attribute def ImageSensorFormat {
        attribute horizontalResolution : PixelCountValue;
        attribute verticalResolution : PixelCountValue;
        attribute bitDepth : Integer;
        attribute colorSpace : String;
        attribute frameRate : Real;
    }
    
    item def OpticalScene {
        attribute sceneIlluminance : IlluminanceValue;
        attribute sceneContrast : Real;
    }
    
    item def FocusedOpticalImage {
        attribute imageIlluminance : IlluminanceValue;
        attribute imageQuality : Real;
    }
    
    item def AnalogSignal {
        attribute signalLevel : Real;
        attribute noiseLevel : Real;
    }
    
    item def RawImageFrame {
        attribute pixelData : Integer[*];
        attribute captureTimestamp : DateTime;
        attribute exposureDuration : ExposureDurationValue;
        attribute sensorFormat : ImageSensorFormat;
        attribute measuredIlluminance : IlluminanceValue;
    }
    
    item def ProcessedImageFrame {
        attribute imageData : RawImageFrame;
        attribute brightnessCorrection : Real;
        attribute contrastEnhancement : Real;
        attribute signalToNoiseRatio : Real;
    }
    
    item def SensorControlCommand {
        attribute commandType : String;
        attribute exposureValue : ExposureDurationValue[0..1];
        attribute gainValue : Real[0..1];
    }
    
    item def SensorStatusData {
        attribute operationalState : String;
        attribute sensorTemperature : TemperatureValue;
        attribute lastFrameTimestamp : DateTime[0..1];
        attribute errorFlags : Integer;
    }
    
    port def ControlPort {
        in item command : SensorControlCommand;
        out item status : SensorStatusData;
    }
    
    port def ImageOutputPort {
        out item rawFrame : RawImageFrame;
        out item processedFrame : ProcessedImageFrame;
    }
    
    action def FocusLight {
        in scene : OpticalScene;
        out focusedImage : FocusedOpticalImage;
    }
    
    action def ConvertToElectrical {
        in opticalImage : FocusedOpticalImage;
        in exposureTime : ExposureDurationValue;
        out electricalSignal : AnalogSignal;
    }
    
    action def DigitizeSignal {
        in analogSignal : AnalogSignal;
        in format : ImageSensorFormat;
        out rawFrame : RawImageFrame;
    }
    
    action def ProcessFrame {
        in rawFrame : RawImageFrame;
        out processedFrame : ProcessedImageFrame;
    }
    
    action def CalculateExposure {
        in sceneIlluminance : IlluminanceValue;
        in targetBrightness : Real;
        out exposureTime : ExposureDurationValue;
    }
    
    action def MeasureIlluminance {
        in opticalImage : FocusedOpticalImage;
        out measuredIlluminance : IlluminanceValue;
    }
    
    state def ImageSensorOperationalStates {
        entry; then powerOff;
        
        state powerOff {
            entry action reportOffStatus {
                out item status : SensorStatusData;
            }
        }
        
        transition powerOff_to_initialization
            first powerOff
            accept SensorControlCommand
            then initialization;
        
        state initialization {
            entry action initializeSensor {
                out item status : SensorStatusData;
            }
        }
        
        transition initialization_to_standby
            first initialization
            then standby;
        
        state standby {
            entry action reportStandbyStatus {
                out item status : SensorStatusData;
            }
        }
        
        transition standby_to_exposureCalculation
            first standby
            accept SensorControlCommand
            then exposureCalculation;
        
        state exposureCalculation {
            entry action calculateExposure : CalculateExposure;
        }
        
        transition exposureCalculation_to_capturing
            first exposureCalculation
            then capturing;
        
        state capturing {
            entry action captureImage {
                action focus : FocusLight;
                flow from focus.focusedImage to measure.opticalImage;
                then action measure : MeasureIlluminance;
                flow from measure.opticalImage to convert.opticalImage;
                then action convert : ConvertToElectrical;
                flow from convert.electricalSignal to digitize.analogSignal;
                then action digitize : DigitizeSignal;
            }
        }
        
        transition capturing_to_processing
            first capturing
            then processing;
        
        state processing {
            entry action processImage : ProcessFrame;
        }
        
        transition processing_to_transmitting
            first processing
            then transmitting;
        
        state transmitting {
            entry action transmitFrames {
                out item rawFrame : RawImageFrame;
                out item processedFrame : ProcessedImageFrame;
            }
        }
        
        transition transmitting_to_standby
            first transmitting
            then standby;
        
        transition standby_to_powerOff
            first standby
            accept SensorControlCommand
            then powerOff;
        
        state fault {
            entry action reportFaultStatus {
                out item status : SensorStatusData;
            }
        }
        
        transition fault_to_initialization
            first fault
            accept SensorControlCommand
            then initialization;
    }
    
    part def OpticalLensAssembly {
        attribute focalLength : LengthValue;
        attribute apertureDiameter : LengthValue;
        attribute opticalQuality : Real;
        
        perform action focusAction : FocusLight;
    }
    
    part def PhotodetectorArray {
        attribute arrayResolution : ImageSensorFormat;
        attribute pixelPitch : LengthValue;
        attribute quantumEfficiency : Real;
        attribute darkCurrent : Real;
        
        perform action photoelectricConversion : ConvertToElectrical;
    }
    
    part def AnalogToDigitalConverter {
        attribute conversionResolution : Integer;
        attribute samplingRate : Real;
        attribute conversionAccuracy : Real;
        
        perform action digitization : DigitizeSignal;
    }
    
    part def ImageSignalProcessor {
        attribute processingAlgorithm : String;
        attribute noiseReductionEnabled : Boolean;
        attribute colorCorrectionEnabled : Boolean;
        
        perform action imageProcessing : ProcessFrame;
    }
    
    part def ExposureControlUnit {
        attribute autoExposureEnabled : Boolean;
        attribute targetBrightnessLevel : Real;
        
        perform action exposureCalculation : CalculateExposure;
    }
    
    part def IlluminanceMeter {
        attribute measurementRange : IlluminanceValue;
        attribute measurementAccuracy : Real;
        
        perform action illuminanceMeasurement : MeasureIlluminance;
    }
    
    part def ImageSensorModule {
        attribute sensorIdentifier : String;
        attribute sensorFormat : ImageSensorFormat;
        attribute operatingTemperatureRange : TemperatureValue[2];
        
        port controlInterface : ControlPort;
        port imageOutput : ImageOutputPort;
        
        ref item currentCommand : SensorControlCommand;
        ref item currentStatus : SensorStatusData;
        
        part optics : OpticalLensAssembly;
        
        part photodetectors : PhotodetectorArray;
        
        part adc : AnalogToDigitalConverter;
        
        part processor : ImageSignalProcessor;
        
        part exposureControl : ExposureControlUnit;
        
        part illuminanceSensor : IlluminanceMeter;
        
        perform action sensorBehavior : ImageSensorOperationalStates;
    }
    
    part def SensingUnit {
        attribute unitIdentifier : String;
        attribute calibrationTimestamp : DateTime;
        attribute firmwareVersion : String;
        
        port systemControl : ControlPort;
        port dataOutput : ImageOutputPort;
        
        part imageSensor : ImageSensorModule;
        
        part powerManagement {
            attribute inputVoltage : Real;
            attribute powerConsumption : Real;
            attribute batteryLevel : Real;
        }
        
        part thermalRegulation {
            attribute coolingEnabled : Boolean;
            attribute targetOperatingTemperature : TemperatureValue;
            attribute currentTemperature : TemperatureValue;
        }
        
        part dataStorage {
            attribute storageCapacity : Real;
            attribute usedStorage : Real;
            attribute compressionEnabled : Boolean;
        }
        
        connection controlLink connect systemControl to imageSensor.controlInterface;
        connection dataLink connect imageSensor.imageOutput to dataOutput;
        
        action def ExecuteSensingOperation {
            in controlCommand : SensorControlCommand;
            out imageFrame : ProcessedImageFrame;
            out statusReport : SensorStatusData;
            
            action receiveControlCommand {
                in item cmd : SensorControlCommand;
            }
            
            flow from receiveControlCommand.cmd to imagingSequence.cmd;
            
            then action imagingSequence {
                in item cmd : SensorControlCommand;
                
                action determineExposure : CalculateExposure {
                    in sceneIlluminance : IlluminanceValue;
                    in targetBrightness : Real;
                    out exposureTime : ExposureDurationValue;
                }
                
                flow from determineExposure.exposureTime to captureRawImage.exposureTime;
                
                then action captureRawImage {
                    in exposureTime : ExposureDurationValue;
                    
                    action focusScene : FocusLight {
                        in scene : OpticalScene;
                        out focusedImage : FocusedOpticalImage;
                    }
                    
                    flow from focusScene.focusedImage to measureLight.opticalImage;
                    
                    then action measureLight : MeasureIlluminance {
                        in opticalImage : FocusedOpticalImage;
                        out measuredIlluminance : IlluminanceValue;
                    }
                    
                    flow from measureLight.opticalImage to convertLight.opticalImage;
                    
                    then action convertLight : ConvertToElectrical {
                        in opticalImage : FocusedOpticalImage;
                        in exposureTime : ExposureDurationValue;
                        out electricalSignal : AnalogSignal;
                    }
                    
                    flow from convertLight.electricalSignal to digitizeSignal.analogSignal;
                    
                    then action digitizeSignal : DigitizeSignal {
                        in analogSignal : AnalogSignal;
                        in format : ImageSensorFormat;
                        out rawFrame : RawImageFrame;
                    }
                }
                
                flow from captureRawImage.digitizeSignal.rawFrame to processRawImage.rawFrame;
                
                then action processRawImage : ProcessFrame {
                    in rawFrame : RawImageFrame;
                    out processedFrame : ProcessedImageFrame;
                }
            }
            
            action generateStatusReport {
                out item report : SensorStatusData;
            }
        }
        
        perform action operation : ExecuteSensingOperation;
    }
    
    requirement def ImageSensorFormatRequirement {
        doc /* The sensing unit shall measure illuminance using an image sensor with defined format specifications including resolution, bit depth, and color space. */
        
        subject unit : SensingUnit;
        
        require minHorizontalResolution {
            unit.imageSensor.sensorFormat.horizontalResolution.num >= 1280.0
        }
        
        require minVerticalResolution {
            unit.imageSensor.sensorFormat.verticalResolution.num >= 720.0
        }
        
        require minBitDepth {
            unit.imageSensor.sensorFormat.bitDepth >= 8
        }
    }
    
    requirement def QuantityMeasurementRequirement {
        doc /* The sensing unit shall measure illuminance as the relevant physical quantity and include it in the captured image frame data. */
        
        subject unit : SensingUnit;
    }
    
    requirement def OperationalStateRequirement {
        doc /* The sensing unit shall implement a complete operational state machine with initialization, standby, capture, processing, and fault states. */
        
        subject unit : SensingUnit;
    }
    
    part sensingUnitInstance : SensingUnit {
        attribute redefines unitIdentifier = "IMG-SENSE-UNIT-001";
        attribute redefines firmwareVersion = "2.1.4";
        
        part redefines imageSensor : ImageSensorModule {
            attribute redefines sensorIdentifier = "CMOS-SENSOR-HD";
        }
        
        part redefines thermalRegulation {
            attribute redefines coolingEnabled = true;
        }
        
        satisfy formatReq : ImageSensorFormatRequirement {
            subject redefines unit = sensingUnitInstance;
        }
        
        satisfy measurementReq : QuantityMeasurementRequirement {
            subject redefines unit = sensingUnitInstance;
        }
        
        satisfy operationalReq : OperationalStateRequirement {
            subject redefines unit = sensingUnitInstance;
        }
    }
}
