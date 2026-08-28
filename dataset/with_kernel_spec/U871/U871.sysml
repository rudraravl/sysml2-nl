package TemperatureSensingUnitModel {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQ::TemperatureValue;
    private import ISQ::ElectricPotentialValue;
    private import ISQ::TimeValue;

    package Definitions {
        package ItemDefinitions {
            item def TemperatureReading {
                attribute value : TemperatureValue;
                attribute sensorId : String;
                attribute isActive : Boolean;
                attribute timestamp : TimeValue;
            }

            item def AggregatedTemperature {
                attribute average : TemperatureValue;
                attribute minimum : TemperatureValue;
                attribute maximum : TemperatureValue;
                attribute activeSensorCount : Integer;
                attribute timestamp : TimeValue;
            }

            item def ControlCommand {
                attribute commandKind : CommandKind;
            }

            enum def CommandKind {
                start;
                stop;
                enterMaintenance;
                exitMaintenance;
                reset;
            }

            item def SystemStatus {
                attribute quality : DataQuality;
                attribute uptime : TimeValue;
                attribute lastMeasurementTime : TimeValue;
            }

            enum def DataQuality {
                nominal;
                degraded;
                failed;
            }

            attribute def InitializationComplete;
            attribute def MeasurementComplete;
            attribute def MaintenanceRequired;
            attribute def MaintenanceComplete;
            attribute def TriggerMeasurementSignal;
        }

        package PortDefinitions {
            private import ItemDefinitions::*;

            port def PowerPort {
                out voltage : ElectricPotentialValue;
            }

            port def SensorDataPort {
                out readings : TemperatureReading[*];
            }

            port def AggregatedDataPort {
                out aggregated : AggregatedTemperature;
            }

            port def ControlPort {
                out command : ControlCommand;
            }

            port def CommandInPort {
                in command : ControlCommand;
            }

            port def StatusPort {
                out status : SystemStatus;
            }
        }

        package ActionDefinitions {
            private import ItemDefinitions::*;

            action def MeasureTemperature {
                out reading : TemperatureReading;
            }

            action def CalibrateSensor {
                in referenceTemperature : TemperatureValue;
                out newOffset : TemperatureValue;
            }

            action def AggregateData {
                in readings : TemperatureReading[*];
                out aggregated : AggregatedTemperature;
                language "Alf"
                    /*
                     * var activeReadings = readings.?{in r : TemperatureReading; r.isActive};
                     * aggregated.activeSensorCount = activeReadings->size();
                     * var values = activeReadings.{in r : TemperatureReading; r.value};
                     * aggregated.average = values->reduce{in x : Real; in y : Real; x + y} / activeReadings->size();
                     * aggregated.minimum = values->reduce{in x : Real; in y : Real; if x < y then x else y endif};
                     * aggregated.maximum = values->reduce{in x : Real; in y : Real; if x > y then x else y endif};
                     * aggregated.timestamp = 0.0 [s];
                     */
            }

            action def TriggerMeasurement {
                out command : ControlCommand;
            }
        }

        package PartDefinitions {
            private import ItemDefinitions::*;
            private import PortDefinitions::*;
            private import ActionDefinitions::*;

            part def PowerSupply {
                attribute outputVoltage : ElectricPotentialValue = 24.0 [V];
                port powerOut : PowerPort;
            }

            part def TemperatureSensor {
                attribute id : String;
                attribute calibrated : Boolean;
                attribute isActive : Boolean default true;
                attribute calibrationOffset : TemperatureValue default 0.0 [K];
                attribute measurementRangeMin : TemperatureValue = -40.0 [K];
                attribute measurementRangeMax : TemperatureValue = 125.0 [K];
                attribute reading : TemperatureValue;
                port powerIn : PowerPort;
                port dataOut : SensorDataPort;
                perform action measure : MeasureTemperature;
                perform action calibrate : CalibrateSensor;
                assert constraint {
                    reading >= measurementRangeMin and reading <= measurementRangeMax
                }
            }

            part def SensorArray {
                part sensor1 : TemperatureSensor;
                part sensor2 : TemperatureSensor;
                part sensor3 : TemperatureSensor;
                part sensor4 : TemperatureSensor;
                port powerIn : PowerPort;
                port arrayDataOut : SensorDataPort;
                port controlIn : ControlPort;
                connect powerIn to sensor1.powerIn;
                connect powerIn to sensor2.powerIn;
                connect powerIn to sensor3.powerIn;
                connect powerIn to sensor4.powerIn;
                flow sensor1.dataOut to arrayDataOut;
                flow sensor2.dataOut to arrayDataOut;
                flow sensor3.dataOut to arrayDataOut;
                flow sensor4.dataOut to arrayDataOut;
            }

            part def DataAggregator {
                port powerIn : PowerPort;
                port dataIn : SensorDataPort;
                port dataOut : AggregatedDataPort;
                perform action aggregateData : AggregateData;
            }

            part def SensingController {
                attribute measurementInterval : TimeValue = 0.5 [s];
                port powerIn : PowerPort;
                port dataIn : AggregatedDataPort;
                port controlOut : ControlPort;
                port commandIn : CommandInPort;
                port statusOut : StatusPort;
                perform action triggerMeasurement : TriggerMeasurement;
                exhibit state controllerStates {
                    entry action initial { }
                    transition initial then Initializing;
                    state Initializing;
                    transition init_to_ready
                        first Initializing
                        accept InitializationComplete
                        then Standby;
                    state Standby;
                    transition standby_to_measuring
                        first Standby
                        accept TriggerMeasurementSignal
                        then Measuring;
                    state Measuring {
                        do send new TriggerMeasurementSignal() to controlOut;
                    }
                    transition measuring_to_standby
                        first Measuring
                        accept MeasurementComplete
                        then Standby;
                    state Maintenance;
                    transition standby_to_maintenance
                        first Standby
                        accept MaintenanceRequired
                        then Maintenance;
                    transition maintenance_to_standby
                        first Maintenance
                        accept MaintenanceComplete
                        then Standby;
                }
            }

            part def TemperatureSensingUnit {
                part powerSupply : PowerSupply;
                part controller : SensingController;
                part sensorArray : SensorArray;
                part aggregator : DataAggregator;

                port externalDataOut : AggregatedDataPort;
                port externalCommandIn : CommandInPort;
                port externalStatusOut : StatusPort;

                connect powerSupply.powerOut to controller.powerIn;
                connect powerSupply.powerOut to sensorArray.powerIn;
                connect powerSupply.powerOut to aggregator.powerIn;
                connect controller.controlOut to sensorArray.controlIn;
                flow sensorArray.arrayDataOut to aggregator.dataIn;
                flow aggregator.dataOut to controller.dataIn;
                flow aggregator.dataOut to externalDataOut;
                connect externalCommandIn to controller.commandIn;
                connect controller.statusOut to externalStatusOut;
            }
        }

        package RequirementDefinitions {
            private import PartDefinitions::*;

            requirement def RedundancyRequirement {
                doc
                /*
                 * The sensor array shall contain four temperature sensors to provide
                 * redundancy and fault tolerance, allowing continued operation even if
                 * one or two sensors fail.
                 */
                subject sensorArray : SensorArray;
                assert constraint {
                    sensorArray.sensor1 <> null and
                    sensorArray.sensor2 <> null and
                    sensorArray.sensor3 <> null and
                    sensorArray.sensor4 <> null
                }
            }

            requirement def MeasurementRangeRequirement {
                doc
                /*
                 * Each temperature sensor shall measure temperatures in the range
                 * from -40 K to 125 K.
                 */
                subject sensor : TemperatureSensor;
                assert constraint {
                    sensor.measurementRangeMin <= -40.0 [K] and
                    sensor.measurementRangeMax >= 125.0 [K]
                }
            }

            requirement def MeasurementIntervalRequirement {
                doc
                /*
                 * The sensing controller shall trigger measurements every 0.5 seconds.
                 */
                subject controller : SensingController;
                assert constraint {
                    controller.measurementInterval == 0.5 [s]
                }
            }

            requirement def PowerSupplyRequirement {
                doc
                /*
                 * The unit shall be powered by an integrated 24-volt power supply.
                 */
                subject powerSupply : PowerSupply;
                assert constraint {
                    powerSupply.outputVoltage == 24.0 [V]
                }
            }

            requirement def AggregationRequirement {
                doc
                /*
                 * The data aggregator shall filter out inactive or faulty sensors and
                 * compute the average, minimum, and maximum temperature across the
                 * active sensors in the array.
                 */
                subject aggregator : DataAggregator;
                assert constraint {
                    aggregator.aggregateData.aggregated.activeSensorCount >= 1
                }
            }
        }
    }

    package Usages {
        private import Definitions::*;

        part tempUnit : TemperatureSensingUnit {
            satisfy RedundancyRequirement by sensorArray;
            satisfy MeasurementRangeRequirement by sensorArray.sensor1;
            satisfy MeasurementRangeRequirement by sensorArray.sensor2;
            satisfy MeasurementRangeRequirement by sensorArray.sensor3;
            satisfy MeasurementRangeRequirement by sensorArray.sensor4;
            satisfy MeasurementIntervalRequirement by controller;
            satisfy PowerSupplyRequirement by powerSupply;
            satisfy AggregationRequirement by aggregator;
        }
    }
}
