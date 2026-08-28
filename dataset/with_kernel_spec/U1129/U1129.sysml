package AdaptiveCloakingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::*;
    private import MeasurementReferences::*;

    attribute def PermittivityValue :> ScalarQuantityValue;
    attribute def PermeabilityValue :> ScalarQuantityValue;
    attribute def RefractiveIndexValue :> ScalarQuantityValue;
    attribute def FrequencyValue :> ScalarQuantityValue;
    attribute def AmplitudeValue :> ScalarQuantityValue;
    attribute def EffectivenessValue :> ScalarQuantityValue;
    attribute def PowerValue :> ScalarQuantityValue;

    item def ElectromagneticWave {
        attribute frequency : FrequencyValue;
        attribute amplitude : AmplitudeValue;
        attribute permittivity : PermittivityValue;
        attribute permeability : PermeabilityValue;
    }

    item def WaveCharacteristics {
        attribute direction : Real;
        attribute frequency : FrequencyValue;
        attribute amplitude : AmplitudeValue;
    }

    item def ConfigurationSignal {
        attribute targetPermittivity : PermittivityValue;
        attribute targetPermeability : PermeabilityValue;
    }

    item def PowerSignal {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    attribute def ActivationSignal;
    attribute def DeactivationSignal;
    attribute def CalibrationComplete;
    attribute def WaveDetected;
    attribute def ConfigurationComputed;
    attribute def CloakActive;
    attribute def PerformanceDegraded;

    part def TargetObject;

    action def CalibrateAction;
    action def ComputeConfigAction {
        in characteristics : WaveCharacteristics;
        out config : ConfigurationSignal;
    }
    action def AnalyzeWaveAction {
        in wave : ElectromagneticWave;
        out characteristics : WaveCharacteristics;
    }
    action def TuneCellAction {
        in config : ConfigurationSignal;
    }

    part def MetamaterialCell {
        port configPort {
            in config : ConfigurationSignal;
        }
        attribute currentPermittivity : PermittivityValue;
        attribute currentPermeability : PermeabilityValue;
        perform action tuneCell : TuneCellAction {
            in config = configPort.config;
        }
    }

    part def MetamaterialLayer {
        attribute layerType : String;
        port configPort {
            in config : ConfigurationSignal;
        }
        part cells : MetamaterialCell[1..*];
        flow configFlow of ConfigurationSignal from configPort.config to cells.configPort.config;
    }

    part def MetamaterialShell {
        port configPort {
            in config : ConfigurationSignal;
        }
        part innerLayers : MetamaterialLayer[6] {
            :>> layerType = "WaveBending";
        }
        part outerLayers : MetamaterialLayer[4] {
            :>> layerType = "ImpedanceMatching";
        }
        flow configFlowInner of ConfigurationSignal from configPort.config to innerLayers.configPort.config;
        flow configFlowOuter of ConfigurationSignal from configPort.config to outerLayers.configPort.config;
    }

    part def WaveSensor {
        port wavePort {
            in incomingWave : ElectromagneticWave;
        }
        port characteristicsPort {
            out characteristics : WaveCharacteristics;
        }
        port powerPort {
            in power : PowerSignal;
        }
        perform action analyzeWave : AnalyzeWaveAction {
            in wave = wavePort.incomingWave;
            out characteristics = characteristicsPort.characteristics;
        }
    }

    part def AdaptiveController {
        port characteristicsPort {
            in characteristics : WaveCharacteristics;
        }
        port configPort {
            out config : ConfigurationSignal;
        }
        port powerPort {
            in power : PowerSignal;
        }
        perform action computeConfiguration : ComputeConfigAction {
            in characteristics = characteristicsPort.characteristics;
            out config = configPort.config;
        }
    }

    part def PowerSupply {
        port powerPort {
            out power : PowerSignal;
        }
    }

    part def CloakingSystem {
        exhibit state cloakingStates {
            entry; then standby;
            state standby;
            transition standby_to_initializing
                first standby
                accept ActivationSignal
                then initializing;
            state initializing {
                entry action calibrate : CalibrateAction;
            }
            transition initializing_to_sensing
                first initializing
                accept CalibrationComplete
                then sensing;
            state sensing;
            transition sensing_to_computing
                first sensing
                accept WaveDetected
                then computing;
            state computing {
                entry action computeConfig : ComputeConfigAction;
            }
            transition computing_to_cloaking
                first computing
                accept ConfigurationComputed
                then cloaking;
            state cloaking;
            transition cloaking_to_monitoring
                first cloaking
                accept CloakActive
                then monitoring;
            state monitoring;
            transition monitoring_to_computing
                first monitoring
                accept PerformanceDegraded
                then computing;
            transition monitoring_to_standby
                first monitoring
                accept DeactivationSignal
                then standby;
        }
        
        port activationPort {
            in activation : ActivationSignal;
            in deactivation : DeactivationSignal;
        }
        port environmentWavePort {
            in incomingWave : ElectromagneticWave;
        }
        
        part target : TargetObject;
        part shell : MetamaterialShell;
        part sensors : WaveSensor[8];
        part controller : AdaptiveController;
        part powerSupply : PowerSupply;

        flow powerToController of PowerSignal from powerSupply.powerPort.power to controller.powerPort.power;
        flow powerToSensors of PowerSignal from powerSupply.powerPort.power to sensors.powerPort.power;
        
        flow waveToSensors of ElectromagneticWave from environmentWavePort.incomingWave to sensors.wavePort.incomingWave;
        flow characteristicsToController of WaveCharacteristics from sensors.characteristicsPort.characteristics to controller.characteristicsPort.characteristics;
        flow configToShell of ConfigurationSignal from controller.configPort.config to shell.configPort.config;
    }

    requirement def CloakingEffectivenessRequirement {
        attribute measuredEffectiveness : EffectivenessValue;
        attribute requiredEffectiveness : EffectivenessValue;
        require constraint { measuredEffectiveness >= requiredEffectiveness }
    }
    requirement cloakingEffectivenessReq : CloakingEffectivenessRequirement {
        :>> requiredEffectiveness = 0.99;
    }
    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : TimeValue;
        require constraint { maxResponseTime <= 0.01 [s] }
    }
    requirement responseTimeReq : ResponseTimeRequirement {
        :>> maxResponseTime = 0.01 [s];
    }
    requirement def PowerBudgetRequirement {
        attribute maxPower : PowerValue;
        require constraint { maxPower <= 500 [W] }
    }
    requirement powerBudgetReq : PowerBudgetRequirement {
        :>> maxPower = 500 [W];
    }
}
