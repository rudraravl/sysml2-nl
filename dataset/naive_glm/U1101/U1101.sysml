package RoboticManufacturingSystem {
    import ISQ::*;
    import ScalarValues::*;

    attribute def Mass :> Real { unit = 'kg'; }
    attribute def Length :> Real { unit = 'm'; }
    attribute def Voltage :> Real { unit = 'V'; }
    attribute def Force :> Real { unit = 'N'; }
    attribute def Time :> Real { unit = 's'; }

    item def Workpiece {
        attribute weight : Mass;
    }

    port def PowerPort {
        attribute voltage : Voltage;
        out item electricity;
    }

    port def ControlPort {
        in item commands;
        out item status;
    }

    port def DataPort {
        in item sensorData;
        out item controlSignals;
    }

    port def MechanicalInterface {
        in item physicalWorkpiece : Workpiece;
    }

    part def Motor {
        port powerIn : PowerPort;
        port controlIn : ControlPort;
    }

    part def Joint {
        part motor : Motor;
        attribute angle : Real;
    }

    part def Gripper {
        port mechanicalInterface : MechanicalInterface;
        port controlIn : ControlPort;
        attribute state : String; // open, closed
    }

    part def PositionSensor {
        port dataOut : DataPort;
        attribute position : Length;
    }

    part def ForceSensor {
        port dataOut : DataPort;
        attribute force : Force;
    }

    part def RobotArm {
        attribute maxReach : Length = 2.0;
        attribute maxPayload : Mass = 25.0;
        attribute atPickupLocation : Boolean;
        attribute atDropoffLocation : Boolean;
        
        part joints : Joint[6];
        part gripper : Gripper;
        part positionSensor : PositionSensor;
        part forceSensor : ForceSensor;
        
        port controlIn : ControlPort;
        port powerIn : PowerPort;
    }

    part def Conveyor {
        attribute speed : Real;
        port powerIn : PowerPort;
        port controlIn : ControlPort;
        port mechanicalInterface : MechanicalInterface;
    }

    part def SafetyFence {
        attribute height : Length;
    }

    part def LightCurtain {
        port dataOut : DataPort;
        attribute breached : Boolean;
    }

    part def EmergencyStopButton {
        port dataOut : DataPort;
        attribute pressed : Boolean;
    }

    part def CollisionDetector {
        port dataOut : DataPort;
        attribute collisionDetected : Boolean;
    }

    part def SafetySystem {
        part lightCurtains : LightCurtain[2];
        part eStopButtons : EmergencyStopButton[4];
        part collisionDetectors : CollisionDetector[2];
        port dataOut : DataPort;
        
        attribute hazardDetected : Boolean;
        attribute hazardCleared : Boolean;
        attribute responseTime : Time;
    }

    part def RobotController {
        port robotControl : ControlPort;
        port safetyIn : DataPort;
        port plcComm : ControlPort;
        port powerIn : PowerPort;
        
        attribute trajectoryPlanned : Boolean;
        attribute executesPickAndPlace : Boolean;
    }

    part def MasterPLC {
        attribute mode : String; // automatic, manual, maintenance, emergency
        attribute cycleStart : Boolean;
        
        port robotComm : ControlPort;
        port conveyorComm : ControlPort[2];
        port safetyIn : DataPort;
        port powerIn : PowerPort;
    }

    part def PowerSupply {
        attribute outputVoltage : Voltage = 480.0;
        port powerOut : PowerPort;
    }

    part def TeachPendant {
        port controllerComm : ControlPort;
    }

    part def WorkCell {
        part powerSupply : PowerSupply;
        part masterPLC : MasterPLC;
        part robotController : RobotController;
        part robotArm : RobotArm;
        part inputConveyor : Conveyor;
        part outputConveyor : Conveyor;
        part safetyFence : SafetyFence;
        part safetySystem : SafetySystem;
        part teachPendant : TeachPendant;
        
        connect powerSupply.powerOut to masterPLC.powerIn;
        connect powerSupply.powerOut to robotController.powerIn;
        connect powerSupply.powerOut to robotArm.powerIn;
        connect powerSupply.powerOut to inputConveyor.powerIn;
        connect powerSupply.powerOut to outputConveyor.powerIn;
        
        connect masterPLC.robotComm to robotController.plcComm;
        connect masterPLC.conveyorComm[1] to inputConveyor.controlIn;
        connect masterPLC.conveyorComm[2] to outputConveyor.controlIn;
        
        connect robotController.robotControl to robotArm.controlIn;
        
        connect safetySystem.dataOut to masterPLC.safetyIn;
        connect safetySystem.dataOut to robotController.safetyIn;
        
        connect teachPendant.controllerComm to robotController.plcComm;
        
        state def CellOperationStateMachine {
            entry; 
            state automatic;
            state manual;
            state maintenance;
            state emergency;
            
            transition init_to_automatic initial -> automatic;
            transition automatic_to_manual automatic -> manual when [masterPLC.mode == "manual"];
            transition manual_to_automatic manual -> automatic when [masterPLC.mode == "automatic"];
            transition automatic_to_emergency automatic -> emergency when [safetySystem.hazardDetected];
            transition manual_to_emergency manual -> emergency when [safetySystem.hazardDetected];
            transition maintenance_to_emergency maintenance -> emergency when [safetySystem.hazardDetected];
            transition emergency_to_manual emergency -> manual when [safetySystem.hazardCleared && masterPLC.mode == "manual"];
        }
        
        state def PickAndPlaceStateMachine {
            state idle;
            state moveToPickup;
            state graspWorkpiece;
            state moveToDropoff;
            state placeWorkpiece;
            state inspectQuality;
            state errorHandling;
            
            attribute pickFailed : Boolean;
            attribute inspectionPassed : Boolean;
            attribute errorResolved : Boolean;
            
            transition init_to_idle initial -> idle;
            transition idle_to_moveToPickup idle -> moveToPickup when [masterPLC.cycleStart];
            transition moveToPickup_to_graspWorkpiece moveToPickup -> graspWorkpiece when [robotArm.atPickupLocation];
            transition graspWorkpiece_to_moveToDropoff graspWorkpiece -> moveToDropoff when [robotArm.gripper.state == "closed"];
            transition moveToDropoff_to_placeWorkpiece moveToDropoff -> placeWorkpiece when [robotArm.atDropoffLocation];
            transition placeWorkpiece_to_inspectQuality placeWorkpiece -> inspectQuality when [robotArm.gripper.state == "open"];
            transition inspectQuality_to_idle inspectQuality -> idle when [inspectionPassed];
            transition graspWorkpiece_to_errorHandling graspWorkpiece -> errorHandling when [pickFailed];
            transition inspectQuality_to_errorHandling inspectQuality -> errorHandling when [!inspectionPassed];
            transition errorHandling_to_idle errorHandling -> idle when [errorResolved];
        }
    }

    requirement def PayloadRequirement {
        subject robotArm : RobotArm;
        requirement :>> robotArm.maxPayload >= 25.0 [Mass];
    }

    requirement def ReachRequirement {
        subject robotArm : RobotArm;
        requirement :>> robotArm.maxReach >= 2.0 [Length];
    }

    requirement def SafetyRequirement {
        subject safetySystem : SafetySystem;
        requirement :>> safetySystem.responseTime < 0.1 [Time];
    }

    requirement def CycleRequirement {
        subject workCell : WorkCell;
        requirement :>> workCell.robotController.executesPickAndPlace == true;
    }
}
