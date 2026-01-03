package 'Port-Based Thermal Management System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def SensorID;
    attribute def ControlMode;
    attribute def AlarmLevel;
    
    item def ThermalReading {
        attribute sensorID : SensorID;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute timestamp : Real;
        attribute valid : Boolean;
    }
    
    item def CoolingCommand {
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute fanSpeed : Real;
        attribute pumpRate : Real;
    }
    
    item def SystemStatus {
        attribute currentTemp : ISQ::ThermodynamicTemperatureValue;
        attribute mode : ControlMode;
        attribute alarmActive : Boolean;
        attribute powerConsumption : ISQ::PowerValue;
    }
    
    port def ThermalSensorPort {
        in attribute readings : ThermalReading[*] ordered;
        out attribute calibrationSignal : Real;
        attribute sampleRate : Real;
    }
    
    port def CoolingActuatorPort {
        out attribute command : CoolingCommand;
        in attribute feedback : SystemStatus;
        attribute responseTime : ISQ::TimeValue;
    }
    
    port def MonitoringPort {
        out attribute status : SystemStatus;
        in attribute setpoint : ISQ::ThermodynamicTemperatureValue;
        out attribute diagnostics : String;
    }
    
    part def TemperatureSensor {
        attribute accuracy : Real;
        attribute currentReading : ISQ::ThermodynamicTemperatureValue;
    }
    
    part def CoolingUnit {
        attribute maxCoolingPower : ISQ::PowerValue;
        attribute efficiency : Real;
        attribute operatingState : String;
    }
    
    part def ThermalController {
        attribute controlGain : Real;
        attribute setpointTemp : ISQ::ThermodynamicTemperatureValue;
        attribute hysteresis : ISQ::ThermodynamicTemperatureValue;
    }
    
    action def ReadTemperature {
        in sensorData : ThermalReading;
        out processedTemp : ISQ::ThermodynamicTemperatureValue;
        out isValid : Boolean;
    }
    
    action def CalculateCooling {
        in currentTemp : ISQ::ThermodynamicTemperatureValue;
        in targetTemp : ISQ::ThermodynamicTemperatureValue;
        in maxPower : ISQ::PowerValue;
        out coolingPower : ISQ::PowerValue;
        out fanSpeed : Real;
    }
    
    action def ApplyCooling {
        in command : CoolingCommand;
        in unitCapacity : ISQ::PowerValue;
        out actualCooling : ISQ::PowerValue;
        out status : SystemStatus;
    }
    
    part def ThermalManagementSystem {
        doc /* 
            The Thermal Management System is a port-based control architecture 
            designed to maintain safe operating temperatures in critical equipment.
            
            Its primary function is to continuously monitor temperature through 
            sensor ports, intelligently regulate cooling systems via actuator ports, 
            and provide real-time status through monitoring ports. The system 
            receives thermal readings from multiple sensors, processes them to 
            determine the current thermal state, and dynamically adjusts cooling 
            power and flow rates to maintain temperatures within safe limits.
            
            The system operates through distinct states: normal operation with 
            minimal cooling, active cooling when temperatures rise, and emergency 
            alarm mode for critical conditions. All interactions occur through 
            well-defined ports that enable modular integration with external 
            sensors, cooling equipment, and monitoring systems.
        */
        
        port sensorInput : ThermalSensorPort {
            in attribute readings : ThermalReading[*] ordered;
            out attribute calibrationSignal = 1.0;
            attribute sampleRate = 10.0;
        }
        
        port actuatorOutput : CoolingActuatorPort {
            out attribute command : CoolingCommand;
            in attribute feedback : SystemStatus;
            attribute responseTime = 0.5;
        }
        
        port systemMonitor : MonitoringPort {
            out attribute status : SystemStatus;
            in attribute setpoint = 298.15;
            out attribute diagnostics = "System operational";
        }
        
        part sensors : TemperatureSensor[4] {
            attribute accuracy = 0.1;
            attribute currentReading = 298.15;
        }
        
        part coolingUnit : CoolingUnit {
            attribute maxCoolingPower = 5000.0;
            attribute efficiency = 0.85;
            attribute operatingState = "standby";
        }
        
        part controller : ThermalController {
            attribute controlGain = 1.5;
            attribute setpointTemp = 298.15;
            attribute hysteresis = 2.0;
        }
        
        private attribute measuredTemperature : ISQ::ThermodynamicTemperatureValue = 298.15;
        private attribute targetTemperature : ISQ::ThermodynamicTemperatureValue = 298.15;
        private attribute maxCoolingCapacity : ISQ::PowerValue = 5000.0;
        private attribute coolingActive : Boolean = false;
        private attribute alarmTriggered : Boolean = false;
        private attribute fanSpeedLevel : Real = 0.0;
        private attribute pumpRateLevel : Real = 0.0;
        private attribute coolingPowerLevel : ISQ::PowerValue = 0.0;
        
        connect sensorInput to sensors;
        connect actuatorOutput to coolingUnit;
        connect controller to coolingUnit;
        
        perform action operateThermalSystem {
            first start;
            then merge continuousControl;
            action acquireReadings {
                out averageTemp : ISQ::ThermodynamicTemperatureValue;
            }
            then continuousControl;
            action processTemperature : ReadTemperature {
                out processedTemp;
                out isValid;
            }
            action determineCooling : CalculateCooling {
                in currentTemp = processTemperature.processedTemp;
                in targetTemp = 298.15;
                in maxPower = 5000.0;
                out coolingPower;
                out fanSpeed;
            }
            action executeCooling : ApplyCooling {
                in unitCapacity = 5000.0;
                out actualCooling;
                out status;
            }
            then continuousControl;
        }
    }
    
    part thermalManagementSystem : ThermalManagementSystem;
    
    requirement <'REQ-TMS-001'> primaryFunctionRequirement {
        doc /* 
            The Thermal Management System shall continuously monitor temperature 
            through sensor ports and regulate cooling through actuator ports to 
            maintain safe operating temperatures below 323.15 K under normal 
            conditions.
        */
        
        subject thermalManagementSystem;
    }
    
    requirement <'REQ-TMS-002'> portInterfaceRequirement {
        doc /* 
            The system shall provide dedicated ports for sensor input, actuator 
            control, and system monitoring to enable modular integration with 
            external components.
        */
        
        subject thermalManagementSystem;
    }
    
    requirement <'REQ-TMS-003'> responseTimeRequirement {
        doc /* 
            The system shall respond to temperature changes exceeding the alarm 
            threshold within 0.5 seconds by activating emergency cooling mode.
        */
        
        subject thermalManagementSystem;
    }
    
    requirement <'REQ-TMS-004'> alarmThresholdRequirement {
        doc /* 
            The system shall trigger an alarm state when measured temperature 
            reaches or exceeds 343.15 K and shall activate maximum cooling power.
        */
        
        subject thermalManagementSystem;
    }
}
