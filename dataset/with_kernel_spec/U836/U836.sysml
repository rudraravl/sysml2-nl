package DigitalAspiratedPsychrometer {
    private import ISQ::*;
    private import ScalarValues::*;

    item def RelativeHumidityValue :> Real;
    item def AirflowRateValue :> Real;
    item def WaterVolumeValue :> Real;

    port def TempOutPort {
        out temp : TemperatureValue;
    }
    port def TempInPort {
        in temp : TemperatureValue;
    }
    port def PressureInPort {
        in pressure : PressureValue;
    }
    port def AirOutPort {
        out air : AirflowRateValue;
    }
    port def AirInPort {
        in air : AirflowRateValue;
    }
    port def WaterOutPort {
        out water : WaterVolumeValue;
    }
    port def WaterInPort {
        in water : WaterVolumeValue;
    }
    port def HumidityOutPort {
        out humidity : RelativeHumidityValue;
        out dryTemp : TemperatureValue;
        out wetTemp : TemperatureValue;
    }
    port def HumidityInPort {
        in humidity : RelativeHumidityValue;
        in dryTemp : TemperatureValue;
        in wetTemp : TemperatureValue;
    }

    interface def TempInterface {
        end outPort : TempOutPort;
        end inPort : TempInPort;
        flow tempFlow of TemperatureValue from outPort.temp to inPort.temp;
    }
    interface def AirInterface {
        end outPort : AirOutPort;
        end inPort : AirInPort;
        flow airFlow of AirflowRateValue from outPort.air to inPort.air;
    }
    interface def WaterInterface {
        end outPort : WaterOutPort;
        end inPort : WaterInPort;
        flow waterFlow of WaterVolumeValue from outPort.water to inPort.water;
    }
    interface def HumidityInterface {
        end outPort : HumidityOutPort;
        end inPort : HumidityInPort;
        flow humidityFlow of RelativeHumidityValue from outPort.humidity to inPort.humidity;
        flow dryTempFlow of TemperatureValue from outPort.dryTemp to inPort.dryTemp;
        flow wetTempFlow of TemperatureValue from outPort.wetTemp to inPort.wetTemp;
    }

    calc def SaturationVaporPressure {
        in temperature : TemperatureValue;
        return svp : PressureValue;
    }
    calc def CalculateRelativeHumidity {
        in dryBulbTemp : TemperatureValue;
        in wetBulbTemp : TemperatureValue;
        in atmosphericPressure : PressureValue;
        return humidity : RelativeHumidityValue;
    }

    part def DryBulbThermometer {
        port airIn : AirInPort;
        port tempOut : TempOutPort;
        attribute measuredTemp : TemperatureValue;
        attribute activationSignal : Boolean;

        state machine DryBulbBehavior {
            state idle;
            state measuring;
            transition t1 first idle to measuring {
                guard activationSignal;
            }
        }

        action measureTemperature {
            out reading : TemperatureValue;
        }
    }

    part def WetBulbThermometer {
        port airIn : AirInPort;
        port waterIn : WaterInPort;
        port tempOut : TempOutPort;
        attribute measuredTemp : TemperatureValue;
        attribute activationSignal : Boolean;
        attribute wickDry : Boolean;
        attribute wickMoist : Boolean;

        state machine WetBulbBehavior {
            state idle;
            state measuring;
            state dryWick;
            transition t1 first idle to measuring {
                guard activationSignal;
            }
            transition t2 first measuring to dryWick {
                guard wickDry;
            }
            transition t3 first dryWick to measuring {
                guard wickMoist;
            }
        }

        action measureTemperature {
            out reading : TemperatureValue;
        }
    }

    part def WaterReservoir {
        port waterOut : WaterOutPort;
        attribute capacity : WaterVolumeValue;
        attribute currentLevel : WaterVolumeValue;
        attribute lowThreshold : WaterVolumeValue;

        state machine ReservoirBehavior {
            state full;
            state low;
            state empty;
            transition t1 first full to low {
                guard currentLevel <= lowThreshold;
            }
            transition t2 first low to empty {
                guard currentLevel <= 0.0;
            }
            transition t3 first empty to full {
                guard currentLevel >= capacity;
            }
        }
    }

    part def VentilationFan {
        port airOut : AirOutPort;
        attribute targetFlowRate : AirflowRateValue;
        attribute currentFlowRate : AirflowRateValue;
        attribute startCommand : Boolean;
        attribute stopCommand : Boolean;
        attribute motorFailure : Boolean;

        state machine FanBehavior {
            state off;
            state running;
            state fault;
            transition t1 first off to running {
                guard startCommand;
            }
            transition t2 first running to off {
                guard stopCommand;
            }
            transition t3 first running to fault {
                guard motorFailure;
            }
        }

        action runFan {
            out flowRate : AirflowRateValue;
        }
    }

    part def HumidityProcessor {
        port dryTempIn : TempInPort;
        port wetTempIn : TempInPort;
        port pressureIn : PressureInPort;
        port humidityOut : HumidityOutPort;
        attribute calculatedHumidity : RelativeHumidityValue;
        attribute validatedDryTemp : TemperatureValue;
        attribute validatedWetTemp : TemperatureValue;
        attribute atmosphericPressure : PressureValue;
        attribute dataReceived : Boolean;
        attribute inputsValid : Boolean;
        attribute inputsInvalid : Boolean;
        attribute computationComplete : Boolean;
        attribute resultsSent : Boolean;
        attribute errorCleared : Boolean;

        state machine ProcessorBehavior {
            state idle;
            state validating;
            state computing;
            state outputting;
            state error;
            transition t1 first idle to validating {
                guard dataReceived;
            }
            transition t2 first validating to computing {
                guard inputsValid;
            }
            transition t3 first validating to error {
                guard inputsInvalid;
            }
            transition t4 first computing to outputting {
                guard computationComplete;
            }
            transition t5 first outputting to idle {
                guard resultsSent;
            }
            transition t6 first error to idle {
                guard errorCleared;
            }
        }

        action validateInputs {
            in dryTemp : TemperatureValue;
            in wetTemp : TemperatureValue;
            out valid : Boolean;
        }

        action computeHumidity {
            in dryTemp : TemperatureValue;
            in wetTemp : TemperatureValue;
            in pressure : PressureValue;
            out humidity : RelativeHumidityValue;
        }

        action sendResults {
            out humidity : RelativeHumidityValue;
            out dryTemp : TemperatureValue;
            out wetTemp : TemperatureValue;
        }
    }

    part def DisplayUnit {
        port humidityIn : HumidityInPort;
        attribute displayedHumidity : RelativeHumidityValue;
        attribute displayedDryTemp : TemperatureValue;
        attribute displayedWetTemp : TemperatureValue;
        attribute inactivityTimeout : Boolean;
        attribute userInteraction : Boolean;
        attribute powerOffCommand : Boolean;
        attribute powerOnCommand : Boolean;

        state machine DisplayBehavior {
            state on;
            state dimmed;
            state off;
            transition t1 first on to dimmed {
                guard inactivityTimeout;
            }
            transition t2 first dimmed to on {
                guard userInteraction;
            }
            transition t3 first on to off {
                guard powerOffCommand;
            }
            transition t4 first off to on {
                guard powerOnCommand;
            }
        }

        action refreshDisplay {
            in humidity : RelativeHumidityValue;
            in dryTemp : TemperatureValue;
            in wetTemp : TemperatureValue;
        }
    }

    part def PsychrometerSystem {
        port pressureIn : PressureInPort;

        part fan : VentilationFan;
        part dryBulb : DryBulbThermometer;
        part wetBulb : WetBulbThermometer;
        part reservoir : WaterReservoir;
        part processor : HumidityProcessor;
        part display : DisplayUnit;

        bind pressureIn = processor.pressureIn;

        interface : AirInterface connect fan.airOut to dryBulb.airIn;
        interface : AirInterface connect fan.airOut to wetBulb.airIn;
        interface : WaterInterface connect reservoir.waterOut to wetBulb.waterIn;
        interface : TempInterface connect dryBulb.tempOut to processor.dryTempIn;
        interface : TempInterface connect wetBulb.tempOut to processor.wetTempIn;
        interface : HumidityInterface connect processor.humidityOut to display.humidityIn;
    }

    requirement def HumidityAccuracyReqDef {
        doc /* The system shall measure relative humidity with an accuracy of plus or minus 2 percent. */
        attribute measuredHumidity : RelativeHumidityValue;
        attribute actualHumidity : RelativeHumidityValue;
        attribute maxError : RelativeHumidityValue = 2.0;
        require constraint { abs(measuredHumidity - actualHumidity) <= maxError }
    }

    requirement def OperatingTempRangeReqDef {
        doc /* The system shall operate within a temperature range of -10 degrees C to 50 degrees C. */
        attribute minTemp : TemperatureValue = -10 [degC];
        attribute maxTemp : TemperatureValue = 50 [degC];
        attribute operatingTemp : TemperatureValue;
        require constraint { operatingTemp >= minTemp && operatingTemp <= maxTemp }
    }

    requirement def ResponseTimeReqDef {
        doc /* The system shall provide stable humidity measurements within 30 seconds of activation. */
        attribute responseTime : TimeValue;
        attribute maxResponseTime : TimeValue = 30 [s];
        require constraint { responseTime <= maxResponseTime }
    }

    requirement psychrometerRequirements {
        requirement humidityReq : HumidityAccuracyReqDef;
        requirement tempRangeReq : OperatingTempRangeReqDef;
        requirement responseTimeReq : ResponseTimeReqDef;
    }
}
