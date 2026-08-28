package 'OneTouch Ultra Blood Glucose Meter' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::TimeInstantValue;

    attribute def GlucoseConcentrationValue :> Real {
    }
    attribute def CurrentValue :> Real {
    }
    attribute def DigitalValue :> Integer;

    item def BloodSample;
    item def TestStrip;
    item def GlucoseReading {
        attribute value : GlucoseConcentrationValue;
        attribute timestamp : TimeInstantValue;
    }
    item def ErrorMessage;

    attribute def StripInserted;
    attribute def BloodApplied;
    attribute def StripRemoved;

    action def MeasureCurrent {
        in item sample : BloodSample;
        in item strip : TestStrip;
        out current : CurrentValue;
    }
    action def ConvertToDigital {
        in current : CurrentValue;
        out digital : DigitalValue;
    }
    action def CalculateGlucose {
        in digital : DigitalValue;
        out reading : GlucoseReading;
    }
    action def DisplayResult {
        in reading : GlucoseReading;
    }
    action def DisplayError {
        in error : ErrorMessage;
    }
    action def SaveReading {
        in reading : GlucoseReading;
    }

    port def StripPort {
        in item strip : TestStrip;
    }
    port def CurrentPort {
        out current : CurrentValue;
    }
    port def DigitalPort {
        out digital : DigitalValue;
    }
    port def ReadingPort {
        out reading : GlucoseReading;
    }
    port def DisplayPort {
        in reading : GlucoseReading;
        in error : ErrorMessage;
    }
    port def MemoryPort {
        in reading : GlucoseReading;
    }
    port def PowerPort;

    part def ElectrochemicalSensor {
        port stripInput : StripPort;
        port currentOutput : CurrentPort;
        port powerInput : PowerPort;
    }
    part def ADC {
        port analogInput : CurrentPort;
        port digitalOutput : DigitalPort;
        port powerInput : PowerPort;
    }
    part def Microcontroller {
        port digitalInput : DigitalPort;
        port readingOutput : ReadingPort;
        port displayOutput : DisplayPort;
        port memoryOutput : MemoryPort;
        port powerInput : PowerPort;
        attribute calibrationCurve : Real[*];
    }
    part def LCD {
        port displayInput : DisplayPort;
        port powerInput : PowerPort;
    }
    part def NonvolatileMemory {
        port memoryInput : MemoryPort;
        port powerInput : PowerPort;
        attribute maxReadings : Integer = 450;
        item storedReadings : GlucoseReading[450];
    }
    part def Battery {
        port powerOutput : PowerPort;
    }

    state def MeterStates;

    part def Meter {
        port stripSlot : StripPort;
        part sensor : ElectrochemicalSensor;
        part adc : ADC;
        part microcontroller : Microcontroller;
        part lcd : LCD;
        part memory : NonvolatileMemory;
        part battery : Battery;

        connect stripSlot to sensor.stripInput;
        connect sensor.currentOutput to adc.analogInput;
        connect adc.digitalOutput to microcontroller.digitalInput;
        connect microcontroller.displayOutput to lcd.displayInput;
        connect microcontroller.memoryOutput to memory.memoryInput;
        connect battery.powerOutput to sensor.powerInput;
        connect battery.powerOutput to adc.powerInput;
        connect battery.powerOutput to microcontroller.powerInput;
        connect battery.powerOutput to lcd.powerInput;
        connect battery.powerOutput to memory.powerInput;

        action measure : MeasureCurrent;
        action convert : ConvertToDigital {
            in current = measure.current;
        }
        action calculate : CalculateGlucose {
            in digital = convert.digital;
        }

        exhibit state meterStates : MeterStates {
            entry; then off;

            state off;
            accept StripInserted
                then standby;

            state standby;
            accept BloodApplied
                then measuring;

            state measuring {
                entry measure;
                entry convert;
                entry calculate;
            }
            accept after 5 [s]
                then displayingResult;

            state displayingResult {
                entry action processResult {
                    if calculate.reading.value >= 20 and calculate.reading.value <= 600 {
                        action display : DisplayResult {
                            in reading = calculate.reading;
                        }
                        action save : SaveReading {
                            in reading = calculate.reading;
                        }
                    } else {
                        action error : DisplayError {
                            in error = new ErrorMessage();
                        }
                    }
                }
            }
            accept StripRemoved
                then off;
        }
    }

    part meter : Meter;

    requirement def 'Blood Glucose Measurement Range' {
        doc /* The OneTouch Ultra shall measure blood glucose concentration in the range of 20 to 600 mg/dL. */
        subject meter : Meter;
        attribute minRange : GlucoseConcentrationValue = 20;
        attribute maxRange : GlucoseConcentrationValue = 600;
    }

    requirement def 'Memory Capacity' {
        doc /* The device shall store up to 450 historical readings with timestamps in nonvolatile memory. */
        subject meter : Meter;
        attribute maxReadings : Integer = 450;
    }

    requirement def 'Measurement Time' {
        doc /* The measurement shall complete within 5 seconds after blood application. */
        subject meter : Meter;
        attribute maxDuration : DurationValue = 5 [s];
    }

    requirement def 'Measurement Accuracy' {
        doc /* Measurement accuracy shall be within ±15% for values greater than 100 mg/dL. */
        subject meter : Meter;
    }

    requirement def 'Out of Range Error' {
        doc /* If the reading is outside the measurable range of 20-600 mg/dL, the meter shall display an error message instead of a numeric result. */
        subject meter : Meter;
    }
}
