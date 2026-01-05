package FreeElectronLaserSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def ElectronBeam {
        attribute beamEnergy :> ISQ::energy;
        attribute beamCurrent :> ISQ::electricCurrent;
        attribute emittance :> ISQ::length;
        attribute bunchCharge :> ISQ::electricCharge;
        attribute repetitionRate :> ISQ::frequency;
    }

    item def PhotonBeam {
        attribute wavelength :> ISQ::length;
        attribute photonEnergy :> ISQ::energy;
        attribute pulseEnergy :> ISQ::energy;
        attribute pulseDuration :> ISQ::time;
        attribute photonFlux :> Real;
        attribute peakPower :> ISQ::power;
        attribute averagePower :> ISQ::power;
    }

    item def MagneticField {
        attribute fieldStrength :> ISQ::magneticFluxDensity;
        attribute undulatorPeriod :> ISQ::length;
        attribute undulatorK :> Real;
        attribute numberOfPeriods :> Real;
    }

    attribute def WavelengthRequest;
    attribute def ShutdownCommand;
    attribute def WavelengthAdjustment;

    part def ElectronGun {
        out port electronOutput : ElectronBeam;
        attribute cathodeVoltage :> ISQ::voltage;
        attribute emissionCurrent :> ISQ::electricCurrent;
        perform action emitElectrons {
            out eBeam : ElectronBeam;
        }
    }

    part def LinearAccelerator {
        in port electronInput : ElectronBeam;
        out port electronOutput : ElectronBeam;
        attribute accelerationGradient :> Real;
        attribute targetEnergy :> ISQ::energy;
        attribute rfFrequency :> ISQ::frequency;
        perform action accelerateBeam {
            in eBeamIn : ElectronBeam;
            out eBeamOut : ElectronBeam;
        }
    }

    part def BunchCompressor {
        in port electronInput : ElectronBeam;
        out port electronOutput : ElectronBeam;
        attribute compressionFactor :> Real;
        perform action compressBunch {
            in eBeamIn : ElectronBeam;
            out eBeamOut : ElectronBeam;
        }
    }

    part def Undulator {
        in port electronInput : ElectronBeam;
        in port magneticFieldInput : MagneticField;
        out port photonOutput : PhotonBeam;
        out port electronOutput : ElectronBeam;
        attribute undulatorLength :> ISQ::length;
        attribute numberOfPeriods :> Real;
        perform action generateRadiation {
            in electrons : ElectronBeam;
            in magneticField : MagneticField;
            out photons : PhotonBeam;
            out spentElectrons : ElectronBeam;
        }
    }

    part def OpticalCavity {
        in port photonInput : PhotonBeam;
        out port photonOutput : PhotonBeam;
        attribute cavityLength :> ISQ::length;
        attribute mirrorReflectivity :> Real;
        attribute qualityFactor :> Real;
        perform action amplifyRadiation {
            in photonsIn : PhotonBeam;
            out photonsOut : PhotonBeam;
        }
    }

    part def BeamDump {
        in port electronInput : ElectronBeam;
        attribute absorptionCapacity :> ISQ::power;
        attribute coolingCapacity :> ISQ::power;
        perform action absorbBeam {
            in electrons : ElectronBeam;
        }
    }

    part def BeamlineOptics {
        in port photonInput : PhotonBeam;
        out port photonOutput : PhotonBeam;
        attribute focusingStrength :> Real;
        attribute transmissionEfficiency :> Real;
        perform action transportPhotons {
            in photonsIn : PhotonBeam;
            out photonsOut : PhotonBeam;
        }
    }

    part def DiagnosticSystem {
        in port electronMonitor : ElectronBeam;
        in port photonMonitor : PhotonBeam;
        attribute beamQuality :> Real;
        attribute wavelengthStability :> Real;
        perform action monitorBeams {
            in electrons : ElectronBeam;
            in photons : PhotonBeam;
            out qualityMetrics : Real;
            out stabilityMetrics : Real;
        }
    }

    part def MagneticFieldController {
        out port fieldOutput : MagneticField;
        attribute targetWavelength :> ISQ::length;
        perform action configureMagneticField {
            in targetWavelength : ISQ::length;
            out magneticField : MagneticField;
        }
    }

    action def ProduceCoherentRadiation {
        in initialElectrons : ElectronBeam;
        in targetWavelength : ISQ::length;
        out coherentPhotons : PhotonBeam;
    }

    action def TuneWavelength {
        in desiredWavelength : ISQ::length;
        in currentBeamEnergy : ISQ::energy;
        out adjustedEnergy : ISQ::energy;
        out adjustedField : MagneticField;
    }

    part def FreeElectronLaser {
        doc /*
            A Free-Electron Laser (FEL) system generates tunable, coherent electromagnetic radiation
            by passing relativistic electron beams through a periodic magnetic structure (undulator).
            The electrons oscillate in the magnetic field and emit synchrotron radiation that can be
            amplified through stimulated emission, producing intense, coherent light pulses across
            a wide spectral range from infrared to X-rays.
        */

        attribute operatingWavelength :> ISQ::length;
        attribute peakPower :> ISQ::power;
        attribute averagePower :> ISQ::power;
        attribute repetitionRate :> ISQ::frequency;
        attribute pulseEnergy :> ISQ::energy;

        part electronGun : ElectronGun;
        part linac : LinearAccelerator;
        part compressor : BunchCompressor;
        part undulator : Undulator;
        part opticalCavity : OpticalCavity;
        part beamDump : BeamDump;
        part beamline : BeamlineOptics;
        part diagnostics : DiagnosticSystem;
        part fieldController : MagneticFieldController;

        connect electronGun.electronOutput to linac.electronInput;
        connect linac.electronOutput to compressor.electronInput;
        connect compressor.electronOutput to undulator.electronInput;
        connect fieldController.fieldOutput to undulator.magneticFieldInput;
        connect undulator.photonOutput to opticalCavity.photonInput;
        connect opticalCavity.photonOutput to beamline.photonInput;
        connect undulator.electronOutput to beamDump.electronInput;
        connect compressor.electronOutput to diagnostics.electronMonitor;
        connect beamline.photonOutput to diagnostics.photonMonitor;

        perform action generateCoherentLight : ProduceCoherentRadiation {
            in initialElectrons;
            in targetWavelength = operatingWavelength;
            out coherentPhotons;

            first start;
            then action emit references electronGun.emitElectrons {
                out eBeam;
            }
            then action accelerate references linac.accelerateBeam {
                in eBeamIn = emit.eBeam;
                out eBeamOut;
            }
            then action compress references compressor.compressBunch {
                in eBeamIn = accelerate.eBeamOut;
                out eBeamOut;
            }
            then action configureField references fieldController.configureMagneticField {
                in targetWavelength = targetWavelength;
                out magneticField;
            }
            then action radiate references undulator.generateRadiation {
                in electrons = compress.eBeamOut;
                in magneticField = configureField.magneticField;
                out photons;
                out spentElectrons;
            }
            then action amplify references opticalCavity.amplifyRadiation {
                in photonsIn = radiate.photons;
                out photonsOut;
            }
            then action transport references beamline.transportPhotons {
                in photonsIn = amplify.photonsOut;
                out photonsOut;
            }
            then action monitor references diagnostics.monitorBeams {
                in electrons = radiate.spentElectrons;
                in photons = transport.photonsOut;
                out qualityMetrics;
                out stabilityMetrics;
            }
            then action dispose references beamDump.absorbBeam {
                in electrons = radiate.spentElectrons;
            }
            then assign coherentPhotons := transport.photonsOut;
            then done;
        }

        state operationalStates {
            entry; then idle;

            state idle {
                entry assign operatingWavelength := 0.0[nm];
            }

            transition idle_to_tuning
                first idle
                accept wavelengthReq : WavelengthRequest
                then tuning;

            state tuning {
                do action tuneWavelengthAction : TuneWavelength {
                    in desiredWavelength;
                    in currentBeamEnergy;
                    out adjustedEnergy;
                    out adjustedField;
                }
            }

            transition tuning_to_generating
                first tuning
                if tuneWavelengthAction.adjustedEnergy > 0.0[J]
                then generating;

            state generating {
                do action generateCoherentLight;
            }

            transition generating_to_idle
                first generating
                accept shutdownCmd : ShutdownCommand
                then idle;

            transition generating_to_tuning
                first generating
                accept wavelengthAdj : WavelengthAdjustment
                then tuning;
        }
    }

    requirement def CoherentRadiationRequirement {
        doc /* The FEL shall produce intense, coherent electromagnetic radiation. */
        subject fel : FreeElectronLaser;
        require constraint {
            fel.peakPower > 1.0e9[W]
        }
    }

    requirement def WavelengthTunabilityRequirement {
        doc /* The FEL shall be tunable across a wide wavelength range. */
        subject fel : FreeElectronLaser;
        require constraint {
            fel.operatingWavelength >= 0.1[nm] and
            fel.operatingWavelength <= 1000.0[nm]
        }
    }

    requirement def BeamQualityRequirement {
        doc /* The FEL shall maintain high beam quality and coherence. */
        subject fel : FreeElectronLaser;
        require constraint {
            fel.diagnostics.beamQuality > 0.90
        }
    }

    requirement def PulseEnergyRequirement {
        doc /* The FEL shall deliver sufficient pulse energy for applications. */
        subject fel : FreeElectronLaser;
        require constraint {
            fel.pulseEnergy > 1.0e-3[J]
        }
    }

    requirement <'FEL-001'> primaryMissionRequirement : CoherentRadiationRequirement {
        doc /*
            The Free-Electron Laser system shall generate tunable, intense, coherent
            electromagnetic radiation by accelerating electrons to relativistic energies
            and passing them through a periodic magnetic undulator structure where they
            emit synchrotron radiation amplified through stimulated emission.
        */

        assume constraint electronBeamAvailable {
            fel.linac.targetEnergy >= 0.1[J]
        }

        assume constraint magneticFieldConfigured {
            fel.undulator.magneticFieldInput.fieldStrength > 0.0[T]
        }

        require wavelengthTunabilityReq : WavelengthTunabilityRequirement;
        require beamQualityReq : BeamQualityRequirement;
        require pulseEnergyReq : PulseEnergyRequirement;
    }

    part fel : FreeElectronLaser {
        :>> operatingWavelength = 10.0[nm];
        :>> peakPower = 5.0e9[W];
        :>> averagePower = 100.0[W];
        :>> repetitionRate = 120.0[Hz];
        :>> pulseEnergy = 0.833[J];

        satisfy primaryMissionRequirement;
    }
}
