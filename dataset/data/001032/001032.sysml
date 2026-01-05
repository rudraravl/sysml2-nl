package ElectroOpticalSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQBase::*;
    private import SI::*;
    private import Measurement::*;
    
    attribute def IrradianceUnit :> SimpleUnit;
    
    attribute def IrradianceValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : IrradianceUnit;
    }
    
    attribute def ResponsivityValue :> ScalarQuantityValue {
        attribute :>> num : Real;
        attribute :>> mRef : SimpleUnit;
    }
    
    item def OpticalRadiation {
        attribute wavelength : LengthValue;
        attribute irradiance : IrradianceValue;
        attribute incidentAngle : Real;
    }
    
    item def PhotocurrentSignal {
        attribute current : Real;
        attribute voltage : Real;
        attribute timestamp : Real;
    }
    
    item def DigitalMeasurement {
        attribute measuredIrradiance : IrradianceValue;
        attribute confidence : Real;
        attribute isValid : Boolean;
        attribute timestamp : Real;
    }
    
    port def OpticalInputPort {
        in item radiation : OpticalRadiation;
    }
    
    port def AnalogSignalPort {
        out item signal : PhotocurrentSignal;
    }
    
    port def DigitalOutputPort {
        out item measurement : DigitalMeasurement;
    }
    
    port def PowerPort {
        in attribute supplyVoltage : Real;
        in attribute supplyCurrent : Real;
    }
    
    action def DetectRadiation {
        in item incidentRadiation : OpticalRadiation;
        out item photocurrent : PhotocurrentSignal;
    }
    
    action def AmplifySignal {
        in item inputSignal : PhotocurrentSignal;
        out item amplifiedSignal : PhotocurrentSignal;
    }
    
    action def ConvertToDigital {
        in item analogSignal : PhotocurrentSignal;
        out item digitalValue : DigitalMeasurement;
    }
    
    action def CalibrateReading {
        in item rawMeasurement : DigitalMeasurement;
        out item calibratedMeasurement : DigitalMeasurement;
    }
    
    action def ValidateMeasurement {
        in item measurement : DigitalMeasurement;
        out item validatedMeasurement : DigitalMeasurement;
    }
    
    action def PerformMeasurement {
        in item radiation : OpticalRadiation;
        out item finalMeasurement : DigitalMeasurement;
        
        action detect : DetectRadiation {
            in item incidentRadiation = PerformMeasurement::radiation;
            out item photocurrent;
        }
        
        then amplify;
        
        flow from detect.photocurrent to amplify.inputSignal;
        
        action amplify : AmplifySignal {
            in item inputSignal;
            out item amplifiedSignal;
        }
        
        then convert;
        
        flow from amplify.amplifiedSignal to convert.analogSignal;
        
        action convert : ConvertToDigital {
            in item analogSignal;
            out item digitalValue;
        }
        
        then calibrate;
        
        flow from convert.digitalValue to calibrate.rawMeasurement;
        
        action calibrate : CalibrateReading {
            in item rawMeasurement;
            out item calibratedMeasurement;
        }
        
        then validate;
        
        flow from calibrate.calibratedMeasurement to validate.measurement;
        
        action validate : ValidateMeasurement {
            in item measurement;
            out item validatedMeasurement = PerformMeasurement::finalMeasurement;
        }
    }
    
    state def SensorOperationalState {
        entry; then powerOff;
        
        state powerOff;
        transition then initializing;
        
        state initializing {
            entry; then selfTest;
            
            state selfTest;
            transition then calibration;
            
            state calibration;
            transition then done;
        }
        transition then standby;
        
        state standby;
        transition then measuring;
        
        state measuring {
            entry; then acquiring;
            
            state acquiring;
            transition then processing;
            
            state processing;
            transition then validating;
            
            state validating;
            transition then outputting;
            
            state outputting;
            transition then done;
        }
        transition then standby;
        
        transition then shutdown;
        
        state shutdown;
        then powerOff;
    }
    
    part def Photodetector {
        attribute responsivity : ResponsivityValue;
        attribute activeArea : AreaValue;
        attribute spectralResponseMin : LengthValue;
        attribute spectralResponseMax : LengthValue;
        attribute darkCurrent : Real;
        
        port opticalIn : OpticalInputPort;
        port signalOut : AnalogSignalPort;
        
        perform action detection : DetectRadiation;
    }
    
    part def TransimpedanceAmplifier {
        attribute gainResistance : Real;
        attribute bandwidth : FrequencyValue;
        attribute inputNoiseVoltage : Real;
        
        port signalIn : AnalogSignalPort;
        port signalOut : AnalogSignalPort;
        port power : PowerPort;
        
        perform action amplification : AmplifySignal;
    }
    
    part def ADC {
        attribute resolution : Integer;
        attribute samplingRate : FrequencyValue;
        attribute referenceVoltage : Real;
        attribute conversionTime : TimeValue;
        
        port analogIn : AnalogSignalPort;
        port digitalOut : DigitalOutputPort;
        port power : PowerPort;
        
        perform action digitization : ConvertToDigital;
    }
    
    part def SignalProcessingUnit {
        attribute calibrationMatrix : Real[*];
        attribute filterCoefficients : Real[*];
        attribute validationThreshold : Real;
        
        port dataIn : DigitalOutputPort;
        port dataOut : DigitalOutputPort;
        port power : PowerPort;
        
        perform action calibration : CalibrateReading;
        perform action validation : ValidateMeasurement;
    }
    
    part def OpticalWindow {
        attribute transmittance : Real;
        attribute antireflectionCoating : Boolean;
        attribute protectionRating : String;
        
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalInputPort;
    }
    
    part def ElectroOpticalSensor {
        attribute sensorID : String;
        attribute operatingTemperatureMin : TemperatureValue;
        attribute operatingTemperatureMax : TemperatureValue;
        attribute totalPowerConsumption : PowerValue;
        
        port opticalInterface : OpticalInputPort;
        port measurementInterface : DigitalOutputPort;
        port powerSupply : PowerPort;
        
        part window : OpticalWindow[1] {
            attribute :>> transmittance = 0.98;
            attribute :>> antireflectionCoating = true;
            attribute :>> protectionRating = "IP67";
        }
        
        part detector : Photodetector[1] {
            attribute :>> responsivity.num = 0.65;
            attribute :>> activeArea.num = 1.0;
            attribute :>> spectralResponseMin.num = 400.0;
            attribute :>> spectralResponseMax.num = 1100.0;
            attribute :>> darkCurrent = 1.0e-9;
        }
        
        part tia : TransimpedanceAmplifier[1] {
            attribute :>> gainResistance = 1.0e6;
            attribute :>> bandwidth.num = 100.0e3;
            attribute :>> inputNoiseVoltage = 5.0e-9;
        }
        
        part converter : ADC[1] {
            attribute :>> resolution = 24;
            attribute :>> samplingRate.num = 1000.0;
            attribute :>> referenceVoltage = 5.0;
        }
        
        part processor : SignalProcessingUnit[1] {
            attribute :>> validationThreshold = 0.95;
        }
        
        connection windowToDetector : OpticalInputPort
            connect window.opticalOut to detector.opticalIn;
        
        connection detectorToTIA : AnalogSignalPort
            connect detector.signalOut to tia.signalIn;
        
        connection tiaToADC : AnalogSignalPort
            connect tia.signalOut to converter.analogIn;
        
        connection adcToProcessor : DigitalOutputPort
            connect converter.digitalOut to processor.dataIn;
        
        connection processorToOutput : DigitalOutputPort
            connect processor.dataOut to measurementInterface;
        
        connection opticalInput : OpticalInputPort
            connect opticalInterface to window.opticalIn;
        
        connection tiaPower : PowerPort
            connect powerSupply to tia.power;
        
        connection adcPower : PowerPort
            connect powerSupply to converter.power;
        
        connection processorPower : PowerPort
            connect powerSupply to processor.power;
        
        perform action sensing : PerformMeasurement;
        
        exhibit state operationalBehavior : SensorOperationalState;
    }
    
    part def SensingUnit {
        attribute unitIdentifier : String;
        attribute measuredQuantityType : String;
        attribute measurementRangeMin : IrradianceValue;
        attribute measurementRangeMax : IrradianceValue;
        attribute measurementAccuracy : Real;
        attribute measurementPrecision : Real;
        attribute responseTime : TimeValue;
        
        port opticalInput : OpticalInputPort;
        port dataOutput : DigitalOutputPort;
        port mainPower : PowerPort;
        
        part eoSensor : ElectroOpticalSensor[1] {
            attribute :>> sensorID = "EOS-2024-001";
            attribute :>> operatingTemperatureMin.num = 233.15;
            attribute :>> operatingTemperatureMax.num = 358.15;
            attribute :>> totalPowerConsumption.num = 2.5;
        }
        
        connection opticalPath : OpticalInputPort
            connect opticalInput to eoSensor.opticalInterface;
        
        connection dataPath : DigitalOutputPort
            connect eoSensor.measurementInterface to dataOutput;
        
        connection powerPath : PowerPort
            connect mainPower to eoSensor.powerSupply;
    }
    
    requirement def SensingUnitRequirement {
        doc /* The sensing unit shall measure optical irradiance using an electro-optical sensor 
                with specified accuracy and response time. */
        
        subject unit : SensingUnit;
        
        require constraint accuracyConstraint {
            unit.measurementAccuracy <= 0.02
        }
        
        require constraint rangeConstraint {
            unit.measurementRangeMin.num >= 0.0 and
            unit.measurementRangeMax.num <= 2000.0
        }
        
        require constraint responseTimeConstraint {
            unit.responseTime.num <= 0.1
        }
        
        require constraint sensorTypeConstraint {
            unit.eoSensor.detector.spectralResponseMin.num <= 450.0 and
            unit.eoSensor.detector.spectralResponseMax.num >= 1000.0
        }
    }
    
    requirement def CalibrationRequirement {
        doc /* The sensing unit shall maintain calibration accuracy through periodic validation. */
        
        subject unit : SensingUnit;
        
        require constraint calibrationIntervalConstraint {
            unit.eoSensor.processor.calibrationMatrix->size() >= 9
        }
    }
    
    part sensingUnitInstance : SensingUnit {
        attribute :>> unitIdentifier = "SU-IRR-001";
        attribute :>> measuredQuantityType = "Optical Irradiance";
        attribute :>> measurementRangeMin.num = 0.1;
        attribute :>> measurementRangeMax.num = 1500.0;
        attribute :>> measurementAccuracy = 0.015;
        attribute :>> measurementPrecision = 0.005;
        attribute :>> responseTime.num = 0.05;
        
        satisfy requirement sensingReq : SensingUnitRequirement {
            subject unit = sensingUnitInstance;
        }
        
        satisfy requirement calibrationReq : CalibrationRequirement {
            subject unit = sensingUnitInstance;
        }
    }
}
