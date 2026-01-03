package 'Neuromorphic Computing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def SpikePattern;
    attribute def SynapticWeight :> Real;
    attribute def MembraneVoltage :> ElectricPotentialValue;
    attribute def SpikeRate :> FrequencyValue;
    attribute def LearningRate :> Real;
    attribute def PlasticityWindow :> TimeValue;

    item def NeuralSpike {
        attribute timestamp : TimeValue;
        attribute amplitude : ElectricPotentialValue;
        attribute sourceNeuronId : Integer;
        attribute targetNeuronId : Integer;
    }

    item def SynapticConnection {
        attribute weight : SynapticWeight;
        attribute delay : TimeValue;
        attribute presynapticId : Integer;
        attribute postsynapticId : Integer;
        attribute lastUpdateTime : TimeValue;
    }

    item def TrainingPattern {
        attribute inputSpikes : NeuralSpike[*];
        attribute expectedOutput : SpikePattern;
        attribute patternId : Integer;
    }

    item def RecognitionResult {
        attribute detectedPattern : Integer;
        attribute confidence : Real;
        attribute processingTime : TimeValue;
    }

    port def SpikeInputPort {
        in item inputSpikes : NeuralSpike[*];
    }

    port def SpikeOutputPort {
        out item outputSpikes : NeuralSpike[*];
    }

    port def ControlPort {
        in attribute learningMode : Boolean;
        in attribute resetSignal : Boolean;
        out attribute systemStatus : String;
    }

    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }

    part def SpikingNeuron {
        attribute neuronId : Integer;
        attribute threshold : MembraneVoltage;
        attribute restingPotential : MembraneVoltage;
        attribute refractoryPeriod : TimeValue;
        attribute currentVoltage : MembraneVoltage;
        attribute lastSpikeTime : TimeValue;

        port spikeIn : SpikeInputPort;
        port spikeOut : SpikeOutputPort;

        perform action integrateInputs {
            in incomingSpikes : NeuralSpike[*];
            out voltageChange : MembraneVoltage;
        }

        perform action generateSpike {
            in currentVoltage : MembraneVoltage;
            out spike : NeuralSpike;
            out spiked : Boolean;
        }

        perform action resetMembrane {
            out newVoltage : MembraneVoltage;
        }
    }

    part def SynapticArray {
        attribute arraySize : Integer;
        attribute totalConnections : Integer;

        part synapses : SynapticConnection[*];

        perform action propagateSpike {
            in inputSpike : NeuralSpike;
            out weightedSpikes : NeuralSpike[*];
        }

        perform action updateWeights {
            in preSpike : NeuralSpike;
            in postSpike : NeuralSpike;
            in learningRate : LearningRate;
            out updatedWeight : SynapticWeight;
        }
    }

    part def NeuronLayer {
        attribute layerId : Integer;
        attribute neuronCount : Integer;
        attribute layerType : String;

        part neurons : SpikingNeuron[*];
        part synapticMatrix : SynapticArray;

        port layerInput : SpikeInputPort;
        port layerOutput : SpikeOutputPort;

        perform action processLayer {
            in layerInputSpikes : NeuralSpike[*];
            out layerOutputSpikes : NeuralSpike[*];
        }
    }

    part def STDPLearningEngine {
        attribute learningRate : LearningRate;
        attribute plasticityWindow : PlasticityWindow;
        attribute adaptiveThreshold : Boolean;

        port synapticDataIn;
        port weightUpdateOut;

        perform action computeSTDP {
            in preSpikeTime : TimeValue;
            in postSpikeTime : TimeValue;
            out weightDelta : SynapticWeight;
        }

        perform action applyPlasticity {
            in currentWeight : SynapticWeight;
            in weightChange : SynapticWeight;
            out newWeight : SynapticWeight;
        }
    }

    part def PatternRecognitionCore {
        attribute recognitionAccuracy : Real;
        attribute processingLatency : TimeValue;

        port patternInput : SpikeInputPort;
        port resultOutput;

        perform action analyzePattern {
            in spikePattern : NeuralSpike[*];
            out patternFeatures : Real[*];
        }

        perform action classifyPattern {
            in features : Real[*];
            out classification : RecognitionResult;
        }
    }

    part def MemoryController {
        attribute memoryCapacity : Integer;
        attribute accessTime : TimeValue;

        perform action storePattern {
            in pattern : TrainingPattern;
            out stored : Boolean;
        }

        perform action retrievePattern {
            in patternId : Integer;
            out pattern : TrainingPattern;
        }
    }

    action def InitializeNetwork {
        out networkReady : Boolean;
        out initializedLayers : Integer;
    }

    action def TrainNetwork {
        in trainingData : TrainingPattern[*];
        in epochs : Integer;
        out trainingComplete : Boolean;
        out finalAccuracy : Real;
    }

    action def RecognizePattern {
        in inputPattern : NeuralSpike[*];
        out result : RecognitionResult;
        out processingTime : TimeValue;
    }

    action def AdaptWeights {
        in presynapticActivity : NeuralSpike[*];
        in postsynapticActivity : NeuralSpike[*];
        out weightsUpdated : Boolean;
        out averageWeightChange : Real;
    }

    state def NeuromorphicSystemStates {
        entry; then initialization;

        state initialization {
            entry assign systemMode := "Initializing";
            do action init : InitializeNetwork;
        }
        then calibration;

        state calibration {
            entry assign systemMode := "Calibrating";
            do action calibrateNeurons;
        }
        then ready;

        state ready {
            entry assign systemMode := "Ready";
        }
        then [trainingRequested] training;
        then [inferenceRequested] inference;

        state training {
            entry assign systemMode := "Training";
            
            state loadingData {
                do action loadTrainingSet;
            }
            then learningPhase;

            state learningPhase {
                do action trainNet : TrainNetwork;
            }
            then [trainingComplete] validation;

            state validation {
                do action validateModel;
            }
            then [validationPassed] ready;
            then [validationFailed] learningPhase;
        }

        state inference {
            entry assign systemMode := "Inference";
            
            state processing {
                do action recognize : RecognizePattern;
            }
            then outputResult;

            state outputResult {
                do action deliverResult;
            }
            then ready;
        }

        then [errorDetected] fault;
        then [shutdownRequested] shutdown;

        state fault {
            entry assign systemMode := "Fault";
            do action diagnostics;
        }
        then [faultCleared] ready;
        then [faultCritical] shutdown;

        state shutdown {
            entry assign systemMode := "Shutdown";
            do action safeShutdown;
        }
        then done;

        attribute systemMode : String;
        attribute trainingRequested : Boolean;
        attribute inferenceRequested : Boolean;
        attribute errorDetected : Boolean;
        attribute shutdownRequested : Boolean;
        attribute trainingComplete : Boolean;
        attribute validationPassed : Boolean;
        attribute validationFailed : Boolean;
        attribute faultCleared : Boolean;
        attribute faultCritical : Boolean;
    }

    part def NeuromorphicProcessor {
        doc /*
        A neuromorphic computing system that mimics biological neural networks
        using spiking neurons and spike-timing-dependent plasticity (STDP) for
        real-time pattern recognition and adaptive learning with ultra-low power consumption.
        */

        attribute totalNeurons : Integer;
        attribute totalSynapses : Integer;
        attribute powerConsumption : PowerValue;
        attribute operatingFrequency : FrequencyValue;

        part inputLayer : NeuronLayer {
            attribute :>> layerId = 1;
            attribute :>> layerType = "Input";
            attribute :>> neuronCount = 784;
        }

        part hiddenLayer1 : NeuronLayer {
            attribute :>> layerId = 2;
            attribute :>> layerType = "Hidden";
            attribute :>> neuronCount = 256;
        }

        part hiddenLayer2 : NeuronLayer {
            attribute :>> layerId = 3;
            attribute :>> layerType = "Hidden";
            attribute :>> neuronCount = 256;
        }

        part outputLayer : NeuronLayer {
            attribute :>> layerId = 4;
            attribute :>> layerType = "Output";
            attribute :>> neuronCount = 10;
        }

        part learningEngine : STDPLearningEngine {
            attribute :>> learningRate = 0.01;
            attribute :>> plasticityWindow = 20.0[SI::ms];
        }

        part recognitionCore : PatternRecognitionCore;
        part memoryController : MemoryController;

        port systemInput : SpikeInputPort;
        port systemOutput : SpikeOutputPort;
        port controlInterface : ControlPort;
        port powerSupply : PowerPort;

        connection inputFlow connect systemInput to inputLayer.layerInput;
        connection layer1to2 connect inputLayer.layerOutput to hiddenLayer1.layerInput;
        connection layer2to3 connect hiddenLayer1.layerOutput to hiddenLayer2.layerInput;
        connection hiddenToOutput connect hiddenLayer2.layerOutput to outputLayer.layerInput;
        connection outputFlow connect outputLayer.layerOutput to systemOutput;

        perform action operateNeuromorphicSystem {
            first start;
            then action initialize : InitializeNetwork;
            then merge operationalLoop;

            action configureNetwork {
                action setupTopology;
                then action initializeWeights;
                then action setThresholds;
            }
            then operationalLoop;

            action processingCycle {
                action receiveInput {
                    in externalSpikes : NeuralSpike[*];
                    out processedInput : NeuralSpike[*];
                }
                then action propagateSpikes {
                    in spikes = receiveInput.processedInput;
                    action forwardPass {
                        action inputToHidden;
                        then action hiddenProcessing;
                        then action hiddenToOutput;
                    }
                    then decide;
                        if controlInterface.learningMode then learningUpdate;
                        if not controlInterface.learningMode then inferenceOnly;
                }

                action learningUpdate : AdaptWeights {
                    in presynapticActivity;
                    in postsynapticActivity;
                }
                then operationalLoop;

                action inferenceOnly : RecognizePattern {
                    in inputPattern;
                    out result;
                }
                then operationalLoop;
            }

            accept shutdownCmd;
            then done;
        }
    }

    requirement def NeuromorphicSystemRequirements {
        doc /* Requirements for neuromorphic computing system performance and efficiency. */

        subject neuromorphicSystem : NeuromorphicProcessor;

        requirement powerEfficiencyRequirement {
            doc /* Power consumption shall not exceed 10 watts during inference mode. */
            assume constraint {
                neuromorphicSystem.powerConsumption <= 10.0[SI::W]
            }
        }

        requirement processingLatencyRequirement {
            doc /* Pattern recognition latency shall be less than 1 millisecond. */
            assume constraint {
                neuromorphicSystem.recognitionCore.processingLatency < 1.0[SI::ms]
            }
        }

        requirement learningAccuracyRequirement {
            doc /* Recognition accuracy shall exceed 95% after training convergence. */
            assume constraint {
                neuromorphicSystem.recognitionCore.recognitionAccuracy >= 0.95
            }
        }

        requirement scalabilityRequirement {
            doc /* System shall support at least 1 million neurons and 1 billion synapses. */
            assume constraint {
                neuromorphicSystem.totalNeurons >= 1000000 and
                neuromorphicSystem.totalSynapses >= 1000000000
            }
        }

        requirement realTimeOperationRequirement {
            doc /* System shall process input spikes in real-time with less than 100 microseconds jitter. */
            assume constraint {
                spikeProcessingJitter < 100.0[SI::us]
            }
            attribute spikeProcessingJitter : TimeValue;
        }

        requirement adaptiveLearningRequirement {
            doc /* STDP learning shall continuously adapt synaptic weights based on spike timing. */
            assume constraint {
                neuromorphicSystem.learningEngine.plasticityWindow >= 10.0[SI::ms] and
                neuromorphicSystem.learningEngine.plasticityWindow <= 50.0[SI::ms]
            }
        }
    }

    requirement neuromorphicMission : NeuromorphicSystemRequirements {
        subject system = neuromorphicProcessor;

        doc /*
        The neuromorphic computing system shall perform real-time pattern recognition
        and adaptive learning by emulating biological neural networks through spiking
        neurons and spike-timing-dependent plasticity, achieving brain-like efficiency
        and cognitive capabilities for applications in robotics, edge AI, and autonomous systems.
        */
    }

    part neuromorphicProcessor : NeuromorphicProcessor {
        attribute :>> totalNeurons = 1048576;
        attribute :>> totalSynapses = 1073741824;
        attribute :>> powerConsumption = 8.5[SI::W];
        attribute :>> operatingFrequency = 1.0[SI::GHz];

        satisfy neuromorphicMission.powerEfficiencyRequirement by self;
        satisfy neuromorphicMission.processingLatencyRequirement by recognitionCore;
        satisfy neuromorphicMission.learningAccuracyRequirement by recognitionCore;
        satisfy neuromorphicMission.scalabilityRequirement by self;
        satisfy neuromorphicMission.adaptiveLearningRequirement by learningEngine;
    }
}
