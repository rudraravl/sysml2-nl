package 'HVAC Control System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityValue :> Real;
    attribute def AirFlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def PowerValue :> ISQ::PowerValue;
    
    item def TemperatureSetpoint {
        attribute target : TemperatureValue;
        attribute deadband : TemperatureValue;
    }
    
    item def ClimateReading {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
    }
    
    item def ControlSignal {
        attribute heatingDemand : Real;
        attribute coolingDemand : Real;
        attribute fanSpeed : Real;
    }
    
    port def SensorPort {
        out reading : ClimateReading;
    }
    
    port def SetpointPort {
        in setpoint : TemperatureSetpoint;
    }
    
    port def ControlOutputPort {
        out signal : ControlSignal;
    }
    
    port def ActuatorInputPort {
        in command : Real;
    }
    
    part def TemperatureSensor {
        port output : SensorPort;
        attribute accuracy : TemperatureValue;
    }
    
    part def HumiditySensor {
        port output : SensorPort;
        attribute accuracy : HumidityValue;
    }
    
    part def Thermostat {
        port sensorInput : ~SensorPort;
        port setpointInput : SetpointPort;
        port controlOutput : ControlOutputPort;
        
        attribute currentTemp : TemperatureValue;
        attribute targetTemp : TemperatureValue;
        
        perform action regulateClimate : RegulateClimate;
    }
    
    part def Furnace {
        port commandInput : ActuatorInputPort;
        attribute maxHeatingPower : PowerValue;
        attribute currentPower : PowerValue;
    }
    
    part def AirConditioner {
        port commandInput : ActuatorInputPort;
        attribute maxCoolingPower : PowerValue;
        attribute currentPower : PowerValue;
    }
    
    part def Blower {
        port commandInput : ActuatorInputPort;
        attribute maxAirFlow : AirFlowRateValue;
        attribute currentAirFlow : AirFlowRateValue;
    }
    
    part def Damper {
        attribute position : Real;
    }
    
    part def Ductwork {
        attribute length : ISQ::LengthValue;
        attribute crossSection : ISQ::AreaValue;
    }
    
    action def ReadSensors {
        out temperature : TemperatureValue;
        out humidity : HumidityValue;
    }
    
    action def ComputeControlAction {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        in deadband : TemperatureValue;
        out controlCmd : ControlSignal;
    }
    
    action def ActivateHeating {
        in demand : Real;
        out power : PowerValue;
    }
    
    action def ActivateCooling {
        in demand : Real;
        out power : PowerValue;
    }
    
    action def ModulateFan {
        in speed : Real;
        out airFlow : AirFlowRateValue;
    }
    
    action def RegulateClimate {
        first start;
        then merge controlCycle;
        
        then action readSensors : ReadSensors {
            out currentTemperature : TemperatureValue;
            out currentHumidity : HumidityValue;
        }
        
        then action computeControl : ComputeControlAction {
            in currentTemp = readSensors.currentTemperature;
            in targetTemp : TemperatureValue;
            in deadband : TemperatureValue;
            out command : ControlSignal;
        }
        
        then decide;
            if computeControl.command.heatingDemand > 0.0 then applyHeating;
            if computeControl.command.coolingDemand > 0.0 then applyCooling;
            if computeControl.command.fanSpeed > 0.0 then runFan;
        
        action applyHeating : ActivateHeating {
            in demand = computeControl.command.heatingDemand;
        }
        
        action applyCooling : ActivateCooling {
            in demand = computeControl.command.coolingDemand;
        }
        
        action runFan : ModulateFan {
            in speed = computeControl.command.fanSpeed;
        }
        
        then controlCycle;
    }
    
    state def ClimateControlStateMachine {
        entry; then idle;
        
        state idle;
        
        state heating;
        
        state cooling;
        
        state ventilating;
        
        transition idle_to_heating
            first idle
            accept TemperatureBelowSetpoint
            then heating;
        
        transition heating_to_idle
            first heating
            accept TemperatureInRange
            then idle;
        
        transition idle_to_cooling
            first idle
            accept TemperatureAboveSetpoint
            then cooling;
        
        transition cooling_to_idle
            first cooling
            accept TemperatureInRange
            then idle;
        
        transition idle_to_ventilating
            first idle
            accept VentilationRequested
            then ventilating;
        
        transition ventilating_to_idle
            first ventilating
            accept VentilationComplete
            then idle;
    }
    
    part def HVACSystem {
        part indoorTempSensor : TemperatureSensor;
        part indoorHumiditySensor : HumiditySensor;
        part outdoorTempSensor : TemperatureSensor;
        part thermostat : Thermostat;
        part furnace : Furnace;
        part airConditioner : AirConditioner;
        part blower : Blower;
        part supplyDuct : Ductwork;
        part returnDuct : Ductwork;
        part damper : Damper;
        
        connect indoorTempSensor.output to thermostat.sensorInput;
        
        perform action climateRegulation : RegulateClimate;
    }
    
    part hvacSystem : HVACSystem;
    
    requirement def TemperatureMaintenanceRequirement {
        doc /* The HVAC system shall maintain indoor temperature within the specified setpoint range. */
        
        subject system : HVACSystem;
        
        require constraint temperatureWithinRange {
            system.thermostat.currentTemp >= system.thermostat.targetTemp - 1.0 and
            system.thermostat.currentTemp <= system.thermostat.targetTemp + 1.0
        }
    }
    
    requirement def EnergyEfficiencyRequirement {
        doc /* The HVAC system shall optimize energy consumption while maintaining comfort conditions. */
        
        subject system : HVACSystem;
        
        require constraint powerLimit {
            (system.furnace.currentPower + system.airConditioner.currentPower) <= 10000.0
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The HVAC system shall not operate heating and cooling simultaneously. */
        
        subject system : HVACSystem;
    }
    
    requirement def ResponseRequirement {
        doc /* The HVAC system shall respond to temperature deviations within acceptable time limits. */
        
        subject system : HVACSystem;
    }
    
    requirement <'HVAC-001'> maintainTemperature : TemperatureMaintenanceRequirement {
        assume constraint conditionedSpace {
            doc /* The building space is enclosed and requires climate control. */
        }
        
        require temperatureWithinRange;
    }
    
    requirement <'HVAC-002'> operateEfficiently : EnergyEfficiencyRequirement {
        require powerLimit;
    }
    
    requirement <'HVAC-003'> ensureSafety : SafetyRequirement;
    
    requirement <'HVAC-SYS'> hvacSystemRequirement {
        doc /* The HVAC system shall automatically regulate indoor climate by continuously monitoring 
               temperature and humidity, then controlling heating, cooling, and ventilation equipment 
               to maintain occupant comfort within specified setpoints while optimizing energy efficiency 
               and ensuring safe operation. */
        
        require maintainTemperature;
        require operateEfficiently;
        require ensureSafety;
    }
}
