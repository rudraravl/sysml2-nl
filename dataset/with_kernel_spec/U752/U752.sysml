package LASH_System_Model {
    private import ScalarValues::*;
    private import ISQ::*;

    item def Scene;
    item def SyncSignal;
    item def FocusedLight {
        attribute radiance : Real;
    }
    item def DispersedSpectrum {
        attribute wavelengthMin : Real;
        attribute wavelengthMax : Real;
        attribute intensity : Real;
    }
    item def RawSpectralFrame {
        attribute frameId : Integer;
        attribute pixelData : Real[*];
    }
    item def CalibrationData {
        attribute darkOffset : Real[*];
        attribute flatField : Real[*];
    }
    item def HyperspectralDataCube {
        attribute spatialDimX : Integer;
        attribute spatialDimY : Integer;
        attribute spectralBands : Integer;
        attribute dataValues : Real[*];
    }

    attribute def PowerOn;
    attribute def InitComplete;
    attribute def CalibComplete;
    attribute def StartScan;
    attribute def ScanComplete;
    attribute def ProcessComplete;
    attribute def Recalibrate;
    attribute def PowerOff;

    action def Initialize;
    action def SelfCalibrate;
    action def Scan;
    action def ProcessData;

    action def Focus {
        in item scene : Scene;
        out item focusedLight : FocusedLight;
    }
    action def Disperse {
        in item focusedLight : FocusedLight;
        out item dispersedSpectrum : DispersedSpectrum;
    }
    action def Capture {
        in item dispersedSpectrum : DispersedSpectrum;
        out item rawFrame : RawSpectralFrame;
    }
    action def Process {
        in item rawFrame : RawSpectralFrame;
        in item calib : CalibrationData;
        out item dataCube : HyperspectralDataCube;
    }

    action def AcquireHyperspectralData {
        in item scene : Scene;
        in item calib : CalibrationData;
        out item dataCube : HyperspectralDataCube;

        action focus : Focus {
            in item scene = AcquireHyperspectralData::scene;
            out item focusedLight;
        }
        flow focus.focusedLight to disperse.focusedLight;
        action disperse : Disperse {
            in item focusedLight;
            out item dispersedSpectrum;
        }
        flow disperse.dispersedSpectrum to capture.dispersedSpectrum;
        action capture : Capture {
            in item dispersedSpectrum;
            out item rawFrame;
        }
        flow capture.rawFrame to process.rawFrame;
        action process : Process {
            in item rawFrame;
            in item calib = AcquireHyperspectralData::calib;
            out item dataCube = AcquireHyperspectralData::dataCube;
        }
    }

    part def OpticalSubsystem {
        in item scene : Scene;
        out item focusedLight : FocusedLight;
    }
    part def SpectrographicDispersiveElement {
        attribute elementType : String = "Prism-Grating";
        in item focusedLight : FocusedLight;
        out item dispersedSpectrum : DispersedSpectrum;
    }
    part def FocalPlaneArray {
        attribute detectorMaterial : String = "HgCdTe";
        attribute operatingTemperature : Real;
        in item dispersedSpectrum : DispersedSpectrum;
        in item syncSignal : SyncSignal;
        out item rawFrame : RawSpectralFrame;
    }
    part def ScanMechanism {
        attribute scanTechnique : String = "Pushbroom";
        attribute platformGroundSpeed : Real;
        out item syncSignal : SyncSignal;
    }
    part def CalibrationSubsystem {
        out item calibrationData : CalibrationData;
    }
    part def SignalProcessingUnit {
        in item rawFrame : RawSpectralFrame;
        in item calibrationData : CalibrationData;
        in item syncSignal : SyncSignal;
        out item dataCube : HyperspectralDataCube;
    }

    state def LASH_Operation {
        entry; then PoweredOff;
        state PoweredOff;
        transition first PoweredOff accept PowerOn then Initializing;

        state Initializing {
            do action initAct : Initialize;
        }
        transition first Initializing accept InitComplete then Calibrating;

        state Calibrating {
            do action calibAct : SelfCalibrate;
        }
        transition first Calibrating accept CalibComplete then Ready;

        state Ready;
        transition first Ready accept StartScan then Scanning;

        state Scanning {
            do action scanAct : Scan;
        }
        transition first Scanning accept ScanComplete then Processing;

        state Processing {
            do action procAct : ProcessData;
        }
        transition first Processing accept ProcessComplete then Ready;

        transition first Ready accept Recalibrate then Calibrating;
        transition first Ready accept PowerOff then PoweredOff;
    }

    part def LASH_System {
        in item scene : Scene;
        out item dataCube : HyperspectralDataCube;

        part optical : OpticalSubsystem {
            in item scene = LASH_System::scene;
        }
        part dispersive : SpectrographicDispersiveElement;
        part fpa : FocalPlaneArray;
        part scan : ScanMechanism;
        part calib : CalibrationSubsystem;
        part spu : SignalProcessingUnit {
            out item dataCube = LASH_System::dataCube;
        }

        flow optical.focusedLight to dispersive.focusedLight;
        flow dispersive.dispersedSpectrum to fpa.dispersedSpectrum;
        flow scan.syncSignal to fpa.syncSignal;
        flow scan.syncSignal to spu.syncSignal;
        flow calib.calibrationData to spu.calibrationData;
        flow fpa.rawFrame to spu.rawFrame;

        state operation : LASH_Operation;
    }

    part lashSystem : LASH_System;

    requirement def HyperspectralImagingRequirement {
        doc /* The LASH system shall capture images in hundreds of spectral bands from visible to shortwave infrared. */
        attribute minSpectralBands : Integer = 200;
        attribute wavelengthMinNm : Real = 400;
        attribute wavelengthMaxNm : Real = 2500;
    }

    requirement def AtmosphericCorrectionRequirement {
        doc /* The signal processing unit shall apply complex corrections for atmospheric effects and sensor characteristics. */
    }

    requirement def LifecycleRequirement {
        doc /* Upon power-up, the system shall initialize and self-calibrate, then enter a standby ready state, returning to ready after processing. */
    }

    requirement hyperspectralReq : HyperspectralImagingRequirement;
    requirement atmosphericReq : AtmosphericCorrectionRequirement;
    requirement lifecycleReq : LifecycleRequirement;
}
