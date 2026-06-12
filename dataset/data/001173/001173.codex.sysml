package ParticleDetectorSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Probability {
        :> ScalarValues::Real;
        unit = one;
    }

    attribute def CountRate {
        :> ScalarValues::Real;
        unit = Hz;
    }

    attribute def EnergyResolution {
        :> ScalarValues::Real;
        unit = '%';
    }

    attribute def DataRate {
        :> ScalarValues::Real;
        unit = 'bit/s';
    }

    attribute def DeadTime {
        :> ScalarValues::Real;
        unit = s;
    }

    attribute def Timestamp {
        :> ScalarValues::Real;
        unit = s;
    }

    item def IncidentParticle {
        attribute kineticEnergy : EnergyValue;
        attribute electricCharge : ElectricChargeValue;
        attribute arrivalTime : Timestamp;
        attribute directionX : ScalarValues::Real;
        attribute directionY : ScalarValues::Real;
        attribute directionZ : ScalarValues::Real;
    }

    item def InteractionEvent {
        attribute depositedEnergy : EnergyValue;
        attribute interactionTime : Timestamp;
        attribute sensorChannelId : ScalarValues::Integer;
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute positionZ : LengthValue;
    }

    item def AnalogPulse {
        attribute amplitude : ElectricPotentialValue;
        attribute riseTime : TimeValue;
        attribute width : TimeValue;
        attribute chargeIntegral : ElectricChargeValue;
    }

    item def DigitalSample {
        attribute sampleValue : ScalarValues::Integer;
        attribute sampleTime : Timestamp;
        attribute channelId : ScalarValues::Integer;
    }

    item def ParticleDetectionRecord {
        attribute eventTime : Timestamp;
        attribute reconstructedEnergy : EnergyValue;
        attribute detectedParticleClass : ParticleClass;
        attribute confidence : Probability;
        attribute sourceChannel : ScalarValues::Integer;
    }

    enum def ParticleClass {
        enum alpha;
        enum beta;
        enum gamma;
        enum neutron;
        enum muon;
        enum unknown;
    }

    port def ParticleAperturePort {
        in item particle : IncidentParticle;
    }

    port def EventPort {
        out item event : InteractionEvent;
    }

    port def AnalogSignalPort {
        inout item pulse : AnalogPulse;
    }

    port def DigitalDataPort {
        inout item sample : DigitalSample;
        inout item record : ParticleDetectionRecord;
    }

    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }

    port def ThermalPort {
        inout attribute heatFlow : PowerValue;
        inout attribute temperature : ThermodynamicTemperatureValue;
    }

    port def ControlPort {
        in attribute enabled : Boolean;
        in attribute acquisitionWindow : TimeValue;
        out attribute ready : Boolean;
        out attribute faultActive : Boolean;
    }

    part def ParticleDetectorSystem {
        doc /* Primary function: detect incident ionizing particles by converting particle interactions in a sensing medium into electrical signals, digitizing those signals, and producing time-stamped particle detection records containing estimated energy, class, channel, and confidence. */

        attribute minimumDetectableEnergy : EnergyValue = 5.0 [keV];
        attribute maximumMeasurableEnergy : EnergyValue = 20.0 [MeV];
        attribute nominalCountRateCapacity : CountRate = 100000.0 [Hz];
        attribute maximumDeadTime : DeadTime = 2.0e-6 [s];
        attribute requiredDetectionEfficiency : Probability = 0.92;
        attribute requiredEnergyResolution : EnergyResolution = 3.0 ['%'];
        attribute outputDataRateLimit : DataRate = 100000000.0 ['bit/s'];

        port particleInput : ParticleAperturePort;
        port commandInterface : ControlPort;
        port scienceDataInterface : DigitalDataPort;
        port electricalPower : PowerPort;
        port thermalInterface : ThermalPort;

        part collimator : Collimator;
        part sensingArray : SegmentedSensorArray;
        part frontEndElectronics : FrontEndElectronics;
        part digitizer : WaveformDigitizer;
        part eventProcessor : EventProcessor;
        part timingReference : TimingReference;
        part powerConditioner : PowerConditioner;
        part thermalController : ThermalController;
        part healthMonitor : HealthMonitor;

        connect particleInput to collimator.inputAperture;
        connect collimator.filteredParticleOutput to sensingArray.particleEntrance;
        connect sensingArray.eventOutput to frontEndElectronics.eventInput;
        connect frontEndElectronics.shapedPulseOutput to digitizer.analogInput;
        connect digitizer.sampleOutput to eventProcessor.sampleInput;
        connect eventProcessor.recordOutput to scienceDataInterface;
        connect commandInterface to eventProcessor.controlInput;
        connect commandInterface to healthMonitor.controlInput;
        connect electricalPower to powerConditioner.powerInput;
        connect powerConditioner.lowVoltageOutput to frontEndElectronics.powerInput;
        connect powerConditioner.digitalVoltageOutput to digitizer.powerInput;
        connect powerConditioner.processorVoltageOutput to eventProcessor.powerInput;
        connect timingReference.clockOutput to digitizer.clockInput;
        connect timingReference.clockOutput to eventProcessor.clockInput;
        connect thermalInterface to thermalController.externalThermalPort;
        connect thermalController.sensorThermalPort to sensingArray.thermalPort;
        connect healthMonitor.statusOutput to commandInterface;

        action detectParticles {
            in item incomingParticle : IncidentParticle;
            out item detectionRecord : ParticleDetectionRecord;

            first start;
            then collimateParticle;
            then convertInteractionToCharge;
            then amplifyAndShapePulse;
            then digitizeWaveform;
            then reconstructEvent;
            then publishDetectionRecord;
            then done;

            action collimateParticle {
                in item rawParticle : IncidentParticle = incomingParticle;
                out item acceptedParticle : IncidentParticle;
            }

            action convertInteractionToCharge {
                in item acceptedParticle : IncidentParticle;
                out item interaction : InteractionEvent;
            }

            action amplifyAndShapePulse {
                in item interaction : InteractionEvent;
                out item pulse : AnalogPulse;
            }

            action digitizeWaveform {
                in item pulse : AnalogPulse;
                out item sample : DigitalSample;
            }

            action reconstructEvent {
                in item sample : DigitalSample;
                out item reconstructedRecord : ParticleDetectionRecord;
            }

            action publishDetectionRecord {
                in item reconstructedRecord : ParticleDetectionRecord;
                out item detectionRecord : ParticleDetectionRecord;
            }
        }

        state detectorOperatingState {
            entry action initializeDetector;
            state Off;
            state Standby;
            state Calibrating;
            state Acquiring;
            state Processing;
            state Fault;
            state SafeShutdown;

            initial then Off;

            transition powerApplied
                first Off
                accept when electricalPower.voltage >= 24.0 [V]
                then Standby;

            transition beginCalibration
                first Standby
                accept when commandInterface.enabled == true
                then Calibrating;

            transition calibrationComplete
                first Calibrating
                accept after 10.0 [s]
                then Acquiring;

            transition particleInteractionDetected
                first Acquiring
                accept item event : InteractionEvent
                then Processing;

            transition recordPublished
                first Processing
                accept item record : ParticleDetectionRecord
                then Acquiring;

            transition detectedFault
                first Standby
                then Fault;

            transition acquisitionFault
                first Acquiring
                then Fault;

            transition processorFault
                first Processing
                then Fault;

            transition shutdownCommand
                first Fault
                accept when commandInterface.enabled == false
                then SafeShutdown;

            transition resetComplete
                first SafeShutdown
                accept after 5.0 [s]
                then Standby;
        }
    }

    part def Collimator {
        attribute fieldOfViewHalfAngle : PlaneAngleValue = 30.0 [deg];
        attribute shieldingThickness : LengthValue = 12.0 [mm];
        attribute apertureDiameter : LengthValue = 25.0 [mm];

        port inputAperture : ParticleAperturePort;
        port filteredParticleOutput : ParticleAperturePort;

        action rejectOutOfFieldParticles {
            in item candidate : IncidentParticle;
            out item accepted : IncidentParticle;
        }
    }

    part def SegmentedSensorArray {
        attribute sensorMaterialDensity : DensityValue = 2.33 ['g/cm^3'];
        attribute activeArea : AreaValue = 100.0 ['cm^2'];
        attribute depletionDepth : LengthValue = 500.0 [um];
        attribute channelCount : ScalarValues::Integer = 1024;
        attribute intrinsicEfficiency : Probability = 0.96;
        attribute darkCountRatePerChannel : CountRate = 0.02 [Hz];

        port particleEntrance : ParticleAperturePort;
        port eventOutput : EventPort;
        port thermalPort : ThermalPort;

        part segments[1024] : SensorSegment;

        action generateInteractionEvent {
            in item particle : IncidentParticle;
            out item event : InteractionEvent;
        }
    }

    part def SensorSegment {
        attribute channelId : ScalarValues::Integer;
        attribute sensitiveVolume : VolumeValue = 0.05 ['cm^3'];
        attribute chargeCollectionTime : TimeValue = 35.0 [ns];
        attribute biasVoltage : ElectricPotentialValue = 150.0 [V];

        port eventOutput : EventPort;
        port thermalPort : ThermalPort;
    }

    part def FrontEndElectronics {
        attribute gain : ScalarValues::Real = 15.0;
        attribute equivalentNoiseCharge : ElectricChargeValue = 120.0 [aC];
        attribute shapingTime : TimeValue = 75.0 [ns];
        attribute saturationVoltage : ElectricPotentialValue = 2.0 [V];

        port eventInput : EventPort;
        port shapedPulseOutput : AnalogSignalPort;
        port powerInput : PowerPort;

        part chargeSensitiveAmplifier : ChargeSensitiveAmplifier;
        part pulseShaper : PulseShaper;
        part discriminator : ThresholdDiscriminator;

        connect eventInput to chargeSensitiveAmplifier.eventInput;
        connect chargeSensitiveAmplifier.rawPulseOutput to pulseShaper.rawPulseInput;
        connect pulseShaper.shapedPulseOutput to discriminator.pulseInput;
        connect discriminator.acceptedPulseOutput to shapedPulseOutput;

        action produceConditionedPulse {
            in item interaction : InteractionEvent;
            out item pulse : AnalogPulse;
        }
    }

    part def ChargeSensitiveAmplifier {
        attribute feedbackCapacitance : CapacitanceValue = 1.0 [pF];
        attribute noiseVoltage : ElectricPotentialValue = 0.8 [mV];

        port eventInput : EventPort;
        port rawPulseOutput : AnalogSignalPort;
    }

    part def PulseShaper {
        attribute peakingTime : TimeValue = 75.0 [ns];
        attribute baselineRecoveryTime : TimeValue = 500.0 [ns];

        port rawPulseInput : AnalogSignalPort;
        port shapedPulseOutput : AnalogSignalPort;
    }

    part def ThresholdDiscriminator {
        attribute thresholdVoltage : ElectricPotentialValue = 20.0 [mV];
        attribute falseTriggerProbability : Probability = 1.0e-6;

        port pulseInput : AnalogSignalPort;
        port acceptedPulseOutput : AnalogSignalPort;
    }

    part def WaveformDigitizer {
        attribute sampleRate : FrequencyValue = 250.0 [MHz];
        attribute resolutionBits : ScalarValues::Integer = 14;
        attribute inputRange : ElectricPotentialValue = 2.0 [V];
        attribute conversionLatency : TimeValue = 120.0 [ns];

        port analogInput : AnalogSignalPort;
        port sampleOutput : DigitalDataPort;
        port clockInput : DigitalDataPort;
        port powerInput : PowerPort;

        action sampleAnalogPulse {
            in item pulse : AnalogPulse;
            out item sample : DigitalSample;
        }
    }

    part def EventProcessor {
        attribute classificationLatency : TimeValue = 1.5 [us];
        attribute maximumAcceptedPileup : ScalarValues::Integer = 2;
        attribute bufferCapacity : ScalarValues::Integer = 65536;
        attribute sustainedOutputRate : DataRate = 80000000.0 ['bit/s'];

        port sampleInput : DigitalDataPort;
        port recordOutput : DigitalDataPort;
        port controlInput : ControlPort;
        port clockInput : DigitalDataPort;
        port powerInput : PowerPort;

        action reconstructParticleEvent {
            in item sample : DigitalSample;
            out item record : ParticleDetectionRecord;

            first validateSample;
            then estimateEnergy;
            then classifyParticle;
            then assignTimestamp;
            then emitRecord;

            action validateSample;
            action estimateEnergy;
            action classifyParticle;
            action assignTimestamp;
            action emitRecord;
        }
    }

    part def TimingReference {
        attribute clockFrequency : FrequencyValue = 100.0 [MHz];
        attribute timeStability : ScalarValues::Real = 1.0e-9;
        attribute synchronizationError : TimeValue = 5.0 [ns];

        port clockOutput : DigitalDataPort;
    }

    part def PowerConditioner {
        attribute inputVoltageNominal : ElectricPotentialValue = 24.0 [V];
        attribute lowVoltageRail : ElectricPotentialValue = 5.0 [V];
        attribute digitalRail : ElectricPotentialValue = 3.3 [V];
        attribute processorRail : ElectricPotentialValue = 1.2 [V];
        attribute conversionEfficiency : Probability = 0.88;

        port powerInput : PowerPort;
        port lowVoltageOutput : PowerPort;
        port digitalVoltageOutput : PowerPort;
        port processorVoltageOutput : PowerPort;
    }

    part def ThermalController {
        attribute targetSensorTemperature : ThermodynamicTemperatureValue = 253.15 [K];
        attribute maximumSensorTemperature : ThermodynamicTemperatureValue = 263.15 [K];
        attribute coolingCapacity : PowerValue = 15.0 [W];

        port externalThermalPort : ThermalPort;
        port sensorThermalPort : ThermalPort;

        state thermalState {
            state Idle;
            state Cooling;
            state Regulating;
            state OverTemperature;

            initial then Idle;

            transition coolingRequired
                first Idle
                accept when sensorThermalPort.temperature > targetSensorTemperature
                then Cooling;

            transition targetReached
                first Cooling
                accept when sensorThermalPort.temperature <= targetSensorTemperature
                then Regulating;

            transition temperatureExceeded
                first Regulating
                accept when sensorThermalPort.temperature > maximumSensorTemperature
                then OverTemperature;

            transition recovered
                first OverTemperature
                accept when sensorThermalPort.temperature <= targetSensorTemperature
                then Regulating;
        }
    }

    part def HealthMonitor {
        attribute voltageTolerance : Probability = 0.05;
        attribute maximumFaultResponseTime : TimeValue = 100.0 [ms];

        port controlInput : ControlPort;
        port statusOutput : ControlPort;

        action evaluateHealth {
            out attribute faultActive : Boolean;
            out attribute ready : Boolean;
        }
    }

    requirement def DetectIncidentParticles {
        doc /* The system shall detect incident ionizing particles entering the detector aperture and produce a time-stamped digital detection record. */

        subject detector : ParticleDetectorSystem;

        require constraint {
            detector.minimumDetectableEnergy <= 5.0 [keV]
        }

        require constraint {
            detector.requiredDetectionEfficiency >= 0.92
        }
    }

    requirement def EstimateParticleEnergy {
        doc /* The system shall estimate deposited particle energy over the specified operating range. */

        subject detector : ParticleDetectorSystem;

        require constraint {
            detector.maximumMeasurableEnergy >= 20.0 [MeV]
        }

        require constraint {
            detector.requiredEnergyResolution <= 3.0 ['%']
        }
    }

    requirement def SustainEventThroughput {
        doc /* The detector shall sustain the required event throughput without exceeding the allowed dead time. */

        subject detector : ParticleDetectorSystem;

        require constraint {
            detector.nominalCountRateCapacity >= 100000.0 [Hz]
        }

        require constraint {
            detector.maximumDeadTime <= 2.0e-6 [s]
        }
    }

    requirement def ProvideDigitalScienceData {
        doc /* The detector shall provide digital particle detection records through its science data interface. */

        subject detector : ParticleDetectorSystem;

        require constraint {
            detector.outputDataRateLimit >= 80000000.0 ['bit/s']
        }
    }

    requirement def MaintainThermalOperatingCondition {
        doc /* The detector shall regulate the sensor array temperature to preserve noise and energy resolution performance. */

        subject detector : ParticleDetectorSystem;

        require constraint {
            detector.thermalController.maximumSensorTemperature <= 263.15 [K]
        }
    }

    satisfy DetectIncidentParticles by ParticleDetectorSystem;
    satisfy EstimateParticleEnergy by ParticleDetectorSystem;
    satisfy SustainEventThroughput by ParticleDetectorSystem;
    satisfy ProvideDigitalScienceData by ParticleDetectorSystem;
    satisfy MaintainThermalOperatingCondition by ParticleDetectorSystem;

}