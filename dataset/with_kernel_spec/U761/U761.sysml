package MADSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def MagneticFieldStrengthValue :> ISQ::MagneticFluxDensityValue;
	attribute def LatitudeValue :> Real;
	attribute def LongitudeValue :> Real;
	attribute def AltitudeValue :> ISQ::LengthValue;
	attribute def TimestampValue :> ISQ::TimeValue;
	attribute def DeviationValue :> ISQ::MagneticFluxDensityValue;

	item def RawMagneticData {
		attribute strength : MagneticFieldStrengthValue;
	}
	item def ConditionedMagneticData {
		attribute strength : MagneticFieldStrengthValue;
	}
	item def PositionData {
		attribute lat : LatitudeValue;
		attribute lon : LongitudeValue;
		attribute alt : AltitudeValue;
	}
	item def AnomalyRecord {
		attribute strength : MagneticFieldStrengthValue;
		attribute deviation : DeviationValue;
		attribute position : PositionData;
		attribute timestamp : TimestampValue;
	}
	item def DeactivateCommand;

	action def MeasureMagneticField { out raw : RawMagneticData; }
	action def ConditionSignal { in raw : RawMagneticData; out cond : ConditionedMagneticData; }
	action def TrackPosition { out pos : PositionData; }
	action def AnalyzeAnomaly {
		in cond : ConditionedMagneticData;
		in pos : PositionData;
		out rec : AnomalyRecord;
	}
	action def RecordAnomaly { in rec : AnomalyRecord; }

	part def Magnetometer {
		port magOut { out raw : RawMagneticData; }
		perform action measure : MeasureMagneticField;
	}
	part def SignalConditioner {
		port condIn { in raw : RawMagneticData; }
		port condOut { out cond : ConditionedMagneticData; }
		perform action condition : ConditionSignal;
	}
	part def PositionTracker {
		port posOut { out pos : PositionData; }
		perform action track : TrackPosition;
	}
	part def AnomalyAnalyzer {
		port analyzerIn { in cond : ConditionedMagneticData; }
		port posIn { in pos : PositionData; }
		port recOut { out rec : AnomalyRecord; }
		perform action analyze : AnalyzeAnomaly;
	}
	part def DataRecorder {
		port recIn { in rec : AnomalyRecord; }
		perform action record : RecordAnomaly;
	}

	state def MADOperationalStates {
		entry; then Measuring;

		state Measuring {
			do action measure : MeasureMagneticField;
			do action track : TrackPosition;
			then Conditioning;
		}
		state Conditioning {
			do action condition : ConditionSignal;
			then Analyzing;
		}
		state Analyzing {
			do action analyze : AnalyzeAnomaly;
			then Recording;
		}
		state Recording {
			do action record : RecordAnomaly;
			then Measuring;
		}

		accept deactivate : DeactivateCommand then Deactivated;

		state Deactivated {
			then done;
		}
	}

	part def MADSystem {
		port cmdIn { in cmd : DeactivateCommand; }

		part magnetometer : Magnetometer;
		part signalConditioner : SignalConditioner;
		part positionTracker : PositionTracker;
		part anomalyAnalyzer : AnomalyAnalyzer;
		part dataRecorder : DataRecorder;

		interface magToCond connect magnetometer.magOut to signalConditioner.condIn {
			flow magFlow of RawMagneticData from magnetometer.magOut.raw to signalConditioner.condIn.raw;
		}
		interface condToAnalyzer connect signalConditioner.condOut to anomalyAnalyzer.analyzerIn {
			flow condFlow of ConditionedMagneticData from signalConditioner.condOut.cond to anomalyAnalyzer.analyzerIn.cond;
		}
		interface posToAnalyzer connect positionTracker.posOut to anomalyAnalyzer.posIn {
			flow posFlow of PositionData from positionTracker.posOut.pos to anomalyAnalyzer.posIn.pos;
		}
		interface analyzerToRecorder connect anomalyAnalyzer.recOut to dataRecorder.recIn {
			flow recFlow of AnomalyRecord from anomalyAnalyzer.recOut.rec to dataRecorder.recIn.rec;
		}

		exhibit state operationalStates : MADOperationalStates;
	}

	requirement def DetectAnomalies {
		subject mad : MADSystem;
		doc "The MAD system shall detect localized disturbances in the Earth's magnetic field.";
	}
}
