package AN_APG77_Radar {

    package ValueTypes {
        value type Frequency :> Real { unit 'Hz'; }
        value type Power :> Real { unit 'W'; }
        value type TimeDelay :> Real { unit 's'; }
        value type Distance :> Real {> Real { unit 'm'; }
        value type Velocity :> Real { unit 'm/s'; }
        value type Angle :> Real { unit 'rad'; }
        value type SignalToNoiseRatio :> Real { unit 'dB'; }
        value type Gain :> Real { unit 'dB'; }
        value type PulseWidth :> Real { unit 's'; }
        value type PulseRepetitionInterval :> Real { unit 's'; }
        value type DopplerShift :> Real { unit 'Hz'; }
        value type Amplitude :> Real { unit 'V'; }
    }

    package Items {
        item def RFPulse {
            attribute carrierFrequency : Frequency;
            attribute peakPower : Power;
            attribute pulseWidth : PulseWidth;
            attribute pri : PulseRepetitionInterval;
        }

        item def EchoSignal {
            attribute amplitude : Amplitude;
            attribute frequency : Frequency;
            attribute timeOfArrival : TimeDelay;
            attribute dopplerShift : DopplerShift;
            attribute azimuth : Angle;
            attribute elevation : Angle;
        }

        item def TargetReport {
            attribute range : Distance;
            attribute velocity : Velocity;
            attribute azimuth : Angle;
            attribute elevation : Angle;
            attribute snr : SignalToNoiseRatio;
            attribute trackId : String;
        }

        item def ModeCommand {
            attribute requestedMode : String;
            attribute priority : Integer;
        }

        item def BeamSteeringDirective {
            attribute azimuth : Angle;
            attribute elevation : Angle;
            attribute beamWidth : Angle;
        }
    }

    package Interfaces {
        port def RFPulseOut {
            out pulse : Items::RFPulse;
        }

        port def RFPulseIn {
            in pulse : Items::RFPulse;
        }

        port def EchoOut {
            out echo : Items::EchoSignal;
        }

        port def EchoIn {
            in echo : Items::EchoSignal;
        }

        port def TargetReportOut {
            out report : Items::TargetReport;
        }

        port def ModeCommandIn {
            in command : Items::ModeCommand;
        }

        port def SteeringDirectiveOut {
            out directive : Items::BeamSteeringDirective;
        }

        port def SteeringDirectiveIn {
            in directive : Items::BeamSteeringDirective;
        }

        port def DigitalDataOut {
            out data : Items::TargetReport;
        }

        port def DigitalDataIn {
            in data : Items::TargetReport;
        }

        interface RFTransmission
            from transmitterPulseOut : RFPulseOut
            to antennaPulseIn : RFPulseIn {
            flow pulse : Items::RFPulse;
        }

        interface EchoReception
            from antennaEchoOut : EchoOut
            to receiverEchoIn : EchoIn {
            flow echo : Items::EchoSignal;
        }

        interface SteeringControl
            from controllerSteeringOut : SteeringDirectiveOut
            to antennaSteeringIn : SteeringDirectiveIn {
            flow directive : Items::BeamSteeringDirective;
        }

        interface ModeControlFlow
            from externalCommandPort : ModeCommandIn
            to controllerCommandPort : ModeCommandIn {
            flow command : Items::ModeCommand;
        }

        interface ReportOutput
            from processorReportOut : TargetReportOut
            to externalDataIn : DigitalDataIn {
            flow report : Items::TargetReport;
        }
    }

    package Components {

        part def Transmitter {
            attribute operatingFrequency : Frequency = 10e9 [Hz];
            attribute peakPower : Power = 20000 [W];
            attribute pulseWidth : PulseWidth = 1e-6 [s];
            attribute pri : PulseRepetitionInterval = 1e-3 [s];

            port pulseOut : Interfaces::RFPulseOut;
            port commandIn : Interfaces::ModeCommandIn;

            attribute isActive : Boolean = false;

            action def GeneratePulse {
                in freq : Frequency;
                in power : Power;
                in width : PulseWidth;
                in interval : PulseRepetitionInterval;
                out pulse : Items::RFPulse;
            }

            perform action generatePulse : GeneratePulse {
                in freq = operatingFrequency;
                in power = peakPower;
                in width = pulseWidth;
                in interval = pri;
                out pulse = pulseOut.pulse;
            }
        }

        part def Antenna {
            attribute apertureGain : Gain = 35 [dB];
            attribute steeringAzimuth : Angle = 0 [rad];
            attribute steeringElevation : Angle = 0 [rad];
            attribute beamWidth : Angle = 0.05 [rad];

            port pulseIn : Interfaces::RFPulseIn;
            port echoOut : Interfaces::EchoOut;
            port steeringIn : Interfaces::SteeringDirectiveIn;

            action def Radiate {
                in pulse : Items::RFPulse;
                in directive : Items::BeamSteeringDirective;
            }

            action def Collect {
                out echo : Items::EchoSignal;
            }

            perform action radiate : Radiate {
                in pulse = pulseIn.pulse;
                in directive = steeringIn.directive;
            }

            perform action collect : Collect {
                out echo = echoOut.echo;
            }
        }

        part def Receiver {
            attribute noiseFigure : Gain = 3 [dB];
            attribute bandwidth : Frequency = 10e6 [Hz];
            attribute gain : Gain = 80 [dB];

            port echoIn : Interfaces::EchoIn;
            port echoOut : Interfaces::EchoOut;

            action def Amplify {
                in echo : Items::EchoSignal;
                out amplified : Items::EchoSignal;
            }

            action def Filter {
                in echo : Items::EchoSignal;
                out filtered : Items::EchoSignal;
            }

            perform action amplify : Amplify {
                in echo = echoIn.echo;
                out amplified;
            }

            perform action filter : Filter {
                in echo = amplify.amplified;
                out filtered = echoOut.echo;
            }
        }

        part def SignalProcessor {
            port echoIn : Interfaces::EchoIn;
            port reportOut : Interfaces::TargetReportOut;

            attribute processingLatency : TimeDelay = 5e-6 [s];

            action def ComputeRange {
                in timeDelay : TimeDelay;
                out range : Distance;
            }

            action def ComputeVelocity {
                in doppler : DopplerShift;
                out velocity : Velocity;
            }

            action def ComputeDirection {
                in azimuth : Angle;
                in elevation : Angle;
                out az : Angle;
                out el : Angle;
            }

            action def ExtractTarget {
                in echo : Items::EchoSignal;
                out report : Items::TargetReport;
            }

            perform action extractTarget : ExtractTarget {
                in echo = echoIn.echo;
                out report = reportOut.report;
            }
        }

        part def ModeController {
            port commandIn : Interfaces::ModeCommandIn;
            port steeringOut : Interfaces::SteeringDirectiveOut;
            port transmitterEnableOut : Interfaces::ModeCommandIn;
            port processorEnableOut : Interfaces::ModeCommandIn;

            attribute currentMode : String = "Standby";

            state def OperationalMode {
                entry;
                then Standby;

                state Standby {
                    entry { currentMode = "Standby"; }
                    accept command : Items::ModeCommand
                    when command.requestedMode == "Search"
                    then Search;
                    accept command : Items::ModeCommand
                    when command.requestedMode == "Track"
                    then Track;
                }

                state Search {
                    entry { currentMode = "Search"; }
                    do { send Items::BeamSteeringDirective{azimuth=0.0[rad]; elevation=0.0[rad]; beamWidth=0.05[rad];} to steeringOut; }
                    accept command : Items::ModeCommand
                    when command.requestedMode == "Track"
                    then Track;
                    accept command : Items::ModeCommand
                    when command.requestedMode == "Standby"
                    then Standby;
                }

                state Track {
                    entry { currentMode = "Track"; }
                    do { send Items::BeamSteeringDirective{azimuth=0.1[rad]; elevation=0.05[rad]; beamWidth=0.02[rad];} to steeringOut; }
                    accept command : Items::ModeCommand
                    when command.requestedMode == "Search"
                    then Search;
                    accept command : Items::ModeCommand
                    when command.requestedMode == "Standby"
                    then Standby;
                }
            }

            exhibit state behavior : OperationalMode;
        }
    }

    package System {

        part def RadarSystem {
            port externalCommandPort : Interfaces::ModeCommandIn;
            port externalDataPort : Interfaces::DigitalDataIn;

            part transmitter : Components::Transmitter;
            part antenna : Components::Antenna;
            part receiver : Components::Receiver;
            part processor : Components::SignalProcessor;
            part controller : Components::ModeController;

            connection transmitterToAntenna : Interfaces::RFTransmission {
                end transmitterPulseOut ::> transmitter.pulseOut;
                end antennaPulseIn ::> antenna.pulseIn;
            }

            connection antennaToReceiver : Interfaces::EchoReception {
                end antennaEchoOut ::> antenna.echoOut;
                end receiverEchoIn ::> receiver.echoIn;
            }

            connection receiverToProcessor : Interfaces::EchoReception {
                end antennaEchoOut ::> receiver.echoOut;
                end receiverEchoIn ::> processor.echoIn;
            }

            connection controllerToAntenna : Interfaces::SteeringControl {
                end controllerSteeringOut ::> controller.steeringOut;
                end antennaSteeringIn ::> antenna.steeringIn;
            }

            connection externalToController : Interfaces::ModeControlFlow {
                end externalCommandPort ::> externalCommandPort;
                end controllerCommandPort ::> controller.commandIn;
            }

            connection processorToExternal : Interfaces::ReportOutput {
                end processorReportOut ::> processor.reportOut;
                end externalDataIn ::> externalDataPort;
            }
        }
    }

    package Requirements {

        requirement def RadarDetectionRequirement {
            doc /* The radar shall detect airborne and surface targets. */
            attribute minDetectionRange : Distance = 200000 [m];
            attribute maxDetectionRange : Distance = 300000 [m];
            subject radar : System::RadarSystem;
            require { radar.processor.reportOut.report.range >= minDetectionRange
                      and radar.processor.reportOut.report.range <= maxDetectionRange; }
        }

        requirement def VelocityMeasurementRequirement {
            doc /* The radar shall measure target velocity via Doppler shift. */
            attribute maxVelocity : Velocity = 2000 [m/s];
            subject radar : System::RadarSystem;
            require { abs(radar.processor.reportOut.report.velocity) <= maxVelocity; }
        }

        requirement def DirectionMeasurementRequirement {
            doc /* The radar shall determine target azimuth and elevation. */
            attribute azimuthCoverage : Angle = 3.14 [rad];
            attribute elevationCoverage : Angle = 1.57 [rad];
            subject radar : System::RadarSystem;
            require { abs(radar.processor.reportOut.report.azimuth) <= azimuthCoverage
                      and abs(radar.processor.reportOut.report.elevation) <= elevationCoverage; }
        }

        requirement def ModeControlRequirement {
            doc /* The radar shall support Standby, Search, and Track modes. */
            subject radar : System::RadarSystem;
            require { radar.controller.currentMode in {"Standby", "Search", "Track"}; }
        }

        requirement def BeamSteeringRequirement {
            doc /* The antenna shall electronically steer its beam. */
            subject radar : System::RadarSystem;
            require { radar.antenna.steeringAzimuth != 0 [rad]
                      or radar.antenna.steeringElevation != 0 [rad]; }
        }

        requirement def TransmitterPowerRequirement {
            doc /* The transmitter shall generate high-power RF pulses. */
            attribute minPeakPower : Power = 10000 [W];
            subject radar : System::RadarSystem;
            require { radar.transmitter.peakPower >= minPeakPower; }
        }

        requirement def ReceiverSensitivityRequirement {
            doc /* The receiver shall amplify weak echoes and filter noise. */
            attribute minGain : Gain = 60 [dB];
            subject radar : System::RadarSystem;
            require { radar.receiver.gain >= minGain; }
        }

        requirement def ReportOutputRequirement {
            doc /* The radar shall output processed target data to an external system. */
            subject radar : System::RadarSystem;
            require { exists(radar.externalDataPort.data); }
        }

        requirement radarSystemRequirements :> RadarDetectionRequirement;
        requirement velocityRequirement :> VelocityMeasurementRequirement;
        requirement directionRequirement :> DirectionMeasurementRequirement;
        requirement modeRequirement :> ModeControlRequirement;
        requirement steeringRequirement :> BeamSteeringRequirement;
        requirement powerRequirement :> TransmitterPowerRequirement;
        requirement sensitivityRequirement :> ReceiverSensitivityRequirement;
        requirement outputRequirement :> ReportOutputRequirement;
    }
}
