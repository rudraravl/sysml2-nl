package CEBusHomeAutomation {
    import ScalarValues::*;
    import ISQ::*;

    value def Temperature :> Real { unit 'C'; }
    value def Percentage :> Real { unit '%'; }
    value def DeviceAddress :> String;

    item def PowerLineSignal {
        attribute source : DeviceAddress;
        attribute destination : DeviceAddress;
    }
    
    item def CommandPacket :> PowerLineSignal {
        attribute commandType : String;
        attribute commandValue : Real;
    }
    
    item def StatusReport :> PowerLineSignal {
        attribute statusValue : String;
    }
    
    item def AlarmSignal :> PowerLineSignal {
        attribute alarmType : String;
    }

    port def PowerLineCommPort {
        out item outgoing : PowerLineSignal;
        in item incoming : PowerLineSignal;
    }

    requirement def CentralizedControlRequirement {
        subject controller : CentralController;
        objective {
            doc "The controller shall provide centralized control and intelligent coordination of smart devices."
        }
    }

    requirement def PowerLineCommunicationRequirement {
        subject device : CEBusDevice;
        objective {
            doc "Devices shall communicate over existing electrical power lines."
        }
    }

    part def CentralController {
        port powerLineIf : PowerLineCommPort;
        attribute deviceRegistry : DeviceAddress[0..*];
        
        action def processIncomingSignal {
            in signal : PowerLineSignal;
        }
        
        action def sendCommand {
            in target : DeviceAddress;
            in cmdType : String;
            in cmdValue : Real;
        }
        
        state controllerStateMachine {
            entry; 
            state Idle;
            state Processing;
            state Dispatching;
            transition Idle to Processing when powerLineIf.incoming->notEmpty();
            transition Processing to Dispatching when true;
            transition Dispatching to Idle when true;
        }
    }

    part def CEBusDevice {
        port powerLineIf : PowerLineCommPort;
        attribute deviceAddress : DeviceAddress;
        
        action def executeCommand {
            in cmd : CommandPacket;
        }
        
        action def reportStatus {
            out report : StatusReport;
        }
    }

    part def SmartLightingModule :> CEBusDevice {
        attribute isOn : Boolean = false;
        attribute dimmingLevel : Percentage = 0;
        
        state lightState {
            state Off;
            state On;
            transition Off to On when powerLineIf.incoming->notEmpty();
            transition On to Off when powerLineIf.incoming->notEmpty();
        }
    }

    part def ClimateControlModule :> CEBusDevice {
        attribute currentTemperature : Temperature;
        attribute targetTemperature : Temperature = 22;
        
        part def HVACSystem {
            attribute isRunning : Boolean = false;
        }
        
        part hvac : HVACSystem;
        
        action def regulateTemperature {
            if currentTemperature < targetTemperature {
                hvac.isRunning = true;
            } else {
                hvac.isRunning = false;
            }
        }
    }

    part def SecuritySensorModule :> CEBusDevice {
        attribute doorOpen : Boolean = false;
        
        state sensorState {
            state Closed;
            state Open;
            transition Closed to Open when doorOpen == true;
            transition Open to Closed when doorOpen == false;
        }
    }

    part def ApplianceControlModule :> CEBusDevice {
        attribute isOn : Boolean = false;
        
        state applianceState {
            state Off;
            state On;
            transition Off to On when powerLineIf.incoming->notEmpty();
            transition On to Off when powerLineIf.incoming->notEmpty();
        }
    }

    part homeAutomationSystem {
        part controller : CentralController {
            satisfy CentralizedControlRequirement;
        }
        
        part livingRoomLight : SmartLightingModule {
            attribute deviceAddress = "LR_LIGHT_01";
            satisfy PowerLineCommunicationRequirement;
        }
        
        part kitchenLight : SmartLightingModule {
            attribute deviceAddress = "KIT_LIGHT_01";
            satisfy PowerLineCommunicationRequirement;
        }
        
        part thermostat : ClimateControlModule {
            attribute deviceAddress = "THERMO_01";
            satisfy PowerLineCommunicationRequirement;
        }
        
        part frontDoorSensor : SecuritySensorModule {
            attribute deviceAddress = "DOOR_SENS_01";
            satisfy PowerLineCommunicationRequirement;
        }
        
        part coffeeMakerPlug : ApplianceControlModule {
            attribute deviceAddress = "COFFEE_01";
            satisfy PowerLineCommunicationRequirement;
        }
        
        connection powerLineNetwork connect controller.powerLineIf to livingRoomLight.powerLineIf;
        connection powerLineNetwork connect controller.powerLineIf to kitchenLight.powerLineIf;
        connection powerLineNetwork connect controller.powerLineIf to thermostat.powerLineIf;
        connection powerLineNetwork connect controller.powerLineIf to frontDoorSensor.powerLineIf;
        connection powerLineNetwork connect controller.powerLineIf to coffeeMakerPlug.powerLineIf;
    }
}
