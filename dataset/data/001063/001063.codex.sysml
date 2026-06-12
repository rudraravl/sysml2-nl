package GalvanometerPrimaryFunctionModel {
    import ScalarValues::*;
    import SI::*;

    attribute def ElectricCurrent :> Real {
        unit = "A";
    }

    attribute def Voltage :> Real {
        unit = "V";
    }

    attribute def Resistance :> Real {
        unit = "ohm";
    }

    attribute def MagneticFluxDensity :> Real {
        unit = "T";
    }

    attribute def Torque :> Real {
        unit = "N*m";
    }

    attribute def Angle :> Real {
        unit = "deg";
    }

    attribute def Time :> Real {
        unit = "s";
    }

    attribute def DampingRatio :> Real {
        unit = "1";
    }

    attribute def CurrentSensitivity :> Real {
        unit = "deg/A";
    }

    attribute def SpringConstant :> Real {
        unit = "N*m/deg";
    }

    item def ElectricalCurrentSample {
        attribute magnitude : ElectricCurrent;
        attribute polarity : String;
        attribute sampleTime : Time;
    }

    item def PointerIndication {
        attribute deflectionAngle : Angle;
        attribute indicatedCurrent : ElectricCurrent;
        attribute overRange : Boolean;
    }

    item def MechanicalRotation {
        attribute angle : Angle;
        attribute torque : Torque;
    }

    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensity;
        attribute fieldUniformity : Real;
    }

    port def ElectricalTerminal {
        in item appliedCurrent : ElectricalCurrentSample;
        out item terminalVoltage : Voltage;
    }

    port def MechanicalPivotPort {
        in item appliedRotation : MechanicalRotation;
        out item restrainedRotation : MechanicalRotation;
    }

    port def IndicationPort {
        out item indication : PointerIndication;
    }

    part def PermanentMagnetAssembly {
        attribute nominalFluxDensity : MagneticFluxDensity = 0.18;
        attribute poleGapWidth : Real = 0.004;
        out item field : MagneticField;
    }

    part def MovingCoil {
        port positiveTerminal : ElectricalTerminal;
        port negativeTerminal : ElectricalTerminal;

        attribute coilResistance : Resistance = 85.0;
        attribute turns : Integer = 120;
        attribute coilArea : Real = 0.00018;
        attribute maximumSafeCurrent : ElectricCurrent = 0.010;

        in item magneticField : MagneticField;
        out item producedTorque : MechanicalRotation;
    }

    part def ControlSpring {
        port pivot : MechanicalPivotPort;

        attribute torsionalSpringConstant : SpringConstant = 0.000042;
        attribute zeroOffset : Angle = 0.0;

        in item coilRotation : MechanicalRotation;
        out item restoringRotation : MechanicalRotation;
    }

    part def DampingSystem {
        port pivot : MechanicalPivotPort;

        attribute dampingRatio : DampingRatio = 0.72;
        attribute settlingTime : Time = 1.2;

        in item rawRotation : MechanicalRotation;
        out item dampedRotation : MechanicalRotation;
    }

    part def PointerAndScale {
        port indicationOutput : IndicationPort;

        attribute scaleMinimum : ElectricCurrent = -0.005;
        attribute scaleMaximum : ElectricCurrent = 0.005;
        attribute fullScaleDeflection : Angle = 60.0;
        attribute sensitivity : CurrentSensitivity = 12000.0;

        in item shaftRotation : MechanicalRotation;
        out item visibleIndication : PointerIndication;
    }

    action def ConvertCurrentToDeflection {
        in item inputCurrent : ElectricalCurrentSample;
        in item magneticField : MagneticField;
        in attribute coilTurns : Integer;
        in attribute coilArea : Real;
        in attribute springConstant : SpringConstant;
        out item shaftRotation : MechanicalRotation;

        action computeElectromagneticTorque {
            out item electromagneticTorque : MechanicalRotation;
        }

        action balanceAgainstSpring {
            in item electromagneticTorque : MechanicalRotation;
            out item equilibriumRotation : MechanicalRotation;
        }

        action limitMechanicalTravel {
            in item equilibriumRotation : MechanicalRotation;
            out item shaftRotation : MechanicalRotation;
        }

        first start;
        then computeElectromagneticTorque;
        then balanceAgainstSpring;
        then limitMechanicalTravel;
        then done;
    }

    action def IndicateMeasuredCurrent {
        in item shaftRotation : MechanicalRotation;
        in attribute sensitivity : CurrentSensitivity;
        in attribute scaleMinimum : ElectricCurrent;
        in attribute scaleMaximum : ElectricCurrent;
        out item indication : PointerIndication;

        action mapAngleToCurrent;
        action detectOverRange;
        action publishPointerPosition;

        first start;
        then mapAngleToCurrent;
        then detectOverRange;
        then publishPointerPosition;
        then done;
    }

    state def GalvanometerOperationalState {
        state Zeroed;
        state Measuring;
        state Settling;
        state OverRange;
        state Protected;

        transition initial then Zeroed;

        transition currentApplied
            first Zeroed
            accept ElectricalCurrentSample
            then Settling;

        transition settled
            first Settling
            then Measuring;

        transition exceedsFullScale
            first Measuring
            then OverRange;

        transition returnsWithinRange
            first OverRange
            then Settling;

        transition unsafeCurrentDetected
            first OverRange
            then Protected;

        transition reset
            first Protected
            then Zeroed;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The galvanometer shall convert a small direct electric current into a proportional visible pointer deflection, enabling high-level indication of current magnitude and polarity. */

        subject galvanometer : GalvanometerInstrument;

        require constraint {
            galvanometer.pointerAndScale.visibleIndication.indicatedCurrent ==
            galvanometer.measuredInput.appliedCurrent.magnitude;
        }
    }

    requirement def ProportionalIndicationRequirement {
        subject galvanometer : GalvanometerInstrument;

        require constraint {
            galvanometer.pointerAndScale.visibleIndication.deflectionAngle ==
            galvanometer.pointerAndScale.sensitivity *
            galvanometer.measuredInput.appliedCurrent.magnitude;
        }
    }

    requirement def OverRangeProtectionRequirement {
        subject galvanometer : GalvanometerInstrument;

        require constraint {
            galvanometer.measuredInput.appliedCurrent.magnitude <=
            galvanometer.movingCoil.maximumSafeCurrent;
        }
    }

    part def GalvanometerInstrument {
        port measuredInput : ElectricalTerminal;
        port returnInput : ElectricalTerminal;
        port currentIndication : IndicationPort;

        part magnet : PermanentMagnetAssembly;
        part movingCoil : MovingCoil;
        part controlSpring : ControlSpring;
        part damper : DampingSystem;
        part pointerAndScale : PointerAndScale;

        attribute nominalRange : ElectricCurrent = 0.005;
        attribute internalResistance : Resistance = 85.0;
        attribute nominalFullScaleDeflection : Angle = 60.0;
        attribute primaryFunction : String = "Indicate small electric current by proportional pointer deflection.";

        perform action currentToRotation : ConvertCurrentToDeflection {
            in inputCurrent = measuredInput.appliedCurrent;
            in magneticField = magnet.field;
            in coilTurns = movingCoil.turns;
            in coilArea = movingCoil.coilArea;
            in springConstant = controlSpring.torsionalSpringConstant;
        }

        perform action rotationToIndication : IndicateMeasuredCurrent {
            in shaftRotation = damper.dampedRotation;
            in sensitivity = pointerAndScale.sensitivity;
            in scaleMinimum = pointerAndScale.scaleMinimum;
            in scaleMaximum = pointerAndScale.scaleMaximum;
        }

        exhibit state operationalState : GalvanometerOperationalState;

        connect measuredInput to movingCoil.positiveTerminal;
        connect returnInput to movingCoil.negativeTerminal;
        connect movingCoil.producedTorque to controlSpring.coilRotation;
        connect controlSpring.restoringRotation to damper.rawRotation;
        connect damper.dampedRotation to pointerAndScale.shaftRotation;
        connect pointerAndScale.indicationOutput to currentIndication;
    }

    part galvanometerSystem : GalvanometerInstrument;

    satisfy PrimaryFunctionRequirement by galvanometerSystem;
    satisfy ProportionalIndicationRequirement by galvanometerSystem;
    satisfy OverRangeProtectionRequirement by galvanometerSystem;
}