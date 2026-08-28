package 'Active Airfoil System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import NonSI::*;

    package 'Value Types' {
        attribute def AngleOfAttackValue :> angle;
        attribute def CriticalAoAValue :> angle;
        attribute def ChordLengthValue :> length;
        attribute def ThicknessValue :> length;
        attribute def CamberValue :> length;
        attribute def SurfaceAreaValue :> area;
        attribute def LiftForceValue :> force;
        attribute def DragForceValue :> force;
        attribute def SurfacePressureValue :> pressure;
        attribute def FlowSpeedValue :> speed;
        attribute def FlowDensityValue :> massDensity;
        attribute def LiftCoeffValue :> Real;
        attribute def DragCoeffValue :> Real;
        attribute def ReynoldsNumberValue :> Real;
        attribute def RotationRateValue :> angularVelocity;
        attribute def MassValue :> mass;
        attribute def TimeValue :> time;
        attribute def AccuracyValue :> Real;

        enum def FlowRegimeEnum {
            laminar;
            transitional;
            turbulent;
        }

        attribute def ActivationCommand;
        attribute def DeactivationCommand;
    }

    package 'Item Definitions' {
        private import 'Value Types'::*;

        item def PressureReading {
            attribute pressure : SurfacePressureValue;
            attribute surfaceSide : String;
        }

        item def FlowAssessment {
            attribute speed : FlowSpeedValue;
            attribute density : FlowDensityValue;
            attribute reynoldsNumber : ReynoldsNumberValue;
            attribute regime : FlowRegimeEnum;
        }

        item def AerodynamicForces {
            attribute lift : LiftForceValue;
            attribute drag : DragForceValue;
            attribute liftCoeff : LiftCoeffValue;
            attribute dragCoeff : DragCoeffValue;
        }

        item def AngleCommand {
            attribute targetAngle : AngleOfAttackValue;
            attribute source : String;
        }

        item def StallWarning {
            attribute currentAngle : AngleOfAttackValue;
            attribute criticalAngle : CriticalAoAValue;
            attribute severity : Integer;
        }
    }

    package 'Port Definitions' {
        private import 'Item Definitions'::*;
        private import 'Value Types'::*;

        port def PressureOutPort {
            out pressureReading : PressureReading;
        }

        port def PressureInPort {
            in pressureReading : PressureReading;
        }

        port def FlowAnalysisOutPort {
            out flowAssessment : FlowAssessment;
        }

        port def ForcesOutPort {
            out forces : AerodynamicForces;
        }

        port def AngleCmdInPort {
            in angleCmd : AngleCommand;
        }

        port def AngleCmdOutPort {
            out angleCmd : AngleCommand;
        }

        port def StallAlertOutPort {
            out stallAlert : StallWarning;
        }

        port def StallAlertInPort {
            in stallAlert : StallWarning;
        }

        port def ControlCmdPort {
            in activationCmd : ActivationCommand;
            in deactivationCmd : DeactivationCommand;
        }
    }

    package 'Calculation Definitions' {
        private import 'Value Types'::*;

        calc def LiftEquation {
            in rho : FlowDensityValue;
            in V : FlowSpeedValue;
            in S : SurfaceAreaValue;
            in Cl : LiftCoeffValue;
            return L : LiftForceValue;
        }

        calc def DragEquation {
            in rho : FlowDensityValue;
            in V : FlowSpeedValue;
            in S : SurfaceAreaValue;
            in Cd : DragCoeffValue;
            return D : DragForceValue;
        }

        calc def DetectStallCondition {
            in angle : AngleOfAttackValue;
            in maxAoA : CriticalAoAValue;
            return stalled : Boolean;
        }
    }

    package 'Action Definitions' {
        private import 'Value Types'::*;
        private import 'Item Definitions'::*;

        action def SensePressure {
            out upperPressure : SurfacePressureValue;
            out lowerPressure : SurfacePressureValue;
        }

        action def AnalyzeFlow {
            in upperPressure : SurfacePressureValue;
            in lowerPressure : SurfacePressureValue;
            out speed : FlowSpeedValue;
            out density : FlowDensityValue;
            out reynoldsNumber : ReynoldsNumberValue;
            out regime : FlowRegimeEnum;
        }

        action def CalculateLiftAndDrag {
            in speed : FlowSpeedValue;
            in density : FlowDensityValue;
            in angle : AngleOfAttackValue;
            in chord : ChordLengthValue;
            in surfaceArea : SurfaceAreaValue;
            out lift : LiftForceValue;
            out drag : DragForceValue;
            out liftCoeff : LiftCoeffValue;
            out dragCoeff : DragCoeffValue;
        }

        action def DetectStallAction {
            in angle : AngleOfAttackValue;
            in maxAoA : CriticalAoAValue;
            out stalled : Boolean;
            out warning : StallWarning;
        }

        action def AdjustAngleOfAttack {
            in targetAoA : AngleOfAttackValue;
        }

        action def RecoverFromStall {
            in currentAngle : AngleOfAttackValue;
            in criticalAngle : CriticalAoAValue;
            out reducedAoA : AngleOfAttackValue;
        }

        action def ProvideLift;

        action def MonitorHealth {
            out healthStatus : String;
        }

        action def InitializeSystems;
    }

    package 'Part Definitions' {
        private import 'Port Definitions'::*;
        private import 'Action Definitions'::*;
        private import 'Value Types'::*;
        private import 'Item Definitions'::*;

        part def PressureSensor {
            attribute surfaceSide : String;
            attribute measuredPressure : SurfacePressureValue;
            attribute accuracy : AccuracyValue;
            port pressureOut : PressureOutPort;
            perform action measurePressure : SensePressure;
        }

        part def Actuator {
            attribute currentAoA : AngleOfAttackValue;
            attribute minAngle : AngleOfAttackValue;
            attribute maxAngle : AngleOfAttackValue;
            attribute maxRotationRate : RotationRateValue;
            port cmdIn : AngleCmdInPort;
            perform action setAoA : AdjustAngleOfAttack;
        }

        part def FlowAnalyzer {
            attribute measuredSpeed : FlowSpeedValue;
            attribute measuredDensity : FlowDensityValue;
            attribute flowRegime : FlowRegimeEnum;
            port pressureInUpper : PressureInPort;
            port pressureInLower : PressureInPort;
            port analysisOut : FlowAnalysisOutPort;
            port forcesOut : ForcesOutPort;
            port stallAlertOut : StallAlertOutPort;
            port angleCmdOut : AngleCmdOutPort;
            perform action analyzeFlow : AnalyzeFlow;
            perform action calculateForces : CalculateLiftAndDrag;
            perform action detectStall : DetectStallAction;
        }

        part def Airfoil {
            attribute chord : ChordLengthValue;
            attribute thickness : ThicknessValue;
            attribute camber : CamberValue;
            attribute surfaceArea : SurfaceAreaValue;
            attribute currentAngleOfAttack : AngleOfAttackValue;
            attribute criticalAngleOfAttack : CriticalAoAValue;
            attribute mass : MassValue;
            attribute lift : LiftForceValue;
            attribute drag : DragForceValue;

            port controlCmdPort : ControlCmdPort;
            port forcesOutPort : ForcesOutPort;
            port stallAlertPort : StallAlertInPort;

            part upperPressureSensor : PressureSensor;
            part lowerPressureSensor : PressureSensor;
            part actuator : Actuator;
            part flowAnalyzer : FlowAnalyzer;

            connect upperPressureSensor.pressureOut to flowAnalyzer.pressureInUpper;
            connect lowerPressureSensor.pressureOut to flowAnalyzer.pressureInLower;
            connect flowAnalyzer.angleCmdOut to actuator.cmdIn;
            connect flowAnalyzer.forcesOut to forcesOutPort;
            connect flowAnalyzer.stallAlertOut to stallAlertPort;

            perform action provideLift : ProvideLift;
            perform action monitorHealth : MonitorHealth;

            exhibit state airfoilStates : AirfoilStates {
                in operatingAirfoil = this;
            }
        }

        state def AirfoilStates {
            in operatingAirfoil : Airfoil;

            entry; then idle;

            state idle;

            transition idle_To_operational
                first idle
                accept ActivationCommand via operatingAirfoil.controlCmdPort
                then operational;

            state operational {
                constraint { operatingAirfoil.lift > 0 [N] }
            }

            transition operational_To_stalled
                first operational
                accept when operatingAirfoil.currentAngleOfAttack >= operatingAirfoil.criticalAngleOfAttack
                then stalled;

            state stalled {
                constraint { operatingAirfoil.currentAngleOfAttack >= operatingAirfoil.criticalAngleOfAttack }
            }

            transition stalled_To_operational
                first stalled
                accept when operatingAirfoil.currentAngleOfAttack < operatingAirfoil.criticalAngleOfAttack
                then operational;

            transition operational_To_idle
                first operational
                accept DeactivationCommand via operatingAirfoil.controlCmdPort
                then idle;
        }
    }

    package 'Requirement Definitions' {
        private import 'Part Definitions'::*;
        private import 'Value Types'::*;

        requirement def LiftGenerationRequirement {
            doc /* The airfoil shall generate positive lift force during operational state. */
            subject airfoil : Airfoil;
            constraint { airfoil.lift > 0 [N] }
        }

        requirement def StallPreventionRequirement {
            doc /* The system shall automatically reduce the angle of attack when a stall condition is detected. */
            subject airfoil : Airfoil;
            constraint { airfoil.currentAngleOfAttack < airfoil.criticalAngleOfAttack }
        }

        requirement def StallRecoveryTimeRequirement {
            doc /* Upon stall detection, the system shall reduce angle of attack within 0.5 seconds. */
            subject actuator : Actuator;
            constraint { actuator.maxRotationRate >= 30.0 [deg/s] }
        }

        requirement def SensorAccuracyRequirement {
            doc /* Pressure sensors shall maintain accuracy within 0.5 percent of full scale. */
            subject sensor : PressureSensor;
            constraint { sensor.accuracy <= 0.005 }
        }

        requirement def FlowMonitoringRequirement {
            doc /* The flow analyzer shall continuously assess flow speed, density, and regime. */
            subject analyzer : FlowAnalyzer;
        }

        requirement def ActuatorRangeRequirement {
            doc /* The actuator shall adjust angle of attack within a safe operating range. */
            subject actuator : Actuator;
            constraint { actuator.currentAoA >= actuator.minAngle and actuator.currentAoA <= actuator.maxAngle }
        }

        requirement def StructuralIntegrityRequirement {
            doc /* The airfoil shall withstand maximum aerodynamic loads without permanent deformation. */
            subject airfoil : Airfoil;
            constraint { airfoil.lift <= 50000.0 [N] and airfoil.drag <= 5000.0 [N] }
        }
    }

    package 'System Assembly' {
        private import 'Part Definitions'::*;
        private import 'Requirement Definitions'::*;

        part activeAirfoilSystem : Airfoil {
            attribute chord = 2.5 [m];
            attribute thickness = 0.3 [m];
            attribute camber = 0.15 [m];
            attribute surfaceArea = 15.0 [m^2];
            attribute mass = 250.0 [kg];
            attribute criticalAngleOfAttack = 15.0 [deg];
            attribute currentAngleOfAttack = 0.0 [deg];

            part upperPressureSensor {
                attribute surfaceSide = "upper";
                attribute accuracy = 0.005;
            }
            part lowerPressureSensor {
                attribute surfaceSide = "lower";
                attribute accuracy = 0.005;
            }
            part actuator {
                attribute currentAoA = 0.0 [deg];
                attribute minAngle = -5.0 [deg];
                attribute maxAngle = 20.0 [deg];
                attribute maxRotationRate = 100.0 [deg/s];
            }
            part flowAnalyzer;

            satisfy LiftGenerationRequirement;
            satisfy StallPreventionRequirement;
            satisfy StallRecoveryTimeRequirement by actuator;
            satisfy SensorAccuracyRequirement by upperPressureSensor;
            satisfy FlowMonitoringRequirement by flowAnalyzer;
            satisfy ActuatorRangeRequirement by actuator;
            satisfy StructuralIntegrityRequirement;
        }
    }
}
