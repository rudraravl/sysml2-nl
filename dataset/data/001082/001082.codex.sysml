package HolographicSensingUnitModel {

    import ScalarValues::*;
    import SI::*;

    attribute def Wavelength :> Real {
        unit = "nm";
    }

    attribute def OpticalPower :> Real {
        unit = "mW";
    }

    attribute def OpticalIntensity :> Real {
        unit = "mW/cm^2";
    }

    attribute def ExposureTime :> Real {
        unit = "ms";
    }

    attribute def Temperature :> Real {
        unit = "degC";
    }

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def Displacement :> Real {
        unit = "um";
    }

    attribute def PhaseAngle :> Real {
        unit = "rad";
    }

    attribute def RefractiveIndex :> Real;

    attribute def Concentration :> Real {
        unit = "mg/L";
    }

    attribute def SignalToNoiseRatio :> Real {
        unit = "dB";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Current :> Real {
        unit = "mA";
    }

    attribute def SampleRate :> Real {
        unit = "Hz";
    }

    attribute def DataRate :> Real {
        unit = "Mbit/s";
    }

    attribute def TimeStamp :> Real {
        unit = "s";
    }

    attribute def MeasurementUncertainty :> Real {
        unit = "mg/L";
    }

    item def OpticalBeam {
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
        attribute coherenceLength : Real {
            unit = "mm";
        }
        attribute polarizationAngle : PhaseAngle;
    }

    item def HologramFrame {
        attribute frameId : Integer;
        attribute capturedAt : TimeStamp;
        attribute exposure : ExposureTime;
        attribute referenceIntensity : OpticalIntensity;
        attribute objectIntensity : OpticalIntensity;
        attribute interferenceContrast : Real;
        attribute meanPhase : PhaseAngle;
    }

    item def ReconstructedField {
        attribute phaseShift : PhaseAngle;
        attribute amplitude : Real;
        attribute reconstructedAt : TimeStamp;
        attribute qualityIndex : Real;
        attribute snr : SignalToNoiseRatio;
    }

    item def AnalyteSample {
        attribute refractiveIndex : RefractiveIndex;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute targetConcentration : Concentration;
    }

    item def ConcentrationMeasurement {
        attribute value : Concentration;
        attribute uncertainty : MeasurementUncertainty;
        attribute measuredAt : TimeStamp;
        attribute confidence : Real;
        attribute valid : Boolean;
    }

    item def DiagnosticReport {
        attribute opticalAlignmentOk : Boolean;
        attribute detectorOk : Boolean;
        attribute thermalOk : Boolean;
        attribute contaminationDetected : Boolean;
        attribute snr : SignalToNoiseRatio;
        attribute reportTime : TimeStamp;
    }

    port def OpticalInputPort {
        in item beam : OpticalBeam;
    }

    port def OpticalOutputPort {
        out item beam : OpticalBeam;
    }

    port def SamplePort {
        in item sample : AnalyteSample;
    }

    port def HologramPort {
        out item frame : HologramFrame;
    }

    port def FieldPort {
        out item field : ReconstructedField;
    }

    port def MeasurementPort {
        out item measurement : ConcentrationMeasurement;
    }

    port def DiagnosticPort {
        out item report : DiagnosticReport;
    }

    port def PowerPort {
        in attribute supplyVoltage : Voltage;
        in attribute supplyCurrent : Current;
    }

    port def CommandPort {
        in attribute startRequested : Boolean;
        in attribute stopRequested : Boolean;
        in attribute calibrateRequested : Boolean;
        in attribute selfTestRequested : Boolean;
    }

    part def LaserSource {
        attribute nominalWavelength : Wavelength = 635.0;
        attribute outputPower : OpticalPower = 5.0;
        attribute wavelengthTolerance : Wavelength = 0.5;
        attribute enabled : Boolean = false;

        port power : PowerPort;
        port emittedBeam : OpticalOutputPort;

        action emitCoherentBeam {
            in attribute enable : Boolean;
            out item beam : OpticalBeam;

            first start;
            then setEnabled;
            then produceBeam;
            then done;

            action setEnabled {
                in attribute enable : Boolean;
                out attribute enabledState : Boolean;
            }

            action produceBeam {
                in attribute enabledState : Boolean;
                out item beam : OpticalBeam;
            }
        }
    }

    part def BeamSplitter {
        attribute splitRatio : Real = 0.5;
        attribute insertionLoss : Real = 0.03;

        port inputBeam : OpticalInputPort;
        port referenceBeam : OpticalOutputPort;
        port objectBeam : OpticalOutputPort;

        action splitBeam {
            in item sourceBeam : OpticalBeam;
            out item reference : OpticalBeam;
            out item object : OpticalBeam;
        }
    }

    part def ReferenceArm {
        attribute pathLength : Real {
            unit = "mm";
        } = 42.0;
        attribute mirrorDisplacement : Displacement = 0.0;
        attribute phaseBias : PhaseAngle = 0.0;

        port inputBeam : OpticalInputPort;
        port outputBeam : OpticalOutputPort;

        action adjustReferencePhase {
            in attribute requestedPhaseBias : PhaseAngle;
            out attribute appliedPhaseBias : PhaseAngle;
        }
    }

    part def SampleCell {
        attribute opticalPathLength : Real {
            unit = "mm";
        } = 10.0;
        attribute chamberVolume : Real {
            unit = "uL";
        } = 120.0;
        attribute maxPressure : Pressure = 200000.0;
        attribute nominalTemperature : Temperature = 25.0;

        port sampleIn : SamplePort;
        port incidentBeam : OpticalInputPort;
        port modulatedBeam : OpticalOutputPort;

        action modulateObjectBeam {
            in item sample : AnalyteSample;
            in item incident : OpticalBeam;
            out item modulated : OpticalBeam;
            out attribute phaseShift : PhaseAngle;
        }
    }

    part def HolographicSensor {
        attribute sensorPitch : Real {
            unit = "um";
        } = 2.2;
        attribute pixelCountX : Integer = 2048;
        attribute pixelCountY : Integer = 2048;
        attribute exposureTime : ExposureTime = 10.0;
        attribute saturationThreshold : OpticalIntensity = 8.0;
        attribute minimumContrast : Real = 0.18;

        port referenceBeam : OpticalInputPort;
        port objectBeam : OpticalInputPort;
        port hologramOut : HologramPort;

        action captureInterferencePattern {
            in item reference : OpticalBeam;
            in item object : OpticalBeam;
            out item hologram : HologramFrame;

            first configureExposure;
            then integratePhotocharge;
            then readOutFrame;
            then validateContrast;
            then done;

            action configureExposure {
                in attribute requestedExposure : ExposureTime;
                out attribute appliedExposure : ExposureTime;
            }

            action integratePhotocharge {
                in item reference : OpticalBeam;
                in item object : OpticalBeam;
                out attribute referenceIntensity : OpticalIntensity;
                out attribute objectIntensity : OpticalIntensity;
                out attribute interferenceContrast : Real;
            }

            action readOutFrame {
                in attribute referenceIntensity : OpticalIntensity;
                in attribute objectIntensity : OpticalIntensity;
                in attribute interferenceContrast : Real;
                out item rawFrame : HologramFrame;
            }

            action validateContrast {
                in item rawFrame : HologramFrame;
                out item validatedFrame : HologramFrame;
            }
        }
    }

    part def TemperatureController {
        attribute measuredTemperature : Temperature = 25.0;
        attribute setPoint : Temperature = 25.0;
        attribute stability : Temperature = 0.05;
        attribute heaterPower : Real {
            unit = "W";
        } = 0.0;

        port power : PowerPort;

        action regulateTemperature {
            in attribute targetTemperature : Temperature;
            out attribute stabilizedTemperature : Temperature;
        }
    }

    part def SignalProcessor {
        attribute reconstructionSampleRate : SampleRate = 30.0;
        attribute minimumSnr : SignalToNoiseRatio = 24.0;
        attribute calibrationSlope : Real {
            unit = "rad/(mg/L)";
        } = 0.0024;
        attribute calibrationOffset : PhaseAngle = 0.0;
        attribute lastPhaseShift : PhaseAngle = 0.0;

        port hologramIn : HologramPort;
        port fieldOut : FieldPort;
        port measurementOut : MeasurementPort;
        port diagnosticOut : DiagnosticPort;

        action reconstructOpticalField {
            in item hologram : HologramFrame;
            out item field : ReconstructedField;

            first subtractBackground;
            then applyFourierReconstruction;
            then unwrapPhase;
            then estimateQuality;
            then done;

            action subtractBackground {
                in item hologram : HologramFrame;
                out item correctedHologram : HologramFrame;
            }

            action applyFourierReconstruction {
                in item correctedHologram : HologramFrame;
                out item complexField : ReconstructedField;
            }

            action unwrapPhase {
                in item complexField : ReconstructedField;
                out item unwrappedField : ReconstructedField;
            }

            action estimateQuality {
                in item unwrappedField : ReconstructedField;
                out item qualifiedField : ReconstructedField;
            }
        }

        action estimateConcentration {
            in item field : ReconstructedField;
            out item measurement : ConcentrationMeasurement;

            first compensateTemperature;
            then applyCalibrationCurve;
            then calculateUncertainty;
            then validateMeasurement;
            then done;

            action compensateTemperature {
                in item field : ReconstructedField;
                out attribute compensatedPhase : PhaseAngle;
            }

            action applyCalibrationCurve {
                in attribute compensatedPhase : PhaseAngle;
                out attribute concentration : Concentration;
            }

            action calculateUncertainty {
                in attribute concentration : Concentration;
                out attribute uncertainty : MeasurementUncertainty;
            }

            action validateMeasurement {
                in attribute concentration : Concentration;
                in attribute uncertainty : MeasurementUncertainty;
                out item measurement : ConcentrationMeasurement;
            }
        }

        action generateDiagnostics {
            in item hologram : HologramFrame;
            in item field : ReconstructedField;
            out item report : DiagnosticReport;
        }
    }

    part def Controller {
        attribute powered : Boolean = false;
        attribute calibrated : Boolean = false;
        attribute measuring : Boolean = false;
        attribute faultPresent : Boolean = false;
        attribute sampleInterval : Real {
            unit = "s";
        } = 1.0;

        port commands : CommandPort;
        port diagnostics : DiagnosticPort;

        state def OperatingStateMachine {
            entry action initializeElectronics;

            state Off;
            state Standby;
            state SelfTest;
            state Calibration;
            state Ready;
            state Measuring;
            state Fault;
            state Shutdown;

            transition initial then Off;

            transition powerApplied
                first Off
                accept true
                then Standby;

            transition requestSelfTest
                first Standby
                accept selfTestRequested
                then SelfTest;

            transition selfTestPassed
                first SelfTest
                accept opticalAlignmentOk and detectorOk and thermalOk
                then Ready;

            transition selfTestFailed
                first SelfTest
                accept not opticalAlignmentOk or not detectorOk or not thermalOk
                then Fault;

            transition requestCalibration
                first Ready
                accept calibrateRequested
                then Calibration;

            transition calibrationComplete
                first Calibration
                accept true
                then Ready;

            transition startMeasurement
                first Ready
                accept startRequested and calibrated
                then Measuring;

            transition stopMeasurement
                first Measuring
                accept stopRequested
                then Ready;

            transition measurementFault
                first Measuring
                accept contaminationDetected or not detectorOk
                then Fault;

            transition clearFault
                first Fault
                accept selfTestRequested
                then SelfTest;

            transition removePower
                first Standby
                accept false
                then Shutdown;
        }

        action initializeElectronics {
            out attribute initialized : Boolean;
        }

        action coordinateMeasurementCycle {
            in attribute startRequested : Boolean;
            out attribute captureRequested : Boolean;
            out attribute processingRequested : Boolean;
        }
    }

    part def HolographicSensingUnit {
        attribute measurementRangeMin : Concentration = 0.0;
        attribute measurementRangeMax : Concentration = 1000.0;
        attribute requiredAccuracy : MeasurementUncertainty = 2.0;
        attribute operatingTemperatureMin : Temperature = 10.0;
        attribute operatingTemperatureMax : Temperature = 45.0;
        attribute nominalSupplyVoltage : Voltage = 12.0;
        attribute nominalSupplyCurrent : Current = 500.0;
        attribute outputDataRate : DataRate = 1.0;

        port power : PowerPort;
        port commands : CommandPort;
        port sample : SamplePort;
        port result : MeasurementPort;
        port diagnostics : DiagnosticPort;

        part laser : LaserSource;
        part splitter : BeamSplitter;
        part referenceArm : ReferenceArm;
        part sampleCell : SampleCell;
        part holographicSensor : HolographicSensor;
        part thermalControl : TemperatureController;
        part processor : SignalProcessor;
        part controller : Controller;

        connect power to laser.power;
        connect power to thermalControl.power;
        connect commands to controller.commands;
        connect sample to sampleCell.sampleIn;

        connect laser.emittedBeam to splitter.inputBeam;
        connect splitter.referenceBeam to referenceArm.inputBeam;
        connect splitter.objectBeam to sampleCell.incidentBeam;
        connect referenceArm.outputBeam to holographicSensor.referenceBeam;
        connect sampleCell.modulatedBeam to holographicSensor.objectBeam;
        connect holographicSensor.hologramOut to processor.hologramIn;
        connect processor.measurementOut to result;
        connect processor.diagnosticOut to diagnostics;
        connect processor.diagnosticOut to controller.diagnostics;

        action performMeasurement {
            in item incomingSample : AnalyteSample;
            out item concentrationResult : ConcentrationMeasurement;
            out item diagnosticResult : DiagnosticReport;

            first stabilizeTemperature;
            then illuminateSample;
            then formHologram;
            then reconstructField;
            then computeMeasurement;
            then publishDiagnostics;
            then done;

            action stabilizeTemperature {
                in item incomingSample : AnalyteSample;
                out attribute stabilizedTemperature : Temperature;
            }

            action illuminateSample {
                out item reference : OpticalBeam;
                out item object : OpticalBeam;
            }

            action formHologram {
                in item reference : OpticalBeam;
                in item object : OpticalBeam;
                out item hologram : HologramFrame;
            }

            action reconstructField {
                in item hologram : HologramFrame;
                out item field : ReconstructedField;
            }

            action computeMeasurement {
                in item field : ReconstructedField;
                out item concentrationResult : ConcentrationMeasurement;
            }

            action publishDiagnostics {
                in item concentrationResult : ConcentrationMeasurement;
                out item diagnosticResult : DiagnosticReport;
            }
        }

        constraint measurementRangeConstraint {
            concentrationResult.value >= measurementRangeMin;
            concentrationResult.value <= measurementRangeMax;
        }

        constraint accuracyConstraint {
            concentrationResult.uncertainty <= requiredAccuracy;
        }

        constraint thermalOperatingConstraint {
            incomingSample.temperature >= operatingTemperatureMin;
            incomingSample.temperature <= operatingTemperatureMax;
        }

        constraint opticalContrastConstraint {
            holographicSensor.minimumContrast >= 0.18;
        }
    }

    requirement def MeasureRelevantQuantityRequirement {
        subject unit : HolographicSensingUnit;

        doc
        /*
         * The sensing unit shall measure the relevant quantity as target analyte
         * concentration by using a holographic sensor that records an interference
         * hologram between a reference beam and a sample-modulated object beam.
         */

        require constraint {
            unit.holographicSensor.pixelCountX >= 1024;
            unit.holographicSensor.pixelCountY >= 1024;
            unit.processor.minimumSnr >= 24.0;
            unit.requiredAccuracy <= 2.0;
        }
    }

    requirement def HolographicMeasurementRequirement {
        subject unit : HolographicSensingUnit;

        doc
        /*
         * The unit shall derive each measurement from reconstructed optical phase
         * shift produced by the interaction of the object beam with the sample.
         */

        require constraint {
            unit.processor.calibrationSlope > 0.0;
            unit.holographicSensor.exposureTime > 0.0;
            unit.sampleCell.opticalPathLength > 0.0;
        }
    }

    requirement def MeasurementRangeRequirement {
        subject unit : HolographicSensingUnit;

        doc
        /*
         * The unit shall report valid concentration measurements from 0 mg/L
         * through 1000 mg/L.
         */

        require constraint {
            unit.measurementRangeMin == 0.0;
            unit.measurementRangeMax == 1000.0;
        }
    }

    requirement def DiagnosticsRequirement {
        subject unit : HolographicSensingUnit;

        doc
        /*
         * The unit shall report diagnostic status for optical alignment, detector
         * health, thermal stability, contamination, and signal-to-noise ratio.
         */

        require constraint {
            unit.processor.minimumSnr >= 24.0;
        }
    }

    satisfy MeasureRelevantQuantityRequirement by HolographicSensingUnit;
    satisfy HolographicMeasurementRequirement by HolographicSensingUnit;
    satisfy MeasurementRangeRequirement by HolographicSensingUnit;
    satisfy DiagnosticsRequirement by HolographicSensingUnit;

    part holographicAnalyteSensingUnit : HolographicSensingUnit {
        attribute measurementRangeMin = 0.0;
        attribute measurementRangeMax = 1000.0;
        attribute requiredAccuracy = 2.0;
        attribute operatingTemperatureMin = 10.0;
        attribute operatingTemperatureMax = 45.0;
        attribute nominalSupplyVoltage = 12.0;
        attribute nominalSupplyCurrent = 500.0;
        attribute outputDataRate = 1.0;

        part laser {
            attribute nominalWavelength = 635.0;
            attribute outputPower = 5.0;
            attribute wavelengthTolerance = 0.5;
        }

        part splitter {
            attribute splitRatio = 0.5;
            attribute insertionLoss = 0.03;
        }

        part referenceArm {
            attribute pathLength = 42.0;
            attribute mirrorDisplacement = 0.0;
            attribute phaseBias = 0.0;
        }

        part sampleCell {
            attribute opticalPathLength = 10.0;
            attribute chamberVolume = 120.0;
            attribute maxPressure = 200000.0;
            attribute nominalTemperature = 25.0;
        }

        part holographicSensor {
            attribute sensorPitch = 2.2;
            attribute pixelCountX = 2048;
            attribute pixelCountY = 2048;
            attribute exposureTime = 10.0;
            attribute saturationThreshold = 8.0;
            attribute minimumContrast = 0.18;
        }

        part thermalControl {
            attribute setPoint = 25.0;
            attribute stability = 0.05;
        }

        part processor {
            attribute reconstructionSampleRate = 30.0;
            attribute minimumSnr = 24.0;
            attribute calibrationSlope = 0.0024;
            attribute calibrationOffset = 0.0;
        }
    }
}