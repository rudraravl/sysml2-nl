package StretcherSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value def MassValue :> Mass;
  value def LengthValue :> Length;
  value def ForceValue :> Force;
  value def TimeValue :> Time;
  value def SpeedValue :> Speed;
  value def AngleValue :> PlaneAngle;

  enum def BrakeState {
    enum released;
    enum applied;
  }

  enum def HeightMode {
    enum lowTransfer;
    enum transport;
    enum highTreatment;
  }

  enum def RailPosition {
    enum lowered;
    enum raised;
    enum lockedRaised;
  }

  enum def OccupancyState {
    enum empty;
    enum loaded;
  }

  item def Patient {
    attribute bodyMass : MassValue;
    attribute bodyLength : LengthValue;
    attribute isSecured : Boolean;
  }

  item def CaregiverCommand {
    attribute requestTransport : Boolean;
    attribute requestLoadPatient : Boolean;
    attribute requestUnloadPatient : Boolean;
    attribute requestRaiseHeight : Boolean;
    attribute requestLowerHeight : Boolean;
    attribute requestApplyBrake : Boolean;
    attribute requestReleaseBrake : Boolean;
  }

  item def MotionCommand {
    attribute requestedSpeed : SpeedValue;
    attribute requestedDirectionAngle : AngleValue;
  }

  item def LoadStatus {
    attribute measuredLoad : MassValue;
    attribute occupancy : OccupancyState;
    attribute overLoadDetected : Boolean;
  }

  item def BrakeCommand {
    attribute targetState : BrakeState;
  }

  item def HeightCommand {
    attribute targetMode : HeightMode;
  }

  item def RailCommand {
    attribute targetPosition : RailPosition;
  }

  port def PatientSupportPort {
    in item patientIn : Patient;
    out item patientOut : Patient;
    out item loadStatus : LoadStatus;
  }

  port def CaregiverControlPort {
    in item command : CaregiverCommand;
    in item motion : MotionCommand;
    out item loadStatus : LoadStatus;
  }

  port def BrakeControlPort {
    in item command : BrakeCommand;
    out attribute state : BrakeState;
  }

  port def HeightControlPort {
    in item command : HeightCommand;
    out attribute mode : HeightMode;
  }

  port def RailControlPort {
    in item command : RailCommand;
    out attribute position : RailPosition;
  }

  port def GroundInterfacePort {
    out item motion : MotionCommand;
    out attribute normalForce : ForceValue;
    out attribute rollingResistance : ForceValue;
  }

  part def Mattress {
    attribute length : LengthValue = 2.05 [m];
    attribute width : LengthValue = 0.72 [m];
    attribute thickness : LengthValue = 0.08 [m];
    attribute ratedPatientMass : MassValue = 180 [kg];

    port support : PatientSupportPort;
  }

  part def Frame {
    attribute structuralMass : MassValue = 32 [kg];
    attribute ratedSafeWorkingLoad : MassValue = 250 [kg];
    attribute foldedLength : LengthValue = 1.25 [m];
    attribute deployedLength : LengthValue = 2.15 [m];

    port patientSupport : PatientSupportPort;
  }

  part def WheelAssembly {
    attribute wheelDiameter : LengthValue = 0.15 [m];
    attribute maximumTransportSpeed : SpeedValue = 1.8 [m/s];
    attribute casterCount : Integer = 4;

    port ground : GroundInterfacePort;
    port brakeControl : BrakeControlPort;
  }

  part def BrakeSystem {
    attribute currentState : BrakeState = BrakeState::applied;
    attribute maximumHoldingForce : ForceValue = 650 [N];

    port control : BrakeControlPort;
  }

  part def HeightAdjustmentSystem {
    attribute currentMode : HeightMode = HeightMode::transport;
    attribute lowHeight : LengthValue = 0.48 [m];
    attribute transportHeight : LengthValue = 0.72 [m];
    attribute highTreatmentHeight : LengthValue = 0.92 [m];
    attribute transitionTime : TimeValue = 6 [s];

    port control : HeightControlPort;
  }

  part def SideRail {
    attribute currentPosition : RailPosition = RailPosition::lockedRaised;
    attribute railHeight : LengthValue = 0.34 [m];
    attribute latchHoldingForce : ForceValue = 300 [N];

    port control : RailControlPort;
  }

  part def RestraintSystem {
    attribute strapCount : Integer = 3;
    attribute ratedRestraintForce : ForceValue = 900 [N];
    attribute secured : Boolean = false;
  }

  part def LoadSensor {
    attribute measuredLoad : MassValue;
    attribute overloadLimit : MassValue = 250 [kg];

    port status : PatientSupportPort;
  }

  part def CaregiverHandle {
    attribute gripHeight : LengthValue = 0.95 [m];
    attribute handleWidth : LengthValue = 0.55 [m];

    port control : CaregiverControlPort;
  }

  action def LoadPatient {
    in item patient : Patient;
    inout item status : LoadStatus;
    first start;
    then lowerRails;
    then positionPatient;
    then securePatient;
    then updateStatus;
    then done;

    action lowerRails;
    action positionPatient;
    action securePatient;
    action updateStatus;
  }

  action def TransportPatient {
    in item patient : Patient;
    in item motionRequest : MotionCommand;
    inout item status : LoadStatus;
    first verifySecured;
    then releaseBrake;
    then moveStretcher;
    then applyBrakeAtDestination;
    then done;

    action verifySecured;
    action releaseBrake;
    action moveStretcher;
    action applyBrakeAtDestination;
  }

  action def UnloadPatient {
    inout item patient : Patient;
    inout item status : LoadStatus;
    first applyBrake;
    then setLowTransferHeight;
    then lowerRails;
    then releaseRestraints;
    then transferPatientOut;
    then updateEmptyStatus;
    then done;

    action applyBrake;
    action setLowTransferHeight;
    action lowerRails;
    action releaseRestraints;
    action transferPatientOut;
    action updateEmptyStatus;
  }

  state def StretcherOperationalStates {
    entry action initialize;

    state idle;
    state preparingForLoad;
    state loadedStationary;
    state transporting;
    state preparingForUnload;
    state maintenanceLocked;

    transition first idle;

    transition loadRequested
      first idle
      accept CaregiverCommand
      if command.requestLoadPatient
      then preparingForLoad;

    transition patientLoaded
      first preparingForLoad
      then loadedStationary;

    transition transportRequested
      first loadedStationary
      accept CaregiverCommand
      if command.requestTransport
      then transporting;

    transition transportComplete
      first transporting
      then loadedStationary;

    transition unloadRequested
      first loadedStationary
      accept CaregiverCommand
      if command.requestUnloadPatient
      then preparingForUnload;

    transition patientUnloaded
      first preparingForUnload
      then idle;

    transition overloadDetected
      first preparingForLoad
      accept LoadStatus
      if loadStatus.overLoadDetected
      then maintenanceLocked;

    transition resetAfterInspection
      first maintenanceLocked
      then idle;
  }

  part def Stretcher {
    attribute primaryFunction : String = "Support, secure, and transport a patient between care locations while allowing caregivers to control height, braking, rails, and movement.";
    attribute systemMass : MassValue = 58 [kg];
    attribute maximumSafeWorkingLoad : MassValue = 250 [kg];
    attribute maximumPatientMass : MassValue = 180 [kg];
    attribute nominalTransportSpeed : SpeedValue = 1.2 [m/s];

    port caregiverInterface : CaregiverControlPort;
    port patientInterface : PatientSupportPort;
    port groundInterface : GroundInterfacePort;

    part frame : Frame;
    part mattress : Mattress;
    part wheels : WheelAssembly;
    part brakes : BrakeSystem;
    part heightAdjuster : HeightAdjustmentSystem;
    part leftRail : SideRail;
    part rightRail : SideRail;
    part restraints : RestraintSystem;
    part loadSensor : LoadSensor;
    part handle : CaregiverHandle;

    connect handle.control to caregiverInterface;
    connect frame.patientSupport to patientInterface;
    connect mattress.support to frame.patientSupport;
    connect loadSensor.status to frame.patientSupport;
    connect wheels.ground to groundInterface;
    connect wheels.brakeControl to brakes.control;

    perform action loadPatient : LoadPatient;
    perform action transportPatient : TransportPatient;
    perform action unloadPatient : UnloadPatient;

    exhibit state operationalBehavior : StretcherOperationalStates;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The stretcher shall support, secure, and enable controlled transport of one patient between care locations. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.maximumPatientMass <= stretcher.maximumSafeWorkingLoad
    }
  }

  requirement def LoadCapacityRequirement {
    doc /* The stretcher shall provide a safe working load of at least 250 kg. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.maximumSafeWorkingLoad >= 250 [kg]
    }
  }

  requirement def PatientSupportRequirement {
    doc /* The stretcher mattress and frame shall support a patient up to the specified maximum patient mass. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.mattress.ratedPatientMass >= stretcher.maximumPatientMass and
      stretcher.frame.ratedSafeWorkingLoad >= stretcher.maximumSafeWorkingLoad
    }
  }

  requirement def MobilityRequirement {
    doc /* The stretcher shall permit caregiver-controlled rolling transport at normal walking speed. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.wheels.maximumTransportSpeed >= 1.5 [m/s]
    }
  }

  requirement def BrakingRequirement {
    doc /* The stretcher shall provide a brake system capable of holding the loaded stretcher stationary during loading, unloading, and treatment. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.brakes.maximumHoldingForce >= 600 [N]
    }
  }

  requirement def HeightAdjustmentRequirement {
    doc /* The stretcher shall support low transfer, transport, and high treatment height modes. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.heightAdjuster.lowHeight < stretcher.heightAdjuster.transportHeight and
      stretcher.heightAdjuster.transportHeight < stretcher.heightAdjuster.highTreatmentHeight
    }
  }

  requirement def SideRailSafetyRequirement {
    doc /* The stretcher shall include side rails that can be locked in the raised position to reduce patient fall risk. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.leftRail.latchHoldingForce >= 300 [N] and
      stretcher.rightRail.latchHoldingForce >= 300 [N]
    }
  }

  requirement def RestraintRequirement {
    doc /* The stretcher shall include restraints sufficient to secure a patient during transport. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.restraints.strapCount >= 3 and
      stretcher.restraints.ratedRestraintForce >= 900 [N]
    }
  }

  requirement def OverloadDetectionRequirement {
    doc /* The stretcher shall detect loads greater than the safe working load and prevent normal transport operation until inspected. */

    subject stretcher : Stretcher;

    require constraint {
      stretcher.loadSensor.overloadLimit == stretcher.maximumSafeWorkingLoad
    }
  }

  satisfy PrimaryFunctionRequirement by Stretcher;
  satisfy LoadCapacityRequirement by Stretcher;
  satisfy PatientSupportRequirement by Stretcher;
  satisfy MobilityRequirement by Stretcher;
  satisfy BrakingRequirement by Stretcher;
  satisfy HeightAdjustmentRequirement by Stretcher;
  satisfy SideRailSafetyRequirement by Stretcher;
  satisfy RestraintRequirement by Stretcher;
  satisfy OverloadDetectionRequirement by Stretcher;

  part stretcherSystem : Stretcher;

}