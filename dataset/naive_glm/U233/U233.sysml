package FreeElectronLaser {
    doc 'A Free-Electron Laser (FEL) system model describing the generation of intense, tunable, coherent light pulses from infrared to X-ray wavelengths for advanced scientific research.';

    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====

    value def ElectronEnergy :> Real {
        doc 'Energy of electron bunches, in electron-volts.';
        unit 'eV';
    }

    value def MagneticFluxDensity :> Real {
        doc 'Magnetic field strength, in teslas.';
        unit 'T';
    }

    value def WavelengthValue :> Real {
        doc 'Photon wavelength, in nanometers.';
        unit 'nm';
    }

    value def BeamCurrent :> Real {
        doc 'Electron beam current, in amperes.';
        unit 'A';
    }

    value def RFFrequency :> Real {
        doc 'Radio-frequency operating frequency, in gigahertz.';
        unit 'GHz';
    }

    value def VacuumPressure :> Real {
        doc 'Vacuum pressure, in pascals.';
        unit 'Pa';
    }

    value def TemperatureValue :> Real {
        doc 'Temperature, in kelvin.';
        unit 'K';
    }

    value def PulseDuration :> Real {
        doc 'Pulse duration, in femtoseconds.';
        unit 'fs';
    }

    value def BunchCharge :> Real {
        doc 'Electron bunch charge, in picocoulombs.';
        unit 'pC';
    }

    value def PhotonIntensity :> Real {
        doc 'Photon beam intensity, in watts per square meter.';
        unit 'W/m2';
    }

    value def CoherenceFactor :> Real {
        doc 'Degree of coherence, dimensionless (0 to 1).';
    }

    value def LengthValue :> Real {
        doc 'Length, in meters.';
        unit 'm';
    }

    value def PowerValue :> Real {
        doc 'Power, in watts.';
        unit 'W';
    }

    value def BeamEnergySpread :> Real {
        doc 'Relative energy spread of electron bunch, dimensionless.';
    }

    value def SpotSize :> Real {
        doc 'Beam focal spot size, in micrometers.';
        unit 'um';
    }

    value def AcceleratingGradient :> Real {
        doc 'RF accelerating gradient, in megavolts per meter.';
        unit 'MV/m';
    }

    // ===== Item Types =====

    item def ElectronBunch {
        doc 'A bunch of electrons with specific energy, charge, and length characteristics.';
        attribute energy : ElectronEnergy;
        attribute charge : BunchCharge;
        attribute bunchLength : LengthValue;
        attribute current : BeamCurrent;
        attribute energySpread : BeamEnergySpread;
    }

    item def PhotonBeam {
        doc 'A beam of photons with specific wavelength, intensity, and coherence.';
        attribute wavelength : WavelengthValue;
        attribute intensity : PhotonIntensity;
        attribute coherence : CoherenceFactor;
        attribute pulseDuration : PulseDuration;
    }

    item def ControlSignal {
        doc 'Control signal for commanding system components.';
        attribute setpoint : Real;
        attribute enabled : Boolean;
        attribute parameter : String;
    }

    item def DiagnosticData {
        doc 'Diagnostic measurement data from beam monitors.';
        attribute beamEnergy : ElectronEnergy;
        attribute beamCurrent : BeamCurrent;
        attribute wavelength : WavelengthValue;
        attribute intensity : PhotonIntensity;
        attribute coherence : CoherenceFactor;
        attribute qualityOK : Boolean;
        attribute timestamp : String;
    }

    // ===== Port Definitions =====

    port def ElectronInPort {
        in item : ElectronBunch;
    }

    port def ElectronOutPort {
        out item : ElectronBunch;
    }

    port def PhotonInPort {
        in item : PhotonBeam;
    }

    port def PhotonOutPort {
        out item : PhotonBeam;
    }

    port def ControlPort {
        in item : ControlSignal;
    }

    port def DiagnosticOutPort {
        out item : DiagnosticData;
    }

    port def DiagnosticInPort {
        in item : DiagnosticData;
    }

    // ===== Component Definitions =====

    part def ElectronGun {
        doc 'Produces and emits bunches of electrons for injection into the linear accelerator.';

        port electronOut : ElectronOutPort;
        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute cathodeTemperature : TemperatureValue := 1200.0;
        attribute initialEnergy : ElectronEnergy := 1000.0;
        attribute nominalBunchCharge : BunchCharge := 250.0;
        attribute enabled : Boolean := false;

        action produceElectrons {
            out item : ElectronBunch;
        }

        state GunStateMachine {
            entry then Off;
            state Off;
            state WarmUp;
            state Emitting;
            state Fault;

            transition offToWarmUp from Off to WarmUp when enabled;
            transition warmUpToEmitting from WarmUp to Emitting when (cathodeTemperature > 1100.0);
            transition emittingToOff from Emitting to Off when !enabled;
            transition anyToFault from Off, WarmUp, Emitting to Fault when (cathodeTemperature > 1500.0);
            transition faultToOff from Fault to Off when !enabled;
        }
    }

    part def LinearAccelerator {
        doc 'A long structure that uses powerful radio-frequency fields to accelerate electron bunches to nearly the speed of light.';

        port electronIn : ElectronInPort;
        port electronOut : ElectronOutPort;
        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute length : LengthValue := 30.0;
        attribute rfFrequency : RFFrequency := 3.0;
        attribute gradient : AcceleratingGradient := 25.0;
        attribute maxEnergy : ElectronEnergy := 17.0e9;
        attribute currentEnergy : ElectronEnergy := 0.0;
        attribute enabled : Boolean := false;

        action accelerate {
            in item : ElectronBunch;
            out item : ElectronBunch;
        }

        state LinacStateMachine {
            entry then Standby;
            state Standby;
            state RampUp;
            state Operating;
            state Fault;

            transition standbyToRampUp from Standby to RampUp when enabled;
            transition rampUpToOperating from RampUp to Operating when (gradient >= 20.0);
            transition operatingToStandby from Operating to Standby when !enabled;
            transition anyToFault from Standby, RampUp, Operating to Fault when (gradient < 0.0);
        }
    }

    part def BunchCompressor {
        doc 'Uses magnetic fields to squeeze electron bunches into shorter, denser packets for high-intensity light production.';

        port electronIn : ElectronInPort;
        port electronOut : ElectronOutPort;
        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute compressionRatio : Real := 10.0;
        attribute magneticField : MagneticFluxDensity := 1.5;
        attribute inputBunchLength : LengthValue;
        attribute outputBunchLength : LengthValue;
        attribute enabled : Boolean := false;

        action compress {
            in item : ElectronBunch;
            out item : ElectronBunch;
        }

        state CompressorStateMachine {
            entry then Idle;
            state Idle;
            state Compressing;

            transition idleToCompressing from Idle to Compressing when enabled;
            transition compressingToIdle from Compressing to Idle when !enabled;
        }
    }

    part def Undulator {
        doc 'A long device with alternating magnets that forces electrons into a wiggling path, causing synchronized photon emission.';

        port electronIn : ElectronInPort;
        port electronOut : ElectronOutPort;
        port photonOut : PhotonOutPort;
        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute length : LengthValue := 50.0;
        attribute period : LengthValue := 0.036;
        attribute magneticField : MagneticFluxDensity := 1.0;
        attribute deflectionParameter : Real := 1.0;
        attribute enabled : Boolean := false;

        action wiggleAndEmit {
            in item : ElectronBunch;
            out item : ElectronBunch;
            out item : PhotonBeam;
        }

        state UndulatorStateMachine {
            entry then Idle;
            state Idle;
            state Wiggling;
            state Fault;

            transition idleToWiggling from Idle to Wiggling when enabled;
            transition wigglingToIdle from Wiggling to Idle when !enabled;
            transition anyToFault from Idle, Wiggling to Fault when (magneticField > 5.0);
        }
    }

    part def MagneticFieldController {
        doc 'Precisely adjusts the undulator magnets to create a specific periodic magnetic field for wavelength tuning.';

        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute setpointField : MagneticFluxDensity := 1.0;
        attribute currentField : MagneticFluxDensity := 0.0;
        attribute precision : MagneticFluxDensity := 0.01;
        attribute enabled : Boolean := false;
        attribute calibrationNeeded : Boolean := false;

        action adjustField {
            in setpoint : Real;
            out fieldSetting : MagneticFluxDensity;
        }

        state ControllerStateMachine {
            entry then Idle;
            state Idle;
            state Adjusting;
            state Stable;
            state Calibrating;

            transition idleToAdjusting from Idle to Adjusting when enabled;
            transition adjustingToStable from Adjusting to Stable when (currentField == setpointField);
            transition stableToAdjusting from Stable to Adjusting when (setpointField != currentField);
            transition anyToCalibrating from Idle, Adjusting, Stable to Calibrating when calibrationNeeded;
            transition calibratingToIdle from Calibrating to Idle when !calibrationNeeded;
        }
    }

    part def OpticalCavity {
        doc 'Highly reflective mirrors that trap photons, causing amplification through interaction with subsequent electron bunches.';

        port photonIn : PhotonInPort;
        port photonOut : PhotonOutPort;
        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute mirrorReflectivity : Real := 0.9999;
        attribute cavityLength : LengthValue := 20.0;
        attribute roundTrips : Integer := 100;
        attribute amplificationFactor : Real := 1000.0;
        attribute enabled : Boolean := false;

        action amplify {
            in item : PhotonBeam;
            out item : PhotonBeam;
        }

        state CavityStateMachine {
            entry then Idle;
            state Idle;
            state Trapping;
            state Amplifying;

            transition idleToTrapping from Idle to Trapping when enabled;
            transition trappingToAmplifying from Trapping to Amplifying when (roundTrips > 1);
            transition amplifyingToIdle from Amplifying to Idle when !enabled;
        }
    }

    part def BeamlineOptics {
        doc 'Specialized mirrors and lenses that transport and focus the photon beam toward the experimental station.';

        port photonIn : PhotonInPort;
        port photonOut : PhotonOutPort;
        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute numMirrors : Integer := 5;
        attribute numLenses : Integer := 3;
        attribute focalSpotSize : SpotSize := 5.0;
        attribute enabled : Boolean := false;

        action transportAndFocus {
            in item : PhotonBeam;
            out item : PhotonBeam;
        }

        state OpticsStateMachine {
            entry then Idle;
            state Idle;
            state Active;

            transition idleToActive from Idle to Active when enabled;
            transition activeToIdle from Active to Idle when !enabled;
        }
    }

    part def BeamDump {
        doc 'A heavily shielded absorber that safely captures the spent electron beam after it exits the undulator.';

        port electronIn : ElectronInPort;
        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute shieldingThickness : LengthValue := 1.5;
        attribute coolingPower : PowerValue := 10000.0;
        attribute maxAbsorbedEnergy : ElectronEnergy := 17.0e9;
        attribute enabled : Boolean := false;

        action absorbElectrons {
            in item : ElectronBunch;
        }

        state DumpStateMachine {
            entry then Idle;
            state Idle;
            state Absorbing;
            state Cooling;

            transition idleToAbsorbing from Idle to Absorbing when enabled;
            transition absorbingToCooling from Absorbing to Cooling when (coolingPower > 5000.0);
            transition coolingToIdle from Cooling to Idle when !enabled;
        }
    }

    part def DiagnosticSystem {
        doc 'Comprehensive monitoring system for electron and photon beam properties to ensure quality, stability, and adherence to specifications.';

        port gunDiag : DiagnosticInPort;
        port linacDiag : DiagnosticInPort;
        port compressorDiag : DiagnosticInPort;
        port undulatorDiag : DiagnosticInPort;
        port dumpDiag : DiagnosticInPort;
        port cavityDiag : DiagnosticInPort;
        port beamlineDiag : DiagnosticInPort;
        port control : ControlPort;
        port dataOut : DiagnosticOutPort;

        attribute samplingRate : Real := 10.0;
        attribute lastMeasurement : DiagnosticData;
        attribute calibrationNeeded : Boolean := false;
        attribute enabled : Boolean := false;

        action monitor {
            in item : DiagnosticData;
            in item : DiagnosticData;
            out item : DiagnosticData;
        }

        state DiagnosticStateMachine {
            entry then Idle;
            state Idle;
            state Monitoring;
            state Calibrating;
            state Alarm;

            transition idleToMonitoring from Idle to Monitoring when enabled;
            transition monitoringToCalibrating from Monitoring to Calibrating when calibrationNeeded;
            transition calibratingToMonitoring from Calibrating to Monitoring when !calibrationNeeded;
            transition monitoringToAlarm from Monitoring to Alarm when (lastMeasurement.qualityOK == false);
            transition alarmToMonitoring from Alarm to Monitoring when (lastMeasurement.qualityOK == true);
        }
    }

    // ===== Top-Level FEL System =====

    part def FreeElectronLaserSystem {
        doc 'A Free-Electron Laser (FEL) that generates intense, tunable, coherent photon pulses for advanced research in materials science, chemistry, and biology.';

        port photonOut : PhotonOutPort;
        port control : ControlPort;
        port diagOut : DiagnosticOutPort;

        attribute enabled : Boolean := false;
        attribute targetWavelength : WavelengthValue := 0.1;

        part electronGun : ElectronGun;
        part linac : LinearAccelerator;
        part bunchCompressor : BunchCompressor;
        part undulator : Undulator;
        part magneticFieldController : MagneticFieldController;
        part opticalCavity : OpticalCavity;
        part beamlineOptics : BeamlineOptics;
        part beamDump : BeamDump;
        part diagnosticSystem : DiagnosticSystem;

        // Electron beam path
        connection gunToLinac from electronGun.electronOut to linac.electronIn;
        connection linacToCompressor from linac.electronOut to bunchCompressor.electronIn;
        connection compressorToUndulator from bunchCompressor.electronOut to undulator.electronIn;
        connection undulatorToDump from undulator.electronOut to beamDump.electronIn;

        // Photon beam path
        connection undulatorToCavity from undulator.photonOut to opticalCavity.photonIn;
        connection cavityToBeamline from opticalCavity.photonOut to beamlineOptics.photonIn;
        connection beamlineToOutput from beamlineOptics.photonOut to photonOut;

        // Control signal distribution
        connection controlToGun from control to electronGun.control;
        connection controlToLinac from control to linac.control;
        connection controlToCompressor from control to bunchCompressor.control;
        connection controlToUndulator from control to undulator.control;
        connection controlToMagnetController from control to magneticFieldController.control;
        connection controlToCavity from control to opticalCavity.control;
        connection controlToBeamline from control to beamlineOptics.control;
        connection controlToDump from control to beamDump.control;
        connection controlToDiagnostic from control to diagnosticSystem.control;

        // Diagnostic data collection
        connection gunDiagConn from electronGun.diagOut to diagnosticSystem.gunDiag;
        connection linacDiagConn from linac.diagOut to diagnosticSystem.linacDiag;
        connection compressorDiagConn from bunchCompressor.diagOut to diagnosticSystem.compressorDiag;
        connection undulatorDiagConn from undulator.diagOut to diagnosticSystem.undulatorDiag;
        connection dumpDiagConn from beamDump.diagOut to diagnosticSystem.dumpDiag;
        connection cavityDiagConn from opticalCavity.diagOut to diagnosticSystem.cavityDiag;
        connection beamlineDiagConn from beamlineOptics.diagOut to diagnosticSystem.beamlineDiag;
        connection diagnosticOutputConn from diagnosticSystem.dataOut to diagOut;

        // Overall system state machine
        state FELStateMachine {
            entry then Off;
            state Off;
            state Initialization;
            state WarmUp;
            state Operation;
            state Shutdown;
            state Fault;

            transition offToInit from Off to Initialization when enabled;
            transition initToWarmUp from Initialization to WarmUp when (linac.gradient > 0.0);
            transition warmUpToOperation from WarmUp to Operation when (magneticFieldController.currentField > 0.0);
            transition operationToShutdown from Operation to Shutdown when !enabled;
            transition shutdownToOff from Shutdown to Off;
            transition anyToFault from WarmUp, Operation to Fault when (diagnosticSystem.lastMeasurement.qualityOK == false);
            transition faultToOff from Fault to Off when !enabled;
        }
    }

    // ===== Requirements =====

    requirement WavelengthRangeReq {
        doc 'The FEL shall produce photon beams with wavelengths tunable from 0.1 nm to 100 nm.';
    }

    requirement BunchChargeReq {
        doc 'The Electron Gun shall produce bunches with charges between 100 and 1000 pC.';
    }

    requirement LinacEnergyReq {
        doc 'The Linac shall accelerate electrons to energies up to 17 GeV.';
    }

    requirement CompressorRatioReq {
        doc 'The Bunch Compressor shall reduce electron bunch length by a factor of at least 10.';
    }

    requirement UndulatorPeriodReq {
        doc 'The Undulator shall produce a periodic magnetic field with period of 36 mm.';
    }

    requirement MagneticControlReq {
        doc 'The Magnetic Field Controller shall adjust the undulator field with precision better than 0.01 T.';
    }

    requirement CavityAmplificationReq {
        doc 'The Optical Cavity shall amplify the photon beam through at least 100 round trips with mirror reflectivity above 0.999.';
    }

    requirement BeamlineFocusReq {
        doc 'The Beamline Optics shall focus the photon beam to a spot size smaller than 10 micrometers at the experimental station.';
    }

    requirement BeamDumpAbsorptionReq {
        doc 'The Beam Dump shall absorb spent electron beams with energies up to 17 GeV safely with shielding thickness of at least 1 meter.';
    }

    requirement DiagnosticMonitoringReq {
        doc 'The Diagnostic System shall monitor electron and photon beam properties at a sampling rate of at least 1 Hz.';
    }

    requirement CoherenceReq {
        doc 'The FEL shall produce coherent photon beams with a coherence factor above 0.9.';
    }

    requirement TunabilityReq {
        doc 'The FEL shall allow wavelength tuning by adjusting electron energy from the accelerator and magnetic field strength in the undulator.';
    }

    // ===== Satisfaction Relationships =====

    satisfaction {
        subject : FreeElectronLaserSystem;
        requirement : WavelengthRangeReq;
    }

    satisfaction {
        subject : ElectronGun;
        requirement : BunchChargeReq;
    }

    satisfaction {
        subject : LinearAccelerator;
        requirement : LinacEnergyReq;
    }

    satisfaction {
        subject : BunchCompressor;
        requirement : CompressorRatioReq;
    }

    satisfaction {
        subject : Undulator;
        requirement : UndulatorPeriodReq;
    }

    satisfaction {
        subject : MagneticFieldController;
        requirement : MagneticControlReq;
    }

    satisfaction {
        subject : OpticalCavity;
        requirement : CavityAmplificationReq;
    }

    satisfaction {
        subject : BeamlineOptics;
        requirement : BeamlineFocusReq;
    }

    satisfaction {
        subject : BeamDump;
        requirement : BeamDumpAbsorptionReq;
    }

    satisfaction {
        subject : DiagnosticSystem;
        requirement : DiagnosticMonitoringReq;
    }

    satisfaction {
        subject : FreeElectronLaserSystem;
        requirement : CoherenceReq;
    }

    satisfaction {
        subject : FreeElectronLaserSystem;
        requirement : TunabilityReq;
    }
}
