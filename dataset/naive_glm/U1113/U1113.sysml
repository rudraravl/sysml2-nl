package KNX_Building_Automation_System {
    import ScalarValues::*;
    
    // Value Types
    value type TemperatureValue :> Real { 
        attribute unit : String = "degC"; 
    }
    value type BrightnessValue :> Real { 
        attribute unit : String = "lux"; 
    }
    value type DimmingLevel :> Real { 
        attribute unit : String = "%"; 
    }
    value type ValvePosition :> Real { 
        attribute unit : String = "%"; 
    }
    
    // Items
    item def Telegram {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
    }
    
    item def TemperatureData :> Telegram {
        attribute temperature : TemperatureValue;
    }
    
    item def BrightnessData :> Telegram {
        attribute brightness : BrightnessValue;
    }
    
    item def PresenceData :> Telegram {
        attribute isPresent : Boolean;
    }
    
    item def DimmingCommand :> Telegram {
        attribute level : DimmingLevel;
    }
    
    item def HeatingCommand :> Telegram {
        attribute position : ValvePosition;
    }
    
    // Ports
    port def KNXPort {
        out item telegramsOut : Telegram;
        in item telegramsIn : Telegram;
    }
    
    // Interfaces
    interface def KNXBusInterface {
        end port : KNXPort;
        end port : KNXPort;
    }
    
    // Parts
    part def TemperatureSensor {
        attribute physicalAddress : String;
        port knxPort : KNXPort;
        
        action def MeasureTemperature {
            in currentTemp : TemperatureValue;
            out telegram : TemperatureData;
        }
    }
    
    part def LightingSensor {
        attribute physicalAddress : String;
        port knxPort : KNXPort;
        
        action def MeasureBrightness {
            in currentLux : BrightnessValue;
            out telegram : BrightnessData;
        }
    }
    
    part def PresenceSensor {
        attribute physicalAddress : String;
        port knxPort : KNXPort;
        
        action def DetectPresence {
            in detected : Boolean;
            out telegram : PresenceData;
        }
    }
    
    part def DimmingActuator {
        attribute physicalAddress : String;
        port knxPort : KNXPort;
        
        attribute currentLevel : DimmingLevel = 0;
        
        action def ExecuteCommand {
            in cmd : DimmingCommand;
            out level : DimmingLevel;
        }
    }
    
    part def HeatingActuator {
        attribute physicalAddress : String;
        port knxPort : KNXPort;
        
        attribute currentPosition : ValvePosition = 0;
        
        action def AdjustValve {
            in cmd : HeatingCommand;
            out position : ValvePosition;
        }
    }
    
    part def AutomationController {
        attribute physicalAddress : String;
        port knxPort : KNXPort;
        
        attribute desiredTemperature : TemperatureValue = 22.0;
        attribute desiredBrightness : BrightnessValue = 500.0;
        
        action def ProcessTelegrams {
            in tempData : TemperatureData;
            in brightData : BrightnessData;
            in presData : PresenceData;
            out dimCmd : DimmingCommand;
            out heatCmd : HeatingCommand;
            
            if (presData.isPresent) {
                if (brightData.brightness < desiredBrightness) {
                    dimCmd.level = 80;
                } else {
                    dimCmd.level = 0;
                }
                if (tempData.temperature < desiredTemperature) {
                    heatCmd.position = 100;
                } else {
                    heatCmd.position = 0;
                }
            } else {
                dimCmd.level = 0;
                heatCmd.position = 0;
            }
        }
    }
    
    part def KNXPowerSupply {
        attribute voltage : Real = 30;
        port powerPort : KNXPort;
    }
    
    part def LineCoupler {
        attribute physicalAddress : String;
        port primaryLinePort : KNXPort;
        port secondaryLinePort : KNXPort;
        
        action def RouteTelegram {
            in telegram : Telegram;
            out routedTelegram : Telegram;
        }
    }
    
    // Top-level Context
    part def BuildingAutomationSystem {
        port busPort : KNXPort;
        
        part tempSensor : TemperatureSensor {
            attribute physicalAddress = "1.1.1";
        }
        part lightSensor : LightingSensor {
            attribute physicalAddress = "1.1.2";
        }
        part presSensor : PresenceSensor {
            attribute physicalAddress = "1.1.3";
        }
        part dimActuator : DimmingActuator {
            attribute physicalAddress = "1.1.4";
        }
        part heatActuator : HeatingActuator {
            attribute physicalAddress = "1.1.5";
        }
        part controller : AutomationController {
            attribute physicalAddress = "1.1.6";
        }
        part powerSupply : KNXPowerSupply;
        part lineCoupler : LineCoupler {
            attribute physicalAddress = "1.0.0";
        }
        
        interface bus : KNXBusInterface connect 
            tempSensor.knxPort to controller.knxPort,
            lightSensor.knxPort to controller.knxPort,
            presSensor.knxPort to controller.knxPort,
            controller.knxPort to dimActuator.knxPort,
            controller.knxPort to heatActuator.knxPort,
            powerSupply.powerPort to busPort,
            lineCoupler.primaryLinePort to busPort;
    }
    
    // Requirements
    requirement def BuildingAutomationRequirement {
        doc /* The system shall intelligently control lighting and heating based on sensor data. */
        subject system : BuildingAutomationSystem;
    }
    
    requirement tempControl :> BuildingAutomationRequirement {
        doc /* The system shall maintain the room temperature near the desired setpoint. */
    }
    
    requirement lightControl :> BuildingAutomationRequirement {
        doc /* The system shall adjust lighting based on presence and ambient light. */
    }
    
    requirement busComm :> BuildingAutomationRequirement {
        doc /* Devices shall communicate via KNX telegrams. */
    }
}
