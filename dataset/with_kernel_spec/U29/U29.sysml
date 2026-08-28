package XenobotDrugDelivery {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def ChemicalConcentration :> Real;
    attribute def DrugMass :> Real;
    attribute def EnergyLevel :> Real;
    attribute def ForceValue :> Real;

    item def GradientSignal {
        attribute concentration : ChemicalConcentration;
        attribute direction : Real;
    }
    item def NavigationCommand {
        attribute heading : Real;
        attribute intensity : Real;
    }
    item def ReleaseCommand;
    item def TargetReachedSignal;
    item def DrugReleasedSignal;
    item def EnergyDepletedSignal;
    item def ChemicalGradientDetected;

    attribute def DrugPayload {
        attribute mass : DrugMass;
        attribute drugName : String;
    }

    port def ChemicalInputPort {
        in gradient : GradientSignal;
    }
    port def CommandOutputPort {
        out command : NavigationCommand;
    }
    port def CommandInputPort {
        in command : NavigationCommand;
    }
    port def ForceOutputPort {
        out force : ForceValue;
    }
    port def ReleaseInputPort {
        in release : ReleaseCommand;
    }
    port def ReleaseOutputPort {
        out released : DrugReleasedSignal;
    }

    action def DetectChemicalGradient {
        in signal : GradientSignal;
        out command : NavigationCommand;
        out detected : Boolean;
    }
    action def GeneratePropulsiveForce {
        in command : NavigationCommand;
        out force : ForceValue;
    }
    action def ReleaseDrug {
        in cmd : ReleaseCommand;
        out released : DrugReleasedSignal;
    }
    action def ConsumeEnergy {
        in amount : EnergyLevel;
        out remaining : EnergyLevel;
    }
    action def Biodegrade;

    part def ContractileCell {
        attribute contractilityRate : Real;
        port forcePort : ForceOutputPort;
        perform action contract : GeneratePropulsiveForce;
    }

    part def CiliatedCell {
        attribute beatFrequency : Real;
        port forcePort : ForceOutputPort;
        perform action beat : GeneratePropulsiveForce;
    }

    part def ChemotaxisSensor {
        port chemicalIn : ChemicalInputPort;
        port commandOut : CommandOutputPort;
        attribute detectionThreshold : ChemicalConcentration := 0.001;
        perform action detect : DetectChemicalGradient;
    }

    part def LocomotionModule {
        port commandIn : CommandInputPort;
        port forceOut : ForceOutputPort;
        part contractileCells : ContractileCell[1..*];
        part ciliatedCells : CiliatedCell[1..*];
        perform action propel : GeneratePropulsiveForce;
    }

    part def PayloadCarrier {
        attribute payload : DrugPayload;
        port releaseIn : ReleaseInputPort;
        port releaseOut : ReleaseOutputPort;
        perform action release : ReleaseDrug;
    }

    part def EnergySupply {
        attribute maxEnergy : EnergyLevel := 1000.0;
        attribute currentEnergy : EnergyLevel := 1000.0;
        perform action consume : ConsumeEnergy;
    }

    state def XenobotLifecycle {
        action detectAction : DetectChemicalGradient;
        action propelAction : GeneratePropulsiveForce;
        action releaseAction : ReleaseDrug;
        action biodegradeAction : Biodegrade;

        entry; then searching;

        state searching {
            do detectAction;
        }
        transition searchToNavigate
            first searching
            accept ChemicalGradientDetected
            then navigating;

        state navigating {
            do propelAction;
        }
        transition navigateToDeliver
            first navigating
            accept TargetReachedSignal
            then delivering;

        state delivering {
            do releaseAction;
        }
        transition deliverToSearch
            first delivering
            accept DrugReleasedSignal
            then searching;

        transition toDepleted
            first searching
            accept EnergyDepletedSignal
            then depleted;

        transition toDepletedFromNav
            first navigating
            accept EnergyDepletedSignal
            then depleted;

        transition toDepletedFromDeliver
            first delivering
            accept EnergyDepletedSignal
            then depleted;

        state depleted {
            do biodegradeAction;
        }
    }

    part def Xenobot {
        attribute biocompatible : Boolean := true;
        attribute biodegradable : Boolean := true;
        attribute targetThreshold : ChemicalConcentration := 0.01;

        port chemicalEnv : ChemicalInputPort;

        part sensor : ChemotaxisSensor;
        part motor : LocomotionModule;
        part carrier : PayloadCarrier;
        part energy : EnergySupply;

        exhibit state lifecycle : XenobotLifecycle;

        connect chemicalEnv to sensor.chemicalIn;
        connect sensor.commandOut to motor.commandIn;
        connect carrier.releaseOut to sensor.commandOut;
    }

    requirement def TargetedDeliveryRequirement {
        doc /* The Xenobot must deliver its drug payload precisely at the target site identified by chemotaxis. */
        subject xenobot : Xenobot;
    }

    requirement def BiocompatibilityRequirement {
        doc /* The Xenobot must be constructed from biocompatible materials to operate safely within a biological environment. */
        subject xenobot : Xenobot;
    }

    requirement def BiodegradabilityRequirement {
        doc /* The Xenobot must be biodegradable, breaking down naturally after mission completion or energy depletion. */
        subject xenobot : Xenobot;
    }

    requirement def EnergyBudgetRequirement {
        doc /* The Xenobot must complete its mission before internal energy is depleted. */
        subject xenobot : Xenobot;
        attribute minEnergy : EnergyLevel := 100.0;
    }

    part xenobotInstance : Xenobot {
        part sensor : ChemotaxisSensor;
        part motor : LocomotionModule;
        part carrier : PayloadCarrier;
        part energy : EnergySupply;

        connect chemicalEnv to sensor.chemicalIn;
        connect sensor.commandOut to motor.commandIn;
        connect carrier.releaseOut to sensor.commandOut;

        exhibit state lifecycle : XenobotLifecycle {
            action detectAction : DetectChemicalGradient;
            action propelAction : GeneratePropulsiveForce;
            action releaseAction : ReleaseDrug;
            action biodegradeAction : Biodegrade;

            entry; then searching;

            state searching {
                do detectAction;
            }
            transition searchToNavigate
                first searching
                accept ChemicalGradientDetected
                then navigating;

            state navigating {
                do propelAction;
            }
            transition navigateToDeliver
                first navigating
                accept TargetReachedSignal
                then delivering;

            state delivering {
                do releaseAction;
            }
            transition deliverToSearch
                first delivering
                accept DrugReleasedSignal
                then searching;

            transition toDepleted
                first searching
                accept EnergyDepletedSignal
                then depleted;

            transition toDepletedFromNav
                first navigating
                accept EnergyDepletedSignal
                then depleted;

            transition toDepletedFromDeliver
                first delivering
                accept EnergyDepletedSignal
                then depleted;

            state depleted {
                do biodegradeAction;
            }
        }

        satisfy TargetedDeliveryRequirement;
        satisfy BiocompatibilityRequirement;
        satisfy BiodegradabilityRequirement;
        satisfy EnergyBudgetRequirement;
    }
}
