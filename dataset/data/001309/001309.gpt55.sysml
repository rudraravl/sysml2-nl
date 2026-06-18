package VisibleLightPhotonCounterModel {

    import ScalarValues::*;

    enum def OperatingMode {
        enum off;
        enum cooldown;
        enum standby;
        enum armed;
        enum counting;
        enum calibration;
        enum fault;
        enum safeShutdown;
    }

    enum def PhotonBand {
        enum visibleBlue;
        enum visibleGreen;
        enum visibleRed;
        enum broadbandVisible;
    }

    enum def FaultCode {
        enum none;
        enum detectorOverTemperature;
        enum detectorUnderTemperature;
        enum biasOutOfRange;
        enum darkCountExcessive;
        enum cryocoolerFailure;
        enum readoutSaturation;
        enum opticalOverload;
        enum communicationLost;
    }

    enum def CountQuality {
        enum valid;
        enum rejectedBelowThreshold;
        enum rejectedPileup;
        enum rejectedDarkEstimate;
        enum saturated;
    }

    attribute def Nanometer :> Real {
        attribute unitSymbol : String = "nm";
    }

    attribute def Kelvin :> Real {
        attribute unitSymbol : String = "K";
    }

    attribute def Volt :> Real {
        attribute unitSymbol : String = "V";
    }

    attribute def Milliampere :> Real {
        attribute unitSymbol : String = "mA";
    }

    attribute def Watt :> Real {
        attribute unitSymbol : String = "W";
    }

    attribute def Picosecond :> Real {
        attribute unitSymbol : String = "ps";
    }

    attribute def Nanosecond :> Real {
        attribute unitSymbol : String = "ns";
    }

    attribute def Hertz :> Real {
        attribute unitSymbol : String = "Hz";
    }

    attribute def CountsPerSecond :> Real {
        attribute unitSymbol : String = "counts/s";
    }

    attribute def Percent :> Real {
        attribute unitSymbol : String = "%";
    }

    attribute def BitRate :> Real {
        attribute unitSymbol : String = "Mbit/s";
    }

    attribute def Dimensionless :> Real {
        attribute unitSymbol : String = "1";
    }

    item def VisiblePhoton {
        attribute wavelength : Nanometer;
        attribute arrivalTime : Picosecond;
        attribute opticalPowerEquivalent : Watt;
        attribute band : PhotonBand;
    }

    item def PhotonFlux {
        attribute meanWavelength : Nanometer;
        attribute minimumWavelength : Nanometer;
        attribute maximumWavelength : Nanometer;
        attribute estimatedPhotonRate : CountsPerSecond;
        attribute opticalPower : Watt;
    }

    item def AvalanchePulse {
        attribute peakAmplitude : Volt;
        attribute riseTime : Picosecond;
        attribute pulseWidth : Nanosecond;
        attribute generatedTime : Picosecond;
    }

    item def DiscriminatedPulse {
        attribute thresholdCrossingTime : Picosecond;
        attribute normalizedAmplitude : Dimensionless;
        attribute quality : CountQuality;
    }

    item def PhotonCountEvent {
        attribute eventTime : Picosecond;
        attribute channelId : Integer;
        attribute quality : CountQuality;
        attribute estimatedWavelength : Nanometer;
    }

    item def CountFrame {
        attribute frameStartTime : Picosecond;
        attribute frameDuration : Nanosecond;
        attribute validCountTotal : Integer;
        attribute rejectedCountTotal : Integer;
        attribute meanCountRate : CountsPerSecond;
    }

    item def CommandMessage {
        attribute requestedMode : OperatingMode;
        attribute requestedBias : Volt;
        attribute requestedGateWidth : Nanosecond;
        attribute requestedIntegrationTime : Nanosecond;
    }

    item def StatusMessage {
        attribute currentMode : OperatingMode;
        attribute detectorTemperature : Kelvin;
        attribute detectorBias : Volt;
        attribute darkCountRate : CountsPerSecond;
        attribute liveCountRate : CountsPerSecond;
        attribute activeFault : FaultCode;
        attribute ready : Boolean;
    }

    item def CoolingPower {
        attribute heatLift : Watt;
        attribute coldTipTemperature : Kelvin;
    }

    item def ElectricalPower {
        attribute voltage : Volt;
        attribute current : Milliampere;
        attribute power : Watt;
    }

    item def BiasSupply {
        attribute voltage : Volt;
        attribute currentLimit : Milliampere;
        attribute enabled : Boolean;
    }

    item def ThermalTelemetry {
        attribute coldStageTemperature : Kelvin;
        attribute detectorTemperature : Kelvin;
        attribute heatSinkTemperature : Kelvin;
    }

    port def OpticalInputPort {
        in item incidentFlux : PhotonFlux;
        in item photon : VisiblePhoton;
    }

    port def OpticalOutputPort {
        out item conditionedFlux : PhotonFlux;
        out item photon : VisiblePhoton;
    }

    port def PulsePort {
        out item avalanchePulse : AvalanchePulse;
    }

    port def AnalogPulseInputPort {
        in item avalanchePulse : AvalanchePulse;
    }

    port def DigitalPulsePort {
        out item discriminatedPulse : DiscriminatedPulse;
    }

    port def DigitalPulseInputPort {
        in item discriminatedPulse : DiscriminatedPulse;
    }

    port def CountEventPort {
        out item photonCountEvent : PhotonCountEvent;
        out item countFrame : CountFrame;
    }

    port def CountEventInputPort {
        in item photonCountEvent : PhotonCountEvent;
        in item countFrame : CountFrame;
    }

    port def CommandPort {
        in item command : CommandMessage;
    }

    port def StatusPort {
        out item status : StatusMessage;
    }

    port def ElectricalPowerInputPort {
        in item inputPower : ElectricalPower;
    }

    port def ElectricalPowerOutputPort {
        out item outputPower : ElectricalPower;
    }

    port def BiasOutputPort {
        out item detectorBias : BiasSupply;
    }

    port def BiasInputPort {
        in item detectorBias : BiasSupply;
    }

    port def CoolingPort {
        out item coolingPower : CoolingPower;
    }

    port def CoolingInputPort {
        in item coolingPower : CoolingPower;
    }

    port def ThermalTelemetryPort {
        out item thermalTelemetry : ThermalTelemetry;
    }

    port def ThermalTelemetryInputPort {
        in item thermalTelemetry : ThermalTelemetry;
    }

    connection def OpticalPath {
        end source : OpticalOutputPort;
        end target : OpticalInputPort;
    }

    connection def AnalogPulsePath {
        end source : PulsePort;
        end target : AnalogPulseInputPort;
    }

    connection def DigitalPulsePath {
        end source : DigitalPulsePort;
        end target : DigitalPulseInputPort;
    }

    connection def CountDataPath {
        end source : CountEventPort;
        end target : CountEventInputPort;
    }

    connection def PowerPath {
        end source : ElectricalPowerOutputPort;
        end target : ElectricalPowerInputPort;
    }

    connection def BiasPath {
        end source : BiasOutputPort;
        end target : BiasInputPort;
    }

    connection def CoolingPath {
        end source : CoolingPort;
        end target : CoolingInputPort;
    }

    connection def ThermalTelemetryPath {
        end source : ThermalTelemetryPort;
        end target : ThermalTelemetryInputPort;
    }

    action def ConditionIncidentLight {
        in item rawFlux : PhotonFlux;
        out item filteredFlux : PhotonFlux;
        attribute passbandMinimum : Nanometer = 400.0;
        attribute passbandMaximum : Nanometer = 700.0;
        attribute insertionLoss : Percent = 8.0;
    }

    action def CoolDetector {
        in item commandedCooling : CoolingPower;
        out item measuredThermalState : ThermalTelemetry;
        attribute targetDetectorTemperature : Kelvin = 6.5;
        attribute maximumCooldownTime : Real = 900.0;
    }

    action def ApplyDetectorBias {
        in item requestedBias : BiasSupply;
        out item establishedBias : BiasSupply;
        attribute nominalBiasVoltage : Volt = 7.2;
        attribute maximumBiasVoltage : Volt = 8.5;
        attribute currentLimit : Milliampere = 0.050;
    }

    action def ConvertPhotonToAvalanchePulse {
        in item photon : VisiblePhoton;
        in item bias : BiasSupply;
        out item pulse : AvalanchePulse;
        attribute quantumEfficiencyAt550nm : Percent = 88.0;
        attribute nominalGain : Dimensionless = 50000.0;
        attribute timingJitter : Picosecond = 35.0;
    }

    action def DiscriminateAvalanchePulse {
        in item pulse : AvalanchePulse;
        out item digitalPulse : DiscriminatedPulse;
        attribute discriminatorThreshold : Volt = 0.025;
        attribute deadTime : Nanosecond = 20.0;
        attribute pileupRejectionWindow : Nanosecond = 5.0;
    }

    action def TimeTagPulse {
        in item digitalPulse : DiscriminatedPulse;
        out item event : PhotonCountEvent;
        attribute timeTagResolution : Picosecond = 10.0;
        attribute channelId : Integer = 1;
    }

    action def AccumulatePhotonCounts {
        in item event : PhotonCountEvent;
        out item frame : CountFrame;
        attribute integrationWindow : Nanosecond = 1000000.0;
        attribute maximumLinearRate : CountsPerSecond = 10000000.0;
    }

    action def EstimateDarkCountRate {
        in item thermalState : ThermalTelemetry;
        out item status : StatusMessage;
        attribute darkMeasurementGate : Nanosecond = 10000000.0;
        attribute maximumAllowedDarkCountRate : CountsPerSecond = 100.0;
    }

    action def PublishCounterStatus {
        in item frame : CountFrame;
        in item thermalState : ThermalTelemetry;
        out item status : StatusMessage;
    }

    state def PhotonCounterOperationalStateMachine {
        attribute currentMode : OperatingMode = OperatingMode::off;
        attribute activeFault : FaultCode = FaultCode::none;

        state off {
            entry action {
                currentMode = OperatingMode::off;
            }
        }

        state cooldown {
            entry action {
                currentMode = OperatingMode::cooldown;
            }
            do action CoolDetector;
        }

        state standby {
            entry action {
                currentMode = OperatingMode::standby;
            }
        }

        state armed {
            entry action {
                currentMode = OperatingMode::armed;
            }
            do action ApplyDetectorBias;
        }

        state counting {
            entry action {
                currentMode = OperatingMode::counting;
            }
            do action ConvertPhotonToAvalanchePulse;
            do action DiscriminateAvalanchePulse;
            do action TimeTagPulse;
            do action AccumulatePhotonCounts;
        }

        state calibration {
            entry action {
                currentMode = OperatingMode::calibration;
            }
            do action EstimateDarkCountRate;
        }

        state fault {
            entry action {
                currentMode = OperatingMode::fault;
            }
        }

        state safeShutdown {
            entry action {
                currentMode = OperatingMode::safeShutdown;
            }
        }

        transition initial_to_off first off;

        transition power_on from off to cooldown
            accept CommandMessage
            if requestedMode == OperatingMode::cooldown;

        transition cooldown_complete from cooldown to standby
            if activeFault == FaultCode::none;

        transition arm_counter from standby to armed
            accept CommandMessage
            if requestedMode == OperatingMode::armed;

        transition begin_counting from armed to counting
            accept CommandMessage
            if requestedMode == OperatingMode::counting;

        transition calibrate_dark_counts from standby to calibration
            accept CommandMessage
            if requestedMode == OperatingMode::calibration;

        transition calibration_complete from calibration to standby
            if activeFault == FaultCode::none;

        transition pause_counting from counting to standby
            accept CommandMessage
            if requestedMode == OperatingMode::standby;

        transition fault_detected_from_cooldown from cooldown to fault
            if activeFault != FaultCode::none;

        transition fault_detected_from_armed from armed to fault
            if activeFault != FaultCode::none;

        transition fault_detected_from_counting from counting to fault
            if activeFault != FaultCode::none;

        transition shutdown_from_fault from fault to safeShutdown
            accept CommandMessage
            if requestedMode == OperatingMode::safeShutdown;

        transition shutdown_from_standby from standby to safeShutdown
            accept CommandMessage
            if requestedMode == OperatingMode::safeShutdown;

        transition safe_to_off from safeShutdown to off;
    }

    part def OpticalEntranceAssembly {
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        attribute apertureDiameter : Real = 2.0;
        attribute apertureDiameterUnit : String = "mm";
        attribute minimumAcceptedWavelength : Nanometer = 400.0;
        attribute maximumAcceptedWavelength : Nanometer = 700.0;
        attribute opticalTransmission : Percent = 92.0;
        attribute maximumSafeOpticalPower : Watt = 0.000001;

        perform action conditionLight : ConditionIncidentLight;
    }

    part def SpectralFilter {
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;

        attribute centerWavelength : Nanometer = 550.0;
        attribute fullWidthHalfMaximum : Nanometer = 300.0;
        attribute outOfBandRejection : Dimensionless = 1000000.0;
        attribute filterTransmission : Percent = 95.0;

        perform action conditionVisibleBand : ConditionIncidentLight;
    }

    part def CryogenicDetectorChip {
        port opticalIn : OpticalInputPort;
        port biasIn : BiasInputPort;
        port coolingIn : CoolingInputPort;
        port pulseOut : PulsePort;
        port thermalOut : ThermalTelemetryPort;

        attribute detectorMaterial : String = "arsenic-compensated silicon visible-light photon counter";
        attribute activeAreaDiameter : Real = 1.0;
        attribute activeAreaDiameterUnit : String = "mm";
        attribute nominalOperatingTemperature : Kelvin = 6.5;
        attribute allowedTemperatureMinimum : Kelvin = 5.5;
        attribute allowedTemperatureMaximum : Kelvin = 7.5;
        attribute nominalBiasVoltage : Volt = 7.2;
        attribute avalancheGain : Dimensionless = 50000.0;
        attribute quantumEfficiencyAt550nm : Percent = 88.0;
        attribute darkCountRateAtNominalTemperature : CountsPerSecond = 50.0;
        attribute timingJitterFwhm : Picosecond = 35.0;
        attribute maximumLinearPhotonRate : CountsPerSecond = 10000000.0;

        perform action detectPhoton : ConvertPhotonToAvalanchePulse;
    }

    part def CryogenicSubsystem {
        port powerIn : ElectricalPowerInputPort;
        port coolingOut : CoolingPort;
        port thermalOut : ThermalTelemetryPort;

        attribute coolerType : String = "closed-cycle cryocooler with cold finger";
        attribute targetColdStageTemperature : Kelvin = 6.0;
        attribute temperatureStability : Kelvin = 0.05;
        attribute maximumHeatLiftAtTarget : Watt = 0.50;
        attribute inputPowerAtSteadyState : Watt = 85.0;
        attribute cooldownTimeToNominal : Real = 900.0;
        attribute cooldownTimeUnit : String = "s";

        perform action coolDetector : CoolDetector;
    }

    part def BiasAndQuenchElectronics {
        port powerIn : ElectricalPowerInputPort;
        port biasOut : BiasOutputPort;
        port analogPulseIn : AnalogPulseInputPort;
        port analogPulseOut : DigitalPulsePort;

        attribute nominalBiasVoltage : Volt = 7.2;
        attribute biasStability : Volt = 0.002;
        attribute currentLimit : Milliampere = 0.050;
        attribute activeQuenchTime : Nanosecond = 20.0;
        attribute recoveryTime : Nanosecond = 35.0;
        attribute discriminatorThreshold : Volt = 0.025;
        attribute analogBandwidth : Real = 1.5;
        attribute analogBandwidthUnit : String = "GHz";

        perform action applyBias : ApplyDetectorBias;
        perform action discriminatePulse : DiscriminateAvalanchePulse;
    }

    part def TimeTaggingProcessor {
        port powerIn : ElectricalPowerInputPort;
        port pulseIn : DigitalPulseInputPort;
        port countOut : CountEventPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port thermalIn : ThermalTelemetryInputPort;

        attribute timeTagResolution : Picosecond = 10.0;
        attribute oscillatorStability : Dimensionless = 0.00000001;
        attribute integrationWindow : Nanosecond = 1000000.0;
        attribute maximumSustainedEventRate : CountsPerSecond = 10000000.0;
        attribute outputFrameRate : Hertz = 1000.0;
        attribute statusUpdateRate : Hertz = 10.0;

        perform action timeTag : TimeTagPulse;
        perform action accumulateCounts : AccumulatePhotonCounts;
        perform action estimateDarkRate : EstimateDarkCountRate;
        perform action publishStatus : PublishCounterStatus;
    }

    part def PowerManagementUnit {
        port externalPowerIn : ElectricalPowerInputPort;
        port coolerPowerOut : ElectricalPowerOutputPort;
        port electronicsPowerOut : ElectricalPowerOutputPort;
        port processorPowerOut : ElectricalPowerOutputPort;
        port statusOut : StatusPort;

        attribute inputVoltage : Volt = 24.0;
        attribute maximumInputPower : Watt = 120.0;
        attribute coolerRailVoltage : Volt = 24.0;
        attribute electronicsRailVoltage : Volt = 12.0;
        attribute processorRailVoltage : Volt = 5.0;
        attribute powerConversionEfficiency : Percent = 90.0;
    }

    part def HostInterface {
        port commandIn : CommandPort;
        port statusIn : CountEventInputPort;
        port counterStatusIn : StatusPort;

        attribute physicalInterface : String = "gigabit Ethernet";
        attribute maximumDataRate : BitRate = 1000.0;
        attribute commandLatency : Real = 5.0;
        attribute commandLatencyUnit : String = "ms";
    }

    part def VisibleLightPhotonCounterSystem {
        port opticalInput : OpticalInputPort;
        port externalPower : ElectricalPowerInputPort;
        port commandInput : CommandPort;
        port countOutput : CountEventPort;
        port statusOutput : StatusPort;

        attribute primaryFunction : String =
            "Detect individual visible-light photons and convert each photon arrival into a time-tagged digital count event while maintaining cryogenic detector conditions, controlled bias, low dark-count rate, and calibrated count-rate telemetry.";

        attribute supportedMinimumWavelength : Nanometer = 400.0;
        attribute supportedMaximumWavelength : Nanometer = 700.0;
        attribute nominalQuantumEfficiencyAt550nm : Percent = 88.0;
        attribute maximumDarkCountRateAtNominalTemperature : CountsPerSecond = 100.0;
        attribute nominalDetectorTemperature : Kelvin = 6.5;
        attribute countTimingResolution : Picosecond = 10.0;
        attribute maximumSustainedCountRate : CountsPerSecond = 10000000.0;
        attribute maximumSafeInputOpticalPower : Watt = 0.000001;
        attribute nominalInputPower : Watt = 95.0;

        part entrance : OpticalEntranceAssembly;
        part filter : SpectralFilter;
        part detector : CryogenicDetectorChip;
        part cryogenics : CryogenicSubsystem;
        part electronics : BiasAndQuenchElectronics;
        part processor : TimeTaggingProcessor;
        part power : PowerManagementUnit;
        part host : HostInterface;

        connection external_optical_to_entrance : OpticalPath
            connect opticalInput to entrance.opticalIn;

        connection entrance_to_filter : OpticalPath
            connect entrance.opticalOut to filter.opticalIn;

        connection filter_to_detector : OpticalPath
            connect filter.opticalOut to detector.opticalIn;

        connection detector_pulse_to_electronics : AnalogPulsePath
            connect detector.pulseOut to electronics.analogPulseIn;

        connection electronics_pulse_to_processor : DigitalPulsePath
            connect electronics.analogPulseOut to processor.pulseIn;

        connection processor_counts_to_system_output : CountDataPath
            connect processor.countOut to countOutput;

        connection system_power_to_pmu : PowerPath
            connect externalPower to power.externalPowerIn;

        connection pmu_to_cryogenics : PowerPath
            connect power.coolerPowerOut to cryogenics.powerIn;

        connection pmu_to_electronics : PowerPath
            connect power.electronicsPowerOut to electronics.powerIn;

        connection pmu_to_processor : PowerPath
            connect power.processorPowerOut to processor.powerIn;

        connection cryogenic_cooling_to_detector : CoolingPath
            connect cryogenics.coolingOut to detector.coolingIn;

        connection electronics_bias_to_detector : BiasPath
            connect electronics.biasOut to detector.biasIn;

        connection detector_thermal_to_processor : ThermalTelemetryPath
            connect detector.thermalOut to processor.thermalIn;

        connection cryogenic_thermal_to_processor : ThermalTelemetryPath
            connect cryogenics.thermalOut to processor.thermalIn;

        connection external_commands_to_processor : CountDataPath
            connect commandInput to processor.commandIn;

        connection processor_status_to_system_status : CountDataPath
            connect processor.statusOut to statusOutput;

        exhibit state machine : PhotonCounterOperationalStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The system shall provide the high-level function of detecting individual visible photons and producing digital photon-count information. */

        require constraint {
            counter.supportedMinimumWavelength <= 400.0 and
            counter.supportedMaximumWavelength >= 700.0 and
            counter.countTimingResolution <= 10.0 and
            counter.maximumSustainedCountRate >= 10000000.0
        }
    }

    requirement def VisibleWavelengthAcceptanceRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The optical path shall accept photons across the visible wavelength range. */

        require constraint {
            counter.supportedMinimumWavelength <= 400.0 and
            counter.supportedMaximumWavelength >= 700.0
        }
    }

    requirement def CryogenicOperationRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The detector shall be maintained at a cryogenic operating temperature suitable for low-noise visible-light photon counting. */

        require constraint {
            counter.nominalDetectorTemperature >= 5.5 and
            counter.nominalDetectorTemperature <= 7.5
        }
    }

    requirement def DarkCountRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The system shall limit internally generated dark-count events at nominal cryogenic temperature. */

        require constraint {
            counter.maximumDarkCountRateAtNominalTemperature <= 100.0
        }
    }

    requirement def QuantumEfficiencyRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The detector shall provide high quantum efficiency for green visible photons. */

        require constraint {
            counter.nominalQuantumEfficiencyAt550nm >= 85.0
        }
    }

    requirement def TimingResolutionRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The time-tagging processor shall timestamp photon count events with picosecond-class resolution. */

        require constraint {
            counter.countTimingResolution <= 10.0
        }
    }

    requirement def OpticalSafetyRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The optical input shall define a maximum safe incident optical power to prevent detector saturation or damage. */

        require constraint {
            counter.maximumSafeInputOpticalPower <= 0.000001
        }
    }

    requirement def CountRateLinearityRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The photon counter shall sustain a high count rate while preserving event discrimination and time-tag generation. */

        require constraint {
            counter.maximumSustainedCountRate >= 10000000.0
        }
    }

    requirement def PowerRequirement {
        subject counter : VisibleLightPhotonCounterSystem;

        doc /* The complete counter shall operate from a bounded electrical power budget including cryogenic cooling and electronics. */

        require constraint {
            counter.nominalInputPower <= 120.0
        }
    }

    satisfy PrimaryFunctionRequirement by VisibleLightPhotonCounterSystem;
    satisfy VisibleWavelengthAcceptanceRequirement by VisibleLightPhotonCounterSystem::entrance;
    satisfy VisibleWavelengthAcceptanceRequirement by VisibleLightPhotonCounterSystem::filter;
    satisfy CryogenicOperationRequirement by VisibleLightPhotonCounterSystem::cryogenics;
    satisfy CryogenicOperationRequirement by VisibleLightPhotonCounterSystem::detector;
    satisfy DarkCountRequirement by VisibleLightPhotonCounterSystem::detector;
    satisfy QuantumEfficiencyRequirement by VisibleLightPhotonCounterSystem::detector;
    satisfy TimingResolutionRequirement by VisibleLightPhotonCounterSystem::processor;
    satisfy OpticalSafetyRequirement by VisibleLightPhotonCounterSystem::entrance;
    satisfy CountRateLinearityRequirement by VisibleLightPhotonCounterSystem::processor;
    satisfy PowerRequirement by VisibleLightPhotonCounterSystem::power;

}
