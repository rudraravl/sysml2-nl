package SpacecraftAttitudeControlSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;
  import Time::*;

  attribute def Angle {
    :> scalar;
    unit = rad;
  }

  attribute def AngularRate {
    :> scalar;
    unit = rad / s;
  }

  attribute def AngularAcceleration {
    :> scalar;
    unit = rad / s^2;
  }

  attribute def Torque {
    :> scalar;
    unit = N * m;
  }

  attribute def Force {
    :> scalar;
    unit = N;
  }

  attribute def MomentOfInertia {
    :> scalar;
    unit = kg * m^2;
  }

  attribute def ElectricPower {
    :> scalar;
    unit = W;
  }

  attribute def ElectricEnergy {
    :> scalar;
    unit = J;
  }

  attribute def Voltage {
    :> scalar;
    unit = V;
  }

  attribute def Current {
    :> scalar;
    unit = A;
  }

  attribute def MagneticFluxDensity {
    :> scalar;
    unit = T;
  }

  attribute def DataRate {
    :> scalar;
    unit = bit / s;
  }

  attribute def Probability {
    :> scalar;
  }

  attribute def QuaternionComponent {
    :> scalar;
  }

  enum def AttitudeControlMode {
    enum idle;
    enum detumble;
    enum sunPointing;
    enum earthPointing;
    enum inertialPointing;
    enum momentumManagement;
    enum safeHold;
    enum faultIsolation;
  }

  enum def ActuatorCommandState {
    enum disabled;
    enum enabled;
    enum saturated;
    enum failed;
  }

  enum def SensorHealthState {
    enum unavailable;
    enum initializing;
    enum valid;
    enum degraded;
    enum failed;
  }

  enum def FaultSeverity {
    enum advisory;
    enum warning;
    enum critical;
  }

  item def Quaternion {
    attribute q0 : QuaternionComponent;
    attribute q1 : QuaternionComponent;
    attribute q2 : QuaternionComponent;
    attribute q3 : QuaternionComponent;
  }

  item def EulerAngles {
    attribute roll : Angle;
    attribute pitch : Angle;
    attribute yaw : Angle;
  }

  item def BodyRates {
    attribute wx : AngularRate;
    attribute wy : AngularRate;
    attribute wz : AngularRate;
  }

  item def TorqueVector {
    attribute tx : Torque;
    attribute ty : Torque;
    attribute tz : Torque;
  }

  item def MagneticFieldVector {
    attribute bx : MagneticFluxDensity;
    attribute by : MagneticFluxDensity;
    attribute bz : MagneticFluxDensity;
  }

  item def SunVector {
    attribute sx : Real;
    attribute sy : Real;
    attribute sz : Real;
  }

  item def StarCentroidSet {
    attribute centroidCount : Integer;
    attribute confidence : Probability;
  }

  item def GyroSample {
    attribute rates : BodyRates;
    attribute sampleTime : Time;
    attribute noiseStdDev : AngularRate;
  }

  item def AttitudeEstimate {
    attribute quaternion : Quaternion;
    attribute rates : BodyRates;
    attribute covarianceTrace : Real;
    attribute validTime : Time;
  }

  item def AttitudeCommand {
    attribute targetQuaternion : Quaternion;
    attribute targetRates : BodyRates;
    attribute mode : AttitudeControlMode;
    attribute pointingTolerance : Angle;
  }

  item def WheelSpeedCommand {
    attribute wheel1Speed : AngularRate;
    attribute wheel2Speed : AngularRate;
    attribute wheel3Speed : AngularRate;
    attribute wheel4Speed : AngularRate;
  }

  item def ThrusterPulseCommand {
    attribute pulseWidth : Time;
    attribute thrusterId : Integer;
    attribute requestedTorque : TorqueVector;
  }

  item def MagnetorquerCommand {
    attribute dipoleX : Real;
    attribute dipoleY : Real;
    attribute dipoleZ : Real;
  }

  item def FaultReport {
    attribute severity : FaultSeverity;
    attribute code : Integer;
    attribute detectedTime : Time;
  }

  port def PowerPort {
    in item voltage : Voltage;
    in item currentLimit : Current;
    out item consumedPower : ElectricPower;
  }

  port def DataPort {
    in item receivedData;
    out item transmittedData;
    attribute linkRate : DataRate;
  }

  port def AttitudeEstimatePort {
    out item estimate : AttitudeEstimate;
  }

  port def AttitudeCommandPort {
    in item command : AttitudeCommand;
  }

  port def TorqueCommandPort {
    in item commandedTorque : TorqueVector;
  }

  port def TorqueOutputPort {
    out item appliedTorque : TorqueVector;
  }

  port def SensorMeasurementPort {
    out item measurement;
    out item health : SensorHealthState;
  }

  port def FaultPort {
    inout item fault : FaultReport;
  }

  part def SpacecraftAttitudeControlSystem {
    attribute primaryFunction : String = "Determine spacecraft attitude, compare it to mission pointing commands, and generate controlled torques that orient and stabilize the spacecraft body about all three rotational axes.";
    attribute totalDryMass : Mass;
    attribute busVoltage : Voltage = 28[V];
    attribute nominalPowerDraw : ElectricPower = 145[W];
    attribute peakPowerDraw : ElectricPower = 420[W];
    attribute controlCyclePeriod : Time = 0.1[s];
    attribute maxPointingError : Angle = 0.001745[rad];
    attribute maxBodyRateDuringPointing : AngularRate = 0.0008727[rad/s];

    port power : PowerPort;
    port spacecraftBus : DataPort;
    port commandInput : AttitudeCommandPort;
    port faultInterface : FaultPort;

    part sensors : AttitudeSensorSuite;
    part estimator : AttitudeEstimator;
    part controller : AttitudeController;
    part actuators : AttitudeActuatorSuite;
    part faultManager : AttitudeFaultManager;
    part flightModeManager : AttitudeModeManager;

    connect power to sensors.power;
    connect power to estimator.power;
    connect power to controller.power;
    connect power to actuators.power;
    connect power to faultManager.power;
    connect spacecraftBus to estimator.data;
    connect spacecraftBus to controller.data;
    connect spacecraftBus to flightModeManager.data;
    connect commandInput to flightModeManager.commandInput;
    connect sensors.gyroMeasurements to estimator.gyroInput;
    connect sensors.starTrackerMeasurements to estimator.starTrackerInput;
    connect sensors.sunSensorMeasurements to estimator.sunSensorInput;
    connect sensors.magnetometerMeasurements to estimator.magnetometerInput;
    connect estimator.attitudeEstimate to controller.estimatedAttitude;
    connect flightModeManager.modeCommand to controller.attitudeCommand;
    connect controller.wheelCommands to actuators.reactionWheelAssembly.commandInput;
    connect controller.magnetorquerCommands to actuators.magnetorquerAssembly.commandInput;
    connect controller.thrusterCommands to actuators.thrusterAssembly.commandInput;
    connect actuators.netTorqueOutput to estimator.appliedTorqueFeedback;
    connect sensors.faultOutput to faultManager.faultInput;
    connect actuators.faultOutput to faultManager.faultInput;
    connect faultManager.faultOutput to flightModeManager.faultInput;
    connect faultManager.faultOutput to faultInterface;
  }

  part def AttitudeSensorSuite {
    attribute nominalPowerDraw : ElectricPower = 52[W];

    port power : PowerPort;
    port faultOutput : FaultPort;
    port gyroMeasurements : SensorMeasurementPort;
    port starTrackerMeasurements : SensorMeasurementPort;
    port sunSensorMeasurements : SensorMeasurementPort;
    port magnetometerMeasurements : SensorMeasurementPort;

    part gyroA : ThreeAxisGyroscope {
      attribute biasStability = 0.00000485[rad/s];
      attribute samplePeriod = 0.01[s];
    }

    part gyroB : ThreeAxisGyroscope {
      attribute biasStability = 0.00000485[rad/s];
      attribute samplePeriod = 0.01[s];
    }

    part starTrackerA : StarTracker {
      attribute accuracy = 0.0000145[rad];
      attribute updatePeriod = 0.5[s];
    }

    part starTrackerB : StarTracker {
      attribute accuracy = 0.0000145[rad];
      attribute updatePeriod = 0.5[s];
    }

    part coarseSunSensor : CoarseSunSensor {
      attribute accuracy = 0.01745[rad];
      attribute updatePeriod = 0.25[s];
    }

    part magnetometer : ThreeAxisMagnetometer {
      attribute noise = 0.00000005[T];
      attribute updatePeriod = 0.1[s];
    }

    connect power to gyroA.power;
    connect power to gyroB.power;
    connect power to starTrackerA.power;
    connect power to starTrackerB.power;
    connect power to coarseSunSensor.power;
    connect power to magnetometer.power;
  }

  part def ThreeAxisGyroscope {
    attribute biasStability : AngularRate;
    attribute scaleFactorError : Real = 0.0005;
    attribute samplePeriod : Time;
    port power : PowerPort;
    port output : SensorMeasurementPort;
  }

  part def StarTracker {
    attribute accuracy : Angle;
    attribute updatePeriod : Time;
    attribute limitingMagnitude : Real = 6.5;
    attribute fieldOfView : Angle = 0.349[rad];
    port power : PowerPort;
    port output : SensorMeasurementPort;
  }

  part def CoarseSunSensor {
    attribute accuracy : Angle;
    attribute updatePeriod : Time;
    port power : PowerPort;
    port output : SensorMeasurementPort;
  }

  part def ThreeAxisMagnetometer {
    attribute noise : MagneticFluxDensity;
    attribute updatePeriod : Time;
    port power : PowerPort;
    port output : SensorMeasurementPort;
  }

  part def AttitudeEstimator {
    attribute filterCyclePeriod : Time = 0.1[s];
    attribute maximumEstimateAge : Time = 0.25[s];

    port power : PowerPort;
    port data : DataPort;
    port gyroInput : SensorMeasurementPort;
    port starTrackerInput : SensorMeasurementPort;
    port sunSensorInput : SensorMeasurementPort;
    port magnetometerInput : SensorMeasurementPort;
    port appliedTorqueFeedback : TorqueOutputPort;
    port attitudeEstimate : AttitudeEstimatePort;

    action estimateAttitude {
      in item gyro : GyroSample;
      in item starCentroids : StarCentroidSet;
      in item sunVector : SunVector;
      in item magneticField : MagneticFieldVector;
      out item estimate : AttitudeEstimate;

      first start;
      then propagateRates;
      then correctWithStarTracker;
      then correctWithSunAndMagneticField;
      then publishEstimate;
      then done;

      action propagateRates;
      action correctWithStarTracker;
      action correctWithSunAndMagneticField;
      action publishEstimate;
    }
  }

  part def AttitudeController {
    attribute controlCyclePeriod : Time = 0.1[s];
    attribute proportionalGainX : Real = 18.0;
    attribute proportionalGainY : Real = 18.0;
    attribute proportionalGainZ : Real = 12.0;
    attribute derivativeGainX : Real = 220.0;
    attribute derivativeGainY : Real = 220.0;
    attribute derivativeGainZ : Real = 160.0;
    attribute maximumCommandedTorque : Torque = 0.12[N*m];

    port power : PowerPort;
    port data : DataPort;
    port estimatedAttitude : AttitudeEstimatePort;
    port attitudeCommand : AttitudeCommandPort;
    port wheelCommands : DataPort;
    port magnetorquerCommands : DataPort;
    port thrusterCommands : DataPort;

    action computeControlTorque {
      in item estimate : AttitudeEstimate;
      in item command : AttitudeCommand;
      out item requestedTorque : TorqueVector;

      first receiveInputs;
      then computeQuaternionError;
      then computeRateError;
      then applyControlLaw;
      then limitTorque;
      then allocateActuators;
      then done;

      action receiveInputs;
      action computeQuaternionError;
      action computeRateError;
      action applyControlLaw;
      action limitTorque;
      action allocateActuators;
    }
  }

  part def AttitudeActuatorSuite {
    attribute nominalPowerDraw : ElectricPower = 78[W];
    attribute peakPowerDraw : ElectricPower = 310[W];

    port power : PowerPort;
    port faultOutput : FaultPort;
    port netTorqueOutput : TorqueOutputPort;

    part reactionWheelAssembly : ReactionWheelAssembly;
    part magnetorquerAssembly : MagnetorquerAssembly;
    part thrusterAssembly : AttitudeThrusterAssembly;

    connect power to reactionWheelAssembly.power;
    connect power to magnetorquerAssembly.power;
    connect power to thrusterAssembly.power;
  }

  part def ReactionWheelAssembly {
    attribute wheelCount : Integer = 4;
    attribute maximumStoredMomentum : Torque * Time = 24[N*m*s];
    attribute maximumWheelTorque : Torque = 0.08[N*m];

    port power : PowerPort;
    port commandInput : DataPort;
    port torqueOutput : TorqueOutputPort;
    port faultOutput : FaultPort;

    part wheel1 : ReactionWheel;
    part wheel2 : ReactionWheel;
    part wheel3 : ReactionWheel;
    part wheel4 : ReactionWheel;
  }

  part def ReactionWheel {
    attribute maximumSpeed : AngularRate = 628.3[rad/s];
    attribute maximumTorque : Torque = 0.02[N*m];
    attribute inertia : MomentOfInertia = 0.006[kg*m^2];
    attribute commandState : ActuatorCommandState = ActuatorCommandState::enabled;

    port power : PowerPort;
    port torqueOutput : TorqueOutputPort;
  }

  part def MagnetorquerAssembly {
    attribute rodCount : Integer = 3;
    attribute maximumDipoleMoment : Real = 18.0;

    port power : PowerPort;
    port commandInput : DataPort;
    port torqueOutput : TorqueOutputPort;
    port faultOutput : FaultPort;

    part rodX : MagnetorquerRod;
    part rodY : MagnetorquerRod;
    part rodZ : MagnetorquerRod;
  }

  part def MagnetorquerRod {
    attribute maximumDipoleMoment : Real = 18.0;
    attribute coilResistance : Real = 42.0;
    attribute commandState : ActuatorCommandState = ActuatorCommandState::enabled;

    port power : PowerPort;
    port torqueOutput : TorqueOutputPort;
  }

  part def AttitudeThrusterAssembly {
    attribute thrusterCount : Integer = 8;
    attribute minimumImpulseBit : Force * Time = 0.02[N*s];
    attribute maximumPulseWidth : Time = 2.0[s];

    port power : PowerPort;
    port commandInput : DataPort;
    port torqueOutput : TorqueOutputPort;
    port faultOutput : FaultPort;

    part thruster1 : AttitudeThruster;
    part thruster2 : AttitudeThruster;
    part thruster3 : AttitudeThruster;
    part thruster4 : AttitudeThruster;
    part thruster5 : AttitudeThruster;
    part thruster6 : AttitudeThruster;
    part thruster7 : AttitudeThruster;
    part thruster8 : AttitudeThruster;
  }

  part def AttitudeThruster {
    attribute nominalThrust : Force = 0.9[N];
    attribute minimumPulseWidth : Time = 0.02[s];
    attribute valveOpenTime : Time = 0.008[s];
    attribute commandState : ActuatorCommandState = ActuatorCommandState::disabled;

    port power : PowerPort;
    port torqueOutput : TorqueOutputPort;
  }

  part def AttitudeFaultManager {
    attribute sensorTimeoutLimit : Time = 2.0[s];
    attribute wheelSaturationLimit : AngularRate = 596.9[rad/s];
    attribute criticalFaultCountLimit : Integer = 1;

    port power : PowerPort;
    port faultInput : FaultPort;
    port faultOutput : FaultPort;

    action detectAndIsolateFault {
      in item fault : FaultReport;
      out item isolatedFault : FaultReport;

      first classifyFault;
      then selectResponse;
      then publishFault;
      then done;

      action classifyFault;
      action selectResponse;
      action publishFault;
    }
  }

  part def AttitudeModeManager {
    attribute defaultMode : AttitudeControlMode = AttitudeControlMode::safeHold;
    attribute commandedMode : AttitudeControlMode = AttitudeControlMode::idle;

    port data : DataPort;
    port commandInput : AttitudeCommandPort;
    port faultInput : FaultPort;
    port modeCommand : AttitudeCommandPort;

    state machine attitudeModeStateMachine {
      state idle;
      state detumble;
      state sunPointing;
      state earthPointing;
      state inertialPointing;
      state momentumManagement;
      state safeHold;
      state faultIsolation;

      initial then idle;

      transition idle_to_detumble
        first idle
        accept commandInput.command
        if commandInput.command.mode == AttitudeControlMode::detumble
        then detumble;

      transition detumble_to_sunPointing
        first detumble
        accept commandInput.command
        if commandInput.command.mode == AttitudeControlMode::sunPointing
        then sunPointing;

      transition sunPointing_to_earthPointing
        first sunPointing
        accept commandInput.command
        if commandInput.command.mode == AttitudeControlMode::earthPointing
        then earthPointing;

      transition earthPointing_to_inertialPointing
        first earthPointing
        accept commandInput.command
        if commandInput.command.mode == AttitudeControlMode::inertialPointing
        then inertialPointing;

      transition inertialPointing_to_momentumManagement
        first inertialPointing
        accept commandInput.command
        if commandInput.command.mode == AttitudeControlMode::momentumManagement
        then momentumManagement;

      transition momentumManagement_to_inertialPointing
        first momentumManagement
        accept commandInput.command
        if commandInput.command.mode == AttitudeControlMode::inertialPointing
        then inertialPointing;

      transition any_to_safeHold
        first idle
        accept faultInput.fault
        if faultInput.fault.severity == FaultSeverity::warning
        then safeHold;

      transition any_to_faultIsolation
        first safeHold
        accept faultInput.fault
        if faultInput.fault.severity == FaultSeverity::critical
        then faultIsolation;

      transition faultIsolation_to_safeHold
        first faultIsolation
        accept commandInput.command
        if commandInput.command.mode == AttitudeControlMode::safeHold
        then safeHold;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject acs : SpacecraftAttitudeControlSystem;

    require constraint {
      acs.primaryFunction == "Determine spacecraft attitude, compare it to mission pointing commands, and generate controlled torques that orient and stabilize the spacecraft body about all three rotational axes."
    }
  }

  requirement def PointingAccuracyRequirement {
    subject acs : SpacecraftAttitudeControlSystem;

    require constraint {
      acs.maxPointingError <= 0.001745[rad]
    }
  }

  requirement def RateStabilityRequirement {
    subject acs : SpacecraftAttitudeControlSystem;

    require constraint {
      acs.maxBodyRateDuringPointing <= 0.0008727[rad/s]
    }
  }

  requirement def ControlUpdateRequirement {
    subject acs : SpacecraftAttitudeControlSystem;

    require constraint {
      acs.controlCyclePeriod <= 0.1[s]
    }
  }

  requirement def PowerRequirement {
    subject acs : SpacecraftAttitudeControlSystem;

    require constraint {
      acs.peakPowerDraw <= 450[W]
    }
  }

  requirement def SafeHoldRequirement {
    subject manager : AttitudeModeManager;

    require constraint {
      manager.defaultMode == AttitudeControlMode::safeHold
    }
  }

  requirement def SensorRedundancyRequirement {
    subject suite : AttitudeSensorSuite;

    require constraint {
      suite.nominalPowerDraw <= 60[W]
    }
  }

  satisfy PrimaryFunctionRequirement by SpacecraftAttitudeControlSystem;
  satisfy PointingAccuracyRequirement by SpacecraftAttitudeControlSystem;
  satisfy RateStabilityRequirement by SpacecraftAttitudeControlSystem;
  satisfy ControlUpdateRequirement by SpacecraftAttitudeControlSystem;
  satisfy PowerRequirement by SpacecraftAttitudeControlSystem;
  satisfy SafeHoldRequirement by AttitudeModeManager;
  satisfy SensorRedundancyRequirement by AttitudeSensorSuite;

  part spacecraftACS : SpacecraftAttitudeControlSystem {
    attribute totalDryMass = 38[kg];
    attribute nominalPowerDraw = 145[W];
    attribute peakPowerDraw = 420[W];
    attribute controlCyclePeriod = 0.1[s];
    attribute maxPointingError = 0.0012[rad];
    attribute maxBodyRateDuringPointing = 0.0007[rad/s];
  }
}