package 'Liquid Propellant Propulsion System' {

    private import ScalarValues::*;

    // === Units ===
    attribute def Unit;
    attribute kg : Unit;
    attribute degC : Unit;
    attribute Pa : Unit;
    attribute mps : Unit;
    attribute N : Unit;
    attribute sec : Unit;

    // === Value Types ===
    attribute def Mass :> Real;
    attribute def Temperature :> Real;
    attribute def Pressure :> Real;
    attribute def Speed :> Real;
    attribute def Force :> Real;
    attribute def Duration :> Real;

    // === Item Types ===
    item def Propellant;
    item def PressurizedPropellant;
    item def ExhaustGas;
    item def IgnitionSignal;
    item def IgnitionConfirmed;
    item def ShutdownCommand;
    item def AnomalyDetected;
    item def EmergencyComplete;

    item def FlowControlCommand {
        attribute flowRate : Real;
        attribute targetPressure : Pressure;
    }

    item def ThrustCommand {
        attribute desiredThrust : Force;
        attribute burnDuration : Duration;
    }

    item def TelemetryData {
        attribute chamberPressure : Pressure;
        attribute chamberTemperature : Temperature;
        attribute propellantRemaining : Mass;
        attribute currentThrust : Force;
    }

    // === Port Definitions ===
    port def ThrustCommandInPort { in item thrustCommand : ThrustCommand; }
    port def ThrustCommandOutPort { out item thrustCommand : ThrustCommand; }
    port def TelemetryInPort { in item telemetry : TelemetryData; }
    port def TelemetryOutPort { out item telemetry : TelemetryData; }
    port def IgnitionOutPort { out item ignition : IgnitionSignal; }
    port def IgnitionInPort { in item ignition : IgnitionSignal; }
    port def FlowControlOutPort { out item flowControl : FlowControlCommand; }
    port def FlowControlInPort { in item flowControl : FlowControlCommand; }
    port def PropellantOutPort { out item propellant : Propellant; }
    port def PropellantInPort { in item propellant : Propellant; }
    port def PressurizedPropellantOutPort { out item propellant : PressurizedPropellant; }
    port def PressurizedPropellantInPort { in item propellant : PressurizedPropellant; }
    port def ExhaustOutPort { out item exhaust : ExhaustGas; }
    port def ExhaustInPort { in item exhaust : ExhaustGas; }
    port def ThrustOutPort { out attribute thrust : Force; }

    // === Part Definitions ===
    part def SpacecraftComputer {
        port commandPort : ThrustCommandOutPort;
        port telemetryPort : TelemetryInPort;
    }

    part def ThrustController {
        port commandPort : ThrustCommandInPort;
        port telemetryPort : TelemetryOutPort;
        port ignitionPort : IgnitionOutPort;
        port flowControlPort : FlowControlOutPort;
        attribute monitoredChamberPressure : Pressure;
        attribute monitoredChamberTemperature : Temperature;
        attribute monitoredPropellantRemaining : Mass;
    }

    part def PropellantTank {
        port propellantPort : PropellantOutPort;
        attribute propellantMass : Mass = 800 [kg];
    }

    part def PropellantFeedSystem {
        port propellantInPort : PropellantInPort;
        port propellantOutPort : PressurizedPropellantOutPort;
        port flowControlInPort : FlowControlInPort;
        attribute outputPressure : Pressure;
    }

    part def CombustionChamber {
        port propellantInPort : PressurizedPropellantInPort;
        port ignitionInPort : IgnitionInPort;
        port exhaustOutPort : ExhaustOutPort;
        attribute chamberTemperature : Temperature = 3400 [degC];
        attribute chamberPressure : Pressure;
    }

    part def Nozzle {
        port exhaustInPort : ExhaustInPort;
        port thrustOutPort : ThrustOutPort;
        attribute exhaustVelocity : Speed = 4200 [mps];
    }

    // === Propulsion System Assembly ===
    part def PropulsionSystem {
        port commandPort : ThrustCommandInPort;
        port telemetryPort : TelemetryOutPort;
        port thrustPort : ThrustOutPort;

        part thrustController : ThrustController {
            state controllerStateMachine {
                entry; then off;

                state off;

                transition off_to_starting
                    first off
                    accept ThrustCommand via commandPort
                    then starting;

                state starting {
                    entry action startEngine {
                        action sendIgnition {
                            send new IgnitionSignal() to combustionChamber;
                        }
                        then action sendInitialFlowControl {
                            send new FlowControlCommand() to feedSystem;
                        }
                    }
                }

                transition starting_to_steady
                    first starting
                    accept IgnitionConfirmed
                    then steadyThrust;

                state steadyThrust {
                    do action regulateFlow {
                        send new FlowControlCommand() to feedSystem;
                    }
                    do action sendTelemetry {
                        send new TelemetryData() to telemetryPort;
                    }
                }

                transition steady_to_shutdown
                    first steadyThrust
                    accept ShutdownCommand via commandPort
                    then shutdown;

                state shutdown {
                    entry action closeFlowControl {
                        send new FlowControlCommand() to feedSystem;
                    }
                }

                transition off_to_emergency
                    first off
                    accept AnomalyDetected
                    then emergencyShutdown;

                transition starting_to_emergency
                    first starting
                    accept AnomalyDetected
                    then emergencyShutdown;

                transition steady_to_emergency
                    first steadyThrust
                    accept AnomalyDetected
                    then emergencyShutdown;

                transition shutdown_to_emergency
                    first shutdown
                    accept AnomalyDetected
                    then emergencyShutdown;

                state emergencyShutdown {
                    entry action emergencyCloseFlow {
                        send new FlowControlCommand() to feedSystem;
                    }
                }

                transition emergency_to_off
                    first emergencyShutdown
                    accept EmergencyComplete
                    then off;
            }
        }

        part propellantTank : PropellantTank;
        part feedSystem : PropellantFeedSystem;
        part combustionChamber : CombustionChamber;
        part nozzle : Nozzle;

        bind commandPort = thrustController.commandPort;
        bind telemetryPort = thrustController.telemetryPort;
        bind thrustPort = nozzle.thrustOutPort;

        flow propellantFlow of Propellant
            from propellantTank.propellantPort.propellant
            to feedSystem.propellantInPort.propellant;

        flow pressurizedPropellantFlow of PressurizedPropellant
            from feedSystem.propellantOutPort.propellant
            to combustionChamber.propellantInPort.propellant;

        flow exhaustFlow of ExhaustGas
            from combustionChamber.exhaustOutPort.exhaust
            to nozzle.exhaustInPort.exhaust;

        flow ignitionFlow of IgnitionSignal
            from thrustController.ignitionPort.ignition
            to combustionChamber.ignitionInPort.ignition;

        flow flowControlFlow of FlowControlCommand
            from thrustController.flowControlPort.flowControl
            to feedSystem.flowControlInPort.flowControl;
    }

    // === Spacecraft Assembly ===
    part def Spacecraft {
        part spacecraftComputer : SpacecraftComputer;
        part propulsion : PropulsionSystem;

        interface commandInterface connect spacecraftComputer.commandPort to propulsion.commandPort {
            flow commandFlow of ThrustCommand
                from spacecraftComputer.commandPort.thrustCommand
                to propulsion.commandPort.thrustCommand;
        }

        interface telemetryInterface connect propulsion.telemetryPort to spacecraftComputer.telemetryPort {
            flow telemetryFlow of TelemetryData
                from propulsion.telemetryPort.telemetry
                to spacecraftComputer.telemetryPort.telemetry;
        }
    }

    // === Requirements ===
    requirement def PropellantStorageRequirement {
        doc "The propellant tank shall store 800 kg of propellant under pressure.";
        attribute maxPropellantMass : Mass = 800 [kg];
        attribute propellantMass : Mass;
        requirement tankCapacity {
            constraint { propellantMass <= maxPropellantMass }
        }
    }

    requirement def CombustionTemperatureRequirement {
        doc "The combustion chamber shall burn propellant at approximately 3400 degrees Celsius.";
        attribute minChamberTemp : Temperature = 3400 [degC];
        attribute chamberTemperature : Temperature;
        requirement chamberTemp {
            constraint { chamberTemperature >= minChamberTemp }
        }
    }

    requirement def ExhaustVelocityRequirement {
        doc "The nozzle shall accelerate exhaust gas to over 4200 meters per second.";
        attribute minExhaustVelocity : Speed = 4200 [mps];
        attribute exhaustVelocity : Speed;
        requirement nozzlePerformance {
            constraint { exhaustVelocity >= minExhaustVelocity }
        }
    }

    requirement def ThrustControlRequirement {
        doc "The thrust controller shall manage ignition, regulate propellant flow, monitor critical performance data, and send telemetry to the spacecraft.";
    }

    requirement def EmergencyShutdownRequirement {
        doc "The system shall perform emergency shutdown in case of anomaly.";
    }

    requirement propellantStorageReq : PropellantStorageRequirement;
    requirement combustionTempReq : CombustionTemperatureRequirement;
    requirement exhaustVelocityReq : ExhaustVelocityRequirement;
    requirement thrustControlReq : ThrustControlRequirement;
    requirement emergencyShutdownReq : EmergencyShutdownRequirement;
}
