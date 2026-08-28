package NeuromorphicProcessorModel {
    attribute def Voltage :> ISQ::electricPotential;
    attribute def ThresholdVoltage :> Voltage;
    attribute def TimeValue :> ISQ::time;
    attribute def RefractoryPeriod :> TimeValue;
    attribute def SynapticWeight :> ScalarValues::Real;
    attribute def PowerValue :> ISQ::power;
    attribute def SpikeRate :> ISQ::frequency;
    attribute def NeuronCount :> ScalarValues::Integer;
    attribute def LayerIndex :> ScalarValues::Integer;

    item def Spike {
        attribute timestamp : TimeValue;
        attribute sourceId : ScalarValues::Integer;
        attribute amplitude : Voltage;
    }
    item def LabeledPattern {
        attribute inputData : ScalarValues::Real[0..*];
        attribute label : ScalarValues::Integer;
    }
    item def ClassificationResult {
        attribute classId : ScalarValues::Integer;
        attribute confidence : ScalarValues::Real;
    }

    attribute def TrainCommand;
    attribute def InferCommand;
    attribute def TrainingComplete;
    attribute def InferenceComplete;
    attribute def FaultSignal;
    attribute def ShutdownCommand;

    port def SpikePort {
        out item spikeOut : Spike;
        in item spikeIn : Spike;
    }
    port def SynapsePort {
        in item preSpike : Spike;
        in item postSpike : Spike;
        out attribute weight : SynapticWeight;
    }
    port def LearningPort {
        in item preSynapticSpike : Spike;
        in item postSynapticSpike : Spike;
        out attribute updatedWeight : SynapticWeight;
    }
    port def DataPort {
        in item pattern : LabeledPattern;
        out item result : ClassificationResult;
    }
    port def ControlPort {
        in attribute command : ScalarValues::String;
        out attribute status : ScalarValues::String;
    }

    action def IntegrateAndFire {
        in item incomingSpike : Spike;
        in attribute currentVoltage : Voltage;
        out attribute newVoltage : Voltage;
        out item outgoingSpike : Spike;
    }
    action def ResetMembrane {
        out attribute resetVoltage : Voltage;
    }
    action def TransmitSpike {
        in item inputSpike : Spike;
        in attribute synapseWeight : SynapticWeight;
        out item weightedSpike : Spike;
    }
    action def UpdateWeight {
        in attribute currentWeight : SynapticWeight;
        in attribute deltaWeight : SynapticWeight;
        out attribute newWeight : SynapticWeight;
    }
    action def MonitorSpikeTiming {
        in item preSpike : Spike;
        in item postSpike : Spike;
        out attribute timeDelta : TimeValue;
    }
    action def ApplySTDP {
        in attribute timeDelta : TimeValue;
        in attribute currentWeight : SynapticWeight;
        out attribute updatedWeight : SynapticWeight;
    }
    action def Initialize {
        out attribute status : ScalarValues::String;
    }
    action def Calibrate {
        out attribute calibrationStatus : ScalarValues::String;
    }
    action def Train {
        in item pattern : LabeledPattern;
        out attribute trainingError : ScalarValues::Real;
    }
    action def Infer {
        in item pattern : LabeledPattern;
        out item result : ClassificationResult;
    }
    action def DetectFault {
        out attribute faultDetected : ScalarValues::Boolean;
        out attribute faultDescription : ScalarValues::String;
    }
    action def SafeShutdown {
        out attribute shutdownStatus : ScalarValues::String;
    }

    state def NeuronState {
        entry; then Resting;
        state Resting;
        state Integrating {
            do action integrateInputs :>> IntegrateAndFire;
        }
        state Firing {
            do action emitSpike :>> TransmitSpike;
        }
        state Refractory {
            do action recover :>> ResetMembrane;
        }
        transition first Resting then Integrating;
        transition first Integrating then Firing;
        transition first Firing then Refractory;
        transition first Refractory then Resting;
    }

    state def LearningState {
        entry; then Idle;
        state Idle;
        state Monitoring {
            do action monitorTiming :>> MonitorSpikeTiming;
        }
        state Updating {
            do action applySTDPRule :>> ApplySTDP;
        }
        transition first Idle then Monitoring;
        transition first Monitoring then Updating;
        transition first Updating then Idle;
    }

    state def ProcessorState {
        entry; then Initialization;
        state Initialization {
            do action initProcessor :>> Initialize;
        }
        state Calibration {
            do action calibrateProcessor :>> Calibrate;
        }
        state Ready;
        state Training {
            do action trainProcessor :>> Train;
        }
        state Inference {
            do action inferProcessor :>> Infer;
        }
        state FaultDetected {
            do action runFaultDetection :>> DetectFault;
        }
        state Shutdown {
            do action performShutdown :>> SafeShutdown;
        }
        transition first Initialization then Calibration;
        transition first Calibration then Ready;
        transition first Ready accept TrainCommand then Training;
        transition first Ready accept InferCommand then Inference;
        transition first Training accept TrainingComplete then Ready;
        transition first Inference accept InferenceComplete then Ready;
        transition first Ready accept FaultSignal then FaultDetected;
        transition first Training accept FaultSignal then FaultDetected;
        transition first Inference accept FaultSignal then FaultDetected;
        transition first FaultDetected then Shutdown;
        transition first Ready accept ShutdownCommand then Shutdown;
    }

    part def SpikingNeuron {
        attribute neuronId : ScalarValues::Integer;
        attribute membraneVoltage : Voltage;
        attribute firingThreshold : ThresholdVoltage;
        attribute refractoryPeriod : RefractoryPeriod;
        attribute lastFiringTime : TimeValue;
        attribute currentRefractoryEnd : TimeValue;
        attribute powerConsumption : PowerValue;
        port spikePort : SpikePort;
        perform action integrateAndFire;
        perform action resetMembrane;
        exhibit state neuronState : NeuronState;
    }

    part def Synapse {
        attribute synapseId : ScalarValues::Integer;
        attribute weight : SynapticWeight;
        attribute delay : TimeValue;
        attribute preSynapticNeuronId : ScalarValues::Integer;
        attribute postSynapticNeuronId : ScalarValues::Integer;
        port synapsePort : SynapsePort;
        port learningPort : LearningPort;
        perform action transmitSpike;
        perform action updateWeight;
    }

    part def NeuralLayer {
        attribute layerIndex : LayerIndex;
        attribute neuronCount : NeuronCount;
        part neurons : SpikingNeuron[0..*];
    }

    part def InputLayer :> NeuralLayer {
        attribute sensorInterfaceType : ScalarValues::String;
    }

    part def HiddenLayer :> NeuralLayer {
        attribute activationFunction : ScalarValues::String;
    }

    part def OutputLayer :> NeuralLayer {
        attribute classificationClasses : ScalarValues::Integer;
    }

    part def LearningEngine {
        attribute learningRule : ScalarValues::String = "STDP";
        attribute positiveWeightDelta : SynapticWeight;
        attribute negativeWeightDelta : SynapticWeight;
        attribute timingWindow : TimeValue;
        port learningControlPort : ControlPort;
        perform action monitorSpikeTiming;
        perform action applySTDP;
        perform action strengthenSynapse;
        perform action weakenSynapse;
        exhibit state learningState : LearningState;
    }

    part def NeuromorphicProcessor {
        attribute processorId : ScalarValues::Integer;
        attribute totalNeuronCount : NeuronCount;
        attribute totalSynapseCount : ScalarValues::Integer;
        attribute powerBudget : PowerValue;
        attribute clockFrequency : SpikeRate;
        part inputLayer : InputLayer;
        part hiddenLayer1 : HiddenLayer;
        part hiddenLayer2 : HiddenLayer;
        part outputLayer : OutputLayer;
        part learningEngine : LearningEngine;
        part synapseNetwork : Synapse[0..*];
        port dataPort : DataPort;
        port controlPort : ControlPort;
        perform action initialize;
        perform action calibrate;
        perform action train;
        perform action infer;
        perform action detectFault;
        perform action safeShutdown;
        exhibit state processorState : ProcessorState;
    }

    requirement def PowerEfficiencyRequirement {
        doc "The neuromorphic processor shall operate within ultra-low power constraints.";
        attribute maxPower : PowerValue = 1;
        subject processor : NeuromorphicProcessor;
        require { processor.powerBudget <= maxPower }
    }
    requirement def PatternRecognitionRequirement {
        doc "The processor shall perform real-time pattern recognition using spiking neural networks.";
        attribute maxLatency : TimeValue = 0.01;
        subject processor : NeuromorphicProcessor;
        require { processor.clockFrequency >= 100 }
    }
    requirement def AdaptiveLearningRequirement {
        doc "The processor shall implement STDP-based learning for continuous adaptation.";
        subject learningEngine : LearningEngine;
        require { learningEngine.learningRule == "STDP" }
    }
    requirement def ScalabilityRequirement {
        doc "The processor shall support thousands of spiking neurons across multiple layers.";
        attribute minNeurons : NeuronCount = 1000;
        subject processor : NeuromorphicProcessor;
        require { processor.totalNeuronCount >= minNeurons }
    }
    requirement def FaultToleranceRequirement {
        doc "The processor shall detect faults and perform safe shutdown.";
        subject processor : NeuromorphicProcessor;
    }

    part neuromorphicProcessor : NeuromorphicProcessor {
        attribute processorId = 1;
        attribute totalNeuronCount = 4000;
        attribute totalSynapseCount = 100000;
        attribute powerBudget = 0.5;
        attribute clockFrequency = 1000;
        port dataPort : DataPort;
        port controlPort : ControlPort;
        part inputLayer : InputLayer {
            attribute layerIndex = 0;
            attribute neuronCount = 500;
            part neurons : SpikingNeuron[500];
        }
        part hiddenLayer1 : HiddenLayer {
            attribute layerIndex = 1;
            attribute neuronCount = 1500;
            attribute activationFunction = "LeakyIntegrateAndFire";
            part neurons : SpikingNeuron[1500];
        }
        part hiddenLayer2 : HiddenLayer {
            attribute layerIndex = 2;
            attribute neuronCount = 1500;
            attribute activationFunction = "LeakyIntegrateAndFire";
            part neurons : SpikingNeuron[1500];
        }
        part outputLayer : OutputLayer {
            attribute layerIndex = 3;
            attribute neuronCount = 500;
            attribute classificationClasses = 10;
            part neurons : SpikingNeuron[500];
        }
        part learningEngine : LearningEngine {
            attribute learningRule = "STDP";
            attribute positiveWeightDelta = 0.01;
            attribute negativeWeightDelta = -0.01;
            attribute timingWindow = 0.02;
            port learningControlPort : ControlPort;
        }
        part synapseNetwork : Synapse[0..*];
        connect inputLayer.neurons.spikePort to hiddenLayer1.neurons.spikePort;
        connect hiddenLayer1.neurons.spikePort to hiddenLayer2.neurons.spikePort;
        connect hiddenLayer2.neurons.spikePort to outputLayer.neurons.spikePort;
        connect learningEngine.learningControlPort to controlPort;
        satisfy PowerEfficiencyRequirement by self;
        satisfy PatternRecognitionRequirement by self;
        satisfy AdaptiveLearningRequirement by learningEngine;
        satisfy ScalabilityRequirement by self;
        satisfy FaultToleranceRequirement by self;
    }
}
