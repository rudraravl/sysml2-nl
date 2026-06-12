package LVDTDisplacementMeasurementSystem {

  import ScalarValues::*;

  attribute def Voltage :> Real {
    unit = "V";
  }

  attribute def Current :> Real {
    unit = "A";
  }

  attribute def Frequency :> Real {
    unit = "Hz";
  }

  attribute def Displacement :> Real {
    unit = "mm";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def LinearityError :> Real {
    unit = "% full scale";
  }

  attribute def Time :> Real {
    unit = "ms";
  }

  item def ACExcitationSignal {
    attribute rmsVoltage : Voltage;
    attribute frequency : Frequency;
  }

  item def DifferentialVoltageSignal {
    attribute magnitude : Voltage;
    attribute phaseDegrees : Real;
    attribute frequency : Frequency;
  }

  item def LinearPositionEstimate {
    attribute displacement : Displacement;
    attribute valid : Boolean;
    attribute timestamp : Time;
  }

  port def ElectricalPowerPort {
    out item excitation : ACExcitationSignal;
  }

  port def DifferentialSignalPort {
    out item differentialSignal : DifferentialVoltageSignal;
  }

  port def PositionDataPort {
    out item position : LinearPositionEstimate;
  }

  port def MechanicalMotionPort {
    in attribute axialDisplacement : Displacement;
  }

  part def PrimaryCoil {
    port excitationInput : ElectricalPowerPort;

    attribute nominalExcitationVoltage : Voltage = 5.0;
    attribute nominalExcitationFrequency : Frequency = 5000.0;
    attribute windingResistance : Real = 120.0;
  }

  part def SecondaryCoil {
    port signalOutput : DifferentialSignalPort;

    attribute windingResistance : Real = 180.0;
    attribute nominalSensitivity : Real = 0.25;
  }

  part def FerromagneticCore {
    port motionInput : MechanicalMotionPort;

    attribute strokeRange : Displacement = 25.0;
    attribute nullPosition : Displacement = 0.0;
    attribute currentPosition : Displacement;
  }

  part def SignalConditioner {
    port differentialInput : DifferentialSignalPort;
    port positionOutput : PositionDataPort;

    attribute demodulationFrequency : Frequency = 5000.0;
    attribute lowPassCutoffFrequency : Frequency = 250.0;
    attribute gain : Real = 4.0;
    attribute offsetCorrection : Displacement = 0.0;
  }

  part def ExcitationSource {
    port excitationOutput : ElectricalPowerPort;

    attribute outputVoltage : Voltage = 5.0;
    attribute outputFrequency : Frequency = 5000.0;
    attribute currentLimit : Current = 0.05;
  }

  action def GenerateACExcitation {
    out item excitation : ACExcitationSignal;

    attribute voltageSetpoint : Voltage = 5.0;
    attribute frequencySetpoint : Frequency = 5000.0;
  }

  action def ConvertMotionToDifferentialVoltage {
    in attribute corePosition : Displacement;
    in item excitation : ACExcitationSignal;
    out item differentialSignal : DifferentialVoltageSignal;

    attribute sensitivity : Real = 0.25;
  }

  action def DemodulateAndScalePosition {
    in item differentialSignal : DifferentialVoltageSignal;
    out item positionEstimate : LinearPositionEstimate;

    attribute scaleFactor : Real = 4.0;
    attribute nullOffset : Displacement = 0.0;
  }

  state def LVDTMeasurementStateMachine {
    state Off;
    state ExcitingPrimary;
    state SensingCorePosition;
    state ConditioningSignal;
    state ReportingPosition;
    state FaultDetected;

    transition InitialToOff
      first Off;

    transition PowerApplied
      first Off
      then ExcitingPrimary;

    transition ExcitationStable
      first ExcitingPrimary
      then SensingCorePosition;

    transition SignalDetected
      first SensingCorePosition
      then ConditioningSignal;

    transition PositionComputed
      first ConditioningSignal
      then ReportingPosition;

    transition ContinueMeasurement
      first ReportingPosition
      then SensingCorePosition;

    transition ExcitationFault
      first ExcitingPrimary
      then FaultDetected;

    transition SignalOutOfRange
      first SensingCorePosition
      then FaultDetected;

    transition ResetFault
      first FaultDetected
      then Off;
  }

  part def LVDTSensorAssembly {
    port mechanicalInput : MechanicalMotionPort;
    port measuredPositionOutput : PositionDataPort;

    part excitationSource : ExcitationSource;
    part primaryCoil : PrimaryCoil;
    part secondaryA : SecondaryCoil;
    part secondaryB : SecondaryCoil;
    part movableCore : FerromagneticCore;
    part conditioner : SignalConditioner;

    attribute measurementRange : Displacement = 25.0;
    attribute linearity : LinearityError = 0.5;
    attribute operatingTemperatureMin : Temperature = -40.0;
    attribute operatingTemperatureMax : Temperature = 85.0;

    connect excitationSource.excitationOutput to primaryCoil.excitationInput;
    connect mechanicalInput to movableCore.motionInput;
    connect secondaryA.signalOutput to conditioner.differentialInput;
    connect secondaryB.signalOutput to conditioner.differentialInput;
    connect conditioner.positionOutput to measuredPositionOutput;

    perform action excite : GenerateACExcitation;
    perform action transduce : ConvertMotionToDifferentialVoltage;
    perform action condition : DemodulateAndScalePosition;

    exhibit state behavior : LVDTMeasurementStateMachine;
  }

  requirement def PrimaryFunctionRequirement {
    subject sensor : LVDTSensorAssembly;

    require constraint {
      sensor.measuredPositionOutput.position.valid == true
    }

    doc
      /*
       The Linear Variable Differential Transformer system shall convert axial
       displacement of a movable ferromagnetic core into an electrical position
       estimate by exciting a primary coil, sensing the differential secondary
       coil response, demodulating the AC signal, and reporting linear position.
      */
  }

  requirement def MeasurementRangeRequirement {
    subject sensor : LVDTSensorAssembly;

    require constraint {
      sensor.measurementRange >= 25.0
    }
  }

  requirement def LinearityRequirement {
    subject sensor : LVDTSensorAssembly;

    require constraint {
      sensor.linearity <= 0.5
    }
  }

  requirement def ExcitationRequirement {
    subject sensor : LVDTSensorAssembly;

    require constraint {
      sensor.primaryCoil.nominalExcitationVoltage == 5.0 and
      sensor.primaryCoil.nominalExcitationFrequency == 5000.0
    }
  }

  requirement def EnvironmentalRequirement {
    subject sensor : LVDTSensorAssembly;

    require constraint {
      sensor.operatingTemperatureMin <= -40.0 and
      sensor.operatingTemperatureMax >= 85.0
    }
  }

  part lvdtSystem : LVDTSensorAssembly {
    satisfy PrimaryFunctionRequirement;
    satisfy MeasurementRangeRequirement;
    satisfy LinearityRequirement;
    satisfy ExcitationRequirement;
    satisfy EnvironmentalRequirement;
  }
}