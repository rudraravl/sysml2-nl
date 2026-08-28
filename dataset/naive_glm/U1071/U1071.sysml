package HVACSystem {

    import ScalarValues::*;

    // ===== Units =====
    unit degC;
    unit percent;
    unit m3_per_s;
    unit W;

    // ===== Value Types =====
    value type Temperature specializes Real { unit degC; }
    value type Humidity specializes Real { unit percent; }
    value type AirFlowRate specializes Real { unit m3_per_s; }
    value type Power specializes Real { unit W; }

    // ===== Enumerations =====
    enum FanSpeed { low; medium; high; }
    enum Mode { off; heating; cooling; ventilating; }

    // ===== Item Types =====
    item Air {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
    }

    item SensorReading {
        attribute temperature : Temperature;
        attribute humidity : Humidity;
    }

    item ControlCommand {
        attribute mode : Mode;
        attribute fanSpeed : FanSpeed;
    }

    // ===== Port Definitions =====
    port def ReadingPort {
        in item reading : SensorReading;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def AirOutPort {
        out item air : Air;
    }

    port def AirInPort {
        in item air : Air;
    }

    port def ThermalPort {
        in attribute thermalOutput : Power;
    }

    // ===== Requirements =====
    requirement def MaintainTemperature {
        attribute setpoint : Temperature;
        attribute tolerance : Temperature;
        require {
            constraint { conditionedSpace.currentTemperature >= setpoint - tolerance }
            constraint { conditionedSpace.currentTemperature <= setpoint + tolerance }
        }
    }

    requirement def MaintainAirQuality {
        attribute maxHumidity : Humidity = 60 [percent];
        require {
            constraint { conditionedSpace.currentHumidity <= maxHumidity }
        }
    }

    requirement def RespondToSetpoint {
        attribute responseTime : TimeValue;
        require {
            constraint { thermostat.responseTime <= responseTime }
        }
    }

    // ===== Parts =====

    part ConditionedSpace {
        attribute currentTemperature : Temperature = 22 [degC];
        attribute currentHumidity : Humidity = 45 [percent];
        attribute volume : AirFlowRate = 200 [m3_per_s];

        port returnAirOut : AirOutPort;
        port supplyAirIn : AirInPort;

        action updateClimate :> Action {
            in supplyAir : Air;
            // Updates currentTemperature and currentHumidity based on supply air
        }
    }

    part TemperatureSensor {
        attribute samplingInterval : TimeValue;
        attribute measuredTemp : Temperature;
        attribute measuredHumidity : Humidity;

        port readingOut : ~ReadingPort;

        action sense :> Action {
            out reading : SensorReading;
            // Continuously samples ambient temperature and humidity
            // from the conditioned space and emits a SensorReading
        }

        exhibit {
            action sense;
        }
    }

    part Thermostat {
        attribute setpoint : Temperature = 22 [degC];
        attribute deadband : Temperature = 1.5 [degC];
        attribute currentTemp : Temperature = 22 [degC];
        attribute currentHumidity : Humidity = 45 [percent];
        attribute responseTime : TimeValue;
        attribute humidityThreshold : Humidity = 60 [percent];

        port readingIn : ReadingPort;
        port furnaceCommand : ~CommandPort;
        port compressorCommand : ~CommandPort;
        port fanCommand : ~CommandPort;

        action processReading :> Action {
            in reading : SensorReading;
            // Updates currentTemp and currentHumidity from the received reading
        }

        action issueCommand :> Action {
            out furnaceCmd : ControlCommand;
            out compressorCmd : ControlCommand;
            out fanCmd : ControlCommand;
            // Issues commands based on the current operating mode
        }

        state machine ClimateControl {
            entry; then Idle;

            state Idle {
                entry {
                    /* Furnace off, Compressor off, Fan off or low */
                }
            }

            state Heating {
                entry {
                    /* Activate Furnace, set Fan to high */
                }
            }

            state Cooling {
                entry {
                    /* Activate Compressor, set Fan to high */
                }
            }

            state Ventilating {
                entry {
                    /* Fan low, no heating or cooling */
                }
            }

            transition from Idle to Heating
                when currentTemp < setpoint - deadband;

            transition from Idle to Cooling
                when currentTemp > setpoint + deadband;

            transition from Idle to Ventilating
                when currentHumidity > humidityThreshold;

            transition from Heating to Idle
                when currentTemp >= setpoint;

            transition from Cooling to Idle
                when currentTemp <= setpoint;

            transition from Ventilating to Idle
                when currentHumidity <= humidityThreshold - 5 [percent];

            transition from Heating to Ventilating
                when currentHumidity > humidityThreshold;

            transition from Cooling to Ventilating
                when currentHumidity > humidityThreshold;
        }

        exhibit {
            action processReading;
            action issueCommand;
            state machine ClimateControl;
        }
    }

    part Furnace {
        attribute heatOutput : Power = 5000 [W];
        attribute isOn : Boolean = false;

        port commandIn : CommandPort;
        port heatOut : ~ThermalPort;

        state machine FurnaceOperation {
            entry; then Off;

            state Off {
                entry {
                    /* heatOut.thermalOutput = 0 [W] */
                }
            }

            state On {
                entry {
                    /* heatOut.thermalOutput = heatOutput */
                }
            }

            transition from Off to On
                when commandIn.command.mode == Mode::heating;

            transition from On to Off
                when commandIn.command.mode != Mode::heating;
        }

        exhibit {
            state machine FurnaceOperation;
        }
    }

    part Compressor {
        attribute coolingOutput : Power = 4000 [W];
        attribute isOn : Boolean = false;

        port commandIn : CommandPort;
        port coolOut : ~ThermalPort;

        state machine CompressorOperation {
            entry; then Off;

            state Off {
                entry {
                    /* coolOut.thermalOutput = 0 [W] */
                }
            }

            state On {
                entry {
                    /* coolOut.thermalOutput = -coolingOutput */
                }
            }

            transition from Off to On
                when commandIn.command.mode == Mode::cooling;

            transition from On to Off
                when commandIn.command.mode != Mode::cooling;
        }

        exhibit {
            state machine CompressorOperation;
        }
    }

    part BlowerFan {
        attribute maxFlowRate : AirFlowRate = 2.0 [m3_per_s];
        attribute currentSpeed : FanSpeed = FanSpeed::low;
        attribute currentFlowRate : AirFlowRate = 0 [m3_per_s];

        port commandIn : CommandPort;
        port airIn : AirInPort;
        port airOut : AirOutPort;

        action regulateSpeed :> Action {
            in command : ControlCommand;
            // Adjusts currentSpeed and currentFlowRate based on command.fanSpeed
        }

        state machine FanOperation {
            entry; then Stopped;

            state Stopped {
                entry {
                    /* currentFlowRate = 0 [m3_per_s] */
                }
            }

            state RunningLow {
                entry {
                    /* currentSpeed = FanSpeed::low; currentFlowRate = maxFlowRate * 0.33 */
                }
            }

            state RunningMedium {
                entry {
                    /* currentSpeed = FanSpeed::medium; currentFlowRate = maxFlowRate * 0.66 */
                }
            }

            state RunningHigh {
                entry {
                    /* currentSpeed = FanSpeed::high; currentFlowRate = maxFlowRate */
                }
            }

            transition from Stopped to RunningLow
                when commandIn.command.fanSpeed == FanSpeed::low;

            transition from Stopped to RunningMedium
                when commandIn.command.fanSpeed == FanSpeed::medium;

            transition from Stopped to RunningHigh
                when commandIn.command.fanSpeed == FanSpeed::high;

            transition from RunningLow to RunningMedium
                when commandIn.command.fanSpeed == FanSpeed::medium;

            transition from RunningLow to RunningHigh
                when commandIn.command.fanSpeed == FanSpeed::high;

            transition from RunningMedium to RunningLow
                when commandIn.command.fanSpeed == FanSpeed::low;

            transition from RunningMedium to RunningHigh
                when commandIn.command.fanSpeed == FanSpeed::high;

            transition from RunningHigh to RunningLow
                when commandIn.command.fanSpeed == FanSpeed::low;

            transition from RunningHigh to RunningMedium
                when commandIn.command.fanSpeed == FanSpeed::medium;

            transition from any to Stopped
                when commandIn.command.mode == Mode::off;
        }

        exhibit {
            action regulateSpeed;
            state machine FanOperation;
        }
    }

    part AirHandler {
        port returnAirIn : AirInPort;
        port supplyAirOut : AirOutPort;
        port heatIn : ThermalPort;
        port coolIn : ThermalPort;
        port fanCommandIn : CommandPort;

        part blowerFan : BlowerFan;

        action conditionAir :> Action {
            in returnAir : Air;
            in heat : Power;
            in cooling : Power;
            out supplyAir : Air;
            // Modifies return air temperature by applying heat or cooling
            // and pushes it through the supply duct via the blower fan
        }

        connection fanCommandIn to blowerFan.commandIn;
        connection returnAirIn to blowerFan.airIn;
        connection blowerFan.airOut to supplyAirOut;

        exhibit {
            action conditionAir;
        }
    }

    part DuctSystem {
        attribute returnDuctLength : Real;
        attribute supplyDuctLength : Real;

        port returnDuctIn : AirInPort;
        port returnDuctOut : AirOutPort;
        port supplyDuctIn : AirInPort;
        port supplyDuctOut : AirOutPort;

        action transportReturnAir :> Action {
            in air : Air;
            out air : Air;
            // Transports return air from conditioned space to air handler
        }

        action transportSupplyAir :> Action {
            in air : Air;
            out air : Air;
            // Transports conditioned supply air from air handler to conditioned space
        }

        connection returnDuctIn to returnDuctOut;
        connection supplyDuctIn to supplyDuctOut;

        exhibit {
            action transportReturnAir;
            action transportSupplyAir;
        }
    }

    // ===== Top-Level System =====
    part def HVACSystem {

        part conditionedSpace : ConditionedSpace;
        part tempSensor : TemperatureSensor;
        part thermostat : Thermostat;
        part furnace : Furnace;
        part compressor : Compressor;
        part airHandler : AirHandler;
        part ductSystem : DuctSystem;

        // Sensor -> Thermostat feedback loop
        connection tempSensor.readingOut to thermostat.readingIn;

        // Thermostat -> Actuators command paths
        connection thermostat.furnaceCommand to furnace.commandIn;
        connection thermostat.compressorCommand to compressor.commandIn;
        connection thermostat.fanCommand to airHandler.fanCommandIn;

        // Thermal energy from Furnace/Compressor into AirHandler
        connection furnace.heatOut to airHandler.heatIn;
        connection compressor.coolOut to airHandler.coolIn;

        // Return air path: Room -> Ducts -> AirHandler
        connection conditionedSpace.returnAirOut to ductSystem.returnDuctIn;
        connection ductSystem.returnDuctOut to airHandler.returnAirIn;

        // Supply air path: AirHandler -> Ducts -> Room
        connection airHandler.supplyAirOut to ductSystem.supplyDuctIn;
        connection ductSystem.supplyDuctOut to conditionedSpace.supplyAirIn;

        // Requirements satisfaction
        satisfy maintainTemp : MaintainTemperature {
            attribute setpoint = 22 [degC];
            attribute tolerance = 1.5 [degC];
        } by thermostat.ClimateControl;

        satisfy maintainAirQuality : MaintainAirQuality {
            attribute maxHumidity = 60 [percent];
        } by thermostat.ClimateControl;

        satisfy respondToSetpoint : RespondToSetpoint {
            attribute responseTime = 30 [s];
        } by thermostat;
    }

}
