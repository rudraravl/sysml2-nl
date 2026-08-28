package PhotoswitchSystem {

    import ScalarValues::*;

    // ===== Units =====
    unit def lux;
    unit def volt;
    unit def watt;
    unit def ampere;

    // ===== Value Types =====
    value def LightLevel :> Real { unit lux; }
    value def Voltage :> Real { unit volt; }
    value def Power :> Real { unit watt; }
    value def Current :> Real { unit ampere; }

    // ===== Enumerations =====
    enum def RelayState { open; closed; }
    enum def CommandKind { open; close; }

    // ===== Item Definitions =====
    item def LightMeasurement {
        attribute level : LightLevel;
    }

    item def RelayCommand {
        attribute kind : CommandKind;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ===== Port Definitions =====
    port def LightOutPort {
        out measurement : LightMeasurement;
    }

    port def LightInPort {
        in measurement : LightMeasurement;
    }

    port def CommandOutPort {
        out command : RelayCommand;
    }

    port def CommandInPort {
        in command : RelayCommand;
    }

    port def PowerOutPort {
        out power : ElectricalPower;
    }

    port def PowerInPort {
        in power : ElectricalPower;
    }

    // ===== Photosensitive Sensor =====
    part def PhotosensitiveSensor {
        port lightOut : LightOutPort;
        attribute measuredLevel : LightLevel;
        attribute sensingRangeMax : LightLevel = 100000 [lux];
        attribute sensingRangeMin : LightLevel = 0 [lux];
        attribute accuracyPercent : Real = 5.0;
        attribute responseTimeMs : Real = 100.0;

        action def SenseLight {
            in ambient : LightLevel;
            out measurement : LightMeasurement;
        }

        perform sense : SenseLight;
    }

    // ===== Control Unit =====
    part def ControlUnit {
        port lightIn : LightInPort;
        port commandOut : CommandOutPort;

        attribute activationThreshold : LightLevel = 10 [lux];
        attribute deactivationThreshold : LightLevel = 50 [lux];
        attribute hysteresisBand : LightLevel = deactivationThreshold - activationThreshold;
        attribute evaluationPeriodMs : Real = 500.0;

        action def EvaluateLight {
            in measurement : LightMeasurement;
            in lowThreshold : LightLevel;
            in highThreshold : LightLevel;
            out command : RelayCommand;
        }

        action def IssueCommand {
            in kind : CommandKind;
            out command : RelayCommand;
        }

        state machine def ControllerBehavior {
            state LoadOff {
                entry then send RelayCommand{kind = CommandKind::open} via commandOut;
            }
            state LoadOn {
                entry then send RelayCommand{kind = CommandKind::close} via commandOut;
            }

            transition activate
                from LoadOff to LoadOn
                when lightIn.measurement.level < activationThreshold;

            transition deactivate
                from LoadOn to LoadOff
                when lightIn.measurement.level > deactivationThreshold;
        }

        perform ControllerBehavior;
    }

    // ===== Electromechanical Switch Relay =====
    part def Relay {
        port commandIn : CommandInPort;
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;

        attribute state : RelayState = RelayState::open;
        attribute maxCurrentRating : Current = 20 [ampere];
        attribute maxVoltageRating : Voltage = 250 [volt];
        attribute contactResistanceOhms : Real = 0.001;
        attribute switchingTimeMs : Real = 15.0;
        attribute mechanicalLifetimeCycles : Integer = 1000000;

        action def ActuateRelay {
            in command : RelayCommand;
            out relayState : RelayState;
        }

        state machine def RelayBehavior {
            state Open {
                do ActuateRelay;
            }
            state Closed {
                do ActuateRelay;
            }

            transition closeRelay
                from Open to Closed
                when commandIn.command.kind == CommandKind::close;

            transition openRelay
                from Closed to Open
                when commandIn.command.kind == CommandKind::open;
        }

        perform RelayBehavior;
    }

    // ===== Electrical Load =====
    part def Load {
        port powerIn : PowerInPort;
        attribute ratedPower : Power = 1000 [watt];
        attribute ratedVoltage : Voltage = 120 [volt];
        attribute isEnergized : Boolean = false;
        attribute loadType : String = "lighting";

        state machine def LoadBehavior {
            state Deenergized;
            state Energized;

            transition energize
                from Deenergized to Energized
                when powerIn.power.voltage > 0 [volt];

            transition deenergize
                from Energized to Deenergized
                when powerIn.power.voltage == 0 [volt];
        }

        perform LoadBehavior;
    }

    // ===== Power Source =====
    part def PowerSource {
        port powerOut : PowerOutPort;
        attribute supplyVoltage : Voltage = 120 [volt];
        attribute maxCurrent : Current = 20 [ampere];
        attribute frequencyHz : Real = 60.0;
    }

    // ===== System Assembly =====
    part def PhotoswitchSystem {
        part sensor : PhotosensitiveSensor;
        part controller : ControlUnit;
        part relay : Relay;
        part load : Load;
        part source : PowerSource;

        connect sensor.lightOut to controller.lightIn;
        connect controller.commandOut to relay.commandIn;
        connect source.powerOut to relay.powerIn;
        connect relay.powerOut to load.powerIn;
    }

    // ===== Requirements =====
    requirement def AutomaticOperation {
        doc /* The system shall automatically control the electrical load based on ambient light levels without human intervention. */;
    }

    requirement def DarkActivation {
        doc /* The system shall energize the load when ambient light falls below the activation threshold. */;
        attribute activationLevel : LightLevel = 10 [lux];
    }

    requirement def LightDeactivation {
        doc /* The system shall de-energize the load when ambient light rises above the deactivation threshold. */;
        attribute deactivationLevel : LightLevel = 50 [lux];
    }

    requirement def HysteresisStability {
        doc /* The system shall employ separate activation and deactivation thresholds to prevent rapid cycling under fluctuating light conditions. */;
        attribute minimumHysteresisBand : LightLevel = 40 [lux];
    }

    requirement def LoadCapacity {
        doc /* The system shall support electrical loads up to 1000W. */;
        attribute maxLoadPower : Power = 1000 [watt];
    }

    requirement def StandardVoltageOperation {
        doc /* The system shall operate at standard household voltage of 120V. */;
        attribute operatingVoltage : Voltage = 120 [volt];
    }

    requirement def RelayCurrentRating {
        doc /* The relay shall handle at least 20A of current to support a 1000W load at 120V. */;
        attribute minCurrentRating : Current = 20 [ampere];
    }

    requirement def SensorAccuracy {
        doc /* The photosensitive sensor shall measure ambient light with an accuracy of 5 percent or better. */;
        attribute maxErrorPercent : Real = 5.0;
    }

    // ===== Requirement Usages =====
    requirement req1 : AutomaticOperation;
    requirement req2 : DarkActivation;
    requirement req3 : LightDeactivation;
    requirement req4 : HysteresisStability;
    requirement req5 : LoadCapacity;
    requirement req6 : StandardVoltageOperation;
    requirement req7 : RelayCurrentRating;
    requirement req8 : SensorAccuracy;

    // ===== Satisfaction =====
    satisfaction req1 by PhotoswitchSystem;
    satisfaction req2 by ControlUnit;
    satisfaction req3 by ControlUnit;
    satisfaction req4 by ControlUnit;
    satisfaction req5 by Load;
    satisfaction req6 by PowerSource;
    satisfaction req7 by Relay;
    satisfaction req8 by PhotosensitiveSensor;
}
