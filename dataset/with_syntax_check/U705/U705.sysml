package 'Hall Probe Magnetometer System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MagneticFluxDensityValue :> ISQ::MagneticFluxDensityValue;
    attribute def HallVoltageValue :> ISQ::VoltageValue;
    attribute def BiasCurrentValue :> ISQ::ElectricCurrentValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def SensitivityValue :> Real;
    attribute def ResistanceValue :> Real;
    
    attribute def CalibrationData {
        attribute offsetVoltage : HallVoltageValue;
        attribute sensitivityCoefficient : SensitivityValue;
        attribute temperatureCoefficient : Real;
    }
    
    item def DigitalMeasurement {
        attribute rawValue : Integer;
        attribute timestamp : Real;
        attribute validFlag : Boolean;
    }
    
    port def MagneticFieldPort {
        in exposedField : MagneticFluxDensityValue;
    }
    
    port def HallVoltagePort {
        out hallVoltage : HallVoltageValue;
    }
    
    port def BiasCurrentPort {
        in biasCurrent : BiasCurrentValue;
    }
    
    port def DigitalDataPort {
        out digitalData : DigitalMeasurement;
    }
    
    port def FieldOutputPort {
        out measuredField : MagneticFluxDensityValue;
    }
    
    part def HallElement {
        doc /* Semiconductor element that generates Hall voltage proportional to magnetic field */
        
        attribute hallCoefficient : Real;
        attribute elementThickness : ISQ::LengthValue;
        attribute carrierDensity : Real;
        
        port fieldInput : MagneticFieldPort;
        port currentInput : BiasCurrentPort;
        port voltageOutput : HallVoltagePort;
        
        action generateHallVoltage {
            in magneticField : MagneticFluxDensityValue;
            in current : BiasCurrentValue;
            out voltage : HallVoltageValue;
        }
    }
    
    part def BiasCurrentSource {
        doc /* Provides stable bias current to Hall element */
        
        attribute nominalCurrent : BiasCurrentValue;
        attribute currentStability : Real;
        attribute temperatureDrift : Real;
        
        port currentOutput : BiasCurrentPort;
        
        action supplyCurrent {
            out current : BiasCurrentValue;
        }
    }
    
    part def SignalAmplifier {
        doc /* Amplifies weak Hall voltage to measurable level */
        
        attribute gain : Real;
        attribute inputImpedance : ResistanceValue;
        attribute bandwidth : ISQ::FrequencyValue;
        
        port voltageInput {
            in inputVoltage : HallVoltageValue;
        }
        
        port amplifiedOutput {
            out outputVoltage : HallVoltageValue;
        }
        
        action amplify {
            in vin : HallVoltageValue;
            out vout : HallVoltageValue;
        }
    }
    
    part def NoiseFilter {
        doc /* Filters high-frequency noise from amplified signal */
        
        attribute cutoffFrequency : ISQ::FrequencyValue;
        attribute filterOrder : Integer;
        
        port signalInput {
            in noisySignal : HallVoltageValue;
        }
        
        port filteredOutput {
            out cleanSignal : HallVoltageValue;
        }
        
        action filterSignal {
            in inputSignal : HallVoltageValue;
            out outputSignal : HallVoltageValue;
        }
    }
    
    part def AnalogDigitalConverter {
        doc /* Converts analog voltage to digital representation */
        
        attribute resolution : Integer;
        attribute samplingRate : ISQ::FrequencyValue;
        attribute referenceVoltage : HallVoltageValue;
        
        port analogInput {
            in analogVoltage : HallVoltageValue;
        }
        
        port digitalOutput : DigitalDataPort;
        
        action convertToDigital {
            in analog : HallVoltageValue;
            out digital : DigitalMeasurement;
        }
    }
    
    part def MicroprocessorUnit {
        doc /* Processes digital data and applies calibration */
        
        attribute calibration : CalibrationData;
        attribute processingRate : ISQ::FrequencyValue;
        
        port dataInput : DigitalDataPort;
        port fieldOutput : FieldOutputPort;
        
        action processData {
            in digitalInput : DigitalMeasurement;
            in calibrationData : CalibrationData;
            out fieldValue : MagneticFluxDensityValue;
        }
        
        action applyCalibration {
            in rawMeasurement : DigitalMeasurement;
            out calibratedValue : MagneticFluxDensityValue;
        }
        
        action compensateTemperature {
            in measurement : MagneticFluxDensityValue;
            in temperature : TemperatureValue;
            out compensatedValue : MagneticFluxDensityValue;
        }
    }
    
    part def TemperatureSensor {
        doc /* Monitors temperature for compensation */
        
        attribute accuracy : TemperatureValue;
        
        port temperatureOutput {
            out temperature : TemperatureValue;
        }
        
        action measureTemperature {
            out temp : TemperatureValue;
        }
    }
    
    part def DisplayInterface {
        doc /* Displays measured magnetic field to user */
        
        attribute updateRate : ISQ::FrequencyValue;
        attribute displayPrecision : Integer;
        
        port fieldInput : FieldOutputPort;
        
        action displayField {
            in field : MagneticFluxDensityValue;
        }
    }
    
    action def MeasureMagneticField {
        doc /* Complete measurement cycle from field exposure to output */
        
        in exposedField : MagneticFluxDensityValue;
        out measuredField : MagneticFluxDensityValue;
    }
    
    action def CalibrateSensor {
        doc /* Calibration procedure using known reference fields */
        
        in referenceFields : MagneticFluxDensityValue[*];
        out calibrationCoefficients : CalibrationData;
    }
    
    part def HallProbeMagnetometer {
        doc /* 
        Hall probe magnetometer system for precision magnetic field measurement.
        Uses Hall effect to convert magnetic flux density into measurable voltage,
        processes signal through amplification and filtering, digitizes the result,
        and applies calibration to produce accurate field measurements.
        */
        
        attribute operatingRange {
            attribute minField : MagneticFluxDensityValue;
            attribute maxField : MagneticFluxDensityValue;
        }
        attribute systemAccuracy : Real;
        
        part hallSensor : HallElement;
        part currentSource : BiasCurrentSource;
        part amplifier : SignalAmplifier;
        part filter : NoiseFilter;
        part adc : AnalogDigitalConverter;
        part processor : MicroprocessorUnit;
        part tempSensor : TemperatureSensor;
        part display : DisplayInterface;
        
        port systemFieldInput : MagneticFieldPort;
        port systemFieldOutput : FieldOutputPort;
        
        action continuousMeasurement {
            first start;
            then merge measurementLoop;
            then action supplyBias {
                perform currentSource.supplyCurrent;
            }
            then action sense {
                perform hallSensor.generateHallVoltage;
            }
            then action condition {
                action amp {
                    perform amplifier.amplify;
                }
                then action filt {
                    perform filter.filterSignal;
                }
            }
            then action convert {
                perform adc.convertToDigital;
            }
            then action compute {
                action calib {
                    perform processor.applyCalibration;
                }
                then action tempComp {
                    perform processor.compensateTemperature;
                }
            }
            then action show {
                perform display.displayField;
            }
            then measurementLoop;
        }
    }
    
    part hallProbeMagnetometer : HallProbeMagnetometer {
        doc /* Complete Hall probe magnetometer system */
        
        :>> operatingRange {
            :>> minField = -2.0 [SI::T];
            :>> maxField = 2.0 [SI::T];
        }
        
        :>> systemAccuracy = 0.01;
        
        :>> hallSensor {
            :>> hallCoefficient = 1.25e-10;
            :>> elementThickness = 0.0001 [SI::m];
            :>> carrierDensity = 1.0e22;
        }
        
        :>> currentSource {
            :>> nominalCurrent = 0.005 [SI::A];
            :>> currentStability = 0.0001;
            :>> temperatureDrift = 0.00005;
        }
        
        :>> amplifier {
            :>> gain = 100.0;
            :>> inputImpedance = 1.0e6;
            :>> bandwidth = 10000.0 [SI::Hz];
        }
        
        :>> filter {
            :>> cutoffFrequency = 1000.0 [SI::Hz];
            :>> filterOrder = 4;
        }
        
        :>> adc {
            :>> resolution = 16;
            :>> samplingRate = 5000.0 [SI::Hz];
            :>> referenceVoltage = 5.0 [SI::V];
        }
        
        :>> processor {
            :>> calibration {
                :>> offsetVoltage = 0.0 [SI::V];
                :>> sensitivityCoefficient = 0.05;
                :>> temperatureCoefficient = 0.0002;
            }
            :>> processingRate = 10000.0 [SI::Hz];
        }
        
        :>> tempSensor {
            :>> accuracy = 0.1 [SI::K];
        }
        
        :>> display {
            :>> updateRate = 10.0 [SI::Hz];
            :>> displayPrecision = 4;
        }
        
        connect currentSource.currentOutput to hallSensor.currentInput;
        connect hallSensor.voltageOutput to amplifier.voltageInput;
        connect amplifier.amplifiedOutput to filter.signalInput;
        connect filter.filteredOutput to adc.analogInput;
        connect adc.digitalOutput to processor.dataInput;
        connect processor.fieldOutput to display.fieldInput;
        connect processor.fieldOutput to systemFieldOutput;
    }
    
    requirement <'REQ-001'> primaryFunctionRequirement {
        doc /* 
        The Hall probe magnetometer system shall measure magnetic flux density
        by exploiting the Hall effect to generate a voltage proportional to the
        applied magnetic field, then condition, digitize, and process this signal
        to provide accurate digital measurements of magnetic field strength.
        */
        
        subject hallProbeMagnetometer;
    }
    
    requirement <'REQ-002'> measurementRangeRequirement {
        doc /* 
        The system shall measure magnetic flux density over the range
        of -2.0 T to +2.0 T.
        */
        
        subject hallProbeMagnetometer;
        
        require constraint {
            hallProbeMagnetometer.operatingRange.minField >= -2.0 [SI::T]
        }
        
        require constraint {
            hallProbeMagnetometer.operatingRange.maxField <= 2.0 [SI::T]
        }
    }
    
    requirement <'REQ-003'> accuracyRequirement {
        doc /* 
        The system shall provide magnetic field measurements with
        accuracy better than 1% of full scale.
        */
        
        subject hallProbeMagnetometer;
        
        require constraint {
            hallProbeMagnetometer.systemAccuracy <= 0.01
        }
    }
    
    requirement <'REQ-004'> resolutionRequirement {
        doc /* 
        The system shall provide measurement resolution of at least
        0.1 mT (millitesla).
        */
        
        subject hallProbeMagnetometer;
        
        require constraint {
            hallProbeMagnetometer.adc.resolution >= 16
        }
    }
    
    requirement <'REQ-005'> responseTimeRequirement {
        doc /* 
        The system shall provide updated magnetic field measurements
        at a rate of at least 100 Hz.
        */
        
        subject hallProbeMagnetometer;
        
        require constraint {
            hallProbeMagnetometer.adc.samplingRate >= 100.0 [SI::Hz]
        }
    }
    
    requirement <'REQ-006'> temperatureCompensationRequirement {
        doc /* 
        The system shall compensate for temperature variations to maintain
        accuracy over the operating temperature range.
        */
        
        subject hallProbeMagnetometer;
        
        assume constraint {
            hallProbeMagnetometer.tempSensor.accuracy <= 0.5 [SI::K]
        }
    }
    
    requirement <'REQ-007'> systemLevelRequirement {
        doc /* 
        The Hall probe magnetometer system shall provide continuous,
        accurate measurement of magnetic flux density with appropriate
        signal conditioning and temperature compensation.
        */
        
        subject hallProbeMagnetometer;
        
        require primaryFunctionRequirement;
        require measurementRangeRequirement;
        require accuracyRequirement;
        require resolutionRequirement;
        require responseTimeRequirement;
        require temperatureCompensationRequirement;
    }
}
