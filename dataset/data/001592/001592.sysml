package TechnologicalChangeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def EfficiencyRating :> Real;
    attribute def ThroughputValue :> Real;
    attribute def ReliabilityScore :> Real;
    attribute def AdaptabilityIndex :> Real;
    
    enum def OperationalMode {
        initialization;
        legacy;
        hybrid;
        fullModern;
        degraded;
    }
    
    enum def TransitionPhase {
        assessment = 1;
        planning = 2;
        implementation = 3;
        validation = 4;
        optimization = 5;
    }
    
    item def DataPacket {
        attribute size : MassValue;
        attribute priority : Real;
        attribute timestamp : TimeValue;
    }
    
    item def ControlCommand {
        attribute targetMode : OperationalMode;
        attribute parameters : Real[*];
    }
    
    item def StatusReport {
        attribute efficiency : EfficiencyRating;
        attribute throughput : ThroughputValue;
        attribute errors : Real;
    }
    
    port def DataPort {
        in dataIn : DataPacket;
        out dataOut : DataPacket;
    }
    
    port def ControlPort {
        in commands : ControlCommand;
        out status : StatusReport;
    }
    
    port def PowerPort {
        in powerSupply : PowerValue;
        out powerDemand : PowerValue;
    }
    
    part def LegacyProcessor {
        attribute processingCapacity : ThroughputValue = 1000.0;
        attribute powerConsumption : PowerValue = 500.0 [W];
        attribute reliability : ReliabilityScore = 0.95;
        attribute latency : TimeValue = 50.0 [s];
        
        port dataInterface : DataPort;
        port control : ControlPort;
        port power : PowerPort;
    }
    
    part def ModernProcessor {
        attribute processingCapacity : ThroughputValue = 5000.0;
        attribute powerConsumption : PowerValue = 300.0 [W];
        attribute reliability : ReliabilityScore = 0.98;
        attribute latency : TimeValue = 10.0 [s];
        attribute aiCapability : Boolean = true;
        
        port dataInterface : DataPort;
        port control : ControlPort;
        port power : PowerPort;
    }
    
    part def TransitionController {
        attribute currentPhase : TransitionPhase = TransitionPhase::assessment;
        attribute transitionProgress : Real = 0.0;
        attribute targetEfficiency : EfficiencyRating = 0.90;
        
        port legacyControl : ControlPort;
        port modernControl : ControlPort;
        port systemControl : ControlPort;
    }
    
    part def DataRouter {
        attribute routingEfficiency : EfficiencyRating = 0.92;
        attribute bufferSize : MassValue = 1000.0 [kg];
        
        port inputPort : DataPort;
        port legacyOutput : DataPort;
        port modernOutput : DataPort;
    }
    
    part def PowerManagementUnit {
        attribute totalCapacity : PowerValue = 2000.0 [W];
        attribute currentLoad : PowerValue;
        attribute efficiency : EfficiencyRating = 0.88;
        
        port mainPower : PowerPort;
        port legacyPower : PowerPort;
        port modernPower : PowerPort;
    }
    
    part def MonitoringSubsystem {
        attribute samplingRate : FrequencyValue = 100.0 [Hz];
        attribute dataRetention : TimeValue = 86400.0 [s];
        
        port legacyMonitor : ControlPort;
        port modernMonitor : ControlPort;
        port analyticsOutput : DataPort;
    }
    
    action def AssessCurrentState {
        in legacyStatus : StatusReport;
        in modernStatus : StatusReport;
        out assessment : OperationalMode;
        out recommendations : Real[*];
    }
    
    action def PlanTransition {
        in currentState : OperationalMode;
        in targetState : OperationalMode;
        in constraints : Real[*];
        out nextPhase : TransitionPhase;
        out resourceAllocation : Real[*];
    }
    
    action def ExecutePhase {
        in phase : TransitionPhase;
        in allocation : Real[*];
        out legacyLoad : Real;
        out modernLoad : Real;
        out phaseComplete : Boolean;
    }
    
    action def ValidatePerformance {
        in actualEfficiency : EfficiencyRating;
        in targetEfficiency : EfficiencyRating;
        in throughput : ThroughputValue;
        out validationResult : Boolean;
        out adjustments : Real[*];
    }
    
    action def ManageTransition {
        first start;
        then merge continuousManagement;
        
        then action assess : AssessCurrentState {
            in legacyStatus : StatusReport;
            in modernStatus : StatusReport;
            out assessment : OperationalMode;
            out recommendations : Real[*];
        }
        
        then action plan : PlanTransition {
            in currentState = assess.assessment;
            in targetState : OperationalMode;
            in constraints : Real[*];
            out nextPhase : TransitionPhase;
            out resourceAllocation : Real[*];
        }
        
        then action execute : ExecutePhase {
            in phase = plan.nextPhase;
            in allocation = plan.resourceAllocation;
            out legacyLoad : Real;
            out modernLoad : Real;
            out phaseComplete : Boolean;
        }
        
        then action validate : ValidatePerformance {
            in actualEfficiency : EfficiencyRating;
            in targetEfficiency : EfficiencyRating;
            in throughput : ThroughputValue;
            out validationResult : Boolean;
            out adjustments : Real[*];
        }
        
        then decide;
            if validate.validationResult and execute.phaseComplete then advancePhase;
            if !validate.validationResult then adjustParameters;
            if validate.validationResult and !execute.phaseComplete then continuousManagement;
        
        action advancePhase;
        then continuousManagement;
        
        action adjustParameters;
        then continuousManagement;
        
        then done;
    }
    
    state def TransitionStateMachine {
        entry; then assessmentState;
        
        state assessmentState {
            entry assign currentPhase = TransitionPhase::assessment;
        }
        accept when transitionProgress >= 0.2;
        then planningState;
        
        state planningState {
            entry assign currentPhase = TransitionPhase::planning;
        }
        accept when transitionProgress >= 0.4;
        then implementationState;
        
        state implementationState {
            entry assign currentPhase = TransitionPhase::implementation;
            
            parallel state dualOperation {
                state legacyActive {
                    entry; then processing;
                    state processing;
                    accept when transitionProgress >= 0.8;
                    then phaseout;
                    state phaseout;
                }
                
                state modernRampup {
                    entry; then initializing;
                    state initializing;
                    accept when transitionProgress >= 0.6;
                    then fullCapacity;
                    state fullCapacity;
                }
            }
        }
        accept when transitionProgress >= 0.8;
        then validationState;
        
        state validationState {
            entry assign currentPhase = TransitionPhase::validation;
        }
        accept when transitionProgress >= 0.95;
        then optimizationState;
        
        state optimizationState {
            entry assign currentPhase = TransitionPhase::optimization;
        }
        accept when transitionProgress >= 1.0;
        then complete;
        
        state complete;
    }
    
    requirement def TechnologicalTransitionRequirement {
        doc /* The system shall enable seamless transition from legacy technology 
             * to modern technology while maintaining operational continuity, 
             * improving performance metrics, and optimizing resource utilization 
             * throughout the transition lifecycle.
             */
        
        subject transitionSystem : HybridTransitionSystem;
        
        require operationalContinuity {
            doc /* The system shall maintain continuous operation with zero 
                 * downtime during the entire transition process.
                 */
        }
        
        require performanceImprovement {
            doc /* The system shall demonstrate progressive improvement in 
                 * efficiency, throughput, and latency as transition progresses.
                 */
        }
        
        require resourceOptimization {
            doc /* The system shall optimize power consumption and processing 
                 * resource allocation between legacy and modern subsystems.
                 */
        }
        
        require adaptiveControl {
            doc /* The system shall adaptively manage transition phases based 
                 * on real-time performance validation and operational constraints.
                 */
        }
    }
    
    requirement <'REQ-2001'> overallEfficiency {
        subject system :> transitionSystem;
        
        assert constraint {
            system.systemEfficiency >= 0.85
        }
    }
    
    requirement <'REQ-2002'> throughputCapacity {
        subject system :> transitionSystem;
        
        assert constraint {
            system.totalThroughput >= 4000.0
        }
    }
    
    requirement <'REQ-2003'> powerBudget {
        subject pmu :> transitionSystem.powerMgmt;
        
        assert constraint {
            pmu.currentLoad <= pmu.totalCapacity
        }
    }
    
    requirement <'REQ-2004'> transitionTimeline {
        subject controller :> transitionSystem.controller;
        
        assert constraint {
            controller.transitionProgress >= 0.0 and 
            controller.transitionProgress <= 1.0
        }
    }
    
    requirement <'REQ-2005'> modernSubsystemPerformance {
        subject modern :> transitionSystem.modernProc;
        
        assert constraint {
            modern.reliability >= 0.98 and
            modern.latency <= 15.0 [s]
        }
    }
    
    part def HybridTransitionSystem {
        doc /* A hybrid system architecture that manages the transition from 
             * legacy to modern technology through adaptive control and resource 
             * optimization. The system continuously monitors performance, 
             * validates transition phases, and dynamically allocates resources 
             * to ensure operational continuity while progressively improving 
             * system capabilities and efficiency.
             */
        
        attribute systemEfficiency : EfficiencyRating;
        attribute totalThroughput : ThroughputValue;
        attribute averageLatency : TimeValue;
        attribute transitionStatus : TransitionPhase;
        
        part legacyProc : LegacyProcessor {
            attribute :>> processingCapacity = 1000.0;
            attribute :>> powerConsumption = 500.0 [W];
            attribute :>> reliability = 0.95;
            attribute :>> latency = 50.0 [s];
        }
        
        part modernProc : ModernProcessor {
            attribute :>> processingCapacity = 5000.0;
            attribute :>> powerConsumption = 300.0 [W];
            attribute :>> reliability = 0.98;
            attribute :>> latency = 10.0 [s];
            attribute :>> aiCapability = true;
        }
        
        part controller : TransitionController {
            attribute :>> currentPhase = TransitionPhase::implementation;
            attribute :>> transitionProgress = 0.65;
            attribute :>> targetEfficiency = 0.90;
            
            perform action manageTransition : ManageTransition;
            perform statemachine transitionStates : TransitionStateMachine;
        }
        
        part router : DataRouter {
            attribute :>> routingEfficiency = 0.92;
            attribute :>> bufferSize = 1000.0 [kg];
        }
        
        part powerMgmt : PowerManagementUnit {
            attribute :>> totalCapacity = 2000.0 [W];
            attribute :>> currentLoad = 720.0 [W];
            attribute :>> efficiency = 0.88;
        }
        
        part monitoring : MonitoringSubsystem {
            attribute :>> samplingRate = 100.0 [Hz];
            attribute :>> dataRetention = 86400.0 [s];
        }
        
        connection routerToLegacy connect router.legacyOutput to legacyProc.dataInterface;
        connection routerToModern connect router.modernOutput to modernProc.dataInterface;
        
        connection controllerToLegacy connect controller.legacyControl to legacyProc.control;
        connection controllerToModern connect controller.modernControl to modernProc.control;
        
        connection powerToLegacy connect powerMgmt.legacyPower to legacyProc.power;
        connection powerToModern connect powerMgmt.modernPower to modernProc.power;
        
        connection monitorLegacy connect monitoring.legacyMonitor to legacyProc.control;
        connection monitorModern connect monitoring.modernMonitor to modernProc.control;
        
        assert constraint efficiencyCalculation {
            systemEfficiency == 
                (legacyProc.reliability * (1.0 - controller.transitionProgress) * 0.4 +
                 modernProc.reliability * controller.transitionProgress * 0.6)
        }
        
        assert constraint throughputCalculation {
            totalThroughput == 
                (legacyProc.processingCapacity * (1.0 - controller.transitionProgress) +
                 modernProc.processingCapacity * controller.transitionProgress)
        }
        
        assert constraint latencyCalculation {
            averageLatency == 
                (legacyProc.latency * (1.0 - controller.transitionProgress) +
                 modernProc.latency * controller.transitionProgress)
        }
        
        assert constraint powerBalance {
            powerMgmt.currentLoad == 
                (legacyProc.powerConsumption * (1.0 - controller.transitionProgress) +
                 modernProc.powerConsumption * controller.transitionProgress)
        }
    }
    
    part transitionSystem : HybridTransitionSystem {
        attribute :>> systemEfficiency = 0.87;
        attribute :>> totalThroughput = 3600.0;
        attribute :>> averageLatency = 26.0 [s];
        attribute :>> transitionStatus = TransitionPhase::implementation;
    }
    
    satisfy TechnologicalTransitionRequirement by transitionSystem;
    satisfy overallEfficiency by transitionSystem;
    satisfy throughputCapacity by transitionSystem;
    satisfy powerBudget by transitionSystem.powerMgmt;
    satisfy transitionTimeline by transitionSystem.controller;
    satisfy modernSubsystemPerformance by transitionSystem.modernProc;
}
