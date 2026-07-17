package 'Water Cooling System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def CoolantTemperature :> ThermodynamicTemperatureValue;
    attribute def FlowRate :> VolumeFlowRateValue;
    attribute def PumpSpeed :> AngularVelocityValue;
    attribute def HeatLoad :> PowerValue;
    attribute def PressureLevel :> PressureValue;
    attribute def FanSpeed :> AngularVelocityValue;
    
    attribute def TemperatureSetpoint {
        attribute target : CoolantTemperature;
        attribute tolerance : ThermodynamicTemperatureValue;
    }
    
    item def Coolant {
        attribute temperature : CoolantTemperature;
        attribute flowRate : FlowRate;
        attribute pressure : PressureLevel;
    }
    
    port def CoolantPort {
        out item coolant : Coolant;
    }
    
    port def HeatSourcePort {
        attribute heatGenerated : HeatLoad;
        attribute surfaceTemp : CoolantTemperature;
    }
    
    port def ControlPort {
        attribute commandSignal : Real;
    }
    
    part def Pump {
        port coolantIn : CoolantPort;
        port coolantOut : CoolantPort;
        port speedControl : ControlPort;
        
        attribute operatingSpeed : PumpSpeed;
        attribute maxFlowCapacity : FlowRate;
        
        action circulateCoolant {
            in speedCommand : PumpSpeed;
            in inletPressure : PressureLevel;
            out outletPressure : PressureLevel;
            out actualFlow : FlowRate;
        }
    }
    
    part def WaterBlock {
        port coolantIn : CoolantPort;
        port coolantOut : CoolantPort;
        port heatSource : HeatSourcePort;
        
        attribute thermalResistance : Real;
        attribute contactArea : AreaValue;
        
        action absorbHeat {
            in inletTemp : CoolantTemperature;
            in flowRate : FlowRate;
            in heatInput : HeatLoad;
            out outletTemp : CoolantTemperature;
        }
    }
    
    part def Radiator {
        port coolantIn : CoolantPort;
        port coolantOut : CoolantPort;
        
        attribute surfaceArea : AreaValue;
        attribute ambientTemp : CoolantTemperature;
        
        action dissipateHeat {
            in inletTemp : CoolantTemperature;
            in flowRate : FlowRate;
            in ambient : CoolantTemperature;
            out outletTemp : CoolantTemperature;
            out heatDissipated : HeatLoad;
        }
    }
    
    part def Fan {
        port speedControl : ControlPort;
        
        attribute fanSpeed : FanSpeed;
        attribute airFlowRate : VolumeFlowRateValue;
        
        action generateAirflow {
            in speedCommand : FanSpeed;
            out actualAirflow : VolumeFlowRateValue;
        }
    }
    
    part def Reservoir {
        port coolantPort : CoolantPort;
        
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        attribute minLevel : VolumeValue;
    }
    
    part def TemperatureSensor {
        port measurementPoint : CoolantPort;
        
        attribute reading : CoolantTemperature;
        attribute accuracy : ThermodynamicTemperatureValue;
        
        action measureTemperature {
            in coolantTemp : CoolantTemperature;
            out tempReading : CoolantTemperature;
        }
    }
    
    part def FlowSensor {
        port measurementPoint : CoolantPort;
        
        attribute reading : FlowRate;
        
        action measureFlow {
            in coolantFlow : FlowRate;
            out flowReading : FlowRate;
        }
    }
    
    part def Controller {
        port tempInput : CoolantPort;
        port flowInput : CoolantPort;
        port pumpOutput : ControlPort;
        port fanOutput : ControlPort;
        
        attribute setpoint : TemperatureSetpoint;
        attribute currentTemp : CoolantTemperature;
        attribute currentFlow : FlowRate;
        
        action controlCooling {
            in measuredTemp : CoolantTemperature;
            in measuredFlow : FlowRate;
            in targetTemp : CoolantTemperature;
            out pumpCmd : PumpSpeed;
            out fanCmd : FanSpeed;
        }
    }
    
    action def MonitorTemperature {
        in currentTemp : CoolantTemperature;
        in setpoint : TemperatureSetpoint;
        out tempError : ThermodynamicTemperatureValue;
    }
    
    action def AdjustCooling {
        in tempError : ThermodynamicTemperatureValue;
        in currentFlow : FlowRate;
        out pumpSpeed : PumpSpeed;
        out fanSpeed : FanSpeed;
    }
    
    action def VerifySystemHealth {
        in coolantLevel : VolumeValue;
        in flowRate : FlowRate;
        in temperature : CoolantTemperature;
        out healthStatus : Real;
    }
    
    connection def CoolantFlow {
        end source : CoolantPort;
        end destination : CoolantPort;
    }
    
    connection def ControlSignal {
        end controller : ControlPort;
        end actuator : ControlPort;
    }
    
    part def WaterCoolingSystem {
        doc /* The water cooling system transfers thermal energy from a heat-generating 
                component to the ambient environment through a closed-loop liquid circulation 
                system, maintaining optimal operating temperatures via active feedback control. */
        
        part pump : Pump;
        part waterBlock : WaterBlock;
        part radiator : Radiator;
        part fan : Fan;
        part reservoir : Reservoir;
        part tempSensor : TemperatureSensor;
        part flowSensor : FlowSensor;
        part controller : Controller;
        
        connection pumpToBlock : CoolantFlow connect pump.coolantOut to waterBlock.coolantIn;
        connection blockToRadiator : CoolantFlow connect waterBlock.coolantOut to radiator.coolantIn;
        connection radiatorToReservoir : CoolantFlow connect radiator.coolantOut to reservoir.coolantPort;
        connection reservoirToPump : CoolantFlow connect reservoir.coolantPort to pump.coolantIn;
        
        connection tempMonitoring : CoolantFlow connect tempSensor.measurementPoint to waterBlock.coolantOut;
        connection flowMonitoring : CoolantFlow connect flowSensor.measurementPoint to pump.coolantOut;
        
        connection tempControl : CoolantFlow connect controller.tempInput to tempSensor.measurementPoint;
        connection flowControl : CoolantFlow connect controller.flowInput to flowSensor.measurementPoint;
        connection pumpControl : ControlSignal connect controller.pumpOutput to pump.speedControl;
        connection fanControl : ControlSignal connect controller.fanOutput to fan.speedControl;
        
        perform action operateCoolingSystem {
            first start;
            then merge maintainCooling;
            
            action monitor : MonitorTemperature {
                in currentTemp = tempSensor.reading;
                in setpoint = controller.setpoint;
                out tempError;
            }
            
            then action adjust : AdjustCooling {
                in tempError = monitor.tempError;
                in currentFlow = flowSensor.reading;
                out pumpSpeed;
                out fanSpeed;
            }
            
            then action setPumpSpeed {
                perform pump.circulateCoolant {
                    in speedCommand = adjust.pumpSpeed;
                }
            }
            
            then action setFanSpeed {
                perform fan.generateAirflow {
                    in speedCommand = adjust.fanSpeed;
                }
            }
            
            then action transferHeat {
                perform waterBlock.absorbHeat {
                    in inletTemp = pump.coolantOut.coolant.temperature;
                    in flowRate = pump.coolantOut.coolant.flowRate;
                }
            }
            
            then action rejectHeat {
                perform radiator.dissipateHeat {
                    in inletTemp = waterBlock.coolantOut.coolant.temperature;
                    in flowRate = waterBlock.coolantOut.coolant.flowRate;
                    in ambient = radiator.ambientTemp;
                }
            }
            
            then action verify : VerifySystemHealth {
                in coolantLevel = reservoir.currentLevel;
                in flowRate = flowSensor.reading;
                in temperature = tempSensor.reading;
                out healthStatus;
            }
            
            then decide;
                if verify.healthStatus > 0.0 then maintainCooling;
                if verify.healthStatus <= 0.0 then emergencyShutdown;
            
            action emergencyShutdown;
            then done;
        }
        
        exhibit state machine CoolingSystemStates {
            initial state Standby;
            
            state Operating {
                entry action startPump {
                    perform pump.circulateCoolant;
                }
                entry action startFan {
                    perform fan.generateAirflow;
                }
            }
            
            state Cooling {
                do action performCooling {
                    perform waterBlock.absorbHeat;
                    then perform radiator.dissipateHeat;
                }
            }
            
            state Fault {
                doc /* System has detected an anomaly requiring intervention. */
            }
            
            transition powerOn from Standby to Operating;
            transition beginCooling from Operating to Cooling 
                when tempSensor.reading > controller.setpoint.target;
            transition maintainTemp from Cooling to Cooling 
                when tempSensor.reading > controller.setpoint.target - controller.setpoint.tolerance;
            transition normalTemp from Cooling to Operating 
                when tempSensor.reading <= controller.setpoint.target - controller.setpoint.tolerance;
            transition lowCoolant from Operating to Fault 
                when reservoir.currentLevel < reservoir.minLevel;
            transition overTemp from Cooling to Fault 
                when tempSensor.reading > controller.setpoint.target + 2.0 * controller.setpoint.tolerance;
            transition powerOff from Operating to Standby;
        }
    }
    
    part waterCoolingSystem : WaterCoolingSystem {
        part pump {
            attribute operatingSpeed = 3000.0;
            attribute maxFlowCapacity = 0.001 [m^3/s];
        }
        
        part waterBlock {
            attribute thermalResistance = 0.15;
            attribute contactArea = 0.01 [m^2];
        }
        
        part radiator {
            attribute surfaceArea = 0.5 [m^2];
            attribute ambientTemp = 298.15 [K];
        }
        
        part fan {
            attribute fanSpeed = 1500.0;
            attribute airFlowRate = 0.05 [m^3/s];
        }
        
        part reservoir {
            attribute capacity = 0.005 [m^3];
            attribute currentLevel = 0.004 [m^3];
            attribute minLevel = 0.002 [m^3];
        }
        
        part tempSensor {
            attribute accuracy = 0.5 [K];
        }
        
        part controller {
            attribute setpoint : TemperatureSetpoint {
                attribute target = 323.15 [K];
                attribute tolerance = 5.0 [K];
            }
        }
    }
    
    requirement def ThermalPerformanceRequirement {
        doc /* The cooling system shall maintain the heat source temperature within 
                specified operational limits under maximum thermal load conditions. */
        
        require constraint maxTemperatureLimit {
            waterCoolingSystem.tempSensor.reading <= waterCoolingSystem.controller.setpoint.target + waterCoolingSystem.controller.setpoint.tolerance
        }
        
        require constraint minFlowRequirement {
            waterCoolingSystem.flowSensor.reading >= waterCoolingSystem.pump.maxFlowCapacity * 0.4
        }
    }
    
    requirement def SystemReliabilityRequirement {
        doc /* The cooling system shall operate continuously without failure and 
                maintain adequate coolant inventory. */
        
        require constraint coolantLevelMaintenance {
            waterCoolingSystem.reservoir.currentLevel >= waterCoolingSystem.reservoir.minLevel
        }
        
        require constraint continuousOperation {
            waterCoolingSystem.pump.operatingSpeed > 0.0
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The cooling system shall prevent overheating and provide fault detection. */
        
        require constraint overTemperatureProtection {
            waterCoolingSystem.tempSensor.reading < waterCoolingSystem.controller.setpoint.target + 2.0 * waterCoolingSystem.controller.setpoint.tolerance
        }
        
        require constraint lowCoolantDetection {
            waterCoolingSystem.reservoir.currentLevel >= waterCoolingSystem.reservoir.minLevel
        }
    }
    
    requirement systemRequirements {
        subject waterCoolingSystem;
        
        doc /* The water cooling system shall continuously circulate liquid coolant through 
                a closed loop to absorb thermal energy from a heat source and dissipate it to 
                ambient air via a radiator, maintaining the heat source within safe operating 
                temperature limits through automated feedback control. */
        
        require thermalPerf : ThermalPerformanceRequirement;
        require reliability : SystemReliabilityRequirement;
        require safety : SafetyRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Water Cooling System'::*;

    part testSubject : WaterCoolingSystem {
    :>> currentTemp = testCurrentTemp;
    :>> setpoint = testSetpoint;
    }

    action orchestrator {
        attribute testCurrentTemp : CoolantTemperature;
        attribute testSetpoint : TemperatureSetpoint {
            attribute target : CoolantTemperature;
            attribute tolerance : ThermodynamicTemperatureValue;
        }
    }
}
