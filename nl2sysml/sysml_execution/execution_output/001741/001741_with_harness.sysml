package AirfoilSystem {
    attribute def FlowStart;
    attribute def FlowStop;

    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;

    attribute def VelocityValue :> Real;
    attribute def ForceValue :> Real;
    attribute def PressureValue :> Real;
    attribute def AreaValue :> Real;
    attribute def AngleValue :> Real;
    attribute def DensityValue :> Real;
    attribute def CoefficientValue :> Real;
    attribute def LengthValue :> Real;

    enum def FlowRegime {
        laminar;
        transitional;
        turbulent;
        separated;
    }

    enum def AirfoilState {
        idle;
        operational;
        stalled;
        critical;
    }

    item def AirFlow {
        attribute velocity : VelocityValue;
        attribute density : DensityValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute regime : FlowRegime;
    }

    port def FlowPort {
        in item incomingFlow : AirFlow;
        out item exitFlow : AirFlow;
    }

    port def ForceOutputPort {
        out attribute liftForce : ForceValue;
        out attribute dragForce : ForceValue;
        out attribute momentCoefficient : CoefficientValue;
    }

    port def ControlInputPort {
        in attribute targetAngle : AngleValue;
        out attribute actualAngle : AngleValue;
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port sensing : FlowPort;
    }

    part def AngleActuator {
        attribute currentAngle : AngleValue;
        attribute commandedAngle : AngleValue;
        attribute actuationRate : Real;
        port control : ControlInputPort;
    }

    part def FlowAnalyzer {
        attribute reynoldsNumber : Real;
        attribute machNumber : Real;
        attribute detectedRegime : FlowRegime;
        port flowInput : FlowPort;
    }

    part def Airfoil {
        attribute chordLength : LengthValue;
        attribute thickness : LengthValue;
        attribute camber : Real;
        attribute planformArea : AreaValue;
        attribute angleOfAttack : AngleValue;
        attribute liftCoefficient : CoefficientValue;
        attribute dragCoefficient : CoefficientValue;
        attribute stallAngle : AngleValue;
        attribute currentState : AirfoilState;

        port leadingEdge : FlowPort;
        port trailingEdge : FlowPort;
        port forceOutput : ForceOutputPort;
        port angleControl : ControlInputPort;

        part upperSurface {
            attribute curvature : Real;
            part pressureSensor1 : PressureSensor;
            part pressureSensor2 : PressureSensor;
        }

        part lowerSurface {
            attribute curvature : Real;
            part pressureSensor3 : PressureSensor;
            part pressureSensor4 : PressureSensor;
        }

        part actuator : AngleActuator {
            attribute :>> actuationRate = 2.0;
        }

        part analyzer : FlowAnalyzer;
    }

    action def MeasureFlowConditions {
        in airflow : AirFlow;
        out velocity : VelocityValue;
        out density : DensityValue;
        out pressure : PressureValue;
    }

    action def CalculateLiftCoefficient {
        in angleOfAttack : AngleValue;
        in reynoldsNumber : Real;
        out liftCoeff : CoefficientValue;
    }

    action def CalculateDragCoefficient {
        in angleOfAttack : AngleValue;
        in liftCoeff : CoefficientValue;
        out dragCoeff : CoefficientValue;
    }

    action def ComputeLiftForce {
        in velocity : VelocityValue;
        in density : DensityValue;
        in area : AreaValue;
        in liftCoeff : CoefficientValue;
        out lift : ForceValue;
    }

    action def ComputeDragForce {
        in velocity : VelocityValue;
        in density : DensityValue;
        in area : AreaValue;
        in dragCoeff : CoefficientValue;
        out drag : ForceValue;
    }

    action def DetectStall {
        in currentAngle : AngleValue;
        in stallAngle : AngleValue;
        in flowRegime : FlowRegime;
        out isStalled : Boolean;
    }

    action def AdjustAngleOfAttack {
        in targetAngle : AngleValue;
        in currentAngle : AngleValue;
        in maxRate : Real;
        out newAngle : AngleValue;
    }

    action def GenerateAerodynamicForces {
        first start;
        then merge monitoringLoop;
        then action measureConditions : MeasureFlowConditions;
        then action computeLiftCoeff : CalculateLiftCoefficient {
            in angleOfAttack;
            in reynoldsNumber;
            out liftCoeff;
        }
        then action computeDragCoeff : CalculateDragCoefficient {
            in angleOfAttack;
            in liftCoeff = computeLiftCoeff.liftCoeff;
            out dragCoeff;
        }
        then action calculateLift : ComputeLiftForce {
            in velocity = measureConditions.velocity;
            in density = measureConditions.density;
            in area;
            in liftCoeff = computeLiftCoeff.liftCoeff;
            out lift;
        }
        then action calculateDrag : ComputeDragForce {
            in velocity = measureConditions.velocity;
            in density = measureConditions.density;
            in area;
            in dragCoeff = computeDragCoeff.dragCoeff;
            out drag;
        }
        then action checkStall : DetectStall;
        then decide;
            if checkStall.isStalled then recoverFromStall;
            if !checkStall.isStalled then continueOperation;
        action recoverFromStall : AdjustAngleOfAttack {
            in targetAngle = 0.0;
            in currentAngle;
            in maxRate = 5.0;
            out newAngle;
        }
        then monitoringLoop;
        action continueOperation;
        then monitoringLoop;
    }

    state def AirfoilOperationalBehavior {
        entry; then idleState;

        state idleState;
        
        transition idleToOperational
            first idleState
            accept FlowStart
            then operationalState;

        state operationalState {
            entry; then normalFlight;

            state normalFlight;
            
            transition normalToHigh
                first normalFlight
                if angleOfAttack > 10.0
                then highAngleFlight;

            state highAngleFlight;
            
            transition highToStall
                first highAngleFlight
                if angleOfAttack >= stallAngle
                then stalledState;

            transition stallToRecovery
                first stalledState
                if angleOfAttack < stallAngle - 3.0
                then normalFlight;
        }

        state stalledState;

        transition operationalToIdle
            first operationalState
            accept FlowStop
            then idleState;
    }

    part airfoilSystem : Airfoil {
        attribute :>> chordLength = 2.0 [m];
        attribute :>> thickness = 0.24 [m];
        attribute :>> camber = 0.05;
        attribute :>> planformArea = 16.0 [m^2];
        attribute :>> angleOfAttack = 6.0;
        attribute :>> stallAngle = 16.0;
        attribute :>> currentState = AirfoilState::idle;

        attribute computedLift : ForceValue;
        attribute computedDrag : ForceValue;
        attribute liftToDragRatio : Real;

        part :>> upperSurface {
            attribute :>> curvature = 0.08;
        }

        part :>> lowerSurface {
            attribute :>> curvature = -0.03;
        }

        connection upperSensorToAnalyzer connect upperSurface.pressureSensor1.sensing to analyzer.flowInput;
        connection lowerSensorToAnalyzer connect lowerSurface.pressureSensor3.sensing to analyzer.flowInput;
        connection actuatorToControl connect actuator.control to angleControl;

        perform action forceGeneration : GenerateAerodynamicForces[*] ordered;

        exhibit state operationalBehavior : AirfoilOperationalBehavior;
    }

    requirement <'REQ-AIRFOIL-001'> generateLiftForce {
        doc /* The airfoil system shall generate lift force by creating a pressure 
             * differential between its upper and lower surfaces when air flows over 
             * its cambered shape, exploiting Bernoulli's principle and flow circulation.
             */
        subject airfoil :> airfoilSystem;

        require constraint {
            airfoil.computedLift > 0.0
        }
    }

    requirement <'REQ-AIRFOIL-002'> maintainEfficiency {
        doc /* The airfoil shall maintain a lift-to-drag ratio of at least 12:1 
             * during normal operational conditions to ensure efficient aerodynamic 
             * performance.
             */
        subject airfoil :> airfoilSystem;

        assert constraint {
            airfoil.liftToDragRatio >= 12.0
        }
    }

    requirement <'REQ-AIRFOIL-003'> preventStall {
        doc /* The airfoil system shall detect approaching stall conditions and 
             * maintain angle of attack below the critical stall angle to prevent 
             * flow separation and loss of lift.
             */
        subject airfoil :> airfoilSystem;

        require constraint {
            airfoil.angleOfAttack < airfoil.stallAngle
        }
    }

    requirement <'REQ-AIRFOIL-004'> structuralLimit {
        doc /* The airfoil shall withstand maximum aerodynamic loads without 
             * structural failure or permanent deformation.
             */
        subject airfoil :> airfoilSystem;

        require constraint {
            airfoil.computedLift <= 80000.0
        }
    }

    requirement <'REQ-AIRFOIL-005'> angleControlRange {
        doc /* The airfoil system shall provide controllable angle of attack 
             * adjustment within a range of -5 to +15 degrees for flight control.
             */
        subject airfoil :> airfoilSystem;

        assert constraint {
            airfoil.angleOfAttack >= -5.0 and airfoil.angleOfAttack <= 15.0
        }
    }

    requirement primaryAirfoilFunction {
        doc /* The airfoil system's primary function is to generate lift force by 
             * exploiting aerodynamic principles. As air flows over the cambered 
             * surface, the curved upper surface creates longer flow path and higher 
             * velocity compared to the lower surface. By Bernoulli's principle, this 
             * velocity difference creates lower pressure above and higher pressure 
             * below, resulting in net upward lift force. The system continuously 
             * monitors flow conditions, adjusts angle of attack, and prevents stall 
             * to maintain efficient lift generation across varying flight conditions.
             */

        assume constraint airflowRequired {
            doc /* Continuous airflow over the airfoil surfaces is required. */
        }

        require generateLiftForce;
        require maintainEfficiency;
        require preventStall;
        require structuralLimit;
        require angleControlRange;
    }

    satisfy primaryAirfoilFunction by airfoilSystem;
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NumericalFunctions::*;
    private import AirfoilSystem::*;

    part airfoilSystem : PressureSensor {
        exhibit state sm : AirfoilOperationalBehavior;
    }

    action orchestrator {
        attribute testTargetAngle : AngleValue = 0.0;
        attribute testCurrentAngle : AngleValue = 0.0;
        action recoverFromStallProbe : AdjustAngleOfAttack {
            in targetAngle = testTargetAngle;
            in currentAngle = testCurrentAngle;
            in maxRate = 0.0;
        }
        attribute testFlowStart : FlowStart;
        attribute testFlowStop : FlowStop;
        action triggerFlowStart send testFlowStart to airfoilSystem;
        action triggerFlowStop send testFlowStop to airfoilSystem;
        first recoverFromStallProbe;
        then triggerFlowStart;
        then triggerFlowStop;
    }
}
