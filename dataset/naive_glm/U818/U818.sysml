package LightDetectionSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Pressure :> Real { unit 'Pa'; }
    attribute def WorkFunction :> Real { unit 'eV'; }
    attribute def SpectralSensitivity :> Real { unit 'A/W'; }
    attribute def LightIntensity :> Real { unit 'W/m2'; }
    attribute def PhotonFlux :> Real { unit '1/(m2*s)'; }
    attribute def ElectronFlux :> Real { unit '1/(m2*s)'; }
    attribute def Wavelength :> Real { unit 'nm'; }
    attribute def Area :> Real { unit 'm2'; }

    // ---- Item definitions ----
    item def Photon {
        attribute energy : Real; // eV
        attribute wavelength : Wavelength;
    }
    item def Electron;
    item def LightStream {
        item photons : Photon[0..*];
        attribute intensity : LightIntensity;
    }
    item def ElectronStream {
        item electrons : Electron[0..*];
        attribute flux : ElectronFlux;
    }

    // ---- Port definitions ----
    port def OpticalPort {
        out item light : LightStream;
    }
    port def ElectricalPort {
        out item current : Current;
        attribute voltage : Voltage;
    }
    port def ElectronCollectorPort {
        in item electrons : ElectronStream;
    }
    port def ElectronEmitterPort {
        out item electrons : ElectronStream;
    }

    // ---- Requirements ----
    requirement def DetectLightRequirement {
        subject : LightDetectionSystem;
        objective {
            doc /* The system shall detect the presence and intensity of light
                 and produce a proportional electrical current. */
        }
        require {
            subject.outputCurrent >= 0 [A];
            subject.outputCurrent proportionalTo subject.incidentLightIntensity;
        }
    }

    requirement def VacuumRequirement {
        subject : VacuumEnvelope;
        require {
            subject.internalPressure <= 1.0e-6 [Pa];
        }
    }

    requirement def BiasRequirement {
        subject : BiasSupply;
        require {
            subject.outputVoltage >= 50 [V];
        }
    }

    requirement def StateBehaviorRequirement {
        subject : LightDetectionSystem;
        require {
            subject.state == 'standby' when subject.incidentLightIntensity == 0 [W/m2];
            subject.state == 'active' when subject.incidentLightIntensity > 0 [W/m2];
        }
    }

    // ---- Part definitions ----
    part def OpticalSource {
        port opticalOut : OpticalPort;
        attribute emittedIntensity : LightIntensity := 0 [W/m2];
        attribute peakWavelength : Wavelength := 550 [nm];

        action def EmitLight :> Action {
            out light : LightStream;
        }
        perform action emitLight : EmitLight {
            out light = opticalOut.light;
        }
    }

    part def VacuumEnvelope {
        attribute internalPressure : Pressure := 1.0e-7 [Pa];
        satisfy VacuumRequirement {
            subject = VacuumEnvelope::self;
        }
    }

    part def Photocathode {
        port opticalIn : OpticalPort;
        port electronOut : ElectronEmitterPort;
        attribute workFunction : WorkFunction := 2.0 [eV];
        attribute spectralSensitivity : SpectralSensitivity := 0.05 [A/W];
        attribute activeArea : Area := 1.0e-4 [m2];

        action def EmitElectrons :> Action {
            in light : LightStream;
            out electrons : ElectronStream;
        }
        perform action emitElectrons : EmitElectrons {
            in light = opticalIn.light;
            out electrons = electronOut.electrons;
        }
    }

    part def Anode {
        port electronIn : ElectronCollectorPort;
        port electricalOut : ElectricalPort;
        attribute collectedCurrent : Current := 0 [A];

        action def CollectElectrons :> Action {
            in electrons : ElectronStream;
            out current : Current;
        }
        perform action collectElectrons : CollectElectrons {
            in electrons = electronIn.electrons;
            out current = electricalOut.current;
        }
    }

    part def BiasSupply {
        port positiveTerminal : ElectricalPort;
        port negativeTerminal : ElectricalPort;
        attribute outputVoltage : Voltage := 100 [V];
        satisfy BiasRequirement {
            subject = BiasSupply::self;
        }
    }

    part def CurrentMeter {
        port electricalIn : ElectricalPort;
        attribute measuredCurrent : Current := 0 [A];

        action def MeasureCurrent :> Action {
            in current : Current;
        }
        perform action measureCurrent : MeasureCurrent {
            in current = electricalIn.current;
        }
    }

    part def Phototube {
        part envelope : VacuumEnvelope;
        part photocathode : Photocathode;
        part anode : Anode;

        port opticalInput : OpticalPort;
        port electricalOutput : ElectricalPort;
        port biasPositive : ElectricalPort;
        port biasNegative : ElectricalPort;

        connection opticalPath : OpticalPort connect opticalInput to photocathode.opticalIn;
        connection electronPath : ElectronEmitterPort connect photocathode.electronOut to anode.electronIn;
        connection anodeOutput : ElectricalPort connect anode.electricalOut to electricalOutput;
        connection biasPosConn : ElectricalPort connect biasPositive to anode.electricalOut;
        connection biasNegConn : ElectricalPort connect biasNegative to photocathode.electronOut;

        attribute incidentLightIntensity : LightIntensity := 0 [W/m2];
        attribute outputCurrent : Current := 0 [A];

        state def PhototubeState {
            entry; exit;
        }
        state machine PhototubeStateMachine {
            state standby {
                entry { /* No light present, no current produced */ }
            }
            state active {
                entry { /* Light detected, performing light-to-current conversion */ }
                do {
                    /* Continuously convert incident photons to photocurrent */
                }
            }
            transition standby_to_active first standby to active
                when incidentLightIntensity > 0 [W/m2];
            transition active_to_standby first active to standby
                when incidentLightIntensity == 0 [W/m2];
        }
        exhibit stateBehavior : PhototubeStateMachine;
    }

    part def LightDetectionSystem {
        part opticalSource : OpticalSource;
        part phototube : Phototube;
        part biasSupply : BiasSupply;
        part currentMeter : CurrentMeter;

        attribute incidentLightIntensity : LightIntensity := 0 [W/m2];
        attribute outputCurrent : Current := 0 [A];
        attribute state : String := "standby";

        connection sourceToTube : OpticalPort connect opticalSource.opticalOut to phototube.opticalInput;
        connection biasPositiveConn : ElectricalPort connect biasSupply.positiveTerminal to phototube.biasPositive;
        connection biasNegativeConn : ElectricalPort connect biasSupply.negativeTerminal to phototube.biasNegative;
        connection tubeToMeter : ElectricalPort connect phototube.electricalOutput to currentMeter.electricalIn;

        satisfy DetectLightRequirement {
            subject = LightDetectionSystem::self;
        }
        satisfy StateBehaviorRequirement {
            subject = LightDetectionSystem::self;
        }

        action def Operate :> Action {
            in light : LightStream;
            out current : Current;
        }
        perform action operate : Operate {
            in light = opticalSource.opticalOut.light;
            out current = currentMeter.electricalIn.current;
        }
    }
}
