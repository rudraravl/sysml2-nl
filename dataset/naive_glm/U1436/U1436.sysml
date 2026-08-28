package TurbofanEngineSystem {

    //=========================================================================
    // UNITS
    //=========================================================================
    unit N;
    unit kg;
    unit s;
    unit m;
    unit K;
    unit Pa;
    unit rpm;
    unit kg_per_s = kg / s;
    unit m_per_s = m / s;
    unit Nm = N * m;
    unit m3 = m * m * m;
    unit m3_per_s = m3 / s;
    unit J = N * m;
    unit g_per_kNs = kg / (N * s) / 1000;

    //=========================================================================
    // VALUE TYPES
    //=========================================================================
    value type Thrust :> Real { unit N; }
    value type MassFlowRate :> Real { unit kg_per_s; }
    value type Temperature :> Real { unit K; }
    value type Pressure :> Real { unit Pa; }
    value type RotationalSpeed :> Real { unit rpm; }
    value type FuelFlowRate :> Real { unit kg_per_s; }
    value type VolumeFlowRate :> Real { unit m3_per_s; }
    value type Velocity :> Real { unit m_per_s; }
    value type Torque :> Real { unit Nm; }
    value type Energy :> Real { unit J; }
    value type Area :> Real { unit m * m; }
    value type Length :> Real { unit m; }
    value type BypassRatio :> Real;
    value type PressureRatio :> Real;
    value type Efficiency :> Real;
    value type ThrottlePosition :> Real;

    //=========================================================================
    // ENUMERATIONS
    //=========================================================================
    enum def CommandType { start; shutdown; throttle; }
    enum def EngineState { off; starting; running; shutdown; }

    //=========================================================================
    // ITEMS
    //=========================================================================
    item def Air {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute massFlow : MassFlowRate;
        attribute humidity : Real;
    }

    item def CompressedAir :> Air {
        attribute compressionRatio : PressureRatio;
    }

    item def Fuel {
        attribute massFlow : FuelFlowRate;
        attribute energyDensity : Real;
        attribute temperature : Temperature;
    }

    item def FuelAirMixture {
        attribute air : CompressedAir;
        attribute fuel : Fuel;
        attribute fuelToAirRatio : Real;
    }

    item def ExhaustGas {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute massFlow : MassFlowRate;
        attribute velocity : Velocity;
    }

    item def ControlCommand {
        attribute commandType : CommandType;
        attribute throttleValue : ThrottlePosition;
    }

    item def SensorData {
        attribute thrustReading : Thrust;
        attribute speedReading : RotationalSpeed;
        attribute temperatureReading : Temperature;
        attribute pressureReading : Pressure;
    }

    //=========================================================================
    // PORT DEFINITIONS
    //=========================================================================
    port def AirInPort {
        in item air : Air;
    }

    port def AirOutPort {
        out item air : Air;
    }

    port def CompressedAirInPort {
        in item air : CompressedAir;
    }

    port def CompressedAirOutPort {
        out item air : CompressedAir;
    }

    port def FuelInPort {
        in item fuel : Fuel;
    }

    port def FuelOutPort {
        out item fuel : Fuel;
    }

    port def GasInPort {
        in item gas : ExhaustGas;
    }

    port def GasOutPort {
        out item gas : ExhaustGas;
    }

    port def MechInPort {
        in attribute speed : RotationalSpeed;
        in attribute torque : Torque;
    }

    port def MechOutPort {
        out attribute speed : RotationalSpeed;
        out attribute torque : Torque;
    }

    port def ControlInPort {
        in item command : ControlCommand;
    }

    port def ControlOutPort {
        out item command : ControlCommand;
    }

    port def SensorOutPort {
        out item data : SensorData;
    }

    port def SensorInPort {
        in item data : SensorData;
    }

    //=========================================================================
    // PART DEFINITIONS — COMPONENTS
    //=========================================================================

    part def AirIntake {
        port airIn : AirInPort;
        port airOut : AirOutPort;
        attribute intakeArea : Area = 1.2 [m * m];
        attribute capturedMassFlow : MassFlowRate;
        attribute bypassRatio : BypassRatio = 5.0;

        action def CaptureAir {
            in ambientAir : Air;
            out capturedAir : Air;
        }

        perform action capture : CaptureAir {
            in ambientAir = airIn.air;
            out capturedAir = airOut.air;
        }
    }

    part def Compressor {
        port airIn : AirInPort;
        port airOut : CompressedAirOutPort;
        port mechIn : MechInPort;
        attribute stageCount : Integer = 12;
        attribute compressionRatio : PressureRatio = 40.0;
        attribute outletPressure : Pressure;
        attribute outletTemperature : Temperature;
        attribute efficiency : Efficiency = 0.88;

        action def Compress {
            in inletAir : Air;
            in shaftSpeed : RotationalSpeed;
            in shaftTorque : Torque;
            out compressedAir : CompressedAir;
        }

        perform action compress : Compress {
            in inletAir = airIn.air;
            in shaftSpeed = mechIn.speed;
            in shaftTorque = mechIn.torque;
            out compressedAir = airOut.air;
        }
    }

    part def CombustionChamber {
        port airIn : CompressedAirInPort;
        port fuelIn : FuelInPort;
        port gasOut : GasOutPort;
        attribute combustionTemperature : Temperature = 1800 [K];
        attribute combustionPressure : Pressure;
        attribute efficiency : Efficiency = 0.99;
        attribute fuelToAirRatio : Real = 0.017;

        action def Combust {
            in compressedAir : CompressedAir;
            in fuel : Fuel;
            out exhaustGas : ExhaustGas;
        }

        perform action combust : Combust {
            in compressedAir = airIn.air;
            in fuel = fuelIn.fuel;
            out exhaustGas = gasOut.gas;
        }
    }

    part def Turbine {
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        port mechOut : MechOutPort;
        attribute stageCount : Integer = 6;
        attribute rotationalSpeed : RotationalSpeed;
        attribute extractedTorque : Torque;
        attribute inletTemperature : Temperature;
        attribute efficiency : Efficiency = 0.90;

        action def ExtractEnergy {
            in exhaustGas : ExhaustGas;
            out expandedGas : ExhaustGas;
            out shaftSpeed : RotationalSpeed;
            out shaftTorque : Torque;
        }

        perform action extract : ExtractEnergy {
            in exhaustGas = gasIn.gas;
            out expandedGas = gasOut.gas;
            out shaftSpeed = mechOut.speed;
            out shaftTorque = mechOut.torque;
        }
    }

    part def Shaft {
        port turbineEnd : MechInPort;
        port compressorEnd : MechOutPort;
        attribute length : Length = 2.5 [m];
        attribute maxSpeed : RotationalSpeed = 15000 [rpm];
        attribute currentSpeed : RotationalSpeed;
        attribute torsionalStiffness : Real;

        action def TransferPower {
            in turbineSpeed : RotationalSpeed;
            in turbineTorque : Torque;
            out compressorSpeed : RotationalSpeed;
            out compressorTorque : Torque;
        }

        perform action transfer : TransferPower {
            in turbineSpeed = turbineEnd.speed;
            in turbineTorque = turbineEnd.torque;
            out compressorSpeed = compressorEnd.speed;
            out compressorTorque = compressorEnd.torque;
        }
    }

    part def ExhaustNozzle {
        port gasIn : GasInPort;
        port gasOut : GasOutPort;
        attribute exitArea : Area = 0.8 [m * m];
        attribute exitVelocity : Velocity;
        attribute producedThrust : Thrust;
        attribute nozzlePressureRatio : PressureRatio;

        action def AccelerateGas {
            in exhaustGas : ExhaustGas;
            out acceleratedGas : ExhaustGas;
            out thrust : Thrust;
        }

        perform action accelerate : AccelerateGas {
            in exhaustGas = gasIn.gas;
            out acceleratedGas = gasOut.gas;
            out thrust = producedThrust;
        }
    }

    part def FuelSystem {
        port fuelOut : FuelOutPort;
        port controlIn : ControlInPort;
        port sensorIn : SensorInPort;
        attribute fuelCapacity : Real = 5000 [kg];
        attribute currentFlowRate : FuelFlowRate;
        attribute pumpPressure : Pressure;
        attribute valveOpen : Boolean;
        attribute fuelTemperature : Temperature = 300 [K];

        action def DeliverFuel {
            in command : ControlCommand;
            in sensorData : SensorData;
            out fuel : Fuel;
        }

        perform action deliver : DeliverFuel {
            in command = controlIn.command;
            in sensorData = sensorIn.data;
            out fuel = fuelOut.fuel;
        }
    }

    part def ControlSystem {
        port commandIn : ControlInPort;
        port controlOut : ControlOutPort;
        port sensorIn : SensorInPort;
        attribute throttleSetting : ThrottlePosition;
        attribute targetThrust : Thrust;
        attribute currentThrust : Thrust;
        attribute maxThrustLimit : Thrust = 120000 [N];
        attribute minThrustLimit : Thrust = 0 [N];
        attribute pidGainProportional : Real = 1.5;
        attribute pidGainIntegral : Real = 0.8;

        action def ProcessCommand {
            in command : ControlCommand;
            in sensorData : SensorData;
            out fuelCommand : ControlCommand;
        }

        perform action process : ProcessCommand {
            in command = commandIn.command;
            in sensorData = sensorIn.data;
            out fuelCommand = controlOut.command;
        }
    }

    part def SensorSuite {
        port dataOut : SensorOutPort;
        attribute thrustSensorRange : Thrust = 150000 [N];
        attribute speedSensorRange : RotationalSpeed = 20000 [rpm];
        attribute tempSensorRange : Temperature = 2500 [K];

        action def ReadSensors {
            out data : SensorData;
        }

        perform action read : ReadSensors {
            out data = dataOut.data;
        }
    }

    //=========================================================================
    // STATE MACHINE DEFINITION
    //=========================================================================
    state def EngineLifecycle {
        entry; then off;

        attribute currentCommand : ControlCommand;
        attribute shaftSpeed : RotationalSpeed;

        state off {
            entry action { /* engine is stationary, no fuel flow */ }
            do action { /* monitor for start command */ }
            exit action { /* acknowledge start request */ }
        }

        transition from off to starting
            when currentCommand.commandType == CommandType::start;

        state starting {
            entry action { /* energize ignition system */ }
            do action { /* spool up compressor, begin fuel injection, ignite mixture */ }
            exit action { /* confirm stable combustion and self-sustaining rotation */ }
        }

        transition from starting to running
            when shaftSpeed > 5000 [rpm];

        transition from starting to off
            when shaftSpeed < 100 [rpm] && currentCommand.commandType == CommandType::shutdown;

        state running {
            entry action { /* engage full thrust control loop */ }
            do action { /* maintain combustion, regulate fuel flow, produce thrust */ }
            exit action { /* begin fuel reduction */ }
        }

        transition from running to shutdown
            when currentCommand.commandType == CommandType::shutdown;

        state shutdown {
            entry action { /* cut main fuel supply */ }
            do action { /* allow controlled spool down, cool turbine */ }
            exit action { /* confirm safe zero-speed state */ }
        }

        transition from shutdown to off
            when shaftSpeed < 100 [rpm];
    }

    //=========================================================================
    // MAIN ENGINE PART DEFINITION
    //=========================================================================
    part def TurbofanEngine {
        port airIntakePort : AirInPort;
        port exhaustPort : GasOutPort;
        port commandPort : ControlInPort;

        attribute maxThrust : Thrust = 120000 [N];
        attribute bypassRatio : BypassRatio = 5.0;
        attribute overallPressureRatio : PressureRatio = 40.0;
        attribute fuelEfficiency : Real;
        attribute currentThrust : Thrust;
        attribute currentCommand : ControlCommand;
        attribute engineState : EngineState;
        attribute dryWeight : Real = 3500 [kg];
        attribute length : Length = 4.0 [m];
        attribute diameter : Real = 2.0 [m];

        part intake : AirIntake;
        part compressor : Compressor;
        part combustionChamber : CombustionChamber;
        part turbine : Turbine;
        part shaft : Shaft;
        part exhaustNozzle : ExhaustNozzle;
        part fuelSystem : FuelSystem;
        part controlSystem : ControlSystem;
        part sensorSuite : SensorSuite;

        // Air flow connections
        connection airIntakePort to intake.airIn;
        connection intake.airOut to compressor.airIn;
        connection compressor.airOut to combustionChamber.airIn;

        // Fuel flow connections
        connection fuelSystem.fuelOut to combustionChamber.fuelIn;

        // Gas flow connections
        connection combustionChamber.gasOut to turbine.gasIn;
        connection turbine.gasOut to exhaustNozzle.gasIn;
        connection exhaustNozzle.gasOut to exhaustPort;

        // Mechanical power transfer
        connection turbine.mechOut to shaft.turbineEnd;
        connection shaft.compressorEnd to compressor.mechIn;

        // Control signal connections
        connection commandPort to controlSystem.commandIn;
        connection controlSystem.controlOut to fuelSystem.controlIn;

        // Sensor data connections
        connection sensorSuite.dataOut to controlSystem.sensorIn;
        connection sensorSuite.dataOut to fuelSystem.sensorIn;

        // Exhibit state machine
        exhibit EngineLifecycle {
            bind currentCommand = self.currentCommand;
            bind shaftSpeed = self.shaft.currentSpeed;
        }

        // Overall thrust generation action
        action def GenerateThrust {
            in ambientAir : Air;
            in fuel : Fuel;
            out thrust : Thrust;
            out exhaust : ExhaustGas;
        }

        perform action generateThrust : GenerateThrust {
            in ambientAir = airIntakePort.air;
            out thrust = currentThrust;
            out exhaust = exhaustPort.gas;
        }
    }

    //=========================================================================
    // REQUIREMENTS
    //=========================================================================
    requirement def ThrustRequirement {
        attribute minThrust : Thrust = 100000 [N];
        subject engine : TurbofanEngine;
        require engine.maxThrust >= minThrust;
        doc /* The engine shall produce a minimum thrust of 100,000 N. */
    }

    requirement def FuelEfficiencyRequirement {
        attribute maxSpecificFuelConsumption : Real = 0.03 [kg / (N * s)];
        subject engine : TurbofanEngine;
        require engine.fuelEfficiency <= maxSpecificFuelConsumption;
        doc /* The engine shall maintain high fuel efficiency under various operational conditions. */
    }

    requirement def LifecycleRequirement {
        subject engine : TurbofanEngine;
        require engine exhibits EngineLifecycle;
        doc /* The engine shall follow a defined lifecycle: off, starting, running, shutdown. */
    }

    requirement def OperationalRangeRequirement {
        attribute minAmbientTemp : Temperature = 216 [K];
        attribute maxAmbientTemp : Temperature = 323 [K];
        attribute maxAltitude : Real = 12000 [m];
        subject engine : TurbofanEngine;
        require engine.currentThrust >= 0 [N];
        require engine.currentThrust <= engine.maxThrust;
        doc /* The engine shall operate across a range of ambient conditions. */
    }

    requirement def StartSequenceRequirement {
        subject engine : TurbofanEngine;
        require engine exhibits EngineLifecycle;
        doc /* The starting sequence shall involve ignition and compressor spool-up before transitioning to running. */
    }

    requirement def ContinuousOperationRequirement {
        subject engine : TurbofanEngine;
        require engine.currentThrust >= 100000 [N];
        doc /* During running state, the engine shall produce sustained thrust exceeding 100,000 N. */
    }

    //=========================================================================
    // ENGINE INSTANCE AND SATISFACTION
    //=========================================================================
    part engineInstance : TurbofanEngine {
        attribute maxThrust = 120000 [N];
        attribute bypassRatio = 5.0;
        attribute overallPressureRatio = 40.0;
    }

    satisfy ThrustRequirement by engineInstance;
    satisfy FuelEfficiencyRequirement by engineInstance;
    satisfy LifecycleRequirement by engineInstance;
    satisfy OperationalRangeRequirement by engineInstance;
    satisfy StartSequenceRequirement by engineInstance;
    satisfy ContinuousOperationRequirement by engineInstance;
}
