package DuearitySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PhaseAngle :> Real;
    attribute def SyncQuality :> Real;
    attribute def SignalAmplitude :> Real;
    
    enum def SystemMode {
        standby;
        initializing;
        active;
        synchronized;
        degraded;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : FrequencyValue;
        attribute phase : PhaseAngle;
    }
    
    item def ControlSignal {
        attribute command : Real;
        attribute timestamp : Real;
    }
    
    port def SignalPort {
        out item signal : ElectricalSignal;
    }
    
    port def ControlPort {
        in item control : ControlSignal;
        out item status : ControlSignal;
    }
    
    part def PrimaryOscillator {
        attribute baseFrequency : FrequencyValue = 1000.0 [Hz];
        attribute outputPhase : PhaseAngle;
        attribute outputAmplitude : SignalAmplitude;
        
        port signalOut : SignalPort;
        port controlIn : ControlPort;
    }
    
    part def SecondaryOscillator {
        attribute baseFrequency : FrequencyValue = 1000.0 [Hz];
        attribute outputPhase : PhaseAngle;
        attribute outputAmplitude : SignalAmplitude;
        attribute phaseOffset : PhaseAngle;
        
        port signalOut : SignalPort;
        port controlIn : ControlPort;
    }
    
    part def PhaseSynchronizer {
        attribute targetPhaseDifference : PhaseAngle = 90.0;
        attribute measuredPhaseDifference : PhaseAngle;
        attribute correctionGain : Real = 0.75;
        attribute syncThreshold : Real = 0.95;
        
        port primaryIn : SignalPort;
        port secondaryIn : SignalPort;
        port primaryControl : ControlPort;
        port secondaryControl : ControlPort;
    }
    
    part def PowerSupply {
        attribute inputVoltage : VoltageValue = 12.0 [V];
        attribute outputVoltage : VoltageValue = 5.0 [V];
        attribute maxCurrent : CurrentValue = 2.0 [A];
        attribute efficiency : Real = 0.85;
        
        port powerOut;
    }
    
    part def MonitoringUnit {
        attribute syncQualityMetric : SyncQuality;
        attribute operationalStatus : SystemMode;
        attribute errorCount : Integer;
        
        port dataIn;
        port statusOut;
    }
    
    part def DuearityCore {
        doc /* The Duearity Core maintains dual synchronized oscillating signals
             * with precise phase relationship. It continuously monitors and adjusts
             * the phase difference between primary and secondary oscillators to
             * achieve stable dual-phase operation essential for coherent signal
             * processing applications.
             */
        
        attribute systemMode : SystemMode = SystemMode::standby;
        attribute overallSyncQuality : SyncQuality;
        attribute operatingFrequency : FrequencyValue = 1000.0 [Hz];
        attribute targetPhaseRelation : PhaseAngle = 90.0;
        attribute totalPowerConsumption : PowerValue;
        
        part primaryOsc : PrimaryOscillator {
            attribute :>> baseFrequency = 1000.0 [Hz];
            attribute :>> outputPhase : PhaseAngle;
            attribute :>> outputAmplitude = 1.0;
        }
        
        part secondaryOsc : SecondaryOscillator {
            attribute :>> baseFrequency = 1000.0 [Hz];
            attribute :>> outputPhase : PhaseAngle;
            attribute :>> outputAmplitude = 1.0;
            attribute :>> phaseOffset = 90.0;
        }
        
        part synchronizer : PhaseSynchronizer {
            attribute :>> targetPhaseDifference = 90.0;
            attribute :>> measuredPhaseDifference : PhaseAngle;
            attribute :>> correctionGain = 0.75;
            attribute :>> syncThreshold = 0.95;
        }
        
        part power : PowerSupply {
            attribute :>> inputVoltage = 12.0 [V];
            attribute :>> outputVoltage = 5.0 [V];
            attribute :>> maxCurrent = 2.0 [A];
            attribute :>> efficiency = 0.85;
        }
        
        part monitor : MonitoringUnit {
            attribute :>> syncQualityMetric : SyncQuality;
            attribute :>> operationalStatus : SystemMode;
            attribute :>> errorCount = 0;
        }
        
        connection primarySignalPath connect primaryOsc.signalOut to synchronizer.primaryIn;
        connection secondarySignalPath connect secondaryOsc.signalOut to synchronizer.secondaryIn;
        connection primaryControlPath connect synchronizer.primaryControl to primaryOsc.controlIn;
        connection secondaryControlPath connect synchronizer.secondaryControl to secondaryOsc.controlIn;
        connection powerDistribution1 connect power.powerOut to primaryOsc.controlIn;
        connection powerDistribution2 connect power.powerOut to secondaryOsc.controlIn;
        connection monitoringPath1 connect synchronizer.primaryIn to monitor.dataIn;
        connection monitoringPath2 connect synchronizer.secondaryIn to monitor.dataIn;
        
        perform action executeDuearityOperation;
    }
    
    action def MeasurePhaseRelationship {
        in primarySignal : ElectricalSignal;
        in secondarySignal : ElectricalSignal;
        out phaseDifference : PhaseAngle;
        out signalQuality : Real;
    }
    
    action def ComputeCorrection {
        in measuredPhase : PhaseAngle;
        in targetPhase : PhaseAngle;
        in gainFactor : Real;
        out correctionValue : Real;
    }
    
    action def ApplyPhaseCorrection {
        in correction : Real;
        inout oscillatorPhase : PhaseAngle;
    }
    
    action def AssessSynchronization {
        in phaseDifference : PhaseAngle;
        in threshold : Real;
        out quality : SyncQuality;
        out isSynchronized : Boolean;
    }
    
    action def UpdateSystemStatus {
        in syncQuality : SyncQuality;
        inout currentMode : SystemMode;
    }
    
    action executeDuearityOperation {
        doc /* Primary operational behavior: Continuously measure phase relationship
             * between dual oscillators, compute necessary corrections, apply adjustments,
             * and assess synchronization quality to maintain stable dual-phase operation.
             */
        
        first start;
        then merge continuousOperation;
        
        then action measurePhase : MeasurePhaseRelationship {
            in primarySignal : ElectricalSignal;
            in secondarySignal : ElectricalSignal;
            out currentPhaseDiff : PhaseAngle;
            out quality : Real;
        }
        
        then action assessSync : AssessSynchronization {
            in phaseDifference = measurePhase.currentPhaseDiff;
            in threshold = 0.95;
            out syncQuality : SyncQuality;
            out synchronized : Boolean;
        }
        
        then decide;
            if assessSync.synchronized then maintainOp;
            if !assessSync.synchronized then correctPhase;
        
        action correctPhase {
            first action computeCorrection : ComputeCorrection {
                in measuredPhase = measurePhase.currentPhaseDiff;
                in targetPhase = 90.0;
                in gainFactor = 0.75;
                out correctionAmount : Real;
            }
            
            then action applyCorrection : ApplyPhaseCorrection {
                in correction = computeCorrection.correctionAmount;
                inout oscillatorPhase : PhaseAngle;
            }
        }
        then merge afterCorrection;
        
        action maintainOp;
        then afterCorrection;
        
        merge afterCorrection;
        then action updateStatus : UpdateSystemStatus {
            in syncQuality = assessSync.syncQuality;
            inout currentMode : SystemMode;
        }
        
        then continuousOperation;
    }
    
    state def DuearityStateMachine {
        entry; then standby;
        
        state standby {
            entry assign systemMode = SystemMode::standby;
        }
        transition standby_to_init
            first standby
            accept powerOnSignal
            then initializing;
        
        state initializing {
            entry assign systemMode = SystemMode::initializing;
            do action initializeOscillators;
        }
        transition init_to_active
            first initializing
            if oscillatorsReady
            then active;
        
        state active {
            entry assign systemMode = SystemMode::active;
            do action beginSynchronization;
        }
        transition active_to_synced
            first active
            if overallSyncQuality > 0.95
            then synchronized;
        transition active_to_degraded
            first active
            if overallSyncQuality < 0.50
            then degraded;
        
        state synchronized {
            entry assign systemMode = SystemMode::synchronized;
            do action maintainSynchronization;
        }
        transition synced_to_active
            first synchronized
            if overallSyncQuality < 0.90
            then active;
        transition synced_to_degraded
            first synchronized
            if overallSyncQuality < 0.50
            then degraded;
        
        state degraded {
            entry assign systemMode = SystemMode::degraded;
            do action attemptRecovery;
        }
        transition degraded_to_active
            first degraded
            if recoverySuccessful
            then active;
        transition degraded_to_standby
            first degraded
            accept shutdownSignal
            then standby;
    }
    
    requirement <'REQ-DUA-001'> primaryFunction {
        doc /* The Duearity System shall maintain continuous dual-phase synchronized
             * oscillation with a phase relationship of 90 degrees between primary and
             * secondary signals during normal operation.
             */
        subject system : DuearityCore;
        
        require constraint {
            system.targetPhaseRelation == 90.0
        }
    }
    
    requirement <'REQ-DUA-002'> synchronizationQuality {
        doc /* The system shall achieve and maintain a synchronization quality factor
             * of at least 0.95 during synchronized operation.
             */
        subject system : DuearityCore;
        
        require constraint {
            system.overallSyncQuality >= 0.95
        }
    }
    
    requirement <'REQ-DUA-003'> phaseMeasurementPrecision {
        doc /* The phase synchronizer shall measure phase differences with a precision
             * of 0.5 degrees or better.
             */
        subject sync : DuearityCore::synchronizer;
    }
    
    requirement <'REQ-DUA-004'> correctionResponseTime {
        doc /* The system shall apply phase corrections within 5 milliseconds of
             * detecting a phase error exceeding the synchronization threshold.
             */
        subject sync : DuearityCore::synchronizer;
    }
    
    requirement <'REQ-DUA-005'> frequencyStability {
        doc /* Both oscillators shall maintain frequency stability within 0.01% of
             * the nominal operating frequency during synchronized operation.
             */
        subject primaryOsc : DuearityCore::primaryOsc;
        subject secondaryOsc : DuearityCore::secondaryOsc;
    }
    
    requirement <'REQ-DUA-006'> powerEfficiency {
        doc /* The power supply shall operate with a minimum efficiency of 80% across
             * the full operational load range.
             */
        subject power : DuearityCore::power;
        
        require constraint {
            power.efficiency >= 0.80
        }
    }
    
    part duearitySystemInstance : DuearityCore {
        :>> systemMode = SystemMode::standby;
        :>> overallSyncQuality = 0.0;
        :>> operatingFrequency = 1000.0 [Hz];
        :>> targetPhaseRelation = 90.0;
        
        part :>> primaryOsc {
            :>> baseFrequency = 1000.0 [Hz];
            :>> outputPhase = 0.0;
            :>> outputAmplitude = 1.0;
        }
        
        part :>> secondaryOsc {
            :>> baseFrequency = 1000.0 [Hz];
            :>> outputPhase = 90.0;
            :>> outputAmplitude = 1.0;
            :>> phaseOffset = 90.0;
        }
        
        part :>> synchronizer {
            :>> targetPhaseDifference = 90.0;
            :>> measuredPhaseDifference = 0.0;
            :>> correctionGain = 0.75;
            :>> syncThreshold = 0.95;
        }
        
        part :>> power {
            :>> inputVoltage = 12.0 [V];
            :>> outputVoltage = 5.0 [V];
            :>> maxCurrent = 2.0 [A];
            :>> efficiency = 0.85;
        }
        
        part :>> monitor {
            :>> syncQualityMetric = 0.0;
            :>> operationalStatus = SystemMode::standby;
            :>> errorCount = 0;
        }
    }
    
    satisfy primaryFunction by duearitySystemInstance;
    satisfy synchronizationQuality by duearitySystemInstance;
    satisfy phaseMeasurementPrecision by duearitySystemInstance.synchronizer;
    satisfy correctionResponseTime by duearitySystemInstance.synchronizer;
    satisfy frequencyStability by duearitySystemInstance.primaryOsc;
    satisfy frequencyStability by duearitySystemInstance.secondaryOsc;
    satisfy powerEfficiency by duearitySystemInstance.power;
}
