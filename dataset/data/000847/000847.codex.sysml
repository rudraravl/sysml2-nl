package ArtificioDeJuaneloModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Length;
  attribute def Height specializes Length;
  attribute def Volume;
  attribute def Mass;
  attribute def Time;
  attribute def FlowRate;
  attribute def Torque;
  attribute def RotationalSpeed;
  attribute def Force;
  attribute def Efficiency;
  attribute def Power;
  attribute def Angle;

  item def Water {
    attribute volume : Volume;
    attribute mass : Mass;
  }

  item def MechanicalMotion {
    attribute torque : Torque;
    attribute speed : RotationalSpeed;
    attribute power : Power;
  }

  item def ControlSignal {
    attribute command : String;
  }

  port def WaterPort {
    inout item water : Water;
  }

  port def MotionPort {
    inout item motion : MechanicalMotion;
  }

  port def SignalPort {
    inout item signal : ControlSignal;
  }

  part def RiverIntake {
    attribute sourceElevation : Height;
    attribute inletFlowCapacity : FlowRate;
    port outlet : WaterPort;
  }

  part def WaterWheel {
    attribute wheelDiameter : Length;
    attribute nominalSpeed : RotationalSpeed;
    attribute hydraulicEfficiency : Efficiency;
    port waterIn : WaterPort;
    port waterOut : WaterPort;
    port rotaryOutput : MotionPort;
  }

  part def DriveShaft {
    attribute length : Length;
    attribute transmittedTorque : Torque;
    port input : MotionPort;
    port output : MotionPort;
  }

  part def CrankAssembly {
    attribute crankRadius : Length;
    attribute strokeAngle : Angle;
    port rotaryInput : MotionPort;
    port reciprocatingOutput : MotionPort;
  }

  part def LiftingFrame {
    attribute frameHeight : Height;
    attribute numberOfStages : Integer;
    port lowerMotion : MotionPort;
    port upperMotion : MotionPort;
  }

  part def OscillatingArm {
    attribute armLength : Length;
    attribute pivotHeight : Height;
    attribute strokeAmplitude : Length;
    port driveInput : MotionPort;
    port bucketCoupling : MotionPort;
  }

  part def Bucket {
    attribute capacity : Volume;
    attribute filledVolume : Volume;
    attribute emptyMass : Mass;
    port inlet : WaterPort;
    port outlet : WaterPort;
    port motionInput : MotionPort;
  }

  part def TransferTrough {
    attribute troughLength : Length;
    attribute slope : Real;
    attribute storageVolume : Volume;
    port inlet : WaterPort;
    port outlet : WaterPort;
  }

  part def Stage {
    attribute liftHeight : Height;
    attribute stageIndex : Integer;
    part arm : OscillatingArm;
    part bucket : Bucket;
    part trough : TransferTrough;
    port waterIn : WaterPort;
    port waterOut : WaterPort;
    port motionIn : MotionPort;

    connect motionIn to arm.driveInput;
    connect arm.bucketCoupling to bucket.motionInput;
    connect waterIn to bucket.inlet;
    connect bucket.outlet to trough.inlet;
    connect trough.outlet to waterOut;
  }

  part def DeliveryReservoir {
    attribute reservoirElevation : Height;
    attribute usableVolume : Volume;
    attribute currentVolume : Volume;
    port inlet : WaterPort;
    port outlet : WaterPort;
  }

  part def AlcazarSupplyOutlet {
    attribute requiredElevation : Height;
    attribute demandFlow : FlowRate;
    port inlet : WaterPort;
  }

  part def Governor {
    attribute minimumWheelSpeed : RotationalSpeed;
    attribute maximumWheelSpeed : RotationalSpeed;
    port speedFeedback : MotionPort;
    port commandOut : SignalPort;
  }

  action def CaptureRiverWater {
    in source : Water;
    out captured : Water;
  }

  action def ConvertHydraulicEnergy {
    in fallingWater : Water;
    out rotation : MechanicalMotion;
  }

  action def TransmitMotion {
    in inputMotion : MechanicalMotion;
    out outputMotion : MechanicalMotion;
  }

  action def OscillateArm {
    in crankMotion : MechanicalMotion;
    out reciprocatingMotion : MechanicalMotion;
  }

  action def FillBucket {
    in availableWater : Water;
    out loadedBucketWater : Water;
  }

  action def RaiseBucket {
    in loadedBucketWater : Water;
    in liftMotion : MechanicalMotion;
    out raisedWater : Water;
  }

  action def EmptyBucketToTrough {
    in raisedWater : Water;
    out transferredWater : Water;
  }

  action def DeliverWaterToReservoir {
    in stageOutputWater : Water;
    out storedWater : Water;
  }

  state def ArtificioOperatingState {
    entry action initialize;
    state Idle;
    state IntakePrimed;
    state WheelTurning;
    state SequentialLifting;
    state Delivering;
    state Stopped;

    transition first Idle;
    transition Idle_to_IntakePrimed
      first Idle then IntakePrimed
      accept ControlSignal;
    transition IntakePrimed_to_WheelTurning
      first IntakePrimed then WheelTurning;
    transition WheelTurning_to_SequentialLifting
      first WheelTurning then SequentialLifting;
    transition SequentialLifting_to_Delivering
      first SequentialLifting then Delivering;
    transition Delivering_to_SequentialLifting
      first Delivering then SequentialLifting;
    transition Any_to_Stopped
      first SequentialLifting then Stopped
      accept ControlSignal;
  }

  part def ArtificioDeJuanelo {
    attribute primaryFunction : String = "Lift water from the Tagus River to the high elevation supply point at the Alcazar of Toledo using water-powered mechanical motion and staged reciprocating buckets.";
    attribute totalLiftHeight : Height;
    attribute nominalDeliveryFlow : FlowRate;
    attribute overallEfficiency : Efficiency;

    part intake : RiverIntake {
      attribute sourceElevation = 0.0;
      attribute inletFlowCapacity = 0.035;
    }

    part wheel : WaterWheel {
      attribute wheelDiameter = 5.0;
      attribute nominalSpeed = 3.0;
      attribute hydraulicEfficiency = 0.42;
    }

    part shaft : DriveShaft {
      attribute length = 12.0;
      attribute transmittedTorque = 1800.0;
    }

    part crank : CrankAssembly {
      attribute crankRadius = 0.45;
      attribute strokeAngle = 180.0;
    }

    part frame : LiftingFrame {
      attribute frameHeight = 96.0;
      attribute numberOfStages = 8;
    }

    part stage1 : Stage {
      attribute liftHeight = 12.0;
      attribute stageIndex = 1;
    }

    part stage2 : Stage {
      attribute liftHeight = 12.0;
      attribute stageIndex = 2;
    }

    part stage3 : Stage {
      attribute liftHeight = 12.0;
      attribute stageIndex = 3;
    }

    part stage4 : Stage {
      attribute liftHeight = 12.0;
      attribute stageIndex = 4;
    }

    part stage5 : Stage {
      attribute liftHeight = 12.0;
      attribute stageIndex = 5;
    }

    part stage6 : Stage {
      attribute liftHeight = 12.0;
      attribute stageIndex = 6;
    }

    part stage7 : Stage {
      attribute liftHeight = 12.0;
      attribute stageIndex = 7;
    }

    part stage8 : Stage {
      attribute liftHeight = 12.0;
      attribute stageIndex = 8;
    }

    part reservoir : DeliveryReservoir {
      attribute reservoirElevation = 96.0;
      attribute usableVolume = 12000.0;
      attribute currentVolume = 6000.0;
    }

    part outlet : AlcazarSupplyOutlet {
      attribute requiredElevation = 96.0;
      attribute demandFlow = 0.012;
    }

    part governor : Governor {
      attribute minimumWheelSpeed = 1.5;
      attribute maximumWheelSpeed = 4.5;
    }

    port riverWaterIn : WaterPort;
    port deliveredWaterOut : WaterPort;
    port operatingCommand : SignalPort;

    connect riverWaterIn to intake.outlet;
    connect intake.outlet to wheel.waterIn;
    connect wheel.rotaryOutput to shaft.input;
    connect shaft.output to crank.rotaryInput;
    connect crank.reciprocatingOutput to frame.lowerMotion;
    connect frame.upperMotion to stage1.motionIn;
    connect stage1.motionIn to stage2.motionIn;
    connect stage2.motionIn to stage3.motionIn;
    connect stage3.motionIn to stage4.motionIn;
    connect stage4.motionIn to stage5.motionIn;
    connect stage5.motionIn to stage6.motionIn;
    connect stage6.motionIn to stage7.motionIn;
    connect stage7.motionIn to stage8.motionIn;
    connect intake.outlet to stage1.waterIn;
    connect stage1.waterOut to stage2.waterIn;
    connect stage2.waterOut to stage3.waterIn;
    connect stage3.waterOut to stage4.waterIn;
    connect stage4.waterOut to stage5.waterIn;
    connect stage5.waterOut to stage6.waterIn;
    connect stage6.waterOut to stage7.waterIn;
    connect stage7.waterOut to stage8.waterIn;
    connect stage8.waterOut to reservoir.inlet;
    connect reservoir.outlet to outlet.inlet;
    connect outlet.inlet to deliveredWaterOut;
    connect wheel.rotaryOutput to governor.speedFeedback;
    connect operatingCommand to governor.commandOut;

    exhibit stateMachine : ArtificioOperatingState;

    perform action capture : CaptureRiverWater;
    perform action convert : ConvertHydraulicEnergy;
    perform action transmit : TransmitMotion;
    perform action oscillate : OscillateArm;
    perform action fill : FillBucket;
    perform action raise : RaiseBucket;
    perform action empty : EmptyBucketToTrough;
    perform action deliver : DeliverWaterToReservoir;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The Artificio de Juanelo shall raise river water from the Tagus to the elevated Alcazar supply level by converting river hydraulic energy into mechanical oscillation and using staged buckets and troughs to transfer water upward. */
    subject artificio : ArtificioDeJuanelo;
    require constraint {
      artificio.totalLiftHeight >= 90.0 and
      artificio.nominalDeliveryFlow >= 0.010 and
      artificio.overallEfficiency > 0.0
    }
  }

  requirement def ContinuousDeliveryRequirement {
    doc /* The mechanism shall support repeated cyclic operation so that water is delivered to the upper reservoir during normal running without manual carrying. */
    subject artificio : ArtificioDeJuanelo;
    require constraint {
      artificio.reservoir.usableVolume >= 10000.0 and
      artificio.outlet.demandFlow <= artificio.nominalDeliveryFlow
    }
  }

  requirement def StagedLiftRequirement {
    doc /* Each lifting stage shall raise water only a limited vertical distance, allowing the complete height difference to be achieved through a sequence of mechanically coupled transfer stages. */
    subject artificio : ArtificioDeJuanelo;
    require constraint {
      artificio.frame.numberOfStages == 8 and
      artificio.stage1.liftHeight +
      artificio.stage2.liftHeight +
      artificio.stage3.liftHeight +
      artificio.stage4.liftHeight +
      artificio.stage5.liftHeight +
      artificio.stage6.liftHeight +
      artificio.stage7.liftHeight +
      artificio.stage8.liftHeight >= artificio.totalLiftHeight
    }
  }

  requirement def PassivePowerRequirement {
    doc /* The primary power source shall be the movement of river water acting on the water wheel, with mechanical transmission through shafts, crank, arms, and buckets. */
    subject artificio : ArtificioDeJuanelo;
    require constraint {
      artificio.wheel.hydraulicEfficiency >= 0.30 and
      artificio.shaft.transmittedTorque >= 1000.0
    }
  }

  satisfy PrimaryFunctionRequirement by ArtificioDeJuanelo;
  satisfy ContinuousDeliveryRequirement by ArtificioDeJuanelo;
  satisfy StagedLiftRequirement by ArtificioDeJuanelo;
  satisfy PassivePowerRequirement by ArtificioDeJuanelo;

}