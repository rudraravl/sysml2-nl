package VacuumTubeAmplifier {
    import ScalarValues::*;
    import ISQ::*;
    import ISQElectromagnetism::*;
    import ISQThermodynamics::*;

    // ---------- Value Types ----------
    def VoltageValue :> Real { unit 'V'; }
    def CurrentValue :> Real { unit 'A'; }
    def ResistanceValue :> Real { unit 'ohm'; }
    def PowerValue :> Real { unit 'W'; }
    def TemperatureValue :> Real { unit 'K'; }
    def TurnsRatioValue :> Real;
    def GainValue :> Real;

    // ---------- Item Types ----------
    item AudioSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute power : PowerValue;
    }

    item DCPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item ElectronFlow {
        attribute current : CurrentValue;
        attribute density : Real;
    }

    // ---------- Port Definitions ----------
    port def AudioInPort {
        out signal : AudioSignal;
    }

    port def AudioOutPort {
        out signal : AudioSignal;
    }

    port def DCPowerPort {
        out power : DCPower;
    }

    port def HeaterPowerPort {
        out power : DCPower;
    }

    port def GridDrivePort {
        in signal : AudioSignal;
    }

    port def AnodeOutputPort {
        out signal : AudioSignal;
    }

    port def SpeakerPort {
        in signal : AudioSignal;
    }

    // ---------- Requirements ----------
    requirement AmplificationRequirement {
        doc /* The system shall amplify a weak input audio signal to a power level sufficient to drive a speaker. */
        attribute minInputPower : PowerValue = 0.001 [W];
        attribute minOutputPower : PowerValue = 5.0 [W];
        constraint { input.power >= minInputPower implies output.power >= minOutputPower }
    }

    requirement HeaterWarmupRequirement {
        doc /* The heater shall bring the cathode to emission temperature within 30 seconds. */
        attribute maxWarmupTime : Real = 30.0;
        attribute cathodeEmissionTemp : TemperatureValue = 1100.0 [K];
    }

    requirement OverloadProtectionRequirement {
        doc /* The system shall enter an overload state if anode current exceeds the rated maximum. */
        attribute maxAnodeCurrent : CurrentValue = 0.05 [A];
    }

    requirement VacuumIntegrityRequirement {
        doc /* The system shall enter a failed state if vacuum inside the tube envelope is compromised. */
        attribute minVacuumLevel : Real = 1e-6;
    }

    // ---------- Triode Vacuum Tube ----------
    part def TriodeVacuumTube {
        port gridPort : GridDrivePort;
        port anodePort : AnodeOutputPort;
        port heaterInput : HeaterPowerPort;
        port hvInput : DCPowerPort;

        attribute amplificationFactor : GainValue = 20.0;
        attribute plateResistance : ResistanceValue = 8000.0 [ohm];
        attribute transconductance : Real = 0.0025;

        part glassEnvelope {
            attribute vacuumLevel : Real = 1e-7;
            attribute compromised : Boolean = false;
        }

        part heater {
            attribute supplyVoltage : VoltageValue = 6.3 [V];
            attribute supplyCurrent : CurrentValue = 0.3 [A];
            attribute temperature : TemperatureValue;
            attribute targetTemperature : TemperatureValue = 1100.0 [K];
            attribute powered : Boolean = false;

            action heatUp {
                in target : TemperatureValue;
                out achievedTemp : TemperatureValue;
            }
        }

        part cathode {
            attribute emissionTemperature : TemperatureValue = 1100.0 [K];
            attribute currentTemperature : TemperatureValue;
            attribute emitting : Boolean = false;

            action emitElectrons {
                out flow : ElectronFlow;
            }
        }

        part anode {
            attribute plateVoltage : VoltageValue = 250.0 [V];
            attribute plateCurrent : CurrentValue;
            attribute maxPlateCurrent : CurrentValue = 0.05 [A];
        }

        part controlGrid {
            attribute biasVoltage : VoltageValue = -3.0 [V];
            attribute inputVoltage : VoltageValue;
        }

        connection heaterToCathode connect heater to cathode;

        action amplify {
            in inputSignal : AudioSignal;
            in hvPower : DCPower;
            out outputSignal : AudioSignal;
            doc /* Modulates electron flow from cathode to anode based on grid voltage. */
        }
    }

    // ---------- Power Supplies ----------
    part def HighVoltageSupply {
        port outputPort : DCPowerPort;
        attribute outputVoltage : VoltageValue = 250.0 [V];
        attribute maxCurrent : CurrentValue = 0.1 [A];
        attribute enabled : Boolean = false;

        action supplyHV {
            out power : DCPower;
        }
    }

    part def LowVoltageSupply {
        port outputPort : HeaterPowerPort;
        attribute outputVoltage : VoltageValue = 6.3 [V];
        attribute maxCurrent : CurrentValue = 1.0 [A];
        attribute enabled : Boolean = false;

        action supplyHeater {
            out power : DCPower;
        }
    }

    // ---------- Transformers ----------
    part def InputTransformer {
        port inputPort : AudioInPort;
        port outputPort : GridDrivePort;
        attribute turnsRatio : TurnsRatioValue = 10.0;
        attribute primaryImpedance : ResistanceValue = 600.0 [ohm];
        attribute secondaryImpedance : ResistanceValue = 10000.0 [ohm];

        action matchInput {
            in rawSignal : AudioSignal;
            out matchedSignal : AudioSignal;
        }
    }

    part def OutputTransformer {
        port inputPort : AnodeOutputPort;
        port outputPort : AudioOutPort;
        attribute turnsRatio : TurnsRatioValue = 20.0;
        attribute primaryImpedance : ResistanceValue = 8000.0 [ohm];
        attribute secondaryImpedance : ResistanceValue = 8.0 [ohm];

        action matchOutput {
            in amplifiedSignal : AudioSignal;
            out matchedSignal : AudioSignal;
        }
    }

    // ---------- Speaker ----------
    part def Speaker {
        port inputPort : SpeakerPort;
        attribute impedance : ResistanceValue = 8.0 [ohm];
        attribute powerRating : PowerValue = 10.0 [W];

        action produceSound {
            in signal : AudioSignal;
        }
    }

    // ---------- Amplifier System ----------
    part def AmplifierSystem {
        port audioIn : AudioInPort;
        port audioOut : AudioOutPort;

        part triode : TriodeVacuumTube;
        part hvSupply : HighVoltageSupply;
        part heaterSupply : LowVoltageSupply;
        part inputTransformer : InputTransformer;
        part outputTransformer : OutputTransformer;
        part speaker : Speaker;

        // System-level attributes
        attribute anodeCurrent : CurrentValue;
        attribute vacuumLevel : Real;
        attribute signalDetected : Boolean = false;
        attribute overloadThreshold : CurrentValue = 0.05 [A];
        attribute cathodeReady : Boolean = false;

        // Connections
        connection hvToTube connect hvSupply.outputPort to triode.hvInput;
        connection heaterToTube connect heaterSupply.outputPort to triode.heaterInput;
        connection audioToInputTransformer connect audioIn to inputTransformer.inputPort;
        connection inputTransformerToGrid connect inputTransformer.outputPort to triode.gridPort;
        connection anodeToOutputTransformer connect triode.anodePort to outputTransformer.inputPort;
        connection outputTransformerToSpeaker connect outputTransformer.outputPort to speaker.inputPort;

        // State Machine
        state def AmplifierStates;

        state warmingUp {
            entry action {
                heaterSupply.enabled = true;
                triode.heater.powered = true;
            }
            do action {
                triode.heater.heatUp(triode.heater.targetTemperature, triode.heater.temperature);
                triode.cathode.currentTemperature = triode.heater.temperature;
            }
            exit action {
                cathodeReady = (triode.cathode.currentTemperature >= triode.cathode.emissionTemperature);
            }
        }

        state standby {
            entry action {
                hvSupply.enabled = true;
            }
            do action {
                // Monitor for input signal
                if (audioIn.signal.power > 0.0) {
                    signalDetected = true;
                }
            }
        }

        state amplifying {
            do action {
                triode.amplify(inputTransformer.matchedSignal, hvSupply.supplyHV(), outputTransformer.matchedSignal);
                anodeCurrent = triode.anode.plateCurrent;
                if (anodeCurrent > overloadThreshold) {
                    // trigger overload transition
                }
            }
        }

        state overload {
            entry action {
                hvSupply.enabled = false;
            }
            do action {
                // Cool down and wait for reset
            }
        }

        state failed {
            entry action {
                hvSupply.enabled = false;
                heaterSupply.enabled = false;
            }
        }

        state machine AmplifierStateMachine {
            state warmingUp;
            state standby;
            state amplifying;
            state overload;
            state failed;

            transition init_to_warmingUp initial to warmingUp;

            transition warmingUp_to_standby
                from warmingUp to standby
                when cathodeReady == true;

            transition standby_to_amplifying
                from standby to amplifying
                when signalDetected == true;

            transition amplifying_to_standby
                from amplifying to standby
                when signalDetected == false;

            transition amplifying_to_overload
                from amplifying to overload
                when anodeCurrent > overloadThreshold;

            transition overload_to_standby
                from overload to standby
                when anodeCurrent <= overloadThreshold;

            transition any_to_failed
                from amplifying to failed
                when triode.glassEnvelope.compromised == true;

            transition standby_to_failed
                from standby to failed
                when triode.glassEnvelope.compromised == true;

            transition warmingUp_to_failed
                from warmingUp to failed
                when triode.glassEnvelope.compromised == true;
        }

        satisfy AmplificationRequirement by triode.amplify;
        satisfy HeaterWarmupRequirement by triode.heater.heatUp;
        satisfy OverloadProtectionRequirement by AmplifierStateMachine.overload;
        satisfy VacuumIntegrityRequirement by AmplifierStateMachine.failed;
    }

    part amplifier : AmplifierSystem;
}
