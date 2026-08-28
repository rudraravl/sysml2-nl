package KNXBuildingAutomation {
    private import ScalarValues::*;

    package Definitions {
        private import ScalarValues::*;

        value def Temperature :> ScalarValues::Real;
        value def Illuminance :> ScalarValues::Real;
        value def BrightnessPercent :> ScalarValues::Real;
        value def ValvePositionPercent :> ScalarValues::Real;

        item def Telegram {
            attribute sourceAddress : String;
            attribute destinationAddress : String;
            attribute groupAddress : String;
        }

        item def SensorTelegram :> Telegram {
            attribute sensorType : String;
            attribute measurement : Real;
        }

        item def CommandTelegram :> Telegram {
            attribute commandType : String;
            attribute setpoint : Real;
        }

        port def BusIF;

        part def KNXDevice {
            attribute physicalAddress : String;
            port busIF : ~BusIF;
        }

        part def TemperatureSensor :> KNXDevice {
            attribute measuredTemperature : Temperature;
            perform action senseAndBroadcast {
                action sendTelegram send new SensorTelegram(physicalAddress, "broadcast", "temperature", "temperature", measuredTemperature) via busIF;
            }
        }

        part def LightingSensor :> KNXDevice {
            attribute measuredIlluminance : Illuminance;
            perform action senseAndBroadcast {
                action sendTelegram send new SensorTelegram(physicalAddress, "broadcast", "illuminance", "illuminance", measuredIlluminance) via busIF;
            }
        }

        part def PresenceSensor :> KNXDevice {
            attribute presenceDetected : Boolean;
            perform action senseAndBroadcast {
                action sendTelegram send new SensorTelegram(physicalAddress, "broadcast", "presence", "presence", if presenceDetected then 1.0 else 0.0) via busIF;
            }
        }

        part def DimmingActuator :> KNXDevice {
            attribute brightnessLevel : BrightnessPercent;
            exhibit state actuatorBehavior {
                entry; then listening;
                state listening;
                transition receiveCommand
                    first listening
                    accept cmd : CommandTelegram via busIF
                    if cmd.commandType == "dim"
                    do send new Telegram(physicalAddress, "broadcast", "ack") via busIF
                    then listening;
            }
        }

        part def HeatingActuator :> KNXDevice {
            attribute valvePosition : ValvePositionPercent;
            exhibit state actuatorBehavior {
                entry; then listening;
                state listening;
                transition receiveCommand
                    first listening
                    accept cmd : CommandTelegram via busIF
                    if cmd.commandType == "heat"
                    do send new Telegram(physicalAddress, "broadcast", "ack") via busIF
                    then listening;
            }
        }

        part def AutomationController :> KNXDevice {
            attribute desiredTemperature : Temperature = 22.0;
            attribute desiredIlluminance : Illuminance = 500.0;

            exhibit state controllerBehavior {
                entry; then waitForTelegram;
                state waitForTelegram;

                transition handleTemperature
                    first waitForTelegram
                    accept tg : SensorTelegram via busIF
                    if tg.sensorType == "temperature"
                    do send new CommandTelegram(physicalAddress, "broadcast", "heating", "heat", desiredTemperature) via busIF
                    then waitForTelegram;

                transition handleIlluminance
                    first waitForTelegram
                    accept tg : SensorTelegram via busIF
                    if tg.sensorType == "illuminance"
                    do send new CommandTelegram(physicalAddress, "broadcast", "lighting", "dim", 80.0) via busIF
                    then waitForTelegram;

                transition handlePresence
                    first waitForTelegram
                    accept tg : SensorTelegram via busIF
                    if tg.sensorType == "presence"
                    do send new CommandTelegram(physicalAddress, "broadcast", "lighting", "dim", 80.0) via busIF
                    then waitForTelegram;
            }
        }

        part def PowerSupply :> KNXDevice {
            attribute outputVoltage : Real = 29.0;
            attribute maxCurrent : Real = 640.0;
        }

        part def LineCoupler :> KNXDevice {
            port secondaryBusIF : ~BusIF;
            exhibit state routingBehavior {
                entry; then listenPrimary;
                state listenPrimary;
                transition routeToSecondary
                    first listenPrimary
                    accept tg : Telegram via busIF
                    do send tg via secondaryBusIF
                    then listenPrimary;
                transition routeToPrimary
                    first listenPrimary
                    accept tg : Telegram via secondaryBusIF
                    do send tg via busIF
                    then listenPrimary;
            }
        }

        part def KNXBus {
            port deviceIF : BusIF [*];
        }
    }

    package Requirements {
        requirement ComfortRequirement {
            doc /* The system shall maintain room temperature within a reasonable range of the desired setpoint and provide adequate lighting when occupied. */
        }

        requirement EnergyOptimizationRequirement {
            doc /* The system shall minimize energy consumption by turning off lights and reducing heating when rooms are unoccupied. */
        }

        requirement DistributedCommunicationRequirement {
            doc /* All devices shall communicate via standardized KNX telegrams over a shared bus topology. */
        }

        requirement ScalabilityRequirement {
            doc /* The system architecture shall support expansion across multiple physical zones using line couplers. */
        }
    }

    package Usages {
        private import Definitions::*;
        private import Requirements::*;

        part buildingAutomation {
            part knxBus : KNXBus;

            part tempSensor : TemperatureSensor {
                attribute physicalAddress = "1.1.1";
            }
            connect tempSensor.busIF to knxBus.deviceIF;

            part lightSensor : LightingSensor {
                attribute physicalAddress = "1.1.2";
            }
            connect lightSensor.busIF to knxBus.deviceIF;

            part presenceSensor : PresenceSensor {
                attribute physicalAddress = "1.1.3";
            }
            connect presenceSensor.busIF to knxBus.deviceIF;

            part controller : AutomationController {
                attribute physicalAddress = "1.1.4";
            }
            connect controller.busIF to knxBus.deviceIF;

            part dimmingActuator : DimmingActuator {
                attribute physicalAddress = "1.1.5";
            }
            connect dimmingActuator.busIF to knxBus.deviceIF;

            part heatingActuator : HeatingActuator {
                attribute physicalAddress = "1.1.6";
            }
            connect heatingActuator.busIF to knxBus.deviceIF;

            part powerSupply : PowerSupply {
                attribute physicalAddress = "1.1.0";
            }
            connect powerSupply.busIF to knxBus.deviceIF;

            part lineCoupler : LineCoupler {
                attribute physicalAddress = "1.1.254";
            }
            connect lineCoupler.busIF to knxBus.deviceIF;

            satisfy ComfortRequirement by controller;
            satisfy EnergyOptimizationRequirement by controller;
            satisfy DistributedCommunicationRequirement by knxBus;
            satisfy ScalabilityRequirement by lineCoupler;
        }
    }
}
