package AircraftFlapSystemModel {

  attribute def Angle_deg :> ScalarValues::Real;
  attribute def AngularRate_deg_per_s :> ScalarValues::Real;
  attribute def Force_N :> ScalarValues::Real;
  attribute def Torque_Nm :> ScalarValues::Real;
  attribute def Voltage_V :> ScalarValues::Real;
  attribute def Current_A :> ScalarValues::Real;
  attribute def Power_W :> ScalarValues::Real;
  attribute def Time_s :> ScalarValues::Real;
  attribute def Percent :> ScalarValues::Real;
  attribute def Airspeed_kt :> ScalarValues::Real;

  item def FlapCommand {
    attribute commandedAngle : Angle_deg;
    attribute commandRate : AngularRate_deg_per_s;
    attribute inhibit : Boolean;
  }

  item def FlapPositionFeedback {
    attribute measuredAngle : Angle_deg;
    attribute measuredRate : AngularRate_deg_per_s;
    attribute leftRightMismatch : Angle_deg;
    attribute valid : Boolean;
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute currentLimit : Current_A;
    attribute availablePower : Power_W;
  }

  item def MechanicalTorque {
    attribute torque : Torque_Nm;
    attribute shaftSpeed : AngularRate_deg_per_s;
  }

  item def AerodynamicLoad {
    attribute normalForce : Force_N;
    attribute hingeMoment : Torque_Nm;
    attribute airspeed : Airspeed_kt;
  }

  port def CommandPort {
    in item command : FlapCommand;
  }

  port def FeedbackPort {
    out item feedback : FlapPositionFeedback;
  }

  port def ElectricalPowerPort {
    in item power : ElectricalPower;
  }

  port def TorquePort {
    out item torqueFlow : MechanicalTorque;
  }

  port def LoadPort {
    in item load : AerodynamicLoad;
  }

  part def FlapPanel {
    attribute surfaceArea_m2 : ScalarValues::Real = 3.2;
    attribute chord_m : ScalarValues::Real = 0.85;
    attribute span_m : ScalarValues::Real = 3.75;
    attribute deflectionAngle : Angle_deg;
    attribute maxDeflection : Angle_deg = 40.0;
    attribute minDeflection : Angle_deg = 0.0;

    port hingeLoadPort : LoadPort;
    port positionPort : FeedbackPort;
  }

  part def HingeAssembly {
    attribute hingeFrictionTorque : Torque_Nm = 18.0;
    attribute allowableHingeMoment : Torque_Nm = 4200.0;

    port aerodynamicLoadIn : LoadPort;
    port driveTorqueIn : TorquePort;
  }

  part def RotaryActuator {
    attribute ratedTorque : Torque_Nm = 5100.0;
    attribute stallTorque : Torque_Nm = 6800.0;
    attribute maxRate : AngularRate_deg_per_s = 8.0;
    attribute healthPercent : Percent = 100.0;

    port powerIn : ElectricalPowerPort;
    port torqueOut : TorquePort;
  }

  part def PositionSensor {
    attribute resolution : Angle_deg = 0.05;
    attribute accuracy : Angle_deg = 0.15;
    attribute samplePeriod : Time_s = 0.02;

    port measuredPositionOut : FeedbackPort;
  }

  part def FlapControlUnit {
    attribute selectedAngle : Angle_deg;
    attribute rateLimit : AngularRate_deg_per_s = 5.0;
    attribute positionTolerance : Angle_deg = 0.5;
    attribute faultLatched : Boolean = false;

    port pilotCommandIn : CommandPort;
    port sensorFeedbackIn : FeedbackPort;
    port actuatorPowerOut : ElectricalPowerPort;
    port systemFeedbackOut : FeedbackPort;
  }

  action def ValidateFlapCommand {
    in command : FlapCommand;
    in currentAirspeed : Airspeed_kt;
    out accepted : Boolean;

    constraint safeCommand {
      command.commandedAngle >= 0.0 and
      command.commandedAngle <= 40.0 and
      not command.inhibit and
      currentAirspeed <= 230.0
    }
  }

  action def DriveFlapToPosition {
    in targetAngle : Angle_deg;
    in currentAngle : Angle_deg;
    in rateLimit : AngularRate_deg_per_s;
    out motorTorque : Torque_Nm;
    out achievedAngle : Angle_deg;

    constraint commandedMotion {
      achievedAngle >= 0.0 and achievedAngle <= 40.0
    }
  }

  action def HoldFlapPosition {
    in commandedAngle : Angle_deg;
    in measuredAngle : Angle_deg;
    out holdingTorque : Torque_Nm;

    constraint holdTolerance {
      abs(commandedAngle - measuredAngle) <= 0.5
    }
  }

  state def FlapOperatingStateMachine {
    attribute commandedAngle : Angle_deg;
    attribute measuredAngle : Angle_deg;
    attribute airspeed : Airspeed_kt;
    attribute faultPresent : Boolean;

    state Stowed;
    state Extending;
    state Holding;
    state Retracting;
    state FaultLocked;

    transition initial then Stowed;

    transition Stowed_to_Extending
      first Stowed
      accept FlapCommand
      if commandedAngle > measuredAngle and airspeed <= 230.0
      then Extending;

    transition Extending_to_Holding
      first Extending
      if abs(commandedAngle - measuredAngle) <= 0.5
      then Holding;

    transition Holding_to_Retracting
      first Holding
      accept FlapCommand
      if commandedAngle < measuredAngle
      then Retracting;

    transition Retracting_to_Stowed
      first Retracting
      if measuredAngle <= 0.5
      then Stowed;

    transition Any_to_FaultLocked
      accept FlapPositionFeedback
      if faultPresent
      then FaultLocked;
  }

  part def AircraftFlapSystem {
    doc /* Primary function: change the wing trailing-edge flap deflection to increase lift and drag at low airspeeds, supporting takeoff, approach, and landing while maintaining commanded position and reporting system status. */

    attribute commandedDeflection : Angle_deg;
    attribute actualDeflection : Angle_deg;
    attribute allowableDeflection : Angle_deg = 40.0;
    attribute deploymentTimeLimit : Time_s = 12.0;

    port flightDeckCommand : CommandPort;
    port aircraftPower : ElectricalPowerPort;
    port aerodynamicLoad : LoadPort;
    port flapStatus : FeedbackPort;

    part controller : FlapControlUnit;
    part actuator : RotaryActuator;
    part hinge : HingeAssembly;
    part flapPanel : FlapPanel;
    part sensor : PositionSensor;
    part operatingLogic : FlapOperatingStateMachine;

    connection commandConnection connect flightDeckCommand to controller.pilotCommandIn;
    connection powerConnection connect aircraftPower to actuator.powerIn;
    connection actuatorDrive connect actuator.torqueOut to hinge.driveTorqueIn;
    connection hingeLoad connect aerodynamicLoad to hinge.aerodynamicLoadIn;
    connection panelLoad connect aerodynamicLoad to flapPanel.hingeLoadPort;
    connection sensorToController connect sensor.measuredPositionOut to controller.sensorFeedbackIn;
    connection panelToSensor connect flapPanel.positionPort to sensor.measuredPositionOut;
    connection feedbackConnection connect controller.systemFeedbackOut to flapStatus;

    perform action validateCommand : ValidateFlapCommand;
    perform action driveToPosition : DriveFlapToPosition;
    perform action holdPosition : HoldFlapPosition;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The flap system shall provide controlled trailing-edge flap deflection to modify wing lift and drag for low-speed flight phases. */
    subject system : AircraftFlapSystem;

    require constraint primaryFunction {
      system.actualDeflection >= 0.0 and
      system.actualDeflection <= system.allowableDeflection
    }
  }

  requirement def PositionAccuracyRequirement {
    subject system : AircraftFlapSystem;

    require constraint positionAccuracy {
      abs(system.commandedDeflection - system.actualDeflection) <= 0.5
    }
  }

  requirement def DeploymentTimeRequirement {
    subject system : AircraftFlapSystem;

    require constraint deploymentTime {
      system.deploymentTimeLimit <= 12.0
    }
  }

  requirement def FailSafeRequirement {
    subject system : AircraftFlapSystem;

    require constraint failSafeLimits {
      system.actualDeflection >= 0.0 and
      system.actualDeflection <= 40.0
    }
  }

  satisfy PrimaryFunctionRequirement by AircraftFlapSystem;
  satisfy PositionAccuracyRequirement by AircraftFlapSystem;
  satisfy DeploymentTimeRequirement by AircraftFlapSystem;
  satisfy FailSafeRequirement by AircraftFlapSystem;
}