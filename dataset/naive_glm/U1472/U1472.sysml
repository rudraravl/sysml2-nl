package GravitationalEnergyStorageSystem {
    import ISQ::*;
    import ScalarValues::*;
    import Time::*;

    attribute def MassValue :> Mass;
    attribute def HeightValue :> Length;
    attribute def EnergyValue :> Energy;
    attribute def PowerValue :> Power;
    attribute def VelocityValue :> Speed;
    attribute def ForceValue :> Force;
    attribute def CurrentValue :> ElectricCurrent;
    attribute def VoltageValue :> ElectricPotentialDifference;

    item def ElectricalEnergy {
        attribute energy : EnergyValue;
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def MechanicalEnergy {
        attribute energy : EnergyValue;
        attribute force : ForceValue;
        attribute velocity : VelocityValue;
    }

    item def ControlSignal {
        attribute command : String;
        attribute active : Boolean;
    }

    port def ElectricalPort {
        in item electricalEnergy : ElectricalEnergy;
    }

    port def MechanicalPort {
        in item mechanicalEnergy : MechanicalEnergy;
    }

    port def ControlPort {
        in item controlSignal : ControlSignal;
    }

    part def MassBlock {
        attribute mass : MassValue = 1000 [kg];
        attribute maxHeight : HeightValue = 50 [m];
        attribute currentHeight : HeightValue;
        attribute currentVelocity : VelocityValue;

        port mechanicalInterface : MechanicalPort;

        action def Descend :> Action {
            in height : HeightValue;
            out mechanicalEnergy : MechanicalEnergy;
        }

        action def Ascend :> Action {
            in mechanicalEnergy : MechanicalEnergy;
            out height : HeightValue;
        }

        perform action descend : Descend;
        perform action ascend : Ascend;
    }

    part def LiftingMechanism {
        attribute maxLiftingForce : ForceValue = 12000 [N];
        attribute liftingEfficiency : Real = 0.92;
        attribute isEngaged : Boolean;

        port electricalIn : ElectricalPort;
        port mechanicalOut : MechanicalPort;
        port controlIn : ControlPort;

        action def Lift :> Action {
            in electricalEnergy : ElectricalEnergy;
            out mechanicalEnergy : MechanicalEnergy;
        }

        perform action lift : Lift;

        requirement liftingCapacity {
            subject liftingMechanism : LiftingMechanism;
            objective {
                liftingMechanism.maxLiftingForce > 1000 [kg] * 9.81 [m/s^2]
            }
        }
    }

    part def ReleaseController {
        attribute operatorCommand : String;
        attribute systemStatus : String;
        attribute releaseRate : VelocityValue = 0.5 [m/s];

        port controlOut : ControlPort;
        port statusIn : ControlPort;

        action def EvaluateCommand :> Action {
            in command : String;
            in status : String;
            out controlSignal : ControlSignal;
        }

        perform action evaluate : EvaluateCommand;

        requirement commandResponse {
            subject controller : ReleaseController;
            objective {
                controller.operatorCommand == "discharge" implies controller.controlOut.controlSignal.command == "release"
            }
        }
    }

    part def PowerConverter {
        attribute conversionEfficiency : Real = 0.90;
        attribute ratedPower : PowerValue = 5000 [W];
        attribute isGenerating : Boolean;

        port mechanicalIn : MechanicalPort;
        port electricalOut : ElectricalPort;

        action def Generate :> Action {
            in mechanicalEnergy : MechanicalEnergy;
            out electricalEnergy : ElectricalEnergy;
        }

        perform action generate : Generate;

        requirement conversionEfficiencyRequirement {
            subject converter : PowerConverter;
            objective {
                converter.conversionEfficiency >= 0.85
            }
        }
    }

    part def GridInterface {
        attribute gridVoltage : VoltageValue = 400 [V];
        attribute gridFrequency : Real = 50 [Hz];

        port gridPort : ElectricalPort;

        action def SupplyGrid :> Action {
            in electricalEnergy : ElectricalEnergy;
        }

        action def DrawGrid :> Action {
            out electricalEnergy : ElectricalEnergy;
        }

        perform action supply : SupplyGrid;
        perform action draw : DrawGrid;
    }

    part def GravitationalStorageSystem {
        attribute maxEnergyStored : EnergyValue = 1000 [kg] * 9.81 [m/s^2] * 50 [m];
        attribute currentEnergy : EnergyValue;
        attribute systemState : String;

        port gridConnection : ElectricalPort;
        port operatorCommandPort : ControlPort;

        part massBlock : MassBlock {
            attribute mass = 1000 [kg];
            attribute maxHeight = 50 [m];
        }

        part liftingMechanism : LiftingMechanism;
        part releaseController : ReleaseController;
        part powerConverter : PowerConverter;
        part gridInterface : GridInterface;

        connect liftingMechanism.electricalIn to gridInterface.gridPort;
        connect liftingMechanism.mechanicalOut to massBlock.mechanicalInterface;
        connect releaseController.controlOut to liftingMechanism.controlIn;
        connect releaseController.controlOut to powerConverter.mechanicalIn;
        connect massBlock.mechanicalInterface to powerConverter.mechanicalIn;
        connect powerConverter.electricalOut to gridInterface.gridPort;
        connect operatorCommandPort to releaseController.statusIn;

        state machine def StorageLifecycle {
            attribute height : HeightValue;

            state idle;
            state charging;
            state charged;
            state discharging;

            transition idle_to_charging
                first idle
                if operatorCommandPort.controlSignal.command == "charge"
                then charging;

            transition charging_to_charged
                from charging
                to charged
                if massBlock.currentHeight >= massBlock.maxHeight;

            transition charged_to_discharging
                from charged
                to discharging
                if operatorCommandPort.controlSignal.command == "discharge";

            transition discharging_to_idle
                from discharging
                to idle
                if massBlock.currentHeight <= 0 [m];

            transition charged_to_idle
                from charged
                to idle
                if operatorCommandPort.controlSignal.command == "shutdown";
        }

        perform stateMachine : StorageLifecycle;

        requirement energyStorageCapacity {
            subject system : GravitationalStorageSystem;
            objective {
                system.maxEnergyStored == 1000 [kg] * 9.81 [m/s^2] * 50 [m]
            }
        }

        requirement maxHeightRequirement {
            subject system : GravitationalStorageSystem;
            objective {
                system.massBlock.maxHeight == 50 [m]
            }
        }

        requirement massBlockRequirement {
            subject system : GravitationalStorageSystem;
            objective {
                system.massBlock.mass == 1000 [kg]
            }
        }

        requirement operationalCycleRequirement {
            subject system : GravitationalStorageSystem;
            objective {
                system.systemState in {"idle", "charging", "charged", "discharging"}
            }
        }
    }
}
