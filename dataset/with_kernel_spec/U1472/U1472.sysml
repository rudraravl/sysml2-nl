package GravitationalEnergyStorage {
    private import ISQ::*;
    private import ScalarValues::*;
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        item def ElectricalEnergy;
        item def MechanicalEnergy;
        item def ReleaseSignal;

        attribute def StartChargingCmd;
        attribute def StartDischargingCmd;
        attribute def BlockAtMaxHeight;
        attribute def BlockAtMinHeight;

        port def ElectricalInPort {
            in item power : ElectricalEnergy;
        }
        port def ElectricalOutPort {
            out item power : ElectricalEnergy;
        }
        port def MechanicalPort {
            inout item energy : MechanicalEnergy;
        }
        port def ControlPort {
            out item command : ReleaseSignal;
        }

        part def MassBlock {
            attribute mass : MassValue = 1000 [kg];
            attribute maxHeight : LengthValue = 50 [m];
            attribute currentHeight : LengthValue;
            port mechanicalPort : MechanicalPort;
        }

        part def LiftingMechanism {
            port electricalIn : ElectricalInPort;
            port mechanicalOut : MechanicalPort;
            perform action liftMass : LiftMass {
                in energy = electricalIn.power;
                out mechanicalEnergy = mechanicalOut.energy;
            }
        }

        part def ReleaseController {
            port controlOut : ControlPort;
        }

        part def PowerConverter {
            port mechanicalIn : MechanicalPort;
            port electricalOut : ElectricalOutPort;
            port controlIn : ~ControlPort;
            perform action generatePower : GeneratePower {
                in mechanicalEnergy = mechanicalIn.energy;
                out energy = electricalOut.power;
            }
        }

        action def LiftMass {
            in energy : ElectricalEnergy;
            out mechanicalEnergy : MechanicalEnergy;
        }

        action def GeneratePower {
            in mechanicalEnergy : MechanicalEnergy;
            out energy : ElectricalEnergy;
        }

        requirement def StoreEnergy {
            doc /* The system shall store energy by lifting a heavy mass. */
        }
        requirement def GenerateElectricity {
            doc /* The system shall generate electricity by letting the mass descend in a controlled manner. */
        }
        requirement def MaxHeightLimit {
            doc /* The lifting mechanism shall hoist the block to a maximum height of 50 meters. */
        }
        requirement def MassSpecification {
            doc /* The mass block shall have a mass of 1000 kg. */
        }
        requirement def StateCycleManagement {
            doc /* The system shall operate in idle, charging, charged, and discharging states based on commands and status. */
        }
    }

    package Usages {
        private import Definitions::*;

        part storageSystem {
            port gridIn : ElectricalInPort;
            port gridOut : ElectricalOutPort;

            part releaseController : ReleaseController;
            part liftingMechanism : LiftingMechanism;
            part massBlock : MassBlock;
            part powerConverter : PowerConverter;

            flow of power : ElectricalEnergy
                from gridIn.power to liftingMechanism.electricalIn.power;

            flow of energy : MechanicalEnergy
                from liftingMechanism.mechanicalOut.energy to massBlock.mechanicalPort.energy;

            flow of energy : MechanicalEnergy
                from massBlock.mechanicalPort.energy to powerConverter.mechanicalIn.energy;

            flow of power : ElectricalEnergy
                from powerConverter.electricalOut.power to gridOut.power;

            flow of command : ReleaseSignal
                from releaseController.controlOut.command to powerConverter.controlIn.command;

            exhibit state systemStates {
                entry; then idle;
                state idle;
                accept StartChargingCmd then charging;
                state charging {
                    do liftingMechanism.liftMass;
                }
                accept BlockAtMaxHeight then charged;
                state charged;
                accept StartDischargingCmd then discharging;
                state discharging {
                    do powerConverter.generatePower;
                }
                accept BlockAtMinHeight then idle;
            }

            requirement storeEnergyReq : StoreEnergy;
            requirement generateElectricityReq : GenerateElectricity;
            requirement maxHeightLimitReq : MaxHeightLimit;
            requirement massSpecReq : MassSpecification;
            requirement stateCycleReq : StateCycleManagement;

            satisfy storeEnergyReq by liftingMechanism;
            satisfy generateElectricityReq by powerConverter;
            satisfy maxHeightLimitReq by massBlock.maxHeight;
            satisfy massSpecReq by massBlock.mass;
            satisfy stateCycleReq by systemStates;
        }
    }
}
