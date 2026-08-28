package HouseholdWashingMachineSystem {

    import ScalarValues::*;

    // ===== Value Types =====
    value type Volume :> Real { unit 'L'; }
    value type Temperature :> Real { unit 'degC'; }
    value type RotationalSpeed :> Real { unit 'rpm'; }
    value type Power :> Real { unit 'W'; }
    value type Pressure :> Real { unit 'bar'; }
    value type Mass :> Real { unit 'kg'; }
    value type Duration :> Real { unit 'min'; }
    value type Voltage :> Real { unit 'V'; }
    value type FlowRate :> Real { unit 'L/min'; }

    // ===== Item Definitions =====
    item def FreshWater;
    item def WasteWater;
    item def Detergent;
    item def DirtyLaundry;
    item def CleanLaundry;
    item def ElectricalEnergy;

    // ===== Enumerations =====
    enum def WashProgram {
        CottonHeavy;
        Delicate;
        QuickWash;
    }

    enum def DoorState {
        Locked;
        Unlocked;
    }

    enum def MotorDirection {
        Forward;
        Reverse;
    }

    // ===== Port Definitions =====
    port def WaterPort {
        in item water : FreshWater;
    }

    port def WastePort {
        in item wasteWater : WasteWater;
    }

    port def PowerPort {
        in item power : ElectricalEnergy;
    }

    port def CommandPort {
        in attribute command : String;
    }

    port def FeedbackPort {
        in attribute reading : Real;
        in attribute sensorId : String;
    }

    port def DrivePort {
        in attribute speed : RotationalSpeed;
        in attribute direction : MotorDirection;
    }

    // ===== Requirement Definitions =====
    requirement def CleanLaundryRequirement {
        doc /* The washing machine shall clean laundry by executing selectable wash programs including Cotton Heavy, Delicate, and Quick Wash. */
        attribute minCapacity : Mass = 7;
        attribute programCount : Integer = 3;
        require minCapacity >= 7;
        require programCount >= 3;
    }

    requirement def DoorSafetyRequirement {
        doc /* The door shall remain locked while the drum is rotating or contains water to prevent injury. */
        attribute maxUnlockSpeed : RotationalSpeed = 0;
        require doorState == DoorState::Locked when drumSpeed > maxUnlockSpeed or drumContainsWater;
    }

    requirement def WaterManagementRequirement {
        doc /* The machine shall fill and drain water as specified by the selected program without overflow. */
        attribute maxFillVolume : Volume = 50;
        require fillVolume <= maxFillVolume;
    }

    requirement def EnergyRequirement {
        doc /* The machine shall operate within specified power limits from a standard household electrical supply. */
        attribute maxPower : Power = 2400;
        require powerConsumption <= maxPower;
    }

    requirement def TemperatureControlRequirement {
        doc /* The heater shall raise water temperature to the target specified by the wash program. */
        attribute maxTemperature : Temperature = 90;
        attribute accuracy : Temperature = 2;
        require targetTemperature <= maxTemperature;
    }

    requirement def CycleCompletionRequirement {
        doc /* The machine shall unlock the door and signal completion when the entire wash process is finished. */
        require doorState == DoorState::Unlocked when cycleComplete;
    }

    // ===== External System Definitions =====
    part def WaterSupply {
        port supplyPort : ~WaterPort;
        attribute pressure : Pressure = 3.0;
        attribute maxFlowRate : FlowRate = 12;
    }

    part def SewerDrain {
        port drainPort : WastePort;
        attribute maxFlowRate : FlowRate = 30;
    }

    part def ElectricalGrid {
        port powerPort : ~PowerPort;
        attribute voltage : Voltage = 230;
        attribute frequency : Real = 50;
        attribute maxPower : Power = 3600;
    }

    // ===== Washing Machine Component Definitions =====
    part def DrumAssembly {
        port driveInput : DrivePort;
        port waterInput : WaterPort;
        port wasteOutput : ~WastePort;

        attribute capacity : Mass = 7;
        attribute currentSpeed : RotationalSpeed = 0;
        attribute direction : MotorDirection = MotorDirection::Forward;
        attribute containsWater : Boolean = false;
        attribute waterLevel : Volume = 0;
        attribute load : Mass = 0;
        attribute temperature : Temperature = 20;

        action def Tumble {
            in tumbleSpeed : RotationalSpeed;
            in tumbleDuration : Duration;
            in tumbleDirection : MotorDirection;
        }

        action def Spin {
            in spinSpeed : RotationalSpeed;
            in spinDuration : Duration;
        }

        action def ReceiveWater {
            in volume : Volume;
        }

        action def DischargeWater {
            out volume : Volume;
        }
    }

    part def DriveMotor {
        port shaftPort : ~DrivePort;
        port powerInput : PowerPort;
        port controlPort : CommandPort;

        attribute ratedPower : Power = 500;
        attribute currentSpeed : RotationalSpeed = 0;
        attribute direction : MotorDirection = MotorDirection::Forward;
        attribute isRunning : Boolean = false;

        action def Start {
            in startSpeed : RotationalSpeed;
            in startDirection : MotorDirection;
        }

        action def Stop;

        action def ChangeSpeed {
            in newSpeed : RotationalSpeed;
        }

        action def Reverse;
    }

    part def WaterInletValve {
        port inletPort : WaterPort;
        port outletPort : ~WaterPort;
        port controlPort : CommandPort;

        attribute isOpen : Boolean = false;
        attribute flowRate : FlowRate = 12;

        action def Open;
        action def Close;
    }

    part def DrainPump {
        port inletPort : WastePort;
        port outletPort : ~WastePort;
        port controlPort : CommandPort;

        attribute isActive : Boolean = false;
        attribute pumpRate : FlowRate = 25;

        action def Activate;
        action def Deactivate;
    }

    part def WaterHeater {
        port controlPort : CommandPort;
        port powerInput : PowerPort;

        attribute ratedPower : Power = 2000;
        attribute isOn : Boolean = false;
        attribute currentTemperature : Temperature = 20;

        action def Heat {
            in targetTemp : Temperature;
        }

        action def TurnOff;
    }

    part def WaterLevelSensor {
        port feedbackPort : ~FeedbackPort;

        attribute level : Volume = 0;
        attribute maxRange : Volume = 50;
        attribute isCalibrated : Boolean = true;

        action def Measure {
            out measuredLevel : Volume;
        }

        action def Calibrate;
    }

    part def TemperatureSensor {
        port feedbackPort : ~FeedbackPort;

        attribute temperature : Temperature = 20;
        attribute accuracy : Temperature = 1;
        attribute maxRange : Temperature = 100;

        action def Measure {
            out measuredTemp : Temperature;
        }
    }

    part def DoorLock {
        port controlPort : CommandPort;

        attribute state : DoorState = DoorState::Unlocked;
        attribute isEngaged : Boolean = false;

        action def Lock;
        action def Unlock;
    }

    part def ControlModule {
        port motorControl : ~CommandPort;
        port valveControl : ~CommandPort;
        port pumpControl : ~CommandPort;
        port heaterControl : ~CommandPort;
        port doorControl : ~CommandPort;
        port levelFeedback : FeedbackPort;
        port tempFeedback : FeedbackPort;
        port powerInput : PowerPort;

        attribute selectedProgram : WashProgram;
        attribute targetTemperature : Temperature;
        attribute targetFillVolume : Volume;
        attribute targetWashSpeed : RotationalSpeed;
        attribute targetSpinSpeed : RotationalSpeed;
        attribute washDuration : Duration;
        attribute rinseCycles : Integer;
        attribute active : Boolean = false;
        attribute cycleComplete : Boolean = false;
        attribute currentPhase : String;
        attribute elapsedWashTime : Duration = 0;
        attribute currentRinseCycle : Integer = 0;
        attribute currentWaterLevel : Volume = 0;
        attribute currentTemperature : Temperature = 20;
        attribute doorLocked : Boolean = false;
        attribute drumEmpty : Boolean = true;
        attribute spinTimeElapsed : Boolean = false;
        attribute programSelected : Boolean = false;

        action def SelectProgram {
            in program : WashProgram;
        }

        action def LockDoor;
        action def UnlockDoor;
        action def OpenValve;
        action def CloseValve;
        action def ActivateHeater;
        action def DeactivateHeater;
        action def ActivatePump;
        action def DeactivatePump;
        action def StartMotor;
        action def StopMotor;
        action def AddDetergent;
        action def SignalComplete;

        action def ConfigureCottonHeavy {
            out targetTemp : Temperature = 60;
            out targetVolume : Volume = 40;
            out washSpeed : RotationalSpeed = 50;
            out spinSpeed : RotationalSpeed = 1200;
            out duration : Duration = 90;
            out rinses : Integer = 3;
        }

        action def ConfigureDelicate {
            out targetTemp : Temperature = 30;
            out targetVolume : Volume = 30;
            out washSpeed : RotationalSpeed = 30;
            out spinSpeed : RotationalSpeed = 600;
            out duration : Duration = 60;
            out rinses : Integer = 2;
        }

        action def ConfigureQuickWash {
            out targetTemp : Temperature = 30;
            out targetVolume : Volume = 20;
            out washSpeed : RotationalSpeed = 50;
            out spinSpeed : RotationalSpeed = 800;
            out duration : Duration = 30;
            out rinses : Integer = 1;
        }

        state WashCycle {
            state Idle {
                entry action waitForProgram;
            }

            state DoorLocking {
                entry action lockDoor;
            }

            state Filling {
                entry action openInletValve;
                do action monitorWaterLevel;
                exit action closeInletValve;
            }

            state Heating {
                entry action activateHeater;
                do action monitorTemperature;
                exit action deactivateHeater;
            }

            state Washing {
                entry action addDetergent;
                entry action startTumbling;
                do action monitorWashTime;
                exit action stopMotor;
            }

            state Draining {
                entry action activateDrainPump;
                do action monitorDrainComplete;
                exit action deactivateDrainPump;
            }

            state Rinsing {
                entry action openInletValve;
                entry action startTumbling;
                do action monitorRinseTime;
                exit action stopMotor;
                exit action closeInletValve;
            }

            state Spinning {
                entry action highSpeedSpin;
                do action monitorSpinTime;
                exit action stopMotor;
            }

            state Complete {
                entry action unlockDoor;
                entry action signalComplete;
            }

            transition from Idle to DoorLocking when programSelected;
            transition from DoorLocking to Filling when doorLocked;
            transition from Filling to Heating when currentWaterLevel >= targetFillVolume;
            transition from Heating to Washing when currentTemperature >= targetTemperature;
            transition from Washing to Draining when elapsedWashTime >= washDuration;
            transition from Draining to Rinsing when drumEmpty and currentRinseCycle < rinseCycles;
            transition from Rinsing to Draining when currentRinseCycle < rinseCycles;
            transition from Draining to Spinning when drumEmpty and currentRinseCycle >= rinseCycles;
            transition from Spinning to Complete when spinTimeElapsed;
        }
    }

    // ===== Main Washing Machine Assembly =====
    part def WashingMachine {
        port waterInlet : WaterPort;
        port waterOutlet : WastePort;
        port powerInput : PowerPort;

        attribute capacity : Mass = 7;
        attribute fillVolume : Volume;
        attribute powerConsumption : Power;
        attribute active : Boolean = false;

        part drumAssembly : DrumAssembly;
        part driveMotor : DriveMotor;
        part waterInletValve : WaterInletValve;
        part drainPump : DrainPump;
        part waterHeater : WaterHeater;
        part controlModule : ControlModule;
        part waterLevelSensor : WaterLevelSensor;
        part temperatureSensor : TemperatureSensor;
        part doorLock : DoorLock;

        connect waterInlet to waterInletValve.inletPort;
        connect waterInletValve.outletPort to drumAssembly.waterInput;
        connect drumAssembly.wasteOutput to drainPump.inletPort;
        connect drainPump.outletPort to waterOutlet;

        connect driveMotor.shaftPort to drumAssembly.driveInput;

        connect controlModule.motorControl to driveMotor.controlPort;
        connect controlModule.valveControl to waterInletValve.controlPort;
        connect controlModule.pumpControl to drainPump.controlPort;
        connect controlModule.heaterControl to waterHeater.controlPort;
        connect controlModule.doorControl to doorLock.controlPort;

        connect waterLevelSensor.feedbackPort to controlModule.levelFeedback;
        connect temperatureSensor.feedbackPort to controlModule.tempFeedback;

        connect powerInput to controlModule.powerInput;
        connect powerInput to driveMotor.powerInput;
        connect powerInput to waterHeater.powerInput;
    }

    // ===== System Context =====
    part WashingMachineSystem {
        part washingMachine : WashingMachine;
        part waterSupply : WaterSupply;
        part sewerDrain : SewerDrain;
        part electricalGrid : ElectricalGrid;

        connect waterSupply.supplyPort to washingMachine.waterInlet;
        connect washingMachine.waterOutlet to sewerDrain.drainPort;
        connect electricalGrid.powerPort to washingMachine.powerInput;

        requirement cleanLaundryReq : CleanLaundryRequirement;
        requirement doorSafetyReq : DoorSafetyRequirement;
        requirement waterMgmtReq : WaterManagementRequirement;
        requirement energyReq : EnergyRequirement;
        requirement tempCtrlReq : TemperatureControlRequirement;
        requirement cycleCompletionReq : CycleCompletionRequirement;

        satisfy cleanLaundryReq by washingMachine;
        satisfy doorSafetyReq by washingMachine.doorLock;
        satisfy waterMgmtReq by washingMachine;
        satisfy energyReq by washingMachine;
        satisfy tempCtrlReq by washingMachine.waterHeater;
        satisfy cycleCompletionReq by washingMachine.controlModule;
    }
}
