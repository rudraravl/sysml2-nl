package NavierStokesBasedFlowSystem {
  import ScalarValues::*;
  import SI::*;

  value def Length :> Real {
    unit = "m";
  }

  value def Area :> Real {
    unit = "m^2";
  }

  value def Volume :> Real {
    unit = "m^3";
  }

  value def Time :> Real {
    unit = "s";
  }

  value def Mass :> Real {
    unit = "kg";
  }

  value def Density :> Real {
    unit = "kg/m^3";
  }

  value def DynamicViscosity :> Real {
    unit = "Pa*s";
  }

  value def KinematicViscosity :> Real {
    unit = "m^2/s";
  }

  value def Pressure :> Real {
    unit = "Pa";
  }

  value def Temperature :> Real {
    unit = "K";
  }

  value def Velocity :> Real {
    unit = "m/s";
  }

  value def Acceleration :> Real {
    unit = "m/s^2";
  }

  value def Force :> Real {
    unit = "N";
  }

  value def MassFlowRate :> Real {
    unit = "kg/s";
  }

  value def VolumetricFlowRate :> Real {
    unit = "m^3/s";
  }

  value def Frequency :> Real {
    unit = "Hz";
  }

  value def Dimensionless :> Real {
    unit = "1";
  }

  value def GridIndex :> Integer {
    unit = "1";
  }

  item def Vector3 {
    attribute x : Real;
    attribute y : Real;
    attribute z : Real;
  }

  item def PositionVector :> Vector3 {
    attribute x : Length;
    attribute y : Length;
    attribute z : Length;
  }

  item def VelocityVector :> Vector3 {
    attribute x : Velocity;
    attribute y : Velocity;
    attribute z : Velocity;
  }

  item def AccelerationVector :> Vector3 {
    attribute x : Acceleration;
    attribute y : Acceleration;
    attribute z : Acceleration;
  }

  item def ForceVector :> Vector3 {
    attribute x : Force;
    attribute y : Force;
    attribute z : Force;
  }

  item def FluidProperties {
    attribute density : Density;
    attribute dynamicViscosity : DynamicViscosity;
    attribute kinematicViscosity : KinematicViscosity;
    attribute referenceTemperature : Temperature;
    attribute incompressible : Boolean;
  }

  item def FlowState {
    attribute position : PositionVector;
    attribute velocity : VelocityVector;
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    attribute density : Density;
    attribute time : Time;
  }

  item def BoundaryCondition {
    attribute boundaryName : String;
    attribute prescribedVelocity : VelocityVector;
    attribute prescribedPressure : Pressure;
    attribute noSlip : Boolean;
    attribute openBoundary : Boolean;
    attribute wallBoundary : Boolean;
  }

  item def MeshCell {
    attribute cellId : GridIndex;
    attribute centroid : PositionVector;
    attribute volume : Volume;
    attribute faceAreaSum : Area;
    attribute localVelocity : VelocityVector;
    attribute localPressure : Pressure;
  }

  item def MeshTopology {
    attribute cellCount : Integer;
    attribute faceCount : Integer;
    attribute minimumCellLength : Length;
    attribute maximumCellLength : Length;
    attribute characteristicLength : Length;
  }

  item def SolverConfiguration {
    attribute timeStep : Time;
    attribute maximumIterations : Integer;
    attribute residualTolerance : Dimensionless;
    attribute courantLimit : Dimensionless;
    attribute pressureVelocityCoupling : String;
    attribute turbulenceEnabled : Boolean;
  }

  item def ResidualReport {
    attribute continuityResidual : Dimensionless;
    attribute momentumResidualX : Dimensionless;
    attribute momentumResidualY : Dimensionless;
    attribute momentumResidualZ : Dimensionless;
    attribute converged : Boolean;
    attribute iterationCount : Integer;
    attribute simulationTime : Time;
  }

  item def FlowPrediction {
    attribute averageOutletVelocity : Velocity;
    attribute averageOutletPressure : Pressure;
    attribute pressureDrop : Pressure;
    attribute massFlowRate : MassFlowRate;
    attribute volumetricFlowRate : VolumetricFlowRate;
    attribute reynoldsNumber : Dimensionless;
    attribute valid : Boolean;
  }

  port def FluidInletPort {
    in item inletState : FlowState;
    in item inletBoundary : BoundaryCondition;
    out item acceptedMassFlow : MassFlowRate;
  }

  port def FluidOutletPort {
    out item outletState : FlowState;
    out item prediction : FlowPrediction;
    in item outletBoundary : BoundaryCondition;
  }

  port def ConfigurationPort {
    in item fluidProperties : FluidProperties;
    in item meshTopology : MeshTopology;
    in item solverConfiguration : SolverConfiguration;
  }

  port def SolverStatusPort {
    out item residualReport : ResidualReport;
    out item currentPrediction : FlowPrediction;
  }

  port def FieldExchangePort {
    inout item flowState : FlowState;
    inout item meshCell : MeshCell;
  }

  constraint def IncompressibleContinuityEquation {
    in velocityDivergence : Frequency;
    require constraint { velocityDivergence == 0.0; }
  }

  constraint def IncompressibleMomentumEquation {
    in density : Density;
    in materialAcceleration : AccelerationVector;
    in pressureGradient : ForceVector;
    in viscousDiffusion : AccelerationVector;
    in bodyForce : ForceVector;

    require constraint {
      density > 0.0;
    }
  }

  constraint def CourantStabilityLimit {
    in localVelocityMagnitude : Velocity;
    in timeStep : Time;
    in cellLength : Length;
    in courantLimit : Dimensionless;
    in courantNumber : Dimensionless;

    require constraint {
      courantNumber == localVelocityMagnitude * timeStep / cellLength;
      courantNumber <= courantLimit;
    }
  }

  constraint def ReynoldsNumberDefinition {
    in density : Density;
    in characteristicVelocity : Velocity;
    in characteristicLength : Length;
    in dynamicViscosity : DynamicViscosity;
    in reynoldsNumber : Dimensionless;

    require constraint {
      reynoldsNumber == density * characteristicVelocity * characteristicLength / dynamicViscosity;
    }
  }

  action def ValidateInputs {
    in item properties : FluidProperties;
    in item mesh : MeshTopology;
    in item solver : SolverConfiguration;
    out valid : Boolean;

    require constraint {
      properties.density > 0.0;
      properties.dynamicViscosity > 0.0;
      mesh.cellCount > 0;
      mesh.minimumCellLength > 0.0;
      solver.timeStep > 0.0;
      solver.maximumIterations > 0;
      solver.residualTolerance > 0.0;
    }
  }

  action def InitializeFlowField {
    in item inlet : FlowState;
    in item properties : FluidProperties;
    in item mesh : MeshTopology;
    out item initializedState : FlowState;
  }

  action def ApplyBoundaryConditions {
    in item inletCondition : BoundaryCondition;
    in item outletCondition : BoundaryCondition;
    inout item state : FlowState;
  }

  action def SolvePressureVelocityCoupling {
    in item configuration : SolverConfiguration;
    inout item state : FlowState;
    out item residual : ResidualReport;
  }

  action def EnforceMassConservation {
    inout item state : FlowState;
    out continuityResidual : Dimensionless;
  }

  action def AdvanceMomentumField {
    in item properties : FluidProperties;
    in item configuration : SolverConfiguration;
    inout item state : FlowState;
    out momentumResidual : Dimensionless;
  }

  action def ComputeDerivedFlowMetrics {
    in item state : FlowState;
    in item properties : FluidProperties;
    in item mesh : MeshTopology;
    out item prediction : FlowPrediction;
  }

  action def PublishFlowPrediction {
    in item residual : ResidualReport;
    in item prediction : FlowPrediction;
    out item publishedPrediction : FlowPrediction;
  }

  state def FlowSolverLifecycle {
    state idle;
    state inputValidation;
    state fieldInitialization;
    state boundaryApplication;
    state iterativeSolve;
    state convergenceCheck;
    state publishing;
    state failed;

    transition first idle;
    transition idle_to_inputValidation
      first idle
      then inputValidation;

    transition validation_to_initialization
      first inputValidation
      then fieldInitialization;

    transition validation_to_failed
      first inputValidation
      then failed;

    transition initialization_to_boundaryApplication
      first fieldInitialization
      then boundaryApplication;

    transition boundaryApplication_to_iterativeSolve
      first boundaryApplication
      then iterativeSolve;

    transition iterativeSolve_to_convergenceCheck
      first iterativeSolve
      then convergenceCheck;

    transition convergenceCheck_to_iterativeSolve
      first convergenceCheck
      then iterativeSolve;

    transition convergenceCheck_to_publishing
      first convergenceCheck
      then publishing;

    transition convergenceCheck_to_failed
      first convergenceCheck
      then failed;

    transition publishing_to_idle
      first publishing
      then idle;
  }

  part def FlowDomain {
    attribute length : Length;
    attribute width : Length;
    attribute height : Length;
    attribute volume : Volume;
    attribute characteristicLength : Length;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port fieldAccess : FieldExchangePort;

    part mesh : MeshTopology;
    part representativeCell : MeshCell;

    constraint domainVolume {
      volume == length * width * height;
    }
  }

  part def FluidModel {
    attribute properties : FluidProperties;
    attribute gravity : AccelerationVector;
    attribute bodyForce : ForceVector;

    port configuration : ConfigurationPort;
    port fieldAccess : FieldExchangePort;
  }

  part def NavierStokesSolver {
    attribute configuration : SolverConfiguration;
    attribute residual : ResidualReport;
    attribute latestPrediction : FlowPrediction;
    attribute lifecycle : FlowSolverLifecycle;

    port configurationIn : ConfigurationPort;
    port fieldAccess : FieldExchangePort;
    port statusOut : SolverStatusPort;

    perform action validateInputs : ValidateInputs;
    perform action initializeFlowField : InitializeFlowField;
    perform action applyBoundaryConditions : ApplyBoundaryConditions;
    perform action advanceMomentumField : AdvanceMomentumField;
    perform action enforceMassConservation : EnforceMassConservation;
    perform action solvePressureVelocityCoupling : SolvePressureVelocityCoupling;
    perform action computeDerivedFlowMetrics : ComputeDerivedFlowMetrics;
    perform action publishFlowPrediction : PublishFlowPrediction;

    constraint courantConstraint : CourantStabilityLimit;
    constraint reynoldsConstraint : ReynoldsNumberDefinition;
    constraint continuityConstraint : IncompressibleContinuityEquation;
    constraint momentumConstraint : IncompressibleMomentumEquation;
  }

  part def BoundaryConditionManager {
    attribute inletCondition : BoundaryCondition;
    attribute outletCondition : BoundaryCondition;

    port inletBoundaryPort : FluidInletPort;
    port outletBoundaryPort : FluidOutletPort;
    port configurationPort : ConfigurationPort;
  }

  part def FlowPredictionPublisher {
    attribute updateRate : Frequency;
    attribute prediction : FlowPrediction;

    port statusIn : SolverStatusPort;
    port outletPort : FluidOutletPort;
  }

  part def NavierStokesFlowSystem {
    doc /* Primary function: predict the time-resolved velocity, pressure, and flow-rate behavior of an incompressible viscous fluid in a bounded domain by numerically enforcing the Navier-Stokes momentum equations and the continuity equation. */

    attribute nominalDensity : Density = 998.2;
    attribute nominalDynamicViscosity : DynamicViscosity = 0.001003;
    attribute nominalTimeStep : Time = 0.001;
    attribute nominalCourantLimit : Dimensionless = 0.5;

    port inlet : FluidInletPort;
    port outlet : FluidOutletPort;
    port configuration : ConfigurationPort;
    port status : SolverStatusPort;

    part domain : FlowDomain {
      attribute length = 2.0;
      attribute width = 0.25;
      attribute height = 0.25;
      attribute characteristicLength = 0.25;
    }

    part fluid : FluidModel {
      attribute properties.density = 998.2;
      attribute properties.dynamicViscosity = 0.001003;
      attribute properties.kinematicViscosity = 0.000001004;
      attribute properties.referenceTemperature = 293.15;
      attribute properties.incompressible = true;
    }

    part solver : NavierStokesSolver {
      attribute configuration.timeStep = 0.001;
      attribute configuration.maximumIterations = 500;
      attribute configuration.residualTolerance = 0.000001;
      attribute configuration.courantLimit = 0.5;
      attribute configuration.pressureVelocityCoupling = "PISO";
      attribute configuration.turbulenceEnabled = false;
    }

    part boundaryManager : BoundaryConditionManager {
      attribute inletCondition.boundaryName = "uniformVelocityInlet";
      attribute inletCondition.prescribedVelocity.x = 1.5;
      attribute inletCondition.prescribedVelocity.y = 0.0;
      attribute inletCondition.prescribedVelocity.z = 0.0;
      attribute inletCondition.prescribedPressure = 101325.0;
      attribute inletCondition.noSlip = false;
      attribute inletCondition.openBoundary = true;
      attribute inletCondition.wallBoundary = false;

      attribute outletCondition.boundaryName = "fixedPressureOutlet";
      attribute outletCondition.prescribedVelocity.x = 0.0;
      attribute outletCondition.prescribedVelocity.y = 0.0;
      attribute outletCondition.prescribedVelocity.z = 0.0;
      attribute outletCondition.prescribedPressure = 101325.0;
      attribute outletCondition.noSlip = false;
      attribute outletCondition.openBoundary = true;
      attribute outletCondition.wallBoundary = false;
    }

    part publisher : FlowPredictionPublisher {
      attribute updateRate = 50.0;
    }

    connection inlet_to_domain connect inlet to domain.inlet;
    connection domain_to_outlet connect domain.outlet to outlet;
    connection external_configuration_to_solver connect configuration to solver.configurationIn;
    connection external_configuration_to_fluid connect configuration to fluid.configuration;
    connection domain_field_to_solver connect domain.fieldAccess to solver.fieldAccess;
    connection fluid_field_to_solver connect fluid.fieldAccess to solver.fieldAccess;
    connection solver_status_to_system_status connect solver.statusOut to status;
    connection solver_status_to_publisher connect solver.statusOut to publisher.statusIn;
    connection publisher_to_outlet connect publisher.outletPort to outlet;
    connection boundary_inlet_to_domain connect boundaryManager.inletBoundaryPort to domain.inlet;
    connection boundary_outlet_to_domain connect boundaryManager.outletBoundaryPort to domain.outlet;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : NavierStokesFlowSystem;

    require constraint {
      system.solver.configuration.timeStep > 0.0;
      system.solver.configuration.residualTolerance <= 0.000001;
    }

    doc /* The system shall compute pressure, velocity, mass-flow, and volume-flow predictions for a viscous incompressible fluid by solving discretized Navier-Stokes and continuity equations over the configured flow domain. */
  }

  requirement def ConservationOfMassRequirement {
    subject solver : NavierStokesSolver;

    require constraint {
      solver.residual.continuityResidual <= solver.configuration.residualTolerance;
    }

    doc /* The solver shall converge the continuity residual below the configured tolerance before publishing a valid flow prediction. */
  }

  requirement def MomentumBalanceRequirement {
    subject solver : NavierStokesSolver;

    require constraint {
      solver.residual.momentumResidualX <= solver.configuration.residualTolerance;
      solver.residual.momentumResidualY <= solver.configuration.residualTolerance;
      solver.residual.momentumResidualZ <= solver.configuration.residualTolerance;
    }

    doc /* The solver shall converge the three Cartesian momentum residuals below the configured tolerance. */
  }

  requirement def StabilityRequirement {
    subject system : NavierStokesFlowSystem;

    require constraint {
      system.solver.configuration.courantLimit <= 1.0;
      system.solver.configuration.courantLimit > 0.0;
    }

    doc /* The system shall maintain the numerical Courant number within the configured stability limit for explicit transport updates. */
  }

  requirement def OutputValidityRequirement {
    subject publisher : FlowPredictionPublisher;

    require constraint {
      publisher.prediction.valid == true;
      publisher.prediction.massFlowRate >= 0.0;
      publisher.prediction.volumetricFlowRate >= 0.0;
    }

    doc /* Published predictions shall be marked valid only after convergence and shall report nonnegative outlet flow rates. */
  }

  satisfy PrimaryFunctionRequirement by NavierStokesFlowSystem;
  satisfy ConservationOfMassRequirement by NavierStokesSolver;
  satisfy MomentumBalanceRequirement by NavierStokesSolver;
  satisfy StabilityRequirement by NavierStokesFlowSystem;
  satisfy OutputValidityRequirement by FlowPredictionPublisher;
}