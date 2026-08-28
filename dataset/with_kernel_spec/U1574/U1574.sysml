package TouchSensingUnit {
    private import SI::*;
    private import ScalarValues::*;
    private import ISQ::*;

    value def CapacitanceValue :> Real {
        unit :> F;
    }

    item def RawSensorData {
        attribute capacitance : CapacitanceValue;
        attribute force : ISQ::ForceValue;
    }

    item def ConditionedData {
        attribute filteredForce : ISQ::ForceValue;
        attribute filteredCapacitance : CapacitanceValue;
    }

    item def DigitizedData {
        attribute force : ISQ::ForceValue;
        attribute capacitance : CapacitanceValue;
        attribute timestamp : ISQ::TimeValue;
    }

    enum def TouchIntensity {
        noContact;
        lightTouch;
        firmTouch;
        heavyTouch;
    }

    item def DataPacket {
        attribute force : ISQ::ForceValue;
        attribute capacitance : CapacitanceValue;
        attribute timestamp : ISQ::TimeValue;
        attribute intensity : TouchIntensity;
    }

    port def RawSensorOut {
        out item raw : RawSensorData;
    }

    port def RawSensorIn {
        in item raw : RawSensorData;
    }

    port def ConditionedOut {
        out item cond : ConditionedData;
    }

    port def ConditionedIn {
        in item cond : ConditionedData;
    }

    port def PacketOut {
        out item packet : DataPacket;
    }

    part def TouchSensor {
        out port rawOut : RawSensorOut;

        action def GenerateRawData {
            out data : RawSensorData;
        }

        state def SensorStates {
            state idle;
            state active {
                do action generateRawData : GenerateRawData;
            }
            transition toActive first idle accept StartCmd then active;
            transition toIdle first active accept StopCmd then idle;
        }
        state sensorBehavior : SensorStates;
    }

    part def SignalConditioner {
        in port rawIn : RawSensorIn;
        out port conditionedOut : ConditionedOut;

        action def ConditionSignal {
            in raw : RawSensorData;
            out conditioned : ConditionedData;
        }
        action conditionSignal : ConditionSignal;
    }

    part def DataAcquisitionUnit {
        in port conditionedIn : ConditionedIn;
        out port packetOut : PacketOut;

        action def AcquireData {
            in cond : ConditionedData;
            out packet : DataPacket;
        }
        action acquireData : AcquireData;
    }

    part def TouchSensingSystem {
        attribute accuracy : Real = 0.02;
        attribute samplingRate : Real = 50;
        attribute maxForce : ISQ::ForceValue = 10.0 [N];

        part touchSensor : TouchSensor;
        part signalConditioner : SignalConditioner;
        part dataAcquisitionUnit : DataAcquisitionUnit;

        connect touchSensor.rawOut to signalConditioner.rawIn;
        connect signalConditioner.conditionedOut to dataAcquisitionUnit.conditionedIn;

        state def SystemBehavior {
            state parallel {
                state sensorOp :> touchSensor.sensorBehavior;
                state condOp { do action signalConditioner.conditionSignal; }
                state daqOp { do action dataAcquisitionUnit.acquireData; }
            }
        }
    }

    part touchSensingSystem : TouchSensingSystem;

    requirement forceRangeRequirement {
        subject unit : TouchSensingSystem;
        require constraint { unit.maxForce <= 10.0 [N] }
    }

    requirement accuracyRequirement {
        subject unit : TouchSensingSystem;
        require constraint { unit.accuracy <= 0.02 }
    }

    requirement samplingRateRequirement {
        subject unit : TouchSensingSystem;
        require constraint { unit.samplingRate >= 50 }
    }

    satisfy forceRangeRequirement by touchSensingSystem;
    satisfy accuracyRequirement by touchSensingSystem;
    satisfy samplingRateRequirement by touchSensingSystem;
}
