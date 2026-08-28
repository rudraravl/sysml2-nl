package SpacecraftACS {
    import ScalarValues::*;

    // Value Types
    type def AngleValue :> Real;
    type def AngularRateValue :> Real;
    type def TorqueValue :> Real;
    type def WheelSpeedValue :> Real;

    // Item Definitions
    item def AttitudeCommand {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def AttitudeEstimate {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def AngularRateData {
        attribute rollRate : AngularRateValue;
        attribute pitchRate : AngularRateValue;
        attribute yawRate : AngularRateValue;
    }

    item def StarTrackerData {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def SingleWheelCommand {
        attribute torque : TorqueValue;
    }

    // Port Definitions
    port def CommandPort {
        out item : AttitudeCommand;
    }

    port def IMUPort {
        out item : AngularRateData;
    }

    port def StarTrackerPort {
        out item : StarTrackerData;
    }

    port def EstimatePort {
        out item : AttitudeEstimate;
    }

    port def WheelCommandPort {
        out item : SingleWheelCommand;
    }

    // Part Definitions
    part def IMU {
        port imuOut : IMUPort;
        attribute samplingRate : Real = 100;
    }

    part def StarTracker {
        port stOut : StarTrackerPort;
        attribute updateRate : Real = 5;
    }

    part def ReactionWheel {
        port cmdIn : WheelCommandPort;
        attribute currentSpeed : WheelSpeedValue;
    }

    part def AttitudeController {
        port cmdIn : CommandPort;
        port imuIn : IMUPort;
        port stIn : StarTrackerPort;
        port estimateOut : EstimatePort;
        port rollWheelCmdOut : WheelCommandPort;
        port pitchWheelCmdOut : WheelCommandPort;
        port yawWheelCmdOut : WheelCommandPort;

        state machine ControllerBehavior {
            state Acquiring;
            state Holding;
            state SafeMode;

            transition initial to Acquiring;
            transition Acquiring_to_Holding
                from Acquiring to Holding
                when { true } // Condition: attitude error < threshold
            transition to_SafeMode
                from Acquiring | Holding to SafeMode
                when { false } // Condition: fault detected
            transition SafeMode_to_Acquiring
                from SafeMode to Acquiring
                when { false } // Condition: fault cleared
        }
    }

    part def SpacecraftACS {
        part controller : AttitudeController;
        part imu : IMU;
        part starTracker : StarTracker;
        part rollWheel : ReactionWheel;
        part pitchWheel : ReactionWheel;
        part yawWheel : ReactionWheel;

        port extCmdIn : CommandPort;
        port extEstimateOut : EstimatePort;

        connect extCmdIn to controller.cmdIn;
        connect imu.imuOut to controller.imuIn;
        connect starTracker.stOut to controller.stIn;
        connect controller.rollWheelCmdOut to rollWheel.cmdIn;
        connect controller.pitchWheelCmdOut to pitchWheel.cmdIn;
        connect controller.yawWheelCmdOut to yawWheel.cmdIn;
        connect controller.estimateOut to extEstimateOut;
    }

    // Requirements
    requirement def PointingAccuracyRequirement {
        doc /* The ACS shall maintain pointing accuracy within 0.01 degrees. */
    }

    requirement def StabilityRequirement {
        doc /* The ACS shall maintain stability within 0.001 deg/s. */
    }

    requirement def ResponsivenessRequirement {
        doc /* The ACS shall achieve target orientation within 30 seconds. */
    }

    requirement acsRequirements {
        subject acs : SpacecraftACS;
        requirement pointingAccuracy : PointingAccuracyRequirement;
        requirement stability : StabilityRequirement;
        requirement responsiveness : ResponsivenessRequirement;
    }
}
