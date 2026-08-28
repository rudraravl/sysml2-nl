package OpticalNanosensorSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    package Definitions {
        attribute def Concentration :> Real { unit "mol/L"; }
        attribute def LightIntensity :> Real { unit "W/m^2"; }
        attribute def Wavelength :> Real { unit "nm"; }
        attribute def Voltage :> Real { unit "V"; }
        attribute def CalibrationFactor :> Real;

        item def TargetMolecule {
            attribute name : String;
            attribute molecularWeight : Real;
        }
        item def BiologicalSample {
            attribute sampleId : String;
            item molecules : TargetMolecule[0..*];
        }

        attribute def StartSignal;
        attribute def StopSignal;
        attribute def CalibrateSignal;
        attribute def CalibrateAck;
        attribute def MeasurementResult {
            attribute concentration : Concentration;
            attribute timestamp : String;
        }

        port def SamplePort {
            in item sample : BiologicalSample;
        }
        port def ExcitationPort {
            out excitation : LightIntensity;
        }
        port def EmissionPort {
            out emission : LightIntensity;
        }
        port def RawSignalPort {
            out rawSignal : LightIntensity;
        }
        port def AmplifiedSignalPort {
            out amplifiedSignal : Voltage;
        }
        port def CommandPort {
            in start : StartSignal;
            in stop : StopSignal;
            in calibrate : CalibrateSignal;
            out ack : CalibrateAck;
            out result : MeasurementResult;
        }

        action def CaptureMolecules {
            in sample : BiologicalSample;
            out boundCount : Integer;
        }
        action def ExciteAndEmit {
            in excitationWavelength : Wavelength;
            out emissionIntensity : LightIntensity;
        }
        action def AmplifySignal {
            in raw : LightIntensity;
            out amplified : Voltage;
        }
        action def ProcessData {
            in signal : Voltage;
            in calibration : CalibrationFactor;
            out concentration : Concentration;
        }
        action def PerformCalibration {
            out factor : CalibrationFactor;
        }
        action def ReportResult {
            in concentration : Concentration;
            out result : MeasurementResult;
        }

        part def NanoparticleSurface {
            attribute functionalLayer : String := "Gold-Antibody";
            attribute excitationWavelength : Wavelength := 532;
            attribute emissionWavelength : Wavelength := 570;
            port samplePort : SamplePort;
            port excitationIn : ~ExcitationPort;
            port emissionOut : EmissionPort;
        }
        part def OpticalTransducer {
            port excitationOut : ExcitationPort;
            port emissionIn : ~EmissionPort;
            port signalOut : RawSignalPort;
        }
        part def SignalAmplifier {
            port signalIn : ~RawSignalPort;
            port signalOut : AmplifiedSignalPort;
            attribute gain : Real := 1000.0;
        }
        part def DataProcessor {
            port signalIn : ~AmplifiedSignalPort;
            port commandPort : CommandPort;
            attribute calibrationFactor : CalibrationFactor := 1.0;
        }
        part def OperatorInterface {
            port commandPort : ~CommandPort;
            attribute operatorId : String;
        }
        part def NanosensorSystem {
            port externalPort : CommandPort;
            port samplePort : SamplePort;
            part surface : NanoparticleSurface;
            part transducer : OpticalTransducer;
            part amplifier : SignalAmplifier;
            part processor : DataProcessor;
            part opInterface : OperatorInterface;
        }

        requirement def HighSensitivity {
            doc /* The system must detect target molecules at concentrations as low as 1 picomolar. */
            subject sensor : NanosensorSystem;
            attribute detectionLimit : Concentration := 1e-12;
            constraint { sensor.amplifier.gain >= 1000.0 }
        }
        requirement def FastResponseTime {
            doc /* The system must provide a concentration reading within 5 seconds of sample introduction. */
            subject sensor : NanosensorSystem;
            attribute maxResponseTime : Real := 5.0;
            constraint { sensor.amplifier.gain > 0 }
        }
        requirement def ContinuousOperation {
            doc /* The system must be capable of monitoring for extended periods without degradation. */
            subject sensor : NanosensorSystem;
            attribute minUptimeHours : Real := 72.0;
            constraint { sensor.surface.functionalLayer == "Gold-Antibody" }
        }
        requirement def SelectiveDetection {
            doc /* The functional layer must specifically capture target molecules with minimal cross-reactivity. */
            subject sensor : NanosensorSystem;
            attribute requiredSpecificity : Real := 1.0e9;
            constraint { sensor.surface.functionalLayer == "Gold-Antibody" }
        }
        requirement def AccurateQuantification {
            doc /* The data processor must apply calibration data to convert light intensity into precise concentration. */
            subject sensor : NanosensorSystem;
            attribute minConcentration : Concentration := 1e-9;
            constraint { sensor.processor.calibrationFactor > 0 }
        }
    }

    package Usages {
        private import Definitions::*;

        part nanosensor : NanosensorSystem {
            port externalPort = processor.commandPort;
            port samplePort = surface.samplePort;

            connect transducer.excitationOut to surface.excitationIn;
            connect surface.emissionOut to transducer.emissionIn;
            connect transducer.signalOut to amplifier.signalIn;
            connect amplifier.signalOut to processor.signalIn;
            connect opInterface.commandPort to processor.commandPort;

            action capture : CaptureMolecules {
                in sample = surface.samplePort.sample;
                out boundCount;
            }
            action excite : ExciteAndEmit {
                in excitationWavelength = surface.excitationWavelength;
                out emissionIntensity;
            }
            action amplify : AmplifySignal {
                in raw = transducer.signalOut.rawSignal;
                out amplified = amplifier.signalOut.amplifiedSignal;
            }
            action process : ProcessData {
                in signal = amplifier.signalOut.amplifiedSignal;
                in calibration = processor.calibrationFactor;
                out concentration;
            }
            action report : ReportResult {
                in concentration = process.concentration;
                out result = processor.commandPort.result;
            }
            action calibrate : PerformCalibration {
                out factor = processor.calibrationFactor;
            }

            state sensorStates {
                entry;
                then idle;

                state idle;

                transition idle_to_calibration
                    first idle
                    accept CalibrateSignal
                    then calibration;

                transition idle_to_active
                    first idle
                    accept StartSignal
                    then active;

                state calibration {
                    do calibrate;
                }
                then idle;

                state active {
                    entry;
                    then sensing;

                    state sensing {
                        do capture;
                        do excite;
                    }

                    state analyzing {
                        do amplify;
                        do process;
                        do report;
                    }

                    transition sensing_to_analyzing
                        first sensing
                        then analyzing;

                    transition analyzing_to_sensing
                        first analyzing
                        then sensing;

                    transition active_to_standby
                        first active
                        accept StopSignal
                        then standby;
                }

                state standby {
                    entry assign amplifier.gain := 0.0;
                    transition standby_to_active
                        first standby
                        accept StartSignal
                        then active;
                    transition standby_to_calibration
                        first standby
                        accept CalibrateSignal
                        then calibration;
                }

                transition standby_to_idle
                    first standby
                    accept StopSignal
                    then idle;
            }
        }

        satisfy HighSensitivity by nanosensor;
        satisfy FastResponseTime by nanosensor;
        satisfy ContinuousOperation by nanosensor;
        satisfy SelectiveDetection by nanosensor;
        satisfy AccurateQuantification by nanosensor;
    }
}
