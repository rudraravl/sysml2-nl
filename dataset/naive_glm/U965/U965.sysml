package AirQualityEgg {

    import ScalarValues::*;

    package ValueTypes {
        attribute def ConcentrationUGM3 :> Real {
            unit 'µg/m³';
        }
        attribute def ConcentrationPPM :> Real {
            unit 'ppm';
        }
        attribute def ConcentrationPPB :> Real {
            unit 'ppb';
        }
        attribute def TemperatureCelsius :> Real {
            unit '°C';
        }
        attribute def RelativeHumidity :> Real {
            unit '%';
        }
        attribute def AQIValue :> Real {
            unit 'AQI';
        }
        attribute def Voltage :> Real {
            unit 'V';
        }
        attribute def DurationSeconds :> Real {
            unit 's';
        }
        attribute def PowerWatts :> Real {
            unit 'W';
        }
    }

    package Items {
        item def PollutantReading {
            attribute no2 : ValueTypes::ConcentrationUGM3;
            attribute co : ValueTypes::ConcentrationPPM;
            attribute o3 : ValueTypes::ConcentrationPPB;
            attribute pm25 : ValueTypes::ConcentrationUGM3;
        }
        item def EnvironmentalReading {
            attribute temperature : ValueTypes::TemperatureCelsius;
            attribute humidity : ValueTypes::RelativeHumidity;
        }
        item def SensorData {
            attribute pollutants : PollutantReading;
            attribute environment : EnvironmentalReading;
            attribute timestamp : String;
        }
        item def CalibratedData {
            attribute pollutants : PollutantReading;
            attribute environment : EnvironmentalReading;
            attribute aqi : ValueTypes::AQIValue;
            attribute timestamp : String;
            attribute deviceId : String;
        }
        item def PowerInput {
            attribute voltage : ValueTypes::Voltage;
            attribute power : ValueTypes::PowerWatts;
        }
    }

    package Ports {
        port def SensorDataOut {
            out data : Items::SensorData;
        }
        port def CalibratedDataOut {
            out data : Items::CalibratedData;
        }
        port def PowerPort {
            out power : Items::PowerInput;
        }
        port def CloudDataPort {
            out data : Items::CalibratedData;
        }
    }

    package Components {

        part def NO2Sensor {
            port out rawNO2 : ValueTypes::ConcentrationUGM3;
            attribute samplingRate : ValueTypes::DurationSeconds = 60;
            attribute warmupTime : ValueTypes::DurationSeconds = 10;
            attribute operational : Boolean = true;
            action def SampleNO2 {
                out reading : ValueTypes::ConcentrationUGM3;
            }
            action sampleAction : SampleNO2;
        }

        part def COSensor {
            port out rawCO : ValueTypes::ConcentrationPPM;
            attribute samplingRate : ValueTypes::DurationSeconds = 60;
            attribute warmupTime : ValueTypes::DurationSeconds = 15;
            attribute operational : Boolean = true;
            action def SampleCO {
                out reading : ValueTypes::ConcentrationPPM;
            }
            action sampleAction : SampleCO;
        }

        part def O3Sensor {
            port out rawO3 : ValueTypes::ConcentrationPPB;
            attribute samplingRate : ValueTypes::DurationSeconds = 60;
            attribute warmupTime : ValueTypes::DurationSeconds = 12;
            attribute operational : Boolean = true;
            action def SampleO3 {
                out reading : ValueTypes::ConcentrationPPB;
            }
            action sampleAction : SampleO3;
        }

        part def PM25Sensor {
            port out rawPM25 : ValueTypes::ConcentrationUGM3;
            attribute samplingRate : ValueTypes::DurationSeconds = 60;
            attribute warmupTime : ValueTypes::DurationSeconds = 8;
            attribute operational : Boolean = true;
            action def SamplePM25 {
                out reading : ValueTypes::ConcentrationUGM3;
            }
            action sampleAction : SamplePM25;
        }

        part def EnvironmentalSensor {
            port out rawTemperature : ValueTypes::TemperatureCelsius;
            port out rawHumidity : ValueTypes::RelativeHumidity;
            attribute samplingRate : ValueTypes::DurationSeconds = 60;
            attribute operational : Boolean = true;
            action def SampleEnvironment {
                out temperature : ValueTypes::TemperatureCelsius;
                out humidity : ValueTypes::RelativeHumidity;
            }
            action sampleAction : SampleEnvironment;
        }

        part def SensorSuite {
            part no2Sensor : NO2Sensor;
            part coSensor : COSensor;
            part o3Sensor : O3Sensor;
            part pm25Sensor : PM25Sensor;
            part envSensor : EnvironmentalSensor;

            port out sensorData : Ports::SensorDataOut;

            action def AggregateReadings {
                in no2 : ValueTypes::ConcentrationUGM3;
                in co : ValueTypes::ConcentrationPPM;
                in o3 : ValueTypes::ConcentrationPPB;
                in pm25 : ValueTypes::ConcentrationUGM3;
                in temperature : ValueTypes::TemperatureCelsius;
                in humidity : ValueTypes::RelativeHumidity;
                out data : Items::SensorData;
            }
            action aggregateAction : AggregateReadings;

            connection no2ToAggregate from no2Sensor.rawNO2 to aggregateAction.no2;
            connection coToAggregate from coSensor.rawCO to aggregateAction.co;
            connection o3ToAggregate from o3Sensor.rawO3 to aggregateAction.o3;
            connection pm25ToAggregate from pm25Sensor.rawPM25 to aggregateAction.pm25;
            connection tempToAggregate from envSensor.rawTemperature to aggregateAction.temperature;
            connection humToAggregate from envSensor.rawHumidity to aggregateAction.humidity;
            connection aggregateToPort from aggregateAction.data to sensorData.data;
        }

        part def CentralProcessingUnit {
            port in sensorInput : Ports::SensorDataOut;
            port out calibratedOutput : Ports::CalibratedDataOut;
            port in power : Ports::PowerPort;

            attribute calibrationOffsetNO2 : ValueTypes::ConcentrationUGM3 = 0.0;
            attribute calibrationOffsetCO : ValueTypes::ConcentrationPPM = 0.0;
            attribute calibrationOffsetO3 : ValueTypes::ConcentrationPPB = 0.0;
            attribute calibrationOffsetPM25 : ValueTypes::ConcentrationUGM3 = 0.0;
            attribute deviceId : String = "AQE-00001";

            action def Calibrate {
                in raw : Items::SensorData;
                out calibrated : Items::PollutantReading;
            }
            action def ComputeAQI {
                in pollutants : Items::PollutantReading;
                out aqi : ValueTypes::AQIValue;
            }
            action def ProcessData {
                in raw : Items::SensorData;
                out result : Items::CalibratedData;
            }
            action calibrateAction : Calibrate;
            action computeAQIAction : ComputeAQI;
            action processAction : ProcessData;

            connection sensorToProcess from sensorInput.data to processAction.raw;
            connection processToCalibrate from processAction.raw to calibrateAction.raw;
            connection calibrateToAQI from calibrateAction.calibrated to computeAQIAction.pollutants;
            connection processToOutput from processAction.result to calibratedOutput.data;
        }

        part def WiFiTransceiver {
            port in dataInput : Ports::CalibratedDataOut;
            port out cloudLink : Ports::CloudDataPort;
            port in power : Ports::PowerPort;

            attribute ssid : String = "CommunityNet";
            attribute serverURL : String = "https://api.airqualityegg.org/v1/measurements";
            attribute connectionTimeout : ValueTypes::DurationSeconds = 30;
            attribute connected : Boolean = false;

            action def ConnectToNetwork {
                out success : Boolean;
            }
            action def TransmitData {
                in data : Items::CalibratedData;
                out success : Boolean;
            }
            action def Disconnect {
            }
            action connectAction : ConnectToNetwork;
            action transmitAction : TransmitData;
            action disconnectAction : Disconnect;

            connection dataToTransmit from dataInput.data to transmitAction.data;
            connection transmitToCloud from transmitAction.success to cloudLink.data;
        }

        part def PowerModule {
            port out regulatedPower : Ports::PowerPort;
            port in externalInput : Ports::PowerPort;

            attribute inputVoltage : ValueTypes::Voltage = 12.0;
            attribute cpuVoltage : ValueTypes::Voltage = 3.3;
            attribute sensorVoltage : ValueTypes::Voltage = 5.0;
            attribute wifiVoltage : ValueTypes::Voltage = 3.3;
            attribute maxPower : ValueTypes::PowerWatts = 5.0;

            action def RegulatePower {
                in input : Items::PowerInput;
                out cpuOut : Items::PowerInput;
                out sensorOut : Items::PowerInput;
                out wifiOut : Items::PowerInput;
            }
            action regulateAction : RegulatePower;

            connection externalToRegulate from externalInput.power to regulateAction.input;
            connection regulateToPort from regulateAction.cpuOut to regulatedPower.power;
        }
    }

    package Behaviors {

        action def SampleSensors {
            in sensorSuite : Components::SensorSuite;
            out data : Items::SensorData;
        }

        action def ProcessReadings {
            in cpu : Components::CentralProcessingUnit;
            in raw : Items::SensorData;
            out result : Items::CalibratedData;
        }

        action def TransmitResults {
            in wifi : Components::WiFiTransceiver;
            in data : Items::CalibratedData;
            out success : Boolean;
        }

        state def OperatingCycle {
            entry action initialize {
                // Power on all modules and verify sensor health
            }

            state Sampling {
                entry action startSensors {
                    // Trigger all sensors to begin sampling
                }
                do action collectReadings {
                    // Wait for samplingRate seconds and collect raw readings
                }
                exit action finalizeReadings {
                    // Aggregate readings into SensorData
                }
            }

            state Processing {
                entry action calibrateData {
                    // Apply calibration offsets to raw pollutant readings
                }
                do action computeAQI {
                    // Compute standardized AQI from calibrated pollutant levels
                }
                exit action packageResults {
                    // Assemble CalibratedData payload
                }
            }

            state Transmitting {
                entry action connectWiFi {
                    // Connect to configured WiFi network
                }
                do action sendData {
                    // POST measurement data to cloud server
                }
                exit action disconnectWiFi {
                    // Close network connection
                }
            }

            state Idle {
                entry action enterLowPower {
                    // Reduce power consumption between cycles
                }
                do action waitForNextCycle {
                    // Wait for configured sampling interval to elapse
                }
                exit action wakeUp {
                    // Restore full power and prepare sensors
                }
            }

            transition from Sampling to Processing when Sampling.done;
            transition from Processing to Transmitting when Processing.done;
            transition from Transmitting to Idle when Transmitting.done;
            transition from Idle to Sampling when Idle.done;

            attribute cycleInterval : ValueTypes::DurationSeconds = 60;
        }
    }

    package System {

        part def AirQualityEggDevice {
            part sensorSuite : Components::SensorSuite;
            part cpu : Components::CentralProcessingUnit;
            part wifi : Components::WiFiTransceiver;
            part power : Components::PowerModule;

            port externalPower : Ports::PowerPort;
            port cloudConnection : Ports::CloudDataPort;

            attribute samplingInterval : ValueTypes::DurationSeconds = 60;
            attribute firmwareVersion : String = "2.1.0";
            attribute location : String = "CommunityStation-001";

            connection externalToPower from externalPower to power.externalInput;
            connection powerToCPU from power.regulatedPower to cpu.power;
            connection powerToWiFi from power.regulatedPower to wifi.power;
            connection sensorToCPU from sensorSuite.sensorData to cpu.sensorInput;
            connection cpuToWiFi from cpu.calibratedOutput to wifi.dataInput;
            connection wifiToCloud from wifi.cloudLink to cloudConnection;

            exhibit Behaviors::OperatingCycle;
        }

        part airQualityEgg : AirQualityEggDevice;
    }

    package Requirements {

        requirement def MeasurePollutants {
            doc "The system shall continuously measure NO2, CO, O3, and PM2.5 concentrations.";
            subject device : System::AirQualityEggDevice;
            objective measureAllPollutants {
                device.sensorSuite.no2Sensor.operational == true and
                device.sensorSuite.coSensor.operational == true and
                device.sensorSuite.o3Sensor.operational == true and
                device.sensorSuite.pm25Sensor.operational == true
            }
        }

        requirement def MeasureEnvironment {
            doc "The system shall measure ambient temperature and humidity.";
            subject device : System::AirQualityEggDevice;
            objective measureEnv {
                device.sensorSuite.envSensor.operational == true
            }
        }

        requirement def ComputeAQIRequirement {
            doc "The system shall compute a standardized Air Quality Index from calibrated pollutant readings.";
            subject device : System::AirQualityEggDevice;
            objective computeAQI {
                device.cpu.calibratedOutput.data.aqi >= 0
            }
        }

        requirement def TransmitDataRequirement {
            doc "The system shall transmit pollutant levels, environmental conditions, and AQI to a central cloud server via WiFi.";
            subject device : System::AirQualityEggDevice;
            objective transmitData {
                device.wifi.connected == true and
                device.cloudConnection.data.aqi >= 0
            }
        }

        requirement def ContinuousCycleRequirement {
            doc "The system shall operate in a continuous cycle of sampling, processing, transmitting, and waiting at a configurable interval.";
            subject device : System::AirQualityEggDevice;
            objective continuousCycle {
                device.samplingInterval >= 30 and
                device.samplingInterval <= 3600
            }
        }

        requirement def PowerRegulationRequirement {
            doc "The power module shall regulate a standard input voltage for all internal components.";
            subject device : System::AirQualityEggDevice;
            objective regulatePower {
                device.power.cpuVoltage == 3.3 and
                device.power.sensorVoltage == 5.0 and
                device.power.wifiVoltage == 3.3 and
                device.power.inputVoltage == 12.0
            }
        }

        requirement def CalibrationRequirement {
            doc "The CPU shall calibrate raw sensor data for accuracy before computing AQI.";
            subject device : System::AirQualityEggDevice;
            objective calibrate {
                device.cpu.calibrationOffsetNO2 >= 0 and
                device.cpu.calibrationOffsetCO >= 0 and
                device.cpu.calibrationOffsetO3 >= 0 and
                device.cpu.calibrationOffsetPM25 >= 0
            }
        }

        requirement def AirQualityEggRequirements {
            requirement measurePollutants : MeasurePollutants;
            requirement measureEnvironment : MeasureEnvironment;
            requirement computeAQI : ComputeAQIRequirement;
            requirement transmitData : TransmitDataRequirement;
            requirement continuousCycle : ContinuousCycleRequirement;
            requirement powerRegulation : PowerRegulationRequirement;
            requirement calibration : CalibrationRequirement;
        }

        package Verification {
            verification verifyPollutantMeasurement for MeasurePollutants {
                subject device : System::AirQualityEggDevice;
                objective {
                    device.sensorSuite.no2Sensor.operational == true
                }
            }
            verification verifyAQIComputation for ComputeAQIRequirement {
                subject device : System::AirQualityEggDevice;
                objective {
                    device.cpu.calibratedOutput.data.aqi >= 0
                }
            }
            verification verifyDataTransmission for TransmitDataRequirement {
                subject device : System::AirQualityEggDevice;
                objective {
                    device.wifi.connected == true
                }
            }
        }
    }
}
