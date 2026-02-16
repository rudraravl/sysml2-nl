package ZWaveHomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def NodeAddress :> Integer;
    attribute def HomeID :> Integer;
    attribute def RSSI :> Real;
    
    enum def NodeType {
        controller;
        slave;
        routing;
    }
    
    enum def CommandClass {
        basic;
        switchBinary;
        switchMultilevel;
        sensorBinary;
        sensorMultilevel;
        meter;
        thermostat;
        doorLock;
        alarm;
        battery;
    }
    
    enum def SecurityMode {
        none;
        s0;
        s2Unauthenticated;
        s2Authenticated;
    }
    
    item def ZWavePacket {
        attribute homeID : HomeID;
        attribute sourceAddress : NodeAddress;
        attribute destinationAddress : NodeAddress;
        attribute commandClass : CommandClass;
        attribute payloadData : Real;
        attribute rssi : RSSI;
        attribute hopCount : Integer;
    }
    
    port def ZWaveRadioPort {
        attribute frequency : FrequencyValue = 908420000.0 [Hz];
        attribute txPower : PowerValue;
        out item txPacket : ZWavePacket;
        in item rxPacket : ZWavePacket;
    }
    
    port def ApplicationPort {
        in item commandRequest : ZWavePacket;
        out item statusResponse : ZWavePacket;
    }
    
    action def TransmitPacket {
        in packet : ZWavePacket;
        in power : PowerValue;
        out success : Boolean;
        
        first start;
        then action encodePacket {
            in data = packet;
        }
        then action modulateSignal;
        then action transmitRF {
            in txPower = power;
        }
        then done;
    }
    
    action def ReceivePacket {
        out packet : ZWavePacket;
        out signalStrength : RSSI;
        
        first start;
        then action detectSignal;
        then action demodulate;
        then action decodePacket {
            out data : ZWavePacket;
        }
        then action validateChecksum;
        then done;
    }
    
    action def RoutePacket {
        in incomingPacket : ZWavePacket;
        in routingTable : NodeAddress[0..232];
        out nextHop : NodeAddress;
        out forwardPacket : ZWavePacket;
        
        first start;
        then action lookupRoute {
            in destination = incomingPacket.destinationAddress;
            in table = routingTable;
            out hop : NodeAddress;
        }
        then action updateHopCount {
            in originalPacket = incomingPacket;
            out modifiedPacket : ZWavePacket;
        }
        then done;
    }
    
    state def ZWaveNodeStateMachine {
        entry; then idle;
        
        state idle;
        state listening;
        state transmitting;
        state routing;
        state sleeping;
        
        transition idle_to_listening
            first idle
            accept at radioPort
            then listening;
        
        transition listening_to_routing
            first listening
            if receivedPacket.destinationAddress != nodeAddress
            then routing;
        
        transition listening_to_transmitting
            first listening
            if receivedPacket.destinationAddress == nodeAddress
            then transmitting;
        
        transition routing_to_idle
            first routing
            then idle;
        
        transition transmitting_to_idle
            first transmitting
            then idle;
        
        transition idle_to_sleeping
            first idle
            if batteryPowered and lowActivity
            then sleeping;
        
        transition sleeping_to_idle
            first sleeping
            accept wakeupSignal
            then idle;
    }
    
    part def ZWaveController {
        attribute nodeAddress : NodeAddress = 1;
        attribute homeID : HomeID;
        attribute nodeType : NodeType = NodeType::controller;
        attribute maxNodes : Integer = 232;
        attribute networkKey : String;
        attribute securityMode : SecurityMode;
        
        port radioPort : ZWaveRadioPort {
            attribute :>> txPower = 0.001 [W];
        }
        
        port appPort : ApplicationPort;
        
        part routingEngine {
            attribute routingTable : NodeAddress[0..232];
            attribute neighborList : NodeAddress[0..*];
            
            action updateRoutes {
                in nodeList : NodeAddress[0..*];
                out updatedTable : NodeAddress[0..232];
            }
        }
        
        part securityManager {
            attribute :>> securityMode : SecurityMode;
            attribute encryptionKeys : String[0..*];
            
            action encryptPayload {
                in plaintext : Real;
                out ciphertext : Real;
            }
            
            action decryptPayload {
                in ciphertext : Real;
                out plaintext : Real;
            }
        }
        
        part networkManager {
            action includeNode {
                in newNodeAddress : NodeAddress;
                out success : Boolean;
            }
            
            action excludeNode {
                in targetNodeAddress : NodeAddress;
                out success : Boolean;
            }
            
            action healNetwork {
                out optimizedRoutes : NodeAddress[0..232];
            }
        }
        
        state machine controllerBehavior : ZWaveNodeStateMachine;
    }
    
    part def ZWaveEndDevice {
        attribute nodeAddress : NodeAddress;
        attribute nodeType : NodeType = NodeType::slave;
        attribute deviceClass : CommandClass;
        attribute batteryPowered : Boolean;
        attribute batteryLevel : Real;
        attribute status : String;
        
        port radioPort : ZWaveRadioPort {
            attribute :>> txPower = 0.0005 [W];
        }
        
        port devicePort : ApplicationPort;
        
        state machine deviceBehavior : ZWaveNodeStateMachine;
    }
    
    part def SmartLightSwitch :> ZWaveEndDevice {
        attribute :>> deviceClass = CommandClass::switchBinary;
        attribute :>> batteryPowered = false;
        attribute switchState : Boolean = false;
        attribute powerConsumption : PowerValue;
        
        action toggleSwitch {
            in command : Boolean;
            
            first start;
            then action updateState {
                in newState = command;
            }
            then action reportStatus {
                out statusPacket : ZWavePacket;
            }
            then done;
        }
    }
    
    part def MotionSensor :> ZWaveEndDevice {
        attribute :>> deviceClass = CommandClass::sensorBinary;
        attribute :>> batteryPowered = true;
        attribute :>> batteryLevel = 100.0;
        attribute motionDetected : Boolean = false;
        attribute sensitivity : Real;
        attribute wakeupInterval : TimeValue = 240.0 [s];
        
        action detectMotion {
            out detected : Boolean;
            out alertPacket : ZWavePacket;
            
            first start;
            then action sampleSensor {
                out reading : Boolean;
            }
            then decide;
                if sampleSensor.reading then sendAlert;
            
            action sendAlert {
                out packet : ZWavePacket;
            }
            then done;
        }
    }
    
    part def SmartThermostat :> ZWaveEndDevice {
        attribute :>> deviceClass = CommandClass::thermostat;
        attribute :>> batteryPowered = false;
        attribute currentTemperature : TemperatureValue;
        attribute targetTemperature : TemperatureValue;
        attribute mode : String;
        attribute fanSpeed : Real;
        
        action regulateTemperature {
            in setpoint : TemperatureValue;
            
            first start;
            then merge controlLoop;
            
            action measureTemp {
                out temp : TemperatureValue;
            }
            then decide;
                if measureTemp.temp < setpoint then activateHeating;
                if measureTemp.temp > setpoint then activateCooling;
                if measureTemp.temp == setpoint then maintainTemp;
            
            action activateHeating;
            then controlLoop;
            
            action activateCooling;
            then controlLoop;
            
            action maintainTemp;
            then controlLoop;
        }
    }
    
    part def DoorLockActuator :> ZWaveEndDevice {
        attribute :>> deviceClass = CommandClass::doorLock;
        attribute :>> batteryPowered = true;
        attribute :>> batteryLevel = 95.0;
        attribute lockState : Boolean = true;
        attribute accessCode : String;
        attribute tamperDetected : Boolean = false;
        
        action operateLock {
            in lockCommand : Boolean;
            in code : String;
            out success : Boolean;
            
            first start;
            then action validateCode {
                in inputCode = code;
                out valid : Boolean;
            }
            then decide;
                if validateCode.valid then changeLockState;
                if not validateCode.valid then rejectCommand;
            
            action changeLockState {
                in newState = lockCommand;
            }
            then done;
            
            action rejectCommand;
            then done;
        }
    }
    
    connection def ZWaveMeshLink {
        end port sourcePort : ZWaveRadioPort;
        end port targetPort : ZWaveRadioPort;
        
        attribute linkQuality : RSSI;
        attribute hopDistance : Integer;
        attribute bandwidth : Real;
    }
    
    action def ManageZWaveNetwork {
        first start;
        then merge networkOperation;
        
        action monitorNetwork {
            out networkStatus : String;
            out activeNodes : NodeAddress[0..*];
        }
        then decide;
            if monitorNetwork.networkStatus == "command_pending" then processCommand;
            if monitorNetwork.networkStatus == "device_report" then handleReport;
            if monitorNetwork.networkStatus == "route_update" then optimizeRoutes;
        
        action processCommand {
            in userCommand : ZWavePacket;
            out deviceCommand : ZWavePacket;
        }
        then action routeCommand : RoutePacket {
            in incomingPacket = processCommand.deviceCommand;
        }
        then action transmitCommand : TransmitPacket {
            in packet = routeCommand.forwardPacket;
        }
        then networkOperation;
        
        action handleReport {
            in deviceReport : ZWavePacket;
            out processedData : Real;
        }
        then networkOperation;
        
        action optimizeRoutes {
            out updatedRoutes : NodeAddress[0..232];
        }
        then networkOperation;
    }
    
    part zWaveNetwork : ZWaveHomeNetwork {
        attribute :>> homeID : HomeID = 2882343476;
        attribute networkRange : LengthValue = 100.0 [m];
        attribute operatingFrequency : FrequencyValue = 908420000.0 [Hz];
        
        part primaryController : ZWaveController {
            attribute :>> nodeAddress = 1;
            attribute :>> homeID = zWaveNetwork.homeID;
            attribute :>> securityMode = SecurityMode::s2Authenticated;
            attribute :>> networkKey = "SecureKey2024";
        }
        
        part livingRoomLight : SmartLightSwitch {
            attribute :>> nodeAddress = 2;
            attribute :>> switchState = false;
            attribute :>> powerConsumption = 60.0 [W];
        }
        
        part bedroomLight : SmartLightSwitch {
            attribute :>> nodeAddress = 3;
            attribute :>> switchState = false;
            attribute :>> powerConsumption = 40.0 [W];
        }
        
        part hallwayMotionSensor : MotionSensor {
            attribute :>> nodeAddress = 4;
            attribute :>> batteryLevel = 100.0;
            attribute :>> sensitivity = 0.8;
            attribute :>> wakeupInterval = 240.0 [s];
        }
        
        part mainThermostat : SmartThermostat {
            attribute :>> nodeAddress = 5;
            attribute :>> currentTemperature = 295.15 [K];
            attribute :>> targetTemperature = 294.15 [K];
            attribute :>> mode = "auto";
        }
        
        part frontDoorLock : DoorLockActuator {
            attribute :>> nodeAddress = 6;
            attribute :>> lockState = true;
            attribute :>> batteryLevel = 95.0;
            attribute :>> accessCode = "1234";
        }
        
        connection link1 : ZWaveMeshLink
            connect primaryController.radioPort to livingRoomLight.radioPort {
                attribute :>> linkQuality = -45.0;
                attribute :>> hopDistance = 1;
            }
        
        connection link2 : ZWaveMeshLink
            connect primaryController.radioPort to bedroomLight.radioPort {
                attribute :>> linkQuality = -50.0;
                attribute :>> hopDistance = 1;
            }
        
        connection link3 : ZWaveMeshLink
            connect primaryController.radioPort to hallwayMotionSensor.radioPort {
                attribute :>> linkQuality = -55.0;
                attribute :>> hopDistance = 1;
            }
        
        connection link4 : ZWaveMeshLink
            connect primaryController.radioPort to mainThermostat.radioPort {
                attribute :>> linkQuality = -48.0;
                attribute :>> hopDistance = 1;
            }
        
        connection link5 : ZWaveMeshLink
            connect primaryController.radioPort to frontDoorLock.radioPort {
                attribute :>> linkQuality = -52.0;
                attribute :>> hopDistance = 1;
            }
        
        connection link6 : ZWaveMeshLink
            connect livingRoomLight.radioPort to bedroomLight.radioPort {
                attribute :>> linkQuality = -60.0;
                attribute :>> hopDistance = 1;
            }
        
        perform action networkControl : ManageZWaveNetwork;
    }
    
    requirement <'SYS-REQ-001'> primaryFunction {
        doc /* The Z-Wave home automation system shall provide reliable wireless
             * mesh networking for monitoring and control of smart home devices,
             * enabling automated management of lighting, climate control, security,
             * and sensor devices through a centralized controller using the Z-Wave
             * protocol operating at 908.42 MHz with support for up to 232 nodes
             * and S2 security framework for encrypted communication.
             */
        subject system :> zWaveNetwork;
        
        assume constraint {
            system.operatingFrequency == 908420000.0 [Hz] and
            system.primaryController.maxNodes == 232
        }
    }
    
    requirement <'SYS-REQ-002'> networkReliability {
        doc /* The network shall maintain mesh routing capability with automatic
             * route optimization and self-healing to ensure reliable communication
             * even when individual nodes fail or signal paths are obstructed.
             */
        subject controller :> zWaveNetwork.primaryController;
    }
    
    requirement <'SYS-REQ-003'> securityRequirement {
        doc /* All device communications shall support S2 security framework
             * with authenticated encryption to prevent unauthorized access
             * and ensure data integrity.
             */
        subject controller :> zWaveNetwork.primaryController;
        
        require constraint {
            controller.securityMode == SecurityMode::s2Authenticated
        }
    }
    
    requirement <'SYS-REQ-004'> batteryEfficiency {
        doc /* Battery-powered devices shall implement sleep mode with
             * configurable wakeup intervals to maximize battery life while
             * maintaining responsive operation.
             */
        subject sensor :> zWaveNetwork.hallwayMotionSensor;
        
        require constraint {
            sensor.wakeupInterval >= 60.0 [s]
        }
    }
    
    requirement <'SYS-REQ-005'> networkCapacity {
        doc /* The controller shall support simultaneous management of
             * up to 232 Z-Wave devices with efficient routing and
             * minimal latency for time-critical operations.
             */
        subject controller :> zWaveNetwork.primaryController;
        
        require constraint {
            controller.maxNodes == 232
        }
    }
    
    satisfy primaryFunction by zWaveNetwork;
    satisfy networkReliability by zWaveNetwork.primaryController.routingEngine;
    satisfy securityRequirement by zWaveNetwork.primaryController.securityManager;
    satisfy batteryEfficiency by zWaveNetwork.hallwayMotionSensor;
    satisfy networkCapacity by zWaveNetwork.primaryController;
}
