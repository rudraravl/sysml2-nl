package DualPhaseSynchronizationSystem {
    private import ScalarValues::*;

    package Definitions {
        unit def Hz;
        unit def deg;
        unit def V;

        value def FrequencyValue :> Real;
        value def PhaseValue :> Real;
        value def VoltageValue :> Real;

        item def OscillatorSignal {
            frequency : FrequencyValue;
            phase : PhaseValue;
        }

        item def PhaseError {
            measuredPhaseDiff : PhaseValue;
            targetPhaseDiff : PhaseValue;
            errorMagnitude : PhaseValue;
        }

        item def ControlSignal {
            frequencyAdjust : FrequencyValue;
            phaseAdjust : PhaseValue;
        }

        item def SyncQuality {
            phaseDifference : PhaseValue;
            qualityLevel : Real;
            errorCount : Integer;
        }

        item def SystemStatus {
            status : String;
            locked : Boolean;
        }

        attribute def StartupSignal;
        attribute def InitializationComplete;
        attribute def PhaseLockAchieved;
        attribute def QualityDegraded;
        attribute def PhaseLockRecovered;
        attribute def PhaseLockLost;
        attribute def ShutdownSignal;

        action def GenerateSignal {
            out signal : OscillatorSignal;
        }

        action def MeasurePhaseDifference {
            in primarySignal : OscillatorSignal;
            in secondarySignal : OscillatorSignal;
            out phaseError : PhaseError;
        }

        action def CalculateCorrection {
            in phaseError : PhaseError;
            out controlSignal : ControlSignal;
        }

        action def RegulatePower {
            in inputVoltage : VoltageValue;
            out outputVoltage : VoltageValue;
        }

        action def MonitorSyncQuality {
            in syncQuality : SyncQuality;
            out systemStatus : SystemStatus;
        }

        action def InitializeSystem;
        action def AchievePhaseLock;
        action def MaintainPhaseLock;
        action def RecoverPhaseLock;

        part def PrimaryOscillator {
            port signalOutPort {
                out signal : OscillatorSignal;
            }
            port controlInPort {
                in controlSignal : ControlSignal;
            }
            port powerInPort {
                in supplyVoltage : VoltageValue;
            }
            attribute nominalFrequency : FrequencyValue = 1000;
            perform action generateSignal : GenerateSignal;
        }

        part def SecondaryOscillator {
            port signalOutPort {
                out signal : OscillatorSignal;
            }
            port controlInPort {
                in controlSignal : ControlSignal;
            }
            port powerInPort {
                in supplyVoltage : VoltageValue;
            }
            attribute nominalFrequency : FrequencyValue = 1000;
            perform action generateSignal : GenerateSignal;
        }

        part def PhaseSynchronizer {
            port primarySignalInPort {
                in primarySignal : OscillatorSignal;
            }
            port secondarySignalInPort {
                in secondarySignal : OscillatorSignal;
            }
            port primaryControlOutPort {
                out primaryControl : ControlSignal;
            }
            port secondaryControlOutPort {
                out secondaryControl : ControlSignal;
            }
            port syncQualityOutPort {
                out syncQuality : SyncQuality;
            }
            port powerInPort {
                in supplyVoltage : VoltageValue;
            }
            attribute targetPhaseDiff : PhaseValue = 90;
            attribute phaseLockThreshold : PhaseValue = 1.0;
            perform action measurePhase : MeasurePhaseDifference;
            perform action calculateCorrection : CalculateCorrection;
        }

        part def PowerSupply {
            port powerInputPort {
                in inputVoltage : VoltageValue;
            }
            port powerOutputPort {
                out outputVoltage : VoltageValue;
            }
            attribute inputVoltageNominal : VoltageValue = 12;
            attribute outputVoltageNominal : VoltageValue = 5;
            perform action regulatePower : RegulatePower;
        }

        part def MonitoringUnit {
            port syncQualityInPort {
                in syncQuality : SyncQuality;
            }
            port statusOutPort {
                out systemStatus : SystemStatus;
            }
            port powerInPort {
                in supplyVoltage : VoltageValue;
            }
            attribute errorCount : Integer = 0;
            attribute qualityThreshold : Real = 0.95;
            attribute degradedThreshold : Real = 0.50;
            attribute currentQualityLevel : Real = 0.0;
            perform action monitorQuality : MonitorSyncQuality;
        }

        state def SystemOperationalStates;

        part def DualPhaseSystem {
            port powerInputPort {
                in inputVoltage : VoltageValue;
            }
            port statusOutputPort {
                out systemStatus : SystemStatus;
            }

            part powerSupply : PowerSupply;
            part primaryOscillator : PrimaryOscillator;
            part secondaryOscillator : SecondaryOscillator;
            part phaseSynchronizer : PhaseSynchronizer;
            part monitoringUnit : MonitoringUnit;

            exhibit state operationalStates : SystemOperationalStates;
        }

        requirement def PhaseSynchronizationRequirement {
            doc /* The system shall maintain a stable 90-degree phase difference between the two output signals. */
        }

        requirement def FrequencyStabilityRequirement {
            doc /* Both oscillators shall generate fundamental signals at 1000 Hz. */
        }

        requirement def PowerRegulationRequirement {
            doc /* The power supply shall convert a 12V input to a regulated 5V operational voltage. */
        }

        requirement def SynchronizationQualityRequirement {
            doc /* The system shall achieve and maintain synchronization quality above 95 percent before entering the synchronized state. */
        }
    }

    package Usages {
        private import Definitions::*;

        action initializeSystem : InitializeSystem;
        action achievePhaseLock : AchievePhaseLock;
        action maintainPhaseLock : MaintainPhaseLock;
        action recoverPhaseLock : RecoverPhaseLock;

        part dualPhaseSystem : DualPhaseSystem {
            bind powerInputPort = powerSupply.powerInputPort;
            bind statusOutputPort = monitoringUnit.statusOutPort;

            flow primaryPowerFlow of VoltageValue
                from powerSupply.powerOutputPort.outputVoltage to primaryOscillator.powerInPort.supplyVoltage;
            flow secondaryPowerFlow of VoltageValue
                from powerSupply.powerOutputPort.outputVoltage to secondaryOscillator.powerInPort.supplyVoltage;
            flow synchronizerPowerFlow of VoltageValue
                from powerSupply.powerOutputPort.outputVoltage to phaseSynchronizer.powerInPort.supplyVoltage;
            flow monitorPowerFlow of VoltageValue
                from powerSupply.powerOutputPort.outputVoltage to monitoringUnit.powerInPort.supplyVoltage;

            flow primarySignalFlow of OscillatorSignal
                from primaryOscillator.signalOutPort.signal to phaseSynchronizer.primarySignalInPort.primarySignal;
            flow secondarySignalFlow of OscillatorSignal
                from secondaryOscillator.signalOutPort.signal to phaseSynchronizer.secondarySignalInPort.secondarySignal;

            flow primaryControlFlow of ControlSignal
                from phaseSynchronizer.primaryControlOutPort.primaryControl to primaryOscillator.controlInPort.controlSignal;
            flow secondaryControlFlow of ControlSignal
                from phaseSynchronizer.secondaryControlOutPort.secondaryControl to secondaryOscillator.controlInPort.controlSignal;

            flow syncQualityFlow of SyncQuality
                from phaseSynchronizer.syncQualityOutPort.syncQuality to monitoringUnit.syncQualityInPort.syncQuality;

            state operationalStates : SystemOperationalStates {
                entry; then standby;

                state standby;
                accept StartupSignal
                    then initializing;

                state initializing {
                    entry initializeSystem;
                }
                accept InitializationComplete
                    then active;

                state active {
                    do achievePhaseLock;
                }
                accept PhaseLockAchieved
                    if monitoringUnit.currentQualityLevel >= monitoringUnit.qualityThreshold
                    then synchronized;
                accept QualityDegraded
                    if monitoringUnit.currentQualityLevel < monitoringUnit.degradedThreshold
                    then degraded;
                accept ShutdownSignal
                    then standby;

                state synchronized {
                    do maintainPhaseLock;
                }
                accept QualityDegraded
                    if monitoringUnit.currentQualityLevel < monitoringUnit.qualityThreshold
                    then degraded;
                accept ShutdownSignal
                    then standby;

                state degraded {
                    do recoverPhaseLock;
                }
                accept PhaseLockRecovered
                    if monitoringUnit.currentQualityLevel >= monitoringUnit.qualityThreshold
                    then synchronized;
                accept PhaseLockLost
                    then active;
                accept ShutdownSignal
                    then standby;
            }
        }

        requirement phaseSyncReq : PhaseSynchronizationRequirement;
        requirement freqReq : FrequencyStabilityRequirement;
        requirement powerReq : PowerRegulationRequirement;
        requirement syncQualityReq : SynchronizationQualityRequirement;
    }
}
