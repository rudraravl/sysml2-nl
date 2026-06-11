package AcceleromyographSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    /* Units and Value Types */

    attribute def ElectricCharge :> ScalarValues::Real {
        unit = "mA";
    }

    attribute def ElectricCurrent_mA :> ScalarValues::Real {
        unit = "mA";
    }

    attribute def ElectricVoltage_V :> ScalarValues::Real {
        unit = "V";
    }

    attribute def Duration_ms :> ScalarValues::Real {
        unit = "ms";
    }

    attribute def Duration_s :> ScalarValues::Real {
        unit = "s";
    }

    attribute def Frequency_Hz :> ScalarValues::Real {
        unit = "Hz";
    }

    attribute def Acceleration_mps2 :> ScalarValues::Real {
        unit = "m/s^2";
    }

    attribute def Mass_g :> ScalarValues::Real {
        unit = "g";
    }

    attribute def Temperature_C :> ScalarValues::Real {
        unit = "degC";
    }

    attribute def Percent :> ScalarValues::Real {
        unit = "%";
    }

    attribute def Ratio :> ScalarValues::Real;

    attribute def Impedance_ohm :> ScalarValues::Real {
        unit = "ohm";
    }

    attribute def Force_N :> ScalarValues::Real {
        unit = "N";
    }

    attribute def Timestamp_s :> ScalarValues::Real {
        unit = "s";
    }

    enum def MeasurementMode {
        enum TrainOfFour;
        enum SingleTwitch;
        enum PostTetanicCount;
        enum DoubleBurst;
        enum Calibration;
        enum Idle;
    }

    enum def SensorAxis {
        enum X;
        enum Y;
        enum Z;
        enum Resultant;
    }

    enum def AlarmSeverity {
        enum Advisory;
        enum Warning;
        enum Critical;
    }

    enum def ElectrodePlacement {
        enum UlnarNerveAtWrist;
        enum FacialNerve;
        enum PosteriorTibialNerve;
    }

    /* Item Definitions */

    item def ElectricalStimulusPulse {
        attribute amplitude : ElectricCurrent_mA;
        attribute pulseWidth : Duration_ms;
        attribute deliveredVoltage : ElectricVoltage_V;
        attribute deliveryTime : Timestamp_s;
        attribute pulseIndex : Integer;
    }

    item def StimulationPattern {
        attribute mode : MeasurementMode;
        attribute pulseCount : Integer;
        attribute interPulseInterval : Duration_ms;
        attribute trainFrequency : Frequency_Hz;
        attribute repeatInterval : Duration_s;
    }

    item def ThumbAccelerationSample {
        attribute axis : SensorAxis;
        attribute acceleration : Acceleration_mps2;
        attribute sampleTime : Timestamp_s;
        attribute sampleRate : Frequency_Hz;
    }

    item def TwitchResponse {
        attribute twitchIndex : Integer;
        attribute peakAcceleration : Acceleration_mps2;
        attribute timeToPeak : Duration_ms;
        attribute derivedForceEstimate : Force_N;
        attribute baselineCorrected : Boolean;
    }

    item def NeuromuscularMeasurement {
        attribute mode : MeasurementMode;
        attribute firstTwitchAmplitude : Acceleration_mps2;
        attribute fourthTwitchAmplitude : Acceleration_mps2;
        attribute tofRatio : Ratio;
        attribute twitchCount : Integer;
        attribute recoveryPercent : Percent;
        attribute measurementTime : Timestamp_s;
        attribute valid : Boolean;
    }

    item def PatientInterfaceStatus {
        attribute electrodeImpedance : Impedance_ohm;
        attribute sensorAttached : Boolean;
        attribute thumbFreeToMove : Boolean;
        attribute skinTemperature : Temperature_C;
        attribute stimulationSite : ElectrodePlacement;
    }

    item def DisplayMessage {
        attribute measurementMode : MeasurementMode;
        attribute tofRatioPercent : Percent;
        attribute twitchCount : Integer;
        attribute qualityIndex : Percent;
        attribute messageText : String;
    }

    item def AlarmEvent {
        attribute severity : AlarmSeverity;
        attribute alarmText : String;
        attribute alarmTime : Timestamp_s;
        attribute latched : Boolean;
    }

    item def PowerStatus {
        attribute batteryVoltage : ElectricVoltage_V;
        attribute batteryChargeRemaining : Percent;
        attribute externalPowerPresent : Boolean;
    }

    item def ClinicalSetting {
        attribute selectedMode : MeasurementMode;
        attribute targetCurrent : ElectricCurrent_mA;
        attribute pulseWidth : Duration_ms;
        attribute repeatInterval : Duration_s;
        attribute autoCalibrateEnabled : Boolean;
    }

    /* Port Definitions */

    port def StimulusOutputPort {
        out item pulse : ElectricalStimulusPulse;
        in item status : PatientInterfaceStatus;
    }

    port def ElectrodeSkinPort {
        in item pulse : ElectricalStimulusPulse;
        out item status : PatientInterfaceStatus;
    }

    port def MotionSensingPort {
        out item sample : ThumbAccelerationSample;
    }

    port def SensorInputPort {
        in item sample : ThumbAccelerationSample;
    }

    port def MeasurementOutputPort {
        out item measurement : NeuromuscularMeasurement;
        out item alarm : AlarmEvent;
    }

    port def MeasurementInputPort {
        in item measurement : NeuromuscularMeasurement;
        in item alarm : AlarmEvent;
    }

    port def UserCommandPort {
        out item setting : ClinicalSetting;
        in item message : DisplayMessage;
        in item alarm : AlarmEvent;
    }

    port def ProcessorCommandPort {
        in item setting : ClinicalSetting;
        out item message : DisplayMessage;
        out item alarm : AlarmEvent;
    }

    port def PowerSupplyPort {
        out item powerStatus : PowerStatus;
    }

    port def PoweredDevicePort {
        in item powerStatus : PowerStatus;
    }

    /* Behavior Definitions */

    action def DeliverStimulation {
        in item pattern : StimulationPattern;
        in item interfaceStatus : PatientInterfaceStatus;
        out item deliveredPulse : ElectricalStimulusPulse;

        attribute currentLimit : ElectricCurrent_mA = 70.0;
        attribute nominalPulseWidth : Duration_ms = 0.2;

        objective {
            doc /* Deliver controlled peripheral nerve stimulation pulses through surface electrodes while limiting current and validating electrode contact. */
        }
    }

    action def AcquireAcceleration {
        in item pulse : ElectricalStimulusPulse;
        out item accelerationSample : ThumbAccelerationSample;

        attribute minimumSampleRate : Frequency_Hz = 200.0;

        objective {
            doc /* Capture thumb acceleration following each stimulus pulse to characterize evoked muscle twitch response. */
        }
    }

    action def ExtractTwitchResponse {
        in item sample : ThumbAccelerationSample;
        out item response : TwitchResponse;

        objective {
            doc /* Filter acceleration data, remove baseline motion, identify twitch peak, and estimate twitch amplitude. */
        }
    }

    action def ComputeNeuromuscularBlockade {
        in item response : TwitchResponse;
        in item setting : ClinicalSetting;
        out item measurement : NeuromuscularMeasurement;

        objective {
            doc /* Convert twitch amplitudes into clinically meaningful neuromuscular transmission metrics such as train-of-four ratio and twitch count. */
        }
    }

    action def EvaluateSignalQuality {
        in item interfaceStatus : PatientInterfaceStatus;
        in item measurement : NeuromuscularMeasurement;
        out item alarm : AlarmEvent;

        objective {
            doc /* Detect detached sensor, high electrode impedance, constrained thumb motion, low battery, and invalid twitch morphology. */
        }
    }

    action def PresentMeasurement {
        in item measurement : NeuromuscularMeasurement;
        in item alarm : AlarmEvent;
        out item message : DisplayMessage;

        objective {
            doc /* Present high-level neuromuscular monitoring results to the clinician. */
        }
    }

    state def MonitorOperationalState {
        entry action initializeSystem;
        state Off;
        state SelfTest;
        state Ready;
        state Calibrating;
        state Stimulating;
        state Acquiring;
        state Processing;
        state Displaying;
        state AlarmActive;
        state Fault;

        transition initial then Off;

        transition powerOn
            first Off
            then SelfTest;

        transition selfTestPassed
            first SelfTest
            then Ready;

        transition selfTestFailed
            first SelfTest
            then Fault;

        transition calibrationRequested
            first Ready
            then Calibrating;

        transition calibrationComplete
            first Calibrating
            then Ready;

        transition stimulationRequested
            first Ready
            then Stimulating;

        transition pulseDelivered
            first Stimulating
            then Acquiring;

        transition acquisitionComplete
            first Acquiring
            then Processing;

        transition processingComplete
            first Processing
            then Displaying;

        transition displayUpdated
            first Displaying
            then Ready;

        transition alarmDetected
            first Ready
            then AlarmActive;

        transition alarmAcknowledged
            first AlarmActive
            then Ready;

        transition unrecoverableFault
            first AlarmActive
            then Fault;

        transition powerOff
            first Ready
            then Off;
    }

    /* Part Definitions */

    part def SurfaceElectrodeSet {
        attribute placement : ElectrodePlacement = ElectrodePlacement::UlnarNerveAtWrist;
        attribute positiveElectrodeArea : ScalarValues::Real = 25.0;
        attribute negativeElectrodeArea : ScalarValues::Real = 25.0;
        attribute maximumAllowedImpedance : Impedance_ohm = 5000.0;

        port stimInterface : ElectrodeSkinPort;
    }

    part def PeripheralNerveStimulator {
        attribute maximumCurrent : ElectricCurrent_mA = 70.0;
        attribute minimumCurrent : ElectricCurrent_mA = 0.0;
        attribute currentResolution : ElectricCurrent_mA = 1.0;
        attribute nominalPulseWidth : Duration_ms = 0.2;
        attribute maximumVoltageCompliance : ElectricVoltage_V = 300.0;

        port stimulusOut : StimulusOutputPort;
        port powerIn : PoweredDevicePort;

        perform action deliverPulse : DeliverStimulation;
    }

    part def ThumbAccelerationSensor {
        attribute sensitiveAxis : SensorAxis = SensorAxis::Resultant;
        attribute measurementRange : Acceleration_mps2 = 157.0;
        attribute noiseDensity : Acceleration_mps2 = 0.02;
        attribute sampleRate : Frequency_Hz = 400.0;
        attribute sensorMass : Mass_g = 5.0;

        port motionOut : MotionSensingPort;
        port powerIn : PoweredDevicePort;

        perform action acquireMotion : AcquireAcceleration;
    }

    part def SignalConditioningModule {
        attribute lowPassCutoff : Frequency_Hz = 20.0;
        attribute highPassCutoff : Frequency_Hz = 0.2;
        attribute analogToDigitalResolutionBits : Integer = 16;

        port sensorIn : SensorInputPort;
        port conditionedOut : MotionSensingPort;
        port powerIn : PoweredDevicePort;
    }

    part def MeasurementProcessor {
        attribute supportedModes : MeasurementMode[6];
        attribute tofPulseCount : Integer = 4;
        attribute tofFrequency : Frequency_Hz = 2.0;
        attribute defaultRepeatInterval : Duration_s = 15.0;
        attribute validTofRecoveryThreshold : Ratio = 0.90;

        port sensorIn : SensorInputPort;
        port clinicianCommand : ProcessorCommandPort;
        port measurementOut : MeasurementOutputPort;
        port powerIn : PoweredDevicePort;

        perform action extractResponse : ExtractTwitchResponse;
        perform action computeBlockade : ComputeNeuromuscularBlockade;
        perform action checkQuality : EvaluateSignalQuality;

        exhibit state operationalState : MonitorOperationalState;
    }

    part def ClinicianInterface {
        attribute displayRefreshRate : Frequency_Hz = 1.0;
        attribute audibleAlarmEnabled : Boolean = true;
        attribute selectedMode : MeasurementMode = MeasurementMode::TrainOfFour;

        port userPort : UserCommandPort;
        port measurementIn : MeasurementInputPort;
        port powerIn : PoweredDevicePort;

        perform action showResult : PresentMeasurement;
    }

    part def RechargeablePowerModule {
        attribute nominalBatteryVoltage : ElectricVoltage_V = 7.4;
        attribute lowBatteryThreshold : Percent = 15.0;
        attribute fullChargeCapacity : Percent = 100.0;
        attribute externalPowerVoltage : ElectricVoltage_V = 12.0;

        port powerOut : PowerSupplyPort;
    }

    part def PatientHandInterface {
        attribute skinTemperature : Temperature_C = 33.0;
        attribute thumbFreeToMove : Boolean = true;
        attribute baselineThumbAcceleration : Acceleration_mps2 = 0.0;

        port electrodePort : ElectrodeSkinPort;
        port motionPort : MotionSensingPort;
    }

    part def Acceleromyograph {
        attribute primaryFunction : String =
            "Quantitatively monitor neuromuscular transmission by electrically stimulating a peripheral nerve, measuring evoked thumb acceleration, and reporting twitch response metrics such as train-of-four ratio.";

        attribute deviceMass : Mass_g = 850.0;
        attribute operatingTemperatureMin : Temperature_C = 10.0;
        attribute operatingTemperatureMax : Temperature_C = 40.0;
        attribute defaultMode : MeasurementMode = MeasurementMode::TrainOfFour;

        part powerModule : RechargeablePowerModule;
        part stimulator : PeripheralNerveStimulator;
        part electrodes : SurfaceElectrodeSet;
        part accelerationSensor : ThumbAccelerationSensor;
        part conditioner : SignalConditioningModule;
        part processor : MeasurementProcessor;
        part clinicianInterface : ClinicianInterface;
        part patientHand : PatientHandInterface;

        port clinicianPort : UserCommandPort;

        connect powerModule.powerOut to stimulator.powerIn;
        connect powerModule.powerOut to accelerationSensor.powerIn;
        connect powerModule.powerOut to conditioner.powerIn;
        connect powerModule.powerOut to processor.powerIn;
        connect powerModule.powerOut to clinicianInterface.powerIn;

        connect stimulator.stimulusOut to electrodes.stimInterface;
        connect electrodes.stimInterface to patientHand.electrodePort;

        connect patientHand.motionPort to accelerationSensor.motionOut;
        connect accelerationSensor.motionOut to conditioner.sensorIn;
        connect conditioner.conditionedOut to processor.sensorIn;

        connect clinicianInterface.userPort to processor.clinicianCommand;
        connect processor.measurementOut to clinicianInterface.measurementIn;
        connect clinicianInterface.userPort to clinicianPort;
    }

    /* System-Level Use Case */

    use case def MonitorNeuromuscularTransmission {
        subject monitor : Acceleromyograph;

        objective {
            doc /* Provide a high-level, continuous clinical indication of neuromuscular blockade and recovery by stimulating a selected peripheral nerve and calculating twitch response ratios from measured acceleration. */
        }

        actor clinician;

        include use case ConfigureStimulation;
        include use case DeliverPeripheralNerveStimulus;
        include use case MeasureEvokedThumbAcceleration;
        include use case ReportTrainOfFourRatio;
        include use case AlertOnInvalidMeasurement;
    }

    use case def ConfigureStimulation {
        subject monitor : Acceleromyograph;
        actor clinician;
    }

    use case def DeliverPeripheralNerveStimulus {
        subject monitor : Acceleromyograph;
    }

    use case def MeasureEvokedThumbAcceleration {
        subject monitor : Acceleromyograph;
    }

    use case def ReportTrainOfFourRatio {
        subject monitor : Acceleromyograph;
        actor clinician;
    }

    use case def AlertOnInvalidMeasurement {
        subject monitor : Acceleromyograph;
        actor clinician;
    }

    /* Requirements */

    requirement def PrimaryFunctionRequirement {
        doc /* The acceleromyograph shall stimulate a peripheral nerve and measure the acceleration of the associated muscle response to quantify neuromuscular transmission at a high level. */

        subject device : Acceleromyograph;

        require constraint {
            device.defaultMode == MeasurementMode::TrainOfFour
        }
    }

    requirement def StimulusCurrentRequirement {
        doc /* The stimulator shall deliver adjustable constant-current pulses from 0 mA to 70 mA with 1 mA resolution. */

        subject stim : PeripheralNerveStimulator;

        require constraint {
            stim.maximumCurrent >= 70.0 and stim.currentResolution <= 1.0
        }
    }

    requirement def PulseWidthRequirement {
        doc /* The stimulation pulse width shall be nominally 0.2 ms for train-of-four monitoring. */

        subject stim : PeripheralNerveStimulator;

        require constraint {
            stim.nominalPulseWidth == 0.2
        }
    }

    requirement def TrainOfFourRequirement {
        doc /* In train-of-four mode, the processor shall evaluate four evoked twitch responses at 2 Hz and compute the fourth-to-first twitch amplitude ratio. */

        subject processor : MeasurementProcessor;

        require constraint {
            processor.tofPulseCount == 4 and processor.tofFrequency == 2.0
        }
    }

    requirement def AccelerationSamplingRequirement {
        doc /* The acceleration sensor shall sample thumb motion at no less than 200 Hz after stimulation. */

        subject sensor : ThumbAccelerationSensor;

        require constraint {
            sensor.sampleRate >= 200.0
        }
    }

    requirement def ElectrodeImpedanceRequirement {
        doc /* The system shall identify an invalid patient interface when electrode impedance exceeds 5000 ohm. */

        subject electrodes : SurfaceElectrodeSet;

        require constraint {
            electrodes.maximumAllowedImpedance <= 5000.0
        }
    }

    requirement def RecoveryDisplayRequirement {
        doc /* The clinician interface shall display the train-of-four ratio as a percentage and indicate adequate recovery when the ratio is at least 90 percent. */

        subject processor : MeasurementProcessor;

        require constraint {
            processor.validTofRecoveryThreshold >= 0.90
        }
    }

    requirement def BatteryAlertRequirement {
        doc /* The power module shall support a low battery alarm when remaining charge is below 15 percent. */

        subject power : RechargeablePowerModule;

        require constraint {
            power.lowBatteryThreshold == 15.0
        }
    }

    requirement def SignalQualityRequirement {
        doc /* The processor shall reject measurements when the sensor is detached, thumb motion is constrained, or the first twitch response is not valid. */

        subject processor : MeasurementProcessor;
    }

    requirement def PatientSafetyRequirement {
        doc /* The system shall limit delivered stimulation energy by enforcing current limit, pulse width control, and electrode contact validation before stimulation. */

        subject device : Acceleromyograph;
    }

    satisfy PrimaryFunctionRequirement by Acceleromyograph;
    satisfy StimulusCurrentRequirement by PeripheralNerveStimulator;
    satisfy PulseWidthRequirement by PeripheralNerveStimulator;
    satisfy TrainOfFourRequirement by MeasurementProcessor;
    satisfy AccelerationSamplingRequirement by ThumbAccelerationSensor;
    satisfy ElectrodeImpedanceRequirement by SurfaceElectrodeSet;
    satisfy RecoveryDisplayRequirement by MeasurementProcessor;
    satisfy BatteryAlertRequirement by RechargeablePowerModule;
    satisfy SignalQualityRequirement by MeasurementProcessor;
    satisfy PatientSafetyRequirement by Acceleromyograph;

    /* Analysis Constraints */

    constraint def ToFRatioCalculation {
        in firstTwitch : Acceleration_mps2;
        in fourthTwitch : Acceleration_mps2;
        out tofRatio : Ratio;

        firstTwitch > 0.0;
        tofRatio == fourthTwitch / firstTwitch;
    }

    constraint def RecoveryPercentCalculation {
        in tofRatio : Ratio;
        out recoveryPercent : Percent;

        recoveryPercent == tofRatio * 100.0;
    }

    constraint def ElectrodeContactValidity {
        in impedance : Impedance_ohm;
        in limit : Impedance_ohm;
        out validContact : Boolean;

        validContact == impedance <= limit;
    }

    analysis def NeuromuscularTransmissionAnalysis {
        subject device : Acceleromyograph;

        attribute firstPeak : Acceleration_mps2;
        attribute fourthPeak : Acceleration_mps2;
        attribute computedRatio : Ratio;
        attribute computedRecovery : Percent;
        attribute interfaceImpedance : Impedance_ohm;
        attribute contactValid : Boolean;

        constraint ratioCalc : ToFRatioCalculation {
            firstTwitch = firstPeak;
            fourthTwitch = fourthPeak;
            tofRatio = computedRatio;
        }

        constraint recoveryCalc : RecoveryPercentCalculation {
            tofRatio = computedRatio;
            recoveryPercent = computedRecovery;
        }

        constraint contactCalc : ElectrodeContactValidity {
            impedance = interfaceImpedance;
            limit = device.electrodes.maximumAllowedImpedance;
            validContact = contactValid;
        }
    }

    /* Concrete System Instance */

    part operatingRoomAcceleromyograph : Acceleromyograph {
        attribute primaryFunction =
            "High-level monitoring of neuromuscular blockade by stimulating the ulnar nerve and measuring thumb acceleration to compute train-of-four ratio.";

        part electrodes {
            attribute placement = ElectrodePlacement::UlnarNerveAtWrist;
            attribute maximumAllowedImpedance = 5000.0;
        }

        part stimulator {
            attribute maximumCurrent = 70.0;
            attribute nominalPulseWidth = 0.2;
        }

        part accelerationSensor {
            attribute sensitiveAxis = SensorAxis::Resultant;
            attribute sampleRate = 400.0;
        }

        part processor {
            attribute defaultRepeatInterval = 15.0;
            attribute validTofRecoveryThreshold = 0.90;
        }

        part clinicianInterface {
            attribute selectedMode = MeasurementMode::TrainOfFour;
            attribute audibleAlarmEnabled = true;
        }
    }
}