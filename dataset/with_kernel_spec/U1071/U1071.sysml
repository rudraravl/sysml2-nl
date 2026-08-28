package BuildingHVACSystem {
    item def EnvironmentalReading {
        attribute temperature : ScalarValues::Real;
        attribute humidity : ScalarValues::Real;
    }
    item def ModeCommand;
    item def FanSpeedCommand;
    item def ReturnAir {
        attribute temperature : ScalarValues::Real;
        attribute humidity : ScalarValues::Real;
    }
    item def ConditionedAir {
        attribute temperature : ScalarValues::Real;
        attribute airflow : ScalarValues::Real;
    }

    part def ConditionedSpace {
        attribute currentTemperature : ScalarValues::Real;
        attribute currentHumidity : ScalarValues::Real;
        port returnAirPort {
            out returnAir : ReturnAir;
        }
        port supplyAirPort {
            in conditionedAir : ConditionedAir;
        }
    }

    part def TemperatureSensor {
        port spaceInterfacePort {
            in returnAir : ReturnAir;
        }
        port sensorDataPort {
            out reading : EnvironmentalReading;
        }
        action senseEnvironment {
            action acceptAir accept ReturnAir via spaceInterfacePort;
            then action sendReading send new EnvironmentalReading() to sensorDataPort;
        }
    }

    part def Thermostat {
        attribute setpoint : ScalarValues::Real;
        attribute deadband : ScalarValues::Real;
        port sensorInputPort {
            in reading : EnvironmentalReading;
        }
        port modeOutputPort {
            out modeCommand : ModeCommand;
        }
        port fanSpeedOutputPort {
            out fanSpeedCommand : FanSpeedCommand;
        }
        action thermostatControl {
            action senseData accept EnvironmentalReading via sensorInputPort;
            then action sendModeCommand send new ModeCommand() to modeOutputPort;
            then action sendFanSpeedCommand send new FanSpeedCommand() to fanSpeedOutputPort;
        }
    }

    part def Furnace {
        port modeInputPort {
            in modeCommand : ModeCommand;
        }
        port returnAirPort {
            in returnAir : ReturnAir;
        }
        port heatExchangerPort {
            out heatedAir : ConditionedAir;
        }
        action furnaceControl {
            action acceptMode accept ModeCommand via modeInputPort;
            then action acceptReturnAir accept ReturnAir via returnAirPort;
            then action sendHeatedAir send new ConditionedAir() to heatExchangerPort;
        }
    }

    part def Compressor {
        port modeInputPort {
            in modeCommand : ModeCommand;
        }
        port returnAirPort {
            in returnAir : ReturnAir;
        }
        port coolingCoilPort {
            out cooledAir : ConditionedAir;
        }
        action compressorControl {
            action acceptMode accept ModeCommand via modeInputPort;
            then action acceptReturnAir accept ReturnAir via returnAirPort;
            then action sendCooledAir send new ConditionedAir() to coolingCoilPort;
        }
    }

    part def BlowerFan {
        port fanSpeedInputPort {
            in fanSpeedCommand : FanSpeedCommand;
        }
        port returnAirPort {
            in returnAir : ReturnAir;
        }
        port dischargePort {
            out conditionedAir : ConditionedAir;
        }
        action fanControl {
            action acceptSpeed accept FanSpeedCommand via fanSpeedInputPort;
            then action acceptReturnAir accept ReturnAir via returnAirPort;
            then action sendConditionedAir send new ConditionedAir() to dischargePort;
        }
    }

    part def AirHandler {
        part blowerFan : BlowerFan;
        port returnAirPort {
            in returnAir : ReturnAir;
        }
        port dischargePort {
            out conditionedAir : ConditionedAir;
        }
        port fanSpeedInputPort {
            in fanSpeedCommand : FanSpeedCommand;
        }
        bind returnAirPort = blowerFan.returnAirPort;
        bind dischargePort = blowerFan.dischargePort;
        bind fanSpeedInputPort = blowerFan.fanSpeedInputPort;
    }

    part def DuctSystem {
        port returnDuctInlet {
            in returnAir : ReturnAir;
        }
        port returnDuctOutlet {
            out returnAir : ReturnAir;
        }
        port supplyDuctInlet {
            in conditionedAir : ConditionedAir;
        }
        port supplyDuctOutlet {
            out conditionedAir : ConditionedAir;
        }
    }

    part def HVACSystem {
        part conditionedSpace : ConditionedSpace;
        part temperatureSensor : TemperatureSensor;
        part thermostat : Thermostat;
        part furnace : Furnace;
        part compressor : Compressor;
        part airHandler : AirHandler;
        part ductSystem : DuctSystem;

        flow spaceToSensorFlow of ReturnAir
            from conditionedSpace.returnAirPort.returnAir to temperatureSensor.spaceInterfacePort.returnAir;
        flow sensorToThermostatFlow of EnvironmentalReading
            from temperatureSensor.sensorDataPort.reading to thermostat.sensorInputPort.reading;
        flow modeToFurnaceFlow of ModeCommand
            from thermostat.modeOutputPort.modeCommand to furnace.modeInputPort.modeCommand;
        flow modeToCompressorFlow of ModeCommand
            from thermostat.modeOutputPort.modeCommand to compressor.modeInputPort.modeCommand;
        flow fanSpeedToAirHandlerFlow of FanSpeedCommand
            from thermostat.fanSpeedOutputPort.fanSpeedCommand to airHandler.fanSpeedInputPort.fanSpeedCommand;
        flow spaceToReturnDuctFlow of ReturnAir
            from conditionedSpace.returnAirPort.returnAir to ductSystem.returnDuctInlet.returnAir;
        flow returnDuctToAirHandlerFlow of ReturnAir
            from ductSystem.returnDuctOutlet.returnAir to airHandler.returnAirPort.returnAir;
        flow returnAirToFurnaceFlow of ReturnAir
            from airHandler.returnAirPort.returnAir to furnace.returnAirPort.returnAir;
        flow returnAirToCompressorFlow of ReturnAir
            from airHandler.returnAirPort.returnAir to compressor.returnAirPort.returnAir;
        flow heatedAirToDischargeFlow of ConditionedAir
            from furnace.heatExchangerPort.heatedAir to airHandler.dischargePort.conditionedAir;
        flow cooledAirToDischargeFlow of ConditionedAir
            from compressor.coolingCoilPort.cooledAir to airHandler.dischargePort.conditionedAir;
        flow dischargeToSupplyDuctFlow of ConditionedAir
            from airHandler.dischargePort.conditionedAir to ductSystem.supplyDuctInlet.conditionedAir;
        flow supplyDuctToSpaceFlow of ConditionedAir
            from ductSystem.supplyDuctOutlet.conditionedAir to conditionedSpace.supplyAirPort.conditionedAir;
    }

    requirement def TemperatureControlReq {
        doc /* The HVAC system shall maintain conditioned space temperature within the deadband of the user setpoint. */
        attribute setpoint : ScalarValues::Real;
        attribute actualTemperature : ScalarValues::Real;
        attribute deadband : ScalarValues::Real;
        require constraint {
            actualTemperature >= setpoint - deadband &&
            actualTemperature <= setpoint + deadband
        }
    }

    requirement def HumidityControlReq {
        doc /* The HVAC system shall maintain conditioned space humidity between 30 and 60 percent. */
        attribute humidity : ScalarValues::Real;
        require constraint {
            humidity >= 30 && humidity <= 60
        }
    }

    requirement def ContinuousSensingReq {
        doc /* The temperature sensor shall continuously measure ambient temperature and humidity. */
        attribute sensingActive : ScalarValues::Integer;
        require constraint { sensingActive == 1 }
    }

    requirement def ResponseTimeReq {
        doc /* The HVAC system shall respond to temperature deviation within 60 seconds. */
        attribute responseTime : ScalarValues::Real;
        attribute maxResponseTime : ScalarValues::Real;
        require constraint { responseTime <= maxResponseTime }
    }

    requirement def ClosedLoopFeedbackReq {
        doc /* The system shall operate as a closed-loop feedback system continuously circulating and conditioning air. */
        attribute loopActive : ScalarValues::Integer;
        require constraint { loopActive == 1 }
    }

    requirement hvacTemperatureControl : TemperatureControlReq {
        attribute :>> setpoint = 22.0;
        attribute :>> deadband = 1.0;
    }
    requirement hvacHumidityControl : HumidityControlReq;
    requirement hvacContinuousSensing : ContinuousSensingReq;
    requirement hvacResponseTime : ResponseTimeReq {
        attribute :>> maxResponseTime = 60.0;
    }
    requirement hvacClosedLoopFeedback : ClosedLoopFeedbackReq;

    part buildingHVAC : HVACSystem;
}
