package 'Gardon Gauge Heat Flux Measurement System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def HeatFluxDensityValue :> ISQ::HeatFluxDensityValue {
        attribute :>> num : Real;
        attribute :>> mks : SI::WattPerSquareMeterUnit;
    }

    attribute def TemperatureValue :> ISQ::TemperatureValue {
        attribute :>> num : Real;
        attribute :>> mks : SI::KelvinUnit;
    }

    attribute def VoltageValue :> ISQ::VoltageValue {
        attribute :>> num : Real;
        attribute :>> mks : SI::VoltUnit;
    }

    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue {
        attribute :>> num : Real;
        attribute :>> mks : SI::CubicMeterPerSecondUnit;
    }

    attribute def ThermalResistanceValue {
        attribute num : Real;
        attribute unit : String = "K/W";
    }

    item def HeatFluxMeasurement {
        attribute heatFlux : HeatFluxDensityValue;
        attribute timestamp : ISQ::TimeValue;
        attribute isValid : Boolean;
    }

    item def CoolantFlow {
        attribute flowRate : FlowRateValue;
        attribute inletTemperature : TemperatureValue;
        attribute outletTemperature : TemperatureValue;
    }

    item def ThermoelectricSignal {
        attribute voltage : VoltageValue;
        attribute temperatureGradient : TemperatureValue;
    }

    item def StartMeasurementCommand;
    item def ResetCommand;

    port def RadiationInputPort {
        in item incidentHeatFlux : HeatFluxDensityValue;
    }

    port def CoolantInputPort {
        in item coolantIn : CoolantFlow;
    }

    port def CoolantOutputPort {
        out item coolantOut : CoolantFlow;
    }

    port def SignalOutputPort {
        out item signal : ThermoelectricSignal;
    }

    port def DataOutputPort {
        out item measurement : HeatFluxMeasurement;
    }

    part def AbsorberFoil {
        doc /* Thin circular constantan foil that absorbs incident radiation. */
        attribute diameter : ISQ::LengthValue;
        attribute thickness : ISQ::LengthValue;
        attribute absorptivity : Real;
        port radiationInput : RadiationInputPort;
        attribute absorbedHeatFlux : HeatFluxDensityValue;
    }

    part def ThermalResistanceElement {
        doc /* Provides thermal resistance between hot junction and heat sink. */
        attribute thermalResistance : ThermalResistanceValue;
        attribute area : ISQ::AreaValue;
    }

    part def ThermocoupleJunction {
        doc /* Generates voltage proportional to temperature difference. */
        attribute seebeckCoefficient : Real;
        attribute hotJunctionTemp : TemperatureValue;
        attribute coldJunctionTemp : TemperatureValue;
        port signalOut : SignalOutputPort;
    }

    part def WaterCooledHeatSink {
        doc /* Maintains constant temperature reference through water cooling. */
        attribute baseTemperature : TemperatureValue;
        attribute thermalCapacity : Real;
        port coolantIn : CoolantInputPort;
        port coolantOut : CoolantOutputPort;
    }

    part def SignalAmplifier {
        doc /* Amplifies low-level thermocouple voltage for measurement. */
        attribute gain : Real;
        attribute inputImpedance : Real;
        attribute outputVoltage : VoltageValue;
    }

    part def CalibrationModule {
        doc /* Converts voltage to heat flux using calibration curve. */
        attribute calibrationFactor : Real;
        attribute polynomialCoefficients : Real[*];
        attribute rawVoltage : VoltageValue;
        attribute calibratedHeatFlux : HeatFluxDensityValue;
    }

    part def DataAcquisitionUnit {
        doc /* Digitizes and records heat flux measurements. */
        attribute samplingRate : Real;
        attribute resolution : Real;
        port dataOut : DataOutputPort;
    }

    action def AbsorbIncidentRadiation {
        in incidentFlux : HeatFluxDensityValue;
        in absorptivity : Real;
        out absorbedFlux : HeatFluxDensityValue;
    }

    action def EstablishTemperatureGradient {
        in absorbedHeat : HeatFluxDensityValue;
        in thermalResistance : ThermalResistanceValue;
        out temperatureDifference : TemperatureValue;
    }

    action def GenerateThermoelectricVoltage {
        in tempDifference : TemperatureValue;
        in seebeckCoeff : Real;
        out voltage : VoltageValue;
    }

    action def AmplifySignal {
        in inputVoltage : VoltageValue;
        in gain : Real;
        out amplifiedVoltage : VoltageValue;
    }

    action def CalibrateHeatFlux {
        in voltage : VoltageValue;
        in calibrationFactor : Real;
        out heatFlux : HeatFluxDensityValue;
    }

    action def RecordMeasurement {
        in heatFlux : HeatFluxDensityValue;
        in timestamp : ISQ::TimeValue;
        out measurement : HeatFluxMeasurement;
    }

    action def MeasureHeatFluxSequence {
        doc /* Complete measurement cycle from radiation absorption to data output. */
        first start;
        then action absorb : AbsorbIncidentRadiation {
            in incidentFlux;
            in absorptivity;
            out absorbedFlux;
        }
        then action establishGradient : EstablishTemperatureGradient {
            in absorbedHeat = absorb.absorbedFlux;
            in thermalResistance;
            out temperatureDifference;
        }
        then action generateVoltage : GenerateThermoelectricVoltage {
            in tempDifference = establishGradient.temperatureDifference;
            in seebeckCoeff;
            out voltage;
        }
        then action amplify : AmplifySignal {
            in inputVoltage = generateVoltage.voltage;
            in gain;
            out amplifiedVoltage;
        }
        then action calibrate : CalibrateHeatFlux {
            in voltage = amplify.amplifiedVoltage;
            in calibrationFactor;
            out heatFlux;
        }
        then action record : RecordMeasurement {
            in heatFlux = calibrate.heatFlux;
            in timestamp;
            out measurement;
        }
        then done;
    }

    state def GaugeOperationalStates {
        in attribute coolantFlowing : Boolean;
        in attribute sensorReady : Boolean;
        in attribute dataAvailable : Boolean;
        
        entry; then initialization;
        
        state initialization {
            doc /* System startup and stabilization. */
        }
        
        transition init_to_standby
            first initialization
            accept when coolantFlowing
            then standby;
        
        state standby {
            doc /* Ready to measure, heat sink at stable temperature. */
        }
        
        transition standby_to_measuring
            first standby
            accept StartMeasurementCommand
            then measuring;
        
        state measuring {
            doc /* Active measurement in progress. */
            do action performMeasurement : MeasureHeatFluxSequence;
        }
        
        transition measuring_to_recording
            first measuring
            then recording;
        
        state recording {
            doc /* Data being recorded and output. */
        }
        
        transition recording_to_standby
            first recording
            then standby;
        
        transition measuring_to_fault
            first measuring
            accept when not coolantFlowing
            then fault;
        
        state fault {
            doc /* Error condition detected. */
        }
        
        transition fault_to_initialization
            first fault
            accept ResetCommand
            then initialization;
    }

    part def GardonGaugeSensor {
        doc /* Complete Gardon gauge sensor assembly with all components. */
        
        attribute sensorReady : Boolean;
        attribute coolantFlowing : Boolean;
        attribute dataAvailable : Boolean;
        
        port radiationInput : RadiationInputPort;
        port coolantSupply : CoolantInputPort;
        port coolantReturn : CoolantOutputPort;
        port measurementOutput : DataOutputPort;
        
        part absorber : AbsorberFoil {
            attribute :>> diameter { attribute :>> num = 0.0127; }
            attribute :>> thickness { attribute :>> num = 0.000025; }
            attribute :>> absorptivity = 0.94;
        }
        
        part thermalResistor : ThermalResistanceElement {
            attribute :>> thermalResistance { attribute num = 150.0; }
        }
        
        part thermocouple : ThermocoupleJunction {
            attribute :>> seebeckCoefficient = 0.000041;
        }
        
        part heatSink : WaterCooledHeatSink {
            attribute :>> baseTemperature { attribute :>> num = 298.15; }
        }
        
        part amplifier : SignalAmplifier {
            attribute :>> gain = 1000.0;
        }
        
        part calibrator : CalibrationModule {
            attribute :>> calibrationFactor = 25000.0;
        }
        
        part daq : DataAcquisitionUnit {
            attribute :>> samplingRate = 1000.0;
            attribute :>> resolution = 16.0;
        }
        
        connect radiationInput to absorber.radiationInput;
        connect coolantSupply to heatSink.coolantIn;
        connect heatSink.coolantOut to coolantReturn;
        connect thermocouple.signalOut to amplifier;
        connect measurementOutput to daq.dataOut;
        
        exhibit state operatingStates : GaugeOperationalStates {
            in coolantFlowing = self.coolantFlowing;
            in sensorReady = self.sensorReady;
            in dataAvailable = self.dataAvailable;
        }
        
        perform action measurementCycle : MeasureHeatFluxSequence;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The Gardon gauge system shall measure incident radiative heat flux density 
               by converting thermal energy into an electrical signal through thermoelectric 
               effect, utilizing a water-cooled heat sink to maintain a stable temperature 
               reference and providing calibrated digital output for high-intensity thermal 
               radiation environments. */
        
        subject gardonSystem : GardonGaugeSensor;
    }

    requirement def MeasurementRangeRequirement {
        doc /* The system shall measure heat flux from 0 to 1000 kW/m². */
        
        subject gardonSystem : GardonGaugeSensor;
        
        require constraint rangeConstraint {
            doc /* Minimum: 0 kW/m², Maximum: 1000 kW/m². */
        }
    }

    requirement def AccuracyRequirement {
        doc /* The system shall achieve measurement accuracy within ±3% of reading. */
        
        subject gardonSystem : GardonGaugeSensor;
        
        require constraint accuracyConstraint {
            doc /* Total uncertainty shall not exceed 3% over calibrated range. */
        }
    }

    requirement def ResponseTimeRequirement {
        doc /* The system shall achieve 95% of final reading within 0.5 seconds. */
        
        subject gardonSystem : GardonGaugeSensor;
        
        require constraint responseConstraint {
            doc /* Time constant shall be less than 0.15 seconds. */
        }
    }

    requirement def CoolingRequirement {
        doc /* Water cooling shall maintain heat sink temperature within ±1K. */
        
        subject heatSink : WaterCooledHeatSink;
        
        require constraint temperatureStabilityConstraint {
            doc /* Coolant flow rate shall be maintained between 0.5 and 2.0 L/min. */
        }
    }

    requirement <'GARDON-SYS-001'> gardonGaugeSystemRequirement {
        doc /* Top-level requirement for Gardon gauge heat flux measurement system. */
        
        subject system : GardonGaugeSensor;
        
        require primaryFunctionReq : PrimaryFunctionRequirement;
        require measurementRangeReq : MeasurementRangeRequirement;
        require accuracyReq : AccuracyRequirement;
        require responseTimeReq : ResponseTimeRequirement;
        require coolingReq : CoolingRequirement;
    }

    part gardonGaugeSystem : GardonGaugeSensor {
        satisfy gardonGaugeSystemRequirement;
    }
}
