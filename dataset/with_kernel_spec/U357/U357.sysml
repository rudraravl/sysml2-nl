package 'TherapeuticJacketSystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        value def TemperatureValue :> ISQ::TemperatureValue;
        value def PressureValue :> ISQ::PressureValue;
        value def RespirationRateValue :> ISQ::FrequencyValue;
        value def BatteryLevelValue :> ScalarValues::Real;
        
        item def TempData {
            attribute temp : TemperatureValue;
        }
        item def ExpansionData {
            attribute rate : RespirationRateValue;
        }
        item def TherapyCommand {
            attribute pressure : PressureValue;
            attribute coolingTemp : TemperatureValue;
        }
        item def AlertSignal {
            attribute alertText : String;
        }
        
        port def TempDataOut { out data : TempData; }
        port def ExpDataOut { out data : ExpansionData; }
        port def ControllerTempIn { in data : TempData; }
        port def ControllerExpIn { in data : ExpansionData; }
        port def ControllerCmdOut { out cmd : TherapyCommand; }
        port def ActuatorCmdIn { in cmd : TherapyCommand; }
        port def AlertOut { out alert : AlertSignal; }
        port def AlertIn { in alert : AlertSignal; }
        
        action def SenseTemperature { out temp : TemperatureValue; }
        action def SenseExpansion { out rate : RespirationRateValue; }
        action def AnalyzeVitals { 
            in temp : TemperatureValue; 
            in rate : RespirationRateValue; 
            out cmd : TherapyCommand; 
        }
        action def ApplyPneumaticCompression { in cmd : TherapyCommand; }
        action def ApplyCooling { in cmd : TherapyCommand; }
        action def SendAlert { out alert : AlertSignal; }
        
        attribute def StartMonitoring;
        attribute def TherapyNeeded;
        attribute def TherapyComplete;
        attribute def PowerOff;
        attribute def CriticalCondition;
        attribute def IssueResolved;
        
        state def JacketOperationalStates;
        
        part def TemperatureSensor {
            port dataOut : TempDataOut;
            perform action senseTemp : SenseTemperature;
        }
        part def ExpansionSensor {
            port dataOut : ExpDataOut;
            perform action senseExp : SenseExpansion;
        }
        part def PneumaticChamber {
            port cmdIn : ActuatorCmdIn;
            perform action compress : ApplyPneumaticCompression;
        }
        part def CoolingModule {
            port cmdIn : ActuatorCmdIn;
            perform action cool : ApplyCooling;
        }
        part def Battery {
            attribute level : BatteryLevelValue = 100.0;
        }
        part def ExternalMonitor {
            port alertIn : AlertIn;
        }
        part def TherapyController {
            port tempIn : ControllerTempIn;
            port expIn : ControllerExpIn;
            port cmdOut : ControllerCmdOut;
            port alertOut : AlertOut;
            perform action analyze : AnalyzeVitals;
            perform action alert : SendAlert;
            exhibit state controllerStates : JacketOperationalStates;
        }
        part def TherapeuticJacket {
            part controller : TherapyController;
            part tempSensors : TemperatureSensor[4];
            part expansionSensors : ExpansionSensor[2];
            part pneumaticChambers : PneumaticChamber[3];
            part coolingModule : CoolingModule;
            part battery : Battery;
            part externalMonitor : ExternalMonitor;
            
            connect tempSensors.dataOut to controller.tempIn;
            connect expansionSensors.dataOut to controller.expIn;
            connect controller.cmdOut to pneumaticChambers.cmdIn;
            connect controller.cmdOut to coolingModule.cmdIn;
            connect controller.alertOut to externalMonitor.alertIn;
            
            exhibit state jacketStates : JacketOperationalStates;
        }
        
        requirement def MaxPressureLimit {
            doc /* The pressure in pneumatic chambers must not exceed 50 kPa. */
            subject pressure : PressureValue;
            attribute maxPressure : PressureValue = 50.0;
            constraint { pressure <= maxPressure }
        }
        requirement def MinCoolingTempLimit {
            doc /* The cooling fluid temperature must not drop below 15 degrees C. */
            subject fluidTemp : TemperatureValue;
            attribute minTemp : TemperatureValue = 15.0;
            constraint { fluidTemp >= minTemp }
        }
        requirement def LowBatteryAlert {
            doc /* The system must alert if battery is low. */
            subject batteryLevel : BatteryLevelValue;
            attribute lowThreshold : BatteryLevelValue = 20.0;
            constraint { batteryLevel < lowThreshold }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part jacket : TherapeuticJacket {
            action 'monitor vitals' : AnalyzeVitals;
            action 'apply compression' : ApplyPneumaticCompression;
            action 'apply cooling' : ApplyCooling;
            action 'send alert' : SendAlert;
            
            state jacketStates : JacketOperationalStates parallel {
                state 'operational modes' {
                    entry; then standby;
                    state standby;
                    accept StartMonitoring
                        then monitoring;
                    state monitoring {
                        do 'monitor vitals';
                    }
                    accept TherapyNeeded
                        then activeTherapy;
                    state activeTherapy {
                        do 'apply compression';
                        do 'apply cooling';
                    }
                    accept TherapyComplete
                        then monitoring;
                    accept PowerOff
                        then standby;
                }
                state 'safety monitoring' {
                    entry; then normal;
                    state normal;
                    accept when battery.level < 20.0
                        do 'send alert'
                        then alertState;
                    accept CriticalCondition
                        do 'send alert'
                        then alertState;
                    state alertState;
                    accept IssueResolved
                        then normal;
                }
            }
        }
        
        requirement maxPressureReq : MaxPressureLimit;
        requirement minCoolingTempReq : MinCoolingTempLimit;
        requirement lowBatteryAlertReq : LowBatteryAlert;
    }
}
