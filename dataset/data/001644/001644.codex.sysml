package ClipsalCBusAutomationSystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Percent {
        :> ScalarValues::Real;
        unit = "%";
    }

    attribute def Volt {
        :> ScalarValues::Real;
        unit = "V";
    }

    attribute def Ampere {
        :> ScalarValues::Real;
        unit = "A";
    }

    attribute def Watt {
        :> ScalarValues::Real;
        unit = "W";
    }

    attribute def Lux {
        :> ScalarValues::Real;
        unit = "lx";
    }

    attribute def Second {
        :> ScalarValues::Real;
        unit = "s";
    }

    attribute def Celsius {
        :> ScalarValues::Real;
        unit = "degC";
    }

    attribute def BinaryState {
        :> ScalarValues::Boolean;
    }

    enum def LightingMode {
        enum off;
        enum manual;
        enum automatic;
        enum scene;
        enum fault;
    }

    enum def BusHealth {
        enum normal;
        enum degraded;
        enum failed;
    }

    item def CBusTelegram {
        attribute applicationAddress : ScalarValues::Integer;
        attribute groupAddress : ScalarValues::Integer;
        attribute commandCode : ScalarValues::Integer;
        attribute level : Percent;
        attribute sourceUnitAddress : ScalarValues::Integer;
        attribute checksumValid : BinaryState;
    }

    item def PowerFeed {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute availablePower : Watt;
    }

    item def LightLevelReport {
        attribute measuredIlluminance : Lux;
        attribute occupancyDetected : BinaryState;
        attribute reportedAt : Second;
    }

    item def LoadCommand {
        attribute targetLevel : Percent;
        attribute rampTime : Second;
        attribute priority : ScalarValues::Integer;
    }

    port def CBusPort {
        in item rx : CBusTelegram;
        out item tx : CBusTelegram;
        in item supply : PowerFeed;
    }

    port def LoadOutputPort {
        out item command : LoadCommand;
        out item supply : PowerFeed;
    }

    port def SensorReportPort {
        out item report : LightLevelReport;
    }

    port def MainsInputPort {
        in item feed : PowerFeed;
    }

    port def UserInterfacePort {
        out item userTelegram : CBusTelegram;
        in item statusTelegram : CBusTelegram;
    }

    action def DecodeCBusTelegram {
        in item incoming : CBusTelegram;
        out item command : LoadCommand;

        assert constraint {
            incoming.checksumValid == true
        }

        bind command.targetLevel = incoming.level;
        bind command.priority = 5;
    }

    action def ApplyLightingScene {
        in attribute sceneNumber : ScalarValues::Integer;
        out item loungeCommand : LoadCommand;
        out item kitchenCommand : LoadCommand;
        out item corridorCommand : LoadCommand;

        if sceneNumber == 1 then {
            bind loungeCommand.targetLevel = 80 [%];
            bind kitchenCommand.targetLevel = 70 [%];
            bind corridorCommand.targetLevel = 40 [%];
        } else if sceneNumber == 2 then {
            bind loungeCommand.targetLevel = 25 [%];
            bind kitchenCommand.targetLevel = 15 [%];
            bind corridorCommand.targetLevel = 10 [%];
        } else {
            bind loungeCommand.targetLevel = 0 [%];
            bind kitchenCommand.targetLevel = 0 [%];
            bind corridorCommand.targetLevel = 0 [%];
        }

        bind loungeCommand.rampTime = 2 [s];
        bind kitchenCommand.rampTime = 2 [s];
        bind corridorCommand.rampTime = 2 [s];
        bind loungeCommand.priority = 7;
        bind kitchenCommand.priority = 7;
        bind corridorCommand.priority = 7;
    }

    action def MaintainIlluminance {
        in item sensorReport : LightLevelReport;
        in attribute targetIlluminance : Lux;
        out item dimmerCommand : LoadCommand;

        if sensorReport.occupancyDetected == false then {
            bind dimmerCommand.targetLevel = 0 [%];
        } else if sensorReport.measuredIlluminance < targetIlluminance then {
            bind dimmerCommand.targetLevel = 85 [%];
        } else {
            bind dimmerCommand.targetLevel = 35 [%];
        }

        bind dimmerCommand.rampTime = 5 [s];
        bind dimmerCommand.priority = 4;
    }

    state def LightingControlStateMachine {
        attribute mode : LightingMode;
        attribute busStatus : BusHealth;

        entry action initialize {
            bind mode = LightingMode::automatic;
            bind busStatus = BusHealth::normal;
        }

        state operating;
        state manualControl;
        state automaticControl;
        state sceneControl;
        state faultHandling;

        initial then operating;

        transition operating_to_automatic
            first operating
            then automaticControl
            effect {
                bind mode = LightingMode::automatic;
            }

        transition automatic_to_manual
            first automaticControl
            accept CBusTelegram
            if payload.commandCode == 1
            then manualControl
            effect {
                bind mode = LightingMode::manual;
            }

        transition manual_to_scene
            first manualControl
            accept CBusTelegram
            if payload.commandCode == 3
            then sceneControl
            effect {
                bind mode = LightingMode::scene;
            }

        transition scene_to_automatic
            first sceneControl
            after 600 [s]
            then automaticControl
            effect {
                bind mode = LightingMode::automatic;
            }

        transition any_to_fault
            first operating
            accept CBusTelegram
            if payload.checksumValid == false
            then faultHandling
            effect {
                bind mode = LightingMode::fault;
                bind busStatus = BusHealth::degraded;
            }

        transition fault_to_operating
            first faultHandling
            accept CBusTelegram
            if payload.checksumValid == true
            then operating
            effect {
                bind busStatus = BusHealth::normal;
            }
    }

    part def CBusPowerSupply {
        attribute nominalVoltage : Volt = 36 [V];
        attribute maxCurrent : Ampere = 2 [A];
        attribute maxPower : Watt = 72 [W];

        port mains : MainsInputPort;
        port bus : CBusPort;
    }

    part def CBusNetworkBridge {
        attribute unitAddress : ScalarValues::Integer;
        attribute applicationAddress : ScalarValues::Integer = 56;
        attribute busVoltage : Volt;
        attribute health : BusHealth;

        port busA : CBusPort;
        port busB : CBusPort;
        port userInterface : UserInterfacePort;

        perform action decode : DecodeCBusTelegram;
    }

    part def WallSwitch {
        attribute unitAddress : ScalarValues::Integer;
        attribute selectedGroupAddress : ScalarValues::Integer;
        attribute lastPressedLevel : Percent;
        attribute debounceTime : Second = 0.05 [s];

        port bus : CBusPort;
        port user : UserInterfacePort;
    }

    part def OccupancyLightSensor {
        attribute unitAddress : ScalarValues::Integer;
        attribute measuredIlluminance : Lux;
        attribute occupied : BinaryState;
        attribute timeout : Second = 900 [s];
        attribute targetIlluminance : Lux = 450 [lx];

        port bus : CBusPort;
        port report : SensorReportPort;

        perform action maintain : MaintainIlluminance;
    }

    part def DimmerChannel {
        attribute channelNumber : ScalarValues::Integer;
        attribute ratedPower : Watt = 500 [W];
        attribute outputLevel : Percent;
        attribute minimumLevel : Percent = 5 [%];
        attribute maximumLevel : Percent = 100 [%];
        attribute thermalLimit : Celsius = 75 [degC];

        port bus : CBusPort;
        port load : LoadOutputPort;
    }

    part def RelayChannel {
        attribute channelNumber : ScalarValues::Integer;
        attribute ratedCurrent : Ampere = 10 [A];
        attribute energized : BinaryState;
        attribute outputLevel : Percent;

        port bus : CBusPort;
        port load : LoadOutputPort;
    }

    part def LightingLoad {
        attribute name : ScalarValues::String;
        attribute ratedPower : Watt;
        attribute commandedLevel : Percent;
        attribute actualLevel : Percent;
        attribute supplyVoltage : Volt = 230 [V];

        port loadInput : LoadOutputPort;
    }

    part def TouchScreenController {
        attribute unitAddress : ScalarValues::Integer;
        attribute activeScene : ScalarValues::Integer;
        attribute screenBrightness : Percent;
        attribute standbyTimeout : Second = 120 [s];

        port bus : CBusPort;
        port user : UserInterfacePort;

        perform action sceneAction : ApplyLightingScene;
    }

    part def ClipsalCBusLightingAutomation {
        doc /* 
         * High-level primary function:
         * The system provides distributed digital control of building lighting over a Clipsal C-Bus network.
         * It allows wall switches, touch screens, sensors, dimmers, relays, and lighting loads to exchange
         * addressed control telegrams so that occupants and automation logic can switch, dim, schedule,
         * and scene-control lights reliably from multiple locations.
         */

        attribute buildingSupplyVoltage : Volt = 230 [V];
        attribute cbusNominalVoltage : Volt = 36 [V];
        attribute targetWorkingIlluminance : Lux = 450 [lx];
        attribute normalBusHealth : BusHealth = BusHealth::normal;

        part powerSupply : CBusPowerSupply {
            attribute nominalVoltage = 36 [V];
            attribute maxCurrent = 2 [A];
        }

        part networkBridge : CBusNetworkBridge {
            attribute unitAddress = 1;
        }

        part entrySwitch : WallSwitch {
            attribute unitAddress = 10;
            attribute selectedGroupAddress = 101;
        }

        part loungeSwitch : WallSwitch {
            attribute unitAddress = 11;
            attribute selectedGroupAddress = 102;
        }

        part touchScreen : TouchScreenController {
            attribute unitAddress = 20;
            attribute activeScene = 1;
            attribute screenBrightness = 70 [%];
        }

        part loungeSensor : OccupancyLightSensor {
            attribute unitAddress = 30;
            attribute targetIlluminance = 450 [lx];
        }

        part kitchenSensor : OccupancyLightSensor {
            attribute unitAddress = 31;
            attribute targetIlluminance = 500 [lx];
        }

        part loungeDimmer : DimmerChannel {
            attribute channelNumber = 1;
            attribute ratedPower = 500 [W];
        }

        part kitchenDimmer : DimmerChannel {
            attribute channelNumber = 2;
            attribute ratedPower = 500 [W];
        }

        part corridorRelay : RelayChannel {
            attribute channelNumber = 3;
            attribute ratedCurrent = 10 [A];
        }

        part loungeLights : LightingLoad {
            attribute name = "Lounge LED downlights";
            attribute ratedPower = 180 [W];
        }

        part kitchenLights : LightingLoad {
            attribute name = "Kitchen task lights";
            attribute ratedPower = 240 [W];
        }

        part corridorLights : LightingLoad {
            attribute name = "Corridor luminaires";
            attribute ratedPower = 120 [W];
        }

        port mainsIn : MainsInputPort;

        connect mainsIn to powerSupply.mains;
        connect powerSupply.bus to networkBridge.busA;
        connect networkBridge.busB to entrySwitch.bus;
        connect networkBridge.busB to loungeSwitch.bus;
        connect networkBridge.busB to touchScreen.bus;
        connect networkBridge.busB to loungeSensor.bus;
        connect networkBridge.busB to kitchenSensor.bus;
        connect networkBridge.busB to loungeDimmer.bus;
        connect networkBridge.busB to kitchenDimmer.bus;
        connect networkBridge.busB to corridorRelay.bus;

        connect loungeDimmer.load to loungeLights.loadInput;
        connect kitchenDimmer.load to kitchenLights.loadInput;
        connect corridorRelay.load to corridorLights.loadInput;

        connect entrySwitch.user to networkBridge.userInterface;
        connect loungeSwitch.user to networkBridge.userInterface;
        connect touchScreen.user to networkBridge.userInterface;

        perform state control : LightingControlStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The C-Bus automation system shall provide distributed digital lighting control for building zones using C-Bus telegrams between user interfaces, sensors, controllers, output modules, and lighting loads. */
        subject system : ClipsalCBusLightingAutomation;
        require constraint {
            system.cbusNominalVoltage == 36 [V]
        }
    }

    requirement def MultiPointControlRequirement {
        doc /* A lighting group shall be controllable from more than one physical or graphical user interface without hard-wired switch loops to the load circuit. */
        subject system : ClipsalCBusLightingAutomation;
        require constraint {
            system.entrySwitch.selectedGroupAddress == 101 and
            system.loungeSwitch.selectedGroupAddress == 102
        }
    }

    requirement def SceneControlRequirement {
        doc /* The touch screen controller shall command predefined lighting scenes by sending addressed C-Bus telegrams to the dimmer and relay channels. */
        subject controller : TouchScreenController;
        require constraint {
            controller.activeScene >= 0
        }
    }

    requirement def SensorAutomationRequirement {
        doc /* Occupancy and illuminance sensors shall reduce lighting output when spaces are vacant and raise or maintain output when occupied illuminance is below target. */
        subject sensor : OccupancyLightSensor;
        require constraint {
            sensor.timeout >= 300 [s] and sensor.targetIlluminance >= 300 [lx]
        }
    }

    requirement def LoadProtectionRequirement {
        doc /* Output channels shall operate within their rated load capacity and thermal limits. */
        subject channel : DimmerChannel;
        require constraint {
            channel.ratedPower <= 500 [W] and
            channel.thermalLimit <= 75 [degC]
        }
    }

    requirement def BusPowerRequirement {
        doc /* The C-Bus power supply shall provide a regulated low-voltage bus feed suitable for distributed control units. */
        subject supply : CBusPowerSupply;
        require constraint {
            supply.nominalVoltage == 36 [V] and
            supply.maxPower >= 50 [W]
        }
    }

    satisfy PrimaryFunctionRequirement by ClipsalCBusLightingAutomation;
    satisfy MultiPointControlRequirement by ClipsalCBusLightingAutomation;
    satisfy SceneControlRequirement by TouchScreenController;
    satisfy SensorAutomationRequirement by OccupancyLightSensor;
    satisfy LoadProtectionRequirement by DimmerChannel;
    satisfy BusPowerRequirement by CBusPowerSupply;
}