package MetamaterialSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Frequency :> real;
    attribute def Length :> real;
    attribute def Angle :> real;
    attribute def Power :> real;
    attribute def Ratio :> real;
    attribute def Permittivity :> real;
    attribute def Permeability :> real;
    attribute def Temperature :> real;

    item def ElectromagneticWave {
        attribute frequency : Frequency;
        attribute wavelength : Length;
        attribute incidenceAngle : Angle;
        attribute polarization : PolarizationKind;
        attribute powerDensity : Power;
    }

    item def ConditionedWave :> ElectromagneticWave {
        attribute transmittedPowerRatio : Ratio;
        attribute reflectedPowerRatio : Ratio;
        attribute phaseShift : Angle;
        attribute beamSteeringAngle : Angle;
    }

    item def ControlCommand {
        attribute targetFrequency : Frequency;
        attribute targetSteeringAngle : Angle;
        attribute targetTransmissionRatio : Ratio;
    }

    item def HealthStatus {
        attribute maximumCellTemperature : Temperature;
        attribute failedCellRatio : Ratio;
        attribute ready : Boolean;
    }

    enum def PolarizationKind {
        enum linearHorizontal;
        enum linearVertical;
        enum circularLeft;
        enum circularRight;
    }

    enum def OperatingMode {
        enum standby;
        enum tune;
        enum conditionWave;
        enum fault;
    }

    port def WaveInputPort {
        in item incidentWave : ElectromagneticWave;
    }

    port def WaveOutputPort {
        out item conditionedWave : ConditionedWave;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def StatusPort {
        out item status : HealthStatus;
    }

    port def ThermalPort {
        out attribute heatFlow : Power;
        in attribute ambientTemperature : Temperature;
    }

    port def BiasPort {
        out attribute biasVoltage : SI::volt;
        out attribute biasCurrent : SI::ampere;
    }

    part def MetamaterialSystem {
        attribute currentMode : OperatingMode;
        attribute supportedMinimumFrequency : Frequency = 8.0;
        attribute supportedMaximumFrequency : Frequency = 12.0;
        attribute nominalInsertionLoss : Ratio = 0.08;

        port waveIn : WaveInputPort;
        port waveOut : WaveOutputPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port thermalOut : ThermalPort;

        part aperture : MetamaterialAperture;
        part controller : AdaptiveSurfaceController;
        part powerUnit : BiasPowerUnit;
        part thermalManager : ThermalManager;
        part diagnostics : HealthMonitor;

        connect waveIn.incidentWave to aperture.incidentWave;
        connect aperture.conditionedWave to waveOut.conditionedWave;
        connect commandIn.command to controller.command;
        connect controller.biasProfile to powerUnit.biasProfile;
        connect powerUnit.cellBias to aperture.cellBias;
        connect aperture.thermalLoad to thermalManager.thermalLoad;
        connect thermalManager.rejectedHeat to thermalOut.heatFlow;
        connect thermalOut.ambientTemperature to thermalManager.ambientTemperature;
        connect aperture.cellTelemetry to diagnostics.cellTelemetry;
        connect powerUnit.powerTelemetry to diagnostics.powerTelemetry;
        connect diagnostics.status to statusOut.status;

        perform action conditionIncomingWave;
        exhibit state operatingStateMachine;
    }

    part def MetamaterialAperture {
        attribute apertureWidth : Length = 0.250;
        attribute apertureHeight : Length = 0.250;
        attribute cellPitch : Length = 0.005;
        attribute cellCount : Integer = 2500;
        attribute effectiveRelativePermittivity : Permittivity;
        attribute effectiveRelativePermeability : Permeability;
        attribute effectiveRefractiveIndex : real;

        in item incidentWave : ElectromagneticWave;
        out item conditionedWave : ConditionedWave;
        in attribute cellBias : SI::volt[2500];
        out attribute thermalLoad : Power;
        out item cellTelemetry : MetamaterialCellTelemetry;

        part cells : MetamaterialCell[2500];

        perform action synthesizeEffectiveMedium;
        perform action transformWavefront;
    }

    part def MetamaterialCell {
        attribute row : Integer;
        attribute column : Integer;
        attribute resonantFrequency : Frequency;
        attribute phaseResponse : Angle;
        attribute transmissionMagnitude : Ratio;
        attribute localRelativePermittivity : Permittivity;
        attribute localRelativePermeability : Permeability;
        attribute temperature : Temperature;
        attribute healthy : Boolean;

        port bias : BiasPort;
    }

    item def MetamaterialCellTelemetry {
        attribute averageTemperature : Temperature;
        attribute maximumTemperature : Temperature;
        attribute averageTransmissionMagnitude : Ratio;
        attribute failedCells : Integer;
    }

    item def PowerTelemetry {
        attribute supplyVoltage : SI::volt;
        attribute supplyCurrent : SI::ampere;
        attribute deliveredPower : Power;
    }

    item def BiasProfile {
        attribute frequencySetpoint : Frequency;
        attribute phaseGradientX : Angle;
        attribute phaseGradientY : Angle;
        attribute transmissionSetpoint : Ratio;
        attribute cellVoltages : SI::volt[2500];
    }

    part def AdaptiveSurfaceController {
        in item command : ControlCommand;
        out item biasProfile : BiasProfile;

        attribute measuredFrequency : Frequency;
        attribute requestedSteeringAngle : Angle;
        attribute requestedTransmissionRatio : Ratio;

        perform action computePhaseGradient;
        perform action allocateCellBias;
    }

    part def BiasPowerUnit {
        in item biasProfile : BiasProfile;
        out attribute cellBias : SI::volt[2500];
        out item powerTelemetry : PowerTelemetry;

        attribute maximumOutputVoltage : SI::volt = 20.0;
        attribute maximumOutputCurrent : SI::ampere = 2.5;
        attribute conversionEfficiency : Ratio = 0.91;

        perform action regulateCellVoltages;
    }

    part def ThermalManager {
        in attribute thermalLoad : Power;
        in attribute ambientTemperature : Temperature;
        out attribute rejectedHeat : Power;

        attribute heatSinkThermalResistance : real = 1.8;
        attribute maximumAllowedTemperature : Temperature = 358.15;

        perform action rejectWasteHeat;
    }

    part def HealthMonitor {
        in item cellTelemetry : MetamaterialCellTelemetry;
        in item powerTelemetry : PowerTelemetry;
        out item status : HealthStatus;

        attribute failedCellThreshold : Ratio = 0.02;
        attribute overTemperatureLimit : Temperature = 358.15;

        perform action evaluateReadiness;
    }

    action def conditionIncomingWave {
        in item incident : ElectromagneticWave;
        in item command : ControlCommand;
        out item output : ConditionedWave;

        first start;
        then validateFrequency;
        then computeSurfaceResponse;
        then biasMetamaterialCells;
        then transformIncidentWave;
        then emitConditionedWave;
        then done;

        action validateFrequency {
            in item wave : ElectromagneticWave;
            out attribute accepted : Boolean;
        }

        action computeSurfaceResponse {
            in item command : ControlCommand;
            out item profile : BiasProfile;
        }

        action biasMetamaterialCells {
            in item profile : BiasProfile;
            out attribute settled : Boolean;
        }

        action transformIncidentWave {
            in item incident : ElectromagneticWave;
            in item profile : BiasProfile;
            out item transformed : ConditionedWave;
        }

        action emitConditionedWave {
            in item transformed : ConditionedWave;
        }
    }

    action def synthesizeEffectiveMedium {
        in attribute cellVoltages : SI::volt[2500];
        out attribute effectivePermittivity : Permittivity;
        out attribute effectivePermeability : Permeability;
        out attribute effectiveIndex : real;
    }

    action def transformWavefront {
        in item incident : ElectromagneticWave;
        in attribute effectiveIndex : real;
        in item profile : BiasProfile;
        out item conditioned : ConditionedWave;
    }

    action def computePhaseGradient {
        in item command : ControlCommand;
        out attribute gradientX : Angle;
        out attribute gradientY : Angle;
    }

    action def allocateCellBias {
        in attribute gradientX : Angle;
        in attribute gradientY : Angle;
        in attribute transmissionSetpoint : Ratio;
        out item profile : BiasProfile;
    }

    action def regulateCellVoltages {
        in item profile : BiasProfile;
        out attribute cellBias : SI::volt[2500];
    }

    action def rejectWasteHeat {
        in attribute thermalLoad : Power;
        in attribute ambientTemperature : Temperature;
        out attribute rejectedHeat : Power;
    }

    action def evaluateReadiness {
        in item cellTelemetry : MetamaterialCellTelemetry;
        in item powerTelemetry : PowerTelemetry;
        out item status : HealthStatus;
    }

    state def operatingStateMachine {
        entry action initializeSystem;

        state standby;
        state tuning;
        state waveConditioning;
        state degraded;
        state fault;

        transition initial then standby;

        transition standby_to_tuning
            first standby
            accept ControlCommand
            if commandInRange
            then tuning;

        transition tuning_to_conditioning
            first tuning
            if surfaceSettled
            then waveConditioning;

        transition conditioning_to_tuning
            first waveConditioning
            accept ControlCommand
            then tuning;

        transition any_to_degraded
            first waveConditioning
            if minorCellFailuresDetected
            then degraded;

        transition degraded_to_conditioning
            first degraded
            if healthRecovered
            then waveConditioning;

        transition any_to_fault_from_tuning
            first tuning
            if overTemperatureDetected
            then fault;

        transition any_to_fault_from_conditioning
            first waveConditioning
            if overTemperatureDetected
            then fault;

        transition fault_to_standby
            first fault
            accept Reset
            if faultCleared
            then standby;
    }

    action def initializeSystem;
    action def Reset;

    constraint def FrequencyWithinOperatingBand {
        in attribute f : Frequency;
        in attribute fMin : Frequency;
        in attribute fMax : Frequency;
        f >= fMin and f <= fMax;
    }

    constraint def EnergyConservationApproximation {
        in attribute transmitted : Ratio;
        in attribute reflected : Ratio;
        in attribute absorbed : Ratio;
        transmitted + reflected + absorbed <= 1.0;
    }

    constraint def TemperatureLimit {
        in attribute temperature : Temperature;
        in attribute limit : Temperature;
        temperature <= limit;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The metamaterial system shall condition an incident electromagnetic wave by using engineered sub-wavelength cells to synthesize an effective medium that controls transmission, phase, and beam direction. */

        subject system : MetamaterialSystem;

        require constraint {
            system.supportedMinimumFrequency <= system.supportedMaximumFrequency
        }
    }

    requirement def OperatingBandRequirement {
        doc /* The system shall accept and condition incident waves from 8 GHz through 12 GHz. */

        subject system : MetamaterialSystem;

        require constraint FrequencyWithinOperatingBand {
            f = system.waveIn.incidentWave.frequency;
            fMin = system.supportedMinimumFrequency;
            fMax = system.supportedMaximumFrequency;
        }
    }

    requirement def BeamSteeringRequirement {
        doc /* The system shall steer the conditioned wave according to the commanded steering angle while maintaining a continuous phase gradient across the aperture. */

        subject system : MetamaterialSystem;

        require constraint {
            abs(system.waveOut.conditionedWave.beamSteeringAngle - system.commandIn.command.targetSteeringAngle) <= 1.0
        }
    }

    requirement def TransmissionRequirement {
        doc /* The system shall maintain at least 80 percent transmitted power in nominal wave conditioning mode. */

        subject system : MetamaterialSystem;

        require constraint {
            system.waveOut.conditionedWave.transmittedPowerRatio >= 0.80
        }
    }

    requirement def ReflectionRequirement {
        doc /* The system shall limit reflected power to no more than 10 percent during nominal operation. */

        subject system : MetamaterialSystem;

        require constraint {
            system.waveOut.conditionedWave.reflectedPowerRatio <= 0.10
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* The system shall keep all metamaterial cells below the maximum allowed operating temperature. */

        subject system : MetamaterialSystem;

        require constraint TemperatureLimit {
            temperature = system.diagnostics.cellTelemetry.maximumTemperature;
            limit = system.thermalManager.maximumAllowedTemperature;
        }
    }

    requirement def FaultDetectionRequirement {
        doc /* The system shall report not ready when the failed cell ratio exceeds two percent or when the aperture exceeds the thermal limit. */

        subject system : MetamaterialSystem;

        require constraint {
            (system.statusOut.status.failedCellRatio <= system.diagnostics.failedCellThreshold and
             system.statusOut.status.maximumCellTemperature <= system.diagnostics.overTemperatureLimit)
             == system.statusOut.status.ready
        }
    }

    satisfy PrimaryFunctionRequirement by MetamaterialSystem;
    satisfy OperatingBandRequirement by MetamaterialSystem;
    satisfy BeamSteeringRequirement by MetamaterialSystem;
    satisfy TransmissionRequirement by MetamaterialSystem;
    satisfy ReflectionRequirement by MetamaterialSystem;
    satisfy ThermalSafetyRequirement by MetamaterialSystem;
    satisfy FaultDetectionRequirement by MetamaterialSystem;

    part metamaterialWaveConditioner : MetamaterialSystem {
        attribute currentMode = OperatingMode::standby;
    }
}