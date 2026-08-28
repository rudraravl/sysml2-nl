package MedicalHeadMirror {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value type MassValue :> Real { unit "g"; }
    value type LengthValue :> Real { unit "cm"; }
    value type AngleValue :> Real { unit "deg"; }
    value type LuminousFluxValue :> Real { unit "lm"; }
    value type IlluminanceValue :> Real { unit "lx"; }
    value type ForceValue :> Real { unit "N"; }
    value type PressureValue :> Real { unit "kPa"; }

    // ---- Item types ----
    item def AmbientLight {
        attribute illuminance : IlluminanceValue;
    }

    item def FocusedBeam {
        attribute luminousFlux : LuminousFluxValue;
        attribute targetDistance : LengthValue;
    }

    item def AdjustmentCommand {
        attribute verticalDelta : AngleValue;
        attribute horizontalDelta : AngleValue;
    }

    // ---- Enumerations ----
    enum FitStatus { loose, snug, tight }
    enum PowerState { off, on }

    // ---- Requirements ----
    requirement def IlluminationRequirement {
        doc "The head mirror shall concentrate ambient light into a focused beam at the working distance.";
        attribute requiredFocalDistance : LengthValue = 25 [cm];
        attribute minTargetIlluminance : IlluminanceValue = 1000 [lx];
        subject device : HeadMirror;
        objective {
            device.mirror.focalDistance == requiredFocalDistance;
        }
    }

    requirement def ErgonomicRequirement {
        doc "The device shall be lightweight and comfortable for extended use.";
        attribute maxTotalMass : MassValue = 200 [g];
        attribute maxForeheadPressure : PressureValue = 12 [kPa];
        subject device : HeadMirror;
        objective {
            device.totalMass <= maxTotalMass;
            device.headband.foreheadPressure <= maxForeheadPressure;
        }
    }

    requirement def AdjustabilityRequirement {
        doc "The pivot joint shall allow vertical and horizontal aiming of the mirror.";
        attribute requiredVerticalRange : AngleValue = 90 [deg];
        attribute requiredHorizontalRange : AngleValue = 120 [deg];
        subject pivot : PivotJoint;
        objective {
            pivot.verticalRange >= requiredVerticalRange;
            pivot.horizontalRange >= requiredHorizontalRange;
        }
    }

    requirement def StabilityRequirement {
        doc "The headband shall maintain a stable fit during examination movements.";
        attribute minElasticity : Real = 0.7;
        subject headband : Headband;
        objective {
            headband.elasticity >= minElasticity;
        }
    }

    // ---- Part definitions ----
    part def Headband {
        attribute material : String = "elastic fabric";
        attribute mass : MassValue = 50 [g];
        attribute elasticity : Real = 0.85;
        attribute width : LengthValue = 3.5 [cm];
        attribute foreheadPressure : PressureValue = 8 [kPa];
        attribute fitStatus : FitStatus = FitStatus::loose;

        port def ForeheadInterface {
            in item contactForce : ForceValue;
            out item fitFeedback : FitStatus;
        }

        port foreheadPort : ForeheadInterface;

        exhibit state def FitStateMachine {
            entry; then Unsecured;
            state Unsecured {
                entry { fitStatus = FitStatus::loose; }
            }
            transition from Unsecured to Secured
                when foreheadPort.fitFeedback == FitStatus::snug;
            state Secured {
                entry { fitStatus = FitStatus::snug; }
            }
            transition from Secured to Tightened
                when foreheadPort.fitFeedback == FitStatus::tight;
            state Tightened {
                entry { fitStatus = FitStatus::tight; }
            }
            transition from Tightened to Secured
                when foreheadPort.fitFeedback == FitStatus::snug;
            transition from Secured to Unsecured
                when foreheadPort.fitFeedback == FitStatus::loose;
        }
    }

    part def MountingFrame {
        attribute material : String = "aluminum alloy";
        attribute mass : MassValue = 40 [g];
        attribute rigidity : Real = 0.95;
        attribute length : LengthValue = 12 [cm];

        port def FrameMountInterface {
            in item mechanicalLoad : ForceValue;
        }

        port headbandMount : FrameMountInterface;
        port pivotMount : FrameMountInterface;
    }

    part def ConcaveMirror {
        attribute focalDistance : LengthValue = 25 [cm];
        attribute diameter : LengthValue = 8 [cm];
        attribute reflectivity : Real = 0.92;
        attribute mass : MassValue = 30 [g];
        attribute curvatureRadius : LengthValue = 50 [cm];

        port def OpticalPort {
            in item incomingLight : AmbientLight;
            out item outgoingBeam : FocusedBeam;
        }

        port opticalPort : OpticalPort;

        exhibit action def ReflectLight {
            in light : AmbientLight;
            out beam : FocusedBeam;
            perform {
                beam.luminousFlux = light.illuminance * 0.05;
                beam.targetDistance = focalDistance;
            }
        }
    }

    part def PivotJoint {
        attribute verticalRange : AngleValue = 90 [deg];
        attribute horizontalRange : AngleValue = 120 [deg];
        attribute frictionCoefficient : Real = 0.3;
        attribute mass : MassValue = 20 [g];
        attribute currentVerticalAngle : AngleValue = 0 [deg];
        attribute currentHorizontalAngle : AngleValue = 0 [deg];

        port def CommandPort {
            in item command : AdjustmentCommand;
        }

        port commandPort : CommandPort;

        exhibit action def AdjustAngle {
            in cmd : AdjustmentCommand;
            perform {
                currentVerticalAngle = currentVerticalAngle + cmd.verticalDelta;
                currentHorizontalAngle = currentHorizontalAngle + cmd.horizontalDelta;
            }
        }
    }

    // ---- Top-level part ----
    part def HeadMirror {
        attribute totalMass : MassValue = 140 [g];
        attribute focalDistance : LengthValue = 25 [cm];
        attribute powerState : PowerState = PowerState::off;

        part headband : Headband;
        part frame : MountingFrame;
        part mirror : ConcaveMirror;
        part pivot : PivotJoint;

        // Mechanical connections
        connection headbandToFrame
            connect headband.foreheadPort to frame.headbandMount;
        connection frameToPivot
            connect frame.pivotMount to pivot.commandPort;
        connection pivotToMirror
            connect pivot to mirror;

        // Optical flow
        flow of AmbientLight to mirror.opticalPort.incomingLight;
        flow of FocusedBeam from mirror.opticalPort.outgoingBeam;

        // Requirement satisfaction
        satisfy IlluminationRequirement;
        satisfy ErgonomicRequirement;
        satisfy AdjustabilityRequirement by pivot;
        satisfy StabilityRequirement by headband;

        exhibit state def OperatingLifecycle {
            entry; then Stored;

            state Stored {
                entry { powerState = PowerState::off; }
            }

            transition from Stored to Mounted
                when headband.fitStatus == FitStatus::snug;

            state Mounted {
                entry { powerState = PowerState::on; }
            }

            transition from Mounted to Positioning
                when pivot.commandPort.command != null;

            state Positioning {
                entry { pivot.AdjustAngle; }
            }

            transition from Positioning to Operating
                when mirror.opticalPort.outgoingBeam != null;

            state Operating {
                entry { mirror.ReflectLight; }
            }

            transition from Operating to Positioning
                when pivot.commandPort.command != null;

            transition from Operating to Stored
                when headband.fitStatus == FitStatus::loose;

            transition from Mounted to Stored
                when headband.fitStatus == FitStatus::loose;
        }
    }

    // ---- Usage / configuration ----
    part def ExaminationSetup {
        part device : HeadMirror;
        attribute workingDistance : LengthValue = 25 [cm];
        attribute roomIlluminance : IlluminanceValue = 500 [lx];

        flow of AmbientLight
            from roomIlluminance
            to device.mirror.opticalPort.incomingLight;
    }

}
