package RoboticsSuiteModel {
    import ScalarValues::*;
    import SI::*;

    value def Percent {
        unit = "%";
        quantity kind = "ratio";
    }

    value def Celsius {
        unit = "degC";
        quantity kind = "temperature";
    }

    value def Millisecond {
        unit = "ms";
        quantity kind = "time";
    }

    value def MeterPerSecond {
        unit = "m/s";
        quantity kind = "speed";
    }

    value def NewtonMeter {
        unit = "N*m";
        quantity kind = "torque";
    }

    value def WattHour {
        unit = "W*h";
        quantity kind = "energy";
    }

    item def MissionPlan {
        attribute missionId : String;
        attribute targetAreaName : String;
        attribute maxDuration : Time;
        attribute safetyBoundaryRadius : Length;
        attribute requiresHumanApproval : Boolean;
    }

    item def TaskCommand {
        attribute commandId : String;
        attribute commandType : String;
        attribute priority : Integer;
        attribute issuedTime : Time;
    }

    item def RobotStatus {
        attribute robotId : String;
        attribute operatingMode : String;
        attribute batteryStateOfCharge : Percent;
        attribute faultActive : Boolean;
        attribute estimatedPoseX : Length;
        attribute estimatedPoseY : Length;
        attribute heading : Angle;
    }

    item def SensorObservation {
        attribute observationId : String;
        attribute sourceRobotId : String;
        attribute timestamp : Time;
        attribute confidence : Percent;
        attribute range : Length;
        attribute bearing : Angle;
        attribute classification : String;
    }

    item def ControlSignal {
        attribute leftWheelVelocity : MeterPerSecond;
        attribute rightWheelVelocity : MeterPerSecond;
        attribute manipulatorTorqueLimit : NewtonMeter;
        attribute emergencyStop : Boolean;
    }

    item def PowerFlow {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute availableEnergy : WattHour;
    }

    item def DiagnosticReport {
        attribute reportId : String;
        attribute severity : String;
        attribute componentName : String;
        attribute message : String;
        attribute recommendedAction : String;
    }

    port def MissionCommandPort {
        out item missionPlan : MissionPlan;
        out item taskCommand : TaskCommand;
        in item robotStatus : RobotStatus;
        in item diagnosticReport : DiagnosticReport;
    }

    port def RobotControlPort {
        in item taskCommand : TaskCommand;
        in item controlSignal : ControlSignal;
        out item robotStatus : RobotStatus;
        out item sensorObservation : SensorObservation;
        out item diagnosticReport : DiagnosticReport;
    }

    port def SensorDataPort {
        out item sensorObservation : SensorObservation;
        out item diagnosticReport : DiagnosticReport;
    }

    port def PowerPort {
        out item powerFlow : PowerFlow;
        in item diagnosticReport : DiagnosticReport;
    }

    port def OperatorInterfacePort {
        in item robotStatus : RobotStatus;
        in item sensorObservation : SensorObservation;
        in item diagnosticReport : DiagnosticReport;
        out item missionPlan : MissionPlan;
        out item taskCommand : TaskCommand;
    }

    action def PlanMission {
        in item requestedMission : MissionPlan;
        in item currentFleetStatus : RobotStatus;
        out item assignedCommand : TaskCommand;
    }

    action def NavigateToTarget {
        in item assignedCommand : TaskCommand;
        in item localObservation : SensorObservation;
        out item wheelControl : ControlSignal;
        out item navigationStatus : RobotStatus;
    }

    action def InspectEnvironment {
        in item navigationStatus : RobotStatus;
        out item observation : SensorObservation;
        out item inspectionReport : DiagnosticReport;
    }

    action def ExecuteManipulationTask {
        in item assignedCommand : TaskCommand;
        in item observation : SensorObservation;
        out item actuatorControl : ControlSignal;
        out item taskStatus : RobotStatus;
    }

    action def MonitorHealth {
        in item powerInput : PowerFlow;
        in item robotStatus : RobotStatus;
        out item diagnosticReport : DiagnosticReport;
    }

    state def RobotOperationalState {
        entry action initializeControllers;
        state Idle;
        state Assigned;
        state Navigating;
        state Inspecting;
        state Manipulating;
        state Returning;
        state Charging;
        state Faulted;

        initial then Idle;

        transition Idle_to_Assigned
            first Idle
            accept TaskCommand
            then Assigned;

        transition Assigned_to_Navigating
            first Assigned
            if assignedCommand.commandType == "Navigate"
            then Navigating;

        transition Navigating_to_Inspecting
            first Navigating
            if navigationStatus.operatingMode == "AtInspectionPoint"
            then Inspecting;

        transition Inspecting_to_Manipulating
            first Inspecting
            if assignedCommand.commandType == "Manipulate"
            then Manipulating;

        transition Inspecting_to_Returning
            first Inspecting
            if assignedCommand.commandType == "SurveyComplete"
            then Returning;

        transition Manipulating_to_Returning
            first Manipulating
            if taskStatus.operatingMode == "TaskComplete"
            then Returning;

        transition Returning_to_Idle
            first Returning
            if navigationStatus.operatingMode == "Docked"
            then Idle;

        transition Idle_to_Charging
            first Idle
            if robotStatus.batteryStateOfCharge < 30 [%]
            then Charging;

        transition Charging_to_Idle
            first Charging
            if robotStatus.batteryStateOfCharge >= 95 [%]
            then Idle;

        transition Any_to_Faulted
            first Idle, Assigned, Navigating, Inspecting, Manipulating, Returning, Charging
            if robotStatus.faultActive
            then Faulted;

        transition Faulted_to_Idle
            first Faulted
            accept TaskCommand
            if taskCommand.commandType == "ResetFault"
            then Idle;
    }

    part def SensorSuite {
        attribute lidarRange : Length = 80 [m];
        attribute cameraHorizontalFov : Angle = 120 [deg];
        attribute imuUpdatePeriod : Millisecond = 5 [ms];
        attribute nominalTemperature : Celsius = 35 [degC];

        port sensorOut : SensorDataPort;

        action collectObservation : InspectEnvironment;
    }

    part def MobilityBase {
        attribute maxSpeed : MeterPerSecond = 2.5 [m/s];
        attribute wheelBase : Length = 0.62 [m];
        attribute obstacleClearance : Length = 0.18 [m];

        port controlIn : RobotControlPort;

        action navigate : NavigateToTarget;
    }

    part def ManipulatorArm {
        attribute reach : Length = 1.1 [m];
        attribute payloadCapacity : Mass = 8 [kg];
        attribute maxJointTorque : NewtonMeter = 42 [N*m];

        port controlIn : RobotControlPort;

        action manipulate : ExecuteManipulationTask;
    }

    part def PowerModule {
        attribute batteryCapacity : WattHour = 1500 [W*h];
        attribute nominalVoltage : Voltage = 48 [V];
        attribute minimumSafeCharge : Percent = 15 [%];

        port powerOut : PowerPort;

        action monitorPower : MonitorHealth;
    }

    part def RobotUnit {
        attribute robotId : String;
        attribute mass : Mass = 72 [kg];
        attribute operatingRadius : Length = 250 [m];
        attribute nominalRuntime : Time = 4 [h];

        port commandAndTelemetry : RobotControlPort;
        port powerInput : PowerPort;

        part sensors : SensorSuite;
        part mobility : MobilityBase;
        part manipulator : ManipulatorArm;
        part battery : PowerModule;

        state operationalState : RobotOperationalState;

        connect battery.powerOut to powerInput;
        connect sensors.sensorOut to commandAndTelemetry;
        connect mobility.controlIn to commandAndTelemetry;
        connect manipulator.controlIn to commandAndTelemetry;
    }

    part def FleetCoordinator {
        attribute maxRobotsManaged : Integer = 12;
        attribute replanningPeriod : Millisecond = 250 [ms];
        attribute minimumFleetAvailability : Percent = 75 [%];

        port operatorPort : OperatorInterfacePort;
        port fleetCommandPort : MissionCommandPort;

        action missionPlanning : PlanMission;
    }

    part def OperatorConsole {
        attribute displayRefreshPeriod : Millisecond = 100 [ms];
        attribute alertLatencyLimit : Millisecond = 500 [ms];

        port userPort : OperatorInterfacePort;
    }

    part def SafetySupervisor {
        attribute emergencyStopLatencyLimit : Millisecond = 100 [ms];
        attribute safeSeparationDistance : Length = 1.5 [m];
        attribute maxAllowedSpeedNearHuman : MeterPerSecond = 0.5 [m/s];

        port safetyCommandPort : MissionCommandPort;

        action monitorFleetHealth : MonitorHealth;
    }

    part def RoboticsSuite {
        attribute suiteName : String = "Integrated Robotics Suite";
        attribute primaryFunction : String = "Coordinate a fleet of mobile robots to perceive an operating area, navigate safely, inspect targets, manipulate objects, and report mission status to a human operator.";
        attribute supportedRobotCount : Integer = 6;
        attribute nominalCoverageRadius : Length = 250 [m];
        attribute commandResponseLimit : Millisecond = 300 [ms];

        port operatorAccess : OperatorInterfacePort;

        part operatorConsole : OperatorConsole;
        part coordinator : FleetCoordinator;
        part safetySupervisor : SafetySupervisor;
        part robotA : RobotUnit {
            attribute robotId = "RBT-A";
        }
        part robotB : RobotUnit {
            attribute robotId = "RBT-B";
        }
        part robotC : RobotUnit {
            attribute robotId = "RBT-C";
        }

        connect operatorConsole.userPort to operatorAccess;
        connect operatorConsole.userPort to coordinator.operatorPort;
        connect coordinator.fleetCommandPort to robotA.commandAndTelemetry;
        connect coordinator.fleetCommandPort to robotB.commandAndTelemetry;
        connect coordinator.fleetCommandPort to robotC.commandAndTelemetry;
        connect safetySupervisor.safetyCommandPort to robotA.commandAndTelemetry;
        connect safetySupervisor.safetyCommandPort to robotB.commandAndTelemetry;
        connect safetySupervisor.safetyCommandPort to robotC.commandAndTelemetry;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The robotics suite shall coordinate multiple mobile robots to execute operator-approved missions involving navigation, sensing, inspection, manipulation, and status reporting. */
        subject suite : RoboticsSuite;
        require constraint {
            suite.supportedRobotCount >= 3
        }
    }

    requirement def SafetyStopRequirement {
        doc /* The robotics suite shall command an emergency stop to every active robot within the specified latency when a critical safety fault is detected. */
        subject supervisor : SafetySupervisor;
        require constraint {
            supervisor.emergencyStopLatencyLimit <= 100 [ms]
        }
    }

    requirement def MissionResponseRequirement {
        doc /* The robotics suite shall acknowledge and distribute valid mission commands within the command response limit. */
        subject suite : RoboticsSuite;
        require constraint {
            suite.commandResponseLimit <= 300 [ms]
        }
    }

    requirement def FleetAvailabilityRequirement {
        doc /* The fleet coordinator shall maintain sufficient available robots for mission execution or report degraded capability to the operator. */
        subject coordinator : FleetCoordinator;
        require constraint {
            coordinator.minimumFleetAvailability >= 75 [%]
        }
    }

    requirement def RobotRuntimeRequirement {
        doc /* Each robot unit shall support a nominal runtime suitable for extended autonomous inspection missions. */
        subject robot : RobotUnit;
        require constraint {
            robot.nominalRuntime >= 4 [h]
        }
    }

    requirement def SafeHumanProximityRequirement {
        doc /* Robots operating near humans shall reduce commanded speed to a safe value while maintaining obstacle separation. */
        subject supervisor : SafetySupervisor;
        require constraint {
            supervisor.maxAllowedSpeedNearHuman <= 0.5 [m/s] and
            supervisor.safeSeparationDistance >= 1.5 [m]
        }
    }

    satisfy PrimaryFunctionRequirement by RoboticsSuite;
    satisfy SafetyStopRequirement by SafetySupervisor;
    satisfy MissionResponseRequirement by RoboticsSuite;
    satisfy FleetAvailabilityRequirement by FleetCoordinator;
    satisfy RobotRuntimeRequirement by RobotUnit;
    satisfy SafeHumanProximityRequirement by SafetySupervisor;

    part roboticsSuite : RoboticsSuite;
}