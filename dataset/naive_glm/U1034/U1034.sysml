package DishwasherSystem {

    import ScalarValues::*;
    import ISQ::*;

    value type Temperature :> Real { unit 'degC'; }
    value type Volume :> Real { unit 'L'; }
    value type FlowRate :> Real { unit 'L/min'; }
    value type Pressure :> Real { unit 'bar'; }
    value type Power :> Real { unit 'kW'; }
    value type Duration :> Real { unit 'min'; }
    value type Percentage :> Real { unit '%'; }
    value type RotationalSpeed :> Real { unit 'rpm'; }
    value type Mass :> Real { unit 'g'; }

    item def FreshWater;
    item def HeatedWater;
    item def SoapyWater;
    item def DirtyWater;
    item def DetergentPod;
    item def FoodSoil;
    item def DirtyDish;
    item def CleanDish;
    item def HotAir;

    enum def WashCycleSelection { NORMAL; HEAVY; QUICK; ECO; }
    enum def CyclePhase { IDLE; PRE_WASH; MAIN_WASH; RINSE; DRYING; COMPLETE; }
    enum def DoorState { OPEN; CLOSED; LOCKED; }

    port def WaterFlowPort {
        out item FreshWater : FreshWater;
        in item DirtyWater : DirtyWater;
    }

    port def HeatedWaterPort {
        out item HeatedWater : HeatedWater;
    }

    port def SoapyWaterPort {
        out item SoapyWater : SoapyWater;
    }

    port def DrainPort {
        in item DirtyWater : DirtyWater;
    }

    port def ElectricalPowerPort {
        in attribute power : Power;
    }

    port def ControlSignalPort {
        in attribute command : String;
        out attribute status : String;
    }

    port def SensorSignalPort {
        out attribute reading : Real;
        out attribute unit : String;
    }

    port def DetergentReleasePort {
        out item DetergentPod : DetergentPod;
    }

    port def DishHoldingPort {
        in item DirtyDish : DirtyDish;
        out item CleanDish : CleanDish;
    }

    port def UserInterfacePort {
        in attribute cycleSelection : WashCycleSelection;
        in attribute startCommand : Boolean;
        out attribute phaseDisplay : CyclePhase;
        out attribute timeRemaining : Duration;
    }

    part def SprayArm {
        attribute rotationalSpeed : RotationalSpeedValue := 0 [rpm];
        attribute sprayPressure : PressureValue := 0.8 [bar];
        port sprayOut : HeatedWaterPort;
        port soapyOut : SoapyWaterPort;
        attribute active : Boolean := false;
        action def Rotate {
            in item water;
            out item spray;
        }
    }

    part def FilterAssembly {
        attribute meshSize : Real := 0.5 [mm];
        port soilIn : WaterFlowPort;
        port cleanWaterOut : HeatedWaterPort;
        attribute trappedSoilMass : Mass := 0 [g];
        action def TrapSoil {
            in item incomingWater;
            in item soil;
            out item filteredWater;
        }
    }

    part def WashChamber {
        attribute capacity : Volume := 14.0 [L];
        attribute currentVolume : Volume := 0.0 [L];
        attribute currentTemperature : Temperature := 20.0 [degC];
        port dishPort : DishHoldingPort;
        port upperArmMount : HeatedWaterPort;
        port lowerArmMount : HeatedWaterPort;
        port soapyUpper : SoapyWaterPort;
        port soapyLower : SoapyWaterPort;
        port filterInterface : WaterFlowPort;
        port drainOutlet : DrainPort;
        part upperSprayArm : SprayArm;
        part lowerSprayArm : SprayArm;
        part filter : FilterAssembly;
    }

    part def WaterInletValve {
        attribute flowRate : FlowRate := 6.0 [L/min];
        attribute open : Boolean := false;
        port supplyIn : WaterFlowPort;
        port chamberFill : WaterFlowPort;
        action def AdmitWater {
            in item freshWater;
            out item admittedWater;
        }
    }

    part def HeatingElement {
        attribute ratedPower : Power := 1.8 [kW];
        attribute active : Boolean := false;
        attribute targetTemperature : Temperature := 55.0 [degC];
        port powerIn : ElectricalPowerPort;
        port waterHeating : HeatedWaterPort;
        action def HeatWater {
            in item coldWater;
            in attribute targetTemp : Temperature;
            out item hotWater;
        }
    }

    part def CirculationPump {
        attribute ratedPower : Power := 0.25 [kW];
        attribute flowRate : FlowRate := 30.0 [L/min];
        attribute active : Boolean := false;
        port powerIn : ElectricalPowerPort;
        port suction : WaterFlowPort;
        port dischargeUpper : HeatedWaterPort;
        port dischargeLower : HeatedWaterPort;
        port soapyDischargeUpper : SoapyWaterPort;
        port soapyDischargeLower : SoapyWaterPort;
        action def Circulate {
            in item water;
            out item pressurizedWater;
        }
    }

    part def DrainPump {
        attribute ratedPower : Power := 0.18 [kW];
        attribute flowRate : FlowRate := 12.0 [L/min];
        attribute active : Boolean := false;
        port powerIn : ElectricalPowerPort;
        port drainIn : DrainPort;
        port drainOut : WaterFlowPort;
        action def ExpelWater {
            in item dirtyWater;
            out item expelledWater;
        }
    }

    part def DetergentDispenser {
        attribute podLoaded : Boolean := true;
        attribute released : Boolean := false;
        port releasePort : DetergentReleasePort;
        action def ReleaseDetergent {
            out item pod;
        }
    }

    part def TemperatureSensor {
        attribute measuredTemperature : Temperature := 20.0 [degC];
        attribute accuracy : Temperature := 1.0 [degC];
        port signalOut : SensorSignalPort;
        action def MeasureTemperature {
            in item water;
            out attribute temperature : Temperature;
        }
    }

    part def WaterLevelSensor {
        attribute measuredLevel : Volume := 0.0 [L];
        attribute threshold : Volume := 8.0 [L];
        port signalOut : SensorSignalPort;
        action def MeasureLevel {
            in item water;
            out attribute level : Volume;
        }
    }

    part def DoorLatch {
        attribute doorState : DoorState := DoorState::OPEN;
        attribute lockedDuringWetPhases : Boolean := true;
        port lockSignal : SensorSignalPort;
        action def LockDoor {
            in attribute command : Boolean;
            out attribute locked : Boolean;
        }
        action def UnlockDoor {
            out attribute unlocked : Boolean;
        }
    }

    part def ControlPanel {
        attribute selectedCycle : WashCycleSelection := WashCycleSelection::NORMAL;
        attribute startRequested : Boolean := false;
        port uiPort : UserInterfacePort;
        action def AcceptUserInput {
            out attribute cycle : WashCycleSelection;
            out attribute start : Boolean;
        }
    }

    part def ControlModule {
        attribute currentPhase : CyclePhase := CyclePhase::IDLE;
        attribute selectedCycle : WashCycleSelection := WashCycleSelection::NORMAL;
        attribute phaseDuration : Duration := 0.0 [min];
        attribute preWashDuration : Duration := 5.0 [min];
        attribute mainWashDuration : Duration := 45.0 [min];
        attribute rinseDuration : Duration := 15.0 [min];
        attribute dryingDuration : Duration := 25.0 [min];
        attribute washTargetTemp : Temperature := 55.0 [degC];
        attribute sanitizeTargetTemp : Temperature := 72.0 [degC];
        attribute dryTargetTemp : Temperature := 65.0 [degC];

        port uiPort : UserInterfacePort;
        port tempSensorPort : SensorSignalPort;
        port levelSensorPort : SensorSignalPort;
        port doorLatchPort : SensorSignalPort;
        port inletValveControl : ControlSignalPort;
        port heaterControl : ControlSignalPort;
        port circPumpControl : ControlSignalPort;
        port drainPumpControl : ControlSignalPort;
        port detergentControl : ControlSignalPort;

        state machine def DishwasherCycleStateMachine {
            attribute elapsed : Duration := 0.0 [min];

            state idle {
                entry action { ControlModule::currentPhase = CyclePhase::IDLE; }
                transition idle_to_preWash
                    when ControlPanel::startRequested == true
                    to preWash;
            }

            state preWash {
                entry action {
                    ControlModule::currentPhase = CyclePhase::PRE_WASH;
                    WaterInletValve::open = true;
                    DoorLatch::doorState = DoorState::LOCKED;
                }
                do action PreWashAction {
                    // Fill chamber with unheated water
                    WaterInletValve::open = true;
                    CirculationPump::active = true;
                    WashChamber::upperSprayArm::active = true;
                    WashChamber::lowerSprayArm::active = true;
                    // Spray for preliminary rinse
                    DrainPump::active = true;
                    WaterInletValve::open = false;
                    CirculationPump::active = false;
                    WashChamber::upperSprayArm::active = false;
                    WashChamber::lowerSprayArm::active = false;
                    DrainPump::active = false;
                }
                transition preWash_to_mainWash
                    when elapsed >= ControlModule::preWashDuration
                    to mainWash;
            }

            state mainWash {
                entry action {
                    ControlModule::currentPhase = CyclePhase::MAIN_WASH;
                    WaterInletValve::open = true;
                    DoorLatch::doorState = DoorState::LOCKED;
                }
                do action MainWashAction {
                    // Fill chamber
                    WaterInletValve::open = true;
                    // Heat water to wash temperature
                    HeatingElement::active = true;
                    HeatingElement::targetTemperature = ControlModule::washTargetTemp;
                    // Release detergent pod
                    DetergentDispenser::released = true;
                    // Circulate soapy water through spray arms
                    CirculationPump::active = true;
                    WashChamber::upperSprayArm::active = true;
                    WashChamber::lowerSprayArm::active = true;
                    // Extended wash period
                    HeatingElement::active = false;
                    CirculationPump::active = false;
                    WashChamber::upperSprayArm::active = false;
                    WashChamber::lowerSprayArm::active = false;
                    // Drain dirty water
                    DrainPump::active = true;
                    DrainPump::active = false;
                }
                transition mainWash_to_rinse
                    when elapsed >= ControlModule::mainWashDuration
                    to rinse;
            }

            state rinse {
                entry action {
                    ControlModule::currentPhase = CyclePhase::RINSE;
                    WaterInletValve::open = true;
                    DoorLatch::doorState = DoorState::LOCKED;
                }
                do action RinseAction {
                    // Fill with fresh water
                    WaterInletValve::open = true;
                    // Heat to sanitizing temperature
                    HeatingElement::active = true;
                    HeatingElement::targetTemperature = ControlModule::sanitizeTargetTemp;
                    // Circulate and rinse
                    CirculationPump::active = true;
                    WashChamber::upperSprayArm::active = true;
                    WashChamber::lowerSprayArm::active = true;
                    HeatingElement::active = false;
                    CirculationPump::active = false;
                    WashChamber::upperSprayArm::active = false;
                    WashChamber::lowerSprayArm::active = false;
                    // Drain
                    DrainPump::active = true;
                    DrainPump::active = false;
                }
                transition rinse_to_drying
                    when elapsed >= ControlModule::rinseDuration
                    to drying;
            }

            state drying {
                entry action {
                    ControlModule::currentPhase = CyclePhase::DRYING;
                    DoorLatch::doorState = DoorState::LOCKED;
                }
                do action DryingAction {
                    // Use residual heat and dedicated heating
                    HeatingElement::active = true;
                    HeatingElement::targetTemperature = ControlModule::dryTargetTemp;
                    // Circulate hot air
                    CirculationPump::active = false;
                    HeatingElement::active = false;
                }
                transition drying_to_complete
                    when elapsed >= ControlModule::dryingDuration
                    to complete;
            }

            state complete {
                entry action {
                    ControlModule::currentPhase = CyclePhase::COMPLETE;
                    DoorLatch::doorState = DoorState::CLOSED;
                }
                transition complete_to_idle
                    to idle;
            }
        }
    }

    part def Dishwasher {
        attribute modelIdentifier : String = "DW-2024-A";
        attribute ratedCapacity : Integer := 12;

        part controlModule : ControlModule;
        part controlPanel : ControlPanel;
        part washChamber : WashChamber;
        part waterInletValve : WaterInletValve;
        part heatingElement : HeatingElement;
        part circulationPump : CirculationPump;
        part drainPump : DrainPump;
        part detergentDispenser : DetergentDispenser;
        part temperatureSensor : TemperatureSensor;
        part waterLevelSensor : WaterLevelSensor;
        part doorLatch : DoorLatch;

        connection controlPanelToControlModule connect controlPanel.uiPort to controlModule.uiPort;
        connection tempSensorToControl connect temperatureSensor.signalOut to controlModule.tempSensorPort;
        connection levelSensorToControl connect waterLevelSensor.signalOut to controlModule.levelSensorPort;
        connection latchToControl connect doorLatch.lockSignal to controlModule.doorLatchPort;
        connection controlToInletValve connect controlModule.inletValveControl to waterInletValve.supplyIn;
        connection controlToHeater connect controlModule.heaterControl to heatingElement.powerIn;
        connection controlToCircPump connect controlModule.circPumpControl to circulationPump.powerIn;
        connection controlToDrainPump connect controlModule.drainPumpControl to drainPump.powerIn;
        connection controlToDetergent connect controlModule.detergentControl to detergentDispenser.releasePort;

        connection inletToChamber connect waterInletValve.chamberFill to washChamber.filterInterface;
        connection chamberToFilter connect washChamber.filterInterface to washChamber.filter.soilIn;
        connection filterToCirc connect washChamber.filter.cleanWaterOut to circulationPump.suction;
        connection circToUpperArm connect circulationPump.dischargeUpper to washChamber.upperArmMount;
        connection circToLowerArm connect circulationPump.dischargeLower to washChamber.lowerArmMount;
        connection circToSoapyUpper connect circulationPump.soapyDischargeUpper to washChamber.soapyUpper;
        connection circToSoapyLower connect circulationPump.soapyDischargeLower to washChamber.soapyLower;
        connection upperArmToChamber connect washChamber.upperArmMount to washChamber.upperSprayArm.sprayOut;
        connection lowerArmToChamber connect washChamber.lowerArmMount to washChamber.lowerSprayArm.sprayOut;
        connection heaterToCirc connect heatingElement.waterHeating to circulationPump.suction;
        connection chamberToDrain connect washChamber.drainOutlet to drainPump.drainIn;
        connection detergentToChamber connect detergentDispenser.releasePort to washChamber.filterInterface;
        connection tempSensorToChamber connect washChamber.filterInterface to temperatureSensor.signalOut;
        connection levelSensorToChamber connect washChamber.filterInterface to waterLevelSensor.signalOut;
    }

    requirement def CleaningEfficiencyRequirement {
        attribute minSoilRemoval : Percentage := 98.0 [%];
        subject dishwasher : Dishwasher;
        objective {
            doc /* The dishwasher shall remove at least 98% of soil from dishes in a complete cycle. */
        }
        require constraint {
            dishwasher.washChamber.dishPort.CleanDish.soilMass <= 0.02 * dishwasher.washChamber.dishPort.DirtyDish.soilMass
        }
    }

    requirement def WaterConservationRequirement {
        attribute maxWaterUsage : Volume := 13.0 [L];
        subject dishwasher : Dishwasher;
        objective {
            doc /* The dishwasher shall consume no more than 13 L of fresh water per complete cycle. */
        }
        require constraint {
            dishwasher.waterInletValve.flowRate * (ControlModule::preWashDuration + ControlModule::mainWashDuration + ControlModule::rinseDuration) <= maxWaterUsage
        }
    }

    requirement def SanitizingTemperatureRequirement {
        attribute minSanitizeTemp : Temperature := 72.0 [degC];
        subject dishwasher : Dishwasher;
        objective {
            doc /* The dishwasher shall achieve a minimum rinse temperature of 72 degC for sanitization. */
        }
        require constraint {
            dishwasher.washChamber.currentTemperature >= minSanitizeTemp during ControlModule::currentPhase == CyclePhase::RINSE
        }
    }

    requirement def DoorSafetyRequirement {
        subject dishwasher : Dishwasher;
        objective {
            doc /* The door shall remain locked throughout all wet phases of the cycle. */
        }
        require constraint {
            dishwasher.doorLatch.doorState == DoorState::LOCKED during
            (ControlModule::currentPhase == CyclePhase::PRE_WASH or
             ControlModule::currentPhase == CyclePhase::MAIN_WASH or
             ControlModule::currentPhase == CyclePhase::RINSE)
        }
    }

    requirement def CycleCompletionRequirement {
        subject dishwasher : Dishwasher;
        attribute maxCycleDuration : Duration := 120.0 [min];
        objective {
            doc /* The dishwasher shall complete a full cycle within 120 minutes. */
        }
        require constraint {
            (ControlModule::preWashDuration + ControlModule::mainWashDuration + ControlModule::rinseDuration + ControlModule::dryingDuration) <= maxCycleDuration
        }
    }

    requirement def DetergentReleaseRequirement {
        subject dishwasher : Dishwasher;
        objective {
            doc /* The detergent dispenser shall release the detergent pod during the main wash phase. */
        }
        require constraint {
            dishwasher.detergentDispenser.released == true during ControlModule::currentPhase == CyclePhase::MAIN_WASH
        }
    }

    requirement def HeatingElementRequirement {
        attribute maxHeaterPower : Power := 2.0 [kW];
        subject dishwasher : Dishwasher;
        objective {
            doc /* The heating element shall not exceed 2 kW rated power. */
        }
        require constraint {
            dishwasher.heatingElement.ratedPower <= maxHeaterPower
        }
    }

    package DishwasherRequirements {
        requirement cleaningEfficiency : CleaningEfficiencyRequirement;
        requirement waterConservation : WaterConservationRequirement;
        requirement sanitizingTemp : SanitizingTemperatureRequirement;
        requirement doorSafety : DoorSafetyRequirement;
        requirement cycleCompletion : CycleCompletionRequirement;
        requirement detergentRelease : DetergentReleaseRequirement;
        requirement heaterPower : HeatingElementRequirement;
    }

    package DishwasherInstances {
        part householdDishwasher : Dishwasher {
            satisfy cleaningEfficiency by dishwasher;
            satisfy waterConservation by dishwasher;
            satisfy sanitizingTemp by dishwasher;
            satisfy doorSafety by dishwasher;
            satisfy cycleCompletion by dishwasher;
            satisfy detergentRelease by dishwasher;
            satisfy heaterPower by dishwasher;
        }
    }

}
