package 'Jet Aeration System' {
    private import ScalarValues::Real;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    
    package Definitions {
        item def Wastewater;
        item def Air;
        item def FineBubbles;
        item def ElectricPower;
        
        item def DOReading {
            attribute doLevel : Real;
        }
        item def DOSetPoint {
            attribute target : Real;
        }
        item def PumpCommand {
            attribute pumpSpeed : Real;
            attribute waterFlow : Real;
        }
        item def CompressorCommand {
            attribute compressorLoad : Real;
            attribute airFlow : Real;
        }
        
        port def WaterOutPort {
            out item water : Wastewater;
        }
        port def WaterInPort {
            in item water : Wastewater;
        }
        port def AirOutPort {
            out item air : Air;
        }
        port def AirInPort {
            in item air : Air;
        }
        port def BubblesOutPort {
            out item bubbles : FineBubbles;
        }
        port def BubblesInPort {
            in item bubbles : FineBubbles;
        }
        port def PowerOutPort {
            out item power : ElectricPower;
        }
        port def PowerInPort {
            in item power : ElectricPower;
        }
        port def PumpCmdOutPort {
            out item command : PumpCommand;
        }
        port def PumpCmdInPort {
            in item command : PumpCommand;
        }
        port def CompCmdOutPort {
            out item command : CompressorCommand;
        }
        port def CompCmdInPort {
            in item command : CompressorCommand;
        }
        port def DOReadingOutPort {
            out item reading : DOReading;
        }
        port def DOReadingInPort {
            in item reading : DOReading;
        }
        port def DOSetPointOutPort {
            out item setPoint : DOSetPoint;
        }
        port def DOSetPointInPort {
            in item setPoint : DOSetPoint;
        }
        
        action def PumpWater {
            in water : Wastewater;
            in power : ElectricPower;
            in command : PumpCommand;
            out pressurizedWater : Wastewater;
        }
        
        action def CompressAir {
            in air : Air;
            in power : ElectricPower;
            in command : CompressorCommand;
            out compressedAir : Air;
        }
        
        action def MixAirWater {
            in water : Wastewater;
            in air : Air;
            out bubbles : FineBubbles;
        }
        
        action def ControlDO {
            in currentReading : DOReading;
            in targetSetPoint : DOSetPoint;
            out pumpCmd : PumpCommand;
            out compressorCmd : CompressorCommand;
        }
        
        state machine def ControlStates {
            state Idle;
            state Monitoring;
            state Adjusting;
            
            transition from Idle to Monitoring;
            transition from Monitoring to Adjusting;
            transition from Adjusting to Monitoring;
            transition from Monitoring to Idle;
        }
        
        part def WaterPump {
            port waterInPort : WaterInPort;
            port waterOutPort : WaterOutPort;
            port powerInPort : PowerInPort;
            port commandInPort : PumpCmdInPort;
        }
        
        part def AirCompressor {
            port airInPort : AirInPort;
            port airOutPort : AirOutPort;
            port powerInPort : PowerInPort;
            port commandInPort : CompCmdInPort;
        }
        
        part def JetNozzle {
            port waterInPort : WaterInPort;
            port airInPort : AirInPort;
            port bubblesOutPort : BubblesOutPort;
        }
        
        part def AerationBasin {
            port bubblesInPort : BubblesInPort;
            port waterOutPort : WaterOutPort;
            attribute volume : Real = 500.0;
            attribute currentDO : Real = 1.0;
            item wastewater : Wastewater;
        }
        
        part def DOSensor {
            port waterInPort : WaterInPort;
            port readingOutPort : DOReadingOutPort;
        }
        
        part def ControlSystem {
            port readingInPort : DOReadingInPort;
            port setPointInPort : DOSetPointInPort;
            port pumpCommandOutPort : PumpCmdOutPort;
            port compressorCommandOutPort : CompCmdOutPort;
            
            perform action controlDO : ControlDO {
                in currentReading = readingInPort.reading;
                in targetSetPoint = setPointInPort.setPoint;
                out pumpCmd = pumpCommandOutPort.command;
                out compressorCmd = compressorCommandOutPort.command;
            }
            
            state machine controlStates : ControlStates;
        }
        
        part def ElectricalSupply {
            port pumpPowerOutPort : PowerOutPort;
            port compressorPowerOutPort : PowerOutPort;
        }
        
        part def Atmosphere {
            port airOutPort : AirOutPort;
        }
        
        part def Operator {
            port setPointOutPort : DOSetPointOutPort;
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part context {
            part electricalSupply : ElectricalSupply;
            part atmosphere : Atmosphere;
            part aerationBasin : AerationBasin;
            part doSensor : DOSensor;
            part controlSystem : ControlSystem;
            part waterPump : WaterPump {
                perform action pumpWater : PumpWater {
                    in water = waterInPort.water;
                    in power = powerInPort.power;
                    in command = commandInPort.command;
                    out pressurizedWater = waterOutPort.water;
                }
            }
            part airCompressor : AirCompressor {
                perform action compressAir : CompressAir {
                    in air = airInPort.air;
                    in power = powerInPort.power;
                    in command = commandInPort.command;
                    out compressedAir = airOutPort.air;
                }
            }
            part jetNozzle : JetNozzle {
                perform action mixAirWater : MixAirWater {
                    in water = waterInPort.water;
                    in air = airInPort.air;
                    out bubbles = bubblesOutPort.bubbles;
                }
            }
            part operator : Operator;
            
            flow of ElectricPower
                from electricalSupply.pumpPowerOutPort.power to waterPump.powerInPort.power;
            flow of ElectricPower
                from electricalSupply.compressorPowerOutPort.power to airCompressor.powerInPort.power;
            
            flow of Air
                from atmosphere.airOutPort.air to airCompressor.airInPort.air;
            flow of Air
                from airCompressor.airOutPort.air to jetNozzle.airInPort.air;
            
            flow of Wastewater
                from aerationBasin.waterOutPort.water to waterPump.waterInPort.water;
            flow of Wastewater
                from waterPump.waterOutPort.water to jetNozzle.waterInPort.water;
            
            flow of FineBubbles
                from jetNozzle.bubblesOutPort.bubbles to aerationBasin.bubblesInPort.bubbles;
            
            flow of Wastewater
                from aerationBasin.waterOutPort.water to doSensor.waterInPort.water;
            flow of DOReading
                from doSensor.readingOutPort.reading to controlSystem.readingInPort.reading;
            flow of DOSetPoint
                from operator.setPointOutPort.setPoint to controlSystem.setPointInPort.setPoint;
            
            flow of PumpCommand
                from controlSystem.pumpCommandOutPort.command to waterPump.commandInPort.command;
            flow of CompressorCommand
                from controlSystem.compressorCommandOutPort.command to airCompressor.commandInPort.command;
        }
    }
    
    package Requirements {
        private import Definitions::*;
        private import Usages::*;
        
        requirement def DOContentRequirement {
            doc /* The system shall maintain the dissolved oxygen concentration in the aeration basin at or above the desired target. */
            subject basin : AerationBasin;
            attribute targetDO : Real;
            objective {
                assert basin.currentDO >= targetDO;
            }
        }
        
        requirement def EnergyEfficiencyRequirement {
            doc /* The system shall adjust compressor and pump operations based on the DO difference to minimize power consumption. */
            subject control : ControlSystem;
        }
        
        requirement doContent : DOContentRequirement {
            subject :>> basin = Usages::context.aerationBasin;
            attribute :>> targetDO = 4.0;
        }
        
        requirement energyEfficiency : EnergyEfficiencyRequirement {
            subject :>> control = Usages::context.controlSystem;
        }
    }
}
