package ClipsalCBusSystem {
    attribute def GroupId :> ScalarValues::Integer;
    attribute def CmdAction :> ScalarValues::String;
    attribute def BrightnessLevel :> ScalarValues::Real;
    attribute def VoltageValue :> ScalarValues::Real;
    attribute def DurationValue :> ScalarValues::Real;

    item def Command {
        attribute groupId : GroupId;
        attribute cmdAction : CmdAction;
        attribute level : BrightnessLevel = 0.0;
    }

    attribute def OccupancyDetected;
    attribute def InactivityTimeout;

    item def ScheduledEvent {
        attribute triggerTime : ScalarValues::String;
        attribute groupId : GroupId;
        attribute cmdAction : CmdAction;
        attribute level : BrightnessLevel = 0.0;
    }

    port def CBusPort {
        inout item cmd : Command;
    }

    port def EthernetPort {
        inout item data : ScalarValues::String;
    }

    abstract part def CBusDevice {
        port cbusIF : CBusPort;
        attribute deviceAddress : ScalarValues::String;
    }

    part def PowerSupply :> CBusDevice {
        attribute outputVoltage : VoltageValue = 36.0;
        attribute maxCurrent : ScalarValues::Real = 2.0;
    }

    abstract part def InputDevice :> CBusDevice {
        attribute groupId : GroupId;
    }

    part def WallSwitch :> InputDevice {
        attribute numButtons : ScalarValues::Integer = 4;

        action def PressButton {
            in buttonId : ScalarValues::Integer;
            out cmd : Command;
        }

        action press : PressButton {
            in buttonId = 1;
            out cmd = Command { groupId = groupId; cmdAction = "toggle"; level = 100.0; }
        }

        flow press.cmd to cbusIF.cmd;
    }

    part def MotionSensor :> InputDevice {
        attribute timeout : DurationValue = 600.0;
        attribute isOccupied : ScalarValues::Boolean = false;

        state def OccupancyState;
        state occupancy : OccupancyState {
            entry; then unoccupied;

            state unoccupied;
            accept OccupancyDetected then occupied;

            state occupied;
            accept after timeout then unoccupied;
        }

        action def GenerateOnCommand {
            out cmd : Command;
        }

        action def GenerateOffCommand {
            out cmd : Command;
        }

        action sendOn : GenerateOnCommand {
            out cmd = Command { groupId = groupId; cmdAction = "on"; level = 100.0; }
        }

        action sendOff : GenerateOffCommand {
            out cmd = Command { groupId = groupId; cmdAction = "off"; level = 0.0; }
        }

        flow sendOn.cmd to cbusIF.cmd;
        flow sendOff.cmd to cbusIF.cmd;
    }

    part def ScheduleController :> InputDevice {
        attribute schedule : ScheduledEvent[0..*];

        action def ExecuteSchedule {
            in events : ScheduledEvent[0..*];
            out cmd : Command;
        }

        action execute : ExecuteSchedule {
            in events = schedule;
        }

        flow execute.cmd to cbusIF.cmd;
    }

    abstract part def OutputUnit :> CBusDevice {
        attribute assignedGroups : GroupId[0..*];
    }

    part def Dimmer :> OutputUnit {
        attribute brightness : BrightnessLevel = 0.0;
        attribute rampTime : DurationValue = 2.0;

        state def DimmerState;
        state dimming : DimmerState {
            entry; then off;

            state off;
            accept cmd : Command
                if cmd.cmdAction == "on"
                then on;

            state on;
            accept cmd : Command
                if cmd.cmdAction == "off"
                then off;
        }
    }

    part def Relay :> OutputUnit {
        attribute isClosed : ScalarValues::Boolean = false;

        state def RelayState;
        state relayLogic : RelayState {
            entry; then open;

            state open;
            accept cmd : Command
                if cmd.cmdAction == "on"
                then closed;

            state closed;
            accept cmd : Command
                if cmd.cmdAction == "off"
                then open;
        }
    }

    part def NetworkInterface :> CBusDevice {
        port pcIF : EthernetPort;

        action def MonitorNetwork {
            out status : ScalarValues::String;
        }

        action def ProgramDevice {
            in configData : ScalarValues::String;
            out cmd : Command;
        }

        action monitor : MonitorNetwork;
        action program : ProgramDevice;

        flow program.cmd to cbusIF.cmd;
    }

    part def CBusNetwork {
        port deviceIF : CBusPort[0..*];
    }

    part def CBusSystem {
        part network : CBusNetwork;
        part powerSupply : PowerSupply;
        part wallSwitch1 : WallSwitch {
            attribute :>> groupId = 1;
        }
        part motionSensor1 : MotionSensor {
            attribute :>> groupId = 2;
            attribute :>> timeout = 900.0;
        }
        part scheduleController1 : ScheduleController {
            attribute :>> groupId = 3;
            attribute :>> schedule = (
                ScheduledEvent { triggerTime = "07:00"; groupId = 1; cmdAction = "on"; level = 100.0; },
                ScheduledEvent { triggerTime = "22:00"; groupId = 1; cmdAction = "off"; level = 0.0; }
            );
        }
        part dimmer1 : Dimmer {
            attribute :>> assignedGroups = (1, 3);
            attribute :>> rampTime = 3.0;
        }
        part dimmer2 : Dimmer {
            attribute :>> assignedGroups = (2, 3);
        }
        part relay1 : Relay {
            attribute :>> assignedGroups = (1, 2);
        }
        part pcInterface : NetworkInterface;

        connect powerSupply.cbusIF to network.deviceIF;
        connect wallSwitch1.cbusIF to network.deviceIF;
        connect motionSensor1.cbusIF to network.deviceIF;
        connect scheduleController1.cbusIF to network.deviceIF;
        connect dimmer1.cbusIF to network.deviceIF;
        connect dimmer2.cbusIF to network.deviceIF;
        connect relay1.cbusIF to network.deviceIF;
        connect pcInterface.cbusIF to network.deviceIF;
    }

    part system : CBusSystem;

    requirement def DistributedControlReq {
        doc /* The system shall use distributed intelligence with devices communicating over a shared two-wire network rather than relying on a central computer. */
    }

    requirement def PowerDataNetworkReq {
        doc /* The two-wire network backbone shall carry both regulated 36V DC power and digital command data to all connected devices. */
    }

    requirement def GroupAddressingReq {
        doc /* Each output unit shall respond only to commands addressed to its assigned group addresses, allowing a single command to control multiple loads simultaneously. */
    }

    requirement def MotionSensorTimeoutReq {
        doc /* Motion sensors shall send an off command after a configurable period of inactivity following the last detected occupancy. */
    }

    requirement def DimmerRampReq {
        doc /* Dimmers shall smoothly ramp brightness up or down over a configurable ramp time rather than switching abruptly. */
    }

    requirement def NetworkInterfaceReq {
        doc /* A network interface shall allow a computer to connect for programming, monitoring, and optional centralized control. */
    }

    requirement distCtrl : DistributedControlReq {
        subject :>> system = system;
    }

    requirement powerData : PowerDataNetworkReq {
        subject :>> system = system;
    }

    requirement groupAddr : GroupAddressingReq {
        subject :>> output = system.dimmer1;
    }

    requirement motionTimeout : MotionSensorTimeoutReq {
        subject :>> sensor = system.motionSensor1;
    }

    requirement dimmerRamp : DimmerRampReq {
        subject :>> dimmer = system.dimmer1;
    }

    requirement netIf : NetworkInterfaceReq {
        subject :>> interface = system.pcInterface;
    }
}
