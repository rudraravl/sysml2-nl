package HomeAutomation {
    private import ScalarValues::*;
    
    attribute def OpenWebNetCommand {
        attribute address : String;
        attribute command : String;
        attribute value : Real;
    }
    
    attribute def StatusUpdate {
        attribute address : String;
        attribute status : String;
        attribute value : Real;
    }
    
    attribute def TemperatureValue :> Real;
    attribute def BrightnessValue :> Real;
    attribute def VoltageValue :> Real;
    
    port def BusPort {
        inout command : OpenWebNetCommand;
        inout status : StatusUpdate;
    }
    
    port def NetworkPort {
        in externalCommand : OpenWebNetCommand;
        out externalStatus : StatusUpdate;
    }
    
    part def SmartHomeBus {
        port gatewayPort : BusPort;
        port psuPort : BusPort;
        port lightPort[3] : BusPort;
        port thermostatPort : BusPort;
        port scenarioPort : BusPort;
    }
    
    part def PowerSupplyUnit {
        port busPort : ~BusPort;
        attribute inputVoltage : VoltageValue = 230;
        attribute outputVoltage : VoltageValue = 27;
    }
    
    part def BusGateway {
        port networkPort : NetworkPort;
        port busPort : ~BusPort;
        
        state machine GatewayBehavior {
            entry then Idle;
            state Idle {
                accept cmd : OpenWebNetCommand via networkPort.externalCommand
                do action { send cmd via busPort.command; }
                then Idle;
                
                accept stat : StatusUpdate via busPort.status
                do action { send stat via networkPort.externalStatus; }
                then Idle;
            }
        }
    }
    
    part def SmartphoneApp {
        port networkPort : ~NetworkPort;
    }
    
    part def LightingActuator {
        port busPort : ~BusPort;
        attribute address : String;
        attribute brightness : BrightnessValue = 0;
        
        state machine LightBehavior {
            entry then Off;
            state Off {
                accept cmd : OpenWebNetCommand via busPort.command
                    if cmd.address == address and cmd.command == "ON"
                do action {
                    brightness = 100;
                    send new StatusUpdate(address, "ON", brightness) via busPort.status;
                }
                then On;
            }
            state On {
                accept cmd : OpenWebNetCommand via busPort.command
                    if cmd.address == address and cmd.command == "OFF"
                do action {
                    brightness = 0;
                    send new StatusUpdate(address, "OFF", brightness) via busPort.status;
                }
                then Off;
                
                accept cmd : OpenWebNetCommand via busPort.command
                    if cmd.address == address and cmd.command == "DIM"
                do action {
                    brightness = cmd.value;
                    send new StatusUpdate(address, "DIM", brightness) via busPort.status;
                }
                then On;
            }
        }
    }
    
    part def Thermostat {
        port busPort : ~BusPort;
        attribute address : String;
        attribute currentTemp : TemperatureValue = 20;
        attribute targetTemp : TemperatureValue = 21;
        
        state machine ThermostatBehavior {
            entry then Monitoring;
            state Monitoring {
                accept cmd : OpenWebNetCommand via busPort.command
                    if cmd.address == address and cmd.command == "SET_TEMP"
                do action { targetTemp = cmd.value; }
                then Monitoring;
            }
        }
    }
    
    part def ScenarioController {
        port busPort : ~BusPort;
        attribute address : String;
        
        state machine ScenarioBehavior {
            entry then Idle;
            state Idle {
                accept cmd : OpenWebNetCommand via busPort.command
                    if cmd.address == address and cmd.command == "EVENING"
                do action {
                    send new OpenWebNetCommand("L1", "DIM", 20) via busPort.command;
                    send new OpenWebNetCommand("L3", "ON", 100) via busPort.command;
                    send new OpenWebNetCommand("T1", "SET_TEMP", 18) via busPort.command;
                }
                then Idle;
                
                accept cmd : OpenWebNetCommand via busPort.command
                    if cmd.address == address and cmd.command == "MORNING"
                do action {
                    send new OpenWebNetCommand("L1", "ON", 100) via busPort.command;
                    send new OpenWebNetCommand("L3", "OFF", 0) via busPort.command;
                    send new OpenWebNetCommand("T1", "SET_TEMP", 21) via busPort.command;
                }
                then Idle;
            }
        }
    }
    
    requirement def CentralizedControlReq {
        doc /* The system shall provide centralized management of lighting, climate, and scenarios via a low-voltage bus. */
    }
    requirement def RemoteAccessReq {
        doc /* The gateway shall translate external network commands to internal bus messages and return status updates. */
    }
    requirement def LightingControlReq {
        doc /* Lighting actuators shall support on/off and dimming functions. */
    }
    requirement def ClimateControlReq {
        doc /* The thermostat shall automatically regulate heating and cooling based on a target temperature. */
    }
    requirement def ScenarioReq {
        doc /* The system shall execute pre-programmed multi-device routines upon trigger. */
    }
    
    part def SmartHomeSystem {
        part bus : SmartHomeBus;
        
        part psu : PowerSupplyUnit;
        connect psu.busPort to bus.psuPort;
        
        part gateway : BusGateway;
        connect gateway.busPort to bus.gatewayPort;
        
        part smartphoneApp : SmartphoneApp;
        connect smartphoneApp.networkPort to gateway.networkPort;
        
        part livingRoomLight : LightingActuator {
            attribute :>> address = "L1";
        }
        connect livingRoomLight.busPort to bus.lightPort[1];
        
        part kitchenLight : LightingActuator {
            attribute :>> address = "L2";
        }
        connect kitchenLight.busPort to bus.lightPort[2];
        
        part bedroomLight : LightingActuator {
            attribute :>> address = "L3";
        }
        connect bedroomLight.busPort to bus.lightPort[3];
        
        part thermostat : Thermostat {
            attribute :>> address = "T1";
        }
        connect thermostat.busPort to bus.thermostatPort;
        
        part scenarioController : ScenarioController {
            attribute :>> address = "S1";
        }
        connect scenarioController.busPort to bus.scenarioPort;
    }
    
    part homeSystem : SmartHomeSystem;
    
    satisfy CentralizedControlReq by homeSystem;
    satisfy RemoteAccessReq by homeSystem.gateway;
    satisfy LightingControlReq by homeSystem.livingRoomLight, homeSystem.kitchenLight, homeSystem.bedroomLight;
    satisfy ClimateControlReq by homeSystem.thermostat;
    satisfy ScenarioReq by homeSystem.scenarioController;
}
