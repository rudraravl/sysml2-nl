package ChemoreceptorSystemModel {

    import ScalarValues::*;

    // ===== Value Types =====

    value type Concentration :> Real {
        attribute unit : String = "mol/L";
    }

    value type Voltage :> Real {
        attribute unit : String = "mV";
    }

    value type Frequency :> Real {
        attribute unit : String = "Hz";
    }

    value type TimeDuration :> Real {
        attribute unit : String = "ms";
    }

    value type Dimensionless :> Real {
    }

    // ===== Item Types =====

    item def ChemicalStimulus {
        attribute concentration : Concentration;
        attribute moleculeType : String;
        attribute pH : Real;
    }

    item def ReceptorPotential {
        attribute amplitude : Voltage;
        attribute duration : TimeDuration;
        attribute isGraded : Boolean = true;
    }

    item def NeuralImpulse {
        attribute frequency : Frequency;
        attribute amplitude : Voltage;
        attribute duration : TimeDuration;
        attribute impulseCount : Integer;
    }

    item def EffectorCommand {
        attribute commandType : String;
        attribute intensity : Dimensionless;
        attribute targetOrgan : String;
    }

    // ===== Port Definitions =====

    port def ChemicalInputPort {
        in item stimulus : ChemicalStimulus;
    }

    port def ReceptorPotentialOutputPort {
        out item potential : ReceptorPotential;
    }

    port def ReceptorPotentialInputPort {
        in item potential : ReceptorPotential;
    }

    port def NeuralImpulseOutputPort {
        out item impulse : NeuralImpulse;
    }

    port def NeuralImpulseInputPort {
        in item impulse : NeuralImpulse;
    }

    port def CommandOutputPort {
        out item command : EffectorCommand;
    }

    port def CommandInputPort {
        in item command : EffectorCommand;
    }

    // ===== Requirements =====

    requirement def DetectionSensitivityRequirement {
        doc "The chemoreceptor cell must detect chemical concentrations as low as 0.0001 mol/L.";
        subject receptorCell : ChemoreceptorCell;
        objective constraint {
            receptorCell.detectionThreshold <= 0.0001
        }
    }

    requirement def ResponseTimeRequirement {
        doc "The system must generate a physiological response within 100 ms of initial detection.";
        subject system : ChemoreceptorSystem;
        objective constraint {
            system.totalResponseTime <= 100
        }
    }

    requirement def SignalTransductionRequirement {
        doc "The neural transmitter must fire only when receptor potential exceeds threshold.";
        subject transmitter : NeuralTransmitter;
        objective constraint {
            transmitter.firingThreshold >= 2
        }
    }

    requirement def NeuralImpulseGenerationRequirement {
        doc "The neural transmitter must produce standardized action potentials.";
        subject transmitter : NeuralTransmitter;
        objective constraint {
            transmitter.standardImpulseAmplitude == 100
        }
    }

    requirement def SignalProcessingRequirement {
        doc "The signal processor must interpret impulse frequency to determine response strength.";
        subject processor : SignalProcessor;
        objective constraint {
            processor.maxResponseTime <= 100
        }
    }

    requirement def EffectorActivationRequirement {
        doc "The effector unit must activate within 20 ms of receiving command.";
        subject effector : EffectorUnit;
        objective constraint {
            effector.activationTime <= 20
        }
    }

    requirement def ReceptorRecoveryRequirement {
        doc "The receptor cell must return to resting state after each stimulus cycle.";
        subject receptorCell : ChemoreceptorCell;
        objective constraint {
            receptorCell.recoveryTime <= 10
        }
    }

    // ===== Chemoreceptor Cell =====

    part def ChemoreceptorCell {
        port chemicalInput : ChemicalInputPort;
        port potentialOutput : ReceptorPotentialOutputPort;

        attribute detectionThreshold : Concentration := 0.0001;
        attribute restingPotential : Voltage := -70;
        attribute receptorPotentialAmplitude : Voltage := 5;
        attribute bindingTime : TimeDuration := 2;
        attribute transductionTime : TimeDuration := 5;
        attribute recoveryTime : TimeDuration := 10;
        attribute maxReceptorPotential : Voltage := 20;

        attribute currentStimulus : ChemicalStimulus;
        attribute currentPotential : ReceptorPotential;
        attribute isRecovering : Boolean := false;

        action def UpdateReceptorPotential {
            in stimulus : ChemicalStimulus;
            out potential : ReceptorPotential;
            attribute calculatedAmplitude : Voltage;
            calculatedAmplitude = receptorPotentialAmplitude * (stimulus.concentration / detectionThreshold);
            if calculatedAmplitude > maxReceptorPotential {
                potential.amplitude = maxReceptorPotential;
            } else {
                potential.amplitude = calculatedAmplitude;
            }
            potential.duration = transductionTime;
            potential.isGraded = true;
        }

        state def ReceptorCellStates {
            entry; then Resting;

            state Resting {
                entry {
                    currentPotential.amplitude = restingPotential;
                    isRecovering = false;
                }
            }

            state Binding {
                entry {
                    currentStimulus = chemicalInput.stimulus;
                }
            }

            state Transducing {
                entry {
                    action updatePotential : UpdateReceptorPotential {
                        in stimulus = currentStimulus;
                        out potential = currentPotential;
                    }
                }
            }

            state Sending {
                entry {
                    potentialOutput.potential = currentPotential;
                }
            }

            state Recovery {
                entry {
                    currentPotential.amplitude = restingPotential;
                    isRecovering = true;
                }
            }

            transition RestingToBinding first Resting
                if chemicalInput.stimulus.concentration >= detectionThreshold
                then Binding;

            transition BindingToTransducing first Binding
                then Transducing;

            transition TransducingToSending first Transducing
                then Sending;

            transition SendingToRecovery first Sending
                then Recovery;

            transition RecoveryToResting first Recovery
                then Resting;
        }

        exhibit state ReceptorCellStates;
    }

    // ===== Neural Transmitter =====

    part def NeuralTransmitter {
        port potentialInput : ReceptorPotentialInputPort;
        port impulseOutput : NeuralImpulseOutputPort;

        attribute firingThreshold : Voltage := 2;
        attribute amplificationFactor : Dimensionless := 20;
        attribute standardImpulseAmplitude : Voltage := 100;
        attribute impulseDuration : TimeDuration := 1;
        attribute refractoryPeriod : TimeDuration := 2;
        attribute maxFiringRate : Frequency := 500;

        action def TransmitSignal {
            in potential : ReceptorPotential;
            out impulse : NeuralImpulse;
            attribute calculatedFrequency : Frequency;
            if potential.amplitude >= firingThreshold {
                calculatedFrequency = potential.amplitude * amplificationFactor;
                if calculatedFrequency > maxFiringRate {
                    impulse.frequency = maxFiringRate;
                } else {
                    impulse.frequency = calculatedFrequency;
                }
                impulse.amplitude = standardImpulseAmplitude;
                impulse.duration = impulseDuration;
                impulse.impulseCount = (potential.duration / (impulseDuration + refractoryPeriod)) as Integer;
            }
        }

        action transmit : TransmitSignal {
            in potential = potentialInput.potential;
            out impulse = impulseOutput.impulse;
        }
    }

    // ===== Signal Processor =====

    part def SignalProcessor {
        port impulseInput : NeuralImpulseInputPort;
        port commandOutput : CommandOutputPort;

        attribute maxResponseTime : TimeDuration := 100;
        attribute strongResponseThreshold : Frequency := 50;
        attribute moderateResponseThreshold : Frequency := 20;
        attribute processingTime : TimeDuration := 5;
        attribute baselineFrequency : Frequency := 0;

        action def ProcessSignal {
            in impulse : NeuralImpulse;
            out command : EffectorCommand;
            if impulse.frequency >= strongResponseThreshold {
                command.commandType = "strong_response";
                command.intensity = 1.0;
                command.targetOrgan = "primary_effector";
            } else if impulse.frequency >= moderateResponseThreshold {
                command.commandType = "moderate_response";
                command.intensity = 0.7;
                command.targetOrgan = "primary_effector";
            } else if impulse.frequency > baselineFrequency {
                command.commandType = "weak_response";
                command.intensity = 0.3;
                command.targetOrgan = "secondary_effector";
            }
        }

        action process : ProcessSignal {
            in impulse = impulseInput.impulse;
            out command = commandOutput.command;
        }
    }

    // ===== Effector Unit =====

    part def EffectorUnit {
        port commandInput : CommandInputPort;

        attribute effectorType : String;
        attribute activationTime : TimeDuration := 20;
        attribute deactivationTime : TimeDuration := 50;
        attribute currentIntensity : Dimensionless := 0.0;
        attribute isActive : Boolean := false;

        action def ExecuteResponse {
            in command : EffectorCommand;
            if command.commandType == "strong_response" {
                currentIntensity = command.intensity;
                isActive = true;
            } else if command.commandType == "moderate_response" {
                currentIntensity = command.intensity;
                isActive = true;
            } else {
                currentIntensity = command.intensity;
                isActive = true;
            }
        }

        action def DeactivateEffector {
            currentIntensity = 0.0;
            isActive = false;
        }

        action execute : ExecuteResponse {
            in command = commandInput.command;
        }

        action deactivate : DeactivateEffector;
    }

    // ===== Environment =====

    part def ChemicalEnvironment {
        port chemicalOutput : ChemicalInputPort;
        attribute ambientConcentration : Concentration := 0.0;
        attribute stimulusConcentration : Concentration := 0.005;
        attribute stimulusMoleculeType : String := "glucose";
        attribute stimulusPH : Real := 7.4;

        action def ReleaseStimulus {
            out stimulus : ChemicalStimulus;
            stimulus.concentration = stimulusConcentration;
            stimulus.moleculeType = stimulusMoleculeType;
            stimulus.pH = stimulusPH;
        }

        action release : ReleaseStimulus {
            out stimulus = chemicalOutput.stimulus;
        }
    }

    // ===== System =====

    part def ChemoreceptorSystem {
        port externalChemicalInput : ChemicalInputPort;

        part environment : ChemicalEnvironment;
        part receptorCell : ChemoreceptorCell;
        part transmitter : NeuralTransmitter;
        part processor : SignalProcessor;
        part effector : EffectorUnit;

        connect externalChemicalInput to environment.chemicalOutput;
        connect environment.chemicalOutput to receptorCell.chemicalInput;
        connect receptorCell.potentialOutput to transmitter.potentialInput;
        connect transmitter.impulseOutput to processor.impulseInput;
        connect processor.commandOutput to effector.commandInput;

        attribute totalResponseTime : TimeDuration := 100;
        attribute receptorCellTime : TimeDuration := 17;
        attribute transmitterTime : TimeDuration := 3;
        attribute processorTime : TimeDuration := 5;
        attribute effectorTime : TimeDuration := 20;

        satisfaction satisfyDetectionSensitivity : DetectionSensitivityRequirement by receptorCell;
        satisfaction satisfyResponseTime : ResponseTimeRequirement by self;
        satisfaction satisfySignalTransduction : SignalTransductionRequirement by transmitter;
        satisfaction satisfyNeuralImpulse : NeuralImpulseGenerationRequirement by transmitter;
        satisfaction satisfySignalProcessing : SignalProcessingRequirement by processor;
        satisfaction satisfyEffectorActivation : EffectorActivationRequirement by effector;
        satisfaction satisfyReceptorRecovery : ReceptorRecoveryRequirement by receptorCell;
    }

    // ===== System Usage =====

    part chemoreceptorSystemInstance : ChemoreceptorSystem;
}
