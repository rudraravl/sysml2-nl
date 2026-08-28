package GravimeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def DisplacementSignal {
        attribute displacement :> ISQ::length;
    }
    item def RawVoltageSignal {
        attribute voltage :> ISQ::electricPotentialDifference;
    }
    item def ConditionedVoltageSignal {
        attribute voltage :> ISQ::electricPotentialDifference;
    }
    item def DigitalSignal {
        attribute value : Integer;
    }
    item def TemperatureSignal {
        attribute value :> ISQ::temperature;
    }
    item def GravityReading {
        attribute gravity :> ISQ::acceleration;
        attribute timestamp :> ISQ::time;
        attribute temperature :> ISQ::temperature;
    }
    item def Command;
    item def StartCommand :> Command;
    item def StopCommand :> Command;
    item def StatusReport {
        attribute code : Integer;
        attribute statusMessage : String;
    }
    item def PowerSignal {
        attribute voltage :> ISQ::electricPotentialDifference;
    }

    port def DispOutPort { out disp : DisplacementSignal; }
    port def DispInPort { in disp : DisplacementSignal; }
    port def RawVoltOutPort { out sig : RawVoltageSignal; }
    port def RawVoltInPort { in sig : RawVoltageSignal; }
    port def CondVoltOutPort { out sig : ConditionedVoltageSignal; }
    port def CondVoltInPort { in sig : ConditionedVoltageSignal; }
    port def DigitalOutPort { out sig : DigitalSignal; }
    port def DigitalInPort { in sig : DigitalSignal; }
    port def TempOutPort { out sig : TemperatureSignal; }
    port def TempInPort { in sig : TemperatureSignal; }
    port def ReadingOutPort { out r : GravityReading; }
    port def ReadingInPort { in r : GravityReading; }
    port def PowerOutPort { out p : PowerSignal; }
    port def PowerInPort { in p : PowerSignal; }
    port def CmdInPort { in cmd : Command; }
    port def CmdOutPort { out cmd : Command; }
    port def StatusOutPort { out stat : StatusReport; }

    part def ProofMass {
        attribute mass :> ISQ::mass = 0.01 [kg];
        attribute localGravity :> ISQ::acceleration;
        attribute displacement :> ISQ::length;
        out port dispOut : DispOutPort;
        assign displacement = localGravity * 0.001 [s*s];
        bind dispOut.disp.displacement = displacement;
    }

    part def SpringSystem {
        attribute stiffness : Real = 100.0;
        attribute restLength :> ISQ::length = 0.05 [m];
    }

    part def DisplacementSensor {
        in port dispIn : DispInPort;
        in port pwrIn : PowerInPort;
        out port rawOut : RawVoltOutPort;
        perform action sense {
            in disp : DisplacementSignal = dispIn.disp;
            out raw : RawVoltageSignal = rawOut.sig;
            assign raw.voltage = disp.displacement * 1.0 [V/m];
        }
    }

    part def SignalConditioner {
        in port rawIn : RawVoltInPort;
        in port pwrIn : PowerInPort;
        out port condOut : CondVoltOutPort;
        attribute gain : Real = 100.0;
        perform action condition {
            in raw : RawVoltageSignal = rawIn.sig;
            out cond : ConditionedVoltageSignal = condOut.sig;
            assign cond.voltage = raw.voltage * gain;
        }
    }

    part def ADC {
        in port condIn : CondVoltInPort;
        in port pwrIn : PowerInPort;
        out port digitalOut : DigitalOutPort;
        attribute resolutionBits : Integer = 24;
        perform action convert {
            in cond : ConditionedVoltageSignal = condIn.sig;
            out digital : DigitalSignal = digitalOut.sig;
            assign digital.value = 0;
        }
    }

    part def TemperatureSensor {
        in port pwrIn : PowerInPort;
        out port tempOut : TempOutPort;
        attribute currentTemp :> ISQ::temperature = 293.15 [K];
        bind tempOut.sig.value = currentTemp;
    }

    part def DataProcessor {
        in port digitalIn : DigitalInPort;
        in port tempIn : TempInPort;
        in port pwrIn : PowerInPort;
        out port readingOut : ReadingOutPort;
        attribute calibScale : Real = 9.80665;
        attribute calibOffset : Real = 0.0;
        attribute tempCoeff : Real = 1.0e-5;
        perform action process {
            in digital : DigitalSignal = digitalIn.sig;
            in temp : TemperatureSignal = tempIn.sig;
            out reading : GravityReading = readingOut.r;
            assign reading.gravity = digital.value * calibScale * 1.0 [m/(s*s)];
            assign reading.temperature = temp.value;
            assign reading.timestamp = 0.0 [s];
        }
    }

    part def DataLogger {
        in port readingIn : ReadingInPort;
        in port pwrIn : PowerInPort;
        in port cmdIn : CmdInPort;
        out port storedOut : ReadingOutPort;
        perform action log {
            in reading : GravityReading = readingIn.r;
            out stored : GravityReading = storedOut.r;
            assign stored = reading;
        }
        exhibit state loggerStates {
            state idle;
            state logging;
            transition initial then idle;
            transition 'begin-logging'
                first idle
                accept StartCommand
                then logging;
            transition 'end-logging'
                first logging
                accept StopCommand
                then idle;
        }
    }

    part def PowerSupply {
        attribute outputVoltage :> ISQ::electricPotentialDifference = 12 [V];
        attribute maxCurrent :> ISQ::electricCurrent = 2 [A];
        out port pwrOut : PowerOutPort;
        bind pwrOut.p.voltage = outputVoltage;
    }

    part def ControlUnit {
        in port cmdIn : CmdInPort;
        in port pwrIn : PowerInPort;
        out port statusOut : StatusOutPort;
        out port cmdOut : CmdOutPort;
        exhibit state controlStates {
            state off;
            state initializing;
            state measuring;
            transition initial then off;
            transition 'start'
                first off
                accept StartCommand
                do send new StartCommand() to cmdOut
                then initializing;
            transition 'init-complete'
                first initializing
                then measuring;
            transition 'stop'
                first measuring
                accept StopCommand
                do send new StopCommand() to cmdOut
                then off;
        }
    }

    part def Gravimeter {
        in port extCmdIn : CmdInPort;
        out port extStatusOut : StatusOutPort;
        out port extDataOut : ReadingOutPort;

        part proofMass : ProofMass;
        part springSystem : SpringSystem;
        part displacementSensor : DisplacementSensor;
        part signalConditioner : SignalConditioner;
        part adc : ADC;
        part temperatureSensor : TemperatureSensor;
        part dataProcessor : DataProcessor;
        part dataLogger : DataLogger;
        part powerSupply : PowerSupply;
        part controlUnit : ControlUnit;

        connect proofMass.dispOut to displacementSensor.dispIn;
        connect displacementSensor.rawOut to signalConditioner.rawIn;
        connect signalConditioner.condOut to adc.condIn;
        connect adc.digitalOut to dataProcessor.digitalIn;
        connect temperatureSensor.tempOut to dataProcessor.tempIn;
        connect dataProcessor.readingOut to dataLogger.readingIn;
        connect dataLogger.storedOut to extDataOut;

        connect powerSupply.pwrOut to displacementSensor.pwrIn;
        connect powerSupply.pwrOut to signalConditioner.pwrIn;
        connect powerSupply.pwrOut to adc.pwrIn;
        connect powerSupply.pwrOut to temperatureSensor.pwrIn;
        connect powerSupply.pwrOut to dataProcessor.pwrIn;
        connect powerSupply.pwrOut to dataLogger.pwrIn;
        connect powerSupply.pwrOut to controlUnit.pwrIn;

        connect extCmdIn to controlUnit.cmdIn;
        connect controlUnit.cmdOut to dataLogger.cmdIn;
        connect controlUnit.statusOut to extStatusOut;
    }

    requirement def HighPrecisionRequirement {
        doc /* The gravimeter shall measure gravitational acceleration with an uncertainty of less than 1e-5 m/s^2 (approximately 1 microGal). */
        attribute maxUncertainty :> ISQ::acceleration;
    }

    requirement def TemperatureCompensationRequirement {
        doc /* All gravity readings shall be compensated for ambient temperature variations between 233 K and 323 K. */
        attribute minTemp :> ISQ::temperature;
        attribute maxTemp :> ISQ::temperature;
    }

    requirement def ContinuousOperationRequirement {
        doc /* The instrument shall operate continuously for a minimum of 72 hours without manual intervention. */
        attribute minUptime :> ISQ::time;
    }

    requirement def DataIntegrityRequirement {
        doc /* Each GravityReading shall include gravitational acceleration, timestamp, and temperature. */
    }

    requirement def PowerStabilityRequirement {
        doc /* The Power Supply shall provide a regulated voltage stable to within 1 percent of nominal under all operating conditions. */
        attribute voltageTolerance : Real = 0.01;
    }
}
