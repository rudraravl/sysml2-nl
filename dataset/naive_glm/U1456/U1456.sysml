package CFD_System {
    import ScalarValues::*;
    import SI::*;

    // ===== Value Types =====

    value type DensityValue :> Real { unit 'kg/m^3'; }
    value type ViscosityValue :> Real { unit 'Pa.s'; }
    value type PressureValue :> Real { unit 'Pa'; }
    value type VelocityComponent :> Real { unit 'm/s'; }
    value type TimeStepValue :> Real { unit 's'; }
    value type LengthValue :> Real { unit 'm'; }
    value type AccelerationValue :> Real { unit 'm/s^2'; }
    value type ForcePerVolumeValue :> Real { unit 'N/m^3'; }
    value type DivergenceValue :> Real { unit '1/s'; }
    value type ReynoldsNumber :> Real { }

    // ===== Item Definitions =====

    item def VelocityVector {
        attribute x : VelocityComponent;
        attribute y : VelocityComponent;
        attribute z : VelocityComponent;
    }

    item def FluidProperties {
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;
        attribute reynoldsNumber : ReynoldsNumber;
    }

    item def CellState {
        attribute velocity : VelocityVector;
        attribute pressure : PressureValue;
        attribute density : DensityValue;
    }

    item def BodyForce {
        attribute gravity : AccelerationValue;
        attribute fx : ForcePerVolumeValue;
        attribute fy : ForcePerVolumeValue;
        attribute fz : ForcePerVolumeValue;
    }

    item def SimulationParameters {
        attribute timeStep : TimeStepValue;
        attribute currentTime : TimeStepValue;
        attribute maxTime : TimeStepValue;
        attribute iterationCount : Integer;
    }

    abstract item def BoundaryCondition;

    item def InletVelocityBC :> BoundaryCondition {
        attribute velocity : VelocityVector;
        attribute position : LengthValue;
    }

    item def OutletPressureBC :> BoundaryCondition {
        attribute pressure : PressureValue;
        attribute position : LengthValue;
    }

    item def SolidWallBC :> BoundaryCondition {
        attribute noSlip : Boolean;
        attribute position : LengthValue;
    }

    // ===== Port Definitions =====

    port def VelocityOutPort {
        out velocity : VelocityVector;
    }

    port def VelocityInPort {
        in velocity : VelocityVector;
    }

    port def PressureOutPort {
        out pressure : PressureValue;
    }

    port def PressureInPort {
        in pressure : PressureValue;
    }

    port def CellStateOutPort {
        out cellState : CellState;
    }

    port def CellStateInPort {
        in cellState : CellState;
    }

    port def BoundaryConditionOutPort {
        out boundaryCondition : BoundaryCondition;
    }

    port def BoundaryConditionInPort {
        in boundaryCondition : BoundaryCondition;
    }

    port def FluidPropertiesOutPort {
        out fluidProperties : FluidProperties;
    }

    port def FluidPropertiesInPort {
        in fluidProperties : FluidProperties;
    }

    port def BodyForceOutPort {
        out bodyForce : BodyForce;
    }

    port def BodyForceInPort {
        in bodyForce : BodyForce;
    }

    port def CommandPort {
        in command : String;
        out status : String;
    }

    // ===== Part Definitions =====

    part def FluidCell {
        attribute id : Integer;
        attribute posX : LengthValue;
        attribute posY : LengthValue;
        attribute posZ : LengthValue;
        attribute cellSize : LengthValue;

        attribute velocity : VelocityVector;
        attribute pressure : PressureValue;
        attribute density : DensityValue;

        port stateOutput : CellStateOutPort;

        action def UpdateCellState {
            in newVelocity : VelocityVector;
            in newPressure : PressureValue;
            in newDensity : DensityValue;
        }

        action update : UpdateCellState;
    }

    part def ComputationalDomain {
        attribute nx : Integer;
        attribute ny : Integer;
        attribute nz : Integer;
        attribute lengthX : LengthValue;
        attribute lengthY : LengthValue;
        attribute lengthZ : LengthValue;

        part cells : FluidCell[nx, ny, nz];

        port boundaryInputs : BoundaryConditionInPort[0..*];
        port stateOutput : CellStateOutPort;

        action def InitializeGrid {
            in xCells : Integer;
            in yCells : Integer;
            in zCells : Integer;
            in xLength : LengthValue;
            in yLength : LengthValue;
            in zLength : LengthValue;
        }

        action initialize : InitializeGrid;
    }

    part def ConvectionSolver {
        attribute name : String = "ConvectionSolver";

        port velocityInput : VelocityInPort;
        port velocityOutput : VelocityOutPort;

        action def ComputeConvection {
            in velocities : VelocityVector[0..*];
            in dt : TimeStepValue;
            in cellSize : LengthValue;
            out convectedVelocities : VelocityVector[0..*];
        }

        action compute : ComputeConvection;
    }

    part def DiffusionSolver {
        attribute name : String = "DiffusionSolver";

        port velocityInput : VelocityInPort;
        port velocityOutput : VelocityOutPort;

        action def ComputeDiffusion {
            in velocities : VelocityVector[0..*];
            in viscosity : ViscosityValue;
            in dt : TimeStepValue;
            in cellSize : LengthValue;
            out diffusedVelocities : VelocityVector[0..*];
        }

        action compute : ComputeDiffusion;
    }

    part def PressureCorrector {
        attribute name : String = "PressureCorrector";

        port velocityInput : VelocityInPort;
        port pressureInput : PressureInPort;
        port velocityOutput : VelocityOutPort;
        port pressureOutput : PressureOutPort;

        action def SolvePressure {
            in velocities : VelocityVector[0..*];
            in pressure : PressureValue[0..*];
            in density : DensityValue;
            in dt : TimeStepValue;
            in cellSize : LengthValue;
            out correctedPressure : PressureValue[0..*];
            out correctedVelocity : VelocityVector[0..*];
        }

        action solve : SolvePressure;
    }

    part def ContinuityEnforcer {
        attribute name : String = "ContinuityEnforcer";

        port velocityInput : VelocityInPort;
        port velocityOutput : VelocityOutPort;

        action def EnforceContinuity {
            in velocities : VelocityVector[0..*];
            in density : DensityValue;
            in cellSize : LengthValue;
            out divergence : DivergenceValue;
            out correctedVelocities : VelocityVector[0..*];
        }

        action enforce : EnforceContinuity;
    }

    part def NavierStokesSolver {
        attribute solverName : String = "NavierStokesSolver";
        attribute timeStep : TimeStepValue;
        attribute currentTime : TimeStepValue;
        attribute maxTime : TimeStepValue;
        attribute iterationCount : Integer;

        part convection : ConvectionSolver;
        part diffusion : DiffusionSolver;
        part pressureCorrector : PressureCorrector;
        part continuityEnforcer : ContinuityEnforcer;

        port commandPort : CommandPort;
        port fluidPropsInput : FluidPropertiesInPort;
        port bodyForceInput : BodyForceInPort;
        port cellStateInput : CellStateInPort;
        port cellStateOutput : CellStateOutPort;

        connect convection.velocityOutput to diffusion.velocityInput;
        connect diffusion.velocityOutput to pressureCorrector.velocityInput;
        connect pressureCorrector.velocityOutput to continuityEnforcer.velocityInput;
        connect continuityEnforcer.velocityOutput to cellStateOutput;
        connect cellStateInput to convection.velocityInput;

        action def PerformTimeStep {
            in dt : TimeStepValue;
            in fluidProps : FluidProperties;
            in bodyForce : BodyForce;

            perform convection.compute;
            then perform diffusion.compute;
            then perform pressureCorrector.solve;
            then perform continuityEnforcer.enforce;
            then assign currentTime := currentTime + dt;
            then assign iterationCount := iterationCount + 1;
        }

        action timeStep : PerformTimeStep;

        state def SolverLifecycle {
            initial -> Initializing;

            state Initializing {
                entry {
                    assign currentTime := 0.0;
                    assign iterationCount := 0;
                    assign commandPort.status := "initializing";
                }
                do {
                    perform convection.compute;
                    perform diffusion.compute;
                    perform pressureCorrector.solve;
                    perform continuityEnforcer.enforce;
                }
            }

            transition from Initializing to Computing
                when commandPort.command == "run";

            state Computing {
                entry {
                    assign commandPort.status := "computing";
                    perform timeStep;
                }
            }

            transition from Computing to Computing
                when currentTime < maxTime;

            transition from Computing to Completing
                when currentTime >= maxTime;

            state Completing {
                entry {
                    assign commandPort.status := "completed";
                }
            }

            transition from Completing to done;

            state done {
                entry {
                    assign commandPort.status := "finished";
                }
            }
        }

        state lifecycle : SolverLifecycle;
    }

    part def FluidPropertiesProvider {
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;

        port propsOutput : FluidPropertiesOutPort;
    }

    part def BodyForceProvider {
        attribute gravity : AccelerationValue;
        attribute fx : ForcePerVolumeValue;
        attribute fy : ForcePerVolumeValue;
        attribute fz : ForcePerVolumeValue;

        port forceOutput : BodyForceOutPort;
    }

    part def InletBoundary {
        attribute velocity : VelocityVector;
        attribute position : LengthValue;

        port bcOutput : BoundaryConditionOutPort;
    }

    part def OutletBoundary {
        attribute pressure : PressureValue;
        attribute position : LengthValue;

        port bcOutput : BoundaryConditionOutPort;
    }

    part def WallBoundary {
        attribute noSlip : Boolean;
        attribute position : LengthValue;

        port bcOutput : BoundaryConditionOutPort;
    }

    part def CFDApplication {
        attribute applicationName : String = "CFD Simulator";

        part domain : ComputationalDomain {
            attribute nx = 100;
            attribute ny = 100;
            attribute nz = 100;
            attribute lengthX = 1.0;
            attribute lengthY = 1.0;
            attribute lengthZ = 1.0;
        }

        part solver : NavierStokesSolver {
            attribute timeStep = 0.001;
            attribute maxTime = 10.0;
        }

        part fluidProps : FluidPropertiesProvider {
            attribute density = 1000.0;
            attribute viscosity = 0.001;
        }

        part bodyForce : BodyForceProvider {
            attribute gravity = 9.81;
            attribute fx = 0.0;
            attribute fy = 0.0;
            attribute fz = -9810.0;
        }

        part inletBC : InletBoundary {
            attribute velocity : VelocityVector {
                attribute x = 1.0;
                attribute y = 0.0;
                attribute z = 0.0;
            }
            attribute position = 0.0;
        }

        part outletBC : OutletBoundary {
            attribute pressure = 0.0;
            attribute position = 1.0;
        }

        part wallBC : WallBoundary {
            attribute noSlip = true;
            attribute position = 0.0;
        }

        connect fluidProps.propsOutput to solver.fluidPropsInput;
        connect bodyForce.forceOutput to solver.bodyForceInput;
        connect domain.stateOutput to solver.cellStateInput;
        connect solver.cellStateOutput to domain.stateOutput;
        connect inletBC.bcOutput to domain.boundaryInputs;
        connect outletBC.bcOutput to domain.boundaryInputs;
        connect wallBC.bcOutput to domain.boundaryInputs;
    }

    // ===== Requirements =====

    requirement def SolveNavierStokes {
        doc "The system shall numerically solve the incompressible Navier-Stokes equations to predict fluid velocity and pressure over time within a three-dimensional domain.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "The solver shall compute combined effects of convection, diffusion, pressure differences, and external body forces in each time step.";
        }
        requirement {
            doc "The solver shall update velocity and pressure in every fluid cell during each time step.";
        }
    }

    requirement def MassConservation {
        doc "The system shall enforce mass conservation within the computational domain, preventing artificial creation or destruction of fluid.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "The Continuity Enforcer shall ensure the divergence of the velocity field approaches zero for incompressible flow.";
        }
        requirement {
            doc "The Pressure Corrector and Continuity Enforcer shall collaborate to maintain mass conservation.";
        }
    }

    requirement def TimeStepping {
        doc "The system shall advance the simulation in discrete time steps.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "Each time step shall execute convection, diffusion, pressure correction, and continuity enforcement in sequence.";
        }
        requirement {
            doc "The simulation shall generate a complete history of fluid dynamic behavior over the configured time range.";
        }
    }

    requirement def BoundaryConditionSupport {
        doc "The system shall support inlet velocity, outlet pressure, and solid wall boundary conditions.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "Inlet boundary conditions shall prescribe a velocity vector at the domain inlet.";
        }
        requirement {
            doc "Outlet boundary conditions shall prescribe a pressure at the domain outlet.";
        }
        requirement {
            doc "Solid wall boundary conditions shall enforce no-slip conditions at wall surfaces.";
        }
    }

    requirement def ViscousFlowModeling {
        doc "The system shall model viscous effects through the Diffusion Solver based on fluid viscosity.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "The Diffusion Solver shall compute viscous diffusion terms that smooth out velocity differences.";
        }
    }

    requirement def ConvectionModeling {
        doc "The system shall model convective momentum transport through the Convection Solver.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "The Convection Solver shall calculate how the fluid carries its own momentum.";
        }
    }

    requirement def LifecycleManagement {
        doc "The system shall manage its operational lifecycle through initializing, computing, and completing states.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "The solver state machine shall transition from initializing to computing upon receiving a run command.";
        }
        requirement {
            doc "The solver shall transition from computing to completing when the current time reaches the maximum simulation time.";
        }
    }

    requirement def DomainDiscretization {
        doc "The system shall discretize the computational domain into a three-dimensional grid of fluid cells.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "Each fluid cell shall track local velocity vector, pressure, and density at its specific location.";
        }
        requirement {
            doc "The domain grid shall be configurable in terms of cell count and physical dimensions.";
        }
    }

    requirement def FluidPropertyConfiguration {
        doc "The system shall allow users to define physical properties of the fluid including density and viscosity.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "Fluid density and viscosity shall be used by the Diffusion Solver and Pressure Corrector.";
        }
    }

    requirement def BodyForceModeling {
        doc "The system shall account for external body forces such as gravity during simulation.";
        subject cfdApp : CFDApplication;

        requirement {
            doc "Body forces shall be applied during each time step to update the velocity field.";
        }
    }

    // ===== Requirement Satisfaction =====

    satisfaction def CFDRequirementsSatisfied {
        subject cfdApp : CFDApplication;

        satisfy SolveNavierStokes by cfdApp.solver;
        satisfy MassConservation by cfdApp.solver.continuityEnforcer;
        satisfy TimeStepping by cfdApp.solver;
        satisfy BoundaryConditionSupport by cfdApp.domain;
        satisfy ViscousFlowModeling by cfdApp.solver.diffusion;
        satisfy ConvectionModeling by cfdApp.solver.convection;
        satisfy LifecycleManagement by cfdApp.solver;
        satisfy DomainDiscretization by cfdApp.domain;
        satisfy FluidPropertyConfiguration by cfdApp.fluidProps;
        satisfy BodyForceModeling by cfdApp.bodyForce;
    }
}
