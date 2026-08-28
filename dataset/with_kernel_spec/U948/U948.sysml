package WireChamberDetector {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def ChargedParticle {
        attribute charge : ElectricChargeValue;
        attribute energy : EnergyValue;
    }

    item def GasMixture {
        attribute argonFraction : Real;
        attribute co2Fraction : Real;
        attribute pressure : PressureValue = 101325 [Pa];
    }

    item def IonizationElectron;

    item def ChargePulse {
        attribute charge : ElectricChargeValue;
        attribute wireId : Integer;
    }

    item def DigitalPulse {
        attribute wireId : Integer;
        attribute logicLevel : Integer;
    }

    item def HitData {
        attribute wireId : Integer;
        attribute hitTime : TimeValue;
    }

    item def EventRecord {
        attribute hits : HitData[*];
        attribute eventId : Integer;
        attribute timestamp : TimeValue;
    }

    item def ArmCommand;
    item def DisarmCommand;
    item def TriggerDetected;
    item def ReadoutComplete;
    item def ShutdownCommand;

    part def CathodePlane {
        attribute potential : ElectricPotentialValue = 0 [V];
    }

    part def AnodeWire {
        attribute wireId : Integer;
        attribute voltage : ElectricPotentialValue;
        attribute diameter : LengthValue = 0.02 [mm];
        attribute spacing : LengthValue = 0.4 [mm];
        out item pulse : ChargePulse;
    }

    part def AnodeWirePlane {
        part wires : AnodeWire[128];
        attribute wireSpacing : LengthValue = 0.4 [mm];
        out item signalOut : ChargePulse[128];
        flow wires.pulse to signalOut;
    }

    part def GasChamber {
        in item gasIn : GasMixture;
        part cathodes : CathodePlane[2];
        part anodes : AnodeWirePlane;
        item gas : GasMixture;
        attribute volume : VolumeValue;
        flow gasIn to gas;
    }

    part def GasFlowController {
        attribute targetPressure : PressureValue = 101325 [Pa];
        attribute flowRate : Real;
        out item gasOut : GasMixture;
    }

    part def HighVoltageModule {
        attribute outputVoltage : ElectricPotentialValue = 2800 [V];
        attribute ripple : Real = 0.001;
    }

    part def ChargeAmplifier {
        attribute gain : Real = 1000.0;
        in item input : ChargePulse;
        out item output : ChargePulse;
    }

    part def Discriminator {
        attribute threshold : ElectricChargeValue = 1e-15 [C];
        in item input : ChargePulse;
        out item output : DigitalPulse;
    }

    part def ReadoutChannel {
        in item input : ChargePulse;
        out item output : DigitalPulse;
        part amplifier : ChargeAmplifier;
        part discriminator : Discriminator;
        flow input to amplifier.input;
        flow amplifier.output to discriminator.input;
        flow discriminator.output to output;
    }

    part def TimeDigitizer {
        attribute resolution : TimeValue = 3e-9 [s];
        attribute maxRate : FrequencyValue = 1.5e6 [Hz];
        in item inputs : DigitalPulse[*];
        out item outputs : HitData[*];
        action digitize {
            in pulses : DigitalPulse[*] = inputs;
            out hits : HitData[*] = outputs;
        }
    }

    part def DAQSystem {
        in item inputs : HitData[*];
        out item record : EventRecord;
        attribute detectionEfficiency : Real = 0.98;

        action reconstructEvent {
            in hits : HitData[*] = inputs;
            out eventRecord : EventRecord = record;
        }
    }

    action def DetectParticleAction {
        in particle : ChargedParticle;
        in gas : GasMixture;
        out record : EventRecord;

        action ionize {
            in p : ChargedParticle = particle;
            in g : GasMixture = gas;
            out electrons : IonizationElectron[*];
        }
        then action drift {
            in electrons : IonizationElectron[*] = ionize.electrons;
            out collectedElectrons : IonizationElectron[*];
        }
        then action avalanche {
            in collectedElectrons : IonizationElectron[*] = drift.collectedElectrons;
            out pulses : ChargePulse[*];
        }
        then action amplify {
            in pulses : ChargePulse[*] = avalanche.pulses;
            out amplifiedPulses : ChargePulse[*];
        }
        then action discriminate {
            in amplifiedPulses : ChargePulse[*] = amplify.amplifiedPulses;
            out digitalPulses : DigitalPulse[*];
        }
        then action digitize {
            in digitalPulses : DigitalPulse[*] = discriminate.digitalPulses;
            out hits : HitData[*];
        }
        then action reconstruct {
            in hits : HitData[*] = digitize.hits;
            out eventRecord : EventRecord = record;
        }
    }

    state def DetectorStateMachine {
        state standby;
        state armed;
        state readout;
        transition standby to armed accept ArmCommand;
        transition armed to standby accept DisarmCommand;
        transition armed to readout accept TriggerDetected;
        transition readout to armed accept ReadoutComplete;
        transition readout to standby accept ShutdownCommand;
    }

    requirement def SpatialResolutionRequirement {
        doc /* The detector shall achieve a spatial resolution of 400 micrometers. */
        attribute requiredResolution : LengthValue = 0.4 [mm];
    }

    requirement def TimeResolutionRequirement {
        doc /* The detector shall achieve a time resolution of 3 nanoseconds. */
        attribute requiredResolution : TimeValue = 3e-9 [s];
    }

    requirement def RateCapabilityRequirement {
        doc /* The detector shall handle particle rates up to 1.5 million per second. */
        attribute maxRate : FrequencyValue = 1.5e6 [Hz];
    }

    requirement def DetectionEfficiencyRequirement {
        doc /* The detector shall maintain a detection efficiency greater than 98 percent. */
        attribute minEfficiency : Real = 0.98;
    }

    part def WireChamber {
        requirement spatialResolutionReq : SpatialResolutionRequirement;
        requirement timeResolutionReq : TimeResolutionRequirement;
        requirement rateCapabilityReq : RateCapabilityRequirement;
        requirement efficiencyReq : DetectionEfficiencyRequirement;

        state detectorState : DetectorStateMachine;

        part chamber : GasChamber;
        part gasCtrl : GasFlowController;
        part hv : HighVoltageModule;
        part readout : ReadoutChannel[128];
        part digitizer : TimeDigitizer;
        part daq : DAQSystem;

        in item incidentParticle : ChargedParticle;
        out item eventRecordOut : EventRecord;

        attribute actualResolution : LengthValue;
        attribute actualTimeResolution : TimeValue;
        attribute actualRate : FrequencyValue;
        attribute actualEfficiency : Real;

        flow gasCtrl.gasOut to chamber.gasIn;
        bind hv.outputVoltage = chamber.anodes.wires.voltage;
        flow chamber.anodes.signalOut to readout.input;
        flow readout.output to digitizer.inputs;
        flow digitizer.outputs to daq.inputs;
        flow daq.record to eventRecordOut;

        action detect : DetectParticleAction {
            in particle = incidentParticle;
            in gas = chamber.gas;
            out record = daq.record;
        }
    }
}
