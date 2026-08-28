package AutoclaveSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    package Definitions {
        item def Water;
        item def Steam;
        item def Air;

        attribute def PressureValue :> ScalarValues::Real;
        attribute def TemperatureValue :> ScalarValues::Real;
        attribute def DurationValue :> ScalarValues::Real;

        attribute def StartCycleSignal;
        attribute def AbortCycleSignal;
        attribute def DoorLockedSignal;
        attribute def DoorUnlockedSignal;
        attribute def EvacuationCompleteSignal;
        attribute def SterilizationConditionsReachedSignal;
        attribute def ExhaustCompleteSignal;
        attribute def DryingCompleteSignal;

        attribute def CommandLockDoor;
        attribute def CommandUnlockDoor;
        attribute def CommandEvacuate;
        attribute def CommandInjectSteam;
        attribute def CommandExhaust;
        attribute def CommandDry;

        port def FluidPort;
        port def SteamPort :> FluidPort {
            in item steam : Steam;
        }
        port def WaterPort :> FluidPort {
            in item water : Water;
        }
        port def AirPort :> FluidPort {
            in item air : Air;
            out item steam : Steam;
        }
        port def ExhaustPort :> FluidPort {
            out item steam : Steam;
        }
        port def ControlPort {
            in item command;
            out item status;
        }
        port def PressureSignalPort {
            out attribute pressure : PressureValue;
        }
        port def TemperatureSignalPort {
            out attribute temperature : TemperatureValue;
        }
        port def DoorLockControlPort {
            in item command;
            out item status;
        }

        connection def SteamFlow {
            end : SteamPort[1];
            end : SteamPort[1];
        }
        connection def WaterFlow {
            end : WaterPort[1];
            end : WaterPort[1];
        }
        connection def AirFlow {
            end : AirPort[1];
            end : AirPort[1];
        }
        connection def ControlSignalConnection {
            end : ControlPort[1];
            end : ControlPort[1];
        }
        connection def PressureSignalConnection {
            end : PressureSignalPort[1];
            end : PressureSignalPort[1];
        }
        connection def TemperatureSignalConnection {
            end : TemperatureSignalPort[1];
            end : TemperatureSignalPort[1];
        }
        connection def DoorLockControlConnection {
            end : DoorLockControlPort[1];
            end : DoorLockControlPort[1];
        }

        part def SterilizationChamber {
            attribute pressure :> PressureValue;
            attribute temperature :> TemperatureValue;
            attribute maxSafePressure :> PressureValue;
            attribute volume :> ScalarValues::Real;
            port steamIn : SteamPort;
            port airPort : AirPort;
            port exhaustPort : ExhaustPort;
            port pressureRelief : SteamPort;
            port pressureTap : PressureSignalPort;
            port temperatureTap : TemperatureSignalPort;
        }

        part def SteamGenerator {
            attribute dutyCycle : ScalarValues::Real;
            port waterIn : WaterPort;
            port steamOut : SteamPort;
            port commandPort : ControlPort;
            perform action generateSteam : GenerateSteam;
        }

        part def VacuumPump {
            attribute flowRate : ScalarValues::Real;
            port airPort : AirPort;
            port commandPort : ControlPort;
            perform action evacuate : Evacuate;
            perform action dry : Dry;
        }

        part def PressureSensor {
            attribute currentPressure :> PressureValue;
            port sensePort : PressureSignalPort;
            port signalOut : PressureSignalPort;
            perform action readPressure : ReadPressure;
        }

        part def TemperatureSensor {
            attribute currentTemperature :> TemperatureValue;
            port sensePort : TemperatureSignalPort;
            port signalOut : TemperatureSignalPort;
            perform action readTemperature : ReadTemperature;
        }

        part def DoorLockAssembly {
            port commandPort : DoorLockControlPort;
            port statusPort : DoorLockControlPort;
            perform action lockDoor : LockDoor;
            perform action unlockDoor : UnlockDoor;
            exhibit state doorLockStates : DoorLockStates;
        }

        part def SafetyValve {
            attribute crackingPressure :> PressureValue;
            port inletPort : SteamPort;
            port ventPort : ExhaustPort;
            perform action ventSteam : VentSteam;
            perform action stopVentSteam : StopVentSteam;
            exhibit state safetyValveStates : SafetyValveStates;
        }

        part def ControlUnit {
            attribute requiredSterilizationTemperature :> TemperatureValue;
            attribute requiredSterilizationPressure :> PressureValue;
            attribute requiredHoldDuration :> DurationValue;
            attribute holdEndTime : Time::DateTime;
            port pressureInput : PressureSignalPort;
            port temperatureInput : TemperatureSignalPort;
            port steamGeneratorCommand : ControlPort;
            port vacuumPumpCommand : ControlPort;
            port doorLockCommand : DoorLockControlPort;
            port doorLockStatus : DoorLockControlPort;
            exhibit state sterilizationCycle : SterilizationCycle;
        }

        part def AutoclaveSystem {
            part chamber : SterilizationChamber[1];
            part controlUnit : ControlUnit[1];
            part steamGenerator : SteamGenerator[1];
            part vacuumPump : VacuumPump[1];
            part pressureSensor : PressureSensor[1];
            part temperatureSensor : TemperatureSensor[1];
            part doorLockAssembly : DoorLockAssembly[1];
            part safetyValve : SafetyValve[1];

            connection : SteamFlow connect steamGenerator.steamOut to chamber.steamIn;
            connection : AirFlow connect vacuumPump.airPort to chamber.airPort;
            connection : PressureSignalConnection connect pressureSensor.sensePort to chamber.pressureTap;
            connection : TemperatureSignalConnection connect temperatureSensor.sensePort to chamber.temperatureTap;
            connection : PressureSignalConnection connect pressureSensor.signalOut to controlUnit.pressureInput;
            connection : TemperatureSignalConnection connect temperatureSensor.signalOut to controlUnit.temperatureInput;
            connection : ControlSignalConnection connect controlUnit.steamGeneratorCommand to steamGenerator.commandPort;
            connection : ControlSignalConnection connect controlUnit.vacuumPumpCommand to vacuumPump.commandPort;
            connection : DoorLockControlConnection connect controlUnit.doorLockCommand to doorLockAssembly.commandPort;
            connection : DoorLockControlConnection connect doorLockAssembly.statusPort to controlUnit.doorLockStatus;
            connection : SteamFlow connect chamber.pressureRelief to safetyValve.inletPort;
        }

        action def GenerateSteam;
        action def Evacuate;
        action def Dry;
        action def ReadPressure { out pressure : PressureValue; }
        action def ReadTemperature { out temperature : TemperatureValue; }
        action def LockDoor;
        action def UnlockDoor;
        action def VentSteam;
        action def StopVentSteam;

        state def SterilizationCycle;
        state def SafetyValveStates;
        state def DoorLockStates;

        requirement def SterilizationEffectiveness {
            doc /* The autoclave must sterilize instruments effectively by achieving and maintaining the required temperature and pressure for the specified duration. */
            subject autoclaveSystem : AutoclaveSystem;
            attribute minTemperature :> TemperatureValue;
            attribute minPressure :> PressureValue;
            attribute minDuration :> DurationValue;
        }

        requirement def SafetyPressureLimit {
            doc /* The chamber pressure must not exceed the maximum safe pressure limit at any time during operation. */
            subject safetyValve : SafetyValve;
            attribute maxPressure :> PressureValue;
        }

        requirement def DoorInterlock {
            doc /* The door must remain locked whenever the chamber pressure exceeds atmospheric pressure. */
            subject doorLock : DoorLockAssembly;
        }
    }

    package Usages {
        private import Definitions::*;

        part autoclave : AutoclaveSystem;

        action 'vent steam' : VentSteam;
        action 'stop vent steam' : StopVentSteam;
        action 'lock door' : LockDoor;
        action 'unlock door' : UnlockDoor;

        state 'sterilizationCycle' : SterilizationCycle {
            entry; then idle;
            state idle;
            accept 'StartCycleSignal'
                do send new 'CommandLockDoor'() to autoclave.doorLockAssembly
                then securingDoor;
            state securingDoor;
            accept 'DoorLockedSignal'
                do send new 'CommandEvacuate'() to autoclave.vacuumPump
                then evacuating;
            state evacuating;
            accept 'EvacuationCompleteSignal'
                do send new 'CommandInjectSteam'() to autoclave.steamGenerator
                then steamInjection;
            state steamInjection;
            accept 'SterilizationConditionsReachedSignal'
                then holding;
            state holding;
            accept at autoclave.controlUnit.holdEndTime
                do send new 'CommandExhaust'() to autoclave.vacuumPump
                then exhausting;
            state exhausting;
            accept 'ExhaustCompleteSignal'
                do send new 'CommandDry'() to autoclave.vacuumPump
                then drying;
            state drying;
            accept 'DryingCompleteSignal'
                do send new 'CommandUnlockDoor'() to autoclave.doorLockAssembly
                then unlockingDoor;
            state unlockingDoor;
            accept 'DoorUnlockedSignal'
                then complete;
            state complete;
            accept 'AbortCycleSignal'
                do send new 'CommandExhaust'() to autoclave.vacuumPump
                then aborted;
            state aborted;
        }

        state 'safetyValveStates' : SafetyValveStates {
            entry; then closed;
            state closed;
            accept when autoclave.chamber.pressure > autoclave.safetyValve.crackingPressure
                do 'vent steam'
                then open;
            state open;
            accept when autoclave.chamber.pressure <= autoclave.safetyValve.crackingPressure
                do 'stop vent steam'
                then closed;
        }

        state 'doorLockStates' : DoorLockStates {
            entry; then unlocked;
            state unlocked;
            accept 'CommandLockDoor'
                do 'lock door'
                then locked;
            state locked;
            accept 'CommandUnlockDoor'
                do 'unlock door'
                then unlocked;
        }

        requirement 'Sterilization Effectiveness Requirement' : SterilizationEffectiveness {
            attribute minTemperature = 121;
            attribute minPressure = 2.0;
            attribute minDuration = 900;
        }

        requirement 'Safety Pressure Limit Requirement' : SafetyPressureLimit {
            attribute maxPressure = 3.0;
        }

        requirement 'Door Interlock Requirement' : DoorInterlock {
        }

        satisfy 'Sterilization Effectiveness Requirement' by autoclave.controlUnit;
        satisfy 'Safety Pressure Limit Requirement' by autoclave.safetyValve;
        satisfy 'Door Interlock Requirement' by autoclave.doorLockAssembly;
    }
}
