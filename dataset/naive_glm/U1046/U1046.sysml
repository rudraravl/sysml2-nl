package NeuromorphicProcessor {

    // ---- Value Types with Units ----
    value type Voltage :> Real { unit 'mV'; }
    value type Time :> Real { unit 'ms'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Power :> Real { unit 'mW'; }
    value type Conductance :> Real { unit 'µS'; }
    value type Dimensionless :> Real;
    value type Energy :> Real { unit 'pJ'; }

    // ---- Item Types ----
    item def Spike {
        attribute timestamp : Time;
        attribute sourceId : Integer;
        attribute destinationId : Integer;
        attribute amplitude : Dimensionless := 1.0;
    }

    item def LabeledPattern {
        attribute data : Real[0..*];
        attribute label : String;
        attribute timestamp : Time;
    }

    item def ClassificationResult {
        attribute label : String;
        attribute confidence : Dimensionless;
        attribute latency : Time;
    }

    item def WeightUpdate {
        attribute synapseId : Integer;
        attribute deltaWeight : Dimensionless;
        attribute preSpikeTime : Time;
        attribute postSpikeTime : Time;
    }

    item def FaultSignal {
        attribute faultType : String;
        attribute location : String;
        attribute severity : Dimensionless;
    }

    // ---- Spiking Neuron ----
    part def SpikingNeuron {
        attribute neuronId : Integer;
        attribute membraneVoltage : Voltage := -70 [mV];
        attribute restPotential : Voltage := -70 [mV];
        attribute firingThreshold : Voltage := 55 [mV];
        attribute refractoryPeriod : Time := 2 [ms];
        attribute leakTimeConstant : Time := 10 [ms];
        attribute lastSpikeTime : Time := 0 [ms];
        attribute isInRefractory : Boolean := false;
        attribute spikeCount : Integer := 0;

        port inSpike : Spike[*];
        port outSpike : Spike[*];

        action def Integrate {
            input incomingSpike : Spike;
            attribute deltaV : Voltage;
            // membraneVoltage += deltaV based on incoming spike
        }

        action def Fire {
            // emit spike when threshold exceeded and not refractory
            out emittedSpike : Spike;
        }

        action def Leak {
            // decay membrane voltage toward rest potential
        }

        action def Reset {
            // reset membrane voltage after firing, enter refractory
        }

        exhibit action IntegrateAndFire {
            action receive : Integrate;
            action checkThreshold;
            action fire : Fire;
            action reset : Reset;
            action leak : Leak;
            // sequential flow
        }
    }

    // ---- Synapse ----
    part def Synapse {
        attribute synapseId : Integer;
        attribute preNeuronId : Integer;
        attribute postNeuronId : Integer;
        attribute weight : Dimensionless := 0.5;
        attribute delay : Time := 1 [ms];
        attribute lastPreSpikeTime : Time := 0 [ms];
        attribute lastPostSpikeTime : Time := 0 [ms];
        attribute maxWeight : Dimensionless := 1.0;
        attribute minWeight : Dimensionless := 0.0;

        port inPreSpike : Spike;
        port outPostSpike : Spike;

        action def Transmit {
            input spike : Spike;
            attribute weightedAmplitude : Dimensionless;
            // weightedAmplitude = spike.amplitude * weight
            // emit delayed spike
        }

        action def ApplySTDP {
            input preTime : Time;
            input postTime : Time;
            attribute deltaT : Time;
            attribute deltaW : Dimensionless;
            // deltaT = postTime - preTime
            // if 0 < deltaT < stdpWindow: deltaW = potentiationFactor * exp(-deltaT / tauPlus)
            // if -stdpWindow < deltaT < 0: deltaW = -depressionFactor * exp(deltaT / tauMinus)
            // weight = clamp(weight + deltaW, minWeight, maxWeight)
        }
    }

    // ---- Neuron Layer ----
    part def NeuronLayer {
        attribute layerName : String;
        attribute neuronCount : Integer;
        part neurons : SpikingNeuron[neuronCount];

        port inLayerInput : Spike[*];
        port outLayerOutput : Spike[*];

        connection layerInputToNeurons connect inLayerInput to neurons.inSpike;
        connection neuronsToLayerOutput connect neurons.outSpike to outLayerOutput;
    }

    // ---- Learning Engine ----
    part def LearningEngine {
        attribute learningRate : Dimensionless := 0.01;
        attribute stdpWindow : Time := 20 [ms];
        attribute potentiationFactor : Dimensionless := 0.1;
        attribute depressionFactor : Dimensionless := 0.12;
        attribute tauPlus : Time := 20 [ms];
        attribute tauMinus : Time := 20 [ms];
        attribute isEnabled : Boolean := true;

        port inSpikeEvents : Spike[*];
        port outWeightUpdates : WeightUpdate[*];

        part synapseRegistry : Synapse[0..*];

        action def MonitorSpikeTiming {
            input spike : Spike;
            // record timestamp and source/destination
        }

        action def EvaluateSTDP {
            input synapse : Synapse;
            // invoke synapse.ApplySTDP with pre/post timing
        }

        action def UpdateWeights {
            input update : WeightUpdate;
            // apply weight change to target synapse
        }

        exhibit action ContinuousLearning {
            action monitor : MonitorSpikeTiming;
            action evaluate : EvaluateSTDP;
            action update : UpdateWeights;
            // continuous loop while isEnabled
        }
    }

    // ---- Fault Manager ----
    part def FaultManager {
        attribute faultThreshold : Dimensionless := 0.8;
        attribute isFaultActive : Boolean := false;

        port inFaultSignal : FaultSignal;
        port outShutdownCommand;

        action def DetectFault {
            input signal : FaultSignal;
            // evaluate severity against threshold
        }

        action def InitiateSafeShutdown {
            // sequence power-down of all layers
        }
    }

    // ---- Power Manager ----
    part def PowerManager {
        attribute nominalPower : Power := 50 [mW];
        attribute currentPower : Power;
        attribute voltageRail : Voltage := 1000 [mV];
        attribute isPowered : Boolean := true;

        action def PowerOn {
            // ramp up voltage rails
        }

        action def PowerOff {
            // ramp down voltage rails safely
        }

        action def MeasurePower {
            // measure instantaneous power consumption
        }
    }

    // ---- Neuromorphic Processor (Top-Level) ----
    part def NeuromorphicProcessor {
        attribute processorId : String;
        attribute architecture : String := "Spiking Neural Network";
        attribute totalNeuronCount : Integer := 9472;
        attribute totalSynapseCount : Integer := 10000000;
        attribute operatingTemperature : Dimensionless;
        attribute maxPowerBudget : Power := 100 [mW];

        part inputLayer : NeuronLayer {
            layerName = "InputLayer";
            neuronCount = 1024;
        }
        part hiddenLayer1 : NeuronLayer {
            layerName = "HiddenLayer1";
            neuronCount = 4096;
        }
        part hiddenLayer2 : NeuronLayer {
            layerName = "HiddenLayer2";
            neuronCount = 4096;
        }
        part outputLayer : NeuronLayer {
            layerName = "OutputLayer";
            neuronCount = 256;
        }
        part learningEngine : LearningEngine;
        part faultManager : FaultManager;
        part powerManager : PowerManager;

        port inPattern : LabeledPattern;
        port outResult : ClassificationResult;
        port inFault : FaultSignal;

        // Inter-layer connections
        connection inputToHidden1 connect inputLayer.outLayerOutput to hiddenLayer1.inLayerInput;
        connection hidden1ToHidden2 connect hiddenLayer1.outLayerOutput to hiddenLayer2.inLayerInput;
        connection hidden2ToOutput connect hiddenLayer2.outLayerOutput to outputLayer.inLayerOutput;

        // Learning engine connections
        connection spikeEventsToLearning connect hiddenLayer1.outLayerOutput to learningEngine.inSpikeEvents;
        connection learningToSynapses connect learningEngine.outWeightUpdates to hiddenLayer1.neurons.inSpike;

        // Fault manager connections
        connection faultToManager connect inFault to faultManager.inFaultSignal;

        // System state machine
        exhibit state def ProcessorStates {
            attribute currentState : String;

            state initialization {
                entry action InitializeSystem {
                    // power on, load configuration, zero membrane voltages
                }
            }
            state calibration {
                entry action CalibrateNeurons {
                    // set thresholds, verify spike propagation
                }
            }
            state ready {
                entry action EnterReady {
                    // system idle, awaiting mode selection
                }
            }
            state training {
                entry action StartTraining {
                    // enable learning engine, process labeled patterns
                }
                do action ProcessTrainingPatterns {
                    // continuously present labeled data, apply STDP
                }
                exit action SaveWeights {
                    // persist learned synaptic weights
                }
            }
            state inference {
                entry action StartInference {
                    // disable learning, use fixed weights
                }
                do action ClassifyPatterns {
                    // process incoming patterns, emit classification
                }
            }
            state faultDetected {
                entry action HandleFault {
                    // log fault, isolate affected region
                }
            }
            state shutdown {
                entry action SafeShutdown {
                    // save state, ramp down power
                }
            }

            transition initToCalib
                from initialization to calibration
                when powerManager.isPowered == true;
            transition calibToReady
                from calibration to ready
                when calibration.complete == true;
            transition readyToTraining
                from ready to training
                when inPattern.label != "";
            transition readyToInference
                from ready to inference
                when inPattern.label == "";
            transition trainingToReady
                from training to ready
                when training.episodeComplete == true;
            transition inferenceToReady
                from inference to ready
                when inference.sessionComplete == true;
            transition anyToFault
                from ready | training | inference to faultDetected
                when faultManager.isFaultActive == true;
            transition faultToShutdown
                from faultDetected to shutdown
                when faultManager.shutdownRequired == true;
            transition readyToShutdown
                from ready to shutdown
                when powerManager.shutdownRequested == true;
        }
    }

    // ---- Requirements ----
    requirement def RealTimePatternRecognition {
        doc "The processor shall perform real-time pattern recognition with end-to-end latency not exceeding 10 ms.";
        subject processor : NeuromorphicProcessor;
        attribute maxLatency : Time := 10 [ms];
        satisfy processor.outResult.latency <= maxLatency;
    }

    requirement def UltraLowPowerConsumption {
        doc "The processor shall operate with total power consumption not exceeding 100 mW during inference.";
        subject processor : NeuromorphicProcessor;
        attribute maxPower : Power := 100 [mW];
        satisfy processor.powerManager.currentPower <= maxPower;
    }

    requirement def AdaptiveLearningCapability {
        doc "The processor shall implement Spike-Timing-Dependent Plasticity for continuous online learning.";
        subject processor : NeuromorphicProcessor;
        satisfy processor.learningEngine.isEnabled == true;
    }

    requirement def MultiLayerArchitecture {
        doc "The processor shall comprise an input layer, two hidden layers, and an output layer of spiking neurons.";
        subject processor : NeuromorphicProcessor;
        satisfy processor.inputLayer.neuronCount > 0
            and processor.hiddenLayer1.neuronCount > 0
            and processor.hiddenLayer2.neuronCount > 0
            and processor.outputLayer.neuronCount > 0;
    }

    requirement def FaultToleranceAndSafeShutdown {
        doc "The processor shall detect faults and execute safe shutdown procedures.";
        subject processor : NeuromorphicProcessor;
        satisfy processor.faultManager.isFaultActive implies ProcessorStates.currentState == "faultDetected";
    }

    requirement def SpikingNeuronDynamics {
        doc "Each spiking neuron shall integrate incoming spikes, fire when threshold is exceeded, and observe a refractory period.";
        subject neuron : SpikingNeuron;
        satisfy neuron.membraneVoltage >= neuron.firingThreshold implies neuron.isInRefractory == false;
    }

    requirement def SynapticWeightAdjustability {
        doc "Each synapse shall have an adjustable weight bounded by minimum and maximum values.";
        subject synapse : Synapse;
        satisfy synapse.weight >= synapse.minWeight
            and synapse.weight <= synapse.maxWeight;
    }

    // ---- Verification ----
    verification def VerifyLatency {
        subject processor : NeuromorphicProcessor;
        objective "Measure end-to-end classification latency and confirm <= 10 ms.";
    }

    verification def VerifyPowerConsumption {
        subject processor : NeuromorphicProcessor;
        objective "Measure power during inference and confirm <= 100 mW.";
    }

    verification def VerifySTDP {
        subject processor : NeuromorphicProcessor;
        objective "Confirm that synaptic weights change according to STDP rule given pre/post spike timing.";
    }

}
