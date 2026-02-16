package HydrogenSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PartsPerMillion :> Real {
        doc /* Hydrogen concentration in parts per million (ppm) */
    }
    
    item def GasSample {
        attribute hydrogenConcentration : PartsPerMillion;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute humidity : Real;
    }
    
    item def RawSensorSignal {
        attribute voltage : Real;
        attribute timestamp : Real;
    }
    
    item def ProcessedMeasurement {
        attribute concentration : PartsPerMillion;
        attribute temperature : TemperatureValue;
        attribute timestamp : Real;
        attribute isValid : Boolean;
        attribute qualityFactor : Real;
    }
    
    item def CalibrationParameters {
        attribute zeroOffset : Real;
        attribute spanGain : Real;
        attribute temperatureCoefficient : Real;
        attribute lastCalibrationTime : Real;
    }
    
    port def GasInputPort {
        in item sample : GasSample;
    }
    
    port def SensorOutputPort {
        out item signal : RawSensorSignal;
    }
    
    port def ProcessorInputPort {
        in item signal : RawSensorSignal;
    }
    
    port def MeasurementOutputPort {
        out item measurement : ProcessedMeasurement;
    }
    
    port def CalibrationPort {
        in item parameters : CalibrationParameters;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }
    
    action def SenseHydrogen {
        in item gasSample : GasSample;
        out item rawSignal : RawSensorSignal;
    }
    
    action def AmplifySignal {
        in item rawSignal : RawSensorSignal;
        out item amplifiedSignal : RawSensorSignal;
    }
    
    action def FilterNoise {
        in item amplifiedSignal : RawSensorSignal;
        out item filteredSignal : RawSensorSignal;
    }
    
    action def ConvertToDigital {
        in item filteredSignal : RawSensorSignal;
        out item digitalValue : Real;
    }
    
    action def ApplyCalibration {
        in item digitalValue : Real;
        in item calibration : CalibrationParameters;
        out item calibratedValue : Real;
    }
    
    action def CompensateTemperature {
        in item calibratedValue : Real;
        in item temperature : TemperatureValue;
        in item calibration : CalibrationParameters;
        out item compensatedValue : Real;
    }
    
    action def ValidateMeasurement {
        in item compensatedValue : Real;
        out item isValid : Boolean;
        out item qualityFactor : Real;
    }
    
    action def GenerateMeasurement {
        in item compensatedValue : Real;
        in item temperature : TemperatureValue;
        in item timestamp : Real;
        in item isValid : Boolean;
        in item qualityFactor : Real;
        out item measurement : ProcessedMeasurement;
    }
    
    state def SensorOperationalState {
        entry action initializeSensor;
        
        state off;
        state warmingUp;
        state ready;
        state measuring;
        state calibrating;
        state error;
        
        transition powerOn
            first off
            then warmingUp;
        
        transition warmupComplete
            first warmingUp
            then ready;
        
        transition startMeasurement
            first ready
            then measuring;
        
        transition measurementComplete
            first measuring
            then ready;
        
        transition startCalibration
            first ready
            then calibrating;
        
        transition calibrationComplete
            first calibrating
            then ready;
        
        transition toError
            then error;
        
        transition errorRecovered
            first error
            then ready;
        
        transition powerOff
            then off;
    }
    
    part def HydrogenSensorElement {
        doc /* Catalytic bead or electrochemical sensing element */
        
        attribute sensitivity : Real;
        attribute operatingTemperature : TemperatureValue;
        attribute heaterPower : Real;
        
        port gasInput : GasInputPort;
        port signalOutput : SensorOutputPort;
        port power : PowerSupplyPort;
        
        action sense : SenseHydrogen {
            in item gasSample = gasInput.sample;
            out item rawSignal = signalOutput.signal;
        }
        
        state lifecycle : SensorOperationalState;
    }
    
    part def SignalConditioningModule {
        doc /* Amplifies and filters raw sensor signal */
        
        attribute amplificationGain : Real;
        attribute filterCutoffFrequency : Real;
        attribute noiseThreshold : Real;
        
        port signalInput : ProcessorInputPort;
        port signalOutput : SensorOutputPort;
        
        action conditionSignal {
            in item rawSignal : RawSensorSignal;
            out item conditionedSignal : RawSensorSignal;
            
            action amplifyStep : AmplifySignal {
                in item rawSignal;
                out item amplifiedSignal;
            }
            
            flow from amplifyStep.amplifiedSignal to filterStep.amplifiedSignal;
            
            action filterStep : FilterNoise {
                in item amplifiedSignal;
                out item filteredSignal = conditionedSignal;
            }
        }
    }
    
    part def AnalogDigitalConverter {
        doc /* Converts analog voltage to digital value */
        
        attribute resolution : Integer;
        attribute samplingRate : Real;
        attribute referenceVoltage : Real;
        
        port analogInput : ProcessorInputPort;
        
        action convert : ConvertToDigital;
    }
    
    part def ProcessingModule {
        doc /* Applies calibration, temperature compensation, and validation */
        
        attribute processingRate : Real;
        
        port calibrationInput : CalibrationPort;
        port measurementOutput : MeasurementOutputPort;
        
        action processMeasurement {
            in item digitalValue : Real;
            in item calibration : CalibrationParameters;
            in item temperature : TemperatureValue;
            in item timestamp : Real;
            out item measurement : ProcessedMeasurement;
            
            action calibrate : ApplyCalibration {
                in item digitalValue;
                in item calibration;
                out item calibratedValue;
            }
            
            flow from calibrate.calibratedValue to compensate.calibratedValue;
            
            action compensate : CompensateTemperature {
                in item calibratedValue;
                in item temperature;
                in item calibration;
                out item compensatedValue;
            }
            
            flow from compensate.compensatedValue to validate.compensatedValue;
            
            action validate : ValidateMeasurement {
                in item compensatedValue;
                out item isValid;
                out item qualityFactor;
            }
            
            flow from validate.isValid to generate.isValid;
            flow from validate.qualityFactor to generate.qualityFactor;
            
            action generate : GenerateMeasurement {
                in item compensatedValue;
                in item temperature;
                in item timestamp;
                in item isValid;
                in item qualityFactor;
                out item measurement;
            }
        }
    }
    
    action def MeasureHydrogenConcentration {
        in item gasSample : GasSample;
        in item calibration : CalibrationParameters;
        out item measurement : ProcessedMeasurement;
    }
    
    part def HydrogenSensingUnit {
        doc /* Complete sensing unit for measuring hydrogen concentration */
        
        attribute serialNumber : String;
        attribute firmwareVersion : String;
        attribute measurementRange : PartsPerMillion;
        attribute accuracy : Real;
        attribute responseTime : Real;
        attribute operatingTemperatureRange : TemperatureValue;
        
        port gasInput : GasInputPort;
        port measurementOutput : MeasurementOutputPort;
        port calibrationInput : CalibrationPort;
        port powerSupply : PowerSupplyPort;
        
        part sensorElement : HydrogenSensorElement[1];
        part signalConditioner : SignalConditioningModule[1];
        part adc : AnalogDigitalConverter[1];
        part processor : ProcessingModule[1];
        
        connection sensorToConditioner 
            connect sensorElement.signalOutput to signalConditioner.signalInput;
        
        connection conditionerToADC 
            connect signalConditioner.signalOutput to adc.analogInput;
        
        connection calibrationToProcessor 
            connect calibrationInput to processor.calibrationInput;
        
        connection processorToOutput 
            connect processor.measurementOutput to measurementOutput;
        
        connection gasToSensor 
            connect gasInput to sensorElement.gasInput;
        
        connection powerToSensor 
            connect powerSupply to sensorElement.power;
        
        perform action measure : MeasureHydrogenConcentration {
            in item gasSample = gasInput.sample;
            in item calibration = calibrationInput.parameters;
            out item measurement = measurementOutput.measurement;
            
            action detectGas : SenseHydrogen {
                in item gasSample;
                out item rawSignal;
            }
            
            flow from detectGas.rawSignal to conditionSignal.rawSignal;
            
            action conditionSignal {
                in item rawSignal : RawSensorSignal;
                out item conditionedSignal : RawSensorSignal;
            }
            
            flow from conditionSignal.conditionedSignal to convertSignal.filteredSignal;
            
            action convertSignal : ConvertToDigital {
                in item filteredSignal;
                out item digitalValue;
            }
            
            flow from convertSignal.digitalValue to processData.digitalValue;
            
            action processData {
                in item digitalValue : Real;
                in item calibration : CalibrationParameters;
                out item measurement : ProcessedMeasurement;
            }
        }
        
        state operationalState : SensorOperationalState;
    }
    
    requirement def HydrogenSensingRequirements {
        doc /* Requirements for hydrogen sensing unit */
        
        requirement measurementAccuracy {
            doc /* The sensing unit shall measure hydrogen concentration with accuracy of ±3% of reading */
            subject sensingUnit : HydrogenSensingUnit;
            require constraint { sensingUnit.accuracy <= 0.03 }
        }
        
        requirement measurementRange {
            doc /* The sensing unit shall measure hydrogen concentration from 0 to 10000 ppm */
        }
        
        requirement responseTimeReq {
            doc /* The sensing unit shall provide measurement within 2 seconds of gas exposure */
        }
        
        requirement operatingTemperature {
            doc /* The sensing unit shall operate in temperature range from -20°C to 60°C */
        }
        
        requirement calibrationStability {
            doc /* The sensing unit shall maintain calibration accuracy for minimum 12 months */
        }
        
        requirement powerConsumption {
            doc /* The sensing unit shall consume less than 500 mW during continuous operation */
        }
        
        requirement outputValidity {
            doc /* The sensing unit shall indicate measurement validity and quality factor */
        }
    }
    
    part hydrogenSensingUnit : HydrogenSensingUnit {
        attribute :>> serialNumber = "H2-SENS-2025-001";
        attribute :>> firmwareVersion = "3.2.1";
        attribute :>> accuracy = 0.025;
        
        satisfy sensingRequirements : HydrogenSensingRequirements;
    }
}
