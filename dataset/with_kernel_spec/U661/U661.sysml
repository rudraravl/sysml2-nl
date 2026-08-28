package PiezoelectricActuatorSystem {
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def Voltage :> ISQ::ElectricPotentialValue;
    attribute def Displacement :> ISQ::LengthValue;

    attribute def TargetPosition :> Displacement;
    attribute def MeasuredPosition :> Displacement;
    attribute def VoltageCommand :> Voltage;
    attribute def VoltageSignal :> Voltage;
    attribute def EmergencyShutdownSignal;
    attribute def VoltageAppliedSignal;
    attribute def FieldBuiltSignal;
    attribute def TargetReachedSignal;
    attribute def VoltageRemovedSignal;
    attribute def FullyRelaxedSignal;

    part def ControlProcessor {
        port targetPositionPort { in targetPosition : TargetPosition; }
        port measuredPositionPort { in measuredPosition : MeasuredPosition; }
        port voltageCommandPort { out voltageCommand : VoltageCommand; }
        port emergencyPort { out shutdownSignal : EmergencyShutdownSignal; }

        action controlBehavior {
            accept targetCmd : TargetPosition;
            then loop {
                accept measuredPos : MeasuredPosition;
                then action computeError { }
                then action sendCommand send new VoltageCommand() to voltageCommandPort;
            }
        }
    }

    part def VoltageDriver {
        port voltageCommandPort { in voltageCommand : VoltageCommand; }
        port emergencyPort { in shutdownSignal : EmergencyShutdownSignal; }
        port voltageOutputPort { out voltageSignal : VoltageSignal; }

        action driverBehavior {
            accept cmd : VoltageCommand;
            then action amplify { }
            then action outputSignal send new VoltageSignal() to voltageOutputPort;
        }
    }

    part def Electrode {
        attribute isConductive : ScalarValues::Boolean = true;
    }

    part def Substrate {
        attribute stiffness : ScalarValues::Real;
    }

    part def PiezoelectricFilm {
        port voltageInputPort { in voltageSignal : VoltageSignal; }
        port displacementOutputPort { out displacement : Displacement; }

        attribute thickness : Displacement;

        state filmStates {
            entry; then inactive;

            state inactive;
            accept VoltageAppliedSignal then charging;

            state charging {
                do action buildElectricField { }
            }
            accept FieldBuiltSignal then actuating;
            accept EmergencyShutdownSignal then relaxing;

            state actuating {
                do action deform { }
            }
            accept TargetReachedSignal then stabilized;
            accept EmergencyShutdownSignal then relaxing;

            state stabilized {
                do action holdPosition { }
            }
            accept VoltageRemovedSignal then relaxing;
            accept EmergencyShutdownSignal then relaxing;

            state relaxing {
                do action relax { }
            }
            accept FullyRelaxedSignal then inactive;
        }
    }

    part def DisplacementSensor {
        port displacementInputPort { in displacement : Displacement; }
        port measuredOutputPort { out measuredPosition : MeasuredPosition; }

        action sensorBehavior {
            loop {
                accept disp : Displacement;
                then action sendMeasurement send new MeasuredPosition() to measuredOutputPort;
            }
        }
    }

    part def ActuatorAssembly {
        part substrate : Substrate;
        part bottomElectrode : Electrode;
        part piezoFilm : PiezoelectricFilm;
        part topElectrode : Electrode;
    }

    part def ActuatorSystem {
        attribute measuredError : Displacement;

        part controlProcessor : ControlProcessor;
        part voltageDriver : VoltageDriver;
        part actuatorAssembly : ActuatorAssembly;
        part displacementSensor : DisplacementSensor;

        flow voltageCommandFlow of VoltageCommand
            from controlProcessor.voltageCommandPort.voltageCommand
            to voltageDriver.voltageCommandPort.voltageCommand;
        flow voltageSignalFlow of VoltageSignal
            from voltageDriver.voltageOutputPort.voltageSignal
            to actuatorAssembly.piezoFilm.voltageInputPort.voltageSignal;
        flow displacementFlow of Displacement
            from actuatorAssembly.piezoFilm.displacementOutputPort.displacement
            to displacementSensor.displacementInputPort.displacement;
        flow measuredPositionFlow of MeasuredPosition
            from displacementSensor.measuredOutputPort.measuredPosition
            to controlProcessor.measuredPositionPort.measuredPosition;
        flow emergencyFlow of EmergencyShutdownSignal
            from controlProcessor.emergencyPort.shutdownSignal
            to voltageDriver.emergencyPort.shutdownSignal;
    }

    requirement def PositionAccuracyRequirement {
        doc /* The system shall maintain the target position with a precision of 10 nanometers under steady-state conditions. */
        attribute maxError : Displacement = 10.0e-9 [m];
        subject actuator : ActuatorSystem;
        require actuator.measuredError <= maxError;
    }

    requirement def ClosedLoopControlRequirement {
        doc /* The system shall implement closed-loop control using displacement feedback from the displacement sensor to the control processor. */
        subject actuator : ActuatorSystem;
    }

    requirement def EmergencyShutdownRequirement {
        doc /* The system shall provide an emergency shutdown capability to safely remove high voltage from the piezoelectric film upon receiving an emergency shutdown signal. */
        subject actuator : ActuatorSystem;
    }

    requirement def FilmLifecycleRequirement {
        doc /* The piezoelectric film shall transition through inactive, charging, actuating, stabilized, and relaxing states during normal operation. */
        subject film : PiezoelectricFilm;
    }
}
