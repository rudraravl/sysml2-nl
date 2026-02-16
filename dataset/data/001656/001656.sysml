package GreenPeakWirelessSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NetworkAddress :> Integer;
    
    attribute def SignalStrength {
        attribute value : Real;
        attribute unit : String = "dBm";
    }
    
    attribute def PacketID :> Integer;
    
    item def WirelessFrame {
        attribute sourceAddr : NetworkAddress;
        attribute destAddr : NetworkAddress;
        attribute packetId : PacketID;
        attribute payload : String;
        attribute timestamp : TimeValue;
        attribute rssi : SignalStrength;
    }
    
    item def SensorData {
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
        attribute batteryLevel : Real;
    }
    
    port def RFPort {
        in item rxFrame : WirelessFrame;
        out item txFrame : WirelessFrame;
        attribute frequency : FrequencyValue;
        attribute txPower : PowerValue;
    }
    
    port def SensorPort {
        out item reading : SensorData;
    }
    
    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    part def RFTransceiver {
        doc /* GreenPeak RF transceiver implementing IEEE 802.15.4 protocol for low-power wireless communication */
        
        attribute operatingFrequency : FrequencyValue = 2400.0e6[SI::Hz];
        attribute transmitPower : PowerValue = 0.010[SI::W];
        attribute receiveSensitivity : SignalStrength;
        attribute dataRate : Real = 250.0;
        
        port rfInterface : RFPort;
        port power : PowerPort;
    }
    
    part def MicroController {
        doc /* Embedded processor managing network protocol stack and application logic */
        
        attribute nodeAddress : NetworkAddress;
        attribute processingPower : FrequencyValue = 32.0e6[SI::Hz];
        
        port power : PowerPort;
    }
    
    part def EnvironmentalSensor {
        doc /* Multi-sensor module for environmental monitoring */
        
        attribute sampleRate : FrequencyValue = 0.1[SI::Hz];
        
        port sensorOutput : SensorPort;
        port power : PowerPort;
    }
    
    part def BatteryPack {
        doc /* Lithium battery providing system power */
        
        attribute capacity : Real = 2400.0;
        attribute nominalVoltage : ElectricPotentialValue = 3.0[SI::V];
        attribute stateOfCharge : Real = 100.0;
        
        port output : PowerPort;
    }
    
    action def AcquireSensorData {
        in sampleInterval : TimeValue;
        out data : SensorData;
    }
    
    action def EncodeFrame {
        in sensorData : SensorData;
        in sourceAddress : NetworkAddress;
        in destAddress : NetworkAddress;
        out frame : WirelessFrame;
    }
    
    action def TransmitFrame {
        in frame : WirelessFrame;
        in txPower : PowerValue;
        out transmitComplete : Boolean;
    }
    
    action def ReceiveFrame {
        in signalStrength : SignalStrength;
        out frame : WirelessFrame;
        out receiveComplete : Boolean;
    }
    
    action def ProcessReceivedData {
        in frame : WirelessFrame;
        out processedData : SensorData;
    }
    
    state def NodeOperatingState {
        entry; then sleep;
        
        state sleep {
            doc /* Ultra-low power sleep mode consuming < 1 uA */
        }
        
        state wakeup {
            doc /* Transition state for system initialization */
        }
        
        state sensing {
            doc /* Active sensor data acquisition */
        }
        
        state transmit {
            doc /* RF transmission active */
        }
        
        state receive {
            doc /* RF receiver active listening for incoming frames */
        }
        
        transition sleep_to_wakeup
            first sleep
            accept wakeupTimer
            then wakeup;
        
        transition wakeup_to_sensing
            first wakeup
            accept systemReady
            then sensing;
        
        transition sensing_to_transmit
            first sensing
            accept dataReady
            then transmit;
        
        transition transmit_to_receive
            first transmit
            accept txComplete
            then receive;
        
        transition receive_to_sleep
            first receive
            accept rxTimeout
            then sleep;
        
        transition receive_to_transmit
            first receive
            accept frameReceived
            then transmit;
    }
    
    action def WirelessNodeOperation {
        doc /* Primary operational cycle for GreenPeak wireless sensor node */
        
        first start;
        then merge operationLoop;
        
        action senseAndTransmit {
            first action acquire : AcquireSensorData {
                in sampleInterval = 10.0[SI::s];
                out data;
            }
            then action encode : EncodeFrame {
                in sensorData = acquire.data;
                in sourceAddress = 1;
                in destAddress = 0;
                out frame;
            }
            then action transmit : TransmitFrame {
                in frame = encode.frame;
                in txPower = 0.010[SI::W];
                out transmitComplete;
            }
        }
        then operationLoop;
        
        action listenAndForward {
            action listen : ReceiveFrame {
                in signalStrength;
                out frame;
                out receiveComplete;
            }
            then decide;
                if listen.receiveComplete then processAndRelay;
                if not listen.receiveComplete then done;
            
            action processAndRelay {
                action process : ProcessReceivedData {
                    in frame = listen.frame;
                    out processedData;
                }
                then action relay : TransmitFrame {
                    in frame = listen.frame;
                    in txPower = 0.010[SI::W];
                    out transmitComplete;
                }
            }
        }
        then operationLoop;
    }
    
    part def GreenPeakWirelessNode {
        doc /* 
            GreenPeak Technologies wireless sensor node implementing ultra-low power
            IEEE 802.15.4 communication for IoT and smart home applications.
            Integrates RF transceiver, microcontroller, environmental sensors, and
            battery management for autonomous operation.
        */
        
        attribute nodeId : NetworkAddress;
        attribute networkChannel : Integer = 15;
        attribute sleepDuration : TimeValue = 60.0[SI::s];
        
        part transceiver : RFTransceiver {
            attribute :>> operatingFrequency = 2405.0e6[SI::Hz];
            attribute :>> transmitPower = 0.008[SI::W];
        }
        
        part mcu : MicroController {
            attribute :>> nodeAddress = nodeId;
        }
        
        part sensor : EnvironmentalSensor {
            attribute :>> sampleRate = 0.1[SI::Hz];
        }
        
        part battery : BatteryPack {
            attribute :>> capacity = 2400.0;
            attribute :>> nominalVoltage = 3.0[SI::V];
        }
        
        connect battery.output to transceiver.power;
        connect battery.output to mcu.power;
        connect battery.output to sensor.power;
        
        exhibit state nodeState : NodeOperatingState;
        perform action operation : WirelessNodeOperation;
    }
    
    part def GreenPeakMeshNetwork {
        doc /*
            Multi-hop wireless mesh network based on GreenPeak Technologies
            enabling distributed sensor monitoring and control across
            residential and commercial environments.
        */
        
        attribute networkId : Integer = 1;
        attribute maxNodes : Integer = 255;
        attribute coverageRadius : LengthValue = 100.0[SI::m];
        
        part coordinator : GreenPeakWirelessNode {
            attribute :>> nodeId = 0;
        }
        
        part router1 : GreenPeakWirelessNode {
            attribute :>> nodeId = 10;
        }
        
        part router2 : GreenPeakWirelessNode {
            attribute :>> nodeId = 11;
        }
        
        part endDevice1 : GreenPeakWirelessNode {
            attribute :>> nodeId = 20;
        }
        
        part endDevice2 : GreenPeakWirelessNode {
            attribute :>> nodeId = 21;
        }
        
        part endDevice3 : GreenPeakWirelessNode {
            attribute :>> nodeId = 22;
        }
        
        perform action networkOperation {
            first start;
            then action initializeNetwork {
                doc /* Coordinator establishes network and assigns addresses */
            }
            then merge dataCollection;
            
            action collectAndRoute {
                action endDeviceTransmit references endDevice1.operation;
                flow endDeviceTransmit to routerRelay;
                
                action routerRelay references router1.operation;
                flow routerRelay to coordinatorReceive;
                
                action coordinatorReceive references coordinator.operation;
            }
            then dataCollection;
        }
    }
    
    requirement def PowerConsumptionRequirement {
        doc /* 
            Wireless node shall operate with average power consumption
            below 50 uW to achieve multi-year battery life.
        */
        
        subject node : GreenPeakWirelessNode;
        
        require constraint {
            node.battery.stateOfCharge > 0.0
        }
    }
    
    requirement def CommunicationRangeRequirement {
        doc /*
            Wireless node shall achieve minimum 30 meter indoor range
            at specified transmit power.
        */
        
        subject node : GreenPeakWirelessNode;
        
        require constraint {
            node.transceiver.transmitPower >= 0.005[SI::W]
        }
    }
    
    requirement def DataReliabilityRequirement {
        doc /*
            Network shall maintain packet delivery ratio above 95%
            under normal operating conditions.
        */
        
        subject network : GreenPeakMeshNetwork;
        
        require constraint {
            network.maxNodes >= 3
        }
    }
    
    requirement def NetworkScalabilityRequirement {
        doc /*
            Network shall support minimum 50 nodes with automatic
            routing and self-healing capability.
        */
        
        subject network : GreenPeakMeshNetwork;
        
        require constraint {
            network.maxNodes >= 50
        }
    }
    
    requirement <'GP-001'> greenPeakSystemRequirements {
        doc /*
            Top-level requirements for GreenPeak Technologies wireless
            mesh networking system for smart home and IoT applications.
        */
        
        require powerReq : PowerConsumptionRequirement;
        require rangeReq : CommunicationRangeRequirement;
        require reliabilityReq : DataReliabilityRequirement;
        require scalabilityReq : NetworkScalabilityRequirement;
    }
    
    part greenPeakSystem : GreenPeakMeshNetwork {
        doc /*
            GreenPeak Technologies wireless mesh networking system providing
            ultra-low power, reliable, and scalable communication infrastructure
            for smart home automation, environmental monitoring, and IoT applications.
            
            Primary Function: Enable distributed wireless sensor networks with
            multi-hop mesh topology, automatic network formation, self-healing
            routing, and years of battery-powered operation for residential and
            commercial building automation.
        */
        
        attribute :>> networkId = 100;
        attribute :>> maxNodes = 100;
        attribute :>> coverageRadius = 150.0[SI::m];
        
        satisfy greenPeakSystemRequirements;
    }
}
