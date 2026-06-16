package DegreesOfFreedomSystemModel {
    import ScalarValues::*;

    attribute def Length_m :> Real;
    attribute def Angle_rad :> Real;
    attribute def Velocity_mps :> Real;
    attribute def AngularVelocity_radps :> Real;
    attribute def Acceleration_mps2 :> Real;
    attribute def Force_N :> Real;
    attribute def Torque_Nm :> Real;
    attribute def Power_W :> Real;
    attribute def Voltage_V :> Real;
    attribute def Current_A :> Real;
    attribute def Time_s :> Real;
    attribute def Percent :> Real;

    item def Pose6DOF {
        attribute surge : Length_m;
        attribute sway : Length_m;
        attribute heave : Length_m;
        attribute roll : Angle_rad;
        attribute pitch : Angle_rad;
        attribute yaw : Angle_rad;
    }

    item def Twist6DOF {
        attribute surgeRate : Velocity_mps;
        attribute swayRate : Velocity_mps;
        attribute heaveRate : Velocity_mps;
        attribute rollRate : AngularVelocity_radps;
        attribute pitchRate : AngularVelocity_radps;
        attribute yawRate : AngularVelocity_radps;
    }

    item def Wrench6DOF {
        attribute forceX : Force_N;
        attribute forceY : Force_N;
        attribute forceZ : Force_N;
        attribute torqueRoll : Torque_Nm;
        attribute torquePitch : Torque_Nm;
        attribute torqueYaw : Torque_Nm;
    }

    item def MotionCommand {
        attribute targetPose : Pose6DOF;
        attribute targetVelocity : Twist6DOF;
        attribute maxAcceleration : Acceleration_mps2;
        attribute duration : Time_s;
    }

    item def PlatformStatus {
        attribute actualPose : Pose6DOF;
        attribute actualVelocity : Twist6DOF;
        attribute trackingError : Length_m;
        attribute healthPercent : Percent;
        attribute faultActive : Boolean;
    }

    item def ElectricalPower {
        attribute voltage : Voltage_V;
        attribute current : Current_A;
        attribute power : Power_W;
    }

    port def CommandPort {
        in item command : MotionCommand;
    }

    port def StatusPort {
        out item status : PlatformStatus;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def SensorDataPort {
        out item measuredPose : Pose6DOF;
        out item measuredVelocity : Twist6DOF;
    }

    port def ActuatorDrivePort {
        in item demandedWrench : Wrench6DOF;
        out item deliveredWrench : Wrench6DOF;
    }

    part def SixDegreeOfFreedomMotionPlatform {
        doc /* Primary function: receive a commanded six-degree-of-freedom pose and move a payload in surge, sway, heave, roll, pitch, and yaw while monitoring state, limiting motion, and reporting platform status. */

        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port powerIn : PowerPort;

        part controller : MotionController;
        part estimator : PoseEstimator;
        part safetyManager : SafetyManager;
        part payloadDeck : PayloadDeck;
        part actuatorSet : HexapodActuatorSet;
        part powerUnit : PowerDistributionUnit;
        part inertialSensor : InertialMeasurementUnit;
        part limitSensor : LimitSensorArray;

        connect commandIn to controller.commandIn;
        connect controller.statusOut to statusOut;
        connect powerIn to powerUnit.powerIn;
        connect powerUnit.controllerPower to controller.powerIn;
        connect powerUnit.actuatorPower to actuatorSet.powerIn;

        connect inertialSensor.sensorOut to estimator.imuIn;
        connect limitSensor.sensorOut to safetyManager.limitIn;
        connect estimator.poseOut to controller.feedbackIn;
        connect safetyManager.safeCommandOut to controller.safetyIn;
        connect controller.driveOut to actuatorSet.driveIn;
        connect actuatorSet.wrenchOut to payloadDeck.wrenchIn;
        connect payloadDeck.poseOut to inertialSensor.platformPoseIn;
    }

    part def MotionController {
        port commandIn : CommandPort;
        port feedbackIn : SensorDataPort;
        port safetyIn : CommandPort;
        port driveOut : ActuatorDrivePort;
        port statusOut : StatusPort;
        port powerIn : PowerPort;

        attribute controlCycle : Time_s = 0.002;
        attribute maximumPositionError : Length_m = 0.005;
        attribute maximumAngleError : Angle_rad = 0.003;

        perform action closedLoopControl : TrackSixDOFPose;
    }

    part def PoseEstimator {
        port imuIn : SensorDataPort;
        port poseOut : SensorDataPort;

        attribute filterCycle : Time_s = 0.001;
        attribute poseLatency : Time_s = 0.004;

        perform action estimatePose : FuseMotionMeasurements;
    }

    part def SafetyManager {
        port limitIn : SensorDataPort;
        port safeCommandOut : CommandPort;

        attribute maxSurge : Length_m = 0.35;
        attribute maxSway : Length_m = 0.35;
        attribute maxHeave : Length_m = 0.25;
        attribute maxRoll : Angle_rad = 0.35;
        attribute maxPitch : Angle_rad = 0.35;
        attribute maxYaw : Angle_rad = 0.52;

        perform action enforceMotionEnvelope : LimitSixDOFCommand;
    }

    part def PayloadDeck {
        port wrenchIn : ActuatorDrivePort;
        port poseOut : SensorDataPort;

        attribute payloadMassCapacity : Real = 250.0;
        attribute deckDiameter : Length_m = 1.20;
    }

    part def HexapodActuatorSet {
        port powerIn : PowerPort;
        port driveIn : ActuatorDrivePort;
        port wrenchOut : ActuatorDrivePort;

        part actuator1 : LinearActuator;
        part actuator2 : LinearActuator;
        part actuator3 : LinearActuator;
        part actuator4 : LinearActuator;
        part actuator5 : LinearActuator;
        part actuator6 : LinearActuator;
    }

    part def LinearActuator {
        attribute stroke : Length_m = 0.45;
        attribute peakForce : Force_N = 6500.0;
        attribute continuousForce : Force_N = 3200.0;
        attribute maxSpeed : Velocity_mps = 0.65;
        attribute healthPercent : Percent = 100.0;
    }

    part def PowerDistributionUnit {
        port powerIn : PowerPort;
        port controllerPower : PowerPort;
        port actuatorPower : PowerPort;

        attribute nominalVoltage : Voltage_V = 380.0;
        attribute maximumPower : Power_W = 18000.0;
    }

    part def InertialMeasurementUnit {
        port platformPoseIn : SensorDataPort;
        port sensorOut : SensorDataPort;

        attribute samplePeriod : Time_s = 0.001;
        attribute angularNoise : AngularVelocity_radps = 0.0005;
        attribute linearNoise : Acceleration_mps2 = 0.02;
    }

    part def LimitSensorArray {
        port sensorOut : SensorDataPort;

        attribute sensorCount : Integer = 12;
        attribute responseTime : Time_s = 0.003;
    }

    action def TrackSixDOFPose {
        in item command : MotionCommand;
        in item feedbackPose : Pose6DOF;
        out item demandedWrench : Wrench6DOF;
        out item status : PlatformStatus;

        first start;
        then validateCommand;
        then computePoseError;
        then resolveSixAxisWrench;
        then distributeWrenchToActuators;
        then publishStatus;
    }

    action def FuseMotionMeasurements {
        in item measuredPose : Pose6DOF;
        in item measuredVelocity : Twist6DOF;
        out item estimatedPose : Pose6DOF;
        out item estimatedVelocity : Twist6DOF;

        first sampleSensors;
        then rejectInvalidSamples;
        then updateStateEstimate;
        then outputEstimatedState;
    }

    action def LimitSixDOFCommand {
        in item requestedCommand : MotionCommand;
        out item safeCommand : MotionCommand;

        first inspectRequestedPose;
        then clampSurgeSwayHeave;
        then clampRollPitchYaw;
        then limitAcceleration;
        then issueSafeCommand;
    }

    state def PlatformOperationalState {
        state Off;
        state Initializing;
        state Ready;
        state TrackingCommand;
        state HoldingPose;
        state Faulted;
        state EmergencyStop;

        initial then Off;

        transition powerApplied first Off then Initializing;
        transition initializationComplete first Initializing then Ready;
        transition commandReceived first Ready then TrackingCommand;
        transition targetReached first TrackingCommand then HoldingPose;
        transition newCommand first HoldingPose then TrackingCommand;
        transition faultDetected first Ready then Faulted;
        transition trackingFault first TrackingCommand then Faulted;
        transition holdFault first HoldingPose then Faulted;
        transition emergencyStopPressed first Faulted then EmergencyStop;
        transition resetAccepted first EmergencyStop then Initializing;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide controlled six-degree-of-freedom payload motion in surge, sway, heave, roll, pitch, and yaw from an external motion command. */
    }

    requirement def PoseTrackingRequirement {
        doc /* The system shall track commanded translational pose within 0.005 m and commanded rotational pose within 0.003 rad during normal operation. */
    }

    requirement def MotionEnvelopeRequirement {
        doc /* The system shall constrain commanded motion to plus or minus 0.35 m surge, plus or minus 0.35 m sway, plus or minus 0.25 m heave, plus or minus 0.35 rad roll, plus or minus 0.35 rad pitch, and plus or minus 0.52 rad yaw. */
    }

    requirement def SafetyStopRequirement {
        doc /* The system shall enter EmergencyStop when a hard limit, actuator fault, or external emergency stop is detected. */
    }

    requirement def StatusReportingRequirement {
        doc /* The system shall publish actual pose, velocity, tracking error, health percentage, and active fault state during operation. */
    }

    part sixDOFSystem : SixDegreeOfFreedomMotionPlatform;

    satisfy PrimaryFunctionRequirement by sixDOFSystem;
    satisfy PoseTrackingRequirement by sixDOFSystem.controller;
    satisfy MotionEnvelopeRequirement by sixDOFSystem.safetyManager;
    satisfy SafetyStopRequirement by sixDOFSystem.safetyManager;
    satisfy StatusReportingRequirement by sixDOFSystem.controller;
}