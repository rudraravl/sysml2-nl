package AutoclaveSterilizationSystem {
    import ISQ::*;
    import ISQBase::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def Temperature :> Real { unit = "K"; }
    value def Pressure :> Real { unit = "kPa"; }
    value def Duration :> Real { unit = "min"; }
    value def BondStrength :> Real { unit = "N/m"; }
    value def MassFlowRate :> Real { unit = "kg/min"; }

    // ---- Enumeration types ----
    enum def CycleCommand { start; abort; }
    enum def CycleStatus { idle; running; complete; faulted; }
    enum def IndicatorColor { beige; green; }
    enum def IndicatorStatus { unexposed; exposed; changed; }

    // ---- Item types ----
    item def Water;
    item def SaturatedSteam {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }
    item def SterilizationPackage;
    item def CycleCompleteSignal;

    // ---- Requirements ----
    requirement def SterilizationRequirement {
        subject autoclave : AutoclaveMachine;
        objective {
            doc /* The autoclave shall sterilize packages using saturated steam at 394.15 K and 205 kPa for at least 15 minutes. */
        }
        assume autoclave.chamber.isSealed
    }

    requirement def TapeAdhesionRequirement {
        subject tape : AutoclaveTape;
        attribute maxTemp : Temperature = 423.15 [K]; // 150°C
        objective {
            doc /* The adhesive backing shall maintain bond strength up to 150°C. */
        }
        require tape.adhesive.bondStrength >= 5.0 [N/m]
    }

    requirement def IndicatorColorChangeRequirement {
        subject indicator : ChemicalIndicator;
        attribute targetTemp : Temperature = 394.15 [K];
        attribute targetPressure : Pressure = 205 [kPa];
        attribute minExposure : Duration = 15 [min];
        objective {
            doc /* The indicator shall change from beige to green after exposure to target conditions for the minimum duration. */
        }
        require indicator.initialColor == IndicatorColor::beige
        require indicator.finalColor == IndicatorColor::green
    }

    requirement def OperatorConfirmationRequirement {
        subject tape : AutoclaveTape;
        objective {
            doc /* The tape shall provide a visible green confirmation to the operator after a successful cycle. */
        }
        require tape.indicator.status == IndicatorStatus::changed
    }

    // ---- Autoclave Tape ----
    part def AdhesiveBacking {
        attribute bondStrength : BondStrength = 8.0 [N/m];
        attribute maxOperatingTemp : Temperature = 423.15 [K];
        attribute isBonded : Boolean = false;
    }

    part def ChemicalIndicator {
        attribute initialColor : IndicatorColor = IndicatorColor::beige;
        attribute currentColor : IndicatorColor = IndicatorColor::beige;
        attribute finalColor : IndicatorColor = IndicatorColor::green;
        attribute status : IndicatorStatus = IndicatorStatus::unexposed;
        attribute accumulatedExposure : Duration = 0 [min];

        port in steamIn : SaturatedSteam;
        port out colorOut : IndicatorColor;

        state machine IndicatorBehavior {
            entry; then Unexposed;

            state Unexposed {
                entry { currentColor = IndicatorColor::beige; status = IndicatorStatus::unexposed; }
                transition first Unexposed to Exposed
                    when steamIn.temperature >= 394.15 [K] and steamIn.pressure >= 205 [kPa];
            }

            state Exposed {
                entry { status = IndicatorStatus::exposed; }
                do {
                    if (steamIn.temperature >= 394.15 [K] and steamIn.pressure >= 205 [kPa]) {
                        accumulatedExposure = accumulatedExposure + 1.0 [min];
                    }
                }
                transition Exposed to Changed
                    when accumulatedExposure >= 15 [min];
            }

            state Changed {
                entry {
                    currentColor = IndicatorColor::green;
                    status = IndicatorStatus::changed;
                    colorOut = currentColor;
                }
            }
        }
    }

    part def AutoclaveTape {
        part adhesive : AdhesiveBacking;
        part indicator : ChemicalIndicator;

        port in tapeSteamIn : SaturatedSteam;
        port out tapeColorOut : IndicatorColor;

        connection tapeSteamConn connect tapeSteamIn to indicator.steamIn;
        connection tapeColorConn connect indicator.colorOut to tapeColorOut;

        satisfy TapeAdhesionRequirement by adhesive;
        satisfy OperatorConfirmationRequirement by self;
    }

    // ---- Autoclave Machine ----
    part def SteamGenerator {
        attribute targetTemp : Temperature = 394.15 [K];
        attribute targetPressure : Pressure = 205 [kPa];
        attribute active : Boolean = false;

        port in waterIn : Water;
        port in activate : Boolean;
        port out steamOut : SaturatedSteam;

        action def GenerateSteam {
            in water : Water;
            out steam : SaturatedSteam;
        }

        perform action generate : GenerateSteam {
            when activate == true and active == true;
            then {
                steam.temperature = 394.15 [K];
                steam.pressure = 205 [kPa];
                steamOut = steam;
            }
        }
    }

    part def Chamber {
        attribute isSealed : Boolean = false;
        attribute internalTemp : Temperature = 293.15 [K];
        attribute internalPressure : Pressure = 101.325 [kPa];

        port in steamIn : SaturatedSteam;
        port in sealCmd : Boolean;
        port out steamToPackages : SaturatedSteam;

        part packages : SterilizationPackage[0..*];

        connection distributeSteam connect steamIn to steamToPackages;
    }

    part def ControlSystem {
        attribute cycleStatus : CycleStatus = CycleStatus::idle;
        attribute cycleDuration : Duration = 0 [min];
        attribute requiredDuration : Duration = 15 [min];

        port in command : CycleCommand;
        port in chamberSealed : Boolean;
        port out generatorActivate : Boolean;
        port out chamberSealCmd : Boolean;
        port out cycleComplete : CycleCompleteSignal;

        state machine ControlBehavior {
            entry; then Idle;

            state Idle {
                entry { cycleStatus = CycleStatus::idle; }
                transition first Idle to Starting
                    when command == CycleCommand::start;
            }

            state Starting {
                entry {
                    chamberSealCmd = true;
                }
                transition Starting to Running
                    when chamberSealed == true;
            }

            state Running {
                entry {
                    generatorActivate = true;
                    cycleStatus = CycleStatus::running;
                }
                do {
                    cycleDuration = cycleDuration + 1.0 [min];
                }
                transition Running to Complete
                    when cycleDuration >= requiredDuration;
                transition Running to Faulted
                    when command == CycleCommand::abort;
            }

            state Complete {
                entry {
                    generatorActivate = false;
                    cycleStatus = CycleStatus::complete;
                    cycleComplete = CycleCompleteSignal();
                }
            }

            state Faulted {
                entry {
                    generatorActivate = false;
                    cycleStatus = CycleStatus::faulted;
                }
            }
        }
    }

    part def AutoclaveMachine {
        part generator : SteamGenerator;
        part chamber : Chamber;
        part controller : ControlSystem;

        port in startCmd : CycleCommand;
        port out doneSignal : CycleCompleteSignal;

        connection cmdConn connect startCmd to controller.command;
        connection sealCmdConn connect controller.chamberSealCmd to chamber.sealCmd;
        connection sealedFbConn connect chamber.isSealed to controller.chamberSealed;
        connection activateConn connect controller.generatorActivate to generator.activate;
        connection waterConn connect generator.waterIn to generator.waterIn;
        connection steamToChamber connect generator.steamOut to chamber.steamIn;

        satisfy SterilizationRequirement by self;
    }

    // ---- Top-level system ----
    part def SterilizationSystem {
        part machine : AutoclaveMachine;
        part tape : AutoclaveTape;

        connection steamToTape connect machine.chamber.steamToPackages to tape.tapeSteamIn;
        connection colorFeedback connect tape.tapeColorOut to tape.tapeColorOut;

        satisfy IndicatorColorChangeRequirement by tape.indicator;
    }

    part sterilizationSystem : SterilizationSystem;
}
