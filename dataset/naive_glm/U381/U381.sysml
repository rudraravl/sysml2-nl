package SensitiveSkinSystem {
    import ScalarValues::*;

    // ============================================================
    // Unit Definitions
    // ============================================================
    unit Pa;
    unit degC;
    unit N;
    unit mm2;
    unit ms;
    unit V;
    unit A;

    // ============================================================
    // Value Types
    // ============================================================
    value type PressureValue :> Real { unit Pa; }
    value type TemperatureValue :> Real { unit degC; }
    value type ForceValue :> Real { unit N; }
    value type AreaValue :> Real { unit mm2; }
    value type TimeDurationValue :> Real { unit ms; }
    value type VoltageValue :> Real { unit V; }
    value type CurrentValue :> Real { unit A; }

    value type GridIndex :> Integer {
        constraint { self >= 0 and self <= 7; }
    }

    enumeration def AlertLevel {
        none = 0;
        warning = 1;
        critical = 2;
    }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def RawSensorData {
        attribute row : GridIndex;
        attribute col : GridIndex;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute timestamp : TimeDurationValue;
    }

    item def TouchEventData {
        attribute contactMade : Boolean;
        attribute totalForce : ForceValue;
        attribute contactArea : AreaValue;
        attribute surfaceTemperature : TemperatureValue;
        attribute centerRow : GridIndex;
        attribute centerCol : GridIndex;
    }

    item def ResponseSignal {
        attribute alert : AlertLevel;
        attribute row : GridIndex;
        attribute col : GridIndex;
        attribute detectedForce : ForceValue;
        attribute detectedTemperature : TemperatureValue;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    port def RawDataStreamPort {
        out item raw : RawSensorData;
    }

    port def TouchEventStreamPort {
        out item event : TouchEventData;
    }

    port def ResponseStreamPort {
        out item response : ResponseSignal;
    }

    // ============================================================
    // Component Definitions
    // ============================================================
    part def SkinSubstrate {
        attribute material : String = "flexible silicone";
        attribute gridRows : Integer = 8;
        attribute gridCols : Integer = 8;
        attribute thickness : Real = 2.0;
        attribute operatingTempMin : TemperatureValue = -20 [degC];
        attribute operatingTempMax : TemperatureValue = 100 [degC];
        port powerIn : PowerPort;
    }

    part def TactileSensorCell {
        attribute rowIndex : GridIndex;
        attribute colIndex : GridIndex;
        attribute pressureReading : PressureValue;
        attribute temperatureReading : TemperatureValue;

        port powerIn : PowerPort;
        port rawOut : RawDataStreamPort;

        action def SenseTouch {
            in pVal : PressureValue;
            in tVal : TemperatureValue;
            out raw : RawSensorData;
        }

        perform SenseTouch;

        state machine SensingLifecycle {
            state Idle;
            state Sampling;
            state Emitting;

            initial -> Idle;
            transition Idle -> Sampling when powerIn.voltage > 0;
            transition Sampling -> Emitting when sampleReady;
            transition Emitting -> Idle when rawOut.raw sent;
        }
    }

    part def SensorArray {
        attribute gridRows : Integer = 8;
        attribute gridCols : Integer = 8;
        attribute cellCount : Integer = 64;

        part cells[64] : TactileSensorCell;

        port powerIn : PowerPort;
        port arrayOut : RawDataStreamPort;

        flow powerFromInput from powerIn to cells.powerIn;
        flow rawAggregation from cells.rawOut to arrayOut;
    }

    part def SignalProcessingUnit {
        port powerIn : PowerPort;
        port rawIn : RawDataStreamPort;
        port eventOut : TouchEventStreamPort;

        attribute noiseThreshold : PressureValue = 5 [Pa];
        attribute contactPressureThreshold : PressureValue = 50 [Pa];
        attribute maxProcessTime : TimeDurationValue = 10 [ms];

        attribute lastRawBatch : RawSensorData[0..*];
        attribute lastEvent : TouchEventData;

        action def FilterNoise {
            in raw : RawSensorData;
            out filtered : RawSensorData;
        }

        action def AnalyzeContact {
            in batch : RawSensorData[0..*];
            out event : TouchEventData;
        }

        perform FilterNoise;
        perform AnalyzeContact;

        state machine ProcessingLifecycle {
            state Idle;
            state Filtering;
            state Analyzing;
            state Dispatching;

            initial -> Idle;
            transition Idle -> Filtering when rawIn.raw received;
            transition Filtering -> Analyzing when filteringComplete;
            transition Analyzing -> Dispatching when analysisComplete;
            transition Dispatching -> Idle when eventOut.event sent;
        }
    }

    part def ResponseController {
        port powerIn : PowerPort;
        port eventIn : TouchEventStreamPort;
        port responseOut : ResponseStreamPort;

        attribute maxSafeForce : ForceValue = 10 [N];
        attribute maxSafeTemperature : TemperatureValue = 60 [degC];
        attribute maxEvaluateTime : TimeDurationValue = 5 [ms];

        attribute lastEvent : TouchEventData;
        attribute lastResponse : ResponseSignal;

        action def EvaluateEvent {
            in event : TouchEventData;
            out response : ResponseSignal;
        }

        action def DetermineAlert {
            in force : ForceValue;
            in temp : TemperatureValue;
            out alert : AlertLevel;
        }

        perform EvaluateEvent;
        perform DetermineAlert;

        state machine ControlLifecycle {
            state Idle;
            state Evaluating;
            state GeneratingResponse;

            initial -> Idle;
            transition Idle -> Evaluating when eventIn.event received;
            transition Evaluating -> GeneratingResponse when evaluationComplete;
            transition GeneratingResponse -> Idle when responseOut.response sent;
        }
    }

    part def PowerSupply {
        attribute nominalVoltage : VoltageValue = 5 [V];
        attribute maxCurrent : CurrentValue = 2 [A];
        attribute operatingTempMin : TemperatureValue = -20 [degC];
        attribute operatingTempMax : TemperatureValue = 100 [degC];
        port powerOut : PowerPort;
    }

    // ============================================================
    // Top-Level Assembly
    // ============================================================
    part def SensitiveSkinSystem {
        attribute gridRows : Integer = 8;
        attribute gridCols : Integer = 8;
        attribute operatingTempMin : TemperatureValue = -20 [degC];
        attribute operatingTempMax : TemperatureValue = 100 [degC];
        attribute maxResponseTime : TimeDurationValue = 20 [ms];

        port responseOut : ResponseStreamPort;

        part skin : SkinSubstrate;
        part sensorArray : SensorArray;
        part signalProcessor : SignalProcessingUnit;
        part responseController : ResponseController;
        part power : PowerSupply;

        // Power distribution
        connection from power.powerOut to sensorArray.powerIn;
        connection from power.powerOut to signalProcessor.powerIn;
        connection from power.powerOut to responseController.powerIn;
        connection from power.powerOut to skin.powerIn;

        // Data flow
        connection from sensorArray.arrayOut to signalProcessor.rawIn;
        connection from signalProcessor.eventOut to responseController.eventIn;
        connection from responseController.responseOut to responseOut;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def SensorGridRequirement {
        subject array : SensorArray;
        doc { The skin shall contain an 8x8 grid of 64 tactile sensor cells. }
        constraint { array.cellCount == 64; }
        constraint { array.gridRows == 8; }
        constraint { array.gridCols == 8; }
    }

    requirement def PerCellMeasurementRequirement {
        subject cell : TactileSensorCell;
        doc { Each cell shall independently measure both pressure and temperature at its location. }
        attribute pressureRangeMin : PressureValue = 0 [Pa];
        attribute pressureRangeMax : PressureValue = 100000 [Pa];
        attribute tempRangeMin : TemperatureValue = -20 [degC];
        attribute tempRangeMax : TemperatureValue = 100 [degC];
    }

    requirement def SignalProcessingRequirement {
        subject spu : SignalProcessingUnit;
        doc { The SPU shall filter noise and analyze contact, force, contact area, and surface temperature. }
    }

    requirement def ResponseControllerRequirement {
        subject rc : ResponseController;
        doc { The controller shall compare contact against safety thresholds for force and temperature and emit a response signal with alert level and event location. }
    }

    requirement def LatencyRequirement {
        subject system : SensitiveSkinSystem;
        doc { The system shall process a touch event and generate a response in under 20 ms. }
        constraint { system.maxResponseTime <= 20 [ms]; }
    }

    requirement def OperatingTemperatureRequirement {
        subject system : SensitiveSkinSystem;
        doc { The system shall operate reliably from -20 degC to 100 degC. }
        constraint { system.operatingTempMin <= -20 [degC]; }
        constraint { system.operatingTempMax >= 100 [degC]; }
    }

    requirement def PowerSupplyRequirement {
        subject psu : PowerSupply;
        doc { A dedicated power supply shall power all components of the system. }
    }

    requirement def SensitiveSkinSystemRequirement {
        subject system : SensitiveSkinSystem;
        doc { The system shall provide a machine with a human-like sense of touch by continuously monitoring its surface, understanding physical interactions, and reacting intelligently to its environment. }

        requirement GridReq : SensorGridRequirement {
            subject array : SensorArray = system.sensorArray;
        }

        requirement CellReq : PerCellMeasurementRequirement {
            subject cell : TactileSensorCell = system.sensorArray.cells;
        }

        requirement SPUReq : SignalProcessingRequirement {
            subject spu : SignalProcessingUnit = system.signalProcessor;
        }

        requirement RCReq : ResponseControllerRequirement {
            subject rc : ResponseController = system.responseController;
        }

        requirement LatReq : LatencyRequirement {
            subject system : SensitiveSkinSystem = system;
        }

        requirement OpTempReq : OperatingTemperatureRequirement {
            subject system : SensitiveSkinSystem = system;
        }

        requirement PowerReq : PowerSupplyRequirement {
            subject psu : PowerSupply = system.power;
        }
    }

    // ============================================================
    // Satisfactions
    // ============================================================
    satisfy SensorGridRequirement by sensorArray;
    satisfy PerCellMeasurementRequirement by TactileSensorCell;
    satisfy SignalProcessingRequirement by signalProcessor;
    satisfy ResponseControllerRequirement by responseController;
    satisfy LatencyRequirement by system;
    satisfy OperatingTemperatureRequirement by system;
    satisfy PowerSupplyRequirement by power;
}
