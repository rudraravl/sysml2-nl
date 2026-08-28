package 'Household Refrigerator System' {
    private import ScalarValues::*;
    
    attribute def Temperature :> Real;
    
    enum def DoorState {
        enum open;
        enum closed;
    }
    
    item def Refrigerant;
    item def Heat;
    item def Air;
    item def ElectricalPower;
    
    item def TempReading {
        attribute temp : Temperature;
    }
    item def DoorReading {
        attribute doorStatus : DoorState;
    }
    item def ControlCommand {
        attribute active : Boolean;
    }
    
    port def RefrigerantInPort { in refrigerant : Refrigerant; }
    port def RefrigerantOutPort { out refrigerant : Refrigerant; }
    port def AirInPort { in air : Air; }
    port def AirOutPort { out air : Air; }
    port def HeatInPort { in heat : Heat; }
    port def HeatOutPort { out heat : Heat; }
    port def PowerInPort { in power : ElectricalPower; }
    port def PowerOutPort { out power : ElectricalPower; }
    port def TempSignalInPort { in tempReading : TempReading; }
    port def TempSignalOutPort { out tempReading : TempReading; }
    port def DoorSignalInPort { in doorReading : DoorReading; }
    port def DoorSignalOutPort { out doorReading : DoorReading; }
    port def ControlSignalInPort { in command : ControlCommand; }
    port def ControlSignalOutPort { out command : ControlCommand; }
    
    part def Compressor {
        port refrigerantIn : RefrigerantInPort;
        port refrigerantOut : RefrigerantOutPort;
        port powerIn : PowerInPort;
        port controlIn : ControlSignalInPort;
        attribute isRunning : Boolean;
    }
    
    part def Condenser {
        port refrigerantIn : RefrigerantInPort;
        port refrigerantOut : RefrigerantOutPort;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port heatOut : HeatOutPort;
    }
    
    part def ExpansionValve {
        port refrigerantIn : RefrigerantInPort;
        port refrigerantOut : RefrigerantOutPort;
    }
    
    part def Evaporator {
        port refrigerantIn : RefrigerantInPort;
        port refrigerantOut : RefrigerantOutPort;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port heatIn : HeatInPort;
    }
    
    part def Fan {
        port powerIn : PowerInPort;
        port controlIn : ControlSignalInPort;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute isRunning : Boolean;
    }
    
    part def TemperatureSensor {
        port signalOut : TempSignalOutPort;
        attribute currentTemp : Temperature;
    }
    
    part def DoorSensor {
        port signalOut : DoorSignalOutPort;
        attribute doorState : DoorState;
    }
    
    part def Controller {
        port tempIn : TempSignalInPort;
        port doorIn : DoorSignalInPort;
        port powerIn : PowerInPort;
        port compressorControlOut : ControlSignalOutPort;
        port condenserFanControlOut : ControlSignalOutPort;
        port evaporatorFanControlOut : ControlSignalOutPort;
        attribute setpoint : Temperature = 4.0;
        
        state controllerBehavior {
            entry; then idle;
            state idle {
                entry action disableOutputs {
                    send new ControlCommand() to compressorControlOut;
                    send new ControlCommand() to condenserFanControlOut;
                    send new ControlCommand() to evaporatorFanControlOut;
                }
            }
            accept tempReading : TempReading via tempIn
                if tempReading.temp > setpoint and doorIn.doorReading.doorStatus == DoorState::closed
                then cooling;
            state cooling {
                entry action enableOutputs {
                    send new ControlCommand() to compressorControlOut;
                    send new ControlCommand() to condenserFanControlOut;
                    send new ControlCommand() to evaporatorFanControlOut;
                }
            }
            accept tempReading : TempReading via tempIn
                if tempReading.temp <= setpoint
                then idle;
            accept doorReading : DoorReading via doorIn
                if doorReading.doorStatus == DoorState::open
                then idle;
        }
    }
    
    part def PowerSupply {
        port powerOutController : PowerOutPort;
        port powerOutCompressor : PowerOutPort;
        port powerOutCondenserFan : PowerOutPort;
        port powerOutEvaporatorFan : PowerOutPort;
    }
    
    part def InteriorCompartment {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port heatOut : HeatOutPort;
        attribute temp : Temperature;
    }
    
    part def InsulatedCabinet {
        part interior : InteriorCompartment;
    }
    
    part def Room {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port heatIn : HeatInPort;
    }
    
    action def Compress {
        in lowPressureGas : Refrigerant;
        out highPressureGas : Refrigerant;
    }
    action def Condense {
        in highPressureGas : Refrigerant;
        out highPressureLiquid : Refrigerant;
        out dissipatedHeat : Heat;
    }
    action def Expand {
        in highPressureLiquid : Refrigerant;
        out lowPressureColdLiquid : Refrigerant;
    }
    action def Evaporate {
        in lowPressureColdLiquid : Refrigerant;
        in absorbedHeat : Heat;
        out lowPressureGas : Refrigerant;
    }
    
    action def RefrigerationCycle {
        in lowPressureGasIn : Refrigerant;
        out lowPressureGasOut : Refrigerant;
        
        first action compress : Compress {
            in lowPressureGas = lowPressureGasIn;
            out highPressureGas;
        }
        then action condense : Condense {
            in highPressureGas = compress.highPressureGas;
            out highPressureLiquid;
            out dissipatedHeat;
        }
        then action expand : Expand {
            in highPressureLiquid = condense.highPressureLiquid;
            out lowPressureColdLiquid;
        }
        then action evaporate : Evaporate {
            in lowPressureColdLiquid = expand.lowPressureColdLiquid;
            in absorbedHeat;
            out lowPressureGas = lowPressureGasOut;
        }
        then done;
    }
    
    part def VaporCompressionCycle {
        part compressor : Compressor;
        part condenser : Condenser;
        part expansionValve : ExpansionValve;
        part evaporator : Evaporator;
        
        flow refrigerantFlow1 of Refrigerant from compressor.refrigerantOut.refrigerant to condenser.refrigerantIn.refrigerant;
        flow refrigerantFlow2 of Refrigerant from condenser.refrigerantOut.refrigerant to expansionValve.refrigerantIn.refrigerant;
        flow refrigerantFlow3 of Refrigerant from expansionValve.refrigerantOut.refrigerant to evaporator.refrigerantIn.refrigerant;
        flow refrigerantFlow4 of Refrigerant from evaporator.refrigerantOut.refrigerant to compressor.refrigerantIn.refrigerant;
    }
    
    part def Refrigerator {
        part cabinet : InsulatedCabinet;
        part cycle : VaporCompressionCycle;
        part condenserFan : Fan;
        part evaporatorFan : Fan;
        part controller : Controller;
        part tempSensor : TemperatureSensor;
        part doorSensor : DoorSensor;
        part powerSupply : PowerSupply;
        part room : Room;
        
        flow heatFromInterior of Heat from cabinet.interior.heatOut.heat to cycle.evaporator.heatIn.heat;
        flow heatToRoom of Heat from cycle.condenser.heatOut.heat to room.heatIn.heat;
        
        flow airFromCompartment of Air from cabinet.interior.airOut.air to evaporatorFan.airIn.air;
        flow airToEvaporator of Air from evaporatorFan.airOut.air to cycle.evaporator.airIn.air;
        flow airFromEvaporator of Air from cycle.evaporator.airOut.air to cabinet.interior.airIn.air;
        
        flow airFromRoom of Air from room.airOut.air to condenserFan.airIn.air;
        flow airToCondenser of Air from condenserFan.airOut.air to cycle.condenser.airIn.air;
        flow airToRoom of Air from cycle.condenser.airOut.air to room.airIn.air;
        
        flow powerToController of ElectricalPower from powerSupply.powerOutController.power to controller.powerIn.power;
        flow powerToCompressor of ElectricalPower from powerSupply.powerOutCompressor.power to cycle.compressor.powerIn.power;
        flow powerToCondenserFan of ElectricalPower from powerSupply.powerOutCondenserFan.power to condenserFan.powerIn.power;
        flow powerToEvaporatorFan of ElectricalPower from powerSupply.powerOutEvaporatorFan.power to evaporatorFan.powerIn.power;
        
        flow tempSignal of TempReading from tempSensor.signalOut.tempReading to controller.tempIn.tempReading;
        flow doorSignal of DoorReading from doorSensor.signalOut.doorReading to controller.doorIn.doorReading;
        
        flow compressorControl of ControlCommand from controller.compressorControlOut.command to cycle.compressor.controlIn.command;
        flow condenserFanControl of ControlCommand from controller.condenserFanControlOut.command to condenserFan.controlIn.command;
        flow evaporatorFanControl of ControlCommand from controller.evaporatorFanControlOut.command to evaporatorFan.controlIn.command;
    }
    
    requirement def CoolingRequirement {
        doc /* The refrigerator shall maintain the internal compartment temperature at or below the configured setpoint when the door is closed. */
        subject refrigerator : Refrigerator;
        constraint { refrigerator.cabinet.interior.temp <= refrigerator.controller.setpoint; }
    }
    
    requirement def DoorInterlockRequirement {
        doc /* The cooling cycle (compressor and fans) shall not run when the door is detected as open. */
        subject refrigerator : Refrigerator;
        constraint { refrigerator.doorSensor.doorState == DoorState::open implies refrigerator.cycle.compressor.isRunning == false; }
    }
    
    requirement def VaporCompressionCycleRequirement {
        doc /* The system shall implement a closed-loop vapor-compression refrigeration cycle comprising a compressor, condenser, expansion valve, and evaporator. */
        subject refrigerator : Refrigerator;
    }
    
    requirement def InsulationRequirement {
        doc /* The refrigerated compartment shall be enclosed by an insulated cabinet to minimize heat leakage from the surrounding environment. */
        subject refrigerator : Refrigerator;
    }
}
