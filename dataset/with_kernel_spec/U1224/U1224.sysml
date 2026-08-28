package LiveUpgradeSystem {
    private import ScalarValues::*;
    
    unit def W;
    unit def Gbps;
    unit def ms;
    unit def percent;
    
    item def Data;
    
    attribute def Power { unit W; }
    attribute def Throughput { unit Gbps; }
    attribute def Latency { unit ms; }
    attribute def ErrorRate { unit percent; }
    attribute def Efficiency;
    
    attribute def AssessmentComplete;
    attribute def PlanComplete;
    attribute def ImplementationComplete;
    attribute def ValidationComplete;
    attribute def OptimizationComplete;
    attribute def FailbackSignal;
    
    port def DataPort {
        in data : Data;
    }
    port def PowerPort {
        in p : Power;
    }
    port def ControlPort {
        in command;
    }
    port def MonitorPort {
        out metrics;
    }
    
    part def Processor {
        attribute powerConsumption : Power;
        attribute throughput : Throughput;
        attribute latency : Latency;
        port dataIn : DataPort;
        port dataOut : DataPort;
        port powerIn : PowerPort;
        port controlPort : ControlPort;
    }
    
    part def LegacyProcessor :> Processor {
        attribute powerConsumption = 5000 [W];
        attribute throughput = 10 [Gbps];
        attribute latency = 50 [ms];
    }
    
    part def ModernProcessor :> Processor {
        attribute powerConsumption = 2000 [W];
        attribute throughput = 100 [Gbps];
        attribute latency = 5 [ms];
        attribute hasAI : Boolean = true;
    }
    
    part def DataRouter {
        port dataIn : DataPort;
        port legacyOut : DataPort;
        port modernOut : DataPort;
        port controlPort : ControlPort;
        attribute routingMode : String;
        action routeData {
            in data : Data;
        }
    }
    
    part def PowerManagementUnit {
        attribute totalCapacity : Power = 10000 [W];
        attribute legacyLoad : Power;
        attribute modernLoad : Power;
        port powerIn : PowerPort;
        port legacyPowerOut : PowerPort;
        port modernPowerOut : PowerPort;
        port controlPort : ControlPort;
        action distributePower;
        constraint powerLimit {
            legacyLoad + modernLoad <= totalCapacity
        }
    }
    
    part def MonitoringSubsystem {
        port legacyMonitorIn : DataPort;
        port modernMonitorIn : DataPort;
        port controllerOut : MonitorPort;
        attribute efficiency : Efficiency;
        attribute errorRate : ErrorRate;
        attribute throughput : Throughput;
        action gatherMetrics;
    }
    
    part def TransitionController {
        port legacyControl : ControlPort;
        port modernControl : ControlPort;
        port routerControl : ControlPort;
        port monitorIn : MonitorPort;
        port powerControl : ControlPort;
        
        state def TransitionPhases {
            entry; then assessment;
            state assessment;
            accept AssessmentComplete then planning;
            state planning;
            accept PlanComplete then implementation;
            state implementation;
            accept ImplementationComplete then validation;
            state validation;
            accept ValidationComplete then optimization;
            state optimization;
            accept OptimizationComplete then done;
            accept FailbackSignal then assessment;
        }
        
        state def SystemModes {
            entry; then legacyMode;
            state legacyMode;
            accept ImplementationComplete then hybridMode;
            state hybridMode;
            accept ValidationComplete then fullModernMode;
            state fullModernMode;
        }
        
        state controllerBehavior parallel {
            state phases : TransitionPhases;
            state modes : SystemModes;
        }
    }
    
    part def UpgradeSystem {
        part legacy : LegacyProcessor;
        part modern : ModernProcessor;
        part router : DataRouter;
        part power : PowerManagementUnit;
        part monitor : MonitoringSubsystem;
        part controller : TransitionController;
        
        connect router.legacyOut to legacy.dataIn;
        connect router.modernOut to modern.dataIn;
        connect power.legacyPowerOut to legacy.powerIn;
        connect power.modernPowerOut to modern.powerIn;
        connect monitor.legacyMonitorIn to legacy.dataOut;
        connect monitor.modernMonitorIn to modern.dataOut;
        connect monitor.controllerOut to controller.monitorIn;
        connect controller.legacyControl to legacy.controlPort;
        connect controller.modernControl to modern.controlPort;
        connect controller.routerControl to router.controlPort;
        connect controller.powerControl to power.controlPort;
    }
    
    requirement def SeamlessMigration {
        doc /* The system must migrate from legacy to modern without downtime. */
    }
    
    requirement def PowerLimit {
        subject powerUnit : PowerManagementUnit;
        doc /* Total power consumption must not exceed capacity. */
        constraint { powerUnit.legacyLoad + powerUnit.modernLoad <= powerUnit.totalCapacity }
    }
    
    requirement def ContinuousService {
        doc /* Data routing must be maintained throughout the transition. */
    }
    
    part upgradeSystem : UpgradeSystem;
}
