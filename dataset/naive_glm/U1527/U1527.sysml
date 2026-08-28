package MunicipalWaterSupplyNetwork {

    import ScalarFunctions::*;

    // ============================================================
    // Value Types with Units
    // ============================================================
    value type VolumeFlowRate { :> Real; unit 'm3/s'; }
    value type Pressure { :> Real; unit 'kPa'; }
    value type Volume { :> Real; unit 'm3'; }
    value type Length { :> Real; unit 'm'; }
    value type Concentration { :> Real; unit 'mg/L'; }
    value type Turbidity { :> Real; unit 'NTU'; }
    value type Power { :> Real; unit 'kW'; }
    value type Elevation { :> Real; unit 'm'; }
    value type Duration { :> Real; unit 'h'; }
    value type Diameter { :> Real; unit 'm'; }
    value type Velocity { :> Real; unit 'm/s'; }
    value type MeterReading { :> Real; unit 'm3'; }
    value type Efficiency { :> Real; min 0; max 1; }
    value type Availability { :> Real; min 0; max 1; }

    // ============================================================
    // Enumerations
    // ============================================================
    enum def DemandLevel { low; moderate; peak; emergency; }
    enum def PumpStatus { off; standby; running; faulted; }
    enum def QualityStatus { compliant; nonCompliant; }
    enum def ValveState { open; closed; throttled; }
    enum def ConsumerType { residential; commercial; industrial; }
    enum def MonitoringMode { nominal; leakDetected; pressureAnomaly; qualityViolation; }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def Water {
        attribute turbidity : Turbidity;
        attribute pH : Real;
        attribute temperature : Real;
        attribute dissolvedOxygen : Concentration;
    }

    item def RawWater :> Water {
        attribute bacteriaLevel : Concentration;
        attribute sedimentLoad : Concentration;
    }

    item def PotableWater :> Water {
        attribute chlorineResidual : Concentration;
        attribute bacteriaLevel : Concentration;
    }

    item def CoagulantDose {
        attribute coagulantType : String;
        attribute doseConcentration : Concentration;
    }

    item def ChlorineDose {
        attribute solutionConcentration : Concentration;
        attribute dosage : Concentration;
    }

    item def DemandSignal {
        attribute level : DemandLevel;
        attribute flowRate : VolumeFlowRate;
        attribute pressure : Pressure;
    }

    item def QualityReading {
        attribute turbidity : Turbidity;
        attribute chlorineResidual : Concentration;
        attribute pH : Real;
        attribute bacteriaLevel : Concentration;
        attribute status : QualityStatus;
    }

    item def LeakAlert {
        attribute location : String;
        attribute severity : Real;
        attribute detectedFlowRate : VolumeFlowRate;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def WaterIn {
        in flow water : Water;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def WaterOut {
        out flow water : Water;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def RawWaterIn {
        in flow water : RawWater;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def RawWaterOut {
        out flow water : RawWater;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def PotableWaterIn {
        in flow water : PotableWater;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def PotableWaterOut {
        out flow water : PotableWater;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    port def DemandPort {
        in signal : DemandSignal;
    }

    port def MonitoringOut {
        out reading : QualityReading;
        out leakAlert : LeakAlert;
        attribute pressure : Pressure;
        attribute flowRate : VolumeFlowRate;
    }

    // ============================================================
    // Pump (Generic, subtyped by context)
    // ============================================================
    part def Pump {
        attribute name : String;
        attribute capacity : VolumeFlowRate;
        attribute powerRating : Power;
        attribute efficiency : Efficiency;
        attribute status : PumpStatus;
        attribute operatingHours : Duration;
        port inlet : WaterIn;
        port outlet : WaterOut;

        exhibit state {
            state Off;
            state Standby;
            state Running;
            state Faulted;
            initial Off;
            transition from Off to Standby when status == PumpStatus::standby;
            transition from Standby to Running when status == PumpStatus::running;
            transition from Running to Standby when status == PumpStatus::standby;
            transition from Running to Faulted when status == PumpStatus::faulted;
            transition from Faulted to Off when status == PumpStatus::off;
            transition from Faulted to Standby when status == PumpStatus::standby;
        }
    }

    // ============================================================
    // Reservoir (Natural Source)
    // ============================================================
    part def Reservoir {
        attribute name : String;
        attribute capacity : Volume;
        attribute currentVolume : Volume;
        attribute surfaceElevation : Elevation;
        attribute minimumLevel : Volume;
        attribute inflowRate : VolumeFlowRate;
        attribute outflowRate : VolumeFlowRate;
        port output : RawWaterOut;

        exhibit state {
            state Normal;
            state LowLevel;
            state Recovery;
            state Critical;
            initial Normal;
            transition from Normal to LowLevel when currentVolume < minimumLevel;
            transition from LowLevel to Critical when currentVolume < 0.1 * minimumLevel;
            transition from LowLevel to Recovery when inflowRate > outflowRate;
            transition from Critical to Recovery when inflowRate > outflowRate;
            transition from Recovery to Normal when currentVolume > 0.5 * capacity;
        }
    }

    // ============================================================
    // Intake Pump Station (Redundant)
    // ============================================================
    part def IntakePumpStation {
        attribute name : String;
        attribute designFlow : VolumeFlowRate;
        attribute dischargePressure : Pressure;
        attribute standbyReady : Boolean;
        attribute numberOfOperatingPumps : Integer;
        port input : RawWaterIn;
        port output : RawWaterOut;
        part primaryPump : Pump;
        part standbyPump : Pump;

        exhibit state {
            state SinglePump;
            state DualPump;
            state StandbyFailover;
            initial SinglePump;
            transition from SinglePump to StandbyFailover when primaryPump.status == PumpStatus::faulted;
            transition from StandbyFailover to SinglePump when primaryPump.status == PumpStatus::standby;
            transition from SinglePump to DualPump when input.flowRate > designFlow;
            transition from DualPump to SinglePump when input.flowRate < 0.5 * designFlow;
        }

        connection input to primaryPump.inlet;
        connection input to standbyPump.inlet;
        connection primaryPump.outlet to output;
        connection standbyPump.outlet to output;
    }

    // ============================================================
    // Treatment Plant Sub-Components
    // ============================================================
    part def CoagulationUnit {
        attribute name : String;
        attribute coagulantType : String;
        attribute dosingRate : Concentration;
        attribute mixingTime : Duration;
        attribute coagulant : CoagulantDose;
        port input : RawWaterIn;
        port output : RawWaterOut;
    }

    part def SedimentationBasin {
        attribute name : String;
        attribute volume : Volume;
        attribute settlingTime : Duration;
        attribute turbidityReduction : Turbidity;
        port input : RawWaterIn;
        port output : RawWaterOut;
    }

    part def FiltrationSystem {
        attribute name : String;
        attribute mediaType : String;
        attribute filterArea : Volume;
        attribute backwashInterval : Duration;
        attribute backwashTimer : Duration;
        port input : RawWaterIn;
        port output : RawWaterOut;

        exhibit state {
            state Filtering;
            state Backwash;
            initial Filtering;
            transition from Filtering to Backwash when backwashTimer >= backwashInterval;
            transition from Backwash to Filtering when backwashTimer < backwashInterval;
        }
    }

    part def DisinfectionUnit {
        attribute name : String;
        attribute chlorineDose : Concentration;
        attribute contactTime : Duration;
        attribute residualTarget : Concentration;
        attribute chlorine : ChlorineDose;
        port input : RawWaterIn;
        port output : PotableWaterOut;
    }

    // ============================================================
    // Water Quality Monitor (Treatment Plant)
    // ============================================================
    part def WaterQualityMonitor {
        attribute name : String;
        attribute turbidityThreshold : Turbidity;
        attribute chlorineMin : Concentration;
        attribute chlorineMax : Concentration;
        attribute pHMin : Real;
        attribute pHMax : Real;
        attribute bacteriaMax : Concentration;
        attribute lastReading : QualityReading;
        port sample : PotableWaterIn;
        port output : MonitoringOut;

        exhibit state {
            state Compliant;
            state NonCompliant;
            initial Compliant;
            transition from Compliant to NonCompliant when lastReading.status == QualityStatus::nonCompliant;
            transition from NonCompliant to Compliant when lastReading.status == QualityStatus::compliant;
        }
    }

    // ============================================================
    // Water Treatment Plant (Multi-Stage)
    // ============================================================
    part def WaterTreatmentPlant {
        attribute name : String;
        attribute designCapacity : VolumeFlowRate;
        attribute currentMode : MonitoringMode;
        port input : RawWaterIn;
        port output : PotableWaterOut;
        part coagulation : CoagulationUnit;
        part sedimentation : SedimentationBasin;
        part filtration : FiltrationSystem;
        part disinfection : DisinfectionUnit;
        part qualityMonitor : WaterQualityMonitor;

        exhibit state {
            state NormalTreatment;
            state Recirculation;
            initial NormalTreatment;
            transition from NormalTreatment to Recirculation when qualityMonitor.lastReading.status == QualityStatus::nonCompliant;
            transition from Recirculation to NormalTreatment when qualityMonitor.lastReading.status == QualityStatus::compliant;
        }

        connection input to coagulation.input;
        connection coagulation.output to sedimentation.input;
        connection sedimentation.output to filtration.input;
        connection filtration.output to disinfection.input;
        connection disinfection.output to qualityMonitor.sample;
        connection qualityMonitor.output to output;
        connection qualityMonitor.sample to coagulation.input;
    }

    // ============================================================
    // Clear Well (Storage with Emergency Reserve)
    // ============================================================
    part def ClearWell {
        attribute name : String;
        attribute totalCapacity : Volume;
        attribute currentVolume : Volume;
        attribute emergencyReserve : Volume;
        attribute minimumOperationalLevel : Volume;
        attribute usableVolume : Volume;
        port input : PotableWaterIn;
        port output : PotableWaterOut;

        exhibit state {
            state Full;
            state Normal;
            state Low;
            state EmergencyDrawdown;
            initial Normal;
            transition from Normal to Full when currentVolume > 0.9 * totalCapacity;
            transition from Full to Normal when currentVolume < 0.8 * totalCapacity;
            transition from Normal to Low when currentVolume < minimumOperationalLevel;
            transition from Low to EmergencyDrawdown when currentVolume < emergencyReserve;
            transition from EmergencyDrawdown to Low when currentVolume > emergencyReserve;
            transition from Low to Normal when currentVolume > 0.5 * totalCapacity;
        }
    }

    // ============================================================
    // High Service Pump Station (Adaptive)
    // ============================================================
    part def HighServicePumpStation {
        attribute name : String;
        attribute designFlow : VolumeFlowRate;
        attribute dischargePressure : Pressure;
        attribute currentDemandLevel : DemandLevel;
        attribute activePumpCount : Integer;
        port input : PotableWaterIn;
        port output : PotableWaterOut;
        port demand : DemandPort;
        part pump1 : Pump;
        part pump2 : Pump;
        part pump3 : Pump;

        exhibit state {
            state LowDemand;
            state ModerateDemand;
            state PeakDemand;
            state EmergencyDemand;
            initial LowDemand;
            transition from LowDemand to ModerateDemand when currentDemandLevel == DemandLevel::moderate;
            transition from ModerateDemand to PeakDemand when currentDemandLevel == DemandLevel::peak;
            transition from PeakDemand to EmergencyDemand when currentDemandLevel == DemandLevel::emergency;
            transition from EmergencyDemand to PeakDemand when currentDemandLevel == DemandLevel::peak;
            transition from PeakDemand to ModerateDemand when currentDemandLevel == DemandLevel::moderate;
            transition from ModerateDemand to LowDemand when currentDemandLevel == DemandLevel::low;
        }

        connection input to pump1.inlet;
        connection input to pump2.inlet;
        connection input to pump3.inlet;
        connection pump1.outlet to output;
        connection pump2.outlet to output;
        connection pump3.outlet to output;
    }

    // ============================================================
    // Transmission Pipeline
    // ============================================================
    part def TransmissionPipeline {
        attribute pipeId : String;
        attribute length : Length;
        attribute diameter : Diameter;
        attribute material : String;
        attribute frictionLoss : Pressure;
        port input : PotableWaterIn;
        port output : PotableWaterOut;
    }

    // ============================================================
    // Water Tower (Elevated Storage)
    // ============================================================
    part def WaterTower {
        attribute name : String;
        attribute capacity : Volume;
        attribute currentVolume : Volume;
        attribute towerHeight : Elevation;
        attribute baseElevation : Elevation;
        port input : PotableWaterIn;
        port output : PotableWaterOut;

        exhibit state {
            state Idle;
            state Charging;
            state Discharging;
            initial Idle;
            transition from Idle to Charging when input.flowRate > output.flowRate;
            transition from Idle to Discharging when output.flowRate > input.flowRate;
            transition from Charging to Idle when currentVolume > 0.95 * capacity;
            transition from Discharging to Idle when currentVolume < 0.1 * capacity;
            transition from Charging to Discharging when output.flowRate > input.flowRate;
            transition from Discharging to Charging when input.flowRate > output.flowRate;
        }
    }

    // ============================================================
    // Distribution Main
    // ============================================================
    part def DistributionMain {
        attribute pipeId : String;
        attribute length : Length;
        attribute diameter : Diameter;
        attribute material : String;
        attribute zoneId : String;
        port input : PotableWaterIn;
        port output : PotableWaterOut;
    }

    // ============================================================
    // Pressure Reducing Valve
    // ============================================================
    part def PressureReducingValve {
        attribute name : String;
        attribute zoneId : String;
        attribute setPressure : Pressure;
        attribute upstreamPressure : Pressure;
        attribute downstreamPressure : Pressure;
        attribute state : ValveState;
        port input : PotableWaterIn;
        port output : PotableWaterOut;

        exhibit state {
            state Open;
            state Throttled;
            state Closed;
            initial Open;
            transition from Open to Throttled when downstreamPressure > setPressure;
            transition from Throttled to Open when downstreamPressure < setPressure;
            transition from Throttled to Closed when downstreamPressure > 1.1 * setPressure;
            transition from Closed to Throttled when downstreamPressure < 1.1 * setPressure;
        }
    }

    // ============================================================
    // Distribution Node (Split Point)
    // ============================================================
    part def DistributionNode {
        attribute nodeId : String;
        attribute location : String;
        attribute splitRatio1 : Efficiency;
        attribute splitRatio2 : Efficiency;
        port input : PotableWaterIn;
        port output1 : PotableWaterOut;
        port output2 : PotableWaterOut;
    }

    // ============================================================
    // Service Meter
    // ============================================================
    part def ServiceMeter {
        attribute meterId : String;
        attribute totalConsumption : MeterReading;
        attribute currentFlowRate : VolumeFlowRate;
        attribute accuracy : Efficiency;
        port input : PotableWaterIn;
        port output : PotableWaterOut;
    }

    // ============================================================
    // Consumer Service Connection
    // ============================================================
    part def ConsumerServiceConnection {
        attribute consumerId : String;
        attribute consumerType : ConsumerType;
        attribute serviceDiameter : Diameter;
        attribute flowRate : VolumeFlowRate;
        port input : PotableWaterIn;
        port output : PotableWaterOut;
        part meter : ServiceMeter;

        connection input to meter.input;
        connection meter.output to output;
    }

    // ============================================================
    // Pressure Sensor
    // ============================================================
    part def PressureSensor {
        attribute sensorId : String;
        attribute location : String;
        attribute measuredPressure : Pressure;
        attribute alarmThresholdHigh : Pressure;
        attribute alarmThresholdLow : Pressure;
        port input : PotableWaterIn;
    }

    // ============================================================
    // Flow Meter (Distribution)
    // ============================================================
    part def FlowMeter {
        attribute meterId : String;
        attribute location : String;
        attribute measuredFlowRate : VolumeFlowRate;
        attribute totalVolume : Volume;
        port input : PotableWaterIn;
        port output : PotableWaterOut;
    }

    // ============================================================
    // Quality Monitor (Distribution)
    // ============================================================
    part def QualityMonitor {
        attribute monitorId : String;
        attribute location : String;
        attribute turbidity : Turbidity;
        attribute chlorineResidual : Concentration;
        attribute pH : Real;
        attribute status : QualityStatus;
        port sample : PotableWaterIn;
    }

    // ============================================================
    // Monitoring System
    // ============================================================
    part def MonitoringSystem {
        attribute name : String;
        attribute activeAlerts : Integer;
        attribute currentMode : MonitoringMode;
        port output : MonitoringOut;
        part pressureSensors[*] : PressureSensor;
        part flowMeters[*] : FlowMeter;
        part qualityMonitors[*] : QualityMonitor;

        exhibit state {
            state Nominal;
            state LeakDetected;
            state PressureAnomaly;
            state QualityViolation;
            initial Nominal;
            transition from Nominal to LeakDetected when activeAlerts > 0 and currentMode == MonitoringMode::leakDetected;
            transition from Nominal to PressureAnomaly when currentMode == MonitoringMode::pressureAnomaly;
            transition from Nominal to QualityViolation when currentMode == MonitoringMode::qualityViolation;
            transition from LeakDetected to Nominal when activeAlerts == 0;
            transition from PressureAnomaly to Nominal when currentMode == MonitoringMode::nominal;
            transition from QualityViolation to Nominal when currentMode == MonitoringMode::nominal;
        }
    }

    // ============================================================
    // Distribution Network
    // ============================================================
    part def DistributionNetwork {
        attribute name : String;
        port input : PotableWaterIn;
        part transmissionMain1 : TransmissionPipeline;
        part waterTower : WaterTower;
        part transmissionMain2 : TransmissionPipeline;
        part prvZone1 : PressureReducingValve;
        part prvZone2 : PressureReducingValve;
        part mainZone1 : DistributionMain;
        part mainZone2 : DistributionMain;
        part nodeSplit1 : DistributionNode;
        part nodeSplit2 : DistributionNode;
        part residentialConsumer1 : ConsumerServiceConnection {
            redefines consumerType = ConsumerType::residential;
        }
        part residentialConsumer2 : ConsumerServiceConnection {
            redefines consumerType = ConsumerType::residential;
        }
        part residentialConsumer3 : ConsumerServiceConnection {
            redefines consumerType = ConsumerType::residential;
        }
        part commercialConsumer1 : ConsumerServiceConnection {
            redefines consumerType = ConsumerType::commercial;
        }
        part commercialConsumer2 : ConsumerServiceConnection {
            redefines consumerType = ConsumerType::commercial;
        }
        part industrialConsumer1 : ConsumerServiceConnection {
            redefines consumerType = ConsumerType::industrial;
        }
        part industrialConsumer2 : ConsumerServiceConnection {
            redefines consumerType = ConsumerType::industrial;
        }

        connection input to transmissionMain1.input;
        connection transmissionMain1.output to transmissionMain2.input;
        connection transmissionMain1.output to waterTower.input;
        connection waterTower.output to transmissionMain2.input;
        connection transmissionMain2.output to prvZone1.input;
        connection transmissionMain2.output to prvZone2.input;
        connection prvZone1.output to mainZone1.input;
        connection prvZone2.output to mainZone2.input;
        connection mainZone1.output to nodeSplit1.input;
        connection mainZone2.output to nodeSplit2.input;
        connection nodeSplit1.output1 to residentialConsumer1.input;
        connection nodeSplit1.output2 to residentialConsumer2.input;
        connection nodeSplit2.output1 to commercialConsumer1.input;
        connection nodeSplit2.output2 to industrialConsumer1.input;
        connection prvZone1.output to residentialConsumer3.input;
        connection prvZone2.output to commercialConsumer2.input;
        connection mainZone1.output to industrialConsumer2.input;
    }

    // ============================================================
    // Top-Level Municipal Water System
    // ============================================================
    part def MunicipalWaterSystem {
        attribute name : String;
        attribute designCapacity : VolumeFlowRate;
        attribute servicePopulation : Integer;
        attribute availability : Availability;
        port sourceOut : RawWaterOut;
        port distributionIn : PotableWaterIn;
        part source : Reservoir;
        part intake : IntakePumpStation;
        part treatment : WaterTreatmentPlant;
        part clearWell : ClearWell;
        part highService : HighServicePumpStation;
        part distribution : DistributionNetwork;
        part monitoring : MonitoringSystem;

        connection source.output to intake.input;
        connection intake.output to treatment.input;
        connection treatment.output to clearWell.input;
        connection clearWell.output to highService.input;
        connection highService.output to distribution.input;
        connection highService.demand to monitoring.output;
        connection monitoring.output to highService.demand;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def ContinuousSupply {
        subject s : MunicipalWaterSystem;
        doc /* The system shall provide continuous drinking water supply to all consumers. */
        constraint { s.availability >= 0.999; }
        constraint { s.intake.standbyReady == true; }
    }

    requirement def WaterQualityCompliance {
        subject s : MunicipalWaterSystem;
        doc /* Treated water shall meet potable water quality standards per regulatory limits. */
        constraint { s.treatment.qualityMonitor.lastReading.turbidity < 1.0 [NTU]; }
        constraint { s.treatment.qualityMonitor.lastReading.chlorineResidual >= 0.2 [mg/L]; }
        constraint { s.treatment.qualityMonitor.lastReading.chlorineResidual <= 4.0 [mg/L]; }
        constraint { s.treatment.qualityMonitor.lastReading.bacteriaLevel == 0 [mg/L]; }
        constraint { s.treatment.qualityMonitor.lastReading.pH >= 6.5; }
        constraint { s.treatment.qualityMonitor.lastReading.pH <= 8.5; }
    }

    requirement def PressureMaintenance {
        subject s : MunicipalWaterSystem;
        doc /* Distribution pressure shall remain within safe operating range at all consumer connections. */
        constraint { s.highService.output.pressure >= 140 [kPa]; }
        constraint { s.highService.output.pressure <= 800 [kPa]; }
        constraint { s.distribution.prvZone1.downstreamPressure <= s.distribution.prvZone1.setPressure; }
        constraint { s.distribution.prvZone2.downstreamPressure <= s.distribution.prvZone2.setPressure; }
    }

    requirement def IntakeRedundancy {
        subject s : IntakePumpStation;
        doc /* Intake pump station shall maintain redundant pumping capability via standby pump. */
        constraint { s.standbyPump.status == PumpStatus::standby or s.standbyPump.status == PumpStatus::running; }
        constraint { s.standbyReady == true; }
    }

    requirement def StorageCapacity {
        subject s : ClearWell;
        doc /* Clear well shall maintain emergency reserve for continuity of supply. */
        constraint { s.emergencyReserve >= 0.25 * s.totalCapacity; }
        constraint { s.currentVolume >= s.emergencyReserve; }
    }

    requirement def WaterTowerBuffer {
        subject s : WaterTower;
        doc /* Water tower shall provide pressure regulation buffer in distribution network. */
        constraint { s.capacity >= 500 [m3]; }
        constraint { s.currentVolume >= 0.1 * s.capacity; }
    }

    requirement def MonitoringCoverage {
        subject s : MonitoringSystem;
        doc /* Monitoring system shall deploy sensors to detect leaks and quality issues. */
        constraint { #s.pressureSensors >= 5; }
        constraint { #s.flowMeters >= 5; }
        constraint { #s.qualityMonitors >= 3; }
    }

    requirement def TreatmentCapacity {
        subject s : WaterTreatmentPlant;
        doc /* Treatment plant shall handle design capacity with re-treatment capability. */
        constraint { s.designCapacity >= 1.0 [m3/s]; }
    }

    requirement def ConsumerCoverage {
        subject s : DistributionNetwork;
        doc /* Distribution network shall serve residential, commercial, and industrial consumers. */
        constraint { #s.residentialConsumer1 + #s.residentialConsumer2 + #s.residentialConsumer3 >= 1; }
        constraint { #s.commercialConsumer1 + #s.commercialConsumer2 >= 1; }
        constraint { #s.industrialConsumer1 + #s.industrialConsumer2 >= 1; }
    }

    requirement def DemandAdaptability {
        subject s : HighServicePumpStation;
        doc /* High service pump station shall adapt to fluctuating demand with staged pump activation. */
        constraint { s.activePumpCount >= 1; }
        constraint { s.activePumpCount <= 3; }
    }

    // ============================================================
    // Requirement Satisfaction
    // ============================================================
    part municipalWaterSystem : MunicipalWaterSystem {
        satisfy ContinuousSupply;
        satisfy WaterQualityCompliance;
        satisfy PressureMaintenance;
        satisfy DemandAdaptability;
    }

    part intakeStation : IntakePumpStation {
        satisfy IntakeRedundancy;
    }

    part clearWellStorage : ClearWell {
        satisfy StorageCapacity;
    }

    part towerBuffer : WaterTower {
        satisfy WaterTowerBuffer;
    }

    part monitoringSystem : MonitoringSystem {
        satisfy MonitoringCoverage;
    }

    part treatmentPlant : WaterTreatmentPlant {
        satisfy TreatmentCapacity;
    }

    part distributionNet : DistributionNetwork {
        satisfy ConsumerCoverage;
    }

}
