package 'KNX Building Automation System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def KNXGroupAddress {
        mainGroup : Integer;
        middleGroup : Integer;
        subGroup : Integer;
    }
    
    attribute def KNXPhysicalAddress {
        area : Integer;
        line : Integer;
        device : Integer;
    }
    
    item def KNXTelegram {
        attribute sourceAddress : KNXPhysicalAddress;
        attribute destinationAddress : KNXGroupAddress;
        attribute priority : TelegramPriority;
        attribute dataPayload : Real;
        attribute timestamp : ISQ::DurationValue;
    }
    
    enum def TelegramPriority {
        system;
        alarm;
        high;
        normal;
    }
    
    port def KNXBusPort {
        out tx : KNXTelegram[*];
        in rx : KNXTelegram[*];
    }
    
    part def KNXPowerSupply {
        attribute outputVoltage : Real;
        attribute maxCurrent : Real;
        attribute nominalPower : ISQ::PowerValue;
    }
    
    part def KNXLineCoupler {
        port mainLine : KNXBusPort;
        port subLine : KNXBusPort;
        
        action routeTelegrams {
            in telegram : KNXTelegram;
            out routedTelegram : KNXTelegram;
        }
    }
    
    part def TemperatureSensor {
        port knxBus : KNXBusPort;
        attribute physicalAddress : KNXPhysicalAddress;
        attribute groupAddress : KNXGroupAddress;
        in measuredTemperature : ISQ::ThermodynamicTemperatureValue;
        
        action transmitTemperature {
            in temp : ISQ::ThermodynamicTemperatureValue;
            out telegram : KNXTelegram;
        }
    }
    
    part def LightingSensor {
        port knxBus : KNXBusPort;
        attribute physicalAddress : KNXPhysicalAddress;
        attribute groupAddress : KNXGroupAddress;
        in measuredIlluminance : ISQ::LuminousIntensityValue;
        
        action transmitIlluminance {
            in lux : ISQ::LuminousIntensityValue;
            out telegram : KNXTelegram;
        }
    }
    
    part def PresenceSensor {
        port knxBus : KNXBusPort;
        attribute physicalAddress : KNXPhysicalAddress;
        attribute groupAddress : KNXGroupAddress;
        out presenceDetected : Boolean;
        
        action transmitPresence {
            in presence : Boolean;
            out telegram : KNXTelegram;
            out payloadValue : Real;
        }
    }
    
    part def DimmingActuator {
        port knxBus : KNXBusPort;
        attribute physicalAddress : KNXPhysicalAddress;
        attribute listenAddress : KNXGroupAddress;
        attribute dimLevel : Real;
        
        action processDimCommand {
            in telegram : KNXTelegram;
            out newLevel : Real;
        }
    }
    
    part def HeatingActuator {
        port knxBus : KNXBusPort;
        attribute physicalAddress : KNXPhysicalAddress;
        attribute listenAddress : KNXGroupAddress;
        attribute valvePosition : Real;
        
        action processValveCommand {
            in telegram : KNXTelegram;
            out newPosition : Real;
        }
    }
    
    part def AutomationController {
        port knxBus : KNXBusPort;
        attribute physicalAddress : KNXPhysicalAddress;
        attribute temperatureSetpoint : ISQ::ThermodynamicTemperatureValue;
        attribute targetIlluminance : ISQ::LuminousIntensityValue;
        
        action processEnvironmentalData {
            in currentTemp : ISQ::ThermodynamicTemperatureValue;
            in currentLux : ISQ::LuminousIntensityValue;
            in presence : Boolean;
            out heatingCommand : KNXTelegram;
            out lightingCommand : KNXTelegram;
        }
    }
    
    action def MonitorSensors {
        out temperature : ISQ::ThermodynamicTemperatureValue;
        out illuminance : ISQ::LuminousIntensityValue;
        out presence : Boolean;
    }
    
    action def DetermineControlActions {
        in temperature : ISQ::ThermodynamicTemperatureValue;
        in illuminance : ISQ::LuminousIntensityValue;
        in presence : Boolean;
        out heatingCommand : KNXTelegram;
        out lightingCommand : KNXTelegram;
    }
    
    action def TransmitCommands {
        in heatingCommand : KNXTelegram;
        in lightingCommand : KNXTelegram;
    }
    
    action def AutomateBuilding {
        first start;
        then merge continuousControl;
        
        then action monitor : MonitorSensors {
            out currentTemperature : ISQ::ThermodynamicTemperatureValue;
            out currentIlluminance : ISQ::LuminousIntensityValue;
            out currentPresence : Boolean;
        }
        
        then action determine : DetermineControlActions {
            in temperature = monitor.currentTemperature;
            in illuminance = monitor.currentIlluminance;
            in presence = monitor.currentPresence;
            out heatingCommand : KNXTelegram;
            out lightingCommand : KNXTelegram;
        }
        
        then action transmit : TransmitCommands {
            in heatingCommand = determine.heatingCommand;
            in lightingCommand = determine.lightingCommand;
        }
        
        then continuousControl;
    }
    
    part def KNXBuildingAutomationSystem;
    
    connection def KNXBusConnection {
        end port devices : KNXBusPort[2..*];
    }
    
    part knxSystem : KNXBuildingAutomationSystem {
        doc /*
            The KNX Building Automation System provides distributed, decentralized control
            of building services including lighting, heating, ventilation, and security.
            Its primary function is to automatically manage the building environment by
            coordinating sensors and actuators through a standardized bus communication
            protocol, optimizing comfort, energy efficiency, and safety based on real-time
            occupancy and environmental conditions.
        */
        
        perform action buildingAutomation : AutomateBuilding;
        
        part powerSupply : KNXPowerSupply {
            attribute :>> outputVoltage = 29.0;
            attribute :>> maxCurrent = 0.64;
            attribute :>> nominalPower = 18.56[W];
        }
        
        part lineCoupler : KNXLineCoupler;
        
        part controller : AutomationController {
            attribute :>> physicalAddress {
                area = 1;
                line = 1;
                device = 1;
            }
            attribute :>> temperatureSetpoint = 294.15[K];
            attribute :>> targetIlluminance = 500.0[cd];
            perform buildingAutomation.determine;
        }
        
        part tempSensor : TemperatureSensor {
            attribute :>> physicalAddress {
                area = 1;
                line = 1;
                device = 10;
            }
            attribute :>> groupAddress {
                mainGroup = 0;
                middleGroup = 1;
                subGroup = 1;
            }
            perform buildingAutomation.monitor;
        }
        
        part lightSensor : LightingSensor {
            attribute :>> physicalAddress {
                area = 1;
                line = 1;
                device = 11;
            }
            attribute :>> groupAddress {
                mainGroup = 0;
                middleGroup = 1;
                subGroup = 2;
            }
            perform buildingAutomation.monitor;
        }
        
        part presenceSensor : PresenceSensor {
            attribute :>> physicalAddress {
                area = 1;
                line = 1;
                device = 12;
            }
            attribute :>> groupAddress {
                mainGroup = 0;
                middleGroup = 1;
                subGroup = 3;
            }
            perform buildingAutomation.monitor;
        }
        
        part dimmer : DimmingActuator {
            attribute :>> physicalAddress {
                area = 1;
                line = 1;
                device = 20;
            }
            attribute :>> listenAddress {
                mainGroup = 1;
                middleGroup = 1;
                subGroup = 1;
            }
        }
        
        part heatingValve : HeatingActuator {
            attribute :>> physicalAddress {
                area = 1;
                line = 1;
                device = 21;
            }
            attribute :>> listenAddress {
                mainGroup = 2;
                middleGroup = 1;
                subGroup = 1;
            }
        }
        
        connection mainBus : KNXBusConnection connect
            lineCoupler.mainLine to controller.knxBus,
            lineCoupler.mainLine to tempSensor.knxBus,
            lineCoupler.mainLine to lightSensor.knxBus,
            lineCoupler.mainLine to presenceSensor.knxBus,
            lineCoupler.mainLine to dimmer.knxBus,
            lineCoupler.mainLine to heatingValve.knxBus;
    }
    
    requirement def SystemRequirement;
    
    requirement <'KNX-REQ-001'> communicationReliability : SystemRequirement {
        doc /*
            The KNX system shall ensure reliable telegram delivery between all devices
            with a success rate of at least 99.9% under normal operating conditions.
        */
        
        subject knxSystem;
    }
    
    requirement <'KNX-REQ-002'> responseTime : SystemRequirement {
        doc /*
            The KNX system shall respond to sensor inputs and transmit control commands
            to actuators within 100 milliseconds to ensure responsive automation.
        */
        
        subject knxSystem;
    }
    
    requirement <'KNX-REQ-003'> energyEfficiency : SystemRequirement {
        doc /*
            The KNX system shall reduce building energy consumption by at least 25%
            through intelligent control of lighting and heating based on occupancy
            and environmental conditions.
        */
        
        subject knxSystem;
    }
}
