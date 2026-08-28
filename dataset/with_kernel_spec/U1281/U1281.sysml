package 'LightingControlSystem' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def Brightness :> Real;
        attribute def Illuminance :> Real;
        attribute def FadeTime :> Real;

        attribute def OccupancyTrigger;
        attribute def VacancyTrigger;
        attribute def MotionDetected;
        attribute def MotionCleared;
        attribute def DaylightSampleReady;

        item def DaylightReading {
            attribute level : Illuminance;
        }
        item def ControlCommand {
            attribute channel : Integer;
            attribute brightness : Brightness;
            attribute fadeTime : FadeTime;
        }

        part def NetworkController {
            port motionPort {
                in motionDetected : MotionDetected;
                in motionCleared : MotionCleared;
            }
            port daylightPort {
                in daylightReading : DaylightReading;
            }
            port controlPort1 {
                out command : ControlCommand;
            }
            port controlPort2 {
                out command : ControlCommand;
            }
            port controlPort3 {
                out command : ControlCommand;
            }
            port controlPort4 {
                out command : ControlCommand;
            }
            exhibit state controllerStates {
                entry; then idle;
                state idle;
                accept MotionDetected
                    do send new ControlCommand() to controlPort1
                    then active;
                accept DaylightReading
                    do send new ControlCommand() to controlPort1
                    then active;
                state active;
                accept MotionCleared
                    do send new ControlCommand() to controlPort1
                    then idle;
                accept DaylightReading
                    do send new ControlCommand() to controlPort1
                    then active;
            }
        }

        part def MotionSensor {
            port outPort {
                out motionDetected : MotionDetected;
                out motionCleared : MotionCleared;
            }
            exhibit state sensorStates {
                entry; then unoccupied;
                state unoccupied;
                accept OccupancyTrigger
                    do send new MotionDetected() to outPort
                    then occupied;
                state occupied;
                accept VacancyTrigger
                    do send new MotionCleared() to outPort
                    then unoccupied;
            }
        }

        part def PhotocellSensor {
            port outPort {
                out daylightReading : DaylightReading;
            }
            exhibit state photocellStates {
                entry; then sampling;
                state sampling;
                accept DaylightSampleReady
                    do send new DaylightReading() to outPort
                    then sampling;
            }
        }

        part def ChannelRelay {
            port inPort {
                in command : ControlCommand;
            }
            port powerPort {
                out brightness : Brightness;
            }
            exhibit state relayStates {
                entry; then off;
                state off;
                accept ControlCommand then on;
                state on;
                accept ControlCommand then off;
            }
        }

        part def LightingFixture {
            port powerIn {
                in brightness : Brightness;
            }
            exhibit state fixtureStates {
                entry; then off;
                state off;
                accept Brightness then on;
                state on;
                accept Brightness then off;
            }
        }

        requirement def EnergyEfficiency {
            doc /* The system shall minimize energy consumption by using daylight harvesting and occupancy-based control. */
        }
        requirement def OccupancyControl {
            doc /* Lights shall turn on when motion is detected and off after a timeout of no motion. */
        }
        requirement def DaylightHarvesting {
            doc /* Artificial lighting shall be dimmed in proportion to available daylight to maintain a target illuminance. */
        }
    }

    package Usages {
        private import Definitions::*;

        part networkController : NetworkController;
        part motionSensor : MotionSensor;
        part photocellSensor : PhotocellSensor;
        part relay1 : ChannelRelay;
        part relay2 : ChannelRelay;
        part relay3 : ChannelRelay;
        part relay4 : ChannelRelay;
        part fixture1 : LightingFixture;
        part fixture2 : LightingFixture;
        part fixture3 : LightingFixture;
        part fixture4 : LightingFixture;

        interface motionConnection connect motionSensor.outPort to networkController.motionPort {
            flow motionDetectedFlow of MotionDetected from motionSensor.outPort.motionDetected to networkController.motionPort.motionDetected;
            flow motionClearedFlow of MotionCleared from motionSensor.outPort.motionCleared to networkController.motionPort.motionCleared;
        }
        interface daylightConnection connect photocellSensor.outPort to networkController.daylightPort {
            flow daylightFlow of DaylightReading from photocellSensor.outPort.daylightReading to networkController.daylightPort.daylightReading;
        }

        interface relayConnection1 connect networkController.controlPort1 to relay1.inPort {
            flow cmdFlow1 of ControlCommand from networkController.controlPort1.command to relay1.inPort.command;
        }
        interface relayConnection2 connect networkController.controlPort2 to relay2.inPort {
            flow cmdFlow2 of ControlCommand from networkController.controlPort2.command to relay2.inPort.command;
        }
        interface relayConnection3 connect networkController.controlPort3 to relay3.inPort {
            flow cmdFlow3 of ControlCommand from networkController.controlPort3.command to relay3.inPort.command;
        }
        interface relayConnection4 connect networkController.controlPort4 to relay4.inPort {
            flow cmdFlow4 of ControlCommand from networkController.controlPort4.command to relay4.inPort.command;
        }

        interface powerConnection1 connect relay1.powerPort to fixture1.powerIn {
            flow powerFlow1 of Brightness from relay1.powerPort.brightness to fixture1.powerIn.brightness;
        }
        interface powerConnection2 connect relay2.powerPort to fixture2.powerIn {
            flow powerFlow2 of Brightness from relay2.powerPort.brightness to fixture2.powerIn.brightness;
        }
        interface powerConnection3 connect relay3.powerPort to fixture3.powerIn {
            flow powerFlow3 of Brightness from relay3.powerPort.brightness to fixture3.powerIn.brightness;
        }
        interface powerConnection4 connect relay4.powerPort to fixture4.powerIn {
            flow powerFlow4 of Brightness from relay4.powerPort.brightness to fixture4.powerIn.brightness;
        }

        requirement energyEfficiency : EnergyEfficiency;
        requirement occupancyControl : OccupancyControl;
        requirement daylightHarvesting : DaylightHarvesting;

        satisfy occupancyControl by networkController;
        satisfy daylightHarvesting by networkController;
        satisfy energyEfficiency by networkController;
    }
}
