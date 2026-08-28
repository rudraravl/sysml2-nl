package FuelLevelSensingSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQElectricity::*;
    import ISQVolume::*;

    // ---------- Value Types ----------
    value def Capacitance :> Real { unit 'F'; }
    value def Voltage :> Real { unit 'V'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def Percentage :> Real { unit '%'; }
    value def Power :> Real { unit 'W'; }
    value def ServiceLife :> Real { unit 'h'; }
    value def DigitalCount :> Integer;
    value def ErrorCount :> Integer;

    item def Fuel {
        attribute dielectricConstant : Real;
        attribute fuelType : String;
    }

    item def Air {
        attribute dielectricConstant : Real default 1.0;
    }

    item def CalibrationData {
        attribute minCapacitance : Capacitance;
        attribute maxCapacitance : Capacitance;
        attribute emptyLevel : Percentage default 0.0;
        attribute fullLevel : Percentage default 100.0;
        attribute slope : Real;
        attribute offset : Real;
    }

    item def DiagnosticInfo {
        attribute status : String;
        attribute errorCode : Integer;
        attribute timestamp : TimeValue;
    }

    // ---------- Ports ----------
    port def VehiclePowerPort {
        attribute voltage : Voltage default 12.0;
        in power : Voltage;
    }

    port def DigitalOutputPort {
        out fuelLevelPct : Percentage;
        out fuelVolume : Volume;
        out operationalStatus : String;
    }

    port def DiagnosticPort {
        out diagnosticInfo : DiagnosticInfo;
        in calibrationCommand : String;
    }

    // ---------- Parts ----------
    part def CapacitiveProbe {
        attribute submergedLength : LengthValue;
        attribute totalLength : LengthValue;
        attribute baseCapacitance : Capacitance;
        attribute fuelCapacitancePerUnitLength : Capacitance;
        out rawCapacitance : Capacitance;
        
        action measureCapacitance {
            in fuelLevel : Percentage;
            out capacitance : Capacitance;
        }
    }

    part def SignalConditioningCircuit {
        attribute gain : Real;
        attribute offsetVoltage : Voltage;
        in rawCapacitance : Capacitance;
        out analogVoltage : Voltage;
        
        action convertCapacitanceToVoltage {
            in capacitance : Capacitance;
            out voltage : Voltage;
        }
    }

    part def AnalogToDigitalConverter {
        attribute resolutionBits : Integer default 12;
        attribute referenceVoltage : Voltage default 5.0;
        in analogVoltage : Voltage;
        out digitalValue : DigitalCount;
        
        action digitize {
            in voltage : Voltage;
            out count : DigitalCount;
        }
    }

    part def SignalProcessor {
        attribute filterCoefficient : Real default 0.25;
        attribute updateRate : Frequency default 10.0;
        in digitalValue : DigitalCount;
        in calibration : CalibrationData;
        out fuelLevelPercentage : Percentage;
        out fuelVolume : Volume;
        
        action processData {
            in rawDigital : DigitalCount;
            in calib : CalibrationData;
            out filteredLevel : Percentage;
            out volume : Volume;
        }
        
        action applyLowPassFilter {
            in current : Percentage;
            in previous : Percentage;
            out filtered : Percentage;
        }
        
        action calculateFuelLevel {
            in digital : DigitalCount;
            in calib : CalibrationData;
            out level : Percentage;
        }
        
        action calculateFuelVolume {
            in level : Percentage;
            in tankCapacity : Volume;
            out volume : Volume;
        }
    }

    part def FuelTank {
        attribute capacity : Volume default 50 [L];
        attribute currentFuelLevel : Percentage;
        in fuel : Fuel;
    }

    // ---------- Requirements ----------
    requirement def AccuracyRequirement {
        doc "The system shall measure fuel level within ±1.5% accuracy."
        attribute maxError : Percentage default 1.5;
        subject fuelLevelSensingSystem : FuelLevelSensingSystem;
        require { |fuelLevelSensingSystem.measuredLevel - fuelLevelSensingSystem.actualLevel| <= maxError }
    }

    requirement def ResponsivenessRequirement {
        doc "The system shall update fuel level at least 10 times per second."
        attribute minUpdateRate : Frequency default 10.0;
        subject fuelLevelSensingSystem : FuelLevelSensingSystem;
        require { fuelLevelSensingSystem.updateRate >= minUpdateRate }
    }

    requirement def ReliabilityRequirement {
        doc "The system shall have a service life of at least 10,000 hours."
        attribute minServiceLife : ServiceLife default 10000;
        subject fuelLevelSensingSystem : FuelLevelSensingSystem;
        require { fuelLevelSensingSystem.serviceLife >= minServiceLife }
    }

    requirement def PowerRequirement {
        doc "The system shall operate on 12V vehicle power supply with low power consumption."
        attribute supplyVoltage : Voltage default 12.0;
        attribute maxPower : Power default 1.0;
        subject fuelLevelSensingSystem : FuelLevelSensingSystem;
        require { fuelLevelSensingSystem.supplyVoltage == supplyVoltage }
        require { fuelLevelSensingSystem.powerConsumption <= maxPower }
    }

    requirement def CommunicationRequirement {
        doc "The system shall communicate fuel level percentage, fuel volume, and operational status via digital output port."
        subject fuelLevelSensingSystem : FuelLevelSensingSystem;
        require { fuelLevelSensingSystem.digitalOutput.fuelLevelPct.isProvided }
        require { fuelLevelSensingSystem.digitalOutput.fuelVolume.isProvided }
        require { fuelLevelSensingSystem.digitalOutput.operationalStatus.isProvided }
    }

    requirement def DiagnosticRequirement {
        doc "The system shall provide a diagnostic port for status information and error codes."
        subject fuelLevelSensingSystem : FuelLevelSensingSystem;
        require { fuelLevelSensingSystem.diagnosticPort.diagnosticInfo.isProvided }
    }

    // ---------- State Machine ----------
    state def FuelLevelSensorStates {
        entry; then Off;

        state Off {
            entry action { /* System powered off */ }
            transition off_to_poweringUp
                first Off
                then PoweringUp
                when vehiclePower == 12.0 [V];
        }

        state PoweringUp {
            entry action { /* Initialize power rails and clocks */ }
            do action { performSelfTest(); }
            transition poweringUp_to_selfTest
                first PoweringUp
                then SelfTest;
        }

        state SelfTest {
            entry action { /* Test probe, conditioning, ADC, processor */ }
            do action { runComponentDiagnostics(); }
            transition selfTest_pass
                first SelfTest
                then Standby
                when selfTestResult == "pass";
            transition selfTest_fail
                first SelfTest
                then Fault
                when selfTestResult == "fail";
        }

        state Standby {
            entry action { /* Ready, waiting for measurement trigger */ }
            transition standby_to_measuring
                first Standby
                then Measuring
                when measurementRequested == true;
            transition standby_to_calibration
                first Standby
                then CalibrationMode
                when calibrationRequested == true;
        }

        state Measuring {
            entry action { /* Begin measurement cycle */ }
            do action {
                probe.measureCapacitance();
                conditioning.convertCapacitanceToVoltage();
                adc.digitize();
                processor.processData();
            }
            transition measuring_to_transmitting
                first Measuring
                then Transmitting
                when measurementComplete == true;
        }

        state Transmitting {
            entry action { /* Send fuel level, volume, status */ }
            do action { transmitResults(); }
            transition transmitting_to_standby
                first Transmitting
                then Standby;
        }

        state CalibrationMode {
            entry action { /* Enter calibration routine */ }
            do action { performCalibration(); }
            transition calibration_to_standby
                first CalibrationMode
                then Standby
                when calibrationComplete == true;
        }

        state Fault {
            entry action { logErrorCode(); }
            do action { /* Maintain fault state, provide diagnostics */ }
            transition fault_to_standby
                first Fault
                then Standby
                when faultCleared == true;
        }
    }

    // ---------- Main System ----------
    part def FuelLevelSensingSystem {
        attribute supplyVoltage : Voltage default 12.0;
        attribute powerConsumption : Power default 0.8;
        attribute updateRate : Frequency default 10.0;
        attribute serviceLife : ServiceLife default 12000;
        attribute measuredLevel : Percentage;
        attribute actualLevel : Percentage;
        attribute selfTestResult : String;
        attribute measurementRequested : Boolean;
        attribute measurementComplete : Boolean;
        attribute calibrationRequested : Boolean;
        attribute calibrationComplete : Boolean;
        attribute faultCleared : Boolean;
        attribute vehiclePower : Voltage;
        attribute errorLog : ErrorCount default 0;

        in power : VehiclePowerPort;
        out digitalOutput : DigitalOutputPort;
        out diagnosticPort : DiagnosticPort;

        part probe : CapacitiveProbe {
            attribute totalLength : LengthValue default 0.5 [m];
            attribute baseCapacitance : Capacitance default 10.0e-12 [F];
        }

        part conditioning : SignalConditioningCircuit {
            attribute gain : Real default 1.0e9;
            attribute offsetVoltage : Voltage default 0.0;
        }

        part adc : AnalogToDigitalConverter {
            attribute resolutionBits : Integer default 12;
            attribute referenceVoltage : Voltage default 5.0;
        }

        part processor : SignalProcessor {
            attribute filterCoefficient : Real default 0.25;
            attribute updateRate : Frequency default 10.0;
        }

        part tank : FuelTank {
            attribute capacity : Volume default 50 [L];
        }

        item calibration : CalibrationData {
            attribute minCapacitance : Capacitance default 10.0e-12 [F];
            attribute maxCapacitance : Capacitance default 100.0e-12 [F];
            attribute slope : Real default 1.11;
            attribute offset : Real default 0.0;
        }

        // Internal connections
        connection probe.rawCapacitance to conditioning.rawCapacitance;
        connection conditioning.analogVoltage to adc.analogVoltage;
        connection adc.digitalValue to processor.digitalValue;
        connection calibration to processor.calibration;

        // Bind outputs
        bind processor.fuelLevelPercentage to digitalOutput.fuelLevelPct;
        bind processor.fuelVolume to digitalOutput.fuelVolume;

        // State machine behavior
        exhibit state behavior FuelLevelSensorStates;

        action performSelfTest {
            // Verify probe continuity, conditioning output range, ADC conversion, processor integrity
        }

        action runComponentDiagnostics {
            // Detailed component checks
        }

        action transmitResults {
            // Output fuel level percentage, volume, and status
        }

        action performCalibration {
            // Apply known fuel levels and record calibration data
        }

        action logErrorCode {
            // Record error code to diagnostic memory
        }

        // Requirements satisfaction
        satisfy AccuracyRequirement by measuredLevel;
        satisfy ResponsivenessRequirement by updateRate;
        satisfy ReliabilityRequirement by serviceLife;
        satisfy PowerRequirement by supplyVoltage;
        satisfy CommunicationRequirement by digitalOutput;
        satisfy DiagnosticRequirement by diagnosticPort;
    }
}
