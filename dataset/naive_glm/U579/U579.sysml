package WaterPumpingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolumeFlowRate::*;

    // ---- Items ----
    item def Water;

    // ---- Value types (with units) ----
    value type Volume :> ISQVolume;
    value type Level :> ISQLength;
    value type FlowRate :> ISQVolumeFlowRate;
    value type Pressure :> ISQPressure;
    value type Duration :> ISQDuration;
    value type Frequency :> ISQFrequency;

    // ---- Port definitions ----
    port def FluidPort {
        attribute flowRate : FlowRate;
        flow of Water;
    }

    port def FluidOutPort :> FluidPort {
        out flow of Water;
    }

    port def FluidInPort :> FluidPort {
        in flow of Water;
    }

    port def LevelSignalPort {
        attribute levelReading : Level;
        attribute readingValid : Boolean;
        attribute timestamp : Duration;
    }

    port def LevelSignalOutPort :> LevelSignalPort {
        out attribute levelReading : Level;
        out attribute readingValid : Boolean;
        out attribute timestamp : Duration;
    }

    port def LevelSignalInPort :> LevelSignalPort {
        in attribute levelReading : Level;
        in attribute readingValid : Boolean;
        in attribute timestamp : Duration;
    }

    port def PumpCommandPort {
        attribute startCommand : Boolean;
        attribute stopCommand : Boolean;
        attribute commandId : Integer;
    }

    port def PumpCommandOutPort :> PumpCommandPort {
        out attribute startCommand : Boolean;
        out attribute stopCommand : Boolean;
        out attribute commandId : Integer;
    }

    port def PumpCommandInPort :> PumpCommandPort {
        in attribute startCommand : Boolean;
        in attribute stopCommand : Boolean;
        in attribute commandId : Integer;
    }

    // ---- Source Reservoir ----
    part def SourceReservoir {
        attribute capacity : Volume = 1000.0 [m^3];
        attribute initialVolume : Volume = 800.0 [m^3];
        attribute currentVolume : Volume := initialVolume;
        attribute outletPressure : Pressure = 101325.0 [Pa];

        out port fluidOutlet : FluidOutPort {
            attribute flowRate : FlowRate = 0.0 [m^3/s];
        }

        action def SupplyWater(in requestedFlow : FlowRate) : out deliveredFlow : FlowRate {
            if currentVolume > 0.0 [m^3] {
                deliveredFlow := requestedFlow;
                currentVolume := currentVolume - (deliveredFlow * 1.0 [s]);
            } else {
                deliveredFlow := 0.0 [m^3/s];
            }
        }
    }

    // ---- Destination Tank ----
    part def DestinationTank {
        attribute capacity : Volume = 50.0 [m^3];
        attribute crossSectionArea : Real = 25.0 [m^2];
        attribute tankHeight : Level = 2.0 [m];
        attribute lowLimit : Level = 0.2 [m];
        attribute highLimit : Level = 1.8 [m];
        attribute initialLevel : Level = 1.0 [m];
        attribute currentLevel : Level := initialLevel;
        attribute currentVolume : Volume := currentLevel * crossSectionArea;

        in port fluidInlet : FluidInPort {
            attribute flowRate : FlowRate = 0.0 [m^3/s];
        }

        action def UpdateLevel(in inflowRate : FlowRate, in dt : Duration) {
            attribute deltaVolume : Volume := inflowRate * dt;
            attribute newVolume : Volume := currentVolume + deltaVolume;
            if newVolume > capacity {
                currentVolume := capacity;
                currentLevel := tankHeight;
            } else {
                if newVolume < 0.0 [m^3] {
                    currentVolume := 0.0 [m^3];
                    currentLevel := 0.0 [m];
                } else {
                    currentVolume := newVolume;
                    currentLevel := currentVolume / crossSectionArea;
                }
            }
        }

        action def SenseLevel() : out measuredLevel : Level {
            measuredLevel := currentLevel;
        }
    }

    // ---- Water Pump ----
    part def WaterPump {
        attribute ratedFlow : FlowRate = 0.01 [m^3/s];
        attribute startDuration : Duration = 5.0 [s];
        attribute stopDuration : Duration = 3.0 [s];
        attribute maxPressure : Pressure = 200000.0 [Pa];
        attribute isEnergized : Boolean = false;

        in port fluidIn : FluidInPort {
            attribute flowRate : FlowRate = 0.0 [m^3/s];
        }

        out port fluidOut : FluidOutPort {
            attribute flowRate : FlowRate = 0.0 [m^3/s];
        }

        in port commandPort : PumpCommandInPort {
            attribute startCommand : Boolean = false;
            attribute stopCommand : Boolean = false;
            attribute commandId : Integer = 0;
        }

        attribute currentFlow : FlowRate := 0.0 [m^3/s];
        attribute elapsedTime : Duration := 0.0 [s];

        state pumpStateMachine {
            entry action { isEnergized := false; currentFlow := 0.0 [m^3/s]; }

            state Off {
                entry action {
                    isEnergized := false;
                    currentFlow := 0.0 [m^3/s];
                }
            }

            state Starting {
                entry action { isEnergized := true; elapsedTime := 0.0 [s]; }
                do action RampUp {
                    attribute rampProgress : Real;
                    rampProgress := elapsedTime / startDuration;
                    if rampProgress > 1.0 { rampProgress := 1.0; }
                    currentFlow := ratedFlow * rampProgress;
                    elapsedTime := elapsedTime + 1.0 [s];
                }
            }

            state Running {
                entry action {
                    isEnergized := true;
                    currentFlow := ratedFlow;
                }
                do action PumpWater {
                    fluidOut.flowRate := currentFlow;
                }
            }

            state Stopping {
                entry action { elapsedTime := 0.0 [s]; }
                do action RampDown {
                    attribute rampProgress : Real;
                    rampProgress := 1.0 - (elapsedTime / stopDuration);
                    if rampProgress < 0.0 { rampProgress := 0.0; }
                    currentFlow := ratedFlow * rampProgress;
                    elapsedTime := elapsedTime + 1.0 [s];
                }
            }

            transition first to Off;

            transition from Off to Starting
                when commandPort.startCommand == true
                guard not commandPort.stopCommand;

            transition from Starting to Running
                when elapsedTime >= startDuration;

            transition from Running to Stopping
                when commandPort.stopCommand == true;

            transition from Stopping to Off
                when elapsedTime >= stopDuration;
        }
    }

    // ---- Level Sensor ----
    part def LevelSensor {
        attribute accuracy : Level = 0.005 [m];
        attribute samplePeriod : Duration = 1.0 [s];
        attribute measurementRange : Level = 2.0 [m];
        attribute sensorId : String = "LS-001";
        attribute lastReading : Level := 0.0 [m];
        attribute readingValid : Boolean := true;
        attribute timestamp : Duration := 0.0 [s];

        in port tankInterface {
            in attribute tankLevel : Level;
        }

        out port signalOut : LevelSignalOutPort {
            attribute levelReading : Level = 0.0 [m];
            attribute readingValid : Boolean = true;
            attribute timestamp : Duration = 0.0 [s];
        }

        action def MeasureLevel(in actualLevel : Level) : out measured : Level {
            attribute noise : Level;
            // Simulated bounded noise within +/- accuracy
            noise := 0.0 [m];
            measured := actualLevel + noise;
            if measured < 0.0 [m] { measured := 0.0 [m]; }
            if measured > measurementRange { measured := measurementRange; }
            lastReading := measured;
            readingValid := true;
            timestamp := timestamp + samplePeriod;
        }

        action def TransmitReading() {
            signalOut.levelReading := lastReading;
            signalOut.readingValid := readingValid;
            signalOut.timestamp := timestamp;
        }

        do action SensorLoop {
            while true {
                MeasureLevel(tankInterface.tankLevel);
                TransmitReading();
                wait(samplePeriod);
            }
        }
    }

    // ---- Pump Controller ----
    part def PumpController {
        attribute lowSetpoint : Level = 0.2 [m];
        attribute highSetpoint : Level = 1.8 [m];
        attribute hysteresis : Level = 0.05 [m];
        attribute controllerId : String = "PC-001";
        attribute commandCounter : Integer := 0;
        attribute lastLevel : Level := 1.0 [m];
        attribute pumpActive : Boolean := false;

        in port levelIn : LevelSignalInPort {
            attribute levelReading : Level = 1.0 [m];
            attribute readingValid : Boolean = true;
            attribute timestamp : Duration = 0.0 [s];
        }

        out port commandOut : PumpCommandOutPort {
            attribute startCommand : Boolean = false;
            attribute stopCommand : Boolean = false;
            attribute commandId : Integer = 0;
        }

        action def SendStartCommand() {
            commandOut.startCommand := true;
            commandOut.stopCommand := false;
            commandCounter := commandCounter + 1;
            commandOut.commandId := commandCounter;
            pumpActive := true;
        }

        action def SendStopCommand() {
            commandOut.startCommand := false;
            commandOut.stopCommand := true;
            commandCounter := commandCounter + 1;
            commandOut.commandId := commandCounter;
            pumpActive := false;
        }

        action def ClearCommands() {
            commandOut.startCommand := false;
            commandOut.stopCommand := false;
        }

        state controllerStateMachine {
            entry action { ClearCommands(); }

            state Monitoring {
                entry action { ClearCommands(); }
                do action EvaluateLevel {
                    if levelIn.readingValid {
                        lastLevel := levelIn.levelReading;
                        if lastLevel < lowSetpoint {
                            SendStartCommand();
                        }
                    }
                }
            }

            state Pumping {
                entry action { ClearCommands(); }
                do action EvaluateLevelPumping {
                    if levelIn.readingValid {
                        lastLevel := levelIn.levelReading;
                        if lastLevel >= highSetpoint {
                            SendStopCommand();
                        }
                    }
                }
            }

            transition first to Monitoring;

            transition from Monitoring to Pumping
                when levelIn.readingValid and levelIn.levelReading < lowSetpoint;

            transition from Pumping to Monitoring
                when levelIn.readingValid and levelIn.levelReading >= highSetpoint;
        }
    }

    // ---- System composition ----
    part def AutomatedWaterPumpingSystem {
        attribute systemName : String = "AWPS-01";
        attribute systemStatus : String = "Operational";

        part reservoir : SourceReservoir {
            attribute label : String = "SourceReservoir-01";
        }

        part tank : DestinationTank {
            attribute label : String = "DestinationTank-01";
        }

        part pump : WaterPump {
            attribute label : String = "WaterPump-01";
        }

        part sensor : LevelSensor {
            attribute label : String = "LevelSensor-01";
        }

        part controller : PumpController {
            attribute label : String = "PumpController-01";
        }

        // Fluid connections
        connect reservoir.fluidOutlet to pump.fluidIn {
            attribute connectionId : String = "C-Fluid-01";
        }

        connect pump.fluidOut to tank.fluidInlet {
            attribute connectionId : String = "C-Fluid-02";
        }

        // Sensor measures tank level
        connect tank.currentLevel to sensor.tankInterface.tankLevel {
            attribute connectionId : String = "C-Sense-01";
        }

        // Signal connections
        connect sensor.signalOut to controller.levelIn {
            attribute connectionId : String = "C-Signal-01";
        }

        connect controller.commandOut to pump.commandPort {
            attribute connectionId : String = "C-Cmd-01";
        }

        // System-level behavior
        action def SystemStartup() {
            reservoir.currentVolume := reservoir.initialVolume;
            tank.currentLevel := tank.initialLevel;
            controller.pumpActive := false;
            pump.currentFlow := 0.0 [m^3/s];
        }

        action def SystemShutdown() {
            controller.SendStopCommand();
            systemStatus := "Shutdown";
        }

        do action SystemOperation {
            SystemStartup();
            while systemStatus == "Operational" {
                // Continuous coordination handled by part state machines
                wait(1.0 [s]);
            }
        }
    }

    // ---- Requirements ----
    requirement def MaintainWaterLevel {
        attribute id : String = "REQ-001";
        subject : AutomatedWaterPumpingSystem;
        objective {
            doc /* The system shall maintain the water level in the destination tank
                   between the low setpoint and the high setpoint. */
        }
        assume tank.currentLevel >= 0.0 [m];
        require tank.currentLevel >= controller.lowSetpoint or pump.isEnergized;
        require tank.currentLevel <= controller.highSetpoint;
    }

    requirement def PreventOverflow {
        attribute id : String = "REQ-002";
        subject : AutomatedWaterPumpingSystem;
        objective {
            doc /* The system shall prevent the destination tank from overflowing. */
        }
        require tank.currentLevel <= tank.tankHeight;
    }

    requirement def PumpStateTransitions {
        attribute id : String = "REQ-003";
        subject : WaterPump;
        objective {
            doc /* The pump shall transition through Starting, Running, and Stopping states. */
        }
        require pump.pumpStateMachine.Running.isReached;
    }

    requirement def SensorAccuracy {
        attribute id : String = "REQ-004";
        subject : LevelSensor;
        objective {
            doc /* The level sensor shall measure water level within the defined accuracy. */
        }
        require sensor.accuracy <= 0.01 [m];
    }

    requirement def AutomatedControlCycle {
        attribute id : String = "REQ-005";
        subject : PumpController;
        objective {
            doc /* The controller shall autonomously activate the pump below the low setpoint
                   and deactivate it above the high setpoint. */
        }
        require controller.lowSetpoint < controller.highSetpoint;
        require controller.commandOut.startCommand == true when tank.currentLevel < controller.lowSetpoint;
        require controller.commandOut.stopCommand == true when tank.currentLevel >= controller.highSetpoint;
    }

    requirement def ReliableWaterSupply {
        attribute id : String = "REQ-006";
        subject : AutomatedWaterPumpingSystem;
        objective {
            doc /* The system shall provide a reliable water supply from the source reservoir
                   to the destination tank. */
        }
        require reservoir.currentVolume > 0.0 [m^3];
        require pump.ratedFlow > 0.0 [m^3/s];
    }

    // ---- Requirement satisfaction ----
    satisfaction MaintainWaterLevel {
        subject : AutomatedWaterPumpingSystem = AutomatedWaterPumpingSystem;
        verify by SystemOperation;
    }

    satisfaction PreventOverflow {
        subject : AutomatedWaterPumpingSystem = AutomatedWaterPumpingSystem;
        verify by SystemOperation;
    }

    satisfaction PumpStateTransitions {
        subject : WaterPump = WaterPump;
        verify by pumpStateMachine;
    }

    satisfaction SensorAccuracy {
        subject : LevelSensor = LevelSensor;
        verify by MeasureLevel;
    }

    satisfaction AutomatedControlCycle {
        subject : PumpController = PumpController;
        verify by controllerStateMachine;
    }

    satisfaction ReliableWaterSupply {
        subject : AutomatedWaterPumpingSystem = AutomatedWaterPumpingSystem;
        verify by SystemOperation;
    }
}
