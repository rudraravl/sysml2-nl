package SmartDeviceModel {
    import ScalarValues::*;

    // ===== Value Types =====
    value type TempValue :> Real {
        unit "degC";
    }
    value type BatteryLevel :> Real {
        unit "percent";
    }
    value type VoltageValue :> Real {
        unit "V";
    }
    value type CurrentValue :> Real {
        unit "A";
    }
    value type FrequencyValue :> Real {
        unit "MHz";
    }
    value type TimeStampValue :> String;
    value type PowerModeValue :> String;

    // ===== Item Definitions =====
    item def TemperatureReading {
        attribute value : TempValue;
        attribute timestamp : TimeStampValue;
    }
    item def MotionReading {
        attribute detected : Boolean;
        attribute timestamp : TimeStampValue;
    }
    item def ProcessedData {
        attribute temperature : TempValue;
        attribute motionDetected : Boolean;
        attribute batteryLevel : BatteryLevel;
        attribute timestamp : TimeStampValue;
    }
    item def Command {
        attribute commandType : String;
        attribute payload : String;
    }
    item def StatusUpdate {
        attribute batteryLevel : BatteryLevel;
        attribute powerState : PowerModeValue;
        attribute message : String;
        attribute timestamp : TimeStampValue;
    }
    item def PowerModeCommand {
        attribute mode : PowerModeValue;
    }

    // ===== Port Definitions =====
    port def TempOutPort {
        out item : TemperatureReading;
    }
    port def MotionOutPort {
        out item : MotionReading;
    }
    port def DataOutPort {
        out item : ProcessedData;
    }
    port def CmdInPort {
        in item : Command;
    }
    port def StatusOutPort {
        out item : StatusUpdate;
    }
    port def DisplayInPort {
        in item : StatusUpdate;
    }
    port def NetPort {
        in item : ProcessedData;
        out item : Command;
    }
    port def PowerControlPort {
        out item : PowerModeCommand;
    }
    port def PowerControlInPort {
        in item : PowerModeCommand;
    }
    port def BatteryInfoPort {
        out attribute level : BatteryLevel;
        out attribute voltage : VoltageValue;
        out attribute charging : Boolean;
    }
    port def BatteryInfoInPort {
        in attribute level : BatteryLevel;
        in attribute voltage : VoltageValue;
        in attribute charging : Boolean;
    }
    port def ExternalPowerPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute connected : Boolean;
    }

    // ===== Part Definitions =====
    part def TemperatureSensor {
        port tempOut : TempOutPort;
        attribute samplingInterval : Real = 1.0;
        attribute minRange : TempValue = -40.0;
        attribute maxRange : TempValue = 85.0;
        attribute accuracy : TempValue = 0.5;

        action def senseTemperature() {
            out reading : TemperatureReading;
        }
    }

    part def MotionDetector {
        port motionOut : MotionOutPort;
        attribute sensitivity : Real = 0.5;
        attribute detectionRangeMeters : Real = 5.0;

        action def detectMotion() {
            out reading : MotionReading;
        }
    }

    part def Processor {
        port tempIn : TempOutPort;
        port motionIn : MotionOutPort;
        port dataOut : DataOutPort;
        port cmdIn : CmdInPort;
        port statusOut : StatusOutPort;
        port powerControlIn : PowerControlInPort;

        attribute clockSpeedMHz : Real = 80.0;
        attribute currentPowerMode : PowerModeValue = "active";
        attribute firmwareVersion : String = "1.0.0";

        action def processData(in temp : TemperatureReading, in motion : MotionReading, in battLevel : BatteryLevel) {
            out data : ProcessedData;
        }
        action def executeCommand(in cmd : Command) {
        }
        action def generateStatus(in battLevel : BatteryLevel, in pState : PowerModeValue) {
            out status : StatusUpdate;
        }
        action def handlePowerMode(in modeCmd : PowerModeCommand) {
        }
    }

    part def WirelessModule {
        port netPort : NetPort;
        port externalNet : NetPort;
        attribute frequency : FrequencyValue = 2400.0;
        attribute protocol : String = "WiFi";
        attribute txPowerdBm : Real = 15.0;
        attribute encryptionEnabled : Boolean = true;

        action def transmit(in data : ProcessedData) {
        }
        action def receive() {
            out cmd : Command;
        }
    }

    part def Battery {
        port powerInfoOut : BatteryInfoPort;
        port chargePort : ExternalPowerPort;

        attribute level : BatteryLevel = 100.0;
        attribute capacitymAh : Real = 2000.0;
        attribute nominalVoltage : VoltageValue = 3.7;
        attribute lowThreshold : BatteryLevel = 20.0;
        attribute criticalThreshold : BatteryLevel = 10.0;
        attribute chargingThreshold : BatteryLevel = 90.0;
        attribute isCharging : Boolean = false;

        action def discharge() {
        }
        action def charge() {
        }
        action def monitorLevel() {
            out currentLevel : BatteryLevel;
        }
    }

    part def Display {
        port displayIn : DisplayInPort;
        attribute backlightEnabled : Boolean = true;
        attribute resolution : String = "128x64";
        attribute type : String = "OLED";

        action def show(in status : StatusUpdate) {
        }
        action def clearScreen() {
        }
    }

    part def PowerManager {
        port batteryMonitor : BatteryInfoInPort;
        port processorControl : PowerControlPort;
        port chargeDetect : ExternalPowerPort;

        attribute currentLevel : BatteryLevel = 100.0;
        attribute lowThreshold : BatteryLevel = 20.0;
        attribute criticalThreshold : BatteryLevel = 10.0;
        attribute chargingThreshold : BatteryLevel = 90.0;
        attribute externalPowerConnected : Boolean = false;
        attribute activeMode : PowerModeValue = "active";

        action def setPowerMode(in mode : PowerModeValue) {
        }
        action def updateBatteryLevel(in level : BatteryLevel) {
        }
        action def checkExternalPower() {
            out connected : Boolean;
        }

        state defenum PowerState {
            active;
            idle;
            sleep;
            charging;
        }

        state PowerManagement {
            state active {
                entry perform setPowerMode("active");
                do perform updateBatteryLevel(currentLevel);
            }
            state idle {
                entry perform setPowerMode("idle");
                do perform updateBatteryLevel(currentLevel);
            }
            state sleep {
                entry perform setPowerMode("sleep");
                do perform updateBatteryLevel(currentLevel);
            }
            state charging {
                entry perform setPowerMode("charging");
                do perform updateBatteryLevel(currentLevel);
            }

            transition first to active;

            transition active_to_idle
                from active to idle
                when currentLevel < lowThreshold and not externalPowerConnected;

            transition idle_to_sleep
                from idle to sleep
                when currentLevel < criticalThreshold and not externalPowerConnected;

            transition active_to_charging
                from active to charging
                when externalPowerConnected;

            transition idle_to_charging
                from idle to charging
                when externalPowerConnected;

            transition sleep_to_charging
                from sleep to charging
                when externalPowerConnected;

            transition charging_to_active
                from charging to active
                when currentLevel >= chargingThreshold and not externalPowerConnected;

            transition sleep_to_active
                from sleep to active
                when currentLevel >= chargingThreshold and not externalPowerConnected;

            transition idle_to_active
                from idle to active
                when currentLevel >= chargingThreshold and not externalPowerConnected;
        }
    }

    // ===== Main Smart Device Assembly =====
    part def SmartDevice {
        port externalNet : NetPort;
        port externalPower : ExternalPowerPort;

        part processor : Processor;
        part tempSensor : TemperatureSensor;
        part motionDetector : MotionDetector;
        part wireless : WirelessModule;
        part battery : Battery;
        part display : Display;
        part powerManager : PowerManager;

        // Sensor data to processor
        connect tempSensor.tempOut to processor.tempIn;
        connect motionDetector.motionOut to processor.motionIn;

        // Processor data to wireless for transmission
        connect processor.dataOut to wireless.netPort;

        // Wireless commands to processor
        connect wireless.netPort to processor.cmdIn;

        // Processor status to display
        connect processor.statusOut to display.displayIn;

        // Battery info to power manager
        connect battery.powerInfoOut to powerManager.batteryMonitor;

        // Power manager control to processor
        connect powerManager.processorControl to processor.powerControlIn;

        // External power delegation to battery and power manager
        connect externalPower to battery.chargePort;
        connect externalPower to powerManager.chargeDetect;

        // Wireless external network delegation
        connect wireless.externalNet to externalNet;
    }

    // ===== Requirements =====
    requirement def EnvironmentalMonitoringRequirement {
        subject device : SmartDevice;
        attribute samplingIntervalSeconds : Real = 1.0;
        attribute tempRangeMin : TempValue = -40.0;
        attribute tempRangeMax : TempValue = 85.0;
        objective {
            doc "The device shall continuously monitor environmental temperature and motion at the specified sampling interval within the defined temperature range.";
        }
    }

    requirement def WirelessCommunicationRequirement {
        subject device : SmartDevice;
        attribute protocol : String = "WiFi";
        attribute minTxPowerdBm : Real = 10.0;
        objective {
            doc "The device shall transmit processed environmental data wirelessly and receive commands from an external user or system.";
        }
    }

    requirement def PowerManagementRequirement {
        subject device : SmartDevice;
        attribute lowThreshold : BatteryLevel = 20.0;
        attribute criticalThreshold : BatteryLevel = 10.0;
        attribute chargingThreshold : BatteryLevel = 90.0;
        objective {
            doc "The device shall automatically transition between active, idle, sleep, and charging power modes based on battery level and external power connection to conserve energy and ensure extended operation.";
        }
    }

    requirement def BatteryLifeRequirement {
        subject device : SmartDevice;
        attribute minOperatingHours : Real = 168.0;
        objective {
            doc "The device shall operate autonomously for at least 168 hours on a single full charge under normal operating conditions.";
        }
    }

    requirement def AutonomousOperationRequirement {
        subject device : SmartDevice;
        objective {
            doc "The device shall operate autonomously without manual intervention, automatically sensing, processing, communicating, and managing power.";
        }
    }

    requirement def DisplayRequirement {
        subject device : SmartDevice;
        objective {
            doc "The device shall display current status, battery level, and sensor data on its integrated display.";
        }
    }

    requirement def CommandExecutionRequirement {
        subject device : SmartDevice;
        objective {
            doc "The device shall receive and execute commands sent over the wireless network from an authorized external user or system.";
        }
    }

    requirement envMonReq : EnvironmentalMonitoringRequirement;
    requirement wirelessReq : WirelessCommunicationRequirement;
    requirement powerMgmtReq : PowerManagementRequirement;
    requirement batteryLifeReq : BatteryLifeRequirement;
    requirement autoOpReq : AutonomousOperationRequirement;
    requirement displayReq : DisplayRequirement;
    requirement cmdExecReq : CommandExecutionRequirement;

    // ===== Satisfaction Relationships =====
    satisfy envMonReq by tempSensor.senseTemperature;
    satisfy envMonReq by motionDetector.detectMotion;
    satisfy wirelessReq by wireless.transmit;
    satisfy wirelessReq by wireless.receive;
    satisfy powerMgmtReq by powerManager.PowerManagement;
    satisfy displayReq by display.show;
    satisfy cmdExecReq by processor.executeCommand;
    satisfy autoOpReq by SmartDevice;
}
