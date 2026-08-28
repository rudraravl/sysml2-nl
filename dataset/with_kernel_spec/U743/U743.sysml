package LaserRangefinderSystem {
    private import ScalarValues::*;

    attribute def Length :> Real;
    attribute def Duration :> Real;
    attribute def Frequency :> Real;
    attribute def Temperature :> Real;

    item def LaserPulse {
        attribute wavelength : Length = 905e-9;
    }
    item def Reflection;
    item def DetectionSignal;
    item def TimeOfFlightData {
        attribute timeOfFlight : Duration;
    }
    item def DistanceData {
        attribute distance : Length;
        attribute isValid : Boolean;
    }
    item def Power {
        attribute voltage : Real = 3.3;
    }

    port def LaserPulseOutPort { out item pulse : LaserPulse; }
    port def LaserPulseInPort { in item pulse : LaserPulse; }
    port def ReflectionOutPort { out item refl : Reflection; }
    port def ReflectionInPort { in item refl : Reflection; }
    port def DetectionOutPort { out item det : DetectionSignal; }
    port def DetectionInPort { in item det : DetectionSignal; }
    port def TimeDataOutPort { out item td : TimeOfFlightData; }
    port def TimeDataInPort { in item td : TimeOfFlightData; }
    port def DistanceOutPort { out item dd : DistanceData; }
    port def DistanceInPort { in item dd : DistanceData; }
    port def PowerOutPort { out item pwr : Power; }
    port def PowerInPort { in item pwr : Power; }

    part def LaserEmitter {
        port pulseOut : LaserPulseOutPort;
        port powerIn : PowerInPort;
        attribute wavelength : Length = 905e-9;
        action emitPulse {
            send new LaserPulse() via pulseOut;
        }
    }

    part def OpticalReceiver {
        port reflectionIn : ReflectionInPort;
        port detectionOut : DetectionOutPort;
        port powerIn : PowerInPort;
        action detectReflection {
            accept Reflection via reflectionIn;
            then send new DetectionSignal() via detectionOut;
        }
    }

    part def TimingCircuit {
        port startIn : LaserPulseInPort;
        port stopIn : DetectionInPort;
        port timeDataOut : TimeDataOutPort;
        port powerIn : PowerInPort;
        attribute resolution : Duration = 1e-9;
        action measureTime {
            accept LaserPulse via startIn;
            then accept DetectionSignal via stopIn;
            then send new TimeOfFlightData() via timeDataOut;
        }
    }

    part def ProcessingUnit {
        port timeDataIn : TimeDataInPort;
        port distanceDataOut : DistanceOutPort;
        port powerIn : PowerInPort;
        attribute speedOfLight : Real = 299792458;
        attribute minRange : Length = 0.2;
        attribute maxRange : Length = 250;
        action processDistance {
            accept TimeOfFlightData via timeDataIn;
            then action calculateDistance {
                attribute distanceValue : Length;
            }
            then action validateRange {
                attribute isValid : Boolean;
            }
            then send new DistanceData() via distanceDataOut;
        }
    }

    part def DisplayModule {
        port distanceIn : DistanceInPort;
        port powerIn : PowerInPort;
        action displayDistance {
            accept DistanceData via distanceIn;
        }
    }

    part def PowerSupply {
        port powerOut : PowerOutPort;
        attribute outputVoltage : Real = 3.3;
    }

    part def Target {
        port pulseIn : LaserPulseInPort;
        port reflectionOut : ReflectionOutPort;
        action reflect {
            accept LaserPulse via pulseIn;
            then send new Reflection() via reflectionOut;
        }
    }

    state def MeasurementStateDef {
        state Idle;
        state Emitting;
        state Measuring;
        state Calculating;
        state Displaying;
        transition from Idle to Emitting on trigger;
        transition from Emitting to Measuring on pulseEmitted;
        transition from Measuring to Calculating on reflectionDetected;
        transition from Calculating to Displaying on calculationComplete;
        transition from Displaying to Idle on displayComplete;
    }

    part def LaserRangefinder {
        part emitter : LaserEmitter;
        part receiver : OpticalReceiver;
        part timing : TimingCircuit;
        part processor : ProcessingUnit;
        part display : DisplayModule;
        part power : PowerSupply;
        part target : Target;
        state measurementState : MeasurementStateDef;

        connect emitter.pulseOut to target.pulseIn;
        connect emitter.pulseOut to timing.startIn;
        connect target.reflectionOut to receiver.reflectionIn;
        connect receiver.detectionOut to timing.stopIn;
        connect timing.timeDataOut to processor.timeDataIn;
        connect processor.distanceDataOut to display.distanceIn;
        connect power.powerOut to emitter.powerIn;
        connect power.powerOut to receiver.powerIn;
        connect power.powerOut to timing.powerIn;
        connect power.powerOut to processor.powerIn;
        connect power.powerOut to display.powerIn;
    }

    requirement def MeasurementRateReqDef {
        doc /* The rangefinder shall perform up to 100 readings per second. */
        attribute measurementRate : Frequency;
        attribute maxMeasurementRate : Frequency = 100;
        require constraint { measurementRate <= maxMeasurementRate }
    }

    requirement def AccuracyReqDef {
        doc /* The rangefinder shall measure distance with an accuracy of within 1 cm. */
        attribute accuracy : Length;
        attribute maxAccuracy : Length = 0.01;
        require constraint { accuracy <= maxAccuracy }
    }

    requirement def RangeReqDef {
        doc /* The rangefinder shall measure distances from 0.2 m to 250 m. */
        attribute minRange : Length = 0.2;
        attribute maxRange : Length = 250;
        attribute measuredDistance : Length;
        require constraint { measuredDistance >= minRange && measuredDistance <= maxRange }
    }

    requirement def EnvironmentalReqDef {
        doc /* The rangefinder shall function across a wide range of environmental temperatures. */
        attribute minOperatingTemp : Temperature = 253.15;
        attribute maxOperatingTemp : Temperature = 333.15;
        attribute operatingTemp : Temperature;
        require constraint { operatingTemp >= minOperatingTemp && operatingTemp <= maxOperatingTemp }
    }

    requirement def EyeSafetyReqDef {
        doc /* The rangefinder shall comply with eye safety standards for Class 1 laser products. */
        attribute laserClass : String = "Class 1";
        require constraint { laserClass == "Class 1" }
    }

    requirement def WavelengthReqDef {
        doc /* The laser emitter shall emit light at 905 nm. */
        attribute wavelength : Length;
        attribute targetWavelength : Length = 905e-9;
        require constraint { wavelength == targetWavelength }
    }
}
