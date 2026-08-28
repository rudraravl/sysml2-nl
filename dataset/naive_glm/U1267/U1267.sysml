package ZWaveHomeAutomation {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def Power :> Real {
        unit W;
    }

    value def Energy :> Real {
        unit Wh;
    }

    value def Temperature :> Real {
        unit degC;
    }

    value def BatteryLevel :> Real {
        unit percent;
    }

    value def SignalStrength :> Real {
        unit dBm;
    }

    value def NodeId :> Integer;
    value def HomeId :> Integer;
    value def AccessCode :> String;
    value def RouteHopCount :> Integer;

    // ===== Item Types =====

    item def ZWaveMessage {
        attribute sourceId : NodeId;
        attribute destinationId : NodeId;
        attribute payload : String;
        attribute encrypted : Boolean = true;
        attribute hopCount : RouteHopCount;
    }

    item def CommandMessage :> ZWaveMessage {
        attribute commandType : CommandType;
    }

    item def StatusReport :> ZWaveMessage {
        attribute statusType : String;
    }

    item def AlertMessage :> ZWaveMessage {
        attribute alertType : String;
        attribute timestamp : String;
    }

    enumeration def CommandType {
        ADD_NODE;
        REMOVE_NODE;
        SET_VALUE;
        GET_STATUS;
        LOCK;
        UNLOCK;
        SET_SETPOINT;
        SET_SWITCH;
        DISCOVER_ROUTE;
        HEAL_NETWORK;
    }

    // ===== Port Definitions =====

    port def ZWavePort {
        in item messagesIn : ZWaveMessage;
        out item messagesOut : ZWaveMessage;
        attribute nodeId : NodeId;
        attribute signalStrength : SignalStrength;
    }

    port def PowerPort {
        in item powerIn : Power;
        attribute mainsPowered : Boolean;
    }

    // ===== Abstract Node =====

    part def ZWaveNode {
        attribute nodeId : NodeId;
        attribute homeId : HomeId;
        attribute isMainsPowered : Boolean;
        attribute isRepeater : Boolean;
        attribute batteryLevel : BatteryLevel[0..1];

        port zWavePort : ZWavePort;
        port powerPort : PowerPort;

        attribute currentState : NodeState;

        state machine NodeStateMachine {
            entry;
            state Listening {
                entry;
                transition listen_to_transmit
                    source Listening
                    target Transmitting
                    when zWavePort.messagesIn->notEmpty();
            }
            state Transmitting {
                entry;
                transition transmit_to_listening
                    source Transmitting
                    target Listening
                    when zWavePort.messagesOut->isEmpty();
            }
            state Sleeping {
                entry;
                transition sleep_to_listen
                    source Sleeping
                    target Listening
                    when wakeTrigger;
            }
            transition initial to Listening;
        }

        variation of kind NodeStateKind;
        enum NodeStateKind { listening; transmitting; sleeping; }
        attribute wakeTrigger : Boolean = false;
    }

    // ===== Central Controller =====

    part def CentralController :> ZWaveNode {
        attribute isMainsPowered = true;
        attribute isRepeater = false;

        part networkKey :> String;
        part routingTable {
            attribute routes : NodeId[0..*];
            attribute hopCounts : RouteHopCount[0..*];
        }

        action def manageNetwork {
            in command : CommandType;
            in targetNode : NodeId;
        }

        action def addDevice {
            in newNodeId : NodeId;
            // Secure inclusion protocol
        }

        action def removeDevice {
            in nodeId : NodeId;
        }

        action def optimizeRoutes {
            // Mesh route healing
        }

        action def encryptMessage {
            in plaintext : ZWaveMessage;
            out ciphertext : ZWaveMessage;
        }

        state machine ControllerStateMachine {
            state Idle;
            state ManagingDevices {
                entry;
                do manageNetwork;
            }
            state OptimizingNetwork {
                entry;
                do optimizeRoutes;
            }
            state ProcessingMessage {
                entry;
                do encryptMessage;
            }
            transition initial to Idle;
            transition idle_to_managing
                source Idle
                target ManagingDevices
                when zWavePort.messagesIn->notEmpty() and zWavePort.messagesIn->first().commandType in {CommandType::ADD_NODE, CommandType::REMOVE_NODE};
            transition managing_to_idle
                source ManagingDevices
                target Idle
                when true;
            transition idle_to_optimizing
                source Idle
                target OptimizingNetwork
                when optimizeTimer;
            transition optimizing_to_idle
                source OptimizingNetwork
                target Idle
                when true;
            transition idle_to_processing
                source Idle
                target ProcessingMessage
                when zWavePort.messagesIn->notEmpty();
            transition processing_to_idle
                source ProcessingMessage
                target Idle
                when true;
            attribute optimizeTimer : Boolean = false;
        }
    }

    // ===== Smart Light Switch =====

    part def SmartLightSwitch :> ZWaveNode {
        attribute isMainsPowered = true;
        attribute isRepeater = true;

        attribute isOn : Boolean = false;
        attribute powerConsumption : Power;
        attribute ratedPower : Power;

        action def toggleSwitch {
            in command : CommandType;
            out newStatus : Boolean;
        }

        action def reportStatus {
            out status : StatusReport;
        }

        action def relayMessage {
            in incoming : ZWaveMessage;
            out outgoing : ZWaveMessage;
        }

        state machine LightSwitchStateMachine {
            state Off {
                entry;
                attribute isOn = false;
                attribute powerConsumption = 0.0 [W];
            }
            state On {
                entry;
                attribute isOn = true;
                attribute powerConsumption = ratedPower;
            }
            transition initial to Off;
            transition off_to_on
                source Off
                target On
                when zWavePort.messagesIn->notEmpty() and zWavePort.messagesIn->first().commandType == CommandType::SET_SWITCH;
            transition on_to_off
                source On
                target Off
                when zWavePort.messagesIn->notEmpty() and zWavePort.messagesIn->first().commandType == CommandType::SET_SWITCH;
        }

        state machine RepeaterStateMachine {
            state RepeaterIdle;
            state Repeating {
                entry;
                do relayMessage;
            }
            transition initial to RepeaterIdle;
            transition idle_to_repeating
                source RepeaterIdle
                target Repeating
                when zWavePort.messagesIn->notEmpty() and zWavePort.messagesIn->first().destinationId != nodeId;
            transition repeating_to_idle
                source Repeating
                target RepeaterIdle
                when true;
        }
    }

    // ===== Smart Thermostat =====

    part def SmartThermostat :> ZWaveNode {
        attribute isMainsPowered = true;
        attribute isRepeater = true;

        attribute currentTemperature : Temperature;
        attribute setpoint : Temperature;
        attribute heatingActive : Boolean = false;
        attribute coolingActive : Boolean = false;

        part temperatureSensor {
            attribute reading : Temperature;
            action def sense {
                out temp : Temperature;
            }
        }

        part hvacInterface {
            port def hvacControlPort {
                out item heatCommand : Boolean;
                out item coolCommand : Boolean;
            }
            port hvacPort : hvacControlPort;
        }

        action def regulateTemperature {
            in current : Temperature;
            in target : Temperature;
            out heat : Boolean;
            out cool : Boolean;
        }

        action def reportTemperature {
            out report : StatusReport;
        }

        state machine ThermostatStateMachine {
            state Monitoring {
                entry;
                do temperatureSensor.sense;
            }
            state Heating {
                entry;
                attribute heatingActive = true;
                attribute coolingActive = false;
            }
            state Cooling {
                entry;
                attribute heatingActive = false;
                attribute coolingActive = true;
            }
            state Idle {
                entry;
                attribute heatingActive = false;
                attribute coolingActive = false;
            }
            transition initial to Monitoring;
            transition monitor_to_heating
                source Monitoring
                target Heating
                when currentTemperature < (setpoint - 0.5 [degC]);
            transition monitor_to_cooling
                source Monitoring
                target Cooling
                when currentTemperature > (setpoint + 0.5 [degC]);
            transition heating_to_idle
                source Heating
                target Idle
                when currentTemperature >= setpoint;
            transition cooling_to_idle
                source Cooling
                target Idle
                when currentTemperature <= setpoint;
            transition idle_to_monitoring
                source Idle
                target Monitoring
                when true;
        }
    }

    // ===== Battery-Powered Motion Sensor =====

    part def MotionSensor :> ZWaveNode {
        attribute isMainsPowered = false;
        attribute isRepeater = false;
        attribute batteryLevel : BatteryLevel = 100.0 [percent];

        attribute motionDetected : Boolean = false;
        attribute wakeInterval : Integer;

        part pirSensor {
            attribute detectionState : Boolean;
            action def detect {
                out motion : Boolean;
            }
        }

        action def sendAlert {
            out alert : AlertMessage;
        }

        action def enterSleep {
            // Reduce power consumption
        }

        action def wakeUp {
            // Periodic or motion-triggered wake
        }

        state machine MotionSensorStateMachine {
            state Awake {
                entry;
                do pirSensor.detect;
            }
            state Sleep {
                entry;
                do enterSleep;
            }
            state Alerting {
                entry;
                do sendAlert;
            }
            transition initial to Awake;
            transition awake_to_sleep
                source Awake
                target Sleep
                when !motionDetected and wakeTimerExpired;
            transition sleep_to_awake
                source Sleep
                target Awake
                when wakeTimerExpired or motionDetected;
            transition awake_to_alerting
                source Awake
                target Alerting
                when motionDetected;
            transition alerting_to_sleep
                source Alerting
                target Sleep
                when true;
            attribute wakeTimerExpired : Boolean = false;
        }
    }

    // ===== Battery-Powered Smart Door Lock =====

    part def SmartDoorLock :> ZWaveNode {
        attribute isMainsPowered = false;
        attribute isRepeater = false;
        attribute batteryLevel : BatteryLevel = 100.0 [percent];

        attribute isLocked : Boolean = true;
        attribute authorizedAccessCode : AccessCode;

        part keypad {
            attribute enteredCode : AccessCode;
            action def receiveInput {
                out code : AccessCode;
            }
        }

        part lockMechanism {
            attribute position : LockPosition;
            action def actuate {
                in target : LockPosition;
            }
        }

        enum LockPosition { locked; unlocked; }

        action def verifyAccessCode {
            in code : AccessCode;
            out authorized : Boolean;
        }

        action def lock {
            in code : AccessCode;
        }

        action def unlock {
            in code : AccessCode;
        }

        action def reportLockState {
            out report : StatusReport;
        }

        state machine DoorLockStateMachine {
            state Locked {
                entry;
                attribute isLocked = true;
            }
            state Unlocked {
                entry;
                attribute isLocked = false;
            }
            state VerifyingCode {
                entry;
                do verifyAccessCode;
            }
            transition initial to Locked;
            transition locked_to_verifying
                source Locked
                target VerifyingCode
                when zWavePort.messagesIn->notEmpty() or keypad.enteredCode->notEmpty();
            transition verifying_to_unlocked
                source VerifyingCode
                target Unlocked
                when accessVerified;
            transition verifying_to_locked
                source VerifyingCode
                target Locked
                when !accessVerified;
            transition unlocked_to_locked
                source Unlocked
                target Locked
                when zWavePort.messagesIn->notEmpty() and zWavePort.messagesIn->first().commandType == CommandType::LOCK;
            attribute accessVerified : Boolean = false;
        }
    }

    // ===== Z-Wave Network Assembly =====

    part def ZWaveNetwork {
        attribute homeId : HomeId;

        part controller : CentralController {
            attribute nodeId = 1;
            attribute homeId = homeId;
        }

        part lightSwitch1 : SmartLightSwitch {
            attribute nodeId = 2;
            attribute homeId = homeId;
            attribute ratedPower = 60.0 [W];
        }

        part lightSwitch2 : SmartLightSwitch {
            attribute nodeId = 3;
            attribute homeId = homeId;
            attribute ratedPower = 75.0 [W];
        }

        part thermostat : SmartThermostat {
            attribute nodeId = 4;
            attribute homeId = homeId;
            attribute setpoint = 21.0 [degC];
        }

        part motionSensor : MotionSensor {
            attribute nodeId = 5;
            attribute homeId = homeId;
            attribute wakeInterval = 300;
        }

        part doorLock : SmartDoorLock {
            attribute nodeId = 6;
            attribute homeId = homeId;
            attribute authorizedAccessCode = "123456";
        }

        // Mesh connections — mains-powered devices act as repeaters
        connection def ZWaveLink {
            end source : ZWavePort;
            end target : ZWavePort;
            item forwardedMessages : ZWaveMessage;
        }

        connection : ZWaveLink connect controller.zWavePort to lightSwitch1.zWavePort;
        connection : ZWaveLink connect controller.zWavePort to lightSwitch2.zWavePort;
        connection : ZWaveLink connect controller.zWavePort to thermostat.zWavePort;
        connection : ZWaveLink connect lightSwitch1.zWavePort to thermostat.zWavePort;
        connection : ZWaveLink connect lightSwitch2.zWavePort to motionSensor.zWavePort;
        connection : ZWaveLink connect thermostat.zWavePort to doorLock.zWavePort;
        connection : ZWaveLink connect lightSwitch1.zWavePort to doorLock.zWavePort;
        connection : ZWaveLink connect lightSwitch1.zWavePort to lightSwitch2.zWavePort;

        // Power connections
        connection def MainsPower {
            end source : PowerPort;
            end target : PowerPort;
            item power : Power;
        }

        connection : MainsPower connect controller.powerPort to lightSwitch1.powerPort;
        connection : MainsPower connect controller.powerPort to lightSwitch2.powerPort;
        connection : MainsPower connect controller.powerPort to thermostat.powerPort;
    }

    // ===== Requirements =====

    requirement def SecureMeshNetwork {
        subject network : ZWaveNetwork;
        requirement {
            /* The system shall operate as a secure mesh network where devices
               communicate directly or relay messages to extend range. */
        }
    }

    requirement def ControllerManagesNetwork {
        subject controller : CentralController;
        requirement {
            /* The central controller shall manage device addition/removal,
               maintain encrypted communication, and optimize message routes. */
        }
    }

    requirement def LightSwitchReporting {
        subject lightSwitch : SmartLightSwitch;
        requirement {
            /* Smart light switches shall control lighting and report on/off
               status and power consumption. */
        }
    }

    requirement def ThermostatControl {
        subject thermostat : SmartThermostat;
        requirement {
            /* The smart thermostat shall monitor current temperature and
               control heating/cooling to maintain the desired setpoint. */
        }
    }

    requirement def MotionSensorLowPower {
        subject sensor : MotionSensor;
        requirement {
            /* The motion sensor shall detect movement, send alerts, and
               operate in low-power sleep mode, waking periodically or on motion. */
        }
    }

    requirement def DoorLockSecureAccess {
        subject lock : SmartDoorLock;
        requirement {
            /* The smart door lock shall support remote lock/unlock via secure
               access code and report its locked/unlocked state. */
        }
    }

    requirement def RepeaterFunctionality {
        subject node : ZWaveNode;
        requirement {
            /* Mains-powered nodes shall act as repeaters to route messages
               for out-of-range devices, creating a self-healing network. */
        }
    }

    requirement def NodeStates {
        subject node : ZWaveNode;
        requirement {
            /* All nodes shall operate in states including listening,
               transmitting, or sleeping to save power. */
        }
    }

    // ===== Requirement Satisfaction =====

    satisfaction secureMeshReq : SecureMeshNetwork {
        subject :> ZWaveNetwork;
        requirement {
            /* Satisfied by mesh connections between all nodes and repeater
               functionality of mains-powered devices. */
        }
    }

    satisfaction controllerReq : ControllerManagesNetwork {
        subject :> CentralController;
        requirement {
            /* Satisfied by addDevice, removeDevice, optimizeRoutes, and
               encryptMessage actions. */
        }
    }

    satisfaction lightSwitchReq : LightSwitchReporting {
        subject :> SmartLightSwitch;
        requirement {
            /* Satisfied by toggleSwitch and reportStatus actions. */
        }
    }

    satisfaction thermostatReq : ThermostatControl {
        subject :> SmartThermostat;
        requirement {
            /* Satisfied by regulateTemperature action and ThermostatStateMachine. */
        }
    }

    satisfaction motionSensorReq : MotionSensorLowPower {
        subject :> MotionSensor;
        requirement {
            /* Satisfied by MotionSensorStateMachine with Sleep and Awake states. */
        }
    }

    satisfaction doorLockReq : DoorLockSecureAccess {
        subject :> SmartDoorLock;
        requirement {
            /* Satisfied by verifyAccessCode, lock, unlock actions and
               DoorLockStateMachine. */
        }
    }

    satisfaction repeaterReq : RepeaterFunctionality {
        subject :> SmartLightSwitch;
        requirement {
            /* Satisfied by isRepeater = true and RepeaterStateMachine. */
        }
    }

    satisfaction nodeStatesReq : NodeStates {
        subject :> ZWaveNode;
        requirement {
            /* Satisfied by NodeStateMachine with Listening, Transmitting,
               and Sleeping states. */
        }
    }

}
