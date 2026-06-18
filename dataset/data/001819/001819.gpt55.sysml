package NavierStokesFluidSystemModel {

    import ScalarValues::*;

    attribute def Length :> Real {
        attribute unitSymbol : String = "m";
    }

    attribute def Area :> Real {
        attribute unitSymbol : String = "m^2";
    }

    attribute def Volume :> Real {
        attribute unitSymbol : String = "m^3";
    }

    attribute def Time :> Real {
        attribute unitSymbol : String = "s";
    }

    attribute def Mass :> Real {
        attribute unitSymbol : String = "kg";
    }

    attribute def Density :> Real {
        attribute unitSymbol : String = "kg/m^3";
    }

    attribute def DynamicViscosity :> Real {
        attribute unitSymbol : String = "Pa*s";
    }

    attribute def KinematicViscosity :> Real {
        attribute unitSymbol : String = "m^2/s";
    }

    attribute def Pressure :> Real {
        attribute unitSymbol : String = "Pa";
    }

    attribute def Temperature :> Real {
        attribute unitSymbol : String = "K";
    }

    attribute def Velocity :> Real {
        attribute unitSymbol : String = "m/s";
    }

    attribute def Acceleration :> Real {
        attribute unitSymbol : String = "m/s^2";
    }

    attribute def Force :> Real {
        attribute unitSymbol : String = "N";
    }

    attribute def VolumetricFlowRate :> Real {
        attribute unitSymbol : String = "m^3/s";
    }

    attribute def MassFlowRate :> Real {
        attribute unitSymbol : String = "kg/s";
    }

    attribute def Frequency :> Real {
        attribute unitSymbol : String = "Hz";
    }

    attribute def Dimensionless :> Real {
        attribute unitSymbol : String = "1";
    }

    attribute def ResidualNorm :> Real {
        attribute unitSymbol : String = "1";
    }

    attribute def CellCount :> Integer {
        attribute unitSymbol : String = "cell";
    }

    attribute def Vector3D {
        attribute x : Real;
        attribute y : Real;
        attribute z : Real;
    }

    attribute def PositionVector {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    attribute def VelocityVector {
        attribute x : Velocity;
        attribute y : Velocity;
        attribute z : Velocity;
    }

    attribute def AccelerationVector {
        attribute x : Acceleration;
        attribute y : Acceleration;
        attribute z : Acceleration;
    }

    attribute def ForceVector {
        attribute x : Force;
        attribute y : Force;
        attribute z : Force;
    }

    attribute def GradientTensor3x3 {
        attribute xx : Real;
        attribute xy : Real;
        attribute xz : Real;
        attribute yx : Real;
        attribute yy : Real;
        attribute yz : Real;
        attribute zx : Real;
        attribute zy : Real;
        attribute zz : Real;
    }

    enum def BoundaryConditionKind {
        enum noSlipWall;
        enum velocityInlet;
        enum pressureOutlet;
        enum symmetryPlane;
        enum periodicPair;
    }

    enum def SolverMode {
        enum steady;
        enum transient;
    }

    enum def TurbulenceClosureKind {
        enum laminar;
        enum largeEddySimulation;
        enum reynoldsAveragedKOmegaSST;
    }

    item def FluidMaterial {
        attribute name : String;
        attribute density : Density;
        attribute dynamicViscosity : DynamicViscosity;
        attribute kinematicViscosity : KinematicViscosity;
        attribute referenceTemperature : Temperature;
    }

    item def MeshCell {
        attribute cellId : Integer;
        attribute centroid : PositionVector;
        attribute volume : Volume;
        attribute minimumFaceArea : Area;
        attribute characteristicLength : Length;
    }

    item def ComputationalMesh {
        attribute cellCount : CellCount;
        attribute boundaryFaceCount : Integer;
        attribute minimumCellLength : Length;
        attribute maximumCellLength : Length;
        attribute meanCellVolume : Volume;
        item cells : MeshCell[1..*];
    }

    item def FluidStateSample {
        attribute sampleTime : Time;
        attribute position : PositionVector;
        attribute velocity : VelocityVector;
        attribute pressure : Pressure;
        attribute density : Density;
        attribute temperature : Temperature;
        attribute vorticity : Vector3D;
    }

    item def FlowField {
        attribute time : Time;
        attribute meanPressure : Pressure;
        attribute maximumVelocityMagnitude : Velocity;
        attribute minimumPressure : Pressure;
        attribute maximumPressure : Pressure;
        attribute continuityResidual : ResidualNorm;
        attribute momentumResidual : ResidualNorm;
        item samples : FluidStateSample[1..*];
    }

    item def BoundaryCondition {
        attribute name : String;
        attribute kind : BoundaryConditionKind;
        attribute prescribedVelocity : VelocityVector;
        attribute prescribedPressure : Pressure;
        attribute prescribedTemperature : Temperature;
        attribute area : Area;
    }

    item def BoundaryConditionSet {
        item inlet : BoundaryCondition;
        item outlet : BoundaryCondition;
        item walls : BoundaryCondition[1..*];
        item optionalSymmetryPlanes : BoundaryCondition[0..*];
    }

    item def SimulationConfiguration {
        attribute solverMode : SolverMode;
        attribute turbulenceClosure : TurbulenceClosureKind;
        attribute startTime : Time;
        attribute endTime : Time;
        attribute timeStep : Time;
        attribute maximumCourantNumber : Dimensionless;
        attribute pressureTolerance : ResidualNorm;
        attribute momentumTolerance : ResidualNorm;
        attribute maximumIterationsPerStep : Integer;
        attribute gravitationalAcceleration : AccelerationVector;
    }

    item def SolverHealth {
        attribute initialized : Boolean;
        attribute stable : Boolean;
        attribute converged : Boolean;
        attribute currentTime : Time;
        attribute currentStep : Integer;
        attribute courantNumber : Dimensionless;
        attribute continuityResidual : ResidualNorm;
        attribute momentumResidual : ResidualNorm;
    }

    item def SimulationReport {
        attribute completed : Boolean;
        attribute simulatedDuration : Time;
        attribute totalSteps : Integer;
        attribute finalContinuityResidual : ResidualNorm;
        attribute finalMomentumResidual : ResidualNorm;
        attribute peakVelocity : Velocity;
        attribute pressureDrop : Pressure;
        attribute primaryFunctionSummary : String;
    }

    port def MaterialInputPort {
        in item material : FluidMaterial;
    }

    port def MeshInputPort {
        in item mesh : ComputationalMesh;
    }

    port def BoundaryConditionPort {
        in item boundaryConditions : BoundaryConditionSet;
    }

    port def ConfigurationPort {
        in item configuration : SimulationConfiguration;
    }

    port def FlowFieldPort {
        in item field : FlowField;
        out item field : FlowField;
    }

    port def SolverHealthPort {
        out item health : SolverHealth;
    }

    port def ReportPort {
        out item report : SimulationReport;
    }

    port def InletFlowPort {
        in item inletState : FluidStateSample;
    }

    port def OutletFlowPort {
        out item outletState : FluidStateSample;
    }

    port def WallInteractionPort {
        in item wallCondition : BoundaryCondition;
        out item wallShearEstimate : ForceVector;
    }

    constraint def IncompressibleContinuityConstraint {
        in attribute velocityGradientTrace : Real;
        in attribute continuityResidual : ResidualNorm;
        in attribute allowedResidual : ResidualNorm;
        require velocityGradientTrace == 0.0;
        require continuityResidual <= allowedResidual;
    }

    constraint def NavierStokesMomentumConstraint {
        in attribute materialDensity : Density;
        in attribute dynamicViscosity : DynamicViscosity;
        in attribute momentumResidual : ResidualNorm;
        in attribute allowedResidual : ResidualNorm;
        require materialDensity > 0.0;
        require dynamicViscosity > 0.0;
        require momentumResidual <= allowedResidual;
    }

    constraint def CourantStabilityConstraint {
        in attribute courantNumber : Dimensionless;
        in attribute maximumCourantNumber : Dimensionless;
        require courantNumber > 0.0;
        require courantNumber <= maximumCourantNumber;
    }

    constraint def PositiveTimeStepConstraint {
        in attribute timeStep : Time;
        require timeStep > 0.0;
    }

    constraint def PositiveMeshVolumeConstraint {
        in attribute cellVolume : Volume;
        require cellVolume > 0.0;
    }

    action def LoadSimulationInputs {
        in item material : FluidMaterial;
        in item mesh : ComputationalMesh;
        in item boundaryConditions : BoundaryConditionSet;
        in item configuration : SimulationConfiguration;
        out item initializedField : FlowField;
        out item initialHealth : SolverHealth;
    }

    action def EnforceBoundaryConditions {
        in item incomingField : FlowField;
        in item boundaryConditions : BoundaryConditionSet;
        out item boundedField : FlowField;
    }

    action def ComputeConvectiveTransport {
        in item incomingField : FlowField;
        in item mesh : ComputationalMesh;
        in item configuration : SimulationConfiguration;
        out item convectedField : FlowField;
    }

    action def ComputeViscousDiffusion {
        in item incomingField : FlowField;
        in item material : FluidMaterial;
        in item mesh : ComputationalMesh;
        out item diffusedField : FlowField;
    }

    action def SolvePressurePoissonEquation {
        in item predictedVelocityField : FlowField;
        in item mesh : ComputationalMesh;
        in item boundaryConditions : BoundaryConditionSet;
        in attribute tolerance : ResidualNorm;
        out item pressureCorrectedField : FlowField;
    }

    action def ProjectVelocityToDivergenceFreeField {
        in item pressureCorrectedField : FlowField;
        out item incompressibleField : FlowField;
    }

    action def EvaluateResidualsAndStability {
        in item field : FlowField;
        in item configuration : SimulationConfiguration;
        out item health : SolverHealth;
    }

    action def AdvanceNavierStokesTimeStep {
        in item previousField : FlowField;
        in item material : FluidMaterial;
        in item mesh : ComputationalMesh;
        in item boundaryConditions : BoundaryConditionSet;
        in item configuration : SimulationConfiguration;
        out item nextField : FlowField;
        out item health : SolverHealth;

        action applyBoundaryConditions : EnforceBoundaryConditions {
            in item incomingField = previousField;
            in item boundaryConditions = boundaryConditions;
        }

        action computeAdvection : ComputeConvectiveTransport {
            in item incomingField = applyBoundaryConditions.boundedField;
            in item mesh = mesh;
            in item configuration = configuration;
        }

        action computeDiffusion : ComputeViscousDiffusion {
            in item incomingField = computeAdvection.convectedField;
            in item material = material;
            in item mesh = mesh;
        }

        action solvePressure : SolvePressurePoissonEquation {
            in item predictedVelocityField = computeDiffusion.diffusedField;
            in item mesh = mesh;
            in item boundaryConditions = boundaryConditions;
            in attribute tolerance = configuration.pressureTolerance;
        }

        action projectVelocity : ProjectVelocityToDivergenceFreeField {
            in item pressureCorrectedField = solvePressure.pressureCorrectedField;
        }

        action evaluateHealth : EvaluateResidualsAndStability {
            in item field = projectVelocity.incompressibleField;
            in item configuration = configuration;
        }

        bind nextField = projectVelocity.incompressibleField;
        bind health = evaluateHealth.health;
    }

    action def GenerateSimulationReport {
        in item finalField : FlowField;
        in item finalHealth : SolverHealth;
        in item configuration : SimulationConfiguration;
        out item report : SimulationReport;
    }

    action def SimulateFluidMotion {
        in item material : FluidMaterial;
        in item mesh : ComputationalMesh;
        in item boundaryConditions : BoundaryConditionSet;
        in item configuration : SimulationConfiguration;
        out item finalField : FlowField;
        out item report : SimulationReport;

        action loadInputs : LoadSimulationInputs {
            in item material = material;
            in item mesh = mesh;
            in item boundaryConditions = boundaryConditions;
            in item configuration = configuration;
        }

        action advanceStep : AdvanceNavierStokesTimeStep {
            in item previousField = loadInputs.initializedField;
            in item material = material;
            in item mesh = mesh;
            in item boundaryConditions = boundaryConditions;
            in item configuration = configuration;
        }

        action createReport : GenerateSimulationReport {
            in item finalField = advanceStep.nextField;
            in item finalHealth = advanceStep.health;
            in item configuration = configuration;
        }

        bind finalField = advanceStep.nextField;
        bind report = createReport.report;
    }

    state def SolverLifecycle {
        state idle;
        state inputLoaded;
        state meshValidated;
        state boundaryConditionsApplied;
        state solvingMomentum;
        state solvingPressure;
        state projectingVelocity;
        state checkingConvergence;
        state converged;
        state unstable;
        state completed;

        transition initialToIdle first idle;
        transition loadInput first idle then inputLoaded;
        transition validateMesh first inputLoaded then meshValidated;
        transition applyBoundaries first meshValidated then boundaryConditionsApplied;
        transition solveMomentum first boundaryConditionsApplied then solvingMomentum;
        transition solvePressure first solvingMomentum then solvingPressure;
        transition projectVelocity first solvingPressure then projectingVelocity;
        transition checkConvergence first projectingVelocity then checkingConvergence;
        transition convergedStep first checkingConvergence then converged;
        transition nextStep first converged then boundaryConditionsApplied;
        transition detectedInstability first checkingConvergence then unstable;
        transition finishSimulation first converged then completed;
    }

    part def FluidDomain {
        attribute domainName : String;
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
        attribute volume : Volume;

        port inlet : InletFlowPort;
        port outlet : OutletFlowPort;
        port wall : WallInteractionPort;

        item containedFluid : FluidMaterial;
        item currentFlowField : FlowField;
    }

    part def MeshGenerator {
        port meshOut : MeshInputPort;
        attribute targetMinimumCellLength : Length;
        attribute targetMaximumCellLength : Length;
        attribute generatedCellCount : CellCount;
        item generatedMesh : ComputationalMesh;
    }

    part def BoundaryConditionManager {
        port boundaryOut : BoundaryConditionPort;
        item activeBoundaryConditions : BoundaryConditionSet;
    }

    part def MaterialPropertyManager {
        port materialOut : MaterialInputPort;
        item selectedMaterial : FluidMaterial;
    }

    part def TimeIntegrator {
        port configurationOut : ConfigurationPort;
        attribute currentTime : Time;
        attribute stepSize : Time;
        attribute endTime : Time;
        attribute currentStep : Integer;
    }

    part def MomentumEquationSolver {
        port fieldInOut : FlowFieldPort;
        attribute convectiveResidual : ResidualNorm;
        attribute viscousResidual : ResidualNorm;

        constraint momentumEquation : NavierStokesMomentumConstraint {
            in attribute materialDensity = 998.2;
            in attribute dynamicViscosity = 0.001003;
            in attribute momentumResidual = convectiveResidual;
            in attribute allowedResidual = 0.000001;
        }
    }

    part def PressureProjectionSolver {
        port fieldInOut : FlowFieldPort;
        attribute poissonResidual : ResidualNorm;
        attribute divergenceAfterProjection : Real;

        constraint continuityEquation : IncompressibleContinuityConstraint {
            in attribute velocityGradientTrace = divergenceAfterProjection;
            in attribute continuityResidual = poissonResidual;
            in attribute allowedResidual = 0.000001;
        }
    }

    part def StabilityMonitor {
        port healthOut : SolverHealthPort;
        attribute courantNumber : Dimensionless;
        attribute maximumCourantNumber : Dimensionless;
        attribute stable : Boolean;

        constraint courantLimit : CourantStabilityConstraint {
            in attribute courantNumber = courantNumber;
            in attribute maximumCourantNumber = maximumCourantNumber;
        }
    }

    part def ResultsReporter {
        port fieldIn : FlowFieldPort;
        port reportOut : ReportPort;
        item generatedReport : SimulationReport;
    }

    part def NavierStokesSolver {
        attribute solverName : String = "Projection-method incompressible Navier-Stokes solver";
        attribute primaryFunction : String = "Compute the time evolution of velocity and pressure fields for a viscous incompressible fluid by satisfying mass conservation and momentum balance.";
        attribute lifecycle : SolverLifecycle;

        port materialIn : MaterialInputPort;
        port meshIn : MeshInputPort;
        port boundaryIn : BoundaryConditionPort;
        port configurationIn : ConfigurationPort;
        port fieldInOut : FlowFieldPort;
        port healthOut : SolverHealthPort;
        port reportOut : ReportPort;

        part timeIntegrator : TimeIntegrator;
        part momentumSolver : MomentumEquationSolver;
        part pressureSolver : PressureProjectionSolver;
        part stabilityMonitor : StabilityMonitor;
        part reporter : ResultsReporter;

        perform action simulationBehavior : SimulateFluidMotion;

        connect fieldInOut to momentumSolver.fieldInOut;
        connect momentumSolver.fieldInOut to pressureSolver.fieldInOut;
        connect pressureSolver.fieldInOut to reporter.fieldIn;
        connect stabilityMonitor.healthOut to healthOut;
        connect reporter.reportOut to reportOut;
    }

    part def NavierStokesFlowSystem {
        attribute systemName : String = "High-level Navier-Stokes-based fluid motion analysis system";
        attribute primaryFunction : String = "Predict pressure, velocity, and derived flow quantities in a bounded fluid domain using the Navier-Stokes equations.";

        port materialInput : MaterialInputPort;
        port meshInput : MeshInputPort;
        port boundaryInput : BoundaryConditionPort;
        port configurationInput : ConfigurationPort;
        port fieldOutput : FlowFieldPort;
        port healthOutput : SolverHealthPort;
        port reportOutput : ReportPort;

        part domain : FluidDomain {
            attribute domainName = "rectangular internal channel";
            attribute length = 2.0;
            attribute width = 0.25;
            attribute height = 0.25;
            attribute volume = 0.125;
        }

        part materialManager : MaterialPropertyManager {
            item selectedMaterial : FluidMaterial {
                attribute name = "water at 293 K";
                attribute density = 998.2;
                attribute dynamicViscosity = 0.001003;
                attribute kinematicViscosity = 0.000001004;
                attribute referenceTemperature = 293.15;
            }
        }

        part meshGenerator : MeshGenerator {
            attribute targetMinimumCellLength = 0.0025;
            attribute targetMaximumCellLength = 0.01;
            attribute generatedCellCount = 180000;
        }

        part boundaryManager : BoundaryConditionManager {
            item activeBoundaryConditions : BoundaryConditionSet {
                item inlet : BoundaryCondition {
                    attribute name = "uniform inlet";
                    attribute kind = BoundaryConditionKind::velocityInlet;
                    attribute prescribedVelocity : VelocityVector {
                        attribute x = 1.5;
                        attribute y = 0.0;
                        attribute z = 0.0;
                    }
                    attribute prescribedPressure = 101325.0;
                    attribute prescribedTemperature = 293.15;
                    attribute area = 0.0625;
                }
                item outlet : BoundaryCondition {
                    attribute name = "static pressure outlet";
                    attribute kind = BoundaryConditionKind::pressureOutlet;
                    attribute prescribedVelocity : VelocityVector {
                        attribute x = 0.0;
                        attribute y = 0.0;
                        attribute z = 0.0;
                    }
                    attribute prescribedPressure = 101325.0;
                    attribute prescribedTemperature = 293.15;
                    attribute area = 0.0625;
                }
                item walls : BoundaryCondition[4] {
                    attribute name = "no-slip channel wall";
                    attribute kind = BoundaryConditionKind::noSlipWall;
                    attribute prescribedVelocity : VelocityVector {
                        attribute x = 0.0;
                        attribute y = 0.0;
                        attribute z = 0.0;
                    }
                    attribute prescribedPressure = 101325.0;
                    attribute prescribedTemperature = 293.15;
                    attribute area = 1.0;
                }
            }
        }

        part configurationProvider : TimeIntegrator {
            attribute currentTime = 0.0;
            attribute stepSize = 0.0005;
            attribute endTime = 5.0;
            attribute currentStep = 0;

            constraint positiveStep : PositiveTimeStepConstraint {
                in attribute timeStep = stepSize;
            }
        }

        part solver : NavierStokesSolver;

        connect materialInput to materialManager.materialOut;
        connect meshInput to meshGenerator.meshOut;
        connect boundaryInput to boundaryManager.boundaryOut;
        connect configurationInput to configurationProvider.configurationOut;

        connect materialManager.materialOut to solver.materialIn;
        connect meshGenerator.meshOut to solver.meshIn;
        connect boundaryManager.boundaryOut to solver.boundaryIn;
        connect configurationProvider.configurationOut to solver.configurationIn;

        connect domain.inlet to boundaryManager.boundaryOut;
        connect solver.fieldInOut to fieldOutput;
        connect solver.healthOut to healthOutput;
        connect solver.reportOut to reportOutput;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : NavierStokesFlowSystem;
        require constraint {
            system.primaryFunction == "Predict pressure, velocity, and derived flow quantities in a bounded fluid domain using the Navier-Stokes equations."
        }
    }

    requirement def MassConservationRequirement {
        subject solver : NavierStokesSolver;
        attribute maximumAllowedContinuityResidual : ResidualNorm = 0.000001;
        require constraint {
            solver.pressureSolver.poissonResidual <= maximumAllowedContinuityResidual
        }
    }

    requirement def MomentumBalanceRequirement {
        subject solver : NavierStokesSolver;
        attribute maximumAllowedMomentumResidual : ResidualNorm = 0.000001;
        require constraint {
            solver.momentumSolver.convectiveResidual <= maximumAllowedMomentumResidual
        }
    }

    requirement def NumericalStabilityRequirement {
        subject solver : NavierStokesSolver;
        attribute maximumCourantNumber : Dimensionless = 0.5;
        require constraint {
            solver.stabilityMonitor.courantNumber <= maximumCourantNumber
        }
    }

    requirement def PositivePhysicalPropertiesRequirement {
        subject system : NavierStokesFlowSystem;
        require constraint {
            system.materialManager.selectedMaterial.density > 0.0 and
            system.materialManager.selectedMaterial.dynamicViscosity > 0.0 and
            system.domain.volume > 0.0
        }
    }

    requirement def BoundaryConditionCompletenessRequirement {
        subject system : NavierStokesFlowSystem;
        require constraint {
            system.boundaryManager.activeBoundaryConditions.inlet.area > 0.0 and
            system.boundaryManager.activeBoundaryConditions.outlet.area > 0.0
        }
    }

    requirement primaryFunctionReq : PrimaryFunctionRequirement {
        subject system = navierStokesFlowSystem;
    }

    requirement massConservationReq : MassConservationRequirement {
        subject solver = navierStokesFlowSystem.solver;
    }

    requirement momentumBalanceReq : MomentumBalanceRequirement {
        subject solver = navierStokesFlowSystem.solver;
    }

    requirement stabilityReq : NumericalStabilityRequirement {
        subject solver = navierStokesFlowSystem.solver;
    }

    requirement physicalPropertiesReq : PositivePhysicalPropertiesRequirement {
        subject system = navierStokesFlowSystem;
    }

    requirement boundaryCompletenessReq : BoundaryConditionCompletenessRequirement {
        subject system = navierStokesFlowSystem;
    }

    part navierStokesFlowSystem : NavierStokesFlowSystem;

    satisfy primaryFunctionReq by navierStokesFlowSystem;
    satisfy massConservationReq by navierStokesFlowSystem.solver.pressureSolver;
    satisfy momentumBalanceReq by navierStokesFlowSystem.solver.momentumSolver;
    satisfy stabilityReq by navierStokesFlowSystem.solver.stabilityMonitor;
    satisfy physicalPropertiesReq by navierStokesFlowSystem.materialManager;
    satisfy boundaryCompletenessReq by navierStokesFlowSystem.boundaryManager;
}
