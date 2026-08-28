package BuildingHVACSystem {
    private import ScalarValues::*;

    attribute def Temperature :> Real { unit 'K'; }
    attribute def Humidity :> Real { unit '%'; }
    attribute def Power :> Real { unit 'W'; }

    item def TemperatureReading { attribute value : Temperature; }
    item def HumidityReading { attribute value : Humidity; }
    item def ControlSignal { attribute active : Boolean; }
    attribute def Setpoint { attribute targetTemp : Temperature; attribute deadband : Temperature; }

    port def TempOutPort { out item reading : TemperatureReading; }
    port def HumidityOutPort { out item reading : HumidityReading; }
    port def SetpointOutPort { out item config : Setpoint; }
    port def ControlInPort { in item signal : ControlSignal; }

    part def IndoorTemperatureSensor {
        port tempOut : TempOutPort;
    }
    part def OutdoorTemperatureSensor {
        port tempOut : TempOutPort;
    }
    part def HumiditySensor {
        port humidityOut : HumidityOutPort;
    }
    part def UserInterface {
        port setpointOut : SetpointOutPort;
    }

    part def Furnace {
        port controlIn : ControlInPort;
        attribute powerConsumption : Power = 5000;
    }
    part def AirConditioner {
        port controlIn : ControlInPort;
        attribute powerConsumption : Power = 3000;
    }
    part def Blower {
        port controlIn : ControlInPort;
        attribute powerConsumption : Power = 500;
    }
    part def Ductwork {
    }

    port def ThermostatInTempPort { in item reading : TemperatureReading; }
    port def ThermostatInHumidityPort { in item reading : HumidityReading; }
    port def ThermostatInSetpointPort { in item config : Setpoint; }
    port def ThermostatOutControlPort { out item signal : ControlSignal; }

    part def Thermostat {
        port indoorTempIn : ThermostatInTempPort;
        port outdoorTempIn : ThermostatInTempPort;
        port humidityIn : ThermostatInHumidityPort;
        port setpointIn : ThermostatInSetpointPort;

        port furnaceControl : ThermostatOutControlPort;
        port acControl : ThermostatOutControlPort;
        port blowerControl : ThermostatOutControlPort;

        attribute setpoint : Setpoint;
        attribute currentTemp : Temperature;
        attribute currentHumidity : Humidity;

        state def HVACStateMachine {
            initial state Idle;
            state Heating {
                entry action {
                    send new ControlSignal(active = true) to furnaceControl;
                    send new ControlSignal(active = true) to blowerControl;
                }
            }
            state Cooling {
                entry action {
                    send new ControlSignal(active = true) to acControl;
                    send new ControlSignal(active = true) to blowerControl;
                }
            }
            state Ventilating {
                entry action {
                    send new ControlSignal(active = true) to blowerControl;
                }
            }

            transition Idle_to_Heating first Idle then Heating
                if currentTemp < (setpoint.targetTemp - setpoint.deadband);
            transition Heating_to_Idle first Heating then Idle
                if currentTemp >= setpoint.targetTemp;
            transition Idle_to_Cooling first Idle then Cooling
                if currentTemp > (setpoint.targetTemp + setpoint.deadband);
            transition Cooling_to_Idle first Cooling then Idle
                if currentTemp <= setpoint.targetTemp;
            transition Idle_to_Ventilating first Idle then Ventilating
                if currentHumidity > 60;
            transition Ventilating_to_Idle first Ventilating then Idle
                if currentHumidity <= 50;
        }

        state machine thermostatStateMachine : HVACStateMachine;
    }

    part def BuildingHVAC {
        part thermostat : Thermostat {
            attribute setpoint.targetTemp = 293.15;
            attribute setpoint.deadband = 1.0;
        }
        part indoorTempSensor : IndoorTemperatureSensor;
        part outdoorTempSensor : OutdoorTemperatureSensor;
        part humiditySensor : HumiditySensor;
        part furnace : Furnace;
        part airConditioner : AirConditioner;
        part blower : Blower;
        part ductwork : Ductwork;
        part userInterface : UserInterface;

        connect indoorTempSensor.tempOut to thermostat.indoorTempIn;
        connect outdoorTempSensor.tempOut to thermostat.outdoorTempIn;
        connect humiditySensor.humidityOut to thermostat.humidityIn;
        connect userInterface.setpointOut to thermostat.setpointIn;

        connect thermostat.furnaceControl to furnace.controlIn;
        connect thermostat.acControl to airConditioner.controlIn;
        connect thermostat.blowerControl to blower.controlIn;
    }

    requirement def TemperatureControlReqDef {
        doc /* The HVAC system shall maintain the indoor temperature within the setpoint deadband. */
        attribute actualTemp : Temperature;
        attribute targetTemp : Temperature;
        attribute tolerance : Temperature;
        require constraint { abs(actualTemp - targetTemp) <= tolerance }
    }

    requirement def EnergyEfficiencyReqDef {
        doc /* The HVAC system shall operate with total power consumption below the maximum limit. */
        attribute totalPower : Power;
        attribute maxPower : Power;
        require constraint { totalPower <= maxPower }
    }

    requirement def SafetyInterlockReqDef {
        doc /* The system shall prevent the furnace and air conditioner from running simultaneously. */
        attribute furnaceActive : Boolean;
        attribute acActive : Boolean;
        require constraint { not (furnaceActive and acActive) }
    }

    requirement tempControlReq : TemperatureControlReqDef {
        attribute targetTemp = 293.15;
        attribute tolerance = 1.0;
    }

    requirement energyEfficiencyReq : EnergyEfficiencyReqDef {
        attribute maxPower = 8500;
    }

    requirement safetyInterlockReq : SafetyInterlockReqDef;
}
