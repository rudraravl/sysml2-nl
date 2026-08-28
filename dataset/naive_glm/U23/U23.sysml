package FleetCommandControlSystem {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ============ VALUE TYPES WITH UNITS ============

    value def Distance :> Length {
        doc "Linear distance value, derived from ISQ::Length";
    }

    value def Speed :> Velocity {
        doc "Speed value, derived from ISQ::Velocity";
    }

    value def HeadingAngle :> AngleValue {
        doc "Heading angle, derived from ISQ::AngleValue";
    }

    value def BatteryLevel :> Real {
        doc "Battery charge level expressed as percentage, 0..100";
    }

    value def ToleranceDistance :> Distance {
        doc "Acceptable deviation from assigned formation position";
    }

    value def Position2D {
        attribute x : Distance;
        attribute y : Distance;
    }

    value def Velocity2D {
        attribute vx : Speed;
        attribute vy : Speed;
    }

    value def MachineId :> String {
        doc "Unique identifier for an autonomous machine";
    }

    // ============ ENUMERATIONS ============

    enum def FormationPattern {
        enum values
            wedge
            column
            line
            diamond
            echelon;
    }

    enum def OperationalState {
        enum values
            standby
            marching
            correcting
            recharging;
    }

    // ============ ITEM DEFINITIONS ============

    item def MissionDirective {
        doc "High-level mission objective issued by the Mission Controller";
        attribute destination : Position2D;
        attribute phaseSequence : String[0..*];
        attribute nominalSpeed : Speed;
        attribute formationPattern : FormationPattern;
    }

    item def FormationCommand {
        doc "Per-machine marching order issued by the Formation Coordinator";
        attribute machineId : MachineId;
        attribute assignedPosition : Position2D;
        attribute assignedSpeed : Speed;
        attribute destinationWaypoint : Position2D;
        attribute formationPattern : FormationPattern;
    }

    item def MachineStatus {
        doc "Telemetry reported by each autonomous machine";
        attribute machineId : MachineId;
        attribute currentPosition : Position2D;
        attribute currentSpeed : Speed;
        attribute currentHeading : HeadingAngle;
        attribute batteryLevel : BatteryLevel;
        attribute operationalState : OperationalState;
        attribute timestamp : TimeValue;
    }

    item def NeighborStatus {
        doc "Status shared directly between neighboring machines";
        attribute neighborId : MachineId;
        attribute neighborPosition : Position2D;
        attribute neighborSpeed : Speed;
        attribute neighborBattery : BatteryLevel;
    }

    item def FleetProgressReport {
        doc "Aggregated fleet progress report produced for the Mission Controller";
        attribute machinesReporting : Integer;
        attribute fleetCentroid : Position2D;
        attribute avgProgress : Distance;
        attribute batteryAverage : BatteryLevel;
        attribute missionPhase : String;
    }

    // ============ PORT DEFINITIONS ============

    port def MissionDirectiveOutPort {
        out item directive : MissionDirective;
    }

    port def MissionDirectiveInPort {
        in item directive : MissionDirective;
    }

    port def FleetProgressReportOutPort {
        out item progress : FleetProgressReport;
    }

    port def FleetProgressReportInPort {
        in item progress : FleetProgressReport;
    }

    port def CoordinatorCommandPort {
        out item command : FormationCommand;
    }

    port def MachineCommandReceivePort {
        in item command : FormationCommand;
    }

    port def MachineTelemetrySendPort {
        out item status : MachineStatus;
    }

    port def CoordinatorTelemetryPort {
        in item status : MachineStatus;
    }

    port def NeighborSyncPort {
        in item incomingNeighborStatus : NeighborStatus;
        out item outgoingNeighborStatus : NeighborStatus;
    }

    // ============ REQUIREMENTS ============

    requirement def CoordinatedMarchRequirement {
        doc "Top-level requirement for the fleet command and control system";
        subject c2system : CommandControlSystem;
        objective {
            doc "Make a fleet of 100 autonomous machines move together in precise, pre-defined formations toward a destination";
        }
        assume {
            doc "Terrain is navigable by all autonomous machines in the fleet";
        }
    }

    requirement def ThreeTieredArchitectureRequirement {
        subject c2system : CommandControlSystem;
        objective {
            doc "System shall implement a three-tiered control architecture: Mission Controller, Formation Coordinator, and Autonomous Machines";
        }
    }

    requirement def FormationIntegrityRequirement {
        subject coordinator : FormationCoordinator;
        attribute tolerance : ToleranceDistance = 2;
        objective {
            doc "Each machine shall remain within 2 meters of its assigned position in the active formation";
        }
    }

    requirement def AutonomousNavigationRequirement {
        subject machine : AutonomousMachine;
        objective {
            doc "Each machine shall track its position, speed, and battery level and navigate autonomously";
        }
    }

    requirement def DeviationCorrectionRequirement {
        subject machine : AutonomousMachine;
        objective {
            doc "When a machine deviates from its assigned spot, it shall automatically compute corrections to its heading and speed to return to formation";
        }
    }

    requirement def EnduranceRequirement {
        subject machine : AutonomousMachine;
        objective {
            doc "Each machine shall operate for extended periods before requiring recharge";
        }
    }

    requirement def NeighborCommunicationRequirement {
        subject machine : AutonomousMachine;
        objective {
            doc "Each machine shall communicate directly with its neighbors to share status updates and maintain local spacing and coherence";
        }
    }

    requirement def RechargingLifecycleRequirement {
        subject machine : AutonomousMachine;
        objective {
            doc "Each machine shall transition to recharging when battery is low and return to standby after recharging";
        }
    }

    // ============ MISSION CONTROLLER (STRATEGIC PLANNER) ============

    block MissionController {
        doc "Strategic planner: defines mission objective, plans phases, and monitors fleet progress toward the final goal";

        port missionOut : MissionDirectiveOutPort;
        port progressIn : FleetProgressReportInPort;

        attribute currentDirective : MissionDirective;
        attribute currentPhase : Integer;
        attribute totalPhases : Integer;
        attribute fleetReportingCount : Integer;
        attribute finalDestination : Position2D;

        action planMission(in destination : Position2D, in formation : FormationPattern) : MissionDirective {
            doc "Produce a phased mission directive with destination, sequence, nominal speed and formation pattern";
        }

        action advancePhase() {
            doc "Move to the next mission phase when the current phase completes";
        }

        action evaluateProgress(in report : FleetProgressReport) {
            doc "Compare fleet progress against the planned mission objective";
        }

        state machine MissionLifecycle {
            state planning {
                entry {
                    currentPhase := 0;
                    totalPhases := 0;
                }
            }
            state executing;
            state monitoring;
            state completed;

            transition from planning to executing
                when currentDirective != null;
            transition from executing to monitoring
                when fleetReportingCount > 0;
            transition from monitoring to executing
                when currentPhase < totalPhases;
            transition from monitoring to completed
                when currentPhase == totalPhases;
        }
    }

    // ============ FORMATION COORDINATOR (TACTICAL MANAGER) ============

    block FormationCoordinator {
        doc "Tactical manager for the entire fleet: maintains formation shape and integrity, computes assigned slots, and issues per-machine corrections";

        port directiveIn : MissionDirectiveInPort;
        port progressReportOut : FleetProgressReportOutPort;
        port commandsOut : CoordinatorCommandPort[*];
        port telemetryIn : CoordinatorTelemetryPort[*];

        attribute fleetSize : Integer = 100;
        attribute formationTolerance : ToleranceDistance = 2;
        attribute activePattern : FormationPattern;
        attribute fleetCentroid : Position2D;
        attribute assignedSlots : Position2D[0..*];
        attribute lastKnownPositions : Position2D[0..*];
        attribute lowBatteryCount : Integer;

        action computeAssignedSlot(in machineId : MachineId, in pattern : FormationPattern, in centroid : Position2D, in index : Integer) : Position2D {
            doc "Compute the ideal spot for a given machine within the active formation pattern";
        }

        action computeCorrection(in machineId : MachineId, in actual : Position2D, in assigned : Position2D, in targetSpeed : Speed) : FormationCommand {
            doc "Build a FormationCommand that corrects a machine's position and speed when deviation exceeds tolerance";
        }

        action assessFleet(in statuses : MachineStatus[0..*]) {
            doc "Compare each machine's current position to its assigned slot and flag those exceeding tolerance";
        }

        action dispatchCorrections(in commands : FormationCommand[0..*]) {
            doc "Send correction commands to the machines via the commandsOut ports";
        }

        action aggregateProgress(in statuses : MachineStatus[0..*]) : FleetProgressReport {
            doc "Aggregate individual machine statuses into a fleet progress report for the Mission Controller";
        }

        state machine CoordinationCycle {
            state assessing;
            state computing;
            state dispatching;

            transition from assessing to computing
                when true;
            transition from computing to dispatching
                when true;
            transition from dispatching to assessing
                when true;
        }
    }

    // ============ AUTONOMOUS MACHINE (INDIVIDUAL UNIT) ============

    block AutonomousMachine {
        doc "Independent battery-powered autonomous unit navigating terrain; tracks state, receives orders, and shares status with neighbors";

        port commandIn : MachineCommandReceivePort;
        port statusOut : MachineTelemetrySendPort;
        port neighborLinks : NeighborSyncPort[*];

        attribute machineId : MachineId;
        attribute currentPosition : Position2D;
        attribute currentVelocity : Velocity2D;
        attribute currentHeading : HeadingAngle;
        attribute batteryLevel : BatteryLevel;
        attribute operationalState : OperationalState;
        attribute assignedPosition : Position2D;
        attribute assignedSpeed : Speed;
        attribute destinationWaypoint : Position2D;
        attribute lowBatteryThreshold : BatteryLevel = 15;
        attribute fullChargeThreshold : BatteryLevel = 95;
        attribute deviationThreshold : ToleranceDistance = 2;
        attribute neighbors : MachineId[0..*];
        attribute isLeader : Boolean = false;

        action computeDeviation() : Distance {
            doc "Return the Euclidean distance between current position and assigned formation position";
        }

        action computeCorrectionHeading(in current : Position2D, in assigned : Position2D) : HeadingAngle {
            doc "Compute the heading that points from current position toward the assigned formation slot";
        }

        action computeCorrectionSpeed(in current : Position2D, in assigned : Position2D, in targetSpeed : Speed) : Speed {
            doc "Compute adjusted speed to converge on the assigned slot without overshoot";
        }

        action navigateTo(in waypoint : Position2D, in speed : Speed) {
            doc "Plan and follow a local path to a waypoint at the given speed";
        }

        action broadcastNeighborStatus() {
            doc "Emit NeighborStatus on the outgoing side of each neighborLinks port";
        }

        action receiveNeighborStatus(in incoming : NeighborStatus) {
            doc "Incorporate incoming neighbor status into the local neighbor map and adjust spacing";
        }

        action reportStatus() {
            doc "Emit a MachineStatus on the statusOut port";
        }

        action recharge() {
            doc "Return to base and charge the battery";
        }

        state machine MachineLifecycle {
            state standby {
                doc "Awaiting marching orders";
                entry {
                    operationalState := OperationalState::standby;
                }
            }
            state marching {
                doc "Moving toward a waypoint at the assigned speed";
                entry {
                    operationalState := OperationalState::marching;
                }
            }
            state correcting {
                doc "Actively correcting path to maintain formation";
                entry {
                    operationalState := OperationalState::correcting;
                }
            }
            state recharging {
                doc "Returning to base for battery recharge";
                entry {
                    operationalState := OperationalState::recharging;
                }
            }

            transition from standby to marching
                when commandIn.command.assignedPosition != null
                and commandIn.command.assignedSpeed > 0;
            transition from marching to correcting
                when computeDeviation() > deviationThreshold;
            transition from correcting to marching
                when computeDeviation() <= deviationThreshold;
            transition from marching to recharging
                when batteryLevel <= lowBatteryThreshold;
            transition from correcting to recharging
                when batteryLevel <= lowBatteryThreshold;
            transition from recharging to standby
                when batteryLevel >= fullChargeThreshold;
            transition from standby to recharging
                when batteryLevel <= lowBatteryThreshold;
        }
    }

    // ============ COMMAND AND CONTROL SYSTEM (TOP LEVEL) ============

    block CommandControlSystem {
        doc "Top-level command and control system for the coordinated march of a 100-machine fleet";

        part missionController : MissionController;
        part formationCoordinator : FormationCoordinator;
        part fleet : AutonomousMachine[100];

        // Mission Controller -> Formation Coordinator
        connect missionController.missionOut to formationCoordinator.directiveIn;
        // Formation Coordinator -> Mission Controller (progress report)
        connect formationCoordinator.progressReportOut to missionController.progressIn;
        // Formation Coordinator -> each machine (per-machine commands)
        connect formationCoordinator.commandsOut to fleet.commandIn;
        // Each machine -> Formation Coordinator (telemetry)
        connect fleet.statusOut to formationCoordinator.telemetryIn;
        // Inter-machine neighbor links for local spacing and coherence
        connect fleet.neighborLinks to fleet.neighborLinks;
    }

    // ============ REQUIREMENT SATISFACTION ============

    requirement coordinatedMarchReq : CoordinatedMarchRequirement;
    requirement architectureReq : ThreeTieredArchitectureRequirement;
    requirement integrityReq : FormationIntegrityRequirement;
    requirement navReq : AutonomousNavigationRequirement;
    requirement correctionReq : DeviationCorrectionRequirement;
    requirement enduranceReq : EnduranceRequirement;
    requirement neighborReq : NeighborCommunicationRequirement;
    requirement lifecycleReq : RechargingLifecycleRequirement;

    satisfy coordinatedMarchReq by CommandControlSystem;
    satisfy architectureReq by CommandControlSystem;
    satisfy integrityReq by FormationCoordinator;
    satisfy navReq by fleet;
    satisfy correctionReq by fleet;
    satisfy enduranceReq by fleet;
    satisfy neighborReq by fleet;
    satisfy lifecycleReq by fleet;
}
