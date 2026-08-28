package HirtzMagneticCompass {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def AngleValue :> Real {
        unit 'deg';
    }

    value def AngularVelocityValue :> Real {
        unit 'deg/s';
    }

    value def MagneticFluxDensityValue :> Real {
        unit 'uT';
    }

    value def DampingCoefficientValue :> Real {
        unit 'N*s/m';
    }

    value def FrictionTorqueValue :> Real {
        unit 'uN*m';
    }

    value def PressureValue :> Real {
        unit 'kPa';
    }

    value def HeadingValue :> AngleValue;

    // ---- Enumerations ----
    enum def CardinalDirection {
        N = 0;
        NE = 45;
        E = 90;
        SE = 135;
        S = 180;
        SW = 225;
        W = 270;
        NW = 315;
    }

    enum def CompassOperationalState {
        seeking;
        settling;
        stable;
        disturbed;
    }

    // ---- Item types ----
    item def MagneticField {
        attribute fluxDensity : MagneticFluxDensityValue;
        attribute declination : AngleValue;
    }

    item def DampingFluid {
        attribute kind : String = "mineral oil";
        attribute viscosity : Real;
        attribute volume : Real;
    }

    item def MagneticInterference {
        attribute strength : MagneticFluxDensityValue;
        attribute direction : AngleValue;
    }

    // ---- Interfaces / port definitions ----
    port def MagneticFieldInput {
        in field : MagneticField;
        in interference : MagneticInterference optional;
    }

    port def HeadingOutput {
        out heading : HeadingValue;
        out state : CompassOperationalState;
    }

    // ---- Components ----
    part def MagnetizedNeedle {
        attribute magneticMoment : Real;
        attribute momentOfInertia : Real;
        attribute currentAngle : AngleValue := 0;
        attribute angularVelocity : AngularVelocityValue := 0;

        port fieldIn : MagneticFieldInput;
        port angleOut : HeadingOutput;

        action def AlignToField {
            in field : MagneticField;
            in damping : DampingCoefficientValue;
            in friction : FrictionTorqueValue;
            out angle : AngleValue;
        }

        perform AlignToField align :>> fieldIn.field, damping := 0.0, friction := 0.0, angle :>> angleOut.heading;
    }

    part def SapphireBearing {
        attribute frictionTorque : FrictionTorqueValue := 5;
        attribute jewelMaterial : String = "sapphire";
    }

    part def PivotAssembly {
        part bearing : SapphireBearing;
        attribute pivotHeight : Real;
        attribute maxTilt : AngleValue := 15;
    }

    part def CompassCard {
        attribute graduations : AngleValue := 1;
        attribute cardinalMarks : CardinalDirection[8] = (N, NE, E, SE, S, SW, W, NW);
        attribute diameter : Real;
    }

    part def LubberLine {
        attribute fixedHeading : AngleValue := 0;
        attribute position : String = "forward";
    }

    part def DampingChamber {
        attribute fillPressure : PressureValue;
        attribute sealed : Boolean = true;
        item fluid : DampingFluid {
            redef kind = "mineral oil";
        }
        attribute dampingCoefficient : DampingCoefficientValue := 0.012;
    }

    part def GlassWindow {
        attribute material : String = "glass";
        attribute transmittance : Real := 0.92;
        attribute thickness : Real;
    }

    part def ProtectiveHousing {
        attribute material : String = "brass";
        attribute hermeticallySealed : Boolean = true;
        attribute ingressProtection : String = "IP67";
        part window : GlassWindow;
    }

    // ---- The compass assembly ----
    part def HirtzCompass {

        port magneticInput : MagneticFieldInput;
        port headingOutput : HeadingOutput;

        part housing : ProtectiveHousing {
            part window : GlassWindow;
        }

        part chamber : DampingChamber {
            item fluid : DampingFluid;
        }

        part pivot : PivotAssembly {
            part bearing : SapphireBearing;
        }

        part needle : MagnetizedNeedle {
            port fieldIn : MagneticFieldInput;
            port angleOut : HeadingOutput;
        }

        part card : CompassCard;

        part lubber : LubberLine;

        // Internal connections
        connection magneticFlow connect magneticInput to needle.fieldIn;
        connection needleAngle connect needle.angleOut to headingOutput;

        // Behavioral state machine
        state def CompassBehavior {

            attribute needleAngle : AngleValue;
            attribute interferenceLevel : MagneticFluxDensityValue;

            state seeking {
                entry action seekNorth {
                    // Needle rotates freely toward magnetic north
                    needle.angularVelocity := 30;
                }
                do action rotateToField continue;
                transition seeking to settling
                    when needle.angularVelocity < 5;
            }

            state settling {
                entry action dampOscillation {
                    // Damping fluid minimizes oscillations
                    needle.angularVelocity := needle.angularVelocity * 0.5;
                }
                do action settle continue;
                transition settling to stable
                    when needle.angularVelocity < 0.5;
            }

            state stable {
                entry action lockHeading {
                    headingOutput.heading := needle.currentAngle;
                    headingOutput.state := CompassOperationalState::stable;
                }
                do action maintainReading continue;
                transition stable to disturbed
                    when magneticInput.interference.strength > 50;
            }

            state disturbed {
                entry action flagDisturbance {
                    headingOutput.state := CompassOperationalState::disturbed;
                }
                do action waitForClearance continue;
                transition disturbed to seeking
                    when magneticInput.interference.strength <= 50;
            }

            transition first to seeking;
        }

        perform CompassBehavior behavior;

        // Initialization
        assertion InitCondition {
            needle.currentAngle == 0 and
            needle.angularVelocity == 0 and
            chamber.sealed == true and
            housing.hermeticallySealed == true
        }
    }

    // ---- Requirements ----
    requirement def HeadingIndicationRequirement {
        subject compass : HirtzCompass;
        objective {
            doc /* The compass shall provide a continuous indication of magnetic heading. */
        }
        require compass.headingOutput.heading.defined
    }

    requirement def SensitivityRequirement {
        subject needle : MagnetizedNeedle;
        subject bearing : SapphireBearing;
        objective {
            doc /* The needle shall align with the Earth's magnetic field with friction torque not exceeding 10 uN*m. */
        }
        require bearing.frictionTorque <= 10
    }

    requirement def DampingRequirement {
        subject chamber : DampingChamber;
        objective {
            doc /* The damping chamber shall reduce needle oscillation so that the needle settles within 5 seconds after disturbance. */
        }
        require chamber.dampingCoefficient > 0
    }

    requirement def SealingRequirement {
        subject housing : ProtectiveHousing;
        objective {
            doc /* The housing shall be hermetically sealed to prevent ingress of moisture and contaminants. */
        }
        require housing.hermeticallySealed == true and
               housing.ingressProtection == "IP67"
    }

    requirement def ReadabilityRequirement {
        subject card : CompassCard;
        subject lubber : LubberLine;
        objective {
            doc /* The compass card shall be graduated in degrees and cardinal/intercardinal points, referenced against a fixed lubber line. */
        }
        require card.graduations == 1 and
               card.cardinalMarks::N.defined and
               lubber.fixedHeading.defined
    }

    requirement def DisturbanceRecoveryRequirement {
        subject behavior : CompassBehavior;
        objective {
            doc /* After removal of magnetic interference, the compass shall re-seek and settle to a stable heading. */
        }
        require behavior.disturbed.defined and
               behavior.seeking.defined and
               behavior.settling.defined and
               behavior.stable.defined
    }

    // ---- Satisfaction ----
    satisfaction HeadingIndicationRequirement satisfy by HirtzCompass;
    satisfaction SensitivityRequirement satisfy by HirtzCompass::needle, HirtzCompass::pivot.bearing;
    satisfaction DampingRequirement satisfy by HirtzCompass::chamber;
    satisfaction SealingRequirement satisfy by HirtzCompass::housing;
    satisfaction ReadabilityRequirement satisfy by HirtzCompass::card, HirtzCompass::lubber;
    satisfaction DisturbanceRecoveryRequirement satisfy by HirtzCompass::behavior;

}
