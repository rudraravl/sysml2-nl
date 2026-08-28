package BlindsightVisualSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    value def VelocityValue :> Real;

    item def VisualStimulus {
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute velocity : VelocityValue;
        attribute luminance : LuminousIntensityValue;
    }

    item def NeuralSignal {
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute velocity : VelocityValue;
        attribute firingRate : FrequencyValue;
    }

    item def SpatialMap {
        attribute positionX : LengthValue;
        attribute positionY : LengthValue;
        attribute velocity : VelocityValue;
        attribute reliability : Real;
    }

    item def MotorCommand {
        attribute actionType : String;
        attribute targetX : LengthValue;
        attribute targetY : LengthValue;
    }

    item def ConsciousPercept {
        attribute identifiedObject : String;
        attribute confidence : Real;
    }

    port def OpticalInPort {
        in item stimulus : VisualStimulus;
    }

    port def NeuralOutPort {
        out item signal : NeuralSignal;
    }

    port def NeuralInPort {
        in item signal : NeuralSignal;
    }

    port def SpatialOutPort {
        out item spatialMap : SpatialMap;
    }

    port def SpatialInPort {
        in item spatialMap : SpatialMap;
    }

    port def MotorOutPort {
        out item command : MotorCommand;
    }

    port def PerceptOutPort {
        out item percept : ConsciousPercept;
    }

    action def TransduceLight {
        in stimulus : VisualStimulus;
        out signal : NeuralSignal;
    }

    action def ComputeSpatialInfo {
        in signal : NeuralSignal;
        out spatialMap : SpatialMap;
    }

    action def GenerateMotorCommand {
        in dorsalSpatial : SpatialMap;
        in collicularSpatial : SpatialMap;
        out command : MotorCommand;
    }

    action def ProcessConsciousPerception {
        in signal : NeuralSignal;
        out percept : ConsciousPercept;
    }

    state machine def VentralState {
        initial state intact;
        state severed;
        transition from intact to severed;
    }

    state machine def VisualProcessingSM {
        initial state Unaware;
        state StimulusReceived;
        state SpatialProcessing;
        state MotorActionGenerated;
        transition from Unaware to StimulusReceived;
        transition from StimulusReceived to SpatialProcessing;
        transition from SpatialProcessing to MotorActionGenerated;
        transition from MotorActionGenerated to Unaware;
    }

    part def Retina {
        port opticalIn : OpticalInPort;
        port neuralOut : NeuralOutPort;
        perform action transduce : TransduceLight {
            in stimulus = opticalIn.stimulus;
            out signal = neuralOut.signal;
        }
    }

    part def Eye {
        port opticalIn : OpticalInPort;
        part retina : Retina;
        connect opticalIn to retina.opticalIn;
    }

    part def VisualPathway {
        attribute isFunctional : Boolean;
        port neuralIn : NeuralInPort;
    }

    part def VentralStream :> VisualPathway {
        port perceptOut : PerceptOutPort;
        perform action processPerception : ProcessConsciousPerception {
            in signal = neuralIn.signal;
            out percept = perceptOut.percept;
        }
        exhibit ventralState : VentralState;
    }

    part def DorsalStream :> VisualPathway {
        port spatialOut : SpatialOutPort;
        perform action computeSpatial : ComputeSpatialInfo {
            in signal = neuralIn.signal;
            out spatialMap = spatialOut.spatialMap;
        }
    }

    part def SuperiorColliculus :> VisualPathway {
        port spatialOut : SpatialOutPort;
        perform action computeReflexive : ComputeSpatialInfo {
            in signal = neuralIn.signal;
            out spatialMap = spatialOut.spatialMap;
        }
    }

    part def MotorCortex {
        port dorsalIn : SpatialInPort;
        port colliculusIn : SpatialInPort;
        port motorOut : MotorOutPort;
        perform action generateCommand : GenerateMotorCommand {
            in dorsalSpatial = dorsalIn.spatialMap;
            in collicularSpatial = colliculusIn.spatialMap;
            out command = motorOut.command;
        }
    }

    part def Brain {
        part leftEye : Eye;
        part rightEye : Eye;
        part ventralStream : VentralStream {
            attribute :>> isFunctional = false;
        }
        part dorsalStream : DorsalStream {
            attribute :>> isFunctional = true;
        }
        part superiorColliculus : SuperiorColliculus {
            attribute :>> isFunctional = true;
        }
        part motorCortex : MotorCortex;

        connect leftEye.retina.neuralOut to ventralStream.neuralIn;
        connect rightEye.retina.neuralOut to ventralStream.neuralIn;
        connect leftEye.retina.neuralOut to dorsalStream.neuralIn;
        connect rightEye.retina.neuralOut to dorsalStream.neuralIn;
        connect leftEye.retina.neuralOut to superiorColliculus.neuralIn;
        connect rightEye.retina.neuralOut to superiorColliculus.neuralIn;
        connect dorsalStream.spatialOut to motorCortex.dorsalIn;
        connect superiorColliculus.spatialOut to motorCortex.colliculusIn;
    }

    part def Human {
        attribute name : String;
        part brain : Brain;
        attribute consciousAwareness : Boolean = false;
        exhibit visualProcessing : VisualProcessingSM;
    }

    part blindsightPatient : Human {
        attribute :>> name = "Blindsight Patient";
    }

    requirement def BlindsightCondition {
        doc /* Requirement for modeling the blindsight neurological condition. */
    }

    requirement blindsightReq : BlindsightCondition {
        subject patient : Human;

        requirement ventralStreamDamaged {
            doc /* The ventral stream responsible for conscious perception must be damaged. */
            constraint patient.brain.ventralStream.isFunctional == false;
        }

        requirement noConsciousAwareness {
            doc /* The patient must report no conscious visual awareness. */
            constraint patient.consciousAwareness == false;
        }

        requirement dorsalStreamIntact {
            doc /* The dorsal stream for spatial processing must remain functional. */
            constraint patient.brain.dorsalStream.isFunctional == true;
        }

        requirement superiorColliculusIntact {
            doc /* The superior colliculus pathway for reflexive responses must remain functional. */
            constraint patient.brain.superiorColliculus.isFunctional == true;
        }

        requirement motorCommandGenerated {
            doc /* The motor cortex must generate appropriate motor commands from unconscious visual data. */
            constraint patient.brain.motorCortex.motorOut.command.actionType != "";
        }
    }
}
