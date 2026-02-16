package NetRadiometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IrradianceValue :> ISQ::PowerValue {
        attribute :>> num : Real;
    }
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue {
        attribute :>> num : Real;
    }
    
    attribute def VoltageValue :> ISQ::VoltageValue {
        attribute :>> num : Real;
    }
    
    item def RadiationData {
        attribute downwardIrradiance : IrradianceValue;
        attribute upwardIrradiance : IrradianceValue;
        attribute netIrradiance : IrradianceValue;
        attribute sensorTemperature : TemperatureValue;
        attribute timestamp : ISQ::TimeValue;
    }
    
    item def SensorSignal {
        attribute voltage : VoltageValue;
        attribute temperature : TemperatureValue;
    }
    
    port def SensorOutputPort {
        out signal : SensorSignal;
    }
    
    port def ProcessorInputPort {
        in upperSignal : SensorSignal;
        in lowerSignal : SensorSignal;
    }
    
    port def DataOutputPort {
        out radiationData : RadiationData;
    }
    
    part def UpperPyrgeometer {
        doc /* Measures downward longwave radiation from the sky */
        port output : SensorOutputPort;
        attribute sensitivity : Real;
        attribute bodyTemperature : TemperatureValue;
        
        action measureDownward {
            out sensorSignal : SensorSignal;
        }
    }
    
    part def LowerPyrgeometer {
        doc /* Measures upward longwave radiation from the surface */
        port output : SensorOutputPort;
        attribute sensitivity : Real;
        attribute bodyTemperature : TemperatureValue;
        
        action measureUpward {
            out sensorSignal : SensorSignal;
        }
    }
    
    part def SignalProcessor {
        doc /* Converts sensor voltages to irradiance values and computes net radiation */
        port input : ProcessorInputPort;
        port output : DataOutputPort;
        
        attribute calibrationFactorUpper : Real;
        attribute calibrationFactorLower : Real;
        
        action processSignals {
            in upperSignal : SensorSignal;
            in lowerSignal : SensorSignal;
            out radiationData : RadiationData;
        }
    }
    
    part def DataLogger {
        doc /* Stores and outputs radiation measurements */
        port dataInput : DataOutputPort;
        port dataOutput : DataOutputPort;
        
        attribute measurementHistory : RadiationData[*];
        attribute samplingInterval : ISQ::TimeValue;
        
        action logData {
            in measurement : RadiationData;
        }
    }
    
    part def PowerSupply {
        doc /* Provides regulated power to all system components */
        attribute outputVoltage : VoltageValue;
        attribute outputCurrent : ISQ::ElectricCurrentValue;
        
        action supplyPower;
    }
    
    action def ConvertVoltageToIrradiance {
        in voltage : VoltageValue;
        in temperature : TemperatureValue;
        in calibrationFactor : Real;
        out irradiance : IrradianceValue;
    }
    
    action def ComputeNetRadiation {
        in downwardIrradiance : IrradianceValue;
        in upwardIrradiance : IrradianceValue;
        out netIrradiance : IrradianceValue;
    }
    
    action def ValidateMeasurement {
        in measurement : RadiationData;
        out isValid : Boolean;
    }
    
    requirement def AccuracyRequirement {
        doc /* The net radiometer shall measure net radiation with accuracy within ±10 W/m² */
        
        attribute maxError : Real;
    }
    
    requirement def MeasurementRangeRequirement {
        doc /* The instrument shall measure radiation flux from -250 to +1500 W/m² */
        
        attribute minRange : Real;
        attribute maxRange : Real;
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall achieve 95% response within 10 seconds */
        
        attribute maxResponseTime : Real;
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for net radiometer system */
        
        require accuracy : AccuracyRequirement;
        require measurementRange : MeasurementRangeRequirement;
        require responseTime : ResponseTimeRequirement;
    }
    
    part netRadiometer {
        doc /* 
        A net radiometer measures the balance between incoming and outgoing radiation 
        at a surface. The system uses two pyrgeometers mounted back-to-back to 
        simultaneously measure downward radiation from the sky and upward radiation 
        from the surface, then computes the net radiation flux as the difference 
        between these two components.
        */
        
        part upperSensor : UpperPyrgeometer {
            perform upperSensor.measureDownward;
        }
        
        part lowerSensor : LowerPyrgeometer {
            perform lowerSensor.measureUpward;
        }
        
        part processor : SignalProcessor {
            perform processor.processSignals;
        }
        
        part logger : DataLogger {
            perform logger.logData[*] ordered;
        }
        
        part power : PowerSupply {
            perform power.supplyPower;
        }
        
        connect upperSensor.output to processor.input;
        connect lowerSensor.output to processor.input;
        connect processor.output to logger.dataInput;
        
        action measureNetRadiation {
            first start;
            
            then action initialize {
                action warmUpSensors;
                action calibrateSystem;
            }
            
            then merge continuousMeasurement;
            
            then action acquireData {
                action readUpperSensor {
                    out downwardSignal : SensorSignal;
                }
                
                action readLowerSensor {
                    out upwardSignal : SensorSignal;
                }
            }
            
            then action convertSignals {
                action convertDownward : ConvertVoltageToIrradiance {
                    in voltage;
                    in temperature;
                    in calibrationFactor;
                    out irradiance;
                }
                
                action convertUpward : ConvertVoltageToIrradiance {
                    in voltage;
                    in temperature;
                    in calibrationFactor;
                    out irradiance;
                }
            }
            
            then action calculateNet : ComputeNetRadiation {
                in downwardIrradiance;
                in upwardIrradiance;
                out netIrradiance;
            }
            
            then action validate : ValidateMeasurement {
                in measurement : RadiationData;
                out isValid : Boolean;
            }
            
            then decide;
                if validate.isValid then storeData;
                if not validate.isValid then continuousMeasurement;
            
            action storeData {
                in validMeasurement : RadiationData;
            }
            
            then action outputData {
                out finalMeasurement : RadiationData;
            }
            
            then continuousMeasurement;
        }
        
        state operationalStates {
            entry; then idle;
            
            state idle {
                doc /* System powered but not measuring */
            }
            
            state measuring {
                entry; then acquiring;
                
                state acquiring {
                    doc /* Reading sensor voltages and temperatures */
                }
                
                state converting {
                    doc /* Converting voltages to irradiance values */
                }
                
                state computing {
                    doc /* Calculating net radiation */
                }
                
                state validating {
                    doc /* Checking measurement validity */
                }
                
                state storing {
                    doc /* Logging measurement data */
                }
                
                transition acquiringToConverting
                    first acquiring
                    then converting;
                
                transition convertingToComputing
                    first converting
                    then computing;
                
                transition computingToValidating
                    first computing
                    then validating;
                
                transition validatingToStoring
                    first validating
                    then storing;
                
                transition storingToAcquiring
                    first storing
                    then acquiring;
            }
            
            transition idleToMeasuring
                first idle
                then measuring;
            
            transition measuringToIdle
                first measuring
                then idle;
        }
        
        satisfy systemRequirements;
    }
}
