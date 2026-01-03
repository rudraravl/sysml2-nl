package LightSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::*;
    private import MeasurementReferences::*;
    
    attribute def IlluminanceValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : IlluminanceUnit;
    }
    
    attribute def VoltageValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : VoltageUnit;
    }
    
    attribute def CurrentValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : ElectricCurrentUnit;
    }
    
    attribute def TemperatureValue :> QuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : TemperatureUnit;
    }
    
    item def LightSource {
        attribute intensity : IlluminanceValue;
        attribute wavelength : LengthValue;
    }
    
    item def LightMeasurement {
        attribute illuminance : IlluminanceValue;
        attribute timestamp : Real;
        attribute sensorId : String;
        attribute isValid : Boolean;
    }
    
    item def CalibrationData {
        attribute offsetValue : Real;
        attribute gainFactor : Real;
        attribute referenceIlluminance : IlluminanceValue;
        attribute calibrationDate : String;
    }
    
    attribute def SensorStatus {
        attribute isCalibrated : Boolean;
        attribute isActive : Boolean;
        attribute errorCode : Integer;
        attribute temperature : TemperatureValue;
    }
    
    port def OpticalInputPort {
        in item lightInput : LightSource;
    }
    
    port def ElectricalOutputPort {
        out attribute photocurrent : CurrentValue;
    }
    
    port def AnalogSignalPort {
        in attribute inputSignal : VoltageValue;
        out attribute outputSignal : VoltageValue;
    }
    
    port def DigitalDataPort {
        in attribute digitalInput : Integer;
        out attribute digitalOutput : Integer;
    }
    
    port def MeasurementOutputPort {
        out item measurement : LightMeasurement;
    }
    
    port def ControlInterfacePort {
        in item calibration : CalibrationData;
        in attribute enableSignal : Boolean;
        in attribute resetSignal : Boolean;
        out attribute status : SensorStatus;
    }
    
    port def PowerSupplyPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute supplyCurrent : CurrentValue;
    }
    
    action def DetectLight {
        in item lightSource : LightSource;
        out attribute photocurrent : CurrentValue;
    }
    
    action def AmplifySignal {
        in attribute inputCurrent : CurrentValue;
        in attribute gainFactor : Real;
        out attribute outputVoltage : VoltageValue;
    }
    
    action def FilterSignal {
        in attribute inputVoltage : VoltageValue;
        out attribute filteredVoltage : VoltageValue;
    }
    
    action def ConvertToDigital {
        in attribute analogVoltage : VoltageValue;
        in attribute referenceVoltage : VoltageValue;
        in attribute resolution : Integer;
        out attribute digitalValue : Integer;
    }
    
    action def ApplyCalibration {
        in attribute rawValue : Integer;
        in item calibration : CalibrationData;
        out attribute calibratedValue : Real;
    }
    
    action def ValidateMeasurement {
        in attribute measuredValue : Real;
        in attribute minThreshold : Real;
        in attribute maxThreshold : Real;
        out attribute isValid : Boolean;
        out attribute validatedValue : Real;
    }
    
    action def CreateMeasurement {
        in attribute illuminanceValue : Real;
        in attribute sensorIdentifier : String;
        in attribute validFlag : Boolean;
        out item measurement : LightMeasurement;
    }
    
    action def PerformCalibration {
        in item referenceLight : LightSource;
        in attribute measuredRawValue : Integer;
        out item updatedCalibration : CalibrationData;
        out attribute calibrationSuccess : Boolean;
    }
    
    action def MeasureIlluminance {
        in item ambientLight : LightSource;
        in item calibrationData : CalibrationData;
        in attribute sensorId : String;
        out item lightMeasurement : LightMeasurement;
        
        bind detectLight.lightSource = ambientLight;
        
        action detectLight : DetectLight {
            in lightSource;
            out photocurrent;
        }
        
        flow from detectLight.photocurrent to amplifySignal.inputCurrent;
        first detectLight then amplifySignal;
        
        action amplifySignal : AmplifySignal {
            in inputCurrent;
            in gainFactor = 150.0;
            out outputVoltage;
        }
        
        flow from amplifySignal.outputVoltage to filterSignal.inputVoltage;
        first amplifySignal then filterSignal;
        
        action filterSignal : FilterSignal {
            in inputVoltage;
            out filteredVoltage;
        }
        
        flow from filterSignal.filteredVoltage to convertToDigital.analogVoltage;
        first filterSignal then convertToDigital;
        
        action convertToDigital : ConvertToDigital {
            in analogVoltage;
            in referenceVoltage = 3.3;
            in resolution = 16;
            out digitalValue;
        }
        
        flow from convertToDigital.digitalValue to applyCalibration.rawValue;
        flow from calibrationData to applyCalibration.calibration;
        first convertToDigital then applyCalibration;
        
        action applyCalibration : ApplyCalibration {
            in rawValue;
            in calibration;
            out calibratedValue;
        }
        
        flow from applyCalibration.calibratedValue to validateMeasurement.measuredValue;
        first applyCalibration then validateMeasurement;
        
        action validateMeasurement : ValidateMeasurement {
            in measuredValue;
            in minThreshold = 0.0;
            in maxThreshold = 100000.0;
            out isValid;
            out validatedValue;
        }
        
        flow from validateMeasurement.validatedValue to createMeasurement.illuminanceValue;
        flow from validateMeasurement.isValid to createMeasurement.validFlag;
        flow from sensorId to createMeasurement.sensorIdentifier;
        first validateMeasurement then createMeasurement;
        
        action createMeasurement : CreateMeasurement {
            in illuminanceValue;
            in sensorIdentifier;
            in validFlag;
            out measurement;
        }
        
        bind createMeasurement.measurement = lightMeasurement;
    }
    
    state def LightSensorStateMachine {
        attribute currentStatus : SensorStatus;
        
        entry; then powerOn;
        
        state powerOn;
        
        transition powerOn_to_initialization
            first powerOn
            accept powerUpComplete
            then initialization;
        
        state initialization;
        
        transition initialization_to_idle
            first initialization
            then idle;
        
        state idle;
        
        transition idle_to_calibration
            first idle
            accept calibrationRequest
            then calibration;
        
        transition idle_to_measuring
            first idle
            accept measurementRequest
            then measuring;
        
        state calibration;
        
        transition calibration_to_idle
            first calibration
            then idle;
        
        state measuring;
        
        transition measuring_to_idle
            first measuring
            accept stopMeasurement
            then idle;
        
        transition measuring_to_error
            first measuring
            accept sensorFault
            then error;
        
        state error;
        
        transition error_to_idle
            first error
            accept resetCommand
            then idle;
    }
    
    part def PhotodiodeElement {
        attribute spectralSensitivity : Real;
        attribute activeArea : AreaValue;
        attribute responsivity : Real;
        attribute darkCurrent : CurrentValue;
        
        port opticalInput : OpticalInputPort;
        port electricalOutput : ElectricalOutputPort;
        
        perform action lightDetection : DetectLight {
            in lightSource = opticalInput.lightInput;
            out photocurrent = electricalOutput.photocurrent;
        }
    }
    
    part def TransimpedanceAmplifier {
        attribute feedbackResistance : Real;
        attribute bandwidth : Real;
        attribute inputBias : CurrentValue;
        
        port currentInput {
            in attribute inputCurrent : CurrentValue;
        }
        
        port voltageOutput {
            out attribute outputVoltage : VoltageValue;
        }
        
        perform action amplification : AmplifySignal {
            in inputCurrent = currentInput.inputCurrent;
            in gainFactor = feedbackResistance;
            out outputVoltage = voltageOutput.outputVoltage;
        }
    }
    
    part def LowPassFilter {
        attribute cutoffFrequency : Real;
        attribute filterOrder : Integer;
        
        port filterInput : AnalogSignalPort;
        port filterOutput : AnalogSignalPort;
        
        perform action filtering : FilterSignal {
            in inputVoltage = filterInput.inputSignal;
            out filteredVoltage = filterOutput.outputSignal;
        }
    }
    
    part def ADCConverter {
        attribute resolution : Integer;
        attribute samplingRate : Real;
        attribute referenceVoltage : VoltageValue;
        attribute conversionTime : Real;
        
        port analogInput {
            in attribute inputVoltage : VoltageValue;
        }
        
        port digitalOutput : DigitalDataPort;
        
        perform action conversion : ConvertToDigital {
            in analogVoltage = analogInput.inputVoltage;
            in referenceVoltage = ADCConverter::referenceVoltage;
            in resolution = ADCConverter::resolution;
            out digitalValue = digitalOutput.digitalOutput;
        }
    }
    
    part def ProcessingUnit {
        attribute processorSpeed : Real;
        attribute memoryCapacity : Integer;
        attribute firmwareVersion : String;
        
        part calibrationMemory {
            item storedCalibration : CalibrationData {
                attribute :>> offsetValue = 0.0;
                attribute :>> gainFactor = 1.0;
                attribute :>> calibrationDate = "2025-01-01";
            }
        }
        
        port dataInput : DigitalDataPort;
        port measurementOutput : MeasurementOutputPort;
        port controlInterface : ControlInterfacePort;
        
        perform action processing : MeasureIlluminance;
    }
    
    part def LightSensor {
        attribute sensorIdentifier : String;
        attribute operatingTemperatureMin : TemperatureValue;
        attribute operatingTemperatureMax : TemperatureValue;
        attribute measurementRangeMin : IlluminanceValue;
        attribute measurementRangeMax : IlluminanceValue;
        attribute accuracy : Real;
        
        part photodiode : PhotodiodeElement {
            attribute :>> spectralSensitivity = 0.62;
            attribute :>> responsivity = 0.48;
        }
        
        part amplifier : TransimpedanceAmplifier {
            attribute :>> feedbackResistance = 100000.0;
            attribute :>> bandwidth = 10000.0;
        }
        
        part filter : LowPassFilter {
            attribute :>> cutoffFrequency = 1000.0;
            attribute :>> filterOrder = 2;
        }
        
        part adc : ADCConverter {
            attribute :>> resolution = 16;
            attribute :>> samplingRate = 1000.0;
        }
        
        part processor : ProcessingUnit {
            attribute :>> processorSpeed = 48000000.0;
            attribute :>> memoryCapacity = 65536;
            attribute :>> firmwareVersion = "1.0.0";
        }
        
        port opticalPort : OpticalInputPort;
        port dataPort : MeasurementOutputPort;
        port controlPort : ControlInterfacePort;
        port powerPort : PowerSupplyPort;
        
        connection photodiodeToAmplifier
            connect photodiode.electricalOutput.photocurrent
            to amplifier.currentInput.inputCurrent;
        
        connection amplifierToFilter
            connect amplifier.voltageOutput.outputVoltage
            to filter.filterInput.inputSignal;
        
        connection filterToADC
            connect filter.filterOutput.outputSignal
            to adc.analogInput.inputVoltage;
        
        connection adcToProcessor
            connect adc.digitalOutput.digitalOutput
            to processor.dataInput.digitalInput;
        
        connection processorToOutput
            connect processor.measurementOutput.measurement
            to dataPort.measurement;
        
        connection controlToProcessor
            connect controlPort.calibration
            to processor.controlInterface.calibration;
        
        connection controlEnableToProcessor
            connect controlPort.enableSignal
            to processor.controlInterface.enableSignal;
        
        connection processorStatusToControl
            connect processor.controlInterface.status
            to controlPort.status;
        
        connection opticalToPhotodiode
            connect opticalPort.lightInput
            to photodiode.opticalInput.lightInput;
        
        perform action sensingOperation : MeasureIlluminance {
            in ambientLight = opticalPort.lightInput;
            in calibrationData = processor.calibrationMemory.storedCalibration;
            in sensorId = sensorIdentifier;
            out lightMeasurement = dataPort.measurement;
        }
        
        exhibit state sensorBehavior : LightSensorStateMachine;
    }
    
    part sensingUnit : LightSensor {
        attribute :>> sensorIdentifier = "LS-2025-001";
        attribute :>> accuracy = 0.05;
        
        part :>> processor {
            part :>> calibrationMemory {
                item :>> storedCalibration {
                    attribute :>> offsetValue = 3.5;
                    attribute :>> gainFactor = 1.02;
                    attribute :>> calibrationDate = "2025-01-15";
                }
            }
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* The light sensor shall measure illuminance with an accuracy within the specified tolerance across the full measurement range. */
        
        subject sensor : LightSensor;
        attribute requiredAccuracy : Real;
        
        require constraint {
            sensor.accuracy <= requiredAccuracy
        }
    }
    
    requirement def MeasurementRangeRequirement {
        doc /* The light sensor shall operate reliably across the specified illuminance range. */
        
        subject sensor : LightSensor;
        attribute minIlluminance : IlluminanceValue;
        attribute maxIlluminance : IlluminanceValue;
        
        require constraint {
            sensor.measurementRangeMin.num >= minIlluminance.num and
            sensor.measurementRangeMax.num <= maxIlluminance.num
        }
    }
    
    requirement def TemperatureRangeRequirement {
        doc /* The light sensor shall operate within the specified temperature range. */
        
        subject sensor : LightSensor;
        attribute minTemperature : TemperatureValue;
        attribute maxTemperature : TemperatureValue;
        
        require constraint {
            sensor.operatingTemperatureMin.num >= minTemperature.num and
            sensor.operatingTemperatureMax.num <= maxTemperature.num
        }
    }
    
    requirement def CalibrationRequirement {
        doc /* The light sensor shall support field calibration to maintain measurement accuracy over time. */
        
        subject sensor : LightSensor;
        
        require constraint {
            sensor.processor.calibrationMemory.storedCalibration.gainFactor > 0.0 and
            sensor.processor.calibrationMemory.storedCalibration.gainFactor < 2.0
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The light sensor shall provide measurement updates at a minimum sampling rate. */
        
        subject sensor : LightSensor;
        attribute minimumSamplingRate : Real;
        
        require constraint {
            sensor.adc.samplingRate >= minimumSamplingRate
        }
    }
    
    requirement sensingUnitRequirements {
        doc /* Complete requirements specification for the light sensing unit. */
        
        subject unit : LightSensor = sensingUnit;
        
        require accuracyReq : AccuracyRequirement {
            subject sensor = unit;
            attribute :>> requiredAccuracy = 0.05;
        }
        
        require rangeReq : MeasurementRangeRequirement {
            subject sensor = unit;
        }
        
        require temperatureReq : TemperatureRangeRequirement {
            subject sensor = unit;
        }
        
        require calibrationReq : CalibrationRequirement {
            subject sensor = unit;
        }
        
        require responseReq : ResponseTimeRequirement {
            subject sensor = unit;
            attribute :>> minimumSamplingRate = 10.0;
        }
    }
}
