package ClaytronicsSystem {

    attribute def Position {
        x : ScalarValues::Real;
        y : ScalarValues::Real;
        z : ScalarValues::Real;
    }

    attribute def TargetShape;

    attribute def MoveCommand {
        targetPosition : Position;
    }

    attribute def VerificationResult {
        isCorrect : ScalarValues::Boolean;
    }

    attribute def BondSignal {
        isAttached : ScalarValues::Boolean;
        force : ScalarValues::Real;
    }

    attribute def NeighborInfo {
        relativePositions : Position[*];
    }

    action def CalculateDestinations {
        in targetShape : TargetShape;
        out commands : MoveCommand[*];
    }

    action def VerifyShape {
        in verifications : VerificationResult[*];
        out result : ScalarValues::Boolean;
    }

    action def SenseNeighbors {
        out neighbors : NeighborInfo;
    }

    action def DetachBonds;

    action def PivotMove {
        in target : Position;
        in pivotNeighbor : NeighborInfo;
    }

    action def EstablishBonds;

    action def ReconfigureCatom {
        action senseStep : SenseNeighbors;
        then action detachStep : DetachBonds;
        then action pivotStep : PivotMove;
        then action bondStep : EstablishBonds;
    }

    port def ElectromagneticPort {
        in bond : BondSignal;
        out bondStatus : BondSignal;
        in data : MoveCommand;
        out data : MoveCommand;
    }

    port def ControllerPort {
        out command : MoveCommand;
        in verification : VerificationResult;
    }

    interface def CatomBondInterface {
        end p1 : ElectromagneticPort;
        end p2 : ElectromagneticPort;
    }

    interface def ControllerSwarmInterface {
        end controllerEnd : ControllerPort;
        end catomEnd : ControllerPort;
    }

    part def Processor;
    part def Sensor;
    part def PowerSupply;
    part def Actuator;

    part def Catom {
        part processor : Processor;
        part sensor : Sensor;
        part powerSupply : PowerSupply;
        part actuator : Actuator;

        port emPort[6] : ElectromagneticPort;
        port controlPort : ControllerPort;

        attribute currentPosition : Position;
        attribute targetPosition : Position;

        state def CatomBehavior {
            entry; then idle;

            state idle;
            transition
                first idle
                accept command : MoveCommand via controlPort
                do assign targetPosition := command.targetPosition
                then reconfiguring;

            state reconfiguring {
                do action reconfigureCatom : ReconfigureCatom;
            }
            then stable;

            state stable;
            transition
                first stable
                accept command : MoveCommand via controlPort
                do assign targetPosition := command.targetPosition
                then reconfiguring;
        }

        state catomState : CatomBehavior;
    }

    part def EnsembleController {
        port controlPort : ControllerPort;

        attribute currentTargetShape : TargetShape;

        action calculate : CalculateDestinations;
        action verifyShape : VerifyShape;

        state def ControllerBehavior {
            entry; then waitingForShape;

            state waitingForShape;
            transition
                first waitingForShape
                accept newShape : TargetShape
                do assign currentTargetShape := newShape
                then computing;

            state computing {
                do calculate;
            }
            then waitingForVerification;

            state waitingForVerification;
            transition
                first waitingForVerification
                accept result : VerificationResult via controlPort
                if result.isCorrect
                then waitingForShape;
        }

        state controllerState : ControllerBehavior;
    }

    part def ClaytronicsSystem {
        part controller : EnsembleController;
        part swarm : Catom[1000];

        flow commandFlow of MoveCommand
            from controller.controlPort.command to swarm.controlPort.command;
        flow verificationFlow of VerificationResult
            from swarm.controlPort.verification to controller.controlPort.verification;
    }

    action def ReconfigureShape {
        in targetShape : TargetShape;
        part controller : EnsembleController;
        part swarm : Catom[1000];

        action calculate : CalculateDestinations {
            in targetShape = targetShape;
            out commands : MoveCommand[*];
        }
        flow calculate.commands to swarm.controlPort.command;
        action verifyShape : VerifyShape {
            in verifications : VerificationResult[*];
            out result : ScalarValues::Boolean;
        }
    }

    requirement def Req_ShapeReconfiguration {
        text "The Claytronics system shall reconfigure from its current shape to a specified target shape.";
        subject system : ClaytronicsSystem;
        satisfy ReconfigureShape;
    }

    requirement def Req_CatomMobility {
        text "Each catom shall move by latching onto neighbors and pivoting to adjacent spaces without wheels or legs.";
        subject catom : Catom;
        satisfy Catom::CatomBehavior.reconfiguring;
    }

    requirement def Req_CollisionPrevention {
        text "The Ensemble Controller shall coordinate catom movements to prevent collisions during reconfiguration.";
        subject controller : EnsembleController;
        satisfy EnsembleController::ControllerBehavior.computing;
    }

    requirement def Req_StableShape {
        text "The system shall maintain a stable bonded structure once the target shape is achieved.";
        subject system : ClaytronicsSystem;
        satisfy Catom::CatomBehavior.stable;
    }
}
