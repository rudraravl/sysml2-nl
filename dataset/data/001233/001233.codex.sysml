package ScanningSQUIDMicroscopeModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def MagneticFlux :> ISQ::magneticFlux {
    unit = "Wb";
  }

  attribute def MagneticFluxDensity :> ISQ::magneticFluxDensity {
    unit = "T";
  }

  attribute def ElectricCurrent :> ISQ::electricCurrent {
    unit = "A";
  }

  attribute def ElectricVoltage :> ISQ::electricPotential {
    unit = "V";
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = "K";
  }

  attribute def Length :> ISQ::length {
    unit = "m";
  }

  attribute def Frequency :> ISQ::frequency {
    unit = "Hz";
  }

  attribute def Time :> ISQ::time {
    unit = "s";
  }

  attribute def ScanSpeed :> ISQ::speed {
    unit = "m/s";
  }

  attribute def Position2D {
    attribute x : Length;
    attribute y : Length;
  }

  item def MagneticFieldSample {
    attribute position : Position2D;
    attribute fluxDensity : MagneticFluxDensity;
    attribute flux : MagneticFlux;
    attribute timestamp : Time;
  }

  item def ScanCommand {
    attribute scanAreaX : Length;
    attribute scanAreaY : Length;
    attribute stepSize : Length;
    attribute dwellTime : Time;
    attribute heightSetpoint : Length;
  }

  item def BiasCommand {
    attribute current : ElectricCurrent;
    attribute modulationFrequency : Frequency;
  }

  item def SQUIDVoltageSignal {
    attribute voltage : ElectricVoltage;
    attribute timestamp : Time;
  }

  item def TopographySample {
    attribute position : Position2D;
    attribute sampleHeight : Length;
    attribute timestamp : Time;
  }

  item def MagneticImage {
    attribute pixelCountX : ScalarValues::Integer;
    attribute pixelCountY : ScalarValues::Integer;
    attribute fieldRangeMinimum : MagneticFluxDensity;
    attribute fieldRangeMaximum : MagneticFluxDensity;
    attribute spatialResolution : Length;
  }

  port def CommandPort {
    in item command : ScanCommand;
  }

  port def BiasPort {
    in item bias : BiasCommand;
  }

  port def SQUIDSignalPort {
    out item signal : SQUIDVoltageSignal;
  }

  port def FieldDataPort {
    out item fieldSample : MagneticFieldSample;
  }

  port def TopographyDataPort {
    out item topography : TopographySample;
  }

  port def ImageDataPort {
    out item image : MagneticImage;
  }

  port def CryogenicThermalPort {
    inout attribute temperature : Temperature;
  }

  part def SuperconductingPickupLoop {
    attribute loopDiameter : Length = 1.0e-6 [m];
    attribute effectiveArea : ISQ::area = 7.85e-13 [m^2];
    attribute operatingTemperature : Temperature = 4.2 [K];
    attribute coupledFlux : MagneticFlux;

    port fieldOut : FieldDataPort;
  }

  part def SQUIDSensor {
    attribute criticalCurrent : ElectricCurrent = 20.0e-6 [A];
    attribute biasCurrent : ElectricCurrent = 18.0e-6 [A];
    attribute fluxNoiseDensity : MagneticFlux = 1.0e-6 [Wb];
    attribute transferFunction : ElectricVoltage = 150.0e-6 [V];

    port biasIn : BiasPort;
    port voltageOut : SQUIDSignalPort;
    port thermal : CryogenicThermalPort;

    part pickupLoop : SuperconductingPickupLoop;
  }

  part def CryogenicSubsystem {
    attribute bathTemperature : Temperature = 4.2 [K];
    attribute temperatureStability : Temperature = 0.005 [K];
    attribute cooldownTime : Time = 7200 [s];

    port sensorThermal : CryogenicThermalPort;
  }

  part def PiezoScanner {
    attribute rangeX : Length = 100.0e-6 [m];
    attribute rangeY : Length = 100.0e-6 [m];
    attribute rangeZ : Length = 10.0e-6 [m];
    attribute minimumStep : Length = 50.0e-9 [m];
    attribute maximumScanSpeed : ScanSpeed = 100.0e-6 [m/s];
    attribute currentPosition : Position2D;

    port commandIn : CommandPort;
  }

  part def HeightControlSubsystem {
    attribute heightSetpoint : Length = 500.0e-9 [m];
    attribute heightError : Length;
    attribute feedbackBandwidth : Frequency = 1000 [Hz];

    port topographyOut : TopographyDataPort;
  }

  part def SampleStage {
    attribute sampleWidth : Length = 5.0e-3 [m];
    attribute sampleLength : Length = 5.0e-3 [m];
    attribute sampleTemperature : Temperature = 4.2 [K];
  }

  part def FluxLockedLoopElectronics {
    attribute modulationFrequency : Frequency = 100000 [Hz];
    attribute feedbackCurrent : ElectricCurrent;
    attribute outputVoltage : ElectricVoltage;
    attribute bandwidth : Frequency = 50000 [Hz];

    port biasOut : BiasPort;
    port squidIn : SQUIDSignalPort;
    port fieldOut : FieldDataPort;
  }

  part def ControlAndAcquisitionComputer {
    attribute commandedStepSize : Length = 250.0e-9 [m];
    attribute commandedDwellTime : Time = 0.01 [s];
    attribute acquiredPointCount : ScalarValues::Integer;

    port scanCommandOut : CommandPort;
    port fieldIn : FieldDataPort;
    port topographyIn : TopographyDataPort;
    port imageOut : ImageDataPort;
  }

  action def InitializeMicroscope {
    in part cryostat : CryogenicSubsystem;
    in part squid : SQUIDSensor;
    in part scanner : PiezoScanner;

    first start;
    then coolSensor;
    then biasSQUID;
    then homeScanner;
    then ready;

    action coolSensor {
      out attribute stableTemperature : Temperature = 4.2 [K];
    }

    action biasSQUID {
      out attribute appliedBias : ElectricCurrent = 18.0e-6 [A];
    }

    action homeScanner {
      out attribute origin : Position2D;
    }
  }

  action def AcquireMagneticScan {
    in item command : ScanCommand;
    out item image : MagneticImage;

    first receiveScanCommand;
    then rasterScan;

    action receiveScanCommand {
      in item command : ScanCommand;
    }

    action rasterScan {
      action moveToNextPixel;
      action stabilizeHeight;
      action measureSQUIDFlux;
      action convertFluxToField;
      action storePixel;
    }

    then assembleMagneticImage;

    action assembleMagneticImage {
      out item image : MagneticImage;
    }
  }

  state def MicroscopeOperatingState {
    state off;
    state cooling;
    state standby;
    state scanning;
    state fault;
    state warming;

    transition first off then cooling;
    transition cooling then standby
      accept when true;
    transition standby then scanning
      accept item command : ScanCommand;
    transition scanning then standby
      accept when true;
    transition standby then warming
      accept when true;
    transition cooling then fault
      accept when false;
    transition scanning then fault
      accept when false;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The scanning SQUID microscope shall map weak magnetic fields above a sample surface by raster scanning a superconducting quantum interference device pickup loop and converting measured magnetic flux into a spatially resolved magnetic image. */

    subject microscope : ScanningSQUIDMicroscope;

    require constraint {
      microscope.spatialResolution <= 1.0e-6 [m]
    }

    require constraint {
      microscope.minimumDetectableField <= 1.0e-12 [T]
    }
  }

  requirement def CryogenicOperationRequirement {
    subject microscope : ScanningSQUIDMicroscope;

    require constraint {
      microscope.cryogenicSubsystem.bathTemperature <= 4.5 [K]
    }

    require constraint {
      microscope.squidSensor.operatingTemperature <= 4.5 [K]
    }
  }

  requirement def ScanAreaRequirement {
    subject microscope : ScanningSQUIDMicroscope;

    require constraint {
      microscope.scanner.rangeX >= 50.0e-6 [m]
    }

    require constraint {
      microscope.scanner.rangeY >= 50.0e-6 [m]
    }
  }

  requirement def HeightControlRequirement {
    subject microscope : ScanningSQUIDMicroscope;

    require constraint {
      microscope.heightControl.heightSetpoint >= 100.0e-9 [m]
    }

    require constraint {
      microscope.heightControl.heightSetpoint <= 2.0e-6 [m]
    }
  }

  part def ScanningSQUIDMicroscope {
    attribute spatialResolution : Length = 1.0e-6 [m];
    attribute minimumDetectableField : MagneticFluxDensity = 1.0e-12 [T];
    attribute nominalScanSpeed : ScanSpeed = 25.0e-6 [m/s];
    attribute primaryFunction : ScalarValues::String = "Create spatially resolved images of weak magnetic fields above a sample using a scanned superconducting quantum interference device.";

    port scanCommand : CommandPort;
    port magneticImageOut : ImageDataPort;

    part squidSensor : SQUIDSensor;
    part cryogenicSubsystem : CryogenicSubsystem;
    part scanner : PiezoScanner;
    part heightControl : HeightControlSubsystem;
    part sampleStage : SampleStage;
    part fluxLockedLoop : FluxLockedLoopElectronics;
    part computer : ControlAndAcquisitionComputer;

    connect cryogenicSubsystem.sensorThermal to squidSensor.thermal;
    connect computer.scanCommandOut to scanner.commandIn;
    connect computer.scanCommandOut to scanCommand;
    connect fluxLockedLoop.biasOut to squidSensor.biasIn;
    connect squidSensor.voltageOut to fluxLockedLoop.squidIn;
    connect fluxLockedLoop.fieldOut to computer.fieldIn;
    connect heightControl.topographyOut to computer.topographyIn;
    connect computer.imageOut to magneticImageOut;

    perform initialize : InitializeMicroscope {
      in cryostat = cryogenicSubsystem;
      in squid = squidSensor;
      in scanner = scanner;
    }

    perform acquireScan : AcquireMagneticScan {
      in command = scanCommand.command;
      out image = magneticImageOut.image;
    }

    exhibit state operatingState : MicroscopeOperatingState;
  }

  part microscope : ScanningSQUIDMicroscope;

  satisfy PrimaryFunctionRequirement by microscope;
  satisfy CryogenicOperationRequirement by microscope;
  satisfy ScanAreaRequirement by microscope;
  satisfy HeightControlRequirement by microscope;
}