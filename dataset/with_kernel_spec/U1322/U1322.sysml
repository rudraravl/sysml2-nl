package OneWireSystem {
    private import ISQ::TemperatureValue;
    private import ISQ::DurationValue;
    private import SI::s;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;

    attribute def ROMAddress {
        attribute id : String;
    }
    attribute def ResetPulse;
    attribute def PresencePulse;
    attribute def SkipRomCommand;
    attribute def MatchRomCommand;
    attribute def ConvertTCommand;
    attribute def ReadScratchpadCommand;
    attribute def WriteScratchpadCommand;
    attribute def ReadMemoryCommand;
    attribute def WriteMemoryCommand;
    attribute def TempData {
        attribute value : TemperatureValue;
    }
    attribute def MemoryData {
        attribute address : Integer;
        attribute data : Integer;
    }

    action def ConvertTemperature {
        out temp : TemperatureValue;
    }
    action def ReadMemory {
        in addr : Integer;
        out data : Integer;
    }
    action def WriteMemory {
        in addr : Integer;
        in data : Integer;
    }

    connection def OneWireBus {
        end master;
        end slaves [0..*];
    }

    abstract part def SlaveDevice {
        attribute romAddress : ROMAddress;
        attribute parasitePowered : Boolean = false;
        port oneWirePort {
            in reset : ResetPulse;
            out presence : PresencePulse;
            in skipRom : SkipRomCommand;
            in matchRom : MatchRomCommand;
            in convertT : ConvertTCommand;
            in readScratchpad : ReadScratchpadCommand;
            in writeScratchpad : WriteScratchpadCommand;
            in readMem : ReadMemoryCommand;
            in writeMem : WriteMemoryCommand;
            out tempData : TempData;
            out memData : MemoryData;
        }
        exhibit state slaveStates {
            entry; then idle;
            state idle;
            transition detectReset
                first idle
                accept ResetPulse
                do send new PresencePulse() to oneWirePort
                then commandWait;
            state commandWait;
            transition startConversion
                first commandWait
                accept ConvertTCommand
                then converting;
            transition readResult
                first commandWait
                accept ReadScratchpadCommand
                then idle;
            transition writeMem
                first commandWait
                accept WriteMemoryCommand
                then idle;
            transition readMemCmd
                first commandWait
                accept ReadMemoryCommand
                then idle;
            state converting {
                entry action convertTemp : ConvertTemperature;
            }
            transition finishConversion
                first converting
                accept after 0.75 [s]
                then resultReady;
            state resultReady;
            transition sendResult
                first resultReady
                accept ReadScratchpadCommand
                do send new TempData() to oneWirePort
                then idle;
        }
    }

    part def DS18B20 :> SlaveDevice {
        attribute conversionTime : DurationValue = 0.75 [s];
        attribute temperature : TemperatureValue;
    }

    part def DS2431 :> SlaveDevice {
        attribute memorySize : Integer = 1024;
        attribute memory : Integer[1024];
    }

    part def MasterController {
        port oneWirePort {
            out reset : ResetPulse;
            in presence : PresencePulse;
            out skipRom : SkipRomCommand;
            out matchRom : MatchRomCommand;
            out convertT : ConvertTCommand;
            out readScratchpad : ReadScratchpadCommand;
            out writeScratchpad : WriteScratchpadCommand;
            out readMem : ReadMemoryCommand;
            out writeMem : WriteMemoryCommand;
            in tempData : TempData;
            in memData : MemoryData;
        }
        exhibit state masterStates {
            entry; then idle;
            state idle;
            transition initComm
                first idle
                do send new ResetPulse() to oneWirePort
                then waitForPresence;
            state waitForPresence;
            transition presenceDetected
                first waitForPresence
                accept PresencePulse
                then addressing;
            state addressing;
            transition issueSkipRom
                first addressing
                do send new SkipRomCommand() to oneWirePort
                then skipRomSent;
            state skipRomSent;
            transition issueConvert
                first skipRomSent
                do send new ConvertTCommand() to oneWirePort
                then conversionWait;
            state conversionWait;
            transition requestRead
                first conversionWait
                accept after 0.75 [s]
                do send new ReadScratchpadCommand() to oneWirePort
                then readWait;
            state readWait;
            transition done
                first readWait
                accept TempData
                then idle;
        }
    }

    part system {
        part master : MasterController;
        part tempSensor1 : DS18B20 {
            attribute romAddress : ROMAddress { id = "28-000004A1B2"; }
            attribute parasitePowered = true;
        }
        part tempSensor2 : DS18B20 {
            attribute romAddress : ROMAddress { id = "28-000004A3C4"; }
            attribute parasitePowered = true;
        }
        part tempSensor3 : DS18B20 {
            attribute romAddress : ROMAddress { id = "28-000004A5D6"; }
            attribute parasitePowered = false;
        }
        part eeprom : DS2431 {
            attribute romAddress : ROMAddress { id = "2D-00000001E2"; }
        }

        connection bus : OneWireBus
            connect master.oneWirePort to (tempSensor1.oneWirePort, tempSensor2.oneWirePort, tempSensor3.oneWirePort, eeprom.oneWirePort);
    }

    requirement def SingleDataLineRequirement {
        doc /* The system shall use a single data wire plus ground reference for all communication between master and slave devices. */
    }
    requirement def UniqueAddressRequirement {
        doc /* Each slave device shall have a unique 64-bit factory-programmed ROM address. */
    }
    requirement def ParasitePowerRequirement {
        doc /* At least two temperature sensors shall support parasite power, drawing operating current from the data line. */
    }
    requirement def MasterInitiatedCommunicationRequirement {
        doc /* All communication on the 1-Wire bus shall be initiated by the master controller via a reset pulse. */
    }
    requirement def ConversionTimingRequirement {
        doc /* Temperature conversion shall complete within 750 milliseconds. */
    }
    requirement def ReliableCommunicationRequirement {
        doc /* The system shall operate under strict timing and electrical rules to ensure reliable communication. */
    }
}
