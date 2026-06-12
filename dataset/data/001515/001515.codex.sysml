package OneNetSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    /* Value and item definitions */

    value def FrequencyMHz :> Real {
        unit = "MHz";
    }

    value def DataRateKbps :> Real {
        unit = "kbps";
    }

    value def PowerdBm :> Real {
        unit = "dBm";
    }

    value def Percent :> Real {
        unit = "%";
    }

    value def Millisecond :> Real {
        unit = "ms";
    }

    value def Meter :> Real {
        unit = "m";
    }

    value def ByteCount :> Integer {
        unit = "byte";
    }

    enum def DeviceRole {
        enum master;
        enum peer;
        enum repeater;
        enum sleepingEndpoint;
    }

    enum def LinkState {
        enum unjoined;
        enum discovering;
        enum joining;
        enum authenticated;
        enum synchronized;
        enum degraded;
        enum isolated;
    }

    enum def MessagePriority {
        enum emergency;
        enum high;
        enum normal;
        enum low;
    }

    enum def SecurityMode {
        enum none;
        enum networkKey;
        enum sessionKey;
    }

    item def OneNetFrame {
        attribute networkId : Integer;
        attribute sourceAddress : Integer;
        attribute destinationAddress : Integer;
        attribute sequenceNumber : Integer;
        attribute priority : MessagePriority;
        attribute payloadSize : ByteCount;
        attribute encrypted : Boolean;
        attribute checksumValid : Boolean;
    }

    item def ControlCommand {
        attribute commandId : Integer;
        attribute targetFunction : String;
        attribute requestedState : String;
        attribute priority : MessagePriority;
    }

    item def SensorReport {
        attribute sensorId : Integer;
        attribute measuredValue : Real;
        attribute engineeringUnit : String;
        attribute sampleAge : Millisecond;
    }

    item def NetworkStatus {
        attribute joinedNodeCount : Integer;
        attribute packetDeliveryRatio : Percent;
        attribute averageLatency : Millisecond;
        attribute channelQuality : Percent;
    }

    port def RadioPort {
        in item receivedFrame : OneNetFrame;
        out item transmittedFrame : OneNetFrame;
        attribute centerFrequency : FrequencyMHz;
        attribute transmitPower : PowerdBm;
        attribute receiveSensitivity : PowerdBm;
    }

    port def ApplicationPort {
        in item inboundCommand : ControlCommand;
        out item outboundReport : SensorReport;
        out item networkStatus : NetworkStatus;
    }

    port def ManagementPort {
        in item provisioningCommand : ControlCommand;
        out item diagnosticStatus : NetworkStatus;
    }

    port def PowerPort {
        in item supplyVoltage;
        out item powerDemand;
    }

    /* Core system structure */

    part def OneNetBasedSystem {
        doc /* 
         * Primary function:
         * Provide a low-power wireless control and monitoring network that allows distributed embedded devices
         * to discover one another, authenticate, synchronize communication, exchange short command and sensor
         * messages, and maintain reliable operation using acknowledged packet transfer and adaptive routing.
         */

        attribute networkIdentifier : Integer = 1701;
        attribute operatingFrequency : FrequencyMHz = 915.0;
        attribute nominalDataRate : DataRateKbps = 38.4;
        attribute maximumPayloadSize : ByteCount = 58;
        attribute targetDeliveryRatio : Percent = 99.0;
        attribute targetCommandLatency : Millisecond = 150.0;
        attribute indoorRange : Meter = 60.0;
        attribute securityMode : SecurityMode = SecurityMode::sessionKey;

        port app : ApplicationPort;
        port management : ManagementPort;
        port power : PowerPort;

        part coordinator : OneNetCoordinator {
            attribute address = 1;
            attribute role = DeviceRole::master;
        }

        part environmentalSensor : OneNetSensorNode {
            attribute address = 11;
            attribute role = DeviceRole::sleepingEndpoint;
            attribute sensorKind = "temperatureHumidity";
        }

        part actuatorController : OneNetActuatorNode {
            attribute address = 21;
            attribute role = DeviceRole::peer;
            attribute controlledLoad = "lightingRelay";
        }

        part rangeExtender : OneNetRepeaterNode {
            attribute address = 31;
            attribute role = DeviceRole::repeater;
        }

        part securityManager : SecurityManager;
        part routingManager : RoutingManager;
        part timebase : NetworkTimebase;
        part healthMonitor : NetworkHealthMonitor;

        connect coordinator.radio to rangeExtender.upstreamRadio;
        connect rangeExtender.downstreamRadio to environmentalSensor.radio;
        connect rangeExtender.downstreamRadio to actuatorController.radio;

        connect coordinator.application to app;
        connect coordinator.management to management;

        connect coordinator.securityInterface to securityManager.nodeSecurityInterface;
        connect environmentalSensor.securityInterface to securityManager.nodeSecurityInterface;
        connect actuatorController.securityInterface to securityManager.nodeSecurityInterface;
        connect rangeExtender.securityInterface to securityManager.nodeSecurityInterface;

        connect coordinator.routingInterface to routingManager.routeControl;
        connect rangeExtender.routingInterface to routingManager.routeControl;

        connect coordinator.timeInterface to timebase.timeDistribution;
        connect environmentalSensor.timeInterface to timebase.timeDistribution;
        connect actuatorController.timeInterface to timebase.timeDistribution;
        connect rangeExtender.timeInterface to timebase.timeDistribution;

        connect coordinator.healthInterface to healthMonitor.nodeTelemetry;
        connect environmentalSensor.healthInterface to healthMonitor.nodeTelemetry;
        connect actuatorController.healthInterface to healthMonitor.nodeTelemetry;
        connect rangeExtender.healthInterface to healthMonitor.nodeTelemetry;

        action provideWirelessControlAndMonitoring {
            first startNetwork;
            then admitNodes;
            then synchronizeNodes;
            then exchangeMessages;
            then monitorHealth;

            action startNetwork {
                out item status : NetworkStatus;
            }

            action admitNodes {
                in item provisioningCommand : ControlCommand;
                out item status : NetworkStatus;
            }

            action synchronizeNodes {
                out item status : NetworkStatus;
            }

            action exchangeMessages {
                in item command : ControlCommand;
                out item report : SensorReport;
            }

            action monitorHealth {
                out item status : NetworkStatus;
            }
        }

        state networkOperation {
            entry action initializeCoordinator;
            state Offline;
            state FormingNetwork;
            state Operational;
            state Degraded;
            state Recovery;

            transition first Offline;
            transition Offline_to_FormingNetwork
                first Offline
                then FormingNetwork
                accept StartRequested;

            transition FormingNetwork_to_Operational
                first FormingNetwork
                then Operational
                accept NodesAuthenticated;

            transition Operational_to_Degraded
                first Operational
                then Degraded
                accept DeliveryRatioBelowTarget;

            transition Degraded_to_Recovery
                first Degraded
                then Recovery
                accept RouteRepairRequested;

            transition Recovery_to_Operational
                first Recovery
                then Operational
                accept RouteRepairComplete;

            transition Recovery_to_Degraded
                first Recovery
                then Degraded
                accept RouteRepairFailed;
        }
    }

    part def OneNetNode {
        attribute address : Integer;
        attribute role : DeviceRole;
        attribute linkState : LinkState = LinkState::unjoined;
        attribute batteryPowered : Boolean;
        attribute lastHeardAge : Millisecond;
        attribute retryLimit : Integer = 3;
        attribute acknowledgementTimeout : Millisecond = 30.0;

        port radio : RadioPort;
        port application : ApplicationPort;
        port securityInterface : ManagementPort;
        port routingInterface : ManagementPort;
        port timeInterface : ManagementPort;
        port healthInterface : ManagementPort;

        action joinNetwork {
            first scanChannels;
            then requestAdmission;
            then authenticateNode;
            then synchronizeClock;

            action scanChannels {
                out item discoveredBeacon : OneNetFrame;
            }

            action requestAdmission {
                in item discoveredBeacon : OneNetFrame;
                out item joinRequest : OneNetFrame;
            }

            action authenticateNode {
                in item joinChallenge : OneNetFrame;
                out item joinResponse : OneNetFrame;
            }

            action synchronizeClock {
                in item timeBeacon : OneNetFrame;
            }
        }

        action transmitReliableFrame {
            in item frameToSend : OneNetFrame;
            out item acknowledgedFrame : OneNetFrame;

            first encryptPayload;
            then assignSequenceNumber;
            then sendFrame;
            then waitForAcknowledgement;

            action encryptPayload {
                in item plainFrame : OneNetFrame;
                out item protectedFrame : OneNetFrame;
            }

            action assignSequenceNumber {
                in item protectedFrame : OneNetFrame;
                out item sequencedFrame : OneNetFrame;
            }

            action sendFrame {
                in item sequencedFrame : OneNetFrame;
                out item transmittedFrame : OneNetFrame;
            }

            action waitForAcknowledgement {
                in item transmittedFrame : OneNetFrame;
                out item acknowledgedFrame : OneNetFrame;
            }
        }

        state nodeLifecycle {
            state Unjoined;
            state Discovering;
            state Joining;
            state Authenticated;
            state Synchronized;
            state Active;
            state Sleep;
            state Isolated;

            transition first Unjoined;
            transition Unjoined_to_Discovering
                first Unjoined
                then Discovering
                accept PowerApplied;

            transition Discovering_to_Joining
                first Discovering
                then Joining
                accept BeaconDetected;

            transition Joining_to_Authenticated
                first Joining
                then Authenticated
                accept AuthenticationAccepted;

            transition Authenticated_to_Synchronized
                first Authenticated
                then Synchronized
                accept TimeBeaconReceived;

            transition Synchronized_to_Active
                first Synchronized
                then Active
                accept ApplicationTrafficReady;

            transition Active_to_Sleep
                first Active
                then Sleep
                accept IdlePeriodStarted;

            transition Sleep_to_Active
                first Sleep
                then Active
                accept WakeTimerExpired;

            transition Active_to_Isolated
                first Active
                then Isolated
                accept MissedBeaconLimitExceeded;

            transition Isolated_to_Discovering
                first Isolated
                then Discovering
                accept RejoinRequested;
        }
    }

    part def OneNetCoordinator :> OneNetNode {
        attribute batteryPowered = false;
        attribute maximumJoinedNodes : Integer = 64;
        attribute beaconInterval : Millisecond = 250.0;

        port management : ManagementPort;

        action formNetwork {
            first selectChannel;
            then publishBeacon;
            then admitAuthenticatedNodes;

            action selectChannel {
                out attribute selectedFrequency : FrequencyMHz;
            }

            action publishBeacon {
                out item beaconFrame : OneNetFrame;
            }

            action admitAuthenticatedNodes {
                in item joinRequest : OneNetFrame;
                out item admissionResponse : OneNetFrame;
            }
        }
    }

    part def OneNetSensorNode :> OneNetNode {
        attribute batteryPowered = true;
        attribute sensorKind : String;
        attribute reportingInterval : Millisecond = 5000.0;
        attribute maximumSleepCurrent;

        action sampleAndReport {
            first wakeReceiver;
            then sampleSensor;
            then sendReport;
            then returnToSleep;

            action wakeReceiver;
            action sampleSensor {
                out item report : SensorReport;
            }
            action sendReport {
                in item report : SensorReport;
                out item reportFrame : OneNetFrame;
            }
            action returnToSleep;
        }
    }

    part def OneNetActuatorNode :> OneNetNode {
        attribute batteryPowered = false;
        attribute controlledLoad : String;
        attribute commandExecutionDeadline : Millisecond = 100.0;
        attribute failsafeState : String = "off";

        action receiveAndExecuteCommand {
            first validateCommand;
            then applyOutputState;
            then acknowledgeCommand;

            action validateCommand {
                in item commandFrame : OneNetFrame;
                out item command : ControlCommand;
            }

            action applyOutputState {
                in item command : ControlCommand;
            }

            action acknowledgeCommand {
                out item acknowledgementFrame : OneNetFrame;
            }
        }

        state actuatorControl {
            state OutputOff;
            state OutputOn;
            state Failsafe;

            transition first OutputOff;
            transition OutputOff_to_OutputOn
                first OutputOff
                then OutputOn
                accept TurnOnCommand;

            transition OutputOn_to_OutputOff
                first OutputOn
                then OutputOff
                accept TurnOffCommand;

            transition OutputOn_to_Failsafe
                first OutputOn
                then Failsafe
                accept CommunicationLost;

            transition OutputOff_to_Failsafe
                first OutputOff
                then Failsafe
                accept CommunicationLost;

            transition Failsafe_to_OutputOff
                first Failsafe
                then OutputOff
                accept ValidCommandReceived;
        }
    }

    part def OneNetRepeaterNode :> OneNetNode {
        attribute batteryPowered = false;
        attribute maximumForwardedFramesPerSecond : Integer = 40;

        port upstreamRadio : RadioPort;
        port downstreamRadio : RadioPort;

        action forwardFrame {
            in item receivedFrame : OneNetFrame;
            out item forwardedFrame : OneNetFrame;

            first verifyChecksum;
            then consultRouteTable;
            then retransmitFrame;

            action verifyChecksum {
                in item receivedFrame : OneNetFrame;
                out attribute valid : Boolean;
            }

            action consultRouteTable {
                in item receivedFrame : OneNetFrame;
                out attribute nextHopAddress : Integer;
            }

            action retransmitFrame {
                in item receivedFrame : OneNetFrame;
                out item forwardedFrame : OneNetFrame;
            }
        }
    }

    part def SecurityManager {
        attribute activeSecurityMode : SecurityMode = SecurityMode::sessionKey;
        attribute networkKeyVersion : Integer = 4;
        attribute sessionKeyLifetime : Millisecond = 3600000.0;

        port nodeSecurityInterface : ManagementPort;

        action authenticateJoiningNode {
            in item joinRequest : OneNetFrame;
            out item authenticationResult : OneNetFrame;
        }

        action rotateSessionKeys {
            out item keyUpdateCommand : ControlCommand;
        }
    }

    part def RoutingManager {
        attribute routeRepairTimeout : Millisecond = 500.0;
        attribute maximumHopCount : Integer = 4;

        port routeControl : ManagementPort;

        action maintainRoutes {
            first collectLinkMetrics;
            then computePreferredRoutes;
            then distributeRouteUpdates;

            action collectLinkMetrics {
                out item status : NetworkStatus;
            }

            action computePreferredRoutes {
                in item status : NetworkStatus;
            }

            action distributeRouteUpdates {
                out item routeCommand : ControlCommand;
            }
        }
    }

    part def NetworkTimebase {
        attribute timeBeaconInterval : Millisecond = 1000.0;
        attribute maximumClockError : Millisecond = 5.0;

        port timeDistribution : ManagementPort;

        action distributeTimeBeacon {
            out item timeBeacon : OneNetFrame;
        }
    }

    part def NetworkHealthMonitor {
        attribute minimumDeliveryRatio : Percent = 99.0;
        attribute maximumAverageLatency : Millisecond = 150.0;
        attribute minimumChannelQuality : Percent = 70.0;

        port nodeTelemetry : ManagementPort;

        action evaluateNetworkHealth {
            in item status : NetworkStatus;
            out attribute healthy : Boolean;
        }

        action requestRecovery {
            out item recoveryCommand : ControlCommand;
        }
    }

    /* Requirements */

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide wireless command, monitoring, and status exchange among distributed embedded devices using a One-Net based low-power network. */
    }

    requirement def ReliableDeliveryRequirement {
        doc /* The system shall deliver normal-priority application messages with at least 99 percent packet delivery ratio under nominal indoor operating conditions. */
        attribute requiredDeliveryRatio : Percent = 99.0;
    }

    requirement def CommandLatencyRequirement {
        doc /* The system shall deliver high-priority actuator commands from coordinator to actuator node within 150 milliseconds under nominal network loading. */
        attribute maximumLatency : Millisecond = 150.0;
    }

    requirement def SecureAdmissionRequirement {
        doc /* The system shall admit nodes only after successful network authentication and assignment of a valid session key. */
        attribute requiredSecurityMode : SecurityMode = SecurityMode::sessionKey;
    }

    requirement def LowPowerEndpointRequirement {
        doc /* Battery-powered endpoint nodes shall support sleep operation between scheduled reporting or command receive windows. */
        attribute reportingInterval : Millisecond = 5000.0;
    }

    requirement def RouteRecoveryRequirement {
        doc /* The system shall attempt route repair after degraded link quality or repeated acknowledgement loss is detected. */
        attribute routeRepairTimeout : Millisecond = 500.0;
    }

    satisfy PrimaryFunctionRequirement by OneNetBasedSystem;
    satisfy ReliableDeliveryRequirement by OneNetBasedSystem::healthMonitor;
    satisfy CommandLatencyRequirement by OneNetBasedSystem::actuatorController;
    satisfy SecureAdmissionRequirement by OneNetBasedSystem::securityManager;
    satisfy LowPowerEndpointRequirement by OneNetBasedSystem::environmentalSensor;
    satisfy RouteRecoveryRequirement by OneNetBasedSystem::routingManager;

    constraint def DeliveryRatioConstraint {
        in measuredDeliveryRatio : Percent;
        in requiredDeliveryRatio : Percent;
        measuredDeliveryRatio >= requiredDeliveryRatio;
    }

    constraint def CommandLatencyConstraint {
        in measuredLatency : Millisecond;
        in maximumLatency : Millisecond;
        measuredLatency <= maximumLatency;
    }

    constraint def PayloadSizeConstraint {
        in payloadSize : ByteCount;
        in maximumPayloadSize : ByteCount;
        payloadSize <= maximumPayloadSize;
    }

    constraint def ChannelQualityConstraint {
        in channelQuality : Percent;
        in minimumChannelQuality : Percent;
        channelQuality >= minimumChannelQuality;
    }

    part oneNetInstallation : OneNetBasedSystem;

}