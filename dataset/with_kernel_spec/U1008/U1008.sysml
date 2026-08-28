package CEBusHomeAutomation {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    enum def CommandType {
        ON;
        OFF;
        DIM;
        SET_TEMPERATURE;
    }

    enum def StatusType {
        STATE;
        TEMPERATURE;
        ALARM;
    }

    item def CommandPacket {
        attribute targetAddress : String;
        attribute command : CommandType;
        attribute value : Real;
    }

    item def StatusReport {
        attribute sourceAddress : String;
        attribute status : StatusType;
        attribute data : Real;
    }

    item def AlarmSignal {
        attribute sensorAddress : String;
        attribute alarmType : String;
    }

    port def DevicePowerlinePort {
        in command : CommandPacket;
        out status : StatusReport;
        out alarm : AlarmSignal;
    }

    port def ControllerPowerlinePort {
        out command : CommandPacket;
        in status : StatusReport;
        in alarm : AlarmSignal;
    }

    interface def PowerlineInterface {
        end controllerPort : ControllerPowerlinePort;
        end devicePort : ~DevicePowerlinePort;
        flow of CommandPacket from controllerPort.command to devicePort.command;
        flow of StatusReport from devicePort.status to controllerPort.status;
        flow of AlarmSignal from devicePort.alarm to controllerPort.alarm;
    }

    part def SmartLightingModule {
        attribute address : String;
        attribute dimLevel : Real = 100;
        attribute isOn : Boolean = false;
        port powerlinePort : DevicePowerlinePort;

        perform action executeCommand;
        perform action reportStatus;

        exhibit state lightState {
            entry action initial;
            state off;
            state on;
            state dimming;
            transition initial then off;
            transition off_to_on
                first off
                accept cmd : CommandPacket via powerlinePort.command
                if cmd.targetAddress == address and cmd.command == CommandType::ON
                do executeCommand
                then on;
            transition on_to_off
                first on
                accept cmd : CommandPacket via powerlinePort.command
                if cmd.targetAddress == address and cmd.command == CommandType::OFF
                do executeCommand
                then off;
            transition on_to_dimming
                first on
                accept cmd : CommandPacket via powerlinePort.command
                if cmd.targetAddress == address and cmd.command == CommandType::DIM
                do executeCommand
                then dimming;
            transition dimming_to_on
                first dimming
                accept cmd : CommandPacket via powerlinePort.command
                if cmd.targetAddress == address and cmd.command == CommandType::ON
                do executeCommand
                then on;
            transition dimming_to_off
                first dimming
                accept cmd : CommandPacket via powerlinePort.command
                if cmd.targetAddress == address and cmd.command == CommandType::OFF
                do executeCommand
                then off;
        }
    }

    part def ClimateControlModule {
        attribute address : String;
        attribute currentTemperature : ISQ::TemperatureValue;
        attribute setpoint : ISQ::TemperatureValue = 295.15 [K];
        port powerlinePort : DevicePowerlinePort;

        perform action senseTemperature;
        perform action controlHVAC;

        exhibit state climateState {
            entry action initial;
            state idle {
                do senseTemperature;
            }
            state heating {
                do controlHVAC;
            }
            state cooling {
                do controlHVAC;
            }
            transition initial then idle;
            transition idle_to_heating
                first idle
                if currentTemperature < setpoint - 0.5 [K]
                then heating;
            transition idle_to_cooling
                first idle
                if currentTemperature > setpoint + 0.5 [K]
                then cooling;
            transition heating_to_idle
                first heating
                if currentTemperature >= setpoint
                then idle;
            transition cooling_to_idle
                first cooling
                if currentTemperature <= setpoint
                then idle;
            transition set_temp
                first idle
                accept cmd : CommandPacket via powerlinePort.command
                if cmd.targetAddress == address and cmd.command == CommandType::SET_TEMPERATURE
                then idle;
        }
    }

    part def SecuritySensorModule {
        attribute address : String;
        attribute doorOpen : Boolean = false;
        port powerlinePort : DevicePowerlinePort;

        perform action monitorDoor;
        perform action sendAlarm;

        exhibit state securityState {
            entry action initial;
            state closed {
                do monitorDoor;
            }
            state open {
                entry sendAlarm;
            }
            transition initial then closed;
            transition closed_to_open
                first closed
                if doorOpen
                then open;
            transition open_to_closed
                first open
                if doorOpen == false
                then closed;
        }
    }

    part def ApplianceControlModule {
        attribute address : String;
        attribute isOn : Boolean = false;
        port powerlinePort : DevicePowerlinePort;

        perform action switchPower;

        exhibit state applianceState {
            entry action initial;
            state off;
            state on;
            transition initial then off;
            transition off_to_on
                first off
                accept cmd : CommandPacket via powerlinePort.command
                if cmd.targetAddress == address and cmd.command == CommandType::ON
                do switchPower
                then on;
            transition on_to_off
                first on
                accept cmd : CommandPacket via powerlinePort.command
                if cmd.targetAddress == address and cmd.command == CommandType::OFF
                do switchPower
                then off;
        }
    }

    part def CentralController {
        attribute registry : String[0..*];
        port powerlinePort : ControllerPowerlinePort;

        perform action routeCommand;
        perform action handleAlarm;

        exhibit state controllerState {
            entry action initial;
            state idle;
            state monitoring {
                do routeCommand;
            }
            state alarmHandling {
                do handleAlarm;
            }
            transition initial then idle;
            transition idle_to_monitoring
                first idle
                accept status : StatusReport via powerlinePort.status
                then monitoring;
            transition monitoring_to_idle
                first monitoring
                then idle;
            transition idle_to_alarmHandling
                first idle
                accept alarm : AlarmSignal via powerlinePort.alarm
                then alarmHandling;
            transition alarmHandling_to_idle
                first alarmHandling
                then idle;
        }
    }

    part def HomeSystem {
        part controller : CentralController;
        part livingRoomLight : SmartLightingModule {
            attribute address = "LivingRoomLight";
        }
        part kitchenLight : SmartLightingModule {
            attribute address = "KitchenLight";
        }
        part thermostat : ClimateControlModule {
            attribute address = "Thermostat";
        }
        part frontDoorSensor : SecuritySensorModule {
            attribute address = "FrontDoorSensor";
        }
        part coffeeMaker : ApplianceControlModule {
            attribute address = "CoffeeMaker";
        }

        interface : PowerlineInterface connect controller.powerlinePort to livingRoomLight.powerlinePort;
        interface : PowerlineInterface connect controller.powerlinePort to kitchenLight.powerlinePort;
        interface : PowerlineInterface connect controller.powerlinePort to thermostat.powerlinePort;
        interface : PowerlineInterface connect controller.powerlinePort to frontDoorSensor.powerlinePort;
        interface : PowerlineInterface connect controller.powerlinePort to coffeeMaker.powerlinePort;
    }

    part homeSystem : HomeSystem;

    requirement def CEBusCommunicationReq {
        text = "The system shall use existing electrical power lines for bidirectional communication between the central controller and smart devices.";
    }

    requirement def DeviceRegistryReq {
        text = "The central controller shall maintain a registry of all connected device addresses and route command packets to the correct destination.";
    }

    requirement def AlarmResponseReq {
        text = "Upon receiving an alarm signal from the security sensor, the central controller shall turn on all lighting modules in the house.";
    }

    requirement def ClimateControlReq {
        text = "The climate control module shall monitor temperature and control the HVAC system to maintain the pre-set target temperature.";
    }

    requirement def DimmingReq {
        text = "Smart lighting modules shall support on/off control and dimming capabilities via command packets addressed to them.";
    }

    requirement cEBusCommReq : CEBusCommunicationReq;
    requirement deviceRegReq : DeviceRegistryReq;
    requirement alarmRespReq : AlarmResponseReq;
    requirement climateReq : ClimateControlReq;
    requirement dimmingReq : DimmingReq;

    satisfy cEBusCommReq by homeSystem;
    satisfy deviceRegReq by homeSystem.controller;
    satisfy alarmRespReq by homeSystem.controller;
    satisfy climateReq by homeSystem.thermostat;
    satisfy dimmingReq by homeSystem.livingRoomLight;
}
