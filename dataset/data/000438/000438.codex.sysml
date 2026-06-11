package CytocentrifugeSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def RevolutionsPerMinute :> ScalarValues::Real;
  attribute def Microliter :> ScalarValues::Real;
  attribute def Milliliter :> ScalarValues::Real;
  attribute def Minute :> ScalarValues::Real;
  attribute def Second :> ScalarValues::Real;
  attribute def Celsius :> ScalarValues::Real;
  attribute def GForce :> ScalarValues::Real;
  attribute def Percent :> ScalarValues::Real;

  item def LiquidSpecimen {
    attribute volume : Microliter;
    attribute cellConcentration : ScalarValues::Real;
    attribute viscosity : ScalarValues::Real;
    attribute biohazardClass : ScalarValues::Integer;
  }

  item def ConcentratedCellDeposit {
    attribute targetAreaDiameter : Length;
    attribute retainedCellFraction : Percent;
    attribute residualFluidVolume : Microliter;
    attribute morphologyPreserved : Boolean;
  }

  item def MicroscopeSlide {
    attribute slideId : String;
    attribute prepared : Boolean;
    attribute depositAreaDiameter : Length;
    attribute labeled : Boolean;
  }

  item def AbsorbentPad {
    attribute capacity : Microliter;
    attribute saturated : Boolean;
  }

  item def CytologyChamber {
    attribute chamberId : String;
    attribute maxSpecimenVolume : Microliter;
    attribute sealed : Boolean;
  }

  item def RotorAssemblyStatus {
    attribute installed : Boolean;
    attribute balanced : Boolean;
    attribute locked : Boolean;
    attribute speed : RevolutionsPerMinute;
    attribute vibrationLevel : ScalarValues::Real;
  }

  item def RunProgram {
    attribute targetSpeed : RevolutionsPerMinute;
    attribute accelerationTime : Second;
    attribute spinDuration : Minute;
    attribute brakeTime : Second;
    attribute targetTemperature : Celsius;
  }

  item def RunResult {
    attribute completed : Boolean;
    attribute aborted : Boolean;
    attribute faultCode : String;
    attribute slidesPrepared : ScalarValues::Integer;
  }

  item def ElectricalPower {
    attribute voltage : ElectricPotential;
    attribute current : ElectricCurrent;
    attribute frequency : Frequency;
  }

  item def ControlCommand {
    attribute commandName : String;
    attribute requestedByUser : Boolean;
  }

  item def AlarmSignal {
    attribute alarmCode : String;
    attribute severity : ScalarValues::Integer;
    attribute latched : Boolean;
  }

  port def SpecimenInputPort {
    in item specimen : LiquidSpecimen;
  }

  port def SlideOutputPort {
    out item slide : MicroscopeSlide;
    out item deposit : ConcentratedCellDeposit;
  }

  port def ChamberPort {
    in item chamber : CytologyChamber;
    in item pad : AbsorbentPad;
    inout item slide : MicroscopeSlide;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def CommandPort {
    in item command : ControlCommand;
    out item result : RunResult;
    out item alarm : AlarmSignal;
  }

  port def DrivePort {
    out attribute commandedSpeed : RevolutionsPerMinute;
    in attribute measuredSpeed : RevolutionsPerMinute;
    in attribute vibrationLevel : ScalarValues::Real;
  }

  port def SafetyInterlockPort {
    out attribute lidLocked : Boolean;
    out attribute rotorLocked : Boolean;
    in attribute emergencyStopRequested : Boolean;
  }

  port def ThermalPort {
    out attribute commandedTemperature : Celsius;
    in attribute measuredTemperature : Celsius;
  }

  action def LoadCytologyChambers {
    in item specimen : LiquidSpecimen;
    in item slide : MicroscopeSlide;
    in item pad : AbsorbentPad;
    out item chamber : CytologyChamber;
  }

  action def VerifyRotorBalance {
    in item rotorStatus : RotorAssemblyStatus;
    out attribute balanced : Boolean;
    out attribute acceptableVibration : Boolean;
  }

  action def ExecuteSpinProgram {
    in item program : RunProgram;
    in item chamber : CytologyChamber;
    inout item slide : MicroscopeSlide;
    out item deposit : ConcentratedCellDeposit;
    out item result : RunResult;
  }

  action def AbsorbSupernatant {
    in item chamber : CytologyChamber;
    inout item pad : AbsorbentPad;
    out attribute residualFluidVolume : Microliter;
  }

  action def StopRotorSafely {
    in attribute initialSpeed : RevolutionsPerMinute;
    out attribute finalSpeed : RevolutionsPerMinute;
    out attribute stopped : Boolean;
  }

  state def CytocentrifugeOperatingState {
    entry action initializeControl;
    state poweredOff;
    state idle;
    state loading;
    state ready;
    state accelerating;
    state spinning;
    state braking;
    state complete;
    state fault;
    state decontaminationRequired;

    transition first poweredOff;
    transition powerApplied
      first poweredOff then idle;

    transition beginLoad
      first idle then loading
      accept ControlCommand
      if command.commandName == "Load";

    transition loadComplete
      first loading then ready
      if chamber.sealed == true;

    transition startRun
      first ready then accelerating
      accept ControlCommand
      if command.commandName == "Start" and rotorStatus.balanced == true and rotorStatus.locked == true;

    transition targetSpeedReached
      first accelerating then spinning
      if rotorStatus.speed >= activeProgram.targetSpeed;

    transition spinTimeElapsed
      first spinning then braking;

    transition rotorStopped
      first braking then complete
      if rotorStatus.speed == 0.0;

    transition unload
      first complete then idle
      accept ControlCommand
      if command.commandName == "Unload";

    transition biohazardCleanup
      first idle then decontaminationRequired
      if contaminationDetected == true;

    transition cleanupComplete
      first decontaminationRequired then idle;

    transition anyFault
      first idle then fault
      accept AlarmSignal
      if alarm.severity >= 2;

    transition runFault
      first accelerating then fault
      if rotorStatus.vibrationLevel > maximumAllowedVibration;

    transition spinFault
      first spinning then fault
      if lidLocked == false or rotorStatus.vibrationLevel > maximumAllowedVibration;

    transition emergencyStop
      first spinning then braking
      if emergencyStopRequested == true;

    transition resetFault
      first fault then idle
      accept ControlCommand
      if command.commandName == "Reset";
  }

  part def LidAssembly {
    attribute closed : Boolean;
    attribute locked : Boolean;
    port interlock : SafetyInterlockPort;
  }

  part def UserInterface {
    attribute displayText : String;
    attribute selectedProgramName : String;
    port commandPort : CommandPort;
  }

  part def MotorDrive {
    attribute maximumSpeed : RevolutionsPerMinute = 2500.0;
    attribute speedTolerance : RevolutionsPerMinute = 25.0;
    port powerIn : PowerPort;
    port drive : DrivePort;
  }

  part def Rotor {
    attribute chamberCapacity : ScalarValues::Integer = 12;
    attribute currentSpeed : RevolutionsPerMinute;
    attribute balanceError : ScalarValues::Real;
    attribute locked : Boolean;
    port chamberPorts[12] : ChamberPort;
    port drive : DrivePort;
  }

  part def ChamberSet {
    part chambers[12] : CytologyChamber;
    part pads[12] : AbsorbentPad;
    part slides[12] : MicroscopeSlide;
    attribute loadedChamberCount : ScalarValues::Integer;
  }

  part def TemperatureController {
    attribute minimumTemperature : Celsius = 15.0;
    attribute maximumTemperature : Celsius = 30.0;
    attribute measuredTemperature : Celsius;
    port thermal : ThermalPort;
    port powerIn : PowerPort;
  }

  part def VibrationSensor {
    attribute measuredVibration : ScalarValues::Real;
    attribute tripThreshold : ScalarValues::Real = 1.5;
    port driveFeedback : DrivePort;
  }

  part def ContainmentBowl {
    attribute leakDetected : Boolean;
    attribute disinfected : Boolean;
  }

  part def SafetyController {
    attribute maximumAllowedVibration : ScalarValues::Real = 1.5;
    attribute lidLocked : Boolean;
    attribute rotorLocked : Boolean;
    attribute emergencyStopRequested : Boolean;
    port interlock : SafetyInterlockPort;
    port commandPort : CommandPort;
  }

  part def Cytocentrifuge {
    attribute primaryFunction : String =
      "Concentrate suspended cells from a liquid clinical specimen onto a defined area of a microscope slide by controlled centrifugal force while absorbing excess fluid for cytological examination.";

    attribute maximumSpecimenVolumePerChamber : Microliter = 500.0;
    attribute nominalSpecimenVolumePerChamber : Microliter = 200.0;
    attribute minimumCellRetention : Percent = 85.0;
    attribute nominalTargetAreaDiameter : Length = 6.0 [mm];
    attribute maximumAllowedVibration : ScalarValues::Real = 1.5;
    attribute contaminationDetected : Boolean = false;

    part ui : UserInterface;
    part lid : LidAssembly;
    part motorDrive : MotorDrive;
    part rotor : Rotor;
    part chamberSet : ChamberSet;
    part temperatureController : TemperatureController;
    part vibrationSensor : VibrationSensor;
    part containmentBowl : ContainmentBowl;
    part safetyController : SafetyController;

    port powerIn : PowerPort;
    port specimenIn[12] : SpecimenInputPort;
    port slideOut[12] : SlideOutputPort;
    port operatorCommands : CommandPort;

    item activeProgram : RunProgram {
      attribute targetSpeed = 1200.0;
      attribute accelerationTime = 20.0;
      attribute spinDuration = 5.0;
      attribute brakeTime = 30.0;
      attribute targetTemperature = 22.0;
    }

    item rotorStatus : RotorAssemblyStatus;
    item runResult : RunResult;

    connect powerIn to motorDrive.powerIn;
    connect powerIn to temperatureController.powerIn;
    connect operatorCommands to ui.commandPort;
    connect ui.commandPort to safetyController.commandPort;
    connect lid.interlock to safetyController.interlock;
    connect motorDrive.drive to rotor.drive;
    connect rotor.drive to vibrationSensor.driveFeedback;

    connection def ChamberInstallation {
      end chamberSet.chambers;
      end rotor.chamberPorts;
    }

    connection def SlideRecovery {
      end rotor.chamberPorts;
      end slideOut;
    }

    perform action LoadCytologyChambers {
      in specimen = specimenIn.specimen;
      in slide = chamberSet.slides;
      in pad = chamberSet.pads;
      out chamber = chamberSet.chambers;
    }

    perform action VerifyRotorBalance {
      in rotorStatus = rotorStatus;
      out balanced = rotorStatus.balanced;
      out acceptableVibration;
    }

    perform action ExecuteSpinProgram {
      in program = activeProgram;
      in chamber = chamberSet.chambers;
      inout slide = chamberSet.slides;
      out deposit = slideOut.deposit;
      out result = runResult;
    }

    perform action AbsorbSupernatant {
      in chamber = chamberSet.chambers;
      inout pad = chamberSet.pads;
      out residualFluidVolume = slideOut.deposit.residualFluidVolume;
    }

    perform action StopRotorSafely {
      in initialSpeed = rotor.currentSpeed;
      out finalSpeed = rotor.currentSpeed;
      out stopped = runResult.completed;
    }

    exhibit state CytocentrifugeOperatingState;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The cytocentrifuge shall concentrate cells from a liquid specimen onto a defined microscope slide area for cytological examination. */
    subject centrifuge : Cytocentrifuge;
    require constraint {
      centrifuge.primaryFunction != "" and
      centrifuge.nominalTargetAreaDiameter <= 8.0 [mm]
    }
  }

  requirement def SpecimenCapacityRequirement {
    doc /* Each chamber shall process a liquid specimen volume up to 500 microliters without overflow during the spin cycle. */
    subject centrifuge : Cytocentrifuge;
    require constraint {
      centrifuge.maximumSpecimenVolumePerChamber >= 500.0
    }
  }

  requirement def CellRetentionRequirement {
    doc /* The system shall retain at least 85 percent of available cells in the deposited slide area under nominal operating conditions. */
    subject centrifuge : Cytocentrifuge;
    require constraint {
      centrifuge.minimumCellRetention >= 85.0
    }
  }

  requirement def RotorSafetyRequirement {
    doc /* The rotor shall not accelerate unless the lid is locked, the rotor is locked, and the chamber set is balanced. */
    subject centrifuge : Cytocentrifuge;
    require constraint {
      centrifuge.lid.locked == true implies centrifuge.safetyController.lidLocked == true
    }
  }

  requirement def VibrationProtectionRequirement {
    doc /* The system shall enter a fault state or brake safely when measured vibration exceeds the allowed threshold. */
    subject centrifuge : Cytocentrifuge;
    require constraint {
      centrifuge.vibrationSensor.tripThreshold <= centrifuge.maximumAllowedVibration
    }
  }

  requirement def ThermalStabilityRequirement {
    doc /* The system shall maintain the chamber environment between 15 and 30 degrees Celsius during operation. */
    subject centrifuge : Cytocentrifuge;
    require constraint {
      centrifuge.temperatureController.minimumTemperature <= 15.0 and
      centrifuge.temperatureController.maximumTemperature >= 30.0
    }
  }

  requirement def BioContainmentRequirement {
    doc /* The system shall contain liquid leakage inside the containment bowl and require decontamination before subsequent use when leakage is detected. */
    subject centrifuge : Cytocentrifuge;
    require constraint {
      centrifuge.containmentBowl.leakDetected == true implies centrifuge.contaminationDetected == true
    }
  }

  satisfy PrimaryFunctionRequirement by Cytocentrifuge;
  satisfy SpecimenCapacityRequirement by Cytocentrifuge;
  satisfy CellRetentionRequirement by Cytocentrifuge;
  satisfy RotorSafetyRequirement by SafetyController;
  satisfy VibrationProtectionRequirement by SafetyController;
  satisfy ThermalStabilityRequirement by TemperatureController;
  satisfy BioContainmentRequirement by ContainmentBowl;

  part cytocentrifugeSystem : Cytocentrifuge;

}