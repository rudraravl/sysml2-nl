package SensingUnitModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IlluminanceUnit :> ISQ::DerivedUnit {
        attribute :>> unitPowerFactor : ISQ::UnitPowerFactor[2] ordered;
    }
    
    attribute def IlluminanceValue :> ISQ::QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : IlluminanceUnit;
    }
    
    attribute def PixelCount :> ISQ::QuantityValue {
        attribute :>> num : Integer;
    }
    
    attribute def ExposureTimeValue :> ISQ::TimeValue {
        attribute :>> num : Real;
        attribute :>> mRef : ISQ::TimeUnit;
    }
    
    item def OpticalScene {
        attribute ambientIlluminance : IlluminanceValue;
        attribute wavelengthRange : ISQ::LengthValue[2];
    }
    
    item def RawImageData {
        attribute pixelValues : Integer[*] ordered;
        attribute captureTimestamp : ISQ::TimeValue;
        attribute exposureTime : ExposureTimeValue;
        attribute isSaturated : Boolean;
    }
    
    item def ProcessedImageData {
        attribute imageData : RawImageData;
        attribute averageIntensity : Real;
        attribute isValid : Boolean;
    }
    
    item def MeasurementResult {
        attribute illuminance : IlluminanceValue;
        attribute confidence : Real;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def CaptureCommand;
    item def ProcessCommand;
    item def MeasureCommand;
    item def ResetCommand;
    item def DataReady;
    
    port def OpticalInputPort {
        in item scene : OpticalScene;
    }
    
    port def ImageDataPort {
        out item rawData : RawImageData;
    }
    
    port def ProcessedDataPort {
        out item processedData : ProcessedImageData;
    }
    
    port def MeasurementOutputPort {
        out item measurement : MeasurementResult;
    }
    
    port def ControlInputPort {
        in item command : CaptureCommand;
    }
    
    action def CaptureImage {
        in scene : OpticalScene;
        in exposureTime : ExposureTimeValue;
        out rawImage : RawImageData;
    }
    
    action def ProcessRawImage {
        in rawImage : RawImageData;
        out processedImage : ProcessedImageData;
    }
    
    action def CalculateIlluminance {
        in processedImage : ProcessedImageData;
        in calibrationFactor : Real;
        out measurement : MeasurementResult;
    }
    
    action def PerformMeasurement {
        in scene : OpticalScene;
        in exposureTime : ExposureTimeValue;
        in calibrationFactor : Real;
        out measurement : MeasurementResult;
        
        action capture : CaptureImage {
            in item scene = PerformMeasurement::scene;
            in item exposureTime = PerformMeasurement::exposureTime;
            out item rawImage;
        }
        
        first capture;
        
        flow from capture.rawImage to process.rawImage;
        
        then action process : ProcessRawImage {
            in item rawImage;
            out item processedImage;
        }
        
        flow from process.processedImage to calculate.processedImage;
        
        then action calculate : CalculateIlluminance {
            in item processedImage;
            in item calibrationFactor = PerformMeasurement::calibrationFactor;
            out item measurement = PerformMeasurement::measurement;
        }
    }
    
    state def ImageSensorStateMachine {
        entry; then idle;
        
        state idle;
        
        transition idle_to_capturing
            first idle
            accept CaptureCommand
            then capturing;
        
        state capturing {
            entry action captureAction : CaptureImage;
        }
        
        transition capturing_to_processing
            first capturing
            accept DataReady
            then processing;
        
        state processing {
            entry action processAction : ProcessRawImage;
        }
        
        transition processing_to_measuring
            first processing
            accept DataReady
            then measuring;
        
        state measuring {
            entry action measureAction : CalculateIlluminance;
        }
        
        transition measuring_to_ready
            first measuring
            accept DataReady
            then ready;
        
        state ready;
        
        transition ready_to_idle
            first ready
            accept ResetCommand
            then idle;
    }
    
    part def PixelArray {
        attribute horizontalPixels : PixelCount {
            attribute :>> num = 1920;
        }
        attribute verticalPixels : PixelCount {
            attribute :>> num = 1080;
        }
        attribute pixelPitch : ISQ::LengthValue;
        attribute quantumEfficiency : Real;
    }
    
    part def AnalogToDigitalConverter {
        attribute bitDepth : Integer;
        attribute conversionRate : Real;
    }
    
    part def SignalProcessor {
        attribute processingSpeed : Real;
        attribute noiseReductionEnabled : Boolean;
        
        perform action processImage : ProcessRawImage;
    }
    
    part def MeasurementEngine {
        attribute calibrationFactor : Real;
        
        perform action calculateMeasurement : CalculateIlluminance;
    }
    
    part def ImageSensor {
        attribute sensorResolution : PixelCount {
            attribute :>> num = 2073600;
        }
        attribute nominalExposure : ExposureTimeValue {
            attribute :>> num = 0.033;
        }
        attribute spectralRange : ISQ::LengthValue[2];
        
        port opticalInput : OpticalInputPort;
        port dataOutput : ImageDataPort;
        port controlInput : ControlInputPort;
        
        part pixels : PixelArray {
            attribute :>> horizontalPixels.num = 1920;
            attribute :>> verticalPixels.num = 1080;
            attribute :>> quantumEfficiency = 0.75;
        }
        
        part adc : AnalogToDigitalConverter {
            attribute :>> bitDepth = 12;
            attribute :>> conversionRate = 60.0;
        }
        
        perform action captureImage : CaptureImage;
        
        exhibit state behavior : ImageSensorStateMachine;
    }
    
    part def SensingUnit {
        ref item observedScene : OpticalScene;
        
        port sceneInput : OpticalInputPort;
        port measurementOutput : MeasurementOutputPort;
        
        part sensor : ImageSensor {
            attribute :>> nominalExposure.num = 0.020;
            attribute :>> sensorResolution.num = 2073600;
        }
        
        part processor : SignalProcessor {
            attribute :>> noiseReductionEnabled = true;
            attribute :>> processingSpeed = 30.0;
        }
        
        part measurementEngine : MeasurementEngine {
            attribute :>> calibrationFactor = 1.25;
        }
        
        part controller {
            port commandOutput;
        }
        
        connection sensorControl connect controller.commandOutput to sensor.controlInput;
        
        item measurements : MeasurementResult[*];
        
        perform action measure : PerformMeasurement;
    }
    
    requirement def IlluminanceMeasurementRequirement {
        doc /* The sensing unit shall measure illuminance from the observed scene using an image sensor 
                with minimum resolution of 1920x1080 pixels and exposure time control. */
        
        subject unit : SensingUnit;
        
        require constraint minResolution {
            unit.sensor.sensorResolution.num >= 2073600
        }
        
        require constraint exposureControl {
            unit.sensor.nominalExposure.num > 0.0 and unit.sensor.nominalExposure.num < 1.0
        }
        
        require constraint validCalibration {
            unit.measurementEngine.calibrationFactor > 0.0
        }
        
        require constraint quantumEfficiency {
            unit.sensor.pixels.quantumEfficiency >= 0.5
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The sensing unit shall provide illuminance measurements with confidence level tracking. */
        
        subject unit : SensingUnit;
        
        require constraint confidenceTracking {
            unit.measurements->size() >= 0
        }
    }
    
    part actualSensingUnit : SensingUnit;
    
    requirement illuminanceReq : IlluminanceMeasurementRequirement {
        subject :>> unit = actualSensingUnit;
    }
    
    requirement accuracyReq : MeasurementAccuracyRequirement {
        subject :>> unit = actualSensingUnit;
    }
    
    satisfy illuminanceReq by actualSensingUnit;
    satisfy accuracyReq by actualSensingUnit;
}
