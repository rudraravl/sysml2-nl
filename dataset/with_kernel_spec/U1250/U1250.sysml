package UtilityFog {
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def Length :> Real { unit = m; }
    attribute def Force :> Real { unit = N; }
    attribute def Density :> Real { unit = kg/(m*m*m); }
    attribute def Strength :> Real { unit = Pa; }
    attribute def Power :> Real { unit = W; }
    attribute def Energy :> Real { unit = J; }
    
    attribute def Position {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }
    
    item def Blueprint {
        attribute shape : String;
        attribute density : Density;
        attribute strength : Strength;
    }
    
    item def Command {
        attribute commandType : String;
        attribute targetPosition : Position;
    }
    
    item def Status {
        attribute fogletId : Integer;
        attribute operationalState : String;
    }
    
    item def SensorData {
        attribute force : Force;
        attribute position : Position;
    }
    
    port def FogletCommPort {
        in command : Command;
        out status : Status;
    }
    
    port def ControllerCommPort {
        out command : Command;
        in status : Status;
    }
    
    port def ArmGraspPort;
    
    part def Processor {
        port dataPort : FogletCommPort;
        action processCommand;
    }
    
    part def PowerUnit {
        port powerPort {
            out power : Power;
        }
        attribute capacity : Energy;
        action supplyPower;
    }
    
    part def Sensor {
        port sensorPort {
            out data : SensorData;
        }
        action sense;
    }
    
    part def CommModule {
        port commPort : FogletCommPort;
        action transmit;
        action receive;
    }
    
    part def Arm {
        port graspPort : ArmGraspPort;
        attribute length : Length;
        action extend;
        action retract;
        action grasp;
        action release;
    }
    
    part def ProgrammableMatter;
    
    part def Foglet {
        attribute id : Integer;
        attribute operationalState : String;
        
        part processor : Processor;
        part powerUnit : PowerUnit;
        part sensors : Sensor[1..*];
        part commModule : CommModule;
        part arms : Arm[12];
        
        port commPort :>> commModule.commPort;
        port powerPort :>> powerUnit.powerPort;
        port armPorts :>> arms.graspPort;
        
        action moveToPosition;
        action selfDiagnose;
        action repair;
    }
    
    part def CommNetwork {
        port controllerPort : FogletCommPort;
        port fogletPorts : ControllerCommPort[1..*];
        
        action routeCommand;
        action aggregateStatus;
    }
    
    part def FogletCluster {
        part foglets : Foglet[1..*];
        attribute shape : String;
        attribute density : Density;
        attribute strength : Strength;
        
        action formCluster;
        action monitorExternalForces;
        action detectFogletFailure;
        action isolateFailedFoglet;
        action rerouteConnections;
        action repairStructure;
    }
    
    part def CentralController {
        port swarmCommPort : ControllerCommPort;
        port blueprintPort {
            in blueprint : Blueprint;
        }
        
        action analyzeTargetObject;
        action formObject;
        action maintainIntegrity;
        action selfHeal;
    }
    
    association PhysicalLink {
        end arm1 : Arm;
        end arm2 : Arm;
    }
    
    part def UtilityFogSystem :> ProgrammableMatter {
        part controller : CentralController;
        part swarm : Foglet[1000000..*];
        part commNetwork : CommNetwork;
        part activeCluster : FogletCluster;
        
        connect controller.swarmCommPort to commNetwork.controllerPort;
        connect swarm.commPort to commNetwork.fogletPorts;
        connect swarm.armPorts to swarm.armPorts;
    }
}
