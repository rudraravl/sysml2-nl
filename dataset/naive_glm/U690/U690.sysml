package GardonGaugeModel {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceAndTimeExtent::*;
    import ISQThermodynamics::*;
    import ISQElectromagnetism::*;

    // ---- Value Types with Units ----

    value type HeatFluxValue :> Real {
        :>> unit = "W/m2";
    }

    value type TemperatureValue :> Real {
        :>> unit = "K";
    }

    value type TemperatureGradientValue :> Real {
        :>> unit = "K";
    }

    value type VoltageValue :> Real {
        :>> unit = "V";
    }

    value type AmplifiedVoltageValue :> Real {
        :>> unit = "V";
    }

    value type CalibrationFactorValue :> Real {
        :>> unit = "W/(m2*V)";
    }

    value type MassFlowRateValue :> Real {
        :>> unit = "kg/s";
    }

    value type ThermalResistanceValue :> Real {
        :>> unit = "K/W";
    }

    value type TimeStampValue :> Real {
        :>> unit = "s";
    }

    // ---- Item Types ----

    item HeatRadiation;

    item CoolantFlow;

    item RawThermocoupleSignal;

    item AmplifiedSignal;

    item CalibratedHeatFluxSignal;

    item DigitizedMeasurement;

    // ---- Attribute Definitions ----

    attribute def MeasurementRecord {
        attribute heatFlux : HeatFluxValue;
        attribute timeStamp : TimeStampValue;
        attribute sensorId : String;
        attribute status : String;
    }

    // ---- Port Definitions ----

    port def RadiationInPort {
        in item incidentRadiation : HeatRadiation;
    }

    port def CoolantPort {
        in item coolantFlow : CoolantFlow;
        out attribute flowRate : MassFlowRateValue;
    }

    port def ThermocoupleOutPort {
        out attribute voltage : VoltageValue;
    }

    port def AmplifierInPort {
        in attribute inputVoltage : VoltageValue;
    }

    port def AmplifierOutPort {
        out attribute outputVoltage : AmplifiedVoltageValue;
    }

    port def CalibrationInPort {
        in attribute amplifiedVoltage : AmplifiedVoltageValue;
    }

    port def CalibrationOutPort {
        out attribute heatFlux : HeatFluxValue;
    }

    port def DAQInPort {
        in attribute calibratedSignal : HeatFluxValue;
    }

    port def DAQOutPort {
        out item measurement : DigitizedMeasurement;
    }

    port def CommandPort {
        in attribute triggerCommand : Boolean;
        in attribute resetCommand : Boolean;
    }

    port def StatusPort {
        out attribute systemStatus : String;
    }

    // ---- Part Definitions ----

    part def AbsorberFoil {
        attribute foilDiameter : Real = 0.01; // meters
        attribute foilThickness : Real = 0.000015; // meters
        attribute absorptivity : Real = 0.95;
        attribute centerTemperature : TemperatureValue;
        attribute perimeterTemperature : TemperatureValue;

        port radiationInput : RadiationInPort;
        port thermalOutput : ThermocoupleOutPort;

        action def AbsorbRadiation {
            in incidentRadiation : HeatRadiation;
            out centerTemp : TemperatureValue;
        }

        perform AbsorbRadiation {
            in incidentRadiation = radiationInput.incidentRadiation;
            out centerTemp = centerTemperature;
        }
    }

    part def WaterCooledHeatSink {
        attribute targetPerimeterTemperature : TemperatureValue = 293.15; // 20°C in K
        attribute actualPerimeterTemperature : TemperatureValue;
        attribute coolantFlowRate : MassFlowRateValue;
        attribute coolingStabilized : Boolean = false;

        port coolantInput : CoolantPort;

        action def StabilizeCooling {
            in flowRate : MassFlowRateValue;
            out stabilized : Boolean;
            out perimeterTemp : TemperatureValue;
        }

        perform StabilizeCooling {
            in flowRate = coolantInput.coolantFlow;
            out stabilized = coolingStabilized;
            out perimeterTemp = actualPerimeterTemperature;
        }
    }

    part def ThermalResistanceElement {
        attribute thermalResistance : ThermalResistanceValue = 0.5;
        attribute hotSideTemperature : TemperatureValue;
        attribute coldSideTemperature : TemperatureValue;
        attribute temperatureGradient : TemperatureGradientValue;

        action def ConductHeat {
            in hotTemp : TemperatureValue;
            in coldTemp : TemperatureValue;
            out gradient : TemperatureGradientValue;
        }

        perform ConductHeat {
            in hotTemp = hotSideTemperature;
            in coldTemp = coldSideTemperature;
            out gradient = temperatureGradient;
        }
    }

    part def ThermocoupleJunction {
        attribute sensitivity : Real = 0.000040; // V/K (approx for type K)
        attribute measuredGradient : TemperatureGradientValue;
        attribute outputVoltage : VoltageValue;

        port thermalInput : ThermocoupleOutPort;
        port signalOutput : ThermocoupleOutPort;

        action def GenerateVoltage {
            in gradient : TemperatureGradientValue;
            out voltage : VoltageValue;
        }

        perform GenerateVoltage {
            in gradient = measuredGradient;
            out voltage = outputVoltage;
        }
    }

    part def SignalAmplifier {
        attribute gain : Real = 1000;
        attribute inputVoltage : VoltageValue;
        attribute outputVoltage : AmplifiedVoltageValue;

        port amplifierInput : AmplifierInPort;
        port amplifierOutput : AmplifierOutPort;

        action def AmplifySignal {
            in inputV : VoltageValue;
            out outputV : AmplifiedVoltageValue;
        }

        perform AmplifySignal {
            in inputV = inputVoltage;
            out outputV = outputVoltage;
        }
    }

    part def CalibrationModule {
        attribute calibrationFactor : CalibrationFactorValue = 10000; // W/(m2*V)
        attribute inputVoltage : AmplifiedVoltageValue;
        attribute outputHeatFlux : HeatFluxValue;

        port calibrationInput : CalibrationInPort;
        port calibrationOutput : CalibrationOutPort;

        action def Calibrate {
            in amplifiedV : AmplifiedVoltageValue;
            in factor : CalibrationFactorValue;
            out heatFlux : HeatFluxValue;
        }

        perform Calibrate {
            in amplifiedV = inputVoltage;
            in factor = calibrationFactor;
            out heatFlux = outputHeatFlux;
        }
    }

    part def DataAcquisitionUnit {
        attribute samplingRate : Real = 100; // Hz
        attribute digitizedHeatFlux : HeatFluxValue;
        attribute currentTimeStamp : TimeStampValue;
        attribute sensorIdentifier : String = "GG-001";
        attribute operationalStatus : String = "OK";

        port daqInput : DAQInPort;
        port daqOutput : DAQOutPort;
        port statusOutput : StatusPort;

        action def DigitizeAndTimestamp {
            in calibratedSignal : HeatFluxValue;
            out measurement : DigitizedMeasurement;
        }

        perform DigitizeAndTimestamp {
            in calibratedSignal = digitizedHeatFlux;
            out measurement;
        }
    }

    // ---- Main System Definition ----

    part def GardonGauge {
        attribute gaugeId : String = "GardonGauge-001";
        attribute maxHeatFlux : HeatFluxValue = 200000; // W/m2
        attribute minCoolantFlow : MassFlowRateValue = 0.05; // kg/s

        port radiationPort : RadiationInPort;
        port coolantPort : CoolantPort;
        port commandPort : CommandPort;
        port dataOutputPort : DAQOutPort;
        port gaugeStatusPort : StatusPort;

        part absorberFoil : AbsorberFoil;
        part heatSink : WaterCooledHeatSink;
        part thermalResistor : ThermalResistanceElement;
        part thermocouple : ThermocoupleJunction;
        part amplifier : SignalAmplifier;
        part calibrationModule : CalibrationModule;
        part daqUnit : DataAcquisitionUnit;

        // Internal connections
        connection heatFlowConnection connect absorberFoil.radiationInput to thermalResistor;
        connection thermalGradientConnection connect thermalResistor to thermocouple.thermalInput;
        connection thermocoupleSignalConnection connect thermocouple.signalOutput to amplifier.amplifierInput;
        connection amplifiedSignalConnection connect amplifier.amplifierOutput to calibrationModule.calibrationInput;
        connection calibratedSignalConnection connect calibrationModule.calibrationOutput to daqUnit.daqInput;

        // External port proxies
        flow radiationFlow from radiationPort.incidentRadiation to absorberFoil.radiationInput.incidentRadiation;
        flow coolantFlow from coolantPort.coolantFlow to heatSink.coolantInput.coolantFlow;

        // State Machine
        state def GaugeStateMachine {
            attribute coolantFlowRate : MassFlowRateValue;
            attribute initializationTimer : TimeStampValue = 0;
            attribute initializationComplete : Boolean = false;

            state initialization {
                entry action {
                    initializationTimer := 0;
                    initializationComplete := false;
                }
                do action {
                    // Wait for water cooling to stabilize
                    initializationTimer := initializationTimer + 1;
                    if heatSink.coolingStabilized == true {
                        initializationComplete := true;
                    }
                }
                transition to standby
                    when initializationComplete == true;
            }

            state standby {
                entry action {
                    daqUnit.operationalStatus := "Standby";
                }
                do action {
                    // Ready for trigger command
                }
                transition to measuring
                    when commandPort.triggerCommand == true;
                transition to fault
                    when coolantPort.flowRate < minCoolantFlow;
            }

            state measuring {
                entry action {
                    daqUnit.operationalStatus := "Measuring";
                }
                do action {
                    // Perform energy conversion and signal processing
                    absorberFoil.centerTemperature := absorberFoil.centerTemperature;
                    thermalResistor.hotSideTemperature := absorberFoil.centerTemperature;
                    thermalResistor.coldSideTemperature := heatSink.actualPerimeterTemperature;
                    thermocouple.measuredGradient := thermalResistor.temperatureGradient;
                    thermocouple.outputVoltage := thermocouple.measuredGradient * thermocouple.sensitivity;
                    amplifier.inputVoltage := thermocouple.outputVoltage;
                    amplifier.outputVoltage := amplifier.inputVoltage * amplifier.gain;
                    calibrationModule.inputVoltage := amplifier.outputVoltage;
                    calibrationModule.outputHeatFlux := calibrationModule.inputVoltage * calibrationModule.calibrationFactor;
                    daqUnit.digitizedHeatFlux := calibrationModule.outputHeatFlux;
                    daqUnit.currentTimeStamp := daqUnit.currentTimeStamp + (1.0 / daqUnit.samplingRate);
                }
                transition to standby
                    when commandPort.triggerCommand == false;
                transition to fault
                    when coolantPort.flowRate < minCoolantFlow;
            }

            state fault {
                entry action {
                    daqUnit.operationalStatus := "Fault";
                }
                do action {
                    // Prevent damage - halt measurement
                }
                transition to initialization
                    when commandPort.resetCommand == true;
            }
        }

        state machine : GaugeStateMachine {
            attribute coolantFlowRate : MassFlowRateValue;
        }

        // Bind external status
        binding gaugeStatusPort.systemStatus = daqUnit.operationalStatus;
    }

    // ---- Requirements ----

    requirement def MeasurementAccuracyRequirement {
        attribute id : String = "REQ-001";
        attribute text : String = "The Gardon Gauge shall measure heat flux with an accuracy of +/- 3% of the full-scale reading.";
        attribute fullScaleRange : HeatFluxValue = 200000;
        attribute maxErrorPercent : Real = 3.0;
    }

    requirement def CoolantFlowRequirement {
        attribute id : String = "REQ-002";
        attribute text : String = "The system shall maintain a minimum coolant flow rate of 0.05 kg/s to prevent sensor damage.";
        attribute minFlowRate : MassFlowRateValue = 0.05;
    }

    requirement def FaultDetectionRequirement {
        attribute id : String = "REQ-003";
        attribute text : String = "The system shall enter a fault state within 1 second of detecting coolant flow below the minimum threshold.";
        attribute maxResponseTime : TimeStampValue = 1.0;
    }

    requirement def InitializationRequirement {
        attribute id : String = "REQ-004";
        attribute text :String = "The system shall complete initialization and enter standby mode only after the water cooling has stabilized.";
        attribute maxInitializationTime : TimeStampValue = 60.0;
    }

    requirement def DataOutputRequirement {
        attribute id : String = "REQ-005";
        attribute text : String = "The Data Acquisition Unit shall output digitized heat flux measurements in W/m2 with a timestamp and sensor identifier.";
        attribute outputUnit : String = "W/m2";
    }

    requirement def SignalAmplificationRequirement {
        attribute id : String = "REQ-006";
        attribute text : String = "The Signal Amplifier shall amplify the thermocouple voltage by a gain factor of at least 1000.";
        attribute minGain : Real = 1000;
    }

    requirement def CalibrationRequirement {
        attribute id : String = "REQ-007";
        attribute text : String = "The Calibration Module shall convert amplified voltage to heat flux using a calibration factor traceable to national standards.";
        attribute calibrationTraceability : String = "NIST-traceable";
    }

    // ---- Requirement Satisfaction ----

    part def GardonGaugeSystem :> GardonGauge {
        satisfy MeasurementAccuracyRequirement {
            attribute fullScaleRange = maxHeatFlux;
        }
        satisfy CoolantFlowRequirement {
            attribute minFlowRate = minCoolantFlow;
        }
        satisfy FaultDetectionRequirement;
        satisfy InitializationRequirement;
        satisfy DataOutputRequirement;
        satisfy SignalAmplificationRequirement {
            attribute minGain = amplifier.gain;
        }
        satisfy CalibrationRequirement;
    }

}
