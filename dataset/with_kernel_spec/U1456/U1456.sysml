package 'Navier-Stokes Fluid Simulation' {
	private import ISQ::*;
	private import ScalarValues::*;
	private import SequenceFunctions::*;

	package 'Port Definitions' {
		port def FlowPort {
			attribute u :> ISQ::speed;
			attribute v :> ISQ::speed;
			attribute w :> ISQ::speed;
			attribute p :> ISQ::pressure;
		}

		port def InflowPort {
			attribute u :> ISQ::speed;
			attribute v :> ISQ::speed;
			attribute w :> ISQ::speed;
		}

		port def OutflowPort {
			attribute p :> ISQ::pressure;
		}
	}

	package 'Fluid Model' {
		part def Fluid {
			attribute density :> ISQ::massDensity;
			attribute dynamicViscosity :> ISQ::dynamicViscosity;
			attribute kinematicViscosity :> ISQ::kinematicViscosity = dynamicViscosity / density;
		}
	}

	package 'Spatial Discretization' {
		private import 'Fluid Model'::*;
		private import 'Port Definitions'::*;

		part def FluidCell {
			comment /* A single cell in the computational grid tracking local fluid properties. */
			attribute i : Natural;
			attribute j : Natural;
			attribute k : Natural;
			attribute x :> ISQ::length;
			attribute y :> ISQ::length;
			attribute z :> ISQ::length;
			attribute u :> ISQ::speed;
			attribute v :> ISQ::speed;
			attribute w :> ISQ::speed;
			attribute p :> ISQ::pressure;
			attribute rho :> ISQ::massDensity;
		}

		part def ComputationalDomain {
			comment /* The three-dimensional space where fluid flow is simulated on a discretized grid. */
			attribute nX : Natural;
			attribute nY : Natural;
			attribute nZ : Natural;
			attribute dx :> ISQ::length;
			attribute dy :> ISQ::length;
			attribute dz :> ISQ::length;
			part cells : FluidCell[*];
			port inflow : FlowPort;
			port outflow : FlowPort;
		}
	}

	package 'Boundary Conditions' {
		item def BoundaryCondition {
			comment /* Base type for all boundary condition specifications. */
		}

		item def InletVelocityBoundary specializes BoundaryCondition {
			comment /* Prescribes velocity components at the domain inlet. */
			attribute u :> ISQ::speed;
			attribute v :> ISQ::speed;
			attribute w :> ISQ::speed;
		}

		item def OutletPressureBoundary specializes BoundaryCondition {
			comment /* Prescribes static pressure at the domain outlet. */
			attribute pOut :> ISQ::pressure;
		}

		item def WallBoundary specializes BoundaryCondition {
			comment /* Solid wall boundary; noSlip enforces zero velocity. */
			attribute noSlip : Boolean = true;
		}
	}

	package 'Solver Modules' {
		private import 'Spatial Discretization'::*;
		private import 'Fluid Model'::*;
		private import 'Boundary Conditions'::*;

		calc def ConvectiveAccel {
			comment /* Convective acceleration term: -(u * du/dx). */
			in u : SpeedValue;
			in grad_u : Real;
			return : AccelerationValue = -(u * grad_u);
		}

		calc def DiffusiveAccel {
			comment /* Diffusive acceleration term: nu * laplacian(u). */
			in nu : Real;
			in lap_u : Real;
			return : AccelerationValue = nu * lap_u;
		}

		calc def PressureGradAccel {
			comment /* Pressure gradient acceleration: -(1/rho) * dp/dx. */
			in grad_p : Real;
			in rho : Real;
			return : AccelerationValue = -(grad_p / rho);
		}

		calc def Divergence {
			comment /* Divergence of velocity: du/dx + dv/dy + dw/dz. */
			in du_dx : Real;
			in dv_dy : Real;
			in dw_dz : Real;
			return : Real = du_dx + dv_dy + dw_dz;
		}

		calc def UpdateVelocity {
			comment /* Forward Euler integration: u_new = u_old + a * dt. */
			in u_old : SpeedValue;
			in accel : AccelerationValue;
			in dt : TimeValue;
			return : SpeedValue = u_old + accel * dt;
		}

		calc def PressureUpdate {
			comment /* Pressure correction: p_new = p_old - rho * div^2 / dt. */
			in p_old : PressureValue;
			in rho : Real;
			in div : Real;
			in dt : TimeValue;
			return : PressureValue = p_old - rho * div * div / dt;
		}

		action def ConvectionStep {
			comment /* Calculates convective acceleration for a fluid cell. */
			in cell : FluidCell;
			in dt : TimeValue;
			out convAccU : AccelerationValue;
			out convAccV : AccelerationValue;
			out convAccW : AccelerationValue;
		}

		action def DiffusionStep {
			comment /* Calculates viscous diffusion acceleration for a fluid cell. */
			in cell : FluidCell;
			in fluid : Fluid;
			in dt : TimeValue;
			out diffAccU : AccelerationValue;
			out diffAccV : AccelerationValue;
			out diffAccW : AccelerationValue;
		}

		action def PressureCorrection {
			comment /* Solves pressure Poisson equation for divergence-free velocity. */
			in cell : FluidCell;
			in fluid : Fluid;
			in dt : TimeValue;
			out correctedP : PressureValue;
		}

		action def ContinuityEnforcement {
			comment /* Enforces mass conservation by checking divergence. */
			in cell : FluidCell;
			in dt : TimeValue;
			out divergence : Real;
			out isDivergenceFree : Boolean;
		}

		action def NavierStokesStep {
			comment /* One complete time step: convection, diffusion, body forces, pressure correction, continuity. */
			in domain : ComputationalDomain;
			in fluid : Fluid;
			in dt : TimeValue;
			in bodyForceU : AccelerationValue;
			in bodyForceV : AccelerationValue;
			in bodyForceW : AccelerationValue;
			in boundaries : BoundaryCondition[*];
			out updatedCells : FluidCell[*];
		}
	}

	package 'Simulation Controller' {
		private import 'Solver Modules'::*;
		private import 'Spatial Discretization'::*;
		private import 'Fluid Model'::*;
		private import 'Boundary Conditions'::*;

		action def RunSimulation {
			comment /* Executes the full unsteady simulation by iterating NavierStokesStep. */
			in domain : ComputationalDomain;
			in fluid : Fluid;
			in dt : TimeValue;
			in numSteps : Natural;
			in bodyForceU : AccelerationValue;
			in bodyForceV : AccelerationValue;
			in bodyForceW : AccelerationValue;
			in boundaries : BoundaryCondition[*];
			out finalState : FluidCell[*];

			for step in 1..numSteps {
				perform action solver : NavierStokesStep {
					in domain = domain;
					in fluid = fluid;
					in dt = dt;
					in bodyForceU = bodyForceU;
					in bodyForceV = bodyForceV;
					in bodyForceW = bodyForceW;
					in boundaries = boundaries;
					out updatedCells;
				}
				then assign finalState := solver.updatedCells;
			}
		}

		analysis def FluidFlowAnalysis {
			comment /* Analysis of fluid flow by iterating the Navier-Stokes solver over time. */
			subject domain : ComputationalDomain;
			in fluid : Fluid;
			in attribute timeStep :> ISQ::time;
			in attribute stepCount : Natural;
			in attribute bodyForceU :> ISQ::acceleration;
			in attribute bodyForceV :> ISQ::acceleration;
			in attribute bodyForceW :> ISQ::acceleration;
			in boundaries : BoundaryCondition[*];
			return attribute finalState : FluidCell[*] := ();

			for step in 1..stepCount {
				perform action solver : NavierStokesStep {
					in domain = domain;
					in fluid = fluid;
					in dt = timeStep;
					in bodyForceU = bodyForceU;
					in bodyForceV = bodyForceV;
					in bodyForceW = bodyForceW;
					in boundaries = boundaries;
					out updatedCells;
				}
				then assign finalState := solver.updatedCells;
			}
		}

		state machine def SimulationLifecycle {
			comment /* Manages the operational lifecycle: initializing, computing, completing. */

			state initializing;
			state computing;
			state completing;

			transition from initializing to computing;
			transition from computing to completing;
		}
	}

	package 'Requirements' {
		requirement def SimulateFluidMotion {
			doc /* The system shall simulate the motion of incompressible viscous fluids by numerically solving the Navier-Stokes equations. */
		}

		requirement def PredictVelocityAndPressure {
			doc /* The system shall predict the fluid velocity and pressure over time within a defined three-dimensional space. */
		}

		requirement def EnforceMassConservation {
			doc /* The system shall enforce mass conservation through pressure correction and continuity enforcement. */
		}

		requirement def HandleBoundaryConditions {
			doc /* The system shall support inlet velocity, outlet pressure, and solid wall boundary conditions. */
		}

		requirement def ManageLifecycle {
			doc /* The system shall manage its operational lifecycle through initializing, computing, and completing states. */
		}
	}

	package 'System Assembly' {
		private import 'Fluid Model'::*;
		private import 'Spatial Discretization'::*;
		private import 'Solver Modules'::*;
		private import 'Boundary Conditions'::*;
		private import 'Simulation Controller'::*;
		private import 'Port Definitions'::*;

		part def NavierStokesSolverSystem {
			comment /* Complete CFD solver system integrating domain, fluid, solver modules, and lifecycle. */

			port systemInflow : FlowPort;
			port systemOutflow : FlowPort;

			part domain : ComputationalDomain;
			part fluid : Fluid;
			part boundaries : BoundaryCondition[*];

			action convection : ConvectionStep;
			action diffusion : DiffusionStep;
			action pressureCorrector : PressureCorrection;
			action continuityEnforcer : ContinuityEnforcement;

			attribute dt :> ISQ::time;
			attribute numSteps : Natural;
			attribute bodyForceU :> ISQ::acceleration;
			attribute bodyForceV :> ISQ::acceleration;
			attribute bodyForceW :> ISQ::acceleration;

			connect systemInflow to domain.inflow;
			connect domain.outflow to systemOutflow;

			action runSim : RunSimulation {
				in domain = domain;
				in fluid = fluid;
				in dt = dt;
				in numSteps = numSteps;
				in bodyForceU = bodyForceU;
				in bodyForceV = bodyForceV;
				in bodyForceW = bodyForceW;
				in boundaries = boundaries;
				out finalState;
			}

			state lifecycle : SimulationLifecycle;
		}
	}
}
