package PositionSensitiveDeviceSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;
    import USCustomaryUnits::*;

    attribute def Length2D {
        attribute x : LengthValue;
        attribute y : LengthValue;
    }

    attribute def Position2D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute coordinateFrame : String;
    }

    attribute def OpticalPowerValue :> Real;
    attribute def IrradianceValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def TimeValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def ResolutionValue :> Real;
    attribute def ErrorValue :> Real;

    enum def MeasurementStatus {
        enum idle;
        enum acquiring;
        enum valid;
        enum saturated;
        enum lowSignal;
        enum fault;
    }

    item def IncidentLight {
        attribute wavelength : LengthValue;
        attribute opticalPower : OpticalPowerValue;
        attribute spotDiameter : LengthValue;
        attribute centroid : Position2D;
        attribute modulationFrequency : FrequencyValue;
    }

    item def PhotocurrentSignal {
        attribute current : CurrentValue;
        attribute noiseCurrentRms : CurrentValue;
        attribute channelId : String;
    }

    item def AnalogVoltageSignal {
        attribute voltage : VoltageValue;
        attribute noiseVoltageRms : VoltageValue;
        attribute channelId : String;
    }

    item def DigitalSample {
        attribute rawCode : Integer;
        attribute voltageEquivalent : VoltageValue;
        attribute sampleTime : TimeValue;
        attribute channelId : String;
    }

    item def PositionEstimate {
        attribute position : Position2D;
        attribute status : MeasurementStatus;
        attribute confidence : Real;
        attribute totalOpticalPower : OpticalPowerValue;
        attribute updateTime : TimeValue;
        attribute errorEstimate : ErrorValue;
    }

    item def ConfigurationCommand {
        attribute integrationTime : TimeValue;
        attribute gainSetting : Real;
        attribute sampleRate : FrequencyValue;
        attribute zeroOffset : Position2D;
        attribute enableAutoRange : Boolean;
    }

    item def DiagnosticReport {
        attribute status : MeasurementStatus;
        attribute detectorTemperature : TemperatureValue;
        attribute saturationDetected : Boolean;
        attribute signalToNoiseRatio : Real;
        attribute faultCode : String;
    }

    port def OpticalInputPort {
        in item light : IncidentLight;
    }

    port def PhotocurrentPort {
        out item currentSignal : PhotocurrentSignal;
    }

    port def AnalogSignalPort {
        in item inputVoltage : AnalogVoltageSignal;
        out item outputVoltage : AnalogVoltageSignal;
    }

    port def DigitalSamplePort {
        out item sample : DigitalSample;
    }

    port def PositionOutputPort {
        out item estimate : PositionEstimate;
    }

    port def CommandPort {
        in item command : ConfigurationCommand;
    }

    port def DiagnosticPort {
        out item report : DiagnosticReport;
    }

    part def PositionSensitiveDeviceSystem {
        attribute activeArea : Length2D = (x = 10 [mm], y = 10 [mm]);
        attribute nominalWavelength : LengthValue = 850 [nm];
        attribute measurementRangeX : LengthValue = 5 [mm];
        attribute measurementRangeY : LengthValue = 5 [mm];
        attribute positionResolution : ResolutionValue = 1.0;
        attribute maximumUpdateRate : FrequencyValue = 10000 [Hz];
        attribute operatingTemperatureMin : TemperatureValue = -20.0;
        attribute operatingTemperatureMax : TemperatureValue = 70.0;

        port opticalInput : OpticalInputPort;
        port configuration : CommandPort;
        port measuredPosition : PositionOutputPort;
        port diagnostics : DiagnosticPort;

        part detector : PhotodiodeArray {
            attribute activeArea = system.activeArea;
            attribute responsivity = 0.55;
        }

        part transimpedanceAmplifier : AnalogFrontEnd {
            attribute nominalGain = 100000.0;
            attribute bandwidth = 100000 [Hz];
        }

        part analogToDigitalConverter : SamplingConverter {
            attribute resolutionBits = 16;
            attribute sampleRate = 50000 [Hz];
        }

        part processor : PositionProcessor {
            attribute updateRate = 10000 [Hz];
            attribute coordinateFrameName = "PSD_LOCAL_XY";
        }

        part controller : DeviceController {
            attribute defaultIntegrationTime = 100 [us];
            attribute autoRangeEnabled = true;
        }

        part thermalMonitor : TemperatureMonitor {
            attribute highTemperatureLimit = 70.0;
            attribute lowTemperatureLimit = -20.0;
        }

        connection opticalPath connect opticalInput.light to detector.incidentLight.light;
        connection xPositiveCurrent connect detector.xPositiveCurrent.currentSignal to transimpedanceAmplifier.xPositiveInput.currentSignal;
        connection xNegativeCurrent connect detector.xNegativeCurrent.currentSignal to transimpedanceAmplifier.xNegativeInput.currentSignal;
        connection yPositiveCurrent connect detector.yPositiveCurrent.currentSignal to transimpedanceAmplifier.yPositiveInput.currentSignal;
        connection yNegativeCurrent connect detector.yNegativeCurrent.currentSignal to transimpedanceAmplifier.yNegativeInput.currentSignal;

        connection analogXPositive connect transimpedanceAmplifier.xPositiveVoltage.outputVoltage to analogToDigitalConverter.xPositiveInput.inputVoltage;
        connection analogXNegative connect transimpedanceAmplifier.xNegativeVoltage.outputVoltage to analogToDigitalConverter.xNegativeInput.inputVoltage;
        connection analogYPositive connect transimpedanceAmplifier.yPositiveVoltage.outputVoltage to analogToDigitalConverter.yPositiveInput.inputVoltage;
        connection analogYNegative connect transimpedanceAmplifier.yNegativeVoltage.outputVoltage to analogToDigitalConverter.yNegativeInput.inputVoltage;

        connection sampleXPositive connect analogToDigitalConverter.xPositiveSample.sample to processor.xPositiveSample.sample;
        connection sampleXNegative connect analogToDigitalConverter.xNegativeSample.sample to processor.xNegativeSample.sample;
        connection sampleYPositive connect analogToDigitalConverter.yPositiveSample.sample to processor.yPositiveSample.sample;
        connection sampleYNegative connect analogToDigitalConverter.yNegativeSample.sample to processor.yNegativeSample.sample;

        connection positionOutput connect processor.positionOut.estimate to measuredPosition.estimate;
        connection commandInput connect configuration.command to controller.commandIn.command;
        connection controllerToProcessor connect controller.processorCommand.command to processor.configuration.command;
        connection controllerToAnalogFrontEnd connect controller.afeCommand.command to transimpedanceAmplifier.configuration.command;
        connection controllerToAdc connect controller.adcCommand.command to analogToDigitalConverter.configuration.command;
        connection temperatureDiagnostic connect thermalMonitor.diagnosticOut.report to controller.temperatureDiagnostic.report;
        connection systemDiagnostic connect controller.diagnosticOut.report to diagnostics.report;

        perform action acquireAndReportPosition;
        exhibit state systemOperatingState;
    }

    part def PhotodiodeArray {
        attribute activeArea : Length2D;
        attribute responsivity : Real;
        attribute darkCurrent : CurrentValue = 2.0e-9;
        attribute saturationCurrent : CurrentValue = 1.0e-3;

        port incidentLight : OpticalInputPort;
        port xPositiveCurrent : PhotocurrentPort;
        port xNegativeCurrent : PhotocurrentPort;
        port yPositiveCurrent : PhotocurrentPort;
        port yNegativeCurrent : PhotocurrentPort;

        action convertSpotToElectrodeCurrents {
            in item light : IncidentLight;
            out item ixp : PhotocurrentSignal;
            out item ixn : PhotocurrentSignal;
            out item iyp : PhotocurrentSignal;
            out item iyn : PhotocurrentSignal;

            constraint opticalToCurrent {
                ixp.current + ixn.current + iyp.current + iyn.current > 0.0;
            }
        }
    }

    part def AnalogFrontEnd {
        attribute nominalGain : Real;
        attribute bandwidth : FrequencyValue;
        attribute inputReferredNoise : CurrentValue = 5.0e-12;

        port xPositiveInput : PhotocurrentPort;
        port xNegativeInput : PhotocurrentPort;
        port yPositiveInput : PhotocurrentPort;
        port yNegativeInput : PhotocurrentPort;

        port xPositiveVoltage : AnalogSignalPort;
        port xNegativeVoltage : AnalogSignalPort;
        port yPositiveVoltage : AnalogSignalPort;
        port yNegativeVoltage : AnalogSignalPort;

        port configuration : CommandPort;

        action amplifyPhotocurrents {
            in item xp : PhotocurrentSignal;
            in item xn : PhotocurrentSignal;
            in item yp : PhotocurrentSignal;
            in item yn : PhotocurrentSignal;
            out item vxp : AnalogVoltageSignal;
            out item vxn : AnalogVoltageSignal;
            out item vyp : AnalogVoltageSignal;
            out item vyn : AnalogVoltageSignal;
        }
    }

    part def SamplingConverter {
        attribute resolutionBits : Integer;
        attribute sampleRate : FrequencyValue;
        attribute referenceVoltage : VoltageValue = 3.3 [V];

        port xPositiveInput : AnalogSignalPort;
        port xNegativeInput : AnalogSignalPort;
        port yPositiveInput : AnalogSignalPort;
        port yNegativeInput : AnalogSignalPort;

        port xPositiveSample : DigitalSamplePort;
        port xNegativeSample : DigitalSamplePort;
        port yPositiveSample : DigitalSamplePort;
        port yNegativeSample : DigitalSamplePort;

        port configuration : CommandPort;

        action sampleAnalogChannels {
            in item vxp : AnalogVoltageSignal;
            in item vxn : AnalogVoltageSignal;
            in item vyp : AnalogVoltageSignal;
            in item vyn : AnalogVoltageSignal;
            out item sxp : DigitalSample;
            out item sxn : DigitalSample;
            out item syp : DigitalSample;
            out item syn : DigitalSample;
        }
    }

    part def PositionProcessor {
        attribute updateRate : FrequencyValue;
        attribute coordinateFrameName : String;
        attribute minimumSignalVoltage : VoltageValue = 0.01 [V];
        attribute saturationVoltage : VoltageValue = 3.2 [V];

        port xPositiveSample : DigitalSamplePort;
        port xNegativeSample : DigitalSamplePort;
        port yPositiveSample : DigitalSamplePort;
        port yNegativeSample : DigitalSamplePort;
        port configuration : CommandPort;
        port positionOut : PositionOutputPort;

        action computeCentroid {
            in item sxp : DigitalSample;
            in item sxn : DigitalSample;
            in item syp : DigitalSample;
            in item syn : DigitalSample;
            out item position : PositionEstimate;

            constraint normalizedPositionEquation {
                position.position.x == ((sxp.voltageEquivalent - sxn.voltageEquivalent) /
                    (sxp.voltageEquivalent + sxn.voltageEquivalent)) * 5 [mm];
                position.position.y == ((syp.voltageEquivalent - syn.voltageEquivalent) /
                    (syp.voltageEquivalent + syn.voltageEquivalent)) * 5 [mm];
            }
        }

        action classifyMeasurementStatus {
            in item position : PositionEstimate;
            out item classifiedPosition : PositionEstimate;
        }
    }

    part def DeviceController {
        attribute defaultIntegrationTime : TimeValue;
        attribute autoRangeEnabled : Boolean;

        port commandIn : CommandPort;
        port processorCommand : CommandPort;
        port afeCommand : CommandPort;
        port adcCommand : CommandPort;
        port temperatureDiagnostic : DiagnosticPort;
        port diagnosticOut : DiagnosticPort;

        action applyConfiguration {
            in item command : ConfigurationCommand;
            out item processorConfiguration : ConfigurationCommand;
            out item afeConfiguration : ConfigurationCommand;
            out item adcConfiguration : ConfigurationCommand;
        }

        action publishDiagnostics {
            in item temperatureReport : DiagnosticReport;
            out item systemReport : DiagnosticReport;
        }
    }

    part def TemperatureMonitor {
        attribute detectorTemperature : TemperatureValue;
        attribute highTemperatureLimit : TemperatureValue;
        attribute lowTemperatureLimit : TemperatureValue;

        port diagnosticOut : DiagnosticPort;

        action monitorTemperature {
            out item report : DiagnosticReport;
        }
    }

    action def AcquireAndReportPosition {
        in item incidentLight : IncidentLight;
        in item configurationCommand : ConfigurationCommand;
        out item reportedPosition : PositionEstimate;
        out item diagnosticReport : DiagnosticReport;

        first start;
        then applyConfiguration;
        then convertOpticalSpot;
        then amplifySignals;
        then sampleSignals;
        then computePosition;
        then validatePosition;
        then reportResult;
        then done;

        action applyConfiguration;
        action convertOpticalSpot;
        action amplifySignals;
        action sampleSignals;
        action computePosition;
        action validatePosition;
        action reportResult;
    }

    state def SystemOperatingState {
        entry action initialize;

        state poweredOff;
        state initializing;
        state standby;
        state measuring;
        state reporting;
        state faulted;

        transition initialToOff first poweredOff;
        transition powerApplied from poweredOff to initializing;
        transition initializationComplete from initializing to standby;
        transition commandReceived from standby to measuring;
        transition sampleComplete from measuring to reporting;
        transition reportPublished from reporting to measuring;
        transition stopCommand from measuring to standby;
        transition detectedFault from standby to faulted;
        transition measurementFault from measuring to faulted;
        transition resetFault from faulted to initializing;

        action initialize;
    }

    requirement def PrimaryFunctionRequirement {
        subject psdSystem : PositionSensitiveDeviceSystem;
        require constraint {
            psdSystem.measuredPosition.estimate.position.coordinateFrame == "PSD_LOCAL_XY";
        }
        doc /* The system shall convert the centroid of an incident optical spot on a position sensitive detector into a calibrated two-dimensional position estimate. */
    }

    requirement def MeasurementRangeRequirement {
        subject psdSystem : PositionSensitiveDeviceSystem;
        require constraint {
            psdSystem.measurementRangeX >= 5 [mm] and psdSystem.measurementRangeY >= 5 [mm];
        }
        doc /* The system shall measure optical spot displacement over at least plus or minus 5 mm in both local X and local Y axes. */
    }

    requirement def UpdateRateRequirement {
        subject psdSystem : PositionSensitiveDeviceSystem;
        require constraint {
            psdSystem.maximumUpdateRate >= 10000 [Hz];
        }
        doc /* The system shall provide position estimates at a maximum update rate of at least 10 kHz. */
    }

    requirement def ResolutionRequirement {
        subject psdSystem : PositionSensitiveDeviceSystem;
        require constraint {
            psdSystem.positionResolution <= 1.0;
        }
        doc /* The system shall resolve spot position changes of 1 micrometer or smaller under nominal optical power and wavelength conditions. */
    }

    requirement def SaturationDetectionRequirement {
        subject processor : PositionProcessor;
        require constraint {
            processor.saturationVoltage <= 3.2 [V];
        }
        doc /* The position processor shall classify measurements as saturated when any sampled channel approaches the converter full-scale limit. */
    }

    requirement def LowSignalDetectionRequirement {
        subject processor : PositionProcessor;
        require constraint {
            processor.minimumSignalVoltage >= 0.01 [V];
        }
        doc /* The position processor shall classify measurements as lowSignal when summed channel voltage is insufficient for a reliable centroid estimate. */
    }

    requirement def DiagnosticsRequirement {
        subject psdSystem : PositionSensitiveDeviceSystem;
        require constraint {
            psdSystem.operatingTemperatureMin <= psdSystem.thermalMonitor.detectorTemperature and
            psdSystem.thermalMonitor.detectorTemperature <= psdSystem.operatingTemperatureMax;
        }
        doc /* The system shall publish diagnostic status including measurement validity, saturation indication, signal-to-noise ratio, and detector temperature. */
    }

    satisfy PrimaryFunctionRequirement by PositionSensitiveDeviceSystem;
    satisfy MeasurementRangeRequirement by PositionSensitiveDeviceSystem;
    satisfy UpdateRateRequirement by PositionSensitiveDeviceSystem;
    satisfy ResolutionRequirement by PositionSensitiveDeviceSystem;
    satisfy SaturationDetectionRequirement by PositionProcessor;
    satisfy LowSignalDetectionRequirement by PositionProcessor;
    satisfy DiagnosticsRequirement by PositionSensitiveDeviceSystem;

    part system : PositionSensitiveDeviceSystem;

    action acquireAndReportPosition : AcquireAndReportPosition;
    state systemOperatingState : SystemOperatingState;
}