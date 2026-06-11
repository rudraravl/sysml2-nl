package MammotomeBasedBiopsySystemModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Pressure_kPa :> Real;
  attribute def FlowRate_mL_per_min :> Real;
  attribute def Volume_mL :> Real;
  attribute def Length_mm :> Real;
  attribute def Time_s :> Real;
  attribute def RotationalSpeed_rpm :> Real;
  attribute def Voltage_V :> Real;
  attribute def Temperature_C :> Real;

  enum def ProcedureMode {
    enum idle;
    enum prime;
    enum target;
    enum sample;
    enum lavage;
    enum fault;
    enum shutdown;
  }

  enum def TissueCondition {
    enum intact;
    enum positionedInAperture;
    enum excised;
    enum transported;
    enum preserved;
  }

  item def ElectricalPower {
    attribute voltage : Voltage_V;
    attribute current_A : Real;
  }

  item def ClinicianCommand {
    attribute requestedMode : ProcedureMode;
    attribute cutterEnabled : Boolean;
    attribute vacuumEnabled : Boolean;
  }

  item def TissueSample {
    attribute condition : TissueCondition;
    attribute sampleVolume : Volume_mL;
    attribute sampleLength : Length_mm;
  }

  item def VacuumMedium {
    attribute pressure : Pressure_kPa;
    attribute flowRate : FlowRate_mL_per_min;
  }

  item def SalineFluid {
    attribute volume : Volume_mL;
    attribute flowRate : FlowRate_mL_per_min;
    attribute temperature : Temperature_C;
  }

  item def WasteFluid {
    attribute collectedVolume : Volume_mL;
    attribute containsBlood : Boolean;
    attribute containsSaline : Boolean;
  }

  item def ImagingCoordinate {
    attribute x_mm : Length_mm;
    attribute y_mm : Length_mm;
    attribute z_mm : Length_mm;
    attribute targetingConfirmed : Boolean;
  }

  item def ProcedureData {
    attribute sampleCount : Integer;
    attribute elapsedTime : Time_s;
    attribute activeMode : ProcedureMode;
    attribute vacuumPressure : Pressure_kPa;
    attribute cutterSpeed : RotationalSpeed_rpm;
  }

  port def PowerInPort {
    in item power : ElectricalPower;
  }

  port def CommandInPort {
    in item command : ClinicianCommand;
  }

  port def VacuumPort {
    out item vacuum : VacuumMedium;
  }

  port def FluidPort {
    out item saline : SalineFluid;
    in item waste : WasteFluid;
  }

  port def TissuePort {
    in item targetTissue : TissueSample;
    out item removedSample : TissueSample;
  }

  port def ImagingPort {
    in item coordinate : ImagingCoordinate;
  }

  port def DataPort {
    out item data : ProcedureData;
  }

  part def VacuumPump {
    port powerIn : PowerInPort;
    port vacuumOut : VacuumPort;

    attribute commandedPressure : Pressure_kPa = -70.0;
    attribute minimumPressure : Pressure_kPa = -90.0;
    attribute maximumPressure : Pressure_kPa = -40.0;
    attribute nominalFlowRate : FlowRate_mL_per_min = 250.0;

    action generateVacuum {
      in item electricalPower : ElectricalPower;
      out item vacuum : VacuumMedium;
    }
  }

  part def CutterDrive {
    port powerIn : PowerInPort;

    attribute cutterSpeed : RotationalSpeed_rpm = 1200.0;
    attribute maxCutterSpeed : RotationalSpeed_rpm = 1800.0;
    attribute enabled : Boolean = false;

    action rotateAndAdvanceCutter {
      in attribute enable : Boolean;
      out attribute rotationSpeed : RotationalSpeed_rpm;
    }
  }

  part def ProbeNeedle {
    port tissueInterface : TissuePort;
    port vacuumInterface : VacuumPort;
    port fluidInterface : FluidPort;

    attribute apertureLength : Length_mm = 19.0;
    attribute outerDiameter : Length_mm = 3.0;
    attribute insertionDepth : Length_mm;
    attribute apertureAlignedToTarget : Boolean = false;

    action captureTissueInAperture {
      in item vacuum : VacuumMedium;
      in item targetTissue : TissueSample;
      out item positionedTissue : TissueSample;
    }
  }

  part def SampleTransportPath {
    port vacuumInterface : VacuumPort;
    port sampleInterface : TissuePort;
    port fluidInterface : FluidPort;

    attribute pathVolume : Volume_mL = 4.0;
    attribute obstructionDetected : Boolean = false;

    action transportSample {
      in item excisedSample : TissueSample;
      in item vacuum : VacuumMedium;
      out item transportedSample : TissueSample;
    }
  }

  part def SampleCollectionChamber {
    port sampleIn : TissuePort;
    port fluidIn : FluidPort;

    attribute chamberCapacity : Integer = 24;
    attribute collectedSampleCount : Integer = 0;
    attribute preservativeVolume : Volume_mL = 20.0;

    action preserveSample {
      in item transportedSample : TissueSample;
      out item preservedSample : TissueSample;
    }
  }

  part def FluidManagementUnit {
    port fluidOut : FluidPort;
    port vacuumIn : VacuumPort;

    attribute salineReservoirVolume : Volume_mL = 250.0;
    attribute wasteCanisterCapacity : Volume_mL = 500.0;
    attribute wasteCanisterFill : Volume_mL = 0.0;
    attribute lavageFlowRate : FlowRate_mL_per_min = 120.0;

    action lavageAndAspirate {
      in item saline : SalineFluid;
      in item vacuum : VacuumMedium;
      out item waste : WasteFluid;
    }
  }

  part def ControlConsole {
    port powerIn : PowerInPort;
    port commandIn : CommandInPort;
    port imagingIn : ImagingPort;
    port dataOut : DataPort;

    attribute activeMode : ProcedureMode = ProcedureMode::idle;
    attribute targetLocked : Boolean = false;
    attribute interlockClosed : Boolean = false;
    attribute elapsedProcedureTime : Time_s = 0.0;

    action evaluateCommand {
      in item command : ClinicianCommand;
      in item coordinate : ImagingCoordinate;
      out attribute selectedMode : ProcedureMode;
    }

    action publishProcedureData {
      out item data : ProcedureData;
    }
  }

  part def FootSwitch {
    port commandOut : CommandInPort;

    attribute pressed : Boolean = false;

    action issueSampleCommand {
      out item command : ClinicianCommand;
    }
  }

  part def ImagingGuidanceInterface {
    port coordinateOut : ImagingPort;

    attribute stereotacticCompatible : Boolean = true;
    attribute ultrasoundCompatible : Boolean = true;
    attribute mriCompatible : Boolean = false;

    action provideTargetCoordinate {
      out item coordinate : ImagingCoordinate;
    }
  }

  part def MammotomeBasedVacuumAssistedBiopsySystem {
    port facilityPower : PowerInPort;
    port clinicianInput : CommandInPort;
    port imagingInput : ImagingPort;
    port tissueAccess : TissuePort;
    port procedureRecord : DataPort;

    part console : ControlConsole;
    part pump : VacuumPump;
    part cutterDrive : CutterDrive;
    part probe : ProbeNeedle;
    part transportPath : SampleTransportPath;
    part sampleChamber : SampleCollectionChamber;
    part fluidManagement : FluidManagementUnit;
    part footSwitch : FootSwitch;
    part imagingInterface : ImagingGuidanceInterface;

    attribute primaryFunction : String =
      "Acquire multiple contiguous breast tissue specimens through a single minimally invasive probe insertion by applying controlled vacuum, positioning tissue in a side aperture, excising the tissue with a powered cutter, transporting samples to a collection chamber, and supporting lavage and aspiration.";

    attribute nominalVacuumPressure : Pressure_kPa = -70.0;
    attribute nominalSampleVolume : Volume_mL = 1.2;
    attribute maximumSamplesPerInsertion : Integer = 24;
    attribute singleInsertionSampling : Boolean = true;

    connect facilityPower.power to console.powerIn.power;
    connect facilityPower.power to pump.powerIn.power;
    connect facilityPower.power to cutterDrive.powerIn.power;

    connect clinicianInput.command to console.commandIn.command;
    connect footSwitch.commandOut.command to console.commandIn.command;

    connect imagingInput.coordinate to console.imagingIn.coordinate;
    connect imagingInterface.coordinateOut.coordinate to console.imagingIn.coordinate;

    connect pump.vacuumOut.vacuum to probe.vacuumInterface.vacuum;
    connect pump.vacuumOut.vacuum to transportPath.vacuumInterface.vacuum;
    connect pump.vacuumOut.vacuum to fluidManagement.vacuumIn.vacuum;

    connect probe.tissueInterface.removedSample to transportPath.sampleInterface.targetTissue;
    connect transportPath.sampleInterface.removedSample to sampleChamber.sampleIn.targetTissue;

    connect fluidManagement.fluidOut.saline to probe.fluidInterface.saline;
    connect probe.fluidInterface.waste to fluidManagement.fluidOut.waste;
    connect fluidManagement.fluidOut.saline to transportPath.fluidInterface.saline;
    connect transportPath.fluidInterface.waste to fluidManagement.fluidOut.waste;

    connect console.dataOut.data to procedureRecord.data;

    action performVacuumAssistedBiopsy {
      in item targetCoordinate : ImagingCoordinate;
      in item clinicianCommand : ClinicianCommand;
      in item targetTissue : TissueSample;
      out item preservedSamples : TissueSample;
      out item procedureData : ProcedureData;

      first startSystem;
      then verifyTarget;
      then applyVacuum;
      then drawTissueIntoAperture;
      then exciseTissue;
      then transportExcisedSample;
      then preserveExcisedSample;
      then lavageAndAspirateSite;
      then recordProcedure;

      action startSystem {
        out attribute ready : Boolean;
      }

      action verifyTarget {
        in item targetCoordinate : ImagingCoordinate;
        out attribute targetAccepted : Boolean;
      }

      action applyVacuum {
        out item vacuum : VacuumMedium;
      }

      action drawTissueIntoAperture {
        in item vacuum : VacuumMedium;
        in item targetTissue : TissueSample;
        out item positionedTissue : TissueSample;
      }

      action exciseTissue {
        in item positionedTissue : TissueSample;
        out item excisedSample : TissueSample;
      }

      action transportExcisedSample {
        in item excisedSample : TissueSample;
        out item transportedSample : TissueSample;
      }

      action preserveExcisedSample {
        in item transportedSample : TissueSample;
        out item preservedSamples : TissueSample;
      }

      action lavageAndAspirateSite {
        out item waste : WasteFluid;
      }

      action recordProcedure {
        out item procedureData : ProcedureData;
      }
    }

    state def ProcedureStateMachine {
      entry action console.evaluateCommand;

      state Idle;
      state Priming;
      state Targeting;
      state Armed;
      state VacuumCapture;
      state Cutting;
      state SampleTransport;
      state Lavage;
      state Complete;
      state Fault;
      state Shutdown;

      transition initial then Idle;

      transition Idle_to_Priming
        first Idle
        accept ClinicianCommand
        if command.requestedMode == ProcedureMode::prime
        then Priming;

      transition Priming_to_Targeting
        first Priming
        if fluidManagement.salineReservoirVolume > 20.0
        then Targeting;

      transition Targeting_to_Armed
        first Targeting
        accept ImagingCoordinate
        if coordinate.targetingConfirmed == true
        then Armed;

      transition Armed_to_VacuumCapture
        first Armed
        accept ClinicianCommand
        if command.vacuumEnabled == true and console.interlockClosed == true
        then VacuumCapture;

      transition VacuumCapture_to_Cutting
        first VacuumCapture
        accept ClinicianCommand
        if command.cutterEnabled == true
        then Cutting;

      transition Cutting_to_SampleTransport
        first Cutting
        then SampleTransport;

      transition SampleTransport_to_Lavage
        first SampleTransport
        if sampleChamber.collectedSampleCount < maximumSamplesPerInsertion
        then Lavage;

      transition Lavage_to_Armed
        first Lavage
        accept ClinicianCommand
        if command.requestedMode == ProcedureMode::sample
        then Armed;

      transition Lavage_to_Complete
        first Lavage
        accept ClinicianCommand
        if command.requestedMode == ProcedureMode::shutdown
        then Complete;

      transition Any_to_Fault
        first Idle, Priming, Targeting, Armed, VacuumCapture, Cutting, SampleTransport, Lavage
        if transportPath.obstructionDetected == true or fluidManagement.wasteCanisterFill >= fluidManagement.wasteCanisterCapacity
        then Fault;

      transition Fault_to_Shutdown
        first Fault
        accept ClinicianCommand
        if command.requestedMode == ProcedureMode::shutdown
        then Shutdown;

      transition Complete_to_Shutdown
        first Complete
        then Shutdown;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : MammotomeBasedVacuumAssistedBiopsySystem;

    require constraint {
      system.singleInsertionSampling == true
    }

    require constraint {
      system.maximumSamplesPerInsertion >= 12
    }
  }

  requirement def ControlledVacuumRequirement {
    subject system : MammotomeBasedVacuumAssistedBiopsySystem;

    require constraint {
      system.nominalVacuumPressure <= -40.0 and system.nominalVacuumPressure >= -90.0
    }
  }

  requirement def SampleCollectionRequirement {
    subject system : MammotomeBasedVacuumAssistedBiopsySystem;

    require constraint {
      system.sampleChamber.chamberCapacity >= system.maximumSamplesPerInsertion
    }
  }

  requirement def TargetingInterlockRequirement {
    subject system : MammotomeBasedVacuumAssistedBiopsySystem;

    require constraint {
      system.console.targetLocked == true implies system.console.interlockClosed == true
    }
  }

  requirement def FluidContainmentRequirement {
    subject system : MammotomeBasedVacuumAssistedBiopsySystem;

    require constraint {
      system.fluidManagement.wasteCanisterCapacity >= 2.0 * system.fluidManagement.salineReservoirVolume
    }
  }

  requirement def ProcedureDataRequirement {
    subject system : MammotomeBasedVacuumAssistedBiopsySystem;

    require constraint {
      system.console.elapsedProcedureTime >= 0.0
    }
  }

  satisfy PrimaryFunctionRequirement by MammotomeBasedVacuumAssistedBiopsySystem;
  satisfy ControlledVacuumRequirement by VacuumPump;
  satisfy SampleCollectionRequirement by SampleCollectionChamber;
  satisfy TargetingInterlockRequirement by ControlConsole;
  satisfy FluidContainmentRequirement by FluidManagementUnit;
  satisfy ProcedureDataRequirement by ControlConsole;
}