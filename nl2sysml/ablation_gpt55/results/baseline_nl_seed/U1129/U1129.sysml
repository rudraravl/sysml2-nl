package MetamaterialCloakingSpecification {
    private import ScalarValues::*;

    attribute def Length_m :> Real {
        doc /* Unit: metre. */
    }

    attribute def Area_m2 :> Real {
        doc /* Unit: square metre. */
    }

    attribute def Frequency_Hz :> Real {
        doc /* Unit: hertz. */
    }

    attribute def Bandwidth_Hz :> Real {
        doc /* Unit: hertz. */
    }

    attribute def Time_s :> Real {
        doc /* Unit: second. */
    }

    attribute def Angle_rad :> Real {
        doc /* Unit: radian. */
    }

    attribute def Power_W :> Real {
        doc /* Unit: watt. */
    }

    attribute def Voltage_V :> Real {
        doc /* Unit: volt. */
    }

    attribute def Current_A :> Real {
        doc /* Unit: ampere. */
    }

    attribute def PowerFluxDensity_W_per_m2 :> Real {
        doc /* Unit: watt per square metre. */
    }

    attribute def ElectricFieldStrength_V_per_m :> Real {
        doc /* Unit: volt per metre. */
    }

    attribute def RCSReduction_dB :> Real {
        doc /* Unit: decibel relative reduction in radar cross section. */
    }

    attribute def Attenuation_dB :> Real {
        doc /* Unit: decibel. */
    }

    attribute def Temperature_K :> Real {
        doc /* Unit: kelvin. */
    }

    attribute def RelativePermittivity :> Real {
        doc /* Unitless relative dielectric permittivity. */
    }

    attribute def RelativePermeability :> Real {
        doc /* Unitless relative magnetic permeability. */
    }

    attribute def Conductivity_S_per_m :> Real {
        doc /* Unit: siemens per metre. */
    }

    attribute def Ratio :> Real {
        doc /* Unitless ratio. */
    }

    attribute def Count :> Integer {
        doc /* Unitless count. */
    }

    enum def CloakMode {
        enum off;
        enum selfTest;
        enum standby;
        enum calibrating;
        enum cloaking;
        enum degraded;
        enum safeBypass;
    }

    enum def PolarizationKind {
        enum linearHorizontal;
        enum linearVertical;
        enum circularRight;
        enum circularLeft;
        enum elliptical;
        enum unknown;
    }

    enum def CommandKind {
        enum powerOn;
        enum powerOff;
        enum enterStandby;
        enum calibrate;
        enum engageCloak;
        enum disengageCloak;
        enum safeBypass;
        enum resetFault;
    }

    enum def HealthKind {
        enum nominal;
        enum warning;
        enum fault;
        enum unsafe;
    }

    item def ElectromagneticWave {
        attribute frequency : Frequency_Hz;
        attribute wavelength : Length_m;
        attribute powerFluxDensity : PowerFluxDensity_W_per_m2;
        attribute electricFieldStrength : ElectricFieldStrength_V_per_m;
        attribute polarizationAngle : Angle_rad;
        attribute polarization : PolarizationKind;
    }

    item def ResidualField {
        attribute frequency : Frequency_Hz;
        attribute electricFieldStrength : ElectricFieldStrength_V_per_m;
        attribute attenuationFromIncident : Attenuation_dB;
    }

    item def CloakCommand {
        attribute command : CommandKind;
        attribute requestedMode : CloakMode;
        attribute requestedCenterFrequency : Frequency_Hz;
        attribute requestedBandwidth : Bandwidth_Hz;
    }

    item def BiasPattern {
        attribute centerFrequency : Frequency_Hz;
        attribute phaseGradient : Angle_rad;
        attribute radialPermittivitySetpoint : RelativePermittivity;
        attribute tangentialPermittivitySetpoint : RelativePermittivity;
        attribute radialPermeabilitySetpoint : RelativePermeability;
        attribute tangentialPermeabilitySetpoint : RelativePermeability;
        attribute updatePeriod : Time_s;
    }

    item def FieldSample {
        attribute measuredFrequency : Frequency_Hz;
        attribute measuredPowerFluxDensity : PowerFluxDensity_W_per_m2;
        attribute measuredPolarizationAngle : Angle_rad;
        attribute sampleAge : Time_s;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    item def ThermalState {
        attribute shellTemperature : Temperature_K;
        attribute controllerTemperature : Temperature_K;
    }

    item def CloakStatus {
        attribute mode : CloakMode;
        attribute health : HealthKind;
        attribute achievedRcsReduction : RCSReduction_dB;
        attribute internalFieldAttenuation : Attenuation_dB;
        attribute tunedCenterFrequency : Frequency_Hz;
        attribute responseTime : Time_s;
    }

    port def ElectromagneticFieldPort {
        in item incidentField : ElectromagneticWave;
        out item redirectedField : ElectromagneticWave;
        out item residualField : ResidualField;
    }

    port def ProtectedZoneFieldPort {
        in item residualField : ResidualField;
    }

    port def CommandPort {
        in item command : CloakCommand;
    }

    port def TelemetryPort {
        out item status : CloakStatus;
        out item thermalState : ThermalState;
    }

    port def FieldSamplePort {
        out item sample : FieldSample;
    }

    port def SensorInputPort {
        in item sample : FieldSample;
    }

    port def BiasCommandPort {
        in item biasPattern : BiasPattern;
    }

    port def BiasOutputPort {
        out item biasPattern : BiasPattern;
    }

    port def DcPowerPort {
        in item suppliedPower : ElectricalPower;
    }

    action def SenseIncidentField {
        in item incidentField : ElectromagneticWave;
        out item sample : FieldSample;
        attribute maximumSampleAge : Time_s = 0.001;
    }

    action def SynthesizeSpatialMaterialResponse {
        in item sample : FieldSample;
        in item command : CloakCommand;
        out item biasPattern : BiasPattern;
        attribute tuningComputationLimit : Time_s = 0.005;
    }

    action def ApplyBiasPattern {
        in item biasPattern : BiasPattern;
        out item appliedBiasPattern : BiasPattern;
        attribute maximumSettlingTime : Time_s = 0.010;
    }

    action def GuideFieldAroundProtectedVolume {
        in item incidentField : ElectromagneticWave;
        in item appliedBiasPattern : BiasPattern;
        out item redirectedField : ElectromagneticWave;
        out item residualField : ResidualField;
        attribute designRcsReduction : RCSReduction_dB = 25.0;
        attribute designInternalAttenuation : Attenuation_dB = 35.0;
    }

    action def MonitorCloakHealth {
        in item thermalState : ThermalState;
        in item residualField : ResidualField;
        out item status : CloakStatus;
        attribute healthUpdatePeriod : Time_s = 0.100;
    }

    action def BendElectromagneticWaveAroundProtectedVolume {
        doc /* Primary high-level function: sense an incident electromagnetic wave, synthesize an anisotropic metamaterial response, bias the shell, and guide the wave around a protected volume so the external scattering signature and internal field exposure are reduced. */
        in item incidentField : ElectromagneticWave;
        in item command : CloakCommand;
        out item redirectedField : ElectromagneticWave;
        out item residualInternalField : ResidualField;
        out item status : CloakStatus;

        first action sense : SenseIncidentField;
        then action synthesize : SynthesizeSpatialMaterialResponse;
        then action applyBias : ApplyBiasPattern;
        then action redirect : GuideFieldAroundProtectedVolume;
        then action monitor : MonitorCloakHealth;
    }

    state def CloakSystemLifecycle {
        state off;
        state selfTest;
        state standby;
        state calibrating;
        state cloaking;
        state degraded;
        state safeBypass;

        transition startInOff first off;
        transition powerOn first off then selfTest;
        transition selfTestPassed first selfTest then standby;
        transition calibrationRequested first standby then calibrating;
        transition calibrationComplete first calibrating then standby;
        transition engageRequested first standby then cloaking;
        transition disengageRequested first cloaking then standby;
        transition healthWarning first cloaking then degraded;
        transition healthRecovered first degraded then cloaking;
        transition unsafeCondition first cloaking then safeBypass;
        transition degradedUnsafeCondition first degraded then safeBypass;
        transition resetAfterSafeBypass first safeBypass then selfTest;
        transition powerOffFromStandby first standby then off;
        transition powerOffFromCloaking first cloaking then off;
    }

    part def SplitRingResonatorCell {
        attribute outerTraceRadius : Length_m = 0.0040;
        attribute traceWidth : Length_m = 0.00035;
        attribute gapWidth : Length_m = 0.00025;
        attribute substrateThickness : Length_m = 0.00080;
        attribute nominalResonantFrequency : Frequency_Hz = 10000000000.0;
        attribute qualityFactor : Ratio = 85.0;
        attribute tunabilityRatio : Ratio = 0.18;
        attribute conductorConductivity : Conductivity_S_per_m = 58000000.0;
    }

    part def ResonatorLattice {
        attribute cellPitch : Length_m = 0.0080;
        attribute rows : Count = 40;
        attribute columns : Count = 40;
        attribute layerArea : Area_m2 = 0.1024;
        part cells[1600] : SplitRingResonatorCell;
    }

    part def AnisotropicLayer {
        attribute radialPermittivity : RelativePermittivity = 0.45;
        attribute tangentialPermittivity : RelativePermittivity = 3.60;
        attribute radialPermeability : RelativePermeability = 0.55;
        attribute tangentialPermeability : RelativePermeability = 2.90;
        attribute layerThickness : Length_m = 0.018;
        attribute lossTangent : Ratio = 0.015;

        port incidentInterface : ElectromagneticFieldPort;
        port exitInterface : ElectromagneticFieldPort;
        port biasInput : BiasCommandPort;

        part lattice : ResonatorLattice;
    }

    part def MetamaterialShell {
        attribute innerRadius : Length_m = 0.75;
        attribute outerRadius : Length_m = 1.05;
        attribute axialLength : Length_m = 2.20;
        attribute layerCount : Count = 6;
        attribute nominalCenterFrequency : Frequency_Hz = 10000000000.0;
        attribute usableBandwidth : Bandwidth_Hz = 750000000.0;
        attribute designRcsReduction : RCSReduction_dB = 25.0;
        attribute designInternalAttenuation : Attenuation_dB = 35.0;

        port outerFieldPort : ElectromagneticFieldPort;
        port innerBoundaryPort : ProtectedZoneFieldPort;
        port biasInputPort : BiasCommandPort;

        part outerLayer : AnisotropicLayer {
            attribute radialPermittivity = 0.75;
            attribute tangentialPermittivity = 2.80;
            attribute radialPermeability = 0.80;
            attribute tangentialPermeability = 2.10;
        }

        part gradientLayer1 : AnisotropicLayer {
            attribute radialPermittivity = 0.62;
            attribute tangentialPermittivity = 3.10;
            attribute radialPermeability = 0.66;
            attribute tangentialPermeability = 2.40;
        }

        part gradientLayer2 : AnisotropicLayer {
            attribute radialPermittivity = 0.50;
            attribute tangentialPermittivity = 3.45;
            attribute radialPermeability = 0.56;
            attribute tangentialPermeability = 2.75;
        }

        part gradientLayer3 : AnisotropicLayer {
            attribute radialPermittivity = 0.42;
            attribute tangentialPermittivity = 3.85;
            attribute radialPermeability = 0.48;
            attribute tangentialPermeability = 3.10;
        }

        part innerLayer : AnisotropicLayer {
            attribute radialPermittivity = 0.36;
            attribute tangentialPermittivity = 4.20;
            attribute radialPermeability = 0.40;
            attribute tangentialPermeability = 3.50;
        }

        connect outerFieldPort to outerLayer.incidentInterface;
        connect outerLayer.exitInterface to gradientLayer1.incidentInterface;
        connect gradientLayer1.exitInterface to gradientLayer2.incidentInterface;
        connect gradientLayer2.exitInterface to gradientLayer3.incidentInterface;
        connect gradientLayer3.exitInterface to innerLayer.incidentInterface;
        connect innerLayer.exitInterface to innerBoundaryPort;

        connect biasInputPort to outerLayer.biasInput;
        connect biasInputPort to gradientLayer1.biasInput;
        connect biasInputPort to gradientLayer2.biasInput;
        connect biasInputPort to gradientLayer3.biasInput;
        connect biasInputPort to innerLayer.biasInput;

        perform action guideField : GuideFieldAroundProtectedVolume;
    }

    part def FieldSensorArray {
        attribute sensorCount : Count = 96;
        attribute samplingFrequency : Frequency_Hz = 200000.0;
        attribute minimumDetectablePowerFluxDensity : PowerFluxDensity_W_per_m2 = 0.000001;
        attribute maximumSampleAge : Time_s = 0.001;

        port observedFieldPort : ElectromagneticFieldPort;
        port sampleOutputPort : FieldSamplePort;

        perform action senseIncidentField : SenseIncidentField;
    }

    part def TuningController {
        attribute processorClockFrequency : Frequency_Hz = 800000000.0;
        attribute controlLoopPeriod : Time_s = 0.005;
        attribute commandedCenterFrequency : Frequency_Hz = 10000000000.0;
        attribute commandedBandwidth : Bandwidth_Hz = 750000000.0;

        port commandPort : CommandPort;
        port sensorInputPort : SensorInputPort;
        port biasOutputPort : BiasOutputPort;
        port telemetryPort : TelemetryPort;

        perform action synthesizeResponse : SynthesizeSpatialMaterialResponse;

        state controllerLifecycle : CloakSystemLifecycle;
    }

    part def BiasNetwork {
        attribute channelCount : Count = 512;
        attribute maximumBiasVoltage : Voltage_V = 24.0;
        attribute maximumBiasCurrent : Current_A = 8.0;
        attribute settlingTime : Time_s = 0.010;

        port commandInputPort : BiasCommandPort;
        port shellBiasOutputPort : BiasOutputPort;
        port powerPort : DcPowerPort;

        perform action applyBiasPattern : ApplyBiasPattern;
    }

    part def ProtectedVolume {
        attribute clearRadius : Length_m = 0.70;
        attribute clearLength : Length_m = 1.80;
        attribute maximumAllowedResidualField : ElectricFieldStrength_V_per_m = 0.50;
        attribute requiredInternalAttenuation : Attenuation_dB = 30.0;

        port boundaryFieldPort : ProtectedZoneFieldPort;
    }

    part def PowerConditioner {
        attribute inputVoltage : Voltage_V = 48.0;
        attribute regulatedVoltage : Voltage_V = 24.0;
        attribute maximumOutputPower : Power_W = 450.0;
        attribute conversionEfficiency : Ratio = 0.92;

        port externalPowerPort : DcPowerPort;
        port conditionedPowerPort : DcPowerPort;
    }

    part def HealthMonitor {
        attribute maximumShellTemperature : Temperature_K = 340.0;
        attribute maximumControllerTemperature : Temperature_K = 330.0;
        attribute healthUpdatePeriod : Time_s = 0.100;

        port telemetryPort : TelemetryPort;
        port protectedZonePort : ProtectedZoneFieldPort;

        perform action monitorHealth : MonitorCloakHealth;
    }

    part def MetamaterialCloakingSystem {
        doc /* System based on metamaterial cloaking. Its primary function is to reduce observability of a protected volume by transforming the propagation path of incident electromagnetic energy around the volume and restoring the wavefront with minimized scattering. */

        attribute operationalCenterFrequency : Frequency_Hz = 10000000000.0;
        attribute minimumOperatingFrequency : Frequency_Hz = 9625000000.0;
        attribute maximumOperatingFrequency : Frequency_Hz = 10375000000.0;
        attribute operationalBandwidth : Bandwidth_Hz = 750000000.0;
        attribute radarCrossSectionReduction : RCSReduction_dB = 25.0;
        attribute internalFieldAttenuation : Attenuation_dB = 35.0;
        attribute maximumResponseTime : Time_s = 0.020;
        attribute maximumPowerConsumption : Power_W = 450.0;
        attribute protectedRadius : Length_m = 0.70;

        port externalFieldPort : ElectromagneticFieldPort;
        port protectedZonePort : ProtectedZoneFieldPort;
        port commandPort : CommandPort;
        port telemetryPort : TelemetryPort;
        port externalPowerPort : DcPowerPort;

        part shell : MetamaterialShell;
        part sensors : FieldSensorArray;
        part controller : TuningController;
        part biasNetwork : BiasNetwork;
        part protectedVolume : ProtectedVolume;
        part powerConditioner : PowerConditioner;
        part healthMonitor : HealthMonitor;

        connect externalFieldPort to shell.outerFieldPort;
        connect externalFieldPort to sensors.observedFieldPort;
        connect shell.innerBoundaryPort to protectedVolume.boundaryFieldPort;
        connect protectedVolume.boundaryFieldPort to protectedZonePort;
        connect protectedVolume.boundaryFieldPort to healthMonitor.protectedZonePort;

        connect sensors.sampleOutputPort to controller.sensorInputPort;
        connect commandPort to controller.commandPort;
        connect controller.biasOutputPort to biasNetwork.commandInputPort;
        connect biasNetwork.shellBiasOutputPort to shell.biasInputPort;

        connect externalPowerPort to powerConditioner.externalPowerPort;
        connect powerConditioner.conditionedPowerPort to biasNetwork.powerPort;

        connect controller.telemetryPort to telemetryPort;
        connect healthMonitor.telemetryPort to telemetryPort;

        perform action primaryFunction : BendElectromagneticWaveAroundProtectedVolume;

        state systemLifecycle : CloakSystemLifecycle;
    }

    constraint def FrequencyWithinOperatingBand {
        in frequency : Frequency_Hz;
        in minimumFrequency : Frequency_Hz;
        in maximumFrequency : Frequency_Hz;
        frequency >= minimumFrequency and frequency <= maximumFrequency
    }

    constraint def ReductionAtLeast {
        in achievedReduction : RCSReduction_dB;
        in requiredReduction : RCSReduction_dB;
        achievedReduction >= requiredReduction
    }

    constraint def AttenuationAtLeast {
        in achievedAttenuation : Attenuation_dB;
        in requiredAttenuation : Attenuation_dB;
        achievedAttenuation >= requiredAttenuation
    }

    constraint def ResponseTimeAtMost {
        in achievedResponseTime : Time_s;
        in requiredResponseTime : Time_s;
        achievedResponseTime <= requiredResponseTime
    }

    constraint def PowerAtMost {
        in achievedPower : Power_W;
        in allowedPower : Power_W;
        achievedPower <= allowedPower
    }

    requirement def HighLevelCloakingFunctionRequirement {
        doc /* The system shall cloak a protected volume by guiding incident electromagnetic waves around the volume using a tunable anisotropic metamaterial shell and by minimizing the restored wavefront scattering signature. */
        subject system : MetamaterialCloakingSystem;
        require constraint {
            system.radarCrossSectionReduction >= 20.0
        }
    }

    requirement def OperatingBandRequirement {
        doc /* The system shall operate over the specified X-band-centered frequency interval. */
        subject system : MetamaterialCloakingSystem;
        require constraint {
            system.minimumOperatingFrequency <= system.operationalCenterFrequency and
            system.operationalCenterFrequency <= system.maximumOperatingFrequency
        }
    }

    requirement def ProtectedVolumeIsolationRequirement {
        doc /* The protected volume shall receive a residual electromagnetic field attenuated by at least 30 dB relative to the incident field. */
        subject system : MetamaterialCloakingSystem;
        require constraint {
            system.internalFieldAttenuation >= 30.0
        }
    }

    requirement def RapidRetuningRequirement {
        doc /* The tunable metamaterial cloak shall retune quickly enough to respond to a changed incident field or command. */
        subject system : MetamaterialCloakingSystem;
        require constraint {
            system.maximumResponseTime <= 0.020
        }
    }

    requirement def PowerLimitRequirement {
        doc /* The system shall remain within the allocated electrical power envelope during active cloaking. */
        subject system : MetamaterialCloakingSystem;
        require constraint {
            system.maximumPowerConsumption <= 500.0
        }
    }

    requirement def SafeBypassRequirement {
        doc /* The system shall transition to safe bypass when unsafe thermal or residual-field conditions are detected. */
        subject system : MetamaterialCloakingSystem;
        require constraint {
            system.healthMonitor.maximumShellTemperature <= 340.0 and
            system.protectedVolume.maximumAllowedResidualField <= 0.50
        }
    }

    part metamaterialCloak : MetamaterialCloakingSystem;

    requirement highLevelCloakingFunction : HighLevelCloakingFunctionRequirement {
        subject system = metamaterialCloak;
    }

    requirement operatingBand : OperatingBandRequirement {
        subject system = metamaterialCloak;
    }

    requirement protectedVolumeIsolation : ProtectedVolumeIsolationRequirement {
        subject system = metamaterialCloak;
    }

    requirement rapidRetuning : RapidRetuningRequirement {
        subject system = metamaterialCloak;
    }

    requirement powerLimit : PowerLimitRequirement {
        subject system = metamaterialCloak;
    }

    requirement safeBypass : SafeBypassRequirement {
        subject system = metamaterialCloak;
    }
}
