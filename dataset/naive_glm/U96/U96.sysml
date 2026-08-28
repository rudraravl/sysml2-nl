package OrganCareSystem {
    import ScalarValues::*;
    import ISQ::*;

    package ValueTypes {
        value type TemperatureValue :> Real { unit "degC"; }
        value type PressureValue :> Real {> ISQ::PressureValue { unit "kPa"; }
        value type FlowRateValue :> Real { unit "mL/min"; }
        value type OxygenLevelValue :> Real { unit "percent"; }
        value type LactateLevelValue :> Real { unit "mmol/L"; }
        value type PumpSpeedValue :> Real { unit "RPM"; }
        value type PowerValue :> Real { unit "W"; }
        value type VolumeValue :> Real { unit "mL"; }
        value type DurationValue :> Real { unit "min"; }
    }

    package Items {
        item def PreservationSolution;
        item def OxygenGas;
        item def DonorOrgan;

        item def SensorData {
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
            attribute oxygenLevel : OxygenLevelValue;
            attribute lactateLevel : LactateLevelValue;
            attribute timestamp : String;
        }

        item def ControlCommand {
            attribute pumpSpeed : PumpSpeedValue;
            attribute targetTemperature : TemperatureValue;
            attribute oxygenationTarget : OxygenLevelValue;
        }

        item def AlarmSignal {
            attribute severity : Integer;
            attribute description : String;
            attribute parameter : String;
        }

        item def UIStatus {
            attribute organCondition : String;
            attribute systemState : String;
            attribute elapsedPerfusionTime : DurationValue;
        }
    }

    package Ports {
        port def FluidInPort {
            in item PreservationSolution;
        }
        port def FluidOutPort {
            out item PreservationSolution;
        }
        port def GasInPort {
            in item OxygenGas;
        }
        port def SensorOutPort {
            out item SensorData;
        }
        port def SensorInPort {
            in item SensorData;
        }
        port def CommandInPort {
            in item ControlCommand;
        }
        port def CommandOutPort {
            out item ControlCommand;
        }
        port def AlarmOutPort {
            out item AlarmSignal;
        }
        port def UIOutPort {
            out item UIStatus;
        }
    }

    package Components {

        part def FluidReservoir {
            port fluidOut : FluidOutPort;
            attribute capacity : VolumeValue = 2000;
            attribute currentVolume : VolumeValue;
            attribute solutionType : PreservationSolution;

            action def DispenseSolution {
                out solution : PreservationSolution;
            }
        }

        part def CirculationPump {
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
            port commandIn : CommandInPort;
            attribute speed : PumpSpeedValue;
            attribute maxSpeed : PumpSpeedValue = 5000;
            attribute minSpeed : PumpSpeedValue = 0;
            attribute powerDraw : PowerValue;

            action def PumpOperation {
                in solution : PreservationSolution;
                in speed : PumpSpeedValue;
                out pressurizedSolution : PreservationSolution;
            }

            perform action pumpOperation : PumpOperation {
                in solution = fluidIn.PreservationSolution;
                in speed = speed;
                out pressurizedSolution = fluidOut.PreservationSolution;
            }
        }

        part def OxygenationModule {
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
            port gasIn : GasInPort;
            port commandIn : CommandInPort;
            attribute oxygenationRate : OxygenLevelValue;
            attribute targetOxygen : OxygenLevelValue = 95;
            attribute membraneArea : Real;

            action def Oxygenate {
                in solution : PreservationSolution;
                in gas : OxygenGas;
                in target : OxygenLevelValue;
                out oxygenatedSolution : PreservationSolution;
            }

            perform action oxygenate : Oxygenate {
                in solution = fluidIn.PreservationSolution;
                in gas = gasIn.OxygenGas;
                in target = targetOxygen;
                out oxygenatedSolution = fluidOut.PreservationSolution;
            }
        }

        part def ThermalRegulator {
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
            port commandIn : CommandInPort;
            attribute currentTemperature : TemperatureValue;
            attribute targetTemperature : TemperatureValue = 4;
            attribute coolingPower : PowerValue;
            attribute maxCoolingPower : PowerValue = 150;

            action def RegulateTemperature {
                in solution : PreservationSolution;
                in target : TemperatureValue;
                out chilledSolution : PreservationSolution;
            }

            perform action regulateTemperature : RegulateTemperature {
                in solution = fluidIn.PreservationSolution;
                in target = targetTemperature;
                out chilledSolution = fluidOut.PreservationSolution;
            }
        }

        part def PerfusionChamber {
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
            port organPort;
            attribute housedOrgan : DonorOrgan;
            attribute chamberPressure : PressureValue;
            attribute chamberTemperature : TemperatureValue;
            attribute isSealed : Boolean;

            action def PerfuseOrgan {
                in solution : PreservationSolution;
                in organ : DonorOrgan;
                out effluent : PreservationSolution;
            }

            perform action perfuseOrgan : PerfuseOrgan {
                in solution = fluidIn.PreservationSolution;
                in organ = housedOrgan;
                out effluent = fluidOut.PreservationSolution;
            }
        }

        part def BioSensorArray {
            port fluidIn : FluidInPort;
            port fluidOut : FluidOutPort;
            port dataOut : SensorOutPort;
            attribute temperature : TemperatureValue;
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
            attribute oxygenLevel : OxygenLevelValue;
            attribute lactateLevel : LactateLevelValue;
            attribute samplingInterval : DurationValue = 1;

            action def SampleSolution {
                in solution : PreservationSolution;
                out data : SensorData;
            }

            perform action sampleSolution : SampleSolution {
                in solution = fluidIn.PreservationSolution;
                out data = dataOut.SensorData;
            }
        }

        part def ControlProcessor {
            port sensorIn : SensorInPort;
            port pumpCommandOut : CommandOutPort;
            port thermalCommandOut : CommandOutPort;
            port oxygenatorCommandOut : CommandOutPort;
            port alarmOut : AlarmOutPort;
            port uiOut : UIOutPort;

            attribute safeTempMin : TemperatureValue = 2;
            attribute safeTempMax : TemperatureValue = 8;
            attribute safePressureMin : PressureValue = 5;
            attribute safePressureMax : PressureValue = 15;
            attribute safeFlowMin : FlowRateValue = 50;
            attribute safeFlowMax : FlowRateValue = 300;
            attribute safeOxygenMin : OxygenLevelValue = 85;
            attribute safeOxygenMax : OxygenLevelValue = 100;
            attribute safeLactateMax : LactateLevelValue = 5;

            attribute currentData : SensorData;
            attribute lastCommand : ControlCommand;

            state machine def ControlStateMachine {
                entry; then Off;

                state Off;
                transition off_to_priming
                    first Off
                    then Priming
                    accept PowerOn;

                state Priming {
                    entry { send pumpCommandOut.ControlCommand; }
                    do { circulate solution without organ; }
                }
                transition priming_to_active
                    first Priming
                    then ActivePerfusion
                    accept PrimingComplete;

                state ActivePerfusion {
                    do { maintain perfusion parameters; }
                }
                transition active_to_monitoring
                    first ActivePerfusion
                    then Monitoring
                    accept StableParameters;

                state Monitoring {
                    do { observe parameters during transport; }
                }
                transition monitoring_to_active
                    first Monitoring
                    then ActivePerfusion
                    accept AdjustmentNeeded;

                state Alarm {
                    entry { send alarmOut.AlarmSignal; }
                    do { attempt automatic correction; }
                }
                transition any_to_alarm
                    first (Off | Priming | ActivePerfusion | Monitoring)
                    then Alarm
                    accept ParameterOutOfRange;

                transition alarm_to_active
                    first Alarm
                    then ActivePerfusion
                    accept IssueResolved;

                transition alarm_to_off
                    first Alarm
                    then Off
                    accept CriticalFailure;
            }

            exhibit state : ControlStateMachine;

            action def AnalyzeSensorData {
                in data : SensorData;
                out command : ControlCommand;
                out alarm : AlarmSignal;
            }

            perform action analyze : AnalyzeSensorData {
                in data = sensorIn.SensorData;
                out command = lastCommand;
                out alarm = alarmOut.AlarmSignal;
            }
        }

        part def UserInterface {
            port statusIn;
            port alarmIn;
            port displayOut : UIOutPort;
            attribute displayState : String;
            attribute backlightOn : Boolean;

            action def RenderStatus {
                in status : UIStatus;
                in alarm : AlarmSignal;
            }
        }

        part def OxygenSupply {
            port gasOut : GasInPort;
            attribute remainingVolume : VolumeValue;
            attribute pressure : PressureValue;
        }

        part def PowerSupply {
            attribute batteryCapacity : PowerValue = 200;
            attribute remainingCharge : Real;
            attribute isOnBattery : Boolean;
        }
    }

    package System {
        part def OrganCareSystem {
            part reservoir : Components::FluidReservoir;
            part pump : Components::CirculationPump;
            part oxygenator : Components::OxygenationModule;
            part thermalRegulator : Components::ThermalRegulator;
            part chamber : Components::PerfusionChamber;
            part sensorArray : Components::BioSensorArray;
            part processor : Components::ControlProcessor;
            part ui : Components::UserInterface;
            part oxygenSupply : Components::OxygenSupply;
            part power : Components::PowerSupply;

            connection reservoir_to_pump connect reservoir.fluidOut to pump.fluidIn;
            connection pump_to_oxygenator connect pump.fluidOut to oxygenator.fluidIn;
            connection oxygenator_to_thermal connect oxygenator.fluidOut to thermalRegulator.fluidIn;
            connection thermal_to_chamber connect thermalRegulator.fluidOut to chamber.fluidIn;
            connection chamber_to_sensor connect chamber.fluidOut to sensorArray.fluidIn;
            connection sensor_to_reservoir connect sensorArray.fluidOut to reservoir.fluidOut;
            connection oxygen_to_oxygenator connect oxygenSupply.gasOut to oxygenator.gasIn;
            connection sensor_to_processor connect sensorArray.dataOut to processor.sensorIn;
            connection processor_to_pump connect processor.pumpCommandOut to pump.commandIn;
            connection processor_to_thermal connect processor.thermalCommandOut to thermalRegulator.commandIn;
            connection processor_to_oxygenator connect processor.oxygenatorCommandOut to oxygenator.commandIn;
            connection processor_alarm_to_ui connect processor.alarmOut to ui.alarmIn;
            connection processor_status_to_ui connect processor.uiOut to ui.statusIn;
        }
    }

    package Requirements {
        requirement def PreservationRequirement {
            doc "The system shall extend donor organ preservation time beyond static cold storage limits.";
            attribute minPreservationTime : DurationValue = 480;
            subject organ : DonorOrgan;
            objective { organ.viabilityDuration >= minPreservationTime }
        }

        requirement def PerfusionRequirement {
            doc "The system shall continuously perfuse the organ with nutrient-rich preservation solution.";
            attribute minFlowRate : FlowRateValue = 50;
            attribute maxFlowRate : FlowRateValue = 300;
            subject solution : PreservationSolution;
            objective { solution.flowRate >= minFlowRate and solution.flowRate <= maxFlowRate }
        }

        requirement def OxygenationRequirement {
            doc "The system shall dissolve oxygen into the preservation solution to mimic natural lung function.";
            attribute targetOxygen : OxygenLevelValue = 95;
            subject oxygenator : Components::OxygenationModule;
            objective { oxygenator.oxygenationRate >= targetOxygen }
        }

        requirement def ThermalRequirement {
            doc "The system shall chill the solution to a hypothermic temperature to slow organ metabolism.";
            attribute targetTemp : TemperatureValue = 4;
            attribute tolerance : TemperatureValue = 2;
            subject regulator : Components::ThermalRegulator;
            objective { abs(regulator.currentTemperature - targetTemp) <= tolerance }
        }

        requirement def MonitoringRequirement {
            doc "The system shall continuously monitor temperature, pressure, flow, oxygen, and lactate.";
            subject sensors : Components::BioSensorArray;
            objective { sensors.temperature.isMonitored and sensors.pressure.isMonitored and sensors.flowRate.isMonitored and sensors.oxygenLevel.isMonitored and sensors.lactateLevel.isMonitored }
        }

        requirement def ControlRequirement {
            doc "The processor shall automatically adjust pump speed and thermal output to maintain safe parameters.";
            subject processor : Components::ControlProcessor;
            objective { processor.lastCommand.pumpSpeed > 0 and processor.lastCommand.targetTemperature <= 8 }
        }

        requirement def AlarmRequirement {
            doc "The system shall enter an alarm state when any parameter exits its target range.";
            subject processor : Components::ControlProcessor;
            objective { processor.state.active = "Alarm" when ParameterOutOfRange }
        }

        requirement def UIRequirement {
            doc "The user interface shall provide real-time status of organ condition and system performance.";
            subject ui : Components::UserInterface;
            objective { ui.displayState != "Off" during ActivePerfusion }
        }

        requirement def PortabilityRequirement {
            doc "The system shall be portable for transport between donor and recipient sites.";
            attribute maxMass : Real = 25;
            subject system : System::OrganCareSystem;
            objective { system.mass <= maxMass }
        }

        requirement orgPreservation : PreservationRequirement;
        requirement continuousPerfusion : PerfusionRequirement;
        requirement oxygenation : OxygenationRequirement;
        requirement thermalControl : ThermalRequirement;
        requirement monitoring : MonitoringRequirement;
        requirement automaticControl : ControlRequirement;
        requirement alarmBehavior : AlarmRequirement;
        requirement userInterface : UIRequirement;
        requirement portability : PortabilityRequirement;
    }
}
