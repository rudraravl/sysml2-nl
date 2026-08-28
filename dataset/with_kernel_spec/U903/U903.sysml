package SAR_System {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    attribute def RadarPulse {
        attribute frequency : FrequencyValue;
        attribute duration : TimeValue;
        attribute power : PowerValue;
    }

    attribute def EchoData {
        attribute amplitude : Real;
        attribute phase : Real;
        attribute timestamp : TimeValue;
    }

    attribute def NavigationData {
        attribute position : LengthValue;
        attribute velocity : SpeedValue;
        attribute orientation : AngleValue;
        attribute timestamp : TimeValue;
    }

    attribute def ProcessedImage {
        attribute resolution : LengthValue;
        attribute swathWidth : LengthValue;
        attribute geolocation : LengthValue;
    }

    enum def ImagingMode {
        StripMap;
        Spotlight;
        ScanSAR;
    }

    attribute def SigPowerOn;
    attribute def SigPowerOff;
    attribute def SigStartImaging;
    attribute def SigStopImaging;
    attribute def SigModeSpotlight;
    attribute def SigModeScanSAR;
    attribute def SigModeStripMap;

    part def TransmitReceiveModule {
        port timingSync { in attribute timing : TimeValue; }
        port powerIn { in attribute power : PowerValue; }
        port radarPulseOut { out attribute pulse : RadarPulse; }
        port echoIn { in attribute echo : EchoData; }
        port rawEchoOut { out attribute rawEcho : EchoData; }

        perform action TransmitPulse {
            in mode : ImagingMode;
            out pulse : RadarPulse;
            first start;
            then action generateWaveform;
            then action amplify;
            then done;
        }
        perform action ReceiveEcho {
            in signal : EchoData;
            out data : EchoData;
            first start;
            then action downconvert;
            then action digitize;
            then done;
        }
    }

    part def Antenna {
        port pulseIn { in attribute pulse : RadarPulse; }
        port echoOut { out attribute echo : EchoData; }
        attribute gain : Real;
        attribute beamwidth : AngleValue;
    }

    part def PlatformNavigationSystem {
        part gps;
        part inertialSensor;
        port navDataOut { out attribute navData : NavigationData; }
        perform action RecordMotion {
            out data : NavigationData;
            first start;
            then action readGPS;
            then action readIMU;
            then action fuseData;
            then done;
        }
    }

    part def DataStorage {
        port rawEchoIn { in attribute rawEcho : EchoData; }
        port navDataIn { in attribute navData : NavigationData; }
        port storedEchoOut { out attribute storedEcho : EchoData; }
        port storedNavDataOut { out attribute storedNavData : NavigationData; }
        attribute capacity : Real;
        perform action StoreData {
            in echo : EchoData;
            in motion : NavigationData;
            out storedEcho : EchoData;
            out storedNavData : NavigationData;
        }
    }

    part def SignalProcessor {
        port echoDataIn { in attribute echoData : EchoData; }
        port focusedDataOut { out attribute focusedData : EchoData; }
        perform action CompressData {
            in raw : EchoData;
            out focused : EchoData;
            first start;
            then action rangeCompression;
            then action azimuthCompression;
            then done;
        }
    }

    part def ImageFormationProcessor {
        port focusedDataIn { in attribute focusedData : EchoData; }
        port navDataIn { in attribute navData : NavigationData; }
        port finalImageOut { out attribute finalImage : ProcessedImage; }
        perform action FormImage {
            in focused : EchoData;
            in nav : NavigationData;
            out image : ProcessedImage;
            first start;
            then action motionCompensation;
            then action assembleImage;
            then action radiometricCalibration;
            then done;
        }
    }

    part def PowerSupply {
        port powerOut { out attribute power : PowerValue; }
        attribute voltage : Real;
        attribute maxPower : PowerValue;
    }

    part def TimingUnit {
        port timingSignalOut { out attribute timingSignal : TimeValue; }
        attribute stability : Real;
        perform action GenerateClock {
            out clock : TimeValue;
        }
    }

    part def SAR {
        attribute imagingMode : ImagingMode;

        part trm : TransmitReceiveModule;
        part antenna : Antenna;
        part navSystem : PlatformNavigationSystem;
        part storage : DataStorage;
        part signalProc : SignalProcessor;
        part imageProc : ImageFormationProcessor;
        part power : PowerSupply;
        part timing : TimingUnit;

        connect power.powerOut to trm.powerIn;
        connect timing.timingSignalOut to trm.timingSync;
        connect trm.radarPulseOut to antenna.pulseIn;
        connect antenna.echoOut to trm.echoIn;
        connect trm.rawEchoOut to storage.rawEchoIn;
        connect navSystem.navDataOut to storage.navDataIn;
        connect storage.storedEchoOut to signalProc.echoDataIn;
        connect signalProc.focusedDataOut to imageProc.focusedDataIn;
        connect storage.storedNavDataOut to imageProc.navDataIn;

        state sarOperation {
            entry; then Off;
            state Off;
            accept SigPowerOn then Standby;
            state Standby;
            accept SigStartImaging then Imaging;
            accept SigPowerOff then Off;
            state Imaging {
                entry; then StripMap;
                state StripMap;
                transition first StripMap accept SigModeSpotlight then Spotlight;
                state Spotlight;
                transition first Spotlight accept SigModeScanSAR then ScanSAR;
                state ScanSAR;
                transition first ScanSAR accept SigModeStripMap then StripMap;
            }
            accept SigStopImaging then Standby;
        }

        perform action ProcessingPipeline {
            in raw : EchoData;
            in nav : NavigationData;
            out image : ProcessedImage;
            first start;
            then action storeData {
                in echo : EchoData = raw;
                in motion : NavigationData = nav;
                out storedEcho : EchoData;
                out storedNavData : NavigationData;
            }
            then action compress {
                in echo : EchoData = storeData.storedEcho;
                out focused : EchoData;
            }
            then action formImage {
                in focused : EchoData = compress.focused;
                in motion : NavigationData = storeData.storedNavData;
                out result : ProcessedImage;
            }
            then done;
        }
    }

    requirement def SAR_Requirements {
        requirement OperationalCapability {
            doc /* The SAR system shall operate day or night and through clouds. */
        }
        requirement ResolutionRequirement {
            doc /* The system shall achieve high resolution imaging. */
            attribute minResolution : LengthValue = 1 [m];
        }
        requirement ModeRequirement {
            doc /* The system shall support StripMap, Spotlight, and ScanSAR modes. */
        }
    }
}
