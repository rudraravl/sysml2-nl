package CO2SensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    // ===== Value Types =====
    attribute def Concentration {
        :>> value : Real;
        :>> unit : String = "ppm";
    }

    attribute def RelativeHumidity {
        :>> value : Real;
        :>> unit : String = "%";
    }

    attribute def Voltage {
        :>> value : Real;
        :>> unit : String = "V";
    }

    attribute def Duration {
        :>> value : Real;
        :>> unit : String = "s";
    }

    attribute def TemperatureK {
        :>> value : Real;
        :>> unit : String = "K";
    }

    // ===== Item Definitions =====
    item def AirSample {
        attribute co2Concentration : Concentration;
        attribute temperature : TemperatureK;
        attribute humidity : RelativeHumidity;
    }

    item def RawCO2Reading {
        attribute rawValue : Concentration;
        attribute timestamp : String;
    }

    item def CompensatedReading {
        attribute co2Concentration : Concentration;
        attribute temperature : TemperatureK;
        attribute humidity : RelativeHumidity;
    }

    item def MeasurementReport {
        attribute co2Concentration : Concentration;
        attribute timestamp : String;
        attribute status : String;
        attribute calibrated : Boolean;
    }

    item def PowerInput {
        attribute voltage : Voltage;
    }

    item def RegulatedPower {
        attribute voltage : Voltage = 5.0;
    }

    item def Command {
        attribute commandType : String;
    }

    // ===== Port Definitions =====
    port def AirIntakePort {
        out airSample : AirSample;
    }

    port def PowerInputPort {
        in power : PowerInput;
    }

    port def RegulatedPowerPort {
        out power : RegulatedPower;
    }

    port def RawDataPort {
        out rawReading : RawCO2Reading;
    }

    port def ProcessedDataPort {
        out report : MeasurementReport;
    }

    port def CommandPort {
        in command : Command;
    }

    // ===== Requirements =====
    requirement def MeasurementRangeRequirement {
        doc /* The unit shall measure CO2 concentrations from 0 to 5000 ppm. */
        attribute minRange : Concentration = 0.0;
        attribute maxRange : Concentration = 5000.0;
        constraint { 0.0 <= measuredValue.value and measuredValue.value <= 5000.0 }
        attribute measuredValue : Concentration;
    }

    requirement def AccuracyRequirement {
        doc /* The unit shall measure CO2 with an accuracy of ±50 ppm. */
        attribute accuracy : Concentration = 50.0;
        attribute trueValue : Concentration;
        attribute measuredValue : Concentration;
        constraint { abs(measuredValue.value - trueValue.value) <= 50.0 }
    }

    requirement def ResponseTimeRequirement {
        doc /* The unit shall provide a valid measurement within 30 seconds of a command. */
        attribute maxResponseTime : Duration = 30.0;
        attribute actualResponseTime : Duration;
        constraint { actualResponseTime.value <= 30.0 }
    }

    requirement def OperatingTemperatureRequirement {
        doc /* The unit shall operate reliably within -10°C to 50°C (263.15K to 323.15K). */
        attribute minTemp : TemperatureK = 263.15;
        attribute maxTemp : TemperatureK = 323.15;
        attribute ambientTemp : TemperatureK;
        constraint { 263.15 <= ambientTemp.value and ambientTemp.value <= 323.15 }
    }

    // ===== Parts =====
    part def PowerSupply {
        port powerIn : PowerInputPort;
        port powerOut : RegulatedPowerPort;

        attribute inputVoltage : Voltage;
        attribute outputVoltage : Voltage = 5.0;

        action def regulate :> Actions::Action {
            in inPower : PowerInput;
            out outPower : RegulatedPower;
        }

        perform regulate;
    }

    part def CarbonDioxideSensor {
        port airIntake : AirIntakePort;
        port powerIn : RegulatedPowerPort;
        port rawDataOut : RawDataPort;

        attribute warmUpTime : Duration = 15.0;
        attribute isCalibrated : Boolean = true;
        attribute operatingTemp : TemperatureK;

        action def warmUp :> Actions::Action {
            out ready : Boolean;
        }

        action def detect :> Actions::Action {
            in sample : AirSample;
            out raw : RawCO2Reading;
        }

        perform warmUp;
        perform detect;
    }

    part def SignalProcessor {
        port rawDataIn : RawDataPort;
        port processedDataOut : ProcessedDataPort;

        action def compensate :> Actions::Action {
            in raw : RawCO2Reading;
            in temperature : TemperatureK;
            in humidity : RelativeHumidity;
            out compensated : CompensatedReading;
        }

        action def validate :> Actions::Action {
            in compensated : CompensatedReading;
            out valid : Boolean;
        }

        action def createReport :> Actions::Action {
            in compensated : CompensatedReading;
            in valid : Boolean;
            in calibrated : Boolean;
            out report : MeasurementReport;
        }

        perform compensate;
        perform validate;
        perform createReport;
    }

    // ===== Top-level CO2 Sensing Unit =====
    part def CO2SensingUnit {
        port externalPower : PowerInputPort;
        port airIntake : AirIntakePort;
        port commandIn : CommandPort;
        port dataOut : ProcessedDataPort;

        satisfy MeasurementRangeRequirement {
            attribute measuredValue : Concentration;
        }

        satisfy AccuracyRequirement {
            attribute trueValue : Concentration;
            attribute measuredValue : Concentration;
        }

        satisfy ResponseTimeRequirement {
            attribute actualResponseTime : Duration;
        }

        satisfy OperatingTemperatureRequirement {
            attribute ambientTemp : TemperatureK;
        }

        part powerSupply : PowerSupply {
            port powerIn : PowerInputPort = externalPower;
            port powerOut : RegulatedPowerPort;
        }

        part co2Sensor : CarbonDioxideSensor {
            port airIntake : AirIntakePort = CO2SensingUnit::airIntake;
            port powerIn : RegulatedPowerPort = powerSupply.powerOut;
            port rawDataOut : RawDataPort;
        }

        part signalProcessor : SignalProcessor {
            port rawDataIn : RawDataPort = co2Sensor.rawDataOut;
            port processedDataOut : ProcessedDataPort = CO2SensingUnit::dataOut;
        }

        connection powerConnection connect powerSupply.powerOut to co2Sensor.powerIn;
        connection dataConnection connect co2Sensor.rawDataOut to signalProcessor.rawDataIn;
        connection outputConnection connect signalProcessor.processedDataOut to CO2SensingUnit::dataOut;

        // ===== State Machine =====
        state machine CO2SensingUnitStateMachine {
            attribute warmUpTimer : Duration = 0.0;
            attribute responseTimer : Duration = 0.0;
            attribute currentStatus : String = "idle";

            state idle;
            state warming;
            state ready;
            state measuring;
            state error;

            transition idle_to_warming first idle if commandIn.command.commandType == "warmup" then warming {
                assign warmUpTimer := 0.0;
                assign responseTimer := 0.0;
                assign currentStatus := "warming";
            }

            transition warming_to_ready first warming if warmUpTimer.value >= co2Sensor.warmUpTime.value then ready {
                assign currentStatus := "ready";
            }

            transition warming_to_error first warming if currentStatus == "error" then error {
                assign currentStatus := "error";
            }

            transition ready_to_measuring first ready if commandIn.command.commandType == "measure" then measuring {
                assign responseTimer := 0.0;
                assign currentStatus := "measuring";
            }

            transition measuring_to_ready first measuring if dataOut.report.status == "valid" then ready {
                assign currentStatus := "ready";
            }

            transition measuring_to_error first measuring if currentStatus == "error" then error {
                assign currentStatus := "error";
            }

            transition any_to_idle first measuring if commandIn.command.commandType == "reset" then idle {
                assign currentStatus := "idle";
                assign warmUpTimer := 0.0;
                assign responseTimer := 0.0;
            }

            transition error_to_idle first error if commandIn.command.commandType == "reset" then idle {
                assign currentStatus := "idle";
                assign warmUpTimer := 0.0;
                assign responseTimer := 0.0;
            }

            entry warming {
                perform co2Sensor.warmUp;
            }

            entry measuring {
                perform co2Sensor.detect;
                perform signalProcessor.compensate;
                perform signalProcessor.validate;
                perform signalProcessor.createReport;
            }
        }

        exhibit CO2SensingUnitStateMachine;
    }
}
