package 'Autonomous Attitude Control System' {
    private import ScalarValues::*;
    private import ISQ::*;

    item def TargetOrientation {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    item def IMUData {
        attribute rollRate : AngularVelocity;
        attribute pitchRate : AngularVelocity;
        attribute yawRate : AngularVelocity;
    }

    item def StarTrackerData {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    item def AttitudeEstimate {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
        attribute rollRate : AngularVelocity;
        attribute pitchRate : AngularVelocity;
        attribute yawRate : AngularVelocity;
    }

    item def TorqueCommand {
        attribute rollTorque : Torque;
        attribute pitchTorque : Torque;
        attribute yawTorque : Torque;
    }

    port def TargetInputPort { in target : TargetOrientation; }
    port def IMUOutputPort { out imuData : IMUData; }
    port def IMUInputPort { in imuData : IMUData; }
    port def StarTrackerOutputPort { out starTrackerData : StarTrackerData; }
    port def StarTrackerInputPort { in starTrackerData : StarTrackerData; }
    port def TorqueOutputPort { out torqueCommand : TorqueCommand; }
    port def TorqueInputPort { in torqueCommand : TorqueCommand; }

    action def FuseSensorData {
        in imuData : IMUData;
        in starTrackerData : StarTrackerData;
        out estimate : AttitudeEstimate;
    }

    action def ComputeTorqueCommand {
        in target : TargetOrientation;
        in estimate : AttitudeEstimate;
        out torqueCommand : TorqueCommand;
    }

    part def AttitudeController {
        port targetPort : TargetInputPort;
        port imuInputPort : IMUInputPort;
        port starTrackerInputPort : StarTrackerInputPort;
        port torqueOutputPort : TorqueOutputPort;

        attribute newTargetReceived : Boolean = false;
        attribute targetReached : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute faultCleared : Boolean = false;

        action fuseSensors : FuseSensorData;
        action computeTorque : ComputeTorqueCommand;

        state machine controllerStateMachine {
            state Idle;
            state AcquiringTarget;
            state HoldingSteady;
            state SafeMode;

            initial transition to Idle;
            transition from Idle to AcquiringTarget when newTargetReceived;
            transition from AcquiringTarget to HoldingSteady when targetReached;
            transition from HoldingSteady to AcquiringTarget when newTargetReceived;
            transition from Idle to SafeMode when faultDetected;
            transition from AcquiringTarget to SafeMode when faultDetected;
            transition from HoldingSteady to SafeMode when faultDetected;
            transition from SafeMode to Idle when faultCleared;
        }
    }

    part def IMU {
        port imuOutputPort : IMUOutputPort;
    }

    part def StarTracker {
        port starTrackerOutputPort : StarTrackerOutputPort;
    }

    part def ReactionWheel {
        port torqueInputPort : TorqueInputPort;
        attribute axis : String;
        attribute currentSpeed : AngularVelocity;
    }

    part def Spacecraft {
        port targetInputPort : TargetInputPort;

        part attitudeController : AttitudeController;
        part imu : IMU;
        part starTracker : StarTracker;
        part rollWheel : ReactionWheel {
            :>> axis = "roll";
        }
        part pitchWheel : ReactionWheel {
            :>> axis = "pitch";
        }
        part yawWheel : ReactionWheel {
            :>> axis = "yaw";
        }

        bind targetInputPort = attitudeController.targetPort;

        flow imuDataFlow of IMUData
            from imu.imuOutputPort.imuData to attitudeController.imuInputPort.imuData;
        flow starTrackerDataFlow of StarTrackerData
            from starTracker.starTrackerOutputPort.starTrackerData to attitudeController.starTrackerInputPort.starTrackerData;
        flow rollTorqueFlow of TorqueCommand
            from attitudeController.torqueOutputPort.torqueCommand to rollWheel.torqueInputPort.torqueCommand;
        flow pitchTorqueFlow of TorqueCommand
            from attitudeController.torqueOutputPort.torqueCommand to pitchWheel.torqueInputPort.torqueCommand;
        flow yawTorqueFlow of TorqueCommand
            from attitudeController.torqueOutputPort.torqueCommand to yawWheel.torqueInputPort.torqueCommand;
    }

    requirement def PointingAccuracyRequirement {
        attribute maxError : Real = 0.01;
        doc /* The ACS shall maintain pointing accuracy within 0.01 degrees of the target orientation. */
    }

    requirement def StabilityRequirement {
        attribute maxRate : Real = 0.001;
        doc /* The ACS shall maintain angular stability within 0.001 degrees per second during hold mode. */
    }

    requirement def ResponsivenessRequirement {
        attribute maxResponseTime : Real = 60;
        doc /* The ACS shall acquire a new target orientation within 60 seconds. */
    }

    part spacecraft : Spacecraft {
        satisfy PointingAccuracyRequirement;
        satisfy StabilityRequirement;
        satisfy ResponsivenessRequirement;
    }
}
