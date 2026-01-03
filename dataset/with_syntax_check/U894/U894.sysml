package StrainGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def StrainValue :> Real;
    attribute def ResistanceValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def ForceValue :> Real;
    attribute def GaugeFactorValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def DigitalCountValue :> Integer;
    
    item def MechanicalLoad {
        attribute appliedForce : ForceValue;
        attribute resultingStrain : StrainValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : Real;
    }
    
    item def DigitalData {
        attribute strainReading : StrainValue;
        attribute timestamp : Real;
        attribute temperature : TemperatureValue;
    }
    
    port def MechanicalPort {
        in load : MechanicalLoad;
    }
    
    port def AnalogPort {
        out signal : ElectricalSignal;
    }
    
    port def DigitalPort {
        out data : DigitalData;
    }
    
    port def PowerPort {
        in supplyVoltage : VoltageValue;
    }
    
    part def StrainGauge {
        doc /* 
            Resistive sensor that converts mechanical strain into 
            a change in electrical resistance.
        */
        
        attribute nominalResistance : ResistanceValue = 350.0;
        attribute gaugeFactor : GaugeFactorValue = 2.1;
        attribute currentStrain : StrainValue = 0.0;
        attribute currentResistance : ResistanceValue;
        attribute operatingTemperature : TemperatureValue;
        
        port mechanicalInput : MechanicalPort;
        port electricalOutput : AnalogPort;
        
        action senseStrain {
            in mechanicalLoad : MechanicalLoad;
            out resistanceChange : ResistanceValue;
            out measuredStrain : StrainValue;
            
            action calculateStrain {
                in force : ForceValue;
                out strain : StrainValue;
            }
            
            action convertToResistance {
                in strain : StrainValue;
                in factor : GaugeFactorValue;
                in baseResistance : ResistanceValue;
                out resistance : ResistanceValue;
            }
        }
    }
    
    part def Wheatstonebridge {
        doc /* 
            Bridge circuit that converts resistance changes into 
            measurable voltage differences.
        */
        
        attribute excitationVoltage : VoltageValue = 10.0;
        attribute outputVoltage : VoltageValue = 0.0;
        attribute bridgeBalance : Real = 1.0;
        
        port gaugeConnection : ~AnalogPort;
        port voltageOutput : AnalogPort;
        port power : PowerPort;
        
        part activeGauge1 : StrainGauge;
        part activeGauge2 : StrainGauge;
        
        action measureDifferential {
            in gaugeResistance : ResistanceValue;
            in excitation : VoltageValue;
            out differentialVoltage : VoltageValue;
            
            action balanceBridge {
                in resistance : ResistanceValue;
                in referenceResistance : ResistanceValue;
                out balanceFactor : Real;
            }
            
            action calculateOutput {
                in balance : Real;
                in vExcite : VoltageValue;
                out vOut : VoltageValue;
            }
        }
    }
    
    part def SignalConditioner {
        doc /* 
            Amplifies and filters the bridge output signal for 
            optimal analog-to-digital conversion.
        */
        
        attribute amplificationGain : Real = 500.0;
        attribute lowPassCutoff : Real = 1000.0;
        attribute highPassCutoff : Real = 0.1;
        
        port analogInput : ~AnalogPort;
        port analogOutput : AnalogPort;
        port power : PowerPort;
        
        action conditionSignal {
            in rawSignal : ElectricalSignal;
            out conditionedSignal : ElectricalSignal;
            
            action amplify {
                in inputVoltage : VoltageValue;
                in gain : Real;
                out amplifiedVoltage : VoltageValue;
            }
            
            action filterLowFrequency {
                in signal : VoltageValue;
                in cutoff : Real;
                out filteredSignal : VoltageValue;
            }
            
            action filterHighFrequency {
                in signal : VoltageValue;
                in cutoff : Real;
                out cleanSignal : VoltageValue;
            }
            
            action compensateTemperature {
                in voltage : VoltageValue;
                out compensatedVoltage : VoltageValue;
            }
        }
    }
    
    part def AnalogToDigitalConverter {
        doc /* 
            Converts conditioned analog voltage to digital counts 
            for processing.
        */
        
        attribute resolution : Integer = 24;
        attribute samplingRate : Real = 10000.0;
        attribute referenceVoltage : VoltageValue = 5.0;
        
        port analogIn : ~AnalogPort;
        port digitalOut : DigitalPort;
        port power : PowerPort;
        
        action convertToDigital {
            in analogSignal : ElectricalSignal;
            out digitalCount : DigitalCountValue;
            
            action sampleSignal {
                in signal : ElectricalSignal;
                in rate : Real;
                out sampledVoltage : VoltageValue;
            }
            
            action quantize {
                in voltage : VoltageValue;
                in bits : Integer;
                in vRef : VoltageValue;
                out count : DigitalCountValue;
            }
        }
    }
    
    part def DataProcessor {
        doc /* 
            Processes digital counts to compute calibrated strain values 
            with temperature compensation.
        */
        
        attribute calibrationFactor : Real = 1.05;
        attribute temperatureCoefficient : Real = 0.000011;
        attribute zeroOffset : DigitalCountValue = 0;
        
        port digitalInput : ~DigitalPort;
        port dataOutput : DigitalPort;
        
        action processStrainData {
            in rawCount : DigitalCountValue;
            in temperature : TemperatureValue;
            out calibratedStrain : StrainValue;
            
            action applyZeroOffset {
                in count : DigitalCountValue;
                in offset : DigitalCountValue;
                out adjustedCount : DigitalCountValue;
            }
            
            action convertToStrain {
                in count : DigitalCountValue;
                out strain : StrainValue;
            }
            
            action applyCalibration {
                in strain : StrainValue;
                in factor : Real;
                out correctedStrain : StrainValue;
            }
            
            action compensateTemperature {
                in strain : StrainValue;
                in temp : TemperatureValue;
                in coefficient : Real;
                out finalStrain : StrainValue;
            }
            
            action filterNoise {
                in strainData : StrainValue;
                out cleanStrain : StrainValue;
            }
        }
    }
    
    part strainMeasurementSystem {
        doc /* 
            Complete strain gauge measurement system that detects mechanical 
            deformation in structures by converting minute changes in resistance 
            into calibrated digital strain readings. The system continuously 
            monitors structural loads, processes signals through multiple stages 
            of conditioning and conversion, and outputs precise strain measurements 
            for structural health monitoring, load testing, and stress analysis 
            applications.
        */
        
        part sensor : StrainGauge;
        part bridge : Wheatstonebridge;
        part conditioner : SignalConditioner;
        part adc : AnalogToDigitalConverter;
        part processor : DataProcessor;
        
        connection sensorToBridge connect sensor.electricalOutput to bridge.gaugeConnection;
        connection bridgeToConditioner connect bridge.voltageOutput to conditioner.analogInput;
        connection conditionerToADC connect conditioner.analogOutput to adc.analogIn;
        connection adcToProcessor connect adc.digitalOut to processor.digitalInput;
    }
    
    state def SystemOperationalStates {
        entry; then idle;
        
        state idle;
        state calibrating;
        state measuring;
        state fault;
        
        transition idle to calibrating
            accept startCalibration;
        
        transition calibrating to measuring
            accept calibrationComplete;
        
        transition measuring to idle
            accept stopMeasurement;
        
        transition measuring to fault
            accept sensorError;
        
        transition fault to idle
            accept systemReset;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* Defines accuracy requirements for strain measurement */
        subject system;
        require constraint {
            doc /* Measurement error shall not exceed ±0.05% of full scale */
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* Defines system response time requirements */
        subject system;
        require constraint {
            doc /* System shall provide strain readings within 0.5 milliseconds */
        }
    }
    
    requirement def TemperatureStabilityRequirement {
        doc /* Defines temperature compensation requirements */
        subject system;
        require constraint {
            doc /* System shall maintain accuracy over -40°C to +150°C range */
        }
    }
    
    requirement def ResolutionRequirement {
        doc /* Defines minimum measurement resolution */
        subject system;
        require constraint {
            doc /* System shall resolve strain changes of 1 microstrain or better */
        }
    }
    
    requirement <'SG-SYS-001'> primarySystemRequirements {
        doc /* 
            Primary functional and performance requirements for the 
            strain gauge measurement system.
        */
        
        require accuracyReq : MeasurementAccuracyRequirement {
            subject system = strainMeasurementSystem;
        }
        
        require responseReq : ResponseTimeRequirement {
            subject system = strainMeasurementSystem;
        }
        
        require temperatureReq : TemperatureStabilityRequirement {
            subject system = strainMeasurementSystem;
        }
        
        require resolutionReq : ResolutionRequirement {
            subject system = strainMeasurementSystem;
        }
    }
}
