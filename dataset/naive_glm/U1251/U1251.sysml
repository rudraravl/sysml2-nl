package VehicularAutomationSystem {

    value def Distance :> Real { unit "m"; }
    value def Speed :> Real { unit "m/s"; }
    value def Angle :> Real { unit "rad"; }
    value def Acceleration :> Real { unit "m/s^2"; }

    item def RawSensorData;
    item def FusedSensorData;
    item def EnvironmentalModel;
    item def VehiclePose {
        value position : Distance;
        value speed : Speed;
        value heading : Angle;
    }
    item def TrajectoryPlan;
    item def ControlCommand {
        value throttle : Real;
        value brake : Real;
        value steering : Angle;
    }
    item def ActuationCommand;
    item def HazardAlert;
    item def DriverInput;
    item def SystemStatus;

    port def RawSensorOutPort { out item : RawSensorData; }
    port def RawSensorInPort { in item : RawSensorData; }
    port def FusedDataOutPort { out item : FusedSensorData; }
    port def FusedDataInPort { in item : FusedSensorData; }
    port def EnvModelOutPort { out item : EnvironmentalModel; }
    port def EnvModelInPort { in item : EnvironmentalModel; }
    port def PoseOutPort { out item : VehiclePose; }
    port def PoseInPort { in item : VehiclePose; }
    port def TrajectoryOutPort { out item : TrajectoryPlan; }
    port def TrajectoryInPort { in item : TrajectoryPlan; }
    port def ControlOutPort { out item : ControlCommand; }
    port def ControlInPort { in item : ControlCommand; }
    port def ActuationOutPort { out item : ActuationCommand; }
    port def AlertOutPort { out item : HazardAlert; }
    port def AlertInPort { in item : HazardAlert; }
    port def DriverOutPort { out item : DriverInput; }
    port def DriverInPort { in item : DriverInput; }
    port def StatusOutPort { out item : SystemStatus; }
    port def StatusInPort { in item : SystemStatus; }

    connection def RawDataConn connect source::RawSensorOutPort to target::RawSensorInPort;
    connection def FusedDataConn connect source::FusedDataOutPort to target::FusedDataInPort;
    connection def EnvModelConn connect source::EnvModelOutPort to target::EnvModelInPort;
    connection def PoseConn connect source::PoseOutPort to target::PoseInPort;
    connection def TrajectoryConn connect source::TrajectoryOutPort to target::TrajectoryInPort;
    connection def ControlConn connect source::ControlOutPort to target::ControlInPort;
    connection def AlertConn connect source::AlertOutPort to target::AlertInPort;
    connection def DriverConn connect source::DriverOutPort to target::DriverInPort;

    part def SensorSuite {
        out port rawOut : RawSensorOutPort;
    }
    part def SensorFusionModule {
        in port rawIn : RawSensorInPort;
        out port fusedOut : FusedDataOutPort;
    }
    part def PerceptionModule {
        in port fusedIn : FusedDataInPort;
        out port envOut : EnvModelOutPort;
    }
    part def LocalizationModule {
        in port fusedIn : FusedDataInPort;
        out port poseOut : PoseOutPort;
    }
    part def PlanningModule {
        in port envIn : EnvModelInPort;
        in port poseIn : PoseInPort;
        in port driverIn : DriverInPort;
        out port trajOut : TrajectoryOutPort;
    }
    part def ControlModule {
        in port trajIn : TrajectoryInPort;
        in port poseIn : PoseInPort;
        out port cmdOut : ControlOutPort;
    }
    part def ActuationInterface {
        in port cmdIn : ControlInPort;
        out port actOut : ActuationOutPort;
    }
    part def SafetyMonitor {
        in port envIn : EnvModelInPort;
        in port poseIn : PoseInPort;
        out port alertOut : AlertOutPort;
        out port cmdOut : ControlOutPort;
    }
    part def HMI {
        out port driverOut : DriverOutPort;
        in port statusIn : StatusInPort;
        in port alertIn : AlertInPort;
    }

    part def Vehicle {
        part sensors : SensorSuite;
        part fusion : SensorFusionModule;
        part perception : PerceptionModule;
        part localization : LocalizationModule;
        part planning : PlanningModule;
        part control : ControlModule;
        part actuation : ActuationInterface;
        part safety : SafetyMonitor;
        part hmi : HMI;

        connection : RawDataConn connect sensors.rawOut to fusion.rawIn;
        connection : FusedDataConn connect fusion.fusedOut to perception.fusedIn;
        connection : FusedDataConn connect fusion.fusedOut to localization.fusedIn;
        connection : EnvModelConn connect perception.envOut to planning.envIn;
        connection : EnvModelConn connect perception.envOut to safety.envIn;
        connection : PoseConn connect localization.poseOut to planning.poseIn;
        connection : PoseConn connect localization.poseOut to control.poseIn;
        connection : PoseConn connect localization.poseOut to safety.poseIn;
        connection : TrajectoryConn connect planning.trajOut to control.trajIn;
        connection : ControlConn connect control.cmdOut to actuation.cmdIn;
        connection : ControlConn connect safety.cmdOut to actuation.cmdIn;
        connection : AlertConn connect safety.alertOut to hmi.alertIn;
        connection : DriverConn connect hmi.driverOut to planning.driverIn;

        state machine : VehicleStateMachine;
    }

    state def VehicleStateMachine {
        state Inactive;
        state Standby;
        state Active {
            state Cruising;
            state Following;
            state LaneChanging;
            state Stopping;
            transition cruising_to_following first Cruising then Following when vehicle_ahead_detected;
            transition following_to_cruising first Following then Cruising when vehicle_ahead_lost;
            transition cruising_to_lanechanging first Cruising then LaneChanging when lane_change_requested;
            transition lanechanging_to_cruising first LaneChanging then Cruising when lane_change_complete;
            transition cruising_to_stopping first Cruising then Stopping when obstacle_detected;
            transition following_to_stopping first Following then Stopping when obstacle_detected;
            transition lanechanging_to_stopping first LaneChanging then Stopping when obstacle_detected;
            transition stopping_to_cruising first Stopping then Cruising when path_clear;
        }
        transition inactive_to_standby first Inactive then Standby when system_activated;
        transition standby_to_active first Standby then Active when destination_set;
        transition active_to_standby first Active then Standby when destination_reached;
        transition standby_to_inactive first Standby then Inactive when system_deactivated;
    }

    requirement def VehicularAutomationRequirements {
        requirement autonomous_driving {
            doc /* The system shall enable a car to drive itself safely from an origin to a destination. */
        }
        requirement sensor_fusion {
            doc /* The system shall combine raw sensor inputs into a single cohesive picture. */
        }
        requirement perception {
            doc /* The system shall identify obstacles, lane markings, and traffic signals. */
        }
        requirement localization {
            doc /* The system shall determine the vehicle's position, speed, and direction. */
        }
        requirement planning {
            doc /* The system shall plan route, tactical decisions, and short-term trajectory. */
        }
        requirement control {
            doc /* The system shall translate trajectory plans into physical commands. */
        }
        requirement safety_monitor {
            doc /* The system shall detect hazards and trigger emergency braking. */
        }
        requirement hmi {
            doc /* The system shall allow driver to set destination, monitor status, and override. */
        }
    }
}
