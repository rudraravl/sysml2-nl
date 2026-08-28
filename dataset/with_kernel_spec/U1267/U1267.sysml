package ZWaveHomeAutomation {
    public import ISQ::*;
    public import ScalarValues::*;

    item def ZWaveMessage {
        attribute sourceId : String;
        attribute destId : String;
        attribute payload : String;
        attribute encrypted : Boolean;
        attribute sequenceNumber : Integer;
    }

    item def CommandMessage :> ZWaveMessage {
        attribute commandType : String;
    }

    item def StatusReport :> ZWaveMessage {
        attribute statusValue : Real;
        attribute unit : String;
    }

    item def TransmissionComplete;
    item def SleepTimerExpired;
    item def WakeupTimerExpired;
    item def MotionDetectedSignal;
    item def InclusionCommand;
    item def ExclusionCommand;
    item def RouteOptimizationTrigger;

    port def ZWavePort {
        in item msgIn : ZWaveMessage;
        out item msgOut : ZWaveMessage;
    }

    port def PowerPort {
        in supplyPower : ISQ::power;
    }

    port def BatteryPort {
        attribute batteryLevel : Real;
        out reportBattery : StatusReport;
    }

    port def HVACControlPort {
        out setHVACState : CommandMessage;
        in hvacStatus : StatusReport;
    }

    port def AlertPort {
        out motionAlert : StatusReport;
    }

    part def ZWaveNode {
        attribute nodeId : String;
        attribute isMainsPowered : Boolean = false;
        attribute isRepeater : Boolean = false;
        port zwavePort : ZWavePort;

        perform action sendMessage {
            in msg : ZWaveMessage;
        }
        perform action receiveMessage {
            in msg : ZWaveMessage;
        }

        exhibit state nodeStates {
            state listening;
            state transmitting;
            state sleeping;
            transition initial then listening;
            transition listening_to_transmitting
                first listening
                accept msg : ZWaveMessage via zwavePort.msgIn
                then transmitting;
            transition transmitting_to_listening
                first transmitting
                accept TransmissionComplete
                then listening;
            transition listening_to_sleeping
                first listening
                accept SleepTimerExpired
                then sleeping;
            transition sleeping_to_listening
                first sleeping
                accept WakeupTimerExpired
                then listening;
        }
    }

    part def ZWaveController :> ZWaveNode {
        attribute networkKey : String;
        attribute routingTable : String[*];
        attribute isMainsPowered : Boolean = true;

        perform action addDevice {
            in deviceInfo : String;
            out success : Boolean;
        }
        perform action removeDevice {
            in deviceId : String;
            out success : Boolean;
        }
        perform action optimizeRoutes;
        perform action encryptMessage {
            in plain : ZWaveMessage;
            out encrypted : ZWaveMessage;
        }
        perform action decryptMessage {
            in encrypted : ZWaveMessage;
            out plain : ZWaveMessage;
        }

        exhibit state controllerStates {
            state standby;
            state addingDevice;
            state removingDevice;
            state optimizingRoutes;
            transition initial then standby;
            transition standby_to_adding
                first standby
                accept InclusionCommand
                then addingDevice;
            transition adding_to_standby
                first addingDevice
                accept TransmissionComplete
                then standby;
            transition standby_to_removing
                first standby
                accept ExclusionCommand
                then removingDevice;
            transition removing_to_standby
                first removingDevice
                accept TransmissionComplete
                then standby;
            transition standby_to_optimizing
                first standby
                accept RouteOptimizationTrigger
                then optimizingRoutes;
            transition optimizing_to_standby
                first optimizingRoutes
                accept TransmissionComplete
                then standby;
        }
    }

    part def SmartLightSwitch :> ZWaveNode {
        attribute isOn : Boolean = false;
        attribute powerConsumption : ISQ::power = 0[W];
        attribute isMainsPowered : Boolean = true;
        attribute isRepeater : Boolean = true;
        port powerPort : PowerPort;

        perform action toggleOnOff;
        perform action turnOn;
        perform action turnOff;
        perform action reportStatus;
        perform action repeatMessage {
            in msg : ZWaveMessage;
            out repeatedMsg : ZWaveMessage;
        }

        exhibit state switchStates {
            state on {
                do turnOn;
                constraint { powerConsumption > 0[W] }
            }
            state off {
                do turnOff;
                constraint { powerConsumption == 0[W] }
            }
            transition initial then off;
            transition on_to_off
                first on
                accept turnOffCmd : CommandMessage via zwavePort.msgIn
                then off;
            transition off_to_on
                first off
                accept turnOnCmd : CommandMessage via zwavePort.msgIn
                then on;
        }
    }

    part def SmartThermostat :> ZWaveNode {
        attribute currentTemp : ISQ::temperature = 295[K];
        attribute setpoint : ISQ::temperature = 295[K];
        attribute isMainsPowered : Boolean = true;
        attribute isRepeater : Boolean = true;
        port hvacPort : HVACControlPort;

        perform action controlHVAC;
        perform action reportTemperature;
        perform action senseTemperature;

        exhibit state thermostatStates {
            state monitoring {
                do senseTemperature;
            }
            state heating {
                do controlHVAC;
                constraint { currentTemp < setpoint }
            }
            state cooling {
                do controlHVAC;
                constraint { currentTemp > setpoint }
            }
            state steady {
                constraint { currentTemp >= setpoint - 1[K] and currentTemp <= setpoint + 1[K] }
            }
            transition initial then monitoring;
            transition monitoring_to_heating
                first monitoring
                if currentTemp < setpoint
                then heating;
            transition monitoring_to_cooling
                first monitoring
                if currentTemp > setpoint
                then cooling;
            transition monitoring_to_steady
                first monitoring
                if currentTemp >= setpoint - 1[K] and currentTemp <= setpoint + 1[K]
                then steady;
            transition heating_to_steady
                first heating
                if currentTemp >= setpoint
                then steady;
            transition cooling_to_steady
                first cooling
                if currentTemp <= setpoint
                then steady;
            transition steady_to_monitoring
                first steady
                accept WakeupTimerExpired
                then monitoring;
        }
    }

    part def MotionSensor :> ZWaveNode {
        attribute motionDetected : Boolean = false;
        attribute batteryLevel : Real = 100;
        attribute isMainsPowered : Boolean = false;
        attribute isRepeater : Boolean = false;
        port batteryPort : BatteryPort;
        port alertPort : AlertPort;

        perform action detectMotion;
        perform action sendAlert;
        perform action enterLowPowerMode;

        exhibit state sensorStates {
            state deepSleep {
                do enterLowPowerMode;
                constraint { batteryLevel > 0 }
            }
            state activeDetection {
                do detectMotion;
            }
            state reporting {
                do sendAlert;
            }
            transition initial then deepSleep;
            transition deepSleep_to_active_motion
                first deepSleep
                accept MotionDetectedSignal
                then activeDetection;
            transition deepSleep_to_active_wakeup
                first deepSleep
                accept WakeupTimerExpired
                then activeDetection;
            transition active_to_reporting
                first activeDetection
                if motionDetected == true
                then reporting;
            transition reporting_to_sleep
                first reporting
                accept TransmissionComplete
                then deepSleep;
            transition active_to_sleep
                first activeDetection
                accept SleepTimerExpired
                then deepSleep;
        }
    }

    part def SmartDoorLock :> ZWaveNode {
        attribute isLocked : Boolean = true;
        attribute accessCode : String;
        attribute accessCodeValid : Boolean;
        attribute batteryLevel : Real = 100;
        attribute isMainsPowered : Boolean = false;
        attribute isRepeater : Boolean = false;
        port batteryPort : BatteryPort;

        perform action lock;
        perform action unlock {
            in code : String;
        }
        perform action reportLockState;
        perform action verifyCode {
            in code : String;
            out valid : Boolean;
        }

        exhibit state lockStates {
            state locked {
                do lock;
            }
            state unlocked {
                constraint { isLocked == false }
            }
            state securing {
                do verifyCode;
            }
            transition initial then locked;
            transition locked_to_securing
                first locked
                accept unlockRequest : CommandMessage via zwavePort.msgIn
                then securing;
            transition securing_to_unlocked
                first securing
                if accessCodeValid == true
                then unlocked;
            transition unlocked_to_locked
                first unlocked
                accept lockRequest : CommandMessage via zwavePort.msgIn
                then locked;
        }
    }

    requirement def MeshNetworkReqDef {
        doc /* The system shall operate as a secure mesh network with self-healing capability. */
        attribute meshEnabled : Boolean;
        attribute maxHops : Integer;
        require constraint { meshEnabled == true and maxHops <= 4 }
    }

    requirement def SecureCommunicationReqDef {
        doc /* All communication within the Z-Wave network shall be encrypted. */
        attribute encryptionEnabled : Boolean;
        attribute encryptionProtocol : String;
        require constraint { encryptionEnabled == true and encryptionProtocol == "AES-128" }
    }

    requirement def ControllerManagementReqDef {
        doc /* The central controller shall manage devices and optimize routes. */
        attribute deviceManagement : Boolean;
        attribute routeOptimization : Boolean;
        require constraint { deviceManagement == true and routeOptimization == true }
    }

    requirement def LightSwitchReqDef {
        doc /* Smart light switches shall control lighting, report status, and act as repeaters. */
        attribute statusReporting : Boolean;
        attribute repeaterFunction : Boolean;
        require constraint { statusReporting == true and repeaterFunction == true }
    }

    requirement def ThermostatReqDef {
        doc /* The smart thermostat shall monitor temperature and control HVAC to maintain setpoint. */
        attribute tempMonitoring : Boolean;
        attribute hvacControl : Boolean;
        attribute tempTolerance : ISQ::temperature;
        require constraint { tempMonitoring == true and hvacControl == true and tempTolerance <= 1[K] }
    }

    requirement def MotionSensorReqDef {
        doc /* The motion sensor shall detect movement and operate in a low-power sleep mode. */
        attribute motionDetection : Boolean;
        attribute lowPowerMode : Boolean;
        attribute minBatteryLife : ISQ::time;
        require constraint { motionDetection == true and lowPowerMode == true and minBatteryLife >= 17520[h] }
    }

    requirement def DoorLockReqDef {
        doc /* The smart door lock shall allow remote locking/unlocking and report its state. */
        attribute remoteAccess : Boolean;
        attribute stateReporting : Boolean;
        attribute minBatteryLife : ISQ::time;
        require constraint { remoteAccess == true and stateReporting == true and minBatteryLife >= 8760[h] }
    }

    requirement def RepeaterReqDef {
        doc /* Mains-powered devices shall act as repeaters to extend network range. */
        attribute repeaterEnabled : Boolean;
        require constraint { repeaterEnabled == true }
    }

    requirement def NetworkReliabilityReqDef {
        doc /* The network shall maintain connectivity and message delivery reliability above 99 percent. */
        attribute packetDeliveryRate : Real;
        attribute networkUptime : ISQ::time;
        require constraint { packetDeliveryRate >= 0.99 and networkUptime >= 8760[h] }
    }

    part homeNetwork {
        part controller : ZWaveController;
        part lightSwitch1 : SmartLightSwitch;
        part lightSwitch2 : SmartLightSwitch;
        part thermostat : SmartThermostat;
        part motionSensor : MotionSensor;
        part doorLock : SmartDoorLock;

        connect controller.zwavePort to lightSwitch1.zwavePort;
        connect controller.zwavePort to lightSwitch2.zwavePort;
        connect controller.zwavePort to thermostat.zwavePort;
        connect controller.zwavePort to motionSensor.zwavePort;
        connect controller.zwavePort to doorLock.zwavePort;

        connect lightSwitch1.zwavePort to lightSwitch2.zwavePort;
        connect lightSwitch1.zwavePort to thermostat.zwavePort;
        connect lightSwitch2.zwavePort to thermostat.zwavePort;

        flow controller.zwavePort.msgOut to lightSwitch1.zwavePort.msgIn;
        flow controller.zwavePort.msgOut to lightSwitch2.zwavePort.msgIn;
        flow controller.zwavePort.msgOut to thermostat.zwavePort.msgIn;
        flow controller.zwavePort.msgOut to motionSensor.zwavePort.msgIn;
        flow controller.zwavePort.msgOut to doorLock.zwavePort.msgIn;

        flow lightSwitch1.zwavePort.msgOut to controller.zwavePort.msgIn;
        flow lightSwitch2.zwavePort.msgOut to controller.zwavePort.msgIn;
        flow thermostat.zwavePort.msgOut to controller.zwavePort.msgIn;
        flow motionSensor.zwavePort.msgOut to controller.zwavePort.msgIn;
        flow doorLock.zwavePort.msgOut to controller.zwavePort.msgIn;

        flow lightSwitch1.zwavePort.msgOut to lightSwitch2.zwavePort.msgIn;
        flow lightSwitch2.zwavePort.msgOut to lightSwitch1.zwavePort.msgIn;
        flow lightSwitch1.zwavePort.msgOut to thermostat.zwavePort.msgIn;
        flow lightSwitch2.zwavePort.msgOut to thermostat.zwavePort.msgIn;

        flow motionSensor.alertPort.motionAlert to controller.zwavePort.msgIn;

        requirement meshReq : MeshNetworkReqDef {
            attribute meshEnabled : Boolean = true;
            attribute maxHops : Integer = 4;
        }
        requirement secureReq : SecureCommunicationReqDef {
            attribute encryptionEnabled : Boolean = true;
            attribute encryptionProtocol : String = "AES-128";
        }
        requirement ctrlReq : ControllerManagementReqDef {
            attribute deviceManagement : Boolean = true;
            attribute routeOptimization : Boolean = true;
        }
        requirement lightReq1 : LightSwitchReqDef {
            attribute statusReporting : Boolean = true;
            attribute repeaterFunction : Boolean = true;
        }
        requirement lightReq2 : LightSwitchReqDef {
            attribute statusReporting : Boolean = true;
            attribute repeaterFunction : Boolean = true;
        }
        requirement thermoReq : ThermostatReqDef {
            attribute tempMonitoring : Boolean = true;
            attribute hvacControl : Boolean = true;
            attribute tempTolerance : ISQ::temperature = 1[K];
        }
        requirement motionReq : MotionSensorReqDef {
            attribute motionDetection : Boolean = true;
            attribute lowPowerMode : Boolean = true;
            attribute minBatteryLife : ISQ::time = 17520[h];
        }
        requirement lockReq : DoorLockReqDef {
            attribute remoteAccess : Boolean = true;
            attribute stateReporting : Boolean = true;
            attribute minBatteryLife : ISQ::time = 8760[h];
        }
        requirement repeaterReq : RepeaterReqDef {
            attribute repeaterEnabled : Boolean = true;
        }
        requirement reliabilityReq : NetworkReliabilityReqDef {
            attribute packetDeliveryRate : Real = 0.99;
            attribute networkUptime : ISQ::time = 8760[h];
        }

        satisfy meshReq by homeNetwork;
        satisfy secureReq by controller;
        satisfy ctrlReq by controller;
        satisfy lightReq1 by lightSwitch1;
        satisfy lightReq2 by lightSwitch2;
        satisfy thermoReq by thermostat;
        satisfy motionReq by motionSensor;
        satisfy lockReq by doorLock;
        satisfy repeaterReq by lightSwitch1, lightSwitch2, thermostat;
        satisfy reliabilityReq by homeNetwork;
    }
}
