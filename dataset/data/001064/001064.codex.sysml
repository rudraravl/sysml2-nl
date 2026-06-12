package GardonGaugeSystemModel {

    package Units {
        unit W;
        unit m;
        unit m2;
        unit K;
        unit degC;
        unit V;
        unit mV;
        unit A;
        unit s;
        unit Pa;
        unit ohm;
        unit W_per_m2;
        unit mV_per_kW_per_m2;
    }

    value def HeatFlux {
        unit = Units::W_per_m2;
    }

    value def Temperature {
        unit = Units::degC;
    }

    value def Voltage {
        unit = Units::mV;
    }

    value def Pressure {
        unit = Units::Pa;
    }

    value def ElectricalResistance {
        unit = Units::ohm;
    }

    value def TimeDuration {
        unit = Units::s;
    }

    item def IncidentRadiantEnergy {
        attribute heatFlux : HeatFlux;
        attribute spectrumBand : String;
        attribute sourceTemperature : Temperature;
    }

    item def CoolingWater {
        attribute inletTemperature : Temperature;
        attribute outletTemperature : Temperature;
        attribute pressure : Pressure;
        attribute flowRate : Real;
    }

    item def ThermoelectricSignal {
        attribute openCircuitVoltage : Voltage;
        attribute polarity : String;
        attribute compensatedVoltage : Voltage;
    }

    item def CalibratedHeatFluxSignal {
        attribute measuredHeatFlux : HeatFlux;
        attribute sensorTemperature : Temperature;
        attribute validity : Boolean;
    }

    port def RadiationReceivingPort {
        in item incidentRadiation : IncidentRadiantEnergy;
    }

    port def CoolingFluidPort {
        inout item water : CoolingWater;
    }

    port def ElectricalSignalPort {
        out item signal : ThermoelectricSignal;
    }

    port def MeasurementOutputPort {
        out item measurement : CalibratedHeatFluxSignal;
    }

    part def CircularAbsorberDisc {
        attribute diameter : Real unit Units::m = 0.010;
        attribute thickness : Real unit Units::m = 0.000025;
        attribute absorptivity : Real = 0.96;
        attribute surfaceTemperature : Temperature;
        attribute centerTemperature : Temperature;
        attribute edgeTemperature : Temperature;

        port radiationPort : RadiationReceivingPort;

        action absorbRadiation {
            in item incoming : IncidentRadiantEnergy;
            out heatFluxAtSurface : HeatFlux;
        }

        action conductRadially {
            in centerTemp : Temperature;
            in edgeTemp : Temperature;
            out radialHeatFlow : Real unit Units::W;
        }
    }

    part def WaterCooledHeatSink {
        attribute bodyMaterial : String = "Copper";
        attribute coolantChannelDiameter : Real unit Units::m = 0.003;
        attribute allowablePressure : Pressure = 600000;
        attribute referenceTemperature : Temperature;
        attribute coolantFlowAvailable : Boolean;

        port coolantInlet : CoolingFluidPort;
        port coolantOutlet : CoolingFluidPort;

        action removeHeat {
            in absorbedHeat : Real unit Units::W;
            in item coolantIn : CoolingWater;
            out item coolantOut : CoolingWater;
        }
    }

    part def ThermocoupleJunctionNetwork {
        attribute junctionMaterialPositive : String = "Copper";
        attribute junctionMaterialNegative : String = "Constantan";
        attribute numberOfJunctions : Integer = 1;
        attribute seebeckCoefficient : Real unit Units::mV_per_kW_per_m2 = 0.12;
        attribute electricalResistance : ElectricalResistance;
        attribute coldJunctionTemperature : Temperature;
        attribute hotJunctionTemperature : Temperature;

        port electricalPort : ElectricalSignalPort;

        action generateThermoelectricVoltage {
            in hotTemperature : Temperature;
            in coldTemperature : Temperature;
            out item rawSignal : ThermoelectricSignal;
        }
    }

    part def SignalConditioner {
        attribute inputImpedance : ElectricalResistance = 1000000;
        attribute lowPassCutoffFrequency : Real;
        attribute offsetVoltage : Voltage = 0;
        attribute gain : Real = 1.0;

        port signalInput : ElectricalSignalPort;
        port conditionedOutput : MeasurementOutputPort;

        action filterAndScale {
            in item rawSignal : ThermoelectricSignal;
            out item heatFluxSignal : CalibratedHeatFluxSignal;
        }
    }

    part def CalibrationDataStore {
        attribute calibrationFactor : Real unit Units::mV_per_kW_per_m2 = 0.12;
        attribute calibrationTemperature : Temperature = 25;
        attribute expandedUncertaintyPercent : Real = 3.0;
        attribute lastCalibrationDate : String = "2026-01-15";

        action convertVoltageToHeatFlux {
            in sensorVoltage : Voltage;
            in sensorBodyTemperature : Temperature;
            out calibratedFlux : HeatFlux;
        }
    }

    part def GardonGauge {
        attribute primaryFunction : String =
            "Convert incident radiant heat flux on a thin circular absorber into a proportional thermoelectric voltage and calibrated heat-flux measurement.";
        attribute measurementRangeMinimum : HeatFlux = 0;
        attribute measurementRangeMaximum : HeatFlux = 5000000;
        attribute responseTime : TimeDuration = 0.25;
        attribute activeAreaDiameter : Real unit Units::m = 0.010;
        attribute operational : Boolean;

        port incidentRadiationPort : RadiationReceivingPort;
        port coolantSupplyPort : CoolingFluidPort;
        port coolantReturnPort : CoolingFluidPort;
        port measurementPort : MeasurementOutputPort;

        part absorber : CircularAbsorberDisc;
        part heatSink : WaterCooledHeatSink;
        part thermocouple : ThermocoupleJunctionNetwork;
        part conditioner : SignalConditioner;
        part calibrationStore : CalibrationDataStore;

        connect incidentRadiationPort to absorber.radiationPort;
        connect coolantSupplyPort to heatSink.coolantInlet;
        connect heatSink.coolantOutlet to coolantReturnPort;
        connect thermocouple.electricalPort to conditioner.signalInput;
        connect conditioner.conditionedOutput to measurementPort;

        action measureIncidentHeatFlux {
            in item incidentRadiation : IncidentRadiantEnergy;
            in item inletWater : CoolingWater;
            out item measuredOutput : CalibratedHeatFluxSignal;

            first absorber.absorbRadiation;
            then absorber.conductRadially;
            then heatSink.removeHeat;
            then thermocouple.generateThermoelectricVoltage;
            then calibrationStore.convertVoltageToHeatFlux;
            then conditioner.filterAndScale;
        }

        state def OperatingStateMachine {
            state Off;
            state CoolingRequired;
            state Ready;
            state Measuring;
            state Fault;

            transition Off_to_CoolingRequired
                first Off
                then CoolingRequired
                if operational == true;

            transition CoolingRequired_to_Ready
                first CoolingRequired
                then Ready
                if heatSink.coolantFlowAvailable == true;

            transition Ready_to_Measuring
                first Ready
                then Measuring
                if absorber.surfaceTemperature < 400;

            transition Measuring_to_Fault
                first Measuring
                then Fault
                if heatSink.coolantFlowAvailable == false or absorber.surfaceTemperature > 500;

            transition Fault_to_CoolingRequired
                first Fault
                then CoolingRequired
                if absorber.surfaceTemperature < 100 and heatSink.coolantFlowAvailable == true;

            transition Measuring_to_Ready
                first Measuring
                then Ready
                if operational == true;
        }
    }

    part def GaugeReadoutController {
        attribute samplingPeriod : TimeDuration = 0.05;
        attribute displayedHeatFlux : HeatFlux;
        attribute alarmLimit : HeatFlux = 4500000;
        attribute alarmActive : Boolean;

        port inputMeasurement : MeasurementOutputPort;

        action acquireMeasurement {
            in item measurement : CalibratedHeatFluxSignal;
            out displayedValue : HeatFlux;
        }

        action evaluateAlarm {
            in measuredFlux : HeatFlux;
            out alarm : Boolean;
        }
    }

    part def GardonGaugeMeasurementSystem {
        attribute systemPurpose : String =
            "Provide a high-level heat-flux measurement system using a Gardon gauge sensor head, cooling support, calibration conversion, and measurement readout.";
        attribute installedLocation : String = "Radiant heat exposure test stand";

        port radiationInterface : RadiationReceivingPort;
        port coolantSupplyInterface : CoolingFluidPort;
        port coolantReturnInterface : CoolingFluidPort;
        port heatFluxOutputInterface : MeasurementOutputPort;

        part sensorHead : GardonGauge;
        part readout : GaugeReadoutController;

        connect radiationInterface to sensorHead.incidentRadiationPort;
        connect coolantSupplyInterface to sensorHead.coolantSupplyPort;
        connect sensorHead.coolantReturnPort to coolantReturnInterface;
        connect sensorHead.measurementPort to readout.inputMeasurement;
        connect sensorHead.measurementPort to heatFluxOutputInterface;
    }

    requirement def PrimaryFunctionRequirement {
        subject gauge : GardonGauge;
        require constraint {
            gauge.primaryFunction ==
            "Convert incident radiant heat flux on a thin circular absorber into a proportional thermoelectric voltage and calibrated heat-flux measurement."
        }
    }

    requirement def HeatFluxRangeRequirement {
        subject gauge : GardonGauge;
        require constraint {
            gauge.measurementRangeMinimum <= 0 and gauge.measurementRangeMaximum >= 5000000
        }
    }

    requirement def CoolingRequirement {
        subject gauge : GardonGauge;
        require constraint {
            gauge.heatSink.coolantFlowAvailable == true implies gauge.operational == true
        }
    }

    requirement def ResponseTimeRequirement {
        subject gauge : GardonGauge;
        require constraint {
            gauge.responseTime <= 0.5
        }
    }

    requirement def OverTemperatureProtectionRequirement {
        subject gauge : GardonGauge;
        require constraint {
            gauge.absorber.surfaceTemperature > 500 implies gauge.operational == false
        }
    }

    requirement def SignalValidityRequirement {
        subject system : GardonGaugeMeasurementSystem;
        require constraint {
            system.sensorHead.measurementRangeMaximum > system.sensorHead.measurementRangeMinimum
        }
    }

    satisfy PrimaryFunctionRequirement by GardonGaugeMeasurementSystem::sensorHead;
    satisfy HeatFluxRangeRequirement by GardonGaugeMeasurementSystem::sensorHead;
    satisfy CoolingRequirement by GardonGaugeMeasurementSystem::sensorHead;
    satisfy ResponseTimeRequirement by GardonGaugeMeasurementSystem::sensorHead;
    satisfy OverTemperatureProtectionRequirement by GardonGaugeMeasurementSystem::sensorHead;
    satisfy SignalValidityRequirement by GardonGaugeMeasurementSystem;

}