package ActuatorBasedSystemModel {
  attribute def Voltage :> Real { doc /* volts */ }
  attribute def Current :> Real { doc /* amperes */ }
  attribute def Power :> Real { doc /* watts */ }
  attribute def Torque :> Real { doc /* newton meters */ }
  attribute def Angle :> Real { doc /* degrees */ }
  attribute def AngularRate :> Real { doc /* degrees per second */ }
  attribute def Temperature :> Real { doc /* degrees Celsius */ }
  attribute def Time :> Real { doc /* seconds */ }

  item def ElectricalPower {
    attribute voltage : Voltage;
    attribute current : Current;
    attribute availablePower : Power;
  }

  item def MotionCommand {
    attribute targetPosition : Angle;
    attribute maxRate : AngularRate;
    attribute enable : Boolean;
  }

  item def MechanicalMotion {
    attribute position : Angle;
    attribute rate : AngularRate;
    attribute outputTorque : Torque;
  }

  item def PositionFeedback {
    attribute measuredPosition : Angle;
    attribute measuredRate : AngularRate;
    attribute valid : Boolean;
  }

  item def ThermalStatus {
    attribute windingTemperature : Temperature;
    attribute electronicsTemperature : Temperature;
  }

  port def PowerInputPort {
    in item electricalPower : ElectricalPower;
  }

  port def CommandInputPort {
    in item command : MotionCommand;
  }

  port def MotionOutputPort {
    out item motion : MechanicalMotion;
  }

  port def FeedbackOutputPort {
    out item feedback : PositionFeedback;
  }

  port def ThermalOutputPort {
    out item thermalStatus : ThermalStatus;
  }

  part def ControlElectronics {
    port commandIn : CommandInputPort;
    port feedbackIn : FeedbackOutputPort;
    port driveCommandOut : CommandInputPort;

    attribute controlLoopPeriod : Time = 0.005;
    attribute positionTolerance : Angle = 0.5;
  }

  part def PowerConditioner {
    port rawPowerIn : PowerInputPort;
    port regulatedPowerOut : PowerInputPort;

    attribute nominalVoltage : Voltage = 28.0;
    attribute maxContinuousPower : Power = 240.0;
  }

  part def ElectricMotor {
    port powerIn : PowerInputPort;
    port commandIn : CommandInputPort;
    port shaftOut : MotionOutputPort;
    port thermalOut : ThermalOutputPort;

    attribute ratedTorque : Torque = 12.0;
    attribute peakTorque : Torque = 24.0;
    attribute maxSpeed : AngularRate = 180.0;
  }

  part def GearTrain {
    port motorShaftIn : MotionOutputPort;
    port loadShaftOut : MotionOutputPort;

    attribute gearRatio : Real = 50.0;
    attribute efficiency : Real = 0.88;
  }

  part def PositionSensor {
    port motionIn : MotionOutputPort;
    port feedbackOut : FeedbackOutputPort;

    attribute resolution : Angle = 0.05;
    attribute samplePeriod : Time = 0.002;
  }

  part def DrivenLoad {
    port motionIn : MotionOutputPort;

    attribute requiredTorque : Torque = 8.0;
    attribute allowedTravelMin : Angle = -45.0;
    attribute allowedTravelMax : Angle = 45.0;
  }

  part def Actuator {
    port powerIn : PowerInputPort;
    port commandIn : CommandInputPort;
    port motionOut : MotionOutputPort;
    port feedbackOut : FeedbackOutputPort;
    port thermalOut : ThermalOutputPort;

    part motor : ElectricMotor;
    part gearTrain : GearTrain;
    part sensor : PositionSensor;

    connect commandIn to motor.commandIn;
    connect powerIn to motor.powerIn;
    connect motor.shaftOut to gearTrain.motorShaftIn;
    connect gearTrain.loadShaftOut to motionOut;
    connect gearTrain.loadShaftOut to sensor.motionIn;
    connect sensor.feedbackOut to feedbackOut;
    connect motor.thermalOut to thermalOut;

    action performPrimaryFunction {
      in item requestedMotion : MotionCommand;
      in item suppliedPower : ElectricalPower;
      out item deliveredMotion : MechanicalMotion;

      first start;
      then validateCommand;
      then energizeMotor;
      then convertElectricalEnergyToTorque;
      then reduceSpeedAndAmplifyTorque;
      then positionLoad;
      then reportFeedback;
      then done;
    }

    state actuatorState {
      state Off;
      state Standby;
      state Moving;
      state Holding;
      state Fault;

      transition initial then Off;
      transition Off_to_Standby
        first Off
        accept MotionCommand
        if command.enable
        then Standby;

      transition Standby_to_Moving
        first Standby
        accept MotionCommand
        if command.enable
        then Moving;

      transition Moving_to_Holding
        first Moving
        if abs(feedbackOut.feedback.measuredPosition - commandIn.command.targetPosition) <= 0.5
        then Holding;

      transition Holding_to_Moving
        first Holding
        accept MotionCommand
        if abs(feedbackOut.feedback.measuredPosition - commandIn.command.targetPosition) > 0.5
        then Moving;

      transition Any_to_Fault
        first Off
        then Fault
        if thermalOut.thermalStatus.windingTemperature > 120.0;

      transition Fault_to_Off
        first Fault
        accept MotionCommand
        if not command.enable
        then Off;
    }
  }

  part def ActuatorBasedSystem {
    port externalPowerIn : PowerInputPort;
    port operatorCommandIn : CommandInputPort;
    port mechanicalInterfaceOut : MotionOutputPort;
    port systemFeedbackOut : FeedbackOutputPort;
    port systemThermalOut : ThermalOutputPort;

    part controller : ControlElectronics;
    part powerConditioner : PowerConditioner;
    part actuator : Actuator;
    part load : DrivenLoad;

    connect externalPowerIn to powerConditioner.rawPowerIn;
    connect powerConditioner.regulatedPowerOut to actuator.powerIn;
    connect operatorCommandIn to controller.commandIn;
    connect controller.driveCommandOut to actuator.commandIn;
    connect actuator.motionOut to load.motionIn;
    connect actuator.motionOut to mechanicalInterfaceOut;
    connect actuator.feedbackOut to controller.feedbackIn;
    connect actuator.feedbackOut to systemFeedbackOut;
    connect actuator.thermalOut to systemThermalOut;

    action primaryFunction {
      in item operatorRequest : MotionCommand;
      out item controlledMechanicalMotion : MechanicalMotion;

      first receiveOperatorCommand;
      then regulateInputPower;
      then commandActuator;
      then convertPowerAndCommandToMotion;
      then moveDrivenLoad;
      then publishPositionFeedback;
      then done;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : ActuatorBasedSystem;

    doc /* The actuator-based system shall convert electrical power and a commanded position into controlled mechanical motion at the mechanical interface. */
  }

  requirement def PositionControlRequirement {
    subject system : ActuatorBasedSystem;

    require constraint {
      abs(system.systemFeedbackOut.feedback.measuredPosition - system.operatorCommandIn.command.targetPosition) <= 0.5
    }
  }

  requirement def TorqueRequirement {
    subject system : ActuatorBasedSystem;

    require constraint {
      system.mechanicalInterfaceOut.motion.outputTorque >= system.load.requiredTorque
    }
  }

  requirement def TravelLimitRequirement {
    subject system : ActuatorBasedSystem;

    require constraint {
      system.mechanicalInterfaceOut.motion.position >= system.load.allowedTravelMin and
      system.mechanicalInterfaceOut.motion.position <= system.load.allowedTravelMax
    }
  }

  requirement def ThermalProtectionRequirement {
    subject system : ActuatorBasedSystem;

    require constraint {
      system.systemThermalOut.thermalStatus.windingTemperature <= 120.0
    }
  }

  part actuatorMotionSystem : ActuatorBasedSystem;
}