package MagneticCompassSystem {

    import ScalarValues::*;

    // ===== Value Types =====

    value type Angle :> Real {
        unit "deg";
    }

    value type AngularVelocity :> Real {
        unit "deg/s";
    }

    value type MagneticFluxDensity :> Real {
        unit "nT";
    }

    value type MagneticMoment :> Real {
        unit "A·m²";
    }

    value type MassValue :> Real {
        unit "kg";
    }

    value type LengthValue :> Real {
        unit "m";
    }

    value type ViscosityValue :> Real {
        unit "cP";
    }

    value type VolumeValue :> Real {
        unit "m³";
    }

    value type TimeValue :> Real {
        unit "s";
    }

    value type DampingCoeff :> Real {
        unit "1";
    }

    // ===== Item Definitions =====

    item def EarthMagneticField {
        attribute fluxDensity : MagneticFluxDensity;
        attribute fieldDirection : Angle;
    }

    item def HeadingData {
        attribute magneticHeading : Angle;
        attribute trueHeading : Angle;
        attribute declination : Angle;
        attribute timestamp : TimeValue;
    }

    // ===== Port Definitions =====

    port def MagneticFieldSensorPort {
        in item sensedField : EarthMagneticField;
    }

    port def HeadingOutputPort {
        out item heading : HeadingData;
    }

    port def MechanicalRotationPort {
        out rotationAngle : Angle;
    }

    // ===== Component Part Definitions =====

    part def MagnetizedNeedle {
        attribute needleMass : MassValue = 0.005;
        attribute needleLength : LengthValue = 0.025;
        attribute magneticMomentValue : MagneticMoment = 0.05;
        attribute currentAngle : Angle = 0;
        attribute angularVelocity : AngularVelocity = 0;

        port fieldSensor : MagneticFieldSensorPort;
        port rotationOutput : MechanicalRotationPort;

        action def SeekMagneticNorth {
            in field : EarthMagneticField;
            in damping : DampingCoeff;
            in friction : DampingCoeff;
            out resultingAngle : Angle;
            out resultingVelocity : AngularVelocity;
        }

        action def SettleOscillation {
            in initialAngle : Angle;
            in initialVelocity : AngularVelocity;
            in dampingCoeff : DampingCoeff;
            out settledAngle : Angle;
            out settledVelocity : AngularVelocity;
        }
    }

    part def PivotAssembly {
        attribute frictionCoefficient : DampingCoeff = 0.001;
        attribute pivotHeight : LengthValue = 0.008;
        attribute bearingMaterial : String = "Synthetic Sapphire";
    }

    part def DampingMedium {
        attribute viscosity : ViscosityValue = 1.0;
        attribute fluidVolume : VolumeValue = 0.00005;
        attribute dampingCoefficient : DampingCoeff = 0.02;
        attribute fluidType : String = "Mineral Oil";
    }

    part def CompassRose {
        attribute roseDiameter : LengthValue = 0.05;
        attribute graduations : Integer = 360;
        attribute cardinalMarks : String = "N, E, S, W";
        attribute intermediateGraduations : Integer = 32;
        attribute rotationAngle : Angle = 0;

        port rotationInput : MechanicalRotationPort;
    }

    part def LubberLine {
        attribute referenceAngle : Angle = 0;
        attribute description : String = "Forward reference mark";
        attribute isFixed : Boolean = true;
    }

    part def ProtectiveHousing {
        attribute isSealed : Boolean = true;
        attribute isWaterproof : Boolean = true;
        attribute windowMaterial : String = "Acrylic";
        attribute housingDiameter : LengthValue = 0.06;
        attribute housingHeight : LengthValue = 0.015;
    }

    // ===== Calculation Definitions =====

    calc def ComputeTrueHeading {
        in magneticHeading : Angle;
        in declination : Angle;
        return trueHeading : Angle;
    }

    // ===== Compass System =====

    part def CompassSystem {
        port externalFieldInput : MagneticFieldSensorPort;
        port headingOutput : HeadingOutputPort;

        attribute localDeclination : Angle = 0;
        attribute isCalibrated : Boolean = false;
        attribute systemTime : TimeValue = 0;

        part needle : MagnetizedNeedle;
        part pivot : PivotAssembly;
        part dampingFluid : DampingMedium;
        part rose : CompassRose;
        part lubberLine : LubberLine;
        part housing : ProtectiveHousing;

        // External field connection
        connect externalFieldInput to needle.fieldSensor;

        // Mechanical coupling: needle rotation drives compass rose
        connect needle.rotationOutput to rose.rotationInput;

        // State machine behavior
        state CompassOperation {
            state Seeking {
                entry {
                    needle.angularVelocity = 10.0;
                }
                do {
                    needle.currentAngle = needle.fieldSensor.sensedField.fieldDirection;
                    needle.angularVelocity = needle.angularVelocity * 0.9;
                }
                transition Seeking -> Stabilizing when needle.angularVelocity < 5.0;
            }

            state Stabilizing {
                entry {
                    // Damping phase begins
                }
                do {
                    needle.angularVelocity = needle.angularVelocity * (1.0 - dampingFluid.dampingCoefficient);
                    needle.currentAngle = needle.currentAngle + needle.angularVelocity * 0.01;
                }
                transition Stabilizing -> Steady when needle.angularVelocity < 0.1;
            }

            state Steady {
                entry {
                    headingOutput.heading.magneticHeading = needle.currentAngle;
                    headingOutput.heading.declination = localDeclination;
                    headingOutput.heading.trueHeading = needle.currentAngle + localDeclination;
                    headingOutput.heading.timestamp = systemTime;
                }
                do {
                    headingOutput.heading.magneticHeading = needle.currentAngle;
                    headingOutput.heading.trueHeading = needle.currentAngle + localDeclination;
                    headingOutput.heading.declination = localDeclination;
                    headingOutput.heading.timestamp = systemTime;
                }
                transition Steady -> Seeking when needle.angularVelocity > 5.0;
            }

            transition initial -> Seeking;
        }
    }

    // ===== Requirement Definitions =====

    requirement def HeadingAccuracyRequirement {
        attribute maxError : Angle = 2.0;
        subject compass : CompassSystem;
        objective {
            assert compass.headingOutput.heading.trueHeading == compass.needle.currentAngle + compass.localDeclination;
        }
    }

    requirement def SettlingTimeRequirement {
        attribute maxSettlingTime : TimeValue = 5.0;
        subject compass : CompassSystem;
        objective {
            assert compass.needle.angularVelocity < 0.1;
        }
    }

    requirement def WaterproofHousingRequirement {
        subject housingPart : ProtectiveHousing;
        objective {
            assert housingPart.isWaterproof == true;
        }
    }

    requirement def ContinuousReferenceRequirement {
        subject compass : CompassSystem;
        objective {
            assert compass.headingOutput.heading.magneticHeading == compass.needle.currentAngle;
        }
    }

    requirement def DeclinationCompensationRequirement {
        subject compass : CompassSystem;
        objective {
            assert compass.headingOutput.heading.trueHeading == compass.headingOutput.heading.magneticHeading + compass.localDeclination;
        }
    }

    requirement def SealedHousingRequirement {
        subject housingPart : ProtectiveHousing;
        objective {
            assert housingPart.isSealed == true;
        }
    }

    // ===== Instantiation and Satisfaction =====

    part navigationCompass : CompassSystem {
        attribute localDeclination = 7.5;
        attribute isCalibrated = true;
    }

    requirement headingAccuracy : HeadingAccuracyRequirement;
    requirement settlingTime : SettlingTimeRequirement;
    requirement waterproofHousing : WaterproofHousingRequirement;
    requirement continuousRef : ContinuousReferenceRequirement;
    requirement declinationComp : DeclinationCompensationRequirement;
    requirement sealedHousing : SealedHousingRequirement;

    satisfy headingAccuracy by navigationCompass;
    satisfy settlingTime by navigationCompass;
    satisfy waterproofHousing by navigationCompass.housing;
    satisfy continuousRef by navigationCompass;
    satisfy declinationComp by navigationCompass;
    satisfy sealedHousing by navigationCompass.housing;
}
