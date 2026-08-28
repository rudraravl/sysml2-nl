package DataProcessingUpgradeSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value types with units ----
    value def Power { unit 'kW'; }
    value def Throughput { unit 'Gbps'; }
    value def Latency { unit 'ms'; }
    value def ErrorRate { unit 'percent'; }
    value def Capacity { unit 'TPS'; }
    value def Temperature { unit 'Celsius'; }
    value def Duration { unit 's'; }

    // ---- Enumerations ----
    enum ProcessingMode { legacy, hybrid, fullModern }
    enum TransitionPhase { assessment, planning, implementation, validation, optimization }
    enum RouterState { allLegacy, hybrid, allModern }
    enum HealthStatus { healthy, degraded, critical }
    enum PowerState { normal, loadBalancing, critical }

    // ---- Item definitions ----
    item def DataPacket {
        attribute id : String;
        attribute size : Integer [bits];
        attribute priority : Integer;
        attribute timestamp : Time;
    }

    item def PerformanceMetric {
        attribute throughput : Throughput;
        attribute latency : Latency;
        attribute errorRate : ErrorRate;
        attribute powerConsumption : Power;
        attribute temperature : Temperature;
        attribute timestamp : Time;
    }

    item def ControlCommand {
        attribute targetPhase : TransitionPhase;
        attribute targetMode : ProcessingMode;
        attribute splitRatio : Real;
        attribute modernEnable : Boolean;
        attribute modernDisable : Boolean;
    }

    item def PowerAllocation {
        attribute legacyPower : Power;
        attribute modernPower : Power;
        attribute totalBudget : Power;
    }

    item def AlertEvent {
        attribute severity : Integer;
        attribute description : String;
        attribute source : String;
        attribute timestamp : Time;
    }

    // ---- Port definitions ----
    port def DataInPort { in item data : DataPacket; }
    port def DataOutPort { out item data : DataPacket; }
    port def ControlPort { in item command : ControlCommand; out item ack : ControlCommand; }
    port def PowerPort { in item allocation : PowerAllocation; }
    port def MonitoringPort { out item metric : PerformanceMetric; out item alert : AlertEvent; }

    // ---- Abstract processor ----
    part def Processor {
        port dataIn : DataInPort;
        port dataOut : DataOutPort;
        port powerIn : PowerPort;
        port controlIn : ControlPort;
        port monOut : MonitoringPort;

        attribute maxCapacity : Capacity;
        attribute powerDraw : Power;
        attribute processingLatency : Latency;
        attribute status : HealthStatus = HealthStatus::healthy;
        attribute enabled : Boolean = true;

        action processPacket {
            in data : DataPacket;
            out result : DataPacket;
        }

        action emitMetric {
            out metric : PerformanceMetric;
        }
    }

    // ---- Legacy Processor ----
    part def LegacyProcessor :> Processor {
        attribute maxCapacity = 1000 [TPS];
        attribute powerDraw = 5.0 [kW];
        attribute processingLatency = 50 [ms];
        attribute aiEnabled = false;
        attribute efficiency = 200 [TPS/kW];

        state machine LegacyOperation {
            idle;
            processing;
            transition idle -> processing when dataIn.data->notEmpty();
            transition processing -> idle when dataIn.data->isEmpty();
        }
    }

    // ---- Modern Processor ----
    part def ModernProcessor :> Processor {
        attribute maxCapacity = 5000 [TPS];
        attribute powerDraw = 2.5 [kW];
        attribute processingLatency = 5 [ms];
        attribute aiEnabled = true;
        attribute efficiency = 2000 [TPS/kW];
        attribute initialized : Boolean = false;

        action aiOptimize {
            in metric : PerformanceMetric;
            out adjusted : PerformanceMetric;
        }

        state machine ModernOperation {
            offline {
                entry enabled = false;
                entry initialized = false;
            }
            initializing {
                entry enabled = true;
                do aiOptimize;
            }
            active {
                entry initialized = true;
            }
            transition offline -> initializing when controlIn.command.modernEnable == true;
            transition initializing -> active when initialized == true;
            transition active -> offline when controlIn.command.modernDisable == true;
        }
    }

    // ---- Data Router ----
    part def DataRouter {
        port dataIn : DataInPort;
        port legacyOut : DataOutPort;
        port modernOut : DataOutPort;
        port controlIn : ControlPort;

        attribute mode : RouterState = RouterState::allLegacy;
        attribute splitRatio : Real = 0.0;
        attribute packetsToLegacy : Integer = 0;
        attribute packetsToModern : Integer = 0;

        action route {
            in packet : DataPacket;
            out toLegacy : DataPacket;
            out toModern : DataPacket;
        }

        state machine RoutingMode {
            allLegacy {
                entry splitRatio = 0.0;
                entry mode = RouterState::allLegacy;
            }
            hybrid {
                entry splitRatio = 0.5;
                entry mode = RouterState::hybrid;
            }
            allModern {
                entry splitRatio = 1.0;
                entry mode = RouterState::allModern;
            }
            transition allLegacy -> hybrid when controlIn.command.targetMode == ProcessingMode::hybrid;
            transition hybrid -> allModern when controlIn.command.targetMode == ProcessingMode::fullModern;
            transition hybrid -> allLegacy when controlIn.command.targetMode == ProcessingMode::legacy;
            transition allModern -> hybrid when controlIn.command.targetMode == ProcessingMode::hybrid;
        }
    }

    // ---- Power Management Unit ----
    part def PowerManagementUnit {
        port legacyPowerOut : PowerPort;
        port modernPowerOut : PowerPort;
        port controlIn : ControlPort;
        port monOut : MonitoringPort;

        attribute totalCapacity : Power = 10.0 [kW];
        attribute legacyAllocation : Power = 5.0 [kW];
        attribute modernAllocation : Power = 0.0 [kW];
        attribute currentLoad : Power = 5.0 [kW];
        attribute state : PowerState = PowerState::normal;

        action allocatePower {
            in legacyDemand : Power;
            in modernDemand : Power;
            out allocation : PowerAllocation;
        }

        action balanceLoad {
            // redistribute power between legacy and modern
        }

        state machine PowerStateMachine {
            normal {
                entry state = PowerState::normal;
            }
            loadBalancing {
                entry state = PowerState::loadBalancing;
                do balanceLoad;
            }
            critical {
                entry state = PowerState::critical;
                do balanceLoad;
            }
            transition normal -> loadBalancing when currentLoad > 0.8 * totalCapacity;
            transition loadBalancing -> normal when currentLoad < 0.6 * totalCapacity;
            transition loadBalancing -> critical when currentLoad > 0.95 * totalCapacity;
            transition critical -> loadBalancing when currentLoad < 0.9 * totalCapacity;
        }
    }

    // ---- Monitoring Subsystem ----
    part def MonitoringSubsystem {
        port legacyMonIn : MonitoringPort;
        port modernMonIn : MonitoringPort;
        port controllerOut : MonitoringPort;

        attribute samplingInterval : Duration = 1 [s];
        attribute legacyMetrics : PerformanceMetric;
        attribute modernMetrics : PerformanceMetric;
        attribute aggregateThroughput : Throughput;
        attribute aggregateErrorRate : ErrorRate;
        attribute aggregateLatency : Latency;
        attribute totalPower : Power;

        action collectMetrics {
            in legacy : PerformanceMetric;
            in modern : PerformanceMetric;
            out aggregate : PerformanceMetric;
        }

        action raiseAlert {
            in metric : PerformanceMetric;
            out alert : AlertEvent;
        }

        action aggregatePerformance {
            // combine metrics from both processors
        }
    }

    // ---- Transition Controller ----
    part def TransitionController {
        port routerControl : ControlPort;
        port legacyControl : ControlPort;
        port modernControl : ControlPort;
        port powerControl : ControlPort;
        port monIn : MonitoringPort;

        attribute currentPhase : TransitionPhase = TransitionPhase::assessment;
        attribute currentMode : ProcessingMode = ProcessingMode::legacy;
        attribute splitRatio : Real = 0.0;
        attribute validationThreshold : ErrorRate = 0.1 [percent];
        attribute assessmentComplete : Boolean = false;
        attribute planReady : Boolean = false;
        attribute implementationComplete : Boolean = false;
        attribute validationPassed : Boolean = false;
        attribute validationFailed : Boolean = false;
        attribute optimizationComplete : Boolean = false;

        action assess {
            // gather metrics, evaluate feasibility of upgrade
            out command : ControlCommand;
        }

        action plan {
            // compute migration plan and split schedule
            out command : ControlCommand;
        }

        action implement {
            // bring modern online, adjust split ratio incrementally
            out command : ControlCommand;
        }

        action validate {
            // check metrics against thresholds
            in metric : PerformanceMetric;
            out pass : Boolean;
        }

        action optimize {
            // tune modern system parameters using AI
            out command : ControlCommand;
        }

        state machine TransitionLifecycle {
            assessment {
                entry currentPhase = TransitionPhase::assessment;
                do assess;
            }
            planning {
                entry currentPhase = TransitionPhase::planning;
                do plan;
            }
            implementation {
                entry currentPhase = TransitionPhase::implementation;
                do implement;
            }
            validation {
                entry currentPhase = TransitionPhase::validation;
                do validate;
            }
            optimization {
                entry currentPhase = TransitionPhase::optimization;
                do optimize;
            }
            transition assessment -> planning when assessmentComplete == true;
            transition planning -> implementation when planReady == true;
            transition implementation -> validation when implementationComplete == true;
            transition validation -> implementation when validationFailed == true;
            transition validation -> optimization when validationPassed == true;
            transition optimization -> final when optimizationComplete == true;
        }
    }

    // ---- Overall System ----
    part def UpgradeSystem {
        port externalDataIn : DataInPort;
        port externalDataOut : DataOutPort;
        attribute systemMode : ProcessingMode = ProcessingMode::legacy;
        attribute downtime : Duration = 0 [s];

        part controller : TransitionController;
        part router : DataRouter;
        part legacy : LegacyProcessor;
        part modern : ModernProcessor;
        part power : PowerManagementUnit;
        part monitoring : MonitoringSubsystem;

        // Data flow
        connect externalDataIn to router.dataIn;
        connect router.legacyOut to legacy.dataIn;
        connect router.modernOut to modern.dataIn;
        connect legacy.dataOut to externalDataOut;
        connect modern.dataOut to externalDataOut;

        // Control flow
        connect controller.routerControl to router.controlIn;
        connect controller.legacyControl to legacy.controlIn;
        connect controller.modernControl to modern.controlIn;
        connect controller.powerControl to power.controlIn;

        // Power distribution
        connect power.legacyPowerOut to legacy.powerIn;
        connect power.modernPowerOut to modern.powerIn;

        // Monitoring feedback
        connect legacy.monOut to monitoring.legacyMonIn;
        connect modern.monOut to monitoring.modernMonIn;
        connect monitoring.controllerOut to controller.monIn;

        // System-level state machine
        state systemMode {
            legacyMode {
                entry systemMode = ProcessingMode::legacy;
            }
            hybridMode {
                entry systemMode = ProcessingMode::hybrid;
            }
            fullModernMode {
                entry systemMode = ProcessingMode::fullModern;
            }
            transition legacyMode -> hybridMode when controller.currentPhase == TransitionPhase::implementation;
            transition hybridMode -> fullModernMode when controller.currentPhase == TransitionPhase::optimization;
        }
    }

    // ---- Requirements ----
    requirement def ZeroDowntimeRequirement {
        subject system : UpgradeSystem;
        objective {
            doc "The system shall maintain continuous service availability during the entire upgrade lifecycle with zero downtime."
            constraint { system.downtime == 0 [s] }
        }
    }

    requirement def PowerCapacityRequirement {
        subject pmu : PowerManagementUnit;
        objective {
            doc "Total power consumption shall never exceed the facility's total power capacity."
            constraint { pmu.currentLoad <= pmu.totalCapacity }
        }
    }

    requirement def PerformanceImprovementRequirement {
        subject modern : ModernProcessor;
        subject legacy : LegacyProcessor;
        objective {
            doc "The modern processor shall provide at least five times the throughput capacity of the legacy processor."
            constraint { modern.maxCapacity >= 5 * legacy.maxCapacity }
        }
    }

    requirement def LatencyImprovementRequirement {
        subject modern : ModernProcessor;
        subject legacy : LegacyProcessor;
        objective {
            doc "The modern processor shall achieve at least ten times lower latency than the legacy processor."
            constraint { modern.processingLatency <= legacy.processingLatency / 10 }
        }
    }

    requirement def EnergyEfficiencyRequirement {
        subject modern : ModernProcessor;
        subject legacy : LegacyProcessor;
        objective {
            doc "The modern processor shall consume at most half the power per unit throughput compared to the legacy processor."
            constraint { modern.powerDraw / modern.maxCapacity <= (legacy.powerDraw / legacy.maxCapacity) / 2 }
        }
    }

    requirement def TransitionCompletenessRequirement {
        subject controller : TransitionController;
        objective {
            doc "The transition controller shall complete all five phases of the upgrade lifecycle: assessment, planning, implementation, validation, and optimization."
            constraint { controller.currentPhase == TransitionPhase::optimization }
        }
    }

    requirement def ValidationThresholdRequirement {
        subject controller : TransitionController;
        subject monitoring : MonitoringSubsystem;
        objective {
            doc "Validation shall only pass when the aggregate error rate remains below the defined threshold."
            constraint { monitoring.aggregateErrorRate <= controller.validationThreshold }
        }
    }

    requirement def HybridRoutingRequirement {
        subject router : DataRouter;
        objective {
            doc "During hybrid mode, the data router shall split traffic between legacy and modern processors according to the split ratio commanded by the transition controller."
            constraint { router.mode == RouterState::hybrid implies router.splitRatio > 0.0 and router.splitRatio < 1.0 }
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction satisfy ZeroDowntimeRequirement by UpgradeSystem;
    satisfaction satisfy PowerCapacityRequirement by UpgradeSystem.power;
    satisfaction satisfy PerformanceImprovementRequirement by UpgradeSystem.modern, UpgradeSystem.legacy;
    satisfaction satisfy LatencyImprovementRequirement by UpgradeSystem.modern, UpgradeSystem.legacy;
    satisfaction satisfy EnergyEfficiencyRequirement by UpgradeSystem.modern, UpgradeSystem.legacy;
    satisfaction satisfy TransitionCompletenessRequirement by UpgradeSystem.controller;
    satisfaction satisfy ValidationThresholdRequirement by UpgradeSystem.controller, UpgradeSystem.monitoring;
    satisfaction satisfy HybridRoutingRequirement by UpgradeSystem.router;
}
