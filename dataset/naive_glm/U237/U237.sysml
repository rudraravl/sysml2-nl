package HHHFT_System {
    import ISQ::*;
    import ScalarValues::*;

    value type TemperatureValue > Real { unit 'degC'; }
    value type FlowRateValue > Real { unit 'L/min'; }
    value type HumidityValue > Real { unit '%'; }
    value type OxygenConcentrationValue > Real { unit '%'; }
    value type PressureValue > Real { unit 'kPa'; }

    item def Gas;
    item def MedicalAir :> Gas;
    item def PureOxygen :> Gas;
    item def BlendedGas :> Gas {
        ref oxygenConcentration : OxygenConcentrationValue;
    }
    item def HumidifiedGas :> BlendedGas {
        ref humidity : HumidityValue;
    }
    item def HeatedGas :> HumidifiedGas {
        ref temperature : TemperatureValue;
    }

    port def AirFlowPort {
        out item air : MedicalAir;
    }
    port def OxygenFlowPort {
        out item oxygen : PureOxygen;
    }
    port def BlendedGasFlowPort {
        out item blendedGas : BlendedGas;
    }
    port def HumidifiedGasFlowPort {
        out item humidifiedGas : HumidifiedGas;
    }
    port def HeatedGasFlowPort {
        out item heatedGas : HeatedGas;
    }
    port def GasFlowPort {
        out item gas : Gas;
    }

    port def SensorSignalPort {
        out flowRate : FlowRateValue;
        out temperature : TemperatureValue;
        out humidity : HumidityValue;
    }

    port def ControlCommandPort {
        out targetO2 : OxygenConcentrationValue;
        out targetFlow : FlowRateValue;
        out targetTemp : TemperatureValue;
    }

    requirement def StableTemperatureRequirement {
        doc /* The system must maintain gas temperature at 37 +/- 1 degC. */
        subject deliveredGas : HeatedGas;
        constraint { deliveredGas.temperature == 37.0 [+/- 1.0] }
    }

    requirement def FlowRateRangeRequirement {
        doc /* The system must deliver flow rates between 2 and 60 L/min. */
        subject deliveredFlow : FlowRateValue;
        constraint { deliveredFlow >= 2.0 and deliveredFlow <= 60.0 }
    }

    requirement def HighHumidityRequirement {
        doc /* The system must deliver gas with >= 95% relative humidity. */
        subject deliveredHumidity : HumidityValue;
        constraint { deliveredHumidity >= 95.0 }
    }

    requirement def AccurateO2Requirement {
        doc /* The system must maintain O2 concentration within +/- 2% of set value. */
        subject deliveredO2 : OxygenConcentrationValue;
        attribute setO2 : OxygenConcentrationValue;
        constraint { abs(deliveredO2 - setO2) <= 2.0 }
    }

    part def MedicalAirSource {
        port airOut : AirFlowPort;
    }

    part def OxygenSource {
        port oxygenOut : OxygenFlowPort;
    }

    part def GasBlender {
        port airIn : ~AirFlowPort;
        port oxygenIn : ~OxygenFlowPort;
        port blendedOut : BlendedGasFlowPort;
        port controlIn : ~ControlCommandPort;
        
        attribute currentO2 : OxygenConcentrationValue;
        
        action mixGases {
            in air : MedicalAir;
            in oxygen : PureOxygen;
            out blended : BlendedGas;
        }
    }

    part def FlowGenerator {
        port gasIn : ~BlendedGasFlowPort;
        port gasOut : BlendedGasFlowPort;
        port controlIn : ~ControlCommandPort;
        
        attribute currentFlow : FlowRateValue;
        
        action generateFlow {
            in gas : BlendedGas;
            out flowingGas : BlendedGas;
        }
    }

    part def Humidifier {
        port gasIn : ~BlendedGasFlowPort;
        port gasOut : HumidifiedGasFlowPort;
        
        attribute waterLevel : Real;
        
        action humidifyGas {
            in gas : BlendedGas;
            out humidGas : HumidifiedGas;
        }
    }

    part def Heater {
        port gasIn : ~HumidifiedGasFlowPort;
        port gasOut : HeatedGasFlowPort;
        port controlIn : ~ControlCommandPort;
        
        attribute currentTemp : TemperatureValue;
        
        action heatGas {
            in gas : HumidifiedGas;
            out heatedGas : HeatedGas;
        }
    }

    part def HeatedTubing {
        port gasIn : ~HeatedGasFlowPort;
        port gasOut : HeatedGasFlowPort;
        
        attribute tubeTemp : TemperatureValue;
    }

    part def NasalCannula {
        port gasIn : ~HeatedGasFlowPort;
        port gasOut : GasFlowPort;
    }

    part def DeliverySensors {
        port gasIn : ~HeatedGasFlowPort;
        port gasOut : HeatedGasFlowPort;
        port signalOut : SensorSignalPort;
        
        attribute measuredFlow : FlowRateValue;
        attribute measuredTemp : TemperatureValue;
        attribute measuredHumidity : HumidityValue;
        
        action measureGas {
            in gas : HeatedGas;
            out flow : FlowRateValue;
            out temp : TemperatureValue;
            out humidity : HumidityValue;
        }
    }

    part def ControlSystem {
        port sensorIn : ~SensorSignalPort;
        port blenderControl : ControlCommandPort;
        port flowGenControl : ControlCommandPort;
        port heaterControl : ControlCommandPort;
        
        attribute prescribedO2 : OxygenConcentrationValue;
        attribute prescribedFlow : FlowRateValue;
        attribute prescribedTemp : TemperatureValue;
        
        state def ControlStates {
            entry; 
            state idle;
            state priming;
            state active;
            state paused;
            state shutdown;
            
            transition init_to_idle initial -> idle;
            transition idle_to_priming idle -> priming when true;
            transition priming_to_active priming -> active when true;
            transition active_to_paused active -> paused when true;
            transition paused_to_active paused -> active when true;
            transition active_to_shutdown active -> shutdown when true;
            transition paused_to_shutdown paused -> shutdown when true;
        }
        
        exhibit state behavior : ControlStates;
        
        action regulateTherapy {
            in sensorData : ~SensorSignalPort;
            out blenderCmd : ControlCommandPort;
            out flowGenCmd : ControlCommandPort;
            out heaterCmd : ControlCommandPort;
        }
    }

    part def HHHFT_Device {
        part airSource : MedicalAirSource;
        part oxygenSource : OxygenSource;
        part blender : GasBlender;
        part flowGen : FlowGenerator;
        part humidifier : Humidifier;
        part heater : Heater;
        part tubing : HeatedTubing;
        part cannula : NasalCannula;
        part sensors : DeliverySensors;
        part controller : ControlSystem;
        
        satisfy StableTemperatureRequirement by controller;
        satisfy FlowRateRangeRequirement by flowGen;
        satisfy HighHumidityRequirement by humidifier;
        satisfy AccurateO2Requirement by blender;
        
        connection airToBlender connect airSource.airOut to blender.airIn;
        connection oxygenToBlender connect oxygenSource.oxygenOut to blender.oxygenIn;
        connection blenderToFlowGen connect blender.blendedOut to flowGen.gasIn;
        connection flowGenToHumidifier connect flowGen.gasOut to humidifier.gasIn;
        connection humidifierToHeater connect humidifier.gasOut to heater.gasIn;
        connection heaterToTubing connect heater.gasOut to tubing.gasIn;
        connection tubingToSensors connect tubing.gasOut to sensors.gasIn;
        connection sensorsToCannula connect sensors.gasOut to cannula.gasIn;
        
        connection sensorToController connect sensors.signalOut to controller.sensorIn;
        connection controllerToBlender connect controller.blenderControl to blender.controlIn;
        connection controllerToFlowGen connect controller.flowGenControl to flowGen.controlIn;
        connection controllerToHeater connect controller.heaterControl to heater.controlIn;
    }
}
