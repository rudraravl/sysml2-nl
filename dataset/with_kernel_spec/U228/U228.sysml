package MedicalFluidWarmingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute def PowerOn;
        attribute def PowerOff;
        attribute def StartWarming;
        attribute def AlarmClear;
        attribute def AlarmSignal;
        attribute def PowerCommand;
        attribute def DisplayUpdate;

        port def FluidPort;
        port def HeatPort;
        port def PowerPort;
        port def TempPort {
            attribute temp : TemperatureValue;
        }
        port def FlowPort {
            attribute flowRate : VolumeFlowRateValue;
        }
        port def PowerCommandPort {
            attribute cmd : PowerCommand;
        }
        port def AlarmPort {
            attribute alarm : AlarmSignal;
        }
        port def DisplayPort {
            attribute data : DisplayUpdate;
        }

        part def WarmingChamber {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            port heatIn : HeatPort;
        }

        part def HeatingElement {
            port powerIn : PowerCommandPort;
            port heatOut : HeatPort;
        }

        part def TemperatureSensor {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            out port tempOut : TempPort;
            perform action senseTemp : SenseTemperature;
        }

        part def FlowSensor {
            port fluidIn : FluidPort;
            port fluidOut : FluidPort;
            out port flowOut : FlowPort;
            perform action senseFlow : SenseFlow;
        }

        part def ControlUnit {
            in port powerIn : PowerPort;
            in port tempIn : TempPort;
            in port flowIn : FlowPort;
            out port powerOut : PowerCommandPort;
            out port alarmOut : AlarmPort;
            out port displayOut : DisplayPort;
            exhibit state operationalStates : OperationalStates;
        }

        part def AlarmSystem {
            in port alarmIn : AlarmPort;
        }

        part def PowerSupply {
            out port powerOut : PowerPort;
        }

        part def UserInterface {
            in port displayIn : DisplayPort;
        }

        action def SenseTemperature {
            out temp : TemperatureValue;
        }
        action def SenseFlow {
            out flowRate : VolumeFlowRateValue;
        }
        action def RegulateHeating {
            in currentTemp : TemperatureValue;
            in currentFlowRate : VolumeFlowRateValue;
        }
        action def UpdateDisplay {
            in currentTemp : TemperatureValue;
            in currentFlowRate : VolumeFlowRateValue;
            in mode : String;
        }

        state def OperationalStates;

        requirement def TargetTemperatureRequirement {
            doc /* The system shall heat fluid to a target temperature of 37 degrees C. */
            attribute targetTemp : TemperatureValue = 37.0 [degC];
        }
        requirement def TemperatureToleranceRequirement {
            doc /* The system shall maintain fluid temperature within plus or minus 0.5 degrees C of the target. */
            attribute tolerance : TemperatureValue = 0.5 [degC];
        }
        requirement def MaxSafeTemperatureRequirement {
            doc /* The fluid temperature shall not exceed 39 degrees C. */
            attribute maxTemp : TemperatureValue = 39.0 [degC];
        }
        requirement def MinSafeTemperatureRequirement {
            doc /* The fluid temperature shall not drop below 35 degrees C. */
            attribute minTemp : TemperatureValue = 35.0 [degC];
        }
        requirement def AlarmOnOverUnderTempRequirement {
            doc /* If temperature exceeds 39 degrees C or drops below 35 degrees C, the alarm shall activate. */
        }
        requirement def HeatingStopOnAlarmRequirement {
            doc /* When alarm activates, heating shall stop immediately. */
        }
    }

    package Usages {
        private import Definitions::*;

        action regulateHeating : RegulateHeating;
        action updateDisplay : UpdateDisplay;

        part fluidWarmerSystem {
            port fluidInlet : FluidPort;
            port fluidOutlet : FluidPort;

            part warmingChamber : WarmingChamber;
            part heatingElement : HeatingElement;
            part tempSensor : TemperatureSensor;
            part flowSensor : FlowSensor;

            part controlUnit : ControlUnit {
                exhibit state operationalStates : OperationalStates {
                    entry; then off;

                    state off;
                    accept PowerOn then standby;

                    state standby {
                        do updateDisplay {
                            in currentTemp = tempIn.temp;
                            in currentFlowRate = flowIn.flowRate;
                            in mode = "standby";
                        }
                    }
                    accept StartWarming then warming;
                    accept PowerOff then off;

                    state warming {
                        do regulateHeating {
                            in currentTemp = tempIn.temp;
                            in currentFlowRate = flowIn.flowRate;
                        }
                        do updateDisplay {
                            in currentTemp = tempIn.temp;
                            in currentFlowRate = flowIn.flowRate;
                            in mode = "warming";
                        }
                    }
                    accept when tempIn.temp >= 37.0 [degC] then maintaining;
                    accept when tempIn.temp > 39.0 [degC] or tempIn.temp < 35.0 [degC]
                        do send new AlarmSignal() via alarmOut
                        then alarm;
                    accept PowerOff then off;

                    state maintaining {
                        do regulateHeating {
                            in currentTemp = tempIn.temp;
                            in currentFlowRate = flowIn.flowRate;
                        }
                        do updateDisplay {
                            in currentTemp = tempIn.temp;
                            in currentFlowRate = flowIn.flowRate;
                            in mode = "maintaining";
                        }
                    }
                    accept when tempIn.temp < 36.5 [degC] then warming;
                    accept when tempIn.temp > 39.0 [degC] or tempIn.temp < 35.0 [degC]
                        do send new AlarmSignal() via alarmOut
                        then alarm;
                    accept PowerOff then off;

                    state alarm {
                        entry send new PowerCommand() via powerOut;
                        do updateDisplay {
                            in currentTemp = tempIn.temp;
                            in currentFlowRate = flowIn.flowRate;
                            in mode = "alarm";
                        }
                    }
                    accept AlarmClear then standby;
                    accept PowerOff then off;
                }
            }

            part alarmSystem : AlarmSystem;
            part powerSupply : PowerSupply;
            part userInterface : UserInterface;

            connect fluidInlet to warmingChamber.fluidIn;
            connect warmingChamber.fluidOut to flowSensor.fluidIn;
            connect flowSensor.fluidOut to tempSensor.fluidIn;
            connect tempSensor.fluidOut to fluidOutlet;

            connect heatingElement.heatOut to warmingChamber.heatIn;

            connect tempSensor.tempOut to controlUnit.tempIn;
            connect flowSensor.flowOut to controlUnit.flowIn;

            connect powerSupply.powerOut to controlUnit.powerIn;
            connect controlUnit.powerOut to heatingElement.powerIn;

            connect controlUnit.alarmOut to alarmSystem.alarmIn;
            connect controlUnit.displayOut to userInterface.displayIn;
        }

        satisfy TargetTemperatureRequirement by fluidWarmerSystem;
        satisfy TemperatureToleranceRequirement by fluidWarmerSystem;
        satisfy MaxSafeTemperatureRequirement by fluidWarmerSystem;
        satisfy MinSafeTemperatureRequirement by fluidWarmerSystem;
        satisfy AlarmOnOverUnderTempRequirement by fluidWarmerSystem;
        satisfy HeatingStopOnAlarmRequirement by fluidWarmerSystem;
    }
}
