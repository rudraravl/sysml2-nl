package 'HVAC Climate Control System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityPercentage :> Real;
    attribute def AirFlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def PowerConsumptionValue :> ISQ::PowerValue;
    attribute def PressureValue :> ISQ::PressureValue;

    enum def SystemMode {
        off;
        heating;
        cooling;
        ventilating;
        auto;
    }

    enum def FanSpeedLevel {
        off;
        low;
        medium;
        high;
        automatic;
    }

    item def SensorReading {
        attribute timestamp : Real;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityPercentage;
    }

    item def ControlCommand {
        attribute mode : SystemMode;
        attribute fanSpeed : FanSpeedLevel;
        attribute targetTemperature : TemperatureValue;
    }

    item def ActuatorSignal {
        attribute compressorOn : Boolean;
        attribute heaterOn : Boolean;
        attribute fanSpeed : FanSpeedLevel;
        attribute damperPosition : Real;
    }

    port def SensorDataPort {
        out sensorData : SensorReading;
    }

    port def ControlCommandPort {
        in command : ControlCommand;
    }

    port def ActuatorCommandPort {
        out signal : ActuatorSignal;
    }

    port def AirFlowPort {
        inout airFlow : AirFlowRateValue;
        inout airTemperature : TemperatureValue;
    }

    port def PowerSupplyPort {
        in powerInput : PowerConsumptionValue;
    }

    part def TemperatureSensor {
        port dataOutput : SensorDataPort;
        attribute measuredTemperature : TemperatureValue;
        attribute measuredHumidity : HumidityPercentage;

        action sense {
            out reading : SensorReading;
            first start;
            then assign reading.temperature := measuredTemperature;
            then assign reading.humidity := measuredHumidity;
            then done;
        }
    }

    part def Thermostat {
        port sensorInput : SensorDataPort;
        port commandOutput : ControlCommandPort;

        attribute setpointTemperature : TemperatureValue;
        attribute temperatureDeadband : TemperatureValue;
        attribute currentMode : SystemMode;
        attribute currentTemperature : TemperatureValue;

        action evaluateConditions {
            in sensorReading : SensorReading;
            out controlCmd : ControlCommand;

            first start;
            then assign currentTemperature := sensorReading.temperature;
            then decide;
                if currentTemperature < (setpointTemperature - temperatureDeadband) then requestHeating;
                if currentTemperature > (setpointTemperature + temperatureDeadband) then requestCooling;
                else requestIdle;

            action requestHeating {
                then assign controlCmd.mode := SystemMode::heating;
                then assign controlCmd.fanSpeed := FanSpeedLevel::medium;
                then assign controlCmd.targetTemperature := setpointTemperature;
            }

            action requestCooling {
                then assign controlCmd.mode := SystemMode::cooling;
                then assign controlCmd.fanSpeed := FanSpeedLevel::high;
                then assign controlCmd.targetTemperature := setpointTemperature;
            }

            action requestIdle {
                then assign controlCmd.mode := SystemMode::ventilating;
                then assign controlCmd.fanSpeed := FanSpeedLevel::low;
                then assign controlCmd.targetTemperature := setpointTemperature;
            }

            then done;
        }
    }

    part def Compressor {
        port control : ControlCommandPort;
        port power : PowerSupplyPort;

        attribute isOperating : Boolean;
        attribute coolingCapacity : PowerConsumptionValue;
        attribute powerDraw : PowerConsumptionValue;

        action operateCompressor {
            in cmd : ControlCommand;
            first start;
            then decide;
                if cmd.mode == SystemMode::cooling then activateCompressor;
                else deactivateCompressor;
            
            action activateCompressor {
                then assign isOperating := true;
                then assign powerDraw := coolingCapacity;
            }
            
            action deactivateCompressor {
                then assign isOperating := false;
                then assign powerDraw := 0.0 [SI::W];
            }
            
            then done;
        }
    }

    part def Furnace {
        port control : ControlCommandPort;
        port power : PowerSupplyPort;

        attribute isHeating : Boolean;
        attribute heatingCapacity : PowerConsumptionValue;
        attribute powerDraw : PowerConsumptionValue;

        action operateFurnace {
            in cmd : ControlCommand;
            first start;
            then decide;
                if cmd.mode == SystemMode::heating then activateFurnace;
                else deactivateFurnace;
            
            action activateFurnace {
                then assign isHeating := true;
                then assign powerDraw := heatingCapacity;
            }
            
            action deactivateFurnace {
                then assign isHeating := false;
                then assign powerDraw := 0.0 [SI::W];
            }
            
            then done;
        }
    }

    part def BlowerFan {
        port control : ControlCommandPort;
        port power : PowerSupplyPort;
        port airOutput : AirFlowPort;

        attribute currentSpeed : FanSpeedLevel;
        attribute airFlowRate : AirFlowRateValue;
        attribute powerDraw : PowerConsumptionValue;

        action adjustFanSpeed {
            in targetSpeed : FanSpeedLevel;
            out resultingFlow : AirFlowRateValue;

            first start;
            then assign currentSpeed := targetSpeed;
            then decide;
                if currentSpeed == FanSpeedLevel::low then setLowFlow;
                if currentSpeed == FanSpeedLevel::medium then setMediumFlow;
                if currentSpeed == FanSpeedLevel::high then setHighFlow;
                else setOffFlow;

            action setLowFlow {
                then assign resultingFlow := 0.3 [SI::'m³/s'];
                then assign powerDraw := 150.0 [SI::W];
            }

            action setMediumFlow {
                then assign resultingFlow := 0.6 [SI::'m³/s'];
                then assign powerDraw := 300.0 [SI::W];
            }

            action setHighFlow {
                then assign resultingFlow := 1.0 [SI::'m³/s'];
                then assign powerDraw := 500.0 [SI::W];
            }

            action setOffFlow {
                then assign resultingFlow := 0.0 [SI::'m³/s'];
                then assign powerDraw := 0.0 [SI::W];
            }

            then assign airFlowRate := resultingFlow;
            then done;
        }
    }

    part def AirHandler {
        port airIntake : AirFlowPort;
        port airSupply : AirFlowPort;
        port controlInput : ControlCommandPort;

        part blower : BlowerFan;
        part filterAssembly;
        part heatExchanger;

        attribute supplyAirTemperature : TemperatureValue;
        attribute supplyAirFlow : AirFlowRateValue;
    }

    part def DuctSystem {
        port supplyInlet : AirFlowPort;
        port supplyOutlet : AirFlowPort;
        port returnInlet : AirFlowPort;
        port returnOutlet : AirFlowPort;

        attribute ductLength : ISQ::LengthValue;
        attribute ductDiameter : ISQ::LengthValue;
        attribute pressureDrop : PressureValue;
    }

    part def ConditionedSpace {
        port supplyAir : AirFlowPort;
        port returnAir : AirFlowPort;
        port sensing : SensorDataPort;

        attribute spaceVolume : ISQ::VolumeValue;
        attribute spaceTemperature : TemperatureValue;
        attribute spaceHumidity : HumidityPercentage;
        attribute heatLoad : PowerConsumptionValue;
    }

    part def HVACSystem {
        attribute systemSetpoint : TemperatureValue;
        attribute systemDeadband : TemperatureValue;
        attribute totalPowerConsumption : PowerConsumptionValue;
        attribute operatingMode : SystemMode;

        part indoorSensor : TemperatureSensor {
            attribute :>> measuredTemperature = 22.0 [SI::K];
            attribute :>> measuredHumidity = 50.0;
        }

        part thermostat : Thermostat {
            attribute :>> setpointTemperature = 22.0 [SI::K];
            attribute :>> temperatureDeadband = 1.0 [SI::K];
            attribute :>> currentMode = SystemMode::auto;
        }

        part compressor : Compressor {
            attribute :>> coolingCapacity = 3500.0 [SI::W];
        }

        part furnace : Furnace {
            attribute :>> heatingCapacity = 5000.0 [SI::W];
        }

        part airHandler : AirHandler {
            attribute :>> supplyAirFlow = 0.8 [SI::'m³/s'];
        }

        part supplyDuct : DuctSystem {
            attribute :>> ductLength = 20.0 [SI::m];
            attribute :>> ductDiameter = 0.3 [SI::m];
        }

        part returnDuct : DuctSystem {
            attribute :>> ductLength = 18.0 [SI::m];
            attribute :>> ductDiameter = 0.35 [SI::m];
        }

        part conditionedSpace : ConditionedSpace {
            attribute :>> spaceVolume = 150.0 [SI::'m³'];
            attribute :>> spaceTemperature = 22.0 [SI::K];
            attribute :>> spaceHumidity = 50.0;
            attribute :>> heatLoad = 2000.0 [SI::W];
        }

        connect conditionedSpace.sensing to indoorSensor.dataOutput;
        connect indoorSensor.dataOutput to thermostat.sensorInput;
        connect thermostat.commandOutput to compressor.control;
        connect thermostat.commandOutput to furnace.control;
        connect thermostat.commandOutput to airHandler.controlInput;
        connect airHandler.airSupply to supplyDuct.supplyInlet;
        connect supplyDuct.supplyOutlet to conditionedSpace.supplyAir;
        connect conditionedSpace.returnAir to returnDuct.returnInlet;
        connect returnDuct.returnOutlet to airHandler.airIntake;

        perform action climateRegulation[*] ordered;
    }

    action def MonitorEnvironment {
        in sensor : TemperatureSensor;
        out environmentData : SensorReading;
    }

    action def DetermineControlAction {
        in thermostat : Thermostat;
        in sensorData : SensorReading;
        out controlDecision : ControlCommand;
    }

    action def ActivateHeating {
        in furnace : Furnace;
        in blower : BlowerFan;
        in heatingDemand : Real;
    }

    action def ActivateCooling {
        in compressor : Compressor;
        in blower : BlowerFan;
        in coolingDemand : Real;
    }

    action def CirculateAir {
        in blower : BlowerFan;
        in targetFlow : AirFlowRateValue;
    }

    action climateRegulation : ClimateRegulation {
        first start;
        then merge controlLoop;

        then action monitorEnvironment : MonitorEnvironment {
            in sensor = hvacSystem.indoorSensor;
            out environmentData envData;
        }

        then action determineControl : DetermineControlAction {
            in thermostat = hvacSystem.thermostat;
            in sensorData = monitorEnvironment.envData;
            out controlDecision decision;
        }

        then decide;
            if determineControl.decision.mode == SystemMode::heating then activateHeating;
            if determineControl.decision.mode == SystemMode::cooling then activateCooling;
            if determineControl.decision.mode == SystemMode::ventilating then activateVentilation;
            else maintainOff;

        action activateHeating : ActivateHeating {
            in furnace = hvacSystem.furnace;
            in blower = hvacSystem.airHandler.blower;
            in heatingDemand = 0.75;
        }
        then controlLoop;

        action activateCooling : ActivateCooling {
            in compressor = hvacSystem.compressor;
            in blower = hvacSystem.airHandler.blower;
            in coolingDemand = 0.85;
        }
        then controlLoop;

        action activateVentilation : CirculateAir {
            in blower = hvacSystem.airHandler.blower;
            in targetFlow = 0.4 [SI::'m³/s'];
        }
        then controlLoop;

        action maintainOff;
        then controlLoop;
    }

    part hvacSystem : HVACSystem {
        perform action climateRegulation[*] ordered;
    }

    requirement def TemperatureControlRequirement {
        doc /* The HVAC system shall maintain the conditioned space temperature within the specified deadband of the setpoint temperature. */

        subject system : HVACSystem;

        require constraint temperatureWithinDeadband {
            abs(system.conditionedSpace.spaceTemperature - system.thermostat.setpointTemperature) 
                <= system.thermostat.temperatureDeadband
        }
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The HVAC system shall operate with total power consumption not exceeding the combined rated capacity of all components. */

        subject system : HVACSystem;

        require constraint powerConsumptionLimit {
            system.totalPowerConsumption <= 10000.0 [SI::W]
        }
    }

    requirement def AirQualityRequirement {
        doc /* The HVAC system shall provide continuous air circulation with minimum airflow rate to ensure adequate ventilation. */

        subject system : HVACSystem;

        require constraint minimumVentilation {
            system.airHandler.supplyAirFlow >= 0.3 [SI::'m³/s']
        }
    }

    requirement def SystemReliabilityRequirement {
        doc /* The HVAC system shall respond to temperature deviations by activating appropriate heating or cooling within one control cycle. */

        subject system : HVACSystem;
    }

    requirement <'HVAC-REQ-001'> temperatureControl : TemperatureControlRequirement {
        subject system = hvacSystem;
    }

    requirement <'HVAC-REQ-002'> energyEfficiency : EnergyEfficiencyRequirement {
        subject system = hvacSystem;
    }

    requirement <'HVAC-REQ-003'> airQuality : AirQualityRequirement {
        subject system = hvacSystem;
    }

    requirement <'HVAC-REQ-004'> systemReliability : SystemReliabilityRequirement {
        subject system = hvacSystem;
    }

    requirement <'HVAC-MISSION'> hvacMissionRequirement {
        doc /* The HVAC system shall automatically regulate indoor climate conditions by continuously monitoring 
                temperature and humidity, then activating heating, cooling, or ventilation modes as needed to maintain 
                occupant comfort at the desired setpoint while ensuring energy-efficient operation and adequate air quality. */

        assume constraint buildingEnclosure {
            doc /* The conditioned space is properly insulated and sealed to minimize heat transfer with the external environment. */
        }

        assume constraint powerAvailability {
            doc /* Electrical power supply is continuously available to support all HVAC components. */
        }

        require temperatureControl;
        require energyEfficiency;
        require airQuality;
        require systemReliability;
    }
}
