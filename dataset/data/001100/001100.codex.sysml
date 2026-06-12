package InertialNavigationSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Angle :> ScalarValues::Real {
    unit = SI::radian;
  }

  attribute def AngularRate :> ScalarValues::Real {
    unit = SI::radian / SI::second;
  }

  attribute def Acceleration :> ScalarValues::Real {
    unit = SI::metre / SI::second^2;
  }

  attribute def Velocity :> ScalarValues::Real {
    unit = SI::metre / SI::second;
  }

  attribute def Distance :> ScalarValues::Real {
    unit = SI::metre;
  }

  attribute def Frequency :> ScalarValues::Real {
    unit = SI::hertz;
  }

  attribute def TimeDuration :> ScalarValues::Real {
    unit = SI::second;
  }

  attribute def ElectricPower :> ScalarValues::Real {
    unit = SI::watt;
  }

  attribute def Voltage :> ScalarValues::Real {
    unit = SI::volt;
  }

  attribute def Temperature :> ScalarValues::Real {
    unit = SI::degreeCelsius;
  }

  attribute def Probability :> ScalarValues::Real {
    unit = one;
  }

  item def ThreeAxisAcceleration {
    attribute ax : Acceleration;
    attribute ay : Acceleration;
    attribute az : Acceleration;
  }

  item def ThreeAxisAngularRate {
    attribute wx : AngularRate;
    attribute wy : AngularRate;
    attribute wz : AngularRate;
  }

  item def AttitudeEstimate {
    attribute roll : Angle;
    attribute pitch : Angle;
    attribute yaw : Angle;
    attribute covarianceTrace : Real;
  }

  item def PositionEstimate {
    attribute north : Distance;
    attribute east : Distance;
    attribute down : Distance;
    attribute circularErrorProbable : Distance;
  }

  item def VelocityEstimate {
    attribute northRate : Velocity;
    attribute eastRate : Velocity;
    attribute downRate : Velocity;
  }

  item def NavigationSolution {
    attribute timeTag : TimeDuration;
    attribute position : PositionEstimate;
    attribute velocity : VelocityEstimate;
    attribute attitude : AttitudeEstimate;
    attribute solutionValid : Boolean;
    attribute integrityRisk : Probability;
  }

  item def ImuSample {
    attribute sampleTime : TimeDuration;
    attribute acceleration : ThreeAxisAcceleration;
    attribute angularRate : ThreeAxisAngularRate;
    attribute temperature : Temperature;
    attribute sampleValid : Boolean;
  }

  item def PowerInput {
    attribute voltage : Voltage;
    attribute availablePower : ElectricPower;
    attribute powerHealthy : Boolean;
  }

  item def AlignmentCommand {
    attribute startAlignment : Boolean;
    attribute initialHeading : Angle;
    attribute alignmentLatitude : Angle;
    attribute alignmentLongitude : Angle;
    attribute alignmentAltitude : Distance;
  }

  item def NavigationModeCommand {
    attribute enableNavigation : Boolean;
    attribute resetFaults : Boolean;
    attribute requestBuiltInTest : Boolean;
  }

  item def HealthReport {
    attribute imuHealthy : Boolean;
    attribute processorHealthy : Boolean;
    attribute powerHealthy : Boolean;
    attribute navigationHealthy : Boolean;
    attribute faultCode : Integer;
  }

  port def PowerPort {
    in item power : PowerInput;
  }

  port def CommandPort {
    in item alignCommand : AlignmentCommand;
    in item modeCommand : NavigationModeCommand;
  }

  port def NavigationOutputPort {
    out item solution : NavigationSolution;
    out item health : HealthReport;
  }

  port def ImuDataPort {
    out item sample : ImuSample;
  }

  port def InternalImuInputPort {
    in item sample : ImuSample;
  }

  port def InternalSolutionPort {
    out item solution : NavigationSolution;
  }

  part def InertialMeasurementUnit {
    attribute sampleRate : Frequency = 1000 [SI::hertz];
    attribute gyroBiasStability : AngularRate = 0.00001 [SI::radian / SI::second];
    attribute accelerometerBiasStability : Acceleration = 0.0001 [SI::metre / SI::second^2];
    attribute operatingTemperature : Temperature;

    port powerIn : PowerPort;
    port imuOut : ImuDataPort;

    part triadAccelerometers {
      attribute xAxisRange : Acceleration = 196.2 [SI::metre / SI::second^2];
      attribute yAxisRange : Acceleration = 196.2 [SI::metre / SI::second^2];
      attribute zAxisRange : Acceleration = 196.2 [SI::metre / SI::second^2];
    }

    part triadGyroscopes {
      attribute xAxisRange : AngularRate = 8.73 [SI::radian / SI::second];
      attribute yAxisRange : AngularRate = 8.73 [SI::radian / SI::second];
      attribute zAxisRange : AngularRate = 8.73 [SI::radian / SI::second];
    }

    action generateImuSample {
      in item suppliedPower : PowerInput;
      out item sample : ImuSample;

      first start;
      then senseLinearAcceleration;
      then senseAngularRate;
      then compensateTemperatureBias;
      then validateSample;
      then publishSample;
    }
  }

  part def NavigationComputer {
    attribute updateRate : Frequency = 200 [SI::hertz];
    attribute alignmentTimeLimit : TimeDuration = 180 [SI::second];
    attribute maximumCoastTime : TimeDuration = 7200 [SI::second];

    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port imuIn : InternalImuInputPort;
    port solutionOut : InternalSolutionPort;

    part strapdownMechanization {
      attribute earthRotationCompensationEnabled : Boolean = true;
      attribute gravityModelEnabled : Boolean = true;
    }

    part kalmanEstimator {
      attribute estimatedGyroBiasX : AngularRate;
      attribute estimatedGyroBiasY : AngularRate;
      attribute estimatedGyroBiasZ : AngularRate;
      attribute estimatedAccelBiasX : Acceleration;
      attribute estimatedAccelBiasY : Acceleration;
      attribute estimatedAccelBiasZ : Acceleration;
    }

    part integrityMonitor {
      attribute maximumIntegrityRisk : Probability = 0.000001;
      attribute maximumAllowedCep : Distance = 1852 [SI::metre];
    }

    action align {
      in item command : AlignmentCommand;
      in item imuSample : ImuSample;
      out item initialSolution : NavigationSolution;

      first acceptAlignmentCommand;
      then estimateLevelAttitude;
      then estimateHeading;
      then initializePosition;
      then initializeVelocityToZero;
      then markSolutionValid;
    }

    action propagateNavigationSolution {
      in item previousSolution : NavigationSolution;
      in item imuSample : ImuSample;
      out item propagatedSolution : NavigationSolution;

      first removeEstimatedSensorBias;
      then integrateAngularRatesToAttitude;
      then transformSpecificForceToNavigationFrame;
      then subtractGravity;
      then integrateAccelerationToVelocity;
      then integrateVelocityToPosition;
      then estimateUncertaintyGrowth;
      then publishPropagatedSolution;
    }

    action performBuiltInTest {
      out item report : HealthReport;

      first checkProcessorMemory;
      then checkImuDataFreshness;
      then checkPowerInput;
      then checkEstimatorConsistency;
      then issueHealthReport;
    }

    state def NavigationComputerStateMachine {
      state off;
      state initialization;
      state alignment;
      state navigating;
      state degradedNavigation;
      state faulted;

      transition off_to_initialization
        first off
        accept PowerInput
        if powerHealthy
        then initialization;

      transition initialization_to_alignment
        first initialization
        accept AlignmentCommand
        if startAlignment
        then alignment;

      transition alignment_to_navigating
        first alignment
        if alignmentComplete
        then navigating;

      transition navigating_to_degraded
        first navigating
        if imuSampleInvalid or integrityRiskExceeded
        then degradedNavigation;

      transition degraded_to_navigating
        first degradedNavigation
        if imuSampleValid and integrityRiskAcceptable
        then navigating;

      transition any_to_faulted
        first initialization
        if processorFault or powerFault
        then faulted;

      transition faulted_to_initialization
        first faulted
        accept NavigationModeCommand
        if resetFaults
        then initialization;
    }
  }

  part def PowerConditioner {
    attribute nominalInputVoltage : Voltage = 28 [SI::volt];
    attribute maximumPowerConsumption : ElectricPower = 45 [SI::watt];

    port externalPower : PowerPort;
    port imuPower : PowerPort;
    port computerPower : PowerPort;

    action regulatePower {
      in item inputPower : PowerInput;
      out item conditionedPower : PowerInput;

      first filterInput;
      then regulateVoltage;
      then detectUndervoltage;
      then distributeConditionedPower;
    }
  }

  part def VehicleInterfaceUnit {
    port commandInput : CommandPort;
    port navigationOutput : NavigationOutputPort;
    port internalSolutionInput : InternalSolutionPort;

    action formatNavigationOutput {
      in item solution : NavigationSolution;
      in item health : HealthReport;
      out item publishedSolution : NavigationSolution;

      first validateOutputAge;
      then applyInterfaceScaleFactors;
      then attachHealthStatus;
      then transmitToVehicle;
    }
  }

  part def InertialNavigationSystem {
    attribute primaryFunction : String =
      "Estimate vehicle position, velocity, and attitude continuously from inertial sensor measurements without requiring external navigation references.";
    attribute nominalPositionDriftAfterOneHour : Distance = 1852 [SI::metre];
    attribute attitudeAccuracyRollPitch : Angle = 0.00175 [SI::radian];
    attribute attitudeAccuracyHeading : Angle = 0.00524 [SI::radian];
    attribute navigationUpdateRate : Frequency = 200 [SI::hertz];

    port aircraftPowerInput : PowerPort;
    port vehicleCommandInput : CommandPort;
    port navigationDataOutput : NavigationOutputPort;

    part powerConditioner : PowerConditioner;
    part imu : InertialMeasurementUnit;
    part navigationComputer : NavigationComputer;
    part vehicleInterface : VehicleInterfaceUnit;

    connect aircraftPowerInput.power to powerConditioner.externalPower.power;
    connect powerConditioner.imuPower.power to imu.powerIn.power;
    connect powerConditioner.computerPower.power to navigationComputer.powerIn.power;
    connect vehicleCommandInput.alignCommand to navigationComputer.commandIn.alignCommand;
    connect vehicleCommandInput.modeCommand to navigationComputer.commandIn.modeCommand;
    connect vehicleCommandInput.alignCommand to vehicleInterface.commandInput.alignCommand;
    connect vehicleCommandInput.modeCommand to vehicleInterface.commandInput.modeCommand;
    connect imu.imuOut.sample to navigationComputer.imuIn.sample;
    connect navigationComputer.solutionOut.solution to vehicleInterface.internalSolutionInput.solution;
    connect vehicleInterface.navigationOutput.solution to navigationDataOutput.solution;
    connect vehicleInterface.navigationOutput.health to navigationDataOutput.health;

    action provideInertialNavigation {
      in item externalPower : PowerInput;
      in item alignmentCommand : AlignmentCommand;
      in item modeCommand : NavigationModeCommand;
      out item navigationSolution : NavigationSolution;
      out item healthReport : HealthReport;

      first receiveElectricalPower;
      then conditionAndDistributePower;
      then initializeSensorsAndProcessor;
      then performSystemBuiltInTest;
      then alignToLocalNavigationFrame;
      then continuouslySampleInertialSensors;
      then computeAttitudeVelocityAndPosition;
      then monitorNavigationIntegrity;
      then publishNavigationSolution;
    }

    state def InertialNavigationOperationalStateMachine {
      state unpowered;
      state selfTest;
      state awaitingAlignment;
      state aligning;
      state operational;
      state degraded;
      state failed;

      transition power_applied
        first unpowered
        accept PowerInput
        if powerHealthy
        then selfTest;

      transition selftest_passed
        first selfTest
        if imuHealthy and processorHealthy and powerHealthy
        then awaitingAlignment;

      transition selftest_failed
        first selfTest
        if not imuHealthy or not processorHealthy or not powerHealthy
        then failed;

      transition alignment_requested
        first awaitingAlignment
        accept AlignmentCommand
        if startAlignment
        then aligning;

      transition alignment_complete
        first aligning
        if solutionValid
        then operational;

      transition navigation_degraded
        first operational
        if circularErrorProbable > nominalPositionDriftAfterOneHour or integrityRisk > 0.000001
        then degraded;

      transition recovery
        first degraded
        if circularErrorProbable <= nominalPositionDriftAfterOneHour and integrityRisk <= 0.000001
        then operational;

      transition unrecoverable_fault
        first operational
        if not imuHealthy or not processorHealthy
        then failed;

      transition commanded_reset
        first failed
        accept NavigationModeCommand
        if resetFaults
        then selfTest;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /* The inertial navigation system shall provide continuous estimates of vehicle position, velocity, and attitude using internally measured acceleration and angular rate. */
    subject ins : InertialNavigationSystem;

    require constraint {
      ins.navigationUpdateRate >= 100 [SI::hertz]
    }
  }

  requirement def SelfContainedNavigationRequirement {
    doc
      /* The inertial navigation system shall maintain a valid navigation solution for at least two hours without external position, velocity, or attitude aiding. */
    subject ins : InertialNavigationSystem;

    require constraint {
      ins.navigationComputer.maximumCoastTime >= 7200 [SI::second]
    }
  }

  requirement def PositionDriftRequirement {
    doc
      /* The inertial navigation system shall limit unaided horizontal position error growth to no more than one nautical mile after one hour of operation. */
    subject ins : InertialNavigationSystem;

    require constraint {
      ins.nominalPositionDriftAfterOneHour <= 1852 [SI::metre]
    }
  }

  requirement def AttitudeAccuracyRequirement {
    doc
      /* The inertial navigation system shall estimate roll and pitch attitude with an error not exceeding 0.1 degree during normal operation. */
    subject ins : InertialNavigationSystem;

    require constraint {
      ins.attitudeAccuracyRollPitch <= 0.00175 [SI::radian]
    }
  }

  requirement def HealthMonitoringRequirement {
    doc
      /* The inertial navigation system shall report sensor, processor, power, and navigation health status with every navigation output message. */
    subject report : HealthReport;

    require constraint {
      report.imuHealthy == true or report.processorHealthy == false or report.powerHealthy == false or report.navigationHealthy == false
    }
  }

  requirement def OutputValidityRequirement {
    doc
      /* The inertial navigation system shall mark the navigation solution invalid when inertial measurements are stale, failed, or inconsistent with estimator integrity limits. */
    subject solution : NavigationSolution;

    require constraint {
      solution.integrityRisk <= 0.000001 implies solution.solutionValid == true
    }
  }

  satisfy PrimaryFunctionRequirement by InertialNavigationSystem::provideInertialNavigation;
  satisfy SelfContainedNavigationRequirement by InertialNavigationSystem::navigationComputer;
  satisfy PositionDriftRequirement by InertialNavigationSystem;
  satisfy AttitudeAccuracyRequirement by InertialNavigationSystem;
  satisfy HealthMonitoringRequirement by InertialNavigationSystem::vehicleInterface;
  satisfy OutputValidityRequirement by InertialNavigationSystem::navigationComputer::integrityMonitor;

  verification case def VerifyPrimaryFunction {
    subject ins : InertialNavigationSystem;

    objective {
      verify PrimaryFunctionRequirement;
    }

    action simulateStraightAndTurningMotion {
      out item result : NavigationSolution;

      first initializeKnownPositionVelocityAndAttitude;
      then injectRepresentativeImuSamples;
      then runStrapdownMechanizationForOneHour;
      then compareEstimatedStateToTruth;
    }
  }

  verification case def VerifyUnaidedDrift {
    subject ins : InertialNavigationSystem;

    objective {
      verify PositionDriftRequirement;
    }

    action evaluateOneHourUnaidedNavigation {
      out attribute measuredDrift : Distance;

      first alignSystem;
      then removeExternalAiding;
      then propagateNavigationForOneHour;
      then computeHorizontalPositionError;
      then confirmDriftLimit;
    }
  }

}