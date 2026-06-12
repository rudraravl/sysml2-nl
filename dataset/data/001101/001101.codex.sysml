package InertialReferenceUnitModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Angle :> Real { unit = "rad"; }
  attribute def AngularRate :> Real { unit = "rad/s"; }
  attribute def LinearAcceleration :> Real { unit = "m/s^2"; }
  attribute def Temperature :> Real { unit = "K"; }
  attribute def Voltage :> Real { unit = "V"; }
  attribute def Power :> Real { unit = "W"; }
  attribute def TimeDuration :> Real { unit = "s"; }
  attribute def DataRate :> Real { unit = "Hz"; }
  attribute def Probability :> Real;
  attribute def Distance :> Real { unit = "m"; }

  item def ThreeAxisAngularRate {
    attribute rollRate : AngularRate;
    attribute pitchRate : AngularRate;
    attribute yawRate : AngularRate;
  }

  item def ThreeAxisAcceleration {
    attribute longitudinalAcceleration : LinearAcceleration;
    attribute lateralAcceleration : LinearAcceleration;
    attribute verticalAcceleration : LinearAcceleration;
  }

  item def AttitudeEstimate {
    attribute roll : Angle;
    attribute pitch : Angle;
    attribute yaw : Angle;
    attribute attitudeValidity : Boolean;
  }

  item def NavigationState {
    attribute roll : Angle;
    attribute pitch : Angle;
    attribute heading : Angle;
    attribute velocityNorth : Real { unit = "m/s"; }
    attribute velocityEast : Real { unit = "m/s"; }
    attribute velocityDown : Real { unit = "m/s"; }
    attribute positionLatitude : Angle;
    attribute positionLongitude : Angle;
    attribute altitude : Distance;
    attribute navigationValidity : Boolean;
  }

  item def TimeReference {
    attribute timeSincePowerOn : TimeDuration;
    attribute synchronizationValid : Boolean;
  }

  item def BuiltInTestStatus {
    attribute sensorHealthValid : Boolean;
    attribute processorHealthValid : Boolean;
    attribute powerHealthValid : Boolean;
    attribute thermalHealthValid : Boolean;
    attribute faultCode : Integer;
  }

  item def PowerInput {
    attribute supplyVoltage : Voltage;
    attribute availablePower : Power;
  }

  item def AlignmentCommand {
    attribute beginAlignment : Boolean;
    attribute latitude : Angle;
    attribute longitude : Angle;
    attribute initialHeading : Angle;
  }

  item def MaintenanceCommand {
    attribute runExtendedTest : Boolean;
    attribute resetFaults : Boolean;
  }

  port def PowerPort {
    in item power : PowerInput;
  }

  port def CommandPort {
    in item alignmentCommand : AlignmentCommand;
    in item maintenanceCommand : MaintenanceCommand;
  }

  port def NavigationOutputPort {
    out item navigationState : NavigationState;
    out item attitudeEstimate : AttitudeEstimate;
    out item bitStatus : BuiltInTestStatus;
  }

  port def SensorDataPort {
    out item angularRate : ThreeAxisAngularRate;
    out item acceleration : ThreeAxisAcceleration;
    out item sensorTemperature : Temperature;
  }

  port def ProcessorSensorInputPort {
    in item angularRate : ThreeAxisAngularRate;
    in item acceleration : ThreeAxisAcceleration;
    in item sensorTemperature : Temperature;
  }

  part def TriadGyroscopeAssembly {
    attribute measurementRange : AngularRate = 8.73;
    attribute biasStability : AngularRate = 0.00000485;
    attribute outputRate : DataRate = 400.0;
    attribute operatingTemperature : Temperature;

    port sensorOut : SensorDataPort;

    action senseAngularRates {
      in item trueBodyRates : ThreeAxisAngularRate;
      out item measuredBodyRates : ThreeAxisAngularRate;
    }
  }

  part def TriadAccelerometerAssembly {
    attribute measurementRange : LinearAcceleration = 196.2;
    attribute biasStability : LinearAcceleration = 0.000981;
    attribute outputRate : DataRate = 400.0;
    attribute operatingTemperature : Temperature;

    port sensorOut : SensorDataPort;

    action senseSpecificForce {
      in item trueSpecificForce : ThreeAxisAcceleration;
      out item measuredSpecificForce : ThreeAxisAcceleration;
    }
  }

  part def SensorThermalController {
    attribute targetTemperature : Temperature = 318.15;
    attribute allowableTemperatureError : Temperature = 1.0;
    attribute heaterPowerLimit : Power = 18.0;

    action regulateSensorTemperature {
      in item measuredTemperature : Temperature;
      out item heaterPowerCommand : Power;
    }
  }

  part def PowerConditioningUnit {
    attribute nominalInputVoltage : Voltage = 28.0;
    attribute minimumInputVoltage : Voltage = 18.0;
    attribute maximumInputVoltage : Voltage = 32.0;
    attribute regulatedLogicVoltage : Voltage = 5.0;
    attribute regulatedSensorVoltage : Voltage = 12.0;
    attribute maximumPowerConsumption : Power = 45.0;

    port externalPower : PowerPort;

    action conditionPower {
      in item aircraftPower : PowerInput;
      out item logicPowerValid : Boolean;
      out item sensorPowerValid : Boolean;
    }
  }

  part def InertialNavigationProcessor {
    attribute updateRate : DataRate = 100.0;
    attribute alignmentTimeLimit : TimeDuration = 300.0;
    attribute attitudeAccuracy : Angle = 0.000873;
    attribute headingAccuracy : Angle = 0.001745;
    attribute navigationDriftLimit : Real { unit = "m/h"; } = 1852.0;

    port sensorInput : ProcessorSensorInputPort;
    port commandInput : CommandPort;
    port navigationOutput : NavigationOutputPort;

    action alignReferenceFrame {
      in item command : AlignmentCommand;
      in item measuredRates : ThreeAxisAngularRate;
      in item measuredAcceleration : ThreeAxisAcceleration;
      out item initialAttitude : AttitudeEstimate;
      out item alignmentSuccessful : Boolean;
    }

    action computeNavigationSolution {
      in item angularRate : ThreeAxisAngularRate;
      in item acceleration : ThreeAxisAcceleration;
      in item timeReference : TimeReference;
      out item navigationState : NavigationState;
    }

    action compensateSensorErrors {
      in item rawAngularRate : ThreeAxisAngularRate;
      in item rawAcceleration : ThreeAxisAcceleration;
      in item sensorTemperature : Temperature;
      out item correctedAngularRate : ThreeAxisAngularRate;
      out item correctedAcceleration : ThreeAxisAcceleration;
    }

    action performBuiltInTest {
      out item status : BuiltInTestStatus;
    }

    state def ProcessorOperatingState {
      entry; then Initializing;

      state Initializing;
      state Aligning;
      state Navigating;
      state DegradedNavigation;
      state Faulted;
      state MaintenanceTest;

      transition Initializing_to_Aligning
        first Initializing
        accept AlignmentCommand
        then Aligning;

      transition Aligning_to_Navigating
        first Aligning
        if alignmentSuccessful
        then Navigating;

      transition Aligning_to_Faulted
        first Aligning
        if alignmentTimeExceeded
        then Faulted;

      transition Navigating_to_DegradedNavigation
        first Navigating
        if sensorHealthValid == false
        then DegradedNavigation;

      transition DegradedNavigation_to_Navigating
        first DegradedNavigation
        if sensorHealthValid == true
        then Navigating;

      transition Navigating_to_Faulted
        first Navigating
        if processorHealthValid == false
        then Faulted;

      transition Faulted_to_Initializing
        first Faulted
        accept MaintenanceCommand
        if resetFaults
        then Initializing;

      transition Initializing_to_MaintenanceTest
        first Initializing
        accept MaintenanceCommand
        if runExtendedTest
        then MaintenanceTest;

      transition MaintenanceTest_to_Initializing
        first MaintenanceTest
        if extendedTestComplete
        then Initializing;
    }
  }

  part def OutputInterfaceUnit {
    attribute messageRate : DataRate = 50.0;
    attribute maximumLatency : TimeDuration = 0.02;

    port navigationOut : NavigationOutputPort;

    action formatNavigationMessages {
      in item navigationState : NavigationState;
      in item attitudeEstimate : AttitudeEstimate;
      in item bitStatus : BuiltInTestStatus;
      out item transmittedNavigationState : NavigationState;
      out item transmittedAttitude : AttitudeEstimate;
      out item transmittedStatus : BuiltInTestStatus;
    }
  }

  part def InertialReferenceUnit {
    attribute mass : Real { unit = "kg"; } = 7.5;
    attribute requiredWarmupTime : TimeDuration = 180.0;
    attribute navigationOutputRate : DataRate = 50.0;
    attribute primaryFunctionDescription : String =
      "Measure three-axis angular rate and specific force, maintain an inertial reference frame, and compute continuous attitude, heading, velocity, and position estimates for the host vehicle without dependence on external navigation signals.";

    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port navigationOut : NavigationOutputPort;

    part powerConditioner : PowerConditioningUnit;
    part gyroscopeAssembly : TriadGyroscopeAssembly;
    part accelerometerAssembly : TriadAccelerometerAssembly;
    part thermalController : SensorThermalController;
    part navigationProcessor : InertialNavigationProcessor;
    part outputInterface : OutputInterfaceUnit;

    connect powerIn to powerConditioner.externalPower;
    connect commandIn to navigationProcessor.commandInput;
    connect gyroscopeAssembly.sensorOut to navigationProcessor.sensorInput;
    connect accelerometerAssembly.sensorOut to navigationProcessor.sensorInput;
    connect navigationProcessor.navigationOutput to outputInterface.navigationOut;
    connect outputInterface.navigationOut to navigationOut;

    action provideInertialReference {
      in item power : PowerInput;
      in item alignmentCommand : AlignmentCommand;
      in item maintenanceCommand : MaintenanceCommand;
      out item navigationState : NavigationState;
      out item attitudeEstimate : AttitudeEstimate;
      out item bitStatus : BuiltInTestStatus;

      first startPowerConditioning;
      then warmSensors;
      then executeAlignment;
      then generateNavigationSolution;
      then publishOutputs;

      action startPowerConditioning {
        in item power : PowerInput;
        out item powerValid : Boolean;
      }

      action warmSensors {
        out item thermalStable : Boolean;
      }

      action executeAlignment {
        in item alignmentCommand : AlignmentCommand;
        out item alignmentValid : Boolean;
      }

      action generateNavigationSolution {
        out item navigationState : NavigationState;
        out item attitudeEstimate : AttitudeEstimate;
      }

      action publishOutputs {
        in item navigationState : NavigationState;
        in item attitudeEstimate : AttitudeEstimate;
        in item bitStatus : BuiltInTestStatus;
      }
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /* The inertial reference unit shall provide an autonomous inertial reference by sensing three-axis angular rate and three-axis specific force and computing attitude, heading, velocity, and position for the host vehicle. */

    subject iru : InertialReferenceUnit;

    require constraint {
      iru.navigationOutputRate >= 50.0
    }
  }

  requirement def AlignmentRequirement {
    doc
      /* The inertial reference unit shall complete initial alignment within 300 seconds after receiving a valid alignment command and stable power. */

    subject processor : InertialNavigationProcessor;

    require constraint {
      processor.alignmentTimeLimit <= 300.0
    }
  }

  requirement def OutputLatencyRequirement {
    doc
      /* The inertial reference unit shall publish valid navigation and attitude outputs with latency no greater than 20 milliseconds during normal navigation. */

    subject outputInterface : OutputInterfaceUnit;

    require constraint {
      outputInterface.maximumLatency <= 0.02
    }
  }

  requirement def PowerCompatibilityRequirement {
    doc
      /* The inertial reference unit shall operate from a 28 volt direct-current aircraft power bus over the range from 18 volts to 32 volts. */

    subject powerConditioner : PowerConditioningUnit;

    require constraint {
      powerConditioner.minimumInputVoltage <= 18.0 and
      powerConditioner.maximumInputVoltage >= 32.0 and
      powerConditioner.nominalInputVoltage == 28.0
    }
  }

  requirement def SensorAccuracyRequirement {
    doc
      /* The inertial reference unit sensors shall support attitude and heading estimation with sufficient angular-rate and acceleration bias stability for aircraft navigation. */

    subject gyro : TriadGyroscopeAssembly;
    subject accel : TriadAccelerometerAssembly;

    require constraint {
      gyro.biasStability <= 0.00000485 and
      accel.biasStability <= 0.000981
    }
  }

  requirement def BuiltInTestRequirement {
    doc
      /* The inertial reference unit shall continuously monitor sensor, processor, power, and thermal health and report a built-in-test status with each navigation output message. */

    subject iru : InertialReferenceUnit;
  }

  requirement def ThermalControlRequirement {
    doc
      /* The inertial reference unit shall regulate inertial sensor temperature to maintain stable sensor calibration during operation. */

    subject controller : SensorThermalController;

    require constraint {
      controller.allowableTemperatureError <= 1.0 and
      controller.heaterPowerLimit <= 18.0
    }
  }

  satisfy PrimaryFunctionRequirement by InertialReferenceUnit::provideInertialReference;
  satisfy AlignmentRequirement by InertialNavigationProcessor::alignReferenceFrame;
  satisfy OutputLatencyRequirement by OutputInterfaceUnit::formatNavigationMessages;
  satisfy PowerCompatibilityRequirement by PowerConditioningUnit::conditionPower;
  satisfy SensorAccuracyRequirement by InertialNavigationProcessor::compensateSensorErrors;
  satisfy BuiltInTestRequirement by InertialNavigationProcessor::performBuiltInTest;
  satisfy ThermalControlRequirement by SensorThermalController::regulateSensorTemperature;

  part aircraftInertialReferenceUnit : InertialReferenceUnit;

}