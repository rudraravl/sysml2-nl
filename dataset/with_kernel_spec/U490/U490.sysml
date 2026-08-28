package 'Dry Running Protection System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PumpStop;
    attribute def ValveClose;
    attribute def AlarmOn;
    attribute def ResetSignal;
    
    port def FlowDataPort {
        out flow : VolumeFlowRateValue;
    }
    port def PressureDataPort {
        out pressure : PressureValue;
    }
    port def TempDataPort {
        out temp : TemperatureValue;
    }
    port def PumpControlPort {
        in pumpStop : PumpStop;
    }
    port def ValveControlPort {
        in valveClose : ValveClose;
    }
    port def AlarmControlPort {
        in alarmOn : AlarmOn;
    }
    
    part def Pump {
        port pumpControl : PumpControlPort;
    }
    part def IsolationValve {
        port valveControl : ValveControlPort;
    }
    part def AlarmUnit {
        port alarmControl : AlarmControlPort;
    }
    part def FlowSensor {
        port flowOutput : FlowDataPort;
    }
    part def PressureSensor {
        port pressureOutput : PressureDataPort;
    }
    part def TemperatureSensor {
        port tempOutput : TempDataPort;
    }
    
    part def ProtectionController {
        port flowInput : ~FlowDataPort;
        port pressureInput : ~PressureDataPort;
        port tempInput : ~TempDataPort;
        port pumpOutput : ~PumpControlPort;
        port valveOutput : ~ValveControlPort;
        port alarmOutput : ~AlarmControlPort;
        
        attribute minFlow : VolumeFlowRateValue = 5.0 [L/min];
        attribute minPressure : PressureValue = 1.0 [bar];
        attribute maxTemp : TemperatureValue = 80.0 [degC];
        attribute warningTimeout : DurationValue = 3.0 [s];
    }
    
    state protectionStates {
        in controller : ProtectionController;
        entry; then normal;
        
        state normal;
        accept when controller.flowInput.flow < controller.minFlow or controller.pressureInput.pressure < controller.minPressure
            then warning;
        accept when controller.tempInput.temp > controller.maxTemp
            then shutdown;
            
        state warning;
        accept when controller.flowInput.flow >= controller.minFlow and controller.pressureInput.pressure >= controller.minPressure
            then normal;
        accept after controller.warningTimeout
            if controller.flowInput.flow < controller.minFlow or controller.pressureInput.pressure < controller.minPressure
            then shutdown;
        accept when controller.tempInput.temp > controller.maxTemp
            then shutdown;
            
        state shutdown {
            entry action shutdownActions {
                send new PumpStop() to controller.pumpOutput;
                send new ValveClose() to controller.valveOutput;
                send new AlarmOn() to controller.alarmOutput;
            }
        }
        accept ResetSignal
            then normal;
    }
    
    requirement def DryRunningProtectionReq {
        doc
        /*
         * The pump assembly shall prevent dry running of the liquid pump
         * by monitoring flow, pressure, and temperature, and initiating
         * a protective shutdown when threshold conditions are met.
         */
        subject thePump : Pump;
        subject theController : ProtectionController;
        subject theValve : IsolationValve;
        subject theAlarm : AlarmUnit;
        
        requirement monitorCondition {
            doc /* The controller shall continuously monitor flow, pressure, and temperature. */
        }
        requirement warnOnLowFlowOrPressure {
            doc /* The controller shall enter a warning state if flow < 5.0 L/min or pressure < 1.0 bar. */
        }
        requirement shutdownOnPersistentWarning {
            doc /* The controller shall shut down if warning conditions persist for more than 3 seconds. */
        }
        requirement shutdownOnHighTemp {
            doc /* The controller shall immediately shut down if temperature exceeds 80 degrees C. */
        }
        requirement shutdownActions {
            doc /* Shutdown shall stop the pump, close the isolation valve, and activate the alarm. */
        }
    }
    
    part pumpAssembly {
        part pump : Pump;
        part isolationValve : IsolationValve;
        part alarm : AlarmUnit;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part tempSensor : TemperatureSensor;
        part controller : ProtectionController {
            exhibit protectionStates {
                in controller = controller;
            }
        }
        
        connection flowConn : flowSensor.flowOutput <> controller.flowInput;
        connection pressureConn : pressureSensor.pressureOutput <> controller.pressureInput;
        connection tempConn : tempSensor.tempOutput <> controller.tempInput;
        
        connection pumpCmdConn : controller.pumpOutput <> pump.pumpControl;
        connection valveCmdConn : controller.valveOutput <> isolationValve.valveControl;
        connection alarmCmdConn : controller.alarmOutput <> alarm.alarmControl;
        
        requirement dryRunProtect : DryRunningProtectionReq {
            subject thePump = pump;
            subject theController = controller;
            subject theValve = isolationValve;
            subject theAlarm = alarm;
        }
    }
}
