package PMT_System {
    import ScalarValues::*;

    package PMT_ValueTypes {
        value type Voltage :> Real;
        value type Current :> Real;
        value type Time :> Real;
        value type Energy :> Real;
        value type Length :> Real;
        value type Wavelength :> Real;
        value type Gain :> Real;
        value type ElectronCount :> Integer;
        value type PhotonFlux :> Real;
        value type Pressure :> Real;
    }

    package PMT_Items {
        import PMT_ValueTypes::*;

        item def Photon {
            attribute wavelength : Wavelength;
            attribute energy : Energy;
        }

        item def Electron {
            attribute charge : Real = -1.602e-19;
            attribute kineticEnergy : Energy;
        }

        item def Photoelectron :> Electron;

        item def SecondaryElectron :> Electron;

        item def ElectronCloud {
            attribute electronCount : ElectronCount;
        }

        item def ElectricalPulse {
            attribute amplitude : Voltage;
            attribute duration : Time;
            attribute totalCharge : Real;
        }
    }

    package PMT_Behaviors {
        import PMT_Items::*;
        import PMT_ValueTypes::*;

        action def PhotoelectricEmission {
            in incomingPhoton : Photon;
            in cathodeWorkFunction : Energy;
            in quantumEfficiency : Real;
            out emittedElectron : Photoelectron;
            doc "Emits a primary photoelectron when a photon strikes the photocathode, via the photoelectric effect.";
        }

        action def SecondaryEmission {
            in incidentElectron : Electron;
            in dynodeIndex : Integer;
            in secondaryEmissionYield : Real;
            out secondaryElectrons : SecondaryElectron[0..*];
            doc "Knocks loose secondary electrons when an incident electron strikes a dynode surface.";
        }

        action def ElectronCollection {
            in electronCloud : ElectronCloud;
            in collectionEfficiency : Real;
            out outputPulse : ElectricalPulse;
            doc "Collects the electron cloud at the anode and generates a measurable electrical output pulse.";
        }

        calc def CalculateGain {
            in dynodeCount : Integer;
            in secondaryEmissionYield : Real;
            out totalGain : Gain;
            doc "Calculates total PMT gain as secondaryEmissionYield raised to the power of dynodeCount.";
        }
    }

    package PMT_Components {
        import PMT_ValueTypes::*;
        import PMT_Items::*;
        import PMT_Behaviors::*;

        part def UVTransmittingWindow {
            attribute material : String = "UV-grade fused silica";
            attribute transmissionEfficiency : Real = 0.85;
            attribute cutoffWavelength : Wavelength = 160.0;
            port in photonIn : Photon;
            port out photonOut : Photon;
        }

        part def Photocathode {
            attribute material : String = "bialkali";
            attribute quantumEfficiency : Real = 0.25;
            attribute workFunction : Energy;
            port in photonIn : Photon;
            port out electronOut : Photoelectron;
            port in biasInput : Voltage;
            perform emission : PhotoelectricEmission;
        }

        part def Dynode {
            attribute index : Integer;
            attribute biasVoltage : Voltage;
            attribute secondaryEmissionYield : Real = 4.0;
            port in electronIn : Electron;
            port out electronOut : SecondaryElectron;
            port in biasInput : Voltage;
            perform secondaryEmission : SecondaryEmission;
        }

        part def DynodeChain {
            attribute dynodeCount : Integer = 10;
            attribute totalGain : Gain;
            port in electronIn : Photoelectron;
            port out electronOut : ElectronCloud;
            port in biasInputs : Voltage[10] ordered;

            part dynodes : Dynode[10] ordered;

            connection chainInput connect electronIn to dynodes[1].electronIn;
            connection link1 connect dynodes[1].electronOut to dynodes[2].electronIn;
            connection link2 connect dynodes[2].electronOut to dynodes[3].electronIn;
            connection link3 connect dynodes[3].electronOut to dynodes[4].electronIn;
            connection link4 connect dynodes[4].electronOut to dynodes[5].electronIn;
            connection link5 connect dynodes[5].electronOut to dynodes[6].electronIn;
            connection link6 connect dynodes[6].electronOut to dynodes[7].electronIn;
            connection link7 connect dynodes[7].electronOut to dynodes[8].electronIn;
            connection link8 connect dynodes[8].electronOut to dynodes[9].electronIn;
            connection link9 connect dynodes[9].electronOut to dynodes[10].electronIn;
            connection chainOutput connect dynodes[10].electronOut to electronOut;

            connection biasDistribution connect biasInputs to dynodes.biasInput;
        }

        part def Anode {
            attribute collectionEfficiency : Real = 0.95;
            attribute biasVoltage : Voltage;
            port in electronIn : ElectronCloud;
            port out pulseOut : ElectricalPulse;
            port in biasInput : Voltage;
            perform collection : ElectronCollection;
        }

        part def VacuumEnvelope {
            attribute material : String = "borosilicate glass";
            attribute internalPressure : Pressure;
            attribute maxSafePressure : Pressure = 1.0e-6;
            port in photonIn : Photon;
            port out photonOut : Photon;
        }

        part def HighVoltageSupply {
            attribute outputVoltage : Voltage = 1000.0;
            attribute maxCurrent : Current;
            attribute ripple : Voltage;
            port out hvPositive : Voltage;
            port out hvGround : Voltage;
        }

        part def VoltageDivider {
            attribute resistorValues : Real[11];
            attribute tolerance : Real = 0.01;
            port in hvInput : Voltage;
            port out photocathodeBias : Voltage;
            port out dynodeBiases : Voltage[10] ordered;
            port out anodeBias : Voltage;
        }
    }

    package PMT_Assembly {
        import PMT_Components::*;
        import PMT_Items::*;
        import PMT_ValueTypes::*;
        import PMT_Behaviors::*;

        part def PMT {
            attribute serialNumber : String;
            attribute maxSafePhotonFlux : PhotonFlux = 1.0e8;
            attribute overallGain : Gain;
            attribute photonFlux : PhotonFlux;
            attribute isPowered : Boolean;
            attribute dynodeCount : Integer = 10;
            attribute secondaryEmissionYield : Real = 4.0;

            port in lightInput : Photon;
            port out signalOutput : ElectricalPulse;
            port in externalHV : Voltage;

            part envelope : VacuumEnvelope;
            part window : UVTransmittingWindow;
            part photocathode : Photocathode;
            part dynodeChain : DynodeChain;
            part anode : Anode;
            part hvSupply : HighVoltageSupply;
            part divider : VoltageDivider;

            connection lightToEnvelope connect lightInput to envelope.photonIn;
            connection envelopeToWindow connect envelope.photonOut to window.photonIn;
            connection windowToPhotocathode connect window.photonOut to photocathode.photonIn;
            connection photocathodeToDynode connect photocathode.electronOut to dynodeChain.electronIn;
            connection dynodeToAnode connect dynodeChain.electronOut to anode.electronIn;
            connection anodeOutput connect anode.pulseOut to signalOutput;

            connection externalHVToSupply connect externalHV to hvSupply.hvPositive;
            connection hvToDivider connect hvSupply.hvPositive to divider.hvInput;
            connection dividerToPhotocathode connect divider.photocathodeBias to photocathode.biasInput;
            connection dividerToDynodes connect divider.dynodeBiases to dynodeChain.biasInputs;
            connection dividerToAnode connect divider.anodeBias to anode.biasInput;

            calc gainCalc : CalculateGain {
                in dynodeCount = self.dynodeCount;
                in secondaryEmissionYield = self.secondaryEmissionYield;
                out totalGain = self.overallGain;
            }

            exhibit {
                entry; then Idle;

                state Idle {
                    entry;
                    doc "Powered on and waiting for light input.";
                }

                state Detecting {
                    entry;
                    doc "Actively detecting photons and producing amplified electrical output pulses.";
                }

                state Saturated {
                    entry;
                    doc "Incoming light intensity exceeds safe operating limits; device at risk of damage.";
                }

                transition idleToDetecting
                    first Idle
                    then Detecting
                    when photonFlux > 0.0;

                transition detectingToIdle
                    first Detecting
                    then Idle
                    when photonFlux == 0.0;

                transition detectingToSaturated
                    first Detecting
                    then Saturated
                    when photonFlux > maxSafePhotonFlux;

                transition saturatedToIdle
                    first Saturated
                    then Idle
                    when photonFlux == 0.0;
            }
        }
    }

    package PMT_Requirements {
        import PMT_ValueTypes::*;
        import PMT_Assembly::*;

        requirement def VacuumIntegrityRequirement {
            attribute maxInternalPressure : Pressure = 1.0e-6;
            doc "The borosilicate glass vacuum envelope must maintain sufficient vacuum for electrons to travel without colliding with air molecules.";
            constraint { envelope.internalPressure < maxInternalPressure }
        }

        requirement def GainRequirement {
            attribute minGain : Gain = 1.0e6;
            doc "The PMT must achieve a total gain of at least one million, turning a single photoelectron into a cascade of over a million electrons.";
            constraint { overallGain >= minGain }
        }

        requirement def UVWindowRequirement {
            attribute maxCutoffWavelength : Wavelength = 160.0;
            doc "The UV-transmitting window must transmit ultraviolet light down to at least 160 nm wavelength.";
            constraint { window.cutoffWavelength <= maxCutoffWavelength }
        }

        requirement def DynodeCountRequirement {
            attribute requiredCount : Integer = 10;
            doc "The dynode chain must consist of exactly ten dynodes, each held at a progressively higher voltage.";
            constraint { dynodeChain.dynodeCount == requiredCount }
        }

        requirement def SaturationProtectionRequirement {
            doc "The system must enter a saturated state when incoming light exceeds safe levels to prevent damage to the device.";
        }

        requirement def VoltageDividerRequirement {
            doc "The voltage divider circuit must ensure each dynode receives the correct, incrementally higher voltage to create the accelerating electric field.";
        }

        requirement def PhotoelectricEffectRequirement {
            attribute minQuantumEfficiency : Real = 0.15;
            doc "The photocathode must emit primary electrons via the photoelectric effect when photons strike its surface.";
            constraint { photocathode.quantumEfficiency >= minQuantumEfficiency }
        }

        requirement def AnodeOutputRequirement {
            doc "The anode must collect the electron cloud and generate a distinct, measurable electrical output pulse.";
        }

        requirement def HighVoltageSupplyRequirement {
            attribute minOutputVoltage : Voltage = 500.0;
            doc "The high-voltage supply must provide sufficient voltage to power the entire dynode chain and create the accelerating fields.";
            constraint { hvSupply.outputVoltage >= minOutputVoltage }
        }

        requirement vacReq : VacuumIntegrityRequirement;
        requirement gainReq : GainRequirement;
        requirement windowReq : UVWindowRequirement;
        requirement dynodeReq : DynodeCountRequirement;
        requirement satReq : SaturationProtectionRequirement;
        requirement dividerReq : VoltageDividerRequirement;
        requirement peReq : PhotoelectricEffectRequirement;
        requirement anodeReq : AnodeOutputRequirement;
        requirement hvReq : HighVoltageSupplyRequirement;

        part pmtInstance : PMT {
            satisfy vacReq;
            satisfy gainReq;
            satisfy windowReq;
            satisfy dynodeReq;
            satisfy satReq;
            satisfy dividerReq;
            satisfy peReq;
            satisfy anodeReq;
            satisfy hvReq;
        }
    }
}
