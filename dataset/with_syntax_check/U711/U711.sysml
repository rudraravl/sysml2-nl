package HumistorMonitoringSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def RelativeHumidityValue :> Real {
        doc /* Relative humidity as percentage (0-100%) */
    }
    
    attribute def ResistanceValue :> Real {
        doc /* Electrical resistance in ohms */
    }
    
    attribute def TemperatureValue :> Real {
        doc /* Temperature in degrees Celsius */
    }
    
    attribute def VoltageValue :> Real {
        doc /* Voltage in volts */
    }
    
    attribute def CurrentValue :> Real {
        doc /* Current in amperes */
    }
    
    item def HumidityReading {
        attribute humidity : RelativeHumidityValue;
        attribute temperature : TemperatureValue;
        attribute timestamp : Real;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    item def ResistanceMeasurement {
        attribute resistance : ResistanceValue;
        attribute voltage : VoltageValue;
    }
    
    port def PowerInputPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute supplyCurrent : CurrentValue;
    }
    
    port def AnalogOutputPort {
        out attribute outputVoltage : VoltageValue;
    }
    
    port def DataOutputPort {
        out item reading : HumidityReading;
    }
    
    part def Humistor {
        doc /* 
            Humidity-sensitive resistor element that exhibits resistance variation 
            proportional to ambient relative humidity changes.
        */
        
        attribute nominalResistance : ResistanceValue := 10000.0;
        attribute currentResistance : ResistanceValue;
        attribute ambientHumidity : RelativeHumidityValue;
        attribute ambientTemperature : TemperatureValue := 25.0;
        attribute sensitivityCoefficient : Real := -0.5;
        
        port powerInput : PowerInputPort;
        port analogOutput : AnalogOutputPort;
        
        action def CalculateResistance {
            in humidity : RelativeHumidityValue;
            in temperature : TemperatureValue;
            in nominalR : ResistanceValue;
            in coefficient : Real;
            out resistance : ResistanceValue;
        }
        
        perform action resistanceResponse : CalculateResistance {
            in humidity = ambientHumidity;
            in temperature = ambientTemperature;
            in nominalR = nominalResistance;
            in coefficient = sensitivityCoefficient;
            out resistance;
        }
        
        state humistorState {
            entry; then assign currentResistance := resistanceResponse.resistance;
        }
    }
    
    part def VoltageDividerCircuit {
        doc /* 
            Converts resistance changes from humistor into proportional voltage signal 
            suitable for analog-to-digital conversion.
        */
        
        attribute referenceResistance : ResistanceValue := 10000.0;
        attribute supplyVoltage : VoltageValue := 5.0;
        attribute outputVoltage : VoltageValue;
        
        port resistiveInput : ~AnalogOutputPort;
        port voltageOutput : AnalogOutputPort;
        
        action def ConvertResistanceToVoltage {
            in sensorResistance : ResistanceValue;
            in refResistance : ResistanceValue;
            in vSupply : VoltageValue;
            out vOut : VoltageValue;
        }
        
        perform action voltageConversion : ConvertResistanceToVoltage {
            in sensorResistance;
            in refResistance = referenceResistance;
            in vSupply = supplyVoltage;
            out vOut;
        }
    }
    
    part def AnalogToDigitalConverter {
        doc /* 
            Digitizes analog voltage signal with specified resolution for 
            microcontroller processing.
        */
        
        attribute resolution : Natural := 12;
        attribute referenceVoltage : VoltageValue := 5.0;
        attribute digitalValue : Natural;
        
        port analogInput : ~AnalogOutputPort;
        
        action def Digitize {
            in analogVoltage : VoltageValue;
            in refVoltage : VoltageValue;
            in bits : Natural;
            out digitalOutput : Natural;
        }
        
        perform action conversion : Digitize {
            in analogVoltage;
            in refVoltage = referenceVoltage;
            in bits = resolution;
            out digitalOutput;
        }
    }
    
    part def SignalProcessor {
        doc /* 
            Processes digitized sensor data, applies calibration algorithms, 
            and computes compensated humidity values.
        */
        
        attribute calibrationOffset : Real := 0.0;
        attribute calibrationGain : Real := 1.0;
        attribute temperatureCompensation : Real := -0.03;
        
        port dataOutput : DataOutputPort;
        
        action def CalculateHumidity {
            in digitalInput : Natural;
            in offset : Real;
            in gain : Real;
            in tempComp : Real;
            in temperature : TemperatureValue;
            out humidity : RelativeHumidityValue;
        }
        
        action def ApplyCalibration {
            in rawHumidity : RelativeHumidityValue;
            in temperature : TemperatureValue;
            in tempCompensation : Real;
            out calibratedHumidity : RelativeHumidityValue;
        }
        
        perform action processing : CalculateHumidity {
            in digitalInput;
            in offset = calibrationOffset;
            in gain = calibrationGain;
            in tempComp = temperatureCompensation;
            in temperature;
            out humidity;
        }
        
        perform action calibration : ApplyCalibration {
            in rawHumidity = processing.humidity;
            in temperature;
            in tempCompensation = temperatureCompensation;
            out calibratedHumidity;
        }
    }
    
    part def PowerRegulator {
        doc /* 
            Provides stable, regulated voltage supply to all system components 
            ensuring measurement accuracy and stability.
        */
        
        attribute inputVoltage : VoltageValue := 12.0;
        attribute regulatedVoltage : VoltageValue := 5.0;
        attribute maxOutputCurrent : CurrentValue := 0.5;
        attribute efficiency : Real := 0.85;
        
        port powerOutput : PowerInputPort;
        
        action def RegulateVoltage {
            in vIn : VoltageValue;
            in vTarget : VoltageValue;
            out vOut : VoltageValue;
            out iOut : CurrentValue;
        }
        
        perform action regulation : RegulateVoltage {
            in vIn = inputVoltage;
            in vTarget = regulatedVoltage;
            out vOut;
            out iOut;
        }
    }
    
    part def HumistorSensorSystem {
        doc /* 
            Primary function: Continuously measure and report ambient relative humidity 
            by exploiting the humidity-dependent electrical resistance characteristics 
            of the humistor sensing element.
            
            The system operates through a coordinated measurement cycle: the humistor 
            element responds to ambient humidity changes by varying its electrical 
            resistance. This resistance modulation is converted to a proportional 
            voltage signal via a precision voltage divider circuit. The analog voltage 
            is then digitized with high resolution and processed by calibration 
            algorithms that compensate for temperature effects and sensor non-linearity, 
            ultimately producing accurate, temperature-compensated humidity readings 
            suitable for environmental monitoring, HVAC control, and industrial process 
            applications.
        */
        
        attribute operatingHumidityRange : RelativeHumidityValue[2] := (10.0, 90.0);
        attribute operatingTemperatureRange : TemperatureValue[2] := (-20.0, 60.0);
        attribute measurementAccuracy : Real := 3.0;
        attribute responseTime : Real := 8.0;
        attribute samplingInterval : Real := 2.0;
        
        part humistor : Humistor;
        part voltageDivider : VoltageDividerCircuit;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        part powerSupply : PowerRegulator;
        
        connection powerToHumistor connect powerSupply.powerOutput to humistor.powerInput;
        connection humistorToVoltageDivider connect humistor.analogOutput to voltageDivider.resistiveInput;
        connection voltageDividerToADC connect voltageDivider.voltageOutput to adc.analogInput;
        
        port systemOutput : DataOutputPort;
        
        binding outputBinding bind systemOutput.reading = processor.dataOutput.reading;
        
        state systemOperation {
            entry;
            then state Initializing {
                doc /* Power-up sequence and self-test */
            }
            
            then state Stabilizing {
                doc /* Allow sensor element to reach thermal equilibrium */
            }
            
            then state OperationalLoop {
                entry;
                then state Sensing {
                    doc /* Humistor responds to ambient humidity */
                }
                
                then state Converting {
                    doc /* Voltage divider and ADC convert resistance to digital value */
                }
                
                then state Processing {
                    doc /* Apply calibration and temperature compensation */
                }
                
                then state Reporting {
                    doc /* Output calibrated humidity reading */
                }
                
                then state Waiting {
                    doc /* Delay before next measurement cycle */
                }
                
                then Sensing;
            }
        }
        
        perform action measurementCycle {
            first start;
            then merge continueMeasurement;
            then action sense {
                doc /* Humistor resistance changes with humidity */
            }
            then action convert {
                doc /* Convert resistance to voltage and digitize */
            }
            then action process {
                doc /* Calculate and calibrate humidity value */
            }
            then action output {
                doc /* Provide reading to external systems */
            }
            then continueMeasurement;
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* 
            The system shall maintain humidity measurement accuracy within 
            specified tolerance across the operating range.
        */
        
        subject system : HumistorSensorSystem;
        
        require constraint accuracyConstraint {
            system.measurementAccuracy <= 3.5
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* 
            The system shall operate reliably within specified environmental 
            humidity and temperature ranges.
        */
        
        subject system : HumistorSensorSystem;
        
        require constraint humidityRangeConstraint {
            system.operatingHumidityRange[1] >= 0.0 and
            system.operatingHumidityRange[2] <= 100.0
        }
        
        require constraint temperatureRangeConstraint {
            system.operatingTemperatureRange[1] >= -40.0 and
            system.operatingTemperatureRange[2] <= 85.0
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* 
            The system shall provide humidity measurements with response time 
            suitable for real-time monitoring applications.
        */
        
        subject system : HumistorSensorSystem;
        
        attribute maxResponseTime : Real := 10.0;
        
        require constraint responseConstraint {
            system.responseTime <= maxResponseTime
        }
    }
    
    requirement def PowerConsumptionRequirement {
        doc /* 
            The system shall operate within specified power consumption limits 
            for battery-powered and low-power applications.
        */
        
        subject system : HumistorSensorSystem;
        
        attribute maxPowerConsumption : Real := 2.5;
        
        require constraint powerConstraint {
            system.powerSupply.maxOutputCurrent * system.powerSupply.regulatedVoltage <= maxPowerConsumption
        }
    }
    
    requirement <'SYS-REQ-001'> humistorSystemRequirements {
        doc /* 
            Top-level requirements specification for humistor-based humidity 
            sensing and monitoring system.
        */
        
        subject humistorSystem : HumistorSensorSystem;
        
        require accuracyReq : MeasurementAccuracyRequirement;
        require rangeReq : OperatingRangeRequirement;
        require responseReq : ResponseTimeRequirement;
        require powerReq : PowerConsumptionRequirement;
    }
    
    part humistorSystemInstance : HumistorSensorSystem {
        :>> measurementAccuracy = 2.8;
        :>> responseTime = 7.5;
        :>> samplingInterval = 1.5;
    }
}
