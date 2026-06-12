package HomeSystemModel {
    import ScalarValues::*;
    import ISQ::*;

    attribute def Temperature {
        :> scalarValues::Real;
        unit = "degC";
    }

    attribute def RelativeHumidity {
        :> scalarValues::Real;
        unit = "%";
    }

    attribute def ElectricPower {
        :> scalarValues::Real;
        unit = "W";
    }

    attribute def Energy {
        :> scalarValues::Real;
        unit = "kWh";
    }

    attribute def WaterFlowRate {
        :> scalarValues::Real;
        unit = "L/min";
    }

    attribute def Illuminance {
        :> scalarValues::Real;
        unit = "lux";
    }

    attribute def AirQualityIndex {
        :> scalarValues::Integer;
        unit = "AQI";
    }

    attribute def SecurityLevel {
        :> scalarValues::Integer;
    }

    item def Electricity {
        attribute voltage : Real = 120.0;
        attribute frequency : Real = 60.0;
        attribute power : ElectricPower;
    }

    item def PotableWater {
        attribute flowRate : WaterFlowRate;
        attribute pressure : Real;
        attribute temperature : Temperature;
    }

    item def ConditionedAir {
        attribute temperature : Temperature;
        attribute humidity : RelativeHumidity;
        attribute airQuality : AirQualityIndex;
    }

    item def Occupant {
        attribute comfortTemperatureMin : Temperature = 20.0;
        attribute comfortTemperatureMax : Temperature = 24.0;
        attribute requiredSecurityLevel : SecurityLevel = 3;
    }

    item def SecurityAlert {
        attribute severity : SecurityLevel;
        attribute message : String;
    }

    port def ElectricPowerPort {
        in item suppliedElectricity : Electricity;
        out item consumedElectricity : Electricity;
    }

    port def WaterPort {
        in item suppliedWater : PotableWater;
        out item usedWater : PotableWater;
    }

    port def AirPort {
        out item deliveredAir : ConditionedAir;
        in item returnAir : ConditionedAir;
    }

    port def OccupantAccessPort {
        in item resident : Occupant;
        out item entryAuthorization : Boolean;
    }

    port def SecurityNotificationPort {
        out item alert : SecurityAlert;
    }

    port def ControlSignalPort {
        in item command : String;
        out item status : String;
    }

    part def Home {
        attribute indoorTemperature : Temperature;
        attribute indoorHumidity : RelativeHumidity;
        attribute indoorAirQuality : AirQualityIndex;
        attribute totalEnergyUsed : Energy;
        attribute occupied : Boolean;
        attribute secure : Boolean;

        port gridConnection : ElectricPowerPort;
        port waterService : WaterPort;
        port entryAccess : OccupantAccessPort;
        port securityNotifications : SecurityNotificationPort;
        port homeControl : ControlSignalPort;

        part envelope : BuildingEnvelope;
        part livingSpace : LivingSpace;
        part utilityCore : UtilityCore;
        part climateSystem : ClimateControlSystem;
        part lightingSystem : LightingSystem;
        part waterSystem : DomesticWaterSystem;
        part securitySystem : SecuritySystem;
        part energyManagementSystem : EnergyManagementSystem;
        part controller : HomeController;

        connect gridConnection to energyManagementSystem.utilityPower;
        connect energyManagementSystem.conditionedPower to utilityCore.electricalInput;
        connect utilityCore.hvacPower to climateSystem.powerInput;
        connect utilityCore.lightingPower to lightingSystem.powerInput;
        connect utilityCore.waterPower to waterSystem.powerInput;
        connect utilityCore.securityPower to securitySystem.powerInput;
        connect utilityCore.controllerPower to controller.powerInput;

        connect waterService to waterSystem.waterSupply;
        connect climateSystem.conditionedAirOutput to livingSpace.airExchange;
        connect lightingSystem.lightOutput to livingSpace.lightInput;
        connect securitySystem.accessInterface to entryAccess;
        connect securitySystem.notificationOutput to securityNotifications;
        connect controller.controlInterface to homeControl;

        connect controller.climateCommand to climateSystem.controlInput;
        connect controller.lightingCommand to lightingSystem.controlInput;
        connect controller.waterCommand to waterSystem.controlInput;
        connect controller.securityCommand to securitySystem.controlInput;
        connect energyManagementSystem.energyStatus to controller.energyInput;

        perform action provideHabitableShelter;
        exhibit state homeOperationalState;
    }

    part def BuildingEnvelope {
        attribute thermalResistance : Real = 4.2;
        attribute weatherTight : Boolean = true;
        attribute exteriorDoorCount : Integer = 3;
        attribute windowCount : Integer = 18;
    }

    part def LivingSpace {
        attribute floorArea : Real = 185.0;
        attribute roomCount : Integer = 8;
        attribute currentOccupants : Integer;
        attribute averageIlluminance : Illuminance;
        attribute airTemperature : Temperature;
        attribute airHumidity : RelativeHumidity;

        port airExchange : AirPort;
        port lightInput : LightPort;
    }

    port def LightPort {
        in item luminousOutput : LightEnergy;
    }

    item def LightEnergy {
        attribute illuminance : Illuminance;
        attribute powerUsed : ElectricPower;
    }

    part def UtilityCore {
        port electricalInput : ElectricPowerPort;
        port hvacPower : ElectricPowerPort;
        port lightingPower : ElectricPowerPort;
        port waterPower : ElectricPowerPort;
        port securityPower : ElectricPowerPort;
        port controllerPower : ElectricPowerPort;
    }

    part def ClimateControlSystem {
        attribute heatingCapacity : ElectricPower = 8500.0;
        attribute coolingCapacity : ElectricPower = 6200.0;
        attribute targetTemperature : Temperature = 22.0;
        attribute targetHumidity : RelativeHumidity = 45.0;

        port powerInput : ElectricPowerPort;
        port conditionedAirOutput : AirPort;
        port controlInput : ControlSignalPort;

        part furnace : Heater;
        part heatPump : Cooler;
        part ventilationFan : VentilationFan;
        part airFilter : AirFilter;

        perform action regulateIndoorClimate;
        exhibit state climateState;
    }

    part def Heater {
        attribute maxHeatPower : ElectricPower = 8500.0;
        attribute active : Boolean;
    }

    part def Cooler {
        attribute maxCoolingPower : ElectricPower = 6200.0;
        attribute active : Boolean;
    }

    part def VentilationFan {
        attribute airflowRate : Real = 450.0;
        attribute active : Boolean;
    }

    part def AirFilter {
        attribute minimumEfficiencyReportingValue : Integer = 13;
        attribute remainingLifePercent : Real;
    }

    part def LightingSystem {
        attribute installedFixtureCount : Integer = 34;
        attribute targetIlluminance : Illuminance = 300.0;
        attribute exteriorLightingEnabled : Boolean;

        port powerInput : ElectricPowerPort;
        port lightOutput : LightPort;
        port controlInput : ControlSignalPort;

        perform action illuminateOccupiedSpaces;
    }

    part def DomesticWaterSystem {
        attribute hotWaterTemperature : Temperature = 49.0;
        attribute storageVolume : Real = 190.0;
        attribute leakDetected : Boolean = false;

        port powerInput : ElectricPowerPort;
        port waterSupply : WaterPort;
        port controlInput : ControlSignalPort;

        part waterHeater : WaterHeater;
        part plumbingDistribution : PlumbingDistribution;

        perform action deliverDomesticWater;
    }

    part def WaterHeater {
        attribute heatingPower : ElectricPower = 4500.0;
        attribute setpoint : Temperature = 49.0;
    }

    part def PlumbingDistribution {
        attribute fixtureCount : Integer = 14;
        attribute nominalFlowRate : WaterFlowRate = 24.0;
    }

    part def SecuritySystem {
        attribute armed : Boolean;
        attribute lockedExteriorDoors : Integer;
        attribute detectedMotionZones : Integer;
        attribute currentSecurityLevel : SecurityLevel;

        port powerInput : ElectricPowerPort;
        port accessInterface : OccupantAccessPort;
        port notificationOutput : SecurityNotificationPort;
        port controlInput : ControlSignalPort;

        part doorSensors : DoorSensor[3];
        part windowSensors : WindowSensor[18];
        part motionSensors : MotionSensor[6];
        part smartLocks : SmartLock[3];

        perform action protectHomeAndOccupants;
        exhibit state securityState;
    }

    part def DoorSensor {
        attribute open : Boolean;
        attribute tamperDetected : Boolean;
    }

    part def WindowSensor {
        attribute open : Boolean;
        attribute tamperDetected : Boolean;
    }

    part def MotionSensor {
        attribute motionDetected : Boolean;
        attribute zoneName : String;
    }

    part def SmartLock {
        attribute locked : Boolean;
        attribute batteryLevelPercent : Real;
    }

    part def EnergyManagementSystem {
        attribute solarGenerationPower : ElectricPower;
        attribute gridImportPower : ElectricPower;
        attribute batteryStoredEnergy : Energy;
        attribute dailyEnergyUsed : Energy;

        port utilityPower : ElectricPowerPort;
        port conditionedPower : ElectricPowerPort;
        port energyStatus : ControlSignalPort;

        part mainPanel : ElectricalPanel;
        part battery : HomeBattery;
        part solarArray : SolarArray;

        perform action manageResidentialEnergy;
    }

    part def ElectricalPanel {
        attribute ratedCurrent : Real = 200.0;
        attribute activeCircuitCount : Integer = 28;
    }

    part def HomeBattery {
        attribute usableCapacity : Energy = 13.5;
        attribute stateOfChargePercent : Real;
        attribute maxOutputPower : ElectricPower = 5000.0;
    }

    part def SolarArray {
        attribute peakPower : ElectricPower = 7600.0;
        attribute currentOutputPower : ElectricPower;
    }

    part def HomeController {
        attribute operatingMode : String;
        attribute comfortPriority : Real = 0.65;
        attribute energySavingPriority : Real = 0.25;
        attribute securityPriority : Real = 0.10;

        port powerInput : ElectricPowerPort;
        port controlInterface : ControlSignalPort;
        port climateCommand : ControlSignalPort;
        port lightingCommand : ControlSignalPort;
        port waterCommand : ControlSignalPort;
        port securityCommand : ControlSignalPort;
        port energyInput : ControlSignalPort;

        perform action coordinateHomeServices;
    }

    action def provideHabitableShelter {
        in item residents : Occupant;
        in attribute outsideTemperature : Temperature;
        in attribute outsideLightLevel : Illuminance;
        out attribute habitable : Boolean;

        first start;
        then maintainThermalComfort;
        then provideUtilities;
        then maintainSafety;
        then supportDailyLiving;
        then done;

        action maintainThermalComfort;
        action provideUtilities;
        action maintainSafety;
        action supportDailyLiving;
    }

    action def regulateIndoorClimate {
        in attribute measuredTemperature : Temperature;
        in attribute measuredHumidity : RelativeHumidity;
        in attribute measuredAirQuality : AirQualityIndex;
        out item supplyAir : ConditionedAir;

        first senseAir;
        then decideMode;
        then conditionAir;
        then distributeAir;
        then verifyComfort;

        action senseAir;
        action decideMode;
        action conditionAir;
        action distributeAir;
        action verifyComfort;
    }

    action def illuminateOccupiedSpaces {
        in attribute occupancyDetected : Boolean;
        in attribute daylightLevel : Illuminance;
        out item luminousOutput : LightEnergy;

        first evaluateNeed;
        then setInteriorLighting;
        then setExteriorLighting;
        then reportLightingStatus;

        action evaluateNeed;
        action setInteriorLighting;
        action setExteriorLighting;
        action reportLightingStatus;
    }

    action def deliverDomesticWater {
        in item suppliedWater : PotableWater;
        in attribute demandFlowRate : WaterFlowRate;
        out item usableWater : PotableWater;

        first checkLeakStatus;
        then heatWaterWhenNeeded;
        then distributeToFixtures;
        then monitorFlow;

        action checkLeakStatus;
        action heatWaterWhenNeeded;
        action distributeToFixtures;
        action monitorFlow;
    }

    action def protectHomeAndOccupants {
        in attribute entryRequested : Boolean;
        in attribute motionDetected : Boolean;
        out item alert : SecurityAlert;

        first monitorPerimeter;
        then evaluateAccess;
        then lockOrUnlock;
        then notifyIfThreatDetected;

        action monitorPerimeter;
        action evaluateAccess;
        action lockOrUnlock;
        action notifyIfThreatDetected;
    }

    action def manageResidentialEnergy {
        in item gridElectricity : Electricity;
        out item distributedElectricity : Electricity;

        first measureLoads;
        then prioritizeCriticalLoads;
        then useSolarWhenAvailable;
        then chargeOrDischargeBattery;
        then importFromGridAsNeeded;
        then recordEnergyUse;

        action measureLoads;
        action prioritizeCriticalLoads;
        action useSolarWhenAvailable;
        action chargeOrDischargeBattery;
        action importFromGridAsNeeded;
        action recordEnergyUse;
    }

    action def coordinateHomeServices {
        in item residents : Occupant;
        in attribute requestedMode : String;
        out attribute serviceStatus : String;

        first readSensors;
        then evaluateResidentNeeds;
        then issueClimateCommands;
        then issueLightingCommands;
        then issueWaterCommands;
        then issueSecurityCommands;
        then publishStatus;

        action readSensors;
        action evaluateResidentNeeds;
        action issueClimateCommands;
        action issueLightingCommands;
        action issueWaterCommands;
        action issueSecurityCommands;
        action publishStatus;
    }

    state def HomeOperationalState {
        entry action initializeHomeServices;

        state Unoccupied {
            entry action reduceNonessentialLoads;
        }

        state Occupied {
            entry action enableComfortServices;
        }

        state Sleeping {
            entry action lowerLightingAndArmPerimeter;
        }

        state Away {
            entry action armSecurityAndConserveEnergy;
        }

        state Emergency {
            entry action preserveSafetyAndNotifyResidents;
        }

        transition first Unoccupied;
        transition Unoccupied to Occupied if residentDetected;
        transition Occupied to Sleeping if nightModeRequested;
        transition Sleeping to Occupied if morningScheduleReached;
        transition Occupied to Away if allResidentsDeparted;
        transition Away to Occupied if authorizedEntryDetected;
        transition Unoccupied to Emergency if hazardDetected;
        transition Occupied to Emergency if hazardDetected;
        transition Sleeping to Emergency if hazardDetected;
        transition Away to Emergency if hazardDetected;
        transition Emergency to Unoccupied if hazardCleared;
    }

    state def ClimateState {
        state Idle;
        state Heating;
        state Cooling;
        state Ventilating;
        state Fault;

        transition first Idle;
        transition Idle to Heating if indoorTemperatureBelowSetpoint;
        transition Idle to Cooling if indoorTemperatureAboveSetpoint;
        transition Idle to Ventilating if airQualityPoor;
        transition Heating to Idle if temperatureWithinComfortBand;
        transition Cooling to Idle if temperatureWithinComfortBand;
        transition Ventilating to Idle if airQualityAcceptable;
        transition Idle to Fault if equipmentFailureDetected;
        transition Heating to Fault if equipmentFailureDetected;
        transition Cooling to Fault if equipmentFailureDetected;
        transition Ventilating to Fault if equipmentFailureDetected;
    }

    state def SecurityState {
        state Disarmed;
        state ArmedStay;
        state ArmedAway;
        state Alarm;

        transition first Disarmed;
        transition Disarmed to ArmedStay if stayModeRequested;
        transition Disarmed to ArmedAway if awayModeRequested;
        transition ArmedStay to Disarmed if authorizedDisarm;
        transition ArmedAway to Disarmed if authorizedDisarm;
        transition ArmedStay to Alarm if perimeterBreachDetected;
        transition ArmedAway to Alarm if perimeterBreachDetected;
        transition ArmedAway to Alarm if interiorMotionDetected;
        transition Alarm to Disarmed if authorizedReset;
    }

    requirement def HomePrimaryFunctionRequirement {
        subject home : Home;

        doc /* The Home shall provide a habitable, safe, and resource-supported living environment for occupants by coordinating shelter, thermal comfort, lighting, domestic water, energy distribution, access control, and security monitoring. */

        require constraint {
            home.indoorTemperature >= 18.0 and
            home.indoorTemperature <= 26.0 and
            home.indoorHumidity >= 30.0 and
            home.indoorHumidity <= 60.0 and
            home.indoorAirQuality <= 100 and
            home.secure == true
        }
    }

    requirement def EnergyContinuityRequirement {
        subject home : Home;

        doc /* The Home shall maintain electrical service to climate control, security, lighting, water heating, and control systems during normal grid service and shall support critical security and control loads from stored energy during grid interruption. */

        require constraint {
            home.energyManagementSystem.battery.usableCapacity >= 10.0 and
            home.energyManagementSystem.mainPanel.ratedCurrent >= 150.0
        }
    }

    requirement def OccupantComfortRequirement {
        subject climate : ClimateControlSystem;

        doc /* The climate control system shall maintain occupied living spaces within the resident comfort band under normal operating conditions. */

        require constraint {
            climate.targetTemperature >= 20.0 and
            climate.targetTemperature <= 24.0 and
            climate.targetHumidity >= 35.0 and
            climate.targetHumidity <= 55.0
        }
    }

    requirement def DomesticWaterRequirement {
        subject water : DomesticWaterSystem;

        doc /* The domestic water system shall provide potable cold and heated water to household fixtures while monitoring for leaks. */

        require constraint {
            water.hotWaterTemperature >= 45.0 and
            water.hotWaterTemperature <= 52.0 and
            water.leakDetected == false
        }
    }

    requirement def SecurityRequirement {
        subject security : SecuritySystem;

        doc /* The security system shall control authorized entry, monitor perimeter openings, detect unauthorized motion, and notify occupants of security events. */

        require constraint {
            security.currentSecurityLevel >= 3 and
            security.lockedExteriorDoors >= 3
        }
    }

    satisfy HomePrimaryFunctionRequirement by Home::provideHabitableShelter;
    satisfy EnergyContinuityRequirement by EnergyManagementSystem::manageResidentialEnergy;
    satisfy OccupantComfortRequirement by ClimateControlSystem::regulateIndoorClimate;
    satisfy DomesticWaterRequirement by DomesticWaterSystem::deliverDomesticWater;
    satisfy SecurityRequirement by SecuritySystem::protectHomeAndOccupants;
}