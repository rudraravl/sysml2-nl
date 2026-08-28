package 'Automated Grain Sampling System' {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    item def Grain;
    item def GrainSample :> Grain {
        attribute mass : ISQ::MassValue;
    }

    item def LowerCommand {
        attribute targetDepth : ISQ::LengthValue;
    }
    item def RetrieveCommand;
    item def StopCommand;
    item def OpenValveCommand;
    item def CloseValveCommand;
    item def EmptyCommand;

    item def ValveStateData {
        attribute isOpen : Boolean;
        attribute fillMass : ISQ::MassValue;
    }

    item def WinchStatusData {
        attribute currentDepth : ISQ::LengthValue;
        attribute isMoving : Boolean;
    }

    part def Motor {
        action rotateForward;
        action rotateReverse;
        action stop;
    }

    part def Drum {
        attribute radius : ISQ::LengthValue = 0.05[SI::m];
    }

    part def Cable {
        attribute length : ISQ::LengthValue = 10[SI::m];
        attribute currentLength : ISQ::LengthValue = 0[SI::m];
    }

    part def Valve {
        attribute isOpen : Boolean = false;
        attribute fillMass : ISQ::MassValue = 0[SI::kg];
        port controlPort {
            in open : OpenValveCommand;
            in close : CloseValveCommand;
        }
        port statePort {
            out state : ValveStateData;
        }
        action openValve;
        action closeValve;
    }

    part def CrosbyKuglerCapsule {
        attribute sampleMass : ISQ::MassValue = 0[SI::kg];
        attribute capacity : ISQ::MassValue = 2[SI::kg];
        port valveControlPort {
            in open : OpenValveCommand;
            in close : CloseValveCommand;
        }
        port valveStatePort {
            out state : ValveStateData;
        }
        port emptyControlPort {
            in empty : EmptyCommand;
        }
        port grainInletPort {
            in grain : Grain;
        }
        port grainOutletPort {
            out grain : GrainSample;
        }
        part inletValve : Valve;
        bind valveControlPort = inletValve.controlPort;
        bind valveStatePort = inletValve.statePort;
    }

    part def WinchAssembly {
        attribute currentDepth : ISQ::LengthValue = 0[SI::m];
        attribute maxDepth : ISQ::LengthValue = 10[SI::m];
        port commandPort {
            in lower : LowerCommand;
            in retrieve : RetrieveCommand;
            in stop : StopCommand;
        }
        port statusPort {
            out status : WinchStatusData;
        }
        part motor : Motor;
        part drum : Drum;
        part cable : Cable;
    }

    part def SampleReceptacle {
        attribute collectedMass : ISQ::MassValue = 0[SI::kg];
        port grainInletPort {
            in grain : GrainSample;
        }
        action receiveSample;
    }

    part def GrainStream {
        port grainOutletPort {
            out grain : Grain;
        }
    }

    action def SamplingCycle {
        in desiredDepth : ISQ::LengthValue;
        in desiredDuration : ISQ::TimeValue;
        in minimumMass : ISQ::MassValue;
        out materialSample : GrainSample;
    }

    state def ControlBehavior {
        state idle;
        state deploying;
        state filling;
        state retrieving;
        state depositing;
        transition idle -> deploying;
        transition deploying -> filling;
        transition filling -> retrieving;
        transition retrieving -> depositing;
        transition depositing -> idle;
    }

    part def SystemController {
        attribute targetDepth : ISQ::LengthValue = 5[SI::m];
        attribute sampleDuration : ISQ::TimeValue = 10[SI::s];
        attribute minSampleMass : ISQ::MassValue = 0.5[SI::kg];
        attribute collectedSample : GrainSample;

        port winchCommandPort {
            out lower : LowerCommand;
            out retrieve : RetrieveCommand;
            out stop : StopCommand;
        }
        port winchStatusPort {
            in status : WinchStatusData;
        }
        port valveControlPort {
            out open : OpenValveCommand;
            out close : CloseValveCommand;
        }
        port valveStatePort {
            in state : ValveStateData;
        }
        port emptyControlPort {
            out empty : EmptyCommand;
        }

        perform samplingCycle : SamplingCycle {
            in desiredDepth :>> targetDepth;
            in desiredDuration :>> sampleDuration;
            in minimumMass :>> minSampleMass;
            out materialSample :>> collectedSample;
        }

        perform controlBehavior : ControlBehavior;
    }

    part def GrainSamplingSystem {
        attribute targetDepth : ISQ::LengthValue = 5[SI::m];
        attribute sampleDuration : ISQ::TimeValue = 10[SI::s];
        attribute minSampleMass : ISQ::MassValue = 0.5[SI::kg];
        attribute maxOperatingDepth : ISQ::LengthValue = 10[SI::m];
        attribute maxBias : Real = 0.05;

        part controller : SystemController;
        part winch : WinchAssembly;
        part capsule : CrosbyKuglerCapsule;
        part receptacle : SampleReceptacle;
        part grainStream : GrainStream;

        flow lowerCommandFlow of LowerCommand 
            from controller.winchCommandPort.lower to winch.commandPort.lower;
        flow retrieveCommandFlow of RetrieveCommand 
            from controller.winchCommandPort.retrieve to winch.commandPort.retrieve;
        flow stopCommandFlow of StopCommand 
            from controller.winchCommandPort.stop to winch.commandPort.stop;
        flow winchStatusFlow of WinchStatusData 
            from winch.statusPort.status to controller.winchStatusPort.status;
        flow openValveFlow of OpenValveCommand 
            from controller.valveControlPort.open to capsule.valveControlPort.open;
        flow closeValveFlow of CloseValveCommand 
            from controller.valveControlPort.close to capsule.valveControlPort.close;
        flow emptyCommandFlow of EmptyCommand 
            from controller.emptyControlPort.empty to capsule.emptyControlPort.empty;
        flow valveStateFlow of ValveStateData 
            from capsule.valveStatePort.state to controller.valveStatePort.state;
        flow grainInFlow of Grain 
            from grainStream.grainOutletPort.grain to capsule.grainInletPort.grain;
        flow grainOutFlow of GrainSample 
            from capsule.grainOutletPort.grain to receptacle.grainInletPort.grain;
    }

    requirement def MinimumSampleMassRequirement {
        doc /* The collected sample must be at least 500 grams. */
        attribute minimumMass : ISQ::MassValue = 0.5[SI::kg];
    }

    requirement def MaximumDepthRequirement {
        doc /* The winch must deploy the capsule to depths up to 10 meters. */
        attribute maximumDepth : ISQ::LengthValue = 10[SI::m];
    }

    requirement def SamplingBiasRequirement {
        doc /* The sampling bias must be less than 5%. */
        attribute maximumBias : Real = 0.05;
    }

    requirement minSampleMassReq : MinimumSampleMassRequirement;
    requirement maxDepthReq : MaximumDepthRequirement;
    requirement biasReq : SamplingBiasRequirement;

    part grainSamplingSystem : GrainSamplingSystem;

    satisfy minSampleMassReq by grainSamplingSystem;
    satisfy maxDepthReq by grainSamplingSystem;
    satisfy biasReq by grainSamplingSystem;
}
