package GasMeterSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Volume :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    attribute def VolumetricFlowRate {
        :>> mRef = Volume;
        :>> tRef = ISQ::time;
        unit = SI::cubicMetre / SI::second;
    }

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Energy {
        unit = SI::joule;
    }

    attribute def BatteryCharge {
        unit = SI::ampere * SI::hour;
    }

    attribute def SignalStrength {
        unit = SI::decibel;
    }

    attribute def Currency {
        unit = SI::one;
    }

    item def NaturalGas {
        attribute gasVolume : Volume;
        attribute gasPressure : Pressure;
        attribute gasTemperature : Temperature;
        attribute flowRate : VolumetricFlowRate;
        attribute calorificValue : Energy;
    }

    item def MeterReading {
        attribute cumulativeVolume : Volume;
        attribute correctedVolume : Volume;
        attribute estimatedEnergy : Energy;
        attribute readingTimestamp : ISQ::time;
        attribute meterSerialNumber : String;
    }

    item def BillingRecord {
        attribute billedVolume : Volume;
        attribute billedEnergy : Energy;
        attribute tariffRate : Currency;
        attribute chargeAmount : Currency;
        attribute billingTimestamp : ISQ::time;
    }

    item def DiagnosticReport {
        attribute batteryRemaining : BatteryCharge;
        attribute signalStrength : SignalStrength;
        attribute tamperDetected : Boolean;
        attribute sensorFaultDetected : Boolean;
        attribute reverseFlowDetected : Boolean;
        attribute reportTimestamp : ISQ::time;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute requestedValveOpen : Boolean;
        attribute requestedReportNow : Boolean;
        attribute requestedFirmwareUpdate : Boolean;
    }

    port def GasInletPort {
        in item gasIn : NaturalGas;
    }

    port def GasOutletPort {
        out item gasOut : NaturalGas;
    }

    port def ReadingDataPort {
        out item reading : MeterReading;
        out item diagnostics : DiagnosticReport;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def BillingDataPort {
        out item billingRecord : BillingRecord;
    }

    port def ElectricalPowerPort {
        out attribute supplyVoltage : ISQ::electricPotential {
            unit = SI::volt;
        }
        out attribute availableCharge : BatteryCharge;
    }

    part def FlowMeasurementAssembly {
        port gasInlet : GasInletPort;
        port gasOutlet : GasOutletPort;

        attribute instantaneousFlow : VolumetricFlowRate;
        attribute accumulatedRawVolume : Volume;
        attribute pressureAtSensor : Pressure;
        attribute temperatureAtSensor : Temperature;
        attribute reverseFlow : Boolean;

        action measureGasFlow {
            in item gasSample : NaturalGas;
            out attribute measuredFlow : VolumetricFlowRate;
            out attribute measuredPressure : Pressure;
            out attribute measuredTemperature : Temperature;
        }

        state def FlowMeasurementStateMachine {
            state idle;
            state measuring;
            state reverseFlowDetected;
            state sensorFault;

            transition idle_to_measuring
                first idle
                then measuring;

            transition measuring_to_reverse
                first measuring
                then reverseFlowDetected
                if reverseFlow;

            transition reverse_to_measuring
                first reverseFlowDetected
                then measuring
                if not reverseFlow;

            transition measuring_to_fault
                first measuring
                then sensorFault
                if pressureAtSensor <= 0 [SI::pascal];

            transition fault_to_idle
                first sensorFault
                then idle
                if pressureAtSensor > 0 [SI::pascal];
        }

        perform measurementBehavior : FlowMeasurementStateMachine;
    }

    part def VolumeCorrectionComputer {
        attribute basePressure : Pressure = 101325 [SI::pascal];
        attribute baseTemperature : Temperature = 288.15 [SI::kelvin];
        attribute correctionFactor : Real;
        attribute correctedAccumulatedVolume : Volume;
        attribute estimatedEnergyUsed : Energy;

        action computeCorrectedVolume {
            in attribute rawVolume : Volume;
            in attribute measuredPressure : Pressure;
            in attribute measuredTemperature : Temperature;
            out attribute correctedVolume : Volume;
        }

        action estimateEnergy {
            in attribute correctedVolume : Volume;
            in attribute calorificValue : Energy;
            out attribute energy : Energy;
        }
    }

    part def ReadingRegister {
        attribute meterSerialNumber : String;
        attribute cumulativeVolume : Volume;
        attribute correctedVolume : Volume;
        attribute estimatedEnergy : Energy;
        attribute lastReadingTime : ISQ::time;

        port readingOut : ReadingDataPort;
        port billingOut : BillingDataPort;

        action createMeterReading {
            out item reading : MeterReading;
        }

        action createBillingRecord {
            in attribute tariffRate : Currency;
            out item billingRecord : BillingRecord;
        }
    }

    part def CommunicationsModule {
        port dataOut : ReadingDataPort;
        port commandIn : CommandPort;

        attribute networkRegistered : Boolean;
        attribute radioSignalStrength : SignalStrength;
        attribute lastTransmissionTime : ISQ::time;
        attribute retryCount : Integer;

        action transmitReading {
            in item reading : MeterReading;
            in item diagnostics : DiagnosticReport;
        }

        action receiveCommand {
            out item command : ControlCommand;
        }

        state def CommunicationsStateMachine {
            state offline;
            state registering;
            state connected;
            state transmitting;
            state receiveCommandMode;
            state communicationFault;

            transition offline_to_registering
                first offline
                then registering;

            transition registering_to_connected
                first registering
                then connected
                if networkRegistered;

            transition connected_to_transmitting
                first connected
                then transmitting;

            transition transmitting_to_connected
                first transmitting
                then connected
                if retryCount < 3;

            transition connected_to_receive
                first connected
                then receiveCommandMode;

            transition receive_to_connected
                first receiveCommandMode
                then connected;

            transition transmitting_to_fault
                first transmitting
                then communicationFault
                if retryCount >= 3;

            transition fault_to_registering
                first communicationFault
                then registering;
        }

        perform communicationBehavior : CommunicationsStateMachine;
    }

    part def ShutoffValve {
        port gasInlet : GasInletPort;
        port gasOutlet : GasOutletPort;

        attribute valveOpen : Boolean;
        attribute commandedOpen : Boolean;
        attribute valvePositionPercent : Real;

        action openValve {
            out attribute valveOpen : Boolean;
        }

        action closeValve {
            out attribute valveOpen : Boolean;
        }

        state def ValveStateMachine {
            state open;
            state closed;
            state closing;
            state opening;
            state valveFault;

            transition open_to_closing
                first open
                then closing
                if not commandedOpen;

            transition closing_to_closed
                first closing
                then closed
                if valvePositionPercent == 0.0;

            transition closed_to_opening
                first closed
                then opening
                if commandedOpen;

            transition opening_to_open
                first opening
                then open
                if valvePositionPercent == 100.0;

            transition moving_to_fault
                first opening
                then valveFault
                if valvePositionPercent < 0.0 or valvePositionPercent > 100.0;
        }

        perform valveBehavior : ValveStateMachine;
    }

    part def TamperDetectionAssembly {
        attribute enclosureOpen : Boolean;
        attribute magneticTamperDetected : Boolean;
        attribute excessiveVibrationDetected : Boolean;
        attribute tamperDetected : Boolean;

        action evaluateTamperCondition {
            out attribute tamperDetected : Boolean;
        }
    }

    part def BatteryPowerSupply {
        port powerOut : ElectricalPowerPort;

        attribute nominalVoltage : ISQ::electricPotential = 3.6 [SI::volt];
        attribute remainingCharge : BatteryCharge;
        attribute lowBatteryThreshold : BatteryCharge = 0.5 [SI::ampere * SI::hour];
        attribute lowBattery : Boolean;

        action supplyPower {
            out attribute voltage : ISQ::electricPotential;
        }

        action evaluateBatteryHealth {
            out attribute lowBattery : Boolean;
        }
    }

    part def GasMeter {
        port serviceGasInlet : GasInletPort;
        port customerGasOutlet : GasOutletPort;
        port readingsToUtility : ReadingDataPort;
        port utilityCommands : CommandPort;
        port billingInterface : BillingDataPort;

        part flowAssembly : FlowMeasurementAssembly;
        part correctionComputer : VolumeCorrectionComputer;
        part register : ReadingRegister;
        part communications : CommunicationsModule;
        part shutoffValve : ShutoffValve;
        part tamperAssembly : TamperDetectionAssembly;
        part battery : BatteryPowerSupply;

        attribute installed : Boolean;
        attribute active : Boolean;
        attribute maximumRatedFlow : VolumetricFlowRate = 0.0167 [SI::cubicMetre / SI::second];
        attribute minimumRatedFlow : VolumetricFlowRate = 0.0000167 [SI::cubicMetre / SI::second];
        attribute maximumOperatingPressure : Pressure = 500000 [SI::pascal];
        attribute operatingTemperatureMin : Temperature = 253.15 [SI::kelvin];
        attribute operatingTemperatureMax : Temperature = 328.15 [SI::kelvin];
        attribute measurementInterval : ISQ::time = 1 [SI::second];
        attribute reportingInterval : ISQ::time = 86400 [SI::second];

        connect serviceGasInlet to shutoffValve.gasInlet;
        connect shutoffValve.gasOutlet to flowAssembly.gasInlet;
        connect flowAssembly.gasOutlet to customerGasOutlet;
        connect register.readingOut to readingsToUtility;
        connect register.billingOut to billingInterface;
        connect communications.commandIn to utilityCommands;
        connect communications.dataOut to readingsToUtility;

        action measureAndRecordGasUse {
            in item gasFlow : NaturalGas;
            out item reading : MeterReading;

            first flowAssembly.measureGasFlow;
            then correctionComputer.computeCorrectedVolume;
            then correctionComputer.estimateEnergy;
            then register.createMeterReading;
        }

        action reportStatusToUtility {
            out item reading : MeterReading;
            out item diagnostics : DiagnosticReport;

            first register.createMeterReading;
            then tamperAssembly.evaluateTamperCondition;
            then battery.evaluateBatteryHealth;
            then communications.transmitReading;
        }

        action processUtilityCommand {
            in item command : ControlCommand;

            first communications.receiveCommand;
            then shutoffValve.openValve if command.requestedValveOpen;
            then shutoffValve.closeValve if not command.requestedValveOpen;
        }

        state def GasMeterOperatingStateMachine {
            state notInstalled;
            state commissioning;
            state normalOperation;
            state reporting;
            state commandProcessing;
            state lowBatteryOperation;
            state tamperAlarm;
            state shutoff;
            state maintenanceFault;

            transition install_meter
                first notInstalled
                then commissioning
                if installed;

            transition commission_complete
                first commissioning
                then normalOperation
                if active;

            transition normal_to_reporting
                first normalOperation
                then reporting;

            transition reporting_to_normal
                first reporting
                then normalOperation;

            transition normal_to_command
                first normalOperation
                then commandProcessing;

            transition command_to_normal
                first commandProcessing
                then normalOperation
                if shutoffValve.valveOpen;

            transition command_to_shutoff
                first commandProcessing
                then shutoff
                if not shutoffValve.valveOpen;

            transition shutoff_to_normal
                first shutoff
                then normalOperation
                if shutoffValve.valveOpen;

            transition normal_to_low_battery
                first normalOperation
                then lowBatteryOperation
                if battery.lowBattery;

            transition low_battery_to_normal
                first lowBatteryOperation
                then normalOperation
                if not battery.lowBattery;

            transition any_to_tamper
                first normalOperation
                then tamperAlarm
                if tamperAssembly.tamperDetected;

            transition tamper_to_shutoff
                first tamperAlarm
                then shutoff;

            transition normal_to_fault
                first normalOperation
                then maintenanceFault
                if flowAssembly.pressureAtSensor > maximumOperatingPressure;
        }

        perform operatingBehavior : GasMeterOperatingStateMachine;
    }

    requirement def PrimaryFunctionRequirement {
        subject meter : GasMeter;

        doc
        /*
         * The gas meter shall measure the volume of natural gas delivered from
         * the utility service inlet to the customer outlet, correct the measured
         * volume for pressure and temperature, accumulate usage over time, and
         * provide authenticated readings suitable for utility billing and
         * operational monitoring.
         */

        require constraint {
            meter.active implies
            meter.flowAssembly.accumulatedRawVolume >= 0 [SI::cubicMetre] and
            meter.register.correctedVolume >= 0 [SI::cubicMetre];
        }
    }

    requirement def FlowRangeRequirement {
        subject meter : GasMeter;

        doc
        /*
         * The gas meter shall measure gas flow within its rated operating range.
         */

        require constraint {
            meter.flowAssembly.instantaneousFlow >= meter.minimumRatedFlow and
            meter.flowAssembly.instantaneousFlow <= meter.maximumRatedFlow;
        }
    }

    requirement def PressureSafetyRequirement {
        subject meter : GasMeter;

        doc
        /*
         * The gas meter shall detect operation above maximum operating pressure
         * and enter a maintenance fault condition.
         */

        require constraint {
            meter.flowAssembly.pressureAtSensor <= meter.maximumOperatingPressure;
        }
    }

    requirement def TemperatureCorrectionRequirement {
        subject meter : GasMeter;

        doc
        /*
         * The gas meter shall correct measured volume using measured gas
         * temperature and pressure relative to base reference conditions.
         */

        require constraint {
            meter.correctionComputer.basePressure == 101325 [SI::pascal] and
            meter.correctionComputer.baseTemperature == 288.15 [SI::kelvin];
        }
    }

    requirement def ReportingRequirement {
        subject meter : GasMeter;

        doc
        /*
         * The gas meter shall generate meter readings that include cumulative
         * volume, corrected volume, estimated energy, timestamp, and meter
         * serial number.
         */

        require constraint {
            meter.reportingInterval <= 86400 [SI::second];
        }
    }

    requirement def ShutoffRequirement {
        subject meter : GasMeter;

        doc
        /*
         * The gas meter shall support remote shutoff commands and shall stop
         * downstream gas delivery when the shutoff valve is closed.
         */

        require constraint {
            not meter.shutoffValve.valveOpen implies
            meter.flowAssembly.instantaneousFlow == 0 [SI::cubicMetre / SI::second];
        }
    }

    requirement def TamperDetectionRequirement {
        subject meter : GasMeter;

        doc
        /*
         * The gas meter shall detect enclosure opening, magnetic interference,
         * and excessive vibration as tamper conditions.
         */

        require constraint {
            meter.tamperAssembly.tamperDetected ==
            (meter.tamperAssembly.enclosureOpen or
             meter.tamperAssembly.magneticTamperDetected or
             meter.tamperAssembly.excessiveVibrationDetected);
        }
    }

    requirement def BatteryLifeMonitoringRequirement {
        subject meter : GasMeter;

        doc
        /*
         * The gas meter shall monitor remaining battery charge and report a low
         * battery condition when the charge is below the configured threshold.
         */

        require constraint {
            meter.battery.lowBattery ==
            (meter.battery.remainingCharge <= meter.battery.lowBatteryThreshold);
        }
    }

    part utilityGasMeter : GasMeter {
        :>> installed = true;
        :>> active = true;

        part register {
            :>> meterSerialNumber = "GM-2026-000184";
            :>> cumulativeVolume = 0 [SI::cubicMetre];
            :>> correctedVolume = 0 [SI::cubicMetre];
            :>> estimatedEnergy = 0 [SI::joule];
        }

        part shutoffValve {
            :>> valveOpen = true;
            :>> commandedOpen = true;
            :>> valvePositionPercent = 100.0;
        }

        part battery {
            :>> remainingCharge = 8.5 [SI::ampere * SI::hour];
            :>> lowBattery = false;
        }

        part communications {
            :>> networkRegistered = true;
            :>> retryCount = 0;
            :>> radioSignalStrength = -75 [SI::decibel];
        }
    }

    satisfy PrimaryFunctionRequirement by utilityGasMeter;
    satisfy FlowRangeRequirement by utilityGasMeter;
    satisfy PressureSafetyRequirement by utilityGasMeter;
    satisfy TemperatureCorrectionRequirement by utilityGasMeter;
    satisfy ReportingRequirement by utilityGasMeter;
    satisfy ShutoffRequirement by utilityGasMeter;
    satisfy TamperDetectionRequirement by utilityGasMeter;
    satisfy BatteryLifeMonitoringRequirement by utilityGasMeter;
}