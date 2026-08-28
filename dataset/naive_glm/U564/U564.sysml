package SolarFluidPumpingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def PowerValue :> Real { unit = "W"; }
    value def VoltageValue :> Real { unit = "V"; }
    value def CurrentValue :> Real { unit = "A"; }
    value def EnergyValue :> Real { unit = "J"; }
    value def ChargeLevelValue :> Real { unit = "%"; }
    value def FluidLevelValue :> Real { unit = "m"; }
    value def VolumeValue :> Real { unit = "m3"; }
    value def FlowRateValue :> Real { unit = "m3/s"; }
    value def PressureValue :> Real { unit = "Pa"; }
    value def IrradianceValue :> Real { unit = "W/m2"; }

    // ---- Items ----
    item def Sunlight;
    item def ElectricalEnergy;
    item def Fluid;

    // ---- Enumerations ----
    enum def PumpCommand { off; start; run; stop; }
    enum def PumpState { off; starting; running; stopping; faulted; }
    enum def ChargeDecision { direct; charge; both; none; }

    // ---- Ports ----
    port def SolarPort {
        in item sunlight : Sunlight;
        out item energy : ElectricalEnergy;
    }
    port def PowerPort {
        in item inEnergy : ElectricalEnergy;
        out item outEnergy : ElectricalEnergy;
    }
    port def FluidPort {
        in item inFluid : Fluid;
        out item outFluid : Fluid;
    }
    port def SignalPort {
        attribute value : Real;
    }

    // ---- Requirements ----
    requirement def AutonomousOperationRequirement {
        doc "The system shall operate autonomously without external grid power."
        subject system : SolarPumpingSystem;
        objective {
            system.gridConnected == false
        }
    }

    requirement def FluidTransferRequirement {
        doc "The system shall transfer fluid from the source reservoir to the destination tank."
        subject system : SolarPumpingSystem;
        objective {
            system.transferRate > 0
        }
    }

    requirement def BatteryProtectionRequirement {
        doc "The charge controller shall prevent the battery bank from overcharging."
        subject controller : ChargeController;
        objective {
            controller.batteryProtected == true
        }
    }

    requirement def PumpSafetyRequirement {
        doc "The pump shall not run when the battery is low, the source is empty, or the destination is full."
        subject controller : PumpController;
        objective {
            (controller.batteryCharge > controller.minBatteryLevel
             and controller.sourceLevel > controller.minSourceLevel
             and controller.destinationLevel < controller.maxDestinationLevel)
            implies controller.pumpActive == true
        }
    }

    requirement def NightOperationRequirement {
        doc "The system shall operate during periods without solar input by using stored battery energy."
        subject system : SolarPumpingSystem;
        objective {
            system.batteryBank.chargeLevel > 0
        }
    }

    // ---- Parts ----

    part def SolarPanelArray {
        attribute ratedPower : PowerValue = 300;
        attribute irradiance : IrradianceValue = 0;
        attribute efficiency : Real = 0.18;
        attribute generatedPower : PowerValue = 0;

        port solarIn : SolarPort;
        port powerOut : PowerPort;

        action def GeneratePower {
            in sunlight : Sunlight;
            out energy : ElectricalEnergy;
        }

        action generate : GeneratePower {
            bind sunlight = solarIn.sunlight;
            bind energy = powerOut.outEnergy;
        }

        state def PanelState {
            state Exposed {
                entry { generatedPower = ratedPower * efficiency * (irradiance / 1000); }
            }
            state Shaded {
                entry { generatedPower = 0; }
            }
            transition Exposed to Shaded when irradiance < 50;
            transition Shaded to Exposed when irradiance >= 50;
        }

        behavior : PanelState;
    }

    part def ChargeController {
        attribute maxBatteryVoltage : VoltageValue = 14.4;
        attribute floatVoltage : VoltageValue = 13.6;
        attribute batteryProtected : Boolean = true;
        attribute decision : ChargeDecision = ChargeDecision::none;
        attribute availablePower : PowerValue = 0;

        port powerIn : PowerPort;
        port powerToPump : PowerPort;
        port powerToBattery : PowerPort;

        action def RegulatePower {
            in incoming : ElectricalEnergy;
            out toPump : ElectricalEnergy;
            out toBattery : ElectricalEnergy;
        }

        action regulate : RegulatePower {
            bind incoming = powerIn.inEnergy;
            bind toPump = powerToPump.outEnergy;
            bind toBattery = powerToBattery.outEnergy;
        }

        state def ChargeControllerState {
            state Direct {
                entry { decision = ChargeDecision::direct; }
            }
            state Charging {
                entry { decision = ChargeDecision::charge; }
            }
            state Both {
                entry { decision = ChargeDecision::both; }
            }
            state Protection {
                entry { decision = ChargeDecision::none; batteryProtected = true; }
            }
            transition Direct to Both when availablePower > 0;
            transition Both to Charging when availablePower > 0;
            transition Charging to Protection when maxBatteryVoltage >= 14.4;
            transition Protection to Direct when maxBatteryVoltage < 13.6;
        }

        behavior : ChargeControllerState;
    }

    part def BatteryBank {
        attribute capacity : EnergyValue = 3600000;
        attribute chargeLevel : ChargeLevelValue = 100;
        attribute voltage : VoltageValue = 12;
        attribute lowThreshold : ChargeLevelValue = 20;
        attribute fullyCharged : Boolean = false;
        attribute depleted : Boolean = false;

        port powerIn : PowerPort;
        port powerOut : PowerPort;

        state def BatteryState {
            state Charging {
                entry { chargeLevel < 100; }
            }
            state Discharging {
                entry { chargeLevel > 0; }
            }
            state Full {
                entry { fullyCharged = true; }
            }
            state Low {
                entry { chargeLevel <= lowThreshold; }
            }
            transition Charging to Full when chargeLevel >= 100;
            transition Full to Discharging when chargeLevel < 100;
            transition Discharging to Low when chargeLevel <= lowThreshold;
            transition Low to Charging when chargeLevel > lowThreshold;
        }

        behavior : BatteryState;
    }

    part def PumpController {
        attribute batteryCharge : ChargeLevelValue = 100;
        attribute sourceLevel : FluidLevelValue = 1.0;
        attribute destinationLevel : FluidLevelValue = 0.5;
        attribute command : PumpCommand = PumpCommand::off;
        attribute safeToRun : Boolean = false;
        attribute pumpActive : Boolean = false;

        attribute minBatteryLevel : ChargeLevelValue = 20;
        attribute minSourceLevel : FluidLevelValue = 0.1;
        attribute maxDestinationLevel : FluidLevelValue = 1.9;

        port batteryMonitor : SignalPort;
        port sourceSensor : SignalPort;
        port destinationSensor : SignalPort;
        port pumpCommandOut : SignalPort;

        action def Evaluate {
            in battery : ChargeLevelValue;
            in source : FluidLevelValue;
            in destination : FluidLevelValue;
            out cmd : PumpCommand;
        }

        action evaluate : Evaluate {
            bind battery = batteryCharge;
            bind source = sourceLevel;
            bind destination = destinationLevel;
            bind cmd = command;
        }

        state def ControllerLogic {
            state Idle {
                entry { command = PumpCommand::off; pumpActive = false; }
            }
            state Monitoring {
                entry {
                    safeToRun = (batteryCharge > minBatteryLevel)
                        and (sourceLevel > minSourceLevel)
                        and (destinationLevel < maxDestinationLevel);
                }
            }
            state Commanding {
                entry {
                    if safeToRun { command = PumpCommand::start; pumpActive = true; }
                    else { command = PumpCommand::stop; pumpActive = false; }
                }
            }
            transition Idle to Monitoring;
            transition Monitoring to Commanding;
            transition Commanding to Monitoring;
        }

        behavior : ControllerLogic;
    }

    part def CentrifugalPump {
        attribute maxFlowRate : FlowRateValue = 0.001;
        attribute flowRate : FlowRateValue = 0;
        attribute dischargePressure : PressureValue = 200000;
        attribute state : PumpState = PumpState::off;
        attribute command : PumpCommand = PumpCommand::off;
        attribute powered : Boolean = false;

        port powerIn : PowerPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port commandIn : SignalPort;

        action def PumpFluid {
            in inFluid : Fluid;
            out outFluid : Fluid;
        }

        action pump : PumpFluid {
            bind inFluid = fluidIn.inFluid;
            bind outFluid = fluidOut.outFluid;
        }

        state def PumpStateMachine {
            state Off {
                entry { state = PumpState::off; flowRate = 0; }
            }
            state Starting {
                entry { state = PumpState::starting; flowRate = 0; }
            }
            state Running {
                entry { state = PumpState::running; flowRate = maxFlowRate; }
            }
            state Stopping {
                entry { state = PumpState::stopping; flowRate = 0; }
            }
            state Faulted {
                entry { state = PumpState::faulted; flowRate = 0; }
            }
            transition Off to Starting when command == PumpCommand::start and powered == true;
            transition Starting to Running when powered == true;
            transition Running to Stopping when command == PumpCommand::stop;
            transition Stopping to Off;
            transition Running to Faulted when powered == false;
            transition Faulted to Off when command == PumpCommand::off;
        }

        behavior : PumpStateMachine;
    }

    part def SourceReservoir {
        attribute capacity : VolumeValue = 5;
        attribute currentLevel : FluidLevelValue = 1.0;
        attribute currentVolume : VolumeValue = 1.0;
        attribute fluid : Fluid;

        port fluidOut : FluidPort;

        state def ReservoirState {
            state Full;
            state Partial;
            state Empty {
                entry { currentLevel = 0; }
            }
            transition Full to Partial when currentLevel < capacity;
            transition Partial to Empty when currentLevel <= 0;
            transition Empty to Partial when currentLevel > 0;
        }

        behavior : ReservoirState;
    }

    part def DestinationTank {
        attribute capacity : VolumeValue = 10;
        attribute currentLevel : FluidLevelValue = 0.5;
        attribute currentVolume : VolumeValue = 0.5;
        attribute fluid : Fluid;

        port fluidIn : FluidPort;

        state def TankState {
            state Empty;
            state Partial;
            state Full {
                entry { currentLevel = capacity; }
            }
            transition Empty to Partial when currentLevel > 0;
            transition Partial to Full when currentLevel >= capacity;
            transition Full to Partial when currentLevel < capacity;
        }

        behavior : TankState;
    }

    // ---- System ----
    part def SolarPumpingSystem {
        attribute gridConnected : Boolean = false;
        attribute transferRate : FlowRateValue = 0;

        part panelArray : SolarPanelArray;
        part chargeController : ChargeController;
        part batteryBank : BatteryBank;
        part pumpController : PumpController;
        part pump : CentrifugalPump;
        part source : SourceReservoir;
        part destination : DestinationTank;

        // Power connections
        connection panelToController connect panelArray.powerOut to chargeController.powerIn;
        connection controllerToPumpPower connect chargeController.powerToPump to pump.powerIn;
        connection controllerToBatteryPower connect chargeController.powerToBattery to batteryBank.powerIn;
        connection batteryToControllerPower connect batteryBank.powerOut to chargeController.powerIn;

        // Fluid connections
        connection sourceToPumpFluid connect source.fluidOut to pump.fluidIn;
        connection pumpToDestinationFluid connect pump.fluidOut to destination.fluidIn;

        // Signal connections
        connection batterySignal connect batteryBank.powerOut to pumpController.batteryMonitor;
        connection sourceSignal connect source.fluidOut to pumpController.sourceSensor;
        connection destinationSignal connect destination.fluidIn to pumpController.destinationSensor;
        connection pumpCommandSignal connect pumpController.pumpCommandOut to pump.commandIn;

        // Requirement satisfaction
        satisfy AutonomousOperationRequirement by system;
        satisfy FluidTransferRequirement by system;
        satisfy BatteryProtectionRequirement by chargeController;
        satisfy PumpSafetyRequirement by pumpController;
        satisfy NightOperationRequirement by system;
    }
}
