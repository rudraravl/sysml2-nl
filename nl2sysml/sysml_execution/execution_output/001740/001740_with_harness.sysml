package AirConditioningSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityValue :> Real;
    attribute def AirFlowRateValue :> Real;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def PressureValue :> ISQ::PressureValue;
    
    enum def OperatingMode {
        off;
        cooling;
        heating;
        fan;
        auto;
    }
    
    enum def FanSpeed {
        low;
        medium;
        high;
        auto;
    }
    
    item def Refrigerant {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute flowRate : Real;
    }
    
    item def AirStream {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute flowRate : AirFlowRateValue;
    }
    
    port def RefrigerantPort {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }
    
    port def AirFlowPort {
        attribute flowRate : AirFlowRateValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
    }
    
    port def ElectricalPort {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : PowerValue;
    }
    
    port def ControlPort {
        attribute signal : Boolean;
    }
    
    part def Compressor {
        port electricalIn : ElectricalPort;
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port controlIn : ControlPort;
        
        attribute powerConsumption : PowerValue;
        attribute compressionRatio : Real;
        attribute efficiency : Real;
        attribute isRunning : Boolean;
        
        action compress {
            in lowPressureRefrigerant : Refrigerant;
            out highPressureRefrigerant : Refrigerant;
        }
    }
    
    part def Condenser {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port airFlow : AirFlowPort;
        
        attribute heatRejection : PowerValue;
        attribute surfaceArea : Real;
        attribute effectiveness : Real;
        
        action condense {
            in hotRefrigerant : Refrigerant;
            in ambientAir : AirStream;
            out cooledRefrigerant : Refrigerant;
            out heatedAir : AirStream;
        }
    }
    
    part def ExpansionValve {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        
        attribute openingPercentage : Real;
        attribute flowCoefficient : Real;
        
        action expand {
            in highPressureRefrigerant : Refrigerant;
            out lowPressureRefrigerant : Refrigerant;
        }
    }
    
    part def Evaporator {
        port refrigerantIn : RefrigerantPort;
        port refrigerantOut : RefrigerantPort;
        port airFlowIn : AirFlowPort;
        port airFlowOut : AirFlowPort;
        
        attribute heatAbsorption : PowerValue;
        attribute surfaceArea : Real;
        attribute effectiveness : Real;
        
        action evaporate {
            in coldRefrigerant : Refrigerant;
            in warmAir : AirStream;
            out heatedRefrigerant : Refrigerant;
            out cooledAir : AirStream;
        }
    }
    
    part def Fan {
        port electricalIn : ElectricalPort;
        port airFlowOut : AirFlowPort;
        port controlIn : ControlPort;
        
        attribute speed : FanSpeed;
        attribute powerConsumption : PowerValue;
        attribute airFlowRate : AirFlowRateValue;
        attribute isRunning : Boolean;
        
        action blowAir {
            in speedSetting : FanSpeed;
            out airFlow : AirStream;
        }
    }
    
    part def TemperatureSensor {
        port sensing : AirFlowPort;
        
        attribute measuredTemperature : TemperatureValue;
        attribute accuracy : Real;
        
        action measureTemperature {
            out temperature : TemperatureValue;
        }
    }
    
    part def HumiditySensor {
        port sensing : AirFlowPort;
        
        attribute measuredHumidity : HumidityValue;
        attribute accuracy : Real;
        
        action measureHumidity {
            out humidity : HumidityValue;
        }
    }
    
    part def Thermostat {
        attribute setPoint : TemperatureValue;
        attribute hysteresis : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        
        action controlTemperature {
            in desiredTemp : TemperatureValue;
            in actualTemp : TemperatureValue;
            out controlSignal : Boolean;
        }
    }
    
    action def StartCompressor;
    action def StopCompressor;
    action def StartIndoorFan;
    action def StopIndoorFan;
    action def StartOutdoorFan;
    action def StopOutdoorFan;
    action def StartHeater;
    action def IncreaseCompressorSpeed;
    action def DecreaseCompressorSpeed;
    action def IncreaseFanSpeed;
    action def DecreaseFanSpeed;
    
    part def AirConditioningController {
        port powerIn : ElectricalPort;
        port compressorControl : ControlPort;
        port indoorFanControl : ControlPort;
        port outdoorFanControl : ControlPort;
        
        attribute mode : OperatingMode;
        attribute targetTemperature : TemperatureValue;
        attribute fanSpeed : FanSpeed;
        attribute currentTemperature : TemperatureValue;
        
        exhibit state operationControl {
            entry; then off;
            
            state off {
                entry action stopAllComponents {
                    perform StartCompressor;
                    perform StopIndoorFan;
                    perform StopOutdoorFan;
                }
            }
            
            state cooling {
                entry action startCoolingMode {
                    perform StartCompressor;
                    perform StartIndoorFan;
                    perform StartOutdoorFan;
                }
                
                do action regulateCooling {
                    first start;
                    then merge monitorLoop;
                    then action checkTemperature {
                        out temp : TemperatureValue;
                    }
                    then decide;
                        if checkTemperature.temp > targetTemperature + 1.0 then increaseCooling;
                        if checkTemperature.temp < targetTemperature - 1.0 then decreaseCooling;
                        else maintainCooling;
                    action increaseCooling {
                        perform IncreaseCompressorSpeed;
                        perform IncreaseFanSpeed;
                    }
                    then monitorLoop;
                    action decreaseCooling {
                        perform DecreaseCompressorSpeed;
                        perform DecreaseFanSpeed;
                    }
                    then monitorLoop;
                    action maintainCooling;
                    then monitorLoop;
                }
            }
            
            state heating {
                entry action startHeatingMode {
                    perform StartHeater;
                    perform StartIndoorFan;
                }
                
                do action regulateHeating {
                    action monitorTemp;
                    then action adjustHeat;
                }
            }
            
            state fan {
                entry action startFanOnlyMode {
                    perform StartIndoorFan;
                }
            }
            
            state auto {
                entry action enableAutoMode;
                
                do action autoRegulate {
                    first start;
                    then merge autoLoop;
                    then action sense {
                        out temp : TemperatureValue;
                    }
                    then decide;
                        if sense.temp > targetTemperature + 2.0 then switchToCooling;
                        if sense.temp < targetTemperature - 2.0 then switchToHeating;
                        else maintainAuto;
                    action switchToCooling;
                    then cooling;
                    action switchToHeating;
                    then heating;
                    action maintainAuto;
                    then autoLoop;
                }
            }
            
            transition off_to_cooling
                first off
                if mode == OperatingMode::cooling
                then cooling;
                
            transition cooling_to_off
                first cooling
                if mode == OperatingMode::off
                then off;
                
            transition off_to_heating
                first off
                if mode == OperatingMode::heating
                then heating;
                
            transition heating_to_off
                first heating
                if mode == OperatingMode::off
                then off;
                
            transition off_to_fan
                first off
                if mode == OperatingMode::fan
                then fan;
                
            transition fan_to_off
                first fan
                if mode == OperatingMode::off
                then off;
                
            transition off_to_auto
                first off
                if mode == OperatingMode::auto
                then auto;
                
            transition auto_to_off
                first auto
                if mode == OperatingMode::off
                then off;
        }
    }
    
    part def AirConditioningUnit {
        attribute totalPowerConsumption : PowerValue;
        attribute coolingCapacity : PowerValue;
        attribute heatingCapacity : PowerValue;
        attribute energyEfficiencyRatio : Real;
        attribute seasonalEnergyEfficiencyRatio : Real;
        
        part compressor : Compressor {
            attribute :>> powerConsumption = 1500.0 [SI::W];
            attribute :>> compressionRatio = 3.5;
            attribute :>> efficiency = 0.85;
        }
        
        part condenser : Condenser {
            attribute :>> heatRejection = 5000.0 [SI::W];
            attribute :>> surfaceArea = 3.0;
            attribute :>> effectiveness = 0.75;
        }
        
        part expansionValve : ExpansionValve {
            attribute :>> openingPercentage = 50.0;
            attribute :>> flowCoefficient = 0.8;
        }
        
        part evaporator : Evaporator {
            attribute :>> heatAbsorption = 3500.0 [SI::W];
            attribute :>> surfaceArea = 2.5;
            attribute :>> effectiveness = 0.80;
        }
        
        part indoorFan : Fan {
            attribute :>> speed = FanSpeed::medium;
            attribute :>> powerConsumption = 75.0 [SI::W];
            attribute :>> airFlowRate = 450.0;
        }
        
        part outdoorFan : Fan {
            attribute :>> speed = FanSpeed::high;
            attribute :>> powerConsumption = 100.0 [SI::W];
            attribute :>> airFlowRate = 600.0;
        }
        
        part roomTempSensor : TemperatureSensor {
            attribute :>> accuracy = 0.5;
        }
        
        part roomHumiditySensor : HumiditySensor {
            attribute :>> accuracy = 2.0;
        }
        
        part thermostat : Thermostat {
            attribute :>> setPoint = 297.0 [SI::K];
            attribute :>> hysteresis = 1.0 [SI::K];
        }
        
        part controller : AirConditioningController {
            attribute :>> mode = OperatingMode::auto;
            attribute :>> targetTemperature = 297.0 [SI::K];
            attribute :>> fanSpeed = FanSpeed::auto;
        }
        
        connection refrigerantCycle1 connect compressor.refrigerantOut to condenser.refrigerantIn;
        connection refrigerantCycle2 connect condenser.refrigerantOut to expansionValve.refrigerantIn;
        connection refrigerantCycle3 connect expansionValve.refrigerantOut to evaporator.refrigerantIn;
        connection refrigerantCycle4 connect evaporator.refrigerantOut to compressor.refrigerantIn;
        
        connection airFlow1 connect indoorFan.airFlowOut to evaporator.airFlowIn;
        connection airFlow2 connect outdoorFan.airFlowOut to condenser.airFlow;
        
        connection control1 connect controller.compressorControl to compressor.controlIn;
        connection control2 connect controller.indoorFanControl to indoorFan.controlIn;
        connection control3 connect controller.outdoorFanControl to outdoorFan.controlIn;
        
        assert constraint powerBalance {
            totalPowerConsumption == compressor.powerConsumption + 
                                     indoorFan.powerConsumption + 
                                     outdoorFan.powerConsumption
        }
        
        assert constraint efficiencyRequirement {
            energyEfficiencyRatio >= 3.0
        }
        
        assert constraint coolingCapacityCalculation {
            coolingCapacity == evaporator.heatAbsorption
        }
    }
    
    part def ConditionedSpace {
        attribute volume : Real;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute heatLoad : PowerValue;
        
        port supplyAir : AirFlowPort;
        port returnAir : AirFlowPort;
    }
    
    action def ClimateControl {
        first start;
        then merge monitoringLoop;
        
        then action readSensors {
            out currentTemp : TemperatureValue;
            out currentHumidity : HumidityValue;
        }
        
        then action evaluateConditions {
            in temp : TemperatureValue;
            in humidity : HumidityValue;
            in setpoint : TemperatureValue;
            out needsCooling : Boolean;
            out needsHeating : Boolean;
        }
        
        then decide;
            if evaluateConditions.needsCooling then activateCooling;
            if evaluateConditions.needsHeating then activateHeating;
            else maintainConditions;
            
        action activateCooling {
            action startCompressor;
            then action startFans;
            then action circulateRefrigerant;
        }
        then monitoringLoop;
        
        action activateHeating {
            action startHeater;
            then action startFan;
        }
        then monitoringLoop;
        
        action maintainConditions;
        then monitoringLoop;
    }
    
    requirement <'REQ-AC-001'> primaryFunction {
        doc /* The air conditioning system shall regulate indoor air temperature 
             * and humidity to maintain comfortable environmental conditions by 
             * removing heat and moisture from the conditioned space.
             */
        subject acUnit : AirConditioningUnit;
    }
    
    requirement <'REQ-AC-002'> coolingCapacityRequirement {
        doc /* The system shall provide sufficient cooling capacity to reduce 
             * room temperature from 308 K (35°C) to 297 K (24°C) within 30 minutes 
             * for a standard room volume of 50 cubic meters.
             */
        subject acUnit : AirConditioningUnit;
        assert constraint {
            acUnit.coolingCapacity >= 3500.0 [SI::W]
        }
    }
    
    requirement <'REQ-AC-003'> energyEfficiency {
        doc /* The system shall maintain an energy efficiency ratio (EER) 
             * of at least 3.0 to minimize power consumption and operating costs.
             */
        subject acUnit : AirConditioningUnit;
        assert constraint {
            acUnit.energyEfficiencyRatio >= 3.0
        }
    }
    
    requirement <'REQ-AC-004'> temperatureControl {
        doc /* The system shall maintain room temperature within ±1 K 
             * of the set point during normal operation.
             */
        subject controller : AirConditioningController;
        assert constraint {
            controller.targetTemperature - 1.0 [SI::K] <= controller.currentTemperature and
            controller.currentTemperature <= controller.targetTemperature + 1.0 [SI::K]
        }
    }
    
    requirement <'REQ-AC-005'> operationalModes {
        doc /* The system shall support multiple operating modes including 
             * cooling, heating, fan-only, and automatic mode to accommodate 
             * varying environmental conditions and user preferences.
             */
        subject controller : AirConditioningController;
    }
    
    requirement <'REQ-AC-006'> powerConsumption {
        doc /* The total power consumption of the system shall not exceed 
             * 2000 W during peak cooling operation.
             */
        subject acUnit : AirConditioningUnit;
        assert constraint {
            acUnit.totalPowerConsumption <= 2000.0 [SI::W]
        }
    }
    
    part airConditioningSystem : AirConditioningUnit {
        attribute :>> coolingCapacity = 3500.0 [SI::W];
        attribute :>> heatingCapacity = 3000.0 [SI::W];
        attribute :>> energyEfficiencyRatio = 3.2;
        attribute :>> seasonalEnergyEfficiencyRatio = 14.0;
        attribute :>> totalPowerConsumption = 1675.0 [SI::W];
        
        perform action climateControl : ClimateControl;
    }
    
    part conditionedRoom : ConditionedSpace {
        attribute :>> volume = 50.0;
        attribute :>> currentTemperature = 300.0 [SI::K];
        attribute :>> currentHumidity = 60.0;
        attribute :>> heatLoad = 2000.0 [SI::W];
    }
    
    connection supplyAirConnection connect airConditioningSystem.evaporator.airFlowOut to conditionedRoom.supplyAir;
    connection returnAirConnection connect conditionedRoom.returnAir to airConditioningSystem.evaporator.airFlowIn;
    
    satisfy primaryFunction by airConditioningSystem;
    satisfy coolingCapacityRequirement by airConditioningSystem;
    satisfy energyEfficiency by airConditioningSystem;
    satisfy temperatureControl by airConditioningSystem.controller;
    satisfy operationalModes by airConditioningSystem.controller;
    satisfy powerConsumption by airConditioningSystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import AirConditioningSystem::*;
}
