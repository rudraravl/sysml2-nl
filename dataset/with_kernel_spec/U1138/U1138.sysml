package MotionPlanningSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def Point2D {
        attribute x :> ISQ::length;
        attribute y :> ISQ::length;
    }

    attribute def Pose2D :> Point2D {
        attribute heading :> ISQ::angle;
    }

    attribute def Velocity2D {
        attribute vx :> ISQ::speed;
        attribute vy :> ISQ::speed;
    }

    attribute def Obstacle {
        attribute position : Pose2D;
        attribute size :> ISQ::length;
        attribute velocity : Velocity2D;
    }

    attribute def EnvironmentMap {
        attribute obstacles : Obstacle[*];
        attribute boundary : Point2D[4];
    }

    attribute def VehicleState {
        attribute pose : Pose2D;
        attribute speed :> ISQ::speed;
    }

    attribute def GlobalPath {
        attribute waypoints : Pose2D[*];
    }

    attribute def LocalTrajectory {
        attribute points : Pose2D[*];
        attribute velocities : ISQ::speed[*];
    }

    attribute def ControlCommand {
        attribute velocity :> ISQ::speed;
        attribute steering :> ISQ::angle;
    }

    port def EnvironmentMapPort {
        attribute environmentMap : EnvironmentMap;
    }
    port def VehicleStatePort {
        attribute vehicleState : VehicleState;
    }
    port def PosePort {
        attribute pose : Pose2D;
    }
    port def GlobalPathPort {
        attribute globalPath : GlobalPath;
    }
    port def LocalTrajectoryPort {
        attribute localTrajectory : LocalTrajectory;
    }
    port def ControlCommandPort {
        attribute controlCommand : ControlCommand;
    }

    action def PerceiveEnvironment {
        out environmentMap : EnvironmentMap;
    }

    action def LocalizeVehicle {
        out vehicleState : VehicleState;
    }

    action def PlanGlobalPath {
        in environmentMap : EnvironmentMap;
        in vehicleState : VehicleState;
        in goal : Pose2D;
        out globalPath : GlobalPath;
    }

    action def PlanLocalTrajectory {
        in environmentMap : EnvironmentMap;
        in vehicleState : VehicleState;
        in globalPath : GlobalPath;
        out localTrajectory : LocalTrajectory;
    }

    action def ComputeControl {
        in localTrajectory : LocalTrajectory;
        in vehicleState : VehicleState;
        out controlCommand : ControlCommand;
    }

    part def PerceptionSubsystem {
        out port environmentMapOut : EnvironmentMapPort;
        perform action perceive : PerceiveEnvironment;
        connect perceive.environmentMap to environmentMapOut.environmentMap;
    }

    part def LocalizationSubsystem {
        out port vehicleStateOut : VehicleStatePort;
        perform action localize : LocalizeVehicle;
        connect localize.vehicleState to vehicleStateOut.vehicleState;
    }

    part def GlobalPlannerSubsystem {
        in port environmentMapIn : EnvironmentMapPort;
        in port vehicleStateIn : VehicleStatePort;
        in port goalIn : PosePort;
        out port globalPathOut : GlobalPathPort;
        perform action planGlobal : PlanGlobalPath;
        connect environmentMapIn.environmentMap to planGlobal.environmentMap;
        connect vehicleStateIn.vehicleState to planGlobal.vehicleState;
        connect goalIn.pose to planGlobal.goal;
        connect planGlobal.globalPath to globalPathOut.globalPath;
    }

    part def LocalPlannerSubsystem {
        in port environmentMapIn : EnvironmentMapPort;
        in port vehicleStateIn : VehicleStatePort;
        in port globalPathIn : GlobalPathPort;
        out port localTrajectoryOut : LocalTrajectoryPort;
        perform action planLocal : PlanLocalTrajectory;
        connect environmentMapIn.environmentMap to planLocal.environmentMap;
        connect vehicleStateIn.vehicleState to planLocal.vehicleState;
        connect globalPathIn.globalPath to planLocal.globalPath;
        connect planLocal.localTrajectory to localTrajectoryOut.localTrajectory;
    }

    part def ControllerSubsystem {
        in port localTrajectoryIn : LocalTrajectoryPort;
        in port vehicleStateIn : VehicleStatePort;
        out port controlCommandOut : ControlCommandPort;
        perform action computeControl : ComputeControl;
        connect localTrajectoryIn.localTrajectory to computeControl.localTrajectory;
        connect vehicleStateIn.vehicleState to computeControl.vehicleState;
        connect computeControl.controlCommand to controlCommandOut.controlCommand;
    }

    requirement def MotionConstraints {
        doc /* Physical and safety constraints for the motion planning system */
        attribute maxSpeed :> ISQ::speed = 2.0 [m/s];
        attribute maxAcceleration :> ISQ::acceleration = 1.0 [m/s^2];
        attribute minTurningRadius :> ISQ::length = 0.5 [m];
        attribute safetyMargin :> ISQ::length = 0.3 [m];
        constraint { maxSpeed <= 2.0 [m/s] }
        constraint { maxAcceleration <= 1.0 [m/s^2] }
        constraint { minTurningRadius >= 0.5 [m] }
        constraint { safetyMargin >= 0.3 [m] }
    }

    part def AutonomousVehicle {
        attribute maxSpeed :> ISQ::speed = 2.0 [m/s];
        attribute maxAcceleration :> ISQ::acceleration = 1.0 [m/s^2];
        attribute minTurningRadius :> ISQ::length = 0.5 [m];
        attribute safetyMargin :> ISQ::length = 0.3 [m];

        part perception : PerceptionSubsystem;
        part localization : LocalizationSubsystem;
        part globalPlanner : GlobalPlannerSubsystem;
        part localPlanner : LocalPlannerSubsystem;
        part controller : ControllerSubsystem;

        in port goalIn : PosePort;
        out port controlCommandOut : ControlCommandPort;

        connect perception.environmentMapOut to globalPlanner.environmentMapIn;
        connect perception.environmentMapOut to localPlanner.environmentMapIn;
        connect localization.vehicleStateOut to globalPlanner.vehicleStateIn;
        connect localization.vehicleStateOut to localPlanner.vehicleStateIn;
        connect localization.vehicleStateOut to controller.vehicleStateIn;
        connect goalIn to globalPlanner.goalIn;
        connect globalPlanner.globalPathOut to localPlanner.globalPathIn;
        connect localPlanner.localTrajectoryOut to controller.localTrajectoryIn;
        connect controller.controlCommandOut to controlCommandOut;

        requirement motionConstraints : MotionConstraints;
        satisfy motionConstraints;
    }
}
