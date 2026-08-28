package CalorimeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        part def MaterialSample {
            attribute mass :> ISQ::mass;
            attribute specificHeatCapacity : Real;
        }

        part def SampleChamber {
            attribute currentTemp :> ISQ::temperature;
            attribute targetTemp :> ISQ::temperature;
            port tempPort : TempPort;
            port heatPort : HeatPort;
        }

        part def TemperatureSensor {
            attribute responseTime :> ISQ::time;
            attribute accuracy :> ISQ::temperature;
            port sensorOut : TempPort;
            perform action senseTemperature {
                out temp :> ISQ::temperature;
            }
        }

        part def HeatingElement {
            attribute maxPower :> ISQ::power;
            port heaterIn : PowerCmdPort;
            port heaterOut : HeatPort;
            perform action applyHeat {
                in powerCmd :> ISQ::power;
                out heatSupplied :> ISQ::energy;
            }
        }

        part def ThermalInsulation {
            attribute thermalResistance : Real;
            port innerHeatPort : HeatPort;
            port outerHeatPort : HeatPort;
        }

        part def ControlUnit {
            port sensorIn : TempPort;
            port heaterCmdOut : PowerCmdPort;
            port opCmdIn : OpCmdPort;
            port daqCmdOut : DaqCmdPort;
            attribute selectedMode : OperatingMode;
            exhibit state controlStates : ControlStates;
            perform action controlHeater {
                in currentTemp :> ISQ::temperature;
                in targetTemp :> ISQ::temperature;
                out powerCmd :> ISQ::power;
            }
        }

        part def DataAcquisitionSystem {
            port tempIn : TempPort;
            port heatIn : HeatPort;
            port cmdIn : DaqCmdPort;
            attribute samplingRate :> ISQ::frequency;
            perform action logData {
                in timestamp : String;
                in tempReading :> ISQ::temperature;
                in heatSupplied :> ISQ::power;
            }
            perform action calculateHeatCapacity {
                in sampleMass :> ISQ::mass;
                in tempDelta :> ISQ::temperature;
                in totalHeat :> ISQ::energy;
                out specificHeatCapacity : Real;
            }
        }

        part def Operator {
            port cmdOut : OpCmdPort;
        }

        part def Environment {
            port ambientHeatPort : HeatPort;
        }

        port def TempPort {
            out temp :> ISQ::temperature;
        }
        port def HeatPort {
            in heat :> ISQ::energy;
        }
        port def PowerCmdPort {
            in power :> ISQ::power;
        }
        port def OpCmdPort {
            in cmd : OperatorCommand;
        }
        port def DaqCmdPort {
            in cmd : String;
        }

        item def OperatorCommand {
            attribute mode : OperatingMode;
        }
        enum def OperatingMode {
            Isothermal;
            Adiabatic;
        }
        item def StartSignal;
        item def StopSignal;
        item def SelectIsothermalSignal;
        item def SelectAdiabaticSignal;

        interface def TempInterface {
            end tempPort1 : TempPort;
            end tempPort2 : TempPort;
        }
        interface def HeatInterface {
            end heatPort1 : HeatPort;
            end heatPort2 : HeatPort;
        }
        interface def PowerCmdInterface {
            end powerPort1 : PowerCmdPort;
            end powerPort2 : PowerCmdPort;
        }
        interface def OpCmdInterface {
            end opPort1 : OpCmdPort;
            end opPort2 : OpCmdPort;
        }
        interface def DaqCmdInterface {
            end daqPort1 : DaqCmdPort;
            end daqPort2 : DaqCmdPort;
        }

        state def ControlStates {
            entry;
            then idle;
            state idle;
            transition idle_to_running
                first idle
                accept StartSignal
                then running;
            state running {
                entry;
                then choose_mode;
                state choose_mode;
                transition to_isothermal
                    first choose_mode
                    accept SelectIsothermalSignal
                    then isothermal;
                transition to_adiabatic
                    first choose_mode
                    accept SelectAdiabaticSignal
                    then adiabatic;
                state isothermal;
                state adiabatic;
                transition isothermal_to_adiabatic
                    first isothermal
                    accept SelectAdiabaticSignal
                    then adiabatic;
                transition adiabatic_to_isothermal
                    first adiabatic
                    accept SelectIsothermalSignal
                    then isothermal;
            }
            transition running_to_idle
                first running
                accept StopSignal
                then idle;
        }

        requirement def TemperatureAccuracyRequirement {
            doc /* The temperature sensor shall have an accuracy of at least 0.01 K. */
            attribute accuracyReq :> ISQ::temperature = 0.01 [K];
            attribute sensorAccuracy :> ISQ::temperature;
            require constraint {
                sensorAccuracy <= accuracyReq
            }
        }
        requirement def ThermalInsulationRequirement {
            doc /* The thermal insulation shall have a thermal resistance of at least 5 K/W. */
            attribute minResistance : Real = 5;
            attribute insulationResistance : Real;
            require constraint {
                insulationResistance >= minResistance
            }
        }
        requirement def SamplingRateRequirement {
            doc /* The data acquisition system shall sample at a rate of at least 1000 Hz. */
            attribute minSamplingRate :> ISQ::frequency = 1000 [Hz];
            attribute actualSamplingRate :> ISQ::frequency;
            require constraint {
                actualSamplingRate >= minSamplingRate
            }
        }
        requirement def HeatCapacityCalculationRequirement {
            doc /* The system shall calculate specific heat capacity using Q = m*c*ΔT. */
            subject daq : DataAcquisitionSystem;
            attribute specificHeatCapacity : Real;
            attribute totalHeat :> ISQ::energy;
            attribute sampleMass :> ISQ::mass;
            attribute tempDelta :> ISQ::temperature;
            require constraint {
                specificHeatCapacity == totalHeat / (sampleMass * tempDelta)
            }
        }
    }

    public import Definitions::*;

    package Usages {
        private import Definitions::*;

        part calorimeter {
            part chamber : SampleChamber;
            part sample : MaterialSample {
                :>> mass = 0.5 [kg];
            }
            part sensor : TemperatureSensor {
                port :>> sensorOut;
                :>> responseTime = 0.1 [s];
                :>> accuracy = 0.005 [K];
                perform senseTemperature;
            }
            part heater : HeatingElement {
                port :>> heaterIn;
                port :>> heaterOut;
                :>> maxPower = 100 [W];
                perform applyHeat;
            }
            part insulation : ThermalInsulation {
                :>> thermalResistance = 8;
            }
            part controller : ControlUnit {
                port :>> sensorIn;
                port :>> heaterCmdOut;
                port :>> opCmdIn;
                port :>> daqCmdOut;
                :>> selectedMode = OperatingMode::Isothermal;
                exhibit controlStates;
                perform controlHeater;
            }
            part daq : DataAcquisitionSystem {
                port :>> tempIn;
                port :>> heatIn;
                port :>> cmdIn;
                :>> samplingRate = 2000 [Hz];
                perform logData;
                perform calculateHeatCapacity;
            }
            part operator : Operator {
                port :>> cmdOut;
            }
            part environment : Environment {
                port :>> ambientHeatPort;
            }

            interface sensorToChamber : TempInterface
                connect sensor.sensorOut to chamber.tempPort;
            interface sensorToController : TempInterface
                connect sensor.sensorOut to controller.sensorIn;
            interface sensorToDaq : TempInterface
                connect sensor.sensorOut to daq.tempIn;
            interface controllerToHeater : PowerCmdInterface
                connect controller.heaterCmdOut to heater.heaterIn;
            interface heaterToChamber : HeatInterface
                connect heater.heaterOut to chamber.heatPort;
            interface heaterToDaq : HeatInterface
                connect heater.heaterOut to daq.heatIn;
            interface operatorToController : OpCmdInterface
                connect operator.cmdOut to controller.opCmdIn;
            interface controllerToDaq : DaqCmdInterface
                connect controller.daqCmdOut to daq.cmdIn;
            interface chamberToInsulation : HeatInterface
                connect chamber.heatPort to insulation.innerHeatPort;
            interface insulationToEnvironment : HeatInterface
                connect insulation.outerHeatPort to environment.ambientHeatPort;
        }

        requirement tempAcc : TemperatureAccuracyRequirement {
            subject sensor : TemperatureSensor;
            :>> sensorAccuracy = 0.005 [K];
        }
        requirement insulationEff : ThermalInsulationRequirement {
            subject insulation : ThermalInsulation;
            :>> insulationResistance = 8;
        }
        requirement samplingRt : SamplingRateRequirement {
            subject daq : DataAcquisitionSystem;
            :>> actualSamplingRate = 2000 [Hz];
        }
        requirement heatCapacityCalc : HeatCapacityCalculationRequirement {
            subject daq : DataAcquisitionSystem;
        }
    }
}
