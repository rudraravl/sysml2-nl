package 'Check Weigher System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def Product {
        attribute mass : MassValue;
    }

    item def WeightMeasurement {
        attribute value : MassValue;
    }

    enum def DecisionKind {
        Pass;
        Fail;
    }

    item def SortDecision {
        attribute decision : DecisionKind;
    }

    attribute def StartSignal;
    attribute def StopSignal;
    attribute def WeightMeasured;
    attribute def DecisionMade;
    attribute def ProductSorted;

    part def InfeedConveyor {
        port inProductPort {
            in product : Product;
        }
        port outProductPort {
            out product : Product;
        }
        attribute speed : Real = 0.5 [m/s];
    }

    part def WeighingStation {
        port inProductPort {
            in product : Product;
        }
        port outProductPort {
            out product : Product;
        }
        port outMeasurementPort {
            out measurement : WeightMeasurement;
        }
    }

    part def ControlUnit {
        port inMeasurementPort {
            in measurement : WeightMeasurement;
        }
        port outDecisionPort {
            out decision : SortDecision;
        }
        attribute targetWeight : MassValue = 500 [g];
        attribute upperTolerance : MassValue = 5 [g];
        attribute lowerTolerance : MassValue = 5 [g];
    }

    part def RejectMechanism {
        port inProductPort {
            in product : Product;
        }
        port inDecisionPort {
            in decision : SortDecision;
        }
        port outAcceptPort {
            out product : Product;
        }
        port outRejectPort {
            out product : Product;
        }
    }

    part def AcceptConveyor {
        port inProductPort {
            in product : Product;
        }
        port outProductPort {
            out product : Product;
        }
    }

    part def RejectConveyor {
        port inProductPort {
            in product : Product;
        }
        port outProductPort {
            out product : Product;
        }
    }

    part def CheckWeigherSystem {
        port inProductPort {
            in product : Product;
        }
        port outAcceptPort {
            out product : Product;
        }
        port outRejectPort {
            out product : Product;
        }

        part infeedConveyor : InfeedConveyor;
        part weighingStation : WeighingStation;
        part controlUnit : ControlUnit;
        part rejectMechanism : RejectMechanism;
        part acceptConveyor : AcceptConveyor;
        part rejectConveyor : RejectConveyor;

        flow infeedFlow of Product
            from inProductPort.product to infeedConveyor.inProductPort.product;
        flow toWeighingFlow of Product
            from infeedConveyor.outProductPort.product to weighingStation.inProductPort.product;
        flow measurementFlow of WeightMeasurement
            from weighingStation.outMeasurementPort.measurement to controlUnit.inMeasurementPort.measurement;
        flow fromWeighingFlow of Product
            from weighingStation.outProductPort.product to rejectMechanism.inProductPort.product;
        flow decisionFlow of SortDecision
            from controlUnit.outDecisionPort.decision to rejectMechanism.inDecisionPort.decision;
        flow acceptFlow of Product
            from rejectMechanism.outAcceptPort.product to acceptConveyor.inProductPort.product;
        flow rejectFlow of Product
            from rejectMechanism.outRejectPort.product to rejectConveyor.inProductPort.product;
        flow outAcceptFlow of Product
            from acceptConveyor.outProductPort.product to outAcceptPort.product;
        flow outRejectFlow of Product
            from rejectConveyor.outProductPort.product to outRejectPort.product;

        state checkWeigherStates {
            entry; then idle;
            state idle;
            accept StartSignal
                then active;
            state active {
                entry; then weighing;
                state weighing;
                accept WeightMeasured
                    then evaluating;
                state evaluating;
                accept DecisionMade
                    then sorting;
                state sorting;
                accept ProductSorted
                    then weighing;
            }
            accept StopSignal
                then idle;
        }
    }

    requirement CheckWeigherRequirement {
        doc /* The system shall continuously weigh products on a conveyor, compare against a target weight of 500g with a tolerance of plus or minus 5g, and automatically divert out-of-tolerance items while passing compliant items to the next stage. */;
        subject checkWeigher : CheckWeigherSystem;
        constraint { checkWeigher.controlUnit.targetWeight == 500 [g] }
        constraint { checkWeigher.controlUnit.upperTolerance == 5 [g] }
        constraint { checkWeigher.controlUnit.lowerTolerance == 5 [g] }
    }
}
