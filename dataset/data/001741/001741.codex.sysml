package AirfoilSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def AngleOfAttack :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def LiftCoefficient {
        :>> scalarValues = Real;
    }

    attribute def DragCoefficient {
        :>> scalarValues = Real;
    }

    attribute def ReynoldsNumber {
        :>> scalarValues = Real;
    }

    attribute def Pressure {
        :>> scalarValues = Real;
        unit = SI::pascal;
    }

    attribute def Velocity {
        :>> scalarValues = Real;
        unit = SI::metrePerSecond;
    }

    attribute def Force {
        :>> scalarValues = Real;
        unit = SI::newton;
    }

    attribute def Length {
        :>> scalarValues = Real;
        unit = SI::metre;
    }

    attribute def Area {
        :>> scalarValues = Real;
        unit = SI::squareMetre;
    }

    attribute def Density {
        :>> scalarValues = Real;
        unit = SI::kilogramPerCubicMetre;
    }

    item def AirStream {
        attribute speed : Velocity;
        attribute staticPressure : Pressure;
        attribute density : Density;
        attribute turbulenceIntensity : Real;
        attribute angleOfAttack : AngleOfAttack;
        attribute reynoldsNumber : ReynoldsNumber;
    }

    item def PressureField {
        attribute upperSurfacePressure : Pressure;
        attribute lowerSurfacePressure : Pressure;
        attribute leadingEdgePressure : Pressure;
        attribute trailingEdgePressure : Pressure;
        attribute pressureDifference : Pressure;
    }

    item def AerodynamicLoad {
        attribute lift : Force;
        attribute drag : Force;
        attribute pitchingMoment : Real;
        attribute liftCoefficient : LiftCoefficient;
        attribute dragCoefficient : DragCoefficient;
    }

    port def AirInletPort {
        in item incomingFlow : AirStream;
    }

    port def AirOutletPort {
        out item deflectedFlow : AirStream;
    }

    port def PressurePort {
        out item pressureField : PressureField;
    }

    port def LoadPort {
        out item aerodynamicLoad : AerodynamicLoad;
    }

    part def AirfoilSystem {
        attribute designChord : Length = 1.5 [SI::metre];
        attribute designSpan : Length = 6.0 [SI::metre];
        attribute planformArea : Area = 9.0 [SI::squareMetre];
        attribute nominalAngleOfAttack : AngleOfAttack = 5.0 [SI::degree];
        attribute stallAngle : AngleOfAttack = 15.0 [SI::degree];

        port inlet : AirInletPort;
        port outlet : AirOutletPort;
        port pressureOutput : PressurePort;
        port loadOutput : LoadPort;

        part airfoilBody : AirfoilBody;
        part leadingEdge : LeadingEdge;
        part upperSurface : UpperSurface;
        part lowerSurface : LowerSurface;
        part trailingEdge : TrailingEdge;
        part boundaryLayer : BoundaryLayerRegion;
        part pressureDistribution : PressureDistributionModel;
        part liftGenerator : LiftGenerationFunction;

        connect inlet to airfoilBody.flowInput;
        connect airfoilBody.upperFlow to upperSurface.flowInput;
        connect airfoilBody.lowerFlow to lowerSurface.flowInput;
        connect upperSurface.pressureOutput to pressureDistribution.upperPressureInput;
        connect lowerSurface.pressureOutput to pressureDistribution.lowerPressureInput;
        connect pressureDistribution.pressureOutput to pressureOutput;
        connect pressureDistribution.loadOutput to liftGenerator.loadInput;
        connect liftGenerator.loadOutput to loadOutput;
        connect airfoilBody.flowOutput to outlet;

        perform action generateLift : GenerateLift;
        exhibit state operatingState : AirfoilOperatingState;

        satisfy req primaryFunctionRequirement by liftGenerator;
        satisfy req pressureDifferentialRequirement by pressureDistribution;
        satisfy req stallAwarenessRequirement by operatingState;
    }

    part def AirfoilBody {
        attribute chord : Length = 1.5 [SI::metre];
        attribute span : Length = 6.0 [SI::metre];
        attribute maximumThickness : Length = 0.18 [SI::metre];
        attribute camber : Length = 0.045 [SI::metre];
        attribute leadingEdgeRadius : Length = 0.025 [SI::metre];

        port flowInput : AirInletPort;
        port flowOutput : AirOutletPort;
        port upperFlow : AirOutletPort;
        port lowerFlow : AirOutletPort;
    }

    part def LeadingEdge {
        attribute radius : Length = 0.025 [SI::metre];
        attribute purpose : String = "Smoothly splits incoming airflow and delays separation at moderate angle of attack.";
    }

    part def UpperSurface {
        attribute curvatureRatio : Real = 0.065;
        attribute surfaceRoughness : Length = 0.000015 [SI::metre];

        port flowInput : AirInletPort;
        port pressureOutput : PressurePort;
    }

    part def LowerSurface {
        attribute curvatureRatio : Real = 0.025;
        attribute surfaceRoughness : Length = 0.000015 [SI::metre];

        port flowInput : AirInletPort;
        port pressureOutput : PressurePort;
    }

    part def TrailingEdge {
        attribute wedgeAngle : AngleOfAttack = 8.0 [SI::degree];
        attribute thickness : Length = 0.004 [SI::metre];
        attribute purpose : String = "Recombines upper and lower airflow streams with controlled wake formation.";
    }

    part def BoundaryLayerRegion {
        attribute transitionLocationUpper : Length = 0.45 [SI::metre];
        attribute transitionLocationLower : Length = 0.70 [SI::metre];
        attribute separated : Boolean = false;
    }

    part def PressureDistributionModel {
        attribute computedPressureDifference : Pressure;
        attribute computedLiftCoefficient : LiftCoefficient;
        attribute computedDragCoefficient : DragCoefficient;

        port upperPressureInput : PressurePort;
        port lowerPressureInput : PressurePort;
        port pressureOutput : PressurePort;
        port loadOutput : LoadPort;

        perform action calculatePressureDifference : CalculatePressureDifference;
    }

    part def LiftGenerationFunction {
        attribute effectiveAngleOfAttack : AngleOfAttack;
        attribute resultingLift : Force;
        attribute resultingDrag : Force;

        port loadInput : LoadPort;
        port loadOutput : LoadPort;

        perform action resolveAerodynamicForces : ResolveAerodynamicForces;
    }

    action def GenerateLift {
        in item freeStream : AirStream;
        out item load : AerodynamicLoad;

        first start;
        then splitFlow;
        then accelerateUpperFlow;
        then maintainLowerFlow;
        then computePressureField;
        then resolveLiftAndDrag;
        then done;

        action splitFlow {
            in item freeStream : AirStream;
            out item upperStream : AirStream;
            out item lowerStream : AirStream;
        }

        action accelerateUpperFlow {
            in item upperStream : AirStream;
            out item acceleratedUpperStream : AirStream;
        }

        action maintainLowerFlow {
            in item lowerStream : AirStream;
            out item lowerSurfaceStream : AirStream;
        }

        action computePressureField {
            in item acceleratedUpperStream : AirStream;
            in item lowerSurfaceStream : AirStream;
            out item pressureField : PressureField;
        }

        action resolveLiftAndDrag {
            in item pressureField : PressureField;
            out item load : AerodynamicLoad;
        }
    }

    action def CalculatePressureDifference {
        in item upperPressure : PressureField;
        in item lowerPressure : PressureField;
        out item field : PressureField;

        attribute pressureDifference : Pressure;
    }

    action def ResolveAerodynamicForces {
        in item field : PressureField;
        in attribute referenceArea : Area;
        in attribute flowSpeed : Velocity;
        in attribute airDensity : Density;
        out item load : AerodynamicLoad;

        attribute dynamicPressure : Pressure;
        attribute lift : Force;
        attribute drag : Force;
    }

    state def AirfoilOperatingState {
        entry action initializeFlowAssessment;

        state AttachedFlow;
        state HighLift;
        state IncipientSeparation;
        state Stalled;
        state Recovery;

        transition initial then AttachedFlow;

        transition attached_to_highLift
            first AttachedFlow
            accept when effectiveAngleOfAttack >= 4.0 [SI::degree] and effectiveAngleOfAttack < 10.0 [SI::degree]
            then HighLift;

        transition highLift_to_separation
            first HighLift
            accept when effectiveAngleOfAttack >= 10.0 [SI::degree] and effectiveAngleOfAttack < 15.0 [SI::degree]
            then IncipientSeparation;

        transition separation_to_stall
            first IncipientSeparation
            accept when effectiveAngleOfAttack >= 15.0 [SI::degree]
            then Stalled;

        transition stall_to_recovery
            first Stalled
            accept when effectiveAngleOfAttack < 12.0 [SI::degree]
            then Recovery;

        transition recovery_to_attached
            first Recovery
            accept when effectiveAngleOfAttack < 8.0 [SI::degree]
            then AttachedFlow;

        attribute effectiveAngleOfAttack : AngleOfAttack;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The airfoil system shall convert incoming airflow into a useful aerodynamic lift force by producing a lower pressure region over the upper surface and a higher pressure region over the lower surface. */
        subject airfoil : AirfoilSystem;

        require constraint {
            airfoil.loadOutput.aerodynamicLoad.lift > airfoil.loadOutput.aerodynamicLoad.drag
        }
    }

    requirement def PressureDifferentialRequirement {
        doc /* The airfoil shall maintain a positive pressure difference between the lower and upper surfaces during attached-flow operation. */
        subject pressureModel : PressureDistributionModel;

        require constraint {
            pressureModel.computedPressureDifference > 0.0 [SI::pascal]
        }
    }

    requirement def StallAwarenessRequirement {
        doc /* The airfoil system shall identify high angle-of-attack operation where flow separation can reduce lift and increase drag. */
        subject system : AirfoilSystem;

        require constraint {
            system.stallAngle <= 15.0 [SI::degree]
        }
    }

    requirement def GeometryRequirement {
        doc /* The airfoil shall provide a finite chord, span, camber, and rounded leading edge suitable for stable lift generation. */
        subject body : AirfoilBody;

        require constraint {
            body.chord > 0.0 [SI::metre] and
            body.span > 0.0 [SI::metre] and
            body.maximumThickness > 0.0 [SI::metre] and
            body.leadingEdgeRadius > 0.0 [SI::metre]
        }
    }

    requirement def DragControlRequirement {
        doc /* The airfoil shall limit drag growth in nominal attached-flow operation. */
        subject loadFunction : LiftGenerationFunction;

        require constraint {
            loadFunction.resultingDrag < loadFunction.resultingLift
        }
    }

    part operationalAirfoil : AirfoilSystem {
        attribute :>> designChord = 1.5 [SI::metre];
        attribute :>> designSpan = 6.0 [SI::metre];
        attribute :>> planformArea = 9.0 [SI::squareMetre];
        attribute :>> nominalAngleOfAttack = 5.0 [SI::degree];

        part :>> airfoilBody {
            attribute :>> chord = 1.5 [SI::metre];
            attribute :>> span = 6.0 [SI::metre];
            attribute :>> maximumThickness = 0.18 [SI::metre];
            attribute :>> camber = 0.045 [SI::metre];
        }
    }

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject airfoil = operationalAirfoil;
    }

    requirement pressureDifferentialRequirement : PressureDifferentialRequirement {
        subject pressureModel = operationalAirfoil.pressureDistribution;
    }

    requirement stallAwarenessRequirement : StallAwarenessRequirement {
        subject system = operationalAirfoil;
    }

    requirement geometryRequirement : GeometryRequirement {
        subject body = operationalAirfoil.airfoilBody;
    }

    requirement dragControlRequirement : DragControlRequirement {
        subject loadFunction = operationalAirfoil.liftGenerator;
    }
}