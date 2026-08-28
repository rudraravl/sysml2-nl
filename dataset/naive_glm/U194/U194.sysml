package AutomatedGrainSamplingSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types with Units ----

    value def Depth :> Real { unit = 'm'; }
    value def Mass :> Real { unit = 'g'; }
    value def Duration :> Real { unit = 's'; }
    value def Bias :> Real { unit = '%'; }
    value def AngularVelocity :> Real { unit = 'rad/s'; }
    value def Torque :> Real { unit = 'N*m'; }
    value def LinearVelocity :> Real { unit = 'm/s'; }

    // ---- Item Types ----

    item def Grain {
        attribute moistureContent : Real [0..1];
        attribute bulkDensity : Real [0..1] unit 'kg/m^3';
    }

    item def GrainSample :> Grain {
        attribute sampleMass : Mass;
        attribute collectionDepth : Depth;
        attribute timestamp : String;
    }

    // ---- Requirements ----

    requirement def SamplingAccuracyRequirement {
        doc /* The system shall collect samples with a bias of less than 5%. */
        attribute maxBias : Bias = 5.0;
        subject samplingBias : Bias;
        require samplingBias < maxBias;
    }

    requirement def SampleMassRequirement {
        doc /* Each collected sample shall have a mass of at least 500 grams. */
        attribute minSampleMass : Mass = 500.0;
        subject collectedMass : Mass;
        require collectedMass >= minSampleMass;
    }

    requirement def DeploymentDepthRequirement {
        doc /* The winch shall deploy the capsule to depths of up to 10 meters. */
        attribute maxDepth : Depth = 10.0;
        subject deploymentDepth : Depth;
        require deploymentDepth <= maxDepth;
    }

    requirement def CycleReliabilityRequirement {
        doc /* The system shall perform sampling cycles repeatedly and reliably. */
        attribute minCycles : Integer = 1000;
        subject completedCycles : Integer;
        require completedCycles >= minCycles;
    }

    // ---- Ports ----

    port def GrainFlowPort {
        out flowingGrain : Grain;
    }

    port def SampleTransferPort {
        out sample : GrainSample;
    }

    port def CommandPort {
        in command : String;
        in targetDepth : Depth;
        in fillDuration : Duration;
    }

    port def StatusPort {
        out capsulePosition : Depth;
        out valveState : String;
        out sampleCollected : Mass;
        out cycleComplete : Boolean;
    }

    port def MechanicalDrivePort {
        out torque : Torque;
        out angularVelocity : AngularVelocity;
    }

    port def CableMotionPort {
        out cableVelocity : LinearVelocity;
        out cablePosition : Depth;
    }

    // ---- Parts ----

    part def CrosbyKuglerCapsule {
        attribute capacity : Mass = 750.0;
        attribute currentMass : Mass = 0.0;
        attribute currentDepth : Depth = 0.0;
        attribute valveOpen : Boolean = false;

        port grainIn : GrainFlowPort;
        port sampleOut : SampleTransferPort;
        port cmdIn : CommandPort;
        port statusOut : StatusPort;

        state def CapsuleStates {
            entry; then Closed;

            state Closed {
                entry { capsule.statusOut.valveState = "closed"; }
                transition closed_to_opening
                    first if capsule.cmdIn.command == "open" then Opening
                    else if capsule.cmdIn.command == "lower" then Lowering;
            }

            state Lowering {
                entry { capsule.statusOut.valveState = "closed"; }
                transition lowering_to_opening
                    first if capsule.currentDepth >= capsule.cmdIn.targetDepth then Opening;
            }

            state Opening {
                entry {
                    capsule.valveOpen = true;
                    capsule.statusOut.valveState = "opening";
                }
                do { capsule.statusOut.valveState = "open"; }
                transition opening_to_filling
                    first if capsule.valveOpen == true then Filling;
            }

            state Filling {
                entry { capsule.statusOut.valveState = "open"; }
                do for capsule.cmdIn.fillDuration {
                    capsule.currentMass = capsule.currentMass + 50.0;
                    capsule.statusOut.sampleCollected = capsule.currentMass;
                }
                transition filling_to_closing
                    first if capsule.currentMass >= 500.0 then Closing
                    else if capsule.currentMass >= capsule.capacity then Closing;
            }

            state Closing {
                entry {
                    capsule.valveOpen = false;
                    capsule.statusOut.valveState = "closed";
                }
                transition closing_to_sealed
                    first if capsule.valveOpen == false then Sealed;
            }

            state Sealed {
                entry { capsule.statusOut.valveState = "sealed"; }
                transition sealed_to_emptying
                    first if capsule.cmdIn.command == "empty" then Emptying;
            }

            state Emptying {
                entry {
                    capsule.sampleOut.sample = GrainSample {
                        sampleMass = capsule.currentMass,
                        collectionDepth = capsule.currentDepth
                    };
                    capsule.currentMass = 0.0;
                    capsule.statusOut.sampleCollected = 0.0;
                }
                transition emptying_to_closed
                    first if capsule.currentMass == 0.0 then Closed;
            }
        }

        state machine : CapsuleStates;
    }

    part def Motor {
        attribute ratedTorque : Torque = 50.0;
        attribute ratedSpeed : AngularVelocity = 10.0;

        port driveOut : MechanicalDrivePort;
        port cmdIn : CommandPort;

        action def Operate {
            in speed : AngularVelocity;
            out torque : Torque;
        }

        perform Operate {
            in speed = ratedSpeed;
            out torque = ratedTorque;
        }
    }

    part def Drum {
        attribute radius : Real = 0.1 unit 'm';
        attribute maxCableLength : Depth = 10.0;

        port driveIn : MechanicalDrivePort;
        port cableOut : CableMotionPort;

        action def Spool {
            in torque : Torque;
            in angularVelocity : AngularVelocity;
            out cableVelocity : LinearVelocity;
            out cablePosition : Depth;
        }

        perform Spool {
            in torque = driveIn.torque;
            in angularVelocity = driveIn.angularVelocity;
            out cableVelocity = driveIn.angularVelocity * radius;
            out cablePosition = 0.0;
        }
    }

    part def Cable {
        attribute length : Depth = 10.0;
        attribute diameter : Real = 0.005 unit 'm';

        port motionIn : CableMotionPort;
        port attachmentPoint : CableMotionPort;
    }

    part def WinchAssembly {
        part motor : Motor;
        part drum : Drum;
        part cable : Cable;

        port cmdIn : CommandPort;
        port statusOut : StatusPort;
        port cableAttachment : CableMotionPort;

        connection motorToDrum : MechanicalDrivePort connect motor.driveOut to drum.driveIn;
        connection drumToCable : CableMotionPort connect drum.cableOut to cable.motionIn;
        connection cableToAttachment : CableMotionPort connect cable.attachmentPoint to cableAttachment;

        action def Deploy {
            in targetDepth : Depth;
            out finalDepth : Depth;
        }

        action def Retrieve {
            out finalDepth : Depth;
        }

        perform Deploy {
            in targetDepth = cmdIn.targetDepth;
            out finalDepth = cableAttachment.cablePosition;
        }

        perform Retrieve {
            out finalDepth = cableAttachment.cablePosition;
        }
    }

    part def SampleReceptacle {
        attribute capacity : Mass = 5000.0;
        attribute storedMass : Mass = 0.0;
        attribute sampleCount : Integer = 0;

        port sampleIn : SampleTransferPort;

        action def ReceiveSample {
            in incomingSample : GrainSample;
            out storedMass : Mass;
        }

        perform ReceiveSample {
            in incomingSample = sampleIn.sample;
            out storedMass = storedMass + incomingSample.sampleMass;
        }
    }

    part def SystemController {
        attribute cycleCount : Integer = 0;
        attribute targetDepth : Depth = 5.0;
        attribute fillDuration : Duration = 10.0;
        attribute measuredBias : Bias = 3.0;

        port winchCmd : CommandPort;
        port capsuleCmd : CommandPort;
        port winchStatus : StatusPort;
        port capsuleStatus : StatusPort;

        state def ControllerStates {
            entry; then Idle;

            state Idle {
                entry { controller.winchCmd.command = "standby"; }
                transition idle_to_deploying
                    first if true then Deploying;
            }

            state Deploying {
                entry {
                    controller.winchCmd.command = "lower";
                    controller.winchCmd.targetDepth = controller.targetDepth;
                }
                transition deploying_to_collecting
                    first if controller.winchStatus.capsulePosition >= controller.targetDepth then Collecting;
            }

            state Collecting {
                entry {
                    controller.capsuleCmd.command = "open";
                    controller.capsuleCmd.fillDuration = controller.fillDuration;
                }
                transition collecting_to_sealing
                    first if controller.capsuleStatus.sampleCollected >= 500.0 then Sealing;
            }

            state Sealing {
                entry { controller.capsuleCmd.command = "close"; }
                transition sealing_to_retrieving
                    first if controller.capsuleStatus.valveState == "sealed" then Retrieving;
            }

            state Retrieving {
                entry { controller.winchCmd.command = "raise"; }
                transition retrieving_to_emptying
                    first if controller.winchStatus.capsulePosition == 0.0 then Emptying;
            }

            state Emptying {
                entry { controller.capsuleCmd.command = "empty"; }
                transition emptying_to_idle
                    first if controller.capsuleStatus.cycleComplete == true then Idle;
            }
        }

        state machine : ControllerStates;

        satisfy SamplingAccuracyRequirement {
            samplingBias = measuredBias;
        }
    }

    // ---- Top-level System ----

    part def GrainSamplingSystem {
        part controller : SystemController;
        part winch : WinchAssembly;
        part capsule : CrosbyKuglerCapsule;
        part receptacle : SampleReceptacle;

        port grainStream : GrainFlowPort;
        port systemStatus : StatusPort;

        connection controllerToWinch : CommandPort connect controller.winchCmd to winch.cmdIn;
        connection winchToController : StatusPort connect winch.statusOut to controller.winchStatus;
        connection controllerToCapsule : CommandPort connect controller.capsuleCmd to capsule.cmdIn;
        connection capsuleToController : StatusPort connect capsule.statusOut to controller.capsuleStatus;
        connection winchToCapsule : CableMotionPort connect winch.cableAttachment to capsule.cmdIn;
        connection grainToCapsule : GrainFlowPort connect grainStream to capsule.grainIn;
        connection capsuleToReceptacle : SampleTransferPort connect capsule.sampleOut to receptacle.sampleIn;
        connection capsuleStatusToSystem : StatusPort connect capsule.statusOut to systemStatus;

        satisfy SampleMassRequirement {
            collectedMass = capsule.currentMass;
        }

        satisfy DeploymentDepthRequirement {
            deploymentDepth = winch.cableAttachment.cablePosition;
        }

        satisfy CycleReliabilityRequirement {
            completedCycles = controller.cycleCount;
        }
    }

    // ---- System-level sampling action ----

    action def SamplingCycle {
        in grainInput : Grain;
        out collectedSample : GrainSample;

        action lowerCapsule {
            in depth : Depth;
        }

        action openValve {
            in duration : Duration;
        }

        action fillCapsule {
            in grain : Grain;
            out mass : Mass;
        }

        action closeValve;

        action raiseCapsule;

        action emptyCapsule {
            out sample : GrainSample;
        }

        then lowerCapsule;
        then openValve;
        then fillCapsule;
        then closeValve;
        then raiseCapsule;
        then emptyCapsule;
    }

}
