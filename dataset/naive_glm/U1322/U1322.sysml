package OneWireEnvironmentalMonitoring {

import ScalarValues::*;

package MeasurementTypes {
    value type Voltage :> Real;
    unit volt : Voltage = 1;

    value type Current :> Real;
    unit milliamp : Current = 0.001;

    value type TimeDuration :> Real;
    unit millisecond : TimeDuration = 0.001;
    unit microsecond : TimeDuration = 0.000001;

    value type TemperatureValue :> Real;
    unit celsius : TemperatureValue = 1;

    value type ResistanceValue :> Real;
    unit kiloohm : ResistanceValue = 1000;

    value type CapacitanceValue :> Real;
    unit nanofarad : CapacitanceValue = 0.000000001;
}

enum LogicLevel { HIGH; LOW; }
enum PowerMode { EXTERNAL; PARASITE; }

package ItemDefinitions {
    item def OneWireAddress {
        attribute familyCode : Integer;
        attribute serialNumber : Integer;
        attribute crc : Integer;
        attribute totalBits : Integer = 64;
    }

    item def ResetPulse {
        attribute duration : MeasurementTypes::TimeDuration;
    }

    item def PresencePulse {
        attribute duration : MeasurementTypes::TimeDuration;
    }

    item def OneWireCommand {
        attribute opcode : Integer;
        attribute isROMCommand : Boolean;
    }

    item def ReadROM :> OneWireCommand {
        :>> opcode = 0x33;
        :>> isROMCommand = true;
    }

    item def MatchROM :> OneWireCommand {
        :>> opcode = 0x55;
        :>> isROMCommand = true;
        item targetAddress : OneWireAddress;
    }

    item def SkipROM :> OneWireCommand {
        :>> opcode = 0xCC;
        :>> isROMCommand = true;
    }

    item def SearchROM :> OneWireCommand {
        :>> opcode = 0xF0;
        :>> isROMCommand = true;
    }

    item def ConvertT :> OneWireCommand {
        :>> opcode = 0x44;
        :>> isROMCommand = false;
    }

    item def ReadScratchpad :> OneWireCommand {
        :>> opcode = 0xBE;
        :>> isROMCommand = false;
    }

    item def WriteScratchpad :> OneWireCommand {
        :>> opcode = 0x4E;
        :>> isROMCommand = false;
    }

    item def ReadMemory :> OneWireCommand {
        :>> opcode = 0xF0;
        :>> isROMCommand = false;
        attribute startAddress : Integer;
    }

    item def WriteMemory :> OneWireCommand {
        :>> opcode = 0x0F;
        :>> isROMCommand = false;
        attribute targetAddress : Integer;
    }

    item def TemperatureReading {
        attribute value : MeasurementTypes::TemperatureValue;
        attribute resolution : Integer;
        attribute rawValue : Integer;
    }

    item def MemoryBlock {
        attribute address : Integer;
        attribute data : Integer[8];
        attribute length : Integer;
    }
}

package PortDefinitions {
    port def OneWireDataPort {
        in item reset : ItemDefinitions::ResetPulse;
        out item presence : ItemDefinitions::PresencePulse;
        in item command : ItemDefinitions::OneWireCommand;
        in item writeData : ItemDefinitions::MemoryBlock;
        out item readData : ItemDefinitions::MemoryBlock;
        out item temperatureData : ItemDefinitions::TemperatureReading;
    }
}

package Master {
    part def OneWireMaster {
        port busPort : PortDefinitions::OneWireDataPort;

        attribute supplyVoltage : MeasurementTypes::Voltage = 5.0 [volt];
        attribute pullupResistance : MeasurementTypes::ResistanceValue = 4.7 [kiloohm];
        attribute busCapacitance : MeasurementTypes::CapacitanceValue = 100 [nanofarad];
        attribute maxDevices : Integer = 10;
        attribute logicLowThreshold : MeasurementTypes::Voltage = 0.8 [volt];
        attribute logicHighThreshold : MeasurementTypes::Voltage = 2.2 [volt];

        attribute communicationRequested : Boolean = false;
        attribute presenceDetected : Boolean = false;
        attribute deviceSelected : Boolean = false;
        attribute convertCommandSent : Boolean = false;
        attribute readCommandSent : Boolean = false;
        attribute writeCommandSent : Boolean = false;
        attribute responseComplete : Boolean = false;
        attribute writeComplete : Boolean = false;

        part timer {
            attribute precision : MeasurementTypes::TimeDuration = 1 [microsecond];
        }

        part crcCalculator {
            attribute polynomial : Integer = 0x31;
        }

        part busDriver {
            attribute driveCurrent : MeasurementTypes::Current = 4 [milliamp];
            attribute strongPullupCurrent : MeasurementTypes::Current = 15 [milliamp];
        }

        item knownDevices : ItemDefinitions::OneWireAddress[0..*];

        action initiateBusReset {
            out resetPulse : ItemDefinitions::ResetPulse;
        }

        action sendMatchROMCommand {
            in targetAddress : ItemDefinitions::OneWireAddress;
        }

        action sendConvertCommand {
            in target : ItemDefinitions::OneWireAddress;
        }

        action readTemperature {
            in target : ItemDefinitions::OneWireAddress;
            out reading : ItemDefinitions::TemperatureReading;
        }

        action writeEEPROM {
            in target : ItemDefinitions::OneWireAddress;
            in address : Integer;
            in data : Integer[8];
        }

        action readEEPROM {
            in target : ItemDefinitions::OneWireAddress;
            in address : Integer;
            out data : Integer[8];
        }

        state masterStateMachine {
            entry action initialize {
                /* Initialize bus driver, timer, and CRC calculator */
            }

            state Idle {
                entry action releaseBus {
                    /* Release bus; pull-up resistor holds line high */
                }
            }

            state SendingReset {
                entry action driveBusLow {
                    /* Drive bus low for reset pulse duration */
                }
                attribute resetDuration : MeasurementTypes::TimeDuration = 480 [microsecond];
            }

            state DetectingPresence {
                entry action sampleBus {
                    /* Sample bus for presence pulse from slaves */
                }
                attribute sampleDelay : MeasurementTypes::TimeDuration = 70 [microsecond];
            }

            state SelectingDevice {
                entry action sendAddress {
                    /* Send Match ROM command with target device address */
                }
            }

            state SendingCommand {
                entry action sendFunctionCommand {
                    /* Send function command to selected device */
                }
            }

            state WaitingForConversion {
                entry action enableStrongPullup {
                    /* Enable strong pull-up to power parasite devices during conversion */
                }
                attribute conversionTimeout : MeasurementTypes::TimeDuration = 750 [millisecond];
            }

            state ReadingResponse {
                entry action readDataBytes {
                    /* Read data bytes from slave device */
                }
            }

            state WritingData {
                entry action writeDataBytes {
                    /* Write data bytes to slave device */
                }
            }

            state ErrorHandling {
                entry action reportError {
                    /* Report communication error and attempt recovery */
                }
            }

            transition from Idle to SendingReset when communicationRequested;
            transition from SendingReset to DetectingPresence after 480 [microsecond];
            transition from DetectingPresence to SelectingDevice when presenceDetected;
            transition from DetectingPresence to ErrorHandling when not presenceDetected;
            transition from SelectingDevice to SendingCommand when deviceSelected;
            transition from SendingCommand to WaitingForConversion when convertCommandSent;
            transition from SendingCommand to WritingData when writeCommandSent;
            transition from SendingCommand to ReadingResponse when readCommandSent;
            transition from WaitingForConversion to ReadingResponse after 750 [millisecond];
            transition from ReadingResponse to Idle when responseComplete;
            transition from WritingData to Idle when writeComplete;
            transition from ErrorHandling to Idle after 100 [millisecond];
        }
    }
}

package Slaves {
    abstract part def OneWireSlave {
        port busPort : PortDefinitions::OneWireDataPort;

        item uniqueAddress : ItemDefinitions::OneWireAddress;
        attribute powerMode : PowerMode;
        attribute familyCode : Integer;

        attribute resetPulseDetected : Boolean = false;
        attribute romCommandProcessed : Boolean = false;
        attribute functionCommandReceived : Boolean = false;
        attribute readRequested : Boolean = false;
        attribute writeRequested : Boolean = false;
        attribute transmissionComplete : Boolean = false;
        attribute dataReceived : Boolean = false;

        state slaveStateMachine {
            state Idle;
            state DetectingReset;
            state SendingPresence {
                attribute presenceDelay : MeasurementTypes::TimeDuration = 15 [microsecond];
                attribute presenceDuration : MeasurementTypes::TimeDuration = 60 [microsecond];
            }
            state ReceivingROMCommand;
            state ReceivingFunctionCommand;
            state ExecutingFunction;
            state TransmittingData;
            state ReceivingData;

            transition from Idle to DetectingReset when resetPulseDetected;
            transition from DetectingReset to SendingPresence after 15 [microsecond];
            transition from SendingPresence to ReceivingROMCommand after 60 [microsecond];
            transition from ReceivingROMCommand to ReceivingFunctionCommand when romCommandProcessed;
            transition from ReceivingFunctionCommand to ExecutingFunction when functionCommandReceived;
            transition from ExecutingFunction to TransmittingData when readRequested;
            transition from ExecutingFunction to ReceivingData when writeRequested;
            transition from TransmittingData to Idle when transmissionComplete;
            transition from ReceivingData to Idle when dataReceived;
        }
    }

    part def DS18B20 :> OneWireSlave {
        :>> familyCode = 0x28;
        attribute resolution : Integer = 12;
        attribute conversionTime : MeasurementTypes::TimeDuration = 750 [millisecond];
        attribute minOperatingTemp : MeasurementTypes::TemperatureValue = -55 [celsius];
        attribute maxOperatingTemp : MeasurementTypes::TemperatureValue = 125 [celsius];
        attribute accuracy : MeasurementTypes::TemperatureValue = 0.5 [celsius];

        attribute temperatureLSB : Integer;
        attribute temperatureMSB : Integer;
        attribute thRegister : Integer;
        attribute tlRegister : Integer;
        attribute configRegister : Integer;
        attribute crcByte : Integer;

        item currentReading : ItemDefinitions::TemperatureReading;

        attribute convertTReceived : Boolean = false;
        attribute readScratchpadReceived : Boolean = false;
        attribute scratchpadTransmitted : Boolean = false;

        action performConversion {
            in trigger : ItemDefinitions::ConvertT;
            out result : ItemDefinitions::TemperatureReading;
        }

        action readScratchpad {
            out data : Integer[9];
        }

        action writeScratchpad {
            in th : Integer;
            in tl : Integer;
            in config : Integer;
        }

        state sensorStateMachine {
            state Idle;
            state ConvertingTemperature {
                entry action startADC {
                    /* Begin temperature-to-digital conversion using internal ADC */
                }
                attribute duration : MeasurementTypes::TimeDuration = 750 [millisecond];
            }
            state ResultReady {
                entry action storeResult {
                    /* Store conversion result in scratchpad registers */
                }
            }
            state TransmittingScratchpad {
                entry action transmitData {
                    /* Transmit scratchpad contents to master */
                }
            }

            transition from Idle to ConvertingTemperature when convertTReceived;
            transition from ConvertingTemperature to ResultReady after 750 [millisecond];
            transition from ResultReady to TransmittingScratchpad when readScratchpadReceived;
            transition from TransmittingScratchpad to Idle when scratchpadTransmitted;
        }
    }

    part def DS2431 :> OneWireSlave {
        :>> familyCode = 0x2D;
        attribute memorySizeBits : Integer = 1024;
        attribute memorySizeBytes : Integer = 128;
        attribute pageSize : Integer = 8;
        attribute pageCount : Integer = 16;
        attribute writeCycleTime : MeasurementTypes::TimeDuration = 10 [millisecond];

        item memoryArray : Integer[128];

        attribute writeMemoryReceived : Boolean = false;
        attribute writeDataComplete : Boolean = false;
        attribute readMemoryReceived : Boolean = false;
        attribute readAddressReceived : Boolean = false;
        attribute readDataTransmitted : Boolean = false;

        action writeMemoryPage {
            in address : Integer;
            in data : Integer[8];
        }

        action readMemoryPage {
            in address : Integer;
            out data : Integer[8];
        }

        state memoryStateMachine {
            state Idle;
            state ReceivingWriteData;
            state Programming {
                entry action programCell {
                    /* Program EEPROM cells with received data */
                }
                attribute programTime : MeasurementTypes::TimeDuration = 10 [millisecond];
            }
            state ReceivingReadAddress;
            state TransmittingReadData {
                entry action transmitData {
                    /* Transmit requested memory data to master */
                }
            }

            transition from Idle to ReceivingWriteData when writeMemoryReceived;
            transition from ReceivingWriteData to Programming when writeDataComplete;
            transition from Programming to Idle after 10 [millisecond];
            transition from Idle to ReceivingReadAddress when readMemoryReceived;
            transition from ReceivingReadAddress to TransmittingReadData when readAddressReceived;
            transition from TransmittingReadData to Idle when readDataTransmitted;
        }
    }
}

package SystemAssembly {
    part oneWireEnvironmentalMonitoringSystem {
        part master : Master::OneWireMaster {
            :>> supplyVoltage = 5.0 [volt];
            :>> pullupResistance = 4.7 [kiloohm];
        }

        part temperatureSensor1 : Slaves::DS18B20 {
            :>> uniqueAddress.familyCode = 0x28;
            :>> uniqueAddress.serialNumber = 0x010203040506;
            :>> uniqueAddress.crc = 0x0A;
            :>> powerMode = PowerMode::PARASITE;
        }

        part temperatureSensor2 : Slaves::DS18B20 {
            :>> uniqueAddress.familyCode = 0x28;
            :>> uniqueAddress.serialNumber = 0x111213141516;
            :>> uniqueAddress.crc = 0x0B;
            :>> powerMode = PowerMode::PARASITE;
        }

        part temperatureSensor3 : Slaves::DS18B20 {
            :>> uniqueAddress.familyCode = 0x28;
            :>> uniqueAddress.serialNumber = 0x212223242526;
            :>> uniqueAddress.crc = 0x0C;
            :>> powerMode = PowerMode::EXTERNAL;
        }

        part eepromMemory : Slaves::DS2431 {
            :>> uniqueAddress.familyCode = 0x2D;
            :>> uniqueAddress.serialNumber = 0x313233343536;
            :>> uniqueAddress.crc = 0x0D;
            :>> powerMode = PowerMode::EXTERNAL;
        }

        connection busLink1 connect master.busPort to temperatureSensor1.busPort;
        connection busLink2 connect master.busPort to temperatureSensor2.busPort;
        connection busLink3 connect master.busPort to temperatureSensor3.busPort;
        connection busLink4 connect master.busPort to eepromMemory.busPort;
    }
}

package Requirements {
    requirement def OneWireSystemRequirements {
        subject system : SystemAssembly::oneWireEnvironmentalMonitoringSystem;

        requirement masterInitiatedCommunication {
            doc /* The master controller shall initiate all communication on the 1-Wire bus. No slave device shall transmit data without first being addressed by the master. */
        }

        requirement resetPresenceHandshake {
            doc /* The master shall initiate communication by issuing a reset pulse of minimum 480 microseconds duration. All slave devices on the bus shall respond with a presence pulse of 60 to 240 microseconds duration after a 15 to 60 microsecond delay. */
        }

        requirement uniqueDeviceAddressing {
            doc /* Each slave device shall possess a unique 64-bit factory-programmed ROM address consisting of an 8-bit family code, 48-bit serial number, and 8-bit CRC. */
        }

        requirement selectiveDeviceCommunication {
            doc /* The master shall selectively communicate with individual devices using the Match ROM (0x55) command followed by the target device 64-bit address. */
        }

        requirement broadcastCommunication {
            doc /* The master shall communicate with all devices simultaneously using the Skip ROM (0xCC) command. */
        }
    }

    requirement def TemperatureSensorRequirements {
        subject sensor : Slaves::DS18B20;

        requirement temperatureConversionTime {
            doc /* The DS18B20 shall complete a 12-bit temperature conversion within 750 milliseconds of receiving the Convert T (0x44) command. */
        }

        requirement temperatureRange {
            doc /* The DS18B20 shall measure temperatures in the range of minus 55 degrees Celsius to plus 125 degrees Celsius with an accuracy of plus or minus 0.5 degrees Celsius. */
        }

        requirement resultRetention {
            doc /* The DS18B20 shall retain the last conversion result in its scratchpad memory until the next conversion is initiated or power is removed. */
        }

        requirement parasitePowerOperation {
            doc /* The DS18B20 shall support parasite power mode, drawing operating current from the data line when the bus is in the high state. The master shall provide a strong pull-up during temperature conversion to supply sufficient current for parasite-powered devices. */
        }
    }

    requirement def EEPROMRequirements {
        subject memory : Slaves::DS2431;

        requirement memoryCapacity {
            doc /* The DS2431 shall provide 1024 bits (128 bytes) of non-volatile EEPROM storage organized in 16 pages of 8 bytes each. */
        }

        requirement writeCycleTime {
            doc /* The DS2431 shall complete a write cycle within 10 milliseconds of receiving the write data. */
        }

        requirement randomAccessRead {
            doc /* The master shall read data from any memory location by issuing the Read Memory command with the target address. */
        }
    }

    requirement def ElectricalRequirements {
        requirement busIdleVoltage {
            doc /* The 1-Wire bus shall be pulled to 5.0 volts through a 4.7 kiloohm pull-up resistor when no device is driving the line low. */
        }

        requirement logicLowThreshold {
            doc /* The logic low voltage on the bus shall not exceed 0.8 volts when any device drives the line low. */
        }

        requirement logicHighThreshold {
            doc /* The logic high voltage on the bus shall be at least 2.2 volts to be recognized as a logic high by all devices. */
        }

        requirement busCapacitanceLimit {
            doc /* The total bus capacitance shall not exceed 100 nanofarads to ensure reliable timing of the 1-Wire protocol. */
        }
    }

    requirement def TimingRequirements {
        requirement resetPulseLowTime {
            doc /* The master shall hold the bus low for at least 480 microseconds during the reset pulse. */
        }

        requirement presencePulseTiming {
            doc /* Slave devices shall pull the bus low for 60 to 240 microseconds after detecting the rising edge of the reset pulse, following a 15 to 60 microsecond delay. */
        }

        requirement writeSlotTiming {
            doc /* Each write slot shall be at least 60 microseconds in duration with a minimum 1 microsecond recovery time between slots. */
        }

        requirement readSlotTiming {
            doc /* The master shall sample the bus within 15 microseconds of initiating a read slot to capture the slave response. */
        }
    }
}

package Verification {
    verification verifyConversionTiming
        satisfies Requirements::TemperatureSensorRequirements::temperatureConversionTime {
        subject : SystemAssembly::oneWireEnvironmentalMonitoringSystem.temperatureSensor1;
        doc /* Verify that DS18B20 temperature conversion completes within 750 milliseconds at 12-bit resolution. */
    }

    verification verifyPresencePulse
        satisfies Requirements::OneWireSystemRequirements::resetPresenceHandshake {
        subject : SystemAssembly::oneWireEnvironmentalMonitoringSystem;
        doc /* Verify that all slave devices respond to reset pulse with presence pulse within specified timing. */
    }

    verification verifyParasitePower
        satisfies Requirements::TemperatureSensorRequirements::parasitePowerOperation {
        subject : SystemAssembly::oneWireEnvironmentalMonitoringSystem.temperatureSensor1;
        doc /* Verify parasite-powered sensor operates correctly without external VDD by using strong pull-up during conversion. */
    }

    verification verifyEEPROMWrite
        satisfies Requirements::EEPROMRequirements::writeCycleTime {
        subject : SystemAssembly::oneWireEnvironmentalMonitoringSystem.eepromMemory;
        doc /* Verify EEPROM write cycle completes within 10 milliseconds. */
    }

    verification verifyUniqueAddressing
        satisfies Requirements::OneWireSystemRequirements::uniqueDeviceAddressing {
        subject : SystemAssembly::oneWireEnvironmentalMonitoringSystem;
        doc /* Verify all slave devices have unique 64-bit ROM addresses using Search ROM enumeration. */
    }

    verification verifyBusElectrical
        satisfies Requirements::ElectricalRequirements::busIdleVoltage {
        subject : SystemAssembly::oneWireEnvironmentalMonitoringSystem;
        doc /* Verify bus idle voltage is 5.0 volts through 4.7 kiloohm pull-up resistor. */
    }
}

}
