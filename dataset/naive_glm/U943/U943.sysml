package WaterSensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def Length :> Real { unit 'm'; }
    value def VolumetricFlowRate :> Real { unit 'm3/s'; }
    value def Temperature :> Real { unit 'K'; }
    value def Turbidity :> Real { unit 'NTU'; }
    value def pH :> Real;
    value def Conductivity :> Real { unit 'S/m'; }
    value def QualityIndex :> Real;
    value def BatteryVoltage :> Real { unit 'V'; }
    value def BatteryCharge :> Real { unit 'Ah'; }
    value def TimeStamp :> Integer;

    // ---- Item definitions ----
    item def RawSensorData {
        attribute waterLevel : Length;
        attribute flowRate : VolumetricFlowRate;
        attribute temperature : Temperature;
        attribute turbidity : Turbidity;
        attribute pH : pH;
        attribute conductivity : Conductivity;
        attribute timestamp : TimeStamp;
    }

    item def ProcessedData {
        attribute waterLevel : Length;
        attribute flowRate : VolumetricFlowRate;
        attribute temperature : Temperature;
        attribute qualityIndex : QualityIndex;
        attribute turbidity : Turbidity;
        attribute pH : pH;
        attribute conductivity : Conductivity;
        attribute timestamp : TimeStamp;
        attribute confidence : Real;
    }

    item def TransmitPacket {
        attribute unitId : String;
        attribute payload : ProcessedData;
        attribute rssi : Real;
        attribute sequenceNumber : Integer;
    }

    item def CalibrationCommand {
        attribute targetParameter : String;
        attribute referenceValue : Real;
    }

    item def SystemCommand {
        attribute commandType : String;
        attribute commandPayload : String;
    }

    // ---- Interfaces ----
    interface def RawDataFlow {
        end supplier;
        end consumer;
        item raw : RawSensorData;
    }

    interface def ProcessedDataFlow {
        end supplier;
        end consumer;
        item processed : ProcessedData;
    }

    interface def PowerFlow {
        end source;
        end load;
        item voltage : BatteryVoltage;
        item availableCharge : BatteryCharge;
    }

    interface def CommandLink {
        end receiver;
        end sender;
        item command : SystemCommand;
        item calibration : CalibrationCommand;
    }

    // ---- Part definitions ----
    part def WaterSensor {
        attribute samplingRate : Real = 1.0;
        port rawOut : RawDataFlow::supplier;
        port powerIn : PowerFlow::load;

        action def takeReadings {
            in waterContact : Boolean;
            out readings : RawSensorData;
        }

        perform takeReadings {
            in waterContact = true;
            out readings;
        }
    }

    part def SignalProcessor {
        attribute filterType : String = "Kalman";
        attribute processNoise : Real = 0.01;
        attribute measurementNoise : Real = 0.05;
        port rawIn : RawDataFlow::consumer;
        port processedOut : ProcessedDataFlow::supplier;
        port powerIn : PowerFlow::load;

        action def filterData {
            in raw : RawSensorData;
            out processed : ProcessedData;
        }

        perform filterData {
            in raw;
            out processed;
        }

        action def computeQualityIndex {
            in turbidity : Turbidity;
            in pH : pH;
            in conductivity : Conductivity;
            out index : QualityIndex;
        }
    }

    part def DataTransmitter {
        attribute protocol : String = "LoRaWAN";
        attribute frequencyMHz : Real = 868.0;
        attribute maxPayloadBytes : Integer = 51;
        port dataIn : ProcessedDataFlow::consumer;
        port commandIn : CommandLink::receiver;
        port powerIn : PowerFlow::load;

        action def transmit {
            in packet : TransmitPacket;
            out ack : Boolean;
        }

        perform transmit {
            in packet;
            out ack;
        }

        action def packageData {
            in processed : ProcessedData;
            out packet : TransmitPacket;
        }
    }

    part def PowerSupply {
        attribute nominalVoltage : BatteryVoltage = 3.7;
        attribute capacity : BatteryCharge = 100.0;
        attribute estimatedLifetimeDays : Integer = 365;
        port powerOut : PowerFlow::source;

        action def monitorBattery {
            out voltage : BatteryVoltage;
            out remainingCharge : BatteryCharge;
        }
    }

    // ---- Composite system ----
    part def WaterSensingUnit {
        attribute unitId : String = "WSU-001";
        attribute deploymentLocation : String;
        attribute firmwareVersion : String = "1.4.0";

        port commandPort : CommandLink::receiver;

        part waterSensor : WaterSensor {
            port redefines rawOut;
            port redefines powerIn;
        }

        part signalProcessor : SignalProcessor {
            port redefines rawIn;
            port redefines processedOut;
            port redefines powerIn;
        }

        part dataTransmitter : DataTransmitter {
            port redefines dataIn;
            port redefines commandIn;
            port redefines powerIn;
        }

        part powerSupply : PowerSupply {
            port redefines powerOut;
        }

        connection rawLink : RawDataFlow connect waterSensor.rawOut to signalProcessor.rawIn;
        connection processedLink : ProcessedDataFlow connect signalProcessor.processedOut to dataTransmitter.dataIn;

        connection powerToSensor : PowerFlow connect powerSupply.powerOut to waterSensor.powerIn;
        connection powerToProcessor : PowerFlow connect powerSupply.powerOut to signalProcessor.powerIn;
        connection powerToTransmitter : PowerFlow connect powerSupply.powerOut to dataTransmitter.powerIn;

        connection commandLink : CommandLink connect commandPort to dataTransmitter.commandIn;

        // ---- State machine ----
        state def OperationMode {
            entry; then idle;

            state idle {
                entry {
                    // Low-power standby; peripherals disabled
                }
                do {
                    // Wait for scheduled interval or external trigger
                }
                transition idle_to_measuring
                    first idle
                    accept ScheduleTrigger
                    then measuring;

                transition idle_to_calibrating
                    first idle
                    accept CalibrationCommand
                    then calibrating;

                transition idle_to_error
                    first idle
                    accept FaultDetected
                    then errorState;
            }

            state measuring {
                entry {
                    // Activate sensor and acquire raw readings
                }
                do perform waterSensor.takeReadings {
                    in waterContact = true;
                    out readings;
                }
                transition measuring_to_processing
                    first measuring
                    accept ReadingsComplete
                    then processing;
            }

            state processing {
                entry {
                    // Apply Kalman filtering and compute quality index
                }
                do perform signalProcessor.filterData {
                    in raw;
                    out processed;
                }
                do perform signalProcessor.computeQualityIndex {
                    in turbidity;
                    in pH;
                    in conductivity;
                    out index;
                }
                transition processing_to_transmitting
                    first processing
                    accept ProcessingComplete
                    then transmitting;
            }

            state transmitting {
                entry {
                    // Package data and send via LoRaWAN
                }
                do perform dataTransmitter.packageData {
                    in processed;
                    out packet;
                }
                do perform dataTransmitter.transmit {
                    in packet;
                    out ack;
                }
                transition transmitting_to_idle
                    first transmitting
                    accept TransmissionComplete
                    then idle;

                transition transmitting_to_error
                    first transmitting
                    accept FaultDetected
                    then errorState;
            }

            state calibrating {
                entry {
                    // Enter maintenance calibration routine
                }
                do {
                    // Apply reference values to sensor channels
                }
                transition calibrating_to_idle
                    first calibrating
                    accept CalibrationComplete
                    then idle;

                transition calibrating_to_error
                    first calibrating
                    accept FaultDetected
                    then errorState;
            }

            state errorState {
                entry {
                    // Log fault, disable non-essential loads, raise alert
                }
                do {
                    // Attempt recovery or await service
                }
                transition error_to_idle
                    first errorState
                    accept FaultCleared
                    then idle;
            }
        }

        perform OperationMode;

        // ---- Occurrence definitions ----
        occurrence def ScheduleTrigger;
        occurrence def ReadingsComplete;
        occurrence def ProcessingComplete;
        occurrence def TransmissionComplete;
        occurrence def CalibrationComplete;
        occurrence def FaultDetected;
        occurrence def FaultCleared;
    }

    // ---- Requirements ----
    requirement def MeasurementRequirements {
        subject unit : WaterSensingUnit;
        requirement measureWaterLevel {
            subject :>> unit;
            doc /* The unit shall measure water level. */
            constraint { unit.waterSensor.takeReadings.readings.waterLevel >= 0.0 }
        }
        requirement measureFlowRate {
            subject :>> unit;
            doc /* The unit shall measure volumetric flow rate. */
            constraint { unit.waterSensor.takeReadings.readings.flowRate >= 0.0 }
        }
        requirement measureTemperature {
            subject :>> unit;
            doc /* The unit shall measure water temperature. */
            constraint { unit.waterSensor.takeReadings.readings.temperature > 273.15 }
        }
        requirement measureQualityIndex {
            subject :>> unit;
            doc /* The unit shall compute a quality index from turbidity, pH, and conductivity. */
            constraint { unit.signalProcessor.computeQualityIndex.index >= 0.0 }
        }
    }

    requirement def ProcessingRequirements {
        subject unit : WaterSensingUnit;
        requirement useKalmanFilter {
            subject :>> unit;
            doc /* The signal processor shall apply a Kalman filter to refine raw readings. */
            constraint { unit.signalProcessor.filterType == "Kalman" }
        }
        requirement produceProcessedData {
            subject :>> unit;
            doc /* The processor shall output processed data with a confidence metric. */
            constraint { unit.signalProcessor.filterData.processed.confidence >= 0.0 }
        }
    }

    requirement def TransmissionRequirements {
        subject unit : WaterSensingUnit;
        requirement useLoRaWAN {
            subject :>> unit;
            doc /* The transmitter shall use LoRaWAN for long-range low-power communication. */
            constraint { unit.dataTransmitter.protocol == "LoRaWAN" }
        }
        requirement transmitCompletePacket {
            subject :>> unit;
            doc /* The transmitter shall send a packet containing all processed parameters. */
            constraint { unit.dataTransmitter.packageData.packet.payload.qualityIndex >= 0.0 }
        }
    }

    requirement def PowerRequirements {
        subject unit : WaterSensingUnit;
        requirement batteryLifeOneYear {
            subject :>> unit;
            doc /* The power supply shall sustain operation for at least one year without maintenance. */
            constraint { unit.powerSupply.estimatedLifetimeDays >= 365 }
        }
        requirement supplyAllComponents {
            subject :>> unit;
            doc /* The power supply shall power the sensor, processor, and transmitter. */
            constraint { unit.powerSupply.nominalVoltage >= 3.3 }
        }
    }

    requirement def OperationalRequirements {
        subject unit : WaterSensingUnit;
        requirement idleDefault {
            subject :>> unit;
            doc /* The unit shall rest in an idle state between measurement cycles. */
            constraint { unit.OperationMode.idle.active }
        }
        requirement scheduledMeasurement {
            subject :>> unit;
            doc /* The unit shall perform a measurement cycle on schedule or trigger. */
            constraint { unit.OperationMode.measuring.active or unit.OperationMode.processing.active or unit.OperationMode.transmitting.active }
        }
        requirement remoteCalibration {
            subject :>> unit;
            doc /* The unit shall support remote command to enter calibration mode. */
            constraint { unit.OperationMode.calibrating.active }
        }
        requirement errorHandling {
            subject :>> unit;
            doc /* The unit shall enter an error state upon fault detection. */
            constraint { unit.OperationMode.errorState.active }
        }
    }

    requirement def WaterSensingUnitRequirements {
        subject unit : WaterSensingUnit;
        satisfy MeasurementRequirements by unit;
        satisfy ProcessingRequirements by unit;
        satisfy TransmissionRequirements by unit;
        satisfy PowerRequirements by unit;
        satisfy OperationalRequirements by unit;
    }

    // ---- Instantiated system with allocation ----
    part waterSensingUnitInstance : WaterSensingUnit {
        attribute deploymentLocation = "Reservoir North-3";
        attribute unitId = "WSU-001";

        part :>> waterSensor {
            attribute samplingRate = 0.5;
        }
        part :>> signalProcessor {
            attribute filterType = "Kalman";
            attribute processNoise = 0.008;
            attribute measurementNoise = 0.04;
        }
        part :>> dataTransmitter {
            attribute protocol = "LoRaWAN";
            attribute frequencyMHz = 868.0;
        }
        part :>> powerSupply {
            attribute nominalVoltage = 3.7;
            attribute capacity = 120.0;
            attribute estimatedLifetimeDays = 400;
        }
    }

    satisfy WaterSensingUnitRequirements by waterSensingUnitInstance;

}
