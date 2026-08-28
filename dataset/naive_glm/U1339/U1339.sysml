package HVAC_System {

    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type Celsius :> Real;
    value type Percent :> Real;
    value type Watt :> Real;
    value type CubicMetersPerSecond :> Real;
    value type Seconds :> Real;

    // ===== Item Types =====
    item def TempReading {
        attribute value : Celsius;
        attribute timestamp : Seconds;
    }

    item def HumidityReading {
        attribute value : Percent;
        attribute timestamp : Seconds;
    }

    item def ControlSignal {
        attribute active : Boolean;
        attribute powerLevel : Real; // 0.0 .. 1.0
    }

    item def ConditionedAir {
        attribute temperature : Celsius;
        attribute flowRate : CubicMetersPerSecond;
    }

    // ===== Setpoint =====
    part def TempSetpoint {
        attribute target : Celsius = 21.0;
        attribute deadband : Celsius = 0.5;
    }

    // ===== Sensors =====
    part def TemperatureSensor {
        attribute measuredTemp : Celsius;
        attribute samplingPeriod : Seconds = 1.0;
        out port readingOut : TempReading;

        action def senseTemp() : TempReading {
            out result : TempReading;
        }

        action sense : senseTemp();
    }

    part def HumiditySensor {
        attribute measuredHumidity : Percent;
        attribute samplingPeriod : Seconds = 2.0;
        out port readingOut : HumidityReading;

        action def senseHumidity() : HumidityReading {
            out result : HumidityReading;
        }

        action sense : senseHumidity();
    }

    // ===== Actuators =====
    part def Furnace {
        attribute maxPower : Watt = 5000.0;
        attribute currentPower : Watt = 0.0;
        attribute efficiency : Real = 0.92;
        in port command : ControlSignal;
        out port airOut : ConditionedAir;

        action def heat(in cmd : ControlSignal) : ConditionedAir {
            out result : ConditionedAir;
        }

        action heating : heat(command);
    }

    part def AirConditioner {
        attribute maxPower : Watt = 3500.0;
        attribute currentPower : Watt = 0.0;
        attribute efficiency : Real = 0.88;
        in port command : ControlSignal;
        out port airOut : ConditionedAir;

        action def cool(in cmd : ControlSignal) : ConditionedAir {
            out result : ConditionedAir;
        }

        action cooling : cool(command);
    }

    part def Blower {
        attribute maxFlow : CubicMetersPerSecond = 0.5;
        attribute currentFlow : CubicMetersPerSecond = 0.0;
        in port command : ControlSignal;
        in port airIn : ConditionedAir;
        out port airOut : ConditionedAir;

        action def circulate(in air : ConditionedAir, in cmd : ControlSignal) : ConditionedAir {
            out result : ConditionedAir;
        }

        action circulating : circulate(airIn, command);
    }

    part def Ductwork {
        attribute totalLength : Real = 30.0;
        attribute leakageRate : Real = 0.03;
        in port airIn : ConditionedAir;
        out port airOut : ConditionedAir;

        action def distribute(in air : ConditionedAir) : ConditionedAir {
            out result : ConditionedAir;
        }

        action distributing : distribute(airIn);
    }

    // ===== Thermostat (Controller) =====
    part def Thermostat {
        attribute setpoint : TempSetpoint;
        attribute indoorTemp : Celsius;
        attribute outdoorTemp : Celsius;
        attribute indoorHumidity : Percent;
        attribute totalPower : Watt = 0.0;
        attribute maxPower : Watt = 8000.0;
        attribute heatingActive : Boolean = false;
        attribute coolingActive : Boolean = false;
        attribute blowerActive : Boolean = false;

        in port indoorTempIn : TempReading;
        in port outdoorTempIn : TempReading;
        in port humidityIn : HumidityReading;
        out port furnaceCmd : ControlSignal;
        out port acCmd : ControlSignal;
        out port blowerCmd : ControlSignal;

        action def evaluate(
            in indoor : TempReading,
            in outdoor : TempReading,
            in humidity : HumidityReading,
            out furnace : ControlSignal,
            out ac : ControlSignal,
            out blower : ControlSignal
        ) {
            // Decision logic placeholder implemented by state machine
        }

        action control : evaluate(indoorTempIn, outdoorTempIn, humidityIn, furnaceCmd, acCmd, blowerCmd);

        state def ControlStates {
            entry; then Idle;

            state Idle {
                entry action {
                    furnaceCmd.active = false;
                    furnaceCmd.powerLevel = 0.0;
                    acCmd.active = false;
                    acCmd.powerLevel = 0.0;
                    blowerCmd.active = false;
                    blowerCmd.powerLevel = 0.0;
                    heatingActive = false;
                    coolingActive = false;
                    blowerActive = false;
                }
            }

            state Heating {
                entry action {
                    furnaceCmd.active = true;
                    furnaceCmd.powerLevel = 1.0;
                    acCmd.active = false;
                    acCmd.powerLevel = 0.0;
                    blowerCmd.active = true;
                    blowerCmd.powerLevel = 0.8;
                    heatingActive = true;
                    coolingActive = false;
                    blowerActive = true;
                }
            }

            state Cooling {
                entry action {
                    furnaceCmd.active = false;
                    furnaceCmd.powerLevel = 0.0;
                    acCmd.active = true;
                    acCmd.powerLevel = 1.0;
                    blowerCmd.active = true;
                    blowerCmd.powerLevel = 0.8;
                    heatingActive = false;
                    coolingActive = true;
                    blowerActive = true;
                }
            }

            state Ventilating {
                entry action {
                    furnaceCmd.active = false;
                    furnaceCmd.powerLevel = 0.0;
                    acCmd.active = false;
                    acCmd.powerLevel = 0.0;
                    blowerCmd.active = true;
                    blowerCmd.powerLevel = 0.5;
                    heatingActive = false;
                    coolingActive = false;
                    blowerActive = true;
                }
            }

            transition idle_to_heating
                first Idle
                accept when indoorTemp < (setpoint.target - setpoint.deadband)
                then Heating;

            transition heating_to_idle
                first Heating
                accept when indoorTemp >= setpoint.target
                then Idle;

            transition idle_to_cooling
                first Idle
                accept when indoorTemp > (setpoint.target + setpoint.deadband)
                then Cooling;

            transition cooling_to_idle
                first Cooling
                accept when indoorTemp <= setpoint.target
                then Idle;

            transition idle_to_ventilating
                first Idle
                accept when indoorHumidity > 60.0
                then Ventilating;

            transition ventilating_to_idle
                first Ventilating
                accept when indoorHumidity <= 50.0
                then Idle;
        }

        behavior modeControl : ControlStates;
    }

    // ===== HVAC System Assembly =====
    part def HVACSystem {
        attribute systemName : String = "BuildingHVAC";
        attribute buildingArea : Real = 250.0;

        part thermostat : Thermostat {
            attribute setpoint : TempSetpoint = TempSetpoint { target = 21.0; deadband = 0.5; }
        }

        part indoorSensor : TemperatureSensor;
        part outdoorSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part furnace : Furnace;
        part airConditioner : AirConditioner;
        part blower : Blower;
        part ductwork : Ductwork;

        connection indoorTempConn connect indoorSensor.readingOut to thermostat.indoorTempIn;
        connection outdoorTempConn connect outdoorSensor.readingOut to thermostat.outdoorTempIn;
        connection humidityConn connect humiditySensor.readingOut to thermostat.humidityIn;

        connection furnaceCmdConn connect thermostat.furnaceCmd to furnace.command;
        connection acCmdConn connect thermostat.acCmd to airConditioner.command;
        connection blowerCmdConn connect thermostat.blowerCmd to blower.command;

        connection furnaceAirConn connect furnace.airOut to blower.airIn;
        connection acAirConn connect airConditioner.airOut to blower.airIn;
        connection blowerAirConn connect blower.airOut to ductwork.airIn;
    }

    // ===== Requirements =====
    requirement def TemperatureControlRequirement {
        attribute setpointTarget : Celsius = 21.0;
        attribute tolerance : Celsius = 0.5;
        subject hvac : HVACSystem;
        require {
            |hvac.thermostat.indoorTemp - setpointTarget| <= tolerance
        }
    }

    requirement def EnergyEfficiencyRequirement {
        attribute maxTotalPower : Watt = 8000.0;
        subject hvac : HVACSystem;
        require {
            hvac.thermostat.totalPower <= maxTotalPower
        }
    }

    requirement def SafetyInterlockRequirement {
        subject hvac : HVACSystem;
        require {
            not (hvac.furnace.currentPower > 0.0 and hvac.airConditioner.currentPower > 0.0)
        }
    }

    requirement def HumidityControlRequirement {
        attribute maxHumidity : Percent = 60.0;
        attribute minHumidity : Percent = 30.0;
        subject hvac : HVACSystem;
        require {
            hvac.thermostat.indoorHumidity <= maxHumidity and hvac.thermostat.indoorHumidity >= minHumidity
        }
    }

    requirement HVACSystemRequirements {
        satisfy tempControl : TemperatureControlRequirement;
        satisfy energyEfficiency : EnergyEfficiencyRequirement;
        satisfy safetyInterlock : SafetyInterlockRequirement;
        satisfy humidityControl : HumidityControlRequirement;
    }
}
