package WheelSpeedSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;

    package ValueTypes {
        attribute def AngularVelocity :> Real { unit 'rad/s'; }
        attribute def AngularAcceleration :> Real { unit 'rad/s2'; }
        attribute def Temperature :> Real { unit 'degC'; }
        attribute def Frequency :> Real { unit 'Hz'; }
        attribute def Voltage :> Real { unit 'V'; }
        attribute def ConfidenceScore :> Real { unit 'percent'; min = 0; max = 100; }
        attribute def ToothCount :> Integer;
        attribute def RotationAngle :> Real { unit 'rad'; }
        attribute def TimeStamp :> Real { unit 's'; }
    }

    package Items {
        enum def SensorStatus {
            operational;
            degraded;
            failed;
        }

        item def RawSignal {
            attribute amplitude : Voltage;
            attribute frequency : Frequency;
            attribute temperature : Temperature;
            attribute timestamp : TimeStamp;
        }

        item def WheelSpeedData {
            attribute angularVelocity : AngularVelocity;
            attribute angularAcceleration : AngularAcceleration;
            attribute confidence : ConfidenceScore;
            attribute status : SensorStatus;
            attribute timestamp : TimeStamp;
        }

        item def ElectricalPower {
            attribute voltage : Voltage;
            attribute nominal : Voltage = 12 [V];
        }

        item def ToneRingPass {
            attribute toothIndex : ToothCount;
            attribute angle : RotationAngle;
        }
    }

    package Ports {
        port def MechanicalRotationPort {
            attribute angularPosition : RotationAngle;
            attribute angularVelocity : AngularVelocity;
        }

        port def RawSignalPort {
            out item raw : Items::RawSignal;
        }

        port def DataOutputPort {
            out item data : Items::WheelSpeedData;
        }

        port def PowerPort {
            in item power : Items::ElectricalPower;
        }
    }

    package Parts {

        part def ToneRing {
            attribute toothCount : ToothCount = 48;
            attribute diameter : Real { unit 'mm'; } = 100;
            port rotation : Ports::MechanicalRotationPort;
        }

        part def MagneticSensingElement {
            attribute minOperatingTemp : Temperature = -40 [degC];
            attribute maxOperatingTemp : Temperature = 125 [degC];
            attribute currentTemperature : Temperature;
            port rawOut : Ports::RawSignalPort;
            action def SenseToothPass(in pass : Items::ToneRingPass) : Items::RawSignal;
            perform action senseLoop {
                while true {
                    accept pass : Items::ToneRingPass;
                    emit rawOut.raw : SenseToothPass(pass);
                }
            }
        }

        part def SignalConditioner {
            attribute gain : Real = 100;
            attribute filterCutoff : Frequency = 1000 [Hz];
            attribute status : Items::SensorStatus = Items::SensorStatus::operational;
            attribute confidence : ConfidenceScore = 100 [percent];
            port rawIn : Ports::RawSignalPort { in item raw; }
            port dataOut : Ports::DataOutputPort;
            action def Amplify(in s : Items::RawSignal) : Items::RawSignal;
            action def Filter(in s : Items::RawSignal) : Items::RawSignal;
            action def ComputeVelocity(in s : Items::RawSignal) : AngularVelocity;
            action def ComputeAcceleration(in v : AngularVelocity) : AngularAcceleration;
            action def Validate(in s : Items::RawSignal) : ConfidenceScore;
            perform action conditionLoop {
                while true {
                    accept s : Items::RawSignal via rawIn.raw;
                    then a1 = Amplify(s);
                    then a2 = Filter(a1);
                    then v = ComputeVelocity(a2);
                    then acc = ComputeAcceleration(v);
                    then conf = Validate(a2);
                    then assign status = (conf < 30 [percent]) ? Items::SensorStatus::failed :
                                       (conf < 70 [percent]) ? Items::SensorStatus::degraded :
                                       Items::SensorStatus::operational;
                    then emit dataOut.data : Items::WheelSpeedData {
                        angularVelocity = v;
                        angularAcceleration = acc;
                        confidence = conf;
                        status = status;
                        timestamp = s.timestamp;
                    };
                }
            }
        }

        part def ABSSensor {
            attribute serialNumber : String;
            attribute supplyVoltage : Voltage = 12 [V];
            port power : Ports::PowerPort;
            port dataOut : Ports::DataOutputPort;
            part magneticElement : MagneticSensingElement;
            part conditioner : SignalConditioner;
            connection rawLink connect magneticElement.rawOut to conditioner.rawIn;
            connection dataLink connect conditioner.dataOut to dataOut;
            exhibit stateMachine : SensorStateMachine;
        }

        part def WheelSpeedSensingUnit {
            attribute assemblyId : String;
            part toneRing : ToneRing;
            part absSensor : ABSSensor;
            connection mechanicalInterface connect toneRing.rotation to absSensor.power;
            // Note: tone ring rotation is sensed magnetically; represented as item flow
            flow from toneRing.rotation to absSensor.magneticElement.senseLoop.pass : Items::ToneRingPass;
        }
    }

    package Behaviors {
        state def SensorStateMachine {
            entry; then Off;

            state Off;
            transition off_to_selftest first Off to SelfTest
                when absSensor.power.power.voltage > 0 [V];

            state SelfTest {
                entry { assign absSensor.conditioner.status = Items::SensorStatus::operational; }
                do { perform selfTestRoutine; }
            }
            action def selfTestRoutine;
            transition selftest_to_operational first SelfTest to Operational
                when selfTestRoutine.success;

            state Operational {
                entry { assign absSensor.conditioner.status = Items::SensorStatus::operational; }
                do { perform absSensor.conditioner.conditionLoop; }
            }
            transition operational_to_degraded first Operational to Degraded
                when absSensor.conditioner.confidence < 70 [percent];

            state Degraded {
                entry { assign absSensor.conditioner.status = Items::SensorStatus::degraded; }
                do { perform absSensor.conditioner.conditionLoop; }
            }
            transition degraded_to_operational first Degraded to Operational
                when absSensor.conditioner.confidence >= 70 [percent];
            transition degraded_to_fault first Degraded to Fault
                when absSensor.conditioner.confidence < 30 [percent];

            state Fault {
                entry {
                    assign absSensor.conditioner.status = Items::SensorStatus::failed;
                    // Safely shut down: stop emitting data
                }
            }
            transition operational_to_fault first Operational to Fault
                when absSensor.conditioner.confidence < 30 [percent];
        }
    }

    package Requirements {
        requirement def MeasurementAccuracy {
            attribute tolerance : AngularVelocity = 0.5 [rad/s];
            subject sensor : Parts::ABSSensor;
            objective {
                doc /* The sensor shall measure wheel angular velocity within tolerance. */
            }
        }

        requirement def TemperatureRange {
            attribute minTemp : Temperature = -40 [degC];
            attribute maxTemp : Temperature = 125 [degC];
            subject element : Parts::MagneticSensingElement;
            objective {
                doc /* The magnetic sensing element shall operate between minTemp and maxTemp. */
            }
        }

        requirement def SelfTestOnPowerUp {
            subject sensor : Parts::ABSSensor;
            objective {
                doc /* The sensor shall run a self-test upon power-up before entering operational mode. */
            }
        }

        requirement def SafeShutdownOnFault {
            subject sensor : Parts::ABSSensor;
            objective {
                doc /* Upon critical fault, the sensor shall enter fault mode and cease data emission. */
            }
        }

        requirement def HealthReporting {
            subject conditioner : Parts::SignalConditioner;
            objective {
                doc /* The conditioner shall report status and confidence with each data sample. */
            }
        }

        requirement MeasurementAccuracyReq : MeasurementAccuracy {
            tolerance = 0.5 [rad/s];
        }
        requirement TemperatureRangeReq : TemperatureRange {
            minTemp = -40 [degC];
            maxTemp = 125 [degC];
        }
        requirement SelfTestReq : SelfTestOnPowerUp;
        requirement SafeShutdownReq : SafeShutdownOnFault;
        requirement HealthReportingReq : HealthReporting;

        satisfaction TemperatureRangeReq by Parts::MagneticSensingElement;
        satisfaction SelfTestReq by Parts::ABSSensor;
        satisfaction SafeShutdownReq by Parts::ABSSensor;
        satisfaction HealthReportingReq by Parts::SignalConditioner;
        satisfaction MeasurementAccuracyReq by Parts::SignalConditioner;
    }
}
