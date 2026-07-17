package 'NavierStokesFluidSimulationSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;

    attribute def VelocityVector3D {
        attribute u : SpeedValue;
        attribute v : SpeedValue;
        attribute w : SpeedValue;
    }

    attribute def PressureField {
        attribute p : PressureValue;
    }

    attribute def ViscosityProperties {
        attribute dynamicViscosity : Real;
        attribute kinematicViscosity : Real;
    }

    attribute def FluidProperties {
        attribute density : DensityValue;
        attribute viscosity : ViscosityProperties;
    }

    attribute def SpatialDerivatives {
        attribute dx : LengthValue;
        attribute dy : LengthValue;
        attribute dz : LengthValue;
    }

    attribute def BodyForceVector {
        attribute fx : ForceValue;
        attribute fy : ForceValue;
        attribute fz : ForceValue;
    }

    item def FluidCell {
        attribute position : SpatialDerivatives;
        attribute velocity : VelocityVector3D;
        attribute pressure : PressureField;
        attribute localDensity : DensityValue;
    }

    item def BoundaryConditionSpec {
        attribute boundaryType : String;
        attribute inletVelocity : VelocityVector3D;
        attribute outletPressure : PressureValue;
        attribute wallCondition : String;
    }

    port def FluidDataPort {
        in attribute velocityIn : VelocityVector3D;
        in attribute pressureIn : PressureField;
        out attribute velocityOut : VelocityVector3D;
        out attribute pressureOut : PressureField;
    }

    part def ComputationalDomain {
        attribute domainLength : LengthValue;
        attribute domainWidth : LengthValue;
        attribute domainHeight : LengthValue;
        attribute meshResolution : Integer;
        part cells : FluidCell[*];
        part boundaryConditions : BoundaryConditionSpec[*];
    }

    part def ConvectionSolver {
        port dataIn : FluidDataPort;
        port dataOut : FluidDataPort;
        attribute convectiveTerm : Real;
    }

    part def DiffusionSolver {
        port dataIn : FluidDataPort;
        port dataOut : FluidDataPort;
        attribute diffusiveTerm : Real;
    }

    part def PressureCorrector {
        port dataIn : FluidDataPort;
        port dataOut : FluidDataPort;
        attribute pressureCorrection : PressureValue;
    }

    part def ContinuityEnforcer {
        port dataIn : FluidDataPort;
        port dataOut : FluidDataPort;
        attribute divergence : Real;
    }

    action def ComputeConvectiveTerm {
        in attribute velocity : VelocityVector3D;
        in attribute spatialStep : SpatialDerivatives;
        out attribute convectiveAcceleration : Real;
    }

    action def ComputeDiffusiveTerm {
        in attribute velocity : VelocityVector3D;
        in attribute viscosity : ViscosityProperties;
        in attribute density : DensityValue;
        in attribute spatialStep : SpatialDerivatives;
        out attribute viscousAcceleration : Real;
    }

    action def ComputePressureGradient {
        in attribute pressure : PressureField;
        in attribute density : DensityValue;
        in attribute spatialStep : SpatialDerivatives;
        out attribute pressureAcceleration : Real;
    }

    action def EnforceContinuity {
        in attribute velocity : VelocityVector3D;
        in attribute density : DensityValue;
        in attribute spatialStep : SpatialDerivatives;
        out attribute divergenceFreeVelocity : VelocityVector3D;
        out attribute massConservationError : Real;
    }

    action def SolveNavierStokesTimeStep {
        in attribute currentVelocity : VelocityVector3D;
        in attribute currentPressure : PressureField;
        in attribute fluidProps : FluidProperties;
        in attribute bodyForce : BodyForceVector;
        in attribute timeStep : TimeValue;
        in attribute spatialStep : SpatialDerivatives;
        out attribute updatedVelocity : VelocityVector3D;
        out attribute updatedPressure : PressureField;

        first start;
        then action convection : ComputeConvectiveTerm {
            in attribute velocity = currentVelocity;
            in attribute spatialStep = spatialStep;
            out convectiveAcceleration;
        }
        then action diffusion : ComputeDiffusiveTerm {
            in attribute velocity = currentVelocity;
            in attribute viscosity = fluidProps.viscosity;
            in attribute density = fluidProps.density;
            in attribute spatialStep = spatialStep;
            out viscousAcceleration;
        }
        then action pressureGrad : ComputePressureGradient {
            in attribute pressure = currentPressure;
            in attribute density = fluidProps.density;
            in attribute spatialStep = spatialStep;
            out pressureAcceleration;
        }
        then action updateVelocity {
            in attribute convective = convection.convectiveAcceleration;
            in attribute viscous = diffusion.viscousAcceleration;
            in attribute pressureAcc = pressureGrad.pressureAcceleration;
            in attribute force = bodyForce;
            in attribute dt = timeStep;
        }
        then action continuity : EnforceContinuity {
            in attribute velocity = currentVelocity;
            in attribute density = fluidProps.density;
            in attribute spatialStep = spatialStep;
            out divergenceFreeVelocity;
            out massConservationError;
        }
        then assign updatedVelocity := continuity.divergenceFreeVelocity;
        then assign updatedPressure := currentPressure;
        then done;
    }

    action def RunFluidSimulation {
        in attribute totalSimulationTime : TimeValue;
        in attribute deltaTime : TimeValue;
        in attribute initialVelocityField : VelocityVector3D;
        in attribute initialPressureField : PressureField;
        in attribute fluidProperties : FluidProperties;
        in attribute externalForces : BodyForceVector;
        in attribute spatialDiscretization : SpatialDerivatives;
        out attribute velocityHistory : VelocityVector3D[*] := ( );
        out attribute pressureHistory : PressureField[*] := ( );

        private attribute currentVelocity : VelocityVector3D := initialVelocityField;
        private attribute currentPressure : PressureField := initialPressureField;
        private attribute elapsedTime : TimeValue := 0.0[s];

        first start;
        then merge continueIteration;
        then decide;
            if elapsedTime < totalSimulationTime then solveStep;
            if elapsedTime >= totalSimulationTime then finalize;

        action solveStep : SolveNavierStokesTimeStep {
            in attribute currentVelocity = currentVelocity;
            in attribute currentPressure = currentPressure;
            in attribute fluidProps = fluidProperties;
            in attribute bodyForce = externalForces;
            in attribute timeStep = deltaTime;
            in attribute spatialStep = spatialDiscretization;
            out updatedVelocity;
            out updatedPressure;
        }
        then assign currentVelocity := solveStep.updatedVelocity;
        then assign currentPressure := solveStep.updatedPressure;
        then assign elapsedTime := elapsedTime + deltaTime;
        then assign velocityHistory := velocityHistory->including(currentVelocity);
        then assign pressureHistory := pressureHistory->including(currentPressure);
        then continueIteration;

        action finalize;
        then done;
    }

    state def SimulationState {
        entry; then idle;
        state idle;
        state initializing;
        state computing;
        state converged;
        state completed;

        transition initialize first idle then initializing;
        transition startComputation first initializing then computing;
        transition checkConvergence first computing then converged;
        transition continueComputation first computing then computing;
        transition finish first converged then completed;
    }

    part def NavierStokesSolver {
        part domain : ComputationalDomain;
        part convectionSolver : ConvectionSolver;
        part diffusionSolver : DiffusionSolver;
        part pressureCorrector : PressureCorrector;
        part continuityEnforcer : ContinuityEnforcer;

        connect convectionSolver.dataOut to diffusionSolver.dataIn;
        connect diffusionSolver.dataOut to pressureCorrector.dataIn;
        connect pressureCorrector.dataOut to continuityEnforcer.dataIn;

        attribute fluidProps : FluidProperties {
            attribute density = 1000.0[kg/(m^3)];
            attribute viscosity : ViscosityProperties {
                attribute dynamicViscosity = 0.001;
                attribute kinematicViscosity = 0.000001;
            }
        }

        perform action executeSimulation[*] ordered : RunFluidSimulation;
        state simulationLifecycle : SimulationState;
    }

    requirement def NavierStokesEquationRequirement {
        doc /* 
        The system shall solve the incompressible Navier-Stokes equations:
        ∂u/∂t + (u·∇)u = -∇p/ρ + ν∇²u + f
        ∇·u = 0
        where u is velocity, p is pressure, ρ is density, ν is kinematic viscosity, and f is body force.
        */

        require constraint momentumConservation {
            doc /* The momentum equation shall balance convective, diffusive, pressure, and body force terms. */
        }

        require constraint massConservation {
            doc /* The continuity equation shall enforce zero divergence for incompressible flow. */
        }

        require constraint boundaryConditions {
            doc /* Appropriate boundary conditions shall be applied at all domain boundaries. */
        }
    }

    requirement def NumericalStabilityRequirement {
        doc /* The numerical solution shall remain stable throughout the simulation. */

        require constraint cflCondition {
            doc /* The Courant-Friedrichs-Lewy (CFL) condition shall be satisfied: CFL = u·Δt/Δx < 1. */
        }

        require constraint convergenceCriteria {
            doc /* Iterative solvers shall converge to within specified tolerance limits. */
        }
    }

    requirement def AccuracyRequirement {
        doc /* The simulation shall maintain specified accuracy levels. */

        require constraint spatialAccuracy {
            doc /* Spatial discretization error shall be less than 2% of characteristic velocity. */
        }

        require constraint temporalAccuracy {
            doc /* Temporal discretization error shall be less than 1% per time step. */
        }
    }

    part navierStokesSimulationSystem : NavierStokesSolver {
        doc /* 
        This system models incompressible viscous fluid flow governed by the Navier-Stokes equations.
        
        Its primary function is to simulate the time-dependent motion of fluids by numerically solving
        the fundamental equations of fluid dynamics. The system computes how velocity and pressure fields
        evolve throughout a three-dimensional spatial domain over time.
        
        The simulation operates through successive time-stepping iterations. At each time step, the system
        calculates the convective transport of momentum as fluid particles carry momentum through the domain,
        computes diffusive effects arising from fluid viscosity that smooth out velocity gradients, evaluates
        pressure-driven flow resulting from pressure differences, and incorporates external body forces such
        as gravity.
        
        The system enforces the fundamental physical constraint of mass conservation through the continuity
        equation, ensuring that the velocity field remains divergence-free for incompressible flow. It balances
        all momentum equation terms—convection, diffusion, pressure gradient, and body forces—to update the
        velocity field, then corrects the pressure field to maintain mass conservation.
        
        This iterative process repeats continuously, advancing the solution forward in time while preserving
        physical conservation laws and maintaining numerical stability. The result is a complete temporal
        history of the fluid's velocity and pressure distribution, enabling analysis of complex flow phenomena
        including turbulence, vortex formation, boundary layer development, and flow separation.
        */

        satisfy NavierStokesEquationRequirement;
        satisfy NumericalStabilityRequirement;
        satisfy AccuracyRequirement;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    private import NavierStokesFluidSimulationSystem::*;

    part testSubject : ComputationalDomain {
        exhibit state sm : SimulationState;
    }

    action orchestrator {
        attribute testCurrentVelocity : VelocityVector3D {
            attribute u : SpeedValue;
            attribute v : SpeedValue;
            attribute w : SpeedValue;
        }
        attribute testCurrentPressure : PressureField {
            attribute p : PressureValue;
        }
        attribute testFluidProps : FluidProperties {
            attribute density : DensityValue;
            attribute viscosity : ViscosityProperties {
                attribute dynamicViscosity = 0.0;
                attribute kinematicViscosity = 0.0;
            }
        }
        attribute testBodyForce : BodyForceVector {
            attribute fx : ForceValue;
            attribute fy : ForceValue;
            attribute fz : ForceValue;
        }
        attribute testTimeStep : TimeValue;
        attribute testSpatialStep : SpatialDerivatives {
            attribute dx : LengthValue;
            attribute dy : LengthValue;
            attribute dz : LengthValue;
        }
        action solveStepProbe : SolveNavierStokesTimeStep {
            in currentVelocity = testCurrentVelocity;
            in currentPressure = testCurrentPressure;
            in fluidProps = testFluidProps;
            in bodyForce = testBodyForce;
            in timeStep = testTimeStep;
            in spatialStep = testSpatialStep;
        }
        first solveStepProbe;
    }
}
