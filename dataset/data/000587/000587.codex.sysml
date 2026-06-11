package DonPackSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Mass :> Real { unit = "kg"; }
    attribute def Volume :> Real { unit = "L"; }
    attribute def Power :> Real { unit = "W"; }
    attribute def Energy :> Real { unit = "Wh"; }
    attribute def Voltage :> Real { unit = "V"; }
    attribute def Current :> Real { unit = "A"; }
    attribute def Temperature :> Real { unit = "degC"; }
    attribute def TimeDuration :> Real { unit = "min"; }
    attribute def Length :> Real { unit = "m"; }
    attribute def Force :> Real { unit = "N"; }

    item def StoredItem {
        attribute itemMass : Mass;
        attribute itemVolume : Volume;
    }

    item def FoodRation :> StoredItem {
        attribute calories : Real;
        attribute shelfLifeDays : Real;
    }

    item def WaterSupply :> StoredItem {
        attribute potableVolume : Volume;
    }

    item def MedicalSupply :> StoredItem {
        attribute sterile : Boolean;
        attribute expirationDays : Real;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute availableEnergy : Energy;
    }

    item def LocationData {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute accuracy : Length;
    }

    item def StatusMessage {
        attribute packMass : Mass;
        attribute batteryEnergy : Energy;
        attribute internalTemperature : Temperature;
        attribute emergencyMode : Boolean;
    }

    port def StoragePort {
        in item inputItem : StoredItem;
        out item outputItem : StoredItem;
    }

    port def PowerPort {
        inout item energy : ElectricalEnergy;
    }

    port def DataPort {
        inout item message : StatusMessage;
    }

    port def LocationPort {
        out item position : LocationData;
    }

    part def DonPack {
        attribute primaryFunction : String = "Carry, protect, monitor, and rapidly provide essential supplies for one person during field movement or emergency response.";
        attribute maxGrossMass : Mass = 18.0;
        attribute emptyMass : Mass = 3.2;
        attribute usableVolume : Volume = 32.0;
        attribute waterCapacity : Volume = 3.0;
        attribute batteryCapacity : Energy = 120.0;
        attribute operatingTemperatureMin : Temperature = -20.0;
        attribute operatingTemperatureMax : Temperature = 50.0;

        port mainStoragePort : StoragePort;
        port externalPowerPort : PowerPort;
        port statusPort : DataPort;
        port gpsPort : LocationPort;

        part frame : LoadBearingFrame;
        part cargoModule : CargoModule;
        part hydrationModule : HydrationModule;
        part medicalModule : MedicalModule;
        part powerModule : PowerModule;
        part navigationModule : NavigationModule;
        part environmentalController : EnvironmentalController;
        part shoulderHarness : Harness;
        part waistBelt : Harness;
        part controller : PackController;

        connection frameToCargo connect frame.mountPort to cargoModule.mountPort;
        connection frameToHarness connect frame.upperLoadPort to shoulderHarness.loadPort;
        connection frameToBelt connect frame.lowerLoadPort to waistBelt.loadPort;
        connection cargoToStorage connect mainStoragePort to cargoModule.storagePort;
        connection hydrationToCargo connect hydrationModule.storagePort to cargoModule.storagePort;
        connection medicalToCargo connect medicalModule.storagePort to cargoModule.storagePort;
        connection powerToController connect powerModule.lowVoltagePort to controller.powerPort;
        connection powerToExternal connect powerModule.chargePort to externalPowerPort;
        connection controllerToStatus connect controller.statusPort to statusPort;
        connection navigationToController connect navigationModule.locationPort to controller.locationPort;
        connection navigationToGps connect navigationModule.locationPort to gpsPort;
        connection controllerToEnvironment connect controller.controlPort to environmentalController.controlPort;

        perform action monitorPack;
        exhibit state packOperationalStates;
    }

    part def LoadBearingFrame {
        attribute mass : Mass = 0.9;
        attribute ratedLoad : Force = 300.0;
        attribute torsoLength : Length = 0.52;

        port mountPort : StoragePort;
        port upperLoadPort : StoragePort;
        port lowerLoadPort : StoragePort;
    }

    part def Harness {
        attribute mass : Mass = 0.45;
        attribute adjustmentRange : Length = 0.18;
        attribute padded : Boolean = true;

        port loadPort : StoragePort;
    }

    part def CargoModule {
        attribute dryVolume : Volume = 24.0;
        attribute maxCargoMass : Mass = 10.0;
        attribute waterResistanceRating : String = "IP54";

        port storagePort : StoragePort;

        part food : FoodRation {
            attribute itemMass = 1.2;
            attribute itemVolume = 2.0;
            attribute calories = 3600.0;
            attribute shelfLifeDays = 730.0;
        }

        part blanket : StoredItem {
            attribute itemMass = 0.6;
            attribute itemVolume = 1.8;
        }

        part toolKit : StoredItem {
            attribute itemMass = 1.4;
            attribute itemVolume = 2.5;
        }
    }

    part def HydrationModule {
        attribute reservoirMass : Mass = 0.35;
        attribute capacity : Volume = 3.0;
        attribute flowRate : Real = 0.7;

        port storagePort : StoragePort;

        part water : WaterSupply {
            attribute itemMass = 3.0;
            attribute itemVolume = 3.0;
            attribute potableVolume = 3.0;
        }
    }

    part def MedicalModule {
        attribute sealed : Boolean = true;
        attribute moduleMass : Mass = 0.8;
        attribute moduleVolume : Volume = 2.2;

        port storagePort : StoragePort;

        part bandageSet : MedicalSupply {
            attribute itemMass = 0.15;
            attribute itemVolume = 0.25;
            attribute sterile = true;
            attribute expirationDays = 1095.0;
        }

        part antisepticKit : MedicalSupply {
            attribute itemMass = 0.2;
            attribute itemVolume = 0.3;
            attribute sterile = true;
            attribute expirationDays = 730.0;
        }

        part splint : MedicalSupply {
            attribute itemMass = 0.25;
            attribute itemVolume = 0.8;
            attribute sterile = false;
            attribute expirationDays = 1825.0;
        }
    }

    part def PowerModule {
        attribute batteryEnergy : Energy = 120.0;
        attribute nominalVoltage : Voltage = 12.0;
        attribute maxOutputPower : Power = 45.0;
        attribute rechargeTime : TimeDuration = 180.0;

        port chargePort : PowerPort;
        port lowVoltagePort : PowerPort;

        part battery : BatteryPack;
        part solarCharger : SolarCharger;

        connection batteryToCharger connect battery.chargePort to solarCharger.outputPort;
        connection batteryToOutput connect battery.outputPort to lowVoltagePort;
    }

    part def BatteryPack {
        attribute storedEnergy : Energy = 120.0;
        attribute voltage : Voltage = 12.0;
        attribute maxCurrent : Current = 4.0;

        port chargePort : PowerPort;
        port outputPort : PowerPort;
    }

    part def SolarCharger {
        attribute peakPower : Power = 20.0;
        attribute foldedArea : Real = 0.04;
        attribute deployedArea : Real = 0.35;

        port outputPort : PowerPort;
    }

    part def NavigationModule {
        attribute mass : Mass = 0.18;
        attribute updatePeriod : TimeDuration = 1.0;

        port locationPort : LocationPort;
    }

    part def EnvironmentalController {
        attribute insulationRating : Real = 0.65;
        attribute maxInternalTemperature : Temperature = 40.0;
        attribute minInternalTemperature : Temperature = -5.0;

        port controlPort : DataPort;
    }

    part def PackController {
        attribute samplingPeriod : TimeDuration = 0.5;
        attribute emergencyMode : Boolean = false;

        port powerPort : PowerPort;
        port statusPort : DataPort;
        port locationPort : LocationPort;
        port controlPort : DataPort;
    }

    action def MonitorPackStatus {
        in packMass : Mass;
        in batteryEnergy : Energy;
        in internalTemperature : Temperature;
        out status : StatusMessage;

        first start;
        then evaluateMass;
        then evaluateEnergy;
        then evaluateTemperature;
        then publishStatus;
    }

    action def ProvideEmergencyAccess {
        in requestEmergencyMode : Boolean;
        out medicalAvailable : Boolean;
        out foodAvailable : Boolean;
        out waterAvailable : Boolean;

        first receiveRequest;
        then releaseMedicalModule;
        then exposeHydrationTube;
        then markRationsForAccess;
        then confirmAvailable;
    }

    action def RechargeFromSolar {
        in sunlightAvailable : Boolean;
        in batteryEnergy : Energy;
        out rechargedEnergy : Energy;

        first checkSunlight;
        then deploySolarPanel;
        then regulateCharge;
        then stowSolarPanel;
    }

    state def DonPackOperationalStates {
        entry action initializeController;

        state Packed;
        state Carried;
        state Monitoring;
        state EmergencyAccess;
        state Recharging;
        state MaintenanceRequired;

        transition initial then Packed;

        transition Packed_to_Carried
            first Packed
            accept userDonsPack
            then Carried;

        transition Carried_to_Monitoring
            first Carried
            accept controllerPowered
            then Monitoring;

        transition Monitoring_to_EmergencyAccess
            first Monitoring
            accept emergencyRequest
            then EmergencyAccess;

        transition Monitoring_to_Recharging
            first Monitoring
            accept solarPanelDeployed
            then Recharging;

        transition Recharging_to_Monitoring
            first Recharging
            accept batterySufficient
            then Monitoring;

        transition Monitoring_to_MaintenanceRequired
            first Monitoring
            accept faultDetected
            then MaintenanceRequired;

        transition EmergencyAccess_to_Monitoring
            first EmergencyAccess
            accept emergencyAccessClosed
            then Monitoring;
    }

    requirement def CarryEssentialSupplies {
        doc /* The Don Pack shall carry food, water, medical supplies, tools, and thermal protection for one person. */
        attribute requiredUsableVolume : Volume = 30.0;
        attribute requiredWaterCapacity : Volume = 3.0;
    }

    requirement def LimitWearableMass {
        doc /* The Don Pack shall not exceed a gross carried mass that prevents practical human wear during field movement. */
        attribute maximumAllowedGrossMass : Mass = 18.0;
    }

    requirement def ProvideStatusAwareness {
        doc /* The Don Pack shall provide pack status including mass estimate, battery level, temperature, and emergency mode state. */
        attribute maximumStatusLatency : TimeDuration = 2.0;
    }

    requirement def SupportEmergencyAccess {
        doc /* The Don Pack shall allow rapid access to water, medical supplies, and food during emergency use. */
        attribute maximumAccessTime : TimeDuration = 1.0;
    }

    requirement def OperateInFieldEnvironment {
        doc /* The Don Pack shall operate across expected outdoor field temperatures while protecting stored supplies. */
        attribute minimumOperatingTemperature : Temperature = -20.0;
        attribute maximumOperatingTemperature : Temperature = 50.0;
    }

    satisfy CarryEssentialSupplies by DonPack::cargoModule;
    satisfy CarryEssentialSupplies by DonPack::hydrationModule;
    satisfy CarryEssentialSupplies by DonPack::medicalModule;
    satisfy LimitWearableMass by DonPack;
    satisfy ProvideStatusAwareness by DonPack::controller;
    satisfy SupportEmergencyAccess by ProvideEmergencyAccess;
    satisfy OperateInFieldEnvironment by DonPack::environmentalController;

    part donPackSystem : DonPack {
        perform monitorPack : MonitorPackStatus;
        exhibit packOperationalStates : DonPackOperationalStates;
    }
}