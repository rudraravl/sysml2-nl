package ChemoreceptorSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def ConcentrationValue :> Real;

    enum def ConcentrationUnit {
        molPerLiter;
        partsPerMillion;
    }

    item def ChemicalStimulus {
        attribute concentration : ConcentrationValue;
        attribute moleculeType : String;
        attribute temperature : ISQ::TemperatureValue;
    }

    item def ReceptorPotential {
        attribute voltage : ISQ::VoltageValue;
        attribute duration : ISQ::DurationValue;
    }

    item def NeuralImpulse {
        attribute frequency : Real;
        attribute amplitude : ISQ::VoltageValue;
    }

    item def EffectorSignal {
        attribute commandType : String;
        attribute intensity : Real;
    }

    port def ChemicalInputPort {
        in stimulus : ChemicalStimulus;
    }

    port def ElectricalOutputPort {
        out potential : ReceptorPotential;
    }

    port def NeuralOutputPort {
        out impulse : NeuralImpulse;
    }

    port def EffectorPort {
        out signal : EffectorSignal;
    }

    requirement def SystemObjective {
        doc /* The chemoreceptor system shall detect specific chemical substances in the environment, 
                convert chemical signals into electrical signals, and initiate appropriate physiological responses. */
    }

    requirement <'REQ-001'> primaryFunction : SystemObjective {
        doc /* The system shall continuously monitor the chemical environment, 
                transduce chemical concentrations into neural signals, 
                and trigger effector responses when threshold concentrations are exceeded. */
    }

    part def ChemoreceptorCell;

    requirement <'REQ-002'> sensitivityRequirement {
        doc /* The chemoreceptor shall detect chemical concentrations as low as 0.001 mol/L. */
        subject receptor : ChemoreceptorCell;
        require constraint {
            receptor.detectionThreshold <= 0.001
        }
    }

    requirement <'REQ-003'> responseTimeRequirement {
        doc /* The system shall generate a neural response within 100 milliseconds of stimulus detection. */
    }

    action def BindChemical {
        in stimulus : ChemicalStimulus;
        in threshold : ConcentrationValue;
        out bindingOccurred : Boolean;
        out potential : ReceptorPotential;
    }

    action def GenerateReceptorPotential {
        in bindingStrength : Real;
        out potential : ReceptorPotential;
    }

    action def TransduceToNeuralSignal {
        in potential : ReceptorPotential;
        in threshold : ISQ::VoltageValue;
        out impulse : NeuralImpulse;
    }

    action def ProcessNeuralSignal {
        in impulse : NeuralImpulse;
        out signal : EffectorSignal;
    }

    action def ChemoreceptionCycle {
        in stimulus : ChemicalStimulus;
        in detectionThreshold : ConcentrationValue;
        in voltageThreshold : ISQ::VoltageValue;
        out effectorSignal : EffectorSignal;

        first start;
        then action bind : BindChemical {
            in stimulus = ChemoreceptionCycle::stimulus;
            in threshold = detectionThreshold;
            out bindingOccurred;
            out potential;
        }
        then decide;
            if bind.bindingOccurred then generatePotential;
            else done;
        action generatePotential : GenerateReceptorPotential {
            in bindingStrength = 1.0;
            out potential;
        }
        then action transduce : TransduceToNeuralSignal {
            in potential = generatePotential.potential;
            in threshold = voltageThreshold;
            out impulse;
        }
        then action process : ProcessNeuralSignal {
            in impulse = transduce.impulse;
            out signal = ChemoreceptionCycle::effectorSignal;
        }
        then done;
    }

    state def ChemoreceptorState {
        entry; then Resting;

        state Resting {
            accept stimulusArrival;
            transition to Binding;
        }

        state Binding {
            do action bindingAction : BindChemical;
            accept bindingComplete;
            transition to Transducing;
        }

        state Transducing {
            do action transductionAction : GenerateReceptorPotential;
            accept potentialGenerated;
            transition to Signaling;
        }

        state Signaling {
            do action signalingAction : TransduceToNeuralSignal;
            accept signalSent;
            transition to Recovery;
        }

        state Recovery {
            accept recoveryComplete;
            transition to Resting;
        }
    }

    part def ChemoreceptorCell {
        attribute detectionThreshold : ConcentrationValue;
        attribute voltageThreshold : ISQ::VoltageValue;
        
        port chemicalInput : ChemicalInputPort;
        port electricalOutput : ElectricalOutputPort;

        perform action detectAndBind : BindChemical {
            in stimulus = chemicalInput.stimulus;
            in threshold = detectionThreshold;
            out potential = electricalOutput.potential;
        }

        state lifecycle : ChemoreceptorState;
    }

    part def NeuralTransmitter {
        port potentialInput : ElectricalOutputPort;
        port neuralOutput : NeuralOutputPort;

        perform action transmit : TransduceToNeuralSignal {
            in potential = potentialInput.potential;
            out impulse = neuralOutput.impulse;
        }
    }

    part def SignalProcessor {
        port neuralInput : NeuralOutputPort;
        port effectorOutput : EffectorPort;

        perform action processSignal : ProcessNeuralSignal {
            in impulse = neuralInput.impulse;
            out signal = effectorOutput.signal;
        }
    }

    part def EffectorUnit {
        port commandInput : EffectorPort;
        attribute responseActive : Boolean;

        perform action executeResponse {
            in command = commandInput.signal;
        }
    }

    part def ChemoreceptorSystem {
        doc /* Complete chemoreceptor system integrating detection, transduction, and response mechanisms. */

        port environmentInterface : ChemicalInputPort;
        port responseInterface : EffectorPort;

        part receptor : ChemoreceptorCell {
            attribute detectionThreshold = 0.001;
            attribute voltageThreshold = 50.0 [SI::mV];
        }

        part transmitter : NeuralTransmitter;
        part processor : SignalProcessor;
        part effector : EffectorUnit;

        connect environmentInterface to receptor.chemicalInput;
        connect receptor.electricalOutput to transmitter.potentialInput;
        connect transmitter.neuralOutput to processor.neuralInput;
        connect processor.effectorOutput to effector.commandInput;
        connect effector.commandInput to responseInterface;

        perform action systemBehavior : ChemoreceptionCycle {
            in stimulus = environmentInterface.stimulus;
            in detectionThreshold = receptor.detectionThreshold;
            in voltageThreshold = receptor.voltageThreshold;
            out effectorSignal = responseInterface.signal;
        }

        satisfy primaryFunction;
        satisfy sensitivityRequirement;
        satisfy responseTimeRequirement;
    }

    part chemoreceptorSystem : ChemoreceptorSystem;
}
