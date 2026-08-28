package PhotodetectorSystem {
    private import SI::*;
    private import ScalarValues::*;

    attribute def Light {
        attribute power :> ISQ::power;
        attribute wavelength :> ISQ::length;
    }

    attribute def LightDetected;
    attribute def OverSaturation;
    attribute def LightNormal;

    port def OpticalPort {
        attribute light : Light;
    }

    port def BiasVoltagePort {
        attribute voltage :> ISQ::electricPotential;
    }

    port def CurrentPort {
        attribute current :> ISQ::electricCurrent;
    }

    port def VoltagePort {
        attribute voltage :> ISQ::electricPotential;
    }

    part def PhotodetectorElement {
        attribute activeArea :> ISQ::area;
        attribute responsivity : Real;
        attribute darkCurrent :> ISQ::electricCurrent;
        attribute wavelengthMin :> ISQ::length;
        attribute wavelengthMax :> ISQ::length;
        attribute quantumEfficiency : Real;

        in port lightInput : OpticalPort;
        in port biasInput : BiasVoltagePort;
        out port currentOutput : CurrentPort;
    }

    part def BiasSupply {
        attribute outputVoltage :> ISQ::electricPotential;
        attribute voltageRipple :> ISQ::electricPotential;
        out port biasOutput : BiasVoltagePort;
    }

    part def TransimpedanceAmplifier {
        attribute gain :> ISQ::resistance;
        attribute bandwidth :> ISQ::frequency;
        attribute inputCapacitance :> ISQ::capacitance;

        in port currentInput : CurrentPort;
        out port voltageOutput : VoltagePort;
    }

    part def SignalConditioner {
        attribute gain : Real;
        attribute lowCutoff :> ISQ::frequency;
        attribute highCutoff :> ISQ::frequency;

        in port voltageInput : VoltagePort;
        out port voltageOutput : VoltagePort;
    }

    part def PhotodetectorSystem {
        in port lightIn : OpticalPort;
        out port signalOut : VoltagePort;

        part biasSupply : BiasSupply;
        part detector : PhotodetectorElement;
        part tia : TransimpedanceAmplifier;
        part conditioner : SignalConditioner;

        connect lightIn to detector.lightInput;
        connect biasSupply.biasOutput to detector.biasInput;
        connect detector.currentOutput to tia.currentInput;
        connect tia.voltageOutput to conditioner.voltageInput;
        connect conditioner.voltageOutput to signalOut;

        state def PhotodetectorStates {
            state standby;
            state detecting {
                do action detectLight;
            }
            state amplifying {
                do action amplifyCurrent;
            }
            state conditioning {
                do action conditionSignal;
            }
            state saturated;

            transition first standby
                accept LightDetected
                then detecting;
            transition first detecting then amplifying;
            transition first amplifying then conditioning;
            transition first conditioning then standby;

            transition first standby
                accept OverSaturation
                then saturated;
            transition first detecting
                accept OverSaturation
                then saturated;
            transition first amplifying
                accept OverSaturation
                then saturated;
            transition first conditioning
                accept OverSaturation
                then saturated;

            transition first saturated
                accept LightNormal
                then standby;
        }

        exhibit state photodetectorBehavior : PhotodetectorStates;
    }

    requirement def PhotodetectorSystemRequirement {
        subject pdSystem : PhotodetectorSystem;
    }

    requirement def DarkCurrentRequirement :> PhotodetectorSystemRequirement {
        doc /* The photodetector dark current shall not exceed the specified maximum. */
        attribute actualDarkCurrent :> ISQ::electricCurrent;
        attribute maxDarkCurrent :> ISQ::electricCurrent;
        require constraint { actualDarkCurrent <= maxDarkCurrent }
    }

    requirement def ResponsivityRequirement :> PhotodetectorSystemRequirement {
        doc /* The photodetector responsivity shall be at least the specified minimum. */
        attribute actualResponsivity : Real;
        attribute minResponsivity : Real;
        require constraint { actualResponsivity >= minResponsivity }
    }

    requirement def BandwidthRequirement :> PhotodetectorSystemRequirement {
        doc /* The transimpedance amplifier bandwidth shall be at least the specified minimum. */
        attribute actualBandwidth :> ISQ::frequency;
        attribute minBandwidth :> ISQ::frequency;
        require constraint { actualBandwidth >= minBandwidth }
    }

    requirement def WavelengthRangeRequirement :> PhotodetectorSystemRequirement {
        doc /* The photodetector shall be sensitive within the specified wavelength range. */
        attribute minWavelength :> ISQ::length;
        attribute maxWavelength :> ISQ::length;
        require constraint { maxWavelength > minWavelength }
    }

    requirement def SaturationRecoveryRequirement :> PhotodetectorSystemRequirement {
        doc /* The system shall recover from saturation within the specified time. */
        attribute recoveryTime :> ISQ::time;
        attribute maxRecoveryTime :> ISQ::time;
        require constraint { recoveryTime <= maxRecoveryTime }
    }

    analysis def PhotodetectorSystemAnalysis {
        subject system : PhotodetectorSystem;

        requirement darkCurrentRequirement : DarkCurrentRequirement;
        requirement responsivityRequirement : ResponsivityRequirement;
        requirement bandwidthRequirement : BandwidthRequirement;
        requirement wavelengthRangeRequirement : WavelengthRangeRequirement;
        requirement saturationRecoveryRequirement : SaturationRecoveryRequirement;

        objective verifyPerformance {
            doc /* Verify that the photodetector system meets all performance requirements under incident light conditions. */
        }
    }
}
