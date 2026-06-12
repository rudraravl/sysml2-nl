package NicholsRadiometerSystemModel {

  import ScalarValues::*;
  import SI::*;

  value type Length {
    unit = m;
  }

  value type Angle {
    unit = rad;
  }

  value type Time {
    unit = s;
  }

  value type Mass {
    unit = kg;
  }

  value type Force {
    unit = N;
  }

  value type Torque {
    unit = N*m;
  }

  value type Pressure {
    unit = Pa;
  }

  value type OpticalPower {
    unit = W;
  }

  value type Irradiance {
    unit = W/m^2;
  }

  value type Temperature {
    unit = K;
  }

  value type AngularStiffness {
    unit = N*m/rad;
  }

  value type DampingCoefficient {
    unit = N*m*s/rad;
  }

  value type Reflectance {
    unit = one;
  }

  value type VacuumPressure {
    unit = Pa;
  }

  item def LightBeam {
    attribute wavelength : Length;
    attribute opticalPower : OpticalPower;
    attribute irradiance : Irradiance;
    attribute beamArea : Length^2;
    attribute modulationFrequency : 1/s;
  }

  item def ReflectedLight {
    attribute reflectedPower : OpticalPower;
    attribute reflectedAngle : Angle;
  }

  item def ElectricalSignal {
    attribute voltage : V;
    attribute sampleTime : Time;
  }

  item def RadiationPressureEstimate {
    attribute pressure : Pressure;
    attribute force : Force;
    attribute torque : Torque;
    attribute uncertainty : Pressure;
  }

  port def LightInputPort {
    in item incidentLight : LightBeam;
  }

  port def LightOutputPort {
    out item reflectedLight : ReflectedLight;
  }

  port def SignalOutputPort {
    out item estimate : RadiationPressureEstimate;
  }

  port def ElectricalOutputPort {
    out item signal : ElectricalSignal;
  }

  port def VacuumServicePort {
    in item chamberPressure : VacuumPressure;
  }

  action def AdmitLight {
    in item incident : LightBeam;
    out item collimated : LightBeam;
  }

  action def ApplyRadiationPressure {
    in item beam : LightBeam;
    in attribute reflectance : Reflectance;
    in attribute mirrorArea : Length^2;
    out attribute radiationForce : Force;
    out attribute appliedTorque : Torque;
  }

  action def MeasureAngularDeflection {
    in attribute torque : Torque;
    in attribute torsionConstant : AngularStiffness;
    out attribute deflection : Angle;
  }

  action def ConvertDeflectionToPressure {
    in attribute deflection : Angle;
    in attribute torsionConstant : AngularStiffness;
    in attribute leverArm : Length;
    in attribute mirrorArea : Length^2;
    out item result : RadiationPressureEstimate;
  }

  state def RadiometerOperatingState {
    state Idle;
    state Evacuating;
    state Zeroing;
    state Measuring;
    state Computing;
    state Reporting;
    state Faulted;

    transition initial then Idle;

    transition Idle_to_Evacuating
      first Idle
      accept startCommand
      then Evacuating;

    transition Evacuating_to_Zeroing
      first Evacuating
      if chamberPressure <= 1.0e-3 Pa
      then Zeroing;

    transition Zeroing_to_Measuring
      first Zeroing
      if angularDeflection == 0.0 rad
      then Measuring;

    transition Measuring_to_Computing
      first Measuring
      accept stableDeflectionDetected
      then Computing;

    transition Computing_to_Reporting
      first Computing
      accept pressureEstimateAvailable
      then Reporting;

    transition Reporting_to_Measuring
      first Reporting
      accept nextSampleRequested
      then Measuring;

    transition Any_to_Faulted
      first Idle, Evacuating, Zeroing, Measuring, Computing, Reporting
      if chamberPressure > 10.0 Pa
      then Faulted;
  }

  part def NicholsRadiometer {
    doc
    /*
     * A Nichols radiometer is a precision instrument that detects radiation
     * pressure by observing the torsional deflection of a suspended mirror
     * assembly when illuminated by a calibrated light beam.
     */

    port lightIn : LightInputPort;
    port reflectedLightOut : LightOutputPort;
    port pressureEstimateOut : SignalOutputPort;
    port vacuumService : VacuumServicePort;

    attribute primaryFunction : String = "Measure incident electromagnetic radiation pressure by converting light-induced torque on a suspended reflective vane into angular deflection and then into a pressure estimate.";

    attribute operatingState : RadiometerOperatingState;
    attribute chamberPressure : VacuumPressure;
    attribute measuredDeflection : Angle;
    attribute computedRadiationPressure : Pressure;

    part vacuumChamber : VacuumChamber;
    part opticalBench : OpticalBench;
    part torsionSuspension : TorsionSuspension;
    part mirrorAssembly : MirrorVaneAssembly;
    part angularReadout : OpticalReadout;
    part processor : MeasurementProcessor;
    part environmentalController : EnvironmentalController;

    connection incidentOpticalPath
      connect lightIn.incidentLight to opticalBench.inputBeam;

    connection collimatedBeamPath
      connect opticalBench.collimatedBeam to mirrorAssembly.incidentBeam;

    connection reflectedBeamPath
      connect mirrorAssembly.reflectedBeam to angularReadout.trackingBeam;

    connection readoutSignalPath
      connect angularReadout.deflectionSignal to processor.deflectionInput;

    connection estimateOutputPath
      connect processor.pressureEstimate to pressureEstimateOut.estimate;

    connection chamberPressurePath
      connect vacuumService.chamberPressure to vacuumChamber.internalPressure;

    perform action measureRadiationPressure {
      first start;
      then admitLight : AdmitLight {
        in incident = lightIn.incidentLight;
        out collimated = opticalBench.inputBeam;
      }
      then applyPressure : ApplyRadiationPressure {
        in beam = opticalBench.collimatedBeam;
        in reflectance = mirrorAssembly.frontMirror.reflectance;
        in mirrorArea = mirrorAssembly.frontMirror.effectiveArea;
        out radiationForce = mirrorAssembly.netRadiationForce;
        out appliedTorque = torsionSuspension.appliedTorque;
      }
      then measureDeflection : MeasureAngularDeflection {
        in torque = torsionSuspension.appliedTorque;
        in torsionConstant = torsionSuspension.torsionConstant;
        out deflection = measuredDeflection;
      }
      then computePressure : ConvertDeflectionToPressure {
        in deflection = measuredDeflection;
        in torsionConstant = torsionSuspension.torsionConstant;
        in leverArm = mirrorAssembly.momentArm;
        in mirrorArea = mirrorAssembly.frontMirror.effectiveArea;
        out result = processor.pressureEstimate;
      }
      then done;
    }
  }

  part def VacuumChamber {
    attribute volume : Length^3 = 0.012 m^3;
    attribute windowTransmittance : Real = 0.995;
    attribute internalPressure : VacuumPressure;
    attribute allowableLeakRate : Pa*m^3/s = 1.0e-8 Pa*m^3/s;

    part inletWindow : OpticalWindow {
      attribute diameter = 0.050 m;
      attribute transmittance = 0.995;
    }

    part outletWindow : OpticalWindow {
      attribute diameter = 0.050 m;
      attribute transmittance = 0.995;
    }
  }

  part def OpticalWindow {
    attribute diameter : Length;
    attribute transmittance : Real;
    attribute wedgeAngle : Angle = 0.002 rad;
  }

  part def OpticalBench {
    in item inputBeam : LightBeam;
    out item collimatedBeam : LightBeam;

    attribute alignmentTolerance : Angle = 1.0e-5 rad;

    part aperture : PrecisionAperture {
      attribute diameter = 0.010 m;
    }

    part collimator : Collimator {
      attribute focalLength = 0.250 m;
    }

    part attenuator : OpticalAttenuator {
      attribute transmission = 0.50;
    }
  }

  part def PrecisionAperture {
    attribute diameter : Length;
    attribute edgeRoughness : Length = 1.0e-6 m;
  }

  part def Collimator {
    attribute focalLength : Length;
    attribute wavefrontError : Length = 5.0e-8 m;
  }

  part def OpticalAttenuator {
    attribute transmission : Real;
    attribute thermalAbsorptance : Real = 0.02;
  }

  part def TorsionSuspension {
    attribute fiberLength : Length = 0.150 m;
    attribute fiberRadius : Length = 1.25e-5 m;
    attribute torsionConstant : AngularStiffness = 2.0e-8 N*m/rad;
    attribute damping : DampingCoefficient = 4.0e-10 N*m*s/rad;
    attribute appliedTorque : Torque;
    attribute angularDeflection : Angle;

    part fiber : TorsionFiber;
    part upperClamp : Clamp;
    part lowerClamp : Clamp;
  }

  part def TorsionFiber {
    attribute material : String = "quartz";
    attribute length : Length = 0.150 m;
    attribute radius : Length = 1.25e-5 m;
    attribute elasticLimitTorque : Torque = 1.0e-6 N*m;
  }

  part def Clamp {
    attribute mass : Mass = 0.002 kg;
    attribute alignmentOffset : Angle = 2.0e-6 rad;
  }

  part def MirrorVaneAssembly {
    in item incidentBeam : LightBeam;
    out item reflectedBeam : ReflectedLight;

    attribute mass : Mass = 0.0008 kg;
    attribute momentArm : Length = 0.025 m;
    attribute netRadiationForce : Force;
    attribute netTorque : Torque;
    attribute balanceTolerance : Torque = 1.0e-11 N*m;

    part crossbar : BalanceBeam {
      attribute length = 0.060 m;
      attribute mass = 0.00025 kg;
    }

    part frontMirror : ReflectiveVane {
      attribute effectiveArea = 1.0e-4 m^2;
      attribute reflectance = 0.985;
      attribute absorptance = 0.010;
    }

    part rearMirror : ReflectiveVane {
      attribute effectiveArea = 1.0e-4 m^2;
      attribute reflectance = 0.985;
      attribute absorptance = 0.010;
    }
  }

  part def BalanceBeam {
    attribute length : Length;
    attribute mass : Mass;
    attribute centerOfMassOffset : Length = 2.0e-6 m;
  }

  part def ReflectiveVane {
    attribute effectiveArea : Length^2;
    attribute reflectance : Reflectance;
    attribute absorptance : Real;
    attribute surfaceFlatness : Length = 2.5e-8 m;
  }

  part def OpticalReadout {
    in item trackingBeam : ReflectedLight;
    out item deflectionSignal : ElectricalSignal;

    attribute angularResolution : Angle = 1.0e-7 rad;
    attribute samplePeriod : Time = 0.010 s;

    part readoutLaser : ReferenceLaser {
      attribute opticalPower = 0.001 W;
      attribute wavelength = 6.328e-7 m;
    }

    part positionSensor : PositionSensitiveDetector {
      attribute activeWidth = 0.020 m;
      attribute voltageSensitivity = 1000.0 V/m;
    }
  }

  part def ReferenceLaser {
    attribute opticalPower : OpticalPower;
    attribute wavelength : Length;
    attribute powerStability : Real = 1.0e-4;
  }

  part def PositionSensitiveDetector {
    attribute activeWidth : Length;
    attribute voltageSensitivity : V/m;
    attribute noiseVoltage : V = 1.0e-6 V;
  }

  part def MeasurementProcessor {
    in item deflectionInput : ElectricalSignal;
    out item pressureEstimate : RadiationPressureEstimate;

    attribute calibrationTorsionConstant : AngularStiffness = 2.0e-8 N*m/rad;
    attribute calibrationLeverArm : Length = 0.025 m;
    attribute calibrationMirrorArea : Length^2 = 1.0e-4 m^2;
    attribute lastComputedPressure : Pressure;

    perform action computeEstimate : ConvertDeflectionToPressure;
  }

  part def EnvironmentalController {
    attribute targetTemperature : Temperature = 293.15 K;
    attribute temperatureStability : Temperature = 0.02 K;
    attribute strayLightLimit : Irradiance = 1.0e-4 W/m^2;

    part thermalShield : ThermalShield {
      attribute emissivity = 0.05;
    }

    part baffleSet : OpticalBaffles {
      attribute attenuationRatio = 1.0e-6;
    }
  }

  part def ThermalShield {
    attribute emissivity : Real;
    attribute temperatureGradient : Temperature = 0.01 K;
  }

  part def OpticalBaffles {
    attribute attenuationRatio : Real;
    attribute vaneCount : Integer = 8;
  }

  requirement def PrimaryFunctionRequirement {
    subject radiometer : NicholsRadiometer;

    require constraint {
      radiometer.primaryFunction == "Measure incident electromagnetic radiation pressure by converting light-induced torque on a suspended reflective vane into angular deflection and then into a pressure estimate."
    }
  }

  requirement def VacuumRequirement {
    subject chamber : VacuumChamber;

    require constraint {
      chamber.internalPressure <= 1.0e-3 Pa
    }
  }

  requirement def DeflectionSensitivityRequirement {
    subject readout : OpticalReadout;

    require constraint {
      readout.angularResolution <= 1.0e-7 rad
    }
  }

  requirement def MirrorReflectanceRequirement {
    subject vane : ReflectiveVane;

    require constraint {
      vane.reflectance >= 0.98
    }
  }

  requirement def TorsionElasticRequirement {
    subject suspension : TorsionSuspension;

    require constraint {
      suspension.appliedTorque < suspension.fiber.elasticLimitTorque
    }
  }

  requirement def PressureEstimateRequirement {
    subject processor : MeasurementProcessor;

    require constraint {
      processor.pressureEstimate.uncertainty <= 0.05 * processor.pressureEstimate.pressure
    }
  }

  requirement def StrayLightRequirement {
    subject controller : EnvironmentalController;

    require constraint {
      controller.strayLightLimit <= 1.0e-4 W/m^2
    }
  }

  part nicholsRadiometer : NicholsRadiometer {
    attribute chamberPressure = 5.0e-4 Pa;
    attribute measuredDeflection = 2.5e-4 rad;
    attribute computedRadiationPressure = 1.0e-6 Pa;
  }

}