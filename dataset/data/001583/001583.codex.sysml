package SmartRefrigeratorModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Celsius :> Real {
        unit = "degC";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Watt :> Real {
        unit = "W";
    }

    attribute def Liter :> Real {
        unit = "L";
    }

    attribute def Kilogram :> Real {
        unit = "kg";
    }

    attribute def Minute :> Real {
        unit = "min";
    }

    attribute def DateTime :> String;

    item def ElectricalPower {
        attribute voltage : Real;
        attribute current : Real;
        attribute frequency : Real;
    }

    item def CoolingAir {
        attribute temperature : Celsius;
        attribute humidity : Percent;
        attribute flowRate : Real;
    }

    item def FoodItem {
        attribute name : String;
        attribute mass : Kilogram;
        attribute targetStorageTemperature : Celsius;
        attribute expirationDate : DateTime;
        attribute barcode : String;
    }

    item def InventoryRecord {
        attribute itemName : String;
        attribute quantity : Integer;
        attribute expirationDate : DateTime;
        attribute compartmentId : String;
        attribute lastUpdated : DateTime;
    }

    item def TemperatureReading {
        attribute compartmentId : String;
        attribute temperature : Celsius;
        attribute timestamp : DateTime;
    }

    item def HumidityReading {
        attribute compartmentId : String;
        attribute humidity : Percent;
        attribute timestamp : DateTime;
    }

    item def DoorStatusSignal {
        attribute compartmentId : String;
        attribute open : Boolean;
        attribute timestamp : DateTime;
    }

    item def UserCommand {
        attribute commandId : String;
        attribute requestedMode : String;
        attribute targetCompartment : String;
        attribute targetTemperature : Celsius;
    }

    item def Notification {
        attribute severity : String;
        attribute message : String;
        attribute timestamp : DateTime;
    }

    item def CloudMessage {
        attribute topic : String;
        attribute payload : String;
        attribute timestamp : DateTime;
    }

    port def PowerInPort {
        in item power : ElectricalPower;
    }

    port def AirSupplyPort {
        out item air : CoolingAir;
    }

    port def AirReturnPort {
        in item air : CoolingAir;
    }

    port def SensorOutPort {
        out item temperature : TemperatureReading;
        out item humidity : HumidityReading;
        out item doorStatus : DoorStatusSignal;
    }

    port def ControlInPort {
        in item command : UserCommand;
    }

    port def ControlOutPort {
        out item command : UserCommand;
    }

    port def InventoryInPort {
        in item food : FoodItem;
    }

    port def InventoryOutPort {
        out item record : InventoryRecord;
    }

    port def NotificationPort {
        out item notification : Notification;
    }

    port def NetworkPort {
        in item inbound : CloudMessage;
        out item outbound : CloudMessage;
    }

    port def UserInterfacePort {
        in item command : UserCommand;
        out item notification : Notification;
        out item record : InventoryRecord;
    }

    part def Compressor {
        attribute ratedPower : Watt = 180.0;
        attribute operatingPower : Watt;
        attribute active : Boolean;
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
    }

    part def Condenser {
        attribute heatRejectionCapacity : Watt = 420.0;
        port airReturn : AirReturnPort;
        port airSupply : AirSupplyPort;
    }

    part def Evaporator {
        attribute coolingCapacity : Watt = 360.0;
        attribute coilTemperature : Celsius;
        port airReturn : AirReturnPort;
        port airSupply : AirSupplyPort;
    }

    part def Fan {
        attribute ratedPower : Watt = 18.0;
        attribute speedPercent : Percent;
        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port airReturn : AirReturnPort;
        port airSupply : AirSupplyPort;
    }

    part def TemperatureSensor {
        attribute accuracy : Celsius = 0.5;
        attribute measuredTemperature : Celsius;
        port sensorOut : SensorOutPort;
    }

    part def HumiditySensor {
        attribute accuracy : Percent = 3.0;
        attribute measuredHumidity : Percent;
        port sensorOut : SensorOutPort;
    }

    part def DoorSensor {
        attribute open : Boolean;
        port sensorOut : SensorOutPort;
    }

    part def BarcodeCamera {
        attribute resolutionMegapixels : Real = 8.0;
        attribute scanSuccessRate : Percent = 98.0;
        port inventoryIn : InventoryInPort;
        port inventoryOut : InventoryOutPort;
    }

    part def WeightShelf {
        attribute capacity : Kilogram = 25.0;
        attribute measuredMass : Kilogram;
        port inventoryIn : InventoryInPort;
        port inventoryOut : InventoryOutPort;
    }

    part def RefrigeratedCompartment {
        attribute compartmentId : String;
        attribute volume : Liter;
        attribute targetTemperature : Celsius;
        attribute maximumAllowedTemperature : Celsius;
        attribute currentTemperature : Celsius;
        attribute currentHumidity : Percent;

        port airSupply : AirSupplyPort;
        port airReturn : AirReturnPort;
        port sensorOut : SensorOutPort;
        port inventoryIn : InventoryInPort;
        port inventoryOut : InventoryOutPort;

        part temperatureSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part doorSensor : DoorSensor;
        part shelf[4] : WeightShelf;

        connect temperatureSensor.sensorOut to sensorOut;
        connect humiditySensor.sensorOut to sensorOut;
        connect doorSensor.sensorOut to sensorOut;
        connect shelf.inventoryIn to inventoryIn;
        connect shelf.inventoryOut to inventoryOut;
    }

    part def FreezerCompartment :> RefrigeratedCompartment {
        attribute compartmentId : String = "freezer";
        attribute volume : Liter = 110.0;
        attribute targetTemperature : Celsius = -18.0;
        attribute maximumAllowedTemperature : Celsius = -12.0;
    }

    part def FreshFoodCompartment :> RefrigeratedCompartment {
        attribute compartmentId : String = "fresh-food";
        attribute volume : Liter = 290.0;
        attribute targetTemperature : Celsius = 3.0;
        attribute maximumAllowedTemperature : Celsius = 7.0;
    }

    part def CoolingSubsystem {
        attribute coolingEnabled : Boolean;
        attribute defrostEnabled : Boolean;
        attribute totalPowerDraw : Watt;

        port powerIn : PowerInPort;
        port controlIn : ControlInPort;
        port freshAirSupply : AirSupplyPort;
        port freshAirReturn : AirReturnPort;
        port freezerAirSupply : AirSupplyPort;
        port freezerAirReturn : AirReturnPort;

        part compressor : Compressor;
        part condenser : Condenser;
        part evaporator : Evaporator;
        part freshFan : Fan;
        part freezerFan : Fan;

        connect powerIn to compressor.powerIn;
        connect powerIn to freshFan.powerIn;
        connect powerIn to freezerFan.powerIn;
        connect controlIn to compressor.controlIn;
        connect controlIn to freshFan.controlIn;
        connect controlIn to freezerFan.controlIn;
        connect freezerAirReturn to evaporator.airReturn;
        connect evaporator.airSupply to freezerFan.airReturn;
        connect freezerFan.airSupply to freezerAirSupply;
        connect freshAirReturn to condenser.airReturn;
        connect condenser.airSupply to freshFan.airReturn;
        connect freshFan.airSupply to freshAirSupply;
    }

    part def InventorySubsystem {
        attribute knownItemCount : Integer;
        attribute expiredItemCount : Integer;
        attribute missingItemCount : Integer;

        port foodInput : InventoryInPort;
        port sensorInput : InventoryOutPort;
        port uiOutput : InventoryOutPort;
        port notificationOut : NotificationPort;

        part scanner : BarcodeCamera;

        connect foodInput to scanner.inventoryIn;
        connect scanner.inventoryOut to sensorInput;
        connect sensorInput to uiOutput;
    }

    part def ConnectivitySubsystem {
        attribute wifiConnected : Boolean;
        attribute cloudSyncInterval : Minute = 15.0;
        attribute lastSyncTime : DateTime;

        port network : NetworkPort;
        port notificationOut : NotificationPort;
        port inventoryOut : InventoryOutPort;
        port commandOut : ControlOutPort;
    }

    part def UserInterfaceSubsystem {
        attribute displayBrightness : Percent = 75.0;
        attribute childLockEnabled : Boolean;

        port touchDisplay : UserInterfacePort;
        port commandOut : ControlOutPort;
        port notificationIn : NotificationPort;
        port inventoryIn : InventoryOutPort;

        connect touchDisplay.command to commandOut.command;
        connect notificationIn.notification to touchDisplay.notification;
        connect inventoryIn.record to touchDisplay.record;
    }

    part def ControlSubsystem {
        attribute operatingMode : String;
        attribute freshFoodSetpoint : Celsius = 3.0;
        attribute freezerSetpoint : Celsius = -18.0;
        attribute energySavingEnabled : Boolean;
        attribute alarmEnabled : Boolean = true;

        port sensorInput : SensorOutPort;
        port userCommandInput : ControlInPort;
        port cloudCommandInput : ControlInPort;
        port coolingCommandOutput : ControlOutPort;
        port notificationOut : NotificationPort;
    }

    action def RegulateTemperature {
        in attribute freshTemperature : Celsius;
        in attribute freezerTemperature : Celsius;
        in attribute freshSetpoint : Celsius;
        in attribute freezerSetpoint : Celsius;
        out attribute compressorOn : Boolean;
        out attribute freshFanSpeed : Percent;
        out attribute freezerFanSpeed : Percent;

        first start;
        then evaluateFreshCompartment;
        then evaluateFreezerCompartment;
        then issueCoolingCommand;
        then done;

        action evaluateFreshCompartment;
        action evaluateFreezerCompartment;
        action issueCoolingCommand;
    }

    action def UpdateInventory {
        in item scannedFood : FoodItem;
        in attribute measuredMass : Kilogram;
        out item record : InventoryRecord;

        first identifyItem;
        then estimateQuantity;
        then assignCompartment;
        then storeInventoryRecord;
        then done;

        action identifyItem;
        action estimateQuantity;
        action assignCompartment;
        action storeInventoryRecord;
    }

    action def NotifyUser {
        in item notification : Notification;
        out item displayedNotification : Notification;
        out item cloudNotification : CloudMessage;

        first classifyNotification;
        then routeNotification;
        then done;

        action classifyNotification;
        action routeNotification;
    }

    state def RefrigeratorOperatingState {
        entry action initializeControlLoops;

        state Off;
        state Startup;
        state NormalCooling;
        state EnergySaving;
        state DoorOpenAlarm;
        state Defrost;
        state Fault;

        transition first Off then Startup
            accept UserCommand
            if command.requestedMode == "power-on";

        transition Startup then NormalCooling
            if true;

        transition NormalCooling then EnergySaving
            accept UserCommand
            if command.requestedMode == "energy-saving";

        transition EnergySaving then NormalCooling
            accept UserCommand
            if command.requestedMode == "normal";

        transition NormalCooling then DoorOpenAlarm
            accept DoorStatusSignal
            if doorStatus.open == true;

        transition DoorOpenAlarm then NormalCooling
            accept DoorStatusSignal
            if doorStatus.open == false;

        transition NormalCooling then Defrost
            accept UserCommand
            if command.requestedMode == "defrost";

        transition Defrost then NormalCooling
            if true;

        transition NormalCooling then Fault
            accept TemperatureReading
            if temperature.temperature > 12.0;

        transition EnergySaving then Fault
            accept TemperatureReading
            if temperature.temperature > 12.0;

        transition Fault then NormalCooling
            accept UserCommand
            if command.requestedMode == "fault-cleared";

        transition NormalCooling then Off
            accept UserCommand
            if command.requestedMode == "power-off";
    }

    part def SmartRefrigerator {
        attribute primaryFunction : String =
            "Preserve stored food by automatically maintaining safe compartment temperatures while tracking inventory and notifying users of storage, door, and expiration conditions.";

        attribute totalUsableVolume : Liter = 400.0;
        attribute annualEnergyUse : Real = 520.0;
        attribute ratedVoltage : Real = 120.0;
        attribute maximumPowerDraw : Watt = 650.0;

        port mainsPower : PowerInPort;
        port userInterface : UserInterfacePort;
        port cloudNetwork : NetworkPort;
        port groceryInput : InventoryInPort;
        port userNotifications : NotificationPort;

        part freshFood : FreshFoodCompartment;
        part freezer : FreezerCompartment;
        part cooling : CoolingSubsystem;
        part control : ControlSubsystem;
        part inventory : InventorySubsystem;
        part connectivity : ConnectivitySubsystem;
        part ui : UserInterfaceSubsystem;

        perform regulateTemperature : RegulateTemperature;
        perform updateInventory : UpdateInventory;
        perform notifyUser : NotifyUser;

        exhibit state behavior operatingState : RefrigeratorOperatingState;

        connect mainsPower to cooling.powerIn;

        connect cooling.freshAirSupply to freshFood.airSupply;
        connect freshFood.airReturn to cooling.freshAirReturn;
        connect cooling.freezerAirSupply to freezer.airSupply;
        connect freezer.airReturn to cooling.freezerAirReturn;

        connect freshFood.sensorOut to control.sensorInput;
        connect freezer.sensorOut to control.sensorInput;

        connect control.coolingCommandOutput to cooling.controlIn;
        connect ui.commandOut to control.userCommandInput;
        connect connectivity.commandOut to control.cloudCommandInput;

        connect groceryInput to inventory.foodInput;
        connect freshFood.inventoryOut to inventory.sensorInput;
        connect freezer.inventoryOut to inventory.sensorInput;
        connect inventory.uiOutput to ui.inventoryIn;
        connect inventory.uiOutput to connectivity.inventoryOut;

        connect userInterface to ui.touchDisplay;
        connect cloudNetwork to connectivity.network;

        connect control.notificationOut to ui.notificationIn;
        connect inventory.notificationOut to ui.notificationIn;
        connect connectivity.notificationOut to ui.notificationIn;
        connect control.notificationOut to userNotifications;
        connect inventory.notificationOut to userNotifications;
    }

    requirement def PreserveFoodRequirement {
        subject fridge : SmartRefrigerator;

        require constraint {
            fridge.freshFood.currentTemperature <= fridge.freshFood.maximumAllowedTemperature
            and fridge.freezer.currentTemperature <= fridge.freezer.maximumAllowedTemperature
        }

        doc /* The smart refrigerator shall preserve food by maintaining the fresh-food and freezer compartments within safe temperature limits during normal operation. */
    }

    requirement def TemperatureControlRequirement {
        subject fridge : SmartRefrigerator;

        require constraint {
            fridge.control.freshFoodSetpoint >= 1.0
            and fridge.control.freshFoodSetpoint <= 5.0
            and fridge.control.freezerSetpoint >= -22.0
            and fridge.control.freezerSetpoint <= -15.0
        }

        doc /* The system shall regulate each compartment around a user-configurable setpoint appropriate for refrigerated and frozen food storage. */
    }

    requirement def DoorAlarmRequirement {
        subject fridge : SmartRefrigerator;

        require constraint {
            fridge.control.alarmEnabled == true
        }

        doc /* The system shall notify the user when a compartment door remains open long enough to threaten food preservation or waste energy. */
    }

    requirement def InventoryTrackingRequirement {
        subject fridge : SmartRefrigerator;

        require constraint {
            fridge.inventory.knownItemCount >= 0
            and fridge.inventory.expiredItemCount >= 0
        }

        doc /* The system shall maintain an inventory of detected food items, quantities, storage locations, and expiration dates. */
    }

    requirement def RemoteMonitoringRequirement {
        subject fridge : SmartRefrigerator;

        require constraint {
            fridge.connectivity.cloudSyncInterval <= 30.0
        }

        doc /* The system shall synchronize temperature, inventory, and notification data with a cloud service for remote monitoring. */
    }

    requirement def EnergyEfficiencyRequirement {
        subject fridge : SmartRefrigerator;

        require constraint {
            fridge.maximumPowerDraw <= 700.0
        }

        doc /* The system shall limit peak electrical power draw while preserving required cooling performance. */
    }

    satisfy PreserveFoodRequirement by SmartRefrigerator;
    satisfy TemperatureControlRequirement by ControlSubsystem;
    satisfy DoorAlarmRequirement by ControlSubsystem;
    satisfy InventoryTrackingRequirement by InventorySubsystem;
    satisfy RemoteMonitoringRequirement by ConnectivitySubsystem;
    satisfy EnergyEfficiencyRequirement by CoolingSubsystem;

}