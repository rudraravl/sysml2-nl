package PlethysmographSystemModel {

    private import ScalarValues::*;

    unit def nanometer;
    unit def milliwatt;
    unit def microampere;
    unit def volt;
    unit def hertz;
    unit def millisecond;
    unit def beatPerMinute;
    unit def percent;
    unit def milliliter;
    unit def degreeCelsius;

    attribute def OpticalWavelength :> Real {
        :>> unit = nanometer;
    }

    attribute def OpticalPowerLevel :> Real {
        :>> unit = milliwatt;
    }

    attribute def ElectricalCurrentLevel :> Real {
        :>> unit = microampere;
    }

    attribute def ElectricalVoltageLevel :> Real {
        :>> unit = volt;
    }

    attribute def SamplingFrequency :> Real {
        :>> unit = hertz;
    }

    attribute def TimeDuration :> Real {
        :>> unit = millisecond;
    }

    attribute def HeartRateValue :> Real {
        :>> unit = beatPerMinute;
    }

    attribute def RatioPercent :> Real {
        :>> unit = percent;
    }

    attribute def VolumeChangeValue :> Real {
        :>> unit = milliliter;
    }

    attribute def TemperatureValue :> Real {
        :>> unit = degreeCelsius;
    }

    item def ElectricalPower {
        attribute voltage : ElectricalVoltageLevel;
        attribute current : ElectricalCurrentLevel;
    }

    item def UserCommand {
        attribute startAcquisition : Boolean;
        attribute stopAcquisition : Boolean;
        attribute acknowledgeAlarm : Boolean;
    }

    item def OpticalRadiation {
        attribute wavelength : OpticalWavelength;
        attribute power : OpticalPowerLevel;
        attribute modulationFrequency : SamplingFrequency;
    }

    item def BackscatteredOpticalSignal :> OpticalRadiation {
        attribute pulsatileComponent : RatioPercent;
        attribute nonPulsatileComponent : RatioPercent;
    }

    item def PhotodiodeCurrent {
        attribute current : ElectricalCurrentLevel;
        attribute darkCurrent : ElectricalCurrentLevel;
        attribute signalToNoiseRatio : RatioPercent;
    }

    item def DigitizedPlethSample {
        attribute sampleTime : TimeDuration;
        attribute normalizedAmplitude : RatioPercent;
        attribute rawCode : Integer;
    }

    item def PlethysmogramWaveform {
        attribute samplingRate : SamplingFrequency;
        attribute duration : TimeDuration;
        attribute pulseAmplitude : RatioPercent;
        attribute baselineLevel : RatioPercent;
        attribute estimatedTissueVolumeChange : VolumeChangeValue;
    }

    item def PhysiologicMeasurement {
        attribute heartRate : HeartRateValue;
        attribute perfusionIndex : RatioPercent;
        attribute pulseAmplitude : RatioPercent;
        attribute signalQuality : RatioPercent;
    }

    item def DisplayFrame {
        attribute displayedHeartRate : HeartRateValue;
        attribute displayedPerfusionIndex : RatioPercent;
        attribute waveformScale : RatioPercent;
        attribute displayLatency : TimeDuration;
    }

    item def AlarmNotification {
        attribute lowPerfusion : Boolean;
        attribute sensorDisconnected : Boolean;
        attribute excessiveMotion : Boolean;
        attribute deviceFault : Boolean;
    }

    item def TissueOpticalResponse {
        attribute absorptionVariation : RatioPercent;
        attribute scatteringVariation : RatioPercent;
        attribute estimatedBloodVolumeChange : VolumeChangeValue;
        attribute tissueTemperature : TemperatureValue;
    }

    port def ElectricalPowerInPort {
        in item power : ElectricalPower;
    }

    port def ElectricalPowerOutPort {
        out item power : ElectricalPower;
    }

    port def UserCommandInPort {
        in item command : UserCommand;
    }

    port def OpticalOutPort {
        out item radiation : OpticalRadiation;
    }

    port def OpticalInPort {
        in item radiation : OpticalRadiation;
    }

    port def BackscatterInPort {
        in item response : BackscatteredOpticalSignal;
    }

    port def PhotodiodeCurrentOutPort {
        out item photocurrent : PhotodiodeCurrent;
    }

    port def PhotodiodeCurrentInPort {
        in item photocurrent : PhotodiodeCurrent;
    }

    port def DigitizedSampleOutPort {
        out item sample : DigitizedPlethSample;
    }

    port def DigitizedSampleInPort {
        in item sample : DigitizedPlethSample;
    }

    port def WaveformOutPort {
        out item waveform : PlethysmogramWaveform;
    }

    port def WaveformInPort {
        in item waveform : PlethysmogramWaveform;
    }

    port def MeasurementOutPort {
        out item measurement : PhysiologicMeasurement;
    }

    port def MeasurementInPort {
        in item measurement : PhysiologicMeasurement;
    }

    port def DisplayFrameOutPort {
        out item frame : DisplayFrame;
    }

    port def DisplayFrameInPort {
        in item frame : DisplayFrame;
    }

    port def AlarmOutPort {
        out item alarm : AlarmNotification;
    }

    port def AlarmInPort {
        in item alarm : AlarmNotification;
    }

    port def TissueContactPort {
        in item tissueResponse : TissueOpticalResponse;
        out item incidentLight : OpticalRadiation;
    }

    part def PerfusedTissue {
        attribute localBloodVolumeChange : VolumeChangeValue;
        attribute nominalPerfusionIndex : RatioPercent;
        attribute skinTemperature : TemperatureValue;

        port measurementSite : TissueContactPort;
    }

    part def PowerSubsystem {
        attribute nominalOutputVoltage : ElectricalVoltageLevel = 5.0;
        attribute maximumOutputCurrent : ElectricalCurrentLevel = 500000.0;

        port externalPowerIn : ElectricalPowerInPort;
        port regulatedPowerOut : ElectricalPowerOutPort;
    }

    part def LightEmitter {
        attribute nominalWavelength : OpticalWavelength;
        attribute maximumOpticalPower : OpticalPowerLevel;
        attribute driveCurrentLimit : ElectricalCurrentLevel;

        port powerIn : ElectricalPowerInPort;
        port opticalOut : OpticalOutPort;
    }

    part def RedLightEmitter :> LightEmitter {
        :>> nominalWavelength = 660.0;
        :>> maximumOpticalPower = 3.0;
        :>> driveCurrentLimit = 20000.0;
    }

    part def InfraredLightEmitter :> LightEmitter {
        :>> nominalWavelength = 940.0;
        :>> maximumOpticalPower = 3.0;
        :>> driveCurrentLimit = 20000.0;
    }

    part def TissueOpticalCoupler {
        attribute contactStable : Boolean;
        attribute ambientLightRejected : RatioPercent = 95.0;

        port tissuePort : TissueContactPort;
        port redInput : OpticalInPort;
        port infraredInput : OpticalInPort;
        port returnedLightOut : OpticalOutPort;
    }

    part def Photodetector {
        attribute responsivity : RatioPercent;
        attribute darkCurrentLimit : ElectricalCurrentLevel = 1.0;

        port opticalIn : OpticalInPort;
        port currentOut : PhotodiodeCurrentOutPort;
        port powerIn : ElectricalPowerInPort;
    }

    part def OpticalSensorHead {
        attribute attachedToPatient : Boolean;
        attribute contactPressureAcceptable : Boolean;
        attribute ambientLightLevelAcceptable : Boolean;

        port powerIn : ElectricalPowerInPort;
        port patientInterface : TissueContactPort;
        port photocurrentOut : PhotodiodeCurrentOutPort;

        part redEmitter : RedLightEmitter;
        part infraredEmitter : InfraredLightEmitter;
        part opticalCoupler : TissueOpticalCoupler;
        part photodetector : Photodetector;

        connect powerIn to redEmitter.powerIn;
        connect powerIn to infraredEmitter.powerIn;
        connect powerIn to photodetector.powerIn;
        connect redEmitter.opticalOut to opticalCoupler.redInput;
        connect infraredEmitter.opticalOut to opticalCoupler.infraredInput;
        connect opticalCoupler.tissuePort to patientInterface;
        connect opticalCoupler.returnedLightOut to photodetector.opticalIn;
        connect photodetector.currentOut to photocurrentOut;
    }

    part def AnalogFrontEnd {
        attribute transimpedanceGain : RatioPercent;
        attribute highPassCorner : SamplingFrequency = 0.5;
        attribute lowPassCorner : SamplingFrequency = 20.0;
        attribute saturationDetected : Boolean;

        port powerIn : ElectricalPowerInPort;
        port photocurrentIn : PhotodiodeCurrentInPort;
        port analogSampleOut : DigitizedSampleOutPort;
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer = 16;
        attribute sampleRate : SamplingFrequency = 200.0;
        attribute conversionLatency : TimeDuration = 2.0;

        port powerIn : ElectricalPowerInPort;
        port sampleIn : DigitizedSampleInPort;
        port sampleOut : DigitizedSampleOutPort;
    }

    part def SignalProcessor {
        attribute minimumAcceptableSignalQuality : RatioPercent = 70.0;
        attribute motionArtifactRejected : Boolean;
        attribute baselineTrackingEnabled : Boolean = true;

        port powerIn : ElectricalPowerInPort;
        port sampleIn : DigitizedSampleInPort;
        port waveformOut : WaveformOutPort;
        port measurementOut : MeasurementOutPort;
        port alarmOut : AlarmOutPort;
    }

    part def DisplayAndUserInterface {
        attribute waveformRefreshRate : SamplingFrequency = 30.0;
        attribute maximumDisplayLatency : TimeDuration = 250.0;

        port powerIn : ElectricalPowerInPort;
        port commandIn : UserCommandInPort;
        port waveformIn : WaveformInPort;
        port measurementIn : MeasurementInPort;
        port alarmIn : AlarmInPort;
        port displayedFrameOut : DisplayFrameOutPort;
    }

    part def DataLogger {
        attribute retainedWaveformDuration : TimeDuration = 600000.0;
        attribute storesMeasurementTrends : Boolean = true;

        port powerIn : ElectricalPowerInPort;
        port waveformIn : WaveformInPort;
        port measurementIn : MeasurementInPort;
        port alarmIn : AlarmInPort;
    }

    action def EmitControlledLight {
        in item command : UserCommand;
        out item redPulse : OpticalRadiation;
        out item infraredPulse : OpticalRadiation;
    }

    action def IlluminatePerfusedTissue {
        in item redPulse : OpticalRadiation;
        in item infraredPulse : OpticalRadiation;
        in item tissueState : TissueOpticalResponse;
        out item returnedSignal : BackscatteredOpticalSignal;
    }

    action def DetectReturnedLight {
        in item returnedSignal : BackscatteredOpticalSignal;
        out item photocurrent : PhotodiodeCurrent;
    }

    action def ConditionAndDigitizeSignal {
        in item photocurrent : PhotodiodeCurrent;
        out item digitizedSample : DigitizedPlethSample;
    }

    action def BuildPlethysmogram {
        in item digitizedSample : DigitizedPlethSample;
        out item waveform : PlethysmogramWaveform;
    }

    action def EstimatePulseMetrics {
        in item waveform : PlethysmogramWaveform;
        out item measurement : PhysiologicMeasurement;
        out item alarm : AlarmNotification;
    }

    action def PresentPlethysmographicInformation {
        in item waveform : PlethysmogramWaveform;
        in item measurement : PhysiologicMeasurement;
        in item alarm : AlarmNotification;
        out item frame : DisplayFrame;
    }

    action def AcquireAndReportPlethysmogram {
        in item operatorCommand : UserCommand;
        in item tissueResponse : TissueOpticalResponse;
        out item waveform : PlethysmogramWaveform;
        out item measurement : PhysiologicMeasurement;
        out item alarm : AlarmNotification;
        out item displayFrame : DisplayFrame;

        action emit : EmitControlledLight;
        action illuminate : IlluminatePerfusedTissue;
        action detect : DetectReturnedLight;
        action digitize : ConditionAndDigitizeSignal;
        action buildWaveform : BuildPlethysmogram;
        action estimateMetrics : EstimatePulseMetrics;
        action present : PresentPlethysmographicInformation;

        flow operatorCommand to emit.command;
        flow emit.redPulse to illuminate.redPulse;
        flow emit.infraredPulse to illuminate.infraredPulse;
        flow tissueResponse to illuminate.tissueState;
        flow illuminate.returnedSignal to detect.returnedSignal;
        flow detect.photocurrent to digitize.photocurrent;
        flow digitize.digitizedSample to buildWaveform.digitizedSample;
        flow buildWaveform.waveform to estimateMetrics.waveform;
        flow buildWaveform.waveform to present.waveform;
        flow estimateMetrics.measurement to present.measurement;
        flow estimateMetrics.alarm to present.alarm;
        flow buildWaveform.waveform to waveform;
        flow estimateMetrics.measurement to measurement;
        flow estimateMetrics.alarm to alarm;
        flow present.frame to displayFrame;
    }

    state def PlethysmographOperatingStateMachine {
        entry; then PoweredOff;

        state PoweredOff {
            accept UserCommand then SelfTest;
        }

        state SelfTest {
            entry action verifyPower;
            entry action verifyOpticalPath;
            entry action verifyProcessorMemory;
            then Ready;
        }

        state Ready {
            accept UserCommand then Acquiring;
        }

        state Acquiring {
            do action acquire : AcquireAndReportPlethysmogram;
            accept UserCommand then Ready;
            accept AlarmNotification then FaultHandling;
        }

        state Processing {
            do action build : BuildPlethysmogram;
            do action estimate : EstimatePulseMetrics;
            then Reporting;
        }

        state Reporting {
            do action present : PresentPlethysmographicInformation;
            then Acquiring;
        }

        state FaultHandling {
            entry action disableOpticalEmitters;
            entry action notifyOperator;
            accept UserCommand then SelfTest;
        }
    }

    part def Plethysmograph {
        doc /*
            A plethysmograph is a measurement system whose primary high-level function is to sense,
            record, and present changes in tissue or organ volume. This model specializes that function
            as a noninvasive optical plethysmograph that illuminates perfused tissue, detects pulsatile
            optical changes caused by blood-volume variation, and outputs a plethysmographic waveform
            with derived pulse metrics.
        */

        attribute canProducePlethysmogram : Boolean = true;
        attribute noninvasiveMeasurement : Boolean = true;
        attribute nominalSamplingRate : SamplingFrequency = 200.0;
        attribute maximumPrimaryFunctionLatency : TimeDuration = 500.0;

        port externalPowerIn : ElectricalPowerInPort;
        port operatorCommandIn : UserCommandInPort;
        port patientInterface : TissueContactPort;
        port waveformOut : WaveformOutPort;
        port measurementOut : MeasurementOutPort;
        port displayFrameOut : DisplayFrameOutPort;
        port alarmOut : AlarmOutPort;

        part powerSubsystem : PowerSubsystem;
        part sensorHead : OpticalSensorHead;
        part analogFrontEnd : AnalogFrontEnd;
        part adc : AnalogToDigitalConverter;
        part processor : SignalProcessor;
        part userInterface : DisplayAndUserInterface;
        part dataLogger : DataLogger;

        connect externalPowerIn to powerSubsystem.externalPowerIn;
        connect powerSubsystem.regulatedPowerOut to sensorHead.powerIn;
        connect powerSubsystem.regulatedPowerOut to analogFrontEnd.powerIn;
        connect powerSubsystem.regulatedPowerOut to adc.powerIn;
        connect powerSubsystem.regulatedPowerOut to processor.powerIn;
        connect powerSubsystem.regulatedPowerOut to userInterface.powerIn;
        connect powerSubsystem.regulatedPowerOut to dataLogger.powerIn;

        connect patientInterface to sensorHead.patientInterface;
        connect sensorHead.photocurrentOut to analogFrontEnd.photocurrentIn;
        connect analogFrontEnd.analogSampleOut to adc.sampleIn;
        connect adc.sampleOut to processor.sampleIn;

        connect processor.waveformOut to userInterface.waveformIn;
        connect processor.measurementOut to userInterface.measurementIn;
        connect processor.alarmOut to userInterface.alarmIn;

        connect processor.waveformOut to dataLogger.waveformIn;
        connect processor.measurementOut to dataLogger.measurementIn;
        connect processor.alarmOut to dataLogger.alarmIn;

        connect processor.waveformOut to waveformOut;
        connect processor.measurementOut to measurementOut;
        connect processor.alarmOut to alarmOut;
        connect userInterface.displayedFrameOut to displayFrameOut;
        connect operatorCommandIn to userInterface.commandIn;

        perform action primaryPlethysmographFunction : AcquireAndReportPlethysmogram;
        exhibit state operatingStates : PlethysmographOperatingStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : Plethysmograph;

        doc /*
            The plethysmograph shall perform the high-level primary function of detecting changes in
            perfused tissue volume and producing a plethysmogram waveform that represents those volume
            changes over time.
        */

        require constraint {
            system.canProducePlethysmogram == true
        }

        require constraint {
            system.noninvasiveMeasurement == true
        }
    }

    requirement def SamplingRequirement {
        subject system : Plethysmograph;

        doc /*
            The plethysmograph shall sample the pulsatile tissue response at a rate sufficient to
            reconstruct a clinical pulse waveform.
        */

        require constraint {
            system.nominalSamplingRate >= 100.0
        }
    }

    requirement def LatencyRequirement {
        subject system : Plethysmograph;

        doc /*
            The plethysmograph shall present the measured waveform and pulse metrics within the maximum
            primary-function latency after acquisition.
        */

        require constraint {
            system.maximumPrimaryFunctionLatency <= 500.0
        }
    }

    requirement def NoninvasiveInterfaceRequirement {
        subject system : Plethysmograph;

        doc /*
            The patient interface shall allow plethysmographic measurement through external contact with
            perfused tissue without penetrating the tissue.
        */

        require constraint {
            system.noninvasiveMeasurement == true
        }
    }

    part plethysmographSystem : Plethysmograph;

    part patientFinger : PerfusedTissue {
        :>> localBloodVolumeChange = 0.08;
        :>> nominalPerfusionIndex = 4.0;
        :>> skinTemperature = 33.0;
    }

    item externalPowerSupply : ElectricalPower {
        :>> voltage = 5.0;
        :>> current = 200000.0;
    }

    connect plethysmographSystem.patientInterface to patientFinger.measurementSite;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject system = plethysmographSystem;
    }

    requirement samplingAdequacy : SamplingRequirement {
        subject system = plethysmographSystem;
    }

    requirement outputLatency : LatencyRequirement {
        subject system = plethysmographSystem;
    }

    requirement noninvasivePatientInterface : NoninvasiveInterfaceRequirement {
        subject system = plethysmographSystem;
    }

    satisfy primaryFunction by plethysmographSystem;
    satisfy samplingAdequacy by plethysmographSystem.processor;
    satisfy samplingAdequacy by plethysmographSystem.adc;
    satisfy outputLatency by plethysmographSystem.processor;
    satisfy outputLatency by plethysmographSystem.userInterface;
    satisfy noninvasivePatientInterface by plethysmographSystem.sensorHead;
}
