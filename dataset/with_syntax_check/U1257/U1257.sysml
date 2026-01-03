package WaterHeatingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def EnergyValue :> ISQ::EnergyValue;
    attribute def PressureValue :> ISQ::PressureValue;
    
    enum def HeaterOperatingMode {
        off;
        heating;
        maintaining;
        standby;
    }
    
    enum def SafetyState {
        normal;
        warning;
        emergency;
    }
    
    item def Water {
        attribute temperature : TemperatureValue;
        attribute volume : VolumeValue;
        attribute flowRate : FlowRateValue;
    }
    
    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    port def WaterFlowPort {
        item water : Water;
    }
    
    port def PowerPort {
        item power : ElectricalPower;
    }
    
    port def ControlSignalPort {
        attribute signalValue : Real;
    }
    
    part def TemperatureSensor {
        attribute measuredTemp : TemperatureValue;
        attribute accuracy : TemperatureValue;
        out port tempOutput : ControlSignalPort;
        
        action def MeasureTemperature {
            out temp : TemperatureValue;
            first start;
            then read;
            action read {
                assign temp = measuredTemp;
            }
            then done;
        }
    }
    
    part def HeatingElement {
        attribute ratedPower : PowerValue;
        attribute currentPower : PowerValue;
        attribute efficiency : Real;
        attribute isActive : Boolean;
        in port powerInput : PowerPort;
        out port heatOutput;
        
        action def Energize {
            in reqPower : PowerValue;
            first start;
            then activate;
            action activate;
            then done;
        }
        
        action def Deenergize {
            first start;
            then deactivate;
            action deactivate;
            then done;
        }
    }
    
    part def Thermostat {
        attribute setpoint : TemperatureValue;
        attribute hysteresis : TemperatureValue;
        attribute upperLimit : TemperatureValue;
        attribute lowerLimit : TemperatureValue;
        in port tempInput : ControlSignalPort;
        out port controlOutput : ControlSignalPort;
        
        action def DetermineHeatingNeed {
            in currentTemp : TemperatureValue;
            in targetTemp : TemperatureValue;
            out heatingRequired : Boolean;
            first start;
            then evaluate;
            action evaluate;
            then done;
        }
    }
    
    part def WaterTank {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        attribute waterTemperature : TemperatureValue;
        attribute insulationRating : Real;
        in port coldWaterInlet : WaterFlowPort;
        out port hotWaterOutlet : WaterFlowPort;
        
        part containedWater : Water {
            attribute :>> temperature = waterTemperature;
            attribute :>> volume = currentVolume;
        }
    }
    
    part def SafetyValve {
        attribute maxPressure : PressureValue;
        attribute releaseThreshold : PressureValue;
        attribute isOpen : Boolean;
        in port pressureInput;
        
        action def CheckPressure {
            in currentPressure : PressureValue;
            out releaseRequired : Boolean;
            first start;
            then check;
            action check;
            then done;
        }
    }
    
    part def ControlUnit {
        attribute operatingMode : HeaterOperatingMode;
        attribute safetyStatus : SafetyState;
        attribute targetTemperature : TemperatureValue;
        attribute maxSafeTemperature : TemperatureValue;
        in port sensorInput : ControlSignalPort;
        in port thermostatInput : ControlSignalPort;
        out port heaterControl : ControlSignalPort;
        out port statusOutput : ControlSignalPort;
        
        perform action controlLoop[*] ordered references RegulateHeating;
    }
    
    part def CirculationPump {
        attribute flowCapacity : FlowRateValue;
        attribute currentFlow : FlowRateValue;
        attribute isRunning : Boolean;
        in port controlInput : ControlSignalPort;
        
        action def StartCirculation {
            in targetFlow : FlowRateValue;
            first start;
            then run;
            action run;
            then done;
        }
        
        action def StopCirculation {
            first start;
            then stop;
            action stop;
            then done;
        }
    }
    
    action def MonitorTemperature {
        in currentTemp : TemperatureValue;
        in targetTemp : TemperatureValue;
        in maxTemp : TemperatureValue;
        out tempDelta : TemperatureValue;
        out overheated : Boolean;
        first start;
        then measure;
        action measure;
        then done;
    }
    
    action def ControlHeating {
        in tempDelta : TemperatureValue;
        in overheated : Boolean;
        in currentMode : HeaterOperatingMode;
        out heatingCommand : Boolean;
        out newMode : HeaterOperatingMode;
        first start;
        then decide;
            if overheated then emergencyStop;
            if tempDelta > 5.0 then startHeating;
            if tempDelta <= 5.0 and tempDelta > 0.0 then maintainHeating;
            if tempDelta <= 0.0 then stopHeating;
        action emergencyStop;
        action startHeating;
        action maintainHeating;
        action stopHeating;
        then done;
    }
    
    action def RegulateHeating {
        in targetTemp : TemperatureValue;
        in maxTemp : TemperatureValue;
        in currentTemp : TemperatureValue;
        in currentMode : HeaterOperatingMode;
        out heatingCommand : Boolean;
        out newMode : HeaterOperatingMode;
        first start;
        then merge controlCycle;
        then action monitor : MonitorTemperature {
            in currentTemp = currentTemp;
            in targetTemp = targetTemp;
            in maxTemp = maxTemp;
            out tempDelta : TemperatureValue;
            out overheated : Boolean;
        }
        then action control : ControlHeating {
            in tempDelta = monitor.tempDelta;
            in overheated = monitor.overheated;
            in currentMode = currentMode;
            out heatingCommand : Boolean;
            out newMode : HeaterOperatingMode;
        }
        then decide;
            if control.heatingCommand then activateHeater;
            if !control.heatingCommand then deactivateHeater;
        action activateHeater;
        then controlCycle;
        action deactivateHeater;
        then controlCycle;
    }
    
    state def WaterHeaterStateMachine {
        entry; then idle;
        
        state idle;
        transition idle_to_heating
            first idle
            accept StartHeatingSignal
            then heating;
        
        state heating;
        transition heating_to_maintaining
            first heating
            accept TargetTempReachedSignal
            then maintaining;
        
        state maintaining;
        transition maintaining_to_heating
            first maintaining
            accept TempDroppedSignal
            then heating;
        
        transition maintaining_to_standby
            first maintaining
            accept NoFlowSignal
            then standby;
        
        state standby;
        transition standby_to_heating
            first standby
            accept FlowDetectedSignal
            then heating;
        
        transition any_to_idle
            first heating, maintaining, standby
            accept EmergencyStopSignal
            then idle;
    }
    
    part def WaterHeater {
        attribute targetTemperature : TemperatureValue;
        attribute maxSafeTemperature : TemperatureValue;
        attribute minOperatingTemperature : TemperatureValue;
        attribute totalPowerConsumption : PowerValue;
        attribute heatingEfficiency : Real;
        
        in port coldWaterSupply : WaterFlowPort;
        out port hotWaterDelivery : WaterFlowPort;
        in port electricalSupply : PowerPort;
        out port systemStatus : ControlSignalPort;
        
        part tank : WaterTank {
            attribute :>> capacity = 200.0 [SI::L];
            attribute :>> currentVolume = 200.0 [SI::L];
            attribute :>> waterTemperature = 293.15 [SI::K];
            attribute :>> insulationRating = 0.85;
        }
        
        part primaryHeater : HeatingElement {
            attribute :>> ratedPower = 4500.0 [SI::W];
            attribute :>> currentPower = 0.0 [SI::W];
            attribute :>> efficiency = 0.95;
            attribute :>> isActive = false;
        }
        
        part secondaryHeater : HeatingElement {
            attribute :>> ratedPower = 2000.0 [SI::W];
            attribute :>> currentPower = 0.0 [SI::W];
            attribute :>> efficiency = 0.92;
            attribute :>> isActive = false;
        }
        
        part tempSensor : TemperatureSensor {
            attribute :>> measuredTemp = tank.waterTemperature;
            attribute :>> accuracy = 0.5 [SI::K];
        }
        
        part thermostat : Thermostat {
            attribute :>> setpoint = targetTemperature;
            attribute :>> hysteresis = 3.0 [SI::K];
            attribute :>> upperLimit = maxSafeTemperature;
            attribute :>> lowerLimit = minOperatingTemperature;
        }
        
        part controller : ControlUnit {
            attribute :>> operatingMode = HeaterOperatingMode::off;
            attribute :>> safetyStatus = SafetyState::normal;
            attribute :>> targetTemperature = targetTemperature;
            attribute :>> maxSafeTemperature = maxSafeTemperature;
        }
        
        part safetyValve : SafetyValve {
            attribute :>> maxPressure = 1000.0 [SI::kPa];
            attribute :>> releaseThreshold = 850.0 [SI::kPa];
            attribute :>> isOpen = false;
        }
        
        part circulationPump : CirculationPump {
            attribute :>> flowCapacity = 15.0 [SI::'L/min'];
            attribute :>> currentFlow = 0.0 [SI::'L/min'];
            attribute :>> isRunning = false;
        }
        
        connection coldWaterInlet connect coldWaterSupply to tank.coldWaterInlet;
        connection hotWaterOutlet connect tank.hotWaterOutlet to hotWaterDelivery;
        connection powerToPrimaryHeater connect electricalSupply to primaryHeater.powerInput;
        connection powerToSecondaryHeater connect electricalSupply to secondaryHeater.powerInput;
        connection tempMonitoring connect tempSensor.tempOutput to thermostat.tempInput;
        connection thermostatControl connect thermostat.controlOutput to controller.thermostatInput;
        connection sensorToController connect tempSensor.tempOutput to controller.sensorInput;
        connection controllerToHeater connect controller.heaterControl to primaryHeater.powerInput;
        connection statusOutput connect controller.statusOutput to systemStatus;
        
        perform action heatingOperation : RegulateHeating {
            in targetTemp = targetTemperature;
            in maxTemp = maxSafeTemperature;
            in currentTemp = tank.waterTemperature;
            in currentMode = controller.operatingMode;
        }
        
        exhibit state heaterBehavior : WaterHeaterStateMachine;
    }
    
    requirement def WaterHeaterRequirements {
        doc /* Top-level requirements for the water heating system */
        
        requirement <'REQ-WH-001'> heatingCapability {
            doc /* The system shall heat water from ambient temperature 
                 * (20°C) to the target temperature (60°C) within 90 minutes 
                 * for a full 200-liter tank.
                 */
            subject heater : WaterHeater;
        }
        
        requirement <'REQ-WH-002'> temperatureMaintenance {
            doc /* The system shall maintain water temperature within 
                 * ±3°C of the target temperature during standby operation.
                 */
            subject heater : WaterHeater;
            assert constraint {
                heater.tank.waterTemperature >= heater.targetTemperature - 3.0 [SI::K] and
                heater.tank.waterTemperature <= heater.targetTemperature + 3.0 [SI::K]
            }
        }
        
        requirement <'REQ-WH-003'> safetyLimit {
            doc /* The system shall prevent water temperature from exceeding 
                 * the maximum safe temperature (85°C) to prevent scalding 
                 * and equipment damage.
                 */
            subject heater : WaterHeater;
            assert constraint {
                heater.tank.waterTemperature <= heater.maxSafeTemperature
            }
        }
        
        requirement <'REQ-WH-004'> energyEfficiency {
            doc /* The system shall achieve a minimum heating efficiency 
                 * of 90% to minimize energy consumption and operating costs.
                 */
            subject heater : WaterHeater;
            assert constraint {
                heater.heatingEfficiency >= 0.90
            }
        }
        
        requirement <'REQ-WH-005'> continuousOperation {
            doc /* The system shall operate continuously with automatic 
                 * temperature regulation, cycling heating elements on and 
                 * off as needed to maintain target temperature.
                 */
            subject heater : WaterHeater;
        }
        
        requirement <'REQ-WH-006'> pressureRelief {
            doc /* The system shall include a pressure relief valve that 
                 * activates at 850 kPa to prevent tank rupture.
                 */
            subject heater : WaterHeater;
            assert constraint {
                heater.safetyValve.releaseThreshold <= 850.0 [SI::kPa]
            }
        }
        
        requirement <'REQ-WH-007'> hotWaterDelivery {
            doc /* The system shall deliver hot water at the target 
                 * temperature with a flow rate of at least 10 L/min.
                 */
            subject heater : WaterHeater;
        }
    }
    
    part residentialWaterHeater : WaterHeater {
        attribute :>> targetTemperature = 333.15 [SI::K];
        attribute :>> maxSafeTemperature = 358.15 [SI::K];
        attribute :>> minOperatingTemperature = 313.15 [SI::K];
        attribute :>> totalPowerConsumption = 6500.0 [SI::W];
        attribute :>> heatingEfficiency = 0.93;
        
        part :>> tank {
            attribute :>> capacity = 200.0 [SI::L];
            attribute :>> currentVolume = 200.0 [SI::L];
            attribute :>> waterTemperature = 293.15 [SI::K];
        }
        
        part :>> primaryHeater {
            attribute :>> ratedPower = 4500.0 [SI::W];
        }
        
        part :>> secondaryHeater {
            attribute :>> ratedPower = 2000.0 [SI::W];
        }
        
        part :>> thermostat {
            attribute :>> setpoint = 333.15 [SI::K];
            attribute :>> hysteresis = 3.0 [SI::K];
        }
    }
    
    satisfy WaterHeaterRequirements::heatingCapability by residentialWaterHeater;
    satisfy WaterHeaterRequirements::temperatureMaintenance by residentialWaterHeater;
    satisfy WaterHeaterRequirements::safetyLimit by residentialWaterHeater;
    satisfy WaterHeaterRequirements::energyEfficiency by residentialWaterHeater;
    satisfy WaterHeaterRequirements::continuousOperation by residentialWaterHeater;
    satisfy WaterHeaterRequirements::pressureRelief by residentialWaterHeater.safetyValve;
    satisfy WaterHeaterRequirements::hotWaterDelivery by residentialWaterHeater;
}
