package AdaptiveCloakingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----

    value def Permittivity :> Real {
        doc { | Relative permittivity of metamaterial medium. }
        unit "F/m";
    }

    value def Permeability :> Real {
        doc { | Relative permeability of metamaterial medium. }
        unit "H/m";
    }

    value def RefractiveIndex :> Real {
        doc { | Dimensionless refractive index. }
        unit "1";
    }

    value def WaveFrequency :> Real {
        unit "Hz";
    }

    value def WaveAmplitude :> Real {
        unit "V/m";
    }

    value def WaveDirection :> Real {
        doc { | Angle of incidence in degrees. }
        unit "deg";
    }

    value def WavePhase :> Real {
        unit "rad";
    }

    value def Power :> Real {
        unit "W";
    }

    value def Voltage :> Real {
        unit "V";
    }

    value def Current :> Real {
        unit "A";
    }

    value def ElectricFieldStrength :> Real {
        unit "V/m";
    }

    value def MagneticFieldStrength :> Real {
        unit "A/m";
    }

    value def CloakingEfficiency :> Real {
        doc { | Fraction of wave energy successfully redirected. }
        unit "1";
    }

    value def ResidualReflection :> Real {
        doc { | Fraction of incident energy reflected. }
        unit "1";
    }

    // ---- Item Types ----

    item def ElectromagneticWave {
        attribute frequency : WaveFrequency;
        attribute amplitude : WaveAmplitude;
        attribute direction : WaveDirection;
        attribute phase : WavePhase;
        attribute polarization : String;
    }

    item def WaveCharacteristics {
        attribute frequency : WaveFrequency;
        attribute amplitude : WaveAmplitude;
        attribute direction : WaveDirection;
        attribute phase : WavePhase;
        attribute polarization : String;
        attribute sourceSignature : String;
    }

    item def LayerConfiguration {
        attribute layerId : Integer;
        attribute permittivity : Permittivity;
        attribute permeability : Permeability;
        attribute refractiveIndex : RefractiveIndex;
    }

    item def ConfigurationSignal {
        attribute configurations : LayerConfiguration[10];
        attribute timestamp : TimeValue;
    }

    item def PerformanceMetrics {
        attribute residualReflection : ResidualReflection;
        attribute waveDistortion : Real;
        attribute cloakingEfficiency : CloakingEfficiency;
        attribute phaseError : WavePhase;
    }

    item def PowerStatus {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute available : Boolean;
    }

    // ---- Port Definitions ----

    port def WaveDetectionPort {
        out item detectedWave : WaveCharacteristics;
    }

    port def ControlSignalPort {
        out item configuration : ConfigurationSignal;
    }

    port def PerformanceFeedbackPort {
        out item metrics : PerformanceMetrics;
    }

    port def PowerOutputPort {
        out item powerStatus : PowerStatus;
    }

    // ---- Metamaterial Cell ----

    part def MetamaterialCell {
        attribute cellId : Integer;
        attribute row : Integer;
        attribute column : Integer;
        attribute permittivity : Permittivity := 1.0;
        attribute permeability : Permeability := 1.0;
        attribute tuned : Boolean := false;

        port configIn : ControlSignalPort;

        action def TuneCell :> Action {
            in newPermittivity : Permittivity;
            in newPermeability : Permeability;
            out success : Boolean;
        }

        perform action tune : TuneCell {
            in newPermittivity = configIn.configuration.configurations[1].permittivity;
            in newPermeability = configIn.configuration.configurations[1].permeability;
            out success;
        }
    }

    // ---- Metamaterial Layer ----

    part def MetamaterialLayer {
        attribute layerId : Integer;
        attribute layerType : String;
        attribute layerIndex : Integer;
        attribute permittivity : Permittivity := 1.0;
        attribute permeability : Permeability := 1.0;
        attribute refractiveIndex : RefractiveIndex := 1.0;

        port configIn : ControlSignalPort;

        part cells : MetamaterialCell[8, 8];

        connection distributeConfig {
            source configIn;
            target cells.configIn;
        }

        action def ApplyConfiguration :> Action {
            in config : ConfigurationSignal;
            out applied : Boolean;
        }

        perform action apply : ApplyConfiguration {
            in config = configIn.configuration;
            out applied;
        }
    }

    // ---- Metamaterial Shell ----

    part def MetamaterialShell {
        attribute totalLayers : Integer := 10;
        attribute shellRadius : Real;
        attribute shellThickness : Real;

        port configIn : ControlSignalPort;

        part innerLayers : MetamaterialLayer[6] {
            attribute layerType := "bending";
        }

        part outerLayers : MetamaterialLayer[4] {
            attribute layerType := "matching";
        }

        connection innerConfigDistribution {
            source configIn;
            target innerLayers.configIn;
        }

        connection outerConfigDistribution {
            source configIn;
            target outerLayers.configIn;
        }

        action def EstablishGradient :> Action {
            in config : ConfigurationSignal;
            out gradientEstablished : Boolean;
        }

        perform action establish : EstablishGradient {
            in config = configIn.configuration;
            out gradientEstablished;
        }
    }

    // ---- Wave Sensor ----

    part def WaveSensor {
        attribute sensorId : Integer;
        attribute scanDirection : WaveDirection;
        attribute scanRange : Real;
        attribute active : Boolean := false;
        attribute sensitivity : Real;

        port detectionOut : WaveDetectionPort;
        port powerIn : PowerOutputPort;

        action def ScanEnvironment :> Action {
            in power : PowerStatus;
            out detected : WaveCharacteristics;
        }

        action def AnalyzeWave :> Action {
            in rawSignal : ElectromagneticWave;
            out characteristics : WaveCharacteristics;
        }

        perform action scan : ScanEnvironment {
            in power = powerIn.powerStatus;
            out detected = detectionOut.detectedWave;
        }

        perform action analyze : AnalyzeWave;
    }

    // ---- Adaptive Controller ----

    part def AdaptiveController {
        attribute controllerId : Integer;
        attribute processingSpeed : Real;
        attribute memoryCapacity : Real;
        attribute currentConfiguration : ConfigurationSignal;
        attribute adaptationCount : Integer := 0;

        port waveDataIn : WaveDetectionPort;
        port configOut : ControlSignalPort;
        port feedbackIn : PerformanceFeedbackPort;
        port powerIn : PowerOutputPort;

        action def ComputeConfiguration :> Action {
            in waveInfo : WaveCharacteristics;
            in feedback : PerformanceMetrics;
            out config : ConfigurationSignal;
        }

        action def EvaluatePerformance :> Action {
            in metrics : PerformanceMetrics;
            out needsAdaptation : Boolean;
            out efficiency : CloakingEfficiency;
        }

        action def CalculateGradient :> Action {
            in waveInfo : WaveCharacteristics;
            out layerConfigs : LayerConfiguration[10];
        }

        perform action compute : ComputeConfiguration {
            in waveInfo = waveDataIn.detectedWave;
            in feedback = feedbackIn.metrics;
            out config = configOut.configuration;
        }

        perform action evaluate : EvaluatePerformance {
            in metrics = feedbackIn.metrics;
            out needsAdaptation;
            out efficiency;
        }

        perform action calculateGradient : CalculateGradient {
            in waveInfo = waveDataIn.detectedWave;
            out layerConfigs;
        }
    }

    // ---- Power Supply ----

    part def PowerSupply {
        attribute supplyId : Integer;
        attribute outputPower : Power;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute chargeLevel : Real;
        attribute active : Boolean := false;

        port powerOut : PowerOutputPort;

        action def DistributePower :> Action {
            out status : PowerStatus;
        }

        perform action distribute : DistributePower {
            out status = powerOut.powerStatus;
        }
    }

    // ---- Target Object ----

    part def TargetObject {
        attribute objectName : String;
        attribute crossSection : Real;
        attribute concealed : Boolean := false;
    }

    // ---- Performance Monitor ----

    part def PerformanceMonitor {
        attribute monitorId : Integer;
        attribute samplingRate : Real;

        port metricsOut : PerformanceFeedbackPort;

        action def MeasurePerformance :> Action {
            out metrics : PerformanceMetrics;
        }

        perform action measure : MeasurePerformance {
            out metrics = metricsOut.metrics;
        }
    }

    // ---- Cloaking System State Machine ----

    state def CloakingStateMachine {
        entry; then standby;

        state standby {
            entry action enterStandby {
                // Power down active components, maintain minimal monitoring
            }
        }

        transition standby_to_initializing
            first standby
            then initializing
            when powerSupply.active;

        state initializing {
            entry action initComponents {
                // Initialize sensors, controller, and power distribution
            }
        }

        transition initializing_to_calibrating
            first initializing
            then calibrating
            when controller.powerIn.powerStatus.available;

        state calibrating {
            entry action calibrateSystem {
                // Calibrate sensors and baseline metamaterial properties
            }
            do action calibrationSequence;
            exit action storeBaseline;
        }

        transition calibrating_to_sensing
            first calibrating
            then sensing
            when calibrationComplete;

        state sensing {
            entry action enterSensing {
                // Activate all sensors for continuous environmental scanning
            }
            do action continuousScan;
        }

        transition sensing_to_computing
            first sensing
            then solutionComputation
            when waveDetected;

        state solutionComputation {
            entry action computeSolution {
                // Controller calculates required permittivity/permeability per layer
            }
            do action calculateGradient;
        }

        transition computing_to_cloaking
            first solutionComputation
            then activeCloaking
            when configurationComputed;

        state activeCloaking {
            entry action activateCloak {
                // Apply configuration signals to all metamaterial layers
            }
            do action maintainGradient;
        }

        transition cloaking_to_monitoring
            first activeCloaking
            then performanceMonitoring
            when cloakingActive;

        state performanceMonitoring {
            entry action monitorPerformance {
                // Continuously measure cloaking effectiveness
            }
            do action measurePerformance;
        }

        transition monitoring_to_adapting
            first performanceMonitoring
            then solutionComputation
            when performanceDegraded;

        transition monitoring_to_cloaking
            first performanceMonitoring
            then activeCloaking
            when waveChanged;

        transition monitoring_to_sensing
            first performanceMonitoring
            then sensing
            when noThreatDetected;

        transition monitoring_to_standby
            first performanceMonitoring
            then standby
            when deactivateCommanded;

        transition sensing_to_standby
            first sensing
            then standby
            when deactivateCommanded;
    }

    // ---- Top-Level Cloaking System ----

    part def CloakingSystem {
        attribute systemId : String;
        attribute operational : Boolean := false;
        attribute waveDetected : Boolean := false;
        attribute configurationComputed : Boolean := false;
        attribute cloakingActive : Boolean := false;
        attribute performanceDegraded : Boolean := false;
        attribute calibrationComplete : Boolean := false;
        attribute noThreatDetected : Boolean := false;
        attribute deactivateCommanded : Boolean := false;
        attribute waveChanged : Boolean := false;

        part shell : MetamaterialShell;
        part sensors : WaveSensor[8];
        part controller : AdaptiveController;
        part powerSupply : PowerSupply;
        part performanceMonitor : PerformanceMonitor;
        part target : TargetObject;

        // Connections: sensors to controller
        connection sensorDataFlow {
            source sensors.detectionOut;
            target controller.waveDataIn;
        }

        // Connection: controller to shell
        connection controlSignalFlow {
            source controller.configOut;
            target shell.configIn;
        }

        // Connection: performance monitor to controller
        connection feedbackFlow {
            source performanceMonitor.metricsOut;
            target controller.feedbackIn;
        }

        // Connections: power distribution
        connection powerToSensors {
            source powerSupply.powerOut;
            target sensors.powerIn;
        }

        connection powerToController {
            source powerSupply.powerOut;
            target controller.powerIn;
        }

        // Exhibit state machine
        exhibit cloakingBehavior : CloakingStateMachine;

        // System-level actions
        action def ActivateSystem :> Action {
            out activated : Boolean;
        }

        action def DeactivateSystem :> Action {
            out deactivated : Boolean;
        }

        perform action activate : ActivateSystem;
        perform action deactivate : DeactivateSystem;
    }

    // ---- Requirements ----

    requirement def CloakingEffectivenessRequirement {
        doc { | The cloaking system shall reduce detectable radar cross-section by at least 95%. }
        attribute minReduction : Real := 0.95;
        attribute measuredReduction : Real;
        satisfy requirement {
            measuredReduction >= minReduction;
        }
    }

    requirement def ResponseTimeRequirement {
        doc { | The system shall compute and apply a cloaking configuration within 10 milliseconds of wave detection. }
        attribute maxResponseTime : TimeValue := 10 [ms];
        attribute measuredResponseTime : TimeValue;
        satisfy requirement {
            measuredResponseTime <= maxResponseTime;
        }
    }

    requirement def LayerConfigurationRequirement {
        doc { | The shell shall consist of exactly 10 layers: 6 inner bending layers and 4 outer matching layers. }
        attribute innerLayerCount : Integer := 6;
        attribute outerLayerCount : Integer := 4;
        attribute totalLayerCount : Integer := 10;
        satisfy requirement {
            innerLayerCount + outerLayerCount == totalLayerCount;
        }
    }

    requirement def SensorCoverageRequirement {
        doc { | The system shall employ 8 distributed wave sensors providing omnidirectional coverage. }
        attribute sensorCount : Integer := 8;
        attribute coverageAngle : Real := 360;
        satisfy requirement {
            sensorCount == 8;
        }
    }

    requirement def AdaptiveReconfigurationRequirement {
        doc { | The controller shall re-calculate and apply a new configuration within 5 ms when performance degrades or wave characteristics change. }
        attribute maxAdaptationTime : TimeValue := 5 [ms];
        attribute measuredAdaptationTime : TimeValue;
        satisfy requirement {
            measuredAdaptationTime <= maxAdaptationTime;
        }
    }

    requirement def PowerSupplyRequirement {
        doc { | The power supply shall provide sufficient energy for sensors, controller, and active cell tuning simultaneously. }
        attribute minPowerOutput : Power := 500 [W];
        attribute measuredOutput : Power;
        satisfy requirement {
            measuredOutput >= minPowerOutput;
        }
    }

    // ---- Requirement Satisfaction ----

    part def CloakingSystemRequirements {
        part cloakingSystem : CloakingSystem;

        requirement effectivenessReq : CloakingEffectivenessRequirement {
            subject cloakingSystem;
        }

        requirement responseTimeReq : ResponseTimeRequirement {
            subject cloakingSystem;
        }

        requirement layerConfigReq : LayerConfigurationRequirement {
            subject cloakingSystem.shell;
        }

        requirement sensorCoverageReq : SensorCoverageRequirement {
            subject cloakingSystem.sensors;
        }

        requirement adaptiveReq : AdaptiveReconfigurationRequirement {
            subject cloakingSystem.controller;
        }

        requirement powerReq : PowerSupplyRequirement {
            subject cloakingSystem.powerSupply;
        }
    }

}
