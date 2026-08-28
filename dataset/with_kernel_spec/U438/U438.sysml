package VacuumExtractionSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    item def Air;
    item def ContaminatedAir :> Air;
    item def CleanAir :> Air;
    item def Debris;

    attribute def PowerLevel :> Real;
    attribute def FillLevel :> Real;
    attribute def SaturationLevel :> Real;

    attribute def PowerOnCommand;
    attribute def PowerOffCommand;
    attribute def FilterSaturatedAlert;
    attribute def ContainerFullAlert;
    attribute def FilterReplaced;
    attribute def ContainerEmptied;

    port def AirFlowPort {
        in air : Air;
        out air : Air;
    }
    port def CmdPort;
    port def DrivePort;
    port def DebrisPort;
    port def AlertPort;
    port def MotorControlPort;
    port def SensorPort;

    action def StartMotor;
    action def StopMotor;
    action def ReduceMotorPower;
    action def AlertOperator;
    action def ProvideVacuum;
    action def SendAlert;

    state def SystemStates;
    state def FilterStates;
    state def ContainerStates;

    part def Motor {
        attribute currentPower : PowerLevel = 0.0;
        attribute nominalPower : PowerLevel = 1000.0;
        attribute speed :> ISQ::angularVelocity;
        port drivePort : ~DrivePort;
        port controlPort : MotorControlPort;
    }

    part def ImpellerFan {
        attribute speed :> ISQ::angularVelocity;
        port drivePort : DrivePort;
        port airPort : AirFlowPort;
    }

    part def IntakeNozzle {
        port airPort : AirFlowPort;
    }

    part def FilterAssembly {
        attribute saturation : SaturationLevel = 0.0;
        port airInPort : AirFlowPort;
        port airOutPort : AirFlowPort;
        port debrisPort : DebrisPort;
        port sensorPort : SensorPort;
        exhibit state filterStates : FilterStates {
            entry; then clean;
            state clean;
            accept when saturation > 0.5 then partiallyLoaded;
            state partiallyLoaded;
            accept when saturation > 0.9 then saturated;
            state saturated;
            accept FilterReplaced then clean;
        }
    }

    part def CollectionContainer {
        attribute fill : FillLevel = 0.0;
        attribute capacity : FillLevel = 100.0;
        port debrisPort : ~DebrisPort;
        port sensorPort : SensorPort;
        exhibit state containerStates : ContainerStates {
            entry; then notFull;
            state notFull;
            accept when fill >= 80.0 then full;
            state full;
            accept ContainerEmptied then notFull;
        }
    }

    part def ExhaustPort {
        port airPort : AirFlowPort;
    }

    part def ControlUnit {
        port cmdPort : CmdPort;
        port motorControlPort : MotorControlPort;
        port filterSensorPort : SensorPort;
        port containerSensorPort : SensorPort;
        port alertPort : AlertPort;
    }

    part def Operator {
        port cmdPort : ~CmdPort;
        port alertPort : ~AlertPort;
    }

    part def VacuumSystem {
        port cmdPort : CmdPort;
        port alertPort : AlertPort;
        part controlUnit : ControlUnit;
        part motor : Motor;
        part fan : ImpellerFan;
        part intake : IntakeNozzle;
        part filterAssembly : FilterAssembly;
        part container : CollectionContainer;
        part exhaust : ExhaustPort;

        perform action startMotor;
        perform action stopMotor;
        perform action reduceMotorPower;
        perform action sendAlert;
        perform action provideVacuum;

        connect cmdPort to controlUnit.cmdPort;
        connect controlUnit.alertPort to alertPort;
        connect motor.drivePort to fan.drivePort;
        connect controlUnit.motorControlPort to motor.controlPort;
        connect intake.airPort to filterAssembly.airInPort;
        connect filterAssembly.debrisPort to container.debrisPort;
        connect filterAssembly.airOutPort to exhaust.airPort;
        connect filterAssembly.sensorPort to controlUnit.filterSensorPort;
        connect container.sensorPort to controlUnit.containerSensorPort;

        exhibit state systemStates : SystemStates parallel {
            state operationalStates {
                entry; then standby;
                state standby;
                accept PowerOnCommand via cmdPort
                    then startup;
                state startup {
                    entry startMotor;
                }
                transition startup_to_operating
                    first startup
                    then operating;
                state operating {
                    do provideVacuum;
                }
                accept PowerOffCommand via cmdPort
                    then shutdown;
                state shutdown {
                    entry stopMotor;
                }
                transition shutdown_to_standby
                    first shutdown
                    then standby;
            }
            state healthStates {
                entry; then normal;
                state normal;
                accept FilterSaturatedAlert
                    do reduceMotorPower
                    then filterAlert;
                state filterAlert;
                accept FilterReplaced then normal;
                accept ContainerFullAlert
                    do sendAlert
                    then containerAlert;
                state containerAlert;
                accept ContainerEmptied then normal;
            }
        }
    }

    requirement def PowerOnRequirement {
        subject s : VacuumSystem;
        text = "The system shall transition from standby to operating state when a powerOn command is received.";
    }

    requirement def FilterMaintenanceRequirement {
        subject f : FilterAssembly;
        attribute saturationThreshold : SaturationLevel = 0.9;
        text = "The system shall alert the operator when the filter saturation exceeds 90 percent.";
    }

    requirement def ContainerCapacityRequirement {
        subject c : CollectionContainer;
        attribute fillThreshold : FillLevel = 80.0;
        text = "The system shall alert the operator when the collection container fill level reaches 80 percent.";
    }

    requirement def PowerReductionRequirement {
        subject m : Motor;
        attribute powerReductionPercent : Real = 0.3;
        text = "The controller shall reduce motor power by at least 30 percent when the filter is saturated.";
    }

    part vacuumSystem : VacuumSystem;

    requirement powerOnReq : PowerOnRequirement;
    requirement filterMaintReq : FilterMaintenanceRequirement;
    requirement containerCapReq : ContainerCapacityRequirement;
    requirement powerReductionReq : PowerReductionRequirement;
}
