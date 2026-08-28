package ResidentialSmokeDetector {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        value type SmokeConcentrationValue :> ScalarValues::Real;
        value type SoundPressureLevelValue :> ScalarValues::Real;
        value type BatteryChargeValue :> ScalarValues::Real;

        attribute def SmokeDetected;
        attribute def LowBatteryWarning;
        attribute def TestCommand;
        attribute def ResetCommand;

        action def MonitorAir { out smokeLevel : SmokeConcentrationValue; }
        action def CheckBattery { out chargeLevel : BatteryChargeValue; }
        action def ActivateSiren;
        action def FlashLED;
        action def PerformSelfTest;

        port def SmokeSensorPort {
            out attribute smokeReading : SmokeConcentrationValue;
        }
        port def AlarmPort {
            out attribute activateSiren : Boolean;
            out attribute activateLED : Boolean;
        }
        port def BatteryPort {
            out attribute chargeReading : BatteryChargeValue;
        }
        port def UserPort {
            out attribute testCmd : TestCommand;
            out attribute resetCmd : ResetCommand;
        }

        part def OpticalSensor {
            port sensorOut : SmokeSensorPort;
            perform action 'monitor air' : MonitorAir;
        }

        part def AudibleAlarm {
            attribute minSoundLevel : SoundPressureLevelValue = 85.0;
            port alarmIn : ~AlarmPort;
            perform action 'activate siren' : ActivateSiren;
        }

        part def VisualAlert {
            port alertIn : ~AlarmPort;
            perform action 'flash led' : FlashLED;
        }

        part def BatteryPack {
            port batteryOut : BatteryPort;
            perform action 'check battery' : CheckBattery;
        }

        part def ControlInterface {
            port userOut : UserPort;
        }

        part def ControlUnit {
            port sensorIn : ~SmokeSensorPort;
            port alarmOut : AlarmPort;
            port batteryIn : ~BatteryPort;
            port userIn : ~UserPort;
            attribute smokeThreshold : SmokeConcentrationValue = 50.0;
            attribute lowBatteryThreshold : BatteryChargeValue = 10.0;
            exhibit state 'control states' : ControlStates;
        }

        state def ControlStates;

        part def SmokeDetector {
            part controlUnit : ControlUnit;
            part opticalSensor : OpticalSensor;
            part audibleAlarm : AudibleAlarm;
            part visualAlert : VisualAlert;
            part battery : BatteryPack;
            part userInterface : ControlInterface;
            exhibit state 'detector states' : DetectorStates;
        }

        state def DetectorStates;
    }

    package Usages {
        private import Definitions::*;

        action 'monitor air' : MonitorAir;
        action 'check battery' : CheckBattery;
        action 'activate siren' : ActivateSiren;
        action 'flash led' : FlashLED;
        action 'perform self test' : PerformSelfTest;

        part detector1 : SmokeDetector {
            part controlUnit : ControlUnit {
                attribute smokeThreshold = 50.0;
                attribute lowBatteryThreshold = 10.0;
            }
            part opticalSensor : OpticalSensor;
            part audibleAlarm : AudibleAlarm {
                attribute minSoundLevel = 85.0;
            }
            part visualAlert : VisualAlert;
            part battery : BatteryPack;
            part userInterface : ControlInterface;

            connect opticalSensor.sensorOut to controlUnit.sensorIn;
            connect controlUnit.alarmOut to audibleAlarm.alarmIn;
            connect controlUnit.alarmOut to visualAlert.alertIn;
            connect battery.batteryOut to controlUnit.batteryIn;
            connect userInterface.userOut to controlUnit.userIn;
        }

        state 'detector states' : DetectorStates {
            entry; then standby;

            state standby {
                do 'monitor air' { out smokeLevel; }
                do 'check battery' { out chargeLevel; }
            }
            accept when 'monitor air'.smokeLevel > detector1.controlUnit.smokeThreshold
                then alarming;
            accept when 'check battery'.chargeLevel < detector1.controlUnit.lowBatteryThreshold
                then lowBattery;
            accept TestCommand
                then testing;

            state alarming {
                entry 'activate siren';
                entry 'flash led';
                do 'activate siren';
                do 'flash led';
            }
            accept ResetCommand
                if 'monitor air'.smokeLevel <= detector1.controlUnit.smokeThreshold
                then standby;

            state lowBattery {
                entry 'flash led';
                do 'flash led';
            }
            accept ResetCommand
                then standby;

            state testing {
                entry 'perform self test';
                do 'perform self test';
            }
            accept ResetCommand
                then standby;
        }
    }

    package Requirements {
        private import Definitions::*;

        requirement def SmokeDetectionRequirement {
            doc /* The smoke detector shall continuously monitor air and activate alerts when smoke concentration exceeds threshold. */
            subject detector : SmokeDetector;
            attribute threshold : SmokeConcentrationValue = 50.0;
        }

        requirement def AudibleAlarmRequirement {
            doc /* The audible alarm shall emit sound of at least 85 decibels. */
            subject alarm : AudibleAlarm;
            attribute minLevel : SoundPressureLevelValue = 85.0;
        }

        requirement def LowBatteryWarningRequirement {
            doc /* The system shall provide low battery warning when charge falls below threshold. */
            subject battery : BatteryPack;
            attribute minCharge : BatteryChargeValue = 10.0;
        }

        requirement def SelfTestRequirement {
            doc /* The user shall be able to trigger a self-test via the control interface. */
            subject detector : SmokeDetector;
        }

        requirement def ResetRequirement {
            doc /* The user shall be able to reset the alarm after the alert and when air is clear. */
            subject detector : SmokeDetector;
        }

        requirement smokeDetectionReq : SmokeDetectionRequirement;
        requirement audibleAlarmReq : AudibleAlarmRequirement;
        requirement lowBatteryReq : LowBatteryWarningRequirement;
        requirement selfTestReq : SelfTestRequirement;
        requirement resetReq : ResetRequirement;
    }
}
