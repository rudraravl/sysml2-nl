package XanaduHouseModel {
    private import ScalarValues::*;

    // ===== Value Types =====
    attribute def TemperatureValue :> Real;
    attribute def HumidityValue :> Real;
    attribute def BrightnessValue :> Real;
    attribute def ColorTemperatureValue :> Real;
    attribute def TintValue :> Real;
    attribute def PositionValue :> Real;
    attribute def PowerValue :> Real;
    attribute def EnergyValue :> Real;
    attribute def LengthValue :> Real;
    attribute def RValue :> Real;
    attribute def PercentageValue :> Real;

    // ===== Enumerations =====
    enum def OccupancyState { unoccupied; occupied; sleeping; }
    enum def ClimateMode { heat; cool; ventilate; dehumidify; off; }
    enum def LightingMood { normal; dim; off; }
    enum def PowerSource { solar; battery; grid; }

    // ===== Item Definitions =====
    item def SensorData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
        attribute motionDetected : Boolean;
        attribute sensorId : Integer;
    }

    item def ClimateCommand {
        attribute mode : ClimateMode;
        attribute targetTemperature : TemperatureValue;
        attribute fanSpeed : Integer;
    }

    item def LightingCommand {
        attribute mood : LightingMood;
        attribute brightness : BrightnessValue;
        attribute colorTemperature : ColorTemperatureValue;
        attribute roomId : Integer;
    }

    item def WindowCommand {
        attribute windowId : Integer;
        attribute openPercent : PositionValue;
        attribute tintLevel : TintValue;
    }

    item def PowerCommand {
        attribute source : PowerSource;
        attribute powerDraw : PowerValue;
    }

    item def PowerStatus {
        attribute solarOutput : PowerValue;
        attribute batteryLevel : EnergyValue;
        attribute gridAvailable : Boolean;
    }

    // ===== State Machine Definition =====
    state def OccupancyControl {
        in sensorData : SensorData;
    }

    // ===== Part Definitions =====
    part def FoamStructure {
        attribute thermalResistance : RValue;
        attribute thickness : LengthValue;
    }

    part def EnvironmentalSensor {
        port sensorDataPort {
            out sensorData : SensorData;
        }
        attribute sensorId : Integer;
        attribute location : String;
    }

    part def CentralController {
        port sensorDataPort {
            in sensorData : SensorData;
        }
        port climateCommandPort {
            out climateCommand : ClimateCommand;
        }
        port lightingCommandPort {
            out lightingCommand : LightingCommand;
        }
        port windowCommandPort {
            out windowCommand : WindowCommand;
        }
        port solarStatusPort {
            in solarStatus : PowerStatus;
        }
        port batteryStatusPort {
            in batteryStatus : PowerStatus;
        }
        port gridStatusPort {
            in gridStatus : PowerStatus;
        }
        port powerCommandPort {
            out powerCommand : PowerCommand;
        }
        attribute occupantPreferences : TemperatureValue;
        attribute learnedHabits : Boolean;

        state occupancyControl : OccupancyControl {
            in sensorData : SensorData;
            entry; then unoccupied;
            state unoccupied;
            accept s : SensorData
                if s.motionDetected
                then occupied;
            state occupied;
            accept s : SensorData
                if s.motionDetected == false
                then unoccupied;
            accept s : SensorData
                if s.motionDetected == false && s.temperature < 20.0
                then sleeping;
            state sleeping;
            accept s : SensorData
                if s.motionDetected
                then occupied;
        }
    }

    part def ClimateControlUnit {
        port climateCommandPort {
            in climateCommand : ClimateCommand;
        }
        port climateStatusPort {
            out currentTemperature : TemperatureValue;
            out currentHumidity : HumidityValue;
        }
        port powerDrawPort {
            out powerDraw : PowerValue;
        }
        attribute currentMode : ClimateMode;
    }

    part def LightingSystem {
        port lightingCommandPort {
            in lightingCommand : LightingCommand;
        }
        port lightingStatusPort {
            out currentBrightness : BrightnessValue;
            out currentColorTemperature : ColorTemperatureValue;
        }
        port powerDrawPort {
            out powerDraw : PowerValue;
        }
        attribute currentMood : LightingMood;
    }

    part def AutomatedWindow {
        port windowCommandPort {
            in windowCommand : WindowCommand;
        }
        port windowStatusPort {
            out currentPosition : PositionValue;
            out currentTint : TintValue;
        }
        attribute windowId : Integer;
    }

    part def SolarEnergySystem {
        port solarPowerPort {
            out generatedPower : PowerValue;
        }
        port powerStatusPort {
            out powerStatus : PowerStatus;
        }
        attribute panelCount : Integer;
        attribute currentOutput : PowerValue;
    }

    part def EnergyStorageSystem {
        port chargePort {
            in chargePower : PowerValue;
        }
        port dischargePort {
            out dischargePower : PowerValue;
        }
        port powerStatusPort {
            out powerStatus : PowerStatus;
        }
        port powerCommandPort {
            in powerCommand : PowerCommand;
        }
        attribute capacity : EnergyValue;
        attribute currentLevel : EnergyValue;
    }

    part def GridConnection {
        port gridPowerPort {
            out gridPower : PowerValue;
        }
        port powerStatusPort {
            out powerStatus : PowerStatus;
        }
        port powerCommandPort {
            in powerCommand : PowerCommand;
        }
        attribute gridAvailable : Boolean;
    }

    part def XanaduHouse {
        part foamStructure : FoamStructure {
            attribute thermalResistance = 30.0;
            attribute thickness = 0.3;
        }
        part controller : CentralController {
            attribute occupantPreferences = 22.0;
            attribute learnedHabits = false;
        }
        part sensors : EnvironmentalSensor[8];
        part climateControl : ClimateControlUnit;
        part lighting : LightingSystem;
        part windows : AutomatedWindow[16];
        part solarSystem : SolarEnergySystem {
            attribute panelCount = 24;
        }
        part battery : EnergyStorageSystem {
            attribute capacity = 40.0;
            attribute currentLevel = 20.0;
        }
        part grid : GridConnection {
            attribute gridAvailable = true;
        }

        flow sensorDataFlow of SensorData
            from sensors.sensorDataPort.sensorData to controller.sensorDataPort.sensorData;

        flow climateCommandFlow of ClimateCommand
            from controller.climateCommandPort.climateCommand to climateControl.climateCommandPort.climateCommand;

        flow lightingCommandFlow of LightingCommand
            from controller.lightingCommandPort.lightingCommand to lighting.lightingCommandPort.lightingCommand;

        flow windowCommandFlow of WindowCommand
            from controller.windowCommandPort.windowCommand to windows.windowCommandPort.windowCommand;

        flow solarToBatteryFlow of PowerValue
            from solarSystem.solarPowerPort.generatedPower to battery.chargePort.chargePower;

        flow solarStatusFlow of PowerStatus
            from solarSystem.powerStatusPort.powerStatus to controller.solarStatusPort.solarStatus;

        flow batteryStatusFlow of PowerStatus
            from battery.powerStatusPort.powerStatus to controller.batteryStatusPort.batteryStatus;

        flow gridStatusFlow of PowerStatus
            from grid.powerStatusPort.powerStatus to controller.gridStatusPort.gridStatus;

        flow powerCommandToBatteryFlow of PowerCommand
            from controller.powerCommandPort.powerCommand to battery.powerCommandPort.powerCommand;

        flow powerCommandToGridFlow of PowerCommand
            from controller.powerCommandPort.powerCommand to grid.powerCommandPort.powerCommand;
    }

    part house : XanaduHouse;

    // ===== Action Definitions =====
    action def DetermineOccupancy {
        in sensorData : SensorData;
        out occupancy : OccupancyState;
    }

    action def RegulateClimate {
        in sensorData : SensorData;
        in occupancy : OccupancyState;
        in preferences : TemperatureValue;
        out climateCommand : ClimateCommand;
    }

    action def AdjustLighting {
        in occupancy : OccupancyState;
        in sensorData : SensorData;
        out lightingCommand : LightingCommand;
    }

    action def ControlWindows {
        in occupancy : OccupancyState;
        in sensorData : SensorData;
        out windowCommand : WindowCommand;
    }

    action def ManagePower {
        in solarStatus : PowerStatus;
        in batteryStatus : PowerStatus;
        in gridStatus : PowerStatus;
        out powerCommand : PowerCommand;
    }

    action def LearnHabits {
        in sensorData : SensorData;
        in preferences : TemperatureValue;
        out updatedPreferences : TemperatureValue;
    }

    // ===== Requirements =====
    requirement def ComfortEnvironmentReqDef {
        doc /* The house shall maintain a comfortable living environment for occupants. */
        attribute actualTemperature : TemperatureValue;
        attribute minComfortTemp : TemperatureValue;
        attribute maxComfortTemp : TemperatureValue;
        require constraint {
            actualTemperature >= minComfortTemp &&
            actualTemperature <= maxComfortTemp
        }
    }

    requirement def EnergyEfficiencyReqDef {
        doc /* The house shall minimize energy consumption through automation and renewable energy. */
        attribute totalEnergyConsumption : EnergyValue;
        attribute maxEnergyConsumption : EnergyValue;
        require constraint { totalEnergyConsumption <= maxEnergyConsumption }
    }

    requirement def OccupancyDetectionReqDef {
        doc /* The controller shall determine occupancy state using 8 environmental sensors. */
        attribute sensorCount : Integer;
        attribute requiredSensors : Integer;
        require constraint { sensorCount >= requiredSensors }
    }

    requirement def ClimateControlReqDef {
        doc /* The climate control unit shall heat, cool, ventilate, or dehumidify based on controller commands. */
        attribute supportedModes : Integer;
        attribute requiredModes : Integer;
        require constraint { supportedModes >= requiredModes }
    }

    requirement def LightingControlReqDef {
        doc /* The lighting system shall adjust brightness and color temperature and turn off lights in empty rooms. */
        attribute lightsOffInEmptyRooms : Boolean;
        require constraint { lightsOffInEmptyRooms == true }
    }

    requirement def AutomatedWindowReqDef {
        doc /* The 16 automated windows shall open, close, and adjust tint level per controller commands. */
        attribute windowCount : Integer;
        attribute requiredWindows : Integer;
        require constraint { windowCount >= requiredWindows }
    }

    requirement def SolarEnergyReqDef {
        doc /* The solar energy system shall generate electrical power for the house. */
        attribute solarOutput : PowerValue;
        attribute minSolarOutput : PowerValue;
        require constraint { solarOutput >= minSolarOutput }
    }

    requirement def EnergyStorageReqDef {
        doc /* The energy storage system shall store excess solar power for later use. */
        attribute batteryCapacity : EnergyValue;
        attribute minBatteryCapacity : EnergyValue;
        require constraint { batteryCapacity >= minBatteryCapacity }
    }

    requirement def PowerSourcePrioritizationReqDef {
        doc /* The controller shall prioritize solar, then battery, then grid for power sourcing. */
        attribute sourcePriority : PowerSource;
        require constraint { sourcePriority == PowerSource::solar }
    }

    requirement def ThermalInsulationReqDef {
        doc /* The foam structure shall provide exceptional thermal insulation to reduce heating/cooling needs. */
        attribute thermalResistance : RValue;
        attribute minThermalResistance : RValue;
        require constraint { thermalResistance >= minThermalResistance }
    }

    requirement def AdaptiveLearningReqDef {
        doc /* The system shall learn occupant habits over time to optimize comfort and energy use. */
        attribute learningEnabled : Boolean;
        require constraint { learningEnabled == true }
    }

    requirement def SelfSufficiencyReqDef {
        doc /* The house shall be self-sufficient and affordable through renewable energy and efficiency. */
        attribute gridDependency : PercentageValue;
        attribute maxGridDependency : PercentageValue;
        require constraint { gridDependency <= maxGridDependency }
    }

    // ===== Requirement Usages =====
    requirement comfortReq : ComfortEnvironmentReqDef {
        attribute minComfortTemp = 20.0;
        attribute maxComfortTemp = 24.0;
    }

    requirement energyEfficiencyReq : EnergyEfficiencyReqDef {
        attribute maxEnergyConsumption = 30.0;
    }

    requirement occupancyReq : OccupancyDetectionReqDef {
        attribute requiredSensors = 8;
    }

    requirement climateReq : ClimateControlReqDef {
        attribute requiredModes = 4;
    }

    requirement lightingReq : LightingControlReqDef;

    requirement windowReq : AutomatedWindowReqDef {
        attribute requiredWindows = 16;
    }

    requirement solarReq : SolarEnergyReqDef {
        attribute minSolarOutput = 5.0;
    }

    requirement storageReq : EnergyStorageReqDef {
        attribute minBatteryCapacity = 40.0;
    }

    requirement powerPriorityReq : PowerSourcePrioritizationReqDef;

    requirement insulationReq : ThermalInsulationReqDef {
        attribute minThermalResistance = 25.0;
    }

    requirement learningReq : AdaptiveLearningReqDef;

    requirement selfSufficiencyReq : SelfSufficiencyReqDef {
        attribute maxGridDependency = 20.0;
    }
}
