package MAD_System {
    import ScalarValues::Real;
    import ScalarValues::Boolean;
    import ScalarValues::String;

    // Value Types
    value def MagneticFluxDensity :> Real { unit 'nT'; }
    value def Latitude :> Real { unit 'deg'; }
    value def Longitude :> Real { unit 'deg'; }
    value def Altitude :> Real { unit 'm'; }
    value def Deviation :> Real { unit 'nT'; }
    value def TimeStamp :> String;

    // Item Types
    item def RawMagneticData {
        value fieldStrength : MagneticFluxDensity;
    }
    item def CleanedMagneticData {
        value fieldStrength : MagneticFluxDensity;
    }
    item def PositionData {
        value lat : Latitude;
        value lon : Longitude;
        value alt : Altitude;
    }
    item def AnomalyRecord {
        value fieldStrength : MagneticFluxDensity;
        value deviation : Deviation;
        value position : PositionData;
        value timestamp : TimeStamp;
    }
    item def AnomalyLog {
        item records : AnomalyRecord[0..*];
    }

    // Action Definitions
    action def MeasureMagneticField {
        out rawField : RawMagneticData;
    }
    action def ConditionSignal {
        in rawField : RawMagneticData;
        out cleanedField : CleanedMagneticData;
    }
    action def TrackPosition {
        out position : PositionData;
    }
    action def AnalyzeAnomaly {
        in cleanedField : CleanedMagneticData;
        in position : PositionData;
        out anomalyRecord : AnomalyRecord;
    }
    action def RecordAnomaly {
        in anomalyRecord : AnomalyRecord;
        out log : AnomalyLog;
    }
    action def StartCycle { }
    action def ContinuousCycle { }
    action def OutputLog {
        out systemLog : AnomalyLog;
    }

    // Parts
    part def Magnetometer {
        out rawField : RawMagneticData;
        action measure : MeasureMagneticField;
    }

    part def SignalConditioner {
        in rawField : RawMagneticData;
        out cleanedField : CleanedMagneticData;
        action condition : ConditionSignal;
    }

    part def PositionTracker {
        out position : PositionData;
        action track : TrackPosition;
    }

    part def AnomalyAnalyzer {
        in cleanedField : CleanedMagneticData;
        in position : PositionData;
        out anomalyRecord : AnomalyRecord;
        attribute threshold : Deviation = 5.0;
        action analyze : AnalyzeAnomaly;
    }

    part def DataRecorder {
        in anomalyRecord : AnomalyRecord;
        out log : AnomalyLog;
        action record : RecordAnomaly;
    }

    part def MADSystem {
        part magnetometer : Magnetometer;
        part signalConditioner : SignalConditioner;
        part positionTracker : PositionTracker;
        part anomalyAnalyzer : AnomalyAnalyzer;
        part dataRecorder : DataRecorder;

        connection magnetometer.rawField to signalConditioner.rawField;
        connection signalConditioner.cleanedField to anomalyAnalyzer.cleanedField;
        connection positionTracker.position to anomalyAnalyzer.position;
        connection anomalyAnalyzer.anomalyRecord to dataRecorder.anomalyRecord;

        port in deactivateCmd : Boolean;
        port out systemLog : AnomalyLog;

        state def OperationalStates {
            state Active {
                entry action startCycle : StartCycle;
                do action continuousCycle : ContinuousCycle;
            }
            state Deactivated {
                entry action outputLog : OutputLog;
            }
            transition initial to Active;
            transition from Active to Deactivated on deactivateCmd;
        }
    }

    // Requirements
    requirement def DetectMagneticAnomalies {
        subject madSystem : MADSystem;
        objective {
            doc /* The system shall detect localized disturbances in the Earth's magnetic field. */
        }
    }
}
