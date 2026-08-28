package BedpanManagementSystem {
    import ISQ::*;

    value type Volume :> Real { unit "L"; }
    value type Temperature :> Real { unit "degC"; }
    value type Pressure :> Real { unit "bar"; }
    value type Duration :> Real { unit "min"; }
    value type Mass :> Real { unit "kg"; }
    value type Level :> Real { unit "%"; }
    value type UVIntensity :> Real { unit "mW/cm^2"; }

    item def SanitizingAgent;
    item def WashWater;
    item def Waste;
    item def UVLight;

    enum def BedpanState {
        sterile;
        deployed;
        inUse;
        contaminated;
        emptying;
        washing;
        disinfecting;
        inspecting;
        returned;
    }

    enum def SanitationPhase {
        idle;
        washing;
        disinfecting;
        inspecting;
        complete;
        faulted;
    }

    enum def StorageStatus {
        ready;
        lowInventory;
        empty;
    }

    enum def DisposalStatus {
        accepting;
        emptying;
        discharging;
    }

    port def FluidLevelPort {
        in fluidVolume : Volume;
    }

    port def LevelOutputPort {
        out levelReading : Level;
        out nearCapacity : Boolean;
    }

    port def BedpanFlowPort {
        in bedpanIn : BedpanUnit;
        out bedpanOut : BedpanUnit;
    }

    port def AgentFlowPort {
        in agent : SanitizingAgent;
    }

    port def WaterFlowPort {
        in water : WashWater;
    }

    port def UVFlowPort {
        out uv : UVLight;
    }

    port def WasteFlowPort {
        out waste : Waste;
    }

    port def StatusPort {
        out phase : SanitationPhase;
        out cycleComplete : Boolean;
        out faultDetected : Boolean;
    }

    part def BedpanUnit {
        attribute serialNumber : String;
        attribute capacity : Volume = 2.5 [L];
        attribute material : String = "stainless steel";
        attribute mass : Mass = 0.8 [kg];
        attribute state : BedpanState = BedpanState::sterile;

        part basin {
            attribute contour : String = "ergonomic";
            attribute spillGuard : Boolean = true;
            attribute currentContents : Volume = 0.0 [L];
            port fluidLevelPort : FluidLevelPort;
        }

        part handle {
            attribute gripTexture : String = "textured";
            attribute loadRating : Mass = 5.0 [kg];
            attribute insulated : Boolean = true;
        }

        part levelSensor {
            attribute measurementRange : Level = 100.0 [%];
            attribute threshold : Level = 90.0 [%];
            attribute currentLevel : Level = 0.0 [%];
            attribute tolerance : Level = 2.5 [%];
            port levelOutput : LevelOutputPort;

            action def senseLevel {
                in fluidVolume : Volume;
                out levelReading : Level;
                out nearCapacity : Boolean;
                perform {
                    levelReading := (fluidVolume / 2.5 [L]) * 100.0 [%];
                    nearCapacity := levelReading >= threshold;
                }
            }
        }

        connect basin.fluidLevelPort to levelSensor.levelOutput;
    }

    part def SanitationFacility {
        attribute washTemperature : Temperature = 85.0 [degC];
        attribute washPressure : Pressure = 6.0 [bar];
        attribute washDuration : Duration = 12.0 [min];
        attribute disinfectionDuration : Duration = 8.0 [min];
        attribute uvIntensity : UVIntensity = 55.0 [mW/cm^2];
        attribute throughput : Integer = 4;

        port bedpanInput : BedpanFlowPort;
        port bedpanOutput : BedpanFlowPort;
        port agentSupply : AgentFlowPort;
        port waterSupply : WaterFlowPort;
        port uvEmission : UVFlowPort;
        port statusOut : StatusPort;

        part washChamber {
            attribute capacity : Integer = 4;
            attribute currentLoad : Integer = 0;
            attribute temperature : Temperature = 85.0 [degC];
            attribute pressure : Pressure = 6.0 [bar];
        }

        part disinfectionChamber {
            attribute uvLamps : Integer = 6;
            attribute exposureTime : Duration = 8.0 [min];
        }

        part inspectionUnit {
            attribute cleanlinessThreshold : Level = 99.9 [%];
            attribute integrityCheck : Boolean = true;

            action def inspect {
                in bedpan : BedpanUnit;
                out passed : Boolean;
                perform {
                    passed := (bedpan.basin.currentContents == 0.0 [L]) and (bedpan.handle.loadRating >= 5.0 [kg]);
                }
            }
        }

        attribute washTimer : Duration = 0.0 [min];
        attribute disinfectionTimer : Duration = 0.0 [min];
        attribute operatorReset : Boolean = false;
        attribute currentPhase : SanitationPhase = SanitationPhase::idle;

        state machine def SanitationBehavior {
            entry; then idle;

            state idle {
                attribute currentPhase : SanitationPhase = SanitationPhase::idle;
            }
            state washing {
                attribute currentPhase : SanitationPhase = SanitationPhase::washing;
            }
            state disinfecting {
                attribute currentPhase : SanitationPhase = SanitationPhase::disinfecting;
            }
            state inspecting {
                attribute currentPhase : SanitationPhase = SanitationPhase::inspecting;
            }
            state complete {
                attribute currentPhase : SanitationPhase = SanitationPhase::complete;
            }
            state faulted {
                attribute currentPhase : SanitationPhase = SanitationPhase::faulted;
            }

            transition idle to washing
                when bedpanInput.bedpanIn.state == BedpanState::emptying;
            transition washing to disinfecting
                when washTimer >= washDuration;
            transition disinfecting to inspecting
                when disinfectionTimer >= disinfectionDuration;
            transition inspecting to complete
                when inspectionUnit.inspect().passed == true;
            transition inspecting to faulted
                when inspectionUnit.inspect().passed == false;
            transition complete to idle
                when bedpanOutput.bedpanOut.state == BedpanState::sterile;
            transition faulted to idle
                when operatorReset == true;
        }
    }

    part def StorageRack {
        attribute slotCount : Integer = 20;
        attribute occupiedSlots : Integer = 0;
        attribute minInventory : Integer = 5;
        attribute status : StorageStatus = StorageStatus::ready;

        port storageIn : BedpanFlowPort;
        port storageOut : BedpanFlowPort;

        action def store {
            in bedpan : BedpanUnit;
            perform {
                occupiedSlots := occupiedSlots + 1;
            }
        }

        action def retrieve {
            out bedpan : BedpanUnit;
            perform {
                occupiedSlots := occupiedSlots - 1;
            }
        }

        state machine def StorageBehavior {
            entry; then ready;

            state ready;
            state lowInventory;
            state empty;

            transition ready to lowInventory when occupiedSlots < minInventory;
            transition lowInventory to ready when occupiedSlots >= minInventory;
            transition lowInventory to empty when occupiedSlots == 0;
            transition empty to lowInventory when occupiedSlots > 0;
        }
    }

    part def WasteDisposal {
        attribute hopperCapacity : Volume = 50.0 [L];
        attribute currentWasteVolume : Volume = 0.0 [L];
        attribute status : DisposalStatus = DisposalStatus::accepting;
        attribute emptyingComplete : Boolean = false;

        port bedpanIn : BedpanFlowPort;
        port bedpanOut : BedpanFlowPort;
        port wasteOut : WasteFlowPort;

        action def empty {
            in bedpan : BedpanUnit;
            out emptiedBedpan : BedpanUnit;
            out waste : Waste;
            perform {
                waste := bedpan.basin.currentContents as Waste;
                emptiedBedpan.basin.currentContents := 0.0 [L];
                emptiedBedpan.state := BedpanState::emptying;
                currentWasteVolume := currentWasteVolume + bedpan.basin.currentContents;
            }
        }

        action def discharge {
            out waste : Waste;
            perform {
                currentWasteVolume := 0.0 [L];
            }
        }

        state machine def DisposalBehavior {
            entry; then accepting;

            state accepting;
            state emptying;
            state discharging;

            transition accepting to emptying
                when bedpanIn.bedpanIn.state == BedpanState::contaminated;
            transition emptying to discharging
                when emptyingComplete == true;
            transition discharging to accepting
                when bedpanOut.bedpanOut.state == BedpanState::emptying;
        }
    }

    part def Caregiver {
        attribute id : String;
        attribute name : String;

        port handPort : BedpanFlowPort;

        action def transport {
            in bedpan : BedpanUnit;
            out bedpan : BedpanUnit;
            perform {
                bedpan.state := BedpanState::deployed;
            }
        }

        action def deliverToPatient {
            in bedpan : BedpanUnit;
            out bedpan : BedpanUnit;
            perform {
                bedpan.state := BedpanState::inUse;
            }
        }

        action def retrieveFromPatient {
            in bedpan : BedpanUnit;
            out bedpan : BedpanUnit;
            perform {
                bedpan.state := BedpanState::contaminated;
            }
        }
    }

    part def Patient {
        attribute id : String;
        attribute name : String;
        attribute bedridden : Boolean = true;

        port usePort : BedpanFlowPort;

        action def use {
            in bedpan : BedpanUnit;
            out bedpan : BedpanUnit;
            perform {
                bedpan.basin.currentContents := 1.8 [L];
                bedpan.state := BedpanState::contaminated;
            }
        }
    }

    part def BedpanManagementSystem {
        attribute facilityName : String = "Central Healthcare Facility";
        attribute facilityId : String;

        part storageRack : StorageRack;
        part wasteDisposal : WasteDisposal;
        part sanitationFacility : SanitationFacility;
        part bedpans : BedpanUnit[8];
        part caregivers : Caregiver[4];
        part patients : Patient[6];

        part agentReservoir : SanitizingAgent;
        part waterReservoir : WashWater;
        part wasteReceiver : Waste;
        part uvEmitter : UVLight;

        connect storageRack.storageOut to caregivers.handPort;
        connect caregivers.handPort to patients.usePort;
        connect patients.usePort to caregivers.handPort;
        connect caregivers.handPort to wasteDisposal.bedpanIn;
        connect wasteDisposal.bedpanOut to sanitationFacility.bedpanInput;
        connect sanitationFacility.bedpanOutput to storageRack.storageIn;

        connect agentReservoir to sanitationFacility.agentSupply;
        connect waterReservoir to sanitationFacility.waterSupply;
        connect uvEmitter to sanitationFacility.uvEmission;
        connect wasteDisposal.wasteOut to wasteReceiver;

        state machine def LifecycleBehavior {
            entry; then sterile;

            state sterile;
            state deployed;
            state inUse;
            state contaminated;
            state emptying;
            state washing;
            state disinfecting;
            state inspecting;
            state returned;

            transition sterile to deployed
                when storageRack.storageOut.bedpanOut.state == BedpanState::sterile;
            transition deployed to inUse
                when patients.usePort.bedpanIn.state == BedpanState::inUse;
            transition inUse to contaminated
                when patients.usePort.bedpanOut.state == BedpanState::contaminated;
            transition contaminated to emptying
                when wasteDisposal.bedpanIn.bedpanIn.state == BedpanState::contaminated;
            transition emptying to washing
                when wasteDisposal.bedpanOut.bedpanOut.state == BedpanState::emptying;
            transition washing to disinfecting
                when sanitationFacility.statusOut.phase == SanitationPhase::disinfecting;
            transition disinfecting to inspecting
                when sanitationFacility.statusOut.phase == SanitationPhase::inspecting;
            transition inspecting to returned
                when sanitationFacility.statusOut.phase == SanitationPhase::complete;
            transition returned to sterile
                when storageRack.storageIn.bedpanIn.state == BedpanState::sterile;
        }
    }

    requirement def HygieneRequirement {
        subject system : BedpanManagementSystem;
        requirement {
            system.sanitationFacility.washTemperature >= 82.0 [degC];
        }
        requirement {
            system.sanitationFacility.washPressure >= 4.0 [bar];
        }
        requirement {
            system.sanitationFacility.disinfectionDuration >= 5.0 [min];
        }
        requirement {
            system.sanitationFacility.uvIntensity >= 40.0 [mW/cm^2];
        }
    }

    requirement def CapacityRequirement {
        subject bedpan : BedpanUnit;
        requirement {
            bedpan.capacity >= 2.5 [L];
        }
    }

    requirement def InventoryRequirement {
        subject rack : StorageRack;
        requirement {
            rack.occupiedSlots >= rack.minInventory;
        }
    }

    requirement def CrossContaminationRequirement {
        subject system : BedpanManagementSystem;
        requirement {
            forall b in system.bedpans {
                b.state == BedpanState::sterile implies b.basin.currentContents == 0.0 [L];
            }
        }
        requirement {
            forall b in system.bedpans {
                b.state == BedpanState::contaminated implies b.state != BedpanState::sterile;
            }
        }
    }

    requirement def PatientComfortRequirement {
        subject bedpan : BedpanUnit;
        requirement {
            bedpan.basin.contour == "ergonomic";
        }
        requirement {
            bedpan.basin.spillGuard == true;
        }
        requirement {
            bedpan.handle.gripTexture == "textured";
        }
    }

    requirement def LevelSensorRequirement {
        subject bedpan : BedpanUnit;
        requirement {
            bedpan.levelSensor.threshold <= 90.0 [%];
        }
        requirement {
            bedpan.levelSensor.measurementRange == 100.0 [%];
        }
    }

    requirement def ClosedLoopRequirement {
        subject system : BedpanManagementSystem;
        requirement {
            system.sanitationFacility.bedpanOutput.bedpanOut.state == BedpanState::sterile;
        }
        requirement {
            system.storageRack.storageIn.bedpanIn.state == BedpanState::sterile;
        }
    }

    requirement def DisposalRequirement {
        subject disposal : WasteDisposal;
        requirement {
            disposal.bedpanOut.bedpanOut.basin.currentContents == 0.0 [L];
        }
        requirement {
            disposal.currentWasteVolume <= disposal.hopperCapacity;
        }
    }

    requirement def InspectionRequirement {
        subject facility : SanitationFacility;
        requirement {
            facility.inspectionUnit.cleanlinessThreshold >= 99.9 [%];
        }
    }

    requirement def MaterialRequirement {
        subject bedpan : BedpanUnit;
        requirement {
            bedpan.material == "stainless steel";
        }
        requirement {
            bedpan.handle.loadRating >= 5.0 [kg];
        }
    }

    satisfaction HygieneRequirement : system = BedpanManagementSystem;
    satisfaction CapacityRequirement : bedpan = BedpanUnit;
    satisfaction InventoryRequirement : rack = StorageRack;
    satisfaction CrossContaminationRequirement : system = BedpanManagementSystem;
    satisfaction PatientComfortRequirement : bedpan = BedpanUnit;
    satisfaction LevelSensorRequirement : bedpan = BedpanUnit;
    satisfaction ClosedLoopRequirement : system = BedpanManagementSystem;
    satisfaction DisposalRequirement : disposal = WasteDisposal;
    satisfaction InspectionRequirement : facility = SanitationFacility;
    satisfaction MaterialRequirement : bedpan = BedpanUnit;
}
