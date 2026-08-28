package WiredGloveSystem {
    private import ISQ::**;
    private import ScalarValues::**;

    attribute def Confidence :> Real;

    enum def GestureKind {
        neutral;
        fist;
        point;
        pinch;
        open;
        thumbsUp;
        custom;
    }

    item def PositionVector {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    item def Orientation {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def GestureData {
        attribute gesture : GestureKind;
        attribute confidence : Confidence;
        attribute position : PositionVector;
        attribute orientation : Orientation;
    }

    item def CalibrationMap {
        attribute flexOffsets : AngleValue[5];
        attribute forceThumbScale : Real;
        attribute forceIndexScale : Real;
    }

    port def AngleOutPort {
        out attribute angle : AngleValue;
    }

    port def ForceOutPort {
        out attribute force : ForceValue;
    }

    port def IMUOutPort {
        out attribute position : PositionVector;
        out attribute roll : AngleValue;
        out attribute pitch : AngleValue;
        out attribute yaw : AngleValue;
    }

    port def CalibrationOutPort {
        out attribute calibration : CalibrationMap;
    }

    port def GestureDataOutPort {
        out attribute data : GestureData;
    }

    port def GestureDataInPort {
        in attribute data : GestureData;
    }

    port def PowerOutPort {
        out attribute voltage : ElectricPotentialValue;
    }

    port def PowerInPort {
        in attribute voltage : ElectricPotentialValue;
    }

    part def ConductiveTextile;

    part def FlexSensor {
        port dataOut : AngleOutPort;
        port powerIn : PowerInPort;
        attribute bendAngle : AngleValue;
    }

    part def ForceSensor {
        port dataOut : ForceOutPort;
        port powerIn : PowerInPort;
        attribute force : ForceValue;
    }

    part def IMU {
        port dataOut : IMUOutPort;
        port powerIn : PowerInPort;
    }

    part def CalibrationMemory {
        attribute calibrationData : CalibrationMap;
        port calibOut : CalibrationOutPort;
    }

    action def FilterAction {
        in flex : AngleValue[5];
        in forceThumb : ForceValue;
        in forceIndex : ForceValue;
        in roll : AngleValue;
        in pitch : AngleValue;
        in yaw : AngleValue;
        out filteredFlex : AngleValue[5];
        out filteredForceThumb : ForceValue;
        out filteredForceIndex : ForceValue;
        out filteredRoll : AngleValue;
        out filteredPitch : AngleValue;
        out filteredYaw : AngleValue;
    }

    action def CalibrateAction {
        in filteredFlex : AngleValue[5];
        in filteredForceThumb : ForceValue;
        in filteredForceIndex : ForceValue;
        in filteredRoll : AngleValue;
        in filteredPitch : AngleValue;
        in filteredYaw : AngleValue;
        in calibration : CalibrationMap;
        out calibratedFlex : AngleValue[5];
        out calibratedForceThumb : ForceValue;
        out calibratedForceIndex : ForceValue;
        out calibratedRoll : AngleValue;
        out calibratedPitch : AngleValue;
        out calibratedYaw : AngleValue;
    }

    action def RecognizeGestureAction {
        in calibratedFlex : AngleValue[5];
        in calibratedForceThumb : ForceValue;
        in calibratedForceIndex : ForceValue;
        out gesture : GestureKind;
        out confidence : Confidence;
    }

    part def DataProcessor {
        port flexIn1 : ~AngleOutPort;
        port flexIn2 : ~AngleOutPort;
        port flexIn3 : ~AngleOutPort;
        port flexIn4 : ~AngleOutPort;
        port flexIn5 : ~AngleOutPort;
        port forceThumbIn : ~ForceOutPort;
        port forceIndexIn : ~ForceOutPort;
        port imuIn : ~IMUOutPort;
        port calibIn : ~CalibrationOutPort;
        port powerIn : PowerInPort;
        port dataOut : GestureDataOutPort;

        perform action processData {
            in rawFlex1 : AngleValue;
            in rawFlex2 : AngleValue;
            in rawFlex3 : AngleValue;
            in rawFlex4 : AngleValue;
            in rawFlex5 : AngleValue;
            in rawForceThumb : ForceValue;
            in rawForceIndex : ForceValue;
            in rawRoll : AngleValue;
            in rawPitch : AngleValue;
            in rawYaw : AngleValue;
            in rawPosition : PositionVector;
            in calibration : CalibrationMap;
            out gesture : GestureKind;
            out confidence : Confidence;
            out position : PositionVector;
            out orientation : Orientation;

            first start;
            then action filter;
            then action calibrate;
            then action recognizeGesture;
            then done;
        }
    }

    part def WirelessTransmitter {
        port dataIn : GestureDataInPort;
        port powerIn : PowerInPort;
        perform action transmit {
            in data : GestureData;
            first start;
            then done;
        }
    }

    part def RechargeableBattery {
        port powerOut : PowerOutPort;
        attribute capacity : TimeValue = 8 [h];
        attribute stateOfCharge : Real;
    }

    part def WiredGlove {
        attribute latency : TimeValue;
        attribute accuracy : Confidence;

        part gloveBody : ConductiveTextile;
        part flexSensors[5] : FlexSensor;
        part forceSensors[2] : ForceSensor;
        part imu : IMU;
        part calibrationMemory : CalibrationMemory;
        part processor : DataProcessor;
        part transmitter : WirelessTransmitter;
        part battery : RechargeableBattery;

        connect battery.powerOut to processor.powerIn;
        connect battery.powerOut to transmitter.powerIn;
        connect battery.powerOut to imu.powerIn;
        connect battery.powerOut to flexSensors.powerIn;
        connect battery.powerOut to forceSensors.powerIn;

        connect flexSensors[1].dataOut to processor.flexIn1;
        connect flexSensors[2].dataOut to processor.flexIn2;
        connect flexSensors[3].dataOut to processor.flexIn3;
        connect flexSensors[4].dataOut to processor.flexIn4;
        connect flexSensors[5].dataOut to processor.flexIn5;
        connect forceSensors[1].dataOut to processor.forceThumbIn;
        connect forceSensors[2].dataOut to processor.forceIndexIn;
        connect imu.dataOut to processor.imuIn;
        connect calibrationMemory.calibOut to processor.calibIn;

        connect processor.dataOut to transmitter.dataIn;

        state gloveLifecycle {
            state off;
            state calibrating;
            state active;
            transition powerOn first off if battery.powerOut.voltage > 0 then calibrating;
            transition calibrationComplete first calibrating if true then active;
            transition captureLoop first active if true then active;
            transition powerOff first active if battery.powerOut.voltage <= 0 then off;
        }
    }

    requirement def LowLatencyRequirement {
        doc /* The system shall recognize gestures with end-to-end latency under 50 milliseconds. */
        subject glove : WiredGlove;
        attribute maxLatency : TimeValue = 50 [ms];
        require glove.latency <= maxLatency;
    }

    requirement def HighAccuracyRequirement {
        doc /* The gesture recognition accuracy shall exceed 90 percent. */
        subject glove : WiredGlove;
        attribute minAccuracy : Confidence = 0.90;
        require glove.accuracy >= minAccuracy;
    }

    requirement def BatteryLifeRequirement {
        doc /* The rechargeable battery shall provide at least 8 hours of continuous operation. */
        subject glove : WiredGlove;
        attribute minDuration : TimeValue = 8 [h];
        require glove.battery.capacity >= minDuration;
    }

    part wiredGloveSystem : WiredGlove {
        satisfy LowLatencyRequirement;
        satisfy HighAccuracyRequirement;
        satisfy BatteryLifeRequirement;
    }
}
