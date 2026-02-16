package AutoclaveSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def CyclePhase;
    attribute def StartCommand;
    attribute def AbortCommand;

    item def MedicalInstrument;
    item def SterilizedInstrument :> MedicalInstrument;
    item def Steam;
    item def Water;
    item def Condensate;

    port def SteamSupplyPort {
        in flow steamIn : Steam;
        out steamPressure : PressureValue;
        out steamTemperature : TemperatureValue;
    }

    port def WaterSupplyPort {
        in flow waterIn : Water;
    }

    port def DrainPort {
        out flow drainOut : Condensate;
    }

    port def SensorPort {
        out pressure : PressureValue;
        out temperature : TemperatureValue;
    }

    port def DoorControlPort {
        in lockCommand : Boolean;
        out lockStatus : Boolean;
        out doorClosed : Boolean;
    }

    part def SterilizationChamber {
        port sensorOutput : SensorPort;
        port steamInput : SteamSupplyPort;
        port drainOutput : DrainPort;
        attribute volume : VolumeValue;
        attribute currentPressure : PressureValue;
        attribute currentTemperature : TemperatureValue;
        attribute maxPressure : PressureValue;
        part contents : MedicalInstrument[*];
    }

    part def SteamGenerator {
        port waterSupply : WaterSupplyPort;
        port steamOutput : SteamSupplyPort;
        attribute heatingPower : PowerValue;
        attribute generationRate : Real;
        in steamDemand : Boolean;
    }

    part def VacuumPump {
        port chamberConnection : DrainPort;
        attribute pumpingCapacity : VolumeValue;
        in pumpActive : Boolean;
    }

    part def PressureSensor {
        port measurement : SensorPort;
        attribute accuracy : PressureValue;
    }

    part def TemperatureSensor {
        port measurement : SensorPort;
        attribute accuracy : TemperatureValue;
    }

    part def DoorLockAssembly {
        port control : DoorControlPort;
        attribute lockEngaged : Boolean;
        attribute doorSealed : Boolean;
    }

    part def SafetyValve {
        in chamberPressure : PressureValue;
        out reliefActive : Boolean;
        attribute reliefPressure : PressureValue;
    }

    part def ControlUnit {
        in chamberPressure : PressureValue;
        in chamberTemperature : TemperatureValue;
        in doorStatus : Boolean;
        out steamControl : Boolean;
        out vacuumControl : Boolean;
        out doorLockControl : Boolean;
        attribute targetPressure : PressureValue;
        attribute targetTemperature : TemperatureValue;
        attribute sterilizationDuration : DurationValue;
        attribute dryingDuration : DurationValue;
    }

    action def MonitorConditions {
        in currentPressure : PressureValue;
        in currentTemperature : TemperatureValue;
        in targetPressure : PressureValue;
        in targetTemperature : TemperatureValue;
        out conditionsMet : Boolean;
    }

    action def ActivateSteamInjection {
        in targetPressure : PressureValue;
        out steamEnabled : Boolean;
    }

    action def ActivateVacuum {
        out vacuumEnabled : Boolean;
    }

    action def SecureDoor {
        out doorLocked : Boolean;
    }

    action def ReleaseDoor {
        in safePressure : Boolean;
        out doorUnlocked : Boolean;
    }

    action def MaintainSterilization {
        in targetPressure : PressureValue;
        in targetTemperature : TemperatureValue;
        in duration : DurationValue;
        out maintainComplete : Boolean;
    }

    action def ExecuteSterilizationCycle {
        in instruments : MedicalInstrument[*];
        in targetPressure : PressureValue;
        in targetTemperature : TemperatureValue;
        in sterilizationTime : DurationValue;
        in dryingTime : DurationValue;
        out sterilizedInstruments : SterilizedInstrument[*];

        first start;
        then action secureDoorAction : SecureDoor {
            out doorLocked : Boolean;
        }
        then action evacuateAir : ActivateVacuum {
            out vacuumEnabled : Boolean;
        }
        then action injectSteam : ActivateSteamInjection {
            in targetPressure = ExecuteSterilizationCycle::targetPressure;
            out steamEnabled : Boolean;
        }
        then merge conditionCheck;
        then action monitorAction : MonitorConditions {
            in currentPressure : PressureValue;
            in currentTemperature : TemperatureValue;
            in targetPressure = ExecuteSterilizationCycle::targetPressure;
            in targetTemperature = ExecuteSterilizationCycle::targetTemperature;
            out conditionsMet : Boolean;
        }
        then decide;
            if !monitorAction.conditionsMet then conditionCheck;
            if monitorAction.conditionsMet then sterilizePhase;
        action sterilizePhase : MaintainSterilization {
            in targetPressure = ExecuteSterilizationCycle::targetPressure;
            in targetTemperature = ExecuteSterilizationCycle::targetTemperature;
            in duration = sterilizationTime;
            out maintainComplete : Boolean;
        }
        then action exhaustSteam : ActivateVacuum {
            out vacuumEnabled : Boolean;
        }
        then action dryContents : MaintainSterilization {
            in targetPressure : PressureValue;
            in targetTemperature : TemperatureValue;
            in duration = dryingTime;
            out maintainComplete : Boolean;
        }
        then action releaseDoorAction : ReleaseDoor {
            in safePressure : Boolean;
            out doorUnlocked : Boolean;
        }
        then done;
    }

    state def AutoclaveStateMachine {
        in startCycle : StartCommand;
        in abortCycle : AbortCommand;
        in doorClosed : Boolean;
        in currentPressure : PressureValue;
        in currentTemperature : TemperatureValue;
        in targetPressure : PressureValue;
        in targetTemperature : TemperatureValue;
        in sterilizationTime : DurationValue;
        out steamActive : Boolean;
        out vacuumActive : Boolean;
        out doorLocked : Boolean;

        entry; then Idle;

        state Idle {
            entry assign doorLocked := false;
        }

        state DoorSecured {
            entry assign doorLocked := true;
        }

        state Evacuation {
            entry assign vacuumActive := true;
        }

        state Heating {
            entry assign steamActive := true;
            entry assign vacuumActive := false;
        }

        state Sterilizing {
            do assign steamActive := true;
        }

        state Exhausting {
            entry assign steamActive := false;
            entry assign vacuumActive := true;
        }

        state Drying {
            do assign vacuumActive := true;
        }

        state Complete {
            entry assign vacuumActive := false;
            entry assign doorLocked := false;
        }

        transition first from Idle to DoorSecured
            accept startCycle
            if doorClosed;
        transition from DoorSecured to Evacuation;
        transition from Evacuation to Heating
            if currentPressure <= 10.0[kPa];
        transition from Heating to Sterilizing 
            if currentPressure >= targetPressure and currentTemperature >= targetTemperature;
        transition from Sterilizing to Exhausting;
        transition from Exhausting to Drying
            if currentPressure <= 101.325[kPa];
        transition from Drying to Complete;
        transition from Complete to Idle;
        transition abortTransition from any to Idle
            accept abortCycle;
    }

    part def Autoclave;

    part autoclave : Autoclave {
        attribute operatingPressure : PressureValue;
        attribute operatingTemperature : TemperatureValue;
        attribute cycleDuration : DurationValue;

        part chamber : SterilizationChamber {
            attribute :>> volume = 100.0[L];
            attribute :>> maxPressure = 250.0[kPa];
        }

        part steamGen : SteamGenerator {
            attribute :>> heatingPower = 3000.0[W];
            attribute :>> generationRate = 5.0;
        }

        part vacuum : VacuumPump {
            attribute :>> pumpingCapacity = 50.0[L];
        }

        part pressureSensor : PressureSensor {
            attribute :>> accuracy = 1.0[kPa];
        }

        part tempSensor : TemperatureSensor {
            attribute :>> accuracy = 0.5['°C'];
        }

        part doorLock : DoorLockAssembly;

        part safetyValve : SafetyValve {
            attribute :>> reliefPressure = 240.0[kPa];
        }

        part controller : ControlUnit {
            attribute :>> targetPressure = 205.0[kPa];
            attribute :>> targetTemperature = 134.0['°C'];
            attribute :>> sterilizationDuration = 15.0[min];
            attribute :>> dryingDuration = 5.0[min];
        }

        connection steamSupply connect steamGen.steamOutput to chamber.steamInput;
        connection vacuumConnection connect vacuum.chamberConnection to chamber.drainOutput;
        connection pressureMonitoring connect pressureSensor.measurement to chamber.sensorOutput;
        connection temperatureMonitoring connect tempSensor.measurement to chamber.sensorOutput;
        connection doorControl connect controller to doorLock.control;
        connection safetyMonitoring connect chamber.sensorOutput to safetyValve.chamberPressure;

        bind chamber.currentPressure = pressureSensor.measurement.pressure;
        bind chamber.currentTemperature = tempSensor.measurement.temperature;
        bind controller.chamberPressure = pressureSensor.measurement.pressure;
        bind controller.chamberTemperature = tempSensor.measurement.temperature;
        bind controller.doorStatus = doorLock.control.doorClosed;
        bind steamGen.steamDemand = controller.steamControl;
        bind vacuum.pumpActive = controller.vacuumControl;
        bind doorLock.control.lockCommand = controller.doorLockControl;

        perform action sterilizationCycle[*] ordered references ExecuteSterilizationCycle {
            in instruments = chamber.contents;
            in targetPressure = controller.targetPressure;
            in targetTemperature = controller.targetTemperature;
            in sterilizationTime = controller.sterilizationDuration;
            in dryingTime = controller.dryingDuration;
            out sterilizedInstruments : SterilizedInstrument[*];
        }

        exhibit state autoclaveControl : AutoclaveStateMachine;
    }

    requirement def SterilizationEffectiveness {
        doc /* The autoclave shall achieve complete sterilization by maintaining specified temperature and pressure conditions for the required duration. */

        require constraint temperatureRequirement {
            doc /* Chamber temperature must reach and maintain at least 121°C during sterilization. */
        }

        require constraint pressureRequirement {
            doc /* Chamber pressure must reach and maintain at least 205 kPa during sterilization. */
        }

        require constraint durationRequirement {
            doc /* Sterilization conditions must be maintained for minimum 15 minutes. */
        }
    }

    requirement def SafetyRequirement {
        doc /* The autoclave shall operate safely preventing hazardous conditions. */

        require constraint doorInterlock {
            doc /* Door must remain locked whenever chamber pressure exceeds atmospheric pressure. */
        }

        require constraint pressureRelief {
            doc /* Safety valve must activate if chamber pressure exceeds maximum rated pressure. */
        }

        require constraint emergencyStop {
            doc /* System must safely abort cycle and depressurize chamber upon abort command. */
        }
    }

    requirement autoclaveSystemRequirements {
        doc /* The autoclave system shall sterilize medical instruments safely and effectively using high-pressure saturated steam. */

        subject autoclave;

        require sterilizationReq : SterilizationEffectiveness;
        require safetyReq : SafetyRequirement;
    }
}
