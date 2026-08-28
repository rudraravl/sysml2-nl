package LightDetectionSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ISQ::IlluminanceValue;
    private import ISQ::ElectricCurrentValue;
    private import ISQ::ElectricPotentialValue;
    private import ISQ::PressureValue;
    private import ISQ::EnergyValue;

    attribute def LightIntensity :> IlluminanceValue;
    attribute def PhotocurrentValue :> ElectricCurrentValue;
    attribute def BiasVoltageValue :> ElectricPotentialValue;
    attribute def InternalPressure :> PressureValue;
    attribute def WorkFunctionValue :> EnergyValue;
    attribute def SpectralSensitivity :> Real;

    attribute def LightDetected;
    attribute def LightRemoved;

    item def Photon;
    item def Electron;
    item def Light {
        attribute intensity : LightIntensity;
        item photons : Photon[*];
    }

    port def OpticalPort {
        out item light : Light;
    }

    part def VacuumEnvelope {
        attribute internalPressure : InternalPressure;
    }

    part def Photocathode {
        attribute workFunction : WorkFunctionValue;
        attribute spectralSensitivity : SpectralSensitivity;
        in item incidentLight : Light;
        out item emittedElectrons : Electron[*];
    }

    part def Anode {
        in item incomingElectrons : Electron[*];
        out item photocurrent : PhotocurrentValue;
    }

    part def Phototube {
        part envelope : VacuumEnvelope;
        part photocathode : Photocathode;
        part anode : Anode;
        in item incidentLight : Light;
        in item biasVoltage : BiasVoltageValue;
        out item photocurrent : PhotocurrentValue;

        flow incidentLight to photocathode.incidentLight;
        flow photocathode.emittedElectrons to anode.incomingElectrons;
        flow anode.photocurrent to photocurrent;
    }

    part def BiasSupply {
        attribute voltageSetting : BiasVoltageValue;
        out item biasVoltage : BiasVoltageValue;
    }

    part def OpticalSource {
        attribute intensitySetting : LightIntensity;
        port lightOut : OpticalPort;
    }

    part def CurrentMeter {
        in item currentIn : PhotocurrentValue;
        attribute reading : PhotocurrentValue;
    }

    action def ConvertLightToCurrent {
        in item incidentLight : Light;
        in item biasVoltage : BiasVoltageValue;
        out item photocurrent : PhotocurrentValue;
    }

    state def DetectionStates {
        initial state standby;
        state active;
        transition from standby to active {
            accept lightDetected : LightDetected;
        }
        transition from active to standby {
            accept lightRemoved : LightRemoved;
        }
    }

    requirement def DetectLightRequirement {
        doc "The system shall detect the presence and intensity of light by utilizing the photoelectric effect.";
    }

    requirement def VacuumRequirement {
        doc "The vacuum envelope shall maintain an internal pressure below 1e-5 Pa to allow free electron travel.";
    }

    requirement def ProportionalityRequirement {
        doc "The output photocurrent shall be directly proportional to the incident light intensity.";
    }

    requirement def StateRequirement {
        doc "The system shall operate in standby when no light is present and transition to active when light is detected.";
    }

    part system {
        part opticalSource : OpticalSource {
            attribute intensitySetting : LightIntensity = 500;
        }

        part biasSupply : BiasSupply {
            attribute voltageSetting : BiasVoltageValue = 300;
        }

        part phototube : Phototube {
            part envelope : VacuumEnvelope {
                attribute internalPressure : InternalPressure = 1e-6;
            }
            part photocathode : Photocathode {
                attribute workFunction : WorkFunctionValue = 2.0;
                attribute spectralSensitivity : SpectralSensitivity = 0.05;
            }
            part anode : Anode;
        }

        part currentMeter : CurrentMeter;

        flow opticalSource.lightOut.light to phototube.incidentLight;
        flow biasSupply.biasVoltage to phototube.biasVoltage;
        flow phototube.photocurrent to currentMeter.currentIn;

        state detectionStates : DetectionStates;

        requirement detectLightReq : DetectLightRequirement;
        requirement vacuumReq : VacuumRequirement;
        requirement proportionalityReq : ProportionalityRequirement;
        requirement stateReq : StateRequirement;

        satisfy detectLightReq by phototube;
        satisfy vacuumReq by phototube.envelope;
        satisfy proportionalityReq by phototube.anode;
        satisfy stateReq by detectionStates;
    }
}
