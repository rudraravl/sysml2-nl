package MagnetoresistanceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MagneticFieldStrength :> ISQ::MagneticFieldStrengthValue {
        doc /* Magnetic field strength in amperes per meter */
    }
    
    attribute def ResistanceValue :> ISQ::ResistanceValue {
        doc /* Electrical resistance in ohms */
    }
    
    attribute def VoltageValue :> ISQ::ElectricPotentialDifferenceValue {
        doc /* Voltage in volts */
    }
    
    attribute def CurrentValue :> ISQ::ElectricCurrentValue {
        doc /* Electric current in amperes */
    }
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue {
        doc /* Temperature in kelvin */
    }
    
    attribute def SensitivityCoefficient :> Real {
        doc /* Magnetoresistance sensitivity coefficient */
    }
    
    attribute def CalibrationData;
    attribute def MeasurementReady;
    attribute def PowerOn;
    attribute def PowerOff;
    
    port def MagneticFieldInputPort {
        in magneticField : MagneticFieldStrength;
    }
    
    port def ElectricalOutputPort {
        out outputVoltage : VoltageValue;
        out outputCurrent : CurrentValue;
    }
    
    port def PowerSupplyPort {
        in supplyVoltage : VoltageValue;
        in supplyCurrent : CurrentValue;
    }
    
    port def DataPort {
        out resistanceData : ResistanceValue;
        out fieldStrengthData : MagneticFieldStrength;
    }
    
    item def MagnetoresistiveMaterial {
        attribute nominalResistance : ResistanceValue;
        attribute magnetoresistanceRatio : SensitivityCoefficient;
        attribute operatingTemperature : TemperatureValue;
    }
    
    part def MagnetoresistiveElement {
        doc /* Core sensing element that changes resistance in response to magnetic field */
        
        attribute baseResistance : ResistanceValue;
        attribute currentResistance : ResistanceValue;
        attribute sensitivity : SensitivityCoefficient;
        attribute material : MagnetoresistiveMaterial;
        
        port fieldInput : MagneticFieldInputPort;
        port electricalOutput : ElectricalOutputPort;
        
        action respondToMagneticField {
            in appliedField : MagneticFieldStrength;
            in baseR : ResistanceValue;
            in sens : SensitivityCoefficient;
            out deltaResistance : ResistanceValue;
            out newResistance : ResistanceValue;
        }
    }
    
    part def BiasingCircuit {
        doc /* Provides stable current or voltage bias to magnetoresistive element */
        
        attribute biasVoltage : VoltageValue;
        attribute biasCurrent : CurrentValue;
        
        port powerIn : PowerSupplyPort;
        port biasOut : ElectricalOutputPort;
        
        action provideBias {
            in supplyV : VoltageValue;
            out biasV : VoltageValue;
            out biasI : CurrentValue;
        }
    }
    
    part def SignalConditioner {
        doc /* Amplifies and filters the resistance change signal */
        
        attribute gain : Real;
        attribute filterCutoff : ISQ::FrequencyValue;
        attribute offsetVoltage : VoltageValue;
        
        port signalIn : ElectricalOutputPort;
        port signalOut : ElectricalOutputPort;
        
        action amplifySignal {
            in inputVoltage : VoltageValue;
            in amplificationGain : Real;
            out amplifiedVoltage : VoltageValue;
        }
        
        action filterSignal {
            in rawSignal : VoltageValue;
            in cutoffFreq : ISQ::FrequencyValue;
            out filteredSignal : VoltageValue;
        }
    }
    
    part def TemperatureCompensator {
        doc /* Compensates for temperature-dependent resistance variations */
        
        attribute referenceTemp : TemperatureValue;
        attribute tempCoefficient : Real;
        
        action compensateTemperature {
            in measuredResistance : ResistanceValue;
            in currentTemp : TemperatureValue;
            in refTemp : TemperatureValue;
            in coefficient : Real;
            out compensatedResistance : ResistanceValue;
        }
    }
    
    part def AnalogToDigitalConverter {
        doc /* Converts analog voltage to digital representation */
        
        attribute resolution : Real;
        attribute samplingRate : ISQ::FrequencyValue;
        attribute referenceVoltage : VoltageValue;
        
        port analogIn : ElectricalOutputPort;
        port digitalOut : DataPort;
        
        action convertSignal {
            in analogVoltage : VoltageValue;
            in resolutionBits : Real;
            in refVoltage : VoltageValue;
            out digitalValue : Real;
        }
    }
    
    part def DataProcessor {
        doc /* Processes digital data and calculates magnetic field strength */
        
        attribute calibrationCoefficients : CalibrationData;
        
        port dataIn : DataPort;
        port dataOut : DataPort;
        
        action calculateFieldStrength {
            in resistanceValue : ResistanceValue;
            in calibration : CalibrationData;
            out fieldStrength : MagneticFieldStrength;
        }
        
        action linearizeResponse {
            in rawData : Real;
            in calibration : CalibrationData;
            out linearizedData : Real;
        }
    }
    
    state def MagnetoresistanceSensorStates {
        entry; then powerOff;
        
        state powerOff {
            doc /* System is not powered */
        }
        
        transition powerOff_to_initialization
            first powerOff
            accept powerOn : PowerOn
            then initialization;
        
        state initialization {
            doc /* System initializing and performing self-test */
            entry action initializeSystem;
            do action selfTest;
        }
        
        transition initialization_to_calibration
            first initialization
            then calibration;
        
        state calibration {
            doc /* Calibrating sensor baseline and sensitivity */
            do action performCalibration;
        }
        
        transition calibration_to_ready
            first calibration
            then ready;
        
        state ready {
            doc /* System ready to measure magnetic field */
        }
        
        transition ready_to_measuring
            first ready
            accept measurementReady : MeasurementReady
            then measuring;
        
        state measuring {
            doc /* Actively measuring magnetic field */
            entry action startMeasurement;
            do action continuousMeasurement;
        }
        
        transition measuring_to_processing
            first measuring
            then processing;
        
        state processing {
            doc /* Processing and compensating measurement data */
            do action processData;
        }
        
        transition processing_to_outputting
            first processing
            then outputting;
        
        state outputting {
            doc /* Providing measurement output */
            do action outputResults;
        }
        
        transition outputting_to_ready
            first outputting
            then ready;
        
        transition ready_to_powerOff
            first ready
            accept powerOff : PowerOff
            then powerOff;
        
        transition measuring_to_powerOff
            first measuring
            accept powerOff : PowerOff
            then powerOff;
    }
    
    action def MeasureMagneticField {
        doc /* Primary measurement action */
        
        in magneticField : MagneticFieldStrength;
        in biasVoltage : VoltageValue;
        out resistanceChange : ResistanceValue;
        out outputVoltage : VoltageValue;
    }
    
    action def ProcessMeasurement {
        doc /* Process and compensate measurement */
        
        in rawResistance : ResistanceValue;
        in temperature : TemperatureValue;
        in calibration : CalibrationData;
        out compensatedField : MagneticFieldStrength;
    }
    
    action def CalibrateSystem {
        doc /* Calibrate sensor system */
        
        in referenceField : MagneticFieldStrength;
        out calibrationData : CalibrationData;
    }
    
    part def MagnetoresistanceSensorSystem {
        doc /* 
            Complete magnetoresistance-based magnetic field sensing system.
            
            Primary Function: The system detects and measures magnetic field strength
            by exploiting the magnetoresistive effect, where the electrical resistance
            of the sensing element changes in response to an applied magnetic field.
            
            The system operates by applying a stable bias current or voltage to the
            magnetoresistive element. When exposed to a magnetic field, the element's
            resistance changes proportionally to the field strength. This resistance
            change is converted to a voltage signal, amplified, temperature-compensated,
            and digitized to produce an accurate measurement of the magnetic field.
            
            The system continuously monitors the magnetic environment and provides
            real-time field strength measurements with high sensitivity and accuracy.
        */
        
        port fieldInput : MagneticFieldInputPort;
        port powerSupply : PowerSupplyPort;
        port measurementOutput : DataPort;
        
        part mrElement : MagnetoresistiveElement {
            attribute :>> baseResistance = 1000.0;
            attribute :>> sensitivity = 0.025;
        }
        
        part biasCircuit : BiasingCircuit {
            attribute :>> biasVoltage = 5.0;
            attribute :>> biasCurrent = 0.005;
        }
        
        part conditioner : SignalConditioner {
            attribute :>> gain = 100.0;
            attribute :>> filterCutoff = 1000.0;
        }
        
        part tempComp : TemperatureCompensator {
            attribute :>> referenceTemp = 298.15;
            attribute :>> tempCoefficient = 0.004;
        }
        
        part adc : AnalogToDigitalConverter {
            attribute :>> resolution = 16.0;
            attribute :>> samplingRate = 10000.0;
            attribute :>> referenceVoltage = 5.0;
        }
        
        part processor : DataProcessor;
        
        connection fieldConnection connect fieldInput to mrElement.fieldInput;
        connection powerConnection connect powerSupply to biasCircuit.powerIn;
        connection biasConnection connect biasCircuit.biasOut to mrElement.electricalOutput;
        connection signalConnection connect mrElement.electricalOutput to conditioner.signalIn;
        connection conditionedConnection connect conditioner.signalOut to adc.analogIn;
        connection dataConnection connect adc.digitalOut to processor.dataIn;
        connection outputConnection connect processor.dataOut to measurementOutput;
        
        action detectAndMeasureField : MeasureAndProcessField {
            in appliedField : MagneticFieldStrength = fieldInput.magneticField;
            in supplyVoltage : VoltageValue = powerSupply.supplyVoltage;
            out fieldMeasurement : MagneticFieldStrength;
            
            first start;
            then action measure : MeasureMagneticField {
                in magneticField = appliedField;
                in biasVoltage = biasCircuit.biasVoltage;
                out resistanceChange;
                out outputVoltage;
            }
            then action compensate : ProcessMeasurement {
                in rawResistance = measure.resistanceChange;
                in temperature = 298.15;
                in calibration = processor.calibrationCoefficients;
                out compensatedField;
            }
            then action output {
                in fieldData = compensate.compensatedField;
                out finalMeasurement = fieldMeasurement;
            }
            then done;
        }
        
        exhibit state operationalBehavior : MagnetoresistanceSensorStates;
    }
    
    action def MeasureAndProcessField {
        doc /* Complete measurement and processing cycle */
        
        in appliedField : MagneticFieldStrength;
        in supplyVoltage : VoltageValue;
        out fieldMeasurement : MagneticFieldStrength;
    }
    
    part magnetoresistanceSystem : MagnetoresistanceSensorSystem {
        doc /* 
            Magnetoresistance-based magnetic field sensing system instance.
            
            This system provides continuous, high-precision measurement of magnetic
            field strength using the magnetoresistive effect. The primary function
            is to convert variations in magnetic field into proportional electrical
            signals that can be processed and output as digital field strength data.
        */
        
        perform action continuousSensing : MeasureAndProcessField[*] ordered;
    }
    
    requirement def <'MR-FUNC-001'> PrimaryFunctionRequirement {
        doc /* The system shall detect and measure magnetic field strength using magnetoresistive effect */
        
        subject magnetoresistanceSystem;
        
        require constraint {
            doc /* System shall convert magnetic field to resistance change */
        }
    }
    
    requirement def <'MR-PERF-001'> SensitivityRequirement {
        doc /* The system shall maintain minimum sensitivity across operating range */
        
        subject magnetoresistanceSystem;
        
        require constraint {
            doc /* Sensitivity shall be at least 2.5% resistance change per unit field strength */
        }
    }
    
    requirement def <'MR-PERF-002'> AccuracyRequirement {
        doc /* The system shall provide accurate field measurements */
        
        subject magnetoresistanceSystem;
        
        require constraint {
            doc /* Measurement accuracy shall be within ±2% of actual field strength */
        }
    }
    
    requirement def <'MR-ENV-001'> TemperatureStabilityRequirement {
        doc /* The system shall compensate for temperature variations */
        
        subject magnetoresistanceSystem;
        
        require constraint {
            doc /* Temperature drift shall not exceed 0.1% per degree Celsius */
        }
    }
    
    requirement def <'MR-OPER-001'> ResponseTimeRequirement {
        doc /* The system shall provide timely measurements */
        
        subject magnetoresistanceSystem;
        
        require constraint {
            doc /* Response time shall be less than 1 millisecond */
        }
    }
    
    requirement <'MR-SYS-001'> systemLevelRequirement {
        doc /* 
            The magnetoresistance system shall provide continuous, accurate
            magnetic field measurement with temperature compensation and
            high sensitivity across the specified operating range.
        */
        
        subject magnetoresistanceSystem;
        
        require primaryFunc : PrimaryFunctionRequirement;
        require sensitivity : SensitivityRequirement;
        require accuracy : AccuracyRequirement;
        require tempStability : TemperatureStabilityRequirement;
        require responseTime : ResponseTimeRequirement;
    }
}
