package DentalInstrumentModel {
  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Frequency :> scalar;
  attribute def FlowRate :> scalar;
  attribute def Pressure :> scalar;
  attribute def PowerLevel :> scalar;
  attribute def Temperature :> scalar;
  attribute def Force :> scalar;
  attribute def TimeDuration :> scalar;

  item def ElectricalEnergy {
    attribute voltage : Real;
    attribute current : Real;
    attribute frequency : Frequency;
  }

  item def CoolingWater {
    attribute flowRate : FlowRate;
    attribute pressure : Pressure;
    attribute temperature : Temperature;
  }

  item def AcousticVibration {
    attribute tipFrequency : Frequency;
    attribute amplitude : Real;
    attribute deliveredPower : PowerLevel;
  }

  item def DentalDebris {
    attribute calculusMass : Real;
    attribute biofilmMass : Real;
  }

  item def OperatorCommand {
    attribute requestedPower : PowerLevel;
    attribute waterEnabled : Boolean;
    attribute activationRequested : Boolean;
  }

  port def ElectricalPowerPort {
    in item energy : ElectricalEnergy;
  }

  port def WaterInletPort {
    in item water : CoolingWater;
  }

  port def ControlInputPort {
    in item command : OperatorCommand;
  }

  port def VibrationOutputPort {
    out item vibration : AcousticVibration;
  }

  port def IrrigationOutputPort {
    out item water : CoolingWater;
  }

  port def DebrisRemovalPort {
    out item removedMaterial : DentalDebris;
  }

  port def ToothContactPort {
    inout item vibration : AcousticVibration;
    inout item irrigation : CoolingWater;
    out item removedMaterial : DentalDebris;
  }

  action def ConvertElectricalPowerToVibration {
    in item inputEnergy : ElectricalEnergy;
    in attribute selectedPower : PowerLevel;
    out item outputVibration : AcousticVibration;

    constraint conversionLimit {
      outputVibration.deliveredPower <= selectedPower
    }
  }

  action def RegulateCoolingWater {
    in item inletWater : CoolingWater;
    in attribute waterEnabled : Boolean;
    out item outletWater : CoolingWater;

    constraint safeFlow {
      if waterEnabled then outletWater.flowRate >= 20.0 else outletWater.flowRate == 0.0
    }
  }

  action def RemoveCalculusAndBiofilm {
    in item vibration : AcousticVibration;
    in item irrigation : CoolingWater;
    out item debris : DentalDebris;

    constraint effectiveScaling {
      vibration.tipFrequency >= 25000.0 and vibration.tipFrequency <= 32000.0
    }
  }

  state def InstrumentOperatingState {
    state Off;
    state Standby;
    state Ready;
    state ActiveScaling;
    state CoolingFlush;
    state Fault;

    transition Off_to_Standby
      first Off
      then Standby;

    transition Standby_to_Ready
      first Standby
      then Ready;

    transition Ready_to_ActiveScaling
      first Ready
      then ActiveScaling;

    transition ActiveScaling_to_CoolingFlush
      first ActiveScaling
      then CoolingFlush;

    transition CoolingFlush_to_Ready
      first CoolingFlush
      then Ready;

    transition Any_to_Fault
      first Ready
      then Fault;

    transition Fault_to_Standby
      first Fault
      then Standby;
  }

  part def Handpiece {
    port electricalInput : ElectricalPowerPort;
    port controlInput : ControlInputPort;
    port vibrationOutput : VibrationOutputPort;

    attribute housingTemperature : Temperature;
    attribute mass : Real;
    attribute gripDiameter : Real;

    part piezoelectricStack {
      attribute resonantFrequency : Frequency = 30000.0;
      attribute maximumPower : PowerLevel = 12.0;
    }

    part vibrationCoupler {
      attribute mechanicalEfficiency : Real = 0.86;
    }

    perform action ConvertElectricalPowerToVibration;
  }

  part def ScalingTip {
    port vibrationInput : VibrationOutputPort;
    port toothInterface : ToothContactPort;

    attribute tipLength : Real = 28.0;
    attribute tipDiameter : Real = 0.6;
    attribute maximumContactForce : Force = 1.5;
    attribute nominalAmplitude : Real = 75.0;
  }

  part def WaterControlModule {
    port waterInput : WaterInletPort;
    port controlInput : ControlInputPort;
    port irrigationOutput : IrrigationOutputPort;

    attribute minimumFlowRate : FlowRate = 20.0;
    attribute maximumFlowRate : FlowRate = 60.0;
    attribute maximumPressure : Pressure = 350000.0;

    part solenoidValve {
      attribute responseTime : TimeDuration = 0.08;
    }

    part flowRestrictor {
      attribute nominalRestriction : Real = 0.45;
    }

    perform action RegulateCoolingWater;
  }

  part def FootControl {
    port commandOutput : ControlInputPort;

    attribute pedalTravel : Real;
    attribute activationThreshold : Real = 0.25;
    attribute selectedPower : PowerLevel;
  }

  part def Console {
    port mainsInput : ElectricalPowerPort;
    port waterInput : WaterInletPort;
    port handpiecePowerOutput : ElectricalPowerPort;
    port waterOutput : WaterInletPort;
    port controlInput : ControlInputPort;
    port handpieceControlOutput : ControlInputPort;
    port waterControlOutput : ControlInputPort;

    attribute selectedMode : String;
    attribute selectedPower : PowerLevel = 6.0;
    attribute supplyVoltage : Real = 120.0;
    attribute maximumOutputPower : PowerLevel = 15.0;

    part powerSupply {
      attribute outputVoltage : Real = 48.0;
      attribute overloadLimit : PowerLevel = 16.0;
    }

    part controller {
      attribute samplePeriod : TimeDuration = 0.01;
      attribute faultDetected : Boolean;
    }

    state operatingState : InstrumentOperatingState;
  }

  part def PatientToothSurface {
    port treatmentInterface : ToothContactPort;

    attribute enamelTemperature : Temperature = 37.0;
    attribute calculusThickness : Real;
    attribute gingivalProximity : Real;
  }

  part def DentalUltrasonicScalerSystem {
    port facilityPower : ElectricalPowerPort;
    port facilityWater : WaterInletPort;
    port clinicianInput : ControlInputPort;
    port toothInterface : ToothContactPort;
    port debrisOutput : DebrisRemovalPort;

    attribute primaryFunction : String =
      "Remove calculus and biofilm from tooth surfaces by delivering controlled ultrasonic tip vibration with cooling irrigation.";

    part console : Console;
    part footControl : FootControl;
    part waterControl : WaterControlModule;
    part handpiece : Handpiece;
    part scalingTip : ScalingTip;
    part toothSurface : PatientToothSurface;

    connect facilityPower to console.mainsInput;
    connect facilityWater to console.waterInput;
    connect clinicianInput to footControl.commandOutput;
    connect footControl.commandOutput to console.controlInput;
    connect console.handpiecePowerOutput to handpiece.electricalInput;
    connect console.handpieceControlOutput to handpiece.controlInput;
    connect console.waterControlOutput to waterControl.controlInput;
    connect console.waterOutput to waterControl.waterInput;
    connect waterControl.irrigationOutput to scalingTip.toothInterface;
    connect handpiece.vibrationOutput to scalingTip.vibrationInput;
    connect scalingTip.toothInterface to toothSurface.treatmentInterface;
    connect toothSurface.treatmentInterface to toothInterface;
    connect toothSurface.treatmentInterface to debrisOutput;

    perform action ConvertElectricalPowerToVibration;
    perform action RegulateCoolingWater;
    perform action RemoveCalculusAndBiofilm;
  }

  requirement def PrimaryDentalInstrumentFunction {
    subject scaler : DentalUltrasonicScalerSystem;

    doc /* The dental instrument shall provide a controlled ultrasonic scaling function that removes calculus and biofilm from tooth surfaces while limiting heat generation and operator-applied force. */

    require constraint {
      scaler.handpiece.piezoelectricStack.resonantFrequency >= 25000.0 and
      scaler.handpiece.piezoelectricStack.resonantFrequency <= 32000.0
    }
  }

  requirement def CoolingRequirement {
    subject scaler : DentalUltrasonicScalerSystem;

    doc /* When ultrasonic vibration is active, the system shall deliver cooling irrigation to the scaling tip. */

    require constraint {
      scaler.waterControl.minimumFlowRate >= 20.0 and
      scaler.waterControl.maximumFlowRate <= 60.0
    }
  }

  requirement def TipForceRequirement {
    subject scaler : DentalUltrasonicScalerSystem;

    doc /* The scaling tip shall support effective dental calculus removal without requiring excessive contact force against the tooth surface. */

    require constraint {
      scaler.scalingTip.maximumContactForce <= 1.5
    }
  }

  requirement def ElectricalSafetyRequirement {
    subject scaler : DentalUltrasonicScalerSystem;

    doc /* The console shall limit output power to the handpiece during clinical operation. */

    require constraint {
      scaler.console.maximumOutputPower <= 15.0
    }
  }

  requirement def ThermalProtectionRequirement {
    subject scaler : DentalUltrasonicScalerSystem;

    doc /* The handpiece housing temperature shall remain within a clinically acceptable handling limit during normal scaling. */

    require constraint {
      scaler.handpiece.housingTemperature <= 45.0
    }
  }

  satisfy PrimaryDentalInstrumentFunction by DentalUltrasonicScalerSystem;
  satisfy CoolingRequirement by WaterControlModule;
  satisfy TipForceRequirement by ScalingTip;
  satisfy ElectricalSafetyRequirement by Console;
  satisfy ThermalProtectionRequirement by Handpiece;
}