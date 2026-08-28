package ThermalMonitoringSystem {
    private import ScalarValues::*;
    private import SequenceFunctions::*;
    private import ControlFunctions::*;

    attribute def TemperatureValue :> Real;
    attribute def TimeValue :> Real;

    attribute def Coordinate {
        x : Natural;
        y : Natural;
    }

    item def RawReading {
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
        attribute sensorId : Natural;
    }

    item def ProcessedReading {
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
        attribute coordinate : Coordinate;
        attribute isValid : Boolean;
    }

    item def AggregatedPacket {
        attribute timestamp : TimeValue;
        attribute avgTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
        attribute minTemp : TemperatureValue;
        attribute variance : Real;
        attribute activeSensors : Natural;
    }

    port def RawTempPort {
        out reading : RawReading;
    }

    port def ProcessedTempPort {
        out reading : ProcessedReading;
    }

    port def AggregatedDataPort {
        out packet : AggregatedPacket;
    }

    attribute def Activate;
    attribute def Fault;
    attribute def Recovered;

    action def SenseAction {
        in sensorId : Natural;
        in offset : TemperatureValue;
        out r : RawReading;
        first start;
        then assign r.timestamp := 0;
        then assign r.temperature := 25 + offset;
        then assign r.sensorId := sensorId;
        then done;
    }

    action def RecoverAction;

    action def ProcessAction {
        in raw : RawReading;
        in offset : TemperatureValue;
        in coord : Coordinate;
        out proc : ProcessedReading;
        first start;
        then assign proc.timestamp := raw.timestamp;
        then assign proc.temperature := raw.temperature + offset;
        then assign proc.coordinate := coord;
        then assign proc.isValid := raw.temperature > 0;
        then done;
    }

    action def AggregateAction {
        in readings : ProcessedReading[*];
        out packet : AggregatedPacket;

        attribute validReadings : ProcessedReading[*] =
            readings -> select { in r : ProcessedReading; r.isValid };
        attribute temps : TemperatureValue[*] =
            validReadings -> collect { in r : ProcessedReading; r.temperature };
        attribute count : Natural = temps->size();
        attribute sum : TemperatureValue =
            temps -> reduce { in x : TemperatureValue; in y : TemperatureValue; x + y };
        attribute mean : TemperatureValue = sum / count;
        attribute sqDiffs : Real[*] =
            temps -> collect { in t : TemperatureValue; (t - mean) * (t - mean) };

        first start;
        then assign packet.activeSensors := count;
        then assign packet.avgTemp := mean;
        then assign packet.maxTemp :=
            temps -> reduce { in x : TemperatureValue; in y : TemperatureValue; if x > y then x else y };
        then assign packet.minTemp :=
            temps -> reduce { in x : TemperatureValue; in y : TemperatureValue; if x < y then x else y };
        then assign packet.variance :=
            sqDiffs -> reduce { in x : Real; in y : Real; x + y } / count;
        then assign packet.timestamp := 0;
        then done;
    }

    part def TemperatureSensor {
        attribute id : Natural;
        attribute calibrationOffset : TemperatureValue;
        port rawOut : RawTempPort;

        action sense : SenseAction {
            in sensorId = id;
            in offset = calibrationOffset;
            flow r to rawOut.reading;
        }

        state sensorLifecycle {
            entry; then standby;
            state standby;
            state sensing {
                do sense;
            }
            state fault {
                do action recover : RecoverAction;
            }
            transition first standby accept Activate then sensing;
            transition first sensing accept Fault then fault;
            transition first fault accept Recovered then standby;
        }
    }

    part def SignalProcessor {
        attribute coordinate : Coordinate;
        attribute calibrationOffset : TemperatureValue;
        port rawIn : ~RawTempPort;
        port procOut : ProcessedTempPort;

        action process : ProcessAction {
            in raw = rawIn.reading;
            in offset = calibrationOffset;
            in coord = coordinate;
            flow proc to procOut.reading;
        }
    }

    part def DataAggregator {
        port procIn : ~ProcessedTempPort[16];
        port aggOut : AggregatedDataPort;

        action aggregate : AggregateAction {
            in readings = procIn.reading;
            flow packet to aggOut.packet;
        }
    }

    part def ThermalGridUnit {
        part sensors : TemperatureSensor[16];
        part processors : SignalProcessor[16];
        part aggregator : DataAggregator;

        connection sensorToProcessor connect sensors.rawOut to processors.rawIn;
        connection processorToAggregator connect processors.procOut to aggregator.procIn;
    }

    requirement def FaultToleranceRequirement {
        doc /* The system shall continue to operate and provide valid aggregated statistics even if up to 4 sensors are in a fault state. */
        subject unit : ThermalGridUnit;
        require constraint {
            unit.aggregator.aggregate.packet.activeSensors >= 12
        }
    }

    requirement def OutputFrequencyRequirement {
        doc /* The system shall output aggregated data packets at a frequency of 10 Hz. */
        subject unit : ThermalGridUnit;
        attribute outputRate : Real = 10;
        require constraint {
            outputRate == 10
        }
    }
}
