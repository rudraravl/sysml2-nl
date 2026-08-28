package CrankshaftPositionSensingSystem {
    private import ScalarValues::*;

    package Definitions {
        package ValueDefinitions {
            attribute def Voltage :> ScalarValues::Real;
            attribute def AngularVelocity :> ScalarValues::Real;
            attribute def CrankAngle :> ScalarValues::Real;
            attribute def RotationalSpeed :> ScalarValues::Real;
            attribute def TimeValue :> ScalarValues::Real;
        }

        package ItemDefinitions {
            private import ValueDefinitions::*;
            item def RawVoltagePulse {
                attribute amplitude :> Voltage;
                attribute duration :> TimeValue;
            }
            item def FilteredPulse :> RawVoltagePulse;
            item def DigitalPulse {
                attribute timestamp :> TimeValue;
            }
            item def CrankshaftTelemetry {
                attribute crankshaftAngle :> CrankAngle;
                attribute crankshaftSpeed :> RotationalSpeed;
                attribute isSynchronized :> Boolean;
            }
            attribute def PowerOn;
            attribute def PowerOff;
            attribute def InitComplete;
            attribute def GapDetected;
            attribute def ErrorDetected;
            attribute def AttemptRecovery;
            attribute def SyncRestored;
            attribute def SyncFailed;
            attribute def ResetCommand;
        }

        package PortDefinitions {
            private import ItemDefinitions::*;
            port def AnalogSignalOutPort {
                out item pulse : RawVoltagePulse;
            }
            port def AnalogSignalInPort {
                in item pulse : RawVoltagePulse;
            }
            port def FilteredSignalOutPort {
                out item pulse : FilteredPulse;
            }
            port def FilteredSignalInPort {
                in item pulse : FilteredPulse;
            }
            port def TelemetryOutPort {
                out item telemetry : CrankshaftTelemetry;
            }
            port def TelemetryInPort {
                in item telemetry : CrankshaftTelemetry;
            }
        }

        package PartDefinitions {
            private import PortDefinitions::*;
            private import ItemDefinitions::*;
            private import ValueDefinitions::*;
            private import StateDefinitions::*;
            private import ActionDefinitions::*;
            private import RequirementDefinitions::*;

            part def ReluctorWheel {
                attribute totalTeethCount :> Integer = 60;
                attribute missingTeethCount :> Integer = 2;
                attribute referenceGapAngle :> CrankAngle;
                attribute currentRotationAngle :> CrankAngle;
            }

            part def Crankshaft {
                attribute currentAngle :> CrankAngle;
                attribute currentSpeed :> RotationalSpeed;
                part reluctorWheelAttachment : ReluctorWheel {
                    satisfy ReluctorPatternRequirement;
                }
            }

            part def HallEffectSensor {
                port rawSignalOut : AnalogSignalOutPort;
                attribute supplyVoltage :> Voltage;
                perform action generatePulse : GeneratePulse;
            }

            part def SignalConditioningCircuit {
                port rawSignalIn : AnalogSignalInPort;
                port filteredSignalOut : FilteredSignalOutPort;
                part amplifier {
                    attribute gain :> Real = 10.0;
                    perform action amplifySignal : AmplifySignal;
                }
                part noiseFilter {
                    attribute cutoffFrequency :> Real = 1000.0;
                    perform action filterNoise : FilterNoise;
                }
            }

            part def DigitalSignalProcessor {
                port signalIn : FilteredSignalInPort;
                port telemetryOut : TelemetryOutPort;
                attribute clockFrequency :> Real;
                attribute lastToothTime :> TimeValue;
                attribute currentAngle :> CrankAngle;
                attribute currentSpeed :> RotationalSpeed;
                perform action detectToothTransitions : DetectToothTransitions;
                perform action calculateAngularVelocity : CalculateAngularVelocity;
                perform action identifyReferenceGap : IdentifyReferenceGap;
                perform action reportTelemetry : ReportTelemetry;
                exhibit state processorStates : ProcessorStates;
            }

            part def CrankshaftPositionSensingUnit {
                port telemetryPort : TelemetryOutPort;
                part sensor : HallEffectSensor;
                part conditioningCircuit : SignalConditioningCircuit;
                part processor : DigitalSignalProcessor;

                connect sensor.rawSignalOut to conditioningCircuit.rawSignalIn;
                connect conditioningCircuit.filteredSignalOut to processor.signalIn;
                connect processor.telemetryOut to telemetryPort;

                perform action initializeUnit : Initialize;
                perform action selfTest : SelfTest;
                perform action recover : Recover;
                exhibit state unitStates : UnitStates;
            }

            part def EngineControlUnit {
                port ecuInputPort : TelemetryInPort;
                perform action useEngineData : UseEngineData;
            }
        }

        package ActionDefinitions {
            private import ItemDefinitions::*;
            private import ValueDefinitions::*;

            action def GeneratePulse {
                out pulse : RawVoltagePulse;
            }
            action def AmplifySignal {
                in rawPulse : RawVoltagePulse;
                out amplifiedPulse : RawVoltagePulse;
            }
            action def FilterNoise {
                in amplifiedPulse : RawVoltagePulse;
                out filteredPulse : FilteredPulse;
            }
            action def DetectToothTransitions {
                in filteredPulse : FilteredPulse;
                out toothDetected : Boolean;
            }
            action def CalculateAngularVelocity {
                in toothDetected : Boolean;
                out speed : RotationalSpeed;
            }
            action def IdentifyReferenceGap {
                in filteredPulse : FilteredPulse;
                out gapFound : Boolean;
                out angularPosition : CrankAngle;
            }
            action def ReportTelemetry {
                in angle : CrankAngle;
                in speed : RotationalSpeed;
                in synchronized : Boolean;
                out telemetry : CrankshaftTelemetry;
            }
            action def Initialize;
            action def SelfTest;
            action def Recover;
            action def UseEngineData {
                in telemetry : CrankshaftTelemetry;
            }
        }

        package StateDefinitions {
            private import ItemDefinitions::*;

            state def UnitStates {
                entry; then off;
                state off;
                accept PowerOn then initializing;
                state initializing;
                accept InitComplete then synchronizing;
                state synchronizing;
                accept GapDetected then operational;
                state operational;
                accept ErrorDetected then fault;
                accept PowerOff then off;
                state fault;
                accept AttemptRecovery then synchronizing;
                accept SyncFailed then fault;
            }

            state def ProcessorStates {
                entry; then idle;
                state idle;
                accept PowerOn then initializing;
                state initializing;
                accept InitComplete then synchronizing;
                state synchronizing;
                accept GapDetected then operational;
                state operational;
                accept ErrorDetected then fault;
                state fault;
                accept SyncRestored then operational;
                accept SyncFailed then fault;
                accept ResetCommand then initializing;
            }
        }

        package RequirementDefinitions {
            private import ValueDefinitions::*;

            requirement def PositionAccuracyRequirement {
                doc /* The sensing unit shall measure crankshaft position with an accuracy of at least 1 degree. */
                attribute maxError :> CrankAngle = 1.0;
            }
            requirement def SpeedMeasurementRange {
                doc /* The sensing unit shall measure crankshaft speed up to 10000 RPM. */
                attribute maxRPM :> RotationalSpeed = 166.67;
            }
            requirement def ReluctorPatternRequirement {
                doc /* The reluctor wheel shall feature a pattern of 60 teeth with a gap where two teeth are missing to serve as an absolute position reference. */
                attribute totalTeeth :> Integer = 60;
                attribute missingTeeth :> Integer = 2;
            }
            requirement def SignalProcessingRequirement {
                doc /* The raw analog voltage pulse shall be amplified and filtered to remove electrical noise before processing. */
                attribute minGain :> Real = 5.0;
                attribute maxCutoffFrequency :> Real = 2000.0;
            }
            requirement def GapDetectionRequirement {
                doc /* The signal processor shall identify the longer-than-usual pause indicating the missing-tooth gap to determine absolute crankshaft position. */
                attribute maxSyncRevolutions :> Integer = 2;
            }
            requirement def StateManagementRequirement {
                doc /* The unit shall transition from synchronizing to operational upon gap detection, and enter a fault state upon error detection with recovery capability. */
            }
        }
    }

    package Usages {
        private import Definitions::PartDefinitions::*;
        private import Definitions::PortDefinitions::*;
        private import Definitions::ItemDefinitions::*;
        private import Definitions::ActionDefinitions::*;
        private import Definitions::StateDefinitions::*;
        private import Definitions::RequirementDefinitions::*;
        private import Definitions::ValueDefinitions::*;

        part engineManagementSystem {
            part crankshaft : Crankshaft;
            part cpsUnit : CrankshaftPositionSensingUnit {
                satisfy PositionAccuracyRequirement;
                satisfy SpeedMeasurementRange;
                satisfy StateManagementRequirement;
                satisfy SignalProcessingRequirement;
                satisfy GapDetectionRequirement;
            }
            part ecu : EngineControlUnit;

            connect cpsUnit.telemetryPort to ecu.ecuInputPort;
        }
    }
}
