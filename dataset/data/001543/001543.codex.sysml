package RefrigeratorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Celsius :> Real {
        unit = "degC";
    }

    attribute def Watt :> Real {
        unit = "W";
    }

    attribute def KilowattHour :> Real {
        unit = "kW*h";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    attribute def Pascal :> Real {
        unit = "Pa";
    }

    attribute def Liter :> Real {
        unit = "L";
    }

    attribute def Second :> Real {
        unit = "s";
    }

    item def ElectricalPower {
        attribute voltage : Real;
        attribute frequency : Real;
        attribute availablePower : Watt;
    }

    item def ThermalEnergy {
        attribute heatFlowRate : Watt;
        attribute sourceTemperature : Celsius;
        attribute sinkTemperature : Celsius;
    }

    item def Refrigerant {
        attribute pressure : Pascal;
        attribute temperature : Celsius;
        attribute massFlowRate : Real;
        attribute phase : RefrigerantPhase;
    }

    enum def RefrigerantPhase {
        enum vapor;
        enum liquid;
        enum twoPhase;
    }

    item def Air {
        attribute temperature : Celsius;
        attribute relativeHumidity : Percent;
        attribute circulationFlowRate : Real;
    }

    item def FoodLoad {
        attribute mass : Real;
        attribute initialTemperature : Celsius;
        attribute targetTemperature : Celsius;
    }

    item def UserCommand {
        attribute targetFreshFoodTemperature : Celsius;
        attribute targetFreezerTemperature : Celsius;
        attribute energySavingMode : Boolean;
        attribute rapidCoolMode : Boolean;
    }

    item def DoorStatus {
        attribute open : Boolean;
        attribute openDuration : Second;
    }

    port def ElectricalInlet {
        in item power : ElectricalPower;
    }

    port def HeatPort {
        inout item heat : ThermalEnergy;
    }

    port def RefrigerantPort {
        inout item fluid : Refrigerant;
    }

    port def AirPort {
        inout item air : Air;
    }

    port def CommandPort {
        in item command : UserCommand;
    }

    port def StatusPort {
        out item doorStatus : DoorStatus;
    }

    part def Refrigerator {
        attribute freshFoodSetpoint : Celsius = 3.0;
        attribute freezerSetpoint : Celsius = -18.0;
        attribute maxFreshFoodTemperature : Celsius = 5.0;
        attribute maxFreezerTemperature : Celsius = -15.0;
        attribute usableVolume : Liter = 520.0;
        attribute ratedPower : Watt = 180.0;
        attribute dailyEnergyConsumption : KilowattHour = 1.2;

        port electricalSupply : ElectricalInlet;
        port userInput : CommandPort;
        port roomHeatExchange : HeatPort;
        port statusOutput : StatusPort;

        part cabinet : InsulatedCabinet;
        part freshFoodCompartment : FreshFoodCompartment;
        part freezerCompartment : FreezerCompartment;
        part refrigerationLoop : VaporCompressionCoolingLoop;
        part controller : TemperatureController;
        part userInterface : UserInterface;
        part doorAssembly : DoorAssembly;
        part defrostSystem : DefrostSystem;

        connect electricalSupply to controller.powerInput;
        connect electricalSupply to refrigerationLoop.powerInput;
        connect electricalSupply to defrostSystem.powerInput;
        connect userInput to userInterface.commandInput;
        connect userInterface.commandOutput to controller.commandInput;
        connect controller.compressorControl to refrigerationLoop.compressor.controlInput;
        connect controller.fanControl to freshFoodCompartment.circulationFan.controlInput;
        connect controller.defrostControl to defrostSystem.controlInput;
        connect doorAssembly.statusOutput to controller.doorStatusInput;
        connect doorAssembly.statusOutput to statusOutput;
        connect freshFoodCompartment.airSensor.sensorOutput to controller.freshFoodTemperatureInput;
        connect freezerCompartment.airSensor.sensorOutput to controller.freezerTemperatureInput;
        connect refrigerationLoop.evaporator.coldSide to freezerCompartment.coolingInterface;
        connect freezerCompartment.transferDuct to freshFoodCompartment.coldAirInlet;
        connect freshFoodCompartment.returnDuct to freezerCompartment.returnAirInlet;
        connect refrigerationLoop.condenser.hotSide to roomHeatExchange;
        connect cabinet.ambientInterface to roomHeatExchange;

        perform action maintainPreservedFoodEnvironment : MaintainPreservedFoodEnvironment;
        exhibit state refrigeratorOperatingState : RefrigeratorOperatingState;
    }

    part def InsulatedCabinet {
        attribute insulationThermalResistance : Real = 2.8;
        attribute ambientTemperatureAssumption : Celsius = 25.0;

        port ambientInterface : HeatPort;
        port interiorInterface : HeatPort;
    }

    part def FreshFoodCompartment {
        attribute nominalVolume : Liter = 360.0;
        attribute targetTemperature : Celsius = 3.0;
        attribute allowableTemperatureLow : Celsius = 0.0;
        attribute allowableTemperatureHigh : Celsius = 5.0;

        port coolingInterface : HeatPort;
        port coldAirInlet : AirPort;
        port returnDuct : AirPort;

        part circulationFan : VariableSpeedFan;
        part airSensor : TemperatureSensor;
        part shelfZoneUpper : StorageZone {
            attribute zoneVolume : Liter = 120.0;
            attribute nominalTemperature : Celsius = 4.0;
        }
        part shelfZoneLower : StorageZone {
            attribute zoneVolume : Liter = 140.0;
            attribute nominalTemperature : Celsius = 3.0;
        }
        part crisperDrawer : StorageZone {
            attribute zoneVolume : Liter = 60.0;
            attribute nominalTemperature : Celsius = 5.0;
        }
        part doorBins : StorageZone {
            attribute zoneVolume : Liter = 40.0;
            attribute nominalTemperature : Celsius = 5.0;
        }
    }

    part def FreezerCompartment {
        attribute nominalVolume : Liter = 160.0;
        attribute targetTemperature : Celsius = -18.0;
        attribute allowableTemperatureHigh : Celsius = -15.0;

        port coolingInterface : HeatPort;
        port transferDuct : AirPort;
        port returnAirInlet : AirPort;

        part airSensor : TemperatureSensor;
        part freezerFan : VariableSpeedFan;
        part storageBasketUpper : StorageZone {
            attribute zoneVolume : Liter = 80.0;
            attribute nominalTemperature : Celsius = -18.0;
        }
        part storageBasketLower : StorageZone {
            attribute zoneVolume : Liter = 80.0;
            attribute nominalTemperature : Celsius = -18.0;
        }
    }

    part def StorageZone {
        attribute zoneVolume : Liter;
        attribute nominalTemperature : Celsius;
        attribute foodLoadCapacity : Real = 25.0;
    }

    part def VaporCompressionCoolingLoop {
        attribute refrigerantChargeMass : Real = 0.09;
        attribute coolingCapacity : Watt = 450.0;
        attribute coefficientOfPerformance : Real = 1.8;

        port powerInput : ElectricalInlet;

        part compressor : Compressor;
        part condenser : Condenser;
        part expansionValve : ExpansionValve;
        part evaporator : Evaporator;

        connect compressor.discharge to condenser.inlet;
        connect condenser.outlet to expansionValve.inlet;
        connect expansionValve.outlet to evaporator.inlet;
        connect evaporator.outlet to compressor.suction;
    }

    part def Compressor {
        attribute ratedElectricalPower : Watt = 150.0;
        attribute speedCommand : Percent;

        port suction : RefrigerantPort;
        port discharge : RefrigerantPort;
        port controlInput : CommandPort;

        perform action compressRefrigerant : CompressRefrigerant;
    }

    part def Condenser {
        attribute heatRejectionCapacity : Watt = 600.0;

        port inlet : RefrigerantPort;
        port outlet : RefrigerantPort;
        port hotSide : HeatPort;

        perform action rejectHeatToRoom : RejectHeatToRoom;
    }

    part def ExpansionValve {
        attribute nominalPressureDrop : Pascal = 850000.0;

        port inlet : RefrigerantPort;
        port outlet : RefrigerantPort;

        perform action meterRefrigerant : MeterRefrigerant;
    }

    part def Evaporator {
        attribute heatAbsorptionCapacity : Watt = 450.0;

        port inlet : RefrigerantPort;
        port outlet : RefrigerantPort;
        port coldSide : HeatPort;

        perform action absorbHeatFromCompartments : AbsorbHeatFromCompartments;
    }

    part def VariableSpeedFan {
        attribute commandedSpeed : Percent = 0.0;
        attribute maximumPower : Watt = 12.0;

        port controlInput : CommandPort;
        port airInlet : AirPort;
        port airOutlet : AirPort;

        perform action circulateAir : CirculateAir;
    }

    part def TemperatureSensor {
        attribute measuredTemperature : Celsius;
        attribute accuracy : Celsius = 0.5;
        port sensorOutput : StatusPort;
    }

    part def DoorAssembly {
        attribute freshFoodDoorOpen : Boolean = false;
        attribute freezerDoorOpen : Boolean = false;
        attribute gasketLeakageRate : Real = 0.0;

        port statusOutput : StatusPort;

        part freshFoodDoor : Door;
        part freezerDoor : Door;
    }

    part def Door {
        attribute open : Boolean = false;
        attribute sealIntegrity : Percent = 98.0;
        attribute openAlarmThreshold : Second = 60.0;
    }

    part def UserInterface {
        port commandInput : CommandPort;
        port commandOutput : CommandPort;

        attribute displayedFreshFoodTemperature : Celsius;
        attribute displayedFreezerTemperature : Celsius;
        attribute alarmActive : Boolean = false;
    }

    part def TemperatureController {
        attribute freshFoodTemperature : Celsius;
        attribute freezerTemperature : Celsius;
        attribute compressorEnabled : Boolean = false;
        attribute fanEnabled : Boolean = false;
        attribute defrostEnabled : Boolean = false;

        port powerInput : ElectricalInlet;
        port commandInput : CommandPort;
        port doorStatusInput : StatusPort;
        port freshFoodTemperatureInput : StatusPort;
        port freezerTemperatureInput : StatusPort;
        port compressorControl : CommandPort;
        port fanControl : CommandPort;
        port defrostControl : CommandPort;

        perform action regulateTemperature : RegulateTemperature;
        exhibit state controllerState : ControllerState;
    }

    part def DefrostSystem {
        attribute heaterPower : Watt = 120.0;
        attribute maximumDefrostDuration : Second = 900.0;

        port powerInput : ElectricalInlet;
        port controlInput : CommandPort;
        port evaporatorHeatPort : HeatPort;

        perform action removeEvaporatorFrost : RemoveEvaporatorFrost;
    }

    action def MaintainPreservedFoodEnvironment {
        in item foodLoad : FoodLoad;
        in item electricalPower : ElectricalPower;
        out item rejectedHeat : ThermalEnergy;

        first start;
        then senseCompartmentTemperatures;
        then compareTemperaturesToSetpoints;
        then operateCoolingLoop;
        then circulateConditionedAir;
        then rejectExtractedHeat;
        then maintainSafeStorageTemperature;
    }

    action def RegulateTemperature {
        in attribute measuredFreshFoodTemperature : Celsius;
        in attribute measuredFreezerTemperature : Celsius;
        in attribute freshFoodSetpoint : Celsius;
        in attribute freezerSetpoint : Celsius;
        out attribute compressorCommand : Boolean;
        out attribute fanCommand : Boolean;

        first evaluateFreshFoodError;
        then evaluateFreezerError;
        then selectCoolingDemand;
        then issueCompressorAndFanCommands;
    }

    action def CompressRefrigerant {
        in item lowPressureVapor : Refrigerant;
        out item highPressureVapor : Refrigerant;
    }

    action def RejectHeatToRoom {
        in item hotRefrigerant : Refrigerant;
        out item cooledRefrigerant : Refrigerant;
        out item heatToRoom : ThermalEnergy;
    }

    action def MeterRefrigerant {
        in item highPressureLiquid : Refrigerant;
        out item lowPressureTwoPhaseRefrigerant : Refrigerant;
    }

    action def AbsorbHeatFromCompartments {
        in item compartmentHeat : ThermalEnergy;
        out item warmedRefrigerant : Refrigerant;
    }

    action def CirculateAir {
        in item returnAir : Air;
        out item suppliedAir : Air;
    }

    action def RemoveEvaporatorFrost {
        in attribute frostDetected : Boolean;
        out attribute defrostComplete : Boolean;
    }

    state def RefrigeratorOperatingState {
        entry action initializeController;
        state Off;
        state Standby;
        state Cooling;
        state RapidCooling;
        state Defrosting;
        state DoorOpenAlarm;
        state Fault;

        transition first Off then Standby
            if electricalPowerAvailable;

        transition Standby then Cooling
            if freezerTemperature > freezerSetpoint + 2.0 or freshFoodTemperature > freshFoodSetpoint + 1.0;

        transition Cooling then Standby
            if freezerTemperature <= freezerSetpoint and freshFoodTemperature <= freshFoodSetpoint;

        transition Standby then RapidCooling
            if rapidCoolModeRequested;

        transition RapidCooling then Standby
            if rapidCoolComplete;

        transition Cooling then Defrosting
            if scheduledDefrostDue and compressorRuntimeExceeded;

        transition Defrosting then Standby
            if evaporatorFrostRemoved or defrostDurationExceeded;

        transition Standby then DoorOpenAlarm
            if anyDoorOpenDuration > 60.0;

        transition Cooling then DoorOpenAlarm
            if anyDoorOpenDuration > 60.0;

        transition DoorOpenAlarm then Standby
            if allDoorsClosed;

        transition Standby then Fault
            if sensorFailureDetected or compressorOvercurrentDetected;

        transition Cooling then Fault
            if sensorFailureDetected or compressorOvercurrentDetected;

        transition Fault then Standby
            if faultCleared;
    }

    state def ControllerState {
        state Monitoring;
        state DemandCooling;
        state EnergySaving;
        state AlarmHandling;

        transition first Monitoring then DemandCooling
            if coolingDemandPresent;

        transition DemandCooling then Monitoring
            if coolingDemandSatisfied;

        transition Monitoring then EnergySaving
            if energySavingModeEnabled and doorClosed;

        transition EnergySaving then DemandCooling
            if freezerTemperature > freezerSetpoint + 3.0;

        transition Monitoring then AlarmHandling
            if doorOpenTooLong or temperatureOutOfRange;

        transition AlarmHandling then Monitoring
            if alarmConditionCleared;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The refrigerator shall preserve perishable food by removing heat from insulated storage compartments and maintaining controlled low temperatures using an electrically powered vapor-compression refrigeration cycle. */
    }

    requirement def FreshFoodTemperatureRequirement {
        subject refrigerator : Refrigerator;
        attribute requiredMaximumTemperature : Celsius = 5.0;
        require constraint {
            refrigerator.freshFoodCompartment.targetTemperature <= requiredMaximumTemperature
        }
    }

    requirement def FreezerTemperatureRequirement {
        subject refrigerator : Refrigerator;
        attribute requiredMaximumTemperature : Celsius = -15.0;
        require constraint {
            refrigerator.freezerCompartment.targetTemperature <= requiredMaximumTemperature
        }
    }

    requirement def EnergyConsumptionRequirement {
        subject refrigerator : Refrigerator;
        attribute maximumDailyEnergyConsumption : KilowattHour = 1.5;
        require constraint {
            refrigerator.dailyEnergyConsumption <= maximumDailyEnergyConsumption
        }
    }

    requirement def StorageVolumeRequirement {
        subject refrigerator : Refrigerator;
        attribute minimumUsableVolume : Liter = 500.0;
        require constraint {
            refrigerator.usableVolume >= minimumUsableVolume
        }
    }

    requirement def DoorAlarmRequirement {
        subject refrigerator : Refrigerator;
        attribute maximumUnalarmedOpenDuration : Second = 60.0;
        require constraint {
            refrigerator.doorAssembly.freshFoodDoor.openAlarmThreshold <= maximumUnalarmedOpenDuration and
            refrigerator.doorAssembly.freezerDoor.openAlarmThreshold <= maximumUnalarmedOpenDuration
        }
    }

    requirement def ElectricalSafetyRequirement {
        subject refrigerator : Refrigerator;
        attribute maximumRatedPower : Watt = 250.0;
        require constraint {
            refrigerator.ratedPower <= maximumRatedPower
        }
    }

    satisfy PrimaryFunctionRequirement by Refrigerator::maintainPreservedFoodEnvironment;
    satisfy FreshFoodTemperatureRequirement by Refrigerator::freshFoodCompartment;
    satisfy FreezerTemperatureRequirement by Refrigerator::freezerCompartment;
    satisfy EnergyConsumptionRequirement by Refrigerator;
    satisfy StorageVolumeRequirement by Refrigerator;
    satisfy DoorAlarmRequirement by Refrigerator::doorAssembly;
    satisfy ElectricalSafetyRequirement by Refrigerator;

    part refrigeratorSystem : Refrigerator {
        attribute freshFoodSetpoint = 3.0;
        attribute freezerSetpoint = -18.0;
        attribute usableVolume = 520.0;
        attribute ratedPower = 180.0;
        attribute dailyEnergyConsumption = 1.2;
    }
}