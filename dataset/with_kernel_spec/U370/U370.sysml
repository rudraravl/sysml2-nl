package ROTIGS {
    private import ScalarValues::*;
    
    value type Angle :> Real { unit "deg"; }
    value type Distance :> Real { unit "m"; }
    value type Temperature :> Real { unit "K"; }
    
    item def Command;
    item def ScanCommand :> Command;
    item def TrackCommand :> Command;
    item def FireCommand :> Command;
    item def StopCommand :> Command;
    
    item def ThermalVideoFrame {
        attribute width : Integer;
        attribute height : Integer;
        attribute tempRange : Temperature;
    }
    
    item def TargetData {
        attribute x : Distance;
        attribute y : Distance;
        attribute z : Distance;
        attribute isLocked : Boolean;
    }
    
    item def SystemStatus {
        attribute systemState : String;
        attribute batteryLevel : Real;
    }
    
    port def CommandPort {
        in item command : Command;
    }
    port def StatusPort {
        out item status : SystemStatus;
    }
    port def VideoPort {
        out item video : ThermalVideoFrame;
    }
    port def TargetingPort {
        out item targetData : TargetData;
    }
    port def FireCommandPort {
        in item fireCommand : FireCommand;
    }
    
    part def Display {
        port videoIn : ~VideoPort;
        port targetIn : ~TargetingPort;
    }
    
    part def ControlInterface {
        port commandOut : ~CommandPort;
        port statusIn : ~StatusPort;
    }
    
    part def CommLink {
        port commandIn : CommandPort;
        port statusIn : ~StatusPort;
        port videoIn : ~VideoPort;
        port targetIn : ~TargetingPort;
        
        port commandOut : ~CommandPort;
        port statusOut : StatusPort;
        port videoOut : VideoPort;
        port targetOut : TargetingPort;
        
        flow commandFlow from commandIn.command to commandOut.command;
        flow statusFlow from statusIn.status to statusOut.status;
        flow videoFlow from videoIn.video to videoOut.video;
        flow targetDataFlow from targetIn.targetData to targetOut.targetData;
    }
    
    part def OperatorStation {
        part display : Display;
        part controlInterface : ControlInterface;
        part commLink : CommLink;
        
        flow cmdFlow from controlInterface.commandOut.command to commLink.commandIn.command;
        flow statusFlow from commLink.statusOut.status to controlInterface.statusIn.status;
        flow videoFlow from commLink.videoOut.video to display.videoIn.video;
        flow targetFlow from commLink.targetOut.targetData to display.targetIn.targetData;
    }
    
    part def ThermalImager {
        port videoOut : VideoPort;
    }
    
    part def Gimbal {
        attribute pan : Angle;
        attribute tilt : Angle;
        port commandIn : CommandPort;
    }
    
    part def ImageProcessor {
        port videoIn : ~VideoPort;
        port videoOut : VideoPort;
    }
    
    part def TrackingComputer {
        port dataIn : ~VideoPort;
        port commandIn : CommandPort;
        port videoOut : VideoPort;
        port targetOut : TargetingPort;
        port statusOut : StatusPort;
        port fireCommandOut : ~FireCommandPort;
        attribute isLocked : Boolean = false;
    }
    
    part def ThermalSight {
        part thermalImager : ThermalImager;
        part gimbal : Gimbal;
        part imageProcessor : ImageProcessor;
        part trackingComputer : TrackingComputer;
        
        port commandPort : CommandPort;
        port videoPort : VideoPort;
        port targetPort : TargetingPort;
        port statusPort : StatusPort;
        port fireCommandOut : ~FireCommandPort;
        
        flow videoFlow1 from thermalImager.videoOut.video to imageProcessor.videoIn.video;
        flow videoFlow2 from imageProcessor.videoOut.video to trackingComputer.dataIn.video;
        flow videoFlow3 from trackingComputer.videoOut.video to videoPort.video;
        flow targetFlow from trackingComputer.targetOut.targetData to targetPort.targetData;
        flow cmdFlow1 from commandPort.command to trackingComputer.commandIn.command;
        flow cmdFlow2 from commandPort.command to gimbal.commandIn.command;
        flow statusFlow from trackingComputer.statusOut.status to statusPort.status;
        flow fireCmdFlow from trackingComputer.fireCommandOut.fireCommand to fireCommandOut.fireCommand;
        
        state machine thermalSightState {
            entry; then standby;
            state standby;
            transition standby_to_searching first standby then searching;
            state searching;
            transition searching_to_tracking first searching then tracking;
            state tracking;
            transition tracking_to_locked first tracking then locked;
            state locked;
            transition locked_to_engaging first locked then engaging;
            state engaging;
            transition engaging_to_searching first engaging then searching;
        }
    }
    
    part def Gun {
        port fireCommandIn : FireCommandPort;
    }
    
    part def Ammunition {
        attribute roundCount : Integer;
    }
    
    part def FiringMechanism {
        port fireCommandIn : FireCommandPort;
        port fireCommandOut : ~FireCommandPort;
        flow fireFlow from fireCommandIn.fireCommand to fireCommandOut.fireCommand;
    }
    
    part def SafetyInterlock {
        attribute isEngaged : Boolean = true;
        port fireCommandIn : FireCommandPort;
        port fireCommandOut : ~FireCommandPort;
        flow fireFlow from fireCommandIn.fireCommand to fireCommandOut.fireCommand;
    }
    
    part def WeaponSystem {
        part gun : Gun;
        part ammunition : Ammunition;
        part firingMechanism : FiringMechanism;
        part safetyInterlock : SafetyInterlock;
        
        port fireControlPort : FireCommandPort;
        
        flow fireFlow1 from fireControlPort.fireCommand to safetyInterlock.fireCommandIn.fireCommand;
        flow fireFlow2 from safetyInterlock.fireCommandOut.fireCommand to firingMechanism.fireCommandIn.fireCommand;
        flow fireFlow3 from firingMechanism.fireCommandOut.fireCommand to gun.fireCommandIn.fireCommand;
    }
    
    part def ROTIGS_System {
        part operatorStation : OperatorStation;
        part thermalSight : ThermalSight;
        part weaponSystem : WeaponSystem;
        
        flow cmdFlow from operatorStation.commLink.commandOut.command to thermalSight.commandPort.command;
        flow statusFlow from thermalSight.statusPort.status to operatorStation.commLink.statusIn.status;
        flow videoFlow from thermalSight.videoPort.video to operatorStation.commLink.videoIn.video;
        flow targetFlow from thermalSight.targetPort.targetData to operatorStation.commLink.targetIn.targetData;
        flow fireCmdFlow from thermalSight.fireCommandOut.fireCommand to weaponSystem.fireControlPort.fireCommand;
        
        state machine systemState {
            entry; then standby;
            state standby;
            transition standby_to_searching first standby then searching;
            state searching;
            transition searching_to_tracking first searching then tracking;
            state tracking;
            transition tracking_to_locked first tracking then locked;
            state locked;
            transition locked_to_engaging first locked then engaging;
            state engaging;
            transition engaging_to_searching first engaging then searching;
        }
    }
    
    requirement remoteOperationRequirement {
        doc "The system shall allow an operator to control the thermal sight and weapon system from a remote location.";
    }
    
    requirement targetTrackingRequirement {
        doc "The thermal sight shall automatically track and maintain a lock on a designated target.";
    }
    
    requirement safetyInterlockRequirement {
        doc "The weapon system shall only fire when a confirmed target lock exists and the operator has explicitly authorized firing.";
    }
    
    requirement videoFeedRequirement {
        doc "The operator station shall display a live thermal video feed with targeting overlay.";
    }
    
    requirement stateSequenceRequirement {
        doc "The system shall transition through states: standby, searching, tracking, locked, engaging, and back to searching.";
    }
    
    part rotigs : ROTIGS_System;
    
    satisfy remoteOperationRequirement by rotigs;
    satisfy targetTrackingRequirement by rotigs.thermalSight;
    satisfy safetyInterlockRequirement by rotigs.weaponSystem;
    satisfy videoFeedRequirement by rotigs.operatorStation;
    satisfy stateSequenceRequirement by rotigs;
}
