package EngineCoolantTemperatureSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::DateTime;
    
    item def Coolant {
        attribute temperature : TemperatureValue;
        attribute flowRate : Real;
        attribute pressure : Real;
    }
    
    item def TemperatureSignal {
        attribute voltage : Real;
        attribute timestamp : DateTime;
        attribute valid : Boolean;
    }
    
    port def CoolantInterfacePort {
        in item coolantFlow : Coolant;
        attribute exposedTemperature : TemperatureValue;
    }
    
    port def SignalOutputPort {
        out item signal : TemperatureSignal;
        attribute outputVoltage : Real;
    }
    
    port def PowerInputPort {
        in attribute supplyVoltage : Real;
        in attribute ground : Real;
    }
    
    part def ThermistorElement {
        doc /* Negative Temperature Coefficient thermistor sensing element */
        
        attribute resistance : Real;
        attribute nominalResistance : Real;
        attribute nominalTemperature : TemperatureValue;
        attribute betaCoefficient : Real;
        
        action calculateResistance {
            in measuredTemp : TemperatureValue;
            out resultResistance : Real;
        }
    }
    
    part def SignalConditioningCircuit {
        doc /* Converts thermistor resistance to calibrated voltage signal */
        
        attribute referenceVoltage : Real;
        attribute dividerResistance : Real;
        
        port resistanceInput {
            in attribute thermistorResistance : Real;
        }
        
        port voltageOutput {
            out attribute conditionedVoltage : Real;
        }
        
        action convertResistanceToVoltage {
            in resistance : Real;
            in refVoltage : Real;
            out outputVoltage : Real;
        }
    }
    
    part def EngineCoolantTemperatureSensor {
        doc /* 
         * Engine coolant temperature sensor using thermistor technology.
         * Measures coolant temperature and outputs proportional voltage signal.
         */
        
        attribute sensorIdentifier : String;
        attribute calibrationDate : DateTime;
        attribute measurementRangeMin : TemperatureValue;
        attribute measurementRangeMax : TemperatureValue;
        attribute measurementAccuracy : TemperatureValue;
        attribute responseTime : Real;
        
        port coolantInterface : CoolantInterfacePort;
        port signalOutput : SignalOutputPort;
        port powerInput : PowerInputPort;
        
        part sensingElement : ThermistorElement {
            attribute :>> nominalResistance = 2500.0;
            attribute :>> betaCoefficient = 3950.0;
        }
        
        part signalConditioner : SignalConditioningCircuit {
            attribute :>> referenceVoltage = 5.0;
            attribute :>> dividerResistance = 2200.0;
        }
        
        part housingAssembly {
            attribute material : String = "brass";
            attribute threadSpecification : String = "M12x1.5";
            attribute sealingType : String = "O-ring";
        }
        
        part electricalConnector {
            attribute connectorType : String = "2-pin weatherproof";
            attribute pinConfiguration : Integer = 2;
        }
        
        connection thermistorConnection 
            connect sensingElement to signalConditioner.resistanceInput;
        
        flow signalFlow 
            from signalConditioner.voltageOutput.conditionedVoltage 
            to signalOutput.outputVoltage;
        
        action def initializeSensor {
            doc /* Perform sensor initialization and self-test */
        }
        
        action def beginMeasurement;
        
        action def measureTemperature {
            in coolantTemp : TemperatureValue;
            out resistance : Real;
        }
        
        action def convertSignal {
            in resistance : Real;
            out voltage : Real;
        }
        
        action def outputSignal {
            out signal : TemperatureSignal;
        }
        
        action def logFault;
        
        state sensorStateMachine {
            entry initializeSensor;
            
            state Idle {
                doc /* Sensor ready but not actively measuring */
            }
            
            state Active {
                entry beginMeasurement;
                
                state Sensing {
                    entry measureTemperature;
                }
                
                transition SensingToConverting
                    first Sensing
                    accept MeasurementComplete
                    then Converting;
                
                state Converting {
                    entry convertSignal;
                }
                
                transition ConvertingToTransmitting
                    first Converting
                    accept ConversionComplete
                    then Transmitting;
                
                state Transmitting {
                    entry outputSignal;
                }
                
                transition TransmittingToSensing
                    first Transmitting
                    accept TransmissionComplete
                    then Sensing;
            }
            
            state Fault {
                entry logFault;
                
                state OpenCircuit {
                    doc /* Detected open circuit condition */
                }
                
                state ShortCircuit {
                    doc /* Detected short circuit condition */
                }
                
                state OutOfRange {
                    doc /* Temperature exceeds valid measurement range */
                }
            }
            
            transition idleToActive
                first Idle
                accept StartMeasurement
                then Active;
            
            transition activeToFault
                first Active
                accept FaultCondition
                then Fault;
            
            transition faultToIdle
                first Fault
                accept Reset
                then Idle;
        }
    }
    
    part def CoolantCircuit {
        doc /* Engine coolant circulation system */
        
        attribute systemPressure : Real;
        attribute coolantVolume : Real;
        attribute coolantType : String;
        
        port coolantOutput {
            out item coolant : Coolant;
        }
    }
    
    part def EngineControlModule {
        doc /* Electronic control unit processing temperature data */
        
        port temperatureInput {
            in item temperatureSignal : TemperatureSignal;
        }
        
        attribute currentTemperature : TemperatureValue;
        
        action processTemperatureSignal {
            in signal : TemperatureSignal;
            out temperature : TemperatureValue;
        }
        
        action adjustFuelInjection {
            in coolantTemp : TemperatureValue;
            out injectionTiming : Real;
        }
        
        action controlCoolingFan {
            in coolantTemp : TemperatureValue;
            out fanDutyCycle : Real;
        }
        
        action detectOverheating {
            in coolantTemp : TemperatureValue;
            out warningActive : Boolean;
        }
    }
    
    part sensingUnit {
        doc /* 
         * Complete engine coolant temperature sensing unit assembly.
         * Integrates sensor, coolant interface, and control module interface.
         */
        
        part coolantSystem : CoolantCircuit {
            attribute :>> systemPressure = 1.4;
            attribute :>> coolantVolume = 9.5;
            attribute :>> coolantType = "ethylene glycol mixture";
        }
        
        part temperatureSensor : EngineCoolantTemperatureSensor {
            attribute :>> sensorIdentifier = "ECT-SU-001";
            attribute :>> responseTime = 4.5;
        }
        
        part controlModule : EngineControlModule;
        
        connection coolantConnection 
            connect coolantSystem.coolantOutput.coolant 
            to temperatureSensor.coolantInterface.coolantFlow;
        
        flow temperatureDataFlow 
            of TemperatureSignal
            from temperatureSensor.signalOutput.signal 
            to controlModule.temperatureInput.temperatureSignal;
    }
    
    requirement def AccuracyRequirement {
        doc /* Sensor shall measure temperature within specified accuracy */
        
        subject sensor : EngineCoolantTemperatureSensor;
        
        attribute maxAccuracyError : TemperatureValue;
    }
    
    requirement def MeasurementRangeRequirement {
        doc /* Sensor shall operate across full engine temperature range */
        
        subject sensor : EngineCoolantTemperatureSensor;
        
        attribute requiredMinTemp : TemperatureValue;
        attribute requiredMaxTemp : TemperatureValue;
    }
    
    requirement def ResponseTimeRequirement {
        doc /* Sensor shall respond to temperature changes within time limit */
        
        subject sensor : EngineCoolantTemperatureSensor;
        
        attribute maxResponseTime : Real;
    }
    
    requirement def ReliabilityRequirement {
        doc /* Sensor shall maintain accuracy over operational lifetime */
        
        attribute minimumOperatingHours : Real = 10000.0;
        attribute maximumDrift : TemperatureValue;
    }
    
    requirement sensingUnitRequirements {
        doc /* Complete requirements specification for sensing unit */
        
        requirement accuracyReq : AccuracyRequirement {
            subject sensor = sensingUnit.temperatureSensor;
        }
        
        requirement rangeReq : MeasurementRangeRequirement {
            subject sensor = sensingUnit.temperatureSensor;
        }
        
        requirement responseReq : ResponseTimeRequirement {
            subject sensor = sensingUnit.temperatureSensor;
        }
        
        requirement reliabilityReq : ReliabilityRequirement;
    }
}
