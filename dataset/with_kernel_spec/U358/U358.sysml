package 'Intelligent Thermal Management System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def TempReading {
        attribute value : TemperatureValue;
        attribute sensorId : Integer;
    }
    attribute def CoolingCommand {
        attribute fanSpeed : Real;
        attribute pumpRate : VolumeFlowRateValue;
    }
    attribute def DiagnosticAlert {
        attribute alertText : String;
        attribute severity : Integer;
    }
    attribute def SetpointAdjustment {
        attribute newSetpoint : TemperatureValue;
    }
    attribute def StatusRequest;
    attribute def StatusResponse {
        attribute currentTemp : TemperatureValue;
        attribute powerConsumption : PowerValue;
        attribute alarmActive : Boolean;
        attribute mode : String;
    }

    port def SensorOutPort {
        out reading : TempReading;
    }
    port def SensorInPort {
        in reading : TempReading;
    }
    port def ControlOutPort {
        out command : CoolingCommand;
    }
    port def ControlInPort {
        in command : CoolingCommand;
    }
    port def PowerOutPort {
        out power : PowerValue;
    }
    port def PowerInPort {
        in power : PowerValue;
    }
    port def MonitoringPort {
        in request : StatusRequest;
        in adjustment : SetpointAdjustment;
        out response : StatusResponse;
    }
    port def AlertPort {
        out alert : DiagnosticAlert;
    }

    part def TemperatureSensor {
        attribute sensorId : Integer;
        port tempOutPort : SensorOutPort;
        exhibit state sensorStates {
            entry; then sensing;
            state sensing;
        }
    }

    part def CoolingUnit {
        port commandInPort : ControlInPort;
        port powerOutPort : PowerOutPort;
        exhibit state coolingStates {
            entry; then standby;
            state standby;
            state active;
            state maxCapacity;
        }
    }

    part def ThermalController {
        attribute setpoint : TemperatureValue = 25.0 [K];
        attribute activeThreshold : TemperatureValue = 35.0 [K];
        attribute criticalThreshold : TemperatureValue = 80.0 [K];

        port sensorInPort1 : SensorInPort;
        port sensorInPort2 : SensorInPort;
        port sensorInPort3 : SensorInPort;
        port sensorInPort4 : SensorInPort;
        port commandOutPort : ControlOutPort;
        port powerInPort : PowerInPort;
        port monitorPort : MonitoringPort;
        port alertPort : AlertPort;

        action senseTemps {
            out temp : TemperatureValue;
        }
        action generateCmd {
            out command : CoolingCommand;
        }

        exhibit state controllerStates parallel {
            state controlStates {
                entry; then normal;
                do senseTemps;
                state normal {
                    do generateCmd;
                }
                accept when senseTemps.temp > activeThreshold
                    then active;
                state active {
                    do generateCmd;
                }
                accept when senseTemps.temp > criticalThreshold
                    do send new DiagnosticAlert() to alertPort
                    then critical;
                state critical {
                    do generateCmd;
                }
                accept when senseTemps.temp <= activeThreshold
                    then normal;
            }
            state monitorStates {
                entry; then idle;
                state idle;
                accept request : StatusRequest
                    do send new StatusResponse() to monitorPort
                    then idle;
                accept adjustment : SetpointAdjustment
                    do assign setpoint := adjustment.newSetpoint
                    then idle;
            }
        }
    }

    part def ThermalManagementSystem {
        part sensor1 : TemperatureSensor;
        part sensor2 : TemperatureSensor;
        part sensor3 : TemperatureSensor;
        part sensor4 : TemperatureSensor;
        part controller : ThermalController;
        part coolingUnit : CoolingUnit;
    }

    part def ExternalMonitor {
        port monitorPort {
            out request : StatusRequest;
            out adjustment : SetpointAdjustment;
            in response : StatusResponse;
        }
    }

    requirement def SafeTemperatureRequirement {
        doc /* The system shall maintain the temperature of the equipment below the critical threshold. */
    }

    part systemInstance : ThermalManagementSystem {
        part :>> sensor1 : TemperatureSensor;
        part :>> sensor2 : TemperatureSensor;
        part :>> sensor3 : TemperatureSensor;
        part :>> sensor4 : TemperatureSensor;
        part :>> controller : ThermalController;
        part :>> coolingUnit : CoolingUnit;

        flow tempFlow1 of TempReading from sensor1.tempOutPort.reading to controller.sensorInPort1.reading;
        flow tempFlow2 of TempReading from sensor2.tempOutPort.reading to controller.sensorInPort2.reading;
        flow tempFlow3 of TempReading from sensor3.tempOutPort.reading to controller.sensorInPort3.reading;
        flow tempFlow4 of TempReading from sensor4.tempOutPort.reading to controller.sensorInPort4.reading;
        flow coolingCmdFlow of CoolingCommand from controller.commandOutPort.command to coolingUnit.commandInPort.command;
        flow powerFlow of PowerValue from coolingUnit.powerOutPort.power to controller.powerInPort.power;
    }

    part monitorInstance : ExternalMonitor;

    interface monitorInterface connect monitorInstance.monitorPort to systemInstance.controller.monitorPort {
        flow statusRequestFlow of StatusRequest from monitorInstance.monitorPort.request to systemInstance.controller.monitorPort.request;
        flow setpointAdjustmentFlow of SetpointAdjustment from monitorInstance.monitorPort.adjustment to systemInstance.controller.monitorPort.adjustment;
        flow statusResponseFlow of StatusResponse from systemInstance.controller.monitorPort.response to monitorInstance.monitorPort.response;
    }

    satisfy SafeTemperatureRequirement by systemInstance;
}
