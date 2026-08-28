package 'Gardon Gauge System' {
    private import ScalarValues::*;
    
    attribute def HeatFluxValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def TimeValue :> Real;
    attribute def CoolantFlowRateValue :> Real;
    attribute def CalibrationFactorValue :> Real;
    
    item def HeatRadiation;
    item def CoolantWater;
    item def DigitalMeasurement {
        attribute heatFlux : HeatFluxValue;
        attribute timestamp : TimeValue;
    }
    
    port def HeatRadiationInPort {
        in item radiation : HeatRadiation;
    }
    port def CoolantInPort {
        in item coolant : CoolantWater;
    }
    port def ThermalOutPort {
        out attribute temperature : TemperatureValue;
    }
    port def ThermalInPort {
        in attribute temperature : TemperatureValue;
    }
    port def VoltageInPort {
        in attribute voltage : VoltageValue;
    }
    port def VoltageOutPort {
        out attribute voltage : VoltageValue;
    }
    port def FluxInPort {
        in attribute heatFlux : HeatFluxValue;
    }
    port def FluxOutPort {
        out attribute heatFlux : HeatFluxValue;
    }
    port def MeasurementOutPort {
        out item measurement : DigitalMeasurement;
    }
    
    attribute def InitCompleteSignal;
    attribute def StartMeasurementSignal;
    attribute def StopMeasurementSignal;
    attribute def CoolantLossSignal;
    attribute def ResetSignal;
    
    state def GardonGaugeStates {
        entry; then initialization;
        state initialization;
        transition init_to_standby
            first initialization
            accept InitCompleteSignal
            then standby;
        state standby;
        transition standby_to_measuring
            first standby
            accept StartMeasurementSignal
            then measuring;
        state measuring;
        transition measuring_to_standby
            first measuring
            accept StopMeasurementSignal
            then standby;
        transition measuring_to_fault
            first measuring
            accept CoolantLossSignal
            then fault;
        transition standby_to_fault
            first standby
            accept CoolantLossSignal
            then fault;
        state fault;
        transition fault_to_standby
            first fault
            accept ResetSignal
            then standby;
    }
    
    action def AbsorbRadiation {
        in radiation : HeatRadiation;
        out centerTemp : TemperatureValue;
    }
    action def MaintainCoolantFlow {
        in coolant : CoolantWater;
        out edgeTemp : TemperatureValue;
    }
    action def GenerateTemperatureGradient {
        in centerTemp : TemperatureValue;
        in edgeTemp : TemperatureValue;
        out tempGradient : TemperatureValue;
    }
    action def GenerateThermocoupleVoltage {
        in tempGradient : TemperatureValue;
        out voltage : VoltageValue;
    }
    action def AmplifyVoltage {
        in voltage : VoltageValue;
        out amplifiedVoltage : VoltageValue;
    }
    action def CalibrateFlux {
        in amplifiedVoltage : VoltageValue;
        in calibrationFactor : CalibrationFactorValue;
        out heatFlux : HeatFluxValue;
    }
    action def DigitizeAndTimestamp {
        in heatFlux : HeatFluxValue;
        out measurement : DigitalMeasurement;
    }
    
    action def MeasureHeatFluxProcess {
        in radiation : HeatRadiation;
        in coolant : CoolantWater;
        in calibrationFactor : CalibrationFactorValue;
        out measurement : DigitalMeasurement;
        
        action absorb : AbsorbRadiation;
        action maintain : MaintainCoolantFlow;
        action generateGradient : GenerateTemperatureGradient;
        action generateVoltage : GenerateThermocoupleVoltage;
        action amplify : AmplifyVoltage;
        action calibrate : CalibrateFlux;
        action digitize : DigitizeAndTimestamp;
        
        bind absorb.radiation = radiation;
        bind maintain.coolant = coolant;
        bind calibrate.calibrationFactor = calibrationFactor;
        bind measurement = digitize.measurement;
        
        flow absorb.centerTemp to generateGradient.centerTemp;
        flow maintain.edgeTemp to generateGradient.edgeTemp;
        flow generateGradient.tempGradient to generateVoltage.tempGradient;
        flow generateVoltage.voltage to amplify.voltage;
        flow amplify.amplifiedVoltage to calibrate.amplifiedVoltage;
        flow calibrate.heatFlux to digitize.heatFlux;
        
        first start;
        then absorb;
        then maintain;
        then generateGradient;
        then generateVoltage;
        then amplify;
        then calibrate;
        then digitize;
        then done;
    }
    
    part def AbsorberFoil {
        port radiationIn : HeatRadiationInPort;
        port centerThermal : ThermalOutPort;
    }
    part def WaterCooledHeatSink {
        port coolantIn : CoolantInPort;
        port edgeThermal : ThermalOutPort;
    }
    part def ThermalResistanceElement {
        port hotPoint : ThermalInPort;
        port coldPoint : ThermalInPort;
    }
    part def ThermocoupleJunction {
        port hotPoint : ThermalInPort;
        port coldPoint : ThermalInPort;
        port voltageOut : VoltageOutPort;
    }
    part def SignalAmplifier {
        port voltageIn : VoltageInPort;
        port voltageOut : VoltageOutPort;
    }
    part def CalibrationModule {
        port voltageIn : VoltageInPort;
        port fluxOut : FluxOutPort;
        attribute calibrationFactor : CalibrationFactorValue;
    }
    part def DataAcquisitionUnit {
        port fluxIn : FluxInPort;
        port measurementOut : MeasurementOutPort;
    }
    
    part def GardonGauge {
        port radiationIn : HeatRadiationInPort;
        port coolantIn : CoolantInPort;
        port measurementOut : MeasurementOutPort;
        
        part absorberFoil : AbsorberFoil;
        part heatSink : WaterCooledHeatSink;
        part thermalResistor : ThermalResistanceElement;
        part thermocouple : ThermocoupleJunction;
        part amplifier : SignalAmplifier;
        part calibrator : CalibrationModule;
        part daq : DataAcquisitionUnit;
        
        connect radiationIn to absorberFoil.radiationIn;
        connect coolantIn to heatSink.coolantIn;
        
        connect absorberFoil.centerThermal to thermocouple.hotPoint;
        connect heatSink.edgeThermal to thermocouple.coldPoint;
        connect absorberFoil.centerThermal to thermalResistor.hotPoint;
        connect heatSink.edgeThermal to thermalResistor.coldPoint;
        
        connect thermocouple.voltageOut to amplifier.voltageIn;
        connect amplifier.voltageOut to calibrator.voltageIn;
        connect calibrator.fluxOut to daq.fluxIn;
        connect daq.measurementOut to measurementOut;
        
        state gaugeState : GardonGaugeStates;
        action measureHeatFlux : MeasureHeatFluxProcess;
    }
    
    requirement def AccurateMeasurementRequirement {
        subject gauge : GardonGauge;
        doc /* The gauge shall measure high-intensity thermal radiation accurately. */
    }
    
    requirement def CoolantSafetyRequirement {
        subject sink : WaterCooledHeatSink;
        doc /* The water-cooled heat sink shall maintain cooling to prevent damage. */
    }
    
    requirement def SignalIntegrityRequirement {
        subject amplifier : SignalAmplifier;
        doc /* The signal amplifier shall boost the thermocouple voltage to a usable level without distortion. */
    }
}
