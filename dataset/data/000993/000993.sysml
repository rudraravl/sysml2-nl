package BolometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def ResistanceValue :> ISQ::ElectricalResistanceValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialDifferenceValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def ThermalConductanceValue :> Real;
    attribute def HeatCapacityValue :> Real;
    
    item def ElectromagneticRadiation {
        attribute wavelength : ISQ::LengthValue;
        attribute incidentPower : PowerValue;
    }
    
    item def ElectricalSignal {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    item def MeasurementData {
        attribute detectedPower : PowerValue;
        attribute timestamp : ISQ::TimeValue;
        attribute signalToNoise : Real;
    }
    
    attribute def StartMeasurementCmd;
    attribute def StopMeasurementCmd;
    attribute def CooldownCmd;
    attribute def CalibrateCmd;
    attribute def CalibrationCompleteCmd;
    
    port def RadiationPort {
        in item radiation : ElectromagneticRadiation;
    }
    
    port def ThermalPort {
        out attribute heatFlow : PowerValue;
        out attribute temperature : TemperatureValue;
    }
    
    port def ElectricalPort {
        in attribute biasVoltage : VoltageValue;
        out attribute outputSignal : ElectricalSignal;
    }
    
    port def DataPort {
        out item measurement : MeasurementData;
    }
    
    part def AbsorberElement {
        doc /* Absorbs incident electromagnetic radiation and converts it to thermal energy. */
        
        attribute absorptivity : Real = 0.98;
        attribute thermalMass : HeatCapacityValue = 1.5e-10;
        attribute surfaceArea : ISQ::AreaValue;
        
        port radiationIn : RadiationPort;
        port thermalOut : ThermalPort;
    }
    
    part def ThermistorSensor {
        doc /* Temperature-sensitive resistor that changes resistance with absorbed heat. */
        
        attribute baseResistance : ResistanceValue = 100000.0 [SI::Ω];
        attribute temperatureCoefficient : Real = -0.04;
        attribute operatingTemperature : TemperatureValue = 4.2 [SI::K];
        attribute currentResistance : ResistanceValue;
        
        port thermalIn : ThermalPort;
        port electricalOut : ElectricalPort;
    }
    
    part def ThermalIsolation {
        doc /* Weak thermal link to heat sink providing controlled thermal conductance. */
        
        attribute thermalConductance : ThermalConductanceValue = 1.0e-8;
        attribute linkLength : ISQ::LengthValue;
        
        port sensorSide : ThermalPort;
        port heatSinkSide : ThermalPort;
    }
    
    part def CryogenicHeatSink {
        doc /* Maintains stable low temperature reference for thermal isolation. */
        
        attribute sinkTemperature : TemperatureValue = 4.2 [SI::K];
        attribute heatCapacity : HeatCapacityValue;
        
        port thermalConnection : ThermalPort;
    }
    
    part def BiasCircuit {
        doc /* Provides stable bias voltage and current to thermistor. */
        
        attribute biasVoltage : VoltageValue = 0.001 [SI::V];
        attribute biasCurrent : CurrentValue;
        
        port electricalOutput : ElectricalPort;
    }
    
    part def ReadoutAmplifier {
        doc /* Amplifies small voltage changes from thermistor resistance variations. */
        
        attribute gain : Real = 10000.0;
        attribute inputImpedance : ResistanceValue;
        attribute noiseVoltage : VoltageValue = 1.0e-9 [SI::V];
        
        port electricalInput : ElectricalPort;
        port amplifiedOutput : ElectricalPort;
    }
    
    part def SignalProcessor {
        doc /* Converts amplified signal to calibrated power measurement. */
        
        attribute calibrationFactor : Real;
        attribute integrationTime : ISQ::TimeValue = 0.1 [SI::s];
        
        port signalInput : ElectricalPort;
        port dataOutput : DataPort;
    }
    
    action def AbsorbRadiation {
        in radiation : ElectromagneticRadiation;
        in absorptivity : Real;
        out thermalPower : PowerValue;
    }
    
    action def ConvertHeatToResistance {
        in thermalPower : PowerValue;
        in thermalConductance : ThermalConductanceValue;
        in baseResistance : ResistanceValue;
        in tempCoefficient : Real;
        out resistanceChange : ResistanceValue;
    }
    
    action def MeasureResistance {
        in resistance : ResistanceValue;
        in biasVoltage : VoltageValue;
        out outputVoltage : VoltageValue;
    }
    
    action def AmplifySignal {
        in inputVoltage : VoltageValue;
        in amplifierGain : Real;
        out amplifiedVoltage : VoltageValue;
    }
    
    action def CalculatePower {
        in voltage : VoltageValue;
        in calibration : Real;
        out measuredPower : PowerValue;
        out data : MeasurementData;
    }
    
    action def DetectElectromagneticPower {
        doc /* Primary function: detect and measure incident electromagnetic radiation power. */
        
        in incidentRadiation : ElectromagneticRadiation;
        out powerMeasurement : MeasurementData;
        
        first start;
        then action absorb : AbsorbRadiation {
            in radiation = incidentRadiation;
            out thermalPower;
        }
        then action convertToResistance : ConvertHeatToResistance {
            in thermalPower = absorb.thermalPower;
            out resistanceChange;
        }
        then action measure : MeasureResistance {
            in resistance = convertToResistance.resistanceChange;
            out outputVoltage;
        }
        then action amplify : AmplifySignal {
            in inputVoltage = measure.outputVoltage;
            out amplifiedVoltage;
        }
        then action calculate : CalculatePower {
            in voltage = amplify.amplifiedVoltage;
            out measuredPower;
            out data;
        }
        then assign powerMeasurement := calculate.data;
        then done;
    }
    
    state def BolometerOperationalStates {
        entry; then standby;
        
        state standby {
            doc /* System cooled and thermally stabilized, ready for measurement. */
            entry assign mode := "Standby";
        }
        
        state measuring {
            doc /* Actively detecting and measuring incident radiation. */
            entry assign mode := "Measuring";
            do action activeMeasurement : DetectElectromagneticPower;
        }
        
        state calibrating {
            doc /* Performing internal calibration with known reference sources. */
            entry assign mode := "Calibrating";
        }
        
        state saturated {
            doc /* Incident power exceeds measurement range. */
            entry assign mode := "Saturated";
        }
        
        transition standby_to_measuring
            first standby
            accept startCmd : StartMeasurementCmd
            then measuring;
        
        transition measuring_to_standby
            first measuring
            accept stopCmd : StopMeasurementCmd
            then standby;
        
        transition measuring_to_saturated
            first measuring
            if measuring.activeMeasurement.powerMeasurement.detectedPower > 1.0e-6 [SI::W]
            then saturated;
        
        transition saturated_to_standby
            first saturated
            accept coolCmd : CooldownCmd
            then standby;
        
        transition standby_to_calibrating
            first standby
            accept calCmd : CalibrateCmd
            then calibrating;
        
        transition calibrating_to_standby
            first calibrating
            accept calCompleteCmd : CalibrationCompleteCmd
            then standby;
        
        attribute mode : String;
    }
    
    part def Bolometer {
        doc /* Complete bolometer system for detecting and measuring electromagnetic radiation 
                by converting absorbed radiant energy into measurable electrical signals through 
                thermal and resistive transduction. */
        
        attribute operatingTemperature : TemperatureValue = 4.2 [SI::K];
        attribute noiseEquivalentPower : PowerValue = 1.0e-13 [SI::W];
        attribute responsivity : Real = 1.0e8;
        attribute timeConstant : ISQ::TimeValue = 0.05 [SI::s];
        
        port radiationInput : RadiationPort;
        port measurementOutput : DataPort;
        
        part absorber : AbsorberElement {
            attribute :>> absorptivity = 0.98;
            attribute :>> thermalMass = 1.5e-10;
            attribute :>> surfaceArea = 1.0e-6 [SI::'m²'];
        }
        
        part thermistor : ThermistorSensor {
            attribute :>> baseResistance = 100000.0 [SI::Ω];
            attribute :>> temperatureCoefficient = -0.04;
            attribute :>> operatingTemperature = 4.2 [SI::K];
        }
        
        part thermalLink : ThermalIsolation {
            attribute :>> thermalConductance = 1.0e-8;
            attribute :>> linkLength = 0.001 [SI::m];
        }
        
        part heatSink : CryogenicHeatSink {
            attribute :>> sinkTemperature = 4.2 [SI::K];
        }
        
        part biasSource : BiasCircuit {
            attribute :>> biasVoltage = 0.001 [SI::V];
        }
        
        part amplifier : ReadoutAmplifier {
            attribute :>> gain = 10000.0;
            attribute :>> noiseVoltage = 1.0e-9 [SI::V];
        }
        
        part processor : SignalProcessor {
            attribute :>> integrationTime = 0.1 [SI::s];
        }
        
        connection radiationPath connect radiationInput to absorber.radiationIn;
        connection thermalCoupling connect absorber.thermalOut to thermistor.thermalIn;
        connection thermalIsolationPath connect thermistor.thermalIn to thermalLink.sensorSide;
        connection heatSinkPath connect thermalLink.heatSinkSide to heatSink.thermalConnection;
        connection biasConnection connect biasSource.electricalOutput to thermistor.electricalOut;
        connection signalPath connect thermistor.electricalOut to amplifier.electricalInput;
        connection amplifiedPath connect amplifier.amplifiedOutput to processor.signalInput;
        connection dataPath connect processor.dataOutput to measurementOutput;
        
        perform action detection : DetectElectromagneticPower {
            in incidentRadiation;
            out powerMeasurement;
        }
        
        exhibit state behavior : BolometerOperationalStates;
    }
    
    requirement def SensitivityRequirement {
        doc /* The bolometer shall achieve minimum detectable power limited by thermal noise. */
        
        subject bolometerSystem : Bolometer;
        
        require constraint {
            bolometerSystem.noiseEquivalentPower <= 1.0e-12 [SI::W]
        }
    }
    
    requirement def TemperatureStabilityRequirement {
        doc /* The bolometer shall maintain stable cryogenic operating temperature. */
        
        subject bolometerSystem : Bolometer;
        
        require constraint {
            bolometerSystem.operatingTemperature >= 3.0 [SI::K] and
            bolometerSystem.operatingTemperature <= 5.0 [SI::K]
        }
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The bolometer shall respond to radiation changes within thermal time constant. */
        
        subject bolometerSystem : Bolometer;
        
        require constraint {
            bolometerSystem.timeConstant <= 0.1 [SI::s]
        }
    }
    
    requirement def DynamicRangeRequirement {
        doc /* The bolometer shall measure radiation over specified power range without saturation. */
        
        subject bolometerSystem : Bolometer;
        
        require constraint {
            doc /* Shall measure from NEP to 1 microwatt */
        }
    }
    
    requirement <'BOL-001'> primaryFunctionRequirement {
        doc /* The bolometer system shall detect and measure incident electromagnetic radiation 
                by absorbing radiant energy, converting it to heat, sensing the resulting temperature 
                change via resistance variation, and producing calibrated electrical output signals 
                proportional to the incident power. */
        
        subject bolometer : Bolometer;
        
        require sensitivityReq : SensitivityRequirement;
        require tempStabilityReq : TemperatureStabilityRequirement;
        require responseReq : ResponseTimeRequirement;
        require dynamicReq : DynamicRangeRequirement;
    }
}
