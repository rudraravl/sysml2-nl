package QuantumComputingSystem {
    import ScalarValues::*;

    value def Temperature :> Real { unit 'K'; }
    value def QubitCount :> Integer;

    item def QuantumAlgorithm;
    item def ControlPulse;
    item def QuantumState;
    item def QuantumSignal;
    item def RawDigitalData;
    item def CorrectedData;
    item def FinalResult;
    item def CoolingCommand;

    requirement def QuantumComputationRequirement {
        doc /* The system shall execute quantum algorithms to solve complex computational problems. */
        subject quantumSystem : QuantumComputingSystem;
        objective {
            quantumSystem.executeAlgorithm().result->notEmpty()
        }
    }

    requirement def CoolingRequirement {
        doc /* The cryogenic cooling system shall chill the QPU to 0.015 K. */
        subject coolingSystem : CryogenicCoolingSystem;
        objective {
            coolingSystem.targetTemperature == 0.015 [K]
        }
    }

    requirement def QubitCountRequirement {
        doc /* The QPU shall contain 127 qubits. */
        subject qpu : QPU;
        objective {
            qpu.qubitCount == 127
        }
    }

    part def QuantumComputingSystem {
        requirement ref quantumComputationReq : QuantumComputationRequirement;
        requirement ref coolingReq : CoolingRequirement;
        requirement ref qubitCountReq : QubitCountRequirement;

        port in algorithmInput : QuantumAlgorithm;
        port out resultOutput : FinalResult;

        part classicalControlSystem : ClassicalControlSystem;
        part cryogenicCoolingSystem : CryogenicCoolingSystem;
        part qpu : QPU;
        part readoutSystem : ReadoutSystem;
        part errorCorrectionUnit : ErrorCorrectionUnit;

        connection algorithmFlow from algorithmInput to classicalControlSystem.algorithmInput;
        connection controlPulseFlow from classicalControlSystem.pulseOutput to qpu.pulseInput;
        connection coolingFlow from cryogenicCoolingSystem.coolingOutput to qpu.coolingInput;
        connection quantumStateFlow from qpu.stateOutput to readoutSystem.stateInput;
        connection rawDataFlow from readoutSystem.dataOutput to errorCorrectionUnit.dataInput;
        connection correctedDataFlow from errorCorrectionUnit.dataOutput to classicalControlSystem.correctedDataInput;
        connection resultFlow from classicalControlSystem.resultOutput to resultOutput;

        exhibit state QuantumSystemStateMachine {
            state coolingDown;
            state ready;
            state executing;
            state measuring;
            state correcting;

            transition coolingDown -> ready when cryogenicCoolingSystem.isAtTargetTemp;
            transition ready -> executing when classicalControlSystem.algorithmReceived;
            transition executing -> measuring when qpu.computationComplete;
            transition measuring -> correcting when readoutSystem.measurementComplete;
            transition correcting -> ready when errorCorrectionUnit.correctionComplete;
        }

        action def executeAlgorithm {
            in algorithm : QuantumAlgorithm;
            out result : FinalResult;
        }
    }

    part def ClassicalControlSystem {
        port in algorithmInput : QuantumAlgorithm;
        port in correctedDataInput : CorrectedData;
        port out pulseOutput : ControlPulse;
        port out resultOutput : FinalResult;

        attribute algorithmReceived : Boolean = false;

        action def compileAlgorithm {
            in algorithm : QuantumAlgorithm;
            out pulses : ControlPulse;
        }

        action def processResult {
            in data : CorrectedData;
            out result : FinalResult;
        }
    }

    part def CryogenicCoolingSystem {
        port out coolingOutput : CoolingCommand;
        attribute targetTemperature : Temperature = 0.015 [K];
        attribute isAtTargetTemp : Boolean = false;

        action def coolDown {
            out cooling : CoolingCommand;
        }
    }

    part def QPU {
        port in pulseInput : ControlPulse;
        port in coolingInput : CoolingCommand;
        port out stateOutput : QuantumState;

        attribute qubitCount : QubitCount = 127;
        attribute computationComplete : Boolean = false;

        action def performQuantumOperations {
            in pulses : ControlPulse;
            out state : QuantumState;
        }
    }

    part def ReadoutSystem {
        port in stateInput : QuantumState;
        port out dataOutput : RawDigitalData;

        attribute measurementComplete : Boolean = false;

        action def measureAndAmplify {
            in state : QuantumState;
            out data : RawDigitalData;
        }
    }

    part def ErrorCorrectionUnit {
        port in dataInput : RawDigitalData;
        port out dataOutput : CorrectedData;

        attribute correctionComplete : Boolean = false;

        action def correctErrors {
            in rawData : RawDigitalData;
            out correctedData : CorrectedData;
        }
    }
}
