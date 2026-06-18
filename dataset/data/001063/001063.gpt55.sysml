package GalvanometerPrimaryFunctionModel {
  import ScalarValues::*;

  attribute def Current_A :> Real {
    doc "Electric current; unit: ampere (A)."
  }

  attribute def Current_mA :> Real {
    doc "Electric current; unit: milliampere (mA). 1 mA = 0.001 A."
  }

  attribute def Voltage_V :> Real {
    doc "Electric potential difference; unit: volt (V)."
  }

  attribute def Resistance_Ohm :> Real {
    doc "Electrical resistance; unit: ohm (ohm)."
  }

  attribute def MagneticFluxDensity_T :> Real {
    doc "Magnetic flux density; unit: tesla (T)."
  }

  attribute def Area_m2 :> Real {
    doc "Area; unit: square meter (m^2)."
  }

  attribute def Torque_Nm :> Real {
    doc "Torque; unit: newton meter (N*m)."
  }

  attribute def Angle_deg :> Real {
    doc "Angular deflection; unit: degree (deg)."
  }

  attribute def AngularVelocity_deg_per_s :> Real {
    doc "Angular velocity; unit: degree per second (deg/s)."
  }

  attribute def SpringConstant_Nm_per_deg :> Real {
    doc "Torsional spring constant; unit: newton meter per degree (N*m/deg)."
  }

  attribute def DampingCoefficient_Nm_s_per_deg :> Real {
    doc "Rotational damping coefficient; unit: newton meter second per degree (N*m*s/deg)."
  }

  attribute def Sensitivity_deg_per_mA :> Real {
    doc "Pointer sensitivity; unit: degree per milliampere (deg/mA)."
  }

  attribute def Time_s :> Real {
    doc "Time; unit: second (s)."
  }

  attribute def ScaleDivision :> Real {
    doc "Readable scale division count; unit: division."
  }

  enum def CurrentPolarity {
    enum positive;
    enum negative;
    enum zero;
  }

  enum def IndicationValidity {
    enum valid;
    enum settling;
    enum overRange;
    enum notPowered;
    enum fault;
  }

  item def ElectricalCurrent {
    attribute magnitude : Current_mA;
    attribute polarity : CurrentPolarity;
  }

  item def ElectricalPotential {
    attribute value : Voltage_V;
  }

  item def CoilTorque {
    attribute value : Torque_Nm;
  }

  item def ShaftAngle {
    attribute value : Angle_deg;
  }

  item def PointerReading {
    attribute indicatedCurrent : Current_mA;
    attribute deflection : Angle_deg;
    attribute polarity : CurrentPolarity;
    attribute validity : IndicationValidity;
  }

  item def MagneticField {
    attribute fluxDensity : MagneticFluxDensity_T;
    attribute uniformityRatio : Real;
  }

  item def OpticalScaleMark {
    attribute currentValue : Current_mA;
    attribute angularPosition : Angle_deg;
    attribute divisionNumber : ScaleDivision;
  }

  port def ElectricalTerminal {
    inout item current : ElectricalCurrent;
    attribute potential : Voltage_V;
  }

  port def DifferentialElectricalPort {
    port positive : ElectricalTerminal;
    port negative : ElectricalTerminal;
  }

  port def TorquePort {
    inout item torque : CoilTorque;
  }

  port def RotationalPositionPort {
    inout item angle : ShaftAngle;
  }

  port def MagneticFieldPort {
    out item field : MagneticField;
  }

  port def VisualIndicationPort {
    out item reading : PointerReading;
  }

  connection def ElectricalConductor {
    end a : ElectricalTerminal;
    end b : ElectricalTerminal;
    attribute resistance : Resistance_Ohm = 0.002;
  }

  connection def TorqueCoupling {
    end drive : TorquePort;
    end load : TorquePort;
    attribute backlash : Angle_deg = 0.0;
  }

  connection def ShaftCoupling {
    end rotor : RotationalPositionPort;
    end pointerHub : RotationalPositionPort;
    attribute angularOffset : Angle_deg = 0.0;
  }

  constraint def CoilTorqueLaw {
    in current : Current_mA;
    in fluxDensity : MagneticFluxDensity_T;
    in turns : Real;
    in coilArea : Area_m2;
    out electromagneticTorque : Torque_Nm;

    doc "High-level moving-coil law: torque is proportional to current, magnetic field, turns, and coil area."
  }

  constraint def SpringRestoringLaw {
    in angle : Angle_deg;
    in springConstant : SpringConstant_Nm_per_deg;
    out restoringTorque : Torque_Nm;

    doc "Torsion spring restoring torque is proportional to angular displacement from zero."
  }

  constraint def StaticBalanceLaw {
    in electromagneticTorque : Torque_Nm;
    in restoringTorque : Torque_Nm;
    in dampingTorque : Torque_Nm;
    out netTorque : Torque_Nm;

    doc "At stable indication, electromagnetic torque is balanced by spring and damping torques."
  }

  constraint def DeflectionIndicationLaw {
    in current : Current_mA;
    in sensitivity : Sensitivity_deg_per_mA;
    out angle : Angle_deg;

    doc "High-level primary-function relation: pointer deflection is proportional to sensed current."
  }

  action def AcceptInputCurrent {
    in item appliedCurrent : ElectricalCurrent;
    out item coilCurrent : ElectricalCurrent;

    doc "Receives the small external current to be indicated and routes the protected current through the galvanometer moving coil."
  }

  action def ConvertCurrentToTorque {
    in item coilCurrent : ElectricalCurrent;
    in item field : MagneticField;
    out item torque : CoilTorque;

    doc "Converts electrical current in the coil into electromagnetic torque in the permanent-magnet field."
  }

  action def ConvertTorqueToDeflection {
    in item torque : CoilTorque;
    out item shaftAngle : ShaftAngle;

    doc "Converts torque into angular deflection against the torsion spring and damping system."
  }

  action def IndicateCurrent {
    in item shaftAngle : ShaftAngle;
    in item coilCurrent : ElectricalCurrent;
    out item displayedReading : PointerReading;

    doc "Displays magnitude and polarity of the measured small current as pointer deflection on a calibrated scale."
  }

  action def ProtectAgainstOverRange {
    in item appliedCurrent : ElectricalCurrent;
    out item limitedCurrent : ElectricalCurrent;
    out overRangeDetected : Boolean;

    doc "Limits excessive current and identifies an over-range condition to prevent coil damage."
  }

  state def GalvanometerOperatingStateMachine {
    doc "Lifecycle states for a moving-coil galvanometer used to detect and indicate small direct currents."

    state DeEnergized {
      doc "No useful current is being measured and no indication is valid."
    }

    state Zeroing {
      doc "Pointer returns to mechanical zero under spring control."
    }

    state Ready {
      doc "Pointer is at zero and the instrument is ready for measurement."
    }

    state Measuring {
      doc "Input current is within range and is converted into proportional pointer deflection."
    }

    state Settling {
      doc "Damping suppresses oscillation until a stable reading is achieved."
    }

    state OverRange {
      doc "Applied current exceeds safe range; protection path limits current and indication is marked over-range."
    }

    state Fault {
      doc "An internal discontinuity, coil short, pointer jam, or magnet fault prevents valid indication."
    }

    transition InitialToDeEnergized first start then DeEnergized;
    transition EnergizeToZeroing first DeEnergized accept PowerAvailable then Zeroing;
    transition ZeroingToReady first Zeroing accept PointerAtZero then Ready;
    transition ReadyToMeasuring first Ready accept CurrentApplied then Measuring;
    transition MeasuringToSettling first Measuring accept DeflectionChanged then Settling;
    transition SettlingToReady first Settling accept ReadingStable then Ready;
    transition MeasuringToOverRange first Measuring accept CurrentOverRange then OverRange;
    transition OverRangeToZeroing first OverRange accept CurrentRemoved then Zeroing;
    transition AnyToFault first DeEnergized accept InternalFault then Fault;
    transition AnyReadyToFault first Ready accept InternalFault then Fault;
    transition AnyMeasuringToFault first Measuring accept InternalFault then Fault;
  }

  part def InputProtectionNetwork {
    doc "Series resistance and bypass elements that protect the moving coil from excessive current."

    port lineIn : DifferentialElectricalPort;
    port lineOut : DifferentialElectricalPort;

    attribute seriesResistance : Resistance_Ohm = 25.0;
    attribute bypassThresholdCurrent : Current_mA = 1.20;
    attribute maximumSurvivableCurrent : Current_mA = 10.0;
    attribute responseTime : Time_s = 0.005;

    perform action protection : ProtectAgainstOverRange;
  }

  part def MovingCoil {
    doc "Lightweight rectangular coil suspended in the magnetic gap."

    port electrical : DifferentialElectricalPort;
    port torqueOut : TorquePort;
    port shaft : RotationalPositionPort;

    attribute turns : Real = 120;
    attribute coilArea : Area_m2 = 0.00008;
    attribute coilResistance : Resistance_Ohm = 42.0;
    attribute fullScaleCurrent : Current_mA = 1.0;
    attribute safeContinuousCurrent : Current_mA = 1.2;

    perform action acceptCurrent : AcceptInputCurrent;
    perform action currentToTorque : ConvertCurrentToTorque;
  }

  part def PermanentMagnetAssembly {
    doc "Provides a stable radial magnetic field for proportional torque generation."

    port fieldOut : MagneticFieldPort;

    attribute fluxDensity : MagneticFluxDensity_T = 0.18;
    attribute fieldUniformityRatio : Real = 0.97;
    attribute airGapWidth_mm : Real = 1.5;
  }

  part def TorsionSpring {
    doc "Provides restoring torque and defines the zero-current pointer position."

    port torqueInterface : TorquePort;
    port angularInterface : RotationalPositionPort;

    attribute springConstant : SpringConstant_Nm_per_deg = 0.0000021;
    attribute zeroAngle : Angle_deg = 0.0;
    attribute maximumElasticAngle : Angle_deg = 110.0;
  }

  part def DampingAssembly {
    doc "Eddy-current or air damping that reduces pointer oscillation and settling time."

    port torqueInterface : TorquePort;
    port angularInterface : RotationalPositionPort;

    attribute dampingCoefficient : DampingCoefficient_Nm_s_per_deg = 0.00000035;
    attribute targetSettlingTime : Time_s = 1.5;
    attribute overshootLimitPercent : Real = 5.0;
  }

  part def Pointer {
    doc "Mechanical pointer attached to the moving coil shaft."

    port hub : RotationalPositionPort;
    port visualOut : VisualIndicationPort;

    attribute length_mm : Real = 65.0;
    attribute mass_g : Real = 0.08;
    attribute angularPosition : Angle_deg = 0.0;
  }

  part def CalibratedScale {
    doc "Readable scale marked in milliamperes with zero at center for positive and negative current indication."

    port visualOut : VisualIndicationPort;

    attribute minimumCurrent : Current_mA = -1.0;
    attribute maximumCurrent : Current_mA = 1.0;
    attribute zeroMarkAngle : Angle_deg = 0.0;
    attribute negativeFullScaleAngle : Angle_deg = -90.0;
    attribute positiveFullScaleAngle : Angle_deg = 90.0;
    attribute divisionsPerSide : ScaleDivision = 50.0;

    item zeroMark : OpticalScaleMark {
      :>> currentValue = 0.0;
      :>> angularPosition = 0.0;
      :>> divisionNumber = 0.0;
    }

    item positiveFullScaleMark : OpticalScaleMark {
      :>> currentValue = 1.0;
      :>> angularPosition = 90.0;
      :>> divisionNumber = 50.0;
    }

    item negativeFullScaleMark : OpticalScaleMark {
      :>> currentValue = -1.0;
      :>> angularPosition = -90.0;
      :>> divisionNumber = -50.0;
    }
  }

  part def ExternalMeasuredCircuit {
    doc "Representative external circuit supplying the unknown small current to the galvanometer."

    port output : DifferentialElectricalPort;

    attribute nominalCurrent : Current_mA = 0.35;
    attribute sourceVoltage : Voltage_V = 0.020;
    attribute sourceResistance : Resistance_Ohm = 1000.0;
  }

  part def HumanObserver {
    doc "User who reads the pointer position against the calibrated scale."

    port eye : VisualIndicationPort;

    attribute minimumReadableDivision : ScaleDivision = 0.5;
    attribute maximumReadingError : Current_mA = 0.01;
  }

  part def MovingCoilGalvanometer {
    doc "Primary function: detect a small direct electric current and indicate its magnitude and polarity by converting current through a coil into proportional angular pointer deflection."

    port input : DifferentialElectricalPort;
    port indication : VisualIndicationPort;

    attribute fullScaleCurrent : Current_mA = 1.0;
    attribute minimumResolvableCurrent : Current_mA = 0.01;
    attribute inputResistance : Resistance_Ohm = 67.0;
    attribute sensitivity : Sensitivity_deg_per_mA = 90.0;
    attribute positiveFullScaleDeflection : Angle_deg = 90.0;
    attribute negativeFullScaleDeflection : Angle_deg = -90.0;
    attribute settlingTime : Time_s = 1.5;
    attribute overloadCurrentLimit : Current_mA = 1.2;

    part inputProtection : InputProtectionNetwork;
    part coil : MovingCoil;
    part magnet : PermanentMagnetAssembly;
    part spring : TorsionSpring;
    part damper : DampingAssembly;
    part pointer : Pointer;
    part scale : CalibratedScale;

    connect input.positive to inputProtection.lineIn.positive;
    connect input.negative to inputProtection.lineIn.negative;
    connect inputProtection.lineOut.positive to coil.electrical.positive;
    connect inputProtection.lineOut.negative to coil.electrical.negative;

    connect coil.torqueOut to spring.torqueInterface;
    connect coil.torqueOut to damper.torqueInterface;
    connect coil.shaft to spring.angularInterface;
    connect coil.shaft to damper.angularInterface;
    connect coil.shaft to pointer.hub;

    connect pointer.visualOut to indication;
    connect scale.visualOut to indication;

    exhibit state operatingStates : GalvanometerOperatingStateMachine;

    perform action receiveCurrent : AcceptInputCurrent;
    perform action createTorque : ConvertCurrentToTorque;
    perform action deflectPointer : ConvertTorqueToDeflection;
    perform action showReading : IndicateCurrent;

    constraint torqueGeneration : CoilTorqueLaw {
      in current = fullScaleCurrent;
      in fluxDensity = magnet.fluxDensity;
      in turns = coil.turns;
      in coilArea = coil.coilArea;
    }

    constraint pointerCalibration : DeflectionIndicationLaw {
      in current = fullScaleCurrent;
      in sensitivity = sensitivity;
      out angle = positiveFullScaleDeflection;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc "The galvanometer shall provide a high-level function to detect a small direct electric current and convert it into a readable pointer deflection indicating current magnitude and polarity."

    subject galvanometer : MovingCoilGalvanometer;

    require constraint {
      galvanometer.fullScaleCurrent == 1.0 and
      galvanometer.sensitivity == 90.0 and
      galvanometer.positiveFullScaleDeflection == 90.0 and
      galvanometer.negativeFullScaleDeflection == -90.0
    }
  }

  requirement def SmallCurrentRangeRequirement {
    doc "The galvanometer shall indicate currents from -1.0 mA to +1.0 mA without entering over-range state."

    subject galvanometer : MovingCoilGalvanometer;

    require constraint {
      galvanometer.fullScaleCurrent >= 1.0 and
      galvanometer.overloadCurrentLimit > galvanometer.fullScaleCurrent
    }
  }

  requirement def ReadabilityRequirement {
    doc "The galvanometer shall resolve current changes of 0.01 mA or smaller on its calibrated visual scale."

    subject galvanometer : MovingCoilGalvanometer;

    require constraint {
      galvanometer.minimumResolvableCurrent <= 0.01
    }
  }

  requirement def SettlingRequirement {
    doc "The pointer indication shall settle to a valid reading within 1.5 seconds for a step input within the measurement range."

    subject galvanometer : MovingCoilGalvanometer;

    require constraint {
      galvanometer.settlingTime <= 1.5
    }
  }

  requirement def ProtectionRequirement {
    doc "The galvanometer shall limit coil current during over-range conditions to reduce risk of permanent coil or spring damage."

    subject galvanometer : MovingCoilGalvanometer;

    require constraint {
      galvanometer.overloadCurrentLimit <= 1.2
    }
  }

  part def GalvanometerMeasurementSystem {
    doc "System context containing the moving-coil galvanometer, an external measured circuit, and a human observer."

    part measuredCircuit : ExternalMeasuredCircuit;
    part galvanometer : MovingCoilGalvanometer;
    part observer : HumanObserver;

    connect measuredCircuit.output.positive to galvanometer.input.positive;
    connect measuredCircuit.output.negative to galvanometer.input.negative;
    connect galvanometer.indication to observer.eye;

    satisfy PrimaryFunctionRequirement by galvanometer;
    satisfy SmallCurrentRangeRequirement by galvanometer;
    satisfy ReadabilityRequirement by galvanometer;
    satisfy SettlingRequirement by galvanometer;
    satisfy ProtectionRequirement by galvanometer;
  }

  part galvanometerSystem : GalvanometerMeasurementSystem;
}
