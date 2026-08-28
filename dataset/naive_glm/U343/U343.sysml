package MedicalOxygenConcentrator {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type Pressure :> Real { unit 'Pa'; }
    value type FlowRate :> Real { unit 'L/min'; }
    value type Temperature :> Real { unit 'K'; }
    value type Purity :> Real { unit '%'; }
    value type RotationalSpeed :> Real { unit 'rpm'; }
    value type Duration :> Real { unit 's'; }
    value type Volume :> Real { unit 'L'; }

    // ---- Item types ----
    item def AmbientAir {
        attribute pressure : Pressure = 101325 [Pa];
        attribute temperature : Temperature = 293.15 [K];
        attribute oxygenFraction : Real = 0.21;
    }
    item def CompressedAir :> AmbientAir {
        attribute pressure : Pressure;
    }
    item def EnrichedOxygen {
        attribute pressure : Pressure;
        attribute purity : Purity;
        attribute temperature : Temperature;
    }
    item def ProductOxygen :> EnrichedOxygen {
        attribute flowRate : FlowRate;
    }
    item def WasteNitrogen {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def SensorReading {
        attribute purity : Purity;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
        attribute temperature : Temperature;
    }
    item def ControlCommand {
        attribute compressorSpeed : RotationalSpeed;
        attribute activeBed : Integer;
        attribute cycleTime : Duration;
        attribute flowSetpoint : FlowRate;
        attribute emergencyStop : Boolean = false;
    }
    item def AlarmSignal {
        attribute alarmType : String;
        attribute severity : Integer;
        attribute shutdown : Boolean;
    }

    // ---- Port definitions ----
    port def AmbientAirInPort { in item : AmbientAir; }
    port def CompressedAirOutPort { out item : CompressedAir; }
    port def CompressedAirInPort { in item : CompressedAir; }
    port def OxygenOutPort { out item : EnrichedOxygen; }
    port def OxygenInPort { in item : EnrichedOxygen; }
    port def WasteOutPort { out item : WasteNitrogen; }
    port def SensorDataOutPort { out data : SensorReading; }
    port def SensorDataInPort { in data : SensorReading; }
    port def ControlCmdOutPort { out data : ControlCommand; }
    port def ControlCmdInPort { in data : ControlCommand; }
    port def AlarmOutPort { out data : AlarmSignal; }

    // ---- Requirements ----
    requirement def OxygenPurityRequirement {
        doc /* Delivered oxygen shall have purity >= 90% */
        attribute purity : Purity;
        constraint { purity >= 90 [%] }
    }
    requirement def FlowRateRequirement {
        doc /* Output flow rate shall be within prescribed therapeutic range */
        attribute flowRate : FlowRate;
        constraint { flowRate >= 0.5 [L/min] and flowRate <= 10.0 [L/min] }
    }
    requirement def SafetyRequirement {
        doc /* System shall alarm and shut down on unsafe conditions */
        attribute purity : Purity;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute shutdownRequired : Boolean;
        constraint { purity < 82 [%] implies shutdownRequired }
        constraint { pressure > 200000 [Pa] implies shutdownRequired }
        constraint { temperature > 323.15 [K] implies shutdownRequired }
    }
    requirement def ContinuousSupplyRequirement {
        doc /* System shall provide uninterrupted oxygen via alternating PSA beds */
        attribute cyclePeriod : Duration;
        constraint { cyclePeriod <= 20 [s] }
    }

    // ---- Parts ----
    part def AirCompressor {
        port airIn : AmbientAirInPort;
        port airOut : CompressedAirOutPort;
        port cmdIn : ControlCmdInPort;
        attribute speed : RotationalSpeed = 3000 [rpm];
        attribute outputPressure : Pressure = 180000 [Pa];
        attribute running : Boolean = true;

        action def CompressAir {
            in air : AmbientAir;
            in speed : RotationalSpeed;
            out compressed : CompressedAir;
        }

        state def CompressorOperation {
            entry; then Running;
            state Running {
                entry action compress();
            }
            transition from Running to Stopped when cmdIn.data.emergencyStop == true;
            state Stopped {
                entry action halt();
            }
            transition from Stopped to Running when cmdIn.data.emergencyStop == false;
        }

        action compress();
        action halt();
    }

    part def MolecularSieveBed {
        port inlet : CompressedAirInPort;
        port oxygenOutlet : OxygenOutPort;
        port wasteOutlet : WasteOutPort;
        port cmdIn : ControlCmdInPort;
        attribute bedId : String;
        attribute phase : String;
        attribute cycleTime : Duration = 10 [s];
        attribute zeoliteCapacity : Real = 1.5;
        attribute isActive : Boolean;

        enum def BedPhase { adsorption; desorption; }

        state def BedOperation {
            entry; then Adsorption;
            state Adsorption {
                entry action doAdsorption();
            }
            transition from Adsorption to Desorption when cmdIn.data.activeBed != bedId;
            state Desorption {
                entry action doDesorption();
            }
            transition from Desorption to Adsorption when cmdIn.data.activeBed == bedId;
        }

        action doAdsorption();
        action doDesorption();
    }

    part def ProductTank {
        port inlet : OxygenInPort;
        port outlet : OxygenOutPort;
        attribute volume : Volume = 5 [L];
        attribute internalPressure : Pressure;
        attribute storedPurity : Purity;

        action def BufferSupply {
            in oxygen : EnrichedOxygen;
            out buffered : EnrichedOxygen;
        }
    }

    part def FlowController {
        port inlet : OxygenInPort;
        port outlet : OxygenOutPort;
        port cmdIn : ControlCmdInPort;
        attribute setpoint : FlowRate = 2 [L/min];
        attribute actualFlow : FlowRate;

        action def RegulateFlow {
            in oxygen : EnrichedOxygen;
            in setpoint : FlowRate;
            out regulated : ProductOxygen;
        }
    }

    part def OxygenSensor {
        port samplePort : OxygenInPort;
        port dataOut : SensorDataOutPort;
        attribute measuredPurity : Purity;
        attribute measuredPressure : Pressure;
        attribute measuredFlow : FlowRate;
        attribute measuredTemp : Temperature;

        action def SampleAndReport {
            in oxygen : EnrichedOxygen;
            out reading : SensorReading;
        }
    }

    part def PSAController {
        port sensorIn : SensorDataInPort;
        port compressorCmd : ControlCmdOutPort;
        port bedCmd : ControlCmdOutPort;
        port flowCmd : ControlCmdOutPort;
        attribute targetPurity : Purity = 93 [%];
        attribute targetFlow : FlowRate = 2 [L/min];
        attribute cyclePeriod : Duration = 10 [s];
        attribute activeBed : Integer = 1;

        state def ControllerOperation {
            entry; then Monitoring;
            state Monitoring {
                entry action computeCommands();
            }
            transition from Monitoring to Adjusting when sensorIn.data.purity < targetPurity;
            state Adjusting {
                entry action adjustCycle();
            }
            transition from Adjusting to Monitoring when true;
        }

        action computeCommands();
        action adjustCycle();
    }

    part def SafetySystem {
        port sensorIn : SensorDataInPort;
        port alarmOut : AlarmOutPort;
        port shutdownCmd : ControlCmdOutPort;
        attribute purityThreshold : Purity = 82 [%];
        attribute pressureLimit : Pressure = 200000 [Pa];
        attribute tempLimit : Temperature = 323.15 [K];
        attribute alarmActive : Boolean = false;
        attribute shutdownInitiated : Boolean = false;

        state def SafetyMonitoring {
            entry; then Normal;
            state Normal;
            transition from Normal to AlarmState when sensorIn.data.purity < purityThreshold;
            transition from Normal to AlarmState when sensorIn.data.pressure > pressureLimit;
            transition from Normal to AlarmState when sensorIn.data.temperature > tempLimit;
            state AlarmState {
                entry action triggerAlarm();
            }
            transition from AlarmState to ShutdownState when true;
            state ShutdownState {
                entry action initiateShutdown();
            }
        }

        action triggerAlarm();
        action initiateShutdown();
    }

    // ---- Top-level system ----
    part def OxygenConcentratorSystem {
        port ambientIntake : AmbientAirInPort;
        port patientOutlet : OxygenOutPort;
        port alarmInterface : AlarmOutPort;

        part compressor : AirCompressor;
        part bed1 : MolecularSieveBed { attribute bedId = "Bed1"; attribute isActive = true; }
        part bed2 : MolecularSieveBed { attribute bedId = "Bed2"; attribute isActive = false; }
        part productTank : ProductTank;
        part flowController : FlowController;
        part oxygenSensor : OxygenSensor;
        part psaController : PSAController;
        part safetySystem : SafetySystem;

        // Gas flow connections
        connect ambientIntake to compressor.airIn;
        connect compressor.airOut to bed1.inlet;
        connect compressor.airOut to bed2.inlet;
        connect bed1.oxygenOutlet to productTank.inlet;
        connect bed2.oxygenOutlet to productTank.inlet;
        connect productTank.outlet to flowController.inlet;
        connect flowController.outlet to oxygenSensor.samplePort;
        connect flowController.outlet to patientOutlet;

        // Waste exhaust
        connect bed1.wasteOutlet to ambientIntake;
        connect bed2.wasteOutlet to ambientIntake;

        // Sensor data connections
        connect oxygenSensor.dataOut to psaController.sensorIn;
        connect oxygenSensor.dataOut to safetySystem.sensorIn;

        // Control signal connections
        connect psaController.compressorCmd to compressor.cmdIn;
        connect psaController.bedCmd to bed1.cmdIn;
        connect psaController.bedCmd to bed2.cmdIn;
        connect psaController.flowCmd to flowController.cmdIn;
        connect safetySystem.shutdownCmd to compressor.cmdIn;
        connect safetySystem.alarmOut to alarmInterface;

        // Requirement satisfaction
        satisfy OxygenPurityRequirement by oxygenSensor;
        satisfy FlowRateRequirement by flowController;
        satisfy SafetyRequirement by safetySystem;
        satisfy ContinuousSupplyRequirement by psaController;
    }
}
