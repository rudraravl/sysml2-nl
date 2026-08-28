package SaverySteamPump {
    import ISQ::*;
    import ScalarValues::*;

    value def PressureValue = Real { unit 'Pa'; }
    value def VolumeValue = Real { unit 'm3'; }
    value def TemperatureValue = Real { unit 'K'; }
    value def MassFlowRateValue = Real { unit 'kg/s'; }
    value def VolumeFlowRateValue = Real { unit 'm3/s'; }
    value def LengthValue = Real { unit 'm'; }
    value def MassValue = Real { unit 'kg'; }
    value def DurationValue = Real { unit 's'; }
    value def PowerValue = Real { unit 'W'; }
    value def AreaValue = Real { unit 'm2'; }

    item def Fluid {
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    item def Steam :> Fluid {
        attribute pressure : PressureValue = 8.0e5 [Pa];
        attribute temperature : TemperatureValue = 450 [K];
    }

    item def Water :> Fluid {
        attribute volume : VolumeValue;
        attribute temperature : TemperatureValue = 290 [K];
    }

    item def ColdWater :> Water {
        attribute temperature : TemperatureValue = 285 [K];
    }

    enum def ValvePosition { open; closed; }
    enum def FillState { empty; full; }
    enum def PumpStage { expulsion; condensation; intake; idle; }

    port def FluidPort {
        inout item fluid : Fluid;
    }

    part def ControlValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute position : ValvePosition = ValvePosition::closed;
        attribute flowRate : VolumeFlowRateValue = 0.0 [m3/s];

        action def Open {
            out newPosition : ValvePosition = ValvePosition::open;
        }

        action def Close {
            out newPosition : ValvePosition = ValvePosition::closed;
        }

        state valveStates {
            entry; then closedState;
            state closedState {
                transition to openState
                    when position == ValvePosition::open;
            }
            state openState {
                transition to closedState
                    when position == ValvePosition::closed;
            }
        }
    }

    part def CheckValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute allowsForwardFlow : Boolean = true;
        attribute allowsBackwardFlow : Boolean = false;
        attribute position : ValvePosition = ValvePosition::closed;
        attribute crackingPressure : PressureValue = 5.0e3 [Pa];

        state checkValveStates {
            entry; then sealed;
            state sealed {
                transition to flowing
                    when inlet.fluid.pressure > outlet.fluid.pressure + crackingPressure;
            }
            state flowing {
                transition to sealed
                    when outlet.fluid.pressure >= inlet.fluid.pressure;
            }
        }
    }

    part def Boiler {
        port steamOutlet : FluidPort;

        attribute maxPressure : PressureValue = 1.0e6 [Pa];
        attribute operatingPressure : PressureValue = 8.0e5 [Pa];
        attribute waterCapacity : VolumeValue = 0.5 [m3];
        attribute operatingTemperature : TemperatureValue = 450 [K];
        attribute heatInput : PowerValue = 50000 [W];
        attribute currentWaterLevel : VolumeValue = 0.4 [m3];

        part firebox {
            attribute fuelType : String = "coal";
            attribute burnRate : MassFlowRateValue = 0.01 [kg/s];
            attribute heatOutput : PowerValue = 50000 [W];
        }

        part pressureRelief {
            attribute threshold : PressureValue = 9.5e5 [Pa];
            attribute status : ValvePosition = ValvePosition::closed;
        }

        action def GenerateSteam {
            out generatedSteam : Steam;
        }

        state boilerOperation {
            entry; then heating;
            state heating {
                entry action GenerateSteam;
                transition to venting
                    when operatingPressure > pressureRelief.threshold;
            }
            state venting {
                entry { pressureRelief.status = ValvePosition::open; }
                transition to heating
                    when operatingPressure < 8.5e5 [Pa];
                exit { pressureRelief.status = ValvePosition::closed; }
            }
        }
    }

    part def ReceivingVessel {
        port steamInlet : FluidPort;
        port waterInlet : FluidPort;
        port waterOutlet : FluidPort;
        port coldWaterInlet : FluidPort;

        attribute capacity : VolumeValue = 0.2 [m3];
        attribute currentWaterVolume : VolumeValue = 0.0 [m3];
        attribute fillState : FillState = FillState::empty;
        attribute internalPressure : PressureValue = 1.01325e5 [Pa];
        attribute vesselHeight : LengthValue = 1.5 [m];
        attribute vesselDiameter : LengthValue = 0.4 [m];
        attribute crossSectionalArea : AreaValue = 0.1257 [m2];
        attribute wallThickness : LengthValue = 0.01 [m];
        attribute maxWorkingPressure : PressureValue = 1.2e6 [Pa];

        action def ExpelWater {
            doc { Steam pressure forces water out through delivery pipe. }
            in steamPressure : PressureValue;
            assign internalPressure := steamPressure;
            assign currentWaterVolume := 0.0 [m3];
            assign fillState := FillState::empty;
        }

        action def CondenseSteam {
            doc { Cold water spray condenses steam, creating vacuum. }
            in coldWaterVolume : VolumeValue;
            assign internalPressure := 2.0e4 [Pa];
            assign currentWaterVolume := coldWaterVolume;
        }

        action def IntakeWater {
            doc { Vacuum draws water up from mine through supply pipe. }
            assign currentWaterVolume := capacity;
            assign fillState := FillState::full;
            assign internalPressure := 1.01325e5 [Pa];
        }

        action def Pressurize {
            doc { Admit steam to pressurize vessel for expulsion. }
            in steam : Steam;
            assign internalPressure := steam.pressure;
        }
    }

    part def SupplyPipe {
        port mineEnd : FluidPort;
        port vesselEnd : FluidPort;

        attribute length : LengthValue = 8.0 [m];
        attribute diameter : LengthValue = 0.1 [m];
        attribute maxSuctionHeight : LengthValue = 10.0 [m];
        attribute flowResistance : Real = 0.5;
    }

    part def DeliveryPipe {
        port vesselEnd : FluidPort;
        port dischargeEnd : FluidPort;

        attribute length : LengthValue = 15.0 [m];
        attribute diameter : LengthValue = 0.1 [m];
        attribute dischargeHeight : LengthValue = 9.0 [m];
        attribute flowResistance : Real = 0.6;
    }

    part def ColdWaterSupply {
        port outlet : FluidPort;

        attribute reservoirCapacity : VolumeValue = 2.0 [m3];
        attribute waterTemperature : TemperatureValue = 285 [K];
        attribute sprayVolumePerCycle : VolumeValue = 0.002 [m3];
        attribute currentReservoirLevel : VolumeValue = 1.8 [m3];
    }

    part def SaverySteamPumpSystem {
        port mineWaterIntake : FluidPort;
        port dischargeOutlet : FluidPort;

        part boiler : Boiler;
        part receivingVessel : ReceivingVessel;
        part supplyPipe : SupplyPipe;
        part deliveryPipe : DeliveryPipe;
        part coldWaterSupply : ColdWaterSupply;

        part steamAdmissionValve : ControlValve;
        part coldWaterValve : ControlValve;
        part supplyCheckValve : CheckValve;
        part deliveryCheckValve : CheckValve;

        connection boiler.steamOutlet to steamAdmissionValve.inlet;
        connection steamAdmissionValve.outlet to receivingVessel.steamInlet;

        connection mineWaterIntake to supplyPipe.mineEnd;
        connection supplyPipe.vesselEnd to supplyCheckValve.inlet;
        connection supplyCheckValve.outlet to receivingVessel.waterInlet;

        connection receivingVessel.waterOutlet to deliveryCheckValve.inlet;
        connection deliveryCheckValve.outlet to deliveryPipe.vesselEnd;
        connection deliveryPipe.dischargeEnd to dischargeOutlet;

        connection coldWaterSupply.outlet to coldWaterValve.inlet;
        connection coldWaterValve.outlet to receivingVessel.coldWaterInlet;

        attribute cycleCount : Integer = 0;
        attribute totalPumpedVolume : VolumeValue = 0.0 [m3];
        attribute averageFlowRate : VolumeFlowRateValue = 0.0 [m3/s];
        attribute currentStage : PumpStage = PumpStage::idle;
        attribute cycleDuration : DurationValue = 30.0 [s];

        action def CompleteExpulsion {
            doc { Open steam valve, pressurize vessel, expel water through delivery. }
            assign steamAdmissionValve.position := ValvePosition::open;
            assign currentStage := PumpStage::expulsion;
            assign receivingVessel.internalPressure := boiler.operatingPressure;
            assign receivingVessel.currentWaterVolume := 0.0 [m3];
            assign receivingVessel.fillState := FillState::empty;
            assign totalPumpedVolume := totalPumpedVolume + receivingVessel.capacity;
            assign cycleCount := cycleCount + 1;
        }

        action def CompleteCondensation {
            doc { Close steam valve, open cold water valve, condense steam to create vacuum. }
            assign steamAdmissionValve.position := ValvePosition::closed;
            assign coldWaterValve.position := ValvePosition::open;
            assign currentStage := PumpStage::condensation;
            assign receivingVessel.internalPressure := 2.0e4 [Pa];
            assign receivingVessel.currentWaterVolume := coldWaterSupply.sprayVolumePerCycle;
        }

        action def CompleteIntake {
            doc { Vacuum draws water from mine through supply pipe into vessel. }
            assign coldWaterValve.position := ValvePosition::closed;
            assign currentStage := PumpStage::intake;
            assign receivingVessel.currentWaterVolume := receivingVessel.capacity;
            assign receivingVessel.fillState := FillState::full;
            assign receivingVessel.internalPressure := 1.01325e5 [Pa];
        }

        state pumpCycle {
            entry; then waterExpulsion;

            state waterExpulsion {
                doc { Stage 1: High-pressure steam admitted to push water out through delivery pipe. }
                entry {
                    steamAdmissionValve.position := ValvePosition::open;
                    currentStage := PumpStage::expulsion;
                }
                do action CompleteExpulsion;
                transition waterExpulsion_to_condensation
                    first waterExpulsion
                    then steamCondensation
                    when receivingVessel.fillState == FillState::empty;
                exit {
                    steamAdmissionValve.position := ValvePosition::closed;
                }
            }

            state steamCondensation {
                doc { Stage 2: Steam valve closed, cold water sprayed to condense steam and create vacuum. }
                entry {
                    coldWaterValve.position := ValvePosition::open;
                    currentStage := PumpStage::condensation;
                }
                do action CompleteCondensation;
                transition condensation_to_intake
                    first steamCondensation
                    then waterIntake
                    when receivingVessel.internalPressure <= 3.0e4 [Pa];
                exit {
                    coldWaterValve.position := ValvePosition::closed;
                }
            }

            state waterIntake {
                doc { Stage 3: Vacuum draws water up from mine through supply pipe. }
                entry {
                    currentStage := PumpStage::intake;
                }
                do action CompleteIntake;
                transition intake_to_expulsion
                    first waterIntake
                    then waterExpulsion
                    when receivingVessel.fillState == FillState::full;
            }
        }

        state systemOperation {
            entry; then running;
            state running {
                do perform pumpCycle;
                transition to stopped
                    when boiler.currentWaterLevel < 0.05 [m3];
            }
            state stopped {
                entry {
                    steamAdmissionValve.position := ValvePosition::closed;
                    coldWaterValve.position := ValvePosition::closed;
                    currentStage := PumpStage::idle;
                }
                transition to running
                    when boiler.currentWaterLevel >= 0.3 [m3];
            }
        }
    }

    requirement def SteamGenerationRequirement {
        subject boiler : Boiler;
        doc { The boiler shall generate steam at sufficient pressure to lift water to the required discharge height. }
        constraint { boiler.operatingPressure >= 9.0e5 [Pa] }
        constraint { boiler.operatingTemperature >= 445 [K] }
    }

    requirement def VacuumCreationRequirement {
        subject vessel : ReceivingVessel;
        doc { The receiving vessel shall create sufficient vacuum to draw water from the mine source. }
        constraint { vessel.internalPressure <= 3.0e4 [Pa] }
    }

    requirement def DeliveryHeightRequirement {
        subject delivery : DeliveryPipe;
        doc { The pump shall lift water to at least the specified discharge height above the vessel. }
        constraint { delivery.dischargeHeight >= 9.0 [m] }
    }

    requirement def SuctionHeightRequirement {
        subject supply : SupplyPipe;
        doc { The pump shall draw water from at least the specified suction depth below the vessel. }
        constraint { supply.maxSuctionHeight >= 8.0 [m] }
    }

    requirement def ContinuousCycleRequirement {
        subject pumpSystem : SaverySteamPumpSystem;
        doc { The pump cycle shall repeat continuously to provide pulsed water flow from mine to discharge. }
        constraint { pumpSystem.cycleCount >= 1 }
    }

    requirement def CheckValveIntegrityRequirement {
        subject supplyCheck : CheckValve;
        doc { The supply check valve shall prevent backflow from vessel to mine. }
        constraint { supplyCheck.allowsBackwardFlow == false }
    }

    requirement def DeliveryCheckValveIntegrityRequirement {
        subject deliveryCheck : CheckValve;
        doc { The delivery check valve shall prevent backflow from discharge to vessel. }
        constraint { deliveryCheck.allowsBackwardFlow == false }
    }

    requirement def VesselPressureRatingRequirement {
        subject vessel : ReceivingVessel;
        doc { The receiving vessel shall withstand maximum boiler steam pressure without failure. }
        constraint { vessel.maxWorkingPressure >= 1.0e6 [Pa] }
    }

    requirement def ColdWaterSupplyRequirement {
        subject coldSupply : ColdWaterSupply;
        doc { The cold water supply shall provide sufficient water for condensation across multiple cycles. }
        constraint { coldSupply.reservoirCapacity >= 2.0 [m3] }
        constraint { coldSupply.waterTemperature <= 290 [K] }
    }

    requirement def SaveryPumpSystemRequirement {
        subject pumpSystem : SaverySteamPumpSystem;
        doc { The Savery Steam Pump system shall remove water from flooded mines using steam pressure and vacuum without pistons or moving engine parts. }

        requirement steamReq : SteamGenerationRequirement {
            subject boiler = pumpSystem.boiler;
        }
        requirement vacuumReq : VacuumCreationRequirement {
            subject vessel = pumpSystem.receivingVessel;
        }
        requirement deliveryReq : DeliveryHeightRequirement {
            subject delivery = pumpSystem.deliveryPipe;
        }
        requirement suctionReq : SuctionHeightRequirement {
            subject supply = pumpSystem.supplyPipe;
        }
        requirement cycleReq : ContinuousCycleRequirement {
            subject pumpSystem = pumpSystem;
        }
        requirement supplyCheckReq : CheckValveIntegrityRequirement {
            subject supplyCheck = pumpSystem.supplyCheckValve;
        }
        requirement deliveryCheckReq : DeliveryCheckValveIntegrityRequirement {
            subject deliveryCheck = pumpSystem.deliveryCheckValve;
        }
        requirement vesselRatingReq : VesselPressureRatingRequirement {
            subject vessel = pumpSystem.receivingVessel;
        }
        requirement coldWaterReq : ColdWaterSupplyRequirement {
            subject coldSupply = pumpSystem.coldWaterSupply;
        }
    }

    verification def VerifyPumpCycleCompletion {
        subject pumpSystem : SaverySteamPumpSystem;
        objective {
            doc { Verify that the pump completes all four stages: expulsion, condensation, intake, and repeat. }
        }
    }

    verification def VerifyVacuumPressureAchieved {
        subject vessel : ReceivingVessel;
        objective {
            doc { Verify that steam condensation creates internal pressure at or below 30 kPa. }
        }
    }

    verification def VerifyDeliveryHeightAchieved {
        subject delivery : DeliveryPipe;
        subject boiler : Boiler;
        objective {
            doc { Verify that boiler steam pressure can lift water to the required discharge height of 9 meters. }
        }
    }

    verification def VerifyCheckValveOperation {
        subject supplyCheck : CheckValve;
        subject deliveryCheck : CheckValve;
        objective {
            doc { Verify that check valves permit forward flow and prevent backward flow. }
        }
    }

    verification def VerifyContinuousOperation {
        subject pumpSystem : SaverySteamPumpSystem;
        objective {
            doc { Verify that the pump sustains continuous cyclic operation for at least 10 cycles. }
        }
    }
}
