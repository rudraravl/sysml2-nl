package AircraftWingSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Length :> Real { unit "m"; }
    value type Angle :> Real { unit "deg"; }
    value type Velocity :> Real { unit "m/s"; }
    value type Pressure :> Real { unit "Pa"; }
    value type Density :> Real { unit "kg/m^3"; }
    value type Force :> Real { unit "N"; }
    value type Area :> Real { unit "m^2"; }
    value type Coefficient :> Real { unit "dimensionless"; }
    value type Mass :> Real { unit "kg"; }
    value type Temperature :> Real { unit "K"; }
    value type Duration :> Real { unit "s"; }

    // ===== Item Definitions =====
    item def Airflow {
        attribute velocity : Velocity;
        attribute staticPressure : Pressure;
        attribute dynamicPressure : Pressure;
        attribute density : Density;
        attribute temperature : Temperature;
        attribute angleOfAttack : Angle;
        attribute sideslipAngle : Angle;
    }

    item def AerodynamicForces {
        attribute lift : Force;
        attribute drag : Force;
        attribute sideForce : Force;
        attribute liftCoefficient : Coefficient;
        attribute dragCoefficient : Coefficient;
        attribute pitchingMoment : Real;
    }

    item def ControlCommand {
        attribute aileronDeflection : Angle;
        attribute flapDeflection : Angle;
        attribute timestamp : Duration;
    }

    // ===== Port Definitions =====
    port def AirflowSensorPort {
        in item sensedAirflow : Airflow;
    }

    port def ForceOutputPort {
        out item generatedForces : AerodynamicForces;
    }

    port def ControlInputPort {
        in item command : ControlCommand;
    }

    // ===== Interface Definitions =====
    interface def AirflowInterface {
        end supplier : AirflowSensorPort;
        end consumer : AirflowSensorPort;
    }

    interface def ForceInterface {
        end supplier : ForceOutputPort;
        end consumer : ForceOutputPort;
    }

    interface def ControlInterface {
        end supplier : ControlInputPort;
        end consumer : ControlInputPort;
    }

    // ===== Requirement Definitions =====
    requirement def LiftGenerationRequirement {
        doc "The wing shall generate sufficient aerodynamic lift to sustain flight across all operational conditions."
        attribute minLiftAtCruise : Force = 50000;
        attribute cruiseVelocity : Velocity = 80;
        attribute cruiseAngleOfAttack : Angle = 3;
        attribute stallSpeed : Velocity = 25;
    }

    requirement def StructuralIntegrityRequirement {
        doc "The wing structure shall withstand all aerodynamic and inertial loads during flight."
        attribute maxLoadFactor : Real = 3.8;
        attribute safetyFactor : Real = 1.5;
        attribute materialYieldStrength : Pressure = 503000000;
        attribute ribCount : Integer = 24;
    }

    requirement def ControlSurfaceRequirement {
        doc "The wing shall provide roll control via ailerons and lift augmentation via flaps."
        attribute maxAileronDeflection : Angle = 25;
        attribute maxFlapDeflection : Angle = 30;
        attribute aileronResponseTime : Duration = 0.1;
        attribute flapResponseTime : Duration = 2.0;
    }

    requirement def StallRecoveryRequirement {
        doc "The wing shall recover from stall when angle of attack is reduced below the critical value."
        attribute criticalAngleOfAttack : Angle = 15;
        attribute recoveryAngleMargin : Angle = 2;
    }

    requirement def WingGeometryRequirement {
        doc "The wing shall have the specified geometric properties for stability and performance."
        attribute requiredSpan : Length = 12;
        attribute sweepAngle : Angle = 5;
        attribute dihedralAngle : Angle = 3;
        attribute airfoilType : String = "NACA 2412";
        attribute constructionMaterial : String = "Aluminum";
    }

    // ===== Enumerations =====
    enum def OperationalState {
        idle;
        generatingLift;
        maneuvering;
        stalled;
    }

    enum def FlapPosition {
        retracted;
        takeoff;
        landing;
    }

    // ===== Part Definitions =====
    part def Spar {
        attribute sparName : String;
        attribute sparPosition : String;
        attribute material : String = "Aluminum 7075-T6";
        attribute sparLength : Length;
        attribute crossSectionArea : Area;
        attribute momentOfInertia : Real;
    }

    part def Rib {
        attribute ribId : Integer;
        attribute material : String = "Aluminum 2024-T3";
        attribute thickness : Length = 0.003;
        attribute airfoilProfile : String = "NACA 2412";
        attribute chordLength : Length;
        attribute stationPosition : Length;
    }

    part def SkinPanel {
        attribute panelName : String;
        attribute material : String = "Aluminum 2024-T3";
        attribute thickness : Length = 0.002;
        attribute surfaceType : String;
    }

    part def ControlSurface {
        attribute surfaceName : String;
        attribute material : String = "Aluminum 2024-T3";
        attribute span : Length;
        attribute chord : Length;
        attribute currentDeflection : Angle = 0;
        attribute maxDeflection : Angle;
        attribute hingeMoment : Real;

        port controlPort : ControlInputPort;

        action def Deflect {
            in attribute commandedDeflection : Angle;
            out attribute actualDeflection : Angle;
        }
    }

    part def Aileron :> ControlSurface {
        attribute maxDeflection : Angle = 25;
        attribute span : Length = 2.5;
        attribute chord : Length = 0.4;
    }

    part def Flap :> ControlSurface {
        attribute maxDeflection : Angle = 30;
        attribute span : Length = 3.0;
        attribute chord : Length = 0.6;
        attribute currentPosition : FlapPosition = FlapPosition::retracted;
    }

    // ===== Action Definitions =====
    action def SenseAirflow {
        in item airflowIn : Airflow;
        out attribute sensedVelocity : Velocity;
        out attribute sensedPressure : Pressure;
        out attribute sensedDensity : Density;
        out attribute sensedTemperature : Temperature;
        out attribute sensedAngleOfAttack : Angle;
    }

    action def CalculateAerodynamics {
        in attribute velocity : Velocity;
        in attribute density : Density;
        in attribute angleOfAttack : Angle;
        in attribute wingArea : Area;
        in attribute aileronDeflection : Angle;
        in attribute flapDeflection : Angle;
        out attribute lift : Force;
        out attribute drag : Force;
        out attribute liftCoeff : Coefficient;
        out attribute dragCoeff : Coefficient;
    }

    action def UpdateControlSurfaces {
        in attribute aileronCommand : Angle;
        in attribute flapCommand : Angle;
        out attribute aileronPosition : Angle;
        out attribute flapPosition : Angle;
    }

    // ===== Wing Definition =====
    part def Wing {
        doc "Aircraft wing system providing aerodynamic lift and flight control."

        // Physical attributes
        attribute span : Length = 12;
        attribute sweepAngle : Angle = 5;
        attribute dihedralAngle : Angle = 3;
        attribute rootChord : Length = 1.8;
        attribute tipChord : Length = 1.2;
        attribute airfoilType : String = "NACA 2412";
        attribute constructionMaterial : String = "Aluminum";
        attribute planformArea : Area = 18.0;
        attribute aspectRatio : Real = 8.0;
        attribute taperRatio : Real = 0.667;

        // Aerodynamic state attributes
        attribute currentAngleOfAttack : Angle = 0;
        attribute criticalAngleOfAttack : Angle = 15;
        attribute currentVelocity : Velocity = 0;
        attribute currentDensity : Density = 1.225;
        attribute currentPressure : Pressure = 101325;
        attribute currentTemperature : Temperature = 288.15;
        attribute liftCoefficient : Coefficient = 0.0;
        attribute dragCoefficient : Coefficient = 0.0;
        attribute generatedLift : Force = 0;
        attribute generatedDrag : Force = 0;
        attribute currentAileronDeflection : Angle = 0;
        attribute currentFlapDeflection : Angle = 0;
        attribute operationalState : OperationalState = OperationalState::idle;

        // Ports
        port airflowSensor : AirflowSensorPort;
        port forceOutput : ForceOutputPort;
        port controlInput : ControlInputPort;

        // Structural parts
        part frontSpar : Spar {
            attribute sparName = "Front Spar";
            attribute sparPosition = "25% chord";
            attribute sparLength = 12;
            attribute crossSectionArea = 0.005;
            attribute momentOfInertia = 0.0002;
        }

        part rearSpar : Spar {
            attribute sparName = "Rear Spar";
            attribute sparPosition = "75% chord";
            attribute sparLength = 12;
            attribute crossSectionArea = 0.004;
            attribute momentOfInertia = 0.00015;
        }

        part ribs[24] : Rib {
            attribute material = "Aluminum 2024-T3";
            attribute thickness = 0.003;
            attribute airfoilProfile = "NACA 2412";
        }

        part upperSkin : SkinPanel {
            attribute panelName = "Upper Skin";
            attribute surfaceType = "Upper";
        }

        part lowerSkin : SkinPanel {
            attribute panelName = "Lower Skin";
            attribute surfaceType = "Lower";
        }

        part leftAileron : Aileron {
            attribute surfaceName = "Left Aileron";
        }

        part rightAileron : Aileron {
            attribute surfaceName = "Right Aileron";
        }

        part leftFlap : Flap {
            attribute surfaceName = "Left Flap";
        }

        part rightFlap : Flap {
            attribute surfaceName = "Right Flap";
        }

        // Structural connections
        connection frontSparToRibs connect frontSpar to ribs;
        connection rearSparToRibs connect rearSpar to ribs;
        connection ribsToUpperSkin connect ribs to upperSkin;
        connection ribsToLowerSkin connect ribs to lowerSkin;
        connection leftAileronToRearSpar connect leftAileron to rearSpar;
        connection rightAileronToRearSpar connect rightAileron to rearSpar;
        connection leftFlapToRearSpar connect leftFlap to rearSpar;
        connection rightFlapToRearSpar connect rightFlap to rearSpar;

        // Actions
        action senseAirflow : SenseAirflow {
            in airflowIn = airflowSensor.sensedAirflow;
            out sensedVelocity = currentVelocity;
            out sensedPressure = currentPressure;
            out sensedDensity = currentDensity;
            out sensedTemperature = currentTemperature;
            out sensedAngleOfAttack = currentAngleOfAttack;
        }

        action calculateForces : CalculateAerodynamics {
            in velocity = currentVelocity;
            in density = currentDensity;
            in angleOfAttack = currentAngleOfAttack;
            in wingArea = planformArea;
            in aileronDeflection = currentAileronDeflection;
            in flapDeflection = currentFlapDeflection;
            out lift = generatedLift;
            out drag = generatedDrag;
            out liftCoeff = liftCoefficient;
            out dragCoeff = dragCoefficient;
        }

        action updateControls : UpdateControlSurfaces {
            in aileronCommand = controlInput.command.aileronDeflection;
            in flapCommand = controlInput.command.flapDeflection;
            out aileronPosition = currentAileronDeflection;
            out flapPosition = currentFlapDeflection;
        }

        // State Machine
        state wingOperation {
            entry { operationalState = OperationalState::idle; }

            state idle {
                doc "Ground state with no significant airflow."
                entry {
                    generatedLift = 0;
                    generatedDrag = 0;
                    operationalState = OperationalState::idle;
                }
                do { senseAirflow; }
            }

            state generatingLift {
                doc "Normal flight condition producing aerodynamic lift."
                entry {
                    operationalState = OperationalState::generatingLift;
                }
                do {
                    senseAirflow;
                    calculateForces;
                }
            }

            state maneuvering {
                doc "Control surfaces deflected for roll or lift augmentation."
                entry {
                    operationalState = OperationalState::maneuvering;
                }
                do {
                    senseAirflow;
                    updateControls;
                    calculateForces;
                }
            }

            state stalled {
                doc "Critical condition with separated airflow and lift loss."
                entry {
                    operationalState = OperationalState::stalled;
                    liftCoefficient = liftCoefficient * 0.3;
                }
                do {
                    senseAirflow;
                    calculateForces;
                }
            }

            transition first idle
                accept when currentVelocity > 20
                then generatingLift;

            transition first generatingLift
                accept ControlCommand
                if currentAileronDeflection != 0 or currentFlapDeflection != 0
                then maneuvering;

            transition first maneuvering
                accept ControlCommand
                if currentAileronDeflection == 0 and currentFlapDeflection == 0
                then generatingLift;

            transition first generatingLift
                accept when currentAngleOfAttack > criticalAngleOfAttack
                then stalled;

            transition first maneuvering
                accept when currentAngleOfAttack > criticalAngleOfAttack
                then stalled;

            transition first stalled
                accept when currentAngleOfAttack < criticalAngleOfAttack - 2
                then generatingLift;

            transition first generatingLift
                accept when currentVelocity < 20
                then idle;

            transition first maneuvering
                accept when currentVelocity < 20
                then idle;
        }
    }

    // ===== Requirement Usages =====
    requirement liftReq : LiftGenerationRequirement {
        attribute minLiftAtCruise = 50000;
    }

    requirement structReq : StructuralIntegrityRequirement {
        attribute maxLoadFactor = 3.8;
    }

    requirement controlReq : ControlSurfaceRequirement {
        attribute maxAileronDeflection = 25;
    }

    requirement stallReq : StallRecoveryRequirement {
        attribute criticalAngleOfAttack = 15;
    }

    requirement geometryReq : WingGeometryRequirement {
        attribute requiredSpan = 12;
    }

    // ===== Top-level Wing System =====
    part wingSystem : Wing {
        doc "Complete aircraft wing system instance."
    }

    // ===== Requirement Satisfaction =====
    satisfy liftReq by wingSystem;
    satisfy structReq by wingSystem;
    satisfy controlReq by wingSystem;
    satisfy stallReq by wingSystem;
    satisfy geometryReq by wingSystem;
}
