package ClimateControlSystem {
    import ScalarValues::*;

    // ===== Value Types =====
    value type TemperatureValue :> Real { unit "degC"; }
    value type HumidityValue :> Real { unit "percent"; }
    value type PowerValue :> Real { unit "W"; }
    value type MassFlowRateValue :> Real { unit "kg/s"; }
    value type PressureValue :> Real { unit "Pa"; }
    value type RotationalSpeedValue :> Real { unit "rpm"; }
    value type EnergyEfficiencyValue :> Real { unit "EER"; }
    value type VoltageValue :> Real { unit "V"; }
    value type VolumeValue :> Real { unit "m3"; }

    // ===== Enumerations =====
    enum def SystemMode { off; cooling; heating; fanOnly; auto; }
    enum def ControlCommand {
        startCompressor;
        stopCompressor;
        setCompressorSpeed;
        setIndoorFanSpeed;
        setOutdoorFanSpeed;
        activateHeatingElement;
        deactivateHeatingElement;
    }

    // ===== Item Types =====
    item def Refrigerant {
        attribute phase: String;
        attribute pressure: PressureValue;
        attribute temperature: TemperatureValue;
    }

    item def ConditionedAir {
        attribute temperature: TemperatureValue;
        attribute humidity: HumidityValue;
    }

    // ===== Port Definitions =====
    port def RefrigerantFlowPort {
        out item refrigerant: Refrigerant;
    }

    port def AirFlowPort {
        out item air: ConditionedAir;
    }

    port def ControlSignalPort {
        out command: ControlCommand;
        out targetSpeed: RotationalSpeedValue;
    }

    port def SensorDataPort {
        out temperature: TemperatureValue;
        out humidity: HumidityValue;
    }

    port def ThermostatPort {
        out setTemperature: TemperatureValue;
        out mode: SystemMode;
    }

    // ===== Part Definitions =====

    part def Compressor {
        port refrigerantIn: ~RefrigerantFlowPort;
        port refrigerantOut: RefrigerantFlowPort;
        port controlIn: ~ControlSignalPort;

        attribute currentSpeed: RotationalSpeedValue = 0;
        attribute powerConsumption: PowerValue = 0;
        attribute maxSpeed: RotationalSpeedValue = 3600;
        attribute ratedPower: PowerValue = 1200;

        action def Compress {
            in lowPressureVapor: Refrigerant;
            out highPressureVapor: Refrigerant;
        }

        action compress: Compress;
    }

    part def Condenser {
        port refrigerantIn: ~RefrigerantFlowPort;
        port refrigerantOut: RefrigerantFlowPort;
        port airIn: ~AirFlowPort;

        attribute heatRejectionRate: PowerValue = 0;

        action def Condense {
            in hotVapor: Refrigerant;
            in ambientAir: ConditionedAir;
            out liquidRefrigerant: Refrigerant;
            out heatedAir: ConditionedAir;
        }

        action condense: Condense;
    }

    part def OutdoorFan {
        port airOut: AirFlowPort;
        port controlIn: ~ControlSignalPort;

        attribute currentSpeed: RotationalSpeedValue = 0;
        attribute powerConsumption: PowerValue = 0;
        attribute maxSpeed: RotationalSpeedValue = 1200;
        attribute ratedPower: PowerValue = 150;
    }

    part def ExpansionValve {
        port refrigerantIn: ~RefrigerantFlowPort;
        port refrigerantOut: RefrigerantFlowPort;

        attribute pressureDropRatio: Real = 0.1;

        action def Expand {
            in highPressureLiquid: Refrigerant;
            out lowPressureMixture: Refrigerant;
        }

        action expand: Expand;
    }

    part def Evaporator {
        port refrigerantIn: ~RefrigerantFlowPort;
        port refrigerantOut: RefrigerantFlowPort;
        port airIn: ~AirFlowPort;
        port airOut: AirFlowPort;

        attribute heatAbsorptionRate: PowerValue = 0;
        attribute condensateDrainRate: MassFlowRateValue = 0;

        action def Evaporate {
            in coldRefrigerant: Refrigerant;
            in warmHumidAir: ConditionedAir;
            out vaporRefrigerant: Refrigerant;
            out coolDryAir: ConditionedAir;
        }

        action evaporate: Evaporate;
    }

    part def IndoorFan {
        port airIn: ~AirFlowPort;
        port airOut: AirFlowPort;
        port controlIn: ~ControlSignalPort;

        attribute currentSpeed: RotationalSpeedValue = 0;
        attribute powerConsumption: PowerValue = 0;
        attribute maxSpeed: RotationalSpeedValue = 1200;
        attribute ratedPower: PowerValue = 100;
    }

    part def TemperatureSensor {
        port dataOut: SensorDataPort;
        attribute currentTemperature: TemperatureValue = 25.0;
    }

    part def HumiditySensor {
        port dataOut: SensorDataPort;
        attribute currentHumidity: HumidityValue = 50.0;
    }

    part def Thermostat {
        port dataOut: ThermostatPort;
        attribute setTemperature: TemperatureValue = 24.0;
        attribute selectedMode: SystemMode = SystemMode::off;
    }

    part def Room {
        port airReturn: AirFlowPort;
        port airSupply: ~AirFlowPort;

        attribute currentTemperature: TemperatureValue = 25.0;
        attribute currentHumidity: HumidityValue = 50.0;
        attribute volume: VolumeValue = 60.0;
    }

    // ===== State Machine for Controller =====
    state def ControllerStateMachine {
        initial state Off;
        state Cooling;
        state Heating;
        state FanOnly;
        state Auto;

        transition off_to_cooling first Off then Cooling
            if thermostatIn.mode == SystemMode::cooling;

        transition off_to_heating first Off then Heating
            if thermostatIn.mode == SystemMode::heating;

        transition off_to_fanonly first Off then FanOnly
            if thermostatIn.mode == SystemMode::fanOnly;

        transition off_to_auto first Off then Auto
            if thermostatIn.mode == SystemMode::auto;

        transition cooling_to_off first Cooling then Off
            if thermostatIn.mode == SystemMode::off;

        transition heating_to_off first Heating then Off
            if thermostatIn.mode == SystemMode::off;

        transition fanonly_to_off first FanOnly then Off
            if thermostatIn.mode == SystemMode::off;

        transition auto_to_off first Auto then Off
            if thermostatIn.mode == SystemMode::off;

        transition auto_to_cooling first Auto then Cooling
            if roomTemperature > targetTemperature + 1.0;

        transition auto_to_heating first Auto then Heating
            if roomTemperature < targetTemperature - 1.0;

        transition cooling_to_auto first Cooling then Auto
            if thermostatIn.mode == SystemMode::auto and roomTemperature <= targetTemperature + 0.5;

        transition heating_to_auto first Heating then Auto
            if thermostatIn.mode == SystemMode::auto and roomTemperature >= targetTemperature - 0.5;

        transition cooling_to_fanonly first Cooling then FanOnly
            if thermostatIn.mode == SystemMode::fanOnly;

        transition heating_to_fanonly first Heating then FanOnly
            if thermostatIn.mode == SystemMode::fanOnly;

        state Off {
            entry action {
                compressorControl.command = ControlCommand::stopCompressor;
                outdoorFanControl.targetSpeed = 0;
                indoorFanControl.targetSpeed = 0;
            }
        }

        state Cooling {
            entry action {
                compressorControl.command = ControlCommand::startCompressor;
                outdoorFanControl.command = ControlCommand::setOutdoorFanSpeed;
                indoorFanControl.command = ControlCommand::setIndoorFanSpeed;
            }
            do action {
                if temperatureError > 3.0 {
                    compressorControl.targetSpeed = 3600;
                    indoorFanControl.targetSpeed = 1200;
                    outdoorFanControl.targetSpeed = 1200;
                } else if temperatureError > 1.0 {
                    compressorControl.targetSpeed = 2400;
                    indoorFanControl.targetSpeed = 800;
                    outdoorFanControl.targetSpeed = 900;
                } else {
                    compressorControl.targetSpeed = 1800;
                    indoorFanControl.targetSpeed = 480;
                    outdoorFanControl.targetSpeed = 600;
                }
            }
        }

        state Heating {
            entry action {
                compressorControl.command = ControlCommand::activateHeatingElement;
                indoorFanControl.command = ControlCommand::setIndoorFanSpeed;
                outdoorFanControl.command = ControlCommand::setOutdoorFanSpeed;
            }
            do action {
                if (targetTemperature - roomTemperature) > 3.0 {
                    compressorControl.targetSpeed = 3600;
                    indoorFanControl.targetSpeed = 1200;
                    outdoorFanControl.targetSpeed = 600;
                } else if (targetTemperature - roomTemperature) > 1.0 {
                    compressorControl.targetSpeed = 2400;
                    indoorFanControl.targetSpeed = 800;
                    outdoorFanControl.targetSpeed = 400;
                } else {
                    compressorControl.targetSpeed = 1800;
                    indoorFanControl.targetSpeed = 600;
                    outdoorFanControl.targetSpeed = 300;
                }
            }
        }

        state FanOnly {
            entry action {
                compressorControl.command = ControlCommand::stopCompressor;
                outdoorFanControl.targetSpeed = 0;
                indoorFanControl.command = ControlCommand::setIndoorFanSpeed;
            }
            do action {
                indoorFanControl.targetSpeed = 360;
            }
        }
    }

    part def ElectronicController {
        port tempSensorIn: ~SensorDataPort;
        port humiditySensorIn: ~SensorDataPort;
        port thermostatIn: ~ThermostatPort;
        port compressorControl: ControlSignalPort;
        port outdoorFanControl: ControlSignalPort;
        port indoorFanControl: ControlSignalPort;

        attribute currentMode: SystemMode = SystemMode::off;
        attribute roomTemperature: TemperatureValue = 25.0;
        attribute roomHumidity: HumidityValue = 50.0;
        attribute targetTemperature: TemperatureValue = 24.0;
        attribute temperatureError: TemperatureValue = 0.0;

        exhibit ControllerStateMachine;
    }

    // ===== Top-level System =====
    part def AirConditioningSystem {
        part compressor: Compressor;
        part condenser: Condenser;
        part outdoorFan: OutdoorFan;
        part expansionValve: ExpansionValve;
        part evaporator: Evaporator;
        part indoorFan: IndoorFan;
        part controller: ElectronicController;
        part tempSensor: TemperatureSensor;
        part humiditySensor: HumiditySensor;
        part thermostat: Thermostat;
        part room: Room;

        // Refrigerant cycle connections
        connection compressorToCondenser connect compressor.refrigerantOut to condenser.refrigerantIn;
        connection condenserToExpansionValve connect condenser.refrigerantOut to expansionValve.refrigerantIn;
        connection expansionValveToEvaporator connect expansionValve.refrigerantOut to evaporator.refrigerantIn;
        connection evaporatorToCompressor connect evaporator.refrigerantOut to compressor.refrigerantIn;

        // Outdoor air flow connections
        connection outdoorFanToCondenser connect outdoorFan.airOut to condenser.airIn;

        // Indoor air flow connections
        connection roomToIndoorFan connect room.airReturn to indoorFan.airIn;
        connection indoorFanToEvaporator connect indoorFan.airOut to evaporator.airIn;
        connection evaporatorToRoom connect evaporator.airOut to room.airSupply;

        // Control signal connections
        connection controllerToCompressor connect controller.compressorControl to compressor.controlIn;
        connection controllerToOutdoorFan connect controller.outdoorFanControl to outdoorFan.controlIn;
        connection controllerToIndoorFan connect controller.indoorFanControl to indoorFan.controlIn;

        // Sensor data connections
        connection tempSensorToController connect tempSensor.dataOut to controller.tempSensorIn;
        connection humiditySensorToController connect humiditySensor.dataOut to controller.humiditySensorIn;
        connection thermostatToController connect thermostat.dataOut to controller.thermostatIn;
    }

    // ===== Requirements =====
    requirement def CoolingCapacityRequirement {
        doc /* The system shall provide a minimum cooling capacity of 5000W. */
        subject acSystem: AirConditioningSystem;
        attribute minCoolingCapacity: PowerValue = 5000;
        require constraint { acSystem.compressor.ratedPower >= minCoolingCapacity }
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall achieve a minimum Energy Efficiency Ratio (EER) of 10.0. */
        subject acSystem: AirConditioningSystem;
        attribute minEER: EnergyEfficiencyValue = 10.0;
        require constraint {
            (acSystem.compressor.ratedPower /
                (acSystem.compressor.ratedPower + acSystem.indoorFan.ratedPower + acSystem.outdoorFan.ratedPower))
                * 3.412 >= minEER
        }
    }

    requirement def TotalPowerConsumptionRequirement {
        doc /* The total power consumption shall not exceed 1500W under normal operation. */
        subject acSystem: AirConditioningSystem;
        attribute maxPower: PowerValue = 1500;
        require constraint {
            acSystem.compressor.ratedPower + acSystem.indoorFan.ratedPower + acSystem.outdoorFan.ratedPower <= maxPower
        }
    }

    requirement def TemperatureControlRequirement {
        doc /* The system shall maintain room temperature within plus or minus 1.0 degC of the set point. */
        subject acSystem: AirConditioningSystem;
        attribute tolerance: TemperatureValue = 1.0;
        require constraint { acSystem.controller.temperatureError <= tolerance }
    }

    requirement def DehumidificationRequirement {
        doc /* The system shall reduce indoor humidity by at least 10 percent when in cooling mode. */
        subject acSystem: AirConditioningSystem;
        attribute minReduction: HumidityValue = 10.0;
        require constraint { acSystem.room.currentHumidity <= 50.0 }
    }

    package ClimateControlRequirements {
        requirement coolingCapacity: CoolingCapacityRequirement;
        requirement energyEfficiency: EnergyEfficiencyRequirement;
        requirement totalPower: TotalPowerConsumptionRequirement;
        requirement temperatureControl: TemperatureControlRequirement;
        requirement dehumidification: DehumidificationRequirement;
    }
}
