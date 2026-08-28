package CeilometerModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    package Definitions {
        attribute def CloudHeight :> ISQ::Length;
        attribute def TimeOfFlight :> ISQ::Time;
        attribute def IntensityValue :> ScalarValues::Real;
        attribute def ConfidenceValue :> ScalarValues::Real;
        attribute def EnergyValue :> ScalarValues::Real;

        item def LaserPulse {
            attribute wavelength : ISQ::Length;
            attribute energy : EnergyValue;
        }

        item def BackscatterSignal {
            attribute intensity : IntensityValue;
            attribute timeOfFlight : TimeOfFlight;
        }

        item def CloudMeasurement {
            attribute height : CloudHeight;
            attribute timestamp : Iso8601DateTime;
            attribute confidence : ConfidenceValue;
        }

        item def Command;
        item def StartCommand :> Command;
        item def StopCommand :> Command;
        item def FaultSignal :> Command;
        item def ResetCommand :> Command;

        port def LaserOutputPort {
            out pulse : LaserPulse;
        }

        port def BackscatterInputPort {
            in signal : BackscatterSignal;
        }

        port def SignalOutputPort {
            out signal : BackscatterSignal;
        }

        port def MeasurementOutputPort {
            out measurement : CloudMeasurement;
        }

        port def CommandInputPort {
            in command : Command;
        }

        action def EmitPulse {
            out pulse : LaserPulse;
        }

        action def DetectBackscatter {
            in pulse : LaserPulse;
            out signal : BackscatterSignal;
        }

        action def CalculateHeight {
            in tof : TimeOfFlight;
            in intensity : IntensityValue;
            out height : CloudHeight;
            out confidence : ConfidenceValue;
        }

        action def GenerateMeasurement {
            in height : CloudHeight;
            in confidence : ConfidenceValue;
            in timestamp : Iso8601DateTime;
            out measurement : CloudMeasurement;
        }

        action def RunDiagnostics {
            out status : String;
        }

        action def PerformMeasurementCycle {
            out measurement : CloudMeasurement;
        }

        part def LaserTransmitter {
            port laserPort : LaserOutputPort;
            perform action emit : EmitPulse;
        }

        part def OpticalReceiver {
            port backscatterPort : BackscatterInputPort;
            port signalPort : SignalOutputPort;
            perform action detect : DetectBackscatter;
        }

        part def SignalProcessor {
            port signalPort : SignalOutputPort;
            port measurementPort : MeasurementOutputPort;
            perform action calculate : CalculateHeight;
            perform action generate : GenerateMeasurement;
        }

        state def CeilometerBehavior {
            entry; then standby;

            state standby;
            accept StartCommand
                then warmup;

            state warmup;
            accept after 30 [s]
                then active;

            state active {
                entry; then waiting;
                state waiting;
                accept after 15 [s]
                    then measuring;
                state measuring {
                    do action performCycle : PerformMeasurementCycle;
                }
                accept after 1 [s]
                    then waiting;
            }

            accept StopCommand
                then standby;

            accept FaultSignal
                then fault;

            state fault {
                do action runDiag : RunDiagnostics;
            }
            accept ResetCommand
                then standby;
        }

        part def Ceilometer {
            part transmitter : LaserTransmitter;
            part receiver : OpticalReceiver;
            part processor : SignalProcessor;
            part clock : Clock;

            port cmdPort : CommandInputPort;
            port dataPort : MeasurementOutputPort;

            connect transmitter.laserPort to receiver.backscatterPort;
            connect receiver.signalPort to processor.signalPort;
            connect processor.measurementPort to dataPort;

            exhibit state behavior : CeilometerBehavior;
        }

        requirement def MaxAltitudeRequirement {
            doc "The Ceilometer shall provide cloud height measurements up to an altitude of 7,500 meters.";
            attribute maxAltitude : CloudHeight = 7500 [m];
        }

        requirement def AccuracyRequirement {
            doc "The Ceilometer shall measure cloud base height with an accuracy of plus or minus 10 meters.";
            attribute accuracy : CloudHeight = 10 [m];
        }

        requirement def UpdateRateRequirement {
            doc "The Ceilometer shall update measurement information at least every 15 seconds.";
            attribute updateInterval : ISQ::Time = 15 [s];
        }
    }

    package Usages {
        private import Definitions::*;

        requirement maxAltReq : MaxAltitudeRequirement;
        requirement accuracyReq : AccuracyRequirement;
        requirement updateRateReq : UpdateRateRequirement;

        part ceilometer : Ceilometer {
            satisfy maxAltReq;
            satisfy accuracyReq;
            satisfy updateRateReq;
        }
    }
}
