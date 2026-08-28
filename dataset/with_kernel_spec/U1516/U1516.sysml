package TotalPressureMeasurementSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    private import NumericalFunctions::*;

    attribute def Activate;
    attribute def Deactivate;
    attribute def SelfTestComplete;
    attribute def AcquisitionComplete;
    attribute def ProcessingComplete;
    attribute def TransmissionComplete;
    attribute def FaultSignal;
    attribute def ResetSignal;

    item def ElectricalSignal {
        attribute value : PressureValue;
    }

    item def DisplayData {
        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;
        attribute dynamicPressure : PressureValue;
        attribute velocity : VelocityValue;
    }

    item def LogRecord {
        attribute timestamp : TimeValue;
        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;
        attribute dynamicPressure : PressureValue;
        attribute velocity : VelocityValue;
    }

    action def PerformSelfTest;
    action def AcquirePressures;
    action def CalculateVelocity;
    action def TransmitData;
    action def LogError;

    calc def DynamicPressureCalc {
        in totalPressure : PressureValue;
        in staticPressure : PressureValue;
        return dynamicPressure : PressureValue = totalPressure - staticPressure;
    }

    calc def VelocityCalc {
        in dynamicPressure : PressureValue;
        in density : MassDensityValue;
        return velocity : VelocityValue = sqrt(2.0 * dynamicPressure / density);
    }

    part def PitotProbe {
        attribute measuredTotalPressure : PressureValue;
        out port totalPressureOut : PressureValue;
    }

    part def StaticPressureProbe {
        attribute measuredStaticPressure : PressureValue;
        out port staticPressureOut : PressureValue;
    }

    part def PressureTransducer {
        in port pressureIn : PressureValue;
        out port signalOut : ElectricalSignal;
        attribute calibrationFactor : Real = 1.0;
    }

    part def DataProcessor {
        in port totalSignalIn : ElectricalSignal;
        in port staticSignalIn : ElectricalSignal;
        out port displayOut : DisplayData;
        out port logOut : LogRecord;

        attribute airDensity : MassDensityValue = 1.225;
        attribute systemClock : TimeValue;

        calc dynamicCalc : DynamicPressureCalc {
            in totalPressure = totalSignalIn.value;
            in staticPressure = staticSignalIn.value;
            return dynamicPressure;
        }

        calc velocityCalc : VelocityCalc {
            in dynamicPressure = dynamicCalc.dynamicPressure;
            in density = airDensity;
            return velocity;
        }

        state def ProcessorBehavior {
            entry; then initializing;
            state initializing {
                do action selfTest : PerformSelfTest;
            }
            transition first initializing accept SelfTestComplete then standby;
            state standby;
            transition first standby accept Activate then active;
            state active {
                entry; then acquire;
                state acquire {
                    do action acquirePressures : AcquirePressures;
                }
                transition first acquire accept AcquisitionComplete then process;
                state process {
                    do action calculateVelocity : CalculateVelocity;
                }
                transition first process accept ProcessingComplete then transmit;
                state transmit {
                    do action transmitData : TransmitData;
                }
                transition first transmit accept TransmissionComplete then acquire;
            }
            transition first active accept Deactivate then standby;
            transition first active accept FaultSignal then fault;
            state fault {
                do action logError : LogError;
            }
            transition first fault accept ResetSignal then standby;
        }

        state processorState : ProcessorBehavior;
    }

    part def DisplayUnit {
        in port displayIn : DisplayData;
    }

    part def DataLogger {
        in port logIn : LogRecord;
        attribute samplingRate : FrequencyValue = 100;
    }

    requirement def MeasureTotalPressure {
        doc /* The system shall measure total pressure using a Pitot probe facing the oncoming airflow. */
    }

    requirement def MeasureStaticPressure {
        doc /* The system shall measure ambient static pressure using a static pressure probe. */
    }

    requirement def CalculateDynamicPressure {
        doc /* The system shall calculate dynamic pressure as the difference between total and static pressure. */
    }

    requirement def CalculateVelocity {
        doc /* The system shall calculate airspeed from dynamic pressure and air density using Bernoulli's equation. */
    }

    requirement def DisplayInformation {
        doc /* The system shall display total, static, and dynamic pressures and calculated velocity to the operator. */
    }

    requirement def LogInformation {
        doc /* The system shall log pressure and velocity data at a minimum frequency of 100 Hz for post-flight analysis. */
    }

    requirement def HandleFaults {
        doc /* The system shall enter a safe fault state upon detection of errors during operation. */
    }

    part def MeasurementSystem {
        part pitotProbe : PitotProbe;
        part staticProbe : StaticPressureProbe;
        part totalTransducer : PressureTransducer;
        part staticTransducer : PressureTransducer;
        part dataProcessor : DataProcessor;
        part displayUnit : DisplayUnit;
        part dataLogger : DataLogger;

        requirement measureTotalPressure : MeasureTotalPressure;
        requirement measureStaticPressure : MeasureStaticPressure;
        requirement calculateDynamicPressure : CalculateDynamicPressure;
        requirement calculateVelocity : CalculateVelocity;
        requirement displayInformation : DisplayInformation;
        requirement logInformation : LogInformation;
        requirement handleFaults : HandleFaults;

        satisfy measureTotalPressure by pitotProbe;
        satisfy measureStaticPressure by staticProbe;
        satisfy calculateDynamicPressure by dataProcessor;
        satisfy calculateVelocity by dataProcessor;
        satisfy displayInformation by displayUnit;
        satisfy logInformation by dataLogger;
        satisfy handleFaults by dataProcessor;

        connection pitotToTransducer connect pitotProbe.totalPressureOut to totalTransducer.pressureIn;
        connection staticToTransducer connect staticProbe.staticPressureOut to staticTransducer.pressureIn;
        connection totalTransducerToProcessor connect totalTransducer.signalOut to dataProcessor.totalSignalIn;
        connection staticTransducerToProcessor connect staticTransducer.signalOut to dataProcessor.staticSignalIn;
        connection processorToDisplay connect dataProcessor.displayOut to displayUnit.displayIn;
        connection processorToLogger connect dataProcessor.logOut to dataLogger.logIn;
    }

    part system : MeasurementSystem;
}
