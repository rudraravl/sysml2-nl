package VillageInfrastructureManagementSystem {
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types with Units =====

    value def Volume :> Real { unit 'm3'; }
    value def FlowRate :> Real { unit 'm3/h'; }
    value def Power :> Real { unit 'kW'; }
    value def Energy :> Real { unit 'kWh'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Percentage :> Real { unit '%'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Pressure :> Real { unit 'bar'; }
    value def Duration :> Real { unit 'h'; }
    value def FuelVolume :> Real { unit 'L'; }
    value def Distance :> Real { unit 'm'; }
    value def Illuminance :> Real { unit 'lux'; }

    // ===== Enumerations =====

    enum def AlertSeverity {
        INFO;
        WARNING;
        CRITICAL;
    }

    enum def EquipmentStatus {
        OPERATIONAL;
        DEGRADED;
        FAILED;
        MAINTENANCE;
    }

    enum def PowerSource {
        SOLAR;
        BATTERY;
        DIESEL;
        NONE;
    }

    // ===== Item Types =====

    item def PotableWater;
    item def Electricity;
    item def DieselFuel;

    item def SensorData {
        attribute sensorId : String;
        attribute metricType : String;
        attribute value : Real;
        attribute unit : String;
        attribute timestamp : String;
    }

    item def MaintenanceAlert {
        attribute alertId : String;
        attribute severity : AlertSeverity;
        attribute componentId : String;
        attribute description : String;
        attribute timestamp : String;
    }

    item def MaintenanceReport {
        attribute reportId : String;
        attribute alertId : String;
        attribute actionTaken : String;
        attribute technicianId : String;
        attribute completionTime : String;
        attribute componentStatus : EquipmentStatus;
    }

    // ===== Port Definitions =====

    port def WaterOutPort {
        out item potableWater : PotableWater;
        attribute flowRate : FlowRate;
    }

    port def WaterInPort {
        in item potableWater : PotableWater;
        attribute flowRate : FlowRate;
    }

    port def PowerOutPort {
        out item electricity : Electricity;
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    port def PowerInPort {
        in item electricity : Electricity;
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    port def FuelInPort {
        in item dieselFuel : DieselFuel;
        attribute volume : FuelVolume;
    }

    port def DataOutPort {
        out item sensorData : SensorData;
    }

    port def DataInPort {
        in item sensorData : SensorData;
    }

    port def AlertOutPort {
        out item maintenanceAlert : MaintenanceAlert;
    }

    port def AlertInPort {
        in item maintenanceAlert : MaintenanceAlert;
    }

    port def ReportOutPort {
        out item maintenanceReport : MaintenanceReport;
    }

    port def ReportInPort {
        in item maintenanceReport : MaintenanceReport;
    }

    // ===== Water Supply System Components =====

    part def Well {
        port def RechargePort {
            out item water : PotableWater;
            attribute rechargeRate : FlowRate;
        }
        attribute depth : Distance;
        attribute maxRechargeRate : FlowRate;
        attribute currentRechargeRate : FlowRate;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        state def WellBehavior {
            entry; then Recharging;
            state Recharging;
            state Depleted;
            transition Recharging to Depleted
                when currentRechargeRate < 0.01 [m3/h];
            transition Depleted to Recharging
                when currentRechargeRate >= 0.05 [m3/h];
        }
    }

    part def HandPump {
        port def IntakePort {
            in item water : PotableWater;
        }
        port def DischargePort :>> WaterOutPort;

        attribute pumpRate : FlowRate;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;
        attribute operatingHours : Duration = 0 [h];
        attribute maintenanceInterval : Duration;

        action def PumpWater {
            in item water : PotableWater;
            out item pumpedWater : PotableWater;
            attribute flowRate : FlowRate;
        }

        state def PumpBehavior {
            entry; then Idle;
            state Idle;
            state Pumping;
            state Failed;
            transition Idle to Pumping
                when status == EquipmentStatus::OPERATIONAL;
            transition Pumping to Idle
                when status != EquipmentStatus::OPERATIONAL;
            transition Pumping to Failed
                when operatingHours > maintenanceInterval;
            transition Failed to Idle
                when status == EquipmentStatus::MAINTENANCE;
        }
    }

    part def StorageTank {
        port def InletPort :>> WaterInPort;
        port def OutletPort :>> WaterOutPort;

        attribute capacity : Volume;
        attribute currentLevel : Volume;
        attribute minLevel : Volume;
        attribute maxLevel : Volume;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        state def TankBehavior {
            entry; then Normal;
            state Normal;
            state Low;
            state Critical;
            state Overflow;
            transition Normal to Low
                when currentLevel < (capacity * 0.3);
            transition Low to Normal
                when currentLevel >= (capacity * 0.4);
            transition Low to Critical
                when currentLevel < minLevel;
            transition Critical to Low
                when currentLevel >= minLevel;
            transition Normal to Overflow
                when currentLevel > maxLevel;
            transition Overflow to Normal
                when currentLevel <= maxLevel;
        }
    }

    part def WaterPipe {
        port def PipeInPort :>> WaterInPort;
        port def PipeOutPort :>> WaterOutPort;

        attribute length : Distance;
        attribute diameter : Distance;
        attribute maxFlowRate : FlowRate;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;
    }

    part def WaterSupplySystem {
        part well : Well {
            attribute depth = 25 [m];
            attribute maxRechargeRate = 0.5 [m3/h];
            attribute currentRechargeRate = 0.5 [m3/h];
        }

        part handPump : HandPump {
            attribute pumpRate = 0.3 [m3/h];
            attribute maintenanceInterval = 500 [h];
        }

        part storageTank : StorageTank {
            attribute capacity = 10 [m3];
            attribute currentLevel = 5 [m3];
            attribute minLevel = 1 [m3];
            attribute maxLevel = 9.5 [m3];
        }

        part clinicPipe : WaterPipe {
            attribute length = 50 [m];
            attribute diameter = 0.05 [m];
            attribute maxFlowRate = 0.5 [m3/h];
        }

        part communityCenterPipe : WaterPipe {
            attribute length = 80 [m];
            attribute diameter = 0.04 [m];
            attribute maxFlowRate = 0.3 [m3/h];
        }

        port waterOutClinic :>> WaterOutPort;
        port waterOutCommunityCenter :>> WaterOutPort;

        connection wellToPump connect well.RechargePort to handPump.IntakePort;
        connection pumpToTank connect handPump.DischargePort to storageTank.InletPort;
        connection tankToClinicPipe connect storageTank.OutletPort to clinicPipe.PipeInPort;
        connection tankToCCPipe connect storageTank.OutletPort to communityCenterPipe.PipeInPort;
        connection clinicPipeOut connect clinicPipe.PipeOutPort to waterOutClinic;
        connection ccPipeOut connect communityCenterPipe.PipeOutPort to waterOutCommunityCenter;
    }

    // ===== Power Generation System Components =====

    part def SolarPanelArray {
        port def PowerOutPort :>> PowerOutPort;

        attribute panelCount : Integer;
        attribute panelPower : Power;
        attribute totalPower : Power;
        attribute currentOutput : Power;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        state def SolarBehavior {
            entry; then Generating;
            state Generating;
            state Idle;
            state Degraded;
            transition Generating to Idle
                when currentOutput < 0.01 [kW];
            transition Idle to Generating
                when currentOutput >= 0.01 [kW];
            transition Generating to Degraded
                when status == EquipmentStatus::DEGRADED;
            transition Degraded to Generating
                when status == EquipmentStatus::OPERATIONAL;
        }
    }

    part def BatteryBank {
        port def ChargePort :>> PowerInPort;
        port def DischargePort :>> PowerOutPort;

        attribute capacity : Energy;
        attribute currentCharge : Energy;
        attribute chargeLevel : Percentage;
        attribute minCharge : Percentage;
        attribute maxCharge : Percentage;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        state def BatteryBehavior {
            entry; then Standby;
            state Charging;
            state Discharging;
            state Standby;
            state Low;
            state Critical;
            transition Standby to Charging
                when chargeLevel < 80 [%];
            transition Charging to Standby
                when chargeLevel >= 95 [%];
            transition Standby to Discharging
                when chargeLevel > 20 [%];
            transition Discharging to Standby
                when chargeLevel <= 20 [%];
            transition Discharging to Low
                when chargeLevel < 20 [%];
            transition Low to Critical
                when chargeLevel < 10 [%];
            transition Low to Discharging
                when chargeLevel >= 30 [%];
            transition Critical to Charging
                when chargeLevel < 5 [%];
        }
    }

    part def DieselGenerator {
        port def FuelPort :>> FuelInPort;
        port def PowerOutPort :>> PowerOutPort;

        attribute ratedPower : Power;
        attribute currentOutput : Power;
        attribute fuelLevel : FuelVolume;
        attribute fuelCapacity : FuelVolume;
        attribute minFuelLevel : FuelVolume;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;
        attribute operatingHours : Duration = 0 [h];
        attribute maintenanceInterval : Duration;

        state def GeneratorBehavior {
            entry; then Off;
            state Off;
            state Running;
            state LowFuel;
            state Failed;
            transition Off to Running
                when status == EquipmentStatus::OPERATIONAL and fuelLevel > minFuelLevel;
            transition Running to Off
                when status != EquipmentStatus::OPERATIONAL;
            transition Running to LowFuel
                when fuelLevel < (fuelCapacity * 0.15);
            transition LowFuel to Off
                when fuelLevel < minFuelLevel;
            transition LowFuel to Running
                when fuelLevel >= (fuelCapacity * 0.25);
            transition Running to Failed
                when operatingHours > maintenanceInterval;
            transition Failed to Off
                when status == EquipmentStatus::MAINTENANCE;
        }
    }

    part def PowerDistributionPanel {
        port def SolarInPort :>> PowerInPort;
        port def BatteryChargePort :>> PowerOutPort;
        port def BatteryDischargePort :>> PowerInPort;
        port def GeneratorInPort :>> PowerInPort;
        port def ClinicOutPort :>> PowerOutPort;
        port def CommunityCenterOutPort :>> PowerOutPort;

        attribute activeSource : PowerSource = PowerSource::SOLAR;
        attribute totalDemand : Power;
        attribute solarContribution : Power;
        attribute batteryContribution : Power;
        attribute generatorContribution : Power;
        attribute batteryChargeLevel : Percentage;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        state def DistributionBehavior {
            entry; then SolarPriority;
            state SolarPriority;
            state SolarBattery;
            state BatteryOnly;
            state GeneratorBackup;
            state FullBackup;
            transition SolarPriority to SolarBattery
                when solarContribution < totalDemand;
            transition SolarBattery to BatteryOnly
                when solarContribution < 0.01 [kW];
            transition BatteryOnly to GeneratorBackup
                when batteryChargeLevel < 10 [%];
            transition GeneratorBackup to SolarPriority
                when solarContribution >= totalDemand;
            transition SolarBattery to SolarPriority
                when solarContribution >= totalDemand;
            transition BatteryOnly to SolarPriority
                when solarContribution >= totalDemand;
            transition GeneratorBackup to FullBackup
                when generatorContribution < totalDemand;
            transition FullBackup to SolarPriority
                when solarContribution >= totalDemand;
        }
    }

    part def PowerGenerationSystem {
        part solarArray : SolarPanelArray {
            attribute panelCount = 12;
            attribute panelPower = 0.4 [kW];
            attribute totalPower = 4.8 [kW];
            attribute currentOutput = 3.5 [kW];
        }

        part batteryBank : BatteryBank {
            attribute capacity = 20 [kWh];
            attribute currentCharge = 15 [kWh];
            attribute chargeLevel = 75 [%];
            attribute minCharge = 10 [%];
            attribute maxCharge = 95 [%];
        }

        part dieselGenerator : DieselGenerator {
            attribute ratedPower = 5 [kW];
            attribute currentOutput = 0 [kW];
            attribute fuelLevel = 40 [L];
            attribute fuelCapacity = 50 [L];
            attribute minFuelLevel = 5 [L];
            attribute maintenanceInterval = 250 [h];
        }

        part distributionPanel : PowerDistributionPanel {
            attribute totalDemand = 2.15 [kW];
            attribute solarContribution = 3.5 [kW];
            attribute batteryContribution = 0 [kW];
            attribute generatorContribution = 0 [kW];
            attribute batteryChargeLevel = 75 [%];
        }

        port powerOutClinic :>> PowerOutPort;
        port powerOutCommunityCenter :>> PowerOutPort;

        connection solarToPanel connect solarArray.PowerOutPort to distributionPanel.SolarInPort;
        connection solarToBattery connect solarArray.PowerOutPort to batteryBank.ChargePort;
        connection batteryToPanel connect batteryBank.DischargePort to distributionPanel.BatteryDischargePort;
        connection panelToBattery connect distributionPanel.BatteryChargePort to batteryBank.ChargePort;
        connection generatorToPanel connect dieselGenerator.PowerOutPort to distributionPanel.GeneratorInPort;
        connection panelToClinic connect distributionPanel.ClinicOutPort to powerOutClinic;
        connection panelToCC connect distributionPanel.CommunityCenterOutPort to powerOutCommunityCenter;
    }

    // ===== Health Clinic =====

    part def SanitationFacility {
        port def WaterInPort :>> WaterInPort;
        attribute waterDemand : FlowRate;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;
    }

    part def MedicalEquipment {
        port def PowerInPort :>> PowerInPort;
        attribute powerDemand : Power;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        state def MedicalEquipmentBehavior {
            entry; then Operational;
            state Operational;
            state Standby;
            state Off;
            transition Operational to Standby
                when powerDemand < 0.1 [kW];
            transition Standby to Operational
                when powerDemand >= 0.1 [kW];
            transition Operational to Off
                when status == EquipmentStatus::FAILED;
            transition Off to Operational
                when status == EquipmentStatus::OPERATIONAL;
        }
    }

    part def LightingSystem {
        port def PowerInPort :>> PowerInPort;
        attribute powerDemand : Power;
        attribute lightCount : Integer;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;
        attribute ambientLight : Illuminance;
        attribute lightThreshold : Illuminance;

        state def LightingBehavior {
            entry; then Off;
            state On;
            state Off;
            transition Off to On
                when ambientLight < lightThreshold;
            transition On to Off
                when ambientLight >= lightThreshold;
        }
    }

    part def HealthClinic {
        part sanitation : SanitationFacility {
            attribute waterDemand = 0.2 [m3/h];
        }
        part medicalEquipment : MedicalEquipment {
            attribute powerDemand = 1.5 [kW];
        }
        part lighting : LightingSystem {
            attribute powerDemand = 0.3 [kW];
            attribute lightCount = 8;
            attribute ambientLight = 200 [lux];
            attribute lightThreshold = 100 [lux];
        }

        port waterIn :>> WaterInPort;
        port powerIn :>> PowerInPort;

        connection waterToSanitation connect waterIn to sanitation.WaterInPort;
        connection powerToMedical connect powerIn to medicalEquipment.PowerInPort;
        connection powerToLighting connect powerIn to lighting.PowerInPort;
    }

    // ===== Community Center =====

    part def CommunicationEquipment {
        port def PowerInPort :>> PowerInPort;
        attribute powerDemand : Power;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        state def CommBehavior {
            entry; then Active;
            state Active;
            state Standby;
            state Off;
            transition Active to Standby
                when powerDemand < 0.05 [kW];
            transition Standby to Active
                when powerDemand >= 0.05 [kW];
            transition Active to Off
                when status == EquipmentStatus::FAILED;
            transition Off to Active
                when status == EquipmentStatus::OPERATIONAL;
        }
    }

    part def CommunityCenter {
        part lighting : LightingSystem {
            attribute powerDemand = 0.2 [kW];
            attribute lightCount = 6;
            attribute ambientLight = 200 [lux];
            attribute lightThreshold = 100 [lux];
        }
        part commEquipment : CommunicationEquipment {
            attribute powerDemand = 0.15 [kW];
        }
        part sanitation : SanitationFacility {
            attribute waterDemand = 0.1 [m3/h];
        }

        port waterIn :>> WaterInPort;
        port powerIn :>> PowerInPort;

        connection waterToSanitation connect waterIn to sanitation.WaterInPort;
        connection powerToLighting connect powerIn to lighting.PowerInPort;
        connection powerToComm connect powerIn to commEquipment.PowerInPort;
    }

    // ===== Sensors =====

    part def WaterLevelSensor {
        port def DataPort :>> DataOutPort;
        attribute sensorId : String;
        attribute measuredLevel : Volume;
        attribute thresholdLow : Volume;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        action def Measure {
            out item data : SensorData;
        }
    }

    part def PowerOutputSensor {
        port def DataPort :>> DataOutPort;
        attribute sensorId : String;
        attribute measuredPower : Power;
        attribute thresholdLow : Power;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        action def Measure {
            out item data : SensorData;
        }
    }

    part def BatteryChargeSensor {
        port def DataPort :>> DataOutPort;
        attribute sensorId : String;
        attribute measuredCharge : Percentage;
        attribute thresholdLow : Percentage;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        action def Measure {
            out item data : SensorData;
        }
    }

    part def FuelLevelSensor {
        port def DataPort :>> DataOutPort;
        attribute sensorId : String;
        attribute measuredFuel : FuelVolume;
        attribute thresholdLow : FuelVolume;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        action def Measure {
            out item data : SensorData;
        }
    }

    part def EquipmentHealthSensor {
        port def DataPort :>> DataOutPort;
        attribute sensorId : String;
        attribute measuredStatus : EquipmentStatus;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        action def Measure {
            out item data : SensorData;
        }
    }

    part def FlowRateSensor {
        port def DataPort :>> DataOutPort;
        attribute sensorId : String;
        attribute measuredFlowRate : FlowRate;
        attribute thresholdLow : FlowRate;
        attribute status : EquipmentStatus = EquipmentStatus::OPERATIONAL;

        action def Measure {
            out item data : SensorData;
        }
    }

    // ===== Monitoring Station =====

    part def MonitoringStation {
        port dataIn :>> DataInPort;
        port alertOut :>> AlertOutPort;
        port reportIn :>> ReportInPort;

        attribute stationId : String;
        attribute monitoringInterval : Duration;
        attribute alertDetected : Boolean = false;
        attribute alertSent : Boolean = false;
        attribute repairConfirmed : Boolean = false;

        action def ProcessSensorData {
            in item sensorData : SensorData;
            out item alert : MaintenanceAlert;
        }

        action def GenerateAlert {
            in attribute componentId : String;
            in attribute description : String;
            in attribute severity : AlertSeverity;
            out item alert : MaintenanceAlert;
        }

        state def MonitoringBehavior {
            entry; then Monitoring;
            state Monitoring;
            state AlertActive;
            state AwaitingRepair;
            transition Monitoring to AlertActive
                when alertDetected == true;
            transition AlertActive to AwaitingRepair
                when alertSent == true;
            transition AwaitingRepair to Monitoring
                when repairConfirmed == true;
        }
    }

    // ===== Maintenance Team =====

    part def SparePart {
        attribute partName : String;
        attribute quantity : Integer;
        attribute partNumber : String;
    }

    part def SparePartsInventory {
        part pumpSeals : SparePart {
            attribute partName = "Pump Seal Kit";
            attribute quantity = 5;
            attribute partNumber = "PSK-001";
        }
        part solarFuses : SparePart {
            attribute partName = "Solar Array Fuse";
            attribute quantity = 20;
            attribute partNumber = "SAF-010";
        }
        part batteryCells : SparePart {
            attribute partName = "Battery Cell 12V";
            attribute quantity = 4;
            attribute partNumber = "BC-012";
        }
        part generatorFilters : SparePart {
            attribute partName = "Generator Fuel Filter";
            attribute quantity = 3;
            attribute partNumber = "GFF-003";
        }
        part pipeFittings : SparePart {
            attribute partName = "Pipe Fitting Set";
            attribute quantity = 10;
            attribute partNumber = "PFS-010";
        }
        part lightBulbs : SparePart {
            attribute partName = "LED Bulb 12V";
            attribute quantity = 15;
            attribute partNumber = "LB-015";
        }
    }

    part def ToolKit {
        attribute toolCount : Integer;
        attribute toolTypes : String;
    }

    part def Technician {
        port alertIn :>> AlertInPort;
        port reportOut :>> ReportOutPort;

        attribute technicianId : String;
        attribute name : String;
        attribute specialization : String;
        attribute availability : Boolean = true;
        attribute alertReceived : Boolean = false;
        attribute arrivedAtSite : Boolean = false;
        attribute assessmentComplete : Boolean = false;
        attribute repairComplete : Boolean = false;
        attribute reportSubmitted : Boolean = false;

        action def PerformInspection {
            in attribute componentId : String;
            out item report : MaintenanceReport;
        }

        action def PerformRepair {
            in item alert : MaintenanceAlert;
            out item report : MaintenanceReport;
        }

        action def PerformRoutineMaintenance {
            in attribute componentId : String;
            out item report : MaintenanceReport;
        }

        state def TechnicianBehavior {
            entry; then Available;
            state Available;
            state Dispatched;
            state OnSite;
            state Repairing;
            state Reporting;
            transition Available to Dispatched
                when alertReceived == true;
            transition Dispatched to OnSite
                when arrivedAtSite == true;
            transition OnSite to Repairing
                when assessmentComplete == true;
            transition Repairing to Reporting
                when repairComplete == true;
            transition Reporting to Available
                when reportSubmitted == true;
        }
    }

    part def MaintenanceTeam {
        part leadTechnician : Technician {
            attribute technicianId = "TECH-001";
            attribute name = "James Okello";
            attribute specialization = "Electrical Systems";
        }
        part waterSystemsTech : Technician {
            attribute technicianId = "TECH-002";
            attribute name = "Maria Santos";
            attribute specialization = "Water Systems";
        }
        part generatorSpecialist : Technician {
            attribute technicianId = "TECH-003";
            attribute name = "David Park";
            attribute specialization = "Power Generation";
        }
        part toolKit : ToolKit {
            attribute toolCount = 25;
            attribute toolTypes = "Wrenches, Multimeters, Pipe wrenches, Soldering iron, Crimpers";
        }
        part spareParts : SparePartsInventory;

        attribute technicianCount : Integer = 3;
        attribute maxResponseTime : Duration = 2 [h];

        port alertIn :>> AlertInPort;
        port reportOut :>> ReportOutPort;

        connection alertToLead connect alertIn to leadTechnician.alertIn;
        connection leadReport connect leadTechnician.reportOut to reportOut;
        connection waterReport connect waterSystemsTech.reportOut to reportOut;
        connection genReport connect generatorSpecialist.reportOut to reportOut;
    }

    // ===== Top-Level Village Infrastructure System =====

    part def VillageInfrastructureSystem {
        part waterSystem : WaterSupplySystem;
        part powerSystem : PowerGenerationSystem;
        part healthClinic : HealthClinic;
        part communityCenter : CommunityCenter;
        part monitoringStation : MonitoringStation {
            attribute stationId = "MON-001";
            attribute monitoringInterval = 0.083 [h];
        }
        part maintenanceTeam : MaintenanceTeam;

        // Distributed sensors
        part wellWaterLevelSensor : WaterLevelSensor {
            attribute sensorId = "WLS-001";
            attribute measuredLevel = 5 [m3];
            attribute thresholdLow = 1 [m3];
        }
        part pumpHealthSensor : EquipmentHealthSensor {
            attribute sensorId = "PHS-001";
            attribute measuredStatus = EquipmentStatus::OPERATIONAL;
        }
        part tankLevelSensor : WaterLevelSensor {
            attribute sensorId = "WLS-002";
            attribute measuredLevel = 5 [m3];
            attribute thresholdLow = 1 [m3];
        }
        part solarOutputSensor : PowerOutputSensor {
            attribute sensorId = "POS-001";
            attribute measuredPower = 3.5 [kW];
            attribute thresholdLow = 1 [kW];
        }
        part batteryChargeSensor : BatteryChargeSensor {
            attribute sensorId = "BCS-001";
            attribute measuredCharge = 75 [%];
            attribute thresholdLow = 15 [%];
        }
        part generatorFuelSensor : FuelLevelSensor {
            attribute sensorId = "FLS-001";
            attribute measuredFuel = 40 [L];
            attribute thresholdLow = 7.5 [L];
        }
        part generatorHealthSensor : EquipmentHealthSensor {
            attribute sensorId = "GHS-001";
            attribute measuredStatus = EquipmentStatus::OPERATIONAL;
        }
        part clinicFlowSensor : FlowRateSensor {
            attribute sensorId = "FRS-001";
            attribute measuredFlowRate = 0.2 [m3/h];
            attribute thresholdLow = 0.05 [m3/h];
        }
        part ccFlowSensor : FlowRateSensor {
            attribute sensorId = "FRS-002";
            attribute measuredFlowRate = 0.1 [m3/h];
            attribute thresholdLow = 0.03 [m3/h];
        }

        attribute systemAvailability : Percentage = 99.5 [%];

        // Water connections
        connection waterToClinic connect waterSystem.waterOutClinic to healthClinic.waterIn;
        connection waterToCC connect waterSystem.waterOutCommunityCenter to communityCenter.waterIn;

        // Power connections
        connection powerToClinic connect powerSystem.powerOutClinic to healthClinic.powerIn;
        connection powerToCC connect powerSystem.powerOutCommunityCenter to communityCenter.powerIn;

        // Sensor data connections to monitoring station
        connection wellLevelData connect wellWaterLevelSensor.DataPort to monitoringStation.dataIn;
        connection pumpHealthData connect pumpHealthSensor.DataPort to monitoringStation.dataIn;
        connection tankLevelData connect tankLevelSensor.DataPort to monitoringStation.dataIn;
        connection solarOutputData connect solarOutputSensor.DataPort to monitoringStation.dataIn;
        connection batteryChargeData connect batteryChargeSensor.DataPort to monitoringStation.dataIn;
        connection generatorFuelData connect generatorFuelSensor.DataPort to monitoringStation.dataIn;
        connection generatorHealthData connect generatorHealthSensor.DataPort to monitoringStation.dataIn;
        connection clinicFlowData connect clinicFlowSensor.DataPort to monitoringStation.dataIn;
        connection ccFlowData connect ccFlowSensor.DataPort to monitoringStation.dataIn;

        // Alert connection from monitoring station to maintenance team
        connection alertToTeam connect monitoringStation.alertOut to maintenanceTeam.alertIn;

        // Report connection from maintenance team back to monitoring station
        connection reportToStation connect maintenanceTeam.reportOut to monitoringStation.reportIn;
    }

    // ===== Requirements =====

    requirement def ReliableWaterSupply {
        subject waterSystem : WaterSupplySystem;

        requirement storageCapacity {
            doc /* The storage tank must hold at least 10 m3 of potable water to buffer recharge variability. */
            constraint { waterSystem.storageTank.capacity >= 10 [m3] }
        }

        requirement continuousSupply {
            doc /* Water supply must maintain minimum flow rate to clinic and community center at all times. */
            constraint { waterSystem.waterOutClinic.flowRate >= 0.1 [m3/h] }
            constraint { waterSystem.waterOutCommunityCenter.flowRate >= 0.05 [m3/h] }
        }

        requirement tankReserve {
            doc /* Storage tank must maintain at least 1 m3 reserve at all times. */
            constraint { waterSystem.storageTank.currentLevel >= waterSystem.storageTank.minLevel }
        }

        requirement pumpMaintenance {
            doc /* Hand pump must be serviced before exceeding maintenance interval. */
            constraint { waterSystem.handPump.operatingHours <= waterSystem.handPump.maintenanceInterval }
        }
    }

    requirement def ReliablePowerSupply {
        subject powerSystem : PowerGenerationSystem;

        requirement solarCapacity {
            doc /* Solar array must provide at least 4 kW peak power for clean energy generation. */
            constraint { powerSystem.solarArray.totalPower >= 4 [kW] }
        }

        requirement batteryCapacity {
            doc /* Battery bank must store at least 20 kWh to cover nighttime and cloudy periods. */
            constraint { powerSystem.batteryBank.capacity >= 20 [kWh] }
        }

        requirement backupPower {
            doc /* Diesel generator must provide at least 5 kW for backup and peak load handling. */
            constraint { powerSystem.dieselGenerator.ratedPower >= 5 [kW] }
        }

        requirement fuelReserve {
            doc /* Generator must maintain at least 5 L of fuel reserve at all times. */
            constraint { powerSystem.dieselGenerator.fuelLevel >= powerSystem.dieselGenerator.minFuelLevel }
        }

        requirement clinicPower {
            doc /* Clinic must receive at least 1.8 kW for medical equipment and lighting. */
            constraint { powerSystem.powerOutClinic.power >= 1.8 [kW] }
        }

        requirement communityCenterPower {
            doc /* Community center must receive at least 0.35 kW for lighting and communication. */
            constraint { powerSystem.powerOutCommunityCenter.power >= 0.35 [kW] }
        }

        requirement generatorMaintenance {
            doc /* Diesel generator must be serviced before exceeding maintenance interval. */
            constraint { powerSystem.dieselGenerator.operatingHours <= powerSystem.dieselGenerator.maintenanceInterval }
        }
    }

    requirement def ContinuousMonitoring {
        subject monitoringStation : MonitoringStation;

        requirement monitoringFrequency {
            doc /* Monitoring station must check all sensors at least every 5 minutes. */
            constraint { monitoringStation.monitoringInterval <= 0.083 [h] }
        }

        requirement sensorCoverage {
            doc /* All critical components must have operational health monitoring sensors. */
        }

        requirement alertGeneration {
            doc /* System must generate maintenance alert when any sensor exceeds threshold. */
        }
    }

    requirement def MaintenanceResponse {
        subject maintenanceTeam : MaintenanceTeam;

        requirement teamSize {
            doc /* At least 3 technicians must be available for maintenance operations. */
            constraint { maintenanceTeam.technicianCount >= 3 }
        }

        requirement responseTime {
            doc /* Maintenance team must respond to critical alerts within 2 hours. */
            constraint { maintenanceTeam.maxResponseTime <= 2 [h] }
        }

        requirement sparePartsAvailability {
            doc /* Spare parts inventory must include minimum quantities for critical components. */
            constraint { maintenanceTeam.spareParts.pumpSeals.quantity >= 3 }
            constraint { maintenanceTeam.spareParts.solarFuses.quantity >= 10 }
            constraint { maintenanceTeam.spareParts.generatorFilters.quantity >= 2 }
            constraint { maintenanceTeam.spareParts.batteryCells.quantity >= 2 }
        }

        requirement toolAvailability {
            doc /* Maintenance team must have complete toolkit with at least 20 tools. */
            constraint { maintenanceTeam.toolKit.toolCount >= 20 }
        }
    }

    requirement def VillageInfrastructureRequirements {
        subject villageSystem : VillageInfrastructureSystem;

        requirement waterSupply :>> ReliableWaterSupply {
            subject waterSystem = villageSystem.waterSystem;
        }

        requirement powerSupply :>> ReliablePowerSupply {
            subject powerSystem = villageSystem.powerSystem;
        }

        requirement monitoring :>> ContinuousMonitoring {
            subject monitoringStation = villageSystem.monitoringStation;
        }

        requirement maintenance :>> MaintenanceResponse {
            subject maintenanceTeam = villageSystem.maintenanceTeam;
        }

        requirement overallAvailability {
            doc /* Overall system availability must be at least 99 percent. */
            constraint { villageSystem.systemAvailability >= 99 [%] }
        }

        requirement clinicServiceContinuity {
            doc /* Health clinic must have continuous water and power supply for essential services. */
            constraint { villageSystem.healthClinic.waterIn.flowRate >= 0.1 [m3/h] }
            constraint { villageSystem.healthClinic.powerIn.power >= 1.8 [kW] }
        }

        requirement communityCenterServiceContinuity {
            doc /* Community center must have continuous water and power supply. */
            constraint { villageSystem.communityCenter.waterIn.flowRate >= 0.05 [m3/h] }
            constraint { villageSystem.communityCenter.powerIn.power >= 0.35 [kW] }
        }

        requirement alertHandling {
            doc /* All maintenance alerts must be routed to the maintenance team and resolved. */
        }
    }
}
