package AutoclaveSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQTemperature::*;
    import ISQPressure::*;
    import ISQTime::*;

    // ---- Value types with units ----
    attribute def TemperatureValue :> Real { unit = '°C'; }
    attribute def PressureValue :> Real { unit = 'bar'; }
    attribute def DurationValue :> Real { unit = 'min'; }
    attribute def FlowRateValue :> Real { unit = 'L/min'; }
    attribute def PowerValue :> Real { unit = 'kW'; }

    // ---- Items ----
    item def Water;
    item def Steam;
    item def Air;
    item def MedicalInstrument;

    // ---- Port definitions ----
    port def SteamPort {
        out item steam : Steam;
        attribute flowRate : FlowRateValue;
    }
    port def WaterPort {
        in item water : Water;
        attribute flowRate : FlowRateValue;
    }
    port def AirPort {
        inout item air : Air;
        attribute flowRate : FlowRateValue;
    }
    port def InstrumentPort {
        inout item instruments : MedicalInstrument[*];
    }
    port def PressureSignalPort {
        out attribute measuredPressure : PressureValue;
    }
    port def TemperatureSignalPort {
        out attribute measuredTemperature : TemperatureValue;
    }
    port def ControlSignalPort {
        in attribute command : ControlCommand;
        out attribute status : ComponentStatus;
    }
    port def DoorStatusPort {
        out attribute locked : Boolean;
        out attribute sealed : Boolean;
    }
    port def SafetyVentPort {
        out item ventedSteam : Steam;
    }

    // ---- Enumerations ----
    enum def ControlCommand {
        options START, STOP, ABORT, VACUUM, INJECT_STEAM, HOLD, EXHAUST, DRY, UNLOCK, LOCK;
    }
    enum def ComponentStatus {
        options IDLE, RUNNING, FAULT, COMPLETE;
    }
    enum def CyclePhase {
        options IDLE, DOOR_LOCK, EVACUATION, STERILIZATION, HOLD, EXHAUST, DRYING, COMPLETE, ABORTED;
    }

    // ---- Requirements ----
    requirement def SterilizationRequirement {
        doc /* The system shall sterilize medical instruments using high-pressure saturated steam. */
        attribute targetTemperature : TemperatureValue = 134;
        attribute targetPressure : PressureValue = 3.0;
        attribute holdDuration : DurationValue = 3.0;
    }

    requirement def SafetyRequirement {
        doc /* The system shall prevent door opening while pressurized and vent excess pressure. */
        attribute maxSafePressure : PressureValue = 3.5;
    }

    requirement def EvacuationRequirement {
        doc /* The system shall evacuate air from the chamber before steam injection. */
        attribute targetVacuumPressure : PressureValue = 0.2;
        attribute maxEvacuationTime : DurationValue = 10.0;
    }

    requirement def DryingRequirement {
        doc /* The system shall dry instruments after sterilization using vacuum. */
        attribute dryingDuration : DurationValue = 15.0;
    }

    // ---- Parts ----

    part def SterilizationChamber {
        attribute volume : Real = 100; // liters
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute isPressurized : Boolean;

        port instrumentAccess : InstrumentPort;
        port steamInlet : SteamPort;
        port airOutlet : AirPort;
        port pressureMeasurement : PressureSignalPort;
        port temperatureMeasurement : TemperatureSignalPort;
        port safetyVent : SafetyVentPort;

        action def Pressurize {
            in steamInput : Steam;
        }
        action def Depressurize {
            out ventedAir : Air;
            out ventedSteam : Steam;
        }
    }

    part def SteamGenerator {
        attribute maxPower : PowerValue = 10.0;
        attribute status : ComponentStatus = ComponentStatus::IDLE;

        port waterInlet : WaterPort;
        port steamOutlet : SteamPort;
        port control : ControlSignalPort;

        action def GenerateSteam {
            in water : Water;
            out steam : Steam;
        }
    }

    part def VacuumPump {
        attribute maxFlowRate : FlowRateValue = 50.0;
        attribute status : ComponentStatus = ComponentStatus::IDLE;

        port pumpPort : AirPort;
        port control : ControlSignalPort;

        action def Evacuate {
            in airIn : Air;
            out airOut : Air;
        }
        action def Dry {
            in airIn : Air;
            out airOut : Air;
        }
    }

    part def PressureSensor {
        attribute accuracy : PressureValue = 0.05;
        port measurement : PressureSignalPort;
    }

    part def TemperatureSensor {
        attribute accuracy : TemperatureValue = 0.5;
        port measurement : TemperatureSignalPort;
    }

    part def DoorLockAssembly {
        attribute isLocked : Boolean = false;
        attribute isSealed : Boolean = false;
        attribute status : ComponentStatus = ComponentStatus::IDLE;

        port doorStatus : DoorStatusPort;
        port control : ControlSignalPort;

        action def LockDoor {
            out locked : Boolean;
            out sealed : Boolean;
        }
        action def UnlockDoor {
            out locked : Boolean;
        }
    }

    part def SafetyValve {
        attribute thresholdPressure : PressureValue = 3.5;
        attribute isVenting : Boolean = false;

        port chamberConnection : SafetyVentPort;

        state def ValveStates {
            entry; then Closed;
            state Closed;
            state Venting;
            transition from Closed to Venting when chamberConnection.ventedSteam.flowRate > 0;
            transition from Venting to Closed when chamberConnection.ventedSteam.flowRate == 0;
        }
    }

    part def ControlUnit {
        attribute currentPhase : CyclePhase = CyclePhase::IDLE;
        attribute targetTemperature : TemperatureValue = 134;
        attribute targetPressure : PressureValue = 3.0;
        attribute holdDuration : DurationValue = 3.0;
        attribute elapsedHoldTime : DurationValue = 0;
        attribute abortRequested : Boolean = false;

        port pressureInput : PressureSignalPort;
        port temperatureInput : TemperatureSignalPort;
        port steamGenControl : ControlSignalPort;
        port vacuumPumpControl : ControlSignalPort;
        port doorLockControl : ControlSignalPort;

        state def ControlStateMachine {
            entry; then Idle;
            state Idle;
            state DoorLocking;
            state Evacuating;
            state SteamInjection;
            state Sterilizing;
            state Exhausting;
            state Drying;
            state Complete;
            state Aborted;

            transition from Idle to DoorLocking when doorLockControl.command == ControlCommand::START;
            transition from DoorLocking to Evacuating when doorLockControl.status == ComponentStatus::COMPLETE;
            transition from Evacuating to SteamInjection when pressureInput.measuredPressure <= 0.2;
            transition from SteamInjection to Sterilizing when pressureInput.measuredPressure >= 3.0 and temperatureInput.measuredTemperature >= 134;
            transition from Sterilizing to Exhausting when elapsedHoldTime >= holdDuration;
            transition from Exhausting to Drying when pressureInput.measuredPressure <= 0.5;
            transition from Drying to Complete when vacuumPumpControl.status == ComponentStatus::COMPLETE;
            transition from Complete to Idle when doorLockControl.command == ControlCommand::STOP;
            transition from Idle to Aborted when doorLockControl.command == ControlCommand::ABORT;
            transition from DoorLocking to Aborted when abortRequested;
            transition from Evacuating to Aborted when abortRequested;
            transition from SteamInjection to Aborted when abortRequested;
            transition from Sterilizing to Aborted when abortRequested;
            transition from Exhausting to Aborted when abortRequested;
            transition from Drying to Aborted when abortRequested;
            transition from Aborted to Idle when doorLockControl.command == ControlCommand::STOP;
        }
    }

    // ---- System assembly ----
    part def AutoclaveSystem {
        satisfy SterilizationRequirement;
        satisfy SafetyRequirement;
        satisfy EvacuationRequirement;
        satisfy DryingRequirement;

        part chamber : SterilizationChamber;
        part steamGenerator : SteamGenerator;
        part vacuumPump : VacuumPump;
        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        part doorLock : DoorLockAssembly;
        part safetyValve : SafetyValve;
        part controlUnit : ControlUnit;

        connection : WaterPort connect steamGenerator.waterInlet to external;
        connection : SteamPort connect steamGenerator.steamOutlet to chamber.steamInlet;
        connection : AirPort connect chamber.airOutlet to vacuumPump.pumpPort;
        connection : PressureSignalPort connect chamber.pressureMeasurement to pressureSensor.measurement;
        connection : TemperatureSignalPort connect chamber.temperatureMeasurement to temperatureSensor.measurement;
        connection : PressureSignalPort connect pressureSensor.measurement to controlUnit.pressureInput;
        connection : TemperatureSignalPort connect temperatureSensor.measurement to controlUnit.temperatureInput;
        connection : ControlSignalPort connect controlUnit.steamGenControl to steamGenerator.control;
        connection : ControlSignalPort connect controlUnit.vacuumPumpControl to vacuumPump.control;
        connection : ControlSignalPort connect controlUnit.doorLockControl to doorLock.control;
        connection : SafetyVentPort connect chamber.safetyVent to safetyValve.chamberConnection;
        connection : DoorStatusPort connect doorLock.doorStatus to external;
        connection : InstrumentPort connect chamber.instrumentAccess to external;
    }
}
