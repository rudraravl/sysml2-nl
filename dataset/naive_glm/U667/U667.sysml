package EDS_System {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Units ----
    unit keV;
    unit nA;
    unit Pa;
    unit um;
    unit K;
    unit percent;
    unit counts;
    unit MHz;

    // ---- Value Types ----
    value def ElectronEnergy :> Real { unit keV; }
    value def BeamCurrent :> Real { unit nA; }
    value def VacuumPressure :> Real { unit Pa; }
    value def XRayEnergy :> Real { unit keV; }
    value def PhotonCount :> Integer;
    value def Intensity :> Real { unit counts; }
    value def Concentration :> Real { unit percent; }
    value def SpatialResolution :> Real { unit um; }
    value def Temperature :> Real { unit K; }
    value def SamplingRate :> Real { unit MHz; }

    // ---- Item Definitions ----
    item def ElectronBeam {
        attribute energy : ElectronEnergy;
        attribute current : BeamCurrent;
        attribute focusDiameter : SpatialResolution;
    }

    item def MaterialSample {
        attribute sampleId : String;
        attribute description : String;
        attribute baseMaterial : String;
    }

    item def XRayPhoton {
        attribute energy : XRayEnergy;
        attribute timestamp : Real;
    }

    item def EnergyBin {
        attribute energy : XRayEnergy;
        attribute intensity : Intensity;
    }

    item def EnergySpectrum {
        attribute bins : EnergyBin[0..*];
        attribute acquisitionTime : Real;
    }

    item def ElementalConcentration {
        attribute element : String;
        attribute atomicNumber : Integer;
        attribute weightPercent : Concentration;
        attribute atomicPercent : Concentration;
    }

    item def AnalysisReport {
        attribute sampleId : String;
        attribute results : ElementalConcentration[0..*];
        attribute timestamp : String;
        attribute operator : String;
    }

    // ---- Interface Definitions ----
    interface def ElectronBeamFlow {
        end beam : ElectronBeam;
    }

    interface def XRayFlow {
        end photons : XRayPhoton[0..*];
    }

    interface def SpectrumFlow {
        end spectrum : EnergySpectrum;
    }

    interface def ReportFlow {
        end report : AnalysisReport;
    }

    // ---- Part Definitions ----
    part def ElectronGun {
        attribute acceleratingVoltage : ElectronEnergy;
        attribute emissionCurrent : BeamCurrent;
        attribute minFocusDiameter : SpatialResolution;

        port out beamOut : ElectronBeamFlow;

        action def GenerateBeam {
            in voltage : ElectronEnergy;
            in current : BeamCurrent;
            out beam : ElectronBeam;
        }

        perform generateBeam : GenerateBeam {
            in voltage = acceleratingVoltage;
            in current = emissionCurrent;
        }
    }

    part def SampleChamber {
        attribute vacuumPressure : VacuumPressure;
        attribute temperature : Temperature;
        attribute sample : MaterialSample;

        port in beamIn : ElectronBeamFlow;
        port out xrayOut : XRayFlow;

        action def ExciteSample {
            in beam : ElectronBeam;
            in sample : MaterialSample;
            out photons : XRayPhoton[0..*];
        }

        perform exciteSample : ExciteSample {
            in beam = beamIn.beam;
            in sample = sample;
        }
    }

    part def SiliconDriftDetector {
        attribute detectionArea : Real;
        attribute energyResolution : XRayEnergy;
        attribute operatingTemperature : Temperature;
        attribute deadTimeFraction : Real;

        port in xrayIn : XRayFlow;
        port out signalOut : XRayFlow;

        action def DetectPhotons {
            in photons : XRayPhoton[0..*];
            out detected : XRayPhoton[0..*];
        }

        perform detectPhotons : DetectPhotons {
            in photons = xrayIn.photons;
        }
    }

    part def DigitalSignalProcessor {
        attribute samplingRate : SamplingRate;
        attribute processingChannels : Integer;
        attribute energyRange : XRayEnergy;

        port in signalIn : XRayFlow;
        port out spectrumOut : SpectrumFlow;

        action def ProcessSignal {
            in photons : XRayPhoton[0..*];
            out spectrum : EnergySpectrum;
        }

        perform processSignal : ProcessSignal {
            in photons = signalIn.photons;
        }
    }

    part def AnalysisWorkstation {
        attribute softwareVersion : String;
        attribute zafCorrectionEnabled : Boolean;

        port in spectrumIn : SpectrumFlow;
        port out reportOut : ReportFlow;

        action def IdentifyPeaks {
            in spectrum : EnergySpectrum;
            out elements : String[0..*];
        }

        action def ApplyZAFCorrection {
            in rawConcentrations : ElementalConcentration[0..*];
            out correctedConcentrations : ElementalConcentration[0..*];
        }

        action def GenerateReport {
            in concentrations : ElementalConcentration[0..*];
            in sampleId : String;
            out report : AnalysisReport;
        }

        perform analyzeSpectrum : IdentifyPeaks {
            in spectrum = spectrumIn.spectrum;
        }

        perform applyZAF : ApplyZAFCorrection;

        perform generateReport : GenerateReport;
    }

    // ---- Top-Level EDS System ----
    part def EDSSystem {
        attribute systemId : String;
        attribute spatialResolution : SpatialResolution;

        part electronGun : ElectronGun {
            attribute acceleratingVoltage = 20.0 [keV];
            attribute emissionCurrent = 1.0 [nA];
            attribute minFocusDiameter = 0.5 [um];
        }

        part sampleChamber : SampleChamber {
            attribute vacuumPressure = 1.0e-5 [Pa];
            attribute temperature = 293.0 [K];
        }

        part sdd : SiliconDriftDetector {
            attribute detectionArea = 30.0;
            attribute energyResolution = 0.125 [keV];
            attribute operatingTemperature = 223.0 [K];
            attribute deadTimeFraction = 0.05;
        }

        part dsp : DigitalSignalProcessor {
            attribute samplingRate = 100.0 [MHz];
            attribute processingChannels = 8;
            attribute energyRange = 40.0 [keV];
        }

        part workstation : AnalysisWorkstation {
            attribute softwareVersion = "EDS-Analyze v3.2";
            attribute zafCorrectionEnabled = true;
        }

        // ---- Connections ----
        connection beamLink : ElectronBeamFlow
            connect electronGun.beamOut to sampleChamber.beamIn;

        connection xrayLink : XRayFlow
            connect sampleChamber.xrayOut to sdd.xrayIn;

        connection signalLink : XRayFlow
            connect sdd.signalOut to dsp.signalIn;

        connection spectrumLink : SpectrumFlow
            connect dsp.spectrumOut to workstation.spectrumIn;

        // ---- Operational State Machine ----
        state def EDSOperationalStates {
            entry; then standby;

            state standby {
                entry {
                    doc "System powered but idle, electron gun off.";
                }
            }

            state systemSetup {
                entry {
                    doc "Pump down chamber, load sample, configure beam parameters.";
                }
            }

            state dataAcquisition {
                entry {
                    doc "Electron beam active, detector collecting X-ray photons.";
                }
            }

            state dataProcessing {
                entry {
                    doc "DSP converts photon stream into energy spectrum.";
                }
            }

            state reporting {
                entry {
                    doc "Workstation identifies elements, applies ZAF, generates report.";
                }
            }

            transition standby to systemSetup
                when electronGun.acceleratingVoltage > 0.0 [keV];

            transition systemSetup to dataAcquisition
                when sampleChamber.vacuumPressure < 1.0e-4 [Pa];

            transition dataAcquisition to dataProcessing
                when sdd.deadTimeFraction < 0.5;

            transition dataProcessing to reporting
                when dsp.spectrumOut.spectrum.bins->size() > 0;

            transition reporting to standby
                when workstation.reportOut.report.results->size() > 0;
        }

        state machine operationalStates : EDSOperationalStates;
    }

    // ---- Requirements ----
    requirement def HighVacuumRequirement {
        subject chamber : SampleChamber;
        objective {
            doc "The sample chamber shall maintain a high vacuum to prevent interference during analysis."
        }
        constraint { chamber.vacuumPressure < 1.0e-4 [Pa] }
    }

    requirement def SpatialResolutionRequirement {
        subject system : EDSSystem;
        objective {
            doc "The system shall achieve high spatial resolution to analyze features smaller than a micrometer."
        }
        constraint { system.electronGun.minFocusDiameter < 1.0 [um] }
    }

    requirement def EnergyResolutionRequirement {
        subject detector : SiliconDriftDetector;
        objective {
            doc "The SDD shall resolve X-ray energies with sufficient precision for elemental fingerprint identification."
        }
        constraint { detector.energyResolution < 0.15 [keV] }
    }

    requirement def ElementalIdentificationRequirement {
        subject ws : AnalysisWorkstation;
        objective {
            doc "The workstation shall identify energy peaks to determine elements present and quantify concentrations using ZAF correction."
        }
        constraint { ws.zafCorrectionEnabled == true }
    }

    requirement def OperationalSequenceRequirement {
        subject system : EDSSystem;
        objective {
            doc "The system shall follow a defined operational sequence: standby, setup, acquisition, processing, reporting."
        }
        constraint { system.operationalStates.owningStateMetaclass == EDSOperationalStates }
    }

    // ---- Requirement Satisfaction ----
    satisfaction highVacuumSatisfaction : HighVacuumRequirement {
        subject chamberRef : EDSSystem::sampleChamber;
    }

    satisfaction spatialResolutionSatisfaction : SpatialResolutionRequirement {
        subject systemRef : EDSSystem;
    }

    satisfaction energyResolutionSatisfaction : EnergyResolutionRequirement {
        subject detectorRef : EDSSystem::sdd;
    }

    satisfaction elementalIdentificationSatisfaction : ElementalIdentificationRequirement {
        subject wsRef : EDSSystem::workstation;
    }
}
