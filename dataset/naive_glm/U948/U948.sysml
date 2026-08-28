package WireChamber {
    import ScalarValues::*;
    import ScalarFunctions::*;

    package Quantities {
        value def Voltage :> Real { unit "V"; }
        value def Pressure :> Real { unit "mbar"; }
        value def Length :> Real { unit "um"; }
        value def Time :> Real { unit "ns"; }
        value def Rate :> Real { unit "1/s"; }
        value def Current :> Real { unit "uA"; }
        value def Charge :> Real { unit "fC"; }
        value def Efficiency :> Real { unit "%"; }
        value def Count :> Integer;
        value def WireId :> Integer;
    }

    package Items {
        import Quantities::*;
        item def GasMixture {
            attribute argonFraction : Real;
            attribute co2Fraction : Real;
        }
        item def ChargedParticle {
            attribute energy : Real;
            attribute momentum : Real;
        }
        item def ElectronIonPair;
        item def Avalanche {
            attribute gain : Real;
        }
        item def CurrentPulse {
            attribute wireId : WireId;
            attribute peakCurrent : Current;
            attribute arrivalTime : Time;
        }
        item def DigitalPulse {
            attribute wireId : WireId;
            attribute leadingEdgeTime : Time;
        }
        item def TimingMeasurement {
            attribute wireId : WireId;
            attribute measuredTime : Time;
        }
        item def EventRecord {
            attribute eventId : Count;
            attribute measurements : TimingMeasurement[0..*];
            attribute reconstructedPath : Real[0..*];
        }
    }

    package Ports {
        import Items::*;
        port def GasFlowPort {
            out item gas : GasMixture;
            attribute pressure : Quantities::Pressure;
        }
        port def HVPort {
            attribute voltage : Quantities::Voltage;
        }
        port def SignalPort {
            out item pulse : CurrentPulse;
        }
        port def DigitalSignalPort {
            out item pulse : DigitalPulse;
        }
        port def TimingPort {
            out item measurement : TimingMeasurement;
        }
        port def EventPort {
            out item record : EventRecord;
        }
        port def ParticlePort {
            in item particle : ChargedParticle;
        }
    }

    package Requirements {
        import Quantities::*;
        requirement def SpatialResolutionRequirement {
            attribute requiredResolution : Length = 400;
            require /* chamber */ { resolution <= requiredResolution }
        }
        requirement def TimeResolutionRequirement {
            attribute requiredTimeResolution : Time = 3;
            require /* digitizer */ { timeResolution <= requiredTimeResolution }
        }
        requirement def RateCapabilityRequirement {
            attribute maxRate : Rate = 1500000;
            require /* system */ { sustainedRate <= maxRate }
        }
        requirement def EfficiencyRequirement {
            attribute minEfficiency : Efficiency = 98;
            require /* system */ { detectionEfficiency >= minEfficiency }
        }
        requirement def HVStabilityRequirement {
            attribute nominalVoltage : Voltage = 2800;
            require /* hvModule */ { |outputVoltage - nominalVoltage| < 5 }
        }
        requirement def GasPressureRequirement {
            attribute nominalPressure : Pressure = 1013;
            require /* gasFlowController */ { |chamberPressure - nominalPressure| < 10 }
        }
    }

    package Behaviors {
        import Items::*;
        import Quantities::*;

        state def DetectorStateMachine {
            entry; then standby;
            state standby;
            transition standby->armed
                when /* arm command received */;
            state armed {
                entry;
                do { /* monitor HV and gas, await particle trigger */ }
            }
            transition armed->activeReadout
                when /* trigger detected */;
            state activeReadout {
                entry { /* collect digitizer data */ }
                do { /* build event record */ }
                exit { /* forward record to DAQ */ }
            }
            transition activeReadout->armed
                when /* readout complete */;
            transition armed->standby
                when /* disarm command received */;
        }

        action def IonizeGas {
            in particle : ChargedParticle;
            out pairs : ElectronIonPair[1..*];
        }
        action def DriftElectrons {
            in pairs : ElectronIonPair[1..*];
            out driftedElectrons : ElectronIonPair[1..*];
        }
        action def AvalancheMultiplication {
            in driftedElectrons : ElectronIonPair[1..*];
            out avalanche : Avalanche;
        }
        action def InduceCurrentPulse {
            in avalanche : Avalanche;
            out pulse : CurrentPulse;
        }
        action def AmplifyCharge {
            in pulse : CurrentPulse;
            out amplified : CurrentPulse;
        }
        action def Discriminate {
            in amplified : CurrentPulse;
            out digital : DigitalPulse;
        }
        action def DigitizeTime {
            in digital : DigitalPulse;
            out measurement : TimingMeasurement;
        }
        action def BuildEvent {
            in measurements : TimingMeasurement[0..*];
            out record : EventRecord;
        }
    }

    package Components {
        import Items::*;
        import Ports::*;
        import Behaviors::*;
        import Quantities::*;

        part def GasChamber {
            attribute resolution : Length = 400;
            port gasIn : GasFlowPort;
            port gasOut : GasFlowPort;
            port hvInput : HVPort;
            port particleIn : ParticlePort;
            port signalOut : SignalPort[128];

            part cathodePlaneTop {
                attribute potential : Voltage = 0;
            }
            part cathodePlaneBottom {
                attribute potential : Voltage = 0;
            }
            part anodeWirePlane {
                attribute wireCount : Count = 128;
                attribute wireVoltage : Voltage = 2800;
                part wires : AnodeWire[128];
            }
            part def AnodeWire {
                attribute id : WireId;
                attribute diameter : Length = 20;
            }

            action detectionSequence :> IonizeGas {
                in particle = particleIn.particle;
                out pairs;
            }
            flow detectionSequence.pairs to drift.pairs;
            action drift :> DriftElectrons {
                out driftedElectrons;
            }
            flow drift.driftedElectrons to avalanche.driftedElectrons;
            action avalanche :> AvalancheMultiplication {
                out avalanche;
            }
            flow avalanche.avalanche to induce.avalanche;
            action induce :> InduceCurrentPulse {
                out pulse;
            }
            flow induce.pulse to signalOut.pulse;
        }

        part def GasFlowController {
            attribute chamberPressure : Pressure;
            port gasSupply : GasFlowPort;
            port chamberFeed : GasFlowPort;
            action regulatePressure {
                /* adjust flow to maintain stable pressure */
            }
        }

        part def HVModule {
            attribute outputVoltage : Voltage = 2800;
            port hvOutput : HVPort;
            action stabilize {
                /* maintain stable high voltage */
            }
        }

        part def ChargeAmplifier {
            port input : SignalPort;
            port output : SignalPort;
            action amplify :> AmplifyCharge {
                in pulse = input.pulse;
                out amplified;
            }
            flow amplify.amplified to output.pulse;
        }

        part def Discriminator {
            attribute threshold : Current = 5;
            port input : SignalPort;
            port output : DigitalSignalPort;
            action discriminate :> Discriminate {
                in amplified = input.pulse;
                out digital;
            }
            flow discriminate.digital to output.pulse;
        }

        part def TimeDigitizer {
            attribute timeResolution : Time = 3;
            port input : DigitalSignalPort[128];
            port output : TimingPort[128];
            action digitize :> DigitizeTime {
                in digital = input.pulse;
                out measurement;
            }
            flow digitize.measurement to output.measurement;
        }

        part def DAQSystem {
            attribute sustainedRate : Rate;
            attribute detectionEfficiency : Efficiency;
            port timingInputs : TimingPort[128];
            port eventOutput : EventPort;
            action buildEvent :> BuildEvent {
                in measurements = timingInputs.measurement;
                out record;
            }
            flow buildEvent.record to eventOutput.record;
        }

        part def ReadoutChannel {
            attribute channelId : WireId;
            port input : SignalPort;
            port output : DigitalSignalPort;
            part amplifier : ChargeAmplifier {
                port input = input;
            }
            part discriminator : Discriminator {
                port input = amplifier.output;
                port output = ReadoutChannel::output;
            }
            flow amplifier.output.pulse to discriminator.input.pulse;
        }
    }

    package System {
        import Components::*;
        import Requirements::*;
        import Behaviors::*;
        import Ports::*;
        import Items::*;
        import Quantities::*;

        part def WireChamberSystem {
            attribute resolution : Length = 400;
            attribute timeResolution : Time = 3;
            attribute sustainedRate : Rate = 1500000;
            attribute detectionEfficiency : Efficiency = 98;

            port particleInput : ParticlePort;
            port eventOutput : EventPort;

            part gasFlowController : GasFlowController {
                port chamberFeed;
            }
            part hvModule : HVModule {
                port hvOutput;
            }
            part chamber : GasChamber {
                port gasIn;
                port gasOut;
                port hvInput;
                port particleIn = System::WireChamberSystem::particleInput;
                port signalOut[128];
            }
            part readoutChannels : ReadoutChannel[128] {
                port input;
                port output;
            }
            part digitizer : TimeDigitizer {
                port input[128];
                port output[128];
            }
            part daq : DAQSystem {
                port timingInputs[128];
                port eventOutput = System::WireChamberSystem::eventOutput;
            }

            connection gasFlowController.chamberFeed to chamber.gasIn;
            connection hvModule.hvOutput to chamber.hvInput;
            connection chamber.signalOut to readoutChannels.input;
            connection readoutChannels.output to digitizer.input;
            connection digitizer.output to daq.timingInputs;

            state detectorState :> DetectorStateMachine;

            requirement spatialResolution : SpatialResolutionRequirement {
                require { chamber.resolution <= requiredResolution }
            }
            requirement timeResolution : TimeResolutionRequirement {
                require { digitizer.timeResolution <= requiredTimeResolution }
            }
            requirement rateCapability : RateCapabilityRequirement {
                require { sustainedRate <= maxRate }
            }
            requirement efficiency : EfficiencyRequirement {
                require { detectionEfficiency >= minEfficiency }
            }
            requirement hvStability : HVStabilityRequirement {
                require { |hvModule.outputVoltage - nominalVoltage| < 5 }
            }
            requirement gasPressure : GasPressureRequirement {
                require { |gasFlowController.chamberPressure - nominalPressure| < 10 }
            }
        }
    }
}
