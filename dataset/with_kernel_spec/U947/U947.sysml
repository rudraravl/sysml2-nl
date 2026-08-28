package WheelSpeedSensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package Definitions {
        item def RawPulseSignal {
            attribute frequency : ISQ::frequency;
        }
        item def CleanPulseSignal {
            attribute frequency : ISQ::frequency;
        }
        item def SpeedDataPackage {
            attribute linearSpeed : ISQ::speed;
            attribute angularVelocity : ISQ::frequency;
            attribute timestamp : Time::DateTime;
            attribute qualityScore : Real;
        }
        item def DiagnosticStatus {
            attribute operationalStatus : String;
            attribute faultCodes : Integer[0..*];
        }
        item def PowerSignal;
        item def RecoveryAttempt;

        port def RawSignalPort {
            inout rawSignal : RawPulseSignal;
        }
        port def CleanSignalPort {
            inout cleanSignal : CleanPulseSignal;
        }
        port def SpeedDataPort {
            out speedData : SpeedDataPackage;
        }
        port def DiagnosticPort {
            out diagnosticStatus : DiagnosticStatus;
        }
        port def PowerPort {
            in power : PowerSignal;
        }

        part def ToneRing {
            attribute teethCount : Integer;
            attribute material : String = "Ferromagnetic";
        }

        part def SensingElement {
            port rawSignalOut : RawSignalPort;
            perform action detectMagneticField;
        }

        part def SignalConditioner {
            port rawSignalIn : RawSignalPort;
            port cleanSignalOut : CleanSignalPort;
            perform action amplifyAndFilter;
        }

        part def SpeedCalculator {
            port cleanSignalIn : CleanSignalPort;
            port speedDataOut : SpeedDataPort;
            attribute wheelRadius : ISQ::length;
            attribute teethCount : Integer;
            perform action calculateSpeed;
        }

        action def DetectMagneticField {
            out rawSignal : RawPulseSignal;
        }
        action def AmplifyAndFilter {
            in rawSignal : RawPulseSignal;
            out cleanSignal : CleanPulseSignal;
        }
        action def CalculateSpeed {
            in cleanSignal : CleanPulseSignal;
            in wheelRadius : ISQ::length;
            in teethCount : Integer;
            out speedData : SpeedDataPackage;
        }
        action def PerformSelfCheck {
            out powerStatus : Boolean;
            out signalQuality : Real;
            out temperature : ISQ::temperature;
        }
        action def AttemptRecovery;

        part def WheelSpeedSensor {
            attribute ingressProtection : String = "IP67";
            attribute casingMaterial : String = "Stainless Steel";

            port powerPort : PowerPort;
            port speedDataPort : SpeedDataPort;
            port diagnosticPort : DiagnosticPort;

            part sensingElement : SensingElement;
            part signalConditioner : SignalConditioner;
            part speedCalculator : SpeedCalculator;

            attribute selfCheckPassed : Boolean;
            attribute recoverySuccessful : Boolean;

            perform action performSelfCheck : PerformSelfCheck;
            perform action calculateSpeed : CalculateSpeed;
            perform action attemptRecovery : AttemptRecovery;

            exhibit state sensorStates {
                entry; then Initializing;
                state Initializing;
                transition init_to_selfcheck
                    first Initializing
                    accept PowerSignal
                    then SelfCheck;
                state SelfCheck {
                    entry performSelfCheck;
                }
                transition selfcheck_to_operational
                    first SelfCheck
                    if selfCheckPassed
                    then Operational;
                transition selfcheck_to_fault
                    first SelfCheck
                    if !selfCheckPassed
                    then Fault;
                state Operational {
                    do calculateSpeed;
                    do performSelfCheck;
                }
                transition operational_to_fault
                    first Operational
                    if !selfCheckPassed
                    then Fault;
                state Fault {
                    entry action sendFaultReport {
                        send new DiagnosticStatus() via diagnosticPort;
                    }
                }
                transition fault_to_recovery
                    first Fault
                    accept RecoveryAttempt
                    then Recovery;
                state Recovery {
                    entry attemptRecovery;
                }
                transition recovery_to_operational
                    first Recovery
                    if recoverySuccessful
                    then Operational;
                transition recovery_to_fault
                    first Recovery
                    if !recoverySuccessful
                    then Fault;
            }

            connect sensingElement.rawSignalOut to signalConditioner.rawSignalIn;
            connect signalConditioner.cleanSignalOut to speedCalculator.cleanSignalIn;
            connect speedCalculator.speedDataOut to speedDataPort;
        }

        part def VehicleComputer {
            port speedDataIn : SpeedDataPort;
            port diagnosticIn : DiagnosticPort;
        }

        requirement def SpeedAccuracyRequirement {
            doc /* The sensor must accurately measure wheel speed within specified tolerances. */
            subject sensor : WheelSpeedSensor;
            doc /* The calculated linear speed must be within +/- 1% of actual speed. */
        }

        requirement def EnvironmentalProtectionRequirement {
            doc /* The sensor must be protected from harsh road conditions. */
            subject sensor : WheelSpeedSensor;
            doc /* The sensor casing must be IP67 rated stainless steel. */
        }

        requirement def SelfDiagnosticRequirement {
            doc /* The sensor shall continuously monitor power supply, signal quality, and internal temperature. */
            subject sensor : WheelSpeedSensor;
        }
    }

    package Usages {
        private import Definitions::*;

        part wheelSpeedSystem {
            part toneRing : ToneRing {
                attribute redefines teethCount = 48;
            }
            part sensor : WheelSpeedSensor {
                part speedCalculator {
                    attribute redefines wheelRadius = 0.3 [m];
                    attribute redefines teethCount = 48;
                }
            }
            part vehicleComputer : VehicleComputer;

            connect sensor.speedDataPort to vehicleComputer.speedDataIn;
            connect sensor.diagnosticPort to vehicleComputer.diagnosticIn;

            satisfy SpeedAccuracyRequirement by sensor;
            satisfy EnvironmentalProtectionRequirement by sensor;
            satisfy SelfDiagnosticRequirement by sensor;
        }
    }
}
