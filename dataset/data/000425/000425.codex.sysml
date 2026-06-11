package ArtificialUrinarySphincterSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def PressureValue :> Real {
    unit = "cmH2O";
  }

  attribute def VolumeValue :> Real {
    unit = "mL";
  }

  attribute def TimeValue :> Real {
    unit = "s";
  }

  attribute def ForceValue :> Real {
    unit = "N";
  }

  attribute def FlowRateValue :> Real {
    unit = "mL/s";
  }

  attribute def StateOfChargeValue :> Real {
    unit = "%";
  }

  item def HydraulicFluid {
    attribute volume : VolumeValue;
    attribute pressure : PressureValue;
    attribute biocompatible : Boolean;
  }

  item def Urine {
    attribute flowRate : FlowRateValue;
    attribute sterilePathMaintained : Boolean;
  }

  item def ControlSignal {
    attribute command : ControlCommandKind;
    attribute timestamp : TimeValue;
  }

  enum def ControlCommandKind {
    enum inflateCuff;
    enum deflateCuff;
    enum holdPressure;
    enum enterSafeMode;
    enum selfTest;
  }

  enum def ContinenceModeKind {
    enum continence;
    enum voiding;
    enum refill;
    enum safeOpen;
    enum fault;
  }

  port def HydraulicPort {
    inout fluid : HydraulicFluid;
  }

  port def UrethralInterfacePort {
    inout urine : Urine;
    attribute appliedCompressionPressure : PressureValue;
    attribute urethralPatency : Boolean;
  }

  port def PatientManualPort {
    in command : ControlSignal;
    out feedback : ControlSignal;
  }

  port def DiagnosticPort {
    out diagnosticStatus : ControlSignal;
  }

  part def OcclusiveCuff {
    port hydraulicPort : HydraulicPort;
    port urethralInterface : UrethralInterfacePort;

    attribute innerDiameter : Real {
      unit = "mm";
    }

    attribute cuffPressure : PressureValue;
    attribute nominalOcclusionPressure : PressureValue = 65.0;
    attribute maximumSafePressure : PressureValue = 90.0;
    attribute minimumContinencePressure : PressureValue = 45.0;
    attribute inflated : Boolean;

    action inflate {
      in suppliedFluid : HydraulicFluid;
      out achievedPressure : PressureValue;
    }

    action deflate {
      out returnedFluid : HydraulicFluid;
      out residualPressure : PressureValue;
    }
  }

  part def PressureRegulatingBalloon {
    port hydraulicPort : HydraulicPort;

    attribute storedVolume : VolumeValue;
    attribute setPointPressure : PressureValue = 65.0;
    attribute compliance : Real {
      unit = "mL/cmH2O";
    }

    action regulatePressure {
      in systemFluid : HydraulicFluid;
      out regulatedFluid : HydraulicFluid;
    }
  }

  part def ManualPump {
    port cuffSide : HydraulicPort;
    port reservoirSide : HydraulicPort;
    port patientInterface : PatientManualPort;

    attribute pumpStrokeVolume : VolumeValue = 0.35;
    attribute activationForce : ForceValue = 12.0;
    attribute lockoutTime : TimeValue = 4.0;
    attribute cyclesToDeflate : Integer = 3;

    action transferFluidToReservoir {
      in strokeCount : Integer;
      out displacedVolume : VolumeValue;
    }

    action transferFluidToCuff {
      in refillPressure : PressureValue;
      out displacedVolume : VolumeValue;
    }

    action acceptPatientCommand {
      in command : ControlSignal;
      out accepted : Boolean;
    }
  }

  part def FlowRestrictor {
    port cuffSide : HydraulicPort;
    port reservoirSide : HydraulicPort;

    attribute refillDelay : TimeValue = 180.0;
    attribute maximumRefillFlowRate : FlowRateValue = 0.02;

    action meterRefillFlow {
      in pressureDifference : PressureValue;
      out refillFlow : FlowRateValue;
    }
  }

  part def ControlModule {
    port patientPort : PatientManualPort;
    port diagnosticPort : DiagnosticPort;

    attribute currentMode : ContinenceModeKind;
    attribute cuffPressureEstimate : PressureValue;
    attribute voidingWindowRemaining : TimeValue;
    attribute selfTestPassed : Boolean;

    action interpretPumpSequence {
      in command : ControlSignal;
      out requestedMode : ContinenceModeKind;
    }

    action monitorSafetyLimits {
      in measuredPressure : PressureValue;
      out safe : Boolean;
    }

    state def ContinenceControl {
      state Continence {
        entry action holdUrethralOcclusion;
        transition to Voiding
          accept ControlSignal
          if command == ControlCommandKind::deflateCuff;
        transition to Fault
          if cuffPressureEstimate > 90.0;
      }

      state Voiding {
        entry action openUrethralLumen;
        do action maintainVoidingWindow;
        transition to Refill
          after 120.0;
        transition to Fault
          if selfTestPassed == false;
      }

      state Refill {
        entry action meterCuffRefill;
        transition to Continence
          after 180.0
          if cuffPressureEstimate >= 45.0;
        transition to SafeOpen
          if cuffPressureEstimate > 90.0;
      }

      state SafeOpen {
        entry action relieveCuffPressure;
        transition to Fault
          after 10.0;
      }

      state Fault {
        entry action reportDiagnosticFault;
      }

      initial then Continence;
    }
  }

  part def DiagnosticSensorSet {
    port hydraulicSensePort : HydraulicPort;
    port diagnosticPort : DiagnosticPort;

    attribute measuredCuffPressure : PressureValue;
    attribute measuredReservoirPressure : PressureValue;
    attribute leakDetected : Boolean;
    attribute blockageDetected : Boolean;

    action sampleHydraulicPressure {
      out cuffPressure : PressureValue;
      out reservoirPressure : PressureValue;
    }

    action detectAbnormalCondition {
      in cuffPressure : PressureValue;
      in reservoirPressure : PressureValue;
      out faultPresent : Boolean;
    }
  }

  part def PatientUrethra {
    port urethralInterface : UrethralInterfacePort;

    attribute urethralClosingPressure : PressureValue = 40.0;
    attribute urineFlowDuringVoiding : FlowRateValue;
    attribute lumenOpen : Boolean;
  }

  part def ArtificialUrinarySphincter {
    port patientCommandPort : PatientManualPort;
    port diagnosticPort : DiagnosticPort;
    port urethralPort : UrethralInterfacePort;

    part cuff : OcclusiveCuff {
      attribute innerDiameter = 40.0;
      attribute cuffPressure = 65.0;
      attribute inflated = true;
    }

    part reservoir : PressureRegulatingBalloon {
      attribute storedVolume = 22.0;
      attribute compliance = 0.28;
    }

    part pump : ManualPump;
    part restrictor : FlowRestrictor;
    part controller : ControlModule;
    part sensors : DiagnosticSensorSet;

    connect pump.cuffSide to cuff.hydraulicPort;
    connect pump.reservoirSide to reservoir.hydraulicPort;
    connect restrictor.cuffSide to cuff.hydraulicPort;
    connect restrictor.reservoirSide to reservoir.hydraulicPort;
    connect sensors.hydraulicSensePort to cuff.hydraulicPort;
    connect cuff.urethralInterface to urethralPort;
    connect patientCommandPort to pump.patientInterface;
    connect patientCommandPort to controller.patientPort;
    connect sensors.diagnosticPort to diagnosticPort;
    connect controller.diagnosticPort to diagnosticPort;

    action provideContinence {
      in bladderUrine : Urine;
      out retainedUrine : Urine;

      first start;
      then sensePressure;
      then regulateCuffPressure;
      then compressUrethra;
      then confirmContinence;
      then done;

      action sensePressure {
        out sensedPressure : PressureValue;
      }

      action regulateCuffPressure {
        in sensedPressure : PressureValue;
        out regulatedPressure : PressureValue;
      }

      action compressUrethra {
        in regulatedPressure : PressureValue;
        out urethralClosed : Boolean;
      }

      action confirmContinence {
        in urethralClosed : Boolean;
        out continenceAchieved : Boolean;
      }
    }

    action enableVoiding {
      in patientCommand : ControlSignal;
      out urineFlow : Urine;

      first receiveCommand;
      then deflateOcclusiveCuff;
      then openUrethralLumen;
      then allowUrineFlow;
      then beginTimedRefill;
      then completeVoidingCycle;

      action receiveCommand {
        in command : ControlSignal;
        out validCommand : Boolean;
      }

      action deflateOcclusiveCuff {
        in validCommand : Boolean;
        out cuffPressureAfterDeflation : PressureValue;
      }

      action openUrethralLumen {
        in cuffPressureAfterDeflation : PressureValue;
        out lumenOpen : Boolean;
      }

      action allowUrineFlow {
        in lumenOpen : Boolean;
        out voidingFlowRate : FlowRateValue;
      }

      action beginTimedRefill {
        out refillStarted : Boolean;
      }

      action completeVoidingCycle {
        out continenceRestored : Boolean;
      }
    }
  }

  part ausSystem : ArtificialUrinarySphincter;

  part patientUrethra : PatientUrethra;

  connect ausSystem.urethralPort to patientUrethra.urethralInterface;

  requirement def PrimaryFunctionRequirement {
    subject device : ArtificialUrinarySphincter;

    require constraint {
      device.cuff.cuffPressure >= device.cuff.minimumContinencePressure and
      device.cuff.cuffPressure <= device.cuff.maximumSafePressure
    }

    doc /* The artificial urinary sphincter shall provide urinary continence by hydraulically inflating a cuff around the urethra to maintain urethral closure during normal activity, and shall allow intentional voiding when the patient manually activates the pump to temporarily reduce cuff pressure. */
  }

  requirement def VoidingActivationRequirement {
    subject device : ArtificialUrinarySphincter;

    require constraint {
      device.pump.cyclesToDeflate >= 2 and
      device.pump.cyclesToDeflate <= 5
    }

    doc /* The system shall transition from continence mode to voiding mode only after a deliberate patient pump activation sequence. */
  }

  requirement def AutomaticRefillRequirement {
    subject device : ArtificialUrinarySphincter;

    require constraint {
      device.restrictor.refillDelay >= 120.0 and
      device.restrictor.refillDelay <= 240.0
    }

    doc /* After voiding, the system shall automatically refill the cuff through a restricted hydraulic path to restore urethral occlusion without requiring an additional patient command. */
  }

  requirement def PressureSafetyRequirement {
    subject device : ArtificialUrinarySphincter;

    require constraint {
      device.cuff.maximumSafePressure <= 90.0
    }

    doc /* The system shall limit cuff pressure to reduce the risk of urethral tissue injury. */
  }

  requirement def DiagnosticRequirement {
    subject device : ArtificialUrinarySphincter;

    require constraint {
      device.sensors.leakDetected == false and
      device.sensors.blockageDetected == false
    }

    doc /* The system shall detect abnormal hydraulic conditions such as leakage, blockage, or excessive cuff pressure and report a diagnostic fault. */
  }

  satisfy PrimaryFunctionRequirement by ausSystem;
  satisfy VoidingActivationRequirement by ausSystem;
  satisfy AutomaticRefillRequirement by ausSystem;
  satisfy PressureSafetyRequirement by ausSystem;
  satisfy DiagnosticRequirement by ausSystem;
}