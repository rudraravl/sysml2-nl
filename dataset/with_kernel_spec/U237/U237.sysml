package HHHFT_Device {
    private import ScalarValues::*;

    package Definitions {
        attribute def OxygenConcentrationValue :> ScalarValues::Real;
        attribute def FlowRateValue :> ScalarValues::Real;
        attribute def TemperatureValue :> ScalarValues::Real;
        attribute def RelativeHumidityValue :> ScalarValues::Real;

        item def GasMixture {
            attribute oxygenConcentration : OxygenConcentrationValue;
            attribute flowRate : FlowRateValue;
            attribute temperature : TemperatureValue;
            attribute relativeHumidity : RelativeHumidityValue;
        }
        attribute def TherapySettings {
            attribute prescribedOxygenConcentration : OxygenConcentrationValue;
            attribute prescribedFlowRate : FlowRateValue;
            attribute prescribedTemperature : TemperatureValue;
            attribute prescribedRelativeHumidity : RelativeHumidityValue;
        }
        item def SensorReadings {
            attribute measuredFlowRate : FlowRateValue;
            attribute measuredTemperature : TemperatureValue;
            attribute measuredRelativeHumidity : RelativeHumidityValue;
        }
        item def SetOxygenConcentrationCommand {
            attribute targetOxygenConcentration : OxygenConcentrationValue;
        }
        item def SetFlowRateCommand {
            attribute targetFlowRate : FlowRateValue;
        }
        item def SetHeaterTemperatureCommand {
            attribute targetTemperature : TemperatureValue;
        }

        attribute def PrimeSignal;
        attribute def TherapyOnSignal;
        attribute def PauseSignal;
        attribute def ResumeSignal;
        attribute def ShutdownSignal;

        port def GasInPort {
            in gas : GasMixture;
        }
        port def GasOutPort {
            out gas : GasMixture;
        }
        port def SensorInPort {
            in readings : SensorReadings;
        }
        port def SensorOutPort {
            out readings : SensorReadings;
        }
        port def OxygenCommandInPort {
            in command : SetOxygenConcentrationCommand;
        }
        port def OxygenCommandOutPort {
            out command : SetOxygenConcentrationCommand;
        }
        port def FlowCommandInPort {
            in command : SetFlowRateCommand;
        }
        port def FlowCommandOutPort {
            out command : SetFlowRateCommand;
        }
        port def HeaterCommandInPort {
            in command : SetHeaterTemperatureCommand;
        }
        port def HeaterCommandOutPort {
            out command : SetHeaterTemperatureCommand;
        }
        port def TherapySettingsInPort {
            in settings : TherapySettings;
        }

        action def MixGases;
        action def GenerateFlow;
        action def HumidifyGas;
        action def HeatGas;
        action def PreheatGas;
        action def RegulateTherapy;
        action def ShutdownSystem;

        state def TherapyStates;

        part def AirSource {
            port gasOut : GasOutPort;
        }
        part def OxygenSource {
            port gasOut : GasOutPort;
        }
        part def GasBlender {
            port airIn : GasInPort;
            port oxygenIn : GasInPort;
            port gasOut : GasOutPort;
            port controlPort : OxygenCommandInPort;
            perform action mixGases : MixGases;
        }
        part def FlowGenerator {
            port gasIn : GasInPort;
            port gasOut : GasOutPort;
            port controlPort : FlowCommandInPort;
            perform action generateFlow : GenerateFlow;
        }
        part def Humidifier {
            port gasIn : GasInPort;
            port gasOut : GasOutPort;
            perform action humidifyGas : HumidifyGas;
        }
        part def Heater {
            port gasIn : GasInPort;
            port gasOut : GasOutPort;
            port controlPort : HeaterCommandInPort;
            attribute currentTemperature : TemperatureValue;
            perform action heatGas : HeatGas;
        }
        part def HeatedTubing {
            port gasIn : GasInPort;
            port gasOut : GasOutPort;
            port sensorPort : SensorOutPort;
        }
        part def NasalCannula {
            port gasIn : GasInPort;
            port gasOut : GasOutPort;
        }
        part def Patient {
            port gasIn : GasInPort;
        }
        part def ControlSystem {
            port sensorPort : SensorInPort;
            port oxygenCommandPort : OxygenCommandOutPort;
            port flowCommandPort : FlowCommandOutPort;
            port heaterCommandPort : HeaterCommandOutPort;
            port settingsPort : TherapySettingsInPort;
            attribute prescribedSettings : TherapySettings;
            perform action regulateTherapy : RegulateTherapy;
        }

        requirement def TemperatureStabilityReq {
            doc /* The delivered gas temperature shall be maintained at 37 degrees C plus or minus 1 degree C during active therapy. */
        }
        requirement def FlowRateRangeReq {
            doc /* The device shall deliver flow rates adjustable between 2 and 60 L/min. */
        }
        requirement def HumidityLevelReq {
            doc /* The delivered gas shall have relative humidity of at least 95 percent at the patient interface. */
        }
        requirement def OxygenConcentrationAccuracyReq {
            doc /* The oxygen concentration shall be accurate within plus or minus 2 percent of the prescribed value. */
        }
        requirement def PatientSafetyReq {
            doc /* The device shall avoid harm to the patient under all operating modes. */
        }
    }

    package Usages {
        public import Definitions::*;

        requirement tempStability : TemperatureStabilityReq;
        requirement flowRange : FlowRateRangeReq;
        requirement humidityLevel : HumidityLevelReq;
        requirement o2Accuracy : OxygenConcentrationAccuracyReq;
        requirement patientSafety : PatientSafetyReq;

        part hhhftDevice {
            part airSource : AirSource;
            part oxygenSource : OxygenSource;
            part gasBlender : GasBlender;
            part flowGenerator : FlowGenerator;
            part humidifier : Humidifier;
            part heater : Heater;
            part heatedTubing : HeatedTubing;
            part nasalCannula : NasalCannula;
            part patient : Patient;
            part controlSystem : ControlSystem;

            action preheatGas : PreheatGas;
            action regulateTherapy : RegulateTherapy;
            action shutdownSystem : ShutdownSystem;

            flow airFlow of GasMixture
                from airSource.gasOut.gas to gasBlender.airIn.gas;
            flow oxygenFlow of GasMixture
                from oxygenSource.gasOut.gas to gasBlender.oxygenIn.gas;
            flow blendedFlow of GasMixture
                from gasBlender.gasOut.gas to flowGenerator.gasIn.gas;
            flow generatedFlow of GasMixture
                from flowGenerator.gasOut.gas to humidifier.gasIn.gas;
            flow humidifiedFlow of GasMixture
                from humidifier.gasOut.gas to heater.gasIn.gas;
            flow heatedFlow of GasMixture
                from heater.gasOut.gas to heatedTubing.gasIn.gas;
            flow deliveredFlow of GasMixture
                from heatedTubing.gasOut.gas to nasalCannula.gasIn.gas;
            flow patientFlow of GasMixture
                from nasalCannula.gasOut.gas to patient.gasIn.gas;

            flow sensorReadingsFlow of SensorReadings
                from heatedTubing.sensorPort.readings to controlSystem.sensorPort.readings;
            flow oxygenCommandFlow of SetOxygenConcentrationCommand
                from controlSystem.oxygenCommandPort.command to gasBlender.controlPort.command;
            flow flowCommandFlow of SetFlowRateCommand
                from controlSystem.flowCommandPort.command to flowGenerator.controlPort.command;
            flow heaterCommandFlow of SetHeaterTemperatureCommand
                from controlSystem.heaterCommandPort.command to heater.controlPort.command;

            exhibit state therapyStates : TherapyStates {
                entry; then idle;
                state idle;
                accept PrimeSignal
                    then priming;
                state priming {
                    entry preheatGas;
                }
                accept TherapyOnSignal
                    then active;
                state active {
                    do regulateTherapy;
                }
                accept PauseSignal
                    then paused;
                accept ShutdownSignal
                    then shutdown;
                state paused;
                accept ResumeSignal
                    then active;
                accept ShutdownSignal
                    then shutdown;
                state shutdown {
                    entry shutdownSystem;
                }
            }

            satisfy tempStability by heater;
            satisfy flowRange by flowGenerator;
            satisfy humidityLevel by humidifier;
            satisfy o2Accuracy by gasBlender;
            satisfy patientSafety by controlSystem;
        }
    }

    public import Usages::hhhftDevice;
    public import Definitions::TherapyStates;
}
