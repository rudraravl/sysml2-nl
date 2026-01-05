package 'CrosbyKuglerCapsuleSystem' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def TargetDepth;
    attribute def SamplingCommand;
    attribute def SamplingStatus;
    
    item def GrainMaterial {
        attribute particleSize : LengthValue;
        attribute moistureContent : Real;
        attribute density : DensityValue;
    }
    
    item def GrainSample {
        attribute totalMass : MassValue;
        attribute averageMoisture : Real;
        attribute particleDistribution : Real[*];
        attribute representativeness : Real;
    }
    
    attribute def DepthValue :> LengthValue;
    attribute def TensionValue :> ForceValue;
    attribute def FlowRateValue :> VolumeFlowRateValue;
    
    port def GrainStreamPort {
        in attribute grainFlow : GrainMaterial;
        attribute flowRate : FlowRateValue;
    }
    
    port def SampleOutputPort {
        out attribute collectedSample : GrainSample;
    }
    
    port def TetherPort {
        attribute tension : TensionValue;
        attribute currentLength : DepthValue;
    }
    
    port def ControlPort {
        in attribute command : SamplingCommand;
        out attribute status : SamplingStatus;
    }
    
    part def CrosbyKuglerCapsule {
        doc /* A specialized sampling device designed to collect representative samples from flowing grain streams. */
        
        attribute capsuleID : String;
        attribute nominalCapacity : MassValue;
        attribute currentLoad : MassValue;
        attribute isOpen : Boolean;
        
        port grainInlet : GrainStreamPort;
        port sampleOutlet : SampleOutputPort;
        port tetherConnection : TetherPort;
        
        part samplingChamber {
            attribute volume : VolumeValue;
            attribute fillLevel : Real;
        }
        
        part inletValve {
            attribute position : Real;
            attribute maxOpening : LengthValue;
        }
        
        part dischargeValve {
            attribute position : Real;
            attribute isSealed : Boolean;
        }
    }
    
    part def WinchAssembly {
        doc /* Mechanical system for deploying and retrieving the capsule. */
        
        attribute maxDeploymentDepth : DepthValue;
        attribute retrievalSpeed : SpeedValue;
        
        port tetherEnd : TetherPort;
        
        part motor {
            attribute power : PowerValue;
            attribute torque : TorqueValue;
        }
        
        part cable {
            attribute length : LengthValue;
            attribute maxTension : TensionValue;
            attribute diameter : LengthValue;
        }
        
        part drum {
            attribute radius : LengthValue;
            attribute windingCapacity : LengthValue;
        }
    }
    
    part def SampleReceptacle {
        doc /* Container for storing collected samples. */
        
        attribute capacity : MassValue;
        attribute storedMass : MassValue;
        
        port sampleInput : SampleOutputPort;
    }
    
    part def SystemController {
        doc /* Control unit managing the sampling operation. */
        
        port controlInterface : ControlPort;
        
        attribute operatingMode : String;
        attribute cycleCount : Integer;
    }
    
    requirement def RepresentativeSampling {
        doc /* The system shall collect grain samples that are statistically representative of the flowing stream with bias less than 5%. */
        
        subject samplingSystem : CrosbyKuglerSamplingSystem;
        
        require constraint {
            samplingSystem.capsule.sampleOutlet.collectedSample.representativeness >= 0.95
        }
    }
    
    requirement def MinimumSampleMass {
        doc /* Each collected sample shall have a minimum mass of 500 grams. */
        
        subject samplingSystem : CrosbyKuglerSamplingSystem;
        
        require constraint {
            samplingSystem.capsule.sampleOutlet.collectedSample.totalMass >= 0.5[kilogram]
        }
    }
    
    requirement def OperationalDepth {
        doc /* The capsule shall be deployable to depths up to 10 meters within the grain stream. */
        
        subject samplingSystem : CrosbyKuglerSamplingSystem;
        
        require constraint {
            samplingSystem.winch.maxDeploymentDepth >= 10.0[metre]
        }
    }
    
    action def DeployCapsule {
        in targetDepth : DepthValue;
        in deploymentSpeed : SpeedValue;
        out deploymentComplete : Boolean;
        out actualDepth : DepthValue;
    }
    
    action def OpenInletValve {
        in openingDegree : Real;
        out valveOpen : Boolean;
    }
    
    action def CollectGrain {
        in grainStream : GrainMaterial;
        in collectionDuration : TimeValue;
        out accumulatedMass : MassValue;
        out sampleQuality : Real;
    }
    
    action def CloseInletValve {
        out valveSealed : Boolean;
    }
    
    action def RetrieveCapsule {
        in retrievalSpeed : SpeedValue;
        out retrievalComplete : Boolean;
    }
    
    action def DischargeSample {
        in accumulatedSample : GrainSample;
        out dischargeComplete : Boolean;
    }
    
    action def SamplingCycle {
        doc /* Complete sampling operation from deployment through sample discharge. */
        
        in samplingDepth : DepthValue;
        in targetMass : MassValue;
        in grainStream : GrainMaterial;
        out finalSample : GrainSample;
        out cycleSuccess : Boolean;
        
        private attribute collectedMass : MassValue;
        private attribute sampleData : GrainSample;
        
        first start;
        
        then action deploy : DeployCapsule {
            in targetDepth = samplingDepth;
            in deploymentSpeed = 0.5[metre/second];
            out deploymentComplete;
            out actualDepth;
        }
        
        then decide;
            if deploy.deploymentComplete then openValve;
            else abort;
        
        action openValve : OpenInletValve {
            in openingDegree = 1.0;
            out valveOpen;
        }
        
        then action collect : CollectGrain {
            in grainStream = SamplingCycle::grainStream;
            in collectionDuration = 10.0[second];
            out accumulatedMass = collectedMass;
            out sampleQuality;
        }
        
        then decide;
            if collectedMass >= targetMass then closeValve;
            else collect;
        
        action closeValve : CloseInletValve {
            out valveSealed;
        }
        
        then action retrieve : RetrieveCapsule {
            in retrievalSpeed = 0.3[metre/second];
            out retrievalComplete;
        }
        
        then action discharge : DischargeSample {
            in accumulatedSample : GrainSample {
                :>> totalMass = collectedMass;
                :>> averageMoisture = collect.sampleQuality;
            }
            out dischargeComplete;
        }
        
        then assign finalSample := discharge.accumulatedSample;
        then assign cycleSuccess := discharge.dischargeComplete;
        then done;
        
        action abort {
            then assign cycleSuccess := false;
            then done;
        }
    }
    
    part def CrosbyKuglerSamplingSystem {
        doc /* Integrated grain sampling system utilizing a Crosby-Kugler capsule for representative sample collection from flowing grain streams. */
        
        attribute systemID : String;
        attribute operationalStatus : String;
        
        part capsule : CrosbyKuglerCapsule {
            :>> capsuleID = "CK-001";
            :>> nominalCapacity = 1.0[kilogram];
            :>> currentLoad = 0.0[kilogram];
            :>> isOpen = false;
        }
        
        part winch : WinchAssembly {
            :>> maxDeploymentDepth = 12.0[metre];
            :>> retrievalSpeed = 0.3[metre/second];
        }
        
        part receptacle : SampleReceptacle {
            :>> capacity = 10.0[kilogram];
            :>> storedMass = 0.0[kilogram];
        }
        
        part controller : SystemController {
            :>> operatingMode = "standby";
            :>> cycleCount = 0;
        }
        
        port grainStreamInput : GrainStreamPort;
        port controlInput : ControlPort;
        
        connect winch.tetherEnd to capsule.tetherConnection;
        connect capsule.sampleOutlet to receptacle.sampleInput;
        connect capsule.grainInlet to grainStreamInput;
        connect controller.controlInterface to controlInput;
        
        perform action samplingOperation : SamplingCycle {
            in samplingDepth = 5.0[metre];
            in targetMass = 0.5[kilogram];
            in grainStream = grainStreamInput.grainFlow;
            out finalSample;
            out cycleSuccess;
        }
    }
    
    package SystemInstantiation {
        private import 'CrosbyKuglerCapsuleSystem'::*;
        
        part grainSamplingStation : CrosbyKuglerSamplingSystem {
            :>> systemID = "Station-Alpha";
            :>> operationalStatus = "active";
            
            satisfy RepresentativeSampling;
            satisfy MinimumSampleMass;
            satisfy OperationalDepth;
        }
    }
}
