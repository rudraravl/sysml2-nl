package WaterHeaterSystem {
    import ScalarValues::*;
    
    package Types {
        type VolumeUnit;
        type PowerUnit;
        type TempUnit;
        type PressureUnit;
        
        value type VolumeVal :> Real {
            unit : VolumeUnit;
        }
        value type PowerVal :> Real {
            unit : PowerUnit;
        }
        value type TempVal :> Real {
            unit : TempUnit;
        }
        value type PressureVal :> Real {
            unit : PressureUnit;
        }
    }
    
    package Interfaces {
        import Types::*;
        
        item def Water;
        item def ColdWater :> Water;
        item def HotWater :> Water;
        item def ElectricPower;
        item def Heat;
        item def TempReading {
            attribute temp : TempVal;
        }
        item def Command {
            attribute status : String;
        }
        
        port def WaterInlet {
            in item water : Water;
        }
        port def WaterOutlet {
            out item water : Water;
        }
        port def PowerInlet {
            in item power : ElectricPower;
        }
        port def HeatPort {
            in item heat : Heat;
        }
        port def DataIn {
            in item reading : TempReading;
        }
        port def DataOut {
            out item reading : TempReading;
        }
        port def CommandIn {
            in item cmd : Command;
        }
        port def CommandOut {
            out item cmd : Command;
        }
    }
    
    package Requirements {
        import Types::*;
        
        requirement def ProvideHotWaterReq {
            doc /* The system shall provide a supply of hot water for household use. */
        }
        requirement def RapidHeatingReq {
            doc /* The system shall rapidly heat water using a 4500W primary heater. */
            attribute powerReq : PowerVal = 4500;
        }
        requirement def EfficientMaintenanceReq {
            doc /* The system shall maintain temperature efficiently using a 2000W secondary heater. */
            attribute powerReq : PowerVal = 2000;
        }
        requirement def TargetTempReq {
            doc /* The system shall maintain water at a user-defined target of 60C. */
            attribute targetTemp : TempVal = 60;
        }
        requirement def OverTempSafetyReq {
            doc /* The control unit shall shut down the heaters if water temperature exceeds 85C. */
            attribute maxTemp : TempVal = 85;
        }
        requirement def OverPressureSafetyReq {
            doc /* The mechanical safety valve shall release pressure if it builds to a dangerous level. */
        }
        requirement def EnergyEfficiencyReq {
            doc /* The system shall be highly efficient, ensuring minimal energy loss. */
        }
    }
    
    package Components {
        import Interfaces::*;
        
        part def TemperatureSensor {
            out port readingOut : DataOut;
        }
        
        part def WaterTank {
            attribute capacity : VolumeVal = 200;
            
            in port coldWaterIn : WaterInlet;
            out port hotWaterOut : WaterOutlet;
            out port reliefPort : WaterOutlet;
            in port primaryHeatPort : HeatPort;
            in port secondaryHeatPort : HeatPort;
            in port circIn : WaterInlet;
            out port circOut : WaterOutlet;
            out port tempDataOut : DataOut;
            
            part tempSensor : TemperatureSensor;
            
            connection tempSensor.readingOut to tempDataOut;
        }
        
        part def ElectricHeater {
            attribute powerRating : PowerVal;
            in port powerIn : PowerInlet;
            in port cmdIn : CommandIn;
            out port heatOut : HeatPort;
        }
        
        part def Thermostat {
            attribute targetTemp : TempVal = 60;
            attribute maxSafeTemp : TempVal = 85;
            
            in port sensorData : DataIn;
            out port primaryCmd : CommandOut;
            out port secondaryCmd : CommandOut;
            out port pumpCmd : CommandOut;
            
            state machine ControlStates {
                state standby {
                    entry {
                        send new Command { status = "off"; } to primaryCmd;
                        send new Command { status = "off"; } to secondaryCmd;
                        send new Command { status = "off"; } to pumpCmd;
                    }
                }
                state heating {
                    entry {
                        send new Command { status = "on"; } to primaryCmd;
                        send new Command { status = "on"; } to secondaryCmd;
                        send new Command { status = "on"; } to pumpCmd;
                    }
                }
                state maintaining {
                    entry {
                        send new Command { status = "off"; } to primaryCmd;
                        send new Command { status = "on"; } to secondaryCmd;
                        send new Command { status = "on"; } to pumpCmd;
                    }
                }
                state faultShutdown {
                    entry {
                        send new Command { status = "off"; } to primaryCmd;
                        send new Command { status = "off"; } to secondaryCmd;
                        send new Command { status = "off"; } to pumpCmd;
                    }
                }
                
                transition initial to standby;
                transition standby to heating 
                    accept reading : TempReading on sensorData 
                    if reading.temp < targetTemp;
                transition heating to maintaining 
                    accept reading : TempReading on sensorData 
                    if reading.temp >= targetTemp;
                transition maintaining to heating 
                    accept reading : TempReading on sensorData 
                    if reading.temp < targetTemp;
                transition standby, heating, maintaining to faultShutdown 
                    accept reading : TempReading on sensorData 
                    if reading.temp > maxSafeTemp;
            }
        }
        
        part def ControlUnit {
            in port powerIn : PowerInlet;
            in port sensorData : DataIn;
            out port primaryCmd : CommandOut;
            out port secondaryCmd : CommandOut;
            out port pumpCmd : CommandOut;
            
            part thermostat : Thermostat;
            
            connection sensorData to thermostat.sensorData;
            connection thermostat.primaryCmd to primaryCmd;
            connection thermostat.secondaryCmd to secondaryCmd;
            connection thermostat.pumpCmd to pumpCmd;
        }
        
        part def CirculationPump {
            in port powerIn : PowerInlet;
            in port cmdIn : CommandIn;
            in port pumpIn : WaterInlet;
            out port pumpOut : WaterOutlet;
        }
        
        part def SafetyValve {
            attribute maxPressure : PressureVal = 6;
            in port tankPort : WaterInlet;
            out port reliefPort : WaterOutlet;
        }
    }
    
    part def ResidentialWaterHeater {
        import Interfaces::*;
        import Components::*;
        import Requirements::*;
        
        in port mainPower : PowerInlet;
        in port mainColdWater : WaterInlet;
        out port mainHotWater : WaterOutlet;
        out port reliefDrain : WaterOutlet;
        
        part tank : WaterTank {
            satisfy ProvideHotWaterReq;
            satisfy EnergyEfficiencyReq;
        }
        part primaryHeater : ElectricHeater {
            attribute powerRating : PowerVal = 4500;
            satisfy RapidHeatingReq;
        }
        part secondaryHeater : ElectricHeater {
            attribute powerRating : PowerVal = 2000;
            satisfy EfficientMaintenanceReq;
        }
        part controlUnit : ControlUnit {
            satisfy TargetTempReq;
            satisfy OverTempSafetyReq;
        }
        part pump : CirculationPump;
        part safetyValve : SafetyValve {
            satisfy OverPressureSafetyReq;
        }
        
        connection mainPower to controlUnit.powerIn;
        connection mainPower to primaryHeater.powerIn;
        connection mainPower to secondaryHeater.powerIn;
        connection mainPower to pump.powerIn;
        
        connection mainColdWater to tank.coldWaterIn;
        connection tank.hotWaterOut to mainHotWater;
        
        connection tank.circOut to pump.pumpIn;
        connection pump.pumpOut to tank.circIn;
        
        connection primaryHeater.heatOut to tank.primaryHeatPort;
        connection secondaryHeater.heatOut to tank.secondaryHeatPort;
        
        connection tank.reliefPort to safetyValve.tankPort;
        connection safetyValve.reliefPort to reliefDrain;
        
        connection tank.tempDataOut to controlUnit.sensorData;
        connection controlUnit.primaryCmd to primaryHeater.cmdIn;
        connection controlUnit.secondaryCmd to secondaryHeater.cmdIn;
        connection controlUnit.pumpCmd to pump.cmdIn;
    }
}
