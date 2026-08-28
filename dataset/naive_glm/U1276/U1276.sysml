package CBusSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def BrightnessLevel :> Real { unit '%'; min 0; max 100; }
    value def RampDuration :> Real { unit 's'; }
    value def TimeoutDuration :> Real { unit 's'; }
    value def GroupAddress :> Integer { min 0; max 255; }
    value def SceneId :> Integer { min 0; max 255; }
    value def TimeOfDay :> Real { unit 'h'; min 0; max 24; }

    // ===== Items =====
    item def CBusCommand {
        attribute targetGroup : GroupAddress;
        attribute commandType : CBusCommandType;
        attribute level : BrightnessLevel[0..1];
        attribute rampTime : RampDuration[0..1];
        attribute scene : SceneId[0..1];
    }

    enum def CBusCommandType {
        ON;
        OFF;
        RAMP_UP;
        RAMP_DOWN;
        SET_LEVEL;
        RECALL_SCENE;
        STATUS_REQUEST;
    }

    item def OccupancyEvent {
        attribute detected : Boolean;
        attribute timestamp : TimeOfDay;
    }

    item def ScheduleEvent {
        attribute sceneId : SceneId;
        attribute triggerTime : TimeOfDay;
        attribute targetGroups : GroupAddress[*];
    }

    item def StatusReport {
        attribute group : GroupAddress;
        attribute currentLevel : BrightnessLevel;
        attribute loadActive : Boolean;
    }

    item def ProgrammingData {
        attribute groupAssignments : GroupAddress[*];
        attribute rampProfiles : RampDuration[*];
        attribute sceneDefinitions : SceneId[*];
    }

    // ===== Ports =====
    port def CBusNetworkPort {
        out command : CBusCommand;
        in status : StatusReport;
    }

    port def CBusNetworkInputPort {
        out command : CBusCommand;
    }

    port def CBusNetworkOutputPort {
        in command : CBusCommand;
        out status : StatusReport;
    }

    port def PowerInputPort {
        in power : DC;
    }

    port def PowerOutputPort {
        out power : DC;
    }

    port def LoadPort {
        out loadPower : AC;
    }

    port def EthernetPort {
        inout programming : ProgrammingData;
        inout monitoring : StatusReport;
    }

    port def SensorInputPort {
        in occupancy : OccupancyEvent;
    }

    port def SwitchInputPort {
        in pressed : Boolean;
    }

    item def DC;
    item def AC;

    // ===== Interfaces =====
    interface def CBusCommunication {
        end sender : CBusNetworkPort;
        end receiver : CBusNetworkPort;
    }

    interface def PowerDistribution {
        end source : PowerOutputPort;
        end sink : PowerInputPort;
    }

    // ===== Parts: Core Devices =====
    part def CBusPowerSupply {
        attribute outputVoltage : Voltage = 36 [V];
        attribute maxCurrent : Current = 2.0 [A];
        attribute maxPower : Power = 72 [W];

        port cbusPowerOut : PowerOutputPort;

        state def PowerSupplyStates {
            entry; then Operational;
            state Operational;
            state Fault {
                entry action { send FaultIndication(); }
            }
            transition Operational to Fault when outputVoltage < 30 [V];
            transition Fault to Operational when outputVoltage >= 35 [V];
        }

        exhibit state PowerSupplyStates;
    }

    part def CBusNetwork {
        attribute networkVoltage : Voltage = 36 [V];
        attribute devicesConnected : Integer = 0;

        port powerIn : PowerInputPort;
        port powerOut : PowerOutputPort;

        flow powerIn.power to powerOut.power;

        attribute connectedPorts : CBusNetworkPort[*];

        perform action distributeCommands {
            in commands : CBusCommand[*];
        }
    }

    // ===== Parts: Input Devices =====
    part def WallSwitch {
        attribute buttonCount : Integer = 4;
        attribute groupAssignments : GroupAddress[0..*];
        attribute debounceTime : RampDuration = 0.05 [s];

        port switchInput : SwitchInputPort;
        port cbusOut : CBusNetworkInputPort;

        perform action generateCommand {
            in pressed : Boolean;
            out command : CBusCommand;
        }

        exhibit action generateCommand {
            if pressed then {
                send CBusCommand{targetGroup = groupAssignments[1], commandType = CBusCommandType::ON, level = 100 [%]} to cbusOut;
            } else {
                send CBusCommand{targetGroup = groupAssignments[1], commandType = CBusCommandType::OFF} to cbusOut;
            }
        }
    }

    part def MotionSensor {
        attribute detectionRange : Real = 8.0 [m];
        attribute timeoutPeriod : TimeoutDuration = 300 [s];
        attribute targetGroup : GroupAddress;
        attribute lastDetectionTime : TimeOfDay;

        port sensorInput : SensorInputPort;
        port cbusOut : CBusNetworkInputPort;

        state def MotionSensorStates {
            entry; then Idle;
            state Idle {
                entry action { /* sensor armed */ }
            }
            state Occupied {
                entry action {
                    send CBusCommand{targetGroup = targetGroup, commandType = CBusCommandType::ON, level = 100 [%]} to cbusOut;
                }
            }
            state TimeoutPending {
                entry action { start timeoutTimer; }
            }
            transition Idle to Occupied when sensorInput.occupancy.detected == true;
            transition Occupied to TimeoutPending when sensorInput.occupancy.detected == false;
            transition TimeoutPending to Occupied when sensorInput.occupancy.detected == true;
            transition TimeoutPending to Idle when timeoutTimer.elapsed >= timeoutPeriod {
                action {
                    send CBusCommand{targetGroup = targetGroup, commandType = CBusCommandType::OFF} to cbusOut;
                }
            }
        }

        exhibit state MotionSensorStates;
    }

    part def ScheduleController {
        attribute scheduledEvents : ScheduleEvent[*];
        attribute currentTime : TimeOfDay;
        attribute activeScenes : SceneId[*];

        port cbusOut : CBusNetworkInputPort;

        perform action checkSchedule {
            in time : TimeOfDay;
            out command : CBusCommand;
        }

        exhibit action checkSchedule {
            for event in scheduledEvents {
                if time == event.triggerTime then {
                    for grp in event.targetGroups {
                        send CBusCommand{targetGroup = grp, commandType = CBusCommandType::RECALL_SCENE, scene = event.sceneId} to cbusOut;
                    }
                }
            }
        }

        state def ScheduleControllerStates {
            entry; then Monitoring;
            state Monitoring {
                do action { checkSchedule(currentTime); }
            }
        }

        exhibit state ScheduleControllerStates;
    }

    // ===== Parts: Output Devices =====
    part def OutputUnit {
        attribute assignedGroups : GroupAddress[*];
        attribute currentLevel : BrightnessLevel = 0 [%];
        attribute loadActive : Boolean = false;

        port cbusIn : CBusNetworkOutputPort;
        port loadOut : LoadPort;

        perform action processCommand {
            in command : CBusCommand;
        }

        exhibit action processCommand {
            if command.targetGroup in assignedGroups then {
                match command.commandType {
                    CBusCommandType::ON => { currentLevel = 100 [%]; loadActive = true; }
                    CBusCommandType::OFF => { currentLevel = 0 [%]; loadActive = false; }
                    CBusCommandType::SET_LEVEL => { currentLevel = command.level; loadActive = (command.level > 0 [%]); }
                    else => { /* no action */ }
                }
                send StatusReport{group = command.targetGroup, currentLevel = currentLevel, loadActive = loadActive} to cbusIn;
            }
        }
    }

    part def Dimmer :> OutputUnit {
        attribute minLevel : BrightnessLevel = 1 [%];
        attribute maxLevel : BrightnessLevel = 100 [%];
        attribute rampRate : RampDuration = 2.0 [s];
        attribute ratedLoad : Power = 500 [W];

        override action processCommand {
            in command : CBusCommand;
        }

        exhibit action processCommand {
            if command.targetGroup in assignedGroups then {
                match command.commandType {
                    CBusCommandType::ON => { rampTo(100 [%], rampRate); }
                    CBusCommandType::OFF => { rampTo(0 [%], rampRate); }
                    CBusCommandType::RAMP_UP => { rampTo(currentLevel + 10 [%], command.rampTime); }
                    CBusCommandType::RAMP_DOWN => { rampTo(currentLevel - 10 [%], command.rampTime); }
                    CBusCommandType::SET_LEVEL => { rampTo(command.level, command.rampTime); }
                    CBusCommandType::RECALL_SCENE => { recallScene(command.scene); }
                    else => { /* no action */ }
                }
                send StatusReport{group = command.targetGroup, currentLevel = currentLevel, loadActive = loadActive} to cbusIn;
            }
        }

        perform action rampTo {
            in target : BrightnessLevel;
            in duration : RampDuration;
        }

        perform action recallScene {
            in scene : SceneId;
        }

        state def DimmerStates {
            entry; then Off;
            state Off {
                entry action { currentLevel = 0 [%]; loadActive = false; }
            }
            state Ramping {
                entry action { /* ramp in progress */ }
            }
            state On {
                entry action { loadActive = true; }
            }
            transition Off to Ramping when currentLevel > 0 [%];
            transition Ramping to On when currentLevel >= targetLevel;
            transition On to Ramping when currentLevel < targetLevel;
            transition Ramping to Off when currentLevel == 0 [%];
        }

        attribute targetLevel : BrightnessLevel;

        exhibit state DimmerStates;
    }

    part def Relay :> OutputUnit {
        attribute ratedCurrent : Current = 16 [A];
        attribute contactType : String = "latching";

        override action processCommand {
            in command : CBusCommand;
        }

        exhibit action processCommand {
            if command.targetGroup in assignedGroups then {
                match command.commandType {
                    CBusCommandType::ON => { currentLevel = 100 [%]; loadActive = true; }
                    CBusCommandType::OFF => { currentLevel = 0 [%]; loadActive = false; }
                    CBusCommandType::RECALL_SCENE => { /* relays may toggle based on scene */ }
                    else => { /* no action */ }
                }
                send StatusReport{group = command.targetGroup, currentLevel = currentLevel, loadActive = loadActive} to cbusIn;
            }
        }

        state def RelayStates {
            entry; then Open;
            state Open {
                entry action { loadActive = false; currentLevel = 0 [%]; }
            }
            state Closed {
                entry action { loadActive = true; currentLevel = 100 [%]; }
            }
            transition Open to Closed when command.commandType == CBusCommandType::ON;
            transition Closed to Open when command.commandType == CBusCommandType::OFF;
        }

        exhibit state RelayStates;
    }

    // ===== Network Interface =====
    part def NetworkInterface {
        attribute baudRate : Integer = 9600;
        attribute connected : Boolean = false;

        port cbusPort : CBusNetworkPort;
        port ethernetPort : EthernetPort;

        perform action receiveProgramming {
            in data : ProgrammingData;
        }

        perform action sendStatus {
            out report : StatusReport;
        }

        perform action issueCommand {
            in command : CBusCommand;
        }

        state def InterfaceStates {
            entry; then Disconnected;
            state Disconnected {
                entry action { connected = false; }
            }
            state Connected {
                entry action { connected = true; }
                do action { /* monitor and relay */ }
            }
            transition Disconnected to Connected when ethernetPort.programming received;
            transition Connected to Disconnected when connectionLost;
        }

        attribute connectionLost : Boolean;

        exhibit state InterfaceStates;
    }

    // ===== Requirements =====
    requirement def PowerSupplyRequirement {
        subject ps : CBusPowerSupply;
        requirement ps.outputVoltage == 36 [V];
        requirement ps.maxPower >= 72 [W];
    }

    requirement def NetworkCommunicationRequirement {
        subject net : CBusNetwork;
        requirement net.networkVoltage >= 15 [V];
        requirement net.networkVoltage <= 36 [V];
    }

    requirement def MotionSensorRequirement {
        subject ms : MotionSensor;
        requirement ms.timeoutPeriod <= 900 [s];
        requirement ms.detectionRange >= 5.0 [m];
    }

    requirement def DimmerRequirement {
        subject dim : Dimmer;
        requirement dim.rampRate <= 10.0 [s];
        requirement dim.ratedLoad >= 350 [W];
    }

    requirement def GroupControlRequirement {
        subject sys : CBusBuildingSystem;
        requirement sys.allOutputsAssignedToGroups;
        requirement sys.singleCommandControlsMultipleOutputs;
    }

    // ===== Top-level System =====
    part def CBusBuildingSystem {
        attribute systemName : String = "Clipsal C-Bus Automation";
        attribute buildingType : String;

        part powerSupply : CBusPowerSupply {
            satisfy PowerSupplyRequirement by powerSupply;
        }

        part network : CBusNetwork;

        part wallSwitches : WallSwitch[2..*];
        part motionSensors : MotionSensor[1..*];
        part scheduleController : ScheduleController;
        part networkInterface : NetworkInterface;

        part dimmers : Dimmer[1..*];
        part relays : Relay[1..*];

        // Power distribution connections
        connection powerFromSupply to network {
            powerSupply.cbusPowerOut -> network.powerIn;
        }

        // C-Bus communication connections
        connection cbusFromSwitches {
            wallSwitches.cbusOut -> network.connectedPorts;
        }

        connection cbusFromSensors {
            motionSensors.cbusOut -> network.connectedPorts;
        }

        connection cbusFromScheduler {
            scheduleController.cbusOut -> network.connectedPorts;
        }

        connection cbusFromInterface {
            networkInterface.cbusPort -> network.connectedPorts;
        }

        connection cbusToDimmers {
            network.connectedPorts -> dimmers.cbusIn;
        }

        connection cbusToRelays {
            network.connectedPorts -> relays.cbusIn;
        }

        // Load outputs
        connection dimmerLoads {
            dimmers.loadOut -> externalLoads;
        }

        connection relayLoads {
            relays.loadOut -> externalLoads;
        }

        part externalLoads :> LoadPort;

        satisfy GroupControlRequirement by self;
    }
}
