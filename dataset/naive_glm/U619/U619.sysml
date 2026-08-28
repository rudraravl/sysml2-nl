package BourdonGaugeSystem {
    import ISQ::*;
    import ScalarValues::*;
    import MeasurementReferences::*;
    import Time::*;

    // ---- Item definitions ----
    item def PressurizedFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    // ---- Port definitions ----
    port def FluidPort {
        attribute pressure : Pressure;
        in item fluid : PressurizedFluid;
    }

    port def MechanicalLinearPort {
        attribute displacement : Length;
    }

    port def MechanicalRotationalPort {
        attribute angle : Angle;
    }

    // ---- Requirements ----
    requirement def AccuracyRequirement {
        attribute fullScale : Pressure;
        attribute maxErrorFraction : Real = 0.015;
        doc /* The gauge shall indicate pressure within 1.5% of full scale. */
        constraint { abs(indicatedPressure - actualPressure) <= maxErrorFraction * fullScale }
    }

    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : Duration = 0.1 [s];
        doc /* The gauge shall settle within 100 ms of a step pressure change. */
    }

    requirement def RobustnessRequirement {
        attribute enclosureMaterial : String = "Stainless Steel";
        attribute windowMaterial : String = "Polycarbonate";
        attribute ingressProtection : String = "IP65";
        doc /* The assembly shall be robust for industrial environments. */
    }

    requirement def PressureRangeRequirement {
        attribute minRange : Pressure = 0 [Pa];
        attribute maxRange : Pressure = 10 [MPa];
        doc /* The gauge shall measure pressure from 0 to 10 MPa. */
    }

    // ---- Bourdon Tube ----
    part def BourdonTube {
        attribute material : String = "Beryllium Copper";
        attribute crossSection : String = "Elliptical";
        attribute tubeShape : String = "Curved (C-shaped)";
        attribute ambientPressure : Pressure = 101325 [Pa];
        attribute internalPressure : Pressure = ambientPressure;
        attribute freeEndDisplacement : Length = 0 [mm];
        attribute displacementSensitivity : Real = 0.001 [mm/Pa];

        port fluidIn : FluidPort;

        action def RespondToPressure {
            in pressure : Pressure;
            out displacement : Length;
            constraint { displacement == (pressure - ambientPressure) * displacementSensitivity }
        }

        perform respond : RespondToPressure {
            in pressure = internalPressure;
            out displacement = freeEndDisplacement;
        }

        requirement tubeAccuracy : AccuracyRequirement {
            fullScale = 10 [MPa];
        }
    }

    // ---- Linkage Mechanism ----
    part def LinkageMechanism {
        attribute amplificationRatio : Real = 100.0;
        attribute leverRatio : Real = 5.0;
        attribute gearRatio : Real = 20.0;
        attribute inputDisplacement : Length = 0 [mm];
        attribute outputRotation : Angle = 0 [deg];
        attribute backlash : Angle = 0.5 [deg];

        in port mechanicalInput : MechanicalLinearPort;
        out port mechanicalOutput : MechanicalRotationalPort;

        action def AmplifyAndConvert {
            in displacement : Length;
            out rotation : Angle;
            constraint { rotation == displacement * amplificationRatio }
        }

        perform amplify : AmplifyAndConvert {
            in displacement = inputDisplacement;
            out rotation = outputRotation;
        }
    }

    // ---- Pointer Assembly ----
    part def PointerAssembly {
        attribute currentAngle : Angle = 0 [deg];
        attribute indicatedPressure : Pressure = 0 [Pa];
        attribute sweepRange : Angle = 270 [deg];
        attribute fullScale : Pressure = 10 [MPa];

        in port rotationInput : MechanicalRotationalPort;

        action def SweepPointer {
            in rotation : Angle;
            out angle : Angle;
            out indicated : Pressure;
            constraint { angle == rotation }
            constraint { indicated == (rotation / sweepRange) * fullScale }
        }

        perform sweep : SweepPointer {
            in rotation = rotationInput.angle;
            out angle = currentAngle;
            out indicated = indicatedPressure;
        }
    }

    // ---- Dial ----
    part def Dial {
        attribute units : String = "MPa";
        attribute fullScale : Pressure = 10 [MPa];
        attribute divisions : Integer = 50;
        attribute sweepAngle : Angle = 270 [deg];
        attribute minorDivisions : Integer = 10;
        attribute faceColor : String = "White";
        attribute textColor : String = "Black";
    }

    // ---- Window ----
    part def Window {
        attribute material : String = "Polycarbonate";
        attribute transparency : String = "Clear";
        attribute thickness : Length = 3 [mm];
        attribute shatterResistant : Boolean = true;
    }

    // ---- Enclosure ----
    part def Enclosure {
        attribute material : String = "Stainless Steel";
        attribute ingressProtection : String = "IP65";
        attribute diameter : Length = 100 [mm];
        attribute depth : Length = 50 [mm];

        part window : Window;
        part dial : Dial;
    }

    // ---- Threaded Connection ----
    part def ThreadedConnection {
        attribute threadStandard : String = "NPT 1/4";
        attribute material : String = "Stainless Steel";
        attribute sealingMethod : String = "Tapered thread seal";

        port processConnection : FluidPort;
    }

    // ---- State Machine ----
    state def GaugeStates {
        entry; exit;

        state standby {
            entry; exit;
            doc /* Gauge at ambient pressure, pointer at zero. */
        }

        state active {
            entry; exit;
            doc /* Pressure applied, pointer in motion. */
        }

        state stable {
            entry; exit;
            doc /* Pressure settled, pointer holding steady reading. */
        }

        transition standby_to_active first standby to active {
            when { bourdonTube.internalPressure > bourdonTube.ambientPressure }
        }

        transition active_to_stable active to stable {
            when { pointer.currentAngle'::stable }
        }

        transition stable_to_active stable to active {
            when { bourdonTube.internalPressure'::changing }
        }

        transition active_to_standby active to standby {
            when { bourdonTube.internalPressure == bourdonTube.ambientPressure }
        }

        transition stable_to_standby stable to standby {
            when { bourdonTube.internalPressure == bourdonTube.ambientPressure }
        }
    }

    // ---- Top-level Assembly ----
    part def BourdonGauge {
        attribute fullScale : Pressure = 10 [MPa];
        attribute accuracyClass : Real = 0.015;
        attribute manufacturer : String = "Industrial Instruments Inc.";
        attribute modelNumber : String = "BG-10MPa";

        part threadedConnection : ThreadedConnection;
        part bourdonTube : BourdonTube;
        part linkage : LinkageMechanism;
        part pointer : PointerAssembly;
        part enclosure : Enclosure;

        port processPort : FluidPort redefines threadedConnection.processConnection;

        // Internal connections
        connection fluidPath connect threadedConnection.processConnection to bourdonTube.fluidIn;
        connection linearMotion connect bourdonTube.respond.displacement to linkage.mechanicalInput.displacement;
        connection rotationalMotion connect linkage.mechanicalOutput.angle to pointer.rotationInput.angle;

        exhibit gaugeStates : GaugeStates;

        requirement gaugeAccuracy : AccuracyRequirement {
            fullScale = 10 [MPa];
        }
        requirement gaugeResponse : ResponseTimeRequirement;
        requirement gaugeRobustness : RobustnessRequirement;
        requirement gaugeRange : PressureRangeRequirement;

        satisfy AccuracyRequirement by gaugeAccuracy;
        satisfy ResponseTimeRequirement by gaugeResponse;
        satisfy RobustnessRequirement by gaugeRobustness;
        satisfy PressureRangeRequirement by gaugeRange;
    }
}
