package TherapeuticJacketSystem {
    import ScalarValues::*;
    import ISQ::*;

    value type TemperatureValue > Real { unit 'degC'; }
    value type PressureValue > Real { unit 'bar'; }
    value type RespirationRateValue > Real { unit 'breaths/min'; }
    value type BatteryLevelValue > Real { unit '%'; }

    item def VitalData {
        attribute bodyTemp : TemperatureValue;
        attribute respirationRate : RespirationRateValue;
    }

    item def TherapyCommand {
        attribute targetPressure : PressureValue;
        attribute targetCoolingTemp : TemperatureValue;
        attribute enablePneumatic : Boolean;
        attribute enableCooling : Boolean;
    }

    item def AlertMessage {
        attribute severity : String;
        attribute description : String;
    }

    port def TempPort {
        out temp : TemperatureValue;
    }

    port def ExpPort {
        out rate : RespirationRateValue;
    }

    port def CmdPort {
        in out command : TherapyCommand;
    }

    port def AlertPort {
        in out alert : AlertMessage;
    }

    part def TempSensor {
        port tempOut : TempPort;
        attribute measuredTemp : TemperatureValue;
    }

    part def ExpansionSensor {
        port expOut : ExpPort;
        attribute measuredRate : RespirationRateValue;
    }

    part def PneumaticChamber {
        port cmdIn : CmdPort;
        attribute currentPressure : PressureValue;
        attribute maxPressure : PressureValue = 0.5;
    }

    part def CoolingModule {
        port cmdIn : CmdPort;
        attribute currentFluidTemp : TemperatureValue;
        attribute minFluidTemp : TemperatureValue = 15.0;
    }

    part def Battery {
        attribute level : BatteryLevelValue;
    }

    part def CommsModule {
        port alertIn : AlertPort;
    }

    part def TherapyController {
        port tempIn : TempPort[4];
        port expIn : ExpPort[2];
        port pneumaticCmd : CmdPort[3];
        port coolingCmd : CmdPort;
        port alertOut : AlertPort;
        
        attribute batteryLevel : BatteryLevelValue;
        attribute feverThreshold : TemperatureValue = 38.5;
        attribute abnormalRespThreshold : RespirationRateValue = 40.0;
        
        attribute currentMaxTemp : TemperatureValue;
        attribute currentMaxResp : RespirationRateValue;

        state def ControllerBehavior {
            entry; then Standby;
            
            state Standby {
                entry { /* Initialize system */ }
                transition to Monitoring 
                    when (batteryLevel > 10.0);
            }
            
            state Monitoring {
                entry { /* Read sensors continuously */ }
                transition to ActiveTherapy 
                    when (currentMaxTemp > feverThreshold || currentMaxResp > abnormalRespThreshold);
                transition to Alerting 
                    when (batteryLevel <= 10.0);
            }
            
            state ActiveTherapy {
                entry { /* Send TherapyCommand to chambers and cooling */ }
                transition to Monitoring 
                    when (currentMaxTemp <= feverThreshold && currentMaxResp <= abnormalRespThreshold);
                transition to Alerting 
                    when (batteryLevel <= 10.0 || currentMaxTemp > 42.0);
            }
            
            state Alerting {
                entry { /* Send AlertMessage via alertOut */ }
                transition to Standby 
                    when (batteryLevel > 20.0);
            }
        }
    }

    part def TherapeuticJacket {
        part controller : TherapyController;
        part tempSensors : TempSensor[4];
        part expansionSensors : ExpansionSensor[2];
        part pneumaticChambers : PneumaticChamber[3];
        part coolingModule : CoolingModule;
        part battery : Battery;
        part commsModule : CommsModule;
        
        connection tempConnections connect controller.tempIn to tempSensors.tempOut;
        connection expConnections connect controller.expIn to expansionSensors.expOut;
        connection pneumaticConnections connect controller.pneumaticCmd to pneumaticChambers.cmdIn;
        connection coolingConnection connect controller.coolingCmd to coolingModule.cmdIn;
        connection alertConnection connect controller.alertOut to commsModule.alertIn;
    }

    requirement def MonitorVitals {
        subject jacket : TherapeuticJacket;
        objective {
            doc /* The jacket shall continuously monitor body temperature and respiration rate. */
        }
    }

    requirement def ProvidePneumaticTherapy {
        subject jacket : TherapeuticJacket;
        objective {
            doc /* The jacket shall apply intermittent pressure via pneumatic chambers to improve lung function. */
        }
    }

    requirement def ProvideCoolingTherapy {
        subject jacket : TherapeuticJacket;
        objective {
            doc /* The jacket shall circulate temperature-controlled fluid to lower fever. */
        }
    }

    requirement def SafetyLimits {
        subject jacket : TherapeuticJacket;
        objective {
            doc /* The system shall not exceed max chamber pressure of 0.5 bar and shall not cool fluid below 15 degC. */
        }
    }

    requirement def Alerting {
        subject jacket : TherapeuticJacket;
        objective {
            doc /* The system shall send an alert if a critical condition is detected or battery is low. */
        }
    }

    requirement JacketRequirements {
        requirement monitor : MonitorVitals;
        requirement pneumatic : ProvidePneumaticTherapy;
        requirement cooling : ProvideCoolingTherapy;
        requirement safety : SafetyLimits;
        requirement alert : Alerting;
    }
}
