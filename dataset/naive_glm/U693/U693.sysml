package ProportionalCounter {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value def PressureValue :> Real { unit "Pa"; }
    value def VoltageValue :> Real { unit "V"; }
    value def CurrentValue :> Real { unit "A"; }
    value def EnergyValue :> Real { unit "eV"; }
    value def RateValue :> Real { unit "1/s"; }
    value def TemperatureValue :> Real { unit "K"; }
    value def TimeValue :> Real { unit "s"; }
    value def FractionValue :> Real;
    value def GainValue :> Real;

    // ===== Items =====
    item def RadiationParticle {
        attribute energy : EnergyValue;
        attribute particleType : String;
    }
    item def ElectronIonPair;
    item def GasMixture {
        attribute name : String;
        attribute argonFraction : FractionValue;
        attribute methaneFraction : FractionValue;
        attribute pressure : PressureValue;
    }
    item def P10Gas :> GasMixture {
        redef name = "P10";
        redef argonFraction = 0.90;
        redef methaneFraction = 0.10;
    }
    item def CurrentPulse {
        attribute amplitude : CurrentValue;
        attribute duration : TimeValue;
    }
    item def VoltagePulse {
        attribute amplitude : VoltageValue;
        attribute duration : TimeValue;
    }
    item def DiscriminatedPulse :> VoltagePulse {
        attribute accepted : Boolean;
    }
    item def CountEvent {
        attribute timestamp : TimeValue;
        attribute energy : EnergyValue;
    }
    item def GasFlowCommand {
        attribute targetPressure : PressureValue;
        attribute flowRate : RateValue;
    }
    item def HVCommand {
        attribute targetVoltage : VoltageValue;
    }

    // ===== Requirements =====
    requirement def DetectIonizingRadiationRequirement {
        doc "The system shall detect ionizing radiation events entering the detection chamber.";
        attribute minDetectableEnergy : EnergyValue = 1000;
        subject detector;
        objective { detector.detectedEventCount >= 1 }
    }

    requirement def GasStabilityRequirement {
        doc "The gas flow controller shall maintain P10 gas pressure within tolerance.";
        attribute nominalPressure : PressureValue = 101325;
        attribute pressureTolerance : PressureValue = 500;
        subject controller;
        objective {
            abs(controller.measuredPressure - nominalPressure) <= pressureTolerance
        }
    }

    requirement def PulseProcessingRequirement {
        doc "The preamplifier shall convert current pulses into voltage pulses with gain above threshold.";
        attribute minGain : GainValue = 1000;
        subject preamp;
        objective { preamp.gain >= minGain }
    }

    requirement def DiscriminationRequirement {
        doc "The discriminator shall accept only pulses within the configured energy window.";
        attribute lowerEnergy : EnergyValue = 5000;
        attribute upperEnergy : EnergyValue = 50000;
        subject discriminator;
        objective {
            discriminator.acceptedPulse.energy >= lowerEnergy and
            discriminator.acceptedPulse.energy <= upperEnergy
        }
    }

    requirement def CountingRequirement {
        doc "The counter module shall count accepted pulses and report event rate.";
        subject counter;
        objective { counter.eventCount >= 0 and counter.eventRate >= 0 }
    }

    // ===== Port Definitions =====
    port def RadiationInPort {
        out item particle : RadiationParticle;
    }
    port def GasPort {
        out item gas : GasMixture;
        in item command : GasFlowCommand;
    }
    port def HVPort {
        out item voltage : VoltageValue;
        in item command : HVCommand;
    }
    port def CurrentPulsePort {
        out item pulse : CurrentPulse;
    }
    port def VoltagePulsePort {
        out item pulse : VoltagePulse;
    }
    port def DiscriminatedPulsePort {
        out item pulse : DiscriminatedPulse;
    }
    port def CountEventPort {
        out item event : CountEvent;
    }

    // ===== Parts =====
    part def GasFlowController {
        attribute measuredPressure : PressureValue;
        attribute measuredFlowRate : RateValue;
        attribute targetPressure : PressureValue;
        port gasOut : GasPort;
        attribute stable : Boolean;

        action def regulateFlow {
            in gasCmd : GasFlowCommand;
            out suppliedGas : P10Gas;
        }
    }

    part def ElectrodeAssembly {
        attribute anodeWireDiameter : Real { unit "um"; } = 25;
        attribute cathodeInnerDiameter : Real { unit "mm"; } = 50;
        attribute electricField : Real { unit "V/m"; }
        port hvIn : HVPort;
        port currentOut : CurrentPulsePort;

        action def generateAvalanche {
            in incoming : RadiationParticle;
            out pulse : CurrentPulse;
        }
    }

    part def DetectionChamber {
        attribute volume : Real { unit "cm3"; } = 100;
        attribute sealed : Boolean = true;
        attribute gasFill : P10Gas;
        port radiationIn : RadiationInPort;
        port gasIn : GasPort;
        port hvConnection : HVPort;
        port currentOut : CurrentPulsePort;
        part electrode : ElectrodeAssembly;

        action def ionizeGas {
            in particle : RadiationParticle;
            out pairs : ElectronIonPair[*];
        }
    }

    part def HighVoltageSupply {
        attribute outputVoltage : VoltageValue;
        attribute targetVoltage : VoltageValue;
        attribute rampTime : TimeValue = 5;
        port hvOut : HVPort;
        attribute stable : Boolean;

        action def rampUp {
            in cmd : HVCommand;
            out voltage : VoltageValue;
        }
    }

    part def PreamplifierCircuit {
        attribute gain : GainValue = 5000;
        attribute shapingTime : TimeValue = 0.000001;
        port currentIn : CurrentPulsePort;
        port voltageOut : VoltagePulsePort;

        action def amplifyAndShape {
            in currentPulse : CurrentPulse;
            out voltagePulse : VoltagePulse;
        }
    }

    part def PulseDiscriminator {
        attribute lowerThreshold : VoltageValue;
        attribute upperThreshold : VoltageValue;
        attribute lowerEnergy : EnergyValue = 5000;
        attribute upperEnergy : EnergyValue = 50000;
        port pulseIn : VoltagePulsePort;
        port acceptedOut : DiscriminatedPulsePort;

        action def discriminate {
            in pulse : VoltagePulse;
            out discriminated : DiscriminatedPulse;
        }
    }

    part def CounterModule {
        attribute eventCount : Integer = 0;
        attribute eventRate : RateValue = 0;
        attribute integrationTime : TimeValue = 1;
        port pulseIn : DiscriminatedPulsePort;
        port countOut : CountEventPort;

        action def countPulse {
            in pulse : DiscriminatedPulse;
            out event : CountEvent;
        }

        action def updateRate {
            in events : CountEvent[*];
            out rate : RateValue;
        }
    }

    // ===== System =====
    part def ProportionalCounterSystem {
        attribute detectedEventCount : Integer = 0;
        attribute systemReady : Boolean = false;
        attribute faultActive : Boolean = false;

        port radiationInput : RadiationInPort;
        port countOutput : CountEventPort;

        part chamber : DetectionChamber {
            redef radiationIn = radiationInput;
        }
        part gasController : GasFlowController;
        part hvSupply : HighVoltageSupply;
        part preamplifier : PreamplifierCircuit;
        part discriminator : PulseDiscriminator;
        part counter : CounterModule;

        // Connections
        connection gasController.gasOut to chamber.gasIn;
        connection hvSupply.hvOut to chamber.hvConnection;
        connection chamber.currentOut to preamplifier.currentIn;
        connection preamplifier.voltageOut to discriminator.pulseIn;
        connection discriminator.acceptedOut to counter.pulseIn;
        connection counter.countOut to countOutput;

        // Requirements satisfaction
        satisfy DetectIonizingRadiationRequirement by self;
        satisfy GasStabilityRequirement by gasController;
        satisfy PulseProcessingRequirement by preamplifier;
        satisfy DiscriminationRequirement by discriminator;
        satisfy CountingRequirement by counter;

        // ===== State Machine =====
        state def DetectorStates {
            entry action { systemReady = false; }

            state Standby {
                entry action { faultActive = false; detectedEventCount = 0; }
            }

            state Initialization {
                entry action {
                    gasController.targetPressure := 101325;
                    hvSupply.targetVoltage := 1500;
                }
                do action {
                    gasController.regulateFlow();
                    hvSupply.rampUp();
                }
                transition from Standby to Initialization
                    when (powerOn == true);
                transition from Initialization to Detecting
                    when (gasController.stable == true and hvSupply.stable == true)
                    accept PowerStable;
            }

            state Detecting {
                entry action { systemReady := true; }
                do action {
                    chamber.ionizeGas();
                    chamber.electrode.generateAvalanche();
                    preamplifier.amplifyAndShape();
                    discriminator.discriminate();
                    counter.countPulse();
                    detectedEventCount := detectedEventCount + 1;
                }
                transition from Detecting to Detecting
                    accept RadiationEvent
                    send ProcessEvent;
                transition from Detecting to Fault
                    when (faultActive == true);
            }

            state Fault {
                entry action { systemReady := false; }
                do action { logFault(); }
                transition from Fault to Standby
                    accept ResetCommand;
            }

            transition from Initialization to Fault
                when (faultActive == true);
        }

        // Signals / events referenced by state machine
        item def PowerOn;
        item def PowerStable;
        item def RadiationEvent;
        item def ProcessEvent;
        item def ResetCommand;

        attribute powerOn : Boolean = false;

        action def logFault {
            /* record fault information */
        }

        exhibit state machine : DetectorStates;
    }
}
