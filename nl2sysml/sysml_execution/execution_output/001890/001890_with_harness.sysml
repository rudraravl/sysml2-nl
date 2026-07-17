package WaterSupplyNetworkSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WaterPressure :> ISQ::PressureValue;
    attribute def WaterFlowRate :> ISQ::VolumetricFlowRateValue;
    attribute def WaterVolume :> ISQ::VolumeValue;
    attribute def WaterLevel :> ISQ::LengthValue;
    attribute def WaterTemperature :> ISQ::TemperatureValue;
    attribute def ChemicalConcentration :> ISQ::MassConcentrationValue;
    
    attribute def WaterQuality {
        attribute turbidity : ScalarValues::Real;
        attribute pH : ScalarValues::Real;
        attribute chlorineLevel : ChemicalConcentration;
        attribute bacteriaCount : ScalarValues::Real;
    }
    
    item def PotableWater {
        attribute quality : WaterQuality;
        attribute temperature : WaterTemperature;
    }
    
    port def WaterInletPort {
        attribute pressure : WaterPressure;
        attribute flowRate : WaterFlowRate;
        in item waterIn : PotableWater;
    }
    
    port def WaterOutletPort {
        attribute pressure : WaterPressure;
        attribute flowRate : WaterFlowRate;
        out item waterOut : PotableWater;
    }
    
    port def WaterServicePort {
        attribute pressure : WaterPressure;
        attribute flowRate : WaterFlowRate;
        out item waterSupply : PotableWater;
    }
    
    part def WaterSource {
        port sourceOutlet : WaterOutletPort;
        attribute capacity : WaterVolume;
        attribute currentLevel : WaterLevel;
        attribute replenishmentRate : WaterFlowRate;
    }
    
    part def IntakePumpStation {
        port intakeInlet : WaterInletPort;
        port intakeOutlet : WaterOutletPort;
        attribute pumpCapacity : ISQ::PowerValue;
        attribute operatingPressure : WaterPressure;
        
        part primaryPump {
            attribute power : ISQ::PowerValue;
            attribute efficiency : ScalarValues::Real;
        }
        
        part standbyPump {
            attribute power : ISQ::PowerValue;
            attribute efficiency : ScalarValues::Real;
        }
    }
    
    part def WaterTreatmentPlant {
        port rawWaterInlet : WaterInletPort;
        port treatedWaterOutlet : WaterOutletPort;
        attribute treatmentCapacity : WaterFlowRate;
        
        part coagulationUnit {
            attribute chemicalDosage : ChemicalConcentration;
        }
        
        part sedimentationBasin {
            attribute retentionTime : ISQ::TimeValue;
        }
        
        part filtrationSystem {
            attribute filterEfficiency : ScalarValues::Real;
            attribute backwashCycle : ISQ::TimeValue;
        }
        
        part disinfectionUnit {
            attribute chlorinationRate : ChemicalConcentration;
            attribute contactTime : ISQ::TimeValue;
        }
        
        perform action treatWater {
            first start;
            then action receiveRawWater;
            then action coagulate;
            then action sediment;
            then action filterAction;
            then action disinfect;
            then action testQuality {
                out qualityAcceptable : ScalarValues::Boolean;
            }
            then decide;
                if testQuality.qualityAcceptable then releaseWater;
                if !testQuality.qualityAcceptable then retreatWater;
            action releaseWater;
            then done;
            action retreatWater;
            then coagulate;
        }
    }
    
    part def ClearWellStorage {
        port storageInlet : WaterInletPort;
        port storageOutlet : WaterOutletPort;
        attribute totalCapacity : WaterVolume;
        attribute currentVolume : WaterVolume;
        attribute waterLevel : WaterLevel;
        attribute emergencyReserve : WaterVolume;
    }
    
    part def HighServicePumpStation {
        port pumpInlet : WaterInletPort;
        port pumpOutlet : WaterOutletPort;
        attribute pumpCapacity : ISQ::PowerValue;
        attribute dischargePressure : WaterPressure;
        
        part pump1 {
            attribute power : ISQ::PowerValue;
            attribute efficiency : ScalarValues::Real;
        }
        
        part pump2 {
            attribute power : ISQ::PowerValue;
            attribute efficiency : ScalarValues::Real;
        }
        
        part pump3 {
            attribute power : ISQ::PowerValue;
            attribute efficiency : ScalarValues::Real;
        }
        
        state pumpOperation {
            entry; then idle;
            
            state idle;
            transition idle_to_operating
                first idle
                accept DemandIncrease
                then operating;
            
            state operating {
                state singlePumpActive;
                state dualPumpActive;
                state allPumpsActive;
                
                transition single_to_dual
                    first singlePumpActive
                    accept ModerateDemand
                    then dualPumpActive;
                
                transition dual_to_all
                    first dualPumpActive
                    accept PeakDemand
                    then allPumpsActive;
                
                transition all_to_dual
                    first allPumpsActive
                    accept DemandDecrease
                    then dualPumpActive;
                
                transition dual_to_single
                    first dualPumpActive
                    accept LowDemand
                    then singlePumpActive;
            }
            
            transition operating_to_idle
                first operating
                accept NoDemand
                then idle;
        }
    }
    
    part def TransmissionMain {
        port mainInlet : WaterInletPort;
        port mainOutlet : WaterOutletPort;
        attribute length : ISQ::LengthValue;
        attribute diameter : ISQ::LengthValue;
        attribute material : ScalarValues::String;
        attribute pressureLoss : WaterPressure;
        attribute maxFlowCapacity : WaterFlowRate;
    }
    
    part def ElevatedStorageTank {
        port tankInlet : WaterInletPort;
        port tankOutlet : WaterOutletPort;
        attribute totalCapacity : WaterVolume;
        attribute currentVolume : WaterVolume;
        attribute elevation : ISQ::LengthValue;
        attribute staticPressure : WaterPressure;
    }
    
    part def DistributionPipeline {
        port pipelineInlet : WaterInletPort;
        port pipelineOutlet : WaterOutletPort;
        attribute length : ISQ::LengthValue;
        attribute diameter : ISQ::LengthValue;
        attribute material : ScalarValues::String;
        attribute pressureLoss : WaterPressure;
    }
    
    part def PressureReducingValve {
        port valveInlet : WaterInletPort;
        port valveOutlet : WaterOutletPort;
        attribute inletPressure : WaterPressure;
        attribute outletPressure : WaterPressure;
        attribute setPoint : WaterPressure;
    }
    
    part def DistributionNode {
        port nodeInlet : WaterInletPort;
        port nodeOutlet1 : WaterOutletPort;
        port nodeOutlet2 : WaterOutletPort;
        port nodeOutlet3 : WaterOutletPort;
        attribute nodePressure : WaterPressure;
    }
    
    part def ConsumerServiceConnection {
        port serviceInlet : WaterServicePort;
        attribute serviceAddress : ScalarValues::String;
        attribute meterReading : WaterVolume;
        attribute averageDemand : WaterFlowRate;
        attribute peakDemand : WaterFlowRate;
    }
    
    part def PressureSensor {
        attribute measuredPressure : WaterPressure;
        attribute sensorAccuracy : ScalarValues::Real;
        attribute calibrationDate : ScalarValues::String;
    }
    
    part def FlowMeter {
        attribute measuredFlow : WaterFlowRate;
        attribute totalVolume : WaterVolume;
        attribute meterAccuracy : ScalarValues::Real;
    }
    
    part def QualityMonitor {
        attribute turbidityReading : ScalarValues::Real;
        attribute pHReading : ScalarValues::Real;
        attribute chlorineReading : ChemicalConcentration;
        attribute samplingInterval : ISQ::TimeValue;
    }
    
    requirement def SystemRequirements {
        doc /* The water supply network shall provide continuous, safe, and adequate potable water to all consumers. */
        
        requirement <'WSN-REQ-001'> continuousSupply {
            doc /* The system shall maintain water supply availability of at least 99.5% annually. */
        }
        
        requirement <'WSN-REQ-002'> waterQualityCompliance {
            doc /* Delivered water shall meet drinking water quality standards at all times. */
        }
        
        requirement <'WSN-REQ-003'> minimumPressure {
            doc /* The system shall maintain minimum pressure of 138 kPa at all consumer connection points. */
        }
        
        requirement <'WSN-REQ-004'> maximumPressure {
            doc /* The system shall not exceed maximum pressure of 550 kPa at any consumer connection point. */
        }
        
        requirement <'WSN-REQ-005'> redundancyProvision {
            doc /* Critical components shall have backup systems to ensure continuity of service during failures. */
        }
        
        requirement <'WSN-REQ-006'> storageCapacity {
            doc /* The system shall maintain storage capacity equivalent to at least one day of average demand. */
        }
    }
    
    action def MonitorSystemPressure {
        in sensorData : WaterPressure[*];
        out averagePressure : WaterPressure;
        out minimumPressure : WaterPressure;
        out pressureAlarm : ScalarValues::Boolean;
    }
    
    action def ControlPumpOperation {
        in currentPressure : WaterPressure;
        in targetPressure : WaterPressure;
        in currentDemand : WaterFlowRate;
        out pumpSpeed : ScalarValues::Real;
        out numberOfPumps : ScalarValues::Integer;
    }
    
    action def DetectLeakage {
        in flowIn : WaterFlowRate;
        in flowOut : WaterFlowRate;
        in pressureDrop : WaterPressure;
        out leakDetected : ScalarValues::Boolean;
        out estimatedLeakRate : WaterFlowRate;
        out leakLocation : ScalarValues::String;
    }
    
    action def ManageWaterQuality {
        in rawQuality : WaterQuality;
        in targetQuality : WaterQuality;
        out chemicalDosage : ChemicalConcentration;
        out treatmentAdjustment : ScalarValues::Real;
    }
    
    action def SupplyWaterToNetwork {
        first start;
        then merge monitoringLoop;
        
        then action monitorPressure : MonitorSystemPressure {
            out networkPressure : WaterPressure;
            out minPressure : WaterPressure;
            out alarm : ScalarValues::Boolean;
        }
        
        then decide;
            if monitorPressure.alarm then adjustPumping;
            if !monitorPressure.alarm then checkLeaks;
        
        action adjustPumping : ControlPumpOperation {
            in currentPressure = monitorPressure.networkPressure;
            out pumpSpeed;
            out numberOfPumps;
        }
        then monitoringLoop;
        
        action checkLeaks : DetectLeakage {
            out leakDetected;
            out estimatedLeakRate;
        }
        
        then decide;
            if checkLeaks.leakDetected then initiateRepair;
            if !checkLeaks.leakDetected then monitorQuality;
        
        action initiateRepair;
        then monitoringLoop;
        
        action monitorQuality : ManageWaterQuality {
            out chemicalDosage;
        }
        then monitoringLoop;
    }
    
    part def WaterSupplyNetwork;
    
    part waterSupplyNetwork : WaterSupplyNetwork {
        doc /* 
            A comprehensive municipal water supply network that sources raw water from a reservoir,
            treats it to potable standards, stores it in elevated tanks, and distributes it through
            a pressurized pipeline network to residential, commercial, and industrial consumers.
            The system ensures continuous delivery of safe drinking water while maintaining adequate
            pressure and quality throughout the distribution network.
        */
        
        part reservoir : WaterSource {
            port :>> sourceOutlet;
        }
        
        part intakePumps : IntakePumpStation {
            port :>> intakeInlet;
            port :>> intakeOutlet;
        }
        
        part treatmentPlant : WaterTreatmentPlant {
            port :>> rawWaterInlet;
            port :>> treatedWaterOutlet;
            
            perform action :>> treatWater;
        }
        
        part clearWell : ClearWellStorage {
            port :>> storageInlet;
            port :>> storageOutlet;
        }
        
        part highServicePumps : HighServicePumpStation {
            port :>> pumpInlet;
            port :>> pumpOutlet;
        }
        
        part transmissionPipeline : TransmissionMain {
            port :>> mainInlet;
            port :>> mainOutlet;
        }
        
        part elevatedTank : ElevatedStorageTank {
            port :>> tankInlet;
            port :>> tankOutlet;
        }
        
        part primaryDistribution : DistributionPipeline {
            port :>> pipelineInlet;
            port :>> pipelineOutlet;
        }
        
        part pressureValve : PressureReducingValve {
            port :>> valveInlet;
            port :>> valveOutlet;
        }
        
        part distributionNode1 : DistributionNode {
            port :>> nodeInlet;
            port :>> nodeOutlet1;
            port :>> nodeOutlet2;
            port :>> nodeOutlet3;
        }
        
        part secondaryDistribution1 : DistributionPipeline {
            port :>> pipelineInlet;
            port :>> pipelineOutlet;
        }
        
        part secondaryDistribution2 : DistributionPipeline {
            port :>> pipelineInlet;
            port :>> pipelineOutlet;
        }
        
        part distributionNode2 : DistributionNode {
            port :>> nodeInlet;
            port :>> nodeOutlet1;
            port :>> nodeOutlet2;
            port :>> nodeOutlet3;
        }
        
        part residentialConsumer1 : ConsumerServiceConnection {
            port :>> serviceInlet;
        }
        
        part residentialConsumer2 : ConsumerServiceConnection {
            port :>> serviceInlet;
        }
        
        part commercialConsumer1 : ConsumerServiceConnection {
            port :>> serviceInlet;
        }
        
        part industrialConsumer1 : ConsumerServiceConnection {
            port :>> serviceInlet;
        }
        
        part residentialConsumer3 : ConsumerServiceConnection {
            port :>> serviceInlet;
        }
        
        part pressureMonitor1 : PressureSensor;
        part pressureMonitor2 : PressureSensor;
        part pressureMonitor3 : PressureSensor;
        part mainFlowMeter : FlowMeter;
        part distributionFlowMeter : FlowMeter;
        part qualityMonitor1 : QualityMonitor;
        part qualityMonitor2 : QualityMonitor;
        
        connect reservoir.sourceOutlet to intakePumps.intakeInlet;
        connect intakePumps.intakeOutlet to treatmentPlant.rawWaterInlet;
        connect treatmentPlant.treatedWaterOutlet to clearWell.storageInlet;
        connect clearWell.storageOutlet to highServicePumps.pumpInlet;
        connect highServicePumps.pumpOutlet to transmissionPipeline.mainInlet;
        connect transmissionPipeline.mainOutlet to elevatedTank.tankInlet;
        connect elevatedTank.tankOutlet to primaryDistribution.pipelineInlet;
        connect primaryDistribution.pipelineOutlet to pressureValve.valveInlet;
        connect pressureValve.valveOutlet to distributionNode1.nodeInlet;
        connect distributionNode1.nodeOutlet1 to secondaryDistribution1.pipelineInlet;
        connect distributionNode1.nodeOutlet2 to secondaryDistribution2.pipelineInlet;
        connect distributionNode1.nodeOutlet3 to residentialConsumer1.serviceInlet;
        connect secondaryDistribution1.pipelineOutlet to commercialConsumer1.serviceInlet;
        connect secondaryDistribution2.pipelineOutlet to distributionNode2.nodeInlet;
        connect distributionNode2.nodeOutlet1 to residentialConsumer2.serviceInlet;
        connect distributionNode2.nodeOutlet2 to industrialConsumer1.serviceInlet;
        connect distributionNode2.nodeOutlet3 to residentialConsumer3.serviceInlet;
        
        perform action supplyOperation : SupplyWaterToNetwork;
        
        satisfy SystemRequirements::continuousSupply;
        satisfy SystemRequirements::waterQualityCompliance;
        satisfy SystemRequirements::minimumPressure;
        satisfy SystemRequirements::maximumPressure;
        satisfy SystemRequirements::redundancyProvision;
        satisfy SystemRequirements::storageCapacity;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import WaterSupplyNetworkSystem::*;

    action orchestrator {
        attribute testCurrentPressure : WaterPressure;
        action adjustPumpingProbe : ControlPumpOperation {
            in currentPressure = testCurrentPressure;
        }
        first adjustPumpingProbe;
    }
}
