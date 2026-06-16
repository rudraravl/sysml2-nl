package HumanoidPrimaryFunctionModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Percent :> Real {
    range = "0..100";
    unit = "%";
  }

  attribute def Confidence :> Real {
    range = "0..1";
  }

  attribute def JointAngle :> Real {
    unit = "rad";
  }

  attribute def JointTorque :> Real {
    unit = "N*m";
  }

  attribute def Force :> Real {
    unit = "N";
  }

  attribute def Power :> Real {
    unit = "W";
  }

  attribute def Energy :> Real {
    unit = "J";
  }

  attribute def Speed :> Real {
    unit = "m/s";
  }

  attribute def Distance :> Real {
    unit = "m";
  }

  attribute def Mass :> Real {
    unit = "kg";
  }

  attribute def Duration :> Real {
    unit = "s";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  item def VisualScene {
    attribute objectCount : Integer;
    attribute sceneConfidence : Confidence;
    attribute illuminationLevel : Real;
  }

  item def AudioSignal {
    attribute soundPressureLevel : Real;
    attribute speechConfidence : Confidence;
  }

  item def TactileContact {
    attribute contactForce : Force;
    attribute contactLocation : String;
    attribute slipDetected : Boolean;
  }

  item def HumanCommand {
    attribute intent : String;
    attribute priority : Integer;
    attribute confidence : Confidence;
  }

  item def MotionPlan {
    attribute targetDescription : String;
    attribute plannedDistance : Distance;
    attribute plannedDuration : Duration;
    attribute expectedSpeed : Speed;
  }

  item def ManipulationPlan {
    attribute objectDescription : String;
    attribute graspForce : Force;
    attribute expectedObjectMass : Mass;
  }

  item def StatusReport {
    attribute operatingMode : String;
    attribute batteryStateOfCharge : Percent;
    attribute healthState : String;
    attribute taskProgress : Percent;
  }

  item def ElectricalPower {
    attribute voltage : Real;
    attribute current : Real;
    attribute availablePower : Power;
  }

  item def HeatFlow {
    attribute heatRate : Power;
    attribute componentTemperature : Temperature;
  }

  port def VisionPort {
    out item scene : VisualScene;
  }

  port def HearingPort {
    out item audio : AudioSignal;
  }

  port def TouchPort {
    out item contact : TactileContact;
  }

  port def CommandPort {
    in item command : HumanCommand;
  }

  port def StatusPort {
    out item status : StatusReport;
  }

  port def PowerPort {
    in item suppliedPower : ElectricalPower;
  }

  port def ThermalPort {
    out item wasteHeat : HeatFlow;
  }

  port def MotionPlanPort {
    out item motionPlan : MotionPlan;
  }

  port def ManipulationPlanPort {
    out item manipulationPlan : ManipulationPlan;
  }

  port def LocomotionControlPort {
    in item plan : MotionPlan;
  }

  port def ManipulationControlPort {
    in item plan : ManipulationPlan;
  }

  part def SensorSuite {
    attribute visualUpdateRate : Real = 60;
    attribute audioUpdateRate : Real = 16000;
    attribute tactileUpdateRate : Real = 500;

    port vision : VisionPort;
    port hearing : HearingPort;
    port touch : TouchPort;

    action senseEnvironment {
      out item perceivedScene : VisualScene;
      out item perceivedAudio : AudioSignal;
      out item perceivedContact : TactileContact;
    }
  }

  part def CognitiveController {
    attribute nominalDecisionLatency : Duration = 0.25;
    attribute minimumIntentConfidence : Confidence = 0.75;

    port commandIn : CommandPort;
    port statusOut : StatusPort;
    port motionPlanOut : MotionPlanPort;
    port manipulationPlanOut : ManipulationPlanPort;

    action interpretHumanIntent {
      in item command : HumanCommand;
      out attribute accepted : Boolean;
    }

    action planAssistance {
      in item command : HumanCommand;
      out item motionPlan : MotionPlan;
      out item manipulationPlan : ManipulationPlan;
    }

    action reportStatus {
      out item status : StatusReport;
    }
  }

  part def LocomotionSystem {
    attribute maximumWalkingSpeed : Speed = 1.5;
    attribute nominalWalkingSpeed : Speed = 1.0;
    attribute maximumSlope : Real = 10;
    attribute stanceStabilityMargin : Distance = 0.08;

    port controlIn : LocomotionControlPort;

    part leftLeg : Leg;
    part rightLeg : Leg;
    part pelvis : Pelvis;

    action maintainBalance {
      in attribute centerOfMassOffset : Distance;
      out attribute stable : Boolean;
    }

    action executeWalkingPlan {
      in item plan : MotionPlan;
      out attribute distanceCompleted : Distance;
    }
  }

  part def ManipulationSystem {
    attribute maximumPayloadMass : Mass = 10;
    attribute nominalGripForce : Force = 35;
    attribute maximumGripForce : Force = 120;

    port controlIn : ManipulationControlPort;

    part leftArm : Arm;
    part rightArm : Arm;
    part leftHand : Hand;
    part rightHand : Hand;

    action graspObject {
      in item plan : ManipulationPlan;
      out attribute graspSecured : Boolean;
    }

    action transferObject {
      in item plan : ManipulationPlan;
      out attribute transferComplete : Boolean;
    }
  }

  part def PowerSystem {
    attribute batteryCapacity : Energy = 1800000;
    attribute nominalVoltage : Real = 48;
    attribute stateOfCharge : Percent = 100;
    attribute reserveThreshold : Percent = 15;

    port externalPowerIn : PowerPort;
    port controllerPowerOut : PowerPort;
    port actuatorPowerOut : PowerPort;

    action distributePower {
      in item suppliedPower : ElectricalPower;
      out item controllerPower : ElectricalPower;
      out item actuatorPower : ElectricalPower;
    }

    action monitorEnergy {
      out attribute stateOfCharge : Percent;
      out attribute reserveReached : Boolean;
    }
  }

  part def ThermalManagementSystem {
    attribute maximumControllerTemperature : Temperature = 70;
    attribute maximumActuatorTemperature : Temperature = 85;
    attribute coolingPower : Power = 150;

    port thermalOut : ThermalPort;

    action rejectHeat {
      in item heatLoad : HeatFlow;
      out item rejectedHeat : HeatFlow;
    }
  }

  part def HumanInterface {
    port commandOut : CommandPort;
    port statusIn : StatusPort;

    action receiveSpokenInstruction {
      out item command : HumanCommand;
    }

    action presentStatus {
      in item status : StatusReport;
    }
  }

  part def Arm {
    attribute shoulderAngle : JointAngle;
    attribute elbowAngle : JointAngle;
    attribute wristAngle : JointAngle;
    attribute shoulderTorque : JointTorque;
    attribute elbowTorque : JointTorque;
  }

  part def Hand {
    attribute fingerClosure : Percent;
    attribute appliedGripForce : Force;
    attribute tactileConfidence : Confidence;
  }

  part def Leg {
    attribute hipAngle : JointAngle;
    attribute kneeAngle : JointAngle;
    attribute ankleAngle : JointAngle;
    attribute hipTorque : JointTorque;
    attribute kneeTorque : JointTorque;
    attribute ankleTorque : JointTorque;
  }

  part def Pelvis {
    attribute orientationPitch : JointAngle;
    attribute orientationRoll : JointAngle;
    attribute verticalLoad : Force;
  }

  part def Humanoid {
    attribute height : Distance = 1.75;
    attribute mass : Mass = 82;
    attribute designedServiceLife : Duration = 315360000;
    attribute primaryFunction : String = "Assist humans by perceiving intent, moving safely through human environments, manipulating everyday objects, and reporting operational status.";

    port externalCommand : CommandPort;
    port externalStatus : StatusPort;
    port externalPower : PowerPort;
    port wasteHeat : ThermalPort;

    part sensors : SensorSuite;
    part cognition : CognitiveController;
    part locomotion : LocomotionSystem;
    part manipulation : ManipulationSystem;
    part power : PowerSystem;
    part thermal : ThermalManagementSystem;
    part interface : HumanInterface;

    connect interface.commandOut to cognition.commandIn;
    connect cognition.statusOut to interface.statusIn;
    connect cognition.motionPlanOut to locomotion.controlIn;
    connect cognition.manipulationPlanOut to manipulation.controlIn;
    connect externalCommand to cognition.commandIn;
    connect cognition.statusOut to externalStatus;
    connect externalPower to power.externalPowerIn;
    connect power.controllerPowerOut to cognition.commandIn;
    connect power.actuatorPowerOut to locomotion.controlIn;
    connect thermal.thermalOut to wasteHeat;

    action performPrimaryFunction {
      in item command : HumanCommand;
      out item status : StatusReport;

      first start;
      then interpret;
      then plan;
      then move;
      then manipulate;
      then report;
      then done;

      action interpret {
        in item command : HumanCommand;
        out attribute accepted : Boolean;
      }

      action plan {
        out item motionPlan : MotionPlan;
        out item manipulationPlan : ManipulationPlan;
      }

      action move {
        in item motionPlan : MotionPlan;
        out attribute reachedWorkLocation : Boolean;
      }

      action manipulate {
        in item manipulationPlan : ManipulationPlan;
        out attribute taskObjectHandled : Boolean;
      }

      action report {
        out item status : StatusReport;
      }
    }

    state def OperatingStateMachine {
      state off;
      state initializing;
      state idle;
      state perceiving;
      state planning;
      state assisting;
      state reporting;
      state charging;
      state fault;

      transition first off then initializing
        accept PowerApplied;

      transition initializing then idle
        accept InitializationComplete;

      transition idle then perceiving
        accept CommandReceived;

      transition perceiving then planning
        accept IntentRecognized;

      transition planning then assisting
        accept AssistancePlanReady;

      transition assisting then reporting
        accept AssistanceTaskComplete;

      transition reporting then idle
        accept StatusAcknowledged;

      transition idle then charging
        accept LowEnergyDetected;

      transition charging then idle
        accept ChargeComplete;

      transition initializing then fault
        accept SelfTestFailed;

      transition perceiving then fault
        accept UnsafeConditionDetected;

      transition planning then fault
        accept NoSafePlanAvailable;

      transition assisting then fault
        accept BalanceOrGripLost;

      transition fault then idle
        accept FaultCleared;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The humanoid shall provide high-level human assistance by understanding a human command, forming a safe motion and manipulation plan, executing the plan, and communicating status. */
    subject humanoid : Humanoid;

    require constraint {
      humanoid.primaryFunction == "Assist humans by perceiving intent, moving safely through human environments, manipulating everyday objects, and reporting operational status."
    }
  }

  requirement def SafetyRequirement {
    doc /* The humanoid shall maintain balance and limit physical interaction forces while assisting humans in shared environments. */
    subject humanoid : Humanoid;

    require constraint {
      humanoid.locomotion.stanceStabilityMargin >= 0.05 and
      humanoid.manipulation.maximumGripForce <= 120
    }
  }

  requirement def MobilityRequirement {
    doc /* The humanoid shall walk at a nominal indoor assistance speed while carrying out commanded tasks. */
    subject humanoid : Humanoid;

    require constraint {
      humanoid.locomotion.nominalWalkingSpeed >= 0.8 and
      humanoid.locomotion.maximumWalkingSpeed >= 1.2
    }
  }

  requirement def ManipulationRequirement {
    doc /* The humanoid shall manipulate common carried objects up to the defined payload mass. */
    subject humanoid : Humanoid;

    require constraint {
      humanoid.manipulation.maximumPayloadMass >= 8 and
      humanoid.manipulation.nominalGripForce >= 20
    }
  }

  requirement def EnergyRequirement {
    doc /* The humanoid shall preserve reserve energy for controlled stopping and status reporting. */
    subject humanoid : Humanoid;

    require constraint {
      humanoid.power.reserveThreshold >= 10 and
      humanoid.power.batteryCapacity >= 1500000
    }
  }

  requirement def HumanInteractionRequirement {
    doc /* The humanoid shall accept human commands and report current operating status through an external interface. */
    subject humanoid : Humanoid;

    require constraint {
      humanoid.cognition.minimumIntentConfidence >= 0.70 and
      humanoid.cognition.nominalDecisionLatency <= 0.50
    }
  }

  part humanoidAssistant : Humanoid {
    attribute height = 1.78;
    attribute mass = 84;
    attribute primaryFunction = "Assist humans by perceiving intent, moving safely through human environments, manipulating everyday objects, and reporting operational status.";

    satisfy PrimaryFunctionRequirement by humanoidAssistant;
    satisfy SafetyRequirement by humanoidAssistant;
    satisfy MobilityRequirement by humanoidAssistant;
    satisfy ManipulationRequirement by humanoidAssistant;
    satisfy EnergyRequirement by humanoidAssistant;
    satisfy HumanInteractionRequirement by humanoidAssistant;
  }

}