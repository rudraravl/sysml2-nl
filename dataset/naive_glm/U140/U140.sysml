package AirIonizerSystem {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ===== Value Types =====
    value def Voltage :> Real { unit "V"; }
    value def LowVoltage :> Voltage;
    value def HighVoltage :> Voltage;
    value def Current :> Real { unit "A"; }
    value def Power :> Real { unit "W"; }
    value def FanSpeed :> Real { unit "rpm"; }
    value def AirFlowRate :> Real { unit "m^3/h"; }
    value def ParticulateDensity :> Real { unit "ug/m^3"; }
    value def IonConcentration :> Real { unit "ions/cm^3"; }
    value def OzoneConcentration :> Real { unit "ppm"; }
    value def Efficiency :> Real;
    value def DutyCycle :> Real { unit "%"; }

    // ===== Items =====
    item def Air;
    item def Particulate;
    item def Dust :> Particulate;
    item def Pollen :> Particulate;
    item def ChargedParticulate :> Particulate;
    item def NegativeIon;
    item def Ozone;
    item def PurifiedAir;
    item def ElectricPower;

    // ===== Enumerations =====
    enum OperatingMode { off; standby; low; medium; high; auto; }
    enum UserSetting { silent; comfort; boost; eco; }

    // ===== Port Definitions =====
    port def AirInPort { in item Air; }
    port def AirOutPort { out item PurifiedAir; }
    port def PowerInPort { in item ElectricPower; }
    port def PowerOutPort { out item ElectricPower; }
    port def HighVoltagePort { out item ElectricPower; }
    port def ControlSignalPort { out Real; }
    port def SensorDataPort {
        out particulateReading : ParticulateDensity;
        out ionReading : IonConcentration;
        out ozoneReading : OzoneConcentration;
    }

    // ===== Part Definitions =====

    part def PowerSupply {
        attribute outputVoltage : LowVoltage = 12;
        attribute outputCurrent : Current = 2.5;
        attribute maxOutputPower : Power = 30;
        port mainsIn : PowerInPort;
        port lowVoltageOut : PowerOutPort;
        action def supplyPower {
            in p : ElectricPower;
            out lv : ElectricPower;
        }
    }

    part def CirculationFan {
        attribute maxSpeed : FanSpeed = 1500;
        attribute currentSpeed : FanSpeed;
        attribute flowRate : AirFlowRate;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port powerIn : PowerInPort;
        port speedCommand : ControlSignalPort;
        action def circulate {
            in air : Air;
            in speedCmd : Real;
            out movedAir : Air;
        }
    }

    part def PreFilter {
        attribute filterType : String = "HEPA";
        attribute captureEfficiency : Efficiency = 0.99;
        attribute loadingLevel : Real = 0.0;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        action def filterAir {
            in dirtyAir : Air;
            out filteredAir : Air;
            out trapped : Dust;
        }
    }

    part def HighVoltageGenerator {
        attribute nominalOutput : HighVoltage = 7000;
        attribute intensity : DutyCycle;
        port powerIn : PowerInPort;
        port hvOut : HighVoltagePort;
        port intensityCommand : ControlSignalPort;
        action def generateHV {
            in lv : ElectricPower;
            in intensityCmd : Real;
            out hv : ElectricPower;
        }
    }

    part def IonizationNeedle {
        attribute needleId : Integer;
        attribute emissionRate : IonConcentration;
        port hvIn : HighVoltagePort;
        action def emitIons {
            in hv : ElectricPower;
            out ions : NegativeIon;
        }
    }

    part def IonizationChamber {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        port hvIn : HighVoltagePort;
        part needles : IonizationNeedle[6] {
            attribute needleId = indexof(this) + 1;
        }
        action def ionize {
            in air : Air;
            in ions : NegativeIon;
            out chargedAir : Air;
            out chargedParticles : ChargedParticulate;
        }
    }

    part def OzoneCatalyst {
        attribute reductionEfficiency : Efficiency = 0.95;
        port airIn : AirInPort;
        port airOut : AirOutPort;
        action def neutralizeOzone {
            in airWithOzone : Air;
            out cleanAir : PurifiedAir;
            out neutralizedOzone : Ozone;
        }
    }

    part def AirQualitySensor {
        attribute measuredParticulates : ParticulateDensity;
        attribute measuredIons : IonConcentration;
        attribute measuredOzone : OzoneConcentration;
        attribute samplingInterval : Time = 1 [s];
        port dataOut : SensorDataPort;
        action def sample {
            out particulates : ParticulateDensity;
            out ions : IonConcentration;
            out ozone : OzoneConcentration;
        }
    }

    part def ControlModule {
        attribute currentMode : OperatingMode = OperatingMode::off;
        attribute userSetting : UserSetting = UserSetting::comfort;
        attribute targetParticulateLevel : ParticulateDensity = 10 [ug/m^3];
        attribute maxSafeOzone : OzoneConcentration = 0.05 [ppm];
        port sensorIn : SensorDataPort;
        port fanCommand : ControlSignalPort;
        port hvCommand : ControlSignalPort;
        port powerEnable : PowerOutPort;

        state machine def ControlBehavior {
            entry; then Off;

            state Off {
                entry { currentMode = OperatingMode::off; }
            }
            transition Off to Standby when powerOn;

            state Standby {
                entry { currentMode = OperatingMode::standby; }
            }
            transition Standby to Active
                when modeSelected && (currentMode != OperatingMode::standby);

            state Active {
                entry { currentMode = selectedMode; }
                choice chooseLevel {
                    if currentMode == OperatingMode::low then LowMode
                    else if currentMode == OperatingMode::medium then MediumMode
                    else if currentMode == OperatingMode::high then HighMode
                    else AutoMode;
                }
            }

            state LowMode {
                entry { fanCommand = 400; hvCommand = 30; }
            }
            state MediumMode {
                entry { fanCommand = 800; hvCommand = 60; }
            }
            state HighMode {
                entry { fanCommand = 1500; hvCommand = 100; }
            }

            state AutoMode {
                entry { currentMode = OperatingMode::auto; }
                do { adjustPerformance(); }
            }

            transition Active to Standby when standbyRequested;
            transition any Off when powerOff;

            action def adjustPerformance {
                in particulates : ParticulateDensity;
                in ozone : OzoneConcentration;
                out newFanCmd : Real;
                out newHVCmd : Real;
                if particulates > targetParticulateLevel {
                    newFanCmd = 1500;
                    newHVCmd = 100;
                } else {
                    newFanCmd = 400;
                    newHVCmd = 30;
                }
                if ozone > maxSafeOzone {
                    newHVCmd = newHVCmd * 0.5;
                }
            }
        }
    }

    // ===== Top-Level System =====
    part def AirIonizer {
        attribute manufacturer : String = "CleanAir Inc.";
        attribute model : String = "IonPure-7000";
        attribute serialNumber : String;

        port roomAirIn : AirInPort;
        port purifiedAirOut : AirOutPort;
        port mainsIn : PowerInPort;

        part powerSupply : PowerSupply;
        part fan : CirculationFan;
        part preFilter : PreFilter;
        part ionizationChamber : IonizationChamber;
        part ozoneCatalyst : OzoneCatalyst;
        part controlModule : ControlModule;
        part airQualitySensor : AirQualitySensor;

        connection mainsIn to powerSupply.mainsIn;
        connection powerSupply.lowVoltageOut to fan.powerIn;
        connection powerSupply.lowVoltageOut to controlModule.powerEnable;
        connection powerSupply.lowVoltageOut to ionizationChamber.hvIn;

        connection roomAirIn to fan.airIn;
        connection fan.airOut to preFilter.airIn;
        connection preFilter.airOut to ionizationChamber.airIn;
        connection ionizationChamber.airOut to ozoneCatalyst.airIn;
        connection ozoneCatalyst.airOut to purifiedAirOut;

        connection airQualitySensor.dataOut to controlModule.sensorIn;
        connection controlModule.fanCommand to fan.speedCommand;
        connection controlModule.hvCommand to ionizationChamber.hvIn;

        flow of Air from roomAirIn through fan.airIn to fan.airOut;
        flow of Air from fan.airOut through preFilter.airIn to preFilter.airOut;
        flow of Air from preFilter.airOut through ionizationChamber.airIn to ionizationChamber.airOut;
        flow of PurifiedAir from ionizationChamber.airOut through ozoneCatalyst.airIn to ozoneCatalyst.airOut;
        flow of PurifiedAir from ozoneCatalyst.airOut to purifiedAirOut;
    }

    // ===== Requirements =====
    requirement def PurificationRequirement {
        subject : AirIonizer;
        objective {
            doc "The system shall remove airborne particulates from room air by charging them with negative ions."
        }
        requirement {
            subject::preFilter.captureEfficiency >= 0.99;
        }
        requirement {
            subject::ionizationChamber.needles->size() == 6;
        }
    }

    requirement def HighVoltageRequirement {
        subject : HighVoltageGenerator;
        objective {
            doc "The high-voltage generator shall produce 7,000V nominal output."
        }
        requirement {
            subject::nominalOutput == 7000 [V];
        }
    }

    requirement def OzoneSafetyRequirement {
        subject : AirIonizer;
        objective {
            doc "The system shall neutralize ozone byproducts to maintain safe indoor ozone levels."
        }
        requirement {
            subject::ozoneCatalyst.reductionEfficiency >= 0.95;
        }
        requirement {
            subject::controlModule.maxSafeOzone <= 0.05 [ppm];
        }
    }

    requirement def OperatingModeRequirement {
        subject : ControlModule;
        objective {
            doc "The control module shall support off, standby, low, medium, high, and auto modes."
        }
        requirement {
            subject::currentMode in OperatingMode;
        }
    }

    requirement def AutoModeRequirement {
        subject : ControlModule;
        objective {
            doc "In auto mode, the system shall dynamically adjust fan speed and ion intensity based on sensor readings."
        }
        requirement {
            subject::currentMode == OperatingMode::auto implies
                subject::fanCommand.value > 0 && subject::hvCommand.value > 0;
        }
    }

    requirement def SensorMonitoringRequirement {
        subject : AirQualitySensor;
        objective {
            doc "The air quality sensor shall continuously measure particulate and ion levels."
        }
        requirement {
            subject::samplingInterval <= 2 [s];
        }
    }

    requirement def AirflowRequirement {
        subject : AirIonizer;
        objective {
            doc "The system shall draw ambient room air through the pre-filter, ionization chamber, and ozone catalyst, returning purified air to the room."
        }
    }

    satisfaction PurificationRequirement by AirIonizer;
    satisfaction HighVoltageRequirement by AirIonizer::ionizationChamber;
    satisfaction OzoneSafetyRequirement by AirIonizer;
    satisfaction OperatingModeRequirement by AirIonizer::controlModule;
    satisfaction AutoModeRequirement by AirIonizer::controlModule;
    satisfaction SensorMonitoringRequirement by AirIonizer::airQualitySensor;
    satisfaction AirflowRequirement by AirIonizer;
}
