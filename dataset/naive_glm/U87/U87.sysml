package miraDrySystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceAndTime::*;
    import ISQThermodynamics::*;
    import ISQElectromagnetism::*;
    import ISQMechanics::*;

    // ===== Value Types =====
    value def PowerValue :> Real { unit "W"; }
    value def TemperatureValue :> Real { unit "degC"; }
    value def EnergyValue :> Real { unit "J"; }
    value def DurationValue :> Real { unit "s"; }
    value def PressureValue :> Real { unit "Pa"; }
    value def FlowRateValue :> Real { unit "mL/s"; }
    value def VoltageValue :> Real { unit "V"; }
    value def FrequencyValue :> Real { unit "MHz"; }
    value def DepthValue :> Real { unit "mm"; }
    value def PercentValue :> Real { unit "%"; }

    // ===== Item Types =====
    item def MicrowaveEnergy {
        attribute power : PowerValue;
        attribute frequency : FrequencyValue;
        attribute duration : DurationValue;
    }

    item def CoolantFluid {
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
    }

    item def SkinTissue {
        attribute surfaceTemp : TemperatureValue;
        attribute dermalTemp : TemperatureValue;
        attribute glandDepth : DepthValue;
    }

    item def SweatGland {
        attribute viability : PercentValue;
    }

    item def ControlSignal {
        attribute command : String;
        attribute timestamp : DurationValue;
    }

    item def SensorReading {
        attribute value : Real;
        attribute valid : Boolean;
    }

    // ===== Port Definitions =====
    port def MicrowavePort {
        out item energy : MicrowaveEnergy;
    }

    port def CoolantPort {
        in item supply : CoolantFluid;
        out item return : CoolantFluid;
    }

    port def VacuumPort {
        out item vacuumPressure : PressureValue;
    }

    port def ControlPort {
        in item command : ControlSignal;
        out item feedback : ControlSignal;
    }

    port def SensorPort {
        out item reading : SensorReading;
    }

    port def PowerPort {
        out item voltage : VoltageValue;
    }

    // ===== Requirements =====
    requirement def SafetyRequirement {
        doc "The system shall prevent skin surface temperatures from exceeding safe limits.";
        attribute maxSafeSkinTemp : TemperatureValue = 4.0;
        subject system : miraDrySystem;
        objective {
            system.handpiece.skinTempSensor.reading.value <= maxSafeSkinTemp
        }
    }

    requirement def EnergyDeliveryRequirement {
        doc "The system shall deliver controlled microwave energy to the sweat gland depth.";
        attribute targetDepth : DepthValue = 3.0;
        attribute targetEnergy : EnergyValue = 50.0;
        subject system : miraDrySystem;
        objective {
            system.handpiece.antenna.emittedEnergy.power > 0
        }
    }

    requirement def CoolingRequirement {
        doc "The system shall cool the skin surface during energy delivery.";
        attribute coolantTemp : TemperatureValue = -10.0;
        subject system : miraDrySystem;
        objective {
            system.console.reservoir.coolant.temperature <= coolantTemp
        }
    }

    requirement def VacuumRequirement {
        doc "The system shall stabilize tissue via vacuum before energy delivery.";
        attribute minVacuum : PressureValue = 30000.0;
        subject system : miraDrySystem;
        objective {
            system.handpiece.vacuumChamber.pressure >= minVacuum
        }
    }

    requirement def SterilityRequirement {
        doc "The BioTip shall be single-use and sterile.";
        subject biotip : BioTipApplicator;
        objective {
            biotip.isSterile == true and biotip.isUsed == false
        }
    }

    // ===== Part Definitions =====
    part def PowerSupply {
        attribute inputVoltage : VoltageValue = 120;
        attribute outputPower : PowerValue;
        port powerOut : PowerPort;
        perform action generateMicrowaveEnergy {
            out generated : MicrowaveEnergy;
        }
    }

    part def CoolantReservoir {
        attribute capacity : Real = 500;
        attribute coolant : CoolantFluid;
        port coolantOut : CoolantPort;
    }

    part def CoolantPump {
        attribute flowRate : FlowRateValue;
        port coolantIn : CoolantPort;
        port coolantOut : CoolantPort;
        perform action circulateCoolant {
            in coolantIn : CoolantFluid;
            out coolantOut : CoolantFluid;
        }
    }

    part def UserInterface {
        attribute displayActive : Boolean;
        attribute treatmentParameters : String;
        perform action displayStatus {
            in status : String;
        }
        perform action acceptOperatorInput {
            out command : ControlSignal;
        }
    }

    part def ControlProcessor {
        attribute treatmentActive : Boolean;
        attribute energyDose : EnergyValue;
        attribute cycleCount : Integer;
        port controlIn : ControlPort;
        port controlOut : ControlPort;
        port sensorIn : SensorPort;
        exhibit state treatmentStateMachine {
            entry; then initialization;
            state initialization {
                entry { self.runSelfTest(); }
                do { self.verifySystemIntegrity(); }
                transition to ready
                    when { self.selfTestPassed == true }
                    satisfy SafetyRequirement;
            }
            state ready {
                entry { self.ui.displayStatus("Ready"); }
                accept OperatorStart
                    then activeTreatment;
            }
            state activeTreatment {
                entry { self.startVacuum(); self.startCooling(); }
                do { self.deliverEnergy(); }
                transition to cooling
                    when { self.energyCycleComplete == true };
                transition to fault
                    when { self.sensorIn.reading.value > self.maxSafeSkinTemp };
            }
            state cooling {
                entry { self.stopEnergy(); }
                do { self.maintainCooling(); }
                transition to ready
                    when { self.cooldownComplete == true };
            }
            state fault {
                entry { self.emergencyShutdown(); }
                do { self.alertOperator(); }
            }
        }
        perform action runSelfTest;
        perform action verifySystemIntegrity;
        perform action startVacuum;
        perform action startCooling;
        perform action deliverEnergy;
        perform action stopEnergy;
        perform action maintainCooling;
        perform action emergencyShutdown;
        perform action alertOperator;
        attribute selfTestPassed : Boolean;
        attribute energyCycleComplete : Boolean;
        attribute cooldownComplete : Boolean;
        attribute maxSafeSkinTemp : TemperatureValue = 4.0;
        ref ui : UserInterface;
    }

    part def ConsoleUnit {
        attribute serialNumber : String;
        attribute firmwareVersion : String;
        part powerSupply : PowerSupply;
        part reservoir : CoolantReservoir;
        part pump : CoolantPump;
        part processor : ControlProcessor;
        part ui : UserInterface;
        port consoleControlPort : ControlPort;
        port consoleCoolantPort : CoolantPort;
        port consolePowerPort : PowerPort;
        connection powerSupplyToProcessor connect powerSupply.powerOut to processor.controlIn;
        connection reservoirToPump connect reservoir.coolantOut to pump.coolantIn;
        connection pumpToConsolePort connect pump.coolantOut to consoleCoolantPort;
        connection uiToProcessor connect ui.acceptOperatorInput.command to processor.controlIn.command;
        satisfy SafetyRequirement;
        satisfy EnergyDeliveryRequirement;
        satisfy CoolingRequirement;
    }

    part def MicrowaveAntenna {
        attribute frequency : FrequencyValue = 5800;
        attribute emittedEnergy : MicrowaveEnergy;
        port antennaPort : MicrowavePort;
        perform action emitEnergy {
            in control : ControlSignal;
            out energy : MicrowaveEnergy;
        }
    }

    part def CoolingPlate {
        attribute plateTemp : TemperatureValue;
        port coolantInterface : CoolantPort;
        perform action transferCooling {
            in coolant : CoolantFluid;
            out surfaceCooling : CoolantFluid;
        }
    }

    part def VacuumChamber {
        attribute pressure : PressureValue;
        attribute vacuumActive : Boolean;
        port vacuumPort : VacuumPort;
        perform action applyVacuum {
            in command : ControlSignal;
            out pressure : PressureValue;
        }
        perform action releaseVacuum;
    }

    part def SkinTempSensor {
        attribute reading : SensorReading;
        port sensorOut : SensorPort;
        perform action measureTemperature {
            out reading : SensorReading;
        }
    }

    part def ContactSensor {
        attribute contactDetected : Boolean;
        port sensorOut : SensorPort;
        perform action detectContact {
            out reading : SensorReading;
        }
    }

    part def HandpieceAssembly {
        attribute handpieceId : String;
        part antenna : MicrowaveAntenna;
        part coolingPlate : CoolingPlate;
        part vacuumChamber : VacuumChamber;
        part skinTempSensor : SkinTempSensor;
        part contactSensor : ContactSensor;
        port handpieceControlPort : ControlPort;
        port handpieceCoolantPort : CoolantPort;
        port handpiecePowerPort : PowerPort;
        port handpieceVacuumPort : VacuumPort;
        port handpieceSensorPort : SensorPort;
        port handpieceMicrowavePort : MicrowavePort;
        connection controlToAntenna connect handpieceControlPort.command to antenna.antennaPort;
        connection controlToVacuum connect handpieceControlPort.command to vacuumChamber.vacuumPort;
        connection coolantToPlate connect handpieceCoolantPort to coolingPlate.coolantInterface;
        connection sensorToControl connect skinTempSensor.sensorOut to handpieceSensorPort;
        connection contactToControl connect contactSensor.sensorOut to handpieceSensorPort;
        satisfy VacuumRequirement;
    }

    part def CeramicWindow {
        attribute microwaveTransparency : PercentValue = 95;
        attribute surfaceTemp : TemperatureValue;
        perform action transmitMicrowave {
            in energy : MicrowaveEnergy;
            out transmitted : MicrowaveEnergy;
        }
        perform action transferCoolingToSkin {
            in cooling : CoolantFluid;
            out skinCooling : CoolantFluid;
        }
    }

    part def BioTipApplicator {
        attribute lotNumber : String;
        attribute isSterile : Boolean = true;
        attribute isUsed : Boolean = false;
        attribute maxUses : Integer = 1;
        part ceramicWindow : CeramicWindow;
        port biotipMicrowavePort : MicrowavePort;
        port biotipCoolantPort : CoolantPort;
        connection microwaveThroughWindow connect biotipMicrowavePort to ceramicWindow.transmitMicrowave;
        satisfy SterilityRequirement;
    }

    // ===== Top-Level System =====
    part def miraDrySystem {
        attribute systemId : String;
        attribute modelVersion : String = "miraDry-G2";
        part console : ConsoleUnit;
        part handpiece : HandpieceAssembly;
        part biotip : BioTipApplicator;
        connection consoleToHandpieceControl connect console.consoleControlPort to handpiece.handpieceControlPort;
        connection consoleToHandpieceCoolant connect console.consoleCoolantPort to handpiece.handpieceCoolantPort;
        connection consoleToHandpiecePower connect console.consolePowerPort to handpiece.handpiecePowerPort;
        connection handpieceToBiotipMicrowave connect handpiece.handpieceMicrowavePort to biotip.biotipMicrowavePort;
        connection handpieceToBiotipCoolant connect handpiece.handpieceCoolantPort to biotip.biotipCoolantPort;
        connection handpieceSensorFeedback connect handpiece.handpieceSensorPort to console.processor.sensorIn;
        satisfy SafetyRequirement;
        satisfy EnergyDeliveryRequirement;
        satisfy CoolingRequirement;
        satisfy VacuumRequirement;
        satisfy SterilityRequirement;
    }

    // ===== Treatment Action Sequence =====
    action def TreatmentProcedure {
        in system : miraDrySystem;
        action attachBioTip {
            out biotip : BioTipApplicator;
        }
        action placeHandpiece {
            in biotip : BioTipApplicator;
            out contactEstablished : Boolean;
        }
        action activateVacuum {
            in contactEstablished : Boolean;
            out vacuumStabilized : Boolean;
        }
        action activateCooling {
            out coolingActive : Boolean;
        }
        action verifySafetyConditions {
            in vacuumStabilized : Boolean;
            in coolingActive : Boolean;
            out safeToProceed : Boolean;
        }
        action deliverMicrowaveEnergy {
            in safeToProceed : Boolean;
            out energyDelivered : Boolean;
        }
        action monitorSkinTemperature {
            in energyDelivered : Boolean;
            out temperatureSafe : Boolean;
        }
        action releaseVacuum {
            in temperatureSafe : Boolean;
            out vacuumReleased : Boolean;
        }
        action moveToNextArea {
            in vacuumReleased : Boolean;
            out areaComplete : Boolean;
        }
        flow attachBioTip.biotip to placeHandpiece.biotip;
        flow placeHandpiece.contactEstablished to activateVacuum.contactEstablished;
        flow activateVacuum.vacuumStabilized to verifySafetyConditions.vacuumStabilized;
        flow activateCooling.coolingActive to verifySafetyConditions.coolingActive;
        flow verifySafetyConditions.safeToProceed to deliverMicrowaveEnergy.safeToProceed;
        flow deliverMicrowaveEnergy.energyDelivered to monitorSkinTemperature.energyDelivered;
        flow monitorSkinTemperature.temperatureSafe to releaseVacuum.temperatureSafe;
        flow releaseVacuum.vacuumReleased to moveToNextArea.vacuumReleased;
        then if areaComplete then done else repeat;
    }

    action def EmergencyShutdownProcedure {
        in system : miraDrySystem;
        action stopEnergyDelivery;
        action activateMaxCooling;
        action releaseVacuumImmediately;
        action alertOperator;
        action logIncident;
        first stopEnergyDelivery then activateMaxCooling;
        then releaseVacuumImmediately;
        then alertOperator;
        then logIncident;
    }
}
