package 'MatC System Model' {
    private import ScalarValues::*;
    private import ISQ::*;

    item def RawMaterial;
    item def ProcessedMaterial;
    item def ElectricalPower;
    item def ControlCommand;
    item def StatusReport;
    item def StartInit;
    item def StartBatch;
    item def EmergencyStop;

    port def MaterialPort {
        out item material;
    }
    port def PowerPort {
        out item power : ElectricalPower;
    }
    port def ControlPort {
        out item command : ControlCommand;
        in item status : StatusReport;
    }

    part def MaterialReceptor {
        attribute capacity :> ISQ::mass = 500 [kg];
        port materialInPort : ~MaterialPort;
        port materialOutPort : MaterialPort;
        port powerInPort : ~PowerPort;
        port controlPort : ~ControlPort;
    }

    part def ProcessingChamber {
        attribute targetTemp :> ISQ::temperature = 300 [degC];
        attribute operatingPressure :> ISQ::pressure = 101325 [Pa];
        attribute processingDuration :> ISQ::time = 3600 [s];
        port materialInPort : ~MaterialPort;
        port materialOutPort : MaterialPort;
        port powerInPort : ~PowerPort;
        port controlPort : ~ControlPort;
    }

    part def QualityAnalyzer {
        attribute requiredGrade : Real = 0.95;
        port materialInPort : ~MaterialPort;
        port materialOutPort : MaterialPort;
        port rejectPort : MaterialPort;
        port powerInPort : ~PowerPort;
        port controlPort : ~ControlPort;
    }

    part def MaterialDispenser {
        attribute bufferCapacity :> ISQ::mass = 100 [kg];
        attribute dispensingRate : Real = 10;
        port materialInPort : ~MaterialPort;
        port materialOutPort : MaterialPort;
        port powerInPort : ~PowerPort;
        port controlPort : ~ControlPort;
    }

    part def SystemController {
        port controlPorts : ControlPort;
        exhibit state controllerStates : SystemStates;
    }

    part def PowerDistribution {
        port highVoltageInPort : ~PowerPort;
        port powerOutPorts : PowerPort;
    }

    state def SystemStates {
        state Offline;
        state Initializing;
        state Ready;
        state Processing;
        state Dispensing;
        state Fault;

        transition from Offline to Initializing on StartInit;
        transition from Initializing to Ready;
        transition from Ready to Processing on StartBatch;
        transition from Processing to Dispensing;
        transition from Dispensing to Ready;
        transition from * to Fault on EmergencyStop;
    }

    part def MatCSystem {
        part receptor : MaterialReceptor;
        part chamber : ProcessingChamber;
        part analyzer : QualityAnalyzer;
        part dispenser : MaterialDispenser;
        part controller : SystemController;
        part powerDist : PowerDistribution;

        connect receptor.materialOutPort to chamber.materialInPort;
        connect chamber.materialOutPort to analyzer.materialInPort;
        connect analyzer.materialOutPort to dispenser.materialInPort;
        connect analyzer.rejectPort to receptor.materialInPort;

        connect powerDist.powerOutPorts to receptor.powerInPort;
        connect powerDist.powerOutPorts to chamber.powerInPort;
        connect powerDist.powerOutPorts to analyzer.powerInPort;
        connect powerDist.powerOutPorts to dispenser.powerInPort;

        connect controller.controlPorts to receptor.controlPort;
        connect controller.controlPorts to chamber.controlPort;
        connect controller.controlPorts to analyzer.controlPort;
        connect controller.controlPorts to dispenser.controlPort;
    }

    requirement def CapacityRequirement {
        subject p : MaterialReceptor;
        attribute maxCapacity :> ISQ::mass;
        constraint { p.capacity <= maxCapacity }
    }

    requirement def ProcessingRequirement {
        subject p : ProcessingChamber;
        attribute requiredTemp :> ISQ::temperature;
        constraint { p.targetTemp == requiredTemp }
    }

    requirement def DispensingRequirement {
        subject p : MaterialDispenser;
        attribute requiredRate : Real;
        constraint { p.dispensingRate == requiredRate }
    }

    requirement def SafetyRequirement {
        doc /* The system must support an immediate emergency shutdown transitioning to a Fault state. */
        subject p : SystemController;
    }

    part matCSystem : MatCSystem {
        exhibit state systemStates : SystemStates;
    }

    requirement matCSystemSpec {
        subject system : MatCSystem;
        require receptorCapacity : CapacityRequirement {
            subject = system.receptor;
            redefines maxCapacity = 500 [kg];
        }
        require chamberProcessing : ProcessingRequirement {
            subject = system.chamber;
            redefines requiredTemp = 300 [degC];
        }
        require dispenserRate : DispensingRequirement {
            subject = system.dispenser;
            redefines requiredRate = 10;
        }
        require emergencyShutdown : SafetyRequirement {
            subject = system.controller;
        }
    }
}
