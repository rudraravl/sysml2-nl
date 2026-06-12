package MieleApplianceHighLevelModel {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Volume;
    attribute def Mass;
    attribute def Temperature;
    attribute def Duration;
    attribute def Power;
    attribute def Energy;
    attribute def RotationalSpeed;
    attribute def FlowRate;

    item def LaundryLoad {
        attribute dryMass : Mass;
        attribute soilLevel : SoilLevelKind;
        attribute fabricType : FabricKind;
        attribute retainedWaterMass : Mass;
        attribute targetCleanliness : CleanlinessKind;
    }

    item def WaterSupply {
        attribute volume : Volume;
        attribute temperature : Temperature;
        attribute flowRate : FlowRate;
    }

    item def DetergentDose {
        attribute mass : Mass;
        attribute detergentType : DetergentKind;
        attribute concentrationPercent : Real;
    }

    item def WasteWater {
        attribute volume : Volume;
        attribute suspendedSoilMass : Mass;
        attribute detergentResidueMass : Mass;
        attribute temperature : Temperature;
    }

    item def CleanLaundry {
        attribute wetMass : Mass;
        attribute residualMoisturePercent : Real;
        attribute achievedCleanliness : CleanlinessKind;
    }

    enum def SoilLevelKind {
        enum light;
        enum normal;
        enum heavy;
    }

    enum def FabricKind {
        enum cotton;
        enum synthetic;
        enum wool;
        enum delicate;
        enum mixed;
    }

    enum def DetergentKind {
        enum liquid;
        enum powder;
        enum capsule;
        enum automaticTwinDos;
    }

    enum def CleanlinessKind {
        enum unwashed;
        enum refreshed;
        enum clean;
        enum hygienic;
    }

    enum def ProgramKind {
        enum cottonEco;
        enum cottonIntensive;
        enum mixedLoad;
        enum delicates;
        enum woolCare;
        enum quickWash;
        enum hygiene;
    }

    enum def DoorLockStateKind {
        enum unlocked;
        enum locked;
    }

    enum def ApplianceOperatingStateKind {
        enum off;
        enum standby;
        enum loading;
        enum dosing;
        enum filling;
        enum heating;
        enum washing;
        enum rinsing;
        enum draining;
        enum spinning;
        enum complete;
        enum fault;
    }

    port def ElectricalPowerPort {
        in item electricalEnergy : Energy;
        attribute nominalVoltage : Real;
        attribute maxPower : Power;
    }

    port def FreshWaterInletPort {
        in item water : WaterSupply;
        attribute maxFlowRate : FlowRate;
    }

    port def DrainOutletPort {
        out item wastewater : WasteWater;
        attribute pumpFlowRate : FlowRate;
    }

    port def LaundryAccessPort {
        in item dirtyLaundry : LaundryLoad;
        out item washedLaundry : CleanLaundry;
        attribute doorLockState : DoorLockStateKind;
    }

    port def DetergentInputPort {
        in item detergent : DetergentDose;
    }

    port def UserControlPort {
        in attribute selectedProgram : ProgramKind;
        in attribute startCommand : Boolean;
        in attribute pauseCommand : Boolean;
        in attribute cancelCommand : Boolean;
        out attribute remainingTime : Duration;
        out attribute operatingState : ApplianceOperatingStateKind;
    }

    port def ServiceDiagnosticPort {
        out attribute faultCode : String;
        out attribute cycleCount : Integer;
        out attribute energyUsedLastCycle : Energy;
        out attribute waterUsedLastCycle : Volume;
    }

    action def SenseLoad {
        in item load : LaundryLoad;
        out attribute estimatedMass : Mass;
        out attribute recommendedWaterVolume : Volume;
        out attribute recommendedDetergentMass : Mass;
    }

    action def DoseDetergent {
        in attribute requestedDose : Mass;
        in item detergentReservoirInput : DetergentDose;
        out item meteredDose : DetergentDose;
    }

    action def FillDrum {
        in item inletWater : WaterSupply;
        in attribute targetVolume : Volume;
        out item washWater : WaterSupply;
    }

    action def HeatWater {
        in item unheatedWater : WaterSupply;
        in attribute targetTemperature : Temperature;
        out item heatedWater : WaterSupply;
    }

    action def WashLaundry {
        in item dirtyLaundry : LaundryLoad;
        in item washWater : WaterSupply;
        in item detergent : DetergentDose;
        in attribute washDuration : Duration;
        out item partiallyCleanLaundry : LaundryLoad;
        out item soiledWater : WasteWater;
    }

    action def RinseLaundry {
        in item partiallyCleanLaundry : LaundryLoad;
        in item rinseWater : WaterSupply;
        out item rinsedLaundry : LaundryLoad;
        out item rinseWasteWater : WasteWater;
    }

    action def SpinExtract {
        in item rinsedLaundry : LaundryLoad;
        in attribute spinSpeed : RotationalSpeed;
        in attribute spinDuration : Duration;
        out item cleanLaundry : CleanLaundry;
        out item extractedWater : WasteWater;
    }

    action def DrainWater {
        in item collectedWasteWater : WasteWater;
        out item dischargedWasteWater : WasteWater;
    }

    action def ExecuteWashingCycle {
        in item incomingLaundry : LaundryLoad;
        in item incomingWater : WaterSupply;
        in item incomingDetergent : DetergentDose;
        in attribute selectedProgram : ProgramKind;
        out item outgoingLaundry : CleanLaundry;
        out item outgoingWasteWater : WasteWater;

        first start;
        then sense : SenseLoad {
            in load = incomingLaundry;
        }
        then dose : DoseDetergent {
            in requestedDose = sense.recommendedDetergentMass;
            in detergentReservoirInput = incomingDetergent;
        }
        then fill : FillDrum {
            in inletWater = incomingWater;
            in targetVolume = sense.recommendedWaterVolume;
        }
        then heat : HeatWater {
            in unheatedWater = fill.washWater;
            in targetTemperature = if selectedProgram == ProgramKind::hygiene then 333.15 [K] else 313.15 [K];
        }
        then wash : WashLaundry {
            in dirtyLaundry = incomingLaundry;
            in washWater = heat.heatedWater;
            in detergent = dose.meteredDose;
            in washDuration = if selectedProgram == ProgramKind::quickWash then 1200 [s] else 3600 [s];
        }
        then drainWash : DrainWater {
            in collectedWasteWater = wash.soiledWater;
        }
        then rinse : RinseLaundry {
            in partiallyCleanLaundry = wash.partiallyCleanLaundry;
            in rinseWater = incomingWater;
        }
        then drainRinse : DrainWater {
            in collectedWasteWater = rinse.rinseWasteWater;
        }
        then spin : SpinExtract {
            in rinsedLaundry = rinse.rinsedLaundry;
            in spinSpeed = if selectedProgram == ProgramKind::woolCare then 800 [1/min] else 1400 [1/min];
            in spinDuration = 600 [s];
        }
        then drainSpin : DrainWater {
            in collectedWasteWater = spin.extractedWater;
        }
        then done;

        bind outgoingLaundry = spin.cleanLaundry;
        bind outgoingWasteWater = drainSpin.dischargedWasteWater;
    }

    part def MieleFrontLoadWashingMachine {
        attribute modelName : String = "Miele W1 front-load washing machine";
        attribute primaryFunction : String = "Automatically clean household laundry by dosing detergent, adding and heating water, mechanically agitating textiles, rinsing away soil and detergent, extracting water by spin, and returning clean damp laundry to the user.";
        attribute ratedCapacity : Mass = 9 [kg];
        attribute maximumSpinSpeed : RotationalSpeed = 1400 [1/min];
        attribute nominalCycleEnergy : Energy = 0.65 [kW*h];
        attribute nominalCycleWaterUse : Volume = 48 [L];
        attribute operatingState : ApplianceOperatingStateKind = ApplianceOperatingStateKind::off;

        port powerPort : ElectricalPowerPort {
            attribute nominalVoltage = 120;
            attribute maxPower = 1.6 [kW];
        }

        port waterInlet : FreshWaterInletPort {
            attribute maxFlowRate = 10 [L/min];
        }

        port drainOutlet : DrainOutletPort {
            attribute pumpFlowRate = 18 [L/min];
        }

        port laundryDoor : LaundryAccessPort;
        port detergentDrawer : DetergentInputPort;
        port controls : UserControlPort;
        port diagnostics : ServiceDiagnosticPort;

        part drum {
            attribute usableVolume : Volume = 64 [L];
            attribute currentLoadMass : Mass;
            attribute rotationalSpeed : RotationalSpeed;
        }

        part brushlessMotor {
            attribute peakMechanicalPower : Power = 0.75 [kW];
            attribute commandedSpeed : RotationalSpeed;
            attribute measuredSpeed : RotationalSpeed;
        }

        part waterValve {
            attribute openCommand : Boolean;
            attribute measuredFlowRate : FlowRate;
        }

        part drainPump {
            attribute enabled : Boolean;
            attribute measuredPumpFlow : FlowRate;
        }

        part heater {
            attribute ratedHeatingPower : Power = 1.4 [kW];
            attribute enabled : Boolean;
            attribute measuredWaterTemperature : Temperature;
        }

        part detergentMeteringUnit {
            attribute reservoirVolume : Volume = 1.5 [L];
            attribute lastDoseMass : Mass;
        }

        part doorLock {
            attribute lockState : DoorLockStateKind = DoorLockStateKind::unlocked;
        }

        part loadSensor {
            attribute estimatedLoadMass : Mass;
            attribute imbalanceDetected : Boolean;
        }

        part controller {
            attribute selectedProgram : ProgramKind = ProgramKind::mixedLoad;
            attribute remainingCycleTime : Duration;
            attribute faultCode : String = "NONE";
            attribute totalCycleCount : Integer;
        }

        connection powerToController connect powerPort to controller;
        connection waterToValve connect waterInlet to waterValve;
        connection valveToDrum connect waterValve to drum;
        connection drawerToMeteringUnit connect detergentDrawer to detergentMeteringUnit;
        connection meteringUnitToDrum connect detergentMeteringUnit to drum;
        connection motorToDrum connect brushlessMotor to drum;
        connection heaterToDrum connect heater to drum;
        connection drumToDrainPump connect drum to drainPump;
        connection pumpToDrainOutlet connect drainPump to drainOutlet;
        connection doorToDrum connect laundryDoor to drum;
        connection lockToDoor connect doorLock to laundryDoor;
        connection controllerToControls connect controller to controls;
        connection controllerToDiagnostics connect controller to diagnostics;

        perform washingCycle : ExecuteWashingCycle {
            in incomingLaundry = laundryDoor.dirtyLaundry;
            in incomingWater = waterInlet.water;
            in incomingDetergent = detergentDrawer.detergent;
            in selectedProgram = controls.selectedProgram;
            out outgoingLaundry = laundryDoor.washedLaundry;
            out outgoingWasteWater = drainOutlet.wastewater;
        }

        state operatingBehavior {
            entry; then Off;

            state Off {
                entry action {
                    operatingState = ApplianceOperatingStateKind::off;
                    doorLock.lockState = DoorLockStateKind::unlocked;
                    heater.enabled = false;
                    drainPump.enabled = false;
                    waterValve.openCommand = false;
                }
            }

            transition Off_to_Standby
                first Off
                accept powerPort.electricalEnergy
                then Standby;

            state Standby {
                entry action {
                    operatingState = ApplianceOperatingStateKind::standby;
                    controls.operatingState = operatingState;
                    doorLock.lockState = DoorLockStateKind::unlocked;
                }
            }

            transition Standby_to_Loading
                first Standby
                accept laundryDoor.dirtyLaundry
                then Loading;

            state Loading {
                entry action {
                    operatingState = ApplianceOperatingStateKind::loading;
                    loadSensor.estimatedLoadMass = laundryDoor.dirtyLaundry.dryMass;
                }
            }

            transition Loading_to_Dosing
                first Loading
                accept controls.startCommand
                if loadSensor.estimatedLoadMass <= ratedCapacity
                then Dosing;

            state Dosing {
                entry action {
                    operatingState = ApplianceOperatingStateKind::dosing;
                    doorLock.lockState = DoorLockStateKind::locked;
                    detergentMeteringUnit.lastDoseMass =
                        if laundryDoor.dirtyLaundry.soilLevel == SoilLevelKind::heavy then 85 [g] else 55 [g];
                }
            }

            transition Dosing_to_Filling first Dosing then Filling;

            state Filling {
                entry action {
                    operatingState = ApplianceOperatingStateKind::filling;
                    waterValve.openCommand = true;
                }
                exit action {
                    waterValve.openCommand = false;
                }
            }

            transition Filling_to_Heating first Filling then Heating;

            state Heating {
                entry action {
                    operatingState = ApplianceOperatingStateKind::heating;
                    heater.enabled = true;
                }
                exit action {
                    heater.enabled = false;
                }
            }

            transition Heating_to_Washing first Heating then Washing;

            state Washing {
                entry action {
                    operatingState = ApplianceOperatingStateKind::washing;
                    brushlessMotor.commandedSpeed = 55 [1/min];
                }
            }

            transition Washing_to_DrainingWash first Washing then DrainingWash;

            state DrainingWash {
                entry action {
                    operatingState = ApplianceOperatingStateKind::draining;
                    drainPump.enabled = true;
                }
                exit action {
                    drainPump.enabled = false;
                }
            }

            transition DrainingWash_to_Rinsing first DrainingWash then Rinsing;

            state Rinsing {
                entry action {
                    operatingState = ApplianceOperatingStateKind::rinsing;
                    waterValve.openCommand = true;
                    brushlessMotor.commandedSpeed = 45 [1/min];
                }
                exit action {
                    waterValve.openCommand = false;
                }
            }

            transition Rinsing_to_DrainingRinse first Rinsing then DrainingRinse;

            state DrainingRinse {
                entry action {
                    operatingState = ApplianceOperatingStateKind::draining;
                    drainPump.enabled = true;
                }
                exit action {
                    drainPump.enabled = false;
                }
            }

            transition DrainingRinse_to_Spinning first DrainingRinse then Spinning;

            state Spinning {
                entry action {
                    operatingState = ApplianceOperatingStateKind::spinning;
                    brushlessMotor.commandedSpeed =
                        if controller.selectedProgram == ProgramKind::woolCare then 800 [1/min] else maximumSpinSpeed;
                    drainPump.enabled = true;
                }
                exit action {
                    drainPump.enabled = false;
                    brushlessMotor.commandedSpeed = 0 [1/min];
                }
            }

            transition Spinning_to_Complete first Spinning then Complete;

            state Complete {
                entry action {
                    operatingState = ApplianceOperatingStateKind::complete;
                    doorLock.lockState = DoorLockStateKind::unlocked;
                    controller.totalCycleCount = controller.totalCycleCount + 1;
                }
            }

            transition Complete_to_Standby first Complete then Standby;

            transition Any_to_Fault
                first Off, Standby, Loading, Dosing, Filling, Heating, Washing, DrainingWash, Rinsing, DrainingRinse, Spinning, Complete
                accept controller.faultCode
                if controller.faultCode != "NONE"
                then Fault;

            state Fault {
                entry action {
                    operatingState = ApplianceOperatingStateKind::fault;
                    heater.enabled = false;
                    waterValve.openCommand = false;
                    drainPump.enabled = false;
                    brushlessMotor.commandedSpeed = 0 [1/min];
                    controls.operatingState = operatingState;
                }
            }
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The appliance shall provide an automated laundry cleaning function at household scale. */
        subject washingMachine : MieleFrontLoadWashingMachine;
        require constraint {
            washingMachine.primaryFunction ==
            "Automatically clean household laundry by dosing detergent, adding and heating water, mechanically agitating textiles, rinsing away soil and detergent, extracting water by spin, and returning clean damp laundry to the user."
        }
    }

    requirement def CapacityRequirement {
        doc /* The appliance shall accept a normal household laundry load up to its rated capacity. */
        subject washingMachine : MieleFrontLoadWashingMachine;
        require constraint {
            washingMachine.ratedCapacity >= 8 [kg]
        }
    }

    requirement def WaterUseRequirement {
        doc /* The appliance should limit nominal water consumption for a mixed household cycle. */
        subject washingMachine : MieleFrontLoadWashingMachine;
        require constraint {
            washingMachine.nominalCycleWaterUse <= 55 [L]
        }
    }

    requirement def SpinExtractionRequirement {
        doc /* The appliance shall provide high-speed spin extraction to reduce retained moisture before drying. */
        subject washingMachine : MieleFrontLoadWashingMachine;
        require constraint {
            washingMachine.maximumSpinSpeed >= 1200 [1/min]
        }
    }

    requirement def DoorSafetyRequirement {
        doc /* The appliance shall keep the access door locked while filling, washing, rinsing, draining, or spinning. */
        subject washingMachine : MieleFrontLoadWashingMachine;
        require constraint {
            washingMachine.operatingState == ApplianceOperatingStateKind::filling or
            washingMachine.operatingState == ApplianceOperatingStateKind::washing or
            washingMachine.operatingState == ApplianceOperatingStateKind::rinsing or
            washingMachine.operatingState == ApplianceOperatingStateKind::draining or
            washingMachine.operatingState == ApplianceOperatingStateKind::spinning
            implies washingMachine.doorLock.lockState == DoorLockStateKind::locked
        }
    }

    requirement def FaultMitigationRequirement {
        doc /* The appliance shall de-energize heater, inlet valve, drain pump, and drive motor command when in fault state. */
        subject washingMachine : MieleFrontLoadWashingMachine;
        require constraint {
            washingMachine.operatingState == ApplianceOperatingStateKind::fault implies
            washingMachine.heater.enabled == false and
            washingMachine.waterValve.openCommand == false and
            washingMachine.drainPump.enabled == false and
            washingMachine.brushlessMotor.commandedSpeed == 0 [1/min]
        }
    }

    part mieleW1System : MieleFrontLoadWashingMachine;

    satisfy PrimaryFunctionRequirement by mieleW1System;
    satisfy CapacityRequirement by mieleW1System;
    satisfy WaterUseRequirement by mieleW1System;
    satisfy SpinExtractionRequirement by mieleW1System;
    satisfy DoorSafetyRequirement by mieleW1System;
    satisfy FaultMitigationRequirement by mieleW1System;
}