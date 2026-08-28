package DopplerEchocardiographySystem {
    private import ScalarValues::*;

    package Definitions {
        attribute def FrequencyValue :> Real;
        attribute def VelocityValue :> Real;
        attribute def PressureGradientValue :> Real;
        attribute def TurbulenceValue :> Real;
        attribute def GainValue :> Real;
        attribute def AmplitudeValue :> Real;

        enum def ImagingMode {
            continuousWaveDoppler;
            pulsedWaveDoppler;
            colorDoppler;
            twoDimensional;
        }

        enum def FlowDirection {
            forward;
            reverse;
            turbulent;
        }

        item def UltrasoundWave {
            attribute frequency : FrequencyValue;
        }

        item def EchoSignal {
            attribute frequencyShift : FrequencyValue;
            attribute amplitude : AmplitudeValue;
        }

        item def BloodFlowData {
            attribute velocity : VelocityValue;
            attribute direction : FlowDirection;
            attribute turbulence : TurbulenceValue;
        }

        item def CardiacImage {
            attribute imageData : String;
            attribute colorOverlay : String;
        }

        item def HemodynamicMetrics {
            attribute pressureGradient : PressureGradientValue;
        }

        item def ControlCommand {
            attribute mode : ImagingMode;
            attribute gain : GainValue;
        }

        port def ControlInputPort {
            in item command : ControlCommand;
        }

        port def ControlOutputPort {
            out item command : ControlCommand;
        }

        port def UltrasoundTransmitPort {
            out item ultrasound : UltrasoundWave;
        }

        port def EchoReceivePort {
            in item echo : EchoSignal;
        }

        port def EchoOutputPort {
            out item echo : EchoSignal;
        }

        port def BloodFlowInputPort {
            in item bloodFlow : BloodFlowData;
        }

        port def BloodFlowOutputPort {
            out item bloodFlow : BloodFlowData;
        }

        port def CardiacImageOutputPort {
            out item image : CardiacImage;
        }

        port def HemodynamicOutputPort {
            out item metrics : HemodynamicMetrics;
        }

        port def DisplayInputPort {
            in item image : CardiacImage;
            in item metrics : HemodynamicMetrics;
        }

        port def PatientBodyPort {
            in item ultrasound : UltrasoundWave;
            out item echo : EchoSignal;
        }

        action def calculatePressureGradient {
            in velocity : VelocityValue;
            out pressureGradient : PressureGradientValue;
        }

        part def UltrasoundTransducer {
            port controlInputPort : ControlInputPort;
            port transmitPort : UltrasoundTransmitPort;
            port echoReceivePort : EchoReceivePort;
            port echoOutputPort : EchoOutputPort;

            perform action transmitAndReceive {
                in item command : ControlCommand;
                out item ultrasound : UltrasoundWave;
                in item echo : EchoSignal;
                out item echoOut : EchoSignal;
            }

            flow cmdToAction of ControlCommand
                from controlInputPort.command to transmitAndReceive.command;
            flow waveToPort of UltrasoundWave
                from transmitAndReceive.ultrasound to transmitPort.ultrasound;
            flow echoToAction of EchoSignal
                from echoReceivePort.echo to transmitAndReceive.echo;
            flow echoToPort of EchoSignal
                from transmitAndReceive.echoOut to echoOutputPort.echo;
        }

        part def DopplerProcessor {
            port echoInputPort : EchoReceivePort;
            port bloodFlowOutputPort : BloodFlowOutputPort;
            port controlInputPort : ControlInputPort;

            perform action processDoppler {
                in item echo : EchoSignal;
                in item command : ControlCommand;
                out item bloodFlow : BloodFlowData;
            }

            flow echoToProc of EchoSignal
                from echoInputPort.echo to processDoppler.echo;
            flow cmdToProc of ControlCommand
                from controlInputPort.command to processDoppler.command;
            flow flowToPort of BloodFlowData
                from processDoppler.bloodFlow to bloodFlowOutputPort.bloodFlow;
        }

        part def ImageProcessor {
            port echoInputPort : EchoReceivePort;
            port bloodFlowInputPort : BloodFlowInputPort;
            port imageOutputPort : CardiacImageOutputPort;
            port controlInputPort : ControlInputPort;

            perform action processImage {
                in item echo : EchoSignal;
                in item bloodFlow : BloodFlowData;
                in item command : ControlCommand;
                out item image : CardiacImage;
            }

            flow echoToImg of EchoSignal
                from echoInputPort.echo to processImage.echo;
            flow flowToImg of BloodFlowData
                from bloodFlowInputPort.bloodFlow to processImage.bloodFlow;
            flow cmdToImg of ControlCommand
                from controlInputPort.command to processImage.command;
            flow imgToPort of CardiacImage
                from processImage.image to imageOutputPort.image;
        }

        part def MeasurementEngine {
            port bloodFlowInputPort : BloodFlowInputPort;
            port metricsOutputPort : HemodynamicOutputPort;
            port controlInputPort : ControlInputPort;

            perform action measureHemodynamics {
                in item bloodFlow : BloodFlowData;
                in item command : ControlCommand;
                out item metrics : HemodynamicMetrics;
            }

            flow flowToMeas of BloodFlowData
                from bloodFlowInputPort.bloodFlow to measureHemodynamics.bloodFlow;
            flow cmdToMeas of ControlCommand
                from controlInputPort.command to measureHemodynamics.command;
            flow metricsToPort of HemodynamicMetrics
                from measureHemodynamics.metrics to metricsOutputPort.metrics;
        }

        part def DisplaySystem {
            port displayInputPort : DisplayInputPort;

            perform action display {
                in item image : CardiacImage;
                in item metrics : HemodynamicMetrics;
            }

            flow imgToDisplay of CardiacImage
                from displayInputPort.image to display.image;
            flow metricsToDisplay of HemodynamicMetrics
                from displayInputPort.metrics to display.metrics;
        }

        part def ControlSystem {
            attribute currentMode : ImagingMode;

            port clinicianCommandPort : ControlInputPort;
            port transducerControlPort : ControlOutputPort;
            port dopplerControlPort : ControlOutputPort;
            port imageControlPort : ControlOutputPort;
            port measurementControlPort : ControlOutputPort;

            perform action generateCommands {
                in item clinicianCommand : ControlCommand;
                out item transducerCommand : ControlCommand;
                out item dopplerCommand : ControlCommand;
                out item imageCommand : ControlCommand;
                out item measurementCommand : ControlCommand;
            }

            flow clinicianCmdToAction of ControlCommand
                from clinicianCommandPort.command to generateCommands.clinicianCommand;
            flow cmdToTransducerPort of ControlCommand
                from generateCommands.transducerCommand to transducerControlPort.command;
            flow cmdToDopplerPort of ControlCommand
                from generateCommands.dopplerCommand to dopplerControlPort.command;
            flow cmdToImagePort of ControlCommand
                from generateCommands.imageCommand to imageControlPort.command;
            flow cmdToMeasurementPort of ControlCommand
                from generateCommands.measurementCommand to measurementControlPort.command;

            state machine ControlStateMachine {
                state idle { initial; }
                state imaging;
                state dopplerMode;
                state measurement;
                state complete;

                transition t1 from idle to imaging when currentMode == ImagingMode::twoDimensional;
                transition t2 from imaging to dopplerMode when currentMode == ImagingMode::continuousWaveDoppler;
                transition t3 from dopplerMode to measurement when currentMode == ImagingMode::colorDoppler;
                transition t4 from measurement to complete;
                transition t5 from complete to idle;
            }
        }

        part def Clinician {
            port commandPort : ControlOutputPort;
        }

        part def Patient {
            port bodyPort : PatientBodyPort;
        }

        part def DopplerEchocardiographyMachine {
            part transducer : UltrasoundTransducer;
            part dopplerProcessor : DopplerProcessor;
            part imageProcessor : ImageProcessor;
            part measurementEngine : MeasurementEngine;
            part displaySystem : DisplaySystem;
            part controlSystem : ControlSystem;

            interface transducerToDoppler connect transducer.echoOutputPort to dopplerProcessor.echoInputPort {
                flow echoToDoppler of EchoSignal
                    from transducer.echoOutputPort.echo to dopplerProcessor.echoInputPort.echo;
            }

            interface transducerToImage connect transducer.echoOutputPort to imageProcessor.echoInputPort {
                flow echoToImage of EchoSignal
                    from transducer.echoOutputPort.echo to imageProcessor.echoInputPort.echo;
            }

            interface dopplerToImage connect dopplerProcessor.bloodFlowOutputPort to imageProcessor.bloodFlowInputPort {
                flow flowToImage of BloodFlowData
                    from dopplerProcessor.bloodFlowOutputPort.bloodFlow
                    to imageProcessor.bloodFlowInputPort.bloodFlow;
            }

            interface dopplerToMeasurement connect dopplerProcessor.bloodFlowOutputPort to measurementEngine.bloodFlowInputPort {
                flow flowToMeas of BloodFlowData
                    from dopplerProcessor.bloodFlowOutputPort.bloodFlow
                    to measurementEngine.bloodFlowInputPort.bloodFlow;
            }

            interface imageToDisplay connect imageProcessor.imageOutputPort to displaySystem.displayInputPort {
                flow imgToDisplay of CardiacImage
                    from imageProcessor.imageOutputPort.image
                    to displaySystem.displayInputPort.image;
            }

            interface measurementToDisplay connect measurementEngine.metricsOutputPort to displaySystem.displayInputPort {
                flow metricsToDisplay of HemodynamicMetrics
                    from measurementEngine.metricsOutputPort.metrics
                    to displaySystem.displayInputPort.metrics;
            }

            interface controlToTransducer connect controlSystem.transducerControlPort to transducer.controlInputPort {
                flow cmdToTransducer of ControlCommand
                    from controlSystem.transducerControlPort.command
                    to transducer.controlInputPort.command;
            }

            interface controlToDoppler connect controlSystem.dopplerControlPort to dopplerProcessor.controlInputPort {
                flow cmdToDoppler of ControlCommand
                    from controlSystem.dopplerControlPort.command
                    to dopplerProcessor.controlInputPort.command;
            }

            interface controlToImage connect controlSystem.imageControlPort to imageProcessor.controlInputPort {
                flow cmdToImage of ControlCommand
                    from controlSystem.imageControlPort.command
                    to imageProcessor.controlInputPort.command;
            }

            interface controlToMeasurement connect controlSystem.measurementControlPort to measurementEngine.controlInputPort {
                flow cmdToMeas of ControlCommand
                    from controlSystem.measurementControlPort.command
                    to measurementEngine.controlInputPort.command;
            }
        }

        requirement def RealTimeImaging {
            subject machine : DopplerEchocardiographyMachine;
            doc "The system shall produce real-time two-dimensional images of the heart's anatomy.";
        }

        requirement def BloodFlowMeasurement {
            subject machine : DopplerEchocardiographyMachine;
            doc "The system shall measure velocity, direction, and turbulence of blood flow using Doppler frequency shift.";
        }

        requirement def PressureGradientCalculation {
            subject machine : DopplerEchocardiographyMachine;
            doc "The Measurement Engine shall calculate pressure gradient across heart valves from blood flow data.";
        }

        requirement def ModeSelection {
            subject machine : DopplerEchocardiographyMachine;
            doc "The Control System shall allow the operator to select imaging modes, including Continuous Wave Doppler.";
        }
    }

    package Usages {
        public import Definitions::*;

        part clinician : Clinician;
        part patient : Patient;
        part machine : DopplerEchocardiographyMachine;

        interface clinicianToMachine connect clinician.commandPort to machine.controlSystem.clinicianCommandPort {
            flow clinicianCmd of ControlCommand
                from clinician.commandPort.command
                to machine.controlSystem.clinicianCommandPort.command;
        }

        interface machineToPatient connect machine.transducer.transmitPort to patient.bodyPort {
            flow ultrasoundToPatient of UltrasoundWave
                from machine.transducer.transmitPort.ultrasound
                to patient.bodyPort.ultrasound;
        }

        interface patientToMachine connect patient.bodyPort to machine.transducer.echoReceivePort {
            flow echoFromPatient of EchoSignal
                from patient.bodyPort.echo
                to machine.transducer.echoReceivePort.echo;
        }

        requirement realTimeImagingReq : RealTimeImaging {
            subject :>> machine;
        }

        requirement bloodFlowMeasurementReq : BloodFlowMeasurement {
            subject :>> machine;
        }

        requirement pressureGradientCalcReq : PressureGradientCalculation {
            subject :>> machine;
        }

        requirement modeSelectionReq : ModeSelection {
            subject :>> machine;
        }
    }
}
