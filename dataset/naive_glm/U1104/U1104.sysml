package InsteonHomeAutomation {
    import ScalarValues::*;
    import ISQ::*;
    import Units::*;

    // ---------- Units ----------
    attribute def PercentUnit :> Unit;
    attribute def CelsiusUnit :> Unit;
    attribute def WattUnit :> Unit;
    attribute def KilowattHourUnit :> Unit;
    attribute def LuxUnit :> Unit;
    attribute def HertzUnit :> Unit;
    attribute def SecondUnit :> Unit;

    // ---------- Value Types ----------
    value type BrightnessLevel :> Real { unit : PercentUnit; }
    value type TemperatureValue :> Real { unit : CelsiusUnit; }
    value type PowerValue :> Real { unit : WattUnit; }
    value type EnergyValue :> Real { unit : KilowattHourUnit; }
    value type LuminanceValue :> Real { unit : LuxUnit; }
    value type FrequencyValue :> Real { unit : HertzUnit; }
    value type TimeValue :> Real { unit : SecondUnit; }

    // ---------- Enumerations ----------
    enum def CommandKind { on; off; dim; brighten; setLevel; statusRequest; reportStatus; sceneTrigger; }
    enum def ClimateMode { off; heat; cool; auto; }
    enum def DeviceState { off; on; standby; active; fault; }
    enum def TriggerSource { user; schedule; sensor; remote; internal; }

    // ---------- Items ----------
    item def InsteonMessage {
        attribute sourceId : String;
        attribute targetId : String;
        attribute command : CommandKind;
        attribute payload : String;
        attribute hopCount : Integer;
        attribute maxHops : Integer = 3;
        attribute powerlinePath : Boolean;
        attribute rfPath : Boolean;
    }

    item def StatusReport {
        attribute deviceId : String;
        attribute state : DeviceState;
        attribute brightness : BrightnessLevel;
        attribute power : PowerValue;
        attribute energy : EnergyValue;
        attribute temperature : TemperatureValue;
        attribute luminance : LuminanceValue;
    }

    item def SensorEvent {
        attribute sensorId : String;
        attribute motionDetected : Boolean;
        attribute luminance : LuminanceValue;
        attribute timestamp : TimeValue;
    }

    item def ScheduleEntry {
        attribute time : TimeValue;
        attribute deviceId : String;
        attribute command : CommandKind;
        attribute brightness : BrightnessLevel;
    }

    // ---------- Signals ----------
    item def OnSignal :> InsteonMessage;
    item def OffSignal :> InsteonMessage;
    item def SetLevelSignal :> InsteonMessage { attribute level : BrightnessLevel; }
    item def StatusRequestSignal :> InsteonMessage;
    item def StatusReportSignal :> InsteonMessage { attribute report : StatusReport; }
    item def MotionDetectedSignal :> InsteonMessage;
    item def MotionClearedSignal :> InsteonMessage;
    item def SceneTriggerSignal :> InsteonMessage { attribute sceneId : String; }
    item def UserInputSignal { attribute command : CommandKind; attribute level : BrightnessLevel; }

    // ---------- Ports ----------
    port def PowerlinePort {
        in item message : InsteonMessage;
        out item message : InsteonMessage;
    }

    port def RFPort {
        in item message : InsteonMessage;
        out item message : InsteonMessage;
    }

    port def DualBandPort {
        port powerline : PowerlinePort;
        port rf : RFPort;
    }

    port def InternetPort {
        in item request : String;
        out item response : String;
    }

    port def ClimateControlPort {
        in item mode : ClimateMode;
        in item setpoint : TemperatureValue;
        out item currentTemp : TemperatureValue;
    }

    port def PowerLoadPort {
        out item power : PowerValue;
        out item energy : EnergyValue;
    }

    port def UserInputPort {
        in item command : CommandKind;
        in item level : BrightnessLevel;
    }

    // ---------- Connections ----------
    connection def PowerlineLink {
        end a : PowerlinePort;
        end b : PowerlinePort;
        flow message : InsteonMessage;
    }

    connection def RFLink {
        end a : RFPort;
        end b : RFPort;
        flow message : InsteonMessage;
    }

    connection def InternetLink {
        end a : InternetPort;
        end b : InternetPort;
        flow request : String;
        flow response : String;
    }

    // ---------- Base Device ----------
    part def InsteonDevice {
        port dualBandPort : DualBandPort;
        attribute deviceId : String;
        attribute state : DeviceState = DeviceState::off;
        attribute repeaterEnabled : Boolean = true;
        attribute maxHops : Integer = 3;

        action def receiveMessage {
            in msg : InsteonMessage;
            if msg.targetId == deviceId then {
                executeCommand(msg);
            } else if repeaterEnabled && msg.hopCount < msg.maxHops then {
                rebroadcast(msg);
            } endif;
        }

        action def executeCommand {
            in msg : InsteonMessage;
        }

        action def rebroadcast {
            in msg : InsteonMessage;
            attribute nextHop : Integer = msg.hopCount + 1;
            send InsteonMessage(sourceId = msg.sourceId, targetId = msg.targetId, command = msg.command, payload = msg.payload, hopCount = nextHop, maxHops = msg.maxHops, powerlinePath = true, rfPath = true) to dualBandPort.powerline;
            send InsteonMessage(sourceId = msg.sourceId, targetId = msg.targetId, command = msg.command, payload = msg.payload, hopCount = nextHop, maxHops = msg.maxHops, powerlinePath = true, rfPath = true) to dualBandPort.rf;
        }

        state machine DeviceBehavior {
            entry; then Listening;
            state Listening;
            transition from Listening to Executing accept InsteonMessage;
            state Executing {
                entry { executeCommand; }
            }
            transition from Executing to Listening when done;
        }
    }

    // ---------- Dimmable Switch ----------
    part def DimmableSwitch :> InsteonDevice {
        attribute brightness : BrightnessLevel = 0;
        attribute loadConnected : Boolean = true;

        action def executeCommand :> InsteonDevice::executeCommand {
            in msg : InsteonMessage;
            if msg.command == CommandKind::on then {
                brightness := 100;
                state := DeviceState::on;
            } elseif msg.command == CommandKind::off then {
                brightness := 0;
                state := DeviceState::off;
            } elseif msg.command == CommandKind::setLevel then {
                brightness := msg.payload;
                state := DeviceState::on;
            } elseif msg.command == CommandKind::statusRequest then {
                send StatusReportSignal(report = StatusReport(deviceId = deviceId, state = state, brightness = brightness)) to dualBandPort.powerline;
                send StatusReportSignal(report = StatusReport(deviceId = deviceId, state = state, brightness = brightness)) to dualBandPort.rf;
            } endif;
        }

        state machine SwitchBehavior {
            entry; then Off;
            state Off {
                entry { brightness := 0; state := DeviceState::off; }
            }
            transition from Off to On accept OnSignal;
            transition from Off to Dimmed accept SetLevelSignal;
            state On {
                entry { brightness := 100; state := DeviceState::on; }
            }
            state Dimmed {
                entry { brightness := 50; state := DeviceState::on; }
            }
            transition from On to Off accept OffSignal;
            transition from Dimmed to Off accept OffSignal;
            transition from Dimmed to On accept OnSignal;
            transition from On to Dimmed accept SetLevelSignal;
        }
    }

    // ---------- Motion Sensor ----------
    part def MotionSensor :> InsteonDevice {
        attribute motionDetected : Boolean = false;
        attribute luminance : LuminanceValue = 0;
        attribute darkThreshold : LuminanceValue = 10;
        attribute reportInterval : TimeValue = 30;

        action def detectMotion {
            if motionDetected && luminance < darkThreshold then {
                send MotionDetectedSignal(sourceId = deviceId, targetId = "*", command = CommandKind::sceneTrigger, payload = "motion_dark", hopCount = 0, maxHops = maxHops, powerlinePath = true, rfPath = true) to dualBandPort.powerline;
                send MotionDetectedSignal(sourceId = deviceId, targetId = "*", command = CommandKind::sceneTrigger, payload = "motion_dark", hopCount = 0, maxHops = maxHops, powerlinePath = true, rfPath = true) to dualBandPort.rf;
            } elseif !motionDetected then {
                send MotionClearedSignal(sourceId = deviceId, targetId = "*", command = CommandKind::off, payload = "motion_clear", hopCount = 0, maxHops = maxHops, powerlinePath = true, rfPath = true) to dualBandPort.powerline;
                send MotionClearedSignal(sourceId = deviceId, targetId = "*", command = CommandKind::off, payload = "motion_clear", hopCount = 0, maxHops = maxHops, powerlinePath = true, rfPath = true) to dualBandPort.rf;
            } endif;
        }

        action def measureLuminance {
            // luminance updated by physical sensing
        }

        state machine SensorBehavior {
            entry; then Idle;
            state Idle;
            transition from Idle to MotionDetectedState when motionDetected && luminance < darkThreshold;
            state MotionDetectedState {
                entry { detectMotion; }
            }
            transition from MotionDetectedState to Idle when !motionDetected;
        }
    }

    // ---------- Thermostat ----------
    part def Thermostat :> InsteonDevice {
        port climatePort : ClimateControlPort;
        attribute currentTemperature : TemperatureValue = 22;
        attribute setpoint : TemperatureValue = 21;
        attribute mode : ClimateMode = ClimateMode::off;
        attribute schedule : ScheduleEntry[*];
        attribute tolerance : TemperatureValue = 1;

        action def regulateClimate {
            if mode == ClimateMode::heat && currentTemperature < setpoint - tolerance then {
                state := DeviceState::active;
            } elseif mode == ClimateMode::cool && currentTemperature > setpoint + tolerance then {
                state := DeviceState::active;
            } else {
                state := DeviceState::standby;
            } endif;
        }

        action def executeCommand :> InsteonDevice::executeCommand {
            in msg : InsteonMessage;
            if msg.command == CommandKind::setLevel then {
                setpoint := msg.payload;
            } elseif msg.command == CommandKind::statusRequest then {
                send StatusReportSignal(report = StatusReport(deviceId = deviceId, state = state, temperature = currentTemperature)) to dualBandPort.powerline;
                send StatusReportSignal(report = StatusReport(deviceId = deviceId, state = state, temperature = currentTemperature)) to dualBandPort.rf;
            } endif;
        }

        state machine ThermostatBehavior {
            entry; then Idle;
            state Idle;
            transition from Idle to Heating when mode == ClimateMode::heat && currentTemperature < setpoint - tolerance;
            transition from Idle to Cooling when mode == ClimateMode::cool && currentTemperature > setpoint + tolerance;
            state Heating {
                entry { state := DeviceState::active; }
            }
            state Cooling {
                entry { state := DeviceState::active; }
            }
            transition from Heating to Idle when currentTemperature >= setpoint;
            transition from Cooling to Idle when currentTemperature <= setpoint;
        }
    }

    // ---------- Smart Outlet ----------
    part def SmartOutlet :> InsteonDevice {
        port loadPort : PowerLoadPort;
        attribute powerState : Boolean = false;
        attribute instantaneousPower : PowerValue = 0;
        attribute cumulativeEnergy : EnergyValue = 0;
        attribute samplingInterval : TimeValue = 60;

        action def executeCommand :> InsteonDevice::executeCommand {
            in msg : InsteonMessage;
            if msg.command == CommandKind::on then {
                powerState := true;
                state := DeviceState::on;
            } elseif msg.command == CommandKind::off then {
                powerState := false;
                state := DeviceState::off;
            } elseif msg.command == CommandKind::statusRequest then {
                send StatusReportSignal(report = StatusReport(deviceId = deviceId, state = state, power = instantaneousPower, energy = cumulativeEnergy)) to dualBandPort.powerline;
                send StatusReportSignal(report = StatusReport(deviceId = deviceId, state = state, power = instantaneousPower, energy = cumulativeEnergy)) to dualBandPort.rf;
            } endif;
        }

        action def monitorEnergy {
            if powerState then {
                cumulativeEnergy := cumulativeEnergy + instantaneousPower * samplingInterval / 3600;
            } endif;
        }

        state machine OutletBehavior {
            entry; then Off;
            state Off {
                entry { powerState := false; state := DeviceState::off; }
            }
            transition from Off to On accept OnSignal;
            state On {
                entry { powerState := true; state := DeviceState::on; }
            }
            transition from On to Off accept OffSignal;
        }
    }

    // ---------- Insteon Controller ----------
    part def InsteonController :> InsteonDevice {
        port userInputPort : UserInputPort;
        attribute buttonCount : Integer = 8;
        attribute sceneMap : String[*];

        action def handleUserInput {
            in cmd : CommandKind;
            in lvl : BrightnessLevel;
            send InsteonMessage(sourceId = deviceId, targetId = "*", command = cmd, payload = lvl, hopCount = 0, maxHops = maxHops, powerlinePath = true, rfPath = true) to dualBandPort.powerline;
            send InsteonMessage(sourceId = deviceId, targetId = "*", command = cmd, payload = lvl, hopCount = 0, maxHops = maxHops, powerlinePath = true, rfPath = true) to dualBandPort.rf;
        }

        state machine ControllerBehavior {
            entry; then Ready;
            state Ready;
            transition from Ready to Transmitting accept UserInputSignal;
            state Transmitting {
                entry { handleUserInput; }
            }
            transition from Transmitting to Ready when done;
        }
    }

    // ---------- Insteon Hub ----------
    part def InsteonHub :> InsteonDevice {
        port internetPort : InternetPort;
        attribute deviceRegistry : String[*];
        attribute scenes : String[*];
        attribute schedules : ScheduleEntry[*];
        attribute powerOK : Boolean = true;
        attribute internetConnected : Boolean = true;

        action def routeMessage {
            in msg : InsteonMessage;
            send msg to dualBandPort.powerline;
            send msg to dualBandPort.rf;
        }

        action def processRemoteCommand {
            in request : String;
            // parse request and generate InsteonMessage
            send InsteonMessage(sourceId = deviceId, targetId = "*", command = CommandKind::on, payload = request, hopCount = 0, maxHops = maxHops, powerlinePath = true, rfPath = true) to dualBandPort.powerline;
            send InsteonMessage(sourceId = deviceId, targetId = "*", command = CommandKind::on, payload = request, hopCount = 0, maxHops = maxHops, powerlinePath = true, rfPath = true) to dualBandPort.rf;
        }

        action def registerDevice {
            in id : String;
            deviceRegistry := deviceRegistry.append(id);
        }

        state machine HubBehavior {
            entry; then Online;
            state Online;
            transition from Online to Offline when !powerOK;
            state Offline;
            transition from Offline to Online when powerOK;
        }
    }

    // ---------- Network ----------
    part def DualBandMeshNetwork {
        port powerlineBus : PowerlinePort[*];
        port rfBus : RFPort[*];
        attribute deviceCount : Integer;
        attribute powerlineCarrier : FrequencyValue = 131;
        attribute rfCarrier : FrequencyValue = 915;
        attribute messageTimeout : TimeValue = 2;
    }

    // ---------- System ----------
    part def InsteonSystem {
        part hub : InsteonHub;
        part hallwaySwitch : DimmableSwitch;
        part livingRoomSwitch : DimmableSwitch;
        part hallwayMotionSensor : MotionSensor;
        part homeThermostat : Thermostat;
        part kitchenOutlet : SmartOutlet;
        part livingRoomOutlet : SmartOutlet;
        part keypadController : InsteonController;
        part network : DualBandMeshNetwork;

        connection : PowerlineLink connect hub.dualBandPort.powerline to network.powerlineBus;
        connection : RFLink connect hub.dualBandPort.rf to network.rfBus;

        connection : PowerlineLink connect hallwaySwitch.dualBandPort.powerline to network.powerlineBus;
        connection : RFLink connect hallwaySwitch.dualBandPort.rf to network.rfBus;

        connection : PowerlineLink connect livingRoomSwitch.dualBandPort.powerline to network.powerlineBus;
        connection : RFLink connect livingRoomSwitch.dualBandPort.rf to network.rfBus;

        connection : PowerlineLink connect hallwayMotionSensor.dualBandPort.powerline to network.powerlineBus;
        connection : RFLink connect hallwayMotionSensor.dualBandPort.rf to network.rfBus;

        connection : PowerlineLink connect homeThermostat.dualBandPort.powerline to network.powerlineBus;
        connection : RFLink connect homeThermostat.dualBandPort.rf to network.rfBus;

        connection : PowerlineLink connect kitchenOutlet.dualBandPort.powerline to network.powerlineBus;
        connection : RFLink connect kitchenOutlet.dualBandPort.rf to network.rfBus;

        connection : PowerlineLink connect livingRoomOutlet.dualBandPort.powerline to network.powerlineBus;
        connection : RFLink connect livingRoomOutlet.dualBandPort.rf to network.rfBus;

        connection : PowerlineLink connect keypadController.dualBandPort.powerline to network.powerlineBus;
        connection : RFLink connect keypadController.dualBandPort.rf to network.rfBus;

        connection : ClimateControlPort connect homeThermostat.climatePort to homeThermostat.climatePort;
        connection : PowerLoadPort connect kitchenOutlet.loadPort to kitchenOutlet.loadPort;
        connection : PowerLoadPort connect livingRoomOutlet.loadPort to livingRoomOutlet.loadPort;
        connection : UserInputPort connect keypadController.userInputPort to keypadController.userInputPort;
    }

    // ---------- Requirements ----------
    requirement def DualBandReliabilityRequirement {
        subject system : InsteonSystem;
        requirement {
            the system shall transmit each command over both powerline and RF communication paths simultaneously.
        }
    }

    requirement def MeshRepeaterRequirement {
        subject device : InsteonDevice;
        requirement {
            each device shall repeat received messages until the maximum hop count is reached.
        }
    }

    requirement def RemoteControlRequirement {
        subject hub : InsteonHub;
        requirement {
            the hub shall provide internet bridge functionality for remote control via a smartphone application.
        }
    }

    requirement def DimmingRequirement {
        subject switch : DimmableSwitch;
        requirement {
            the switch shall support on, off, and brightness level adjustment commands.
        }
    }

    requirement def MotionTriggerRequirement {
        subject sensor : MotionSensor;
        requirement {
            the sensor shall detect motion and ambient light and trigger other devices when motion is detected in the dark.
        }
    }

    requirement def ClimateControlRequirement {
        subject thermostat : Thermostat;
        requirement {
            the thermostat shall control heating and cooling based on schedules, remote commands, or system events.
        }
    }

    requirement def EnergyMonitoringRequirement {
        subject outlet : SmartOutlet;
        requirement {
            the outlet shall monitor and report energy consumption of connected devices.
        }
    }

    requirement def PeerToPeerRequirement {
        subject system : InsteonSystem;
        requirement {
            the system shall support peer-to-peer communication for basic operations without relying on a central computer or cloud connection.
        }
    }

    requirement def ControllerCommandRequirement {
        subject controller : InsteonController;
        requirement {
            the controller shall send commands to other devices in the network upon user input.
        }
    }

    // ---------- Requirement Satisfaction ----------
    part def InsteonSystemWithRequirements :> InsteonSystem {
        satisfy DualBandReliabilityRequirement by system;
        satisfy PeerToPeerRequirement by system;
        satisfy MeshRepeaterRequirement by hub;
        satisfy MeshRepeaterRequirement by hallwaySwitch;
        satisfy MeshRepeaterRequirement by livingRoomSwitch;
        satisfy MeshRepeaterRequirement by hallwayMotionSensor;
        satisfy MeshRepeaterRequirement by homeThermostat;
        satisfy MeshRepeaterRequirement by kitchenOutlet;
        satisfy MeshRepeaterRequirement by livingRoomOutlet;
        satisfy MeshRepeaterRequirement by keypadController;
        satisfy RemoteControlRequirement by hub;
        satisfy DimmingRequirement by hallwaySwitch;
        satisfy DimmingRequirement by livingRoomSwitch;
        satisfy MotionTriggerRequirement by hallwayMotionSensor;
        satisfy ClimateControlRequirement by homeThermostat;
        satisfy EnergyMonitoringRequirement by kitchenOutlet;
        satisfy EnergyMonitoringRequirement by livingRoomOutlet;
        satisfy ControllerCommandRequirement by keypadController;
    }
}
