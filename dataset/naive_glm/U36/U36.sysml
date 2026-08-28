package TherapeuticNMESDevice {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value types with units =====

    value def Current :> Real { unit 'mA'; }
    value def Frequency :> Real { unit 'Hz'; }
    value def PulseWidth :> Real { unit 'us'; }
    value def Voltage :> Real { unit 'V'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Pressure :> Real { unit 'kPa'; }
    value def Duration :> Real { unit 'min'; }
    value def Charge :> Real { unit 'mAh'; }
    value def Power :> Real { unit 'mW'; }

    // ===== Enumerations =====

    enum def CommandKind { START; STOP; ADJUST; QUERY; EMERGENCY_STOP; }
    enum def SessionStateKind { IDLE; PRE_OP_CHECK; ACTIVE; PAUSED; FAULT; SHUTDOWN; }
    enum def FaultKind { NONE; OVER_TEMP; OVER_PRESSURE; OVER_CURRENT; LOW_BATTERY; INVALID_COMMAND; COMMS_LOSS; }
    enum def TherapyPattern { CONSTANT; SURGE; RAMP; RECIPROCAL; }

    // ===== Item definitions =====

    item def WirelessCommand {
        attribute kind : CommandKind;
        attribute intensity : Current[0..1];
        attribute frequency : Frequency[0..1];
        attribute pulseWidth : PulseWidth[0..1];
        attribute pattern : TherapyPattern[0..1];
        attribute duration : Duration[0..1];
        attribute sessionId : Integer[0..1];
    }

    item def StatusReport {
        attribute sessionId : Integer;
        attribute state : SessionStateKind;
        attribute batteryLevel : Charge;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute elapsed : Duration;
        attribute fault : FaultKind;
    }

    item def StimulationSettings {
        attribute intensity : Current;
        attribute frequency : Frequency;
        attribute pulseWidth : PulseWidth;
        attribute pattern : TherapyPattern;
        attribute duration : Duration;
    }

    item def SensorReading {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute loadImpedance : Real; // ohm
    }

    item def ElectricalPulse {
        attribute amplitude : Current;
        attribute width : PulseWidth;
        attribute frequency : Frequency;
    }

    // ===== Port definitions =====

    port def BLEPort {
        attribute in commands : WirelessCommand[*];
        attribute out status : StatusReport[*];
    }

    port def CommandPort {
        attribute in settings : StimulationSettings[*];
        attribute out feedback : SensorReading[*];
    }

    port def PowerPort {
        attribute out supply : Voltage;
        attribute in demand : Power;
    }

    port def SensorPort {
        attribute out readings : SensorReading[*];
    }

    port def SafetyPort {
        attribute out override : Boolean;
        attribute out fault : FaultKind;
    }

    port def ElectrodePort {
        attribute out pulse : ElectricalPulse[*];
    }

    port def BatteryPort {
        attribute out voltage : Voltage;
        attribute in chargeCurrent : Current;
    }

    // ===== Requirements =====

    requirement def DeviceRequirements {

        requirement BiocompatibleEnclosure {
            doc /* The device shall be housed in medical-grade silicone with antimicrobial coating. */
            subject device : TherapeuticNMESDevice;
            attribute material : String = "medical-grade silicone";
            attribute coating : String = "antimicrobial";
        }

        requirement WirelessControl {
            doc /* The device shall accept commands via Bluetooth Low Energy. */
            subject device : TherapeuticNMESDevice;
            attribute protocol : String = "BLE";
        }

        requirement BatteryLife {
            doc /* The device shall provide at least 3 hours of continuous operation on full charge. */
            subject device : TherapeuticNMESDevice;
            attribute minRuntime : Duration = 180 [min];
        }

        requirement SafetyOverride {
            doc /* Safety monitoring shall override controller and trigger immediate shutdown on threshold violation. */
            subject device : TherapeuticNMESDevice;
        }

        requirement StimulationAccuracy {
            doc /* Stimulation generator shall deliver current within +/- 0.5 mA of commanded value. */
            subject device : TherapeuticNMESDevice;
            attribute tolerance : Current = 0.5 [mA];
        }
    }

    // ===== Part definitions =====

    part def ControllerUnit {

        port ble : BLEPort;
        port stimCmd : CommandPort;
        port powerIn : PowerPort;
        port safetyIn : SafetyPort;

        attribute currentSettings : StimulationSettings;
        attribute sessionState : SessionStateKind = SessionStateKind::IDLE;
        attribute sessionId : Integer = 0;
        attribute elapsed : Duration = 0 [min];

        attribute maxIntensity : Current = 100 [mA];
        attribute maxFrequency : Frequency = 100 [Hz];
        attribute maxPulseWidth : PulseWidth = 400 [us];
        attribute maxDuration : Duration = 60 [min];

        state def ControllerBehavior {

            entry; then Idle;

            state Idle {
                entry { sessionState = SessionStateKind::IDLE; }
                accept ble.commands[kind == CommandKind::START]
                    then PreOpCheck;
            }

            state PreOpCheck {
                entry { sessionState = SessionStateKind::PRE_OP_CHECK; }
                do { performPreOpCheck(); }
                accept PreOpCheckPassed then Active;
                accept PreOpCheckFailed then Fault;
            }

            state Active {
                entry { sessionState = SessionStateKind::ACTIVE; }
                do { deliverTherapy(); }
                accept ble.commands[kind == CommandKind::STOP] then Idle;
                accept ble.commands[kind == CommandKind::ADJUST] then Active;
                accept safetyIn.override then Shutdown;
                accept SessionComplete then Idle;
            }

            state Fault {
                entry { sessionState = SessionStateKind::FAULT; }
                accept ble.commands[kind == CommandKind::STOP] then Idle;
            }

            state Shutdown {
                entry { sessionState = SessionStateKind::SHUTDOWN; }
                do { emergencyShutdown(); }
                then Idle;
            }
        }

        action performPreOpCheck {
            in sensors : SensorReading;
            out pass : Boolean;
        }

        action deliverTherapy {
            out settings : StimulationSettings;
        }

        action emergencyShutdown {}

        action validateCommand {
            in cmd : WirelessCommand;
            out valid : Boolean;
        }

        action generateStatus {
            out report : StatusReport;
        }
    }

    part def StimulationGenerator {

        port cmdIn : CommandPort;
        port electrodeOut : ElectrodePort;
        port powerIn : PowerPort;
        port sensorOut : SensorPort;

        attribute activeSettings : StimulationSettings;
        attribute measuredImpedance : Real;
        attribute deliveredCurrent : Current;

        state def GeneratorBehavior {
            entry; then Off;

            state Off {
                accept cmdIn.settings then Generating;
            }

            state Generating {
                entry { applySettings(); }
                do { generatePulse(); }
                accept StopGenerating then Off;
            }
        }

        action applySettings {
            in s : StimulationSettings;
        }

        action generatePulse {
            out p : ElectricalPulse;
        }

        action adjustOutput {
            in feedback : SensorReading;
        }
    }

    part def PowerManagementSystem {

        port battery : BatteryPort;
        port supply1 : PowerPort;
        port supply2 : PowerPort;
        port supply3 : PowerPort;
        port supply4 : PowerPort;

        attribute batteryCapacity : Charge = 800 [mAh];
        attribute batteryLevel : Charge = 800 [mAh];
        attribute supplyVoltage : Voltage = 3.3 [V];
        attribute charging : Boolean = false;
        attribute minOperationalLevel : Charge = 50 [mAh];

        state def PowerBehavior {
            entry; then Discharging;

            state Discharging {
                do { monitorBattery(); }
                accept battery.chargeCurrent then Charging;
                accept LowBattery then Critical;
            }

            state Charging {
                do { chargeBattery(); }
                accept ChargeComplete then Discharging;
            }

            state Critical {
                entry { raiseLowBatteryAlert(); }
                accept battery.chargeCurrent then Charging;
            }
        }

        action monitorBattery {
            out level : Charge;
        }

        action chargeBattery {}

        action raiseLowBatteryAlert {}
    }

    part def SafetyMonitoringSystem {

        port sensorIn : SensorPort;
        port controllerOut : SafetyPort;
        port powerIn : PowerPort;

        attribute tempThreshold : Temperature = 42 [degC];
        attribute pressureThreshold : Pressure = 60 [kPa];
        attribute currentThreshold : Current = 110 [mA];
        attribute lastReading : SensorReading;
        attribute activeFault : FaultKind = FaultKind::NONE;

        state def SafetyBehavior {
            entry; then Monitoring;

            state Monitoring {
                do { evaluateSensors(); }
                accept ThresholdExceeded then Override;
            }

            state Override {
                entry { triggerOverride(); }
                then Monitoring;
            }
        }

        action evaluateSensors {
            in reading : SensorReading;
            out fault : FaultKind;
        }

        action triggerOverride {
            out override : Boolean = true;
            out fault : FaultKind;
        }
    }

    part def BiocompatibleEnclosure {
        attribute material : String = "medical-grade silicone";
        attribute coating : String = "antimicrobial";
        attribute ipRating : String = "IP68";
        attribute maxExternalPressure : Pressure = 100 [kPa];
    }

    part def ElectrodeArray {
        port pulseIn : ElectrodePort;
        attribute contactArea : Real = 200; // mm^2
        attribute impedance : Real = 500; // ohm
    }

    part def BLEAntenna {
        port ble : BLEPort;
        attribute protocol : String = "BLE 5.2";
        attribute range : Real = 10; // m
    }

    part def TemperatureSensor {
        port out : SensorPort;
        attribute range : Temperature = 0..70 [degC];
        attribute accuracy : Temperature = 0.5 [degC];
    }

    part def PressureSensor {
        port out : SensorPort;
        attribute range : Pressure = 0..200 [kPa];
        attribute accuracy : Pressure = 2 [kPa];
    }

    // ===== Top-level device =====

    part def TherapeuticNMESDevice {

        satisfy DeviceRequirements;

        part enclosure : BiocompatibleEnclosure;
        part antenna : BLEAntenna;
        part controller : ControllerUnit;
        part generator : StimulationGenerator;
        part power : PowerManagementSystem;
        part safety : SafetyMonitoringSystem;
        part electrodes : ElectrodeArray;
        part tempSensor : TemperatureSensor;
        part pressureSensor : PressureSensor;

        // Wireless link
        connect antenna.ble to controller.ble;

        // Controller to generator
        connect controller.stimCmd to generator.cmdIn;
        connect generator.sensorOut to controller.stimCmd;

        // Generator to electrodes
        connect generator.electrodeOut to electrodes.pulseIn;

        // Power distribution
        connect power.battery to power.battery;
        connect power.supply1 to controller.powerIn;
        connect power.supply2 to generator.powerIn;
        connect power.supply3 to safety.powerIn;

        // Sensors to safety
        connect tempSensor.out to safety.sensorIn;
        connect pressureSensor.out to safety.sensorIn;

        // Safety override to controller
        connect safety.controllerOut to controller.safetyIn;

        attribute nominalRuntime : Duration = 180 [min];
        attribute therapyModes : TherapyPattern[*] = {TherapyPattern::CONSTANT, TherapyPattern::SURGE, TherapyPattern::RAMP, TherapyPattern::RECIPROCAL};
    }

    // ===== Use case / scenario =====

    action def TherapySessionScenario {

        in device : TherapeuticNMESDevice;
        in cmd : WirelessCommand;

        action preOperationCheck {
            out cleared : Boolean;
        }

        action startTherapy {
            out settings : StimulationSettings;
        }

        action monitorSession {
            out status : StatusReport;
        }

        action concludeSession {}

        then;

        // Flow
        flow from preOperationCheck.cleared to startTherapy;
        flow from startTherapy.settings to monitorSession;
        flow from monitorSession.status to concludeSession;
    }

}
