package KNXBuildingAutomationSystem {
    import ScalarValues::*;
    import SI::*;

    attribute def Voltage :> ScalarValues::Real {
        unit = "V";
    }

    attribute def Current :> ScalarValues::Real {
        unit = "A";
    }

    attribute def Power :> ScalarValues::Real {
        unit = "W";
    }

    attribute def Temperature :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def Illuminance :> ScalarValues::Real {
        unit = "lx";
    }

    attribute def Percent :> ScalarValues::Real {
        unit = "%";
    }

    attribute def TimeDuration :> ScalarValues::Real {
        unit = "s";
    }

    attribute def KNXAddress :> ScalarValues::String;
    attribute def DeviceIdentifier :> ScalarValues::String;

    enum def TelegramPriority {
        enum normal;
        enum urgent;
        enum system;
    }

    enum def TelegramService {
        enum groupValueRead;
        enum groupValueResponse;
        enum groupValueWrite;
        enum physicalAddressWrite;
        enum deviceDescriptorRead;
        enum restart;
    }

    item def KNXTelegram {
        attribute sourceAddress : KNXAddress;
        attribute destinationAddress : KNXAddress;
        attribute service : TelegramService;
        attribute priority : TelegramPriority;
        attribute payloadLength : ScalarValues::Integer;
        attribute payloadValue : ScalarValues::String;
        attribute checksumValid : ScalarValues::Boolean;
    }

    item def BinaryCommand {
        attribute targetAddress : KNXAddress;
        attribute commandValue : ScalarValues::Boolean;
    }

    item def DimmerCommand {
        attribute targetAddress : KNXAddress;
        attribute level : Percent;
    }

    item def BlindCommand {
        attribute targetAddress : KNXAddress;
        attribute position : Percent;
        attribute slatAngle : Percent;
    }

    item def TemperatureSetpoint {
        attribute zoneAddress : KNXAddress;
        attribute requestedTemperature : Temperature;
    }

    item def SensorMeasurement {
        attribute sourceAddress : KNXAddress;
        attribute measuredTemperature : Temperature;
        attribute measuredIlluminance : Illuminance;
        attribute occupancyDetected : ScalarValues::Boolean;
    }

    port def KNXBusPort {
        in item inboundTelegram : KNXTelegram;
        out item outboundTelegram : KNXTelegram;
        attribute nominalBusVoltage : Voltage = 30.0;
        attribute maximumBusCurrent : Current;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute availableCurrent : Current;
    }

    port def SwitchInputPort {
        out item switchCommand : BinaryCommand;
    }

    port def SensorOutputPort {
        out item measurement : SensorMeasurement;
    }

    port def LoadOutputPort {
        in item binaryCommand : BinaryCommand;
        in item dimmerCommand : DimmerCommand;
    }

    port def BlindOutputPort {
        in item blindCommand : BlindCommand;
    }

    part def KNXDevice {
        attribute physicalAddress : KNXAddress;
        attribute deviceId : DeviceIdentifier;
        attribute applicationLoaded : ScalarValues::Boolean;
        attribute operatingVoltage : Voltage;
        port bus : KNXBusPort;
        port power : PowerPort;
    }

    part def KNXPowerSupply :> KNXDevice {
        attribute outputVoltage : Voltage = 30.0;
        attribute ratedCurrent : Current = 0.64;
        attribute ratedPower : Power = 19.2;
        attribute overloadTripCurrent : Current = 0.80;

        port busOutput : KNXBusPort;

        state def PowerSupplyStateMachine {
            state off;
            state starting;
            state regulating;
            state overload;
            state fault;

            initial then off;

            transition off_to_starting
                first off
                then starting;

            transition starting_to_regulating
                first starting
                then regulating;

            transition regulating_to_overload
                first regulating
                then overload;

            transition overload_to_regulating
                first overload
                then regulating;

            transition any_to_fault
                first regulating
                then fault;
        }
    }

    part def KNXTwistedPairBus {
        attribute nominalVoltage : Voltage = 30.0;
        attribute maximumSegmentLength : ScalarValues::Real = 1000.0 {
            unit = "m";
        }
        attribute maximumDevicesPerSegment : ScalarValues::Integer = 64;
        attribute telegramBitRate : ScalarValues::Real = 9600.0 {
            unit = "bit/s";
        }

        port linePower : PowerPort;
        port devicePort[1..64] : KNXBusPort;

        action def BroadcastTelegram {
            in item telegram : KNXTelegram;
            out item deliveredTelegram : KNXTelegram;

            first start;
            then validateChecksum;
            then arbitratePriority;
            then deliverToGroupAddress;
            then done;

            action validateChecksum;
            action arbitratePriority;
            action deliverToGroupAddress;
        }
    }

    part def AreaCoupler :> KNXDevice {
        attribute mainLineAddress : KNXAddress;
        attribute subLineAddress : KNXAddress;
        attribute filterTableEntries : ScalarValues::Integer;

        port mainLine : KNXBusPort;
        port subLine : KNXBusPort;

        action def RouteTelegram {
            in item receivedTelegram : KNXTelegram;
            out item forwardedTelegram : KNXTelegram;

            first start;
            then checkAddressDomain;
            then applyFilterTable;
            then forwardWhenPermitted;
            then done;

            action checkAddressDomain;
            action applyFilterTable;
            action forwardWhenPermitted;
        }
    }

    part def WallSwitchSensor :> KNXDevice {
        attribute buttonCount : ScalarValues::Integer = 4;
        attribute debounceTime : TimeDuration = 0.030;
        attribute lightingGroupAddress : KNXAddress;
        attribute blindGroupAddress : KNXAddress;

        port switchOutput : SwitchInputPort;

        state def SwitchBehavior {
            state idle;
            state pressed;
            state longPressed;
            state released;

            initial then idle;

            transition idle_to_pressed
                first idle
                then pressed;

            transition pressed_to_released
                first pressed
                then released;

            transition pressed_to_longPressed
                first pressed
                then longPressed;

            transition released_to_idle
                first released
                then idle;
        }

        action def CreateLightingCommand {
            in attribute pressedButton : ScalarValues::Integer;
            out item command : BinaryCommand;

            first start;
            then mapButtonToGroupAddress;
            then encodeBooleanCommand;
            then sendTelegram;
            then done;

            action mapButtonToGroupAddress;
            action encodeBooleanCommand;
            action sendTelegram;
        }
    }

    part def RoomSensor :> KNXDevice {
        attribute reportingPeriod : TimeDuration = 60.0;
        attribute temperatureAccuracy : Temperature = 0.3;
        attribute illuminanceAccuracy : Illuminance = 25.0;
        attribute occupancyTimeout : TimeDuration = 900.0;

        port sensorOutput : SensorOutputPort;

        action def PublishMeasurement {
            out item measurement : SensorMeasurement;

            first start;
            then sampleTemperature;
            then sampleIlluminance;
            then evaluateOccupancy;
            then encodeTelegram;
            then done;

            action sampleTemperature;
            action sampleIlluminance;
            action evaluateOccupancy;
            action encodeTelegram;
        }
    }

    part def LightingActuator :> KNXDevice {
        attribute channelCount : ScalarValues::Integer = 8;
        attribute ratedChannelCurrent : Current = 10.0;
        attribute lightingGroupAddress : KNXAddress;
        attribute presentLoadPower : Power;

        port loadOutput[1..8] : LoadOutputPort;

        state def LightingActuatorStateMachine {
            state offline;
            state ready;
            state channelOn;
            state channelOff;
            state channelFault;

            initial then offline;

            transition offline_to_ready
                first offline
                then ready;

            transition ready_to_channelOn
                first ready
                then channelOn;

            transition ready_to_channelOff
                first ready
                then channelOff;

            transition channelOn_to_channelOff
                first channelOn
                then channelOff;

            transition channelOff_to_channelOn
                first channelOff
                then channelOn;

            transition ready_to_fault
                first ready
                then channelFault;
        }

        action def ApplyLightingCommand {
            in item command : BinaryCommand;

            first start;
            then verifyDestinationAddress;
            then selectOutputChannel;
            then switchRelay;
            then reportStatus;
            then done;

            action verifyDestinationAddress;
            action selectOutputChannel;
            action switchRelay;
            action reportStatus;
        }
    }

    part def DimmingActuator :> KNXDevice {
        attribute channelCount : ScalarValues::Integer = 4;
        attribute minimumLevel : Percent = 1.0;
        attribute maximumLevel : Percent = 100.0;
        attribute rampTime : TimeDuration = 2.0;
        attribute dimmingGroupAddress : KNXAddress;

        port dimmedLoadOutput[1..4] : LoadOutputPort;

        action def ApplyDimmingCommand {
            in item command : DimmerCommand;

            first start;
            then validateLevelRange;
            then computeRampProfile;
            then updateOutputPower;
            then publishLevelFeedback;
            then done;

            action validateLevelRange;
            action computeRampProfile;
            action updateOutputPower;
            action publishLevelFeedback;
        }
    }

    part def BlindActuator :> KNXDevice {
        attribute channelCount : ScalarValues::Integer = 4;
        attribute travelTimeUp : TimeDuration = 45.0;
        attribute travelTimeDown : TimeDuration = 42.0;
        attribute blindGroupAddress : KNXAddress;

        port blindOutput[1..4] : BlindOutputPort;

        state def BlindChannelStateMachine {
            state stopped;
            state movingUp;
            state movingDown;
            state calibrating;
            state obstructed;

            initial then stopped;

            transition stopped_to_movingUp
                first stopped
                then movingUp;

            transition stopped_to_movingDown
                first stopped
                then movingDown;

            transition movingUp_to_stopped
                first movingUp
                then stopped;

            transition movingDown_to_stopped
                first movingDown
                then stopped;

            transition stopped_to_calibrating
                first stopped
                then calibrating;

            transition movingDown_to_obstructed
                first movingDown
                then obstructed;
        }

        action def ApplyBlindCommand {
            in item command : BlindCommand;

            first start;
            then verifyDestinationAddress;
            then calculateTravelDuration;
            then energizeMotorDirection;
            then stopAtRequestedPosition;
            then publishPositionFeedback;
            then done;

            action verifyDestinationAddress;
            action calculateTravelDuration;
            action energizeMotorDirection;
            action stopAtRequestedPosition;
            action publishPositionFeedback;
        }
    }

    part def RoomController :> KNXDevice {
        attribute zoneGroupAddress : KNXAddress;
        attribute heatingSetpoint : Temperature = 21.0;
        attribute coolingSetpoint : Temperature = 24.0;
        attribute occupiedLightingLevel : Percent = 70.0;
        attribute unoccupiedLightingLevel : Percent = 0.0;

        port roomBus : KNXBusPort;

        action def CoordinateRoomAutomation {
            in item measurement : SensorMeasurement;
            out item lightingCommand : DimmerCommand;
            out item temperatureSetpoint : TemperatureSetpoint;
            out item blindCommand : BlindCommand;

            first start;
            then evaluateOccupancyMode;
            then regulateLightingLevel;
            then regulateThermalSetpoint;
            then optimizeDaylightWithBlinds;
            then transmitGroupCommands;
            then done;

            action evaluateOccupancyMode;
            action regulateLightingLevel;
            action regulateThermalSetpoint;
            action optimizeDaylightWithBlinds;
            action transmitGroupCommands;
        }
    }

    part def KNXBuildingAutomationController {
        attribute systemName : ScalarValues::String = "KNX-based Building Automation System";
        attribute primaryFunction : ScalarValues::String =
            "Provide distributed, interoperable monitoring and control of building functions by exchanging KNX telegrams among sensors, actuators, controllers, and power infrastructure over a shared bus.";

        part powerSupply : KNXPowerSupply {
            physicalAddress = "1.1.0";
            deviceId = "PSU-640mA-MainLine";
            applicationLoaded = true;
            operatingVoltage = 230.0;
        }

        part mainBus : KNXTwistedPairBus;

        part lineCoupler : AreaCoupler {
            physicalAddress = "1.1.1";
            deviceId = "LC-OfficeLine";
            applicationLoaded = true;
            operatingVoltage = 30.0;
            mainLineAddress = "1.0";
            subLineAddress = "1.1";
            filterTableEntries = 128;
        }

        part wallSwitch : WallSwitchSensor {
            physicalAddress = "1.1.10";
            deviceId = "SW-OfficeEntry";
            applicationLoaded = true;
            operatingVoltage = 30.0;
            lightingGroupAddress = "0/0/1";
            blindGroupAddress = "0/1/1";
        }

        part roomSensor : RoomSensor {
            physicalAddress = "1.1.11";
            deviceId = "SNS-OfficePresenceTempLux";
            applicationLoaded = true;
            operatingVoltage = 30.0;
        }

        part roomController : RoomController {
            physicalAddress = "1.1.20";
            deviceId = "CTRL-OfficeRoomLogic";
            applicationLoaded = true;
            operatingVoltage = 30.0;
            zoneGroupAddress = "2/0/1";
        }

        part lightingActuator : LightingActuator {
            physicalAddress = "1.1.30";
            deviceId = "ACT-LightRelay8";
            applicationLoaded = true;
            operatingVoltage = 30.0;
            lightingGroupAddress = "0/0/1";
            presentLoadPower = 320.0;
        }

        part dimmingActuator : DimmingActuator {
            physicalAddress = "1.1.31";
            deviceId = "ACT-Dimmer4";
            applicationLoaded = true;
            operatingVoltage = 30.0;
            dimmingGroupAddress = "0/0/2";
        }

        part blindActuator : BlindActuator {
            physicalAddress = "1.1.40";
            deviceId = "ACT-Blind4";
            applicationLoaded = true;
            operatingVoltage = 30.0;
            blindGroupAddress = "0/1/1";
        }

        connect powerSupply.busOutput to mainBus.devicePort;
        connect lineCoupler.subLine to mainBus.devicePort;
        connect wallSwitch.bus to mainBus.devicePort;
        connect roomSensor.bus to mainBus.devicePort;
        connect roomController.roomBus to mainBus.devicePort;
        connect lightingActuator.bus to mainBus.devicePort;
        connect dimmingActuator.bus to mainBus.devicePort;
        connect blindActuator.bus to mainBus.devicePort;

        connect wallSwitch.switchOutput to lightingActuator.loadOutput;
        connect roomSensor.sensorOutput to roomController.roomBus;
        connect roomController.roomBus to dimmingActuator.bus;
        connect roomController.roomBus to blindActuator.bus;

        action def OperateBuildingAutomation {
            first start;
            then energizeKNXBus;
            then initializeDevices;
            then receiveSensorAndSwitchEvents;
            then exchangeGroupTelegrams;
            then commandActuators;
            then monitorFeedback;
            then continueOperation;

            action energizeKNXBus;
            action initializeDevices;
            action receiveSensorAndSwitchEvents;
            action exchangeGroupTelegrams;
            action commandActuators;
            action monitorFeedback;
            action continueOperation;
        }

        state def SystemOperatingStateMachine {
            state deenergized;
            state commissioning;
            state normalOperation;
            state degradedOperation;
            state maintenance;
            state emergencyShutdown;

            initial then deenergized;

            transition deenergized_to_commissioning
                first deenergized
                then commissioning;

            transition commissioning_to_normalOperation
                first commissioning
                then normalOperation;

            transition normalOperation_to_degradedOperation
                first normalOperation
                then degradedOperation;

            transition degradedOperation_to_normalOperation
                first degradedOperation
                then normalOperation;

            transition normalOperation_to_maintenance
                first normalOperation
                then maintenance;

            transition maintenance_to_normalOperation
                first maintenance
                then normalOperation;

            transition normalOperation_to_emergencyShutdown
                first normalOperation
                then emergencyShutdown;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : KNXBuildingAutomationController;

        require constraint {
            system.primaryFunction ==
            "Provide distributed, interoperable monitoring and control of building functions by exchanging KNX telegrams among sensors, actuators, controllers, and power infrastructure over a shared bus."
        }
    }

    requirement def BusPowerRequirement {
        subject supply : KNXPowerSupply;

        require constraint {
            supply.outputVoltage >= 21.0 and supply.outputVoltage <= 30.0
        }
    }

    requirement def DeviceAddressingRequirement {
        subject device : KNXDevice;

        require constraint {
            device.physicalAddress != ""
        }
    }

    requirement def TelegramIntegrityRequirement {
        subject telegram : KNXTelegram;

        require constraint {
            telegram.checksumValid == true
        }
    }

    requirement def SegmentCapacityRequirement {
        subject bus : KNXTwistedPairBus;

        require constraint {
            bus.maximumDevicesPerSegment <= 64
        }
    }

    requirement def LightingControlRequirement {
        subject actuator : LightingActuator;

        require constraint {
            actuator.channelCount >= 1 and actuator.ratedChannelCurrent >= 6.0
        }
    }

    requirement def RoomComfortRequirement {
        subject controller : RoomController;

        require constraint {
            controller.heatingSetpoint >= 18.0 and
            controller.heatingSetpoint <= 23.0 and
            controller.coolingSetpoint >= 22.0 and
            controller.coolingSetpoint <= 27.0
        }
    }

    requirement def OccupancyEnergySavingRequirement {
        subject controller : RoomController;

        require constraint {
            controller.unoccupiedLightingLevel <= 10.0
        }
    }

    satisfy PrimaryFunctionRequirement by KNXBuildingAutomationController;
    satisfy BusPowerRequirement by KNXPowerSupply;
    satisfy SegmentCapacityRequirement by KNXTwistedPairBus;
    satisfy LightingControlRequirement by LightingActuator;
    satisfy RoomComfortRequirement by RoomController;
    satisfy OccupancyEnergySavingRequirement by RoomController;
}