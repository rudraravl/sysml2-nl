package CentrifugeSystemModel {

  import ScalarValues::*;

  attribute def RotationalSpeed {
    :>> unit = "rpm";
    attribute value : Real;
  }

  attribute def Duration {
    :>> unit = "s";
    attribute value : Real;
  }

  attribute def Temperature {
    :>> unit = "degC";
    attribute value : Real;
  }

  attribute def Volume {
    :>> unit = "mL";
    attribute value : Real;
  }

  attribute def Acceleration {
    :>> unit = "g";
    attribute value : Real;
  }

  item def ElectricalPower {
    attribute voltage : Real;
    attribute current : Real;
  }

  item def ControlCommand {
    attribute targetSpeed : RotationalSpeed;
    attribute runTime : Duration;
    attribute targetTemperature : Temperature;
  }

  item def SpeedFeedback {
    attribute measuredSpeed : RotationalSpeed;
  }

  item def ImbalanceFeedback {
    attribute imbalanceDetected : Boolean;
  }

  item def SeparatedSample {
    attribute supernatantVolume : Volume;
    attribute pelletPresent : Boolean;
    attribute separationComplete : Boolean;
  }

  item def SampleTube {
    attribute sampleVolume : Volume;
    attribute sealed : Boolean;
    attribute balancedMassPairPresent : Boolean;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  port def MotorControlPort {
    out item command : ControlCommand;
  }

  port def SpeedSensorPort {
    out item feedback : SpeedFeedback;
  }

  port def ImbalanceSensorPort {
    out item feedback : ImbalanceFeedback;
  }

  port def TubeLoadingPort {
    in item tube : SampleTube;
  }

  port def ProductPort {
    out item product : SeparatedSample;
  }

  action def SeparateSuspendedPhases {
    in item inputTube : SampleTube;
    in attribute targetSpeed : RotationalSpeed;
    in attribute runTime : Duration;
    out item outputSample : SeparatedSample;

    action accelerateRotor;
    action maintainCentrifugalField;
    action decelerateRotor;
    action releaseSeparatedSample;

    succession accelerateRotor then maintainCentrifugalField;
    succession maintainCentrifugalField then decelerateRotor;
    succession decelerateRotor then releaseSeparatedSample;
  }

  action def StopRotorSafely {
    action removeMotorTorque;
    action applyBrake;
    action unlockLidWhenStationary;

    succession removeMotorTorque then applyBrake;
    succession applyBrake then unlockLidWhenStationary;
  }

  state def CentrifugeOperatingState {
    state Off;
    state Idle;
    state LidOpen;
    state Loaded;
    state Accelerating;
    state Separating;
    state Decelerating;
    state Complete;
    state Fault;

    transition initial then Off;
    transition Off then Idle;
    transition Idle then LidOpen;
    transition LidOpen then Loaded;
    transition Loaded then Accelerating;
    transition Accelerating then Separating;
    transition Separating then Decelerating;
    transition Decelerating then Complete;
    transition Complete then Idle;
    transition Accelerating then Fault;
    transition Separating then Fault;
    transition Fault then Idle;
  }

  part def ElectricDriveMotor {
    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port speedOut : SpeedSensorPort;

    attribute maximumSpeed : RotationalSpeed = 15000 [rpm];
    attribute continuousPower : Real = 600;
  }

  part def RotorAssembly {
    port tubeLoad : TubeLoadingPort;
    port separatedSampleOut : ProductPort;

    attribute rotorRadius : Real = 0.085;
    attribute maximumRelativeCentrifugalForce : Acceleration = 21000 [g];
    attribute maximumTubeCapacity : Volume = 50 [mL];
    attribute tubePositions : Integer = 8;
  }

  part def LidAndInterlock {
    attribute lidClosed : Boolean;
    attribute lidLocked : Boolean;
    attribute unlockAllowedOnlyWhenStationary : Boolean = true;
  }

  part def ImbalanceMonitor {
    port imbalanceOut : ImbalanceSensorPort;
    attribute tripThreshold : Real = 0.15;
  }

  part def ThermalControlUnit {
    attribute chamberTemperature : Temperature;
    attribute minimumTemperature : Temperature = 4 [degC];
    attribute maximumTemperature : Temperature = 40 [degC];
  }

  part def UserInterface {
    port commandOut : MotorControlPort;
    attribute selectedSpeed : RotationalSpeed;
    attribute selectedRunTime : Duration;
    attribute selectedTemperature : Temperature;
    attribute startRequested : Boolean;
    attribute stopRequested : Boolean;
  }

  part def CentrifugeController {
    port userCommandIn : CommandPort;
    port motorCommandOut : MotorControlPort;
    port speedFeedbackIn : SpeedSensorPort;
    port imbalanceFeedbackIn : ImbalanceSensorPort;

    attribute commandedSpeed : RotationalSpeed;
    attribute elapsedRunTime : Duration;
    attribute safeToRun : Boolean;
  }

  part def LaboratoryCentrifuge {
    port facilityPower : PowerPort;
    port sampleInput : TubeLoadingPort;
    port separatedOutput : ProductPort;

    attribute primaryFunction : String =
      "Generate controlled high-speed rotation to create centrifugal acceleration that separates suspended sample phases by density.";

    attribute nominalSpeed : RotationalSpeed = 12000 [rpm];
    attribute nominalRunTime : Duration = 600 [s];
    attribute nominalTemperature : Temperature = 20 [degC];

    part motor : ElectricDriveMotor;
    part rotor : RotorAssembly;
    part lid : LidAndInterlock;
    part controller : CentrifugeController;
    part userInterface : UserInterface;
    part imbalanceMonitor : ImbalanceMonitor;
    part thermalControl : ThermalControlUnit;

    perform action separation : SeparateSuspendedPhases;
    perform action emergencyStop : StopRotorSafely;
    exhibit state operatingState : CentrifugeOperatingState;

    connection powerToMotor connect facilityPower to motor.powerIn;
    connection userToController connect userInterface.commandOut to controller.userCommandIn;
    connection controllerToMotor connect controller.motorCommandOut to motor.commandIn;
    connection speedFeedback connect motor.speedOut to controller.speedFeedbackIn;
    connection imbalanceFeedback connect imbalanceMonitor.imbalanceOut to controller.imbalanceFeedbackIn;
    connection loadingPath connect sampleInput to rotor.tubeLoad;
    connection productPath connect rotor.separatedSampleOut to separatedOutput;
  }

  requirement def PrimaryFunctionRequirement {
    subject centrifuge : LaboratoryCentrifuge;

    require constraint {
      centrifuge.primaryFunction ==
      "Generate controlled high-speed rotation to create centrifugal acceleration that separates suspended sample phases by density."
    }
  }

  requirement def SafeOperationRequirement {
    subject centrifuge : LaboratoryCentrifuge;

    require constraint {
      centrifuge.lid.lidLocked == true implies centrifuge.controller.safeToRun == true
    }
  }

  requirement def ImbalanceProtectionRequirement {
    subject centrifuge : LaboratoryCentrifuge;

    require constraint {
      centrifuge.controller.safeToRun == false implies centrifuge.imbalanceMonitor.tripThreshold <= 0.15
    }
  }

  requirement def SeparationPerformanceRequirement {
    subject centrifuge : LaboratoryCentrifuge;

    require constraint {
      centrifuge.nominalSpeed.value >= 12000 and
      centrifuge.nominalRunTime.value >= 600
    }
  }

  part laboratoryCentrifuge : LaboratoryCentrifuge;

  satisfy PrimaryFunctionRequirement by laboratoryCentrifuge;
  satisfy SafeOperationRequirement by laboratoryCentrifuge;
  satisfy ImbalanceProtectionRequirement by laboratoryCentrifuge;
  satisfy SeparationPerformanceRequirement by laboratoryCentrifuge;
}