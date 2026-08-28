package SteamEngineSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    
    package Definitions {
        item def Fuel {
            attribute energyContent :> EnergyValue;
        }
        item def Water {
            attribute pressure :> PressureValue;
            attribute temperature :> TemperatureValue;
            attribute mass :> MassValue;
        }
        item def Steam {
            attribute pressure :> PressureValue;
            attribute temperature :> TemperatureValue;
        }
        item def CoolingWater {
            attribute temperature :> TemperatureValue;
        }
        
        attribute def StartSignal;
        attribute def StopSignal;
        attribute def EmergencyStop;
        attribute def PressureReady;
        attribute def PressureLow;
        
        port def FuelInPort {
            in item fuel : Fuel;
        }
        port def WaterInPort {
            in item water : Water;
        }
        port def WaterOutPort {
            out item water : Water;
        }
        port def SteamInPort {
            in item steam : Steam;
        }
        port def SteamOutPort {
            out item steam : Steam;
        }
        port def CoolingWaterInPort {
            in item coolingWater : CoolingWater;
        }
        port def CoolingWaterOutPort {
            out item coolingWater : CoolingWater;
        }
        port def TorqueOutPort {
            out torque : TorqueValue;
        }
        port def ControlPort {
            in startSignal : StartSignal;
            in stopSignal : StopSignal;
            in emergencyStop : EmergencyStop;
        }
        
        action def generateSteam {
            in item fuel : Fuel;
            in item water : Water;
            out item steam : Steam;
        }
        action def expandSteam {
            in item steam : Steam;
            out item exhaustSteam : Steam;
            out torque : TorqueValue;
        }
        action def condenseSteam {
            in item exhaustSteam : Steam;
            in item coolingWater : CoolingWater;
            out item condensate : Water;
            out item warmCoolingWater : CoolingWater;
        }
        action def pumpWater {
            in item condensate : Water;
            out item pressurizedWater : Water;
        }
        action def operateCycle {
            in item fuel : Fuel;
            in item coolingWater : CoolingWater;
            out torque : TorqueValue;
            
            action generate : generateSteam;
            action expand : expandSteam;
            action condense : condenseSteam;
            action pump : pumpWater;
            
            flow generate.steam to expand.steam;
            flow expand.exhaustSteam to condense.exhaustSteam;
            flow condense.condensate to pump.condensate;
            flow pump.pressurizedWater to generate.water;
            
            first start;
            then generate;
            then expand;
            then condense;
            then pump;
        }
        
        state def EngineStates {
            state idle;
            state startup;
            state operating;
            state shutdown;
            state emergency;
            
            transition toStartup : idle -> startup accept StartSignal;
            transition toOperating : startup -> operating accept PressureReady;
            transition toShutdown : operating -> shutdown accept StopSignal;
            transition toIdle : shutdown -> idle accept PressureLow;
            transition toEmergency : operating -> emergency accept EmergencyStop;
            transition emergencyToIdle : emergency -> idle after 60.0 [s];
        }
        
        part def Boiler {
            attribute maxPressure :> PressureValue = 10.0 [MPa];
            attribute minWaterLevel :> VolumeValue = 50.0 [L];
            attribute currentPressure :> PressureValue;
            attribute currentWaterLevel :> VolumeValue;
            attribute currentTemperature :> TemperatureValue;
            
            port fuelInPort : FuelInPort;
            port waterInPort : WaterInPort;
            port steamOutPort : SteamOutPort;
            
            perform generateSteam {
                in fuel = fuelInPort.fuel;
                in water = waterInPort.water;
                out steam = steamOutPort.steam;
            }
        }
        
        part def SteamExpander {
            attribute outputTorque :> TorqueValue;
            
            port steamInPort : SteamInPort;
            port exhaustSteamOutPort : SteamOutPort;
            port torqueOutPort : TorqueOutPort;
            
            perform expandSteam {
                in steam = steamInPort.steam;
                out exhaustSteam = exhaustSteamOutPort.steam;
                out torque = torqueOutPort.torque;
            }
        }
        
        part def Condenser {
            attribute coolingCapacity :> PowerValue = 100.0 [kW];
            
            port exhaustSteamInPort : SteamInPort;
            port coolingWaterInPort : CoolingWaterInPort;
            port warmCoolingWaterOutPort : CoolingWaterOutPort;
            port condensateOutPort : WaterOutPort;
            
            perform condenseSteam {
                in exhaustSteam = exhaustSteamInPort.steam;
                in coolingWater = coolingWaterInPort.coolingWater;
                out condensate = condensateOutPort.water;
                out warmCoolingWater = warmCoolingWaterOutPort.coolingWater;
            }
        }
        
        part def FeedwaterPump {
            attribute maxPressure :> PressureValue = 12.0 [MPa];
            attribute flowRate :> MassFlowRateValue = 0.5 [kg/s];
            
            port condensateInPort : WaterInPort;
            port pressurizedWaterOutPort : WaterOutPort;
            
            perform pumpWater {
                in condensate = condensateInPort.water;
                out pressurizedWater = pressurizedWaterOutPort.water;
            }
        }
        
        part def SteamEngine {
            attribute thermalEfficiency :> Real;
            attribute outputPower :> PowerValue;
            
            port fuelInPort : FuelInPort;
            port coolingWaterInPort : CoolingWaterInPort;
            port warmCoolingWaterOutPort : CoolingWaterOutPort;
            port torqueOutPort : TorqueOutPort;
            port controlPort : ControlPort;
            
            exhibit state engineStates : EngineStates;
            perform operateCycle {
                in fuel = fuelInPort.fuel;
                in coolingWater = coolingWaterInPort.coolingWater;
                out torque = torqueOutPort.torque;
            }
            
            part boiler : Boiler;
            part expander : SteamExpander;
            part condenser : Condenser;
            part pump : FeedwaterPump;
            
            flow fuelFlow of Fuel 
                from fuelInPort.fuel to boiler.fuelInPort.fuel;
            flow coolingWaterFlow of CoolingWater 
                from coolingWaterInPort.coolingWater to condenser.coolingWaterInPort.coolingWater;
            flow steamFlow of Steam 
                from boiler.steamOutPort.steam to expander.steamInPort.steam;
            flow exhaustSteamFlow of Steam 
                from expander.exhaustSteamOutPort.steam to condenser.exhaustSteamInPort.steam;
            flow condensateFlow of Water 
                from condenser.condensateOutPort.water to pump.condensateInPort.water;
            flow pressurizedWaterFlow of Water 
                from pump.pressurizedWaterOutPort.water to boiler.waterInPort.water;
            flow warmCoolingWaterFlow of CoolingWater 
                from condenser.warmCoolingWaterOutPort.coolingWater to warmCoolingWaterOutPort.coolingWater;
            flow torqueFlow of TorqueValue 
                from expander.torqueOutPort.torque to torqueOutPort.torque;
        }
        
        requirement def SafeBoilerPressure {
            doc /* The boiler pressure shall not exceed the maximum safe operating pressure. */
            subject boiler : Boiler;
            attribute maxAllowedPressure :> PressureValue = 10.0 [MPa];
            constraint { boiler.currentPressure <= maxAllowedPressure }
        }
        
        requirement def MinimumWaterLevel {
            doc /* The boiler water level shall remain above the minimum safe level. */
            subject boiler : Boiler;
            attribute minAllowedLevel :> VolumeValue = 50.0 [L];
            constraint { boiler.currentWaterLevel >= minAllowedLevel }
        }
        
        requirement def TargetThermalEfficiency {
            doc /* The engine system shall achieve a thermal efficiency of at least 15 percent. */
            subject engine : SteamEngine;
            attribute targetEfficiency :> Real = 0.15;
            constraint { engine.thermalEfficiency >= targetEfficiency }
        }
        
        requirement def SafeShutdown {
            doc /* The system shall complete a controlled shutdown within 30 seconds of receiving a stop signal. */
            attribute maxShutdownTime :> TimeValue = 30.0 [s];
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part steamEngine : SteamEngine {
            attribute :>> thermalEfficiency = 0.18;
            attribute :>> outputPower = 250.0 [kW];
            
            satisfy SafeBoilerPressure by boiler;
            satisfy MinimumWaterLevel by boiler;
            satisfy TargetThermalEfficiency by steamEngine;
            satisfy SafeShutdown;
        }
    }
}
