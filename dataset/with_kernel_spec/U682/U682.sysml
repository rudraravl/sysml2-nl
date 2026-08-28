package ChlorideIonSensorSystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    attribute def ChlorideConcentration :> ISQ::MassDensityValue;
    attribute def FluorescenceIntensity :> ISQ::LuminousIntensityValue;
    attribute def Wavelength :> ISQ::LengthValue;
    attribute def Voltage :> ISQ::ElectricPotentialValue;
    attribute def VolumeFlowRate :> ISQ::VolumeFlowRateValue;

    attribute def StartSignal;
    attribute def ShutdownSignal;
    attribute def FaultCondition;
    attribute def ResetSignal;

    item def SampleFluid {
        attribute chlorideConcentration : ChlorideConcentration;
        attribute flowRate : VolumeFlowRate;
    }
    item def ExcitationLight {
        attribute wavelength : Wavelength = 365 [nm];
        attribute intensity : FluorescenceIntensity;
    }
    item def EmissionLight {
        attribute wavelength : Wavelength = 450 [nm];
        attribute intensity : FluorescenceIntensity;
    }
    item def AnalogSignal {
        attribute voltage : Voltage;
    }
    item def DigitalSignal {
        attribute counts : Integer;
    }
    item def ConcentrationReading {
        attribute value : ChlorideConcentration;
        attribute sampleID : Integer;
    }
    item def CalibrationEntry {
        attribute intensity : FluorescenceIntensity;
        attribute concentration : ChlorideConcentration;
    }
    item def CalibrationTable {
        attribute entries : CalibrationEntry[*];
    }
    item def ControlSignal {
        attribute pumpEnable : Boolean;
        attribute ledEnable : Boolean;
        attribute flowRateSetpoint : VolumeFlowRate;
    }
    item def SystemStatus {
        attribute fault : Boolean;
        attribute mode : Integer;
    }

    part def Pump {
        in item controlIn : ControlSignal;
        in item fluidIn : SampleFluid;
        out item fluidOut : SampleFluid;
    }
    part def QuartzFlowCell {
        in item sampleIn : SampleFluid;
        out item sampleOut : SampleFluid;
    }
    part def UVLED {
        in item controlIn : ControlSignal;
        out item excitationOut : ExcitationLight;
    }
    part def ExcitationFilter {
        in item lightIn : ExcitationLight;
        out item lightOut : ExcitationLight;
    }
    part def SensingChamber {
        in item sampleIn : SampleFluid;
        in item excitationIn : ExcitationLight;
        out item emissionOut : EmissionLight;
    }
    part def EmissionFilter {
        in item lightIn : EmissionLight;
        out item lightOut : EmissionLight;
    }
    part def Photodetector {
        in item lightIn : EmissionLight;
        out item signalOut : AnalogSignal;
    }
    part def SignalConditioner {
        in item rawSignal : AnalogSignal;
        out item digitalSignal : DigitalSignal;
    }
    part def Microprocessor {
        in item digitalIn : DigitalSignal;
        out item concentrationOut : ConcentrationReading;
        out item controlOut : ControlSignal;
        in ref item calibrationTable : CalibrationTable;
    }

    action def PumpSample {
        in item fluidIn : SampleFluid;
        out item fluidOut : SampleFluid;
        in attribute flowRate : VolumeFlowRate;
    }
    action def GenerateExcitation {
        out item excitationLight : ExcitationLight;
    }
    action def FilterExcitation {
        in item lightIn : ExcitationLight;
        out item lightOut : ExcitationLight;
    }
    action def QuenchFluorescence {
        in item sampleIn : SampleFluid;
        in item excitationIn : ExcitationLight;
        out item emissionOut : EmissionLight;
    }
    action def FilterEmission {
        in item lightIn : EmissionLight;
        out item lightOut : EmissionLight;
    }
    action def DetectEmission {
        in item lightIn : EmissionLight;
        out item signalOut : AnalogSignal;
    }
    action def ConditionSignal {
        in item rawSignal : AnalogSignal;
        out item digitalSignal : DigitalSignal;
    }
    action def CalculateConcentration {
        in item signalIn : DigitalSignal;
        in ref item calibrationTable : CalibrationTable;
        out item resultOut : ConcentrationReading;
    }
    action def PerformMeasurement {
        in item sampleInput : SampleFluid;
        out item concentrationOutput : ConcentrationReading;
        in ref item calibrationTable : CalibrationTable;
        in attribute flowRate : VolumeFlowRate;

        action pumpSample : PumpSample {
            in fluidIn = sampleInput;
            in flowRate = flowRate;
            out fluidOut : SampleFluid;
        }
        action generateUV : GenerateExcitation {
            out excitationLight : ExcitationLight;
        }
        flow generateUV.excitationLight to filterExcitation.lightIn;
        action filterExcitation : FilterExcitation {
            in lightIn : ExcitationLight;
            out lightOut : ExcitationLight;
        }
        flow filterExcitation.lightOut to quench.excitationIn;
        flow pumpSample.fluidOut to quench.sampleIn;
        action quench : QuenchFluorescence {
            in sampleIn : SampleFluid;
            in excitationIn : ExcitationLight;
            out emissionOut : EmissionLight;
        }
        flow quench.emissionOut to filterEmission.lightIn;
        action filterEmission : FilterEmission {
            in lightIn : EmissionLight;
            out lightOut : EmissionLight;
        }
        flow filterEmission.lightOut to detect.lightIn;
        action detect : DetectEmission {
            in lightIn : EmissionLight;
            out signalOut : AnalogSignal;
        }
        flow detect.signalOut to condition.rawSignal;
        action condition : ConditionSignal {
            in rawSignal : AnalogSignal;
            out digitalSignal : DigitalSignal;
        }
        flow condition.digitalSignal to calculate.signalIn;
        action calculate : CalculateConcentration {
            in signalIn : DigitalSignal;
            in calibrationTable = calibrationTable;
            out resultOut = concentrationOutput;
        }
    }
    action def WarmUpElectronics;
    action def Calibrate;
    action def ProcessData;
    action def FlushFlowCell;
    action def HandleFault;

    state def SensorLifecycle;

    part def ChlorideSensor {
        in item sampleInput : SampleFluid;
        out item concentrationOutput : ConcentrationReading;
        out item statusOut : SystemStatus;
        in ref item calibrationTable : CalibrationTable;
        in attribute flowRateSetpoint : VolumeFlowRate;
        in attribute startSignal : StartSignal;
        in attribute shutdownSignal : ShutdownSignal;
        in attribute faultCondition : FaultCondition;
        in attribute resetSignal : ResetSignal;

        part pump : Pump {
            in item controlIn : ControlSignal;
            in item fluidIn = sampleInput;
            out item fluidOut : SampleFluid;
        }
        part flowCell : QuartzFlowCell {
            in item sampleIn : SampleFluid;
            out item sampleOut : SampleFluid;
        }
        part uvLed : UVLED {
            in item controlIn : ControlSignal;
            out item excitationOut : ExcitationLight;
        }
        part excitationFilter : ExcitationFilter {
            in item lightIn : ExcitationLight;
            out item lightOut : ExcitationLight;
        }
        part sensingChamber : SensingChamber {
            in item sampleIn : SampleFluid;
            in item excitationIn : ExcitationLight;
            out item emissionOut : EmissionLight;
        }
        part emissionFilter : EmissionFilter {
            in item lightIn : EmissionLight;
            out item lightOut : EmissionLight;
        }
        part photodetector : Photodetector {
            in item lightIn : EmissionLight;
            out item signalOut : AnalogSignal;
        }
        part signalConditioner : SignalConditioner {
            in item rawSignal : AnalogSignal;
            out item digitalSignal : DigitalSignal;
        }
        part microprocessor : Microprocessor {
            in item digitalIn : DigitalSignal;
            out item concentrationOut = concentrationOutput;
            out item controlOut : ControlSignal;
            in ref item calibrationTable = calibrationTable;
        }

        flow pump.fluidOut to flowCell.sampleIn;
        flow flowCell.sampleOut to sensingChamber.sampleIn;
        flow uvLed.excitationOut to excitationFilter.lightIn;
        flow excitationFilter.lightOut to sensingChamber.excitationIn;
        flow sensingChamber.emissionOut to emissionFilter.lightIn;
        flow emissionFilter.lightOut to photodetector.lightIn;
        flow photodetector.signalOut to signalConditioner.rawSignal;
        flow signalConditioner.digitalSignal to microprocessor.digitalIn;
        flow microprocessor.concentrationOut to concentrationOutput;
        flow microprocessor.controlOut to pump.controlIn;
        flow microprocessor.controlOut to uvLed.controlIn;

        perform action warmUpElectronics : WarmUpElectronics;
        perform action calibrate : Calibrate;
        perform action measure : PerformMeasurement {
            in sampleInput = sampleInput;
            out concentrationOutput = concentrationOutput;
            in calibrationTable = calibrationTable;
            in flowRate = flowRateSetpoint;
        }
        perform action processData : ProcessData;
        perform action flushFlowCell : FlushFlowCell;
        perform action handleFault : HandleFault;

        exhibit state lifecycle : SensorLifecycle {
            entry action initial { }
            transition initial then off;
            state off;
            transition offToWarmUp first off accept StartSignal then warmUp;
            state warmUp {
                do action warmUpElectronics;
            }
            transition warmUpToCalibration first warmUp then calibration;
            state calibration {
                do action calibrate;
            }
            transition calibrationToMeasuring first calibration then measuring;
            state measuring {
                do action measure;
            }
            transition measuringToProcessing first measuring then processing;
            state processing {
                do action processData;
            }
            transition processingToFlushing first processing then flushing;
            state flushing {
                do action flushFlowCell;
            }
            transition flushingToMeasuring first flushing then measuring;
            transition warmUpToError first warmUp accept FaultCondition then error;
            transition calibrationToError first calibration accept FaultCondition then error;
            transition measuringToError first measuring accept FaultCondition then error;
            transition processingToError first processing accept FaultCondition then error;
            transition flushingToError first flushing accept FaultCondition then error;
            state error {
                do action handleFault;
            }
            transition errorToMeasuring first error accept ResetSignal then measuring;
            transition errorToOff first error accept ShutdownSignal then off;
        }
    }

    requirement def ContinuousMonitoring {
        doc /* The system shall continuously measure chloride ion concentration in the sample. */
        attribute minMeasurementInterval : ISQ::duration = 1 [s];
    }
    requirement def FluorescenceMeasurement {
        doc /* The system shall measure chloride concentration based on fluorescence quenching. */
    }
    requirement def CalibrationValidation {
        doc /* The system shall use a stored calibration table to calculate chloride concentration. */
    }
    requirement def FaultDetection {
        doc /* The system shall detect faults and enter an error state. */
    }
    requirement def FlushingCycle {
        doc /* The system shall flush the flow cell between measurements. */
    }

    requirement continuous : ContinuousMonitoring;
    requirement fluorescence : FluorescenceMeasurement;
    requirement calibration : CalibrationValidation;
    requirement faultDetection : FaultDetection;
    requirement flushingCycle : FlushingCycle;

    part sensorSystem : ChlorideSensor {
        satisfy continuous;
        satisfy fluorescence;
        satisfy calibration;
        satisfy faultDetection;
        satisfy flushingCycle;
    }
}
