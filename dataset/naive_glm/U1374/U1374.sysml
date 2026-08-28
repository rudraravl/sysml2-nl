package ActiveAirfoilSystem {
    import ISQ::*;
    import ISQBase::*;
    import ScalarValues::*;
    import Time::*;

    // ---------- Value Types ----------

    value def ChordLength :> Length;
    value def AirfoilThickness :> Length;
    value def Camber :> Length;
    value def AngleOfAttack :> PlaneAngle;
    value def FlowSpeed :> Speed;
    value def FlowDensity :> MassDensity;
    value def SurfacePressure :> Pressure;
    value def LiftForce :> Force;
    value def DragForce :> Force;
    value def ReynoldsNumber :> Real;

    // ---------- Item Definitions ----------

    item def PressureSample {
        attribute value : SurfacePressure;
        attribute location : String; // "upper" | "lower"
        attribute timestamp : DateTime;
    }

    item def FlowCharacterization {
        attribute speed : FlowSpeed;
        attribute density : FlowDensity;
        attribute turbulent : Boolean;
        attribute reynolds : ReynoldsNumber;
    }

    item def LiftDragEstimate {
        attribute lift : LiftForce;
        attribute drag : DragForce;
        attribute timestamp : DateTime;
    }

    item def ActuatorCommand {
        attribute targetAngle : AngleOfAttack;
        attribute priority : Integer; // 0 = normal, 1 = recovery
    }

    item def StallAlert {
        attribute detected : Boolean;
        attribute severity : Real;
    }

    // ---------- Port Definitions ----------

    port def PressureSampleOut {
        out sample : PressureSample;
    }

    port def PressureSampleIn {
        in sample : PressureSample;
    }

    port def FlowCharacterizationOut {
        out flow : FlowCharacterization;
    }

    port def FlowCharacterizationIn {
        in flow : FlowCharacterization;
    }

    port def ActuatorCommandOut {
        out command : ActuatorCommand;
    }

    port def ActuatorCommandIn {
        in command : ActuatorCommand;
    }

    port def LiftDragOut {
        out estimate : LiftDragEstimate;
    }

    port def StallAlertOut {
        out alert : StallAlert;
    }

    // ---------- Part Definitions ----------

    part def AirfoilStructure {
        attribute chord : ChordLength = 1.0 [m];
        attribute thickness : AirfoilThickness = 0.12 [m];
        attribute camber : Camber = 0.04 [m];
        attribute currentAngleOfAttack : AngleOfAttack = 0.0 [deg];

        port upperSurfacePort : PressureSampleOut;
        port lowerSurfacePort : PressureSampleOut;

        perform action updateOrientation(in target : AngleOfAttack) {
            // Mechanical reorientation of the airfoil
        }
    }

    part def PressureSensor {
        attribute surface : String; // "upper" or "lower"
        attribute samplingRate : Frequency = 100.0 [Hz];
        attribute calibrated : Boolean = true;

        port sampleOut : PressureSampleOut;

        perform action samplePressure(out s : PressureSample) {
            // Reads local surface pressure and emits a sample
        }
    }

    part def FlowAnalyzer {
        attribute analysisInterval : Duration = 0.01 [s];

        port pressureInUpper : PressureSampleIn;
        port pressureInLower : PressureSampleIn;
        port flowOut : FlowCharacterizationOut;

        perform action analyzeFlow {
            in upperSample : PressureSample;
            in lowerSample : PressureSample;
            out result : FlowCharacterization;
            // Computes speed, density, and turbulence state from pressure differential
        }
    }

    part def Actuator {
        attribute maxRate : AngularVelocity = 30.0 [deg/s];
        attribute minAngle : AngleOfAttack = -5.0 [deg];
        attribute maxAngle : AngleOfAttack = 25.0 [deg];
        attribute currentAngle : AngleOfAttack = 0.0 [deg];

        port commandIn : ActuatorCommandIn;

        perform action actuate(in cmd : ActuatorCommand) {
            // Drives the airfoil to the commanded angle of attack
        }
    }

    part def AirfoilController {
        attribute stallAngleThreshold : AngleOfAttack = 18.0 [deg];
        attribute recoveryAngle : AngleOfAttack = 10.0 [deg];
        attribute liftCoefficientSlope : Real = 0.11; // per degree, simplified
        attribute dragCoefficientBase : Real = 0.02;

        port flowIn : FlowCharacterizationIn;
        port commandOut : ActuatorCommandOut;
        port liftDragOut : LiftDragOut;
        port stallAlertOut : StallAlertOut;

        attribute lastEstimate : LiftDragEstimate;
        attribute lastFlow : FlowCharacterization;
        attribute stallDetected : Boolean = false;

        perform action computeLiftDrag {
            in flow : FlowCharacterization;
            in angle : AngleOfAttack;
            out estimate : LiftDragEstimate;
            // lift = 0.5 * density * speed^2 * area * Cl
            // drag = 0.5 * density * speed^2 * area * Cd
        }

        state def ControllerBehavior {
            entry; then Idle;

            state Idle {
                entry {
                    // Initialize subsystems; no active control
                }
                transition to Operational
                    when flowIn.flow.received;
            }

            state Operational {
                entry {
                    stallDetected = false;
                }
                do computeLiftDrag(lastFlow, currentAngleOfAttack, lastEstimate);
                transition to Stalled
                    when currentAngleOfAttack > stallAngleThreshold or lastFlow.turbulent;
            }

            state Stalled {
                entry {
                    stallDetected = true;
                    send ActuatorCommand{targetAngle = recoveryAngle, priority = 1} via commandOut;
                    send StallAlert{detected = true, severity = 1.0} via stallAlertOut;
                }
                transition to Operational
                    when currentAngleOfAttack <= recoveryAngle and not lastFlow.turbulent;
            }
        }

        exhibit state behavior : ControllerBehavior;
    }

    // ---------- Composite System ----------

    part def ActiveAirfoil {
        attribute systemId : String = "AAF-001";
        attribute operational : Boolean = false;

        part structure : AirfoilStructure;
        part upperSensor : PressureSensor {
            attribute surface = "upper";
        }
        part lowerSensor : PressureSensor {
            attribute surface = "lower";
        }
        part analyzer : FlowAnalyzer;
        part actuator : Actuator;
        part controller : AirfoilController;

        // Connections
        connection upperSensor.sampleOut to analyzer.pressureInUpper;
        connection lowerSensor.sampleOut to analyzer.pressureInLower;
        connection analyzer.flowOut to controller.flowIn;
        connection controller.commandOut to actuator.commandIn;

        // Bind actuator angle back to structure
        binding actuator.currentAngle = structure.currentAngleOfAttack;

        perform action startup {
            operational = true;
        }

        perform action shutdown {
            operational = false;
        }
    }

    // ---------- Requirements ----------

    requirement def ShallGenerateLift {
        doc "The system shall generate aerodynamic lift efficiently across its operational envelope."
        subject : ActiveAirfoil;
        constraint { lastEstimate.lift > 0.0 [N] when operational }
    }

    requirement def ShallMonitorPressure {
        doc "The system shall continuously measure surface pressure on upper and lower airfoil surfaces."
        subject : ActiveAirfoil;
        constraint { upperSensor.samplingRate >= 50.0 [Hz] and lowerSensor.samplingRate >= 50.0 [Hz] }
    }

    requirement def ShallAnalyzeFlow {
        doc "The system shall characterize airflow speed, density, and turbulence state from pressure data."
        subject : ActiveAirfoil;
        constraint { analyzer.flowOut.flow.speed > 0.0 [m/s] }
    }

    requirement def ShallAdjustAngleOfAttack {
        doc "The system shall actively adjust the angle of attack in response to control commands."
        subject : ActiveAirfoil;
        constraint { actuator.minAngle <= structure.currentAngleOfAttack <= actuator.maxAngle }
    }

    requirement def ShallDetectStall {
        doc "The system shall detect aerodynamic stall when the angle of attack exceeds the stall threshold or flow becomes turbulent."
        subject : ActiveAirfoil;
        constraint { controller.stallDetected == true when structure.currentAngleOfAttack > controller.stallAngleThreshold }
    }

    requirement def ShallRecoverFromStall {
        doc "Upon stall detection, the system shall automatically command the actuator to reduce the angle of attack to the recovery angle."
        subject : ActiveAirfoil;
        constraint { actuator.currentAngle <= controller.recoveryAngle when controller.stallDetected }
    }

    requirement def ShallReportLiftDrag {
        doc "The system shall continuously compute and report lift and drag forces."
        subject : ActiveAirfoil;
        constraint { controller.liftDragOut.estimate.received when operational }
    }

    // ---------- Requirement Satisfaction ----------

    satisfaction ShallGenerateLift by ActiveAirfoil;
    satisfaction ShallMonitorPressure by ActiveAirfoil;
    satisfaction ShallAnalyzeFlow by ActiveAirfoil;
    satisfaction ShallAdjustAngleOfAttack by ActiveAirfoil;
    satisfaction ShallDetectStall by ActiveAirfoil;
    satisfaction ShallRecoverFromStall by ActiveAirfoil;
    satisfaction ShallReportLiftDrag by ActiveAirfoil;
}
