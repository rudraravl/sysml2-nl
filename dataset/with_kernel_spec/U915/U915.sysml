package ThrottlePositionSensingUnit {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute def ThrottleAngle :> ISQ::angle;
        attribute def VoltageValue :> ISQ::electric_potential;
        attribute def PercentageValue :> ScalarValues::Real;
        attribute def ResponseTimeValue :> ISQ::time;

        attribute def PowerOnSignal;
        attribute def FaultSignal;
        attribute def ResetSignal;

        item def RawSignal {
            attribute angle : ThrottleAngle;
            attribute voltage : VoltageValue;
            attribute openPercentage : PercentageValue;
        }

        item def ProcessedSignal {
            attribute angle : ThrottleAngle;
            attribute voltage : VoltageValue;
            attribute openPercentage : PercentageValue;
        }

        port def RawSignalPort {
            inout rawSignal : RawSignal;
        }

        port def ProcessedSignalPort {
            inout processedSignal : ProcessedSignal;
        }

        action def MeasurePosition {
            out rawSignal : RawSignal;
        }

        action def FilterNoise {
            in rawSignal : RawSignal;
            out processedSignal : ProcessedSignal;
        }

        action def AmplifySignal {
            in processedSignal : ProcessedSignal;
            out amplifiedSignal : ProcessedSignal;
        }

        action def AdjustFuelInjection {
            in processedSignal : ProcessedSignal;
        }

        action def ManageIgnitionTiming {
            in processedSignal : ProcessedSignal;
        }

        action def RunSelfTest;
        action def Calibrate;
        action def LogError;
        action def RunDiagnostics;

        part def ThrottleShaft {
            attribute rotationAngle : ThrottleAngle;
        }

        part def ThrottlePositionSensor {
            ref part throttleShaft : ThrottleShaft;
            port rawOut : RawSignalPort;
            perform action measurePosition : MeasurePosition;
        }

        part def SignalProcessor {
            port rawIn : RawSignalPort;
            port processedOut : ProcessedSignalPort;
            perform action filterNoise : FilterNoise;
            perform action amplifySignal : AmplifySignal;
        }

        part def ControlModule {
            port processedIn : ProcessedSignalPort;
            perform action adjustFuelInjection : AdjustFuelInjection;
            perform action manageIgnitionTiming : ManageIgnitionTiming;
        }

        state def OperationalStates;

        part def ThrottlePositionSensingUnit {
            part shaft : ThrottleShaft;
            part tps : ThrottlePositionSensor;
            part processor : SignalProcessor;
            part controller : ControlModule;

            bind tps.throttleShaft = shaft;
            connect tps.rawOut to processor.rawIn;
            connect processor.processedOut to controller.processedIn;

            exhibit state operationalStates : OperationalStates {
                entry; then off;

                state off;
                accept PowerOnSignal then selfTest;

                state selfTest {
                    entry RunSelfTest;
                    then calibrating;
                }

                state calibrating {
                    entry Calibrate;
                    then measuring;
                }

                state measuring {
                    do MeasurePosition;
                }
                accept FaultSignal then fault;

                state fault {
                    entry LogError;
                    do RunDiagnostics;
                }
                accept ResetSignal then selfTest;
            }
        }

        requirement def AccuracyRequirement {
            doc "The system must measure throttle position accurately to within +/- 0.5%.";
            attribute maxError : PercentageValue = 0.5;
            subject positionError : PercentageValue;
            require constraint { positionError <= maxError }
        }

        requirement def ResponseTimeRequirement {
            doc "The system must respond to throttle changes in under 10 milliseconds.";
            attribute maxResponseTime : ResponseTimeValue = 10 [ms];
            subject responseTime : ResponseTimeValue;
            require constraint { responseTime <= maxResponseTime }
        }
    }

    package Usages {
        private import Definitions::*;

        requirement accuracyRequirement : AccuracyRequirement;
        requirement responseTimeRequirement : ResponseTimeRequirement;

        part sensingUnit : ThrottlePositionSensingUnit {
            satisfy accuracyRequirement;
            satisfy responseTimeRequirement;
        }
    }
}
