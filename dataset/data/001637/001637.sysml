package 'Zigbee Wireless Mesh Network System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NetworkAddress :> String;
    attribute def DeviceIdentifier :> String;
    attribute def MessagePayload :> String;
    attribute def SequenceNumber :> Integer;
    attribute def ChannelNumber :> Integer;
    attribute def PANIdentifier :> Integer;
    
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def PowerValue :> ISQ::PowerValue;
    
    attribute def DataRateValue :> Real;
    
    enum def DeviceRole {
        enum coordinator;
        enum router;
        enum endDevice;
    }
    
    enum def NetworkState {
        enum forming;
        enum operational;
        enum degraded;
        enum failed;
    }
    
    item def ZigbeeFrame {
        attribute sourceAddress : NetworkAddress;
        attribute destinationAddress : NetworkAddress;
        attribute payload : MessagePayload;
        attribute sequence : SequenceNumber;
        attribute hopCount : Integer;
    }
    
    item def RoutingTableEntry {
        attribute destination : NetworkAddress;
        attribute nextHop : NetworkAddress;
        attribute cost : Integer;
    }
    
    port def ZigbeeRadioInterface {
        attribute operatingFrequency : FrequencyValue;
        attribute transmitPower : PowerValue;
        attribute channel : ChannelNumber;
        attribute dataRate : DataRateValue;
        in receivedFrame : ZigbeeFrame;
        out transmittedFrame : ZigbeeFrame;
    }
    
    port def ApplicationInterface {
        in applicationData : MessagePayload;
        out receivedData : MessagePayload;
    }
    
    part def ZigbeeCoordinator {
        attribute deviceId : DeviceIdentifier;
        attribute networkAddress : NetworkAddress;
        attribute role : DeviceRole = DeviceRole::coordinator;
        attribute panId : PANIdentifier;
        attribute connectedDevices : NetworkAddress[*];
        
        port radioPort : ZigbeeRadioInterface {
            attribute :>> operatingFrequency : FrequencyValue = 2400.0;
            attribute :>> transmitPower : PowerValue = 0.001;
            attribute :>> channel = 11;
            attribute :>> dataRate = 250.0;
        }
        
        port appPort : ApplicationInterface;
        
        action initializeHardware;
        action selectChannel;
        action assignPANId;
        action broadcastBeacon;
        action enableRouting;
        action authorizeDevice;
        action forwardFrame;
        action updateRoutingTable;
        action logError;
        action validateConfiguration;
        action confirmNetworkEstablished;
        action resetNetwork;
        
        perform action manageNetwork;
    }
    
    part def ZigbeeRouter {
        attribute deviceId : DeviceIdentifier;
        attribute networkAddress : NetworkAddress;
        attribute role : DeviceRole = DeviceRole::router;
        attribute parentAddress : NetworkAddress;
        attribute routingTable : RoutingTableEntry[*];
        attribute childDevices : NetworkAddress[*];
        
        port radioPort : ZigbeeRadioInterface {
            attribute :>> operatingFrequency : FrequencyValue = 2400.0;
            attribute :>> transmitPower : PowerValue = 0.001;
            attribute :>> channel = 11;
            attribute :>> dataRate = 250.0;
        }
        
        port appPort : ApplicationInterface;
        
        action scanForNetworks;
        action sendJoinRequest;
        action lookupRoute;
        action transmitToNextHop;
        action registerChild;
        action attemptRejoin;
        action selectParent;
        action confirmJoin;
        action findNewParent;
        
        perform action routeMessages;
    }
    
    part def ZigbeeEndDevice {
        attribute deviceId : DeviceIdentifier;
        attribute networkAddress : NetworkAddress;
        attribute role : DeviceRole = DeviceRole::endDevice;
        attribute parentAddress : NetworkAddress;
        attribute sleepEnabled : Boolean;
        attribute wakeInterval : ISQ::TimeValue;
        
        port radioPort : ZigbeeRadioInterface {
            attribute :>> operatingFrequency : FrequencyValue = 2400.0;
            attribute :>> transmitPower : PowerValue = 0.0005;
            attribute :>> channel = 11;
            attribute :>> dataRate = 250.0;
        }
        
        port appPort : ApplicationInterface;
        
        action discoverNetworks;
        action sendAssociationRequest;
        action transmitToParent;
        action pollParent;
        action processReceivedData;
        action enterLowPowerMode;
        action wakeRadio;
        action notifyApplication;
        action selectNetwork;
        action confirmAssociation;
        action resetDevice;
        
        perform action communicateData;
    }
    
    action def InitializeNetwork {
        in panId : PANIdentifier;
        in channel : ChannelNumber;
        out networkReady : Boolean;
        out assignedPAN : PANIdentifier;
    }
    
    action def JoinNetwork {
        in deviceAddr : NetworkAddress;
        in targetPAN : PANIdentifier;
        in parentAddr : NetworkAddress;
        out joinSuccess : Boolean;
        out assignedAddress : NetworkAddress;
    }
    
    action def RouteFrame {
        in incomingFrame : ZigbeeFrame;
        in routingTable : RoutingTableEntry[*];
        out nextHopAddress : NetworkAddress;
        out routingSuccess : Boolean;
    }
    
    action def TransmitMessage {
        in messageData : MessagePayload;
        in destinationAddr : NetworkAddress;
        in sourceAddr : NetworkAddress;
        out transmitSuccess : Boolean;
    }
    
    action def ReceiveMessage {
        out messageData : MessagePayload;
        out sourceAddr : NetworkAddress;
        out receiveSuccess : Boolean;
    }
    
    action def UpdateRoutingTable {
        in newEntry : RoutingTableEntry;
        in currentTable : RoutingTableEntry[*];
        out updatedTable : RoutingTableEntry[*];
    }
    
    action def ManageNetworkOperation {
        first start;
        then action init : InitializeNetwork {
            in panId = 6699;
            in channel = 11;
            out networkReady;
            out assignedPAN;
        }
        then decide;
            if init.networkReady then operateNetwork;
            if !init.networkReady then retryInit;
        action retryInit {
            then merge start;
        }
        action operateNetwork {
            first merge continueOperation;
            then action monitorDevices {
                doc /* Monitor connected devices and network health */
            }
            then action maintainRoutes {
                doc /* Update and optimize routing tables */
            }
            then action processMessages {
                doc /* Handle incoming and outgoing messages */
            }
            then continueOperation;
        }
        then done;
    }
    
    action def RouteMessagesOperation {
        first start;
        then action join : JoinNetwork {
            in deviceAddr;
            in targetPAN;
            in parentAddr;
            out joinSuccess;
            out assignedAddress;
        }
        then decide;
            if join.joinSuccess then routingLoop;
            if !join.joinSuccess then done;
        action routingLoop {
            first merge continueRouting;
            then action receive : ReceiveMessage {
                out messageData;
                out sourceAddr;
                out receiveSuccess;
            }
            then decide;
                if receive.receiveSuccess then processFrame;
                if !receive.receiveSuccess then continueRouting;
            action processFrame {
                action determineRoute : RouteFrame {
                    in incomingFrame;
                    in routingTable;
                    out nextHopAddress;
                    out routingSuccess;
                }
                then decide;
                    if determineRoute.routingSuccess then forwardMessage;
                    if !determineRoute.routingSuccess then dropFrame;
                action forwardMessage : TransmitMessage {
                    in messageData = receive.messageData;
                    in destinationAddr = determineRoute.nextHopAddress;
                    in sourceAddr;
                    out transmitSuccess;
                }
                then continueRouting;
                action dropFrame {
                    then continueRouting;
                }
            }
        }
        then done;
    }
    
    action def CommunicateDataOperation {
        first start;
        then action associate : JoinNetwork {
            in deviceAddr;
            in targetPAN;
            in parentAddr;
            out joinSuccess;
            out assignedAddress;
        }
        then decide;
            if associate.joinSuccess then dataLoop;
            if !associate.joinSuccess then done;
        action dataLoop {
            first merge continueData;
            then decide;
                if hasDataToSend then sendData;
                if shouldPoll then pollData;
                if shouldSleep then enterSleep;
            action sendData : TransmitMessage {
                in messageData;
                in destinationAddr;
                in sourceAddr;
                out transmitSuccess;
            }
            then continueData;
            action pollData : ReceiveMessage {
                out messageData;
                out sourceAddr;
                out receiveSuccess;
            }
            then action processReceived {
                doc /* Process received data */
            }
            then continueData;
            action enterSleep {
                doc /* Enter low power sleep mode */
                then action wakeUp {
                    doc /* Wake from sleep after interval */
                }
                then continueData;
            }
        }
        then done;
    }
    
    part zigbeeNetwork {
        part coord : ZigbeeCoordinator {
            attribute :>> deviceId = "COORD_001";
            attribute :>> networkAddress = "0x0000";
            attribute :>> panId = 6699;
            
            perform action networkMgmt : ManageNetworkOperation;
        }
        
        part router1 : ZigbeeRouter {
            attribute :>> deviceId = "RTR_001";
            attribute :>> networkAddress = "0x0001";
            attribute :>> parentAddress = "0x0000";
            
            perform action routing1 : RouteMessagesOperation;
        }
        
        part router2 : ZigbeeRouter {
            attribute :>> deviceId = "RTR_002";
            attribute :>> networkAddress = "0x0002";
            attribute :>> parentAddress = "0x0000";
            
            perform action routing2 : RouteMessagesOperation;
        }
        
        part router3 : ZigbeeRouter {
            attribute :>> deviceId = "RTR_003";
            attribute :>> networkAddress = "0x0003";
            attribute :>> parentAddress = "0x0001";
            
            perform action routing3 : RouteMessagesOperation;
        }
        
        part endDevice1 : ZigbeeEndDevice {
            attribute :>> deviceId = "END_001";
            attribute :>> networkAddress = "0x0010";
            attribute :>> parentAddress = "0x0001";
            attribute :>> sleepEnabled = true;
            
            perform action comm1 : CommunicateDataOperation;
        }
        
        part endDevice2 : ZigbeeEndDevice {
            attribute :>> deviceId = "END_002";
            attribute :>> networkAddress = "0x0011";
            attribute :>> parentAddress = "0x0002";
            attribute :>> sleepEnabled = true;
            
            perform action comm2 : CommunicateDataOperation;
        }
        
        part endDevice3 : ZigbeeEndDevice {
            attribute :>> deviceId = "END_003";
            attribute :>> networkAddress = "0x0012";
            attribute :>> parentAddress = "0x0003";
            attribute :>> sleepEnabled = false;
            
            perform action comm3 : CommunicateDataOperation;
        }
        
        connection def WirelessMeshLink {
            end source : ZigbeeRadioInterface;
            end target : ZigbeeRadioInterface;
        }
        
        connection coordToRouter1 : WirelessMeshLink
            connect coord.radioPort to router1.radioPort;
        
        connection coordToRouter2 : WirelessMeshLink
            connect coord.radioPort to router2.radioPort;
        
        connection router1ToRouter3 : WirelessMeshLink
            connect router1.radioPort to router3.radioPort;
        
        connection router1ToEnd1 : WirelessMeshLink
            connect router1.radioPort to endDevice1.radioPort;
        
        connection router2ToEnd2 : WirelessMeshLink
            connect router2.radioPort to endDevice2.radioPort;
        
        connection router3ToEnd3 : WirelessMeshLink
            connect router3.radioPort to endDevice3.radioPort;
        
        connection router1ToRouter2 : WirelessMeshLink
            connect router1.radioPort to router2.radioPort;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The Zigbee wireless mesh network system shall provide reliable, 
               low-power, low-data-rate wireless communication between distributed 
               devices using self-organizing mesh topology with automatic routing 
               and network healing capabilities. */
        
        subject zigbeeNetwork;
    }
    
    requirement def MeshTopologyRequirement {
        doc /* The system shall support mesh network topology allowing multiple 
               routing paths between devices for improved reliability and coverage. */
        
        require constraint {
            doc /* Network shall support at least 65,535 addressable devices */
        }
        
        require constraint {
            doc /* Routers shall maintain routing tables with multiple path options */
        }
    }
    
    requirement def PowerEfficiencyRequirement {
        doc /* The system shall minimize power consumption to enable battery-operated 
               devices with multi-year operational lifetime. */
        
        require constraint {
            doc /* End devices shall support sleep mode with current less than 3 microamperes */
        }
        
        require constraint {
            doc /* Transmit power shall be adjustable from 0.5mW to 100mW */
        }
        
        require constraint {
            doc /* End devices shall wake periodically to poll for messages */
        }
    }
    
    requirement def DataRateRequirement {
        doc /* The system shall provide sufficient data rate for sensor and 
               control applications while maintaining low power consumption. */
        
        require constraint {
            doc /* Data rate shall be 250 kbps at 2.4 GHz frequency band */
        }
    }
    
    requirement def ReliabilityRequirement {
        doc /* The system shall provide reliable message delivery through 
               acknowledgments, retries, and mesh routing. */
        
        require constraint {
            doc /* Message delivery success rate shall exceed 95 percent under normal conditions */
        }
        
        require constraint {
            doc /* Network shall automatically heal when devices fail or move */
        }
        
        require constraint {
            doc /* Routers shall discover and update routes dynamically */
        }
    }
    
    requirement def InteroperabilityRequirement {
        doc /* The system shall comply with IEEE 802.15.4 and Zigbee Alliance 
               specifications to ensure interoperability between vendors. */
        
        require constraint {
            doc /* Physical layer shall comply with IEEE 802.15.4 */
        }
        
        require constraint {
            doc /* Network and application layers shall comply with Zigbee specification */
        }
        
        require constraint {
            doc /* Operating frequency shall be 2.4 GHz ISM band channels 11 through 26 */
        }
    }
    
    requirement zigbeeSystemRequirements {
        doc /* Top-level requirements for Zigbee wireless mesh network system 
               defining its primary function and key operational characteristics. */
        
        require primaryFunction : PrimaryFunctionRequirement;
        require meshTopology : MeshTopologyRequirement;
        require powerEfficiency : PowerEfficiencyRequirement;
        require dataRate : DataRateRequirement;
        require reliability : ReliabilityRequirement;
        require interoperability : InteroperabilityRequirement;
        
        satisfy primaryFunction by zigbeeNetwork;
    }
}
