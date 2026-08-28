package MedicalInfusionPump {
    import ISQ::*;
    import ScalarValues::*;

    // Value Types
    value type FlowRate :> Real {
        unit 'mL/hr';
    }
    value type Volume :> Real {
        unit 'mL';
    }
    value type HeartRate :> Real {
        unit 'bpm';
    }
    value type BloodPressure :> Real {
        unit 'mmHg';
    }
    value type Temperature :> Real {
        unit 'degC';
    }
    value type BatteryLevel :> Real {
        unit '%';
    }
    value type Time :> Real {
        unit 's';
    }

    // Item Types
    item def Medication;
    item def VitalSigns {
        attribute hr : HeartRate;
        attribute bp : BloodPressure;
        attribute temp : Temperature;
    }
    item def AlarmSignal;
    item def StatusUpdate;

    // Requirements
    requirement def HighPrecisionDelivery {
        doc /* The pump shall deliver medication with a precision of +/- 2%. */
        attribute precision : Real = 0.02;
    }
    requirement def LongBatteryLife {
        doc /* The battery shall last for at least 24 hours of continuous use. */
        attribute minDuration : Time = 86400;
    }
    requirement def RapidAlarmResponse {
        doc /* The system shall trigger an alarm within 2 seconds of detecting an unsafe condition. */
        attribute maxResponseTime : Time = 2;
    }

    // Port Definitions
    port def MedicationOut {
        out item med : Medication;
    }
    port def VitalSignsOut {
        out item vitals : VitalSigns;
    }
    port def CommandPort {
        in attribute targetFlowRate : FlowRate;
        in attribute targetVolume : Volume;
        in attribute command : String;
    }
    port def DisplayPort {
        in item alarm : AlarmSignal;
        in item status : StatusUpdate;
    }
    port def PowerPort {
        out attribute level : BatteryLevel;
    }

    // Part Definitions
    part def Sensor {
        port vitalOut : VitalSignsOut;
        attribute measuredVitals : VitalSigns;
        
        action def measureVitals {
            // Simulate measuring vitals
        }
    }

    part def Battery {
        port powerOut : PowerPort;
        attribute currentLevel : BatteryLevel = 100;
        
        state def BatteryLifecycle {
            entry; then Full;
            state Full;
            transition from Full to Depleting
                when currentLevel < 100;
            state Depleting;
            transition from Depleting to Low
                when currentLevel < 20;
            state Low;
            transition from Low to Depleted
                when currentLevel == 0;
            state Depleted;
        }
    }

    part def PumpMechanism {
        port cmdIn : CommandPort;
        port medOut : MedicationOut;
        attribute currentFlowRate : FlowRate;
        attribute deliveredVolume : Volume = 0;
        attribute pumpCommand : String;
        
        state def PumpOperation {
            entry; then Idle;
            state Idle;
            transition from Idle to Priming
                when pumpCommand == "prime";
            state Priming;
            transition from Priming to Infusing
                when pumpCommand == "infuse";
            state Infusing;
            transition from Infusing to Paused
                when pumpCommand == "pause";
            state Paused;
            transition from Paused to Infusing
                when pumpCommand == "infuse";
            transition from Infusing to Idle
                when deliveredVolume >= cmdIn.targetVolume;
        }
    }

    part def UserInterface {
        port displayIn : DisplayPort;
        
        action def updateDisplay {
            in alarm : AlarmSignal;
            in status : StatusUpdate;
        }
    }

    part def ControlUnit {
        port vitalIn : VitalSignsOut;
        port cmdOut : CommandPort;
        port displayOut : DisplayPort;
        port powerIn : PowerPort;
        
        attribute targetFlowRate : FlowRate;
        attribute targetVolume : Volume;
        attribute resetCommand : Boolean = false;
        
        action def analyzeVitals {
            in vitals : VitalSigns;
        }
        action def manageTherapy {
            // Manage therapy schedule
        }
        action def ensureSafety {
            // Ensure safe operation
        }
    }

    part def InfusionPumpSystem {
        part controlUnit : ControlUnit;
        part battery : Battery;
        part pump : PumpMechanism;
        part sensor : Sensor;
        part ui : UserInterface;
        
        connection battery.powerOut to controlUnit.powerIn;
        connection sensor.vitalOut to controlUnit.vitalIn;
        connection controlUnit.cmdOut to pump.cmdIn;
        connection controlUnit.displayOut to ui.displayIn;
        
        state def SystemOperation {
            entry; then Standby;
            state Standby;
            transition from Standby to ActiveTherapy
                when controlUnit.targetFlowRate > 0;
            state ActiveTherapy;
            transition from ActiveTherapy to Alarm
                when battery.currentLevel < 20 or sensor.measuredVitals.hr > 120;
            transition from ActiveTherapy to Completed
                when pump.deliveredVolume >= controlUnit.targetVolume;
            state Alarm;
            transition from Alarm to Standby
                when controlUnit.resetCommand == true;
            state Completed;
            transition from Completed to Standby
                when controlUnit.resetCommand == true;
        }
        
        satisfy HighPrecisionDelivery by pump;
        satisfy LongBatteryLife by battery;
        satisfy RapidAlarmResponse by controlUnit;
    }
}
