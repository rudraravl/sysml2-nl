package 'Gas Distribution System' {
    attribute def pressureDeviation;
    attribute def pressureStabilized;
    attribute def systemReady;
    attribute def highDemandDetected;
    attribute def demandNormalized;
    attribute def maintenanceRequest;
    attribute def maintenanceComplete;
    attribute def criticalPressureExceeded;
    attribute def emergencyResolved;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SafetyThreshold;
    attribute def OperationalLimit;
    
    item def NaturalGas {
        attribute pressure : ISQ::PressureValue;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute flowRate : ISQ::VolumeFlowRateValue;
        attribute composition : String;
    }
    
    port def GasInputPort {
        in item gas : NaturalGas;
    }
    
    port def GasOutputPort {
        out item gas : NaturalGas;
    }
    
    port def ControlPort {
        in attribute command : Real;
        out attribute status : String;
    }
    
    port def SensorPort {
        out attribute measurement : Real;
    }
    
    part def HighPressureSupply {
        doc /* Provides natural gas at high pressure from transmission pipeline. */
        attribute supplyPressure : ISQ::PressureValue;
        attribute supplyTemperature : ISQ::ThermodynamicTemperatureValue;
        port gasOutput : GasOutputPort;
    }
    
    part def PressureRegulationStation {
        doc /* Reduces gas pressure from transmission levels to distribution levels. */
        attribute inletPressure : ISQ::PressureValue;
        attribute outletPressure : ISQ::PressureValue;
        attribute targetPressure : ISQ::PressureValue;
        attribute maxFlowCapacity : ISQ::VolumeFlowRateValue;
        port gasInput : GasInputPort;
        port gasOutput : GasOutputPort;
        port control : ControlPort;
        port pressureSensor : SensorPort;
    }
    
    part def DistributionPipeline {
        doc /* Transports gas through network to delivery points. */
        attribute pipelinePressure : ISQ::PressureValue;
        attribute pipelineLength : ISQ::LengthValue;
        attribute pipeDiameter : ISQ::LengthValue;
        port gasInput : GasInputPort;
        port gasOutput : GasOutputPort[1..*];
    }
    
    part def MeteringStation {
        doc /* Measures gas consumption and regulates flow to end users. */
        attribute measuredFlow : ISQ::VolumeFlowRateValue;
        attribute totalVolume : ISQ::VolumeValue;
        attribute customerPressure : ISQ::PressureValue;
        port gasInput : GasInputPort;
        port gasOutput : GasOutputPort;
        port flowSensor : SensorPort;
    }
    
    part def SafetyValve {
        doc /* Provides overpressure protection by venting excess gas. */
        attribute setPoint : ISQ::PressureValue;
        attribute ventCapacity : ISQ::VolumeFlowRateValue;
        attribute isOpen : Boolean;
        port gasInput : GasInputPort;
        port ventOutput : GasOutputPort;
    }
    
    part def PressureMonitor {
        doc /* Continuously monitors system pressure at critical points. */
        attribute currentPressure : ISQ::PressureValue;
        attribute alarmThreshold : ISQ::PressureValue;
        attribute warningThreshold : ISQ::PressureValue;
        port sensing : GasInputPort;
        port measurement : SensorPort;
    }
    
    action def MeasurePressure {
        in gasStream : NaturalGas;
        out pressureReading : ISQ::PressureValue;
    }
    
    action def RegulateFlow {
        in currentPressure : ISQ::PressureValue;
        in targetPressure : ISQ::PressureValue;
        in maxFlow : ISQ::VolumeFlowRateValue;
        out valvePosition : Real;
        out regulatedGas : NaturalGas;
    }
    
    action def MonitorSafety {
        in systemPressure : ISQ::PressureValue;
        in safetyLimit : ISQ::PressureValue;
        out alarmStatus : Boolean;
    }
    
    action def MeterConsumption {
        in gasFlow : NaturalGas;
        in duration : ISQ::TimeValue;
        out volumeConsumed : ISQ::VolumeValue;
        out flowRate : ISQ::VolumeFlowRateValue;
    }
    
    state def SystemOperationState {
        entry action initializeSystem;
        
        state Startup {
            entry action performSystemChecks;
            do action purgeLines;
        }
        
        state NormalOperation {
            entry action enableFlowControl;
            
            state Monitoring {
                do action continuousMonitoring;
            }
            
            state Regulating {
                do action activePressureControl;
            }
            
            transition first Monitoring
                accept pressureDeviation
                then Regulating;
            
            transition first Regulating
                accept pressureStabilized
                then Monitoring;
        }
        
        state PeakDemand {
            entry action increaseFlowCapacity;
            do action maintainPressure;
        }
        
        state Maintenance {
            entry action isolateSection;
            do action performMaintenance;
            exit action restoreSection;
        }
        
        state Emergency {
            entry action activateEmergencyProtocol;
            do action ventExcessPressure;
        }
        
        transition first Startup
            accept systemReady
            then NormalOperation;
        
        transition first NormalOperation
            accept highDemandDetected
            then PeakDemand;
        
        transition first PeakDemand
            accept demandNormalized
            then NormalOperation;
        
        transition first NormalOperation
            accept maintenanceRequest
            then Maintenance;
        
        transition first Maintenance
            accept maintenanceComplete
            then Startup;
        
        transition first Startup
            accept criticalPressureExceeded
            then Emergency;
        
        transition first NormalOperation
            accept criticalPressureExceeded
            then Emergency;
        
        transition first PeakDemand
            accept criticalPressureExceeded
            then Emergency;
        
        transition first Emergency
            accept emergencyResolved
            then Startup;
    }
    
    action def DistributeGas {
        doc /* Primary system function: deliver natural gas from supply to consumers at safe, regulated pressure. */
        in attribute supplyGas : NaturalGas;
        in attribute targetDeliveryPressure : ISQ::PressureValue;
        in attribute safetyPressureLimit : ISQ::PressureValue;
        out attribute deliveredGas : NaturalGas[1..*];
        out attribute systemStatus : String;
        
        private attribute currentPressure : ISQ::PressureValue;
        private attribute flowStatus : String;
        
        first start;
        then merge operationLoop;
        
        then action measureSupply : MeasurePressure {
            in gasStream = supplyGas;
            out pressureReading;
        }
        
        then action checkSafety : MonitorSafety {
            in systemPressure = measureSupply.pressureReading;
            in safetyLimit = safetyPressureLimit;
            out alarmStatus;
        }
        
        then decide;
            if checkSafety.alarmStatus then emergencyShutdown;
            if not checkSafety.alarmStatus then regulateAndDistribute;
        
        action regulateAndDistribute {
            action regulate : RegulateFlow {
                in currentPressure = measureSupply.pressureReading;
                in targetPressure = targetDeliveryPressure;
                in maxFlow;
                out valvePosition;
                out regulatedGas;
            }
            then action distributeToCustomers {
                then assign deliveredGas := deliveredGas->including(regulate.regulatedGas);
                then assign currentPressure := regulate.regulatedGas.pressure;
                then assign flowStatus := "Normal";
            }
        }
        then operationLoop;
        
        action emergencyShutdown {
            then assign flowStatus := "Emergency Shutdown";
        }
        then done;
    }
    
    requirement def SystemRequirements {
        doc /* Requirements for safe and reliable gas distribution system operation. */
        
        requirement <'GDS-001'> pressureSafetyRequirement {
            doc /* The system shall maintain delivery pressure below maximum safe operating pressure at all times. */
        }
        
        requirement <'GDS-002'> pressureRegulationRequirement {
            doc /* The system shall regulate outlet pressure to within 10% of target delivery pressure. */
        }
        
        requirement <'GDS-003'> continuousSupplyRequirement {
            doc /* The system shall provide uninterrupted gas supply to all connected customers during normal operation. */
        }
        
        requirement <'GDS-004'> emergencyResponseRequirement {
            doc /* The system shall activate safety shutdown within 2 seconds of detecting overpressure condition. */
        }
        
        requirement <'GDS-005'> meteringAccuracyRequirement {
            doc /* The system shall measure gas consumption with accuracy of +/- 1.5% of actual volume. */
        }
    }
    
    part def GasDistributionSystem {
        doc /* 
            A comprehensive natural gas distribution system that receives high-pressure gas from 
            transmission pipelines and delivers it safely to residential, commercial, and industrial 
            customers at regulated lower pressures. The system continuously monitors pressure, 
            regulates flow, meters consumption, and provides safety protection against overpressure 
            conditions through automated control and emergency shutdown capabilities.
        */
        
        attribute maxOperatingPressure : ISQ::PressureValue;
        attribute deliveryPressureTarget : ISQ::PressureValue;
        attribute systemCapacity : ISQ::VolumeFlowRateValue;
        attribute numberOfCustomers : Integer;
        
        part supply : HighPressureSupply {
            attribute :>> supplyPressure = 4000000.0 [SI::Pa];
            attribute :>> supplyTemperature = 288.15 [SI::K];
        }
        
        part regulationStation : PressureRegulationStation {
            attribute :>> targetPressure = 300000.0 [SI::Pa];
            attribute :>> maxFlowCapacity = 5.0 [SI::'m³/s'];
        }
        
        part safetyValve : SafetyValve {
            attribute :>> setPoint = 350000.0 [SI::Pa];
            attribute :>> isOpen = false;
        }
        
        part pressureMonitor : PressureMonitor {
            attribute :>> alarmThreshold = 340000.0 [SI::Pa];
            attribute :>> warningThreshold = 320000.0 [SI::Pa];
        }
        
        part distributionNetwork : DistributionPipeline {
            attribute :>> pipelineLength = 50000.0 [SI::m];
            attribute :>> pipeDiameter = 0.6 [SI::m];
        }
        
        part residentialMeter : MeteringStation {
            attribute :>> customerPressure = 2000.0 [SI::Pa];
        }
        
        part commercialMeter : MeteringStation {
            attribute :>> customerPressure = 5000.0 [SI::Pa];
        }
        
        part industrialMeter : MeteringStation {
            attribute :>> customerPressure = 100000.0 [SI::Pa];
        }
        
        connection supplyToRegulator connect supply.gasOutput to regulationStation.gasInput;
        connection regulatorToSafety connect regulationStation.gasOutput to safetyValve.gasInput;
        connection regulatorToMonitor connect regulationStation.gasOutput to pressureMonitor.sensing;
        connection regulatorToNetwork connect regulationStation.gasOutput to distributionNetwork.gasInput;
        connection networkToResidential connect distributionNetwork.gasOutput[1] to residentialMeter.gasInput;
        connection networkToCommercial connect distributionNetwork.gasOutput[2] to commercialMeter.gasInput;
        connection networkToIndustrial connect distributionNetwork.gasOutput[3] to industrialMeter.gasInput;
        
        exhibit state systemState : SystemOperationState;
        
        perform action distributeGas : DistributeGas {
            in supplyGas.pressure = supply.supplyPressure;
            in targetDeliveryPressure = regulationStation.targetPressure;
            in safetyPressureLimit = safetyValve.setPoint;
            out deliveredGas;
            out systemStatus;
        }
        
        satisfy SystemRequirements::pressureSafetyRequirement;
        satisfy SystemRequirements::pressureRegulationRequirement;
        satisfy SystemRequirements::continuousSupplyRequirement;
        satisfy SystemRequirements::emergencyResponseRequirement;
        satisfy SystemRequirements::meteringAccuracyRequirement;
    }
    
    part operationalSystem : GasDistributionSystem {
        attribute :>> maxOperatingPressure = 350000.0 [SI::Pa];
        attribute :>> deliveryPressureTarget = 300000.0 [SI::Pa];
        attribute :>> systemCapacity = 5.0 [SI::'m³/s'];
        attribute :>> numberOfCustomers = 15000;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Gas Distribution System'::*;

    part testSubject : GasDistributionSystem {
        exhibit state systemState : SystemOperationState;
    }

    action orchestrator {
        attribute testCurrentPressure : ISQ::PressureValue;
        attribute testTargetPressure : ISQ::PressureValue;
        attribute testMaxFlow : ISQ::VolumeFlowRateValue;
        action regulateProbe : RegulateFlow {
            in currentPressure = testCurrentPressure;
            in targetPressure = testTargetPressure;
            in maxFlow = testMaxFlow;
        }
        attribute testPressureDeviation : pressureDeviation;
        attribute testPressureStabilized : pressureStabilized;
        action triggerpressureDeviation send testPressureDeviation to testSubject.systemState;
        action triggerpressureStabilized send testPressureStabilized to testSubject.systemState;
        first regulateProbe;
        then triggerpressureDeviation;
        then triggerpressureStabilized;
    }
}
