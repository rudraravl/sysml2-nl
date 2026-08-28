package ElectronicNoseSystem {
    private import SI::s;
    private import SI::ohm;
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;

    item def AirSample {
        attribute volume : Real;
    }

    item def RawSensorData {
        attribute resistances : ohm[16];
    }

    item def ConditionedData {
        attribute normalizedPattern : Real[16];
    }

    item def OdorResult {
        attribute category : String;
        attribute compounds : String[*];
        attribute confidence : Real;
    }

    port def AirOutPort {
        out item sample : AirSample;
    }

    port def AirInPort {
        in item sample : AirSample;
    }

    port def RawDataOutPort {
        out item rawData : RawSensorData;
    }

    port def RawDataInPort {
        in item rawData : RawSensorData;
    }

    port def CondDataOutPort {
        out item conditionedData : ConditionedData;
    }

    port def CondDataInPort {
        in item conditionedData : ConditionedData;
    }

    port def ResultOutPort {
        out item result : OdorResult;
    }

    port def ResultInPort {
        in item result : OdorResult;
    }

    part def Pump {
        in port airIntake : AirInPort;
        out port airExhaust : AirOutPort;
        attribute flowRate : Real;
    }

    part def ParticleFilter {
        in port dirtyAirIn : AirInPort;
        out port cleanAirOut : AirOutPort;
        attribute efficiency : Real;
    }

    part def AirSamplingUnit {
        in port ambientIntake : AirInPort;
        out port sampleOut : AirOutPort;
        part pump : Pump;
        part particleFilter : ParticleFilter;
        connect ambientIntake to particleFilter.dirtyAirIn;
        connect particleFilter.cleanAirOut to pump.airIntake;
        connect pump.airExhaust to sampleOut;
    }

    part def ChemicalSensor {
        attribute resistance : ohm;
        attribute sensorType : String;
    }

    part def MetalOxideSensor :> ChemicalSensor {
        :>> sensorType = "metal-oxide";
    }

    part def ConductivePolymerSensor :> ChemicalSensor {
        :>> sensorType = "conductive-polymer";
    }

    part def SensorArray {
        in port sampleIn : AirInPort;
        out port rawDataOut : RawDataOutPort;
        part metalOxideSensors : MetalOxideSensor[8];
        part conductivePolymerSensors : ConductivePolymerSensor[8];
    }

    part def SignalConditioner {
        in port rawDataIn : RawDataInPort;
        out port conditionedDataOut : CondDataOutPort;
        attribute gain : Real;
        attribute noiseThreshold : Real;
    }

    part def PatternRecognitionModule {
        in port conditionedDataIn : CondDataInPort;
        out port resultOut : ResultOutPort;
        attribute librarySize : Integer;
        attribute nnWeights : Real[*];
    }

    part def UserInterface {
        in port resultIn : ResultInPort;
    }

    part def ElectronicNose {
        part airSamplingUnit : AirSamplingUnit;
        part sensorArray : SensorArray;
        part signalConditioner : SignalConditioner;
        part patternRecognitionModule : PatternRecognitionModule;
        part userInterface : UserInterface;

        connect airSamplingUnit.sampleOut to sensorArray.sampleIn;
        connect sensorArray.rawDataOut to signalConditioner.rawDataIn;
        connect signalConditioner.conditionedDataOut to patternRecognitionModule.conditionedDataIn;
        connect patternRecognitionModule.resultOut to userInterface.resultIn;

        attribute maxProcessingTime : Real = 30 [s];

        state def OperationalStates {
            state Idle;
            state Sampling;
            state Processing;
            state Displaying;
            transition initial to Idle;
            transition from Idle to Sampling;
            transition from Sampling to Processing;
            transition from Processing to Displaying;
            transition from Displaying to Idle;
        }

        perform OperationalStates;
    }

    requirement def ProcessTimeRequirement {
        attribute maxTime : Real = 30 [s];
        subject electronicNose : ElectronicNose;
        constraint { electronicNose.maxProcessingTime <= maxTime }
    }

    requirement def DetectionRequirement {
        subject electronicNose : ElectronicNose;
        constraint { electronicNose.patternRecognitionModule.resultOut.result.confidence > 0.8 }
    }
}
