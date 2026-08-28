package BuildingAutomationSystem {
    private import ScalarValues::*;

    attribute def Temperature :> Real;
    attribute def Humidity :> Real;
    attribute def DamperPosition :> Real;
    attribute def FanSpeed :> Real;

    item def TemperatureReading {
        attribute temperature : Temperature;
    }
    item def HumidityReading {
        attribute humidity : Humidity;
    }
    item def DamperCommand {
        attribute position : DamperPosition;
    }
    item def FanCommand {
        attribute speed : FanSpeed;
    }
    item def DamperStatus {
        attribute position : DamperPosition;
    }
    item def FanStatus {
        attribute speed : FanSpeed;
    }

    port def TempSensorPort {
        out tempReading : TemperatureReading;
    }
    port def HumiditySensorPort {
        out humidityReading : HumidityReading;
    }
    port def ControllerPort {
        in tempReading : TemperatureReading;
        in humidityReading : HumidityReading;
        out damperCmd : DamperCommand;
        out fanCmd : FanCommand;
        in damperStat : DamperStatus;
        in fanStat : FanStatus;
    }
    port def DamperActuatorPort {
        in damperCmd : DamperCommand;
        out damperStat : DamperStatus;
    }
    port def FanActuatorPort {
        in fanCmd : FanCommand;
        out fanStat : FanStatus;
    }

    part def SensorNode {
        attribute samplingPeriod : Integer = 5;
        attribute nodeId : String;
    }

    part def TemperatureSensorNode :> SensorNode {
        port tempOut : TempSensorPort;
        attribute measuredTemp : Temperature;

        action sensorBehavior {
            first start;
            then merge m;
            then send new TemperatureReading() via tempOut;
            then decide;
                if true then m;
                else done;
        }
    }

    part def HumiditySensorNode :> SensorNode {
        port humidityOut : HumiditySensorPort;
        attribute measuredHumidity : Humidity;

        action sensorBehavior {
            first start;
            then merge m;
            then send new HumidityReading() via humidityOut;
            then decide;
                if true then m;
                else done;
        }
    }

    part def HVACControllerNode {
        port controllerPort : ControllerPort;
        attribute tempSetpoint : Temperature = 22;
        attribute humiditySetpoint : Humidity = 50;
        attribute currentTemp : Temperature;
        attribute currentHumidity : Humidity;
        attribute computedDamperPos : DamperPosition;
        attribute computedFanSpeed : FanSpeed;

        state def ControllerStates {
            entry; then monitoring;
            state monitoring;
            state evaluating;
            state commanding;
            transition monitoring_to_evaluating
                first monitoring
                accept TemperatureReading
                then evaluating;
            transition evaluating_to_commanding
                first evaluating
                accept HumidityReading
                then commanding;
            transition commanding_to_monitoring
                first commanding
                then monitoring;
        }

        action controllerBehavior {
            first start;
            then merge loopStart;
            then accept TemperatureReading via controllerPort;
            then accept HumidityReading via controllerPort;
            then send new DamperCommand() via controllerPort;
            then send new FanCommand() via controllerPort;
            then accept DamperStatus via controllerPort;
            then accept FanStatus via controllerPort;
            then decide;
                if true then loopStart;
                else done;
        }
    }

    part def ActuatorNode {
        attribute nodeId : String;
    }

    part def DamperActuator :> ActuatorNode {
        port damperPort : DamperActuatorPort;
        attribute currentPosition : DamperPosition = 0;

        action actuatorBehavior {
            first start;
            then merge loopStart;
            then accept DamperCommand via damperPort;
            then send new DamperStatus() via damperPort;
            then decide;
                if true then loopStart;
                else done;
        }
    }

    part def FanActuator :> ActuatorNode {
        port fanPort : FanActuatorPort;
        attribute currentSpeed : FanSpeed = 0;

        action actuatorBehavior {
            first start;
            then merge loopStart;
            then accept FanCommand via fanPort;
            then send new FanStatus() via fanPort;
            then decide;
                if true then loopStart;
                else done;
        }
    }

    part def LonWorksNetwork {
        attribute protocol : String = "LonWorks";
        attribute cabling : String = "Twisted-Pair";
        attribute topology : String = "Peer-to-Peer";
    }

    part def Zone {
        attribute zoneId : String;
        part tempSensor : TemperatureSensorNode;
        part humiditySensor : HumiditySensorNode;
        part controller : HVACControllerNode;
        part damperActuator : DamperActuator;
        part fanActuator : FanActuator;

        interface tempSensorToController
            connect tempSensor.tempOut to controller.controllerPort {
            flow tempFlow of TemperatureReading
                from tempSensor.tempOut.tempReading to controller.controllerPort.tempReading;
        }
        interface humiditySensorToController
            connect humiditySensor.humidityOut to controller.controllerPort {
            flow humidityFlow of HumidityReading
                from humiditySensor.humidityOut.humidityReading to controller.controllerPort.humidityReading;
        }
        interface controllerToDamper
            connect controller.controllerPort to damperActuator.damperPort {
            flow damperCmdFlow of DamperCommand
                from controller.controllerPort.damperCmd to damperActuator.damperPort.damperCmd;
            flow damperStatFlow of DamperStatus
                from damperActuator.damperPort.damperStat to controller.controllerPort.damperStat;
        }
        interface controllerToFan
            connect controller.controllerPort to fanActuator.fanPort {
            flow fanCmdFlow of FanCommand
                from controller.controllerPort.fanCmd to fanActuator.fanPort.fanCmd;
            flow fanStatFlow of FanStatus
                from fanActuator.fanPort.fanStat to controller.controllerPort.fanStat;
        }
    }

    part def Facility {
        attribute name : String;
        part network : LonWorksNetwork;
        part zone1 : Zone {
            :>> zoneId = "Zone-1";
        }
        part zone2 : Zone {
            :>> zoneId = "Zone-2";
        }
    }

    part facility : Facility {
        :>> name = "Main Building";
    }

    occurrence def HVACFeedbackLoop {
        ref part tempSensor : TemperatureSensorNode {
            event tempMessage.sourceEvent;
        }
        ref part humiditySensor : HumiditySensorNode {
            event humidityMessage.sourceEvent;
        }
        ref part controller : HVACControllerNode {
            event tempMessage.targetEvent;
            then event humidityMessage.targetEvent;
            then event damperCmdMessage.sourceEvent;
            then event fanCmdMessage.sourceEvent;
            then event damperStatusMessage.targetEvent;
            then event fanStatusMessage.targetEvent;
        }
        ref part damperActuator : DamperActuator {
            event damperCmdMessage.targetEvent;
            then event damperStatusMessage.sourceEvent;
        }
        ref part fanActuator : FanActuator {
            event fanCmdMessage.targetEvent;
            then event fanStatusMessage.sourceEvent;
        }
        message tempMessage of TemperatureReading;
        then message humidityMessage of HumidityReading;
        then message damperCmdMessage of DamperCommand;
        then message fanCmdMessage of FanCommand;
        then message damperStatusMessage of DamperStatus;
        then message fanStatusMessage of FanStatus;
    }

    requirement def MaintainTemperatureSetpoint {
        attribute setpoint : Temperature = 22;
        doc /* The HVAC controller shall maintain the zone temperature at the specified setpoint. */
    }

    requirement def MaintainHumiditySetpoint {
        attribute setpoint : Humidity = 50;
        doc /* The HVAC controller shall maintain the zone relative humidity at the specified setpoint. */
    }

    requirement def PeerToPeerCommunication {
        doc /* All nodes shall communicate in a peer-to-peer fashion over the LonWorks network without relying on a central computer. */
    }

    requirement def PeriodicSensorReporting {
        attribute period : Integer = 5;
        doc /* Sensor nodes shall periodically broadcast environmental readings onto the network. */
    }

    requirement def ActuatorStatusReporting {
        doc /* Actuator nodes shall report their operational status back to the HVAC controller. */
    }

    requirement def DamperPositionControl {
        doc /* The damper actuator shall control the air damper position from 0 to 100 percent based on received commands. */
    }

    requirement def FanSpeedControl {
        doc /* The fan actuator shall control the ventilation fan speed based on received commands. */
    }

    requirement tempControlReq : MaintainTemperatureSetpoint;
    requirement humidityControlReq : MaintainHumiditySetpoint;
    requirement peerToPeerReq : PeerToPeerCommunication;
    requirement periodicReportingReq : PeriodicSensorReporting;
    requirement actuatorStatusReq : ActuatorStatusReporting;
    requirement damperControlReq : DamperPositionControl;
    requirement fanControlReq : FanSpeedControl;

    satisfy tempControlReq by facility.zone1.controller;
    satisfy humidityControlReq by facility.zone1.controller;
    satisfy peerToPeerReq by facility.network;
    satisfy periodicReportingReq by facility.zone1.tempSensor;
    satisfy periodicReportingReq by facility.zone1.humiditySensor;
    satisfy actuatorStatusReq by facility.zone1.damperActuator;
    satisfy actuatorStatusReq by facility.zone1.fanActuator;
    satisfy damperControlReq by facility.zone1.damperActuator;
    satisfy fanControlReq by facility.zone1.fanActuator;
}
