package ViscometerSystemModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def DynamicViscosity {
    :> scalarValues::Real;
    unit = "Pa*s";
  }

  attribute def KinematicViscosity {
    :> scalarValues::Real;
    unit = "m^2/s";
  }

  attribute def Density {
    :> scalarValues::Real;
    unit = "kg/m^3";
  }

  attribute def Temperature {
    :> scalarValues::Real;
    unit = "degC";
  }

  attribute def Pressure {
    :> scalarValues::Real;
    unit = "Pa";
  }

  attribute def FlowRate {
    :> scalarValues::Real;
    unit = "mL/min";
  }

  attribute def Torque {
    :> scalarValues::Real;
    unit = "mN*m";
  }

  attribute def RotationalSpeed {
    :> scalarValues::Real;
    unit = "rpm";
  }

  attribute def Voltage {
    :> scalarValues::Real;
    unit = "V";
  }

  attribute def Current {
    :> scalarValues::Real;
    unit = "A";
  }

  attribute def TimeDuration {
    :> scalarValues::Real;
    unit = "s";
  }

  item def LiquidSample {
    attribute sampleId : String;
    attribute temperature : Temperature;
    attribute density : Density;
    attribute expectedViscosityRangeMin : DynamicViscosity;
    attribute expectedViscosityRangeMax : DynamicViscosity;
  }

  item def ConditionedSample :> LiquidSample {
    attribute isBubbleFree : Boolean;
    attribute isTemperatureStable : Boolean;
  }

  item def WasteLiquid {
    attribute volume : Real;
    attribute disposalClass : String;
  }

  item def MeasurementCommand {
    attribute targetTemperature : Temperature;
    attribute targetSpeed : RotationalSpeed;
    attribute stabilizationTime : TimeDuration;
    attribute replicateCount : Integer;
  }

  item def ViscosityResult {
    attribute sampleId : String;
    attribute dynamicViscosity : DynamicViscosity;
    attribute kinematicViscosity : KinematicViscosity;
    attribute measuredTemperature : Temperature;
    attribute measuredTorque : Torque;
    attribute measuredSpeed : RotationalSpeed;
    attribute timestamp : String;
    attribute qualityFlag : String;
  }

  item def DiagnosticStatus {
    attribute ready : Boolean;
    attribute faultCode : String;
    attribute message : String;
  }

  port def SampleInPort {
    in item sample : LiquidSample;
  }

  port def SampleOutPort {
    out item waste : WasteLiquid;
  }

  port def ConditionedSamplePort {
    out item conditionedSample : ConditionedSample;
  }

  port def CommandPort {
    in item command : MeasurementCommand;
  }

  port def ResultPort {
    out item result : ViscosityResult;
  }

  port def StatusPort {
    out item status : DiagnosticStatus;
  }

  port def PowerPort {
    in attribute voltage : Voltage;
    in attribute current : Current;
  }

  port def TorqueSignalPort {
    out attribute torque : Torque;
  }

  port def SpeedSignalPort {
    out attribute speed : RotationalSpeed;
  }

  port def TemperatureSignalPort {
    out attribute temperature : Temperature;
  }

  port def MotorDrivePort {
    out attribute commandedSpeed : RotationalSpeed;
    in attribute actualSpeed : RotationalSpeed;
  }

  part def SampleHandlingSubsystem {
    port sampleIn : SampleInPort;
    port conditionedSampleOut : ConditionedSamplePort;
    port wasteOut : SampleOutPort;

    attribute fillVolume : Real = 12.0;
    attribute fillVolumeUnit : String = "mL";
    attribute maximumParticleSize : Real = 250.0;
    attribute maximumParticleSizeUnit : String = "um";

    part inletValve;
    part sampleCell {
      attribute internalVolume : Real = 15.0;
      attribute internalVolumeUnit : String = "mL";
      attribute wettedMaterial : String = "316L stainless steel";
    }
    part drainValve;
    part bubbleTrap;

    action conditionSample {
      in item rawSample : LiquidSample;
      out item conditioned : ConditionedSample;
    }
  }

  part def ThermalControlSubsystem {
    port power : PowerPort;
    port temperatureOut : TemperatureSignalPort;

    attribute setpoint : Temperature;
    attribute stabilityBand : Temperature = 0.05;
    attribute operatingMinimum : Temperature = 15.0;
    attribute operatingMaximum : Temperature = 90.0;

    part heater;
    part peltierCooler;
    part temperatureSensor {
      attribute accuracy : Temperature = 0.03;
      attribute responseTime : TimeDuration = 1.0;
    }

    action regulateTemperature {
      in attribute targetTemperature : Temperature;
      out attribute stabilizedTemperature : Temperature;
    }
  }

  part def RotorDriveSubsystem {
    port power : PowerPort;
    port drive : MotorDrivePort;
    port speedOut : SpeedSignalPort;

    attribute minimumSpeed : RotationalSpeed = 0.1;
    attribute maximumSpeed : RotationalSpeed = 300.0;
    attribute speedAccuracy : RotationalSpeed = 0.05;

    part brushlessMotor;
    part spindle {
      attribute geometryFactor : Real = 1.327;
      attribute material : String = "titanium";
    }
    part encoder {
      attribute resolution : Real = 4096.0;
      attribute resolutionUnit : String = "counts/revolution";
    }

    action rotateSpindle {
      in attribute targetSpeed : RotationalSpeed;
      out attribute actualSpeed : RotationalSpeed;
    }
  }

  part def TorqueMeasurementSubsystem {
    port torqueOut : TorqueSignalPort;

    attribute torqueRangeMin : Torque = 0.001;
    attribute torqueRangeMax : Torque = 200.0;
    attribute torqueAccuracyPercentOfReading : Real = 0.5;

    part torsionElement;
    part strainGaugeBridge;
    part signalConditioner;

    action measureTorque {
      out attribute measuredTorque : Torque;
    }
  }

  part def ViscosityComputationSubsystem {
    port commandIn : CommandPort;
    port resultOut : ResultPort;
    port statusOut : StatusPort;

    attribute calibrationConstant : Real = 1.327;
    attribute lastDynamicViscosity : DynamicViscosity;
    attribute lastKinematicViscosity : KinematicViscosity;

    action computeViscosity {
      in item sample : ConditionedSample;
      in attribute torque : Torque;
      in attribute speed : RotationalSpeed;
      in attribute temperature : Temperature;
      out item result : ViscosityResult;
    }

    action validateResult {
      in item result : ViscosityResult;
      out attribute qualityFlag : String;
    }
  }

  part def OperatorInterface {
    port commandOut : CommandPort;
    port resultIn : ResultPort;
    port statusIn : StatusPort;

    part display;
    part keypad;
    part dataLogger;

    action showResult {
      in item result : ViscosityResult;
    }

    action showStatus {
      in item status : DiagnosticStatus;
    }
  }

  part def Viscometer {
    port sampleIn : SampleInPort;
    port wasteOut : SampleOutPort;
    port power : PowerPort;
    port commandIn : CommandPort;
    port resultOut : ResultPort;
    port statusOut : StatusPort;

    attribute primaryFunction : String = "Determine the viscosity of a liquid sample by controlling sample temperature, applying controlled spindle motion, measuring resisting torque, and computing a traceable viscosity result.";
    attribute dynamicViscosityRangeMin : DynamicViscosity = 0.2;
    attribute dynamicViscosityRangeMax : DynamicViscosity = 1000000.0;
    attribute temperatureControlRangeMin : Temperature = 15.0;
    attribute temperatureControlRangeMax : Temperature = 90.0;
    attribute nominalSupplyVoltage : Voltage = 24.0;

    part sampleHandling : SampleHandlingSubsystem;
    part thermalControl : ThermalControlSubsystem;
    part rotorDrive : RotorDriveSubsystem;
    part torqueMeasurement : TorqueMeasurementSubsystem;
    part computation : ViscosityComputationSubsystem;
    part operatorInterface : OperatorInterface;

    connect sampleIn to sampleHandling.sampleIn;
    connect sampleHandling.wasteOut to wasteOut;
    connect power to thermalControl.power;
    connect power to rotorDrive.power;
    connect commandIn to computation.commandIn;
    connect operatorInterface.commandOut to computation.commandIn;
    connect computation.resultOut to resultOut;
    connect computation.resultOut to operatorInterface.resultIn;
    connect computation.statusOut to statusOut;
    connect computation.statusOut to operatorInterface.statusIn;
    connect rotorDrive.speedOut to computation;
    connect torqueMeasurement.torqueOut to computation;
    connect thermalControl.temperatureOut to computation;

    action performMeasurement {
      in item sample : LiquidSample;
      in item command : MeasurementCommand;
      out item result : ViscosityResult;

      first start;
      then condition = sampleHandling.conditionSample(rawSample = sample);
      then regulate = thermalControl.regulateTemperature(targetTemperature = command.targetTemperature);
      then rotate = rotorDrive.rotateSpindle(targetSpeed = command.targetSpeed);
      then torque = torqueMeasurement.measureTorque();
      then calculate = computation.computeViscosity(
        sample = condition.conditioned,
        torque = torque.measuredTorque,
        speed = rotate.actualSpeed,
        temperature = regulate.stabilizedTemperature
      );
      then result = calculate.result;
    }

    state def MeasurementStateMachine {
      state idle;
      state acceptingSample;
      state conditioning;
      state stabilizingTemperature;
      state rotating;
      state measuringTorque;
      state calculating;
      state reporting;
      state draining;
      state fault;

      transition initial then idle;
      transition idle to acceptingSample
        accept MeasurementCommand
        if commandIn.command.replicateCount > 0;
      transition acceptingSample to conditioning
        if sampleHandling.sampleIn.sample.sampleId != "";
      transition conditioning to stabilizingTemperature
        if true;
      transition stabilizingTemperature to rotating
        if thermalControl.temperatureOut.temperature >= commandIn.command.targetTemperature - thermalControl.stabilityBand and
           thermalControl.temperatureOut.temperature <= commandIn.command.targetTemperature + thermalControl.stabilityBand;
      transition rotating to measuringTorque
        if rotorDrive.speedOut.speed >= commandIn.command.targetSpeed - rotorDrive.speedAccuracy and
           rotorDrive.speedOut.speed <= commandIn.command.targetSpeed + rotorDrive.speedAccuracy;
      transition measuringTorque to calculating
        if torqueMeasurement.torqueOut.torque >= torqueMeasurement.torqueRangeMin and
           torqueMeasurement.torqueOut.torque <= torqueMeasurement.torqueRangeMax;
      transition calculating to reporting;
      transition reporting to draining;
      transition draining to idle;
      transition acceptingSample to fault
        if sampleHandling.sampleIn.sample.expectedViscosityRangeMax > dynamicViscosityRangeMax;
      transition stabilizingTemperature to fault
        if commandIn.command.targetTemperature < temperatureControlRangeMin or
           commandIn.command.targetTemperature > temperatureControlRangeMax;
      transition measuringTorque to fault
        if torqueMeasurement.torqueOut.torque > torqueMeasurement.torqueRangeMax;
      transition fault to idle
        accept MeasurementCommand;
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc
    /* The viscometer shall determine the dynamic viscosity of a liquid sample at a controlled temperature by imposing controlled spindle motion and measuring the resisting torque. */

    subject viscometer : Viscometer;

    require constraint {
      viscometer.dynamicViscosityRangeMin <= viscometer.computation.lastDynamicViscosity and
      viscometer.computation.lastDynamicViscosity <= viscometer.dynamicViscosityRangeMax
    }
  }

  requirement def TemperatureControlRequirement {
    doc
    /* The viscometer shall maintain sample temperature within 0.05 degC of the commanded setpoint before recording torque data. */

    subject viscometer : Viscometer;

    require constraint {
      viscometer.thermalControl.temperatureOut.temperature >= viscometer.computation.commandIn.command.targetTemperature - viscometer.thermalControl.stabilityBand and
      viscometer.thermalControl.temperatureOut.temperature <= viscometer.computation.commandIn.command.targetTemperature + viscometer.thermalControl.stabilityBand
    }
  }

  requirement def SpeedControlRequirement {
    doc
    /* The rotor drive shall maintain spindle speed within 0.05 rpm of the commanded speed during measurement. */

    subject viscometer : Viscometer;

    require constraint {
      viscometer.rotorDrive.speedOut.speed >= viscometer.computation.commandIn.command.targetSpeed - viscometer.rotorDrive.speedAccuracy and
      viscometer.rotorDrive.speedOut.speed <= viscometer.computation.commandIn.command.targetSpeed + viscometer.rotorDrive.speedAccuracy
    }
  }

  requirement def ResultReportingRequirement {
    doc
    /* The viscometer shall report dynamic viscosity, kinematic viscosity, temperature, torque, speed, timestamp, and quality flag for each completed measurement. */

    subject result : ViscosityResult;

    require constraint {
      result.sampleId != "" and
      result.dynamicViscosity > 0.0 and
      result.kinematicViscosity > 0.0 and
      result.qualityFlag != ""
    }
  }

  requirement def SafetyRequirement {
    doc
    /* The viscometer shall enter a fault state when measured torque exceeds the calibrated torque range or when requested temperature is outside the allowable operating range. */

    subject viscometer : Viscometer;

    require constraint {
      viscometer.torqueMeasurement.torqueOut.torque <= viscometer.torqueMeasurement.torqueRangeMax and
      viscometer.computation.commandIn.command.targetTemperature >= viscometer.temperatureControlRangeMin and
      viscometer.computation.commandIn.command.targetTemperature <= viscometer.temperatureControlRangeMax
    }
  }

  satisfy PrimaryFunctionRequirement by Viscometer;
  satisfy TemperatureControlRequirement by Viscometer.thermalControl;
  satisfy SpeedControlRequirement by Viscometer.rotorDrive;
  satisfy ResultReportingRequirement by Viscometer.computation;
  satisfy SafetyRequirement by Viscometer;

  part laboratoryViscometer : Viscometer {
    attribute dynamicViscosityRangeMin = 0.2;
    attribute dynamicViscosityRangeMax = 1000000.0;
    attribute temperatureControlRangeMin = 15.0;
    attribute temperatureControlRangeMax = 90.0;
    attribute nominalSupplyVoltage = 24.0;
  }

}