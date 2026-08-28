package ZigbeeMeshNetwork {
    import ScalarValues::*;

    doc /* SysML v2 model of a Zigbee wireless mesh network system for reliable, low-power, low-data-rate communication. */;

    // ===== Quantity and Unit Definitions =====

    quantity def Frequency;
    unit GHz of Frequency;

    quantity def DataRate;
    unit kbps of DataRate;

    quantity def Power;
    unit mW of Power;

    quantity def BatteryLevel;
    unit percent of BatteryLevel;

    quantity def SignalStrength;
    unit dBm of SignalStrength;

    quantity def Duration;
    unit ms of Duration;
    unit s of Duration = 1000 * ms;

    quantity def DataSize;
    unit kB of DataSize;

    // ===== Attribute (Value Type) Definitions =====

    attribute def FrequencyValue :> Real { :>> unit = GHz; }
    attribute def DataRateValue :> Real { :>> unit = kbps; }
    attribute def PowerValue :> Real { :>> unit = mW; }
    attribute def BatteryLevelValue :> Real { :>> unit = percent; }
    attribute def RSSIValue :> Real { :>> unit = dBm; }
    attribute def TimeValue :> Real { :>> unit = ms; }
    attribute def MemoryValue :> Real { :>> unit = kB; }

    attribute def NetworkId :> Natural;
    attribute def PanId :> Natural;
    attribute def ShortAddress :> Natural;
    attribute def ExtendedAddress :> String;
    attribute def ChannelNumber :> Natural;
    attribute def NodeId :> String;
    attribute def PayloadData :> String;
    attribute def DeviceType :> String;

    // ===== Item Definitions =====

    item def DataPacket {
        attribute sourceAddress : ShortAddress;
        attribute destinationAddress : ShortAddress;
        attribute sourceExtAddress : ExtendedAddress;
        attribute destinationExtAddress : ExtendedAddress;
        attribute panId : PanId;
        attribute payload : PayloadData;
        attribute sequenceNumber : Natural;
        attribute rssi : RSSIValue;
        attribute timestamp : TimeValue;
        attribute hopCount : Natural;
        attribute maxHops : Natural;
        attribute isBroadcast : Boolean;
    }

    item def JoinRequest {
        attribute deviceExtAddress : ExtendedAddress;
        attribute deviceType : DeviceType;
        attribute rssi : RSSIValue;
        attribute supportedChannels : ChannelNumber[0..*];
    }

    item def JoinResponse {
        attribute accepted : Boolean;
        attribute assignedShortAddress : ShortAddress;
        attribute parentAddress : ShortAddress;
        attribute panId : PanId;
        attribute channel : ChannelNumber;
        attribute networkKey : String;
    }

    item def RoutingTableEntry {
        attribute destinationAddress : ShortAddress;
        attribute nextHopAddress : ShortAddress;
        attribute hopCount : Natural;
        attribute routeCost : Natural;
        attribute isActive : Boolean;
        attribute lastUpdated : TimeValue;
    }

    item def NeighborTableEntry {
        attribute neighborAddress : ShortAddress;
        attribute neighborExtAddress : ExtendedAddress;
        attribute deviceType : DeviceType;
        attribute rssi : RSSIValue;
        attribute isParent : Boolean;
        attribute isActive : Boolean;
        attribute lastContactTime : TimeValue;
    }

    item def NetworkBeacon {
        attribute panId : PanId;
        attribute coordinatorExtAddress : ExtendedAddress;
        attribute channel : ChannelNumber;
        attribute permitJoining : Boolean;
        attribute depth : Natural;
        attribute rssi : RSSIValue;
        attribute beaconInterval : TimeValue;
    }

    item def StatusReport {
        attribute deviceAddress : ShortAddress;
        attribute batteryLevel : BatteryLevelValue;
        attribute rssi : RSSIValue;
        attribute isOnline : Boolean;
        attribute timestamp : TimeValue;
    }

    item def RouteRequest {
        attribute sourceAddress : ShortAddress;
        attribute destinationAddress : ShortAddress;
        attribute broadcastId : Natural;
        attribute pathCost : Natural;
    }

    item def RouteReply {
        attribute sourceAddress : ShortAddress;
        attribute destinationAddress : ShortAddress;
        attribute pathCost : Natural;
        attribute responderAddress : ShortAddress;
    }

    // ===== Port Definitions =====

    port def RadioPort {
        in item beaconIn : NetworkBeacon;
        in item dataIn : DataPacket;
        in item joinReqIn : JoinRequest;
        in item joinRespIn : JoinResponse;
        in item statusIn : StatusReport;
        in item routeReqIn : RouteRequest;
        in item routeReplyIn : RouteReply;
        out item dataOut : DataPacket;
        out item beaconOut : NetworkBeacon;
        out item joinReqOut : JoinRequest;
        out item joinRespOut : JoinResponse;
        out item statusOut : StatusReport;
        out item routeReqOut : RouteRequest;
        out item routeReplyOut : RouteReply;

        attribute operatingFrequency : FrequencyValue = 2.4;
        attribute channel : ChannelNumber;
        attribute txPower : PowerValue;
        attribute rxSensitivity : RSSIValue = -85.0;
    }

    port def GatewayPort {
        in item uplinkData : DataPacket;
        out item downlinkData : DataPacket;
        attribute isConnected : Boolean;
    }

    // ===== Connection Definition =====

    connection def WirelessLink {
        end sender : RadioPort;
        end receiver : RadioPort;
        attribute rssi : RSSIValue;
        attribute linkQuality : Natural;
        attribute isActive : Boolean = true;
    }

    // ===== Abstract Zigbee Device =====

    part def ZigbeeDevice {
        port radioPort : RadioPort;

        attribute deviceExtAddress : ExtendedAddress;
        attribute shortAddress : ShortAddress;
        attribute panId : PanId;
        attribute channel : ChannelNumber;
        attribute batteryLevel : BatteryLevelValue;
        attribute txPower : PowerValue;
        attribute isOnline : Boolean = true;
        attribute maxDataRate : DataRateValue = 250.0;
        attribute memorySize : MemoryValue = 32.0;

        item neighborTable : NeighborTableEntry[0..*];

        exhibit state deviceBehavior {
            entry; then Off;

            state Off {
                entry action { /* Device powered off, radio disabled */ }
            }
            transition first Off if powerOn then Initializing;

            state Initializing {
                entry action { /* Initialize hardware and radio transceiver */ }
                do action scanChannels { /* Scan 2.4 GHz channels for active networks */ }
            }
            transition first Initializing if networkFound then Joining;
            transition first Initializing if noNetworkFound then Standalone;

            state Standalone {
                entry action { /* Operate without network; retry scan periodically */ }
            }
            transition first Standalone if networkFound then Joining;

            state Joining {
                entry action { /* Send join request to discovered coordinator or router */ }
                do action authenticate { /* Perform authentication handshake */ }
            }
            transition first Joining if joinAccepted then Operational;
            transition first Joining if joinFailed then Standalone;

            state Operational {
                entry action { /* Device joined network; begin normal operation */ }
                do action performDeviceTask;
            }
            transition first Operational if idleTimeout and sleepCapable then Sleeping;
            transition first Operational if powerOff then Off;
            transition first Operational if connectionLost then Reconnecting;

            state Reconnecting {
                entry action { /* Attempt to rejoin network through parent or new parent */ }
                do action findNewParent;
            }
            transition first Reconnecting if rejoined then Operational;
            transition first Reconnecting if rejoinFailed then Standalone;

            state Sleeping {
                entry action { /* Enter low-power mode; disable radio transceiver */ }
                do action sleepTimer { /* Wait for sleep interval to elapse */ }
            }
            transition first Sleeping if wakeUp then Operational;
            transition first Sleeping if powerOff then Off;
        }

        action def performDeviceTask {
            doc /* Default device task; overridden by specific device types. */;
        }
    }

    // ===== Zigbee Coordinator =====

    part def ZigbeeCoordinator :> ZigbeeDevice {
        port gatewayPort : GatewayPort;

        attribute networkId : NetworkId;
        attribute isFounder : Boolean = true;
        attribute permitJoining : Boolean = true;
        attribute maxDevices : Natural = 32;
        attribute connectedDeviceCount : Natural;
        attribute beaconInterval : TimeValue = 3000.0;

        item routingTable : RoutingTableEntry[0..*];
        item registeredDevices : ExtendedAddress[0..*];

        exhibit state coordinatorBehavior {
            entry; then Off;

            state Off {
                entry action { /* Coordinator powered off */ }
            }
            transition first Off if powerOn then Initializing;

            state Initializing {
                entry action selectChannel { /* Select optimal channel in 2.4 GHz ISM band */ }
                do action configureNetwork {
                    /* Assign PAN ID, generate network key, configure security */ 
                }
            }
            transition first Initializing if networkConfigured then NetworkActive;

            state NetworkActive {
                entry action broadcastBeacon { /* Begin periodic beacon transmission */ }
                do action manageNetwork;
            }
            transition first NetworkActive if permitJoining == true then AcceptingJoins;
            transition first NetworkActive if permitJoining == false then RejectingJoins;

            state AcceptingJoins {
                entry action enableJoining { /* Open network for new device joins */ }
                do action processJoinRequests;
            }
            transition first AcceptingJoins if permitJoining == false then RejectingJoins;

            state RejectingJoins {
                entry action disableJoining { /* Close network to new device joins */ }
            }
            transition first RejectingJoins if permitJoining == true then AcceptingJoins;

            transition first AcceptingJoins if powerOff then Off;
            transition first RejectingJoins if powerOff then Off;
        }

        action def manageNetwork {
            in item joinReq : JoinRequest via radioPort.joinReqIn;
            out item joinResp : JoinResponse via radioPort.joinRespOut;
            in item dataPkt : DataPacket via radioPort.dataIn;
            out item forwardedPkt : DataPacket via radioPort.dataOut;

            doc /* Authenticate joining devices, assign short addresses, maintain routing tables, and forward data packets to gateway or destination. */;

            action authenticateDevice {
                in item req : JoinRequest;
                out item authResult : Boolean;
                /* Verify device credentials and authorize join */ 
            }
            action assignAddress {
                in item req : JoinRequest;
                out item shortAddr : ShortAddress;
                /* Allocate unique 16-bit short address */ 
            }
            action updateRoutingTable {
                in item entry : RoutingTableEntry;
                /* Add or update route in coordinator routing table */ 
            }
            action forwardToGateway {
                in item pkt : DataPacket;
                out item gwData : DataPacket via gatewayPort.uplinkData;
                /* Forward collected data to external network via gateway */ 
            }

            flow from authenticateDevice.authResult to assignAddress;
            flow from joinReq to authenticateDevice.req;
        }

        action def processJoinRequests {
            in item joinReq : JoinRequest via radioPort.joinReqIn;
            out item joinResp : JoinResponse via radioPort.joinRespOut;
            doc /* Continuously process incoming join requests from candidate devices. */;
        }

        action def broadcastBeacon {
            out item beacon : NetworkBeacon via radioPort.beaconOut;
            doc /* Periodically transmit network beacon on configured channel. */;
        }
    }

    // ===== Zigbee Router =====

    part def ZigbeeRouter :> ZigbeeDevice {
        attribute parentAddress : ShortAddress;
        attribute depth : Natural;
        attribute routingTableSize : Natural = 32;
        attribute isRoutingEnabled : Boolean = true;
        attribute sleepEnabled : Boolean = false;
        attribute routeDiscoveryTimeout : TimeValue = 5000.0;

        item routingTable : RoutingTableEntry[0..*];

        exhibit state routerBehavior {
            entry; then Off;

            state Off {
                entry action { /* Router powered off */ }
            }
            transition first Off if powerOn then Scanning;

            state Scanning {
                entry action scanChannels { /* Scan channels for network beacons */ }
                do action findNetwork { /* Evaluate beacon RSSI and select best parent */ }
            }
            transition first Scanning if beaconReceived then Joining;
            transition first Scanning if scanTimeout then Off;

            state Joining {
                entry action sendJoinRequest { /* Send join request to selected coordinator or router */ }
                do action waitForResponse { /* Wait for join response */ }
            }
            transition first Joining if joinAccepted then Operational;
            transition first Joining if joinFailed then Scanning;

            state Operational {
                entry action { /* Router operational; relaying traffic and maintaining routes */ }
                do action routeTraffic;
            }
            transition first Operational if packetReceived then Relaying;
            transition first Operational if routeUpdateNeeded then MaintainingRoutes;
            transition first Operational if pathFailureDetected then DiscoveringRoute;
            transition first Operational if idleTimeout and sleepEnabled then Sleeping;
            transition first Operational if powerOff then Off;

            state Relaying {
                entry action processPacket { /* Receive and forward data packet to next hop */ }
                do action forwardPacket;
            }
            transition first Relaying if forwardingComplete then Operational;

            state MaintainingRoutes {
                entry action updateRoutingTable { /* Update neighbor and routing tables */ }
                do action checkNeighborHealth;
            }
            transition first MaintainingRoutes if updateComplete then Operational;

            state DiscoveringRoute {
                entry action broadcastRouteRequest { /* Initiate route discovery for unreachable destination */ }
                do action collectRouteReplies;
            }
            transition first DiscoveringRoute if routeDiscovered then Operational;
            transition first DiscoveringRoute if discoveryTimeout then Operational;

            state Sleeping {
                entry action enterLowPower { /* Disable radio; enter low-power mode */ }
            }
            transition first Sleeping if wakeUp then Operational;
            transition first Sleeping if powerOff then Off;
        }

        action def routeTraffic {
            in item packet : DataPacket via radioPort.dataIn;
            out item forwardedPacket : DataPacket via radioPort.dataOut;
            in item routeReq : RouteRequest via radioPort.routeReqIn;
            out item routeReply : RouteReply via radioPort.routeReplyOut;

            doc /* Route incoming data packets using routing table; initiate route discovery if no route exists. */;

            action lookupRoute {
                in item destAddr : ShortAddress;
                out item nextHop : ShortAddress;
                out item routeFound : Boolean;
                /* Search routing table for destination */ 
            }
            action forwardToNextHop {
                in item pkt : DataPacket;
                in item nextHop : ShortAddress;
                out item fwdPkt : DataPacket;
                /* Increment hop count and transmit to next hop */ 
            }
            action initiateRouteDiscovery {
                in item destAddr : ShortAddress;
                out item routeReqOut : RouteRequest;
                /* Broadcast route request to discover path */ 
            }

            flow from packet.destinationAddress to lookupRoute.destAddr;
            flow from lookupRoute.nextHop to forwardToNextHop.nextHop;
            flow from packet to forwardToNextHop.pkt;
        }

        action def updateRoutingTable {
            in item neighborInfo : NeighborTableEntry;
            doc /* Update neighbor table and routing table; detect failed links and mark routes inactive. */;
            action checkNeighborHealth {
                in item neighbor : NeighborTableEntry;
                out item isAlive : Boolean;
                /* Ping neighbor and evaluate RSSI */ 
            }
            action markRouteInactive {
                in item destAddr : ShortAddress;
                /* Mark routes through failed neighbor as inactive */ 
            }
            action discoverAlternateRoute {
                in item destAddr : ShortAddress;
                out item newRoute : RoutingTableEntry;
                /* Find alternate path through other neighbors */ 
            }
        }

        action def forwardPacket {
            in item packet : DataPacket via radioPort.dataIn;
            out item forwarded : DataPacket via radioPort.dataOut;
            doc /* Forward packet to next hop based on routing table lookup. */;
        }
    }

    // ===== Zigbee End Device =====

    part def ZigbeeEndDevice :> ZigbeeDevice {
        attribute parentAddress : ShortAddress;
        attribute sleepInterval : TimeValue = 1000.0;
        attribute isSleepCapable : Boolean = true;
        attribute sensorType : DeviceType;
        attribute actuatorType : DeviceType;
        attribute isRoutingEnabled : Boolean = false;
        attribute pollInterval : TimeValue = 5000.0;

        exhibit state endDeviceBehavior {
            entry; then Off;

            state Off {
                entry action { /* End device powered off */ }
            }
            transition first Off if powerOn then Scanning;

            state Scanning {
                entry action scanChannels { /* Scan for parent router or coordinator beacons */ }
                do action findParent { /* Select parent with best RSSI */ }
            }
            transition first Scanning if beaconReceived then Joining;
            transition first Scanning if scanTimeout then Off;

            state Joining {
                entry action sendJoinRequest { /* Send join request to selected parent */ }
                do action waitForResponse { /* Wait for join response with assigned address */ }
            }
            transition first Joining if joinAccepted then Operational;
            transition first Joining if joinFailed then Scanning;

            state Operational {
                entry action { /* End device operational; performing sensing or actuation */ }
                do action performDeviceTask;
            }
            transition first Operational if dataReady then Transmitting;
            transition first Operational if pollTimerExpired then Polling;
            transition first Operational if idleTimeout and isSleepCapable then Sleeping;
            transition first Operational if powerOff or batteryLevel < 5.0 then Off;

            state Transmitting {
                entry action collectData { /* Gather sensor reading or actuator status */ }
                do action sendDataToParent;
            }
            transition first Transmitting if transmissionComplete then Operational;

            state Polling {
                entry action pollParent { /* Send poll request to parent for pending messages */ }
                do action checkForMessages { /* Receive any buffered messages from parent */ }
            }
            transition first Polling if pollComplete then Operational;

            state Sleeping {
                entry action enterLowPower { /* Disable radio; conserve battery */ }
                do action sleepTimer { /* Remain in sleep for sleepInterval duration */ }
            }
            transition first Sleeping if wakeUp then Operational;
            transition first Sleeping if powerOff then Off;
        }

        action def performDeviceTask {
            doc /* Perform sensor reading or actuator control; overridden by specific end device. */;
        }

        action def sendDataToParent {
            out item packet : DataPacket via radioPort.dataOut;
            doc /* Construct data packet with sensor reading and transmit to parent router. */;
            action buildPacket {
                out item pkt : DataPacket;
                /* Set source, destination, payload, sequence number */ 
            }
            action transmit {
                in item pkt : DataPacket;
                out item sentPkt : DataPacket;
                /* Send packet via radio to parent */ 
            }
            flow from buildPacket.pkt to transmit.pkt;
        }

        action def pollParent {
            out item pollRequest : DataPacket via radioPort.dataOut;
            in item pendingMessages : DataPacket[0..*] via radioPort.dataIn;
            doc /* Poll parent router for any buffered incoming messages. */;
        }

        action def enterLowPower {
            doc /* Disable radio transceiver and enter low-power sleep mode. */;
        }
    }

    // ===== Specific End Device Types =====

    part def TemperatureSensor :> ZigbeeEndDevice {
        :>> sensorType = "temperature";
        attribute temperatureValue : Real;
        attribute samplingInterval : TimeValue = 2000.0;

        action def performDeviceTask {
            doc /* Read temperature sensor and prepare data for transmission. */;
            action readTemperature {
                out item tempValue : Real;
                /* Read analog or digital temperature sensor */ 
            }
            action preparePacket {
                in item temp : Real;
                out item pkt : DataPacket;
                /* Package temperature reading into DataPacket */ 
            }
            flow from readTemperature.tempValue to preparePacket.temp;
        }
    }

    part def LightSwitch :> ZigbeeEndDevice {
        :>> sensorType = "light_switch";
        :>> actuatorType = "light_switch";
        attribute switchState : Boolean = false;

        action def performDeviceTask {
            doc /* Detect switch toggle and send state change command. */;
            action detectToggle {
                out item newState : Boolean;
                /* Detect physical switch state change */ 
            }
            action sendCommand {
                in item state : Boolean;
                out item pkt : DataPacket;
                /* Send toggle command to coordinator or actuator */ 
            }
            flow from detectToggle.newState to sendCommand.state;
        }
    }

    part def DoorLock :> ZigbeeEndDevice {
        :>> actuatorType = "door_lock";
        attribute lockState : Boolean = true;
        attribute isLocked : Boolean = true;

        action def performDeviceTask {
            doc /* Receive lock/unlock commands and actuate door lock mechanism. */;
            action receiveCommand {
                in item pkt : DataPacket via radioPort.dataIn;
                out item command : Boolean;
                /* Parse incoming lock/unlock command */ 
            }
            action actuateLock {
                in item cmd : Boolean;
                out item newState : Boolean;
                /* Drive lock motor to locked or unlocked position */ 
            }
            flow from receiveCommand.command to actuateLock.cmd;
        }
    }

    // ===== Network Definition =====

    part def ZigbeeNetwork {
        attribute networkId : NetworkId;
        attribute panId : PanId;
        attribute channel : ChannelNumber;
        attribute operatingFrequency : FrequencyValue = 2.4;
        attribute maxHops : Natural = 30;
        attribute selfHealingEnabled : Boolean = true;
        attribute maxDevices : Natural = 32;
        attribute securityEnabled : Boolean = true;

        part coordinator : ZigbeeCoordinator {
            :>> deviceExtAddress = "00:1A:2B:3C:4D:5E:6F:70";
            :>> shortAddress = 0;
            :>> networkId = 1;
            :>> panId = 0x1A2B;
            :>> channel = 15;
            :>> txPower = 10.0;
            :>> batteryLevel = 100.0;
            :>> permitJoining = true;
            :>> connectedDeviceCount = 6;
        }

        part router1 : ZigbeeRouter {
            :>> deviceExtAddress = "00:1A:2B:3C:4D:5E:6F:71";
            :>> shortAddress = 1;
            :>> panId = 0x1A2B;
            :>> channel = 15;
            :>> txPower = 8.0;
            :>> batteryLevel = 85.0;
            :>> parentAddress = 0;
            :>> depth = 1;
        }

        part router2 : ZigbeeRouter {
            :>> deviceExtAddress = "00:1A:2B:3C:4D:5E:6F:72";
            :>> shortAddress = 2;
            :>> panId = 0x1A2B;
            :>> channel = 15;
            :>> txPower = 8.0;
            :>> batteryLevel = 78.0;
            :>> parentAddress = 1;
            :>> depth = 2;
        }

        part router3 : ZigbeeRouter {
            :>> deviceExtAddress = "00:1A:2B:3C:4D:5E:6F:73";
            :>> shortAddress = 3;
            :>> panId = 0x1A2B;
            :>> channel = 15;
            :>> txPower = 8.0;
            :>> batteryLevel = 92.0;
            :>> parentAddress = 0;
            :>> depth = 1;
        }

        part tempSensor1 : TemperatureSensor {
            :>> deviceExtAddress = "00:1A:2B:3C:4D:5E:6F:81";
            :>> shortAddress = 10;
            :>> panId = 0x1A2B;
            :>> channel = 15;
            :>> txPower = 5.0;
            :>> batteryLevel = 72.0;
            :>> parentAddress = 1;
            :>> sleepInterval = 2000.0;
            :>> temperatureValue = 22.5;
        }

        part tempSensor2 : TemperatureSensor {
            :>> deviceExtAddress = "00:1A:2B:3C:4D:5E:6F:82";
            :>> shortAddress = 11;
            :>> panId = 0x1A2B;
            :>> channel = 15;
            :>> txPower = 5.0;
            :>> batteryLevel = 65.0;
            :>> parentAddress = 2;
            :>> sleepInterval = 3000.0;
            :>> temperatureValue = 19.8;
        }

        part lightSwitch1 : LightSwitch {
            :>> deviceExtAddress = "00:1A:2B:3C:4D:5E:6F:91";
            :>> shortAddress = 20;
            :>> panId = 0x1A2B;
            :>> channel = 15;
            :>> txPower = 5.0;
            :>> batteryLevel = 88.0;
            :>> parentAddress = 1;
            :>> switchState = false;
        }

        part doorLock1 : DoorLock {
            :>> deviceExtAddress = "00:1A:2B:3C:4D:5E:6F:A1";
            :>> shortAddress = 30;
            :>> panId = 0x1A2B;
            :>> channel = 15;
            :>> txPower = 5.0;
            :>> batteryLevel = 54.0;
            :>> parentAddress = 3;
            :>> isLocked = true;
        }

        // Wireless links forming the mesh topology
        connection linkCoordRouter1 : WirelessLink connect coordinator.radioPort to router1.radioPort {
            :>> rssi = -45.0;
            :>> linkQuality = 95;
        }
        connection linkCoordRouter3 : WirelessLink connect coordinator.radioPort to router3.radioPort {
            :>> rssi = -52.0;
            :>> linkQuality = 88;
        }
        connection linkRouter1Router2 : WirelessLink connect router1.radioPort to router2.radioPort {
            :>> rssi = -58.0;
            :>> linkQuality = 82;
        }
        connection linkRouter2Router3 : WirelessLink connect router2.radioPort to router3.radioPort {
            :>> rssi = -61.0;
            :>> linkQuality = 78;
        }
        connection linkRouter1Temp1 : WirelessLink connect router1.radioPort to tempSensor1.radioPort {
            :>> rssi = -48.0;
            :>> linkQuality = 92;
        }
        connection linkRouter1Light : WirelessLink connect router1.radioPort to lightSwitch1.radioPort {
            :>> rssi = -50.0;
            :>> linkQuality = 90;
        }
        connection linkRouter2Temp2 : WirelessLink connect router2.radioPort to tempSensor2.radioPort {
            :>> rssi = -55.0;
            :>> linkQuality = 85;
        }
        connection linkRouter3Door : WirelessLink connect router3.radioPort to doorLock1.radioPort {
            :>> rssi = -53.0;
            :>> linkQuality = 87;
        }
    }

    // ===== Requirement Definitions =====

    requirement def LowPowerCommunication {
        subject device : ZigbeeDevice;
        doc /* The device shall operate with low power consumption suitable for battery-powered operation. */;
        require {
            device.txPower <= 10.0;
            device.maxDataRate <= 250.0;
        }
    }

    requirement def MeshReliability {
        subject network : ZigbeeNetwork;
        doc /* The network shall provide reliable communication through mesh topology with self-healing capability. */;
        require {
            network.selfHealingEnabled == true;
            network.maxHops >= 15;
        }
    }

    requirement def SelfOrganizingNetwork {
        subject network : ZigbeeNetwork;
        doc /* The network shall self-organize by allowing devices to discover and join automatically. */;
        require {
            network.coordinator.permitJoining == true;
        }
    }

    requirement def CoordinatorManagement {
        subject coordinator : ZigbeeCoordinator;
        doc /* The coordinator shall establish and manage the network, including channel selection, PAN ID assignment, and device authorization. */;
        require {
            coordinator.isFounder == true;
            coordinator.permitJoining == true;
            coordinator.radioPort.operatingFrequency == 2.4;
        }
    }

    requirement def RouterRelay {
        subject router : ZigbeeRouter;
        doc /* The router shall relay messages and maintain routing tables for efficient path selection. */;
        require {
            router.isRoutingEnabled == true;
            router.routingTableSize >= 16;
        }
    }

    requirement def EndDeviceSleep {
        subject endDevice : ZigbeeEndDevice;
        doc /* End devices shall support low-power sleep mode to conserve battery life and shall not route traffic. */;
        require {
            endDevice.isSleepCapable == true;
            endDevice.isRoutingEnabled == false;
        }
    }

    requirement def WirelessCommunication {
        subject device : ZigbeeDevice;
        doc /* All devices shall communicate wirelessly over 2.4 GHz radio frequency. */;
        require {
            device.radioPort.operatingFrequency == 2.4;
        }
    }

    requirement def DataPacketStructure {
        subject packet : DataPacket;
        doc /* Data packets shall contain source and destination addresses, payload, and control information. */;
        require {
            packet.sourceAddress != null;
            packet.destinationAddress != null;
            packet.payload != null;
            packet.sequenceNumber != null;
            packet.hopCount != null;
        }
    }

    requirement def SelfHealingRerouting {
        subject router : ZigbeeRouter;
        doc /* When a communication path fails, the router shall automatically reroute through alternative available paths. */;
        require {
            router.isRoutingEnabled == true;
        }
    }

    requirement def NetworkSecurity {
        subject network : ZigbeeNetwork;
        doc /* The network shall employ security mechanisms to protect data integrity and confidentiality. */;
        require {
            network.securityEnabled == true;
        }
    }

    requirement def GatewayConnectivity {
        subject coordinator : ZigbeeCoordinator;
        doc /* The coordinator shall serve as a gateway to external networks for data collection and remote access. */;
        require {
            coordinator.gatewayPort.isConnected == true;
        }
    }

    // ===== Requirement Usages and Satisfaction =====

    requirement lowPowerCoord : LowPowerCommunication;
    requirement lowPowerRouter : LowPowerCommunication;
    requirement lowPowerEndDev : LowPowerCommunication;
    requirement meshRel : MeshReliability;
    requirement selfOrg : SelfOrganizingNetwork;
    requirement coordMgmt : CoordinatorManagement;
    requirement routerRelay : RouterRelay;
    requirement endDevSleep : EndDeviceSleep;
    requirement wirelessComm : WirelessCommunication;
    requirement pktStruct : DataPacketStructure;
    requirement selfHeal : SelfHealingRerouting;
    requirement netSec : NetworkSecurity;
    requirement gwConn : GatewayConnectivity;

    satisfy lowPowerCoord by coordinator;
    satisfy lowPowerRouter by router1;
    satisfy lowPowerEndDev by tempSensor1;
    satisfy meshRel by ZigbeeNetwork;
    satisfy selfOrg by ZigbeeNetwork;
    satisfy coordMgmt by coordinator;
    satisfy routerRelay by router1;
    satisfy endDevSleep by tempSensor1;
    satisfy wirelessComm by coordinator;
    satisfy wirelessComm by router1;
    satisfy wirelessComm by tempSensor1;
    satisfy pktStruct by DataPacket;
    satisfy selfHeal by router1;
    satisfy netSec by ZigbeeNetwork;
    satisfy gwConn by coordinator;
}
