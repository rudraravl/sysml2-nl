package ElectronBasedImagingSystemModel {

  import ScalarValues::*;
  import SI::*;

  value def ElectricCharge {
    unit C;
  }

  value def ElectronVoltEnergy {
    unit eV;
  }

  value def ElectricPotential {
    unit V;
  }

  value def ElectricCurrent {
    unit A;
  }

  value def MagneticFluxDensity {
    unit T;
  }

  value def Length {
    unit m;
  }

  value def Time {
    unit s;
  }

  value def Temperature {
    unit K;
  }

  value def Pressure {
    unit Pa;
  }

  value def DataRate {
    unit bit_per_s;
  }

  item def Electron {
    attribute charge : ElectricCharge = -1.602176634e-19 [C];
    attribute restMass : Real = 9.1093837015e-31;
    attribute spinQuantumNumber : Real = 0.5;
  }

  item def ElectronBeam {
    attribute beamEnergy : ElectronVoltEnergy;
    attribute beamCurrent : ElectricCurrent;
    attribute spotDiameter : Length;
    attribute divergenceAngle : Real;
    attribute electronFlux : Real;
  }

  item def VacuumEnvironment {
    attribute chamberPressure : Pressure;
    attribute chamberTemperature : Temperature;
  }

  item def SampleSurface {
    attribute workingDistance : Length;
    attribute surfacePotential : ElectricPotential;
    attribute materialConductivity : Real;
  }

  item def SecondaryElectronSignal {
    attribute intensity : Real;
    attribute collectionEnergy : ElectronVoltEnergy;
    attribute timestamp : Time;
  }

  item def ImageFrame {
    attribute widthPixels : Integer;
    attribute heightPixels : Integer;
    attribute dwellTime : Time;
    attribute pixelSize : Length;
    attribute signalToNoiseRatio : Real;
  }

  port def ElectronSourcePort {
    out item emittedBeam : ElectronBeam;
  }

  port def ElectronBeamInputPort {
    in item incomingBeam : ElectronBeam;
  }

  port def ElectronBeamOutputPort {
    out item outgoingBeam : ElectronBeam;
  }

  port def SampleInteractionPort {
    in item focusedBeam : ElectronBeam;
    in item environment : VacuumEnvironment;
    inout item sample : SampleSurface;
    out item secondarySignal : SecondaryElectronSignal;
  }

  port def SignalInputPort {
    in item signal : SecondaryElectronSignal;
  }

  port def ImageOutputPort {
    out item frame : ImageFrame;
  }

  port def VacuumServicePort {
    out item vacuum : VacuumEnvironment;
  }

  part def ElectronGun {
    attribute cathodeTemperature : Temperature;
    attribute extractionVoltage : ElectricPotential;
    attribute emissionCurrent : ElectricCurrent;

    port electronOut : ElectronSourcePort;

    action emitElectrons {
      out item emitted : ElectronBeam;
    }
  }

  part def AccelerationStage {
    attribute accelerationVoltage : ElectricPotential;
    attribute energySpread : ElectronVoltEnergy;

    port beamIn : ElectronBeamInputPort;
    port beamOut : ElectronBeamOutputPort;

    action accelerateBeam {
      in item lowEnergyBeam : ElectronBeam;
      out item highEnergyBeam : ElectronBeam;
    }
  }

  part def MagneticLens {
    attribute coilCurrent : ElectricCurrent;
    attribute magneticField : MagneticFluxDensity;
    attribute focalLength : Length;

    port beamIn : ElectronBeamInputPort;
    port beamOut : ElectronBeamOutputPort;

    action focusBeam {
      in item unfocusedBeam : ElectronBeam;
      out item focusedBeam : ElectronBeam;
    }
  }

  part def ScanDeflector {
    attribute horizontalDeflectionVoltage : ElectricPotential;
    attribute verticalDeflectionVoltage : ElectricPotential;
    attribute scanRate : Real;

    port beamIn : ElectronBeamInputPort;
    port beamOut : ElectronBeamOutputPort;

    action rasterScan {
      in item focusedBeam : ElectronBeam;
      out item positionedBeam : ElectronBeam;
    }
  }

  part def VacuumSubsystem {
    attribute pumpSpeed : Real;
    attribute targetPressure : Pressure = 1.0e-4 [Pa];

    port vacuumOut : VacuumServicePort;

    action evacuateChamber {
      out item vacuumState : VacuumEnvironment;
    }
  }

  part def SampleStage {
    attribute xPosition : Length;
    attribute yPosition : Length;
    attribute zPosition : Length;
    attribute tiltAngle : Real;

    port interaction : SampleInteractionPort;

    action exposeSample {
      in item incidentBeam : ElectronBeam;
      out item emittedSignal : SecondaryElectronSignal;
    }
  }

  part def ElectronDetector {
    attribute biasVoltage : ElectricPotential;
    attribute gain : Real;
    attribute bandwidth : DataRate;

    port signalIn : SignalInputPort;

    action convertElectronSignal {
      in item secondaryElectrons : SecondaryElectronSignal;
      out attribute digitalIntensity : Real;
    }
  }

  part def ImageProcessor {
    attribute frameWidth : Integer = 2048;
    attribute frameHeight : Integer = 2048;
    attribute noiseReductionEnabled : Boolean = true;

    port imageOut : ImageOutputPort;

    action assembleImage {
      in attribute intensityStream : Real;
      out item image : ImageFrame;
    }
  }

  part def ElectronBasedImager {
    doc /* Primary high-level function: use controlled electrons as an information carrier to probe a material surface and produce a magnified digital image from emitted electron signals. */

    part gun : ElectronGun {
      attribute cathodeTemperature = 1800 [K];
      attribute extractionVoltage = 5000 [V];
      attribute emissionCurrent = 20.0e-6 [A];
    }

    part accelerator : AccelerationStage {
      attribute accelerationVoltage = 30000 [V];
      attribute energySpread = 0.7 [eV];
    }

    part condenserLens : MagneticLens {
      attribute coilCurrent = 1.2 [A];
      attribute magneticField = 0.18 [T];
      attribute focalLength = 0.045 [m];
    }

    part objectiveLens : MagneticLens {
      attribute coilCurrent = 2.4 [A];
      attribute magneticField = 0.42 [T];
      attribute focalLength = 0.006 [m];
    }

    part scanner : ScanDeflector {
      attribute horizontalDeflectionVoltage = 80 [V];
      attribute verticalDeflectionVoltage = 80 [V];
      attribute scanRate = 30.0;
    }

    part vacuumSystem : VacuumSubsystem {
      attribute pumpSpeed = 85.0;
      attribute targetPressure = 5.0e-5 [Pa];
    }

    part stage : SampleStage {
      attribute xPosition = 0.0 [m];
      attribute yPosition = 0.0 [m];
      attribute zPosition = 0.008 [m];
      attribute tiltAngle = 0.0;
    }

    part detector : ElectronDetector {
      attribute biasVoltage = 300 [V];
      attribute gain = 1250.0;
      attribute bandwidth = 250000000 [bit_per_s];
    }

    part processor : ImageProcessor;

    connect gun.electronOut.emittedBeam to accelerator.beamIn.incomingBeam;
    connect accelerator.beamOut.outgoingBeam to condenserLens.beamIn.incomingBeam;
    connect condenserLens.beamOut.outgoingBeam to objectiveLens.beamIn.incomingBeam;
    connect objectiveLens.beamOut.outgoingBeam to scanner.beamIn.incomingBeam;
    connect scanner.beamOut.outgoingBeam to stage.interaction.focusedBeam;
    connect vacuumSystem.vacuumOut.vacuum to stage.interaction.environment;
    connect stage.interaction.secondarySignal to detector.signalIn.signal;

    action operateImagingCycle {
      first startVacuum : vacuumSystem.evacuateChamber;
      then startEmission : gun.emitElectrons;
      then raiseEnergy : accelerator.accelerateBeam;
      then condense : condenserLens.focusBeam;
      then focusAtSample : objectiveLens.focusBeam;
      then scanSurface : scanner.rasterScan;
      then interact : stage.exposeSample;
      then detect : detector.convertElectronSignal;
      then render : processor.assembleImage;
    }

    state operationalStates {
      state PoweredOff;

      state PumpingDown {
        entry action vacuumSystem.evacuateChamber;
      }

      state BeamStandby {
        entry action gun.emitElectrons;
      }

      state Imaging {
        entry action operateImagingCycle;
      }

      state Fault {
        entry action {
          detector.gain = 0.0;
          gun.emissionCurrent = 0.0 [A];
        }
      }

      transition powerOn first PoweredOff then PumpingDown;
      transition vacuumReady first PumpingDown then BeamStandby
        if vacuumSystem.targetPressure <= 1.0e-4 [Pa];

      transition beginScan first BeamStandby then Imaging;
      transition pauseScan first Imaging then BeamStandby;
      transition shutdown first BeamStandby then PoweredOff;
      transition pressureFault first Imaging then Fault
        if vacuumSystem.targetPressure > 1.0e-2 [Pa];

      transition resetFault first Fault then PumpingDown;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject imager : ElectronBasedImager;

    require constraint {
      imager.processor.frameWidth >= 1024 and
      imager.processor.frameHeight >= 1024
    }

    doc /* The system shall use an electron beam to interrogate a sample and output a digital image frame representing surface-dependent electron emission. */
  }

  requirement def BeamEnergyRequirement {
    subject imager : ElectronBasedImager;

    require constraint {
      imager.accelerator.accelerationVoltage >= 1000 [V] and
      imager.accelerator.accelerationVoltage <= 30000 [V]
    }
  }

  requirement def VacuumRequirement {
    subject imager : ElectronBasedImager;

    require constraint {
      imager.vacuumSystem.targetPressure <= 1.0e-4 [Pa]
    }
  }

  requirement def FocusRequirement {
    subject imager : ElectronBasedImager;

    require constraint {
      imager.objectiveLens.focalLength <= 0.010 [m]
    }
  }

  requirement def SignalAcquisitionRequirement {
    subject imager : ElectronBasedImager;

    require constraint {
      imager.detector.bandwidth >= 100000000 [bit_per_s] and
      imager.detector.gain >= 100.0
    }
  }

  satisfy PrimaryFunctionRequirement by ElectronBasedImager;
  satisfy BeamEnergyRequirement by ElectronBasedImager;
  satisfy VacuumRequirement by ElectronBasedImager;
  satisfy FocusRequirement by ElectronBasedImager;
  satisfy SignalAcquisitionRequirement by ElectronBasedImager;
}