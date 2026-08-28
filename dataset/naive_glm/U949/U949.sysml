package WiredGlove {
    import ISQ::*;
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---------- Value Types with Units ----------
    value def Angle :> Real { unit 'deg'; }
    value def Force :> Real { unit 'N'; }
    value def AngularVelocity :> Real { unit 'deg/s'; }
    value def LinearAcceleration :> Real { unit 'm/s^2'; }
    value def Duration :> Real { unit 'ms'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real {> Real { unit 'mA'; }
    value def Charge :> Real { unit 'mAh'; }
    value def Confidence :> Real { unit '%'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Distance :> Real { unit 'm'; }
    value def Power :> Real { unit 'mW'; }

    // ---------- Enumerations ----------
    enum def FingerName { thumb; index; middle; ring; pinky; }
    enum def GestureType { fist; openPalm; pinch; point; grip; wave; thumbsUp; unknown; }
    enum def OperationalMode { off; calibration; active; standby; }

    // ---------- Item Definitions ----------
    item def RawSensorData {
        attribute timestamp : Duration;
    }
    item def FlexData :> RawSensorData {
        attribute finger : FingerName;
        attribute bendAngle : Angle;
    }
    item def ForceData :> RawSensorData {
        attribute finger : FingerName;
        attribute force : Force;
    }
    item def IMUData :> RawSensorData {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
        attribute rollRate : AngularVelocity;
        attribute pitchRate : AngularVelocity;
        attribute yawRate : AngularVelocity;
        attribute accelX : LinearAcceleration;
        attribute accelY : LinearAcceleration;
        attribute accelZ : LinearAcceleration;
    }
    item def CalibrationProfile {
        attribute flexOffsets : Angle[5];
        attribute flexScales : Real[5];
        attribute forceOffsets : Force[2];
        attribute forceScales : Real[2];
        attribute imuOffsets : Angle[3];
    }
    item def CalibratedData {
        attribute timestamp : Duration;
        attribute flexAngles : Angle[5];
        attribute forces : Force[2];
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }
    item def GestureResult {
        attribute timestamp : Duration;
        attribute gesture : GestureType;
        attribute confidence : Confidence;
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }
    item def PowerSignal {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ---------- Port Definitions ----------
    port def FlexSensorOut { out flexData : FlexData; }
    port def ForceSensorOut { out forceData : ForceData; }
    port def IMUOut { out imuData : IMUData; }
    port def ProcessorIn {
        in flexData : FlexData[5];
        in forceData : ForceData[2];
        in imuData : IMUData;
    }
    port def ProcessorOut { out gestureResult : GestureResult; }
    port def TransmitterIn { in gestureResult : GestureResult; }
    port def WirelessLink { out gestureResult : GestureResult; }
    port def PowerOut { out power : PowerSignal; }
    port def PowerIn { in power : PowerSignal; }

    // ---------- Action Definitions ----------
    action def MeasureFlex :> Actions::Action {
        in currentBend : Angle;
        out data : FlexData;
    }
    action def MeasureForce :> Actions::Action {
        in currentForce : Force;
        out data : ForceData;
    }
    action def MeasureIMU :> Actions::Action {
        out data : IMUData;
    }
    action def FilterData :> Actions::Action {
        in rawFlex : FlexData[5];
        in rawForce : ForceData[2];
        in rawIMU : IMUData;
        out filteredFlex : FlexData[5];
        out filteredForce : ForceData[2];
        out filteredIMU : IMUData;
    }
    action def ApplyCalibration :> Actions::Action {
        in filteredFlex : FlexData[5];
        in filteredForce : ForceData[2];
        in filteredIMU : IMUData;
        in profile : CalibrationProfile;
        out calibrated : CalibratedData;
    }
    action def RecognizeGesture :> Actions::Action {
        in calibrated : CalibratedData;
        out result : GestureResult;
    }
    action def TransmitData :> Actions::Action {
        in result : GestureResult;
    }
    action def Discharge :> Actions::Action {
        out power : PowerSignal;
    }

    // ---------- Part Definitions ----------
    part def FlexSensor {
        attribute finger : FingerName;
        attribute samplingRate : Frequency = 100;
        attribute maxBendAngle : Angle = 90;
        port flexOut : FlexSensorOut;
        port pwrIn : PowerIn;
        action measure : MeasureFlex;
    }

    part def ForceSensor {
        attribute finger : FingerName;
        attribute samplingRate : Frequency = 100;
        attribute maxForce : Force = 50;
        port forceOut : ForceSensorOut;
        port pwrIn : PowerIn;
        action measure : MeasureForce;
    }

    part def IMU {
        attribute samplingRate : Frequency = 200;
        attribute rollRange : Angle = 360;
        attribute pitchRange : Angle = 360;
        attribute yawRange : Angle = 360;
        port imuOut : IMUOut;
        port pwrIn : PowerIn;
        action measure : MeasureIMU;
    }

    part def DataProcessor {
        attribute clockSpeed : Frequency = 80;
        attribute calibrationProfile : CalibrationProfile;
        attribute latencyBudget : Duration = 50;
        port procIn : ProcessorIn;
        port procOut : ProcessorOut;
        port pwrIn : PowerIn;

        action filter : FilterData;
        action calibrate : ApplyCalibration;
        action recognize : RecognizeGesture;

        state def ProcessorBehavior {
            entry; then idle;
            state idle;
            transition idle_to_processing
                first idle
                if procIn.flexData->size() == 5 and procIn.forceData->size() == 2 and procIn.imuData <> null
                then processing;
            state processing {
                do filter then calibrate then recognize;
            }
            transition processing_to_idle
                first processing
                then idle;
        }
    }

    part def WirelessTransmitter {
        attribute protocol : String = "BLE 5.0";
        attribute range : Distance = 10;
        attribute bandwidth : Frequency = 1000;
        port txIn : TransmitterIn;
        port txOut : WirelessLink;
        port pwrIn : PowerIn;
        action transmit : TransmitData;
    }

    part def Battery {
        attribute capacity : Charge = 1200;
        attribute nominalVoltage : Voltage = 3.7;
        attribute currentDraw : Current = 150;
        attribute minRuntimeHours : Real = 8;
        attribute chargeLevel : Charge = 1200;
        port powerOut : PowerOut;
        action discharge : Discharge;
    }

    part def ConductiveGlove {
        attribute material : String = "conductive textile";
        attribute size : String = "universal";
        attribute washable : Boolean = true;
    }

    // ---------- Top-Level System ----------
    part def WiredGloveSystem {
        attribute systemId : String;
        attribute mode : OperationalMode = OperationalMode::off;

        part glove : ConductiveGlove;

        part thumbFlex : FlexSensor { attribute finger = FingerName::thumb; }
        part indexFlex : FlexSensor { attribute finger = FingerName::index; }
        part middleFlex : FlexSensor { attribute finger = FingerName::middle; }
        part ringFlex : FlexSensor { attribute finger = FingerName::ring; }
        part pinkyFlex : FlexSensor { attribute finger = FingerName::pinky; }

        part thumbForce : ForceSensor { attribute finger = FingerName::thumb; }
        part indexForce : ForceSensor { attribute finger = FingerName::index; }

        part imu : IMU;
        part processor : DataProcessor;
        part transmitter : WirelessTransmitter;
        part battery : Battery;

        // Power distribution
        connection batteryToProcessor connect battery.powerOut to processor.pwrIn;
        connection batteryToTransmitter connect battery.powerOut to transmitter.pwrIn;
        connection batteryToIMU connect battery.powerOut to imu.pwrIn;
        connection batteryToThumbFlex connect battery.powerOut to thumbFlex.pwrIn;
        connection batteryToIndexFlex connect battery.powerOut to indexFlex.pwrIn;
        connection batteryToMiddleFlex connect battery.powerOut to middleFlex.pwrIn;
        connection batteryToRingFlex connect battery.powerOut to ringFlex.pwrIn;
        connection batteryToPinkyFlex connect battery.powerOut to pinkyFlex.pwrIn;
        connection batteryToThumbForce connect battery.powerOut to thumbForce.pwrIn;
        connection batteryToIndexForce connect battery.powerOut to indexForce.pwrIn;

        // Sensor data to processor
        connection thumbFlexToProc connect thumbFlex.flexOut to processor.procIn;
        connection indexFlexToProc connect indexFlex.flexOut to processor.procIn;
        connection middleFlexToProc connect middleFlex.flexOut to processor.procIn;
        connection ringFlexToProc connect ringFlex.flexOut to processor.procIn;
        connection pinkyFlexToProc connect pinkyFlex.flexOut to processor.procIn;
        connection thumbForceToProc connect thumbForce.forceOut to processor.procIn;
        connection indexForceToProc connect indexForce.forceOut to processor.procIn;
        connection imuToProc connect imu.imuOut to processor.procIn;

        // Processor to transmitter
        connection procToTx connect processor.procOut to transmitter.txIn;

        // System lifecycle state machine
        state def SystemLifecycle {
            entry; then off;
            state off {
                doc { Glove is powered down. }
            }
            transition off_to_calibration
                first off
                if powerOn
                then calibrationMode;
            state calibrationMode {
                doc { System performs sensor calibration upon power-on. }
                do processor.calibrate;
            }
            transition calibration_to_active
                first calibrationMode
                if calibrationComplete
                then activeMode;
            state activeMode {
                doc { Continuous capture and transmission loop. }
                do {
                    thumbFlex.measure;
                    indexFlex.measure;
                    middleFlex.measure;
                    ringFlex.measure;
                    pinkyFlex.measure;
                    thumbForce.measure;
                    indexForce.measure;
                    imu.measure;
                    processor.filter;
                    processor.calibrate;
                    processor.recognize;
                    transmitter.transmit;
                }
            }
            transition active_to_standby
                first activeMode
                if lowBattery
                then standbyMode;
            state standbyMode {
                doc { Reduced activity to conserve remaining battery. }
            }
            transition standby_to_off
                first standbyMode
                if powerOff
                then off;
            transition active_to_off
                first activeMode
                if powerOff
                then off;
        }

        // Requirements
        requirement lowLatencyReq {
            doc { The end-to-end latency from sensor capture to wireless transmission shall be less than 50 milliseconds. }
            subject self;
            assume { self.mode == OperationalMode::active; }
        }
        requirement highAccuracyReq {
            doc { Gesture recognition accuracy shall exceed 90%. }
            subject self;
        }
        requirement batteryLifeReq {
            doc { The battery shall provide at least 8 hours of continuous operation on a single charge. }
            subject self;
            assume { self.mode == OperationalMode::active; }
        }
        requirement confidenceScoreReq {
            doc { The system shall assign a confidence score to each recognized gesture. }
            subject self;
        }
        requirement calibrationModeReq {
            doc { Upon powering on, the system shall enter calibration mode before becoming active. }
            subject self;
        }
        requirement wirelessTransmissionReq {
            doc { The system shall transmit gesture type, hand position, and orientation to an external device. }
            subject self;
        }
        requirement fiveFlexSensorsReq {
            doc { The system shall include five flex sensors, one for each finger. }
            subject self;
        }
        requirement forceSensorsReq {
            doc { The system shall include force sensors in the thumb and index finger. }
            subject self;
        }
        requirement imuReq {
            doc { The system shall include an IMU to track roll, pitch, and yaw. }
            subject self;
        }
    }
}
