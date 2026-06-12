package ZWaveHomeAutomationSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Percentage :> ScalarValues::Real {
        unit = "%";
    }

    attribute def dBm :> ScalarValues::Real {
        unit = "dBm";
    }

    attribute def Hertz :> ScalarValues::Real {
        unit = "Hz";
    }

    attribute def Millisecond :> ScalarValues::Real {
        unit = "ms";
    }

    attribute def ByteCount :> ScalarValues::Integer {
        unit = "byte";
    }

    attribute def NodeIdentifier :> ScalarValues::Integer;
    attribute def NetworkHomeIdentifier :> ScalarValues::Integer;
    attribute def SecurityKey128 :> ScalarValues::String;

    enum def DeviceMode {
        enum off;
        enum standby;
        enum active;
        enum fault;
    }

    enum def CommandClass {
        enum basic;
        enum switchBinary;
        enum switchMultilevel;
        enum sensorMultilevel;
        enum notification;
        enum security2;
        enum supervision;
        enum association;
    }

    enum def FramePriority {
        enum normal;
        enum wakeup;
        enum alarm;
        enum networkManagement;
    }

    enum def InclusionState {
        enum excluded;
        enum listeningForInclusion;
        enum includedUnauthenticated;
        enum includedSecure;
    }

    item def ZWaveFrame {
        attribute homeId : NetworkHomeIdentifier;
        attribute sourceNodeId : NodeIdentifier;
        attribute destinationNodeId : NodeIdentifier;
        attribute commandClass : CommandClass;
        attribute priority : FramePriority;
        attribute encrypted : Boolean;
        attribute sequenceNumber : Integer;
        attribute payloadLength : ByteCount;
    }

    item def SensorReport {
        attribute sourceNodeId : NodeIdentifier;
        attribute measuredTemperature : TemperatureValue;
        attribute measuredIlluminance : IlluminanceValue;
        attribute motionDetected : Boolean;
        attribute batteryLevel : Percentage;
    }

    item def ControlCommand {
        attribute targetNodeId : NodeIdentifier;
        attribute requestedMode : DeviceMode;
        attribute dimLevel : Percentage;
        attribute supervisionRequired : Boolean;
    }

    attribute def TemperatureValue :> ScalarValues::Real {
        unit = "Cel";
    }

    attribute def IlluminanceValue :> ScalarValues::Real {
        unit = "lx";
    }

    port def ZWaveRadioPort {
        out item txFrame : ZWaveFrame;
        in item rxFrame : ZWaveFrame;
    }

    port def SensorDataPort {
        out item report : SensorReport;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def CloudApiPort {
        in item remoteCommand : ControlCommand;
        out item telemetry : SensorReport;
        out item networkStatus : ZWaveFrame;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute availableCurrent : ElectricCurrent;
    }

    part def ZWaveController {
        attribute homeId : NetworkHomeIdentifier;
        attribute controllerNodeId : NodeIdentifier = 1;
        attribute radioFrequency : Hertz = 908400000;
        attribute maxManagedNodes : Integer = 232;
        attribute securityKey : SecurityKey128;
        attribute mode : DeviceMode;

        port radio : ZWaveRadioPort;
        port cloud : CloudApiPort;
        port power : PowerPort;

        perform action routeCommand;
        perform action includeNode;
        perform action validateSecurity;
        perform action publishTelemetry;
    }

    part def ZWaveRepeater {
        attribute nodeId : NodeIdentifier;
        attribute homeId : NetworkHomeIdentifier;
        attribute receivedSignalStrength : dBm;
        attribute retransmissionDelay : Millisecond = 40;
        attribute mode : DeviceMode;

        port radio : ZWaveRadioPort;
        port power : PowerPort;

        perform action forwardFrame;
    }

    part def MotionTemperatureSensor {
        attribute nodeId : NodeIdentifier;
        attribute homeId : NetworkHomeIdentifier;
        attribute batteryLevel : Percentage;
        attribute wakeupInterval : Millisecond = 300000;
        attribute inclusion : InclusionState;
        attribute mode : DeviceMode;

        port radio : ZWaveRadioPort;
        port sensorOut : SensorDataPort;
        port power : PowerPort;

        perform action sampleEnvironment;
        perform action sendSensorReport;
    }

    part def SmartDimmerSwitch {
        attribute nodeId : NodeIdentifier;
        attribute homeId : NetworkHomeIdentifier;
        attribute dimLevel : Percentage;
        attribute loadPower : Power;
        attribute mode : DeviceMode;
        attribute inclusion : InclusionState;

        port radio : ZWaveRadioPort;
        port commandIn : CommandPort;
        port power : PowerPort;

        perform action applyDimLevel;
        perform action reportSwitchState;
    }

    part def DoorLock {
        attribute nodeId : NodeIdentifier;
        attribute homeId : NetworkHomeIdentifier;
        attribute locked : Boolean;
        attribute tamperDetected : Boolean;
        attribute batteryLevel : Percentage;
        attribute mode : DeviceMode;
        attribute inclusion : InclusionState;

        port radio : ZWaveRadioPort;
        port commandIn : CommandPort;
        port power : PowerPort;

        perform action lockDoor;
        perform action unlockDoor;
        perform action reportLockStatus;
    }

    part def HomeAutomationGateway {
        doc /* Primary high-level function: coordinate a secure Z-Wave mesh network so a user or automation rule can monitor home conditions and command connected devices such as lights and locks. */

        attribute homeId : NetworkHomeIdentifier = 43120577;
        attribute networkAvailability : Percentage;
        attribute averageCommandLatency : Millisecond;
        attribute encryptedTrafficRatio : Percentage;

        part controller : ZWaveController {
            attribute homeId = 43120577;
        }

        part repeaterHallway : ZWaveRepeater {
            attribute nodeId = 2;
            attribute homeId = 43120577;
        }

        part livingRoomSensor : MotionTemperatureSensor {
            attribute nodeId = 11;
            attribute homeId = 43120577;
            attribute batteryLevel = 86;
        }

        part entryDoorLock : DoorLock {
            attribute nodeId = 21;
            attribute homeId = 43120577;
            attribute batteryLevel = 74;
        }

        part kitchenDimmer : SmartDimmerSwitch {
            attribute nodeId = 31;
            attribute homeId = 43120577;
            attribute dimLevel = 0;
        }

        connect controller.radio to repeaterHallway.radio;
        connect repeaterHallway.radio to livingRoomSensor.radio;
        connect repeaterHallway.radio to entryDoorLock.radio;
        connect repeaterHallway.radio to kitchenDimmer.radio;

        perform action coordinateSecureMesh;
        perform action executeAutomationRule;
    }

    action def CoordinateSecureMesh {
        in item inboundFrame : ZWaveFrame;
        out item outboundFrame : ZWaveFrame;

        first start;
        then action authenticateFrame;
        then action chooseRoute;
        then action transmitFrame;
        then done;
    }

    action def ExecuteAutomationRule {
        in item sensorReport : SensorReport;
        out item lightingCommand : ControlCommand;
        out item lockCommand : ControlCommand;

        first start;
        then action evaluateMotionAndTime;
        then action createDeviceCommand;
        then action requestSupervision;
        then done;
    }

    action def IncludeNode {
        in attribute requestedNodeId : NodeIdentifier;
        in attribute secureRequested : Boolean;
        out attribute assignedNodeId : NodeIdentifier;
        out attribute resultingState : InclusionState;

        first start;
        then action assignNodeIdentifier;
        then action exchangeNetworkKeys;
        then action verifyCommandClasses;
        then done;
    }

    state def ControllerOperationalState {
        entry action initializeRadio;
        state offline;
        state idle;
        state includingNode;
        state routingCommand;
        state publishingTelemetry;
        state faulted;

        transition first offline
            then idle;

        transition idle
            accept includeRequest
            then includingNode;

        transition includingNode
            accept inclusionCompleted
            then idle;

        transition idle
            accept commandReceived
            then routingCommand;

        transition routingCommand
            accept supervisionReportReceived
            then idle;

        transition idle
            accept sensorReportReceived
            then publishingTelemetry;

        transition publishingTelemetry
            accept telemetryPublished
            then idle;

        transition idle
            accept radioFailure
            then faulted;

        transition faulted
            accept resetCompleted
            then idle;
    }

    state def BatterySensorState {
        entry action loadWakeupSchedule;
        state sleeping;
        state sampling;
        state transmittingReport;
        state lowBattery;
        state faulted;

        transition first sleeping;

        transition sleeping
            accept wakeupTimerExpired
            then sampling;

        transition sampling
            accept sampleCompleted
            then transmittingReport;

        transition transmittingReport
            accept acknowledgementReceived
            then sleeping;

        transition sampling
            accept batteryBelowTwentyPercent
            then lowBattery;

        transition lowBattery
            accept reportSent
            then sleeping;

        transition sleeping
            accept sensorSelfTestFailed
            then faulted;
    }

    state def ActuatorDeviceState {
        state excluded;
        state secureIncluded;
        state standby;
        state executingCommand;
        state reportingStatus;
        state faulted;

        transition first excluded;

        transition excluded
            accept secureInclusionCompleted
            then secureIncluded;

        transition secureIncluded
            accept configurationCompleted
            then standby;

        transition standby
            accept secureCommandReceived
            then executingCommand;

        transition executingCommand
            accept deviceActionCompleted
            then reportingStatus;

        transition reportingStatus
            accept supervisionReportSent
            then standby;

        transition standby
            accept tamperOrLoadFault
            then faulted;

        transition faulted
            accept localReset
            then standby;
    }

    requirement def SecureMeshControlRequirement {
        subject gateway : HomeAutomationGateway;

        doc /* The system shall provide secure, supervised command and telemetry exchange across a Z-Wave mesh network for residential automation devices. */

        require constraint {
            gateway.controller.radioFrequency == 908400000
        }
    }

    requirement def NodeCapacityRequirement {
        subject gateway : HomeAutomationGateway;

        doc /* The controller shall support a residential Z-Wave network containing up to 232 managed nodes. */

        require constraint {
            gateway.controller.maxManagedNodes >= 232
        }
    }

    requirement def CommandLatencyRequirement {
        subject gateway : HomeAutomationGateway;

        doc /* A supervised command routed through the mesh shall complete within 1000 ms under normal radio conditions. */

        require constraint {
            gateway.averageCommandLatency <= 1000
        }
    }

    requirement def SecurityRequirement {
        subject frame : ZWaveFrame;

        doc /* Commands that operate locks, lighting actuators, or network-management functions shall be encrypted before transmission. */

        require constraint {
            frame.encrypted == true
        }
    }

    requirement def AvailabilityRequirement {
        subject gateway : HomeAutomationGateway;

        doc /* The Z-Wave automation network shall maintain at least 99 percent local control availability while mains power is present. */

        require constraint {
            gateway.networkAvailability >= 99
        }
    }

    requirement def BatteryReportingRequirement {
        subject sensor : MotionTemperatureSensor;

        doc /* Battery-powered sensors shall report remaining battery level with each scheduled environmental report. */

        require constraint {
            sensor.batteryLevel >= 0 and sensor.batteryLevel <= 100
        }
    }

    requirement def DimmerRangeRequirement {
        subject dimmer : SmartDimmerSwitch;

        doc /* A controlled dimmer shall accept commanded brightness values from fully off through fully on. */

        require constraint {
            dimmer.dimLevel >= 0 and dimmer.dimLevel <= 100
        }
    }

    satisfy SecureMeshControlRequirement by HomeAutomationGateway;
    satisfy NodeCapacityRequirement by ZWaveController;
    satisfy CommandLatencyRequirement by HomeAutomationGateway;
    satisfy AvailabilityRequirement by HomeAutomationGateway;
    satisfy BatteryReportingRequirement by MotionTemperatureSensor;
    satisfy DimmerRangeRequirement by SmartDimmerSwitch;

}