package PlethysmographSystemModel {

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    alias mmHg for PressureUnit;
    alias mL for VolumeUnit;
    alias ms for TimeUnit;
    alias Hz for FrequencyUnit;
    alias percent for DimensionlessUnit;

    value def BloodVolume {
        :> Real;
        unit = mL;
        doc /* Volume of blood represented in a measured body segment or optical sensing region. */
    }

    value def Pressure {
        :> Real;
        unit = mmHg;
        doc /* Pressure applied by cuff, tissue, or ambient conditions. */
    }

    value def OpticalIntensity {
        :> Real;
        unit = percent;
        doc /* Relative transmitted or reflected optical signal intensity. */
    }

    value def SamplingRate {
        :> Real;
        unit = Hz;
        doc /* Number of sensor samples acquired per second. */
    }

    value def TimeDuration {
        :> Real;
        unit = ms;
        doc /* Time duration used for acquisition windows and pulse intervals. */
    }

    value def PulseRate {
        :> Real;
        unit = Hz;
        doc /* Frequency of pulsatile blood-volume changes. */
    }

    item def TissueOpticalSignal {
        attribute redIntensity : OpticalIntensity;
        attribute infraredIntensity : OpticalIntensity;
        attribute ambientIntensity : OpticalIntensity;
        attribute acquisitionTime : TimeDuration;
    }

    item def PressureSignal {
        attribute cuffPressure : Pressure;
        attribute chamberPressure : Pressure;
        attribute acquisitionTime : TimeDuration;
    }

    item def PlethysmographicWaveform {
        attribute sampleRate : SamplingRate;
        attribute acAmplitude : OpticalIntensity;
        attribute dcLevel : OpticalIntensity;
        attribute estimatedVolumeChange : BloodVolume;
        attribute pulseInterval : TimeDuration;
    }

    item def PhysiologicalEstimate {
        attribute pulseRate : PulseRate;
        attribute relativePerfusionIndex : percent;
        attribute signalQuality : percent;
        attribute valid : Boolean;
    }

    item def UserCommand {
        attribute startMeasurement : Boolean;
        attribute stopMeasurement : Boolean;
        attribute calibrate : Boolean;
    }

    item def StatusMessage {
        attribute ready : Boolean;
        attribute measuring : Boolean;
        attribute faultPresent : Boolean;
        attribute signalQuality : percent;
    }

    port def OpticalEmitterPort {
        out redLight : OpticalIntensity;
        out infraredLight : OpticalIntensity;
    }

    port def OpticalDetectorPort {
        in tissueSignal : TissueOpticalSignal;
    }

    port def PressureTransducerPort {
        in pressureSignal : PressureSignal;
    }

    port def WaveformPort {
        out waveform : PlethysmographicWaveform;
    }

    port def EstimatePort {
        out estimate : PhysiologicalEstimate;
    }

    port def CommandPort {
        in command : UserCommand;
    }

    port def StatusPort {
        out status : StatusMessage;
    }

    part def OpticalEmitter {
        attribute redWavelength_nm : Real = 660.0;
        attribute infraredWavelength_nm : Real = 940.0;
        attribute driveCurrent_mA : Real;
        port opticalOut : OpticalEmitterPort;
    }

    part def Photodetector {
        attribute darkCurrent_nA : Real;
        attribute gain : Real;
        port opticalIn : OpticalDetectorPort;
    }

    part def PressureSensor {
        attribute rangeMinimum : Pressure = 0.0;
        attribute rangeMaximum : Pressure = 300.0;
        port pressureIn : PressureTransducerPort;
    }

    part def AnalogFrontEnd {
        attribute amplifierGain : Real = 64.0;
        attribute highPassCutoff : PulseRate = 0.5;
        attribute lowPassCutoff : PulseRate = 12.0;
        port detectorInput : OpticalDetectorPort;
        port pressureInput : PressureTransducerPort;
        port waveformOut : WaveformPort;
    }

    part def SignalProcessor {
        attribute nominalSampleRate : SamplingRate = 200.0;
        attribute minimumSignalQuality : percent = 70.0;
        port rawWaveformIn : WaveformPort;
        port estimateOut : EstimatePort;

        action filterAndEstimate {
            in raw : PlethysmographicWaveform;
            out estimate : PhysiologicalEstimate;

            first start;
            then removeAmbientComponent;
            then isolatePulsatileComponent;
            then detectPulsePeaks;
            then calculatePerfusionIndex;
            then assessSignalQuality;
            then publishEstimate;

            action removeAmbientComponent;
            action isolatePulsatileComponent;
            action detectPulsePeaks;
            action calculatePerfusionIndex;
            action assessSignalQuality;
            action publishEstimate;
        }
    }

    part def UserInterface {
        port commandOut : CommandPort;
        port statusIn : StatusPort;
        port estimateIn : EstimatePort;
    }

    part def PlethysmographController {
        attribute acquisitionWindow : TimeDuration = 8000.0;
        attribute calibrationDuration : TimeDuration = 2000.0;
        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port waveformIn : WaveformPort;
        port estimateIn : EstimatePort;

        state def MeasurementControl {
            state idle;
            state calibrating;
            state acquiring;
            state processing;
            state reporting;
            state fault;

            transition idle_to_calibrating
                first idle
                accept UserCommand
                if calibrate
                then calibrating;

            transition idle_to_acquiring
                first idle
                accept UserCommand
                if startMeasurement
                then acquiring;

            transition calibrating_to_idle
                first calibrating
                after calibrationDuration
                then idle;

            transition acquiring_to_processing
                first acquiring
                after acquisitionWindow
                then processing;

            transition processing_to_reporting
                first processing
                then reporting;

            transition reporting_to_acquiring
                first reporting
                accept UserCommand
                if startMeasurement
                then acquiring;

            transition reporting_to_idle
                first reporting
                accept UserCommand
                if stopMeasurement
                then idle;

            transition any_to_fault
                first idle
                then fault;

            transition fault_to_idle
                first fault
                accept UserCommand
                if calibrate
                then idle;
        }
    }

    part def Plethysmograph {
        doc /* A plethysmograph is a measurement system that senses pulsatile changes in blood volume within a body region and converts those changes into a plethysmographic waveform and high-level physiological estimates. */

        attribute primaryFunction : String =
            "Detect and characterize cyclic blood-volume variation in tissue to support noninvasive cardiovascular monitoring.";

        part emitter : OpticalEmitter;
        part detector : Photodetector;
        part pressureSensor : PressureSensor;
        part analogFrontEnd : AnalogFrontEnd;
        part processor : SignalProcessor;
        part controller : PlethysmographController;
        part userInterface : UserInterface;

        port userCommand : CommandPort;
        port userStatus : StatusPort;
        port physiologicalOutput : EstimatePort;

        connect emitter.opticalOut to detector.opticalIn;
        connect detector.opticalIn to analogFrontEnd.detectorInput;
        connect pressureSensor.pressureIn to analogFrontEnd.pressureInput;
        connect analogFrontEnd.waveformOut to processor.rawWaveformIn;
        connect analogFrontEnd.waveformOut to controller.waveformIn;
        connect processor.estimateOut to controller.estimateIn;
        connect processor.estimateOut to userInterface.estimateIn;
        connect processor.estimateOut to physiologicalOutput;
        connect userCommand to controller.commandIn;
        connect userCommand to userInterface.commandOut;
        connect controller.statusOut to userStatus;
        connect controller.statusOut to userInterface.statusIn;

        action performPrimaryFunction {
            in command : UserCommand;
            out waveform : PlethysmographicWaveform;
            out estimate : PhysiologicalEstimate;
            out status : StatusMessage;

            first receiveMeasurementCommand;
            then illuminateTissue;
            then senseOpticalOrPressureVariation;
            then conditionAnalogSignal;
            then sampleWaveform;
            then estimatePhysiologicalParameters;
            then reportStatusAndEstimate;

            action receiveMeasurementCommand;
            action illuminateTissue;
            action senseOpticalOrPressureVariation;
            action conditionAnalogSignal;
            action sampleWaveform;
            action estimatePhysiologicalParameters;
            action reportStatusAndEstimate;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The plethysmograph shall noninvasively detect pulsatile blood-volume variation and provide a plethysmographic waveform suitable for physiological interpretation. */
        subject system : Plethysmograph;

        require constraint {
            system.processor.nominalSampleRate >= 100.0
        }

        require constraint {
            system.processor.minimumSignalQuality >= 70.0
        }
    }

    requirement def WaveformOutputRequirement {
        doc /* The system shall output a waveform containing AC amplitude, DC level, estimated volume change, pulse interval, and sampling rate. */
        subject waveform : PlethysmographicWaveform;

        require constraint {
            waveform.sampleRate >= 100.0
        }
    }

    requirement def MonitoringStatusRequirement {
        doc /* The system shall indicate readiness, active measurement state, fault state, and current signal quality to the user interface. */
        subject status : StatusMessage;
    }

    part operationalPlethysmograph : Plethysmograph;

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject system = operationalPlethysmograph;
    }

    requirement waveformOutputRequirement : WaveformOutputRequirement;

    requirement monitoringStatusRequirement : MonitoringStatusRequirement;
}